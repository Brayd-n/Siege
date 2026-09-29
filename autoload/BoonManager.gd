extends Node
## Roguelike layer ("Spoils of War").
## After every wave the player drafts 1 of 3 random boons. Boons persist for the
## whole run and stack. Some are cursed Pacts with a real downside.
## Before some waves an Omen is rolled that changes only that wave.
##
## Stat queries: get_mult("damage", "archer") multiplies every matching mod key:
##   "damage:all" and "damage:archer".

const RARITY_COLORS := {
	"common": Color(0.78, 0.76, 0.7),
	"rare": Color(0.35, 0.62, 1.0),
	"legendary": Color(1.0, 0.72, 0.2),
	"cursed": Color(0.78, 0.3, 0.95),
	"event": Color(0.45, 0.85, 0.7),
	"relic": Color(1.0, 0.45, 0.25),
}

## Relics: rare run-changing items. Elites drop one (pick 1 of 2 after the
## wave); the Wandering Merchant sells them; Endless bosses drop them too.
const RELICS := [
	{"id": "crown_command", "name": "Crown of Command", "req": ["hero"],
		"desc": "Your hero's first ability casts itself whenever it is ready (every 30s at most)."},
	{"id": "horn_valor", "name": "Horn of Valor",
		"desc": "At the start of each wave, every soldier attacks 50% faster for 8s."},
	{"id": "midas", "name": "Midas Purse",
		"desc": "Clear a wave without losing a life: +150 gold."},
	{"id": "phoenix", "name": "Phoenix Feather",
		"desc": "The first time the castle would fall, it rises again with 10 lives."},
	{"id": "dragonglass", "name": "Dragonglass Shard",
		"desc": "All your soldiers' damage ignores armour."},
	{"id": "hourglass", "name": "Hourglass of Ages",
		"desc": "Every soldier's special is recharged at the start of each wave."},
	{"id": "soul_lantern", "name": "Soul Lantern",
		"desc": "Every 40 kills restore 1 castle life."},
	{"id": "war_banner", "name": "Great War Banner",
		"desc": "Soldiers with 2 or more allies within 6m deal +20% damage."},
	{"id": "echo_mirror", "name": "Mirror of Echoes",
		"desc": "The first special used each wave is cast a second time for free."},
	{"id": "bloodstone", "name": "Bloodstone",
		"desc": "Soldiers heal 4% of their health whenever they land a kill."},
]

