extends Node
## Persistent player profile (the "live service" layer).
## Saved to user://siegewatch_profile.json. Tracks player level/XP, Crowns
## (meta currency), unit unlocks, level medals, endless records, Armory
## upgrades, daily quests, achievements, login streak, lifetime stats and
## settings. Listens to gameplay signals to progress quests/achievements.

signal crowns_changed(amount: int)
signal profile_changed
signal toast(title: String, body: String, color: Color)

const SAVE_PATH := "user://siegewatch_profile.json"
const SAVE_VERSION := 2

# ------------------------------------------------------------------ Armory (permanent upgrades)
const ARMORY := [
	{"id": "treasury", "name": "War Treasury", "desc": "+60 starting gold per rank.", "costs": [100, 200, 350], "icon": "coin"},
	{"id": "walls", "name": "Stone Walls", "desc": "+3 castle lives per rank.", "costs": [150, 300], "icon": "heart"},
	{"id": "veterans", "name": "Veteran Recruits", "desc": "+6% damage for every soldier per rank.", "costs": [200, 400, 650], "icon": "star"},
	{"id": "vitality", "name": "Blessed Steel", "desc": "+12% soldier health per rank.", "costs": [150, 300], "icon": "star"},
	{"id": "ledger", "name": "Quartermaster's Ledger", "desc": "Upgrades cost 6% less per rank.", "costs": [180, 360], "icon": "coin"},
	{"id": "medics", "name": "Field Medics", "desc": "Downed soldiers get up 3s sooner per rank.", "costs": [150, 300], "icon": "heart"},
	{"id": "scouts", "name": "Signal Horns", "desc": "Soldiers warn and help allies from 20% farther per rank.", "costs": [120, 240], "icon": "flag"},
	{"id": "favor", "name": "Royal Favor", "desc": "One free boon reroll every level per rank.", "costs": [250, 500], "icon": "star"},
]

# ------------------------------------------------------------------ daily quests
## kind -> what increments it. target scaled by the "n" array.
const QUEST_POOL := [
	{"id": "kill_goblins", "text": "Slay %d goblins", "kind": "kill:goblin", "n": [80, 150], "reward": 40},
	{"id": "kill_any", "text": "Defeat %d enemies", "kind": "kill:any", "n": [200, 400], "reward": 50},
	{"id": "kill_trolls", "text": "Topple %d trolls", "kind": "kill:troll", "n": [3, 8], "reward": 60},
	{"id": "kill_wolves", "text": "Stop %d wolf riders", "kind": "kill:wolf_rider", "n": [20, 50], "reward": 45},
	{"id": "waves", "text": "Clear %d waves", "kind": "wave", "n": [10, 20], "reward": 50},
	{"id": "talk", "text": "Talk to your soldiers %d times", "kind": "talk", "n": [5, 10], "reward": 30},
	{"id": "specials", "text": "Use %d special abilities", "kind": "special", "n": [8, 15], "reward": 40},
	{"id": "upgrades", "text": "Buy %d upgrades", "kind": "upgrade", "n": [10, 20], "reward": 40},
	{"id": "recruit", "text": "Recruit %d soldiers", "kind": "place", "n": [15, 30], "reward": 35},
	{"id": "win", "text": "Win %d level(s)", "kind": "win", "n": [1, 2], "reward": 70},
	{"id": "support", "text": "Have knights answer %d calls for help", "kind": "support", "n": [5, 12], "reward": 45},
	{"id": "boons", "text": "Claim %d Spoils of War", "kind": "boon", "n": [5, 10], "reward": 35},
]

