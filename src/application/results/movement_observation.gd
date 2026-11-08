class_name MovementObservation
extends RefCounted

var velocity: Vector3 = Vector3.ZERO
var grounded: bool = false
var crouched: bool = false
var on_ladder: bool = false
var in_water: bool = false
var near_water_surface: bool = false
var ladder_normal: Vector3 = Vector3.BACK
var up: Vector3 = Vector3.UP
## Effective field relative to the level base gravity; the profile gravity is scaled by it.
var gravity_scale: float = 1.0
