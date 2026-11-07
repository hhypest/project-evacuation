class_name CarryPhysicsTests
extends TestSuite

const LAB: PackedScene = preload("res://content/levels/foundation_lab.tscn")
var _scope: LevelScope
var _player: PlayerMotor
var _camera: LookCamera
var _cube: CarryRigidBody
var _tree: SceneTree
var _maximum_force: float = 0.0
var _maximum_speed: float = 0.0


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	await _open()
	await _ticks(90, true)
	var target: Vector3 = _camera.global_position - _camera.global_basis.z * 2.16
	results.append(TestOutcome.new("Jolt cube acquires, rises and settles near the carry target",
		_scope.held_prop_id() == &"lab.cube.medium" and _cube.position.distance_to(target) < 0.25
		and _cube.linear_velocity.length() < 0.4,
		"cube=%s target=%s velocity=%s" % [_cube.position, target, _cube.linear_velocity]))
	_camera.rotation.y += deg_to_rad(40)
	await _ticks(60)
	await _ticks(40, false, false, Vector2(1, 0))
	target = _camera.global_position - _camera.global_basis.z * 2.16
	results.append(TestOutcome.new("carried cube follows look and player motion through physical forces",
		_scope.held_prop_id() == &"lab.cube.medium" and _cube.position.distance_to(target) < 0.4
		and _maximum_force <= 1200.01 and _maximum_speed < 10,
		"error=%.3f force=%.3f speed=%.3f" % [_cube.position.distance_to(target), _maximum_force, _maximum_speed]))
	await _ticks(1, true)
	await _ticks(45)
	results.append(TestOutcome.new("E release clears ownership and returns the cube to ordinary gravity",
		_scope.held_prop_id().is_empty() and not _cube.is_carried() and _cube.position.y < 0.8))
	await _close()
	var throw_speeds: Array[float] = []
	for kilograms: float in [1.0, 5.0, 40.0]:
		await _open(kilograms)
		await _ticks(75, true)
		var acquired: bool = _scope.held_prop_id() == &"lab.cube.medium" and _maximum_speed < 10
		var forward: Vector3 = -_camera.global_basis.z
		await _ticks(1, false, true)
		await _ticks(2)
		throw_speeds.append(_cube.linear_velocity.dot(forward))
		results.append(TestOutcome.new("physical throw releases %.0f kg cube with finite bounded velocity" % kilograms,
			acquired and _scope.held_prop_id().is_empty() and not _cube.is_carried()
			and _cube.linear_velocity.is_finite() and _cube.linear_velocity.length() < 12.5,
			"velocity=%s" % _cube.linear_velocity))
		await _close()
	results.append(TestOutcome.new("same bounded throw launches 5 kg faster than 40 kg",
		throw_speeds[1] > throw_speeds[2] * 1.5 and throw_speeds[2] > 1,
		"speeds=%s" % str(throw_speeds)))
	await _open(80)
	await _ticks(5, true)
	results.append(TestOutcome.new("overweight physical cube is not acquired", _scope.held_prop_id().is_empty() and not _cube.is_carried()))
	await _close()
	await _open(20, Vector3(0, 0.05, 6))
	await _ticks(5, true)
	results.append(TestOutcome.new("distant physical cube is not acquired", _scope.held_prop_id().is_empty()))
	await _close()
	await _open()
	_wall(Vector3(0, 1.5, 1.5), Vector3(4, 3, 0.2))
	await _ticks(10)
	await _ticks(5, true)
	results.append(TestOutcome.new("world wall occludes acquisition ray", _scope.held_prop_id().is_empty()))
	await _close()
	await _open()
	_wall(Vector3(0, 1.5, -0.8), Vector3(4, 3, 0.2))
	await _ticks(90, true)
	await _ticks(100, false, false, Vector2(0, -1))
	results.append(TestOutcome.new("carry into a wall keeps collisions and bounded motion",
		_cube.position.z > -0.4 and _cube.linear_velocity.is_finite() and _maximum_speed < 10
		and _maximum_force <= 1200.01,
		"cube=%s speed=%.3f force=%.3f" % [_cube.position, _maximum_speed, _maximum_force]))
	await _close()
	await _open()
	_wall(Vector3(0, 2.65, 0.5), Vector3(5, 0.2, 6))
	await _ticks(75, true)
	_camera.rotation.x = deg_to_rad(40)
	await _ticks(80)
	results.append(TestOutcome.new("ceiling obstruction safely releases an impossible hold",
		_scope.held_prop_id().is_empty() and not _cube.is_carried()
		and _cube.position.y < 2.1 and _cube.linear_velocity.is_finite()))
	await _close()
	await _open()
	_wall(Vector3(-0.6, 1.5, 0), Vector3(0.2, 3, 4))
	_wall(Vector3(0.6, 1.5, 0), Vector3(0.2, 3, 4))
	await _ticks(75, true)
	_camera.rotation.y += deg_to_rad(55)
	await _ticks(100)
	results.append(TestOutcome.new("pinched cube does not explode when the target rotates into a corner",
		_cube.position.is_finite() and _cube.linear_velocity.is_finite()
		and _maximum_speed < 10 and _maximum_force <= 1200.01,
		"cube=%s speed=%.3f" % [_cube.position, _maximum_speed]))
	await _close()
	await _open()
	await _ticks(70, true)
	var stale: CarryBodyCommand = CarryBodyCommand.new()
	stale.scope_id = 10
	stale.tick_id = 10000
	stale.releasing = true
	stale.impulse = Vector3.UP * 10000
	var rejected_scope: bool = not _cube.submit(stale)
	stale.scope_id = 11
	stale.tick_id = _cube.last_applied_tick
	results.append(TestOutcome.new("body adapter rejects stale scopes and already applied ticks",
		rejected_scope and not _cube.submit(stale)))
	_cube.global_position = Vector3(0, 1, -8)
	await _ticks(3)
	results.append(TestOutcome.new("external separation breaks the hold without pulling through the room",
		_scope.held_prop_id().is_empty() and not _cube.is_carried()))
	await _close()
	await _open()
	_player.position = Vector3(0, 1.1, 0)
	await _ticks(30)
	_camera.look_at(_cube.global_position, Vector3.FORWARD)
	await _ticks(4, true)
	results.append(TestOutcome.new("standing on a physical cube cannot create a carry elevator",
		_scope.held_prop_id().is_empty() and _player.position.y < 1.2))
	await _close()
	await _open()
	await _ticks(70, true)
	_player.position = _cube.position + Vector3.UP * 0.55
	_camera.look_at(_cube.global_position, Vector3.FORWARD)
	var before_support: float = _player.position.y
	await _ticks(70)
	results.append(TestOutcome.new("landing on an already carried cube breaks the feedback loop",
		_scope.held_prop_id().is_empty() and not _cube.is_carried()
		and _player.position.y < before_support + 0.3 and _maximum_speed < 10))
	await _close()
	await _open(5)
	_wall(Vector3(0, 1.5, -1.5), Vector3(5, 3, 0.1))
	await _ticks(75, true)
	_camera.rotation.x = 0.0
	await _ticks(60)
	await _ticks(1, false, true)
	await _ticks(90)
	results.append(TestOutcome.new("CCD throw hits a 10 cm wall without tunnelling",
		_scope.held_prop_id().is_empty() and _cube.continuous_cd and _cube.position.z > -1.1
		and _cube.linear_velocity.is_finite(), "position=%s" % _cube.position))
	await _close()
	await _open()
	await _ticks(70, true)
	var level: Node3D = _scope.get_node("FoundationLab") as Node3D
	level.remove_child(_cube)
	await _ticks(2)
	results.append(TestOutcome.new("removing a live held body cancels its ownership and pending commands",
		_scope.held_prop_id().is_empty() and not _cube.is_carried()))
	level.add_child(_cube)
	await _close()
	return results


