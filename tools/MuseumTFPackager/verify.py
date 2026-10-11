"""Run parser/conversion/scene selection regression checks on temporary files."""

import struct
import argparse
import subprocess
import tempfile
import time
import tkinter as tk
from tkinter import ttk
import wave
from pathlib import Path
from unittest.mock import patch

from PIL import Image, ImageGrab

from museum_media_packager import (
    build_package, canonical_wav, find_ffmpeg, inspect_source, normalize_wav,
    scene_cuts_from_cues, sha256, wav_info,
    launch_gui,
    HELP_TEXT, RUNTIME, show_help,
)
from generate_museum_subtitles import parse_srt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", type=Path, help="Optional previous EXE for byte-for-byte TF comparison")
    parser.add_argument("--preview", type=Path, help="Save the tested GUI preview")
    args = parser.parse_args()
    binary = (RUNTIME / "MuseumTFPackager.exe").read_bytes()
    pe = struct.unpack_from("<I", binary, 0x3c)[0]
    assert struct.unpack_from("<H", binary, pe + 24 + 68)[0] == 2, "EXE must not open a console"
    with tempfile.TemporaryDirectory(prefix="museum_formats_") as temporary:
        root = Path(temporary)
        srt = root / "字幕.srt"
        text = "1\r\n00:00:00.5 --> 00:00:01.25 X1:40\r\n<b>测试</b>\r\n字幕\r\n \r\n00:00:01,500-->00:00:02,000\r\n第二句\r\n"
        for encoding in ("utf-8-sig", "utf-16", "utf-16-le", "utf-16-be", "utf-32", "gb18030"):
            srt.write_bytes(text.encode(encoding))
            cues = parse_srt(srt, 5 * 48000, "direct")
            assert cues == [(24000, 60000, "测试字幕"), (72000, 96000, "第二句")], encoding
        for content in ("1\n00:00:01,000 --> 00:00:00,000\n倒序", "1\n00:00:00,000 --> 00:00:06,000\n超长"):
            srt.write_text(content, encoding="utf-8")
            try:
                parse_srt(srt, 5 * 48000, "direct")
            except ValueError:
                assert len(parse_srt(srt, 5 * 48000, "direct", False)) == 1
            else:
                raise AssertionError("Invalid timing was accepted without alignment")
        print("PASS SRT encodings, dotted timestamps, multiline/tags, malformed timing only allowed before alignment")

        source = root / "素材"
        for index in range(1, 6):
            folder = source / f"{index:02d}_文物"
            folder.mkdir(parents=True)
            for name in ("全貌图", "细节1", "细节2", "细节3"):
                Image.new("RGB", (64, 48), "brown").save(folder / f"{name}.bmp")
            with wave.open(str(folder / "任意音频名.WAV"), "wb") as wav:
                wav.setparams((2, 2, 48000, 0, "NONE", "not compressed"))
                wav.writeframes(bytes(5 * 48000 * 4))
            (folder / "任意字幕名.SRT").write_text("\n\n".join(
                f"{number}\n00:00:0{start},000 --> 00:00:0{start},500\n第{number}句"
                for number, start in enumerate(range(5), 1)), encoding="utf-8")
        assert len(inspect_source(source)) == 5
        package = build_package(source, root / "输出")
        for name, exe in (("exe", RUNTIME / "MuseumTFPackager.exe"), ("baseline", args.baseline)):
            if exe is None:
                continue
            subprocess.run([str(exe.resolve()), "--check", str(source)], check=True, timeout=120,
                           creationflags=subprocess.CREATE_NO_WINDOW)
            subprocess.run([str(exe.resolve()), "--build", str(source), "--output", str(root / name)],
                           check=True, timeout=120, creationflags=subprocess.CREATE_NO_WINDOW)
            output = next((root / name).glob("museum_package_*")) / "TF_CARD"
            assert len(list(output.iterdir())) == 31
            for expected in (package / "TF_CARD").iterdir():
                assert sha256(expected) == sha256(output / expected.name), expected.name
        print("PASS standalone windowed EXE: check, build, all 31 TF file hashes match")
        header = (package / "TF_CARD/SUB0.BIN").read_bytes()
        assert struct.unpack_from("<IIII", header, 20) == (48000, 96000, 144000, 192000)
        first = source / "01_文物"
        choices = {first.name: {"subtitle_sha256": sha256(first / "任意字幕名.SRT"), "cues": [2, 3, 4, 5]}}

        def fake_align(folders, building, rows):
            paths = []
            for index, folder in enumerate(folders):
                path = building / f"aligned{index}.srt"
                path.write_text("\n\n".join(
                    f"{number}\n00:00:0{start},200 --> 00:00:0{start},700\n第{number}句"
                    for number, start in enumerate(range(5), 1)), encoding="utf-8")
                paths.append(path)
            return paths, {}
        with patch("museum_media_packager.alignment_command", return_value=[]), patch("museum_media_packager.align_subtitle_files", side_effect=fake_align):
            package = build_package(source, root / "校准输出", align_subtitles=True, scene_choices=choices)
        assert struct.unpack_from("<IIII", (package / "TF_CARD/SUB0.BIN").read_bytes(), 20) == (57600, 105600, 153600, 201600)
        assert struct.unpack_from("<II", (package / "TF_CARD/SUB0.BIN").read_bytes(), 512) == (9600, 33600)
        choices[first.name]["subtitle_sha256"] = "old"
        try:
            build_package(source, root / "失败输出", scene_choices=choices)
        except ValueError:
            assert not list((root / "失败输出").iterdir()), "Failed build left a partial package"
        else:
            raise AssertionError("Stale subtitle selection was accepted")
        for numbers in ([1, 2, 3, 4], [2, 2, 3, 4], [2, 3, 4, 6]):
            try:
                scene_cuts_from_cues(parse_srt(first / "任意字幕名.SRT", 240000, "direct"), numbers, 240000)
            except ValueError:
                pass
            else:
                raise AssertionError("Invalid cuts accepted")
        print("PASS six-file input, automatic cuts, cuts use corrected SRT, stale/invalid cuts rejected, atomic failure cleanup")

        def widgets(parent):
            for child in parent.winfo_children():
                yield child
                yield from widgets(child)

        def gui_flow(gui):
            gui.update()
            style = ttk.Style(gui)
            table = next(widget for widget in widgets(gui) if isinstance(widget, ttk.Treeview))
            original_font = style.lookup(".", "font")
            original_height = int(style.lookup("Treeview", "rowheight"))
            gui.geometry("1600x1100")
            gui.update()
            assert style.lookup(".", "font") != original_font
            assert int(style.lookup("Treeview", "rowheight")) > original_height
            for button in (widget for widget in widgets(gui) if isinstance(widget, ttk.Button)):
                assert button.winfo_rootx() + button.winfo_width() <= gui.winfo_rootx() + gui.winfo_width()
            assert table.winfo_height() > 0
            gui.geometry("980x720")
            gui.update()
            assert int(style.lookup("Treeview", "rowheight")) < original_height
            gui.geometry("1120x780")
            gui.update()
            print("PASS proportional GUI fonts, rows and controls at 980x720 / 1120x780 / 1600x1100")
            help_window = show_help(gui)
            gui.update()
            text = next(widget for widget in widgets(help_window) if isinstance(widget, tk.Text))
            assert text.get("1.0", "end-1c") == HELP_TEXT and text.cget("state") == "disabled"
            text.yview_moveto(1.0)
            gui.update()
            assert text.yview()[0] > 0
            help_window.destroy()
            assert gui.winfo_exists()
            buttons = {widget.cget("text"): widget for widget in widgets(gui) if isinstance(widget, ttk.Button)}
            entry = next(widget for widget in widgets(gui) if isinstance(widget, ttk.Entry))
            variable = entry.cget("textvariable")
            gui.setvar(variable, str(root / "不存在的素材目录"))
            buttons["1. 检查素材"].invoke()
            timeout = time.monotonic() + 30
            while buttons["1. 检查素材"].instate(["disabled"]) and time.monotonic() < timeout:
                gui.update()
                time.sleep(0.02)
            assert errors.called and not buttons["1. 检查素材"].instate(["disabled"])
            errors.reset_mock()
            gui.setvar(variable, str(source))
            buttons["设置切图句"].invoke()
            dialog = next(widget for widget in gui.winfo_children() if isinstance(widget, tk.Toplevel))
            notebook = next(widget for widget in widgets(dialog) if isinstance(widget, ttk.Notebook))
            assert len(notebook.tabs()) == 5
            combos = [widget for widget in widgets(notebook.winfo_children()[0]) if isinstance(widget, ttk.Combobox)]
            for combo, number in zip(combos, [2, 3, 4, 5]):
                combo.current(number)
            next(widget for widget in widgets(dialog) if isinstance(widget, ttk.Button)).invoke()
            buttons["2. 生成 TF 素材包"].invoke()
            assert buttons["2. 生成 TF 素材包"].instate(["disabled"])
            timeout = time.monotonic() + 30
            while buttons["2. 生成 TF 素材包"].instate(["disabled"]) and time.monotonic() < timeout:
                gui.update()
                time.sleep(0.02)
            assert not buttons["2. 生成 TF 素材包"].instate(["disabled"]), "GUI build did not finish"
            assert not errors.called, errors.call_args
            assert success.called
            package = next((root / "GUI输出").glob("museum_package_*"))
            assert struct.unpack_from("<IIII", (package / "TF_CARD/SUB0.BIN").read_bytes(), 20) == (48000, 96000, 144000, 192000)
            if args.preview:
                gui.update()
                time.sleep(0.2)
                gui.update()
                ImageGrab.grab(window=gui.winfo_id()).save(args.preview)
            gui.destroy()

        with patch("museum_media_packager.DEFAULT_SOURCE", source), patch("museum_media_packager.DEFAULT_OUTPUT", root / "GUI输出"), \
             patch("tkinter.Tk.mainloop", gui_flow), patch("tkinter.messagebox.showerror") as errors, patch("tkinter.messagebox.showinfo") as success:
            launch_gui()
        print("PASS GUI-only flow: five tabs, four cue selections, background generation, controls restored")

        ffmpeg = find_ffmpeg()
        assert ffmpeg, "Need FFmpeg to test WAV variants"
        for codec in ("pcm_u8", "pcm_s24le", "pcm_f32le", "adpcm_ima_wav", "pcm_mulaw"):
            audio = root / f"{codec}.wav"
            subprocess.run([str(ffmpeg), "-v", "error", "-y", "-f", "lavfi", "-i", "sine=frequency=440:duration=1",
                            "-ar", "22050", "-ac", "1", "-c:a", codec, str(audio)], check=True,
                           creationflags=subprocess.CREATE_NO_WINDOW)
            assert wav_info(audio)["duration_s"] > 0
            target = root / f"{codec}_canonical.wav"
            normalize_wav(audio, target, ffmpeg)
            assert canonical_wav(target)
        (root / "fake.wav").write_text("not a wav", encoding="utf-8")
        try:
            wav_info(root / "fake.wav")
        except ValueError:
            pass
        else:
            raise AssertionError("Fake WAV accepted")
        print("PASS PCM8/PCM24/float32/IMA ADPCM/mu-law WAV conversion and invalid WAV rejection")


if __name__ == "__main__":
    main()
