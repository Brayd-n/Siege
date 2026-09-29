extends Node3D
## Main menu / campaign map. A live 3D battlefield slowly orbits behind the UI.
## Shows the player profile (rank, XP, Crowns), live events, daily login reward,
## daily quests, the daily challenge, the campaign level select with medals and
## unlocks, and the Armory, Achievements and Settings screens.

var cam: Camera3D
var orbit_t: float = 0.0
var ui: Control
var lbl_crowns: Label
var lbl_rank: Label
var xp_bar: ProgressBar
var quests_box: VBoxContainer
var levels_grid: GridContainer
var overlay: Control
var overlay_box: VBoxContainer
var loading: Control
var selected_heat: Array = []
var hero_tab: String = ""
var codex_sel: String = ""


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.main = null
	# backdrop: the most recently unlocked map
	var backdrop := 0
	for i in LevelDefs.count():
		if Profile.level_unlocked(i) and not LevelDefs.theme(LevelDefs.get_level(i)).get("dark", false):
			backdrop = i
	GameManager.level = LevelDefs.get_level(backdrop)
	GameManager.level_index = backdrop
	var map: Node3D = load("res://scenes/map/Map.tscn").instantiate()
	add_child(map)
	GameManager.map = map
	Atmosphere.build(self, LevelDefs.theme(GameManager.level))
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	Sfx.start_ambience()
	_build_ui()
	Profile.crowns_changed.connect(_on_crowns_changed)
	Profile.profile_changed.connect(_refresh_profile)
	_refresh_profile()
	if not Profile.data.get("seen_intro", false):
		call_deferred("_show_intro")
	elif Profile.login_pending():
		call_deferred("_show_login")


func _process(delta: float) -> void:
	orbit_t += delta * 0.03
	var r := 78.0
	cam.position = Vector3(cos(orbit_t) * r, 42.0, sin(orbit_t) * r * 0.75)
	cam.look_at(Vector3(0, 0, 0), Vector3.UP)


# ================================================================== layout
func _panel(bg: Color = UiTheme.PANEL_BG, border: Color = UiTheme.GOLD_DIM) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(bg, border))
	return p


func _button(text: String, cb: Callable, min_w: float = 0.0, size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = min_w
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	b.pressed.connect(_click)
	return b


func _click() -> void:
	Sfx.play("click", -8.0)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.get_theme()
	layer.add_child(ui)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(margin)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(cols)
	cols.add_child(_left_column())
	cols.add_child(_center_column())
	cols.add_child(_right_column())
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	ui.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var op := _panel(Color(0.08, 0.065, 0.05, 0.98), UiTheme.GOLD)
	center.add_child(op)
	# plain VBox (no ScrollContainer): the panel always sizes to its content
	overlay_box = VBoxContainer.new()
	overlay_box.add_theme_constant_override("separation", 10)
	overlay_box.custom_minimum_size = Vector2(760, 0)
	op.add_child(overlay_box)
	loading = Control.new()
	loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.mouse_filter = Control.MOUSE_FILTER_STOP
	loading.visible = false
	ui.add_child(loading)
	var lb := ColorRect.new()
	lb.color = Color(0.03, 0.02, 0.02, 0.92)
	lb.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(lb)
	var lc := CenterContainer.new()
	lc.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading.add_child(lc)
	var lv := VBoxContainer.new()
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lc.add_child(lv)
	var lt := UiTheme.label("Preparing the battlefield...", 40, UiTheme.GOLD, UiTheme.font_title())
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(lt)
	var ls := UiTheme.label("The first battle takes longer while your graphics card compiles shaders. After that it's cached.", 16, UiTheme.PARCHMENT)
	ls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(ls)


func _left_column() -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 360
	vb.add_theme_constant_override("separation", 12)
	vb.add_child(TitleLogo.new())
	# profile
	var pp := _panel()
	vb.add_child(pp)
	var pv := VBoxContainer.new()
	pp.add_child(pv)
	lbl_rank = UiTheme.label("Commander Rank 1", 22, UiTheme.PARCHMENT, UiTheme.font_title())
	pv.add_child(lbl_rank)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 14)
	xp_bar.show_percentage = false
	pv.add_child(xp_bar)
	var ch := HBoxContainer.new()
	ch.add_child(HudIcon.new("star", UiTheme.GOLD, 28))
	lbl_crowns = UiTheme.label("0 Crowns", 24, UiTheme.GOLD, UiTheme.font_title())
	ch.add_child(lbl_crowns)
	pv.add_child(ch)
	var streak := UiTheme.label("", 15, Color(0.75, 0.7, 0.62), UiTheme.font_italic())
	streak.name = "Streak"
	pv.add_child(streak)
	# live events
	var events := Profile.active_events()
	if not events.is_empty():
		var ep := _panel(Color(0.12, 0.06, 0.1, 0.9), Color(0.85, 0.55, 1.0))
		vb.add_child(ep)
		var ev := VBoxContainer.new()
		ep.add_child(ev)
		ev.add_child(UiTheme.label("LIVE EVENTS", 15, Color(0.85, 0.55, 1.0), UiTheme.font_title()))
		for e in events:
			var el := UiTheme.label("%s - %s" % [e["name"], e["desc"]], 15, UiTheme.PARCHMENT)
			el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			el.custom_minimum_size.x = 330
			ev.add_child(el)
	# menu buttons
	for entry in [["HEROES & GEAR", _show_heroes], ["ARMORY", _show_armory], ["CODEX", _show_codex], ["HALL OF RECORDS", _show_records],
			["ACHIEVEMENTS", _show_achievements], ["SETTINGS", _show_settings], ["CREDITS", _show_credits], ["QUIT", _quit]]:
		var b := _button(entry[0], entry[1], 0, 18)
		b.custom_minimum_size.y = 38
		b.add_theme_font_override("font", UiTheme.font_title())
		vb.add_child(b)
	return vb


