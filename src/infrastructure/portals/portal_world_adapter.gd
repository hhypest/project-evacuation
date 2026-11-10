class_name PortalWorldAdapter
extends PortalWorldPort
## Engine side: centred capsule/box snapshots, whole-shape exit sweeps, local barriers and atomic
## coordinator-phase pose updates. Domain/Application never receive physics nodes or cameras.

const PLAYER_ID: StringName = &"@portal.player"
const EXIT_MASK: int = 1 | 2 | 4

var _pairs: Array[PortalPairDevice] = []
var _bodies: Dictionary[StringName, CarryRigidBody] = {}
var _barriers: Array[RID] = []
var _visuals: Array[PortalPropVisual] = []
var _space_owner: Node3D
var _player: PlayerMotor
var _carry: CarryController


func configure(level: Node3D, player: PlayerMotor = null, carry: CarryController = null) -> bool:
	_space_owner = level
	_player = player
	_carry = carry
	_collect(level)
	if _bodies.has(PLAYER_ID):
		return false
	var surfaces: Array[PortalSurface] = []
	for pair: PortalPairDevice in _pairs:
		for surface: PortalSurface in [pair.surface_a, pair.surface_b]:
			surfaces.append(surface)
			_barriers.append(surface.barrier_rid)
	if not surfaces.is_empty():
		for body: CarryRigidBody in _bodies.values():
			var visual: PortalPropVisual = PortalPropVisual.new()
			level.add_child(visual)
			visual.configure(body, surfaces)
			_visuals.append(visual)
	return true


func _collect(node: Node) -> void:
	if node is PortalPairDevice:
		_pairs.append(node as PortalPairDevice)
	elif node is CarryRigidBody:
		var body: CarryRigidBody = node as CarryRigidBody
		if not body.stable_id.is_empty():
			_bodies[body.stable_id] = body
	for child: Node in node.get_children():
		_collect(child)


func pairs() -> Array[PortalPairState]:
	var result: Array[PortalPairState] = []
	for pair: PortalPairDevice in _pairs:
		if is_instance_valid(pair) and pair.is_inside_tree():
			result.append(pair.state())
	return result


func bodies() -> Array[PortalBodyState]:
	var result: Array[PortalBodyState] = []
	if is_instance_valid(_player) and _player.is_inside_tree():
		var state: PortalBodyState = PortalBodyState.new()
		state.id = PLAYER_ID
		state.is_player = true
		state.transform = Transform3D(_player.global_basis, _player.center())
		state.linear_velocity = _player.velocity
		var capsule: CapsuleShape3D = _player.portal_shape()
		state.half_extents = Vector3(capsule.radius, capsule.height * 0.5, capsule.radius)
		state.extent = capsule.height * 0.5
		result.append(state)
	for id: StringName in _bodies.keys():
		var body: CarryRigidBody = _bodies[id]
		if not is_instance_valid(body) or not body.is_inside_tree():
			continue
		var state: PortalBodyState = PortalBodyState.new()
		state.id = id
		state.transform = body.global_transform
		state.linear_velocity = body.linear_velocity
		state.angular_velocity = body.angular_velocity
		var box: BoxShape3D = body.carry_shape() as BoxShape3D
		state.half_extents = box.size * 0.5
		state.extent = maxf(state.half_extents.x, maxf(state.half_extents.y, state.half_extents.z))
		state.held = body.is_carried()
		state.carrier_id = PLAYER_ID if state.held and _player != null else &""
		result.append(state)
	return result


func exit_free(body_id: StringName, destination: Transform3D, exclude_ids: Array[StringName] = [],
		from: Vector3 = Vector3.INF) -> bool:
	var shape: Shape3D = _shape(body_id)
	if shape == null:
		return false
	# Resting contact is not penetration. Preserve almost the whole capsule/box, including its up.
	var probe: Shape3D = shape.duplicate() as Shape3D
	if probe is BoxShape3D:
		var box: BoxShape3D = probe as BoxShape3D
		box.size *= 0.98
	elif probe is CapsuleShape3D:
		var capsule: CapsuleShape3D = probe as CapsuleShape3D
		capsule.radius *= 0.98
		capsule.height *= 0.98
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = destination
	query.collision_mask = EXIT_MASK
	var excluded: Array[RID] = _barriers.duplicate()
	var ids: Array[StringName] = [body_id]
	ids.append_array(exclude_ids)
	for id: StringName in ids:
		var rid: RID = _rid(id)
		if rid.is_valid():
			excluded.append(rid)
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = _space_owner.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	if from.is_finite():
		query.transform.origin = from
		if not space.intersect_shape(query, 1).is_empty():
			return false
		query.motion = destination.origin - from
		if not query.motion.is_zero_approx():
			var fractions: PackedFloat32Array = space.cast_motion(query)
			return fractions.size() == 2 and fractions[0] >= 1.0
	return true


func set_barrier(plane_id: StringName, blocked: bool) -> void:
	for pair: PortalPairDevice in _pairs:
		for surface: PortalSurface in [pair.surface_a, pair.surface_b]:
			if StringName(String(pair.stable_id) + "." + surface.name.to_lower()) == plane_id:
				surface.set_blocked(blocked)


func release(body_id: StringName) -> void:
	if _carry != null:
		_carry.drop_for_portal(body_id)


func straddle(body_id: StringName, plane_id: StringName) -> void:
	var found: PortalSurface = null
	for pair: PortalPairDevice in _pairs:
		for surface: PortalSurface in [pair.surface_a, pair.surface_b]:
			if StringName(String(pair.stable_id) + "." + surface.name.to_lower()) == plane_id:
				found = surface
	for visual: PortalPropVisual in _visuals:
		if is_instance_valid(visual.body) and visual.body.stable_id == body_id:
			visual.set_held_surface(found)


func teleport(body_id: StringName, destination: Transform3D, linear: Vector3, angular: Vector3) -> void:
	if body_id == PLAYER_ID and is_instance_valid(_player):
		_player.portal_place(destination, linear)
		return
	var body: CarryRigidBody = _bodies.get(body_id)
	if is_instance_valid(body):
		body.portal_place(destination, linear, angular)
		for visual: PortalPropVisual in _visuals:
			if visual.body == body:
				visual.reset_transit()


func hold(body_id: StringName, destination: Transform3D, linear: Vector3) -> void:
	if body_id == PLAYER_ID and is_instance_valid(_player):
		_player.portal_place(destination, linear)
		return
	var body: CarryRigidBody = _bodies.get(body_id)
	if is_instance_valid(body):
		body.global_transform = destination
		body.linear_velocity = linear
		body.sleeping = false
		body.reset_physics_interpolation()


func close() -> void:
	for visual: PortalPropVisual in _visuals:
		if is_instance_valid(visual):
			visual.queue_free()
	for pair: PortalPairDevice in _pairs:
		if is_instance_valid(pair):
			pair.surface_a.set_blocked(false)
			pair.surface_b.set_blocked(false)
	_visuals.clear()
	_pairs.clear()
	_bodies.clear()
	_barriers.clear()
	_player = null
	_carry = null


func _shape(id: StringName) -> Shape3D:
	if id == PLAYER_ID and is_instance_valid(_player):
		return _player.portal_shape()
	var body: CarryRigidBody = _bodies.get(id)
	return body.carry_shape() if is_instance_valid(body) else null


func _rid(id: StringName) -> RID:
	if id == PLAYER_ID and is_instance_valid(_player):
		return _player.get_rid()
	var body: CarryRigidBody = _bodies.get(id)
	return body.get_rid() if is_instance_valid(body) else RID()
