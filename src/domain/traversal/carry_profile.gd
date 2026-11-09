class_name CarryProfile
extends RefCounted
## SI units: metres, kilograms, seconds, radians and newton-seconds.
## Talos-style hold (ADR-0012): the prop sticks to a point in front of the carrier instead of being pulled by forces.

var min_mass: float = 1.0
var max_mass: float = 40.0
## Grab ray length from the eyes.
var reach: float = 3.0
## Height of the held prop's centre above the carrier's feet, along the carrier's up.
var hold_height: float = 0.75
## Gap between the carrier's capsule and the held prop's near face.
var hold_gap: float = 0.15
## How far looking straight up or down moves the hold point along the carrier's up.
var pitch_lift: float = 0.9
## Speed limits of the snap toward the hold point; high enough to read as "sticking".
var pull_speed: float = 14.0
var turn_speed: float = 12.0
## A prop blocked further than this from its hold point for break_delay seconds is dropped.
var break_distance: float = 1.5
var break_delay: float = 0.5
## Sweep clearance against the world.
var clearance: float = 0.04
var throw_impulse: float = 120.0
var max_throw_speed: float = 12.0
var friction: float = 0.7
var bounce: float = 0.0
## Placement (ADR-0012): a held prop aimed at a floor button or a resting prop within place_reach of the eyes
## shows its silhouette there and is set down exactly in it.
var place_reach: float = 3.5
## Gap left under a placed prop so it starts free of its support.
var place_lift: float = 0.01
## A support tilted further than this (radians) has no level top face to set a prop on.
var level_tilt: float = 0.26
## A support moving faster than this is not resting and takes no prop.
var support_speed: float = 0.25
## The prop glides to its slot at pull_speed; within place_settle metres, or after place_timeout seconds,
## it is set exactly in the slot if that is still free.
var place_settle: float = 0.08
var place_timeout: float = 0.35


func accepts_mass(value: float) -> bool:
	return is_finite(value) and value >= min_mass and value <= max_mass


func is_valid() -> bool:
	var values: Array[float] = [min_mass, max_mass, reach, hold_height, hold_gap, pitch_lift, pull_speed,
		turn_speed, break_distance, break_delay, clearance, throw_impulse, max_throw_speed, friction, bounce,
		place_reach, place_lift, level_tilt, support_speed, place_settle, place_timeout]
	for value: float in values:
		if not is_finite(value) or value < 0.0:
			return false
	return min_mass > 0 and max_mass >= min_mass and reach > 0 and hold_height > 0 \
		and pull_speed > 0 and turn_speed > 0 and break_distance > 0 and break_delay > 0 \
		and clearance > 0 and max_throw_speed > 0 and friction <= 1 and bounce <= 1 \
		and place_reach > 0 and level_tilt < PI * 0.25 and support_speed > 0 and place_settle > 0 \
		and place_timeout > 0
