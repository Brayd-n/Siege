extends Node
## Headless checks for hero kits (unique mechanics + abilities), gear and mastery:
##   godot --headless --fixed-fps 30 --path . res://tests/KitTest.tscn

const MAIN := preload("res://scenes/main/Main.tscn")
var main: Node
var frame := 0
var results: Array = []
var em
var um
var h: FriendlyUnit
var foes: Array = []
var snap := {}
var step := 0


func _ready() -> void:
	Profile.no_save = true
	Profile.data = Profile._defaults()
	Profile.unlock_everything()
	GameManager.level = LevelDefs.get_level(1)
	GameManager.level_index = 1
	GameManager.difficulty = "normal"
	GameManager.mode = "campaign"
	GameManager.hero_id = "lionheart"
	GameManager.reset_run()
	main = MAIN.instantiate()
	add_child(main)


func check(name: String, ok: bool) -> void:
	results.append([name, ok])
	print(("PASS  " if ok else "FAIL  ") + name)


func _spot(off: float, side: float) -> Vector3:
	var map: GameMap = GameManager.map
	var pos := map.sample_path(off)
	var dir := map.path_direction(off)
	var c := pos + Vector3(-dir.z, 0, dir.x) * side
	if map.placement_error(c) != "":
		c = pos + Vector3(-dir.z, 0, dir.x) * side * 1.5
	return c


func _new_hero(id: String, pos: Vector3) -> FriendlyUnit:
	if is_instance_valid(GameManager.hero_unit):
		var old: FriendlyUnit = GameManager.hero_unit
		um.units.erase(old)
		old._release_blocker()
		old.queue_free()
	GameManager.hero_unit = null
	GameManager.hero_id = id
	var u: FriendlyUnit = um.spawn_hero(pos)
	u.hero_level = 3
	return u


func _foe(t: String, off: float) -> Enemy:
	var e: Enemy = em.spawn_at(t, 0, off)
	foes.append(e)
	return e


func _clear() -> void:
	em.clear_all()
	foes.clear()


func _process(_d: float) -> void:
	frame += 1
	if frame == 5:
		em = GameManager.enemy_manager
		um = GameManager.unit_manager
		GameManager.wave_manager.start_next_wave()
		_clear()
		GameManager.wave_manager.spawn_queue.clear()
		GameManager.wave_manager.active = false
		GameManager.set_state(GameManager.State.WAVE)
		_gear_checks()
		# ---------------- Lionheart: stands on the road and holds enemies
		var road: Vector3 = GameManager.map.sample_path(40.0)
		h = _new_hero("lionheart", road)
		check("Aldric can stand on the road", h != null and h.global_position.distance_to(road) < 0.5)
		for i in 2:
			var g := _foe("goblin", 34.0 + i * 0.5)
			g.max_hp = 99999.0
			g.hp = 99999.0
	if frame == 90:
		var held := 0
		for e in foes:
			if is_instance_valid(e) and e.blocked_by == h:
				held += 1
		check("Aldric holds enemies in place (%d)" % held, held >= 1)
		var before: Vector3 = h.global_position
		check("Heroic Charge works", h.kit.use_ability(0, before + Vector3(8, 0, 0).rotated(Vector3.UP, 0.0)) or h.kit.use_ability(0, _spot(55.0, 3.0)))
	if frame == 110:
		check("Lion's Roar stuns", h.kit.use_ability(1, Vector3.ZERO))
		_clear()
		# ---------------- Lyra: marks, execute, rain, gale
		h = _new_hero("lyra", _spot(30.0, 3.5))
		var t := _foe("orc", 30.0)
		t.speed = 0.0
		h.kit.on_hit(t, 1.0)
		h.kit.on_hit(t, 1.0)
		check("Lyra marks enemies", t.mark_stacks == 2)
		var hp0 := t.hp
		t.take_damage(10.0, Damage.Type.ARCANE, null)
		check("marked enemies take more damage", hp0 - t.hp > 11.0)
		t.hp = t.max_hp * 0.05
		h.kit.on_hit(t, 1.0)
		check("Lyra executes wounded enemies", not t.alive)
		var r := _foe("orc", 31.0)
		r.speed = 0.0
		snap["rain"] = r
		snap["rain_hp"] = r.hp
		check("Rain of Arrows cast", h.kit.use_ability(0, r.global_position))
	if frame == 170:
		var r2: Enemy = snap["rain"]
		check("Rain of Arrows damages", not is_instance_valid(r2) or not r2.alive or r2.hp < float(snap["rain_hp"]))
		var g2 := _foe("orc", 33.0)
		g2.speed = 0.0
		snap["gale"] = g2
		snap["gale_hp"] = g2.hp
		check("Piercing Gale cast", h.kit.use_ability(1, g2.global_position))
		print("  gale: hero ", h.global_position, " foe ", g2.global_position, " hp ", g2.hp, "/", snap["gale_hp"], " hidden ", g2.is_hidden())
		check("Piercing Gale damages", not g2.alive or g2.hp < float(snap["gale_hp"]))
		_clear()
		# ---------------- Voss: beam ramps, blink, meteor, time warp
		h = _new_hero("voss", _spot(30.0, 3.5))
		var v := _foe("troll", 30.0)
		v.speed = 0.0
		snap["beam"] = v
		snap["beam_hp"] = v.hp
	if frame == 260:
		var v2: Enemy = snap["beam"]
		check("Voss's beam burns a target down", v2.hp < float(snap["beam_hp"]) * 0.97)
		check("Voss's beam ramps up", h.kit.ramp > 0.5)
		var dest := _spot(60.0, 4.0)
		check("Voss blinks when moved", h.hero_move_order(dest) and h.global_position.distance_to(Vector3(dest.x, 0, dest.z)) < 0.2)
		check("Meteor cast", h.kit.use_ability(0, v2.global_position))
		snap["met_hp"] = v2.hp
	if frame == 300:
		var v3: Enemy = snap["beam"]
		check("Meteor lands and hits", not v3.alive or v3.hp < float(snap["met_hp"]))
		check("Time Warp cast", h.kit.use_ability(1, Vector3.ZERO))
		check("Time Warp slows enemies", not v3.alive or (v3.slow_time > 0.0 and v3.slow_mult <= 0.5))
		_clear()
		# ---------------- Brunhild: barricade + iron wall + thorns
		h = _new_hero("brunhild", _spot(46.0, 3.5))
		var road2: Vector3 = GameManager.map.sample_path(40.0)
		check("Barricade raised", h.kit.use_ability(0, road2))
		check("barricade registered on the map", GameManager.map.barricades.size() == 1)
		var bg := _foe("orc", 34.0)
		bg.max_hp = 99999.0
		bg.hp = 99999.0
		snap["bar_enemy"] = bg
	if frame == 400:
		var bg2: Enemy = snap["bar_enemy"]
		check("barricade stops enemies", is_instance_valid(bg2.blocked_barricade))
		var b: Node3D = GameManager.map.barricades[0] if not GameManager.map.barricades.is_empty() else null
		check("enemies hack at the barricade", b != null and b.hp < b.max_hp)
		check("Iron Wall cast", h.kit.use_ability(1, Vector3.ZERO))
		var hp1 := h.hp
		h.take_damage(50.0, null)
		check("Iron Wall makes soldiers immune", h.hp == hp1)
		_clear()
		for bb in GameManager.map.barricades.duplicate():
			bb.destroy()
		# ---------------- Elowen: guardian angel, consecrate, resurrection
		h = _new_hero("elowen", _spot(50.0, 3.5))
		var ally: FriendlyUnit = um.spawn_unit("archer", _spot(52.0, -3.5), 0)
		ally.take_damage(99999.0, null)
		check("Guardian Angel saves a soldier", not ally.downed and ally.hp > 0.0)
		ally.take_damage(99999.0, null)
		check("...but only once per wave", ally.downed)
		check("Resurrection cast", h.kit.use_ability(1, Vector3.ZERO))
		check("Resurrection revives", not ally.downed)
		ally.hp = ally.get_max_hp() * 0.3
		snap["ally"] = ally
		snap["ally_hp"] = ally.hp
		check("Consecrate cast", h.kit.use_ability(0, ally.global_position))
	if frame == 460:
		var al: FriendlyUnit = snap["ally"]
		check("Consecrate heals soldiers inside", al.hp > float(snap["ally_hp"]))
		check("abilities locked below level 3", _lock_check())
		_finish()


