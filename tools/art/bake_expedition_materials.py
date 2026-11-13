"""Bake the DEV-01 markings and three surface derivatives from tracked source art."""
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
ATLAS = ROOT / "content/models/devices/ballast_cube"
TEXTURES = ROOT / "content/textures"
EXPEDITION = TEXTURES / "expedition"
DIGITS = {
    "0": ("111", "101", "101", "101", "111"),
    "1": ("010", "110", "010", "010", "111"),
    "5": ("111", "100", "111", "001", "111"),
}


def stamp(heavy: bool) -> np.ndarray:
    """One service stencil projected on each upright side, in model metres."""
    image = Image.new("L", (512, 512))
    draw = ImageDraw.Draw(image)
    digit_width = 28
    text = "10" if heavy else "5"
    left = 256 - (len(text) * (digit_width + 7) - 7) // 2 + 20
    for digit in text:
        for row, cells in enumerate(DIGITS[digit]):
            for col, pixel in enumerate(cells):
                if pixel == "1":
                    x, y = left + col * 9, 233 + row * 9
                    draw.rectangle((x, y, x + 8, y + 8), fill=255)
        left += digit_width + 7
    # Weight-class chevrons also identify the shells from an oblique angle.
    for index in range(1 + int(heavy)):
        x = 171 + index * 12
        draw.polygon([(x, 239), (x + 6, 239), (x - 3, 271), (x - 9, 271)], fill=150)
    return np.asarray(image)


def read_mesh() -> tuple[np.ndarray, ...]:
    model = json.loads((ATLAS / "ballast_cube.gltf").read_text())
    binary = (ATLAS / model["buffers"][0]["uri"]).read_bytes()
    primitive = model["meshes"][0]["primitives"][0]
    attributes = primitive["attributes"]

    def read(index: int, width: int, dtype: str) -> np.ndarray:
        accessor = model["accessors"][index]
        view = model["bufferViews"][accessor["bufferView"]]
        offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
        return np.frombuffer(binary, dtype, accessor["count"] * width, offset).reshape(-1, width)

    return (read(attributes["POSITION"], 3, "<f4"), read(attributes["NORMAL"], 3, "<f4"),
            read(attributes["TEXCOORD_0"], 2, "<f4"), read(primitive["indices"], 1, "<u4").reshape(-1, 3))


