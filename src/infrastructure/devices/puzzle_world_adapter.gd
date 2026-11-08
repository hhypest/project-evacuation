class_name PuzzleWorldAdapter
extends PuzzleWorldPort
## Godot side of a chamber's devices: registry by stable ID, load, press and beam observation, actuators.

## Game beams stop at world geometry/doors, props (cubes) and the player.
const BEAM_MASK: int = 1 | 2 | 4

var _devices: Dictionary[StringName, PuzzleDeviceNode] = {}
var _player: PlayerMotor
var _player_mass: float = 80.0
var _pending: Array[StringName] = []
var _open: bool = true


func configure(level: Node, player: PlayerMotor, player_mass: float) -> bool:
	_player = player
	_player_mass = player_mass
	return _register(level)


func _register(node: Node) -> bool:
	if node is PuzzleDeviceNode:
		var device: PuzzleDeviceNode = node as PuzzleDeviceNode
		if device.stable_id.is_empty() or _devices.has(device.stable_id):
			push_error("Puzzle device with empty or duplicate ID: '%s' at %s" % [device.stable_id, device.get_path()])
			return false
		_devices[device.stable_id] = device
	for child: Node in node.get_children():
		if not _register(child):
			return false
	return true


func device(id: StringName) -> PuzzleDeviceNode:
	var node: PuzzleDeviceNode = _devices.get(id)
	return node if _open else null


func definitions() -> Array[DeviceDefinition]:
	var result: Array[DeviceDefinition] = []
	for id: StringName in _devices.keys():
		var definition: DeviceDefinition = _devices[id].definition()
		if definition != null:
			result.append(definition)
	return result


func observe(tick_id: int) -> PuzzleObservation:
	if not _open:
		return null
	var observation: PuzzleObservation = PuzzleObservation.new()
	observation.tick_id = tick_id
	for id: StringName in _devices.keys():
		var plate: FloorButtonDevice = _devices[id] as FloorButtonDevice
		if plate != null and is_instance_valid(plate) and plate.is_inside_tree():
			observation.loads[id] = plate.measure(_player, _player_mass)
	observation.presses = _pending.duplicate()
	_pending.clear()
	# Beams are traced with the emitter power shown on the previous tick, which is also the state the
	# network reads while sensing: emitter -> receiver feedback always passes through one physics tick.
	for id: StringName in _devices.keys():
		var emitter: EmitterDevice = _devices[id] as EmitterDevice
		if emitter != null and is_instance_valid(emitter) and emitter.is_inside_tree() and emitter.powered:
			var hit: BeamHit = _trace(emitter)
			if hit != null:
				observation.beams.append(hit)
	return observation


func apply(result: PuzzleStepResult) -> void:
	if not _open:
		return
	var delta: float = 1.0 / float(Engine.physics_ticks_per_second)
	for id: StringName in _devices.keys():
		var node: PuzzleDeviceNode = _devices[id]
		if is_instance_valid(node) and node.is_inside_tree():
			var emitter: EmitterDevice = node as EmitterDevice
			var was_powered: bool = emitter != null and emitter.powered
			node.show_output(result.output(id), delta)
			if emitter != null and emitter.powered and not was_powered:
				# Visual only: show the correct length on the tick power arrives.
				_trace(emitter)


## Casts the game beam of one emitter, updates its visible length and reports a receiver hit, if any.
func _trace(emitter: EmitterDevice) -> BeamHit:
	if _player == null or emitter.body == null:
		return null
	var from: Vector3 = emitter.muzzle()
	var forward: Vector3 = emitter.direction()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + forward * emitter.range_m, BEAM_MASK, [emitter.body.get_rid()])
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	var point: Variant = hit.get("position")
	var collider: Variant = hit.get("collider")
	if point is not Vector3 or collider is not Object:
		emitter.show_beam(emitter.range_m)
		return null
	# Raw engine query result; both types were checked before crossing the typed boundary.
	@warning_ignore("unsafe_cast")
	var end: Vector3 = point as Vector3
	@warning_ignore("unsafe_cast")
	var target: Object = collider as Object
	emitter.show_beam(from.distance_to(end))
	for id: StringName in _devices.keys():
		var receiver: ReceiverDevice = _devices[id] as ReceiverDevice
		if receiver != null and receiver.owns(target):
			return BeamHit.make(emitter.stable_id, id, receiver.front().dot(-forward))
	return null


func usable(view: Transform3D, reach: float) -> StringName:
	if not _open or _player == null:
		return &""
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		view.origin, view.origin - view.basis.z * reach, 3, [_player.get_rid()])
	var hit: Dictionary = _player.get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Variant = hit.get("collider")
	if collider is not Object:
		return &""
	# Raw engine query result; the Object type was checked before crossing the typed boundary.
	@warning_ignore("unsafe_cast")
	var target: Object = collider as Object
	for id: StringName in _devices.keys():
		var button: WallButtonDevice = _devices[id] as WallButtonDevice
		if button != null and button.owns(target):
			return id
	return &""


func press(id: StringName) -> bool:
	if not _open or _devices.get(id) is not WallButtonDevice or id in _pending:
		return false
	_pending.append(id)
	return true


func cancel_pending() -> void:
	_pending.clear()


func close() -> void:
	_open = false
	_pending.clear()
	_devices.clear()
