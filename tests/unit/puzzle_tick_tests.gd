class_name PuzzleTickTests
extends TestSuite

class World:
	extends PuzzleWorldPort
	var pending: Array[StringName] = []
	var observed: int = 0
	var applied: int = 0

	func definitions() -> Array[DeviceDefinition]:
		var button: DeviceDefinition = DeviceDefinition.make(&"button", DeviceDefinition.Kind.WALL_BUTTON)
		button.wall_mode = DeviceDefinition.WallMode.TOGGLE
		return [button]

	func observe(tick_id: int) -> PuzzleObservation:
		observed += 1
		var snapshot: PuzzleObservation = PuzzleObservation.new()
		snapshot.tick_id = tick_id
		snapshot.presses = pending.duplicate()
		pending.clear()
		return snapshot

	func apply(_result: PuzzleStepResult) -> void:
		applied += 1

	func cancel_pending() -> void:
		pending.clear()


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var world: World = World.new()
	var use_case: AdvancePuzzle = AdvancePuzzle.new(world, 4, 2.0)
	use_case.step(4, 10)
	world.pending.append(&"button")
	var duplicate: PuzzleStepResult = use_case.step(4, 10)
	var stale: PuzzleStepResult = use_case.step(4, 9)
	var foreign: PuzzleStepResult = use_case.step(5, 11)
	results.append(TestOutcome.new("rejected puzzle ticks do not observe, consume queued input or apply actuators",
		duplicate == null and stale == null and foreign == null and world.observed == 1 and world.applied == 1
		and world.pending == [&"button"]))
	var next: PuzzleStepResult = use_case.step(4, 11)
	results.append(TestOutcome.new("the next valid puzzle tick receives the preserved press exactly once",
		next != null and next.output(&"button") and world.pending.is_empty() and world.observed == 2 and world.applied == 2))
	use_case.step(4, 12)
	results.append(TestOutcome.new("a preserved press is not replayed on subsequent valid ticks", use_case.network.output(&"button")))
	world.pending.append(&"button")
	use_case.reset()
	var restarted: PuzzleStepResult = use_case.step(4, 1)
	results.append(TestOutcome.new("explicit puzzle reset clears pending input and starts a new logical tick history",
		restarted != null and not restarted.output(&"button") and world.pending.is_empty()))
	return results
