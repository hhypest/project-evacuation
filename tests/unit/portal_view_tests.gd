class_name PortalViewTests
extends TestSuite


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var half: Vector2 = Vector2(0.8, 1.2)
	var tangents: Vector2 = Vector2(1.0, 0.5625)
	var viewer: Transform3D = Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.2, 0.1, 0.03))
	var patch: Rect2 = PortalViewGeometry.visible_region(half, viewer.affine_inverse(), tangents)
	var region: Rect2 = PortalViewGeometry.fit_aspect(patch, 16.0 / 9.0)
	var all_visible: bool = true
	var rays: int = 0
	for y: int in range(5):
		for x: int in range(5):
			var ray: Vector3 = viewer.basis * Vector3((float(x) / 2.0 - 1.0) * tangents.x,
				(float(y) / 2.0 - 1.0) * tangents.y, -1.0)
			if ray.z >= 0.0:
				continue
			var point: Vector3 = viewer.origin + ray * (-viewer.origin.z / ray.z)
			if absf(point.x) <= half.x and absf(point.y) <= half.y:
				rays += 1
				all_visible = all_visible and region.has_point(Vector2(point.x, point.y))
	results.append(TestOutcome.new("close yawed portal crop contains every visible screen ray at the aperture",
		all_visible and rays > 10, "rays %d patch %s" % [rays, region]))
	results.append(TestOutcome.new("close-up uses pixels for the visible patch, not the whole 1.6 by 2.4 m aperture",
		region.has_area() and region.get_area() < half.x * half.y * 4.0 * 0.02, str(region)))
	var uv: Vector4 = PortalViewGeometry.uv_region(region, half)
	var centre: Vector2 = region.get_center()
	var original_uv: Vector2 = Vector2((centre.x + half.x) / (2.0 * half.x), (half.y - centre.y) / (2.0 * half.y))
	var sampled: Vector2 = (original_uv - Vector2(uv.x, uv.y)) / Vector2(uv.z, uv.w)
	results.append(TestOutcome.new("cropped membrane UVs put the centre of the visible patch at the texture centre",
		sampled.is_equal_approx(Vector2(0.5, 0.5))))
	var away: Transform3D = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 1))
	results.append(TestOutcome.new("portal behind the camera has no visible patch",
		not PortalViewGeometry.visible_region(half, away.affine_inverse(), tangents).has_area()))
	var normal: Vector2i = PortalViewGeometry.target_size(Vector2i(1920, 1080))
	var huge: Vector2i = PortalViewGeometry.target_size(Vector2i(16000, 9000))
	results.append(TestOutcome.new("render target is native at 1080p and bounded for huge windows",
		normal == Vector2i(1920, 1080) and huge.x <= 4096 and huge.y <= 4096
		and float(huge.x) * huge.y <= PortalViewGeometry.MAX_PIXELS, str(huge)))
	var plane: PortalPlane = PortalPlane.make(&"a", Transform3D.IDENTITY, half)
	var aperture: Rect2 = Rect2(-half, half * 2.0)
	var ahead: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 0, 3))
	var wall: AABB = AABB(Vector3(-2, -2, 1), Vector3(4, 4, 0.3))
	var edge: AABB = AABB(Vector3(0, -2, 1), Vector3(2, 4, 0.3))
	var behind: AABB = AABB(Vector3(-2, -2, -1), Vector3(4, 4, 0.3))
	results.append(TestOutcome.new("portal culling requires one opaque box in front of the entire aperture",
		PortalViewGeometry.hidden_by_box(aperture, Transform3D.IDENTITY, ahead, 0.05, [wall])
		and not PortalViewGeometry.hidden_by_box(aperture, Transform3D.IDENTITY, ahead, 0.05, [edge, behind])))
	var inside: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.15))
	results.append(TestOutcome.new("portal culling preserves near-plane views when the viewer is inside a blocker",
		not PortalViewGeometry.hidden_by_box(aperture, Transform3D.IDENTITY, inside, 0.05, [wall])))
	results.append(TestOutcome.new("centre-only opening hit does not admit an oversized or rotated shape",
		PortalRules.fits(plane, Transform3D.IDENTITY, Vector3(0.3, 0.9, 0.3))
		and not PortalRules.fits(plane, Transform3D(Basis.IDENTITY, Vector3(0.5, 0, 0)), Vector3.ONE * 0.5)
		and not PortalRules.fits(plane, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3.ZERO), Vector3(0.3, 0.9, 0.3))))
	return results
