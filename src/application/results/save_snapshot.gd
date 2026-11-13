class_name SaveSnapshot
extends RefCounted
## Durable progress at one authored checkpoint. Physics state belongs to the live chamber.

const ENTRY_ID: StringName = &"entry"
const MAX_LEVELS: int = 64
const MAX_SWITCHES: int = 32
const MAX_ID_LENGTH: int = 96

var level_id: StringName
var checkpoint_id: StringName
var game_version: String
var completed_levels: Array[StringName] = []
var switches: Dictionary[StringName, bool] = {}


func _init(level: StringName, version: String, checkpoint: StringName = ENTRY_ID) -> void:
	level_id = level
	game_version = version
	checkpoint_id = checkpoint


func is_valid() -> bool:
	if not valid_id(level_id) or not valid_id(checkpoint_id) or game_version.strip_edges().is_empty() 			or game_version.length() > 64 or completed_levels.size() > MAX_LEVELS or switches.size() > MAX_SWITCHES:
		return false
	if checkpoint_id == ENTRY_ID and not switches.is_empty():
		return false
	var seen: Dictionary[StringName, bool] = {}
	for id: StringName in completed_levels:
		if not valid_id(id) or seen.has(id):
			return false
		seen[id] = true
	for id: StringName in switches:
		if not valid_id(id):
			return false
	return true


func matches(other: SaveSnapshot) -> bool:
	if other == null or level_id != other.level_id or checkpoint_id != other.checkpoint_id 			or game_version != other.game_version or switches != other.switches 			or completed_levels.size() != other.completed_levels.size():
		return false
	for id: StringName in completed_levels:
		if id not in other.completed_levels:
			return false
	return true


static func valid_id(id: StringName) -> bool:
	return not String(id).strip_edges().is_empty() and String(id).length() <= MAX_ID_LENGTH
