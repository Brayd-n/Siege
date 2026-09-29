class_name ElderDragon
extends Dragon
## Vyraxis: summons bat swarms, and goes berserk at half health.

var bat_timer := 10.0
var enraged := false


func _init() -> void:
	super._init()
	enemy_type = "elder_dragon"


func _ready() -> void:
	super._ready()
	model_scale *= 1.2
	model_root.scale = Vector3.ONE * model_scale


func _special_process(delta: float) -> void:
	super._special_process(delta)
	bat_timer -= delta
	if bat_timer <= 0.0:
		bat_timer = 12.0 if not enraged else 8.0
		var em := GameManager.enemy_manager
		if em:
			for i in 6:
				em.spawn_at("bat", path_idx, max(0.0, progress - 1.0 - i * 0.6))
			Sfx.play("roar", -4.0, 0.2, 1.3)
	if not enraged and hp < max_hp * 0.5:
		enraged = true
		speed *= 1.35
		breath_rate = 0.55
		EventBus.boss_phase.emit(self, "Vyraxis is enraged!")
		EventBus.camera_shake.emit(0.7)
		Sfx.play("roar", 4.0, 0.0, 0.8)
