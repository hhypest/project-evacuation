class_name ChamberBuilder
extends Node3D
## Shared primitives for code-built chambers: walls, devices, cubes, signs and lamps. Every device gets
## its stable ID and a node name derived from it, so tests and the gpu smoke can find it.

const WALL_COLOR: Color = Color(0.2, 0.23, 0.26)
const FLOOR_COLOR: Color = Color(0.13, 0.16, 0.19)


static func node_name(id: StringName) -> String:
	return String(id).replace(".", "_")


func _box(size: Vector3, at: Vector3, color: Color = WALL_COLOR, label: String = "") -> StaticBody3D:
	var body: StaticBody3D = PuzzleDeviceNode.static_box(size, color, at)
	if not label.is_empty():
		body.name = label
	add_child(body)
	return body


func _lamp(at: Vector3, reach: float = 10.0, energy: float = 1.4) -> void:
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = at
	lamp.omni_range = reach
	lamp.light_energy = energy
	lamp.light_color = Color(0.9, 0.93, 1.0)
	add_child(lamp)


func _plate(id: StringName, at: Vector3, press: float, release: float, turn: Vector3 = Vector3.ZERO) -> FloorButtonDevice:
	var plate: FloorButtonDevice = FloorButtonDevice.new()
	plate.name = node_name(id)
	plate.rotation_degrees = turn
	plate.stable_id = id
	plate.press_threshold_kg = press
	plate.release_threshold_kg = release
	plate.position = at
	add_child(plate)
	return plate


func _button(id: StringName, at: Vector3, mode: DeviceDefinition.WallMode, hold: float, caption: String = "",
		yaw_degrees: float = 0.0) -> WallButtonDevice:
	var button: WallButtonDevice = WallButtonDevice.new()
	button.name = node_name(id)
	button.rotation_degrees = Vector3(0, yaw_degrees, 0)
	button.stable_id = id
	button.mode = mode
	button.hold_seconds = hold
	button.caption = caption
	button.position = at
	add_child(button)
	return button


func _door(id: StringName, at: Vector3, sources: Array[StringName], yaw_degrees: float = 0.0) -> DoorDevice:
	var door: DoorDevice = DoorDevice.new()
	door.name = node_name(id)
	door.rotation_degrees = Vector3(0, yaw_degrees, 0)
	door.stable_id = id
	door.inputs = sources
	door.position = at
	add_child(door)
	return door


func _emitter(id: StringName, at: Vector3, sources: Array[StringName], yaw_degrees: float = 90.0) -> EmitterDevice:
	_stand(at)
	var emitter: EmitterDevice = EmitterDevice.new()
	emitter.name = node_name(id)
	emitter.stable_id = id
	emitter.inputs = sources
	emitter.range_m = 20.0
	emitter.position = at
	# Local -Z is the beam; yaw 90 fires toward -X.
	emitter.rotation_degrees = Vector3(0, yaw_degrees, 0)
	add_child(emitter)
	return emitter


func _receiver(id: StringName, at: Vector3, yaw_degrees: float = 90.0) -> ReceiverDevice:
	_stand(at)
	var receiver: ReceiverDevice = ReceiverDevice.new()
	receiver.name = node_name(id)
	receiver.stable_id = id
	receiver.position = at
	# Local +Z is the front; yaw 90 faces +X.
	receiver.rotation_degrees = Vector3(0, yaw_degrees, 0)
	add_child(receiver)
	return receiver


func _stand(at: Vector3) -> void:
	var height: float = at.y - 0.25
	add_child(PuzzleDeviceNode.static_box(Vector3(0.3, height, 0.3), Color(0.3, 0.32, 0.34), Vector3(at.x, height * 0.5, at.z)))


func _logic(id: StringName, kind: DeviceDefinition.Kind, sources: Array[StringName], at: Vector3, delay: float = 1.0,
		yaw_degrees: float = 0.0, initial: bool = false) -> LogicDevice:
	var logic: LogicDevice = LogicDevice.new()
	logic.name = node_name(id)
	logic.rotation_degrees = Vector3(0, yaw_degrees, 0)
	logic.initial = initial
	logic.stable_id = id
	logic.kind = kind
	logic.inputs = sources
	logic.delay_seconds = delay
	logic.position = at
	add_child(logic)
	return logic


func _cube(label: String, id: StringName, at: Vector3, kilograms: float, edge: float = 1.0) -> CarryRigidBody:
	var body: CarryRigidBody = CarryRigidBody.new()
	body.name = label
	body.stable_id = id
	body.position = at
	body.mass = kilograms
	body.collision_layer = 2
	body.collision_mask = 7
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3.ONE * edge
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = shape
	body.add_child(collision)
	body.add_child(PuzzleDeviceNode.box_mesh(Vector3.ONE * edge, Color(0.86, 0.85, 0.82)))
	var sign: Label3D = Label3D.new()
	sign.text = "%.0f кг" % kilograms
	sign.position = Vector3(0, 0, edge * 0.5 + 0.01)
	sign.pixel_size = 0.005
	sign.font_size = 48
	sign.modulate = Color(0.1, 0.1, 0.1)
	body.add_child(sign)
	add_child(body)
	return body


func _sign(text: String, at: Vector3, yaw_degrees: float = 0.0) -> void:
	var sign: Label3D = Label3D.new()
	sign.text = text
	sign.position = at
	sign.rotation_degrees = Vector3(0, yaw_degrees, 0)
	sign.pixel_size = 0.007
	sign.font_size = 36
	add_child(sign)


## Directional field; "down" is local -Y, so roll -90 pulls toward -X and +90 toward +X.
func _field(id: StringName, at: Vector3, size: Vector3, roll_degrees: float, sources: Array[StringName],
		strength: float = 9.8) -> GravityFieldDevice:
	var field: GravityFieldDevice = GravityFieldDevice.new()
	field.name = node_name(id)
	field.stable_id = id
	field.inputs = sources
	field.size = size
	field.strength = strength
	field.position = at
	field.rotation_degrees = Vector3(0, 0, roll_degrees)
	add_child(field)
	return field


## Room envelope along -Z: floor, side walls and end caps between z_front (> z_back).
func _corridor(half_width: float, z_front: float, z_back: float, height: float) -> void:
	var length: float = z_front - z_back
	var middle: float = (z_front + z_back) * 0.5
	_box(Vector3(half_width * 2.0, 1.0, length), Vector3(0, -0.5, middle), FLOOR_COLOR, "Floor")
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.3, height, length), Vector3(side * (half_width + 0.15), height * 0.5, middle))
	for z: float in [z_front + 0.15, z_back - 0.15]:
		_box(Vector3(half_width * 2.0 + 0.6, height, 0.3), Vector3(0, height * 0.5, z))


## Wall across the corridor at z with a door centred at door_x; the gap above the door frame is closed.
func _partition(half_width: float, z: float, height: float, door_x: float, door_id: StringName,
		sources: Array[StringName]) -> DoorDevice:
	var left: float = door_x - 1.3
	var right: float = door_x + 1.3
	if left > -half_width:
		_box(Vector3(left + half_width, height, 0.3), Vector3((left - half_width) * 0.5, height * 0.5, z))
	if right < half_width:
		_box(Vector3(half_width - right, height, 0.3), Vector3((right + half_width) * 0.5, height * 0.5, z))
	_box(Vector3(2.6, height - 3.0, 0.3), Vector3(door_x, 3.0 + (height - 3.0) * 0.5, z))
	return _door(door_id, Vector3(door_x, 0, z), sources)