# ------------------------------------------------------------------ achievements
const ACHIEVEMENTS := [
	{"id": "first_blood", "name": "First Blood", "desc": "Defeat your first enemy.", "stat": "kills", "goal": 1, "reward": 10},
	{"id": "goblin_bane", "name": "Goblin Bane", "desc": "Defeat 1,000 goblins.", "stat": "goblin_kills", "goal": 1000, "reward": 100},
	{"id": "giant_killer", "name": "Giant Killer", "desc": "Topple 50 trolls.", "stat": "troll_kills", "goal": 50, "reward": 100},
	{"id": "dragonslayer", "name": "Dragonslayer", "desc": "Slay a dragon.", "stat": "dragon_kills", "goal": 1, "reward": 150},
	{"id": "chatterbox", "name": "Talk of the Town", "desc": "Talk to your soldiers 25 times.", "stat": "talks", "goal": 25, "reward": 40},
	{"id": "commander", "name": "Commander", "desc": "Recruit 100 soldiers.", "stat": "placed", "goal": 100, "reward": 60},
	{"id": "brotherhood", "name": "Brothers in Arms", "desc": "Knights answer 50 calls for help.", "stat": "supports", "goal": 50, "reward": 80},
	{"id": "first_win", "name": "The Kingdom Stands", "desc": "Win your first level.", "stat": "wins", "goal": 1, "reward": 50},
	{"id": "campaign", "name": "Hero of the Realm", "desc": "Beat every level on Normal or harder.", "stat": "", "goal": 0, "reward": 300},
	{"id": "hardened", "name": "Hard as Steel", "desc": "Win any level on Hard.", "stat": "", "goal": 0, "reward": 120},
	{"id": "flawless", "name": "Not One Step", "desc": "Win a level without losing a single life.", "stat": "", "goal": 0, "reward": 120},
	{"id": "pactmaker", "name": "Pact Maker", "desc": "Take 3 cursed pacts in one run and win.", "stat": "", "goal": 0, "reward": 100},
	{"id": "maxed", "name": "Legend in the Making", "desc": "Raise a soldier to level 7.", "stat": "", "goal": 0, "reward": 60},
	{"id": "endless30", "name": "The Long Night", "desc": "Reach wave 30 in Endless.", "stat": "", "goal": 0, "reward": 150},
	{"id": "veteran", "name": "Veteran Commander", "desc": "Reach player level 10.", "stat": "", "goal": 0, "reward": 150},
	{"id": "armory_full", "name": "Fully Stocked", "desc": "Buy every Armory rank.", "stat": "", "goal": 0, "reward": 200},
]

var data: Dictionary = {}
var run: Dictionary = {}          ## stats for the level currently being played
var _dirty := false
var no_save := false      ## tests set this so they never touch the real save
var _save_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()
	_roll_daily_if_needed()
	apply_settings()
	_fit_window_to_screen.call_deferred()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.enemy_spawned.connect(_on_enemy_seen)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.unit_placed.connect(_on_unit_placed)
	EventBus.unit_upgraded.connect(_on_unit_upgraded)
	EventBus.special_used.connect(_on_special_used)
	EventBus.player_talked.connect(_on_player_talked)
	EventBus.ally_needs_support.connect(_on_support)
	EventBus.boon_picked.connect(_on_boon_picked)
	EventBus.enemy_reached_castle.connect(_on_enemy_leaked)


func _process(delta: float) -> void:
	if _dirty:
		_save_timer -= delta
		if _save_timer <= 0.0:
			save_profile()


# ================================================================== persistence
func _defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION, "xp": 0, "level": 1, "crowns": 0,
		"unlocked": LevelDefs.STARTING_UNITS.duplicate(),
		"medals": {}, "endless_best": {}, "armory": {}, "achievements": {},
		"stats": {"kills": 0, "goblin_kills": 0, "troll_kills": 0, "dragon_kills": 0, "talks": 0,
			"placed": 0, "supports": 0, "wins": 0, "games": 0, "waves": 0, "specials": 0},
		"daily": {"date": "", "quests": [], "challenge_done": false},
		"login": {"last": "", "streak": 0},
		"seen_intro": false, "hero": "lionheart",
		"settings": {"master": 0.8, "sfx": 1.0, "ambience": 0.7, "quality": "high", "fullscreen": false,
			"camera_speed": 1.0, "show_chat": true, "auto_waves": false, "colorblind": false, "ui_scale": 1.0, "binds": {}},
	}


func load_profile() -> void:
	data = _defaults()
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_merge(data, parsed)


