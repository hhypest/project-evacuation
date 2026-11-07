class_name TestInputEvents
extends RefCounted
## Exercises engine delivery, including the physical InputMap bindings.


static func key(code: Key, pressed: bool = true, repeated: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = repeated
	Input.parse_input_event(event)
	Input.flush_buffered_events()


static func motion(delta: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.relative = delta
	event.screen_relative = delta
	Input.parse_input_event(event)
	Input.flush_buffered_events()
