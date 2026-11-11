class_name MechanicsLabBuilder
extends ChamberBuilder
## One playable level, seven independent bays and a permanently open central circulation route.


func _ready() -> void:
	_box(Vector3(4, 0.5, 80), Vector3(0, -0.25, -40), FLOOR_COLOR, "SpineFloor")
	_box(Vector3(8, 0.5, 8), Vector3(0, -0.25, 4), FLOOR_COLOR, "HubFloor")
	_box(Vector3(8.6, 6, 0.3), Vector3(0, 3, 8.15))
	_box(Vector3(4.6, 0.2, 80), Vector3(0, 6.1, -40), WALL_COLOR, "SpineCeiling")
	_box(Vector3(8.6, 0.2, 8.6), Vector3(0, 6.1, 4), WALL_COLOR, "HubCeiling")
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.3, 6, 8), Vector3(side * 4.15, 3, 4))
		_box(Vector3(2, 6, 0.3), Vector3(side * 3, 3, -0.15))
		for z: float in [-1.0, -27.0, -53.0, -79.0]:
			_box(Vector3(0.3, 6, 2), Vector3(side * 2.15, 3, z))
	_add_bay(MechanicsMovementBay.new(), "Movement", "01 · ДВИЖЕНИЕ", Vector3(-14, 0, -14), 1)
	_add_bay(MechanicsCarryBay.new(), "Carry", "02 · ПЕРЕНОС И ПОСТАНОВКА", Vector3(14, 0, -14), -1)
	_add_bay(MechanicsDevicesBay.new(), "Devices", "03 · УСТРОЙСТВА И ЛОГИКА", Vector3(-14, 0, -40), 1)
	_add_bay(MechanicsOpticsBay.new(), "Optics", "04 · ОПТИКА", Vector3(14, 0, -40), -1)
	_add_bay(MechanicsGravityBay.new(), "Gravity", "05 · ГРАВИТАЦИЯ И КОМБИНАЦИЯ", Vector3(-14, 0, -66), 1)
	_add_bay(MechanicsPortalsBay.new(), "Portals", "06 · ПОРТАЛЫ", Vector3(14, 0, -66), -1)
	var lighting: MechanicsLightingBay = MechanicsLightingBay.new()
	lighting.name = "Lighting"
	lighting.heading = "07 · СВЕТ И ТЕНИ"
	lighting.position = Vector3(0, 0, -92)
	lighting.rotation_degrees.y = 90
	lighting.entrance_side = -1
	add_child(lighting)
	_navigation_board()
	for z: float in [4.0, -10.0, -24.0, -38.0, -52.0, -66.0, -78.0]:
		_lamp(Vector3(0, 5.5, z), 13, 1.3)
	# A first interaction in the safe hub also exercises start/restart/carry without walking a whole bay.
	_cube("TestCube", &"lab.cube.medium", Vector3(0, 0.55, 0.8), 20)


func _add_bay(bay: MechanicsBayBuilder, label: String, title: String, at: Vector3, side: float) -> void:
	bay.name = label
	bay.heading = title
	bay.position = at
	bay.entrance_side = side
	add_child(bay)


func _navigation_board() -> void:
	_box(Vector3(3.8, 1.5, 0.08), Vector3(0, 3.6, -0.15), Color(0.04, 0.05, 0.06), "NavigationBoard")
	for x: float in [-1.75, 1.75]:
		_box(Vector3(0.06, 1.65, 0.06), Vector3(x, 5.175, -0.15))
	var label: Label3D = Label3D.new()
	label.text = "ЕДИНЫЙ ПОЛИГОН\n01 Движение ← → 02 Перенос\n03 Устройства ← → 04 Оптика\n05 Гравитация ← → 06 Порталы\n07 Свет и тени — в конце коридора\nR — полный сброс · Esc — пауза"
	label.position = Vector3(0, 3.6, -0.105)
	label.font_size = 36
	label.pixel_size = 0.0028
	label.outline_size = 0
	add_child(label)
