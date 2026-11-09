class_name CarryWorldPort
extends RefCounted
## Runtime boundary; a missing observation represents a rejected or removed object.


func candidate(_view: Transform3D, _reach: float) -> CarryObservation:
	return null


func observe(_id: StringName) -> CarryObservation:
	return null


func acquire(_id: StringName) -> bool:
	return false


func supporting_player(_id: StringName) -> bool:
	return false


## Moves the held prop toward desired by at most max_step metres and max_turn radians without passing
## through the world or other props; returns where it can stand this tick.
func follow(_id: StringName, _desired: Transform3D, _max_step: float, _max_turn: float) -> CarryTarget:
	return CarryTarget.new()


## Where the held prop would rest if set down on the floor button or resting prop the view ray meets within
## reach: a level support, with room for the prop clear of the world, other props and the carrier.
func placement(_id: StringName, _view: Transform3D, _reach: float, _up: Vector3) -> CarryPlacement:
	return CarryPlacement.new()


## Whether the held prop still fits at pose without touching the world, other props or the carrier.
func fits(_id: StringName, _pose: Transform3D) -> bool:
	return false


func submit(_id: StringName, _command: CarryBodyCommand) -> bool:
	return false


## Per-tick housekeeping for props that were released while still overlapping the carrier.
func settle() -> void:
	pass


func cancel_pending() -> void:
	pass


func close() -> void:
	pass
