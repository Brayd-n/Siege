shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Instanced grass tufts. UV.y = 0 at root, 1 at tip.

uniform vec3 root_color : source_color = vec3(0.09, 0.15, 0.035);
uniform vec3 tip_color : source_color = vec3(0.24, 0.36, 0.08);
uniform vec3 dry_color : source_color = vec3(0.4, 0.37, 0.17);
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float wind_strength = 0.14;
uniform float wind_speed = 1.4;

varying float h;
varying vec3 wp;

void vertex() {
	h = UV.y;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 origin = MODEL_MATRIX[3].xyz;
	float t = TIME * wind_speed + origin.x * 0.21 + origin.z * 0.13;
	float gust = texture(macro_noise, origin.xz * 0.01 + vec2(TIME * 0.02, 0.0)).r;
	float w = (sin(t) * 0.6 + sin(t * 2.3 + 1.7) * 0.25) * (0.5 + gust);
	VERTEX.x += w * wind_strength * h * h;
	VERTEX.z += w * wind_strength * 0.6 * h * h;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.5));
}

void fragment() {
	float m = texture(macro_noise, wp.xz * 0.012).r;
	float m2 = texture(macro_noise, wp.xz * 0.05 + vec2(0.3, 0.1)).r;
	vec3 c = mix(root_color, tip_color, h);
	c *= mix(0.8, 1.12, m);
	c = mix(c, dry_color * mix(0.7, 1.0, h), smoothstep(0.55, 0.8, m2) * 0.5 * h);
	ALBEDO = c * (0.45 + 0.55 * h);
	ROUGHNESS = 0.75;
	SPECULAR = 0.1;
	BACKLIGHT = vec3(0.12, 0.16, 0.04) * h;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
