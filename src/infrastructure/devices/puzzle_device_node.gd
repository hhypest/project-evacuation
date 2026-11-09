class_name PuzzleDeviceNode
extends Node3D
## Scene-side identity and authoring parameters of a puzzle device. It never decides its own state:
## the network output arrives through show_output().

@export var stable_id: StringName = &""
## IDs of devices that drive this one (consumers and logic only; ignored by sensors).
@export var inputs: Array[StringName] = []

const AMBER: Color = Color(0.91, 0.59, 0.24)
const DARK: Color = Color(0.08, 0.09, 0.1)


func definition() -> DeviceDefinition:
	return null


func show_output(_on: bool, _delta: float) -> void:
	pass


static func box_mesh(size: Vector3, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	return visual


static func static_box(size: Vector3, color: Color, at: Vector3) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 6
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	body.add_child(box_mesh(size, color))
	return body


## A flat disc (thin cylinder along local Y) with the same material rules as box_mesh.
static func disc_mesh(radius: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var visual: MeshInstance3D = box_mesh(Vector3.ONE, color, emission)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.008
	mesh.radial_segments = 32
	visual.mesh = mesh
	return visual


## Indicator lamp material: amber means "powered / signal present" (ADR-0006); dark means off.
static func set_lamp(lamp: MeshInstance3D, on: bool) -> void:
	var material: StandardMaterial3D = lamp.material_override as StandardMaterial3D
	if material == null:
		return
	material.albedo_color = AMBER if on else DARK
	material.emission_enabled = on
	material.emission = AMBER
	material.emission_energy_multiplier = 2.5
