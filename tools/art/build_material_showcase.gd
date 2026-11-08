extends SceneTree
## Собирает демонстрационные сцены материалов:
##   content/levels/material_showcase.tscn — интерьер: человеческий и чужой слой, скафандр;
##   content/levels/vitrine_showcase.tscn — снаружи: небо терминатора, грунт, макет HEVS-02.
## Сцена служит для художественной проверки (читаемость состояний, свет, масштаб)
## и не входит в игровой маршрут. Запуск из корня репозитория:
##   godot --headless --path . --script tools/art/build_material_showcase.gd

const SCENE_PATH: String = "res://content/levels/material_showcase.tscn"
const VITRINE_PATH: String = "res://content/levels/vitrine_showcase.tscn"
const CAMP_PATH: String = "res://content/levels/camp_showcase.tscn"
const DEVICES: String = "res://content/materials/devices/"
const SURFACES: String = "res://content/materials/surfaces/"
const ALIEN: String = "res://content/materials/alien/"
const SUIT: String = "res://content/materials/suit/"
const VEHICLE: String = "res://content/materials/vehicle/"
const PLANET: String = "res://content/materials/planet/"
const CAMP: String = "res://content/materials/camp/"
const SEGMENTS: int = 40
const CYAN: Color = Color("#38C8DC")
const GRAVITY: Color = Color("#8B4FC4")

var _root: Node3D


class BoxFace:
	var normal: Vector3
	var points: Array[Vector3]
	var size: Vector2

	func _init(face_normal: Vector3, face_points: Array[Vector3], face_size: Vector2) -> void:
		normal = face_normal
		points = face_points
		size = face_size

var _failed: bool = false


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "MaterialShowcase"
	_build_environment()
	_build_room()
	_build_device_row(-1.2, true)
	_build_device_row(0.9, false)
	_build_wall_devices()
	_build_alien_features()
	_build_catwalk_and_suit()
	_build_swatches()
	_build_camera(Vector3(0.0, 3.2, 10.5), Vector3(0.0, 1.6, -2.0))
	if not _save_scene(SCENE_PATH):
		quit(1)
		return
	_root = Node3D.new()
	_root.name = "VitrineShowcase"
	_build_vitrine()
	if not _save_scene(VITRINE_PATH):
		quit(1)
		return
	_root = Node3D.new()
	_root.name = "CampShowcase"
	_build_camp()
	if not _save_scene(CAMP_PATH):
		quit(1)
		return
	quit(0)


func _save_scene(path: String) -> bool:
	if _failed:
		_root.free()
		return false
	_assign_owner(_root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(_root)
	_root.free()
	if pack_error != OK:
		push_error("Не удалось упаковать сцену %s" % path)
		return false
	var save_error: Error = ResourceSaver.save(packed, path)
	if save_error != OK:
		push_error("Не удалось сохранить %s" % path)
		return false
	print("SHOWCASE_BUILT %s" % path)
	return true


# --------------------------------------------------------------------------- материалы

func _material(path: String) -> Material:
	if not ResourceLoader.exists(path):
		push_error("Нет материала: %s" % path)
		_failed = true
		return StandardMaterial3D.new()
	var resource: Resource = load(path)
	if resource is not Material:
		push_error("Не материал: %s" % path)
		_failed = true
		return StandardMaterial3D.new()
	var material: Material = resource
	return material


func _optional_material(path: String, fallback: Color) -> Material:
	if ResourceLoader.exists(path):
		return _material(path)
	var placeholder: StandardMaterial3D = StandardMaterial3D.new()
	placeholder.albedo_color = fallback
	placeholder.roughness = 0.8
	return placeholder


## Состояние «выключено»: копия материала без свечения. Цвет и маска не меняются.
func _off(material: Material) -> Material:
	if material is not BaseMaterial3D:
		return material
	var base: BaseMaterial3D = material
	var copy: BaseMaterial3D = base.duplicate()
	copy.emission_energy_multiplier = 0.0
	return copy


func _glow(color: Color, alpha: float, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


# --------------------------------------------------------------------------- геометрия

## Квадрат: углы a — левый верх, b — правый верх, c — правый низ, d — левый низ (вид снаружи).
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, uv_size: Vector2) -> void:
	var uvs: Array[Vector2] = [Vector2.ZERO, Vector2(uv_size.x, 0.0), uv_size, Vector2(0.0, uv_size.y)]
	var points: Array[Vector3] = [a, b, c, d]
	for index: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[index])
		st.add_vertex(points[index])


