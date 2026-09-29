class_name Crossbowman
extends FriendlyUnit
## Slow, long ranged, armour piercing. Bolts pierce through lines of enemies.
## Special: PIERCING SHOT (empowered bolts for a few seconds).


func _init() -> void:
	unit_type = "crossbowman"


func pierce_count() -> int:
	var p := int(def.get("pierce", 1)) + int(path_add("pierce")) + int(BoonManager.get_add("pierce"))
	if special_active > 0.0:
		p = max(p, 6)
	return p


func active_bonuses() -> Array[String]:
	var out := super.active_bonuses()
	out.append("Pierces %d" % pierce_count())
	if special_active > 0.0:
		out.append("PIERCING SHOT (%.0fs)" % special_active)
	return out


func _perform_attack(e: Enemy) -> void:
	_fire_bolt(e)
	if has_spec("burst"):
		for i in 2:
			get_tree().create_timer(0.14 * (i + 1), false).timeout.connect(_burst_bolt.bind(e))


func _burst_bolt(e) -> void:
	if not downed and is_instance_valid(e) and e.alive:
		_fire_bolt(e)


func _fire_bolt(e: Enemy) -> void:
	var dmg := get_damage() * (1.5 if special_active > 0.0 else 1.0)
	var from := global_position + Vector3.UP * 2.0 + (e.global_position - global_position).normalized() * 0.6
	var ex := {"pierce": pierce_count(), "empowered": special_active > 0.0}
	if has_spec("knockback"):
		ex["knockback"] = 1.6
	Projectile.spawn(Projectile.Kind.BOLT, from, e, dmg, Damage.Type.PIERCING, self, ex)
	Sfx.play("crossbow", -6.0, 0.1, 0.05)


func _use_special() -> bool:
	special_active = float(def["special"]["duration"])
	attack_timer = min(attack_timer, 0.2)
	say("Piercing bolts loaded. Nothing survives this!", 2)
	FX.magic_ring(global_position, Color(0.6, 0.85, 1.0), 2.0)
	return true


func _animate_attack(a: float) -> void:
	var torso: Node3D = rig["torso"]
	torso.rotation.x = -a * 0.18
	var w: Node3D = rig["weapon"]
	w.rotation.x = deg_to_rad(80) - a * 0.3
	var bolt := w.get_node_or_null("LoadedBolt") as Node3D
	if bolt:
		bolt.visible = attack_timer < get_attack_interval() * 0.6
