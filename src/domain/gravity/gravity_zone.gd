class_name GravityZone
extends RefCounted
## One directional gravity source as the rules see it: stable ID, priority, direction, magnitude and power.

const MAX_STRENGTH: float = 50.0

var id: StringName = &""
var priority: int = 0
## Unit vector of the acceleration ("down" inside the zone).
var direction: Vector3 = Vector3.DOWN
## Acceleration magnitude, m/s².
var strength: float = 9.8
var powered: bool = true


static func make(zone_id: StringName, zone_priority: int, zone_direction: Vector3, zone_strength: float,
		zone_powered: bool = true) -> GravityZone:
	var zone: GravityZone = GravityZone.new()
	zone.id = zone_id
	zone.priority = zone_priority
	zone.direction = zone_direction
	zone.strength = zone_strength
	zone.powered = zone_powered
	return zone


## Zero gravity and 6DOF flight are outside 0.1.0 (Architecture §9): a zone always pulls.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if id.is_empty():
		errors.append("gravity zone needs a stable ID")
	if not direction.is_finite() or direction.length() < 0.5 or absf(direction.length() - 1.0) > 0.001:
		errors.append("gravity zone '%s' direction must be a unit vector" % id)
	if not is_finite(strength) or strength <= 0.0 or strength > MAX_STRENGTH:
		errors.append("gravity zone '%s' strength must be in (0, %.0f] m/s²" % [id, MAX_STRENGTH])
	return errors


## Up direction for a body or the player standing in this field.
func up() -> Vector3:
	return -direction
