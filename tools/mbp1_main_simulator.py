#!/usr/bin/env python3
"""Interactive PC stand-in for the MAIN5 board; no FPGA reflash needed."""

import argparse
import queue
import secrets
import select
import socket
import sys
import threading
import time

from mbp1_secondary_pc_probe import LOCAL, MAIN_HELLO, SECONDARY, check_control, decode, packet


PRESETS = ((3, 2, 3, 3), (5, 3, 4, 4), (3, 4, 4, 3), (2, 1, 2, 4))
NAMES = {1: "HELLO", 2: "HEARTBEAT", 3: "STATUS_QUERY", 4: "ACK",
         0x12: "PLAYBACK_STATE", 0x13: "DISPLAY_PRESET",
         0x14: "DISPLAY_ADJUST", 0x15: "VIEWPORT_SET"}


class Main:
    def __init__(self, sock):
        self.sock = sock
        self.boot = secrets.randbits(32)
        self.seq = 0
        self.hello_seen = False
        self.highlight = 0
        self.preload = None
        self.lecture = None
        self.emergency = False
        self.preset = 0
        self.indices = list(PRESETS[0])
        self.zoom = 1
        self.pan = (0, 0)
        self.last_control = None
        self.playback_wait = None
        self.counts = {"HELLO": 0, "HEARTBEAT": 0, "STATUS_QUERY": 0,
                       "ACK": 0, "CONTROL": 0, "BAD": 0}

    def send(self, kind, flags=0, payload=b"", seq=None):
        if seq is None:
            self.seq += 1
            seq = self.seq
        self.sock.sendto(packet(kind, flags, seq, self.boot, payload), SECONDARY)
        return seq

    def heartbeat(self):
        mode = 3 if self.emergency else 2 if self.lecture is not None else 1
        artifact = self.lecture if self.lecture is not None else self.highlight
        phase = 0 if self.lecture is not None else 255
        preload = self.preload if self.preload is not None else 15
        ready = preload if self.lecture is None and not self.emergency else 15
        data = bytearray((mode, artifact, phase, int(self.lecture is not None),
                          int(self.emergency), self.preset, 0, 0x80))
        data += bytes(4) + int(self.emergency).to_bytes(2, "big")
        data += bytes(((self.highlight << 4) | preload, (preload << 4) | ready))
        return bytes(data)

    def display(self):
        return bytes((self.preset, *self.indices, self.zoom, 3,
                      0 if self.lecture is not None else 255)) + \
            self.pan[0].to_bytes(2, "big", signed=True) + \
            self.pan[1].to_bytes(2, "big", signed=True)

    def snapshot(self, diagnostic=False):
        self.send(2, payload=self.heartbeat())
        self.send(0x16, payload=self.display())
        if diagnostic:
            self.send(0x31, payload=bytes((1, 3, 2, 1)) + bytes(12))

    def playback(self):
        artifact = self.lecture if self.lecture is not None else self.highlight
        payload = bytes((artifact, int(self.lecture is not None),
                         0 if self.lecture is not None else 255, self.preset)) + bytes(4)
        seq = self.send(0x12, 1, payload)
        self.playback_wait = (seq, payload, time.monotonic(), 1)
        print(f"TX PLAYBACK_STATE seq={seq} artifact={artifact} lecture={self.lecture is not None}")

    def control(self, kind, flags, seq, boot, payload):
        key = (boot, seq, kind)
        if self.last_control and key == self.last_control[:3]:
            result = self.last_control[3]
            print(f"RX {NAMES[kind]} seq={seq} RETRY -> ACK {result}")
        else:
            valid, detail = check_control(kind, payload, self.lecture)
            if kind == 0x15:
                valid = (len(payload) == 8 and self.lecture is not None and
                         payload[0] == self.lecture and payload[1] == 0 and
                         payload[2] == self.zoom and payload[3] == 0 and
                         -240 <= int.from_bytes(payload[4:6], "big", signed=True) <= 240 and
                         -135 <= int.from_bytes(payload[6:8], "big", signed=True) <= 135)
            result = 5 if not valid or flags not in (1, 5) else 4 if self.emergency else 0
            if result == 0:
                if kind == 0x13:
                    self.preset = payload[0]
                    self.indices = list(PRESETS[self.preset])
                elif kind == 0x14:
                    self.preset = 255
                    self.indices = list(payload[:4])
                else:
                    self.pan = (int.from_bytes(payload[4:6], "big", signed=True),
                                int.from_bytes(payload[6:8], "big", signed=True))
            self.last_control = (*key, result)
            self.counts["CONTROL"] += 1
            print(f"RX {NAMES[kind]} seq={seq} {detail} -> "
                  f"{'OK' if result == 0 else 'BUSY' if result == 4 else 'INVALID_STATE'}")
        self.send(4, 2, seq.to_bytes(4, "big") + bytes((kind, result, 0, 0)))
        if result == 0:
            self.send(0x16, payload=self.display())

    def receive(self):
        data, source = self.sock.recvfrom(512)
        if source != SECONDARY:
            print(f"IGNORE unexpected peer {source}")
            return
        try:
            kind, flags, seq, payload = decode(data)
        except ValueError as exc:
            self.counts["BAD"] += 1
            print(f"BAD packet: {exc}")
            return
        if kind == 1 and len(payload) == 12 and payload[:4] == b"\x02\x02\x01\x01" and flags & 1:
            self.hello_seen = True
            self.counts["HELLO"] += 1
            print(f"RX HELLO seq={seq} build={payload[4:8].hex()} caps={payload[8:].hex()}")
            self.send(4, 2, seq.to_bytes(4, "big") + bytes((1, 0, 0, 0)))
            self.snapshot(True)
        elif kind == 3 and not payload and flags & 1:
            self.counts["STATUS_QUERY"] += 1
            print(f"RX STATUS_QUERY seq={seq}")
            self.send(4, 2, seq.to_bytes(4, "big") + bytes((3, 0, 0, 0)))
            self.snapshot(True)
        elif kind == 2 and len(payload) == 16 and flags == 0:
            self.counts["HEARTBEAT"] += 1
        elif kind == 4 and len(payload) == 8 and flags == 2:
            self.counts["ACK"] += 1
            ack_seq = int.from_bytes(payload[:4], "big")
            print(f"RX ACK {NAMES.get(payload[4], hex(payload[4]))} "
                  f"seq={ack_seq} result={payload[5]}")
            if self.playback_wait and ack_seq == self.playback_wait[0] and payload[4] == 0x12:
                self.playback_wait = None
        elif kind in (0x13, 0x14, 0x15):
            self.control(kind, flags, seq, int.from_bytes(data[12:16], "big"), payload)
        else:
            self.counts["BAD"] += 1
            print(f"UNEXPECTED {NAMES.get(kind, hex(kind))} seq={seq} flags={flags:02x} data={payload.hex()}")

    def command(self, line):
        parts = line.strip().lower().split()
        if not parts:
            return True
        if parts[0] in ("quit", "q", "exit"):
            return False
        if parts[0] == "status":
            print(f"highlight={self.highlight} preload={self.preload} "
                  f"lecture={self.lecture} emergency={self.emergency} "
                  f"preset={self.preset} indices={self.indices} pan={self.pan} RX={self.counts}")
            return True
        if parts[0] == "overview" and len(parts) == 1:
            self.lecture = None
            self.pan = (0, 0)
            self.playback()
        elif parts[0] in ("highlight", "preload", "lecture") and len(parts) == 2 and parts[1] in "01234":
            artifact = int(parts[1])
            if parts[0] == "highlight":
                self.highlight = artifact
            else:
                self.preload = artifact
            if parts[0] == "lecture":
                self.lecture = artifact
                self.highlight = artifact
                self.pan = (0, 0)
                self.playback()
        elif parts[0] == "emergency" and len(parts) == 2 and parts[1] in ("on", "off"):
            self.emergency = parts[1] == "on"
        else:
            print("Commands: highlight/preload/lecture 0..4 | overview | "
                  "emergency on/off | status | quit")
            return True
        self.snapshot(True)
        print(f"TX state: highlight={self.highlight} preload={self.preload} "
              f"lecture={self.lecture} emergency={self.emergency}")
        return True


