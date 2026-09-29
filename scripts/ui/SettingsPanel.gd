class_name SettingsPanel
extends RefCounted
## Settings controls shared by the main menu and the in-game pause menu.
## Everything is stored in the player profile and applied immediately.


static func build(on_change: Callable = Callable()) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(UiTheme.label("SETTINGS", 16, UiTheme.GOLD, UiTheme.font_title()))
	for entry in [["Master volume", "master"], ["Effects volume", "sfx"], ["Ambience volume", "ambience"], ["Camera speed", "camera_speed"], ["UI scale", "ui_scale"]]:
		var row := HBoxContainer.new()
		var l := UiTheme.label(entry[0], 16, UiTheme.PARCHMENT)
		l.custom_minimum_size.x = 170
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = {"camera_speed": 0.4, "ui_scale": 0.75}.get(entry[1], 0.0)
		s.max_value = {"camera_speed": 2.0, "ui_scale": 1.4}.get(entry[1], 1.0)
		s.step = 0.05
		s.value = float(Profile.setting(entry[1]))
		s.custom_minimum_size = Vector2(230, 24)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		s.focus_mode = Control.FOCUS_NONE
		s.value_changed.connect(_on_value.bind(entry[1], on_change))
		row.add_child(s)
		vb.add_child(row)
	for entry in [["High graphics (grass, SSAO) - applies next level", "quality"], ["Fullscreen (F11)", "fullscreen"], ["Show battlefield chat", "show_chat"],
			["Colour-blind friendly range circles (blue / orange)", "colorblind"], ["Auto-start waves", "auto_waves"]]:
		var cb := CheckBox.new()
		cb.text = entry[0]
		cb.focus_mode = Control.FOCUS_NONE
		cb.add_theme_color_override("font_color", UiTheme.PARCHMENT)
		if entry[1] == "quality":
			cb.button_pressed = Profile.setting("quality") == "high"
		else:
			cb.button_pressed = bool(Profile.setting(entry[1]))
		cb.toggled.connect(_on_toggle.bind(entry[1], on_change))
		vb.add_child(cb)
	# key bindings (collapsed behind a button to keep the panel short)
	var kb := Button.new()
	kb.text = "Key bindings..."
	kb.focus_mode = Control.FOCUS_NONE
	vb.add_child(kb)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.visible = false
	grid.add_theme_constant_override("h_separation", 8)
	vb.add_child(grid)
	kb.pressed.connect(func(): grid.visible = not grid.visible)
	for a in Keys.ACTIONS:
		var l := UiTheme.label(a[1], 14, UiTheme.PARCHMENT)
		l.custom_minimum_size.x = 130
		grid.add_child(l)
		var b := KeyBindButton.new()
		b.setup(a[0])
		grid.add_child(b)
	var rb := Button.new()
	rb.text = "Reset keys"
	rb.focus_mode = Control.FOCUS_NONE
	rb.pressed.connect(_reset_keys.bind(vb))
	grid.add_child(rb)
	return vb


static func _reset_keys(vb: Control) -> void:
	Keys.reset()
	for b in vb.get_tree().get_nodes_in_group("keybind_buttons"):
		(b as KeyBindButton)._refresh()


static func _on_value(v: float, key: String, on_change: Callable) -> void:
	Profile.set_setting(key, v)
	if on_change.is_valid():
		on_change.call()


static func _on_toggle(on: bool, key: String, on_change: Callable) -> void:
	if key == "quality":
		Profile.set_setting("quality", "high" if on else "low")
	else:
		Profile.set_setting(key, on)
	if on_change.is_valid():
		on_change.call()
