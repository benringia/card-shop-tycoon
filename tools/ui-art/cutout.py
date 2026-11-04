"""Cut stickers out of a generated picture on a flat green background (HUD mascot art, docs/hud-mascot.md).

    python tools/ui-art/cutout.py <in.png> <out dir> <name> [<name> ...]

Keys out the green (soft edge from how green a pixel is), removes the green fringe, splits the picture into stickers
left to right at fully empty columns, trims each and saves it as <out dir>/<name>.png (transparent, at most 512 px
on its longer side). Give one name per sticker, in left-to-right order. Needs Pillow.
"""

import sys
from pathlib import Path

from PIL import Image

LOW, HIGH = 40, 170  # greenness (g - max(r, b)) where a pixel starts and finishes turning see-through
MAX_SIDE = 512
MIN_WIDTH = 8  # columns: narrower groups are specks, not stickers


def key(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, _ = pixels[x, y]
            greenness = g - max(r, b)
            if greenness <= LOW:
                continue
            alpha = 0 if greenness >= HIGH else round(255 * (1 - (greenness - LOW) / (HIGH - LOW)))
            pixels[x, y] = (r, min(g, max(r, b)), b, alpha)  # despill: no green brighter than red or blue
    return rgba


def groups(rgba: Image.Image) -> list[tuple[int, int]]:
    alpha = rgba.getchannel("A")
    width, height = rgba.size
    data = alpha.load()
    filled = [any(data[x, y] > 16 for y in range(height)) for x in range(width)]
    spans, start = [], None
    for x, on in enumerate(filled + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            if x - start >= MIN_WIDTH:
                spans.append((start, x))
            start = None
    return spans


def main() -> None:
    if len(sys.argv) < 4:
        sys.exit(__doc__)
    source, out_dir, names = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3:]
    rgba = key(Image.open(source))
    spans = groups(rgba)
    if len(spans) != len(names):
        sys.exit(f"found {len(spans)} stickers, got {len(names)} names")
    out_dir.mkdir(parents=True, exist_ok=True)
    for (left, right), name in zip(spans, names):
        piece = rgba.crop((left, 0, right, rgba.size[1]))
        piece = piece.crop(piece.getchannel("A").point(lambda a: 255 if a > 16 else 0).getbbox())
        scale = min(1.0, MAX_SIDE / max(piece.size))
        if scale < 1:
            piece = piece.resize((round(piece.size[0] * scale), round(piece.size[1] * scale)), Image.LANCZOS)
        path = out_dir / f"{name}.png"
        piece.save(path)
        print(f"{path} {piece.size[0]}x{piece.size[1]}")


if __name__ == "__main__":
    main()
