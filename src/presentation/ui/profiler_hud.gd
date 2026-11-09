class_name ProfilerHud
extends CanvasLayer
## Development-only overlay. Not part of the game's diegetic interface; never takes mouse/focus.

signal panel_toggled(visible_now: bool)
signal record_toggled()

var panel_visible: bool = false
var _panel: PanelContainer
var _label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 16)
	margin.add_child(_label)
	_panel.add_child(margin)
	add_child(_panel)
	_panel.visible = panel_visible
	_label.text = "Профилировщик · ожидание первого замера\nF3 — скрыть · F4 — запись CSV"


func set_panel_visible(enabled: bool) -> void:
	panel_visible = enabled
	if _panel != null:
		_panel.visible = enabled
	panel_toggled.emit(enabled)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if key.physical_keycode == KEY_F3:
		set_panel_visible(not panel_visible)
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_F4:
		set_panel_visible(true)
		record_toggled.emit()
		get_viewport().set_input_as_handled()


func show_sample(sample: ProfilerSample) -> void:
	var mib: float = 1048576.0
	_label.text = "ПРОФИЛИРОВЩИК · F3 скрыть · F4 CSV %s\n" % ("■ СТОП" if sample.recording else "● СТАРТ")
	_label.text += "%s · %s · %d × %d\n" % [sample.texture_profile, sample.level.get_file(), sample.viewport_size.x, sample.viewport_size.y]
	_label.text += "FPS %.1f · кадр %.2f мс · p95 %.2f · max %.2f\n" % [sample.fps, sample.frame_mean_ms, sample.frame_p95_ms, sample.frame_max_ms]
	_label.text += "Процесс %.2f · физика %.2f мс\n" % [sample.process_ms, sample.physics_ms]
	_label.text += "Отрисовка CPU %s · GPU %s мс (%d viewport)\n" % [_timing(sample.render_cpu_ms), _timing(sample.render_gpu_ms), sample.viewport_count]
	_label.text += "Вызовы %d · примитивы %d\n" % [sample.draw_calls, sample.primitives]
	_label.text += "Текстуры %.1f MiB · видео %.1f MiB (оценка Godot)\n" % [float(sample.texture_bytes) / mib, float(sample.video_bytes) / mib]
	_label.text += "Память движка %s MiB · пауза %s · фокус %s\n" % [_timing(float(sample.static_bytes) / mib), str(sample.paused), str(sample.focused)]
	if not sample.report_path.is_empty():
		_label.text += "CSV: " + sample.report_path.get_file() + "\n"
	if not sample.error.is_empty():
		_label.text += sample.error + "\n"
	_label.text += "" if sample.gpu.is_empty() else sample.gpu


func _timing(value: float) -> String:
	return "н/д" if value < 0.0 else "%.2f" % value
