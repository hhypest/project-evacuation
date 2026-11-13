class_name PortalSurface
extends Node3D
## One side of a portal pair: frame, live membrane and a native screen-space SubViewport camera.
## PortalViewWorld clips opaque geometry at the exit. Cameras never see live membranes (no recursion).

## Render layer of live membranes (seen by the player camera only).
const MEMBRANE_LAYER: int = 1 << 1
const ASSEMBLY_ENAMEL: Material = preload("res://content/materials/expedition/portal_enamel.tres")
const GASKET_COLOR: Color = Color(0.085, 0.092, 0.096)
const AMBER: Color = Color(1.0, 0.55, 0.23)
const ALL_LAYERS: int = 0xFFFFF
const MEMBRANE_SHADER: Shader = preload("res://src/infrastructure/portals/portal_membrane.gdshader")

var half_size: Vector2 = Vector2(0.8, 1.2)
## The opening starts at the floor: no bottom bar and posts that stop at the floor.
var floor_level: bool = true
var accent: Color = Color(0.88, 0.42, 0.18)
## Visual-only controls. Zero intensity restores the original native portal image for comparisons.
var rim_width: float = 0.04
var rim_intensity: float = 0.65
var partner: PortalSurface
var powered: bool = false
var viewport: SubViewport
var camera: Camera3D
var _membrane: MeshInstance3D
var _frame_lamps: Array[MeshInstance3D] = []
var _live: ShaderMaterial
var _gate: CollisionShape3D
var blocked: bool = false
var barrier_rid: RID
## The aperture-local patch rendered into the viewport this frame (expanded to its aspect).
var view_region: Rect2
## Inset world-space boxes of permanent opaque walls authored with the level.
var view_blockers: Array[AABB] = []


func _ready() -> void:
	var depth: float = PortalRules.FRAME_HALF_DEPTH * 2.0
	for side: float in [-1.0, 1.0]:
		var post_height: float = half_size.y * 2.0 + (0.16 if floor_level else 0.32)
		_frame_rail(Vector3(0.16, post_height, depth),
			Vector3(side * (half_size.x + 0.08), 0.08 if floor_level else 0.0, 0), Vector3.RIGHT * side)
		# Floor-level openings have no sill.
		if side > 0.0 or not floor_level:
			_frame_rail(Vector3(half_size.x * 2.0, 0.16, depth),
				Vector3(0, side * (half_size.y + 0.08), 0), Vector3.UP * side)
		# Pair identity stays visible when unpowered, independently of the amber contact lamps.
		var tag: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(0.075, 0.21, 0.01), accent)
		tag.position = Vector3(side * (half_size.x + 0.103), half_size.y * 0.67, depth * 0.5 + 0.025)
		add_child(tag)
		var letter: Label3D = Label3D.new()
		letter.text = str(name)
		letter.modulate = Color(0.05, 0.06, 0.06)
		letter.outline_size = 0
		letter.font_size = 48
		letter.pixel_size = 0.00112
		letter.position = tag.position + Vector3(0, 0, 0.009)
		add_child(letter)
	viewport = SubViewport.new()
	viewport.name = "View"
	viewport.size = PortalViewGeometry.target_size(_screen_size())
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.cull_mask = PortalViewWorld.VIEW_LAYERS[0 if name == &"A" else 1]
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	viewport.add_child(camera)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = half_size * 2.0
	_live = ShaderMaterial.new()
	_live.shader = MEMBRANE_SHADER
	_live.set_shader_parameter(&"portal_image", viewport.get_texture())
	_membrane = MeshInstance3D.new()
	_membrane.name = "Membrane"
	_membrane.mesh = quad
	_membrane.material_override = _live
	_membrane.layers = MEMBRANE_LAYER
	_membrane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Screen-ray geometry still needs a conservative CPU culling bound when the physical aperture
	# lies inside Camera3D.near. Off-screen/back-facing apertures are hidden in _process instead.
	_membrane.extra_cull_margin = 1.0
	add_child(_membrane)
	# A real local barrier is enabled only for a refused passage, never by disabling a wall.
	var barrier: StaticBody3D = StaticBody3D.new()
	barrier.name = "ExitBlocker"
	barrier.collision_layer = 1
	barrier.collision_mask = 6
	_gate = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(half_size.x * 2.0, half_size.y * 2.0, PortalRules.BARRIER_HALF_DEPTH * 2.0)
	_gate.shape = shape
	_gate.disabled = true
	barrier.add_child(_gate)
	add_child(barrier)
	barrier_rid = barrier.get_rid()
	set_powered(false)


