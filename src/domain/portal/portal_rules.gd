class_name PortalRules
extends RefCounted
## Crossing detection and re-entry guard. A crossing is the body centre passing from the front (local z > 0)
## to the back of the plane between two physics ticks, through the opening. One body_entered event is not
## enough for fast bodies; the swept segment is checked instead.

## Distance in front of the exit a transferred body must reach before that exit may send it back.
const GUARD_CLEARANCE: float = 0.1


static func crosses(plane: PortalPlane, previous: Vector3, current: Vector3) -> bool:
	var before: Vector3 = plane.local(previous)
	var after: Vector3 = plane.local(current)
	if not (before.z > 0.0 and after.z <= 0.0):
		return false
	var span: float = before.z - after.z
	var hit: Vector3 = before.lerp(after, before.z / span if span > 0.0 else 0.0)
	return plane.inside_opening(hit)


## A body just sent out of an exit stays guarded until it is clear of that exit's front volume.
static func guard_released(plane: PortalPlane, position: Vector3, extent: float) -> bool:
	var local_position: Vector3 = plane.local(position)
	return local_position.z > extent + GUARD_CLEARANCE or not plane.inside_opening(local_position) \
		or local_position.z < -extent - GUARD_CLEARANCE
