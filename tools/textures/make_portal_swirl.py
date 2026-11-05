"""The Wild loading screen's portal swirl (owner 2026-11-05, option A "Portal swirl"): white with the shape in the
alpha, so the screen tints it (two copies turning against each other in the portal's greens). Written to
assets/ui/fx-portal (uploaded as an image; id in Config/WildLoading SWIRL):

  swirl   five soft spiral arms curling in to a bright core, fading out at the rim

Square, 512 px. Usage: python tools/textures/make_portal_swirl.py [out dir]. Needs Pillow."""
import math
import os
import sys

from PIL import Image, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/ui/fx-portal"

SIZE = 512
ARMS = 5
TWIST = 2.6  # radians an arm turns from the core to the rim
ARM_WIDTH = 0.62  # of the gap between arms, at full brightness


def swirl():
    half = SIZE / 2
    mask = Image.new("L", (SIZE, SIZE), 0)
    pixels = mask.load()
    gap = 2 * math.pi / ARMS
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = (x + 0.5 - half) / half, (y + 0.5 - half) / half
            r = math.hypot(dx, dy)
            if r >= 1:
                continue
            # the angle along an arm: arms curl as they go out
            angle = math.atan2(dy, dx) - TWIST * r
            phase = (angle % gap) / gap  # 0..1 across one arm and its gap
            arm = max(0.0, 1 - abs(phase - 0.5) / (ARM_WIDTH / 2 + 0.5 * (1 - ARM_WIDTH) * (1 - r)))
            arm = arm ** 1.6
            rim = max(0.0, 1 - r) ** 0.7  # fades out to the rim
            core = max(0.0, 1 - r / 0.34) ** 2  # a bright core
            value = min(1.0, arm * rim * 0.95 + core)
            pixels[x, y] = int(value * 255)
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    img = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    img.putalpha(mask)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    swirl().save(os.path.join(OUT, "swirl.png"))
    print("wrote", os.path.join(OUT, "swirl.png"))


if __name__ == "__main__":
    main()
