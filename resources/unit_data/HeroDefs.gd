class_name HeroDefs
extends RefCounted
## Heroes: one named champion per run. The player picks a hero before the
## battle, places them once for free, and they level up every wave they
## survive. A hero can't be sold or moved. Each hero is built on a soldier
## class (so class boons apply to them too) with much stronger stats and an
## aura that buffs nearby soldiers.
##
## aura: {stat, mult, radius, label}
##   damage / attack_speed / range  -> multiplier above 1 is better
##   special_cd / damage_taken      -> multiplier below 1 is better

const ORDER: Array[String] = ["lionheart", "lyra", "voss", "brunhild", "elowen"]
const MAX_LEVEL := 10
const PER_LEVEL := 0.08          ## +8% damage and health per hero level

const DATA := {
	"lionheart": {
		"name": "Sir Aldric Lionheart", "short": "Aldric", "title": "The Lionheart", "base": "knight",
		"personality": "Brave", "unlock": -1,
		"hp": 2.4, "damage": 2.0, "range": 1.1, "speed": 1.15,
		"aura": {"stat": "damage", "mult": 1.15, "radius": 9.0, "label": "Inspired"},
		"aura_b": {"stat": "max_hp", "mult": 1.2, "radius": 9.0, "label": "Stalwart", "desc": "Soldiers within 9m have +20% health."},
		"special_name": "Lion's Roar", "road_ok": true,
		"unique": "Stands ON the road and holds up to 3 enemies in place while he fights them.",
		"passive": "Lionheart: takes 25% less damage, and deals +50% damage below 30% health.",
		"abilities": [
			{"name": "Heroic Charge", "cd": 16.0, "target": "point", "radius": 2.0, "level": 1,
				"desc": "Charges to the target spot (up to 18m), hitting every enemy on the way for 2x damage and knocking them back."},
			{"name": "Lion's Roar", "cd": 30.0, "target": "none", "radius": 7.0, "level": 3,
				"desc": "Stuns enemies within 7m for 2.5s. Soldiers within 10m attack 35% faster for 8s."},
		],
		"blurb": "A living legend in plate. Holds the line alone and inspires every soldier near him.",
		"aura_desc": "Soldiers within 9m deal +15% damage.",
		"cape": Color(0.55, 0.08, 0.06),
	},
	"lyra": {
		"name": "Lyra Windrunner", "short": "Lyra", "title": "Warden of the Wood", "base": "archer",
		"personality": "Cocky", "unlock": -1,
		"hp": 2.2, "damage": 1.9, "range": 1.3, "speed": 1.3,
		"aura": {"stat": "attack_speed", "mult": 1.15, "radius": 9.0, "label": "Tailwind"},
		"aura_b": {"stat": "range", "mult": 1.12, "radius": 9.0, "label": "Eagle's Eye", "desc": "Soldiers within 9m gain +12% range."},
		"special_name": "Storm of Arrows",
		"unique": "Hunter's Mark: each hit marks the enemy (+6% damage taken from everyone, up to 5 stacks). Finishes off enemies below 12% health. Her falcon strikes and reveals enemies.",
		"passive": "Falcon: every 3s her falcon dives at an enemy within 22m.",
		"abilities": [
			{"name": "Rain of Arrows", "cd": 18.0, "target": "point", "radius": 5.0, "level": 1,
				"desc": "Arrows rain on the target area for 4s, hitting ground and flying enemies."},
			{"name": "Piercing Gale", "cd": 26.0, "target": "point", "radius": 1.5, "level": 3,
				"desc": "A storm arrow flies toward the target, hitting every enemy in a 30m line for 5x damage and knocking them back."},
		],
		"blurb": "The finest bow in the kingdom. Huge range, and her calls speed every archer's hand.",
		"aura_desc": "Soldiers within 9m attack 15% faster.",
		"cape": Color(0.1, 0.35, 0.18),
	},
	"voss": {
		"name": "Magister Voss", "short": "Voss", "title": "The Stormcaller", "base": "battle_mage",
		"personality": "Serious", "unlock": 1,
		"hp": 2.0, "damage": 1.9, "range": 1.15, "speed": 1.1,
		"aura": {"stat": "special_cd", "mult": 0.75, "radius": 10.0, "label": "Arcane Resonance"},
		"aura_b": {"stat": "damage", "mult": 1.1, "radius": 10.0, "label": "Arcane Surge", "desc": "Soldiers within 10m deal +10% damage."},
		"special_name": "Tempest Nova", "blink": true,
		"unique": "Channels a lightning beam that grows stronger the longer it stays on one enemy (up to 3x) and arcs to two more. Teleports instead of walking.",
		"passive": "Stormcaller: the beam arcs to 2 extra enemies for 40% damage.",
		"abilities": [
			{"name": "Meteor", "cd": 20.0, "target": "point", "radius": 4.5, "level": 1,
				"desc": "A meteor lands after 1s: 8x damage, sets enemies ablaze and stuns them for 1s."},
			{"name": "Time Warp", "cd": 40.0, "target": "none", "radius": 0.0, "level": 3,
				"desc": "Every enemy on the map is slowed 50% for 5s, and every soldier's special recharges 5s."},
		],
		"blurb": "Archmage of the royal court. His lightning chains through whole warbands.",
		"aura_desc": "Soldiers within 10m recharge specials 25% faster.",
		"cape": Color(0.22, 0.1, 0.42),
	},
	"brunhild": {
		"name": "Brunhild Ironpike", "short": "Brunhild", "title": "The Unbroken", "base": "spearman",
		"personality": "Veteran", "unlock": 2,
		"hp": 2.6, "damage": 1.9, "range": 1.1, "speed": 1.15,
		"aura": {"stat": "range", "mult": 1.12, "radius": 9.0, "label": "Watchful"},
		"aura_b": {"stat": "damage_taken", "mult": 0.85, "radius": 9.0, "label": "Bulwark", "desc": "Soldiers within 9m take 15% less damage."},
		"special_name": "Iron Wall",
		"unique": "Builds barricades on the road that enemies must smash through. Her pike sweeps everything in front of her.",
		"passive": "Iron Hide: enemies that hit her take 30% of the damage back.",
		"abilities": [
			{"name": "Raise Barricade", "cd": 22.0, "target": "road", "radius": 1.8, "level": 1,
				"desc": "Builds a spiked barricade on the road (max 2). Ground enemies must break it to pass."},
			{"name": "Iron Wall", "cd": 35.0, "target": "none", "radius": 9.0, "level": 3,
				"desc": "Brunhild and every soldier within 9m take no damage for 4s."},
		],
		"blurb": "Veteran of a hundred sieges. Nothing gets past her pike, and her sentries see further.",
		"aura_desc": "Soldiers within 9m gain +12% range.",
		"cape": Color(0.42, 0.3, 0.1),
	},
	"elowen": {
		"name": "Mother Elowen", "short": "Elowen", "title": "The Lightbringer", "base": "cleric",
		"personality": "Friendly", "unlock": 4,
		"hp": 2.4, "damage": 1.8, "range": 1.2, "speed": 1.2, "heal": 1.8,
		"aura": {"stat": "damage_taken", "mult": 0.8, "radius": 10.0, "label": "Sanctified"},
		"aura_b": {"stat": "attack_speed", "mult": 1.12, "radius": 10.0, "label": "Blessing of Haste", "desc": "Soldiers within 10m attack 12% faster."},
		"special_name": "Dawn's Grace",
		"unique": "Guardian Angel: once per wave, each soldier in her aura who would be knocked down survives on 30% health instead.",
		"passive": "Her healing reaches every soldier in her aura every 2s.",
		"abilities": [
			{"name": "Consecrate", "cd": 20.0, "target": "point", "radius": 5.0, "level": 1,
				"desc": "Holy ground for 8s: burns enemies inside (double vs undead) and heals soldiers inside 4% per second."},
			{"name": "Resurrection", "cd": 60.0, "target": "none", "radius": 0.0, "level": 3,
				"desc": "Revives every downed soldier on the map at full health, frees stunned soldiers and restores 2 castle lives."},
		],
		"blurb": "High priestess of the Sun. Heals twice as hard and shields her soldiers from harm.",
		"aura_desc": "Soldiers within 10m take 20% less damage.",
		"cape": Color(0.9, 0.85, 0.7),
	},
}


