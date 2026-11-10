class_name PlayerMotor
extends CharacterBody3D
## Godot/Jolt owns collision resolution and position. One call per physics tick from LevelScope.

@export var settings: MovementSettings = preload("res://content/definitions/default_movement.tres")

var profile: MovementProfile
var crouched: bool = false
var mode: MovementStep.Mode = MovementStep.Mode.AIR
var _shape: CapsuleShape3D
var _collision: CollisionShape3D
var _movement: ComputeMovement = ComputeMovement.new()
var _ladder_lock: float = 0.0
var _step_ray: RayCast3D
## Field requested by the scope for the next step: up direction and gravity relative to the base.
var _wanted_up: Vector3 = Vector3.UP
var _wanted_scale: float = 1.0
var _gravity_scale: float = 1.0
## CharacterBody support belongs to its last move_and_slide, not a newly placed pose.
var _support_valid: bool = true
var _support_pose: Transform3D
var _support_up: Vector3 = Vector3.UP
## True while a new field direction waits for free space to turn the capsule.
var reorientation_blocked: bool = false


func _ready() -> void:
	profile = settings.to_profile()
	_shape = CapsuleShape3D.new()
	_shape.radius = profile.radius
	_shape.height = profile.standing_height
	_collision = CollisionShape3D.new()
	_collision.shape = _shape
	_collision.position.y = profile.standing_height * 0.5
	add_child(_collision)
	collision_layer = 4
	collision_mask = 3
	floor_max_angle = deg_to_rad(profile.floor_angle_degrees)
	floor_snap_length = profile.step_height + profile.floor_snap_extra
	platform_floor_layers = 1
	max_slides = 6
	_step_ray = RayCast3D.new()
	_step_ray.enabled = false
	_step_ray.collision_mask = 1
	add_child(_step_ray)


func eye_position() -> Vector3:
	return global_position + up_direction * (profile.crouched_eye_height if crouched else profile.standing_eye_height)


## Requests the effective field for the next step. Applied at the start of step() if the capsule fits.
func set_gravity(up: Vector3, relative_strength: float) -> void:
	if up.is_finite() and not up.is_zero_approx() and is_finite(relative_strength) and relative_strength > 0.0:
		_wanted_up = up.normalized()
		_wanted_scale = relative_strength


func center() -> Vector3:
	return global_position + up_direction * (_shape.height * 0.5)


func portal_shape() -> CapsuleShape3D:
	return _shape


func has_floor_support() -> bool:
	return _support_valid and is_on_floor() and global_transform.is_equal_approx(_support_pose) \
		and up_direction.is_equal_approx(_support_up)


func _invalidate_support() -> void:
	_support_valid = false
	mode = MovementStep.Mode.AIR


## The portal pose is centred on the capsule, not at its feet. Preserve the mapped up/momentum until
## the next step samples the field at the exit before moving; the old floor/ladder is no longer support.
func portal_place(pose: Transform3D, motion: Vector3) -> void:
	global_basis = pose.basis.orthonormalized()
	up_direction = global_basis.y.normalized()
	global_position = pose.origin - up_direction * (_shape.height * 0.5)
	velocity = motion
	_wanted_up = up_direction
	_invalidate_support()
	_ladder_lock = profile.ladder_detach_seconds
	reset_physics_interpolation()


func step(command: MovementCommand, delta: float) -> void:
	_apply_field()
	_ladder_lock = maxf(0.0, _ladder_lock - delta)
	_update_stance(command.crouching)
	var observation: MovementObservation = _observe()
	if mode == MovementStep.Mode.LADDER and not observation.on_ladder:
		_ladder_lock = profile.ladder_detach_seconds
	var result: MovementStep = _movement.execute(command, observation, profile, delta)
	mode = result.mode
	velocity = result.velocity
	if result.jumped and mode == MovementStep.Mode.LADDER:
		_ladder_lock = profile.ladder_detach_seconds
	motion_mode = MOTION_MODE_FLOATING if mode in [MovementStep.Mode.LADDER, MovementStep.Mode.SWIM] else MOTION_MODE_GROUNDED
	if mode == MovementStep.Mode.GROUND and not result.jumped:
		_try_step(velocity.slide(up_direction) * delta)
	var desired_velocity: Vector3 = velocity
	move_and_slide()
	_support_valid = true
	_support_pose = global_transform
	_support_up = up_direction
	_push_props(desired_velocity, delta)


## Turns the capsule about its centre so local +Y matches the field's up. Velocity is kept as is: the new
## field accelerates it from here, no momentum is lost. If the turned capsule would overlap geometry the
## old field stays in force and the turn is retried next step.
func _apply_field() -> void:
	if _wanted_up.dot(up_direction) > 0.99999:
		up_direction = _wanted_up
		_gravity_scale = _wanted_scale
		reorientation_blocked = false
		return
	var half: float = _shape.height * 0.5
	var middle: Vector3 = center()
	var turn: Basis = _shortest_turn(up_direction, _wanted_up, global_basis.x)
	var turned: Basis = (turn * global_basis).orthonormalized()
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var free: bool = false
	# Turning about the centre can extend the capsule into a cube beside the entrance. Try moving
	# toward the new up by at most its cylindrical half-length, then a normal step-height lift.
	# Both the upright translation and the intermediate rotation poses must be free.
	for attempt: int in range(9):
		var lift: Vector3 = _wanted_up * ((half - _shape.radius + profile.stance_clearance) * float(attempt) / 4.0) \
			if attempt <= 4 else up_direction * (profile.step_height * float(attempt - 4) / 4.0)
		query.transform = Transform3D(global_basis, middle)
		query.motion = lift
		if attempt > 0:
			var sweep: PackedFloat32Array = space.cast_motion(query)
			if sweep.size() != 2 or sweep[0] < 1.0:
				continue
		query.motion = Vector3.ZERO
		free = true
		for sample: int in range(1, 13):
			query.transform = Transform3D(global_basis.slerp(turned, float(sample) / 12.0), middle + lift)
			if not space.intersect_shape(query, 1).is_empty():
				free = false
				break
		if free:
			middle += lift
			break
	if not free:
		reorientation_blocked = true
		return
	global_basis = turned
	global_position = middle - _wanted_up * half
	up_direction = _wanted_up
	_invalidate_support()
	_gravity_scale = _wanted_scale
	reorientation_blocked = false


