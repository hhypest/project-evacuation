class_name GravityRulesTests
extends TestSuite
## Single effective source: power, priority, stable-ID tie-break, base fallback and zone validation.


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var base: GravityZone = GravityZone.make(&"level.base", -100, Vector3.DOWN, 9.8)
	var wall: GravityZone = GravityZone.make(&"wall", 1, Vector3.LEFT, 9.8)
	var ceiling: GravityZone = GravityZone.make(&"ceiling", 5, Vector3.UP, 9.8)
	var twin: GravityZone = GravityZone.make(&"another", 1, Vector3.RIGHT, 9.8)
	var dark: GravityZone = GravityZone.make(&"dark", 9, Vector3.BACK, 9.8, false)
	results.append(TestOutcome.new("outside every powered zone the base gravity applies",
		GravityRules.select([], base) == base and GravityRules.select([dark], base) == base))
	results.append(TestOutcome.new("the higher priority powered zone wins; an unpowered zone never does",
		GravityRules.select([wall, dark, ceiling], base) == ceiling))
	results.append(TestOutcome.new("equal priority resolves to the smaller stable ID regardless of order",
		GravityRules.select([wall, twin], base) == twin and GravityRules.select([twin, wall], base) == twin))
	var order: Array[StringName] = GravityRules.rank([ceiling, wall, twin])
	results.append(TestOutcome.new("engine rank lists zones from least to most effective",
		order == [&"wall", &"another", &"ceiling"], str(order)))
	var bad: Array[GravityZone] = [GravityZone.make(&"", 0, Vector3.DOWN, 9.8),
		GravityZone.make(&"slanted", 0, Vector3(1, 1, 0), 9.8), GravityZone.make(&"weightless", 0, Vector3.DOWN, 0.0),
		GravityZone.make(&"crushing", 0, Vector3.DOWN, 80.0), GravityZone.make(&"nan", 0, Vector3.DOWN, NAN),
		GravityZone.make(&"wall", 0, Vector3.LEFT, 9.8), GravityZone.make(&"wall", 0, Vector3.LEFT, 9.8)]
	var errors: PackedStringArray = GravityRules.validate(bad)
	results.append(TestOutcome.new("validation rejects empty IDs, non-unit directions, zero/excess/NaN strength and duplicates",
		errors.size() == 6, "\n".join(errors)))
	results.append(TestOutcome.new("a zone's up is opposite to its pull", wall.up() == Vector3.RIGHT))
	return results