## Ящик: передняя грань (+Z) — материал front, остальные — side.
## tile_per_meter (повторов на метр по U и V) повторяет текстуру по размеру грани; ноль — каждая грань 0..1.
func _box(size: Vector3, front: Material, side: Material, tile_per_meter: Vector2 = Vector2.ZERO, front_only_uv: bool = false) -> ArrayMesh:
	var h: Vector3 = size * 0.5
	var mesh: ArrayMesh = ArrayMesh.new()
	var faces: Array[BoxFace] = [
		BoxFace.new(Vector3.BACK, [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)], Vector2(size.x, size.y)),
		BoxFace.new(Vector3.FORWARD, [Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z)], Vector2(size.x, size.y)),
		BoxFace.new(Vector3.RIGHT, [Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)], Vector2(size.z, size.y)),
		BoxFace.new(Vector3.LEFT, [Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z)], Vector2(size.z, size.y)),
		BoxFace.new(Vector3.UP, [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)], Vector2(size.x, size.z)),
		BoxFace.new(Vector3.DOWN, [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z)], Vector2(size.x, size.z)),
	]
	for surface: int in 2:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face_index: int in faces.size():
			if (face_index == 0) != (surface == 0):
				continue
			var face: BoxFace = faces[face_index]
			var uv_size: Vector2 = Vector2.ONE
			if tile_per_meter != Vector2.ZERO and not (front_only_uv and face_index == 0):
				uv_size = face.size * tile_per_meter
			_quad(st, face.points[0], face.points[1], face.points[2], face.points[3], face.normal, uv_size)
		st.generate_tangents()
		st.commit(mesh)
		mesh.surface_set_material(surface, front if surface == 0 else side)
	return mesh


## Цилиндр вдоль локальной Y: боковая поверхность — side (U по окружности, V сверху вниз),
## торцы — cap с планарной развёрткой диска. u_repeat повторяет боковую текстуру по окружности.
func _cylinder(radius: float, height: float, side: Material, cap: Material, u_repeat: float = 1.0,
		v_repeat: float = 1.0, swap_uv: bool = false) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var half: float = height * 0.5
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in SEGMENTS:
		var t0: float = TAU * float(i) / float(SEGMENTS)
		var t1: float = TAU * float(i + 1) / float(SEGMENTS)
		var n0: Vector3 = Vector3(cos(t0), 0.0, sin(t0))
		var n1: Vector3 = Vector3(cos(t1), 0.0, sin(t1))
		var u0: float = (1.0 - float(i) / float(SEGMENTS)) * u_repeat
		var u1: float = (1.0 - float(i + 1) / float(SEGMENTS)) * u_repeat
		var verts: Array[Vector3] = [n1 * radius + Vector3.UP * half, n0 * radius + Vector3.UP * half,
			n0 * radius + Vector3.DOWN * half, n1 * radius + Vector3.DOWN * half]
		var normals: Array[Vector3] = [n1, n0, n0, n1]
		var uvs: Array[Vector2] = [Vector2(u1, 0.0), Vector2(u0, 0.0), Vector2(u0, v_repeat), Vector2(u1, v_repeat)]
		for index: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(normals[index])
			var uv: Vector2 = uvs[index]
			st.set_uv(Vector2(uv.y, uv.x) if swap_uv else uv)
			st.add_vertex(verts[index])
	st.generate_tangents()
	st.commit(mesh)
	mesh.surface_set_material(0, side)
	var caps: SurfaceTool = SurfaceTool.new()
	caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	for top: bool in [true, false]:
		var y: float = half if top else -half
		var normal: Vector3 = Vector3.UP if top else Vector3.DOWN
		for i: int in SEGMENTS:
			var t0: float = TAU * float(i) / float(SEGMENTS)
			var t1: float = TAU * float(i + 1) / float(SEGMENTS)
			var p0: Vector3 = Vector3(cos(t0) * radius, y, sin(t0) * radius)
			var p1: Vector3 = Vector3(cos(t1) * radius, y, sin(t1) * radius)
			var centre: Vector3 = Vector3(0.0, y, 0.0)
			var tri: Array[Vector3] = [centre, p0, p1]
			if not top:
				tri = [centre, p1, p0]
			for point: Vector3 in tri:
				caps.set_normal(normal)
				var flip: float = 1.0 if top else -1.0
				caps.set_uv(Vector2(0.5 + point.x / (2.0 * radius), 0.5 + flip * point.z / (2.0 * radius)))
				caps.add_vertex(point)
	caps.generate_tangents()
	caps.commit(mesh)
	mesh.surface_set_material(1, cap)
	return mesh


func _instance(mesh: Mesh, node_name: String, position: Vector3, rotation_deg: Vector3 = Vector3.ZERO,
		parent: Node3D = null) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation_degrees = rotation_deg
	(parent if parent != null else _root).add_child(instance)
	return instance


func _label(text: String, position: Vector3, size: int = 40) -> void:
	var label: Label3D = Label3D.new()
	label.name = "Label_%s" % text.validate_node_name()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.004
	label.position = position
	label.modulate = Color(0.85, 0.83, 0.78)
	label.outline_size = 8
	_root.add_child(label)


# --------------------------------------------------------------------------- сцена

