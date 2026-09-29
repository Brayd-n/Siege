shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

// Alpha-cut leaf cards. Mesh normals are "spherized" from the canopy centre
// by the builder, which gives soft volumetric shading.

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float alpha_cut = 0.5;
uniform float sway = 0.06;
instance uniform vec3 tint : source_color = vec3(1.0);

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float t = TIME * 1.3 + origin.x * 0.3 + origin.z * 0.2;
	float hgt = max(VERTEX.y, 0.0);
	VERTEX.x += sin(t + VERTEX.y * 0.8) * sway * hgt * 0.15;
	VERTEX.z += cos(t * 0.8 + VERTEX.x) * sway * hgt * 0.1;
}

void fragment() {
	vec4 c = texture(leaf_tex, UV);
	ALBEDO = c.rgb * tint * COLOR.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = c.rgb * vec3(0.55, 0.65, 0.3);
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}
