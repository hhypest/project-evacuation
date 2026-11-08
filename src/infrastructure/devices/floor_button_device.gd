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

var plate: StaticBody3D
var last_load: float = 0.0
var _sensor: Area3D
var _plate_visual: MeshInstance3D
var _lamp: MeshInstance3D


func _ready() -> void:
	var skirt: MeshInstance3D = box_mesh(Vector3(plate_size.x + 0.4, 0.06, plate_size.z + 0.4), Color(0.23, 0.25, 0.28))
	skirt.position.y = 0.03
	add_child(skirt)
	_lamp = box_mesh(Vector3(plate_size.x + 0.12, 0.065, plate_size.z + 0.12), DARK)
	_lamp.position.y = 0.035
	add_child(_lamp)
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
	_plate_visual = box_mesh(plate_size, Color(0.6, 0.62, 0.64))
	_plate_visual.position.y = plate_size.y * 0.5
	add_child(_plate_visual)
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
	set_lamp(_lamp, on)
	_plate_visual.position.y = plate_size.y * 0.5 - (TRAVEL if on else 0.0)
