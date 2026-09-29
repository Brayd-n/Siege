class_name Projectile
extends Node3D
## Arrows, crossbow bolts, torches and goblin arrows.
## Projectiles home in on their target along a simple arc: reliable hits,
## no physics. If the target dies mid-flight they land on its last position.

enum Kind { ARROW, BOLT, TORCH, ENEMY_ARROW, ARCANE, BOULDER }

const SCENE_PATH := "res://scenes/projectiles/Projectile.tscn"
static var _scene: PackedScene = null

var kind: int = Kind.ARROW
var target: Node3D = null
var target_pos: Vector3
var start_pos: Vector3
var damage: float = 10.0
var dtype: int = Damage.Type.NORMAL
var source: Node = null
var extra: Dictionary = {}
var t: float = 0.0
var flight_time: float = 0.5
var arc_height: float = 1.0
var _prev: Vector3
var _spin: float = 0.0


## Factory used by units and enemies.
static func spawn(k: int, from: Vector3, tgt: Node3D, dmg: float, dt: int, src: Node, ex: Dictionary = {}) -> Projectile:
	if _scene == null:
		_scene = load(SCENE_PATH)
	var root: Node = null
	if GameManager.main and is_instance_valid(GameManager.main):
		root = GameManager.main.get_node_or_null("Projectiles")
	if root == null:
		return null
	var p: Projectile = _scene.instantiate()
	p.kind = k
	p.target = tgt
	p.damage = dmg
	p.dtype = dt
	p.source = src
	p.extra = ex
	root.add_child(p)
	p.launch(from)
	return p


func launch(from: Vector3) -> void:
	start_pos = from
	global_position = from
	_prev = from
	target_pos = _target_point()
	var dist := from.distance_to(target_pos)
	var spd := 26.0
	match kind:
		Kind.ARROW:
			spd = 28.0
			arc_height = dist * 0.12
		Kind.BOLT:
			spd = 45.0
			arc_height = dist * 0.03
		Kind.TORCH:
			spd = 14.0
			arc_height = 1.2 + dist * 0.25
		Kind.ENEMY_ARROW:
			spd = 20.0
			arc_height = dist * 0.15
		Kind.ARCANE:
			spd = 32.0
			arc_height = dist * 0.05
		Kind.BOULDER:
			spd = 15.0
			arc_height = 4.0 + dist * 0.35
	flight_time = max(0.08, dist / spd)
	_build_visual()


func _target_point() -> Vector3:
	if is_instance_valid(target):
		if target is Enemy:
			return (target as Enemy).aim_point()
		return target.global_position + Vector3.UP * 1.2
	return target_pos


func _build_visual() -> void:
	match kind:
		Kind.ARROW, Kind.ENEMY_ARROW:
			var wood := Mats.get_mat("wood_obj")
			ModelBuilder.add_mesh(self, ModelBuilder.cyl(0.018, 0.018, 0.8, 5), wood, Vector3.ZERO, Vector3(90, 0, 0))
			ModelBuilder.add_mesh(self, ModelBuilder.cone(0.04, 0.12, 4), Mats.get_mat("metal"), Vector3(0, 0, 0.44), Vector3(90, 0, 0))
			var fl := Mats.flat(Color(0.9, 0.9, 0.85)) if kind == Kind.ARROW else Mats.flat(Color(0.2, 0.2, 0.2))
			ModelBuilder.add_mesh(self, ModelBuilder.box(Vector3(0.1, 0.005, 0.14)), fl, Vector3(0, 0, -0.34))
			ModelBuilder.add_mesh(self, ModelBuilder.box(Vector3(0.005, 0.1, 0.14)), fl, Vector3(0, 0, -0.34))
			if kind == Kind.ARROW and extra.get("fire", false):
				var f := FX.fire_emitter(0.35)
				f.position = Vector3(0, 0, 0.3)
				add_child(f)
				f.emitting = true
		Kind.BOLT:
			ModelBuilder.add_mesh(self, ModelBuilder.cyl(0.03, 0.03, 0.55, 6), Mats.get_mat("wood_dark"), Vector3.ZERO, Vector3(90, 0, 0))
			ModelBuilder.add_mesh(self, ModelBuilder.cone(0.06, 0.16, 4), Mats.get_mat("metal"), Vector3(0, 0, 0.34), Vector3(90, 0, 0))
			if extra.get("empowered", false):
				ModelBuilder.add_mesh(self, ModelBuilder.sphere(0.12, 8), Mats.emissive(Color(0.5, 0.8, 1.0), 4.0), Vector3(0, 0, 0.3))
		Kind.ARCANE:
			ModelBuilder.add_mesh(self, ModelBuilder.sphere(0.16, 10), Mats.emissive(Color(0.65, 0.45, 1.0), 6.0), Vector3.ZERO)
			var trail := FX.make_particles({"one_shot": false, "amount": 20, "lifetime": 0.3, "vel_min": 0.1, "vel_max": 0.4,
				"gravity": Vector3.ZERO, "size_min": 0.15, "size_max": 0.25, "local": false,
				"colors": [Color(0.7, 0.5, 1.0, 0.8), Color(0.3, 0.2, 0.9, 0.0)]})
			add_child(trail)
			trail.emitting = true
			var al := OmniLight3D.new()
			al.light_color = Color(0.6, 0.45, 1.0)
			al.light_energy = 1.2
			al.omni_range = 3.5
			add_child(al)
		Kind.BOULDER:
			var rock := ModelBuilder.add_mesh(self, ModelBuilder.sphere(0.35, 10), Mats.get_mat("rock"), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.85, 1.1))
			rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		Kind.TORCH:
			ModelBuilder.add_mesh(self, ModelBuilder.cyl(0.035, 0.04, 0.55, 6), Mats.get_mat("wood_dark"), Vector3.ZERO, Vector3(90, 0, 0))
			var f2 := FX.fire_emitter(0.7)
			f2.position = Vector3(0, 0, 0.3)
			add_child(f2)
			f2.emitting = true
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.6, 0.25)
			l.light_energy = 1.5
			l.omni_range = 4.0
			add_child(l)


