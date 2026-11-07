class_name CarryState
extends RefCounted

var held_id: StringName = &""


func take(id: StringName, mass: float, profile: CarryProfile) -> bool:
	if not held_id.is_empty() or id.is_empty() or not profile.accepts_mass(mass):
		return false
	held_id = id
	return true


func release() -> void:
	held_id = &""
