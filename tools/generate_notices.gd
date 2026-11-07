extends SceneTree
## Engine boundary: preserve upstream license texts and copyright metadata verbatim.


func _initialize() -> void:
	var destination: String = "res://content/licenses"
	DirAccess.make_dir_recursive_absolute(destination)
	var godot_license: FileAccess = FileAccess.open(destination + "/GODOT_LICENSE.txt", FileAccess.WRITE)
	if godot_license == null:
		printerr("Cannot write Godot license")
		quit(1)
		return
	godot_license.store_string(Engine.get_license_text())
	godot_license.close()
	var metadata: FileAccess = FileAccess.open(destination + "/GODOT_COPYRIGHT.json", FileAccess.WRITE)
	if metadata == null:
		quit(1)
		return
	metadata.store_string(JSON.stringify(Engine.get_copyright_info(), "\t") + "\n")
	metadata.close()
	var bundled: FileAccess = FileAccess.open(destination + "/GODOT_THIRD_PARTY.txt", FileAccess.WRITE)
	if bundled == null:
		quit(1)
		return
	var license_info: Dictionary = Engine.get_license_info()
	var identifiers: Array[String] = []
	for raw_identifier: Variant in license_info:
		if raw_identifier is not String:
			quit(1)
			return
		identifiers.append(str(raw_identifier))
	identifiers.sort()
	for identifier: String in identifiers:
		var text: Variant = license_info[identifier]
		if text is not String:
			quit(1)
			return
		bundled.store_string("=== %s ===\n%s" % [identifier, text])
		if identifier != identifiers[-1]:
			bundled.store_string("\n\n")
	bundled.close()
	print("Preserved Godot license and %d third-party license texts." % identifiers.size())
	quit(0)
