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


func submit(_id: StringName, _command: CarryBodyCommand) -> bool:
	return false


func cancel_pending() -> void:
	pass


func close() -> void:
	pass
