class_name MechanicsDevicesBay
extends MechanicsBayBuilder


func _build() -> void:
	_plate(&"qa.devices.plate", Vector3(-7, 0, -3), 8, 6)
	_test_door(&"qa.devices.door.plate", Vector3(-7, 0, -8), [&"qa.devices.plate"])
	_cube("PlateCubeA", &"qa.devices.cube.a", Vector3(-9, 0.55, 0), 5)
	_cube("PlateCubeB", &"qa.devices.cube.b", Vector3(-7.5, 0.55, 0), 5)
	_button(&"qa.devices.timed", Vector3(-2, 1.3, -7.72), DeviceDefinition.WallMode.TIMED, 4)
	_test_door(&"qa.devices.door.timed", Vector3(0, 0, -8), [&"qa.devices.timed"])
	_button(&"qa.devices.toggle", Vector3(5, 1.3, -7.72), DeviceDefinition.WallMode.TOGGLE, 1)
	_test_door(&"qa.devices.door.toggle", Vector3(7, 0, -8), [&"qa.devices.toggle"])
	_box(Vector3(16, 3, 0.25), Vector3(-2, 1.5, 6), WALL_COLOR, "LogicBench")
	_button(&"qa.devices.a", Vector3(-8, 1.2, 6.22), DeviceDefinition.WallMode.TOGGLE, 1, "A")
	_button(&"qa.devices.b", Vector3(-6.8, 1.2, 6.22), DeviceDefinition.WallMode.TOGGLE, 1, "B")
	_button(&"qa.devices.set", Vector3(0, 1.2, 6.22), DeviceDefinition.WallMode.TIMED, 0.2, "S")
	_button(&"qa.devices.reset", Vector3(1.2, 1.2, 6.22), DeviceDefinition.WallMode.TIMED, 0.2, "R")
	_logic(&"qa.devices.source", DeviceDefinition.Kind.SOURCE, [], Vector3(-8, 2.2, 6.22), 1, 0, true)
	_logic(&"qa.devices.and", DeviceDefinition.Kind.AND, [&"qa.devices.a", &"qa.devices.b"], Vector3(-6, 2.2, 6.22))
	_logic(&"qa.devices.or", DeviceDefinition.Kind.OR, [&"qa.devices.a", &"qa.devices.b"], Vector3(-4, 2.2, 6.22))
	_logic(&"qa.devices.not", DeviceDefinition.Kind.NOT, [&"qa.devices.a"], Vector3(-2, 2.2, 6.22))
	_logic(&"qa.devices.latch", DeviceDefinition.Kind.LATCH, [&"qa.devices.set", &"qa.devices.reset"], Vector3(0, 2.2, 6.22))
	_logic(&"qa.devices.delay", DeviceDefinition.Kind.DELAY, [&"qa.devices.latch"], Vector3(2, 2.2, 6.22), 1)
	_test_door(&"qa.devices.door.logic", Vector3(0, 0, 0), [&"qa.devices.delay"])
	_board("Плита: 8 кг / отпускание 6 кг · два куба по 5 кг\nТаймер 4 с · переключатель · дверь не зажимает тело", Vector3(0, 4.8, -11.8))
	_board("A/B → И, ИЛИ, НЕ · S/R → защёлка → задержка 1 с\nЛампа каждого узла показывает выход; задержка открывает дверь", Vector3(0, 4, 11.8), 180)
