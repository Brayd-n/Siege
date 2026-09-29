class_name EnemyDefs
extends RefCounted
## Static balance data for enemies.
## resist maps Damage.Type -> damage multiplier (lower = more resistant).

const DATA := {
	"goblin": {
		"name": "Goblin", "hp": 45.0, "speed": 3.2, "reward": 10, "lives": 1, "armor": 0.0,
		"heavy": false, "contact": 4.0, "contact_range": 1.9, "resist": {},
	},
	"goblin_archer": {
		"name": "Goblin Archer", "hp": 85.0, "speed": 2.6, "reward": 14, "lives": 1, "armor": 0.0,
		"heavy": false, "contact": 3.0, "contact_range": 1.9, "resist": {},
	},
	"wolf_rider": {
		"name": "Wolf Rider", "hp": 85.0, "speed": 5.4, "reward": 15, "lives": 1, "armor": 0.0,
		"heavy": false, "contact": 6.0, "contact_range": 2.1, "resist": {},
	},
	"shaman": {
		"name": "Goblin Shaman", "hp": 120.0, "speed": 2.4, "reward": 18, "lives": 1, "armor": 0.0,
		"heavy": false, "contact": 3.0, "contact_range": 1.9, "resist": {Damage.Type.ARCANE: 0.7},
	},
	"orc": {
		"name": "Orc", "hp": 240.0, "speed": 2.2, "reward": 25, "lives": 2, "armor": 0.3,
		"heavy": true, "contact": 12.0, "contact_range": 2.2, "resist": {},
	},
	"troll": {
		"name": "Troll", "hp": 1000.0, "speed": 1.8, "reward": 75, "lives": 3, "armor": 0.1,
		"heavy": true, "contact": 28.0, "contact_range": 2.9,
		"resist": {Damage.Type.NORMAL: 0.5, Damage.Type.PIERCING: 1.0, Damage.Type.FIRE: 1.5},
	},
	"dragon": {
		"name": "Dragon", "hp": 16000.0, "speed": 1.55, "reward": 500, "lives": 10, "armor": 0.15,
		"heavy": true, "contact": 0.0, "contact_range": 0.0,
		"resist": {Damage.Type.NORMAL: 0.85, Damage.Type.FIRE: 0.5},
		"boss": true, "title": "Ashmaw the Red",
		"desc": "A red dragon. Flies over the road, so only ranged soldiers can hit it, and breathes fire on anyone close.",
		"counter": "Every ranged soldier. Dragonsbane.",
	},
	# ---------------------------------------------------------------- new enemies
	"shieldbearer": {
		"name": "Shieldbearer", "hp": 150.0, "speed": 2.3, "reward": 16, "lives": 1, "armor": 0.25,
		"heavy": false, "contact": 8.0, "contact_range": 2.0, "resist": {},
		"desc": "Hobgoblin behind a tower shield. Arrows from the front mostly bounce off.",
		"counter": "Crossbowmen (bolts punch through), Battle Mages, fire, or melee.",
	},
	"sapper": {
		"name": "Goblin Sapper", "hp": 55.0, "speed": 3.9, "reward": 14, "lives": 1, "armor": 0.0,
		"heavy": false, "contact": 0.0, "contact_range": 0.0, "resist": {},
		"desc": "Carries a lit powder keg. Leaves the road to charge the nearest soldier and blows up. If you shoot it first, the keg blows up its friends instead.",
		"counter": "Long range: Crossbowmen, Trebuchets, Longbowmen. Kill it inside a crowd.",
	},
	"bat": {
		"name": "Cave Bat", "hp": 28.0, "speed": 5.2, "reward": 4, "lives": 1, "armor": 0.0,
		"heavy": false, "contact": 0.0, "contact_range": 0.0, "resist": {},
		"desc": "Fast flying swarm. Melee soldiers, Torch Throwers and Trebuchets can't hit flyers.",
		"counter": "Battle Mages (chains), Archers, Rangers.",
	},
	"necromancer": {
		"name": "Necromancer", "hp": 190.0, "speed": 2.0, "reward": 30, "lives": 2, "armor": 0.0,
		"heavy": false, "contact": 3.0, "contact_range": 1.9, "resist": {Damage.Type.ARCANE: 0.8},
		"desc": "Raises fallen goblins as skeletons. The longer it lives, the bigger the horde.",
		"counter": "Clerics deal double damage to the dead. Focus the necromancer first.",
	},
	"skeleton": {
		"name": "Skeleton", "hp": 40.0, "speed": 2.9, "reward": 2, "lives": 1, "armor": 0.1,
		"heavy": false, "contact": 4.0, "contact_range": 1.9, "undead": true,
		"resist": {Damage.Type.NORMAL: 0.8, Damage.Type.PIERCING: 0.6, Damage.Type.FIRE: 1.2},
		"desc": "Raised dead. Arrows slip between the ribs.",
		"counter": "Clerics and Paladins (double damage), fire, Knights.",
	},
	# ---------------------------------------------------------------- bosses
	"warlord": {
		"name": "Goblin Warlord", "title": "Grukk the Warlord", "boss": true,
		"hp": 2600.0, "speed": 1.7, "reward": 300, "lives": 8, "armor": 0.25,
		"heavy": true, "contact": 22.0, "contact_range": 2.6, "resist": {},
		"desc": "Blows a war horn that makes nearby goblins faster and tougher, and calls in reinforcements.",
		"counter": "Kill the goblins around him first, or burst him down with specials.",
	},
	"siege_troll": {
		"name": "Siege Troll", "title": "Old Mossback", "boss": true,
		"hp": 5200.0, "speed": 1.45, "reward": 400, "lives": 10, "armor": 0.15,
		"heavy": true, "contact": 35.0, "contact_range": 3.4,
		"resist": {Damage.Type.NORMAL: 0.5, Damage.Type.PIERCING: 1.0, Damage.Type.FIRE: 1.4},
		"desc": "Rips boulders out of the ground and hurls them at your soldiers, stunning them.",
		"counter": "Spread your soldiers out. Crossbows and fire.",
	},
	"riverbane": {
		"name": "River Troll", "title": "Riverbane", "boss": true,
		"hp": 6000.0, "speed": 1.4, "reward": 450, "lives": 10, "armor": 0.15,
		"heavy": true, "contact": 35.0, "contact_range": 3.4,
		"resist": {Damage.Type.NORMAL: 0.5, Damage.Type.PIERCING: 1.0, Damage.Type.FIRE: 1.5},
		"desc": "Regenerates quickly, even faster near water. Fire stops the healing.",
		"counter": "Keep it burning: Torch Throwers, Fire Arrows, Greek Fire.",
	},
	"hollow_king": {
		"name": "Hollow King", "title": "The Hollow King", "boss": true, "undead": true,
		"hp": 4200.0, "speed": 1.6, "reward": 400, "lives": 10, "armor": 0.1,
		"heavy": true, "contact": 18.0, "contact_range": 2.4, "resist": {Damage.Type.NORMAL: 0.75},
		"desc": "Lord of the dead. Raises every fallen goblin near him and becomes untouchable at 66% and 33% health while his bone guard rises.",
		"counter": "Clerics and Paladins. Save area damage for the skeleton waves.",
	},
	"shade": {
		"name": "Shade", "title": "The Night Shade", "boss": true, "undead": true,
		"hp": 3600.0, "speed": 1.9, "reward": 420, "lives": 10, "armor": 0.0,
		"heavy": true, "contact": 16.0, "contact_range": 2.2, "resist": {Damage.Type.NORMAL: 0.7, Damage.Type.ARCANE: 1.3},
		"desc": "A ghost that blinks ahead along the road and calls bats. Only visible in the light.",
		"counter": "Light the road: Torch Throwers and burning ground. Battle Mages.",
	},
	"frost_wyrm": {
		"name": "Frost Wyrm", "title": "Frost Wyrm", "boss": true,
		"hp": 13500.0, "speed": 1.6, "reward": 500, "lives": 10, "armor": 0.15,
		"heavy": true, "contact": 0.0, "contact_range": 0.0,
		"resist": {Damage.Type.NORMAL: 0.85, Damage.Type.FIRE: 1.35},
		"desc": "Ice dragon. Its breath freezes soldiers solid for a few seconds.",
		"counter": "Fire! Torch Throwers and Fire Arrows deal extra damage.",
	},
	"elder_dragon": {
		"name": "Elder Dragon", "title": "Vyraxis the Elder", "boss": true,
		"hp": 23000.0, "speed": 1.45, "reward": 800, "lives": 15, "armor": 0.2,
		"heavy": true, "contact": 0.0, "contact_range": 0.0,
		"resist": {Damage.Type.NORMAL: 0.8, Damage.Type.FIRE: 0.4},
		"desc": "The oldest dragon. Summons bat swarms and goes berserk at half health.",
		"counter": "Everything you have. Save specials for the second half.",
	},
}

