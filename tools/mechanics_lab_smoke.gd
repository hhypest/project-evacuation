extends SceneTree
## Actual unified scene on Vulkan: overview of its geometry and first-person-scale views of every bay.

var _path: String = "res://work/mechanics-lab.png"
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--capture":
		_path = args[1]
	elif not args.is_empty():
		quit(2)
		return
	var runtime: RuntimeInfo = RuntimeProbe.new().read()
	if not ValidateRuntime.new().execute(runtime).is_empty():
		printerr("MECHANICS_LAB_SMOKE_FAILED Vulkan Forward+ required")
		quit(1)
		return
	root.size = Vector2i(1440, 1000)
	var scope: LevelScope = LevelScope.new()
	root.add_child(scope)
	if not scope.open(preload("res://content/levels/mechanics_lab.tscn"), 155):
		quit(1)
		return
	var level: Node3D = scope.get_child(0) as Node3D
	var camera: LookCamera = level.get_node("Camera") as LookCamera
	for tick: int in range(30):
		await physics_frame
		var frame: GameplayInputFrame = GameplayInputFrame.new()
		frame.generation = 155
		scope.apply_input(frame)
	await _capture("hub")
	# A geometry overview of this same loaded scene, with only its roofs hidden for inspection.
	var roofs: Array[MeshInstance3D] = []
	for node: Node in level.find_children("*Ceiling", "StaticBody3D", true, false):
		for child: Node in node.get_children():
			if child is MeshInstance3D:
				var roof: MeshInstance3D = child as MeshInstance3D
				roofs.append(roof)
				roof.visible = false
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 116
	camera.global_position = Vector3(45, 95, 5)
	camera.look_at(Vector3(0, 0, -47))
	await _capture("overview")
	for roof: MeshInstance3D in roofs:
		roof.visible = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 65
	var bays: Array[String] = ["Movement", "Carry", "Devices", "Optics", "Gravity", "Portals", "Lighting"]
	for name: String in bays:
		var bay: Node3D = level.get_node(name) as Node3D
		var side: float = (bay as MechanicsBayBuilder).entrance_side
		camera.global_position = bay.to_global(Vector3(side * 10, 1.65, 2))
		camera.look_at(bay.to_global(Vector3(0, 1.4, -3)))
		await _capture(name.to_lower())
	scope.close()
	await process_frame
	print("MECHANICS_LAB_SMOKE_%s driver=%s gpu=%s" % ["FAILED" if _failed else "PASSED",
		runtime.rendering_driver, RenderingServer.get_video_adapter_name()])
	quit(1 if _failed else 0)


func _capture(suffix: String) -> void:
	for frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.save_png(_path.get_basename() + "-" + suffix + ".png") != OK:
		_failed = true
		printerr("MECHANICS_LAB_SMOKE_FAILED capture " + suffix)
