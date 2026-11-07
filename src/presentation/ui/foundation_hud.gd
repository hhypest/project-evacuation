class_name FoundationHud
extends CanvasLayer

signal pause_requested()
signal restart_requested()
signal quit_requested()

@onready var _status: Label = %Status
@onready var _pause_button: Button = %PauseButton
@onready var _restart_button: Button = %RestartButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	_pause_button.pressed.connect(pause_requested.emit)
	_restart_button.pressed.connect(restart_requested.emit)
	_quit_button.pressed.connect(quit_requested.emit)


func show_status(text: String, paused: bool, valid: bool) -> void:
	_status.text = text
	_pause_button.text = "Продолжить [Esc]" if paused else "Пауза [Esc]"
	_pause_button.disabled = not valid
	_restart_button.disabled = not valid


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"restart_test"):
		restart_requested.emit()
		get_viewport().set_input_as_handled()
