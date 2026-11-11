"""Apply a Retexture GLB's PBR images to an existing glTF without touching geometry, pivots or UVs.

Usage: python tools/art/update_meshy_textures.py RETEXTURED.glb EXISTING.gltf
The provider must preserve the original UV layout. The returned mesh and vertex normals are ignored.
"""
from pathlib import Path
import json
import sys

import normalize_meshy as n


def main() -> None:
    source, target = Path(sys.argv[1]), Path(sys.argv[2])
    g, blob = n.read_glb(source)
    primitive = g["meshes"][0]["primitives"][0]
    material = g["materials"][primitive["material"]]
    sources = {"base_color": material["pbrMetallicRoughness"]["baseColorTexture"]["index"],
               "metallic_roughness": material["pbrMetallicRoughness"]["metallicRoughnessTexture"]["index"],
               "normal": material["normalTexture"]["index"]}
    text = target.read_text(encoding="utf-8")
    document = json.loads(text)
    # Validate all destinations before writing any images.
    changes = []
    for role, index in sources.items():
        matches = [image["uri"] for image in document["images"] if f"_{role}." in image.get("uri", "")]
        if len(matches) != 1:
            raise ValueError(f"Expected one {role} image in {target}")
        image = g["images"][g["textures"][index]["source"]]
        extension = {"image/png": "png", "image/jpeg": "jpg"}[image["mimeType"]]
        old = matches[0]
        new = str(Path(old).with_suffix("." + extension))
        changes.append((old, new, n.image_bytes(g, blob, index)))
    for old, new, data in changes:
        (target.parent / new).write_bytes(data)
        if old != new:
            old_meta = target.parent / (old + ".import")
            new_meta = target.parent / (new + ".import")
            if old_meta.exists():
                new_meta.write_text(old_meta.read_text().replace(old, new))
                old_meta.unlink()
            (target.parent / old).unlink(missing_ok=True)
            text = text.replace(old, new)
    target.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
