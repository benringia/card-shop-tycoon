"""The Forge Scythe (Common, the Forge, five element recolours of its gems; weapons round 3, spec
2026-11-09-weapons-round3-scythes-design): Meshy image-to-3D from the owner's pick B of the Figma concepts (a hammered
steel blade with notched spine, a squared iron socket set with three round white gems, an ash shaft with riveted iron
bands, a steel spike butt; assets/blender/ForgeScythe/concept_B.png, kept out of git). weapon_kit cleans it (8 studs
long); the socket's gems are then tinted into the five elements (weapon_kit.FORGE_GEMS) as
ForgeScythe_<Element>_color.png. Run in a background Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "ForgeScythe"
LENGTH = 8
GRIP_SHARE = 1 / 3
# The socket's gems: faces near the shaft (|x| under SOCKET_X studs; the blade is far out at -X) between these shares of
# the length up from the butt (measured: the white gems' faces from 85% to 97%)
SOCKET = (0.84, 0.98)
SOCKET_X = 0.25

parts, head = weapon_kit.build_scythe(NAME, LENGTH, GRIP_SHARE)
butt = -GRIP_SHARE * LENGTH


def gems(centre):
    return abs(centre.x) < SOCKET_X and butt + SOCKET[0] * LENGTH <= centre.z <= butt + SOCKET[1] * LENGTH


weapon_kit.recolor(NAME, [p for p in parts if p.name == "Head"], gems, weapon_kit.FORGE_GEMS)
weapon_kit.finish(NAME, parts)
