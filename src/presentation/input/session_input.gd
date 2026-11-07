class_name SessionInput
extends Node
## Engine boundary. Gameplay consumers use typed frames, not global polling.

var _buffer: GameplayInputBuffer = GameplayInputBuffer.new()
var _enabled: bool = false
var _generation: int = 0
var _skip_mouse_motion: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_gameplay_enabled(enabled: bool, generation: int) -> void:
	if enabled == _enabled and generation == _generation:
		return
	_enabled = false
	_buffer.configure(false, generation)
	var physically_held: Array[StringName] = _physically_held_actions()
	for action: StringName in physically_held:
		_buffer.record_action(action, true)
	for action: StringName in GameplayInputBuffer.ACTIONS:
		Input.action_release(action)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE
	Input.action_release(&"pause")
	Input.action_release(&"restart_test")
	_buffer.release_unheld_actions(physically_held)
	_buffer.configure(enabled, generation)
	_generation = generation
	_enabled = enabled
	_skip_mouse_motion = enabled


func take_frame() -> GameplayInputFrame:
	return _buffer.take_frame()


func shutdown() -> void:
	set_gameplay_enabled(false, -1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if _enabled:
			if _skip_mouse_motion:
				_skip_mouse_motion = false
			else:
				_buffer.record_look(motion.screen_relative)
			get_viewport().set_input_as_handled()
		return
	for action: StringName in GameplayInputBuffer.ACTIONS:
		if event.is_action(action):
			_buffer.record_action(action, event.is_pressed(), event.is_echo())
			if not _enabled:
				Input.action_release(action)
			else:
				get_viewport().set_input_as_handled()


func _physically_held_actions() -> Array[StringName]:
	var held: Array[StringName] = []
	for action: StringName in GameplayInputBuffer.ACTIONS:
		for binding: InputEvent in InputMap.action_get_events(action):
			if binding is InputEventKey:
				var key: InputEventKey = binding as InputEventKey
				var pressed: bool = Input.is_physical_key_pressed(key.physical_keycode)
				if key.physical_keycode == KEY_NONE:
					pressed = Input.is_key_pressed(key.keycode)
				if pressed:
					held.append(action)
					break
			elif binding is InputEventMouseButton:
				var mouse: InputEventMouseButton = binding as InputEventMouseButton
				if Input.is_mouse_button_pressed(mouse.button_index):
					held.append(action)
					break
	return held
