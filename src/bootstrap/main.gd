class_name SessionBootstrap
extends Node
## Composition root. Session policy stays in Application; scene lifetime stays here.

const LAB_SCENE: PackedScene = preload("res://content/levels/mechanics_lab.tscn")

@export var catalog: LevelCatalog = preload("res://content/definitions/level_catalog.tres")
## Chamber loaded by start/restart; selecting a level in the menu replaces it.
@export var chamber_scene: PackedScene = LAB_SCENE

## Injected for session tests. A game launched from the main scene opens the real portable store.
var save_repository: SaveRepository

@onready var _hud: FoundationHud = $FoundationHud
@onready var _input: SessionInput = $SessionInput

var _session: SessionController = SessionController.new()
var _runtime: RuntimeInfo
var _scope: LevelScope
var _window: Window
var _problem: String = ""
var _continue_level: LevelEntry
var _continue_snapshot: SaveSnapshot
var _active_entry: LevelEntry
var _active_checkpoint: SaveSnapshot
var _completed_levels: Array[StringName] = []
var _checkpoint_load_notice: String = ""
var _checkpoint_write_notice: String = ""
var _log: RuntimeLog
var _profiler: RuntimeProfiler
var _profiler_hud: ProfilerHud
var _fsr2_quality: bool = false
var camera_preferences: CameraPreferences = CameraPreferences.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_log = RuntimeLog.new()
	_log.start()
	_hud.start_requested.connect(_on_start_requested)
	_hud.load_checkpoint_requested.connect(_on_load_checkpoint_requested)
	_hud.level_requested.connect(_on_level_requested)
	if catalog != null:
		_hud.set_levels(catalog.titles())
	_hud.pause_requested.connect(_on_pause_requested)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.menu_requested.connect(_on_menu_requested)
	_hud.quit_requested.connect(_on_quit_requested)
	_hud.camera_preferences_changed.connect(_on_camera_preferences_changed)
	if get_tree().current_scene == self:
		CameraPreferenceFile.load_into(camera_preferences)
	_hud.set_camera_preferences(camera_preferences)
	_window = get_window()
	_hud.fsr2_changed.connect(_on_fsr2_changed)
	var can_use_fsr: bool = RenderScale.available()
	if can_use_fsr and get_tree().current_scene == self:
		_fsr2_quality = RenderPreferenceFile.load_fsr2()
	_hud.configure_fsr2(can_use_fsr, _fsr2_quality)
	RenderScale.apply(_window, _fsr2_quality)
	_runtime = RuntimeProbe.new().read()
	if not _runtime.headless and "--windowed" in OS.get_cmdline_user_args():
		_window.mode = Window.MODE_WINDOWED
		_window.size = _window.content_scale_size
	_window.focus_entered.connect(_on_focus_entered)
	_window.focus_exited.connect(_on_focus_exited)
	_window.close_requested.connect(_on_quit_requested)
	if not _runtime.headless:
		_window.size_changed.connect(_log_display)
		_log_display.call_deferred()
	_log.report_system(_runtime, RuntimeProfiler.SETTINGS.profile_label())
	var errors: PackedStringArray = ValidateRuntime.new().execute(_runtime, true)
	_session.configure_runtime(errors.is_empty())
	_session.set_focus(_runtime.headless or _window.has_focus())
	if save_repository == null and get_tree().current_scene == self and not "--runtime-smoke" in OS.get_cmdline_user_args():
		save_repository = JsonSaveRepository.new()
	_refresh_checkpoint()
	if not errors.is_empty():
		_problem = "Запуск остановлен:\n" + "\n".join(errors)
		push_error("Runtime validation failed: " + "; ".join(errors))
	_sync_session()
	_configure_profiler()
	print("%s Godot=%s renderer=%s physics=%s headless=%s" % [
		"SESSION_READY" if errors.is_empty() else "SESSION_BLOCKED",
		_runtime.engine_version, _runtime.rendering_driver, _runtime.physics_backend, _runtime.headless
	])
	if "--runtime-smoke" in OS.get_cmdline_user_args():
		var smoke: RuntimeGameplaySmoke = RuntimeGameplaySmoke.new()
		add_child(smoke)
		smoke.start(self)


func get_session_status() -> SessionStatus:
	return _session.get_status()


func get_session_log_path() -> String:
	return _log.path if _log != null else ""


func _log_display() -> void:
	_log.report_display(_window)


