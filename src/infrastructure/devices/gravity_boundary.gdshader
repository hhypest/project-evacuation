shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D opaque_scene : hint_screen_texture, filter_linear, repeat_disable;
uniform vec3 sheen : source_color = vec3(0.63, 0.42, 0.90);
uniform vec3 half_size = vec3(2.0);
varying vec3 local_position;
varying flat vec3 local_eye;

void vertex() {
	local_position = VERTEX;
	local_eye = (inverse(MODEL_MATRIX) * INV_VIEW_MATRIX[3]).xyz;
}

void fragment() {
	bool inside = all(lessThan(abs(local_eye), half_size));
	if (inside == FRONT_FACING) {
		discard;
	}
	vec3 edge_distance = max(half_size - abs(local_position), vec3(0.0));
	// The box face already has one axis at zero. The second smallest distance is its border.
	float border = max(min(edge_distance.x, edge_distance.y),
		max(min(edge_distance.y, edge_distance.z), min(edge_distance.x, edge_distance.z)));
	float band = 1.0 - smoothstep(0.007, 0.16, border);
	band *= smoothstep(0.20, 1.0, length(VERTEX));
	if (band < 0.005) {
		discard;
	}
	vec3 normal = normalize(NORMAL);
	vec2 shift = normal.xy * band * 1.5 / VIEWPORT_SIZE;
	vec3 scene = texture(opaque_scene, SCREEN_UV).rgb;
	vec3 displaced = texture(opaque_scene, clamp(SCREEN_UV + shift, vec2(0.0), vec2(1.0))).rgb;
	// Keep bright or high-contrast pixels stable, including the ray core and the aperture edge.
	float stable = 1.0 - smoothstep(0.10, 0.38, length(displaced - scene));
	float brightness = max(scene.r, max(scene.g, scene.b));
	stable *= 1.0 - smoothstep(0.50, 0.92, brightness);
	ALBEDO = mix(scene, displaced, stable) + sheen * 0.075;
	ALPHA = band * 0.28;
}
