shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

instance uniform vec4 portal_clip_plane = vec4(0.0);
instance uniform vec4 portal_second_clip = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec3 halo_color : source_color = vec3(0.18, 0.69, 0.84);
varying vec3 world_position;

void vertex() {
	// Local Y follows the traced axis. Only the transverse position faces the viewing camera.
	vec3 center = MODEL_MATRIX[3].xyz + VERTEX.y * MODEL_MATRIX[1].xyz;
	vec3 across = cross(normalize(MODEL_MATRIX[1].xyz), normalize(INV_VIEW_MATRIX[3].xyz - center));
	vec3 right = length(across) > 0.0001 ? normalize(across) : INV_VIEW_MATRIX[0].xyz;
	world_position = center + right * VERTEX.x;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_position, 1.0)).xyz;
}

void fragment() {
	vec4 point = vec4(world_position, 1.0);
	if (dot(point, portal_clip_plane) < 0.0 || dot(point, portal_second_clip) < 0.0) {
		discard;
	}
	float across = abs(UV.x * 2.0 - 1.0);
	ALBEDO = halo_color;
	ALPHA = (1.0 - smoothstep(0.0, 1.0, across)) * 0.23;
}
