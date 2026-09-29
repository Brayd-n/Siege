class_name Necromancer
extends Enemy
## Raises fresh goblin corpses near it as skeletons. With nothing to raise it
## still pulls a skeleton out of the ground now and then.

@export var raise_radius := 9.0
@export var raise_max := 3
var raise_timer := 4.0
var idle_raise_timer := 9.0


func _init() -> void:
	enemy_type = "necromancer"
	height = 1.8


func _special_process(delta: float) -> void:
	var w: Node3D = rig.get("weapon")
	if w:
		var orb := w.get_node_or_null("Orb")
		if orb:
			orb.scale = Vector3.ONE * (1.0 + 0.3 * sin(anim_t * 4.0))
	raise_timer -= delta
	idle_raise_timer -= delta
	if raise_timer > 0.0:
		return
	raise_timer = 5.0
	var em := GameManager.enemy_manager
	if em == null:
		return
	var bodies: Array = em.take_corpses(global_position, raise_radius, raise_max)
	if bodies.is_empty() and idle_raise_timer <= 0.0:
		idle_raise_timer = 10.0
		bodies = [{"pos": global_position, "path_idx": path_idx, "progress": max(0.0, progress - 2.0)}]
	if bodies.is_empty():
		return
	attack_anim = 1.0
	FX.magic_ring(global_position, Color(0.5, 1.0, 0.4), 2.0)
	Sfx.play("ability", -10.0, 0.2, 0.6)
	for c in bodies:
		var sk: Enemy = em.spawn_at("skeleton", int(c["path_idx"]), float(c["progress"]), 1.0 + WaveDefs.HP_SCALE_PER_WAVE * max(0, GameManager.wave - 1))
		if sk:
			FX.magic_ring(sk.global_position, Color(0.4, 1.0, 0.5), 1.0)
