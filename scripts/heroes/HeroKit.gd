class_name HeroKit
extends RefCounted
## Base for a hero's unique behaviour. A kit is attached to the hero's
## FriendlyUnit and gets hooks for attacks, damage, abilities and its own
## per-frame logic. Each hero overrides what makes it different.

var u: FriendlyUnit
var id: String = ""
var cds: Array[float] = [0.0, 0.0]


func setup(unit: FriendlyUnit) -> void:
	u = unit
	id = unit.hero_id


## Called every frame while the hero is alive and not stunned.
func process(_delta: float) -> void:
	pass


## Return true to replace the class's normal attack.
func perform_attack(_e: Enemy) -> bool:
	return false


## Called for every hit the hero lands.
func on_hit(_e: Enemy, _dealt: float) -> void:
	pass


func damage_mult() -> float:
	return 1.0


func modify_damage_taken(amount: float, _source: Node) -> float:
	return amount


## Heroes allowed to stand on the road (Aldric).
func road_ok() -> bool:
	return bool(HeroDefs.get_hero(id).get("road_ok", false))


## Another soldier is about to be knocked down. Return true to save them.
func on_ally_would_fall(_ally: FriendlyUnit) -> bool:
	return false


func on_wave_started() -> void:
	pass


## The hero is about to move (walk, blink or charge).
func on_moved() -> void:
	pass


# ------------------------------------------------------------------ abilities
func ability_def(i: int) -> Dictionary:
	return HeroDefs.ability(id, i)


func ability_unlocked(i: int) -> bool:
	return u.hero_level >= int(ability_def(i).get("level", 1))


func cooldown_total(i: int) -> float:
	var cd := float(ability_def(i).get("cd", 20.0)) * u.ability_cd_mult()
	return cd


func ability_ready(i: int) -> bool:
	return ability_unlocked(i) and cds[i] <= 0.0 and not u.downed and u.stun_timer <= 0.0


func tick_cooldowns(delta: float) -> void:
	for i in cds.size():
		cds[i] = max(0.0, cds[i] - delta)


## Try to use ability i at a world position (ignored for untargeted abilities).
func use_ability(i: int, pos: Vector3) -> bool:
	if not ability_ready(i):
		return false
	if not _cast(i, pos):
		return false
	cds[i] = cooldown_total(i)
	Sfx.play("ability", -1.0)
	EventBus.hero_ability_used.emit(u, i)
	EventBus.unit_stats_changed.emit(u)
	return true


func _cast(_i: int, _pos: Vector3) -> bool:
	return false


## Damage an ability deals, scaled by hero level, gear and Legend.
func ability_damage(mult: float) -> float:
	return u.get_damage() * mult * u.ability_power()


func enemies_in(center: Vector3, radius: float, include_flying: bool = true) -> Array:
	var em := GameManager.enemy_manager
	if em == null:
		return []
	var out: Array = []
	for e in em.enemies_near(center, radius, include_flying):
		if not (e as Enemy).is_hidden():
			out.append(e)
	return out


func hit(e: Enemy, dmg: float, dtype: int = Damage.Type.NORMAL) -> void:
	if e == null or not is_instance_valid(e) or not e.alive:
		return
	if not is_instance_valid(u):
		e.take_damage(dmg, dtype, null)
		return
	var dealt := e.take_damage(dmg, dtype, u)
	u.on_damage_dealt(e, dealt)
