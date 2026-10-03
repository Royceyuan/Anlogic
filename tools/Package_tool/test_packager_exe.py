"""Run the standalone windowed EXE against temporary media, not the TF card."""

import json
import os
from pathlib import Path
import struct
import subprocess
import tempfile
from unittest.mock import patch
import wave

from PIL import Image

from museum_media_packager import (
    build_package, canonical_wav, find_ffmpeg, normalize_wav, sha256, verify_tf,
)


def main():
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


if __name__ == "__main__":
    main()
