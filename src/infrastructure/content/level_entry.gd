class_name LevelEntry
extends Resource
## One selectable chamber of the technical menu.

@export var level_id: StringName
@export var title: String = ""
@export_multiline var summary: String = ""
@export var scene: PackedScene
@export var checkpoints: Array[ChamberCheckpoint] = []


func checkpoint(id: StringName) -> ChamberCheckpoint:
	var result: ChamberCheckpoint = null
	for item: ChamberCheckpoint in checkpoints:
		if item != null and item.checkpoint_id == id:
			if result != null:
				return null
			result = item
	return result
