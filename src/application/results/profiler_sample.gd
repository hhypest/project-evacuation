class_name ProfilerSample
extends RefCounted
## Diagnostic snapshot. Timings are milliseconds; memory is bytes. GPU -1 means unavailable.

var frame_count: int = 0
var fps: float = 0.0
var frame_mean_ms: float = 0.0
var frame_p95_ms: float = 0.0
var frame_max_ms: float = 0.0
var process_ms: float = 0.0
var physics_ms: float = 0.0
var render_cpu_ms: float = -1.0
var render_gpu_ms: float = -1.0
var main_gpu_ms: float = -1.0
var subviewports_gpu_ms: float = -1.0
var render_scale: float = 1.0
var scaling_mode: int = 0
var texture_bytes: int = 0
var video_bytes: int = 0
var static_bytes: int = 0
var draw_calls: int = 0
var primitives: int = 0
var elapsed_s: float = 0.0
var viewport_size: Vector2i = Vector2i.ZERO
var viewport_count: int = 0
var active_viewport_count: int = 0
var generation: int = 0
var engine_version: String = ""
var physics_hz: int = 60
var vsync_mode: int = -1
var fps_limit: int = 0
var level: String = "menu"
var texture_profile: String = "source"
var gpu: String = ""
var renderer: String = ""
var paused: bool = false
var focused: bool = false
var recording: bool = false
var report_path: String = ""
var error: String = ""


## Nearest-rank p95 over one sampling window, excluding invalid timer intervals.
static func summarize(frame_times_ms: Array[float]) -> ProfilerSample:
	var sample: ProfilerSample = ProfilerSample.new()
	var sorted: Array[float] = []
	var total: float = 0.0
	for value: float in frame_times_ms:
		if is_finite(value) and value > 0.0:
			sorted.append(value)
			total += value
	sample.frame_count = sorted.size()
	if sorted.is_empty():
		return sample
	sorted.sort()
	sample.frame_mean_ms = total / float(sorted.size())
	sample.fps = 1000.0 / sample.frame_mean_ms
	sample.frame_p95_ms = sorted[ceili(float(sorted.size()) * 0.95) - 1]
	sample.frame_max_ms = sorted[-1]
	return sample
