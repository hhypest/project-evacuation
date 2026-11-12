class_name PropVisuals
extends RefCounted
## Art models for code-built props. Visual only: every collision stays the tested primitive shape, so
## swapping art never changes physics or level traversal (ADR-0006, ART-04). Models: content/models.

const BALLAST_CUBE: PackedScene = preload("res://content/models/devices/ballast_cube/ballast_cube.gltf")


## The carry-cube model, normalised to a 1 m cube centred on its body, scaled to the given edge.
static func ballast_cube(edge: float = 1.0) -> Node3D:
	var visual: Node3D = BALLAST_CUBE.instantiate() as Node3D
	visual.name = "Visual"
	visual.scale = Vector3.ONE * edge
	# Match the portal clipping shader's anisotropic sampling on the ordinary imported cube too.
	for child: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = child as MeshInstance3D
		for index: int in range(mesh.mesh.get_surface_count()):
			var source: BaseMaterial3D = mesh.get_active_material(index) as BaseMaterial3D
			if source != null:
				var material: BaseMaterial3D = source.duplicate() as BaseMaterial3D
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				# A packed atlas is not a tile: opposite image borders contain unrelated UV islands.
				material.texture_repeat = false
				mesh.set_surface_override_material(index, material)
	return visual
