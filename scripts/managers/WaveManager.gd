extends Node
## Builds a spawn schedule for each wave, spawns enemies over time, detects
## wave completion, pays the wave bonus and opens the boon draft.

var spawn_queue: Array = []    ## [{t, type}] sorted by time
var wave_time: float = 0.0
var active: bool = false
var wave_bonus_mult: float = 1.0


var lives_at_wave_start: int = 0


func _ready() -> void:
	EventBus.boon_picked.connect(_on_boon_picked)
	EventBus.relic_picked_continue.connect(_on_relic_taken)


func can_start() -> bool:
	return GameManager.state == GameManager.State.BUILD and (WaveDefs.count() == 0 or GameManager.wave < WaveDefs.count())


func next_wave_number() -> int:
	return GameManager.wave + 1


func start_next_wave() -> void:
	if not can_start():
		return
	GameManager.wave += 1
	var n := GameManager.wave
	spawn_queue.clear()
	wave_time = 0.0
	var count_mult := BoonManager.omen_value("count", 1.0)
	wave_bonus_mult = BoonManager.omen_value("bonus", 1.0)
	for g in WaveDefs.get_wave(n):
		var special: bool = g.get("boss", false) or g.get("elite", false)
		var c := int(round(int(g["count"]) * (count_mult if not special else 1.0)))
		for i in c:
			spawn_queue.append({"t": float(g["delay"]) + i * float(g["interval"]), "type": g["type"],
				"boss": g.get("boss", false), "elite": g.get("elite", false)})
	spawn_queue.sort_custom(func(a, b): return a["t"] < b["t"])
	active = true
	lives_at_wave_start = GameManager.lives
	GameManager.set_state(GameManager.State.WAVE)
	Sfx.play("horn", -2.0, 0.0, 1.0)
	var sub := WaveDefs.describe(n)
	if not BoonManager.current_omen.is_empty():
		sub = BoonManager.current_omen["name"] + "  |  " + sub
	EventBus.banner.emit("WAVE %d" % n, sub, UiTheme.GOLD)
	EventBus.wave_started.emit(n)


func _process(delta: float) -> void:
	if not active:
		return
	wave_time += delta
	var em := GameManager.enemy_manager
	var hp_mult := 1.0 + WaveDefs.HP_SCALE_PER_WAVE * (GameManager.wave - 1)
	while not spawn_queue.is_empty() and spawn_queue[0]["t"] <= wave_time:
		var s: Dictionary = spawn_queue.pop_front()
		var m := hp_mult
		if s.get("boss", false) or EnemyDefs.is_boss(s["type"]):
			m = 1.0 + (0.12 * (GameManager.wave / 10) if WaveDefs.count() == 0 else 0.0)
		var e: Enemy = em.spawn(s["type"], m, 1.0)
		if e and s.get("elite", false):
			e.make_elite()
	if spawn_queue.is_empty() and em.alive_count() == 0 and not GameManager.is_over():
		_complete_wave()


func enemies_remaining() -> int:
	var em := GameManager.enemy_manager
	return spawn_queue.size() + (em.alive_count() if em else 0)


func _complete_wave() -> void:
	active = false
	var n := GameManager.wave
	var bonus := int((WaveDefs.WAVE_BONUS_BASE + WaveDefs.WAVE_BONUS_PER * n) * wave_bonus_mult)
	EconomyManager.add(bonus)
	var extra := ""
	if BoonManager.has_flag("interest"):
		var interest: int = min(150, int(EconomyManager.gold * 0.1))
		EconomyManager.add(interest)
		extra = "  +%d interest" % interest
	if BoonManager.has_flag("divine_favor"):
		GameManager.add_lives(1)
		extra += "  +1 life"
	if BoonManager.has_relic("midas") and GameManager.lives >= lives_at_wave_start:
		EconomyManager.add(150)
		extra += "  +150 Midas"
	GameManager.unit_manager.heal_all()
	BoonManager.clear_omen()
	EventBus.wave_completed.emit(n)
	if WaveDefs.count() > 0 and n >= WaveDefs.count():
		Sfx.play("fanfare", 0.0, 0.0, 1.0)
		GameManager.win()
		return
	Sfx.play("coin", -2.0)
	EventBus.banner.emit("WAVE %d CLEARED" % n, "+%d gold%s" % [bonus, extra], UiTheme.GREEN)
	GameManager.set_state(GameManager.State.DRAFT)
	# give the banner a moment before the draft cards appear
	get_tree().create_timer(1.2, false).timeout.connect(_open_draft.bind(n))


func _open_draft(n: int) -> void:
	if GameManager.state != GameManager.State.DRAFT:
		return
	if BoonManager.relic_pending > 0 and BoonManager.open_relic_draft():
		return
	BoonManager.open_draft(n)


func _on_relic_taken() -> void:
	if GameManager.state == GameManager.State.DRAFT:
		get_tree().create_timer(0.3, false).timeout.connect(_open_draft.bind(GameManager.wave))


func _on_boon_picked(_boon: Dictionary) -> void:
	if GameManager.state != GameManager.State.DRAFT:
		return
	BoonManager.roll_omen(next_wave_number())
	GameManager.set_state(GameManager.State.BUILD)
	RunSave.snapshot()
	if bool(Profile.setting("auto_waves")):
		get_tree().create_timer(3.0, false).timeout.connect(_auto_start)


func _auto_start() -> void:
	if bool(Profile.setting("auto_waves")) and GameManager.state == GameManager.State.BUILD and not GameManager.is_over():
		start_next_wave()


## Debug: finish the current wave instantly (no kill rewards).
func force_complete() -> void:
	if not active:
		return
	spawn_queue.clear()
	GameManager.enemy_manager.clear_all()
	_complete_wave()
