"""Run: py -3 tools/test_mbp1_pc_control.py (loopback only; no FPGA needed)."""
import socket
import struct
import time
import io
from contextlib import redirect_stderr
from unittest.mock import patch
import mbp1_pc_control
from mbp1_pc_control import Peer, packet, parse


def main():
    hb = bytearray(16)
    assert "旧固件" in mbp1_pc_control.local_status_text(hb)
    hb[7], hb[14], hb[15] = 0xb3, 0x23, 0x3f
    text = mbp1_pc_control.local_status_text(hb)
    assert all(s in text for s in ("SW4～1=0011", "高亮=2", "预载目标=3",
                                  "图片已缓存=3", "可进入讲解=无", "暂停=True", "预载中=True"))
    # Binding failure must exit cleanly without creating/destroying a Tk app.
    with patch.object(socket, "socket") as factory, patch("tkinter.Tk") as window:
        factory.return_value.bind.side_effect = PermissionError(10013, "port unavailable")
        output = io.StringIO()
        with redirect_stderr(output):
            assert mbp1_pc_control.main() == 1
        factory.return_value.close.assert_called_once()
        window.assert_not_called()
        assert "10013" in output.getvalue() and "NIDomainService" in output.getvalue()
    print("PASS: bind failure closes socket and exits without creating Tk")
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
        state()
        assert not peer.ready()  # Old values cannot acknowledge a new preset.
        incoming(0x16, bytes([1, 5, 3, 4, 4, 2, 3, 1]) + bytes(4))
        assert peer.ready()
        assert "ms" in peer.message
        peer.preset(1)
        command = outgoing(0x13)
        ack(command)
        assert not peer.ready()  # Matching pre-command status is stale.
        incoming(0x16, bytes([1, 5, 3, 4, 4, 2, 3, 1]) + bytes(4))
        assert peer.ready()
        peer.preset(0)
        command = outgoing(0x13)
        state()  # Applied status may precede ACK on the wire.
        assert not peer.ready()
        ack(command)
        assert peer.ready()
        peer.adjust([6, 4, 5, 6])
        command = outgoing(0x14)
        assert command[4] == bytes([6, 4, 5, 6, 1, 0, 0, 0])
        ack(command, 4)
        assert "BUSY" in peer.message and peer.pending is None
        peer.adjust([3,2,3,3])
        ack(outgoing(0x14))
        incoming(0x16,bytes([255,3,2,3,3,2,3,1])+bytes(4))
        assert peer.ready()
        peer.preset(0)
        ack(outgoing(0x13))
        # If local actions supersede a target, no permanent UI lock is allowed.
        peer.await_display=time.monotonic()-1
        peer.poll()
        assert peer.ready() and "未确认" in peer.message
        peer.pan(-20, 40)
        command = outgoing(0x15)
        assert command[4] == struct.pack(">BBBBhh", 3, 1, 2, 0, -20, 40)
        ack(command, 5)
        incoming(0x16, bytes([0, 3, 2, 3, 3, 1, 3, 1]) + bytes(4))
        peer.pan(20, 0)
        command=outgoing(0x15)
        assert command[4] == struct.pack(">BBBBhh", 3, 1, 1, 0, 20, 0)
        ack(command)
        incoming(0x16, bytes([0, 3, 2, 3, 3, 1, 3, 1]) + struct.pack(">hh",20,0))
        assert peer.ready()
        incoming(2, bytes([3, 3, 1, 1, 1, 0, 0, 0]) + bytes(8))
        try:
            peer.preset(0)
            assert False, "emergency control accepted"
        except ValueError:
            pass
        state()
        # A rejected transition attempt leaves no pending transaction.
        incoming(2, bytes([2,3,1,3,0,0,0,0])+bytes(8))
        try:
            peer.preset(0)
            assert False, "transition command accepted"
        except ValueError:
            pass
        assert peer.pending is None
        incoming(2, bytes([4,3,1,2,0,0,3,0])+bytes(8))
        peer.preset(0)  # Subtitle diagnostic must not disable the image controls.
        ack(outgoing(0x13))
        state()
        assert peer.ready()
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
