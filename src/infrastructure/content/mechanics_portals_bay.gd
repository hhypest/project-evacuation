class_name MechanicsPortalsBay
extends MechanicsBayBuilder

var _view_blockers: Array[AABB] = []


func _floor() -> void:
	_floor_around(Vector2(-12, -10), Vector2(12, 10))


func _build() -> void:
	var fixture: PortalLabBuilder = PortalLabBuilder.new()
	fixture.name = "Fixture"
	add_child(fixture)
	var pair: PortalPairDevice = fixture.get_node("portal_pair") as PortalPairDevice
	pair.surface_a.view_blockers = _view_blockers
	pair.surface_b.view_blockers = _view_blockers
	_board("Порталы: проход в обе стороны, с кубом и без\nПоловина куба, бросок, занятый выход, отключение питания", Vector3(0, 4.6, 11.8), 180)


func _surface_box(size: Vector3, at: Vector3, material: Material, label: String = "") -> StaticBody3D:
	# This bay's shell is authored on world axes. Skip custom rotated placements.
	if global_basis.is_equal_approx(Basis.IDENTITY):
		_view_blockers.append(AABB(to_global(at) - size * 0.5, size).grow(-0.02))
	return super._surface_box(size, at, material, label)