## Copy saved values over defaults so new fields in updates get sensible values.
func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from:
		if into.has(k) and into[k] is Dictionary and from[k] is Dictionary:
			_merge(into[k], from[k])
		else:
			into[k] = from[k]


func save_profile() -> void:
	_dirty = false
	if no_save:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func mark_dirty() -> void:
	_dirty = true
	_save_timer = 1.0
	profile_changed.emit()


func reset_profile() -> void:
	data = _defaults()
	_roll_daily_if_needed()
	save_profile()
	profile_changed.emit()
	crowns_changed.emit(crowns())


# ================================================================== currency & level
func crowns() -> int:
	return int(data["crowns"])


func add_crowns(n: int, reason: String = "") -> void:
	if n == 0:
		return
	data["crowns"] = crowns() + n
	crowns_changed.emit(crowns())
	mark_dirty()
	if reason != "" and n > 0:
		toast.emit("+%d Crowns" % n, reason, UiTheme.GOLD)


func spend_crowns(n: int) -> bool:
	if crowns() < n:
		return false
	data["crowns"] = crowns() - n
	crowns_changed.emit(crowns())
	mark_dirty()
	return true


func player_level() -> int:
	return int(data["level"])


func xp() -> int:
	return int(data["xp"])


func xp_to_next() -> int:
	return int(100 * pow(player_level(), 1.3))


func add_xp(n: int) -> void:
	data["xp"] = xp() + n
	while xp() >= xp_to_next():
		data["xp"] = xp() - xp_to_next()
		data["level"] = player_level() + 1
		var reward := 25 + player_level() * 5
		add_crowns(reward)
		toast.emit("Level %d!" % player_level(), "Commander rank up. +%d Crowns" % reward, UiTheme.GOLD)
		if player_level() >= 10:
			unlock_achievement("veteran")
	mark_dirty()


# ================================================================== live events
## Weekend = double crowns. First week of each month = Dragon Week (dragon kills pay triple XP).
func active_events() -> Array:
	var out: Array = []
	var d := Time.get_date_dict_from_system()
	var wd: int = d["weekday"]
	if wd == Time.WEEKDAY_SATURDAY or wd == Time.WEEKDAY_SUNDAY:
		out.append({"id": "double_crowns", "name": "Weekend War Chest", "desc": "All Crowns earned are doubled this weekend."})
	if int(d["day"]) <= 7:
		out.append({"id": "dragon_week", "name": "Dragon Week", "desc": "Dragons appear in Endless every 5 waves and pay triple XP."})
	return out


func has_event(id: String) -> bool:
	for e in active_events():
		if e["id"] == id:
			return true
	return false


func crown_mult() -> float:
	return 2.0 if has_event("double_crowns") else 1.0


# ================================================================== unlocks & medals
func is_unit_unlocked(type: String) -> bool:
	return type in data["unlocked"]


func unlock_unit(type: String) -> bool:
	if is_unit_unlocked(type):
		return false
	(data["unlocked"] as Array).append(type)
	mark_dirty()
	return true


func unlock_everything() -> void:
	for t in UnitDefs.ORDER:
		unlock_unit(t)
	for lv in LevelDefs.LEVELS:
		var m: Array = data["medals"].get(lv["id"], [])
		if not "normal" in m:
			m.append("normal")
		data["medals"][lv["id"]] = m
	mark_dirty()


## Gear bonus for a hero stat (1.0 = none). Filled in by the gear system.
func hero_gear_mult(hero_id: String, stat: String) -> float:
	return HeroGear.stat_mult(hero_id, stat)


func has_seen(key: String) -> bool:
	return bool(data.get("seen", {}).get(key, false))


func mark_seen(key: String) -> void:
	var d: Dictionary = data.get("seen", {})
	if not d.get(key, false):
		d[key] = true
		data["seen"] = d
		mark_dirty()


func _on_enemy_seen(e) -> void:
	if is_instance_valid(e):
		mark_seen("enemy:" + String(e.enemy_type))


func hero_unlocked(id: String) -> bool:
	var h := HeroDefs.get_hero(id)
	if h.is_empty():
		return false
	var idx := int(h.get("unlock", -1))
	return idx < 0 or level_beaten(idx)