func _configure_profiler() -> void:
	var requested: bool = "--profile" in OS.get_cmdline_user_args()
	# F3/F4 are an explicit opt-in in release too. Hidden diagnostics do not process or time viewports.
	_profiler = RuntimeProfiler.new()
	_profiler.name = "RuntimeProfiler"
	_profiler.log_directory = _log.directory
	add_child(_profiler)
	_profiler_hud = ProfilerHud.new()
	_profiler_hud.name = "ProfilerHud"
	add_child(_profiler_hud)
	_profiler.sampled.connect(_profiler_hud.show_sample)
	_profiler_hud.panel_toggled.connect(_profiler.set_panel_visible)
	_profiler_hud.record_toggled.connect(_on_profile_record_toggled)
	if requested:
		_profiler_hud.set_panel_visible(true)
		print("PROFILER_READY texture_profile=%s" % _profiler.SETTINGS.profile_label())


func _on_profile_record_toggled() -> void:
	if _profiler.recording:
		_profiler.stop_recording()
	else:
		_profiler.start_recording()


func _on_camera_preferences_changed() -> void:
	if _scope != null:
		_scope.configure_camera(camera_preferences)
	if get_tree().current_scene == self and CameraPreferenceFile.save(camera_preferences) != OK:
		_hud.show_preferences_notice("Не удалось записать настройки камеры.")
		printerr("CAMERA_PREFERENCES_WRITE_FAILED")


func _on_fsr2_changed(enabled: bool) -> void:
	if not RenderScale.available():
		return
	_fsr2_quality = enabled
	RenderScale.apply(_window, enabled)
	_log_display()
	if get_tree().current_scene == self and RenderPreferenceFile.save_fsr2(enabled) != OK:
		_hud.show_preferences_notice("Не удалось записать настройки графики.")


func _physics_process(delta: float) -> void:
	if _scope == null or not _session.get_status().accepts_gameplay:
		return
	if _scope.player_fell():
		_recover_chamber(&"fall", PortalWorldAdapter.PLAYER_ID)
		return
	var lost: StringName = _scope.lost_body()
	if not lost.is_empty():
		_recover_chamber(&"lost_prop", lost)
		return
	_scope.apply_input(_input.take_frame(), delta)
	_hud.show_carry_feedback(not _scope.held_prop_id().is_empty(), _scope.has_placement())
	if _scope.needs_recovery():
		_recover_chamber(&"portal", _scope.portals().recovery_body_id)


func _recover_chamber(reason: StringName, body_id: StringName) -> void:
	var before: int = _session.get_status().generation
	if not _session.restart():
		return
	var portals: AdvancePortals = _scope.portals()
	var checkpoint: SaveSnapshot = _active_checkpoint
	var point: StringName = checkpoint.checkpoint_id if checkpoint != null else SaveSnapshot.ENTRY_ID
	print("CHAMBER_RECOVERY body=%s level=%s generation=%d crossings=%d blocked=%d reason=%s checkpoint=%s" % [
		body_id, chamber_scene.resource_path, before, portals.crossing_count, portals.blocked_count, reason, point
	])
	var restored: bool = _replace_scope(checkpoint)
	if not restored and point != SaveSnapshot.ENTRY_ID:
		if _replace_scope():
			_active_checkpoint = null
			restored = true
			print("CHAMBER_RECOVERY_FALLBACK checkpoint=entry")
	if restored:
		_hud.show_recovery("Возврат к контрольной точке")
	else:
		_session.return_to_menu()
	_sync_session()


func _on_start_requested() -> void:
	_start_chamber(chamber_scene)


func _on_level_requested(index: int) -> void:
	var item: LevelEntry = catalog.entry(index) if catalog != null else null
	if item == null or item.scene == null:
		return
	var checkpoint_entry: LevelEntry = item if catalog.find_level(item.level_id) == item else null
	_start_chamber(item.scene, checkpoint_entry)


func _on_load_checkpoint_requested() -> void:
	if not _session.get_status().can_start:
		return
	_refresh_checkpoint()
	if _continue_level == null:
		_sync_session()
		return
	var item: LevelEntry = _continue_level
	var snapshot: SaveSnapshot = _continue_snapshot
	_start_chamber(item.scene, item, snapshot)
	if _scope != null:
		print("CHECKPOINT_LOADED level=%s checkpoint=%s" % [item.level_id, snapshot.checkpoint_id])


