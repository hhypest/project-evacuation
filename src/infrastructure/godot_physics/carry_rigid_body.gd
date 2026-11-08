class_name CarryRigidBody
extends RigidBody3D
## Commands are consumed once in the direct-body callback; Jolt keeps all contacts.

@export var stable_id: StringName = &""

var last_applied_tick: int = -1
var last_force: Vector3 = Vector3.ZERO
var _profile: CarryProfile
var _scope_id: int = -1
var _held: bool = false
var _last_received_tick: int = -1
var _pending: CarryBodyCommand
var _collision: CollisionShape3D


func configure(profile: CarryProfile, scope_id: int) -> bool:
	_collision = get_node_or_null("Collision") as CollisionShape3D
	if stable_id.is_empty() or _collision == null or _collision.shape is not BoxShape3D:
		return false
	if not _collision.transform.is_equal_approx(Transform3D.IDENTITY) or not global_basis.get_scale().is_equal_approx(Vector3.ONE):
		return false
	_profile = profile
	_scope_id = scope_id
	continuous_cd = true
	# Floor buttons read resting contacts to count supported load, including stacks.
	contact_monitor = true
	max_contacts_reported = 8
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = profile.friction
	material.bounce = profile.bounce
	physics_material_override = material
	return true


func carry_shape() -> Shape3D:
	return _collision.shape


func is_carried() -> bool:
	return _held


func acquire() -> bool:
	if _scope_id < 0 or _held or _pending != null or freeze:
		return false
	_held = true
	sleeping = false
	return true


func submit(command: CarryBodyCommand) -> bool:
	if not _held or command.scope_id != _scope_id or command.tick_id <= _last_received_tick:
		return false
	_last_received_tick = command.tick_id
	_pending = command
	if command.releasing:
		_held = false
	sleeping = false
	return true


func cancel_pending() -> void:
	_pending = null
	last_force = Vector3.ZERO


func close() -> void:
	_scope_id = -1
	_held = false
	cancel_pending()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	last_force = Vector3.ZERO
	if _pending == null or _scope_id < 0:
		return
	var command: CarryBodyCommand = _pending
	_pending = null
	last_applied_tick = command.tick_id
	if command.releasing:
		state.apply_central_impulse(command.impulse)
		state.linear_velocity = state.linear_velocity.limit_length(_profile.max_throw_speed)
		return
	if not _held:
		return
	last_force = CarryRules.force(command.target.origin - state.transform.origin,
		state.linear_velocity - command.carrier_velocity, state.total_gravity, mass, _profile)
	state.apply_central_force(last_force)
	var difference: Quaternion = (command.target.basis * state.transform.basis.inverse()).get_rotation_quaternion().normalized()
	if difference.w < 0.0:
		difference = Quaternion(-difference.x, -difference.y, -difference.z, -difference.w)
	var angular_error: Vector3 = Vector3.ZERO
	if difference.get_angle() > 0.001:
		angular_error = difference.get_axis() * difference.get_angle()
	var angular_acceleration: Vector3 = angular_error * _profile.angular_spring - state.angular_velocity * _profile.angular_damping
	if absf(state.inverse_inertia_tensor.determinant()) > 0.000001:
		state.apply_torque((state.inverse_inertia_tensor.inverse() * angular_acceleration).limit_length(_profile.max_torque))
	state.linear_velocity = state.linear_velocity.limit_length(_profile.max_hold_speed)
	state.angular_velocity = state.angular_velocity.limit_length(_profile.max_angular_speed)
