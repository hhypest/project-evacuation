class_name PhysicsTests
extends TestSuite

const LAB: PackedScene = preload("res://content/levels/foundation_lab.tscn")


func suite_name() -> StringName:
	return &"integration"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var info: RuntimeInfo = RuntimeProbe.new().read()
	if not ValidateRuntime.new().execute(info, true).is_empty():
		return [TestOutcome.new("Jolt runtime precondition", false)]
	var lab: Node3D = LAB.instantiate() as Node3D
	if lab == null:
		return [TestOutcome.new("physics lab has a typed root", false)]
	tree.root.add_child(lab)
	var cube: RigidBody3D = lab.get_node("TestCube") as RigidBody3D
	if cube == null:
		lab.queue_free()
		return [TestOutcome.new("physics lab contains a rigid body", false)]
	var initial_y: float = cube.position.y
	for tick: int in range(20):
		await tree.physics_frame
	results.append(TestOutcome.new("Jolt accelerates the cube downwards",
		cube.position.y < initial_y - 0.1 and cube.linear_velocity.y < -0.1))
	for tick: int in range(130):
		await tree.physics_frame
	await tree.process_frame
	results.append(TestOutcome.new("cube settles on the floor without penetration",
		absf(cube.position.y - 0.5) < 0.06 and cube.linear_velocity.length() < 0.2,
		"y=%.4f velocity=%.4f" % [cube.position.y, cube.linear_velocity.length()]))
	tree.root.remove_child(lab)
	lab.queue_free()
	await tree.process_frame
	return results
