"""The Storm Reaper (Epic, Volt, the Storm Sovereign's scythe; weapons round 3, spec
2026-11-09-weapons-round3-scythes-design): Meshy image-to-3D from the owner's pick B of the Figma concepts (a steel-blue
blade veined with gold lightning, a gold eagle socket set with a yellow storm gem, a navy shaft with gold rings, a
lightning-bolt butt; assets/blender/StormReaper/concept_B.png, kept out of git). weapon_kit cleans it (8.6 studs long).
Run in a background Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "StormReaper"

parts, _ = weapon_kit.build_scythe(NAME, 8.6)
weapon_kit.finish(NAME, parts)
