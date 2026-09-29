class_name SiegeTroll
extends Troll
## Old Mossback: hurls boulders at soldiers, stunning them.

const THROW_RANGE := 16.0
const THROW_DAMAGE := 55.0
const THROW_RADIUS := 2.6
const STUN := 2.0
var throw_every := 6.5
var throw_timer := 4.0


func _init() -> void:
	enemy_type = "siege_troll"
	height = 3.3


func _ready() -> void:
	super._ready()
	model_scale *= 1.3
	model_root.scale = Vector3.ONE * model_scale


func _special_process(delta: float) -> void:
	throw_timer -= delta
	if throw_timer > 0.0:
		return
	var um := GameManager.unit_manager
	if um == null:
		return
	var t: FriendlyUnit = um.nearest_unit(global_position, THROW_RANGE, "", true)
	if t == null:
		throw_timer = 0.5
		return
	throw_timer = throw_every
	attack_anim = 1.0
	_throw_at(t.global_position)


func _throw_at(target: Vector3) -> void:
	var fx_parent: Node = GameManager.main.get_node("Effects") if GameManager.main else get_parent()
	# telegraph ring on the ground
	FX.magic_ring(target, Color(1.0, 0.3, 0.2), THROW_RADIUS)
	var rock := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.45
	m.height = 0.8
	rock.mesh = m
	rock.material_override = Mats.get_mat("rock")
	fx_parent.add_child(rock)
	var start := global_position + Vector3.UP * height * model_scale * 0.8
	rock.global_position = start
	var tw := rock.create_tween()
	var dur := 1.1
	tw.tween_method(SiegeTroll._arc.bind(rock, start, target), 0.0, 1.0, dur)
	tw.tween_callback(SiegeTroll._impact.bind(target, rock))
	Sfx.play("whoosh", -2.0, 0.2, 0.5)


static func _arc(t: float, rock: Node3D, a: Vector3, b: Vector3) -> void:
	if is_instance_valid(rock):
		rock.global_position = a.lerp(b, t) + Vector3.UP * sin(t * PI) * 7.0
		rock.rotation = Vector3(t * 8.0, t * 5.0, 0)


static func _impact(target: Vector3, rock: Node3D) -> void:
	if is_instance_valid(rock):
		rock.queue_free()
	FX.death_puff(target, 2.0)
	FX.hit_sparks(target, Color(0.8, 0.7, 0.55))
	EventBus.camera_shake.emit(0.2)
	Sfx.play("explosion", -8.0, 0.2, 0.08)
	var um := GameManager.unit_manager
	if um == null:
		return
	for u in um.units_near(target, THROW_RADIUS):
		(u as FriendlyUnit).take_damage(THROW_DAMAGE, null)
		(u as FriendlyUnit).stun(STUN, "stunned")