func _build_environment() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0D0F10")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#4A5A66")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.05
	environment.ssao_enabled = true
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	_root.add_child(world)
	var work: OmniLight3D = OmniLight3D.new()
	work.name = "WarmWorkLight"
	work.light_color = Color(1.0, 0.82, 0.62)
	work.light_energy = 3.0
	work.omni_range = 14.0
	work.shadow_enabled = true
	work.position = Vector3(-2.5, 3.6, 3.0)
	_root.add_child(work)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.name = "ColdFill"
	fill.light_color = Color(0.62, 0.72, 0.86)
	fill.light_energy = 0.45
	fill.shadow_enabled = true
	fill.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_root.add_child(fill)


func _build_room() -> void:
	var basalt: Material = _material(ALIEN + "basalt_wall.tres")
	var alien_floor: Material = _material(ALIEN + "basalt_floor.tres")
	var plate: Material = _material(SURFACES + "diamond_plate.tres")
	var hazard: Material = _material(SURFACES + "hazard_stripes.tres")
	var dark: Material = _material(SURFACES + "metal_dark.tres")
	_instance(_box(Vector3(20.0, 0.4, 14.0), alien_floor, alien_floor, Vector2(0.5, 0.5)), "AlienFloor", Vector3(0.0, -0.25, -1.0))
	_instance(_box(Vector3(20.0, 7.0, 0.6), basalt, basalt, Vector2(0.5, 0.5)), "AlienWall", Vector3(0.0, 3.0, -4.3))
	_instance(_box(Vector3(13.0, 0.1, 4.8), plate, dark, Vector2(1.0, 1.0)), "HumanPlatform", Vector3(0.0, 0.0, -0.2))
	_instance(_box(Vector3(13.0, 0.12, 0.2), hazard, hazard, Vector2(2.0, 2.0)), "PlatformEdge", Vector3(0.0, 0.01, 2.3))
	_label("ВКЛ — сигнал активен", Vector3(-5.9, 0.9, -1.2), 30)
	_label("ВЫКЛ", Vector3(-5.9, 0.9, 0.9), 30)


func _build_device_row(z: float, active: bool) -> void:
	var state: String = "On" if active else "Off"
	var dark: Material = _material(SURFACES + "metal_dark.tres")
	var hazard: Material = _material(SURFACES + "hazard_stripes.tres")
	var panel: Material = _material(SURFACES + "panel_light.tres")
	# куб 0,5 м — штатный BoxMesh блокаута, материал задаёт uv1_scale 3×2
	var cube_material: Material = _material(DEVICES + "cube_face.tres")
	var cube_mesh: BoxMesh = BoxMesh.new()
	cube_mesh.size = Vector3(0.5, 0.5, 0.5)
	cube_mesh.material = cube_material if active else _off(cube_material)
	_instance(cube_mesh, "Cube" + state, Vector3(-5.0, 0.3, z), Vector3(0.0, 25.0, 0.0))
	# напольная кнопка: юбка + плита; во включённом состоянии плита утоплена
	var top: Material = _material(DEVICES + "floor_button_top.tres")
	_instance(_cylinder(0.52, 0.1, hazard, dark, 6.0, 0.1), "FloorButtonSkirt" + state, Vector3(-3.3, 0.1, z))
	var plate_y: float = 0.15 if active else 0.19
	_instance(_cylinder(0.48, 0.06, dark, top if active else _off(top), 6.0, 0.06), "FloorButtonPlate" + state,
		Vector3(-3.3, plate_y, z))
	# эмиттер → приёмник
	var body: Material = _material(DEVICES + "emitter_body.tres")
	var lens: Material = _material(DEVICES + "emitter_lens.tres")
	_instance(_box(Vector3(0.36, 0.3, 0.36), dark, dark, Vector2(2.0, 2.0)), "EmitterBase" + state, Vector3(-1.6, 0.2, z))
	_instance(_cylinder(0.13, 0.5, body, lens if active else _off(lens)), "EmitterBarrel" + state,
		Vector3(-1.45, 0.5, z), Vector3(0.0, 0.0, -90.0))
	var receiver: Material = _material(DEVICES + "receiver_face.tres")
	_instance(_box(Vector3(0.12, 0.9, 0.12), dark, dark, Vector2(2.0, 2.0)), "ReceiverPost" + state, Vector3(1.0, 0.5, z))
	_instance(_box(Vector3(0.6, 0.6, 0.08), receiver if active else _off(receiver), dark), "ReceiverFace" + state,
		Vector3(0.94, 0.62, z), Vector3(0.0, -90.0, 0.0))
	if active:
		var beam_length: float = 0.94 - (-1.2)
		_instance(_cylinder(0.02, beam_length, _glow(CYAN, 1.0, 3.0), _glow(CYAN, 1.0, 3.0)), "Beam",
			Vector3((-1.2 + 0.94) * 0.5, 0.5, z), Vector3(0.0, 0.0, 90.0))
	# генератор гравитации
	var band: Material = _material(DEVICES + "gravity_band.tres")
	_instance(_cylinder(0.32, 0.5, band if active else _off(band), dark, 3.0), "GravityGenerator" + state,
		Vector3(2.6, 0.3, z))
	if active:
		var field: BoxMesh = BoxMesh.new()
		field.size = Vector3(1.0, 1.6, 1.0)
		field.material = _glow(GRAVITY, 0.06, 0.5)
		_instance(field, "GravityField", Vector3(2.6, 1.35, z))
	# силовой узел HEVS-02
	var node_side: Material = _material(DEVICES + "power_node_side.tres")
	var node_mesh: ArrayMesh = _box(Vector3(0.6, 0.3, 0.3), node_side if active else _off(node_side), dark, Vector2(3.0, 3.0), true)
	_instance(node_mesh, "PowerNode" + state, Vector3(4.6, 0.2, z), Vector3(0.0, -15.0, 0.0))
	# стойка станции авангарда под узлом — светлая панель
	_instance(_box(Vector3(0.8, 0.06, 0.5), panel, panel, Vector2(2.0, 2.0)), "NodeStationShelf" + state, Vector3(4.6, 0.03, z))


