class_name PuzzleWorldPort
extends RefCounted
## Runtime boundary of one chamber's devices. The base class never pretends to succeed.


## Device definitions read from the chamber, already converted to domain DTOs.
func definitions() -> Array[DeviceDefinition]:
	return []


## Facts from the last completed physics step plus presses queued since the previous tick.
func observe(_tick_id: int) -> PuzzleObservation:
	return null


## Drives actuators and indicators from a committed network step. Presentation only follows.
func apply(_result: PuzzleStepResult) -> void:
	pass


## ID of a usable wall button under the view ray within reach, or empty.
func usable(_view: Transform3D, _reach: float) -> StringName:
	return &""


## Queues one press for the next observation; false when the ID is not a usable wall button.
func press(_id: StringName) -> bool:
	return false


## Drops presses queued for a tick that will never be observed (pause, reset, scope change).
func cancel_pending() -> void:
	pass


func close() -> void:
	pass
