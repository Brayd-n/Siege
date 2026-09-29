class_name UnitDefs
extends RefCounted
## Static balance data for every friendly unit class.
## "paths" are the three upgrade tracks shown in the unit panel.
## stat values: damage / range / speed / max_hp / radius are multiplicative (per tier),
## pierce is additive (+per per tier).

const ORDER: Array[String] = ["archer", "knight", "crossbowman", "torch_thrower", "spearman", "battle_mage", "cleric", "trebuchet"]
const MAX_TIER := 2
const SELL_RATE := 0.7

const DATA := {
	"archer": {
		"name": "Archer",
		"cost": 150,
		"hp": 80.0,
		"damage": 13.0,
		"range": 11.0,
		"interval": 0.75,
		"dtype": Damage.Type.NORMAL,
		"color": Color(0.18, 0.42, 0.2),
		"role": "Fast, reliable ranged damage.",
		"paths": [
			{"name": "Sharper Arrows", "stat": "damage", "per": 0.35, "costs": [100, 170]},
			{"name": "Longbow", "stat": "range", "per": 0.18, "costs": [100, 150]},
			{"name": "Quick Draw", "stat": "speed", "per": 0.25, "costs": [150, 220]},
		],
		"special": {"name": "Volley", "cd": 25.0, "duration": 5.0,
			"desc": "Fires three times faster for 5 seconds."},
	},
	"knight": {
		"name": "Knight",
		"cost": 200,
		"hp": 320.0,
		"damage": 30.0,
		"range": 3.4,
		"interval": 1.0,
		"dtype": Damage.Type.NORMAL,
		"color": Color(0.16, 0.24, 0.5),
		"role": "Tough melee guard. Place right beside the road.",
		"paths": [
			{"name": "Keen Blade", "stat": "damage", "per": 0.35, "costs": [120, 190]},
			{"name": "Heavy Plate", "stat": "max_hp", "per": 0.4, "costs": [100, 160]},
			{"name": "Swift Strikes", "stat": "speed", "per": 0.25, "costs": [140, 210]},
		],
		"special": {"name": "Shield Wall", "cd": 30.0, "duration": 8.0,
			"desc": "Knights within 8m deal +50% damage and take half damage for 8s."},
	},
	"crossbowman": {
		"name": "Crossbowman",
		"cost": 250,
		"hp": 90.0,
		"damage": 48.0,
		"range": 15.0,
		"interval": 2.0,
		"dtype": Damage.Type.PIERCING,
		"color": Color(0.45, 0.3, 0.14),
		"role": "Slow, long-range, armor-piercing bolts.",
		"pierce": 1,
		"paths": [
			{"name": "Heavy Bolts", "stat": "damage", "per": 0.4, "costs": [130, 200]},
			{"name": "Barbed Tips", "stat": "pierce", "per": 1.0, "costs": [150, 220]},
			{"name": "Long Stock", "stat": "range", "per": 0.15, "costs": [110, 170]},
		],
		"special": {"name": "Piercing Shot", "cd": 20.0, "duration": 6.0,
			"desc": "For 6s bolts deal +50% damage and pierce up to 6 enemies."},
	},
	"torch_thrower": {
		"name": "Torch Thrower",
		"cost": 300,
		"hp": 90.0,
		"damage": 24.0,
		"range": 10.0,
		"interval": 2.2,
		"dtype": Damage.Type.FIRE,
		"color": Color(0.62, 0.2, 0.08),
		"role": "Explosive area damage that sets enemies ablaze.",
		"radius": 2.8,
		"burn_dps": 8.0,
		"burn_time": 3.0,
		"paths": [
			{"name": "Pitch & Tar", "stat": "damage", "per": 0.35, "costs": [140, 210]},
			{"name": "Bigger Blaze", "stat": "radius", "per": 0.25, "costs": [150, 220]},
			{"name": "Strong Arm", "stat": "range", "per": 0.18, "costs": [120, 180]},
		],
		"special": {"name": "Fire Patch", "cd": 22.0, "duration": 6.0,
			"desc": "Sets the road ablaze for 6s, burning everything that walks through."},
	},
	"spearman": {
		"name": "Spearman",
		"cost": 220,
		"hp": 220.0,
		"damage": 22.0,
		"range": 4.6,
		"interval": 0.9,
		"dtype": Damage.Type.NORMAL,
		"color": Color(0.35, 0.4, 0.22),
		"role": "Long pike: hits two enemies in a line and slows them. Brutal against wolf riders.",
		"cavalry_bonus": 1.8,
		"paths": [
			{"name": "Sharpened Pikes", "stat": "damage", "per": 0.35, "costs": [110, 180]},
			{"name": "Long Pikes", "stat": "range", "per": 0.15, "costs": [100, 160]},
			{"name": "Pike Drill", "stat": "speed", "per": 0.25, "costs": [140, 200]},
		],
		"special": {"name": "Brace", "cd": 24.0, "duration": 2.5,
			"desc": "Plant pikes: every enemy in reach is stopped dead for 2.5s."},
	},
	"battle_mage": {
		"name": "Battle Mage",
		"cost": 350,
		"hp": 70.0,
		"damage": 20.0,
		"range": 12.0,
		"interval": 1.1,
		"dtype": Damage.Type.ARCANE,
		"color": Color(0.3, 0.2, 0.55),
		"role": "Arcane bolts ignore armour and chain to nearby enemies.",
		"chain": 2,
		"paths": [
			{"name": "Arcane Focus", "stat": "damage", "per": 0.35, "costs": [160, 240]},
			{"name": "Chain Lightning", "stat": "chain", "per": 1.0, "costs": [170, 250]},
			{"name": "Far Sight", "stat": "range", "per": 0.18, "costs": [130, 200]},
		],
		"special": {"name": "Frost Nova", "cd": 22.0, "duration": 4.0,
			"desc": "Freezing blast: damages and slows every enemy in range by 60% for 4s."},
	},
	"cleric": {
		"name": "Cleric",
		"cost": 280,
		"hp": 110.0,
		"damage": 9.0,
		"range": 8.0,
		"interval": 1.4,
		"dtype": Damage.Type.ARCANE,
		"color": Color(0.85, 0.8, 0.6),
		"role": "Heals nearby soldiers, blesses them (+12% damage) and gets the fallen back up faster.",
		"heal": 14.0,
		"paths": [
			{"name": "Holy Light", "stat": "heal", "per": 0.45, "costs": [120, 190]},
			{"name": "Sanctuary", "stat": "range", "per": 0.2, "costs": [120, 180]},
			{"name": "Zeal", "stat": "speed", "per": 0.3, "costs": [120, 190]},
		],
		"special": {"name": "Divine Light", "cd": 35.0, "duration": 0.0,
			"desc": "Revives and fully heals every soldier in range and burns nearby enemies."},
	},
	"trebuchet": {
		"name": "Trebuchet",
		"cost": 450,
		"hp": 160.0,
		"damage": 85.0,
		"range": 22.0,
		"interval": 4.5,
		"dtype": Damage.Type.NORMAL,
		"color": Color(0.4, 0.3, 0.2),
		"role": "Huge range siege engine. Slow, crushing area damage. Can't hit flyers or anything too close.",
		"radius": 3.2,
		"min_range": 6.0,
		"paths": [
			{"name": "Heavier Stones", "stat": "damage", "per": 0.35, "costs": [200, 300]},
			{"name": "Counterweight", "stat": "speed", "per": 0.25, "costs": [180, 260]},
			{"name": "Bigger Payload", "stat": "radius", "per": 0.25, "costs": [170, 250]},
		],
		"special": {"name": "Barrage", "cd": 28.0, "duration": 0.0,
			"desc": "Loose five boulders in quick succession at the thickest part of the horde."},
	},
}

