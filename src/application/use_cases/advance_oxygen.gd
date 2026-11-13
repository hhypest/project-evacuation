class_name AdvanceOxygen
extends RefCounted
## One chamber generation owns one reserve, independent of the authored scene.

var _reserve: OxygenReserve = OxygenReserve.new()


func step(atmosphere: OxygenStatus.Atmosphere, delta: float) -> OxygenStatus:
	_reserve.step(delta, atmosphere == OxygenStatus.Atmosphere.BREACH,
		atmosphere == OxygenStatus.Atmosphere.SUPPLY)
	return OxygenStatus.new(atmosphere, _reserve.percentage(), _reserve.remaining_seconds <= 0.0)
