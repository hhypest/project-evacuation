class_name ScopeLoadTests
extends TestSuite


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var scope: LevelScope = LevelScope.new()
	tree.root.add_child(scope)
	var empty: PackedScene = PackedScene.new()
	var empty_rejected: bool = not scope.open(empty, 1) and scope.get_child_count() == 0
	var missing_camera: PackedScene = PackedScene.new()
	var root: Node3D = Node3D.new()
	missing_camera.pack(root)
	root.free()
	var missing_rejected: bool = not scope.open(missing_camera, 1) and scope.get_child_count() == 0
	scope.close()
	await tree.process_frame
	return [
		TestOutcome.new("empty chamber data is rejected without instantiation errors", empty_rejected),
		TestOutcome.new("chamber without a typed camera is rejected without partial scope", missing_rejected),
	]
