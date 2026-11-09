class_name ReceiverDevice
extends PuzzleDeviceNode
## Beam receiver. Its front face is local +Z; the network accepts a beam only inside the acceptance cone
## around that normal, of the same channel, from a powered emitter.

const PLATE: Vector3 = Vector3(0.6, 0.6, 0.25)
## Art model (content/models/devices/receiver): a dark dish centred on the front. The cyan guide frame around
## it, the hit disc in the dish and the lamp stay code, so only optics turn cyan (ADR-0006).
const MODEL: PackedScene = preload("res://content/models/devices/receiver/receiver_body.gltf")
const FRAME_HALF: float = 0.2
const FRAME_Z: float = 0.128
const DISH_Z: float = 0.109

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
	add_child(body)
	var model: Node3D = MODEL.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	# Receiving frame on the front face: a thin cyan square around the dark dish.
	for offset: Vector3 in [Vector3(0, FRAME_HALF, 0), Vector3(0, -FRAME_HALF, 0)]:
		var bar: MeshInstance3D = box_mesh(Vector3(FRAME_HALF * 2.0 + 0.02, 0.02, 0.01), EmitterDevice.CYAN, 1.0)
		bar.position = offset + Vector3(0, 0, FRAME_Z)
		add_child(bar)
	for offset: Vector3 in [Vector3(FRAME_HALF, 0, 0), Vector3(-FRAME_HALF, 0, 0)]:
		var bar: MeshInstance3D = box_mesh(Vector3(0.02, FRAME_HALF * 2.0 + 0.02, 0.01), EmitterDevice.CYAN, 1.0)
		bar.position = offset + Vector3(0, 0, FRAME_Z)
		add_child(bar)
	_ring = disc_mesh(0.07, DARK)
	_ring.rotation.x = PI * 0.5
	_ring.position = Vector3(0, 0, DISH_Z)
	add_child(_ring)
	_lamp = box_mesh(Vector3(0.05, 0.05, 0.01), DARK)
	_lamp.position = Vector3(0, 0.26, FRAME_Z)
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
