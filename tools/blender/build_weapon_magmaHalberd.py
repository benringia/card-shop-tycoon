"""The Magma Halberd (Very Rare, Ember, the Ember Colossus' weapon; weapons round 2, spec
2026-11-07-weapons-round2-design): Meshy image-to-3D from the owner's pick A of the Figma concepts (an obsidian axe blade
with lava cracks, a molten spike, a back hook, a charred shaft with iron rings, a fire gem;
assets/blender/MagmaHalberd/concept_A.png, kept out of git). weapon_kit cleans it (8.5 studs long). Run in a background
Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "MagmaHalberd"

parts, _ = weapon_kit.build_spear(NAME, 8.5)
weapon_kit.finish(NAME, parts)
