class_name MetricBoxMesh
extends RefCounted
## Identical box geometry with face UVs measured in metres, anchored in the builder's local space.
## Adjacent axis-aligned modules share texture phase; no shared material or collision is changed.

static func make(size: Vector3, at: Vector3, tile_metres: float = 2.0) -> ArrayMesh:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var arrays: Array = box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = PackedVector2Array()
	uv.resize(vertices.size())
	for index: int in range(vertices.size()):
		var point: Vector3 = vertices[index] + at
		var normal: Vector3 = normals[index]
		if absf(normal.z) > 0.5:
			uv[index] = Vector2(point.x * signf(normal.z), -point.y) / tile_metres
		elif absf(normal.x) > 0.5:
			uv[index] = Vector2(-point.z * signf(normal.x), -point.y) / tile_metres
		else:
			uv[index] = Vector2(point.x, point.z * signf(normal.y)) / tile_metres
	arrays[Mesh.ARRAY_TEX_UV] = uv
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_tangents()
	return surface.commit()
