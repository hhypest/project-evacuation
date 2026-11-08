class_name LevelCatalog
extends Resource
## Ordered chambers offered by the technical main menu; the first entry is the default start.

@export var entries: Array[LevelEntry] = []


func titles() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry: LevelEntry in entries:
		result.append(entry.title)
	return result


func scene(index: int) -> PackedScene:
	if index < 0 or index >= entries.size() or entries[index] == null:
		return null
	return entries[index].scene
