class_name SessionLifecycle
extends RefCounted
## Discrete session state. Physics and scene ownership belong to adapters/scopes.

enum Phase { READY, RUNNING, PAUSED, STOPPED }

var _phase: Phase = Phase.READY
var _generation: int = 0


func get_phase() -> Phase:
	return _phase


func get_generation() -> int:
	return _generation


func start() -> bool:
	if _phase != Phase.READY:
		return false
	_generation += 1
	_phase = Phase.RUNNING
	return true


func pause() -> bool:
	if _phase != Phase.RUNNING:
		return false
	_phase = Phase.PAUSED
	return true


func resume() -> bool:
	if _phase != Phase.PAUSED:
		return false
	_phase = Phase.RUNNING
	return true


func restart() -> bool:
	if _phase != Phase.RUNNING and _phase != Phase.PAUSED:
		return false
	_generation += 1
	_phase = Phase.RUNNING
	return true


func stop() -> bool:
	if _phase == Phase.STOPPED:
		return false
	_phase = Phase.STOPPED
	return true
