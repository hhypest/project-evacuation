class_name CarryContentTests
extends TestSuite


func suite_name() -> StringName:
	return &"contract"


func run(tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var settings: CarrySettings = CarrySettings.new()
	var copied: CarryProfile = settings.to_profile()
	settings.max_mass = 80
	results.append(TestOutcome.new("carry authoring resource is copied into an independent valid profile",
		copied.max_mass == 40 and copied.is_valid()))
	copied.reference_mass = 0
	var zero_rejected: bool = not copied.is_valid()
	copied = settings.to_profile()
	copied.spring = NAN
	results.append(TestOutcome.new("invalid carry tuning is rejected before physics", zero_rejected and not copied.is_valid()))
	for duplicate: bool in [true, false]:
		var level: Node3D = Node3D.new()
		var player: PlayerMotor = PlayerMotor.new()
		level.add_child(player)
		for index: int in range(2):
			var body: CarryRigidBody = CarryRigidBody.new()
			body.stable_id = &"same" if duplicate else StringName("cube%d" % index)
			body.position.x = float(index) * 3
			var collision: CollisionShape3D = CollisionShape3D.new()
			collision.name = "Collision"
			collision.shape = BoxShape3D.new() if duplicate or index == 0 else SphereShape3D.new()
			body.add_child(collision)
			level.add_child(body)
		tree.root.add_child(level)
		var adapter: CarryPhysicsAdapter = CarryPhysicsAdapter.new()
		var rejected: bool = not adapter.configure(level, player, CarryProfile.new(), 77)
		adapter.close()
		results.append(TestOutcome.new("duplicate stable carry IDs reject the level" if duplicate else "unsupported carry shape rejects the level", rejected))
		tree.root.remove_child(level)
		level.queue_free()
		await tree.process_frame
	return results
