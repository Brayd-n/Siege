extends Node
## Tower-defense style placement: translucent ghost under the mouse, a range
## circle projected on the ground (Decal), green/red validity, left click to
## place, right click / Esc to cancel. Also draws the range circle of the
## currently selected unit.

var active_type: String = ""
var placing_hero: bool = false      ## active_type is the hero's base class
var ability_idx: int = -1           ## aiming a hero ability (active_type == "ability")
var ghost: Node3D
var ghost_valid: bool = false
var ghost_error: String = ""
var mouse_ground: Vector3 = Vector3.ZERO
var mouse_on_ground: bool = false

var _range_decal: Decal
var _sel_decal: Decal
var _mat_ok: StandardMaterial3D
var _mat_bad: StandardMaterial3D
var _ring_tex: ImageTexture
var _ring_emi: ImageTexture


func _ready() -> void:
	_make_ring_textures()
	_range_decal = _make_decal()
	_sel_decal = _make_decal()
	var cb: bool = bool(Profile.setting("colorblind"))
	_mat_ok = _ghost_mat(Color(0.3, 0.6, 1.0, 0.45) if cb else Color(0.35, 1.0, 0.45, 0.45))
	_mat_bad = _ghost_mat(Color(1.0, 0.6, 0.1, 0.45) if cb else Color(1.0, 0.25, 0.2, 0.45))
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.unit_deselected.connect(func(): _sel_decal.visible = false)
	EventBus.unit_stats_changed.connect(_on_stats_changed)


func _on_stats_changed(u) -> void:
	if u == GameManager.unit_manager.selected:
		_on_unit_selected(u)


func _ghost_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b)
	m.emission_energy_multiplier = 0.4
	return m


## Builds the ground ring used by range decals: a soft translucent fill with a
## bright rim. Emission only lights the rim (emission ignores alpha).
func _make_ring_textures() -> void:
	var sz := 256
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var emi := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var c := sz * 0.5
	for y in sz:
		for x in sz:
			var d := Vector2(x + 0.5 - c, y + 0.5 - c).length() / c
			var a := 0.0
			var rim := 0.0
			if d <= 1.0:
				a = 0.1 + 0.12 * pow(d, 6.0)
				rim = clamp(1.0 - abs(d - 0.975) / 0.022, 0.0, 1.0)
				var ang := atan2(y - c, x - c)
				if abs(d - 0.92) < 0.008 and fmod(ang + PI, 0.26) < 0.13:
					rim = max(rim, 0.55)
				a = max(a, rim * 0.95)
			img.set_pixel(x, y, Color(1, 1, 1, a))
			emi.set_pixel(x, y, Color(rim, rim, rim, 1.0))
	img.generate_mipmaps()
	emi.generate_mipmaps()
	_ring_tex = ImageTexture.create_from_image(img)
	_ring_emi = ImageTexture.create_from_image(emi)


func _make_decal() -> Decal:
	var d := Decal.new()
	d.texture_albedo = _ring_tex
	d.texture_emission = _ring_emi
	d.emission_energy = 1.2
	d.cull_mask = 1
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	d.visible = false
	add_child(d)
	return d


func _set_decal(d: Decal, pos: Vector3, radius: float, color: Color) -> void:
	d.size = Vector3(radius * 2.0, 8.0, radius * 2.0)
	d.global_position = Vector3(pos.x, 0.0, pos.z)
	d.modulate = color
	d.visible = true


## Range circle colours (colour-blind mode uses blue/orange instead of green/red).
func ok_color() -> Color:
	return Color(0.35, 0.65, 1.0) if Profile.setting("colorblind") else Color(0.45, 1.0, 0.5)


func bad_color() -> Color:
	return Color(1.0, 0.6, 0.1) if Profile.setting("colorblind") else Color(1.0, 0.35, 0.3)


func _on_unit_selected(u: FriendlyUnit) -> void:
	if u == null or not is_instance_valid(u):
		_sel_decal.visible = false
		return
	_set_decal(_sel_decal, u.global_position, u.get_range(), Color(1.0, 0.85, 0.45))


# ------------------------------------------------------------------ placement mode
## Aim (or instantly cast) one of the hero's abilities.
func begin_ability(i: int) -> void:
	var h: FriendlyUnit = GameManager.hero_unit if GameManager.hero_deployed() else null
	if h == null or h.kit == null or GameManager.is_over():
		return
	var ab := h.kit.ability_def(i)
	if not h.kit.ability_unlocked(i):
		EventBus.feed_message.emit(h.display_name, "%s unlocks at hero level %d." % [ab["name"], int(ab["level"])], UiTheme.RED)
		return
	if not h.kit.ability_ready(i):
		EventBus.feed_message.emit(h.display_name, "%s isn't ready yet." % ab["name"], UiTheme.RED)
		return
	if ab.get("target", "none") == "none":
		cancel()
		h.kit.use_ability(i, h.global_position)
		return
	cancel()
	ability_idx = i
	active_type = "ability"
	EventBus.targeting_mode_changed.emit(true, ab["name"])
	EventBus.placement_mode_changed.emit("ability")


## Start placing this run's hero (free, once per game).
func begin_hero() -> void:
	if GameManager.is_over() or GameManager.hero_id == "":
		return
	if GameManager.hero_deployed():
		GameManager.unit_manager.select(GameManager.hero_unit)
		return
	cancel()
	GameManager.unit_manager.deselect()
	var h := HeroDefs.get_hero(GameManager.hero_id)
	placing_hero = true
	_start_ghost(h["base"])
	HeroDefs.decorate({"head": _ghost_rig.get("head"), "torso": _ghost_rig.get("torso")}, GameManager.hero_id)
	ModelBuilder.override_materials(ghost, _mat_ok)


