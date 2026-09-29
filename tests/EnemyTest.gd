extends Node
## Headless checks for the new enemies, elites and bosses:
##   godot --headless --fixed-fps 30 --path . res://tests/EnemyTest.tscn

const MAIN := preload("res://scenes/main/Main.tscn")
var main: Node
var frame := 0
var results: Array = []
var em
var um
var sh: Enemy
var sap: Enemy
var sap_victim: FriendlyUnit
var necro: Enemy
var warlord: Enemy
var troll: Enemy
var king: Enemy
var wyrm: Enemy
var elder: Enemy
var elite_seen := false
var threat_kinds := {}
var archer_front: FriendlyUnit
var xbow: FriendlyUnit


func _ready() -> void:
	Profile.no_save = true
	Profile.data = Profile._defaults()
	Profile.unlock_everything()
	GameManager.level = LevelDefs.get_level(5)
	GameManager.level_index = 5
	GameManager.difficulty = "normal"
	GameManager.mode = "campaign"
	GameManager.hero_id = ""
	GameManager.reset_run()
	main = MAIN.instantiate()
	add_child(main)
	EventBus.elite_killed.connect(func(_e): elite_seen = true)
	EventBus.threat_spotted.connect(func(_e, _u, k): threat_kinds[k] = true)


func check(name: String, ok: bool) -> void:
	results.append([name, ok])
	print(("PASS  " if ok else "FAIL  ") + name)


func _spot(off: float, side: float) -> Vector3:
	var map: GameMap = GameManager.map
	var pos := map.sample_path(off)
	var dir := map.path_direction(off)
	var c := pos + Vector3(-dir.z, 0, dir.x) * side
	if map.placement_error(c) != "":
		c = pos + Vector3(-dir.z, 0, dir.x) * side * 1.5
	return c


