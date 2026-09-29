class_name Spearman
extends FriendlyUnit
## Long pike: hits the target and the enemy behind it, slows both.
## Deals bonus damage to wolf riders. Special: BRACE (stops everything in reach).
## NPC link: when a soldier spots cavalry, nearby Spearmen shout and focus it.


func _init() -> void:
	unit_type = "spearman"


func can_target(e: Enemy) -> bool:
	return not e.flying


func active_bonuses() -> Array[String]:
	var out := super.active_bonuses()
	out.append("x%.1f vs Wolf Riders" % float(def.get("cavalry_bonus", 1.5)))
	return out


func _hit(e: Enemy, mult: float) -> void:
	var dmg := get_damage() * mult
	if e.enemy_type == "wolf_rider":
		dmg *= 2.5 if has_spec("pin") else float(def.get("cavalry_bonus", 1.5))
	var dealt := e.take_damage(dmg, Damage.Type.NORMAL, self)
	on_damage_dealt(e, dealt)
	if e.alive:
		e.apply_slow(0.6, 1.5)
		if has_spec("pin") and not e.is_boss:
			e.apply_slow(0.0, 0.45)
	FX.hit_sparks(e.aim_point(), Color(1, 0.95, 0.8))


func _perform_attack(e: Enemy) -> void:
	var dir := (e.global_position - global_position)
	dir.y = 0
	dir = dir.normalized()
	_hit(e, 1.0)
	FX.slash(e.aim_point(), dir)
	Sfx.play("hit", -8.0, 0.15, 0.05)
	var em := GameManager.enemy_manager
	# Halberdier: sweep everything in reach in front
	if has_spec("sweep") and em:
		for other in em.enemies_near(global_position, get_range(), false):
			if other == e or not (other as Enemy).alive:
				continue
			var to: Vector3 = (other as Enemy).global_position - global_position
			to.y = 0
			if to.normalized().dot(dir) > 0.3:
				_hit(other, 0.8)
		return
	# the pike goes through into the enemy behind
	if em:
		for other in em.enemies_near(e.global_position + dir * 1.4, 1.3, false):
			if other != e and (other as Enemy).alive:
				_hit(other, 0.7)
				break


func _use_special() -> bool:
	var em := GameManager.enemy_manager
	var n := 0
	for e in em.enemies_near(global_position, get_range() + 1.0, false):
		(e as Enemy).apply_slow(0.0, float(def["special"]["duration"]))
		n += 1
	FX.magic_ring(global_position, Color(0.85, 0.8, 0.5), get_range())
	EventBus.camera_shake.emit(0.12)
	say("Brace! Plant your pikes!" if n > 0 else "Pikes ready. Let them come.", 2)
	return true


func _animate_attack(a: float) -> void:
	var arm_r: Node3D = rig["arm_r"]
	var arm_l: Node3D = rig["arm_l"]
	# thrust forward and pull back
	var thrust := sin(a * PI)
	arm_r.rotation.x = deg_to_rad(-35) - thrust * 0.9
	arm_l.rotation.x = deg_to_rad(-55) - thrust * 0.6
	(rig["torso"] as Node3D).rotation.x = thrust * 0.15
