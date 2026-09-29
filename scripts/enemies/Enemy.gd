class_name Enemy
extends Node3D
## Base enemy: follows the road by distance ("progress"), takes typed damage,
## suffers status effects, attacks soldiers it walks past, pays gold on death
## and costs castle lives if it reaches the gate.

@export var enemy_type: String = "goblin"

var def: Dictionary = {}
var display_name: String = ""
var max_hp: float = 50.0
var hp: float = 50.0
var speed: float = 3.0
var reward: int = 10
var lives_cost: int = 1
var armor: float = 0.0
var resist: Dictionary = {}
var is_heavy: bool = false
var is_boss: bool = false
var flying: bool = false
var fly_height: float = 0.0
var contact_damage: float = 0.0
var contact_range: float = 2.0

var undead: bool = false
var elite: bool = false
var path_idx: int = 0         ## which road this enemy walks (maps can have several)
var immune_timer: float = 0.0 ## boss shield phases
var buff_timer: float = 0.0   ## Warlord's war cry: faster and tougher
var buff_speed: float = 1.0
var buff_dr: float = 0.0
var reveal_timer: float = 0.0 ## night maps: lit by a light source recently
var armor_break_timer: float = 0.0 ## Alchemist acid: no armour
var chill_timer: float = 0.0       ## Frost Mage: takes +25% projectile damage
var mark_stacks: int = 0           ## Lyra's Hunter's Mark
var mark_timer: float = 0.0
var blocked_barricade: Node3D = null
var _barricade_scan: float = 0.0
var elite_fx: MeshInstance3D

var progress: float = 0.0     ## distance travelled along the road
var lateral: float = 0.0      ## sideways offset from the road centre
var alive: bool = true
var burn_time: float = 0.0
var burn_dps: float = 0.0
var burn_source: Node = null
var slow_time: float = 0.0
var slow_mult: float = 1.0
var contact_timer: float = 0.0
var anim_t: float = 0.0
var attack_anim: float = 0.0
var hit_pop: float = 0.0
var model_scale: float = 1.0
var height: float = 1.8       ## used for health bar & hit point placement

var map: GameMap
var rig: Dictionary = {}
var hp_bar: MeshInstance3D
var burn_fx: GPUParticles3D

@onready var model_root: Node3D = $Model


const BASE_SCALE := 1.35


func _ready() -> void:
	add_to_group("enemies")
	model_scale *= BASE_SCALE
	def = EnemyDefs.get_def(enemy_type)
	display_name = def.get("name", enemy_type)
	rig = ModelBuilder.build_enemy(enemy_type)
	model_root.add_child(rig["root"])
	model_root.scale = Vector3.ONE * model_scale
	_build_health_bar()
	anim_t = randf() * 10.0


## Called by EnemyManager right after instancing.
func setup(game_map: GameMap, hp_mult: float, speed_mult: float) -> void:
	map = game_map
	if def.is_empty():
		def = EnemyDefs.get_def(enemy_type)
	max_hp = float(def.get("hp", 50.0)) * hp_mult
	hp = max_hp
	speed = float(def.get("speed", 3.0)) * speed_mult * randf_range(0.95, 1.05)
	reward = int(def.get("reward", 10))
	lives_cost = int(def.get("lives", 1))
	armor = float(def.get("armor", 0.0))
	resist = def.get("resist", {})
	is_heavy = bool(def.get("heavy", false))
	contact_damage = float(def.get("contact", 0.0))
	contact_range = float(def.get("contact_range", 2.0))
	undead = bool(def.get("undead", false))
	if def.get("boss", false):
		is_boss = true
	if is_boss:
		hp_bar.scale = Vector3.ONE * 1.6
		hp_bar.position.y = height * model_scale + 0.6
	if not flying:
		lateral = randf_range(-0.7, 0.7)
	path_idx = map.pick_path_for_spawn()
	global_position = map.sample_on(path_idx, 0.0)


