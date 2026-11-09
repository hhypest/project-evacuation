class_name CarryPlacementTests
extends TestSuite
## ADR-0012, placement: the silhouette and exact set-down on a floor button and on other cubes, on Jolt,
## and the cube ladder to a 2.2 m ledge in the stacking lab.

const LAB: PackedScene = preload("res://content/levels/stacking_lab.tscn")
const EDGE: float = StackingLabBuilder.CUBE_EDGE
var _tree: SceneTree
var _scope: LevelScope
var _player: PlayerMotor
var _camera: LookCamera
var _ghost: CarryGhost
var _plate: FloorButtonDevice
var _cubes: Array[CarryRigidBody] = []


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	await _open()
	var plate_top: Vector3 = _plate.plate.top_center(Vector3.UP)
	await _grab(_cubes[0])
	var holding: bool = _scope.held_prop_id() == &"stack.cube.0"
	await _aim_from(Vector3(plate_top.x, 0.05, plate_top.z + 2.1), plate_top)
	var ghost_on_plate: bool = _ghost.visible and _ghost.global_position.distance_to(
		plate_top + Vector3.UP * (EDGE * 0.5 + 0.01)) < 0.001
	results.append(TestOutcome.new("a held cube aimed at a floor button shows its silhouette centred on the plate",
		holding and ghost_on_plate, "ghost=%s visible=%s plate=%s" % [_ghost.global_position, _ghost.visible, plate_top]))
	await _ticks(1, true)
	await _ticks(60)
	var placed: CarryRigidBody = _cubes[0]
	var offset: Vector3 = (placed.global_position - plate_top).slide(Vector3.UP)
	results.append(TestOutcome.new("E sets the cube down centred and square on the plate, which it presses",
		_scope.held_prop_id().is_empty() and not placed.is_carried() and offset.length() < 0.02
		and placed.global_basis.y.normalized().dot(Vector3.UP) > 0.999
		and absf(placed.global_position.y - (plate_top.y + EDGE * 0.5)) < 0.03 and _plate.last_load >= 10.0
		and not _ghost.visible,
		"offset=%.4f y=%.3f load=%.1f" % [offset.length(), placed.global_position.y, _plate.last_load]))
	await _grab(_cubes[1])
	var lower_top: Vector3 = placed.global_position + Vector3.UP * EDGE * 0.5
	await _aim_from(Vector3(lower_top.x, 0.05, lower_top.z + 2.1), lower_top)
	var ghost_on_cube: bool = _ghost.visible and _ghost.global_basis.y.normalized().dot(Vector3.UP) > 0.999 \
		and (_ghost.global_position - lower_top).slide(Vector3.UP).length() < 0.001
	await _ticks(1, true)
	await _ticks(60)
	var upper: CarryRigidBody = _cubes[1]
	var resting: Vector3 = upper.global_position
	await _ticks(120)
	var stacked: Vector3 = upper.global_position - placed.global_position
	results.append(TestOutcome.new("a cube aimed at another cube is set squarely on top and the stack stays put",
		ghost_on_cube and stacked.slide(Vector3.UP).length() < 0.02 and absf(stacked.y - EDGE) < 0.03
		and upper.global_position.distance_to(resting) < 0.01 and _plate.last_load >= 20.0,
		"stacked=%s drift=%.4f load=%.1f" % [stacked, upper.global_position.distance_to(resting), _plate.last_load]))
	await _grab(_cubes[2])
	var side: Vector3 = placed.global_position + Vector3(0, 0, EDGE * 0.5)
	await _aim_from(Vector3(side.x, 0.05, side.z + 2.0), side)
	var hidden_on_taken: bool = not _ghost.visible
	var stack_top: Vector3 = upper.global_position + Vector3.UP * EDGE * 0.5
	await _aim_from(Vector3(stack_top.x, 0.05, stack_top.z + 2.0), stack_top)
	results.append(TestOutcome.new("a support whose top is taken shows no silhouette; the top of the stack does",
		hidden_on_taken and _ghost.visible))
	await _aim_from(Vector3(3.0, 0.05, 2.0), Vector3(3.0, 0.0, 0.0))
	var hidden_on_floor: bool = not _ghost.visible
	await _ticks(1, true)
	await _ticks(60)
	results.append(TestOutcome.new("aimed at bare floor there is no silhouette and E drops the cube as before",
		hidden_on_floor and _scope.held_prop_id().is_empty() and not _cubes[2].is_carried()
		and _cubes[2].global_position.y < EDGE))
	await _close()
	await _open()
	_cubes[0].global_position = Vector3(0, EDGE * 0.5 + 0.02, 0)
	await _ticks(40)
	await _grab(_cubes[1])
	await _aim_from(Vector3(0, 0.05, 1.6), _cubes[0].global_position + Vector3.UP * EDGE * 0.5)
	var shown_beside: bool = _ghost.visible
	_player.global_position = Vector3(0, EDGE + 0.05, 0)
	await _ticks(40)
	var standing: bool = _player.is_on_floor() and _player.global_position.y > EDGE - 0.05
	_camera.global_basis = Basis(Vector3.RIGHT, deg_to_rad(-85))
	await _ticks(3)
	results.append(TestOutcome.new("no silhouette on the cube the carrier stands on: the slot is where they are",
		shown_beside and standing and _scope.held_prop_id() == &"stack.cube.1" and not _ghost.visible,
		"beside=%s player=%s held=%s visible=%s" % [shown_beside, _player.global_position, _scope.held_prop_id(),
			_ghost.visible]))
	await _close()
	await _open()
	var x: float = StackingLabBuilder.LEDGE_X
	var front: float = StackingLabBuilder.LEDGE_FRONT
	_cubes[0].global_position = Vector3(x, EDGE * 0.5 + 0.01, front + EDGE * 0.5 + 0.03)
	_cubes[1].global_position = Vector3(x, EDGE * 1.5 + 0.03, front + EDGE * 0.5 + 0.03)
	_cubes[2].global_position = Vector3(x, EDGE * 0.5 + 0.01, front + EDGE * 1.5 + 0.4)
	await _ticks(90)
	_player.global_position = Vector3(x, 0.05, 0.5)
	_camera.global_basis = Basis.IDENTITY
	await _ticks(10)
	var top_cube_before: Vector3 = _cubes[1].global_position
	var climbed_at: int = -1
	for tick: int in range(360):
		await _ticks(1, false, Vector2(0, -1), true)
		if _player.global_position.y > StackingLabBuilder.LEDGE_HEIGHT - 0.05 and _player.global_position.z < front - 0.3:
			climbed_at = tick
			break
	results.append(TestOutcome.new("a ladder of three 0.75 m cubes climbs to the 2.2 m ledge: cube, stack, ledge",
		climbed_at >= 0 and _cubes[1].global_position.distance_to(top_cube_before) < 0.25,
		"ticks=%d player=%s top_cube_moved=%.3f" % [climbed_at, _player.global_position,
			_cubes[1].global_position.distance_to(top_cube_before)]))
	await _close()
	return results


