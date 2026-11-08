class_name PuzzleStepResult
extends RefCounted

var tick_id: int = -1
## Device ID -> output signal after the tick.
var outputs: Dictionary[StringName, bool] = {}
## IDs whose output changed during this tick, in deterministic ID order.
var changed: Array[StringName] = []


func output(id: StringName) -> bool:
	return outputs.get(id, false)