func _build_wall_devices() -> void:
	var dark: Material = _material(SURFACES + "metal_dark.tres")
	var panel: Material = _material(SURFACES + "panel_light.tres")
	var wall_z: float = -3.95
	# дверь камеры в человеческой раме
	var door: Material = _material(DEVICES + "door_leaf.tres")
	_instance(_box(Vector3(3.0, 3.0, 0.3), panel, panel, Vector2(1.0, 1.0)), "DoorFrame", Vector3(0.0, 1.5, wall_z))
	_instance(_box(Vector3(2.4, 2.4, 0.12), door, dark, Vector2(1.0, 1.0), true), "Door", Vector3(0.0, 1.25, wall_z + 0.2))
	# настенные кнопки: вкл и выкл
	var wall_button: Material = _material(DEVICES + "wall_button_front.tres")
	_instance(_box(Vector3(0.3, 0.45, 0.1), wall_button, panel, Vector2(2.0, 2.0), true), "WallButtonOn", Vector3(-2.3, 1.3, wall_z))
	_instance(_box(Vector3(0.3, 0.45, 0.1), _off(wall_button), panel, Vector2(2.0, 2.0), true), "WallButtonOff",
		Vector3(-2.9, 1.3, wall_z))
	# распределительные коробки логики, соединённые кабелем
	var kinds: Array[String] = ["relay", "and", "or", "not", "delay", "latch"]
	for index: int in kinds.size():
		var box_material: Material = _material(DEVICES + "junction_%s.tres" % kinds[index])
		var x: float = 2.2 + float(index) * 0.55
		_instance(_box(Vector3(0.4, 0.4, 0.12), box_material, dark, Vector2(2.0, 2.0), true), "Junction_" + kinds[index],
			Vector3(x, 1.6, wall_z))
	var cable: Material = _material(DEVICES + "cable.tres")
	var cable_length: float = 4.4
	_instance(_cylinder(0.025, cable_length, cable, dark, 1.0, cable_length / 0.25, true), "Cable",
		Vector3(1.6 + cable_length * 0.5, 1.25, wall_z + 0.05), Vector3(0.0, 0.0, 90.0))


