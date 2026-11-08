class_name PuzzleDeviceTests
extends TestSuite
## Jolt-backed checks of the device lab: real contacts, real player, real doors.

const LAB: PackedScene = preload("res://content/levels/foundation_lab.tscn")
const GENERATION: int = 21

var _tree: SceneTree
var _scope: LevelScope
var _player: PlayerMotor
var _camera: LookCamera
var _lab: Node3D
var _max_cube_speed: float = 0.0


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	await _open()
	var plate: FloorButtonDevice = _node("lab_plate") as FloorButtonDevice
	var door: DoorDevice = _node("lab_door_plate") as DoorDevice
	var cube_a: CarryRigidBody = _node("CubeA") as CarryRigidBody
	var cube_b: CarryRigidBody = _node("CubeB") as CarryRigidBody
	var plate_top: Vector3 = plate.global_position + Vector3(0, 0.1, 0)
	_place(cube_a, plate_top + Vector3(0, 0.5, 0))
	await _ticks(60)
	results.append(TestOutcome.new("one 5 kg cube on an 8 kg plate leaves the door closed",
		not _output(&"lab.plate") and absf(plate.last_load - 5.0) < 0.01 and door.openness < 0.01,
		"load=%.2f" % plate.last_load))
	_place(cube_b, plate_top + Vector3(0, 1.52, 0))
	await _ticks(90)
	results.append(TestOutcome.new("a stacked second cube presses the plate; each body is counted once",
		_output(&"lab.plate") and absf(plate.last_load - 10.0) < 0.01 and door.is_open(),
		"load=%.2f open=%.2f" % [plate.last_load, door.openness]))
	_place(cube_b, Vector3(14, 0.6, 30))
	await _ticks(90)
	results.append(TestOutcome.new("removing the top cube releases below 6 kg and the door closes",
		not _output(&"lab.plate") and door.openness < 0.01, "load=%.2f open=%.2f" % [plate.last_load, door.openness]))
	_place(cube_a, Vector3(14, 0.6, 28))
	_player.global_position = plate_top + Vector3(0, 0.02, 0)
	await _ticks(60)
	results.append(TestOutcome.new("the player standing on the plate presses it",
		_output(&"lab.plate") and door.is_open() and plate.last_load >= 80.0, "load=%.2f" % plate.last_load))
	_place(cube_a, door.global_position + Vector3(0, 0.55, 0))
	_max_cube_speed = 0.0
	await _ticks(10)
	var parked: Vector3 = cube_a.global_position
	_player.global_position = plate_top + Vector3(-3, 0, -2)
	await _ticks(90, cube_a)
	results.append(TestOutcome.new("a released door never closes onto a cube in the doorway",
		not _output(&"lab.plate") and door.blocked and door.openness > 0.99 and _max_cube_speed < 1.0
		and cube_a.global_position.distance_to(parked) < 0.3,
		"open=%.2f speed=%.2f moved=%.2f" % [door.openness, _max_cube_speed, cube_a.global_position.distance_to(parked)]))
	_place(cube_a, Vector3(14, 0.6, 28))
	await _ticks(60)
	results.append(TestOutcome.new("the door closes once the doorway is clear", door.openness < 0.01 and not door.blocked))
	await _close()

	await _open()
	var timed: WallButtonDevice = _node("lab_button_timed") as WallButtonDevice
	var timed_door: DoorDevice = _node("lab_door_timed") as DoorDevice
	await _stand_facing(timed, 1.3)
	await _ticks(1, null, true)
	results.append(TestOutcome.new("E on a wall button uses it instead of trying to carry",
		_output(&"lab.button.timed") and _scope.held_prop_id().is_empty()))
	await _ticks(60)
	var opened: bool = timed_door.is_open()
	# 4 s hold (240 ticks from the press) plus 0.5 s for the leaves to close.
	await _ticks(225)
	results.append(TestOutcome.new("timed wall button opens its door and releases after 4 s",
		opened and not _output(&"lab.button.timed") and timed_door.openness < 0.01))
	var toggle: WallButtonDevice = _node("lab_button_toggle") as WallButtonDevice
	await _stand_facing(toggle, 1.3)
	await _ticks(1, null, true)
	await _ticks(40)
	var toggled_on: bool = _output(&"lab.button.toggle") and (_node("lab_door_toggle") as DoorDevice).is_open()
	await _ticks(1, null, true)
	await _ticks(40)
	results.append(TestOutcome.new("toggle wall button flips its door on each use",
		toggled_on and not _output(&"lab.button.toggle") and (_node("lab_door_toggle") as DoorDevice).openness < 0.01))
	await _ticks(1, null, true)
	var set_button: WallButtonDevice = _node("lab_button_set") as WallButtonDevice
	await _stand_facing(set_button, 1.3)
	await _ticks(1, null, true)
	await _ticks(30)
	var before_delay: bool = _output(&"lab.and")
	await _ticks(50)
	results.append(TestOutcome.new("set latch passes a 1 s delay and AND with the toggle opens the logic door",
		_output(&"lab.latch") and not before_delay and _output(&"lab.and")))
	_scope.puzzle().reset()
	results.append(TestOutcome.new("chamber reset returns latch, delay and toggle to authored state",
		not _scope.puzzle().network.output(&"lab.latch") and not _scope.puzzle().network.output(&"lab.button.toggle")))
	var cube: CarryRigidBody = _node("CubeA") as CarryRigidBody
	_player.global_position = cube.global_position + Vector3(0, -0.5, -2.2)
	await _ticks(20)
	_camera.look_at(cube.global_position)
	await _ticks(60, null, true)
	results.append(TestOutcome.new("E still carries a cube when no button is under the view",
		_scope.held_prop_id() == &"lab.cube.small_a"))
	await _close()
	return results


func _open() -> void:
	_scope = LevelScope.new()
	_tree.root.add_child(_scope)
	_scope.open(LAB, GENERATION)
	_player = _scope.get_node("FoundationLab/Player") as PlayerMotor
	_camera = _scope.get_node("FoundationLab/Camera") as LookCamera
	_lab = _scope.get_node("FoundationLab/PuzzleLab") as Node3D
	_player.global_position = Vector3(0, 0.05, 30)
	await _ticks(20)


func _close() -> void:
	_scope.close()
	await _tree.process_frame


func _node(label: String) -> Node:
	return _lab.get_node(label)


func _place(body: RigidBody3D, at: Vector3) -> void:
	body.global_position = at
	body.global_basis = Basis.IDENTITY
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false


func _stand_facing(device: Node3D, height: float) -> void:
	var front: Vector3 = device.global_basis.z.normalized()
	_player.global_position = Vector3(device.global_position.x, 0.05, device.global_position.z) + front * 1.3
	await _ticks(20)
	_camera.look_at(device.global_position + Vector3(0, -0.05, 0) + front * 0.05)
	await _ticks(1)


func _output(id: StringName) -> bool:
	var result: PuzzleStepResult = _scope.puzzle().last_result
	return result != null and result.output(id)


func _ticks(count: int, watched: RigidBody3D = null, interact: bool = false) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = GENERATION
		frame.interact_requested = interact and tick == 0
		_scope.apply_input(frame)
		if watched != null:
			_max_cube_speed = maxf(_max_cube_speed, watched.linear_velocity.length())
