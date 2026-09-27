"""Run: py -3 tools/test_mbp1_pc_control.py (loopback only; no FPGA needed)."""
import socket
import struct
import time
from mbp1_pc_control import Peer, packet, parse


def main():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as board, socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as pc:
        board.bind(("127.0.0.1", 0))
        pc.bind(("127.0.0.1", 0))
        board.settimeout(1)
        peer = Peer(pc, board.getsockname())
        board_boot, board_seq = 123, 0

        def incoming(kind, payload, flags=0, boot=None):
            nonlocal board_seq
            board_seq += 1
            board.sendto(packet(kind, flags, board_seq, board_boot if boot is None else boot, payload), pc.getsockname())
            peer.poll()

        def outgoing(kind):
            while True:
                decoded = parse(board.recvfrom(1024)[0])
                assert decoded is not None
                if decoded[0] == kind:
                    return decoded

        def ack(command, result=0, boot=None):
            incoming(4, struct.pack(">IBBBB", command[2], command[0], result, 2, 0), 2, boot)

        def state():
            incoming(2, bytes([2, 3, 1, 2, 0, 0, 0, 0]) + bytes(8))
            incoming(0x16, bytes([0, 3, 2, 3, 3, 2, 3, 1]) + struct.pack(">hh", 0, 0))

        peer.connect()
        hello = outgoing(1)
        assert hello[4] == bytes([2, 2, 1, 1]) + bytes(8)
        ack(hello)
        ack(outgoing(3))
        state()
        assert peer.ready()
        assert len(outgoing(2)[4]) == 16
        incoming(1, bytes([1, 1, 1, 1]) + bytes(8), 1)
        assert outgoing(4)[4][4:6] == bytes([1, 0])
        incoming(0x12, bytes([3, 2, 1, 0]) + bytes(4), 1)
        assert outgoing(4)[4][4:6] == bytes([0x12, 0])
        peer.preset(1)
        command = outgoing(0x13)
        assert command[4] == bytes([1, 1, 0, 0])
        # Wrong session ACK must not complete a transaction.
        ack(command, boot=999)
        assert peer.pending is not None
        peer.pending[3] -= 0.11
        peer.poll()
        retry = outgoing(0x13)
        assert retry[1] == 5 and retry[2:] == command[2:]
        ack(command)
        assert not peer.ready()  # ACK is not proof of applied video state.
        peer.await_display -= 0.2
        state()
        assert peer.ready()
        peer.adjust([6, 4, 5, 6])
        command = outgoing(0x14)
        assert command[4] == bytes([6, 4, 5, 6, 1, 0, 0, 0])
        ack(command, 4)
        assert "BUSY" in peer.message and peer.pending is None
        peer.pan(-16, 16)
        command = outgoing(0x15)
        assert command[4] == struct.pack(">BBBBhh", 3, 1, 2, 0, -16, 16)
        ack(command, 5)
        incoming(0x16, bytes([0, 3, 2, 3, 3, 1, 3, 1]) + bytes(4))
        try:
            peer.pan(16, 0)
            assert False, "1x pan accepted"
        except ValueError:
            pass
        incoming(2, bytes([3, 3, 1, 1, 1, 0, 0, 0]) + bytes(8))
        try:
            peer.preset(0)
            assert False, "emergency control accepted"
        except ValueError:
            pass
        state()
        for levels in ([7, 2, 3, 3], [3, 5, 3, 3], [3, 2, 6, 3], [3, 2, 3, 7]):
            try:
                peer.adjust(levels)
                assert False, "out-of-range accepted"
            except ValueError:
                pass
        before = peer.status[0x16]
        damaged = bytearray(packet(0x16, 0, board_seq + 1, board_boot, bytes(12)))
        damaged[-1] ^= 1
        board.sendto(damaged, pc.getsockname())
        peer.poll()
        assert peer.status[0x16] == before
        # A stale status sequence cannot roll back the displayed state.
        board.sendto(packet(0x16, 0, 0, board_boot, before[0]), pc.getsockname())
        peer.poll()
        assert peer.status[0x16] == before
        hb = peer.status[2][0]
        peer.status[2] = (hb, time.monotonic() - 3)
        peer.poll()
        assert not peer.connected and not peer.ready()
        peer.connect()
        ack(outgoing(1))
        ack(outgoing(3))
        state()
        peer.preset(0)
        outgoing(0x13)
        peer.pending[3:] = [time.monotonic() - 1, 10]
        peer.poll()
        assert peer.pending is None and "超时" in peer.message
        incoming(1, bytes([1, 1, 1, 1]) + bytes(8), 1, boot=456)
        assert not peer.connected and not peer.status
        print("PASS: session, heartbeat, telemetry ACK, commands, retry, BUSY, validation, stale packets, reconnect")


if __name__ == "__main__":
    main()
