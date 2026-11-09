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

	## Without obstacles the prop goes straight to its hold point; a jam keeps it where it is.
	var jammed: bool = false

	func follow(_id: StringName, desired: Transform3D, _max_step: float, _max_turn: float) -> CarryTarget:
		var result: CarryTarget = CarryTarget.new()
		result.available = true
		result.transform = Transform3D(desired.basis, item.position if jammed else desired.origin)
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
	var hold: Vector3 = CarryRules.hold_point(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.FORWARD, 0.3, 0.5, 0.1, profile)
	results.append(TestOutcome.new("level gaze holds the prop at chest height just clear of the capsule",
		hold.is_equal_approx(Vector3(0, profile.hold_height, -(0.3 + profile.hold_gap + 0.5)))))
	var look_down: Vector3 = CarryRules.hold_point(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.DOWN, 0.3, 0.5, 0.1, profile)
	var look_up: Vector3 = CarryRules.hold_point(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.UP, 0.3, 0.5, 0.1, profile)
	results.append(TestOutcome.new("view pitch lowers and raises the hold point by at most pitch_lift",
		is_equal_approx(look_down.y, profile.hold_height - profile.pitch_lift)
		and is_equal_approx(look_up.y, profile.hold_height + profile.pitch_lift) and look_down.z == hold.z))
	var tall_down: Vector3 = CarryRules.hold_point(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.DOWN, 0.3, 0.5, 0.5, profile)
	results.append(TestOutcome.new("looking down never aims a tall prop below the carrier's floor",
		is_equal_approx(tall_down.y, 0.5 + profile.clearance * 2.0) and tall_down.z == hold.z))
	var wall_hold: Vector3 = CarryRules.hold_point(Vector3(-5, 2, 0), Vector3.RIGHT, Vector3.UP, Vector3.UP, 0.3, 0.5, 0.1, profile)
	results.append(TestOutcome.new("the hold point follows the carrier's own up on a wall",
		is_equal_approx(wall_hold.x, -5 + profile.hold_height) and wall_hold.y > 2.5))
	var straight_down: Vector3 = CarryRules.facing(Vector3.DOWN, Vector3.UP, Vector3.LEFT)
	results.append(TestOutcome.new("looking straight down keeps the previous facing",
		straight_down.is_equal_approx(Vector3.LEFT)))
	var tilted: Basis = Basis(Vector3.UP, deg_to_rad(80)) * Basis(Vector3.RIGHT, deg_to_rad(25))
	var upright: Basis = CarryRules.upright_basis(tilted, Vector3.UP, Vector3.FORWARD)
	var yaw: float = rad_to_deg(Vector3.FORWARD.signed_angle_to(-upright.z, Vector3.UP))
	results.append(TestOutcome.new("pick-up straightens the prop and turns it by the nearest quarter turn",
		upright.y.is_equal_approx(Vector3.UP) and absf(absf(yaw) - 90.0) < 0.01))
	var limited: Basis = CarryRules.turn_toward(Basis.IDENTITY, Basis(Vector3.UP, PI * 0.5), 0.2)
	results.append(TestOutcome.new("turning toward the hold orientation is rate limited",
		absf(limited.get_rotation_quaternion().get_angle() - 0.2) < 0.001))
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
	stalled_world.item.position = Vector3(0, 0.5, 4)
	stalled_world.jammed = true
	var stalled: CarryController = CarryController.new(stalled_world, profile, 8)
	var stalled_input: CarryInput = CarryInput.new()
	stalled_input.scope_id = 8
	stalled_input.interact = true
	var held_after_grab: bool = false
	for tick: int in range(40):
		stalled_input.tick_id = tick
		stalled.step(stalled_input)
		if tick == 0:
			held_after_grab = stalled.state.held_id == &"cube"
		stalled_input.interact = false
	results.append(TestOutcome.new("a prop jammed far from its hold point is dropped after the configured delay",
		held_after_grab and stalled.state.held_id.is_empty()
		and stalled_world.commands[stalled_world.commands.size() - 1].releasing))
	var grab_world: FakeWorld = FakeWorld.new()
	var grab: CarryController = CarryController.new(grab_world, profile, 9)
	var grab_input: CarryInput = CarryInput.new()
	grab_input.scope_id = 9
	grab_input.tick_id = 1
	grab_input.interact = true
	grab_input.view = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-40)), Vector3(0, 1.65, 0))
	grab.step(grab_input)
	var first: CarryBodyCommand = grab_world.commands[0] if not grab_world.commands.is_empty() else null
	results.append(TestOutcome.new("one press grabs and places the prop at its hold point in the same tick",
		grab.state.held_id == &"cube" and first != null and not first.releasing
		and first.target.origin.z < -0.5 and first.target.origin.y < profile.hold_height))
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
