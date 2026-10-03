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
