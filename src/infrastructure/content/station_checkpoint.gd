class_name StationCheckpoint
extends Resource
## Authored identity and prerequisites shared by the station and the level catalogue.

@export var checkpoint_id: StringName
@export var title: String = ""
@export var required_switches: Array[StringName] = []


func accepts(states: Dictionary[StringName, bool]) -> bool:
	if states.size() != required_switches.size():
		return false
	for id: StringName in required_switches:
		if not states.get(id, false):
			return false
	return true