func _process(delta: float) -> void:
	t += delta / flight_time
	if is_instance_valid(target) and not (target is Enemy and not (target as Enemy).alive):
		target_pos = _target_point()
	var tt: float = min(t, 1.0)
	var p := start_pos.lerp(target_pos, tt) + Vector3.UP * arc_height * 4.0 * tt * (1.0 - tt)
	global_position = p
	var vel := p - _prev
	if vel.length() > 0.0005:
		look_at(p + vel, Vector3.UP if abs(vel.normalized().y) < 0.98 else Vector3.RIGHT)
		# visuals are built along +Z, look_at points -Z: flip
		rotate_object_local(Vector3.UP, PI)
	if kind == Kind.TORCH:
		_spin += delta * 12.0
		rotate_object_local(Vector3.FORWARD, _spin)
	_prev = p
	if t >= 1.0:
		_impact()


func _impact() -> void:
	set_process(false)
	if not is_instance_valid(source):
		source = null   # shooter was sold / died mid-flight
	match kind:
		Kind.ARROW:
			_hit_single()
		Kind.BOLT:
			_hit_pierce()
		Kind.TORCH:
			_explode()
		Kind.ARCANE:
			_hit_chain()
		Kind.BOULDER:
			_crush()
		Kind.ENEMY_ARROW:
			if is_instance_valid(target) and target is FriendlyUnit:
				(target as FriendlyUnit).take_damage(damage, source)
				FX.hit_sparks(target_pos, Color(0.9, 0.3, 0.2))
	queue_free()


func _credit(enemy: Enemy, dealt: float) -> void:
	if is_instance_valid(source) and source is FriendlyUnit:
		(source as FriendlyUnit).on_damage_dealt(enemy, dealt)
	if is_instance_valid(enemy) and enemy.alive:
		_on_hit(enemy)


## Damage modifiers that depend on the target (specializations).
func _pre(e: Enemy, dmg: float) -> float:
	if extra.get("skyhunter", false) and e.flying:
		dmg *= 2.0
	if e.chill_timer > 0.0:
		dmg *= 1.25   # Frost Mage shatter works for every projectile
	return dmg


## On-hit effects carried by the projectile (specializations).
func _on_hit(e: Enemy) -> void:
	if extra.has("knockback") and not e.is_boss and not e.flying:
		e.progress = max(0.0, e.progress - float(extra["knockback"]))
	if extra.has("chill"):
		var c: Array = extra["chill"]
		e.apply_slow(float(c[0]), float(c[1]))
		e.chill_timer = float(c[1])
	if extra.has("stun") and not e.is_boss:
		e.apply_slow(0.0, float(extra["stun"]))
	if extra.get("acid", false):
		e.armor_break_timer = 5.0
		e.apply_slow(0.75, 3.0)
	if extra.get("smite_burn", false):
		e.apply_burn(10.0, 3.0, source)


func _hit_single() -> void:
	if not (is_instance_valid(target) and target is Enemy):
		return
	var e := target as Enemy
	if not e.alive:
		return
	var dmg := damage
	if e.is_burning():
		dmg *= 1.2  # Torch Thrower + Archer synergy
	var dealt := e.take_damage(_pre(e, dmg), dtype, source)
	_credit(e, dealt)
	if extra.get("fire", false):
		e.apply_burn(6.0, 2.0, source)
	FX.hit_sparks(target_pos, Color(1.0, 0.8, 0.5))
	FX.blood(target_pos, Color(0.35, 0.08, 0.05) if e.enemy_type != "troll" else Color(0.2, 0.25, 0.2))
	Sfx.play("hit", -14.0, 0.2, 0.05)


