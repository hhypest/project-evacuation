class_name GravityRules
extends RefCounted
## Single effective gravity source: among powered zones the highest priority wins, ties go to the
## smallest stable ID; outside every powered zone the level base gravity applies (Architecture §9).


static func select(zones: Array[GravityZone], base: GravityZone) -> GravityZone:
	var best: GravityZone = null
	for zone: GravityZone in zones:
		if zone == null or not zone.powered:
			continue
		if best == null or _precedes(zone, best):
			best = zone
	return best if best != null else base


## Zone IDs from the least to the most effective. Engines that resolve overlapping areas by an integer
## priority receive (index + 1), so the engine order equals the rule order for bodies.
static func rank(zones: Array[GravityZone]) -> Array[StringName]:
	var ordered: Array[GravityZone] = zones.duplicate()
	ordered.sort_custom(func(a: GravityZone, b: GravityZone) -> bool: return _precedes(b, a))
	var ids: Array[StringName] = []
	for zone: GravityZone in ordered:
		ids.append(zone.id)
	return ids


static func validate(zones: Array[GravityZone]) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var seen: Dictionary[StringName, bool] = {}
	for zone: GravityZone in zones:
		errors.append_array(zone.validate())
		if seen.has(zone.id):
			errors.append("duplicate gravity zone ID '%s'" % zone.id)
		seen[zone.id] = true
	return errors


static func _precedes(a: GravityZone, b: GravityZone) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	return String(a.id) < String(b.id)
