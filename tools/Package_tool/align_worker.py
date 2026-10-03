"""Offline forced alignment; original subtitle text and order are authoritative."""

import argparse
import hashlib
import json
import math
import socket
import unicodedata
import wave
from pathlib import Path


MODEL_SHA256 = "9ecf779972d90ba49c06d968637d720dd632c55bbf19d441fb42bf17a411e794"


def timestamp(milliseconds):
    seconds, milli = divmod(milliseconds, 1000)
    minutes, second = divmod(seconds, 60)
    hour, minute = divmod(minutes, 60)
    return f"{hour:02d}:{minute:02d}:{second:02d},{milli:03d}"


def checked_cues(segments, texts, duration):
    if len(segments) != len(texts):
        raise ValueError("校准句数与原字幕不一致，未生成字幕包")
    cues, warnings = [], []
    previous_end = 0
    for number, (segment, text) in enumerate(zip(segments, texts), 1):
        if segment.text.strip() != text.strip():
            raise ValueError(f"第 {number} 句校准文字发生变化：{segment.text!r} / {text!r}，未生成字幕包")
        if not (math.isfinite(segment.start) and math.isfinite(segment.end)):
            raise ValueError(f"第 {number} 句校准时间无效")
        start, end = round(segment.start * 1000), round(segment.end * 1000)
        if start < previous_end or end <= start or end > round(duration * 1000):
            raise ValueError(f"第 {number} 句无法获得有效时间，请核对音频与字幕内容")
        words = [word for word in segment.words
                 if any(unicodedata.category(char)[0] in "LN" for char in word.word)]
        missing = [word.word for word in words if word.end <= word.start]
        if not words or len(missing) > len(words) / 2:
            raise ValueError(f"第 {number} 句含未能定位的文字（{missing!r}；{text!r}），请核对字幕是否漏句、多句或与音频不符")
        if missing:
            warnings.append(f"第 {number} 句个别短字无法单独定位（{'、'.join(missing)}），请试听整句起止时间")
        probabilities = [word.probability for word in words if word.probability is not None]
        confidence = sum(probabilities) / len(probabilities) if probabilities else None
        # ponytail: confidence is a review hint, not proof that subtitle semantics match the audio.
        if confidence is not None and confidence < 0.5:
            warnings.append(f"第 {number} 句匹配置信度 {confidence:.2f}，请重点试听")
        cues.append({"start_ms": start, "end_ms": end, "text": text, "confidence": confidence})
        previous_end = end
    return cues, warnings


def align_batch(request, model_path):
    if not model_path.is_file():
        raise FileNotFoundError(f"缺少本地模型：{model_path}；请使用完整离线包")
    digest = hashlib.sha256()
    with model_path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    if digest.hexdigest() != MODEL_SHA256 or model_path.name != "small.pt":
        raise ValueError("small.pt 模型校验失败；请重新取得完整离线包")

    def no_network(*args, **kwargs):
        raise RuntimeError("字幕校准禁止联网，请检查本地运行包是否完整")

    socket.socket.connect = no_network
    socket.socket.connect_ex = no_network
    import numpy as np
    import stable_whisper
    import torch
    import torchaudio

    torch.set_num_threads(4)
    model = stable_whisper.load_model("small", device="cpu", download_root=str(model_path.parent))
    output = []
    for item in request:
        texts = item["texts"]
        if not 1 <= len(texts) <= 32 or any(not isinstance(text, str) or not text.strip() for text in texts):
            raise ValueError("原字幕需含 1～32 条有效文字")
        with wave.open(item["audio"], "rb") as wav:
            if (wav.getnchannels(), wav.getsampwidth(), wav.getframerate()) != (2, 2, 48000):
                raise ValueError("校准输入需先转换为 PCM16/48kHz/双声道 WAV")
            duration = wav.getnframes() / 48000
            pcm = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").reshape(-1, 2)
        mono = torch.from_numpy(pcm.astype(np.float32).mean(axis=1) / 32768)
        if not torch.any(mono):
            raise ValueError("音频为全静音，无法校准字幕")
        samples = torchaudio.functional.resample(mono, 48000, 16000).numpy()
        result = model.align(samples, "\n".join(texts), language="zh",
                             original_split=True, regroup=False, verbose=None, vad=False, token_step=0, fast_mode=True)
        if result is None:
            raise ValueError("音频无法定位字幕，请核对文字是否与音频相符")
        try:
            cues, warnings = checked_cues(result.segments, texts, duration)
        except ValueError as error:
            raise ValueError(f"{Path(item['audio']).name}: {error}") from error
        target = Path(item["output"])
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("\n\n".join(
            f"{number}\n{timestamp(cue['start_ms'])} --> {timestamp(cue['end_ms'])}\n{cue['text']}"
            for number, cue in enumerate(cues, 1)) + "\n", encoding="utf-8")
        output.append({"audio": item["audio"], "subtitle": str(target), "duration_s": duration,
                       "cues": cues, "warnings": warnings})
    return {"model": "whisper-small", "model_sha256": MODEL_SHA256, "device": "cpu",
            "language": "zh", "engine": "stable-ts 2.19.1 / whisper 20250625",
            "network": "disabled", "tracks": output}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--request", type=Path, required=True)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--result", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = align_batch(json.loads(args.request.read_text(encoding="utf-8")), args.model)
        args.result.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception as error:
        args.result.write_text(json.dumps({"error": str(error)}, ensure_ascii=False), encoding="utf-8")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
