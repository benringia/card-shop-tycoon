"""The Tidal Trident (Epic, Tide, the Frost Tyrant's weapon; weapons round 2, spec 2026-11-07-weapons-round2-design):
Meshy image-to-3D from the owner's pick A of the Figma concepts (three frosted ice-crystal prongs, a sea-glass wave
collar, a pearl-white shaft with a silver spiral, an aquamarine gem; assets/blender/TidalTrident/concept_A.png, kept out
of git). weapon_kit cleans it (8.7 studs long). Run in a background Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "TidalTrident"

parts, _ = weapon_kit.build_spear(NAME, 8.7)
weapon_kit.finish(NAME, parts)
