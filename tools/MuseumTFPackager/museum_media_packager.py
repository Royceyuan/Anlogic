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
import wave
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from pathlib import Path

from PIL import Image


HERE = Path(sys.executable if getattr(sys, "frozen", False) else __file__).resolve().parent
RUNTIME = HERE / "MuseumTFPackager" if not (HERE / "AlignmentWorker").is_dir() and (HERE / "MuseumTFPackager").is_dir() else HERE
TOOLS = HERE.parent
sys.path.insert(0, str(TOOLS))

from generate_museum_osd_names import make_package  # noqa: E402
from generate_museum_subtitles import build_track, parse_srt  # noqa: E402


DEFAULT_SOURCE = HERE.parent.parent.parent / "素材"
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

每个文物文件夹只需准备以下 6 个文件：
    全貌图.png
    细节1.png
    细节2.png
    细节3.png
    讲解音频.wav
    字幕.srt
WAV 和 SRT 文件名不限，每个文物目录各放一个即可；无需切图脚本。
图片也支持 .jpg / .jpeg / .bmp，支持“细节1_特写.jpg”等带描述的文件名。
每个位置只放一张候选图片，避免多个文件时选到不想使用的版本。
名称位图固定为 160×16，过宽或过高会报错，不会静默截断。

二、检查与生成

1. 在主界面选择素材根目录和输出位置；输出位置建议使用电脑本地目录。
2. SRT 已同步时使用 direct；不同步时勾选“本地校准字幕”，点击“1. 检查素材”。
3. 修正错误；需要精确音画对应时点击“设置切图句”，再点击“2. 生成 TF 素材包”。
4. 等待“生成并校验通过”，点击“打开输出目录”。
5. 先备份 TF 卡原素材，再将 TF_CARD 内全部 31 个文件复制到 FAT32 卡根目录。
6. 不要把 TF_CARD 文件夹本身、报告或清单复制到卡里；安全弹出后插回主板。

软件不直接写卡，不修改源素材，也不需要更换 FPGA bit。
检查通过不等于最终生成通过：音频解码、字形生成和输出回读在生成时完成。
打包耗时较长时请等待；完成前不要关闭程序或重复点击生成。

三、图片与音频规则

图片：输出为 24 位 RGB BMP。上限 1920×1080；超过任一边时等比例缩小，
不拉伸、不裁剪，不放大小图。未超限图片保留尺寸。
报告记录输入尺寸和输出尺寸；离线缩小不能作为 FPGA 实时自适应的证明。

音频：不要求输入固定采样率、位深或声道；支持转换器能解码的有效 WAV，
包括常见 PCM、浮点和 ADPCM。不要仅把 MP3 后缀改成 WAV。
输出统一为 PCM16、48 kHz、双声道、标准 WAV 头。
EXE 内置 Python/Pillow；完整离线包附带 FFmpeg、ffprobe、校准组件及模型，无需另装。
单独 EXE 不包含大模型，非规范 WAV 需本机 FFmpeg 及同目录 ffprobe.exe。
找不到 FFmpeg 时，请安装并加入 PATH，或设置 FFMPEG 为 ffmpeg.exe 完整路径。
转换时不会弹出终端。名称和字幕栅格化使用 Windows 微软雅黑字体。

四、字幕时间与本地校准

勾选“本地校准字幕”：以音频为依据重新定位每句起止时间，保留原字幕文字、句数和顺序。
需保留 EXE 同目录的 AlignmentWorker 和 models 文件夹；模型仅在电脑运行，不放入 TF 卡。
当前校准针对中文讲解，使用 CPU，无需 CUDA。耗时随电脑性能及音频长度变化。
校准期间界面可响应，但不要关闭程序；运行禁止联网，不上传音频。
原 SRT 不会被覆盖；结果另存 aligned_subtitles/SUB0.srt～SUB4.srt，便于试听核对。
alignment_report.json 记录每句时间及匹配提示；低置信度句子需重点试听。
模型不能保证所有句子绝对准确；漏句、多句、噪声、错误文字可能校准失败或产生偏差。
失败会停止生成，不偷偷改用等比例压缩。不勾选时才使用以下 direct/auto/fit 选项。

