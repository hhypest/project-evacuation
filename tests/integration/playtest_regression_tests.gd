class_name PlaytestRegressionTests
extends TestSuite

var _tree: SceneTree


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	results.append_array(await _pickup_from_plate())
	results.append_array(await _blocked_gravity())
	results.append_array(await _blocked_gravity(1.0))
	results.append_array(await _obstructed_companion())
	results.append_array(await _obstructed_companion(true))
	results.append_array(await _obstructed_companion(false, "CubeHeavy"))
	results.append_array(await _repeated_portals())
	results.append_array(await _off_axis_portal_return())
	results.append_array(await _view_clipping())
	return results


func _pickup_from_plate() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	for distance: float in [1.2, 1.6, 2.0]:
		var scope: LevelScope = LevelScope.new()
		_tree.root.add_child(scope)
		scope.open(preload("res://content/levels/stacking_lab.tscn"), 82)
		var lab: Node3D = scope.get_child(0) as Node3D
		var plate: FloorButtonDevice = lab.get_node("stack_plate") as FloorButtonDevice
		var cube: CarryRigidBody = lab.get_node("Cube0") as CarryRigidBody
		var player: PlayerMotor = lab.get_node("Player") as PlayerMotor
		var camera: LookCamera = lab.get_node("Camera") as LookCamera
		cube.portal_place(Transform3D(Basis.IDENTITY, plate.global_position + Vector3(0, 0.48, 0)), Vector3.ZERO, Vector3.ZERO)
		player.position = plate.position + Vector3(0, 0.05, distance)
		for tick: int in range(90):
			await _tick(scope, 82)
		camera.look_at(cube.global_position)
		await _tick(scope, 82, Vector2.ZERO, true)
		var acquired: bool = cube.is_carried()
		for tick: int in range(45):
			await _tick(scope, 82)
		results.append(TestOutcome.new("one E lifts a cube off a plate without moving the camera (distance=%.1f)" % distance,
			acquired and cube.is_carried() and cube.position.distance_to(plate.position + Vector3(0, 0.48, 0)) > 0.3,
			"held=%s position=%s" % [cube.is_carried(), cube.position]))
		scope.close()
		await _tree.process_frame
	return results


func _blocked_gravity(edge: float = 0.75) -> Array[TestOutcome]:
	var room: Node3D = Node3D.new()
	_tree.root.add_child(room)
	room.add_child(PuzzleDeviceNode.static_box(Vector3(8, 1, 8), Color.GRAY, Vector3(0, -0.5, 0)))
	room.add_child(PuzzleDeviceNode.static_box(Vector3.ONE * edge, Color.GRAY, Vector3(-0.8, edge * 0.5, 0)))
	var player: PlayerMotor = PlayerMotor.new()
	room.add_child(player)
	player.position = Vector3(0, 0.01, 0)
	for tick: int in range(20):
		await _tree.physics_frame
		player.step(MovementCommand.new(), 1.0 / 60.0)
	player.set_gravity(Vector3.RIGHT, 1.0)
	for tick: int in range(90):
		await _tree.physics_frame
		player.step(MovementCommand.new(), 1.0 / 60.0)
	var result: TestOutcome = TestOutcome.new("a cube beside a field entrance cannot trap the player in the old orientation (edge=%.2f)" % edge,
		player.up_direction.dot(Vector3.RIGHT) > 0.99 and not player.reorientation_blocked,
		"up=%s blocked=%s at=%s" % [player.up_direction, player.reorientation_blocked, player.position])
	room.queue_free()
	await _tree.process_frame
	return [result]


func _obstructed_companion(releasing: bool = false, cube_name: String = "CubeA") -> Array[TestOutcome]:
	var scope: LevelScope = LevelScope.new()
	_tree.root.add_child(scope)
	scope.open(preload("res://content/levels/portal_lab.tscn"), 84)
	var lab: Node3D = scope.get_child(0) as Node3D
	var pair: PortalPairDevice = lab.get_node("portal_pair") as PortalPairDevice
	var player: PlayerMotor = lab.get_node("Player") as PlayerMotor
	var camera: LookCamera = lab.get_node("Camera") as LookCamera
	var cube: CarryRigidBody = lab.get_node(NodePath(cube_name)) as CarryRigidBody
	player.position = pair.surface_a.global_transform * Vector3(0, -1.15, 1.8)
	cube.portal_place(Transform3D(Basis.IDENTITY, pair.surface_a.global_transform * Vector3(0, -0.65, 0.8)), Vector3.ZERO, Vector3.ZERO)
	for tick: int in range(30):
		await _tick(scope, 84)
	camera.look_at(cube.global_position)
	await _tick(scope, 84, Vector2.ZERO, true)
	camera.global_basis = Basis.IDENTITY
	for tick: int in range(60):
		await _tick(scope, 84, Vector2(0, -1))
		if pair.surface_a.to_local(player.center()).z < 0.6:
			break
	var blocker: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(1.6, 2.4, 0.3), Color.GRAY, Vector3.ZERO)
	lab.add_child(blocker)
	blocker.global_transform = pair.surface_b.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.4))
	for tick: int in range(5):
		await _tick(scope, 84, Vector2.ZERO, releasing and tick == 0)
	var result: TestOutcome = TestOutcome.new("a refused inserted companion beside its carrier drops safely without resetting the chamber (release=%s cube=%s)" % [releasing, cube_name],
		not scope.needs_recovery() and not cube.is_carried(),
		"recovery=%s body=%s player=%s cube=%s held=%s" % [scope.needs_recovery(), scope.portals().recovery_body_id, player.center(), cube.position, cube.is_carried()])
	scope.close()
	await _tree.process_frame
	return [result]


