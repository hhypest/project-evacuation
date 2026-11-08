class_name DoorDevice
extends PuzzleDeviceNode
## Chamber door: a human frame with two sliding leaves. The network decides "should be open";
## this adapter only moves the leaves and refuses to close onto a player or a prop in the doorway.

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
		add_child(static_box(Vector3(0.3, opening.y + 0.4, thickness + 0.1), frame_color,
			Vector3(side * (half + 0.15), (opening.y + 0.4) * 0.5, 0)))
	add_child(static_box(Vector3(opening.x + 0.6, 0.4, thickness + 0.1), frame_color, Vector3(0, opening.y + 0.2, 0)))
	var stripe: MeshInstance3D = box_mesh(Vector3(opening.x + 0.6, 0.06, 0.02), Color(0.88, 0.42, 0.18))
	stripe.position = Vector3(0, opening.y + 0.32, thickness * 0.5 + 0.06)
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
		leaf.add_child(box_mesh(shape.size, Color(0.36, 0.4, 0.44)))
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
