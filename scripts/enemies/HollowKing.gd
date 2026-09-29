class_name HollowKing
extends Necromancer
## Raises every corpse around him and summons a bone guard (while immune) at
## 66% and 33% health.

var phases_done := 0


func _init() -> void:
	enemy_type = "hollow_king"
	height = 2.2
	raise_radius = 13.0
	raise_max = 6


func _ready() -> void:
	super._ready()
	model_scale *= 1.25
	model_root.scale = Vector3.ONE * model_scale


func _special_process(delta: float) -> void:
	super._special_process(delta)
	var thresholds := [0.66, 0.33]
	if phases_done < thresholds.size() and hp < max_hp * thresholds[phases_done]:
		phases_done += 1
		immune_timer = 5.0
		EventBus.boss_phase.emit(self, "The Hollow King calls his bone guard! (immune)")
		FX.magic_ring(global_position, Color(0.35, 0.8, 1.0), 4.0)
		Sfx.play("roar", -6.0, 0.2, 0.7)
		var em := GameManager.enemy_manager
		if em:
			for i in 6:
				em.spawn_at("skeleton", path_idx, max(0.0, progress - 1.0 - i * 0.7), 1.5 + WaveDefs.HP_SCALE_PER_WAVE * max(0, GameManager.wave - 1))
