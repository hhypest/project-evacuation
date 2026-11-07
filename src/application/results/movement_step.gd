class_name MovementStep
extends RefCounted

enum Mode { GROUND, AIR, LADDER, SWIM }

var velocity: Vector3 = Vector3.ZERO
var mode: Mode = Mode.AIR
var jumped: bool = false
