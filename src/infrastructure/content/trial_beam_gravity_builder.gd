class_name TrialBeamGravityBuilder
extends ChamberBuilder
## Trial 2 (easy): beam and gravity. Three rooms along -Z:
## 1) move the cube out of the beam; 2) a field drops a cube onto a wall plate;
## 3) walk up the wall in a field and step off onto a 3 m ledge.

const HALF_WIDTH: float = 5.0
const HEIGHT: float = 6.0
const DOOR_A: float = -10.0
const DOOR_B: float = -24.0
const LEDGE_Z: float = -31.0
const END_Z: float = -38.0


func _ready() -> void:
	_corridor(HALF_WIDTH, 4.0, END_Z, HEIGHT)
	# Room 1: an always-on source powers the emitter; the cube sits in the beam.
	_logic(&"t2.power", DeviceDefinition.Kind.SOURCE, [], Vector3(-4.75, 1.6, -3.4), 1.0, 90.0, true)
	_emitter(&"t2.emitter", Vector3(-4.5, 0.6, -5.0), [&"t2.power"], -90.0)
	_receiver(&"t2.receiver", Vector3(4.6, 0.6, -5.0), -90.0)
	_cube("CubeA", &"t2.cube.a", Vector3(0, 0.55, -5.0), 10.0)
	_partition(HALF_WIDTH, DOOR_A, HEIGHT, 0.0, &"t2.door.a", [&"t2.receiver"])
	_sign("1 · Освободите путь лучу", Vector3(0, 3.5, DOOR_A + 0.2))
	# Room 2: a field toward the right wall drops the cube onto the wall plate; the door is outside the field.
	_button(&"t2.button.drop", Vector3(-4.75, 1.3, -14.0), DeviceDefinition.WallMode.TOGGLE, 1.0, "", 90.0)
	_field(&"t2.field.drop", Vector3(HALF_WIDTH - 1.25, 2.0, -17.0), Vector3(4.0, 2.5, 10.0), 90.0, [&"t2.button.drop"])
	_plate(&"t2.plate.wall", Vector3(HALF_WIDTH, 0.75, -17.0), 4.0, 3.0, Vector3(0, 0, 90))
	_cube("CubeB", &"t2.cube.b", Vector3(HALF_WIDTH - 1.4, 0.55, -17.0), 5.0)
	_partition(HALF_WIDTH, DOOR_B, HEIGHT, -2.0, &"t2.door.b", [&"t2.plate.wall"])
	_sign("2 · Включите поле — куб упадёт на кнопку на стене", Vector3(0, 3.6, DOOR_B + 0.2))
	# Room 3: a field toward the left wall; walk up past 3 m and forward out of the field onto the ledge.
	_button(&"t2.button.climb", Vector3(4.75, 1.3, -26.0), DeviceDefinition.WallMode.TOGGLE, 1.0, "", -90.0)
	_field(&"t2.field.climb", Vector3(-HALF_WIDTH + 2.0, 2.5, (DOOR_B - 1.0 + LEDGE_Z) * 0.5),
		Vector3(5.0, 4.0, DOOR_B - 1.0 - LEDGE_Z), -90.0, [&"t2.button.climb"])
	_box(Vector3(HALF_WIDTH * 2.0, 3.0, LEDGE_Z - END_Z), Vector3(0, 1.5, (LEDGE_Z + END_Z) * 0.5), WALL_COLOR, "Ledge")
	_sign("3 · Поле к левой стене: поднимитесь по стене\nвыше уступа и шагните вперёд", Vector3(1.5, 4.6, LEDGE_Z + 0.2))
	_sign("Испытание 2 пройдено", Vector3(0, 4.6, END_Z + 0.2))
	for z: float in [-3.0, -17.0, -28.0, -35.0]:
		_lamp(Vector3(0, HEIGHT - 0.4, z), 11.0, 1.4)
