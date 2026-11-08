class_name TrialLogicBuilder
extends ChamberBuilder
## Trial 1 (easy): buttons and logic. Three rooms along -Z, each opens one door:
## 1) cube on a plate; 2) plate AND a 5 s timed button; 3) latch S/R through a 2 s delay.

const HALF_WIDTH: float = 5.0
const HEIGHT: float = 4.0
const DOOR_A: float = -8.0
const DOOR_B: float = -20.0
const DOOR_C: float = -32.0


func _ready() -> void:
	_corridor(HALF_WIDTH, 4.0, -40.0, HEIGHT)
	# Room 1: one 10 kg cube presses the 8 kg plate.
	_plate(&"t1.plate.a", Vector3(-2.5, 0, -4.0), 8.0, 6.0)
	_cube("CubeA", &"t1.cube.a", Vector3(2.5, 0.55, -1.0), 10.0)
	_partition(HALF_WIDTH, DOOR_A, HEIGHT, 0.0, &"t1.door.a", [&"t1.plate.a"])
	_sign("1 · Положите куб на плиту", Vector3(0, 3.5, DOOR_A + 0.2))
	# Room 2: plate AND a timed wall button; the door stays open 5 s after the press.
	_plate(&"t1.plate.b", Vector3(-2.5, 0, -14.0), 4.0, 3.0)
	_cube("CubeB", &"t1.cube.b", Vector3(2.5, 0.55, -11.0), 5.0)
	_button(&"t1.button.timer", Vector3(3.0, 1.3, DOOR_B + 0.25), DeviceDefinition.WallMode.TIMED, 5.0)
	_logic(&"t1.and", DeviceDefinition.Kind.AND, [&"t1.plate.b", &"t1.button.timer"], Vector3(-2.8, 2.2, DOOR_B + 0.2))
	_partition(HALF_WIDTH, DOOR_B, HEIGHT, 0.0, &"t1.door.b", [&"t1.and"])
	_sign("2 · Куб на плите И кнопка (5 с) — успейте пройти", Vector3(0, 3.5, DOOR_B + 0.2))
	# Room 3: S stores, R clears (reset wins); the door follows the latch after a 2 s delay.
	_button(&"t1.button.set", Vector3(2.6, 1.3, DOOR_C + 0.25), DeviceDefinition.WallMode.TIMED, 0.2, "S")
	_button(&"t1.button.reset", Vector3(3.4, 1.3, DOOR_C + 0.25), DeviceDefinition.WallMode.TIMED, 0.2, "R")
	_logic(&"t1.latch", DeviceDefinition.Kind.LATCH, [&"t1.button.set", &"t1.button.reset"], Vector3(-3.2, 2.2, DOOR_C + 0.2))
	_logic(&"t1.delay", DeviceDefinition.Kind.DELAY, [&"t1.latch"], Vector3(-2.5, 2.2, DOOR_C + 0.2), 2.0)
	_partition(HALF_WIDTH, DOOR_C, HEIGHT, 0.0, &"t1.door.c", [&"t1.delay"])
	_sign("3 · S запоминает, R сбрасывает · дверь — через 2 с", Vector3(0, 3.5, DOOR_C + 0.2))
	# Exit.
	_sign("Испытание 1 пройдено", Vector3(0, 2.2, -39.8))
	for z: float in [-2.0, -14.0, -26.0, -36.0]:
		_lamp(Vector3(0, 3.6, z), 9.0, 1.3)