func _build_alien_features() -> void:
	var wall_z: float = -3.97
	var dark: Material = _material(SURFACES + "metal_dark.tres")
	var panel: Material = _material(SURFACES + "panel_light.tres")
	# канал кладки с человеческим кабелем вдоль всей стены (1 тайл = 2 м по U, 0,5 м по V)
	var channel: Material = _material(ALIEN + "power_channel.tres")
	_instance(_box(Vector3(19.6, 0.5, 0.06), channel, channel, Vector2(0.5, 2.0)), "PowerChannel",
		Vector3(0.0, 0.42, wall_z))
	# колонна глифов
	var glyphs: Material = _material(ALIEN + "glyph_panel.tres")
	_instance(_box(Vector3(1.4, 3.6, 0.12), glyphs, glyphs, Vector2(0.5, 0.5)), "GlyphColumn",
		Vector3(-4.0, 2.4, wall_z))
	# терминал камеры и станция авангарда
	var terminal: Material = _material(DEVICES + "chamber_terminal.tres")
	_instance(_box(Vector3(1.2, 0.9, 0.14), terminal, dark, Vector2(2.0, 2.0), true), "ChamberTerminal",
		Vector3(-6.3, 1.6, wall_z))
	var station: Material = _material(DEVICES + "vanguard_station.tres")
	_instance(_box(Vector3(0.6, 0.9, 0.4), station, panel, Vector2(2.0, 2.0), true), "VanguardStation",
		Vector3(-8.3, 0.45, -3.6))
	# биомасса у основания стены и на полу
	var biomass: Material = _material(ALIEN + "biomass.tres")
	_instance(_box(Vector3(3.0, 1.4, 0.05), biomass, biomass, Vector2(0.5, 0.5)), "BiomassWall",
		Vector3(8.6, 0.7, wall_z + 0.03))
	_instance(_box(Vector3(3.2, 0.03, 1.8), biomass, biomass, Vector2(0.5, 0.5)), "BiomassFloor",
		Vector3(8.6, 0.0, -3.0))
	# рама портала: овал из сегментов; управление — человеческая консоль рядом
	var frame: Material = _material(ALIEN + "portal_frame.tres")
	var centre: Vector3 = Vector3(7.2, 1.75, -2.9)
	var segments: int = 24
	for index: int in segments:
		var a0: float = TAU * float(index) / float(segments)
		var a1: float = TAU * float(index + 1) / float(segments)
		var p0: Vector3 = Vector3(cos(a0) * 1.0, sin(a0) * 1.55, 0.0)
		var p1: Vector3 = Vector3(cos(a1) * 1.0, sin(a1) * 1.55, 0.0)
		var mid: Vector3 = (p0 + p1) * 0.5
		var length: float = p0.distance_to(p1) + 0.02
		var angle_deg: float = rad_to_deg(atan2(p1.y - p0.y, p1.x - p0.x))
		var mesh: ArrayMesh = _box(Vector3(length, 0.34, 0.4), frame, frame, Vector2(0.5, 1.0 / 0.34), false)
		_instance(mesh, "PortalFrame%02d" % index, centre + mid, Vector3(0.0, 0.0, angle_deg))
	# холодный рассеянный свет чужого слоя у портала — атмосфера, не игровой сигнал
	var alien_light: OmniLight3D = OmniLight3D.new()
	alien_light.name = "AlienColdLight"
	alien_light.light_color = Color("#B8C8E0")
	alien_light.light_energy = 1.6
	alien_light.omni_range = 6.0
	alien_light.position = centre + Vector3(0.0, 0.6, 1.6)
	_root.add_child(alien_light)
	var console: Material = _material(DEVICES + "chamber_terminal.tres")
	_instance(_box(Vector3(0.1, 1.0, 0.1), dark, dark, Vector2(2.0, 2.0)), "PortalConsolePost", Vector3(5.6, 0.5, -2.4))
	_instance(_box(Vector3(0.6, 0.45, 0.08), console, dark, Vector2(2.0, 2.0), true), "PortalConsole",
		Vector3(5.6, 1.1, -2.34), Vector3(-20.0, 20.0, 0.0))


func _build_swatches() -> void:
	var names: Array[String] = ["panel_light", "metal_dark", "hazard_stripes", "rubber_ribbed", "diamond_plate"]
	for index: int in names.size():
		var material: Material = _material(SURFACES + names[index] + ".tres")
		_instance(_box(Vector3(1.0, 1.0, 0.05), material, material, Vector2(1.0, 1.0)), "Swatch_" + names[index],
			Vector3(-6.2 + float(index) * 1.15, 4.7, -3.95))
	var alien: Array[String] = ["basalt_wall", "basalt_floor", "glyph_panel", "biomass", "portal_frame"]
	for index: int in alien.size():
		var path: String = ALIEN + alien[index] + ".tres"
		if ResourceLoader.exists(path):
			var material: Material = _material(path)
			_instance(_box(Vector3(1.0, 1.0, 0.05), material, material, Vector2(1.0, 1.0)), "Swatch_" + alien[index],
				Vector3(1.0 + float(index) * 1.15, 4.7, -3.95))


func _build_camera(from: Vector3, to: Vector3) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.name = "ShowcaseCamera"
	camera.fov = 68.0
	camera.position = from
	camera.current = true
	_root.add_child(camera)
	camera.look_at_from_position(from, to)


