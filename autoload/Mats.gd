extends Node
## Material library. Builds PBR StandardMaterial3Ds from the procedural
## textures in res://assets/textures and caches them so every mesh shares them.

const TEX_DIR := "res://assets/textures/"

var _tex_cache: Dictionary = {}
var _mat_cache: Dictionary = {}
var _shader_cache: Dictionary = {}


func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var t: Texture2D = null
	for ext in [".jpg", ".png"]:
		var p: String = TEX_DIR + name + ext
		if ResourceLoader.exists(p):
			t = load(p)
			break
	_tex_cache[name] = t
	return t


func shader(path: String) -> Shader:
	if not _shader_cache.has(path):
		_shader_cache[path] = load(path)
	return _shader_cache[path]


## Generic PBR material from a texture set name (e.g. "bricks").
## world = world-space triplanar (static props), otherwise object-space triplanar.
func pbr(set_name: String, color: Color = Color.WHITE, scale: float = 0.25, world: bool = true,
		albedo_name: String = "", normal_strength: float = 1.0, rough_mult: float = 1.0,
		metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var a := tex((albedo_name if albedo_name != "" else set_name) + "_albedo")
	var n := tex(set_name + "_normal")
	var r := tex(set_name + "_rough")
	m.albedo_color = color
	if a:
		m.albedo_texture = a
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = normal_strength
	if r:
		m.roughness_texture = r
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = rough_mult
	m.metallic = metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3(scale, scale, scale)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func get_mat(key: String) -> Material:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m: Material = _build(key)
	_mat_cache[key] = m
	return m


## Tinted cloth (fabric weave), cached per colour.
func cloth(c: Color) -> StandardMaterial3D:
	var key := "cloth_" + c.to_html(false)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := pbr("fabric", c, 3.0, false)
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	_mat_cache[key] = m
	return m


func leather(c: Color = Color(0.45, 0.3, 0.18)) -> StandardMaterial3D:
	var key := "leather_" + c.to_html(false)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := pbr("leather", c, 2.5, false)
	_mat_cache[key] = m
	return m


func skin(c: Color) -> StandardMaterial3D:
	var key := "skin_" + c.to_html(false)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := pbr("skin", c, 2.0, false, "", 0.6, 0.62)
	m.roughness_texture = null
	m.roughness = 0.58
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.4
	m.subsurf_scatter_enabled = false
	m.backlight_enabled = true
	m.backlight = Color(c.r * 0.35, c.g * 0.18, c.b * 0.12)
	_mat_cache[key] = m
	return m


func emissive(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "emit_%s_%.2f" % [c.to_html(false), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_mat_cache[key] = m
	return m


func flat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var key := "flat_%s_%.2f_%.2f" % [c.to_html(true), rough, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_cache[key] = m
	return m


func _build(key: String) -> Material:
	match key:
		"stone_wall":
			return pbr("bricks", Color(0.95, 0.93, 0.9), 0.28, true, "", 1.2)
		"stone_dark":
			return pbr("bricks", Color(0.5, 0.5, 0.55), 0.3, true, "", 1.2)
		"cobble":
			return pbr("cobble", Color.WHITE, 0.3, true)
		"rock":
			return pbr("rock", Color(0.95, 0.95, 0.95), 0.22, true, "", 1.3)
		"rock_dark":
			return pbr("rock", Color(0.42, 0.4, 0.44), 0.25, true, "", 1.3)
		"wood":
			return pbr("planks", Color(0.95, 0.9, 0.85), 0.5, true)
		"wood_dark":
			return pbr("planks", Color(0.42, 0.33, 0.26), 0.5, true)
		"wood_obj":
			return pbr("planks", Color(0.8, 0.7, 0.6), 2.0, false)
		"plaster":
			return pbr("plaster", Color.WHITE, 0.35, true)
		"roof_red":
			return pbr("roof", Color.WHITE, 0.4, true, "roof_red")
		"roof_slate":
			return pbr("roof", Color.WHITE, 0.4, true, "roof_slate")
		"bark":
			var m := pbr("bark", Color(0.9, 0.88, 0.85), 1.2, false, "", 1.4)
			return m
		"metal":
			var m2 := pbr("metal", Color(0.78, 0.8, 0.84), 3.0, false, "", 0.5, 1.0, 0.9)
			return m2
		"metal_dark":
			var m3 := pbr("metal", Color(0.32, 0.32, 0.34), 3.0, false, "", 0.5, 1.2, 0.85)
			return m3
		"gold":
			var g := pbr("metal", Color(1.0, 0.76, 0.33), 3.0, false, "", 0.3, 0.7, 1.0)
			return g
		"rope":
			return pbr("fabric", Color(0.62, 0.52, 0.36), 6.0, false)
		"hay":
			return pbr("bark", Color(0.95, 0.8, 0.45), 1.5, false, "", 0.6)
		"dragon_scales":
			var d := pbr("scales", Color(0.62, 0.12, 0.08), 2.2, false, "", 1.5)
			d.rim_enabled = true
			d.rim = 0.3
			return d
		"dragon_belly":
			return pbr("scales", Color(0.85, 0.62, 0.32), 3.0, false, "", 1.0)
		"dragon_wing":
			var w := StandardMaterial3D.new()
			w.albedo_color = Color(0.36, 0.07, 0.06)
			w.roughness = 0.7
			w.cull_mode = BaseMaterial3D.CULL_DISABLED
			w.backlight_enabled = true
			w.backlight = Color(0.6, 0.12, 0.04)
			w.normal_enabled = true
			w.normal_texture = tex("leather_normal")
			w.uv1_triplanar = true
			w.uv1_scale = Vector3(0.6, 0.6, 0.6)
			return w
		"bone":
			return pbr("plaster", Color(0.92, 0.88, 0.76), 3.0, false, "", 0.6, 0.6)
		"fur_dark":
			return pbr("leather", Color(0.28, 0.26, 0.26), 4.0, false, "", 1.4)
		"fur_grey":
			return pbr("leather", Color(0.46, 0.44, 0.42), 4.0, false, "", 1.4)
		"moss":
			return pbr("grass", Color(0.8, 0.9, 0.7), 2.0, false)
		"eye_yellow":
			return emissive(Color(1.0, 0.8, 0.2), 3.0)
		"eye_red":
			return emissive(Color(1.0, 0.2, 0.1), 3.0)
		"eye_dark":
			return flat(Color(0.05, 0.04, 0.04), 0.2)
		"fire":
			return emissive(Color(1.0, 0.45, 0.1), 2.2)
		"window_glow":
			return emissive(Color(1.0, 0.7, 0.35), 2.2)
		"portal":
			var s := ShaderMaterial.new()
			s.shader = shader("res://assets/shaders/portal.gdshader")
			return s
		"banner_red":
			return _banner(Color(0.55, 0.06, 0.06), Color(0.95, 0.75, 0.3))
		"banner_blue":
			return _banner(Color(0.08, 0.14, 0.42), Color(0.95, 0.75, 0.3))
		"leaves":
			return _foliage("leaves")
		"needles":
			return _foliage("needles")
	push_warning("Mats: unknown material key " + key)
	return flat(Color.MAGENTA)


func _banner(base: Color, trim: Color) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = shader("res://assets/shaders/banner.gdshader")
	s.set_shader_parameter("base_color", base)
	s.set_shader_parameter("trim_color", trim)
	s.set_shader_parameter("fabric_tex", tex("fabric_albedo"))
	s.set_shader_parameter("fabric_normal", tex("fabric_normal"))
	return s


func _foliage(name: String) -> ShaderMaterial:
	var s := ShaderMaterial.new()
	s.shader = shader("res://assets/shaders/foliage.gdshader")
	s.set_shader_parameter("leaf_tex", tex(name + "_albedo"))
	return s
