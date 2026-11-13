class_name OxygenTrainingBuilder
extends ChamberBuilder
## A short transition between two supplied sections.

const CHECKPOINT: ChamberCheckpoint = preload("res://content/definitions/oxygen_checkpoint.tres")
const BREACH_START_Z: float = -6.0
const BREACH_END_Z: float = -22.0
const SUPPLY_START_Z: float = -24.0
const WARNING: Color = Color(0.48, 0.76, 0.12)
const WALL: Material = preload("res://content/materials/alien/concrete030_basalt.tres")
const FLOOR: Material = preload("res://content/materials/alien/basalt_floor.tres")

var reserve: OxygenReserve = OxygenReserve.new()
var exposed: bool = false
var supplied: bool = false
var _beacon: MeshInstance3D


func _ready() -> void:
	_corridor(2.8, 4.0, -32.0, 3.4)
	_box(Vector3(5.6, 0.24, 36), Vector3(0, 3.52, -14), WALL_COLOR, "Ceiling")
	for child: Node in get_children():
		var shell: StaticBody3D = child as StaticBody3D
		if shell != null:
			var mesh: MeshInstance3D = shell.get_child(1) as MeshInstance3D
			mesh.mesh = MetricBoxMesh.make((mesh.mesh as BoxMesh).size, shell.position)
			mesh.material_override = FLOOR if shell.name == &"Floor" else WALL
	for z: float in [1.0, -5.0, -14.0, -21.0, -27.0]:
		_lamp(Vector3(0, 3.07, z), 10.0, 1.5)
	for z: float in [BREACH_START_Z, BREACH_END_Z]:
		var strip: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(5.2, 0.018, 0.18), WARNING, 0.45)
		strip.position = Vector3(0, 0.009, z)
		add_child(strip)
	_beacon = PuzzleDeviceNode.box_mesh(Vector3(0.60, 0.18, 0.12), WARNING)
	_beacon.position = Vector3(0, 2.93, -6.04)
	add_child(_beacon)
	_sign("РАЗГЕРМЕТИЗАЦИЯ\nИдите к шлюзу снабжения", Vector3(0, 2.62, -6.15))
	_sign("СНАБЖЕНИЕ\nКислород восстанавливается", Vector3(0, 2.60, -26.8))
	_checkpoint()
	_finish_zone(Vector3(0, 1.0, -30.0), Vector3(5.3, 2.1, 1.0), Vector3(0, 2.3, -31.72))


func advance_air(player_center: Vector3, delta: float) -> void:
	var in_breach: bool = player_center.z <= BREACH_START_Z and player_center.z > BREACH_END_Z
	if exposed != in_breach:
		var material: StandardMaterial3D = _beacon.material_override as StandardMaterial3D
		material.emission_enabled = in_breach
		material.emission = WARNING
		material.emission_energy_multiplier = 1.1
	exposed = in_breach
	supplied = player_center.z > BREACH_START_Z or player_center.z <= SUPPLY_START_Z
	reserve.step(delta, exposed, supplied)


func _checkpoint() -> void:
	var terminal: CheckpointTerminal = CheckpointTerminal.new()
	terminal.name = "CheckpointTerminal"
	terminal.checkpoint = CHECKPOINT
	terminal.position = Vector3(1.7, 1.35, -4.7)
	var spawn: Marker3D = Marker3D.new()
	spawn.position = Vector3(0, -1.3, 1.4)
	terminal.spawn = spawn
	terminal.add_child(spawn)
	add_child(terminal)
