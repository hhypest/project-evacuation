shader_type spatial;
render_mode unshaded;

instance uniform vec4 portal_clip_plane = vec4(0.0);
instance uniform vec4 portal_second_clip = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec3 light_color : source_color = vec3(0.78, 0.97, 1.0);
uniform float intensity = 1.4;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 point = vec4(world_position, 1.0);
	if (dot(point, portal_clip_plane) < 0.0 || dot(point, portal_second_clip) < 0.0) {
		discard;
	}
	ALBEDO = light_color * intensity;
}
