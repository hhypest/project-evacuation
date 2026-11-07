class_name RuntimeProbe
extends RefCounted
## Converts engine-owned dictionaries/settings into a typed application contract.


func read() -> RuntimeInfo:
	var version: Dictionary = Engine.get_version_info()
	var numeric_version: String = "unknown"
	var major: Variant = version.get("major")
	var minor: Variant = version.get("minor")
	var patch: Variant = version.get("patch")
	if major is int and minor is int and patch is int:
		numeric_version = "%d.%d.%d" % [major, minor, patch]
	var headless: bool = DisplayServer.get_name() == "headless"
	var driver: StringName = &"headless"
	if not headless:
		driver = RenderingServer.get_current_rendering_driver_name()
	var physics: StringName = &"unknown"
	var raw_physics: Variant = ProjectSettings.get_setting("physics/3d/physics_engine")
	if raw_physics is String:
		physics = StringName(str(raw_physics))
	return RuntimeInfo.new(numeric_version, driver, physics, headless)
