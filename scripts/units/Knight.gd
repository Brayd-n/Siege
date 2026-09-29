class_name Knight
extends FriendlyUnit
## Melee defender placed right next to the road. Can leave its post to help
## allies who call for support, then walks back. Special: SHIELD WALL.

const LEASH := 10.0
const MOVE_SPEED := 4.5
const SHIELD_WALL_RANGE := 8.0

var moving: bool = false


func _init() -> void:
	unit_type = "knight"


func can_target(e: Enemy) -> bool:
	return not e.flying


func _damage_bonus() -> float:
	var b := 1.0
	if shield_wall_timer > 0.0:
		b *= 1.5
	if BoonManager.has_flag("shield_brothers"):
		b *= 1.0 + 0.15 * brothers_nearby()
	return b


func brothers_nearby() -> int:
	var um := GameManager.unit_manager
	if um == null:
		return 0
	return min(3, um.units_near(global_position, 7.0, "knight").size() - 1)


func active_bonuses() -> Array[String]:
	var out := super.active_bonuses()
	if shield_wall_timer > 0.0 and not out.has("Shield Wall"):
		out.append("Shield Wall")
	if BoonManager.has_flag("shield_brothers") and brothers_nearby() > 0:
		out.append("Shield Brothers x%d" % brothers_nearby())
	return out


func _process_movement(delta: float) -> void:
	var goal := home_position
	if support_timer > 0.0 and is_instance_valid(support_ally) and not support_ally.downed:
		var to_ally := support_ally.global_position - home_position
		to_ally.y = 0
		var dest := support_ally.global_position - to_ally.normalized() * 1.4
		if dest.distance_to(home_position) > LEASH:
			dest = home_position + (dest - home_position).normalized() * LEASH
		goal = dest
	var d := goal - global_position
	d.y = 0
	if d.length() > 0.15:
		var step: float = min(d.length(), MOVE_SPEED * delta)
		global_position += d.normalized() * step
		moving = true
		if target == null:
			_face(global_position + d, delta)
	else:
		moving = false


func _perform_attack(e: Enemy) -> void:
	var dmg := get_damage()
	var dealt := e.take_damage(dmg, Damage.Type.NORMAL, self)
	on_damage_dealt(e, dealt)
	if has_spec("lifesteal") and not downed:
		hp = min(get_max_hp(), hp + get_max_hp() * 0.05)
	var dir := (e.global_position - global_position).normalized()
	FX.slash(e.aim_point(), dir)
	FX.hit_sparks(e.aim_point(), Color(1, 0.95, 0.8))
	Sfx.play("sword", -8.0, 0.15, 0.05)
	# small cleave on enemies packed around the target
	var em := GameManager.enemy_manager
	if em:
		var berserk := has_spec("cleave")
		var cleaved := 0
		for other in em.enemies_near(e.global_position, 2.4 if berserk else 1.4, false):
			if other != e and (other as Enemy).alive:
				var d2 := (other as Enemy).take_damage(dmg * (0.8 if berserk else 0.3), Damage.Type.NORMAL, self)
				on_damage_dealt(other, d2)
				cleaved += 1
				if berserk and cleaved >= 3:
					break


func _use_special() -> bool:
	var um := GameManager.unit_manager
	var dur := float(def["special"]["duration"])
	var count := 0
	for k in um.units_near(global_position, SHIELD_WALL_RANGE, "knight"):
		var kn := k as FriendlyUnit
		if kn.downed:
			continue
		kn.shield_wall_timer = dur
		FX.magic_ring(kn.global_position, Color(0.45, 0.65, 1.0), 2.0)
		if kn != self:
			count += 1
			kn.say("Shields locked!", 1)
	say("SHIELD WALL! Lock shields!" if count > 0 else "Shield up! I'll hold alone if I must!", 2)
	EventBus.camera_shake.emit(0.1)
	return true


func _animate(delta: float) -> void:
	super._animate(delta)
	var legs_l: Node3D = rig["leg_l"]
	var legs_r: Node3D = rig["leg_r"]
	if moving:
		var s := sin(anim_t * 10.0)
		legs_l.rotation.x = s * 0.6
		legs_r.rotation.x = -s * 0.6
	else:
		legs_l.rotation.x = lerp(legs_l.rotation.x, 0.0, 0.2)
		legs_r.rotation.x = lerp(legs_r.rotation.x, 0.0, 0.2)
	var arm_l: Node3D = rig["arm_l"]
	arm_l.rotation.x = deg_to_rad(-35) - (0.5 if shield_wall_timer > 0.0 else 0.0)


func _animate_attack(a: float) -> void:
	var arm_r: Node3D = rig["arm_r"]
	# raise and chop
	arm_r.rotation.x = deg_to_rad(-30) - sin(a * PI) * 1.9
	arm_r.rotation.z = -sin(a * PI) * 0.3
