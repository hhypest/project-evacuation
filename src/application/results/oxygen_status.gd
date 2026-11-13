class_name OxygenStatus
extends RefCounted
## Atmosphere observation and the outcome of advancing one simulation tick.

enum Atmosphere { SUPPLY, PASSAGE, BREACH }

var atmosphere: Atmosphere
var percent: int
var recovery_required: bool


func _init(current: Atmosphere, reserve_percent: int, depleted: bool) -> void:
	atmosphere = current
	percent = reserve_percent
	recovery_required = depleted