## Решётчатый мостик с ограждением и манекен скафандра: ткань, нагрудный индикатор, наручный терминал.
func _build_catwalk_and_suit() -> void:
	var grating: Material = _material(SURFACES + "grating.tres")
	var tube: Material = _material(SURFACES + "railing_tube.tres")
	var dark: Material = _material(SURFACES + "metal_dark.tres")
	var base: Vector3 = Vector3(-8.3, 0.0, 0.4)
	var deck_y: float = 0.6
	_instance(_box(Vector3(2.4, 0.04, 1.6), grating, grating, Vector2(2.0, 2.0)), "GratingDeck", base + Vector3(0.0, deck_y, 0.0))
	for corner: Vector2 in [Vector2(-1.15, -0.75), Vector2(1.15, -0.75), Vector2(-1.15, 0.75), Vector2(1.15, 0.75)]:
		_instance(_cylinder(0.04, deck_y, dark, dark), "DeckLeg", base + Vector3(corner.x, deck_y * 0.5, corner.y))
		_instance(_cylinder(0.025, 1.0, tube, dark, 1.0, 2.0, true), "RailPost", base + Vector3(corner.x, deck_y + 0.5, corner.y))
	_instance(_cylinder(0.025, 2.3, tube, dark, 1.0, 4.6, true), "RailFront", base + Vector3(0.0, deck_y + 1.0, 0.75),
		Vector3(0.0, 0.0, 90.0))
	_instance(_cylinder(0.025, 2.3, tube, dark, 1.0, 4.6, true), "RailFrontMid", base + Vector3(0.0, deck_y + 0.5, 0.75),
		Vector3(0.0, 0.0, 90.0))
	for side: float in [-1.15, 1.15]:
		_instance(_cylinder(0.025, 1.5, tube, dark, 1.0, 3.0, true), "RailSide", base + Vector3(side, deck_y + 1.0, 0.0),
			Vector3(90.0, 0.0, 0.0))
	var fabric: Material = _material(SUIT + "suit_fabric.tres")
	var chest: Material = _material(SUIT + "chest_indicator.tres")
	var wrist: Material = _material(SUIT + "wrist_terminal.tres")
	var torso: Vector3 = base + Vector3(0.0, deck_y + 0.95, -0.1)
	_instance(_cylinder(0.24, 0.7, fabric, fabric, 3.0, 1.4), "SuitTorso", torso)
	_instance(_box(Vector3(0.28, 0.28, 0.08), chest, fabric, Vector2(2.0, 2.0), true), "ChestIndicator",
		torso + Vector3(0.0, 0.08, 0.26))
	_instance(_cylinder(0.065, 0.5, fabric, fabric, 1.0, 1.0), "SuitForearm", torso + Vector3(0.3, -0.18, 0.25),
		Vector3(90.0, 0.0, 0.0))
	_instance(_box(Vector3(0.18, 0.09, 0.05), wrist, dark, Vector2(4.0, 4.0), true), "WristTerminal",
		torso + Vector3(0.3, -0.105, 0.3), Vector3(-90.0, 0.0, 0.0))
	_label("скафандр · решётка · ограждение", base + Vector3(0.0, deck_y + 1.55, 0.75), 28)


## Витрина под открытым небом: панорама терминатора, грунт, чужой шпиль, макет HEVS-02 с ливреей.
func _build_vitrine() -> void:
	var sky_resource: Resource = load(PLANET + "terminator_sky_sky.tres")
	var environment: Environment = Environment.new()
	if sky_resource is Sky:
		var sky: Sky = sky_resource
		environment.background_mode = Environment.BG_SKY
		environment.sky = sky
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	else:
		push_error("Нет неба %s" % (PLANET + "terminator_sky_sky.tres"))
		_failed = true
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("#4F5230")
	environment.fog_density = 0.0025
	environment.fog_sky_affect = 0.15
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	_root.add_child(world)
	# неподвижный красный карлик у горизонта. Центр панорамы (u = 0,5) Godot показывает в направлении +Z
	# (проверено рендером), поэтому свет приходит с +Z и падает под углом 4° — как диск на панораме.
	var star: DirectionalLight3D = DirectionalLight3D.new()
	star.name = "RedDwarf"
	star.light_color = Color("#FFB27A")
	star.light_energy = 1.4
	star.shadow_enabled = true
	star.rotation_degrees = Vector3(-4.0, 0.0, 0.0)
	_root.add_child(star)
	var ground: Material = _material(PLANET + "planet_ground.tres")
	_instance(_box(Vector3(160.0, 0.2, 160.0), ground, ground, Vector2(0.5, 0.5)), "Ground", Vector3(0.0, -0.1, 0.0))
	var basalt: Material = _material(ALIEN + "basalt_wall.tres")
	_instance(_box(Vector3(8.0, 60.0, 8.0), basalt, basalt, Vector2(0.5, 0.5)), "AlienSpire", Vector3(-26.0, 30.0, 40.0),
		Vector3(0.0, 20.0, 4.0))
	var hull: Material = _material(VEHICLE + "hevs_hull.tres")
	var livery: Material = _material(VEHICLE + "hevs_livery.tres")
	var dark: Material = _material(SURFACES + "metal_dark.tres")
	var hevs: Vector3 = Vector3(0.0, 1.9, 0.0)
	_instance(_box(Vector3(7.0, 2.4, 3.4), hull, hull, Vector2(0.5, 0.5)), "HevsBody", hevs)
	# лента ливреи: один тайл (два номера «02») на длину борта
	_instance(_box(Vector3(7.06, 0.6, 3.46), livery, livery, Vector2(1.0 / 7.06, 1.0 / 0.6)), "HevsLivery",
		hevs + Vector3(0.0, -0.1, 0.0))
	_instance(_box(Vector3(2.0, 1.6, 3.0), hull, hull, Vector2(0.5, 0.5)), "HevsCockpit", hevs + Vector3(3.9, 0.1, 0.0),
		Vector3(0.0, 0.0, -12.0))
	for leg: Vector2 in [Vector2(-2.6, -1.4), Vector2(2.6, -1.4), Vector2(-2.6, 1.4), Vector2(2.6, 1.4)]:
		_instance(_cylinder(0.12, 1.0, dark, dark), "HevsLeg", Vector3(leg.x, 0.5, leg.y))
	_build_camera(Vector3(9.0, 2.6, 11.0), Vector3(0.0, 1.8, 0.0))


