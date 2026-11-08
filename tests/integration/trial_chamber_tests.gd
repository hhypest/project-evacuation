class_name TrialChamberTests
extends TestSuite
## Both easy trials are solved with the real mechanics and walked through to the exit; every catalog
## level opens with a valid device network and gravity setup.

const CATALOG: LevelCatalog = preload("res://content/definitions/level_catalog.tres")
const GENERATION: int = 24

var _tree: SceneTree
var _scope: LevelScope
var _player: PlayerMotor
var _camera: LookCamera
var _level: Node3D


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	var opened: PackedStringArray = PackedStringArray()
	for index: int in range(CATALOG.entries.size()):
		if await _open(CATALOG.scene(index)):
			opened.append(CATALOG.entries[index].title)
		await _close()
	results.append(TestOutcome.new("every menu level opens with a valid device network and gravity fields",
		opened.size() == 3, ", ".join(opened)))
	results.append_array(await _trial_logic())
	results.append_array(await _trial_beam_gravity())
	return results


func _trial_logic() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	await _open(CATALOG.scene(1))
	var plate_a: Node3D = _node("t1_plate_a")
	_place(_node("CubeA") as RigidBody3D, plate_a.global_position + Vector3(0, 0.65, 0))
	await _ticks(40)
	var door_a: bool = _output(&"t1.door.a")
	var through_a: bool = await _walk_to(Vector3(0, 0.05, -4.5), -10.0)
	results.append(TestOutcome.new("trial 1 room 1: the cube on the plate opens the door and the player walks through",
		door_a and through_a, "door %s, player z %.2f" % [door_a, _player.global_position.z]))
	var plate_b: Node3D = _node("t1_plate_b")
	_place(_node("CubeB") as RigidBody3D, plate_b.global_position + Vector3(0, 0.65, 0))
	await _ticks(20)
	var plate_only: bool = _output(&"t1.door.b")
	await _press(_node("t1_button_timer"))
	await _ticks(10)
	var both: bool = _output(&"t1.door.b")
	var through_b: bool = await _walk_to(Vector3(0, 0.05, -16.5), -22.0)
	results.append(TestOutcome.new("trial 1 room 2: plate alone keeps the door shut; plate AND timer open it in time",
		not plate_only and both and through_b, "plate only %s, both %s, z %.2f" % [plate_only, both, _player.global_position.z]))
	await _press(_node("t1_button_set"))
	await _ticks(60)
	var early: bool = _output(&"t1.door.c")
	await _ticks(90)
	var late: bool = _output(&"t1.door.c")
	await _press(_node("t1_button_reset"))
	await _ticks(150)
	var cleared: bool = _output(&"t1.door.c")
	await _press(_node("t1_button_set"))
	await _ticks(150)
	var through_c: bool = await _walk_to(Vector3(0, 0.05, -28.5), -36.0)
	results.append(TestOutcome.new("trial 1 room 3: the latch opens the door after 2 s, R closes it, the exit is reached",
		not early and late and not cleared and through_c,
		"1 s %s, 2.5 s %s, after R %s, z %.2f" % [early, late, cleared, _player.global_position.z]))
	_scope.puzzle().reset()
	await _ticks(2)
	results.append(TestOutcome.new("trial 1 reset closes every door",
		not _scope.puzzle().network.output(&"t1.door.a") and not _scope.puzzle().network.output(&"t1.door.c")))
	await _close()
	return results


func _trial_beam_gravity() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	await _open(CATALOG.scene(2))
	await _ticks(30)
	var emitter: EmitterDevice = _node("t2_emitter") as EmitterDevice
	var blocked: bool = emitter.powered and not _output(&"t2.receiver") and not _output(&"t2.door.a")
	_place(_node("CubeA") as RigidBody3D, Vector3(2.5, 0.55, -1.5))
	await _ticks(30)
	var freed: bool = _output(&"t2.door.a")
	var through_a: bool = await _walk_to(Vector3(0, 0.05, -7.5), -12.0)
	results.append(TestOutcome.new("trial 2 room 1: the cube blocks the beam; moving it opens the door",
		blocked and freed and through_a, "blocked %s, freed %s, z %.2f" % [blocked, freed, _player.global_position.z]))
	await _press(_node("t2_button_drop"))
	await _ticks(150)
	var dropped: bool = _output(&"t2.plate.wall") and _output(&"t2.door.b")
	var through_b: bool = await _walk_to(Vector3(-2.0, 0.05, -21.0), -25.5)
	results.append(TestOutcome.new("trial 2 room 2: the field drops the cube onto the wall plate and opens the door",
		dropped and through_b, "plate %s, z %.2f" % [_output(&"t2.plate.wall"), _player.global_position.z]))
	await _press(_node("t2_button_climb"))
	_player.global_position = Vector3(-2.0, 0.05, -27.5)
	await _ticks(100)
	var on_wall: bool = _player.up_direction.distance_to(Vector3.RIGHT) < 0.001 and _player.is_on_floor()
	_camera.look_at(_camera.global_position + Vector3.UP, _player.up_direction)
	for _tick: int in range(120):
		if _player.global_position.y >= 4.0:
			break
		await _ticks(1, Vector2(0, -1))
	var height: float = _player.global_position.y
	_camera.look_at(_camera.global_position + Vector3.FORWARD, _player.up_direction)
	await _ticks(60, Vector2(0, -1))
	await _ticks(60)
	var on_ledge: bool = _player.up_direction.distance_to(Vector3.UP) < 0.001 and _player.is_on_floor() \
		and _player.global_position.y > 2.9 and _player.global_position.z < -31.0
	results.append(TestOutcome.new("trial 2 room 3: the player walks up the wall and steps off onto the ledge",
		on_wall and height >= 4.0 and on_ledge,
		"wall %s, climbed to %.2f, now %s up %s" % [on_wall, height, _player.global_position, _player.up_direction]))
	await _close()
	return results


func _open(scene: PackedScene) -> bool:
	_scope = LevelScope.new()
	_tree.root.add_child(_scope)
	var ok: bool = _scope.open(scene, GENERATION)
	if not ok:
		return false
	_level = _scope.get_child(0) as Node3D
	_player = _level.get_node("Player") as PlayerMotor
	_camera = _level.get_node("Camera") as LookCamera
	await _ticks(20)
	return true


func _close() -> void:
	if is_instance_valid(_scope) and _scope.get_parent() != null:
		_scope.close()
	await _tree.process_frame


func _node(label: String) -> Node3D:
	return _level.find_child(label, true, false) as Node3D


func _place(body: RigidBody3D, at: Vector3) -> void:
	body.global_position = at
	body.global_basis = Basis.IDENTITY
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false


func _press(device: Node3D) -> void:
	var front: Vector3 = device.global_basis.z.normalized()
	_player.global_position = Vector3(device.global_position.x, 0.05, device.global_position.z) + front * 1.3
	await _ticks(15)
	_camera.look_at(device.global_position + Vector3(0, -0.05, 0) + front * 0.05, Vector3.UP)
	await _ticks(1)
	await _ticks(1, Vector2.ZERO, true)


## Walks forward along -Z from a start point; true once the player passes target_z.
func _walk_to(start: Vector3, target_z: float) -> bool:
	_player.global_position = start
	await _ticks(10)
	_camera.look_at(_camera.global_position + Vector3.FORWARD, Vector3.UP)
	for _tick: int in range(240):
		if _player.global_position.z < target_z:
			return true
		await _ticks(1, Vector2(0, -1))
	return false


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
