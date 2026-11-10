class_name AdvancePortals
extends RefCounted
## Swept crossings, complete shapes and grouped carry transfer. prepare() closes real entry barriers
## before player movement/next Jolt step; step() commits passages after the network/carry tick.

var errors: PackedStringArray = PackedStringArray()
var transfers: Array[PortalTransfer] = []
const HISTORY_LIMIT: int = 128
var crossing_count: int = 0
var blocked_count: int = 0
## Unrecoverable geometry stops the scope until Bootstrap replaces the entire chamber generation.
var recovery_required: bool = false
var recovery_body_id: StringName = &""
var _safe_poses: Dictionary[StringName, PortalRecoveryPose] = {}
var _world: PortalWorldPort
var _scope_id: int = -1
var _last_tick: int = -1
var _previous: Dictionary[StringName, Vector3] = {}
var _guard: Dictionary[StringName, StringName] = {}
var _powered: Dictionary[StringName, bool] = {}
## A held centre may be beyond the entry before its carrier crosses. Releasing it there must
## materialise the visible body at the exit, not leave the physical prop behind the entry wall.
var _held_entries: Dictionary[StringName, StringName] = {}
var _held_carriers: Dictionary[StringName, StringName] = {}
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


func reset() -> void:
	recovery_required = false
	recovery_body_id = &""
	_safe_poses.clear()
	transfers.clear()
	crossing_count = 0
	blocked_count = 0
	_previous.clear()
	_guard.clear()
	_powered.clear()
	for id: StringName in _held_entries.keys():
		_world.straddle(id, &"")
	_held_entries.clear()
	_held_carriers.clear()
	for pair: PortalPairState in _world.pairs():
		_world.set_barrier(pair.a.id, false)
		_world.set_barrier(pair.b.id, false)


func prepare(scope_id: int, delta: float) -> void:
	if scope_id != _scope_id or not ready() or recovery_required:
		return
	var pairs: Array[PortalPairState] = _world.pairs()
	if pairs.is_empty():
		return
	var bodies: Array[PortalBodyState] = _world.bodies()
	_remember_safe(pairs, bodies)
	for pair: PortalPairState in pairs:
		_prepare_entry(pair.a, pair.b, pair.powered, bodies, delta)
		if recovery_required:
			return
		_prepare_entry(pair.b, pair.a, pair.powered, bodies, delta)
		if recovery_required:
			return


func _prepare_entry(entry: PortalPlane, exit: PortalPlane, powered: bool,
		bodies: Array[PortalBodyState], delta: float) -> void:
	var blocked: bool = false
	if powered:
		for body: PortalBodyState in bodies:
			# Companions are admitted or safely detached by the carrier's transaction in _try().
			# Closing the shared slab for them here would prevent that transaction ever being reached.
			if body.held:
				continue
			if _guard.get(body.id, &"") == entry.id:
				continue
			var local: Transform3D = entry.transform.affine_inverse() * body.transform
			var extent: Vector3 = PortalRules.projected_extent(local.basis, body.half_extents)
			var speed: float = maxf(0.0, -(entry.transform.basis.inverse() * body.linear_velocity).z)
			if local.origin.z < 0.0 or local.origin.z > extent.z + 0.35 + speed * delta * 2.0 \
					or not entry.inside_opening(local.origin):
				continue
			var at_plane: Transform3D = body.transform
			at_plane.origin = entry.transform * Vector3(local.origin.x, local.origin.y, 0)
			var destination: Transform3D = PortalMath.map_transform(entry.transform, exit.transform, at_plane)
			var excluded: Array[StringName] = _group_ids(body, bodies)
			if not PortalRules.fits(entry, at_plane, body.half_extents) \
					or not _world.exit_free(body.id, destination, excluded):
				blocked = true
				# Never enable a slab inside an existing shape. First put a newly obstructed traveller
				# safely in front of it, then let Jolt enforce the closed passage.
				if local.origin.z < extent.z + PortalRules.BARRIER_HALF_DEPTH - PortalRules.CONTACT_TOLERANCE:
					if not _hold(entry, body):
						return
	_world.set_barrier(entry.id, blocked)