const KITS := {
	"lionheart": preload("res://scripts/heroes/KitLionheart.gd"),
	"lyra": preload("res://scripts/heroes/KitLyra.gd"),
	"voss": preload("res://scripts/heroes/KitVoss.gd"),
	"brunhild": preload("res://scripts/heroes/KitBrunhild.gd"),
	"elowen": preload("res://scripts/heroes/KitElowen.gd"),
}

## Hero level milestones (in-battle levels 1-10).
const MILESTONES := {
	3: "Second ability unlocked",
	5: "Empowered: +15% damage and health",
	8: "Veteran: abilities recharge 25% faster",
	10: "Legend: +25% damage, and abilities hit 50% harder",
}


static func make_kit(id: String) -> HeroKit:
	var script: Script = KITS.get(id)
	if script == null:
		return null
	return script.new()


static func ability(id: String, idx: int) -> Dictionary:
	var abs: Array = get_hero(id).get("abilities", [])
	return abs[idx] if idx < abs.size() else {}


## The aura this hero uses right now (mastery level 2 unlocks the second one).
static func active_aura(id: String) -> Dictionary:
	var h := get_hero(id)
	if HeroGear.aura_choice(id) == "b" and h.has("aura_b"):
		return h["aura_b"]
	return h.get("aura", {})


