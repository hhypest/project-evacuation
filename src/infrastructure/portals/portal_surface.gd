class_name PortalSurface
extends Node3D
## One side of a portal pair: frame, live membrane and its own SubViewport camera. The view uses an off-axis
## frustum whose near plane is exactly the partner's opening, so geometry behind the exit never leaks into the
## image (Godot 4.7 has no oblique near plane). Portal cameras do not see live membranes: inside a portal
## view the other portals show a stable stub (no recursion in 0.1.0).

## Render layer of live membranes (seen by the player camera only).
const MEMBRANE_LAYER: int = 1 << 1
## Render layer of membrane stubs (seen by portal cameras only).
const STUB_LAYER: int = 1 << 19
const ALL_LAYERS: int = 0xFFFFF
const MEMBRANE_SHADER: Shader = preload("res://src/infrastructure/portals/portal_membrane.gdshader")

var half_size: Vector2 = Vector2(0.8, 1.2)
## The opening starts at the floor: no bottom bar and posts that stop at the floor.
var floor_level: bool = true
var accent: Color = Color(0.88, 0.42, 0.18)
var partner: PortalSurface
var powered: bool = false
var viewport: SubViewport
var camera: Camera3D
var _membrane: MeshInstance3D
var _stub: MeshInstance3D
var _frame_lamps: Array[MeshInstance3D] = []
var _live: ShaderMaterial
var _gate: CollisionShape3D
var blocked: bool = false
var barrier_rid: RID
## The aperture-local patch rendered into the viewport this frame (expanded to its aspect).
var view_region: Rect2


func _ready() -> void:
	var frame_color: Color = Color(0.88, 0.86, 0.82)
	var depth: float = PortalRules.FRAME_HALF_DEPTH * 2.0
	for side: float in [-1.0, 1.0]:
		var post_height: float = half_size.y * 2.0 + (0.16 if floor_level else 0.32)
		var post: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(0.16, post_height, depth), frame_color)
		post.position = Vector3(side * (half_size.x + 0.08), 0.08 if floor_level else 0.0, 0)
		add_child(post)
		# Floor-level openings have no sill: a bar flush with the floor plane z-fights with it.
		if side > 0.0 or not floor_level:
			var bar: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(half_size.x * 2.0, 0.16, depth), frame_color)
			bar.position = Vector3(0, side * (half_size.y + 0.08), 0)
			add_child(bar)
		var lamp: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(0.05, half_size.y * 1.6, 0.02), accent)
		lamp.position = Vector3(side * (half_size.x + 0.08), 0, depth * 0.5 + 0.01)
		add_child(lamp)
		_frame_lamps.append(lamp)
	viewport = SubViewport.new()
	viewport.name = "View"
	viewport.size = PortalViewGeometry.target_size(_screen_size())
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.cull_mask = ALL_LAYERS & ~MEMBRANE_LAYER
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
	var stub_material: StandardMaterial3D = StandardMaterial3D.new()
	stub_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stub_material.albedo_color = accent.darkened(0.55)
	_stub = MeshInstance3D.new()
	_stub.name = "Stub"
	_stub.mesh = quad
	_stub.material_override = stub_material
	_stub.layers = STUB_LAYER
	_stub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_stub)
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


func set_powered(on: bool) -> void:
	powered = on
	_membrane.visible = on
	_stub.visible = on
	for lamp: MeshInstance3D in _frame_lamps:
		var material: StandardMaterial3D = lamp.material_override as StandardMaterial3D
		material.emission_enabled = on
		material.emission = accent
		material.emission_energy_multiplier = 2.0
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
	if not visible.has_area():
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


## Virtual eye = M * viewer; the camera faces straight out of the partner, and its off-axis frustum frames
## exactly the partner's opening with the near plane on it.
func place_camera(viewer: Transform3D, visible: Rect2 = Rect2()) -> void:
	var exit: Transform3D = partner.global_transform.orthonormalized()
	var eye: Vector3 = PortalMath.map_point(global_transform.orthonormalized(), exit, viewer.origin)
	var view: Transform3D = Transform3D(exit.basis * PortalMath.H, eye)
	camera.global_transform = view
	var centre: Vector3 = view.affine_inverse() * exit.origin
	var near: float = maxf(0.0001, -centre.z)
	var requested: Rect2 = visible if visible.has_area() else Rect2(-half_size, half_size * 2.0)
	view_region = PortalViewGeometry.fit_aspect(requested, float(viewport.size.x) / viewport.size.y)
	camera.set_frustum(view_region.size.y, Vector2(centre.x, centre.y) + view_region.get_center(), near, 400.0)
	_live.set_shader_parameter(&"aperture_crop", PortalViewGeometry.uv_region(view_region, half_size))
	_live.set_shader_parameter(&"portal_origin", global_position)
	_live.set_shader_parameter(&"portal_right", global_basis.x.normalized())
	_live.set_shader_parameter(&"portal_up", global_basis.y.normalized())
	_live.set_shader_parameter(&"portal_normal", global_basis.z.normalized())
	_live.set_shader_parameter(&"portal_half", half_size)


func _screen_size() -> Vector2i:
	var owner_viewport: Viewport = get_viewport()
	# Window.size is physical pixels even when canvas_items scales the HUD's logical coordinates.
	if owner_viewport is Window:
		return (owner_viewport as Window).size
	return Vector2i(owner_viewport.get_texture().get_size())
