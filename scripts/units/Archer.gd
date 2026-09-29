class_name Archer
extends FriendlyUnit
## Fast-firing bowman. Special: VOLLEY (triple fire rate).
## Synergies: shoots faster when a Knight stands nearby; +20% vs burning enemies
## (handled in Projectile._hit_single).

const COVER_RANGE := 6.0


func _init() -> void:
	unit_type = "archer"


func has_knight_cover() -> bool:
	var um := GameManager.unit_manager
	if um == null:
		return false
	return um.nearest_unit(global_position, COVER_RANGE, "knight", true, self) != null


func cover_bonus() -> float:
	return 1.35 if BoonManager.has_flag("kings_guard") else 1.15


func _speed_bonus() -> float:
	var b := 1.0
	if special_active > 0.0:
		b *= 3.0
	if has_knight_cover():
		b *= cover_bonus()
	return b


func active_bonuses() -> Array[String]:
	var out := super.active_bonuses()
	if has_knight_cover():
		out.append("Knight's Cover (+%d%% speed)" % int(round((cover_bonus() - 1.0) * 100)))
	if special_active > 0.0:
		out.append("VOLLEY (%.0fs)" % special_active)
	if BoonManager.has_flag("fire_arrows"):
		out.append("Fire Arrows")
	return out


func _perform_attack(e: Enemy) -> void:
	_shoot(e)
	# Ranger: extra arrows at other enemies in range
	if has_spec("multishot"):
		var em := GameManager.enemy_manager
		var extra := 0
		for o in em.enemies:
			if extra >= 2:
				break
			if o != e and is_instance_valid(o) and o.alive and not o.is_hidden() and _hdist(o.global_position) <= get_range():
				_shoot(o)
				extra += 1
	Sfx.play("bow", -10.0, 0.12, 0.06)


func _shoot(e: Enemy) -> void:
	var from := global_position + Vector3.UP * 2.1 + (e.global_position - global_position).normalized() * 0.4
	Projectile.spawn(Projectile.Kind.ARROW, from, e, get_damage(), Damage.Type.NORMAL, self,
		{"fire": BoonManager.has_flag("fire_arrows"), "skyhunter": has_spec("skyhunter")})


func _use_special() -> bool:
	special_active = float(def["special"]["duration"])
	attack_timer = 0.0
	say("Volley! Loose everything you've got!", 2)
	FX.magic_ring(global_position, Color(0.5, 1.0, 0.5), 2.0)
	return true


func _animate_attack(a: float) -> void:
	var arm_r: Node3D = rig["arm_r"]
	# draw hand pulls back, then snaps forward on release
	arm_r.rotation.x = deg_to_rad(-70) + a * 0.25
	arm_r.rotation.y = deg_to_rad(-25) - (1.0 - a) * 0.35
	var bow: Node3D = rig["weapon"]
	bow.scale = Vector3.ONE * (1.0 + a * 0.06)
