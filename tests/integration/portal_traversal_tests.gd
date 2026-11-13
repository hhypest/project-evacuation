class_name PortalTraversalTests
extends TestSuite

const LAB: PackedScene = preload("res://content/levels/portal_lab.tscn")
const GENERATION: int = 63
var _tree: SceneTree
var _scope: LevelScope
var _lab: Node3D
var _pair: PortalPairDevice
var _player: PlayerMotor
var _camera: LookCamera


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	if not await _open(LAB):
		return [TestOutcome.new("portal traversal scope opens", false)]
	var arrived: bool = await _walk_through()
	var b: PortalPlane = _pair.state().b
	results.append(TestOutcome.new("walking into A transfers capsule, view and velocity out of B",
		arrived and b.local(_player.center()).z > 0.0
		and (-_camera.global_basis.z).dot(b.transform.basis.z) > 0.99
		and _player.velocity.dot(b.transform.basis.z) > 1.0,
		"at B %s velocity %s" % [b.local(_player.center()), _player.velocity]))
	await _ticks(12, Vector2(0, -1))
	var before: int = _player_transfers()
	for tick: int in range(60):
		await _ticks(1, Vector2(0, 1))
		if _player_transfers() > before:
			break
	results.append(TestOutcome.new("the player can return through B without a second automatic crossing",
		_player_transfers() == before + 1 and _pair.state().a.local(_player.center()).z > 0.0,
		str(_player.center())))
	await _close()
	if not await _open(LAB):
		return results + [TestOutcome.new("carry portal scope opens", false)]
	var cube: CarryRigidBody = _lab.get_node("CubeA") as CarryRigidBody
	var a: PortalPlane = _pair.state().a
	cube.global_transform = Transform3D(Basis.IDENTITY, a.transform * Vector3(0, -0.65, 0.75))
	cube.linear_velocity = Vector3.ZERO
	await _ticks(10)
	_camera.look_at(cube.global_position, _player.up_direction)
	await _ticks(1, Vector2.ZERO, true)
	_camera.global_basis = Basis.IDENTITY
	var grabbed: bool = _scope.held_prop_id() == cube.stable_id
	arrived = await _walk_through()
	var still_held: bool = _scope.held_prop_id() == cube.stable_id and cube.is_carried()
	var companion: bool = false
	for transfer: PortalTransfer in _scope.portals().transfers:
		companion = companion or transfer.companion_id == cube.stable_id
	await _ticks(12, Vector2(0, -1))
	results.append(TestOutcome.new("E-held cube crosses with its player and remains in the new hold frame",
		grabbed and arrived and still_held and companion and _scope.held_prop_id() == cube.stable_id
		and cube.global_position.distance_to(_player.center()) < 2.0,
		"grabbed %s arrived %s held %s companion %s distance %.3f" %
		[grabbed, arrived, still_held, companion, cube.global_position.distance_to(_player.center())]))
	await _ticks(1, Vector2.ZERO, false, true)
	await _ticks(6)
	results.append(TestOutcome.new("throw after a portal releases once and travels in the exit frame",
		_scope.held_prop_id().is_empty() and not cube.is_carried()
		and cube.linear_velocity.dot(_pair.surface_b.global_basis.z) > 0.5
		and cube.global_position.distance_to(a.transform.origin) > 5.0, str(cube.linear_velocity)))
	await _close()
	if not await _open(LAB):
		return results + [TestOutcome.new("backwards carry portal scope opens", false)]
	cube = _lab.get_node("CubeA") as CarryRigidBody
	a = _pair.state().a
	cube.global_transform = Transform3D(Basis.IDENTITY, a.transform * Vector3(0, -0.65, 2.5))
	cube.linear_velocity = Vector3.ZERO
	await _ticks(10)
	_camera.look_at(cube.global_position, _player.up_direction)
	await _ticks(1, Vector2.ZERO, true)
	_camera.global_basis = Basis(Vector3.UP, PI)
	grabbed = _scope.held_prop_id() == cube.stable_id
	for tick: int in range(60):
		await _ticks(1, Vector2(0, 1))
		if _player_transfers() > 0:
			break
	var trailing_visual: bool = false
	for child: Node in _lab.get_children():
		if child is PortalPropVisual and (child as PortalPropVisual).body == cube:
			var trailing: PortalPropVisual = child as PortalPropVisual
			trailing.refresh()
			trailing_visual = trailing.twin_visible and trailing.entry == _pair.surface_b
	results.append(TestOutcome.new("walking backwards through a portal preserves a held trailing cube's remote visual",
		grabbed and _player_transfers() == 1 and _scope.held_prop_id() == cube.stable_id and trailing_visual
		and _pair.state().b.local(cube.global_position).z < -0.5))
	await _ticks(1, Vector2.ZERO, false, true)
	await _ticks(6)
	results.append(TestOutcome.new("throwing a trailing cube materialises it back at the original visible entry",
		_scope.held_prop_id().is_empty() and a.local(cube.global_position).z > 0.5
		and cube.linear_velocity.dot(a.transform.basis.z) > 1.0, str(cube.global_position)))
	await _close()
	if not await _open(LAB):
		return results + [TestOutcome.new("inserted held cube scope opens", false)]
	cube = _lab.get_node("CubeA") as CarryRigidBody
	a = _pair.state().a
	cube.global_transform = Transform3D(Basis.IDENTITY, a.transform * Vector3(0, -0.65, 0.75))
	cube.linear_velocity = Vector3.ZERO
	await _ticks(10)
	_camera.look_at(cube.global_position, _player.up_direction)
	await _ticks(1, Vector2.ZERO, true)
	_camera.global_basis = Basis.IDENTITY
	var inserted_depth: float = BallastCube.LIGHT_EDGE * 0.5 + 0.07
	for tick: int in range(30):
		await _ticks(1, Vector2(0, -1))
		if a.local(cube.global_position).z < -inserted_depth:
			break
	var inserted: bool = a.local(cube.global_position).z < -inserted_depth and _player_transfers() == 0
	var full_twin: bool = false
	for child: Node in _lab.get_children():
		if child is PortalPropVisual and (child as PortalPropVisual).body == cube:
			var inserted_visual: PortalPropVisual = child as PortalPropVisual
			inserted_visual.refresh()
			full_twin = inserted_visual.twin_visible and inserted_visual.entry == _pair.surface_a
	results.append(TestOutcome.new("fully inserted held cube keeps its remote visual even after leaving the plane thickness",
		inserted and full_twin))
	await _ticks(1, Vector2.ZERO, false, true)
	var before_player: bool = _player_transfers() == 0
	await _ticks(6)
	results.append(TestOutcome.new("throwing a fully inserted held cube before the player crosses uses the exit and maps the queued impulse",
		inserted and before_player and _scope.held_prop_id().is_empty()
		and _pair.state().b.local(cube.global_position).z > 0.5
		and cube.linear_velocity.dot(_pair.surface_b.global_basis.z) > 1.0,
		"inserted %s before player %s velocity %s" % [inserted, before_player, cube.linear_velocity]))
	await _close()
	if not await _open(LAB):
		return results + [TestOutcome.new("blocked player portal scope opens", false)]
	b = _pair.state().b
	var blocker: CarryRigidBody = _lab.get_node("CubeHeavy") as CarryRigidBody
	blocker.global_transform = Transform3D(Basis.IDENTITY, b.transform * Vector3(0, -0.65, 0.55))
	blocker.linear_velocity = Vector3.ZERO
	await _ticks(15)
	await _ticks(60, Vector2(0, -1))
	results.append(TestOutcome.new("occupied exit physically stops the walking player before A",
		_player_transfers() == 0 and _pair.surface_a.blocked and _pair.state().a.local(_player.center()).z >= 0.29,
		str(_pair.state().a.local(_player.center()))))
	blocker.global_position = Vector3(0.5, 0.55, 3.0)
	blocker.linear_velocity = Vector3.ZERO
	arrived = await _walk_through()
	results.append(TestOutcome.new("clearing the exit releases the entry barrier without resetting the level", arrived))
	await _close()
	if not await _open(LAB):
		return results + [TestOutcome.new("visual portal scope opens", false)]
	cube = _lab.get_node("CubeA") as CarryRigidBody
	cube.freeze = true
	cube.global_transform = Transform3D(Basis.IDENTITY, _pair.surface_a.global_transform * Vector3(0, -0.3, 0.2))
	var visual: PortalPropVisual
	for child: Node in _lab.get_children():
		if child is PortalPropVisual and (child as PortalPropVisual).body == cube:
			visual = child as PortalPropVisual
	var objects_before: int = _lab.find_children("*", "CollisionObject3D", true, false).size()
	visual.refresh()
	var meshes_only: bool = true
	for child: Node in visual.get_children():
		meshes_only = meshes_only and child is MeshInstance3D
	results.append(TestOutcome.new("half-in cube has a clipped visual twin without another physical body",
		visual.twin_visible and visual.entry == _pair.surface_a and meshes_only
		and objects_before == _lab.find_children("*", "CollisionObject3D", true, false).size()))
	_pair.surface_a.set_powered(false)
	_pair.surface_b.set_powered(false)
	visual.refresh()
	results.append(TestOutcome.new("unpowered pair removes the twin and restores the original model", not visual.twin_visible))
	await _close()
	if not await _open(_oriented_scene(false)):
		return results + [TestOutcome.new("floor exit scope opens", false)]
	arrived = await _walk_through()
	var mapped_up: Vector3 = _pair.surface_b.global_basis.y.normalized()
	var upward_speed: float = _player.velocity.y
	results.append(TestOutcome.new("wall-to-floor portal rotates capsule and view without losing outward momentum",
		arrived and _player.up_direction.dot(mapped_up) > 0.99 and upward_speed > 1.0,
		"up %s velocity %s" % [_player.up_direction, _player.velocity]))
	await _ticks(1)
	results.append(TestOutcome.new("next movement samples the effective exit field before moving",
		_player.up_direction.dot(Vector3.RIGHT) > 0.99 and not _player.reorientation_blocked, str(_player.up_direction)))
	await _close()
	if not await _open(_oriented_scene(true)):
		return results + [TestOutcome.new("ceiling exit scope opens", false)]
	arrived = await _walk_through()
	mapped_up = _pair.surface_b.global_basis.y.normalized()
	results.append(TestOutcome.new("wall-to-ceiling portal rotates capsule and camera and preserves downward momentum",
		arrived and _player.up_direction.dot(mapped_up) > 0.99 and _camera.global_basis.y.dot(mapped_up) > 0.99
		and _player.velocity.y < -1.0,
		"up %s velocity %s" % [_player.up_direction, _player.velocity]))
	await _close()
	return results


