extends HeroKit
## Magister Voss: lightning beam that ramps on one target and arcs to two
## more; blinks instead of walking; Meteor and Time Warp.

const TICK := 0.2
var beam_target: Enemy = null
var ramp := 0.0
var tick := 0.0


func perform_attack(_e: Enemy) -> bool:
	return true   # the beam in process() replaces normal bolts


func process(delta: float) -> void:
	tick -= delta
	if tick > 0.0:
		return
	tick = TICK
	var t: Enemy = u.target
	if u.command == "Hold Fire" or t == null or not is_instance_valid(t) or not t.alive:
		beam_target = null
		ramp = 0.0
		return
	if t != beam_target:
		beam_target = t
		ramp = 0.0
	else:
		ramp += TICK * (2.0 if HeroGear.has_legendary(id, "eye_storm") else 1.0)
	var mult: float = min(3.0, 1.0 + 0.25 * ramp)
	var dps := u.get_damage() / u.get_attack_interval()
	var dmg := dps * TICK * mult
	var from := u.global_position + Vector3.UP * 2.6
	var staff: Node3D = u.rig.get("weapon")
	if staff and staff.get_node_or_null("Orb"):
		from = (staff.get_node("Orb") as Node3D).global_position
	hit(t, dmg, Damage.Type.ARCANE)
	FX.beam(from, t.aim_point(), Color(0.6, 0.75, 1.0).lerp(Color(1.0, 1.0, 1.0), (mult - 1.0) / 2.0))
	u.attack_anim = max(u.attack_anim, 0.4)
	# arcs
	var arcs := 0
	for e in enemies_in(t.global_position, 4.5, true):
		if e == t or arcs >= 2:
			continue
		hit(e, dmg * 0.4, Damage.Type.ARCANE)
		FX.beam(t.aim_point(), (e as Enemy).aim_point(), Color(0.55, 0.65, 1.0))
		arcs += 1


func _cast(i: int, pos: Vector3) -> bool:
	if i == 0:
		return _meteor(pos)
	return _time_warp()


func _meteor(pos: Vector3) -> bool:
	var target := Vector3(pos.x, 0, pos.z)
	FX.magic_ring(target, Color(1.0, 0.45, 0.15), 4.5)
	var parent: Node = GameManager.main.get_node("Effects")
	var rock := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.9
	m.height = 1.8
	rock.mesh = m
	rock.material_override = Mats.emissive(Color(1.0, 0.45, 0.1), 3.0)
	parent.add_child(rock)
	var fire := FX.fire_emitter(2.0)
	rock.add_child(fire)
	fire.emitting = true
	var start := target + Vector3(-8, 26, 6)
	rock.global_position = start
	var dmg := ability_damage(8.0)
	var tw := rock.create_tween()
	tw.tween_property(rock, "global_position", target, 1.0).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _meteor_hit(target, dmg, rock))
	u.say("Fire from the heavens!", 2)
	return true


func _meteor_hit(target: Vector3, dmg: float, rock: Node3D) -> void:
	if is_instance_valid(rock):
		rock.queue_free()
	FX.explosion(target, 4.5)
	FX.explosion(target, 2.5)
	EventBus.camera_shake.emit(0.5)
	Sfx.play("explosion", 2.0, 0.1, 0.05)
	if not is_instance_valid(u):
		return
	for e in enemies_in(target, 4.5, true):
		var en := e as Enemy
		hit(en, dmg, Damage.Type.FIRE)
		if en.alive:
			en.apply_burn(20.0, 4.0, u)
			if not en.is_boss:
				en.apply_slow(0.0, 1.0)


func _time_warp() -> bool:
	var em := GameManager.enemy_manager
	for e in em.enemies.duplicate():
		if is_instance_valid(e) and e.alive:
			e.apply_slow(0.5, 5.0)
			FX.hit_sparks(e.aim_point(), Color(0.6, 0.8, 1.0))
	for a in GameManager.unit_manager.units:
		(a as FriendlyUnit).special_cd = max(0.0, a.special_cd - 5.0)
	FX.magic_ring(u.global_position, Color(0.55, 0.75, 1.0), 12.0)
	FX.magic_ring(u.global_position, Color(0.8, 0.9, 1.0), 6.0)
	EventBus.banner.emit("TIME WARP", "The enemy crawls. Your soldiers' specials recharge.", Color(0.6, 0.8, 1.0))
	u.say("Time bends to my will.", 2)
	return true
