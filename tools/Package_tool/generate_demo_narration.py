"""Create image-matched female demo narration; never overwrite the source media."""

import argparse
from array import array
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import wave


NARRATION = {
    "01_越王勾践剑": [
        ["眼前展示的是越王勾践剑。", "先看全貌，剑身修长，剑尖向下。", "两侧轮廓逐渐收束，显得利落而庄重。", "这是以名剑为主题制作的展陈示意图。"],
        ["现在看剑柄与剑格的细节。", "剑格上蓝绿色装饰，与深色金属形成对比。", "两侧装饰相互呼应，中部轮廓向下突出。", "下方的菱形纹理，让剑身更有层次。"],
        ["接下来观察剑尖与两侧刃线。", "剑身从宽处逐渐收紧，汇成锐利的尖端。", "明亮的边缘，衬托出中央深色的菱形纹。", "这个近景，突出线条与纹饰之间的对比。"],
        ["现在看靠近剑格的文字装饰。", "图中两列金色符号，排列在剑身中央。", "真实勾践剑的身份，与剑上的鸟篆铭文有关。", "这里的示意字形，不作为真实铭文释读。"],
        ["回到全貌，再看剑柄、剑格与剑身。", "三个细节，让我们看清装饰和结构的关系。", "菱形纹、彩色装饰与修长轮廓彼此呼应。", "越王勾践剑的这一组展示，到这里结束。"],
    ],
    "02_四羊方尊": [
        ["眼前展示的是四羊方尊。", "它是一件商代青铜器，造型庄重而生动。", "展开的口沿、修长的颈部和底座上下呼应。", "这组展陈示意图，将重点带到造型细节。"],
        ["先看第一张细节图中的羊首。", "卷曲的羊角环绕头部，轮廓清晰有力。", "羊首从器身向外伸出，打破方形的平直。", "动物造型与器物结构，在这里融为一体。"],
        ["接下来观察肩部和颈部的装饰。", "浮起的兽形纹饰，沿肩部横向展开。", "颈部纵向纹样，与肩部横向装饰形成对照。", "细密底纹，让突出的造型更加醒目。"],
        ["现在把视线移到腹部与底座。", "腹部纹饰层层展开，中间立起一道棱线。", "下方底座向外展开，承托上部器身。", "连续的纹理，把上下几部分联系起来。"],
        ["回到全貌，看它整体的比例与节奏。", "方正轮廓中，羊首带来了鲜明的立体变化。", "平面纹饰与立体造型，构成统一的视觉语言。", "四羊方尊的这一组展示，到这里结束。"],
    ],
    "03_金缕玉衣": [
        ["眼前展示的是金缕玉衣。", "它不是日常衣物，而是汉代的贵族葬具。", "全貌呈现出头部、躯干和四肢的轮廓。", "这组示意图，让我们观察玉片的拼接方式。"],
        ["先看肩部与上臂的连接细节。", "一片片玉片，顺着肩部曲线排列。", "细金丝将相邻玉片连在一起。", "平整玉片的组合，形成了转折的肩部轮廓。"],
        ["接下来观察头罩与面部。", "玉片分区拼合，勾勒出面部的大致形状。", "中央有鼻部起伏，周围分布着连接点。", "这些细节，体现了从平面到立体的组合。"],
        ["现在看腰部与腿部的衔接。", "腰部的弧形边缘，连接着下方的玉片。", "金丝沿接缝排列，形成有规律的线条。", "玉片的大小和形状，也随着轮廓变化。"],
        ["回到全貌，重新观察整套玉衣。", "许多小片，通过连接组成完整的人体外形。", "金缕玉衣，展现了细致的加工与组合思路。", "这一组展示，到这里结束。"],
    ],
    "04_马踏飞燕": [
        ["眼前展示的是铜奔马，也称马踏飞燕。", "先看全貌，奔马昂首，四肢向不同方向伸展。", "一只后蹄落在飞鸟上，其余三足腾空。", "这组示意图，突出奔跑瞬间的动感。"],
        ["先看马头与颈部的近景。", "张开的嘴、竖起的耳朵，构成有力的表情。", "鬃毛沿着颈部排列，加强向前的动势。", "头颈的起伏，让静止的造型显得充满活力。"],
        ["接下来观察马蹄与飞鸟的接触处。", "马蹄落在鸟背上，支撑起奔马的姿态。", "飞鸟展开双翼，头部向上转动。", "这个细节，是整件造型最醒目的焦点。"],
        ["现在看马身、四肢与扬起的尾巴。", "前后肢错开伸展，形成一组有节奏的线条。", "饱满的躯干，与细长的腿部形成对照。", "尾部向后扬起，将奔跑的方向继续延伸。"],
        ["回到全貌，看看这些线条如何连成整体。", "马与鸟相互呼应，让速度仿佛可以被看见。", "从头部到四肢，每个细节都服务于动感。", "铜奔马的这一组展示，到这里结束。"],
    ],
    "05_长信宫灯": [
        ["眼前展示的是长信宫灯。", "它以跪坐持灯的人物形象，将照明与造型结合。", "全貌中，人物与灯体相互依托。", "这组示意图，带我们观察三处局部。"],
        ["先看人物的面部、衣袖与持灯姿态。", "面部表情平静，衣褶沿身体展开。", "手臂在灯体旁弯曲，构成连贯的轮廓。", "人物不是附加装饰，而是整体造型的一部分。"],
        ["接下来观察灯体下部与开口区域。", "横向边缘，和竖向支撑形成清晰的层次。", "暗色开口，与金色表面形成鲜明对比。", "这个近景，让灯与人物的连接更加直观。"],
        ["现在看灯体上部与人物之间的关系。", "图中上部呈现展开的结构示意。", "真实宫灯的构件可以拆卸，便于清洁。", "示意图用于观察结构，不代替实物测绘。"],
        ["回到全貌，再看人与灯的整体轮廓。", "照明器具，也能被塑造成优雅的人物形象。", "功能与艺术的结合，是这件文物的看点。", "长信宫灯的这一组展示，到这里结束。"],
    ],
}

