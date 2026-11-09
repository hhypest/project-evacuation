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
	return visual
