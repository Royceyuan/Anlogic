"""Check local forced alignment without touching source media or the TF card."""

import argparse
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path
from types import SimpleNamespace

from align_worker import checked_cues
from museum_media_packager import RUNTIME, find_ffmpeg, find_media, normalize_wav
from generate_museum_subtitles import parse_srt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--worker", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--skip-folder", help="Explicitly skip a known incomplete source during positive regression")
    parser.add_argument("--expect-error", help="Expected error substring for negative source regression")
    args = parser.parse_args()
    word = SimpleNamespace(word="测试", start=1.0, end=2.0, probability=0.9)
    segment = SimpleNamespace(text="测试", start=1.0, end=2.0, words=[word])
    assert checked_cues([segment], ["测试"], 3)[0][0]["start_ms"] == 1000
    for segments, texts, duration in [([], ["测试"], 3), ([segment], ["不同"], 3), ([segment], ["测试"], 1)]:
        try:
            checked_cues(segments, texts, duration)
        except ValueError:
            pass
        else:
            raise AssertionError("Invalid alignment was accepted")
    print("PASS alignment rejects missing cues, changed text and out-of-range timestamps")
    if args.source is None:
        return
    here = Path(__file__).resolve().parent
    worker = args.worker or RUNTIME / "AlignmentWorker" / "AlignmentWorker.exe"
    environment = os.environ.copy()
    environment.pop("PYTHONPATH", None)
    environment.pop("PYTHONHOME", None)
    environment["PATH"] = str(Path(os.environ["SystemRoot"]) / "System32")
    with tempfile.TemporaryDirectory(prefix="museum_align_test_") as temporary:
        root = Path(temporary)
        request = []
        expected = []
        for index, folder in enumerate(sorted(args.source.iterdir())):
            if not folder.is_dir() or folder.name == args.skip_folder:
                continue
            audio = root / f"AUDIO{index}.WAV"
            normalize_wav(find_media(folder, ".wav"), audio, find_ffmpeg())
            texts = [text for _, _, text in parse_srt(find_media(folder, ".srt"), 0, "direct", False)]
            expected.append(texts)
            request.append({"audio": str(audio), "texts": texts, "output": str(root / f"SUB{index}.srt")})
        request_file, result_file = root / "request.json", root / "result.json"
        request_file.write_text(json.dumps(request, ensure_ascii=False), encoding="utf-8")
        start = time.monotonic()
        command = [str(worker)] if worker.suffix != ".py" else [str(here / "_alignment_runtime" / "Scripts" / "python.exe"), str(worker)]
        result = subprocess.run(command + ["--request", str(request_file), "--result", str(result_file),
                                 "--model", str(RUNTIME / "models" / "small.pt")], env=environment,
                                capture_output=True, timeout=1800, creationflags=subprocess.CREATE_NO_WINDOW)
        assert result_file.is_file(), result.stderr.decode(errors="replace")
        report = json.loads(result_file.read_text(encoding="utf-8"))
        if args.expect_error:
            assert result.returncode != 0 and args.expect_error in report.get("error", ""), report
            print("PASS incomplete audio/subtitle pair rejected:", report["error"])
            return
        assert result.returncode == 0, report
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        assert report["network"] == "disabled"
        assert report["alignment_mode"] == "normal / token_step=100"
        for index, track in enumerate(report["tracks"]):
            cues = parse_srt(Path(track["subtitle"]), round(track["duration_s"] * 48000), "direct")
            assert [text for _, _, text in cues] == expected[index]
            print(f"PASS track {index}: {len(cues)} cues, {track['duration_s']:.3f}s, "
                  f"{len(track['warnings'])} review hints, original text/order preserved")
        print(f"PASS local model, network forbidden, Python removed from PATH: {time.monotonic() - start:.1f}s")


if __name__ == "__main__":
    main()
