class_name PuzzleNetworkTests
extends TestSuite

var _tick: int = 0


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	results.append_array(_validation())
	results.append_array(_floor_button())
	results.append_array(_wall_button())
	results.append_array(_logic())
	results.append_array(_memory())
	results.append_array(_determinism())
	results.append_array(_beams())
	return results


func _validation() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var duplicate: PuzzleBuildResult = PuzzleNetwork.build([_d(&"a", DeviceDefinition.Kind.SOURCE), _d(&"a", DeviceDefinition.Kind.SOURCE)])
	results.append(TestOutcome.new("validator rejects duplicate device IDs", not duplicate.ok() and _has(duplicate, "duplicate")))
	var unknown: PuzzleBuildResult = PuzzleNetwork.build([_d(&"door", DeviceDefinition.Kind.DOOR, [&"ghost"])])
	results.append(TestOutcome.new("validator rejects unknown input IDs", not unknown.ok() and _has(unknown, "unknown source")))
	var arity: PuzzleBuildResult = PuzzleNetwork.build([_d(&"s", DeviceDefinition.Kind.SOURCE), _d(&"and", DeviceDefinition.Kind.AND, [&"s"])])
	results.append(TestOutcome.new("validator rejects wrong input count", not arity.ok() and _has(arity, "needs 2..8")))
	var consumer: PuzzleBuildResult = PuzzleNetwork.build([
		_d(&"s", DeviceDefinition.Kind.SOURCE), _d(&"door", DeviceDefinition.Kind.DOOR, [&"s"]),
		_d(&"door2", DeviceDefinition.Kind.DOOR, [&"door"])])
	results.append(TestOutcome.new("validator rejects a consumer used as a signal source", not consumer.ok() and _has(consumer, "signal source")))
	var plate: DeviceDefinition = _d(&"plate", DeviceDefinition.Kind.FLOOR_BUTTON)
	plate.press_threshold = 3.0
	plate.release_threshold = 3.0
	var thresholds: PuzzleBuildResult = PuzzleNetwork.build([plate])
	results.append(TestOutcome.new("validator requires release threshold below press threshold", not thresholds.ok()))
	var delay: DeviceDefinition = _d(&"delay", DeviceDefinition.Kind.DELAY, [&"s"])
	delay.delay_seconds = INF
	var bad_delay: PuzzleBuildResult = PuzzleNetwork.build([_d(&"s", DeviceDefinition.Kind.SOURCE), delay])
	results.append(TestOutcome.new("validator rejects non-finite delays", not bad_delay.ok() and _has(bad_delay, "delay")))
	var loop: PuzzleBuildResult = PuzzleNetwork.build([
		_d(&"s", DeviceDefinition.Kind.SOURCE), _d(&"a", DeviceDefinition.Kind.OR, [&"s", &"b"]),
		_d(&"b", DeviceDefinition.Kind.NOT, [&"a"])])
	results.append(TestOutcome.new("validator rejects instant combinational feedback", not loop.ok() and _has(loop, "instant feedback loop")))
	var latched: PuzzleBuildResult = PuzzleNetwork.build([
		_d(&"s", DeviceDefinition.Kind.SOURCE), _d(&"a", DeviceDefinition.Kind.OR, [&"s", &"m"]),
		_d(&"m", DeviceDefinition.Kind.DELAY, [&"a"])])
	results.append(TestOutcome.new("a loop through an explicit DELAY is accepted", latched.ok(), ", ".join(latched.errors)))
	return results


func _floor_button() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var plate: DeviceDefinition = _d(&"plate", DeviceDefinition.Kind.FLOOR_BUTTON)
	plate.press_threshold = 8.0
	plate.release_threshold = 6.0
	plate.settle_ticks = 3
	var network: PuzzleNetwork = _net([plate, _d(&"door", DeviceDefinition.Kind.DOOR, [&"plate"])])
	var light: bool = _run(network, 5, {&"plate": 5.0}).output(&"door")
	var settled: Array[bool] = []
	for index: int in range(3):
		settled.append(_run(network, 1, {&"plate": 10.0}).output(&"door"))
	results.append(TestOutcome.new("floor button presses only after the load settles at the threshold",
		not light and settled == [false, false, true], str(settled)))
	var hysteresis: bool = _run(network, 10, {&"plate": 7.0}).output(&"door")
	var released: bool = _run(network, 10, {&"plate": 5.0}).output(&"door")
	results.append(TestOutcome.new("hysteresis keeps a pressed plate between release and press thresholds",
		hysteresis and not released))
	_run(network, 10, {&"plate": 10.0})
	var spike: bool = _run(network, 2, {&"plate": 0.0}).output(&"door")
	results.append(TestOutcome.new("a two-tick contact gap does not release a three-tick debounced plate", spike))
	var invalid: bool = _run(network, 10, {&"plate": NAN}).output(&"door")
	results.append(TestOutcome.new("non-finite load is treated as no load", not invalid))
	return results


