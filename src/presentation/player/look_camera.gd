class_name LookCamera
extends Camera3D
## Stationary first-person look; locomotion belongs to SKL-02.

@export var radians_per_pixel: float = 0.0025
@export_range(1.0, 89.0) var pitch_limit_degrees: float = 85.0


func apply_look(delta_pixels: Vector2) -> void:
	rotation.y = wrapf(rotation.y - delta_pixels.x * radians_per_pixel, -PI, PI)
	var limit: float = deg_to_rad(pitch_limit_degrees)
	rotation.x = clampf(rotation.x - delta_pixels.y * radians_per_pixel, -limit, limit)
