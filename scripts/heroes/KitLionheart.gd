extends HeroKit
## Sir Aldric: stands on the road and holds enemies in place (up to 3),
## charges through lines and roars to stun.

const HOLD_RANGE := 1.9
const HOLD_MAX := 3
var held: Array = []
var scan := 0.0


func process(delta: float) -> void:
	scan -= delta
	if scan > 0.0:
		return
	scan = 0.15
	# release enemies that walked off or died
	for e in held.duplicate():
		if not is_instance_valid(e) or not e.alive or u._hdist(e.global_position) > HOLD_RANGE + 0.8:
			if is_instance_valid(e) and e.blocked_by == u:
				e.blocked_by = null
			held.erase(e)
	if held.size() >= HOLD_MAX or u.downed:
		return
	for e in enemies_in(u.global_position, HOLD_RANGE, false):
		var en := e as Enemy
		if en.is_boss or held.has(en) or en.blocked_by != null:
			continue
		en.blocked_by = u
		held.append(en)
		if held.size() >= HOLD_MAX:
			break


func on_moved() -> void:
	for e in held:
		if is_instance_valid(e) and e.blocked_by == u:
			e.blocked_by = null
	held.clear()


func damage_mult() -> float:
	return 1.5 if u.hp < u.get_max_hp() * 0.3 else 1.0


func modify_damage_taken(amount: float, _source: Node) -> float:
	return amount * 0.75


func _cast(i: int, pos: Vector3) -> bool:
	if i == 0:
		return _charge(pos)
	return _roar()


func _charge(pos: Vector3) -> bool:
	var from := u.global_position
	var to := Vector3(pos.x, 0, pos.z)
	var d := to - from
	d.y = 0
	if d.length() > 18.0:
		to = from + d.normalized() * 18.0
	# stop at the furthest spot along the line where he can actually stand
	var dir0 := (to - from)
	dir0.y = 0
	var tries := int(dir0.length())
	while tries > 0 and not u.hero_can_stand(to):
		to -= dir0.normalized()
		tries -= 1
	if tries <= 0 or from.distance_to(to) < 1.5:
		u.say("I can't charge there!", 1)
		cds[0] = 1.0   # short retry delay so a bad click can't spam
		return false
	# hit everything along the line
	var dir := (to - from).normalized()
	var length := from.distance_to(to)
	var em := GameManager.enemy_manager
	if em:
		for e in em.enemies.duplicate():
			if not is_instance_valid(e) or not e.alive or e.flying:
				continue
			var rel: Vector3 = e.global_position - from
			rel.y = 0
			var along := rel.dot(dir)
			if along < -1.0 or along > length + 1.5:
				continue
			if (rel - dir * along).length() < 2.2:
				hit(e, ability_damage(2.0))
				if e.alive and not e.is_boss:
					e.progress = max(0.0, e.progress - 2.5)
				FX.hit_sparks(e.aim_point(), Color(1.0, 0.9, 0.5))
	u.hero_relocate(to, 0.35)
	FX.slash(to + Vector3.UP, dir)
	EventBus.camera_shake.emit(0.2)
	u.say("FOR THE REALM!", 2)
	return true


func _roar() -> bool:
	for e in enemies_in(u.global_position, 7.0, false):
		var en := e as Enemy
		en.apply_slow(0.5 if en.is_boss else 0.0, 2.5)
	var um := GameManager.unit_manager
	for a in um.units_near(u.global_position, 10.0):
		(a as FriendlyUnit).rally_timer = 8.0
	if HeroGear.has_legendary(id, "lion_oath"):
		u.hp = min(u.get_max_hp(), u.hp + u.get_max_hp() * 0.4)
	FX.magic_ring(u.global_position, Color(1.0, 0.75, 0.3), 7.0)
	FX.magic_ring(u.global_position, Color(1.0, 0.9, 0.6), 10.0)
	EventBus.camera_shake.emit(0.35)
	Sfx.play("roar", -2.0, 0.1, 1.2)
	u.say("Stand with me! NONE SHALL PASS!", 2)
	return true
