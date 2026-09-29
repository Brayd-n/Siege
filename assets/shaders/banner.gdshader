shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// Hanging cloth banner with wind ripple, trim border and a simple crest.
// Expects a QuadMesh / PlaneMesh with UV (0,0) at top-left.

uniform vec3 base_color : source_color = vec3(0.55, 0.06, 0.06);
uniform vec3 trim_color : source_color = vec3(0.95, 0.75, 0.3);
uniform sampler2D fabric_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float wave_amp = 0.12;

void vertex() {
	float hang = UV.y; // 0 at the pole, 1 at the bottom
	vec3 origin = MODEL_MATRIX[3].xyz;
	float t = TIME * 2.2 + origin.x * 0.5;
	VERTEX.z += sin(t + UV.y * 5.0 + UV.x * 2.0) * wave_amp * hang;
	VERTEX.x += sin(t * 0.7 + UV.y * 3.0) * wave_amp * 0.3 * hang;
}

void fragment() {
	vec2 uv = UV;
	vec3 fab = texture(fabric_tex, uv * vec2(4.0, 8.0)).rgb;
	float border = step(uv.x, 0.07) + step(0.93, uv.x) + step(uv.y, 0.04);
	// swallow-tail cut at the bottom
	float tail = abs(uv.x - 0.5) * 0.5 + 0.84;
	if (uv.y > tail) { discard; }
	float trim_bottom = smoothstep(tail - 0.05, tail - 0.04, uv.y);
	// diamond crest
	vec2 c = uv - vec2(0.5, 0.42);
	float diamond = step(abs(c.x) * 1.6 + abs(c.y), 0.2) - step(abs(c.x) * 1.6 + abs(c.y), 0.14);
	float dot_c = step(length(c * vec2(1.6, 1.0)), 0.06);
	float trim = clamp(border + trim_bottom + diamond + dot_c, 0.0, 1.0);
	vec3 col = mix(base_color, trim_color, trim) * (fab * 1.1);
	ALBEDO = col;
	NORMAL_MAP = texture(fabric_normal, uv * vec2(4.0, 8.0)).rgb;
	ROUGHNESS = mix(0.85, 0.45, trim);
	METALLIC = trim * 0.6;
	BACKLIGHT = base_color * 0.5;
}
