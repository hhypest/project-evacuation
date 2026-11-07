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
	if not _capture(capture):
		return
	_finished = true
	print("GPU_SMOKE_PASSED driver=%s gpu=%s session=menu/start/pause/focus/resume/restart/quit image=%s" % [
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
