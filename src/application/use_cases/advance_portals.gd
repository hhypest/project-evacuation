class_name AdvancePortals
extends RefCounted
## One tick of portal transfer: detect swept crossings of powered pairs, check the whole exit volume, then
## transfer (position, orientation, linear and angular velocity) or hold the body on the entry side.

var errors: PackedStringArray = PackedStringArray()
var transfers: Array[PortalTransfer] = []
var _world: PortalWorldPort
var _scope_id: int = -1
var _last_tick: int = -1
var _previous: Dictionary[StringName, Vector3] = {}
## Body ID -> exit plane ID that last sent it out; cleared once the body is clear of that exit.
var _guard: Dictionary[StringName, StringName] = {}
var _next_crossing: int = 1


func _init(world: PortalWorldPort, scope_id: int) -> void:
	_world = world
	_scope_id = scope_id
	var seen: Dictionary[StringName, bool] = {}
	for pair: PortalPairState in world.pairs():
		for plane: PortalPlane in [pair.a, pair.b]:
			errors.append_array(plane.validate())
			if seen.has(plane.id):
				errors.append("duplicate portal ID '%s'" % plane.id)
			seen[plane.id] = true
		if pair.a.half_size != pair.b.half_size:
			errors.append("portal pair '%s' needs two openings of the same size" % pair.id)


func ready() -> bool:
	return errors.is_empty()


## Forget positions after a reset or reload so no stale segment can count as a crossing.
func reset() -> void:
	_previous.clear()
	_guard.clear()


func step(scope_id: int, tick_id: int) -> Array[PortalTransfer]:
	var done: Array[PortalTransfer] = []
	if scope_id != _scope_id or tick_id <= _last_tick or not ready():
		return done
	_last_tick = tick_id
	var pairs: Array[PortalPairState] = _world.pairs()
	for body: PortalBodyState in _world.bodies():
		var current: Vector3 = body.transform.origin
		var previous: Vector3 = _previous.get(body.id, current)
		_previous[body.id] = current
		_release_guard(body, pairs)
		if body.held:
			continue
		for pair: PortalPairState in pairs:
			if not pair.powered:
				continue
			var outcome: PortalTransfer = _try(pair, pair.a, pair.b, body, previous, current, tick_id)
			if outcome == null:
				outcome = _try(pair, pair.b, pair.a, body, previous, current, tick_id)
			if outcome != null:
				done.append(outcome)
				break
	transfers.append_array(done)
	return done


func _try(pair: PortalPairState, entry: PortalPlane, exit: PortalPlane, body: PortalBodyState,
		previous: Vector3, current: Vector3, tick_id: int) -> PortalTransfer:
	if _guard.get(body.id, &"") == entry.id or not PortalRules.crosses(entry, previous, current):
		return null
	var outcome: PortalTransfer = PortalTransfer.new()
	outcome.crossing_id = _next_crossing
	_next_crossing += 1
	outcome.tick_id = tick_id
	outcome.body_id = body.id
	outcome.pair_id = pair.id
	outcome.entry_id = entry.id
	outcome.exit_id = exit.id
	var destination: Transform3D = PortalMath.map_transform(entry.transform, exit.transform, body.transform)
	if _world.exit_free(body.id, destination):
		_world.teleport(body.id, destination, PortalMath.map_vector(entry.transform, exit.transform, body.linear_velocity),
			PortalMath.map_vector(entry.transform, exit.transform, body.angular_velocity))
		_guard[body.id] = exit.id
		_previous[body.id] = destination.origin
	else:
		outcome.blocked = true
		# Back to the front of the entry with no velocity into the plane.
		var local: Transform3D = entry.transform.affine_inverse() * body.transform
		local.origin.z = body.extent + 0.02
		var velocity: Vector3 = entry.transform.basis.inverse() * body.linear_velocity
		velocity.z = maxf(0.0, velocity.z)
		var held_at: Transform3D = entry.transform * local
		_world.hold(body.id, held_at, entry.transform.basis * velocity)
		_previous[body.id] = held_at.origin
	return outcome


func _release_guard(body: PortalBodyState, pairs: Array[PortalPairState]) -> void:
	var guarded: StringName = _guard.get(body.id, &"")
	if guarded.is_empty():
		return
	for pair: PortalPairState in pairs:
		for plane: PortalPlane in [pair.a, pair.b]:
			if plane.id == guarded and PortalRules.guard_released(plane, body.transform.origin, body.extent):
				_guard.erase(body.id)
