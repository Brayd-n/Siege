class_name FriendlyUnit
extends Node3D
## Base class for every friendly NPC soldier.
## Handles stats/upgrades, targeting modes, player commands, health, special
## ability cooldowns, speech, and NPC-to-NPC communication (warnings, calls
## for support, reactions). Subclasses implement _perform_attack / _use_special
## / _animate_attack.

enum Targeting { FIRST, LAST, STRONG, WEAK, CLOSE }
const TARGETING_NAMES: Array[String] = ["First", "Last", "Strong", "Weak", "Close"]
const BASE_COMM_RANGE := 16.0
const SUPPORT_CALL_DIST := 3.4
const MODEL_SCALE := 1.4   ## characters are drawn larger than life so they read well from the TD camera

@export var unit_type: String = "archer"

var def: Dictionary = {}
var display_name: String = ""
var personality: String = "Brave"
var kills: int = 0
var damage_dealt: float = 0.0
var upgrades: Array[int] = [0, 0, 0]
var spec: String = ""                   ## tier-3 specialization id ("" = none yet)
var invested: int = 0
var hp: float = 100.0
var targeting: int = Targeting.FIRST
var command: String = "Normal"        ## "Normal", "Hold Fire" or "Assist"
var assist_unit: FriendlyUnit = null
var target: Enemy = null
var attack_timer: float = 0.0
var retarget_timer: float = 0.0
var special_cd: float = 0.0
var special_active: float = 0.0
var downed: bool = false
var downed_timer: float = 0.0
var home_position: Vector3

# NPC coordination state
var priority_target: Enemy = null
var priority_timer: float = 0.0
var priority_reason: String = ""
var support_ally: FriendlyUnit = null
var support_timer: float = 0.0
var shield_wall_timer: float = 0.0
var scan_timer: float = 0.0
var support_call_cd: float = 0.0
var hurt_line_cd: float = 0.0
var last_hit_time: float = -100.0
var blessed: bool = false               ## a Cleric is in range (+12% damage)
var near_knight: bool = false           ## a Knight within 6m (Phalanx boon)
var rally_timer: float = 0.0            ## Martyr's Oath attack-speed buff
var stun_timer: float = 0.0             ## stunned / frozen soldiers can't act
var stun_fx: Node3D
var aura_stat: String = ""              ## hero aura currently affecting this soldier
var aura_mult: float = 1.0
var aura_label: String = ""

# hero state (hero_id is set by UnitManager before the unit enters the tree)
var hero_id: String = ""
var hero_level: int = 1
var hero_ring: MeshInstance3D
var kit: HeroKit = null                  ## hero-only behaviour
var move_goal: Vector3
var hero_moving: bool = false
var move_speed: float = 4.5
var invuln_timer: float = 0.0            ## Iron Wall
var valor_timer: float = 0.0             ## Horn of Valor relic
var allies_close: int = 0                ## Great War Banner relic
var crown_timer: float = 0.0             ## Crown of Command relic

# dialogue state
var last_line: String = ""
var speak_timer: float = 0.0
var speak_priority: int = 0
var recent_event: String = ""
var recent_event_name: String = ""
var recent_event_timer: float = 0.0

# presentation
var rig: Dictionary = {}
var anim_t: float = 0.0
var attack_anim: float = 0.0
var hit_flash: float = 0.0
var selected: bool = false
var hp_bar: MeshInstance3D
var select_ring: MeshInstance3D
var rank_node: Node3D

@onready var model_root: Node3D = $Model


func _ready() -> void:
	add_to_group("units")
	def = UnitDefs.get_def(unit_type)
	rig = ModelBuilder.build_unit(unit_type)
	model_root.add_child(rig["root"])
	if is_hero():
		def = HeroDefs.make_def(hero_id)
		HeroDefs.decorate(rig, hero_id)
		_build_hero_ring()
		EventBus.wave_completed.connect(_on_wave_completed_hero)
		EventBus.wave_started.connect(_on_wave_started_hero)
		kit = HeroDefs.make_kit(hero_id)
		if kit:
			kit.setup(self)
	hp = get_max_hp()
	home_position = global_position
	anim_t = randf() * 10.0
	if GameManager.map and GameManager.map.is_dark:
		# night maps: every soldier carries a lantern (torch throwers light up far more)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 2.2 if unit_type == "torch_thrower" else 1.1
		l.omni_range = 9.5 if unit_type == "torch_thrower" else 4.5
		l.position = Vector3(0, 2.4, 0)
		add_child(l)
	_build_hp_bar()
	_build_select_ring()
	_update_rank_visuals()


# ============================================================ stats
func path_mult(stat: String) -> float:
	var m := 1.0
	var paths: Array = def.get("paths", [])
	for i in paths.size():
		if paths[i]["stat"] == stat:
			m *= 1.0 + float(paths[i]["per"]) * upgrades[i]
	return m


func path_add(stat: String) -> float:
	var v := 0.0
	var paths: Array = def.get("paths", [])
	for i in paths.size():
		if paths[i]["stat"] == stat:
			v += float(paths[i]["per"]) * upgrades[i]
	return v


func get_level() -> int:
	return 1 + upgrades[0] + upgrades[1] + upgrades[2]


