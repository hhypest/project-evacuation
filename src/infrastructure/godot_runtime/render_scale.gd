class_name RenderScale
extends RefCounted
## Apply only to the viewport that owns the first-person camera.

const QUALITY_SCALE: float = 2.0 / 3.0


static func available() -> bool:
	return DisplayServer.get_name() != "headless" 		and RenderingServer.get_current_rendering_method() == &"forward_plus"


static func apply(viewport: Viewport, enabled: bool) -> void:
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if enabled else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = QUALITY_SCALE if enabled else 1.0
