extends SceneTree
## Real Vulkan regressions for native detail and lighting continuity through both portals.

var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60.0, true, false, true).timeout.connect(_timeout)
	var capture: String = "res://work/portal-native.png"
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--capture":
		capture = arguments[1]
	elif not arguments.is_empty():
		printerr("Expected --capture <PNG path>")
		quit(2)
		return
	var info: RuntimeInfo = RuntimeProbe.new().read()
	if not ValidateRuntime.new().execute(info).is_empty():
		printerr("PORTAL_NATIVE_FAILED: real Vulkan runtime required")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var scope: LevelScope = LevelScope.new()
	root.add_child(scope)
	if not scope.open(preload("res://content/levels/portal_lab.tscn"), 90):
		quit(1)
		return
	var lab: Node3D = scope.get_child(0) as Node3D
	var pair: PortalPairDevice = lab.get_node("portal_pair") as PortalPairDevice
	var camera: LookCamera = lab.get_node("Camera") as LookCamera
	var target: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(8, 8)
	target.mesh = quad
	var shader: Shader = Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded; void fragment() { float c = mod(floor(UV.x * 256.0) + floor(UV.y * 256.0), 2.0); ALBEDO = vec3(mix(0.02, 1.0, c)); }"
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	target.material_override = material
	lab.add_child(target)
	target.visible = false
	camera.global_position = pair.surface_b.global_transform * Vector3(0.7, 0.4, 2.6)
	camera.look_at(pair.surface_b.global_position)
	for frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var lit: Image = pair.surface_b.viewport.get_texture().get_image()
	var luminance: float = lit.get_pixel(roundi(lit.get_width() * 0.5), roundi(lit.get_height() * 0.8)).get_luminance()
	_failed = _failed or luminance < 0.04
	print("PORTAL_NATIVE_LIGHT floor_luminance=%.3f" % luminance)
	target.visible = true
	target.global_transform = Transform3D(pair.surface_b.global_basis * PortalMath.H, pair.surface_b.global_transform * Vector3(0, 0.45, 2.5))
	print("QUALITY_RUNTIME renderer=%s GPU=%s" % [info.rendering_driver, RenderingServer.get_video_adapter_name()])
	for entry: PortalSurface in [pair.surface_a, pair.surface_b]:
		for angle: float in [0.18, 0.65, 1.05, 1.25]:
			target.global_transform = Transform3D(entry.partner.global_basis * PortalMath.H, entry.partner.global_transform * Vector3(0, 0.45, 2.5))
			camera.global_transform = entry.global_transform * Transform3D(Basis(Vector3.UP, angle), Vector3(0.2, 0.45, 0.03))
			for frame: int in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			var frame: Image = root.get_texture().get_image()
			var edges: int = _edges(frame)
			var saved: bool = frame.save_png(capture.get_basename() + "-%s-%.2f.png" % [entry.name, angle]) == OK
			_failed = _failed or not saved or edges < 70 or entry.viewport.size != root.size
			print("QUALITY side=%s yaw=%.2f edges=%d target=%s" % [entry.name, angle, edges, entry.viewport.size])
	scope.close()
	await process_frame
	var lighting_passed: bool = await _lighting_parity(capture)
	_failed = _failed or not lighting_passed
	print("PORTAL_NATIVE_%s" % ("FAILED" if _failed else "PASSED"))
	quit(1 if _failed else 0)

## Compare the actual membrane against the same rays in the main camera. The ceiling and walls
## can be outside the exit's color pass yet still block the directional light over the room.
func _lighting_parity(capture: String) -> bool:
	const GENERATION: int = 91
	var scope: LevelScope = LevelScope.new()
	root.add_child(scope)
	if not scope.open(preload("res://content/levels/mechanics_lab.tscn"), GENERATION):
		scope.close()
		return false
	var level: Node3D = scope.get_child(0) as Node3D
	var camera: LookCamera = level.get_node("Camera") as LookCamera
	var pair: PortalPairDevice = level.get_node("Portals/Fixture/portal_pair") as PortalPairDevice
	var input_frame: GameplayInputFrame = GameplayInputFrame.new()
	input_frame.generation = GENERATION
	for tick: int in range(20):
		await physics_frame
		scope.apply_input(input_frame)
	var passed: bool = true
	for entry: PortalSurface in [pair.surface_a, pair.surface_b]:
		var viewer: Transform3D = entry.global_transform * Transform3D(Basis(Vector3.RIGHT, -0.17), Vector3(0, 0.43, 0.065))
		camera.global_transform = viewer
		camera.cull_mask |= PortalSurface.MEMBRANE_LAYER
		var through: Image = await _capture_frame()
		camera.global_transform = PortalMath.map_transform(entry.global_transform, entry.partner.global_transform, viewer)
		camera.cull_mask &= ~PortalSurface.MEMBRANE_LAYER
		var direct: Image = await _capture_frame()
		var error: float = _mean_rgb_error(through, direct, Rect2i(240, 100, 800, 550))
		var prefix: String = capture.get_basename() + "-lighting-" + str(entry.name)
		var saved: bool = through.save_png(prefix + "-through.png") == OK and direct.save_png(prefix + "-direct.png") == OK
		passed = passed and saved and error < 0.012
		print("PORTAL_LIGHTING_PARITY side=%s mean_rgb_error=%.5f limit=0.012" % [entry.name, error])
	scope.close()
	await process_frame
	return passed


func _capture_frame() -> Image:
	for frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _mean_rgb_error(a: Image, b: Image, area: Rect2i) -> float:
	var difference: float = 0.0
	var samples: int = 0
	for y: int in range(area.position.y, area.end.y, 5):
		for x: int in range(area.position.x, area.end.x, 5):
			var left: Color = a.get_pixel(x, y)
			var right: Color = b.get_pixel(x, y)
			difference += absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b)
			samples += 3
	return difference / float(samples)


func _timeout() -> void:
	printerr("PORTAL_NATIVE_TIMEOUT")
	quit(3)

func _edges(frame: Image) -> int:
	var total: int = 0
	for fraction: float in [0.4, 0.5, 0.6]:
		var row: int = roundi(frame.get_height() * fraction)
		var previous: Color = frame.get_pixel(100, row)
		for x: int in range(101, frame.get_width() - 100):
			var current: Color = frame.get_pixel(x, row)
			if absf(current.get_luminance() - previous.get_luminance()) > 0.12:
				total += 1
			previous = current
	return roundi(float(total) / 3.0)