func _repeated_portals() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	for cube_name: String in ["CubeA", "CubeHeavy"]:
		var scope: LevelScope = LevelScope.new()
		_tree.root.add_child(scope)
		scope.open(preload("res://content/levels/portal_lab.tscn"), 83)
		var lab: Node3D = scope.get_child(0) as Node3D
		var pair: PortalPairDevice = lab.get_node("portal_pair") as PortalPairDevice
		var player: PlayerMotor = lab.get_node("Player") as PlayerMotor
		var camera: LookCamera = lab.get_node("Camera") as LookCamera
		var cube: CarryRigidBody = lab.get_node(NodePath(cube_name)) as CarryRigidBody
		player.position = pair.surface_a.global_transform * Vector3(0, -1.15, 1.8)
		cube.portal_place(Transform3D(Basis.IDENTITY, pair.surface_a.global_transform * Vector3(0, -0.65, 0.8)), Vector3.ZERO, Vector3.ZERO)
		for tick: int in range(30):
			await _tick(scope, 83)
		camera.look_at(cube.global_position)
		await _tick(scope, 83, Vector2.ZERO, true)
		var crossings: int = 0
		for lap: int in range(12):
			var entry: PortalSurface = pair.surface_a if lap % 2 == 0 else pair.surface_b
			# The real playtest turns near the exit, including a downward look at the held cube.
			camera.look_at(entry.global_position + Vector3.DOWN * 0.7)
			for tick: int in range(30):
				await _tick(scope, 83)
				if scope.needs_recovery():
					break
			var before: int = scope.portals().crossing_count
			for tick: int in range(90):
				await _tick(scope, 83, Vector2(0, -1))
				if scope.needs_recovery() or scope.portals().crossing_count > before:
					break
			if scope.needs_recovery() or scope.portals().crossing_count <= before:
				break
			crossings += 1
			for tick: int in range(10):
				await _tick(scope, 83, Vector2(0, -1))
		results.append(TestOutcome.new("repeated close turns with %s never request a chamber reset" % cube_name,
			crossings == 12 and not scope.needs_recovery() and cube.is_carried(),
			"laps=%d recovery=%s body=%s held=%s" % [crossings, scope.needs_recovery(), scope.portals().recovery_body_id, cube.is_carried()]))
		scope.close()
		await _tree.process_frame
	return results


