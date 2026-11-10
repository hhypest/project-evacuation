extends SceneTree
## Manual diagnostic witnesses for the 2026-11-10 review. Not part of the passing regression suite.
## Exit 0 means the probes completed; AUDIT_* values report observations, including known defects.
class World:
	extends PuzzleWorldPort
	var pending: Array[StringName] = []
	func definitions() -> Array[DeviceDefinition]:
		var button: DeviceDefinition = DeviceDefinition.make(&"button", DeviceDefinition.Kind.WALL_BUTTON)
		button.wall_mode = DeviceDefinition.WallMode.TOGGLE
		return [button]
	func observe(tick: int) -> PuzzleObservation:
		var obs: PuzzleObservation = PuzzleObservation.new()
		obs.tick_id = tick
		obs.presses = pending.duplicate()
		pending.clear()
		return obs
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var world: World = World.new()
	var puzzle: AdvancePuzzle = AdvancePuzzle.new(world, 1, 2.0)
	puzzle.step(1, 1)
	world.pending = [&"button"]
	puzzle.step(1, 1)
	puzzle.step(1, 2)
	print("AUDIT_DUPLICATE_TICK lost_press=", not puzzle.network.output(&"button"))
	var room: Node3D = Node3D.new()
	root.add_child(room)
	var floor_body: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(8, 1, 8), Color.GRAY, Vector3(0, -0.5, 0))
	room.add_child(floor_body)
	var plate: FloorButtonDevice = FloorButtonDevice.new()
	plate.stable_id = &"plate"
	room.add_child(plate)
	var cube: CarryRigidBody = CarryRigidBody.new()
	cube.stable_id = &"cube"
	cube.mass = 20
	cube.collision_layer = 2
	cube.collision_mask = 3
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * 0.75
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	cube.add_child(collision)
	room.add_child(cube)
	cube.configure(CarryProfile.new(), 1)
	cube.global_position = Vector3(1.07, 0.38, 0)
	cube.constant_force = Vector3(-10, 0, 0)
	for tick: int in range(120):
		await physics_frame
	print("AUDIT_SIDE_CONTACT load=", plate.measure(null, 0.0), " cube=", cube.position, " contacts=", cube.get_colliding_bodies())
	var player: PlayerMotor = PlayerMotor.new()
	room.add_child(player)
	player.global_position = Vector3(0, 0.05, 2)
	for tick: int in range(20):
		await physics_frame
		player.step(MovementCommand.new(), 1.0 / 60)
	var grounded: bool = player.is_on_floor()
	player.set_gravity(Vector3.RIGHT, 1.0)
	var command: MovementCommand = MovementCommand.new()
	command.jump_requested = true
	await physics_frame
	player.step(command, 1.0 / 60)
	print("AUDIT_FIELD_TURN before_grounded=", grounded, " mode=", player.mode, " velocity=", player.velocity, " floor=", player.is_on_floor())
	# An exit becomes blocked while the player is partly in the entry. A new obstacle also
	# occupies the fixed fallback pose in front; recovery must not place the capsule inside it.
	var scope: LevelScope = LevelScope.new()
	root.add_child(scope)
	scope.open(preload("res://content/levels/portal_lab.tscn"), 9)
	var lab: Node3D = scope.get_child(0) as Node3D
	var traveller: PlayerMotor = lab.get_node("Player") as PlayerMotor
	var pair: PortalPairDevice = lab.get_node("portal_pair") as PortalPairDevice
	for tick: int in range(10):
		await physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = 9
		scope.apply_input(frame)
	var a: PortalPlane = pair.state().a
	var b: PortalPlane = pair.state().b
	traveller.global_position = a.transform * Vector3(0, -1.2, 0.05)
	var entry_wall: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(1.6, 2.4, 0.3), Color.GRAY,
		a.transform * Vector3(0, 0, 0.7))
	lab.add_child(entry_wall)
	var blocked_exit: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(1.6, 2.4, 0.3), Color.GRAY,
		b.transform * Vector3(0, 0, 0.25))
	blocked_exit.basis = b.transform.basis
	lab.add_child(blocked_exit)
	for tick: int in range(3):
		await physics_frame
	scope.portals().prepare(9, 1.0 / 60)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = traveller.portal_shape()
	query.transform = Transform3D(traveller.global_basis, traveller.center())
	query.collision_mask = 1
	query.exclude = [traveller.get_rid(), pair.surface_a.barrier_rid, pair.surface_b.barrier_rid]
	var overlap: bool = false
	for hit: Dictionary in traveller.get_world_3d().direct_space_state.intersect_shape(query, 8):
		overlap = overlap or hit.get("rid") == entry_wall.get_rid()
	print("AUDIT_RECOVERY entry_z=", a.local(traveller.center()).z, " overlaps_new_wall=", overlap)
	scope.close()
	room.queue_free()
	await process_frame
	quit()
