extends SceneTree
## Собирает ORMMaterial3D из процедурных текстур (tools/art/generate_device_textures.py).
## Запуск из корня репозитория после импорта текстур:
##   godot --headless --path . --script tools/art/build_device_materials.gd
## Цвет свечения задаётся семантикой ADR-0006, а не текстурой: маска *_emission.png
## определяет только форму светящейся области.

const MANIFEST_PATH: String = "res://content/textures/textures_manifest.json"
const TEXTURE_ROOT: String = "res://content/textures"
const MATERIAL_ROOT: String = "res://content/materials"

const EMISSION_COLORS: Dictionary[String, Color] = {
	"cyan": Color("#38C8DC"),
	"amber": Color("#E8963C"),
	"gravity": Color("#8B4FC4"),
	"white": Color("#EAF2FF"),
	"screen": Color("#C9DCE0"),
	"alien": Color("#DCE6F2"),
}
const EMISSION_ENERGY: Dictionary[String, float] = {
	"cyan": 2.0,
	"amber": 1.6,
	"gravity": 1.8,
	"white": 1.2,
	"screen": 1.4,
	"alien": 0.6,
}
## BoxMesh раскладывает грани сеткой 3×2; одна текстура на все грани требует такого масштаба UV.
const BOX_FACE_UV_SCALE: Vector3 = Vector3(3.0, 2.0, 1.0)


func _initialize() -> void:
	var exit_code: int = _build()
	quit(exit_code)


func _build() -> int:
	var text: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	if text.is_empty():
		push_error("Нет манифеста текстур: %s" % MANIFEST_PATH)
		return 1
	var parsed: Variant = JSON.parse_string(text)
	if parsed is not Array:
		push_error("Манифест текстур должен быть массивом")
		return 1
	# JSON отдаёт Variant; тип проверен выше, присваивание в типизированную переменную безопасно.
	var entries: Array = parsed
	var built: int = 0
	for entry_value: Variant in entries:
		if entry_value is not Dictionary:
			push_error("Запись манифеста должна быть объектом")
			return 1
		var entry: Dictionary = entry_value
		var name_value: Variant = entry.get("name")
		var group_value: Variant = entry.get("group")
		if name_value is not String or group_value is not String:
			push_error("В записи манифеста нет name/group")
			return 1
		var emission_value: Variant = entry.get("emission")
		var emission: String = str(emission_value) if emission_value is String else ""
		if not emission.is_empty() and not EMISSION_COLORS.has(emission):
			push_error("Неизвестная семантика свечения: %s" % emission)
			return 1
		var kind_value: Variant = entry.get("kind")
		var kind: String = str(kind_value) if kind_value is String else "pbr"
		var alpha_value: Variant = entry.get("alpha")
		var alpha: bool = alpha_value is bool and alpha_value == true
		var error: Error = OK
		if kind == "panorama":
			error = _build_sky(str(name_value), str(group_value))
		elif kind == "pbr":
			error = _build_material(str(name_value), str(group_value), emission, alpha)
		else:
			push_error("Неизвестный вид ассета: %s" % kind)
			return 1
		if error != OK:
			return 1
		built += 1
	print("MATERIALS_BUILT %d" % built)
	return 0


func _build_material(asset_name: String, group: String, emission: String, alpha: bool) -> Error:
	var base: String = "%s/%s/%s/%s" % [TEXTURE_ROOT, group, asset_name, asset_name]
	var material: ORMMaterial3D = ORMMaterial3D.new()
	material.resource_name = asset_name
	var albedo: Texture2D = _load_texture(base + "_albedo.png")
	var normal: Texture2D = _load_texture(base + "_normal.png")
	var orm: Texture2D = _load_texture(base + "_orm.png")
	if albedo == null or normal == null or orm == null:
		return ERR_FILE_NOT_FOUND
	material.albedo_texture = albedo
	material.normal_enabled = true
	material.normal_texture = normal
	material.orm_texture = orm
	# ORM-канал R (ambient occlusion) учитывается только при включённом AO.
	material.ao_enabled = true
	if not emission.is_empty():
		var mask: Texture2D = _load_texture(base + "_emission.png")
		if mask == null:
			return ERR_FILE_NOT_FOUND
		material.emission_enabled = true
		material.emission = EMISSION_COLORS[emission]
		material.emission_energy_multiplier = EMISSION_ENERGY[emission]
		material.emission_texture = mask
		material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	if asset_name == "cube_face":
		material.uv1_scale = BOX_FACE_UV_SCALE
	if alpha:
		# Просветы решётки — жёсткий отрез без сортировки прозрачности; решётку видно с обеих сторон.
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _save(material, group, asset_name)


## Небо из равнопромежуточной панорамы: Sky с PanoramaSkyMaterial для WorldEnvironment и витрин.
func _build_sky(asset_name: String, group: String) -> Error:
	var texture: Texture2D = _load_texture("%s/%s/%s/%s_panorama.png" % [TEXTURE_ROOT, group, asset_name, asset_name])
	if texture == null:
		return ERR_FILE_NOT_FOUND
	var panorama: PanoramaSkyMaterial = PanoramaSkyMaterial.new()
	panorama.panorama = texture
	var sky: Sky = Sky.new()
	sky.resource_name = asset_name
	sky.sky_material = panorama
	return _save(sky, group, asset_name + "_sky")


func _save(resource: Resource, group: String, file_name: String) -> Error:
	var directory: String = "%s/%s" % [MATERIAL_ROOT, group]
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if dir_error != OK:
		push_error("Не удалось создать %s" % directory)
		return dir_error
	var path: String = "%s/%s.tres" % [directory, file_name]
	var save_error: Error = ResourceSaver.save(resource, path)
	if save_error != OK:
		push_error("Не удалось сохранить %s" % path)
	return save_error


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_error("Текстура не импортирована: %s" % path)
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource is not Texture2D:
		push_error("Ресурс не является текстурой: %s" % path)
		return null
	return resource as Texture2D
