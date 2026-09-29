shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Terrain: grass / dirt road / rock slopes / cobble plaza, blended using a
// signed-distance field of the enemy road baked at runtime by Map.gd.

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_noise : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D road_sdf : hint_default_white, filter_linear, repeat_disable;

uniform vec2 sdf_origin = vec2(-70.0, -50.0);
uniform vec2 sdf_size = vec2(140.0, 100.0);
uniform float road_half_width = 1.7;
uniform float grass_scale = 0.16;
uniform float dirt_scale = 0.2;
uniform vec4 plaza_rect = vec4(38.0, 2.0, 60.0, 20.0); // xmin, zmin, xmax, zmax
uniform vec3 grass_tint = vec3(1.0);
uniform float snow = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 tex_notile(sampler2D s, vec2 uv, float m) {
	// two rotated/offset samples blended by macro noise to hide tiling
	vec2 uv2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.73 + vec2(0.37, 0.71);
	return mix(texture(s, uv), texture(s, uv2), smoothstep(0.35, 0.65, m));
}

void fragment() {
	vec2 p = wpos.xz;
	float m1 = texture(macro_noise, p * 0.012).r;
	float m2 = texture(macro_noise, p * 0.05 + vec2(0.3, 0.1)).r;
	float m3 = texture(macro_noise, p * 0.21 + vec2(0.7, 0.4)).r;

	// --- grass
	vec2 guv = p * grass_scale;
	vec3 g_alb = tex_notile(grass_albedo, guv, m2).rgb * grass_tint;
	vec3 g_nrm = tex_notile(grass_normal, guv, m2).rgb;
	float g_r = tex_notile(grass_rough, guv, m2).r;
	g_alb *= mix(0.78, 1.12, m1);
	g_alb = mix(g_alb, g_alb * vec3(1.18, 1.08, 0.72), smoothstep(0.55, 0.8, m2) * 0.5); // dry patches

	// --- dirt
	vec2 duv = p * dirt_scale;
	vec3 d_alb = tex_notile(dirt_albedo, duv, m2).rgb;
	vec3 d_nrm = tex_notile(dirt_normal, duv, m2).rgb;
	float d_r = tex_notile(dirt_rough, duv, m2).r;

	// --- road mask from SDF
	vec2 suv = (p - sdf_origin) / sdf_size;
	float dist = texture(road_sdf, suv).r;
	float edge = road_half_width + (m3 - 0.5) * 0.9 + (m2 - 0.5) * 0.5;
	float road = 1.0 - smoothstep(edge - 0.3, edge + 0.3, dist);
	float worn = 1.0 - smoothstep(edge, edge + 1.6, dist);
	// wheel ruts & darker, damper centre line
	float rut = exp(-pow((dist - 0.8) / 0.22, 2.0)) * road;
	d_alb *= 1.0 - rut * 0.22;
	d_alb *= mix(1.0, 0.9, (1.0 - smoothstep(0.0, 0.7, dist)) * road);

	// scattered bare-dirt patches in the fields
	float patch = smoothstep(0.7, 0.78, texture(macro_noise, p * 0.03 + vec2(0.13, 0.57)).r) * 0.8;

	float dirt_amt = clamp(max(road, patch), 0.0, 1.0);
	vec3 alb = mix(g_alb, d_alb, dirt_amt);
	alb = mix(alb, alb * vec3(1.05, 0.95, 0.75), worn * (1.0 - road) * 0.6); // trampled grass
	vec3 nrm = mix(g_nrm, d_nrm, dirt_amt);
	float rgh = mix(g_r, d_r, dirt_amt);

	// --- cobblestone plaza in front of the castle
	float plaza = step(plaza_rect.x, p.x) * step(p.x, plaza_rect.z) * step(plaza_rect.y, p.y) * step(p.y, plaza_rect.w);
	float plaza_soft = plaza * smoothstep(0.0, 1.5, min(min(p.x - plaza_rect.x, plaza_rect.z - p.x), min(p.y - plaza_rect.y, plaza_rect.w - p.y)) + (m3 - 0.5) * 1.5);
	vec2 cuv = p * 0.28;
	alb = mix(alb, texture(cobble_albedo, cuv).rgb, plaza_soft);
	nrm = mix(nrm, texture(cobble_normal, cuv).rgb, plaza_soft);
	rgh = mix(rgh, 0.85, plaza_soft);

	// --- rock on steep hills
	float slope = 1.0 - wnrm.y;
	float rockf = smoothstep(0.22, 0.42, slope + (m2 - 0.5) * 0.2);
	vec2 ruv = vec2(p.x + wpos.y * 0.7, p.y - wpos.y * 0.7) * 0.12;
	alb = mix(alb, texture(rock_albedo, ruv).rgb * 0.9, rockf);
	nrm = mix(nrm, texture(rock_normal, ruv).rgb, rockf);

	// snow cover (winter maps): everywhere except the trodden road
	float snow_mask = snow * smoothstep(0.25, 0.55, m2 * 0.6 + m3 * 0.4 + snow * 0.4) * (1.0 - road * 0.85) * (1.0 - plaza_soft * 0.7);
	alb = mix(alb, vec3(0.86, 0.9, 0.95) * (0.88 + 0.12 * m3), clamp(snow_mask, 0.0, 1.0));
	rgh = mix(rgh, 0.55, snow_mask);
	ALBEDO = alb;
	NORMAL_MAP = nrm;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = clamp(rgh, 0.4, 1.0);
	SPECULAR = 0.35;
}
