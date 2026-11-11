class_name ScopeTests
extends TestSuite

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")
const LAB: PackedScene = preload("res://content/levels/mechanics_lab.tscn")


func suite_name() -> StringName:
	return &"regression"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var original_connections: int = tree.root.focus_exited.get_connections().size()
	var main: SessionBootstrap = MAIN.instantiate() as SessionBootstrap
	if main == null:
		return [TestOutcome.new("typed session bootstrap", false)]
	tree.root.add_child(main)
	await tree.process_frame
	var hud: FoundationHud = main.get_node("FoundationHud") as FoundationHud
	var input: SessionInput = main.get_node("SessionInput") as SessionInput
	if hud == null or input == null:
		tree.root.remove_child(main)
		main.queue_free()
		return [TestOutcome.new("bootstrap creates HUD and input boundary", false)]
	results.append(TestOutcome.new("startup opens a menu without simulating a chamber",
		tree.paused and main.get_session_status().can_start
		and main.get_node_or_null("LevelScope") == null))
	TestInputEvents.key(KEY_ENTER)
	await tree.process_frame
	TestInputEvents.key(KEY_ENTER, false)
	var scope: LevelScope = main.get_node_or_null("LevelScope") as LevelScope
	if scope == null:
		tree.root.remove_child(main)
		main.queue_free()
		return results + [TestOutcome.new("keyboard menu starts a chamber", false)]
	var cube: RigidBody3D = scope.get_node("MechanicsLab/TestCube") as RigidBody3D
	var camera: LookCamera = scope.get_node("MechanicsLab/Camera") as LookCamera
	if cube == null or camera == null:
		tree.root.remove_child(main)
		main.queue_free()
		return results + [TestOutcome.new("chamber has cube and first-person camera", false)]
	var initial_cube_transform: Transform3D = cube.transform
	results.append(TestOutcome.new("keyboard menu starts a running first generation",
		main.get_session_status().accepts_gameplay and main.get_session_status().generation == 1))
	var before_look: Vector3 = camera.rotation
	TestInputEvents.motion(Vector2(1, 0))
	TestInputEvents.motion(Vector2(30, -8))
	for _tick: int in range(3):
		await tree.physics_frame
	results.append(TestOutcome.new("mouse input reaches first-person look on physics ticks",
		not camera.rotation.is_equal_approx(before_look)))
	var stale: GameplayInputFrame = GameplayInputFrame.new()
	stale.generation = 0
	stale.look_delta = Vector2(200, 200)
	var current_look: Vector3 = camera.rotation
	scope.apply_input(stale)
	results.append(TestOutcome.new("level scope rejects stale input generations",
		camera.rotation.is_equal_approx(current_look)))
	for _tick: int in range(20):
		await tree.physics_frame
	TestInputEvents.key(KEY_W)
	TestInputEvents.key(KEY_SPACE)
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	var paused_y: float = cube.position.y
	TestInputEvents.motion(Vector2(500, 500))
	for _frame: int in range(8):
		await tree.process_frame
	var paused_frame: GameplayInputFrame = input.take_frame()
	results.append(TestOutcome.new("pause freezes physics and clears held actions and look",
		tree.paused and is_equal_approx(cube.position.y, paused_y)
		and not Input.is_action_pressed(&"move_forward") and not Input.is_action_pressed(&"jump")
		and paused_frame.move_axis == Vector2.ZERO and paused_frame.look_delta == Vector2.ZERO))
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	TestInputEvents.key(KEY_W, true, true)
	results.append(TestOutcome.new("resume does not replay a held key or accumulated mouse motion",
		not tree.paused and input.take_frame().move_axis == Vector2.ZERO
		and camera.rotation.is_equal_approx(current_look)))
	TestInputEvents.key(KEY_W, false)
	TestInputEvents.key(KEY_SPACE, false)
	TestInputEvents.key(KEY_W)
	results.append(TestOutcome.new("fresh key works after pause release",
		input.take_frame().move_axis == Vector2(0, -1)))
	tree.root.focus_exited.emit()
	var lost_generation: int = main.get_session_status().generation
	TestInputEvents.key(KEY_R)
	TestInputEvents.key(KEY_R, false)
	results.append(TestOutcome.new("focus loss pauses, releases input and refuses restart",
		tree.paused and not main.get_session_status().focused
		and main.get_session_status().generation == lost_generation
		and not Input.is_action_pressed(&"move_forward")))
	tree.root.focus_entered.emit()
	results.append(TestOutcome.new("focus return leaves the chamber paused",
		tree.paused and main.get_session_status().can_resume))
	TestInputEvents.key(KEY_R)
	TestInputEvents.key(KEY_R, true, true)
	await tree.process_frame
	TestInputEvents.key(KEY_R, false)
	var next_scope: LevelScope = main.get_node_or_null("LevelScope") as LevelScope
	var fresh_cube: RigidBody3D = main.get_node_or_null("LevelScope/MechanicsLab/TestCube") as RigidBody3D
	results.append(TestOutcome.new("restart from pause replaces scope once despite key echo",
		not tree.paused and not is_instance_valid(scope) and next_scope != null
		and main.get_session_status().generation == lost_generation + 1
		and fresh_cube != null and fresh_cube.position.distance_to(initial_cube_transform.origin) < 0.1
		and input.take_frame().move_axis == Vector2.ZERO))
	TestInputEvents.key(KEY_W, false)
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	var menu_button: Button = hud.get_node("%MenuButton") as Button
	if menu_button != null:
		menu_button.pressed.emit()
	await tree.process_frame
	results.append(TestOutcome.new("return to main menu unloads the chamber and closes input",
		tree.paused and main.get_node_or_null("LevelScope") == null
		and main.get_session_status().can_start))
	hud.start_requested.emit()
	results.append(TestOutcome.new("starting again creates a new session generation",
		main.get_session_status().accepts_gameplay
		and main.get_session_status().generation == lost_generation + 2))
	main.chamber_scene = null
	hud.restart_requested.emit()
	results.append(TestOutcome.new("failed load returns to a usable menu with input closed",
		tree.paused and main.get_session_status().can_start
		and main.get_node_or_null("LevelScope") == null
		and not main.get_session_status().accepts_gameplay))
	main.chamber_scene = LAB
	hud.start_requested.emit()
	results.append(TestOutcome.new("session can recover after a failed load",
		main.get_session_status().accepts_gameplay and main.get_node_or_null("LevelScope") != null))
	tree.root.remove_child(main)
	main.queue_free()
	await tree.process_frame
	results.append(TestOutcome.new("teardown restores global pause/mouse and removes window subscriptions",
		not tree.paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		and tree.root.focus_exited.get_connections().size() == original_connections))
	return results
