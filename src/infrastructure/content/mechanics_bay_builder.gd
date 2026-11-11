class_name MechanicsBayBuilder
extends ChamberBuilder
## A 24 m independent test bay. Its side entrance always stays open onto the shared corridor.

@export var entrance_side: float = -1.0
@export var heading: String = ""

const FLOOR_MATERIAL: Material = preload("res://content/materials/alien/basalt_floor.tres")
const WALL_MATERIAL: Material = preload("res://content/materials/alien/basalt_wall.tres")


func _ready() -> void:
	_floor()
	_shell()
	_build()
	_board(heading, Vector3(entrance_side * 11.8, 3.4, 0), 90.0 * entrance_side)
	_lighting()


func _lighting() -> void:
	for x: float in [-6.0, 6.0]:
		for z: float in [-6.0, 6.0]:
			_lamp(Vector3(x, 5.1, z), 12.0, 1.3)


func _build() -> void:
	pass


func _floor() -> void:
	_floor_piece(Vector2(-12, -12), Vector2(12, 12))


func _floor_piece(low: Vector2, high: Vector2) -> void:
	if high.x <= low.x or high.y <= low.y:
		return
	var size: Vector2 = high - low
	var at: Vector2 = (low + high) * 0.5
	_surface_box(Vector3(size.x, 0.5, size.y), Vector3(at.x, -0.25, at.y), FLOOR_MATERIAL)


func _floor_around(low: Vector2, high: Vector2) -> void:
	_floor_piece(Vector2(-12, -12), Vector2(low.x, 12))
	_floor_piece(Vector2(high.x, -12), Vector2(12, 12))
	_floor_piece(Vector2(low.x, -12), Vector2(high.x, low.y))
	_floor_piece(Vector2(low.x, high.y), Vector2(high.x, 12))


func _shell() -> void:
	for side: float in [-1.0, 1.0]:
		if side == entrance_side:
			for z: float in [-7.0, 7.0]:
				_surface_box(Vector3(0.3, 6, 10), Vector3(side * 12.15, 3, z), WALL_MATERIAL)
			_surface_box(Vector3(0.3, 2.6, 4), Vector3(side * 12.15, 4.7, 0), WALL_MATERIAL)
		else:
			_surface_box(Vector3(0.3, 6, 24.6), Vector3(side * 12.15, 3, 0), WALL_MATERIAL)
		_surface_box(Vector3(24.6, 6, 0.3), Vector3(0, 3, side * 12.15), WALL_MATERIAL)
	_surface_box(Vector3(24.6, 0.2, 24.6), Vector3(0, 6.1, 0), WALL_MATERIAL, "Ceiling")


func _surface_box(size: Vector3, at: Vector3, material: Material, label: String = "") -> StaticBody3D:
	var body: StaticBody3D = _box(size, at, WALL_COLOR, label)
	for child: Node in body.get_children():
		var visual: MeshInstance3D = child as MeshInstance3D
		if visual != null:
			visual.material_override = material
	return body


func _board(text: String, at: Vector3, yaw: float = 0.0) -> void:
	var board: Node3D = Node3D.new()
	board.position = at
	board.rotation_degrees.y = yaw
	var panel: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(4.4, 0.7, 0.035), Color(0.04, 0.05, 0.06))
	board.add_child(panel)
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = 36
	label.pixel_size = 0.0018
	label.outline_size = 0
	label.position.z = 0.022
	board.add_child(label)
	add_child(board)


func _test_door(id: StringName, at: Vector3, sources: Array[StringName]) -> DoorDevice:
	# Side pockets conceal the open leaves, while a route around the 6 m stand stays accessible.
	for side: float in [-1.0, 1.0]:
		_box(Vector3(1.7, 4, 0.4), at + Vector3(side * 2.15, 2, 0))
	_box(Vector3(2.6, 1, 0.4), at + Vector3(0, 3.5, 0))
	return _door(id, at, sources)


func _movement_volume(label: String, at: Vector3, size: Vector3, kind: MovementVolume.Kind) -> void:
	var volume: MovementVolume = MovementVolume.new()
	volume.name = label
	volume.position = at
	volume.kind = kind
	volume.collision_layer = 8
	volume.collision_mask = 0
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	volume.add_child(collision)
	add_child(volume)
