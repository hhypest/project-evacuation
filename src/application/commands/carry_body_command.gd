class_name CarryBodyCommand
extends RefCounted

var scope_id: int = -1
var tick_id: int = -1
## Pose of the held (kinematic) prop this tick.
var target: Transform3D = Transform3D.IDENTITY
## Velocity the prop keeps when it is let go, so a drop on the move does not stop dead.
var carrier_velocity: Vector3 = Vector3.ZERO
var releasing: bool = false
var impulse: Vector3 = Vector3.ZERO
## A release that first sets the prop exactly at target (placement into a checked free slot).
var placing: bool = false