## Брошенный лагерь у подножия сооружения после пожара Д42: палатки, модули, ящики, прожекторы, знаки.
func _build_camp() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#07090A")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#3A4650")
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.glow_enabled = true
	environment.glow_intensity = 0.7
	environment.ssao_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("#2E3438")
	environment.fog_density = 0.02
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	_root.add_child(world)
	var shaft: DirectionalLight3D = DirectionalLight3D.new()
	shaft.name = "ColdShaft"
	shaft.light_color = Color(0.62, 0.72, 0.86)
	shaft.light_energy = 0.35
	shaft.shadow_enabled = true
	shaft.rotation_degrees = Vector3(-62.0, -25.0, 0.0)
	_root.add_child(shaft)
	var floor_material: Material = _material(ALIEN + "basalt_floor.tres")
	var basalt: Material = _material(ALIEN + "basalt_wall.tres")
	_instance(_box(Vector3(24.0, 0.4, 20.0), floor_material, floor_material, Vector2(0.5, 0.5)), "AlienFloor", Vector3(0.0, -0.2, -2.0))
	_instance(_box(Vector3(24.0, 12.0, 0.8), basalt, basalt, Vector2(0.5, 0.5)), "AlienWall", Vector3(0.0, 6.0, -10.0))
	var dark: Material = _material(SURFACES + "metal_dark.tres")
	var canvas: Material = _material(CAMP + "camp_canvas.tres")
	var canvas_burnt: Material = _material(CAMP + "camp_canvas_burnt.tres")
	_build_tent(canvas, dark, Vector3(-5.2, 0.0, -3.5), 18.0, "TentIntact")
	_build_tent(canvas_burnt, dark, Vector3(-1.4, 0.0, -5.6), -8.0, "TentBurnt")
	var habitat: Material = _material(CAMP + "habitat_panel.tres")
	var habitat_burnt: Material = _material(CAMP + "habitat_panel_burnt.tres")
	# стена модуля — один тайл по высоте (2 м текстуры на 2,4 м стены), 2 м на тайл по длине
	_instance(_box(Vector3(4.0, 2.4, 2.4), habitat, habitat, Vector2(0.5, 1.0 / 2.4)), "HabitatModule", Vector3(1.6, 1.2, -7.6))
	_instance(_box(Vector3(4.0, 2.4, 2.4), habitat_burnt, habitat_burnt, Vector2(0.5, 1.0 / 2.4)), "Medbay", Vector3(5.2, 1.2, -2.2),
		Vector3(0.0, -24.0, 0.0))
	var medbay: Material = _material(CAMP + "medbay_sign.tres")
	_instance(_box(Vector3(0.6, 0.6, 0.01), medbay, medbay), "MedbaySign", Vector3(4.66, 1.7, -1.0), Vector3(0.0, -24.0, 0.0))
	var crate: Material = _material(CAMP + "supply_crate.tres")
	var crates: Array[Vector3] = [Vector3(-3.0, 0.4, -0.6), Vector3(-2.15, 0.4, -0.9), Vector3(-2.6, 1.2, -0.75),
		Vector3(1.4, 0.4, -2.6), Vector3(0.6, 0.4, 0.4)]
	var crate_yaw: Array[float] = [6.0, -10.0, 22.0, 35.0, -4.0]
	for index: int in crates.size():
		_instance(_box(Vector3(0.8, 0.8, 0.8), crate, crate), "SupplyCrate%d" % index, crates[index], Vector3(0.0, crate_yaw[index], 0.0))
	_instance(_box(Vector3(1.4, 0.6, 0.7), crate, crate), "LongCrate", Vector3(2.3, 0.3, 0.9), Vector3(0.0, 80.0, 0.0))
	var lamp: Material = _material(CAMP + "floodlight.tres")
	var target: Vector3 = Vector3(0.0, 0.0, -3.5)
	for lamp_position: Vector3 in [Vector3(-6.8, 0.0, 0.6), Vector3(6.6, 0.0, 1.4), Vector3(-1.0, 0.0, -9.0)]:
		# лицевая грань (+Z) прожектора повёрнута к центру лагеря
		var to_target: Vector3 = target - lamp_position
		_build_floodlight(lamp, dark, lamp_position, rad_to_deg(atan2(to_target.x, to_target.z)), 24.0, true,
			"Floodlight%d" % int(lamp_position.x))
	_build_floodlight(_off(lamp), dark, Vector3(-0.4, 0.45, -1.6), 160.0, 0.0, false, "FloodlightFallen")
	var banner: Material = _material(CAMP + "expedition_banner.tres")
	_instance(_cylinder(0.035, 3.4, dark, dark), "BannerPole", Vector3(-3.8, 1.7, -7.2))
	_instance(_box(Vector3(0.8, 1.6, 0.01), banner, banner), "ExpeditionBanner", Vector3(-3.36, 2.55, -7.2))
	var radiation: Material = _material(CAMP + "radiation_sign.tres")
	_instance(_cylinder(0.03, 1.6, dark, dark), "SignPost", Vector3(0.9, 0.8, 2.6))
	_instance(_box(Vector3(0.5, 0.5, 0.01), radiation, radiation), "RadiationSign", Vector3(0.9, 1.45, 2.63), Vector3(0.0, 12.0, 0.0))
	_build_camera(Vector3(0.0, 2.2, 7.5), Vector3(0.0, 1.0, -3.0))