def run(seconds):
    commands = queue.Queue()

    def read_commands():
        for line in sys.stdin:
            commands.put(line)

    threading.Thread(target=read_commands, daemon=True).start()
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(LOCAL)
        main = Main(sock)
        print(f"PC main {LOCAL} <-> secondary {SECONDARY}")
        print("Commands: highlight/preload/lecture 0..4 | overview | "
              "emergency on/off | status | quit", flush=True)
        deadline = time.monotonic() + seconds if seconds else float("inf")
        next_hello = next_status = next_diag = 0.0
        while time.monotonic() < deadline:
            now = time.monotonic()
            if not main.hello_seen and now >= next_hello:
                main.send(1, 1, MAIN_HELLO)
                next_hello = now + 1
            if main.hello_seen and now >= next_status:
                main.snapshot(now >= next_diag)
                next_status = now + 0.5
                if now >= next_diag:
                    next_diag = now + 1
            if main.playback_wait:
                seq, payload, sent, attempts = main.playback_wait
                if now - sent >= 0.1:
                    if attempts >= 10:
                        print(f"TIMEOUT PLAYBACK_STATE seq={seq}")
                        main.playback_wait = None
                    else:
                        main.send(0x12, 5, payload, seq)
                        main.playback_wait = (seq, payload, now, attempts + 1)
            try:
                while True:
                    if not main.command(commands.get_nowait()):
                        print("Summary:", main.counts)
                        return
            except queue.Empty:
                pass
            if select.select([sock], [], [], 0.05)[0]:
                main.receive()
        print("Summary:", main.counts)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, help="Stop after N seconds; default runs until quit")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        class FakeSocket:
            def __init__(self):
                self.sent = []

            def sendto(self, data, peer):
                self.sent.append((data, peer))

        test_sock = FakeSocket()
        main = Main(test_sock)
        assert len(main.heartbeat()) == 16 and len(main.display()) == 12
        main.command("preload 2")
        assert main.heartbeat()[2] == 255 and main.heartbeat()[14:] == b"\x02\x22"
        main.command("lecture 2")
        assert main.heartbeat()[:3] == b"\x02\x02\x00"
        main.command("emergency on")
        assert main.heartbeat()[4] == 1
        main.command("emergency off")
        main.control(0x13, 1, 7, 9, b"\x01\x01\0\0")
        assert main.preset == 1 and main.indices == list(PRESETS[1])
        assert all(decode(data) for data, peer in test_sock.sent if peer == SECONDARY)
        print("PASS status payloads, control ACK and CRC")
    else:
        run(args.seconds)
