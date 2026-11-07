class_name MovementProfile
extends RefCounted
## SI units. These are project tuning values, not claimed GoldSrc constants.

var run_speed: float = 6.0
var walk_speed: float = 2.5
var crouch_speed: float = 1.8
var ground_acceleration: float = 14.0
var air_acceleration: float = 3.0
var air_control_speed: float = 2.0
var friction: float = 8.0
var stop_speed: float = 1.5
var gravity: float = 20.0
var jump_height: float = 0.9
var step_height: float = 0.3
var floor_angle_degrees: float = 46.0
var standing_height: float = 1.8
var crouched_height: float = 0.95
var radius: float = 0.3
var standing_eye_height: float = 1.65
var crouched_eye_height: float = 0.8
var climb_speed: float = 3.0
var swim_speed: float = 3.0
var water_jump_speed: float = 7.0
var push_force: float = 400.0
var swim_acceleration: float = 12.0
var buoyancy_speed: float = 0.5
var buoyancy_acceleration: float = 1.0
var water_surface_threshold: float = 0.25
var ladder_inward_speed: float = 0.9
var ladder_detach_seconds: float = 0.35
var floor_stick_speed: float = 0.2
var floor_snap_extra: float = 0.05
var stance_clearance: float = 0.01


func jump_speed() -> float:
	return sqrt(2.0 * gravity * jump_height)
