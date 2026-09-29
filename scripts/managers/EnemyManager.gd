extends Node
## Spawns enemies at the portal and keeps the list of living enemies that
## soldiers query for targeting.

const SCENES := {
	"goblin": preload("res://scenes/enemies/Goblin.tscn"),
	"goblin_archer": preload("res://scenes/enemies/GoblinArcher.tscn"),
	"orc": preload("res://scenes/enemies/Orc.tscn"),
	"troll": preload("res://scenes/enemies/Troll.tscn"),
	"wolf_rider": preload("res://scenes/enemies/WolfRider.tscn"),
	"dragon": preload("res://scenes/enemies/Dragon.tscn"),
	"shaman": preload("res://scenes/enemies/Shaman.tscn"),
	"shieldbearer": preload("res://scenes/enemies/Shieldbearer.tscn"),
	"sapper": preload("res://scenes/enemies/Sapper.tscn"),
	"bat": preload("res://scenes/enemies/Bat.tscn"),
	"necromancer": preload("res://scenes/enemies/Necromancer.tscn"),
	"skeleton": preload("res://scenes/enemies/Skeleton.tscn"),
	# bosses
	"warlord": preload("res://scenes/enemies/Warlord.tscn"),
	"siege_troll": preload("res://scenes/enemies/SiegeTroll.tscn"),
	"riverbane": preload("res://scenes/enemies/Riverbane.tscn"),
	"hollow_king": preload("res://scenes/enemies/HollowKing.tscn"),
	"shade": preload("res://scenes/enemies/Shade.tscn"),
	"frost_wyrm": preload("res://scenes/enemies/FrostWyrm.tscn"),
	"elder_dragon": preload("res://scenes/enemies/ElderDragon.tscn"),
}

const CORPSE_LIFETIME := 12.0
var corpses: Array = []   ## [{pos, path_idx, progress, t}] recent small deaths (for necromancers)

var enemies: Array[Enemy] = []

@onready var container: Node3D = get_node("../../Enemies")


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_gone.unbind(1))
	EventBus.enemy_reached_castle.connect(_on_enemy_gone)


func spawn(type: String, hp_mult: float = 1.0, speed_mult: float = 1.0) -> Enemy:
	var scene: PackedScene = SCENES.get(type)
	if scene == null:
		push_warning("Unknown enemy type " + type)
		return null
	var e: Enemy = scene.instantiate()
	container.add_child(e)
	e.setup(GameManager.map, hp_mult * BoonManager.enemy_hp_mult(), speed_mult * BoonManager.omen_value("speed") * BoonManager.get_mult("enemy_speed") * (1.15 if GameManager.heat_has("swift") else 1.0))
	enemies.append(e)
	EventBus.enemy_spawned.emit(e)
	if e.is_boss:
		EventBus.boss_spawned.emit(e)
	return e


## Spawn partway along a road (summons, raised dead).
func spawn_at(type: String, path_i: int, at_progress: float, hp_mult: float = 1.0) -> Enemy:
	var e := spawn(type, hp_mult, 1.0)
	if e == null:
		return null
	e.path_idx = clampi(path_i, 0, GameManager.map.path_count() - 1)
	e.progress = clamp(at_progress, 0.0, GameManager.map.length_of(e.path_idx) - 1.0)
	e.global_position = GameManager.map.sample_on(e.path_idx, e.progress) + Vector3.UP * e.fly_height
	return e


func record_corpse(e: Enemy) -> void:
	if e.is_heavy or e.is_boss or e.flying or e.enemy_type == "skeleton":
		return
	corpses.append({"pos": e.global_position, "path_idx": e.path_idx, "progress": e.progress,
		"t": Time.get_ticks_msec() / 1000.0})
	if corpses.size() > 60:
		corpses.pop_front()


## Takes up to `n` fresh corpses within `radius` of pos (they get used up).
func take_corpses(pos: Vector3, radius: float, n: int) -> Array:
	var now := Time.get_ticks_msec() / 1000.0
	var out: Array = []
	for i in range(corpses.size() - 1, -1, -1):
		var c: Dictionary = corpses[i]
		if now - float(c["t"]) > CORPSE_LIFETIME:
			corpses.remove_at(i)
			continue
		if out.size() < n and Vector2(c["pos"].x - pos.x, c["pos"].z - pos.z).length() <= radius:
			out.append(c)
			corpses.remove_at(i)
	return out


func _on_enemy_gone(e) -> void:
	enemies.erase(e)


func alive_count() -> int:
	return enemies.size()


func has_type_alive(type: String) -> bool:
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.enemy_type == type:
			return true
	return false


## Enemies within a horizontal radius.
func enemies_near(pos: Vector3, radius: float, include_flying: bool = true) -> Array:
	var out: Array = []
	for e in enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		if e.flying and not include_flying:
			continue
		if Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length() <= radius:
			out.append(e)
	return out


## Remove every enemy without rewards (debug / restart).
func clear_all() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.alive = false
			e.queue_free()
	enemies.clear()
	corpses.clear()


func boss_alive() -> Enemy:
	for e in enemies:
		if is_instance_valid(e) and e.alive and e.is_boss:
			return e
	return null
