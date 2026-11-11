class_name PortalViewWorld
extends Node3D
## Native screen-space portal views. Only geometry intersecting the exit plane needs clipped meshes;
## front geometry uses its original materials, back geometry is excluded from that camera's layer.
## Clipped meshes draw color. Shadow-only copies keep casters on camera layers that omit their originals.

const VIEW_LAYERS: Array[int] = [1 << 17, 1 << 18]
const VIEW_MASK: int = (1 << 17) | (1 << 18)

class Proxy:
	extends RefCounted
	var mesh: MeshInstance3D
	var sources: Array[Material] = []
	var materials: Array[ShaderMaterial] = []

class Part:
	extends RefCounted
	var source: GeometryInstance3D
	var id: int
	var original_layers: int
	var proxies: Array[Proxy] = [null, null]
	var shadow: MeshInstance3D

class Lamp:
	extends RefCounted
	var source: Light3D
	var original_mask: int
	var original_layers: int

var _parts: Array[Part] = []
var _lamps: Array[Lamp] = []
var _registered: Dictionary[int, bool] = {}
var _pair: PortalPairDevice
var _level: Node3D


func configure(level: Node3D, pair: PortalPairDevice) -> void:
	_pair = pair
	_level = level
	_collect(level)
	get_tree().node_added.connect(_on_node_added)
	process_priority = 100


func _collect(node: Node) -> void:
	if node == self:
		return
	if node is Light3D and not _registered.has(node.get_instance_id()):
		var lamp: Lamp = Lamp.new()
		lamp.source = node as Light3D
		lamp.original_mask = lamp.source.light_cull_mask
		lamp.original_layers = lamp.source.layers
		lamp.source.light_cull_mask |= VIEW_MASK
		lamp.source.layers |= VIEW_MASK
		_lamps.append(lamp)
		_registered[node.get_instance_id()] = true
	if node is GeometryInstance3D:
		var geometry: GeometryInstance3D = node as GeometryInstance3D
		if geometry.layers & PortalSurface.MEMBRANE_LAYER == 0 and not _registered.has(geometry.get_instance_id()):
			var part: Part = Part.new()
			part.source = geometry
			part.id = geometry.get_instance_id()
			_registered[part.id] = true
			part.original_layers = geometry.layers
			_parts.append(part)
	for child: Node in node.get_children():
		_collect(child)


func _process(_delta: float) -> void:
	# PortalSurface decides visibility earlier in the frame. A disabled target never samples
	# its layers, so leave those layers and proxies alone until the next visible frame.
	var sides: int = 0
	if _pair.surface_a.viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		sides |= 1
	if _pair.surface_b.viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED:
		sides |= 2
	if sides != 0:
		refresh(sides)


func _on_node_added(node: Node) -> void:
	if _level.is_ancestor_of(node) and not is_ancestor_of(node) and (node is GeometryInstance3D or node is Light3D):
		_collect(node)


