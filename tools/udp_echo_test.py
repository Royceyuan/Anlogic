#!/usr/bin/env python3
import socket
import sys
import time

LOCAL = ("192.168.10.2", 5000)
TARGET = ("192.168.10.1", 5000)


def main() -> int:
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 20
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(1.0)
    sock.bind(LOCAL)
    passed = 0
    for sequence in range(count):
        payload = b"MAIN5A" + sequence.to_bytes(2, "big") + bytes(range(32))
        started = time.perf_counter()
        sock.sendto(payload, TARGET)
        try:
            echoed, source = sock.recvfrom(4096)
        except TimeoutError:
            print(f"FAIL {sequence:03d}: timeout")
            continue
        elapsed_ms = (time.perf_counter() - started) * 1000
        if echoed != payload or source != TARGET:
            print(f"FAIL {sequence:03d}: source={source}, bytes={len(echoed)}")
            continue
        passed += 1
        print(f"PASS {sequence:03d}: {elapsed_ms:.2f} ms")
    print(f"result: {passed}/{count}")
    return 0 if passed == count else 1


if __name__ == "__main__":
    raise SystemExit(main())
