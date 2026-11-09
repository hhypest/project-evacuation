class_name CarrySocketBody
extends StaticBody3D
## A static support a held prop can be set down on (ADR-0012, placement), such as a floor button's plate.
## Its own box shape at its origin defines the top face; stable_id names the device it belongs to.

@export var stable_id: StringName = &""


## Centre of the top face in world space, for the given up.
func top_center(up: Vector3) -> Vector3:
	var shape: BoxShape3D = _box()
	if shape == null:
		return global_position
	var axis: Vector3 = CarryRules.level_axis(global_basis, up, PI * 0.5)
	return global_position + axis * _half_along(shape.size, axis)


func is_level(up: Vector3, max_tilt: float) -> bool:
	return _box() != null and CarryRules.level_axis(global_basis, up, max_tilt) != Vector3.ZERO


func _half_along(size: Vector3, axis: Vector3) -> float:
	var basis: Basis = global_basis.orthonormalized()
	return 0.5 * (absf(axis.dot(basis.x)) * size.x + absf(axis.dot(basis.y)) * size.y + absf(axis.dot(basis.z)) * size.z)


func _box() -> BoxShape3D:
	for child: Node in get_children():
		var collision: CollisionShape3D = child as CollisionShape3D
		if collision != null and collision.shape is BoxShape3D and collision.transform.is_equal_approx(Transform3D.IDENTITY):
			return collision.shape as BoxShape3D
	return null
