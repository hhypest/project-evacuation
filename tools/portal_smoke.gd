extends SceneTree
## Vulkan check of the portal view and traversal: opens "Эксперимент: порталы" through the menu,
## captures both split halves and close-view detail, then crosses with a held cube via session input.
## Software Vulkan is a render witness; a person still has to check comfort/performance on real hardware.

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")
const PORTAL_LEVEL: int = 3
var _finished: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0, true, false, true).timeout.connect(_on_timeout)
	var info: RuntimeInfo = RuntimeProbe.new().read()
	if not _check(ValidateRuntime.new().execute(info).is_empty(), "real Vulkan runtime required"):
		return
	var capture: String = "res://work/portal_smoke.png"
	var main: SessionBootstrap = MAIN.instantiate() as SessionBootstrap
	root.add_child(main)
	for _frame: int in range(120):
		if main.get_session_status().can_start:
			break
		await process_frame
	var button: Button = main.find_child("LevelButton%d" % PORTAL_LEVEL, true, false) as Button
	if not _check(main.get_session_status().can_start and button != null, "menu offers the portal experiment"):
		return
	button.pressed.emit()
	for _tick: int in range(60):
		await physics_frame
	var lab: Node3D = main.get_node_or_null("LevelScope/PortalLab") as Node3D
	if not _check(lab != null, "portal experiment level loaded"):
		return
	var player: PlayerMotor = lab.get_node("Player") as PlayerMotor
	var camera: LookCamera = lab.get_node("Camera") as LookCamera
	var pair: PortalPairDevice = lab.get_node("portal_pair") as PortalPairDevice
	if not _check(pair.state().powered, "portal pair powered"):
		return
	var a: Transform3D = pair.surface_a.global_transform
	var b: Transform3D = pair.surface_b.global_transform
	var views: Array[Array] = [[a * Vector3(1.6, 0.4, 3.4), a.origin, "a"], [b * Vector3(-1.4, 0.4, 3.6), b.origin, "b"],
		[a * Vector3(0.2, 0.3, 0.9), a.origin, "a-close"]]
	for view: Array in views:
		var eye: Vector3 = view[0]
		player.global_position = eye - Vector3(0, 1.62, 0)
		for _tick: int in range(15):
			await physics_frame
		var target: Vector3 = view[1]
		camera.look_at(target)
		for _frame: int in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var viewed: PortalSurface = pair.surface_b if str(view[2]) == "b" else pair.surface_a
		if not _check(_rendered(viewed), "visible portal image contains rendered scene"):
			return
		if not _capture(capture.get_basename() + "-%s.png" % str(view[2])):
			return
	if not await _close_quality(pair, player, camera, capture):
		return
	var half_cube: CarryRigidBody = lab.get_node("CubeA") as CarryRigidBody
	half_cube.freeze = true
	half_cube.global_transform = Transform3D(Basis.IDENTITY, a * Vector3(0, -0.3, 0.2))
	var half_views: Array[Transform3D] = [a, b]
	for index: int in range(half_views.size()):
		var surface: Transform3D = half_views[index]
		player.global_position = surface * Vector3(0.7, 0.4, 2.6) - Vector3.UP * 1.65
		for _tick: int in range(12):
			await physics_frame
		camera.look_at(surface.origin + Vector3.DOWN * 0.2)
		for _frame: int in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		if not _capture(capture.get_basename() + "-half-%d.png" % index):
			return
	half_cube.freeze = false
	# A cube thrown into A, captured as it leaves B.
	var cube: CarryRigidBody = lab.get_node("CubeA") as CarryRigidBody
	var portals: AdvancePortals = (main.get_node("LevelScope") as LevelScope).portals()
	var before: int = portals.transfers.size()
	player.global_position = b * Vector3(-2.0, 0.0, 4.5) - Vector3(0, 1.2, 0)
	for _tick: int in range(10):
		await physics_frame
	camera.look_at(b.origin)
	cube.global_transform = Transform3D(Basis.IDENTITY, a * Vector3(0, -0.25, 1.0))
	cube.linear_velocity = a.basis * Vector3(0, 0, -5.0)
	cube.sleeping = false
	for _tick: int in range(40):
		await physics_frame
		if portals.transfers.size() > before:
			break
	for _tick: int in range(5):
		await physics_frame
	await RenderingServer.frame_post_draw
	if not _check(portals.transfers.size() > before, "cube transferred A -> B"):
		return
	if not _capture(capture.get_basename() + "-transfer.png"):
		return
	if not await _walk_with_cube(main, lab, pair, camera, capture):
		return
	_finished = true
	print("PORTAL_SMOKE_PASSED driver=%s gpu=%s view=a/b/close/half transfer=cube/player-held input=E/W/Shift/mouse image=%s" % [
		info.rendering_driver, RenderingServer.get_video_adapter_name(), capture.get_basename() + "-*.png"])
	quit(0)


