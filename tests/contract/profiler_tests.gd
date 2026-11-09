class_name ProfilerTests
extends TestSuite


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
	var opened: bool = profiler.start_recording(directory)
	await tree.create_timer(0.65, true).timeout
	profiler.stop_recording()
	var path: String = profiler.report_path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var header: PackedStringArray = file.get_csv_line() if file != null else PackedStringArray()
	var row: PackedStringArray = file.get_csv_line() if file != null else PackedStringArray()
	results.append(TestOutcome.new("profiler writes a nonempty UTF-8 CSV with quoted level names",
		opened and header == RuntimeProfiler.HEADER and row.size() == header.size()
		and row[1] == "Тест, CSV" and row[8].to_float() > 0.0))
	if file != null:
		file.close()
	var refused: bool = not profiler.start_recording("res://project.godot/profiles")
	results.append(TestOutcome.new("an unwritable report path is rejected without starting recording",
		refused and not profiler.recording and not profiler.last_error.is_empty()))
	profiler.queue_free()
	await tree.process_frame
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	return results
