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


func target(_id: StringName, _view: Transform3D, _basis: Basis) -> CarryTarget:
	return CarryTarget.new()


func submit(_id: StringName, _command: CarryBodyCommand) -> bool:
	return false


func cancel_pending() -> void:
	pass


func close() -> void:
	pass