func _lock_check() -> bool:
	h.hero_level = 1
	h.kit.cds[1] = 0.0
	return not h.kit.ability_ready(1)


func _gear_checks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var counts := {}
	for i in 300:
		var it := HeroGear.roll_item("lyra", 1.5, "common", rng)
		counts[it["rarity"]] = int(counts.get(it["rarity"], 0)) + 1
	check("gear drops cover several rarities %s" % str(counts), counts.size() >= 4)
	var leg := HeroGear.roll_item("voss", 0.0, "legendary", rng)
	check("legendary pieces carry the hero's legendary effect", leg["rarity"] == "legendary" and leg.get("effect", "") == "eye_storm")
	var before := HeroGear.stat_mult("lionheart", "damage")
	var w := HeroGear.roll_item("lionheart", 2.0, "rare", rng)
	w["slot"] = "weapon"
	w["stats"] = {"damage": 0.12}
	HeroGear.add_item(w)
	check("new gear auto-equips into an empty slot", HeroGear.equipped_uid("lionheart", "weapon") == int(w["uid"]))
	check("equipped gear boosts only that hero", HeroGear.stat_mult("lionheart", "damage") > before + 0.1 and HeroGear.stat_mult("lyra", "damage") == 1.0)
	var cr := Profile.crowns()
	var extra := HeroGear.roll_item("lionheart", 0.0, "common", rng)
	HeroGear.add_item(extra)
	HeroGear.salvage("lionheart", int(extra["uid"]))
	check("salvaging gives crowns", Profile.crowns() > cr)
	var lv := HeroGear.mastery_level("brunhild")
	HeroGear.add_mastery_xp("brunhild", 5000)
	check("mastery levels up with XP", HeroGear.mastery_level("brunhild") > lv + 3)
	HeroGear.set_aura_choice("brunhild", "b")
	check("mastery unlocks the second aura", HeroDefs.active_aura("brunhild")["label"] == "Bulwark")
	HeroGear.set_aura_choice("brunhild", "a")
	# end-of-battle drop only for the hero used
	Profile.run["hero"] = "lyra"
	Profile.run["waves"] = 5
	var n0 := HeroGear.items("lyra").size()
	var n1 := HeroGear.items("voss").size()
	var res := Profile.finish_run(true)
	check("battle end drops gear for the hero used", HeroGear.items("lyra").size() > n0 and HeroGear.items("voss").size() == n1 and not res["gear"].is_empty())
	check("battle end gives hero mastery XP", int(res.get("hero_xp", 0)) > 0)
	Profile.begin_run()


func _finish() -> void:
	var fails := 0
	for r in results:
		if not r[1]:
			fails += 1
	print("KitTest: %d/%d passed" % [results.size() - fails, results.size()])
	get_tree().quit(1 if fails > 0 else 0)
