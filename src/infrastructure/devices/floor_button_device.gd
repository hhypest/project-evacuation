class_name FloorButtonDevice
extends PuzzleDeviceNode
## Pressure plate. Counts the supported load: bodies resting on the plate plus bodies stacked on them,
## and the player when standing on that support. Presence in a volume alone never counts.

@export var press_threshold_kg: float = 8.0
@export var release_threshold_kg: float = 6.0
@export var settle_ticks: int = 3
@export var plate_size: Vector3 = Vector3(1.4, 0.1, 1.4)

const TRAVEL: float = 0.03
const STACK_HEIGHT: float = 3.0
## Art model (content/models/devices/floor_button), authored for a 1.4 x 0.1 x 1.4 m plate: a "Frame" that
## stays put and a "Plate" that sinks when pressed. Other plate sizes scale it; the collision stays the box.
const MODEL: PackedScene = preload("res://content/models/devices/floor_button/floor_button.gltf")
const MODEL_PLATE: Vector3 = Vector3(1.4, 0.1, 1.4)
## Lamp strip along the plate edge; it also walls the recess that the pressed plate leaves.
const LAMP_WIDTH: float = 0.025
const LAMP_DEPTH: float = 0.05

var plate: StaticBody3D
var last_load: float = 0.0
var _sensor: Area3D
var _model: Node3D
var _plate_visual: Node3D
var _lamps: Array[MeshInstance3D] = []


func _ready() -> void:
	_model = MODEL.instantiate() as Node3D
	_model.name = "Model"
	_model.scale = plate_size / MODEL_PLATE
	add_child(_model)
	_plate_visual = _model.get_node("Plate") as Node3D
	var half: Vector2 = Vector2(plate_size.x, plate_size.z) * 0.5 + Vector2.ONE * LAMP_WIDTH * 0.5
	var lamp_y: float = plate_size.y - LAMP_DEPTH * 0.5 + 0.004
	for side: float in [-1.0, 1.0]:
		_lamp_strip(Vector3(LAMP_WIDTH, LAMP_DEPTH, half.y * 2.0 + LAMP_WIDTH), Vector3(side * half.x, lamp_y, 0))
		_lamp_strip(Vector3(half.x * 2.0 - LAMP_WIDTH, LAMP_DEPTH, LAMP_WIDTH), Vector3(0, lamp_y, side * half.y))
	plate = StaticBody3D.new()
	plate.name = "Plate"
	plate.collision_layer = 1
	plate.collision_mask = 6
	plate.position.y = plate_size.y * 0.5
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = plate_size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	plate.add_child(collision)
	add_child(plate)
	_sensor = Area3D.new()
	_sensor.name = "Sensor"
	_sensor.collision_layer = 0
	_sensor.collision_mask = 2
	_sensor.monitorable = false
	var volume: BoxShape3D = BoxShape3D.new()
	volume.size = Vector3(plate_size.x + 0.6, STACK_HEIGHT, plate_size.z + 0.6)
	var sensor_shape: CollisionShape3D = CollisionShape3D.new()
	sensor_shape.shape = volume
	sensor_shape.position.y = plate_size.y + STACK_HEIGHT * 0.5
	_sensor.add_child(sensor_shape)
	add_child(_sensor)


func _lamp_strip(size: Vector3, at: Vector3) -> void:
	var strip: MeshInstance3D = box_mesh(size, DARK)
	strip.position = at
	add_child(strip)
	_lamps.append(strip)


func definition() -> DeviceDefinition:
	var result: DeviceDefinition = DeviceDefinition.make(stable_id, DeviceDefinition.Kind.FLOOR_BUTTON)
	result.press_threshold = press_threshold_kg
	result.release_threshold = release_threshold_kg
	result.settle_ticks = settle_ticks
	return result


## Supported load in kilograms after the last completed physics step.
func measure(player: CharacterBody3D, player_mass: float) -> float:
	var up: Vector3 = global_basis.y.normalized()
	var supported: Dictionary[int, RigidBody3D] = {}
	var candidates: Array[RigidBody3D] = []
	for body: Node3D in _sensor.get_overlapping_bodies():
		var rigid: RigidBody3D = body as RigidBody3D
		if rigid == null or rigid.freeze:
			continue
		if rigid is CarryRigidBody and (rigid as CarryRigidBody).is_carried():
			continue
		candidates.append(rigid)
	var grew: bool = true
	while grew:
		grew = false
		for body: RigidBody3D in candidates:
			if supported.has(body.get_instance_id()):
				continue
			for other: Node3D in body.get_colliding_bodies():
				var resting_on_plate: bool = other == plate
				var stacked: bool = other is RigidBody3D and supported.has(other.get_instance_id()) \
					and (body.global_position - other.global_position).dot(up) > 0.05
				if resting_on_plate or stacked:
					supported[body.get_instance_id()] = body
					grew = true
					break
	var total: float = 0.0
	for body: RigidBody3D in supported.values():
		total += body.mass
	if player != null and player.is_on_floor():
		for index: int in range(player.get_slide_collision_count()):
			var contact: KinematicCollision3D = player.get_slide_collision(index)
			if contact.get_normal().dot(player.up_direction) < 0.7:
				continue
			var collider: Object = contact.get_collider()
			if collider == plate or (collider is RigidBody3D and supported.has(collider.get_instance_id())):
				total += player_mass
				break
	last_load = total
	return total


func show_output(on: bool, _delta: float) -> void:
	for lamp: MeshInstance3D in _lamps:
		set_lamp(lamp, on)
	_plate_visual.position.y = -TRAVEL / _model.scale.y if on else 0.0
