class_name PortalMath
extends RefCounted
## Portal space transfer (Architecture §10). Both portals face their local +Z; H turns 180° about local up,
## so a point in front of the entry maps behind the exit and a body crossing the entry emerges in front of
## the exit. Transforms must be orthonormal without scale.

static var H: Basis = Basis(Vector3.UP, PI)


## M = B * H * inverse(A): maps world space at the entry onto world space at the exit.
static func transfer(entry: Transform3D, exit: Transform3D) -> Transform3D:
	return exit * Transform3D(H, Vector3.ZERO) * entry.affine_inverse()


static func map_point(entry: Transform3D, exit: Transform3D, point: Vector3) -> Vector3:
	return transfer(entry, exit) * point


## Directions and velocities rotate only; they never receive the translation.
static func map_vector(entry: Transform3D, exit: Transform3D, vector: Vector3) -> Vector3:
	return transfer(entry, exit).basis * vector


static func map_transform(entry: Transform3D, exit: Transform3D, value: Transform3D) -> Transform3D:
	var mapped: Transform3D = transfer(entry, exit) * value
	mapped.basis = mapped.basis.orthonormalized()
	return mapped