SPEECH = r"""
Add-Type -AssemblyName System.Speech
$request = Get-Content -LiteralPath $env:MUSEUM_NARRATION_REQUEST -Raw -Encoding UTF8 | ConvertFrom-Json
$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
$speaker.SelectVoice('Microsoft Huihui Desktop')
$speaker.Rate = 0
$format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(24000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
try {
    foreach ($item in $request) {
        $speaker.SetOutputToWaveFile($item.path, $format)
        $speaker.Speak($item.text)
        $speaker.SetOutputToNull()
    }
} finally { $speaker.Dispose() }
"""


def timestamp(frames):
    milliseconds = frames * 1000 // 24000
    seconds, ms = divmod(milliseconds, 1000)
    minutes, sec = divmod(seconds, 60)
    hours, minute = divmod(minutes, 60)
    return f"{hours:02}:{minute:02}:{sec:02},{ms:03}"


def generate(source, output):
    import os
    if output.exists() or output.is_relative_to(source):
        raise ValueError("Output must be a new directory outside the source")
    assert sorted(p.name for p in source.iterdir() if p.is_dir()) == sorted(NARRATION)
    image_hashes = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in source.glob("*/*.bmp")}
    assert len(image_hashes) == 20
    output.mkdir(parents=True)
    clips = output / "clips"
    clips.mkdir()
    request = []
    for track, scenes in enumerate(NARRATION.values()):
        assert len(scenes) == 5 and sum(map(len, scenes)) <= 32
        for scene, texts in enumerate(scenes):
            for cue, text in enumerate(texts):
                assert len(text) <= 28
                request.append({"text": text, "path": str(clips / f"{track}_{scene}_{cue}.wav")})
    request_path = output / "speech_request.json"
    request_path.write_text(json.dumps(request, ensure_ascii=False), encoding="utf-8")
    env = {**os.environ, "MUSEUM_NARRATION_REQUEST": str(request_path)}
    subprocess.run(["powershell.exe", "-NoProfile", "-EncodedCommand",
                    base64.b64encode(SPEECH.encode("utf-16-le")).decode()],
                   env=env, check=True, creationflags=subprocess.CREATE_NO_WINDOW)
    rows = []
    for track, (name, scenes) in enumerate(NARRATION.items()):
        target = output / "素材" / name
        target.mkdir(parents=True)
        pcm, cues, boundaries = bytearray(), [], [0]
        for scene, texts in enumerate(scenes):
            # Existing image transitions continue while audio runs: reserve 1.3s before scene narration.
            pcm.extend(bytes(24000 * 2 * (0 if scene == 0 else 1)))
            pcm.extend(bytes(24000 * 2 * 3 // 10))
            for cue, text in enumerate(texts):
                with wave.open(str(clips / f"{track}_{scene}_{cue}.wav"), "rb") as wav:
                    assert (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) == (24000, 1, 2)
                    data = wav.readframes(wav.getnframes())
                samples = array("h", data)
                active = [i for i, value in enumerate(samples) if abs(value) > 32]
                assert active and max(map(abs, samples)) < 32767
                # Retain 80ms before and 120ms after speech, removing SAPI's variable tail silence.
                first, last = max(0, active[0] - 1920), min(len(samples), active[-1] + 2880)
                data = samples[first:last].tobytes()
                start = len(pcm) // 2
                pcm.extend(data)
                cues.append((start, len(pcm) // 2, text))
                pcm.extend(bytes(24000 * 2 // 5))
            # Whole-second scene endpoints keep the existing optional script parser exact.
            pcm.extend(bytes((-len(pcm)) % (24000 * 2)))
            boundaries.append(len(pcm) // 2)
        with wave.open(str(target / "讲解音频.wav"), "wb") as wav:
            wav.setparams((1, 2, 24000, 0, "NONE", "not compressed"))
            wav.writeframes(pcm)
        srt = "\n\n".join(f"{i}\n{timestamp(start)} --> {timestamp(end)}\n{text}"
                            for i, (start, end, text) in enumerate(cues, 1)) + "\n"
        (target / "字幕.srt").write_text(srt, encoding="utf-8-sig")
        lines = [f"# {name.partition('_')[2]}：女声测试素材切图时间", "",
                 "由实际合成音频自动生成，无需手工填写。图片顺序不变。", "",
                 "| 序号 | 时间区间 | 展示图片 | 对应讲解内容 |", "|---|---|---|---|"]
        roles = ["全貌图.bmp", "细节1.bmp", "细节2.bmp", "细节3.bmp", "全貌图.bmp"]
        for i, role in enumerate(roles):
            left, right = (boundary // 24000 for boundary in boundaries[i:i+2])
            lines.append(f"| {i+1} | `{left//60:02}:{left%60:02} – {right//60:02}:{right%60:02}` | **{role}** | {' '.join(scenes[i])} |")
        (target / "图片切换脚本.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
        from generate_museum_subtitles import parse_srt, parse_scene_script, render_bitmap
        parsed = parse_srt(target / "字幕.srt", len(pcm) // 2 * 2, "direct")
        assert [text for _, _, text in parsed] == [text for scene in scenes for text in scene]
        assert parse_scene_script(target / "图片切换脚本.md", len(pcm) // 2 * 2) == [n * 2 for n in boundaries[1:-1]]
        for _, _, text in parsed:
            render_bitmap(text)
        with wave.open(str(target / "讲解音频.wav"), "rb") as wav:
            assert wav.getnframes() * 2 == len(pcm)
        rows.append({"folder": name, "voice": "Microsoft Huihui Desktop", "duration_s": boundaries[-1] // 24000,
                     "cues": len(cues), "scene_cuts_s": [n // 24000 for n in boundaries[1:-1]],
                     "scene_first_cues": [5, 9, 13, 17], "audio_format": "PCM16 / 24000 Hz / mono"})
        print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
    report = {"artifacts": rows, "image_sha256": image_hashes}
    (output / "generation_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    assert all(hashlib.sha256((source / p).read_bytes()).hexdigest() == digest for p, digest in image_hashes.items())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    generate(args.source.resolve(), args.output.resolve())