const BOONS := [
	# ---------------- common (stackable stat boons)
	{"id": "sharpened_arrows", "name": "Sharpened Arrows", "rarity": "common", "stack": true, "req": ["archer"],
		"desc": "Archers deal +20% damage.", "mods": {"damage:archer": 1.2}},
	{"id": "heavy_bolts", "name": "Heavier Bolts", "rarity": "common", "stack": true, "req": ["crossbowman"],
		"desc": "Crossbowmen deal +20% damage.", "mods": {"damage:crossbowman": 1.2}},
	{"id": "tempered_steel", "name": "Tempered Steel", "rarity": "common", "stack": true, "req": ["knight"],
		"desc": "Knights deal +25% damage.", "mods": {"damage:knight": 1.25}},
	{"id": "pitch_oil", "name": "Barrels of Pitch", "rarity": "common", "stack": true, "req": ["torch_thrower"],
		"desc": "Torch Throwers deal +20% damage and burns last 1s longer.",
		"mods": {"damage:torch_thrower": 1.2}, "add": {"burn_time": 1.0}},
	{"id": "ash_pikes", "name": "Ash-Wood Pikes", "rarity": "common", "stack": true, "req": ["spearman"],
		"desc": "Spearmen deal +20% damage.", "mods": {"damage:spearman": 1.2}},
	{"id": "runed_staves", "name": "Runed Staves", "rarity": "common", "stack": true, "req": ["battle_mage"],
		"desc": "Battle Mages deal +20% damage.", "mods": {"damage:battle_mage": 1.2}},
	{"id": "holy_water", "name": "Holy Water", "rarity": "common", "stack": true, "req": ["cleric"],
		"desc": "Clerics heal 30% more.", "mods": {"heal:cleric": 1.3}},
	{"id": "oiled_gears", "name": "Oiled Counterweights", "rarity": "common", "stack": true, "req": ["trebuchet"],
		"desc": "Trebuchets fire 20% faster.", "mods": {"attack_speed:trebuchet": 1.2}},
	{"id": "eagle_eye", "name": "Eagle Eye", "rarity": "common", "stack": true,
		"desc": "All units gain +10% range.", "mods": {"range:all": 1.1}},
	{"id": "war_drums", "name": "War Drums", "rarity": "common", "stack": true,
		"desc": "All units attack 10% faster.", "mods": {"attack_speed:all": 1.1}},
	{"id": "tax_collectors", "name": "Tax Collectors", "rarity": "common", "stack": true,
		"desc": "+15% gold from kills.", "mods": {"gold_kill:all": 1.15}},
	{"id": "masonry", "name": "Stonemasons", "rarity": "common", "stack": true,
		"desc": "Repair the gate: +4 castle lives.", "instant": {"lives": 4}},
	{"id": "field_rations", "name": "Field Rations", "rarity": "common", "stack": true,
		"desc": "All units gain +25% max health.", "mods": {"max_hp:all": 1.25}},
	{"id": "quartermaster", "name": "Quartermaster", "rarity": "common", "stack": true,
		"desc": "Upgrades cost 12% less.", "mods": {"upgrade_cost:all": 0.88}},
	{"id": "war_chest", "name": "War Chest", "rarity": "common", "stack": true,
		"desc": "Gain 150 gold now.", "instant": {"gold": 150}},
	{"id": "scavengers", "name": "Scavengers", "rarity": "common", "stack": false,
		"desc": "Selling a soldier refunds 100% of what you spent (instead of 70%).", "flags": ["scavengers"]},
	# ---------------- rare
	{"id": "royal_bounty", "name": "Royal Bounty", "rarity": "rare", "stack": true,
		"desc": "Gain 300 gold now.", "instant": {"gold": 300}},
	{"id": "battle_hymn", "name": "Battle Hymn", "rarity": "rare", "stack": true,
		"desc": "Special abilities recharge 30% faster.", "mods": {"special_cd:all": 0.7}},
	{"id": "fire_arrows", "name": "Fire Arrows", "rarity": "rare", "stack": false, "req": ["archer"],
		"desc": "Archer arrows set enemies on fire.", "flags": ["fire_arrows"]},
	{"id": "barbed_bolts", "name": "Barbed Bolts", "rarity": "rare", "stack": false, "req": ["crossbowman"],
		"desc": "Crossbow bolts pierce 2 more enemies.", "add": {"pierce": 2}},
	{"id": "shield_brothers", "name": "Shield Brothers", "rarity": "rare", "stack": false, "req": ["knight"],
		"desc": "Knights gain +15% damage for each other Knight within 7m (max 3).",
		"flags": ["shield_brothers"]},
	{"id": "storm_conduit", "name": "Storm Conduit", "rarity": "rare", "stack": false, "req": ["battle_mage"],
		"desc": "Arcane bolts chain to 2 more enemies.", "add": {"chain": 2}},
	{"id": "phalanx", "name": "Phalanx", "rarity": "rare", "stack": false, "req": ["spearman", "knight"],
		"desc": "Spearmen deal +35% damage while a Knight stands within 6m.", "flags": ["phalanx"]},
	{"id": "greek_fire", "name": "Greek Fire", "rarity": "rare", "stack": false, "req": ["trebuchet"],
		"desc": "Trebuchet boulders leave burning ground where they land.", "flags": ["greek_fire"]},
	{"id": "recruiting_banner", "name": "Recruiting Banner", "rarity": "rare", "stack": true,
		"desc": "New soldiers cost 15% less.", "mods": {"unit_cost:all": 0.85}},
	{"id": "treasury_interest", "name": "Treasury Interest", "rarity": "rare", "stack": false,
		"desc": "At the end of each wave, earn 10% of your gold (max 150).",
		"flags": ["interest"]},
	{"id": "hawk_eyed", "name": "Hawk-Eyed Scouts", "rarity": "rare", "stack": false,
		"desc": "Units warn allies from 50% farther away and warnings last longer.",
		"flags": ["scouts"]},
	{"id": "martyrs_oath", "name": "Martyr's Oath", "rarity": "rare", "stack": false,
		"desc": "When a soldier is knocked down, allies within 9m attack 35% faster for 6s.",
		"flags": ["martyrs"]},
	{"id": "veterans_resolve", "name": "Veteran's Resolve", "rarity": "rare", "stack": false,
		"desc": "Every kill gives that soldier +2% damage (up to +40%).", "flags": ["veterans"]},
	{"id": "bounty_hunters", "name": "Bounty Hunters", "rarity": "rare", "stack": false,
		"desc": "Orcs, Trolls and Dragons pay double gold.", "flags": ["bounty"]},
	{"id": "lucky_charm", "name": "Lucky Horseshoe", "rarity": "rare", "stack": false,
		"desc": "Your first reroll in every draft is free.", "flags": ["lucky"]},
	{"id": "legend_grows", "name": "The Legend Grows", "rarity": "rare", "stack": true, "req": ["hero"],
		"desc": "Your hero gains 2 levels now.", "hero_levels": 2},
	{"id": "heroic_banner", "name": "Hero's Banner", "rarity": "rare", "stack": false, "req": ["hero"],
		"desc": "Your hero's aura is 50% stronger and reaches 30% farther.", "add": {"aura_power": 0.5, "aura_radius": 0.3}},
	# ---------------- legendary
	{"id": "dragonsbane", "name": "Dragonsbane", "rarity": "legendary", "stack": false,
		"desc": "+50% damage against Trolls and Dragons.", "flags": ["dragonsbane"]},
	{"id": "kings_guard", "name": "King's Guard", "rarity": "legendary", "stack": false, "req": ["archer", "knight"],
		"desc": "Archers covered by a Knight attack 35% faster (instead of 15%).",
		"flags": ["kings_guard"]},
	{"id": "inferno", "name": "Inferno", "rarity": "legendary", "stack": false, "req": ["torch_thrower"],
		"desc": "Torch blasts are 40% larger and Fire Patches last twice as long.",
		"mods": {"radius:torch_thrower": 1.4}, "flags": ["inferno"]},
	{"id": "divine_favor", "name": "Divine Favor", "rarity": "legendary", "stack": false,
		"desc": "+8 castle lives now, and +1 life every wave you clear.",
		"instant": {"lives": 8}, "flags": ["divine_favor"]},
	{"id": "last_stand", "name": "Last Stand", "rarity": "legendary", "stack": false,
		"desc": "While the castle has 10 lives or fewer, soldiers deal +50% damage and attack 20% faster.",
		"flags": ["last_stand"]},
	{"id": "royal_favor", "name": "Royal Favor", "rarity": "legendary", "stack": false,
		"desc": "Every future draft offers 4 choices instead of 3.", "flags": ["four_choices"]},
	{"id": "zealots", "name": "Order of Zealots", "rarity": "legendary", "stack": false, "req": ["cleric"],
		"desc": "Cleric blessings give +30% damage (instead of +12%).", "flags": ["zealots"]},
	{"id": "heros_gambit", "name": "Hero's Gambit", "rarity": "legendary", "stack": false, "req": ["hero"],
		"desc": "Your hero deals +60% damage and their special recharges twice as fast.",
		"mods": {"damage:hero": 1.6, "special_cd:hero": 0.5}},
	# ---------------- cursed pacts (strong upside, real downside)
	{"id": "blood_pact", "name": "Blood Pact", "rarity": "cursed", "stack": false,
		"desc": "All units deal +35% damage. Lose 5 castle lives.",
		"mods": {"damage:all": 1.35}, "instant": {"lives": -5}},
	{"id": "mercenary_debt", "name": "Mercenary Debt", "rarity": "cursed", "stack": false,
		"desc": "Gain 450 gold now. Enemies have +15% health for the rest of the run.",
		"instant": {"gold": 450}, "mods": {"enemy_hp:all": 1.15}},
	{"id": "reckless_haste", "name": "Reckless Haste", "rarity": "cursed", "stack": false,
		"desc": "All units attack 25% faster, but take 60% more damage.",
		"mods": {"attack_speed:all": 1.25, "damage_taken:all": 1.6}},
	{"id": "glass_cannon", "name": "Glass Cannon", "rarity": "cursed", "stack": false,
		"desc": "All units deal +50% damage, but have 40% less health.",
		"mods": {"damage:all": 1.5, "max_hp:all": 0.6}},
	{"id": "devils_bargain", "name": "Devil's Bargain", "rarity": "cursed", "stack": false,
		"desc": "Gain a random Legendary boon. Lose 8 castle lives.",
		"instant": {"lives": -8}, "grant": "legendary"},
	{"id": "forced_march", "name": "Forced March", "rarity": "cursed", "stack": false,
		"desc": "Enemies move 15% faster for the rest of the run, but kills pay +40% gold.",
		"mods": {"enemy_speed:all": 1.15, "gold_kill:all": 1.4}},
	{"id": "greed", "name": "Pact of Greed", "rarity": "cursed", "stack": false,
		"desc": "Kills pay +50% gold, but new soldiers cost 20% more.",
		"mods": {"gold_kill:all": 1.5, "unit_cost:all": 1.2}},
]

