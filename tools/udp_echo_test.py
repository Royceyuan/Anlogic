#!/usr/bin/env python3
import secrets
import socket
import sys
import time

LOCAL = ("192.168.10.2", 5000)
TARGET = ("192.168.10.1", 5000)


def main() -> int:
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(LOCAL)
    run_id = secrets.token_bytes(4)
    passed = 0
    for sequence in range(count):
        payload = b"MAIN5A" + run_id + sequence.to_bytes(2, "big") + bytes(range(32))
        started = time.perf_counter()
        deadline = started + (10.0 if sequence == 0 else 2.0)
        next_send = started
        while time.perf_counter() < deadline:
            now = time.perf_counter()
            if now >= next_send:
                sock.sendto(payload, TARGET)
                next_send = now + 1.0
            sock.settimeout(max(0.001, min(next_send, deadline) - time.perf_counter()))
            try:
                echoed, source = sock.recvfrom(4096)
            except TimeoutError:
                continue
            if source != TARGET:
                continue
            if echoed == payload:
                passed += 1
                print(f"PASS {sequence:03d}: {(time.perf_counter() - started) * 1000:.2f} ms")
                break
            if echoed.startswith(b"MAIN5A") and echoed[6:10] != run_id:
                continue
            if echoed.startswith(b"MAIN5A" + run_id) and echoed[10:12] != payload[10:12]:
                continue
            print(f"FAIL {sequence:03d}: payload mismatch, bytes={len(echoed)}")
            print(f"  sent: {payload.hex(' ')}")
            print(f"  recv: {echoed.hex(' ')}")
            break
        else:
            print(f"FAIL {sequence:03d}: timeout")
    print(f"result: {passed}/{count}")
    return 0 if passed == count else 1


if __name__ == "__main__":
    raise SystemExit(main())
