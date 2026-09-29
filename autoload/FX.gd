extends Node
## Visual effect helpers: particle bursts, fire, explosions, floating text.
## Everything is spawned under the Effects node of the running Main scene.

var _soft_tex: GradientTexture2D
var _mat_cache: Dictionary = {}
var _quad: QuadMesh


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.4, Color(1, 1, 1, 0.55))
	_soft_tex = GradientTexture2D.new()
	_soft_tex.gradient = g
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(0.5, 0.0)
	_soft_tex.width = 64
	_soft_tex.height = 64
	_quad = QuadMesh.new()
	_quad.size = Vector2(1, 1)


func root() -> Node:
	if GameManager.main and is_instance_valid(GameManager.main):
		var n := GameManager.main.get_node_or_null("Effects")
		if n:
			return n
		return GameManager.main
	return get_tree().current_scene


func soft_texture() -> Texture2D:
	return _soft_tex


## Billboard particle material (additive for fire/sparks, alpha for smoke/dust).
func particle_material(additive: bool) -> StandardMaterial3D:
	var key := "add" if additive else "mix"
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_tex
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	m.disable_receive_shadows = true
	_mat_cache[key] = m
	return m


func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	for i in colors.size():
		g.add_point(float(i) / max(1, colors.size() - 1), colors[i])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _scale_curve(a: float, b: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	var t := CurveTexture.new()
	t.curve = c
	return t


## Build a GPUParticles3D node. Used both for one-shot bursts and for looping fire.
func make_particles(cfg: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.direction = cfg.get("direction", Vector3.UP)
	pm.spread = cfg.get("spread", 180.0)
	pm.initial_velocity_min = cfg.get("vel_min", 1.0)
	pm.initial_velocity_max = cfg.get("vel_max", 3.0)
	pm.gravity = cfg.get("gravity", Vector3(0, -6, 0))
	pm.damping_min = cfg.get("damping", 0.0)
	pm.damping_max = cfg.get("damping", 0.0)
	pm.scale_min = cfg.get("size_min", 0.2)
	pm.scale_max = cfg.get("size_max", 0.5)
	pm.scale_curve = _scale_curve(cfg.get("scale_start", 1.0), cfg.get("scale_end", 0.0))
	pm.color_ramp = _ramp(cfg.get("colors", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]))
	var box: Vector3 = cfg.get("box", Vector3.ZERO)
	var sphere_r: float = cfg.get("sphere", 0.0)
	if sphere_r > 0.0:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = sphere_r
	elif box != Vector3.ZERO:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = box
	p.process_material = pm
	p.amount = cfg.get("amount", 16)
	p.lifetime = cfg.get("lifetime", 0.6)
	p.one_shot = cfg.get("one_shot", true)
	p.explosiveness = cfg.get("explosiveness", 0.95 if p.one_shot else 0.0)
	p.randomness = 0.5
	p.local_coords = cfg.get("local", false)
	p.draw_pass_1 = _quad
	p.material_override = particle_material(cfg.get("additive", true))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 16, 16))
	return p


func burst(pos: Vector3, cfg: Dictionary) -> void:
	var p := make_particles(cfg)
	root().add_child(p)
	p.global_position = pos
	p.emitting = true
	var life: float = p.lifetime + 0.5
	get_tree().create_timer(life, false).timeout.connect(p.queue_free)


# ------------------------------------------------------------------ presets
func fire_emitter(size: float = 1.0) -> GPUParticles3D:
	return make_particles({
		"one_shot": false, "amount": int(12 * clamp(size, 0.5, 3.0)), "lifetime": 0.65,
		"direction": Vector3.UP, "spread": 12.0, "vel_min": 0.8 * size, "vel_max": 1.8 * size,
		"gravity": Vector3(0, 1.5, 0), "size_min": 0.25 * size, "size_max": 0.5 * size,
		"scale_start": 1.0, "scale_end": 0.1, "sphere": 0.12 * size, "local": false,
		"colors": [Color(0.95, 0.45, 0.1, 0.42), Color(0.85, 0.22, 0.04, 0.35), Color(0.3, 0.04, 0.0, 0.0)],
	})


func smoke_emitter(size: float = 1.0) -> GPUParticles3D:
	return make_particles({
		"one_shot": false, "amount": 10, "lifetime": 2.2, "direction": Vector3.UP, "spread": 15.0,
		"vel_min": 0.6, "vel_max": 1.2, "gravity": Vector3(0.3, 0.5, 0), "size_min": 0.5 * size,
		"size_max": 0.9 * size, "scale_start": 0.4, "scale_end": 1.6, "sphere": 0.2, "additive": false,
		"colors": [Color(0.2, 0.18, 0.16, 0.0), Color(0.25, 0.23, 0.2, 0.35), Color(0.3, 0.3, 0.3, 0.0)],
	})


