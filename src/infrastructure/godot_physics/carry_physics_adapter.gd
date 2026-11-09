class_name CarryPhysicsAdapter
extends CarryWorldPort

var _bodies: Dictionary[StringName, CarryRigidBody] = {}
var _player: PlayerMotor
var _profile: CarryProfile
var _open: bool = true
## Released props that still overlap the carrier keep ignoring it until they separate (ADR-0012).
var _separating: Array[CarryRigidBody] = []


func configure(level: Node3D, player: PlayerMotor, profile: CarryProfile, scope_id: int) -> bool:
	_player = player
	_profile = profile
	return _register(level, scope_id)


func _register(node: Node, scope_id: int) -> bool:
	if node is CarryRigidBody:
		var body: CarryRigidBody = node as CarryRigidBody
		if _bodies.has(body.stable_id) or not body.configure(_profile, scope_id):
			return false
		_bodies[body.stable_id] = body
	for child: Node in node.get_children():
		if not _register(child, scope_id):
			return false
	return true


func candidate(view: Transform3D, reach: float) -> CarryObservation:
	if not _open:
		return null
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		view.origin, view.origin - view.basis.z * reach, 3, [_player.get_rid()])
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Variant = hit.get("collider")
	if collider is not CarryRigidBody:
		return null
	# Raw engine query; the exact subtype was checked before crossing the typed boundary.
	@warning_ignore("unsafe_cast")
	var body: CarryRigidBody = collider as CarryRigidBody
	if _bodies.get(body.stable_id) != body:
		return null
	return observe(body.stable_id)


func observe(id: StringName) -> CarryObservation:
	var body: CarryRigidBody = _body(id)
	if body == null:
		return null
	var observation: CarryObservation = CarryObservation.new()
	observation.id = id
	observation.mass = body.mass
	observation.position = body.global_position
	observation.basis = body.global_basis
	observation.velocity = body.linear_velocity
	var size: Vector3 = (body.carry_shape() as BoxShape3D).size
	observation.half_extent = maxf(size.x, size.z) * 0.5
	observation.half_height = size.y * 0.5
	return observation


func acquire(id: StringName) -> bool:
	var body: CarryRigidBody = _body(id)
	if body == null or not body.acquire():
		return false
	_separating.erase(body)
	# The held prop and its carrier never push each other; the prop is placed by sweeps instead.
	body.add_collision_exception_with(_player)
	_player.add_collision_exception_with(body)
	return true


func supporting_player(id: StringName) -> bool:
	var body: CarryRigidBody = _body(id)
	if body == null:
		return false
	for index: int in range(_player.get_slide_collision_count()):
		var contact: KinematicCollision3D = _player.get_slide_collision(index)
		if contact.get_collider() == body and contact.get_normal().dot(_player.up_direction) > 0.5:
			return true
	return false


func follow(id: StringName, desired: Transform3D, max_step: float, max_turn: float) -> CarryTarget:
	var result: CarryTarget = CarryTarget.new()
	var body: CarryRigidBody = _body(id)
	if body == null:
		return result
	var current: Transform3D = body.global_transform.orthonormalized()
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = body.carry_shape()
	query.collision_mask = 3
	query.exclude = [_player.get_rid(), body.get_rid()]
	query.margin = _profile.clearance
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	# Turn in place only where the turned box fits; otherwise keep the old orientation this tick.
	var basis: Basis = CarryRules.turn_toward(current.basis, desired.basis, max_turn)
	query.transform = Transform3D(basis, current.origin)
	if not space.intersect_shape(query, 1).is_empty():
		basis = current.basis
		query.transform = current
	var origin: Vector3 = current.origin
	var motion: Vector3 = current.origin.move_toward(desired.origin, max_step) - origin
	if motion.length() > 0.000001:
		# The sweep itself runs without margin; the clearance is kept by stopping short of the hit.
		query.margin = 0.0
		query.transform = Transform3D(basis, origin)
		if space.intersect_shape(query, 1).is_empty():
			origin = _slide(space, query, basis, origin, motion)
		else:
			# cast_motion ignores a start that already touches. A prop resting on a floor sinks into it a
			# little in Jolt, so push it out along its contacts first and sweep on from free space.
			var free: Vector3 = _recover(space, query, basis, origin)
			var pushed: float = free.distance_to(origin)
			query.transform = Transform3D(basis, free)
			if pushed <= max_step and space.intersect_shape(query, 1).is_empty():
				origin = _slide(space, query, basis, free, free.move_toward(desired.origin, max_step - pushed) - free)
			else:
				var step: Vector3 = motion
				for _attempt: int in range(4):
					query.transform = Transform3D(basis, origin + step)
					if space.intersect_shape(query, 1).is_empty():
						origin += step
						break
					step *= 0.5
	result.available = true
	result.transform = Transform3D(basis, origin)
	return result


