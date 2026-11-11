class_name LevelEntry
extends Resource
## One selectable chamber of the technical menu.

@export var level_id: StringName
@export var title: String = ""
@export_multiline var summary: String = ""
@export var scene: PackedScene
