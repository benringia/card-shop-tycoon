"""Makes a generated pattern tile seamlessly (shop decor's wallpapers, assets/ui/decor-wallpapers): the picture blended
with a copy of itself shifted by half, the copy showing at the edges (where it wraps cleanly) and the original in the
middle, then resized. Needs Pillow.

  python tools/textures/make_seamless.py <in.png> <out.png> [size]
"""
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter


def seamless(image: Image.Image) -> Image.Image:
    width, height = image.size
    shifted = ImageChops.offset(image, width // 2, height // 2)
    # The original's weight: full in the middle, fading to nothing a quarter from each edge
    mask = Image.new("L", (width, height), 0)
    margin_x, margin_y = width // 6, height // 6
    ImageDraw.Draw(mask).rectangle((margin_x, margin_y, width - margin_x, height - margin_y), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(width, height) // 10))
    return Image.composite(image, shifted, mask)


def main():
    source, target = sys.argv[1], sys.argv[2]
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 512
    image = Image.open(source).convert("RGB")
    seamless(image).resize((size, size), Image.LANCZOS).save(target)
    print("wallpaper", target)


if __name__ == "__main__":
    main()
