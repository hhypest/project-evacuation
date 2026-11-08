class_name ReceiverDevice
extends PuzzleDeviceNode
## Beam receiver. Its front face is local +Z; the network accepts a beam only inside the acceptance cone
## around that normal, of the same channel, from a powered emitter.

const PLATE: Vector3 = Vector3(0.6, 0.6, 0.25)

@export var channel: int = 0
@export_range(1.0, 90.0) var acceptance_degrees: float = 30.0
## Consecutive ticks a hit or a loss must hold before the output changes.
@export var settle_ticks: int = 3

var body: StaticBody3D
var _ring: MeshInstance3D
var _lamp: MeshInstance3D


func _ready() -> void:
	body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 6
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = PLATE
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.add_child(box_mesh(PLATE, Color(0.88, 0.86, 0.82)))
	add_child(body)
	# Receiving ring on the front face: cyan frame around a dark target.
	var front: float = PLATE.z * 0.5 + 0.01
	for offset: Vector3 in [Vector3(0, 0.2, 0), Vector3(0, -0.2, 0)]:
		var bar: MeshInstance3D = box_mesh(Vector3(0.44, 0.04, 0.02), EmitterDevice.CYAN, 1.0)
		bar.position = offset + Vector3(0, 0, front)
		add_child(bar)
	for offset: Vector3 in [Vector3(0.2, 0, 0), Vector3(-0.2, 0, 0)]:
		var bar: MeshInstance3D = box_mesh(Vector3(0.04, 0.44, 0.02), EmitterDevice.CYAN, 1.0)
		bar.position = offset + Vector3(0, 0, front)
		add_child(bar)
	_ring = box_mesh(Vector3(0.3, 0.3, 0.02), DARK)
	_ring.position = Vector3(0, 0, front)
	add_child(_ring)
	_lamp = box_mesh(Vector3(0.08, 0.08, 0.02), DARK)
	_lamp.position = Vector3(0, 0.34, 0)
	add_child(_lamp)


func definition() -> DeviceDefinition:
	var result: DeviceDefinition = DeviceDefinition.make(stable_id, DeviceDefinition.Kind.RECEIVER)
	result.channel = channel
	result.acceptance_degrees = acceptance_degrees
	result.settle_ticks = settle_ticks
	return result


func owns(collider: Object) -> bool:
	return collider == body


## World-space front normal used for the incidence angle.
func front() -> Vector3:
	return global_basis.z.normalized()


func show_output(on: bool, _delta: float) -> void:
	set_lamp(_lamp, on)
	var material: StandardMaterial3D = _ring.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = EmitterDevice.CYAN if on else DARK
		material.emission_enabled = on
		material.emission = EmitterDevice.CYAN
		material.emission_energy_multiplier = 2.5
