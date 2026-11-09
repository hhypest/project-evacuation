class_name MovementSettings
extends Resource
## Authoring boundary: Resource is converted once into a plain domain profile.

@export var move_speed: float = 5.1
@export var sprint_speed: float = 8.0
@export var walk_speed: float = 2.5
@export var crouch_speed: float = 1.8
@export var ground_acceleration: float = 14.0
@export var air_acceleration: float = 3.0
@export var air_control_speed: float = 2.0
@export var friction: float = 8.0
@export var stop_speed: float = 1.5
@export var gravity: float = 20.0
@export var jump_height: float = 0.9
@export var step_height: float = 0.3
@export var floor_angle_degrees: float = 46.0
@export var standing_height: float = 1.8
@export var crouched_height: float = 0.95
@export var radius: float = 0.3
@export var standing_eye_height: float = 1.65
@export var crouched_eye_height: float = 0.8
@export var climb_speed: float = 3.0
@export var swim_speed: float = 3.0
@export var water_jump_speed: float = 7.0
@export var push_force: float = 400.0
@export var swim_acceleration: float = 12.0
@export var buoyancy_speed: float = 0.5
@export var buoyancy_acceleration: float = 1.0
@export var water_surface_threshold: float = 0.25
@export var ladder_inward_speed: float = 0.9
@export var ladder_detach_seconds: float = 0.35
@export var floor_stick_speed: float = 0.2
@export var floor_snap_extra: float = 0.05
@export var stance_clearance: float = 0.01


func to_profile() -> MovementProfile:
	var profile: MovementProfile = MovementProfile.new()
	profile.move_speed = move_speed
	profile.sprint_speed = sprint_speed
	profile.walk_speed = walk_speed
	profile.crouch_speed = crouch_speed
	profile.ground_acceleration = ground_acceleration
	profile.air_acceleration = air_acceleration
	profile.air_control_speed = air_control_speed
	profile.friction = friction
	profile.stop_speed = stop_speed
	profile.gravity = gravity
	profile.jump_height = jump_height
	profile.step_height = step_height
	profile.floor_angle_degrees = floor_angle_degrees
	profile.standing_height = standing_height
	profile.crouched_height = crouched_height
	profile.radius = radius
	profile.standing_eye_height = standing_eye_height
	profile.crouched_eye_height = crouched_eye_height
	profile.climb_speed = climb_speed
	profile.swim_speed = swim_speed
	profile.water_jump_speed = water_jump_speed
	profile.push_force = push_force
	profile.swim_acceleration = swim_acceleration
	profile.buoyancy_speed = buoyancy_speed
	profile.buoyancy_acceleration = buoyancy_acceleration
	profile.water_surface_threshold = water_surface_threshold
	profile.ladder_inward_speed = ladder_inward_speed
	profile.ladder_detach_seconds = ladder_detach_seconds
	profile.floor_stick_speed = floor_stick_speed
	profile.floor_snap_extra = floor_snap_extra
	profile.stance_clearance = stance_clearance
	return profile
