"""Run in Blender: blender -b --python tools/art/normalize_door_frame.py -- INPUT.glb OUTPUT_DIR.

DEV-12: fit the measured inner posts to a 2 x 2.6 m aperture, cut that exact aperture through all
decorative geometry with an Exact Boolean, then export three UV-preserving modular frame pieces.
The frame's collision remains the existing Godot primitive frame; no mesh collider is exported.
"""
from pathlib import Path
import json
import sys

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).parent))
import normalize_meshy as n


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:]
    source, output = Path(args[0]), Path(args[1])
    g, blob = n.read_glb(source)
    primitive = g["meshes"][0]["primitives"][0]
    positions = n.accessor(g, blob, primitive["attributes"]["POSITION"]).astype(np.float64)
    normals = n.accessor(g, blob, primitive["attributes"]["NORMAL"]).astype(np.float64)
    uv = n.accessor(g, blob, primitive["attributes"]["TEXCOORD_0"])
    triangles = n.accessor(g, blob, primitive["indices"]).reshape(-1, 3)
    low, high = positions.min(0), positions.max(0)
    # Measured on task 01a1ca00-70cf-7643-b4e2-777d0b90824a, including the rock mounting blocks.
    scale = np.array([1.0 / 0.49, 2.6 / (0.635 - low[1]), 0.4 / (high[2] - low[2])])
    positions *= scale
    positions -= np.array([0, low[1] * scale[1], (low[2] + high[2]) * 0.5 * scale[2]])
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mesh = bpy.data.meshes.new("FrameSource")
    mesh.from_pydata(positions.tolist(), [], triangles.tolist())
    mesh.update()
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        layer.data[loop.index].uv = uv[loop.vertex_index]
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    mesh.normals_split_custom_set_from_vertices(n.scale_normals(normals, scale).tolist())
    frame = bpy.data.objects.new("Frame", mesh)
    bpy.context.collection.objects.link(frame)
    # Leave headroom for the extra triangles introduced by the aperture and modular cuts.
    bpy.context.view_layer.objects.active = frame
    simplify = frame.modifiers.new("FrameBudget", "DECIMATE")
    simplify.ratio = 0.9
    simplify.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=simplify.name)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 1.29, 0))
    cutter = bpy.context.object
    cutter.dimensions = (2.0, 2.62, 2.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.view_layer.objects.active = frame
    modifier = frame.modifiers.new("ClearPassage", "BOOLEAN")
    modifier.operation = "DIFFERENCE"
    modifier.solver = "EXACT"
    modifier.object = cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
    mesh = frame.data
    mesh.calc_loop_triangles()
    uv_layer = mesh.uv_layers.active.data
    rows = []
    for triangle in mesh.loop_triangles:
        rows.append([list(mesh.vertices[mesh.loops[index].vertex_index].co)
                     + list(mesh.corner_normals[index].vector) + list(uv_layer[index].uv)
                     for index in triangle.loops])
    parts = {"LeftPost": [], "RightPost": [], "Lintel": []}
    for triangle in np.array(rows):
        below = n.clip(list(triangle), 1, 2.6, True)
        above = n.clip(list(triangle), 1, 2.6, False)
        if len(above) >= 3:
            parts["Lintel"].extend(n.fan(above))
        if len(below) >= 3:
            for name, keep_below in (("LeftPost", True), ("RightPost", False)):
                polygon = n.clip(below, 0, 0.0, keep_below)
                if len(polygon) >= 3:
                    parts[name].extend(n.fan(polygon))
    pivots = {"LeftPost": [-1.15, 0, 0], "RightPost": [1.15, 0, 0], "Lintel": [0, 2.6, 0]}
    for name, triangles in parts.items():
        soup = np.array(triangles)
        cross = np.cross(soup[:, 1, :3] - soup[:, 0, :3], soup[:, 2, :3] - soup[:, 0, :3])
        soup = soup[np.linalg.norm(cross, axis=1) > 1e-10]
        soup[:, :, :3] -= np.array(pivots[name])
        # Validate after the actual Float32 export quantisation too: tiny Boolean slivers can collapse.
        soup = soup.astype(np.float32)
        cross = np.cross(soup[:, 1, :3] - soup[:, 0, :3], soup[:, 2, :3] - soup[:, 0, :3])
        soup = soup[np.linalg.norm(cross, axis=1) > 1e-9]
        normals = soup[:, :, 3:6]
        length = np.linalg.norm(normals, axis=2, keepdims=True)
        face_normals = np.cross(soup[:, 1, :3] - soup[:, 0, :3], soup[:, 2, :3] - soup[:, 0, :3])
        face_normals /= np.linalg.norm(face_normals, axis=1, keepdims=True)
        # Opposing interpolated normals can cancel at a Boolean cut corner; use its geometric normal.
        normals[:] = np.where(length < 1e-7, face_normals[:, None, :], normals / np.maximum(length, 1e-12))
        parts[name] = soup
        print(name, "triangles", len(soup))
    output.mkdir(parents=True, exist_ok=True)
    material = g["materials"][primitive["material"]]
    sources = {"base_color": material["pbrMetallicRoughness"]["baseColorTexture"]["index"],
               "metallic_roughness": material["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"],
               "normal": material["normalTexture"]["index"]}
    textures = {}
    for role, texture in sources.items():
        image = g["images"][g["textures"][texture]["source"]]
        extension = {"image/png": "png", "image/jpeg": "jpg"}[image["mimeType"]]
        filename = f"door_frame_{role}.{extension}"
        (output / filename).write_bytes(n.image_bytes(g, blob, texture))
        textures[role] = filename
    document, binary = n.build_gltf("door_frame", parts, g, textures)
    for node in document["nodes"]:
        node["translation"] = pivots[node["name"]]
    document["asset"]["generator"] = "tools/art/normalize_door_frame.py (Blender Exact Boolean)"
    (output / "door_frame.gltf").write_text(json.dumps(document, indent=1) + "\n")
    (output / "door_frame.bin").write_bytes(binary)
    # An editable source of the actual repaired geometry, outside the vendored runtime files.
    bpy.ops.wm.save_as_mainfile(filepath=str(source.parent / "frame-repaired.blend"))


if __name__ == "__main__":
    main()
