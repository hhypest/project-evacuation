class_name CarryProfile
extends RefCounted
## SI units: metres, kilograms, seconds, newtons and newton-seconds.

var min_mass: float = 1.0
var max_mass: float = 40.0
var reference_mass: float = 20.0
var reach: float = 3.0
var hold_distance: float = 2.2
var minimum_distance: float = 1.35
var break_distance: float = 4.0
var break_error: float = 1.3
var break_delay: float = 0.6
var clearance: float = 0.04
var spring: float = 850.0
var damping: float = 180.0
var max_force: float = 1200.0
var angular_spring: float = 24.0
var angular_damping: float = 10.0
var max_torque: float = 80.0
var max_hold_speed: float = 8.0
var max_angular_speed: float = 6.0
var throw_impulse: float = 120.0
var max_throw_speed: float = 12.0
var friction: float = 0.7
var bounce: float = 0.0


func accepts_mass(value: float) -> bool:
	return is_finite(value) and value >= min_mass and value <= max_mass


func is_valid() -> bool:
	var values: Array[float] = [min_mass, max_mass, reference_mass, reach, hold_distance, minimum_distance,
		break_distance, break_error, break_delay, clearance, spring, damping, max_force,
		angular_spring, angular_damping, max_torque, max_hold_speed, max_angular_speed,
		throw_impulse, max_throw_speed, friction, bounce]
	for value: float in values:
		if not is_finite(value) or value < 0.0:
			return false
	return min_mass > 0 and max_mass >= min_mass and reference_mass > 0 and reach > 0 \
		and hold_distance >= minimum_distance and minimum_distance > 0 \
		and break_distance > hold_distance and break_error > 0 and break_delay > 0 \
		and clearance > 0 and spring > 0 and damping > 0 and max_force > 0 \
		and angular_spring > 0 and angular_damping > 0 and max_torque > 0 \
		and max_hold_speed > 0 and max_angular_speed > 0 and max_throw_speed > 0 \
		and friction <= 1 and bounce <= 1
