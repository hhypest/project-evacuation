class_name GravityWorldAdapter
extends GravityWorldPort
## Registry of a chamber's gravity fields. Power is applied by the device network; this adapter only
## answers spatial questions and aligns engine area priorities with GravityRules.

var _fields: Dictionary[StringName, GravityFieldDevice] = {}
var _base: GravityZone


func configure(level: Node) -> void:
	_base = _read_base()
	_collect(level)
	var ranked: Array[StringName] = GravityRules.rank(zones())
	for index: int in range(ranked.size()):
		_fields[ranked[index]].set_engine_priority(index + 1)


func _collect(node: Node) -> void:
	var field: GravityFieldDevice = node as GravityFieldDevice
	if field != null and not _fields.has(field.stable_id):
		_fields[field.stable_id] = field
	for child: Node in node.get_children():
		_collect(child)


func zones() -> Array[GravityZone]:
	var result: Array[GravityZone] = []
	for id: StringName in _fields.keys():
		var field: GravityFieldDevice = _fields[id]
		if is_instance_valid(field):
			result.append(field.zone())
	return result


func zones_at(point: Vector3) -> Array[GravityZone]:
	var result: Array[GravityZone] = []
	for id: StringName in _fields.keys():
		var field: GravityFieldDevice = _fields[id]
		if is_instance_valid(field) and field.is_inside_tree() and field.contains(point):
			result.append(field.zone())
	return result


func base() -> GravityZone:
	return _base if _base != null else super.base()


func close() -> void:
	_fields.clear()


## Project default gravity is the level base. ProjectSettings returns Variant; types are checked here.
func _read_base() -> GravityZone:
	var magnitude: Variant = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var vector: Variant = ProjectSettings.get_setting("physics/3d/default_gravity_vector", Vector3.DOWN)
	var strength: float = 9.8
	var direction: Vector3 = Vector3.DOWN
	if magnitude is float:
		@warning_ignore("unsafe_cast")
		strength = magnitude as float
	if vector is Vector3:
		@warning_ignore("unsafe_cast")
		direction = (vector as Vector3).normalized()
	return GravityZone.make(&"level.base", -2147483648, direction, strength)
