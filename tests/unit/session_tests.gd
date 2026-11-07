class_name SessionTests
extends TestSuite


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var session: SessionLifecycle = SessionLifecycle.new()
	results.append(TestOutcome.new("ready session rejects pause/resume/restart",
		not session.pause() and not session.resume() and not session.restart()
		and session.get_generation() == 0))
	results.append(TestOutcome.new("start is accepted exactly once",
		session.start() and not session.start() and session.get_generation() == 1))
	results.append(TestOutcome.new("pause/resume preserves current generation",
		session.pause() and not session.pause() and session.resume()
		and not session.resume() and session.get_generation() == 1))
	session.pause()
	results.append(TestOutcome.new("restart from pause creates a running generation",
		session.restart() and session.get_generation() == 2
		and session.get_phase() == SessionLifecycle.Phase.RUNNING))
	results.append(TestOutcome.new("return to menu preserves generation, new session advances it",
		session.return_to_menu() and not session.return_to_menu()
		and session.get_generation() == 2 and session.start() and session.get_generation() == 3))
	session.stop()
	results.append(TestOutcome.new("stopped session rejects further transitions",
		not session.start() and not session.resume() and not session.restart()
		and not session.return_to_menu() and not session.stop()))
	return results
