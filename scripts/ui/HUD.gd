class_name GameHUD
extends CanvasLayer
## In-battle UI, built in code so there are no fragile node paths:
## top bar (lives, gold, wave, enemies, boons popup, menu), unit shop with live
## 3D portraits (locked units shown with a padlock), start-wave button,
## selected-unit panel (stats, targeting, orders, upgrades, talk, special,
## sell), compact battlefield chat, banners, boon draft, pause menu with
## settings, and the end-of-level results screen with rewards.

const FEED_MAX := 5
const FEED_LIFETIME := 16.0
const CARD_W := 92.0

var root: Control
# top bar
var lbl_lives: Label
var lbl_gold: Label
var lbl_wave: Label
var lbl_enemies: Label
var lbl_omen: Label
var btn_boons: Button
var boons_popup: PanelContainer
var boons_list: VBoxContainer
var speed_buttons: Dictionary = {}
# shop
var shop_buttons: Dictionary = {}
var portraits: Dictionary = {}     ## type -> SubViewport
var portrait_models: Dictionary = {}
var btn_start: Button
var lbl_next: Label
# unit panel
var panel: PanelContainer
var p_portrait: TextureRect
var p_name: Label
var p_sub: Label
var p_hp: ProgressBar
var p_hp_lbl: Label
var p_stats: Dictionary = {}
var p_bonus: Label
var p_target_btns: Array[Button] = []
var p_hold: Button
var p_assist: Button
var p_upg: Array[Button] = []
var p_talk: Button
var p_special: Button
var p_sell: Button
var p_quote: Label
var panel_unit: FriendlyUnit = null
var _panel_refresh: float = 0.0
# chat / banner / overlays
var feed_panel: PanelContainer
var feed_box: VBoxContainer
var feed_items: Array = []
var banner_title: Label
var banner_sub: Label
var banner_tween: Tween
var draft_layer: Control
var draft_cards: HBoxContainer
var btn_reroll: Button
var btn_skip: Button
var draft_title: Label
var draft_sub: Label
var hero_card: Dictionary = {}
var p_upg_title: Label
var p_spec_title: Label
var p_spec_btns: Array[Button] = []
var p_spec_done: Label
var p_hero_box: VBoxContainer
var p_hero_info: Label
var p_ability_btns: Array[Button] = []
var boss_panel: PanelContainer
var boss_name: Label
var boss_bar: ProgressBar
var boss_sub: Label
var btn_auto: Button
var pause_layer: Control
var settings_box: VBoxContainer
var end_layer: Control
var end_box: VBoxContainer
var place_hint: Label
var pause_label: Label
var _results_shown := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)
	_build_portraits()
	_build_top_bar()
	_build_boss_bar()
	_build_shop()
	_build_unit_panel()
	_build_feed()
	_build_banner()
	_build_draft()
	_build_pause_menu()
	_build_end()
	place_hint = UiTheme.label("", 17, UiTheme.PARCHMENT, UiTheme.font_bold())
	place_hint.add_theme_constant_override("outline_size", 6)
	place_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(place_hint)
	pause_label = UiTheme.label("PAUSED", 64, UiTheme.GOLD, UiTheme.font_title())
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.add_theme_constant_override("outline_size", 10)
	pause_label.visible = false
	root.add_child(pause_label)
	_place(pause_label, Control.PRESET_CENTER, 0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)

	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.lives_changed.connect(_on_lives_changed)
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.unit_deselected.connect(_on_unit_deselected)
	EventBus.unit_stats_changed.connect(_on_unit_stats_changed)
	EventBus.npc_said.connect(_on_npc_said)
	EventBus.feed_message.connect(add_feed)
	EventBus.banner.connect(show_banner)
	EventBus.boon_draft_opened.connect(_show_draft)
	EventBus.boon_picked.connect(_on_boon_picked)
	EventBus.omen_changed.connect(_on_omen_changed)
	EventBus.state_changed.connect(_on_state_changed)
	EventBus.game_over.connect(_show_end)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_phase.connect(_on_boss_phase)
	EventBus.relic_gained.connect(func(_r): _refresh_top())
	_refresh_top()
	_refresh_boons()
	var lv: Dictionary = GameManager.level
	var sub := "%s  -  %s" % [GameManager.difficulty_def()["name"], "Endless" if GameManager.mode == "endless" else ("Daily Challenge" if GameManager.mode == "challenge" else "%d waves" % WaveDefs.count())]
	call_deferred("show_banner", String(lv.get("name", "Siegewatch")).to_upper(), sub, UiTheme.GOLD)


# ====================================================================== helpers
func _on_gold_changed(_g: int) -> void:
	_refresh_top()


func _on_lives_changed(_l: int) -> void:
	_refresh_top()
	_pulse(lbl_lives)


func _on_state_changed(_s: int) -> void:
	_refresh_top()


func _on_omen_changed(_o: Dictionary) -> void:
	_refresh_top()
	_refresh_boons()


func _on_boon_picked(_b: Dictionary) -> void:
	_refresh_boons()


func _on_unit_stats_changed(u) -> void:
	if u == panel_unit:
		_refresh_panel()


## Anchor a control to a screen corner/edge using its minimum size.
func _place(c: Control, preset: int, margin: int, grow_h: int, grow_v: int) -> void:
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, margin)
	c.grow_horizontal = grow_h
	c.grow_vertical = grow_v


func _panel(bg: Color = UiTheme.PANEL_BG, border: Color = UiTheme.GOLD_DIM) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(bg, border))
	return p


func _button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = min_w
	b.pressed.connect(cb)
	b.pressed.connect(_click_sound)
	return b


func _click_sound() -> void:
	Sfx.play("click", -8.0)


func _pulse(c: Control) -> void:
	if c == null:
		return
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(1.35, 1.35), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.2)


func _overlay() -> Control:
	var layer_c := Control.new()
	layer_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer_c.mouse_filter = Control.MOUSE_FILTER_STOP
	layer_c.visible = false
	root.add_child(layer_c)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer_c.add_child(dim)
	return layer_c


func _centered(parent: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	center.add_child(vb)
	return vb


func _fade_in(c: Control) -> void:
	c.visible = true
	c.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.25)


# ====================================================================== portraits
func _build_portraits() -> void:
	var types: Array[String] = UnitDefs.ORDER.duplicate()
	if GameManager.hero_id != "":
		types.append("hero")
	for type in types:
		var vp := SubViewport.new()
		vp.size = Vector2i(160, 160)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.msaa_3d = Viewport.MSAA_2X
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.5, 0.45)
		env.ambient_light_energy = 0.6
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		var we := WorldEnvironment.new()
		we.environment = env
		vp.add_child(we)
		var cam := Camera3D.new()
		cam.fov = 28.0 if type != "hero" else 31.0
		if type == "trebuchet":
			cam.fov = 42.0
			cam.position = Vector3(0.4, 2.2, 6.6)
		else:
			cam.position = Vector3(0, 1.45, 4.2)
		cam.rotation_degrees = Vector3(-6, 0, 0)
		vp.add_child(cam)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-35, 35, 0)
		key.light_energy = 1.4
		key.light_color = Color(1.0, 0.9, 0.78)
		vp.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-20, 200, 0)
		rim.light_energy = 1.0
		rim.light_color = Color(0.6, 0.7, 1.0)
		vp.add_child(rim)
		var holder := Node3D.new()
		vp.add_child(holder)
		var build_type: String = type
		if type == "hero":
			build_type = HeroDefs.get_hero(GameManager.hero_id)["base"]
		var rig := ModelBuilder.build_unit(build_type)
		if type == "hero":
			HeroDefs.decorate(rig, GameManager.hero_id)
		holder.add_child(rig["root"])
		holder.rotation_degrees.y = 25.0
		portraits[type] = vp
		portrait_models[type] = holder


