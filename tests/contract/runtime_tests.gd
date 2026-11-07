class_name RuntimeTests
extends TestSuite


func suite_name() -> StringName:
	return &"contract"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var validator: ValidateRuntime = ValidateRuntime.new()
	var results: Array[TestOutcome] = []
	results.append(TestOutcome.new("supported Vulkan/Jolt runtime is accepted",
		validator.execute(RuntimeInfo.new("4.7.2", &"vulkan", &"Jolt Physics", false)).is_empty()))
	results.append(TestOutcome.new("fallback graphics and physics are rejected",
		validator.execute(RuntimeInfo.new("4.7.2", &"opengl3", &"GodotPhysics3D", false)).size() == 2))
	results.append(TestOutcome.new("engine version mismatch is rejected",
		not validator.execute(RuntimeInfo.new("4.6.0", &"vulkan", &"Jolt Physics", false)).is_empty()))
	var headless: RuntimeInfo = RuntimeInfo.new("4.7.2", &"headless", &"Jolt Physics", true)
	results.append(TestOutcome.new("headless requires explicit CPU-test permission",
		not validator.execute(headless).is_empty() and validator.execute(headless, true).is_empty()))
	return results
