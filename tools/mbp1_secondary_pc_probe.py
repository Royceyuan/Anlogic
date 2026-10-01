#!/usr/bin/env python3
"""Exercise the full secondary bit's MBP1 sender with a PC as a fake main board."""

import argparse
import secrets
import select
import socket
import time

LOCAL = ("192.168.10.1", 5000)
SECONDARY = ("192.168.10.2", 5000)
MAIN_HELLO = bytes.fromhex("0101010100050004000003ff")
TYPES = {1: "HELLO", 2: "HEARTBEAT", 3: "STATUS_QUERY", 4: "ACK",
         0x13: "DISPLAY_PRESET", 0x14: "DISPLAY_ADJUST", 0x15: "VIEWPORT_SET",
         0x17: "BROWSE_MODE_SET", 0x18: "BROWSE_IMAGE_SET"}


def crc16(data):
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ (0x1021 if crc & 0x8000 else 0)) & 0xFFFF
    return crc


def packet(kind, flags, seq, boot, payload=b""):
    body = (b"MB\x01" + bytes((kind, flags, 20)) + len(payload).to_bytes(2, "big")
            + seq.to_bytes(4, "big") + boot.to_bytes(4, "big")
            + int(time.monotonic() * 1000 % 2**32).to_bytes(4, "big") + payload)
    return body + crc16(body).to_bytes(2, "big")


def decode(data):
    if len(data) < 22 or data[:3] != b"MB\x01" or data[5] != 20:
        raise ValueError("header or length")
    length = int.from_bytes(data[6:8], "big")
    if data[4] & 0xF8 or length > 256 or len(data) != 22 + length:
        raise ValueError("flags or payload length")
    if crc16(data[:-2]) != int.from_bytes(data[-2:], "big"):
        raise ValueError("CRC")
    return data[3], data[4], int.from_bytes(data[8:12], "big"), data[20:-2]


def check_control(kind, payload, lecture):
    if kind == 0x13:
        valid = len(payload) == 4 and payload[0] <= 3 and payload[1:] == b"\x01\0\0"
        detail = f"preset={payload[0]}" if payload else "empty"
    elif kind == 0x14:
        valid = (len(payload) == 8 and payload[0] <= 6 and payload[1] <= 4
                 and payload[2] <= 5 and payload[3] <= 6
                 and payload[4:] == b"\x01\0\0\0")
        detail = f"indices={list(payload[:4])}"
    elif kind == 0x17:
        valid = len(payload) == 4 and payload[0] <= 1 and payload[1:] == bytes(3)
        detail = f"manual={payload[0]}" if payload else "empty"
    elif kind == 0x18:
        valid = (len(payload) == 4 and lecture is not None and payload[0] == lecture
                 and payload[1] <= 3 and payload[2:] == bytes(2))
        detail = f"artifact/image={list(payload[:2])}"
    elif kind == 0x15:
        valid = (len(payload) == 8 and lecture is not None and payload[0] == lecture
                 and payload[1] == 0 and payload[2] == 1 and payload[3] == 0
                 and -240 <= int.from_bytes(payload[4:6], "big", signed=True) <= 240
                 and -135 <= int.from_bytes(payload[6:8], "big", signed=True) <= 135)
        detail = (f"artifact={payload[0]} phase={payload[1]} zoom={payload[2]} "
                  f"pan=({int.from_bytes(payload[4:6], 'big', signed=True)},"
                  f"{int.from_bytes(payload[6:8], 'big', signed=True)})") if len(payload) == 8 else "bad length"
    else:
        valid, detail = False, "unsupported control"
    return valid, detail


