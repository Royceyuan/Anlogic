"""Render the existing evacuation map as a silent 30-second HDMI loop."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", type=Path, required=True)
    args = parser.parse_args()
    ffmpeg = args.ffmpeg.resolve()
    work = ROOT / "_work"
    work.mkdir(exist_ok=True)
    source = ROOT.parent / "secondary_emergency_720p_v2/IMAGEA.BMP"
    output = ROOT / "06_博物馆应急疏散指引.mp4"
    assert source.is_file() and ffmpeg.is_file()
    filters = ["[0:v]scale=950:534,setsar=1[map]", "[1:v][map]overlay=304:134[base]"]
    draws = []

    def text(value, x, y, size, color="white"):
        name = hashlib.sha256(value.encode()).hexdigest()[:12] + ".txt"
        (work / name).write_text(value, encoding="utf-8")
        return (f"drawtext=fontfile='C\\:/Windows/Fonts/msyh.ttc':textfile='_work/{name}':"
                f"expansion=none:fontsize={size}:fontcolor={color}:x={x}:y={y}")

    draws += [text("博物馆应急疏散指引", 30, 24, 38),
              text("保持镇静  ·  按现场疏散标志有序撤离", 32, 80, 24, "0xbbe4cf")]
    steps = [("01  保持镇静", "听从工作人员指引", 0, 4),
             ("02  确认位置", "找到红色位置标记", 4, 6),
             ("03  沿标志撤离", "路线按原应急图演示", 6, 22),
             ("04  火灾不乘电梯", "留意现场安全出口", 22, 26),
             ("05  听从人员指引", "到达安全处后听候指引", 26, 30)]
    for index, (heading, caption, start, end) in enumerate(steps):
        y = 146 + 103 * index
        draws += [f"drawbox=x=24:y={y}:w=268:h=91:color=0x255b4b:t=fill",
                  f"drawbox=x=24:y={y}:w=268:h=91:color=0x9b332f:t=fill:enable='gte(t,{start})*lt(t,{end})'",
                  text(heading, 38, y + 12, 24), text(caption, 38, y + 52, 19, "0xe2ede7")]
    draws += [text("示意地图；实际疏散以现场标识和工作人员指引为准。", 32, 689, 19, "0xd5e6dd")]
    filters.append("[base]" + ",".join(draws) + "[labelled]")
    distance = "pow(X-16,2)+pow(Y-16,2)"
    filters.append("[2:v]format=rgba,geq="
                   f"r='if(lte({distance},121),0,255)':g='if(lte({distance},121),208,255)':"
                   f"b='if(lte({distance},121),230,255)':a='if(lte({distance},196),255,0)'[marker]")
    # Original map pixels: position -> right corridor -> lower-right exit.
    x = "if(lt(t,4),433,if(lt(t,5),433+33*(t-4),if(lt(t,13),466+35*(t-5),if(lt(t,14),746+14*(t-13),760))))"
    y = "if(lt(t,4),291,if(lt(t,5),291-13*(t-4),if(lt(t,13),278,if(lt(t,14),278+26*(t-13),304+232*min(max((t-14)/8,0),1)))))"
    filters.append(f"[labelled][marker]overlay=x='304+({x})*950/1280-16':"
                   f"y='134+({y})*534/720-16':shortest=1,format=yuv420p[out]")
    log = work / "render.log"

    def run(options):
        with log.open("a", encoding="utf-8") as errors:
            subprocess.run([str(ffmpeg), "-hide_banner", "-loglevel", "error", "-y", *options],
                           cwd=ROOT, check=True, stderr=errors, creationflags=subprocess.CREATE_NO_WINDOW)

    temporary = work / "candidate.mp4"
    run(["-loop", "1", "-framerate", "30", "-i", str(source),
         "-f", "lavfi", "-i", "color=c=0x122f28:s=1280x720:r=30",
         "-f", "lavfi", "-i", "color=c=white:s=32x32:r=30",
         "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo",
         "-filter_complex_threads", "2", "-filter_complex", ";".join(filters),
         "-map", "[out]", "-map", "3:a", "-t", "30", "-c:v", "libx264", "-preset", "medium",
         "-crf", "19", "-profile:v", "high", "-level:v", "3.1", "-g", "60", "-threads", "4",
         "-c:a", "aac", "-ar", "48000", "-ac", "2", "-b:a", "64k", "-movflags", "+faststart", str(temporary)])
    info = json.loads(subprocess.check_output([str(ffmpeg.with_name("ffprobe.exe")), "-v", "error",
        "-show_streams", "-show_format", "-of", "json", str(temporary)], creationflags=subprocess.CREATE_NO_WINDOW))
    video = next(s for s in info["streams"] if s["codec_type"] == "video")
    audio = next(s for s in info["streams"] if s["codec_type"] == "audio")
    assert (video["codec_name"], video["width"], video["height"], video["r_frame_rate"]) == ("h264", 1280, 720, "30/1")
    assert audio["codec_name"] == "aac" and audio["channels"] == 2 and audio["sample_rate"] == "48000"
    assert abs(float(info["format"]["duration"]) - 30) < 0.1
    run(["-i", str(temporary), "-f", "null", "NUL"])
    for i, second in enumerate((0.2, 4.5, 8, 13.5, 18, 24, 28, 29.8)):
        run(["-ss", str(second), "-i", str(temporary), "-frames:v", "1", "-update", "1", str(work / f"qa_{i}.png")])
    run(["-i", str(work / "qa_%d.png"), "-vf", "scale=384:216,tile=4x2", "-frames:v", "1", "-update", "1", str(work / "preview.png")])
    temporary.replace(output)
    (ROOT / "manifest.json").write_text(json.dumps({"file": output.name, "duration_s": 30,
        "format": "H264 1280x720 30fps yuv420p; AAC stereo 48kHz silence",
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "source_map_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "safety": "Demo map only. Follow actual signs and staff; not a certified evacuation system.",
        "references": ["https://www.119.gov.cn/kp/hzyf/ggylcs/2022/32305.shtml",
                       "https://www.119.gov.cn/kp/zjts/hz/2025/49981.shtml"]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("PASS emergency video: 30s, H264/AAC, full decode, original map preserved")


if __name__ == "__main__":
    main()
