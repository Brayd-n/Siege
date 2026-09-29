shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;

// Billboarded health bar. Driven per instance with set_instance_shader_parameter.

instance uniform float fill = 1.0;
instance uniform vec4 bar_color : source_color = vec4(0.35, 0.85, 0.3, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	float bx = 0.025;
	float by = 0.14;
	bool border = uv.x < bx || uv.x > 1.0 - bx || uv.y < by || uv.y > 1.0 - by;
	vec3 inner = uv.x < fill ? bar_color.rgb * (1.1 - uv.y * 0.4) : vec3(0.12, 0.03, 0.03);
	ALBEDO = border ? vec3(0.02) : inner;
	ALPHA = 0.95;
}
