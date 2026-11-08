class_name PuzzleLabBuilder
extends Node3D
## Primitive device proving ground (SKL-04/05/06/07): every bay shows one device rule.

const WALL_Z: float = -9.0
## Bay 5 (beam): partition along X with its own door; the beam runs in front of it.
const PARTITION_Z: float = 3.0
const BEAM_Z: float = 6.5
const BEAM_HEIGHT: float = 0.6
## Bay 6 (gravity): a 4.2 m wall at the left edge; the powered field pulls toward it (-X).
const GRAVITY_WALL_X: float = -14.7
const GRAVITY_Z: float = 8.0
const WALL_COLOR: Color = Color(0.2, 0.23, 0.26)


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
	_partition()
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


func _partition() -> void:
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


func _plate(id: StringName, at: Vector3, press: float, release: float) -> void:
	var plate: FloorButtonDevice = FloorButtonDevice.new()
	plate.name = String(id).replace(".", "_")
	plate.stable_id = id
	plate.press_threshold_kg = press
	plate.release_threshold_kg = release
	plate.position = at
	add_child(plate)


func _button(id: StringName, at: Vector3, mode: DeviceDefinition.WallMode, hold: float, caption: String = "") -> void:
	var button: WallButtonDevice = WallButtonDevice.new()
	button.name = String(id).replace(".", "_")
	button.stable_id = id
	button.mode = mode
	button.hold_seconds = hold
	button.caption = caption
	button.position = at
	add_child(button)


func _door(id: StringName, at: Vector3, sources: Array[StringName]) -> void:
	var door: DoorDevice = DoorDevice.new()
	door.name = String(id).replace(".", "_")
	door.stable_id = id
	door.inputs = sources
	door.position = at
	add_child(door)


func _emitter(id: StringName, at: Vector3, sources: Array[StringName]) -> void:
	_stand(at)
	var emitter: EmitterDevice = EmitterDevice.new()
	emitter.name = String(id).replace(".", "_")
	emitter.stable_id = id
	emitter.inputs = sources
	emitter.range_m = 20.0
	emitter.position = at
	# Local -Z fires toward -X.
	emitter.rotation_degrees = Vector3(0, 90, 0)
	add_child(emitter)


func _receiver(id: StringName, at: Vector3) -> void:
	_stand(at)
	var receiver: ReceiverDevice = ReceiverDevice.new()
	receiver.name = String(id).replace(".", "_")
	receiver.stable_id = id
	receiver.position = at
	# Local +Z front faces +X, toward the emitter.
	receiver.rotation_degrees = Vector3(0, 90, 0)
	add_child(receiver)


func _stand(at: Vector3) -> void:
	var height: float = at.y - 0.25
	add_child(PuzzleDeviceNode.static_box(Vector3(0.3, height, 0.3), Color(0.3, 0.32, 0.34), Vector3(at.x, height * 0.5, at.z)))


func _logic(id: StringName, kind: DeviceDefinition.Kind, sources: Array[StringName], at: Vector3, delay: float = 1.0) -> void:
	var logic: LogicDevice = LogicDevice.new()
	logic.name = String(id).replace(".", "_")
	logic.stable_id = id
	logic.kind = kind
	logic.inputs = sources
	logic.delay_seconds = delay
	logic.position = at
	add_child(logic)


func _cube(label: String, id: StringName, at: Vector3, kilograms: float) -> void:
	var body: CarryRigidBody = CarryRigidBody.new()
	body.name = label
	body.stable_id = id
	body.position = at
	body.mass = kilograms
	body.collision_layer = 2
	body.collision_mask = 7
	var shape: BoxShape3D = BoxShape3D.new()
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	body.add_child(PuzzleDeviceNode.box_mesh(Vector3.ONE, Color(0.86, 0.85, 0.82)))
	var sign: Label3D = Label3D.new()
	sign.text = "%.0f кг" % kilograms
	sign.position = Vector3(0, 0, 0.51)
	sign.pixel_size = 0.005
	sign.font_size = 48
	sign.modulate = Color(0.1, 0.1, 0.1)
	body.add_child(sign)
	add_child(body)


func _sign(text: String, at: Vector3, yaw_degrees: float = 0.0) -> void:
	var sign: Label3D = Label3D.new()
	sign.text = text
	sign.position = at
	sign.rotation_degrees = Vector3(0, yaw_degrees, 0)
	sign.pixel_size = 0.007
	sign.font_size = 36
	add_child(sign)
