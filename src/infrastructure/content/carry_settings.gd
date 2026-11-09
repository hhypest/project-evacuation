class_name CarrySettings
extends Resource
## Authoring boundary. Only the copied profile enters Application. Units and meaning: CarryProfile.

@export var min_mass: float = 1.0
@export var max_mass: float = 40.0
@export var reach: float = 3.0
@export var hold_height: float = 0.75
@export var hold_gap: float = 0.15
@export var pitch_lift: float = 0.9
@export var pull_speed: float = 14.0
@export var turn_speed: float = 12.0
@export var break_distance: float = 1.5
@export var break_delay: float = 0.5
@export var clearance: float = 0.04
@export var throw_impulse: float = 120.0
@export var max_throw_speed: float = 12.0
@export var friction: float = 0.7
@export var bounce: float = 0.0


func to_profile() -> CarryProfile:
	var profile: CarryProfile = CarryProfile.new()
	profile.min_mass = min_mass
	profile.max_mass = max_mass
	profile.reach = reach
	profile.hold_height = hold_height
	profile.hold_gap = hold_gap
	profile.pitch_lift = pitch_lift
	profile.pull_speed = pull_speed
	profile.turn_speed = turn_speed
	profile.break_distance = break_distance
	profile.break_delay = break_delay
	profile.clearance = clearance
	profile.throw_impulse = throw_impulse
	profile.max_throw_speed = max_throw_speed
	profile.friction = friction
	profile.bounce = bounce
	return profile
