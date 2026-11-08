class_name DeviceMemory
extends RefCounted
## Discrete per-device state. Plain values only, so a chamber snapshot can copy it exactly.

var output: bool = false
var settle_count: int = 0
var timer_ticks: int = 0
var latch: bool = false
var history: Array[bool] = []


func copy() -> DeviceMemory:
	var memory: DeviceMemory = DeviceMemory.new()
	memory.output = output
	memory.settle_count = settle_count
	memory.timer_ticks = timer_ticks
	memory.latch = latch
	memory.history = history.duplicate()
	return memory
