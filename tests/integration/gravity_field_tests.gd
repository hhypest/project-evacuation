class_name GravityFieldTests
extends TestSuite
## Jolt-backed checks of gravity fields (SKL-07): sleeping bodies react to a field change, the player
## turns to the new floor and walks on it, leaving the field restores base gravity, priorities resolve
## overlaps the same way for bodies and for the player.

const LAB: PackedScene = preload("res://content/levels/foundation_lab.tscn")
const PLAYER: PackedScene = preload("res://src/infrastructure/godot_physics/player_body.tscn")
const GENERATION: int = 23

var _tree: SceneTree
var _scope: LevelScope
var _player: PlayerMotor
var _camera: LookCamera
var _lab: Node3D


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	results.append_array(await _lab_bay())
	results.append_array(await _priority())
	results.append_array(await _blocked_turn())
	return results


## A field pulling sideways in a 1 m shaft: the lying capsule would overlap the walls, so the old field
## stays in force and the turn waits; it happens once the shaft is opened.
func _blocked_turn() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var root: Node3D = Node3D.new()
	root.name = "Shaft"
	var camera: LookCamera = LookCamera.new()
	camera.name = "Camera"
	_own(root, camera)
	var player: PlayerMotor = PLAYER.instantiate() as PlayerMotor
	player.name = "Player"
	player.position = Vector3(0, 0.05, 0)
	_own(root, player)
	var ground: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(20, 1, 20), Color.GRAY, Vector3(0, -0.5, 0))
	_own(root, ground)
	for side: float in [-1.0, 1.0]:
		var wall: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(0.2, 3, 3), Color.GRAY, Vector3(side * 0.6, 1.5, 0))
		wall.name = "WallLeft" if side < 0.0 else "WallRight"
		_own(root, wall)
	var power: LogicDevice = LogicDevice.new()
	power.name = "Power"
	power.stable_id = &"power"
	power.kind = DeviceDefinition.Kind.SOURCE
	power.initial = true
	_own(root, power)
	var field: GravityFieldDevice = GravityFieldDevice.new()
	field.name = "Field"
	field.stable_id = &"field.side"
	field.inputs = [&"power"]
	field.size = Vector3(8, 8, 8)
	field.position = Vector3(0, 2, 0)
	field.rotation_degrees = Vector3(0, 0, -90)
	_own(root, field)
	var scene: PackedScene = PackedScene.new()
	scene.pack(root)
	root.free()
	await _open(scene)
	await _ticks(30)
	var blocked: bool = _player.reorientation_blocked and _player.up_direction.distance_to(Vector3.UP) < 0.001 \
		and _player.is_on_floor()
	results.append(TestOutcome.new("a field turn that would put the capsule into walls is deferred, old gravity kept",
		blocked, "blocked %s up %s" % [_player.reorientation_blocked, _player.up_direction]))
	for label: String in ["WallLeft", "WallRight"]:
		var wall: Node = _scope.get_node("Shaft/" + label)
		wall.get_parent().remove_child(wall)
		wall.queue_free()
	await _ticks(3)
	results.append(TestOutcome.new("the deferred turn completes once there is room",
		not _player.reorientation_blocked and _player.up_direction.distance_to(Vector3.RIGHT) < 0.001,
		"up %s blocked %s" % [_player.up_direction, _player.reorientation_blocked]))
	await _close()
	return results


