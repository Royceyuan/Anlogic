"""Render a six-second, immediately readable evacuation-direction loop."""
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
    filters = ["[0:v]crop=620:490:285:120,scale=668:528,setsar=1[map]",
               "[1:v][map]overlay=590:134[base]"]
    draws = []

    def text(value, x, y, size, color="white"):
        name = hashlib.sha256(value.encode()).hexdigest()[:12] + ".txt"
        (work / name).write_text(value, encoding="utf-8")
        return (f"drawtext=fontfile='C\\:/Windows/Fonts/msyh.ttc':textfile='_work/{name}':"
                f"expansion=none:fontsize={size}:fontcolor={color}:x={x}:y={y}")

    # All instructions are visible on the first frame. Motion attracts attention
    # without flashing the whole screen or requiring a 30-second reading cycle.
    draws += ["drawbox=x=0:y=0:w=iw:h=116:color=0xa52c27:t=fill",
              text("紧急疏散", 28, 15, 62),
              text("按现场标志有序撤离", 466, 30, 40),
              "drawbox=x=20:y=134:w=530:h=528:color=0x163f31:t=fill",
              text("当前示意位置 → 安全出口", 36, 148, 28, "0xffdc62"),
              text("先向右", 36, 218, 68),
              text("再向下", 36, 432, 62),
              text("红点起步，沿右侧通道到出口", 36, 588, 27, "0xd2eedc"),
              "drawbox=x=0:y=672:w=iw:h=48:color=0x080f0c:t=fill",
              text("火灾不乘电梯  ·  不拥挤  ·  听从工作人员指引", 28, 680, 29),
              text("演示路线，以现场指引为准", 885, 686, 22, "0xffdc62")]
    filters.append("[base]" + ",".join(draws) + "[labelled]")
    outer = "max(between(X,1,15)*between(Y,11,21),between(X,10,30)*lte(abs(Y-16),30-X))"
    inner = "max(between(X,3,15)*between(Y,13,19),between(X,12,27)*lte(abs(Y-16),27-X))"
    filters.append("[2:v]format=rgba,geq="
                   f"r='255*({inner})':g='220*({inner})':b=0:a='255*({outer})',"
                   "split=9[m0][m1][m2][r0][r1][r2][d0][d1][d2]")
    previous = "labelled"
    for i in range(3):
        q = f"mod(t+{i * 2 / 3:.6f},2)"
        x = f"if(lt({q},0.1),433+320*{q},if(lt({q},1),465+280*({q}-0.1)/0.9,if(lt({q},1.1),745+150*({q}-1),760)))"
        y = f"if(lt({q},0.1),291-130*{q},if(lt({q},1),278,if(lt({q},1.1),278+260*({q}-1),304+232*({q}-1.1)/0.9)))"
        filters += [f"[m{i}]rotate='if(lt({q},1.05),0,PI/2)':c=none[turn{i}]",
                    f"[{previous}][turn{i}]overlay=x='590+(({x})-285)*668/620-16':"
                    f"y='134+(({y})-120)*528/490-16':shortest=1[p{i}]"]
        previous = f"p{i}"
    for i in range(3):
        filters += [f"[r{i}]scale=64:64[big_r{i}]",
                    f"[{previous}][big_r{i}]overlay=x='40+mod(t*288+{i*144},432)':y=310:shortest=1[rr{i}]"]
        previous = f"rr{i}"
    for i in range(3):
        filters += [f"[d{i}]scale=64:64,rotate=PI/2:c=none[big_d{i}]",
                    f"[{previous}][big_d{i}]overlay=x=458:y='392+mod(t*132+{i*66},198)':shortest=1[dd{i}]"]
        previous = f"dd{i}"
    filters.append(f"[{previous}]format=yuv420p[out]")
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
         "-map", "[out]", "-map", "3:a", "-t", "6", "-c:v", "libx264", "-preset", "medium",
         "-crf", "19", "-profile:v", "high", "-level:v", "3.1", "-g", "30", "-bf", "0", "-threads", "4",
         "-c:a", "aac", "-ar", "48000", "-ac", "2", "-b:a", "64k", "-movflags", "+faststart", str(temporary)])
    info = json.loads(subprocess.check_output([str(ffmpeg.with_name("ffprobe.exe")), "-v", "error",
        "-show_streams", "-show_format", "-of", "json", str(temporary)], creationflags=subprocess.CREATE_NO_WINDOW))
    video = next(s for s in info["streams"] if s["codec_type"] == "video")
    audio = next(s for s in info["streams"] if s["codec_type"] == "audio")
    assert (video["codec_name"], video["width"], video["height"], video["r_frame_rate"]) == ("h264", 1280, 720, "30/1")
    assert audio["codec_name"] == "aac" and audio["channels"] == 2 and audio["sample_rate"] == "48000"
    assert abs(float(info["format"]["duration"]) - 6) < 0.1 and int(video["has_b_frames"]) == 0
    run(["-i", str(temporary), "-f", "null", "NUL"])
    for i, second in enumerate((0, 0.3, 0.8, 1.3, 2.1, 3.5, 4.8, 5.9)):
        run(["-ss", str(second), "-i", str(temporary), "-frames:v", "1", "-update", "1", str(work / f"qa_{i}.png")])
    run(["-i", str(work / "qa_%d.png"), "-vf", "scale=384:216,tile=4x2", "-frames:v", "1", "-update", "1", str(work / "preview.png")])
    temporary.replace(output)
    (ROOT / "manifest.json").write_text(json.dumps({"file": output.name, "duration_s": 6,
        "format": "H264 1280x720 30fps yuv420p; AAC stereo 48kHz silence",
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "source_map_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "safety": "Demo map only. Follow actual signs and staff; not a certified evacuation system.",
        "references": ["https://www.119.gov.cn/kp/hzyf/ggylcs/2022/32305.shtml",
                       "https://www.119.gov.cn/kp/zjts/hz/2025/49981.shtml"]}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("PASS emergency video: 6s, immediate instructions, moving arrows, no B frames, full decode")


if __name__ == "__main__":
    main()
