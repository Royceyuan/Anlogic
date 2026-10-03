"""Run the standalone windowed EXE against temporary media, not the TF card."""

import argparse
import json
import os
from pathlib import Path
import struct
import subprocess
import shutil
import tempfile
import tkinter as tk
from unittest.mock import patch
import wave

from PIL import Image

from museum_media_packager import (
    HELP_TEXT, build_package, canonical_wav, find_ffmpeg, normalize_wav, sha256,
    show_help, verify_tf,
)
from generate_museum_subtitles import parse_srt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true", help="Also exercise the relocated complete package")
    args = parser.parse_args()
    gui = tk.Tk()
    gui.withdraw()
    try:
        help_window = show_help(gui)
        gui.update()
        body = help_window.winfo_children()[0].winfo_children()[1]
        text = next(widget for widget in body.winfo_children() if isinstance(widget, tk.Text))
        assert text.get("1.0", "end-1c") == HELP_TEXT
        assert text.cget("state") == "disabled"
        text.yview_moveto(1.0)
        gui.update()
        assert text.yview()[0] > 0, "Help must scroll"
        help_window.destroy()
        assert gui.winfo_exists(), "Closing help must not close the packager"
        print("PASS help page: embedded content, read-only, scroll, independent close")
    finally:
        gui.destroy()
    exe = Path(__file__).resolve().with_name("MuseumTFPackager.exe")
    binary = exe.read_bytes()
    pe = struct.unpack_from("<I", binary, 0x3C)[0]
    assert binary[pe:pe + 4] == b"PE\0\0"
    assert struct.unpack_from("<H", binary, pe + 24 + 68)[0] == 2, "Must be GUI, not console"
    with tempfile.TemporaryDirectory(prefix="museum_exe_test_") as temporary:
        root = Path(temporary)
        # Copy only the EXE: no source modules or Python beside the runnable file.
        portable = root / exe.name
        portable.write_bytes(binary)
        source = root / "素材"
        for index in range(1, 6):
            folder = source / f"{index:02d}_文物"
            folder.mkdir(parents=True)
            for name, size in zip(("全貌图", "细节1", "细节2", "细节3"),
                                  ((640, 480), (720, 1080), (1080, 1080), (1921, 1081))):
                Image.new("RGB", size, (30 * index, 70, 120)).save(folder / f"{name}.png")
            with wave.open(str(folder / "讲解音频.wav"), "wb") as wav:
                wav.setparams((2, 2, 48000, 0, "NONE", "not compressed"))
                wav.writeframes(bytes(5 * 48000 * 4))
            (folder / "字幕.srt").write_text(
                "1\n00:00:00,000 --> 00:00:04,000\n测试字幕\n", encoding="utf-8")
            (folder / "图片切换脚本.md").write_text("\n".join(
                f"| {scene + 1} | `00:0{scene}–00:0{scene + 1}` | **{label}** |"
                for scene, label in enumerate(("全貌", "细节1", "细节2", "细节3", "全貌"))
            ), encoding="utf-8")
        environment = os.environ.copy()
        environment.pop("PYTHONPATH", None)
        environment.pop("PYTHONHOME", None)
        environment["PATH"] = str(Path(os.environ["SystemRoot"]) / "System32")
        def run(*args):
            return subprocess.run([str(portable), *map(str, args)], cwd=root,
                                  env=environment, timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
        reference = build_package(source, root / "reference")
        built = run("--build", source, "--output", root / "output")
        assert built.returncode == 0, f"EXE build failed: {built.returncode:#x}"
        packages = list((root / "output").glob("museum_package_*"))
        assert len(packages) == 1
        package = packages[0]
        verify_tf(package / "TF_CARD")
        manifest = json.loads((package / "package_manifest.json").read_text(encoding="utf-8"))
        assert len(manifest["files"]) == 31
        for entry in manifest["files"]:
            assert sha256(package / "TF_CARD" / entry["name"]) == entry["sha256"]
            assert sha256(reference / "TF_CARD" / entry["name"]) == entry["sha256"]
        assert manifest["artifacts"][0]["images"][0]["output_size"] == [640, 480]
        assert manifest["scene_cuts_48k_frames"] == [[48000, 96000, 144000, 192000]] * 5
        print("PASS windowed standalone EXE: 31 files, hashes, names, subtitles, scene cuts")
        assert run("--check", source).returncode == 0
        print("PASS standalone check without external Python")
        ffmpeg = find_ffmpeg()
        if ffmpeg:
            mono = root / "mono.wav"
            with wave.open(str(mono), "wb") as wav:
                wav.setparams((1, 2, 24000, 0, "NONE", "not compressed"))
                wav.writeframes(bytes(24000 * 2))
            with patch("museum_media_packager.subprocess.run", wraps=subprocess.run) as called:
                normalize_wav(mono, root / "normalized.wav", ffmpeg)
            assert called.call_args.kwargs["creationflags"] == subprocess.CREATE_NO_WINDOW
            assert canonical_wav(root / "normalized.wav")
            print("PASS FFmpeg conversion with CREATE_NO_WINDOW")
        else:
            print("SKIP optional FFmpeg conversion: not installed")
        if args.offline:
            here = exe.parent
            for name in ("AlignmentWorker", "models", "ffmpeg"):
                shutil.copytree(here / name, root / name)
            original = Path(r"D:\VSCode\CodeFiles\Git_TD\素材\01_越王勾践剑")
            texts = [text for _, _, text in parse_srt(original / "字幕.srt", 0, "direct", False)]
            choices = {}
            for folder in sorted(source.iterdir()):
                shutil.copy2(original / "讲解音频.wav", folder / "讲解音频.wav")
                srt = folder / "字幕.srt"
                srt.write_text("\n\n".join(f"{number}\n00:00:00,000 --> 00:00:00,000\n{text}"
                                          for number, text in enumerate(texts, 1)), encoding="utf-16")
                choices[folder.name] = {"subtitle_sha256": sha256(srt), "cues": [5, 10, 15, 20]}
            choices_path = root / "scene_cues.json"
            choices_path.write_text(json.dumps(choices), encoding="utf-8")
            aligned = run("--build", source, "--output", root / "aligned_output", "--align-subtitles", "--scene-cues", choices_path)
            assert aligned.returncode == 0, f"Offline EXE alignment failed: {aligned.returncode:#x}"
            package = next((root / "aligned_output").glob("museum_package_*"))
            verify_tf(package / "TF_CARD")
            report = json.loads((package / "alignment_report.json").read_text(encoding="utf-8"))
            manifest = json.loads((package / "package_manifest.json").read_text(encoding="utf-8"))
            assert manifest["align_subtitles"] and report["network"] == "disabled"
            for index, track in enumerate(report["tracks"]):
                cues = parse_srt(package / track["subtitle"], round(track["duration_s"] * 48000), "direct")
                assert [text for _, _, text in cues] == texts
                cuts = [cues[number - 1][0] for number in [5, 10, 15, 20]]
                assert cuts == manifest["scene_cuts_48k_frames"][index]
                assert list(struct.unpack_from("<IIII", (package / "TF_CARD" / f"SUB{index}.BIN").read_bytes(), 20)) == cuts
            print("PASS relocated offline EXE: 5 audio conversions, 5 corrected SRTs, 31 TF files, cuts follow corrected cues, network forbidden")


if __name__ == "__main__":
    main()
