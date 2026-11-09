"""Turns a raw Meshy GLB into a game-ready glTF: exact game size, pivot, and (for the floor button) a
separate moving plate. Textures are written next to the .gltf as their original JPEG bytes, so Godot
imports them once as ordinary textures instead of duplicating them inside a .glb.

Usage:
    python tools/art/normalize_meshy.py cube   <raw.glb> content/models/devices/ballast_cube
    python tools/art/normalize_meshy.py button <raw.glb> content/models/devices/floor_button

cube   — centred on the origin and scaled per axis to exactly 1 x 1 x 1 m (the 1 m BoxShape3D of a
         carry cube); ChamberBuilder scales it for other edges.
button — bottom at y = 0, plate top at y = 0.1 m, plate edge at ±0.7 m (the 1.4 x 0.1 x 1.4 m plate
         collision of FloorButtonDevice). The upper surfaces inside the plate edge are clipped out into
         a node "Plate", everything else stays in "Frame".
wall_button_body / wall_switch_body — scaled per axis to the housing size of WallButtonDevice, front
         towards +Z, back face at z = -0.08 m (the back of its 0.36 x 0.5 x 0.16 m collision box).
wall_button_key — the push key turned to face +Z, 0.1 m wide (it fits the housing recess), its back at z = 0.
wall_switch_lever — the lever turned so the arm points up (+Y) from its pivot hub; the hub centre is
         the origin and the axle runs along Z, so the device turns it about Z.
logic_box — the junction box housing of LogicDevice, centred, lid towards +Z.
emitter_body / receiver_body — scaled per axis to the EmitterDevice housing (lens towards -Z) and the
         ReceiverDevice plate (dish towards +Z), centred on the node.

The raw GLBs are not in the repository; their Meshy task IDs are listed in content/models/README.md.
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

import numpy as np

FLOAT, UINT32 = 5126, 5125

# Floor button: measured on the raw model (Meshy units, model ±0.95 wide, bottom at -0.10).
PLATE_EDGE_RAW = 0.80  # rusty rim of the diamond plate in the texture
PLATE_EDGE_GAME = 0.70
PLATE_TOP_GAME = 0.10


# Wall devices (game metres; WallButtonDevice collision box is 0.36 x 0.5 x 0.16 m centred on the node).
FITS: dict[str, dict] = {
    "wall_button_body": {"node": "Body", "size": (0.34, 0.56, 0.18), "origin": "back", "back": -0.08, "lift": 0.02},
    "wall_switch_body": {"node": "Body", "size": (0.32, 0.5, 0.12), "origin": "back", "back": -0.08},
    "wall_button_key": {"node": "Key", "rotate": (-90.0, 0.0, 0.0), "uniform": (0, 0.1), "origin": "back", "back": 0.0},
    "wall_switch_lever": {"node": "Lever", "uniform": (1, 0.22), "origin": "hub"},
    # Optics: EmitterDevice housing 0.5 x 0.5 x 0.7 m firing along -Z; ReceiverDevice plate 0.6 x 0.6 x 0.25 m
    # facing +Z. "shift" moves the model so its lens or dish sits on the device axis.
    "emitter_body": {"node": "Body", "rotate": (0.0, -90.0, 0.0), "size": (0.5, 0.5, 0.7), "origin": "center", "shift": (0.037, -0.08, 0.0)},
    "receiver_body": {"node": "Body", "size": (0.6, 0.6, 0.25), "origin": "center", "shift": (0.0, 0.02, 0.0)},
    # LogicDevice: one housing for every kind, 0.44 x 0.44 x 0.16 m centred on the node, lid towards +Z.
    "logic_box": {"node": "Body", "size": (0.44, 0.44, 0.16), "origin": "center"},
}


def rotation_matrix(degrees: tuple[float, float, float]) -> np.ndarray:
    x, y, z = np.radians(degrees)
    rx = np.array([[1, 0, 0], [0, np.cos(x), -np.sin(x)], [0, np.sin(x), np.cos(x)]])
    ry = np.array([[np.cos(y), 0, np.sin(y)], [0, 1, 0], [-np.sin(y), 0, np.cos(y)]])
    rz = np.array([[np.cos(z), -np.sin(z), 0], [np.sin(z), np.cos(z), 0], [0, 0, 1]])
    return rz @ ry @ rx


def lever_frame(position: np.ndarray, normal: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Puts the pivot hub at the origin and the arm along +Y. The raw lever lies along its longest axis;
    the hub is the end whose cross-section is widest, its axle the hub's thinnest direction."""
    long_axis = int(np.argmax(position.max(axis=0) - position.min(axis=0)))
    low, high = position[:, long_axis].min(), position[:, long_axis].max()
    span = high - low
    def end(near_high: bool) -> np.ndarray:
        mask = position[:, long_axis] > high - span * 0.15 if near_high else position[:, long_axis] < low + span * 0.15
        return position[mask]
    ends = [end(False), end(True)]
    others = [axis for axis in range(3) if axis != long_axis]
    widths = [np.ptp(e[:, others], axis=0).sum() for e in ends]
    hub_index = int(np.argmax(widths))
    hub = ends[hub_index]
    grip_sign = -1.0 if hub_index == 1 else 1.0
    hub_extent = np.ptp(hub, axis=0)
    axle = others[int(np.argmin(hub_extent[others]))]
    third = [axis for axis in others if axis != axle][0]
    centre = (hub.min(axis=0) + hub.max(axis=0)) * 0.5
    # New basis: X = third axis, Y = towards the grip along the long axis, Z = axle.
    basis = np.zeros((3, 3))
    basis[0, third] = 1.0
    basis[1, long_axis] = grip_sign
    basis[2, axle] = 1.0
    if np.linalg.det(basis) < 0:
        basis[0] *= -1.0
    return (position - centre) @ basis.T, normal @ basis.T


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    offset, chunks = 12, []
    while offset < len(data):
        length, _kind = struct.unpack("<II", data[offset:offset + 8])
        chunks.append(data[offset + 8:offset + 8 + length])
        offset += 8 + length
    return json.loads(chunks[0]), chunks[1]