func step(scope_id: int, tick_id: int) -> Array[PortalTransfer]:
	var done: Array[PortalTransfer] = []
	if scope_id != _scope_id or tick_id <= _last_tick or not ready() or recovery_required:
		return done
	_last_tick = tick_id
	var pairs: Array[PortalPairState] = _world.pairs()
	if pairs.is_empty():
		return done
	var bodies: Array[PortalBodyState] = _world.bodies()
	_restore_unfinished(pairs, bodies)
	if recovery_required:
		return done
	_resolve_held_obstructions(pairs, bodies)
	if recovery_required:
		return done
	# Carriers are processed first, regardless of the adapter's collection order.
	var ordered: Array[PortalBodyState] = []
	for body: PortalBodyState in bodies:
		if body.is_player:
			ordered.append(body)
	for body: PortalBodyState in bodies:
		if not body.is_player:
			ordered.append(body)
	for body: PortalBodyState in ordered:
		if recovery_required:
			break
		var current: Vector3 = body.transform.origin
		var previous: Vector3 = _previous.get(body.id, current)
		_previous[body.id] = current
		_release_guard(body, pairs)
		if body.held:
			_track_held(body, previous, pairs)
			_held_carriers[body.id] = body.carrier_id
			continue
		var held_entry: StringName = _held_entries.get(body.id, &"")
		var former_carrier: StringName = _held_carriers.get(body.id, &"")
		for pair: PortalPairState in pairs:
			if not pair.powered:
				continue
			var from_a: Vector3 = _release_previous(pair.a, body, held_entry, previous)
			var from_b: Vector3 = _release_previous(pair.b, body, held_entry, previous)
			var outcome: PortalTransfer = _try(pair, pair.a, pair.b, body, bodies, from_a, tick_id, former_carrier)
			if outcome == null:
				outcome = _try(pair, pair.b, pair.a, body, bodies, from_b, tick_id, former_carrier)
			if outcome != null:
				done.append(outcome)
				break
		_clear_held(body.id)
	for outcome: PortalTransfer in done:
		crossing_count += 1
		if outcome.blocked:
			blocked_count += 1
		transfers.append(outcome)
		if transfers.size() > HISTORY_LIMIT:
			transfers.pop_front()
	return done


func _try(pair: PortalPairState, entry: PortalPlane, exit: PortalPlane, body: PortalBodyState,
		bodies: Array[PortalBodyState], previous: Vector3, tick: int, former_carrier: StringName = &"") -> PortalTransfer:
	if _guard.get(body.id, &"") == entry.id:
		# A deliberate reverse crossing is valid even before the whole capsule has cleared the exit.
		# Outward velocity and the swept direction still reject immediate numerical ping-pong.
		if (entry.transform.basis.inverse() * body.linear_velocity).z >= -0.05:
			return null
		_guard.erase(body.id)
	if not PortalRules.crosses(entry, previous, body.transform.origin):
		return null
	var outcome: PortalTransfer = PortalTransfer.new()
	outcome.crossing_id = _next_crossing
	_next_crossing += 1
	outcome.tick_id = tick
	outcome.body_id = body.id
	outcome.pair_id = pair.id
	outcome.entry_id = entry.id
	outcome.exit_id = exit.id
	outcome.rotation = PortalMath.transfer(entry.transform, exit.transform).basis
	var before: float = entry.local(previous).z
	var after: float = entry.local(body.transform.origin).z
	var crossing_pose: Transform3D = body.transform
	crossing_pose.origin = previous.lerp(body.transform.origin, before / (before - after))
	var destination: Transform3D = PortalMath.map_transform(entry.transform, exit.transform, body.transform)
	var start: Vector3 = PortalMath.map_point(entry.transform, exit.transform, crossing_pose.origin)
	var group: Array[StringName] = _group_ids(body, bodies)
	if not former_carrier.is_empty():
		group.append(former_carrier)
	if not PortalRules.fits(entry, crossing_pose, body.half_extents) \
			or not _world.exit_free(body.id, destination, group, start):
		outcome.blocked = true
		if _hold(entry, body):
			_world.set_barrier(entry.id, true)
		return outcome
	var companions: Array[PortalBodyState] = []
	for mate: PortalBodyState in bodies:
		if not mate.held or mate.carrier_id != body.id:
			continue
		var mapped: Transform3D = PortalMath.map_transform(entry.transform, exit.transform, mate.transform)
		var local: Vector3 = entry.local(mate.transform.origin)
		var mate_start: Vector3 = PortalMath.map_point(entry.transform, exit.transform,
			entry.transform * Vector3(local.x, local.y, 0))
		if PortalRules.fits(entry, mate.transform, mate.half_extents) \
				and _world.exit_free(mate.id, mapped, group, mate_start):
			companions.append(mate)
		else:
			_world.release(mate.id)
			mate.held = false
			outcome.detached_id = mate.id
			if not _hold(entry, mate):
				outcome.blocked = true
				return outcome
			# The pre-transfer snapshot is no longer held, but must not be independently transferred
			# later in this same tick after being deliberately left at the entry.
			_previous[mate.id] = mate.transform.origin
	_move(entry, exit, body, destination)
	for mate: PortalBodyState in companions:
		_move(entry, exit, mate, PortalMath.map_transform(entry.transform, exit.transform, mate.transform))
		outcome.companion_id = mate.id
	return outcome


