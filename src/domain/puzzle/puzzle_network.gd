class_name PuzzleNetwork
extends RefCounted
## PuzzleAggregate for one chamber: the only owner of device signals and discrete device memory.
##
## Tick phases (Architecture §7):
## 1. sensors take the observation of the last completed physics step;
## 2. memory elements (DELAY, LATCH) publish their stored value;
## 3. combinational devices are evaluated once in a fixed topological order;
## 4. memory elements store the next value from their current inputs.
## The order is sorted by ID, so the authoring order of definitions never changes a result.

const MAX_DELAY_SECONDS: float = 60.0
const MAX_HOLD_SECONDS: float = 600.0

var tick_rate: int = 60
var last_tick: int = -1
var _devices: Dictionary[StringName, DeviceDefinition] = {}
var _sensors: Array[StringName] = []
var _memories: Array[StringName] = []
var _combinational: Array[StringName] = []
var _memory: Dictionary[StringName, DeviceMemory] = {}


static func build(definitions: Array[DeviceDefinition], rate: int = 60) -> PuzzleBuildResult:
	var result: PuzzleBuildResult = PuzzleBuildResult.new()
	if rate <= 0 or rate > 1000:
		result.errors.append("tick rate must be in 1..1000, got %d" % rate)
		return result
	var devices: Dictionary[StringName, DeviceDefinition] = {}
	for definition: DeviceDefinition in definitions:
		if definition == null:
			result.errors.append("null device definition")
			continue
		if definition.id.is_empty():
			result.errors.append("device with empty ID")
			continue
		if devices.has(definition.id):
			result.errors.append("duplicate device ID '%s'" % definition.id)
			continue
		devices[definition.id] = definition.duplicate_definition()
	for id: StringName in _sorted(devices.keys()):
		_validate(devices[id], devices, rate, result.errors)
	if not result.errors.is_empty():
		return result
	var order: Array[StringName] = _topological_order(devices, result.errors)
	if not result.errors.is_empty():
		return result
	var network: PuzzleNetwork = PuzzleNetwork.new()
	network.tick_rate = rate
	network._devices = devices
	for id: StringName in _sorted(devices.keys()):
		var definition: DeviceDefinition = devices[id]
		if definition.is_sensor():
			network._sensors.append(id)
		elif definition.is_memory():
			network._memories.append(id)
	network._combinational = order
	network.reset()
	result.network = network
	return result


## Restores the authored initial state: every timer, latch, delay line and debounce counter.
func reset() -> void:
	last_tick = -1
	_memory.clear()
	for id: StringName in _devices.keys():
		var definition: DeviceDefinition = _devices[id]
		var memory: DeviceMemory = DeviceMemory.new()
		if definition.kind == DeviceDefinition.Kind.SOURCE:
			memory.output = definition.initial
		elif definition.kind == DeviceDefinition.Kind.LATCH:
			memory.latch = definition.initial
			memory.output = definition.initial
		elif definition.kind == DeviceDefinition.Kind.DELAY:
			for index: int in range(delay_ticks(definition)):
				memory.history.append(false)
		_memory[id] = memory
	# Settle combinational outputs so the very first observation sees a consistent network.
	for id: StringName in _combinational:
		_memory[id].output = _evaluate(_devices[id])


func has_device(id: StringName) -> bool:
	return _devices.has(id)


func device(id: StringName) -> DeviceDefinition:
	var definition: DeviceDefinition = _devices.get(id)
	return definition.duplicate_definition() if definition != null else null


func device_ids() -> Array[StringName]:
	return _sorted(_devices.keys())


func output(id: StringName) -> bool:
	var memory: DeviceMemory = _memory.get(id)
	return memory != null and memory.output


func delay_ticks(definition: DeviceDefinition) -> int:
	return maxi(1, roundi(definition.delay_seconds * float(tick_rate)))


func hold_ticks(definition: DeviceDefinition) -> int:
	return maxi(1, roundi(definition.hold_seconds * float(tick_rate)))


## Advances exactly one logical tick. A stale or repeated tick ID is rejected with null.
func step(observation: PuzzleObservation) -> PuzzleStepResult:
	if observation == null or observation.tick_id <= last_tick:
		return null
	last_tick = observation.tick_id
	var before: Dictionary[StringName, bool] = outputs()
	var pressed: Dictionary[StringName, bool] = {}
	for id: StringName in observation.presses:
		pressed[id] = true
	for id: StringName in _sensors:
		_sense(_devices[id], _memory[id], observation, pressed.has(id))
	for id: StringName in _memories:
		var memory: DeviceMemory = _memory[id]
		memory.output = memory.history[0] if _devices[id].kind == DeviceDefinition.Kind.DELAY else memory.latch
	for id: StringName in _combinational:
		_memory[id].output = _evaluate(_devices[id])
	for id: StringName in _memories:
		_store(_devices[id], _memory[id])
	var result: PuzzleStepResult = PuzzleStepResult.new()
	result.tick_id = observation.tick_id
	result.outputs = outputs()
	for id: StringName in device_ids():
		if result.outputs[id] != before[id]:
			result.changed.append(id)
	return result


