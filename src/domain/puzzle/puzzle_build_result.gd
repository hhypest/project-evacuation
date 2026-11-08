class_name PuzzleBuildResult
extends RefCounted

var network: PuzzleNetwork
var errors: PackedStringArray = PackedStringArray()


func ok() -> bool:
	return network != null and errors.is_empty()
