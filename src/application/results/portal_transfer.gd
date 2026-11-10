class_name PortalTransfer
extends RefCounted
## Outcome of one crossing: transferred, or refused because the exit volume was occupied.

var crossing_id: int = 0
var tick_id: int = 0
var body_id: StringName = &""
var pair_id: StringName = &""
var entry_id: StringName = &""
var exit_id: StringName = &""
var blocked: bool = false
var companion_id: StringName = &""
var detached_id: StringName = &""
var rotation: Basis = Basis.IDENTITY
