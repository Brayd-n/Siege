class_name HeroGear
extends RefCounted
## Hero gear: Weapon / Armor / Trinket pieces that drop at the end of a battle
## for the hero you used. Stored per hero in the profile; equipped pieces add
## stat bonuses to that hero only. Also hero mastery (XP across runs).

const SLOTS: Array[String] = ["weapon", "armor", "trinket"]
const SLOT_NAMES := {"weapon": "Weapon", "armor": "Armor", "trinket": "Trinket"}
const RARITIES: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_COLORS := {
	"common": Color(0.75, 0.73, 0.68), "uncommon": Color(0.35, 0.8, 0.35), "rare": Color(0.35, 0.6, 1.0),
	"epic": Color(0.72, 0.4, 0.95), "legendary": Color(1.0, 0.62, 0.15),
}
const SALVAGE := {"common": 5, "uncommon": 12, "rare": 30, "epic": 70, "legendary": 150}
const MAX_ITEMS := 40

## Stat pools per slot. Values are fractions (0.1 = +10%).
## damage_taken and ability_cd are reductions.
const POOLS := {
	"weapon": ["damage", "damage", "attack_speed", "crit", "ability_power"],
	"armor": ["max_hp", "max_hp", "damage_taken", "attack_speed", "damage"],
	"trinket": ["ability_cd", "ability_power", "aura_power", "range", "crit"],
}
const STAT_NAMES := {
	"damage": "Damage", "max_hp": "Health", "attack_speed": "Attack speed", "crit": "Crit chance",
	"ability_power": "Ability power", "ability_cd": "Ability cooldown", "aura_power": "Aura strength",
	"range": "Range", "damage_taken": "Damage taken",
}
const REDUCTIONS := ["ability_cd", "damage_taken"]
## rarity -> [number of stats, min value, max value]
const ROLLS := {
	"common": [1, 0.04, 0.07], "uncommon": [2, 0.05, 0.09], "rare": [2, 0.08, 0.13],
	"epic": [3, 0.10, 0.16], "legendary": [3, 0.13, 0.20],
}
const FAVORED := {"lionheart": "max_hp", "lyra": "crit", "voss": "ability_power", "brunhild": "damage_taken", "elowen": "aura_power"}

const BASES := {
	"lionheart": {"weapon": ["Longsword", "Bastard Sword", "Warblade"], "armor": ["Plate Cuirass", "Lion Mail", "Tower Plate"],
		"trinket": ["Signet Ring", "War Medal", "Royal Seal"]},
	"lyra": {"weapon": ["Longbow", "Yew Bow", "Recurve Bow"], "armor": ["Ranger Leathers", "Forest Cloak", "Hide Jerkin"],
		"trinket": ["Falcon Charm", "Quiver", "Feather Token"]},
	"voss": {"weapon": ["Staff", "Rod", "Grimoire"], "armor": ["Robes", "Mantle", "Starweave Coat"],
		"trinket": ["Amulet", "Orb", "Rune Stone"]},
	"brunhild": {"weapon": ["Pike", "Halberd", "War Spear"], "armor": ["Scale Mail", "Iron Hauberk", "Warden Plate"],
		"trinket": ["Clan Brooch", "Iron Torc", "Oath Ring"]},
	"elowen": {"weapon": ["Censer", "Holy Mace", "Sunstaff"], "armor": ["Vestments", "Sun Robes", "Blessed Habit"],
		"trinket": ["Relic", "Prayer Beads", "Sun Pendant"]},
}
const PREFIX := {
	"common": ["Worn", "Plain", "Sturdy"], "uncommon": ["Fine", "Keen", "Tempered"],
	"rare": ["Masterwork", "Runed", "Gleaming"], "epic": ["Exalted", "Storm-forged", "Ancient"],
}
const SUFFIX := {
	"damage": "of Fury", "max_hp": "of the Bear", "attack_speed": "of Haste", "crit": "of Precision",
	"ability_power": "of Power", "ability_cd": "of Swiftness", "aura_power": "of Leadership",
	"range": "of the Hawk", "damage_taken": "of Warding",
}
## One legendary effect per hero, rolled on legendary pieces.
const LEGENDARY := {
	"lionheart": {"id": "lion_oath", "name": "Lionheart's Oath", "desc": "Lion's Roar also heals Aldric for 40% of his health."},
	"lyra": {"id": "storm_string", "name": "Stormstring", "desc": "Rain of Arrows lasts 3s longer and covers 30% more ground."},
	"voss": {"id": "eye_storm", "name": "Eye of the Storm", "desc": "The lightning beam builds up twice as fast."},
	"brunhild": {"id": "ironbark", "name": "Ironbark Walls", "desc": "Barricades have double health and you can keep 3 at once."},
	"elowen": {"id": "dawnstone", "name": "Dawnstone", "desc": "Consecrate covers 50% more ground and lasts 4s longer."},
}

