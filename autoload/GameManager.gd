extends Node
## Owns the high level run state: lives, wave counter, speed, game over.
## Scene-level managers register themselves here in Main._ready().

enum State { BUILD, WAVE, DRAFT, WON, LOST }

const START_LIVES := 20

var lives: int = START_LIVES
var state: int = State.BUILD
var wave: int = 0 ## number of the last wave that was started (0 = none yet)
var speed: float = 1.0
var paused: bool = false
var total_kills: int = 0

# Level being played (set from the main menu)
const BATTLE_SCENE := "res://scenes/main/Main.tscn"
const MENU_SCENE := "res://scenes/menu/MainMenu.tscn"
var level: Dictionary = LevelDefs.LEVELS[0]
var level_index: int = 0
var difficulty: String = "normal"
var mode: String = "campaign"      ## "campaign", "endless" or "challenge"
var seed_salt: int = 0
var hero_id: String = ""           ## hero chosen for this run ("" = none)
var hero_unit: Node3D = null       ## the placed hero (null until deployed)
var hero_bonus_levels: int = 0     ## hero levels earned before the hero was placed
var heat: Array = []               ## active Heat trial ids for this run
var pending_resume: Dictionary = {} ## run save to rebuild once the battle loads

# Scene references (set by Main)
var main: Node3D = null
var map: Node3D = null
var camera: Camera3D = null
var enemy_manager: Node = null
var unit_manager: Node = null
var wave_manager: Node = null
var placement_manager: Node = null
var dialogue_manager: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.enemy_killed.connect(func(_e, _k): total_kills += 1)


func difficulty_def() -> Dictionary:
	return LevelDefs.DIFFICULTIES.get(difficulty, LevelDefs.DIFFICULTIES["normal"])


func reset_run(resuming: bool = false) -> void:
	lives = int(difficulty_def()["lives"]) + Profile.start_lives_bonus()
	if heat_has("fragile"):
		lives = maxi(1, lives / 2)
	wave = 0
	total_kills = 0
	hero_unit = null
	hero_bonus_levels = 0
	set_state(State.BUILD)
	set_speed(1.0)
	set_paused(false)
	EconomyManager.reset()
	BoonManager.reset()
	if not resuming:
		Profile.begin_run()


## Configure and load a battle.
func start_level(idx: int, diff: String, run_mode: String = "campaign", trials: Array = []) -> void:
	level_index = idx
	level = LevelDefs.get_level(idx)
	difficulty = diff
	mode = run_mode
	heat = trials.duplicate()
	RunSave.clear()
	seed_salt = Profile.daily_challenge_salt() if run_mode == "challenge" else 0
	hero_id = Profile.selected_hero() if not heat_has("heroless") else ""
	reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(BATTLE_SCENE)


func restart_level() -> void:
	start_level(level_index, difficulty, mode, heat)


func heat_has(id: String) -> bool:
	return id in heat


func heat_points() -> int:
	var p := 0
	for h in heat:
		p += int(HeatDefs.get_trial(h).get("heat", 1))
	return p


func heat_crown_mult() -> float:
	return 1.0 + 0.1 * heat_points()


func hero_deployed() -> bool:
	return is_instance_valid(hero_unit)


func to_menu() -> void:
	hero_unit = null
	set_speed(1.0)
	set_paused(false)
	main = null
	enemy_manager = null
	unit_manager = null
	wave_manager = null
	placement_manager = null
	dialogue_manager = null
	get_tree().change_scene_to_file(MENU_SCENE)


## Total waves in this run (0 = endless).
func total_waves() -> int:
	return WaveDefs.count()


func set_state(s: int) -> void:
	state = s
	EventBus.state_changed.emit(s)


func is_over() -> bool:
	return state == State.WON or state == State.LOST


func lose_lives(n: int) -> void:
	if is_over():
		return
	lives = max(0, lives - n)
	if lives <= 0 and BoonManager.has_relic("phoenix") and not BoonManager.phoenix_used:
		BoonManager.phoenix_used = true
		lives = 10
		EventBus.banner.emit("PHOENIX FEATHER", "The castle rises from the ashes! +10 lives", Color(1.0, 0.55, 0.2))
	EventBus.lives_changed.emit(lives)
	EventBus.camera_shake.emit(0.25 + 0.05 * n)
	if lives <= 0:
		set_speed(1.0)
		set_state(State.LOST)
		EventBus.game_over.emit(false)


func add_lives(n: int) -> void:
	lives += n
	EventBus.lives_changed.emit(lives)


func win() -> void:
	if is_over():
		return
	set_speed(1.0)
	set_state(State.WON)
	EventBus.game_over.emit(true)


func set_speed(s: float) -> void:
	speed = s
	Engine.time_scale = s


func set_paused(p: bool) -> void:
	paused = p
	if is_inside_tree():
		get_tree().paused = p



## Drop static caches on quit so Godot doesn't report leaked resources.
func _exit_tree() -> void:
	ModelBuilder._mesh_cache.clear()
	UiTheme._fonts.clear()
	UiTheme._theme = null
	Projectile._scene = null