## Crossroads events: sometimes a wave ends with a story choice instead of a
## normal draft. Every option is a boon-like dictionary; extra keys:
##   cost (gold, the option is disabled if you can't pay), grant (random boon of
##   that rarity), gamble {chance, win, lose}, forced_omen, hero_levels,
##   keep (true = stays in the boon list; otherwise the option is a one-off).
const EVENTS := [
	{"id": "merchant", "title": "THE WANDERING MERCHANT",
		"text": "A hooded peddler spreads strange relics on a cloth beside the road.",
		"options": [
			{"id": "ev_buy_relic", "name": "Buy a Relic", "cost": 180, "grant": "rare",
				"desc": "Pay 180 gold for a random Rare boon."},
			{"id": "ev_buy_jewel", "name": "Buy the Crown Jewel", "cost": 420, "grant": "legendary",
				"desc": "Pay 420 gold for a random Legendary boon."},
			{"id": "ev_buy_relic_true", "name": "Buy a True Relic", "cost": 380, "grant_relic": true,
				"desc": "Pay 380 gold for a random Relic (a run-changing item)."},
			{"id": "ev_rob", "name": "Rob Him", "instant": {"gold": 250, "lives": -3},
				"desc": "Take his purse (+250 gold). His guards fight back: lose 3 lives."},
		]},
	{"id": "shrine", "title": "THE FORGOTTEN SHRINE",
		"text": "Your scouts find an old shrine in the woods, still warm with candle smoke.",
		"options": [
			{"id": "ev_pray", "name": "Pray", "instant": {"lives": 5},
				"desc": "The gods listen. +5 castle lives."},
			{"id": "ev_offering", "name": "Leave an Offering", "cost": 120, "grant": "rare",
				"desc": "Pay 120 gold for a random Rare boon."},
			{"id": "ev_desecrate", "name": "Desecrate It", "keep": true, "rarity": "cursed",
				"instant": {"gold": 350}, "mods": {"enemy_hp:all": 1.08},
				"desc": "Strip the gold (+350). Enemies have +8% health for the rest of the run."},
		]},
	{"id": "map", "title": "THE DRAGON'S MAP",
		"text": "A dying goblin clutches a map to a war camp's treasure. The camp is on the move.",
		"options": [
			{"id": "ev_raid", "name": "Raid the Camp", "instant": {"gold": 550}, "forced_omen": "horde",
				"desc": "+550 gold now, but the next wave is a Horde (30% more enemies)."},
			{"id": "ev_sell_map", "name": "Sell the Map", "instant": {"gold": 150},
				"desc": "A merchant pays 150 gold for it. No risk."},
		]},
	{"id": "forge", "title": "THE DWARVEN FORGE",
		"text": "Travelling dwarf smiths set up their anvils behind your lines.",
		"options": [
			{"id": "ev_reforge", "name": "Reforge Weapons", "cost": 200, "keep": true, "rarity": "rare",
				"mods": {"damage:all": 1.12}, "desc": "Pay 200 gold: all soldiers deal +12% damage."},
			{"id": "ev_ledger", "name": "Buy Their Ledger", "cost": 150, "keep": true, "rarity": "rare",
				"mods": {"upgrade_cost:all": 0.8}, "desc": "Pay 150 gold: upgrades cost 20% less."},
			{"id": "ev_melt", "name": "Sell Them Scrap", "instant": {"gold": 220},
				"desc": "+220 gold."},
		]},
	{"id": "gambler", "title": "THE GAMBLER'S TABLE",
		"text": "A mercenary captain rattles a pair of bone dice. \"Double or nothing, commander?\"",
		"options": [
			{"id": "ev_dice", "name": "Roll for Gold", "gamble": {"chance": 0.5, "win": {"gold": 500}, "lose": {"gold": -200}},
				"desc": "50%: win 500 gold.  50%: lose 200 gold."},
			{"id": "ev_dice_lives", "name": "Bet the Walls", "gamble": {"chance": 0.5, "win": {"grant": "legendary"}, "lose": {"lives": -5}},
				"desc": "50%: a random Legendary boon.  50%: lose 5 castle lives."},
			{"id": "ev_walk", "name": "Walk Away", "desc": "Keep your coin. Nothing happens."},
		]},
	{"id": "deserters", "title": "DESERTERS AT THE GATE",
		"text": "Three soldiers who ran from the last battle beg to be let back in.",
		"options": [
			{"id": "ev_pardon", "name": "Pardon Them", "instant": {"lives": 2}, "grant": "common",
				"desc": "They man the walls again: +2 lives and a random Common boon."},
			{"id": "ev_example", "name": "Make an Example", "keep": true, "rarity": "cursed",
				"instant": {"lives": -2}, "mods": {"attack_speed:all": 1.1},
				"desc": "Harsh discipline: all soldiers attack 10% faster. Lose 2 lives."},
			{"id": "ev_turn_away", "name": "Turn Them Away", "instant": {"gold": 80},
				"desc": "Keep their pay: +80 gold."},
		]},
	{"id": "bard", "title": "A BARD'S BALLAD", "req": ["hero"],
		"text": "A travelling bard wants to write a song about your hero's deeds.",
		"options": [
			{"id": "ev_tale", "name": "Tell the Tale", "hero_levels": 2,
				"desc": "Your hero gains 2 levels."},
			{"id": "ev_ballad", "name": "Fund a Grand Ballad", "cost": 250, "hero_levels": 4,
				"desc": "Pay 250 gold: your hero gains 4 levels."},
		]},
]