func _center_column() -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	var t := UiTheme.label("CAMPAIGN", 34, UiTheme.GOLD, UiTheme.font_title())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 8)
	vb.add_child(t)
	if RunSave.has_save():
		var cr := HBoxContainer.new()
		cr.alignment = BoxContainer.ALIGNMENT_CENTER
		cr.add_theme_constant_override("separation", 10)
		vb.add_child(cr)
		var cb := _button("CONTINUE:  " + RunSave.summary(), _continue_run, 0, 18)
		cb.add_theme_font_override("font", UiTheme.font_title())
		cb.add_theme_color_override("font_color", UiTheme.GREEN)
		cb.custom_minimum_size.y = 42
		cr.add_child(cb)
		var ab := _button("Abandon", _abandon_run, 0, 14)
		cr.add_child(ab)
	var cc := CenterContainer.new()
	vb.add_child(cc)
	levels_grid = GridContainer.new()
	levels_grid.columns = 3
	levels_grid.add_theme_constant_override("h_separation", 12)
	levels_grid.add_theme_constant_override("v_separation", 12)
	cc.add_child(levels_grid)
	_build_level_cards()
	return vb


func _right_column() -> Control:
	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 340
	vb.add_theme_constant_override("separation", 12)
	# daily challenge
	var dp := _panel(Color(0.1, 0.07, 0.04, 0.92), UiTheme.GOLD)
	vb.add_child(dp)
	var dv := VBoxContainer.new()
	dp.add_child(dv)
	dv.add_child(UiTheme.label("DAILY CHALLENGE", 18, UiTheme.GOLD, UiTheme.font_title()))
	var idx := Profile.daily_challenge_level()
	var lv := LevelDefs.get_level(idx)
	var trial_names: Array[String] = []
	for tid in Profile.daily_challenge_trials():
		trial_names.append(HeatDefs.get_trial(tid)["name"])
	var dl := UiTheme.label("%s on Hard with %s. An omen hangs over every wave, and everyone gets the same boon offers today.\nFirst win today: +100 Crowns." % [lv["name"], " + ".join(trial_names)], 15, UiTheme.PARCHMENT)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size.x = 310
	dv.add_child(dl)
	var done: bool = Profile.data["daily"].get("challenge_done", false)
	var db := _button("COMPLETED TODAY" if done else "PLAY CHALLENGE", _play_daily.bind(idx))
	db.add_theme_font_override("font", UiTheme.font_title())
	dv.add_child(db)
	# quests
	var qp := _panel()
	vb.add_child(qp)
	var qv := VBoxContainer.new()
	qp.add_child(qv)
	qv.add_child(UiTheme.label("DAILY QUESTS", 18, UiTheme.GOLD, UiTheme.font_title()))
	qv.add_child(UiTheme.label("New quests every day.", 13, Color(0.7, 0.65, 0.58), UiTheme.font_italic()))
	quests_box = VBoxContainer.new()
	quests_box.add_theme_constant_override("separation", 8)
	qv.add_child(quests_box)
	return vb


func _build_level_cards() -> void:
	for c in levels_grid.get_children():
		c.queue_free()
	for i in LevelDefs.count():
		var lv := LevelDefs.get_level(i)
		var unlocked := Profile.level_unlocked(i)
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(252, 196)
		card.disabled = not unlocked
		card.pressed.connect(_choose_difficulty.bind(i))
		card.pressed.connect(_click)
		levels_grid.add_child(card)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 3)
		card.add_child(v)
		var ri := RouteIcon.from_level(lv, not unlocked)
		ri.custom_minimum_size = Vector2(236, 92)
		v.add_child(ri)
		var nl := UiTheme.label("%d. %s" % [i + 1, lv["name"]], 17, UiTheme.PARCHMENT if unlocked else Color(0.5, 0.48, 0.45), UiTheme.font_title())
		v.add_child(nl)
		var info := ""
		if unlocked:
			info = "%d waves" % int(lv["waves"])
			var u: String = lv.get("unlock", "")
			if u != "" and not Profile.is_unit_unlocked(u):
				info += "  |  Unlocks " + UnitDefs.get_def(u)["name"]
			if lv.get("reward", "") == "gear" and Profile.medals(lv["id"]).is_empty():
				info += "  |  First clear: Epic gear"
			var best := Profile.endless_best(lv["id"])
			if best > 0:
				info += "  |  Endless best %d" % best
			var hb := Profile.heat_best(lv["id"])
			if hb > 0:
				info += "  |  Heat %d" % hb
		else:
			info = "Locked - beat level %d" % i
		var il := UiTheme.label(info, 13, Color(0.75, 0.7, 0.62))
		il.clip_text = true
		il.custom_minimum_size.x = 236
		v.add_child(il)
		var medals := HBoxContainer.new()
		medals.add_theme_constant_override("separation", 6)
		v.add_child(medals)
		var got := Profile.medals(lv["id"])
		for d in LevelDefs.DIFFICULTY_ORDER:
			var dd: Dictionary = LevelDefs.DIFFICULTIES[d]
			var col: Color = dd["color"] if d in got else Color(0.25, 0.23, 0.2)
			var m := HudIcon.new("star", col, 18)
			m.tooltip_text = dd["name"]
			medals.add_child(m)
			medals.add_child(UiTheme.label(dd["name"], 12, col))


func _refresh_profile() -> void:
	if lbl_crowns == null:
		return
	lbl_crowns.text = "%d Crowns" % Profile.crowns()
	lbl_rank.text = "Commander Rank %d" % Profile.player_level()
	xp_bar.max_value = Profile.xp_to_next()
	xp_bar.value = Profile.xp()
	xp_bar.tooltip_text = "%d / %d XP" % [Profile.xp(), Profile.xp_to_next()]
	var streak := lbl_rank.get_parent().get_node_or_null("Streak") as Label
	if streak:
		streak.text = "Login streak: %d day%s" % [Profile.login_streak(), "" if Profile.login_streak() == 1 else "s"]
	_refresh_quests()


func _on_crowns_changed(_c: int) -> void:
	_refresh_profile()