## The hero picked on the level screen ("" if the saved one is locked/unknown).
func selected_hero() -> String:
	var id := String(data.get("hero", "lionheart"))
	if id == "none":
		return ""
	return id if hero_unlocked(id) else "lionheart"


func set_hero(id: String) -> void:
	data["hero"] = id
	mark_dirty()


func medals(level_id: String) -> Array:
	return data["medals"].get(level_id, [])


func level_beaten(idx: int) -> bool:
	return not medals(LevelDefs.get_level(idx)["id"]).is_empty()


func level_unlocked(idx: int) -> bool:
	return idx == 0 or level_beaten(idx - 1)


func endless_unlocked() -> bool:
	return level_beaten(LevelDefs.index_of("dragons_reach"))


func endless_best(level_id: String) -> int:
	return int(data["endless_best"].get(level_id, 0))


# ================================================================== armory
func armory_rank(id: String) -> int:
	return int(data["armory"].get(id, 0))


func armory_def(id: String) -> Dictionary:
	for a in ARMORY:
		if a["id"] == id:
			return a
	return {}


func armory_next_cost(id: String) -> int:
	var a := armory_def(id)
	var r := armory_rank(id)
	var costs: Array = a.get("costs", [])
	return -1 if r >= costs.size() else int(costs[r])


func buy_armory(id: String) -> bool:
	var c := armory_next_cost(id)
	if c < 0 or not spend_crowns(c):
		return false
	data["armory"][id] = armory_rank(id) + 1
	mark_dirty()
	var full := true
	for a in ARMORY:
		if armory_rank(a["id"]) < (a["costs"] as Array).size():
			full = false
	if full:
		unlock_achievement("armory_full")
	return true


## Stat multipliers fed into BoonManager.get_mult so everything uses one path.
func armory_mult(stat: String, _unit_type: String) -> float:
	match stat:
		"damage":
			return 1.0 + 0.06 * armory_rank("veterans")
		"max_hp":
			return 1.0 + 0.12 * armory_rank("vitality")
		"upgrade_cost":
			return 1.0 - 0.06 * armory_rank("ledger")
	return 1.0


func start_gold_bonus() -> int:
	return 60 * armory_rank("treasury")


func start_lives_bonus() -> int:
	return 3 * armory_rank("walls")


func downed_time() -> float:
	return 10.0 - 3.0 * armory_rank("medics")


func comm_mult() -> float:
	return 1.0 + 0.2 * armory_rank("scouts")


func free_rerolls() -> int:
	return armory_rank("favor")


# ================================================================== daily login & quests
func today() -> String:
	return Time.get_date_string_from_system()


func _roll_daily_if_needed() -> void:
	var d: Dictionary = data["daily"]
	if d.get("date", "") == today():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today() + "quests")
	var pool := QUEST_POOL.duplicate()
	var quests: Array = []
	for i in 3:
		var q: Dictionary = pool.pop_at(rng.randi() % pool.size())
		var hard := i == 2
		var target: int = q["n"][1 if hard else 0]
		quests.append({"id": q["id"], "text": q["text"] % target, "kind": q["kind"], "target": target, "progress": 0,
			"reward": int(q["reward"] * (1.6 if hard else 1.0)), "claimed": false})
	data["daily"] = {"date": today(), "quests": quests, "challenge_done": false}
	mark_dirty()


func daily_quests() -> Array:
	_roll_daily_if_needed()
	return data["daily"]["quests"]


func claim_quest(i: int) -> bool:
	var q: Dictionary = daily_quests()[i]
	if q["claimed"] or int(q["progress"]) < int(q["target"]):
		return false
	q["claimed"] = true
	add_crowns(int(q["reward"] * crown_mult()), "Quest complete: " + q["text"])
	add_xp(40)
	return true