const OMENS := [
	{"id": "swift", "name": "Omen: Swift Feet", "desc": "Enemies move 25% faster. Kills pay +30% gold.",
		"speed": 1.25, "gold": 1.3, "hp": 1.0, "count": 1.0},
	{"id": "ironhide", "name": "Omen: Ironhide", "desc": "Enemies have +30% health. Kills pay +35% gold.",
		"speed": 1.0, "gold": 1.35, "hp": 1.3, "count": 1.0},
	{"id": "horde", "name": "Omen: The Horde", "desc": "30% more enemies this wave. Wave bonus doubled.",
		"speed": 1.0, "gold": 1.0, "hp": 1.0, "count": 1.3, "bonus": 2.0},
	{"id": "blood_moon", "name": "Omen: Blood Moon", "desc": "Enemies have +15% health and speed. Kills pay +50% gold.",
		"speed": 1.15, "gold": 1.5, "hp": 1.15, "count": 1.0},
]

var active: Array = []          ## picked boon dictionaries (duplicates allowed for stackables)
var current_omen: Dictionary = {}
var current_options: Array = []
var current_event: Dictionary = {}   ## non-empty while a crossroads event is on screen
var rerolls: int = 0
var free_rerolls_left: int = 0
var draft_free_reroll: bool = false  ## Lucky Horseshoe
var forced_omen: String = ""
var relics: Array = []              ## relic dictionaries owned this run
var relic_pending: int = 0          ## relic choices earned (elites) not yet taken
var relic_options: Array = []
var phoenix_used: bool = false
var lantern_kills: int = 0
var echo_used_wave: int = -1
var last_draft_was_event: bool = false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	EventBus.unit_downed.connect(_on_unit_downed)
	EventBus.elite_killed.connect(_on_elite_killed)
	EventBus.enemy_killed.connect(_on_enemy_killed_relics)
	EventBus.wave_started.connect(_on_wave_started_relics)
	EventBus.special_used.connect(_on_special_used_relics)


