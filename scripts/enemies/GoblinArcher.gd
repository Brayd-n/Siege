class_name GoblinArcher
extends Enemy
## Goblin with a short bow. Periodically shoots at nearby soldiers.

const SHOOT_RANGE := 8.5
const SHOOT_DAMAGE := 7.0
var shoot_timer: float = 2.0


func _init() -> void:
	enemy_type = "goblin_archer"
	height = 1.15


func _special_process(delta: float) -> void:
	shoot_timer -= delta
	if shoot_timer > 0.0:
		return
	var um := GameManager.unit_manager
	if um == null:
		return
	var target: FriendlyUnit = um.nearest_unit(global_position, SHOOT_RANGE, "", true)
	if target == null:
		shoot_timer = 0.4
		return
	shoot_timer = randf_range(2.6, 3.4)
	attack_anim = 1.0
	var pr := Projectile.spawn(Projectile.Kind.ENEMY_ARROW, aim_point(), target, SHOOT_DAMAGE, Damage.Type.NORMAL, self)
	if pr:
		Sfx.play("bow", -12.0, 0.2, 0.1)
