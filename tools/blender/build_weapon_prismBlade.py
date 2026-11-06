"""The PrismBlade (Legendary, every element, the Prism Hydra's weapon): Meshy image-to-3D from the owner's pick of the Figma concepts
(assets/blender/PrismBlade/concept_*.png, kept out of git). weapon_kit cleans it (5.4 studs long). Run in a background
Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "PrismBlade"

parts, _, _ = weapon_kit.build(NAME, 5.4)
weapon_kit.finish(NAME, parts)