func reset() -> void:
	active.clear()
	current_omen = {}
	current_options.clear()
	current_event = {}
	rerolls = 0
	free_rerolls_left = Profile.free_rerolls()
	draft_free_reroll = false
	forced_omen = ""
	last_draft_was_event = false
	relics.clear()
	relic_pending = 0
	relic_options.clear()
	phoenix_used = false
	lantern_kills = 0
	echo_used_wave = -1
	if GameManager.mode == "challenge":
		rng.seed = Profile.daily_challenge_salt() * 7 + 13   # daily run: everyone sees the same offers
	else:
		rng.randomize()
	EventBus.omen_changed.emit(current_omen)


# ------------------------------------------------------------------ queries
func get_mult(stat: String, unit_type: String = "all") -> float:
	var m := Profile.armory_mult(stat, unit_type)
	var k_all := stat + ":all"
	var k_type := stat + ":" + unit_type
	for b in active:
		var mods: Dictionary = b.get("mods", {})
		if mods.has(k_all):
			m *= float(mods[k_all])
		if unit_type != "all" and mods.has(k_type):
			m *= float(mods[k_type])
	return m


## Product of one exact mod key (e.g. "damage:hero"), without the ":all" mods.
func get_mult_key(key: String) -> float:
	var m := 1.0
	for b in active:
		var mods: Dictionary = b.get("mods", {})
		if mods.has(key):
			m *= float(mods[key])
	return m


