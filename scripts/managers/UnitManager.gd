extends Node
## Spawns, tracks, selects and sells friendly NPC soldiers.

const SCENES := {
	"archer": preload("res://scenes/units/Archer.tscn"),
	"knight": preload("res://scenes/units/Knight.tscn"),
	"crossbowman": preload("res://scenes/units/Crossbowman.tscn"),
	"torch_thrower": preload("res://scenes/units/TorchThrower.tscn"),
	"spearman": preload("res://scenes/units/Spearman.tscn"),
	"battle_mage": preload("res://scenes/units/BattleMage.tscn"),
	"cleric": preload("res://scenes/units/Cleric.tscn"),
	"trebuchet": preload("res://scenes/units/Trebuchet.tscn"),
}

var units: Array[FriendlyUnit] = []
var selected: FriendlyUnit = null
var _used_names: Dictionary = {}

@onready var container: Node3D = get_node("../../Units")


func spawn_unit(type: String, pos: Vector3, cost: int, hero_id: String = "", silent: bool = false) -> FriendlyUnit:
	var scene: PackedScene = SCENES.get(type)
	if scene == null:
		return null
	var u: FriendlyUnit = scene.instantiate()
	u.position = pos
	if hero_id != "":
		var h := HeroDefs.get_hero(hero_id)
		u.hero_id = hero_id
		u.display_name = h["name"]
		u.personality = h["personality"]
		u.hero_level = mini(HeroDefs.MAX_LEVEL, 1 + GameManager.hero_bonus_levels + HeroGear.start_level_bonus(hero_id))
		GameManager.hero_unit = u
		Profile.run["hero"] = hero_id
	else:
		u.display_name = _generate_name(type)
		u.personality = UnitDefs.PERSONALITIES[randi() % UnitDefs.PERSONALITIES.size()]
	u.invested = cost
	container.add_child(u)
	u.home_position = u.global_position
	# face the nearest bit of road
	var map: GameMap = GameManager.map
	var road := map.nearest_road_point(pos)
	u.model_root.rotation.y = atan2(road.x - pos.x, road.z - pos.z)
	units.append(u)
	GameManager.map.add_blocker(pos, 0.9)
	if silent:
		return u
	FX.death_puff(pos, 0.7)
	Sfx.play("place", -2.0)
	EventBus.unit_placed.emit(u)
	if hero_id != "":
		FX.magic_ring(pos, Color(1.0, 0.8, 0.3), 3.0)
		EventBus.banner.emit(u.display_name.to_upper(), HeroDefs.get_hero(hero_id)["title"] + " takes the field!", UiTheme.GOLD)
		u.say(HERO_LINES.get(hero_id, "For the realm!"), 2)
	else:
		u.say(DialogueDB.pick(DialogueDB.PLACED.get(type, ["Reporting for duty."])), 1)
	return u


const HERO_LINES := {
	"lionheart": "Stand with me, and none shall pass!",
	"lyra": "Wind's in our favour. Loose on my mark.",
	"voss": "Let them come. The storm is patient.",
	"brunhild": "A hundred sieges, and I've never lost a gate.",
	"elowen": "Rest easy, children. The light is with you.",
}


## Places the run's hero (free, once per game).
func spawn_hero(pos: Vector3, silent: bool = false) -> FriendlyUnit:
	if GameManager.hero_id == "" or GameManager.hero_deployed() or GameManager.heat_has("heroless"):
		return null
	var h := HeroDefs.get_hero(GameManager.hero_id)
	return spawn_unit(h["base"], pos, 0, GameManager.hero_id, silent)


func _generate_name(type: String) -> String:
	var pool := UnitDefs.NAMES.duplicate()
	pool.shuffle()
	var nm: String = pool[0]
	for n in pool:
		if not _used_names.has(n):
			nm = n
			break
	_used_names[nm] = true
	var female := nm in ["Isolde", "Maud", "Elspeth", "Rosamund", "Brienne", "Gwyneth", "Aveline", "Edith", "Matilda"]
	if type == "knight" or randf() < 0.25:
		return ("Dame " if female else "Sir ") + nm
	return nm


func sell(u: FriendlyUnit) -> void:
	if not is_instance_valid(u) or u.is_hero():
		return
	var value := u.sell_value()
	EconomyManager.add(value)
	FX.float_text(u.global_position + Vector3.UP * 2.2, "+%d" % value)
	FX.death_puff(u.global_position, 0.8)
	Sfx.play("coin", -4.0)
	# free the placement blocker
	var map: GameMap = GameManager.map
	for i in range(map.blockers.size() - 1, -1, -1):
		var b: Dictionary = map.blockers[i]
		if (b["pos"] as Vector2).distance_to(Vector2(u.home_position.x, u.home_position.z)) < 0.05:
			map.blockers.remove_at(i)
			break
	_used_names.erase(u.display_name.trim_prefix("Sir ").trim_prefix("Dame "))
	if selected == u:
		deselect()
	units.erase(u)
	for other in units:
		if other.assist_unit == u:
			other.set_assist(null)
	EventBus.unit_sold.emit(u)
	EventBus.feed_message.emit(u.display_name, "leaves the field. (+%d gold)" % value, UiTheme.GOLD_DIM)
	u.queue_free()


func select(u: FriendlyUnit) -> void:
	if selected == u:
		return
	if selected and is_instance_valid(selected):
		selected.set_selected(false)
	selected = u
	if u:
		u.set_selected(true)
		Sfx.play("click", -6.0)
		EventBus.unit_selected.emit(u)
	else:
		EventBus.unit_deselected.emit()


func deselect() -> void:
	if selected and is_instance_valid(selected):
		selected.set_selected(false)
	selected = null
	EventBus.unit_deselected.emit()


func unit_at(pos: Vector3, radius: float = 1.3) -> FriendlyUnit:
	var best: FriendlyUnit = null
	var bd := radius
	for u in units:
		var d := Vector2(u.global_position.x - pos.x, u.global_position.z - pos.z).length()
		if d < bd:
			bd = d
			best = u
	return best


func units_near(pos: Vector3, radius: float, type_filter: String = "") -> Array:
	var out: Array = []
	for u in units:
		if type_filter != "" and u.unit_type != type_filter:
			continue
		if Vector2(u.global_position.x - pos.x, u.global_position.z - pos.z).length() <= radius:
			out.append(u)
	return out


func nearest_unit(pos: Vector3, radius: float, type_filter: String = "", exclude_downed: bool = false, exclude: FriendlyUnit = null) -> FriendlyUnit:
	var best: FriendlyUnit = null
	var bd := radius
	for u in units:
		if u == exclude:
			continue
		if type_filter != "" and u.unit_type != type_filter:
			continue
		if exclude_downed and u.downed:
			continue
		var d := Vector2(u.global_position.x - pos.x, u.global_position.z - pos.z).length()
		if d <= bd:
			bd = d
			best = u
	return best


func count_type(type: String) -> int:
	var c := 0
	for u in units:
		if u.unit_type == type:
			c += 1
	return c


func heal_all() -> void:
	for u in units:
		u.full_heal()