## Descriptions/counters for the original roster (shown in the Codex).
const LORE := {
	"goblin": ["Weak, fast and everywhere.", "Anything. Archers and Torch Throwers clear crowds."],
	"goblin_archer": ["Shoots back at soldiers it walks past.", "Knights and Spearmen shrug off arrows. Kill from range."],
	"wolf_rider": ["Very fast cavalry.", "Spearmen (x1.8 damage) and Brace."],
	"shaman": ["Heals nearby enemies every few seconds.", "Focus it first. Crossbowmen and Mages."],
	"orc": ["Armoured brute.", "Crossbowmen and Mages ignore most of its armour."],
	"troll": ["Huge and shrugs off normal hits.", "Piercing and fire."],
}


static func is_boss(type: String) -> bool:
	return bool(get_def(type).get("boss", false))


static func desc(type: String) -> String:
	var d := get_def(type)
	if d.has("desc"):
		return d["desc"]
	return LORE.get(type, ["", ""])[0]


static func counter(type: String) -> String:
	var d := get_def(type)
	if d.has("counter"):
		return d["counter"]
	return LORE.get(type, ["", ""])[1]


const ORDER: Array[String] = ["goblin", "goblin_archer", "wolf_rider", "shaman", "orc", "troll", "shieldbearer",
	"sapper", "bat", "necromancer", "skeleton", "warlord", "siege_troll", "hollow_king", "frost_wyrm", "dragon",
	"elder_dragon", "riverbane", "shade"]


static func get_def(type: String) -> Dictionary:
	return DATA.get(type, {})