func _lab_bay() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	await _open(LAB)
	_lab = _scope.get_node("FoundationLab/PuzzleLab") as Node3D
	var button: WallButtonDevice = _lab.get_node("lab_button_gravity") as WallButtonDevice
	var field: GravityFieldDevice = _lab.get_node("lab_field") as GravityFieldDevice
	var cube: CarryRigidBody = _lab.get_node("CubeD") as CarryRigidBody
	var plate: FloorButtonDevice = _lab.get_node("lab_plate_wall") as FloorButtonDevice
	var down: Vector3 = field.zone().direction
	await _ticks(120)
	var resting: bool = cube.sleeping
	var floor_gravity: Vector3 = cube.get_gravity()
	await _stand_facing(button)
	await _ticks(1, Vector2.ZERO, true)
	await _ticks(10)
	var woke: bool = not cube.sleeping
	var field_gravity: Vector3 = cube.get_gravity()
	results.append(TestOutcome.new("powering the field wakes a sleeping cube and replaces its gravity once",
		resting and woke and floor_gravity.is_equal_approx(Vector3(0, -9.8, 0))
		and field_gravity.distance_to(down * field.strength) < 0.01,
		"sleeping %s woke %s gravity %s -> %s" % [resting, woke, floor_gravity, field_gravity]))
	await _ticks(110)
	results.append(TestOutcome.new("the cube falls onto the wall plate and presses it",
		_output(&"lab.plate.wall"), "cube at %s, plate %s" % [cube.global_position, _output(&"lab.plate.wall")]))
	# The player steps into the field away from the plate and turns to stand on the wall.
	var wall_point: Vector3 = field.global_position + down * 1.2 + field.global_basis.z.normalized() * -2.0
	_player.global_position = Vector3(wall_point.x, 0.05, wall_point.z)
	await _ticks(100)
	var up: Vector3 = -down
	results.append(TestOutcome.new("the player turns to the field's up and stands on the wall",
		_player.up_direction.distance_to(up) < 0.001 and _player.is_on_floor() and _player.global_position.y > 0.4,
		"up %s floor %s pos %s" % [_player.up_direction, _player.is_on_floor(), _player.global_position]))
	results.append(TestOutcome.new("the camera frame follows the new up within the comfort rate",
		_camera.frame.y.distance_to(up) < 0.01, str(_camera.frame.y)))
	var along: Vector3 = field.global_basis.z.normalized()
	_camera.look_at(_camera.global_position + along, up)
	var start: Vector3 = _player.global_position
	await _ticks(45, Vector2(0, -1))
	var walked: float = (_player.global_position - start).dot(along)
	results.append(TestOutcome.new("forward input walks along the wall on the new floor",
		walked > 1.5 and _player.is_on_floor() and _player.up_direction.distance_to(up) < 0.001,
		"walked %.2f m" % walked))
	await _ticks(120, Vector2(0, -1))
	await _ticks(90)
	results.append(TestOutcome.new("walking out of the field restores base gravity and the player lands on the floor",
		_player.up_direction.distance_to(Vector3.UP) < 0.001 and _player.is_on_floor() and _player.global_position.y < 0.2,
		"up %s pos %s" % [_player.up_direction, _player.global_position]))
	await _stand_facing(button)
	await _ticks(1, Vector2.ZERO, true)
	await _ticks(120)
	results.append(TestOutcome.new("switching the field off returns the cube to base gravity and releases the plate",
		cube.get_gravity().is_equal_approx(Vector3(0, -9.8, 0)) and not _output(&"lab.plate.wall"),
		"gravity %s cube=%s load=%.2f" % [cube.get_gravity(), cube.global_position, plate.last_load]))
	await _close()
	return results


## Two overlapping powered fields: higher priority wins for bodies (engine area order) and for the player
## (rules); equal priority falls back to the smaller stable ID.
func _priority() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var scene: PackedScene = _overlap_scene(2, 1)
	await _open(scene)
	var cube: RigidBody3D = _scope.get_node("Overlap/Cube") as RigidBody3D
	await _ticks(5)
	var body_gravity: Vector3 = cube.get_gravity()
	var player_field: GravityZone = _scope.gravity().at(_player.center())
	results.append(TestOutcome.new("higher priority wins for bodies and the player alike",
		body_gravity.normalized().distance_to(Vector3.RIGHT) < 0.01 and player_field.id == &"field.b",
		"body %s player %s" % [body_gravity, player_field.id]))
	await _close()
	scene = _overlap_scene(1, 1)
	await _open(scene)
	cube = _scope.get_node("Overlap/Cube") as RigidBody3D
	await _ticks(5)
	body_gravity = cube.get_gravity()
	player_field = _scope.gravity().at(_player.center())
	results.append(TestOutcome.new("equal priority resolves to the smaller ID for bodies and the player alike",
		body_gravity.normalized().distance_to(Vector3.LEFT) < 0.01 and player_field.id == &"field.a",
		"body %s player %s" % [body_gravity, player_field.id]))
	await _close()
	return results