## Двускатная палатка: два ската ткани на каркасе из труб.
func _build_tent(fabric: Material, frame: Material, origin: Vector3, yaw: float, node_name: String) -> void:
	var tent: Node3D = Node3D.new()
	tent.name = node_name
	tent.position = origin
	tent.rotation_degrees = Vector3(0.0, yaw, 0.0)
	_root.add_child(tent)
	var slope: float = 1.75
	var tilt: float = 52.0
	var half_width: float = cos(deg_to_rad(tilt)) * slope * 0.5
	var ridge: float = sin(deg_to_rad(tilt)) * slope
	for side: float in [-1.0, 1.0]:
		_instance(_box(Vector3(3.2, 0.02, slope), fabric, fabric, Vector2(1.0, 1.0)), "Slope%s" % ("L" if side < 0.0 else "R"), Vector3(0.0, ridge * 0.5, side * half_width),
			Vector3(side * tilt, 0.0, 0.0), tent)
	for x: float in [-1.55, 1.55]:
		_instance(_cylinder(0.025, ridge, frame, frame), "Pole%s" % ("L" if x < 0.0 else "R"), Vector3(x, ridge * 0.5, 0.0), Vector3.ZERO, tent)
	_instance(_cylinder(0.02, 3.2, frame, frame), "Ridge", Vector3(0.0, ridge, 0.0), Vector3(0.0, 0.0, 90.0), tent)


## Переносной прожектор на треноге; включённый даёт тёплый конус света, упавший погашен.
func _build_floodlight(face: Material, body: Material, origin: Vector3, yaw: float, pitch: float, standing: bool,
		node_name: String) -> void:
	var stand: Node3D = Node3D.new()
	stand.name = node_name
	stand.position = origin
	stand.rotation_degrees = Vector3(0.0, yaw, 0.0 if standing else 78.0)
	_root.add_child(stand)
	var mast: float = 2.2
	for leg: int in 3:
		var angle_rad: float = TAU * float(leg) / 3.0
		var foot: Vector3 = Vector3(cos(angle_rad) * 0.55, 0.0, sin(angle_rad) * 0.55)
		var mid: Vector3 = (foot + Vector3(0.0, 1.0, 0.0)) * 0.5
		var length: float = foot.distance_to(Vector3(0.0, 1.0, 0.0))
		var leg_node: MeshInstance3D = _instance(_cylinder(0.018, length, body, body), "Leg%d" % leg, mid, Vector3.ZERO, stand)
		leg_node.basis = Basis(Quaternion(Vector3.UP, (Vector3(0.0, 1.0, 0.0) - foot).normalized()))
	_instance(_cylinder(0.022, mast - 1.0, body, body), "Mast", Vector3(0.0, 1.0 + (mast - 1.0) * 0.5, 0.0), Vector3.ZERO, stand)
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, mast + 0.12, 0.0)
	# положительный наклон опускает лицевую грань (+Z) вниз
	head.rotation_degrees = Vector3(pitch, 0.0, 0.0)
	stand.add_child(head)
	_instance(_box(Vector3(0.42, 0.42, 0.14), face, body), "LampHead", Vector3.ZERO, Vector3.ZERO, head)
	if standing:
		var spot: SpotLight3D = SpotLight3D.new()
		spot.name = "Beam"
		spot.light_color = Color("#FFE2B8")
		spot.light_energy = 6.0
		spot.spot_range = 16.0
		spot.spot_angle = 48.0
		spot.shadow_enabled = true
		# SpotLight3D светит вдоль −Z; лицевая грань ящика смотрит в +Z, поэтому разворот на 180°.
		spot.position = Vector3(0.0, 0.0, 0.12)
		spot.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		head.add_child(spot)


func _assign_owner(node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = _root
		_assign_owner(child)
