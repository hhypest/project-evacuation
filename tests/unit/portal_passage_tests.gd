class_name PortalPassageTests
extends TestSuite

class World:
	extends PortalWorldPort
	var pair: PortalPairState = PortalPairState.new()
	var states: Array[PortalBodyState] = []
	var refused: StringName = &""
	var moved: Array[StringName] = []
	var dropped: Array[StringName] = []
	var barriers: Dictionary[StringName, bool] = {}
	var excluded: Array[StringName] = []
	var straddles: Dictionary[StringName, StringName] = {}
	var reject_recovery: bool = false

	func _init() -> void:
		pair.id = &"pair"
		pair.a = PortalPlane.make(&"a", Transform3D.IDENTITY, Vector2(0.8, 1.2))
		pair.b = PortalPlane.make(&"b", Transform3D(Basis.IDENTITY, Vector3(10, 0, 0)), Vector2(0.8, 1.2))
		pair.powered = true

	func pairs() -> Array[PortalPairState]:
		return [pair]

	func bodies() -> Array[PortalBodyState]:
		return states

	func exit_free(id: StringName, _pose: Transform3D, exclude_ids: Array[StringName] = [],
			_from: Vector3 = Vector3.INF) -> bool:
		excluded = exclude_ids
		return id != refused

	func set_barrier(id: StringName, blocked: bool) -> void:
		barriers[id] = blocked

	func straddle(id: StringName, plane_id: StringName) -> void:
		straddles[id] = plane_id

	func release(id: StringName) -> void:
		dropped.append(id)
		for state: PortalBodyState in states:
			if state.id == id:
				state.held = false

	func teleport(id: StringName, pose: Transform3D, linear: Vector3, angular: Vector3) -> void:
		moved.append(id)
		for state: PortalBodyState in states:
			if state.id == id:
				state.transform = pose
				state.linear_velocity = linear
				state.angular_velocity = angular

	func hold(id: StringName, pose: Transform3D, linear: Vector3, _former_carrier: StringName = &"",
			_waypoint: Vector3 = Vector3.INF) -> bool:
		if reject_recovery:
			return false
		for state: PortalBodyState in states:
			if state.id == id:
				state.transform = pose
				state.linear_velocity = linear
		return true


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var world: World = _world()
	var use_case: AdvancePortals = AdvancePortals.new(world, 7)
	use_case.step(7, 1)
	var player: PortalBodyState = world.states[1]
	var cube: PortalBodyState = world.states[0]
	player.transform.origin.z = -0.1
	cube.transform.origin.z = -1.0
	var done: Array[PortalTransfer] = use_case.step(7, 2)
	results.append(TestOutcome.new("carrier and held prop cross once as one group despite reverse snapshot order",
		done.size() == 1 and done[0].companion_id == cube.id and world.moved == [&"player", &"cube"]
		and world.pair.b.local(player.transform.origin).z > 0.0 and world.pair.b.local(cube.transform.origin).z > 0.0,
		str(world.moved)))
	results.append(TestOutcome.new("exit query excludes both group members and mapped history survives the prop visit",
		world.excluded.has(&"player") and world.excluded.has(&"cube") and use_case.step(7, 3).is_empty()
		and world.moved.size() == 2))
	results.append(TestOutcome.new("duplicate and stale scope ticks cannot repeat a grouped transfer",
		use_case.step(7, 2).is_empty() and use_case.step(8, 100).is_empty() and world.moved.size() == 2))
	world = _world()
	world.refused = &"cube"
	use_case = AdvancePortals.new(world, 7)
	use_case.step(7, 1)
	world.states[1].transform.origin.z = -0.1
	var refused: Array[PortalTransfer] = use_case.step(7, 2)
	results.append(TestOutcome.new("blocked companion is dropped safely in front of the entry; carrier may pass alone",
		refused.size() == 1 and refused[0].detached_id == &"cube" and world.dropped == [&"cube"]
		and world.moved == [&"player"] and world.states[0].transform.origin.z > 0.5 and not world.states[0].held))
	world = _world()
	world.refused = &"player"
	use_case = AdvancePortals.new(world, 7)
	use_case.prepare(7, 1.0 / 60.0)
	results.append(TestOutcome.new("occupied exit enables a physical entry barrier before movement",
		world.barriers[&"a"] and world.moved.is_empty() and world.states[1].transform.origin.z >= 0.3))
	world.refused = &""
	use_case.prepare(7, 1.0 / 60.0)
	results.append(TestOutcome.new("entry barrier clears automatically when the exit becomes free",
		not world.barriers[&"a"]))
	world = _world()
	world.states = [world.states[0]]
	cube = world.states[0]
	cube.held = false
	cube.carrier_id = &""
	cube.transform.origin = Vector3(0, 0, 0.2)
	use_case = AdvancePortals.new(world, 7)
	use_case.step(7, 1)
	world.pair.powered = false
	use_case.step(7, 2)
	results.append(TestOutcome.new("power loss during a straddle restores the body to its current side",
		cube.transform.origin.z > cube.half_extents.z and world.moved.is_empty()))
	use_case.reset()
	cube.transform.origin.z = -0.2
	world.pair.powered = true
	results.append(TestOutcome.new("reset discards swept history rather than teleporting from an old sample",
		use_case.step(7, 3).is_empty() and world.moved.is_empty()))
	world = _world()
	world.states[1].transform.origin.z = 1.4
	world.states[0].transform.origin.z = 0.2
	use_case = AdvancePortals.new(world, 7)
	use_case.step(7, 1)
	world.states[0].transform.origin.z = -0.7
	use_case.step(7, 2)
	world.states[0].held = false
	use_case.step(7, 3)
	results.append(TestOutcome.new("releasing a cube already held through the entry materialises it at the exit",
		world.moved == [&"cube"] and world.pair.b.local(world.states[0].transform.origin).z > 0.5
		and world.states[1].transform.origin.z > 1.0))
	world = _world()
	world.states[1].transform.origin.z = 1.4
	world.states[0].transform.origin.z = 0.2
	use_case = AdvancePortals.new(world, 7)
	use_case.step(7, 1)
	world.states[0].transform.origin.z = -0.7
	use_case.step(7, 2)
	world.pair.powered = false
	use_case.step(7, 3)
	results.append(TestOutcome.new("power loss also returns a fully inserted held cube before its carrier crosses",
		world.dropped == [&"cube"] and world.states[0].transform.origin.z > 0.5 and world.moved.is_empty()))
	world = _world()
	world.states[1].transform.origin.z = 1.4
	world.states[0].transform.origin.z = 0.2
	use_case = AdvancePortals.new(world, 7)
	use_case.step(7, 1)
	world.states[0].transform.origin.z = -0.7
	use_case.step(7, 2)
	world.refused = &"cube"
	use_case.step(7, 3)
	results.append(TestOutcome.new("an obstruction appearing inside the remote held pose safely drops it at the entry",
		world.dropped == [&"cube"] and world.states[0].transform.origin.z > 0.5 and not world.states[0].held))
	for oversized: bool in [false, true]:
		world = _world()
		cube = world.states[0]
		cube.transform.origin.z = 0.1
		if oversized:
			cube.half_extents.x = 1.0
		else:
			world.refused = cube.id
		use_case = AdvancePortals.new(world, 7)
		use_case.step(7, 1)
		use_case.prepare(7, 1.0 / 60.0)
		var passage_open: bool = not world.barriers[&"a"]
		# A real motor cannot reach the crossing if prepare closed the slab first.
		if passage_open:
			world.states[1].transform.origin.z = -0.1
		var alone: Array[PortalTransfer] = use_case.step(7, 2)
		results.append(TestOutcome.new("prepare allows a clear carrier past a refused companion (oversized=%s)" % oversized,
			passage_open and alone.size() == 1 and alone[0].detached_id == cube.id
			and world.moved == [&"player"] and not cube.held and cube.transform.origin.z > 0.5))
	world = _world()
	cube = world.states[0]
	cube.transform.origin.z = 1.0
	use_case = AdvancePortals.new(world, 7)
	use_case.step(7, 1)
	world.states[1].transform.origin.z = -0.1
	use_case.step(7, 2)
	var straddled: StringName = world.straddles.get(cube.id, &"")
	results.append(TestOutcome.new("a companion behind its carrier keeps the exit straddle for its remote visual",
		straddled == &"b" and world.pair.b.local(cube.transform.origin).z < -0.5))
	cube.held = false
	cube.carrier_id = &""
	use_case.step(7, 3)
	straddled = world.straddles.get(cube.id, &"")
	results.append(TestOutcome.new("releasing a companion still behind the exit materialises it on the original side",
		world.moved == [&"player", &"cube", &"cube"] and world.pair.a.local(cube.transform.origin).z > 0.5
		and straddled == &""))
	world = _world()
	world.refused = &"player"
	world.reject_recovery = true
	use_case = AdvancePortals.new(world, 7)
	var original: Transform3D = world.states[1].transform
	use_case.prepare(7, 1.0 / 60.0)
	results.append(TestOutcome.new("a refused recovery leaves body and aperture unchanged and requests a chamber reset",
		use_case.recovery_required and use_case.recovery_body_id == &"player"
		and world.states[1].transform == original and world.barriers.is_empty()))
	results.append(TestOutcome.new("an unrecoverable portal scope cannot process further crossing commands",
		use_case.step(7, 1).is_empty() and world.moved.is_empty()))
	world = World.new()
	player = PortalBodyState.new()
	player.id = &"traveller"
	player.half_extents = Vector3(0.3, 0.9, 0.3)
	world.states = [player]
	use_case = AdvancePortals.new(world, 7)
	for index: int in range(10000):
		var entry: PortalPlane = world.pair.a if index % 2 == 0 else world.pair.b
		player.linear_velocity = entry.transform.basis * Vector3(0, 0, -4)
		player.transform = entry.transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.2))
		use_case.step(7, index * 2 + 1)
		player.transform.origin = entry.transform * Vector3(0, 0, -0.1)
		use_case.step(7, index * 2 + 2)
	var latest: PortalTransfer = use_case.transfers.back()
	results.append(TestOutcome.new("ten thousand crossings keep bounded diagnostics and monotonic crossing IDs",
		use_case.crossing_count == 10000 and use_case.blocked_count == 0
		and use_case.transfers.size() == AdvancePortals.HISTORY_LIMIT and latest.crossing_id == 10000))
	use_case.reset()
	results.append(TestOutcome.new("explicit reset clears bounded portal diagnostics and recovery state",
		use_case.transfers.is_empty() and use_case.crossing_count == 0 and not use_case.recovery_required))
	return results


func _world() -> World:
	var world: World = World.new()
	var player: PortalBodyState = PortalBodyState.new()
	player.id = &"player"
	player.is_player = true
	player.half_extents = Vector3(0.3, 0.9, 0.3)
	player.transform.origin = Vector3(0, 0, 0.1)
	player.linear_velocity = Vector3(0, 0, -4)
	var cube: PortalBodyState = PortalBodyState.new()
	cube.id = &"cube"
	cube.transform.origin = Vector3(0, -0.4, -0.8)
	cube.held = true
	cube.carrier_id = player.id
	world.states = [cube, player]
	return world
