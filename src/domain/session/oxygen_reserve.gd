class_name OxygenReserve
extends RefCounted
## Reserve expressed in seconds of exposure at the training breach.

const CAPACITY_SECONDS: float = 12.0
var remaining_seconds: float = CAPACITY_SECONDS


func step(delta: float, exposed: bool, supplied: bool) -> void:
	if supplied:
		remaining_seconds = CAPACITY_SECONDS
	elif exposed:
		remaining_seconds = maxf(0.0, remaining_seconds - delta)


func percentage() -> int:
	return ceili(100.0 * remaining_seconds / CAPACITY_SECONDS)
