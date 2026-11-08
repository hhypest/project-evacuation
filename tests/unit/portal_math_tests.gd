class_name PortalMathTests
extends TestSuite
## Portal transfer math, swept crossing and re-entry guard (Architecture §10).


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	# A faces +Z at the origin; B faces -X at (6, 0, 1): the two are 90° apart.
	var a: Transform3D = Transform3D(Basis.IDENTITY, Vector3.ZERO)
	var b: Transform3D = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(6, 0, 1))
	var behind_a: Vector3 = Vector3(0.3, 0.2, -0.1)
	var out: Vector3 = b.affine_inverse() * PortalMath.map_point(a, b, a * behind_a)
	results.append(TestOutcome.new("a point just behind the entry maps just in front of the exit, mirrored across",
		out.is_equal_approx(Vector3(-0.3, 0.2, 0.1)), str(out)))
	var into_a: Vector3 = Vector3(0.5, -1.0, -4.0)
	var mapped: Vector3 = PortalMath.map_vector(a, b, into_a)
	var local_out: Vector3 = b.basis.inverse() * mapped
	results.append(TestOutcome.new("velocity into the entry leaves the exit along its front, speed preserved",
		local_out.is_equal_approx(Vector3(-0.5, -1.0, 4.0)) and is_equal_approx(mapped.length(), into_a.length()), str(local_out)))
	var spin: Vector3 = Vector3(1, 2, 3)
	results.append(TestOutcome.new("angular velocity rotates without translation",
		PortalMath.map_vector(a, b, spin).length() == spin.length() and PortalMath.map_vector(a, b, Vector3.ZERO) == Vector3.ZERO))
	var trip: Transform3D = PortalMath.transfer(b, a) * PortalMath.transfer(a, b)
	results.append(TestOutcome.new("A to B then B to A is the identity", trip.is_equal_approx(Transform3D.IDENTITY), str(trip)))
	var body: Transform3D = Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0.1, 0.5, -0.2))
	var moved: Transform3D = PortalMath.map_transform(a, b, body)
	results.append(TestOutcome.new("orientation stays orthonormal and right-handed after transfer",
		moved.basis.get_scale().is_equal_approx(Vector3.ONE) and moved.basis.determinant() > 0.999))
	var plane: PortalPlane = PortalPlane.make(&"a", a, Vector2(0.8, 1.2))
	results.append(TestOutcome.new("front to back through the opening is a crossing",
		PortalRules.crosses(plane, Vector3(0.2, 0.0, 0.3), Vector3(0.2, 0.0, -0.05))))
	results.append(TestOutcome.new("a fast body crossing in one tick is still detected (swept segment)",
		PortalRules.crosses(plane, Vector3(0, 0, 0.4), Vector3(0, 0, -0.42))))
	results.append(TestOutcome.new("back to front, beside the opening or parallel motion are not crossings",
		not PortalRules.crosses(plane, Vector3(0, 0, -0.3), Vector3(0, 0, 0.2))
		and not PortalRules.crosses(plane, Vector3(1.0, 0, 0.3), Vector3(1.0, 0, -0.1))
		and not PortalRules.crosses(plane, Vector3(0, 0, 0.0), Vector3(0.5, 0, 0.0))))
	results.append(TestOutcome.new("the exit guard holds until the body is clear of the exit front volume",
		not PortalRules.guard_released(plane, Vector3(0, 0, 0.3), 0.5) and PortalRules.guard_released(plane, Vector3(0, 0, 0.7), 0.5)))
	var scaled: PortalPlane = PortalPlane.make(&"s", Transform3D(Basis.IDENTITY.scaled(Vector3(2, 1, 1)), Vector3.ZERO), Vector2(0.8, 1.2))
	var tiny: PortalPlane = PortalPlane.make(&"", a, Vector2(0.05, 1.0))
	results.append(TestOutcome.new("portal validation rejects scale, an empty ID and a tiny opening",
		scaled.validate().size() == 1 and tiny.validate().size() == 2, ", ".join(scaled.validate() + tiny.validate())))
	return results
