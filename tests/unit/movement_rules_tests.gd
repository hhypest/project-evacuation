class_name MovementRulesTests
extends TestSuite


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var profile: MovementProfile = MovementProfile.new()
	var compute: ComputeMovement = ComputeMovement.new()
	var command: MovementCommand = MovementCommand.new()
	var state: MovementObservation = MovementObservation.new()
	state.grounded = true
	command.move_axis = Vector2(0, -1)
	for _tick: int in range(60):
		state.velocity = compute.execute(command, state, profile, 1.0 / 60.0).velocity
	results.append(TestOutcome.new("ground acceleration reaches configured speed",
		absf(state.velocity.slide(Vector3.UP).length() - profile.run_speed) < 0.01))
	command.walking = true
	state.velocity = compute.execute(command, state, profile, 1.0 / 60.0).velocity
	results.append(TestOutcome.new("walk speed is capped independently of run speed",
		absf(state.velocity.slide(Vector3.UP).length() - profile.walk_speed) < 0.01))
	state.crouched = true
	state.velocity = compute.execute(command, state, profile, 1.0 / 60.0).velocity
	results.append(TestOutcome.new("crouched state overrides fast input", state.velocity.length() < 2.0))
	command.move_axis = Vector2.ZERO
	for _tick: int in range(60):
		state.velocity = compute.execute(command, state, profile, 1.0 / 60.0).velocity
	results.append(TestOutcome.new("friction stops planar motion", state.velocity.slide(Vector3.UP).is_zero_approx()))
	command.jump_requested = true
	var jump: MovementStep = compute.execute(command, state, profile, 1.0 / 60.0)
	state.grounded = false
	state.velocity = jump.velocity
	var air: MovementStep = compute.execute(command, state, profile, 1.0 / 60.0)
	results.append(TestOutcome.new("jump uses profile height and cannot repeat in air",
		jump.jumped and is_equal_approx(jump.velocity.y, profile.jump_speed())
		and not air.jumped and air.velocity.y < jump.velocity.y))
	state.velocity = Vector3(0, 0, -6)
	state.crouched = false
	command.move_axis = Vector2(1, 0)
	var strafe: MovementStep = compute.execute(command, state, profile, 1.0 / 60.0)
	results.append(TestOutcome.new("air control changes direction without exceeding run cap",
		strafe.velocity.x > 0 and strafe.velocity.slide(Vector3.UP).length() <= profile.run_speed + 0.001))
	state.on_ladder = true
	command.move_axis = Vector2(0, -1)
	var ladder_jump: MovementStep = compute.execute(command, state, profile, 1.0 / 60.0)
	results.append(TestOutcome.new("ladder jump separates from the ladder face",
		ladder_jump.jumped and ladder_jump.velocity.z > 0 and ladder_jump.velocity.y > 0))
	state.on_ladder = false
	state.in_water = true
	state.near_water_surface = true
	command.jump_held = true
	var water_jump: MovementStep = compute.execute(command, state, profile, 1.0 / 60.0)
	results.append(TestOutcome.new("surface swimming supports an exit impulse",
		water_jump.jumped and is_equal_approx(water_jump.velocity.y, profile.water_jump_speed)))
	command = MovementCommand.new()
	state.near_water_surface = false
	state.velocity = Vector3.ZERO
	for _tick: int in range(120):
		state.velocity = compute.execute(command, state, profile, 1.0 / 60.0).velocity
	results.append(TestOutcome.new("idle swimming reaches and sustains configured buoyancy speed",
		state.velocity.is_equal_approx(Vector3.UP * profile.buoyancy_speed),
		"velocity=%s" % state.velocity))
	state.velocity = Vector3(2, -1, 0)
	for _tick: int in range(240):
		state.velocity = compute.execute(command, state, profile, 1.0 / 60.0).velocity
	results.append(TestOutcome.new("releasing swimming controls brakes drift and recovers passive ascent",
		state.velocity.is_equal_approx(Vector3.UP * profile.buoyancy_speed),
		"velocity=%s" % state.velocity))
	return results
