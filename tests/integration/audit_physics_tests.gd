class_name AuditPhysicsTests
extends TestSuite

var _tree: SceneTree
var _room: Node3D


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	var results: Array[TestOutcome] = []
	for turned: bool in [false, true]:
		_room = Node3D.new()
		_room.basis = Basis(Vector3.FORWARD, PI * 0.5) if turned else Basis.IDENTITY
		tree.root.add_child(_room)
		_room.add_child(PuzzleDeviceNode.static_box(Vector3(8, 1, 8), Color.GRAY, Vector3(0, -0.5, 0)))
		var plate: FloorButtonDevice = FloorButtonDevice.new()
		plate.stable_id = &"audit.plate"
		_room.add_child(plate)
		var cube: CarryRigidBody = _cube(&"audit.cube", Vector3(1.07, 0.38, 0), 20.0)
		cube.constant_force += _room.basis * Vector3(-10, 0, 0)
		await _ticks(120)
		results.append(TestOutcome.new("a cube touching only the plate side contributes no supported load (turned=%s)" % turned,
			plate.measure(null, 0.0) == 0.0 and cube.get_colliding_bodies().has(plate.plate)))
		cube.portal_place(_room.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Vector3.ZERO, Vector3.ZERO)
		cube.constant_force = -plate.global_basis.y * 196.0
		await _ticks(100)
		results.append(TestOutcome.new("a cube really resting on the plate contributes its mass (turned=%s)" % turned,
			absf(plate.measure(null, 0.0) - 20.0) < 0.01, str(plate.last_load)))
		var upper: CarryRigidBody = _cube(&"audit.upper", Vector3(0, 1.26, 0), 5.0)
		await _ticks(100)
		results.append(TestOutcome.new("real stacked contacts count every mass once (turned=%s)" % turned,
			absf(plate.measure(null, 0.0) - 25.0) < 0.01, str(plate.last_load)))
		var side: CarryRigidBody = _cube(&"audit.side", Vector3(0.745, 1.31, 0), 7.0)
		side.constant_force = _room.basis * Vector3(-10, 0, 0)
		await _ticks(30)
		results.append(TestOutcome.new("a side contact higher than a supported cube is not a stack (turned=%s)" % turned,
			absf(plate.measure(null, 0.0) - 25.0) < 0.01 and side.get_colliding_bodies().has(upper), str(plate.last_load)))
		side.queue_free()
		upper.queue_free()
		await _ticks(5)
		results.append(TestOutcome.new("removing supported bodies leaves no stale load (turned=%s)" % turned,
			absf(plate.measure(null, 0.0) - 20.0) < 0.01))
		var portal_world: PortalWorldAdapter = PortalWorldAdapter.new()
		portal_world.configure(_room)
		var raised: Transform3D = cube.global_transform
		raised.origin += plate.global_basis.y * 1.5
		var recovered: bool = portal_world.hold(cube.stable_id, raised, Vector3.ZERO)
		results.append(TestOutcome.new("portal recovery invalidates old rigid-body support before the next observation (turned=%s)" % turned,
			recovered and plate.measure(null, 0.0) == 0.0))
		portal_world.close()
		_room.queue_free()
		await tree.process_frame
	for jumping: bool in [false, true]:
		_room = Node3D.new()
		tree.root.add_child(_room)
		_room.add_child(PuzzleDeviceNode.static_box(Vector3(8, 1, 8), Color.GRAY, Vector3(0, -0.5, 0)))
		var player: PlayerMotor = PlayerMotor.new()
		_room.add_child(player)
		player.global_position = Vector3(0, 0.05, 2)
		for tick: int in range(20):
			await tree.physics_frame
			player.step(MovementCommand.new(), 1.0 / 60.0)
		var was_grounded: bool = player.is_on_floor()
		player.set_gravity(Vector3.RIGHT, 1.0)
		var command: MovementCommand = MovementCommand.new()
		command.jump_requested = jumping
		await tree.physics_frame
		player.step(command, 1.0 / 60.0)
		results.append(TestOutcome.new("field rotation cannot jump from old support or lose its air branch (jump=%s)" % jumping,
			was_grounded and player.mode == MovementStep.Mode.AIR and player.velocity.x < -0.3, str(player.velocity)))
		_room.queue_free()
		await tree.process_frame
	var scope: LevelScope = LevelScope.new()
	tree.root.add_child(scope)
	if not scope.open(preload("res://content/levels/portal_lab.tscn"), 9):
		return results + [TestOutcome.new("recovery lab opens", false)]
	var lab: Node3D = scope.get_child(0) as Node3D
	var traveller: PlayerMotor = lab.get_node("Player") as PlayerMotor
	var pair: PortalPairDevice = lab.get_node("portal_pair") as PortalPairDevice
	for tick: int in range(10):
		await tree.physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = 9
		scope.apply_input(frame)
	var a: PortalPlane = pair.state().a
	var b: PortalPlane = pair.state().b
	# Record a free approach first; once a new wall occupies the return corridor the adapter
	# must refuse both the short fallback and this old pose, rather than teleport through the wall.
	traveller.global_position = a.transform * Vector3(0, -1.2, 1.5)
	scope.portals().prepare(9, 1.0 / 60.0)
	traveller.global_position = a.transform * Vector3(0, -1.2, 0.05)
	var entry_wall: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(1.6, 2.4, 0.3), Color.GRAY,
		a.transform * Vector3(0, 0, 0.7))
	lab.add_child(entry_wall)
	var exit_wall: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(1.6, 2.4, 0.3), Color.GRAY,
		b.transform * Vector3(0, 0, 0.25))
	exit_wall.basis = b.transform.basis
	lab.add_child(exit_wall)
	await _ticks(3)
	var before: Vector3 = traveller.center()
	scope.portals().prepare(9, 1.0 / 60.0)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = traveller.portal_shape()
	query.transform = Transform3D(traveller.global_basis, traveller.center())
	query.collision_mask = 1
	query.exclude = [traveller.get_rid(), pair.surface_a.barrier_rid, pair.surface_b.barrier_rid]
	var overlaps: bool = false
	for hit: Dictionary in traveller.get_world_3d().direct_space_state.intersect_shape(query, 8):
		overlaps = overlaps or hit.get("rid") == entry_wall.get_rid()
	results.append(TestOutcome.new("blocked exit and recovery corridor never place the capsule into a new obstacle",
		not overlaps and traveller.center().is_equal_approx(before) and scope.needs_recovery(), str(traveller.center())))
	scope.close()
	await tree.process_frame
	return results


func _cube(id: StringName, at: Vector3, mass_kg: float) -> CarryRigidBody:
	var body: CarryRigidBody = CarryRigidBody.new()
	body.stable_id = id
	body.mass = mass_kg
	body.collision_layer = 2
	body.collision_mask = 3
	body.gravity_scale = 0.0
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.75
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	_room.add_child(body)
	body.position = at
	body.configure(CarryProfile.new(), 1)
	body.constant_force = -_room.global_basis.y * mass_kg * 9.8
	return body


func _ticks(count: int) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
