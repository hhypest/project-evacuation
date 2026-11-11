class_name UnifiedLabTests
extends TestSuite
## Real unified scene: accessible bays, pool geometry, independent circuits and the repaired door kit.

const LAB: PackedScene = preload("res://content/levels/mechanics_lab.tscn")
const GENERATION: int = 125

var _tree: SceneTree
var _scope: LevelScope
var _level: Node3D
var _player: PlayerMotor
var _camera: LookCamera


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	_scope = LevelScope.new()
	tree.root.add_child(_scope)
	if not _scope.open(LAB, GENERATION):
		results.append(TestOutcome.new("unified lab opens with all networks and a single portal pair", false))
		_scope.queue_free()
		return results
	_level = _scope.get_child(0) as Node3D
	_player = _level.get_node("Player") as PlayerMotor
	_camera = _level.get_node("Camera") as LookCamera
	await _ticks(25)
	results.append(TestOutcome.new("six named independent bays and exactly one portal pair load",
		_level.get_node_or_null("Movement") != null and _level.get_node_or_null("Carry") != null
		and _level.get_node_or_null("Devices") != null and _level.get_node_or_null("Optics") != null
		and _level.get_node_or_null("Gravity") != null
		and _level.find_children("*", "PortalPairDevice", true, false).size() == 1))
	var routes_clear: bool = true
	for z: float in [-14.0, -40.0, -66.0]:
		for side: float in [-1.0, 1.0]:
			routes_clear = _clear_path(Vector3(0, 0.05, -2), Vector3(0, 0.05, z)) and routes_clear
			routes_clear = _clear_path(Vector3(0, 0.05, z), Vector3(side * 4, 0.05, z)) and routes_clear
	results.append(TestOutcome.new("a full-height player capsule has an unobstructed route to every bay", routes_clear))
	var space: PhysicsDirectSpaceState3D = _level.get_world_3d().direct_space_state
	var pool: Node3D = _level.get_node("Movement/Water") as Node3D
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		pool.global_position + Vector3(0, 1.8, 0), pool.global_position - Vector3(0, 2, 0), 1)
	var hit: Dictionary = space.intersect_ray(query)
	var pool_has_depth: bool = hit.get("position") is Vector3
	if pool_has_depth:
		var floor_at: Vector3 = hit["position"]
		pool_has_depth = floor_at.y < -2.9
	results.append(TestOutcome.new("the pool has a real floor opening and a bottom three metres below grade", pool_has_depth))
	var movement: Node3D = _level.get_node("Movement") as Node3D
	_player.global_position = movement.to_global(Vector3(6, -2.3, 6))
	_player.velocity = Vector3.ZERO
	_camera.global_basis = Basis.IDENTITY
	await _ticks(90, false, Vector2.ZERO, true)
	for tick: int in range(120):
		if movement.to_local(_player.global_position).x < 2.5:
			break
		await _ticks(1, false, Vector2.LEFT, true)
	await _ticks(20)
	results.append(TestOutcome.new("the player swims up and exits the new pool over its actual stairs",
		movement.to_local(_player.global_position).x < 3.0 and _player.global_position.y > -0.1 and _player.is_on_floor(),
		str(movement.to_local(_player.global_position))))
	_player.global_position = Vector3(0, 0.05, 4)
	_player.velocity = Vector3.ZERO
	var plate: FloorButtonDevice = _level.get_node("Devices/qa_devices_plate") as FloorButtonDevice
	var cube: CarryRigidBody = _level.get_node("Devices/PlateCubeA") as CarryRigidBody
	var other: CarryRigidBody = _level.get_node("Devices/PlateCubeB") as CarryRigidBody
	_place(cube, plate.global_position + Vector3(0, 0.65, 0))
	await _ticks(35)
	var light_stays_shut: bool = not _output(&"qa.devices.plate")
	_place(other, plate.global_position + Vector3(0, 1.7, 0))
	await _ticks(70)
	var door: DoorDevice = _level.get_node("Devices/qa_devices_door_plate") as DoorDevice
	results.append(TestOutcome.new("new bay keeps the 8 kg plate threshold and stacked cubes open the new door",
		light_stays_shut and _output(&"qa.devices.plate") and door.is_open()))
	results.append(TestOutcome.new("the plate bay does not power optics or the independent gravity field",
		not _output(&"qa.optics.emitter") and not _output(&"qa.gravity.field")))
	# The player is moved out of the doorway so the prop alone exercises obstruction protection.
	_place(other, door.global_position + Vector3(0, 0.55, 0))
	_place(cube, plate.global_position + Vector3(3, 0.55, 0))
	await _ticks(55)
	results.append(TestOutcome.new("a cube in the new door aperture prevents closing after load is removed",
		not _output(&"qa.devices.plate") and door.blocked and door.is_open()))
	_place(other, plate.global_position + Vector3(4.5, 0.55, 0))
	await _ticks(45)
	results.append(TestOutcome.new("the new door closes once its aperture is clear", not door.blocked and door.openness < 0.01))
	results.append(TestOutcome.new("the repaired frame leaves its standard aperture visually empty", _frame_clear(door)))
	var custom: DoorDevice = DoorDevice.new()
	custom.opening = Vector2(3.0, 3.2)
	custom.position = Vector3(0, 0, -100)
	_level.add_child(custom)
	results.append(TestOutcome.new("modular posts and lintel preserve a wider and taller custom aperture", _frame_clear(custom)))
	custom.queue_free()
	await _press(_level.get_node("Optics/qa_optics_toggle") as Node3D)
	await _ticks(45)
	results.append(TestOutcome.new("the new optics bay traces its real powered beam into the receiver",
		_output(&"qa.optics.emitter") and _output(&"qa.optics.receiver")))
	var blocker: CarryRigidBody = _level.get_node("Optics/Blocker") as CarryRigidBody
	var emitter: EmitterDevice = _level.get_node("Optics/qa_optics_emitter") as EmitterDevice
	var receiver: ReceiverDevice = _level.get_node("Optics/qa_optics_receiver") as ReceiverDevice
	_place(blocker, (emitter.global_position + receiver.global_position) * 0.5)
	await _ticks(35)
	results.append(TestOutcome.new("a physical cube interrupts the new bay's beam without turning off its emitter",
		_output(&"qa.optics.emitter") and not _output(&"qa.optics.receiver")))
	var loop: Node3D = _level.get_node("Gravity/CombinedLoop") as Node3D
	var wall_plate: FloorButtonDevice = loop.get_node("loop_plate") as FloorButtonDevice
	var loop_cube: CarryRigidBody = loop.get_node("CubeA") as CarryRigidBody
	var surface: Vector3 = wall_plate.global_position + Vector3.RIGHT * 0.1
	_place(loop_cube, surface + Vector3.RIGHT * (TrialLoopBuilder.CUBE_EDGE * 0.5 + 0.01))
	await _ticks(90)
	results.append(TestOutcome.new("the translated combined bench holds its beam-NOT-field-wall-plate feedback loop",
		_output(&"loop.field") and _output(&"loop.plate") and _output(&"loop.door") and not _output(&"loop.receiver")))
	_scope.close()
	await tree.process_frame
	_scope = LevelScope.new()
	tree.root.add_child(_scope)
	var reopened: bool = _scope.open(LAB, GENERATION + 1)
	results.append(TestOutcome.new("reopening rebuilds all bays with original cube positions and unpowered test switches",
		reopened and not _scope.puzzle().network.output(&"qa.optics.toggle")
		and not _scope.puzzle().network.output(&"qa.devices.plate")))
	_scope.close()
	await tree.process_frame
	return results


