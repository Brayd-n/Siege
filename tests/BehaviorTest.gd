extends Node
## Headless assertions for the NPC requirements:
##   godot --headless --fixed-fps 30 --path . res://tests/BehaviorTest.tscn
## Checks that talking, player orders and NPC-to-NPC messages really change behaviour.

const MAIN := preload("res://scenes/main/Main.tscn")
var main: Node
var frame := 0
var results: Array = []
var archer: FriendlyUnit
var archer2: FriendlyUnit
var knight: FriendlyUnit
var xbow: FriendlyUnit
var torch: FriendlyUnit
var troll: Enemy
var knight_home: Vector3


func _ready() -> void:
	Profile.no_save = true
	Profile.data = Profile._defaults()
	Profile.unlock_everything()
	var lvl := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			lvl = int(a.substr(6))
	GameManager.level_index = lvl
	GameManager.level = LevelDefs.get_level(lvl)
	GameManager.difficulty = "normal"
	GameManager.mode = "endless" if "endless" in OS.get_cmdline_user_args() else "campaign"
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


func _process(_d: float) -> void:
	frame += 1
	var um = GameManager.unit_manager
	var em = GameManager.enemy_manager
	match frame:
		3:
			archer = um.spawn_unit("archer", _spot(60.0, 3.2), 150)
			archer2 = um.spawn_unit("archer", _spot(80.0, -3.6), 150)
			knight = um.spawn_unit("knight", _spot(66.0, -2.8), 200)
			xbow = um.spawn_unit("crossbowman", _spot(70.0, 4.5), 250)
			torch = um.spawn_unit("torch_thrower", _spot(52.0, -4.5), 300)
			knight_home = knight.global_position
			check("5 soldiers placed", um.units.size() == 5)
			check("soldiers have names & personalities", archer.display_name != "" and archer.personality in UnitDefs.PERSONALITIES)
		5:
			var line := archer.talk()
			check("TALK returns a context line: \"%s\"" % line, line.length() > 3)
			check("TALK line reaches the feed (last_line)", archer.last_line == line)
		6:
			# targeting: FIRST vs LAST choose different enemies
			var a = em.spawn("goblin")
			a.progress = 56.0
			var b = em.spawn("goblin")
			b.progress = 64.0
			a.speed = 0.0
			b.speed = 0.0
			a.contact_damage = 0.0
			b.contact_damage = 0.0
		8:
			archer.set_targeting(FriendlyUnit.Targeting.FIRST)
			var t_first: Enemy = archer._acquire_target()
			archer.set_targeting(FriendlyUnit.Targeting.LAST)
			var t_last: Enemy = archer._acquire_target()
			check("FIRST and LAST pick different enemies", t_first != null and t_last != null and t_first != t_last)
			check("FIRST picks the enemy furthest along the road", t_first != null and t_first.progress > t_last.progress)
			archer.toggle_hold_fire()
			check("Hold Fire order sets command", archer.command == "Hold Fire")
			archer.toggle_hold_fire()
			archer.set_assist(archer2)
			check("Assist order targets ally", archer.command == "Assist" and archer.assist_unit == archer2)
			archer.set_assist(null)
			em.clear_all()
		10:
			# heavy enemy warning -> crossbow & torch thrower focus the troll
			troll = em.spawn("troll")
			troll.progress = 52.0
			troll.speed = 0.0
			troll.contact_damage = 0.0
		40:
			check("someone spotted the troll", troll.has_meta("spotted"))
			check("Crossbowman focuses troll after warning", xbow.priority_target == troll)
			check("Torch Thrower focuses troll after warning", torch.priority_target == troll)
			em.clear_all()
		42:
			# support request -> knight walks over
			for i in 3:
				var g = em.spawn("goblin")
				g.progress = map_offset_near(archer) + i * 0.5
				g.speed = 0.0
				g.contact_damage = 0.0
				g.lateral = 0.0
				g.max_hp = 5000.0
				g.hp = 5000.0
		60:
			for e in em.enemies:
				print("  goblin dist to archer: %.2f" % archer._hdist(e.global_position))
			print("  knight dist: %.2f  cd %.1f" % [archer._hdist(knight.global_position), archer.support_call_cd])
		80:
			check("knight received support request", knight.support_ally == archer or knight.recent_event == "supported")
			check("knight left its post to help", knight.global_position.distance_to(knight_home) > 0.5)
			em.clear_all()
		82:
			var dragon = em.spawn("dragon")
			dragon.progress = 58.0
			dragon.speed = 0.0
		120:
			var focused := 0
			for u in um.units:
				if u.unit_type != "knight" and u.priority_target != null and u.priority_target.enemy_type == "dragon":
					focused += 1
			check("dragon alarm: ranged soldiers focus the dragon (%d)" % focused, focused >= 3)
			check("knights can't target the flying dragon", not knight.can_target(em.enemies[0]))
		122:
			var spent := EconomyManager.gold
			var ok := archer.try_upgrade(0) or EconomyManager.gold < 100
			check("upgrade works and raises damage", ok and archer.upgrades[0] == 1)
			check("special ability fires", xbow.use_special() and xbow.special_active > 0.0)
			var value := torch.sell_value()
			um.sell(torch)
			check("sell refunds 70%", value == int(round(300 * 0.7)))
		130:
			var passed := results.filter(func(r): return r[1]).size()
			print("\n%d / %d checks passed" % [passed, results.size()])
			get_tree().quit()


func map_offset_near(u: FriendlyUnit) -> float:
	return GameManager.map.closest_offset(u.global_position)
