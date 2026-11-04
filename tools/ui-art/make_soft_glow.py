"""The cotton candy look's soft glow (spec 2026-11-03-cotton-candy-ui-design).

A white rounded square, blurred, with the square itself cut out: drawn 9-sliced and tinted round a button, a tile, a
window or a portrait, only the soft glow outside it shows, so it can sit over the thing it glows under.

    python tools/ui-art/make_soft_glow.py assets/ui/soft/Glow.png

The picture is SIZE px square; the square sits MARGIN px in with a CORNER px radius. UIKit.glow slices it at
MARGIN + CORNER (Config/BabyColors GLOW) and scales the slices so the hole's corner matches the thing's own.
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128
MARGIN = 32
CORNER = 24
BLUR = 9  # Gaussian radius: the glow fades out well inside the margin


def main(out_path: str) -> None:
    shape = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(shape).rounded_rectangle(
        (MARGIN, MARGIN, SIZE - MARGIN - 1, SIZE - MARGIN - 1), radius=CORNER, fill=255
    )
    glow = shape.filter(ImageFilter.GaussianBlur(BLUR))
    # Cut the square out: inside it the picture is clear, so the thing under it shows untouched
    alpha = Image.composite(Image.new("L", (SIZE, SIZE), 0), glow, shape)
    picture = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    picture.putalpha(alpha)
    picture.save(out_path)
    centre = alpha.getpixel((SIZE // 2, SIZE // 2))
    edge = alpha.getpixel((MARGIN - 4, SIZE // 2))
    corner = alpha.getpixel((2, 2))
    print(f"wrote {out_path}: centre alpha {centre}, just outside the edge {edge}, far corner {corner}")


if __name__ == "__main__":
    main(sys.argv[1])
