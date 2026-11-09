class_name CarryObservation
extends RefCounted

var id: StringName = &""
var mass: float = 0.0
var position: Vector3 = Vector3.ZERO
var basis: Basis = Basis.IDENTITY
var velocity: Vector3 = Vector3.ZERO
## Half of the prop's widest horizontal size, used to keep it clear of the carrier's capsule.
var half_extent: float = 0.5
## Half of the prop's height in its upright hold, used to keep the hold point above the carrier's floor.
var half_height: float = 0.5
## Full size of the prop's box in its own axes.
var size: Vector3 = Vector3.ONE
