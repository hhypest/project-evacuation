class_name ComfortSessionTests
extends TestSuite

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")


func suite_name() -> StringName:
	return &"regression"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var path: String = ProjectSettings.globalize_path("res://work/camera-test-%d-%d.cfg" % [
		OS.get_process_id(), Time.get_ticks_usec()
	])
	var main: SessionBootstrap = MAIN.instantiate() as SessionBootstrap
	tree.root.add_child(main)
	await tree.process_frame
	var camera_button: Button = main.find_child("CameraButton") as Button
	var start: Button = main.find_child("StartButton") as Button
	camera_button.pressed.emit()
	var fov: HSlider = main.find_child("Fov") as HSlider
	var sensitivity: HSlider = main.find_child("Sensitivity") as HSlider
	var rate: HSlider = main.find_child("GravityRate") as HSlider
	var hint: CheckButton = main.find_child("ShowHint") as CheckButton
	var done: Button = main.find_child("CameraDone") as Button
	results.append(TestOutcome.new("camera options focus the FOV slider and hide the menu buttons",
		fov.visible and fov.has_focus() and not start.is_visible_in_tree()))
	fov.value = 78.0
	sensitivity.value = 145.0
	rate.value = 120.0
	hint.button_pressed = false
	done.pressed.emit()
	start.pressed.emit()
	await tree.process_frame
	var camera: LookCamera = main.get_node("LevelScope/MechanicsLab/Camera") as LookCamera
	var game_hint: Label = main.find_child("GameHint") as Label
	results.append(TestOutcome.new("the selected preferences apply to the live camera and hide the gameplay hint",
		is_equal_approx(camera.fov, 78.0) and is_equal_approx(camera.radians_per_pixel, 0.003625)
		and is_equal_approx(camera.align_degrees_per_second, 120.0) and not game_hint.visible))

	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	camera_button.pressed.emit()
	fov.value = 74.0
	TestInputEvents.key(KEY_ESCAPE)
	TestInputEvents.key(KEY_ESCAPE, false)
	var paused: bool = tree.paused and not fov.is_visible_in_tree() and is_equal_approx(camera.fov, 74.0)
	results.append(TestOutcome.new("Escape applies camera options and returns to pause before resuming", paused))

	var wrote: bool = CameraPreferenceFile.save(main.camera_preferences, path) == OK
	var reread: CameraPreferences = CameraPreferences.new()
	CameraPreferenceFile.load_into(reread, path)
	results.append(TestOutcome.new("camera preferences round-trip outside the checkpoint JSON",
		wrote and is_equal_approx(reread.fov, 74.0) and is_equal_approx(reread.sensitivity, 145.0)
		and is_equal_approx(reread.gravity_rate, 120.0) and not reread.show_hint))
	var file: ConfigFile = ConfigFile.new()
	file.set_value("camera", "fov", 1000.0)
	file.set_value("camera", "sensitivity", "wrong type")
	file.set_value("camera", "gravity_rate", -10.0)
	var fixture_written: bool = file.save(path) == OK
	reread = CameraPreferences.new()
	CameraPreferenceFile.load_into(reread, path)
	results.append(TestOutcome.new("camera settings clamp out-of-range numbers and ignore a wrong value type",
		fixture_written and reread.fov == CameraPreferences.FOV_MAX
		and reread.sensitivity == 100.0 and reread.gravity_rate == CameraPreferences.ALIGN_MIN))
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	TestInputEvents.key(KEY_R)
	TestInputEvents.key(KEY_R, false)
	await tree.process_frame
	camera = main.get_node("LevelScope/MechanicsLab/Camera") as LookCamera
	results.append(TestOutcome.new("restarting a chamber keeps camera preferences",
		is_equal_approx(camera.fov, 74.0) and is_equal_approx(camera.align_degrees_per_second, 120.0)
		and main.get_session_status().generation == 2))
	tree.root.remove_child(main)
	main.queue_free()
	await tree.process_frame
	return results
