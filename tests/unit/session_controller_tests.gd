class_name SessionControllerTests
extends TestSuite


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var controller: SessionController = SessionController.new()
	results.append(TestOutcome.new("invalid runtime and unfocused window reject start",
		not controller.start()))
	controller.configure_runtime(true)
	results.append(TestOutcome.new("valid runtime still requires focused start", not controller.start()))
	controller.set_focus(true)
	controller.start()
	controller.set_focus(false)
	results.append(TestOutcome.new("losing focus pauses and rejects resume/restart",
		controller.get_status().phase == SessionLifecycle.Phase.PAUSED
		and not controller.resume() and not controller.restart()
		and not controller.get_status().accepts_gameplay))
	controller.set_focus(true)
	results.append(TestOutcome.new("focus return waits for explicit resume",
		controller.get_status().phase == SessionLifecycle.Phase.PAUSED
		and controller.resume() and controller.get_status().accepts_gameplay))
	controller.configure_runtime(false)
	results.append(TestOutcome.new("runtime failure closes gameplay gate",
		controller.get_status().phase == SessionLifecycle.Phase.PAUSED and not controller.resume()))
	controller.stop()
	controller.configure_runtime(true)
	results.append(TestOutcome.new("stopped session cannot be revived by focus or runtime changes",
		not controller.start() and not controller.resume() and not controller.restart()))
	return results
