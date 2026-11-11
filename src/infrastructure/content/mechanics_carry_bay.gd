class_name MechanicsCarryBay
extends MechanicsBayBuilder


func _build() -> void:
	var masses: Array[float] = [5.0, 20.0, 40.0, 80.0]
	for index: int in range(masses.size()):
		_cube("MassCube%d" % index, StringName("qa.carry.mass%d" % index),
			Vector3(-6.0 + float(index) * 3.0, 0.55, 6), masses[index])
	_box(Vector3(0.25, 3, 7), Vector3(6, 1.5, -4), WALL_COLOR, "CarryWall")
	_box(Vector3(1.5, 0.2, 4), Vector3(6.75, 2.2, -4), WALL_COLOR, "CarryCeiling")
	_box(Vector3(0.25, 3, 7), Vector3(7.5, 1.5, -4), WALL_COLOR, "CarryBack")
	_box(Vector3(4, 2.2, 5), Vector3(0, 1.1, -8), WALL_COLOR, "StackingLedge")
	for index: int in range(3):
		_cube("StackCube%d" % index, StringName("qa.carry.stack%d" % index),
			Vector3(-6.0 + float(index) * 1.5, 0.425, -1.5), 10.0, 0.75)
	_plate(&"qa.carry.plate", Vector3(-7, 0, -6), 8, 6)
	_test_door(&"qa.carry.door", Vector3(-7, 0, -9), [&"qa.carry.plate"])
	_board("E — взять / поставить · ЛКМ — бросить\n5 / 20 / 40 кг переносимы; 80 кг — отказ", Vector3(0, 3.8, 11.8), 180)
	_board("Наведи куб на плиту или другой куб — виден силуэт\nТри куба 0,75 м: лестница на уступ 2,2 м", Vector3(0, 4.5, -11.8))
