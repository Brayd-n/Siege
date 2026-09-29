class_name Shaman
extends Enemy
## Goblin shaman: heals nearby enemies every few seconds. Kill it first.

const HEAL_RADIUS := 5.5
const HEAL_FRACTION := 0.08
var heal_timer: float = 2.0


func _init() -> void:
	enemy_type = "shaman"
	height = 1.2


func _special_process(delta: float) -> void:
	heal_timer -= delta
	if heal_timer > 0.0:
		return
	heal_timer = 3.0
	var em := GameManager.enemy_manager
	if em == null:
		return
	var healed := 0
	for e in em.enemies_near(global_position, HEAL_RADIUS, false):
		var en := e as Enemy
		if en.hp < en.max_hp:
			en.hp = min(en.max_hp, en.hp + en.max_hp * HEAL_FRACTION)
			en._apply_damage(0.0, null, false)  # refresh the health bar
			healed += 1
	if healed > 0:
		attack_anim = 1.0
		FX.magic_ring(global_position, Color(0.3, 1.0, 0.4), HEAL_RADIUS * 0.6)
