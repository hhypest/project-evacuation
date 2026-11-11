class_name DeviceTextureSettings
extends Resource
## Build/import profile for concept devices and door art. The import tool updates this with .import files.

@export_enum("Source:0", "2K:2048") var max_size: int = 0


func profile_label() -> String:
	return "2K" if max_size == 2048 else "source (4K/2K)"
