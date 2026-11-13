class_name StackingLabBuilder
extends ChamberBuilder
## Placement proving ground (ADR-0012, placement): a held cube aimed at the floor button or at another cube
## shows its silhouette there and E sets it down exactly in it. Three 0.75 m cubes make a ladder to a 2.2 m
## ledge: one cube, then two stacked, then the ledge — each step within the 0.9 m jump.

const HALF_WIDTH: float = 5.0
const HEIGHT: float = 5.0
const Z_FRONT: float = 4.0
const Z_BACK: float = -10.0
const CUBE_EDGE: float = BallastCube.HEAVY_EDGE
## Ledge on the right: front face at LEDGE_FRONT, top at LEDGE_HEIGHT.
const LEDGE_HEIGHT: float = 2.2
const LEDGE_FRONT: float = -3.5
const LEDGE_X: float = 2.75
const PLATE_AT: Vector3 = Vector3(-2.5, 0, -1.5)


func _ready() -> void:
	var ground: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(HALF_WIDTH * 2.0, 1, Z_FRONT - Z_BACK),
		FLOOR_COLOR, Vector3(0, -0.5, (Z_FRONT + Z_BACK) * 0.5))
	ground.name = "Floor"
	add_child(ground)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.3, HEIGHT, Z_FRONT - Z_BACK), Vector3(side * (HALF_WIDTH + 0.15), HEIGHT * 0.5, (Z_FRONT + Z_BACK) * 0.5))
	_box(Vector3(HALF_WIDTH * 2.0, HEIGHT, 0.3), Vector3(0, HEIGHT * 0.5, Z_FRONT + 0.15))
	_box(Vector3(HALF_WIDTH * 2.0, HEIGHT, 0.3), Vector3(0, HEIGHT * 0.5, Z_BACK - 0.15))
	var depth: float = LEDGE_FRONT - (Z_BACK + 2.0)
	_box(Vector3(HALF_WIDTH - 0.5, LEDGE_HEIGHT, depth), Vector3(LEDGE_X, LEDGE_HEIGHT * 0.5, LEDGE_FRONT - depth * 0.5),
		WALL_COLOR, "Ledge")
	_plate(&"stack.plate", PLATE_AT, 8.0, 6.0)
	_partition(HALF_WIDTH, Z_BACK + 2.0, HEIGHT, PLATE_AT.x, &"stack.door", [&"stack.plate"])
	for index: int in range(3):
		_cube("Cube%d" % index, StringName("stack.cube.%d" % index),
			Vector3(-1.0 + index * 1.5, CUBE_EDGE * 0.5 + 0.05, 1.0), BallastCube.Kind.HEAVY)
	_lamp(Vector3(0, HEIGHT - 0.4, -1.0), 14.0, 1.6)
	_lamp(Vector3(LEDGE_X, HEIGHT - 0.4, -6.0), 8.0, 1.0)
	_sign("Постановка: держа куб, наведи на кнопку или на другой куб.\nСилуэт покажет место, E ставит куб точно в него.",
		Vector3(-2.5, 3.4, Z_BACK + 2.2))
	_sign("Уступ 2,2 м\nлестница из трёх кубов", Vector3(LEDGE_X, LEDGE_HEIGHT + 1.2, LEDGE_FRONT + 0.05))
