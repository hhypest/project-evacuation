class_name AdvanceOxygenTests
extends TestSuite


func suite_name() -> StringName:
	return &"unit"


func run(_tree: SceneTree) -> Array[TestOutcome]:
	var results: Array[TestOutcome] = []
	var oxygen: AdvanceOxygen = AdvanceOxygen.new()
	var breach: OxygenStatus = oxygen.step(OxygenStatus.Atmosphere.BREACH, 3.0)
	var passage: OxygenStatus = oxygen.step(OxygenStatus.Atmosphere.PASSAGE, 12.0)
	results.append(TestOutcome.new("neutral passage neither supplies nor drains oxygen",
		breach.percent == 75 and passage.percent == 75 and not passage.recovery_required))
	var supplied: OxygenStatus = oxygen.step(OxygenStatus.Atmosphere.SUPPLY, 1.0)
	var later_breach: OxygenStatus = oxygen.step(OxygenStatus.Atmosphere.BREACH, 10.0)
	var depleted: OxygenStatus = oxygen.step(OxygenStatus.Atmosphere.BREACH, 2.0)
	results.append(TestOutcome.new("supply refills the reserve before the next exposure",
		supplied.percent == 100 and later_breach.percent > 0 and not later_breach.recovery_required))
	results.append(TestOutcome.new("depletion requests recovery and a new chamber has a fresh reserve",
		depleted.percent == 0 and depleted.recovery_required
		and AdvanceOxygen.new().step(OxygenStatus.Atmosphere.PASSAGE, 1.0).percent == 100))
	return results
