class_name LevelScope
extends Node
## Owns one chamber generation. Detached scopes reject input before they are freed.

var _generation: int = -1
var _level: Node3D
var _camera: LookCamera


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
	if camera == null:
		level.free()
		return false
	_generation = generation
	_level = level
	_camera = camera
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	return true


func apply_input(frame: GameplayInputFrame) -> void:
	if _generation < 0 or frame.generation != _generation or _camera == null:
		return
	_camera.apply_look(frame.look_delta)


func close() -> void:
	_generation = -1
	_camera = null
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