func _off_axis_portal_return() -> Array[TestOutcome]:
	var scope: LevelScope = LevelScope.new()
	_tree.root.add_child(scope)
	const GENERATION: int = 86
	if not scope.open(preload("res://content/levels/mechanics_lab.tscn"), GENERATION):
		scope.close()
		return [TestOutcome.new("off-axis portal regression opens the unified lab", false)]
	var lab: Node3D = scope.get_child(0) as Node3D
	var player: PlayerMotor = lab.get_node("Player") as PlayerMotor
	var camera: LookCamera = lab.get_node("Camera") as LookCamera
	var pair: PortalPairDevice = lab.get_node("Portals/Fixture/portal_pair") as PortalPairDevice
	var cube: CarryRigidBody = lab.get_node("Portals/Fixture/CubeA") as CarryRigidBody
	var a: Transform3D = pair.surface_a.global_transform
	player.global_position = a * Vector3(0, -1.15, 1.5)
	camera.global_basis = Basis.IDENTITY
	cube.global_position = a * Vector3(0, -0.65, 0.75)
	for tick: int in range(15):
		await _tick(scope, GENERATION)
	camera.look_at(cube.global_position)
	await _tick(scope, GENERATION, Vector2.ZERO, true)
	camera.global_basis = Basis.IDENTITY
	var crossings: int = 0
	var dropped: bool = false
	var turns: Array[int] = [13, 11]
	var aim_offsets: Array[float] = [-0.00492647, -0.23171490]
	for lap: int in range(3):
		var before: int = scope.portals().crossing_count
		for tick: int in range(60):
			await _tick(scope, GENERATION, Vector2.UP, false, true)
			if scope.needs_recovery() or scope.portals().crossing_count > before:
				break
		if scope.needs_recovery() or scope.portals().crossing_count == before:
			break
		var crossing: PortalTransfer = scope.portals().transfers.back()
		if crossing.blocked or crossing.body_id != PortalWorldAdapter.PLAYER_ID:
			break
		crossings += 1
		dropped = crossing.detached_id == cube.stable_id
		await _tick(scope, GENERATION, Vector2.UP, false, true)
		if lap == 2 or scope.needs_recovery():
			break
		for tick: int in range(turns[lap]):
			camera.global_basis = Basis(Vector3.UP, -PI / turns[lap]) * camera.global_basis
			await _tick(scope, GENERATION)
		var entry: PortalSurface = pair.surface_b if lap == 0 else pair.surface_a
		camera.look_at(entry.global_position + Vector3.UP * 0.4 + entry.global_basis.x * aim_offsets[lap])
	for tick: int in range(8):
		await _tick(scope, GENERATION)
	var cube_z: float = pair.surface_a.to_local(cube.global_position).z
	var result: TestOutcome = TestOutcome.new("two quick turns and an off-axis return leave the refused cube on the entry side without a reset",
		crossings == 3 and dropped and not cube.is_carried() and cube_z > 0.5 and not scope.needs_recovery(),
		"crossings=%d detached=%s cube_z=%.3f recovery=%s" % [crossings, dropped, cube_z, scope.portals().recovery_body_id])
	scope.close()
	await _tree.process_frame
	return [result]


func _view_clipping() -> Array[TestOutcome]:
	var scope: LevelScope = LevelScope.new()
	_tree.root.add_child(scope)
	scope.open(preload("res://content/levels/portal_lab.tscn"), 85)
	var lab: Node3D = scope.get_child(0) as Node3D
	var pair: PortalPairDevice = lab.get_node("portal_pair") as PortalPairDevice
	var renderer: PortalViewWorld
	for child: Node in lab.get_children():
		if child is PortalViewWorld:
			renderer = child as PortalViewWorld
	var parts: Array[MeshInstance3D] = []
	for depth: float in [1.0, -1.0, 0.0]:
		var mesh: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3.ONE * 0.3, Color.RED)
		lab.add_child(mesh)
		mesh.global_transform = pair.surface_b.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, depth))
		parts.append(mesh)
	renderer.refresh()
	var proxy: MeshInstance3D
	for child: Node in renderer.get_children():
		var mesh: MeshInstance3D = child as MeshInstance3D
		if mesh != null and mesh.mesh == parts[2].mesh and mesh.layers == PortalViewWorld.VIEW_LAYERS[0]:
			proxy = mesh
	var player_camera: LookCamera = lab.get_node("Camera") as LookCamera
	var lamp: Light3D = lab.get_node("KeyLight") as Light3D
	var classified: bool = parts[0].layers & PortalViewWorld.VIEW_LAYERS[0] != 0 \
		and parts[1].layers & PortalViewWorld.VIEW_LAYERS[0] == 0 and parts[2].layers & PortalViewWorld.VIEW_LAYERS[0] == 0
	var results: Array[TestOutcome] = [TestOutcome.new("exit clipping classifies dynamically added geometry without changing the main camera or adding physics",
		classified and proxy != null and proxy.visible and proxy.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and player_camera.cull_mask & PortalViewWorld.VIEW_MASK == 0)]
	results.append(TestOutcome.new("portal cameras retain the room lights as well as their receiver masks",
		lamp.layers & PortalViewWorld.VIEW_MASK == PortalViewWorld.VIEW_MASK
		and lamp.light_cull_mask & PortalViewWorld.VIEW_MASK == PortalViewWorld.VIEW_MASK))
	parts[2].queue_free()
	await _tree.process_frame
	renderer.refresh()
	await _tree.process_frame
	results.append(TestOutcome.new("removing a clipped object also removes its render-only proxy", not is_instance_valid(proxy)))
	renderer.get_parent().remove_child(renderer)
	results.append(TestOutcome.new("closing portal presentation restores original light and mesh layers",
		lamp.layers == 1 and parts[0].layers == 1))
	renderer.queue_free()
	scope.close()
	await _tree.process_frame
	return results


func _tick(scope: LevelScope, generation: int, move: Vector2 = Vector2.ZERO, interact: bool = false,
		sprint: bool = false) -> void:
	await _tree.physics_frame
	var frame: GameplayInputFrame = GameplayInputFrame.new()
	frame.generation = generation
	frame.move_axis = move
	frame.interact_requested = interact
	frame.sprinting = sprint
	scope.apply_input(frame)
