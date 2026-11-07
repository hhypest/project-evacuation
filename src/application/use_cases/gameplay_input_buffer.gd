class_name GameplayInputBuffer
extends RefCounted
## Held state is separate from one-shot edges and accumulated mouse motion.

const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"jump", &"crouch", &"walk", &"interact",
]

var _enabled: bool = false
var _generation: int = 0
var _held: Dictionary[StringName, bool] = {}
var _blocked: Dictionary[StringName, bool] = {}
var _look_delta: Vector2 = Vector2.ZERO
var _jump_requested: bool = false
var _interact_requested: bool = false


func configure(enabled: bool, generation: int) -> void:
	if enabled == _enabled and generation == _generation:
		return
	for action: StringName in _held:
		_blocked[action] = true
	_held.clear()
	_clear_edges()
	_enabled = enabled
	_generation = generation


func release_unheld_actions(physically_held: Array[StringName]) -> void:
	# A release outside the window may never reach this application as an event.
	for action: StringName in _blocked.keys():
		if action not in physically_held:
			_blocked.erase(action)


func record_action(action: StringName, pressed: bool, repeated: bool = false) -> void:
	if action not in ACTIONS:
		return
	if not pressed:
		_held.erase(action)
		_blocked.erase(action)
		return
	if not _enabled:
		_blocked[action] = true
		return
	if repeated or _blocked.has(action) or _held.has(action):
		return
	_held[action] = true
	if action == &"jump":
		_jump_requested = true
	elif action == &"interact":
		_interact_requested = true


func record_look(delta: Vector2) -> void:
	if _enabled:
		_look_delta += delta


func take_frame() -> GameplayInputFrame:
	var frame: GameplayInputFrame = GameplayInputFrame.new()
	frame.generation = _generation
	if _enabled:
		frame.move_axis = Vector2(
			float(_held.has(&"move_right")) - float(_held.has(&"move_left")),
			float(_held.has(&"move_back")) - float(_held.has(&"move_forward"))
		).limit_length()
		frame.look_delta = _look_delta
		frame.jump_requested = _jump_requested
		frame.interact_requested = _interact_requested
		frame.crouching = _held.has(&"crouch")
		frame.walking = _held.has(&"walk")
	_clear_edges()
	return frame


func _clear_edges() -> void:
	_look_delta = Vector2.ZERO
	_jump_requested = false
	_interact_requested = false
