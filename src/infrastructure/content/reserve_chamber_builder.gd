class_name ReserveChamberBuilder
extends ChamberBuilder
## Two isolated rooms and a gated service hall. All puzzle state belongs to the existing device network.

const HALF_WIDTH: float = 7.0
const HEIGHT: float = 4.5
const RESERVE_Z: float = -29.0
const EXIT_Z: float = -47.0
const PORTAL_X: float = -3.0
const PORTAL_A_Z: float = -8.0
const PORTAL_B_Z: float = -12.0
const SOLID: Material = preload("res://content/materials/alien/basalt_wall.tres")
const GROUND: Material = preload("res://content/materials/alien/basalt_floor.tres")
const GUIDE: Color = Color(0.35, 0.72, 0.78)

var completed: bool = false
var _completion_sign: Label3D


func _ready() -> void:
	_envelope()
	_entry_room()
	_optics_room()
	_service_hall()
	_exit()


func _envelope() -> void:
	_surface(Vector3(14, 0.5, 57), Vector3(0, -0.25, -22.5), GROUND)
	_surface(Vector3(14.6, 0.3, 57), Vector3(0, HEIGHT + 0.15, -22.5), SOLID)
	for side: float in [-1.0, 1.0]:
		_surface(Vector3(0.3, HEIGHT, 57), Vector3(side * 7.15, HEIGHT * 0.5, -22.5), SOLID)
	for z: float in [6.15, -51.15]:
		_surface(Vector3(14.6, HEIGHT, 0.3), Vector3(0, HEIGHT * 0.5, z), SOLID)
	_portal_wall(PORTAL_X, PORTAL_A_Z)
	_portal_wall(-PORTAL_X, PORTAL_B_Z)
	# Unpowered apertures are shallow pockets. The seal does not touch either portal exit.
	_surface(Vector3(14, HEIGHT, 0.6), Vector3(0, HEIGHT * 0.5, -10.0), SOLID)
	for z: float in [3.0, -5.0, -15.0, -22.0, -27.0, -34.0, -42.0, -49.0]:
		_lamp(Vector3(0, 4.1, z), 10, 1.75)


func _entry_room() -> void:
	_cube("Ballast", &"reserve.cube.ballast", Vector3(3.5, 0.425, 0), BallastCube.Kind.HEAVY)
	_plate(&"reserve.primary", Vector3(3.5, 0.05, -5.0), 8.0, 6.0)
	_logic(&"reserve.portal_feed", DeviceDefinition.Kind.OR, [&"reserve.primary", &"reserve.backup"],
		Vector3(-1.65, 1.55, PORTAL_A_Z + 0.25))
	var pair: PortalPairDevice = PortalPairDevice.new()
	pair.name = "PortalPair"
	pair.stable_id = &"reserve.portal"
	pair.inputs = [&"reserve.portal_feed"]
	pair.a_transform = Transform3D(Basis.IDENTITY, Vector3(PORTAL_X, 1.2, PORTAL_A_Z))
	pair.b_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-PORTAL_X, 1.2, PORTAL_B_Z))
	add_child(pair)
	_sign("РЕЗЕРВНЫЙ КОНТУР\nЦель: открыть выходной шлюз", Vector3(0, 3.55, -7.77))
	_sign("ПОРТАЛ\nОсновное ИЛИ резерв", Vector3(-3, 2.85, -7.76))
	_sign("ОСНОВНОЕ ПИТАНИЕ\nПлита · от 8 кг", Vector3(3.5, 2.0, -7.76))
	_guide(Vector3(3.5, 0.012, -5.9), Vector3(1.4, 0.014, 0.06))


func _optics_room() -> void:
	_cube("ScreenCube", &"reserve.cube.screen", Vector3(-3.5, 0.30, -16.2), BallastCube.Kind.LIGHT)
	_logic(&"reserve.source", DeviceDefinition.Kind.SOURCE, [], Vector3(-5.65, 1.25, -19.0), 1.0, 90.0, true)
	_emitter(&"reserve.emitter", Vector3(-5.75, 0.56, -19.0), [&"reserve.source"], -90.0)
	_receiver(&"reserve.receiver", Vector3(5.75, 0.56, -19.0), -90.0)
	_logic(&"reserve.beam_blocked", DeviceDefinition.Kind.NOT, [&"reserve.receiver"],
		Vector3(1.82, 1.55, RESERVE_Z + 0.22))
	_logic(&"reserve.service_access", DeviceDefinition.Kind.OR, [&"reserve.beam_blocked", &"reserve.backup"],
		Vector3(2.35, 1.55, RESERVE_Z + 0.22))
	_partition(HALF_WIDTH, RESERVE_Z, HEIGHT, 0, &"reserve.service_door", [&"reserve.service_access"])
	_sign("ОПТИЧЕСКАЯ БЛОКИРОВКА\nЛуч принят — доступ закрыт", Vector3(0, 2.75, -28.8))
	_sign("ПРИЁМНИК", Vector3(6.82, 1.5, -19.0), -90.0)
	_sign("ИЗЛУЧАТЕЛЬ", Vector3(-6.82, 1.5, -19.0), 90.0)
	_guide(Vector3(0, 0.012, -19.0), Vector3(10.0, 0.014, 0.045))
	_screen_socket()


