extends SceneTree
## Собирает демонстрационную сцену материалов человеческого и чужого слоя:
##   content/levels/material_showcase.tscn
## Сцена служит для художественной проверки (читаемость состояний, свет, масштаб)
## и не входит в игровой маршрут. Запуск из корня репозитория:
##   godot --headless --path . --script tools/art/build_material_showcase.gd

const SCENE_PATH: String = "res://content/levels/material_showcase.tscn"
const DEVICES: String = "res://content/materials/devices/"
const SURFACES: String = "res://content/materials/surfaces/"
const ALIEN: String = "res://content/materials/alien/"
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
	_build_swatches()
	_build_camera()
	if _failed:
		quit(1)
		return
	_assign_owner(_root)
	var packed: PackedScene = PackedScene.new()
	var pack_error: Error = packed.pack(_root)
	if pack_error != OK:
		push_error("Не удалось упаковать сцену")
		quit(1)
		return
	var save_error: Error = ResourceSaver.save(packed, SCENE_PATH)
	_root.free()
	if save_error != OK:
		push_error("Не удалось сохранить %s" % SCENE_PATH)
		quit(1)
		return
	print("SHOWCASE_BUILT %s" % SCENE_PATH)
	quit(0)


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


func _build_camera() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.name = "ShowcaseCamera"
	camera.fov = 68.0
	camera.position = Vector3(0.0, 3.2, 10.5)
	camera.current = true
	_root.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0.0, 1.6, -2.0))


func _assign_owner(node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = _root
		_assign_owner(child)
