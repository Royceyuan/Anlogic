"""Preserve the supplied evacuation map in the secondary's 720p BMP format."""

from pathlib import Path
import struct

from PIL import Image, ImageOps


OUT = Path(__file__).resolve().parents[1] / "assets/secondary_emergency_720p_v2"


with Image.open(OUT / "source.png") as source:
    fitted = ImageOps.contain(source.convert("RGB"), (1280, 720), Image.Resampling.LANCZOS)
    page = Image.new("RGB", (1280, 720), (24, 82, 68))
    page.paste(fitted, ((1280 - fitted.width) // 2, 0))
    page.save(OUT / "IMAGEA.BMP")

data = (OUT / "IMAGEA.BMP").read_bytes()
assert len(data) == 54 + 1280 * 720 * 3
assert struct.unpack_from("<iiHHI", data, 18) == (1280, 720, 1, 24, 0)
print(f"Created {OUT / 'IMAGEA.BMP'} ({len(data)} bytes)")
