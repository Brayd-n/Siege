extends Node
## Loads every level headless, checks the roads/river/night rules and runs a
## few seconds of each:  godot --headless --fixed-fps 30 --path . res://tests/MapsTest.tscn

var idx := 0
var f := 0
var results: Array = []


func _ready() -> void:
	if get_parent() != get_tree().root or name != "MapsDriver":
		var d: Node = load("res://tests/MapsTest.gd").new()
		d.name = "MapsDriver"
		get_tree().root.add_child.call_deferred(d)
		set_process(false)
		return
	Profile.no_save = true
	Profile.data = Profile._defaults()
	Profile.unlock_everything()
	_load(0)


func check(name: String, ok: bool) -> void:
	results.append([name, ok])
	print(("PASS  " if ok else "FAIL  ") + name)


func _load(i: int) -> void:
	idx = i
	f = 0
	var t0 := Time.get_ticks_msec()
	GameManager.start_level(i, "normal", "campaign")
	print("loading ", LevelDefs.get_level(i)["id"], " ...")


func _process(_d: float) -> void:
	if name != "MapsDriver":
		return
	f += 1
	if f == 20:
		var map: GameMap = GameManager.map
		var lv := LevelDefs.get_level(idx)
		check("%s: map built (%d road%s)" % [lv["id"], map.path_count(), "s" if map.path_count() > 1 else ""], map != null and map.path_count() >= 1)
		GameManager.wave_manager.start_next_wave()
		if lv["id"] == "twin_fords":
			var seen := {}
			for i in 6:
				var e: Enemy = GameManager.enemy_manager.spawn("goblin")
				seen[e.path_idx] = true
			check("twin fords: enemies use both roads", seen.size() == 2)
			var a := map.length_of(0)
			var b := map.length_of(1)
			check("twin fords: both roads end at the castle", map.sample_on(0, a).distance_to(map.sample_on(1, b)) < 1.0)
		if lv["id"] == "riverwatch":
			var water := Vector3(2.0, 0, -28.0)
			check("riverwatch: can't build in the river", map.placement_error(water) != "")
			var plat: Vector2 = lv["bridges"][0]
			check("riverwatch: can build on a platform", map.placement_error(Vector3(plat.x, 0, plat.y)) == "")
			check("riverwatch: road bridges built", map.find_child("Bridge*", true, false) != null)
		if lv["id"] == "blackwood":
			check("blackwood: map is dark", map.is_dark)
			var e2: Enemy = GameManager.enemy_manager.spawn_at("goblin", 0, 3.0)
			e2.reveal_timer = 0.0
			check("blackwood: enemies in the dark are hidden", e2.is_hidden())
			var far := true
			for lp in map.light_points:
				if Vector2(e2.global_position.x, e2.global_position.z).distance_to(lp) < 9.0:
					far = false
			if not far:
				print("  (spawn point happens to be lit)")
	if f == 110:
		var lv2 := LevelDefs.get_level(idx)
		check("%s: runs without losing the battle state" % lv2["id"], GameManager.main != null)
		if lv2["id"] == "blackwood":
			var lit := 0
			for e in GameManager.enemy_manager.enemies:
				if is_instance_valid(e) and not e.is_hidden():
					lit += 1
			print("  lit enemies: ", lit, " / ", GameManager.enemy_manager.enemies.size())
		if idx + 1 < LevelDefs.count():
			_load(idx + 1)
		else:
			var fails := 0
			for r in results:
				if not r[1]:
					fails += 1
			print("MapsTest: %d/%d passed" % [results.size() - fails, results.size()])
			get_tree().quit(1 if fails > 0 else 0)