func _hit_pierce() -> void:
	var em := GameManager.enemy_manager
	var pierce: int = int(extra.get("pierce", 1))
	var dir := (target_pos - start_pos)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var hit_list: Array = []
	if is_instance_valid(target) and target is Enemy and (target as Enemy).alive:
		hit_list.append(target)
	# enemies along the line continuing past the target
	if em and pierce > 0:
		var origin := Vector3(target_pos.x, 0, target_pos.z)
		var candidates: Array = []
		for e in em.enemies:
			if not is_instance_valid(e) or not e.alive or hit_list.has(e):
				continue
			var rel: Vector3 = e.global_position - origin
			rel.y = 0
			var along := rel.dot(dir)
			if along < -1.5 or along > 7.0:
				continue
			var perp := (rel - dir * along).length()
			if perp < 1.1:
				candidates.append([along, e])
		candidates.sort_custom(func(a, b): return a[0] < b[0])
		for c in candidates:
			if hit_list.size() > pierce:
				break
			hit_list.append(c[1])
	var mult := 1.0
	for e in hit_list:
		var dealt: float = (e as Enemy).take_damage(_pre(e, damage * mult), dtype, source)
		_credit(e, dealt)
		FX.hit_sparks((e as Enemy).aim_point(), Color(0.8, 0.9, 1.0))
		mult *= 0.8
	Sfx.play("hit", -12.0, 0.2, 0.05)


func _explode() -> void:
	var radius: float = extra.get("radius", 2.5)
	var burn_dps: float = extra.get("burn_dps", 8.0)
	var burn_time: float = extra.get("burn_time", 3.0)
	FX.explosion(target_pos, radius)
	Sfx.play("explosion", -8.0, 0.15, 0.08)
	if extra.get("ground_fire", false) and GameManager.main:
		FirePatch.create(GameManager.main.get_node("Effects"), Vector3(target_pos.x, 0, target_pos.z), radius * 0.6, 2.5, burn_dps, source)
	var em := GameManager.enemy_manager
	if em == null:
		return
	var center := Vector3(target_pos.x, 0, target_pos.z)
	for e in em.enemies_near(center, radius, true):
		var en := e as Enemy
		var d := Vector2(en.global_position.x - center.x, en.global_position.z - center.z).length()
		var falloff: float = lerp(1.0, 0.6, clamp(d / radius, 0.0, 1.0))
		var dealt := en.take_damage(_pre(en, damage * falloff), Damage.Type.FIRE, source)
		_credit(en, dealt)
		if en.alive:
			en.apply_burn(burn_dps, burn_time, source)


func _hit_chain() -> void:
	var em := GameManager.enemy_manager
	var current: Enemy = target as Enemy if (is_instance_valid(target) and target is Enemy and (target as Enemy).alive) else null
	if current == null:
		return
	var jumps: int = int(extra.get("chain", 2))
	var hit: Array = []
	var dmg := damage
	var from_pt := current.aim_point()
	while current != null:
		var dealt := current.take_damage(_pre(current, dmg), dtype, source)
		_credit(current, dealt)
		FX.hit_sparks(current.aim_point(), Color(0.7, 0.5, 1.0))
		hit.append(current)
		if hit.size() > jumps or em == null:
			break
		var nxt: Enemy = null
		var bd := 4.5
		for e in em.enemies:
			if is_instance_valid(e) and e.alive and not hit.has(e):
				var d: float = e.global_position.distance_to(current.global_position)
				if d < bd:
					bd = d
					nxt = e
		if nxt:
			FX.beam(current.aim_point(), nxt.aim_point(), Color(0.7, 0.55, 1.0))
		current = nxt
		dmg *= 0.7
	Sfx.play("hit", -14.0, 0.3, 0.05)


func _crush() -> void:
	var radius: float = extra.get("radius", 3.0)
	FX.death_puff(target_pos, radius * 0.8)
	FX.hit_sparks(target_pos, Color(0.8, 0.7, 0.55))
	EventBus.camera_shake.emit(0.08)
	Sfx.play("explosion", -10.0, 0.25, 0.08)
	var em := GameManager.enemy_manager
	if em == null:
		return
	var center := Vector3(target_pos.x, 0, target_pos.z)
	if (BoonManager.has_flag("greek_fire") or extra.get("fire_payload", false)) and GameManager.main:
		FirePatch.create(GameManager.main.get_node("Effects"), center, radius * 0.7, 3.0, 10.0, source)
	for e in em.enemies_near(center, radius, false):
		var en := e as Enemy
		var d := Vector2(en.global_position.x - center.x, en.global_position.z - center.z).length()
		var falloff: float = lerp(1.0, 0.5, clamp(d / radius, 0.0, 1.0))
		_credit(en, en.take_damage(_pre(en, damage * falloff), Damage.Type.NORMAL, source))
