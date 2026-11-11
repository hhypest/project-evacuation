class_name LevelCatalog
extends Resource
## Ordered chambers offered by the technical main menu; stable IDs resolve saved entrances.

@export var entries: Array[LevelEntry] = []


func titles() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: LevelEntry in entries:
		result.append(item.title if item != null else "")
	return result


func entry(index: int) -> LevelEntry:
	return entries[index] if index >= 0 and index < entries.size() else null


func scene(index: int) -> PackedScene:
	var item: LevelEntry = entry(index)
	return item.scene if item != null else null


func find_level(id: StringName) -> LevelEntry:
	if id.is_empty():
		return null
	var match_entry: LevelEntry
	for item: LevelEntry in entries:
		if item == null or item.level_id != id:
			continue
		if match_entry != null:
			return null
		match_entry = item
	return match_entry if match_entry != null and match_entry.scene != null else null