def run(seconds, lecture):
    boot = secrets.randbits(32)
    seq = 0
    seen = {"HELLO": 0, "HEARTBEAT": 0, "STATUS_QUERY": 0,
            "ACK": 0, "CONTROL": 0, "BAD": 0}
    heartbeat = bytes((2 if lecture is not None else 1,
                       lecture if lecture is not None else 0,
                       0 if lecture is not None else 255,
                       1 if lecture is not None else 0, 0, 0, 0, 0x80)) + bytes(6) + bytes((0x0F, 0xFF))
    display = bytes((0, 3, 2, 3, 3, 1, 0, 0 if lecture is not None else 255)) + bytes(4)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(LOCAL)

        def send(kind, flags=0, payload=b""):
            nonlocal seq
            seq += 1
            sock.sendto(packet(kind, flags, seq, boot, payload), SECONDARY)

        def snapshot():
            send(2, payload=heartbeat)
            send(0x16, payload=display)

        started = time.monotonic()
        deadline = started + seconds
        next_hello = next_snapshot = time.monotonic()
        print(f"PC {LOCAL[0]}:{LOCAL[1]} -> secondary {SECONDARY[0]}:{SECONDARY[1]}")
        print("PC simulates main status; control requests receive BUSY and do not change the main board.")
        while time.monotonic() < deadline:
            now = time.monotonic()
            if seen["HELLO"] == 0 and now >= next_hello:
                send(1, 1, MAIN_HELLO)
                next_hello = now + 1
            if seen["HELLO"] and now >= next_snapshot:
                snapshot()
                next_snapshot = now + 0.5
            readable, _, _ = select.select([sock], [], [], 0.05)
            if not readable:
                continue
            data, source = sock.recvfrom(512)
            if source != SECONDARY:
                print(f"IGNORE other source {source}")
                continue
            try:
                kind, flags, rx_seq, payload = decode(data)
            except ValueError as exc:
                seen["BAD"] += 1
                print(f"BAD packet: {exc}, {len(data)} bytes")
                continue
            name = TYPES.get(kind, f"0x{kind:02X}")
            print(f"{time.monotonic()-started:6.2f}s RX {name} seq={rx_seq} "
                  f"flags={flags:02X} len={len(payload)} payload={payload.hex()}")
            if kind == 1:
                valid = (len(payload) == 12 and flags in (1, 5)
                         and payload[:4] == b"\x02\x02\x01\x01")
                seen["HELLO" if valid else "BAD"] += 1
                send(4, 2, rx_seq.to_bytes(4, "big") + bytes((kind, 0 if valid else 5, 0, 0)))
            elif kind == 2:
                seen["HEARTBEAT" if len(payload) == 16 and flags == 0 else "BAD"] += 1
            elif kind == 3:
                valid = not payload and flags in (1, 5)
                seen["STATUS_QUERY" if valid else "BAD"] += 1
                send(4, 2, rx_seq.to_bytes(4, "big") + bytes((kind, 0 if not payload else 2, 0, 0)))
                snapshot()
            elif kind == 4:
                seen["ACK" if len(payload) == 8 and flags == 2 else "BAD"] += 1
            elif kind in (0x13, 0x14, 0x15, 0x17, 0x18):
                valid, detail = check_control(kind, payload, lecture)
                valid = valid and flags in (1, 5)
                seen["CONTROL" if valid else "BAD"] += 1
                print(f"  {'VALID' if valid else 'INVALID'} {detail}; PC replies BUSY")
                send(4, 2, rx_seq.to_bytes(4, "big") + bytes((kind, 4, 0, 0)))
            else:
                seen["BAD"] += 1
                print("  Unexpected secondary message type")
        print("Summary:", seen)
    return 0 if all(seen[name] for name in ("HELLO", "HEARTBEAT", "STATUS_QUERY", "ACK")) and not seen["BAD"] else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seconds", type=float, default=15)
    parser.add_argument("--lecture-artifact", type=int, choices=range(5))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert crc16(b"123456789") == 0x29B1
        sample = packet(1, 1, 7, 9, MAIN_HELLO)
        assert decode(sample) == (1, 1, 7, MAIN_HELLO)
        assert len(sample) == 22 + len(MAIN_HELLO)
        try:
            decode(sample[:-1] + bytes((sample[-1] ^ 1,)))
        except ValueError:
            pass
        else:
            raise AssertionError("corrupt CRC accepted")
        assert check_control(0x13, b"\x02\x01\0\0", None)[0]
        assert not check_control(0x14, b"\x07\x02\x03\x03\x01\0\0\0", None)[0]
        assert check_control(0x17, b"\x01\0\0\0", None)[0]
        assert check_control(0x18, b"\x02\x03\0\0", 2)[0]
        assert not check_control(0x18, b"\x01\x03\0\0", 2)[0]
        print("PASS CRC, packet, control parser")
    else:
        raise SystemExit(run(args.seconds, args.lecture_artifact))
