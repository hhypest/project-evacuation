class_name ScopeTests
extends TestSuite

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")


func suite_name() -> StringName:
	return &"regression"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var main: Node = MAIN.instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var first_lab: Node3D = main.get_node_or_null("FoundationLab") as Node3D
	var hud: FoundationHud = main.get_node("FoundationHud") as FoundationHud
	if first_lab == null or hud == null:
		main.queue_free()
		return [TestOutcome.new("bootstrap creates a lab and HUD", false)]
	var first_cube: RigidBody3D = first_lab.get_node("TestCube") as RigidBody3D
	if first_cube == null:
		main.queue_free()
		return [TestOutcome.new("bootstrap creates physics props", false)]
	for tick: int in range(30):
		await tree.physics_frame
	hud.pause_requested.emit()
	var paused_y: float = first_cube.position.y
	for frame: int in range(8):
		await tree.process_frame
	var stopped: bool = tree.paused and is_equal_approx(first_cube.position.y, paused_y)
	hud.restart_requested.emit()
	await tree.process_frame
	var next_lab: Node3D = main.get_node_or_null("FoundationLab") as Node3D
	var replaced: bool = next_lab != null and not is_instance_valid(first_lab) and not tree.paused
	var fresh: bool = false
	if next_lab != null:
		var next_cube: RigidBody3D = next_lab.get_node("TestCube") as RigidBody3D
		fresh = next_cube != null and next_cube.position.y > 2.5
	tree.paused = false
	tree.root.remove_child(main)
	main.queue_free()
	await tree.process_frame
	return [
		TestOutcome.new("pause freezes physical simulation while HUD stays active", stopped),
		TestOutcome.new("restart removes paused scope and restores a fresh cube", replaced and fresh),
	]