func refresh(sides: int = 3) -> void:
	var exits: Array[Transform3D] = [_pair.surface_b.global_transform, _pair.surface_a.global_transform]
	var normals: Array[Vector3] = [exits[0].basis.z.normalized(), exits[1].basis.z.normalized()]
	var active_layers: int = (VIEW_LAYERS[0] if sides & 1 else 0) | (VIEW_LAYERS[1] if sides & 2 else 0)
	for part: Part in _parts.duplicate():
		if not is_instance_valid(part.source):
			for old: Proxy in part.proxies:
				if old != null:
					old.mesh.queue_free()
			if part.shadow != null:
				part.shadow.queue_free()
			_parts.erase(part)
			_registered.erase(part.id)
			continue
		var layers: int = part.source.layers
		var visible: bool = part.source.is_visible_in_tree()
		var mesh: MeshInstance3D = part.source as MeshInstance3D
		var has_mesh: bool = mesh != null and mesh.mesh != null
		var bounds: AABB
		if visible and has_mesh:
			bounds = mesh.global_transform * mesh.get_aabb()
		for side: int in range(2):
			if sides & (1 << side) == 0:
				continue
			layers &= ~VIEW_LAYERS[side]
			var proxy: Proxy = part.proxies[side]
			var normal: Vector3 = normals[side]
			var anchor: Vector3 = bounds.get_center() if has_mesh else part.source.global_position
			var distance: float = normal.dot(anchor - exits[side].origin)
			var radius: float = normal.abs().dot(bounds.size * 0.5) if has_mesh else 0.0
			if part.source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				if proxy != null:
					proxy.mesh.hide()
				layers |= VIEW_LAYERS[side]
				continue
			if not visible or distance + radius < -0.0001 or not has_mesh or distance - radius >= -0.0001:
				if proxy != null and proxy.mesh.visible:
					proxy.mesh.visible = false
				# Non-mesh signage is clipped by its anchor.
				if visible and (distance - radius >= -0.0001 if has_mesh else distance >= 0.0):
					layers |= VIEW_LAYERS[side]
				continue
			if proxy == null:
				proxy = Proxy.new()
				proxy.mesh = MeshInstance3D.new()
				proxy.mesh.mesh = mesh.mesh
				proxy.mesh.layers = VIEW_LAYERS[side]
				proxy.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(proxy.mesh)
				part.proxies[side] = proxy
				for index: int in range(mesh.mesh.get_surface_count()):
					proxy.sources.append(null)
					proxy.materials.append(null)
			for index: int in range(mesh.mesh.get_surface_count()):
				var source: Material = mesh.get_active_material(index)
				if source != proxy.sources[index] or proxy.materials[index] == null:
					proxy.sources[index] = source
					var clipped: ShaderMaterial = source as ShaderMaterial
					proxy.materials[index] = clipped.duplicate() as ShaderMaterial \
						if clipped != null and clipped.shader == PortalPropVisual.CLIP_SHADER else PortalPropVisual._material(source)
					proxy.mesh.set_surface_override_material(index, proxy.materials[index])
				var pbr: BaseMaterial3D = source as BaseMaterial3D
				if pbr != null:
					proxy.materials[index].set_shader_parameter(&"albedo_color", pbr.albedo_color)
					proxy.materials[index].set_shader_parameter(&"emission_color", pbr.emission * pbr.emission_energy_multiplier if pbr.emission_enabled else Color.BLACK)
			var source_clip: Vector4 = Vector4(0, 0, 0, 1)
			var original: ShaderMaterial = mesh.get_active_material(0) as ShaderMaterial
			if original != null and original.shader == PortalPropVisual.CLIP_SHADER:
				var parameter: Variant = mesh.get_instance_shader_parameter(&"portal_clip_plane")
				if parameter is Vector4:
					source_clip = parameter
			proxy.mesh.global_transform = mesh.global_transform
			var plane: Vector4 = Vector4(normal.x, normal.y, normal.z, -normal.dot(exits[side].origin))
			proxy.mesh.set_instance_shader_parameter(&"portal_clip_plane", plane)
			proxy.mesh.set_instance_shader_parameter(&"portal_second_clip", source_clip)
			proxy.mesh.visible = true
		if part.source.layers != layers:
			part.source.layers = layers
		var shadow_layers: int = active_layers & ~layers if visible and has_mesh else 0
		_sync_shadow(part, mesh, shadow_layers)


func _sync_shadow(part: Part, source: MeshInstance3D, layers: int) -> void:
	var shadow: MeshInstance3D = part.shadow
	if layers == 0 or source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		if shadow != null and shadow.visible:
			shadow.hide()
		return
	if shadow == null:
		shadow = MeshInstance3D.new()
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		shadow.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		shadow.layers = layers
		add_child(shadow)
		part.shadow = shadow
	if shadow.layers != layers:
		shadow.layers = layers
	if shadow.mesh != source.mesh:
		shadow.mesh = source.mesh
	if shadow.material_override != source.material_override:
		shadow.material_override = source.material_override
	for index: int in range(source.mesh.get_surface_count()):
		var override: Material = source.get_surface_override_material(index)
		if shadow.get_surface_override_material(index) != override:
			shadow.set_surface_override_material(index, override)
	# Use the source's clipping in the shadow pass when a cube is split across the pair.
	var material: ShaderMaterial = source.get_active_material(0) as ShaderMaterial
	if material != null and material.shader == PortalPropVisual.CLIP_SHADER:
		shadow.set_instance_shader_parameter(&"portal_clip_plane", source.get_instance_shader_parameter(&"portal_clip_plane"))
	if shadow.global_transform != source.global_transform:
		shadow.global_transform = source.global_transform
	if not shadow.visible:
		shadow.show()


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	for part: Part in _parts:
		if is_instance_valid(part.source):
			part.source.layers = part.original_layers
	for lamp: Lamp in _lamps:
		if is_instance_valid(lamp.source):
			lamp.source.light_cull_mask = lamp.original_mask
			lamp.source.layers = lamp.original_layers
