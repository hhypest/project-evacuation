shader_type spatial;
// Placement silhouette of a held prop (ADR-0012): faint body, bright box edges, a slow scan along the prop's up.
// White is the expedition's own marking colour (ADR-0006); cyan, amber and violet stay with optics, power and fields.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 half_size = vec3(0.5);
uniform vec4 tint : source_color = vec4(0.93, 0.96, 1.0, 1.0);
uniform float edge_width = 0.025;
uniform float body_alpha = 0.10;
uniform float edge_alpha = 0.85;
uniform float scan_density = 26.0;
uniform float scan_speed = 1.6;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec3 inset = half_size - abs(local_position);
	// On a face one inset is zero; on an edge the second smallest is near zero too.
	float smallest = min(inset.x, min(inset.y, inset.z));
	float largest = max(inset.x, max(inset.y, inset.z));
	float middle = inset.x + inset.y + inset.z - smallest - largest;
	float edge = 1.0 - smoothstep(edge_width * 0.5, edge_width, middle);
	float height = (local_position.y + half_size.y) / max(half_size.y * 2.0, 0.001);
	float scan = 0.5 + 0.5 * sin((height * scan_density - TIME * scan_speed) * 6.2831853);
	float rim = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.0);
	float pulse = 0.9 + 0.1 * sin(TIME * 4.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp((body_alpha * (0.6 + 0.4 * scan) + rim * 0.18 + edge * edge_alpha) * pulse, 0.0, 1.0);
}
