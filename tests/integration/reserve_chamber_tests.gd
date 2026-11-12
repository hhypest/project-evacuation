class_name ReserveChamberTests
extends TestSuite
## A complete, repeatable run from the real menu using input, physical contacts and both portal directions.

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")

var _tree: SceneTree
var _main: SessionBootstrap
var _scope: LevelScope
var _level: ReserveChamberBuilder
var _player: PlayerMotor
var _camera: LookCamera
var _results: Array[TestOutcome] = []


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	_main = MAIN.instantiate() as SessionBootstrap
	tree.root.add_child(_main)
	await tree.process_frame
	var button: Button = _main.find_child("LevelButton1", true, false) as Button
	var selectable: bool = button != null and button.visible and not button.disabled
	if selectable:
		button.pressed.emit()
	await _ticks(28)
	if not _bind():
		_record("second menu entry opens the reserve chamber", false)
		await _close()
		return _results
	_record("second menu entry opens the reserve chamber", selectable)
	_record("the chamber starts unpowered with the optical interlock shut",
		not _out(&"reserve.portal") and _out(&"reserve.receiver") and not _out(&"reserve.service_door"))
	await _go(Vector3(-3, 0, -6.2))
	await _go(Vector3(-3, 0, -11.0), true, 110)
	_record("the unpowered aperture ends at the seal", _player.position.z > -10.0 and not _level.completed)

	var ballast: CarryRigidBody = _level.get_node("Ballast") as CarryRigidBody
	var primary: FloorButtonDevice = _level.get_node("reserve_primary") as FloorButtonDevice
	await _go(Vector3(3.5, 0, 1.9))
	await _pick(ballast)
	var picked: bool = ballast.is_carried()
	await _go(Vector3(3.5, 0, -3.25))
	await _place(primary.plate)
	_record("the original ballast powers the portal after placement", picked and _out(&"reserve.primary")
		and _out(&"reserve.portal") and not ballast.is_carried())
	await _go(Vector3(-3, 0, -6.2))
	await _go(Vector3(-3, 0, -13.7))
	_record("the live portal reaches the optics room without moving the ballast",
		_player.position.z < -12.0 and _player.position.x > 2.5 and ballast.position.z > -8.0)
	if _player.position.z >= -12.0:
		await _close()
		return _results

	await _go(Vector3(0, 0, -19.0))
	await _ticks(18)
	var can_interrupt: bool = not _out(&"reserve.receiver") and _out(&"reserve.service_door")
	await _go(Vector3(0, 0, -31.0), true, 160)
	_record("standing in the beam gives feedback but a sprint cannot beat the interlock",
		can_interrupt and _out(&"reserve.receiver") and _player.position.z > -29.0)

	var screen: CarryRigidBody = _level.get_node("ScreenCube") as CarryRigidBody
	await _go(Vector3(-3.5, 0, -17.85))
	await _pick(screen)
	var screen_picked: bool = screen.is_carried()
	var socket: CarrySocketBody = _level.get_node("ScreenSocket") as CarrySocketBody
	await _place(socket)
	var blocked: bool = not _out(&"reserve.receiver") and _out(&"reserve.service_door")
	await _go(Vector3(0, 0, -24.0))
	await _go(Vector3(0, 0, -31.25))
	_record("the screen cube holds the door open long enough to enter the service hall",
		screen_picked and blocked and _player.position.z < -30.0 and not screen.is_carried())
	if _player.position.z >= -30.0:
		await _close()
		return _results

	var backup: WallButtonDevice = _level.get_node("reserve_backup") as WallButtonDevice
	await _go(Vector3(-4.5, 0, -32.45))
	_aim(backup.global_position + Vector3(0, 0, 0.04))
	_tap(KEY_E)
	await _ticks(20)
	_record("the reserve switch powers the portal and keeps the service route open",
		_out(&"reserve.backup") and _out(&"reserve.service_access") and _out(&"reserve.portal"))

	await _go(Vector3(4.1, 0, -35.0))
	await _ticks(40)
	var momentary: bool = _out(&"reserve.exit_door")
	await _go(Vector3(0, 0, -48.5), true, 200)
	_record("standing on the exit plate cannot open a route to the exit by sprinting",
		momentary and _player.position.z > -47.0 and not _level.completed)

	await _go(Vector3(0, 0, -31.4))
	await _go(Vector3(0, 0, -26.5))
	await _go(Vector3(3, 0, -13.75))
	await _go(Vector3(3, 0, -6.5))
	var returned: bool = _player.position.z > -8.0 and _player.position.x < -2.5
	_record("returning through the blue portal reaches the original room", returned)
	if not returned:
		await _close()
		return _results
	await _go(Vector3(3.5, 0, -3.3))
	await _pick(ballast)
	await _ticks(14)
	var freed: bool = ballast.is_carried() and not _out(&"reserve.primary") and _out(&"reserve.portal")
	await _go(Vector3(-3, 0, -6.1))
	await _go(Vector3(-3, 0, -13.75))
	_record("the reserve lets the player carry the ballast through the portal after lifting it off the plate",
		freed and ballast.is_carried() and _player.position.z < -12.0 and ballast.position.z < -12.0)

	await _go(Vector3(0, 0, -26.0))
	await _go(Vector3(0, 0, -31.25))
	await _go(Vector3(4.1, 0, -33.2))
	var exit_plate: FloorButtonDevice = _level.get_node("reserve_exit_load") as FloorButtonDevice
	await _place(exit_plate.plate)
	var exit_ready: bool = _out(&"reserve.exit_load") and _out(&"reserve.exit_door")
	await _go(Vector3(0, 0, -43.0))
	await _go(Vector3(0, 0, -49.5))
	_record("the ballast holds the exit open and crossing the threshold completes the chamber",
		exit_ready and _level.completed and _player.position.z < -49.0)

	_tap(KEY_R)
	await _ticks(28)
	var reset: bool = _bind()
	_record("R restores the same chamber, both cubes, power and completion state",
		reset and _main.get_session_status().generation == 2 and not _level.completed
		and not _out(&"reserve.portal") and not _out(&"reserve.backup")
		and (_level.get_node("Ballast") as CarryRigidBody).position.distance_to(Vector3(3.5, 0.38, 0)) < 0.1
		and (_level.get_node("ScreenCube") as CarryRigidBody).position.distance_to(Vector3(-3.5, 0.38, -16.2)) < 0.1
		and _player.position.distance_to(Vector3(0, 0, 3)) < 0.1)
	await _close()
	return _results