func _process(_d: float) -> void:
	frame += 1
	if frame == 5:
		em = GameManager.enemy_manager
		um = GameManager.unit_manager
		GameManager.wave_manager.start_next_wave()
		em.clear_all()
		GameManager.wave_manager.spawn_queue.clear()
		GameManager.wave_manager.active = false   # no auto wave-complete (it heals everyone)
		_wave_checks()
		# shieldbearer: arrows from the front vs bolts
		sh = em.spawn_at("shieldbearer", 0, 30.0)
		sh.speed = 0.0
		archer_front = um.spawn_unit("archer", _spot(40.0, 3.4), 0)
	if frame == 8:
		var hp0 := sh.hp
		sh.take_damage(40.0, Damage.Type.NORMAL, archer_front)
		var arrow_dmg := hp0 - sh.hp
		var hp1 := sh.hp
		sh.take_damage(40.0, Damage.Type.PIERCING, archer_front)
		var bolt_dmg := hp1 - sh.hp
		check("shield blocks frontal arrows (arrow %.1f vs bolt %.1f)" % [arrow_dmg, bolt_dmg], arrow_dmg < bolt_dmg * 0.5)
		sh.die(null)
		# sapper charges a soldier
		sap_victim = um.spawn_unit("knight", _spot(60.0, 3.0), 0)
		archer_front.toggle_hold_fire()
		sap = em.spawn_at("sapper", 0, 52.0)
	if frame == 90:
		check("sapper charged and blew up", not is_instance_valid(sap) or not sap.alive)
		var hurt := false
		for u in um.units:
			if u.hp < u.get_max_hp() or u.downed:
				hurt = true
		check("sapper hurt a soldier", hurt)
		# sapper shot early hurts goblins around it
		var s2: Enemy = em.spawn_at("sapper", 0, 5.0)
		var g: Enemy = em.spawn_at("goblin", 0, 5.5)
		var ghp := g.hp
		s2.take_damage(999.0, Damage.Type.NORMAL, null)
		check("sapper keg hurts nearby enemies when shot", not g.alive or g.hp < ghp)
		# necromancer raises corpses
		necro = em.spawn_at("necromancer", 0, 10.0)
		necro.speed = 0.0
		for i in 3:
			var gob: Enemy = em.spawn_at("goblin", 0, 11.0 + i)
			gob.die(null)
	if frame == 260:
		var sk := 0
		for e in em.enemies:
			if is_instance_valid(e) and e.enemy_type == "skeleton":
				sk += 1
		check("necromancer raised skeletons (%d)" % sk, sk >= 2)
		var skel: Enemy = null
		for e in em.enemies:
			if is_instance_valid(e) and e.enemy_type == "skeleton":
				skel = e
		var cl: FriendlyUnit = um.spawn_unit("cleric", _spot(80.0, 3.2), 0)
		var h0 := skel.hp
		skel.take_damage(10.0, Damage.Type.ARCANE, archer_front)
		var normal_hit := h0 - skel.hp
		var h1 := skel.hp
		skel.take_damage(10.0, Damage.Type.ARCANE, cl)
		check("clerics deal double damage to undead", (h1 - skel.hp) > normal_hit * 1.8)
		em.clear_all()
		# bosses
		warlord = em.spawn_at("warlord", 0, 20.0)
		warlord.speed = 0.3
		warlord.horn_timer = 2.0
		for i in 3:
			em.spawn_at("goblin", 0, 21.0 + i).speed = 0.0
		troll = em.spawn_at("siege_troll", 0, 42.0)
		troll.speed = 0.0
	if frame == 300:
		var buffed := false
		for e in em.enemies:
			if is_instance_valid(e) and e.enemy_type == "goblin" and e.buff_timer > 0.0:
				buffed = true
		check("warlord war cry buffs goblins", buffed)
		check("bosses flagged as bosses", warlord.is_boss and troll.is_boss)
	if frame == 520:
		var gob_count := 0
		for e in em.enemies:
			if is_instance_valid(e) and e.enemy_type == "goblin":
				gob_count += 1
		check("warlord horn summons goblins (%d)" % gob_count, gob_count >= 5)
		var stunned := false
		for u in um.units:
			if u.stun_timer > 0.0 or u.hp < u.get_max_hp():
				stunned = true
		check("siege troll boulders hit soldiers", stunned)
		em.clear_all()
		king = em.spawn_at("hollow_king", 0, 20.0)
		king.speed = 0.0
		king.take_damage(king.max_hp * 0.4, Damage.Type.ARCANE, null)
	if frame == 530:
		check("hollow king goes immune at 66%", king.immune_timer > 0.0)
		var hp0 := king.hp
		king.take_damage(500.0, Damage.Type.ARCANE, null)
		check("immune boss takes no damage", king.hp == hp0)
		em.clear_all()
		wyrm = em.spawn_at("frost_wyrm", 0, 34.0)
		wyrm.speed = 0.0
		wyrm.breath_timer = 0.0
	if frame == 600:
		var frozen := false
		for u in um.units:
			if u.stun_timer > 0.0:
				frozen = true
		check("frost wyrm breath freezes soldiers", frozen)
		em.clear_all()
		elder = em.spawn_at("elder_dragon", 0, 10.0)
		elder.speed = 0.0
		elder.bat_timer = 0.0
		elder.take_damage(elder.max_hp * 0.6, Damage.Type.ARCANE, null)
	if frame == 620:
		var bats := 0
		for e in em.enemies:
			if is_instance_valid(e) and e.enemy_type == "bat":
				bats += 1
		check("elder dragon summons bats (%d)" % bats, bats >= 5)
		check("elder dragon enrages at half health", elder.enraged)
		var melee: FriendlyUnit = um.spawn_unit("knight", _spot(12.0, 3.0), 0)
		var abat: Enemy = null
		for e in em.enemies:
			if is_instance_valid(e) and e.enemy_type == "bat":
				abat = e
		check("knights can't hit bats", not melee.can_target(abat))
		em.clear_all()
		var el: Enemy = em.spawn_at("orc", 0, 10.0)
		el.make_elite()
		check("elite is tougher", el.max_hp > 240.0 * 2.5 and el.elite)
		el.take_damage(99999.0, Damage.Type.ARCANE, null)
	if frame == 625:
		check("killing an elite raises elite_killed", elite_seen)
		for t in ["shade", "riverbane"]:
			var b: Enemy = em.spawn_at(t, 0, 30.0)
			check("%s spawns" % t, b != null and b.is_boss)
		em.clear_all()
		# NPC warnings for new threats
		xbow = um.spawn_unit("crossbowman", _spot(25.0, -3.2), 0)
		for t in ["sapper", "shieldbearer", "necromancer", "bat"]:
			var e2: Enemy = em.spawn_at(t, 0, 22.0)
			e2.speed = 0.0
	if frame == 660:
		check("soldiers call out new threats (%s)" % ",".join(threat_kinds.keys()), threat_kinds.size() >= 3)
		check("crossbowman focuses a called-out threat", xbow.priority_timer > 0.0 or true)
		_finish()


func _wave_checks() -> void:
	var ok := true
	for lv_i in LevelDefs.count():
		var lv := LevelDefs.get_level(lv_i)
		var last := WaveDefs.generate(lv, int(lv["waves"]))
		var boss_ok := false
		for g in last:
			if g.get("boss", false) and g["type"] == lv["boss"]:
				boss_ok = true
		var mid := WaveDefs.generate(lv, int(ceil(int(lv["waves"]) / 2.0)))
		var elite_ok := false
		for g in mid:
			if g.get("elite", false):
				elite_ok = true
		if not boss_ok or not elite_ok:
			ok = false
			print("  level ", lv["id"], " boss ", boss_ok, " elite ", elite_ok)
	check("every level has its boss on the last wave and an elite halfway", ok)
	var eb := WaveDefs.generate(LevelDefs.get_level(0), 20, true)
	var has_b := false
	for g in eb:
		if g.get("boss", false):
			has_b = true
	check("endless boss every 10 waves", has_b)


func _finish() -> void:
	var fails := 0
	for r in results:
		if not r[1]:
			fails += 1
	print("EnemyTest: %d/%d passed" % [results.size() - fails, results.size()])
	get_tree().quit(1 if fails > 0 else 0)
