class_name CheckpointTerminal
extends StaticBody3D
## The selector uses the same world collision layers as wall buttons. Local +Z is the front.

const HOUSING: Material = preload("res://content/materials/surfaces/metal027_powder.tres")
const FACEPLATE: Material = preload("res://content/materials/surfaces/plastic010_faceplate.tres")

@export var checkpoint: ChamberCheckpoint
@export var spawn: Marker3D
@export var blocked_message: String = "ВКЛЮЧИТЕ РЕЗЕРВ"
var prop_supports: Dictionary[StringName, CarrySocketBody] = {}
var _status: Label3D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 6
	var size: Vector3 = Vector3(0.72, 0.84, 0.22)
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
	var housing: MeshInstance3D = MeshInstance3D.new()
	housing.mesh = MetricBoxMesh.make(size, Vector3.ZERO, 1.0)
	housing.material_override = HOUSING
	add_child(housing)
	var panel: MeshInstance3D = MeshInstance3D.new()
	panel.mesh = MetricBoxMesh.make(Vector3(0.64, 0.76, 0.028), Vector3.ZERO, 0.5)
	panel.material_override = FACEPLATE
	panel.position.z = 0.12
	add_child(panel)
	var display: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(0.59, 0.36, 0.014), Color(0.045, 0.065, 0.065))
	display.position = Vector3(0, -0.09, 0.139)
	add_child(display)
	var heading: Label3D = _label("КОНТРОЛЬНАЯ\nТОЧКА", Vector3(0, 0.20, 0.15))
	heading.name = "Heading"
	heading.modulate = Color(0.12, 0.13, 0.14)
	_status = _label("", Vector3(0, -0.09, 0.15))
	_status.name = "Status"
	report("E · СОХРАНИТЬ")
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = Vector3(0, 0.43, 0.48)
	lamp.light_color = Color(0.86, 0.90, 0.94)
	lamp.light_energy = 0.45
	lamp.omni_range = 2.4
	add_child(lamp)


func report(message: String) -> void:
	_status.text = message


## Resolve every authored support before moving any cube. The new scope owns the bodies.
func restore_props(level: Node3D) -> bool:
	var props: Dictionary[StringName, CarryRigidBody] = {}
	for child: Node in level.get_children():
		var prop: CarryRigidBody = child as CarryRigidBody
		if prop != null and prop_supports.has(prop.stable_id):
			props[prop.stable_id] = prop
	if props.size() != prop_supports.size() or prop_supports.values().has(null):
		return false
	for id: StringName in props:
		var prop: CarryRigidBody = props[id]
		var shape: BoxShape3D = prop.carry_shape() as BoxShape3D
		var support: CarrySocketBody = prop_supports[id]
		var origin: Vector3 = support.top_center(Vector3.UP) + Vector3.UP * (shape.size.y * 0.5 + 0.005)
		prop.portal_place(Transform3D(Basis.IDENTITY, origin), Vector3.ZERO, Vector3.ZERO)
	return true


func _label(text: String, at: Vector3) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 40
	label.pixel_size = 0.0011
	label.outline_size = 0
	add_child(label)
	return label
