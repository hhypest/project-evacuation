extends SceneTree
## Vulkan A/B check: the rim changes the aperture edge, never the centre or foreground occlusion.
var _failed: bool = false
var _capture: String = "res://work/portal-rim.png"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(180.0, true, false, true).timeout.connect(func() -> void:
		printerr("PORTAL_RIM_FAILED: watchdog")
		quit(1))
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() == 2 and arguments[0] == "--capture":
		_capture = arguments[1]
	elif not arguments.is_empty():
		quit(2)
		return
	var info: RuntimeInfo = RuntimeProbe.new().read()
	if not ValidateRuntime.new().execute(info).is_empty():
		printerr("PORTAL_RIM_FAILED: Vulkan Forward+ required")
		quit(1)
		return
	root.size = Vector2i(640, 360)
	# Camera project/unproject uses logical viewport coordinates; screenshots use physical pixels.
	var projection_scale: Vector2 = root.get_visible_rect().size / Vector2(root.size)
	var scope: LevelScope = LevelScope.new()
	root.add_child(scope)
	if not scope.open(preload("res://content/levels/portal_lab.tscn"), 190):
		quit(1)
		return
	var level: Node3D = scope.get_child(0) as Node3D
	var pair: PortalPairDevice = level.get_node("portal_pair") as PortalPairDevice
	var camera: LookCamera = level.get_node("Camera") as LookCamera
	var targets: Array[Viewport] = [root, pair.surface_a.viewport, pair.surface_b.viewport]
	for target: Viewport in targets:
		RenderingServer.viewport_set_measure_render_time(target.get_viewport_rid(), true)
	var metrics: FileAccess = FileAccess.open(_capture.get_basename() + "-metrics.csv", FileAccess.WRITE)
	if metrics == null:
		_check(false, "open metrics CSV")
		quit(1)
		return
	metrics.store_line("side,rim,gpu_ms,cpu_ms,draw_calls,texture_bytes,video_bytes,physical_width,physical_height")
	# Static opaque foreground patch straddles the edge where the rim would otherwise appear.
	var cover: MeshInstance3D = PuzzleDeviceNode.box_mesh(Vector3(0.22, 0.45, 0.12), Color(0.22, 0.3, 0.4))
	level.add_child(cover)
	for entry: PortalSurface in [pair.surface_a, pair.surface_b]:
		camera.global_transform = entry.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, 2.4))
		cover.global_transform = entry.global_transform * Transform3D(Basis.IDENTITY, Vector3(entry.half_size.x - 0.05, 0, 0.2))
		entry.rim_intensity = 0
		var before: Image = await _frame()
		await _measure(targets, metrics, entry.name, false)
		entry.rim_intensity = 0.65
		var after: Image = await _frame()
		await _measure(targets, metrics, entry.name, true)
		var centre_error: float = 0
		var occlusion_error: float = 0
		var changed: int = 0
		var centre_count: int = 0
		var occlusion_count: int = 0
		for y: int in range(2, after.get_height() - 2):
			for x: int in range(2, after.get_width() - 2):
				var pixel: Vector2 = Vector2(x + 0.5, y + 0.5) * projection_scale
				var ray: Vector3 = camera.project_ray_normal(pixel)
				var eye: Vector3 = entry.to_local(camera.project_ray_origin(pixel))
				var local_ray: Vector3 = entry.global_basis.inverse() * ray
				if local_ray.z >= -0.00001:
					continue
				var at: Vector3 = eye + local_ray * (-eye.z / local_ray.z)
				var edge: float = minf(entry.half_size.x - absf(at.x), entry.half_size.y - absf(at.y))
				var difference: float = absf(before.get_pixel(x, y).r - after.get_pixel(x, y).r) \
					+ absf(before.get_pixel(x, y).g - after.get_pixel(x, y).g) + absf(before.get_pixel(x, y).b - after.get_pixel(x, y).b)
				if edge > 0.15:
					centre_error += difference
					centre_count += 1
				if edge > 0.005 and edge < 0.035 and absf(at.y) > 0.35 and difference > 0.02:
					changed += 1
		var covered: Vector2 = camera.unproject_position(cover.global_position) / projection_scale
		if not Rect2(Vector2(3, 4), Vector2(root.size) - Vector2(6, 8)).has_point(covered):
			_check(false, "foreground sample must be on screen")
			continue
		for y: int in range(roundi(covered.y) - 3, roundi(covered.y) + 4):
			for x: int in range(roundi(covered.x) - 2, roundi(covered.x) + 3):
				occlusion_error += absf(before.get_pixel(x, y).get_luminance() - after.get_pixel(x, y).get_luminance())
				occlusion_count += 1
		var mean: float = centre_error / maxf(1, centre_count)
		var occluded: float = occlusion_error / maxf(1, occlusion_count)
		_check(centre_count > 1000 and mean < 0.005, "centre unchanged: " + str(mean))
		_check(changed > 40, "visible edge pixels: " + str(changed))
		_check(occluded < 0.005, "foreground retains aperture depth: " + str(occluded))
		_check(before.save_png(_capture.get_basename() + "-%s-off.png" % entry.name) == OK, "save baseline")
		_check(after.save_png(_capture.get_basename() + "-%s-on.png" % entry.name) == OK, "save rim")
		print("PORTAL_RIM side=%s centre_error=%.6f changed=%d occlusion_error=%.6f" % [entry.name, mean, changed, occluded])
	metrics.close()
	scope.close()
	await process_frame
	print("PORTAL_RIM_%s driver=%s GPU=%s" % ["FAILED" if _failed else "PASSED", info.rendering_driver, RenderingServer.get_video_adapter_name()])
	quit(1 if _failed else 0)

func _frame() -> Image:
	for frame: int in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _check(passed: bool, message: String) -> void:
	if not passed:
		_failed = true
		printerr("PORTAL_RIM_FAILED: " + message)


## Short deterministic renderer A/B on the available adapter; not a target-hardware FPS claim.
func _measure(targets: Array[Viewport], file: FileAccess, side: StringName, enabled: bool) -> void:
	var gpu: float = 0
	var cpu: float = 0
	for frame: int in range(30):
		await process_frame
		await RenderingServer.frame_post_draw
		for target: Viewport in targets:
			var sub: SubViewport = target as SubViewport
			if sub != null and sub.render_target_update_mode == SubViewport.UPDATE_DISABLED:
				continue
			var rid: RID = target.get_viewport_rid()
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
	file.store_csv_line(PackedStringArray([String(side), str(enabled), str(gpu / 30), str(cpu / 30),
		str(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		str(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		str(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)), str(root.size.x), str(root.size.y)]))
