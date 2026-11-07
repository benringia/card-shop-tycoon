"""The Forge Sword (Common, the Forge (five element recolours of its gems)): Meshy image-to-3D from the owner's pick A of the Figma concepts (a polished steel
broadsword, a squared iron guard and a ring pommel, each with a round white gem; assets/blender/ForgeSword/concept_A.png,
kept out of git). weapon_kit cleans it (5.0 studs long); its gems are then tinted into the five elements
(Config/WeaponLooks BY_ELEMENT glow colours) as ForgeSword_<Element>_color.png. Run in a background Blender (see
weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "ForgeSword"
ELEMENTS = weapon_kit.FORGE_GEMS

parts, guard_bottom, guard_top = weapon_kit.build(NAME, 5.0)
lowest = min((o.matrix_world @ v.co).z for o in parts for v in o.data.vertices)
pommel_top = lowest + 0.35 * (guard_bottom - lowest)


def gems(centre):
    in_guard = abs(centre.x) < 0.28 and guard_bottom <= centre.z <= guard_top
    return in_guard or centre.z <= pommel_top


# Only the guard's and the grip's faces: the blade's pale steel near the guard isn't a gem
weapon_kit.recolor(NAME, [p for p in parts if p.name != "Blade"], gems, ELEMENTS)
weapon_kit.finish(NAME, parts)
