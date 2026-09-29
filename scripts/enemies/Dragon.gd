class_name Dragon
extends Enemy
## Boss. Flies above the road, flaps its wings and breathes fire on soldiers.

const BREATH_RANGE := 11.0
const BREATH_RADIUS := 3.5
const BREATH_DAMAGE := 45.0

var breath_timer: float = 6.0
var breath_fx: GPUParticles3D
var breathing: float = 0.0
var breath_target: Vector3
var breath_rate := 1.0
var breath_colors: Array = [Color(1, 0.95, 0.6, 1), Color(1, 0.45, 0.1, 0.9), Color(0.3, 0.05, 0.02, 0.0)]


func _init() -> void:
	enemy_type = "dragon"
	height = 2.0
	flying = true
	fly_height = 6.5
	is_boss = true


func _ready() -> void:
	super._ready()
	breath_fx = FX.make_particles({
		"one_shot": false, "amount": 70, "lifetime": 0.7, "direction": Vector3(0, 0, 1), "spread": 12.0,
		"vel_min": 10.0, "vel_max": 14.0, "gravity": Vector3(0, -2, 0), "size_min": 0.6, "size_max": 1.3,
		"scale_start": 0.4, "scale_end": 2.2, "local": false,
		"colors": breath_colors,
	})
	breath_fx.emitting = false
	(rig["mouth"] as Node3D).add_child(breath_fx)
	Sfx.play("roar", 2.0, 0.0, 1.0)
	EventBus.camera_shake.emit(0.6)


func _animate(delta: float) -> void:
	var t := anim_t * 0.9
	var flap := sin(t * 2.2)
	var wings: Array = rig["wings"]
	(wings[0] as Node3D).rotation.z = flap * 0.55
	(wings[1] as Node3D).rotation.z = flap * 0.55
	(rig["body"] as Node3D).position.y = -flap * 0.35
	(rig["neck"] as Node3D).rotation.x = sin(t * 1.1) * 0.08 - breathing * 0.25
	(rig["jaw"] as Node3D).rotation.x = 0.1 + breathing * 0.5 + max(0.0, sin(t * 0.4)) * 0.1
	var tail: Array = rig["tail"]
	for i in tail.size():
		(tail[i] as Node3D).rotation.y = sin(t * 1.4 - i * 0.6) * 0.12
		(tail[i] as Node3D).rotation.x = sin(t * 1.1 - i * 0.5) * 0.05
	if breathing > 0.0:
		breathing = max(0.0, breathing - delta)
		if breathing <= 0.0:
			breath_fx.emitting = false


func _special_process(delta: float) -> void:
	breath_timer -= delta
	if breath_timer > 0.0:
		return
	var um := GameManager.unit_manager
	if um == null:
		return
	var ground := Vector3(global_position.x, 0, global_position.z)
	var target: FriendlyUnit = um.nearest_unit(ground, BREATH_RANGE, "", true)
	if target == null:
		breath_timer = 0.5
		return
	breath_timer = randf_range(4.5, 6.0) * breath_rate
	breath_target = target.global_position
	breathing = 1.2
	breath_fx.emitting = true
	var mouth: Node3D = rig["mouth"]
	mouth.look_at(breath_target + Vector3.UP * 0.5, Vector3.UP)
	mouth.rotate_object_local(Vector3.UP, PI)  # particles emit along +Z
	Sfx.play("whoosh", 2.0, 0.1, 0.3)
	Sfx.play("roar", -6.0, 0.2, 2.0)
	get_tree().create_timer(0.45, false).timeout.connect(_breath_impact)


func _breath_impact() -> void:
	if not alive:
		return
	FX.explosion(breath_target, BREATH_RADIUS)
	EventBus.camera_shake.emit(0.35)
	var um := GameManager.unit_manager
	if um == null:
		return
	for u in um.units_near(breath_target, BREATH_RADIUS):
		_breath_hit(u as FriendlyUnit)


## What the breath does to one soldier (Frost Wyrm freezes instead).
func _breath_hit(u: FriendlyUnit) -> void:
	u.take_damage(BREATH_DAMAGE, self)


func aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.3