func is_hero() -> bool:
	return hero_id != ""


## Boon multiplier for this soldier; heroes also get "stat:hero" boons.
func boon_mult(stat: String) -> float:
	var m := BoonManager.get_mult(stat, unit_type)
	if is_hero():
		m *= BoonManager.get_mult_key(stat + ":hero") * Profile.hero_gear_mult(hero_id, stat)
	return m


## Hero ability cooldown multiplier (gear + level 8 milestone).
func ability_cd_mult() -> float:
	var m := Profile.hero_gear_mult(hero_id, "ability_cd")
	if hero_level >= 8:
		m *= 0.75
	return m


## Hero ability damage multiplier (gear + level 10 milestone).
func ability_power() -> float:
	var m := Profile.hero_gear_mult(hero_id, "ability_power")
	if hero_level >= 10:
		m *= 1.5
	return m


# ============================================================ specialization
func spec_def() -> Dictionary:
	return UnitDefs.get_spec(unit_type, spec) if spec != "" else {}


func spec_mult(stat: String) -> float:
	if spec == "":
		return 1.0
	return float(spec_def().get("mods", {}).get(stat, 1.0))


func spec_add(stat: String) -> float:
	if spec == "":
		return 0.0
	return float(spec_def().get("add", {}).get(stat, 0.0))


func has_spec(flag: String) -> bool:
	return spec != "" and flag in spec_def().get("flags", [])


func can_specialize() -> bool:
	return not is_hero() and spec == "" and upgrades[0] + upgrades[1] + upgrades[2] >= UnitDefs.SPEC_UNLOCK_TIERS \
		and not UnitDefs.SPECS.get(unit_type, []).is_empty()


func spec_cost(idx: int) -> int:
	var opts: Array = UnitDefs.SPECS.get(unit_type, [])
	if idx >= opts.size():
		return -1
	return EconomyManager.upgrade_cost(int(opts[idx]["cost"]))


func try_specialize(idx: int) -> bool:
	if not can_specialize():
		return false
	var cost := spec_cost(idx)
	if cost < 0 or not EconomyManager.spend(cost):
		return false
	var old_max := get_max_hp()
	spec = UnitDefs.SPECS[unit_type][idx]["id"]
	invested += cost
	hp += max(0.0, get_max_hp() - old_max)
	_apply_spec_visuals()
	FX.magic_ring(global_position, Color(1.0, 0.85, 0.35), 2.2)
	Sfx.play("upgrade", -2.0)
	say("%s! About time they noticed my talent." % spec_def()["name"], 2)
	EventBus.feed_message.emit(display_name, "becomes a %s." % spec_def()["name"], UiTheme.GOLD)
	EventBus.unit_upgraded.emit(self)
	EventBus.unit_stats_changed.emit(self)
	return true


## Display name of the class, including specialization.
func class_name_text() -> String:
	if spec != "":
		return spec_def()["name"]
	return def.get("name", unit_type)


## A tabard in the specialization colour plus a gold star, so specs read at a glance.
func _apply_spec_visuals() -> void:
	var torso: Node3D = rig.get("torso")
	if torso == null or spec == "":
		return
	var c: Color = spec_def().get("color", Color.WHITE)
	var tab := Node3D.new()
	tab.name = "SpecTabard"
	torso.add_child(tab)
	ModelBuilder.add_mesh(tab, ModelBuilder.box(Vector3(0.34, 0.5, 0.03)), Mats.cloth(c), Vector3(0, 0.3, 0.2))
	ModelBuilder.add_mesh(tab, ModelBuilder.sphere(0.05, 6), Mats.emissive(Color(1.0, 0.8, 0.3), 2.0), Vector3(0, 0.42, 0.23))
	ModelBuilder.add_mesh(tab, ModelBuilder.box(Vector3(0.36, 0.5, 0.03)), Mats.cloth(c.darkened(0.2)), Vector3(0, 0.3, -0.2))


func hero_mult() -> float:
	if not is_hero():
		return 1.0
	var m := 1.0 + HeroDefs.PER_LEVEL * (hero_level - 1)
	if hero_level >= 5:
		m += 0.15
	if hero_level >= 10:
		m += 0.25
	return m


func _aura(stat: String) -> float:
	return aura_mult if aura_stat == stat else 1.0


func last_stand_active() -> bool:
	return BoonManager.has_flag("last_stand") and GameManager.lives <= 10


func get_max_hp() -> float:
	return float(def.get("hp", 100.0)) * path_mult("max_hp") * boon_mult("max_hp") * hero_mult() * spec_mult("max_hp") * _aura("max_hp")


func get_damage() -> float:
	var d := float(def.get("damage", 10.0)) * path_mult("damage") * boon_mult("damage") * hero_mult() * spec_mult("damage")
	if blessed:
		d *= blessing_mult
	d *= _aura("damage")
	if BoonManager.has_flag("veterans"):
		d *= 1.0 + min(0.4, kills * 0.02)
	if last_stand_active():
		d *= 1.5
	if unit_type == "spearman" and near_knight and BoonManager.has_flag("phalanx"):
		d *= 1.35
	if kit:
		d *= kit.damage_mult()
	if allies_close >= 2 and BoonManager.has_relic("war_banner"):
		d *= 1.2
	if is_hero() and randf() < Profile.hero_gear_mult(hero_id, "crit") - 1.0:
		d *= 2.0
	return d * _damage_bonus()


