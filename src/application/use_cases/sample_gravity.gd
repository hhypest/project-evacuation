class_name SampleGravity
extends RefCounted
## Resolves the one effective field at a point. Bodies get the same rule through engine area priorities.

var errors: PackedStringArray = PackedStringArray()
var _world: GravityWorldPort


func _init(world: GravityWorldPort) -> void:
	_world = world
	errors = GravityRules.validate(world.zones())
	errors.append_array(world.base().validate())


func ready() -> bool:
	return errors.is_empty()


func at(point: Vector3) -> GravityZone:
	return GravityRules.select(_world.zones_at(point), _world.base())


func base() -> GravityZone:
	return _world.base()