func _open(kilograms: float = 20.0, at: Vector3 = Vector3(0, 0.05, 3)) -> void:
	_scope = LevelScope.new()
	_tree.root.add_child(_scope)
	_scope.open(LAB, 11)
	_player = _scope.get_node("FoundationLab/Player") as PlayerMotor
	_camera = _scope.get_node("FoundationLab/Camera") as LookCamera
	_cube = _scope.get_node("FoundationLab/TestCube") as CarryRigidBody
	_player.position = at
	_cube.position = Vector3(0, 0.55, 0)
	_cube.mass = kilograms
	_maximum_force = 0.0
	_maximum_speed = 0.0
	await _ticks(30)
	_camera.look_at(_cube.global_position)


func _ticks(count: int, interact: bool = false, throwing: bool = false, move: Vector2 = Vector2.ZERO) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = 11
		frame.interact_requested = interact and tick == 0
		frame.throw_requested = throwing and tick == 0
		frame.move_axis = move
		_scope.apply_input(frame)
		_maximum_force = maxf(_maximum_force, _cube.last_force.length())
		_maximum_speed = maxf(_maximum_speed, _cube.linear_velocity.length())


func _wall(at: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 6
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	_scope.get_node("FoundationLab").add_child(body)


func _close() -> void:
	_scope.close()
	await _tree.process_frame
