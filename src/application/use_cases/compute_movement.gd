class_name ComputeMovement
extends RefCounted


func execute(
	command: MovementCommand, observation: MovementObservation, profile: MovementProfile, delta: float
) -> MovementStep:
	var result: MovementStep = MovementStep.new()
	var up: Vector3 = observation.up
	var forward: Vector3 = command.forward.slide(up).normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	var right: Vector3 = forward.cross(up).normalized()
	var axis: Vector2 = command.move_axis.limit_length()
	var wish: Vector3 = (right * axis.x - forward * axis.y).limit_length()
	if observation.on_ladder:
		result.mode = MovementStep.Mode.LADDER
		result.velocity = (up * -axis.y + up.cross(observation.ladder_normal) * axis.x).limit_length()
		result.velocity *= profile.climb_speed
		# Light pressure into the face lets the capsule cross the lip at the top.
		result.velocity -= observation.ladder_normal * maxf(0.0, -axis.y) * profile.ladder_inward_speed
		if command.jump_requested:
			result.velocity = observation.ladder_normal * profile.climb_speed + up * profile.jump_speed() * 0.65
			result.jumped = true
		return result
	if observation.in_water:
		result.mode = MovementStep.Mode.SWIM
		var swim_wish: Vector3 = right * axis.x - command.forward.normalized() * axis.y
		if command.jump_held:
			swim_wish += up
		if command.crouching:
			swim_wish -= up
		if swim_wish.is_zero_approx():
			result.velocity = observation.velocity.move_toward(up * profile.buoyancy_speed,
				profile.buoyancy_acceleration * delta)
		else:
			result.velocity = observation.velocity.move_toward(swim_wish.limit_length() * profile.swim_speed,
				profile.swim_acceleration * delta)
		if observation.near_water_surface and command.jump_held:
			result.velocity = result.velocity.slide(up) + up * profile.water_jump_speed
			result.jumped = true
		return result
	var vertical: float = observation.velocity.dot(up)
	var planar: Vector3 = observation.velocity.slide(up)
	var speed: float = profile.run_speed
	if observation.crouched:
		speed = profile.crouch_speed
	elif command.walking:
		speed = profile.walk_speed
	if observation.grounded:
		result.mode = MovementStep.Mode.GROUND
		planar = MovementRules.apply_friction(planar, profile.friction, profile.stop_speed, delta)
		planar = MovementRules.accelerate(planar, wish.normalized(), speed * axis.length(),
			profile.ground_acceleration, delta).limit_length(speed)
		vertical = -profile.floor_stick_speed
		if command.jump_requested:
			vertical = profile.jump_speed()
			result.jumped = true
	else:
		result.mode = MovementStep.Mode.AIR
		planar = MovementRules.accelerate(planar, wish.normalized(),
			minf(speed, profile.air_control_speed) * axis.length(), profile.air_acceleration, delta)
		planar = planar.limit_length(profile.run_speed)
		vertical -= profile.gravity * observation.gravity_scale * delta
	result.velocity = planar + up * vertical
	return result
