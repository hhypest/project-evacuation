"""Add ambientCG finishes to existing device atlases and bake the terminal faceplate."""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from bake_ambientcg_materials import ARCHIVES, OUTPUT, ROOT, blend_normal, save, upstream
from bake_expedition_materials import panel_orm

MODELS = ROOT.parent / "models/devices"
ARCHIVES.update({
    "Metal028": "582963a48e2479660dc006cd59103be10db13e97f5ee36884c44c0e288dfa7b7",
    "Metal009": "ec44086a3bee042418ac2b38a74c8cedfa8313d942bf08c1c91be4ef63c8a97f",
    "Rubber004": "73b8a1e4655bd4b6bb29492ca158e5ca43da52a2fc4e2b46eaacafbd96d17901",
    "Plastic010": "2afcc89230a2e40773ad344ef3b21a57249e4d9af4707b50ad30241371eddd93",
})


def plate_mask(model_path: Path, size: tuple[int, int]) -> Image.Image:
    """Mark the moving plate's upward faces in the existing DEV-02 atlas."""
    model = json.loads(model_path.read_text(encoding="utf-8"))
    binary = model_path.with_suffix(".bin").read_bytes()
    meshes = {mesh["name"]: mesh["primitives"][0] for mesh in model["meshes"]}
    plate = meshes["Plate"]

    def read(index: int, width: int, dtype: str) -> np.ndarray:
        accessor = model["accessors"][index]
        view = model["bufferViews"][accessor["bufferView"]]
        offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        return np.frombuffer(binary, dtype, accessor["count"] * width, offset).reshape(-1, width)

    attributes = plate["attributes"]
    uv = read(attributes["TEXCOORD_0"], 2, "<f4")
    normals = read(attributes["NORMAL"], 3, "<f4")
    indexes = model["accessors"][plate["indices"]]
    index_type = {5123: "<u2", 5125: "<u4"}[indexes["componentType"]]
    faces = read(plate["indices"], 1, index_type).reshape(-1, 3)
    mask = Image.new("L", size)
    draw = ImageDraw.Draw(mask)
    for face in faces[normals[faces, 1].mean(axis=1) > 0.55]:
        draw.polygon([tuple(p) for p in uv[face] * np.array(size)], fill=255)
    return mask.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.GaussianBlur(2))


def tile(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    result = Image.new(image.mode, size)
    for y in range(0, size[1], image.height):
        for x in range(0, size[0], image.width):
            result.paste(image, (x, y))
    return result


def blend_surface(base: Image.Image, detail: Image.Image, weight: float) -> Image.Image:
    return Image.blend(base, tile(detail, base.size), weight)


def bake_atlas(
    stem: Path,
    finish: dict[str, Image.Image],
    name: str,
    rubber: dict[str, Image.Image] | None = None,
    steel: dict[str, Image.Image] | None = None,
) -> None:
    normal_path = next(stem.parent.glob(f"{stem.name}_normal.*g"))
    with Image.open(normal_path) as image:
        normals = image.convert("RGB").resize((2048, 2048), Image.Resampling.LANCZOS)
    source_mr = Image.open(stem.with_name(f"{stem.name}_metallic_roughness.jpg")).convert("RGB")
    ao, roughness, metallic = source_mr.split()
    # Use the existing metal mask to keep exposed edges and bolts out of the painted finish.
    paint_mask = metallic.point(lambda v: round(255 * (1 - min(1.0, v / 115))))
    detail = tile(finish["NormalGL"], normals.size)
    paint_strength = np.asarray(paint_mask.resize(normals.size, Image.Resampling.BILINEAR), dtype=np.float32) / 255
    normal = blend_normal(np.asarray(normals), np.asarray(detail), (0.68 * paint_strength)[..., None])
    rough = Image.composite(blend_surface(roughness, finish["Roughness"], 0.52), roughness, paint_mask)

    if rubber is not None:
        mask = plate_mask(stem.with_suffix(".gltf"), normals.size)
        normal = Image.composite(
            blend_normal(np.asarray(normals), np.asarray(tile(rubber["NormalGL"], normals.size)), 0.55),
            normal, mask,
        )
        mr_mask = mask.resize(roughness.size, Image.Resampling.BILINEAR)
        rough = Image.composite(blend_surface(roughness, rubber["Roughness"], 0.78), rough, mr_mask)
        metallic = Image.composite(Image.new("L", metallic.size), metallic, mr_mask)
        color = Image.open(stem.with_name(f"{stem.name}_base_color.jpg")).convert("RGB")
        color = color.resize(normals.size, Image.Resampling.LANCZOS)
        grip = rubber["Color"].convert("L").point(lambda v: 33 + round(v * 0.72)).convert("RGB")
        rubber_color = blend_surface(color, grip, 0.82)
        Image.composite(rubber_color, color, mask).save(
            OUTPUT / f"{name}_albedo.jpg", quality=94, subsampling=0, optimize=True,
        )
    if steel is not None:
        exposed = metallic.point(lambda v: max(0, round((v - 100) * 255 / 155)))
        rough = Image.composite(blend_surface(rough, steel["Roughness"], 0.55), rough, exposed)
        exposed = exposed.resize(normals.size, Image.Resampling.BILINEAR)
        brushed = blend_normal(np.asarray(normals), np.asarray(tile(steel["NormalGL"], normals.size)), 0.52)
        normal = Image.composite(brushed, normal, exposed)
    save(f"{name}_normal", normal)
    save(f"{name}_orm", Image.merge("RGB", (ao, rough, metallic)))


def bake_panel(powder: dict[str, Image.Image]) -> None:
    normal = np.asarray(Image.open(ROOT / "surfaces/panel_light/panel_light_normal.png"))
    ao, roughness, metallic = panel_orm().split()
    save("metal028_panel_normal", blend_normal(normal, np.asarray(powder["NormalGL"]), 0.65))
    save("metal028_panel_orm", Image.merge("RGB", (ao, blend_surface(roughness, powder["Roughness"], 0.46), metallic)))


def bake_inset(name: str, maps: dict[str, Image.Image], metallic: int) -> None:
    save(f"{name}_normal", maps["NormalGL"])
    roughness = maps["Roughness"]
    save(f"{name}_orm", Image.merge("RGB", (Image.new("L", roughness.size, 255), roughness,
                                            Image.new("L", roughness.size, metallic))))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archives", type=Path, help="Directory with the four named 1K PNG ZIP files")
    source = parser.parse_args().archives
    OUTPUT.mkdir(exist_ok=True)
    channels = {"NormalGL": "RGB", "Roughness": "L"}
    powder = upstream(source / "Metal028_1K-PNG.zip", "Metal028", channels)
    rubber = upstream(source / "Rubber004_1K-PNG.zip", "Rubber004", {**channels, "Color": "RGB"})
    steel = upstream(source / "Metal009_1K-PNG.zip", "Metal009", channels)
    bake_atlas(MODELS / "ballast_cube/ballast_cube", powder, "ballast_powder")
    bake_atlas(MODELS / "floor_button/floor_button", powder, "floor_button_grip", rubber, steel)
    bake_atlas(MODELS / "wall_button/wall_button_body", powder, "wall_button_powder")
    bake_panel(powder)
    bake_inset("metal009_bezel", steel, 255)
    bake_inset("plastic010_faceplate", upstream(source / "Plastic010_1K-PNG.zip", "Plastic010", channels), 0)
