class_name CarryPlacement
extends RefCounted
## Where the held prop would be set down (ADR-0012, placement); shown as a silhouette while available.

var available: bool = false
var transform: Transform3D = Transform3D.IDENTITY
## Full size of the held prop's box, for the silhouette.
var size: Vector3 = Vector3.ONE
## Stable ID of the supporting prop, or the floor button's ID.
var support_id: StringName = &""
