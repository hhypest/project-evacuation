class_name SaveSnapshot
extends RefCounted
## Stable identity of a safe checkpoint. Schema 1 captures the authored entrance.

const ENTRY_ID: StringName = &"entry"

var level_id: StringName
var checkpoint_id: StringName
var game_version: String


func _init(level: StringName, version: String, checkpoint: StringName = ENTRY_ID) -> void:
	level_id = level
	game_version = version
	checkpoint_id = checkpoint


func is_valid() -> bool:
	return not level_id.is_empty() and String(level_id).length() <= 96 \
		and checkpoint_id == ENTRY_ID and not game_version.strip_edges().is_empty() and game_version.length() <= 64
