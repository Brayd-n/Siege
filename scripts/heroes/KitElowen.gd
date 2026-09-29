extends HeroKit
## Mother Elowen: Guardian Angel saves soldiers from falling (once per wave
## each), Consecrate holy ground, and Resurrection.

var saved_this_wave: Dictionary = {}


func on_wave_started() -> void:
	saved_this_wave.clear()


func aura_radius() -> float:
	var a: Dictionary = HeroDefs.active_aura(id)
	return float(a["radius"]) * (1.0 + BoonManager.get_add("aura_radius"))


func on_ally_would_fall(ally: FriendlyUnit) -> bool:
	if u.downed or saved_this_wave.has(ally.get_instance_id()):
		return false
	if u._hdist(ally.global_position) > aura_radius():
		return false
	saved_this_wave[ally.get_instance_id()] = true
	ally.hp = ally.get_max_hp() * 0.3
	FX.magic_ring(ally.global_position, Color(1.0, 0.95, 0.7), 1.6)
	FX.float_text(ally.global_position + Vector3.UP * 3.0, "SAVED", Color(1.0, 0.95, 0.6), 40)
	FX.beam(u.global_position + Vector3.UP * 2.5, ally.global_position + Vector3.UP * 1.5, Color(1.0, 0.95, 0.7))
	if randf() < 0.5:
		u.say("Not today, %s." % ally.display_name.get_slice(" ", ally.display_name.get_slice_count(" ") - 1), 1)
	return true


func _cast(i: int, pos: Vector3) -> bool:
	if i == 0:
		var dmg := ability_damage(0.5)
		var big := HeroGear.has_legendary(id, "dawnstone")
		AbilityZone.create(pos, 7.5 if big else 5.0, 12.0 if big else 8.0, 0.5, Color(1.0, 0.92, 0.55), func(c: Vector3, r: float): _consecrate(c, r, dmg),
			{"one_shot": false, "amount": 40, "lifetime": 1.2, "direction": Vector3.UP, "spread": 10.0,
				"vel_min": 0.6, "vel_max": 1.6, "gravity": Vector3(0, 0.5, 0), "size_min": 0.08, "size_max": 0.18,
				"box": Vector3(4.2, 0.05, 4.2), "scale_start": 1.0, "scale_end": 0.0, "local": true,
				"colors": [Color(1, 0.97, 0.75, 1), Color(1, 0.85, 0.4, 0)]})
		u.say("This ground is holy!", 2)
		return true
	return _resurrection()


func _consecrate(center: Vector3, radius: float, dmg: float) -> void:
	for e in enemies_in(center, radius, false):
		hit(e, dmg, Damage.Type.ARCANE)
	for a in GameManager.unit_manager.units_near(center, radius):
		var fu := a as FriendlyUnit
		if not fu.downed:
			fu.hp = min(fu.get_max_hp(), fu.hp + fu.get_max_hp() * 0.02)


func _resurrection() -> bool:
	var n := 0
	for a in GameManager.unit_manager.units:
		var fu := a as FriendlyUnit
		if fu.downed:
			fu.revive(1.0)
			n += 1
		fu.stun_timer = 0.0
		fu.full_heal()
		FX.magic_ring(fu.global_position, Color(1.0, 0.95, 0.7), 1.3)
	GameManager.add_lives(2)
	FX.magic_ring(u.global_position, Color(1.0, 0.95, 0.7), 14.0)
	EventBus.banner.emit("RESURRECTION", "%d soldier%s rise again. +2 castle lives." % [n, "" if n == 1 else "s"], Color(1.0, 0.92, 0.6))
	u.say("Rise, all of you! The Light is not finished with you!", 2)
	return true
