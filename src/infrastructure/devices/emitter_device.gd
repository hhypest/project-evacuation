class_name EmitterDevice
extends PuzzleDeviceNode
## Powered beam emitter. Fires along its local -Z. The adapter traces the game beam; the visible beam
## only shows the traced length and never decides a hit (Architecture §7).

const CYAN: Color = Color(0.22, 0.78, 0.86)
const HOUSING: Vector3 = Vector3(0.5, 0.5, 0.7)

## Maximum game-beam length, metres.
@export var range_m: float = 20.0
@export var channel: int = 0

var body: StaticBody3D
## Power state last shown by the network.
var powered: bool = false
## Length of the last traced beam, metres.
var beam_length: float = 0.0
var _beam: MeshInstance3D
var _lens: MeshInstance3D
var _lamp: MeshInstance3D


func _ready() -> void:
	body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 6
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = HOUSING
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	body.add_child(box_mesh(HOUSING, Color(0.88, 0.86, 0.82)))
	add_child(body)
	var stripe: MeshInstance3D = box_mesh(Vector3(0.52, 0.08, 0.5), Color(0.88, 0.42, 0.18))
	stripe.position = Vector3(0, 0.2, 0.05)
	add_child(stripe)
	_lens = box_mesh(Vector3(0.24, 0.24, 0.04), DARK)
	_lens.position = Vector3(0, 0, -HOUSING.z * 0.5 - 0.02)
	add_child(_lens)
	_lamp = box_mesh(Vector3(0.07, 0.07, 0.02), DARK)
	_lamp.position = Vector3(0, 0.12, HOUSING.z * 0.5 + 0.01)
	add_child(_lamp)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = CYAN
	material.emission_enabled = true
	material.emission = CYAN
	material.emission_energy_multiplier = 3.0
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, 1.0)
	_beam = MeshInstance3D.new()
	_beam.name = "Beam"
	_beam.mesh = mesh
	_beam.material_override = material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)


func definition() -> DeviceDefinition:
	var result: DeviceDefinition = DeviceDefinition.make(stable_id, DeviceDefinition.Kind.EMITTER, inputs)
	result.channel = channel
	return result


## World-space start of the beam, just outside the lens.
func muzzle() -> Vector3:
	return global_transform * Vector3(0, 0, -HOUSING.z * 0.5 - 0.05)


func direction() -> Vector3:
	return -global_basis.z.normalized()


func show_output(on: bool, _delta: float) -> void:
	powered = on
	set_lamp(_lamp, on)
	var material: StandardMaterial3D = _lens.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = CYAN if on else DARK
		material.emission_enabled = on
		material.emission = CYAN
		material.emission_energy_multiplier = 2.0
	show_beam(beam_length)


## Updates the visible beam to the traced length; hidden while unpowered.
func show_beam(length: float) -> void:
	beam_length = clampf(length, 0.0, range_m)
	if _beam == null:
		return
	_beam.visible = powered and beam_length > 0.01
	var start: float = HOUSING.z * 0.5 + 0.05
	_beam.scale = Vector3(1, 1, maxf(beam_length, 0.01))
	_beam.position = Vector3(0, 0, -start - beam_length * 0.5)
