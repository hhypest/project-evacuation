class_name PortalWorldPort
extends RefCounted
## Physics side of portals: pairs with power, body states, exit volume query and the two body operations.


func pairs() -> Array[PortalPairState]:
	return []


func bodies() -> Array[PortalBodyState]:
	return []


## True when the whole body fits at the destination without overlapping anything but itself.
func exit_free(_body_id: StringName, _destination: Transform3D, _exclude_ids: Array[StringName] = [],
		_from: Vector3 = Vector3.INF) -> bool:
	return false


func set_barrier(_plane_id: StringName, _blocked: bool) -> void:
	pass


## Safely drop an attached prop before a refused group transfer; cancel its queued carry/throw commands.
func release(_body_id: StringName) -> void:
	pass


## Rendering hint for a held body whose centre has already crossed (or empty to clear it).
## The physics tick owns this history; a slow render frame must not miss the straddling interval.
func straddle(_body_id: StringName, _plane_id: StringName) -> void:
	pass


## Moves the body and replaces its velocities in one physics-safe operation.
func teleport(_body_id: StringName, _destination: Transform3D, _linear: Vector3, _angular: Vector3) -> void:
	pass


## Applies recovery only if the complete pose and path from the current body are free. A failed
## placement must leave the physical body unchanged, so the coordinator can reset the chamber.
func hold(_body_id: StringName, _destination: Transform3D, _linear: Vector3, _former_carrier: StringName = &"") -> bool:
	return false
