class_name CarryObservation
extends RefCounted

var id: StringName = &""
var mass: float = 0.0
var position: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY
var velocity: Vector3 = Vector3.ZERO
## Half of the prop's widest horizontal size, used to keep it clear of the carrier's capsule.
var half_extent: float = 0.5