## Hero mastery: XP needed to reach each level, and what each level unlocks.
const MASTERY_MAX := 15
const MASTERY_REWARDS := {
	2: "Second aura unlocked",
	4: "Royal skin",
	6: "Start battles at hero level 2",
	8: "Shadow skin",
	10: "+5% damage and health",
	12: "Legend skin",
	15: "Start battles at hero level 3",
}
const SKINS := {
	"default": {"name": "Default", "level": 1},
	"royal": {"name": "Royal", "level": 4, "cape": Color(0.12, 0.2, 0.6), "trim": Color(1.0, 0.85, 0.4)},
	"shadow": {"name": "Shadow", "level": 8, "cape": Color(0.08, 0.07, 0.1), "trim": Color(0.6, 0.2, 0.9)},
	"legend": {"name": "Legend", "level": 12, "cape": Color(0.95, 0.9, 0.8), "trim": Color(1.0, 0.95, 0.6), "glow": true},
}


# ------------------------------------------------------------------ storage
static func _hero_data(hero: String) -> Dictionary:
	var g: Dictionary = Profile.data.get("gear", {})
	if not g.has(hero):
		g[hero] = {"items": [], "equipped": {}}
		Profile.data["gear"] = g
	return g[hero]


static func items(hero: String) -> Array:
	return _hero_data(hero)["items"]


static func equipped_uid(hero: String, slot: String) -> int:
	return int(_hero_data(hero)["equipped"].get(slot, -1))


static func equipped(hero: String, slot: String) -> Dictionary:
	var uid := equipped_uid(hero, slot)
	for it in items(hero):
		if int(it["uid"]) == uid:
			return it
	return {}


static func equip(hero: String, uid: int) -> void:
	for it in items(hero):
		if int(it["uid"]) == uid:
			_hero_data(hero)["equipped"][it["slot"]] = uid
			Profile.mark_dirty()
			return


static func unequip(hero: String, slot: String) -> void:
	_hero_data(hero)["equipped"].erase(slot)
	Profile.mark_dirty()


static func salvage(hero: String, uid: int) -> int:
	var list := items(hero)
	for i in list.size():
		if int(list[i]["uid"]) == uid:
			var it: Dictionary = list[i]
			for slot in SLOTS:
				if equipped_uid(hero, slot) == uid:
					unequip(hero, slot)
			list.remove_at(i)
			var crowns: int = SALVAGE.get(it["rarity"], 5)
			Profile.add_crowns(crowns, "")
			Profile.mark_dirty()
			return crowns
	return 0


## Salvage every unequipped item at or below a rarity. Returns crowns gained.
static func salvage_below(hero: String, max_rarity: String) -> int:
	var limit := RARITIES.find(max_rarity)
	var total := 0
	for it in items(hero).duplicate():
		if RARITIES.find(it["rarity"]) <= limit and not is_equipped(hero, int(it["uid"])):
			total += salvage(hero, int(it["uid"]))
	return total


static func is_equipped(hero: String, uid: int) -> bool:
	for slot in SLOTS:
		if equipped_uid(hero, slot) == uid:
			return true
	return false


# ------------------------------------------------------------------ stats
## Multiplier for one stat from everything the hero has equipped (1.0 = none).
static func stat_mult(hero: String, stat: String) -> float:
	if hero == "" or Profile.data.is_empty() or not Profile.data.has("gear"):
		return 1.0 + _mastery_bonus(hero, stat)
	var total := 0.0
	var reduce := 1.0
	for slot in SLOTS:
		var it := equipped(hero, slot)
		if it.is_empty():
			continue
		var v := float(it["stats"].get(stat, 0.0))
		if stat in REDUCTIONS:
			reduce *= 1.0 - v
		else:
			total += v
	if stat in REDUCTIONS:
		return reduce
	return 1.0 + total + _mastery_bonus(hero, stat)


static func _mastery_bonus(hero: String, stat: String) -> float:
	if hero == "" or not stat in ["damage", "max_hp"]:
		return 0.0
	return 0.05 if mastery_level(hero) >= 10 else 0.0


static func has_legendary(hero: String, effect: String) -> bool:
	for slot in SLOTS:
		if String(equipped(hero, slot).get("effect", "")) == effect:
			return true
	return false


static func item_power(it: Dictionary) -> float:
	var p := 0.0
	for k in it["stats"]:
		p += float(it["stats"][k])
	return p + (0.15 if it.has("effect") else 0.0)


