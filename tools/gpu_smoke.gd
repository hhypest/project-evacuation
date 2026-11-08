extends SceneTree
## Real-display check of session, cursor capture, focus notifications and look.

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")
var _finished: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(30.0, true, false, true).timeout.connect(_on_timeout)
	var info: RuntimeInfo = RuntimeProbe.new().read()
	if not _check(ValidateRuntime.new().execute(info).is_empty(), "real Vulkan runtime required"):
		return
	var capture: String = "res://work/gpu_smoke.png"
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--capture":
		capture = arguments[1]
	elif not arguments.is_empty():
		_check(false, "Expected --capture <absolute image path>")
		return
	var main: SessionBootstrap = MAIN.instantiate() as SessionBootstrap
	if not _check(main != null, "typed bootstrap"):
		return
	root.add_child(main)
	for _frame: int in range(120):
		if main.get_session_status().can_start:
			break
		await process_frame
	if not _check(main.get_session_status().can_start, "focused start menu"):
		return
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-menu.png"):
		return
	TestInputEvents.key(KEY_ENTER)
	TestInputEvents.key(KEY_ENTER, false)
	if not _check(main.get_session_status().accepts_gameplay and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"start must capture the mouse"):
		return
	for _tick: int in range(150):
		await physics_frame
	var player: PlayerMotor = main.get_node("LevelScope/FoundationLab/Player") as PlayerMotor
	if not _check(player != null, "physical player"):
		return
	var origin: Vector3 = player.position
	TestInputEvents.key(KEY_D)
	for _tick: int in range(30):
		await physics_frame
	TestInputEvents.key(KEY_D, false)
	for _tick: int in range(20):
		await physics_frame
	TestInputEvents.key(KEY_W)
	for _tick: int in range(30):
		await physics_frame
	TestInputEvents.key(KEY_SPACE)
	for _tick: int in range(6):
		await physics_frame
	TestInputEvents.key(KEY_SPACE, false)
	TestInputEvents.key(KEY_CTRL)
	for _tick: int in range(8):
		await physics_frame
	if not _check(player.position.x > origin.x + 2 and player.position.z < origin.z - 2
		and player.position.y > 0.7 and player.crouched, "keyboard movement, jump and duck jump"):
		return
	TestInputEvents.key(KEY_CTRL, false)
	TestInputEvents.key(KEY_W, false)
	for _tick: int in range(60):
		await physics_frame
	var camera: LookCamera = main.get_node("LevelScope/FoundationLab/Camera") as LookCamera
	if not _check(camera != null, "first-person look camera"):
		return
	var before: Vector3 = camera.rotation
	TestInputEvents.motion(Vector2(1, 0))
	TestInputEvents.motion(Vector2(20, -5))
	for _tick: int in range(3):
		await physics_frame
	if not _check(not camera.rotation.is_equal_approx(before), "mouse look receives relative motion"):
		return
	TestInputEvents.key(KEY_W)
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	if not _check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		and not Input.is_action_pressed(&"move_forward"), "pause releases cursor and held input"):
		return
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-pause.png"):
		return
	root.focus_exited.emit()
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	if not _check(paused and not main.get_session_status().can_resume, "unfocused window refuses resume"):
		return
	root.focus_entered.emit()
	if not _check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus return never auto-captures"):
		return
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	if not _check(not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "explicit resume recaptures"):
		return
	TestInputEvents.key(KEY_W, false)
	TestInputEvents.key(KEY_R)
	TestInputEvents.key(KEY_R, false)
	if not _check(main.get_session_status().generation == 2, "restart advances scope generation"):
		return
	for _tick: int in range(150):
		await physics_frame
	await RenderingServer.frame_post_draw
	var carry_scope: LevelScope = main.get_node("LevelScope") as LevelScope
	var carry_camera: LookCamera = carry_scope.get_node("FoundationLab/Camera") as LookCamera
	var cube: CarryRigidBody = carry_scope.get_node("FoundationLab/TestCube") as CarryRigidBody
	TestInputEvents.key(KEY_W)
	for _tick: int in range(30):
		await physics_frame
	TestInputEvents.key(KEY_W, false)
	for _tick: int in range(20):
		await physics_frame
	var to_cube: Vector3 = cube.global_position - carry_camera.global_position
	var pitch: float = atan2(to_cube.y, Vector2(to_cube.x, to_cube.z).length())
	TestInputEvents.motion(Vector2(1, 0))
	TestInputEvents.motion(Vector2(0, (carry_camera.rotation.x - pitch) / carry_camera.radians_per_pixel))
	for _tick: int in range(3):
		await physics_frame
	TestInputEvents.key(KEY_E)
	TestInputEvents.key(KEY_E, false)
	for _tick: int in range(75):
		await physics_frame
	if not _check(carry_scope.held_prop_id() == &"lab.cube.medium" and cube.is_carried(), "E acquires a real physical cube"):
		return
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-carry.png"):
		return
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT)
	for _tick: int in range(3):
		await physics_frame
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT, false)
	if not _check(carry_scope.held_prop_id().is_empty() and cube.linear_velocity.length() > 2, "mouse throws and releases cube"):
		return
	await RenderingServer.frame_post_draw
	if not _capture(capture):
		return
	# Devices (SKL-04/05): the fixture moves the player to the timed wall button, the press is a real E event.
	var lab: Node3D = carry_scope.get_node("FoundationLab/PuzzleLab") as Node3D
	var button: WallButtonDevice = lab.get_node("lab_button_timed") as WallButtonDevice
	var door: DoorDevice = lab.get_node("lab_door_timed") as DoorDevice
	if not _check(button != null and door != null, "device lab with wall button and door"):
		return
	var lab_player: PlayerMotor = carry_scope.get_node("FoundationLab/Player") as PlayerMotor
	var front: Vector3 = button.global_basis.z.normalized()
	lab_player.global_position = Vector3(button.global_position.x, 0.05, button.global_position.z) + front * 1.3
	for _tick: int in range(20):
		await physics_frame
	carry_camera.look_at(button.global_position + Vector3(0, -0.05, 0) + front * 0.05)
	TestInputEvents.key(KEY_E)
	TestInputEvents.key(KEY_E, false)
	for _tick: int in range(60):
		await physics_frame
	if not _check(door.is_open() and carry_scope.held_prop_id().is_empty(), "E on a wall button opens its door"):
		return
	carry_camera.look_at(door.global_position + Vector3(0, 1.3, 0))
	for _tick: int in range(3):
		await physics_frame
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-devices.png"):
		return
	_finished = true
	print("GPU_SMOKE_PASSED driver=%s gpu=%s carry=grab/hold/throw devices=button/door movement=strafe/run/jump/duck session=menu/pause/focus/restart/quit image=%s" % [
		info.rendering_driver, RenderingServer.get_video_adapter_name(), capture
	])
	# Exercise the same close signal used by the window manager; Bootstrap owns cleanup.
	root.close_requested.emit()


func _capture(path: String) -> bool:
	var image: Image = root.get_texture().get_image()
	return _check(image != null and not image.is_empty() and image.save_png(path) == OK,
		"save Vulkan frame " + path)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("GPU_SMOKE_FAILED: " + message)
		_finished = true
		quit(1)
	return condition


func _on_timeout() -> void:
	if not _finished:
		printerr("GPU_SMOKE_TIMEOUT")
		quit(3)
