class_name Cleric
extends FriendlyUnit
## Support soldier. Heals allies in range every 2 seconds, blesses them
## (+12% damage, applied in FriendlyUnit via the `blessed` flag) and speeds up
## the recovery of downed allies. Smites enemies with a weak holy bolt.
## Special: DIVINE LIGHT (revive + full heal allies, burn nearby enemies).
## NPC link: when a soldier nearby goes down, the Cleric answers and gets them
## back on their feet quickly (DialogueManager).

const PULSE := 2.0
var pulse_timer: float = 1.0


func _init() -> void:
	unit_type = "cleric"


func heal_amount() -> float:
	return float(def.get("heal", 12.0)) * path_mult("heal") * BoonManager.get_mult("heal", unit_type) * spec_mult("heal")


func active_bonuses() -> Array[String]:
	var out := super.active_bonuses()
	out.append("Heals %d / 2s" % int(heal_amount()))
	out.append("Blesses allies +12% dmg")
	return out


func _process_movement(delta: float) -> void:
	pulse_timer -= delta
	if pulse_timer > 0.0:
		return
	pulse_timer = PULSE
	var um := GameManager.unit_manager
	if um == null:
		return
	var healed := false
	for u in um.units_near(global_position, get_range()):
		var fu := u as FriendlyUnit
		if fu.downed:
			fu.downed_timer = max(0.0, fu.downed_timer - 2.5)
			healed = true
		elif fu.hp < fu.get_max_hp():
			fu.hp = min(fu.get_max_hp(), fu.hp + heal_amount())
			healed = true
			FX.burst(fu.global_position + Vector3.UP * 1.5, {"amount": 8, "lifetime": 0.6, "vel_min": 0.5,
				"vel_max": 1.2, "gravity": Vector3(0, 1.5, 0), "size_min": 0.08, "size_max": 0.14,
				"colors": [Color(1, 0.95, 0.6, 1), Color(0.6, 1.0, 0.6, 0)]})
	if healed:
		attack_anim = max(attack_anim, 0.5)


func _perform_attack(e: Enemy) -> void:
	var dealt := e.take_damage(get_damage(), Damage.Type.ARCANE, self)
	on_damage_dealt(e, dealt)
	if has_spec("smite_burn") and e.alive:
		e.apply_burn(10.0, 3.0, self)
	FX.beam(e.aim_point() + Vector3.UP * 6.0, e.aim_point(), Color(1.0, 0.9, 0.5))
	FX.hit_sparks(e.aim_point(), Color(1.0, 0.9, 0.5))


func _use_special() -> bool:
	var um := GameManager.unit_manager
	var saved := 0
	for u in um.units_near(global_position, get_range() * 1.25):
		var fu := u as FriendlyUnit
		if fu.downed:
			fu.revive(1.0)
			saved += 1
		fu.full_heal()
		FX.magic_ring(fu.global_position, Color(1.0, 0.9, 0.5), 1.2)
	var em := GameManager.enemy_manager
	for e in em.enemies_near(global_position, get_range(), true):
		var en := e as Enemy
		on_damage_dealt(en, en.take_damage(60.0 * path_mult("heal"), Damage.Type.ARCANE, self))
	FX.magic_ring(global_position, Color(1.0, 0.92, 0.6), get_range() * 1.25)
	say("By the Light, rise!" if saved > 0 else "Light, shield these brave souls!", 2)
	return true


func _animate_attack(a: float) -> void:
	var arm_l: Node3D = rig["arm_l"]
	arm_l.rotation.x = deg_to_rad(-60) - sin(a * PI) * 1.0
