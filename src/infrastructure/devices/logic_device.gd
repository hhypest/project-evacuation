class_name LogicDevice
extends PuzzleDeviceNode
## Junction box for SOURCE, AND, OR, NOT, DELAY and LATCH. The symbol is a shape label, not a colour.

@export var kind: DeviceDefinition.Kind = DeviceDefinition.Kind.AND
@export var delay_seconds: float = 1.0
@export var initial: bool = false

var _lamp: MeshInstance3D



func _ready() -> void:
	add_child(box_mesh(Vector3(0.44, 0.44, 0.16), Color(0.88, 0.86, 0.82)))
	_lamp = box_mesh(Vector3(0.08, 0.08, 0.02), DARK)
	_lamp.position = Vector3(0.14, 0.14, 0.085)
	add_child(_lamp)
	var label: Label3D = Label3D.new()
	label.text = symbol()
	label.pixel_size = 0.004
	label.font_size = 40
	label.modulate = Color(0.1, 0.1, 0.1)
	label.position = Vector3(0, -0.04, 0.085)
	add_child(label)


func symbol() -> String:
	match kind:
		DeviceDefinition.Kind.SOURCE:
			return "ИСТ"
		DeviceDefinition.Kind.AND:
			return "И"
		DeviceDefinition.Kind.OR:
			return "ИЛИ"
		DeviceDefinition.Kind.NOT:
			return "НЕ"
		DeviceDefinition.Kind.DELAY:
			return "%.1f с" % delay_seconds
		DeviceDefinition.Kind.LATCH:
			return "S/R"
		_:
			return "?"


func definition() -> DeviceDefinition:
	var result: DeviceDefinition = DeviceDefinition.make(stable_id, kind, inputs)
	result.delay_seconds = delay_seconds
	result.initial = initial
	return result


func show_output(on: bool, _delta: float) -> void:
	set_lamp(_lamp, on)