func _refresh_quests() -> void:
	if quests_box == null:
		return
	var quests := Profile.daily_quests()   # may roll new quests (emits profile_changed) - do it first
	for c in quests_box.get_children():
		quests_box.remove_child(c)
		c.queue_free()
	for i in quests.size():
		var q: Dictionary = quests[i]
		var row := VBoxContainer.new()
		quests_box.add_child(row)
		var top := HBoxContainer.new()
		row.add_child(top)
		var ql := UiTheme.label(q["text"], 15, UiTheme.PARCHMENT if not q["claimed"] else Color(0.5, 0.48, 0.45))
		ql.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(ql)
		top.add_child(UiTheme.label("+%d" % int(q["reward"]), 15, UiTheme.GOLD, UiTheme.font_bold()))
		var bar := ProgressBar.new()
		bar.max_value = int(q["target"])
		bar.value = int(q["progress"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		row.add_child(bar)
		if q["claimed"]:
			row.add_child(UiTheme.label("Claimed", 13, Color(0.5, 0.48, 0.45), UiTheme.font_italic()))
		elif int(q["progress"]) >= int(q["target"]):
			var cb := _button("CLAIM REWARD", _claim.bind(i), 0, 15)
			cb.add_theme_color_override("font_color", UiTheme.GREEN)
			row.add_child(cb)
		else:
			row.add_child(UiTheme.label("%d / %d" % [int(q["progress"]), int(q["target"])], 13, Color(0.7, 0.65, 0.58)))


func _claim(i: int) -> void:
	Profile.claim_quest(i)
	_refresh_quests()


# ================================================================== overlays
func _open_overlay(title: String, width: float = 760.0) -> void:
	for c in overlay_box.get_children():
		c.queue_free()
	overlay_box.custom_minimum_size = Vector2(width, 0)
	overlay_box.get_parent().reset_size()
	var t := UiTheme.label(title, 36, UiTheme.GOLD, UiTheme.font_title())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(t)
	overlay.visible = true
	overlay.modulate.a = 0.0
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.2)


func _close_overlay() -> void:
	overlay.visible = false
	_build_level_cards()
	_refresh_profile()


func _add_close(text: String = "CLOSE") -> void:
	var b := _button(text, _close_overlay, 200, 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", UiTheme.font_title())
	overlay_box.add_child(b)


func _choose_difficulty(idx: int) -> void:
	var lv := LevelDefs.get_level(idx)
	_open_overlay(lv["name"].to_upper())
	var bl := UiTheme.label(lv["blurb"], 18, UiTheme.PARCHMENT, UiTheme.font_italic())
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(bl)
	var ri := RouteIcon.from_level(lv)
	ri.custom_minimum_size = Vector2(380, 150)
	ri.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	overlay_box.add_child(ri)
	var roster: Array[String] = []
	for r in lv["roster"]:
		roster.append(EnemyDefs.get_def(r[0]).get("name", r[0]))
	var el := UiTheme.label("Enemies: %s.  Boss: %s." % [", ".join(roster), EnemyDefs.get_def(lv["boss"]).get("title", EnemyDefs.get_def(lv["boss"])["name"])], 15, Color(0.8, 0.75, 0.66))
	el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_box.add_child(el)
	_hero_picker(idx)
	_trials_picker(idx)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	overlay_box.add_child(row)
	var got := Profile.medals(lv["id"])
	for d in LevelDefs.DIFFICULTY_ORDER:
		var dd: Dictionary = LevelDefs.DIFFICULTIES[d]
		var b := _button("%s%s\n%d lives, enemy HP x%.1f" % [dd["name"].to_upper(), "  (won)" if d in got else "", int(dd["lives"]) + Profile.start_lives_bonus(), float(dd["hp"])], _play.bind(idx, d, "campaign"), 220, 17)
		b.custom_minimum_size.y = 62
		b.add_theme_color_override("font_color", dd["color"])
		row.add_child(b)
	var er := HBoxContainer.new()
	er.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay_box.add_child(er)
	if Profile.endless_unlocked():
		var eb := _button("ENDLESS MODE  (best: wave %d)" % Profile.endless_best(lv["id"]), _play.bind(idx, "normal", "endless"), 360, 17)
		eb.add_theme_color_override("font_color", Color(0.85, 0.55, 1.0))
		er.add_child(eb)
	else:
		er.add_child(UiTheme.label("Endless mode unlocks after beating Dragon's Reach.", 14, Color(0.6, 0.56, 0.5), UiTheme.font_italic()))
	_add_close("BACK")


## Row of hero cards on the level screen. The chosen hero is saved in the profile.
func _hero_picker(level_idx: int) -> void:
	var cur := Profile.selected_hero()
	var hl := UiTheme.label("CHOOSE YOUR HERO", 16, UiTheme.GOLD, UiTheme.font_title())
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(hl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	overlay_box.add_child(row)
	for id in HeroDefs.ORDER:
		var h := HeroDefs.get_hero(id)
		var unlocked := Profile.hero_unlocked(id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(146, 96)
		var sel := id == cur
		b.add_theme_stylebox_override("normal", UiTheme.button_style(Color(0.25, 0.17, 0.06) if sel else Color(0.1, 0.08, 0.06), UiTheme.GOLD if sel else Color(0.35, 0.3, 0.22)))
		b.add_theme_stylebox_override("hover", UiTheme.button_style(Color(0.3, 0.2, 0.08), Color(1, 0.9, 0.6)))
		b.add_theme_stylebox_override("disabled", UiTheme.button_style(Color(0.07, 0.06, 0.05), Color(0.25, 0.22, 0.18)))
		b.disabled = not unlocked
		b.tooltip_text = "%s, %s\n%s\nAura: %s\nBuilt on the %s class." % [h["name"], h["title"], h["blurb"], HeroDefs.aura_text(id), UnitDefs.get_def(h["base"])["name"]] if unlocked else "%s\nBeat %s to unlock this hero." % [h["name"], HeroDefs.unlock_source(id)]
		b.pressed.connect(_pick_hero.bind(id, level_idx))
		row.add_child(b)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 0)
		b.add_child(vb)
		var col: Color = UiTheme.CLASS_COLORS.get(h["base"], UiTheme.PARCHMENT) if unlocked else Color(0.45, 0.42, 0.38)
		for line in [[String(h["short"]).to_upper(), 16, col, UiTheme.font_title()],
				[h["title"] if unlocked else "LOCKED", 11, Color(0.8, 0.75, 0.65) if unlocked else Color(0.5, 0.46, 0.4), UiTheme.font_italic()],
				[UnitDefs.get_def(h["base"])["name"] if unlocked else "Beat " + HeroDefs.unlock_source(id), 11, Color(0.65, 0.6, 0.52), UiTheme.font_bold()],
				["SELECTED" if sel else "", 11, UiTheme.GREEN, UiTheme.font_title()]]:
			var l := UiTheme.label(line[0], line[1], line[2], line[3])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = 140
			vb.add_child(l)
	var desc := UiTheme.label("%s: %s" % [HeroDefs.get_hero(cur)["name"], HeroDefs.aura_text(cur)] if cur != "" else "", 14, Color(0.85, 0.78, 0.6), UiTheme.font_italic())
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(desc)


func _pick_hero(id: String, level_idx: int) -> void:
	Profile.set_hero(id)
	_choose_difficulty(level_idx)


func _play(idx: int, diff: String, mode: String) -> void:
	_launch(idx, diff, mode, selected_heat.duplicate())


func _play_daily(idx: int) -> void:
	_launch(idx, "hard", "challenge", Profile.daily_challenge_trials())


func _launch(idx: int, diff: String, mode: String, trials: Array) -> void:
	overlay.visible = false
	loading.visible = true
	Profile.set_setting("last_heat", selected_heat.duplicate())
	# let the loading screen draw before the (heavy) battlefield build
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.start_level(idx, diff, mode, trials)


func _continue_run() -> void:
	overlay.visible = false
	loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	RunSave.resume()


func _abandon_run() -> void:
	RunSave.clear()
	Profile.toast.emit("Run abandoned", "That battle is gone for good.", UiTheme.RED)
	get_tree().reload_current_scene()


## Heat trials: optional challenges for more Crowns, XP and better gear.
func _trials_picker(level_idx: int) -> void:
	if selected_heat.is_empty() and Profile.setting("last_heat") is Array:
		selected_heat = (Profile.setting("last_heat") as Array).duplicate()
	var pts := 0
	for tid in selected_heat:
		pts += int(HeatDefs.get_trial(tid).get("heat", 0))
	var lv := LevelDefs.get_level(level_idx)
	var best := Profile.heat_best(lv["id"])
	var hl := UiTheme.label("HEAT TRIALS  -  Heat %d  (+%d%% Crowns, better gear)%s" % [pts, pts * 10, ("   Best cleared here: %d" % best) if best >= 0 else ""],
		16, Color(1.0, 0.55, 0.3), UiTheme.font_title())
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(hl)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var cc := CenterContainer.new()
	overlay_box.add_child(cc)
	cc.add_child(grid)
	for t in HeatDefs.TRIALS:
		var on: bool = t["id"] in selected_heat
		var b := _button("%s (%d)" % [t["name"], int(t["heat"])], _toggle_trial.bind(t["id"], level_idx), 146, 13)
		b.tooltip_text = t["desc"]
		b.custom_minimum_size.y = 30
		b.add_theme_stylebox_override("normal", UiTheme.button_style(Color(0.35, 0.12, 0.05) if on else Color(0.1, 0.08, 0.06), Color(1.0, 0.55, 0.3) if on else Color(0.35, 0.3, 0.22)))
		grid.add_child(b)


func _toggle_trial(id: String, level_idx: int) -> void:
	if id in selected_heat:
		selected_heat.erase(id)
	else:
		selected_heat.append(id)
	_choose_difficulty(level_idx)


func _show_armory() -> void:
	_open_overlay("ARMORY")
	var sub := UiTheme.label("Permanent upgrades bought with Crowns. You have %d Crowns." % Profile.crowns(), 17, UiTheme.PARCHMENT, UiTheme.font_italic())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.name = "Sub"
	overlay_box.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	overlay_box.add_child(grid)
	for a in Profile.ARMORY:
		var p := _panel(Color(0.12, 0.1, 0.08, 0.95))
		p.custom_minimum_size = Vector2(360, 0)
		grid.add_child(p)
		var v := VBoxContainer.new()
		p.add_child(v)
		var rank := Profile.armory_rank(a["id"])
		var maxr: int = (a["costs"] as Array).size()
		var h := HBoxContainer.new()
		v.add_child(h)
		h.add_child(HudIcon.new(a["icon"], UiTheme.GOLD, 22))
		var nl := UiTheme.label(a["name"], 19, UiTheme.GOLD, UiTheme.font_title())
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		var pips := ""
		for k in maxr:
			pips += "# " if k < rank else "- "
		h.add_child(UiTheme.label(pips, 16, UiTheme.PARCHMENT, UiTheme.font_bold()))
		var dl := UiTheme.label(a["desc"], 15, UiTheme.PARCHMENT)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(dl)
		var cost := Profile.armory_next_cost(a["id"])
		var b := _button("MAXED" if cost < 0 else "BUY  (%d Crowns)" % cost, _buy.bind(a["id"]), 0, 15)
		b.disabled = cost < 0 or Profile.crowns() < cost
		v.add_child(b)
	_add_close()


func _buy(id: String) -> void:
	if Profile.buy_armory(id):
		Sfx.play("upgrade", -4.0)
		_show_armory()


func _show_achievements() -> void:
	_open_overlay("ACHIEVEMENTS")
	var n := 0
	for a in Profile.ACHIEVEMENTS:
		if Profile.has_achievement(a["id"]):
			n += 1
	var sub := UiTheme.label("%d / %d unlocked" % [n, Profile.ACHIEVEMENTS.size()], 17, UiTheme.PARCHMENT, UiTheme.font_italic())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	overlay_box.add_child(grid)
	for a in Profile.ACHIEVEMENTS:
		var got := Profile.has_achievement(a["id"])
		var p := _panel(Color(0.12, 0.1, 0.08, 0.95), UiTheme.GOLD if got else Color(0.3, 0.28, 0.25))
		p.custom_minimum_size = Vector2(360, 0)
		grid.add_child(p)
		var v := VBoxContainer.new()
		p.add_child(v)
		var h := HBoxContainer.new()
		v.add_child(h)
		h.add_child(HudIcon.new("star", UiTheme.GOLD if got else Color(0.3, 0.28, 0.25), 20))
		var nl := UiTheme.label(a["name"], 17, UiTheme.GOLD if got else Color(0.6, 0.57, 0.52), UiTheme.font_title())
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		h.add_child(UiTheme.label("+%d" % int(a["reward"]), 14, UiTheme.GOLD))
		var desc: String = a["desc"]
		if not got and a["stat"] != "":
			desc += "  (%d / %d)" % [min(Profile.stat(a["stat"]), int(a["goal"])), int(a["goal"])]
		var dl := UiTheme.label(desc, 14, UiTheme.PARCHMENT if got else Color(0.6, 0.57, 0.52))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(dl)
	var st := UiTheme.label("Lifetime: %d enemies slain, %d waves cleared, %d soldiers recruited, %d conversations, %d wins." % [
		Profile.stat("kills"), Profile.stat("waves"), Profile.stat("placed"), Profile.stat("talks"), Profile.stat("wins")], 15, Color(0.75, 0.7, 0.62))
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(st)
	_add_close()


func _show_settings() -> void:
	_open_overlay("SETTINGS")
	overlay_box.add_child(SettingsPanel.build())
	overlay_box.add_child(UiTheme.label("DEMO & PROGRESS", 16, UiTheme.GOLD, UiTheme.font_title()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	overlay_box.add_child(row)
	row.add_child(_button("Unlock all levels & soldiers (demo)", _unlock_all, 0, 15))
	var reset := _button("Reset all progress", _reset, 0, 15)
	reset.add_theme_color_override("font_color", UiTheme.RED)
	row.add_child(reset)
	_add_close()


func _unlock_all() -> void:
	Profile.unlock_everything()
	Profile.toast.emit("Demo mode", "All levels and soldiers unlocked.", UiTheme.GREEN)
	_build_level_cards()


func _reset() -> void:
	Profile.reset_profile()
	Profile.toast.emit("Progress reset", "A fresh start, Commander.", UiTheme.RED)
	_close_overlay()


func _show_login() -> void:
	var reward := Profile.claim_login()
	if reward <= 0:
		return
	_open_overlay("WELCOME BACK")
	var l := UiTheme.label("Day %d login streak!\nThe royal treasury sends %d Crowns." % [Profile.login_streak(), reward], 22, UiTheme.PARCHMENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(l)
	var tip := UiTheme.label("Log in every day for bigger rewards (up to day 7). Daily quests and the daily challenge refresh at midnight.", 15, Color(0.75, 0.7, 0.62), UiTheme.font_italic())
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(tip)
	Sfx.play("coin", -2.0)
	_add_close("COLLECT")


func _show_intro() -> void:
	Profile.data["seen_intro"] = true
	Profile.mark_dirty()
	_open_overlay("WELCOME, COMMANDER")
	var body := UiTheme.label(
		"Your towers are soldiers. Each one has a name, a personality and a voice.\n\n" +
		"Click a soldier to TALK, set who they target, give orders and upgrade them.\n" +
		"They warn each other about trolls, call knights for help, heal the fallen and rally against the dragon.\n\n" +
		"Beat each level to unlock a new kind of soldier. Earn Crowns for the Armory, finish daily quests,\n" +
		"and take on the Daily Challenge. Survive every road to unlock Endless mode.", 18, UiTheme.PARCHMENT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(body)
	Profile.claim_login()
	_add_close("BEGIN")


func _quit() -> void:
	Profile.save_profile()
	get_tree().quit()


# ================================================================== heroes & gear
func _show_heroes(focus: String = "") -> void:
	if focus != "":
		hero_tab = focus
	if hero_tab == "" or not Profile.hero_unlocked(hero_tab):
		hero_tab = Profile.selected_hero() if Profile.selected_hero() != "" else "lionheart"
	_open_overlay("HEROES & GEAR", 1380)
	var id := hero_tab
	var h := HeroDefs.get_hero(id)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	overlay_box.add_child(main)
	# --- hero list
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	main.add_child(list)
	for hid in HeroDefs.ORDER:
		var hd := HeroDefs.get_hero(hid)
		var unlocked := Profile.hero_unlocked(hid)
		var txt := "%s\nMastery %d" % [hd["short"], HeroGear.mastery_level(hid)] if unlocked else "%s\nBeat %s" % [hd["short"], HeroDefs.unlock_source(hid)]
		var b := _button(txt, _show_heroes.bind(hid), 170, 15)
		b.custom_minimum_size.y = 58
		b.disabled = not unlocked
		var on := hid == id
		b.add_theme_stylebox_override("normal", UiTheme.button_style(Color(0.25, 0.17, 0.06) if on else Color(0.1, 0.08, 0.06), UiTheme.GOLD if on else Color(0.35, 0.3, 0.22)))
		list.add_child(b)
	var sel := _button("USE THIS HERO" if Profile.selected_hero() != id else "SELECTED FOR BATTLE", _select_hero_from_screen.bind(id), 170, 14)
	sel.disabled = Profile.selected_hero() == id
	list.add_child(sel)
	# --- portrait + mastery
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	main.add_child(mid)
	var mp := ModelPreview.new(Vector2i(240, 240))
	mid.add_child(mp)
	var rig := ModelBuilder.build_unit(h["base"])
	HeroDefs.decorate(rig, id)
	mp.show_rig(rig, 2.4)
	var nl := UiTheme.label(h["name"], 20, UiTheme.GOLD, UiTheme.font_title())
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.custom_minimum_size.x = 250
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(nl)
	var tl := UiTheme.label(h["title"] + "  -  " + String(UnitDefs.get_def(h["base"])["name"]), 14, UiTheme.PARCHMENT, UiTheme.font_italic())
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(tl)
	var ml := HeroGear.mastery_level(id)
	var xp := HeroGear.mastery_xp(id)
	var lo := HeroGear.xp_for_level(ml)
	var hi := HeroGear.xp_for_level(mini(ml + 1, HeroGear.MASTERY_MAX))
	mid.add_child(UiTheme.label("Mastery %d / %d   (%d XP)" % [ml, HeroGear.MASTERY_MAX, xp], 15, UiTheme.GOLD, UiTheme.font_bold()))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(250, 12)
	bar.max_value = max(1, hi - lo)
	bar.value = clamp(xp - lo, 0, hi - lo) if ml < HeroGear.MASTERY_MAX else bar.max_value
	mid.add_child(bar)
	for lv in HeroGear.MASTERY_REWARDS:
		var got := ml >= int(lv)
		var rl := UiTheme.label("%s Lv %d: %s" % ["+" if got else "-", lv, HeroGear.MASTERY_REWARDS[lv]], 12, UiTheme.GREEN if got else Color(0.55, 0.52, 0.48))
		mid.add_child(rl)
	# --- details: abilities, aura, skins, equipped
	var det := VBoxContainer.new()
	det.add_theme_constant_override("separation", 6)
	det.custom_minimum_size.x = 420
	main.add_child(det)
	det.add_child(UiTheme.label("UNIQUE", 15, UiTheme.GOLD, UiTheme.font_title()))
	for line in [h.get("unique", ""), h.get("passive", "")]:
		var ul := UiTheme.label(line, 14, UiTheme.PARCHMENT)
		ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ul.custom_minimum_size.x = 410
		det.add_child(ul)
	det.add_child(UiTheme.label("ABILITIES", 15, UiTheme.GOLD, UiTheme.font_title()))
	for i in 2:
		var ab := HeroDefs.ability(id, i)
		var al := UiTheme.label("[%s] %s (%ds, hero Lv %d): %s" % ["Z" if i == 0 else "X", ab["name"], int(ab["cd"]), int(ab["level"]), ab["desc"]], 13, Color(0.8, 0.9, 1.0))
		al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		al.custom_minimum_size.x = 410
		det.add_child(al)
	det.add_child(UiTheme.label("AURA", 15, UiTheme.GOLD, UiTheme.font_title()))
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 6)
	det.add_child(ar)
	for choice in ["a", "b"]:
		var a: Dictionary = h["aura"] if choice == "a" else h.get("aura_b", {})
		var label: String = a.get("label", "")
		var on2: bool = HeroGear.aura_choice(id) == choice
		var locked2: bool = choice == "b" and ml < 2
		var b2 := _button(label + (" (Mastery 2)" if locked2 else ""), _set_aura.bind(id, choice), 200, 14)
		b2.disabled = locked2
		b2.tooltip_text = h["aura_desc"] if choice == "a" else String(a.get("desc", ""))
		b2.add_theme_stylebox_override("normal", UiTheme.button_style(Color(0.2, 0.25, 0.1) if on2 else Color(0.1, 0.08, 0.06), UiTheme.GREEN if on2 else Color(0.35, 0.3, 0.22)))
		ar.add_child(b2)
	var aura_l := UiTheme.label(HeroDefs.aura_text(id), 13, UiTheme.PARCHMENT, UiTheme.font_italic())
	det.add_child(aura_l)
	det.add_child(UiTheme.label("SKIN", 15, UiTheme.GOLD, UiTheme.font_title()))
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	det.add_child(sr)
	for sk in HeroGear.SKINS:
		var sd: Dictionary = HeroGear.SKINS[sk]
		var locked3 := ml < int(sd["level"])
		var b3 := _button(String(sd["name"]) + ("" if not locked3 else " (M%d)" % int(sd["level"])), _set_skin.bind(id, sk), 96, 13)
		b3.disabled = locked3
		if HeroGear.skin(id) == sk:
			b3.add_theme_color_override("font_color", UiTheme.GREEN)
		sr.add_child(b3)
	# stats summary from gear
	var parts: Array[String] = []
	for st in HeroGear.STAT_NAMES:
		var m := HeroGear.stat_mult(id, st)
		if absf(m - 1.0) > 0.001:
			if st in HeroGear.REDUCTIONS:
				parts.append("-%d%% %s" % [int(round((1.0 - m) * 100)), HeroGear.STAT_NAMES[st]])
			else:
				parts.append("+%d%% %s" % [int(round((m - 1.0) * 100)), HeroGear.STAT_NAMES[st]])
	var tot := UiTheme.label("Gear total: " + (", ".join(parts) if not parts.is_empty() else "nothing equipped yet"), 13, Color(0.75, 0.95, 0.7))
	tot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tot.custom_minimum_size.x = 410
	det.add_child(tot)
	# --- equipped slots
	var eq := VBoxContainer.new()
	eq.add_theme_constant_override("separation", 6)
	main.add_child(eq)
	eq.add_child(UiTheme.label("EQUIPPED", 15, UiTheme.GOLD, UiTheme.font_title()))
	for slot in HeroGear.SLOTS:
		var it := HeroGear.equipped(id, slot)
		if it.is_empty():
			var empty := _panel(Color(0.08, 0.07, 0.06, 0.9), Color(0.3, 0.27, 0.22))
			empty.custom_minimum_size = Vector2(290, 70)
			empty.add_child(UiTheme.label("%s: empty\nPlay a battle with %s to earn gear." % [HeroGear.SLOT_NAMES[slot], h["short"]], 13, Color(0.6, 0.56, 0.5), UiTheme.font_italic()))
			eq.add_child(empty)
		else:
			eq.add_child(GameHUD.gear_card(it, 290))
	# --- inventory
	var items := HeroGear.items(id)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 12)
	overlay_box.add_child(ih)
	ih.add_child(UiTheme.label("INVENTORY  %d / %d   (click a piece to equip it)" % [items.size(), HeroGear.MAX_ITEMS], 15, UiTheme.GOLD, UiTheme.font_title()))
	ih.add_child(_button("Salvage unequipped Common + Uncommon", _salvage_below.bind(id, "uncommon"), 0, 13))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1360, 180)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	overlay_box.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	var sorted := items.duplicate()
	sorted.sort_custom(func(a, b): return HeroGear.RARITIES.find(a["rarity"]) > HeroGear.RARITIES.find(b["rarity"]))
	if sorted.is_empty():
		grid.add_child(UiTheme.label("No gear yet. Every battle you finish with %s drops a piece; wins, harder difficulties and Heat give better odds." % h["short"], 14, Color(0.65, 0.6, 0.55), UiTheme.font_italic()))
	for it in sorted:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		grid.add_child(cell)
		var card := GameHUD.gear_card(it, 262)
		cell.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		cell.add_child(row)
		var equipped := HeroGear.is_equipped(id, int(it["uid"]))
		var eb := _button("EQUIPPED" if equipped else "EQUIP", _equip.bind(id, int(it["uid"])), 120, 13)
		eb.disabled = equipped
		row.add_child(eb)
		var sb := _button("Salvage +%d" % int(HeroGear.SALVAGE[it["rarity"]]), _salvage.bind(id, int(it["uid"])), 120, 13)
		row.add_child(sb)
	_add_close()


func _select_hero_from_screen(id: String) -> void:
	Profile.set_hero(id)
	_show_heroes(id)


func _set_aura(id: String, c: String) -> void:
	HeroGear.set_aura_choice(id, c)
	_show_heroes(id)


func _set_skin(id: String, sk: String) -> void:
	HeroGear.set_skin(id, sk)
	_show_heroes(id)


func _equip(id: String, uid: int) -> void:
	HeroGear.equip(id, uid)
	Sfx.play("upgrade", -6.0)
	_show_heroes(id)


func _salvage(id: String, uid: int) -> void:
	var c := HeroGear.salvage(id, uid)
	Profile.toast.emit("Salvaged", "+%d Crowns" % c, UiTheme.GOLD)
	_show_heroes(id)


func _salvage_below(id: String, r: String) -> void:
	var c := HeroGear.salvage_below(id, r)
	Profile.toast.emit("Salvaged", "+%d Crowns" % c, UiTheme.GOLD)
	_show_heroes(id)


# ================================================================== codex
func _codex_entries() -> Array:
	var out: Array = []
	for t in EnemyDefs.ORDER:
		out.append({"key": "enemy:" + t, "kind": "boss" if EnemyDefs.is_boss(t) else "enemy", "id": t})
	for t in UnitDefs.ORDER:
		out.append({"key": "unit:" + t, "kind": "soldier", "id": t})
	for hid in HeroDefs.ORDER:
		out.append({"key": "hero:" + hid, "kind": "hero", "id": hid})
	return out


func _codex_known(e: Dictionary) -> bool:
	match e["kind"]:
		"soldier":
			return Profile.is_unit_unlocked(e["id"])
		"hero":
			return Profile.hero_unlocked(e["id"])
	return Profile.has_seen(e["key"])


func _show_codex(sel: String = "") -> void:
	if sel != "":
		codex_sel = sel
	var entries := _codex_entries()
	if codex_sel == "":
		codex_sel = entries[0]["key"]
	_open_overlay("CODEX", 1180)
	var known := 0
	for e in entries:
		if _codex_known(e):
			known += 1
	var sub := UiTheme.label("%d / %d entries discovered. Enemies appear here once you meet them." % [known, entries.size()], 15, UiTheme.PARCHMENT, UiTheme.font_italic())
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(sub)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 16)
	overlay_box.add_child(main)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(300, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	sc.add_child(list)
	var last_kind := ""
	var cur: Dictionary = entries[0]
	for e in entries:
		if e["kind"] != last_kind:
			last_kind = e["kind"]
			list.add_child(UiTheme.label({"enemy": "ENEMIES", "boss": "BOSSES", "soldier": "SOLDIERS", "hero": "HEROES"}[last_kind], 14, UiTheme.GOLD, UiTheme.font_title()))
		var k := _codex_known(e)
		var nm := _codex_name(e) if k else "???"
		var b := _button(nm, _show_codex.bind(e["key"]), 280, 14)
		b.disabled = not k
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if e["key"] == codex_sel:
			b.add_theme_color_override("font_color", UiTheme.GOLD)
			cur = e
		list.add_child(b)
	var det := VBoxContainer.new()
	det.add_theme_constant_override("separation", 8)
	det.custom_minimum_size.x = 820
	main.add_child(det)
	if not _codex_known(cur):
		det.add_child(UiTheme.label("Undiscovered.", 18, Color(0.6, 0.56, 0.5), UiTheme.font_italic()))
		_add_close()
		return
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	det.add_child(top)
	var mp := ModelPreview.new(Vector2i(300, 320))
	top.add_child(mp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tv.custom_minimum_size.x = 490
	top.add_child(tv)
	var title := UiTheme.label(_codex_name(cur), 26, UiTheme.GOLD, UiTheme.font_title())
	tv.add_child(title)
	var lines: Array[String] = []
	match cur["kind"]:
		"enemy", "boss":
			var d := EnemyDefs.get_def(cur["id"])
			var rig := ModelBuilder.build_enemy(cur["id"])
			var big: bool = cur["id"] in ["dragon", "frost_wyrm", "elder_dragon"]
			mp.show_rig(rig, 6.0 if big else (3.4 if cur["id"] in ["troll", "siege_troll", "riverbane"] else 2.0))
			if big:
				mp.cam.position = Vector3(0, 4.0, 22.0)
				mp.cam.look_at(Vector3(0, 0.5, 0), Vector3.UP)
			lines.append(EnemyDefs.desc(cur["id"]))
			lines.append("Counter: " + EnemyDefs.counter(cur["id"]))
			lines.append("Health %d   Speed %.1f   Armour %d%%   Bounty %d gold   Costs %d li%s" % [int(d["hp"]), float(d["speed"]),
				int(float(d.get("armor", 0.0)) * 100), int(d["reward"]), int(d["lives"]), "fe" if int(d["lives"]) == 1 else "ves"])
			var res: Dictionary = d.get("resist", {})
			var rp: Array[String] = []
			for dt in res:
				rp.append("%s x%.2f" % [["Normal", "Piercing", "Fire", "Arcane"][int(dt)] if int(dt) < 4 else str(dt), float(res[dt])])
			if not rp.is_empty():
				lines.append("Damage taken: " + ", ".join(rp))
			if d.get("undead", false):
				lines.append("Undead: Clerics, Paladins and Inquisitors deal extra damage.")
			if d.get("heavy", false):
				lines.append("Heavy: soldiers call it out and focus it.")
			lines.append("Defeated: %d" % Profile.stat("kill_" + String(cur["id"])))
		"soldier":
			var ud := UnitDefs.get_def(cur["id"])
			mp.show_rig(ModelBuilder.build_unit(cur["id"]), 2.6 if cur["id"] == "trebuchet" else 2.2)
			lines.append(ud["role"])
			lines.append("Cost %d   Health %d   Damage %d   Range %.0f   %.2f attacks/s" % [int(ud["cost"]), int(ud["hp"]), int(ud["damage"]), float(ud["range"]), 1.0 / float(ud["interval"])])
			lines.append("Special - %s: %s" % [ud["special"]["name"], ud["special"]["desc"]])
			var pn: Array[String] = []
			for pth in ud["paths"]:
				pn.append(pth["name"])
			lines.append("Upgrades: " + ", ".join(pn))
			for sp in UnitDefs.SPECS.get(cur["id"], []):
				lines.append("Tier 3 - %s: %s" % [sp["name"], sp["desc"]])
		"hero":
			var hd := HeroDefs.get_hero(cur["id"])
			var rig2 := ModelBuilder.build_unit(hd["base"])
			HeroDefs.decorate(rig2, cur["id"])
			mp.show_rig(rig2, 2.4)
			lines.append(hd["blurb"])
			lines.append(hd.get("unique", ""))
			lines.append(hd.get("passive", ""))
			for i in 2:
				var ab := HeroDefs.ability(cur["id"], i)
				lines.append("%s: %s" % [ab["name"], ab["desc"]])
			lines.append("Aura: " + String(hd["aura_desc"]))
	for line in lines:
		var l := UiTheme.label(line, 15, UiTheme.PARCHMENT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 480
		tv.add_child(l)
	_add_close()


func _codex_name(e: Dictionary) -> String:
	match e["kind"]:
		"enemy", "boss":
			var d := EnemyDefs.get_def(e["id"])
			return String(d.get("title", d.get("name", e["id"])))
		"soldier":
			return String(UnitDefs.get_def(e["id"])["name"])
		"hero":
			return String(HeroDefs.get_hero(e["id"])["name"])
	return e["id"]


# ================================================================== records
func _show_records() -> void:
	_open_overlay("HALL OF RECORDS", 1100)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	overlay_box.add_child(cols)
	# campaign table
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	cols.add_child(left)
	left.add_child(UiTheme.label("CAMPAIGN", 17, UiTheme.GOLD, UiTheme.font_title()))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	left.add_child(grid)
	for hd in ["Map", "Medals", "Best Heat", "Endless best"]:
		grid.add_child(UiTheme.label(hd, 13, Color(0.7, 0.64, 0.55), UiTheme.font_bold()))
	for i in LevelDefs.count():
		var lv := LevelDefs.get_level(i)
		var m := Profile.medals(lv["id"])
		grid.add_child(UiTheme.label(lv["name"], 14, UiTheme.PARCHMENT if Profile.level_unlocked(i) else Color(0.5, 0.47, 0.43)))
		var ms: Array[String] = []
		for d in LevelDefs.DIFFICULTY_ORDER:
			if d in m:
				ms.append(LevelDefs.DIFFICULTIES[d]["name"])
		grid.add_child(UiTheme.label(", ".join(ms) if not ms.is_empty() else "-", 14, UiTheme.GOLD))
		var hb := Profile.heat_best(lv["id"])
		grid.add_child(UiTheme.label(str(hb) if hb >= 0 else "-", 14, Color(1.0, 0.55, 0.3)))
		var eb := Profile.endless_best(lv["id"])
		grid.add_child(UiTheme.label(str(eb) if eb > 0 else "-", 14, Color(0.85, 0.55, 1.0)))
	left.add_child(UiTheme.label("LIFETIME", 17, UiTheme.GOLD, UiTheme.font_title()))
	var lt := UiTheme.label("%d enemies slain (%d trolls, %d dragons)\n%d waves cleared, %d wins in %d battles\n%d soldiers recruited, %d conversations, %d specials used" % [
		Profile.stat("kills"), Profile.stat("troll_kills"), Profile.stat("dragon_kills"), Profile.stat("waves"), Profile.stat("wins"),
		Profile.stat("games"), Profile.stat("placed"), Profile.stat("talks"), Profile.stat("specials")], 14, UiTheme.PARCHMENT)
	left.add_child(lt)
	# right: daily + recent runs
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.custom_minimum_size.x = 440
	cols.add_child(right)
	right.add_child(UiTheme.label("DAILY CHALLENGE (same run for everyone each day)", 17, UiTheme.GOLD, UiTheme.font_title()))
	var hist := Profile.daily_history()
	var dates := hist.keys()
	dates.sort()
	dates.reverse()
	if dates.is_empty():
		right.add_child(UiTheme.label("No daily challenges played yet.", 14, Color(0.6, 0.56, 0.5), UiTheme.font_italic()))
	for i in mini(7, dates.size()):
		var d: Dictionary = hist[dates[i]]
		right.add_child(UiTheme.label("%s  -  %s  -  %d waves%s" % [dates[i], d.get("level", ""), int(d.get("waves", 0)), "  WON" if d.get("won", false) else ""], 14,
			UiTheme.GREEN if d.get("won", false) else UiTheme.PARCHMENT))
	right.add_child(UiTheme.label("RECENT BATTLES", 17, UiTheme.GOLD, UiTheme.font_title()))
	var runs: Array = Profile.data.get("run_log", [])
	if runs.is_empty():
		right.add_child(UiTheme.label("No battles yet.", 14, Color(0.6, 0.56, 0.5), UiTheme.font_italic()))
	for i in mini(10, runs.size()):
		var r: Dictionary = runs[i]
		var hero_n := String(HeroDefs.get_hero(r.get("hero", "")).get("short", "no hero")) if String(r.get("hero", "")) != "" else "no hero"
		right.add_child(UiTheme.label("%s  %s  %s  wave %d  heat %d  %s  %s" % [r.get("date", ""), r.get("level", ""), r.get("mode", ""),
			int(r.get("wave", 0)), int(r.get("heat", 0)), hero_n, "WON" if r.get("won", false) else "lost"], 13,
			UiTheme.GREEN if r.get("won", false) else Color(0.8, 0.74, 0.66)))
	var note := UiTheme.label("Records are kept on this computer.", 12, Color(0.55, 0.52, 0.48), UiTheme.font_italic())
	overlay_box.add_child(note)
	_add_close()


# ================================================================== credits
func _show_credits() -> void:
	_open_overlay("CREDITS")
	var body := UiTheme.label(
		"SIEGEWATCH\nA medieval tower defense where your towers are people.\n\n" +
		"Created by Braydon\n\n" +
		"Built with the Godot Engine (godotengine.org, MIT licence)\n" +
		"All models, textures, effects and sounds are generated in code.\n" +
		"Fonts: Cinzel and Alegreya (SIL Open Font License)\n\n" +
		"Programming help from Claude (Anthropic)\n\n" +
		"Thanks for playing, Commander.", 18, UiTheme.PARCHMENT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(body)
	_add_close()
