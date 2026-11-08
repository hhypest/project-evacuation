class_name PortalWorldPort
extends RefCounted
## Physics side of portals: pairs with power, body states, exit volume query and the two body operations.


func pairs() -> Array[PortalPairState]:
	return []


func bodies() -> Array[PortalBodyState]:
	return []


## True when the whole body fits at the destination without overlapping anything but itself.
func exit_free(_body_id: StringName, _destination: Transform3D) -> bool:
	return false


## Moves the body and replaces its velocities in one physics-safe operation.
func teleport(_body_id: StringName, _destination: Transform3D, _linear: Vector3, _angular: Vector3) -> void:
	pass


## Keeps a refused body on the allowed side of the entry: front of the plane, no velocity into it.
func hold(_body_id: StringName, _destination: Transform3D, _linear: Vector3) -> void:
	pass
