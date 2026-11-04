"""Renders a preview of each Wild valley scenery prop (build_valley_props.py) for the owner to judge before importing:
one PNG per prop, front three-quarter view, the Glow object lit up in a sample glow colour. Run in a background Blender:
  blender -b --factory-startup --python tools/blender/render_valley_props.py -- <out_dir>
PROPS="A,B" renders only those. Nothing is saved to assets/ (EXPORT is forced to 0).
"""
import math
import os
import sys

import bpy
from mathutils import Vector

os.environ["EXPORT"] = "0"
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import portal_kit  # noqa: E402
import build_valley_props as valley  # noqa: E402

# a sample glow per prop for the preview (the game picks each spot's colour from Config/WildValley GLOW)
SAMPLE_GLOW = {"GlowMushroomCluster": (190, 120, 255), "GlowFlowers": (110, 190, 255), "EmberTree": (255, 130, 40),
               "DragonSkeleton": (255, 130, 40)}
TEAL = (80, 235, 215)
SIZE = 420


def emission(rgb):
    mat = bpy.data.materials.new("PreviewGlow")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    colour = (rgb[0] / 255, rgb[1] / 255, rgb[2] / 255, 1)
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Emission Color"].default_value = colour
    bsdf.inputs["Emission Strength"].default_value = 1.0
    return mat


def stage(objects):
    scene = bpy.context.scene
    low = Vector((min(v[0] for o in objects for v in o.bound_box), min(v[1] for o in objects for v in o.bound_box), min(v[2] for o in objects for v in o.bound_box)))
    high = Vector((max(v[0] for o in objects for v in o.bound_box), max(v[1] for o in objects for v in o.bound_box), max(v[2] for o in objects for v in o.bound_box)))
    centre = (low + high) / 2
    reach = max((high - low).length, 0.5)
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(camera)
    camera.location = centre + Vector((reach * 0.55, -reach * 1.05, reach * 0.45))
    direction = centre - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.lens = 40
    scene.camera = camera
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.62, 0.7, 0.78, 1)
    background.inputs["Strength"].default_value = 0.9
    scene.world = world


def set_engine(scene):
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    for wanted in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE", "BLENDER_WORKBENCH"):
        if wanted in engines:
            scene.render.engine = wanted
            return wanted
    return scene.render.engine


def run(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    wanted = [name for name in os.environ.get("PROPS", ",".join(valley.PROPS)).split(",") if name]
    for name in wanted:
        portal_kit.begin(name)
        colors, objects = valley.PROPS[name]()
        portal_kit.export(name, objects, colors)
        for obj in objects:
            if obj.name.startswith("Glow"):
                obj.data.materials.clear()
                obj.data.materials.append(emission(SAMPLE_GLOW.get(name, TEAL)))
        stage(objects)
        scene = bpy.context.scene
        set_engine(scene)
        scene.render.resolution_x = SIZE
        scene.render.resolution_y = SIZE
        scene.render.film_transparent = False
        scene.render.filepath = os.path.join(out_dir, f"valley-prop-{name}.png")
        bpy.ops.render.render(write_still=True)
        print("rendered", name)


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
run(args[0] if args else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".superpowers", "previews"))
