class_name TrialLoopBuilder
extends ChamberBuilder
## Example chamber «Петля» (docs/design/puzzles/loop.md): one room, one idea, no new mechanics.
## An emitter sunk in the floor fires up along the left wall to a ceiling receiver; receiver → NOT → a field
## toward the left wall. The player blocks the beam with their body to switch the field on, walks up the wall
## with the cube and leaves it on the wall plate, which sits in the beam: the cube keeps the field on and the
## field keeps the cube on the plate, so the door stays open.

const HALF_WIDTH: float = 5.0
const HEIGHT: float = 7.0
const Z_FRONT: float = 4.0
const Z_BACK: float = -16.0
## Beam line: 1.5 m from the left wall, so a player standing in it has room to turn onto the wall.
const BEAM_X: float = -3.5
const BEAM_Z: float = -7.0
const SHAFT: float = 0.6
const OPENING: float = 0.3
## Ballast cube edge. A 1 m cube does not fit beside a player who has just turned onto the wall (eye ~0.86 m
## above the floor), and the carry rules release it; 0.75 m fits in any orientation.
const CUBE_EDGE: float = 0.75
## Plinth on the wall carrying the plate; deep enough that a cube resting on it covers the beam.
const PLINTH_DEPTH: float = 0.75
const PLINTH_FACE: float = 0.9
const PLINTH_Y: float = 3.7
const DOOR_Z: float = -13.0
const DOOR_X: float = 2.5


func _ready() -> void:
	_envelope()
	_logic(&"loop.power", DeviceDefinition.Kind.SOURCE, [], Vector3(-HALF_WIDTH + 0.08, 1.6, -1.0), 1.0, 90.0, true)
	_logic(&"loop.not", DeviceDefinition.Kind.NOT, [&"loop.receiver"], Vector3(-HALF_WIDTH + 0.08, 2.2, -2.0), 1.0, 90.0)
	_floor_emitter()
	_ceiling_receiver()
	_field(&"loop.field", Vector3(-HALF_WIDTH + 2.0, HEIGHT * 0.5, BEAM_Z), Vector3(HEIGHT, 4.0, 7.0), -90.0, [&"loop.not"])
	# Guide rails on the wall above the turning height keep a climbing player in the beam line.
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.5, 1.5, 0.1), Vector3(-HALF_WIDTH + 0.25, 2.25, BEAM_Z + side * 0.5), WALL_COLOR, "Rail")
	_box(Vector3(PLINTH_DEPTH, PLINTH_FACE, PLINTH_FACE), Vector3(-HALF_WIDTH + PLINTH_DEPTH * 0.5, PLINTH_Y, BEAM_Z), WALL_COLOR, "Plinth")
	_wall_plate()
	_cube("CubeA", &"loop.cube", Vector3(2.0, CUBE_EDGE * 0.5 + 0.05, -4.5), 10.0, CUBE_EDGE)
	_partition(HALF_WIDTH, DOOR_Z, HEIGHT, DOOR_X, &"loop.door", [&"loop.plate"])
	_sign("Камера «Петля»", Vector3(DOOR_X, 4.6, DOOR_Z + 0.2))
	_sign("Схема: источник → эмиттер\nприёмник → НЕ → поле к стене\nкнопка на стене → дверь", Vector3(-1.2, 4.6, DOOR_Z + 0.2))
	_sign("Камера пройдена", Vector3(DOOR_X, 2.4, Z_BACK + 0.2))
	for at: Vector3 in [Vector3(0, HEIGHT - 0.4, -1.5), Vector3(0, HEIGHT - 0.4, -8.5), Vector3(2.0, 3.6, -14.5)]:
		_lamp(at, 11.0, 1.4)


