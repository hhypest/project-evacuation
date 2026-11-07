class_name TestOutcome
extends RefCounted

var name: String
var passed: bool
var detail: String


func _init(test_name: String, success: bool, description: String = "") -> void:
	name = test_name
	passed = success
	detail = description
