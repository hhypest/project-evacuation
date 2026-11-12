#!/usr/bin/env python3
"""Read-only source audit for the DEV-01/04 material reference (numpy, Pillow).

Run from the repository root; prints JSON. No retexturing, resampling or source mutation.
"""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


def inspect_model(folder, stem):
    folder = Path('content/models/devices') / folder
    path = folder / (stem + '.gltf')
    model = json.loads(path.read_text())
    buffer = (folder / model['buffers'][0]['uri']).read_bytes()

    def read(index):
        accessor = model['accessors'][index]
        view = model['bufferViews'][accessor['bufferView']]
        dtype = {5126: '<f4', 5125: '<u4', 5123: '<u2'}[accessor['componentType']]
        width = {'VEC2': 2, 'VEC3': 3, 'SCALAR': 1}[accessor['type']]
        offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        return np.frombuffer(buffer, dtype=dtype, count=accessor['count'] * width, offset=offset).reshape(-1, width)

    parts = []
    for mesh in model['meshes']:
        for primitive in mesh['primitives']:
            position = read(primitive['attributes']['POSITION'])
            normals = read(primitive['attributes']['NORMAL'])
            uv = read(primitive['attributes']['TEXCOORD_0'])
            index = read(primitive['indices']).ravel()
            tri, tex = position[index].reshape(-1, 3, 3), uv[index].reshape(-1, 3, 2)
            area = np.linalg.norm(np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]), axis=1) * .5
            du, dv = tex[:, 1] - tex[:, 0], tex[:, 2] - tex[:, 0]
            uv_area = np.abs(du[:, 0] * dv[:, 1] - du[:, 1] * dv[:, 0]) * .5
            valid = (area > 1e-12) & (uv_area > 1e-12)
            density = np.sqrt(uv_area[valid] / area[valid]) * 4096
            lengths = np.linalg.norm(normals, axis=1)
            assert np.isfinite(position).all() and np.isfinite(uv).all() and np.isfinite(normals).all()
            parts.append(dict(name=mesh['name'], triangles=len(tri), geometry_degenerate=int((area <= 1e-12).sum()),
                              uv_degenerate=int((uv_area <= 1e-12).sum()),
                              normal_length_range=[float(lengths.min()), float(lengths.max())],
                              texels_per_metre_4k_p10_p50_p90=np.percentile(density, [10, 50, 90]).tolist(),
                              uv_min=uv.min(axis=0).tolist(), uv_max=uv.max(axis=0).tolist(),
                              authored_tangents='TANGENT' in primitive['attributes']))
    files = [path, folder / model['buffers'][0]['uri']]
    files += [folder / image['uri'] for image in model['images']]
    return dict(parts=parts, files=[dict(path=str(file), sha256=hashlib.sha256(file.read_bytes()).hexdigest(),
                **({'size': list(Image.open(file).size)} if file.suffix in {'.png', '.jpg'} else {})) for file in files])


def main():
    report = dict(source_audit_version=1, models={
        'DEV-01': inspect_model('ballast_cube', 'ballast_cube'),
        'DEV-04': inspect_model('wall_switch', 'wall_switch_body')})
    report['tiles'] = []
    for group, name, metres in [('surfaces', 'panel_light', 1), ('alien', 'basalt_wall', 2)]:
        files = []
        for kind in ['albedo', 'normal', 'orm']:
            path = Path('content/textures') / group / name / (name + '_' + kind + '.png')
            image = Image.open(path)
            files.append(dict(path=str(path), size=list(image.size), sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        report['tiles'].append(dict(name=name, metres_per_tile=metres, files=files))
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
