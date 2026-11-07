class_name RuntimeInfo
extends RefCounted

var engine_version: String
var rendering_driver: StringName
var physics_backend: StringName
var headless: bool


func _init(
	version: String, renderer: StringName, physics: StringName, without_display: bool
) -> void:
	engine_version = version
	rendering_driver = renderer
	physics_backend = physics
	headless = without_display
