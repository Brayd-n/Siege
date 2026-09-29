extends Node
## Opens every main-menu screen and checks it fits on a 1600x900 screen,
## then tests save & resume of a run:
##   godot --headless --fixed-fps 30 --path . res://tests/MenuTest.tscn

var menu: Node
var f := 0
var results: Array = []
var saved_units := 0
var saved_wave := 0


func _ready() -> void:
	if get_parent() != get_tree().root or name != "MenuDriver":
		var d: Node = load("res://tests/MenuTest.gd").new()
		d.name = "MenuDriver"
		get_tree().root.add_child.call_deferred(d)
		set_process(false)
		return
	Profile.no_save = true
	Profile.data = Profile._defaults()
	Profile.data["seen_intro"] = true
	Profile.data["login"]["last"] = Profile.today()
	Profile.unlock_everything()
	HeroGear.add_mastery_xp("lionheart", 3000)
	for i in 12:
		HeroGear.add_item(HeroGear.roll_item("lionheart", 2.0))
	Profile.mark_seen("enemy:goblin")
	Profile.mark_seen("enemy:dragon")
	Profile.mark_seen("enemy:warlord")
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/MainMenu.tscn")


func check(name: String, ok: bool) -> void:
	results.append([name, ok])
	print(("PASS  " if ok else "FAIL  ") + name)


func _size_ok(label: String) -> void:
	var p: Control = menu.overlay_box.get_parent()
	check("%s fits the screen (%s)" % [label, p.size], p.size.y <= 900.0 and p.size.x <= 1600.0 and p.size.y > 50.0)


func _process(_d: float) -> void:
	if name != "MenuDriver":
		return
	f += 1
	if f == 4:
		menu = get_tree().current_scene
	var steps := {
		5: func(): menu._show_heroes(),
		12: func(): menu._show_codex("enemy:dragon"),
		19: func(): menu._show_codex("unit:trebuchet"),
		26: func(): menu._show_codex("hero:voss"),
		33: func(): menu._show_records(),
		40: func(): menu._show_credits(),
		47: func(): menu._show_settings(),
		54: func(): menu._choose_difficulty(6),
		61: func(): menu._toggle_trial("ironhide", 6),
	}
	if steps.has(f):
		steps[f].call()
	if f in [10, 17, 24, 31, 38, 45, 52, 59, 66]:
		_size_ok(["heroes", "codex enemy", "codex soldier", "codex hero", "records", "credits", "settings", "level screen", "trials"][[10, 17, 24, 31, 38, 45, 52, 59, 66].find(f)])
	if f == 66:
		check("trial toggles", "ironhide" in menu.selected_heat)
		# start a battle to test save & resume
		Profile.set_hero("lionheart")
		GameManager.start_level(0, "normal", "campaign", ["ironhide"])
	if f == 80:
		var um = GameManager.unit_manager
		check("battle started with the trial active", GameManager.heat_has("ironhide"))
		var map: GameMap = GameManager.map
		for i in 3:
			var off := 30.0 + i * 12.0
			var pos := map.sample_path(off)
			var dir := map.path_direction(off)
			um.spawn_unit("archer", pos + Vector3(-dir.z, 0, dir.x) * 3.4, 150)
		um.spawn_hero(map.sample_path(60.0) + Vector3(0, 0, 3.5))
		um.units[0].upgrades[0] = 2
		um.units[0].upgrades[1] = 1
		um.units[0].try_specialize(0)
		EconomyManager.add(5000)
		um.units[0].try_specialize(0)
		GameManager.wave_manager.start_next_wave()
		GameManager.wave_manager.force_complete()
	if f == 140:
		BoonManager.pick(BoonManager.current_options[0] if not BoonManager.current_options.is_empty() else BoonManager.BOONS[0])
	if f == 150:
		check("build phase after the draft", GameManager.state == GameManager.State.BUILD)
		check("run snapshot saved", RunSave.has_save())
		saved_units = GameManager.unit_manager.units.size()
		saved_wave = GameManager.wave
		GameManager.to_menu()
	if f == 170:
		var m = get_tree().current_scene
		check("menu offers Continue", RunSave.has_save() and RunSave.summary() != "")
		RunSave.resume()
	if f == 200:
		var um2 = GameManager.unit_manager
		check("resumed with the same soldiers (%d)" % um2.units.size(), um2.units.size() == saved_units)
		check("resumed at the same wave", GameManager.wave == saved_wave)
		var spec_ok := false
		var hero_ok := false
		for u in um2.units:
			if u.spec == "ranger":
				spec_ok = true
			if u.is_hero():
				hero_ok = true
		check("specialization restored", spec_ok)
		check("hero restored", hero_ok and GameManager.hero_deployed())
		check("boons restored", BoonManager.active.size() >= 1)
		check("heat restored", GameManager.heat_has("ironhide"))
		_finish()


func _finish() -> void:
	var fails := 0
	for r in results:
		if not r[1]:
			fails += 1
	print("MenuTest: %d/%d passed" % [results.size() - fails, results.size()])
	get_tree().quit(1 if fails > 0 else 0)