func _clear_path(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, from + Vector3.UP * 0.9)
	query.motion = to - from
	query.collision_mask = 1
	query.exclude = [_player.get_rid()]
	var fraction: PackedFloat32Array = _level.get_world_3d().direct_space_state.cast_motion(query)
	return fraction.size() == 2 and fraction[0] > 0.999


func _frame_clear(door: DoorDevice) -> bool:
	var frame: Node3D = door.get_node("FrameModel") as Node3D
	var faces: PackedVector3Array = PackedVector3Array()
	for child: Node in frame.find_children("*", "MeshInstance3D", true, false):
		var visual: MeshInstance3D = child as MeshInstance3D
		var transform: Transform3D = door.global_transform.affine_inverse() * visual.global_transform
		for point: Vector3 in visual.mesh.get_faces():
			faces.append(transform * point)
	for x: float in [-door.opening.x * 0.5 + 0.1, 0.0, door.opening.x * 0.5 - 0.1]:
		for y: float in [0.1, door.opening.y * 0.5, door.opening.y - 0.1]:
			for side: float in [-1.0, 1.0]:
				for index: int in range(0, faces.size(), 3):
					# Godot geometry query boundary: a ray hit is Vector3, a miss is null.
					var hit: Variant = Geometry3D.ray_intersects_triangle(Vector3(x, y, side), Vector3(0, 0, -side),
						faces[index], faces[index + 1], faces[index + 2])
					if hit is Vector3:
						return false
	return true


func _place(body: CarryRigidBody, at: Vector3) -> void:
	body.portal_place(Transform3D(Basis.IDENTITY, at), Vector3.ZERO, Vector3.ZERO)
	body.sleeping = false


func _press(device: Node3D) -> void:
	var front: Vector3 = device.global_basis.z.normalized()
	_player.global_position = Vector3(device.global_position.x, 0.05, device.global_position.z) + front * 1.3
	await _ticks(15)
	_camera.look_at(device.global_position, Vector3.UP)
	await _ticks(1, true)


func _output(id: StringName) -> bool:
	return _scope.puzzle().last_result.output(id)


func _ticks(count: int, interact: bool = false, move: Vector2 = Vector2.ZERO, jump: bool = false) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = GENERATION
		frame.interact_requested = interact and tick == 0
		frame.move_axis = move
		frame.jump_held = jump
		_scope.apply_input(frame)
