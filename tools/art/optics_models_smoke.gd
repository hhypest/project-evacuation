extends SceneTree
## Vulkan views and real ray checks for DEV-05/DEV-06. --capture <absolute PNG path>.

var _capture_path: String = "res://work/optics-models.png"
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
		printerr("OPTICS_MODELS_SMOKE_FAILED: Vulkan Forward+ required")
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
	environment.ambient_light_energy = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	stage.add_child(environment_node)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	stage.add_child(light)
	var ground: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(8, 0.05, 8), Color(0.24, 0.26, 0.29))
	ground.position.y = -0.55
	stage.add_child(ground)
	var emitter: EmitterDevice = EmitterDevice.new()
	emitter.position.x = -0.9
	emitter.rotation.y = -PI * 0.5
	stage.add_child(emitter)
	var support: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(0.35, 0.2835, 0.5), Color(0.20, 0.22, 0.25))
	support.position = Vector3(emitter.position.x, -0.38325, 0)
	stage.add_child(support)
	var receiver: ReceiverDevice = ReceiverDevice.new()
	receiver.position.x = 0.9
	receiver.rotation.y = -PI * 0.5
	stage.add_child(receiver)
	_check_collider(emitter.body, EmitterDevice.HOUSING)
	_check_collider(receiver.body, ReceiverDevice.PLATE)
	for device: PuzzleDeviceNode in [emitter, receiver]:
		_check(device.get_node("Model").find_children("*", "CollisionObject3D", true, false).is_empty(),
			"art models add no physical bodies")
	var lens: Node3D = emitter.get_node("Lens") as Node3D
	var hit_lens: Node3D = receiver.get_node("HitLens") as Node3D
	_check((lens.global_position - emitter.muzzle()).cross(emitter.direction()).length() < 0.0001,
		"emitter lens lies on the firing axis")
	_check((hit_lens.global_position - emitter.muzzle()).cross(emitter.direction()).length() < 0.0001,
		"receiver optical centre lies on the incoming beam")
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 48.0
	camera.position = Vector3(0, 1.4, 2.6)
	stage.add_child(camera)
	camera.look_at(Vector3(0, -0.05, 0))
	emitter.show_output(false, 0.0)
	receiver.show_output(false, 0.0)
	await _capture("off")
	for _tick: int in range(5):
		await physics_frame
	# The raw ray result is checked at this Godot boundary; it is never passed into game rules.
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		emitter.muzzle(), emitter.muzzle() + emitter.direction() * 5.0, 7, [emitter.body.get_rid()])
	var hit: Dictionary = emitter.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Object = _hit_collider(hit)
	_check(receiver.owns(collider), "real ray reaches the unchanged receiver collider")
	if hit.get("position") is Vector3:
		var point: Vector3 = hit["position"]
		emitter.show_beam(emitter.muzzle().distance_to(point))
	else:
		_check(false, "ray has a hit position")
	emitter.show_output(true, 0.0)
	receiver.show_output(true, 0.0)
	var beam: MeshInstance3D = emitter.get_node("Beam") as MeshInstance3D
	_check((beam.global_transform * Vector3(0, 0, 0.5)).distance_to(lens.global_position) < 0.0001,
		"visible beam starts on the emitter lens")
	_check((beam.global_transform * Vector3(0, 0, -0.5)).distance_to(hit_lens.global_position) < 0.005,
		"visible beam ends on the receiving optical surface")
	await _capture("hit")
	var blocker: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(0.25, 0.65, 0.65), Color(0.19, 0.21, 0.24), Vector3.ZERO)
	stage.add_child(blocker)
	for _tick: int in range(5):
		await physics_frame
	hit = emitter.get_world_3d().direct_space_state.intersect_ray(query)
	_check(_hit_collider(hit) == blocker, "a physical obstruction takes the first hit")
	if hit.get("position") is Vector3:
		var point: Vector3 = hit["position"]
		emitter.show_beam(emitter.muzzle().distance_to(point))
	receiver.show_output(false, 0.0)
	await _capture("blocked")
	blocker.queue_free()
	receiver.visible = false
	emitter.show_beam(0.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.05
	camera.position = emitter.position + Vector3(1.0, 0.55, 1.3)
	camera.look_at(emitter.position)
	await _capture("emitter")
	receiver.visible = true
	emitter.visible = false
	support.visible = false
	receiver.show_output(true, 0.0)
	camera.position = receiver.position + Vector3(-1.0, 0.45, 1.4)
	camera.look_at(receiver.position + Vector3(0, -0.05, 0))
	await _capture("receiver")
	print("OPTICS_MODELS_SMOKE_%s driver=%s gpu=%s" % ["FAILED" if _failed else "PASSED",
		runtime.rendering_driver, RenderingServer.get_video_adapter_name()])
	quit(1 if _failed else 0)


func _check_collider(body: StaticBody3D, expected: Vector3) -> void:
	var collider: CollisionShape3D = body.get_child(0) as CollisionShape3D
	var shape: BoxShape3D = collider.shape as BoxShape3D
	_check(shape != null and shape.size.is_equal_approx(expected), "authored box collision is preserved")


func _hit_collider(hit: Dictionary) -> Object:
	var candidate: Variant = hit.get("collider")
	if candidate is not Object:
		return null
	# Godot ray-query dictionary: the type is checked above before entering the typed comparison.
	@warning_ignore("unsafe_cast")
	return candidate as Object


func _capture(suffix: String) -> void:
	for _frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	_check(frame != null and not frame.is_empty()
		and frame.save_png(_capture_path.get_basename() + "-" + suffix + ".png") == OK, "save " + suffix)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("OPTICS_MODELS_SMOKE_FAILED: " + message)
