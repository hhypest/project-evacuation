class_name FoundationHud
extends CanvasLayer

signal start_requested()
signal load_checkpoint_requested()
## A chamber from the level list; index 0 is the start button itself.
signal level_requested(index: int)
signal pause_requested()
signal restart_requested()
signal menu_requested()
signal quit_requested()
signal camera_preferences_changed()

@onready var _menu: PanelContainer = %Menu
@onready var _heading: Label = %Heading
@onready var _status: Label = %Status
@onready var _load_button: Button = %LoadCheckpointButton
@onready var _start_button: Button = %StartButton
@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _menu_button: Button = %MenuButton
@onready var _quit_button: Button = %QuitButton
@onready var _game_hint: Label = %GameHint
@onready var _crosshair: Label = %Crosshair
@onready var _placement_hint: Label = %PlacementHint
@onready var _main_stack: VBoxContainer = %Stack
@onready var _settings_stack: VBoxContainer = %CameraSettings
@onready var _settings_button: Button = %CameraButton
@onready var _fov: HSlider = %Fov
@onready var _sensitivity: HSlider = %Sensitivity
@onready var _gravity_rate: HSlider = %GravityRate
@onready var _show_hint: CheckButton = %ShowHint
@onready var _settings_notice: Label = %CameraNotice

var _level_buttons: Array[Button] = []
var _last_phase: SessionLifecycle.Phase = SessionLifecycle.Phase.STOPPED
var _last_focused: bool = false
var _preferences: CameraPreferences


func _ready() -> void:
	_load_button.pressed.connect(load_checkpoint_requested.emit)
	_start_button.pressed.connect(level_requested.emit.bind(0))
	_level_buttons = [_start_button]
	_resume_button.pressed.connect(pause_requested.emit)
	_restart_button.pressed.connect(restart_requested.emit)
	_menu_button.pressed.connect(menu_requested.emit)
	_quit_button.pressed.connect(quit_requested.emit)
	_settings_button.pressed.connect(_open_camera_settings)
	(%CameraDone as Button).pressed.connect(_close_camera_settings)
	_fov.value_changed.connect(_update_camera_labels)
	_sensitivity.value_changed.connect(_update_camera_labels)
	_gravity_rate.value_changed.connect(_update_camera_labels)


func set_camera_preferences(preferences: CameraPreferences) -> void:
	_preferences = preferences
	_fov.min_value = CameraPreferences.FOV_MIN
	_fov.max_value = CameraPreferences.FOV_MAX
	_sensitivity.min_value = CameraPreferences.SENSITIVITY_MIN
	_sensitivity.max_value = CameraPreferences.SENSITIVITY_MAX
	_gravity_rate.min_value = CameraPreferences.ALIGN_MIN
	_gravity_rate.max_value = CameraPreferences.ALIGN_MAX


func _open_camera_settings() -> void:
	_fov.value = _preferences.fov
	_sensitivity.value = _preferences.sensitivity
	_gravity_rate.value = _preferences.gravity_rate
	_show_hint.button_pressed = _preferences.show_hint
	_update_camera_labels(0.0)
	_main_stack.hide()
	_settings_stack.show()
	_fov.grab_focus()


func _close_camera_settings() -> void:
	var changed: bool = _preferences.fov != _fov.value or _preferences.sensitivity != _sensitivity.value \
		or _preferences.gravity_rate != _gravity_rate.value or _preferences.show_hint != _show_hint.button_pressed
	_preferences.fov = _fov.value
	_preferences.sensitivity = _sensitivity.value
	_preferences.gravity_rate = _gravity_rate.value
	_preferences.show_hint = _show_hint.button_pressed
	_settings_stack.hide()
	_main_stack.show()
	_settings_button.grab_focus()
	_settings_notice.hide()
	if changed:
		camera_preferences_changed.emit()


func _update_camera_labels(_value: float) -> void:
	(%FovLabel as Label).text = "Вертикальное поле зрения · %.0f°" % _fov.value
	(%SensitivityLabel as Label).text = "Чувствительность мыши · %.0f%%" % _sensitivity.value
	var seconds: float = 90.0 / maxf(_gravity_rate.value, CameraPreferences.ALIGN_MIN)
	(%GravityRateLabel as Label).text = "Поворот на 90° при смене гравитации · %.2f с" % seconds


func show_preferences_notice(message: String) -> void:
	_settings_notice.text = message
	_settings_notice.show()


func show_carry_feedback(holding: bool, can_place: bool) -> void:
	_placement_hint.visible = holding and can_place and _crosshair.visible


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


func show_session(status: SessionStatus, runtime_label: String, problem: String, has_checkpoint: bool,
		restart_label: String) -> void:
	var in_menu: bool = status.phase == SessionLifecycle.Phase.READY
	var paused: bool = status.phase == SessionLifecycle.Phase.PAUSED
	_menu.visible = in_menu or paused
	_game_hint.visible = status.accepts_gameplay and _preferences.show_hint
	_crosshair.visible = status.accepts_gameplay
	if not status.accepts_gameplay:
		_placement_hint.hide()
	_heading.text = "Главное меню" if in_menu else "Пауза"
	_status.text = runtime_label
	if not status.focused:
		_status.text += "\nСделайте окно активным. Сессия не продолжится автоматически."
	if not problem.is_empty():
		_status.text += "\n" + problem
	for button: Button in _level_buttons:
		button.visible = in_menu
		button.disabled = not status.can_start
	_load_button.visible = in_menu and has_checkpoint
	_load_button.disabled = not status.can_start
	_resume_button.visible = paused
	_resume_button.disabled = not status.can_resume
	_restart_button.visible = paused
	_restart_button.disabled = not status.can_restart
	_restart_button.text = restart_label
	_menu_button.visible = paused
	if status.phase != _last_phase or (status.focused and not _last_focused):
		if status.accepts_gameplay:
			_settings_stack.hide()
			_main_stack.show()
			get_viewport().gui_release_focus()
		elif _settings_stack.visible:
			_fov.grab_focus()
		elif in_menu and status.can_start:
			if has_checkpoint:
				_load_button.grab_focus()
			else:
				_start_button.grab_focus()
		elif paused and status.can_resume:
			_resume_button.grab_focus()
	_last_phase = status.phase
	_last_focused = status.focused


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if _settings_stack.visible:
			_close_camera_settings()
		else:
			pause_requested.emit()
		get_viewport().set_input_as_handled()
	elif not _settings_stack.visible and event.is_action_pressed(&"restart_test"):
		restart_requested.emit()
		get_viewport().set_input_as_handled()
