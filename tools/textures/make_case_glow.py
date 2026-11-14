"""Makes the glass cases' floor glow (owner 2026-11-14, concept B "museum vitrine": the pool of light round the
pedestal's foot): a white picture, opaque over the pedestal's footprint and fading out past its edges, so the light
hugs the foot instead of a round glow whose bright middle hides under the case. Config/Town CASE_LOOK FLOOR_GLOW lays
it over a case's footprint plus `reach` studs on every side; the game tints it the glow strip's colour.

Usage: python tools/textures/make_case_glow.py [out.png]   (default assets/ui/fx-case/case_floor_glow.png; needs Pillow)
"""
import math
import os
import sys

from PIL import Image

CASE = (6.0, 2.0)  # Config/Shelves: the cases' footprint (width, depth), studs
REACH = 1.1  # Config/Town CASE_LOOK FLOOR_GLOW reach, studs
PIXELS_PER_STUD = 62
FALLOFF = 2.2  # the higher, the faster the light fades past the foot


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "fx-case", "case_floor_glow.png")
    width = round((CASE[0] + 2 * REACH) * PIXELS_PER_STUD)
    height = round((CASE[1] + 2 * REACH) * PIXELS_PER_STUD)
    left, right = REACH * PIXELS_PER_STUD, (REACH + CASE[0]) * PIXELS_PER_STUD
    top, bottom = REACH * PIXELS_PER_STUD, (REACH + CASE[1]) * PIXELS_PER_STUD
    reach = REACH * PIXELS_PER_STUD
    image = Image.new("RGBA", (width, height))
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            dx = max(left - x, 0, x - right)
            dy = max(top - y, 0, y - bottom)
            outside = math.hypot(dx, dy) / reach
            alpha = max(0.0, 1.0 - outside) ** FALLOFF
            pixels[x, y] = (255, 255, 255, round(255 * alpha))
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
    image.save(out)
    print("wrote", os.path.abspath(out), image.size)


if __name__ == "__main__":
    main()
