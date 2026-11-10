class_name PortalOrientationLab
extends PortalLabBuilder
## Test-only floor/ceiling exit and effective field, collected by the normal scope setup.

@export var ceiling: bool = false


func _ready() -> void:
	super._ready()
	var pair: PortalPairDevice = get_node("portal_pair") as PortalPairDevice
	var angle: float = PI * 0.5 if ceiling else -PI * 0.5
	pair.surface_b.global_transform = Transform3D(Basis(Vector3.RIGHT, angle), Vector3(2, 3, 0))
	_field(&"portal.exit.field", Vector3(2, 3.5, 0), Vector3(5, 5, 5), -90.0, [&"portal.power"])
