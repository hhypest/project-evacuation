class_name CarryPhysicsTests
extends TestSuite

const LAB: PackedScene = preload("res://content/levels/foundation_lab.tscn")
const HALF_CUBE: float = BallastCube.HEAVY_EDGE * 0.5

var _scope: LevelScope
var _player: PlayerMotor
var _camera: LookCamera
var _cube: CarryRigidBody
var _tree: SceneTree
var _maximum_speed: float = 0.0
var _maximum_lag: float = 0.0
var _profile: CarryProfile = CarryProfile.new()


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	await _open()
	await _ticks(1, true)
	var grabbed_now: bool = _cube.is_carried() and _cube.freeze
	await _ticks(12)
	results.append(TestOutcome.new("one press grabs at once and the cube sticks to its hold point within 0.2 s",
		grabbed_now and _scope.held_prop_id() == &"lab.cube.medium" and _cube.position.distance_to(_hold()) < 0.05,
		"cube=%s hold=%s" % [_cube.position, _hold()]))
	results.append(TestOutcome.new("the held cube and its carrier ignore each other's collisions",
		_cube in _player.get_collision_exceptions() and _player in _cube.get_collision_exceptions()))
	await _close()
	# A cube that has rested a while sinks a little into the floor in Jolt; the first step toward a low hold
	# point is almost horizontal and must still lift it out instead of leaving it stuck until the break delay.
	await _open()
	_cube.position = Vector3(0, 3, 0)
	await _ticks(100)
	var rest_height: float = _cube.position.y
	_camera.look_at(_cube.global_position)
	await _ticks(1, true)
	await _ticks(12)
	results.append(TestOutcome.new("a cube settled into the floor is lifted out and reaches a low hold point",
		rest_height < HALF_CUBE and _scope.held_prop_id() == &"lab.cube.medium" and _cube.position.distance_to(_hold()) < 0.05,
		"rest=%.4f cube=%s hold=%s" % [rest_height, _cube.position, _hold()]))
	await _close()
	await _open()
	await _ticks(1, true)
	await _ticks(12)
	# An instant 40 degree turn jumps the hold point; the cube catches up within a few ticks.
	_camera.rotation.y += deg_to_rad(40)
	await _ticks(8)
	_maximum_lag = 0.0
	await _ticks(40, false, false, Vector2(1, 0))
	results.append(TestOutcome.new("the held cube follows turning and strafing without trailing behind",
		_scope.held_prop_id() == &"lab.cube.medium" and _cube.position.distance_to(_hold()) < 0.05
		and _maximum_lag < 0.35, "error=%.3f lag=%.3f" % [_cube.position.distance_to(_hold()), _maximum_lag]))
	await _ticks(1, true)
	await _ticks(45)
	results.append(TestOutcome.new("E drops the cube: ordinary body again, collisions with the carrier restored",
		_scope.held_prop_id().is_empty() and not _cube.is_carried() and not _cube.freeze
		and _cube.position.y < 0.8 and _cube not in _player.get_collision_exceptions()))
	await _close()
	var throw_speeds: Array[float] = []
	for kilograms: float in [5.0, 10.0, 40.0]:
		await _open(kilograms)
		await _ticks(30, true)
		var acquired: bool = _scope.held_prop_id() == &"lab.cube.medium"
		var forward: Vector3 = -_camera.global_basis.z
		await _ticks(1, false, true)
		await _ticks(2)
		throw_speeds.append(_cube.linear_velocity.dot(forward))
		results.append(TestOutcome.new("throw releases a %.0f kg cube with finite bounded velocity" % kilograms,
			acquired and _scope.held_prop_id().is_empty() and not _cube.is_carried()
			and _cube.linear_velocity.is_finite() and _cube.linear_velocity.length() < 12.5,
			"velocity=%s" % _cube.linear_velocity))
		await _close()
	results.append(TestOutcome.new("the gameplay throw launches the 5 kg cube faster than the 10 kg cube and bounds both speeds",
		throw_speeds[0] > throw_speeds[1] + 2.0 and throw_speeds[1] > throw_speeds[2] * 1.5 and throw_speeds[2] > 1,
		"speeds=%s" % str(throw_speeds)))
	await _open(80)
	await _ticks(5, true)
	results.append(TestOutcome.new("overweight cube is not acquired", _scope.held_prop_id().is_empty() and not _cube.is_carried()))
	await _close()
	await _open(20, Vector3(0, 0.05, 6))
	await _ticks(5, true)
	results.append(TestOutcome.new("distant cube is not acquired", _scope.held_prop_id().is_empty()))
	await _close()
	await _open()
	_wall(Vector3(0, 1.5, 1.5), Vector3(4, 3, 0.2))
	await _ticks(10)
	await _ticks(5, true)
	results.append(TestOutcome.new("world wall occludes acquisition ray", _scope.held_prop_id().is_empty()))
	await _close()
	await _open()
	_wall(Vector3(0, 1.5, -0.8), Vector3(4, 3, 0.2))
	await _ticks(30, true)
	await _ticks(100, false, false, Vector2(0, -1))
	results.append(TestOutcome.new("carrying into a wall stops the cube at the wall, never through it",
		_scope.held_prop_id() == &"lab.cube.medium" and _cube.position.z > -0.7 + HALF_CUBE - 0.02
		and _cube.position.is_finite(), "cube=%s" % _cube.position))
	# The carrier has walked into the blocked cube (collisions with it are off); dropping it there must not
	# hand an interpenetrating pair to the solver.
	var overlapped: bool = _player.position.z - _player.profile.radius < _cube.position.z + HALF_CUBE
	await _ticks(1, true)
	var kept_apart: bool = _cube in _player.get_collision_exceptions()
	_maximum_speed = 0.0
	var player_before: Vector3 = _player.position
	await _ticks(60, false, false, Vector2(0, 1))
	results.append(TestOutcome.new("dropping a cube the carrier overlaps keeps them apart until they separate",
		overlapped and kept_apart and _cube not in _player.get_collision_exceptions()
		and _player not in _cube.get_collision_exceptions()
		and _player.position.z > player_before.z + 0.5 and _maximum_speed < 8 and _cube.position.is_finite(),
		"player=%s cube=%s speed=%.2f" % [_player.position, _cube.position, _maximum_speed]))
	await _close()
	await _open()
	await _ticks(30, true)
	_camera.rotation.x = deg_to_rad(-89)
	await _ticks(20)
	_maximum_lag = 0.0
	await _ticks(40, false, false, Vector2(1, 0))
	await _ticks(40, false, false, Vector2(0, -1))
	results.append(TestOutcome.new("looking straight down, a 0.75 m cube rides above the floor and follows walking and strafing",
		_scope.held_prop_id() == &"lab.cube.medium" and _cube.position.distance_to(_hold()) < 0.1
		and _maximum_lag < 0.35 and _cube.position.y > HALF_CUBE,
		"error=%.3f lag=%.3f cube=%s" % [_cube.position.distance_to(_hold()), _maximum_lag, _cube.position]))
	await _close()
	await _open()
	await _ticks(30, true)
	_wall(Vector3(0, 2.1, 0.5), Vector3(8, 0.2, 8))
	_camera.rotation.x = deg_to_rad(80)
	await _ticks(40)
	results.append(TestOutcome.new("looking up under a 2 m ceiling keeps the cube held below the ceiling",
		_scope.held_prop_id() == &"lab.cube.medium" and _cube.position.y + HALF_CUBE <= 2.0 + 0.001
		and _cube.position.y + HALF_CUBE > 1.9,
		"cube=%s" % _cube.position))
	await _ticks(40, false, false, Vector2(1, 0))
	var sideways: Vector3 = (_cube.position - _hold()).slide(Vector3.UP)
	results.append(TestOutcome.new("a cube pressed to the ceiling still slides along it while strafing",
		_scope.held_prop_id() == &"lab.cube.medium" and sideways.length() < 0.1 and _cube.position.y + HALF_CUBE <= 2.001,
		"cube=%s hold=%s" % [_cube.position, _hold()]))
	await _close()
	await _open(20.0, Vector3(0, 0.05, 2.6))
	_wall(Vector3(-0.65, 1.5, 0), Vector3(0.2, 3, 6))
	_wall(Vector3(0.65, 1.5, 0), Vector3(0.2, 3, 6))
	await _ticks(30, true)
	var in_corridor: bool = _scope.held_prop_id() == &"lab.cube.medium" and _cube.position.z > 1.5
	_camera.rotation.y += deg_to_rad(55)
	await _ticks(60)
	# Turning 55 degrees aims the hold point into a wall; the cube slides along the walls toward it but stays
	# between them and in front of the carrier.
	var extent: Vector3 = PortalRules.projected_extent(_cube.global_basis, Vector3.ONE * HALF_CUBE)
	results.append(TestOutcome.new("a cube held in a 1.1 m corridor slides along the walls, never into or past them",
		in_corridor and _scope.held_prop_id() == &"lab.cube.medium" and _cube.position.is_finite()
		and absf(_cube.position.x) + extent.x <= 0.56 and _cube.position.z < _player.position.z - 0.15,
		"cube=%s player=%s" % [_cube.position, _player.position]))
	await _close()
	await _open()
	await _ticks(30, true)
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
	await _ticks(45)
	results.append(TestOutcome.new("a cube pulled far from its hold point is dropped after the break delay",
		_scope.held_prop_id().is_empty() and not _cube.is_carried()))
	await _close()
	await _open()
	_player.position = Vector3(0, 1.1, 0)
	await _ticks(30)
	_camera.look_at(_cube.global_position, Vector3.FORWARD)
	await _ticks(4, true)
	results.append(TestOutcome.new("standing on a cube cannot create a carry elevator",
		_scope.held_prop_id().is_empty() and _player.position.y < 1.2))
	await _close()
	await _open()
	await _ticks(30, true)
	_player.position = _cube.position + Vector3.UP * 0.55
	await _ticks(70)
	results.append(TestOutcome.new("the carrier cannot stand on its own held cube",
		_player.position.y < 0.2 and _maximum_speed < 15, "player=%s" % _player.position))
	await _close()
	await _open(5)
	_wall(Vector3(0, 1.5, -1.5), Vector3(5, 3, 0.1))
	await _ticks(30, true)
	_camera.rotation.x = 0.0
	await _ticks(20)
	await _ticks(1, false, true)
	await _ticks(90)
	results.append(TestOutcome.new("CCD throw hits a 10 cm wall without tunnelling",
		_scope.held_prop_id().is_empty() and _cube.continuous_cd and _cube.position.z > -1.1
		and _cube.linear_velocity.is_finite(), "position=%s" % _cube.position))
	await _close()
	await _open()
	await _ticks(30, true)
	var level: Node3D = _scope.get_node("FoundationLab") as Node3D
	level.remove_child(_cube)
	await _ticks(2)
	results.append(TestOutcome.new("removing a live held body cancels its ownership and pending commands",
		_scope.held_prop_id().is_empty() and not _cube.is_carried()))
	await _close()
	_cube.free()
	return results


## Where the controller should be holding the 0.75 m test cube right now.
func _hold() -> Vector3:
	var forward: Vector3 = -_camera.global_basis.z
	var facing: Vector3 = CarryRules.facing(forward, _player.up_direction, forward)
	return CarryRules.hold_point(_player.global_position, _player.up_direction, facing, forward,
		_player.profile.radius, HALF_CUBE, HALF_CUBE, _profile)


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
	_maximum_lag = 0.0
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
		if _cube.is_carried():
			_maximum_lag = maxf(_maximum_lag, _cube.position.distance_to(_hold()))
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
