extends SceneTree
## Real Vulkan regression for native detail while turning close to either portal.

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
	print("PORTAL_NATIVE_%s" % ("FAILED" if _failed else "PASSED"))
	quit(1 if _failed else 0)

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