func _track(kind: String, amount: int) -> void:
	for q in daily_quests():
		if q["claimed"]:
			continue
		if q["kind"] == kind:
			var before := int(q["progress"])
			q["progress"] = min(int(q["target"]), before + amount)
			if before < int(q["target"]) and int(q["progress"]) >= int(q["target"]):
				toast.emit("Quest ready to claim", q["text"], UiTheme.GREEN)
	mark_dirty()


## Returns the crowns granted today, or 0 if already claimed.
func claim_login() -> int:
	var l: Dictionary = data["login"]
	if l.get("last", "") == today():
		return 0
	var yesterday := Time.get_date_string_from_unix_time(Time.get_unix_time_from_system() - 86400)
	var streak: int = int(l.get("streak", 0)) + 1 if l.get("last", "") == yesterday else 1
	data["login"] = {"last": today(), "streak": streak}
	var reward := int((20 + 10 * min(streak, 7)) * crown_mult())
	add_crowns(reward)
	return reward


func login_streak() -> int:
	return int(data["login"].get("streak", 0))


func login_pending() -> bool:
	return data["login"].get("last", "") != today()


func daily_challenge_level() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today() + "challenge")
	var available: Array = []
	for i in LevelDefs.count():
		if level_unlocked(i):
			available.append(i)
	return available[rng.randi() % available.size()]


func daily_challenge_salt() -> int:
	return hash(today()) % 100000


## Two Heat trials that everyone gets on today's challenge.
func daily_challenge_trials() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today() + "trials")
	var pool: Array = []
	for t in HeatDefs.TRIALS:
		if t["id"] != "heroless" and t["id"] != "omens":
			pool.append(t["id"])
	var out: Array = []
	while out.size() < 2:
		var id: String = pool[rng.randi() % pool.size()]
		pool.erase(id)
		out.append(id)
	return out


func heat_best(level_id: String) -> int:
	return int(data.get("heat_best", {}).get(level_id, -1))


## Past daily-challenge results: {date: {"waves", "won", "level"}}
func daily_history() -> Dictionary:
	return data.get("daily_scores", {})


# ================================================================== achievements & stats
func _stat(key: String, amount: int) -> void:
	var s: Dictionary = data["stats"]
	s[key] = int(s.get(key, 0)) + amount
	for a in ACHIEVEMENTS:
		if a["stat"] == key and int(s[key]) >= int(a["goal"]):
			unlock_achievement(a["id"])
	mark_dirty()


func has_achievement(id: String) -> bool:
	return data["achievements"].has(id)


func unlock_achievement(id: String) -> void:
	if has_achievement(id):
		return
	data["achievements"][id] = today()
	for a in ACHIEVEMENTS:
		if a["id"] == id:
			toast.emit("Achievement: " + a["name"], a["desc"], Color(0.6, 0.85, 1.0))
			add_crowns(int(a["reward"]))
	mark_dirty()


func stat(key: String) -> int:
	return int(data["stats"].get(key, 0))


# ================================================================== run tracking
func begin_run() -> void:
	run = {"kills": 0, "waves": 0, "lives_lost": 0, "cursed": 0, "xp": 0, "hero": "", "boss": false}
	data["stats"]["games"] = stat("games") + 1
	mark_dirty()


func _on_enemy_killed(e, _killer) -> void:
	if not is_instance_valid(e):
		return
	var t: String = e.enemy_type
	run["kills"] = int(run.get("kills", 0)) + 1
	var xp_gain := 1
	match t:
		"troll":
			xp_gain = 8
		"orc":
			xp_gain = 3
		"dragon":
			xp_gain = 60 * (3 if has_event("dragon_week") else 1)
	if e.is_boss:
		run["boss"] = true
		xp_gain = max(xp_gain, 50)
	run["xp"] = int(run.get("xp", 0)) + xp_gain
	_track("kill:any", 1)
	_track("kill:" + t, 1)
	_stat("kill_" + t, 1)
	_stat("kills", 1)
	if t == "goblin" or t == "goblin_archer":
		_stat("goblin_kills", 1)
	elif t == "troll":
		_stat("troll_kills", 1)
	elif t == "dragon":
		_stat("dragon_kills", 1)


