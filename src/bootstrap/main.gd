class_name SessionBootstrap
extends Node
## Composition root. Session policy stays in Application; scene lifetime stays here.

@export var catalog: LevelCatalog = preload("res://content/definitions/level_catalog.tres")
## Chamber loaded by start/restart; selecting a level in the menu replaces it.
@export var chamber_scene: PackedScene = preload("res://content/levels/mechanics_lab.tscn")

@onready var _hud: FoundationHud = $FoundationHud
@onready var _input: SessionInput = $SessionInput

var _session: SessionController = SessionController.new()
var _runtime: RuntimeInfo
var _scope: LevelScope
var _window: Window
var _problem: String = ""
var _profiler: RuntimeProfiler
var _profiler_hud: ProfilerHud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud.start_requested.connect(_on_start_requested)
	_hud.level_requested.connect(_on_level_requested)
	if catalog != null:
		_hud.set_levels(catalog.titles())
	_hud.pause_requested.connect(_on_pause_requested)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.menu_requested.connect(_on_menu_requested)
	_hud.quit_requested.connect(_on_quit_requested)
	_window = get_window()
	_window.focus_entered.connect(_on_focus_entered)
	_window.focus_exited.connect(_on_focus_exited)
	_window.close_requested.connect(_on_quit_requested)
	_runtime = RuntimeProbe.new().read()
	var errors: PackedStringArray = ValidateRuntime.new().execute(_runtime, true)
	_session.configure_runtime(errors.is_empty())
	_session.set_focus(_runtime.headless or _window.has_focus())
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


func _configure_profiler() -> void:
	var requested: bool = "--profile" in OS.get_cmdline_user_args()
	# F3/F4 are an explicit opt-in in release too. Hidden diagnostics do not process or time viewports.
	_profiler = RuntimeProfiler.new()
	_profiler.name = "RuntimeProfiler"
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


func _physics_process(delta: float) -> void:
	if _scope != null and _session.get_status().accepts_gameplay:
		_scope.apply_input(_input.take_frame(), delta)
		if _scope.needs_recovery():
			print("CHAMBER_RECOVERY body=%s" % _scope.portals().recovery_body_id)
			_on_restart_requested()


func _on_start_requested() -> void:
	if _session.start():
		_replace_scope()
		_sync_session()


func _on_level_requested(index: int) -> void:
	var scene: PackedScene = catalog.scene(index) if catalog != null else null
	if scene == null:
		return
	chamber_scene = scene
	_on_start_requested()


func _on_pause_requested() -> void:
	if _session.toggle_pause():
		_sync_session()


func _on_restart_requested() -> void:
	if _session.restart():
		_replace_scope()
		_sync_session()


func _on_menu_requested() -> void:
	if _session.return_to_menu():
		_drop_scope()
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


func _replace_scope() -> void:
	# Close the old input gate before replacing physics nodes and their generation.
	_input.set_gameplay_enabled(false, _session.get_status().generation)
	_drop_scope()
	_scope = LevelScope.new()
	_scope.name = "LevelScope"
	add_child(_scope)
	if not _scope.open(chamber_scene, _session.get_status().generation):
		_drop_scope()
		_session.return_to_menu()
		_problem = "Не удалось загрузить уровень. Попробуйте начать сессию ещё раз."
	else:
		_problem = ""


func _drop_scope() -> void:
	if is_instance_valid(_scope):
		_scope.close()
	_scope = null


func _sync_session() -> void:
	var status: SessionStatus = _session.get_status()
	if is_instance_valid(_profiler):
		_profiler.level_label = chamber_scene.resource_path if _scope != null else "menu"
	if not status.accepts_gameplay and _scope != null:
		_scope.suspend_carry()
	get_tree().paused = status.phase in [SessionLifecycle.Phase.READY, SessionLifecycle.Phase.PAUSED]
	_input.set_gameplay_enabled(status.accepts_gameplay, status.generation)
	var mode: String = "HEADLESS: графика не проверена" if _runtime.headless else "Vulkan"
	_hud.show_session(status, "Godot %s · %s · %s · 60 Гц" % [
		_runtime.engine_version, mode, _runtime.physics_backend
	], _problem)


func _exit_tree() -> void:
	_session.stop()
	if is_instance_valid(_input):
		_input.shutdown()
	if is_instance_valid(_window):
		_window.focus_entered.disconnect(_on_focus_entered)
		_window.focus_exited.disconnect(_on_focus_exited)
		_window.close_requested.disconnect(_on_quit_requested)
	get_tree().paused = false