func _walk_with_cube(main: SessionBootstrap, lab: Node3D, pair: PortalPairDevice,
		camera: LookCamera, capture: String) -> bool:
	root.grab_focus()
	await process_frame
	if not _check(main.get_session_status().accepts_gameplay, "window focus enables session input"):
		return false
	var scope: LevelScope = main.get_node("LevelScope") as LevelScope
	var player: PlayerMotor = lab.get_node("Player") as PlayerMotor
	var cube: CarryRigidBody = lab.get_node("CubeA") as CarryRigidBody
	var a: Transform3D = pair.surface_a.global_transform
	player.global_transform = Transform3D(Basis.IDENTITY, Vector3(a.origin.x, 0.05, a.origin.z + 1.5))
	player.velocity = Vector3.ZERO
	camera.frame = Basis.IDENTITY
	camera.global_basis = Basis.IDENTITY
	cube.global_transform = Transform3D(Basis.IDENTITY, a * Vector3(0, -0.65, 0.75))
	cube.linear_velocity = Vector3.ZERO
	cube.angular_velocity = Vector3.ZERO
	scope.portals().reset()
	for _tick: int in range(15):
		await physics_frame
	camera.look_at(cube.global_position)
	TestInputEvents.key(KEY_E)
	TestInputEvents.key(KEY_E, false)
	for _tick: int in range(3):
		await physics_frame
	if not _check(scope.held_prop_id() == cube.stable_id, "E grabs the cube through real session input"):
		return false
	camera.global_basis = Basis.IDENTITY
	TestInputEvents.key(KEY_W)
	TestInputEvents.key(KEY_SHIFT)
	var arrived: bool = false
	for _tick: int in range(90):
		await physics_frame
		for passage: PortalTransfer in scope.portals().transfers:
			if passage.body_id == PortalWorldAdapter.PLAYER_ID and not passage.blocked:
				arrived = true
		if arrived:
			break
	TestInputEvents.key(KEY_W, false)
	TestInputEvents.key(KEY_SHIFT, false)
	for _tick: int in range(3):
		await physics_frame
	if not _check(arrived and scope.held_prop_id() == cube.stable_id
			and (-camera.global_basis.z).dot(pair.surface_b.global_basis.z) > 0.99,
		"W/Shift crosses the player, held cube and camera together"):
		return false
	await RenderingServer.frame_post_draw
	if not _capture(capture.get_basename() + "-player-held.png"):
		return false
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT)
	TestInputEvents.mouse_button(MOUSE_BUTTON_LEFT, false)
	for _tick: int in range(6):
		await physics_frame
	return _check(scope.held_prop_id().is_empty() and cube.linear_velocity.dot(pair.surface_b.global_basis.z) > 0.5,
		"mouse throws once in the exit frame after the player passage")


## An unshaded checker checks close detail. The separate portal_view_smoke covers both sides and yaw.
func _close_quality(pair: PortalPairDevice, player: PlayerMotor, camera: LookCamera, capture: String) -> bool:
	var target: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(4, 4)
	target.mesh = quad
	var shader: Shader = Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; void fragment() { float c = mod(floor(UV.x * 128.0) + floor(UV.y * 128.0), 2.0); ALBEDO = vec3(mix(0.02, 1.0, c)); }"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	target.material_override = material
	player.get_parent().add_child(target)
	var b: Transform3D = pair.surface_b.global_transform
	target.global_transform = Transform3D(b.basis * PortalMath.H, b * Vector3(0, 0.45, 2.5))
	var a: Transform3D = pair.surface_a.global_transform
	player.global_position = a * Vector3(0.2, 0.45, 0.03) - Vector3.UP * 1.65
	for _tick: int in range(10):
		await physics_frame
	camera.global_basis = a.basis * Basis(Vector3.UP, 0.18)
	for _frame: int in range(4):
		await process_frame
	var surface: PortalSurface = pair.surface_a
	for _frame: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var cropped: int = _edges(root.get_texture().get_image())
	var visible_area: float = surface.view_region.get_area()
	print("PORTAL_VIEW_DETAIL edges=%d patch=%s target=%s" % [cropped, surface.view_region, surface.viewport.size])
	if not _capture(capture.get_basename() + "-quality-crop.png"):
		return false
	target.queue_free()
	return _check(cropped >= 20 and visible_area < 0.1 and surface.viewport.size == PortalViewGeometry.target_size(root.size),
		"near view preserves checker detail at native resolution")


func _edges(image: Image) -> int:
	if image == null or image.is_empty():
		return 0
	var total: int = 0
	var first: int = roundi(image.get_width() * 0.35)
	var last: int = roundi(image.get_width() * 0.65)
	for fraction: float in [0.4, 0.5, 0.6]:
		var row: int = roundi(image.get_height() * fraction)
		var previous: Color = image.get_pixel(first, row)
		for x: int in range(first + 1, last):
			var current: Color = image.get_pixel(x, row)
			if absf(current.get_luminance() - previous.get_luminance()) > 0.12:
				total += 1
			previous = current
	return roundi(float(total) / 3.0)


## The portal render target must hold a real image: enough different pixels, not one flat colour.
func _rendered(surface: PortalSurface) -> bool:
	var image: Image = surface.viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var first: Color = image.get_pixel(0, 0)
	var differing: int = 0
	for y: int in range(0, image.get_height(), 48):
		for x: int in range(0, image.get_width(), 48):
			if not image.get_pixel(x, y).is_equal_approx(first):
				differing += 1
	return differing > 20


func _capture(path: String) -> bool:
	var image: Image = root.get_texture().get_image()
	return _check(image != null and not image.is_empty() and image.save_png(path) == OK, "save Vulkan frame " + path)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		printerr("PORTAL_SMOKE_FAILED: " + message)
		_finished = true
		quit(1)
	return condition


func _on_timeout() -> void:
	if not _finished:
		printerr("PORTAL_SMOKE_TIMEOUT")
		quit(3)
