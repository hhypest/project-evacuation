class_name QualificationRouteBuilder
extends ChamberBuilder
## A chained exercise with a safe boundary before traversal.

const CHECKPOINT: ChamberCheckpoint = preload("res://content/definitions/route_checkpoint.tres")
const WIDTH: float = 3.4
const HEIGHT: float = 4.4
const PORTAL_A_Z: float = -39.0
const PORTAL_B_Z: float = -43.0


func _ready() -> void:
	_envelope()
	_power_gate()
	_traversal()
	_finish_zone(Vector3(0, 1.0, -49.8), Vector3(6.2, 2.1, 1.0), Vector3(0, 2.4, -51.30))


func _envelope() -> void:
	# Continuous floor on each side of a ten-metre gap. The gravity wall spans the gap.
	_box(Vector3(2 * WIDTH, 1, 26), Vector3(0, -0.5, -9), FLOOR_COLOR)
	_box(Vector3(2 * WIDTH, 1, 20), Vector3(0, -0.5, -42), FLOOR_COLOR)
	_box(Vector3(2 * WIDTH, 0.3, 56), Vector3(0, HEIGHT + 0.15, -24))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.3, HEIGHT + 13, 56), Vector3(side * (WIDTH + 0.15), (HEIGHT - 13) * 0.5, -24))
	for z: float in [4.15, -52.15]:
		_box(Vector3(2 * WIDTH, HEIGHT, 0.3), Vector3(0, HEIGHT * 0.5, z))
	for z: float in [1, -5, -12, -17, -24, -30, -36, -45, -49]:
		_lamp(Vector3(0, HEIGHT - 0.4, z), 11, 1.7)


func _power_gate() -> void:
	_cube("Ballast", &"route.ballast", Vector3(-1.6, 0.425, 0), BallastCube.Kind.HEAVY)
	_plate(&"route.plate", Vector3(-1.6, 0.045, -2.8), 8.0, 6.0)
	_emitter(&"route.beam", Vector3(-2.95, 0.7, -4.8), [&"route.plate"], -90)
	_receiver(&"route.receiver", Vector3(2.95, 0.7, -4.8), -90)
	_box(Vector3(0.52, 2.3, 0.40), Vector3(1.65, 1.15, -7.15))
	_button(&"route.request", Vector3(1.65, 1.33, -6.93), DeviceDefinition.WallMode.TIMED, 6.0, "ПУСК")
	_logic(&"route.authorized", DeviceDefinition.Kind.AND, [&"route.receiver", &"route.request"], Vector3(2.35, 2.2, -8.05))
	_logic(&"route.gate", DeviceDefinition.Kind.OR, [&"route.authorized", &"route.travel"], Vector3(2.85, 2.2, -8.05))
	_partition(WIDTH, -8.3, HEIGHT, 0, &"route.door", [&"route.gate"])
	_sign("КУБ НА ПЛИТУ → ЛУЧ → ПУСК", Vector3(0, 3.5, -8.08))
	_sign("ПЛИТА · ОТ 8 КГ", Vector3(-1.6, 2.1, -3.45))


func _traversal() -> void:
	_box(Vector3(0.55, 2.1, 0.42), Vector3(-2.0, 1.05, -13.1))
	_button(&"route.travel", Vector3(-2, 1.34, -12.86), DeviceDefinition.WallMode.TOGGLE, 1.0, "МАРШРУТ")
	_sign("ВКЛЮЧИТЕ МАРШРУТ\nСохранитесь перед полем", Vector3(0, 2.65, -13.35))
	var terminal: CheckpointTerminal = CheckpointTerminal.new()
	terminal.name = "CheckpointTerminal"
	terminal.checkpoint = CHECKPOINT
	terminal.blocked_message = "ВКЛЮЧИТЕ\nМАРШРУТ"
	terminal.position = Vector3(1.75, 1.35, -13.2)
	var spawn: Marker3D = Marker3D.new()
	spawn.position = Vector3(0, -1.3, 1.45)
	terminal.spawn = spawn
	terminal.add_child(spawn)
	add_child(terminal)
	_field(&"route.field", Vector3(0, 2.1, -26), Vector3(4.6, 7.2, 18), -90, [&"route.travel"])
	_sign("ПОЛЕ → ЛЕВАЯ СТЕНА\nДвигайтесь вдоль коридора", Vector3(0, 3.65, -16.1))
	_portal_wall(PORTAL_A_Z)
	_portal_wall(PORTAL_B_Z)
	_box(Vector3(2 * WIDTH, HEIGHT, 0.6), Vector3(0, HEIGHT * 0.5, -41))
	var pair: PortalPairDevice = PortalPairDevice.new()
	pair.name = "RoutePortals"
	pair.stable_id = &"route.portals"
	pair.inputs = [&"route.travel"]
	pair.a_transform = Transform3D(Basis.IDENTITY, Vector3(0, 1.2, PORTAL_A_Z))
	pair.b_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.2, PORTAL_B_Z))
	add_child(pair)
	_sign("ПОРТАЛ A", Vector3(0, 2.9, PORTAL_A_Z + 0.2))


func _portal_wall(z: float) -> void:
	var width: float = WIDTH - 0.8
	for side: float in [-1.0, 1.0]:
		_box(Vector3(width, HEIGHT, 0.3), Vector3(side * (0.8 + width * 0.5), HEIGHT * 0.5, z))
	_box(Vector3(1.6, HEIGHT - 2.4, 0.3), Vector3(0, (HEIGHT + 2.4) * 0.5, z))
