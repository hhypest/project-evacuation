class_name RuntimeProfiler
extends Node
## Opt-in diagnostics: bounded frame window, all live viewport timers and a local UTF-8 CSV at 2 Hz.
## No game state is changed. GPU/CPU rendering numbers include portal SubViewports, not only the window.

signal sampled(sample: ProfilerSample)

const SETTINGS: DeviceTextureSettings = preload("res://content/definitions/device_texture_quality.tres")
const INTERVAL_US: int = 500000
const MAX_WINDOW_FRAMES: int = 4096
const HEADER: PackedStringArray = ["elapsed_s", "level", "paused", "focused", "texture_profile",
	"width", "height", "frames", "fps", "frame_mean_ms", "frame_p95_ms", "frame_max_ms",
	"process_ms", "physics_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls", "primitives",
	"texture_bytes", "video_bytes", "static_bytes", "gpu", "renderer", "viewports", "godot_version",
	"physics_hz", "vsync_mode", "fps_limit"]

var level_label: String = "menu"
var latest: ProfilerSample = ProfilerSample.new()
var recording: bool = false
var report_path: String = ""
var last_error: String = ""
var _panel_visible: bool = false
var _active: bool = false
var _headless: bool = false
var _viewports: Array[Viewport] = []
var _times: Array[float] = []
var _last_us: int = 0
var _window_us: int = 0
var _started_us: int = 0
var _gpu_sum: float = 0.0
var _render_cpu_sum: float = 0.0
var _render_frames: int = 0
var _file: FileAccess
var _window_paused: bool = false
var _window_focused: bool = false
var _window_level: String = "menu"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	_started_us = Time.get_ticks_usec()
	set_process(false)


func set_panel_visible(enabled: bool) -> void:
	_panel_visible = enabled
	_sync_active()
	_emit_status()


func start_recording(directory: String = "user://profiles") -> bool:
	if recording:
		return true
	last_error = ""
	var absolute: String = ProjectSettings.globalize_path(directory)
	var ancestor: String = absolute
	while not DirAccess.dir_exists_absolute(ancestor):
		if FileAccess.file_exists(ancestor):
			last_error = "Путь отчёта проходит через файл: " + ancestor
			_emit_status()
			return false
		var parent: String = ancestor.get_base_dir()
		if parent == ancestor:
			break
		ancestor = parent
	if DirAccess.make_dir_recursive_absolute(absolute) != OK:
		last_error = "Не удалось создать папку отчётов: " + absolute
		_emit_status()
		return false
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	report_path = absolute.path_join("profile-%s-%d.csv" % [stamp, Time.get_ticks_usec()])
	_file = FileAccess.open(report_path, FileAccess.WRITE)
	if _file == null:
		last_error = "Не удалось открыть отчёт: " + error_string(FileAccess.get_open_error())
		_emit_status()
		return false
	_file.store_csv_line(HEADER)
	_file.flush()
	if _file.get_error() != OK:
		last_error = "Не удалось записать заголовок отчёта"
		_file.close()
		_file = null
		_emit_status()
		return false
	recording = true
	# Start a new frame window; a recording never inherits earlier menu/idle samples.
	_reset_window()
	_sync_active()
	_emit_status()
	print("PROFILE_RECORDING " + report_path)
	return true


func stop_recording() -> void:
	if recording and not _times.is_empty():
		_publish_window()
	recording = false
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
	_sync_active()
	_emit_status()


func _process(_delta: float) -> void:
	# Do not mix loading/menu/pause/focus transitions into a window labelled as steady gameplay.
	if get_tree().paused != _window_paused or get_window().has_focus() != _window_focused or level_label != _window_level:
		_reset_window()
	var now: int = Time.get_ticks_usec()
	if _last_us == 0:
		_last_us = now
		return
	_times.append(float(now - _last_us) / 1000.0)
	_last_us = now
	if not _headless:
		var gpu_ms: float = 0.0
		var cpu_ms: float = RenderingServer.get_frame_setup_time_cpu()
		for viewport: Viewport in _viewports:
			if is_instance_valid(viewport):
				if viewport is SubViewport and (viewport as SubViewport).render_target_update_mode == SubViewport.UPDATE_DISABLED:
					continue
				gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
				cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(viewport.get_viewport_rid())
		if gpu_ms > 0.0:
			_gpu_sum += gpu_ms
			_render_cpu_sum += cpu_ms
			_render_frames += 1
	if now - _window_us >= INTERVAL_US or _times.size() >= MAX_WINDOW_FRAMES:
		_publish_window()
		_refresh_viewports()


