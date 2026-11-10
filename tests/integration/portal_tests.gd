class_name PortalTests
extends TestSuite
## SKL-08 on real Jolt bodies: off-axis portal camera, transfer with rotated velocity, high speed, return,
## no ping-pong, occupied exit and power off.

const LAB: PackedScene = preload("res://content/levels/portal_lab.tscn")
const GENERATION: int = 25

var _tree: SceneTree
var _scope: LevelScope
var _lab: Node3D
var _pair: PortalPairDevice


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	_scope = LevelScope.new()
	_tree.root.add_child(_scope)
	_scope.open(LAB, GENERATION)
	_lab = _scope.get_child(0) as Node3D
	(_lab.get_node("Player") as Node3D).global_position = Vector3(0, 0.05, 8.5)
	_pair = _lab.get_node("portal_pair") as PortalPairDevice
	await _ticks(10)
	results.append(_frustum())
	var a: PortalPlane = _pair.state().a
	var b: PortalPlane = _pair.state().b
	var cube: CarryRigidBody = _lab.get_node("CubeA") as CarryRigidBody
	var before: int = _scope.portals().transfers.size()
	_launch(cube, a, 0.9, 6.0)
	var speed_in: float = 0.0
	var arrived: bool = false
	for _tick: int in range(60):
		speed_in = cube.linear_velocity.length()
		await _ticks(1)
		if _scope.portals().transfers.size() > before:
			arrived = true
			break
	var local: Vector3 = b.local(cube.global_position)
	var speed_out: float = cube.linear_velocity.length()
	var direction: float = (b.transform.basis.inverse() * cube.linear_velocity).normalized().z
	results.append(TestOutcome.new("a cube sent into A leaves B in front of it, velocity turned to B's front, speed kept",
		arrived and local.z > 0.0 and direction > 0.95 and absf(speed_out - speed_in) < 0.3,
		"local %s, speed %.2f -> %.2f, along %.2f" % [local, speed_in, speed_out, direction]))
	await _ticks(60)
	results.append(TestOutcome.new("the exit guard prevents an immediate return (one crossing, one transfer)",
		_scope.portals().transfers.size() == before + 1, str(_scope.portals().transfers.size() - before)))
	before = _scope.portals().transfers.size()
	_launch(cube, b, 0.9, 6.0)
	var back: bool = await _until_transfer(before, 60)
	results.append(TestOutcome.new("sending the cube into B returns it in front of A",
		back and a.local(cube.global_position).z > 0.0, str(a.local(cube.global_position))))
	before = _scope.portals().transfers.size()
	_launch(cube, a, 1.5, 25.0)

	var fast: bool = await _until_transfer(before, 20)
	results.append(TestOutcome.new("a 25 m/s cube is transferred, not tunnelled past the plane",
		fast and b.local(cube.global_position).z > -0.1 and a.local(cube.global_position).z > -1.0,
		"at B %s" % b.local(cube.global_position)))
	await _ticks(90)
	# Occupied exit: a 20 kg cube parked in front of B; the sent cube must stay on A's side.
	var blocker: CarryRigidBody = _lab.get_node("CubeHeavy") as CarryRigidBody
	_place(blocker, b.transform * Vector3(0, -0.65, 0.55), Vector3.ZERO)
	await _ticks(20)
	before = _scope.portals().transfers.size()
	_launch(cube, a, 0.9, 6.0)
	await _until_transfer(before, 60)
	var refused: bool = _pair.surface_a.blocked or (_scope.portals().transfers.size() > before and _scope.portals().transfers.back().blocked)
	await _ticks(10)
	results.append(TestOutcome.new("an occupied exit refuses the transfer and keeps the cube in front of A",
		refused and a.local(cube.global_position).z >= 0.49 and cube.global_position.distance_to(b.transform.origin) > 3.0,
		"refused %s, at A %s" % [refused, a.local(cube.global_position)]))
	_place(blocker, Vector3(0.5, 0.55, 3.0), Vector3.ZERO)
	await _press_power()
	await _ticks(5)
	before = _scope.portals().transfers.size()
	_launch(cube, a, 0.9, 6.0)
	await _ticks(60)
	results.append(TestOutcome.new("with the pair unpowered the cube passes the real opening without transfer",
		not _pair.state().powered and _scope.portals().transfers.size() == before and a.local(cube.global_position).z < -0.6,
		"powered %s, at A %s" % [_pair.state().powered, a.local(cube.global_position)]))
	_scope.close()
	await _tree.process_frame
	return results


## A screen-space portal must preserve the viewer's rays after the complete rigid transform.
func _frustum() -> TestOutcome:
	var surface: PortalSurface = _pair.surface_a
	var viewer: Transform3D = Transform3D(Basis(Vector3.UP, 0.4) * Basis(Vector3.RIGHT, -0.15), Vector3(-3.2, 1.7, 2.6))
	var source: Camera3D = _lab.get_node("Camera") as Camera3D
	source.global_transform = viewer
	surface.place_camera(viewer)
	var exit: Transform3D = _pair.surface_b.global_transform
	var size: Vector2 = Vector2(surface.viewport.size)
	var screen: Vector2 = source.get_viewport().get_visible_rect().size
	var worst: float = 0.0
	var corners: Array[Vector2] = [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]
	for corner: Vector2 in corners:
		# A's +X maps to B's -X: image left is the exit's +X side.
		var world: Vector3 = exit * Vector3(-corner.x * surface.half_size.x, corner.y * surface.half_size.y, 0)
		var pixel: Vector2 = surface.camera.unproject_position(world)
		var original: Vector3 = PortalMath.map_point(exit, surface.global_transform, world)
		var expected: Vector2 = source.unproject_position(original) / screen
		worst = maxf(worst, (pixel / size).distance_to(expected))
	return TestOutcome.new("native portal pixels follow the same projected rays as the viewer",
		worst < 0.0001 and surface.camera.global_transform.is_equal_approx(PortalMath.map_transform(surface.global_transform, exit, viewer)),
		"normalised projection error %.6f" % worst)


func _launch(body: RigidBody3D, plane: PortalPlane, distance: float, speed: float) -> void:
	# Airborne through the middle of the opening, so floor friction does not eat the speed.
	var at: Vector3 = plane.transform * Vector3(0, -0.25, distance)
	_place(body, at, plane.transform.basis * Vector3(0, 0, -speed))


func _place(body: RigidBody3D, at: Vector3, velocity: Vector3) -> void:
	body.global_transform = Transform3D(Basis.IDENTITY, at)
	body.linear_velocity = velocity
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false


func _until_transfer(count: int, limit: int) -> bool:
	for _tick: int in range(limit):
		await _ticks(1)
		if _scope.portals().transfers.size() > count:
			await _ticks(1)
			return true
	return false


func _press_power() -> void:
	var button: Node3D = _lab.get_node("portal_button")
	var player: PlayerMotor = _lab.get_node("Player") as PlayerMotor
	var camera: Camera3D = _lab.get_node("Camera") as Camera3D
	var front: Vector3 = button.global_basis.z.normalized()
	player.global_position = Vector3(button.global_position.x, 0.05, button.global_position.z) + front * 1.3
	await _ticks(15)
	camera.look_at(button.global_position + Vector3(0, -0.05, 0) + front * 0.05)
	await _ticks(1)
	await _ticks(1, true)
	await _ticks(3)
	player.global_position = Vector3(0, 0.05, 8.5)


func _ticks(count: int, interact: bool = false) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = GENERATION
		frame.interact_requested = interact and tick == 0
		_scope.apply_input(frame)
