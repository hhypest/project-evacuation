"""Bake the two ambientCG materials from the original 1K PNG downloads."""
import argparse
from hashlib import sha256
from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2] / "content/textures"
BASALT = ROOT / "alien/basalt_wall"
OUTPUT = ROOT / "ambientcg"
ARCHIVES = {
    "Concrete030": "6cd98c7ba856a10a1cb4000c7ebe7da6fef0e8a3aef55c21121067f7cbd1a2f6",
    "Metal027": "e4fde0890f0a19dadfc9183ec90151028ef6b27b78fbea06964df19ccf76fc8b",
}


def upstream(path: Path, asset: str, maps: dict[str, str]) -> dict[str, Image.Image]:
    data = path.read_bytes()
    if sha256(data).hexdigest() != ARCHIVES[asset]:
        raise ValueError(f"{asset}: expected the original 1K PNG archive")
    with ZipFile(BytesIO(data)) as archive:
        return {
            name: Image.open(BytesIO(archive.read(f"{asset}_1K-PNG_{name}.png"))).convert(mode)
            for name, mode in maps.items()
        }


def save(name: str, image: Image.Image) -> None:
    image.save(OUTPUT / f"{name}.png", optimize=True)


def bake_basalt(path: Path) -> None:
    detail = upstream(path, "Concrete030", {"NormalGL": "RGB", "Roughness": "L"})
    base_normal = np.asarray(Image.open(BASALT / "basalt_wall_normal.png"), dtype=np.float32) / 127.5 - 1.0
    detail_normal = np.asarray(detail["NormalGL"], dtype=np.float32) / 127.5 - 1.0
    # Add a shallow perturbation while keeping the normal direction at the authored seams.
    base_normal[:, :, :2] += detail_normal[:, :, :2] * base_normal[:, :, 2:] * 0.28
    base_normal /= np.linalg.norm(base_normal, axis=2, keepdims=True)
    encoded = (base_normal + 1.0) * 127.5
    save("concrete030_basalt_normal", Image.fromarray(np.clip(np.rint(encoded), 0, 255).astype(np.uint8)))
    ao, roughness, metallic = Image.open(BASALT / "basalt_wall_orm.png").convert("RGB").split()
    save("concrete030_basalt_orm", Image.merge("RGB", (ao, Image.blend(roughness, detail["Roughness"], 0.3), metallic)))


def bake_steel(path: Path) -> None:
    maps = upstream(path, "Metal027", {"Color": "RGB", "NormalGL": "RGB", "Roughness": "L"})
    gray = maps["Color"].convert("L").point(lambda level: min(255, level + 16))
    save("metal027_powder_albedo", Image.blend(maps["Color"], gray.convert("RGB"), 0.72))
    save("metal027_powder_normal", maps["NormalGL"])
    white = Image.new("L", gray.size, 255)
    black = Image.new("L", gray.size, 0)
    # The visible powder coat is dielectric, even though the substrate is steel.
    save("metal027_powder_orm", Image.merge("RGB", (white, maps["Roughness"], black)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("concrete_zip", type=Path)
    parser.add_argument("metal_zip", type=Path)
    args = parser.parse_args()
    OUTPUT.mkdir(exist_ok=True)
    bake_basalt(args.concrete_zip)
    bake_steel(args.metal_zip)
