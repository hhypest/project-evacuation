class_name AdvancePuzzle
extends RefCounted
## Coordinator for one chamber's devices: observe → network tick → apply.
##
## Latency: a contact during physics step N is observed at puzzle tick N+1 (after the step completed)
## and actuators move from that tick onward. A wall press is applied in the same tick it is used.

var network: PuzzleNetwork
var errors: PackedStringArray = PackedStringArray()
var last_result: PuzzleStepResult
var _world: PuzzleWorldPort
var _scope_id: int = -1
var _reach: float = 2.0


func _init(world: PuzzleWorldPort, scope_id: int, reach: float, tick_rate: int = 60) -> void:
	_world = world
	_reach = reach
	var built: PuzzleBuildResult = PuzzleNetwork.build(world.definitions(), tick_rate)
	errors = built.errors
	if built.ok():
		network = built.network
		_scope_id = scope_id


func ready() -> bool:
	return network != null and _scope_id >= 0


## Uses a wall button under the view. Returns true when the interaction was consumed.
func use(scope_id: int, view: Transform3D) -> bool:
	if not ready() or scope_id != _scope_id:
		return false
	var id: StringName = _world.usable(view, _reach)
	return not id.is_empty() and _world.press(id)


func step(scope_id: int, tick_id: int) -> PuzzleStepResult:
	if not ready() or scope_id != _scope_id or tick_id <= network.last_tick:
		return null
	var observation: PuzzleObservation = _world.observe(tick_id)
	if observation == null:
		return null
	var result: PuzzleStepResult = network.step(observation)
	if result != null:
		last_result = result
		_world.apply(result)
	return result


## Clears memory, timers and pending presses, then shows the authored initial state.
func reset() -> void:
	if not ready():
		return
	_world.cancel_pending()
	network.reset()
	_publish_initial()


func restore_checkpoint_switches(states: Dictionary[StringName, bool]) -> bool:
	if not ready() or not network.restore_checkpoint_switches(states):
		return false
	_publish_initial()
	return true


func _publish_initial() -> void:
	var initial: PuzzleStepResult = PuzzleStepResult.new()
	initial.outputs = network.outputs()
	_world.apply(initial)


func suspend() -> void:
	_world.cancel_pending()


func close() -> void:
	_scope_id = -1
	_world.close()
