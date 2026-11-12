class_name CameraPreferenceFile
extends RefCounted
## Local presentation settings are stored separately from authored chamber checkpoints.

const PATH: String = "user://camera.cfg"


static func load_into(preferences: CameraPreferences, path: String = PATH) -> void:
	var file: ConfigFile = ConfigFile.new()
	if file.load(path) != OK:
		return
	preferences.fov = _number(file, "fov", preferences.fov, CameraPreferences.FOV_MIN, CameraPreferences.FOV_MAX)
	preferences.sensitivity = _number(file, "sensitivity", preferences.sensitivity,
		CameraPreferences.SENSITIVITY_MIN, CameraPreferences.SENSITIVITY_MAX)
	preferences.gravity_rate = _number(file, "gravity_rate", preferences.gravity_rate,
		CameraPreferences.ALIGN_MIN, CameraPreferences.ALIGN_MAX)
	var hint: Variant = file.get_value("camera", "show_hint", preferences.show_hint)
	if hint is bool:
		preferences.show_hint = hint == true


static func save(preferences: CameraPreferences, path: String = PATH) -> Error:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("camera", "fov", preferences.fov)
	file.set_value("camera", "sensitivity", preferences.sensitivity)
	file.set_value("camera", "gravity_rate", preferences.gravity_rate)
	file.set_value("camera", "show_hint", preferences.show_hint)
	return file.save(path)


static func _number(file: ConfigFile, key: String, fallback: float, low: float, high: float) -> float:
	var value: Variant = file.get_value("camera", key, fallback)
	if value is float:
		var number: float = value
		return clampf(number, low, high) if is_finite(number) else fallback
	if value is int:
		var integer: int = value
		return clampf(float(integer), low, high)
	return fallback
