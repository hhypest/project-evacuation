class_name MovementLabBuilder
extends Node3D
## Primitive movement proving ground; production level art comes in 0.4.0.


func _ready() -> void:
	_carry_cube("LightCube", &"lab.cube.light", Vector3(-7, 1, 10), 5.0)
	_carry_cube("LimitCube", &"lab.cube.limit", Vector3(-10, 1, 10), 40.0)
	_carry_cube("HeavyCube", &"lab.cube.heavy", Vector3(-13, 1, 10), 80.0)
	_box("CarryWall", Vector3(20, 1.5, 7), Vector3(0.2, 3, 6), Color(0.35, 0.4, 0.43))
	_box("CarryCeiling", Vector3(17, 2.2, 7), Vector3(3, 0.2, 4), Color(0.35, 0.4, 0.43))
	_box("CarryBack", Vector3(17, 1.5, 4), Vector3(6, 3, 0.2), Color(0.35, 0.4, 0.43))
	_sign("Перенос · E взять/отпустить · ЛКМ бросить", Vector3(-9, 2.5, 10))
	_sign("Стена / потолок", Vector3(17, 3, 4))
	var medium: CarryRigidBody = get_node("TestCube") as CarryRigidBody
	_handles(medium)
	for index: int in range(5):
		var height: float = float(index + 1) * 0.2
		_box("Step%d" % index, Vector3(-7, height * 0.5, -3.0 - float(index) * 0.8),
			Vector3(4, height, 0.8), Color(0.3, 0.45, 0.5))
	_box("StairLanding", Vector3(-7, 0.5, -9), Vector3(4, 1, 4), Color(0.3, 0.45, 0.5))
	var ramp: StaticBody3D = _box("Ramp", Vector3(7, 0.8, -7), Vector3(4, 0.25, 6), Color(0.35, 0.5, 0.4))
	ramp.rotation.x = deg_to_rad(15.0)
	var steep: StaticBody3D = _box("SteepRamp", Vector3(14, 1.8, -16), Vector3(4, 0.25, 4), Color(0.5, 0.3, 0.3))
	steep.rotation.x = deg_to_rad(65.0)
	_box("TunnelRoof", Vector3(-14, 1.3, -6), Vector3(4, 0.4, 6), Color(0.4, 0.4, 0.5))
	_box("TunnelLeft", Vector3(-16.2, 0.7, -6), Vector3(0.4, 1.4, 6), Color(0.3, 0.3, 0.4))
	_box("TunnelRight", Vector3(-11.8, 0.7, -6), Vector3(0.4, 1.4, 6), Color(0.3, 0.3, 0.4))
	_box("DuckJumpLedge", Vector3(-2, 0.675, -16), Vector3(3, 1.35, 4), Color(0.5, 0.4, 0.25))
	_box("LadderPlatform", Vector3(-13, 1.5, -23), Vector3(4, 3, 4), Color(0.3, 0.4, 0.5))
	_volume("Ladder", Vector3(-13, 2, -20.65), Vector3(1.4, 4.4, 0.8), MovementVolume.Kind.LADDER)
	for index: int in range(9):
		_visual("Rung%d" % index, Vector3(-13, 0.3 + float(index) * 0.4, -20.9),
			Vector3(1.2, 0.06, 0.08), Color(0.7, 0.65, 0.3))
	_box("PoolApproach", Vector3(24.5, -0.5, -2), Vector3(1, 1, 12), Color(0.2, 0.35, 0.4))
	_box("PoolBottom", Vector3(30, -3.25, -2), Vector3(10, 0.5, 12), Color(0.15, 0.3, 0.4))
	_box("PoolFarWall", Vector3(35, -1.5, -2), Vector3(0.4, 3, 12), Color(0.2, 0.35, 0.4))
	_box("PoolBackWall", Vector3(30, -1.5, -8), Vector3(10, 3, 0.4), Color(0.2, 0.35, 0.4))
	_box("PoolFrontWall", Vector3(30, -1.5, 4), Vector3(10, 3, 0.4), Color(0.2, 0.35, 0.4))
	_volume("Water", Vector3(30, -1.4, -2), Vector3(10, 3.4, 12), MovementVolume.Kind.WATER)
	var water: MeshInstance3D = _visual("WaterSurface", Vector3(30, 0.3, -2), Vector3(10, 0.015, 12), Color(0.05, 0.45, 0.6, 0.4))
	var material: StandardMaterial3D = water.material_override as StandardMaterial3D
	if material != null:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var platform: TestPlatform = TestPlatform.new()
	platform.name = "MovingPlatform"
	platform.position = Vector3(12, 0.4, 8)
	add_child(platform)
	_attach_box(platform, Vector3(4, 0.4, 4), Color(0.5, 0.45, 0.25))
	_sign("Ступени", Vector3(-7, 1.9, -9.5))
	_sign("Склон", Vector3(7, 2.5, -10.5))
	_sign("Низкий проход · Ctrl", Vector3(-14, 2, -6))
	_sign("Прыжок с приседанием", Vector3(-2, 2.5, -18))
	_sign("Лестница · W/S · Space", Vector3(-13, 4.5, -23))
	_sign("Вода · Space / Ctrl", Vector3(30, 1.5, -8))
	_sign("Движущаяся опора", Vector3(12, 2.5, 8))


func _box(label: String, at: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = label
	body.position = at
	add_child(body)
	_attach_box(body, size, color)
	return body


func _carry_cube(label: String, id: StringName, at: Vector3, kilograms: float) -> void:
	var body: CarryRigidBody = CarryRigidBody.new()
	body.name = label
	body.stable_id = id
	body.position = at
	body.mass = kilograms
	body.collision_layer = 2
	body.collision_mask = 7
	_attach_box(body, Vector3.ONE, Color(0.7, 0.72, 0.7))
	_handles(body)
	var sign: Label3D = Label3D.new()
	sign.text = "%.0f кг" % kilograms
	sign.position = Vector3(0, 0.55, 0)
	sign.pixel_size = 0.005
	sign.font_size = 40
	body.add_child(sign)
	add_child(body)


func _handles(body: CarryRigidBody) -> void:
	for side: float in [-1.0, 1.0]:
		var handle: MeshInstance3D = _mesh(Vector3(0.08, 0.4, 0.05), Color(0.88, 0.37, 0.12))
		handle.position = Vector3(side * 0.35, 0, 0.52)
		body.add_child(handle)


func _attach_box(body: PhysicsBody3D, size: Vector3, color: Color) -> void:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	var mesh: MeshInstance3D = _mesh(size, color)
	body.add_child(mesh)


func _visual(label: String, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual: MeshInstance3D = _mesh(size, color)
	visual.name = label
	visual.position = at
	add_child(visual)
	return visual


func _mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	return visual


func _volume(label: String, at: Vector3, size: Vector3, kind: MovementVolume.Kind) -> void:
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


func _sign(text: String, at: Vector3) -> void:
	var sign: Label3D = Label3D.new()
	sign.text = text
	sign.position = at
	sign.pixel_size = 0.008
	sign.font_size = 40
	add_child(sign)