func get_add(stat: String) -> float:
	var v := 0.0
	for b in active:
		var adds: Dictionary = b.get("add", {})
		if adds.has(stat):
			v += float(adds[stat])
	return v


func has_flag(flag: String) -> bool:
	for b in active:
		if flag in b.get("flags", []):
			return true
	return false


func owns(id: String) -> bool:
	for b in active:
		if b["id"] == id:
			return true
	return false


func count_owned(id: String) -> int:
	var c := 0
	for b in active:
		if b["id"] == id:
			c += 1
	return c


func omen_value(key: String, default_value: float = 1.0) -> float:
	if current_omen.is_empty():
		return default_value
	return float(current_omen.get(key, default_value))


## Global multiplier applied to enemy max HP (curses + omen).
func enemy_hp_mult() -> float:
	return get_mult("enemy_hp") * omen_value("hp") * float(GameManager.difficulty_def()["hp"]) * (1.25 if GameManager.heat_has("ironhide") else 1.0)


## True when everything a boon/event needs is available this run: the soldier
## classes it buffs must be unlocked, and "hero" needs a hero in this run.
func requirements_met(b: Dictionary) -> bool:
	for r in b.get("req", []):
		if r == "hero":
			if GameManager.hero_id == "":
				return false
		elif not Profile.is_unit_unlocked(r):
			return false
	return true


## Boons for soldiers you actually have on the field are twice as likely.
func _weight(b: Dictionary) -> float:
	var req: Array = b.get("req", [])
	if req.is_empty():
		return 1.0
	var um = GameManager.unit_manager
	if um == null:
		return 1.0
	for r in req:
		if r == "hero":
			if is_instance_valid(GameManager.hero_unit):
				return 2.0
		elif um.count_type(r) > 0:
			return 2.0
	return 1.0


# ------------------------------------------------------------------ drafting
func reroll_cost() -> int:
	if GameManager.heat_has("fixed_fate"):
		return -1
	if free_rerolls_left > 0 or draft_free_reroll:
		return 0
	return 40 + rerolls * 25


func skip_reward() -> int:
	return 60 + 5 * GameManager.wave


func _pool(exclude: Array = []) -> Array:
	var pool: Array = []
	for b in BOONS:
		if not b.get("stack", false) and owns(b["id"]):
			continue
		if not requirements_met(b) or exclude.has(b):
			continue
		pool.append(b)
	return pool


func roll_options(wave_number: int) -> Array:
	var weights := {
		"common": 60.0,
		"rare": 22.0 + wave_number * 2.0,
		"legendary": 4.0 + wave_number * 1.5,
		"cursed": 8.0 if wave_number >= 2 else 0.0,
	}
	var pool := _pool()
	var n_choices := (4 if has_flag("four_choices") else 3) - (1 if GameManager.heat_has("stingy") else 0)
	var picks: Array = []
	var guard := 0
	while picks.size() < n_choices and guard < 200 and pool.size() > 0:
		guard += 1
		var rarity := _roll_rarity(weights)
		var candidates := pool.filter(func(b): return b["rarity"] == rarity and not picks.has(b))
		if candidates.is_empty():
			continue
		picks.append(_weighted_pick(candidates))
	return picks


func _weighted_pick(candidates: Array) -> Dictionary:
	var total := 0.0
	for c in candidates:
		total += _weight(c)
	var r := rng.randf() * total
	for c in candidates:
		r -= _weight(c)
		if r <= 0.0:
			return c
	return candidates[candidates.size() - 1]


