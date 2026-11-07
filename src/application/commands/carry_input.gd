class_name CarryInput
extends RefCounted

var scope_id: int = -1
var tick_id: int = -1
var delta: float = 1.0 / 60.0
var view: Transform3D = Transform3D.IDENTITY
var carrier_velocity: Vector3 = Vector3.ZERO
var interact: bool = false
var throw_requested: bool = false
