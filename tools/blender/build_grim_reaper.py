"""The Grim Reaper summoned by the Rift Reaper's Thousand Cuts (spec 2026-11-09-weapons-round3-scythes-design 5.4; the
owner: "you can even summon a grim reaper as effect"): Meshy image-to-3D from concept B (the void reaper king: a crown
of violet crystals, one slit eye, armour, the Rift Reaper's eye gem in its chest, a cape fading into smoke;
assets/blender/GrimReaper/concept_B.png, kept out of git). Cleaned like a weapon (weapon_kit): reduced to about
TARGET_TRIS triangles with one 1024 colour map, stood HEIGHT studs tall, its origin at the bottom centre (the smoke's
tip, where it rises from the rift), one mesh named Reaper. Writes GrimReaper.fbx, GrimReaper_color.png,
GrimReaper.blend and two previews. Run in a background Blender:

  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/blender/build_grim_reaper.py

The owner imports the FBX (Rig Type None) and saves it as assets/fx-models/GrimReaper.rbxm (ReplicatedStorage.FxModels).
"""
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_kit  # noqa: E402
import weapon_kit  # noqa: E402

NAME = "GrimReaper"
HEIGHT = 16
TARGET_TRIS = 6000

obj = weapon_kit.load_raw(NAME)
rig_kit.optimize(obj, NAME, target_tris=TARGET_TRIS, texture_size=1024)
zs = [v.co.z for v in obj.data.vertices]
scale = HEIGHT / (max(zs) - min(zs))
obj.scale = (scale, scale, scale)
bpy.ops.object.select_all(action="DESELECT")
obj.select_set(True)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
xs = [v.co.x for v in obj.data.vertices]
ys = [v.co.y for v in obj.data.vertices]
zs = [v.co.z for v in obj.data.vertices]
offset = Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, min(zs)))
for v in obj.data.vertices:
    v.co -= offset
obj.data.update()
obj.name = "Reaper"
obj.data.name = "Reaper"
print(f"{NAME}: {sum(len(p.vertices) - 2 for p in obj.data.polygons)} tris, {max(xs) - min(xs):.1f} x {max(ys) - min(ys):.1f} x {HEIGHT} studs")
weapon_kit.finish(NAME, [obj])
