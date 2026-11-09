class_name EmitterDevice
extends PuzzleDeviceNode
## Powered beam emitter. Fires along its local -Z. The adapter traces the game beam; the visible beam
## only shows the traced length and never decides a hit (Architecture §7).

const CYAN: Color = Color(0.22, 0.78, 0.86)
const HOUSING: Vector3 = Vector3(0.5, 0.5, 0.7)
## DEV-05 art: its recessed lens opening sits on the firing axis. The collision stays the HOUSING box;
## the lens disc and rear lamp are code, so only optics ever turn cyan (ADR-0006).
const MODEL: PackedScene = preload("res://content/models/devices/emitter/emitter_body.gltf")
const LENS_RADIUS: float = 0.116
const LENS_Z: float = -0.331

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
	add_child(body)
	var model: Node3D = MODEL.instantiate() as Node3D
	model.name = "Model"
	add_child(model)
	_lens = disc_mesh(LENS_RADIUS, DARK)
	_lens.name = "Lens"
	_lens.rotation.x = PI * 0.5
	_lens.position = Vector3(0, 0, LENS_Z)
	add_child(_lens)
	_lamp = box_mesh(Vector3(0.05, 0.05, 0.01), DARK)
	_lamp.name = "PowerLamp"
	_lamp.position = Vector3(0, 0.12, 0.332)
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
	# The traced beam starts at the muzzle, clear of the housing; the visible one starts at the lens inside
	# the cowl, so it never looks detached from its source.
	var start: float = -LENS_Z
	var visible_length: float = beam_length + (HOUSING.z * 0.5 + 0.05 - start)
	_beam.scale = Vector3(1, 1, maxf(visible_length, 0.01))
	_beam.position = Vector3(0, 0, -start - visible_length * 0.5)
