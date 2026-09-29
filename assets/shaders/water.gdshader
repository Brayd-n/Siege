shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// River water: two scrolling noise normal layers, fresnel tint, soft edges.

uniform vec4 deep : source_color = vec4(0.05, 0.16, 0.2, 1.0);
uniform vec4 shallow : source_color = vec4(0.2, 0.38, 0.4, 1.0);
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;
uniform float flow = 0.25;
uniform float darkness = 1.0;

void fragment() {
	vec2 uv1 = UV * vec2(1.0, 0.35) + vec2(0.0, TIME * flow);
	vec2 uv2 = UV * vec2(0.7, 0.22) + vec2(0.13, TIME * flow * 0.6);
	float n1 = texture(noise, uv1).r;
	float n2 = texture(noise, uv2).r;
	vec3 nrm = normalize(vec3((n1 - 0.5) * 0.9, 1.0, (n2 - 0.5) * 0.9));
	NORMAL = normalize((VIEW_MATRIX * vec4(nrm, 0.0)).xyz);
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 col = mix(shallow.rgb, deep.rgb, edge);
	col += vec3(0.25, 0.3, 0.3) * fres;
	ALBEDO = col * darkness;
	ROUGHNESS = 0.16;
	METALLIC = 0.0;
	SPECULAR = 0.45;
	ALPHA = mix(0.55, 0.92, edge);
}
