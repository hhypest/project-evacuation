extends SceneTree
## Real-display check. Never run with --headless or substitute a software backend.

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var info: RuntimeInfo = RuntimeProbe.new().read()
	var errors: PackedStringArray = ValidateRuntime.new().execute(info)
	if not errors.is_empty():
		printerr("GPU_SMOKE_FAILED: " + "; ".join(errors))
		quit(1)
		return
	var main: Node = MAIN.instantiate()
	root.add_child(main)
	for _tick: int in range(150):
		await physics_frame
	await RenderingServer.frame_post_draw
	var capture: String = "res://work/gpu_smoke.png"
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--capture":
		capture = arguments[1]
	elif not arguments.is_empty():
		printerr("Expected --capture <absolute image path>")
		quit(2)
		return
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(capture) != OK:
		printerr("Could not save Vulkan frame: " + capture)
		quit(1)
		return
	var pause_event: InputEventAction = InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	Input.parse_input_event(pause_event)
	await process_frame
	if not paused:
		printerr("Pause input did not reach the session")
		quit(1)
		return
	var restart_event: InputEventAction = InputEventAction.new()
	restart_event.action = &"restart_test"
	restart_event.pressed = true
	Input.parse_input_event(restart_event)
	await process_frame
	if paused:
		printerr("Restart did not resume simulation")
		quit(1)
		return
	print("GPU_SMOKE_PASSED driver=%s gpu=%s image=%s" % [
		info.rendering_driver, RenderingServer.get_video_adapter_name(), capture
	])
	root.remove_child(main)
	main.queue_free()
	await process_frame
	quit(0)