direct（推荐）：保留 SRT 原始时间戳；字幕超过音频长度就报错。
auto：字幕未超长时保留时间戳，超长时自动按音频总时长比例调整。
fit：始终按音频总时长比例调整所有字幕时间点。
auto / fit 都不是语音识别，也不能自动对齐每句话；只在确认需要时使用。
更换音频后，字幕文字应与音频对应，生成后再试听上板验证。
格式转换不等于语音自动对齐；保留时间戳时不会修正已有的逐句时间错误。

SRT 支持 UTF-8（含 BOM）、UTF-16/32 BOM、GBK/GB18030，常见换行与空格，
逗号或点号毫秒以及多行文本。常见粗体/斜体标签转成纯文字。
字幕.srt 示例（条目之间留一空行）：
1
00:00:00,000 --> 00:00:03,000
这里填写第一句字幕

2
00:00:03,000 --> 00:00:06,000
这里填写第二句字幕

当前每件文物支持 1～32 条字幕，时间必须递增、不重叠、结束晚于开始。
字幕过长、在最小字号仍放不下时会报错，需要合理拆句。

五、切图对应讲解（不用写脚本）

点击“设置切图句”，按文物分别选择细节1、细节2、细节3、最终全貌对应的字幕句。
初始全貌从音频起点开始，四个切点使用所选句的开始时间；必须递增且不在音频起点。
勾选校准时，先校准 SRT，再使用这些句子的新时间生成切点；不会使用过时的原时间。
每件文物可独立设置；没有设置的文物按下面的自动/兼容脚本规则处理。
设置只保留在本次软件会话；换素材目录会清空，替换 SRT 后需重新设置。

图片顺序固定为：全貌 → 细节1 → 细节2 → 细节3 → 最终全貌。
没有脚本时，按实际转换后的音频时长分为五段，自动生成四个切点。
例如 50 秒音频在 10、20、30、40 秒切图；字幕仍使用原有时间戳。
这只是自动时间安排，不会识别音频正在讲哪张细节图。
已有素材带“图片切换脚本.md”时仍优先使用旧切点，避免改变既有展示节奏。
它是兼容历史素材的可选项，新素材不必准备。报告标明使用自动或脚本切图。

六、输出与常见问题

TF_CARD：20 张 BMP、5 个 WAV、5 个 SUB 字幕包、1 个 OSDNAME 名称包。
仅包含主板正常展陈素材；请保留原卡上的应急素材，不替换副板素材。
package_report.txt：尺寸、音频时长、字幕条数及文件 SHA-256。
package_manifest.json：完整素材清单及四个切图时间点（48 kHz 采样帧）。
启用校准时，aligned_subtitles 和 alignment_report.json 也留在电脑，不复制到 TF 卡。

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
    text = tk.Text(body, wrap="word", font=("Microsoft YaHei", 11), padx=12, pady=8,
                   background="#fffdf7", foreground="#213e38", relief="flat")
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
    for suffix in (".png", ".jpg", ".jpeg", ".bmp"):
        exact = files.get((stem + suffix).lower())
        if exact:
            return exact
    for suffix in (".png", ".jpg", ".jpeg", ".bmp"):
        matches = sorted(folder.glob(f"{stem}_*{suffix}"))
        if matches:
            return matches[0]
    raise FileNotFoundError(f"{folder.name} 缺少 {stem}.png/.jpg/.bmp")


def find_media(folder: Path, suffix: str) -> Path:
    matches = sorted(path for path in folder.iterdir() if path.is_file() and path.suffix.lower() == suffix)
    if len(matches) != 1:
        raise ValueError(f"{folder.name} 应恰好有一个 {suffix} 文件，实际 {len(matches)} 个")
    return matches[0]


def source_images(folder: Path) -> list[tuple[str, Path]]:
    return [("全貌", find_image(folder, "全貌图"))] + [
        (f"细节{detail}", find_image(folder, f"细节{detail}"))
        for detail in range(1, 4)
    ]


