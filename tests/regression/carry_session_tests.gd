class_name CarrySessionTests
extends TestSuite

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")


func suite_name() -> StringName:
	return &"regression"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var main: SessionBootstrap = MAIN.instantiate() as SessionBootstrap
	tree.root.add_child(main)
	await tree.process_frame
	TestInputEvents.key(KEY_ENTER)
	TestInputEvents.key(KEY_ENTER, false)
	var scope: LevelScope = main.get_node("LevelScope") as LevelScope
	var player: PlayerMotor = scope.get_node("MechanicsLab/Player") as PlayerMotor
	var camera: LookCamera = scope.get_node("MechanicsLab/Camera") as LookCamera
	var cube: CarryRigidBody = scope.get_node("MechanicsLab/TestCube") as CarryRigidBody
	player.position = Vector3(0, 0.05, 3)
	for _tick: int in range(100):
		await tree.physics_frame
	camera.look_at(cube.global_position)
	TestInputEvents.key(KEY_E)
	TestInputEvents.key(KEY_E, false)
	for _tick: int in range(70):
		await tree.physics_frame
	results.append(TestOutcome.new("physical E binding acquires a cube through the live session",
		scope.held_prop_id() == &"lab.cube.medium" and cube.is_carried()))
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	var paused_at: Vector3 = cube.position
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT)
	for _frame: int in range(5):
		await tree.process_frame
	results.append(TestOutcome.new("pause preserves carry ownership and freezes the physical body",
		tree.paused and scope.held_prop_id() == &"lab.cube.medium" and cube.position.is_equal_approx(paused_at)))
	tree.root.focus_exited.emit()
	tree.root.focus_entered.emit()
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	for _tick: int in range(8):
		await tree.physics_frame
	results.append(TestOutcome.new("focus return and resume never replay the paused mouse throw",
		not tree.paused and scope.held_prop_id() == &"lab.cube.medium" and cube.is_carried()))
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT, false)
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT)
	for _tick: int in range(3):
		await tree.physics_frame
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT, false)
	results.append(TestOutcome.new("fresh physical mouse click throws and releases through Application",
		scope.held_prop_id().is_empty() and not cube.is_carried() and cube.linear_velocity.length() > 2))
	TestInputEvents.key(KEY_R)
	TestInputEvents.key(KEY_R, false)
	scope = main.get_node("LevelScope") as LevelScope
	player = scope.get_node("MechanicsLab/Player") as PlayerMotor
	camera = scope.get_node("MechanicsLab/Camera") as LookCamera
	cube = scope.get_node("MechanicsLab/TestCube") as CarryRigidBody
	player.position = Vector3(0, 0.05, 3)
	for _tick: int in range(100):
		await tree.physics_frame
	camera.look_at(cube.global_position)
	TestInputEvents.key(KEY_E)
	TestInputEvents.key(KEY_E, false)
	for _tick: int in range(50):
		await tree.physics_frame
	var had_held_cube: bool = cube.is_carried()
	TestInputEvents.key(KEY_R)
	TestInputEvents.key(KEY_R, false)
	var replacement: LevelScope = main.get_node("LevelScope") as LevelScope
	results.append(TestOutcome.new("restart while carrying closes old ownership and creates a clean generation",
		had_held_cube and not scope.is_inside_tree() and not cube.is_carried()
		and replacement.held_prop_id().is_empty() and main.get_session_status().generation == 3))
	tree.root.remove_child(main)
	main.queue_free()
	await tree.process_frame
	return results
