class_name PuzzleLabBuilder
extends ChamberBuilder
## Primitive device proving ground (SKL-04/05/06/07): every bay shows one device rule.

const WALL_Z: float = -9.0
## Bay 5 (beam): partition along X with its own door; the beam runs in front of it.
const PARTITION_Z: float = 3.0
const BEAM_Z: float = 6.5
const BEAM_HEIGHT: float = 0.6
## Bay 6 (gravity): a 4.2 m wall at the left edge; the powered field pulls toward it (-X).
const GRAVITY_WALL_X: float = -14.7
const GRAVITY_Z: float = 8.0
## Bench 7 (logic kinds): a free-standing panel near the entrance from the movement lab.
const BENCH_Z: float = 12.6


func _ready() -> void:
	var ground: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(30, 1, 28), Color(0.13, 0.16, 0.19), Vector3(0, -0.5, 0))
	ground.name = "Floor"
	add_child(ground)
	# Bay 1: floor button with stackable 5 kg cubes; 8 kg presses, below 6 kg releases.
	_plate("lab.plate", Vector3(-10.5, 0, -4), 8.0, 6.0)
	_door("lab.door.plate", Vector3(-10.5, 0, WALL_Z), [&"lab.plate"])
	_cube("CubeA", &"lab.cube.small_a", Vector3(-8.5, 0.55, -1.5), 5.0)
	_cube("CubeB", &"lab.cube.small_b", Vector3(-7.2, 0.55, -1.5), 5.0)
	_sign("Напольная кнопка · порог 8 кг\nдва куба по 5 кг — один на другой", Vector3(-10.5, 3.4, WALL_Z + 0.2))
	# Bay 2: timed wall button.
	_button("lab.button.timed", Vector3(-6.0, 1.3, WALL_Z + 0.25), DeviceDefinition.WallMode.TIMED, 4.0)
	_door("lab.door.timed", Vector3(-3.5, 0, WALL_Z), [&"lab.button.timed"])
	_sign("Настенная кнопка\nудержание 4 с", Vector3(-4.5, 3.4, WALL_Z + 0.2))
	# Bay 3: toggle wall button.
	_button("lab.button.toggle", Vector3(1.0, 1.3, WALL_Z + 0.25), DeviceDefinition.WallMode.TOGGLE, 1.0)
	_door("lab.door.toggle", Vector3(3.5, 0, WALL_Z), [&"lab.button.toggle"])
	_sign("Настенная кнопка\nпереключение", Vector3(2.5, 3.4, WALL_Z + 0.2))
	# Bay 4: logic — latch (set/reset) through a delay, AND with the toggle bay.
	_button("lab.button.set", Vector3(7.0, 1.3, WALL_Z + 0.25), DeviceDefinition.WallMode.TIMED, 0.2, "S")
	_button("lab.button.reset", Vector3(7.8, 1.3, WALL_Z + 0.25), DeviceDefinition.WallMode.TIMED, 0.2, "R")
	_logic("lab.latch", DeviceDefinition.Kind.LATCH, [&"lab.button.set", &"lab.button.reset"], Vector3(7.5, 2.1, WALL_Z + 0.2))
	_logic("lab.delay", DeviceDefinition.Kind.DELAY, [&"lab.latch"], Vector3(8.1, 2.1, WALL_Z + 0.2), 1.0)
	_logic("lab.and", DeviceDefinition.Kind.AND, [&"lab.delay", &"lab.button.toggle"], Vector3(8.7, 2.1, WALL_Z + 0.2))
	_door("lab.door.logic", Vector3(10.5, 0, WALL_Z), [&"lab.and"])
	_sign("Логика: защёлка S/R → задержка 1 с\n→ И с кнопкой-переключателем", Vector3(9.0, 3.4, WALL_Z + 0.2))
	# Bay 5: toggle powers an emitter; the receiver opens the partition door. A cube or the player blocks the beam.
	_button("lab.button.beam", Vector3(13.8, 1.3, PARTITION_Z + 0.25), DeviceDefinition.WallMode.TOGGLE, 1.0)
	_emitter("lab.emitter", Vector3(14.2, BEAM_HEIGHT, BEAM_Z), [&"lab.button.beam"])
	_receiver("lab.receiver", Vector3(4.5, BEAM_HEIGHT, BEAM_Z))
	_door("lab.door.beam", Vector3(11.0, 0, PARTITION_Z), [&"lab.receiver"])
	_cube("CubeC", &"lab.cube.small_c", Vector3(9.0, 0.55, 9.0), 5.0)
	_sign("Луч: переключатель питает эмиттер\nприёмник открывает дверь · куб перекрывает", Vector3(11.0, 3.4, PARTITION_Z + 0.2))
	# Bay 6: toggle powers a field toward the wall; the cube falls onto a plate mounted on the wall,
	# the player walks on the wall. Leaving the field along the wall returns base gravity.
	var gravity_wall: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(0.3, 4.2, 10.0), WALL_COLOR,
		Vector3(GRAVITY_WALL_X - 0.15, 2.1, GRAVITY_Z - 1.0))
	gravity_wall.name = "GravityWall"
	add_child(gravity_wall)
	var gravity_button: Vector3 = Vector3(GRAVITY_WALL_X + 0.1, 1.3, GRAVITY_Z - 5.0)
	_button("lab.button.gravity", gravity_button, DeviceDefinition.WallMode.TOGGLE, 1.0)
	(get_node("lab_button_gravity") as Node3D).rotation_degrees = Vector3(0, 90, 0)
	var field: GravityFieldDevice = GravityFieldDevice.new()
	field.name = "lab_field"
	field.stable_id = &"lab.field"
	field.inputs = [&"lab.button.gravity"]
	# Local -Y aims at -X; local axes: X spans world height, Y spans the depth from the wall, Z the length.
	field.size = Vector3(4.0, 5.0, 8.0)
	field.position = Vector3(GRAVITY_WALL_X + 2.5, 2.0, GRAVITY_Z)
	field.rotation_degrees = Vector3(0, 0, -90)
	add_child(field)
	var wall_plate: FloorButtonDevice = FloorButtonDevice.new()
	wall_plate.name = "lab_plate_wall"
	wall_plate.stable_id = &"lab.plate.wall"
	wall_plate.press_threshold_kg = 4.0
	wall_plate.release_threshold_kg = 3.0
	wall_plate.position = Vector3(GRAVITY_WALL_X, 0.75, GRAVITY_Z)
	wall_plate.rotation_degrees = Vector3(0, 0, -90)
	add_child(wall_plate)
	_cube("CubeD", &"lab.cube.small_d", Vector3(GRAVITY_WALL_X + 3.2, 0.55, GRAVITY_Z), 5.0)
	_sign("Гравитация: переключатель включает поле к стене\nкуб падает на кнопку на стене · можно ходить по стене",
		Vector3(GRAVITY_WALL_X + 0.05, 3.7, GRAVITY_Z - 1.0), 90.0)
	# Bench 7: the remaining logic kinds. Two toggles feed OR and NOT; a source is always on.
	_box(Vector3(3.6, 2.6, 0.2), Vector3(-5.2, 1.3, BENCH_Z - 0.1), WALL_COLOR, "LogicBench")
	_button(&"lab.button.a", Vector3(-6.4, 1.2, BENCH_Z + 0.08), DeviceDefinition.WallMode.TOGGLE, 1.0, "A")
	_button(&"lab.button.b", Vector3(-5.6, 1.2, BENCH_Z + 0.08), DeviceDefinition.WallMode.TOGGLE, 1.0, "B")
	_logic(&"lab.or", DeviceDefinition.Kind.OR, [&"lab.button.a", &"lab.button.b"], Vector3(-6.0, 2.1, BENCH_Z + 0.05))
	_logic(&"lab.not", DeviceDefinition.Kind.NOT, [&"lab.button.a"], Vector3(-5.2, 2.1, BENCH_Z + 0.05))
	_logic(&"lab.source", DeviceDefinition.Kind.SOURCE, [], Vector3(-4.2, 2.1, BENCH_Z + 0.05), 1.0, 0.0, true)
	_sign("Логика: ИЛИ (A, B) · НЕ (A) · источник", Vector3(-5.2, 2.85, BENCH_Z + 0.02))
	_lamp(Vector3(-5.2, 2.8, BENCH_Z + 2.0), 6.0, 1.2)
	_beam_partition()
	_walls()
	for x: float in [-9.0, -1.0, 7.0]:
		var lamp: OmniLight3D = OmniLight3D.new()
		lamp.position = Vector3(x, 4.5, WALL_Z + 4.0)
		lamp.omni_range = 11.0
		lamp.light_energy = 1.6
		lamp.light_color = Color(0.9, 0.93, 1.0)
		add_child(lamp)
	var beam_lamp: OmniLight3D = OmniLight3D.new()
	beam_lamp.position = Vector3(10.0, 4.5, BEAM_Z)
	beam_lamp.omni_range = 9.0
	beam_lamp.light_energy = 1.2
	beam_lamp.light_color = Color(0.9, 0.93, 1.0)
	add_child(beam_lamp)
	var gravity_lamp: OmniLight3D = OmniLight3D.new()
	gravity_lamp.position = Vector3(GRAVITY_WALL_X + 4.0, 4.5, GRAVITY_Z)
	gravity_lamp.omni_range = 9.0
	gravity_lamp.light_energy = 1.2
	gravity_lamp.light_color = Color(0.9, 0.93, 1.0)
	add_child(gravity_lamp)


func _beam_partition() -> void:
	# Door at x = 11: 2 m opening plus 0.3 m posts on each side.
	for span: Vector2 in [Vector2(6.5, 9.7), Vector2(12.3, 15.0)]:
		var width: float = span.y - span.x
		var wall: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(width, 3.4, 0.3), WALL_COLOR,
			Vector3(span.x + width * 0.5, 1.7, PARTITION_Z))
		add_child(wall)


func _walls() -> void:
	# Wall segments between door frames; openings are 2 m + 0.3 m posts on each side.
	var openings: Array[float] = [-10.5, -3.5, 3.5, 10.5]
	var left: float = -15.0
	for center: float in openings:
		var right: float = center - 1.3
		if right > left:
			_wall(left, right)
		left = center + 1.3
	_wall(left, 15.0)
	var behind: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(30, 3.4, 0.3), WALL_COLOR, Vector3(0, 1.7, WALL_Z - 4.0))
	behind.name = "BackWall"
	add_child(behind)


func _wall(from_x: float, to_x: float) -> void:
	var width: float = to_x - from_x
	var wall: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(width, 3.4, 0.3), WALL_COLOR,
		Vector3(from_x + width * 0.5, 1.7, WALL_Z))
	add_child(wall)
