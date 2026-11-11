class_name CheckpointSessionTests
extends TestSuite

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")
const PORTAL_LAB: PackedScene = preload("res://content/levels/portal_lab.tscn")


func suite_name() -> StringName:
	return &"regression"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var path: String = ProjectSettings.globalize_path("res://work/checkpoint-session-%d-%d" % [
		OS.get_process_id(), Time.get_ticks_usec()
	])
	var first: SessionBootstrap = MAIN.instantiate() as SessionBootstrap
	first.save_repository = JsonSaveRepository.new(path)
	tree.root.add_child(first)
	await tree.process_frame
	var start: Button = first.find_child("StartButton") as Button
	var continue_button: Button = first.find_child("LoadCheckpointButton") as Button
	results.append(TestOutcome.new("main menu offers continuation only when a valid checkpoint exists",
		continue_button != null and not continue_button.visible))
	start.pressed.emit()
	var level: Node3D = first.get_node_or_null("LevelScope/MechanicsLab") as Node3D
	var cube_at: Vector3 = Vector3.INF
	var player_at: Vector3 = Vector3.INF
	if level != null:
		var cube: CarryRigidBody = level.get_node("TestCube") as CarryRigidBody
		var player: PlayerMotor = level.get_node("Player") as PlayerMotor
		cube_at = cube.position
		player_at = player.position
		cube.position += Vector3.UP * 2.0
		player.position += Vector3.RIGHT
	var saved: SaveResult = first.save_repository.read_checkpoint()
	results.append(TestOutcome.new("starting from the menu records the entrance after the scope opens",
		level != null and saved.code == SaveResult.Code.OK and saved.snapshot.level_id == &"mechanics_lab"))
	tree.root.remove_child(first)
	first.queue_free()
	await tree.process_frame

	var reopened: SessionBootstrap = MAIN.instantiate() as SessionBootstrap
	reopened.save_repository = JsonSaveRepository.new(path)
	var earlier: LevelEntry = LevelEntry.new()
	earlier.level_id = &"portal_lab"
	earlier.title = "Порталы"
	earlier.scene = PORTAL_LAB
	var reordered: LevelCatalog = LevelCatalog.new()
	reordered.entries = [earlier, reopened.catalog.entry(0)]
	reopened.catalog = reordered
	reopened.chamber_scene = PORTAL_LAB
	tree.root.add_child(reopened)
	await tree.process_frame
	continue_button = reopened.find_child("LoadCheckpointButton") as Button
	var available: bool = continue_button.visible and not continue_button.disabled
	continue_button.pressed.emit()
	level = reopened.get_node_or_null("LevelScope/MechanicsLab") as Node3D
	var restored: bool = false
	if level != null:
		var cube: CarryRigidBody = level.get_node("TestCube") as CarryRigidBody
		var player: PlayerMotor = level.get_node("Player") as PlayerMotor
		restored = cube.position.is_equal_approx(cube_at) and player.position.is_equal_approx(player_at)
	results.append(TestOutcome.new("continuing from disk resolves the level by ID after reordering and restores authored poses",
		available and restored and reopened.get_session_status().accepts_gameplay
		and reopened.get_session_status().generation == 1))
	tree.root.remove_child(reopened)
	reopened.queue_free()
	await tree.process_frame
	for name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(name))
	DirAccess.remove_absolute(path)
	return results
