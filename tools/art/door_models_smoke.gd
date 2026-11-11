extends SceneTree
## DEV-12/13 in Vulkan: both faces, complete travel, scaling and the original physical leaf boxes.

var _capture_path: String = "res://work/door-models.png"
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--capture":
		_capture_path = args[1]
	elif not args.is_empty():
		quit(2)
		return
	var runtime: RuntimeInfo = RuntimeProbe.new().read()
	if not ValidateRuntime.new().execute(runtime).is_empty():
		printerr("DOOR_MODELS_SMOKE_FAILED Vulkan Forward+ required")
		quit(1)
		return
	root.size = Vector2i(1440, 1000)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.92, 0.95)
	env.ambient_light_energy = 0.45
	env_node.environment = env
	stage.add_child(env_node)
	for yaw: float in [-25.0, 155.0]:
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, yaw, 0)
		light.light_energy = 0.75
		stage.add_child(light)
	var ground: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(12, 0.05, 10), Color(0.18, 0.20, 0.23))
	ground.position.y = -0.03
	stage.add_child(ground)
	var door: DoorDevice = DoorDevice.new()
	stage.add_child(door)
	var frame: Node3D = door.get_node("FrameModel") as Node3D
	_check(frame.find_children("*", "CollisionObject3D", true, false).is_empty(), "decorative frame adds no colliders")
	var left: AnimatableBody3D = door.get_node("LeafL") as AnimatableBody3D
	var right: AnimatableBody3D = door.get_node("LeafR") as AnimatableBody3D
	var collision: CollisionShape3D = left.get_child(0) as CollisionShape3D
	var shape: BoxShape3D = collision.shape as BoxShape3D
	_check(shape.size.is_equal_approx(Vector3(1, 2.6, 0.15)), "physical leaf size preserved")
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.0
	stage.add_child(camera)
	camera.position = Vector3(3.6, 2.8, 6)
	camera.look_at(Vector3(0, 1.4, 0))
	await _capture("front-closed")
	var fixed: Transform3D = frame.global_transform
	door.show_output(true, 1.0)
	await _capture("front-open")
	_check(door.is_open() and left.position.x <= -1.499 and right.position.x >= 1.499, "both leaves clear the full aperture")
	_check(frame.global_transform.is_equal_approx(fixed), "frame stays fixed through the opening cycle")
	camera.position = Vector3(-3.6, 2.8, -6)
	camera.look_at(Vector3(0, 1.4, 0))
	await _capture("back-open")
	door.show_output(false, 1.0)
	await _capture("back-closed")
	_check(door.openness < 0.001 and is_equal_approx(left.position.x, -0.5) and is_equal_approx(right.position.x, 0.5),
		"unpowered clear door returns to its closed pose")
	print("DOOR_MODELS_SMOKE_%s driver=%s gpu=%s" % ["FAILED" if _failed else "PASSED",
		runtime.rendering_driver, RenderingServer.get_video_adapter_name()])
	quit(1 if _failed else 0)


func _capture(suffix: String) -> void:
	for frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image != null and image.save_png(_capture_path.get_basename() + "-" + suffix + ".png") == OK, "capture " + suffix)


func _check(passed: bool, description: String) -> void:
	if not passed:
		_failed = true
		printerr("DOOR_MODELS_SMOKE_FAILED " + description)