## Situational damage bonuses (shield wall, shield brothers). Overridden by Knight.
func _damage_bonus() -> float:
	return 1.0


func get_range() -> float:
	return float(def.get("range", 10.0)) * path_mult("range") * boon_mult("range") * _aura("range") * spec_mult("range")


func get_attack_interval() -> float:
	var speed_mult := path_mult("speed") * boon_mult("attack_speed") * _speed_bonus() * _aura("attack_speed") * spec_mult("speed")
	if rally_timer > 0.0:
		speed_mult *= 1.35
	if valor_timer > 0.0:
		speed_mult *= 1.5
	if last_stand_active():
		speed_mult *= 1.2
	return float(def.get("interval", 1.0)) / max(0.1, speed_mult)


## Situational attack-speed bonuses (synergies, volley). Overridden by subclasses.
func _speed_bonus() -> float:
	return 1.0


func attacks_per_second() -> float:
	return 1.0 / get_attack_interval()


func comm_range() -> float:
	return BASE_COMM_RANGE * (1.5 if BoonManager.has_flag("scouts") else 1.0) * Profile.comm_mult()


func priority_duration(base: float) -> float:
	return base * (1.5 if BoonManager.has_flag("scouts") else 1.0)


func special_cooldown_total() -> float:
	return float(def["special"]["cd"]) * boon_mult("special_cd") * _aura("special_cd")


func special_ready() -> bool:
	return special_cd <= 0.0 and not downed


func sell_value() -> int:
	if is_hero():
		return 0
	return int(round(invested * (1.0 if BoonManager.has_flag("scavengers") else UnitDefs.SELL_RATE)))


## Current blessing strength from the best Cleric in range (1.0 = not blessed).
var blessing_mult: float = 1.12


## Human readable list of active synergies/buffs, shown in the unit panel.
func active_bonuses() -> Array[String]:
	var out: Array[String] = []
	if is_hero():
		out.append("Hero Lv %d (+%d%% dmg/hp)" % [hero_level, int(round((hero_mult() - 1.0) * 100))])
		out.append("Aura: %s" % HeroDefs.aura_text(hero_id))
	if aura_label != "":
		out.append(aura_label)
	if spec != "":
		out.append(spec_def()["name"])
	if blessed:
		out.append("Blessed (+%d%% dmg)" % int(round((blessing_mult - 1.0) * 100)))
	if rally_timer > 0.0:
		out.append("Martyr's Oath (+35% speed)")
	if last_stand_active():
		out.append("Last Stand!")
	if BoonManager.has_flag("veterans") and kills > 0:
		out.append("Veteran +%d%%" % int(min(40, kills * 2)))
	if shield_wall_timer > 0.0:
		out.append("Shield Wall")
	if priority_timer > 0.0 and is_instance_valid(priority_target):
		out.append("Focus: %s (%s)" % [priority_target.display_name, priority_reason])
	if support_timer > 0.0 and is_instance_valid(support_ally):
		out.append("Supporting %s" % support_ally.display_name)
	return out


# ============================================================ upgrades
func upgrade_cost(path_idx: int) -> int:
	var paths: Array = def.get("paths", [])
	if path_idx >= paths.size() or upgrades[path_idx] >= UnitDefs.MAX_TIER:
		return -1
	var base: int = paths[path_idx]["costs"][upgrades[path_idx]]
	return EconomyManager.upgrade_cost(base)


func try_upgrade(path_idx: int) -> bool:
	var cost := upgrade_cost(path_idx)
	if cost < 0 or not EconomyManager.spend(cost):
		return false
	var old_max := get_max_hp()
	upgrades[path_idx] += 1
	invested += cost
	hp += get_max_hp() - old_max
	_update_rank_visuals()
	FX.magic_ring(global_position, Color(1.0, 0.85, 0.35), 1.5)
	Sfx.play("upgrade", -4.0)
	say(DialogueDB.pick(DialogueDB.UPGRADED, last_line), 1)
	EventBus.unit_upgraded.emit(self)
	EventBus.unit_stats_changed.emit(self)
	return true


# ============================================================ player commands
func set_targeting(mode: int) -> void:
	targeting = mode
	target = null
	retarget_timer = 0.0
	if command == "Hold Fire":
		command = "Normal"
	say(DialogueDB.pick(DialogueDB.TARGETING.get(mode, DialogueDB.ORDER_ACK), last_line), 1)
	EventBus.unit_stats_changed.emit(self)


func toggle_hold_fire() -> void:
	command = "Normal" if command == "Hold Fire" else "Hold Fire"
	say(DialogueDB.pick(DialogueDB.ORDER_ACK) + (" Holding fire." if command == "Hold Fire" else " Weapons free!"), 1)
	EventBus.unit_stats_changed.emit(self)


