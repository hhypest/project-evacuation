class_name CarryRules
extends RefCounted
## Pure geometry of the Talos-style hold (ADR-0012) and the bounded throw.


## Facing on the carrier's floor plane: the view direction with its "up" part removed.
## Looking straight along up or down keeps the previous facing.
static func facing(view_forward: Vector3, up: Vector3, previous: Vector3) -> Vector3:
	var flat: Vector3 = view_forward.slide(up)
	if flat.length() < 0.05:
		flat = previous.slide(up)
	if flat.length() < 0.000001:
		flat = up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD)
	return flat.normalized()


## Centre of the held prop: in front of the carrier at chest height, raised or lowered by the view pitch.
static func hold_point(feet: Vector3, up: Vector3, facing_direction: Vector3, view_forward: Vector3,
	carrier_radius: float, half_extent: float, half_height: float, profile: CarryProfile) -> Vector3:
	var lift: float = clampf(view_forward.normalized().dot(up), -1.0, 1.0) * profile.pitch_lift
	# Never aim below the floor the carrier stands on: a tall prop stops at its own half height.
	var height: float = maxf(profile.hold_height + lift, half_height + profile.clearance * 2.0)
	var reach_out: float = carrier_radius + profile.hold_gap + half_extent
	return feet + up * height + facing_direction * reach_out


## Upright orientation that faces the carrier, choosing the quarter turn about up closest to the current one,
## so a cube never spins further than 45 degrees when it is picked up.
static func upright_basis(current: Basis, up: Vector3, facing_direction: Vector3) -> Basis:
	var y: Vector3 = up.normalized()
	var z: Vector3 = -facing_direction.slide(y).normalized()
	var x: Vector3 = y.cross(z).normalized()
	return _nearest_quarter(Basis(x, y, z), y, current)


## Axis of a resting box (one of its basis columns, signed) that points closest to up, or zero when the box is
## tilted further than max_tilt radians: a prop can only be set down on a level top face.
static func level_axis(basis: Basis, up: Vector3, max_tilt: float) -> Vector3:
	var y: Vector3 = up.normalized()
	var best: Vector3 = Vector3.ZERO
	var best_dot: float = cos(max_tilt)
	for column: Vector3 in [basis.x, basis.y, basis.z]:
		var axis: Vector3 = column.normalized()
		var dot: float = axis.dot(y)
		if absf(dot) >= best_dot:
			best_dot = absf(dot)
			best = axis * signf(dot)
	return best


## Pose of a prop set down on a level support (ADR-0012, placement): centred over the support's top face,
## upright to up, square with the support's own axes and turned by the quarter closest to the prop's current
## orientation, lift metres above the face.
static func slot(top_center: Vector3, reference: Basis, up: Vector3, current: Basis, half_height: float,
		lift: float) -> Transform3D:
	var y: Vector3 = up.normalized()
	var side: Vector3 = reference.x
	for column: Vector3 in [reference.y, reference.z]:
		if absf(column.normalized().dot(y)) < absf(side.normalized().dot(y)):
			side = column
	var x: Vector3 = side.slide(y).normalized()
	var frame: Basis = Basis(x, y, x.cross(y).normalized())
	return Transform3D(_nearest_quarter(frame, y, current), top_center + y * (half_height + lift))


## Of the four quarter turns of frame about up, the one closest to current.
static func _nearest_quarter(frame: Basis, up: Vector3, current: Basis) -> Basis:
	var now: Quaternion = current.orthonormalized().get_rotation_quaternion()
	var best: Basis = frame
	var best_dot: float = -1.0
	for quarter: int in range(4):
		var candidate: Basis = Basis(up, quarter * PI * 0.5) * frame
		var dot: float = absf(now.dot(candidate.get_rotation_quaternion()))
		if dot > best_dot:
			best_dot = dot
			best = candidate
	return best


## Rotation limited to max_angle radians toward the target orientation.
static func turn_toward(current: Basis, target: Basis, max_angle: float) -> Basis:
	var from: Quaternion = current.orthonormalized().get_rotation_quaternion()
	var to: Quaternion = target.orthonormalized().get_rotation_quaternion()
	var angle: float = from.angle_to(to)
	if angle <= max_angle or angle < 0.000001:
		return Basis(to)
	return Basis(from.slerp(to, max_angle / angle))


static func throw_impulse(forward: Vector3, velocity: Vector3, mass: float, profile: CarryProfile) -> Vector3:
	var direction: Vector3 = forward.normalized()
	var speed_left: float = maxf(0.0, profile.max_throw_speed - velocity.dot(direction))
	return direction * minf(profile.throw_impulse, mass * speed_left)
