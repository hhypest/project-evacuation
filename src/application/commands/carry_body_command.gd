class_name CarryBodyCommand
extends RefCounted

var scope_id: int = -1
var tick_id: int = -1
var target: Transform3D = Transform3D.IDENTITY
var carrier_velocity: Vector3 = Vector3.ZERO
var releasing: bool = false
var impulse: Vector3 = Vector3.ZERO
