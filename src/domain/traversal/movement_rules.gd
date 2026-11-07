class_name MovementRules
extends RefCounted
## Controller velocity laws only. Collision resolution/position integration belongs to Godot.


static func accelerate(
	velocity: Vector3, direction: Vector3, speed: float, acceleration: float, delta: float
) -> Vector3:
	var missing: float = speed - velocity.dot(direction)
	if missing <= 0.0 or direction.is_zero_approx():
		return velocity
	return velocity + direction * minf(missing, acceleration * speed * delta)


static func apply_friction(velocity: Vector3, friction: float, stop_speed: float, delta: float) -> Vector3:
	var speed: float = velocity.length()
	if speed < 0.001:
		return Vector3.ZERO
	var remaining: float = maxf(0.0, speed - maxf(stop_speed, speed) * friction * delta)
	return velocity * (remaining / speed)
