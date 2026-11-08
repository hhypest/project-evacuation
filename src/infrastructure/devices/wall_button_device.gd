class_name WallButtonDevice
extends PuzzleDeviceNode
## Protected wall button used by the player. TIMED keeps the signal for hold_seconds; TOGGLE flips it.

@export var mode: DeviceDefinition.WallMode = DeviceDefinition.WallMode.TIMED
@export var hold_seconds: float = 4.0
## Short marking under the key; empty shows the mode (seconds or ⟳).
@export var caption: String = ""

var body: StaticBody3D
var _key: MeshInstance3D
var _lamp: MeshInstance3D


func _ready() -> void:
	body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 6
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(0.36, 0.5, 0.16)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.add_child(box_mesh(shape.size, Color(0.88, 0.86, 0.82)))
	add_child(body)
	var hood: MeshInstance3D = box_mesh(Vector3(0.42, 0.05, 0.26), Color(0.88, 0.42, 0.18))
	hood.position = Vector3(0, 0.28, 0.05)
	add_child(hood)
	_key = box_mesh(Vector3(0.18, 0.18, 0.06), Color(0.11, 0.12, 0.13))
	_key.position = Vector3(0, -0.05, 0.1)
	add_child(_key)
	_lamp = box_mesh(Vector3(0.07, 0.07, 0.02), DARK)
	_lamp.position = Vector3(0, 0.16, 0.085)
	add_child(_lamp)
	var label: Label3D = Label3D.new()
	label.text = caption if not caption.is_empty() else ("⟳" if mode == DeviceDefinition.WallMode.TOGGLE else "%.0f с" % hold_seconds)
	label.modulate = Color(0.1, 0.1, 0.1)
	label.pixel_size = 0.004
	label.font_size = 48
	label.position = Vector3(0, -0.2, 0.085)
	add_child(label)


func definition() -> DeviceDefinition:
	var result: DeviceDefinition = DeviceDefinition.make(stable_id, DeviceDefinition.Kind.WALL_BUTTON)
	result.wall_mode = mode
	result.hold_seconds = hold_seconds
	return result


func owns(collider: Object) -> bool:
	return collider == body


func show_output(on: bool, _delta: float) -> void:
	set_lamp(_lamp, on)
	_key.position.z = 0.08 if on else 0.1
