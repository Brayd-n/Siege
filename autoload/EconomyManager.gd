extends Node
## Gold bookkeeping. Every gold change goes through here.

const START_GOLD := 650

var gold: int = START_GOLD
var total_earned: int = 0


func reset() -> void:
	gold = START_GOLD + Profile.start_gold_bonus() + int(GameManager.level.get("bonus_gold", 0))
	if GameManager.heat_has("poverty"):
		gold = int(gold * 0.7)
	total_earned = 0
	EventBus.gold_changed.emit(gold)


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend(cost: int) -> bool:
	if cost > gold:
		return false
	gold -= cost
	EventBus.gold_changed.emit(gold)
	return true


func add(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	total_earned += amount
	EventBus.gold_changed.emit(gold)


## Gold for a kill, after boon and omen multipliers. Returns the amount paid.
func reward_kill(base: int) -> int:
	var mult: float = BoonManager.get_mult("gold_kill") * BoonManager.omen_value("gold", 1.0) * float(GameManager.difficulty_def()["gold"])
	if GameManager.heat_has("poverty"):
		mult *= 0.85
	var amt := int(round(base * mult))
	add(amt)
	return amt


## Price of a new unit after boons.
func unit_cost(type: String) -> int:
	var base: int = UnitDefs.get_def(type).get("cost", 0)
	return int(round(base * BoonManager.get_mult("unit_cost") * (1.1 if GameManager.heat_has("taxman") else 1.0)))


func upgrade_cost(base: int) -> int:
	return int(round(base * BoonManager.get_mult("upgrade_cost") * (1.25 if GameManager.heat_has("taxman") else 1.0)))
