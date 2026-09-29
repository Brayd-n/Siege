extends Node
## Headless auto-play test. Run with:
##   godot --headless --fixed-fps 30 --path . res://tests/AutoTest.tscn
## A simple bot recruits soldiers, upgrades, talks, gives orders, uses specials,
## drafts boons and plays every wave. Prints a summary of what happened.

const MAIN := preload("res://scenes/main/Main.tscn")

var main: Node
var t: float = 0.0
var stats := {"said": 0, "heavy": 0, "support": 0, "dragon": 0, "kills": 0, "leaks": 0, "downed": 0, "boons": [], "talk": []}
var spot_cursor: float = 20.0
var side: float = 1.0
var build_order := ["archer", "archer", "knight", "crossbowman", "torch_thrower", "spearman", "battle_mage", "archer", "cleric", "knight", "trebuchet", "crossbowman", "battle_mage", "archer", "torch_thrower", "spearman", "trebuchet", "crossbowman"]
var build_i := 0
var last_state := -1
var talk_done := false
var target_mode_done := false


func _ready() -> void:
	Engine.time_scale = 1.0
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
	GameManager.hero_id = "lionheart"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("hero="):
			GameManager.hero_id = a.substr(5)
	GameManager.reset_run()
	main = MAIN.instantiate()
	add_child(main)
	EventBus.npc_said.connect(_on_said)
	EventBus.heavy_enemy_spotted.connect(func(_e, _u): stats["heavy"] += 1)
	EventBus.ally_needs_support.connect(func(_u, _e): stats["support"] += 1)
	EventBus.dragon_spotted.connect(func(_d, _u): stats["dragon"] += 1)
	EventBus.enemy_killed.connect(func(_e, _k): stats["kills"] += 1)
	EventBus.enemy_reached_castle.connect(func(_e): stats["leaks"] += 1)
	EventBus.unit_downed.connect(func(_u): stats["downed"] += 1)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.boon_draft_opened.connect(_on_draft)
	EventBus.feed_message.connect(_on_feed)
	print("path length: ", GameManager.map.path_length)


var line_counts := {}


func _on_said(_u, text: String) -> void:
	stats["said"] += 1
	line_counts[text] = int(line_counts.get(text, 0)) + 1


func _on_feed(s: String, m: String, _c: Color) -> void:
	if s == "Orders" and t < 400.0:
		print("   [orders] ", m)


func _on_wave_completed(n: int) -> void:
	print("WAVE %d cleared  t=%.0fs lives=%d gold=%d units=%d kills=%d leaks=%d said=%d heavy=%d support=%d" % [
		n, t, GameManager.lives, EconomyManager.gold, GameManager.unit_manager.units.size(), stats["kills"],
		stats["leaks"], stats["said"], stats["heavy"], stats["support"]])


func _on_draft(options: Array) -> void:
	# prefer non-cursed rare/legendary, else first
	var pickb: Dictionary = {}
	for b in options:
		if BoonManager.can_pick(b) and (pickb.is_empty() or b["rarity"] in ["legendary", "rare", "relic"]):
			pickb = b
	if pickb.is_empty():
		get_tree().create_timer(0.5, false).timeout.connect(BoonManager.skip)
		return
	stats["boons"].append(pickb["name"])
	get_tree().create_timer(0.5, false).timeout.connect(func(): BoonManager.pick(pickb))


func _on_game_over(victory: bool) -> void:
	print("GAME OVER victory=", victory, " wave=", GameManager.wave, " lives=", GameManager.lives, " t=", int(t))
	print("stats: ", stats)
	var keys := line_counts.keys()
	keys.sort_custom(func(a, b): return line_counts[a] > line_counts[b])
	for i in mini(12, keys.size()):
		print("   said x%d: %s" % [line_counts[keys[i]], keys[i]])
	var um = GameManager.unit_manager
	for u in um.units:
		print("  %s (%s, %s) lvl %d kills %d dealt %d" % [u.display_name, u.unit_type, u.personality, u.get_level(), u.kills, int(u.damage_dealt)])
	get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit())


