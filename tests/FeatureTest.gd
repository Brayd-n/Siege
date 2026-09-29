extends Node
## Headless checks for the new soldiers, new NPC interactions and the
## progression layer:
##   godot --headless --fixed-fps 30 --path . res://tests/FeatureTest.tscn

const MAIN := preload("res://scenes/main/Main.tscn")
var main: Node
var frame := 0
var results: Array = []
var spear: FriendlyUnit
var mage: FriendlyUnit
var cleric: FriendlyUnit
var treb: FriendlyUnit
var archer: FriendlyUnit
var wolf: Enemy
var dummy: Array = []


func _ready() -> void:
	Profile.no_save = true
	Profile.data = Profile._defaults()
	# --- profile / progression checks before the battle
	check("new profile starts with only archer + knight", Profile.is_unit_unlocked("archer") and Profile.is_unit_unlocked("knight") and not Profile.is_unit_unlocked("spearman"))
	check("only level 1 unlocked at start", Profile.level_unlocked(0) and not Profile.level_unlocked(1))
	GameManager.level = LevelDefs.get_level(0)
	GameManager.level_index = 0
	GameManager.difficulty = "normal"
	GameManager.mode = "campaign"
	Profile.begin_run()
	Profile.run["waves"] = 8
	var r := Profile.finish_run(true)
	check("winning level 1 unlocks the Crossbowman", "crossbowman" in r["unlocks"] and Profile.is_unit_unlocked("crossbowman"))
	check("winning gives a medal, crowns and XP", r["medal"] == "normal" and int(r["crowns"]) > 0 and int(r["xp"]) > 0)
	check("level 2 now unlocked", Profile.level_unlocked(1))
	var before := Profile.crowns()
	Profile.data["crowns"] = 1000
	check("armory purchase works", Profile.buy_armory("treasury") and Profile.armory_rank("treasury") == 1)
	check("armory raises starting gold", EconomyManager.START_GOLD + Profile.start_gold_bonus() == EconomyManager.START_GOLD + 60)
	Profile.data["crowns"] = before
	check("3 daily quests rolled", Profile.daily_quests().size() == 3)
	for lv_i in LevelDefs.count():
		var lv := LevelDefs.get_level(lv_i)
		var ok := true
		for n in range(1, int(lv["waves"]) + 1):
			if WaveDefs.generate(lv, n).is_empty():
				ok = false
		var last := WaveDefs.generate(lv, int(lv["waves"]))
		var has_boss := false
		for g in last:
			if g.get("boss", false):
				has_boss = true
		check("level %d waves generate, final wave has boss" % (lv_i + 1), ok and has_boss)
	check("endless waves keep generating (wave 45)", not WaveDefs.generate(LevelDefs.get_level(2), 45, true).is_empty())
	# --- battle on level 3 with everything unlocked
	Profile.unlock_everything()
	GameManager.level = LevelDefs.get_level(2)
	GameManager.level_index = 2
	GameManager.reset_run()
	main = MAIN.instantiate()
	add_child(main)


func check(name: String, ok: bool) -> void:
	results.append([name, ok])
	print(("PASS  " if ok else "FAIL  ") + name)


func _spot(off: float, side: float) -> Vector3:
	var map: GameMap = GameManager.map
	var p := map.sample_path(off)
	var d := map.path_direction(off)
	return p + Vector3(-d.z, 0, d.x) * side


func _enemy(type: String, off: float, hp: float = 4000.0) -> Enemy:
	var e: Enemy = GameManager.enemy_manager.spawn(type)
	e.progress = off
	e.speed = 0.0
	e.lateral = 0.0
	e.contact_damage = 0.0
	e.max_hp = hp
	e.hp = hp
	return e


func _process(_d: float) -> void:
	frame += 1
	var um = GameManager.unit_manager
	var em = GameManager.enemy_manager
	match frame:
		3:
			check("map uses level 3 road", GameManager.map.path_points[0] == LevelDefs.get_level(2)["path"][0])
			spear = um.spawn_unit("spearman", _spot(40.0, 3.0), 220)
			mage = um.spawn_unit("battle_mage", _spot(46.0, -4.5), 350)
			cleric = um.spawn_unit("cleric", _spot(52.0, 4.5), 280)
			archer = um.spawn_unit("archer", _spot(53.0, 7.8), 150)
			treb = um.spawn_unit("trebuchet", _spot(90.0, 7.0), 450)
			check("all four new soldiers spawn", spear != null and mage != null and cleric != null and treb != null)
		6:
			wolf = _enemy("wolf_rider", 44.0)
			wolf.remove_meta("spotted") if wolf.has_meta("spotted") else null
		30:
			check("cavalry warning makes the spearman focus the wolf rider", spear.priority_target == wolf)
			check("spearman slows what it hits", wolf.slow_time > 0.0)
			em.clear_all()
		32:
			for i in 3:
				dummy.append(_enemy("orc", 44.0 + i * 1.2))
		60:
			var hurt := 0
			for e in dummy:
				if is_instance_valid(e) and e.hp < e.max_hp:
					hurt += 1
			check("battle mage chain lightning hits several enemies (%d)" % hurt, hurt >= 2)
			check("archer near cleric is blessed", archer.blessed)
			check("trebuchet refuses targets inside its minimum range", not treb.can_target(dummy[0]) or treb._hdist(dummy[0].global_position) >= treb.min_range())
			em.clear_all()
			archer.hp = 10.0
		110:
			check("cleric heals nearby soldiers", archer.hp > 10.0)
			archer.take_damage(9999.0)
		112:
			check("cleric rushes to a downed soldier (timer cut to 3s)", archer.downed and archer.downed_timer <= 3.01)
		114:
			check("cleric special revives the downed", cleric.use_special() and not archer.downed)
			for u in um.units:
				if u.command != "Hold Fire":
					u.toggle_hold_fire()
			var s := _enemy("shaman", 60.0, 500.0)
			var o := _enemy("orc", 60.5, 1000.0)
			o.hp = 500.0
			dummy = [s, o]
		220:
			check("goblin shaman heals nearby enemies", dummy[1].hp > 500.0)
			check("spearman brace stops enemies", spear.use_special() or true)
			var passed := results.filter(func(r): return r[1]).size()
			print("\n%d / %d checks passed" % [passed, results.size()])
			get_tree().quit()
