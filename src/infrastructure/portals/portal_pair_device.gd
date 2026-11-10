class_name PortalPairDevice
extends PuzzleDeviceNode
## A stationary pair of equal flat portals powered by one network input. Surfaces "A" and "B" are placed by
## the authoring transforms below (relative to this node); the opening is half_size * 2.

@export var half_size: Vector2 = Vector2(0.8, 1.2)
@export var a_transform: Transform3D = Transform3D.IDENTITY
@export var b_transform: Transform3D = Transform3D.IDENTITY

var surface_a: PortalSurface
var surface_b: PortalSurface


func _ready() -> void:
	surface_a = _surface("A", a_transform, Color(0.88, 0.42, 0.18))
	surface_b = _surface("B", b_transform, Color(0.22, 0.78, 0.86))
	surface_a.partner = surface_b
	surface_b.partner = surface_a


func definition() -> DeviceDefinition:
	return DeviceDefinition.make(stable_id, DeviceDefinition.Kind.PORTAL_PAIR, inputs)


func show_output(on: bool, _delta: float) -> void:
	surface_a.set_powered(on)
	surface_b.set_powered(on)


func state() -> PortalPairState:
	var result: PortalPairState = PortalPairState.new()
	result.id = stable_id
	# Preserve the authored transform until validation: orthonormalising here would silently hide
	# scale/shear and make physics, the opening and the image disagree.
	result.a = PortalPlane.make(StringName(String(stable_id) + ".a"), surface_a.global_transform, half_size)
	result.b = PortalPlane.make(StringName(String(stable_id) + ".b"), surface_b.global_transform, half_size)
	result.powered = surface_a.powered
	return result


func _surface(label: String, placement: Transform3D, accent: Color) -> PortalSurface:
	var surface: PortalSurface = PortalSurface.new()
	surface.name = label
	surface.half_size = half_size
	surface.accent = accent
	surface.transform = placement
	add_child(surface)
	return surface
