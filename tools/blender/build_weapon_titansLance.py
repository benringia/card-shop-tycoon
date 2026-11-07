"""The Titan's Lance (Legendary Masterwork, Bloom; weapons round 2, spec 2026-11-07-weapons-round2-design): Meshy
image-to-3D from the owner's pick A of the Figma concepts (a gold-white lance head with emerald veins, a leaf-carved cone
guard, a living-wood shaft wrapped in golden flowers, an emerald gem; assets/blender/TitansLance/concept_A.png, kept out
of git). weapon_kit cleans it (9.2 studs long, the biggest spear). Run in a background Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "TitansLance"

parts, _ = weapon_kit.build_spear(NAME, 9.2)
weapon_kit.finish(NAME, parts)
