extends HeroKit
## Lyra: marks enemies (they take more damage from everyone), finishes off
## wounded enemies, and her falcon dives at enemies anywhere nearby.

const EXECUTE := 0.12
var falcon: Node3D
var falcon_t := 0.0
var strike_timer := 3.0
var striking := false


func setup(unit: FriendlyUnit) -> void:
	super.setup(unit)
	falcon = Node3D.new()
	u.add_child(falcon)
	var body := Mats.leather(Color(0.45, 0.33, 0.22))
	ModelBuilder.add_mesh(falcon, ModelBuilder.sphere(0.14, 8), body, Vector3.ZERO, Vector3.ZERO, Vector3(0.8, 0.8, 1.4))
	ModelBuilder.add_mesh(falcon, ModelBuilder.sphere(0.08, 8), Mats.cloth(Color(0.9, 0.88, 0.8)), Vector3(0, 0.05, 0.16))
	ModelBuilder.add_mesh(falcon, ModelBuilder.cone(0.03, 0.08, 4), Mats.get_mat("gold"), Vector3(0, 0.04, 0.25), Vector3(90, 0, 0))
	for s in [1, -1]:
		ModelBuilder.add_mesh(falcon, ModelBuilder.box(Vector3(0.5, 0.02, 0.18)), body, Vector3(0.26 * s, 0.02, 0), Vector3(0, 0, 12 * s))


func process(delta: float) -> void:
	if striking or falcon == null:
		return
	falcon_t += delta
	falcon.position = Vector3(cos(falcon_t * 1.3) * 2.6, 4.2 + sin(falcon_t * 2.0) * 0.3, sin(falcon_t * 1.3) * 2.6)
	falcon.rotation.y = -falcon_t * 1.3
	strike_timer -= delta
	if strike_timer > 0.0:
		return
	strike_timer = 3.0
	var cands := enemies_in(u.global_position, 22.0, true)
	if cands.is_empty():
		return
	var e: Enemy = cands[randi() % cands.size()]
	_falcon_strike(e)


func _falcon_strike(e: Enemy) -> void:
	striking = true
	var start := falcon.global_position
	var eid := e.get_instance_id()
	var tw := falcon.create_tween()
	tw.tween_method(func(t: float): _fly(start, eid, t), 0.0, 1.0, 0.35)
	tw.tween_callback(func(): _falcon_hit(eid))
	tw.tween_method(func(t: float): _fly_back(t), 0.0, 1.0, 0.4)
	tw.tween_callback(func(): striking = false)


func _fly(start: Vector3, eid: int, t: float) -> void:
	var e = instance_from_id(eid)
	if e != null and is_instance_valid(e) and is_instance_valid(falcon):
		falcon.global_position = start.lerp(e.aim_point(), t)


func _fly_back(t: float) -> void:
	if is_instance_valid(falcon):
		falcon.position = falcon.position.lerp(Vector3(0, 4.2, 0), t)


func _falcon_hit(eid: int) -> void:
	var e = instance_from_id(eid)
	if e != null and is_instance_valid(e) and e.alive:
		e.reveal_timer = 3.0
		hit(e, u.get_damage() * 0.5)
		FX.hit_sparks(e.aim_point(), Color(1.0, 0.95, 0.7))


func on_hit(e: Enemy, _dealt: float) -> void:
	if not is_instance_valid(e) or not e.alive:
		return
	e.add_mark()
	if not e.is_boss and e.hp < e.max_hp * EXECUTE:
		FX.float_text(e.global_position + Vector3.UP * 2.2, "EXECUTED", Color(1.0, 0.4, 0.3), 38)
		e.take_damage(e.hp * 10.0 + 50.0, Damage.Type.ARCANE, u)


func _cast(i: int, pos: Vector3) -> bool:
	if i == 0:
		var dmg := ability_damage(0.45)
		var leg := HeroGear.has_legendary(id, "storm_string")
		AbilityZone.create(pos, 6.5 if leg else 5.0, 7.0 if leg else 4.0, 0.25, Color(1.0, 0.9, 0.55), func(c: Vector3, r: float): _rain_tick(c, r, dmg),
			{"one_shot": false, "amount": 60, "lifetime": 0.5, "direction": Vector3.DOWN, "spread": 5.0,
				"vel_min": 18.0, "vel_max": 22.0, "gravity": Vector3.ZERO, "size_min": 0.05, "size_max": 0.08,
				"box": Vector3(4.5, 0.1, 4.5), "scale_start": 1.0, "scale_end": 1.0, "local": true,
				"colors": [Color(0.9, 0.85, 0.7, 1), Color(0.9, 0.85, 0.7, 0.6)], "emit_offset": Vector3(0, 9, 0)})
		u.say("Loose! Cover that ground!", 2)
		return true
	return _gale(pos)


func _rain_tick(center: Vector3, radius: float, dmg: float) -> void:
	for e in enemies_in(center, radius, true):
		hit(e, dmg)


func _gale(pos: Vector3) -> bool:
	var from := u.global_position
	var dir := pos - from
	dir.y = 0
	if dir.length() < 0.5:
		return false
	dir = dir.normalized()
	var end := from + dir * 30.0
	var em := GameManager.enemy_manager
	if em:
		for e in em.enemies.duplicate():
			if not is_instance_valid(e) or not e.alive or e.is_hidden():
				continue
			var rel: Vector3 = e.global_position - from
			rel.y = 0
			var along := rel.dot(dir)
			if along < 0.0 or along > 30.0:
				continue
			if (rel - dir * along).length() < 1.8:
				hit(e, ability_damage(5.0), Damage.Type.PIERCING)
				if e.alive and not e.is_boss and not e.flying:
					e.progress = max(0.0, e.progress - 3.0)
				FX.hit_sparks(e.aim_point(), Color(0.7, 0.95, 1.0))
	FX.beam(from + Vector3.UP * 2.2, end + Vector3.UP * 1.5, Color(0.7, 0.95, 1.0))
	Sfx.play("crossbow", 0.0, 0.1, 0.1)
	u.say("Piercing Gale!", 2)
	return true
