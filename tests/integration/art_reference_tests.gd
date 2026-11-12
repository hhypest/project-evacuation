class_name ArtReferenceTests
extends TestSuite
## Geometry/sampling and output behavior, independent of screenshot colors or mesh implementation.

func suite_name() -> StringName:
	return &"integration"

func run(tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var left: ArrayMesh = MetricBoxMesh.make(Vector3(2, 3, 0.2), Vector3(-1, 1.5, 0))
	var right: ArrayMesh = MetricBoxMesh.make(Vector3(2, 3, 0.2), Vector3(1, 1.5, 0))
	# Godot's heterogeneous surface arrays are kept at this engine boundary, then unpacked explicitly.
	var a: Array = left.surface_get_arrays(0)
	var b: Array = right.surface_get_arrays(0)
	var av: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var bv: PackedVector3Array = b[Mesh.ARRAY_VERTEX]
	var an: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bn: PackedVector3Array = b[Mesh.ARRAY_NORMAL]
	var au: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var bu: PackedVector2Array = b[Mesh.ARRAY_TEX_UV]
	var tangent: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
	var matched: int = 0
	var continuous: bool = true
	var density: bool = true
	var tangent_valid: bool = tangent.size() == av.size() * 4
	for i: int in range(av.size()):
		for j: int in range(bv.size()):
			if (av[i] + Vector3(-1, 1.5, 0)).is_equal_approx(bv[j] + Vector3(1, 1.5, 0)) and an[i].is_equal_approx(bn[j]):
				matched += 1
				continuous = continuous and au[i].is_equal_approx(bu[j])
		for j: int in range(av.size()):
			if an[i].is_equal_approx(an[j]):
				density = density and is_equal_approx(au[i].distance_to(au[j]) * 2.0, av[i].distance_to(av[j]))
		if tangent_valid:
			var t: Vector3 = Vector3(tangent[i * 4], tangent[i * 4 + 1], tangent[i * 4 + 2])
			tangent_valid = t.is_finite() and is_equal_approx(t.length(), 1.0) and absf(t.dot(an[i])) < 0.0001
	results.append(TestOutcome.new("adjacent wall modules share UV phase at every common face vertex", continuous and matched >= 8))
	results.append(TestOutcome.new("all six faces preserve two metres per tile and valid tangent frames", density and tangent_valid))
	results.append(TestOutcome.new("metric UV box preserves physical bounds", left.get_aabb().size.is_equal_approx(Vector3(2, 3, 0.2))))
	var lever: WallButtonDevice = WallButtonDevice.new()
	lever.mode = DeviceDefinition.WallMode.TOGGLE
	tree.root.add_child(lever)
	var lamp: MeshInstance3D = lever.get_node("Indicator/Lamp") as MeshInstance3D
	var material: StandardMaterial3D = lamp.material_override as StandardMaterial3D
	var moving: Node3D = lever.get_node("Housing/Lever") as Node3D
	var rest: Transform3D = moving.transform
	lever.show_output(true, 0.0)
	var on: Transform3D = moving.transform
	var lit: bool = material.emission_enabled and material.emission_energy_multiplier > 0.0
	lever.show_output(true, 0.0)
	var stable: bool = moving.transform.is_equal_approx(on)
	lever.show_output(false, 0.0)
	results.append(TestOutcome.new("DEV-04 output drives lens and lever idempotently and returns to rest",
		lit and stable and not material.emission_enabled and material.albedo_color == WallButtonDevice.LENS_OFF
		and not on.is_equal_approx(rest) and moving.transform.is_equal_approx(rest)))
	results.append(TestOutcome.new("DEV-04 indicator adds visual geometry without physics bodies",
		lever.get_node("Indicator").find_children("*", "CollisionObject3D", true, false).is_empty()))
	lever.free()
	var cube: Node3D = PropVisuals.ballast_cube()
	var sample: MeshInstance3D = cube.get_node("Cube") as MeshInstance3D
	var pbr: BaseMaterial3D = sample.get_active_material(0) as BaseMaterial3D
	var clipped: ShaderMaterial = PortalPropVisual._material(pbr)
	var normal_parameter: Variant = clipped.get_shader_parameter(&"normal_map")
	var albedo_parameter: Variant = clipped.get_shader_parameter(&"albedo_map")
	var textures_match: bool = false
	if normal_parameter is Texture2D and albedo_parameter is Texture2D:
		var clipped_normal: Texture2D = normal_parameter
		var clipped_albedo: Texture2D = albedo_parameter
		textures_match = clipped_normal == pbr.normal_texture and clipped_albedo == pbr.albedo_texture
	var repeat_parameter: Variant = clipped.get_shader_parameter(&"repeat_enabled")
	var clamp_matches: bool = false
	if repeat_parameter is bool:
		var repeats: bool = repeat_parameter
		clamp_matches = not repeats and not pbr.texture_repeat
	results.append(TestOutcome.new("cube's portal halves preserve PBR textures and ordinary sampling quality",
		pbr.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		and textures_match and clamp_matches))
	cube.free()
	return results
