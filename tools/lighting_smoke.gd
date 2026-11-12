extends SceneTree
## Real Vulkan images of the seventh bay, including a measured floor shadow and live switch routing.
## --capture <absolute PNG path>; captures use the actual level without hiding its roofs or blockers.

const LAB: PackedScene = preload("res://content/levels/mechanics_lab.tscn")
const GENERATION: int = 171
var _scope: LevelScope
var _player: PlayerMotor
var _camera: LookCamera
var _bay: MechanicsLightingBay
var _path: String = "res://work/lighting.png"
var _finished: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(150, true, false, true).timeout.connect(_timeout)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--capture":
		_path = args[1]
	elif not args.is_empty():
		quit(2)
		return
	var runtime: RuntimeInfo = RuntimeProbe.new().read()
	if not _check(ValidateRuntime.new().execute(runtime).is_empty(), "Vulkan Forward+ required"):
		return
	root.size = Vector2i(1280, 720)
	_scope = LevelScope.new()
	root.add_child(_scope)
	if not _check(_scope.open(LAB, GENERATION), "complete proving ground loads"):
		return
	var level: Node3D = _scope.get_child(0) as Node3D
	_bay = level.get_node("Lighting") as MechanicsLightingBay
	_player = level.get_node("Player") as PlayerMotor
	_camera = level.get_node("Camera") as LookCamera
	await _ticks(5)
	_camera.global_position = _bay.to_global(Vector3(-8, 1.65, 7.5))
	_camera.look_at(_bay.to_global(Vector3(-8, 1.8, 4.7)), Vector3.UP)
	if await _capture("controls") == null:
		return
	await _press("stop")
	await _press("spot")
	if not _check(_bay.motion_stopped and _bay.point.visible and not _bay.spot.visible,
		"interaction ray freezes the point and independently disables the spot"):
		return
	# A fixed source pose makes the pixel comparison repeatable after real switch interactions.
	_bay.phase = 0
	_bay.point.position = Vector3(0, 4, 3)
	_set_view()
	var shadow: Image = await _capture("point-shadows")
	await _press("shadows")
	_set_view()
	var clear: Image = await _capture("point-no-shadows")
	if shadow == null or clear == null:
		return
	var largest_drop: float = 0.0
	for x: float in [-0.4, 0.0, 0.4]:
		for z: float in [-2.5, -3.5, -4.5]:
			var pixel: Vector2 = _camera.unproject_position(_bay.to_global(Vector3(x, 0.045, z)))
			largest_drop = maxf(largest_drop, _luminance(clear, pixel) - _luminance(shadow, pixel))
	print("LIGHTING_SHADOW_DELTA luminance=%.4f" % largest_drop)
	if not _check(largest_drop > 0.04, "enabling shadow maps visibly darkens the floor behind the physical pillar"):
		return
	await _press("shadows")
	await _press("point")
	await _press("spot")
	_set_view()
	if await _capture("spot-shadows") == null:
		return
	await _press("spot")
	_set_view()
	if await _capture("sources-off") == null:
		return
	await _press("point")
	await _press("spot")
	await _press("stop")
	_set_view()
	var before: Vector3 = _bay.point.position
	if await _capture("moving-both") == null:
		return
	if not _check(not _bay.motion_stopped and not before.is_equal_approx(_bay.point.position)
		and _bay.point.visible and _bay.spot.visible and _bay.point.shadow_enabled and _bay.spot.shadow_enabled,
		"switches restore moving direct lights and both shadow maps"):
		return
	if not await _reference():
		return
	_scope.close()
	await process_frame
	_finished = true
	print("LIGHTING_SMOKE_PASSED driver=%s gpu=%s shadow_delta=%.4f" % [runtime.rendering_driver,
		RenderingServer.get_video_adapter_name(), largest_drop])
	quit(0)


func _reference() -> bool:
	await _press("stop")
	var control: WallButtonDevice = _bay.get_node("ReferenceSwitch") as WallButtonDevice
	_player.global_position = control.global_position + Vector3(0, -1.3, 1.3)
	await _ticks(3)
	_camera.look_at(control.global_position, Vector3.UP)
	if await _capture("reference-off") == null:
		return false
	await _ticks(1, true)
	var lamp: MeshInstance3D = control.get_node("Indicator/Lamp") as MeshInstance3D
	var material: StandardMaterial3D = lamp.material_override as StandardMaterial3D
	if not _check(material.emission_enabled, "real E interaction lights DEV-04 reference lens"):
		return false
	if await _capture("reference-on") == null:
		return false
	_camera.global_position = _bay.to_global(Vector3(8.3, 1.65, -1.8))
	_camera.look_at(_bay.to_global(Vector3(8.3, 1.3, -5.5)))
	if await _capture("reference-overview") == null:
		return false
	_scope.puzzle().reset()
	return _check(not material.emission_enabled, "network reset extinguishes DEV-04 reference lens")


func _set_view() -> void:
	_camera.global_position = _bay.to_global(Vector3(-4, 3.2, 6))
	_camera.look_at(_bay.to_global(Vector3(0, 0.6, -2)), Vector3.UP)


func _press(suffix: String) -> void:
	var button: Node3D = _bay.get_node("qa_lighting_" + suffix) as Node3D
	_player.global_position = Vector3(button.global_position.x, 0.05, button.global_position.z) + button.global_basis.z * 1.3
	await _ticks(3)
	_camera.look_at(button.global_position, Vector3.UP)
	await _ticks(1, true)


func _ticks(count: int, interact: bool = false) -> void:
	for tick: int in range(count):
		await physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = GENERATION
		frame.interact_requested = interact and tick == 0
		_scope.apply_input(frame)


func _capture(suffix: String) -> Image:
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if not _check(image != null and not image.is_empty()
		and image.save_png(_path.get_basename() + "-" + suffix + ".png") == OK, "capture " + suffix):
		return null
	return image


func _luminance(image: Image, pixel: Vector2) -> float:
	var viewport_size: Vector2 = root.get_visible_rect().size
	var at: Vector2i = Vector2i(pixel * Vector2(image.get_size()) / viewport_size)
	var sum: float = 0.0
	for x: int in range(-2, 3):
		for y: int in range(-2, 3):
			sum += image.get_pixel(clampi(at.x + x, 0, image.get_width() - 1),
				clampi(at.y + y, 0, image.get_height() - 1)).get_luminance()
	return sum / 25.0


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_finished = true
		printerr("LIGHTING_SMOKE_FAILED: " + message)
		quit(1)
	return condition


func _timeout() -> void:
	if not _finished:
		_check(false, "timeout")
