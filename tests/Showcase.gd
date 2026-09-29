extends Node
## Renders showcase screenshots of the new content (dev tool).
##   xvfb-run godot --path . res://tests/Showcase.tscn -- out=/tmp/shots

var out_dir := "/tmp"
var f := 0
var stage := 0


func _ready() -> void:
	if get_parent() != get_tree().root or name != "ShowDriver":
		var d: Node = load("res://tests/Showcase.gd").new()
		d.name = "ShowDriver"
		get_tree().root.add_child.call_deferred(d)
		set_process(false)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
	Profile.no_save = true
	Profile.data = Profile._defaults()
	Profile.data["seen_intro"] = true
	Profile.data["login"]["last"] = Profile.today()
	Profile.unlock_everything()
	HeroGear.add_mastery_xp("lionheart", 4000)
	for i in 14:
		HeroGear.add_item(HeroGear.roll_item("lionheart", 2.5))
	for t in EnemyDefs.ORDER:
		Profile.mark_seen("enemy:" + t)
	Profile.set_hero("lionheart")
	GameManager.start_level(7, "normal", "campaign")


func _save(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(out_dir + "/" + n + ".png")
	print("saved ", n)


func _cam(pos: Vector3, dist: float, yaw: float = 0.0) -> void:
	var rig: CameraRig = GameManager.main.camera_rig
	rig.position = pos
	rig.target_distance = dist
	rig.distance = dist
	rig.target_yaw = yaw
	rig.yaw = yaw


func _spot(pi: int, off: float, side: float) -> Vector3:
	var map: GameMap = GameManager.map
	var p := map.sample_on(pi, off)
	var d := map.dir_on(pi, off)
	var c := p + Vector3(-d.z, 0, d.x) * side
	for k in 6:
		if map.placement_error(c) == "":
			return c
		c = p + Vector3(-d.z, 0, d.x) * side * (1.2 + 0.25 * k)
	return c


func _process(_d: float) -> void:
	if name != "ShowDriver":
		return
	f += 1
	var um = GameManager.unit_manager
	var em = GameManager.enemy_manager
	match f:
		30:
			# ---- Riverwatch
			EconomyManager.add(9000)
			var lv := LevelDefs.get_level(7)
			for b in lv["bridges"]:
				um.spawn_unit("crossbowman", Vector3(b.x, 0, b.y), 0)
			var types := ["archer", "knight", "battle_mage", "torch_thrower", "cleric", "spearman"]
			for i in types.size():
				um.spawn_unit(types[i], _spot(0, 20.0 + i * 11.0, 3.6 if i % 2 == 0 else -3.6), 0)
			um.spawn_hero(GameManager.map.sample_on(0, 70.0))
			GameManager.wave_manager.start_next_wave()
			for i in 8:
				em.spawn_at("goblin", 0, 10.0 + i * 2.5)
			em.spawn_at("shieldbearer", 0, 28.0)
			em.spawn_at("orc", 0, 34.0)
			_cam(Vector3(0, 0, -4), 62.0, 0.35)
		110:
			_save("river_overview")
			_cam(Vector3(2, 0, -10), 26.0, 0.9)
		135:
			_save("river_bridge")
			GameManager.start_level(8, "normal", "campaign")
		175:
			# ---- Blackwood at night
			EconomyManager.add(9000)
			var types2 := ["torch_thrower", "archer", "knight", "cleric", "battle_mage", "archer", "torch_thrower"]
			for i in types2.size():
				um.spawn_unit(types2[i], _spot(0, 18.0 + i * 10.0, 3.6 if i % 2 == 0 else -3.6), 0)
			GameManager.wave_manager.start_next_wave()
			for i in 10:
				em.spawn_at("goblin", 0, 8.0 + i * 3.0)
			em.spawn_at("necromancer", 0, 30.0)
			for i in 6:
				em.spawn_at("bat", 0, 20.0 + i)
			var p: Vector3 = GameManager.map.sample_on(0, 40.0)
			_cam(p, 34.0, 0.6)
		255:
			_save("night")
			GameManager.start_level(6, "normal", "campaign")
		295:
			# ---- Twin Fords: hero on the road holding a boss wave
			EconomyManager.add(9000)
			var road: Vector3 = GameManager.map.sample_on(0, 58.0)
			var hero: FriendlyUnit = um.spawn_hero(road)
			hero.hero_level = 5
			var types3 := ["archer", "crossbowman", "spearman", "cleric", "battle_mage", "trebuchet", "archer", "knight"]
			for i in types3.size():
				var pi := i % 2
				um.spawn_unit(types3[i], _spot(pi, 36.0 + (i / 2) * 7.0, 3.6 if i % 3 == 0 else -3.6), 0)
			GameManager.wave_manager.start_next_wave()
			var w: Enemy = em.spawn_at("warlord", 0, 44.0)
			w.speed = 0.6
			for i in 8:
				em.spawn_at("goblin", 0, 40.0 + i * 1.2)
			em.spawn_at("shieldbearer", 1, 40.0)
			em.spawn_at("sapper", 1, 44.0)
			em.spawn_at("skeleton", 1, 46.0)
			em.spawn_at("skeleton", 1, 47.0)
			um.select(hero)
			_cam(road + Vector3(-6, 0, 0), 30.0, 0.3)
		330:
			var hero2: FriendlyUnit = GameManager.hero_unit
			hero2.kit.use_ability(1, hero2.global_position)
		380:
			_save("twin_boss")
			GameManager.to_menu()
		430:
			_save("menu")
			get_tree().current_scene._show_heroes("lionheart")
		460:
			_save("heroes")
			get_tree().current_scene._show_codex("enemy:elder_dragon")
		490:
			_save("codex")
			get_tree().current_scene._choose_difficulty(7)
		520:
			_save("level_screen")
			get_tree().quit()