## Tougher golden variant. Elites drop a relic when killed.
func make_elite() -> void:
	elite = true
	max_hp *= 3.2
	hp = max_hp
	reward *= 4
	lives_cost *= 2
	model_scale *= 1.3
	display_name = "Elite " + display_name
	contact_damage *= 1.6
	elite_fx = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.75
	t.outer_radius = 0.85
	elite_fx.mesh = t
	elite_fx.material_override = Mats.emissive(Color(1.0, 0.75, 0.2), 2.2)
	elite_fx.scale = Vector3(model_scale, 0.08, model_scale)
	elite_fx.position.y = 0.05
	elite_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(elite_fx)
	hp_bar.scale = Vector3.ONE * 1.3
	hp_bar.position.y = height * model_scale + 0.45


## Remaining road distance to the castle (used for First/Last targeting).
func remaining() -> float:
	if map == null:
		return 0.0
	return map.length_of(path_idx) - progress


func _build_health_bar() -> void:
	hp_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 0.13) * (1.6 if is_boss else 1.0)
	hp_bar.mesh = q
	var m := ShaderMaterial.new()
	m.shader = Mats.shader("res://assets/shaders/healthbar.gdshader")
	hp_bar.material_override = m
	hp_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hp_bar.position = Vector3(0, height * model_scale + 0.35, 0)
	hp_bar.visible = false
	add_child(hp_bar)


func _process(delta: float) -> void:
	if not alive or map == null:
		return
	_update_status(delta)
	if not alive:
		return
	if elite_fx:
		elite_fx.rotation.y += delta * 1.5
	if not _custom_move(delta):
		var move := speed * delta * move_mult()
		progress += move
		if progress >= map.length_of(path_idx):
			_reach_castle()
			return
		var p := map.sample_on(path_idx, progress)
		var dir := map.dir_on(path_idx, progress)
		var side := Vector3(-dir.z, 0, dir.x)
		global_position = p + side * lateral + Vector3.UP * fly_height
		var target_yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clamp(delta * 8.0, 0.0, 1.0))
	if not alive:
		return
	anim_t += delta * speed
	attack_anim = max(0.0, attack_anim - delta * 3.0)
	hit_pop = max(0.0, hit_pop - delta * 6.0)
	model_root.scale = Vector3.ONE * model_scale * (1.0 + hit_pop * 0.12)
	_animate(delta)
	_special_process(delta)
	if contact_damage > 0.0 or (blocked_barricade != null and is_instance_valid(blocked_barricade)):
		_contact_attack(delta)


## Speed multiplier from slows, stuns and buffs.
func move_mult() -> float:
	var m := 1.0
	if slow_time > 0.0:
		m *= slow_mult
	if buff_timer > 0.0:
		m *= buff_speed
	if blocked_by != null and is_instance_valid(blocked_by) and not blocked_by.downed \
			and Vector2(blocked_by.global_position.x - global_position.x, blocked_by.global_position.z - global_position.z).length() < 3.0:
		m = 0.0
	if blocked_barricade != null and is_instance_valid(blocked_barricade):
		m = 0.0
	return m


## Barricades on the road stop ground enemies.
func _check_barricades(delta: float) -> void:
	_barricade_scan -= delta
	if _barricade_scan > 0.0:
		return
	_barricade_scan = 0.2
	if blocked_barricade != null and not is_instance_valid(blocked_barricade):
		blocked_barricade = null
	if flying or is_boss or map == null or map.barricades.is_empty():
		return
	for b in map.barricades:
		if is_instance_valid(b) and Vector2(b.global_position.x - global_position.x, b.global_position.z - global_position.z).length() < 1.9:
			blocked_barricade = b
			return


func add_mark() -> void:
	mark_stacks = mini(5, mark_stacks + 1)
	mark_timer = 6.0


var blocked_by: FriendlyUnit = null    ## a hero / barricade holding this enemy in place


