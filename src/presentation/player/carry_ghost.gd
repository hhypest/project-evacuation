class_name CarryGhost
extends MeshInstance3D
## Hologram silhouette of where the held prop would be set down (ADR-0012, placement). Display only:
## no collisions, no shadows, hidden whenever the carry controller has no slot.

const SHADER: Shader = preload("res://content/shaders/carry_ghost.gdshader")

var _box: BoxMesh = BoxMesh.new()
var _material: ShaderMaterial = ShaderMaterial.new()


func _init() -> void:
	name = "CarryGhost"
	_material.shader = SHADER
	_box.material = _material
	mesh = _box
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	visible = false


func present(slot: CarryPlacement) -> void:
	if slot == null or not slot.available:
		visible = false
		return
	if not _box.size.is_equal_approx(slot.size):
		_box.size = slot.size
		_material.set_shader_parameter(&"half_size", slot.size * 0.5)
	global_transform = slot.transform
	visible = true
