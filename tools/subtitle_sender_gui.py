#!/usr/bin/env python3
"""Desktop sender for the v69 UART subtitle packet."""
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

from PIL import Image, ImageTk

from send_subtitle import HEIGHT, WIDTH, packet, rasterize


BG = "#0b1220"
CARD = "#162033"
FIELD = "#0f172a"
ACCENT = "#38bdf8"
TEXT = "#e5eefb"
MUTED = "#94a3b8"
LEVELS = ((18, 27, 42), (89, 103, 118), (161, 178, 187), (230, 251, 255))


class SubtitleSender(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("FPGA 字幕控制台")
        self.configure(bg=BG)
        self.resizable(False, False)
        self.port = tk.StringVar(value="COM8")
        self.font = tk.StringVar(value=r"C:\Windows\Fonts\msyhbd.ttc")
        self.size = tk.StringVar(value="28")
        self.scroll = tk.BooleanVar()
        self.speed = tk.StringVar(value="3")
        self.status = tk.StringVar(value="就绪：静态字幕将自动居中")
        self.preview_image = None
        self.build_ui()
        self.bind("<Control-Return>", lambda _event: self.send())
        for variable in (self.font, self.size, self.scroll):
            variable.trace_add("write", lambda *_: self.update_preview())
        self.text.bind("<KeyRelease>", lambda _event: self.update_preview())
        self.refresh_ports()
        self.update_preview()

    def label(self, parent, text, **kwargs):
        options = {"bg": CARD, "fg": MUTED, "font": ("Microsoft YaHei UI", 9)}
        options.update(kwargs)
        return tk.Label(parent, text=text, **options)

    def card(self, parent):
        return tk.Frame(parent, bg=CARD, padx=16, pady=14, highlightthickness=1,
                        highlightbackground="#25344d")

    def build_ui(self):
        header = tk.Frame(self, bg=BG, padx=20, pady=16)
        header.grid(row=0, column=0, sticky="ew")
        tk.Label(header, text="FPGA 字幕控制台", bg=BG, fg=TEXT,
                 font=("Microsoft YaHei UI", 18, "bold")).pack(side="left")
        tk.Label(header, text="UART 115200 · v69", bg=BG, fg=ACCENT,
                 font=("Consolas", 10, "bold")).pack(side="right", pady=6)

        main = tk.Frame(self, bg=BG, padx=20, pady=14)
        main.grid(row=1, column=0)
        settings = self.card(main)
        settings.grid(row=0, column=0, sticky="ew")
        self.label(settings, "连接设置", font=("Microsoft YaHei UI", 10, "bold"), fg=TEXT).grid(row=0, column=0, columnspan=4, sticky="w", pady=(0, 10))
        self.label(settings, "串口").grid(row=1, column=0, sticky="w")
        self.port_box = ttk.Combobox(settings, textvariable=self.port, width=12, state="normal")
        self.port_box.grid(row=1, column=1, sticky="w", padx=(8, 8))
        ttk.Button(settings, text="刷新", command=self.refresh_ports).grid(row=1, column=2, sticky="w")
        self.label(settings, "字体").grid(row=2, column=0, sticky="w", pady=(12, 0))
        tk.Entry(settings, textvariable=self.font, width=44, bg=FIELD, fg=TEXT, insertbackground=TEXT,
                 relief="flat", highlightthickness=1, highlightbackground="#31435f").grid(row=2, column=1, columnspan=2, sticky="we", padx=(8, 8), pady=(12, 0), ipady=4)
        ttk.Button(settings, text="选择字体", command=self.choose_font).grid(row=2, column=3, pady=(12, 0))
        self.label(settings, "字号").grid(row=3, column=0, sticky="w", pady=(12, 0))
        ttk.Combobox(settings, textvariable=self.size, values=("20", "24", "28", "30"), width=12, state="readonly").grid(row=3, column=1, sticky="w", padx=(8, 0), pady=(12, 0))
        self.label(settings, "显示模式").grid(row=3, column=2, sticky="e", padx=(12, 0), pady=(12, 0))
        tk.Checkbutton(settings, text="水平滚动", variable=self.scroll, command=self.update_preview,
                       bg=CARD, fg=TEXT, selectcolor=FIELD, activebackground=CARD, activeforeground=TEXT).grid(row=3, column=3, sticky="w", padx=(8, 0), pady=(12, 0))
        self.label(settings, "滚动速度").grid(row=4, column=0, sticky="w", pady=(10, 0))
        ttk.Combobox(settings, textvariable=self.speed, values=("1", "2", "3", "4", "5", "6", "7"), width=12, state="readonly").grid(row=4, column=1, sticky="w", padx=(8, 0), pady=(10, 0))

        content = self.card(main)
        content.grid(row=1, column=0, sticky="ew", pady=(12, 0))
        self.label(content, "字幕内容", font=("Microsoft YaHei UI", 10, "bold"), fg=TEXT).grid(row=0, column=0, sticky="w")
        self.label(content, "静态字幕居中；滚动会横跨全屏并快速回绕", anchor="e").grid(row=0, column=1, sticky="e")
        self.text = tk.Text(content, width=65, height=3, wrap="word", bg=FIELD, fg=TEXT, insertbackground=TEXT,
                            relief="flat", highlightthickness=1, highlightbackground="#31435f", font=("Microsoft YaHei UI", 11))
        self.text.grid(row=1, column=0, columnspan=2, pady=(8, 12))
        self.label(content, "FPGA 输出预览", font=("Microsoft YaHei UI", 10, "bold"), fg=TEXT).grid(row=2, column=0, sticky="w")
        self.preview = tk.Label(content, bg=FIELD, relief="flat", highlightthickness=1, highlightbackground="#31435f")
        self.preview.grid(row=3, column=0, columnspan=2, pady=(8, 0))

        footer = tk.Frame(self, bg=BG, padx=20, pady=18)
        footer.grid(row=2, column=0, sticky="ew")
        tk.Button(footer, text="发送到 FPGA", command=self.send, bg=ACCENT, fg="#062033",
                  activebackground="#7dd3fc", activeforeground="#062033", relief="flat",
                  font=("Microsoft YaHei UI", 10, "bold"), padx=22, pady=8, cursor="hand2").pack(side="left")
        tk.Button(footer, text="关闭字幕", command=self.clear, bg="#334155", fg=TEXT,
                  activebackground="#475569", activeforeground=TEXT, relief="flat",
                  font=("Microsoft YaHei UI", 10, "bold"), padx=18, pady=8, cursor="hand2").pack(side="left", padx=(10, 0))
        tk.Label(footer, textvariable=self.status, bg=BG, fg=MUTED, font=("Microsoft YaHei UI", 9)).pack(side="right", pady=8)

    def refresh_ports(self):
        try:
            from serial.tools import list_ports
            ports = [item.device for item in list_ports.comports()]
            self.port_box["values"] = ports
            if self.port.get() not in ports and ports:
                self.port.set(ports[0])
            self.status.set("已刷新串口：" + ("、".join(ports) if ports else "未发现设备"))
        except ModuleNotFoundError:
            self.status.set("缺少 pyserial：请执行 py -m pip install --user pyserial")

    def choose_font(self):
        path = filedialog.askopenfilename(filetypes=[("字体", "*.ttf *.ttc *.otf"), ("所有文件", "*.*")])
        if path:
            self.font.set(path)

    def bitmap(self):
        return rasterize(self.text.get("1.0", "end-1c"), self.font.get(), int(self.size.get()), 2,
                         center=not self.scroll.get())

    def update_preview(self):
        try:
            image = Image.new("RGB", (WIDTH, HEIGHT), LEVELS[0])
            for address, value in enumerate(self.bitmap()):
                y, word_x = divmod(address, WIDTH // 4)
                for lane in range(4):
                    image.putpixel((word_x * 4 + lane, y), LEVELS[(value >> (6 - lane * 2)) & 3])
            image = image.resize((640, 64), Image.Resampling.NEAREST)
            self.preview_image = ImageTk.PhotoImage(image)
            self.preview.configure(image=self.preview_image)
        except Exception:
            self.preview.configure(image="")

    def send(self):
        if not self.text.get("1.0", "end-1c"):
            messagebox.showerror("FPGA 字幕控制台", "请输入字幕内容")
            return
        try:
            import serial
            payload = packet(self.bitmap(), self.scroll.get(), int(self.speed.get()), 2)
            self.status.set("正在发送…")
            self.update_idletasks()
            with serial.Serial(self.port.get(), 115200, timeout=2) as port:
                port.reset_input_buffer()
                port.write(payload)
                port.flush()
                reply = port.read_until(b"\n").decode("ascii", "replace").strip()
            if reply != "OK":
                raise RuntimeError(f"FPGA 回包：{reply or '无响应'}")
            self.status.set("发送成功：FPGA 已在下一帧更新字幕")
        except Exception as exc:
            self.status.set("发送失败")
            messagebox.showerror("FPGA 字幕控制台", str(exc))

    def clear(self):
        try:
            import serial
            payload = packet(bytes(WIDTH * HEIGHT // 4), False, 1, 2, clear=True)
            with serial.Serial(self.port.get(), 115200, timeout=2) as port:
                port.reset_input_buffer()
                port.write(payload)
                port.flush()
                reply = port.read_until(b"\n").decode("ascii", "replace").strip()
            if reply != "OK":
                raise RuntimeError(f"FPGA 回包：{reply or '无响应'}")
            self.status.set("字幕已关闭：FPGA 已在下一帧更新")
        except Exception as exc:
            self.status.set("关闭失败")
            messagebox.showerror("FPGA 字幕控制台", str(exc))


if __name__ == "__main__":
    SubtitleSender().mainloop()
