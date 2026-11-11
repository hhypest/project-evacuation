extends SceneTree
## Verify actual imported Texture2D dimensions, not only the size_limit text in .import files.

const SETTINGS: DeviceTextureSettings = preload("res://content/definitions/device_texture_quality.tres")
const MODELS: Dictionary[String, String] = {"ballast_cube": "ballast_cube", "floor_button": "floor_button",
	"emitter": "emitter_body", "receiver": "receiver_body", "wall_button": "wall_button_body",
	"wall_switch": "wall_switch_body", "logic_box": "logic_box", "door": "door_leaf", "door_frame": "door_frame"}


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
	print("TEXTURE_QUALITY_%s profile=%s maps=27" % ["FAILED" if failed else "PASSED", SETTINGS.profile_label()])
	quit(1 if failed else 0)
