extends SceneTree
## Снимает кадры демонстрационных сцен материалов на текущем рендерере (нужен Vulkan, не headless):
##   godot --path . --rendering-driver vulkan --script tools/art/render_showcase.gd
## Кадры пишутся в work/showcase-*.png (папка не коммитится).

const OUTPUT_DIR: String = "res://work"
const WARMUP_FRAMES: int = 30
const SCENES: Array[String] = [
	"res://content/levels/material_showcase.tscn",
	"res://content/levels/vitrine_showcase.tscn",
]
const VIEWS: Array[Dictionary] = [
	{"scene": 0, "name": "overview", "from": Vector3(0.0, 3.2, 10.5), "to": Vector3(0.0, 1.6, -2.0)},
	{"scene": 0, "name": "alien-left", "from": Vector3(-6.4, 1.9, 1.6), "to": Vector3(-6.4, 1.4, -4.0)},
	{"scene": 0, "name": "portal", "from": Vector3(5.4, 1.9, 3.0), "to": Vector3(7.0, 1.5, -3.0)},
	{"scene": 0, "name": "floor-devices", "from": Vector3(-2.2, 1.5, 3.4), "to": Vector3(-2.2, 0.3, -0.2)},
	{"scene": 0, "name": "models-closeup", "from": Vector3(-4.3, 1.05, 2.3), "to": Vector3(-4.3, 0.2, -0.2)},
	{"scene": 0, "name": "models-cube", "from": Vector3(-4.55, 0.75, 1.75), "to": Vector3(-5.0, 0.3, 0.9)},
	{"scene": 0, "name": "beam-gravity", "from": Vector3(1.6, 1.4, 3.2), "to": Vector3(1.6, 0.5, -0.4)},
	{"scene": 0, "name": "wall", "from": Vector3(1.2, 2.2, 0.8), "to": Vector3(1.2, 1.9, -4.0)},
	{"scene": 0, "name": "suit-catwalk", "from": Vector3(-6.4, 2.0, 3.2), "to": Vector3(-8.3, 1.2, 0.2)},
	{"scene": 1, "name": "vitrine-hevs", "from": Vector3(9.0, 2.6, 11.0), "to": Vector3(0.0, 1.8, 0.0)},
	{"scene": 1, "name": "vitrine-star", "from": Vector3(9.0, 1.4, -8.0), "to": Vector3(-6.0, 3.2, 60.0)},
	{"scene": 1, "name": "vitrine-livery", "from": Vector3(-1.2, 1.9, 4.2), "to": Vector3(-1.2, 1.8, 0.0)},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("SHOWCASE_RENDER_FAILED: нужен оконный режим с Vulkan")
		quit(2)
		return
	root.size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var current_index: int = -1
	var scene: Node = null
	for view: Dictionary in VIEWS:
		var scene_index: int = view["scene"]
		if scene_index != current_index:
			if scene != null:
				scene.queue_free()
				await process_frame
			var resource: Resource = load(SCENES[scene_index])
			if resource is not PackedScene:
				printerr("SHOWCASE_RENDER_FAILED: нет сцены %s" % SCENES[scene_index])
				quit(1)
				return
			var packed: PackedScene = resource
			scene = packed.instantiate()
			root.add_child(scene)
			current_index = scene_index
		var camera: Camera3D = root.get_camera_3d()
		if camera == null:
			printerr("SHOWCASE_RENDER_FAILED: в сцене нет камеры")
			quit(1)
			return
		var from: Vector3 = view["from"]
		var to: Vector3 = view["to"]
		camera.look_at_from_position(from, to)
		for frame: int in WARMUP_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var path: String = "%s/showcase-%s.png" % [OUTPUT_DIR, str(view["name"])]
		if image == null or image.is_empty() or image.save_png(path) != OK:
			printerr("SHOWCASE_RENDER_FAILED: не удалось сохранить %s" % path)
			quit(1)
			return
		print("SHOWCASE_FRAME %s" % path)
	print("SHOWCASE_RENDERED driver=%s gpu=%s" % [RenderingServer.get_current_rendering_driver_name(),
		RenderingServer.get_video_adapter_name()])
	quit(0)
