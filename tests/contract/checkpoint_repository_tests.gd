class_name CheckpointRepositoryTests
extends TestSuite


func suite_name() -> StringName:
	return &"contract"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var path: String = ProjectSettings.globalize_path("res://work/checkpoint-%d-%d" % [
		OS.get_process_id(), Time.get_ticks_usec()
	])
	var repository: SaveRepository = JsonSaveRepository.new(path)
	results.append(TestOutcome.new("missing saves are normal and reading does not create the directory",
		repository.read_checkpoint().code == SaveResult.Code.MISSING and not DirAccess.dir_exists_absolute(path)))
	var first: SaveSnapshot = SaveSnapshot.new(&"mechanics_lab", "0.0.10-dev")
	var second: SaveSnapshot = SaveSnapshot.new(&"portal_lab", "0.0.10-dev")
	var saved: bool = repository.write_checkpoint(first) == SaveResult.Code.OK
	var loaded: SaveResult = repository.read_checkpoint()
	results.append(TestOutcome.new("JSON round-trip preserves authored checkpoint identity and game version",
		saved and loaded.code == SaveResult.Code.OK and loaded.snapshot.level_id == first.level_id
		and loaded.snapshot.checkpoint_id == SaveSnapshot.ENTRY_ID and loaded.snapshot.game_version == first.game_version))
	var same: bool = repository.write_checkpoint(first) == SaveResult.Code.OK
	results.append(TestOutcome.new("re-entering the same authored checkpoint reuses the existing save",
		same and DirAccess.get_files_at(path).size() == 1))
	saved = repository.write_checkpoint(second) == SaveResult.Code.OK
	loaded = repository.read_checkpoint()
	var files: PackedStringArray = DirAccess.get_files_at(path)
	results.append(TestOutcome.new("a new checkpoint becomes current while the previous file is kept",
		saved and files.size() == 2 and loaded.code == SaveResult.Code.OK and loaded.snapshot.level_id == second.level_id))
	if files.size() == 2:
		var current: String = path.path_join(files[-1])
		_put(path.path_join("checkpoint-000000000003-1-1.json.tmp"), "{")
		loaded = repository.read_checkpoint()
		results.append(TestOutcome.new("an unpublished temporary file cannot mask the latest valid checkpoint",
			loaded.code == SaveResult.Code.OK and loaded.snapshot.level_id == second.level_id))
		_put(current, "{")
		loaded = repository.read_checkpoint()
		results.append(TestOutcome.new("a truncated latest checkpoint falls back without modifying either file",
			loaded.code == SaveResult.Code.OK and loaded.recovered and loaded.snapshot.level_id == first.level_id
			and FileAccess.get_file_as_string(current) == "{"))
		var future: String = '{"schema_version": 3, "level_id": "portal_lab"}'
		_put(current, future)
		results.append(TestOutcome.new("a newer schema blocks both loading and writing through this build",
			repository.read_checkpoint().code == SaveResult.Code.UNSUPPORTED
			and repository.write_checkpoint(first) == SaveResult.Code.UNSUPPORTED
			and FileAccess.get_file_as_string(current) == future))
		_put(current, '{"schema_version": 1, "game_version": "test", "level_id": 7, "checkpoint_id": "entry"}')
		results.append(TestOutcome.new("a wrong field type is rejected and the previous checkpoint is available",
			repository.read_checkpoint().recovered))
	else:
		results.append(TestOutcome.new("fixture contains both checkpoints for failure checks", false))
	results.append_array(_station_roundtrip(path.path_join("station")))
	var blocked: String = path.path_join("saves-blocked")
	_put(blocked, "not a directory")
	var blocked_repository: SaveRepository = JsonSaveRepository.new(blocked)
	results.append(TestOutcome.new("an unwritable saves path fails cleanly without redirecting",
		blocked_repository.read_checkpoint().code == SaveResult.Code.IO_ERROR
		and blocked_repository.write_checkpoint(first) == SaveResult.Code.IO_ERROR
		and FileAccess.get_file_as_string(blocked) == "not a directory"))
	for name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
	return results


func _station_roundtrip(path: String) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	DirAccess.make_dir_recursive_absolute(path)
	var old_path: String = path.path_join("checkpoint-000000000001-1-1.json")
	var old_json: String = '{"schema_version": 1, "game_version": "test", "level_id": "reserve_circuit", "checkpoint_id": "entry"}'
	_put(old_path, old_json)
	var repository: SaveRepository = JsonSaveRepository.new(path)
	var loaded: SaveResult = repository.read_checkpoint()
	results.append(TestOutcome.new("schema 1 entrance loads with empty progress and stays byte-for-byte intact",
		loaded.code == SaveResult.Code.OK and loaded.snapshot.checkpoint_id == SaveSnapshot.ENTRY_ID
		and loaded.snapshot.completed_levels.is_empty() and loaded.snapshot.switches.is_empty()
		and FileAccess.get_file_as_string(old_path) == old_json))
	var station: SaveSnapshot = SaveSnapshot.new(&"reserve_circuit", "test", &"reserve.service_station")
	station.switches[&"reserve.backup"] = true
	var written: bool = repository.write_checkpoint(station) == SaveResult.Code.OK
	loaded = repository.read_checkpoint()
	results.append(TestOutcome.new("station supersedes the same level entry and round-trips toggle state",
		written and loaded.code == SaveResult.Code.OK and loaded.snapshot.matches(station)
		and DirAccess.get_files_at(path).size() == 2))
	station.completed_levels.append(&"reserve_circuit")
	written = repository.write_checkpoint(station) == SaveResult.Code.OK
	var repeated: bool = repository.write_checkpoint(station) == SaveResult.Code.OK
	loaded = repository.read_checkpoint()
	results.append(TestOutcome.new("completion updates the existing station; an identical retry adds no file",
		written and repeated and loaded.code == SaveResult.Code.OK and loaded.snapshot.matches(station)
		and DirAccess.get_files_at(path).size() == 3))
	var invalid: String = '{"schema_version": 2, "game_version": "test", "level_id": "reserve_circuit", "checkpoint_id": "reserve.service_station", "completed_levels": [], "switches": {"reserve.backup": 1}}'
	var file: String = path.path_join("checkpoint-000000000004-1-1.json")
	_put(file, invalid)
	loaded = repository.read_checkpoint()
	results.append(TestOutcome.new("malformed station progress falls back to the last complete generation",
		loaded.code == SaveResult.Code.OK and loaded.recovered and loaded.snapshot.matches(station)
		and FileAccess.get_file_as_string(file) == invalid))
	for name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
	return results


func _put(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()
