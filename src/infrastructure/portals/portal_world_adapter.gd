class_name PortalWorldAdapter
extends PortalWorldPort
## Godot/Jolt side of portals. Bodies are the chamber's CarryRigidBody props (stable ID, centred box).
## Teleport runs from the scope's physics tick, outside the locked physics step.

## World and doors, props, player: what an exit volume must not overlap.
const EXIT_MASK: int = 1 | 2 | 4

var _pairs: Array[PortalPairDevice] = []
var _bodies: Dictionary[StringName, CarryRigidBody] = {}
var _space_owner: Node3D


func configure(level: Node3D) -> void:
	_space_owner = level
	_collect(level)


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
	for id: StringName in _bodies.keys():
		var body: CarryRigidBody = _bodies[id]
		if not is_instance_valid(body) or not body.is_inside_tree():
			continue
		var state: PortalBodyState = PortalBodyState.new()
		state.id = id
		state.transform = body.global_transform
		state.linear_velocity = body.linear_velocity
		state.angular_velocity = body.angular_velocity
		var box: BoxShape3D = _box(body)
		state.extent = maxf(box.size.x, maxf(box.size.y, box.size.z)) * 0.5 if box != null else 0.5
		state.held = body.is_carried()
		result.append(state)
	return result


func exit_free(body_id: StringName, destination: Transform3D) -> bool:
	var body: CarryRigidBody = _bodies.get(body_id)
	var box: BoxShape3D = _box(body) if body != null else null
	if box == null:
		return false
	# Slightly smaller than the body so resting contact with a floor is not counted as overlap.
	var probe: BoxShape3D = BoxShape3D.new()
	probe.size = box.size * 0.96
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = destination
	query.collision_mask = EXIT_MASK
	query.exclude = [body.get_rid()]
	return _space_owner.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func teleport(body_id: StringName, destination: Transform3D, linear: Vector3, angular: Vector3) -> void:
	var body: CarryRigidBody = _bodies.get(body_id)
	if body == null:
		return
	body.global_transform = destination
	body.linear_velocity = linear
	body.angular_velocity = angular
	body.sleeping = false


func hold(body_id: StringName, destination: Transform3D, linear: Vector3) -> void:
	var body: CarryRigidBody = _bodies.get(body_id)
	if body == null:
		return
	body.global_transform = destination
	body.linear_velocity = linear
	body.sleeping = false


func close() -> void:
	_pairs.clear()
	_bodies.clear()


static func _box(body: CarryRigidBody) -> BoxShape3D:
	for child: Node in body.get_children():
		var collision: CollisionShape3D = child as CollisionShape3D
		if collision != null and collision.shape is BoxShape3D:
			return collision.shape as BoxShape3D
	return null