func _move(entry: PortalPlane, exit: PortalPlane, body: PortalBodyState, destination: Transform3D) -> void:
	_world.teleport(body.id, destination, PortalMath.map_vector(entry.transform, exit.transform, body.linear_velocity),
		PortalMath.map_vector(entry.transform, exit.transform, body.angular_velocity))
	_guard[body.id] = exit.id
	_previous[body.id] = destination.origin
	_clear_held(body.id)
	if body.held and exit.local(destination.origin).z < 0.0:
		# Walking backwards sends the carrier first. The companion still spans the exit and its
		# visible part remains at the old entry until it follows or is released back onto that side.
		_guard.erase(body.id)
		_held_entries[body.id] = exit.id
		_held_carriers[body.id] = body.carrier_id
		_world.straddle(body.id, exit.id)
	# Other members of this tick's snapshot must see the new pose, especially the attached prop
	# which is visited after its carrier. Do not overwrite its mapped history with its old entry pose.
	body.transform = destination


func _hold(entry: PortalPlane, body: PortalBodyState) -> bool:
	var local: Transform3D = entry.transform.affine_inverse() * body.transform
	# The authored frame is 0.4 m deep. Keep even a prop beside the aperture clear of its front,
	# rather than dropping a too-wide companion halfway into the frame or behind the entry wall.
	local.origin.z = PortalRules.projected_extent(local.basis, body.half_extents).z \
		+ PortalRules.FRAME_HALF_DEPTH + PortalRules.ENTRY_CLEARANCE
	var velocity: Vector3 = entry.transform.basis.inverse() * body.linear_velocity
	velocity.z = maxf(0.0, velocity.z)
	var held_at: Transform3D = entry.transform * local
	if not _world.hold(body.id, held_at, entry.transform.basis * velocity):
		var saved: PortalRecoveryPose = _safe_poses.get(body.id)
		if saved == null or saved.entry_id != entry.id \
				or not _world.hold(body.id, saved.transform, entry.transform.basis * velocity):
			recovery_required = true
			recovery_body_id = body.id
			return false
		held_at = saved.transform
	_previous[body.id] = held_at.origin
	_clear_held(body.id)
	body.transform = held_at
	body.linear_velocity = entry.transform.basis * velocity
	return true


func _remember_safe(pairs: Array[PortalPairState], bodies: Array[PortalBodyState]) -> void:
	# Keep one current approach per body. No scene/physics handles enter this application snapshot.
	var live: Dictionary[StringName, bool] = {}
	for body: PortalBodyState in bodies:
		live[body.id] = true
		var nearest: float = INF
		for pair: PortalPairState in pairs:
			for plane: PortalPlane in [pair.a, pair.b]:
				var local: Transform3D = plane.transform.affine_inverse() * body.transform
				var extent: Vector3 = PortalRules.projected_extent(local.basis, body.half_extents)
				if not plane.inside_opening(local.origin) or local.origin.z < extent.z \
						+ PortalRules.FRAME_HALF_DEPTH + PortalRules.ENTRY_CLEARANCE:
					continue
				if local.origin.z >= nearest:
					continue
				if _world.exit_free(body.id, body.transform):
					var saved: PortalRecoveryPose = PortalRecoveryPose.new()
					saved.entry_id = plane.id
					saved.transform = body.transform
					_safe_poses[body.id] = saved
					nearest = local.origin.z
	for id: StringName in _safe_poses.keys():
		if not live.has(id):
			_safe_poses.erase(id)


