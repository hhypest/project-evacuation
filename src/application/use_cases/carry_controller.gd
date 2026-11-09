class_name CarryController
extends RefCounted
## Talos-style carry (ADR-0012): one press grabs, the prop sticks to a point in front of the carrier,
## another press drops it, the throw button throws it.

var state: CarryState = CarryState.new()
var _world: CarryWorldPort
var _profile: CarryProfile
var _scope_id: int
var _last_tick: int = -1
var _facing: Vector3 = Vector3.FORWARD
var _separated_seconds: float = 0.0


func _init(world: CarryWorldPort, profile: CarryProfile, scope_id: int) -> void:
	_world = world
	_profile = profile
	_scope_id = scope_id


func step(request: CarryInput) -> void:
	if _scope_id < 0 or request.scope_id != _scope_id or request.tick_id <= _last_tick:
		return
	_last_tick = request.tick_id
	_world.settle()
	var view_forward: Vector3 = -request.view.basis.z
	_facing = CarryRules.facing(view_forward, request.carrier_up, _facing)
	if state.held_id.is_empty():
		if not request.interact:
			return
		var candidate: CarryObservation = _world.candidate(request.view, _profile.reach)
		if candidate == null or not _profile.accepts_mass(candidate.mass) or _world.supporting_player(candidate.id):
			return
		if not _world.acquire(candidate.id):
			return
		state.take(candidate.id, candidate.mass, _profile)
		_separated_seconds = 0.0
	else:
		if request.interact:
			_release(request)
			return
		if request.throw_requested:
			var thrown: CarryObservation = _world.observe(state.held_id)
			if thrown != null and _profile.accepts_mass(thrown.mass):
				_release(request, CarryRules.throw_impulse(view_forward, request.carrier_velocity, thrown.mass, _profile))
			else:
				_release(request)
			return
	var observed: CarryObservation = _world.observe(state.held_id)
	if observed == null or not _profile.accepts_mass(observed.mass):
		_release(request)
		return
	var desired: Transform3D = Transform3D(
		CarryRules.upright_basis(observed.basis, request.carrier_up, _facing),
		CarryRules.hold_point(request.carrier_feet, request.carrier_up, _facing, view_forward,
			request.carrier_radius, observed.half_extent, observed.half_height, _profile))
	var reached: CarryTarget = _world.follow(state.held_id, desired,
		_profile.pull_speed * request.delta, _profile.turn_speed * request.delta)
	if not reached.available:
		_release(request)
		return
	if reached.transform.origin.distance_to(desired.origin) > _profile.break_distance:
		_separated_seconds += request.delta
	else:
		_separated_seconds = 0.0
	if _separated_seconds >= _profile.break_delay:
		_release(request)
		return
	var command: CarryBodyCommand = _command(request)
	command.target = reached.transform
	command.carrier_velocity = request.carrier_velocity
	if not _world.submit(state.held_id, command):
		state.release()


func suspend() -> void:
	_world.cancel_pending()


func close() -> void:
	_scope_id = -1
	_world.close()
	state.release()


func _command(request: CarryInput) -> CarryBodyCommand:
	var command: CarryBodyCommand = CarryBodyCommand.new()
	command.scope_id = _scope_id
	command.tick_id = request.tick_id
	command.carrier_velocity = request.carrier_velocity
	return command


func _release(request: CarryInput, impulse: Vector3 = Vector3.ZERO) -> void:
	var command: CarryBodyCommand = _command(request)
	command.releasing = true
	command.impulse = impulse
	_world.submit(state.held_id, command)
	state.release()