## Floor with a shaft for the emitter, side walls and end caps. The shaft mouth is narrowed to 0.3 m so
## the player stands over it instead of dropping in; the capsule bottom dips about 4 cm into it.
func _envelope() -> void:
	var length: float = Z_FRONT - Z_BACK
	var middle: float = (Z_FRONT + Z_BACK) * 0.5
	var near_x: float = BEAM_X - SHAFT * 0.5
	var far_x: float = BEAM_X + SHAFT * 0.5
	var near_z: float = BEAM_Z + SHAFT * 0.5
	var far_z: float = BEAM_Z - SHAFT * 0.5
	_box(Vector3(near_x + HALF_WIDTH, 1.0, length), Vector3((near_x - HALF_WIDTH) * 0.5, -0.5, middle), FLOOR_COLOR, "Floor")
	_box(Vector3(HALF_WIDTH - far_x, 1.0, length), Vector3((far_x + HALF_WIDTH) * 0.5, -0.5, middle), FLOOR_COLOR)
	_box(Vector3(SHAFT, 1.0, Z_FRONT - near_z), Vector3(BEAM_X, -0.5, (Z_FRONT + near_z) * 0.5), FLOOR_COLOR)
	_box(Vector3(SHAFT, 1.0, far_z - Z_BACK), Vector3(BEAM_X, -0.5, (far_z + Z_BACK) * 0.5), FLOOR_COLOR)
	_box(Vector3(SHAFT, 0.1, SHAFT), Vector3(BEAM_X, -1.05, BEAM_Z), FLOOR_COLOR)
	var lip: float = (SHAFT - OPENING) * 0.5
	var collar: Color = Color(0.88, 0.42, 0.18)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(lip, 0.06, SHAFT), Vector3(BEAM_X + side * (SHAFT - lip) * 0.5, -0.03, BEAM_Z), collar)
		_box(Vector3(OPENING, 0.06, lip), Vector3(BEAM_X, -0.03, BEAM_Z + side * (SHAFT - lip) * 0.5), collar)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.3, HEIGHT, length), Vector3(side * (HALF_WIDTH + 0.15), HEIGHT * 0.5, middle))
	for z: float in [Z_FRONT + 0.15, Z_BACK - 0.15]:
		_box(Vector3(HALF_WIDTH * 2.0 + 0.6, HEIGHT, 0.3), Vector3(0, HEIGHT * 0.5, z))


## Emitter sunk in the shaft, firing straight up. The muzzle sits 0.2 m below the floor: a ray starting
## inside the capsule would not report it, so the player standing over the opening must be above the origin.
func _floor_emitter() -> void:
	var emitter: EmitterDevice = EmitterDevice.new()
	emitter.name = node_name(&"loop.emitter")
	emitter.stable_id = &"loop.emitter"
	emitter.inputs = [&"loop.power"]
	emitter.range_m = 20.0
	emitter.position = Vector3(BEAM_X, -0.6, BEAM_Z)
	emitter.rotation_degrees = Vector3(90, 0, 0)
	add_child(emitter)


## Receiver hung under a bracket at the top of the wall, facing down the beam.
func _ceiling_receiver() -> void:
	_box(Vector3(2.1, 0.3, 0.8), Vector3(-HALF_WIDTH + 1.05, HEIGHT + 0.125, BEAM_Z), WALL_COLOR, "Bracket")
	var receiver: ReceiverDevice = ReceiverDevice.new()
	receiver.name = node_name(&"loop.receiver")
	receiver.stable_id = &"loop.receiver"
	receiver.position = Vector3(BEAM_X, HEIGHT - 0.15, BEAM_Z)
	receiver.rotation_degrees = Vector3(90, 0, 0)
	add_child(receiver)


## 0.8 × 0.8 m plate on the plinth face, pressing toward the wall; a cube resting on it covers the beam line.
func _wall_plate() -> void:
	var plate: FloorButtonDevice = FloorButtonDevice.new()
	plate.name = node_name(&"loop.plate")
	plate.stable_id = &"loop.plate"
	plate.press_threshold_kg = 8.0
	plate.release_threshold_kg = 6.0
	plate.plate_size = Vector3(0.8, 0.1, 0.8)
	plate.position = Vector3(-HALF_WIDTH + PLINTH_DEPTH, PLINTH_Y, BEAM_Z)
	plate.rotation_degrees = Vector3(0, 0, -90)
	add_child(plate)
