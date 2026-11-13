class_name MechanicsOpticsBay
extends MechanicsBayBuilder


func _build() -> void:
	_button(&"qa.optics.toggle", Vector3(8, 1.3, -7.72), DeviceDefinition.WallMode.TOGGLE, 1)
	_box(Vector3(3, 3, 0.3), Vector3(8, 1.5, -8), WALL_COLOR, "SwitchSupport")
	_emitter(&"qa.optics.emitter", Vector3(8, 0.40, 0), [&"qa.optics.toggle"])
	_receiver(&"qa.optics.receiver", Vector3(-7, 0.40, 0))
	_test_door(&"qa.optics.door", Vector3(0, 0, -8), [&"qa.optics.receiver"])
	_cube("Blocker", &"qa.optics.cube", Vector3(-3, 0.30, 5), BallastCube.Kind.LIGHT)
	_cube("HeavyBlocker", &"qa.optics.heavy", Vector3(0, 0.425, 5), BallastCube.Kind.HEAVY)
	_board("Включи эмиттер: луч → приёмник → дверь\nПерекрой луч кубом или телом — приёмник гаснет", Vector3(0, 4, -11.8))
	_board("Свет следует состоянию сети, а не текстуре\nПереключатель отключает питание эмиттера", Vector3(0, 3.8, 11.8), 180)
