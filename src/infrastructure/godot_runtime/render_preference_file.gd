class_name RenderPreferenceFile
extends RefCounted

const PATH: String = "user://graphics.cfg"


static func load_fsr2(path: String = PATH) -> bool:
	var file: ConfigFile = ConfigFile.new()
	if file.load(path) != OK:
		return false
	var saved: Variant = file.get_value("graphics", "fsr2_quality", false)
	return saved is bool and saved == true


static func save_fsr2(enabled: bool, path: String = PATH) -> Error:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("graphics", "fsr2_quality", enabled)
	return file.save(path)
