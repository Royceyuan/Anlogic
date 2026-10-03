"""Check five museum media folders and build a verified TF-card package."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from PIL import Image


HERE = Path(sys.executable if getattr(sys, "frozen", False) else __file__).resolve().parent
TOOLS = HERE.parent
sys.path.insert(0, str(TOOLS))

from generate_museum_osd_names import make_package  # noqa: E402
from generate_museum_subtitles import build_track, parse_srt  # noqa: E402


DEFAULT_SOURCE = HERE.parents[2] / "素材"
DEFAULT_OUTPUT = Path.home() / "Desktop"
FONT = Path(r"C:\Windows\Fonts\msyh.ttc")
MAX_IMAGE = (1920, 1080)
EXPECTED_TF_FILES = {
    *(f"IMAGE{i}.BMP" for i in range(5)),
    *(f"ART{i}D{detail}.BMP" for i in range(5) for detail in range(1, 4)),
    *(f"AUDIO{i}.WAV" for i in range(5)),
    *(f"SUB{i}.BIN" for i in range(5)),
    "OSDNAME.BIN",
}
HELP_TEXT = """一、准备素材

素材根目录必须包含且只包含 5 个文物文件夹，按编号排列：
    01_文物名称
    02_文物名称
    03_文物名称
    04_文物名称
    05_文物名称
编号 01～05 对应主板文物 0～4；下划线后的名称用于生成 OSD 名称。
请选择这五个文件夹的共同上级目录，不要只选择其中一个文物。

每个文物文件夹中准备以下 7 个文件：
    全貌图.png
    细节1.png
    细节2.png
    细节3.png
    讲解音频.wav
    字幕.srt
    图片切换脚本.md
图片也支持 .jpg / .jpeg，支持“细节1_特写.jpg”等带描述的文件名。
每个位置只放一张候选图片，避免多个文件时选到不想使用的版本。
名称位图固定为 160×16，过宽或过高会报错，不会静默截断。

二、检查与生成

1. 在主界面选择素材根目录和输出位置；输出位置建议使用电脑本地目录。
2. 字幕时间保持默认 direct，点击“1. 检查素材”。
3. 按错误提示修正文件，检查通过后点击“2. 生成 TF 素材包”。
4. 等待“生成并校验通过”，点击“打开输出目录”。
5. 先备份 TF 卡原素材，再将 TF_CARD 内全部 31 个文件复制到 FAT32 卡根目录。
6. 不要把 TF_CARD 文件夹本身、报告或清单复制到卡里；安全弹出后插回主板。

软件不直接写卡，不修改源素材，也不需要更换 FPGA bit。
检查通过不等于最终生成通过：切图脚本解析、字形生成和输出回读在生成时完成。
打包耗时较长时请等待；完成前不要关闭程序或重复点击生成。

三、图片与音频规则

图片：输出为 24 位 RGB BMP。上限 1920×1080；超过任一边时等比例缩小，
不拉伸、不裁剪，不放大小图。未超限图片保留尺寸。
报告记录输入尺寸和输出尺寸；离线缩小不能作为 FPGA 实时自适应的证明。

音频：输入使用未压缩 PCM WAV，不要仅把 MP3 后缀改成 WAV。
输出统一为 PCM16、48 kHz、双声道、标准 WAV 头。
EXE 内置 Python/Pillow，无需另装；非规范 WAV 转换仍需本机 FFmpeg。
找不到 FFmpeg 时，请安装并加入 PATH，或设置 FFMPEG 为 ffmpeg.exe 完整路径。
转换时不会弹出终端。名称和字幕栅格化使用 Windows 微软雅黑字体。

四、字幕时间选项

direct（推荐）：保留 SRT 原始时间戳；字幕超过音频长度就报错。
auto：字幕未超长时保留时间戳，超长时自动按音频总时长比例调整。
fit：始终按音频总时长比例调整所有字幕时间点。
auto / fit 都不是语音识别，也不能自动对齐每句话；只在确认需要时使用。
更换音频后，应先人工核对字幕和切图脚本，生成后再试听上板验证。

字幕.srt 示例（UTF-8；时间使用逗号分隔毫秒；条目之间留一空行）：
1
00:00:00,000 --> 00:00:03,000
这里填写第一句字幕

