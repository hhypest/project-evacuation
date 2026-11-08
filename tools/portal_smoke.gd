extends SceneTree
## Real-GPU check of the SKL-08 portal view: opens "Эксперимент: порталы" through the menu, renders both
## membranes from several eyes, a close-up and a cube leaving the exit. The portal image must be real
## render output (not empty, not a flat colour); a person still has to look at the frames.

const MAIN: PackedScene = preload("res://src/bootstrap/main.tscn")
const PORTAL_LEVEL: int = 3
var _finished: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(40.0, true, false, true).timeout.connect(_on_timeout)
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
		if not _check(_rendered(pair.surface_a) and _rendered(pair.surface_b), "portal images contain rendered scene"):
			return
		if not _capture(capture.get_basename() + "-%s.png" % str(view[2])):
			return
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
	_finished = true
	print("PORTAL_SMOKE_PASSED driver=%s gpu=%s view=a/b/close transfer=a->b image=%s" % [
		info.rendering_driver, RenderingServer.get_video_adapter_name(), capture.get_basename() + "-*.png"])
	quit(0)


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
