class_name CarryRigidBody
extends RigidBody3D
## Held: a kinematic body placed once per physics tick by the carry adapter (ADR-0012).
## Released: an ordinary Jolt body again; a throw impulse is applied once in the direct-body callback.

@export var stable_id: StringName = &""

var last_applied_tick: int = -1
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
	# Talos-style hold (ADR-0012): while held the prop is a kinematic body placed by the carry adapter.
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	return true


func submit(command: CarryBodyCommand) -> bool:
	if not _held or command.scope_id != _scope_id or command.tick_id <= _last_received_tick:
		return false
	_last_received_tick = command.tick_id
	if command.releasing:
		if command.placing:
			# The adapter checked that the slot is free; the prop starts there at rest.
			global_transform = command.target
		_let_go(command.carrier_velocity)
		_pending = command
		return true
	# Called from the coordinator's physics tick, never per render frame; the body is kinematic here.
	global_transform = command.target
	last_applied_tick = command.tick_id
	return true


func cancel_pending() -> void:
	_pending = null


func close() -> void:
	_scope_id = -1
	if _held:
		_let_go(Vector3.ZERO)
	cancel_pending()


func _let_go(velocity: Vector3) -> void:
	_held = false
	freeze = false
	linear_velocity = velocity.limit_length(_profile.max_throw_speed if _profile != null else velocity.length())
	angular_velocity = Vector3.ZERO
	sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending == null or _scope_id < 0:
		return
	var command: CarryBodyCommand = _pending
	_pending = null
	last_applied_tick = command.tick_id
	if command.releasing and command.impulse != Vector3.ZERO:
		state.apply_central_impulse(command.impulse)
		state.linear_velocity = state.linear_velocity.limit_length(_profile.max_throw_speed)