2
00:00:03,000 --> 00:00:06,000
这里填写第二句字幕

当前每件文物支持 1～32 条字幕，时间必须递增、不重叠、结束晚于开始。
字幕过长、在最小字号仍放不下时会报错，需要合理拆句。

五、图片切换脚本

图片顺序固定为：全貌 → 细节1 → 细节2 → 细节3 → 最终全貌。
图片切换脚本.md 使用 UTF-8；下面五行可复制后修改时间。
时间用 分:秒，保留反引号和图片名称两侧的双星号：

| 序号 | 时间范围 | 图片 |
| --- | --- | --- |
| 1 | `00:00–00:10` | **全貌** |
| 2 | `00:10–00:20` | **细节1** |
| 3 | `00:20–00:30` | **细节2** |
| 4 | `00:30–00:40` | **细节3** |
| 5 | `00:40–00:50` | **全貌** |

必须有五段，第一段从 00:00 开始。当前切图时间按脚本末尾时间与实际音频
总时长的比例换算；例如音频是 100 秒，上述 50 秒脚本的切点会翻倍。
建议脚本末尾时间与音频时长对应，并把讲到的内容安排在相应图片段落。
脚本仅控制切图时间，不改变主板转场类型和音频内容。

六、输出与常见问题

TF_CARD：20 张 BMP、5 个 WAV、5 个 SUB 字幕包、1 个 OSDNAME 名称包。
package_report.txt：尺寸、音频时长、字幕条数及文件 SHA-256。
package_manifest.json：完整素材清单及四个切图时间点（48 kHz 采样帧）。

“目录数量/名称不正确”：根目录只留 01_～05_，不要混入输出或备份目录。
“缺少文件”：按第一节核对文件名和扩展名，开启资源管理器的扩展名显示。
“SRT ends … after WAV”：先核对是否选错音频，不要用 fit 掩盖内容不匹配。
“名称/字幕超限”：缩短名称或拆分字幕，按生成错误提示处理。
“生成失败”：查看主界面日志；本次未完成目录会清理，既有包不覆盖。