func _group_ids(body: PortalBodyState, bodies: Array[PortalBodyState]) -> Array[StringName]:
	var result: Array[StringName] = [body.id]
	if not body.carrier_id.is_empty():
		result.append(body.carrier_id)
	for mate: PortalBodyState in bodies:
		if mate.held and mate.carrier_id == body.id:
			result.append(mate.id)
	return result


func _restore_unfinished(pairs: Array[PortalPairState], bodies: Array[PortalBodyState]) -> void:
	for pair: PortalPairState in pairs:
		if not pair.powered and _powered.get(pair.id, false):
			for body: PortalBodyState in bodies:
				for plane: PortalPlane in [pair.a, pair.b]:
					var local: Transform3D = plane.transform.affine_inverse() * body.transform
					var extent: Vector3 = PortalRules.projected_extent(local.basis, body.half_extents)
					if _held_entries.get(body.id, &"") == plane.id \
							or (absf(local.origin.z) <= extent.z and plane.inside_opening(local.origin)):
						if body.held:
							_world.release(body.id)
							body.held = false
						if not _hold(plane, body):
							return
						break
		_powered[pair.id] = pair.powered


func _resolve_held_obstructions(pairs: Array[PortalPairState], bodies: Array[PortalBodyState]) -> void:
	for body: PortalBodyState in bodies:
		if not body.held:
			continue
		var active: StringName = _held_entries.get(body.id, &"")
		for pair: PortalPairState in pairs:
			if not pair.powered:
				continue
			var entry: PortalPlane = pair.a if active == pair.a.id else pair.b if active == pair.b.id else null
			if entry == null:
				continue
			var exit: PortalPlane = pair.b if entry == pair.a else pair.a
			var local: Vector3 = entry.local(body.transform.origin)
			var destination: Transform3D = PortalMath.map_transform(entry.transform, exit.transform, body.transform)
			var start: Vector3 = PortalMath.map_point(entry.transform, exit.transform,
				entry.transform * Vector3(local.x, local.y, 0))
			if not _world.exit_free(body.id, destination, _group_ids(body, bodies), start):
				_world.release(body.id)
				body.held = false
				if not _hold(entry, body):
					return
				_world.set_barrier(entry.id, true)
			break


func _release_previous(plane: PortalPlane, body: PortalBodyState, held_entry: StringName, previous: Vector3) -> Vector3:
	var local: Vector3 = plane.local(body.transform.origin)
	if held_entry == plane.id and local.z < 0.0:
		return plane.transform * Vector3(local.x, local.y, 0.001)
	return previous


func _track_held(body: PortalBodyState, previous: Vector3, pairs: Array[PortalPairState]) -> void:
	var active: StringName = _held_entries.get(body.id, &"")
	for pair: PortalPairState in pairs:
		if not pair.powered:
			continue
		for plane: PortalPlane in [pair.a, pair.b]:
			if plane.id == active:
				if plane.local(body.transform.origin).z >= 0.0:
					_clear_held(body.id)
				return
			if PortalRules.crosses(plane, previous, body.transform.origin) \
					and PortalRules.fits(plane, body.transform, body.half_extents):
				_held_entries[body.id] = plane.id
				_world.straddle(body.id, plane.id)
				return


func _clear_held(id: StringName) -> void:
	if _held_entries.has(id):
		_world.straddle(id, &"")
	_held_entries.erase(id)
	_held_carriers.erase(id)


func _release_guard(body: PortalBodyState, pairs: Array[PortalPairState]) -> void:
	var guarded: StringName = _guard.get(body.id, &"")
	if guarded.is_empty():
		return
	for pair: PortalPairState in pairs:
		for plane: PortalPlane in [pair.a, pair.b]:
			if plane.id == guarded and PortalRules.guard_released(plane, body.transform.origin, body.extent):
				_guard.erase(body.id)
