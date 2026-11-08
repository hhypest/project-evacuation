class_name GravityFieldDevice
extends PuzzleDeviceNode
## Box-shaped directional gravity field. "Down" is the node's local -Y; the box is size in local axes.
## Bodies receive it through a REPLACE Area3D (one effective source); the player is sampled by
## SampleGravity at the capsule centre. The network only switches power.

const VIOLET: Color = Color(0.58, 0.36, 0.9)

@export var size: Vector3 = Vector3(4, 4, 4)
## Acceleration magnitude, m/s².
@export var strength: float = 9.8
@export var priority: int = 0

var area: Area3D
var powered: bool = false
var _edges: Array[MeshInstance3D] = []
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
	for edge: MeshInstance3D in _edges:
		_paint(edge, 2.0 if on else 0.0)
	_fill.visible = on


## Gravity vector of a directional area is global; it follows the node orientation.
func _aim() -> void:
	area.gravity_direction = (-global_basis.y).normalized()
	area.gravity = strength


func _build_visual() -> void:
	var half: Vector3 = size * 0.5
	var thickness: float = 0.03
	for axis: int in range(3):
		for a: float in [-1.0, 1.0]:
			for b: float in [-1.0, 1.0]:
				var extent: Vector3 = Vector3(thickness, thickness, thickness)
				extent[axis] = size[axis]
				var at: Vector3 = Vector3.ZERO
				at[(axis + 1) % 3] = a * half[(axis + 1) % 3]
				at[(axis + 2) % 3] = b * half[(axis + 2) % 3]
				var edge: MeshInstance3D = box_mesh(extent, VIOLET)
				edge.position = at
				_paint(edge, 0.0)
				_edges.append(edge)
				add_child(edge)
	# Three "V" chevrons in the centre point along local -Y ("down").
	for index: int in range(3):
		for side: float in [-1.0, 1.0]:
			var arm: MeshInstance3D = box_mesh(Vector3(0.5, 0.06, 0.06), VIOLET)
			arm.position = Vector3(side * 0.2, 0.6 - index * 0.5 + 0.14, 0)
			arm.rotation.z = side * deg_to_rad(35.0)
			_paint(arm, 0.0)
			_edges.append(arm)
			add_child(arm)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(VIOLET, 0.04)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_fill = MeshInstance3D.new()
	_fill.mesh = mesh
	_fill.material_override = material
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.visible = false
	add_child(_fill)


static func _paint(mesh: MeshInstance3D, glow: float) -> void:
	var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = VIOLET if glow > 0.0 else VIOLET.darkened(0.6)
	material.emission_enabled = glow > 0.0
	material.emission = VIOLET
	material.emission_energy_multiplier = glow
