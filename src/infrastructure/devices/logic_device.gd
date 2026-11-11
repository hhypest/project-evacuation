class_name LogicDevice
extends PuzzleDeviceNode
## Junction box for SOURCE, AND, OR, NOT, DELAY and LATCH. The symbol is a shape label, not a colour.
## Art: one housing for every kind (content/models/devices/logic_box); the kind is the marking on a light
## plate in the lid recess. Logic boxes have no collision.

const MODEL: PackedScene = preload("res://content/models/devices/logic_box/logic_box.gltf")
## Mounting planes ahead of the imported lid, keeping the type plate and lamp visible.
const PANEL_Z: float = 0.082
const FRAME_Z: float = 0.082

@export var kind: DeviceDefinition.Kind = DeviceDefinition.Kind.AND
@export var delay_seconds: float = 1.0
@export var initial: bool = false

var _lamp: MeshInstance3D


func _ready() -> void:
	var model: Node3D = MODEL.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	var plate: MeshInstance3D = box_mesh(Vector3(0.18, 0.10, 0.004), Color(0.91, 0.89, 0.86))
	plate.name = "TypePlate"
	plate.position = Vector3(0, -0.005, PANEL_Z + 0.002)
	add_child(plate)
	_lamp = box_mesh(Vector3(0.04, 0.04, 0.006), DARK)
	_lamp.name = "Lamp"
	_lamp.position = Vector3(0.105, 0.10, FRAME_Z + 0.003)
	add_child(_lamp)
	var label: Label3D = Label3D.new()
	label.name = "TypeLabel"
	label.text = symbol()
	label.pixel_size = 0.0012
	label.font_size = 40
	label.outline_size = 0
	label.modulate = Color(0.1, 0.1, 0.1)
	label.position = Vector3(0, -0.005, PANEL_Z + 0.005)
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