func outputs() -> Dictionary[StringName, bool]:
	var values: Dictionary[StringName, bool] = {}
	for id: StringName in device_ids():
		values[id] = _memory[id].output
	return values


func snapshot() -> Dictionary[StringName, DeviceMemory]:
	var copy: Dictionary[StringName, DeviceMemory] = {}
	for id: StringName in device_ids():
		copy[id] = _memory[id].copy()
	return copy


## Accepts only a complete snapshot of this network; partial or foreign state is rejected unchanged.
func restore(saved: Dictionary[StringName, DeviceMemory], tick: int = -1) -> bool:
	if saved.size() != _devices.size():
		return false
	for id: StringName in _devices.keys():
		var memory: DeviceMemory = saved.get(id)
		if memory == null:
			return false
		var definition: DeviceDefinition = _devices[id]
		if definition.kind == DeviceDefinition.Kind.DELAY and memory.history.size() != delay_ticks(definition):
			return false
		if memory.timer_ticks < 0 or memory.settle_count < 0:
			return false
	for id: StringName in _devices.keys():
		_memory[id] = saved[id].copy()
	last_tick = tick
	return true


func _sense(definition: DeviceDefinition, memory: DeviceMemory, observation: PuzzleObservation, pressed: bool) -> void:
	match definition.kind:
		DeviceDefinition.Kind.SOURCE:
			memory.output = definition.initial
		DeviceDefinition.Kind.FLOOR_BUTTON:
			var supported: float = observation.loads.get(definition.id, 0.0)
			if not is_finite(supported) or supported < 0.0:
				supported = 0.0
			var wants: bool = supported >= (definition.release_threshold if memory.output else definition.press_threshold)
			_debounce(definition, memory, wants)
		DeviceDefinition.Kind.RECEIVER:
			var hit: bool = observation.beam_hits.get(definition.id, false)
			_debounce(definition, memory, hit)
		DeviceDefinition.Kind.WALL_BUTTON:
			if definition.wall_mode == DeviceDefinition.WallMode.TOGGLE:
				if pressed:
					memory.output = not memory.output
			else:
				if pressed:
					memory.timer_ticks = hold_ticks(definition)
				memory.output = memory.timer_ticks > 0
				memory.timer_ticks = maxi(0, memory.timer_ticks - 1)


func _debounce(definition: DeviceDefinition, memory: DeviceMemory, wants: bool) -> void:
	if wants == memory.output:
		memory.settle_count = 0
		return
	memory.settle_count += 1
	if memory.settle_count >= definition.settle_ticks:
		memory.output = wants
		memory.settle_count = 0


func _evaluate(definition: DeviceDefinition) -> bool:
	match definition.kind:
		DeviceDefinition.Kind.AND:
			for source_id: StringName in definition.inputs:
				if not _memory[source_id].output:
					return false
			return true
		DeviceDefinition.Kind.OR:
			for source_id: StringName in definition.inputs:
				if _memory[source_id].output:
					return true
			return false
		DeviceDefinition.Kind.NOT:
			return not _memory[definition.inputs[0]].output
		_:
			# Consumers (door, emitter, field, portal pair) follow their single power/signal input.
			return _memory[definition.inputs[0]].output


func _store(definition: DeviceDefinition, memory: DeviceMemory) -> void:
	if definition.kind == DeviceDefinition.Kind.DELAY:
		memory.history.pop_front()
		memory.history.append(_memory[definition.inputs[0]].output)
	else:
		var set_signal: bool = _memory[definition.inputs[0]].output
		var reset_signal: bool = _memory[definition.inputs[1]].output
		# Reset wins: a stuck "set" never prevents a safe clear.
		if reset_signal:
			memory.latch = false
		elif set_signal:
			memory.latch = true


