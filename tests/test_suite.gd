class_name TestSuite
extends RefCounted


func suite_name() -> StringName:
	return &"unimplemented"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	return [TestOutcome.new("suite must implement run", false)]