func _open() -> void:
	_scope = LevelScope.new()
	_tree.root.add_child(_scope)
	_scope.open(LAB, 21)
	var level: Node3D = _scope.get_node("StackingLab") as Node3D
	_player = level.get_node("Player") as PlayerMotor
	_camera = level.get_node("Camera") as LookCamera
	_ghost = level.get_node("CarryGhost") as CarryGhost
	_plate = level.get_node(ChamberBuilder.node_name(&"stack.plate")) as FloorButtonDevice
	_cubes.clear()
	for index: int in range(3):
		_cubes.append(level.get_node("Cube%d" % index) as CarryRigidBody)
	await _ticks(30)


## Walks up to a resting cube and picks it up.
func _grab(cube: CarryRigidBody) -> void:
	await _aim_from(cube.global_position + Vector3(0, -cube.global_position.y + 0.05, 1.6), cube.global_position)
	await _ticks(1, true)
	await _ticks(10)


## Stands the carrier at feet and turns the view at point; the held cube follows for a few ticks.
func _aim_from(feet: Vector3, point: Vector3) -> void:
	_player.global_position = feet
	await _ticks(2)
	_camera.look_at(point)
	await _ticks(6)
	_camera.look_at(point)
	await _ticks(1)


func _ticks(count: int, interact: bool = false, move: Vector2 = Vector2.ZERO, jumping: bool = false) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = 21
		frame.interact_requested = interact and tick == 0
		frame.move_axis = move
		frame.jump_requested = jumping
		frame.jump_held = jumping
		_scope.apply_input(frame)


func _close() -> void:
	_scope.close()
	await _tree.process_frame
