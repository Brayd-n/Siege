class_name BattleMage
extends FriendlyUnit
## Arcane bolts ignore armour and jump to nearby enemies.
## Special: FROST NOVA (damage + heavy slow on everything in range).


func _init() -> void:
	unit_type = "battle_mage"


func chain_count() -> int:
	return int(def.get("chain", 2)) + int(path_add("chain")) + int(BoonManager.get_add("chain")) + int(spec_add("chain"))


func active_bonuses() -> Array[String]:
	var out := super.active_bonuses()
	out.append("Chains to %d" % chain_count())
	out.append("Ignores armour")
	return out


func _perform_attack(e: Enemy) -> void:
	var staff: Node3D = rig["weapon"]
	var orb := staff.get_node_or_null("Orb") as Node3D
	var from := orb.global_position if orb else global_position + Vector3.UP * 2.4
	var ex := {"chain": chain_count()}
	if has_spec("storm"):
		ex["stun"] = 0.3
	if has_spec("chill"):
		ex["chill"] = [0.65, 2.0]
		ex["shatter"] = true
	Projectile.spawn(Projectile.Kind.ARCANE, from, e, get_damage(), Damage.Type.ARCANE, self, ex)
	Sfx.play("ability", -16.0, 0.3, 0.08)


func _use_special() -> bool:
	var em := GameManager.enemy_manager
	var hit := 0
	for e in em.enemies_near(global_position, get_range(), true):
		var en := e as Enemy
		var dealt := en.take_damage(get_damage() * 2.0, Damage.Type.ARCANE, self)
		on_damage_dealt(en, dealt)
		if en.alive:
			en.apply_slow(0.4, float(def["special"]["duration"]))
		FX.hit_sparks(en.aim_point(), Color(0.6, 0.85, 1.0))
		hit += 1
	FX.magic_ring(global_position, Color(0.55, 0.8, 1.0), get_range())
	FX.magic_ring(global_position, Color(0.8, 0.95, 1.0), get_range() * 0.6)
	say("Frost Nova! Freeze where you stand!" if hit > 0 else "The air is cold... nothing to freeze yet.", 2)
	return true


func _animate_attack(a: float) -> void:
	var arm_r: Node3D = rig["arm_r"]
	arm_r.rotation.x = deg_to_rad(-20) - sin(a * PI) * 1.2
	var staff: Node3D = rig["weapon"]
	var orb := staff.get_node_or_null("Orb") as Node3D
	if orb:
		orb.scale = Vector3.ONE * (1.0 + a * 0.8 + sin(anim_t * 4.0) * 0.08)