## Subclasses return true when they moved themselves this frame (e.g. sappers
## leaving the road to charge a soldier).
func _custom_move(_delta: float) -> bool:
	return false


## Walk cycle for humanoids; subclasses override for special rigs.
func _animate(_delta: float) -> void:
	var s := sin(anim_t * 2.6)
	if rig.has("leg_l"):
		(rig["leg_l"] as Node3D).rotation.x = s * 0.6
		(rig["leg_r"] as Node3D).rotation.x = -s * 0.6
	if rig.has("arm_l"):
		(rig["arm_l"] as Node3D).rotation.x = -s * 0.4
	if rig.has("arm_r"):
		(rig["arm_r"] as Node3D).rotation.x = s * 0.35 - attack_anim * 1.8
	if rig.has("body"):
		(rig["body"] as Node3D).position.y = abs(sin(anim_t * 2.6)) * 0.08


func _special_process(_delta: float) -> void:
	pass


func _contact_attack(delta: float) -> void:
	contact_timer -= delta
	if contact_timer > 0.0:
		return
	var um := GameManager.unit_manager
	if um == null:
		return
	var target: FriendlyUnit = um.nearest_unit(global_position, contact_range, "", true)
	if target:
		contact_timer = 1.3
		attack_anim = 1.0
		target.take_damage(contact_damage, self)
	elif blocked_barricade != null and is_instance_valid(blocked_barricade):
		contact_timer = 1.3
		attack_anim = 1.0
		blocked_barricade.call("take_damage", max(contact_damage, 8.0))
	else:
		contact_timer = 0.2


func _update_status(delta: float) -> void:
	if burn_time > 0.0:
		burn_time -= delta
		var src: Node = burn_source if is_instance_valid(burn_source) else null
		_apply_damage(burn_dps * delta * _resist_mult(Damage.Type.FIRE), src, false)
		if burn_fx == null:
			burn_fx = FX.fire_emitter(0.9 * model_scale)
			burn_fx.position = Vector3(0, height * model_scale * 0.5, 0)
			add_child(burn_fx)
		burn_fx.emitting = true
	elif burn_fx and burn_fx.emitting:
		burn_fx.emitting = false
	if slow_time > 0.0:
		slow_time -= delta
	if buff_timer > 0.0:
		buff_timer -= delta
	if immune_timer > 0.0:
		immune_timer -= delta
	if reveal_timer > 0.0:
		reveal_timer -= delta
	if armor_break_timer > 0.0:
		armor_break_timer -= delta
	if chill_timer > 0.0:
		chill_timer -= delta
	if mark_timer > 0.0:
		mark_timer -= delta
		if mark_timer <= 0.0:
			mark_stacks = 0
	_check_barricades(delta)


## Night maps: enemies in the dark can't be targeted.
func is_hidden() -> bool:
	return map != null and map.is_dark and reveal_timer <= 0.0 and not is_burning()


func apply_buff(speed_mult: float, dr: float, duration: float) -> void:
	buff_speed = speed_mult
	buff_dr = dr
	buff_timer = max(buff_timer, duration)


func is_burning() -> bool:
	return burn_time > 0.0


func apply_burn(dps: float, duration: float, source: Node = null) -> void:
	if source:
		burn_source = source
	burn_dps = max(burn_dps if burn_time > 0.0 else 0.0, dps)
	burn_time = max(burn_time, duration)


func apply_slow(mult: float, duration: float) -> void:
	slow_mult = min(slow_mult if slow_time > 0.0 else 1.0, mult)
	slow_time = max(slow_time, duration)


func _resist_mult(dtype: int) -> float:
	return float(resist.get(dtype, 1.0))


