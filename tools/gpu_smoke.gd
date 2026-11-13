extends SceneTree
## Real-display check of session, cursor capture, focus notifications and look.

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")
var _finished: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# The unified level includes all six bays and live portal views; allow cold software-Vulkan startup.
	create_timer(180.0, true, false, true).timeout.connect(_on_timeout)
	var info: RuntimeInfo = RuntimeProbe.new().read()
	if not _check(ValidateRuntime.new().execute(info).is_empty(), "real Vulkan runtime required"):
		return
	var capture: String = "res://work/gpu_smoke.png"
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--capture":
		capture = arguments[1]
	elif not arguments.is_empty():
		_check(false, "Expected --capture <absolute image path>")
		return
	var main: SessionBootstrap = MAIN.instantiate() as SessionBootstrap
	if not _check(main != null, "typed bootstrap"):
		return
	root.add_child(main)
	for _frame: int in range(120):
		if main.get_session_status().can_start:
			break
		await process_frame
	if not _check(main.get_session_status().can_start, "focused start menu"):
		return
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-menu.png"):
		return
	TestInputEvents.key(KEY_ENTER)
	TestInputEvents.key(KEY_ENTER, false)
	if not _check(main.get_session_status().accepts_gameplay and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		"start must capture the mouse"):
		return
	for _tick: int in range(150):
		await physics_frame
	var player: PlayerMotor = main.get_node("LevelScope/MechanicsLab/Player") as PlayerMotor
	if not _check(player != null, "physical player"):
		return
	var origin: Vector3 = player.position
	TestInputEvents.key(KEY_D)
	for _tick: int in range(30):
		await physics_frame
	TestInputEvents.key(KEY_D, false)
	for _tick: int in range(20):
		await physics_frame
	TestInputEvents.key(KEY_W)
	for _tick: int in range(30):
		await physics_frame
	TestInputEvents.key(KEY_SPACE)
	for _tick: int in range(6):
		await physics_frame
	TestInputEvents.key(KEY_SPACE, false)
	TestInputEvents.key(KEY_CTRL)
	for _tick: int in range(8):
		await physics_frame
	if not _check(player.position.x > origin.x + 2 and player.position.z < origin.z - 2
		and player.position.y > 0.7 and player.crouched, "keyboard movement, jump and duck jump"):
		return
	TestInputEvents.key(KEY_CTRL, false)
	TestInputEvents.key(KEY_W, false)
	for _tick: int in range(60):
		await physics_frame
	var camera: LookCamera = main.get_node("LevelScope/MechanicsLab/Camera") as LookCamera
	if not _check(camera != null, "first-person look camera"):
		return
	var before: Vector3 = camera.rotation
	TestInputEvents.motion(Vector2(1, 0))
	TestInputEvents.motion(Vector2(20, -5))
	for _tick: int in range(3):
		await physics_frame
	if not _check(not camera.rotation.is_equal_approx(before), "mouse look receives relative motion"):
		return
	TestInputEvents.key(KEY_W)
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	if not _check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		and not Input.is_action_pressed(&"move_forward"), "pause releases cursor and held input"):
		return
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-pause.png"):
		return
	var settings: Button = main.find_child("CameraButton") as Button
	var scale: OptionButton = main.find_child("UpscalingMode") as OptionButton
	var settings_done: Button = main.find_child("CameraDone") as Button
	settings.pressed.emit()
	if not _check(not scale.disabled and scale.visible and scale.selected == 0, "graphics settings default to native"):
		return
	scale.select(1)
	scale.item_selected.emit(1)
	if not _check(root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2
			and is_equal_approx(root.scaling_3d_scale, RenderScale.QUALITY_SCALE), "graphics menu applies FSR 2.2 Quality"):
		return
	settings_done.pressed.emit()
	root.focus_exited.emit()
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	if not _check(paused and not main.get_session_status().can_resume, "unfocused window refuses resume"):
		return
	root.focus_entered.emit()
	if not _check(paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "focus return never auto-captures"):
		return
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	if not _check(not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			and root.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2, "explicit resume recaptures and retains FSR"):
		return
	TestInputEvents.key(KEY_W, false)
	TestInputEvents.key(KEY_R)
	TestInputEvents.key(KEY_R, false)
	if not _check(main.get_session_status().generation == 2, "restart advances scope generation"):
		return
	for _tick: int in range(150):
		await physics_frame
	await RenderingServer.frame_post_draw
	var carry_scope: LevelScope = main.get_node("LevelScope") as LevelScope
	var carry_camera: LookCamera = carry_scope.get_node("MechanicsLab/Camera") as LookCamera
	var cube: CarryRigidBody = carry_scope.get_node("MechanicsLab/TestCube") as CarryRigidBody
	TestInputEvents.key(KEY_W)
	for _tick: int in range(30):
		await physics_frame
	TestInputEvents.key(KEY_W, false)
	for _tick: int in range(20):
		await physics_frame
	var to_cube: Vector3 = cube.global_position - carry_camera.global_position
	var pitch: float = atan2(to_cube.y, Vector2(to_cube.x, to_cube.z).length())
	TestInputEvents.motion(Vector2(1, 0))
	TestInputEvents.motion(Vector2(0, (carry_camera.rotation.x - pitch) / carry_camera.radians_per_pixel))
	for _tick: int in range(3):
		await physics_frame
	TestInputEvents.key(KEY_E)
	TestInputEvents.key(KEY_E, false)
	for _tick: int in range(75):
		await physics_frame
	if not _check(carry_scope.held_prop_id() == &"lab.cube.medium" and cube.is_carried(), "E acquires a real physical cube"):
		return
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-carry.png"):
		return
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT)
	for _tick: int in range(3):
		await physics_frame
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT, false)
	if not _check(carry_scope.held_prop_id().is_empty() and cube.linear_velocity.length() > 2, "mouse throws and releases cube"):
		return
	await RenderingServer.frame_post_draw
	if not _capture(capture):
		return
	# Devices (SKL-04/05): the fixture moves the player to the timed wall button, the press is a real E event.
	var lab: Node3D = carry_scope.get_node("MechanicsLab") as Node3D
	var button: WallButtonDevice = lab.get_node("Devices/qa_devices_timed") as WallButtonDevice
	var door: DoorDevice = lab.get_node("Devices/qa_devices_door_timed") as DoorDevice
	if not _check(button != null and door != null, "device lab with wall button and door"):
		return
	var lab_player: PlayerMotor = carry_scope.get_node("MechanicsLab/Player") as PlayerMotor
	var front: Vector3 = button.global_basis.z.normalized()
	lab_player.global_position = Vector3(button.global_position.x, 0.05, button.global_position.z) + front * 1.3
	for _tick: int in range(20):
		await physics_frame
	carry_camera.look_at(button.global_position + Vector3(0, -0.05, 0) + front * 0.05)
	TestInputEvents.key(KEY_E)
	TestInputEvents.key(KEY_E, false)
	for _tick: int in range(60):
		await physics_frame
	if not _check(door.is_open() and carry_scope.held_prop_id().is_empty(), "E on a wall button opens its door"):
		return
	carry_camera.look_at(door.global_position + Vector3(0, 1.3, 0))
	for _tick: int in range(3):
		await physics_frame
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-devices.png"):
		return
	# Beam (SKL-06): E on the toggle powers the emitter; the receiver must accept the traced beam.
	var beam_button: WallButtonDevice = lab.get_node("Optics/qa_optics_toggle") as WallButtonDevice
	var emitter: EmitterDevice = lab.get_node("Optics/qa_optics_emitter") as EmitterDevice
	var beam_door: DoorDevice = lab.get_node("Optics/qa_optics_door") as DoorDevice
	if not _check(beam_button != null and emitter != null and beam_door != null, "beam bay"):
		return
	var beam_front: Vector3 = beam_button.global_basis.z.normalized()
	lab_player.global_position = Vector3(beam_button.global_position.x, 0.05, beam_button.global_position.z) + beam_front * 1.3
	for _tick: int in range(20):
		await physics_frame
	carry_camera.look_at(beam_button.global_position + Vector3(0, -0.05, 0) + beam_front * 0.05)
	TestInputEvents.key(KEY_E)
	TestInputEvents.key(KEY_E, false)
	for _tick: int in range(90):
		await physics_frame
	if not _check(emitter.powered and beam_door.is_open(), "E on the beam toggle powers the emitter and the receiver opens its door"):
		return
	var beam_receiver: ReceiverDevice = lab.get_node("Optics/qa_optics_receiver") as ReceiverDevice
	carry_camera.look_at(beam_receiver.global_position + Vector3(0, 0.5, 0))
	for _tick: int in range(3):
		await physics_frame
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-beam.png"):
		return
	# Placement (ADR-0012): a held cube aimed at the floor button shows its silhouette; E sets it there,
	# and a second cube aimed at the first is set on top. Two 5 kg cubes press the 8 kg plate.
	var plate: FloorButtonDevice = lab.get_node("Devices/qa_devices_plate") as FloorButtonDevice
	var cube_a: CarryRigidBody = lab.get_node("Devices/PlateCubeA") as CarryRigidBody
	var cube_b: CarryRigidBody = lab.get_node("Devices/PlateCubeB") as CarryRigidBody
	var ghost: CarryGhost = carry_scope.get_node("MechanicsLab/CarryGhost") as CarryGhost
	var plate_door: DoorDevice = lab.get_node("Devices/qa_devices_door_plate") as DoorDevice
	if not _check(plate != null and cube_a != null and cube_b != null and ghost != null and plate_door != null,
			"placement bay"):
		return
	var plate_top: Vector3 = plate.plate.top_center(Vector3.UP)
	for pair: Array[Node3D] in [[cube_a, plate] as Array[Node3D], [cube_b, cube_a] as Array[Node3D]]:
		var prop: CarryRigidBody = pair[0] as CarryRigidBody
		lab_player.global_position = Vector3(prop.global_position.x, 0.05, prop.global_position.z) + Vector3(0, 0, 1.6)
		for _tick: int in range(20):
			await physics_frame
		carry_camera.look_at(prop.global_position)
		TestInputEvents.key(KEY_E)
		TestInputEvents.key(KEY_E, false)
		for _tick: int in range(10):
			await physics_frame
		var target: Vector3 = plate_top if pair[1] == plate else cube_a.global_position + Vector3.UP * (BallastCube.LIGHT_EDGE * 0.5)
		lab_player.global_position = Vector3(plate_top.x, 0.05, plate_top.z) + Vector3(0.8, 0, 1.8)
		for _tick: int in range(10):
			await physics_frame
		carry_camera.look_at(target)
		for _tick: int in range(6):
			await physics_frame
		carry_camera.look_at(target)
		for _tick: int in range(3):
			await physics_frame
		if not _check(carry_scope.held_prop_id() == prop.stable_id and ghost.visible, "held cube shows its placement silhouette"):
			return
		await RenderingServer.frame_post_draw
		if not _capture(capture.get_basename() + ("-place-plate.png" if pair[1] == plate else "-place-stack.png")):
			return
		TestInputEvents.key(KEY_E)
		TestInputEvents.key(KEY_E, false)
		for _tick: int in range(60):
			await physics_frame
	var on_top: Vector3 = cube_b.global_position - cube_a.global_position
	if not _check(on_top.slide(Vector3.UP).length() < 0.03 and absf(on_top.y - BallastCube.LIGHT_EDGE) < 0.03
			and (cube_a.global_position - plate_top).slide(Vector3.UP).length() < 0.03 and plate_door.is_open()
			and not ghost.visible, "E sets the cubes square on the plate and on each other; the plate opens its door"):
		return
	# Gravity (SKL-07): E powers the wall field; the player stepping in turns and stands on the wall.
	var gravity_button: WallButtonDevice = lab.get_node("Gravity/qa_gravity_toggle") as WallButtonDevice
	var field: GravityFieldDevice = lab.get_node("Gravity/qa_gravity_field") as GravityFieldDevice
	if not _check(gravity_button != null and field != null, "gravity bay"):
		return
	var gravity_front: Vector3 = gravity_button.global_basis.z.normalized()
	lab_player.global_position = Vector3(gravity_button.global_position.x, 0.05, gravity_button.global_position.z) + gravity_front * 1.3
	for _tick: int in range(20):
		await physics_frame
	carry_camera.look_at(gravity_button.global_position + Vector3(0, -0.05, 0) + gravity_front * 0.05)
	TestInputEvents.key(KEY_E)
	TestInputEvents.key(KEY_E, false)
	for _tick: int in range(5):
		await physics_frame
	var down: Vector3 = field.zone().direction
	var along: Vector3 = field.global_basis.z.normalized()
	var entry: Vector3 = field.global_position + down * 1.2 - along * 2.0
	lab_player.global_position = Vector3(entry.x, 0.05, entry.z)
	for _tick: int in range(100):
		await physics_frame
	if not _check(field.powered and lab_player.up_direction.distance_to(-down) < 0.001 and lab_player.is_on_floor(),
			"powered field turns the player onto the wall"):
		return
	carry_camera.look_at(carry_camera.global_position + along * 2.0 - down * 0.6, lab_player.up_direction)
	for _tick: int in range(3):
		await physics_frame
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-gravity.png"):
		return
	_finished = true
	print("GPU_SMOKE_PASSED driver=%s gpu=%s carry=grab/hold/throw/place devices=button/door/beam gravity=field/wall-walk movement=strafe/run/jump/duck session=menu/pause/focus/restart/quit image=%s" % [
		info.rendering_driver, RenderingServer.get_video_adapter_name(), capture
	])
	# Exercise the same close signal used by the window manager; Bootstrap owns cleanup.
	root.close_requested.emit()


func _capture(path: String) -> bool:
	var image: Image = root.get_texture().get_image()
	return _check(image != null and not image.is_empty() and image.save_png(path) == OK,
		"save Vulkan frame " + path)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("GPU_SMOKE_FAILED: " + message)
		_finished = true
		quit(1)
	else:
		print("GPU_SMOKE_PASS: " + message)
	return condition


func _on_timeout() -> void:
	if not _finished:
		printerr("GPU_SMOKE_TIMEOUT")
		quit(3)
