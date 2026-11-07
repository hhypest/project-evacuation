extends Node
## Composition root. Owns scene lifetime and adapts session state to SceneTree.

const LAB: PackedScene = preload("res://content/levels/foundation_lab.tscn")

@onready var _hud: FoundationHud = $FoundationHud

var _session: SessionLifecycle = SessionLifecycle.new()
var _runtime: RuntimeInfo
var _lab: Node3D
var _valid: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud.pause_requested.connect(_on_pause_requested)
	_hud.restart_requested.connect(_on_restart_requested)
	_hud.quit_requested.connect(_on_quit_requested)
	_runtime = RuntimeProbe.new().read()
	var errors: PackedStringArray = ValidateRuntime.new().execute(_runtime, true)
	_valid = errors.is_empty()
	if not _valid:
		_hud.show_status("Запуск остановлен:\n" + "\n".join(errors), false, false)
		push_error("Runtime validation failed: " + "; ".join(errors))
		return
	if _session.start():
		_create_lab()
	_refresh_status()
	print("FOUNDATION_READY Godot=%s renderer=%s physics=%s headless=%s" % [
		_runtime.engine_version, _runtime.rendering_driver, _runtime.physics_backend, _runtime.headless
	])


func _create_lab() -> void:
	_lab = LAB.instantiate() as Node3D
	if _lab == null:
		_valid = false
		push_error("Foundation lab must be a Node3D scene.")
		return
	_lab.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_lab)


func _on_pause_requested() -> void:
	if not _valid:
		return
	if _session.get_phase() == SessionLifecycle.Phase.PAUSED:
		_session.resume()
	else:
		_session.pause()
	get_tree().paused = _session.get_phase() == SessionLifecycle.Phase.PAUSED
	_refresh_status()


func _on_restart_requested() -> void:
	if not _valid or not _session.restart():
		return
	get_tree().paused = false
	# Called from UI/input outside physics callbacks; remove old scope before creating a new one.
	if is_instance_valid(_lab):
		remove_child(_lab)
		_lab.queue_free()
	_create_lab()
	_refresh_status()


func _on_quit_requested() -> void:
	_session.stop()
	get_tree().paused = false
	get_tree().quit()


func _refresh_status() -> void:
	var paused: bool = _session.get_phase() == SessionLifecycle.Phase.PAUSED
	var mode: String = "HEADLESS: графика не проверена" if _runtime.headless else "Vulkan"
	var state: String = "Пауза" if paused else "Симуляция работает"
	_hud.show_status("Godot %s · %s · %s · 60 Гц\n%s · запуск %d" % [
		_runtime.engine_version, mode, _runtime.physics_backend, state, _session.get_generation()
	], paused, _valid)
