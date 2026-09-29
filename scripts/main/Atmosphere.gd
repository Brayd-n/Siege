class_name Atmosphere
extends RefCounted
## Sky, fog, tonemapping, post effects and sun/fill lights for a level theme.
## Used by the battle scene and by the main menu backdrop.


static func build(parent: Node, th: Dictionary) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = th["sky_top"]
	sm.sky_horizon_color = th["sky_horizon"]
	sm.sky_curve = 0.12
	sm.ground_bottom_color = Color(0.16, 0.14, 0.12)
	sm.ground_horizon_color = Color(0.72, 0.6, 0.48)
	sm.sun_angle_max = 25.0
	sm.sun_curve = 0.1
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = float(th.get("ambient", 0.75))
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = float(th.get("exposure", 1.05))
	env.tonemap_white = 6.0
	env.ssao_enabled = Profile.high_quality()
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.ssao_light_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(4, 0.6)
	env.fog_enabled = true
	env.fog_light_color = th["fog"]
	env.fog_light_energy = 1.0
	env.fog_density = th["fog_density"]
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	# warm late-afternoon sun with long shadows
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, -128, 0)
	sun.light_color = th["sun"]
	sun.light_energy = th["sun_energy"]
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0 if Profile.high_quality() else 80.0
	sun.directional_shadow_blend_splits = true
	parent.add_child(sun)
	# cool sky fill from the opposite side
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-50, 60, 0)
	fill.light_color = Color(0.55, 0.65, 0.9)
	fill.light_energy = float(th.get("fill", 0.22))
	fill.shadow_enabled = false
	parent.add_child(fill)
