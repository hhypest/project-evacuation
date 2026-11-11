extends SceneTree
## Imported DEV-03/04/07, physical interaction bounds, moving parts and all six panel types on Vulkan.
## --capture <absolute PNG path>; saves overview and oblique state pairs beside that path.

var _capture_path: String = "res://work/wall-devices.png"
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
		printerr("WALL_DEVICES_SMOKE_FAILED: Vulkan Forward+ required")
		quit(1)
		return
	root.size = Vector2i(1440, 1000)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var environment_node: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.14, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.93)
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25, -25, 0)
	light.light_energy = 0.8
	light.shadow_enabled = true
	stage.add_child(light)
	var wall: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(3.2, 1.5, 0.05), Color(0.21, 0.23, 0.26))
	wall.position = Vector3(0.15, 0.05, -0.11)
	stage.add_child(wall)
	var button: WallButtonDevice = WallButtonDevice.new()
	button.position = Vector3(-1.0, 0.2, 0)
	stage.add_child(button)
	_check_control(button)
	var lever: WallButtonDevice = WallButtonDevice.new()
	lever.mode = DeviceDefinition.WallMode.TOGGLE
	lever.position = Vector3(-0.5, 0.2, 0)
	stage.add_child(lever)
	_check_control(lever)
	var tilted: WallButtonDevice = WallButtonDevice.new()
	tilted.rotation_degrees = Vector3(30, 70, 90)
	stage.add_child(tilted)
	_check_control(tilted)
	tilted.queue_free()
	var panels: Array[LogicDevice] = []
	var kinds: Array[DeviceDefinition.Kind] = [DeviceDefinition.Kind.SOURCE, DeviceDefinition.Kind.AND,
		DeviceDefinition.Kind.OR, DeviceDefinition.Kind.NOT, DeviceDefinition.Kind.DELAY, DeviceDefinition.Kind.LATCH]
	for index: int in range(kinds.size()):
		var panel: LogicDevice = LogicDevice.new()
		panel.kind = kinds[index]
		panel.position = Vector3(0.1 + float(index % 3) * 0.55, 0.35 - floorf(float(index) / 3.0) * 0.58, 0)
		stage.add_child(panel)
		panels.append(panel)
		_check(panel.find_children("*", "CollisionObject3D", true, false).is_empty(), "panel adds no physics")
		var label: Label3D = panel.get_node("TypeLabel") as Label3D
		var plate: Node3D = panel.get_node("TypePlate") as Node3D
		_check(label.text == panel.symbol() and label.position.z > plate.position.z,
			"each logic kind has its own readable type label ahead of its plate")
		var model: Node3D = panel.get_node("Model") as Node3D
		var visual: MeshInstance3D = model.get_node("Body") as MeshInstance3D
		var bounds: AABB = (panel.global_transform.affine_inverse() * visual.global_transform) * visual.get_aabb()
		_check(plate.position.z - 0.002 > bounds.end.z, "type plate is in front of the imported lid")
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.65
	camera.position = Vector3(0.1, 0.05, 3)
	stage.add_child(camera)
	camera.look_at(Vector3(0.1, 0.05, 0))
	await _capture("off")
	button.show_output(true, 0.0)
	lever.show_output(true, 0.0)
	for panel: LogicDevice in panels:
		panel.show_output(true, 0.0)
	await _capture("on")
	# Close oblique views reveal the stationary cover and the handle rotating around its horizontal axle.
	for control: WallButtonDevice in [button, lever]:
		camera.size = 0.8
		camera.position = control.position + Vector3(0.5, 0.18, 1.0)
		camera.look_at(control.position)
		control.show_output(false, 0.0)
		await _capture("switch-off" if control == lever else "button-off")
		control.show_output(true, 0.0)
		await _capture("switch-on" if control == lever else "button-on")
	print("WALL_DEVICES_SMOKE_%s driver=%s gpu=%s" % ["FAILED" if _failed else "PASSED",
		runtime.rendering_driver, RenderingServer.get_video_adapter_name()])
	quit(1 if _failed else 0)


func _check_control(control: WallButtonDevice) -> void:
	var collision: CollisionShape3D = control.body.get_child(0) as CollisionShape3D
	var shape: BoxShape3D = collision.shape as BoxShape3D
	_check(shape != null and shape.size.is_equal_approx(Vector3(0.36, 0.5, 0.16)), "authored interaction box is preserved")
	var model: Node3D = control.get_node("Housing") as Node3D
	_check(model.find_children("*", "CollisionObject3D", true, false).is_empty(), "art adds no physics bodies")
	var fixed: Node3D = model.get_node("Body") as Node3D
	var fixed_transform: Transform3D = fixed.global_transform
	var toggle: bool = control.mode == DeviceDefinition.WallMode.TOGGLE
	var moving: Node3D = model.get_node("Lever" if toggle else "Key") as Node3D
	control.show_output(false, 0.0)
	var rest: Transform3D = moving.global_transform
	var pivot: Vector3 = moving.position
	control.show_output(true, 0.0)
	if toggle:
		_check(moving.position.is_equal_approx(pivot), "switch hinge stays fixed")
		_check(moving.basis.x.is_equal_approx(Vector3.RIGHT) and not moving.global_basis.is_equal_approx(rest.basis),
			"handle rotates around its horizontal axle")
	else:
		var displacement: Vector3 = control.global_basis.inverse() * (moving.global_position - rest.origin)
		_check(displacement.is_equal_approx(Vector3(0, 0, -0.015)), "key presses 1.5 cm along the local wall normal")
	var active: Transform3D = moving.global_transform
	control.show_output(true, 0.0)
	_check(moving.global_transform.is_equal_approx(active), "repeated output does not accumulate movement")
	_check(fixed.global_transform.is_equal_approx(fixed_transform), "housing and safety cover stay fixed")
	control.show_output(false, 0.0)
	_check(moving.global_transform.is_equal_approx(rest), "reset restores the complete moving-part transform")


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
		printerr("WALL_DEVICES_SMOKE_FAILED: " + message)
