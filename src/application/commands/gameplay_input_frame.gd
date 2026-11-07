class_name GameplayInputFrame
extends RefCounted
## Input consumed once per physics tick; generation prevents stale scope delivery.

var generation: int = 0
var move_axis: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var jump_requested: bool = false
var interact_requested: bool = false
var crouching: bool = false
var walking: bool = false
