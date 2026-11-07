class_name SessionBootstrap
extends Node
## Composition root. Session policy stays in Application; scene lifetime stays here.

@export var chamber_scene: PackedScene = preload("res://content/levels/foundation_lab.tscn")

@onready var _hud: FoundationHud = $FoundationHud
@onready var _input: SessionInput = $SessionInput

var _session: SessionController = SessionController.new()
var _runtime: RuntimeInfo
var _scope: LevelScope
var _window: Window
var _problem: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud.start_requested.connect(_on_start_requested)
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
	print("%s Godot=%s renderer=%s physics=%s headless=%s" % [
		"SESSION_READY" if errors.is_empty() else "SESSION_BLOCKED",
		_runtime.engine_version, _runtime.rendering_driver, _runtime.physics_backend, _runtime.headless
	])


func get_session_status() -> SessionStatus:
	return _session.get_status()


func _physics_process(delta: float) -> void:
	if _scope != null and _session.get_status().accepts_gameplay:
		_scope.apply_input(_input.take_frame(), delta)


func _on_start_requested() -> void:
	if _session.start():
		_replace_scope()
		_sync_session()


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
		_problem = "Не удалось загрузить тестовую камеру. Попробуйте начать сессию ещё раз."
	else:
		_problem = ""


func _drop_scope() -> void:
	if is_instance_valid(_scope):
		_scope.close()
	_scope = null


func _sync_session() -> void:
	var status: SessionStatus = _session.get_status()
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
