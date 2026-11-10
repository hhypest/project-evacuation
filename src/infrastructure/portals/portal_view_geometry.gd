class_name PortalViewGeometry
extends RefCounted
## Clip the aperture to the viewer's screen before rendering it. A fixed whole-aperture texture loses
## almost all its pixels when the eye is close: the screen sees only a tiny patch of that texture.

const MIN_DEPTH: float = 0.0001
const MAX_PIXELS: float = 4194304.0


static func target_size(screen: Vector2i) -> Vector2i:
	var size: Vector2 = Vector2(maxi(64, screen.x), maxi(64, screen.y))
	var scale: float = minf(1.0, sqrt(MAX_PIXELS / (size.x * size.y)))
	scale = minf(scale, 4096.0 / maxf(size.x, size.y))
	return Vector2i(maxi(64, floori(size.x * scale)), maxi(64, floori(size.y * scale)))


## portal_to_eye maps aperture-local points to the viewing camera's frame (-Z forward).
static func visible_region(half: Vector2, portal_to_eye: Transform3D, tangents: Vector2) -> Rect2:
	var polygon: Array[Vector2] = [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
		Vector2(half.x, half.y), Vector2(-half.x, half.y)]
	# Keep the portal up to the eye, rather than the viewer's near plane. The membrane shader clamps
	# its depth at that plane, so it does not disappear during the last centimetres before a crossing.
	var planes: Array[Vector4] = [Vector4(0, 0, -1, -MIN_DEPTH),
		Vector4(1, 0, -tangents.x, 0), Vector4(-1, 0, -tangents.x, 0),
		Vector4(0, 1, -tangents.y, 0), Vector4(0, -1, -tangents.y, 0)]
	for plane: Vector4 in planes:
		polygon = _clip(polygon, portal_to_eye, plane)
		if polygon.is_empty():
			return Rect2()
	var region: Rect2 = Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		region = region.expand(point)
	return region


## Expand to the render target aspect, never trim visible points. This keeps the target's dimensions
## stable while the player moves; only a real window resize reallocates its GPU buffers.
static func fit_aspect(region: Rect2, aspect: float) -> Rect2:
	if not region.has_area() or aspect <= 0.0:
		return Rect2()
	var size: Vector2 = region.size
	if size.x / size.y < aspect:
		size.x = size.y * aspect
	else:
		size.y = size.x / aspect
	# A few texels of guard keep filtering at the cropped screen edge inside the rendered image.
	size *= 1.01
	return Rect2(region.get_center() - size * 0.5, size)


static func uv_region(region: Rect2, half: Vector2) -> Vector4:
	return Vector4((region.position.x + half.x) / (2.0 * half.x),
		(half.y - region.end.y) / (2.0 * half.y), region.size.x / (2.0 * half.x), region.size.y / (2.0 * half.y))


static func _clip(polygon: Array[Vector2], transform: Transform3D, plane: Vector4) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if polygon.is_empty():
		return result
	var before: Vector2 = polygon.back()
	var before_distance: float = _distance(before, transform, plane)
	for after: Vector2 in polygon:
		var after_distance: float = _distance(after, transform, plane)
		if (before_distance >= 0.0) != (after_distance >= 0.0):
			result.append(before.lerp(after, before_distance / (before_distance - after_distance)))
		if after_distance >= 0.0:
			result.append(after)
		before = after
		before_distance = after_distance
	return result


static func _distance(point: Vector2, transform: Transform3D, plane: Vector4) -> float:
	var eye: Vector3 = transform * Vector3(point.x, point.y, 0)
	return plane.x * eye.x + plane.y * eye.y + plane.z * eye.z + plane.w
