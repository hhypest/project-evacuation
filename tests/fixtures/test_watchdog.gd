class_name TestWatchdog
extends Node
## Fixed-fps tests can simulate minutes quickly; timeout must use the wall clock.

var _started: int = Time.get_ticks_msec()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# Uncapped fixed-fps scene churn can outrun Jolt's worker job reclamation.
	# Yield real scheduler time without changing simulated physics delta or hiding warnings.
	OS.delay_usec(1000)
	if Time.get_ticks_msec() - _started > 30000:
		printerr("TEST_TIMEOUT: wall-clock limit 30 seconds exceeded")
		set_process(false)
		get_tree().quit(3)