func _publish_window() -> void:
	latest = ProfilerSample.summarize(_times)
	latest.elapsed_s = float(Time.get_ticks_usec() - _started_us) / 1000000.0
	latest.level = level_label
	latest.texture_profile = SETTINGS.profile_label()
	latest.viewport_size = get_viewport().get_visible_rect().size
	for viewport: Viewport in _viewports:
		if is_instance_valid(viewport):
			latest.viewport_count += 1
	latest.engine_version = RuntimeProbe.new().read().engine_version
	latest.physics_hz = Engine.physics_ticks_per_second
	latest.fps_limit = Engine.max_fps
	if not _headless:
		latest.vsync_mode = DisplayServer.window_get_vsync_mode(get_window().get_window_id())
	latest.paused = get_tree().paused
	latest.focused = get_window().has_focus()
	latest.renderer = "headless" if _headless else String(RenderingServer.get_current_rendering_driver_name())
	latest.gpu = "unavailable" if _headless else RenderingServer.get_video_adapter_name()
	latest.process_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	latest.physics_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	latest.draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	latest.primitives = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	latest.texture_bytes = int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	latest.video_bytes = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	latest.static_bytes = int(Performance.get_monitor(Performance.MEMORY_STATIC)) if OS.is_debug_build() else -1
	if _render_frames > 0:
		latest.render_gpu_ms = _gpu_sum / float(_render_frames)
		latest.render_cpu_ms = _render_cpu_sum / float(_render_frames)
	if recording and _file != null:
		_write_sample()
	_reset_window()
	_emit_status()


func _write_sample() -> void:
	_file.store_csv_line(PackedStringArray([str(latest.elapsed_s), latest.level, str(latest.paused), str(latest.focused),
		latest.texture_profile, str(latest.viewport_size.x), str(latest.viewport_size.y), str(latest.frame_count),
		str(latest.fps), str(latest.frame_mean_ms), str(latest.frame_p95_ms), str(latest.frame_max_ms),
		str(latest.process_ms), str(latest.physics_ms), str(latest.render_cpu_ms), str(latest.render_gpu_ms),
		str(latest.draw_calls), str(latest.primitives), str(latest.texture_bytes), str(latest.video_bytes),
		str(latest.static_bytes), latest.gpu, latest.renderer, str(latest.viewport_count), latest.engine_version,
		str(latest.physics_hz), str(latest.vsync_mode), str(latest.fps_limit)]))
	_file.flush()
	if _file.get_error() != OK:
		last_error = "Ошибка записи CSV: " + error_string(_file.get_error())
		recording = false
		_file.close()
		_file = null
		_sync_active()


func _sync_active() -> void:
	var enabled: bool = _panel_visible or recording
	if enabled == _active:
		return
	_active = enabled
	set_process(enabled)
	if enabled:
		_reset_window()
		_refresh_viewports()
	else:
		_disable_viewports()


func _refresh_viewports() -> void:
	if _headless or not _active:
		return
	_viewports.clear()
	_viewports.append(get_tree().root)
	for node: Node in get_tree().root.find_children("*", "Viewport", true, false):
		var viewport: Viewport = node as Viewport
		_viewports.append(viewport)
	for viewport: Viewport in _viewports:
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)


func _disable_viewports() -> void:
	for viewport: Viewport in _viewports:
		if is_instance_valid(viewport):
			RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), false)
	_viewports.clear()


func _reset_window() -> void:
	_times.clear()
	_last_us = 0
	_window_us = Time.get_ticks_usec()
	_gpu_sum = 0.0
	_render_cpu_sum = 0.0
	_render_frames = 0
	_window_paused = get_tree().paused
	_window_focused = get_window().has_focus()
	_window_level = level_label


func _emit_status() -> void:
	latest.recording = recording
	latest.report_path = report_path
	latest.error = last_error
	sampled.emit(latest)


func _exit_tree() -> void:
	stop_recording()
	_disable_viewports()
