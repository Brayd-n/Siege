extends Node3D
## Root of the game scene. Registers managers, sets up lighting/atmosphere,
## routes mouse & keyboard input, and handles the debug shortcuts.

@onready var map: GameMap = $Map
@onready var camera_rig: CameraRig = $CameraRig
@onready var hud: CanvasLayer = $HUD

var _hover_unit: FriendlyUnit = null


func _enter_tree() -> void:
	GameManager.main = self
	GameManager.map = get_node("Map")
	GameManager.enemy_manager = get_node("Managers/EnemyManager")
	GameManager.unit_manager = get_node("Managers/UnitManager")
	GameManager.wave_manager = get_node("Managers/WaveManager")
	GameManager.placement_manager = get_node("Managers/PlacementManager")
	GameManager.dialogue_manager = get_node("Managers/DialogueManager")


func _ready() -> void:
	GameManager.camera = camera_rig.camera
	_setup_environment()
	Sfx.start_ambience()
	EventBus.gold_changed.emit(EconomyManager.gold)
	EventBus.lives_changed.emit(GameManager.lives)
	EventBus.state_changed.emit(GameManager.state)
	if not GameManager.pending_resume.is_empty():
		var s := GameManager.pending_resume
		GameManager.pending_resume = {}
		RunSave.apply.call_deferred(s)
	else:
		EventBus.feed_message.emit("Herald", "The horde gathers at the dark gate. Recruit soldiers beside the road.", UiTheme.GOLD)
		EventBus.feed_message.emit("Herald", "Click a soldier to TALK or give orders.", UiTheme.GOLD)
		if GameManager.hero_id != "":
			EventBus.feed_message.emit("Herald", "Press H (or the gold card) to place your hero for free.", UiTheme.GOLD)


# ====================================================================== atmosphere
func _setup_environment() -> void:
	Atmosphere.build(self, LevelDefs.theme(GameManager.level))


# ====================================================================== input
func _mouse_ground() -> Dictionary:
	var cam := camera_rig.camera
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if abs(dir.y) < 0.0001:
		return {"hit": false, "pos": Vector3.ZERO}
	var t := -from.y / dir.y
	if t < 0:
		return {"hit": false, "pos": Vector3.ZERO}
	return {"hit": true, "pos": from + dir * t}


func _process(_delta: float) -> void:
	var g := _mouse_ground()
	var pm := GameManager.placement_manager
	pm.update_mouse(g["pos"], g["hit"])


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_over():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var pm := GameManager.placement_manager
		var um := GameManager.unit_manager
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if pm.is_active():
				pm.try_place(mb.shift_pressed)
			else:
				var g := _mouse_ground()
				if g["hit"]:
					var u: FriendlyUnit = um.unit_at(g["pos"], 1.5)
					if u:
						um.select(u)
					else:
						um.deselect()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			if not camera_rig.was_dragging():
				if pm.is_active():
					pm.cancel()
				elif um.selected and is_instance_valid(um.selected) and um.selected.is_hero():
					var g2 := _mouse_ground()
					if g2["hit"]:
						if um.selected.hero_move_order(g2["pos"]):
							FX.magic_ring(g2["pos"], Color(0.55, 0.8, 1.0), 0.8)
				else:
					um.deselect()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event as InputEventKey)


func _handle_key(k: InputEventKey) -> void:
	var pm := GameManager.placement_manager
	var um := GameManager.unit_manager
	var sel: FriendlyUnit = um.selected
	var kc := k.keycode
	if kc >= KEY_1 and kc <= KEY_8:
		pm.begin(UnitDefs.ORDER[kc - KEY_1])
	elif kc == Keys.code("hero"):
		pm.begin_hero()
	elif kc == Keys.code("ability1"):
		pm.begin_ability(0)
	elif kc == Keys.code("ability2"):
		pm.begin_ability(1)
	elif kc == Keys.code("start_wave"):
		GameManager.wave_manager.start_next_wave()
	elif kc == Keys.code("talk"):
		if sel:
			sel.talk()
	elif kc == Keys.code("special"):
		if sel:
			sel.use_special()
	elif kc == Keys.code("targeting"):
		if sel:
			sel.set_targeting((sel.targeting + 1) % FriendlyUnit.TARGETING_NAMES.size())
	else:
		match kc:
			KEY_F1:
				EconomyManager.add(500)
				EventBus.feed_message.emit("Debug", "+500 gold", Color(0.6, 0.9, 1.0))
			KEY_F2:
				GameManager.enemy_manager.spawn("goblin")
			KEY_F3:
				GameManager.enemy_manager.spawn("orc")
			KEY_F4:
				GameManager.enemy_manager.spawn("troll")
			KEY_F5:
				GameManager.enemy_manager.spawn("dragon")
			KEY_F6:
				GameManager.wave_manager.force_complete()
			KEY_F7:
				GameManager.add_lives(10)
				EventBus.feed_message.emit("Debug", "+10 castle lives", Color(0.6, 0.9, 1.0))
			KEY_F8:
				GameManager.wave_manager.start_next_wave()
			_:
				return
	get_viewport().set_input_as_handled()


func restart() -> void:
	GameManager.restart_level()
