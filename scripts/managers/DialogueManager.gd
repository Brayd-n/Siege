extends Node
## NPC <-> NPC coordination. Listens to the communication signals soldiers
## broadcast on the EventBus and decides who answers and how their behaviour
## changes:
##   heavy_enemy_spotted  -> nearby Crossbowmen / Torch Throwers focus that enemy
##   ally_needs_support   -> nearest Knight leaves its post to protect the ally
##   dragon_spotted       -> every ranged soldier focuses the dragon
## Also plays kill reactions, man-down callouts, wave-end chatter and random
## banter between nearby soldiers (with cooldowns so it never spams).

var banter_timer: float = 25.0
var kill_react_cd: float = 0.0
var global_line_cd: float = 0.0


func _ready() -> void:
	EventBus.heavy_enemy_spotted.connect(_on_heavy_spotted)
	EventBus.ally_needs_support.connect(_on_support_request)
	EventBus.dragon_spotted.connect(_on_dragon_spotted)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.wave_completed.connect(_on_wave_completed)
	EventBus.unit_downed.connect(_on_unit_downed)
	EventBus.boon_picked.connect(_on_boon_picked)
	EventBus.cavalry_spotted.connect(_on_cavalry_spotted)
	EventBus.threat_spotted.connect(_on_threat_spotted)


func _process(delta: float) -> void:
	kill_react_cd = max(0.0, kill_react_cd - delta)
	global_line_cd = max(0.0, global_line_cd - delta)
	if GameManager.state != GameManager.State.WAVE:
		return
	banter_timer -= delta
	if banter_timer <= 0.0:
		banter_timer = randf_range(22.0, 36.0)
		_random_banter()


func _units() -> Array:
	var um := GameManager.unit_manager
	return um.units if um else []


## Delayed line so replies feel like a conversation. Safe if the unit is gone.
func _say_later(u: FriendlyUnit, text: String, delay: float, priority: int = 1) -> void:
	get_tree().create_timer(delay, false).timeout.connect(_deliver.bind(u, text, priority))


func _deliver(u, text: String, priority: int) -> void:
	if is_instance_valid(u) and not (u as FriendlyUnit).downed:
		(u as FriendlyUnit).say(text, priority)


