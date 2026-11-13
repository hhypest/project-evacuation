class_name RenderPreferenceFile
extends RefCounted

const PATH: String = "user://graphics.cfg"


static func load_fsr2(path: String = PATH) -> bool:
	var file: ConfigFile = ConfigFile.new()
	return file.load(path) == OK and file.get_value("graphics", "fsr2_quality", false) == true


static func save_fsr2(enabled: bool, path: String = PATH) -> Error:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("graphics", "fsr2_quality", enabled)
	return file.save(path)
