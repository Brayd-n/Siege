class_name Warlord
extends Enemy
## Grukk: war cry buffs nearby goblins (faster, tougher) and his horn calls
## reinforcements. On Twin Fords there are two; if one falls the other rages.

const AURA_RADIUS := 9.0
const BUFFED := ["goblin", "goblin_archer", "wolf_rider", "sapper", "shieldbearer", "shaman"]
var aura_timer := 0.0
var horn_timer := 9.0
var raging := false


func _init() -> void:
	enemy_type = "warlord"
	height = 2.3


func _ready() -> void:
	super._ready()
	model_scale *= 1.45
	model_root.scale = Vector3.ONE * model_scale
	EventBus.enemy_killed.connect(_on_killed)


func _on_killed(e, _k) -> void:
	if e != self and is_instance_valid(e) and e is Warlord and alive and not raging:
		raging = true
		speed *= 1.5
		apply_buff(1.0, 0.25, 9999.0)
		EventBus.boss_phase.emit(self, "%s roars in fury!" % def.get("title", display_name))
		FX.magic_ring(global_position, Color(1.0, 0.2, 0.1), 3.0)


func _special_process(delta: float) -> void:
	aura_timer -= delta
	if aura_timer <= 0.0:
		aura_timer = 0.8
		var em := GameManager.enemy_manager
		if em:
			for e in em.enemies_near(global_position, AURA_RADIUS, false):
				if (e as Enemy).enemy_type in BUFFED:
					(e as Enemy).apply_buff(1.35, 0.3, 1.2)
	horn_timer -= delta
	if horn_timer <= 0.0:
		horn_timer = 11.0
		attack_anim = 1.0
		Sfx.play("horn", -4.0, 0.1, 0.7)
		FX.magic_ring(global_position, Color(1.0, 0.45, 0.15), AURA_RADIUS * 0.6)
		var em2 := GameManager.enemy_manager
		if em2:
			for i in 4:
				em2.spawn_at("goblin", path_idx, max(0.0, progress - 1.5 - i * 0.8), 1.0 + WaveDefs.HP_SCALE_PER_WAVE * max(0, GameManager.wave - 1))