func _wall_button() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var timed: DeviceDefinition = _d(&"timed", DeviceDefinition.Kind.WALL_BUTTON)
	timed.hold_seconds = 0.5
	var toggle: DeviceDefinition = _d(&"toggle", DeviceDefinition.Kind.WALL_BUTTON)
	toggle.wall_mode = DeviceDefinition.WallMode.TOGGLE
	var network: PuzzleNetwork = _net([timed, toggle])
	var first: PuzzleStepResult = _press(network, [&"timed", &"timed", &"toggle"])
	var held: bool = _run(network, 28, {}).output(&"timed")
	var expired: bool = _run(network, 2, {}).output(&"timed")
	results.append(TestOutcome.new("timed wall button holds for its duration and then releases",
		first.output(&"timed") and held and not expired))
	_press(network, [&"timed"])
	_run(network, 20, {})
	_press(network, [&"timed"])
	var restarted: bool = _run(network, 25, {}).output(&"timed")
	results.append(TestOutcome.new("pressing a running timed button restarts the hold", restarted))
	var on: bool = first.output(&"toggle")
	var off: bool = _press(network, [&"toggle"]).output(&"toggle")
	results.append(TestOutcome.new("toggle wall button flips once per press and ignores duplicate events", on and not off))
	return results


func _logic() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var table: Array[String] = []
	for a: bool in [false, true]:
		for b: bool in [false, true]:
			var network: PuzzleNetwork = _net([_src(&"a", a), _src(&"b", b),
				_d(&"and", DeviceDefinition.Kind.AND, [&"a", &"b"]), _d(&"or", DeviceDefinition.Kind.OR, [&"a", &"b"]),
				_d(&"not", DeviceDefinition.Kind.NOT, [&"a"])])
			var step: PuzzleStepResult = _run(network, 1, {})
			table.append("%d%d:%d%d%d" % [int(a), int(b), int(step.output(&"and")), int(step.output(&"or")), int(step.output(&"not"))])
	results.append(TestOutcome.new("AND/OR/NOT truth tables", table == ["00:001", "01:011", "10:010", "11:110"], str(table)))
	var chained: PuzzleNetwork = _net([_src(&"s", true), _d(&"n1", DeviceDefinition.Kind.NOT, [&"s"]),
		_d(&"n2", DeviceDefinition.Kind.NOT, [&"n1"]), _d(&"door", DeviceDefinition.Kind.DOOR, [&"n2"])])
	results.append(TestOutcome.new("a combinational chain settles within one tick", _run(chained, 1, {}).output(&"door")))
	return results


