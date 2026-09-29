class_name Trebuchet
extends FriendlyUnit
## Siege engine with a crew. Enormous range and splash, very slow, can't hit
## flying enemies or anything closer than its minimum range.
## Special: BARRAGE (five boulders in quick succession).

var barrage_left: int = 0
var barrage_timer: float = 0.0


func _init() -> void:
	unit_type = "trebuchet"


func min_range() -> float:
	return float(def.get("min_range", 6.0))


func can_target(e: Enemy) -> bool:
	return not e.flying and _hdist(e.global_position) >= min_range()


func blast_radius() -> float:
	return float(def.get("radius", 3.0)) * path_mult("radius") * BoonManager.get_mult("radius", unit_type) * spec_mult("radius")


func active_bonuses() -> Array[String]:
	var out := super.active_bonuses()
	out.append("Blast %.1fm, min range %dm" % [blast_radius(), int(min_range())])
	if barrage_left > 0:
		out.append("BARRAGE (%d left)" % barrage_left)
	return out


func _launch(e: Enemy) -> void:
	var from := global_position + Vector3.UP * 4.0
	Projectile.spawn(Projectile.Kind.BOULDER, from, e, get_damage(), Damage.Type.NORMAL, self,
		{"radius": blast_radius(), "fire_payload": has_spec("fire_payload"), "smite_burn": has_spec("fire_payload")})
	Sfx.play("whoosh", -6.0, 0.1, 0.1)
	attack_anim = 1.0


func _perform_attack(e: Enemy) -> void:
	_launch(e)


func _process_movement(delta: float) -> void:
	if barrage_left <= 0:
		return
	barrage_timer -= delta
	if barrage_timer > 0.0:
		return
	barrage_timer = 0.4
	var em := GameManager.enemy_manager
	var cands: Array = []
	for e in em.enemies:
		if is_instance_valid(e) and e.alive and can_target(e) and _hdist(e.global_position) <= get_range():
			cands.append(e)
	if cands.is_empty():
		barrage_left = 0
		return
	barrage_left -= 1
	_launch(cands[randi() % cands.size()])


func _use_special() -> bool:
	var em := GameManager.enemy_manager
	var any := false
	for e in em.enemies:
		if is_instance_valid(e) and e.alive and can_target(e) and _hdist(e.global_position) <= get_range():
			any = true
			break
	if not any:
		say("Nothing worth a boulder in range.", 1)
		return false
	barrage_left = 5
	barrage_timer = 0.0
	say("Load everything! Barrage!", 2)
	return true


func _animate_attack(a: float) -> void:
	var arm: Node3D = rig["arm"]
	# counterweight drops, arm whips over
	arm.rotation.x = lerp(deg_to_rad(-35.0), deg_to_rad(70.0), sin(a * PI))
	var stone := arm.get_node_or_null("Stone") as Node3D
	if stone:
		stone.visible = a < 0.2
	(rig["arm_r"] as Node3D).rotation.x = deg_to_rad(-30) - sin(a * PI) * 1.4