func _bind() -> bool:
	_scope = _main.get_node_or_null("LevelScope") as LevelScope
	if _scope == null:
		return false
	_level = _scope.get_node_or_null("ReserveCircuit") as ReserveChamberBuilder
	if _level == null:
		return false
	_player = _level.get_node("Player") as PlayerMotor
	_camera = _level.get_node("Camera") as LookCamera
	return _main.get_session_status().accepts_gameplay


func _go(target: Vector3, sprint: bool = false, budget: int = 360) -> void:
	var heading: Vector3 = (target - _player.position).slide(Vector3.UP)
	if heading.length() < 0.09:
		return
	var direction: Vector3 = heading.normalized()
	_aim(_camera.global_position + direction)
	TestInputEvents.key(KEY_W)
	if sprint:
		TestInputEvents.key(KEY_SHIFT)
	for tick: int in range(budget):
		if (target - _player.position).dot(direction) < 0.24:
			break
		await _tree.physics_frame
	TestInputEvents.key(KEY_W, false)
	if sprint:
		TestInputEvents.key(KEY_SHIFT, false)
	await _ticks(16)


func _aim(target: Vector3) -> void:
	_camera.look_at(target, _player.up_direction)


func _pick(cube: CarryRigidBody) -> void:
	_aim(cube.global_position)
	_tap(KEY_E)
	await _ticks(15)


func _place(socket: CarrySocketBody) -> void:
	_aim(socket.top_center(Vector3.UP))
	await _ticks(6)
	_tap(KEY_E)
	await _ticks(50)


func _out(id: StringName) -> bool:
	return _scope.puzzle().network.output(id)


func _tap(code: Key) -> void:
	TestInputEvents.key(code)
	TestInputEvents.key(code, false)


func _ticks(count: int) -> void:
	for tick: int in range(count):
		await _tree.physics_frame


func _record(name: String, passed: bool) -> void:
	var detail: String = "" if not is_instance_valid(_player) else "player %s" % str(_player.position)
	_results.append(TestOutcome.new(name, passed, detail))


func _close() -> void:
	_tree.root.remove_child(_main)
	_main.queue_free()
	await _tree.process_frame