func _memory() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var timed: DeviceDefinition = _d(&"press", DeviceDefinition.Kind.WALL_BUTTON)
	timed.hold_seconds = 1.0 / 60.0
	var delay: DeviceDefinition = _d(&"delay", DeviceDefinition.Kind.DELAY, [&"press"])
	delay.delay_seconds = 0.1
	var network: PuzzleNetwork = _net([timed, delay])
	var trace: Array[int] = []
	_press(network, [&"press"])
	for index: int in range(8):
		trace.append(int(_run(network, 1, {}).output(&"delay")))
	results.append(TestOutcome.new("delay reproduces the input after exactly its tick count", trace == [0, 0, 0, 0, 0, 1, 0, 0], str(trace)))
	var set_button: DeviceDefinition = _d(&"set", DeviceDefinition.Kind.WALL_BUTTON)
	set_button.hold_seconds = 1.0 / 60.0
	var reset_button: DeviceDefinition = _d(&"reset", DeviceDefinition.Kind.WALL_BUTTON)
	reset_button.hold_seconds = 1.0 / 60.0
	var latch: PuzzleNetwork = _net([set_button, reset_button, _d(&"latch", DeviceDefinition.Kind.LATCH, [&"set", &"reset"])])
	_press(latch, [&"set"])
	var stored: bool = _run(latch, 10, {}).output(&"latch")
	_press(latch, [&"set", &"reset"])
	var cleared: bool = _run(latch, 2, {}).output(&"latch")
	results.append(TestOutcome.new("latch remembers set until reset; reset wins over set", stored and not cleared))
	_press(latch, [&"set"])
	_run(latch, 3, {})
	var saved: Dictionary[StringName, DeviceMemory] = latch.snapshot()
	_press(latch, [&"reset"])
	_run(latch, 3, {})
	var restored: bool = latch.restore(saved, _tick) and latch.output(&"latch")
	var partial: Dictionary[StringName, DeviceMemory] = latch.snapshot()
	partial.erase(&"set")
	results.append(TestOutcome.new("snapshot restore returns latch memory; partial snapshots are rejected",
		restored and not latch.restore(partial)))
	latch.reset()
	results.append(TestOutcome.new("reset returns every memory element to its authored state", not latch.output(&"latch")))
	return results


func _determinism() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var forward: Array[DeviceDefinition] = _sample()
	var reversed: Array[DeviceDefinition] = _sample()
	reversed.reverse()
	var a: PuzzleNetwork = _net(forward)
	var b: PuzzleNetwork = _net(reversed)
	var same: bool = true
	for index: int in range(40):
		var loads: Dictionary[StringName, float] = {&"plate": 10.0 if index % 9 < 5 else 0.0}
		var presses: Array[StringName] = []
		if index % 7 == 0:
			presses.append(&"button")
		var left: PuzzleStepResult = _step(a, loads, presses)
		var right: PuzzleStepResult = _step(b, loads, presses)
		same = same and left.outputs == right.outputs and left.changed == right.changed
	results.append(TestOutcome.new("definition order does not change outputs or change order", same))
	var stale: PuzzleObservation = PuzzleObservation.new()
	stale.tick_id = a.last_tick
	results.append(TestOutcome.new("a repeated tick ID is rejected", a.step(stale) == null))
	return results


func _beams() -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var receiver: DeviceDefinition = _d(&"rx", DeviceDefinition.Kind.RECEIVER)
	receiver.settle_ticks = 2
	var other: DeviceDefinition = _d(&"em1", DeviceDefinition.Kind.EMITTER, [&"on"])
	other.channel = 1
	var definitions: Array[DeviceDefinition] = [_src(&"on", true), _src(&"off", false),
		_d(&"em", DeviceDefinition.Kind.EMITTER, [&"on"]), _d(&"dark", DeviceDefinition.Kind.EMITTER, [&"off"]), other,
		receiver, _d(&"door", DeviceDefinition.Kind.DOOR, [&"rx"])]
	var network: PuzzleNetwork = _net(definitions)
	var head_on: Array[BeamHit] = [BeamHit.make(&"em", &"rx", 1.0)]
	var first: bool = _beam(network, 1, head_on).output(&"rx")
	var settled: bool = _beam(network, 1, head_on).output(&"door")
	results.append(TestOutcome.new("a head-on beam from a powered emitter switches the receiver after its settle ticks",
		not first and settled))
	var flicker: bool = _beam(network, 1, []).output(&"rx")
	var lost: bool = _beam(network, 2, []).output(&"rx")
	results.append(TestOutcome.new("a one-tick occlusion is debounced; a sustained one releases the receiver", flicker and not lost))
	var cases: Dictionary[String, BeamHit] = {
		"60 degrees off a 30 degree cone": BeamHit.make(&"em", &"rx", 0.5),
		"from behind": BeamHit.make(&"em", &"rx", -1.0),
		"non-finite incidence": BeamHit.make(&"em", &"rx", NAN),
		"an unpowered emitter": BeamHit.make(&"dark", &"rx", 1.0),
		"another channel": BeamHit.make(&"em1", &"rx", 1.0),
		"a non-emitter source": BeamHit.make(&"on", &"rx", 1.0),
		"an unknown emitter": BeamHit.make(&"ghost", &"rx", 1.0),
		"a hit addressed to another device": BeamHit.make(&"em", &"door", 1.0)}
	var accepted: Array[String] = []
	for label: String in cases.keys():
		var probe: PuzzleNetwork = _net(definitions)
		if _beam(probe, 5, [cases[label]]).output(&"rx"):
			accepted.append(label)
	results.append(TestOutcome.new("receiver rejects beams outside its rules", accepted.is_empty(), ", ".join(accepted)))
	var inside: PuzzleNetwork = _net(definitions)
	results.append(TestOutcome.new("a beam inside the acceptance cone is accepted",
		_beam(inside, 2, [BeamHit.make(&"em", &"rx", cos(deg_to_rad(25.0)))]).output(&"rx")))
	var channel: DeviceDefinition = _d(&"bad", DeviceDefinition.Kind.EMITTER, [&"on"])
	channel.channel = -1
	var cone: DeviceDefinition = _d(&"wide", DeviceDefinition.Kind.RECEIVER)
	cone.acceptance_degrees = 120.0
	var bad: PuzzleBuildResult = PuzzleNetwork.build([_src(&"on", true), channel, cone])
	results.append(TestOutcome.new("validator rejects negative channels and acceptance outside (0, 90]",
		_has(bad, "channel >= 0") and _has(bad, "acceptance"), ", ".join(bad.errors)))
	var optical: PuzzleBuildResult = PuzzleNetwork.build([_d(&"rx", DeviceDefinition.Kind.RECEIVER),
		_d(&"inv", DeviceDefinition.Kind.NOT, [&"rx"]), _d(&"em", DeviceDefinition.Kind.EMITTER, [&"inv"])])
	results.append(TestOutcome.new("an emitter driven by its own receiver is legal: the beam passes a physics tick",
		optical.ok(), ", ".join(optical.errors)))
	return results


