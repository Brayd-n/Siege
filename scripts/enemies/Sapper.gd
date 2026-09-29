class_name Sapper
extends Enemy
## Carries a lit powder keg. When a soldier is close to the road it leaves the
## path, charges and explodes. Killed early, the keg goes off among its friends.

const NOTICE_RANGE := 7.0
const CHARGE_SPEED := 5.5
const BLAST_RADIUS := 3.2
const SOLDIER_DAMAGE := 75.0
const ENEMY_DAMAGE := 110.0

var charging: FriendlyUnit = null
var charge_pos: Vector3
var scan := 0.0


func _init() -> void:
	enemy_type = "sapper"
	height = 1.1


func _special_process(delta: float) -> void:
	var spark: Node3D = rig.get("spark")
	if spark:
		spark.scale = Vector3.ONE * (0.7 + 0.5 * absf(sin(anim_t * 9.0)))
	if charging != null:
		return
	scan -= delta
	if scan > 0.0:
		return
	scan = 0.25
	var um := GameManager.unit_manager
	if um == null:
		return
	var t: FriendlyUnit = um.nearest_unit(global_position, NOTICE_RANGE, "", true)
	if t:
		charging = t
		Sfx.play("whoosh", -6.0, 0.2, 0.3)


func _custom_move(delta: float) -> bool:
	# a barricade in the way: blow it up (and anyone next to it)
	if blocked_barricade != null and is_instance_valid(blocked_barricade):
		blocked_barricade.call("take_damage", 400.0)
		_detonate(true)
		return true
	if charging == null:
		return false
	if is_instance_valid(charging) and not charging.downed:
		charge_pos = charging.global_position
	var to := charge_pos - global_position
	to.y = 0
	if to.length() < 1.3 or not is_instance_valid(charging):
		_detonate(true)
		return true
	var step := to.normalized() * CHARGE_SPEED * delta * move_mult()
	global_position += step
	rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), clamp(delta * 10.0, 0.0, 1.0))
	return true


func _detonate(on_soldiers: bool) -> void:
	if not alive:
		return
	var p := global_position
	FX.explosion(p, BLAST_RADIUS)
	EventBus.camera_shake.emit(0.25)
	Sfx.play("explosion", -2.0, 0.2, 0.1)
	var um := GameManager.unit_manager
	if on_soldiers and um:
		for u in um.units_near(p, BLAST_RADIUS):
			(u as FriendlyUnit).take_damage(SOLDIER_DAMAGE, self)
	alive = false
	if GameManager.enemy_manager:
		GameManager.enemy_manager.enemies.erase(self)
	queue_free()


## Shot down before reaching anyone: the keg hurts nearby enemies instead.
func die(killer: Node) -> void:
	if not alive:
		return
	var p := global_position
	super.die(killer)
	FX.explosion(p, BLAST_RADIUS)
	Sfx.play("explosion", -4.0, 0.2, 0.1)
	var em := GameManager.enemy_manager
	if em:
		for e in em.enemies_near(p, BLAST_RADIUS, false):
			if e != self:
				(e as Enemy).take_damage(ENEMY_DAMAGE, Damage.Type.FIRE, killer)
	# cut down point-blank, the keg still catches whoever did it
	var um := GameManager.unit_manager
	if um:
		for u in um.units_near(p, BLAST_RADIUS * 0.8):
			(u as FriendlyUnit).take_damage(SOLDIER_DAMAGE * 0.6, self)
