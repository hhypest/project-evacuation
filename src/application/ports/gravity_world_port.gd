class_name GravityWorldPort
extends RefCounted
## Spatial side of gravity zones: which zones contain a point and the level base gravity.


func zones() -> Array[GravityZone]:
	return []


func zones_at(_point: Vector3) -> Array[GravityZone]:
	return []


func base() -> GravityZone:
	return GravityZone.make(&"level.base", -2147483648, Vector3.DOWN, 9.8)
