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
## Portal image height in pixels; width follows the opening aspect. Fixed for the experiment (see QA SKL-08).
const VIEW_HEIGHT: int = 1080

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


func _ready() -> void:
	var frame_color: Color = Color(0.88, 0.86, 0.82)
	var depth: float = 0.4
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
	viewport.size = _viewport_size()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.cull_mask = ALL_LAYERS & ~MEMBRANE_LAYER
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	viewport.add_child(camera)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = half_size * 2.0
	var live: StandardMaterial3D = StandardMaterial3D.new()
	live.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	live.albedo_texture = viewport.get_texture()
	_membrane = MeshInstance3D.new()
	_membrane.name = "Membrane"
	_membrane.mesh = quad
	_membrane.material_override = live
	_membrane.layers = MEMBRANE_LAYER
	_membrane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


func _process(_delta: float) -> void:
	var viewer: Camera3D = get_viewport().get_camera_3d()
	if not powered or partner == null or viewer == null:
		return
	place_camera(viewer.global_transform)
	# A membrane seen from behind is culled; skip its render target then.
	var in_front: bool = (global_transform.affine_inverse() * viewer.global_position).z > 0.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if in_front else SubViewport.UPDATE_DISABLED
	if camera.environment == null and get_world_3d().environment != null:
		# Light the portal image once: the player camera tonemaps the membrane again.
		var environment: Environment = get_world_3d().environment.duplicate() as Environment
		environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		environment.glow_enabled = false
		camera.environment = environment


## Virtual eye = M * viewer; the camera faces straight out of the partner, and its off-axis frustum frames
## exactly the partner's opening with the near plane on it.
func place_camera(viewer: Transform3D) -> void:
	var exit: Transform3D = partner.global_transform.orthonormalized()
	var eye: Vector3 = PortalMath.map_point(global_transform.orthonormalized(), exit, viewer.origin)
	var view: Transform3D = Transform3D(exit.basis * PortalMath.H, eye)
	camera.global_transform = view
	var centre: Vector3 = view.affine_inverse() * exit.origin
	var near: float = maxf(0.01, -centre.z)
	camera.set_frustum(half_size.y * 2.0, Vector2(centre.x, centre.y), near, 400.0)


func _viewport_size() -> Vector2i:
	return Vector2i(roundi(VIEW_HEIGHT * half_size.x / half_size.y), VIEW_HEIGHT)