## Main damage entry point. Returns damage actually dealt.
func take_damage(amount: float, dtype: int, source: Node = null) -> float:
	if not alive:
		return 0.0
	if immune_timer > 0.0:
		if randf() < 0.15:
			FX.float_text(global_position + Vector3.UP * (height * model_scale + 0.3), "IMMUNE", Color(0.7, 0.6, 1.0), 40)
		return 0.0
	amount = _modify_incoming(amount, dtype, source)
	if undead and is_instance_valid(source) and source.has_method("holy_mult"):
		amount *= source.holy_mult()
	if buff_timer > 0.0:
		amount *= 1.0 - buff_dr
	if mark_stacks > 0:
		amount *= 1.0 + 0.06 * mark_stacks
	var arm := armor if armor_break_timer <= 0.0 else 0.0
	if source is FriendlyUnit and BoonManager.has_relic("dragonglass"):
		arm = 0.0
	if dtype == Damage.Type.PIERCING:
		arm *= 0.25
	elif dtype == Damage.Type.FIRE:
		arm *= 0.5
	elif dtype == Damage.Type.ARCANE:
		arm = 0.0
	var dmg := amount * _resist_mult(dtype) * (1.0 - arm)
	if BoonManager.has_flag("dragonsbane") and (enemy_type == "troll" or enemy_type == "dragon"):
		dmg *= 1.5
	_apply_damage(dmg, source, true)
	return dmg


## Subclasses reduce/redirect damage (shields). Returns the new amount.
func _modify_incoming(amount: float, _dtype: int, _source: Node) -> float:
	return amount


func _apply_damage(dmg: float, source: Node, pop: bool) -> void:
	if not alive:
		return
	hp -= dmg
	if pop:
		hit_pop = 1.0
	hp_bar.visible = hp < max_hp
	var f: float = clamp(hp / max_hp, 0.0, 1.0)
	hp_bar.set_instance_shader_parameter("fill", f)
	hp_bar.set_instance_shader_parameter("bar_color", Color(0.9, 0.25, 0.2).lerp(Color(0.35, 0.85, 0.3), f))
	if hp <= 0.0:
		die(source)


func die(killer: Node) -> void:
	if not alive:
		return
	alive = false
	var paid := EconomyManager.reward_kill(reward * (2 if (is_heavy or is_boss) and BoonManager.has_flag("bounty") else 1))
	FX.float_text(global_position + Vector3.UP * (height * model_scale + 0.3), "+%d" % paid, Color(1.0, 0.84, 0.3), 44 if not is_boss else 90)
	FX.death_puff(global_position, model_scale)
	Sfx.play("death", -6.0, 0.15, 0.04)
	Sfx.play("coin", -10.0, 0.1, 0.08)
	EventBus.enemy_killed.emit(self, killer)
	if GameManager.enemy_manager:
		GameManager.enemy_manager.record_corpse(self)
	if elite:
		EventBus.elite_killed.emit(self)
	if elite_fx:
		elite_fx.visible = false
	hp_bar.visible = false
	if burn_fx:
		burn_fx.emitting = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(model_root, "rotation:x", -PI * 0.5, 0.35)
	tw.tween_property(model_root, "position:y", -0.4 * model_scale, 0.6).set_delay(0.3)
	tw.tween_property(model_root, "scale", Vector3.ONE * model_scale * 0.6, 0.6).set_delay(0.3)
	tw.chain().tween_callback(queue_free)


func _reach_castle() -> void:
	alive = false
	GameManager.lose_lives(lives_cost)
	Sfx.play("bell", -4.0, 0.05, 0.2)
	EventBus.enemy_reached_castle.emit(self)
	EventBus.feed_message.emit("Castle Gate", "A %s broke through! -%d %s" % [display_name, lives_cost, "life" if lives_cost == 1 else "lives"], UiTheme.RED)
	queue_free()


## World point projectiles aim at.
func aim_point() -> Vector3:
	return global_position + Vector3.UP * height * model_scale * 0.55


## 0..1 fraction of road travelled.
func path_fraction() -> float:
	if map == null:
		return 0.0
	return progress / map.length_of(path_idx)