## Tier-3 specializations: after 3 upgrade tiers a soldier can pick one of two.
## mods multiply stats (speed = attack speed), flags switch on new behaviour.
const SPEC_UNLOCK_TIERS := 3
const SPECS := {
	"archer": [
		{"id": "ranger", "name": "Ranger", "cost": 380, "color": Color(0.3, 0.6, 0.25),
			"desc": "Looses at up to 3 enemies at once. +15% range, -15% damage per arrow.",
			"mods": {"range": 1.15, "damage": 0.85}, "flags": ["multishot"]},
		{"id": "longbow", "name": "Longbowman", "cost": 400, "color": Color(0.55, 0.4, 0.2),
			"desc": "Huge range (+60%) and +50% damage, fires slower. Double damage to flyers.",
			"mods": {"range": 1.6, "damage": 1.5, "speed": 0.72}, "flags": ["skyhunter"]},
	],
	"knight": [
		{"id": "paladin", "name": "Paladin", "cost": 420, "color": Color(0.95, 0.85, 0.45),
			"desc": "Holy blade: double damage to the undead, heals 5% of max health per hit, +30% health.",
			"mods": {"max_hp": 1.3}, "flags": ["holy", "lifesteal"]},
		{"id": "berserker", "name": "Berserker", "cost": 400, "color": Color(0.7, 0.15, 0.1),
			"desc": "Cleaves up to 3 extra enemies for 80% damage and attacks 40% faster. Takes 25% more damage.",
			"mods": {"speed": 1.4, "damage_taken": 1.25}, "flags": ["cleave"]},
	],
	"crossbowman": [
		{"id": "arbalest", "name": "Arbalest", "cost": 450, "color": Color(0.35, 0.3, 0.3),
			"desc": "Siege crossbow: double damage, slower, and every bolt knocks enemies back.",
			"mods": {"damage": 2.0, "speed": 0.7}, "flags": ["knockback"]},
		{"id": "repeater", "name": "Repeater", "cost": 430, "color": Color(0.6, 0.45, 0.2),
			"desc": "Fires 3-bolt bursts. Each bolt deals 60% damage.",
			"mods": {"damage": 0.6}, "flags": ["burst"]},
	],
	"torch_thrower": [
		{"id": "alchemist", "name": "Alchemist", "cost": 420, "color": Color(0.35, 0.75, 0.3),
			"desc": "Acid flasks melt armour for 5s and slow by 25%. +10% damage.",
			"mods": {"damage": 1.1}, "flags": ["acid"]},
		{"id": "firebomber", "name": "Firebomber", "cost": 440, "color": Color(0.9, 0.35, 0.05),
			"desc": "Blasts 40% larger, and every throw leaves burning ground behind.",
			"mods": {"radius": 1.4}, "flags": ["ground_fire"]},
	],
	"spearman": [
		{"id": "halberdier", "name": "Halberdier", "cost": 380, "color": Color(0.5, 0.5, 0.55),
			"desc": "Wide sweeps hit every enemy in reach in front of them. +20% damage.",
			"mods": {"damage": 1.2}, "flags": ["sweep"]},
		{"id": "pikemaster", "name": "Pikemaster", "cost": 380, "color": Color(0.35, 0.45, 0.25),
			"desc": "+40% reach. Every hit pins the enemy in place for a moment. x2.5 vs wolf riders.",
			"mods": {"range": 1.4}, "flags": ["pin"]},
	],
	"battle_mage": [
		{"id": "stormcaller", "name": "Stormcaller", "cost": 480, "color": Color(0.45, 0.55, 1.0),
			"desc": "Lightning chains to 3 more enemies and briefly stuns each one. +20% damage.",
			"mods": {"damage": 1.2}, "flags": ["storm"], "add": {"chain": 3}},
		{"id": "frost_mage", "name": "Frost Mage", "cost": 460, "color": Color(0.6, 0.9, 1.0),
			"desc": "Every bolt chills (35% slow). Chilled enemies take 25% more damage from everyone's projectiles.",
			"mods": {}, "flags": ["chill"]},
	],
	"cleric": [
		{"id": "high_priest", "name": "High Priest", "cost": 420, "color": Color(1.0, 0.95, 0.75),
			"desc": "Heals twice as much, +30% aura range, and blessings give +20% damage.",
			"mods": {"heal": 2.0, "range": 1.3}, "flags": ["high_bless"]},
		{"id": "inquisitor", "name": "Inquisitor", "cost": 420, "color": Color(0.6, 0.1, 0.1),
			"desc": "Triple damage, sets targets ablaze, and triple damage to the undead. Heals half as much.",
			"mods": {"damage": 3.0, "heal": 0.5}, "flags": ["smite_burn", "holy3"]},
	],
	"trebuchet": [
		{"id": "siege_master", "name": "Siege Master", "cost": 520, "color": Color(0.45, 0.35, 0.25),
			"desc": "+50% blast radius and +30% damage.",
			"mods": {"radius": 1.5, "damage": 1.3}, "flags": []},
		{"id": "fire_trebuchet", "name": "Hellfire Engine", "cost": 520, "color": Color(0.9, 0.3, 0.05),
			"desc": "Flaming boulders leave burning ground and set everything they hit on fire.",
			"mods": {"damage": 1.1}, "flags": ["fire_payload"]},
	],
}


static func get_spec(type: String, spec_id: String) -> Dictionary:
	for sp in SPECS.get(type, []):
		if sp["id"] == spec_id:
			return sp
	return {}


const NAMES: Array[String] = [
	"Aldric", "Rowan", "Cedric", "Roland", "Gareth", "Edmund", "Tristan", "Godfrey", "Elric",
	"Baldwin", "Osric", "Percival", "Leofric", "Wystan", "Aelfric", "Bertram", "Hugo", "Ansel",
	"Merek", "Tobias", "Alaric", "Randolf", "Eamon", "Hollis", "Wendel", "Corwin", "Garrick",
	"Isolde", "Maud", "Elspeth", "Rosamund", "Brienne", "Gwyneth", "Aveline", "Edith", "Matilda",
]

const PERSONALITIES: Array[String] = ["Brave", "Nervous", "Veteran", "Cocky", "Serious", "Friendly"]


static func get_def(type: String) -> Dictionary:
	return DATA.get(type, {})
