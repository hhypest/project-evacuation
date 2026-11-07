class_name TestPlatform
extends AnimatableBody3D
## Repeating fixture motion, intentionally independent of render FPS.

@export var distance: float = 2.0
@export var angular_speed: float = 0.8
var _home: Vector3
var _time: float = 0.0


func _ready() -> void:
	_home = position
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	_time += delta
	position = _home + Vector3.RIGHT * sin(_time * angular_speed) * distance