static func describe_stats(it: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k in it["stats"]:
		var v := float(it["stats"][k])
		if k in REDUCTIONS:
			out.append("-%d%% %s" % [int(round(v * 100)), STAT_NAMES.get(k, k)])
		else:
			out.append("+%d%% %s" % [int(round(v * 100)), STAT_NAMES.get(k, k)])
	if it.has("effect"):
		out.append("%s: %s" % [LEGENDARY[it["hero"]]["name"], LEGENDARY[it["hero"]]["desc"]])
	return out


# ------------------------------------------------------------------ drops
## Roll a new piece for a hero. `luck` 0..~4 pushes the rarity up.
static func roll_item(hero: String, luck: float, min_rarity: String = "common", rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var weights := {
		"common": max(8.0, 50.0 - 10.0 * luck), "uncommon": 30.0, "rare": 14.0 + 5.0 * luck,
		"epic": 4.0 + 3.0 * luck, "legendary": 0.8 + 1.1 * luck,
	}
	var rarity := "common"
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := rng.randf() * total
	for k in RARITIES:
		r -= weights[k]
		if r <= 0.0:
			rarity = k
			break
	if RARITIES.find(rarity) < RARITIES.find(min_rarity):
		rarity = min_rarity
	var slot: String = SLOTS[rng.randi() % SLOTS.size()]
	var roll: Array = ROLLS[rarity]
	var stats := {}
	var pool: Array = POOLS[slot].duplicate()
	if rng.randf() < 0.5:
		pool.append(FAVORED.get(hero, "damage"))
	var main: String = pool[rng.randi() % pool.size()]
	var tries := 0
	while stats.size() < int(roll[0]) and tries < 30:
		tries += 1
		var st: String = main if stats.is_empty() else pool[rng.randi() % pool.size()]
		if stats.has(st):
			continue
		var v := snappedf(rng.randf_range(float(roll[1]), float(roll[2])), 0.01)
		if st == "crit":
			v *= 0.6
		stats[st] = v
	Profile.data["gear_uid"] = int(Profile.data.get("gear_uid", 0)) + 1
	var base_names: Array = BASES.get(hero, BASES["lionheart"])[slot]
	var base: String = base_names[rng.randi() % base_names.size()]
	var it := {"uid": int(Profile.data["gear_uid"]), "hero": hero, "slot": slot, "rarity": rarity, "stats": stats}
	if rarity == "legendary":
		it["effect"] = LEGENDARY[hero]["id"]
		it["name"] = "%s (%s)" % [LEGENDARY[hero]["name"], base]
	else:
		var pre: Array = PREFIX[rarity]
		it["name"] = "%s %s %s" % [pre[rng.randi() % pre.size()], base, SUFFIX.get(main, "")]
	return it


## Adds a piece to the hero's inventory (auto-salvaging the weakest if full).
static func add_item(it: Dictionary) -> void:
	var hero: String = it["hero"]
	var list := items(hero)
	list.append(it)
	if list.size() > MAX_ITEMS:
		var worst: Dictionary = {}
		for x in list:
			if is_equipped(hero, int(x["uid"])):
				continue
			if worst.is_empty() or item_power(x) < item_power(worst):
				worst = x
		if not worst.is_empty():
			salvage(hero, int(worst["uid"]))
	# auto-equip into an empty slot
	if equipped_uid(hero, it["slot"]) == -1:
		equip(hero, int(it["uid"]))
	Profile.mark_dirty()


# ------------------------------------------------------------------ mastery
static func xp_for_level(level: int) -> int:
	return int(round(150.0 * pow(float(level - 1), 1.5)))


static func mastery_xp(hero: String) -> int:
	return int(Profile.data.get("hero_xp", {}).get(hero, 0))


static func mastery_level(hero: String) -> int:
	if hero == "" or Profile.data.is_empty():
		return 1
	var xp := mastery_xp(hero)
	var lv := 1
	while lv < MASTERY_MAX and xp >= xp_for_level(lv + 1):
		lv += 1
	return lv


## Returns the new mastery level.
static func add_mastery_xp(hero: String, amount: int) -> int:
	var d: Dictionary = Profile.data.get("hero_xp", {})
	d[hero] = int(d.get(hero, 0)) + amount
	Profile.data["hero_xp"] = d
	Profile.mark_dirty()
	return mastery_level(hero)


static func start_level_bonus(hero: String) -> int:
	var lv := mastery_level(hero)
	return (2 if lv >= 15 else (1 if lv >= 6 else 0))


static func skin(hero: String) -> String:
	var s := String(Profile.data.get("hero_skin", {}).get(hero, "default"))
	if not SKINS.has(s) or mastery_level(hero) < int(SKINS[s]["level"]):
		return "default"
	return s


static func set_skin(hero: String, s: String) -> void:
	var d: Dictionary = Profile.data.get("hero_skin", {})
	d[hero] = s
	Profile.data["hero_skin"] = d
	Profile.mark_dirty()


static func aura_choice(hero: String) -> String:
	var c := String(Profile.data.get("hero_aura", {}).get(hero, "a"))
	return c if (c == "a" or mastery_level(hero) >= 2) else "a"


static func set_aura_choice(hero: String, c: String) -> void:
	var d: Dictionary = Profile.data.get("hero_aura", {})
	d[hero] = c
	Profile.data["hero_aura"] = d
	Profile.mark_dirty()