func set_assist(ally: FriendlyUnit) -> void:
	if ally == null or ally == self:
		command = "Normal"
		assist_unit = null
	else:
		command = "Assist"
		assist_unit = ally
		say("Understood. Covering %s." % ally.display_name, 1)
	EventBus.unit_stats_changed.emit(self)


func talk() -> String:
	var line := DialogueDB.talk_line(self)
	say(line, 2)
	EventBus.player_talked.emit(self)
	return line


func use_special() -> bool:
	if is_hero() or not special_ready():
		return false
	if not _use_special():
		return false
	special_cd = special_cooldown_total()
	Sfx.play("ability", -2.0)
	EventBus.special_used.emit(self)
	EventBus.unit_stats_changed.emit(self)
	return true


## Implemented by subclasses. Return false if it couldn't be used right now.
func _use_special() -> bool:
	return false


# ============================================================ main loop
func _process(delta: float) -> void:
	anim_t += delta
	_tick_timers(delta)
	_update_bubble(delta)
	_update_bars()
	if downed:
		_process_downed(delta)
		return
	if kit:
		kit.tick_cooldowns(delta)
	if stun_timer > 0.0:
		stun_timer -= delta
		if stun_fx:
			stun_fx.rotation.y += delta * 4.0
		if stun_timer <= 0.0 and stun_fx:
			stun_fx.queue_free()
			stun_fx = null
		_animate(delta)
		return
	if stun_fx:
		stun_fx.queue_free()
		stun_fx = null
	if hero_moving:
		_hero_step(delta)
		_animate(delta)
		return
	if kit:
		kit.process(delta)
		_crown_autocast(delta)
	_process_movement(delta)
	_communicate(delta)
	retarget_timer -= delta
	if retarget_timer <= 0.0 or not _target_valid(target):
		retarget_timer = 0.15
		target = _acquire_target()
	attack_timer -= delta
	if target and command != "Hold Fire":
		_face(target.global_position, delta)
		if attack_timer <= 0.0:
			attack_timer = get_attack_interval()
			attack_anim = 1.0
			if kit == null or not kit.perform_attack(target):
				_perform_attack(target)
	_animate(delta)


func _tick_timers(delta: float) -> void:
	special_cd = max(0.0, special_cd - delta)
	special_active = max(0.0, special_active - delta)
	priority_timer = max(0.0, priority_timer - delta)
	support_timer = max(0.0, support_timer - delta)
	shield_wall_timer = max(0.0, shield_wall_timer - delta)
	support_call_cd = max(0.0, support_call_cd - delta)
	hurt_line_cd = max(0.0, hurt_line_cd - delta)
	recent_event_timer = max(0.0, recent_event_timer - delta)
	attack_anim = max(0.0, attack_anim - delta * 3.0)
	hit_flash = max(0.0, hit_flash - delta * 4.0)
	rally_timer = max(0.0, rally_timer - delta)
	invuln_timer = max(0.0, invuln_timer - delta)
	valor_timer = max(0.0, valor_timer - delta)
	if priority_timer <= 0.0:
		priority_target = null
	if support_timer <= 0.0:
		support_ally = null
	# slow regeneration when nothing is nearby
	if hp < get_max_hp() and not downed and target == null:
		hp = min(get_max_hp(), hp + get_max_hp() * 0.02 * delta)


## Knights override this to walk to allies in trouble.
func _process_movement(_delta: float) -> void:
	pass


func _target_valid(e) -> bool:
	if e == null or not is_instance_valid(e) or not e.alive or e.is_hidden():
		return false
	if not can_target(e):
		return false
	return _hdist(e.global_position) <= get_range()


func can_target(_e: Enemy) -> bool:
	return true


