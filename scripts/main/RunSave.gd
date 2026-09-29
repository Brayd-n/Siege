class_name RunSave
extends RefCounted
## Mid-run save & resume. A snapshot is taken at the start of every build
## phase (and when you quit to the map). "Continue" on the main menu rebuilds
## the battle from it: soldiers, upgrades, hero, boons, relics, gold and lives.


static func has_save() -> bool:
	return Profile.data.has("run_save") and not (Profile.data["run_save"] as Dictionary).is_empty()


static func summary() -> String:
	if not has_save():
		return ""
	var s: Dictionary = Profile.data["run_save"]
	var lv := LevelDefs.get_level(int(s["level_index"]))
	var mode := String(s.get("mode", "campaign"))
	var m: String = "Endless" if mode == "endless" else ("Daily" if mode == "challenge" else LevelDefs.DIFFICULTIES[s["difficulty"]]["name"])
	return "%s (%s) - wave %d" % [lv["name"], m, int(s["wave"]) + 1]


static func clear() -> void:
	Profile.data.erase("run_save")
	Profile.mark_dirty()


static func snapshot() -> void:
	if GameManager.is_over() or GameManager.unit_manager == null:
		return
	var units: Array = []
	for u in GameManager.unit_manager.units:
		var fu := u as FriendlyUnit
		units.append({
			"type": fu.unit_type, "x": fu.home_position.x, "z": fu.home_position.z,
			"up": [fu.upgrades[0], fu.upgrades[1], fu.upgrades[2]], "spec": fu.spec,
			"name": fu.display_name, "pers": fu.personality, "kills": fu.kills,
			"tgt": fu.targeting, "cmd": fu.command if fu.command != "Assist" else "Normal",
			"inv": fu.invested, "dealt": fu.damage_dealt, "hero": fu.hero_id, "hlv": fu.hero_level,
		})
	var bm := BoonManager
	Profile.data["run_save"] = {
		"level_index": GameManager.level_index, "difficulty": GameManager.difficulty, "mode": GameManager.mode,
		"heat": GameManager.heat.duplicate(), "salt": GameManager.seed_salt, "hero_id": GameManager.hero_id,
		"wave": GameManager.wave, "lives": GameManager.lives, "gold": EconomyManager.gold,
		"earned": EconomyManager.total_earned, "kills": GameManager.total_kills,
		"hero_bonus": GameManager.hero_bonus_levels,
		"boons": bm.active.duplicate(true), "relics": bm.relics.duplicate(true),
		"rerolls": bm.rerolls, "free_rerolls": bm.free_rerolls_left, "omen": bm.current_omen.get("id", ""),
		"forced_omen": bm.forced_omen, "phoenix": bm.phoenix_used, "lantern": bm.lantern_kills,
		"relic_pending": bm.relic_pending, "last_event": bm.last_draft_was_event,
		"units": units, "run": Profile.run.duplicate(true),
	}
	Profile.save_profile()


## Menu -> battle: set up the run from the save and load the battle scene.
static func resume() -> void:
	if not has_save():
		return
	var s: Dictionary = Profile.data["run_save"]
	GameManager.pending_resume = s.duplicate(true)
	GameManager.level_index = int(s["level_index"])
	GameManager.level = LevelDefs.get_level(GameManager.level_index)
	GameManager.difficulty = String(s["difficulty"])
	GameManager.mode = String(s["mode"])
	GameManager.heat = (s.get("heat", []) as Array).duplicate()
	GameManager.seed_salt = int(s.get("salt", 0))
	GameManager.hero_id = String(s.get("hero_id", ""))
	GameManager.reset_run(true)
	GameManager.get_tree().paused = false
	GameManager.get_tree().change_scene_to_file(GameManager.BATTLE_SCENE)


## Called by the battle scene once it is ready.
static func apply(s: Dictionary) -> void:
	GameManager.wave = int(s["wave"])
	GameManager.lives = int(s["lives"])
	GameManager.total_kills = int(s.get("kills", 0))
	GameManager.hero_bonus_levels = int(s.get("hero_bonus", 0))
	EconomyManager.gold = int(s["gold"])
	EconomyManager.total_earned = int(s.get("earned", 0))
	var bm := BoonManager
	bm.active = (s.get("boons", []) as Array).duplicate(true)
	bm.relics = (s.get("relics", []) as Array).duplicate(true)
	bm.rerolls = int(s.get("rerolls", 0))
	bm.free_rerolls_left = int(s.get("free_rerolls", 0))
	bm.forced_omen = String(s.get("forced_omen", ""))
	bm.phoenix_used = bool(s.get("phoenix", false))
	bm.lantern_kills = int(s.get("lantern", 0))
	bm.relic_pending = int(s.get("relic_pending", 0))
	bm.last_draft_was_event = bool(s.get("last_event", false))
	bm.current_omen = {}
	for o in bm.OMENS:
		if o["id"] == String(s.get("omen", "")):
			bm.current_omen = o
	Profile.run = (s.get("run", Profile.run) as Dictionary).duplicate(true)
	var um = GameManager.unit_manager
	for d in s.get("units", []):
		var pos := Vector3(float(d["x"]), 0, float(d["z"]))
		var fu: FriendlyUnit = null
		if String(d.get("hero", "")) != "":
			fu = um.spawn_hero(pos, true)
			if fu:
				fu.hero_level = int(d.get("hlv", 1))
		else:
			fu = um.spawn_unit(String(d["type"]), pos, int(d.get("inv", 0)), "", true)
		if fu == null:
			continue
		var up: Array = d.get("up", [0, 0, 0])
		for i in 3:
			fu.upgrades[i] = int(up[i])
		fu.spec = String(d.get("spec", ""))
		if fu.spec != "":
			fu._apply_spec_visuals()
		fu._update_rank_visuals()
		fu.display_name = String(d.get("name", fu.display_name))
		fu.personality = String(d.get("pers", fu.personality))
		fu.kills = int(d.get("kills", 0))
		fu.targeting = int(d.get("tgt", 0))
		fu.command = String(d.get("cmd", "Normal"))
		fu.invested = int(d.get("inv", 0))
		fu.damage_dealt = float(d.get("dealt", 0.0))
		fu.hp = fu.get_max_hp()
	EventBus.gold_changed.emit(EconomyManager.gold)
	EventBus.lives_changed.emit(GameManager.lives)
	EventBus.omen_changed.emit(bm.current_omen)
	GameManager.set_state(GameManager.State.BUILD)
	EventBus.feed_message.emit("Herald", "Run resumed at wave %d." % (GameManager.wave + 1), UiTheme.GOLD)
