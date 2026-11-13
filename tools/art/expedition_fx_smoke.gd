extends SceneTree
## Fixed-pose Vulkan comparison, with a beam and gravity boundary in both live portal views.

var _target: SubViewport
var _capture: String
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void: quit(1))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] != "--capture" or not ValidateRuntime.new().execute(RuntimeProbe.new().read()).is_empty():
		printerr("Expected Vulkan Forward+ and --capture <absolute PNG path>")
		quit(2)
		return
	_capture = args[1].get_basename()
	_target = SubViewport.new()
	_target.size = Vector2i(2560, 1440)
	_target.own_world_3d = true
	_target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_target)
	_target.msaa_3d = Viewport.MSAA_4X
	var stage: ChamberBuilder = ChamberBuilder.new()
	_target.add_child(stage)
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.065, 0.080, 0.095)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.8, 0.86, 0.92)
	world.environment.ambient_light_energy = 0.40
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	stage.add_child(world)
	stage._lamp(Vector3(0, 3.8, 3), 12.0, 2.4)
	stage._lamp(Vector3(-2, 3.4, 6.5), 9.0, 1.6)
	stage._lamp(Vector3(2.6, 3.0, 1.4), 8.0, 1.1)
	_wall(stage, Vector3(11, 0.2, 12), Vector3(0, -0.10, 4.0))
	for panel: Vector3 in [Vector3(-4.25, 1.7, 0), Vector3(0, 1.7, 0), Vector3(4.25, 1.7, 0)]:
		_wall(stage, Vector3(2.3, 3.4, 0.3), panel)
	_wall(stage, Vector3(11, 0.94, 0.3), Vector3(0, 2.87, 0))
	_wall(stage, Vector3(11, 3.4, 0.3), Vector3(0, 1.7, 9.4))
	var pair: PortalPairDevice = PortalPairDevice.new()
	pair.a_transform.origin = Vector3(-2.0, 1.2, 0)
	pair.b_transform.origin = Vector3(2.0, 1.2, 0)
	stage.add_child(pair)
	pair.show_output(true, 0)
	var field: GravityFieldDevice = stage._field(&"bench.field", Vector3(1.9, 1.34, 1.55), Vector3(3.2, 2.5, 3.15), -90, [])
	var emitter: EmitterDevice = stage._emitter(&"bench.emitter", Vector3(-3.4, 0.58, 1.55), [], -90.0)
	var receiver: ReceiverDevice = stage._receiver(&"bench.receiver", Vector3(3.65, 0.58, 1.55), 90.0)
	var light_cube: CarryRigidBody = stage._cube("Light", &"bench.light", Vector3(-1.35, 0.25, 2.0), BallastCube.Kind.LIGHT)
	var heavy_cube: CarryRigidBody = stage._cube("Heavy", &"bench.heavy", Vector3(2.0, 0.375, 2.55), BallastCube.Kind.HEAVY)
	light_cube.freeze = true
	heavy_cube.freeze = true
	var camera: Camera3D = Camera3D.new()
	camera.fov = 76.0
	camera.position = Vector3(-0.37, 1.60, 6.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 1.37, 0.0))
	var views: PortalViewWorld = PortalViewWorld.new()
	stage.add_child(views)
	views.configure(stage, pair)

	emitter.show_output(true, 0)
	emitter.show_beam(emitter.muzzle().distance_to(receiver.global_position) - 0.13)
	receiver.show_output(true, 0)
	var before: Image = await _frame()
	field.show_output(true, 0)
	var after: Image = await _frame()
	_save(after, "combined")
	_check(pair.surface_a.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS
		and pair.surface_b.viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "both live targets in the same frame")
	var sheen: MeshInstance3D = field.get_node("BoundarySheen") as MeshInstance3D
	_check(sheen.visible and sheen.layers & PortalViewWorld.VIEW_MASK == 0, "scene refraction excluded from the live portal targets")
	_check(before.save_png(_capture + "-field-off.png") == OK, "save field-off A/B reference")
	_save(pair.surface_a.viewport.get_texture().get_image(), "portal-a-view")
	_save(pair.surface_b.viewport.get_texture().get_image(), "portal-b-view")
	camera.global_position = Vector3(2.3, 1.49, 2.24)
	camera.look_at(Vector3(0.9, 1.13, 0.0))
	var inside: Image = await _frame()
	_check(field.contains(camera.global_position), "inside boundary capture")
	_save(inside, "inside")

	camera.global_position = Vector3(-1.55, 1.16, 3.1)
	camera.look_at(Vector3(-0.95, 0.61, 1.55))
	heavy_cube.global_position = Vector3(-0.8, 0.375, 1.55)
	var contact: Vector3 = heavy_cube.global_position + Vector3(-BallastCube.HEAVY_EDGE * 0.5, 0.205, 0)
	emitter.show_beam(emitter.muzzle().distance_to(contact))
	emitter.show_contact(contact, Vector3.LEFT)
	receiver.show_output(false, 0)
	_save(await _frame(), "beam-contact")
	print("EXPEDITION_FX_%s resolution=%s GPU=%s" % ["FAILED" if _failed else "PASSED", _target.size,
		RenderingServer.get_video_adapter_name()])
	quit(1 if _failed else 0)


func _wall(stage: ChamberBuilder, size: Vector3, at: Vector3) -> void:
	var wall: MeshInstance3D = MeshInstance3D.new()
	wall.mesh = MetricBoxMesh.make(size, at)
	wall.material_override = MechanicsLightingBay.REFERENCE_BASALT
	wall.position = at
	stage.add_child(wall)


func _frame() -> Image:
	for index: int in range(9):
		await process_frame
	await RenderingServer.frame_post_draw
	return _target.get_texture().get_image()


func _save(frame: Image, suffix: String) -> void:
	_check(frame != null and frame.get_size() == _target.size and frame.save_png(_capture + "-" + suffix + ".png") == OK,
		"save " + suffix)


func _check(ok: bool, label: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	_failed = _failed or not ok
