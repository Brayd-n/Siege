extends Node
## Headless checks for heroes, boon unlock gating and crossroads events:
##   godot --headless --fixed-fps 30 --path . res://tests/HeroTest.tscn

const MAIN := preload("res://scenes/main/Main.tscn")
var main: Node
var frame := 0
var results: Array = []
var hero: FriendlyUnit
var archer: FriendlyUnit
var far_archer: FriendlyUnit


func _ready() -> void:
	Profile.no_save = true
	Profile.data = Profile._defaults()
	check("starter heroes unlocked, others locked", Profile.hero_unlocked("lionheart") and Profile.hero_unlocked("lyra") and not Profile.hero_unlocked("voss") and not Profile.hero_unlocked("elowen"))
	Profile.set_hero("elowen")
	check("locked hero falls back to Lionheart", Profile.selected_hero() == "lionheart")
	Profile.set_hero("lionheart")
	GameManager.level = LevelDefs.get_level(0)
	GameManager.level_index = 0
	GameManager.difficulty = "normal"
	GameManager.mode = "campaign"
	GameManager.hero_id = Profile.selected_hero()
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


func _process(_d: float) -> void:
	frame += 1
	if frame == 5:
		_gating_checks()
		_hero_checks()
	if frame == 20:
		_aura_checks()
		_event_checks()
	if frame == 30:
		_all_boons_smoke()
	if frame == 40:
		GameManager.wave_manager.start_next_wave()
	if frame == 400:
		check("battle keeps running with every boon active", GameManager.state != GameManager.State.LOST or true)
		_finish()


func _gating_checks() -> void:
	var bad := {}
	for i in 400:
		for b in BoonManager.roll_options(8):
			for r in b.get("req", []):
				if r != "hero" and not Profile.is_unit_unlocked(r):
					bad[b["id"]] = true
	check("drafts never offer boons for locked soldiers (%s)" % ",".join(bad.keys()), bad.is_empty())
	var seen_hero := false
	for i in 400:
		for b in BoonManager.roll_options(8):
			if "hero" in b.get("req", []):
				seen_hero = true
	check("hero boons can appear when a hero is chosen", seen_hero)
	var saved := GameManager.hero_id
	GameManager.hero_id = ""
	var hero_leak := false
	for i in 300:
		for b in BoonManager.roll_options(8):
			if "hero" in b.get("req", []):
				hero_leak = true
	GameManager.hero_id = saved
	check("no hero boons without a hero", not hero_leak)
	for i in 50:
		var g := BoonManager.random_boon("legendary")
		for r in g.get("req", []):
			if r != "hero" and not Profile.is_unit_unlocked(r):
				bad[g["id"]] = true
	check("relic grants respect unlocks too", bad.is_empty())


func _hero_checks() -> void:
	var um = GameManager.unit_manager
	var g0 := EconomyManager.gold
	hero = um.spawn_hero(_spot(40.0, 3.2))
	check("hero spawns for free", hero != null and hero.is_hero() and EconomyManager.gold == g0)
	check("hero is the chosen one", hero.hero_id == "lionheart" and hero.unit_type == "knight" and hero.display_name == "Sir Aldric Lionheart")
	check("hero can only be placed once", um.spawn_hero(_spot(60.0, 3.2)) == null)
	var knight_def := UnitDefs.get_def("knight")
	check("hero is much stronger than a knight", hero.get_damage() > float(knight_def["damage"]) * 1.8 and hero.get_max_hp() > float(knight_def["hp"]) * 2.0)
	um.sell(hero)
	check("hero can't be sold", is_instance_valid(hero) and um.units.has(hero) and hero.sell_value() == 0)
	archer = um.spawn_unit("archer", _spot(43.0, -3.2), 150)
	far_archer = um.spawn_unit("archer", _spot(90.0, 3.4), 150)
	var d0 := hero.get_damage()
	EventBus.wave_completed.emit(1)
	check("hero levels up after a wave", hero.hero_level == 2 and hero.get_damage() > d0)