## Nest the enamel and contact strip inside the collar, entirely outside the physical aperture.
func _frame_rail(size: Vector3, at: Vector3, away: Vector3) -> void:
	var collar: MeshInstance3D = PuzzleDeviceNode.box_mesh(size, GASKET_COLOR)
	collar.position = at
	add_child(collar)
	var enamel_size: Vector3 = size - away.abs() * 0.048
	enamel_size.z = 0.022
	for face: float in [-1.0, 1.0]:
		var enamel_at: Vector3 = at + away * 0.019 + Vector3.BACK * face * (size.z * 0.5 + 0.01)
		var enamel: MeshInstance3D = MeshInstance3D.new()
		enamel.mesh = MetricBoxMesh.make(enamel_size, enamel_at, 1.0)
		enamel.material_override = ASSEMBLY_ENAMEL
		enamel.position = enamel_at
		add_child(enamel)
		var contact_size: Vector3 = size - away.abs() * 0.149
		contact_size.z = 0.008
		var lamp: MeshInstance3D = PuzzleDeviceNode.box_mesh(contact_size, AMBER.darkened(0.65))
		lamp.position = at - away * 0.055 + Vector3.BACK * face * (size.z * 0.5 + 0.005)
		add_child(lamp)
		_frame_lamps.append(lamp)


func set_powered(on: bool) -> void:
	powered = on
	_membrane.visible = on
	for lamp: MeshInstance3D in _frame_lamps:
		var material: StandardMaterial3D = lamp.material_override as StandardMaterial3D
		material.emission_enabled = on
		material.emission = AMBER
		material.emission_energy_multiplier = 0.65
	if not on:
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		set_blocked(false)


func set_blocked(on: bool) -> void:
	blocked = on and powered
	if _gate != null:
		_gate.disabled = not blocked


func _process(_delta: float) -> void:
	var viewer: Camera3D = get_viewport().get_camera_3d()
	if not powered or partner == null or viewer == null:
		return
	# A membrane seen from behind is culled; skip its render target then.
	var in_front: bool = (global_transform.affine_inverse() * viewer.global_position).z > 0.0
	if not in_front:
		_membrane.visible = false
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var size: Vector2i = PortalViewGeometry.target_size(_screen_size())
	if viewport.size != size:
		viewport.size = size
	var aspect: float = float(size.x) / size.y
	var vertical: float = tan(deg_to_rad(viewer.fov) * 0.5)
	var tangents: Vector2 = Vector2(vertical * aspect, vertical)
	if viewer.keep_aspect == Camera3D.KEEP_WIDTH:
		tangents = Vector2(vertical, vertical / aspect)
	var visible: Rect2 = PortalViewGeometry.visible_region(half_size,
		viewer.global_transform.affine_inverse() * global_transform, tangents)
	if not visible.has_area() or (not view_blockers.is_empty() and PortalViewGeometry.hidden_by_box(
			visible, global_transform, viewer.global_transform, viewer.near, view_blockers)):
		_membrane.visible = false
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_membrane.visible = true
	place_camera(viewer.global_transform, visible)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if camera.environment == null and get_world_3d().environment != null:
		# Light the portal image once: the player camera tonemaps the membrane again.
		var environment: Environment = get_world_3d().environment.duplicate() as Environment
		environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		environment.glow_enabled = false
		camera.environment = environment


## The complete mapped viewer pose and matching projection keep one texture pixel per screen pixel.
func place_camera(viewer: Transform3D, visible: Rect2 = Rect2()) -> void:
	var native: Vector2i = PortalViewGeometry.target_size(_screen_size())
	if viewport.size != native:
		viewport.size = native
	var exit: Transform3D = partner.global_transform.orthonormalized()
	camera.global_transform = PortalMath.map_transform(global_transform.orthonormalized(), exit, viewer)
	var source: Camera3D = get_viewport().get_camera_3d()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect = source.keep_aspect if source != null else Camera3D.KEEP_HEIGHT
	camera.fov = source.fov if source != null else 75.0
	camera.near = 0.001
	camera.far = source.far if source != null else 400.0
	view_region = visible if visible.has_area() else Rect2(-half_size, half_size * 2.0)
	_live.set_shader_parameter(&"portal_origin", global_position)
	_live.set_shader_parameter(&"portal_right", global_basis.x.normalized())
	_live.set_shader_parameter(&"portal_up", global_basis.y.normalized())
	_live.set_shader_parameter(&"portal_normal", global_basis.z.normalized())
	_live.set_shader_parameter(&"portal_half", half_size)
	_live.set_shader_parameter(&"contact_color", AMBER)
	_live.set_shader_parameter(&"rim_width", maxf(rim_width, 0.0))
	_live.set_shader_parameter(&"rim_intensity", maxf(rim_intensity, 0.0))


func _screen_size() -> Vector2i:
	var owner_viewport: Viewport = get_viewport()
	if DisplayServer.get_name() == "headless":
		return Vector2i(owner_viewport.get_visible_rect().size)
	# Window.size is physical pixels even when canvas_items scales the HUD's logical coordinates.
	if owner_viewport is Window and (owner_viewport as Window).size.x > 0 and (owner_viewport as Window).size.y > 0:
		return (owner_viewport as Window).size
	return Vector2i(owner_viewport.get_visible_rect().size)
