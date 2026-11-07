class_name CarrySettings
extends Resource
## Authoring boundary. Only the copied profile enters Application.

@export var min_mass: float = 1.0
@export var max_mass: float = 40.0
@export var reference_mass: float = 20.0
@export var reach: float = 3.0
@export var hold_distance: float = 2.2
@export var minimum_distance: float = 1.35
@export var break_distance: float = 4.0
@export var break_error: float = 1.3
@export var break_delay: float = 0.6
@export var clearance: float = 0.04
@export var spring: float = 850.0
@export var damping: float = 180.0
@export var max_force: float = 1200.0
@export var angular_spring: float = 24.0
@export var angular_damping: float = 10.0
@export var max_torque: float = 80.0
@export var max_hold_speed: float = 8.0
@export var max_angular_speed: float = 6.0
@export var throw_impulse: float = 120.0
@export var max_throw_speed: float = 12.0
@export var friction: float = 0.7
@export var bounce: float = 0.0


func to_profile() -> CarryProfile:
	var profile: CarryProfile = CarryProfile.new()
	profile.min_mass = min_mass
	profile.max_mass = max_mass
	profile.reference_mass = reference_mass
	profile.reach = reach
	profile.hold_distance = hold_distance
	profile.minimum_distance = minimum_distance
	profile.break_distance = break_distance
	profile.break_error = break_error
	profile.break_delay = break_delay
	profile.clearance = clearance
	profile.spring = spring
	profile.damping = damping
	profile.max_force = max_force
	profile.angular_spring = angular_spring
	profile.angular_damping = angular_damping
	profile.max_torque = max_torque
	profile.max_hold_speed = max_hold_speed
	profile.max_angular_speed = max_angular_speed
	profile.throw_impulse = throw_impulse
	profile.max_throw_speed = max_throw_speed
	profile.friction = friction
	profile.bounce = bounce
	return profile