def accessor(gltf: dict, blob: bytes, index: int) -> np.ndarray:
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    dtype = {FLOAT: np.float32, UINT32: np.uint32, 5123: np.uint16}[acc["componentType"]]
    width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3}[acc["type"]]
    count = acc["count"] * width
    array = np.frombuffer(blob[start:start + count * np.dtype(dtype).itemsize], dtype=dtype)
    return array.reshape(-1, width) if width > 1 else array


def image_bytes(gltf: dict, blob: bytes, texture: int) -> bytes:
    image = gltf["images"][gltf["textures"][texture]["source"]]
    view = gltf["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    return blob[start:start + view["byteLength"]]


def scale_normals(normals: np.ndarray, scale: np.ndarray) -> np.ndarray:
    scaled = normals / scale
    return scaled / np.maximum(np.linalg.norm(scaled, axis=1, keepdims=True), 1e-12)


def clip(polygon: list[np.ndarray], axis: int, limit: float, keep_below: bool) -> list[np.ndarray]:
    """Sutherland–Hodgman against one axis-aligned plane. A vertex row is [x y z nx ny nz u v]."""
    result: list[np.ndarray] = []
    for index, current in enumerate(polygon):
        previous = polygon[index - 1]
        inside_current = current[axis] <= limit if keep_below else current[axis] >= limit
        inside_previous = previous[axis] <= limit if keep_below else previous[axis] >= limit
        if inside_current != inside_previous:
            t = (limit - previous[axis]) / (current[axis] - previous[axis])
            result.append(previous + (current - previous) * t)
        if inside_current:
            result.append(current)
    return result


def fan(polygon: list[np.ndarray]) -> list[np.ndarray]:
    return [np.array([polygon[0], polygon[i], polygon[i + 1]]) for i in range(1, len(polygon) - 1)]


def split_plate(vertices: np.ndarray, triangles: np.ndarray, top: float) -> tuple[np.ndarray, np.ndarray]:
    """Returns (frame, plate) triangle soups. Upper triangles are cut along the square plate edge."""
    frame, plate = [], []
    upper = vertices[triangles][:, :, 1].min(axis=1) > top - 0.025
    for triangle, is_upper in zip(vertices[triangles], upper):
        if not is_upper:
            frame.append(triangle)
            continue
        rest = list(triangle)
        for axis, limit, below in ((0, PLATE_EDGE_RAW, False), (0, -PLATE_EDGE_RAW, True),
                                   (2, PLATE_EDGE_RAW, False), (2, -PLATE_EDGE_RAW, True)):
            outside = clip(rest, axis, limit, below)
            frame.extend(fan(outside) if len(outside) >= 3 else [])
            rest = clip(rest, axis, limit, not below)
            if len(rest) < 3:
                break
        if len(rest) >= 3:
            plate.extend(fan(rest))
    return np.array(frame), np.array(plate)


def build_gltf(name: str, parts: dict[str, np.ndarray], gltf_in: dict, textures: dict[str, str]) -> tuple[dict, bytes]:
    blob = bytearray()
    views, accessors, meshes, nodes = [], [], [], []

    def add(array: np.ndarray, kind: str, target: int, component: int, bounds: bool = False) -> int:
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": array.nbytes, "target": target})
        blob.extend(array.tobytes())
        entry = {"bufferView": len(views) - 1, "componentType": component, "count": len(array), "type": kind}
        if bounds:
            entry["min"] = array.min(axis=0).tolist()
            entry["max"] = array.max(axis=0).tolist()
        accessors.append(entry)
        return len(accessors) - 1

    for part, soup in parts.items():
        rows = soup.reshape(-1, 8).astype(np.float32)
        flat, inverse = np.unique(rows, axis=0, return_inverse=True)
        position = add(np.ascontiguousarray(flat[:, 0:3]), "VEC3", 34962, FLOAT, True)
        normal = add(np.ascontiguousarray(flat[:, 3:6]), "VEC3", 34962, FLOAT)
        uv = add(np.ascontiguousarray(flat[:, 6:8]), "VEC2", 34962, FLOAT)
        indices = add(inverse.reshape(-1).astype(np.uint32), "SCALAR", 34963, UINT32)
        meshes.append({"name": part, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal,
            "TEXCOORD_0": uv}, "indices": indices, "material": 0}]})
        nodes.append({"name": part, "mesh": len(meshes) - 1})

    images = [{"uri": uri} for uri in textures.values()]
    texture_index = {key: i for i, key in enumerate(textures)}
    material = {"name": name, "pbrMetallicRoughness": {"baseColorTexture": {"index": texture_index["base_color"]},
        "metallicRoughnessTexture": {"index": texture_index["metallic_roughness"]},
        "metallicFactor": 1.0, "roughnessFactor": 1.0},
        "normalTexture": {"index": texture_index["normal"]}, "doubleSided": True}
    sampler = gltf_in.get("samplers", [{}])[0]
    return {
        "asset": {"version": "2.0", "generator": "tools/art/normalize_meshy.py"},
        "scene": 0, "scenes": [{"name": name, "nodes": list(range(len(nodes)))}],
        "nodes": nodes, "meshes": meshes, "materials": [material],
        "samplers": [sampler], "images": images,
        "textures": [{"sampler": 0, "source": i} for i in range(len(images))],
        "buffers": [{"uri": f"{name}.bin", "byteLength": len(blob)}],
        "bufferViews": views, "accessors": accessors,
    }, bytes(blob)


