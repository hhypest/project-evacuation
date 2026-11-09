class_name ReceiverDevice
extends PuzzleDeviceNode
## Beam receiver. Its front face is local +Z; the network accepts a beam only inside the acceptance cone
## around that normal, of the same channel, from a powered emitter.

const PLATE: Vector3 = Vector3(0.6, 0.6, 0.25)
## DEV-06 art: a circular receiving aperture. The optical rim, hit disc and signal lamp are separate
## geometry driven by the network; texture highlights never stand in for an accepted beam (ADR-0006).
const MODEL: PackedScene = preload("res://content/models/devices/receiver/receiver_body.gltf")
const APERTURE_RADIUS: float = 0.148
const FRAME_Z: float = 0.123
const DISH_Z: float = 0.125

@export var channel: int = 0
@export_range(1.0, 90.0) var acceptance_degrees: float = 30.0
## Consecutive ticks a hit or a loss must hold before the output changes.
@export var settle_ticks: int = 3

var body: StaticBody3D
var _ring: MeshInstance3D
var _guide: MeshInstance3D
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
	_guide = box_mesh(Vector3.ONE, DARK)
	_guide.name = "OpticalRim"
	var rim: TorusMesh = TorusMesh.new()
	rim.inner_radius = APERTURE_RADIUS
	rim.outer_radius = APERTURE_RADIUS + 0.008
	rim.rings = 64
	rim.ring_segments = 8
	_guide.mesh = rim
	_guide.rotation.x = PI * 0.5
	_guide.position.z = FRAME_Z
	add_child(_guide)
	_ring = disc_mesh(APERTURE_RADIUS, DARK)
	_ring.name = "HitLens"
	_ring.rotation.x = PI * 0.5
	_ring.position = Vector3(0, 0, DISH_Z)
	add_child(_ring)
	_lamp = box_mesh(Vector3(0.05, 0.05, 0.01), DARK)
	_lamp.name = "SignalLamp"
	_lamp.position = Vector3(0, -0.4, 0.205)
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
	var guide_material: StandardMaterial3D = _guide.material_override as StandardMaterial3D
	if guide_material != null:
		guide_material.albedo_color = EmitterDevice.CYAN if on else DARK
		guide_material.emission_enabled = on
		guide_material.emission = EmitterDevice.CYAN
		guide_material.emission_energy_multiplier = 1.0
	var material: StandardMaterial3D = _ring.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = EmitterDevice.CYAN if on else DARK
		material.emission_enabled = on
		material.emission = EmitterDevice.CYAN
		material.emission_energy_multiplier = 2.5