func _start_chamber(scene: PackedScene, checkpoint_entry: LevelEntry = null, loaded: SaveSnapshot = null) -> void:
	if not _session.start():
		return
	chamber_scene = scene
	_active_entry = checkpoint_entry
	_active_checkpoint = loaded
	if not _replace_scope(loaded):
		_session.return_to_menu()
	if _scope != null and loaded == null and save_repository != null and checkpoint_entry != null:
		# A fresh run from the level list can replay the chamber without erasing its station.
		if _continue_snapshot != null and _continue_snapshot.level_id == checkpoint_entry.level_id \
				and _continue_snapshot.checkpoint_id != SaveSnapshot.ENTRY_ID:
			_active_checkpoint = _continue_snapshot
		else:
			_write_checkpoint(_new_snapshot(SaveSnapshot.ENTRY_ID))
	_sync_session()


func _new_snapshot(id: StringName) -> SaveSnapshot:
	var version: String = str(ProjectSettings.get_setting("application/config/version"))
	var snapshot: SaveSnapshot = SaveSnapshot.new(_active_entry.level_id, version, id)
	snapshot.completed_levels = _completed_levels.duplicate()
	return snapshot


func _on_station_requested(station: CheckpointStation, states: Dictionary[StringName, bool]) -> void:
	if save_repository == null or _active_entry == null \
			or _active_entry.station(station.checkpoint.checkpoint_id) != station.checkpoint:
		station.report("ЗАПИСЬ НЕДОСТУПНА")
		return
	var snapshot: SaveSnapshot = _new_snapshot(station.checkpoint.checkpoint_id)
	snapshot.switches = states.duplicate()
	station.report("ТОЧКА СОХРАНЕНА" if _write_checkpoint(snapshot) else "ОШИБКА ЗАПИСИ\nE · ПОВТОРИТЬ")


func _on_chamber_completed(generation: int) -> void:
	if _scope == null or generation != _session.get_status().generation or _active_entry == null or save_repository == null:
		return
	if _active_entry.level_id not in _completed_levels:
		_completed_levels.append(_active_entry.level_id)
	var id: StringName = _active_checkpoint.checkpoint_id if _active_checkpoint != null else SaveSnapshot.ENTRY_ID
	var snapshot: SaveSnapshot = _new_snapshot(id)
	if _active_checkpoint != null:
		snapshot.switches = _active_checkpoint.switches.duplicate()
	_write_checkpoint(snapshot)


func _write_checkpoint(snapshot: SaveSnapshot) -> bool:
	var result: SaveResult.Code = save_repository.write_checkpoint(snapshot)
	_refresh_checkpoint()
	if result == SaveResult.Code.OK:
		_active_checkpoint = snapshot
		_checkpoint_write_notice = ""
		print("CHECKPOINT_READY level=%s checkpoint=%s" % [snapshot.level_id, snapshot.checkpoint_id])
		return true
	var location: String = "вход в камеру" if snapshot.checkpoint_id == SaveSnapshot.ENTRY_ID else "контрольную точку"
	_checkpoint_write_notice = "Не удалось сохранить %s «%s». %s" % [location, _active_entry.title, _checkpoint_error(result)]
	printerr("CHECKPOINT_WRITE_FAILED level=%s code=%s" % [snapshot.level_id, SaveResult.Code.keys()[result]])
	return false


func _refresh_checkpoint() -> void:
	_continue_level = null
	_continue_snapshot = null
	_checkpoint_load_notice = ""
	if save_repository == null:
		return
	var result: SaveResult = save_repository.read_checkpoint()
	if result.code == SaveResult.Code.MISSING:
		return
	if result.code != SaveResult.Code.OK:
		_checkpoint_load_notice = _checkpoint_error(result.code)
		return
	for id: StringName in result.snapshot.completed_levels:
		if id not in _completed_levels:
			_completed_levels.append(id)
	var item: LevelEntry = catalog.find_level(result.snapshot.level_id) if catalog != null else null
	if item == null:
		_checkpoint_load_notice = "Уровень из сохранения недоступен в этой сборке."
		return
	var notice: String = "Доступна предыдущая контрольная точка. " if result.recovered else ""
	if result.snapshot.checkpoint_id == SaveSnapshot.ENTRY_ID:
		_checkpoint_load_notice = notice + "Продолжение открывает камеру с точки входа."
	else:
		var station: StationCheckpoint = item.station(result.snapshot.checkpoint_id)
		if station == null or not station.accepts(result.snapshot.switches):
			_checkpoint_load_notice = "Контрольная точка недоступна в этой сборке."
			return
		_checkpoint_load_notice = notice + "%s · %s" % [item.title, station.title]
	_continue_level = item
	_continue_snapshot = result.snapshot


