class_name PlayerMovementTests
extends TestSuite

const LAB: PackedScene = preload("res://content/levels/foundation_lab.tscn")
var _lab: Node3D
var _player: PlayerMotor


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	_open(tree, Vector3(0, 0.05, 10))
	var command: MovementCommand = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 60)
	var move_speed: float = _player.velocity.slide(Vector3.UP).length()
	results.append(TestOutcome.new("Jolt player moves on floor at ordinary speed",
		_player.global_position.z < 5.6 and absf(_player.global_position.y) < 0.05
		and absf(move_speed - 5.1) < 0.1, "position=%s speed=%.3f" % [_player.position, move_speed]))
	command.sprinting = true
	await _ticks(tree, command, 30)
	var sprint_speed: float = _player.velocity.slide(Vector3.UP).length()
	results.append(TestOutcome.new("holding sprint reaches 8 m/s on real contacts",
		absf(sprint_speed - 8.0) < 0.1, "speed=%.3f" % sprint_speed))
	command.sprinting = false
	_player.global_position = Vector3(0, 0.05, 10)
	command.walking = true
	await _ticks(tree, command, 30)
	results.append(TestOutcome.new("walk modifier selects slower speed on real contacts",
		absf(_player.velocity.slide(Vector3.UP).length() - 2.5) < 0.1))
	command.move_axis = Vector2.ZERO
	await _ticks(tree, command, 40)
	results.append(TestOutcome.new("release brakes player without drift",
		_player.velocity.slide(Vector3.UP).length() < 0.02))
	await _close(tree)
	_open(tree, Vector3(0, 0.05, 10))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.jump_requested = true
	await _ticks(tree, command, 1)
	command.jump_requested = false
	var peak: float = 0.0
	for _tick: int in range(60):
		await _ticks(tree, command, 1)
		peak = maxf(peak, _player.position.y)
	results.append(TestOutcome.new("physical jump height and landing match profile tolerance",
		peak > 0.8 and peak < 1.0 and _player.is_on_floor(), "peak=%.3f" % peak))
	await _close(tree)
	_open(tree, Vector3(-7, 0.05, -1))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 80)
	results.append(TestOutcome.new("stairs climb without jump",
		_player.position.z < -7 and _player.position.y > 0.9, "position=%s" % _player.position))
	command.move_axis = Vector2(0, 1)
	await _ticks(tree, command, 80)
	results.append(TestOutcome.new("stairs descend back onto floor",
		_player.position.z > -2 and absf(_player.position.y) < 0.06, "position=%s" % _player.position))
	await _close(tree)
	_open(tree, Vector3(-14, 0.05, -1))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 35)
	var stopped_z: float = _player.position.z
	command.crouching = true
	await _ticks(tree, command, 70)
	command.crouching = false
	command.move_axis = Vector2.ZERO
	await _ticks(tree, command, 10)
	results.append(TestOutcome.new("crouch enters low tunnel and cannot stand through roof",
		stopped_z > -3 and _player.position.z < -3.5 and _player.crouched,
		"position=%s standing_stop=%.3f" % [_player.position, stopped_z]))
	command.crouching = true
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 180)
	command.crouching = false
	command.move_axis = Vector2.ZERO
	await _ticks(tree, command, 10)
	results.append(TestOutcome.new("stance expands only after leaving tunnel",
		not _player.crouched and _player.position.z < -9.5))
	await _close(tree)
	_open(tree, Vector3(7, 0.05, -2))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 65)
	results.append(TestOutcome.new("walkable slope supports upward travel",
		_player.position.z < -7 and _player.position.y > 0.6, "position=%s" % _player.position))
	await _close(tree)
	_open(tree, Vector3(-13, 0.05, -19))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 70)
	var climbed: bool = _player.position.y > 1.8
	command.jump_requested = true
	await _ticks(tree, command, 1)
	results.append(TestOutcome.new("ladder climbs and jump detaches away from face",
		climbed and _player.velocity.z > 0.5 and _player.velocity.y > 0,
		"position=%s velocity=%s" % [_player.position, _player.velocity]))
	await _close(tree)
	_open(tree, Vector3(-13, 0.05, -19))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 70)
	command.move_axis = Vector2(0, 1)
	await _ticks(tree, command, 40)
	results.append(TestOutcome.new("ladder supports controlled descent", _player.position.y < 1.0,
		"position=%s" % _player.position))
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 100)
	results.append(TestOutcome.new("ladder top dismount reaches platform",
		_player.position.y > 2.9 and _player.position.z < -21.2, "position=%s" % _player.position))
	await _close(tree)
	_open(tree, Vector3(30, -2.5, -2))
	command = MovementCommand.new()
	await _ticks(tree, command, 120)
	results.append(TestOutcome.new("idle swimmer passively rises at configured speed in Jolt water volume",
		_player.mode == MovementStep.Mode.SWIM and _player.position.y > -1.7
		and absf(_player.velocity.y - _player.profile.buoyancy_speed) < 0.01,
		"position=%s velocity=%s" % [_player.position, _player.velocity]))
	await _close(tree)
	_open(tree, Vector3(30, -1.5, -2))
	command = MovementCommand.new()
	command.jump_held = true
	await _ticks(tree, command, 18)
	var rose: bool = _player.position.y > -1.3 and _player.mode == MovementStep.Mode.SWIM
	command.jump_held = false
	command.crouching = true
	await _ticks(tree, command, 30)
	results.append(TestOutcome.new("water supports controlled rise and dive",
		rose and _player.velocity.y < -0.5, "position=%s velocity=%s" % [_player.position, _player.velocity]))
	await _close(tree)
	_open(tree, Vector3(25.4, -0.7, -2))
	command = MovementCommand.new()
	command.jump_held = true
	command.move_axis = Vector2(-1, 0)
	await _ticks(tree, command, 80)
	results.append(TestOutcome.new("swimming exits onto pool shore",
		_player.position.x < 24.5 and _player.position.y > -0.1 and _player.is_on_floor(),
		"position=%s" % _player.position))
	await _close(tree)
	_open(tree, Vector3(12, 0.65, 8))
	command = MovementCommand.new()
	await _ticks(tree, command, 70)
	var platform: TestPlatform = _lab.get_node("MovingPlatform") as TestPlatform
	results.append(TestOutcome.new("moving platform carries standing player",
		platform != null and _player.position.x > 12.7
		and absf(_player.position.x - platform.position.x) < 0.3 and _player.is_on_floor(),
		"player=%s platform=%s" % [_player.position, platform.position]))
	await _close(tree)
	_open(tree, Vector3(-2, 0.05, -12.8))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 6)
	command.jump_requested = true
	await _ticks(tree, command, 1)
	command.jump_requested = false
	await _ticks(tree, command, 8)
	command.crouching = true
	await _ticks(tree, command, 50)
	results.append(TestOutcome.new("duck jump clears a ledge above standing jump height",
		_player.position.y > 1.25 and _player.position.z < -14.2 and _player.crouched,
		"position=%s" % _player.position))
	await _close(tree)
	_open(tree, Vector3(14, 0.05, -13))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 65)
	results.append(TestOutcome.new("steep slope is not treated as walkable stairs",
		_player.position.y < 0.3 and _player.position.z > -16, "position=%s" % _player.position))
	await _close(tree)
	_open(tree, Vector3(-10, 0.05, -4))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(-1, -1)
	await _ticks(tree, command, 40)
	results.append(TestOutcome.new("wall contact slides along wall without penetration",
		_player.position.x > -11.32 and _player.position.z < -6, "position=%s" % _player.position))
	await _close(tree)
	_open(tree, Vector3(0, 0.05, 2.2))
	command = MovementCommand.new()
	await _ticks(tree, command, 150)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 60)
	var cube: RigidBody3D = _lab.get_node("TestCube") as RigidBody3D
	results.append(TestOutcome.new("player pushes a dynamic cube with bounded force",
		cube.position.z < -0.25 and cube.linear_velocity.length() < 6.3,
		"cube=%s velocity=%s player=%s player_velocity=%s contacts=%d" % [
			cube.position, cube.linear_velocity, _player.position, _player.velocity, _player.get_slide_collision_count()]))
	await _close(tree)
	_open(tree, Vector3(0, 0.05, 2.2))
	command = MovementCommand.new()
	var heavy: RigidBody3D = _lab.get_node("TestCube") as RigidBody3D
	heavy.mass = 1000.0
	await _ticks(tree, command, 150)
	command.move_axis = Vector2(0, -1)
	await _ticks(tree, command, 60)
	results.append(TestOutcome.new("same bounded force cannot launch a one-tonne prop",
		absf(heavy.position.z) < 0.1, "cube=%s" % heavy.position))
	await _close(tree)
	_open(tree, Vector3(0, 0.05, 10))
	command = MovementCommand.new()
	await _ticks(tree, command, 20)
	command.move_axis = Vector2(1, -1)
	await _ticks(tree, command, 60)
	results.append(TestOutcome.new("physical diagonal speed does not exceed straight speed",
		absf(_player.velocity.slide(Vector3.UP).length() - 5.1) < 0.1))
	command.jump_requested = true
	await _ticks(tree, command, 1)
	command.jump_requested = false
	command.move_axis = Vector2(-1, 0)
	var before_strafe: float = _player.velocity.x
	await _ticks(tree, command, 15)
	results.append(TestOutcome.new("air strafe changes physical velocity while airborne",
		not _player.is_on_floor() and _player.velocity.x < before_strafe - 0.5))
	await _close(tree)
	for jump: bool in [false, true]:
		_open(tree, Vector3(0, 0.05, 10))
		command = MovementCommand.new()
		await _ticks(tree, command, 20)
		var grounded_before: bool = _player.is_on_floor()
		var pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 6, 10))
		_player.portal_place(pose, Vector3(2, 4, 0))
		command.jump_requested = jump
		await _ticks(tree, command, 1)
		results.append(TestOutcome.new("portal placement discards old support and preserves airborne momentum (jump=%s)" % jump,
			grounded_before and _player.mode == MovementStep.Mode.AIR
			and _player.velocity.y > 3.5 and _player.velocity.y < 4.0 and _player.velocity.x > 1.9,
			str(_player.velocity)))
		command.jump_requested = false
		await _ticks(tree, command, 100)
		results.append(TestOutcome.new("destination contacts restore real floor support after placement (jump=%s)" % jump,
			_player.is_on_floor() and _player.mode == MovementStep.Mode.GROUND))
		await _close(tree)
	return results


func _open(tree: SceneTree, at: Vector3) -> void:
	_lab = LAB.instantiate() as Node3D
	tree.root.add_child(_lab)
	_player = _lab.get_node("Player") as PlayerMotor
	_player.global_position = at


func _ticks(tree: SceneTree, command: MovementCommand, count: int) -> void:
	for _tick: int in range(count):
		await tree.physics_frame
		_player.step(command, 1.0 / 60.0)


func _close(tree: SceneTree) -> void:
	tree.root.remove_child(_lab)
	_lab.queue_free()
	await tree.process_frame
