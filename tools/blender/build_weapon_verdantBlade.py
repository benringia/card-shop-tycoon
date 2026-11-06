"""The VerdantBlade (Rare, Bloom, the Meadow Warden's weapon): Meshy image-to-3D from the owner's pick of the Figma concepts
(assets/blender/VerdantBlade/concept_*.png, kept out of git). weapon_kit cleans it (5.2 studs long). Run in a background
Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "VerdantBlade"

parts, _, _ = weapon_kit.build(NAME, 5.2)
weapon_kit.finish(NAME, parts)
