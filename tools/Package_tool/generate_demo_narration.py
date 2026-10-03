"""Create continuous female narration; requires edge-tts and consent to send text to Microsoft."""

import argparse
import asyncio
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unicodedata
import wave


NARRATION = {
    "01_越王勾践剑": [
        ["请把目光停在这道青铜的锋芒上。", "越王勾践剑，带我们走近遥远的春秋时代。", "修长的剑身收拢到尖端，安静，却自有气势。", "不妨从剑柄开始，读一读古人的匠心。"],
        ["剑格上，蓝绿相映的装饰格外醒目。", "沉稳的金属，遇上宝石般的亮色。", "它让我们想到，兵器也承载着主人的审美。", "菱形纹向下铺开，秩序与锋芒在此相遇。"],
        ["再沿着明亮的刃线，看向剑尖。", "由宽到窄，力量仿佛被收拢到一个点。", "明暗交错的菱形，像为青铜披上了一层暗锦。", "简练的轮廓背后，是对形制与比例的把握。"],
        ["靠近剑格，文字为这把剑留下身份的线索。", "真品上的八字鸟篆，指向它的主人勾践。", "优美的文字，也是跨越年代的署名。", "一个名字，让遥远的历史有了清晰的面孔。"],
        ["回看全剑，彩饰、纹样与线条彼此呼应。", "这道锋芒背后，是冶铸、审美与王者的记忆。", "岁月带走了当年的声音，却留下了青铜。", "今天，我们仍能从这些细节里，与古人相遇。"],
    ],
    "02_四羊方尊": [
        ["四只卷角羊，守住了一件青铜器的四个角。", "这就是四羊方尊，一件来自商代的艺术珍品。", "开阔的口沿与厚重的器身，透出庄严的气息。", "细看之后，你会发现庄严之中，也藏着生动。"],
        ["最先吸引目光的，是向外探出的羊首。", "羊角盘曲，双眼有神，仿佛随时会转过头来。", "柔和的曲线，打破了方形器身的平直。", "羊不只是装饰，它已经成为器物的一部分。"],
        ["顺着羊首往上看，肩部的纹饰层层展开。", "浮起的兽形与细密底纹，营造出深浅变化。", "颈部的纵线，与肩部的横向装饰相互呼应。", "古人把平面纹样和立体造型，织进同一件作品。"],
        ["目光向下，腹部与底座又有新的节奏。", "突起的棱线，让繁密纹饰有了清晰的边界。", "宽稳的底座，托起上方丰富的形体。", "一繁一简，一轻一重，整体因此显得安定。"],
        ["退后一步，四羊方尊的气势再次完整呈现。", "方正与曲线、纹样与雕塑，在这里相互成全。", "青铜留住的不只是形状，还有古人的想象力。", "一件器物，就这样把工艺变成了艺术。"],
    ],
    "03_金缕玉衣": [
        ["这件看似衣服的珍品，并不是用来日常穿着的。", "金缕玉衣，是汉代贵族使用的葬具。", "古人相信玉能守护身体，寄托对不朽的期待。", "这份期待，被化成了一片片玉和一缕缕金丝。"],
        ["来到肩部，玉片沿着身体的转折排列。", "细金丝穿过连接处，把分散的小片连成整体。", "坚硬的玉，竟被组织成近似衣服的轮廓。", "看似轻巧的连接，背后是耐心细致的加工。"],
        ["再看头罩，平整玉片勾勒出了面部的起伏。", "鼻部略微隆起，周围的拼接向两侧铺开。", "每一处转折，都需要玉片彼此配合。", "这张安静的面孔，藏着古人对生命的牵挂。"],
        ["腰部与腿部，让我们看见另一种组合方式。", "弧形边缘顺着身体变化，金丝沿接缝延伸。", "玉片的大小和形状，也随着位置而改变。", "没有一整块玉，只有许多小片共同完成的轮廓。"],
        ["回到全貌，细碎的玉片已经汇成完整的人形。", "温润的玉与纤细的金，凝结了技艺，也寄托了信念。", "今天看它，我们不必相信玉能让生命不朽。", "却能理解古人对生命、尊严与永恒的想象。"],
    ],
    "04_马踏飞燕": [
        ["如果把风凝固下来，会是什么模样？", "眼前的铜奔马，仿佛给出了一个答案。", "三足腾空，一足踏鸟，奔跑被定格在青铜里。", "它也被称作马踏飞燕，名字里就带着飞扬的气息。"],
        ["靠近马头，张开的嘴仿佛正发出一声长嘶。", "竖起的耳朵与昂扬的颈部，让精神跃然眼前。", "鬃毛顺着颈线铺开，像被疾风向后梳过。", "还未看清四蹄，我们已经感到了向前的力量。"],
        ["真正巧妙的地方，藏在马蹄与飞鸟之间。", "一只马蹄落在鸟背上，其余三足凌空伸展。", "飞鸟转头回望，仿佛惊讶于这突如其来的相遇。", "沉重的青铜，竟让人看出了轻盈。"],
        ["再看躯干、四肢与扬起的尾巴。", "饱满的身体和细长的腿，构成鲜明的张力。", "前后肢错开伸展，把奔跑的节奏带到眼前。", "尾巴向后扬起，仿佛速度还没有停下来。"],
        ["回到全貌，马与鸟把一个瞬间变成了永恒。", "无声的青铜里，有风，也有生命的昂扬。", "工匠没有真的让它奔跑，却让我们相信它正在奔跑。", "这正是铜奔马打动人心的地方。"],
    ],
    "05_长信宫灯": [
        ["想象一间汉代居室，灯火正在悄悄亮起。", "一位跪坐的宫女托着灯，神情安静而专注。", "这就是长信宫灯，把照明变成了一幅温柔的画面。", "它的动人之处，却不只在于这张面孔。"],
        ["先走近人物，看看她低垂的目光与舒展的衣袖。", "面部的平静，与衣褶的流动形成细腻的对照。", "弯曲的手臂，让人与灯自然地连在一起。", "实用器具，因此有了人的姿态和温度。"],
        ["视线移到灯体，开口与边缘构成清晰的层次。", "金色表面围着暗处，让我们不禁想象其中的灯火。", "真品的灯罩可以调节，控制光照的方向。", "一盏灯，已经藏着古人对使用体验的细心考虑。"],
        ["而灯体上部，还提示着更巧妙的结构。", "真品借助中空的手臂，将烟尘引入灯的内部。", "构件又能拆卸，便于清洁和维护。", "美丽的外形之下，原来还有一套周到的设计。"],
        ["回看这位持灯的宫女，人物与器物已难分彼此。", "她托起的不只是灯，也托起了古人的生活智慧。", "从一束光出发，艺术、功能与体贴在这里相逢。", "隔着漫长岁月，这份用心依然让人感到温暖。"],
    ],
}

