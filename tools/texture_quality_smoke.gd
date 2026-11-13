extends SceneTree
## Verify actual imported Texture2D dimensions, not only the size_limit text in .import files.

const SETTINGS: DeviceTextureSettings = preload("res://content/definitions/device_texture_quality.tres")
const MODELS: Dictionary[String, String] = {"ballast_cube": "ballast_cube", "floor_button": "floor_button",
	"emitter": "emitter_body", "receiver": "receiver_body", "wall_button": "wall_button_body",
	"wall_switch": "wall_switch_body", "logic_box": "logic_box", "door": "door_leaf", "door_frame": "door_frame"}
const FINISH_ATLASES: Array[Texture2D] = [
	PropVisuals.BALLAST_NORMAL, PropVisuals.BALLAST_ORM,
	FloorButtonDevice.GRIP_COLOR, FloorButtonDevice.GRIP_NORMAL, FloorButtonDevice.GRIP_ORM,
	WallButtonDevice.BUTTON_NORMAL, WallButtonDevice.BUTTON_ORM,
]


func _initialize() -> void:
	var failed: bool = false
	for model: String in MODELS:
		var stem: String = MODELS[model]
		for map: String in ["base_color", "normal", "metallic_roughness"]:
			var jpeg_normal: bool = model in ["ballast_cube", "wall_button", "wall_switch", "logic_box"]
			var extension: String = "png" if map == "normal" and not jpeg_normal else "jpg"
			var path: String = "res://content/models/devices/%s/%s_%s.%s" % [model, stem, map, extension]
			var texture: Texture2D = ResourceLoader.load(path) as Texture2D
			var expected: int = 2048 if map == "metallic_roughness" or SETTINGS.max_size == 2048 else 4096
			if texture == null or texture.get_width() != expected or texture.get_height() != expected:
				failed = true
				printerr("TEXTURE_QUALITY_FAILED %s expected=%d" % [path, expected])
			else:
				print("TEXTURE_SIZE %s %dx%d" % [path, texture.get_width(), texture.get_height()])
	var side: int = 2048 if SETTINGS.max_size == 2048 else 4096
	for albedo: Texture2D in [PropVisuals.LIGHT_ALBEDO, PropVisuals.HEAVY_ALBEDO]:
		if albedo.get_width() != side or albedo.get_height() != side:
			failed = true
			printerr("TEXTURE_QUALITY_FAILED %s expected=%d" % [albedo.resource_path, side])
		else:
			print("TEXTURE_SIZE %s %dx%d" % [albedo.resource_path, side, side])
	for texture: Texture2D in FINISH_ATLASES:
		if texture.get_width() != 2048 or texture.get_height() != 2048:
			failed = true
			printerr("TEXTURE_QUALITY_FAILED %s expected=2048" % texture.resource_path)
		else:
			print("TEXTURE_SIZE %s 2048x2048" % texture.resource_path)
	print("TEXTURE_QUALITY_%s profile=%s maps=%d" % ["FAILED" if failed else "PASSED",
		SETTINGS.profile_label(), MODELS.size() * 3 + 2 + FINISH_ATLASES.size()])
	quit(1 if failed else 0)
