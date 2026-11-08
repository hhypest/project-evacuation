class_name PortalBodyState
extends RefCounted
## Physical state of a dynamic body near portals, read from the last completed physics step.

var id: StringName = &""
var transform: Transform3D = Transform3D.IDENTITY
var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
## Largest half extent of the body, metres.
var extent: float = 0.5
## Held bodies are not transferred in SKL-08; carry integration is SKL-09.
var held: bool = false