func hit_sparks(pos: Vector3, color: Color = Color(1.0, 0.85, 0.5)) -> void:
	burst(pos, {"amount": 10, "lifetime": 0.35, "vel_min": 2.0, "vel_max": 5.0, "size_min": 0.06,
		"size_max": 0.14, "gravity": Vector3(0, -9, 0),
		"colors": [color, Color(color.r, color.g * 0.6, color.b * 0.3, 0.0)]})


func blood(pos: Vector3, color: Color) -> void:
	burst(pos, {"amount": 12, "lifetime": 0.5, "vel_min": 1.5, "vel_max": 3.5, "size_min": 0.08,
		"size_max": 0.18, "gravity": Vector3(0, -12, 0), "additive": false,
		"colors": [Color(color, 1.0), Color(color.darkened(0.5), 0.0)]})


func death_puff(pos: Vector3, scale: float = 1.0) -> void:
	burst(pos + Vector3.UP * 0.4 * scale, {"amount": 14, "lifetime": 0.9, "vel_min": 0.8, "vel_max": 2.2 * scale,
		"size_min": 0.4 * scale, "size_max": 0.8 * scale, "gravity": Vector3(0, 0.6, 0), "additive": false,
		"damping": 2.0, "scale_start": 0.6, "scale_end": 1.5, "sphere": 0.3 * scale,
		"colors": [Color(0.42, 0.38, 0.32, 0.6), Color(0.3, 0.28, 0.25, 0.0)]})


func explosion(pos: Vector3, radius: float = 2.5) -> void:
	burst(pos + Vector3.UP * 0.3, {"amount": 36, "lifetime": 0.6, "vel_min": radius * 1.5, "vel_max": radius * 3.0,
		"size_min": 0.5, "size_max": 1.1, "gravity": Vector3(0, 2, 0), "damping": radius * 2.5,
		"scale_start": 1.0, "scale_end": 0.2, "sphere": 0.3,
		"colors": [Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.1, 0.9), Color(0.5, 0.1, 0.02, 0)]})
	burst(pos + Vector3.UP * 0.5, {"amount": 14, "lifetime": 1.4, "vel_min": 1.0, "vel_max": 2.5,
		"size_min": 0.8, "size_max": 1.4, "gravity": Vector3(0, 1.2, 0), "damping": 1.5, "additive": false,
		"scale_start": 0.5, "scale_end": 1.8, "sphere": radius * 0.4,
		"colors": [Color(0.15, 0.12, 0.1, 0.0), Color(0.2, 0.18, 0.15, 0.55), Color(0.3, 0.3, 0.3, 0.0)]})
	_flash_light(pos + Vector3.UP, Color(1.0, 0.6, 0.25), 6.0, radius * 3.0, 0.35)


func magic_ring(pos: Vector3, color: Color, radius: float = 3.0) -> void:
	burst(pos + Vector3.UP * 0.2, {"amount": 40, "lifetime": 0.8, "vel_min": radius * 2.0, "vel_max": radius * 2.4,
		"spread": 90.0, "direction": Vector3.UP, "gravity": Vector3(0, 3, 0), "damping": radius * 2.0,
		"size_min": 0.15, "size_max": 0.3, "colors": [color, Color(color, 0.0)]})


func slash(pos: Vector3, facing: Vector3) -> void:
	burst(pos, {"amount": 12, "lifetime": 0.25, "direction": facing, "spread": 50.0, "vel_min": 4.0,
		"vel_max": 7.0, "gravity": Vector3.ZERO, "size_min": 0.08, "size_max": 0.16,
		"colors": [Color(1, 1, 1, 0.9), Color(0.7, 0.8, 1.0, 0.0)]})


func _flash_light(pos: Vector3, color: Color, energy: float, range_m: float, time: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_m
	l.shadow_enabled = false
	root().add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time)
	tw.tween_callback(l.queue_free)


## Floating text such as "+10" gold or damage callouts.
func float_text(pos: Vector3, text: String, color: Color = Color(1.0, 0.85, 0.3), size: int = 48) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 12
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.01
	l.font = UiTheme.font_bold()
	root().add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3.UP * 1.4, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## Short-lived glowing line between two points (chain lightning, holy smite).
func beam(a: Vector3, b: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var len := a.distance_to(b)
	if len < 0.05:
		return
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.05
	cm.height = len
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 5.0
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root().add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(mi.queue_free)
