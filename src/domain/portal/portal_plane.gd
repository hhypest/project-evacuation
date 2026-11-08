class_name PortalPlane
extends RefCounted
## One stationary flat portal: stable ID, global transform (front = local +Z) and half size of the opening.

var id: StringName = &""
var transform: Transform3D = Transform3D.IDENTITY
## Half width and half height of the opening, metres.
var half_size: Vector2 = Vector2(0.8, 1.2)


static func make(plane_id: StringName, plane_transform: Transform3D, half: Vector2) -> PortalPlane:
	var plane: PortalPlane = PortalPlane.new()
	plane.id = plane_id
	plane.transform = plane_transform
	plane.half_size = half
	return plane


func local(point: Vector3) -> Vector3:
	return transform.affine_inverse() * point


func inside_opening(local_point: Vector3, margin: float = 0.0) -> bool:
	return absf(local_point.x) <= half_size.x - margin and absf(local_point.y) <= half_size.y - margin


func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if id.is_empty():
		errors.append("portal needs a stable ID")
	if not (half_size.x > 0.1 and half_size.y > 0.1 and is_finite(half_size.x) and is_finite(half_size.y)):
		errors.append("portal '%s' opening must be larger than 0.2 m" % id)
	var scale: Vector3 = transform.basis.get_scale()
	if not scale.is_equal_approx(Vector3.ONE) or transform.basis.determinant() < 0.0:
		errors.append("portal '%s' transform must be orthonormal without scale or mirroring" % id)
	return errors