func _screen_socket() -> void:
	var socket: CarrySocketBody = CarrySocketBody.new()
	socket.name = "ScreenSocket"
	socket.stable_id = &"reserve.screen_socket"
	socket.position = Vector3(-3.5, 0.09, -19.0)
	socket.collision_layer = 1
	socket.collision_mask = 6
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.2, 0.18, 1.2)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	socket.add_child(collision)
	socket.add_child(PuzzleDeviceNode.box_mesh(shape.size, Color(0.32, 0.39, 0.41)))
	add_child(socket)


func _service_hall() -> void:
	_box(Vector3(1.6, 2.25, 0.45), Vector3(-4.5, 1.125, -34.3))
	_button(&"reserve.backup", Vector3(-4.5, 1.35, -34.0),
		DeviceDefinition.WallMode.TOGGLE, 1.0, "РЕЗЕРВ")
	_sign("РЕЗЕРВ\nУдерживает питание портала\nи открывает обратный проход", Vector3(-4.5, 2.52, -34.04))
	_plate(&"reserve.exit_load", Vector3(4.1, 0.05, -35.0), 8.0, 6.0)
	_sign("ВЫХОДНАЯ ПЛИТА\nот 8 кг", Vector3(6.82, 1.55, -35.0), -90.0)
	_guide(Vector3(4.1, 0.012, -35.9), Vector3(1.4, 0.014, 0.06))
	_logic(&"reserve.exit_feed", DeviceDefinition.Kind.AND, [&"reserve.exit_load", &"reserve.backup"],
		Vector3(1.85, 1.55, EXIT_Z + 0.22))
	_partition(HALF_WIDTH, EXIT_Z, HEIGHT, 0, &"reserve.exit_door", [&"reserve.exit_feed"])
	_sign("ВЫХОД\nРезерв И нагрузка", Vector3(0, 2.76, EXIT_Z + 0.19))


func _exit() -> void:
	var marker: Area3D = Area3D.new()
	marker.name = "Exit"
	marker.position = Vector3(0, 1.1, -49.4)
	marker.collision_layer = 0
	marker.collision_mask = 4
	marker.monitorable = false
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(13.8, 2.2, 1.4)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	marker.add_child(collision)
	marker.body_entered.connect(_on_exit_entered)
	add_child(marker)
	_completion_sign = Label3D.new()
	_completion_sign.position = Vector3(0, 2.4, -50.78)
	_completion_sign.font_size = 48
	_completion_sign.pixel_size = 0.006
	_completion_sign.modulate = Color(0.65, 1.0, 0.9)
	add_child(_completion_sign)


func _on_exit_entered(body: Node3D) -> void:
	if completed or body is not PlayerMotor:
		return
	completed = true
	_completion_sign.text = "ИСПЫТАНИЕ ПРОЙДЕНО\nR — заново · Esc — пауза"
	print("CHAMBER_COMPLETED level=reserve_circuit")


func _portal_wall(x: float, z: float) -> void:
	var left: float = x - 0.8
	var right: float = x + 0.8
	_surface(Vector3(left + HALF_WIDTH, HEIGHT, 0.3),
		Vector3((left - HALF_WIDTH) * 0.5, HEIGHT * 0.5, z), SOLID)
	_surface(Vector3(HALF_WIDTH - right, HEIGHT, 0.3),
		Vector3((HALF_WIDTH + right) * 0.5, HEIGHT * 0.5, z), SOLID)
	_surface(Vector3(1.6, HEIGHT - 2.4, 0.3), Vector3(x, (HEIGHT + 2.4) * 0.5, z), SOLID)


func _surface(size: Vector3, at: Vector3, material: Material) -> void:
	var body: StaticBody3D = _box(size, at)
	var mesh: MeshInstance3D = body.get_child(1) as MeshInstance3D
	mesh.mesh = MetricBoxMesh.make(size, at)
	mesh.material_override = material


func _guide(at: Vector3, size: Vector3) -> void:
	var marker: MeshInstance3D = PuzzleDeviceNode.box_mesh(size, GUIDE, 0.65)
	marker.position = at
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