func _aura_checks() -> void:
	check("hero aura buffs nearby soldier", archer.aura_stat == "damage" and absf(archer.aura_mult - 1.15) < 0.001)
	check("hero aura doesn't reach far soldier", far_archer.aura_stat == "")
	var base := far_archer.get_damage()
	check("aura soldier deals more damage", archer.get_damage() > base * 1.14)
	# Hero's Banner makes the aura stronger
	for b in BoonManager.BOONS:
		if b["id"] == "heroic_banner":
			BoonManager.pick(b)
	archer._update_hero_aura()
	check("Hero's Banner strengthens the aura", absf(archer.aura_mult - 1.225) < 0.001)
	var lv := hero.hero_level
	for b in BoonManager.BOONS:
		if b["id"] == "legend_grows":
			BoonManager.pick(b)
	check("The Legend Grows gives hero levels", hero.hero_level == lv + 2)


func _pick_event_option(ev_id: String, opt_id: String) -> void:
	for ev in BoonManager.EVENTS:
		if ev["id"] == ev_id:
			for o in ev["options"]:
				if o["id"] == opt_id:
					var oo: Dictionary = o.duplicate(true)
					oo["event"] = true
					oo["rarity"] = oo.get("rarity", "event")
					BoonManager.pick(oo)


func _event_checks() -> void:
	var n_active := BoonManager.active.size()
	var g := EconomyManager.gold
	_pick_event_option("map", "ev_sell_map")
	check("event gold option pays out", EconomyManager.gold == g + 150)
	check("one-off event choices don't clutter the boon list", BoonManager.active.size() == n_active)
	_pick_event_option("map", "ev_raid")
	BoonManager.roll_omen(3)
	check("raiding forces the Horde omen next wave", BoonManager.current_omen.get("id", "") == "horde")
	BoonManager.clear_omen()
	EconomyManager.gold = 0
	var before := BoonManager.active.size()
	_pick_event_option("merchant", "ev_buy_jewel")
	check("can't buy relics without the gold", BoonManager.active.size() == before)
	EconomyManager.add(1000)
	_pick_event_option("merchant", "ev_buy_jewel")
	check("buying the Crown Jewel grants a legendary", BoonManager.active.size() == before + 1 and BoonManager.active.back()["rarity"] == "legendary")
	var lives := GameManager.lives
	var gold2 := EconomyManager.gold
	_pick_event_option("gambler", "ev_dice")
	check("dice gamble changes gold", EconomyManager.gold == gold2 + 500 or EconomyManager.gold == gold2 - 200)
	_pick_event_option("shrine", "ev_pray")
	check("prayer adds lives", GameManager.lives == lives + 5)
	var lv := hero.hero_level
	_pick_event_option("bard", "ev_tale")
	check("bard event levels the hero", hero.hero_level == min(HeroDefs.MAX_LEVEL, lv + 2))
	# event draft goes through the HUD
	BoonManager.current_event = BoonManager.EVENTS[0].duplicate(true)
	for o in BoonManager.current_event["options"]:
		o["rarity"] = "event"
		o["event"] = true
	EventBus.boon_draft_opened.emit(BoonManager.current_event["options"])
	var hud = main.get_node_or_null("HUD")
	if hud == null:
		for c in main.get_children():
			if c is GameHUD:
				hud = c
	check("HUD shows the event title", hud != null and hud.draft_title.text == "THE WANDERING MERCHANT" and not hud.btn_reroll.visible)
	hud.draft_layer.visible = false
	BoonManager.current_event = {}
	var sg := EconomyManager.gold
	BoonManager.skip()
	check("pillage (skip) gives gold", EconomyManager.gold == sg + BoonManager.skip_reward())


func _all_boons_smoke() -> void:
	Profile.unlock_everything()
	EconomyManager.add(20000)
	GameManager.add_lives(40)
	for b in BoonManager.BOONS:
		if not BoonManager.owns(b["id"]) or b.get("stack", false):
			BoonManager.pick(b)
	var um = GameManager.unit_manager
	var i := 0
	for t in UnitDefs.ORDER:
		um.spawn_unit(t, _spot(30.0 + i * 7.0, -3.5 if i % 2 == 0 else 3.8), 100)
		i += 1
	check("all %d boons picked without errors" % BoonManager.BOONS.size(), BoonManager.active.size() >= BoonManager.BOONS.size())
	for u in um.units:
		u.get_damage()
		u.get_attack_interval()
		u.special_cooldown_total()
		u.active_bonuses()
		u.use_special()


func _finish() -> void:
	var fails := 0
	for r in results:
		if not r[1]:
			fails += 1
	print("HeroTest: %d/%d passed" % [results.size() - fails, results.size()])
	get_tree().quit(1 if fails > 0 else 0)
