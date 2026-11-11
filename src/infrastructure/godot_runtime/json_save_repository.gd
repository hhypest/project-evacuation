class_name JsonSaveRepository
extends SaveRepository
## Each committed checkpoint has its own name. Windows' DirAccess.rename can remove an existing
## destination before moving, so publication never targets an earlier checkpoint.

const SCHEMA_VERSION: int = 1
const MAX_FILE_BYTES: int = 16 * 1024
const MAX_SEQUENCE: int = 999999999999

var _directory: String


func _init(directory: String = "") -> void:
	_directory = game_directory() if directory.is_empty() else ProjectSettings.globalize_path(directory)


static func game_directory() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://saves")
	return OS.get_executable_path().get_base_dir().path_join("saves")


func read_checkpoint() -> SaveResult:
	if FileAccess.file_exists(_directory):
		return SaveResult.new(SaveResult.Code.IO_ERROR)
	if not DirAccess.dir_exists_absolute(_directory):
		return SaveResult.new(SaveResult.Code.MISSING)
	var directory: DirAccess = DirAccess.open(_directory)
	if directory == null:
		return SaveResult.new(SaveResult.Code.IO_ERROR)
	return _latest(_checkpoint_files(directory))


func write_checkpoint(snapshot: SaveSnapshot) -> SaveResult.Code:
	if snapshot == null or not snapshot.is_valid():
		return SaveResult.Code.INVALID
	if FileAccess.file_exists(_directory) or DirAccess.make_dir_recursive_absolute(_directory) != OK:
		return SaveResult.Code.IO_ERROR
	var directory: DirAccess = DirAccess.open(_directory)
	if directory == null:
		return SaveResult.Code.IO_ERROR
	var files: PackedStringArray = _checkpoint_files(directory)
	var current: SaveResult = _latest(files)
	if current.code in [SaveResult.Code.UNSUPPORTED, SaveResult.Code.IO_ERROR]:
		return current.code
	# Re-entering the same authored checkpoint adds no new progress.
	if current.code == SaveResult.Code.OK and not current.recovered \
			and current.snapshot.level_id == snapshot.level_id and current.snapshot.game_version == snapshot.game_version:
		return SaveResult.Code.OK
	var sequence: int = 1 if files.is_empty() else files[-1].get_slice("-", 1).to_int() + 1
	if sequence > MAX_SEQUENCE:
		return SaveResult.Code.IO_ERROR
	var target: String = _directory.path_join("checkpoint-%012d-%d-%d.json" % [
		sequence, OS.get_process_id(), Time.get_ticks_usec()
	])
	var temporary: String = target + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return SaveResult.Code.IO_ERROR
	var data: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"game_version": snapshot.game_version,
		"level_id": String(snapshot.level_id),
		"checkpoint_id": String(snapshot.checkpoint_id)
	}
	file.store_string(JSON.stringify(data, "\t") + "\n")
	file.flush()
	var flushed: bool = file.get_error() == OK
	file.close()
	var checked: SaveResult = _read_file(temporary)
	if not flushed or checked.code != SaveResult.Code.OK or checked.snapshot.level_id != snapshot.level_id \
			or checked.snapshot.game_version != snapshot.game_version or FileAccess.file_exists(target) \
			or DirAccess.rename_absolute(temporary, target) != OK:
		DirAccess.remove_absolute(temporary)
		return SaveResult.Code.IO_ERROR
	return SaveResult.Code.OK


func _latest(files: PackedStringArray) -> SaveResult:
	var recovered: bool = false
	for index: int in range(files.size() - 1, -1, -1):
		var result: SaveResult = _read_file(_directory.path_join(files[index]))
		if result.code == SaveResult.Code.INVALID:
			recovered = true
			continue
		result.recovered = recovered and result.code == SaveResult.Code.OK
		return result
	return SaveResult.new(SaveResult.Code.INVALID if recovered else SaveResult.Code.MISSING)


func _checkpoint_files(directory: DirAccess) -> PackedStringArray:
	var result: PackedStringArray = []
	for name: String in directory.get_files():
		if not name.begins_with("checkpoint-") or name.get_extension() != "json":
			continue
		var parts: PackedStringArray = name.get_basename().split("-")
		if parts.size() == 4 and parts[1].length() == 12 and parts[1].is_valid_int() \
				and parts[2].is_valid_int() and parts[3].is_valid_int():
			result.append(name)
	result.sort()
	return result


func _read_file(path: String) -> SaveResult:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return SaveResult.new(SaveResult.Code.IO_ERROR)
	if file.get_length() > MAX_FILE_BYTES:
		return SaveResult.new(SaveResult.Code.INVALID)
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return SaveResult.new(SaveResult.Code.INVALID)
	# The JSON API returns Variant. The runtime guard above establishes the dictionary type.
	@warning_ignore("unsafe_cast")
	var data: Dictionary = parser.data as Dictionary
	var version: Variant = data.get("schema_version")
	if not (version is int or version is float):
		return SaveResult.new(SaveResult.Code.INVALID)
	if version != SCHEMA_VERSION:
		return SaveResult.new(SaveResult.Code.UNSUPPORTED)
	var level: Variant = data.get("level_id")
	var checkpoint: Variant = data.get("checkpoint_id")
	var game: Variant = data.get("game_version")
	if not (level is String and checkpoint is String and game is String):
		return SaveResult.new(SaveResult.Code.INVALID)
	var snapshot: SaveSnapshot = SaveSnapshot.new(StringName(str(level)), str(game), StringName(str(checkpoint)))
	return SaveResult.new(SaveResult.Code.OK, snapshot) if snapshot.is_valid() else SaveResult.new(SaveResult.Code.INVALID)
