extends Node
## Menu -> battle -> results -> menu scene flow (headless).
var frame := 0


func _ready() -> void:
	if get_parent() != get_tree().root or name != "FlowDriver":
		# re-host a copy on the root so it survives scene changes
		var d: Node = load("res://tests/FlowTest.gd").new()
		d.name = "FlowDriver"
		get_tree().root.add_child.call_deferred(d)
		set_process(false)
		return
	Profile.no_save = true
	Profile.data = Profile._defaults()
	Profile.data["seen_intro"] = true
	Profile.data["login"]["last"] = Profile.today()


func _process(_d: float) -> void:
	if name != "FlowDriver":
		return
	frame += 1
	match frame:
		2:
			get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
		30:
			print("menu loaded: ", get_tree().current_scene.name)
			GameManager.start_level(0, "easy")
		80:
			var ok := GameManager.main != null and is_instance_valid(GameManager.main)
			print("battle loaded: ", ok, " lives=", GameManager.lives, " (easy = 30)")
			GameManager.wave_manager.start_next_wave()
		140:
			print("wave running: ", GameManager.state == GameManager.State.WAVE, " enemies=", GameManager.enemy_manager.alive_count())
			GameManager.lose_lives(999)
		150:
			print("results shown, crowns=", Profile.crowns())
			GameManager.to_menu()
		200:
			print("back at menu: ", get_tree().current_scene.name)
			get_tree().quit()