static func _validate(definition: DeviceDefinition, devices: Dictionary[StringName, DeviceDefinition], rate: int,
		errors: PackedStringArray) -> void:
	var id: StringName = definition.id
	var count: int = definition.inputs.size()
	var arity: Vector2i = input_range(definition.kind)
	if count < arity.x or count > arity.y:
		errors.append("device '%s' (%s) needs %d..%d inputs, got %d" % [
			id, DeviceDefinition.Kind.keys()[definition.kind], arity.x, arity.y, count])
	var seen: Dictionary[StringName, bool] = {}
	for source_id: StringName in definition.inputs:
		if source_id == id:
			errors.append("device '%s' drives itself" % id)
		elif not devices.has(source_id):
			errors.append("device '%s' references unknown source '%s'" % [id, source_id])
		elif seen.has(source_id) and definition.kind != DeviceDefinition.Kind.LATCH:
			errors.append("device '%s' lists source '%s' twice" % [id, source_id])
		elif not _drives_signal(devices[source_id]):
			errors.append("device '%s' cannot use consumer '%s' as a signal source" % [id, source_id])
		seen[source_id] = true
	if definition.kind == DeviceDefinition.Kind.FLOOR_BUTTON:
		if not is_finite(definition.press_threshold) or not is_finite(definition.release_threshold) \
				or definition.release_threshold < 0.0 or definition.press_threshold <= definition.release_threshold:
			errors.append("floor button '%s' needs finite 0 <= release < press thresholds" % id)
	if definition.kind in [DeviceDefinition.Kind.FLOOR_BUTTON, DeviceDefinition.Kind.RECEIVER] \
			and (definition.settle_ticks < 1 or definition.settle_ticks > rate):
		errors.append("sensor '%s' settle ticks must be in 1..%d" % [id, rate])
	if definition.kind == DeviceDefinition.Kind.WALL_BUTTON and definition.wall_mode == DeviceDefinition.WallMode.TIMED \
			and (not is_finite(definition.hold_seconds) or definition.hold_seconds <= 0.0 or definition.hold_seconds > MAX_HOLD_SECONDS):
		errors.append("wall button '%s' hold must be in (0, %.0f] s" % [id, MAX_HOLD_SECONDS])
	if definition.kind == DeviceDefinition.Kind.DELAY \
			and (not is_finite(definition.delay_seconds) or definition.delay_seconds <= 0.0 or definition.delay_seconds > MAX_DELAY_SECONDS):
		errors.append("delay '%s' must be in (0, %.0f] s" % [id, MAX_DELAY_SECONDS])


## Allowed input count (min, max) for a device kind.
static func input_range(kind: DeviceDefinition.Kind) -> Vector2i:
	match kind:
		DeviceDefinition.Kind.SOURCE, DeviceDefinition.Kind.FLOOR_BUTTON, DeviceDefinition.Kind.WALL_BUTTON, \
				DeviceDefinition.Kind.RECEIVER:
			return Vector2i(0, 0)
		DeviceDefinition.Kind.AND, DeviceDefinition.Kind.OR:
			return Vector2i(2, 8)
		DeviceDefinition.Kind.LATCH:
			return Vector2i(2, 2)
		_:
			return Vector2i(1, 1)


## Consumers produce an output for presentation, but they are not signal sources for other devices.
static func _drives_signal(definition: DeviceDefinition) -> bool:
	return definition.kind not in [DeviceDefinition.Kind.DOOR, DeviceDefinition.Kind.EMITTER,
		DeviceDefinition.Kind.GRAVITY_FIELD, DeviceDefinition.Kind.PORTAL_PAIR]


## Kahn's algorithm over combinational devices. Sensors and memory elements are already known at
## evaluation time, so a loop through DELAY/LATCH is legal; any other loop is an instant feedback error.
static func _topological_order(devices: Dictionary[StringName, DeviceDefinition], errors: PackedStringArray) -> Array[StringName]:
	var pending: Dictionary[StringName, int] = {}
	var dependants: Dictionary[StringName, Array] = {}
	for id: StringName in devices.keys():
		var definition: DeviceDefinition = devices[id]
		if definition.is_sensor() or definition.is_memory():
			continue
		var count: int = 0
		for source_id: StringName in definition.inputs:
			var source: DeviceDefinition = devices[source_id]
			if source.is_sensor() or source.is_memory():
				continue
			count += 1
			if not dependants.has(source_id):
				dependants[source_id] = []
			dependants[source_id].append(id)
		pending[id] = count
	var available: Array[StringName] = []
	for id: StringName in pending.keys():
		if pending[id] == 0:
			available.append(id)
	var order: Array[StringName] = []
	while not available.is_empty():
		available = _sorted(available)
		var next: StringName = available.pop_front()
		order.append(next)
		for dependant: Variant in dependants.get(next, []):
			var dependant_id: StringName = StringName(str(dependant))
			pending[dependant_id] -= 1
			if pending[dependant_id] == 0:
				available.append(dependant_id)
	if order.size() != pending.size():
		var looped: Array[StringName] = []
		for id: StringName in pending.keys():
			if id not in order:
				looped.append(id)
		errors.append("instant feedback loop without DELAY or LATCH: %s" % ", ".join(PackedStringArray(_sorted(looped))))
	return order


static func _sorted(ids: Array) -> Array[StringName]:
	var names: PackedStringArray = PackedStringArray()
	for id: Variant in ids:
		names.append(str(id))
	names.sort()
	var result: Array[StringName] = []
	for item: String in names:
		result.append(StringName(item))
	return result