static func aura_text(id: String) -> String:
	var h := get_hero(id)
	if HeroGear.aura_choice(id) == "b" and h.has("aura_b"):
		return h["aura_b"]["desc"]
	return h.get("aura_desc", "")


static func get_hero(id: String) -> Dictionary:
	return DATA.get(id, {})


## Map that must be beaten to unlock this hero ("" = available from the start).
static func unlock_source(id: String) -> String:
	var idx: int = int(get_hero(id).get("unlock", -1))
	if idx < 0:
		return ""
	return String(LevelDefs.get_level(idx)["name"])


## Builds the unit definition a hero uses: the base class with boosted stats.
static func make_def(id: String) -> Dictionary:
	var h := get_hero(id)
	var d: Dictionary = UnitDefs.get_def(h["base"]).duplicate(true)
	d["name"] = "Hero - " + String(UnitDefs.get_def(h["base"])["name"])
	d["cost"] = 0
	d["hp"] = float(d["hp"]) * float(h["hp"])
	d["damage"] = float(d["damage"]) * float(h["damage"])
	d["range"] = float(d["range"]) * float(h["range"])
	d["interval"] = float(d["interval"]) / float(h["speed"])
	if d.has("heal"):
		d["heal"] = float(d["heal"]) * float(h.get("heal", 1.0))
	var sp: Dictionary = d["special"]
	sp["name"] = h["special_name"]
	sp["cd"] = float(sp["cd"]) * 0.7
	d["role"] = h["blurb"]
	return d


## Gold crown, cape and a faint glow so heroes stand out from regular soldiers.
static func decorate(rig: Dictionary, id: String, skin_id: String = "") -> void:
	var h := get_hero(id)
	if skin_id == "":
		skin_id = HeroGear.skin(id)
	var sk: Dictionary = HeroGear.SKINS.get(skin_id, {})
	var head: Node3D = rig.get("head")
	var trim: Color = sk.get("trim", Color(1.0, 0.78, 0.3))
	var gold := Mats.emissive(trim, 1.6 if sk.get("glow", false) else 0.9)
	if head:
		var crown := Node3D.new()
		crown.position = Vector3(0, 0.36, 0)
		head.add_child(crown)
		ModelBuilder.add_mesh(crown, ModelBuilder.cyl(0.15, 0.14, 0.07, 16), gold)
		for i in 6:
			var a := TAU * i / 6.0
			ModelBuilder.add_mesh(crown, ModelBuilder.cone(0.035, 0.1, 6), gold,
				Vector3(cos(a) * 0.14, 0.08, sin(a) * 0.14))
		ModelBuilder.add_mesh(crown, ModelBuilder.sphere(0.028, 8), Mats.emissive(Color(0.9, 0.1, 0.15), 1.5), Vector3(0, 0.02, 0.15))
	var torso: Node3D = rig.get("torso")
	if torso:
		var cape_m := Mats.cloth(sk.get("cape", h.get("cape", Color(0.5, 0.1, 0.08))))
		ModelBuilder.add_mesh(torso, ModelBuilder.box(Vector3(0.5, 0.95, 0.035)), cape_m,
			Vector3(0, 0.2, -0.2), Vector3(10, 0, 0))
		ModelBuilder.add_mesh(torso, ModelBuilder.box(Vector3(0.52, 0.05, 0.04)), gold,
			Vector3(0, 0.66, -0.17), Vector3(10, 0, 0))
		if sk.get("glow", false):
			ModelBuilder.add_mesh(torso, ModelBuilder.box(Vector3(0.5, 0.04, 0.04)), gold, Vector3(0, -0.25, -0.26), Vector3(10, 0, 0))
