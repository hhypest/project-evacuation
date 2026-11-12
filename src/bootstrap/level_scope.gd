class_name LevelScope
extends Node
## Owns one chamber generation. Detached scopes reject input before they are freed.

var _generation: int = -1
var _level: Node3D
var _camera: LookCamera
var _player: PlayerMotor
var _carry: CarryController
var _ghost: CarryGhost
var _puzzle: AdvancePuzzle
var _gravity: SampleGravity
var _gravity_world: GravityWorldAdapter
var _portals: AdvancePortals
var _portal_world: PortalWorldAdapter
var _tick_id: int = 0


func open(scene: PackedScene, generation: int) -> bool:
	if _level != null or scene == null or not scene.can_instantiate():
		return false
	var instance: Node = scene.instantiate()
	if instance == null:
		return false
	var level: Node3D = instance as Node3D
	if level == null:
		instance.free()
		return false
	var camera: LookCamera = level.get_node_or_null("Camera") as LookCamera
	var player: PlayerMotor = level.get_node_or_null("Player") as PlayerMotor
	if camera == null or player == null:
		level.free()
		return false
	var profile: CarryProfile = (preload("res://content/definitions/default_carry.tres") as CarrySettings).to_profile()
	if not profile.is_valid():
		level.free()
		return false
	_generation = generation
	_level = level
	_camera = camera
	_player = player
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	var carry_world: CarryPhysicsAdapter = CarryPhysicsAdapter.new()
	if not carry_world.configure(level, player, profile, generation):
		carry_world.close()
		_abort_open()
		return false
	_carry = CarryController.new(carry_world, profile, generation)
	_ghost = CarryGhost.new()
	level.add_child(_ghost)
	var settings: PuzzleSettings = preload("res://content/definitions/default_puzzle.tres") as PuzzleSettings
	var puzzle_world: PuzzleWorldAdapter = PuzzleWorldAdapter.new()
	if settings == null or not puzzle_world.configure(level, player, settings.player_mass_kg):
		puzzle_world.close()
		_abort_open()
		return false
	_puzzle = AdvancePuzzle.new(puzzle_world, generation, settings.use_reach, Engine.physics_ticks_per_second)
	if not _puzzle.ready():
		push_error("Chamber device network rejected: " + "; ".join(_puzzle.errors))
		_puzzle.close()
		_abort_open()
		return false
	_gravity_world = GravityWorldAdapter.new()
	_gravity_world.configure(level)
	_gravity = SampleGravity.new(_gravity_world)
	if not _gravity.ready():
		push_error("Chamber gravity fields rejected: " + "; ".join(_gravity.errors))
		_puzzle.close()
		_abort_open()
		return false
	_portal_world = PortalWorldAdapter.new()
	if not _portal_world.configure(level, player, _carry):
		_abort_open()
		return false
	_portals = AdvancePortals.new(_portal_world, generation)
	if not _portals.ready():
		push_error("Chamber portals rejected: " + "; ".join(_portals.errors))
		_puzzle.close()
		_abort_open()
		return false
	_puzzle.reset()
	return true


func _abort_open() -> void:
	if _carry != null:
		_carry.close()
	_carry = null
	_ghost = null
	_puzzle = null
	_gravity = null
	if _gravity_world != null:
		_gravity_world.close()
	_gravity_world = null
	_close_portals()
	if _level != null:
		remove_child(_level)
		_level.queue_free()
	_generation = -1
	_level = null
	_camera = null
	_player = null


func apply_input(frame: GameplayInputFrame, delta: float = 1.0 / 60.0) -> void:
	if _generation < 0 or frame.generation != _generation or _camera == null:
		return
	_camera.apply_look(frame.look_delta)
	var command: MovementCommand = MovementCommand.new()
	command.move_axis = frame.move_axis
	command.forward = -_camera.global_basis.z
	command.jump_requested = frame.jump_requested
	command.jump_held = frame.jump_held
	command.crouching = frame.crouching
	command.walking = frame.walking
	command.sprinting = frame.sprinting
	# Field power comes from the previous puzzle tick, like every other device output.
	var field: GravityZone = _gravity.at(_player.center())
	_player.set_gravity(field.up(), field.strength / _gravity.base().strength)
	_portals.prepare(_generation, delta)
	if _portals.recovery_required:
		return
	_player.step(command, delta)
	_camera.align_to(_player.up_direction, delta)
	_camera.global_position = _player.eye_position()
	_tick_id += 1
	var carry_input: CarryInput = CarryInput.new()
	carry_input.scope_id = _generation
	carry_input.tick_id = _tick_id
	carry_input.delta = delta
	carry_input.view = _camera.global_transform
	carry_input.carrier_velocity = _player.velocity
	carry_input.carrier_feet = _player.global_position
	carry_input.carrier_up = _player.up_direction
	carry_input.carrier_radius = _player.profile.radius
	var interact: bool = frame.interact_requested
	# A free hand uses a wall button under the view first; otherwise E keeps its carry meaning.
	if interact and _carry.state.held_id.is_empty() and _puzzle.use(_generation, _camera.global_transform):
		interact = false
	carry_input.interact = interact
	carry_input.throw_requested = frame.throw_requested
	_carry.step(carry_input)
	_ghost.present(_carry.preview)
	_puzzle.step(_generation, _tick_id)
	var passages: Array[PortalTransfer] = _portals.step(_generation, _tick_id)
	for passage: PortalTransfer in passages:
		if passage.body_id == PortalWorldAdapter.PLAYER_ID and not passage.blocked:
			# Presentation stays in the coordinator: the physics adapter cannot depend on LookCamera.
			_camera.frame = (passage.rotation * _camera.frame).orthonormalized()
			_camera.global_basis = (passage.rotation * _camera.global_basis).orthonormalized()
			_camera.reset_physics_interpolation()
			_carry.portal_reframe(passage.rotation)
	_camera.global_position = _player.eye_position()
	# Portal commits can invalidate the pre-transfer placement preview in this same tick.
	_ghost.present(_carry.preview)


func held_prop_id() -> StringName:
	return _carry.state.held_id if _carry != null else &""


func has_placement() -> bool:
	return _carry != null and _carry.preview != null and _carry.preview.available


func configure_camera(preferences: CameraPreferences) -> void:
	if _camera != null:
		_camera.fov = preferences.fov
		_camera.radians_per_pixel = CameraPreferences.BASE_RADIANS_PER_PIXEL * preferences.sensitivity / 100.0
		_camera.align_degrees_per_second = preferences.gravity_rate


func suspend_carry() -> void:
	if _carry != null:
		_carry.suspend()
	if _puzzle != null:
		_puzzle.suspend()


func puzzle() -> AdvancePuzzle:
	return _puzzle


func gravity() -> SampleGravity:
	return _gravity


func portals() -> AdvancePortals:
	return _portals


func needs_recovery() -> bool:
	return _portals != null and _portals.recovery_required


func _close_portals() -> void:
	_portals = null
	if _portal_world != null:
		_portal_world.close()
	_portal_world = null


func close() -> void:
	_generation = -1
	if _carry != null:
		_carry.close()
	_carry = null
	_ghost = null
	if _puzzle != null:
		_puzzle.close()
	_puzzle = null
	_gravity = null
	if _gravity_world != null:
		_gravity_world.close()
	_gravity_world = null
	_close_portals()
	_camera = null
	_player = null
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
