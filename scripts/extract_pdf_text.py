import sys
from pathlib import Path

import fitz


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: extract_pdf_text.py <input.pdf> <output.txt>")
        return 1

    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])

    doc = fitz.open(src)
    parts = []
    for idx, page in enumerate(doc, start=1):
        parts.append(f"--- PAGE {idx} ---\n")
        parts.append(page.get_text("text"))
        parts.append("\n")

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text("".join(parts), encoding="utf-8")
    print(f"pages={len(doc)}")
    print(f"out={dst}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
