class_name MovementVolume
extends Area3D

enum Kind { LADDER, WATER }

@export var kind: Kind = Kind.LADDER
@export var surface_height: float = 0.3
