class_name CarryInput
extends RefCounted

var scope_id: int = -1
var tick_id: int = -1
var delta: float = 1.0 / 60.0
var view: Transform3D = Transform3D.IDENTITY
## Carrier frame for the Talos-style hold: feet, current up (gravity-aware) and capsule radius.
var carrier_feet: Vector3 = Vector3.ZERO
var carrier_up: Vector3 = Vector3.UP
var carrier_radius: float = 0.3
var carrier_velocity: Vector3 = Vector3.ZERO
var interact: bool = false
var throw_requested: bool = false