func _on_wave_completed(_n: int) -> void:
	run["waves"] = int(run.get("waves", 0)) + 1
	run["xp"] = int(run.get("xp", 0)) + 10
	_track("wave", 1)
	_stat("waves", 1)


func _on_unit_placed(_u) -> void:
	_track("place", 1)
	_stat("placed", 1)


func _on_unit_upgraded(u) -> void:
	_track("upgrade", 1)
	if is_instance_valid(u) and u.get_level() >= 7:
		unlock_achievement("maxed")


func _on_boon_picked(b: Dictionary) -> void:
	_track("boon", 1)
	if b.get("rarity", "") == "cursed":
		run["cursed"] = int(run.get("cursed", 0)) + 1


func _on_enemy_leaked(e) -> void:
	if is_instance_valid(e):
		run["lives_lost"] = int(run.get("lives_lost", 0)) + int(e.lives_cost)


func _on_special_used(_u) -> void:
	_track("special", 1)
	_stat("specials", 1)


func _on_player_talked(_u) -> void:
	_track("talk", 1)
	_stat("talks", 1)


func _on_support(_u, _e) -> void:
	_track("support", 1)
	_stat("supports", 1)


## Called by the battle when it ends. Returns a rewards summary for the results screen.
func finish_run(victory: bool) -> Dictionary:
	var lv: Dictionary = GameManager.level
	var diff: String = GameManager.difficulty
	var dd: Dictionary = LevelDefs.DIFFICULTIES.get(diff, LevelDefs.DIFFICULTIES["normal"])
	var waves := int(run.get("waves", 0))
	var result := {"crowns": 0, "xp": 0, "unlocks": [], "medal": "", "first_clear": false, "record": false}
	var base := waves * 3
	if GameManager.mode == "endless":
		var best := endless_best(lv["id"])
		if GameManager.wave > best:
			data["endless_best"][lv["id"]] = GameManager.wave
			result["record"] = true
		base = GameManager.wave * 4
		if GameManager.wave >= 30:
			unlock_achievement("endless30")
	elif victory:
		_stat("wins", 1)
		_track("win", 1)
		base += 40
		var m: Array = medals(lv["id"])
		if not diff in m:
			m.append(diff)
			data["medals"][lv["id"]] = m
			result["medal"] = diff
			base += 50
			if m.size() == 1:
				result["first_clear"] = true
		var unlock: String = lv.get("unlock", "")
		if unlock != "" and unlock_unit(unlock):
			result["unlocks"].append(unlock)
		if diff == "hard":
			unlock_achievement("hardened")
		if int(run.get("lives_lost", 0)) == 0:
			unlock_achievement("flawless")
		if int(run.get("cursed", 0)) >= 3:
			unlock_achievement("pactmaker")
		var all_normal := true
		for l in LevelDefs.LEVELS:
			var mm: Array = medals(l["id"])
			if not ("normal" in mm or "hard" in mm):
				all_normal = false
		if all_normal:
			unlock_achievement("campaign")
	var crowns_gain := int(base * float(dd["crowns"]) * crown_mult())
	if victory and GameManager.mode == "challenge" and not data["daily"].get("challenge_done", false):
		data["daily"]["challenge_done"] = true
		crowns_gain += int(100 * crown_mult())
		result["challenge"] = true
	crowns_gain = int(crowns_gain * GameManager.heat_crown_mult())
	# records
	if victory and GameManager.mode == "campaign":
		var hb: Dictionary = data.get("heat_best", {})
		if GameManager.heat_points() > int(hb.get(lv["id"], -1)):
			hb[lv["id"]] = GameManager.heat_points()
			result["heat_record"] = GameManager.heat_points()
		data["heat_best"] = hb
	if GameManager.mode == "challenge":
		var ds: Dictionary = data.get("daily_scores", {})
		var prev: Dictionary = ds.get(today(), {})
		if waves > int(prev.get("waves", -1)) or (victory and not prev.get("won", false)):
			ds[today()] = {"waves": waves, "won": victory, "level": lv["name"]}
		data["daily_scores"] = ds
	var runs: Array = data.get("run_log", [])
	runs.push_front({"date": today(), "level": lv["name"], "mode": GameManager.mode, "diff": diff, "won": victory,
		"wave": GameManager.wave, "heat": GameManager.heat_points(), "hero": String(run.get("hero", ""))})
	if runs.size() > 25:
		runs.resize(25)
	data["run_log"] = runs
	result["crowns"] = crowns_gain
	result["xp"] = int(run.get("xp", 0)) + (100 if victory else 20)
	_hero_rewards(result, victory, waves)
	add_crowns(crowns_gain)
	add_xp(result["xp"])
	save_profile()
	return result


