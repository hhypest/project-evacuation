class_name FoundationHud
extends CanvasLayer

signal start_requested()
## A chamber from the level list; index 0 is the start button itself.
signal level_requested(index: int)
signal pause_requested()
signal restart_requested()
signal menu_requested()
signal quit_requested()

@onready var _menu: PanelContainer = %Menu
@onready var _heading: Label = %Heading
@onready var _status: Label = %Status
@onready var _start_button: Button = %StartButton
@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton
@onready var _quit_button: Button = %QuitButton
@onready var _game_hint: Label = %GameHint
@onready var _crosshair: Label = %Crosshair

var _level_buttons: Array[Button] = []
var _last_phase: SessionLifecycle.Phase = SessionLifecycle.Phase.STOPPED
var _last_focused: bool = false


func _ready() -> void:
	_start_button.pressed.connect(level_requested.emit.bind(0))
	_level_buttons = [_start_button]
	_resume_button.pressed.connect(pause_requested.emit)
	_restart_button.pressed.connect(restart_requested.emit)
	_menu_button.pressed.connect(menu_requested.emit)
	_quit_button.pressed.connect(quit_requested.emit)


## Builds one menu button per chamber; the first title relabels the start button.
func set_levels(titles: PackedStringArray) -> void:
	for index: int in range(1, _level_buttons.size()):
		_level_buttons[index].queue_free()
	_level_buttons = [_start_button]
	if titles.is_empty():
		return
	_start_button.text = titles[0]
	var anchor: int = _start_button.get_index()
	for index: int in range(1, titles.size()):
		var button: Button = Button.new()
		button.name = "LevelButton%d" % index
		button.text = titles[index]
		button.custom_minimum_size = _start_button.custom_minimum_size
		button.pressed.connect(level_requested.emit.bind(index))
		_start_button.get_parent().add_child(button)
		_start_button.get_parent().move_child(button, anchor + index)
		_level_buttons.append(button)


func show_session(status: SessionStatus, runtime_label: String, problem: String) -> void:
	var in_menu: bool = status.phase == SessionLifecycle.Phase.READY
	var paused: bool = status.phase == SessionLifecycle.Phase.PAUSED
	_menu.visible = in_menu or paused
	_game_hint.visible = status.accepts_gameplay
	_crosshair.visible = status.accepts_gameplay
	_heading.text = "Главное меню" if in_menu else "Пауза"
	_status.text = runtime_label
	if not status.focused:
		_status.text += "\nСделайте окно активным. Сессия не продолжится автоматически."
	if not problem.is_empty():
		_status.text += "\n" + problem
	for button: Button in _level_buttons:
		button.visible = in_menu
		button.disabled = not status.can_start
	_resume_button.visible = paused
	_resume_button.disabled = not status.can_resume
	_restart_button.visible = paused
	_restart_button.disabled = not status.can_restart
	_menu_button.visible = paused
	if status.phase != _last_phase or (status.focused and not _last_focused):
		if status.accepts_gameplay:
			get_viewport().gui_release_focus()
		elif in_menu and status.can_start:
			_start_button.grab_focus()
		elif paused and status.can_resume:
			_resume_button.grab_focus()
	_last_phase = status.phase
	_last_focused = status.focused


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"restart_test"):
		restart_requested.emit()
		get_viewport().set_input_as_handled()
