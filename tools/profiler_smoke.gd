extends SceneTree
## Real Vulkan profiling/input check. --capture <PNG path> --report <CSV path>.

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 4 or args[0] != "--capture" or args[2] != "--report":
		printerr("Expected --capture <PNG path> --report <CSV path>")
		quit(2)
		return
	var info: RuntimeInfo = RuntimeProbe.new().read()
	if not ValidateRuntime.new().execute(info).is_empty():
		printerr("PROFILER_SMOKE_FAILED: Vulkan required")
		quit(1)
		return
	var main: SessionBootstrap = MAIN.instantiate() as SessionBootstrap
	root.add_child(main)
	for _frame: int in range(120):
		if main.get_session_status().can_start:
			break
		await process_frame
	_check(main.get_session_status().can_start, "focused menu")
	var profiler: RuntimeProfiler = main.get_node("RuntimeProfiler") as RuntimeProfiler
	var hud: ProfilerHud = main.get_node("ProfilerHud") as ProfilerHud
	_check(not profiler.is_processing() and not hud.panel_visible, "diagnostics off by default")
	_key(KEY_ENTER)
	for _tick: int in range(90):
		await physics_frame
	_key(KEY_F3)
	await create_timer(0.8, true).timeout
	_check(hud.panel_visible and not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"F3 shows diagnostics without pausing or releasing the mouse")
	_key(KEY_F4)
	await create_timer(1.2, true).timeout
	var active: ProfilerSample = profiler.latest
	_check(profiler.recording and active.fps > 0.0 and active.render_gpu_ms > 0.0
		and active.texture_bytes > 0 and active.frame_count > 0, "real GPU timings and texture memory")
	print("PROFILE_MEASURE profile=%s textures=%d video=%d gpu_ms=%.3f fps=%.1f" % [
		active.texture_profile, active.texture_bytes, active.video_bytes, active.render_gpu_ms, active.fps])
	_key(KEY_ESCAPE)
	await create_timer(0.7, true).timeout
	_check(paused and profiler.latest.paused, "paused samples are labelled")
	_key(KEY_F3)
	_check(not hud.panel_visible and profiler.is_processing() and profiler.recording,
		"hiding the panel keeps CSV recording active")
	_key(KEY_F4)
	_check(not profiler.recording and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"F4 stops and flushes without resuming the session")
	root.focus_exited.emit()
	_key(KEY_F3)
	_key(KEY_F3)
	_check(paused and not main.get_session_status().can_resume, "diagnostic keys never override focus gating")
	root.focus_entered.emit()
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	_check(frame != null and frame.save_png(args[1]) == OK, "capture diagnostic panel")
	var file: FileAccess = FileAccess.open(profiler.report_path, FileAccess.READ)
	_check(file != null, "report is readable after stopping")
	var rows: int = 0
	if file != null:
		_check(file.get_csv_line() == RuntimeProfiler.HEADER, "stable CSV header")
		while not file.eof_reached():
			var row: PackedStringArray = file.get_csv_line()
			if row.size() == RuntimeProfiler.HEADER.size():
				rows += 1
		file.close()
	_check(rows >= 3, "CSV has gameplay and pause samples")
	_check(DirAccess.copy_absolute(profiler.report_path, args[3]) == OK, "copy review report")
	DirAccess.remove_absolute(profiler.report_path)
	# New portal viewports must be registered, and freed viewports must be safe across a restart.
	var menu: FoundationHud = main.get_node("FoundationHud") as FoundationHud
	menu.menu_requested.emit()
	menu.level_requested.emit(0)
	_key(KEY_F4)
	# One half-second interval discovers deferred children; the next publishes their counters.
	await create_timer(1.3, true).timeout
	_check(profiler.latest.viewport_count >= 3, "portal SubViewports are included")
	_key(KEY_R)
	await create_timer(1.3, true).timeout
	_check(main.get_session_status().accepts_gameplay and profiler.latest.viewport_count >= 3,
		"profiler survives freeing and recreating portal viewports")
	profiler.stop_recording()
	DirAccess.remove_absolute(profiler.report_path)
	print("PROFILER_SMOKE_%s gpu=%s rows=%d" % ["FAILED" if _failed else "PASSED", active.gpu, rows])
	root.close_requested.emit()
	if _failed:
		quit(1)


func _key(code: Key) -> void:
	TestInputEvents.key(code)
	TestInputEvents.key(code, false)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failed = true
		printerr("PROFILER_SMOKE_FAILED: " + label)
