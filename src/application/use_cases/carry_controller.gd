class_name CarryController
extends RefCounted
## Talos-style carry (ADR-0012): one press grabs, the prop sticks to a point in front of the carrier,
## another press drops it, the throw button throws it. Aimed at a floor button or a resting prop, the press
## sets it down exactly in the slot its silhouette shows instead.

var state: CarryState = CarryState.new()
## Slot the silhouette shows this tick; null while nothing is held or no slot is in view.
var preview: CarryPlacement = null
var _world: CarryWorldPort
var _profile: CarryProfile
var _scope_id: int
var _last_tick: int = -1
var _facing: Vector3 = Vector3.FORWARD
var _separated_seconds: float = 0.0
var _placing: bool = false
var _slot: Transform3D = Transform3D.IDENTITY
var _placing_seconds: float = 0.0


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
		if _placing:
			_glide(request)
			return
		if request.interact:
			var target: CarryPlacement = _world.placement(state.held_id, request.view, _profile.place_reach,
				request.carrier_up)
			if target.available:
				preview = target
				_placing = true
				_slot = target.transform
				_placing_seconds = 0.0
				_glide(request)
			else:
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
		_forget()
		return
	var shown: CarryPlacement = _world.placement(state.held_id, request.view, _profile.place_reach,
		request.carrier_up)
	preview = shown if shown.available else null


func suspend() -> void:
	_world.cancel_pending()


func portal_reframe(rotation: Basis) -> void:
	_facing = rotation * _facing
	_separated_seconds = 0.0
	_placing = false
	preview = null


func drop_for_portal(id: StringName) -> void:
	_world.release_for_portal(id)
	if state.held_id == id:
		_forget()


func close() -> void:
	_scope_id = -1
	_world.close()
	_forget()


## The held prop moves to its slot by the same sweeps as the hold. Once it has arrived within place_settle it is
## set exactly in the slot and let go at rest, if the slot is still free and the last short stretch is clear.
## Otherwise, or when it cannot arrive within place_timeout (a gap the view passes but the prop does not), it is
## let go where the sweeps left it: placement never moves a prop through geometry.
func _glide(request: CarryInput) -> void:
	_placing_seconds += request.delta
	var reached: CarryTarget = _world.follow(state.held_id, _slot,
		_profile.pull_speed * request.delta, _profile.turn_speed * request.delta)
	if not reached.available:
		_release(request)
		return
	if reached.transform.origin.distance_to(_slot.origin) <= _profile.place_settle:
		if _world.settles(state.held_id, reached.transform, _slot):
			var command: CarryBodyCommand = _command(request)
			command.releasing = true
			command.placing = true
			command.target = _slot
			command.carrier_velocity = Vector3.ZERO
			_world.submit(state.held_id, command)
			_forget()
		else:
			_release(request)
		return
	if _placing_seconds >= _profile.place_timeout:
		_release(request)
		return
	var step: CarryBodyCommand = _command(request)
	step.target = reached.transform
	if not _world.submit(state.held_id, step):
		_forget()


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
	_forget()


func _forget() -> void:
	state.release()
	preview = null
	_placing = false
	_placing_seconds = 0.0
