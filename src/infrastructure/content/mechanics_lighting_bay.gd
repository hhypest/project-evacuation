class_name MechanicsLightingBay
extends MechanicsBayBuilder
## Local direct-light bench: moving omni, spot, physical blockers and independent comparison switches.

const AMBER_GUIDE: Color = Color(0.7, 0.4, 0.13)

var point: OmniLight3D
var spot: SpotLight3D
var motion_stopped: bool = false
var phase: float = 0.0
var _floor_material: BaseMaterial3D
var _wall_material: BaseMaterial3D


func _ready() -> void:
	_floor_material = FLOOR_MATERIAL.duplicate() as BaseMaterial3D
	_wall_material = WALL_MATERIAL.duplicate() as BaseMaterial3D
	# Keep the common level environment readable without washing out this direct-light comparison.
	_floor_material.disable_ambient_light = true
	_wall_material.disable_ambient_light = true
	super._ready()


func _surface_box(size: Vector3, at: Vector3, material: Material, label: String = "") -> StaticBody3D:
	return super._surface_box(size, at, _floor_material if material == FLOOR_MATERIAL else _wall_material, label)


func _lighting() -> void:
	# The other six bays retain their normal four lamps. Only this room uses the comparison rig.
	var safe: OmniLight3D = OmniLight3D.new()
	safe.name = "ControlLight"
	safe.position = Vector3(-8, 2.7, 5.6)
	safe.omni_range = 4
	safe.light_energy = 0.35
	add_child(safe)


func _build() -> void:
	point = OmniLight3D.new()
	point.name = "MovingPoint"
	point.omni_range = 15
	point.light_energy = 5
	point.light_color = Color(1.0, 0.72, 0.43)
	point.shadow_enabled = true
	add_child(point)
	point.add_child(_bulb(point.light_color))
	spot = SpotLight3D.new()
	spot.name = "Spot"
	spot.position = Vector3(5, 4.8, 5)
	spot.spot_range = 16
	spot.spot_angle = 34
	spot.light_energy = 5
	spot.light_color = Color(0.55, 0.75, 1.0)
	spot.shadow_enabled = true
	add_child(spot)
	spot.look_at(to_global(Vector3(3, 0, -3)), Vector3.UP)
	spot.add_child(_bulb(spot.light_color))
	_place_point()
	_control(&"qa.lighting.stop", "СТОП", -9.8, _on_stop)
	_control(&"qa.lighting.point", "ТОЧКА OFF", -8.6, _on_point)
	_control(&"qa.lighting.spot", "КОНУС OFF", -7.4, _on_spot)
	_control(&"qa.lighting.shadows", "ТЕНИ OFF", -6.2, _on_shadows)
	_board("Все рубильники вниз: движение, оба света и тени включены\nE: СТОП / выключить точку / конус / тени · R — полный сброс", Vector3(-8, 2.5, 4.72))
	_board("07 · ДИНАМИЧЕСКИЙ СВЕТ И ТЕНИ\nОстанови свет и сравни тени с одного ракурса", Vector3(0, 4, -11.8))
	_box(Vector3(6, 3, 0.2), Vector3(-8, 1.5, 4.5), WALL_COLOR, "ControlPanel")
	_test_block(Vector3(8, 0.04, 8), Vector3(0, 0.02, -3), 0.85, 0, "ReceiverFloor")
	_test_block(Vector3(1.2, 2.4, 1.2), Vector3(0, 1.2, 0), 0.7, 0, "ShadowPillar")
	_test_block(Vector3(10, 3, 0.2), Vector3(0, 1.5, -8), 0.8, 0, "ShadowScreen")
	# A slatted blocker makes the spot's moving/occluded footprint easy to distinguish on the floor.
	for index: int in range(7):
		_test_block(Vector3(0.18, 2.8, 0.18), Vector3(1.5 + float(index) * 0.65, 1.4, 0), 0.6, 0, "Slat%d" % index)
	_cube("ShadowCubeA", &"qa.lighting.cube.a", Vector3(-3, 0.55, -1), 5)
	_cube("ShadowCubeB", &"qa.lighting.cube.b", Vector3(3, 0.55, -4), 20)
	# Three equal shapes isolate roughness/metalness while the light moves over them.
	for index: int in range(3):
		_test_block(Vector3(1, 1, 1), Vector3(-5 + float(index) * 2, 0.5, -5),
			0.15 if index == 1 else 0.8, 1.0 if index == 2 else 0.0, "MaterialSample%d" % index)
	_board("Матовый / гладкий / металл · кубы можно переносить\nУзкие стойки отбрасывают тени от прожектора", Vector3(-2, 2.4, -7.85))
	# Low emissive strips preserve the exit route when both test sources are switched off.
	for x: float in [-10.5, -6.5, -2.5]:
		var guide: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(0.9, 0.01, 0.08), AMBER_GUIDE, 1)
		guide.position = Vector3(x, 0.05, 0)
		guide.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(guide)


func _process(delta: float) -> void:
	if not motion_stopped:
		phase = fmod(phase + delta * TAU / 12.0, TAU)
		_place_point()


func _place_point() -> void:
	point.position = Vector3(sin(phase) * 3, 4, 1 + cos(phase) * 2)


func _control(id: StringName, text: String, x: float, handler: Callable) -> void:
	var control: LightingControl = LightingControl.new()
	control.name = node_name(id)
	control.stable_id = id
	control.mode = DeviceDefinition.WallMode.TOGGLE
	control.caption = text
	control.position = Vector3(x, 1.35, 4.72)
	control.output_changed.connect(handler)
	add_child(control)


func _on_stop(disabled: bool) -> void:
	motion_stopped = disabled


func _on_point(disabled: bool) -> void:
	point.visible = not disabled


func _on_spot(disabled: bool) -> void:
	spot.visible = not disabled


func _on_shadows(disabled: bool) -> void:
	point.shadow_enabled = not disabled
	spot.shadow_enabled = not disabled


func _bulb(color: Color) -> MeshInstance3D:
	var bulb: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3.ONE * 0.16, color, 3)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return bulb


func _test_block(size: Vector3, at: Vector3, roughness: float, metalness: float, label: String) -> void:
	var body: StaticBody3D = _box(size, at, Color(0.68, 0.68, 0.68), label)
	for child: Node in body.get_children():
		var visual: MeshInstance3D = child as MeshInstance3D
		if visual != null:
			var material: StandardMaterial3D = visual.material_override as StandardMaterial3D
			material.disable_ambient_light = true
			material.roughness = roughness
			material.metallic = metalness
