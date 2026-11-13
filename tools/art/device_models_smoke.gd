extends SceneTree
## Vulkan inspection of imported cube/pressure-plate art, including moving parts and scaled instances.
## --capture <absolute PNG path>; writes idle, pressed and close-up frames alongside that path.

var _capture_path: String = "res://work/device-models.png"
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--capture":
		_capture_path = arguments[1]
	elif not arguments.is_empty():
		printerr("Expected --capture <absolute PNG path>")
		quit(2)
		return
	var runtime: RuntimeInfo = RuntimeProbe.new().read()
	if not ValidateRuntime.new().execute(runtime).is_empty():
		printerr("DEVICE_MODELS_SMOKE_FAILED: Vulkan Forward+ required")
		quit(1)
		return
	root.size = Vector2i(1440, 1000)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.15, 0.18)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.93)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	stage.add_child(light)
	var ground: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(10, 0.05, 10), Color(0.24, 0.26, 0.29))
	ground.position.y = -0.025
	stage.add_child(ground)
	var cube: Node3D = PropVisuals.ballast_cube(BallastCube.HEAVY_EDGE, true)
	cube.position = Vector3(-1.05, 0.375, 0)
	stage.add_child(cube)
	_check((_bounds(cube).size * cube.scale).is_equal_approx(Vector3.ONE * 0.75), "heavy art matches its 0.75 m hull")
	_check(_bounds(cube).get_center().length() < 0.0001, "cube pivot stays at body centre")
	_check(cube.find_children("*", "CollisionObject3D", true, false).is_empty(), "cube art adds no physics bodies")
	var small_cube: Node3D = PropVisuals.ballast_cube(BallastCube.LIGHT_EDGE)
	stage.add_child(small_cube)
	_check((_bounds(small_cube).size * small_cube.scale).is_equal_approx(Vector3.ONE * 0.50), "light art matches its 0.50 m hull")
	small_cube.hide()
	var button: FloorButtonDevice = FloorButtonDevice.new()
	button.position = Vector3(1.1, 0, 0)
	stage.add_child(button)
	_check_button(button)
	var scaled: FloorButtonDevice = FloorButtonDevice.new()
	scaled.plate_size = Vector3(1.0, 0.2, 1.0)
	scaled.rotation.z = PI * 0.5
	stage.add_child(scaled)
	_check_button(scaled)
	scaled.hide()
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.9
	camera.position = Vector3(3.8, 3.4, 5.2)
	stage.add_child(camera)
	camera.look_at(Vector3(0, 0.35, 0))
	button.show_output(false, 0.0)
	await _capture("idle")
	button.show_output(true, 0.0)
	await _capture("pressed")
	button.visible = false
	camera.size = 1.9
	camera.position = cube.position + Vector3(1.8, 1.4, 2.0)
	camera.look_at(cube.position)
	await _capture("cube")
	button.visible = true
	cube.visible = false
	camera.size = 2.65
	camera.position = button.position + Vector3(1.8, 2.2, 2.1)
	camera.look_at(button.position + Vector3(0, 0.04, 0))
	await _capture("button")
	button.show_output(false, 0.0)
	camera.position = button.position + Vector3(0, 4, 0.001)
	camera.look_at(button.position)
	await _capture("button-top")
	print("DEVICE_MODELS_SMOKE_%s driver=%s gpu=%s" % ["FAILED" if _failed else "PASSED",
		runtime.rendering_driver, RenderingServer.get_video_adapter_name()])
	stage.queue_free()
	await process_frame
	quit(1 if _failed else 0)


func _check_button(button: FloorButtonDevice) -> void:
	var model: Node3D = button.get_node("Model") as Node3D
	var plate: Node3D = model.get_node("Plate") as Node3D
	var frame: Node3D = model.get_node("Frame") as Node3D
	var collision: CollisionShape3D = button.plate.get_child(0) as CollisionShape3D
	if collision == null or not collision.shape is BoxShape3D:
		_check(false, "button needs its primitive box collider")
		return
	var shape: BoxShape3D = collision.shape as BoxShape3D
	_check(shape.size.is_equal_approx(button.plate_size), "button collider keeps its authored dimensions")
	_check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "button art adds no physics bodies")
	var bounds: AABB = _bounds(plate)
	_check(absf(bounds.end.y - 0.1) < 0.005 and absf(bounds.size.x - 1.4) < 0.03
		and absf(bounds.size.z - 1.4) < 0.03, "moving art matches the 1.4 m plate and its 10 cm rest height")
	button.show_output(false, 0.0)
	var rest: Vector3 = plate.global_position
	var fixed_frame: Transform3D = frame.global_transform
	button.show_output(true, 0.0)
	var displacement: Vector3 = button.global_basis.inverse() * (plate.global_position - rest)
	_check(displacement.is_equal_approx(Vector3(0, -0.03, 0)), "plate travels 3 cm at any scale and orientation")
	_check(frame.global_transform.is_equal_approx(fixed_frame), "button frame stays fixed when pressed")
	button.show_output(false, 0.0)
	_check(plate.global_position.is_equal_approx(rest), "plate returns to its rest position")


func _bounds(model: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	var visuals: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		visuals.append(model)
	for child: Node in visuals:
		var visual: MeshInstance3D = child as MeshInstance3D
		var bounds: AABB = (model.global_transform.affine_inverse() * visual.global_transform) * visual.get_aabb()
		result = bounds if first else result.merge(bounds)
		first = false
	return result


func _capture(suffix: String) -> void:
	for _frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	var path: String = _capture_path.get_basename() + "-" + suffix + ".png"
	_check(frame != null and not frame.is_empty() and frame.save_png(path) == OK, "save " + path)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("DEVICE_MODELS_SMOKE_FAILED: " + message)
