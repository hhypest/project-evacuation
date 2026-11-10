shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

instance uniform vec4 portal_clip_plane = vec4(0.0);
varying vec3 portal_world;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_map : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D metallic_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D ao_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D emission_map : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform float metallic_factor = 0.0;
uniform float roughness_factor = 1.0;
uniform vec4 metallic_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec4 roughness_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform bool normals_enabled = false;
uniform float normal_depth = 1.0;
uniform bool ao_enabled = false;
uniform vec4 ao_channel = vec4(1.0, 0.0, 0.0, 0.0);
uniform vec3 emission_color : source_color = vec3(0.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);

void vertex() {
	portal_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (dot(vec4(portal_world, 1.0), portal_clip_plane) < 0.0) {
		discard;
	}
	vec2 uv = UV * uv_scale.xy + uv_offset.xy;
	ALBEDO = albedo_color.rgb * texture(albedo_map, uv).rgb;
	METALLIC = metallic_factor * dot(texture(metallic_map, uv), metallic_channel);
	ROUGHNESS = roughness_factor * dot(texture(roughness_map, uv), roughness_channel);
	if (normals_enabled) {
		NORMAL_MAP = texture(normal_map, uv).rgb;
		NORMAL_MAP_DEPTH = normal_depth;
	}
	if (ao_enabled) {
		AO = dot(texture(ao_map, uv), ao_channel);
	}
	EMISSION = emission_color * texture(emission_map, uv).rgb;
}
