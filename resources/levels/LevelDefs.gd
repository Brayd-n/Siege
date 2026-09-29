class_name LevelDefs
extends RefCounted
## Campaign levels (maps), visual themes and difficulty modes.
## Every road starts at the enemy portal on the west edge and ends at the
## castle gate at (49, 11) on the east edge.

const LEVELS := [
	{
		"id": "greenvale", "name": "Greenvale Road", "theme": "summer", "waves": 8, "factor": 0.62,
		"blurb": "A quiet farming road. The goblins think it's undefended.",
		"roster": [["goblin", 1], ["wolf_rider", 4], ["goblin_archer", 5], ["orc", 6]],
		"boss": "warlord", "unlock": "crossbowman",
		"path": [Vector2(-56, -20), Vector2(-44, -20), Vector2(-33, -18), Vector2(-26, -10), Vector2(-26, 0),
			Vector2(-30, 9), Vector2(-24, 18), Vector2(-12, 20), Vector2(-5, 13), Vector2(-6, 2),
			Vector2(-2, -10), Vector2(6, -18), Vector2(16, -17), Vector2(21, -8), Vector2(16, 2),
			Vector2(18, 12), Vector2(27, 16), Vector2(36, 12.5), Vector2(49, 11)],
	},
	{
		"id": "millbrook", "name": "Millbrook Crossing", "theme": "summer", "waves": 10, "factor": 0.78,
		"blurb": "A wide, gentle bend. Orc warbands march in the open.",
		"roster": [["goblin", 1], ["wolf_rider", 3], ["goblin_archer", 4], ["shieldbearer", 5], ["orc", 6], ["troll", 8]],
		"boss": "siege_troll", "unlock": "torch_thrower",
		"path": [Vector2(-56, 2), Vector2(-42, 2), Vector2(-32, -10), Vector2(-17, -18), Vector2(-2, -12),
			Vector2(4, 2), Vector2(14, 16), Vector2(28, 20), Vector2(38, 14), Vector2(49, 11)],
	},
	{
		"id": "autumn", "name": "Autumn Marches", "theme": "autumn", "waves": 12, "factor": 0.88,
		"blurb": "Switchbacks through the red woods. Short sight lines, long road.",
		"roster": [["goblin", 1], ["goblin_archer", 2], ["wolf_rider", 3], ["orc", 4], ["sapper", 5], ["shieldbearer", 6], ["troll", 7], ["shaman", 8], ["necromancer", 9]],
		"boss": "hollow_king", "unlock": "spearman",
		"path": [Vector2(-56, 20), Vector2(-42, 20), Vector2(-34, 8), Vector2(-38, -6), Vector2(-30, -18),
			Vector2(-16, -20), Vector2(-10, -6), Vector2(-14, 8), Vector2(-6, 20), Vector2(8, 21),
			Vector2(12, 8), Vector2(6, -6), Vector2(12, -20), Vector2(26, -20), Vector2(30, -6),
			Vector2(26, 5), Vector2(36, 12), Vector2(49, 11)],
	},
	{
		"id": "frostpeak", "name": "Frostpeak Pass", "theme": "winter", "waves": 12, "factor": 0.98,
		"blurb": "Snow and wolves. The riders come fast and they come in packs.",
		"roster": [["goblin", 1], ["wolf_rider", 1], ["goblin_archer", 3], ["bat", 4], ["orc", 4], ["shaman", 5], ["sapper", 6], ["troll", 7]],
		"boss": "frost_wyrm", "unlock": "battle_mage",
		"path": [Vector2(-56, -22), Vector2(-30, -22), Vector2(-20, -12), Vector2(-26, 0), Vector2(-20, 12),
			Vector2(-4, 16), Vector2(4, 4), Vector2(0, -10), Vector2(10, -20), Vector2(24, -18),
			Vector2(28, -4), Vector2(22, 8), Vector2(32, 16), Vector2(42, 12), Vector2(49, 11)],
	},
	{
		"id": "ashen", "name": "Ashen Wastes", "theme": "ashen", "waves": 14, "factor": 1.05,
		"blurb": "Burnt earth under a red sky. Shamans keep the horde alive.",
		"roster": [["goblin", 1], ["goblin_archer", 2], ["wolf_rider", 2], ["shieldbearer", 3], ["orc", 4], ["shaman", 4], ["sapper", 5], ["necromancer", 6], ["troll", 7], ["bat", 8]],
		"boss": "dragon", "unlock": "cleric",
		"path": [Vector2(-56, 10), Vector2(-44, 10), Vector2(-36, 22), Vector2(-22, 22), Vector2(-16, 8),
			Vector2(-24, -6), Vector2(-18, -20), Vector2(-4, -22), Vector2(2, -8), Vector2(-2, 8),
			Vector2(8, 20), Vector2(22, 22), Vector2(26, 8), Vector2(18, -4), Vector2(26, -16),
			Vector2(38, -12), Vector2(42, 0), Vector2(49, 11)],
	},
	{
		"id": "dragons_reach", "name": "Dragon's Reach", "theme": "dusk", "waves": 15, "factor": 1.12,
		"blurb": "The longest road in the kingdom, and the dragon waits at the end of it.",
		"roster": [["goblin", 1], ["goblin_archer", 2], ["wolf_rider", 2], ["shieldbearer", 3], ["orc", 3], ["bat", 4], ["shaman", 4], ["troll", 5], ["sapper", 6], ["necromancer", 8]],
		"boss": "elder_dragon", "unlock": "trebuchet",
		"path": [Vector2(-56, -6), Vector2(-46, -6), Vector2(-40, -20), Vector2(-26, -24), Vector2(-18, -12),
			Vector2(-30, 0), Vector2(-36, 12), Vector2(-28, 24), Vector2(-14, 22), Vector2(-8, 10),
			Vector2(-12, -4), Vector2(-2, -16), Vector2(12, -22), Vector2(20, -10), Vector2(10, 0),
			Vector2(8, 14), Vector2(18, 24), Vector2(32, 22), Vector2(36, 8), Vector2(30, -4),
			Vector2(40, -16), Vector2(46, -4), Vector2(49, 11)],
	},
	{
		"id": "twin_fords", "name": "Twin Fords", "theme": "spring", "waves": 14, "factor": 0.92, "bonus_gold": 300,
		"blurb": "Two roads, two warbands, one gate. Split your army or lose the flank. (+300 starting gold)",
		"roster": [["goblin", 1], ["wolf_rider", 3], ["goblin_archer", 3], ["shieldbearer", 4], ["sapper", 5], ["orc", 6],
			["bat", 6], ["shaman", 7], ["troll", 8], ["necromancer", 9]],
		"boss": "warlord", "boss_count": 2, "unlock": "", "reward": "gear",
		"paths": [
			[Vector2(-56, -20), Vector2(-44, -20), Vector2(-34, -12), Vector2(-22, -19), Vector2(-10, -15), Vector2(-2, -4),
				Vector2(6, 5), Vector2(14, 6), Vector2(24, 13), Vector2(36, 13), Vector2(49, 11)],
			[Vector2(-56, 22), Vector2(-44, 22), Vector2(-34, 13), Vector2(-22, 20), Vector2(-10, 17), Vector2(-2, 12),
				Vector2(6, 5), Vector2(14, 6), Vector2(24, 13), Vector2(36, 13), Vector2(49, 11)],
		],
	},
	{
		"id": "riverwatch", "name": "Riverwatch", "theme": "misty", "waves": 14, "factor": 1.12,
		"blurb": "The road crosses the Silverrun three times. You can only build on the river platforms.",
		"roster": [["goblin", 1], ["goblin_archer", 2], ["shieldbearer", 3], ["wolf_rider", 3], ["orc", 4], ["sapper", 5],
			["shaman", 6], ["bat", 7], ["troll", 7], ["necromancer", 10]],
		"boss": "riverbane", "unlock": "", "reward": "gear",
		"path": [Vector2(-56, -12), Vector2(-42, -12), Vector2(-32, -20), Vector2(-18, -20), Vector2(-8, -12), Vector2(8, -10),
			Vector2(20, -18), Vector2(32, -14), Vector2(30, -2), Vector2(16, 2), Vector2(8, 8), Vector2(-10, 8),
			Vector2(-24, 14), Vector2(-20, 24), Vector2(-6, 24), Vector2(10, 22), Vector2(24, 18), Vector2(36, 14), Vector2(49, 11)],
		"river": [Vector2(-3, -44), Vector2(2, -28), Vector2(-2, -14), Vector2(3, -2), Vector2(-2, 10), Vector2(2, 22),
			Vector2(-1, 34), Vector2(1, 46)],
		"river_width": 5.5,
		"bridges": [Vector2(0.9, -24), Vector2(3, -2), Vector2(0, 16)],
	},
	{
		"id": "blackwood", "name": "Blackwood by Night", "theme": "night", "waves": 15, "factor": 1.15,
		"blurb": "A moonless forest road. Your soldiers can only shoot what the torchlight shows them.",
		"roster": [["goblin", 1], ["bat", 2], ["goblin_archer", 3], ["necromancer", 4], ["wolf_rider", 5], ["sapper", 6],
			["orc", 6], ["shieldbearer", 7], ["shaman", 8], ["troll", 9]],
		"boss": "shade", "unlock": "", "reward": "gear",
		"path": [Vector2(-56, 0), Vector2(-44, 0), Vector2(-38, -14), Vector2(-24, -20), Vector2(-14, -8), Vector2(-22, 6),
			Vector2(-14, 20), Vector2(0, 22), Vector2(6, 8), Vector2(0, -6), Vector2(8, -20), Vector2(22, -20),
			Vector2(28, -6), Vector2(20, 6), Vector2(26, 18), Vector2(38, 18), Vector2(49, 11)],
	},
]

