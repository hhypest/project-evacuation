class_name PortalBodyState
extends RefCounted
## Physical state of a dynamic body near portals, read from the last completed physics step.

var id: StringName = &""
var transform: Transform3D = Transform3D.IDENTITY
var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
## Largest half extent of the body, metres.
var extent: float = 0.5
var half_extents: Vector3 = Vector3.ONE * 0.5
var is_player: bool = false
## A held body crosses together with its carrier, never independently before the carrier crosses.
var carrier_id: StringName = &""
var held: bool = false
