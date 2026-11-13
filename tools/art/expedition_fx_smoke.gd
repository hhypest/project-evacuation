extends SceneTree
## Fixed-pose Vulkan comparison, with a beam and gravity boundary in both live portal views.

var _target: SubViewport
var _capture: String
var _failed: bool = false
var _compare_fsr: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0, true, false, true).timeout.connect(func() -> void: quit(1))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_compare_fsr = args.size() == 3 and args[2] == "--compare-fsr"
	if (args.size() != 2 and not _compare_fsr) or args[0] != "--capture" \
			or not ValidateRuntime.new().execute(RuntimeProbe.new().read()).is_empty():
		printerr("Expected Vulkan Forward+ and --capture <absolute PNG path> [--compare-fsr]")
		quit(2)
		return
	_capture = args[1].get_basename()
	_target = SubViewport.new()
	_target.size = Vector2i(2560, 1440)
	_target.own_world_3d = true
	_target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_target)
	_target.msaa_3d = Viewport.MSAA_DISABLED if _compare_fsr else Viewport.MSAA_4X
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
	if _compare_fsr:
		field.show_output(true, 0)
		await _benchmark_fsr(pair, camera, emitter)
		field.show_output(false, 0)
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


## Run the exact same camera and beam sequence twice. Timing covers separate viewport GPU queries.
func _benchmark_fsr(pair: PortalPairDevice, camera: Camera3D, emitter: EmitterDevice) -> void:
	var window_vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var viewports: Array[Viewport] = [_target, pair.surface_a.viewport, pair.surface_b.viewport]
	for viewport: Viewport in viewports:
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	var pose: Transform3D = camera.global_transform
	var full_length: float = emitter.beam_length
	for fsr: bool in [false, true]:
		RenderScale.apply(_target, fsr)
		var name: String = "fsr2" if fsr else "native"
		_check(is_equal_approx(pair.surface_a.viewport.scaling_3d_scale, 1.0)
			and is_equal_approx(pair.surface_b.viewport.scaling_3d_scale, 1.0), "portal targets keep native scale")
		await _frame()
		var total: Vector3 = Vector3.ZERO
		var frame_times: Array[float] = []
		var last_frame: int = Time.get_ticks_usec()
		for index: int in range(120):
			camera.global_transform = pose
			camera.position.x += sin(float(index) * 0.09) * 0.62
			camera.rotation.y += sin(float(index) * 0.09) * 0.075
			emitter.show_beam(full_length if index < 60 else full_length * 0.56)
			await process_frame
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			frame_times.append(float(now - last_frame) / 1000.0)
			last_frame = now
			total.x += RenderingServer.viewport_get_measured_render_time_gpu(viewports[0].get_viewport_rid())
			total.y += RenderingServer.viewport_get_measured_render_time_gpu(viewports[1].get_viewport_rid())
			total.z += RenderingServer.viewport_get_measured_render_time_gpu(viewports[2].get_viewport_rid())
		var means: Vector3 = total / 120.0
		_check(means.x > 0.0 and means.y > 0.0 and means.z > 0.0, "recorded GPU times for all three viewports")
		var summary: ProfilerSample = ProfilerSample.summarize(frame_times)
		print("FSR_SAMPLE mode=%s main_gpu_ms=%.3f portal_a_gpu_ms=%.3f portal_b_gpu_ms=%.3f frame_p95_ms=%.3f" \
			% [name, means.x, means.y, means.z, summary.frame_p95_ms])
		camera.global_transform = pose
		emitter.show_beam(full_length)
		var lit: Image = await _frame()
		_save(lit, name + "-beam-on")
		emitter.show_beam(full_length * 0.56)
		await process_frame
		await RenderingServer.frame_post_draw
		_save(_target.get_texture().get_image(), name + "-beam-cut")
		camera.global_transform = pair.surface_a.global_transform * Transform3D(Basis(Vector3.UP, 0.65),
			Vector3(0.2, 0.4, 0.03))
		_save(await _frame(), name + "-near")
		camera.global_transform = pose
		emitter.show_beam(full_length)
	RenderScale.apply(_target, false)
	DisplayServer.window_set_vsync_mode(window_vsync)

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