## Moves a prop that overlaps the world out along its deepest contact, a few passes at most. The caller checks
## that the result is free.
func _recover(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, basis: Basis,
		origin: Vector3) -> Vector3:
	var recovered: Vector3 = origin
	query.margin = 0.0
	query.motion = Vector3.ZERO
	for _pass: int in range(4):
		query.transform = Transform3D(basis, recovered)
		var points: Array[Vector3] = space.collide_shape(query, 8)
		var push: Vector3 = Vector3.ZERO
		# Pairs: a point on the prop, then the matching point on the world body.
		for index: int in range(0, points.size() - 1, 2):
			var separation: Vector3 = points[index + 1] - points[index]
			if separation.length() > push.length():
				push = separation
		if push.length() <= 0.000001:
			break
		recovered += push + push.normalized() * 0.002
	return recovered


## Sweeps toward the hold point and, when a surface blocks the way, keeps the rest of the motion along it,
## so a prop pressed to a floor, ceiling or wall still follows sideways movement.
func _slide(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D, basis: Basis,
		origin: Vector3, motion: Vector3) -> Vector3:
	var remaining: Vector3 = motion
	for _bounce: int in range(3):
		if remaining.length() <= 0.000001:
			break
		query.margin = 0.0
		query.transform = Transform3D(basis, origin)
		query.motion = remaining
		var fractions: PackedFloat32Array = space.cast_motion(query)
		if fractions.size() != 2:
			break
		if fractions[0] >= 1.0:
			origin += remaining
			break
		var touching: Vector3 = origin + remaining * fractions[1]
		origin += remaining.normalized() * maxf(0.0, remaining.length() * fractions[0] - _profile.clearance)
		query.motion = Vector3.ZERO
		query.transform = Transform3D(basis, touching)
		query.margin = _profile.clearance
		var contact: Dictionary = space.get_rest_info(query)
		if typeof(contact.get("normal")) != TYPE_VECTOR3:
			break
		var normal: Vector3 = contact["normal"]
		remaining = (remaining * (1.0 - fractions[0])).slide(normal.normalized())
	query.margin = 0.0
	query.motion = Vector3.ZERO
	return origin


func submit(id: StringName, command: CarryBodyCommand) -> bool:
	var body: CarryRigidBody = _body(id)
	if body == null or not body.submit(command):
		return false
	if command.releasing:
		if _overlaps_player(body):
			# Restoring collisions now would hand an interpenetrating pair to the solver; wait for separation.
			if body not in _separating:
				_separating.append(body)
		else:
			_unpair(body)
	return true


func settle() -> void:
	for body: CarryRigidBody in _separating.duplicate():
		if not is_instance_valid(body) or not body.is_inside_tree():
			_separating.erase(body)
		elif body.is_carried():
			_separating.erase(body)
		elif not _overlaps_player(body):
			_unpair(body)
			_separating.erase(body)


func _overlaps_player(body: CarryRigidBody) -> bool:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = body.carry_shape()
	query.transform = body.global_transform.orthonormalized()
	query.collision_mask = _player.collision_layer
	query.exclude = [body.get_rid()]
	for hit: Dictionary in _player.get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit.get("rid") == _player.get_rid():
			return true
	return false


func cancel_pending() -> void:
	for body: CarryRigidBody in _bodies.values():
		if is_instance_valid(body):
			body.cancel_pending()


func close() -> void:
	_open = false
	for body: CarryRigidBody in _bodies.values():
		if is_instance_valid(body):
			_unpair(body)
			body.close()
	_bodies.clear()
	_separating.clear()


func _unpair(body: CarryRigidBody) -> void:
	if is_instance_valid(_player):
		body.remove_collision_exception_with(_player)
		_player.remove_collision_exception_with(body)


func _body(id: StringName) -> CarryRigidBody:
	if not _open:
		return null
	var body: CarryRigidBody = _bodies.get(id)
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion():
		if is_instance_valid(body):
			_unpair(body)
			body.close()
		_bodies.erase(id)
		return null
	return body
