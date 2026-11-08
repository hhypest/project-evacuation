class_name TestWatchdog
extends Node
## Fixed-fps tests can simulate minutes quickly; timeout must use the wall clock.

const TIMEOUT_MSEC: int = 300000

var _started: int = Time.get_ticks_msec()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# Uncapped fixed-fps scene churn can outrun Jolt's worker job reclamation.
	# Yield real scheduler time without changing simulated physics delta or hiding warnings.
	OS.delay_usec(1000)
	if Time.get_ticks_msec() - _started > TIMEOUT_MSEC:
		printerr("TEST_TIMEOUT: wall-clock limit %d seconds exceeded" % (TIMEOUT_MSEC / 1000))
		set_process(false)
		get_tree().quit(3)
