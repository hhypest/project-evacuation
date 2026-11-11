class_name SaveResult
extends RefCounted

enum Code { OK, MISSING, INVALID, UNSUPPORTED, IO_ERROR }

var code: Code
var snapshot: SaveSnapshot
var recovered: bool = false


func _init(result_code: Code, data: SaveSnapshot = null) -> void:
	code = result_code
	snapshot = data