最终检查：五栏名称正确；自动/手动切图正常；音频、字幕和图片内容相符。
格式及校验值通过只能证明文件生成完整，不能证明语义和逐句同步已经正确。
"""


def show_help(parent):
    import tkinter as tk
    from tkinter import ttk

    window = tk.Toplevel(parent)
    window.title("使用说明 — 博物馆 TF 素材打包工具")
    window.geometry("880x660")
    window.minsize(620, 420)
    window.transient(parent)
    frame = ttk.Frame(window, padding=16)
    frame.pack(fill="both", expand=True)
    ttk.Label(frame, text="从素材准备到 TF 卡使用", font=("Microsoft YaHei", 14, "bold")).pack(anchor="w", pady=(0, 12))
    body = ttk.Frame(frame)
    body.pack(fill="both", expand=True)
    text = tk.Text(body, wrap="word", font=("Microsoft YaHei", 11), padx=12, pady=8)
    scrollbar = ttk.Scrollbar(body, orient="vertical", command=text.yview)
    text.configure(yscrollcommand=scrollbar.set)
    scrollbar.pack(side="right", fill="y")
    text.pack(side="left", fill="both", expand=True)
    text.insert("1.0", HELP_TEXT)
    text.configure(state="disabled")
    ttk.Button(frame, text="关闭说明", command=window.destroy).pack(anchor="e", pady=(12, 0))
    window.bind("<Escape>", lambda event: window.destroy())
    return window


def artifact_folders(root: Path) -> list[Path]:
    folders = sorted(path for path in root.iterdir() if path.is_dir())
    if len(folders) != 5:
        raise ValueError(f"素材根目录应有 5 个文物目录，实际为 {len(folders)} 个")
    for number, folder in enumerate(folders, 1):
        prefix, separator, name = folder.name.partition("_")
        if not separator or prefix != f"{number:02d}" or not name:
            raise ValueError(f"目录应按 NN_文物名 排列：{folder.name}")
    return folders


def find_image(folder: Path, stem: str) -> Path:
    files = {path.name.lower(): path for path in folder.iterdir() if path.is_file()}
    for suffix in (".png", ".jpg", ".jpeg"):
        exact = files.get((stem + suffix).lower())
        if exact:
            return exact
    for suffix in (".png", ".jpg", ".jpeg"):
        matches = sorted(folder.glob(f"{stem}_*{suffix}"))
        if matches:
            return matches[0]
    raise FileNotFoundError(f"{folder.name} 缺少 {stem}.png/.jpg")


def source_images(folder: Path) -> list[tuple[str, Path]]:
    return [("全貌", find_image(folder, "全貌图"))] + [
        (f"细节{detail}", find_image(folder, f"细节{detail}"))
        for detail in range(1, 4)
    ]


def wav_info(path: Path) -> dict:
    file_size = path.stat().st_size
    with path.open("rb") as wav:
        riff = wav.read(12)
        if riff[0:4] != b"RIFF" or riff[8:12] != b"WAVE":
            raise ValueError(f"{path}: 不是 RIFF WAV")
        fmt = None
        data_size = None
        while wav.tell() + 8 <= file_size:
            chunk_id, chunk_size = struct.unpack("<4sI", wav.read(8))
            chunk_start = wav.tell()
            if chunk_id == b"fmt ":
                payload = wav.read(min(chunk_size, 40))
                if len(payload) < 16:
                    raise ValueError(f"{path}: fmt 块不完整")
                fmt = struct.unpack_from("<HHIIHH", payload)
            elif chunk_id == b"data":
                data_size = min(chunk_size, file_size - chunk_start)
                break
            wav.seek(min(file_size, chunk_start + chunk_size + (chunk_size & 1)))
    if fmt is None or data_size is None:
        raise ValueError(f"{path}: 缺少 fmt 或 data 块")
    audio_format, channels, rate, _, block_align, bits = fmt
    if audio_format != 1 or not channels or bits % 8 or block_align != channels * bits // 8:
        raise ValueError(f"{path}: 仅支持未压缩 PCM WAV")
    width = bits // 8
    frames = data_size // block_align
    return {
        "channels": channels,
        "sample_width": width,
        "sample_rate": rate,
        "frames": frames,
        "duration_s": frames / rate,
    }


def canonical_wav(path: Path) -> bool:
    header = path.read_bytes()[:44]
    if len(header) != 44:
        return False
    try:
        fields = struct.unpack("<4sI4s4sIHHIIHH4sI", header)
    except struct.error:
        return False
    return (
        fields[0] == b"RIFF" and fields[2] == b"WAVE" and fields[3] == b"fmt "
        and fields[4:11] == (16, 1, 2, 48_000, 192_000, 4, 16)
        and fields[11] == b"data" and fields[12] == path.stat().st_size - 44
    )


def find_ffmpeg() -> Path | None:
    candidates = [
        os.environ.get("FFMPEG"),
        shutil.which("ffmpeg"),
        str(Path(os.environ.get("CONDA_PREFIX", "")) / "Library/bin/ffmpeg.exe")
        if os.environ.get("CONDA_PREFIX") else None,
        r"D:\Anaconda\envs\Deep_Learning\Library\bin\ffmpeg.exe",
        r"D:\Anaconda\Library\bin\ffmpeg.exe",
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return Path(candidate)
    packages = sorted(Path(r"D:\Anaconda\pkgs").glob("ffmpeg-*/Library/bin/ffmpeg.exe"))
    return packages[-1] if packages else None


def inspect_source(root: Path, timing_mode: str = "direct") -> list[dict]:
    if not root.is_dir():
        raise FileNotFoundError(f"素材目录不存在：{root}")
    if not FONT.is_file():
        raise FileNotFoundError(f"缺少微软雅黑字体：{FONT}")
    rows = []
    needs_ffmpeg = False
    for index, folder in enumerate(artifact_folders(root)):
        images = []
        for label, path in source_images(folder):
            with Image.open(path) as opened:
                opened.verify()
            with Image.open(path) as opened:
                images.append({"label": label, "source": str(path),
                               "size": [opened.width, opened.height]})
        audio = folder / "讲解音频.wav"
        subtitle = folder / "字幕.srt"
        script = folder / "图片切换脚本.md"
        for required in (audio, subtitle, script):
            if not required.is_file():
                raise FileNotFoundError(f"{folder.name} 缺少 {required.name}")
        info = wav_info(audio)
        needs_ffmpeg |= not canonical_wav(audio)
        output_frames = round(info["duration_s"] * 48_000)
        cues = parse_srt(subtitle, output_frames, timing_mode)
        rows.append({
            "index": index,
            "name": folder.name.partition("_")[2],
            "folder": str(folder),
            "images": images,
            "audio": {**info, "source": str(audio),
                      "will_normalize": not canonical_wav(audio)},
            "subtitle_cues": len(cues),
        })
    if needs_ffmpeg and find_ffmpeg() is None:
        raise RuntimeError("音频需要转换，但未找到 FFmpeg；请安装 FFmpeg 或设置 FFMPEG 环境变量")
    return rows


def render_bmp(source: Path, target: Path) -> tuple[int, int]:
    with Image.open(source) as opened:
        image = opened.convert("RGB")
    image.thumbnail(MAX_IMAGE, Image.Resampling.LANCZOS)
    image.save(target, "BMP")
    return image.size


def normalize_wav(source: Path, target: Path, ffmpeg: Path | None) -> None:
    if canonical_wav(source):
        shutil.copy2(source, target)
        return
    if ffmpeg is None:
        raise RuntimeError(f"{source}: 需要 FFmpeg 转换为 PCM16/48kHz/双声道")
    raw = target.with_suffix(".pcm")
    try:
        result = subprocess.run([
            str(ffmpeg), "-hide_banner", "-loglevel", "error", "-y",
            "-i", str(source), "-map_metadata", "-1", "-vn",
            "-f", "s16le", "-acodec", "pcm_s16le", "-ar", "48000", "-ac", "2",
            str(raw),
        ], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        if result.returncode:
            raise RuntimeError(f"{source}: FFmpeg 转换失败\n{result.stderr.strip()}")
        data_size = raw.stat().st_size
        if data_size == 0 or data_size % 4:
            raise ValueError(f"{source}: 转换后的 PCM 数据长度无效")
        header = struct.pack(
            "<4sI4s4sIHHIIHH4sI", b"RIFF", 36 + data_size, b"WAVE",
            b"fmt ", 16, 1, 2, 48_000, 192_000, 4, 16, b"data", data_size,
        )
        with target.open("wb") as output, raw.open("rb") as pcm:
            output.write(header)
            shutil.copyfileobj(pcm, output, 1024 * 1024)
    finally:
        raw.unlink(missing_ok=True)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_tf(tf_root: Path) -> None:
    actual = {path.name for path in tf_root.iterdir() if path.is_file()}
    if actual != EXPECTED_TF_FILES:
        raise ValueError(
            f"TF 文件集合不正确；缺少 {sorted(EXPECTED_TF_FILES - actual)}，"
            f"多出 {sorted(actual - EXPECTED_TF_FILES)}"
        )
    for path in tf_root.glob("*.BMP"):
        with Image.open(path) as image:
            if image.format != "BMP" or image.mode != "RGB":
                raise ValueError(f"{path.name}: 必须为 24 位 RGB BMP")
            if image.width > MAX_IMAGE[0] or image.height > MAX_IMAGE[1]:
                raise ValueError(f"{path.name}: 超过 {MAX_IMAGE[0]}x{MAX_IMAGE[1]}")
    for path in tf_root.glob("AUDIO*.WAV"):
        if not canonical_wav(path):
            raise ValueError(f"{path.name}: WAV 头不符合主板读取格式")
    for path in tf_root.glob("SUB*.BIN"):
        header = path.read_bytes()[:512]
        if header[:5] != b"MSUB\x03" or len(header) != 512:
            raise ValueError(f"{path.name}: 字幕包头无效")
        expected_size = 512 + header[9] * 13 * 512
        if path.stat().st_size != expected_size:
            raise ValueError(f"{path.name}: 字幕包长度无效")
    names = tf_root / "OSDNAME.BIN"
    if names.stat().st_size != 3072 or names.read_bytes()[:5] != b"ONAM\x01":
        raise ValueError("OSDNAME.BIN 格式无效")


def build_package(root: Path, output: Path, timing_mode: str = "direct") -> Path:
    rows = inspect_source(root, timing_mode)
    output.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    building = output / f".museum_package_{stamp}.building"
    package = output / f"museum_package_{stamp}"
    tf_root = building / "TF_CARD"
    tf_root.mkdir(parents=True)
    try:
        ffmpeg = find_ffmpeg()
        folders = artifact_folders(root)
        for index, folder in enumerate(folders):
            for detail, (_, source) in enumerate(source_images(folder)):
                name = f"IMAGE{index}.BMP" if detail == 0 else f"ART{index}D{detail}.BMP"
                rows[index]["images"][detail]["output_size"] = list(
                    render_bmp(source, tf_root / name)
                )
            normalize_wav(folder / "讲解音频.wav", tf_root / f"AUDIO{index}.WAV", ffmpeg)
        subtitle_results = [
            build_track(index, folder, tf_root, tf_root, timing_mode)
            for index, folder in enumerate(folders)
        ]
        (tf_root / "OSDNAME.BIN").write_bytes(make_package(root, FONT))
        verify_tf(tf_root)

        files = [
            {"name": path.name, "bytes": path.stat().st_size, "sha256": sha256(path)}
            for path in sorted(tf_root.iterdir())
        ]
        manifest = {
            "format": "HX4S20C_MUSEUM_TF_PACKAGE_V1",
            "created": datetime.now().astimezone().isoformat(timespec="seconds"),
            "source": str(root.resolve()),
            "timing_mode": timing_mode,
            "image_limit": list(MAX_IMAGE),
            "artifacts": rows,
            "scene_cuts_48k_frames": [cuts for _, cuts in subtitle_results],
            "files": files,
        }
        (building / "package_manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        lines = [
            "HX4S20C 双屏博物馆 TF 素材包检查报告",
            f"生成时间：{manifest['created']}",
            f"源目录：{manifest['source']}",
            f"字幕时间模式：{timing_mode}",
            "结论：通过；TF_CARD 内 31 个文件已回读校验。",
            "",
        ]
        for row in rows:
            sizes = "，".join(
                f"{item['label']} {item['size'][0]}x{item['size'][1]}"
                + (f" → {item['output_size'][0]}x{item['output_size'][1]}"
                   if item["output_size"] != item["size"] else "")
                for item in row["images"]
            )
            lines.append(
                f"文物{row['index']} {row['name']}：{sizes}；"
                f"音频 {row['audio']['duration_s']:.3f}s；字幕 {row['subtitle_cues']} 条"
            )
        lines += ["", "TF 文件 SHA-256："] + [
            f"{item['sha256']}  {item['name']}" for item in files
        ]
        (building / "package_report.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
        building.rename(package)
    except Exception:
        shutil.rmtree(building, ignore_errors=True)
        raise
    return package


def launch_gui() -> None:
    import tkinter as tk
    from tkinter import filedialog, messagebox, ttk

    root = tk.Tk()
    root.title("博物馆 TF 素材打包工具")
    root.geometry("1020x610")
    root.minsize(860, 520)

    source_var = tk.StringVar(value=str(DEFAULT_SOURCE))
    output_var = tk.StringVar(value=str(DEFAULT_OUTPUT))
    timing_var = tk.StringVar(value="direct")
    status_var = tk.StringVar(value="请选择素材目录并执行检查")
    last_package = {"path": None}

    frame = ttk.Frame(root, padding=12)
    frame.pack(fill="both", expand=True)
    frame.columnconfigure(1, weight=1)
    frame.rowconfigure(4, weight=1)

    ttk.Label(frame, text="五件文物素材根目录").grid(row=0, column=0, sticky="w")
    ttk.Entry(frame, textvariable=source_var).grid(row=0, column=1, sticky="ew", padx=8)
    ttk.Button(frame, text="选择", command=lambda: source_var.set(
        filedialog.askdirectory(initialdir=source_var.get()) or source_var.get()
    )).grid(row=0, column=2)
    ttk.Label(frame, text="输出位置").grid(row=1, column=0, sticky="w", pady=8)
    ttk.Entry(frame, textvariable=output_var).grid(row=1, column=1, sticky="ew", padx=8)
    ttk.Button(frame, text="选择", command=lambda: output_var.set(
        filedialog.askdirectory(initialdir=output_var.get()) or output_var.get()
    )).grid(row=1, column=2)

    controls = ttk.Frame(frame)
    controls.grid(row=2, column=0, columnspan=3, sticky="ew")
    ttk.Label(controls, text="字幕时间：").pack(side="left")
    ttk.Combobox(controls, textvariable=timing_var, state="readonly", width=9,
                 values=("direct", "auto", "fit")).pack(side="left")

    columns = ("index", "name", "images", "audio", "subtitles", "status")
    table = ttk.Treeview(frame, columns=columns, show="headings", height=10)
    labels = ("编号", "文物名称", "图片尺寸", "音频", "字幕", "状态")
    widths = (55, 120, 430, 120, 70, 90)
    for column, label, width in zip(columns, labels, widths):
        table.heading(column, text=label)
        table.column(column, width=width, anchor="center")
    table.grid(row=4, column=0, columnspan=3, sticky="nsew", pady=(10, 6))

    log = tk.Text(frame, height=8, wrap="word", state="disabled")
    log.grid(row=5, column=0, columnspan=3, sticky="nsew")

    def show_rows(rows: list[dict]) -> None:
        table.delete(*table.get_children())
        for row in rows:
            sizes = " / ".join(f"{x['label']} {x['size'][0]}x{x['size'][1]}"
                               for x in row["images"])
            audio = row["audio"]
            audio_text = f"{audio['duration_s']:.1f}s / {audio['sample_rate']}Hz"
            status = "将规范化" if audio["will_normalize"] else "通过"
            table.insert("", "end", values=(row["index"], row["name"], sizes,
                         audio_text, row["subtitle_cues"], status))

    def write_log(text: str) -> None:
        log.configure(state="normal")
        log.delete("1.0", "end")
        log.insert("end", text)
        log.configure(state="disabled")

    def check() -> None:
        try:
            rows = inspect_source(Path(source_var.get()), timing_var.get())
            show_rows(rows)
            status_var.set("检查通过，可以生成素材包")
            write_log("检查通过。图片将保持宽高比；超过 1920x1080 才会缩小。\n"
                      "音频会统一输出为主板要求的 PCM16、48kHz、双声道规范 WAV。")
        except Exception as error:
            status_var.set("检查失败")
            write_log(str(error))
            messagebox.showerror("素材检查失败", str(error))

    def build() -> None:
        try:
            status_var.set("正在生成，请稍候……")
            root.update_idletasks()
            package = build_package(Path(source_var.get()), Path(output_var.get()), timing_var.get())
            last_package["path"] = package
            show_rows(inspect_source(Path(source_var.get()), timing_var.get()))
            status_var.set("生成并校验通过")
            write_log(f"素材包已生成：\n{package}\n\n"
                      "请将 TF_CARD 文件夹中的 31 个文件复制到 FAT32 TF 卡根目录。")
            messagebox.showinfo("生成成功", f"素材包已生成并校验通过：\n{package}")
        except Exception as error:
            status_var.set("生成失败")
            write_log(str(error))
            messagebox.showerror("生成失败", str(error))

    ttk.Button(controls, text="1. 检查素材", command=check).pack(side="left", padx=12)
    ttk.Button(controls, text="2. 生成 TF 素材包", command=build).pack(side="left")
    ttk.Button(controls, text="打开输出目录", command=lambda: os.startfile(
        last_package["path"] or Path(output_var.get())
    )).pack(side="left", padx=12)
    ttk.Button(controls, text="使用说明", command=lambda: show_help(root)).pack(side="right")
    ttk.Label(frame, textvariable=status_var).grid(row=6, column=0, columnspan=3,
                                                   sticky="w", pady=(8, 0))
    root.mainloop()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--check", type=Path, metavar="SOURCE")
    action.add_argument("--build", type=Path, metavar="SOURCE")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--timing-mode", choices=("direct", "auto", "fit"), default="direct")
    args = parser.parse_args()
    if args.check:
        rows = inspect_source(args.check, args.timing_mode)
        for row in rows:
            print(f"PASS {row['index']} {row['name']}: "
                  f"4 images, {row['audio']['duration_s']:.3f}s, "
                  f"{row['subtitle_cues']} subtitles")
        return 0
    if args.build:
        print(build_package(args.build, args.output, args.timing_mode))
        return 0
    launch_gui()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
