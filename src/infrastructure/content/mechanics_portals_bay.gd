class_name MechanicsPortalsBay
extends MechanicsBayBuilder


func _floor() -> void:
	_floor_around(Vector2(-12, -10), Vector2(12, 10))


func _build() -> void:
	var fixture: PortalLabBuilder = PortalLabBuilder.new()
	fixture.name = "Fixture"
	add_child(fixture)
	_board("Порталы: проход в обе стороны, с кубом и без\nПоловина куба, бросок, занятый выход, отключение питания", Vector3(0, 4.6, 11.8), 180)
