class_name ValidateRuntime
extends RefCounted
## Headless is allowed for CPU tests, never reported as Vulkan validation.

const REQUIRED_VERSION: String = "4.7.2"


func execute(info: RuntimeInfo, allow_headless: bool = false) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if info.engine_version != REQUIRED_VERSION:
		errors.append("Expected Godot %s, got %s." % [REQUIRED_VERSION, info.engine_version])
	if info.physics_backend != &"Jolt Physics":
		errors.append("Expected explicitly selected Jolt Physics.")
	if info.headless:
		if not allow_headless:
			errors.append("This check requires a real Vulkan display.")
	elif info.rendering_driver != &"vulkan":
		errors.append("Expected active Vulkan driver, got %s." % info.rendering_driver)
	return errors
