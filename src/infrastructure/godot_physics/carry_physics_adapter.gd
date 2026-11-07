class_name CarryPhysicsAdapter
extends CarryWorldPort

var _bodies: Dictionary[StringName, CarryRigidBody] = {}
var _player: PlayerMotor
var _profile: CarryProfile
var _open: bool = true


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
	return observation


func acquire(id: StringName) -> bool:
	var body: CarryRigidBody = _body(id)
	return body != null and body.acquire()


func supporting_player(id: StringName) -> bool:
	var body: CarryRigidBody = _body(id)
	if body == null:
		return false
	for index: int in range(_player.get_slide_collision_count()):
		var contact: KinematicCollision3D = _player.get_slide_collision(index)
		if contact.get_collider() == body and contact.get_normal().dot(_player.up_direction) > 0.5:
			return true
	return false


func target(id: StringName, view: Transform3D, basis: Basis) -> CarryTarget:
	var result: CarryTarget = CarryTarget.new()
	var body: CarryRigidBody = _body(id)
	if body == null:
		return result
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = body.carry_shape()
	query.transform = Transform3D(basis.orthonormalized(), view.origin)
	query.collision_mask = 3
	query.exclude = [_player.get_rid(), body.get_rid()]
	query.margin = _profile.clearance
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	# cast_motion ignores initial overlaps. Reject those explicitly instead of guessing a clear path.
	if not space.intersect_shape(query, 1).is_empty():
		return result
	query.motion = -view.basis.z * _profile.hold_distance
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() != 2:
		return result
	var distance: float = maxf(0.0, _profile.hold_distance * fractions[0] - _profile.clearance)
	if distance < _profile.minimum_distance:
		return result
	query.transform.origin += -view.basis.z * distance
	query.motion = Vector3.ZERO
	if not space.intersect_shape(query, 1).is_empty():
		return result
	result.available = true
	result.transform = query.transform
	return result


func submit(id: StringName, command: CarryBodyCommand) -> bool:
	var body: CarryRigidBody = _body(id)
	return body != null and body.submit(command)


func cancel_pending() -> void:
	for body: CarryRigidBody in _bodies.values():
		if is_instance_valid(body):
			body.cancel_pending()


func close() -> void:
	_open = false
	for body: CarryRigidBody in _bodies.values():
		if is_instance_valid(body):
			body.close()
	_bodies.clear()


func _body(id: StringName) -> CarryRigidBody:
	if not _open:
		return null
	var body: CarryRigidBody = _bodies.get(id)
	if not is_instance_valid(body) or not body.is_inside_tree() or body.is_queued_for_deletion():
		if is_instance_valid(body):
			body.close()
		_bodies.erase(id)
		return null
	return body
