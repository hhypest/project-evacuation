class_name PortalPropVisual
extends Node3D
## Two clipped appearances of one physical prop. The twin has meshes only: never another rigid body,
## collider, device ID or signal. Each original half joins the other half seen through the membrane.

const CLIP_SHADER: Shader = preload("res://src/infrastructure/portals/portal_prop.gdshader")

class Part:
	extends RefCounted
	var source: MeshInstance3D
	var twin: MeshInstance3D
	var original_override: Material
	var original_surfaces: Array[Material] = []
	var clipped_surfaces: Array[ShaderMaterial] = []

var body: CarryRigidBody
var twin_visible: bool = false
var entry: PortalSurface
var _surfaces: Array[PortalSurface] = []
var _parts: Array[Part] = []
var _labels: Array[Label3D] = []
var _label_visibility: Array[bool] = []
var _active: bool = false
var _held_surface: PortalSurface


func configure(prop: CarryRigidBody, surfaces: Array[PortalSurface]) -> void:
	body = prop
	_surfaces = surfaces
	_collect(prop)
	set_process(not _parts.is_empty())


func _collect(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh.mesh != null:
			var part: Part = Part.new()
			part.source = mesh
			part.original_override = mesh.material_override
			part.twin = MeshInstance3D.new()
			part.twin.mesh = mesh.mesh
			part.twin.cast_shadow = mesh.cast_shadow
			part.twin.layers = mesh.layers
			part.twin.visible = false
			add_child(part.twin)
			for index: int in range(mesh.mesh.get_surface_count()):
				part.original_surfaces.append(mesh.get_surface_override_material(index))
				var clipped: ShaderMaterial = _material(mesh.get_active_material(index))
				part.clipped_surfaces.append(clipped)
				part.twin.set_surface_override_material(index, clipped)
			_parts.append(part)
	elif node is Label3D:
		# These are the temporary mass/debug labels, not the model's markings. A flat uncut label must
		# not float through a clipped half. It returns with its original visibility after the crossing.
		var label: Label3D = node as Label3D
		_labels.append(label)
		_label_visibility.append(label.visible)
	for child: Node in node.get_children():
		_collect(child)


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	entry = null
	if is_instance_valid(body) and body.is_inside_tree():
		if is_instance_valid(_held_surface) and _held_surface.powered and body.is_carried() \
				and (_held_surface.global_transform.affine_inverse() * body.global_position).z < 0.0:
			entry = _held_surface
		else:
			_held_surface = null
		var size: Vector3 = (body.carry_shape() as BoxShape3D).size * 0.5
		for surface: PortalSurface in _surfaces:
			if entry != null:
				break
			if not is_instance_valid(surface) or not surface.powered or surface.partner == null:
				continue
			var local: Transform3D = surface.global_transform.affine_inverse() * body.global_transform
			var extent: Vector3 = PortalRules.projected_extent(local.basis, size)
			if absf(local.origin.z) <= extent.z + 0.01 and absf(local.origin.x) + extent.x <= surface.half_size.x + 0.01 \
					and absf(local.origin.y) + extent.y <= surface.half_size.y + 0.01:
				entry = surface
				break
	_set_active(entry != null)
	if entry == null:
		return
	var mapping: Transform3D = PortalMath.transfer(entry.global_transform, entry.partner.global_transform)
	var plane: Vector4 = _plane(entry)
	var other: Vector4 = _plane(entry.partner)
	for part: Part in _parts:
		part.source.set_instance_shader_parameter(&"portal_clip_plane", plane)
		part.twin.global_transform = mapping * part.source.global_transform
		part.twin.set_instance_shader_parameter(&"portal_clip_plane", other)
		part.twin.visible = part.source.is_visible_in_tree()
	twin_visible = true


func reset_transit() -> void:
	_held_surface = null


func set_held_surface(surface: PortalSurface) -> void:
	_held_surface = surface


func _set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	twin_visible = on
	for part: Part in _parts:
		if not is_instance_valid(part.source):
			continue
		part.source.material_override = null if on else part.original_override
		for index: int in range(part.original_surfaces.size()):
			part.source.set_surface_override_material(index, part.clipped_surfaces[index] if on else part.original_surfaces[index])
		part.twin.visible = on
	for index: int in range(_labels.size()):
		if is_instance_valid(_labels[index]):
			_labels[index].visible = false if on else _label_visibility[index]


func _exit_tree() -> void:
	_set_active(false)


static func _plane(surface: PortalSurface) -> Vector4:
	var normal: Vector3 = surface.global_basis.z.normalized()
	return Vector4(normal.x, normal.y, normal.z, -normal.dot(surface.global_position))


## The imported cube uses opaque BaseMaterial3D PBR maps. Keep its albedo/normal/ORM/UV/emission data;
## only the two intersecting instances use this shader, never mutate the shared imported resource.
static func _material(source: Material) -> ShaderMaterial:
	var result: ShaderMaterial = ShaderMaterial.new()
	result.shader = CLIP_SHADER
	var pbr: BaseMaterial3D = source as BaseMaterial3D
	if pbr == null:
		return result
	result.set_shader_parameter(&"albedo_color", pbr.albedo_color)
	result.set_shader_parameter(&"albedo_map", pbr.get_texture(BaseMaterial3D.TEXTURE_ALBEDO))
	result.set_shader_parameter(&"normal_map", pbr.get_texture(BaseMaterial3D.TEXTURE_NORMAL))
	result.set_shader_parameter(&"normals_enabled", pbr.normal_enabled)
	result.set_shader_parameter(&"normal_depth", pbr.normal_scale)
	result.set_shader_parameter(&"metallic_factor", pbr.metallic)
	result.set_shader_parameter(&"roughness_factor", pbr.roughness)
	result.set_shader_parameter(&"uv_scale", pbr.uv1_scale)
	result.set_shader_parameter(&"uv_offset", pbr.uv1_offset)
	result.set_shader_parameter(&"repeat_enabled", pbr.texture_repeat)
	result.set_shader_parameter(&"ao_enabled", pbr.ao_enabled)
	result.set_shader_parameter(&"emission_color", pbr.emission * pbr.emission_energy_multiplier if pbr.emission_enabled else Color.BLACK)
	result.set_shader_parameter(&"emission_map", pbr.get_texture(BaseMaterial3D.TEXTURE_EMISSION))
	if pbr is ORMMaterial3D:
		var orm: Texture2D = pbr.get_texture(BaseMaterial3D.TEXTURE_ORM)
		result.set_shader_parameter(&"packed_orm", true)
		result.set_shader_parameter(&"orm_map", orm)
	else:
		result.set_shader_parameter(&"metallic_map", pbr.get_texture(BaseMaterial3D.TEXTURE_METALLIC))
		result.set_shader_parameter(&"roughness_map", pbr.get_texture(BaseMaterial3D.TEXTURE_ROUGHNESS))
		result.set_shader_parameter(&"ao_map", pbr.get_texture(BaseMaterial3D.TEXTURE_AMBIENT_OCCLUSION))
		result.set_shader_parameter(&"metallic_channel", _channel(pbr.metallic_texture_channel))
		result.set_shader_parameter(&"roughness_channel", _channel(pbr.roughness_texture_channel))
		result.set_shader_parameter(&"ao_channel", _channel(pbr.ao_texture_channel))
	return result


static func _channel(channel: BaseMaterial3D.TextureChannel) -> Vector4:
	var channels: Array[Vector4] = [Vector4(1, 0, 0, 0), Vector4(0, 1, 0, 0), Vector4(0, 0, 1, 0),
		Vector4(0, 0, 0, 1), Vector4(0.333333, 0.333333, 0.333333, 0)]
	return channels[channel]
