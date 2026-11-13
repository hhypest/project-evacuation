extends SceneTree
## Repeatable first-person material bench. --capture <PNG path>; fixed camera/light pairs for QA.

const PANEL: Material = preload("res://content/materials/expedition/panel_reference.tres")
const BASALT: Material = preload("res://content/materials/expedition/basalt_reference.tres")
var _capture: String = "res://work/material-reference.png"
var _failed: bool = false
var _target: SubViewport

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		printerr("MATERIAL_REFERENCE_FAILED: watchdog")
		quit(1))
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--capture":
		_capture = arguments[1]
	elif not arguments.is_empty():
		quit(2)
		return
	var runtime: RuntimeInfo = RuntimeProbe.new().read()
	if not ValidateRuntime.new().execute(runtime).is_empty():
		printerr("MATERIAL_REFERENCE_FAILED: Vulkan Forward+ required")
		quit(1)
		return
	# A native off-screen target gives identical pixels when the Windows desktop constrains the window.
	var target: SubViewport = SubViewport.new()
	target.size = Vector2i(2560, 1440)
	target.own_world_3d = true
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(target)
	_target = target
	var stage: Node3D = Node3D.new()
	target.add_child(stage)
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.04, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.85, 0.92)
	environment.ambient_light_energy = 0.2
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	stage.add_child(world)
	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(-2, 3.5, 3)
	light.omni_range = 12
	light.light_energy = 3
	light.shadow_enabled = true
	stage.add_child(light)
	# Use the real bay's material assignment, including its UV metric, on adjacent modules.
	var bay: MechanicsBayBuilder = MechanicsBayBuilder.new()
	stage.add_child(bay)
	for child: Node in bay.get_children():
		child.queue_free()
	for index: int in range(2):
		bay._surface_box(Vector3(2, 2.4, 0.15), Vector3(-3 + index * 2, 1.2, 0), BASALT)
	var panel: MeshInstance3D = MeshInstance3D.new()
	panel.mesh = MetricBoxMesh.make(Vector3(2, 2.4, 0.15), Vector3(1, 1.2, 0), 1.0)
	panel.material_override = PANEL
	panel.position = Vector3(1, 1.2, 0)
	stage.add_child(panel)
	var floor_visual: MeshInstance3D = MeshInstance3D.new()
	floor_visual.mesh = MetricBoxMesh.make(Vector3(10, 0.1, 4), Vector3(0, -0.05, 1.8))
	floor_visual.position = Vector3(0, -0.05, 1.8)
	floor_visual.material_override = BASALT
	stage.add_child(floor_visual)
	var cube: Node3D = PropVisuals.ballast_cube(BallastCube.LIGHT_EDGE)
	cube.position = Vector3(-0.52, 0.25, 1)
	stage.add_child(cube)
	var heavy: Node3D = PropVisuals.ballast_cube(BallastCube.HEAVY_EDGE, true)
	heavy.position = Vector3(0.36, 0.375, 1)
	stage.add_child(heavy)
	var lever: WallButtonDevice = WallButtonDevice.new()
	lever.mode = DeviceDefinition.WallMode.TOGGLE
	lever.position = Vector3(1, 1.35, 0.16)
	stage.add_child(lever)
	var camera: Camera3D = Camera3D.new()
	camera.fov = 65
	stage.add_child(camera)
	camera.position = Vector3(0, 1.65, 5.4)
	camera.look_at(Vector3(-0.4, 1.1, 0))
	await _save("overview")
	for dim: bool in [false, true]:
		light.light_energy = 0.35 if dim else 3.0
		for angle: float in [0.0, 0.85]:
			camera.position = lever.position + Vector3(sin(angle) * 0.85, 0.08, cos(angle) * 0.85)
			camera.look_at(lever.position)
			for on: bool in [false, true]:
				lever.show_output(on, 0.0)
				await _save("switch-%s-%.2f-%s" % ["dim" if dim else "lit", angle, "on" if on else "off"])
	light.light_energy = 3
	for side: float in [-1.0, 1.0]:
		light.position.x = side * 2.5
		camera.position = Vector3(0.1, 0.95, 2.48)
		camera.look_at(Vector3(-0.04, 0.35, 1))
		await _save("cube-light-%s" % side)
	print("MATERIAL_REFERENCE_%s driver=%s GPU=%s" % ["FAILED" if _failed else "PASSED", runtime.rendering_driver, RenderingServer.get_video_adapter_name()])
	quit(1 if _failed else 0)

func _save(suffix: String) -> void:
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = _target.get_texture().get_image()
	if screenshot == null or screenshot.is_empty() or screenshot.save_png(_capture.get_basename() + "-" + suffix + ".png") != OK:
		_failed = true
		printerr("MATERIAL_REFERENCE_FAILED: " + suffix)
