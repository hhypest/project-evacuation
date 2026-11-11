class_name MechanicsMovementBay
extends MechanicsBayBuilder


func _floor() -> void:
	_floor_around(Vector2(3, 3), Vector2(9, 9))


func _build() -> void:
	for index: int in range(5):
		var height: float = float(index + 1) * 0.2
		_box(Vector3(3.2, height, 0.8), Vector3(-6, height * 0.5, 6.0 - float(index) * 0.8))
	_box(Vector3(3.2, 1, 3), Vector3(-6, 0.5, 1))
	var ramp: StaticBody3D = _box(Vector3(3, 0.25, 6), Vector3(1, 0.8, -6), WALL_COLOR, "Ramp")
	ramp.rotation_degrees.x = 15
	var steep: StaticBody3D = _box(Vector3(3, 0.25, 4), Vector3(6, 1.8, -7), WALL_COLOR, "SteepRamp")
	steep.rotation_degrees.x = 65
	_box(Vector3(4, 0.4, 5), Vector3(-7, 1.3, -5), WALL_COLOR, "TunnelRoof")
	for x: float in [-9.2, -4.8]:
		_box(Vector3(0.4, 1.4, 5), Vector3(x, 0.7, -5))
	_box(Vector3(3, 1.35, 3), Vector3(-1, 0.675, -1), WALL_COLOR, "DuckJumpLedge")
	_box(Vector3(3, 3, 3), Vector3(-8, 1.5, -10), WALL_COLOR, "LadderPlatform")
	_movement_volume("Ladder", Vector3(-8, 2, -8.1), Vector3(1.4, 4.4, 0.8), MovementVolume.Kind.LADDER)
	for index: int in range(10):
		var rung: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(1.2, 0.06, 0.08), Color(0.7, 0.7, 0.65))
		rung.position = Vector3(-8, 0.3 + float(index) * 0.4, -8.35)
		add_child(rung)
	_pool()
	var platform: TestPlatform = TestPlatform.new()
	platform.name = "MovingPlatform"
	platform.position = Vector3(-1, 0.4, 7)
	platform.collision_layer = 1
	platform.collision_mask = 6
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3, 0.4, 3)
	collision.shape = shape
	platform.add_child(collision)
	platform.add_child(PuzzleDeviceNode.box_mesh(shape.size, Color(0.5, 0.45, 0.3)))
	add_child(platform)
	_board("Ступени 0,2 м · склон 15° / 65°\nCtrl — низкий проход; Ctrl в прыжке — уступ 1,35 м", Vector3(0, 3.8, -11.8))
	_board("Лестница: W/S, Space — оттолкнуться\nВода: Space / Ctrl; выход по ступеням", Vector3(0, 3.8, 11.8), 180)


func _pool() -> void:
	_box(Vector3(6, 0.5, 6), Vector3(6, -3.25, 6), FLOOR_COLOR, "PoolBottom")
	for x: float in [3.0, 9.0]:
		_box(Vector3(0.2, 3, 6), Vector3(x, -1.5, 6))
	for z: float in [3.0, 9.0]:
		_box(Vector3(6, 3, 0.2), Vector3(6, -1.5, z))
	_movement_volume("Water", Vector3(6, -1.4, 6), Vector3(6, 3.4, 6), MovementVolume.Kind.WATER)
	var water: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(5.8, 0.015, 5.8), Color(0.12, 0.3, 0.36, 0.4))
	water.name = "WaterSurface"
	water.position = Vector3(6, 0.3, 6)
	var material: StandardMaterial3D = water.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	add_child(water)
	for index: int in range(5):
		var top: float = -0.8 + float(index) * 0.2
		_box(Vector3(0.5, top + 3.0, 1.6), Vector3(5.25 - float(index) * 0.5, (top - 3.0) * 0.5, 6))
