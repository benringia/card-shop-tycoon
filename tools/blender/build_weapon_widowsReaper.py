"""The Widow's Reaper (Very Rare, Shade, the Cave Brood Queen's scythe; weapons round 3, spec
2026-11-09-weapons-round3-scythes-design): Meshy image-to-3D from the owner's pick B of the Figma concepts (a violet
blade with a spined back, a black spider clutching the socket, a bone-white shaft wrapped in black web bands, a violet
fang butt; assets/blender/WidowsReaper/concept_B.png, kept out of git). weapon_kit cleans it (8.3 studs long). Run in a
background Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "WidowsReaper"

parts, _ = weapon_kit.build_scythe(NAME, 8.3)
weapon_kit.finish(NAME, parts)
