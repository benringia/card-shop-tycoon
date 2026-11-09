"""The Rift Reaper (Legendary, Shade, the Rift Devourer's scythe; weapons round 3, spec
2026-11-09-weapons-round3-scythes-design): Meshy image-to-3D from the owner's pick B of the Figma concepts (a black
blade split by glowing violet void cracks, a crown of violet crystals round a slit-eye gem at the socket, a twisted
black shaft with violet bands, a silver crescent butt; assets/blender/RiftReaper/concept_B.png, kept out of git).
weapon_kit cleans it (9 studs long). Run in a background Blender (see weapon_kit)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import weapon_kit  # noqa: E402

NAME = "RiftReaper"

parts, _ = weapon_kit.build_scythe(NAME, 9)
weapon_kit.finish(NAME, parts)