func begin(type: String) -> void:
	if GameManager.is_over():
		return
	cancel()
	if not Profile.is_unit_unlocked(type):
		EventBus.feed_message.emit("Quartermaster", "%s is locked. Beat %s to recruit them." % [UnitDefs.get_def(type)["name"], LevelDefs.unlock_source(type)], UiTheme.RED)
		Sfx.play("click", -4.0)
		return
	var cost := EconomyManager.unit_cost(type)
	if not EconomyManager.can_afford(cost):
		EventBus.feed_message.emit("Quartermaster", "Not enough gold for a %s (%d)." % [UnitDefs.get_def(type)["name"], cost], UiTheme.RED)
		Sfx.play("click", -4.0)
		return
	GameManager.unit_manager.deselect()
	placing_hero = false
	_start_ghost(type)


var _ghost_rig: Dictionary = {}


func _start_ghost(type: String) -> void:
	active_type = type
	_ghost_rig = ModelBuilder.build_unit(type)
	ghost = Node3D.new()
	ghost.add_child(_ghost_rig["root"])
	if placing_hero:
		ghost.scale = Vector3.ONE * 1.15
	# strip lights/particles from the ghost so it reads as a hologram
	_strip_effects(ghost)
	add_child(ghost)
	ModelBuilder.override_materials(ghost, _mat_ok)
	EventBus.placement_mode_changed.emit("hero" if placing_hero else type)


func _strip_effects(n: Node) -> void:
	for c in n.get_children():
		if c is Light3D or c is GPUParticles3D:
			c.queue_free()
		else:
			_strip_effects(c)


func cancel() -> void:
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null
	_range_decal.visible = false
	if ability_idx >= 0:
		ability_idx = -1
		EventBus.targeting_mode_changed.emit(false, "")
	if active_type != "":
		active_type = ""
		placing_hero = false
		EventBus.placement_mode_changed.emit("")


func is_active() -> bool:
	return active_type != ""


func update_mouse(ground: Vector3, on_ground: bool) -> void:
	mouse_ground = ground
	mouse_on_ground = on_ground


func _process(_delta: float) -> void:
	var um := GameManager.unit_manager
	if um and _sel_decal.visible and is_instance_valid(um.selected):
		var sp: Vector3 = um.selected.global_position
		_sel_decal.global_position = Vector3(sp.x, 0.0, sp.z)
	if ability_idx >= 0:
		_aim_ability()
		return
	if not is_active() or ghost == null:
		return
	var p := mouse_ground
	ghost.global_position = p
	ghost.visible = mouse_on_ground
	var road_ok: bool = placing_hero and bool(HeroDefs.get_hero(GameManager.hero_id).get("road_ok", false))
	ghost_error = GameManager.map.placement_error(p, road_ok) if mouse_on_ground else "Point at the ground"
	var cost := 0 if placing_hero else EconomyManager.unit_cost(active_type)
	if ghost_error == "" and GameManager.unit_manager.unit_at(p, 1.5) != null:
		ghost_error = "Another soldier is standing there"
	if ghost_error == "" and not EconomyManager.can_afford(cost):
		ghost_error = "Not enough gold"
	var ok := ghost_error == ""
	if ok != ghost_valid:
		ghost_valid = ok
		ModelBuilder.override_materials(ghost, _mat_ok if ok else _mat_bad)
	var base_def: Dictionary = HeroDefs.make_def(GameManager.hero_id) if placing_hero else UnitDefs.get_def(active_type)
	var r: float = float(base_def["range"]) * BoonManager.get_mult("range", active_type)
	_set_decal(_range_decal, p, r, ok_color() if ok else bad_color())
	_range_decal.visible = mouse_on_ground


func _aim_ability() -> void:
	var h: FriendlyUnit = GameManager.hero_unit if GameManager.hero_deployed() else null
	if h == null:
		cancel()
		return
	var ab := h.kit.ability_def(ability_idx)
	var p := mouse_ground
	if ab.get("target", "") == "road":
		p = GameManager.map.nearest_road_point(p)
	ghost_error = "" if mouse_on_ground else "Point at the ground"
	ghost_valid = ghost_error == ""
	var col := Color(0.55, 0.8, 1.0) if not Profile.setting("colorblind") else Color(0.95, 0.85, 0.3)
	_set_decal(_range_decal, p, float(ab.get("radius", 2.0)), col)
	_range_decal.visible = mouse_on_ground


## Returns true when a unit was placed.
func try_place(keep_placing: bool) -> bool:
	if not is_active():
		return false
	if ability_idx >= 0:
		var h: FriendlyUnit = GameManager.hero_unit if GameManager.hero_deployed() else null
		var idx := ability_idx
		var pos := mouse_ground
		cancel()
		if h and h.kit:
			return h.kit.use_ability(idx, pos)
		return false
	if not ghost_valid:
		EventBus.feed_message.emit("Quartermaster", ghost_error, UiTheme.RED)
		Sfx.play("click", -4.0, 0.0)
		return false
	var type := active_type
	if placing_hero:
		var hu: FriendlyUnit = GameManager.unit_manager.spawn_hero(mouse_ground)
		cancel()
		if hu:
			GameManager.unit_manager.select(hu)
		return hu != null
	var cost := EconomyManager.unit_cost(type)
	if not EconomyManager.spend(cost):
		return false
	var u: FriendlyUnit = GameManager.unit_manager.spawn_unit(type, mouse_ground, cost)
	if keep_placing and EconomyManager.can_afford(EconomyManager.unit_cost(type)):
		return true
	cancel()
	if u:
		GameManager.unit_manager.select(u)
	return true
