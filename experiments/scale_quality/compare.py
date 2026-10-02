"""Read-only source images; emulates loader RGB565/DDA and 3/4 HDMI mapping.

Requires the already-used Pillow only. PNGs/JSON go to ignored build output.
No media conversion or production RTL changes. Run from any directory.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
MODES = ("nearest", "horizontal", "bilinear")


def fit_size(w, h):
    return (960, max(1, h * 960 // w)) if 540*w >= 960*h else (max(1, w*540//h), 540)


def sample(corners, fx, fy, mode):
    a, b, c, d = corners
    if mode == "nearest":
        return a
    h0 = a*256 + (b-a)*fx
    if mode == "horizontal":
        return (h0+128)//256
    h1 = c*256 + (d-c)*fx
    return (h0*256 + (h1-h0)*fy+32768)//65536


def render(image, mode):
    w, h = image.size
    fw, fh = fit_size(w, h)
    ox, oy = (960-fw)//2, (540-fh)//2
    # Real card BMPs are bottom-up: source row zero is the bottom row.
    xs = [divmod(x*w, fw) for x in range(fw)]
    ys = [divmod((fh-1-y)*h, fh) for y in range(fh)]
    data = image.convert("RGB").tobytes()
    quant = [(r>>3, g>>2, b>>3) for r,g,b in zip(data[0::3],data[1::3],data[2::3])]
    canvas = Image.new("RGB", (960,540), (24,28,24))  # 0x18E3 expanded
    pixels = canvas.load()
    for y,(yb,yr) in enumerate(ys):
        y0, y1 = h-1-yb, max(0,h-2-yb)
        fy = yr*256//fh
        for x,(x0,xr) in enumerate(xs):
            x1, fx = min(w-1,x0+1), xr*256//fw
            a,b,c,d = (quant[y0*w+x0],quant[y0*w+x1],quant[y1*w+x0],quant[y1*w+x1])
            rgb = [sample((a[k],b[k],c[k],d[k]),fx,fy,mode) for k in range(3)]
            pixels[x+ox,y+oy] = ((rgb[0]<<3)|(rgb[0]>>2), (rgb[1]<<2)|(rgb[1]>>4), (rgb[2]<<3)|(rgb[2]>>2))
    # Explicit floor(3*x/4), not Pillow's different pixel-centre convention.
    output = Image.new("RGB", (1280,720))
    output.putdata([pixels[x*3//4,y*3//4] for y in range(720) for x in range(1280)])
    return output


def pattern():
    image = Image.new("RGB", (1280,720), "#f5f1e9")
    d = ImageDraw.Draw(image)
    for x in range(0,1280,17):
        d.line((x,0,x+400,719), fill="#244456",width=2)
    for y in range(365,720,9):
        d.line((0,y,1279,y), fill="#885d31",width=1)
    d.rectangle((30,20,390,165),fill="#f5f1e9")
    d.text((45,35),"DIAGONAL / FINE DETAIL\n1280 x 720 -> 960 x 540\n-> 1280 x 720",fill="#244456",font=ImageFont.truetype("C:/Windows/Fonts/consola.ttf",18))
    return image


def smooth_field(x, y):
    return tuple(maximum*(0.5+0.45*math.sin(2*math.pi*(ax*x+ay*y)))
                 for maximum,ax,ay in ((31,.065,.051),(63,-.04,.06),(31,.08,-.035)))


def smooth_pattern():
    image=Image.new("RGB",(1280,720))
    def rgb(x,y):
        r,g,b=(round(v) for v in smooth_field(x,y))
        return ((r<<3)|(r>>2),(g<<2)|(g>>4),(b<<3)|(b>>2))
    image.putdata([rgb(x,y) for y in range(720) for x in range(1280)])
    return image


def smooth_error(results):
    # Analytic truth at the SAME DDA coordinates. Quantised input samples, a
    # deliberately band-limited field; not a universal photograph-quality score.
    errors=[0.0]*3
    readers=[im.load() for im in results]
    for y in range(720):
        sy=719-(539-y*3//4)*720/540
        for x in range(1280):
            truth=smooth_field((x*3//4)*1280/960,sy)
            for i,reader in enumerate(readers):
                r,g,b=reader[x,y]
                errors[i]+=sum((v-t)**2 for v,t in zip((r>>3,g>>2,b>>3),truth))
    return {mode: value/(1280*720*3) for mode,value in zip(MODES,errors)}


def check():
    assert fit_size(1920,1080)==(960,540)
    assert fit_size(720,1080)==(360,540)
    assert fit_size(1080,1080)==(540,540)
    # Convex interpolation cannot overshoot, exact constant preservation.
    max_difference=0
    for maximum in (31,63):
        for fx in range(256):
            for fy in range(256):
                corners=(0,maximum,maximum,0)
                result=sample(corners,fx,fy,"bilinear")
                reference=(corners[0]*(256-fx)*(256-fy)+corners[1]*fx*(256-fy)+corners[2]*(256-fx)*fy+corners[3]*fx*fy+32768)//65536
                assert result==reference and 0<=result<=maximum
                # Q0.8 weights versus exact fractions can alter at most one
                # RGB565 channel code; this is numeric error, not image quality.
                exact_fx=(fx+0.5)/256; exact_fy=(fy+0.5)/256
                exact=round(maximum*(exact_fx+exact_fy-2*exact_fx*exact_fy))
                max_difference=max(max_difference,abs(result-exact))
        for value in range(maximum+1):
            for mode in MODES:
                assert sample((value,)*4,137,219,mode)==value
    assert max_difference<=1
    return max_difference


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source",type=Path,default=ROOT.parent/"素材")
    parser.add_argument("--output",type=Path,default=ROOT/"_build_scale_quality"/"visuals")
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    summary={"numeric_self_check_max_channel_code_error":check(),"mapping":"bottom-up BMP DDA floor; HDMI floor(3*x/4)","images":[]}
    images=[("diagonal",pattern()),("smooth_field",smooth_pattern())]
    sources={}
    for directory in sorted(args.source.glob("0[12345]_*")):
        # One existing detail per artifact; no source modification/resampling.
        candidates=sorted(directory.glob("细节1*.png"))
        if candidates:
            sources[directory.name]=candidates[0]
            with Image.open(candidates[0]) as image:
                images.append((directory.name,image.convert("RGB")))
    font=ImageFont.truetype("C:/Windows/Fonts/consola.ttf",20)
    for name,image in images:
        w,h=image.size
        if not(16<=w<=1920 and 16<=h<=1080):
            # Explicitly report out-of-limit sources, never hide a PC resize.
            summary["images"].append({"name":name,"source_size":[w,h],"skipped":"outside current FPGA 1920x1080 bounds"})
            continue
        results=[render(image,mode) for mode in MODES]
        sheet=Image.new("RGB",(1280*3,760),"#f5f1e9")
        d=ImageDraw.Draw(sheet)
        for i,(mode,result) in enumerate(zip(MODES,results)):
            sheet.paste(result,(1280*i,40))
            d.text((1280*i+16,10),f"{mode} | source {w}x{h} | 960x540 cache",font=font,fill="black")
        sheet.save(args.output/f"{name}.png")
        # Same source/output crop for every method; nearest enlargement is
        # inspection only and isn't an additional algorithm quality upgrade.
        crop=(480,240,736,496)
        close=Image.new("RGB",(768*3,810),"#f5f1e9")
        cd=ImageDraw.Draw(close)
        for i,(mode,result) in enumerate(zip(MODES,results)):
            close.paste(result.crop(crop).resize((768,768),Image.Resampling.NEAREST),(768*i,42))
            cd.text((768*i+16,10),mode,font=font,fill="black")
        close.save(args.output/f"{name}_crop.png")
        record={"name":name,"source_size":[w,h],"fit_size":fit_size(w,h),"comparison":str(args.output/f"{name}.png")}
        if name in sources:
            source=sources[name]
            record.update(source=str(source),sha256=hashlib.sha256(source.read_bytes()).hexdigest())
        if name=="smooth_field":
            record["analytic_mse_rgb565_code_squared"]=smooth_error(results)
        summary["images"].append(record)
        print(f"PASS comparison {name}: {w}x{h} -> {fit_size(w,h)} -> 1280x720",flush=True)
    (args.output/"results.json").write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding="utf-8")


if __name__=="__main__":
    main()
