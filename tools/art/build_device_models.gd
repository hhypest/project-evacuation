extends SceneTree
## Собирает сцены устройств из процедурных моделей (tools/art/models/build_device_models.py):
##   content/models/devices/utility_cube.tscn, content/models/devices/floor_button.tscn
## Поверхность модели называется «<группа>__<ассет>» и получает материал
## content/materials/<группа>/<ассет>.tres. Сцены — только визуальная часть: коллизии и правила
## устройств остаются в игровом коде (SKL-03/SKL-04).
## Запуск после импорта моделей:
##   godot --headless --path . --script tools/art/build_device_models.gd

const MODEL_DIR: String = "res://content/models/devices"
const MATERIAL_ROOT: String = "res://content/materials"
const MANIFEST_PATH: String = "res://content/models/devices/models_manifest.json"


func _initialize() -> void:
	var rest_offset: float = _read_rest_offset()
	if rest_offset < 0.0:
		quit(1)
		return
	var cube: Node3D = Node3D.new()
	cube.name = "UtilityCube"
	if not _add_model(cube, "utility_cube", "Body", Vector3.ZERO):
		quit(1)
		return
	if not _save(cube, MODEL_DIR + "/utility_cube.tscn"):
		quit(1)
		return
	var button: Node3D = Node3D.new()
	button.name = "FloorButton"
	if not _add_model(button, "floor_button_base", "Base", Vector3.ZERO):
		quit(1)
		return
	# Плита в покое; при нажатии Presentation опускает узел Plate на travel_m из манифеста.
	if not _add_model(button, "floor_button_plate", "Plate", Vector3(0.0, rest_offset, 0.0)):
		quit(1)
		return
	if not _save(button, MODEL_DIR + "/floor_button.tscn"):
		quit(1)
		return
	print("DEVICE_MODELS_BUILT 2")
	quit(0)


func _read_rest_offset() -> float:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is not Dictionary:
		push_error("Нет манифеста моделей: %s" % MANIFEST_PATH)
		return -1.0
	var manifest: Dictionary = parsed
	var models_value: Variant = manifest.get("models")
	if models_value is not Array:
		push_error("В манифесте моделей нет списка models")
		return -1.0
	var models: Array = models_value
	for entry_value: Variant in models:
		if entry_value is not Dictionary:
			continue
		var entry: Dictionary = entry_value
		var offset_value: Variant = entry.get("rest_offset_m")
		if str(entry.get("name")) == "floor_button_plate" and offset_value is float:
			# Тип проверен выше: присваивание Variant в float безопасно.
			var offset: float = offset_value
			return offset
	push_error("В манифесте нет rest_offset_m для floor_button_plate")
	return -1.0


func _add_model(parent: Node3D, model: String, node_name: String, position: Vector3) -> bool:
	var path: String = "%s/%s.obj" % [MODEL_DIR, model]
	var resource: Resource = load(path)
	if resource is not ArrayMesh:
		push_error("Модель не импортирована: %s" % path)
		return false
	var mesh: ArrayMesh = resource
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	for surface: int in mesh.get_surface_count():
		var material: Material = _material_for(mesh.surface_get_name(surface))
		if material == null:
			return false
		instance.set_surface_override_material(surface, material)
	parent.add_child(instance)
	instance.owner = parent
	return true


func _material_for(surface_name: String) -> Material:
	var parts: PackedStringArray = surface_name.split("__")
	if parts.size() != 2:
		push_error("Имя поверхности должно быть «группа__ассет»: %s" % surface_name)
		return null
	var path: String = "%s/%s/%s.tres" % [MATERIAL_ROOT, parts[0], parts[1]]
	var resource: Resource = load(path) if ResourceLoader.exists(path) else null
	if resource is not Material:
		push_error("Нет материала %s для поверхности %s" % [path, surface_name])
		return null
	var material: Material = resource
	return material


func _save(root: Node3D, path: String) -> bool:
	var packed: PackedScene = PackedScene.new()
	var error: Error = packed.pack(root)
	root.free()
	if error != OK or ResourceSaver.save(packed, path) != OK:
		push_error("Не удалось сохранить %s" % path)
		return false
	print("DEVICE_MODEL_SCENE %s" % path)
	return true
