class_name CarryTests
extends TestSuite


class FakeWorld extends CarryWorldPort:
	var item: CarryObservation = CarryObservation.new()
	var accepts: bool = true
	var supporting: bool = false
	var commands: Array[CarryBodyCommand] = []
	var cancelled: bool = false
	var closed: bool = false

	func _init() -> void:
		item.id = &"cube"
		item.mass = 20.0
		item.position = Vector3(0, 0, -2)

	func candidate(_view: Transform3D, _reach: float) -> CarryObservation:
		return item

	func observe(_id: StringName) -> CarryObservation:
		return item

	func acquire(_id: StringName) -> bool:
		return accepts

	func supporting_player(_id: StringName) -> bool:
		return supporting

	func target(_id: StringName, _view: Transform3D, basis: Basis) -> CarryTarget:
		var result: CarryTarget = CarryTarget.new()
		result.available = true
		result.transform = Transform3D(basis, Vector3(0, 0, -2))
		return result

	func submit(_id: StringName, command: CarryBodyCommand) -> bool:
		commands.append(command)
		return true

	func cancel_pending() -> void:
		cancelled = true

	func close() -> void:
		closed = true


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var profile: CarryProfile = CarryProfile.new()
	results.append(TestOutcome.new("carry mass rejects nonfinite, light and overweight values",
		not profile.accepts_mass(NAN) and not profile.accepts_mass(INF)
		and not profile.accepts_mass(0.5) and not profile.accepts_mass(80)
		and profile.accepts_mass(1) and profile.accepts_mass(40)))
	var state: CarryState = CarryState.new()
	results.append(TestOutcome.new("one player owns at most one stable carry ID",
		state.take(&"cube", 20, profile) and not state.take(&"other", 5, profile)))
	state.release()
	results.append(TestOutcome.new("release clears ownership and permits another eligible body",
		state.held_id.is_empty() and not state.take(&"", 5, profile) and state.take(&"other", 5, profile)))
	var force: Vector3 = CarryRules.force(Vector3(100, 0, 0), Vector3.ZERO, Vector3.DOWN * 9.8, 20, profile)
	results.append(TestOutcome.new("spring force remains bounded for extreme separation", force.length() <= profile.max_force + 0.001))
	var support: Vector3 = CarryRules.force(Vector3.ZERO, Vector3.ZERO, Vector3.DOWN * 9.8, 20, profile)
	results.append(TestOutcome.new("stationary hold compensates effective gravity exactly once", absf(support.y - 196) < 0.001))
	var light: Vector3 = CarryRules.throw_impulse(Vector3.FORWARD, Vector3.ZERO, 5, profile)
	var heavy: Vector3 = CarryRules.throw_impulse(Vector3.FORWARD, Vector3.ZERO, 40, profile)
	results.append(TestOutcome.new("bounded throw impulse gives heavy bodies a smaller speed change",
		light.length() / 5 > heavy.length() / 40 and heavy.length() <= profile.throw_impulse
		and light.length() / 5 <= profile.max_throw_speed))
	var world: FakeWorld = FakeWorld.new()
	var carry: CarryController = CarryController.new(world, profile, 7)
	var input: CarryInput = CarryInput.new()
	input.scope_id = 7
	input.tick_id = 1
	input.interact = true
	world.accepts = false
	carry.step(input)
	results.append(TestOutcome.new("failed physical acquisition never grants domain ownership", carry.state.held_id.is_empty()))
	world.accepts = true
	input.tick_id = 2
	carry.step(input)
	var count: int = world.commands.size()
	carry.step(input)
	input.scope_id = 6
	input.tick_id = 3
	carry.step(input)
	results.append(TestOutcome.new("carry rejects duplicate ticks and old scopes", world.commands.size() == count and carry.state.held_id == &"cube"))
	input.scope_id = 7
	input.tick_id = 3
	input.interact = false
	input.throw_requested = true
	carry.step(input)
	input.tick_id = 4
	carry.step(input)
	var thrown_command: CarryBodyCommand = world.commands[world.commands.size() - 1]
	results.append(TestOutcome.new("throw releases ownership and queues one impulse only",
		carry.state.held_id.is_empty() and world.commands.size() == count + 1
		and thrown_command.releasing and thrown_command.impulse.length() > 0))
	input.interact = true
	input.throw_requested = false
	input.tick_id = 5
	world.supporting = true
	carry.step(input)
	results.append(TestOutcome.new("a player cannot lift their supporting cube", carry.state.held_id.is_empty()))
	world.supporting = false
	input.tick_id = 6
	carry.step(input)
	world.item.mass = 80.0
	input.interact = false
	input.throw_requested = true
	input.tick_id = 7
	carry.step(input)
	var overweight_release: CarryBodyCommand = world.commands[world.commands.size() - 1]
	results.append(TestOutcome.new("mass becoming ineligible releases without a throw impulse",
		carry.state.held_id.is_empty() and overweight_release.releasing and overweight_release.impulse == Vector3.ZERO))
	world.item.mass = 20.0
	input.throw_requested = false
	input.interact = true
	input.tick_id = 8
	carry.step(input)
	world.item = null
	input.interact = false
	input.tick_id = 9
	carry.step(input)
	results.append(TestOutcome.new("removed body clears carry state safely", carry.state.held_id.is_empty()))
	carry.suspend()
	carry.close()
	input.tick_id = 10
	input.interact = true
	carry.step(input)
	results.append(TestOutcome.new("suspend cancels pending physics and closed scope rejects new input",
		world.cancelled and world.closed and carry.state.held_id.is_empty()))
	var stalled_world: FakeWorld = FakeWorld.new()
	stalled_world.item.position = Vector3(-1.5, 0, -2)
	var stalled: CarryController = CarryController.new(stalled_world, profile, 8)
	var stalled_input: CarryInput = CarryInput.new()
	stalled_input.scope_id = 8
	stalled_input.interact = true
	for tick: int in range(40):
		stalled_input.tick_id = tick
		stalled.step(stalled_input)
		stalled_input.interact = false
	results.append(TestOutcome.new("persistent target separation releases a jammed carry after the configured delay",
		stalled.state.held_id.is_empty() and stalled_world.commands[stalled_world.commands.size() - 1].releasing))
	var buffer: GameplayInputBuffer = GameplayInputBuffer.new()
	buffer.configure(true, 1)
	buffer.record_action(&"throw_prop", true)
	buffer.record_action(&"throw_prop", true, true)
	results.append(TestOutcome.new("throw input is an edge consumed once",
		buffer.take_frame().throw_requested and not buffer.take_frame().throw_requested))
	buffer.configure(false, 1)
	buffer.configure(true, 1)
	buffer.record_action(&"throw_prop", true)
	var blocked: bool = not buffer.take_frame().throw_requested
	buffer.record_action(&"throw_prop", false)
	buffer.record_action(&"throw_prop", true)
	results.append(TestOutcome.new("pause quarantines a held throw until release and fresh press", blocked and buffer.take_frame().throw_requested))
	return results
