shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

// Swirling dark portal for the enemy spawn gate.

uniform vec3 color_a : source_color = vec3(0.45, 0.1, 0.8);
uniform vec3 color_b : source_color = vec3(0.1, 0.9, 0.35);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float a = atan(c.y, c.x);
	float swirl = a + r * 4.0 - TIME * 1.5;
	float n = noise(vec2(swirl * 1.5, r * 6.0 - TIME)) * 0.6 + noise(vec2(swirl * 3.0, r * 12.0)) * 0.4;
	float mask = 1.0 - smoothstep(0.7, 1.0, r);
	vec3 col = mix(color_a, color_b, n) * n * 2.2;
	ALBEDO = col * mask;
	ALPHA = mask;
}
