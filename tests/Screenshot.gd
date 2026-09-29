extends Node
## Renders a staged battle and saves screenshots (dev tool, not part of the game).
## xvfb-run godot --path . res://tests/Screenshot.tscn -- out=/tmp/shots

const MAIN := preload("res://scenes/main/Main.tscn")
var main: Node
var frame := 0
var out_dir := "/tmp"
var shots: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
	Profile.no_save = true
	Profile.data = Profile._defaults()
	Profile.unlock_everything()
	var lvl := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			lvl = int(a.substr(6))
	GameManager.level_index = lvl
	GameManager.level = LevelDefs.get_level(lvl)
	GameManager.difficulty = "normal"
	GameManager.mode = "endless" if "endless" in OS.get_cmdline_user_args() else "campaign"
	GameManager.hero_id = "lionheart"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("hero="):
			GameManager.hero_id = a.substr(5)
	GameManager.reset_run()
	main = MAIN.instantiate()
	add_child(main)


func _stage() -> void:
	var map: GameMap = GameManager.map
	var um = GameManager.unit_manager
	EconomyManager.add(3000)
	var plan := [["archer", 40.0, 3.4], ["knight", 44.0, -2.7], ["spearman", 36.0, -3.0], ["battle_mage", 50.0, 4.2],
		["cleric", 47.0, -4.5], ["torch_thrower", 56.0, -3.8], ["crossbowman", 60.0, 4.0], ["trebuchet", 70.0, 7.5]]
	for p in plan:
		var off: float = p[1]
		var pos := map.sample_path(off)
		var dir := map.path_direction(off)
		var perp := Vector3(-dir.z, 0, dir.x)
		var c := pos + perp * float(p[2])
		if map.placement_error(c) != "":
			c = pos + perp * float(p[2]) * 1.4
		um.spawn_unit(p[0], c, 100)
	um.spawn_hero(map.sample_path(42.0) + Vector3(-map.path_direction(42.0).z, 0, map.path_direction(42.0).x) * -3.4)
	GameManager.wave_manager.start_next_wave()
	var em = GameManager.enemy_manager
	for i in 9:
		var e = em.spawn("goblin")
		e.progress = 20.0 + i * 3.2
	var tr = em.spawn("troll")
	tr.progress = 30.0
	var sh = em.spawn("shaman")
	sh.progress = 24.0
	var orc = em.spawn("orc")
	orc.progress = 26.0
	var w = em.spawn("wolf_rider")
	w.progress = 45.0


func _process(_d: float) -> void:
	frame += 1
	if frame == 5:
		_stage()
	if frame == 60:
		var um = GameManager.unit_manager
		um.select(um.units[0])
		um.units[0].talk()
		var rig: CameraRig = GameManager.main.camera_rig
		rig.position = Vector3(-24, 0, -8)
		rig.target_distance = 34.0
		rig.distance = 34.0
	if frame == 90:
		_save("battle_close")
		var rig2: CameraRig = GameManager.main.camera_rig
		rig2.position = Vector3(-2, 0, 0)
		rig2.target_distance = 70.0
		rig2.distance = 70.0
	if frame == 110:
		_save("overview")
		var rig3: CameraRig = GameManager.main.camera_rig
		rig3.position = Vector3(40, 0, 10)
		rig3.target_distance = 36.0
		rig3.distance = 36.0
		rig3.target_yaw = 0.9
		rig3.yaw = 0.9
	if frame == 130:
		_save("castle")
		var rig4: CameraRig = GameManager.main.camera_rig
		rig4.position = Vector3(-26, 0, -12)
		rig4.target_distance = 18.0
		rig4.distance = 18.0
		rig4.target_yaw = 0.0
		rig4.yaw = 0.0
	if frame == 150:
		_save("units_zoom")
		GameManager.unit_manager.select(GameManager.hero_unit)
		GameManager.hero_unit.gain_levels(3)
		var rig5: CameraRig = GameManager.main.camera_rig
		rig5.position = GameManager.hero_unit.global_position
		rig5.target_distance = 14.0
		rig5.distance = 14.0
	if frame == 175:
		_save("hero")
		BoonManager.current_event = BoonManager.EVENTS[0].duplicate(true)
		for o in BoonManager.current_event["options"]:
			o["rarity"] = "event"
			o["event"] = true
		EventBus.boon_draft_opened.emit(BoonManager.current_event["options"])
	if frame == 190:
		_save("event")
		BoonManager.current_event = {}
		BoonManager.open_draft(5)
		BoonManager.current_event = {}
		EventBus.boon_draft_opened.emit(BoonManager.roll_options(8))
	if frame == 205:
		_save("draft")
		get_tree().quit()


func _save(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir + "/" + name + ".png")
	print("saved ", name)
