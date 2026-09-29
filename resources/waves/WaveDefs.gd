class_name WaveDefs
extends RefCounted
## Wave generation. Each level has an enemy roster (type + first wave it can
## appear), a difficulty factor and a boss. Waves are generated from a threat
## budget with a seeded RNG, so a level always plays the same way.
## Endless mode keeps generating harder waves forever.
##
## Group format: {type, count, interval (s between spawns), delay (s into wave)}

const COST := {"goblin": 4.5, "goblin_archer": 8.0, "wolf_rider": 8.0, "orc": 22.0, "shaman": 16.0, "troll": 90.0,
	"shieldbearer": 13.0, "sapper": 10.0, "bat": 3.2, "necromancer": 26.0, "skeleton": 3.0, "dragon": 900.0}
const INTERVAL := {"goblin": 0.6, "goblin_archer": 1.2, "wolf_rider": 0.8, "orc": 1.2, "shaman": 2.0, "troll": 3.5,
	"shieldbearer": 1.1, "sapper": 1.4, "bat": 0.3, "necromancer": 2.5, "skeleton": 0.6, "dragon": 1.0}
const BOSS_COST := 600.0
const ELITE_PRIORITY: Array[String] = ["troll", "necromancer", "orc", "shieldbearer", "wolf_rider", "goblin_archer", "goblin"]

const WAVE_BONUS_BASE := 90
const WAVE_BONUS_PER := 15
const HP_SCALE_PER_WAVE := 0.12


## Number of waves in the current run (0 = endless).
static func count() -> int:
	if GameManager.mode == "endless":
		return 0
	return int(GameManager.level.get("waves", 10))


static func budget(n: int, factor: float) -> float:
	# gentle early curve, then an extra late-game ramp so big armies stay challenged
	var late := 1.0 + 0.045 * pow(float(max(0, n - 6)), 1.3)
	return 42.0 * pow(float(n), 1.42) * factor * late


static func get_wave(n: int) -> Array:
	return generate(GameManager.level, n, GameManager.mode == "endless", GameManager.seed_salt)


static func generate(level: Dictionary, n: int, endless: bool = false, salt: int = 0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(level.get("id", "x")) + ":" + str(n) + ":" + str(salt))
	var factor: float = level.get("factor", 1.0)
	var total := int(level.get("waves", 10))
	var boss_wave := (not endless and n == total) or (endless and n % 10 == 0)
	if endless:
		factor *= 1.0 + 0.04 * max(0, n - total)
	var roster: Array = []
	for r in level.get("roster", [["goblin", 1]]):
		if n >= int(r[1]) or endless:
			roster.append(r[0])
	var b := budget(n, factor)
	var groups: Array = []
	var delay := 0.0
	if boss_wave:
		var boss: String = level.get("boss", "warlord")
		var bc := int(level.get("boss_count", 1))
		if endless:
			boss = LevelDefs.ENDLESS_BOSSES[(n / 10 - 1) % LevelDefs.ENDLESS_BOSSES.size()] if n >= 10 else boss
			bc += n / 30
		groups.append({"type": boss, "count": bc, "interval": 5.0, "delay": 12.0, "boss": true})
		b -= BOSS_COST * 0.5
		b = max(b, budget(n, factor) * 0.4)
	# elite: halfway through a level (and every 10 waves in endless, offset from bosses)
	var elite_wave := (not endless and n == int(ceil(total / 2.0))) or (endless and n % 10 == 5)
	if not elite_wave and GameManager.heat_has("elites") and n % 5 == 0 and n > 0 and not boss_wave:
		elite_wave = true
	if elite_wave:
		var et := "goblin"
		for cand in ELITE_PRIORITY:
			var ok := false
			for r in level.get("roster", []):
				if r[0] == cand and (int(r[1]) <= n or endless):
					ok = true
			if ok:
				et = cand
				break
		groups.append({"type": et, "count": 1, "interval": 1.0, "delay": 8.0, "elite": true})
	# the newest roster member gets featured in its first wave
	var featured := ""
	for r in level.get("roster", []):
		if int(r[1]) == n:
			featured = r[0]
	var n_groups := clampi(1 + n / 3, 1, 4)
	var picks: Array = []
	if featured != "" and not endless:
		picks.append(featured)
		n_groups = max(n_groups, 2)
	while picks.size() < n_groups:
		var t_pick: String = roster[rng.randi() % roster.size()]
		if t_pick == featured and picks.size() > 0:
			t_pick = roster[0]
		picks.append(t_pick)
	# split the budget between groups (a newly introduced enemy is only a taste)
	var shares: Array = []
	var share_total := 0.0
	for i in picks.size():
		var s := rng.randf_range(0.6, 1.4)
		if i == 0 and featured != "" and not endless:
			s = 0.45
		shares.append(s)
		share_total += s
	for i in picks.size():
		var t: String = picks[i]
		var gb: float = b * shares[i] / share_total
		var c := int(round(gb / COST[t]))
		if c <= 0:
			if t == "troll" or t == "necromancer":
				continue
			c = 1
		# don't let heavy units flood early waves
		if t == "troll":
			c = min(c, 1 + n / 4)
		if t == "necromancer":
			c = min(c, 1 + n / 6)
		if t == "bat":
			c = max(c, 5)
		var interval: float = INTERVAL[t] * clamp(20.0 / max(c, 1), 0.45, 1.0)
		groups.append({"type": t, "count": c, "interval": interval, "delay": delay})
		delay += rng.randf_range(3.0, 7.0)
	return merge_groups(groups)


static func merge_groups(groups: Array) -> Array:
	var out: Array = []
	for g in groups:
		var merged := false
		for o in out:
			if o["type"] == g["type"] and abs(float(o["delay"]) - float(g["delay"])) < 0.01 and o.get("boss", false) == g.get("boss", false) and not g.get("elite", false) and not o.get("elite", false):
				o["count"] += g["count"]
				merged = true
		if not merged:
			out.append(g.duplicate())
	return out


static func describe(n: int) -> String:
	var groups := get_wave(n)
	var totals := {}
	var order: Array = []
	for g in groups:
		if not totals.has(g["type"]):
			order.append(g["type"])
		totals[g["type"]] = totals.get(g["type"], 0) + int(g["count"])
	var parts: Array[String] = []
	for t in order:
		var ed := EnemyDefs.get_def(t)
		var nm: String = ed.get("title", ed.get("name", t))
		var c: int = totals[t]
		if EnemyDefs.is_boss(t):
			parts.append(nm if c == 1 else "%d x %s" % [c, nm])
		else:
			parts.append("%d %s%s" % [c, nm, "s" if c > 1 and not nm.ends_with("s") else ""])
	return ", ".join(parts)


static func has_elite(n: int) -> bool:
	for g in get_wave(n):
		if g.get("elite", false):
			return true
	return false


static func is_boss_wave(n: int) -> bool:
	for g in get_wave(n):
		if g.get("boss", false):
			return true
	return false
