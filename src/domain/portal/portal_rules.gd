class_name PortalRules
extends RefCounted
## Crossing detection and re-entry guard. A crossing is the body centre passing from the front (local z > 0)
## to the back of the plane between two physics ticks, through the opening. One body_entered event is not
## enough for fast bodies; the swept segment is checked instead.

## Distance in front of the exit a transferred body must reach before that exit may send it back.
const GUARD_CLEARANCE: float = 0.1
## Metres: the standard frame is 0.4 m deep; the local barrier is 0.04 m deep.
const FRAME_HALF_DEPTH: float = 0.2
const BARRIER_HALF_DEPTH: float = 0.02
const ENTRY_CLEARANCE: float = 0.02
const CONTACT_TOLERANCE: float = 0.001


static func projected_extent(basis: Basis, half: Vector3) -> Vector3:
	return basis.x.abs() * half.x + basis.y.abs() * half.y + basis.z.abs() * half.z


static func fits(plane: PortalPlane, pose: Transform3D, half: Vector3) -> bool:
	var local: Transform3D = plane.transform.affine_inverse() * pose
	var extent: Vector3 = projected_extent(local.basis, half)
	return absf(local.origin.x) + extent.x <= plane.half_size.x + CONTACT_TOLERANCE * 2.0 \
		and absf(local.origin.y) + extent.y <= plane.half_size.y + CONTACT_TOLERANCE * 2.0


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
