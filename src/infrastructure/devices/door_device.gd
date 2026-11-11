class_name DoorDevice
extends PuzzleDeviceNode
## Chamber door: a human frame with two sliding leaves. The network decides "should be open";
## this adapter only moves the leaves and refuses to close onto a player or a prop in the doorway.
## DEV-12/13 art: a modular Meshy frame with a repaired open aperture and two sliding leaves.
## Primitive collision boxes and the obstruction rule remain independent of the decorative models.

const LEAF_MODEL: PackedScene = preload("res://content/models/devices/door/door_leaf.gltf")
const LEAF_MODEL_SIZE: Vector3 = Vector3(1.0, 2.6, 0.15)
const FRAME_MODEL: PackedScene = preload("res://content/models/devices/door_frame/door_frame.gltf")

@export var opening: Vector2 = Vector2(2.0, 2.6)
@export var thickness: float = 0.3
@export var speed: float = 2.0

## 0 = closed, 1 = fully open. Physical state, not a puzzle signal.
var openness: float = 0.0
var blocked: bool = false
var _leaves: Array[AnimatableBody3D] = []
var _doorway: Area3D
var _lamp: MeshInstance3D


func _ready() -> void:
	var half: float = opening.x * 0.5
	var frame_color: Color = Color(0.88, 0.86, 0.82)
	for side: float in [-1.0, 1.0]:
		var post: StaticBody3D = static_box(Vector3(0.3, opening.y + 0.4, thickness + 0.1), frame_color,
			Vector3(side * (half + 0.15), (opening.y + 0.4) * 0.5, 0))
		_hide_box_visual(post)
		add_child(post)
	var lintel: StaticBody3D = static_box(Vector3(opening.x + 0.6, 0.4, thickness + 0.1), frame_color,
		Vector3(0, opening.y + 0.2, 0))
	_hide_box_visual(lintel)
	add_child(lintel)
	var frame: Node3D = FRAME_MODEL.instantiate() as Node3D
	frame.name = "FrameModel"
	frame.scale.z = (thickness + 0.1) / 0.4
	for side: float in [-1.0, 1.0]:
		var post: Node3D = frame.get_node("LeftPost" if side < 0 else "RightPost") as Node3D
		post.position.x = side * (half + 0.15)
		post.scale.y = opening.y / 2.6
	var top: Node3D = frame.get_node("Lintel") as Node3D
	top.position.y = opening.y
	top.scale.x = (opening.x + 0.6) / 2.6
	add_child(frame)
	_lamp = box_mesh(Vector3(0.12, 0.12, 0.02), DARK)
	_lamp.position = Vector3(half + 0.15, opening.y + 0.2, thickness * 0.5 + 0.06)
	add_child(_lamp)
	for side: float in [-1.0, 1.0]:
		var leaf: AnimatableBody3D = AnimatableBody3D.new()
		leaf.name = "Leaf%s" % ("L" if side < 0.0 else "R")
		leaf.collision_layer = 1
		leaf.collision_mask = 0
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(half, opening.y, thickness * 0.5)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		leaf.add_child(collision)
		var model: Node3D = LEAF_MODEL.instantiate() as Node3D
		model.name = "Model"
		# The model's pull is on its +X edge: as is for the left leaf, turned half round for the right one, so
		# both pulls face the meeting edge (a mirrored copy would flip its normal map and shade darker).
		model.scale = shape.size / LEAF_MODEL_SIZE
		if side > 0.0:
			model.rotation.y = PI
		leaf.add_child(model)
		leaf.position = _leaf_position(side, 0.0)
		add_child(leaf)
		_leaves.append(leaf)
	_doorway = Area3D.new()
	_doorway.name = "Doorway"
	_doorway.collision_layer = 0
	_doorway.collision_mask = 6
	_doorway.monitorable = false
	var volume: BoxShape3D = BoxShape3D.new()
	volume.size = Vector3(opening.x - 0.05, opening.y - 0.05, thickness + 0.5)
	var area_shape: CollisionShape3D = CollisionShape3D.new()
	area_shape.shape = volume
	area_shape.position.y = opening.y * 0.5
	_doorway.add_child(area_shape)
	add_child(_doorway)


## Keep the exact primitive collision but render the new modular frame instead of its old box visual.
func _hide_box_visual(box: StaticBody3D) -> void:
	for child: Node in box.get_children():
		var visual: MeshInstance3D = child as MeshInstance3D
		if visual != null:
			visual.visible = false


func definition() -> DeviceDefinition:
	return DeviceDefinition.make(stable_id, DeviceDefinition.Kind.DOOR, inputs)


func show_output(on: bool, delta: float) -> void:
	set_lamp(_lamp, on)
	var target: float = 1.0 if on else 0.0
	blocked = target < openness and _doorway.has_overlapping_bodies()
	if blocked:
		target = 1.0
	openness = move_toward(openness, target, speed * delta / maxf(0.1, opening.x * 0.5))
	for index: int in range(_leaves.size()):
		_leaves[index].position = _leaf_position(-1.0 if index == 0 else 1.0, openness)


func is_open() -> bool:
	return openness >= 0.999


func _leaf_position(side: float, amount: float) -> Vector3:
	var half: float = opening.x * 0.5
	return Vector3(side * (half * 0.5 + half * amount), opening.y * 0.5, 0)