## field.a pulls toward -X, field.b toward +X; both cover the cube and the player.
func _overlap_scene(priority_b: int, priority_a: int) -> PackedScene:
	var root: Node3D = Node3D.new()
	root.name = "Overlap"
	var camera: LookCamera = LookCamera.new()
	camera.name = "Camera"
	_own(root, camera)
	var player: PlayerMotor = PLAYER.instantiate() as PlayerMotor
	player.name = "Player"
	player.position = Vector3(0, 0.05, 2)
	_own(root, player)
	var ground: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(20, 1, 20), Color.GRAY, Vector3(0, -0.5, 0))
	ground.name = "Floor"
	_own(root, ground)
	var power: LogicDevice = LogicDevice.new()
	power.name = "Power"
	power.stable_id = &"power"
	power.kind = DeviceDefinition.Kind.SOURCE
	power.initial = true
	_own(root, power)
	var ids: Array[StringName] = [&"field.a", &"field.b"]
	var priorities: Array[int] = [priority_a, priority_b]
	var turns: Array[float] = [-90.0, 90.0]
	for index: int in range(2):
		var field: GravityFieldDevice = GravityFieldDevice.new()
		field.stable_id = ids[index]
		field.name = String(ids[index]).replace(".", "_")
		field.priority = priorities[index]
		field.inputs = [&"power"]
		field.size = Vector3(6, 6, 6)
		field.position = Vector3(0, 3, 0)
		field.rotation_degrees = Vector3(0, 0, turns[index])
		_own(root, field)
	var cube: RigidBody3D = RigidBody3D.new()
	cube.name = "Cube"
	cube.collision_layer = 2
	cube.collision_mask = 7
	cube.position = Vector3(0, 2, -1)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	cube.add_child(shape)
	_own(root, cube)
	var packed: PackedScene = PackedScene.new()
	packed.pack(root)
	root.free()
	return packed


func _own(root: Node3D, child: Node) -> void:
	root.add_child(child)
	_claim(root, child)


## PackedScene keeps only owned nodes: claim built subtrees, but leave an instanced scene's own children.
func _claim(root: Node3D, node: Node) -> void:
	node.owner = root
	if not node.scene_file_path.is_empty():
		return
	for child: Node in node.get_children():
		_claim(root, child)


func _open(scene: PackedScene) -> void:
	_scope = LevelScope.new()
	_tree.root.add_child(_scope)
	_scope.open(scene, GENERATION)
	var level: Node = _scope.get_child(0)
	_player = level.get_node("Player") as PlayerMotor
	_camera = level.get_node("Camera") as LookCamera
	if scene == LAB:
		_player.global_position = Vector3(0, 0.05, 30)
	await _ticks(20)


func _close() -> void:
	_scope.close()
	await _tree.process_frame


func _stand_facing(device: Node3D) -> void:
	var front: Vector3 = device.global_basis.z.normalized()
	_player.global_position = Vector3(device.global_position.x, 0.05, device.global_position.z) + front * 1.3
	await _ticks(20)
	_camera.look_at(device.global_position + Vector3(0, -0.05, 0) + front * 0.05, _player.up_direction)
	await _ticks(1)


func _output(id: StringName) -> bool:
	var result: PuzzleStepResult = _scope.puzzle().last_result
	return result != null and result.output(id)


func _ticks(count: int, move: Vector2 = Vector2.ZERO, interact: bool = false) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = GENERATION
		frame.move_axis = move
		frame.interact_requested = interact and tick == 0
		_scope.apply_input(frame)
