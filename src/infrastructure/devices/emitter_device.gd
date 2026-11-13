class_name EmitterDevice
extends PuzzleDeviceNode
## Powered beam emitter. Fires along its local -Z. The adapter traces the game beam; the visible beam
## only shows the traced length and never decides a hit (Architecture §7).

const CORE_SHADER: Shader = preload("res://src/infrastructure/devices/optics_beam.gdshader")
const HALO_SHADER: Shader = preload("res://src/infrastructure/devices/optics_halo.gdshader")
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
var _halo: MeshInstance3D
var _impact: MeshInstance3D
var _has_impact: bool = false
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
	var core: BoxMesh = BoxMesh.new()
	core.size = Vector3(0.012, 0.012, 1.0)
	_beam = _light_mesh("Beam", core, CORE_SHADER)
	var halo: QuadMesh = QuadMesh.new()
	halo.size = Vector2(0.085, 1.0)
	_halo = _light_mesh("BeamHalo", halo, HALO_SHADER)
	_halo.rotation.x = -PI * 0.5
	# The billboard can turn out of its local plane. Use the whole cross-section for CPU culling.
	_halo.custom_aabb = AABB(Vector3(-0.043, -0.5, -0.043), Vector3(0.086, 1.0, 0.086))
	var contact: SphereMesh = SphereMesh.new()
	contact.radius = 0.024
	contact.height = 0.004
	contact.radial_segments = 16
	contact.rings = 4
	_impact = _light_mesh("BeamContact", contact, CORE_SHADER)
	var contact_material: ShaderMaterial = _impact.material_override as ShaderMaterial
	contact_material.set_shader_parameter(&"light_color", CYAN)
	contact_material.set_shader_parameter(&"intensity", 1.15)


func _light_mesh(label: String, mesh: Mesh, shader: Shader) -> MeshInstance3D:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visible = false
	add_child(visual)
	return visual


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
	_beam.visible = on and beam_length > 0.01
	_halo.visible = _beam.visible
	_impact.visible = on and _has_impact
	if not on:
		_has_impact = false


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
	_halo.visible = _beam.visible
	_halo.scale = Vector3(1, maxf(visible_length, 0.01), 1)
	_halo.position = _beam.position

## Place a steady contact mark on the physical surface hit by the same gameplay ray.
func show_contact(point: Vector3 = Vector3.ZERO, normal: Vector3 = Vector3.ZERO) -> void:
	_has_impact = not normal.is_zero_approx()
	_impact.visible = powered and _has_impact
	if _has_impact:
		var orientation: Basis = Basis(Quaternion(Vector3.UP, normal))
		_impact.global_transform = Transform3D(orientation, point + normal * 0.004)