func _checkpoint_error(code: SaveResult.Code) -> String:
	match code:
		SaveResult.Code.INVALID:
			return "Файл контрольной точки повреждён."
		SaveResult.Code.UNSUPPORTED:
			return "Версия сохранения не поддерживается этой сборкой."
		_:
			return "Проверьте доступ к папке saves рядом с игрой."


func _on_pause_requested() -> void:
	if _session.toggle_pause():
		_sync_session()


func _on_restart_requested() -> void:
	if _session.restart():
		if not _replace_scope():
			_session.return_to_menu()
		_sync_session()


func _on_menu_requested() -> void:
	if _session.return_to_menu():
		_drop_scope()
		_refresh_checkpoint()
		_sync_session()


func _on_focus_entered() -> void:
	_session.set_focus(true)
	_sync_session()


func _on_focus_exited() -> void:
	_session.set_focus(false)
	_sync_session()


func _on_quit_requested() -> void:
	_session.stop()
	_drop_scope()
	_sync_session()
	get_tree().quit()


func _replace_scope(checkpoint: SaveSnapshot = null) -> bool:
	# Close the old input gate before replacing physics nodes and their generation.
	_input.set_gameplay_enabled(false, _session.get_status().generation)
	_drop_scope()
	_scope = LevelScope.new()
	_scope.name = "LevelScope"
	add_child(_scope)
	if not _scope.open(chamber_scene, _session.get_status().generation, checkpoint):
		printerr("LEVEL_LOAD_FAILED path=" + (chamber_scene.resource_path if chamber_scene != null else "<empty>"))
		_drop_scope()
		_problem = "Не удалось загрузить уровень. Попробуйте начать сессию ещё раз."
		return false
	else:
		_scope.station_requested.connect(_on_station_requested)
		_scope.chamber_completed.connect(_on_chamber_completed.bind(_session.get_status().generation))
		_scope.configure_camera(camera_preferences)
		_problem = ""
	return true


func _drop_scope() -> void:
	if is_instance_valid(_scope):
		_scope.close()
	_scope = null


func _sync_session() -> void:
	var status: SessionStatus = _session.get_status()
	var level: String = chamber_scene.resource_path if _scope != null else "menu"
	if is_instance_valid(_profiler):
		_profiler.level_label = level
		_profiler.generation = status.generation
	print("SESSION_STATE phase=%s generation=%d focused=%s level=%s" % [
		SessionLifecycle.Phase.keys()[status.phase], status.generation, status.focused, level
	])
	if not status.accepts_gameplay and _scope != null:
		_scope.suspend_carry()
	get_tree().paused = status.phase in [SessionLifecycle.Phase.READY, SessionLifecycle.Phase.PAUSED]
	_input.set_gameplay_enabled(status.accepts_gameplay, status.generation)
	var mode: String = "HEADLESS: графика не проверена" if _runtime.headless else "Vulkan"
	var notice: String = "\n" + _log.notice if not _log.notice.is_empty() else ""
	var load_notice: String = _checkpoint_load_notice if status.phase == SessionLifecycle.Phase.READY else ""
	var messages: PackedStringArray = []
	for message: String in [_problem, _checkpoint_write_notice, load_notice]:
		if not message.is_empty():
			messages.append(message)
	if catalog != null:
		for index: int in range(catalog.entries.size()):
			var entry: LevelEntry = catalog.entry(index)
			if entry != null:
				_hud.set_level_completed(index, entry.title, entry.level_id in _completed_levels)
	_hud.show_session(status, "Godot %s · %s · %s · 60 Гц%s" % [
		_runtime.engine_version, mode, _runtime.physics_backend, notice
	], "\n".join(messages), _continue_level != null,
		"Перезапустить полигон [R]" if chamber_scene == LAB_SCENE else "Перезапустить камеру [R]")


func _exit_tree() -> void:
	_session.stop()
	if is_instance_valid(_input):
		_input.shutdown()
	if is_instance_valid(_window):
		_window.focus_entered.disconnect(_on_focus_entered)
		_window.focus_exited.disconnect(_on_focus_exited)
		_window.close_requested.disconnect(_on_quit_requested)
		if _window.size_changed.is_connected(_log_display):
			_window.size_changed.disconnect(_log_display)
	get_tree().paused = false
	if _log != null:
		print("SESSION_END")
		_log.close()