## Smallest rotation taking from -> to; a half turn uses the given perpendicular hint as its axis.
static func _shortest_turn(from: Vector3, to: Vector3, hint: Vector3) -> Basis:
	var axis: Vector3 = from.cross(to)
	var angle: float = from.angle_to(to)
	if axis.length() < 0.000001:
		axis = hint.slide(from)
		if axis.is_zero_approx():
			axis = from.cross(Vector3.RIGHT if absf(from.x) < 0.9 else Vector3.FORWARD)
	return Basis(axis.normalized(), angle)


func _update_stance(wants_crouch: bool) -> void:
	if wants_crouch == crouched:
		return
	var height: float = profile.crouched_height if wants_crouch else profile.standing_height
	var offset: float = 0.0
	if not has_floor_support():
		offset = _shape.height - height
	var destination: Vector3 = global_position + up_direction * offset
	if not wants_crouch:
		var standing: CapsuleShape3D = CapsuleShape3D.new()
		standing.radius = profile.radius
		standing.height = height
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = standing
		query.transform = Transform3D(global_basis, destination + up_direction * (height * 0.5 + profile.stance_clearance))
		query.collision_mask = collision_mask
		query.exclude = [get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			return
	_shape.height = height
	_collision.position.y = height * 0.5
	global_position = destination
	crouched = wants_crouch


func _observe() -> MovementObservation:
	var observation: MovementObservation = MovementObservation.new()
	observation.velocity = velocity
	observation.grounded = has_floor_support()
	observation.crouched = crouched
	observation.up = up_direction
	observation.gravity_scale = _gravity_scale
	var query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	query.position = global_position + up_direction * (_shape.height * 0.5)
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_point(query, 8)
	for hit: Dictionary in hits:
		var collider: Variant = hit.get("collider")
		if collider is not MovementVolume:
			continue
		# Engine query dictionaries expose Variant; the subtype was validated above.
		@warning_ignore("unsafe_cast")
		var volume: MovementVolume = collider as MovementVolume
		if volume.kind == MovementVolume.Kind.LADDER and _ladder_lock <= 0.0:
			observation.on_ladder = true
			observation.ladder_normal = volume.global_basis.z.normalized()
		elif volume.kind == MovementVolume.Kind.WATER:
			observation.in_water = true
			observation.near_water_surface = query.position.y >= volume.surface_height - profile.water_surface_threshold
	return observation


func _try_step(motion: Vector3) -> void:
	if motion.is_zero_approx():
		return
	var obstacle: KinematicCollision3D = KinematicCollision3D.new()
	if not test_move(global_transform, motion, obstacle):
		return
	if obstacle.get_collider() is RigidBody3D:
		return
	var rise: Vector3 = up_direction * profile.step_height
	if test_move(global_transform, rise):
		return
	var raised: Transform3D = global_transform.translated(rise)
	if test_move(raised, motion):
		return
	# Probe the actual tread beyond the capsule rim; rounded edge normals are not tread normals.
	var probe: Vector3 = global_position + motion.normalized() * (profile.radius + motion.length()) + rise
	_step_ray.global_transform = Transform3D(Basis.IDENTITY, probe)
	_step_ray.target_position = -up_direction * (profile.step_height + profile.floor_snap_extra)
	_step_ray.force_raycast_update()
	if not _step_ray.is_colliding() or _step_ray.get_collision_normal().dot(up_direction) < cos(floor_max_angle):
		return
	var height: float = (_step_ray.get_collision_point() - global_position).dot(up_direction)
	if height <= 0.005 or height > profile.step_height:
		return
	global_position += up_direction * (height + safe_margin)


func _push_props(desired: Vector3, delta: float) -> void:
	var pushed: Dictionary[int, bool] = {}
	for index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(index)
		var collider: Object = collision.get_collider()
		if collider is not RigidBody3D or absf(collision.get_normal().dot(up_direction)) > 0.2:
			continue
		var body: RigidBody3D = collider as RigidBody3D
		if body is CarryRigidBody:
			var carried: CarryRigidBody = body as CarryRigidBody
			if carried.is_carried():
				continue
		if pushed.has(body.get_instance_id()):
			continue
		pushed[body.get_instance_id()] = true
		var direction: Vector3 = -collision.get_normal().slide(up_direction).normalized()
		var missing_speed: float = maxf(0.0, desired.dot(direction) - body.linear_velocity.dot(direction))
		var impulse: float = minf(profile.push_force * delta, body.mass * missing_speed)
		if impulse > 0.0:
			body.sleeping = false
			body.apply_central_impulse(direction * impulse)