func portrait_texture(type: String) -> Texture2D:
	var vp: SubViewport = portraits.get(type)
	return vp.get_texture() if vp else null


# ====================================================================== top bar
func _build_top_bar() -> void:
	var bar := _panel()
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hb)
	lbl_lives = _stat(hb, "heart", "20", UiTheme.PARCHMENT)
	lbl_gold = _stat(hb, "coin", "500", UiTheme.GOLD)
	lbl_wave = _stat(hb, "flag", "Wave 0 / 10", UiTheme.PARCHMENT)
	lbl_enemies = _stat(hb, "skull", "0", UiTheme.PARCHMENT)
	btn_boons = _button("Boons 0", _toggle_boons)
	btn_boons.tooltip_text = "Spoils of War you've claimed this run"
	btn_boons.add_theme_font_override("font", UiTheme.font_title())
	hb.add_child(btn_boons)
	lbl_omen = UiTheme.label("", 15, Color(0.85, 0.55, 1.0), UiTheme.font_bold())
	hb.add_child(lbl_omen)
	_place(bar, Control.PRESET_CENTER_TOP, 8, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	# boons popup under the bar
	boons_popup = _panel(Color(0.07, 0.06, 0.05, 0.96))
	boons_popup.custom_minimum_size = Vector2(420, 0)
	boons_popup.visible = false
	root.add_child(boons_popup)
	var bv := VBoxContainer.new()
	boons_popup.add_child(bv)
	bv.add_child(UiTheme.label("SPOILS OF WAR", 16, UiTheme.GOLD, UiTheme.font_title()))
	boons_list = VBoxContainer.new()
	boons_list.add_theme_constant_override("separation", 4)
	bv.add_child(boons_list)
	_place(boons_popup, Control.PRESET_CENTER_TOP, 0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	boons_popup.offset_top = 70
	# speed + menu (top-right)
	var sp := _panel()
	root.add_child(sp)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	sp.add_child(sh)
	for key in ["pause", "1x", "2x", "3x"]:
		var b := _button("II" if key == "pause" else key, _on_speed.bind(key), 48)
		b.tooltip_text = {"pause": "Pause (P)", "1x": "Normal speed", "2x": "Double speed (F)", "3x": "Triple speed"}[key]
		sh.add_child(b)
		speed_buttons[key] = b
	btn_auto = _button("AUTO", _toggle_auto, 62)
	btn_auto.tooltip_text = "Auto-start the next wave a few seconds after you pick your boon"
	sh.add_child(btn_auto)
	var menu := _button("MENU", open_pause_menu, 80)
	menu.tooltip_text = "Pause menu (Esc)"
	menu.add_theme_font_override("font", UiTheme.font_title())
	sh.add_child(menu)
	_place(sp, Control.PRESET_TOP_RIGHT, 8, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)


# ====================================================================== boss bar
func _build_boss_bar() -> void:
	boss_panel = _panel(Color(0.08, 0.04, 0.04, 0.92), Color(0.7, 0.2, 0.15))
	boss_panel.custom_minimum_size = Vector2(620, 0)
	boss_panel.visible = false
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(boss_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	boss_panel.add_child(v)
	boss_name = UiTheme.label("", 20, Color(1.0, 0.75, 0.55), UiTheme.font_title())
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(boss_name)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(600, 16)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.15, 0.1)
	fill.set_corner_radius_all(3)
	boss_bar.add_theme_stylebox_override("fill", fill)
	v.add_child(boss_bar)
	boss_sub = UiTheme.label("", 13, Color(0.85, 0.75, 0.7), UiTheme.font_italic())
	boss_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(boss_sub)
	_place(boss_panel, Control.PRESET_CENTER_TOP, 0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	boss_panel.offset_top = 66


func _on_boss_spawned(e) -> void:
	if not is_instance_valid(e):
		return
	var d: Dictionary = (e as Enemy).def
	show_banner(String(d.get("title", d.get("name", "BOSS"))).to_upper(), String(d.get("desc", "")), Color(1.0, 0.45, 0.3))
	EventBus.camera_shake.emit(0.4)


func _on_boss_phase(_e, text: String) -> void:
	show_banner(text.to_upper(), "", Color(1.0, 0.55, 0.3))


func _update_boss_bar() -> void:
	var em := GameManager.enemy_manager
	var b: Enemy = em.boss_alive() if em else null
	boss_panel.visible = b != null
	if b == null:
		return
	var others := 0
	for e in em.enemies:
		if is_instance_valid(e) and e.alive and e.is_boss:
			others += 1
	boss_name.text = String(b.def.get("title", b.display_name)) + ("  (x%d)" % others if others > 1 else "")
	boss_bar.max_value = b.max_hp
	boss_bar.value = max(0.0, b.hp)
	var status := "%d / %d" % [int(max(0.0, b.hp)), int(b.max_hp)]
	if b.immune_timer > 0.0:
		status += "   IMMUNE"
	if b.is_hidden():
		status += "   (hidden in the dark)"
	boss_sub.text = status


func _stat(parent: Control, icon: String, text: String, color: Color) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	parent.add_child(h)
	h.add_child(HudIcon.new(icon, Color.WHITE, 24))
	var l := UiTheme.label(text, 22, color, UiTheme.font_title())
	h.add_child(l)
	return l


func _toggle_boons() -> void:
	boons_popup.visible = not boons_popup.visible
	if boons_popup.visible:
		_refresh_boons()


func _on_speed(key: String) -> void:
	match key:
		"pause":
			GameManager.set_paused(not GameManager.paused)
		"1x":
			GameManager.set_paused(false)
			GameManager.set_speed(1.0)
		"2x":
			GameManager.set_paused(false)
			GameManager.set_speed(2.0)
		"3x":
			GameManager.set_paused(false)
			GameManager.set_speed(3.0)
	_refresh_speed()


func _toggle_auto() -> void:
	Profile.set_setting("auto_waves", not bool(Profile.setting("auto_waves")))
	_refresh_speed()


func _refresh_speed() -> void:
	for k in speed_buttons:
		var active: bool = (k == "pause" and GameManager.paused) or (not GameManager.paused and ((k == "1x" and GameManager.speed == 1.0) or (k == "2x" and GameManager.speed == 2.0) or (k == "3x" and GameManager.speed == 3.0)))
		(speed_buttons[k] as Button).modulate = Color(1.0, 0.85, 0.4) if active else Color(1, 1, 1)
	pause_label.visible = GameManager.paused and not pause_layer.visible
	if btn_auto:
		btn_auto.modulate = Color(0.55, 1.0, 0.6) if bool(Profile.setting("auto_waves")) else Color.WHITE


func _refresh_top() -> void:
	if lbl_gold == null:
		return
	lbl_gold.text = str(EconomyManager.gold)
	lbl_lives.text = str(GameManager.lives)
	lbl_lives.add_theme_color_override("font_color", UiTheme.RED if GameManager.lives <= 5 else UiTheme.PARCHMENT)
	if WaveDefs.count() > 0:
		lbl_wave.text = "Wave %d / %d" % [GameManager.wave, WaveDefs.count()]
	else:
		lbl_wave.text = "Wave %d" % GameManager.wave
	var wm := GameManager.wave_manager
	lbl_enemies.text = str(wm.enemies_remaining()) if wm else "0"
	var omen := BoonManager.current_omen
	lbl_omen.text = omen.get("name", "")
	lbl_omen.tooltip_text = omen.get("desc", "")
	lbl_omen.mouse_filter = Control.MOUSE_FILTER_PASS if not omen.is_empty() else Control.MOUSE_FILTER_IGNORE
	btn_boons.text = _boons_text()
	_refresh_start_button()
	_refresh_speed()


func _boons_text() -> String:
	var t := "Boons %d" % BoonManager.active.size()
	if not BoonManager.relics.is_empty():
		t += "  Relics %d" % BoonManager.relics.size()
	return t


func _refresh_boons() -> void:
	if boons_list == null:
		return
	for c in boons_list.get_children():
		c.queue_free()
	for r in BoonManager.relics:
		var rl := UiTheme.label("RELIC  %s  -  %s" % [r["name"], r["desc"]], 15, BoonManager.RARITY_COLORS["relic"], UiTheme.font_bold())
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size.x = 400
		boons_list.add_child(rl)
	var counts := {}
	var order: Array = []
	for b in BoonManager.active:
		if not counts.has(b["id"]):
			order.append(b)
		counts[b["id"]] = counts.get(b["id"], 0) + 1
	if not BoonManager.current_omen.is_empty():
		var o := UiTheme.label("%s - %s" % [BoonManager.current_omen["name"], BoonManager.current_omen["desc"]], 15, Color(0.85, 0.55, 1.0))
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		o.custom_minimum_size.x = 400
		boons_list.add_child(o)
	if order.is_empty():
		boons_list.add_child(UiTheme.label("None yet. Clear a wave to claim one.", 15, Color(0.6, 0.56, 0.5), UiTheme.font_italic()))
		return
	for b in order:
		var rc: Color = BoonManager.RARITY_COLORS.get(b["rarity"], Color.WHITE)
		var n: int = counts[b["id"]]
		var l := UiTheme.label("%s%s  -  %s" % [b["name"], (" x%d" % n) if n > 1 else "", b["desc"]], 15, rc)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400
		boons_list.add_child(l)
	btn_boons.text = _boons_text()


# ====================================================================== shop / start wave
func _build_shop() -> void:
	var shop := _panel()
	root.add_child(shop)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	shop.add_child(hb)
	if GameManager.hero_id != "":
		_build_hero_card(hb)
	var i := 1
	for type in UnitDefs.ORDER:
		var d: Dictionary = UnitDefs.get_def(type)
		var unlocked := Profile.is_unit_unlocked(type)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(CARD_W, 124)
		if unlocked:
			b.tooltip_text = "%s  [%d]\n%s\nDamage %d  |  Range %d  |  %.1f atk/s\nSpecial: %s - %s" % [
				d["name"], i, d["role"], d["damage"], d["range"], 1.0 / float(d["interval"]),
				d["special"]["name"], d["special"]["desc"]]
		else:
			b.tooltip_text = "%s (locked)\nBeat %s to recruit this soldier." % [d["name"], LevelDefs.unlock_source(type)]
		b.pressed.connect(_on_shop_pressed.bind(type))
		hb.add_child(b)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", -2)
		b.add_child(vb)
		var tr := TextureRect.new()
		tr.texture = portrait_texture(type)
		tr.custom_minimum_size = Vector2(CARD_W, 76)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not unlocked:
			tr.modulate = Color(0.15, 0.15, 0.15, 0.9)
		vb.add_child(tr)
		var nm_u := String(d["name"]).to_upper()
		var nl := UiTheme.label(nm_u, 11 if nm_u.length() <= 11 else 9, UiTheme.CLASS_COLORS.get(type, UiTheme.PARCHMENT), UiTheme.font_title())
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.clip_text = true
		nl.custom_minimum_size.x = CARD_W
		vb.add_child(nl)
		var cl := UiTheme.label("", 15, UiTheme.GOLD, UiTheme.font_bold())
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(cl)
		var hk := UiTheme.label("%d" % i, 11, Color(0.6, 0.55, 0.48))
		hk.position = Vector2(5, 2)
		b.add_child(hk)
		if not unlocked:
			var lock := UiTheme.label("LOCKED", 12, Color(0.75, 0.7, 0.6), UiTheme.font_title())
			lock.position = Vector2(22, 32)
			b.add_child(lock)
		shop_buttons[type] = {"button": b, "cost": cl, "unlocked": unlocked}
		i += 1
	_place(shop, Control.PRESET_CENTER_BOTTOM, 8, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	# start wave button (bottom-right)
	var sp := _panel()
	sp.custom_minimum_size = Vector2(300, 0)
	root.add_child(sp)
	var vb2 := VBoxContainer.new()
	sp.add_child(vb2)
	btn_start = _button("START WAVE 1", _on_start_wave)
	btn_start.custom_minimum_size = Vector2(280, 60)
	btn_start.add_theme_font_override("font", UiTheme.font_title())
	btn_start.add_theme_font_size_override("font_size", 22)
	btn_start.add_theme_stylebox_override("normal", UiTheme.button_style(Color(0.35, 0.12, 0.08), UiTheme.GOLD))
	btn_start.add_theme_stylebox_override("hover", UiTheme.button_style(Color(0.5, 0.18, 0.1), Color(1, 0.9, 0.6)))
	btn_start.tooltip_text = "Start the next wave (Space)"
	vb2.add_child(btn_start)
	lbl_next = UiTheme.label("", 13, Color(0.8, 0.76, 0.68))
	lbl_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_next.custom_minimum_size = Vector2(280, 52)
	vb2.add_child(lbl_next)
	_place(sp, Control.PRESET_BOTTOM_RIGHT, 8, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)


func _build_hero_card(hb: HBoxContainer) -> void:
	var h := HeroDefs.get_hero(GameManager.hero_id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(CARD_W + 10, 124)
	b.add_theme_stylebox_override("normal", UiTheme.button_style(Color(0.22, 0.15, 0.05), UiTheme.GOLD))
	b.add_theme_stylebox_override("hover", UiTheme.button_style(Color(0.32, 0.22, 0.08), Color(1, 0.9, 0.6)))
	b.tooltip_text = "HERO: %s, %s  [H]\n%s\nAura: %s\nFree, but you can only place them once. Gains a level every wave (max %d)." % [
		h["name"], h["title"], h["blurb"], HeroDefs.aura_text(GameManager.hero_id), HeroDefs.MAX_LEVEL]
	b.pressed.connect(func(): GameManager.placement_manager.begin_hero())
	hb.add_child(b)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", -2)
	b.add_child(vb)
	var tr := TextureRect.new()
	tr.texture = portrait_texture("hero")
	tr.custom_minimum_size = Vector2(CARD_W + 10, 76)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tr)
	var nl := UiTheme.label(String(h["short"]).to_upper(), 12, UiTheme.GOLD, UiTheme.font_title())
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nl)
	var cl := UiTheme.label("FREE", 14, Color(1.0, 0.9, 0.55), UiTheme.font_bold())
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(cl)
	var hk := UiTheme.label("H", 11, Color(0.8, 0.7, 0.45))
	hk.position = Vector2(5, 2)
	b.add_child(hk)
	var tag := UiTheme.label("HERO", 10, UiTheme.GOLD, UiTheme.font_title())
	tag.position = Vector2(CARD_W - 28, 2)
	b.add_child(tag)
	hero_card = {"button": b, "status": cl}


func _on_shop_pressed(type: String) -> void:
	var pm := GameManager.placement_manager
	if pm.active_type == type:
		pm.cancel()
	else:
		pm.begin(type)


func _on_start_wave() -> void:
	GameManager.wave_manager.start_next_wave()


func _refresh_start_button() -> void:
	if btn_start == null:
		return
	var wm := GameManager.wave_manager
	if wm == null:
		return
	var n: int = wm.next_wave_number()
	match GameManager.state:
		GameManager.State.WAVE:
			btn_start.text = "WAVE %d IN PROGRESS" % GameManager.wave
			btn_start.disabled = true
			lbl_next.text = "Hold the road!"
		GameManager.State.DRAFT:
			btn_start.text = "CHOOSE A BOON"
			btn_start.disabled = true
			lbl_next.text = "Pick your Spoils of War first."
		GameManager.State.BUILD:
			btn_start.text = ("START WAVE %d" % n) if not WaveDefs.is_boss_wave(n) else ("BOSS WAVE %d" % n)
			btn_start.disabled = false
			var txt := "Next: " + WaveDefs.describe(n)
			if not BoonManager.current_omen.is_empty():
				txt += "\n" + BoonManager.current_omen["name"] + ": " + BoonManager.current_omen["desc"]
			lbl_next.text = txt
		_:
			btn_start.disabled = true


# ====================================================================== unit panel
func _build_unit_panel() -> void:
	panel = _panel()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -352
	panel.offset_right = -10
	panel.offset_top = 70
	panel.offset_bottom = -160
	panel.visible = false
	root.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	scroll.add_child(vb)
	var head := HBoxContainer.new()
	vb.add_child(head)
	p_portrait = TextureRect.new()
	p_portrait.custom_minimum_size = Vector2(70, 70)
	p_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(p_portrait)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	p_name = UiTheme.label("Sir Rowan", 22, UiTheme.GOLD, UiTheme.font_title())
	p_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(p_name)
	p_sub = UiTheme.label("Archer - Cocky", 16, UiTheme.PARCHMENT)
	hv.add_child(p_sub)
	var close := _button("X", _deselect)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	head.add_child(close)
	var hpbox := Control.new()
	hpbox.custom_minimum_size = Vector2(0, 20)
	vb.add_child(hpbox)
	p_hp = ProgressBar.new()
	p_hp.show_percentage = false
	p_hp.set_anchors_preset(Control.PRESET_FULL_RECT)
	hpbox.add_child(p_hp)
	p_hp_lbl = UiTheme.label("", 14, Color.WHITE, UiTheme.font_bold())
	p_hp_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	p_hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hpbox.add_child(p_hp_lbl)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	vb.add_child(grid)
	for key in ["Level", "Kills", "Damage", "Range", "Atk/s", "Target", "Order", "Dealt"]:
		grid.add_child(UiTheme.label(key, 14, Color(0.68, 0.62, 0.52)))
		var v := UiTheme.label("-", 16, UiTheme.PARCHMENT, UiTheme.font_bold())
		grid.add_child(v)
		p_stats[key] = v
	p_bonus = UiTheme.label("", 14, Color(0.6, 0.85, 1.0), UiTheme.font_italic())
	p_bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(p_bonus)
	vb.add_child(_section("TARGETING"))
	var tg := HBoxContainer.new()
	tg.add_theme_constant_override("separation", 3)
	vb.add_child(tg)
	for i in FriendlyUnit.TARGETING_NAMES.size():
		var b := _button(FriendlyUnit.TARGETING_NAMES[i], _on_target_mode.bind(i))
		b.add_theme_font_size_override("font_size", 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = ["Enemy closest to the castle", "Enemy furthest from the castle", "Enemy with the most health",
			"Enemy with the least health", "Enemy nearest to this soldier"][i]
		tg.add_child(b)
		p_target_btns.append(b)
	vb.add_child(_section("ORDERS"))
	var od := HBoxContainer.new()
	vb.add_child(od)
	p_hold = _button("Hold Fire", _on_hold)
	p_hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_hold.tooltip_text = "Stop attacking until ordered otherwise"
	od.add_child(p_hold)
	p_assist = _button("Assist Nearby", _on_assist)
	p_assist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_assist.tooltip_text = "Focus the same targets as the nearest ally"
	od.add_child(p_assist)
	p_upg_title = _section("UPGRADES")
	vb.add_child(p_upg_title)
	for i in 3:
		var ub := _button("", _on_upgrade.bind(i))
		ub.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ub.add_theme_font_size_override("font_size", 15)
		vb.add_child(ub)
		p_upg.append(ub)
	p_spec_title = _section("SPECIALIZE (TIER 3)")
	vb.add_child(p_spec_title)
	for i in 2:
		var sb := _button("", _on_specialize.bind(i))
		sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		sb.add_theme_font_size_override("font_size", 15)
		sb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(sb)
		p_spec_btns.append(sb)
	p_spec_done = UiTheme.label("", 14, UiTheme.GOLD, UiTheme.font_italic())
	p_spec_done.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(p_spec_done)
	# hero-only: level, unique mechanic and the two abilities
	p_hero_box = VBoxContainer.new()
	p_hero_box.add_theme_constant_override("separation", 4)
	vb.add_child(p_hero_box)
	p_hero_box.add_child(_section("HERO"))
	p_hero_info = UiTheme.label("", 13, Color(0.85, 0.8, 0.68))
	p_hero_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_hero_info.custom_minimum_size.x = 300
	p_hero_box.add_child(p_hero_info)
	p_hero_box.add_child(_section("ABILITIES"))
	for i in 2:
		var ab := _button("", _on_hero_ability.bind(i))
		ab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ab.add_theme_font_size_override("font_size", 15)
		ab.custom_minimum_size.y = 40
		ab.add_theme_font_override("font", UiTheme.font_title())
		p_hero_box.add_child(ab)
		p_ability_btns.append(ab)
	var mv := UiTheme.label("Right-click the ground to move the hero.", 13, Color(0.6, 0.85, 1.0), UiTheme.font_italic())
	p_hero_box.add_child(mv)
	vb.add_child(_section("COMMAND"))
	var ts := HBoxContainer.new()
	vb.add_child(ts)
	p_talk = _button("TALK", _on_talk)
	p_talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_talk.tooltip_text = "Speak with this soldier (T)"
	p_talk.add_theme_font_override("font", UiTheme.font_title())
	ts.add_child(p_talk)
	p_special = _button("SPECIAL", _on_special)
	p_special.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_special.add_theme_font_override("font", UiTheme.font_title())
	p_special.tooltip_text = "Use special ability (G)"
	ts.add_child(p_special)
	var qp := _panel(Color(0.93, 0.88, 0.76, 0.95), Color(0.45, 0.35, 0.2))
	vb.add_child(qp)
	p_quote = UiTheme.label("", 15, UiTheme.INK, UiTheme.font_italic())
	p_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p_quote.custom_minimum_size = Vector2(290, 40)
	qp.add_child(p_quote)
	p_sell = _button("SELL", _on_sell)
	p_sell.add_theme_color_override("font_color", Color(1.0, 0.7, 0.6))
	vb.add_child(p_sell)


func _deselect() -> void:
	GameManager.unit_manager.deselect()


func _section(t: String) -> Control:
	return UiTheme.label(t, 13, UiTheme.GOLD_DIM, UiTheme.font_title())


func _on_specialize(i: int) -> void:
	if is_instance_valid(panel_unit):
		panel_unit.try_specialize(i)
		_refresh_panel()


func _on_hero_ability(i: int) -> void:
	var pm := GameManager.placement_manager
	if pm:
		pm.begin_ability(i)


func _on_unit_selected(u) -> void:
	panel_unit = u
	panel.visible = true
	p_portrait.texture = portrait_texture("hero" if panel_unit.is_hero() else panel_unit.unit_type)
	p_quote.text = "\"%s\"" % panel_unit.last_line if panel_unit.last_line != "" else "Click TALK to speak with %s." % panel_unit.display_name
	_refresh_panel()


func _on_unit_deselected() -> void:
	panel_unit = null
	panel.visible = false


func _refresh_panel() -> void:
	var u := panel_unit
	if u == null or not is_instance_valid(u):
		panel.visible = false
		return
	var d := u.def
	p_name.text = u.display_name
	p_name.add_theme_color_override("font_color", UiTheme.CLASS_COLORS.get(u.unit_type, UiTheme.GOLD))
	p_sub.text = "%s  -  %s" % [u.class_name_text(), u.personality]
	if u.is_hero():
		p_sub.text = "Hero  -  %s" % HeroDefs.get_hero(u.hero_id)["title"]
	var mh := u.get_max_hp()
	p_hp.max_value = mh
	p_hp.value = u.hp
	p_hp_lbl.text = "DOWNED (%.0fs)" % u.downed_timer if u.downed else "%d / %d HP" % [int(u.hp), int(mh)]
	p_stats["Level"].text = ("Hero %d" % u.hero_level) if u.is_hero() else str(u.get_level())
	p_stats["Kills"].text = str(u.kills)
	p_stats["Damage"].text = "%d" % int(round(u.get_damage()))
	p_stats["Range"].text = "%.1f" % u.get_range()
	p_stats["Atk/s"].text = "%.2f" % u.attacks_per_second()
	p_stats["Target"].text = FriendlyUnit.TARGETING_NAMES[u.targeting]
	var order := u.command
	if u.command == "Assist" and is_instance_valid(u.assist_unit):
		order = "Assist " + u.assist_unit.display_name.get_slice(" ", u.assist_unit.display_name.get_slice_count(" ") - 1)
	p_stats["Order"].text = order
	p_stats["Dealt"].text = str(int(u.damage_dealt))
	var bon := u.active_bonuses()
	p_bonus.text = " | ".join(bon) if not bon.is_empty() else ""
	p_bonus.visible = not bon.is_empty()
	for i in p_target_btns.size():
		p_target_btns[i].modulate = Color(1.0, 0.82, 0.35) if i == u.targeting else Color(0.85, 0.85, 0.85)
	p_hold.text = "Weapons Free" if u.command == "Hold Fire" else "Hold Fire"
	p_hold.modulate = Color(1.0, 0.6, 0.5) if u.command == "Hold Fire" else Color.WHITE
	p_assist.text = "Stop Assisting" if u.command == "Assist" else "Assist Nearby"
	var paths: Array = d["paths"]
	for i in 3:
		var path: Dictionary = paths[i]
		var tier: int = u.upgrades[i]
		var pips := ""
		for k in UnitDefs.MAX_TIER:
			pips += "#" if k < tier else "-"
		var cost := u.upgrade_cost(i)
		if cost < 0:
			p_upg[i].text = "%s  [%s]  MAX" % [path["name"], pips]
			p_upg[i].disabled = true
		else:
			p_upg[i].text = "%s  [%s]   %d gold" % [path["name"], pips, cost]
			p_upg[i].disabled = not EconomyManager.can_afford(cost)
		var stat: String = path["stat"]
		var per: float = path["per"]
		if stat == "pierce" or stat == "chain":
			p_upg[i].tooltip_text = "+%d %s per tier" % [int(per), stat]
		else:
			p_upg[i].tooltip_text = "+%d%% %s per tier" % [int(per * 100), stat.replace("_", " ")]
	_refresh_upgrade_previews(u)
	var hero := u.is_hero()
	p_upg_title.visible = not hero
	for b in p_upg:
		b.visible = not hero
	p_special.visible = not hero
	p_sell.visible = not hero
	p_hero_box.visible = hero
	_refresh_spec(u)
	if hero:
		_refresh_hero_panel(u)
	var sp: Dictionary = d["special"]
	if u.special_cd > 0.0:
		p_special.text = "%s (%ds)" % [String(sp["name"]).to_upper(), int(ceil(u.special_cd))]
		p_special.disabled = true
	else:
		p_special.text = String(sp["name"]).to_upper()
		p_special.disabled = u.downed
	p_special.tooltip_text = "%s\n%s\nCooldown %ds (G)" % [sp["name"], sp["desc"], int(u.special_cooldown_total())]
	p_sell.text = "SELL  (+%d gold)" % u.sell_value()


## Tooltips that show exactly what an upgrade changes (before -> after).
func _refresh_upgrade_previews(u: FriendlyUnit) -> void:
	var paths: Array = u.def.get("paths", [])
	for i in mini(3, paths.size()):
		if u.upgrade_cost(i) < 0:
			continue
		var stat: String = paths[i]["stat"]
		var before := _stat_value(u, stat)
		u.upgrades[i] += 1
		var after := _stat_value(u, stat)
		u.upgrades[i] -= 1
		var nm: String = {"damage": "Damage", "range": "Range", "speed": "Attacks/s", "max_hp": "Health", "radius": "Blast radius",
			"pierce": "Pierce", "chain": "Chains", "heal": "Healing"}.get(stat, stat)
		p_upg[i].tooltip_text = "%s: %s -> %s" % [nm, _fmt(before), _fmt(after)]


func _stat_value(u: FriendlyUnit, stat: String) -> float:
	match stat:
		"damage":
			return u.get_damage() / (1.12 if u.blessed else 1.0)
		"range":
			return u.get_range()
		"speed":
			return u.attacks_per_second()
		"max_hp":
			return u.get_max_hp()
		"radius":
			return u.call("blast_radius") if u.has_method("blast_radius") else 0.0
		"pierce":
			return float(u.call("pierce_count")) if u.has_method("pierce_count") else 0.0
		"chain":
			return float(u.call("chain_count")) if u.has_method("chain_count") else 0.0
		"heal":
			return u.call("heal_amount") if u.has_method("heal_amount") else 0.0
	return 0.0


func _fmt(v: float) -> String:
	return ("%.2f" % v) if v < 10.0 else str(int(round(v)))


func _refresh_spec(u: FriendlyUnit) -> void:
	var opts: Array = UnitDefs.SPECS.get(u.unit_type, [])
	var show_choice := u.can_specialize()
	p_spec_title.visible = not u.is_hero() and (show_choice or u.spec != "" or (not opts.is_empty()))
	for i in 2:
		var b := p_spec_btns[i]
		b.visible = show_choice and i < opts.size()
		if b.visible:
			var sp: Dictionary = opts[i]
			var cost := u.spec_cost(i)
			b.text = "%s  -  %d gold" % [sp["name"], cost]
			b.tooltip_text = sp["desc"]
			b.disabled = not EconomyManager.can_afford(cost)
	if u.is_hero() or opts.is_empty():
		p_spec_done.text = ""
	elif u.spec != "":
		p_spec_done.text = "%s: %s" % [u.spec_def()["name"], u.spec_def()["desc"]]
	elif not show_choice:
		var n: int = u.upgrades[0] + u.upgrades[1] + u.upgrades[2]
		p_spec_done.text = "Buy %d more upgrade tier%s to specialize: %s or %s." % [UnitDefs.SPEC_UNLOCK_TIERS - n,
			"" if UnitDefs.SPEC_UNLOCK_TIERS - n == 1 else "s", opts[0]["name"], opts[1]["name"]]
	else:
		p_spec_done.text = ""
	p_spec_done.visible = p_spec_done.text != ""


func _refresh_hero_panel(u: FriendlyUnit) -> void:
	var h := HeroDefs.get_hero(u.hero_id)
	var next_ms := ""
	for lv in HeroDefs.MILESTONES:
		if int(lv) > u.hero_level:
			next_ms = "Lv %d: %s" % [lv, HeroDefs.MILESTONES[lv]]
			break
	p_hero_info.text = "Level %d / %d   (+1 per wave cleared)\n%s\n%s%s" % [u.hero_level, HeroDefs.MAX_LEVEL,
		h.get("unique", ""), h.get("passive", ""), ("\nNext: " + next_ms) if next_ms != "" else ""]
	if u.kit == null:
		return
	for i in 2:
		var ab: Dictionary = u.kit.ability_def(i)
		var b := p_ability_btns[i]
		var key := "Z" if i == 0 else "X"
		if not u.kit.ability_unlocked(i):
			b.text = "%s  [%s]  unlocks at Lv %d" % [ab["name"], key, int(ab["level"])]
			b.disabled = true
		elif u.kit.cds[i] > 0.0:
			b.text = "%s  [%s]  %ds" % [ab["name"], key, int(ceil(u.kit.cds[i]))]
			b.disabled = true
		else:
			b.text = "%s  [%s]  READY" % [ab["name"], key]
			b.disabled = u.downed
		b.tooltip_text = "%s\n%s\nCooldown %ds" % [ab["name"], ab["desc"], int(u.kit.cooldown_total(i))]


func _on_target_mode(i: int) -> void:
	if is_instance_valid(panel_unit):
		panel_unit.set_targeting(i)


func _on_hold() -> void:
	if is_instance_valid(panel_unit):
		panel_unit.toggle_hold_fire()


func _on_assist() -> void:
	if not is_instance_valid(panel_unit):
		return
	if panel_unit.command == "Assist":
		panel_unit.set_assist(null)
		return
	var ally: FriendlyUnit = GameManager.unit_manager.nearest_unit(panel_unit.global_position, 30.0, "", false, panel_unit)
	if ally == null:
		add_feed(panel_unit.display_name, "There's nobody nearby to assist.", UiTheme.RED)
		return
	panel_unit.set_assist(ally)


func _on_upgrade(i: int) -> void:
	if is_instance_valid(panel_unit) and not panel_unit.try_upgrade(i):
		add_feed("Quartermaster", "Not enough gold for that upgrade.", UiTheme.RED)


func _on_talk() -> void:
	if is_instance_valid(panel_unit):
		panel_unit.talk()


func _on_special() -> void:
	if is_instance_valid(panel_unit):
		panel_unit.use_special()


func _on_sell() -> void:
	if is_instance_valid(panel_unit):
		GameManager.unit_manager.sell(panel_unit)


# ====================================================================== chat (compact)
func _build_feed() -> void:
	feed_panel = _panel(Color(0.05, 0.04, 0.03, 0.5), Color(0.4, 0.33, 0.2, 0.5))
	feed_panel.custom_minimum_size = Vector2(330, 0)
	feed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_panel.clip_contents = true
	var st := UiTheme.panel_style(Color(0.05, 0.04, 0.03, 0.5), Color(0.4, 0.33, 0.2, 0.5), 5, 1)
	st.set_content_margin_all(6)
	feed_panel.add_theme_stylebox_override("panel", st)
	root.add_child(feed_panel)
	feed_box = VBoxContainer.new()
	feed_box.add_theme_constant_override("separation", 1)
	feed_box.custom_minimum_size = Vector2(318, 112)
	feed_box.alignment = BoxContainer.ALIGNMENT_END
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_panel.add_child(feed_box)
	_place(feed_panel, Control.PRESET_BOTTOM_LEFT, 8, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	feed_panel.visible = bool(Profile.setting("show_chat"))


func _on_npc_said(unit, text: String) -> void:
	var u := unit as FriendlyUnit
	add_feed(u.display_name, "\"%s\"" % text, UiTheme.CLASS_COLORS.get(u.unit_type, UiTheme.GOLD))
	if u == panel_unit:
		p_quote.text = "\"%s\"" % text


func add_feed(speaker: String, text: String, color: Color) -> void:
	if feed_box == null:
		return
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.custom_minimum_size = Vector2(318, 0)
	rt.add_theme_font_override("normal_font", UiTheme.font_body())
	rt.add_theme_font_override("bold_font", UiTheme.font_bold())
	rt.add_theme_font_size_override("normal_font_size", 13)
	rt.add_theme_font_size_override("bold_font_size", 13)
	rt.text = "[b][color=#%s]%s:[/color][/b] %s" % [color.to_html(false), speaker, text.replace("[", "(")]
	feed_box.add_child(rt)
	feed_items.append({"node": rt, "age": 0.0})
	while feed_items.size() > FEED_MAX:
		var old: Dictionary = feed_items.pop_front()
		(old["node"] as Node).queue_free()


# ====================================================================== banner
func _build_banner() -> void:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(1000, 150)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vb)
	banner_title = UiTheme.label("", 58, UiTheme.GOLD, UiTheme.font_title())
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_title.add_theme_constant_override("outline_size", 12)
	vb.add_child(banner_title)
	banner_sub = UiTheme.label("", 22, UiTheme.PARCHMENT, UiTheme.font_bold())
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_sub.add_theme_constant_override("outline_size", 8)
	vb.add_child(banner_sub)
	vb.modulate.a = 0.0
	banner_title.set_meta("box", vb)
	_place(vb, Control.PRESET_CENTER_TOP, 0, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	vb.offset_top += 120
	vb.offset_bottom += 120


func show_banner(title: String, sub: String, color: Color) -> void:
	var vb: Control = banner_title.get_meta("box")
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	if banner_tween:
		banner_tween.kill()
	banner_tween = create_tween()
	vb.modulate.a = 0.0
	banner_tween.tween_property(vb, "modulate:a", 1.0, 0.3)
	banner_tween.tween_interval(2.6)
	banner_tween.tween_property(vb, "modulate:a", 0.0, 0.6)


# ====================================================================== boon draft
func _build_draft() -> void:
	draft_layer = _overlay()
	(draft_layer.get_child(0) as ColorRect).color = Color(0, 0, 0, 0.5)
	var vb := _centered(draft_layer)
	draft_title = UiTheme.label("SPOILS OF WAR", 54, UiTheme.GOLD, UiTheme.font_title())
	draft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_title.add_theme_constant_override("outline_size", 10)
	vb.add_child(draft_title)
	draft_sub = UiTheme.label("", 20, UiTheme.PARCHMENT, UiTheme.font_italic())
	draft_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	draft_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	draft_sub.custom_minimum_size = Vector2(900, 0)
	vb.add_child(draft_sub)
	draft_cards = HBoxContainer.new()
	draft_cards.add_theme_constant_override("separation", 22)
	draft_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(draft_cards)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(foot)
	foot.add_theme_constant_override("separation", 16)
	btn_reroll = _button("Reroll", _on_reroll, 220)
	foot.add_child(btn_reroll)
	btn_skip = _button("Pillage instead", _on_skip, 220)
	btn_skip.tooltip_text = "Skip the boon and take some gold"
	foot.add_child(btn_skip)


func _show_draft(options: Array) -> void:
	for c in draft_cards.get_children():
		c.queue_free()
	for b in options:
		draft_cards.add_child(_boon_card(b))
	var ev := BoonManager.current_event
	if ev.is_empty():
		draft_title.text = "SPOILS OF WAR"
		draft_title.add_theme_color_override("font_color", UiTheme.GOLD)
		draft_sub.text = "The King rewards your victory. Choose one boon - it lasts for the rest of this level."
	else:
		draft_title.text = ev["title"]
		draft_title.add_theme_color_override("font_color", BoonManager.RARITY_COLORS["relic" if ev.get("relic", false) else "event"])
		draft_sub.text = ev["text"]
	var cost := BoonManager.reroll_cost()
	btn_reroll.visible = ev.is_empty() and cost >= 0
	btn_skip.visible = ev.is_empty()
	btn_reroll.text = "Reroll (free)" if cost == 0 else "Reroll (%d gold)" % cost
	btn_reroll.disabled = not EconomyManager.can_afford(cost)
	btn_skip.text = "Pillage instead (+%d gold)" % BoonManager.skip_reward()
	_fade_in(draft_layer)
	Sfx.play("boon", -4.0)


func _boon_card(b: Dictionary) -> Control:
	var rc: Color = BoonManager.RARITY_COLORS.get(b["rarity"], Color.WHITE)
	var p := PanelContainer.new()
	var st := UiTheme.panel_style(Color(0.1, 0.08, 0.06, 0.97), rc, 10, 3)
	st.set_content_margin_all(18)
	st.shadow_color = Color(rc.r, rc.g, rc.b, 0.35)
	st.shadow_size = 14
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(290, 330)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	p.add_child(vb)
	var rtext := "CURSED PACT" if b["rarity"] == "cursed" else String(b["rarity"]).to_upper()
	if b.get("event", false):
		rtext = "CHOICE" if b["rarity"] == "event" else rtext
	if b.get("relic", false):
		rtext = "RELIC"
	var req: Array = b.get("req", [])
	if not req.is_empty() and not b.get("event", false):
		var names: Array[String] = []
		for r in req:
			names.append("Hero" if r == "hero" else String(UnitDefs.get_def(r)["name"]))
		rtext += "  -  " + " & ".join(names)
	var rl := UiTheme.label(rtext, 14, rc, UiTheme.font_title())
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(rl)
	var icon := HudIcon.new("moon" if b["rarity"] == "cursed" else ("flag" if b["rarity"] == "event" else ("coin" if b.get("relic", false) else "star")), rc, 54)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(icon)
	var nl := UiTheme.label(b["name"], 26, UiTheme.PARCHMENT, UiTheme.font_title())
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(250, 0)
	vb.add_child(nl)
	var dl := UiTheme.label(b["desc"], 18, Color(0.85, 0.8, 0.7))
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size = Vector2(250, 90)
	dl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(dl)
	var owned := BoonManager.count_owned(b["id"])
	if owned > 0:
		var ol := UiTheme.label("Owned x%d (stacks)" % owned, 14, UiTheme.GOLD_DIM, UiTheme.font_italic())
		ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(ol)
	var cost := int(b.get("cost", 0))
	var choose := _button("CHOOSE" if cost == 0 else "PAY %d GOLD" % cost, _on_boon_chosen.bind(b))
	choose.disabled = not BoonManager.can_pick(b)
	choose.add_theme_font_override("font", UiTheme.font_title())
	choose.add_theme_font_size_override("font_size", 20)
	choose.custom_minimum_size = Vector2(0, 44)
	vb.add_child(choose)
	return p


func _on_boon_chosen(b: Dictionary) -> void:
	if not BoonManager.can_pick(b):
		return
	draft_layer.visible = false
	BoonManager.pick(b)


func _on_skip() -> void:
	draft_layer.visible = false
	BoonManager.skip()


func _on_reroll() -> void:
	BoonManager.reroll(GameManager.wave)


# ====================================================================== pause menu & settings
func _build_pause_menu() -> void:
	pause_layer = _overlay()
	var vb := _centered(pause_layer)
	var box := _panel(Color(0.08, 0.065, 0.05, 0.97), UiTheme.GOLD)
	vb.add_child(box)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	inner.custom_minimum_size = Vector2(460, 0)
	box.add_child(inner)
	var t := UiTheme.label("PAUSED", 44, UiTheme.GOLD, UiTheme.font_title())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(t)
	var sub := UiTheme.label("%s  -  %s" % [GameManager.level.get("name", ""), GameManager.difficulty_def()["name"]], 18, UiTheme.PARCHMENT, UiTheme.font_italic())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(sub)
	for entry in [["RESUME", close_pause_menu], ["RESTART LEVEL", _on_restart], ["SETTINGS", _toggle_settings],
			["SAVE & QUIT TO MAP", _on_quit], ["ABANDON RUN", _on_abandon]]:
		var b := _button(entry[0], entry[1])
		b.custom_minimum_size.y = 46
		b.add_theme_font_override("font", UiTheme.font_title())
		b.add_theme_font_size_override("font_size", 20)
		inner.add_child(b)
	settings_box = SettingsPanel.build(Callable(self, "_on_settings_changed"))
	settings_box.visible = false
	inner.add_child(settings_box)
	inner.add_child(_section("CONTROLS"))
	var c := UiTheme.label(
		"WASD pan  |  Wheel zoom  |  Q/E or right/middle drag rotate\n" +
		"1-8 recruit  |  Left click place/select  |  Shift keeps placing\n" +
		"T talk  |  G special  |  Tab targeting  |  Space start wave\n" +
		"H place hero  |  Z / X hero abilities  |  Right-click ground: move hero\n" +
		"P pause  |  F speed  |  Esc menu\n" +
		"Debug: F1 gold  F2-F5 spawn  F6 end wave  F7 lives", 14, Color(0.78, 0.74, 0.66))
	inner.add_child(c)


func _on_settings_changed() -> void:
	feed_panel.visible = bool(Profile.setting("show_chat"))


func _toggle_settings() -> void:
	settings_box.visible = not settings_box.visible


func open_pause_menu() -> void:
	if GameManager.is_over():
		return
	GameManager.set_paused(true)
	_fade_in(pause_layer)
	_refresh_speed()


func close_pause_menu() -> void:
	pause_layer.visible = false
	settings_box.visible = false
	GameManager.set_paused(false)
	_refresh_speed()


func _on_restart() -> void:
	GameManager.restart_level()


func _on_quit() -> void:
	# keep the run: it can be continued from the main menu (from the last build phase)
	if not GameManager.is_over() and GameManager.state == GameManager.State.BUILD and GameManager.wave > 0:
		RunSave.snapshot()
	GameManager.to_menu()


func _on_abandon() -> void:
	if not GameManager.is_over() and GameManager.wave > 0:
		Profile.finish_run(false)
	RunSave.clear()
	GameManager.to_menu()


# ====================================================================== results screen
func _build_end() -> void:
	end_layer = _overlay()
	end_box = _centered(end_layer)


func _show_end(victory: bool) -> void:
	if _results_shown:
		return
	_results_shown = true
	draft_layer.visible = false
	pause_layer.visible = false
	boons_popup.visible = false
	var rewards := Profile.finish_run(victory)
	RunSave.clear()
	for c in end_box.get_children():
		c.queue_free()
	var endless := GameManager.mode == "endless"
	var sub_t := "KINGDOM DEFENDED" if victory else ("THE HORDE BROKE THROUGH" if endless else "THE KINGDOM HAS FALLEN")
	var title_t := "VICTORY" if victory else ("WAVE %d" % GameManager.wave if endless else "GAME OVER")
	if not victory:
		Sfx.play("defeat", 0.0, 0.0, 1.0)
	var s := UiTheme.label(sub_t, 30, UiTheme.PARCHMENT, UiTheme.font_title())
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_box.add_child(s)
	var t := UiTheme.label(title_t, 84, UiTheme.GOLD if victory or endless else UiTheme.RED, UiTheme.font_title())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 14)
	end_box.add_child(t)
	var um := GameManager.unit_manager
	var best := ""
	var best_k := -1
	if um:
		for u in um.units:
			if u.kills > best_k:
				best_k = u.kills
				best = u.display_name
	var stats := UiTheme.label("%s  -  %s\nWaves cleared: %d     Enemies slain: %d     Gold earned: %d%s" % [
		GameManager.level.get("name", ""), GameManager.difficulty_def()["name"],
		int(Profile.run.get("waves", 0)), GameManager.total_kills, EconomyManager.total_earned,
		("\nHero of the battle: %s (%d kills)" % [best, best_k]) if best_k > 0 else ""], 19, Color(0.85, 0.8, 0.7))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_box.add_child(stats)
	# rewards
	var rw := HBoxContainer.new()
	rw.alignment = BoxContainer.ALIGNMENT_CENTER
	rw.add_theme_constant_override("separation", 28)
	end_box.add_child(rw)
	var crown_box := HBoxContainer.new()
	crown_box.add_child(HudIcon.new("star", UiTheme.GOLD, 30))
	crown_box.add_child(UiTheme.label("+%d Crowns" % int(rewards["crowns"]), 26, UiTheme.GOLD, UiTheme.font_title()))
	rw.add_child(crown_box)
	rw.add_child(UiTheme.label("+%d XP" % int(rewards["xp"]), 26, Color(0.6, 0.85, 1.0), UiTheme.font_title()))
	if rewards.get("medal", "") != "":
		var md: Dictionary = LevelDefs.DIFFICULTIES[rewards["medal"]]
		rw.add_child(UiTheme.label("%s medal!" % md["name"], 26, md["color"], UiTheme.font_title()))
	if rewards.get("record", false):
		rw.add_child(UiTheme.label("New record!", 26, UiTheme.GREEN, UiTheme.font_title()))
	if rewards.get("challenge", false):
		rw.add_child(UiTheme.label("Daily Challenge complete!", 22, UiTheme.GREEN, UiTheme.font_title()))
	for unit in rewards.get("unlocks", []):
		var ub := HBoxContainer.new()
		ub.alignment = BoxContainer.ALIGNMENT_CENTER
		var tr := TextureRect.new()
		tr.texture = portrait_texture(unit)
		tr.custom_minimum_size = Vector2(110, 110)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ub.add_child(tr)
		var ul := UiTheme.label("NEW SOLDIER UNLOCKED\n%s" % UnitDefs.get_def(unit)["name"].to_upper(), 30, UiTheme.CLASS_COLORS.get(unit, UiTheme.GOLD), UiTheme.font_title())
		ub.add_child(ul)
		end_box.add_child(ub)
	if rewards.has("heat_record"):
		var hr := UiTheme.label("New Heat record on this map: %d" % int(rewards["heat_record"]), 20, Color(1.0, 0.5, 0.25), UiTheme.font_title())
		hr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		end_box.add_child(hr)
	_results_hero(rewards)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 16)
	end_box.add_child(btns)
	for entry in [["CONTINUE", GameManager.to_menu], ["PLAY AGAIN", GameManager.restart_level]]:
		var b := _button(entry[0], entry[1], 240)
		b.add_theme_font_override("font", UiTheme.font_title())
		b.add_theme_font_size_override("font_size", 22)
		b.custom_minimum_size.y = 54
		btns.add_child(b)
	_fade_in(end_layer)


## Hero mastery XP and the gear that dropped, on the results screen.
func _results_hero(rewards: Dictionary) -> void:
	var hero := String(rewards.get("hero", ""))
	if hero == "":
		return
	var h := HeroDefs.get_hero(hero)
	var line := "%s  +%d mastery XP  (Mastery %d)" % [h["name"], int(rewards.get("hero_xp", 0)), int(rewards.get("hero_mastery", 1))]
	if rewards.get("hero_level_up", false):
		line += "   MASTERY UP!"
	var hl := UiTheme.label(line, 20, UiTheme.GOLD, UiTheme.font_title())
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_box.add_child(hl)
	var gear: Array = rewards.get("gear", [])
	if gear.is_empty():
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	end_box.add_child(row)
	for it in gear:
		row.add_child(gear_card(it, 300))


## Small panel describing one gear piece (also used by the menu's Heroes screen).
static func gear_card(it: Dictionary, width: float) -> PanelContainer:
	var rc: Color = HeroGear.RARITY_COLORS.get(it["rarity"], Color.WHITE)
	var p := PanelContainer.new()
	var st := UiTheme.panel_style(Color(0.1, 0.08, 0.06, 0.97), rc, 8, 2)
	st.set_content_margin_all(10)
	st.shadow_color = Color(rc.r, rc.g, rc.b, 0.3)
	st.shadow_size = 8
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	v.add_child(UiTheme.label("%s %s" % [String(it["rarity"]).to_upper(), String(HeroGear.SLOT_NAMES[it["slot"]]).to_upper()], 12, rc, UiTheme.font_title()))
	var nl := UiTheme.label(it["name"], 16, UiTheme.PARCHMENT, UiTheme.font_title())
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size.x = width - 24
	v.add_child(nl)
	for line in HeroGear.describe_stats(it):
		var sl := UiTheme.label(line, 13, Color(0.8, 0.9, 0.75) if not line.contains(":") else Color(1.0, 0.7, 0.3))
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size.x = width - 24
		v.add_child(sl)
	return p


# ====================================================================== per-frame
func _process(delta: float) -> void:
	for type in portrait_models:
		(portrait_models[type] as Node3D).rotation.y += delta * 0.6
	for type in shop_buttons:
		var entry: Dictionary = shop_buttons[type]
		var cost := EconomyManager.unit_cost(type)
		var b: Button = entry["button"]
		if not entry["unlocked"]:
			(entry["cost"] as Label).text = ""
			b.modulate = Color(0.55, 0.52, 0.5)
			continue
		(entry["cost"] as Label).text = "%d" % cost
		b.modulate = Color.WHITE if EconomyManager.can_afford(cost) else Color(0.6, 0.55, 0.55)
		var pm := GameManager.placement_manager
		if pm and pm.active_type == type:
			b.modulate = Color(1.0, 0.9, 0.5)
	if not hero_card.is_empty():
		var hb: Button = hero_card["button"]
		var hs: Label = hero_card["status"]
		if GameManager.hero_deployed():
			var hu: FriendlyUnit = GameManager.hero_unit
			var parts: Array[String] = ["LV %d" % hu.hero_level]
			if hu.kit:
				for i in 2:
					if hu.kit.ability_unlocked(i):
						var k: String = ["Z", "X"][i]
						if hu.kit.cds[i] <= 0.0:
							parts.append(k + " ok")
						else:
							parts.append("%s %d" % [k, int(ceil(hu.kit.cds[i]))])
			hs.text = " ".join(parts)
			hs.add_theme_font_size_override("font_size", 12)
			hb.modulate = Color.WHITE
		else:
			hs.text = "FREE"
			var pmh := GameManager.placement_manager
			hb.modulate = Color(1.0, 0.95, 0.6) if pmh and pmh.placing_hero else Color.WHITE
	_update_boss_bar()
	var wm := GameManager.wave_manager
	if wm and lbl_enemies:
		lbl_enemies.text = str(wm.enemies_remaining())
	for item in feed_items:
		item["age"] += delta
		var n: Control = item["node"]
		if is_instance_valid(n):
			n.modulate.a = clamp((FEED_LIFETIME - item["age"]) / 3.0, 0.0, 1.0)
	_panel_refresh -= delta
	if _panel_refresh <= 0.0 and panel.visible:
		_panel_refresh = 0.15
		_refresh_panel()
	var pm2 := GameManager.placement_manager
	if pm2 and pm2.is_active():
		var err: String = pm2.ghost_error
		place_hint.visible = true
		place_hint.text = err if err != "" else "Left-click to place  |  Right-click to cancel"
		if pm2.ability_idx >= 0 and err == "" and GameManager.hero_deployed():
			place_hint.text = "Left-click: %s  |  Right-click: cancel" % GameManager.hero_unit.kit.ability_def(pm2.ability_idx)["name"]
		place_hint.add_theme_color_override("font_color", UiTheme.RED if err != "" else UiTheme.GREEN)
		place_hint.position = root.get_local_mouse_position() + Vector2(22, 18)
	else:
		place_hint.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var kc := (event as InputEventKey).keycode
	if kc == Keys.code("pause") and kc != KEY_ESCAPE:
		if not pause_layer.visible:
			_on_speed("pause")
		get_viewport().set_input_as_handled()
		return
	if kc == Keys.code("speed"):
		_on_speed("1x" if GameManager.speed > 1.0 else "2x")
		get_viewport().set_input_as_handled()
		return
	match kc:
		KEY_ESCAPE:
			if pause_layer.visible:
				close_pause_menu()
			elif boons_popup.visible:
				boons_popup.visible = false
			elif GameManager.placement_manager.is_active():
				GameManager.placement_manager.cancel()
			elif GameManager.unit_manager.selected != null:
				GameManager.unit_manager.deselect()
			else:
				open_pause_menu()
			get_viewport().set_input_as_handled()

