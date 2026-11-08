#!/usr/bin/env python3
"""Процедурные модели устройств Abandoned (Blender как Python-модуль, bpy 5.2 LTS).

Модели строятся кодом: булевы операции, фаски, UV-проекция по осям под уже готовые
процедурные текстуры (tools/art/generate_device_textures.py). Габариты — игровые:
модель не меняет проверенные коллизии, она их одевает.

Материалы называются «<группа>__<ассет>» и в Godot сопоставляются с
content/materials/<группа>/<ассет>.tres (tools/art/build_device_models.gd).

Запуск из корня репозитория:
  python tools/art/models/build_device_models.py --out content/models/devices
Зависимость инструмента: pip install bpy (Python 3.13; Blender 5.2 LTS).
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

import bpy  # noqa: I001 — bpy должен импортироваться первым: он регистрирует bmesh и mathutils
import bmesh
from mathutils import Vector

MODELS_VERSION = 1


# --------------------------------------------------------------------------- сцена и утилиты

def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"


def material(name: str) -> bpy.types.Material:
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    return mat


def box(name: str, size: tuple[float, float, float], location: tuple[float, float, float]) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
    return obj


def cylinder(name: str, radius: float, depth: float, location: tuple[float, float, float],
             rotation: tuple[float, float, float] = (0.0, 0.0, 0.0), vertices: int = 48) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def rounded_slot(name: str, length: float, width: float, depth: float, location: tuple[float, float, float],
                 axis: str) -> bpy.types.Object:
    """Продолговатый паз со скруглёнными торцами; axis — ось глубины ('x', 'y' или 'z')."""
    straight = length - width
    if axis == "z":
        core = box(name, (straight, width, depth), location)
        offsets = [(-straight / 2, 0.0, 0.0), (straight / 2, 0.0, 0.0)]
        rot = (0.0, 0.0, 0.0)
    elif axis == "x":
        core = box(name, (depth, straight, width), location)
        offsets = [(0.0, -straight / 2, 0.0), (0.0, straight / 2, 0.0)]
        rot = (0.0, math.pi / 2, 0.0)
    else:
        core = box(name, (straight, depth, width), location)
        offsets = [(-straight / 2, 0.0, 0.0), (straight / 2, 0.0, 0.0)]
        rot = (math.pi / 2, 0.0, 0.0)
    for i, off in enumerate(offsets):
        cap = cylinder(f"{name}_cap{i}", width / 2, depth, tuple(a + b for a, b in zip(location, off)), rot, 24)
        union(core, cap)
    return core


def boolean(target: bpy.types.Object, cutter: bpy.types.Object, operation: str) -> None:
    mod = target.modifiers.new(name=f"bool_{cutter.name}", type="BOOLEAN")
    mod.operation = operation
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.context.view_layer.objects.active = target
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def difference(target: bpy.types.Object, cutter: bpy.types.Object) -> None:
    boolean(target, cutter, "DIFFERENCE")


def union(target: bpy.types.Object, other: bpy.types.Object) -> None:
    boolean(target, other, "UNION")


def bevel(obj: bpy.types.Object, width: float, segments: int, angle_deg: float = 40.0) -> None:
    mod = obj.modifiers.new(name="bevel", type="BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = math.radians(angle_deg)
    mod.harden_normals = True
    mod.miter_outer = "MITER_ARC"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def finish_shading(obj: bpy.types.Object, angle_deg: float = 35.0) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_auto_smooth(angle=math.radians(angle_deg))
    # «Smooth by Angle» в Blender 5 — модификатор; применяем, чтобы нормали ушли в экспорт.
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def assign(obj: bpy.types.Object, mats: list[bpy.types.Material], chooser) -> None:
    """Назначает материал каждому полигону: chooser(центр, нормаль) -> индекс в mats."""
    obj.data.materials.clear()
    for mat in mats:
        obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = chooser(Vector(poly.center), Vector(poly.normal))


def project_uv(obj: bpy.types.Object, mapper) -> None:
    """UV по полигонам: mapper(точка, нормаль, индекс материала) -> (u, v)."""
    mesh = obj.data
    if not mesh.uv_layers:
        mesh.uv_layers.new(name="UVMap")
    uv = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        n = Vector(poly.normal)
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv[li].uv = mapper(Vector(co), n, poly.material_index)


def dominant_axis(n: Vector) -> tuple[int, float]:
    a = [abs(n.x), abs(n.y), abs(n.z)]
    i = a.index(max(a))
    return i, (1.0 if n[i] >= 0 else -1.0)


def write_minimal_mtl(path: Path, names: list[str]) -> None:
    """MTL нужен Godot только ради имён поверхностей; материалы назначает build_device_models.gd.

    Штатный MTL Blender содержит Ka (ambient), и импортёр Godot печатает на него WARNING,
    который tools/check.ps1 считает провалом. Пишем минимальный файл: имя и Kd.
    """
    lines = ["# Generated by tools/art/models/build_device_models.py; materials are assigned in Godot", ""]
    for name in names:
        lines += [f"newmtl {name}", "Kd 0.800000 0.800000 0.800000", ""]
    path.write_text("\n".join(lines), encoding="utf-8")


def export_obj(obj: bpy.types.Object, path: Path) -> dict[str, object]:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.obj_export(filepath=str(path), export_selected_objects=True, export_uv=True, export_normals=True,
                          export_materials=True, export_triangulated_mesh=True, forward_axis="NEGATIVE_Z",
                          up_axis="Y", apply_modifiers=True, export_pbr_extensions=False, path_mode="STRIP")
    write_minimal_mtl(path.with_suffix(".mtl"), [m.name for m in obj.data.materials])
    mesh = obj.data
    tris = sum(len(p.vertices) - 2 for p in mesh.polygons)
    return {"file": path.name, "triangles": tris, "materials": [m.name for m in mesh.materials]}


# --------------------------------------------------------------------------- куб 0,5 м

CUBE = 0.5
CUBE_TEX = 512.0  # пикселей на грань в cube_face


def px(value: float) -> float:
    """Перевод координаты текстуры грани куба (px от левого края) в метры от центра грани."""
    return (value - CUBE_TEX / 2) / CUBE_TEX * CUBE


def build_cube() -> bpy.types.Object:
    """Утилитарный куб: рамка с фаской, утопленная панель, ступица с линзой, пазы-ручки на всех гранях.
    Размеры элементов совпадают с разметкой cube_face.png."""
    h = CUBE / 2
    cube = box("UtilityCube", (CUBE, CUBE, CUBE), (0.0, 0.0, 0.0))
    bevel(cube, 0.012, 3)
    panel = px(456) - px(56)                # 0,39 м
    hub = px(256 + 76) - px(256 - 76)       # 0,148 м
    lens_r = 48 / CUBE_TEX * CUBE           # 0,047 м
    grip_len = (316 - 196) / CUBE_TEX * CUBE
    grip_w = (134 - 96) / CUBE_TEX * CUBE
    grip_off = abs(px(115))
    recess, grip_depth, lens_depth = 0.010, 0.016, 0.008
    for axis in range(3):
        for sign in (1.0, -1.0):
            def at(depth_center: float, u: float = 0.0, v: float = 0.0) -> tuple[float, float, float]:
                c = [0.0, 0.0, 0.0]
                c[axis] = sign * depth_center
                others = [i for i in range(3) if i != axis]
                c[others[0]] = u
                c[others[1]] = v
                return tuple(c)

            def sized(depth: float, a: float, b: float) -> tuple[float, float, float]:
                s = [a, a, a]
                s[axis] = depth
                others = [i for i in range(3) if i != axis]
                s[others[0]] = a
                s[others[1]] = b
                return tuple(s)

            difference(cube, box("panel_cut", sized(recess * 2, panel, panel), at(h)))
            # ступица на 1 мм ниже плоскости грани: модель не выходит за габарит коллизии 0,5 м
            hub_obj = box("hub", sized(recess, hub, hub), at(h - recess / 2 - 0.001))
            bevel(hub_obj, 0.003, 2)
            union(cube, hub_obj)
            rot = [(0.0, math.pi / 2, 0.0), (math.pi / 2, 0.0, 0.0), (0.0, 0.0, 0.0)][axis]
            difference(cube, cylinder("lens_cut", lens_r, lens_depth * 2, at(h + 0.002), rot))
            # пазы-ручки сверху и снизу панели (в плоскости грани — вторая из свободных осей)
            others = [i for i in range(3) if i != axis]
            slot_axis = "xyz"[axis]
            for vs in (1.0, -1.0):
                loc = [0.0, 0.0, 0.0]
                loc[axis] = sign * (h - recess)
                loc[others[1]] = vs * grip_off
                slot = rounded_slot("grip", grip_len, grip_w, grip_depth * 2, tuple(loc), slot_axis)
                difference(cube, slot)
    bevel(cube, 0.0015, 1, 50.0)
    mats = [material("devices__cube_face")]
    assign(cube, mats, lambda c, n: 0)

    def mapper(co: Vector, n: Vector, _m: int) -> tuple[float, float]:
        i, s = dominant_axis(n)
        if i == 2:
            return ((co.x + h) / CUBE if s > 0 else (h - co.x) / CUBE, (h - co.y) / CUBE)
        if i == 0:
            return ((h - co.y) / CUBE if s > 0 else (co.y + h) / CUBE, (h - co.z) / CUBE)
        return ((co.x + h) / CUBE if s < 0 else (h - co.x) / CUBE, (h - co.z) / CUBE)

    project_uv(cube, mapper)
    finish_shading(cube)
    return cube


# --------------------------------------------------------------------------- напольная кнопка

PLATE_R = 0.45          # радиус плиты, м
PLATE_TEX_R = 496 / 1024  # радиус плиты в долях текстуры floor_button_top
BASE_TOP = 0.08         # верх юбки
PLATE_H = 0.07          # толщина плиты
PLATE_TRAVEL = 0.02     # ход плиты при нажатии: в нажатом положении верх плиты вровень с юбкой
WELL_FLOOR = 0.01       # дно колодца
PLATE_REST = BASE_TOP + 0.02 - PLATE_H  # низ плиты в покое: верх на 2 см выше юбки


def hex_frustum(name: str, r_bottom: float, r_top: float, height: float) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bottom = [bm.verts.new((r_bottom * math.cos(a), r_bottom * math.sin(a), 0.0)) for a in
              [math.radians(30 + 60 * i) for i in range(6)]]
    top = [bm.verts.new((r_top * math.cos(a), r_top * math.sin(a), height)) for a in
           [math.radians(30 + 60 * i) for i in range(6)]]
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    for i in range(6):
        j = (i + 1) % 6
        bm.faces.new([bottom[i], bottom[j], top[j], top[i]])
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def build_floor_button_base() -> bpy.types.Object:
    """Неподвижная гексагональная юбка с колодцем под плиту и гидравлическими упорами."""
    base = hex_frustum("FloorButtonBase", 0.64, 0.56, BASE_TOP)
    bpy.context.view_layer.objects.active = base
    bevel(base, 0.006, 2, 30.0)
    difference(base, cylinder("well", PLATE_R + 0.012, 0.2, (0.0, 0.0, WELL_FLOOR + 0.1), vertices=64))
    for i in range(6):
        a = math.radians(i * 60)
        piston = cylinder("piston", 0.022, PLATE_REST - WELL_FLOOR, (0.36 * math.cos(a), 0.36 * math.sin(a), (PLATE_REST + WELL_FLOOR) / 2), vertices=20)
        union(base, piston)
    mats = [material("surfaces__hazard_stripes"), material("surfaces__metal_dark")]

    def choose(c: Vector, n: Vector) -> int:
        # скаты юбки наклонены на 45°: нормаль между горизонталью и вертикалью, снаружи колодца
        horizontal_r = math.hypot(c.x, c.y)
        sloped_side = 0.2 < n.z < 0.9 and horizontal_r > 0.5
        return 0 if sloped_side else 1

    assign(base, mats, choose)

    def mapper(co: Vector, n: Vector, m: int) -> tuple[float, float]:
        if m == 0:
            # полосы по скату: U — длина по периметру (м), V — высота ската; тайл полос 1 м
            ang = math.atan2(co.y, co.x)
            return (ang / (2 * math.pi) * 6 * 0.6, 0.5 - co.z * 1.4)
        return (co.x + 0.5, co.y + 0.5)

    project_uv(base, mapper)
    finish_shading(base, 30.0)
    return base


def build_floor_button_plate() -> bpy.types.Object:
    """Подвижная плита: верх — floor_button_top (диск с кольцом состояния), борт — тёмный металл.
    Начало координат — низ плиты; в покое низ плиты на PLATE_REST, в нажатом положении — на PLATE_REST - PLATE_TRAVEL."""
    plate = cylinder("FloorButtonPlate", PLATE_R, PLATE_H, (0.0, 0.0, PLATE_H / 2), vertices=72)
    bevel(plate, 0.008, 3, 30.0)
    mats = [material("devices__floor_button_top"), material("surfaces__metal_dark")]
    assign(plate, mats, lambda c, n: 0 if n.z > 0.95 and c.z > PLATE_H - 0.002 else 1)

    def mapper(co: Vector, n: Vector, m: int) -> tuple[float, float]:
        if m == 0:
            return (0.5 + co.x / PLATE_R * PLATE_TEX_R, 0.5 - co.y / PLATE_R * PLATE_TEX_R)
        ang = math.atan2(co.y, co.x)
        return (ang / (2 * math.pi) * 2 * math.pi * PLATE_R, co.z)

    project_uv(plate, mapper)
    finish_shading(plate, 30.0)
    return plate


# --------------------------------------------------------------------------- точка входа

def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default="content/models/devices", type=Path)
    args = ap.parse_args()
    manifest: list[dict[str, object]] = []
    builders = [
        ("utility_cube", build_cube, {"size_m": [CUBE, CUBE, CUBE], "pivot": "центр"}),
        ("floor_button_base", build_floor_button_base, {"pivot": "низ, центр", "top_m": BASE_TOP}),
        ("floor_button_plate", build_floor_button_plate,
         {"pivot": "низ плиты", "rest_offset_m": round(PLATE_REST, 4), "travel_m": PLATE_TRAVEL}),
    ]
    for name, build, meta in builders:
        reset_scene()
        obj = build()
        info = export_obj(obj, args.out / f"{name}.obj")
        info.update({"name": name, **meta})
        manifest.append(info)
        print(f"{name}: {info['triangles']} треугольников, материалы {info['materials']}")
    (args.out / "models_manifest.json").write_text(
        json.dumps({"version": MODELS_VERSION, "models": manifest}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
