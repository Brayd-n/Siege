class_name Shade
extends Enemy
## Night boss: blinks forward along the road and calls bats. Hidden in the dark.

var blink_timer := 8.0
var bat_timer := 12.0


func _init() -> void:
	enemy_type = "shade"
	height = 2.2


func _ready() -> void:
	super._ready()
	model_scale *= 1.2
	model_root.scale = Vector3.ONE * model_scale


func _animate(delta: float) -> void:
	super._animate(delta)
	(rig["body"] as Node3D).position.y = 0.25 + sin(anim_t * 1.3) * 0.15


func _special_process(delta: float) -> void:
	blink_timer -= delta
	bat_timer -= delta
	if blink_timer <= 0.0:
		blink_timer = 9.0
		FX.magic_ring(global_position, Color(0.4, 0.5, 1.0), 2.0)
		progress = min(progress + 7.0, map.length_of(path_idx) - 4.0)
		FX.magic_ring(map.sample_on(path_idx, progress), Color(0.4, 0.5, 1.0), 2.0)
		Sfx.play("whoosh", -4.0, 0.2, 0.4)
	if bat_timer <= 0.0:
		bat_timer = 14.0
		var em := GameManager.enemy_manager
		if em:
			for i in 4:
				em.spawn_at("bat", path_idx, max(0.0, progress - 1.0 - i * 0.6))
