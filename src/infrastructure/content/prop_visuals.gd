class_name PropVisuals
extends RefCounted
## Art models for code-built props. Visual only: every collision stays the tested primitive shape, so
## swapping art never changes physics or level traversal (ADR-0006, ART-04). Models: content/models.

const BALLAST_CUBE: PackedScene = preload("res://content/models/devices/ballast_cube/ballast_cube.gltf")
const LIGHT_ALBEDO: Texture2D = preload("res://content/textures/expedition/ballast_5kg_albedo.jpg")
const HEAVY_ALBEDO: Texture2D = preload("res://content/textures/expedition/ballast_10kg_albedo.jpg")
const BALLAST_NORMAL: Texture2D = preload("res://content/textures/ambientcg/ballast_powder_normal.png")
const BALLAST_ORM: Texture2D = preload("res://content/textures/ambientcg/ballast_powder_orm.png")


## The carry-cube model, normalised to a 1 m cube centred on its body, scaled to the given edge.
static func ballast_cube(edge: float, heavy: bool = false) -> Node3D:
	var visual: Node3D = BALLAST_CUBE.instantiate() as Node3D
	visual.name = "Visual"
	visual.scale = Vector3.ONE * edge
	var cube: MeshInstance3D = visual.get_node("Cube") as MeshInstance3D
	apply_atlas(cube, BALLAST_NORMAL, BALLAST_ORM, HEAVY_ALBEDO if heavy else LIGHT_ALBEDO)
	return visual


## Sample packed device atlases without wrapping across unrelated UV islands.
static func apply_atlas(mesh: MeshInstance3D, normal: Texture2D, orm: Texture2D,
		albedo: Texture2D = null) -> void:
	for index: int in range(mesh.mesh.get_surface_count()):
		var source: StandardMaterial3D = mesh.get_active_material(index) as StandardMaterial3D
		if source == null:
			continue
		var material: StandardMaterial3D = source.duplicate() as StandardMaterial3D
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.texture_repeat = false
		material.normal_enabled = true
		material.normal_texture = normal
		material.roughness_texture = orm
		material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		material.metallic_texture = orm
		material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		if albedo != null:
			material.albedo_texture = albedo
		mesh.set_surface_override_material(index, material)
