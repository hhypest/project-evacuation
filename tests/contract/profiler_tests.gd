class_name ProfilerTests
extends TestSuite

const PUBLICATION_STALL_MS: int = 80
var _publication_stalled: bool = false
var _following_window_max_ms: float = -1.0


func suite_name() -> StringName:
	return &"contract"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var summary: ProfilerSample = ProfilerSample.summarize([10.0, 20.0, 30.0, 40.0])
	results.append(TestOutcome.new("profiler derives FPS from frame time and uses nearest-rank p95",
		summary.frame_count == 4 and is_equal_approx(summary.fps, 40.0)
		and is_equal_approx(summary.frame_mean_ms, 25.0) and is_equal_approx(summary.frame_p95_ms, 40.0)))
	var invalid: ProfilerSample = ProfilerSample.summarize([0.0, -1.0, NAN, INF])
	results.append(TestOutcome.new("invalid and empty timer windows never produce NaN statistics",
		invalid.frame_count == 0 and invalid.fps == 0.0 and invalid.frame_p95_ms == 0.0))
	var profiler: RuntimeProfiler = RuntimeProfiler.new()
	tree.root.add_child(profiler)
	results.append(TestOutcome.new("hidden inactive profiler does not sample or record",
		not profiler.is_processing() and not profiler.recording))
	var directory: String = "res://work/profiler-test-%d" % Time.get_ticks_usec()
	profiler.level_label = "Тест, CSV"
	profiler.generation = 7
	var opened: bool = profiler.start_recording(directory)
	await tree.create_timer(0.65, true).timeout
	profiler.stop_recording()
	var path: String = profiler.report_path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line() if file != null else PackedStringArray()
	var row: PackedStringArray = file.get_csv_line() if file != null else PackedStringArray()
	results.append(TestOutcome.new("profiler writes a nonempty UTF-8 CSV with quoted level names",
		opened and header == RuntimeProfiler.HEADER and row.size() == header.size()
		and row[1] == "Тест, CSV" and row[8].to_float() > 0.0
		and row[header.find("generation")] == "7" and row[header.find("active_viewports")] == "0"))
	if file != null:
		file.close()
	var refused: bool = not profiler.start_recording("res://project.godot/profiles")
	results.append(TestOutcome.new("an unwritable report path is rejected without starting recording",
		refused and not profiler.recording and not profiler.last_error.is_empty()))
	profiler.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	results.append(await _publication_continuity(tree))
	var hud: ProfilerHud = ProfilerHud.new()
	tree.root.add_child(hud)
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	results.append(TestOutcome.new("F3 also accepts a logical function key without a physical keycode", hud.panel_visible))
	var before: bool = hud.panel_visible
	key = InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	key.ctrl_pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	results.append(TestOutcome.new("modified function keys do not toggle diagnostics", hud.panel_visible == before))
	key = InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	hud.queue_free()
	await tree.process_frame
	return results


func _publication_continuity(tree: SceneTree) -> TestOutcome:
	_publication_stalled = false
	_following_window_max_ms = -1.0
	var profiler: RuntimeProfiler = RuntimeProfiler.new()
	tree.root.add_child(profiler)
	profiler.sampled.connect(_stall_first_publication)
	profiler.set_panel_visible(true)
	var deadline: int = Time.get_ticks_msec() + 3000
	while _following_window_max_ms < 0.0 and Time.get_ticks_msec() < deadline:
		await tree.process_frame
	profiler.set_panel_visible(false)
	profiler.queue_free()
	await tree.process_frame
	return TestOutcome.new("publication stalls remain in the following frame window",
		_publication_stalled and _following_window_max_ms >= float(PUBLICATION_STALL_MS),
		"injected=%d ms measured_max=%.3f ms" % [PUBLICATION_STALL_MS, _following_window_max_ms])


func _stall_first_publication(sample: ProfilerSample) -> void:
	if sample.frame_count == 0:
		return
	if not _publication_stalled:
		_publication_stalled = true
		# Reproduce blocking CSV/HUD work in the actual publication callback, without a fake clock.
		OS.delay_msec(PUBLICATION_STALL_MS)
	elif _following_window_max_ms < 0.0:
		_following_window_max_ms = sample.frame_max_ms
