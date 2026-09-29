extends HeroKit
## Brunhild: sweeping pike, thorns, road barricades and Iron Wall.

const MAX_BARRICADES := 2
var barricades: Array = []


func perform_attack(e: Enemy) -> bool:
	var sp := u as Spearman
	if sp == null:
		return false
	var dir := e.global_position - u.global_position
	dir.y = 0
	dir = dir.normalized()
	sp._hit(e, 1.0)
	for o in enemies_in(u.global_position, u.get_range(), false):
		if o == e:
			continue
		var to: Vector3 = (o as Enemy).global_position - u.global_position
		to.y = 0
		if to.normalized().dot(dir) > 0.25:
			sp._hit(o, 0.8)
	FX.slash(e.aim_point(), dir)
	Sfx.play("sword", -8.0, 0.15, 0.05)
	return true


func modify_damage_taken(amount: float, source: Node) -> float:
	if is_instance_valid(source) and source is Enemy and (source as Enemy).alive:
		(source as Enemy).take_damage(amount * 0.3, Damage.Type.NORMAL, u)
	return amount


func _cast(i: int, pos: Vector3) -> bool:
	if i == 0:
		return _barricade(pos)
	return _iron_wall()


func _barricade(pos: Vector3) -> bool:
	var map: GameMap = GameManager.map
	var road := map.nearest_road_point(pos)
	if road.distance_to(Vector3(pos.x, 0, pos.z)) > 4.0:
		u.say("Barricades go on the road!", 1)
		return false
	for b in barricades.duplicate():
		if not is_instance_valid(b):
			barricades.erase(b)
	var cap := MAX_BARRICADES + (1 if HeroGear.has_legendary(id, "ironbark") else 0)
	if barricades.size() >= cap:
		var old: Node3D = barricades.pop_front()
		if is_instance_valid(old):
			old.call("destroy")
	var hp := 320.0 * (1.0 + 0.18 * (u.hero_level - 1)) * u.ability_power() * Profile.hero_gear_mult(id, "max_hp")
	if HeroGear.has_legendary(id, "ironbark"):
		hp *= 2.0
	var b := Barricade.create(road, hp, map.road_yaw_at(road))
	barricades.append(b)
	u.say("Barricade up! Let them break their teeth on it!", 2)
	return true


func _iron_wall() -> bool:
	for a in GameManager.unit_manager.units_near(u.global_position, 9.0):
		var fu := a as FriendlyUnit
		fu.invuln_timer = 4.0
		FX.magic_ring(fu.global_position, Color(0.85, 0.85, 0.95), 1.4)
	FX.magic_ring(u.global_position, Color(0.8, 0.8, 0.9), 9.0)
	EventBus.camera_shake.emit(0.2)
	u.say("IRON WALL! Nothing gets through!", 2)
	return true