func _find_spot(type: String) -> Vector3:
	## Walk the road from the portal side, try both sides at a sensible distance.
	var map: GameMap = GameManager.map
	var dists := [2.7, 3.2] if type == "knight" else [3.6, 4.5, 5.5]
	var off := 18.0
	var pi := build_i % map.path_count()
	while off < map.length_of(pi) * 0.8:
		for dist in dists:
			for sd in [1.0, -1.0]:
				var p := map.sample_on(pi, off)
				var dir := map.dir_on(pi, off)
				var c: Vector3 = p + Vector3(-dir.z, 0, dir.x) * sd * dist
				if map.placement_error(c) == "" and GameManager.unit_manager.unit_at(c, 2.2) == null:
					return c
		off += 3.0
	return Vector3.INF


func _build() -> void:
	var um = GameManager.unit_manager
	var pm = GameManager.placement_manager
	if GameManager.hero_id != "" and not GameManager.hero_deployed():
		var hs := _find_spot("knight")
		if hs != Vector3.INF:
			um.spawn_hero(hs)
	# specialize anything that can
	# buy
	for n in 4:
		var type: String = build_order[build_i % build_order.size()]
		if not EconomyManager.can_afford(EconomyManager.unit_cost(type)):
			break
		var spot := _find_spot(type)
		if spot == Vector3.INF:
			print("  no spot for ", type)
			break
		pm.begin(type)
		pm.update_mouse(spot, true)
		pm._process(0.0)
		if pm.try_place(false):
			build_i += 1
		else:
			print("  place failed: ", type, " ", pm.ghost_error, " at ", spot)
			pm.cancel()
	# upgrade with leftover gold, keep a reserve for the next recruit
	if um.units.size() >= 6:
		for u in um.units:
			for i in 3:
				var c: int = u.upgrade_cost(i)
				if c > 0 and EconomyManager.gold - c > 150:
					u.try_upgrade(i)
			if u.can_specialize() and EconomyManager.gold - u.spec_cost(0) > 150:
				u.try_specialize(randi() % 2)


func _process(delta: float) -> void:
	t += delta
	if GameManager.is_over():
		return
	# hero abilities on cooldown, aimed at the biggest enemy near the hero
	var h = GameManager.hero_unit
	if GameManager.state == GameManager.State.WAVE and is_instance_valid(h) and h.kit:
		for i in 2:
			if h.kit.ability_ready(i):
				var best = null
				for e in GameManager.enemy_manager.enemies:
					if is_instance_valid(e) and e.alive and not e.is_hidden() and h._hdist(e.global_position) < 16.0:
						if best == null or e.hp > best.hp:
							best = e
				if best:
					var pos: Vector3 = best.global_position
					if h.kit.ability_def(i).get("target", "") == "road":
						pos = GameManager.map.nearest_road_point(pos)
					h.kit.use_ability(i, pos)
	var um = GameManager.unit_manager
	if t > 1.0 and not talk_done and um.units.size() > 0:
		talk_done = true
		stats["talk"].append(um.units[0].talk())
	match GameManager.state:
		GameManager.State.BUILD:
			if t > 0.5:
				_build()
				if um.units.size() > 0 and not target_mode_done:
					target_mode_done = true
					um.units[0].set_targeting(FriendlyUnit.Targeting.STRONG)
					um.select(um.units[0])
				if um.units.size() >= 2:
					stats["talk"].append(um.units[randi() % um.units.size()].talk())
				GameManager.wave_manager.start_next_wave()
				Engine.time_scale = 4.0
		GameManager.State.WAVE:
			# use specials when enemies are around
			for u in um.units:
				if u.special_ready() and u.target != null and randf() < 0.02:
					u.use_special()
	if t > 3600.0:
		print("TIMEOUT")
		get_tree().quit()
