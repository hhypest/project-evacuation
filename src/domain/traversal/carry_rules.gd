class_name CarryRules
extends RefCounted


static func force(error: Vector3, relative_velocity: Vector3, gravity: Vector3,
	mass: float, profile: CarryProfile) -> Vector3:
	# Scale the servo down for light props so a 1 kg cube does not receive a 20 kg controller's gain.
	var gain: float = minf(1.0, mass / profile.reference_mass)
	return ((error * profile.spring - relative_velocity * profile.damping) * gain - gravity * mass).limit_length(profile.max_force)


static func throw_impulse(forward: Vector3, velocity: Vector3, mass: float, profile: CarryProfile) -> Vector3:
	var direction: Vector3 = forward.normalized()
	var speed_left: float = maxf(0.0, profile.max_throw_speed - velocity.dot(direction))
	return direction * minf(profile.throw_impulse, mass * speed_left)
