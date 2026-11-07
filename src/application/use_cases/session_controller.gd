class_name SessionController
extends RefCounted
## Applies focus/runtime prerequisites to domain transitions.

var _session: SessionLifecycle = SessionLifecycle.new()
var _focused: bool = false
var _runtime_valid: bool = false


func configure_runtime(valid: bool) -> void:
	_runtime_valid = valid
	if not valid:
		_session.pause()


func set_focus(focused: bool) -> void:
	_focused = focused
	if not focused:
		_session.pause()


func start() -> bool:
	return _ready_for_input() and _session.start()


func toggle_pause() -> bool:
	if _session.get_phase() == SessionLifecycle.Phase.RUNNING:
		return _session.pause()
	return resume()


func resume() -> bool:
	return _ready_for_input() and _session.resume()


func restart() -> bool:
	return _ready_for_input() and _session.restart()


func return_to_menu() -> bool:
	return _session.return_to_menu()


func stop() -> bool:
	return _session.stop()


func get_status() -> SessionStatus:
	var status: SessionStatus = SessionStatus.new()
	status.phase = _session.get_phase()
	status.generation = _session.get_generation()
	status.focused = _focused
	status.can_start = _ready_for_input() and status.phase == SessionLifecycle.Phase.READY
	status.can_resume = _ready_for_input() and status.phase == SessionLifecycle.Phase.PAUSED
	status.can_restart = _ready_for_input() and status.phase in [
		SessionLifecycle.Phase.RUNNING, SessionLifecycle.Phase.PAUSED
	]
	status.accepts_gameplay = _ready_for_input() and status.phase == SessionLifecycle.Phase.RUNNING
	return status


func _ready_for_input() -> bool:
	return _runtime_valid and _focused
