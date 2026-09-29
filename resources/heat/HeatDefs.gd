class_name HeatDefs
extends RefCounted
## Heat trials: optional challenges picked before a battle. Each adds heat;
## more heat means more Crowns, better gear drops and more hero XP.

const TRIALS := [
	{"id": "ironhide", "name": "Iron Hides", "heat": 2, "desc": "Enemies have +25% health."},
	{"id": "swift", "name": "Swift Horde", "heat": 2, "desc": "Enemies move 15% faster."},
	{"id": "poverty", "name": "Lean Coffers", "heat": 2, "desc": "Start with 30% less gold. Kills pay 15% less."},
	{"id": "fragile", "name": "Crumbling Walls", "heat": 2, "desc": "Start with half the castle lives."},
	{"id": "elites", "name": "Elite Vanguard", "heat": 2, "desc": "An elite joins every 5th wave."},
	{"id": "omens", "name": "Cursed Skies", "heat": 2, "desc": "An omen hangs over every wave."},
	{"id": "stingy", "name": "Stingy King", "heat": 1, "desc": "Drafts offer only 2 boons."},
	{"id": "taxman", "name": "Tax Man", "heat": 1, "desc": "Soldiers cost 10% more, upgrades 25% more."},
	{"id": "fixed_fate", "name": "Fixed Fate", "heat": 1, "desc": "No rerolls in drafts."},
	{"id": "heroless", "name": "No Heroes", "heat": 3, "desc": "Your hero stays home. (No gear drop.)"},
]


static func get_trial(id: String) -> Dictionary:
	for t in TRIALS:
		if t["id"] == id:
			return t
	return {}


static func max_heat() -> int:
	var h := 0
	for t in TRIALS:
		h += int(t["heat"])
	return h