## Bosses that rotate through Endless mode (every 10 waves).
const ENDLESS_BOSSES: Array[String] = ["warlord", "siege_troll", "hollow_king", "frost_wyrm", "dragon", "elder_dragon"]

const STARTING_UNITS: Array[String] = ["archer", "knight"]

const DIFFICULTIES := {
	"easy": {"name": "Easy", "lives": 30, "hp": 0.8, "gold": 1.1, "crowns": 1.0, "color": Color(0.8, 0.55, 0.3)},
	"normal": {"name": "Normal", "lives": 20, "hp": 1.0, "gold": 1.0, "crowns": 1.5, "color": Color(0.8, 0.82, 0.9)},
	"hard": {"name": "Hard", "lives": 10, "hp": 1.3, "gold": 0.95, "crowns": 2.2, "color": Color(1.0, 0.78, 0.3)},
}
const DIFFICULTY_ORDER: Array[String] = ["easy", "normal", "hard"]

## Visual themes: terrain/grass/foliage tints, sky and light.
const THEMES := {
	"summer": {
		"icon": Color(0.42, 0.58, 0.26),
		"grass_tint": Color(1, 1, 1), "snow": 0.0, "blade_root": Color(0.09, 0.15, 0.035),
		"blade_tip": Color(0.24, 0.36, 0.08), "leaf_tints": [Color(1, 1, 1), Color(0.9, 1.0, 0.8), Color(1.1, 1.0, 0.75)],
		"sky_top": Color(0.28, 0.42, 0.68), "sky_horizon": Color(0.88, 0.72, 0.56),
		"sun": Color(1.0, 0.86, 0.68), "sun_energy": 1.55, "fog": Color(0.72, 0.66, 0.6), "fog_density": 0.0035,
	},
	"autumn": {
		"icon": Color(0.72, 0.46, 0.2),
		"grass_tint": Color(1.3, 0.95, 0.55), "snow": 0.0, "blade_root": Color(0.16, 0.12, 0.04),
		"blade_tip": Color(0.5, 0.36, 0.1), "leaf_tints": [Color(1.5, 0.75, 0.3), Color(1.6, 0.5, 0.25), Color(1.4, 1.0, 0.35), Color(1.2, 0.4, 0.25)],
		"sky_top": Color(0.35, 0.42, 0.6), "sky_horizon": Color(0.95, 0.7, 0.48),
		"sun": Color(1.0, 0.78, 0.55), "sun_energy": 1.5, "fog": Color(0.78, 0.64, 0.52), "fog_density": 0.0045,
	},
	"winter": {
		"icon": Color(0.7, 0.76, 0.82),
		"grass_tint": Color(0.9, 0.95, 1.0), "snow": 0.8, "blade_root": Color(0.3, 0.33, 0.3),
		"blade_tip": Color(0.75, 0.8, 0.82), "leaf_tints": [Color(0.8, 0.95, 0.9), Color(0.7, 0.85, 0.85)],
		"sky_top": Color(0.45, 0.55, 0.72), "sky_horizon": Color(0.85, 0.88, 0.92),
		"sun": Color(0.95, 0.95, 1.0), "sun_energy": 1.3, "fog": Color(0.82, 0.86, 0.92), "fog_density": 0.006,
	},
	"ashen": {
		"icon": Color(0.42, 0.3, 0.26),
		"grass_tint": Color(0.55, 0.48, 0.42), "snow": 0.0, "blade_root": Color(0.06, 0.05, 0.04),
		"blade_tip": Color(0.25, 0.2, 0.14), "leaf_tints": [Color(0.45, 0.35, 0.3), Color(0.35, 0.3, 0.28)],
		"sky_top": Color(0.25, 0.12, 0.1), "sky_horizon": Color(0.85, 0.35, 0.18),
		"sun": Color(1.0, 0.55, 0.35), "sun_energy": 1.3, "fog": Color(0.45, 0.28, 0.22), "fog_density": 0.007,
	},
	"spring": {
		"icon": Color(0.5, 0.7, 0.35),
		"grass_tint": Color(1.05, 1.12, 0.92), "snow": 0.0, "blade_root": Color(0.08, 0.16, 0.04),
		"blade_tip": Color(0.3, 0.46, 0.1), "leaf_tints": [Color(1, 1.05, 0.9), Color(0.9, 1.1, 0.8), Color(1.25, 1.1, 1.15)],
		"sky_top": Color(0.3, 0.5, 0.78), "sky_horizon": Color(0.85, 0.85, 0.78),
		"sun": Color(1.0, 0.95, 0.85), "sun_energy": 1.6, "fog": Color(0.75, 0.78, 0.75), "fog_density": 0.003,
	},
	"misty": {
		"icon": Color(0.4, 0.55, 0.52),
		"grass_tint": Color(0.88, 1.02, 0.95), "snow": 0.0, "blade_root": Color(0.06, 0.12, 0.06),
		"blade_tip": Color(0.18, 0.3, 0.14), "leaf_tints": [Color(0.85, 1.0, 0.88), Color(0.78, 0.92, 0.9)],
		"sky_top": Color(0.42, 0.5, 0.56), "sky_horizon": Color(0.78, 0.8, 0.78),
		"sun": Color(0.95, 0.95, 0.9), "sun_energy": 1.15, "fog": Color(0.72, 0.76, 0.74), "fog_density": 0.009,
	},
	"night": {
		"icon": Color(0.22, 0.25, 0.45), "dark": true,
		"grass_tint": Color(0.62, 0.72, 0.82), "snow": 0.0, "blade_root": Color(0.03, 0.05, 0.04),
		"blade_tip": Color(0.1, 0.16, 0.13), "leaf_tints": [Color(0.6, 0.7, 0.82), Color(0.55, 0.62, 0.78)],
		"sky_top": Color(0.03, 0.04, 0.11), "sky_horizon": Color(0.12, 0.15, 0.3),
		"sun": Color(0.55, 0.68, 1.0), "sun_energy": 0.55, "fog": Color(0.09, 0.11, 0.22), "fog_density": 0.009,
		"ambient": 0.38, "fill": 0.16, "exposure": 1.4,
	},
	"dusk": {
		"icon": Color(0.4, 0.36, 0.56),
		"grass_tint": Color(0.85, 0.9, 0.95), "snow": 0.0, "blade_root": Color(0.07, 0.11, 0.04),
		"blade_tip": Color(0.2, 0.28, 0.1), "leaf_tints": [Color(0.8, 0.9, 0.8), Color(0.9, 0.8, 0.9)],
		"sky_top": Color(0.14, 0.14, 0.32), "sky_horizon": Color(0.95, 0.5, 0.35),
		"sun": Color(1.0, 0.6, 0.45), "sun_energy": 1.2, "fog": Color(0.5, 0.4, 0.5), "fog_density": 0.005,
	},
}


## Name of the level whose first clear unlocks this soldier.
static func unlock_source(type: String) -> String:
	for lv in LEVELS:
		if lv.get("unlock", "") == type:
			return lv["name"]
	return "the campaign"


static func count() -> int:
	return LEVELS.size()


static func get_level(idx: int) -> Dictionary:
	return LEVELS[clampi(idx, 0, LEVELS.size() - 1)]


static func index_of(id: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i]["id"] == id:
			return i
	return 0


static func theme(level: Dictionary) -> Dictionary:
	return THEMES.get(level.get("theme", "summer"), THEMES["summer"])
