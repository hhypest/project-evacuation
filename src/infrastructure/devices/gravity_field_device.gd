class_name GravityFieldDevice
extends PuzzleDeviceNode
## Box-shaped directional gravity field. "Down" is the node's local -Y; the box is size in local axes.
## Bodies receive it through a REPLACE Area3D (one effective source); the player is sampled by
## SampleGravity at the capsule centre. The network only switches power.

const VIOLET: Color = Color(0.58, 0.36, 0.9)
const BOUNDARY_SHADER: Shader = preload("res://src/infrastructure/devices/gravity_boundary.gdshader")

@export var size: Vector3 = Vector3(4, 4, 4)
## Acceleration magnitude, m/s².
@export var strength: float = 9.8
@export var priority: int = 0

var area: Area3D
var powered: bool = false
var _guides_only: bool = false
var _guide_material: StandardMaterial3D
var _fill: MeshInstance3D


func _ready() -> void:
	area = Area3D.new()
	area.name = "Field"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_DISABLED
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	area.add_child(collision)
	add_child(area)
	_build_visual()


func definition() -> DeviceDefinition:
	return DeviceDefinition.make(stable_id, DeviceDefinition.Kind.GRAVITY_FIELD, inputs)


func zone() -> GravityZone:
	return GravityZone.make(stable_id, priority, (-global_basis.y).normalized(), strength, powered)


func contains(point: Vector3) -> bool:
	var local: Vector3 = global_transform.affine_inverse() * point
	var half: Vector3 = size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## Engine overlap order; the adapter derives it from GravityRules.rank so engine and rules agree.
func set_engine_priority(value: int) -> void:
	area.priority = value


func show_output(on: bool, _delta: float) -> void:
	if on == powered:
		return
	powered = on
	_aim()
	area.gravity_space_override = Area3D.SPACE_OVERRIDE_REPLACE if on else Area3D.SPACE_OVERRIDE_DISABLED
	# A field change must reach resting bodies: Jolt does not wake sleepers for an area parameter change.
	for body: Node3D in area.get_overlapping_bodies():
		var rigid: RigidBody3D = body as RigidBody3D
		if rigid != null:
			rigid.sleeping = false
	_guide_material.albedo_color = VIOLET if on else VIOLET.darkened(0.7)
	_guide_material.emission_enabled = on
	_fill.visible = on and not _guides_only


## Gravity vector of a directional area is global; it follows the node orientation.
func _aim() -> void:
	area.gravity_direction = (-global_basis.y).normalized()
	area.gravity = strength


## Screen reads are deliberately omitted where authored volumes overlap.
func omit_refraction() -> void:
	_guides_only = true
	_fill.hide()


func _build_visual() -> void:
	_guide_material = StandardMaterial3D.new()
	_guide_material.albedo_color = VIOLET.darkened(0.7)
	_guide_material.roughness = 0.65
	_guide_material.emission = VIOLET
	_guide_material.emission_energy_multiplier = 0.65
	var half: Vector3 = size * 0.5
	for axis: int in range(3):
		var span: float = minf(size[axis] * 0.20, 0.46)
		var extent: Vector3 = Vector3.ONE * 0.018
		extent[axis] = span
		for a: float in [-1.0, 1.0]:
			for b: float in [-1.0, 1.0]:
				for end: float in [-1.0, 1.0]:
					var at: Vector3 = Vector3.ZERO
					at[axis] = end * (half[axis] - span * 0.5)
					at[(axis + 1) % 3] = a * half[(axis + 1) % 3]
					at[(axis + 2) % 3] = b * half[(axis + 2) % 3]
					_guide(extent, at)
	# Put direction chevrons on the edges of the volume, clear of the playfield.
	for side: float in [-1.0, 1.0]:
		for index: int in range(2):
			for arm: float in [-1.0, 1.0]:
				var z: float = side * (half.z - 0.015)
				var x: float = minf(0.19, half.x * 0.25) * arm
				var marker: MeshInstance3D = _guide(Vector3(0.42, 0.025, 0.018),
					Vector3(x, (0.25 - index * 0.5) * minf(size.y, 1.0), z))
				marker.rotation.z = arm * deg_to_rad(35.0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = BOUNDARY_SHADER
	material.render_priority = -30
	material.set_shader_parameter(&"half_size", half)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_fill = MeshInstance3D.new()
	_fill.name = "BoundarySheen"
	_fill.mesh = mesh
	_fill.material_override = material
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.visible = false
	# Screen-reading fragments use the main camera's opaque pass. Portal cameras see the guides.
	_fill.layers = SCREEN_EFFECT_LAYER
	add_child(_fill)


func _guide(extent: Vector3, at: Vector3) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = extent
	var guide: MeshInstance3D = MeshInstance3D.new()
	guide.mesh = mesh
	guide.material_override = _guide_material
	guide.position = at
	guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(guide)
	return guide
