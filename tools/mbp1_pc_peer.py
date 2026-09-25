#!/usr/bin/env python3
"""PC stand-in for the secondary board during MAIN-5B UDP checks."""

import binascii
import secrets
import socket
import struct
import time

LOCAL = ("192.168.10.2", 5000)
TARGET = ("192.168.10.1", 5000)


def packet(msg_type: int, flags: int, seq: int, boot: int, payload: bytes = b"") -> bytes:
    if len(payload) > 256:
        raise ValueError("MBP1 payload exceeds 256 bytes")
    body = struct.pack(">2sBBBBHIII", b"MB", 1, msg_type, flags, 20,
                       len(payload), seq, boot, 0) + payload
    return body + struct.pack(">H", binascii.crc_hqx(body, 0xFFFF))


def parse(data: bytes) -> tuple[int, int, int, int, bytes] | None:
    if len(data) < 22 or data[:3] != b"MB\x01" or data[5] != 20:
        return None
    length = int.from_bytes(data[6:8], "big")
    if length > 256 or len(data) != length + 22:
        return None
    if binascii.crc_hqx(data[:-2], 0xFFFF) != int.from_bytes(data[-2:], "big"):
        return None
    return data[3], data[4], int.from_bytes(data[8:12], "big"), int.from_bytes(data[12:16], "big"), data[20:-2]


def main() -> int:
    boot = secrets.randbits(32)
    sequence = 1
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(LOCAL)

        def receive(deadline: float):
            nonlocal sequence
            while time.monotonic() < deadline:
                sock.settimeout(max(0.01, deadline - time.monotonic()))
                try:
                    data, source = sock.recvfrom(1024)
                except TimeoutError:
                    break
                if source != TARGET:
                    continue
                decoded = parse(data)
                if decoded is None:
                    raise AssertionError(f"invalid board packet: {data.hex()}")
                msg_type, flags, seq, _, payload = decoded
                if msg_type == 1:  # The board also initiates HELLO.
                    ack = struct.pack(">IBBBB", seq, msg_type, 0, 1, 0)
                    sock.sendto(packet(4, 2, sequence, boot, ack), TARGET)
                    sequence += 1
                yield msg_type, flags, seq, payload

        def request(msg_type: int, payload: bytes, expected_result: int,
                    *, reuse_seq: int | None = None, timeout: float = 2.0):
            nonlocal sequence
            sent_seq = sequence if reuse_seq is None else reuse_seq
            if reuse_seq is None:
                sequence += 1
            wire = packet(msg_type, 1 if reuse_seq is None else 5,
                          sent_seq, boot, payload)
            deadline = time.monotonic() + timeout
            next_send = 0.0
            seen = []
            while time.monotonic() < deadline:
                now = time.monotonic()
                if now >= next_send:
                    sock.sendto(wire, TARGET)
                    next_send = now + 0.25
                for incoming in receive(min(deadline, next_send)):
                    seen.append(incoming[0])
                    if incoming[0] == 4 and len(incoming[3]) == 8:
                        ack_seq, ack_type, result, _, _ = struct.unpack(
                            ">IBBBB", incoming[3])
                        if ack_seq == sent_seq and ack_type == msg_type:
                            if result != expected_result:
                                raise AssertionError(
                                    f"type {msg_type:02x}: result {result}, expected {expected_result}")
                            print(f"PASS type={msg_type:02x} seq={sent_seq} result={result}")
                            return sent_seq, seen
            raise TimeoutError(f"type {msg_type:02x} seq={sent_seq}: no ACK")

        hello = bytes([2, 2, 1, 1]) + bytes(8)
        request(1, hello, 0, timeout=10.0)
        bad_seq = sequence
        sequence += 1
        corrupted = bytearray(packet(3, 1, bad_seq, boot))
        corrupted[-1] ^= 1
        sock.sendto(corrupted, TARGET)
        bad_len_seq = sequence
        malformed = bytearray(packet(3, 1, bad_len_seq, boot))
        malformed[7] = 1  # Claimed payload length disagrees with UDP length.
        malformed[-2:] = binascii.crc_hqx(malformed[:-2], 0xFFFF).to_bytes(2, "big")
        sock.sendto(malformed, TARGET)
        sequence += 1
        for msg_type, _, _, payload in receive(time.monotonic() + 0.3):
            if msg_type == 4 and len(payload) == 8 and int.from_bytes(payload[:4], "big") in (bad_seq, bad_len_seq):
                raise AssertionError("malformed packet was acknowledged")
        print("PASS malformed CRC and length rejected")
        query_seq, _ = request(3, b"", 0)
        request(3, b"", 0, reuse_seq=query_seq)
        request(0x13, bytes([0, 1, 0, 0]), 3)
        sock.sendto(packet(2, 0, sequence, boot, bytes(16)), TARGET)
        sequence += 1
        seen_types = set()
        for msg_type, _, _, _ in receive(time.monotonic() + 1.2):
            seen_types.add(msg_type)
            if {2, 0x16, 0x31} <= seen_types:
                break
        if not {2, 0x16, 0x31} <= seen_types:
            raise AssertionError(f"missing periodic/status packets: {seen_types}")
        print("PASS telemetry: HEARTBEAT, DISPLAY_STATUS, DIAGNOSTIC_STATUS")
        boot = secrets.randbits(32)
        request(1, hello, 0)
        print("PASS new boot_id session")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