## Gear drop + mastery XP for the hero that fought this battle.
func _hero_rewards(result: Dictionary, victory: bool, waves: int) -> void:
	var hero := String(run.get("hero", ""))
	result["gear"] = []
	if hero == "" or waves <= 0:
		return
	var total := WaveDefs.count()
	var frac: float = float(waves) / float(total) if total > 0 else min(1.0, GameManager.wave / 30.0)
	var diff_luck := {"easy": 0.0, "normal": 0.5, "hard": 1.0}.get(GameManager.difficulty, 0.5) as float
	var luck: float = frac + (1.0 if victory else 0.0) + diff_luck + 0.12 * GameManager.heat_points()
	var min_r := "common"
	if victory and bool(result.get("first_clear", false)) and GameManager.level.get("reward", "") == "gear":
		min_r = "epic"
	var drops: Array = [HeroGear.roll_item(hero, luck, min_r)]
	if victory and bool(run.get("boss", false)) and randf() < 0.35:
		drops.append(HeroGear.roll_item(hero, luck))
	for it in drops:
		HeroGear.add_item(it)
	result["gear"] = drops
	var before := HeroGear.mastery_level(hero)
	var xp := int((waves * 12 + (120 if victory else 0)) * (1.0 + diff_luck * 0.5) * (1.0 + 0.1 * GameManager.heat_points()))
	var after := HeroGear.add_mastery_xp(hero, xp)
	result["hero"] = hero
	result["hero_xp"] = xp
	result["hero_mastery"] = after
	result["hero_level_up"] = after > before


# ================================================================== settings
func setting(key: String):
	return data["settings"].get(key)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	apply_settings()
	mark_dirty()


func apply_settings() -> void:
	_ensure_bus("SFX")
	_ensure_bus("Ambience")
	AudioServer.set_bus_volume_db(0, linear_to_db(max(0.0001, float(setting("master")))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(max(0.0001, float(setting("sfx")))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(max(0.0001, float(setting("ambience")))))
	if is_inside_tree():
		get_tree().root.content_scale_factor = clamp(float(setting("ui_scale") if setting("ui_scale") != null else 1.0), 0.75, 1.4)
	if not OS.has_feature("headless") and DisplayServer.get_name() != "headless":
		var fs: bool = setting("fullscreen")
		var mode := DisplayServer.window_get_mode()
		if fs and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fs and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Shrinks the 1600x900 window to fit smaller (laptop) screens and centres it.
## The UI and 3D view scale with the window (stretch mode canvas_items/expand).
func _fit_window_to_screen() -> void:
	if DisplayServer.get_name() == "headless" or setting("fullscreen"):
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var win := get_window()
	var scr := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(scr)
	var target := Vector2(1600, 900)
	# leave room for the title bar and taskbar
	var fit: float = min(1.0, min(usable.size.x * 0.94 / target.x, (usable.size.y - 40) * 0.94 / target.y))
	if fit >= 0.999:
		return
	var sz := Vector2i(target * fit)
	win.min_size = Vector2i(960, 540)
	win.size = sz
	win.position = usable.position + (usable.size - sz) / 2
	if OS.has_environment("SIEGE_PROFILE"):
		print("window fit ", sz, " on ", usable)


## F11 toggles fullscreen anywhere in the game.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_setting("fullscreen", not bool(setting("fullscreen")))
		get_viewport().set_input_as_handled()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func high_quality() -> bool:
	return setting("quality") == "high"


func _exit_tree() -> void:
	if _dirty:
		save_profile()