func _beam(network: PuzzleNetwork, ticks: int, hits: Array[BeamHit]) -> PuzzleStepResult:
	var last: PuzzleStepResult
	for index: int in range(ticks):
		_tick += 1
		var observation: PuzzleObservation = PuzzleObservation.new()
		observation.tick_id = _tick
		observation.beams = hits
		last = network.step(observation)
	return last


func _sample() -> Array[DeviceDefinition]:
	var plate: DeviceDefinition = _d(&"plate", DeviceDefinition.Kind.FLOOR_BUTTON)
	return [plate, _d(&"button", DeviceDefinition.Kind.WALL_BUTTON),
		_d(&"or", DeviceDefinition.Kind.OR, [&"plate", &"latch"]), _d(&"not", DeviceDefinition.Kind.NOT, [&"or"]),
		_d(&"latch", DeviceDefinition.Kind.LATCH, [&"button", &"not"]), _d(&"door", DeviceDefinition.Kind.DOOR, [&"or"])]


func _d(id: StringName, kind: DeviceDefinition.Kind, inputs: Array[StringName] = []) -> DeviceDefinition:
	return DeviceDefinition.make(id, kind, inputs)


func _src(id: StringName, value: bool) -> DeviceDefinition:
	var source: DeviceDefinition = _d(id, DeviceDefinition.Kind.SOURCE)
	source.initial = value
	return source


func _net(definitions: Array[DeviceDefinition]) -> PuzzleNetwork:
	var built: PuzzleBuildResult = PuzzleNetwork.build(definitions)
	if not built.ok():
		push_error("test network failed: " + ", ".join(built.errors))
	return built.network


func _step(network: PuzzleNetwork, loads: Dictionary[StringName, float], presses: Array[StringName]) -> PuzzleStepResult:
	_tick += 1
	var observation: PuzzleObservation = PuzzleObservation.new()
	observation.tick_id = _tick
	observation.loads = loads
	observation.presses = presses
	return network.step(observation)


func _run(network: PuzzleNetwork, ticks: int, loads: Dictionary[StringName, float]) -> PuzzleStepResult:
	var last: PuzzleStepResult
	for index: int in range(ticks):
		last = _step(network, loads, [])
	return last


func _press(network: PuzzleNetwork, ids: Array[StringName]) -> PuzzleStepResult:
	return _step(network, {}, ids)


func _has(result: PuzzleBuildResult, text: String) -> bool:
	for error: String in result.errors:
		if error.contains(text):
			return true
	return false
