class_name FirePatch
extends Node3D
## Burning ground created by the Torch Thrower's special ability.

var radius: float = 3.0
var duration: float = 6.0
var dps: float = 18.0
var source: Node = null
var _tick: float = 0.0
var _age: float = 0.0
var _light: OmniLight3D
var _flames: GPUParticles3D


static func create(parent: Node, pos: Vector3, r: float, time: float, damage_per_sec: float, src: Node) -> FirePatch:
	var fp := FirePatch.new()
	fp.radius = r
	fp.duration = time
	fp.dps = damage_per_sec
	fp.source = src
	parent.add_child(fp)
	fp.global_position = Vector3(pos.x, 0.05, pos.z)
	return fp


func _ready() -> void:
	_flames = FX.make_particles({
		"one_shot": false, "amount": int(40 * radius), "lifetime": 0.9, "direction": Vector3.UP, "spread": 10.0,
		"vel_min": 1.0, "vel_max": 2.6, "gravity": Vector3(0, 1.0, 0), "size_min": 0.4, "size_max": 0.9,
		"box": Vector3(radius * 0.8, 0.05, radius * 0.8), "scale_start": 1.0, "scale_end": 0.1,
		"colors": [Color(1, 0.9, 0.5, 1), Color(1, 0.45, 0.1, 0.85), Color(0.5, 0.08, 0.02, 0)],
	})
	add_child(_flames)
	_flames.emitting = true
	var smoke := FX.smoke_emitter(1.4)
	smoke.position = Vector3(0, 1.0, 0)
	add_child(smoke)
	smoke.emitting = true
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.5, 0.2)
	_light.light_energy = 3.0
	_light.omni_range = radius * 3.0
	_light.position = Vector3(0, 1.2, 0)
	add_child(_light)
	# scorched ground disc
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	disc.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.05, 0.0, 0.65)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.05)
	m.emission_energy_multiplier = 1.2
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = m
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(disc)
	Sfx.play("whoosh", 0.0, 0.1, 0.2)


func _process(delta: float) -> void:
	_age += delta
	_tick -= delta
	_light.light_energy = 3.0 * (0.85 + 0.15 * sin(_age * 17.0)) * clamp((duration - _age) / 1.0, 0.0, 1.0)
	if _tick <= 0.0:
		_tick = 0.25
		if not is_instance_valid(source):
			source = null   # the soldier who lit it was sold
		var em := GameManager.enemy_manager
		if em:
			for e in em.enemies_near(global_position, radius, false):
				var en := e as Enemy
				var dealt := en.take_damage(dps * 0.25, Damage.Type.FIRE, source)
				if is_instance_valid(source) and source is FriendlyUnit:
					(source as FriendlyUnit).on_damage_dealt(en, dealt)
				if en.alive:
					en.apply_burn(8.0, 2.0, source)
	if _age >= duration:
		_flames.emitting = false
		set_process(false)
		var tw := create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(queue_free)
