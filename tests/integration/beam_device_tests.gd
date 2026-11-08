class_name BeamDeviceTests
extends TestSuite
## Jolt-backed checks of the beam bay (SKL-06): real ray against real bodies, cube and player occlusion,
## receiver acceptance angle, power loss and chamber reset.

const LAB: PackedScene = preload("res://content/levels/foundation_lab.tscn")
const GENERATION: int = 22

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
	await _open()
	var button: WallButtonDevice = _lab.get_node("lab_button_beam") as WallButtonDevice
	var emitter: EmitterDevice = _lab.get_node("lab_emitter") as EmitterDevice
	var receiver: ReceiverDevice = _lab.get_node("lab_receiver") as ReceiverDevice
	var door: DoorDevice = _lab.get_node("lab_door_beam") as DoorDevice
	var cube: CarryRigidBody = _lab.get_node("CubeC") as CarryRigidBody
	var parked: Vector3 = cube.global_position
	results.append(TestOutcome.new("an unpowered emitter shows no beam and the receiver stays dark",
		not emitter.powered and not _output(&"lab.receiver") and not door.is_open()))
	await _stand_facing(button)
	await _ticks(1, true)
	await _ticks(90)
	var face: float = emitter.muzzle().distance_to(receiver.global_position) - ReceiverDevice.PLATE.z * 0.5
	results.append(TestOutcome.new("E on the toggle powers the emitter; the traced beam reaches the receiver face",
		emitter.powered and absf(emitter.beam_length - face) < 0.05, "length %.3f, face %.3f" % [emitter.beam_length, face]))
	results.append(TestOutcome.new("an accepted beam switches the receiver and opens its door",
		_output(&"lab.receiver") and door.is_open()))
	var middle: Vector3 = (emitter.muzzle() + receiver.global_position) * 0.5
	_place(cube, Vector3(middle.x, 0.55, middle.z))
	await _ticks(10)
	var blocked_length: float = emitter.beam_length
	await _ticks(110)
	results.append(TestOutcome.new("a cube in the path stops the beam at the cube and releases the receiver",
		blocked_length < face * 0.6 and not _output(&"lab.receiver") and not door.is_open(),
		"length %.3f, receiver %s, door %.2f" % [blocked_length, _output(&"lab.receiver"), door.openness]))
	_place(cube, parked)
	await _ticks(20)
	results.append(TestOutcome.new("removing the cube restores the hit", _output(&"lab.receiver")))
	_player.global_position = Vector3(middle.x, 0.05, middle.z)
	await _ticks(10)
	results.append(TestOutcome.new("the player standing in the beam occludes it", not _output(&"lab.receiver")))
	# Back to the toggle, between the partition and the beam.
	await _stand_facing(button)
	await _ticks(10)
	var restored: bool = _output(&"lab.receiver")
	var authored: Basis = receiver.global_basis
	receiver.global_basis = authored * Basis(Vector3.UP, deg_to_rad(60.0))
	await _ticks(20)
	var oblique_hit: bool = emitter.beam_length < face + 0.4
	results.append(TestOutcome.new("a receiver turned 60 degrees is still hit but rejects the beam (30 degree cone)",
		restored and oblique_hit and not _output(&"lab.receiver"), "length %.3f" % emitter.beam_length))
	receiver.global_basis = authored
	await _ticks(20)
	var back_on: bool = _output(&"lab.receiver")
	await _stand_facing(button)
	await _ticks(1, true)
	await _ticks(10)
	results.append(TestOutcome.new("switching the emitter off hides the beam and releases the receiver",
		back_on and not emitter.powered and not _output(&"lab.receiver")))
	await _stand_facing(button)
	await _ticks(1, true)
	await _ticks(10)
	var powered_again: bool = emitter.powered and _output(&"lab.receiver")
	_scope.puzzle().reset()
	await _ticks(2)
	results.append(TestOutcome.new("chamber reset returns the emitter and receiver to their authored dark state",
		powered_again and not emitter.powered and not _scope.puzzle().network.output(&"lab.receiver")))
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


func _place(body: RigidBody3D, at: Vector3) -> void:
	body.global_position = at
	body.global_basis = Basis.IDENTITY
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false


func _stand_facing(device: Node3D) -> void:
	var front: Vector3 = device.global_basis.z.normalized()
	_player.global_position = Vector3(device.global_position.x, 0.05, device.global_position.z) + front * 1.3
	await _ticks(20)
	_camera.look_at(device.global_position + Vector3(0, -0.05, 0) + front * 0.05)
	await _ticks(1)


func _output(id: StringName) -> bool:
	var result: PuzzleStepResult = _scope.puzzle().last_result
	return result != null and result.output(id)


func _ticks(count: int, interact: bool = false) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = GENERATION
		frame.interact_requested = interact and tick == 0
		_scope.apply_input(frame)
