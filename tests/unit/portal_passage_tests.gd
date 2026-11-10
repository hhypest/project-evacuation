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

	func hold(id: StringName, pose: Transform3D, linear: Vector3) -> void:
		for state: PortalBodyState in states:
			if state.id == id:
				state.transform = pose
				state.linear_velocity = linear


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
