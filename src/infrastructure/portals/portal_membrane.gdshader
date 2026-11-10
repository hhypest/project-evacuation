shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D portal_image : source_color, filter_linear, repeat_disable;
uniform vec4 aperture_crop = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 portal_origin = vec3(0.0);
uniform vec3 portal_right = vec3(1.0, 0.0, 0.0);
uniform vec3 portal_up = vec3(0.0, 1.0, 0.0);
uniform vec3 portal_normal = vec3(0.0, 0.0, 1.0);
uniform vec2 portal_half = vec2(0.8, 1.2);

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
	vec2 aperture_uv = vec2(local.x / portal_half.x + 1.0, 1.0 - local.y / portal_half.y) * 0.5;
	vec2 sample_uv = (aperture_uv - aperture_crop.xy) / aperture_crop.zw;
	ALBEDO = texture(portal_image, clamp(sample_uv, vec2(0.0), vec2(1.0))).rgb;
	vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(point, 1.0);
	// Real aperture depth preserves occlusion by cubes/frame; only the last near-plane sliver is
	// clamped (Vulkan reverse-Z), so the portal stays visible until the eye actually crosses it.
	DEPTH = clamp(clip.z / clip.w, 0.0, 0.999999);
}
