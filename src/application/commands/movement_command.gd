class_name MovementCommand
extends RefCounted

var move_axis: Vector2 = Vector2.ZERO
var forward: Vector3 = Vector3.FORWARD
var jump_requested: bool = false
var jump_held: bool = false
var crouching: bool = false
var walking: bool = false
var sprinting: bool = false
