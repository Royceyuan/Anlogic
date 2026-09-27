#!/usr/bin/env python3
"""MAIN-5D control panel; only Python's standard library is required."""
import secrets
import socket
import struct
import sys
import time

from mbp1_pc_peer import LOCAL, TARGET, packet, parse

PRESETS = ("标准", "明亮", "高对比", "柔和")
LIMITS = (6, 4, 5, 6)
RESULTS = {0: "已接收；以状态回报为准", 2: "长度错误", 3: "不支持（检查 bit）",
           4: "BUSY：请等转场/恢复结束后重新操作", 5: "状态不匹配或参数越界"}


class Peer:
    def __init__(self, sock, target=TARGET):
        self.sock, self.target = sock, target
        self.sock.setblocking(False)
        self.seq = secrets.randbelow(0x10000000) + 1
        self.boot = secrets.randbits(32)
        self.board_boot = None
        self.pending = None
        self.await_display = 0
        self.connected = False
        self.connected_at = 0
        self.status = {}
        self.last_seq = {}
        self.heartbeat_at = 0
        self.message = "请点击连接 / 重连"

    def send(self, kind, flags=0, payload=b"", seq=None):
        if seq is None:
            seq = self.seq
            self.seq = (self.seq + 1) & 0xffffffff
        self.sock.sendto(packet(kind, flags, seq, self.boot, payload), self.target)
        return seq

    def request(self, kind, payload=b""):
        if self.pending:
            raise ValueError("上一条命令仍在等待 ACK")
        seq = self.send(kind, 1, payload)
        self.pending = [kind, payload, seq, time.monotonic(), 1]
        self.message = f"等待 ACK：{kind:02X} / {seq}"

    def connect(self):
        self.pending = None
        self.connected = False
        self.board_boot = None
        self.status.clear()
        self.await_display = 0
        self.last_seq.clear()
        # A new PC session discards all old commands; nothing is replayed.
        self.boot = secrets.randbits(32)
        self.request(1, bytes([2, 2, 1, 1]) + bytes(8))

    def fresh(self, kind):
        return kind in self.status and time.monotonic() - self.status[kind][1] < 2

    def ready(self):
        return self.connected and not self.pending and not self.await_display and self.fresh(2) and self.fresh(0x16)

    def command(self, kind, payload):
        if not self.ready():
            raise ValueError("未连接、状态过期或上一命令未完成")
        hb = self.status[2][0]
        if hb[0] not in (1, 2) or hb[3] == 3 or hb[4]:
            raise ValueError("主板正在转场、应急、启动或故障，暂不控制")
        self.request(kind, payload)

    def preset(self, index):
        if index not in range(4):
            raise ValueError("预设范围为 0～3")
        self.command(0x13, bytes([index, 1, 0, 0]))

    def adjust(self, levels):
        if len(levels) != 4 or any(not 0 <= x <= hi for x, hi in zip(levels, LIMITS)):
            raise ValueError("参数索引越界")
        self.command(0x14, bytes([*levels, 1, 0, 0, 0]))

    def pan(self, dx=0, dy=0, recenter=False):
        if not self.ready():
            raise ValueError("等待连接和新状态")
        hb, display = self.status[2][0], self.status[0x16][0]
        if hb[0] != 2 or hb[1] > 4 or hb[2] > 4 or display[5] != 2 or hb[2] != display[7]:
            raise ValueError("先进入讲解并按主板 KEY1 切换为 2×，等待阶段状态同步")
        x, y = struct.unpack(">hh", display[8:12])
        x, y = (0, 0) if recenter else (max(-240, min(240, x + dx)), max(-135, min(135, y + dy)))
        self.command(0x15, struct.pack(">BBBBhh", hb[1], hb[2], 2, int(recenter), x, y))

    def poll(self):
        now = time.monotonic()
        # Bound receive work so unsolicited traffic cannot freeze the UI.
        for _ in range(64):
            try:
                data, source = self.sock.recvfrom(1024)
            except BlockingIOError:
                break
            decoded = parse(data)
            if source != self.target or decoded is None:
                continue
            kind, flags, seq, boot, payload = decoded
            if len(payload) != {1: 12, 2: 16, 4: 8, 0x12: 8, 0x16: 12, 0x31: 16}.get(kind):
                continue
            if self.board_boot is None:
                # Only our HELLO ACK can establish a session, not stale telemetry.
                if not (kind == 4 and self.pending and self.pending[0] == 1 and
                        struct.unpack(">IB", payload[:5]) == (self.pending[2], 1) and payload[5] == 0):
                    continue
                self.board_boot = boot
            if boot != self.board_boot:
                if kind == 1:
                    self.connected = False
                    self.pending = None
                    self.status.clear()
                    self.message = "主板会话改变，请点击连接 / 重连；旧命令已丢弃"
                continue
            if kind in (1, 0x12) and flags & 1:
                self.send(4, 2, struct.pack(">IBBBB", seq, kind, 0, 1, 0))
            if kind == 4:
                ack_seq, ack_type, result, _, _ = struct.unpack(">IBBBB", payload)
                if self.pending and (ack_type, ack_seq) == (self.pending[0], self.pending[2]):
                    self.pending = None
                    self.message = f"ACK {ack_type:02X}: {RESULTS.get(result, str(result))}"
                    if ack_type in (0x13, 0x14, 0x15) and result == 0:
                        # Wait for a later snapshot, not the pre-commit event packet.
                        self.await_display = now + 0.1
                    if ack_type == 1:
                        self.connected = result == 0
                        self.connected_at = now
                        if self.connected:
                            self.request(3)
                continue
            if kind not in (2, 0x12, 0x16, 0x31):
                continue
            old_seq = self.last_seq.get(kind)
            if old_seq is not None and not 0 < (seq - old_seq) & 0xffffffff < 0x80000000:
                continue
            if kind == 0x16 and (payload[0] not in (0, 1, 2, 3, 255) or
                    any(x > hi for x, hi in zip(payload[1:5], LIMITS)) or payload[5] not in (1, 2)):
                continue
            self.last_seq[kind] = seq
            self.status[kind] = (payload, now)
            if kind == 0x16 and self.await_display and now >= self.await_display:
                self.await_display = 0
        if self.connected and now >= self.heartbeat_at:
            self.send(2, payload=bytes(16))
            self.heartbeat_at = now + 0.5
        if self.connected and now - self.status.get(2, (None, self.connected_at))[1] >= 2:
            self.connected = False
            self.pending = None
            self.message = "LINK LOST：旧命令已丢弃，请检查网线后重连"
        if self.pending and now - self.pending[3] >= 0.1:
            kind, payload, seq, _, count = self.pending
            if count >= 10:
                self.pending = None
                self.message = "ACK 超时，执行结果未知；请查看回报，必要时重连，勿盲目重复操作"
            else:
                self.send(kind, 5, payload, seq)
                self.pending[3:] = [now, count + 1]


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.bind(LOCAL)
    except OSError as exc:
        sock.close()
        print(f"无法绑定 {LOCAL[0]}:{LOCAL[1]}：{exc}\n"
              "检查有线网卡 IP、UDP 5000 占用和 Windows 保留端口。\n"
              "排查命令：Get-NetUDPEndpoint -LocalPort 5000\n"
              "NI 的 NIDomainService 也可能占用此端口；请勿直接关闭防火墙。",
              file=sys.stderr)
        return 1
    import tkinter as tk
    from tkinter import ttk

    root = tk.Tk()
    root.title("MAIN-5D 主板以太网控制")
    peer = Peer(sock)
    pane = ttk.Frame(root, padding=16)
    pane.grid()
    status = tk.StringVar(value=peer.message)
    actual = tk.StringVar(value="尚无主板状态")
    levels = [tk.IntVar(value=x) for x in (3, 2, 3, 3)]

    def act(fn):
        try:
            fn()
        except (ValueError, OSError) as exc:
            peer.message = str(exc)
        status.set(peer.message)

    ttk.Label(pane, text="电脑 192.168.10.2:5000 → 主板 192.168.10.1:5000").grid(row=0, column=0, columnspan=4)
    ttk.Button(pane, text="连接 / 重连", command=lambda: act(peer.connect)).grid(row=1, column=0, columnspan=2, sticky="ew")
    ttk.Button(pane, text="查询状态", command=lambda: act(lambda: peer.request(3) if peer.connected else peer.connect())).grid(row=1, column=2, columnspan=2, sticky="ew")
    controls = []
    for i, name in enumerate(PRESETS):
        button = ttk.Button(pane, text=name, command=lambda i=i: act(lambda: peer.preset(i)))
        button.grid(row=2, column=i, pady=10)
        controls.append(button)
    for i, name in enumerate(("亮度", "对比度", "饱和度", "色温")):
        ttk.Label(pane, text=f"{name}索引 (0～{LIMITS[i]})").grid(row=3, column=i)
        ttk.Spinbox(pane, from_=0, to=LIMITS[i], width=10, textvariable=levels[i]).grid(row=4, column=i)

    def apply_levels():
        try:
            values = [v.get() for v in levels]
        except tk.TclError:
            raise ValueError("请输入整数索引") from None
        peer.adjust(values)

    def copy_levels():
        if not peer.fresh(0x16):
            raise ValueError("尚无新状态")
        for var, value in zip(levels, peer.status[0x16][0][1:5]):
            var.set(value)

    for col, label, fn in ((0, "应用四项编辑值", apply_levels), (2, "回报值填入编辑框", copy_levels)):
        button = ttk.Button(pane, text=label, command=lambda fn=fn: act(fn))
        button.grid(row=5, column=col, columnspan=2, sticky="ew", pady=8)
        controls.append(button)
    ttk.Label(pane, text="视口方向（每次 16 源像素）；先在主板 KEY1 切换为 2×").grid(row=6, column=0, columnspan=4)
    for col, label, dx, dy in ((0, "← 左", -16, 0), (1, "↑ 上", 0, -16), (2, "↓ 下", 0, 16), (3, "→ 右", 16, 0)):
        button = ttk.Button(pane, text=label, command=lambda dx=dx, dy=dy: act(lambda: peer.pan(dx, dy)))
        button.grid(row=7, column=col)
        controls.append(button)
    button = ttk.Button(pane, text="视口居中", command=lambda: act(lambda: peer.pan(recenter=True)))
    button.grid(row=8, column=0, columnspan=4, pady=8)
    controls.append(button)
    ttk.Label(pane, textvariable=actual, justify="left").grid(row=9, column=0, columnspan=4, sticky="w")
    ttk.Label(pane, textvariable=status, wraplength=600).grid(row=10, column=0, columnspan=4, pady=10)

    def tick():
        try:
            peer.poll()
        except OSError as exc:
            peer.connected = False
            peer.pending = None
            peer.message = f"网络错误：{exc}；请重连"
        for button in controls:
            button.configure(state="normal" if peer.ready() else "disabled")
        lines = ["已连接" if peer.connected else "未连接", "实际回报（编辑框不是实际值）："]
        if 2 in peer.status:
            hb = peer.status[2][0]
            lines.append(f"模式={hb[0]}  文物={hb[1]}  阶段={hb[2]}  播放状态={hb[3]}  应急={hb[4]}  错误={hb[6]}")
        if 0x16 in peer.status:
            d = peer.status[0x16][0]
            x, y = struct.unpack(">hh", d[8:])
            name = PRESETS[d[0]] if d[0] < 4 else "自定义"
            lines.append(f"预设={name}  亮度/对比/饱和/色温={list(d[1:5])}\n倍率={d[5]}×  视口=({x}, {y})  波形={bool(d[6]&1)}  总览OSD={bool(d[6]&2)}")
        if 0x31 in peer.status:
            d = peer.status[0x31][0]
            lines.append(f"PHY={d[0]}  速度代码={d[1]}  存储状态={d[3]}  错误={d[6]}")
        if not peer.ready():
            lines.append("等待 ACK / 新状态；断线时以上可能为最后一次快照")
        actual.set("\n".join(lines))
        status.set(peer.message)
        root.after(20, tick)

    def close():
        sock.close()
        root.destroy()

    root.protocol("WM_DELETE_WINDOW", close)
    tick()
    root.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
