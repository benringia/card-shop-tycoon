"""The Forge Spear (Common, the Forge, five element recolours of its gems; weapons round 2, spec
2026-11-07-weapons-round2-design): Meshy image-to-3D from the owner's pick A of the Figma concepts (a polished steel
leaf head, a squared iron collar set with round white gems, a wood shaft with three steel bands, a ring butt cap;
assets/blender/ForgeSpear/concept_A.png, kept out of git). weapon_kit cleans it (8.5 studs long); the collar's gems are
then tinted into the five elements (weapon_kit.FORGE_GEMS) as ForgeSpear_<Element>_color.png. Run in a background
Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "ForgeSpear"
LENGTH = 8.5
COLLAR = 0.08  # the collar's height as a share of the length, from the head's bottom (measured: 65% to 73% up)

parts, head = weapon_kit.build_spear(NAME, LENGTH)


def gems(centre):
    return head <= centre.z <= head + COLLAR * LENGTH


# Only the head's faces in its collar: the leaf's pale steel above isn't a gem
weapon_kit.recolor(NAME, [p for p in parts if p.name == "Head"], gems, weapon_kit.FORGE_GEMS)
weapon_kit.finish(NAME, parts)
