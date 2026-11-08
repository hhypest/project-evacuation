class_name LookCamera
extends Camera3D
## First-person view. LevelScope follows the motor's eye position after physics movement.
## Yaw and pitch live in a gravity frame whose +Y follows the player's up; with base gravity the frame
## is identity and the camera behaves exactly as a plain yaw/pitch camera.

@export var radians_per_pixel: float = 0.0025
@export_range(1.0, 89.0) var pitch_limit_degrees: float = 85.0
## Comfort smoothing of the view turn when the field changes; physics turns instantly.
@export_range(30.0, 1440.0) var align_degrees_per_second: float = 360.0

var frame: Basis = Basis.IDENTITY


func _ready() -> void:
	# Portal stubs exist only for portal cameras (layer 20); the player sees live membranes.
	set_cull_mask_value(20, false)


func apply_look(delta_pixels: Vector2) -> void:
	var local: Vector3 = (frame.inverse() * global_basis.orthonormalized()).get_euler()
	var yaw: float = wrapf(local.y - delta_pixels.x * radians_per_pixel, -PI, PI)
	var limit: float = deg_to_rad(pitch_limit_degrees)
	var pitch: float = clampf(local.x - delta_pixels.y * radians_per_pixel, -limit, limit)
	global_basis = frame * Basis.from_euler(Vector3(pitch, yaw, 0.0))


## Turns the frame toward the player's up by at most the comfort rate; the view turns with it.
func align_to(up: Vector3, delta: float) -> void:
	var current: Vector3 = frame.y.normalized()
	if not up.is_finite() or up.is_zero_approx() or current.dot(up.normalized()) > 0.99999:
		return
	var target: Vector3 = up.normalized()
	var angle: float = current.angle_to(target)
	var axis: Vector3 = current.cross(target)
	if axis.length() < 0.000001:
		axis = frame.x
	var turn: Basis = Basis(axis.normalized(), minf(angle, deg_to_rad(align_degrees_per_second) * delta))
	frame = (turn * frame).orthonormalized()
	global_basis = (turn * global_basis).orthonormalized()
