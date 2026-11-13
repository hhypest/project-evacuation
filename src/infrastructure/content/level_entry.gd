class_name LevelEntry
extends Resource
## One selectable chamber of the technical menu.

@export var level_id: StringName
@export var title: String = ""
@export_multiline var summary: String = ""
@export var scene: PackedScene
@export var stations: Array[StationCheckpoint] = []


func station(id: StringName) -> StationCheckpoint:
	var result: StationCheckpoint = null
	for item: StationCheckpoint in stations:
		if item != null and item.checkpoint_id == id:
			if result != null:
				return null
			result = item
	return result
