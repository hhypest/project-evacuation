class_name RuntimeLog
extends Logger
## File sink for the engine's output once the game scene is running. The callbacks can run on
## worker threads and must never log another message themselves.

const MAX_BYTES: int = 8 * 1024 * 1024
const ERROR_LEVELS: PackedStringArray = ["ERROR", "WARNING", "SCRIPT ERROR", "SHADER ERROR"]

var directory: String
var path: String
var notice: String
var _file: FileAccess
var _mutex: Mutex = Mutex.new()


static func game_directory() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://logs")
	return OS.get_executable_path().get_base_dir().path_join("logs")


func start() -> void:
	if not path.is_empty():
		return
	directory = game_directory()
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-")
	var filename: String = "session-%sZ-%d-%d.log" % [stamp, OS.get_process_id(), Time.get_ticks_usec()]
	if not _open(directory, filename):
		var preferred: String = directory
		directory = ProjectSettings.globalize_path("user://logs")
		if not _open(directory, filename):
			notice = "Не удалось сохранить журнал. Проверьте доступ к папке logs рядом с игрой."
			printerr("SESSION_LOG_UNAVAILABLE preferred=%s fallback=%s" % [preferred, directory])
			return
		notice = "Папка logs рядом с игрой недоступна.\nЖурнал записан в папку данных игры (user://logs)."
	OS.add_logger(self)
	print("SESSION_LOG path=" + path)
	if not notice.is_empty():
		printerr("SESSION_LOG_FALLBACK directory=" + directory)


func report_system(runtime: RuntimeInfo, texture_profile: String) -> void:
	var info: Dictionary = Engine.get_version_info()
	print("SYSTEM_INFO game=%s revision=%s godot=%s os=%s version=%s cpu=%s logical_cores=%d ram_mib=%d gpu=%s api=%s render_method=%s physics_hz=%d textures=%s" % [
		ProjectSettings.get_setting("application/config/version"), _revision(), info.get("string"), OS.get_name(), OS.get_version(),
		OS.get_processor_name(), OS.get_processor_count(), str(OS.get_memory_info().get("physical", 0)).to_int() >> 20,
		"unavailable" if runtime.headless else RenderingServer.get_video_adapter_name(),
		"unavailable" if runtime.headless else RenderingServer.get_video_adapter_api_version(),
		"headless" if runtime.headless else RenderingServer.get_current_rendering_method(),
		Engine.physics_ticks_per_second, texture_profile
	])


func report_display(window: Window) -> void:
	var screen: int = window.current_screen
	var desktop: Vector2i = DisplayServer.screen_get_size(screen)
	var canvas_size: Vector2i = Vector2i(window.get_visible_rect().size)
	var fullscreen: bool = window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	print("DISPLAY mode=%d fullscreen=%s window=%dx%d desktop=%dx%d screen=%d refresh_hz=%.1f render_scale=%.3f scaling_mode=%d canvas=%dx%d vsync=%d fps_limit=%d" % [
		window.mode, fullscreen, window.size.x, window.size.y, desktop.x, desktop.y, screen,
		DisplayServer.screen_get_refresh_rate(screen), window.scaling_3d_scale, window.scaling_3d_mode, canvas_size.x, canvas_size.y,
		DisplayServer.window_get_vsync_mode(window.get_window_id()), Engine.max_fps
	])


func _revision() -> String:
	if OS.has_feature("editor"):
		return "editor"
	var manifest: String = OS.get_executable_path().get_base_dir().path_join("build-manifest.json")
	if not FileAccess.file_exists(manifest):
		return "unknown"
	var file: FileAccess = FileAccess.open(manifest, FileAccess.READ)
	if file == null or file.get_length() > 4096:
		return "unknown"
	var value: Variant = JSON.parse_string(file.get_as_text())
	if value is Dictionary:
		# JSON returns Variant even after the runtime type check.
		@warning_ignore("unsafe_cast")
		var data: Dictionary = value as Dictionary
		var revision: String = str(data.get("source_commit", ""))
		if revision.length() == 40 and revision.is_valid_hex_number(false):
			return revision
	return "unknown"


func close() -> void:
	if path.is_empty():
		return
	OS.remove_logger(self)
	_mutex.lock()
	if _file != null:
		_file.close()
		_file = null
	_mutex.unlock()
	path = ""


func _open(folder: String, filename: String) -> bool:
	if FileAccess.file_exists(folder) or DirAccess.make_dir_recursive_absolute(folder) != OK:
		return false
	var candidate: String = folder.path_join(filename)
	_file = FileAccess.open(candidate, FileAccess.WRITE)
	if _file == null:
		return false
	path = candidate
	return true


func _log_message(message: String, error: bool) -> void:
	var line: String = message.strip_edges(false, true)
	if not line.is_empty():
		_write("STDERR" if error else "INFO", line)


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var level: String = ERROR_LEVELS[error_type] if error_type >= 0 and error_type < ERROR_LEVELS.size() else "ERROR"
	var detail: String = "%s\n    at %s (%s:%d)" % [rationale if not rationale.is_empty() else code, function, file, line]
	for trace: ScriptBacktrace in script_backtraces:
		if not trace.is_empty():
			detail += "\n" + trace.format(4)
	_write(level, detail)


func _write(level: String, message: String) -> void:
	var stamp: String = Time.get_datetime_string_from_system(true)
	var entry: PackedByteArray = ("%sZ [%s] %s\n" % [stamp, level, message]).to_utf8_buffer()
	_mutex.lock()
	if _file != null:
		if _file.get_position() + entry.size() > MAX_BYTES - 128:
			_file.store_line(stamp + "Z [WARNING] SESSION_LOG_LIMIT 8 MiB")
			_file.close()
			_file = null
		else:
			_file.store_buffer(entry)
			_file.flush()
			if _file.get_error() != OK:
				_file.close()
				_file = null
	_mutex.unlock()
