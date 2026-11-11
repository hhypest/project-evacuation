class_name WallButtonDevice
extends PuzzleDeviceNode
## Protected wall button used by the player. TIMED keeps the signal for hold_seconds; TOGGLE flips it.
## The two modes look different on purpose (ADR-0006: devices differ by silhouette): TIMED is a push button
## under a safety cover, TOGGLE is a manual lever switch. Art: content/models/devices/wall_button and
## wall_switch; the collision stays the 0.36 x 0.5 x 0.16 m box either way.

@export var mode: DeviceDefinition.WallMode = DeviceDefinition.WallMode.TIMED
@export var hold_seconds: float = 4.0
## Short marking under the key; empty shows the mode (seconds or ⟳).
@export var caption: String = ""

const BUTTON_BODY: PackedScene = preload("res://content/models/devices/wall_button/wall_button_body.gltf")
const SWITCH_BODY: PackedScene = preload("res://content/models/devices/wall_switch/wall_switch_body.gltf")
## Key and handle are separate nodes inside their housing scene, with pivots baked by the normaliser.
const KEY_TRAVEL: float = 0.015
const BUTTON_LAMP_AT: Vector3 = Vector3(0, 0.162, 0.084)
## The DEV-04 handle turns about its horizontal hinge (X), away from the housing when switched on.
const LEVER_OFF: float = 0.0
const LEVER_ON: float = -0.4
const SWITCH_LAMP_AT: Vector3 = Vector3(0.105, 0.0, 0.063)

var body: StaticBody3D
var _key: Node3D
var _lever: Node3D
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
	add_child(body)
	var toggle: bool = mode == DeviceDefinition.WallMode.TOGGLE
	var housing: Node3D = (SWITCH_BODY if toggle else BUTTON_BODY).instantiate() as Node3D
	housing.name = "Housing"
	add_child(housing)
	if toggle:
		_lever = housing.get_node("Lever") as Node3D
		_lever.rotation.x = LEVER_OFF
		_lamp = box_mesh(Vector3(0.012, 0.025, 0.004), DARK)
		_lamp.position = SWITCH_LAMP_AT
	else:
		_key = housing.get_node("Key") as Node3D
		_lamp = box_mesh(Vector3(0.028, 0.008, 0.004), DARK)
		_lamp.position = BUTTON_LAMP_AT
	_lamp.name = "Lamp"
	add_child(_lamp)
	var label: Label3D = Label3D.new()
	label.text = caption if not caption.is_empty() else ("⟳" if toggle else "%.0f с" % hold_seconds)
	label.modulate = Color(0.1, 0.1, 0.1)
	label.pixel_size = 0.0008
	label.font_size = 48
	label.outline_size = 0
	label.position = Vector3(0, -0.177, 0.042) if toggle else Vector3(0, -0.147, 0.083)
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
	if _key != null:
		_key.position.z = -KEY_TRAVEL if on else 0.0
	if _lever != null:
		_lever.rotation.x = LEVER_ON if on else LEVER_OFF
