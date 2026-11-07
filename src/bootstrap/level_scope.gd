class_name LevelScope
extends Node
## Owns one chamber generation. Detached scopes reject input before they are freed.

var _generation: int = -1
var _level: Node3D
var _camera: LookCamera
var _player: PlayerMotor


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
	_generation = generation
	_level = level
	_camera = camera
	_player = player
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	return true


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
	_player.step(command, delta)
	_camera.global_position = _player.eye_position()


func close() -> void:
	_generation = -1
	_camera = null
	_player = null
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