func _hdist(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


## Target selection: NPC-issued priorities first, then player orders, then targeting mode.
func _acquire_target() -> Enemy:
	var em := GameManager.enemy_manager
	if em == null:
		return null
	var r := get_range()
	var cands: Array[Enemy] = []
	for e in em.enemies:
		if is_instance_valid(e) and e.alive and not e.is_hidden() and can_target(e) and _hdist(e.global_position) <= r:
			cands.append(e)
	if cands.is_empty():
		return null
	# 1) priority target from an ally's warning (e.g. troll spotted)
	if priority_timer > 0.0 and is_instance_valid(priority_target) and cands.has(priority_target):
		return priority_target
	# 2) supporting an ally who asked for help: hit enemies closest to them
	if support_timer > 0.0 and is_instance_valid(support_ally):
		return _closest_to(cands, support_ally.global_position)
	# 3) player "Assist" command
	if command == "Assist" and is_instance_valid(assist_unit):
		if is_instance_valid(assist_unit.target) and cands.has(assist_unit.target):
			return assist_unit.target
		return _closest_to(cands, assist_unit.global_position)
	# 4) targeting mode
	var best: Enemy = cands[0]
	for e in cands:
		match targeting:
			Targeting.FIRST:
				if e.remaining() < best.remaining():
					best = e
			Targeting.LAST:
				if e.remaining() > best.remaining():
					best = e
			Targeting.STRONG:
				if e.hp > best.hp:
					best = e
			Targeting.WEAK:
				if e.hp < best.hp:
					best = e
			Targeting.CLOSE:
				if _hdist(e.global_position) < _hdist(best.global_position):
					best = e
	return best


func _closest_to(cands: Array[Enemy], p: Vector3) -> Enemy:
	var best: Enemy = cands[0]
	var bd := INF
	for e in cands:
		var d := e.global_position.distance_squared_to(p)
		if d < bd:
			bd = d
			best = e
	return best


func _face(p: Vector3, delta: float) -> void:
	var dir := p - global_position
	var yaw := atan2(dir.x, dir.z)
	model_root.rotation.y = lerp_angle(model_root.rotation.y, yaw, clamp(delta * 10.0, 0.0, 1.0))


## Subclasses spawn projectiles / deal melee damage.
func _perform_attack(_e: Enemy) -> void:
	pass


## Called by projectiles & melee to register damage and kills.
func on_damage_dealt(e: Enemy, amount: float) -> void:
	damage_dealt += amount
	if kit and is_instance_valid(e):
		kit.on_hit(e, amount)
	if e and not e.alive and not e.has_meta("kill_credited"):
		e.set_meta("kill_credited", true)
		kills += 1
		EventBus.unit_stats_changed.emit(self)


# ============================================================ health
## Stunned or frozen: no attacks, no moving.
func stun(seconds: float, kind: String = "stunned") -> void:
	if downed:
		return
	stun_timer = max(stun_timer, seconds * (0.5 if is_hero() else 1.0))
	target = null
	if stun_fx == null:
		stun_fx = Node3D.new()
		stun_fx.position = Vector3(0, 2.45 * MODEL_SCALE, 0)
		add_child(stun_fx)
		var col := Color(0.55, 0.85, 1.0) if kind == "frozen" else Color(1.0, 0.9, 0.3)
		for i in 3:
			var a := TAU * i / 3.0
			ModelBuilder.add_mesh(stun_fx, ModelBuilder.sphere(0.08, 6), Mats.emissive(col, 4.0), Vector3(cos(a) * 0.35, 0, sin(a) * 0.35))
		if kind == "frozen":
			ModelBuilder.add_mesh(stun_fx, ModelBuilder.box(Vector3(0.9, 1.9, 0.9)), Mats.flat(Color(0.6, 0.85, 1.0, 0.35), 0.1), Vector3(0, -1.5, 0))
	FX.float_text(global_position + Vector3.UP * 3.0, kind.to_upper(), Color(0.7, 0.9, 1.0) if kind == "frozen" else Color(1.0, 0.9, 0.4), 36)
	EventBus.unit_stats_changed.emit(self)


## Extra damage against the undead (Clerics, Paladins, Inquisitors).
func holy_mult() -> float:
	if has_spec("holy3"):
		return 3.0
	return 2.0 if unit_type == "cleric" or has_spec("holy") else 1.0


func take_damage(amount: float, _source: Node = null) -> void:
	if downed:
		return
	if invuln_timer > 0.0:
		if randf() < 0.2:
			FX.float_text(global_position + Vector3.UP * 3.0, "IMMUNE", Color(0.85, 0.85, 0.95), 32)
		return
	var dmg := amount * boon_mult("damage_taken") * _aura("damage_taken") * spec_mult("damage_taken")
	if kit:
		dmg = kit.modify_damage_taken(dmg, _source)
	if shield_wall_timer > 0.0:
		dmg *= 0.5
	hp -= dmg
	hit_flash = 1.0
	last_hit_time = Time.get_ticks_msec() / 1000.0
	FX.blood(global_position + Vector3.UP * 1.7, Color(0.5, 0.05, 0.04))
	if hp <= 0.0:
		_go_down()
		return
	if hp < get_max_hp() * 0.35 and hurt_line_cd <= 0.0:
		hurt_line_cd = 12.0
		say(DialogueDB.pick(DialogueDB.by_personality(DialogueDB.HURT, personality), last_line), 1)
	EventBus.unit_stats_changed.emit(self)


func _go_down() -> void:
	# Mother Elowen's Guardian Angel can save soldiers in her aura
	var h = GameManager.hero_unit
	if is_instance_valid(h) and h != self and h.kit and h.kit.on_ally_would_fall(self):
		EventBus.unit_stats_changed.emit(self)
		return
	downed = true
	hero_moving = false
	downed_timer = Profile.downed_time()
	hp = 0.0
	target = null
	support_timer = 0.0
	say(DialogueDB.pick(DialogueDB.DOWNED), 2)
	EventBus.unit_downed.emit(self)
	EventBus.unit_stats_changed.emit(self)
	var tw := create_tween()
	tw.tween_property(model_root, "rotation:x", -PI * 0.47, 0.4)


func _process_downed(delta: float) -> void:
	downed_timer -= delta
	if downed_timer <= 0.0:
		revive(0.5)


func revive(frac: float) -> void:
	if not downed:
		hp = get_max_hp()
		return
	downed = false
	hp = get_max_hp() * frac
	var tw := create_tween()
	tw.tween_property(model_root, "rotation:x", 0.0, 0.4)
	say("Back on my feet!", 1)
	EventBus.unit_stats_changed.emit(self)


func full_heal() -> void:
	if downed:
		revive(1.0)
	hp = get_max_hp()


# ============================================================ NPC communication
## Periodic scan of the battlefield. Raises warnings and help requests that
## other NPCs react to via the EventBus (handled in DialogueManager).
func _communicate(delta: float) -> void:
	scan_timer -= delta
	if scan_timer > 0.0:
		return
	scan_timer = 0.35
	var em := GameManager.enemy_manager
	if em == null:
		return
	var watch := get_range() + 4.0
	# blessing aura from nearby clerics
	var um0 := GameManager.unit_manager
	blessed = false
	blessing_mult = 1.0
	if um0 and unit_type != "cleric":
		for c in um0.units:
			if c.unit_type == "cleric" and not c.downed and c != self and _hdist(c.global_position) <= c.get_range():
				blessed = true
				var bm := 1.12
				if c.has_spec("high_bless"):
					bm = 1.2
				if BoonManager.has_flag("zealots"):
					bm = max(bm, 1.3)
				blessing_mult = max(blessing_mult, bm)
	near_knight = unit_type == "spearman" and um0 != null and um0.nearest_unit(global_position, 6.0, "knight", true, self) != null
	if um0 and BoonManager.has_relic("war_banner"):
		allies_close = um0.units_near(global_position, 6.0).size() - 1
	_update_hero_aura()
	for e in em.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var d := _hdist(e.global_position)
		# Dragon: first soldier to see it raises the alarm
		if e.is_boss and not e.has_meta("spotted") and d < 30.0:
			e.set_meta("spotted", true)
			say(DialogueDB.pick(DialogueDB.DRAGON_SHOUT if e.flying else DialogueDB.BOSS_SHOUT), 3)
			EventBus.dragon_spotted.emit(e, self)
			continue
		# Cavalry: wolf riders get called out so spearmen can brace for them
		if e.enemy_type == "wolf_rider" and not e.has_meta("spotted") and d < watch and _cavalry_warning_ready():
			e.set_meta("spotted", true)
			var um1 := GameManager.unit_manager
			if um1 and (unit_type == "spearman" or um1.nearest_unit(global_position, comm_range(), "spearman", true, self) != null):
				say(DialogueDB.pick(DialogueDB.CAVALRY_SHOUT), 2)
				EventBus.cavalry_spotted.emit(e, self)
			continue
		# New threats: sappers, necromancers, shield walls, bat swarms
		if not e.has_meta("spotted") and d < watch and not e.is_hidden():
			var kind := ""
			match e.enemy_type:
				"sapper":
					kind = "sapper"
				"necromancer":
					kind = "necromancer"
				"shieldbearer":
					kind = "shields"
				"bat":
					kind = "bats"
			if kind != "" and _threat_ready(kind):
				e.set_meta("spotted", true)
				say(DialogueDB.pick(DialogueDB.THREAT_SHOUT[kind]), 2)
				EventBus.threat_spotted.emit(e, self, kind)
				continue
		# Heavy enemies (trolls always, orcs occasionally)
		if e.is_heavy and not e.is_boss and not e.has_meta("spotted") and d < watch:
			if e.enemy_type == "troll" or (e.enemy_type == "orc" and _orc_warning_ready()):
				e.set_meta("spotted", true)
				say(DialogueDB.pick(DialogueDB.HEAVY_SPOT.get(e.enemy_type, ["Heavy enemy!"])), 2)
				EventBus.heavy_enemy_spotted.emit(e, self)
	# Enemies very close to a soldier who is not a knight -> call for a knight
	if unit_type != "knight" and support_call_cd <= 0.0:
		# call only when really pressed: two+ enemies on top of us, or we were just hit
		var closest: Enemy = null
		var cd := SUPPORT_CALL_DIST + 1.0
		var close_count := 0
		for e2 in em.enemies:
			if is_instance_valid(e2) and e2.alive and not e2.flying:
				var d2 := _hdist(e2.global_position)
				if d2 < SUPPORT_CALL_DIST:
					close_count += 1
				if d2 < cd:
					cd = d2
					closest = e2
		var recently_hit := Time.get_ticks_msec() / 1000.0 - last_hit_time < 3.0
		if closest and (close_count >= 2 or recently_hit):
			var um := GameManager.unit_manager
			var knight: FriendlyUnit = um.nearest_unit(global_position, comm_range(), "knight", true) if um else null
			if knight:
				support_call_cd = 20.0
				say(DialogueDB.pick(DialogueDB.by_personality(DialogueDB.SUPPORT_CALL, personality)), 2)
				EventBus.ally_needs_support.emit(self, closest)


static var _last_orc_warning: float = -100.0
static var _last_threat: Dictionary = {}


func _threat_ready(kind: String) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var cd := 6.0 if kind == "sapper" else 18.0
	if now - float(_last_threat.get(kind, -100.0)) > cd:
		_last_threat[kind] = now
		return true
	return false
static var _last_cavalry_warning: float = -100.0


func _cavalry_warning_ready() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_cavalry_warning > 20.0:
		_last_cavalry_warning = now
		return true
	return false


func _orc_warning_ready() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_orc_warning > 25.0:
		_last_orc_warning = now
		return true
	return false


## Another NPC asked this unit to focus a specific enemy.
func receive_priority(e: Enemy, seconds: float, reason: String) -> void:
	priority_target = e
	priority_timer = priority_duration(seconds)
	priority_reason = reason
	target = null
	retarget_timer = 0.0
	EventBus.unit_stats_changed.emit(self)


## Another NPC asked this unit (a knight) for help.
func receive_support_request(ally: FriendlyUnit, seconds: float) -> void:
	support_ally = ally
	support_timer = priority_duration(seconds)
	target = null
	retarget_timer = 0.0
	recent_event = "supported"
	recent_event_name = ally.display_name
	recent_event_timer = 30.0
	EventBus.unit_stats_changed.emit(self)


func note_event(ev: String, who: String) -> void:
	recent_event = ev
	recent_event_name = who
	recent_event_timer = 30.0


# ============================================================ speech
## Speak a line: the HUD draws the speech bubble and the battlefield feed
## entry (EventBus.npc_said). Higher priority lines interrupt lower ones.
func say(text: String, priority: int = 0) -> void:
	if text == "":
		return
	if speak_timer > 0.0 and priority < speak_priority:
		return
	last_line = text
	speak_priority = priority
	speak_timer = 3.2 + text.length() * 0.03
	EventBus.npc_said.emit(self, text)


func _update_bubble(delta: float) -> void:
	if speak_timer <= 0.0:
		return
	speak_timer -= delta
	if speak_timer <= 0.0:
		speak_priority = 0


# ============================================================ heroes
## Which hero aura (if any) reaches this soldier.
func _update_hero_aura() -> void:
	aura_stat = ""
	aura_mult = 1.0
	aura_label = ""
	var h = GameManager.hero_unit
	if is_hero() or not is_instance_valid(h) or h.downed:
		return
	var a := HeroDefs.active_aura(h.hero_id)
	if a.is_empty():
		return
	var radius := float(a["radius"]) * (1.0 + BoonManager.get_add("aura_radius"))
	if _hdist(h.global_position) > radius:
		return
	var power := 1.0 + BoonManager.get_add("aura_power") + (Profile.hero_gear_mult(h.hero_id, "aura_power") - 1.0)
	aura_stat = a["stat"]
	aura_mult = 1.0 + (float(a["mult"]) - 1.0) * power
	aura_label = "%s from %s" % [a["label"], HeroDefs.get_hero(h.hero_id)["short"]]


## Crown of Command: the hero's first ability fires on its own.
func _crown_autocast(delta: float) -> void:
	if not BoonManager.has_relic("crown_command"):
		return
	crown_timer -= delta
	if crown_timer > 0.0 or not kit.ability_ready(0) or GameManager.state != GameManager.State.WAVE:
		return
	var best: Enemy = null
	for e in GameManager.enemy_manager.enemies:
		if is_instance_valid(e) and e.alive and not e.is_hidden() and _hdist(e.global_position) < 18.0:
			if best == null or e.hp > best.hp:
				best = e
	if best == null:
		return
	var pos := best.global_position
	var ab := kit.ability_def(0)
	if ab.get("target", "") == "road":
		pos = GameManager.map.nearest_road_point(pos)
	if kit.use_ability(0, pos):
		crown_timer = 30.0


# ------------------------------------------------------------------ hero movement
## Can the hero stand here? (Aldric may stand on the road.)
func hero_can_stand(pos: Vector3) -> bool:
	var map: GameMap = GameManager.map
	var allow_road := kit != null and kit.road_ok()
	var err := map.placement_error(pos, allow_road)
	if err == "Something is in the way":
		# our own blocker doesn't count
		if Vector2(pos.x - home_position.x, pos.z - home_position.z).length() < 1.5:
			err = ""
	if err != "":
		return false
	var other: FriendlyUnit = GameManager.unit_manager.unit_at(pos, 1.3)
	return other == null or other == self


## Order the hero to walk (or blink, for Voss) to a spot.
func hero_move_order(pos: Vector3) -> bool:
	if not is_hero() or downed or stun_timer > 0.0:
		return false
	var p := Vector3(pos.x, 0, pos.z)
	if not hero_can_stand(p):
		say("I can't stand there.", 1)
		return false
	if bool(HeroDefs.get_hero(hero_id).get("blink", false)):
		FX.magic_ring(global_position, Color(0.55, 0.7, 1.0), 1.5)
		hero_relocate(p, 0.0)
		FX.magic_ring(p, Color(0.55, 0.7, 1.0), 1.5)
		Sfx.play("whoosh", -6.0, 0.2, 0.5)
		return true
	_release_blocker()
	move_goal = p
	hero_moving = true
	target = null
	say(DialogueDB.pick(DialogueDB.ORDER_ACK), 0)
	return true


func _hero_step(delta: float) -> void:
	var to := move_goal - global_position
	to.y = 0
	var step := move_speed * delta
	if to.length() <= step:
		global_position = move_goal
		hero_moving = false
		home_position = global_position
		GameManager.map.add_blocker(global_position, 0.9)
		EventBus.unit_stats_changed.emit(self)
		return
	global_position += to.normalized() * step
	_face(move_goal, delta)
	anim_t += delta * 2.0


## Instantly (or over `time` seconds) move the hero, keeping blockers right.
func hero_relocate(pos: Vector3, time: float) -> void:
	_release_blocker()
	hero_moving = false
	if time <= 0.0:
		global_position = pos
	else:
		create_tween().tween_property(self, "global_position", pos, time)
	home_position = pos
	GameManager.map.add_blocker(pos, 0.9)
	EventBus.unit_stats_changed.emit(self)


func _release_blocker() -> void:
	if kit:
		kit.on_moved()
	var map: GameMap = GameManager.map
	for i in range(map.blockers.size() - 1, -1, -1):
		var b: Dictionary = map.blockers[i]
		if (b["pos"] as Vector2).distance_to(Vector2(home_position.x, home_position.z)) < 0.05:
			map.blockers.remove_at(i)
			break


func _on_wave_started_hero(_n: int) -> void:
	if kit:
		kit.on_wave_started()


func _on_wave_completed_hero(_n: int) -> void:
	gain_levels(1)


func gain_levels(n: int) -> void:
	var before := hero_level
	var ratio: float = hp / maxf(1.0, get_max_hp())
	hero_level = mini(HeroDefs.MAX_LEVEL, hero_level + n)
	if hero_level == before:
		return
	if not downed:
		hp = get_max_hp() * ratio
	FX.magic_ring(global_position, Color(1.0, 0.8, 0.3), 2.5)
	Sfx.play("upgrade", -3.0)
	EventBus.feed_message.emit(display_name, "reaches Hero Level %d!" % hero_level, UiTheme.GOLD)
	EventBus.unit_stats_changed.emit(self)


func _build_hero_ring() -> void:
	hero_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 0.97
	t.rings = 40
	t.ring_segments = 6
	hero_ring.mesh = t
	hero_ring.material_override = Mats.emissive(Color(1.0, 0.72, 0.25), 1.6)
	hero_ring.scale = Vector3(MODEL_SCALE, 0.05, MODEL_SCALE)
	hero_ring.position = Vector3(0, 0.04, 0)
	hero_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hero_ring)


