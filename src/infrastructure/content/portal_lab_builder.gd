class_name PortalLabBuilder
extends ChamberBuilder
## SKL-08 portal experiment: one stationary pair in two real wall openings at 90° to each other. A faces +Z
## in the north wall, B faces -X in the east wall; both fronts face the main room. A cube pushed or thrown
## into one opening comes out of the other with rotated velocity. SKL-09 adds the player, its held cube,
## local exit barriers and a split visual body at the two apertures.

const HALF_SIZE: Vector2 = Vector2(0.8, 1.2)
const A_AT: Vector3 = Vector3(-5.0, 1.2, -3.0)
const B_AT: Vector3 = Vector3(6.0, 1.2, 1.0)
const WALL_HEIGHT: float = 3.4


func _ready() -> void:
	_box(Vector3(24, 1, 20), Vector3(0, -0.5, 0), FLOOR_COLOR, "Floor")
	# North wall (along X) with opening A; east wall (along Z) with opening B. Real holes, no disabled collision.
	_wall_with_hole(Vector3.RIGHT, Vector3(-10.0, 0, A_AT.z), Vector3(-1.0, 0, A_AT.z), A_AT.x, "NorthWall")
	_wall_with_hole(Vector3.BACK, Vector3(B_AT.x, 0, -4.0), Vector3(B_AT.x, 0, 6.0), B_AT.z, "EastWall")
	_button(&"portal.button", Vector3(-2.5, 1.3, A_AT.z + 0.25), DeviceDefinition.WallMode.TOGGLE, 1.0, "")
	_logic(&"portal.power", DeviceDefinition.Kind.NOT, [&"portal.button"], Vector3(-1.7, 1.4, A_AT.z + 0.2))
	var pair: PortalPairDevice = PortalPairDevice.new()
	pair.name = node_name(&"portal.pair")
	pair.stable_id = &"portal.pair"
	pair.inputs = [&"portal.power"]
	pair.half_size = HALF_SIZE
	pair.a_transform = Transform3D(Basis.IDENTITY, A_AT)
	pair.b_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), B_AT)
	add_child(pair)
	_cube("CubeA", &"portal.cube.a", Vector3(-3.0, 0.30, 2.0), BallastCube.Kind.LIGHT)
	_cube("CubeB", &"portal.cube.b", Vector3(-1.5, 0.30, 2.0), BallastCube.Kind.LIGHT)
	_cube("CubeHeavy", &"portal.cube.heavy", Vector3(0.5, 0.425, 3.0), BallastCube.Kind.HEAVY)
	_sign("Портал A · бросьте куб в проём — он выйдет из B\nпереключатель выключает пару", Vector3(-5.0, 3.0, A_AT.z + 0.2))
	_sign("Портал B", Vector3(B_AT.x - 0.2, 3.0, B_AT.z), -90.0)
	_sign("Порталы: пройдите сами или с кубом\nзанятый выход блокирует проход", Vector3(0, 2.6, 7.5), 180.0)
	_lamp(Vector3(-2.0, 4.5, 1.0), 14.0, 1.6)
	_lamp(Vector3(4.0, 4.5, 3.0), 10.0, 1.2)


## Wall from start to end (axis-aligned, 0.3 m thick) with a portal-sized hole centred at along_hole.
func _wall_with_hole(axis: Vector3, start: Vector3, end: Vector3, along_hole: float, label: String) -> void:
	var along_x: bool = axis == Vector3.RIGHT
	var a: float = start.x if along_x else start.z
	var b: float = end.x if along_x else end.z
	var hole_from: float = along_hole - HALF_SIZE.x
	var hole_to: float = along_hole + HALF_SIZE.x
	var spans: Array[Vector2] = [Vector2(a, hole_from), Vector2(hole_to, b)]
	for span: Vector2 in spans:
		var length: float = span.y - span.x
		var middle: float = (span.x + span.y) * 0.5
		_box(_size(along_x, length, WALL_HEIGHT), _at(along_x, middle, WALL_HEIGHT * 0.5, start), WALL_COLOR, label)
	var lintel: float = WALL_HEIGHT - HALF_SIZE.y * 2.0
	_box(_size(along_x, HALF_SIZE.x * 2.0, lintel), _at(along_x, along_hole, HALF_SIZE.y * 2.0 + lintel * 0.5, start), WALL_COLOR)


static func _size(along_x: bool, length: float, height: float) -> Vector3:
	return Vector3(length, height, 0.3) if along_x else Vector3(0.3, height, length)


static func _at(along_x: bool, middle: float, height: float, start: Vector3) -> Vector3:
	return Vector3(middle, height, start.z) if along_x else Vector3(start.x, height, middle)