func _dist(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


# ------------------------------------------------------------------ heavy enemy
func _on_heavy_spotted(enemy, spotter) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(spotter):
		return
	var sp := spotter as FriendlyUnit
	var responders: Array = []
	for u in _units():
		var fu := u as FriendlyUnit
		if fu == sp or fu.downed:
			continue
		if not fu.unit_type in ["crossbowman", "torch_thrower", "battle_mage", "trebuchet"]:
			continue
		if not fu.can_target(enemy):
			continue
		if _dist(fu, sp) <= sp.comm_range():
			responders.append(fu)
	if responders.is_empty():
		return
	responders.sort_custom(func(a, b): return _dist(a, sp) < _dist(b, sp))
	for i in responders.size():
		var r := responders[i] as FriendlyUnit
		r.receive_priority(enemy, 9.0, "%s's warning" % sp.display_name)
	var first := responders[0] as FriendlyUnit
	var reply := DialogueDB.pick(DialogueDB.HEAVY_REPLY.get(first.unit_type, ["I see it."]))
	_say_later(first, reply, 0.9, 2)
	EventBus.feed_message.emit("Orders", "%s focuses the %s after %s's warning." % [first.display_name, (enemy as Enemy).display_name, sp.display_name], Color(0.7, 0.8, 1.0))


# ------------------------------------------------------------------ new threats
## Sappers, necromancers, shield walls and bat swarms: the soldiers best suited
## to each threat switch to it.
func _on_threat_spotted(enemy, spotter, kind: String) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(spotter):
		return
	var sp := spotter as FriendlyUnit
	var types: Array = DialogueDB.THREAT_RESPONDERS.get(kind, [])
	var secs := {"sapper": 6.0, "necromancer": 10.0, "shields": 8.0, "bats": 5.0}.get(kind, 6.0) as float
	var responders: Array = []
	for u in _units():
		var fu := u as FriendlyUnit
		if fu == sp or fu.downed or not fu.unit_type in types or not fu.can_target(enemy):
			continue
		if _dist(fu, sp) <= sp.comm_range():
			responders.append(fu)
	if responders.is_empty():
		return
	responders.sort_custom(func(a, b): return _dist(a, sp) < _dist(b, sp))
	for r in responders:
		(r as FriendlyUnit).receive_priority(enemy, secs, "%s's warning" % sp.display_name)
	var first := responders[0] as FriendlyUnit
	_say_later(first, DialogueDB.pick(DialogueDB.THREAT_REPLY.get(kind, ["On it."])), 0.8, 2)
	var who := "%s turns" % (responders[0] as FriendlyUnit).display_name if responders.size() == 1 else "%d soldiers turn" % responders.size()
	EventBus.feed_message.emit("Orders", "%s on the %s after %s's warning." % [who, (enemy as Enemy).display_name, sp.display_name], Color(0.7, 0.8, 1.0))


# ------------------------------------------------------------------ support request
func _on_support_request(unit, threat) -> void:
	if not is_instance_valid(unit):
		return
	var asker := unit as FriendlyUnit
	var best: FriendlyUnit = null
	var bd := asker.comm_range()
	for u in _units():
		var fu := u as FriendlyUnit
		if fu.unit_type != "knight" or fu.downed or fu == asker or fu.is_hero():
			continue
		if fu.support_timer > 0.0 and is_instance_valid(fu.support_ally) and fu.support_ally != asker:
			continue
		var d := _dist(fu, asker)
		if d < bd:
			bd = d
			best = fu
	if best == null:
		return
	best.receive_support_request(asker, 7.0)
	asker.note_event("saved_by", best.display_name)
	_say_later(best, DialogueDB.pick(DialogueDB.SUPPORT_REPLY), 0.8, 2)
	EventBus.feed_message.emit("Orders", "%s leaves their post to protect %s." % [best.display_name, asker.display_name], Color(0.7, 0.8, 1.0))


# ------------------------------------------------------------------ dragon
func _on_dragon_spotted(dragon, spotter) -> void:
	var delay := 0.9
	var spoke := 0
	var list := _units().duplicate()
	list.shuffle()
	for u in list:
		var fu := u as FriendlyUnit
		if fu == spotter or fu.downed:
			continue
		if fu.unit_type != "knight":
			fu.receive_priority(dragon, 12.0, "Dragon alarm")
		if spoke < 3:
			_say_later(fu, DialogueDB.pick(DialogueDB.DRAGON_REPLY.get(fu.unit_type, ["Aim for the beast!"])), delay, 3)
			delay += 0.9
			spoke += 1
	var nm: String = (dragon as Enemy).def.get("title", (dragon as Enemy).display_name) if is_instance_valid(dragon) else "the boss"
	EventBus.feed_message.emit("Orders", "Every soldier turns their weapons on %s!" % nm, Color(1.0, 0.55, 0.3))


# ------------------------------------------------------------------ kill reactions
func _on_enemy_killed(enemy, killer) -> void:
	if kill_react_cd > 0.0 or not is_instance_valid(killer) or not (killer is FriendlyUnit):
		return
	var e := enemy as Enemy
	var notable: bool = e.enemy_type in ["troll", "dragon"] or (e.enemy_type == "orc" and randf() < 0.15)
	if not notable:
		return
	var k := killer as FriendlyUnit
	var mate: FriendlyUnit = GameManager.unit_manager.nearest_unit(k.global_position, k.comm_range(), "", true, k)
	if mate == null:
		return
	kill_react_cd = 8.0
	_say_later(mate, DialogueDB.pick(DialogueDB.by_personality(DialogueDB.KILL_PRAISE, mate.personality)), 0.5, 2)
	_say_later(k, DialogueDB.pick(DialogueDB.KILL_ANSWER), 1.9, 2)


## Wolf riders spotted -> spearmen nearby focus them and shout back.
func _on_cavalry_spotted(enemy, spotter) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(spotter):
		return
	var sp := spotter as FriendlyUnit
	var first: FriendlyUnit = null
	for u in _units():
		var fu := u as FriendlyUnit
		if fu.unit_type == "spearman" and not fu.downed and _dist(fu, sp) <= sp.comm_range():
			fu.receive_priority(enemy, 6.0, "%s's cavalry warning" % sp.display_name)
			if first == null or (first == sp and fu != sp):
				first = fu
	if first:
		_say_later(first, DialogueDB.pick(DialogueDB.CAVALRY_REPLY), 0.8, 2)
		EventBus.feed_message.emit("Orders", "%s braces for the wolf riders." % first.display_name, Color(0.7, 0.8, 1.0))


func _on_unit_downed(unit) -> void:
	var u := unit as FriendlyUnit
	# a cleric in earshot hurries to get them back up
	var cleric: FriendlyUnit = GameManager.unit_manager.nearest_unit(u.global_position, u.comm_range(), "cleric", true, u)
	if cleric:
		u.downed_timer = min(u.downed_timer, 3.0)
		_say_later(cleric, DialogueDB.pick(DialogueDB.CLERIC_RESCUE) % u.display_name, 0.5, 3)
		EventBus.feed_message.emit("Orders", "%s rushes a blessing to %s." % [cleric.display_name, u.display_name], Color(1.0, 0.9, 0.6))
		u.note_event("saved_by", cleric.display_name)
		return
	var mate: FriendlyUnit = GameManager.unit_manager.nearest_unit(u.global_position, u.comm_range(), "", true, u)
	if mate:
		var line := DialogueDB.pick(DialogueDB.DOWN_CALLOUT)
		if line.contains("%s"):
			line = line % u.display_name
		_say_later(mate, line, 0.6, 2)


# ------------------------------------------------------------------ wave end
func _on_wave_completed(_n: int) -> void:
	var list := _units().duplicate()
	if list.size() < 2:
		if list.size() == 1:
			_say_later(list[0], DialogueDB.pick(DialogueDB.WAVE_END_A), 0.8, 1)
		return
	list.shuffle()
	var a := list[0] as FriendlyUnit
	var b: FriendlyUnit = GameManager.unit_manager.nearest_unit(a.global_position, 40.0, "", true, a)
	if b == null:
		b = list[1]
	_say_later(a, DialogueDB.pick(DialogueDB.WAVE_END_A), 0.6, 1)
	_say_later(b, DialogueDB.pick(DialogueDB.WAVE_END_B), 2.2, 1)


func _on_boon_picked(_boon: Dictionary) -> void:
	var list := _units()
	if list.is_empty():
		return
	_say_later(list[randi() % list.size()], DialogueDB.pick(DialogueDB.BOON_REACT), 0.4, 1)


# ------------------------------------------------------------------ banter
func _random_banter() -> void:
	var list := _units().duplicate()
	list.shuffle()
	for u in list:
		var a := u as FriendlyUnit
		if a.downed or a.speak_timer > 0.0:
			continue
		var b: FriendlyUnit = GameManager.unit_manager.nearest_unit(a.global_position, 14.0, "", true, a)
		if b == null or b.speak_timer > 0.0:
			continue
		var pair: Array = DialogueDB.BANTER[randi() % DialogueDB.BANTER.size()]
		a.say(pair[0], 0)
		_say_later(b, pair[1], 2.0, 0)
		return
