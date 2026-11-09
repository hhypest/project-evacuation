class_name DoorDevice
extends PuzzleDeviceNode
## Chamber door: a human frame with two sliding leaves. The network decides "should be open";
## this adapter only moves the leaves and refuses to close onto a player or a prop in the doorway.
## Art: the leaves are a Meshy model (content/models/devices/door, turned round for the right leaf); the frame is
## its exact collision boxes dressed in the project's panel, dark-metal and hazard-stripe materials (a
## generated frame never kept the passage open). Collisions are unchanged.

const LEAF_MODEL: PackedScene = preload("res://content/models/devices/door/door_leaf.gltf")
const LEAF_MODEL_SIZE: Vector3 = Vector3(1.0, 2.6, 0.15)
const FRAME_PANEL: BaseMaterial3D = preload("res://content/materials/surfaces/panel_light.tres")
const FRAME_DARK: BaseMaterial3D = preload("res://content/materials/surfaces/metal_dark.tres")
const HAZARD: BaseMaterial3D = preload("res://content/materials/surfaces/hazard_stripes.tres")

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
	var panel: BaseMaterial3D = _triplanar(FRAME_PANEL, 1.0)
	for side: float in [-1.0, 1.0]:
		var post: StaticBody3D = static_box(Vector3(0.3, opening.y + 0.4, thickness + 0.1), frame_color,
			Vector3(side * (half + 0.15), (opening.y + 0.4) * 0.5, 0))
		_dress(post, panel)
		add_child(post)
		# Dark guide rail lining the passage edge, where the leaves run.
		var rail: MeshInstance3D = box_mesh(Vector3(0.04, opening.y, thickness + 0.12), DARK)
		rail.material_override = _triplanar(FRAME_DARK, 0.5)
		rail.position = Vector3(side * (half + 0.02), opening.y * 0.5, 0)
		add_child(rail)
	var lintel: StaticBody3D = static_box(Vector3(opening.x + 0.6, 0.4, thickness + 0.1), frame_color,
		Vector3(0, opening.y + 0.2, 0))
	_dress(lintel, panel)
	add_child(lintel)
	for face: float in [-1.0, 1.0]:
		var stripe: MeshInstance3D = box_mesh(Vector3(opening.x + 0.6, 0.16, 0.01), Color(0.88, 0.42, 0.18))
		stripe.material_override = _triplanar(HAZARD, 0.5)
		stripe.position = Vector3(0, opening.y + 0.2, face * ((thickness + 0.1) * 0.5 + 0.006))
		add_child(stripe)
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


## Replaces the flat colour of a frame box with a project surface material.
func _dress(box: StaticBody3D, material: BaseMaterial3D) -> void:
	for child: Node in box.get_children():
		var visual: MeshInstance3D = child as MeshInstance3D
		if visual != null:
			visual.material_override = material


## A copy of a surface material mapped triplanar, one texture tile per `tile` metres, so it fits any box.
static func _triplanar(source: BaseMaterial3D, tile: float) -> BaseMaterial3D:
	var material: BaseMaterial3D = source.duplicate() as BaseMaterial3D
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE / tile
	return material


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