def wav_info(path: Path) -> dict:
    if canonical_wav(path):
        with wave.open(str(path), "rb") as wav:
            return {"channels": wav.getnchannels(), "sample_width": wav.getsampwidth(),
                    "sample_rate": wav.getframerate(), "frames": wav.getnframes(),
                    "duration_s": wav.getnframes() / wav.getframerate(), "codec": "pcm_s16le"}
    ffmpeg = find_ffmpeg()
    probe = ffmpeg.with_name("ffprobe.exe") if ffmpeg else None
    if probe is None or not probe.is_file():
        raise RuntimeError("非标准 WAV 需 FFmpeg 与同目录 ffprobe.exe，请安装完整 FFmpeg 或设置 FFMPEG 路径")
    result = subprocess.run([
        str(probe), "-v", "error", "-select_streams", "a:0", "-show_entries",
        "stream=codec_name,sample_rate,channels,bits_per_sample,bits_per_raw_sample,duration:format=format_name,duration",
        "-of", "json", str(path),
    ], capture_output=True, text=True, encoding="utf-8", errors="replace",
        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    if result.returncode:
        raise ValueError(f"{path}: 无法读取 WAV\n{result.stderr.strip()}")
    metadata = json.loads(result.stdout)
    streams = metadata.get("streams", [])
    container = metadata.get("format", {})
    if not streams or container.get("format_name") != "wav":
        raise ValueError(f"{path}: 文件内容不是有效 WAV 音频，不能仅修改扩展名")
    stream = streams[0]
    rate, channels = int(stream["sample_rate"]), int(stream["channels"])
    duration = float(container.get("duration", stream.get("duration", 0)))
    bits = int(stream.get("bits_per_raw_sample") or stream.get("bits_per_sample") or 0)
    if rate <= 0 or channels <= 0 or duration <= 0:
        raise ValueError(f"{path}: WAV 时长或音频参数无效")
    return {
        "channels": channels, "sample_width": (bits + 7) // 8 if bits else None,
        "sample_rate": rate, "frames": round(duration * rate),
        "duration_s": duration, "codec": stream.get("codec_name"),
    }


def canonical_wav(path: Path) -> bool:
    with path.open("rb") as wav:
        header = wav.read(44)
    if len(header) != 44:
        return False
    try:
        fields = struct.unpack("<4sI4s4sIHHIIHH4sI", header)
    except struct.error:
        return False
    return (
        fields[0] == b"RIFF" and fields[2] == b"WAVE" and fields[3] == b"fmt "
        and fields[1] == path.stat().st_size - 8
        and fields[4:11] == (16, 1, 2, 48_000, 192_000, 4, 16)
        and fields[11] == b"data" and fields[12] == path.stat().st_size - 44
        and fields[12] > 0 and fields[12] % 4 == 0
    )


def find_ffmpeg() -> Path | None:
    candidates = [
        str(HERE / "ffmpeg" / "ffmpeg.exe"),
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


def inspect_source(root: Path, timing_mode: str = "direct", align_subtitles: bool = False) -> list[dict]:
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
        audio = find_media(folder, ".wav")
        subtitle = find_media(folder, ".srt")
        info = wav_info(audio)
        needs_ffmpeg |= not canonical_wav(audio)
        output_frames = round(info["duration_s"] * 48_000)
        cues = parse_srt(subtitle, output_frames, timing_mode, check_timing=not align_subtitles)
        rows.append({
            "index": index,
            "name": folder.name.partition("_")[2],
            "folder": str(folder),
            "images": images,
            "audio": {**info, "source": str(audio),
                      "will_normalize": not canonical_wav(audio)},
            "subtitle_cues": len(cues),
            "subtitle_source": str(subtitle),
            "subtitle_sha256": sha256(subtitle),
            "scene_timing": "script" if (folder / "图片切换脚本.md").is_file() else "auto_equal_fifths",
        })
    if needs_ffmpeg and find_ffmpeg() is None:
        raise RuntimeError("音频需要转换，但未找到 FFmpeg；请安装 FFmpeg 或设置 FFMPEG 环境变量")
    return rows


def alignment_command() -> list[str]:
    worker = HERE / "AlignmentWorker" / "AlignmentWorker.exe"
    model = HERE / "models" / "small.pt"
    if not worker.is_file() or not model.is_file():
        raise FileNotFoundError("本地校准组件不完整，请使用完整离线包（AlignmentWorker、models 与 EXE 同目录）")
    return [str(worker), "--model", str(model)]


def align_subtitle_files(folders: list[Path], building: Path, rows: list[dict]) -> tuple[list[Path], dict]:
    paths = [building / "aligned_subtitles" / f"SUB{index}.srt" for index in range(5)]
    request = [{"audio": str(building / "TF_CARD" / f"AUDIO{index}.WAV"),
                "texts": [text for _, _, text in parse_srt(find_media(folder, ".srt"), 0, "direct", False)],
                "output": str(paths[index])} for index, folder in enumerate(folders)]
    request_path, result_path = building / "alignment_request.json", building / "alignment_report.json"
    request_path.write_text(json.dumps(request, ensure_ascii=False), encoding="utf-8")
    result = subprocess.run(alignment_command() + ["--request", str(request_path), "--result", str(result_path)],
                            capture_output=True, creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
    if not result_path.is_file():
        raise RuntimeError(f"校准组件未返回结果（退出码 {result.returncode}）："
                           + result.stderr.decode("utf-8", errors="replace")[-1500:])
    report = json.loads(result_path.read_text(encoding="utf-8"))
    if result.returncode or "error" in report:
        raise RuntimeError(report.get("error", "字幕校准失败"))
    if len(report.get("tracks", [])) != len(folders):
        raise ValueError("字幕校准结果不完整")
    for index, folder in enumerate(folders):
        aligned = parse_srt(paths[index], round(report["tracks"][index]["duration_s"] * 48000), "direct")
        original = parse_srt(find_media(folder, ".srt"), 0, "direct", False)
        if [text for _, _, text in aligned] != [text for _, _, text in original]:
            raise ValueError(f"{folder.name} 校准后字幕文字或顺序发生变化")
        report["tracks"][index]["audio"] = f"TF_CARD/AUDIO{index}.WAV"
        report["tracks"][index]["subtitle"] = f"aligned_subtitles/SUB{index}.srt"
        rows[index]["alignment_warnings"] = report["tracks"][index]["warnings"]
    request_path.unlink()
    result_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return paths, report


def scene_cuts_from_cues(cues: list[tuple], numbers: list[int], total_frames: int) -> list[int]:
    if len(numbers) != 4 or any(type(number) is not int or not 1 <= number <= len(cues) for number in numbers):
        raise ValueError("请为细节1、细节2、细节3、最终全貌选择四条有效字幕")
    cuts = [cues[number - 1][0] for number in numbers]
    if not 0 < cuts[0] < cuts[1] < cuts[2] < cuts[3] < total_frames:
        raise ValueError("四个切图句的开始时间需递增，且不能在音频起点或结束点")
    return cuts


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
            "-i", str(source), "-map", "0:a:0", "-map_metadata", "-1", "-vn",
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


def build_package(root: Path, output: Path, timing_mode: str = "direct",
                  align_subtitles: bool = False, scene_choices: dict | None = None) -> Path:
    root, output = root.resolve(), output.resolve()
    if output.is_relative_to(root):
        raise ValueError("输出位置请选择素材根目录之外，避免生成目录干扰五个文物目录")
    rows = inspect_source(root, timing_mode, align_subtitles)
    if align_subtitles:
        alignment_command()
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
            normalize_wav(find_media(folder, ".wav"), tf_root / f"AUDIO{index}.WAV", ffmpeg)
        subtitles = [find_media(folder, ".srt") for folder in folders]
        if align_subtitles:
            subtitles, _ = align_subtitle_files(folders, building, rows)
        subtitle_results = []
        for index, folder in enumerate(folders):
            cuts = None
            choice = (scene_choices or {}).get(folder.name)
            actual_timing = "direct" if align_subtitles else timing_mode
            if choice:
                if choice["subtitle_sha256"] != rows[index]["subtitle_sha256"]:
                    raise ValueError(f"{folder.name} 字幕已更换，请重新选择切图句")
                with wave.open(str(tf_root / f"AUDIO{index}.WAV"), "rb") as wav:
                    total = wav.getnframes()
                cuts = scene_cuts_from_cues(parse_srt(subtitles[index], total, actual_timing), choice["cues"], total)
                rows[index]["scene_timing"] = "subtitle_cues"
                rows[index]["scene_cue_numbers"] = choice["cues"]
            subtitle_results.append(build_track(index, folder, tf_root, tf_root, actual_timing, subtitles[index], cuts))
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
            "align_subtitles": align_subtitles,
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
            f"本地逐句校准：{'启用；保留文字，需试听校准结果' if align_subtitles else '关闭；未修改逐句时间'}",
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
                f"音频 {row['audio']['duration_s']:.3f}s；字幕 {row['subtitle_cues']} 条；"
                f"切图 {dict(script='可选脚本', auto_equal_fifths='自动五等分', subtitle_cues='对应字幕句')[row['scene_timing']]}"
            )
            lines.extend(row.get("alignment_warnings", []))
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
    from PIL import ImageTk

    root = tk.Tk()
    root.title("博物馆 TF 素材打包工具")
    root.geometry("1120x780")
    root.minsize(980, 720)
    root.configure(background="#162d2a")
    assets = Path(getattr(sys, "_MEIPASS", HERE)) / "theme"
    icon = ImageTk.PhotoImage(Image.open(assets / "icon.png").resize((64, 64), Image.Resampling.LANCZOS))
    root.iconphoto(True, icon)
    style = ttk.Style(root)
    style.theme_use("clam")
    style.configure(".", font=("Microsoft YaHei UI", 10), foreground="#213e38")
    style.configure("TFrame", background="#f6f3eb")
    style.configure("TLabel", background="#f6f3eb")
    style.configure("TCheckbutton", background="#f6f3eb", padding=(0, 8))
    style.map("TCheckbutton", background=[("active", "#f6f3eb")])
    style.configure("TButton", background="#e5eade", bordercolor="#c1cec3", padding=(12, 8))
    style.map("TButton", background=[("disabled", "#e6e6df"), ("pressed", "#cbd9c9"), ("active", "#d5e3d1")],
              foreground=[("disabled", "#89918b")])
    style.configure("Accent.TButton", background="#225b4e", foreground="#fffdf7", bordercolor="#225b4e")
    style.map("Accent.TButton", background=[("disabled", "#d1dbd2"), ("pressed", "#174538"), ("active", "#33735f")],
              foreground=[("disabled", "#77857c")])
    style.configure("TEntry", padding=7, fieldbackground="#fffdf7")
    style.configure("TCombobox", padding=5, fieldbackground="#fffdf7")
    style.map("TCombobox", fieldbackground=[("readonly", "#fffdf7")], selectbackground=[("readonly", "#e1e9dd")],
              selectforeground=[("readonly", "#213e38")])
    style.configure("Treeview", background="#fffdf7", fieldbackground="#fffdf7", rowheight=34, borderwidth=0)
    style.configure("Treeview.Heading", background="#dfe7dc", padding=(8, 9), font=("Microsoft YaHei UI", 10, "bold"))
    style.map("Treeview", background=[("selected", "#225b4e")], foreground=[("selected", "#fffdf7")])
    canvas = tk.Canvas(root, highlightthickness=0, background="#162d2a")
    canvas.pack(fill="both", expand=True)
    wallpaper = Image.open(assets / "wallpaper.png")
    backdrop = canvas.create_image(0, 0, anchor="nw")
    canvas.create_image(28, 30, image=icon, anchor="nw")
    canvas.create_text(110, 38, text="博物馆素材工坊", anchor="nw", fill="#fff6df", font=("Microsoft YaHei UI", 23, "bold"))
    canvas.create_text(112, 80, text="TF 素材打包  /  图片 · 音频 · 字幕 · 文物名称", anchor="nw",
                       fill="#d7cbae", font=("Microsoft YaHei UI", 11))
    resize_job = {"id": None}

    def resize(event):
        canvas.itemconfigure(card, width=max(1, event.width - 48), height=max(1, event.height - 160))
        if resize_job["id"] is not None:
            root.after_cancel(resize_job["id"])

        def redraw():
            canvas.wallpaper_image = ImageTk.PhotoImage(wallpaper.resize(
                (max(1, event.width), max(1, event.height)), Image.Resampling.LANCZOS))
            canvas.itemconfigure(backdrop, image=canvas.wallpaper_image)
            resize_job["id"] = None
        resize_job["id"] = root.after(90, redraw)

    source_var = tk.StringVar(value=str(DEFAULT_SOURCE))
    output_var = tk.StringVar(value=str(DEFAULT_OUTPUT))
    timing_var = tk.StringVar(value="direct")
    alignment_var = tk.BooleanVar(value=False)
    status_var = tk.StringVar(value="请选择素材目录并执行检查")
    last_package = {"path": None}
    scene_choices = {}
    source_var.trace_add("write", lambda *args: scene_choices.clear())
    executor = ThreadPoolExecutor(max_workers=1)
    pending = {"future": None}

    frame = ttk.Frame(canvas, padding=18)
    card = canvas.create_window(24, 132, anchor="nw", window=frame)
    canvas.bind("<Configure>", resize)
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
    controls.grid(row=3, column=0, columnspan=3, sticky="ew", pady=(8, 0))
    settings = ttk.Frame(frame)
    settings.grid(row=2, column=0, columnspan=3, sticky="ew")
    ttk.Checkbutton(settings, text="本地校准字幕（保留文字）", variable=alignment_var).pack(side="left")
    ttk.Label(settings, text="  不校准时的时间处理：").pack(side="left")
    ttk.Combobox(settings, textvariable=timing_var, state="readonly", width=9,
                 values=("direct", "auto", "fit")).pack(side="left")

    columns = ("index", "name", "images", "audio", "subtitles", "status")
    table = ttk.Treeview(frame, columns=columns, show="headings", height=5)
    labels = ("编号", "文物名称", "图片尺寸", "音频", "字幕", "状态")
    widths = (48, 112, 430, 120, 64, 84)
    for column, label, width in zip(columns, labels, widths):
        table.heading(column, text=label)
        table.column(column, width=width, anchor="center")
    table.grid(row=4, column=0, columnspan=3, sticky="nsew", pady=(10, 6))

    log = tk.Text(frame, height=7, wrap="word", state="disabled", font=("Microsoft YaHei UI", 10),
                  background="#fffdf7", foreground="#35524a", relief="flat", padx=12, pady=10)
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

    def perform(work, success, label):
        if pending["future"] is not None:
            return
        status_var.set(label + "，请稍候；校准可能需要数分钟……")
        for button in task_buttons:
            button.configure(state="disabled")
        pending["future"] = executor.submit(work)

        def poll():
            future = pending["future"]
            if not future.done():
                root.after(200, poll)
                return
            pending["future"] = None
            for button in task_buttons:
                button.configure(state="normal")
            try:
                success(future.result())
            except Exception as error:
                status_var.set(label + "失败")
                write_log(str(error))
                messagebox.showerror(label + "失败", str(error), parent=root)
        root.after(200, poll)

    def check() -> None:
        source, timing, align = Path(source_var.get()), timing_var.get(), alignment_var.get()

        def work():
            if align:
                alignment_command()
            return inspect_source(source, timing, align)

        def success(rows):
            show_rows(rows)
            status_var.set("格式检查通过，可以生成；校准与输出回读在生成时执行")
            write_log("图片保持宽高比，音频统一为 PCM16/48kHz/双声道。\n"
                      "可点击“设置切图句”选择对应讲解；未设置时使用脚本或五等分。")
        perform(work, success, "检查素材")

    def build() -> None:
        source, output = Path(source_var.get()), Path(output_var.get())
        timing, align, choices = timing_var.get(), alignment_var.get(), dict(scene_choices)

        def success(package):
            last_package["path"] = package
            manifest = json.loads((package / "package_manifest.json").read_text(encoding="utf-8"))
            show_rows(manifest["artifacts"])
            status_var.set("生成并校验通过")
            write_log(f"素材包已生成：\n{package}\n\n"
                      "TF_CARD 内 31 个文件复制到 FAT32 卡根目录；校准后请试听 aligned_subtitles。\n"
                      + "\n".join(f"文物{row['index']}：{warning}" for row in manifest["artifacts"]
                                  for warning in row.get("alignment_warnings", [])))
            messagebox.showinfo("生成成功", f"素材包已生成并校验通过：\n{package}")
        perform(lambda: build_package(source, output, timing, align, choices), success, "生成素材包")

    def choose_scenes():
        try:
            rows = inspect_source(Path(source_var.get()), timing_var.get(), alignment_var.get())
        except Exception as error:
            messagebox.showerror("无法设置切图句", str(error), parent=root)
            return
        window = tk.Toplevel(root)
        window.title("选择四个切图句 — 校准后自动使用新时间")
        window.geometry("850x440")
        ttk.Label(window, text="每件文物选四句，按顺序开始细节1、细节2、细节3、最终全貌；全部留空使用自动/脚本切图。",
                  wraplength=800).pack(padx=16, pady=12)
        notebook = ttk.Notebook(window)
        notebook.pack(fill="both", expand=True, padx=16)
        fields = []
        for row in rows:
            page = ttk.Frame(notebook, padding=12)
            notebook.add(page, text=f"{row['index']} {row['name']}")
            cues = parse_srt(Path(row["subtitle_source"]), 0, "direct", False)
            options = ["自动/兼容脚本"] + [f"{index}. {text}" for index, (_, _, text) in enumerate(cues, 1)]
            saved = scene_choices.get(Path(row["folder"]).name, {})
            previous = saved.get("cues", []) if saved.get("subtitle_sha256") == row["subtitle_sha256"] else []
            combos = []
            for index, label in enumerate(("开始细节1", "开始细节2", "开始细节3", "恢复最终全貌")):
                ttk.Label(page, text=label).grid(row=index, column=0, sticky="w", pady=10)
                combo = ttk.Combobox(page, values=options, state="readonly", width=68)
                combo.grid(row=index, column=1, padx=12)
                combo.current(previous[index] if previous else 0)
                combos.append(combo)
            fields.append((row, combos))

        def save():
            selected = {}
            for row, combos in fields:
                numbers = [combo.current() for combo in combos]
                if not any(numbers):
                    continue
                if not 0 < numbers[0] < numbers[1] < numbers[2] < numbers[3]:
                    messagebox.showerror("切图句不正确", f"{row['name']}：请选择四条依次递增的字幕句", parent=window)
                    return
                selected[Path(row["folder"]).name] = {"cues": numbers, "subtitle_sha256": row["subtitle_sha256"]}
            scene_choices.clear()
            scene_choices.update(selected)
            status_var.set(f"已为 {len(selected)} 件文物设置切图句；生成时跟随实际字幕时间")
            window.destroy()
        ttk.Button(window, text="保存切图句", command=save).pack(pady=12)
        window.transient(root)
        window.grab_set()

    check_button = ttk.Button(controls, text="1. 检查素材", command=check)
    check_button.pack(side="left", padx=(0, 12))
    scenes_button = ttk.Button(controls, text="设置切图句", command=choose_scenes)
    scenes_button.pack(side="left", padx=(0, 12))
    build_button = ttk.Button(controls, text="2. 生成 TF 素材包", command=build, style="Accent.TButton")
    build_button.pack(side="left")
    task_buttons = (check_button, scenes_button, build_button)
    ttk.Button(controls, text="打开输出目录", command=lambda: os.startfile(
        last_package["path"] or Path(output_var.get())
    )).pack(side="left", padx=12)
    ttk.Button(controls, text="使用说明", command=lambda: show_help(root)).pack(side="right")
    ttk.Label(frame, textvariable=status_var).grid(row=6, column=0, columnspan=3,
                                                   sticky="w", pady=(8, 0))
    def close():
        if pending["future"] is not None:
            messagebox.showinfo("正在处理", "请等待处理完成后关闭，避免中断生成。", parent=root)
            return
        executor.shutdown(wait=False)
        root.destroy()
    root.protocol("WM_DELETE_WINDOW", close)
    root.mainloop()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--check", type=Path, metavar="SOURCE")
    action.add_argument("--build", type=Path, metavar="SOURCE")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--timing-mode", choices=("direct", "auto", "fit"), default="direct")
    parser.add_argument("--align-subtitles", action="store_true")
    parser.add_argument("--scene-cues", type=Path, help="JSON with folder names, subtitle_sha256 and four 1-based cue indices")
    args = parser.parse_args()
    if args.check:
        if args.align_subtitles:
            alignment_command()
        rows = inspect_source(args.check, args.timing_mode, args.align_subtitles)
        for row in rows:
            print(f"PASS {row['index']} {row['name']}: "
                  f"4 images, {row['audio']['duration_s']:.3f}s, "
                  f"{row['subtitle_cues']} subtitles")
        return 0
    if args.build:
        choices = json.loads(args.scene_cues.read_text(encoding="utf-8")) if args.scene_cues else None
        print(build_package(args.build, args.output, args.timing_mode, args.align_subtitles, choices))
        return 0
    launch_gui()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
