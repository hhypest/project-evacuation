class_name ReleaseRouteTests
extends TestSuite

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")
var _tree: SceneTree
var _main: SessionBootstrap
var _hud: FoundationHud
var _save_path: String
var _scope: LevelScope
var _player: PlayerMotor
var _camera: LookCamera
var _results: Array[TestOutcome] = []


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	_tree = tree
	_save_path = ProjectSettings.globalize_path("res://work/release-route-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	await _open_app()
	await _oxygen()
	await _qualification()
	await _close_app()
	for file: String in DirAccess.get_files_at(_save_path):
		DirAccess.remove_absolute(_save_path.path_join(file))
	DirAccess.remove_absolute(_save_path)
	return _results


func _open_app() -> void:
	_main = MAIN.instantiate() as SessionBootstrap
	_main.save_repository = JsonSaveRepository.new(_save_path)
	_tree.root.add_child(_main)
	await _tree.process_frame
	_hud = _main.get_node("FoundationHud") as FoundationHud


func _close_app() -> void:
	_tree.root.remove_child(_main)
	_main.queue_free()
	await _tree.process_frame


func _bind() -> bool:
	_scope = _main.get_node_or_null("LevelScope") as LevelScope
	if _scope == null:
		return false
	var stage: Node = _scope.get_child(0)
	_player = stage.get_node("Player") as PlayerMotor
	_camera = stage.get_node("Camera") as LookCamera
	return _main.get_session_status().accepts_gameplay


func _oxygen() -> void:
	_hud.level_requested.emit(2)
	await _ticks(15)
	if not _record("oxygen level starts from the menu", _bind() and _scope.oxygen_training() != null):
		return
	var training: OxygenTrainingBuilder = _scope.oxygen_training()
	await _go(Vector3(0, 0, -7.5))
	var generation: int = _main.get_session_status().generation
	if not _record("crossing the marked breach consumes oxygen", training.exposed and training.reserve.percentage() < 100):
		_hud.menu_requested.emit()
		return
	_hud.pause_requested.emit()
	var remaining: float = training.reserve.remaining_seconds
	await _ticks(20)
	_record("pausing in the breach freezes oxygen", training.reserve.remaining_seconds == remaining)
	_hud.pause_requested.emit()
	await _ticks(730)
	if not _record("first oxygen failure returns to entry with a full reserve", _bind()
			and _main.get_session_status().generation == generation + 1 and _player.position.z > 2.5
			and _scope.oxygen_training().reserve.percentage() == 100):
		_hud.menu_requested.emit()
		return
	await _go(Vector3(1.7, 0, -3.0))
	await _interact(Vector3(1.7, 1.36, -4.55))
	var saved: SaveResult = _main.save_repository.read_checkpoint()
	_record("airlock terminal writes its authored checkpoint", saved.code == SaveResult.Code.OK
		and saved.snapshot.checkpoint_id == &"oxygen.airlock")
	var count: int = DirAccess.get_files_at(_save_path).size()
	await _go(Vector3(0, 0, -3.1))
	await _go(Vector3(0, 0, -8.1))
	generation = _main.get_session_status().generation
	await _ticks(730)
	if not _record("oxygen failure restores the saved airlock without a disk write", _bind()
			and _main.get_session_status().generation == generation + 1
			and _player.position.distance_to(Vector3(1.7, 0, -3.3)) < 0.15
			and DirAccess.get_files_at(_save_path).size() == count):
		_hud.menu_requested.emit()
		return
	# Walk around the terminal before heading through the breach.
	await _go(Vector3(0, 0, -3.3))
	await _go(Vector3(0, 0, -25.5), true)
	training = _scope.oxygen_training()
	_record("crossing without delay reaches supply and replenishes oxygen", training.supplied and training.reserve.percentage() == 100)
	await _go(Vector3(0, 0, -30.8))
	saved = _main.save_repository.read_checkpoint()
	_record("oxygen course records completion at its exit", saved.code == SaveResult.Code.OK
		and &"oxygen_training" in saved.snapshot.completed_levels)
	_hud.menu_requested.emit()


func _qualification() -> void:
	_hud.level_requested.emit(3)
	await _ticks(16)
	if not _record("qualification route starts from the menu", _bind()):
		return
	var oxygen: Label = _hud.get_node("OxygenStatus") as Label
	_record("the puzzle route has no oxygen HUD or drain", not oxygen.visible and _scope.oxygen_training() == null)
	if not await _power_route():
		return
	_record("qualification pass 1 starts at the entrance and reaches the exit", await _cross_route())
	var ballast: CarryRigidBody = _scope.get_node("QualificationRoute/Ballast") as CarryRigidBody
	var generation: int = _main.get_session_status().generation
	ballast.global_position.y = -20.0
	await _ticks(24)
	if not _record("lost ballast restores the qualification checkpoint with power on", _bind()
			and _main.get_session_status().generation == generation + 1 and _out(&"route.travel")):
		return
	_tap(KEY_R)
	await _ticks(16)
	if not _record("R restores the same route and clears power", _bind() and not _out(&"route.travel")
			and _player.position.z > 2.5):
		return
	if not await _power_route():
		return
	_record("qualification pass 2 reaches the exit after full reset", await _cross_route())
	await _close_app()
	await _open_app()
	_hud.load_checkpoint_requested.emit()
	await _ticks(16)
	if not _record("fresh session restores the checkpoint and traversal power", _bind()
			and _out(&"route.travel") and _out(&"route.field") and _out(&"route.portals")):
		return
	_record("qualification pass 3 reaches the exit after JSON load", await _cross_route())


func _power_route() -> bool:
	var stage: Node = _scope.get_child(0)
	var ballast: CarryRigidBody = stage.get_node("Ballast") as CarryRigidBody
	var primary: FloorButtonDevice = stage.get_node("route_plate") as FloorButtonDevice
	await _go(Vector3(-1.6, 0, 1.8))
	await _interact(ballast.global_position)
	var held: bool = ballast.is_carried()
	await _go(Vector3(-1.6, 0, -1.10))
	await _interact(primary.plate.top_center(Vector3.UP))
	await _ticks(45)
	if not _record("ballast powers plate, emitter and receiver", held and not ballast.is_carried()
			and _out(&"route.plate") and _out(&"route.beam") and _out(&"route.receiver")):
		return false
	await _go(Vector3(0.1, 0, -6.0))
	await _interact(Vector3(1.65, 1.33, -6.81))
	await _ticks(36)
	if not _record("the receiver and timed button jointly open the door", _out(&"route.authorized") and _out(&"route.door")):
		return false
	await _go(Vector3(0, 0, -11.4), true)
	await _go(Vector3(-1.35, 0, -11.55))
	await _interact(Vector3(-2, 1.34, -12.72))
	await _go(Vector3(1.75, 0, -11.45))
	await _interact(Vector3(1.75, 1.35, -13.05))
	var saved: SaveResult = _main.save_repository.read_checkpoint()
	return _record("traversal switch powers field and portal and can be saved", _out(&"route.travel")
		and _out(&"route.field") and _out(&"route.portals") and saved.code == SaveResult.Code.OK
		and saved.snapshot.checkpoint_id == &"route.traversal")


func _cross_route() -> bool:
	var exit_zone: Area3D = _scope.get_node("QualificationRoute/Exit") as Area3D
	await _go(Vector3(0, 0, -15.2))
	await _go(Vector3(0, 0, -20.0))
	if not _record("the player takes support on the gravity wall", _player.up_direction.dot(Vector3.RIGHT) > 0.99
			and _player.has_floor_support()):
		return false
	await _go(Vector3(-3.4, _player.position.y, -36.0))
	await _go(Vector3(0, 0, -36.6))
	await _go(Vector3(0, 0, -49.9), true)
	var crossed: bool = _scope.portals().crossing_count > 0
	var saved: SaveResult = _main.save_repository.read_checkpoint()
	return crossed and not exit_zone.monitoring and _player.position.z < -49.0 and saved.code == SaveResult.Code.OK \
		and &"qualification_route" in saved.snapshot.completed_levels


func _go(target: Vector3, sprint: bool = false) -> void:
	var heading: Vector3 = (target - _player.position).slide(_player.up_direction)
	if heading.length() < 0.12:
		return
	var direction: Vector3 = heading.normalized()
	_camera.look_at(_camera.global_position + direction, _player.up_direction)
	TestInputEvents.key(KEY_W)
	if sprint:
		TestInputEvents.key(KEY_SHIFT)
	for tick: int in range(360):
		if not is_instance_valid(_player) or (target - _player.position).dot(direction) < 0.20:
			break
		await _tree.physics_frame
	TestInputEvents.key(KEY_W, false)
	if sprint:
		TestInputEvents.key(KEY_SHIFT, false)
	await _ticks(13)


func _interact(target: Vector3) -> void:
	_camera.look_at(target, _player.up_direction)
	await _ticks(6)
	_tap(KEY_E)
	await _ticks(13)


func _out(id: StringName) -> bool:
	return _scope.puzzle().network.output(id)


func _ticks(count: int) -> void:
	for tick: int in range(count):
		await _tree.physics_frame


func _tap(code: Key) -> void:
	TestInputEvents.key(code)
	TestInputEvents.key(code, false)


func _record(label: String, success: bool) -> bool:
	var detail: String = "player %s" % str(_player.position) if is_instance_valid(_player) else ""
	_results.append(TestOutcome.new(label, success, detail))
	return success