func _oriented_scene(ceiling: bool) -> PackedScene:
	var lab: Node3D = LAB.instantiate() as Node3D
	lab.set_script(preload("res://tests/fixtures/portal_floor_lab.gd"))
	var oriented: PortalOrientationLab = lab as PortalOrientationLab
	oriented.ceiling = ceiling
	var scene: PackedScene = PackedScene.new()
	scene.pack(oriented)
	oriented.free()
	return scene


func _open(scene: PackedScene) -> bool:
	_scope = LevelScope.new()
	_tree.root.add_child(_scope)
	if not _scope.open(scene, GENERATION):
		_scope.close()
		return false
	_lab = _scope.get_child(0) as Node3D
	_pair = _lab.get_node("portal_pair") as PortalPairDevice
	_player = _lab.get_node("Player") as PlayerMotor
	_camera = _lab.get_node("Camera") as LookCamera
	_player.global_position = Vector3(_pair.surface_a.global_position.x, 0.05, _pair.surface_a.global_position.z + 1.5)
	_camera.global_basis = Basis.IDENTITY
	_camera.frame = Basis.IDENTITY
	await _ticks(15)
	_scope.portals().reset()
	await _ticks(1)
	return true


func _close() -> void:
	_scope.close()
	await _tree.process_frame


func _player_transfers() -> int:
	var count: int = 0
	for transfer: PortalTransfer in _scope.portals().transfers:
		if transfer.body_id == PortalWorldAdapter.PLAYER_ID and not transfer.blocked:
			count += 1
	return count


func _walk_through() -> bool:
	var before: int = _player_transfers()
	for tick: int in range(60):
		await _ticks(1, Vector2(0, -1))
		if _player_transfers() > before:
			return true
	return false


func _ticks(count: int, move: Vector2 = Vector2.ZERO, interact: bool = false, throwing: bool = false) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = GENERATION
		frame.move_axis = move
		frame.sprinting = true
		frame.interact_requested = interact and tick == 0
		frame.throw_requested = throwing and tick == 0
		_scope.apply_input(frame)