def bake_cubes() -> None:
    source = Image.open(ATLAS / "ballast_cube_base_color.jpg").convert("RGB")
    pixels = np.asarray(source)
    positions, normals, uvs, faces = read_mesh()
    width, height = source.size
    masks = np.zeros((2, height, width), dtype=np.uint8)
    band = np.zeros((height, width), dtype=np.uint8)
    stencils = [stamp(False), stamp(True)]
    for face in faces:
        points = positions[face]
        normal = normals[face].mean(axis=0)
        x_face = abs(normal[0]) > abs(normal[2])
        axis = 0 if x_face else 2
        if abs(normal[axis]) < 0.68 or np.abs(points[:, 1]).min() > 0.15:
            continue
        tangent = np.array([0, 0, -normal[0]]) if x_face else np.array([normal[2], 0, 0])
        tangent /= abs(tangent).max()
        corners = uvs[face] * np.array([width, height])
        low = np.maximum(np.floor(corners.min(axis=0)).astype(int), 0)
        high = np.minimum(np.ceil(corners.max(axis=0)).astype(int), [width, height])
        xs, ys = np.meshgrid(np.arange(low[0], high[0]) + .5, np.arange(low[1], high[1]) + .5)
        base, first, second = corners
        a, b = first - base, second - base
        determinant = a[0] * b[1] - a[1] * b[0]
        if abs(determinant) < 0.00001:
            continue
        u = ((xs - base[0]) * b[1] - (ys - base[1]) * b[0]) / determinant
        v = (a[0] * (ys - base[1]) - a[1] * (xs - base[0])) / determinant
        inside = (u >= 0) & (v >= 0) & (u + v <= 1)
        y, x = np.nonzero(inside)
        if not x.size:
            continue
        world = points[0] + u[inside, None] * (points[1] - points[0]) + v[inside, None] * (points[2] - points[0])
        h = world[:, 1]
        lateral = world @ tangent
        atlas_x, atlas_y = x + low[0], y + low[1]
        skirt = np.interp(np.abs(h + .003), [0, .106, .126, .139], [228, 228, 150, 0])
        band[atlas_y, atlas_x] = skirt
        forward = np.abs(world[:, axis]) > .345
        sx = ((lateral + .5) * 512).astype(int).clip(0, 511)
        sy = ((.5 - h) * 512).astype(int).clip(0, 511)
        for mask, stencil in zip(masks, stencils, strict=True):
            mask[atlas_y, atlas_x] = stencil[sy, sx] * forward

    # Pad the UV islands through the first few mip levels. Preserve the source paint variation.
    def pad(mask: np.ndarray) -> np.ndarray:
        return np.asarray(Image.fromarray(mask).filter(ImageFilter.MaxFilter(3)), dtype=np.float32) / 255.0

    for heavy in (False, True):
        paint = pixels.astype(np.float32) * np.array([1.018, 1.008, 0.985], dtype=np.float32)
        if heavy:
            weight = pad(band)[..., None]
            graphite = paint * .31 + np.array([19, 20, 21], dtype=np.float32)
            paint += (graphite - paint) * weight
        stencil = masks[int(heavy)]
        ticks = pad(np.where(stencil == 150, 230, 0).astype(np.uint8))[..., None]
        numbers = pad(np.where(stencil == 255, 245, 0).astype(np.uint8))[..., None]
        paint += (np.array([226, 131, 49], dtype=np.float32) - paint) * ticks
        ink = [232, 228, 216] if heavy else [43, 46, 43]
        paint += (np.array(ink, dtype=np.float32) - paint) * numbers
        key = "10kg" if heavy else "5kg"
        Image.fromarray(paint.clip(0, 255).astype(np.uint8)).save(
            EXPEDITION / f"ballast_{key}_albedo.jpg", quality=94, subsampling=0, optimize=True)


def bake_surfaces() -> None:
    source_paths = {
        "basalt_reference": TEXTURES / "alien/basalt_wall/basalt_wall",
        "panel_reference": TEXTURES / "surfaces/panel_light/panel_light",
        "portal_enamel": TEXTURES / "surfaces/panel_light/panel_light",
    }
    for key, source in source_paths.items():
        with Image.open(source.with_name(source.name + "_albedo.png")) as image:
            rgb = np.asarray(image, dtype=np.float32)
        with Image.open(source.with_name(source.name + "_orm.png")) as image:
            orm = np.array(image)
        if key == "basalt_reference":
            rgb = rgb * np.array([.81, .86, .91]) + np.array([2, 2, 2])
            orm[:, :, 1] = np.minimum(255, orm[:, :, 1].astype(int) + 15)
        else:
            # Existing weathering carries through the new enamel. Mix in the source cavity mask.
            wear = np.clip((255.0 - orm[:, :, 0]) * .0028, 0, .26)[..., None]
            enamel = np.array([199, 194, 180] if key == "panel_reference" else [211, 199, 177])
            rgb = rgb * .70 + enamel * .30
            rgb *= 1.0 - wear
            orm[:, :, 1] = np.maximum(150, orm[:, :, 1])
            orm[:, :, 2] = np.minimum(65, orm[:, :, 2])
        Image.fromarray(rgb.clip(0, 255).astype(np.uint8)).save(EXPEDITION / f"{key}_albedo.png")
        Image.fromarray(orm).save(EXPEDITION / f"{key}_orm.png")


if __name__ == "__main__":
    EXPEDITION.mkdir(parents=True, exist_ok=True)
    bake_surfaces()
    bake_cubes()
