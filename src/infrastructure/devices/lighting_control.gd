class_name LightingControl
extends WallButtonDevice
## A normal network toggle whose output drives a local rendering experiment.
## It owns no puzzle state; pause, interaction and reset still belong to the session/network.

signal output_changed(disabled: bool)

var disabled: bool = false


func show_output(on: bool, delta: float) -> void:
	super.show_output(on, delta)
	if disabled == on:
		return
	disabled = on
	output_changed.emit(disabled)