VOICE = "zh-CN-XiaoxiaoNeural"


def timestamp(milliseconds):
    seconds, ms = divmod(milliseconds, 1000)
    minutes, sec = divmod(seconds, 60)
    hours, minute = divmod(minutes, 60)
    return f"{hours:02}:{minute:02}:{sec:02},{ms:03}"


async def generate(source, output):
    import edge_tts
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from generate_museum_subtitles import parse_srt, parse_scene_script, render_bitmap
    from museum_media_packager import find_ffmpeg

    if output.exists() or output.is_relative_to(source):
        raise ValueError("Output must be a new directory outside the source")
    assert sorted(p.name for p in source.iterdir() if p.is_dir()) == sorted(NARRATION)
    image_hashes = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in source.glob("*/*.bmp")}
    assert len(image_hashes) == 20
    ffmpeg = find_ffmpeg()
    if ffmpeg is None:
        raise FileNotFoundError("The existing packager FFmpeg is required")
    voices = await edge_tts.list_voices()
    assert any(v["ShortName"] == VOICE and v["Gender"] == "Female" for v in voices)
    output.mkdir(parents=True)
    rows, choices = [], {}
    for track, (name, scenes) in enumerate(NARRATION.items()):
        target = output / "素材" / name
        target.mkdir(parents=True)
        texts = [text for scene in scenes for text in scene]
        assert len(scenes) == 5 and len(texts) == 20
        assert all(len(text) <= 28 for text in texts)
        boundaries = []
        mp3 = output / f"AUDIO{track}.mp3"
        # One request per complete narration: no clip joins or added inter-scene silence.
        with mp3.open("wb") as audio:
            async for chunk in edge_tts.Communicate("".join(texts), VOICE, boundary="SentenceBoundary").stream():
                if chunk["type"] == "audio":
                    audio.write(chunk["data"])
                elif chunk["type"] == "SentenceBoundary":
                    boundaries.append(chunk)
        (output / f"timing{track}.json").write_text(json.dumps(boundaries, ensure_ascii=False, indent=2), encoding="utf-8")
        assert len(boundaries) == len(texts), "Speech sentence boundaries do not match the narration"
        clean = lambda text: "".join(c for c in text if unicodedata.category(c)[0] in "LN")
        assert all(clean(part["text"]) == clean(text) for part, text in zip(boundaries, texts))
        subprocess.run([str(ffmpeg), "-hide_banner", "-loglevel", "error", "-y", "-i", str(mp3),
                        "-ar", "24000", "-ac", "1", "-c:a", "pcm_s16le", str(target / "讲解音频.wav")],
                       check=True, creationflags=subprocess.CREATE_NO_WINDOW)
        with wave.open(str(target / "讲解音频.wav"), "rb") as wav:
            assert (wav.getframerate(), wav.getnchannels(), wav.getsampwidth()) == (24000, 1, 2)
            duration = wav.getnframes() / 24000
        cues = [(round(part["offset"] / 10000), round((part["offset"] + part["duration"]) / 10000), text)
                for part, text in zip(boundaries, texts)]
        # Sentence metadata can overlap the next onset by 50ms; keep subtitles single-valued.
        for i in range(len(cues) - 1):
            start, end, text = cues[i]
            assert end - cues[i+1][0] <= 100
            cues[i] = (start, min(end, cues[i+1][0]), text)
        srt = "\n\n".join(f"{i}\n{timestamp(start)} --> {timestamp(end)}\n{text}"
                            for i, (start, end, text) in enumerate(cues, 1)) + "\n"
        (target / "字幕.srt").write_text(srt, encoding="utf-8-sig")
        lines = [f"# {name.partition('_')[2]}：女声测试素材切图时间", "",
                 "由实际合成音频自动生成，无需手工填写。图片顺序不变。", "",
                 "| 序号 | 时间区间 | 展示图片 | 对应讲解内容 |", "|---|---|---|---|"]
        roles = ["全貌图.bmp", "细节1.bmp", "细节2.bmp", "细节3.bmp", "全貌图.bmp"]
        # Existing optional scripts have whole-second fields; exact cuts use scene_cues.json.
        script_end = round(duration)
        seconds = [0] + [round(cues[n-1][0] / 1000 * script_end / duration) for n in [5, 9, 13, 17]] + [script_end]
        for i, role in enumerate(roles):
            left, right = seconds[i:i+2]
            lines.append(f"| {i+1} | `{left//60:02}:{left%60:02} – {right//60:02}:{right%60:02}` | **{role}** | {' '.join(scenes[i])} |")
        (target / "图片切换脚本.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
        total = round(duration * 48000)
        parsed = parse_srt(target / "字幕.srt", total, "direct")
        assert [text for _, _, text in parsed] == texts
        script_cuts = parse_scene_script(target / "图片切换脚本.md", total)
        assert all(abs(actual / 48000 - cues[n-1][0] / 1000) < 0.6
                   for actual, n in zip(script_cuts, [5, 9, 13, 17]))
        for _, _, text in parsed:
            render_bitmap(text)
        choices[name] = {"subtitle_sha256": hashlib.sha256((target / "字幕.srt").read_bytes()).hexdigest(),
                         "cues": [5, 9, 13, 17]}
        rows.append({"folder": name, "voice": VOICE, "duration_s": duration,
                     "cues": len(cues), "scene_cuts_s": [cues[n-1][0]/1000 for n in [5, 9, 13, 17]],
                     "scene_first_cues": [5, 9, 13, 17], "audio_format": "PCM16 / 24000 Hz / mono"})
        print(json.dumps(rows[-1], ensure_ascii=False), flush=True)
    (output / "scene_cues.json").write_text(json.dumps(choices, ensure_ascii=False, indent=2), encoding="utf-8")
    report = {"artifacts": rows, "image_sha256": image_hashes, "added_middle_silence_ms": 0}
    (output / "generation_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    assert all(hashlib.sha256((source / p).read_bytes()).hexdigest() == digest for p, digest in image_hashes.items())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    asyncio.run(generate(args.source.resolve(), args.output.resolve()))