func _roll_rarity(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return "common"


## A random boon of one rarity that this run can use (for relic grants).
func random_boon(rarity: String) -> Dictionary:
	var candidates := _pool().filter(func(b): return b["rarity"] == rarity and not b.has("grant"))
	if candidates.is_empty():
		candidates = _pool().filter(func(b): return b["rarity"] == "rare")
	if candidates.is_empty():
		return {}
	return _weighted_pick(candidates)


func _roll_event(wave_number: int) -> Dictionary:
	if wave_number < 3 or last_draft_was_event:
		return {}
	if WaveDefs.count() > 0 and wave_number >= WaveDefs.count() - 1:
		return {}
	if rng.randf() > 0.3:
		return {}
	var evs: Array = EVENTS.filter(func(e): return requirements_met(e))
	if evs.is_empty():
		return {}
	var ev: Dictionary = evs[rng.randi() % evs.size()].duplicate(true)
	for o in ev["options"]:
		o["rarity"] = o.get("rarity", "event")
		o["event"] = true
	return ev


func open_draft(wave_number: int) -> void:
	draft_free_reroll = has_flag("lucky")
	current_event = _roll_event(wave_number)
	last_draft_was_event = not current_event.is_empty()
	if current_event.is_empty():
		current_options = roll_options(wave_number)
	else:
		current_options = current_event["options"]
	EventBus.boon_draft_opened.emit(current_options)


func reroll(wave_number: int) -> bool:
	if not current_event.is_empty():
		return false
	var cost := reroll_cost()
	if cost < 0:
		return false
	if cost == 0:
		if draft_free_reroll:
			draft_free_reroll = false
		else:
			free_rerolls_left -= 1
	elif not EconomyManager.spend(cost):
		return false
	else:
		rerolls += 1
	var lucky_left := draft_free_reroll
	current_options = roll_options(wave_number)
	draft_free_reroll = lucky_left
	EventBus.boon_draft_opened.emit(current_options)
	return true


## Pass on the draft for a little gold.
func skip() -> void:
	var g := skip_reward()
	EconomyManager.add(g)
	current_options.clear()
	current_event = {}
	var b := {"id": "skip", "name": "Pillage", "rarity": "common", "desc": "+%d gold" % g, "event": true}
	EventBus.feed_message.emit("Spoils of War", "You took %d gold instead of a boon." % g, UiTheme.GOLD)
	EventBus.boon_picked.emit(b)


func can_pick(b: Dictionary) -> bool:
	return EconomyManager.can_afford(int(b.get("cost", 0)))


func pick(boon: Dictionary) -> void:
	if not can_pick(boon):
		return
	if boon.get("relic", false) and not boon.has("cost"):
		# relic chest choice
		grant_relic(boon)
		relic_pending = max(0, relic_pending - 1)
		current_options.clear()
		current_event = {}
		EventBus.relic_picked_continue.emit()
		return
	var cost := int(boon.get("cost", 0))
	if cost > 0:
		EconomyManager.spend(cost)
	var is_event := bool(boon.get("event", false))
	if not is_event or boon.get("keep", false):
		active.append(boon)
	_apply_effects(boon)
	current_options.clear()
	current_event = {}
	EventBus.boon_picked.emit(boon)
	EventBus.feed_message.emit("Spoils of War", "%s - %s" % [boon["name"], boon["desc"]],
		RARITY_COLORS.get(boon["rarity"], Color.WHITE))


func _apply_effects(b: Dictionary) -> void:
	var inst: Dictionary = b.get("instant", {})
	if inst.has("gold"):
		_change_gold(int(inst["gold"]))
	if inst.has("lives"):
		_change_lives(int(inst["lives"]))
	if b.has("hero_levels"):
		_hero_levels(int(b["hero_levels"]))
	if b.has("forced_omen"):
		forced_omen = String(b["forced_omen"])
	if b.has("grant"):
		_grant(String(b["grant"]))
	if b.get("grant_relic", false):
		var rs := roll_relics(1)
		if rs.is_empty():
			EconomyManager.add(200)
		else:
			grant_relic(rs[0])
	if b.has("gamble"):
		var g: Dictionary = b["gamble"]
		var won := rng.randf() < float(g.get("chance", 0.5))
		var outcome: Dictionary = g["win"] if won else g["lose"]
		EventBus.banner.emit("THE DICE LAND...", "You win!" if won else "You lose.", UiTheme.GREEN if won else UiTheme.RED)
		if outcome.has("gold"):
			_change_gold(int(outcome["gold"]))
		if outcome.has("lives"):
			_change_lives(int(outcome["lives"]))
		if outcome.has("grant"):
			_grant(String(outcome["grant"]))


func _change_gold(n: int) -> void:
	if n >= 0:
		EconomyManager.add(n)
	else:
		EconomyManager.spend(min(-n, EconomyManager.gold))


func _change_lives(n: int) -> void:
	if n >= 0:
		GameManager.add_lives(n)
	else:
		GameManager.lose_lives(-n)


func _grant(rarity: String) -> void:
	var g := random_boon(rarity)
	if g.is_empty():
		EconomyManager.add(200)
		return
	active.append(g)
	_apply_effects(g)
	EventBus.feed_message.emit("Spoils of War", "Gained %s - %s" % [g["name"], g["desc"]],
		RARITY_COLORS.get(g["rarity"], Color.WHITE))


func _hero_levels(n: int) -> void:
	if is_instance_valid(GameManager.hero_unit):
		GameManager.hero_unit.gain_levels(n)
	else:
		GameManager.hero_bonus_levels += n


func _on_unit_downed(u) -> void:
	if not has_flag("martyrs") or GameManager.unit_manager == null:
		return
	for a in GameManager.unit_manager.units_near(u.global_position, 9.0):
		if a != u:
			a.rally_timer = 6.0


# ------------------------------------------------------------------ relics
func has_relic(id: String) -> bool:
	for r in relics:
		if r["id"] == id:
			return true
	return false


func _relic_pool() -> Array:
	return RELICS.filter(func(r): return not has_relic(r["id"]) and requirements_met(r))


func roll_relics(n: int) -> Array:
	var pool := _relic_pool()
	var out: Array = []
	while out.size() < n and not pool.is_empty():
		var r: Dictionary = pool[rng.randi() % pool.size()]
		pool.erase(r)
		var rr := r.duplicate()
		rr["rarity"] = "relic"
		rr["relic"] = true
		out.append(rr)
	return out


func _on_elite_killed(_e) -> void:
	if not _relic_pool().is_empty():
		relic_pending += 1
		EventBus.feed_message.emit("Spoils of War", "The elite dropped a relic chest! Claim it after the wave.", RARITY_COLORS["relic"])


## Opens a relic choice (1 of 2). Returns false when there is nothing to offer.
func open_relic_draft() -> bool:
	relic_options = roll_relics(2)
	if relic_options.is_empty():
		relic_pending = 0
		return false
	current_event = {"title": "A RELIC!", "text": "The elite carried something precious. Choose one relic: it lasts for the rest of this battle.", "relic": true}
	current_options = relic_options
	EventBus.boon_draft_opened.emit(current_options)
	return true


func grant_relic(r: Dictionary) -> void:
	var rr := r.duplicate()
	rr["rarity"] = "relic"
	rr["relic"] = true
	relics.append(rr)
	EventBus.relic_gained.emit(rr)
	EventBus.feed_message.emit("Relic", "%s - %s" % [rr["name"], rr["desc"]], RARITY_COLORS["relic"])


func _on_enemy_killed_relics(e, killer) -> void:
	if has_relic("soul_lantern"):
		lantern_kills += 1
		if lantern_kills >= 40:
			lantern_kills = 0
			GameManager.add_lives(1)
			EventBus.feed_message.emit("Soul Lantern", "+1 castle life.", RARITY_COLORS["relic"])
	if has_relic("bloodstone") and is_instance_valid(killer) and killer is FriendlyUnit:
		var fu := killer as FriendlyUnit
		if not fu.downed:
			fu.hp = min(fu.get_max_hp(), fu.hp + fu.get_max_hp() * 0.04)
	var _unused = e


func _on_wave_started_relics(_n: int) -> void:
	var um = GameManager.unit_manager
	if um == null:
		return
	for u in um.units:
		if has_relic("horn_valor"):
			u.valor_timer = 8.0
		if has_relic("hourglass"):
			u.special_cd = 0.0


func _on_special_used_relics(u) -> void:
	if not has_relic("echo_mirror") or echo_used_wave == GameManager.wave or not is_instance_valid(u):
		return
	echo_used_wave = GameManager.wave
	get_tree().create_timer(0.6, false).timeout.connect(_echo.bind(u))


func _echo(u) -> void:
	if is_instance_valid(u) and not u.downed:
		u._use_special()
		FX.magic_ring(u.global_position, RARITY_COLORS["relic"], 1.6)
		EventBus.feed_message.emit("Mirror of Echoes", "%s's special echoes!" % u.display_name, RARITY_COLORS["relic"])


## Called after the draft to decide whether the next wave carries an omen.
func roll_omen(next_wave: int) -> void:
	current_omen = {}
	if forced_omen != "":
		for o in OMENS:
			if o["id"] == forced_omen:
				current_omen = o
		forced_omen = ""
	else:
		var chance := 1.0 if (GameManager.mode == "challenge" or GameManager.heat_has("omens")) else 0.45
		if next_wave >= 3 and not WaveDefs.is_boss_wave(next_wave) and rng.randf() < chance:
			current_omen = OMENS[rng.randi() % OMENS.size()]
	EventBus.omen_changed.emit(current_omen)


func clear_omen() -> void:
	current_omen = {}
	EventBus.omen_changed.emit(current_omen)
