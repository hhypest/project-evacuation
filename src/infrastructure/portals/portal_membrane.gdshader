shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D portal_image : source_color, filter_linear, repeat_disable;
uniform vec3 portal_origin = vec3(0.0);
uniform vec3 portal_right = vec3(1.0, 0.0, 0.0);
uniform vec3 portal_up = vec3(0.0, 1.0, 0.0);
uniform vec3 portal_normal = vec3(0.0, 0.0, 1.0);
uniform vec2 portal_half = vec2(0.8, 1.2);
// Owner-provided sample.md (2026-11-12): adapted slow value noise, aperture-local and opaque.
uniform vec3 contact_color : source_color = vec3(1.0, 0.55, 0.23);
uniform float rim_width : hint_range(0.0, 0.1) = 0.04; // metres inside the aperture
uniform float rim_intensity : hint_range(0.0, 2.0) = 0.65;

float rim_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float rim_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 blend = fract(point);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(rim_hash(cell), rim_hash(cell + vec2(1.0, 0.0)), blend.x),
		mix(rim_hash(cell + vec2(0.0, 1.0)), rim_hash(cell + vec2(1.0)), blend.x), blend.y);
}

void vertex() {
	// A plane which intersects the camera's near volume cannot be represented by its four original
	// clipped vertices. Rasterise screen rays and restrict them to the actual aperture below.
	POSITION = vec4(UV * 2.0 - 1.0, 1.0, 1.0);
}

void fragment() {
	vec4 view_near = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
	vec3 ray = (INV_VIEW_MATRIX * vec4(view_near.xyz / view_near.w, 0.0)).xyz;
	vec3 eye = INV_VIEW_MATRIX[3].xyz;
	float direction = dot(ray, portal_normal);
	if (direction >= -0.000001) { discard; }
	float distance = dot(portal_origin - eye, portal_normal) / direction;
	if (distance <= 0.0) { discard; }
	vec3 point = eye + ray * distance;
	vec3 offset = point - portal_origin;
	vec2 local = vec2(dot(offset, portal_right), dot(offset, portal_up));
	if (any(greaterThan(abs(local), portal_half))) { discard; }
	// The mapped camera has the viewer's projection and orientation: each screen ray already
	// addresses the matching render-target pixel, including grazing views and the near plane.
	ALBEDO = texture(portal_image, SCREEN_UV).rgb;
	vec2 to_edge = portal_half - abs(local);
	float edge_distance = min(to_edge.x, to_edge.y);
	float width = max(rim_width, 0.000001);
	float feather = max(fwidth(edge_distance), 0.0001);
	// A warm contact line and a softer reflection fall off independently inside the gasket.
	float boundary = smoothstep(0.0, feather, edge_distance);
	float contact = (1.0 - smoothstep(0.0, width * 0.29, edge_distance)) * 0.40;
	float reflection = (1.0 - smoothstep(width * 0.10, width, edge_distance)) * 0.24;
	float along = to_edge.x < to_edge.y ? local.y : local.x;
	float variation = rim_noise(vec2(along * 10.0, TIME * 0.17));
	float grazing = 1.0 - abs(dot(normalize(ray), portal_normal));
	ALBEDO += contact_color * boundary * (contact + reflection * (0.72 + grazing * 0.28))
		* rim_intensity * (0.8 + 0.2 * variation);
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(point, 1.0);
	// Real aperture depth preserves occlusion by cubes/frame; only the last near-plane sliver is
	// clamped (Vulkan reverse-Z), so the portal stays visible until the eye actually crosses it.
	DEPTH = clamp(clip.z / clip.w, 0.0, 0.999999);
}