# ============================================================ visuals
func _build_hp_bar() -> void:
	hp_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.11)
	hp_bar.mesh = q
	var m := ShaderMaterial.new()
	m.shader = Mats.shader("res://assets/shaders/healthbar.gdshader")
	hp_bar.material_override = m
	hp_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_bar.position = Vector3(0, 2.3 * MODEL_SCALE, 0)
	hp_bar.visible = false
	add_child(hp_bar)


func _update_bars() -> void:
	var mh := get_max_hp()
	var f: float = clamp(hp / mh, 0.0, 1.0)
	hp_bar.visible = f < 0.999 or selected
	hp_bar.set_instance_shader_parameter("fill", f)
	hp_bar.set_instance_shader_parameter("bar_color", Color(0.35, 0.6, 1.0) if not downed else Color(0.5, 0.5, 0.5))


func _build_select_ring() -> void:
	select_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.62
	t.outer_radius = 0.72
	t.rings = 32
	t.ring_segments = 6
	select_ring.mesh = t
	select_ring.material_override = Mats.emissive(Color(1.0, 0.8, 0.3), 2.5)
	select_ring.scale = Vector3(MODEL_SCALE, 0.1, MODEL_SCALE)
	select_ring.position = Vector3(0, 0.05, 0)
	select_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	select_ring.visible = false
	add_child(select_ring)


