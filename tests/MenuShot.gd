extends Node
## Renders the main menu for a visual check (dev tool).
var frame := 0
var out_dir := "/tmp"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
	Profile.no_save = true
	Profile.data = Profile._defaults()
	Profile.data["seen_intro"] = not ("intro" in OS.get_cmdline_user_args())
	Profile.data["login"]["last"] = Profile.today()
	Profile.data["crowns"] = 740
	Profile.data["level"] = 6
	Profile.data["medals"] = {"greenvale": ["easy", "normal", "hard"], "millbrook": ["normal"], "autumn": ["normal"]}
	Profile.data["unlocked"] = ["archer", "knight", "crossbowman", "torch_thrower", "spearman"]
	add_child(load("res://scenes/menu/MainMenu.tscn").instantiate())


func _process(_d: float) -> void:
	frame += 1
	if frame == 20 and "intro" in OS.get_cmdline_user_args():
		var m = get_tree().root.find_child("MainMenu", true, false)
		print("overlay visible=", m.overlay.visible, " box size=", m.overlay_box.size)
		get_tree().quit()
	if frame == 12 and "hero" in OS.get_cmdline_user_args():
		var m2 = get_tree().root.find_child("MainMenu", true, false)
		m2._choose_difficulty(3)
	if frame == 30:
		get_viewport().get_texture().get_image().save_png(out_dir + "/menu.png")
		print("saved menu")
		get_tree().quit()
