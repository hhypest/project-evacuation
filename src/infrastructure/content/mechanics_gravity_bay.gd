class_name MechanicsGravityBay
extends MechanicsBayBuilder


func _floor() -> void:
	# The combined bench owns its floor and the emitter shaft; no solid slab may fill that shaft.
	_floor_around(Vector2(0.8, -10), Vector2(10.8, 10))


func _build() -> void:
	_box(Vector3(0.3, 4.2, 10), Vector3(-10.75, 2.1, 4), WALL_COLOR, "GravityWall")
	_button(&"qa.gravity.toggle", Vector3(-10.48, 1.3, -1), DeviceDefinition.WallMode.TOGGLE, 1, "", 90)
	_field(&"qa.gravity.field", Vector3(-8.1, 2, 4), Vector3(4, 5, 8), -90, [&"qa.gravity.toggle"])
	_plate(&"qa.gravity.plate", Vector3(-10.6, 0.75, 4), 4, 3, Vector3(0, 0, -90))
	_cube("WallCube", &"qa.gravity.cube", Vector3(-7.4, 0.55, 4), 5)
	_board("Поле к стене: поверни игрока и куб\nКуб на настенной плите; выйди за край поля", Vector3(-5.5, 4.6, 11.8), 180)
	var loop: TrialLoopBuilder = TrialLoopBuilder.new()
	loop.name = "CombinedLoop"
	loop.position = Vector3(5.8, 0, 6)
	loop.chamber_height = 5.5
	loop.side_entry = 1
	add_child(loop)
	_board("Комбинация справа: перекрой вертикальный луч\nНЕ включает поле; куб на стене удерживает решение", Vector3(5.5, 4.8, 11.8), 180)
