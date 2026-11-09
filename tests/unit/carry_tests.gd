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

	var slot: CarryPlacement = CarryPlacement.new()
	var slot_fits: bool = true
	var placement_queries: int = 0

	func placement(_id: StringName, _view: Transform3D, _reach: float, _up: Vector3) -> CarryPlacement:
		placement_queries += 1
		return slot

	func fits(_id: StringName, _pose: Transform3D) -> bool:
		return slot_fits

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
	results.append(TestOutcome.new("level gaze holds the prop low in front, just clear of the capsule",
		hold.is_equal_approx(Vector3(0, profile.hold_height, -(0.3 + profile.hold_gap + 0.5)))))
	var thirty_down: Vector3 = Vector3(0, -0.5, -sqrt(0.75))
	var look_down: Vector3 = CarryRules.hold_point(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, thirty_down, 0.3, 0.5, 0.1, profile)
	var look_up: Vector3 = CarryRules.hold_point(Vector3.ZERO, Vector3.UP, Vector3.FORWARD, Vector3.UP, 0.3, 0.5, 0.1, profile)
	results.append(TestOutcome.new("view pitch lowers and raises the hold point by sin(pitch) * pitch_lift",
		is_equal_approx(look_down.y, profile.hold_height - 0.5 * profile.pitch_lift)
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
	results.append_array(_placement_outcomes(profile))
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


func _placement_outcomes(profile: CarryProfile) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var tilt: float = profile.level_tilt
	var on_side: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	results.append(TestOutcome.new("a support's level axis is its column closest to up, signed, or none when tilted",
		CarryRules.level_axis(Basis.IDENTITY, Vector3.UP, tilt).is_equal_approx(Vector3.UP)
		and CarryRules.level_axis(on_side, Vector3.UP, tilt).is_equal_approx(Vector3.UP)
		and CarryRules.level_axis(Basis(Vector3.RIGHT, PI), Vector3.UP, tilt).is_equal_approx(Vector3.UP)
		and CarryRules.level_axis(Basis(Vector3.RIGHT, deg_to_rad(30)), Vector3.UP, tilt) == Vector3.ZERO
		and CarryRules.level_axis(Basis.IDENTITY, Vector3.RIGHT, tilt).is_equal_approx(Vector3.RIGHT)))
	var reference: Basis = Basis(Vector3.UP, deg_to_rad(30))
	var current: Basis = Basis(Vector3.UP, deg_to_rad(100))
	var pose: Transform3D = CarryRules.slot(Vector3(1, 0.75, 0), reference, Vector3.UP, current, 0.375, 0.01)
	var turn: float = rad_to_deg(reference.x.signed_angle_to(pose.basis.x, Vector3.UP))
	var quarter_error: float = absf(turn - roundf(turn / 90.0) * 90.0)
	var spin: float = rad_to_deg(current.get_rotation_quaternion().angle_to(pose.basis.get_rotation_quaternion()))
	results.append(TestOutcome.new("a slot is centred over the top face, upright, square with the support, nearest quarter",
		pose.origin.is_equal_approx(Vector3(1, 0.75 + 0.375 + 0.01, 0)) and pose.basis.y.is_equal_approx(Vector3.UP)
		and quarter_error < 0.01 and spin <= 45.01 and is_equal_approx(pose.basis.determinant(), 1.0),
		"turn=%.2f spin=%.2f" % [turn, spin]))
	var wall: Transform3D = CarryRules.slot(Vector3(-5, 2, 0), Basis(Vector3.FORWARD, -PI * 0.5), Vector3.RIGHT,
		Basis(Vector3.FORWARD, -PI * 0.5), 0.5, 0.0)
	results.append(TestOutcome.new("a slot follows the carrier's own up on a wall",
		wall.origin.is_equal_approx(Vector3(-4.5, 2, 0)) and wall.basis.y.is_equal_approx(Vector3.RIGHT)))
	var world: FakeWorld = FakeWorld.new()
	world.slot.available = true
	world.slot.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.135, -2.2))
	world.slot.size = Vector3.ONE * 0.75
	var carry: CarryController = CarryController.new(world, profile, 4)
	var input: CarryInput = CarryInput.new()
	input.scope_id = 4
	input.tick_id = 1
	input.interact = true
	carry.step(input)
	input.interact = false
	input.tick_id = 2
	carry.step(input)
	var shown: bool = carry.preview != null and carry.preview.available
	input.interact = true
	input.tick_id = 3
	input.carrier_velocity = Vector3(3, 0, 0)
	carry.step(input)
	var placed: CarryBodyCommand = world.commands[world.commands.size() - 1]
	results.append(TestOutcome.new("aimed at a slot, E sets the prop exactly in it at rest instead of dropping it",
		shown and carry.state.held_id.is_empty() and carry.preview == null and placed.releasing and placed.placing
		and placed.target.is_equal_approx(world.slot.transform) and placed.carrier_velocity == Vector3.ZERO))
	var far: FakeWorld = FakeWorld.new()
	far.slot = world.slot
	far.jammed = true
	var gliding: CarryController = CarryController.new(far, profile, 5)
	input.scope_id = 5
	input.carrier_velocity = Vector3.ZERO
	var held_until: int = -1
	for tick: int in range(40):
		input.tick_id = 10 + tick
		input.interact = tick == 0 or tick == 1
		input.throw_requested = tick == 3
		gliding.step(input)
		if not gliding.state.held_id.is_empty():
			held_until = tick
	var timed_out: CarryBodyCommand = far.commands[far.commands.size() - 1]
	var expected_ticks: int = ceili(profile.place_timeout / input.delta)
	results.append(TestOutcome.new("a glide that cannot arrive sets the prop in its free slot after the timeout",
		timed_out.placing and timed_out.target.is_equal_approx(world.slot.transform)
		and absi(held_until - expected_ticks) <= 1, "held_until=%d expected=%d" % [held_until, expected_ticks]))
	var taken: FakeWorld = FakeWorld.new()
	taken.slot = world.slot
	taken.slot_fits = false
	var blocked: CarryController = CarryController.new(taken, profile, 6)
	input.scope_id = 6
	input.throw_requested = false
	for tick: int in range(3):
		input.tick_id = 60 + tick
		input.interact = tick != 1
		blocked.step(input)
	var dropped: CarryBodyCommand = taken.commands[taken.commands.size() - 1]
	results.append(TestOutcome.new("a slot taken before the prop arrives turns the placement into a plain drop",
		blocked.state.held_id.is_empty() and dropped.releasing and not dropped.placing))
	var none: FakeWorld = FakeWorld.new()
	var plain: CarryController = CarryController.new(none, profile, 7)
	input.scope_id = 7
	for tick: int in range(3):
		input.tick_id = 80 + tick
		input.interact = tick != 1
		plain.step(input)
	var plain_drop: CarryBodyCommand = none.commands[none.commands.size() - 1]
	results.append(TestOutcome.new("without a slot in view E drops as before and no silhouette is shown",
		plain.state.held_id.is_empty() and plain.preview == null and plain_drop.releasing and not plain_drop.placing))
	return results
