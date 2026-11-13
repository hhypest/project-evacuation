class_name RuntimeGameplaySmoke
extends Node
## Explicit --runtime-smoke diagnostics exercise the actual exported game pack through session input.
## Bootstrap creates this node only for that flag; normal play does not instantiate it.

var _main: SessionBootstrap
var _tree: SceneTree
var _checks: int = 0
var _finished: bool = false


func start(main: SessionBootstrap) -> void:
	_main = main
	_tree = main.get_tree()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_tree.create_timer(120.0, true, false, true).timeout.connect(_timeout)
	if "--self-test-failure" in OS.get_cmdline_user_args():
		_check(false, "intentional smoke failure")
		return
	if not _check(not OS.has_feature("editor"), "running an export template, not the editor"):
		return
	if not _check(not FileAccess.file_exists("res://tests/run_tests.gd"), "test suite excluded from game pack"):
		return
	if not _check(not ResourceLoader.exists("res://content/levels/foundation_lab.tscn")
			and not ResourceLoader.exists("res://content/levels/material_showcase.tscn")
			and not ResourceLoader.exists("res://content/materials/devices/cube_face.tres"),
			"editor fixtures and showcase materials excluded from game pack"):
		return
	if not _check(ResourceLoader.exists("res://content/levels/mechanics_lab.tscn")
			and ResourceLoader.exists("res://content/levels/reserve_circuit.tscn"),
			"both playable levels included in game pack"):
		return
	var main: SessionBootstrap = _main
	await _tree.process_frame
	if not _check(main.get_session_status().can_start and _tree.paused, "usable main menu"):
		return
	var journal: String = main.get_session_log_path()
	var log_text: String = FileAccess.get_file_as_string(journal)
	if not _check(journal.get_base_dir() == RuntimeLog.game_directory()
			and "SYSTEM_INFO" in log_text and "SESSION_READY" in log_text, "session log beside the executable contains startup diagnostics"):
		return
	printerr("RUNTIME_SMOKE_LOG_STREAM")
	if not _check("[STDERR] RUNTIME_SMOKE_LOG_STREAM" in FileAccess.get_file_as_string(journal),
			"the session log captures standard error"):
		return
	var profiler: RuntimeProfiler = main.get_node_or_null("RuntimeProfiler") as RuntimeProfiler
	var panel: ProfilerHud = main.get_node_or_null("ProfilerHud") as ProfilerHud
	if not _check(profiler != null and panel != null and not profiler.is_processing(), "release diagnostics are available but inactive without launch flags"):
		return
	_key(KEY_F3)
	if not _check(panel.panel_visible and profiler.is_processing() and _tree.paused, "release F3 opens diagnostics without changing pause"):
		return
	_key(KEY_F4)
	if not _check(profiler.recording, "release F4 starts CSV without launch flags"):
		return
	await _tree.process_frame
	_key(KEY_F4)
	if not _check(not profiler.recording and FileAccess.file_exists(profiler.report_path)
			and profiler.report_path.get_base_dir() == RuntimeLog.game_directory(), "release F4 flushes CSV beside the session log"):
		return
	DirAccess.remove_absolute(profiler.report_path)
	_key(KEY_F3)
	var hud: FoundationHud = main.get_node("FoundationHud") as FoundationHud
	hud.start_requested.emit()
	var scope: LevelScope = main.get_node("LevelScope") as LevelScope
	var lab: Node3D = scope.get_child(0) as Node3D
	var player: PlayerMotor = lab.get_node("Player") as PlayerMotor
	var camera: LookCamera = lab.get_node("Camera") as LookCamera
	var cube: CarryRigidBody = lab.get_node("TestCube") as CarryRigidBody
	player.position = Vector3(0, 0.05, 3)
	await _ticks(100)
	camera.look_at(cube.global_position)
	_key(KEY_E)
	_key(KEY_E, false)
	await _ticks(20)
	if not _check(cube.is_carried() and not scope.held_prop_id().is_empty(), "physical E acquires a cube"):
		return
	var at: Vector3 = player.position
	_key(KEY_W)
	await _ticks(12)
	_key(KEY_W, false)
	if not _check(player.position.distance_to(at) > 0.15 and cube.is_carried(), "movement while carrying"):
		return
	_mouse(MOUSE_BUTTON_LEFT)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _ticks(3)
	if not _check(scope.held_prop_id().is_empty() and cube.linear_velocity.length() > 1.0, "physical mouse throws once"):
		return
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE, false)
	at = player.position
	for frame: int in range(4):
		await _tree.process_frame
	if not _check(_tree.paused and player.position.is_equal_approx(at), "pause freezes physics"):
		return
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE, false)
	var plate: FloorButtonDevice = lab.get_node("Devices/qa_devices_plate") as FloorButtonDevice
	var door: DoorDevice = lab.get_node("Devices/qa_devices_door_plate") as DoorDevice
	cube.portal_place(Transform3D(Basis.IDENTITY, plate.global_position + Vector3(0, 0.7, 0)), Vector3.ZERO, Vector3.ZERO)
	await _ticks(100)
	if not _check(scope.puzzle().network.output(&"qa.devices.plate") and door.is_open(), "real load drives network and door"):
		return
	hud.menu_requested.emit()
	hud.level_requested.emit(0)
	scope = main.get_node("LevelScope") as LevelScope
	lab = scope.get_child(0) as Node3D
	player = lab.get_node("Player") as PlayerMotor
	camera = lab.get_node("Camera") as LookCamera
	cube = lab.get_node("Portals/Fixture/CubeA") as CarryRigidBody
	var pair: PortalPairDevice = lab.get_node("Portals/Fixture/portal_pair") as PortalPairDevice
	var a: PortalPlane = pair.state().a
	player.global_position = a.transform * Vector3(0, -1.15, 1.5)
	cube.portal_place(Transform3D(Basis.IDENTITY, a.transform * Vector3(0, -0.65, 0.75)), Vector3.ZERO, Vector3.ZERO)
	await _ticks(15)
	camera.look_at(cube.global_position)
	_key(KEY_E)
	_key(KEY_E, false)
	await _ticks(1)
	camera.global_basis = Basis.IDENTITY
	if not _check(cube.is_carried(), "portal lab carry ownership"):
		return
	_key(KEY_W)
	_key(KEY_SHIFT)
	var crossed: bool = false
	for tick: int in range(90):
		await _ticks(1)
		for transfer: PortalTransfer in scope.portals().transfers:
			crossed = crossed or (transfer.body_id == PortalWorldAdapter.PLAYER_ID and not transfer.blocked)
		if crossed:
			break
	_key(KEY_W, false)
	_key(KEY_SHIFT, false)
	if not _check(crossed and cube.is_carried() and pair.state().b.local(player.center()).z > 0.0,
			"player and held cube cross through the live coordinator"):
		return
	_mouse(MOUSE_BUTTON_LEFT)
	_mouse(MOUSE_BUTTON_LEFT, false)
	await _ticks(6)
	if not _check(scope.held_prop_id().is_empty() and cube.linear_velocity.dot(pair.surface_b.global_basis.z) > 1.0,
			"throw uses the exit frame"):
		return
	var generation: int = main.get_session_status().generation
	hud.restart_requested.emit()
	scope = main.get_node("LevelScope") as LevelScope
	lab = scope.get_child(0) as Node3D
	player = lab.get_node("Player") as PlayerMotor
	pair = lab.get_node("Portals/Fixture/portal_pair") as PortalPairDevice
	await _ticks(10)
	a = pair.state().a
	var b: PortalPlane = pair.state().b
	player.global_position = a.transform * Vector3(0, -1.2, 0.05)
	var wall: StaticBody3D = PuzzleDeviceNode.static_box(Vector3(1.6, 2.4, 0.3), Color.GRAY,
		a.transform * Vector3(0, 0, 0.7))
	lab.add_child(wall)
	wall = PuzzleDeviceNode.static_box(Vector3(1.6, 2.4, 0.3), Color.GRAY, b.transform * Vector3(0, 0, 0.25))
	wall.basis = b.transform.basis
	lab.add_child(wall)
	await _ticks(8)
	if not _check(main.get_session_status().generation == generation + 2 and main.get_session_status().accepts_gameplay
			and not is_instance_valid(scope), "unrecoverable portal geometry resets the complete chamber generation"):
		return
	log_text = FileAccess.get_file_as_string(journal)
	if not _check("CHAMBER_RECOVERY body=@portal.player level=res://content/levels/mechanics_lab.tscn generation=" in log_text,
			"portal recovery records body, level and generation in the session log"):
		return
	hud.menu_requested.emit()
	hud.level_requested.emit(1)
	scope = main.get_node_or_null("LevelScope") as LevelScope
	var reserve: ReserveChamberBuilder = scope.get_child(0) as ReserveChamberBuilder if scope != null else null
	if not _check(main.get_session_status().accepts_gameplay and reserve != null
			and reserve.has_node("CheckpointTerminal"), "Reserve Circuit opens from the exported menu"):
		return
	_finished = true
	print("EXPORTED_GAMEPLAY_SMOKE_PASSED checks=%d Godot=%s CPU_ONLY" % [_checks, Engine.get_version_info()["string"]])
	_tree.quit(0)


func _ticks(count: int) -> void:
	for tick: int in range(count):
		await _tree.physics_frame
		OS.delay_usec(1000)


func _key(code: Key, pressed: bool = true) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse(button: MouseButton, pressed: bool = true) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check(passed: bool, label: String) -> bool:
	_checks += 1
	print("EXPORTED_SMOKE_%s %s" % ["PASS" if passed else "FAIL", label])
	if not passed:
		_finished = true
		_tree.quit(1)
	return passed


func _timeout() -> void:
	if not _finished:
		printerr("EXPORTED_GAMEPLAY_SMOKE_TIMEOUT")
		_tree.quit(3)