def main() -> None:
    mode, source, out_dir = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    gltf, blob = read_glb(source)
    primitive = gltf["meshes"][0]["primitives"][0]
    position = accessor(gltf, blob, primitive["attributes"]["POSITION"]).astype(np.float64)
    normal = accessor(gltf, blob, primitive["attributes"]["NORMAL"]).astype(np.float64)
    uv = accessor(gltf, blob, primitive["attributes"]["TEXCOORD_0"]).astype(np.float64)
    triangles = accessor(gltf, blob, primitive["indices"]).reshape(-1, 3)
    low, high = position.min(axis=0), position.max(axis=0)

    if mode == "cube":
        name = "ballast_cube"
        scale = 1.0 / (high - low)
        offset = -(low + high) * 0.5
        vertices = np.hstack([(position + offset) * scale, scale_normals(normal, scale), uv])
        parts = {"Cube": vertices[triangles]}
    elif mode == "button":
        name = "floor_button"
        centre = np.array([(low[0] + high[0]) * 0.5, 0.0, (low[2] + high[2]) * 0.5])
        position = position - centre
        raw = np.hstack([position, normal, uv])
        faces = position[triangles]
        up = np.cross(faces[:, 1] - faces[:, 0], faces[:, 2] - faces[:, 0])
        up_facing = up[:, 1] / np.maximum(np.linalg.norm(up, axis=1), 1e-12) > 0.9
        middle = np.abs(faces[:, :, [0, 2]]).max(axis=(1, 2)) < PLATE_EDGE_RAW * 0.7
        top = float(np.median(faces[up_facing & middle][:, :, 1]))
        frame, plate = split_plate(raw, triangles, top)
        scale = np.array([PLATE_EDGE_GAME / PLATE_EDGE_RAW, PLATE_TOP_GAME / (top - low[1]), PLATE_EDGE_GAME / PLATE_EDGE_RAW])
        parts = {}
        for part, soup in (("Frame", frame), ("Plate", plate)):
            flat = soup.reshape(-1, 8)
            flat[:, 0:3] = (flat[:, 0:3] - [0.0, low[1], 0.0]) * scale
            flat[:, 3:6] = scale_normals(flat[:, 3:6], scale)
            parts[part] = flat.reshape(-1, 3, 8)
        print(f"plate top {top:.4f} raw, frame {len(frame)} tris, plate {len(plate)} tris, scale {scale.round(4).tolist()}")
    elif mode in FITS:
        name = mode
        fit = FITS[mode]
        rotation = rotation_matrix(fit.get("rotate", (0.0, 0.0, 0.0)))
        position = position @ rotation.T
        normal = normal @ rotation.T
        if mode == "wall_switch_lever":
            position, normal = lever_frame(position, normal)
        low, high = position.min(axis=0), position.max(axis=0)
        if "size" in fit:
            scale = np.array(fit["size"]) / (high - low)
        else:
            axis, length = fit["uniform"]
            scale = np.full(3, length / (high - low)[axis])
        position = position * scale
        normal = scale_normals(normal, scale)
        low, high = position.min(axis=0), position.max(axis=0)
        centre = (low + high) * 0.5
        if fit["origin"] == "back":
            offset = np.array([-centre[0], -centre[1] + fit.get("lift", 0.0), fit["back"] - low[2]])
        elif fit["origin"] == "center":
            offset = -centre + np.array(fit.get("shift", (0.0, 0.0, 0.0)))
        else:  # "hub": lever_frame already put the hub at the origin
            offset = np.zeros(3)
        vertices = np.hstack([position + offset, normal, uv])
        parts = {fit["node"]: vertices[triangles]}
    else:
        raise SystemExit(f"unknown mode {mode}")

    out_dir.mkdir(parents=True, exist_ok=True)
    material = gltf["materials"][primitive["material"]]
    sources = {"base_color": material["pbrMetallicRoughness"]["baseColorTexture"]["index"],
               "metallic_roughness": material["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"],
               "normal": material["normalTexture"]["index"]}
    textures = {}
    for key, texture in sources.items():
        file_name = f"{name}_{key}.jpg"
        (out_dir / file_name).write_bytes(image_bytes(gltf, blob, texture))
        textures[key] = file_name
    document, binary = build_gltf(name, parts, gltf, textures)
    (out_dir / f"{name}.bin").write_bytes(binary)
    (out_dir / f"{name}.gltf").write_text(json.dumps(document, indent=1), encoding="utf-8")
    for part, soup in parts.items():
        flat = soup.reshape(-1, 8)
        print(f"{part}: {len(soup)} tris, min {flat[:, 0:3].min(axis=0).round(4).tolist()}, max {flat[:, 0:3].max(axis=0).round(4).tolist()}")


if __name__ == "__main__":
    main()