func set_selected(on: bool) -> void:
	selected = on
	select_ring.visible = on


## Gold rank pips on the chest + slight size increase with level.
func _update_rank_visuals() -> void:
	if rank_node and is_instance_valid(rank_node):
		rank_node.queue_free()
	var torso: Node3D = rig.get("torso")
	if torso == null:
		return
	rank_node = Node3D.new()
	torso.add_child(rank_node)
	var lv := get_level()
	for i in lv - 1:
		ModelBuilder.add_mesh(rank_node, ModelBuilder.box(Vector3(0.1, 0.035, 0.03)), Mats.emissive(Color(1.0, 0.78, 0.3), 1.5),
			Vector3(0.12, 0.5 - i * 0.06, 0.2), Vector3(0, 0, 20))
	if lv >= 4:
		ModelBuilder.add_mesh(rank_node, ModelBuilder.torus(0.13, 0.17), Mats.get_mat("gold"), Vector3(0, 1.08, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	model_root.scale = Vector3.ONE * MODEL_SCALE * (1.0 + 0.04 * (lv - 1)) * (1.15 if is_hero() else 1.0)


## Idle breathing + class specific attack animation.
func _animate(_delta: float) -> void:
	if hero_ring:
		hero_ring.rotation.y = anim_t * 0.6
		hero_ring.transparency = 0.3 + 0.25 * sin(anim_t * 2.0)
	var body: Node3D = rig["body"]
	body.position.y = sin(anim_t * 2.0) * 0.01
	var torso: Node3D = rig["torso"]
	torso.rotation.x = sin(anim_t * 1.6) * 0.02
	var head: Node3D = rig["head"]
	head.rotation.y = sin(anim_t * 0.5) * 0.25 if target == null else 0.0
	_animate_attack(attack_anim)


func _animate_attack(_a: float) -> void:
	pass
