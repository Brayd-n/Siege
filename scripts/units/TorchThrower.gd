class_name TorchThrower
extends FriendlyUnit
## Area damage. Torches explode and set enemies on fire.
## Special: FIRE PATCH (burning ground on the road).

const PATCH_BASE_DPS := 18.0
const PATCH_RADIUS := 3.0


func _init() -> void:
	unit_type = "torch_thrower"


func blast_radius() -> float:
	return float(def.get("radius", 2.5)) * path_mult("radius") * BoonManager.get_mult("radius", unit_type) * spec_mult("radius")


func burn_duration() -> float:
	return float(def.get("burn_time", 3.0)) + BoonManager.get_add("burn_time")


func burn_dps() -> float:
	return float(def.get("burn_dps", 8.0)) * path_mult("damage") * BoonManager.get_mult("damage", unit_type)


func active_bonuses() -> Array[String]:
	var out := super.active_bonuses()
	out.append("Blast radius %.1fm" % blast_radius())
	return out


func _perform_attack(e: Enemy) -> void:
	var from := global_position + Vector3.UP * 2.6
	Projectile.spawn(Projectile.Kind.TORCH, from, e, get_damage(), Damage.Type.FIRE, self,
		{"radius": blast_radius(), "burn_dps": burn_dps(), "burn_time": burn_duration(),
			"acid": has_spec("acid"), "ground_fire": has_spec("ground_fire")})
	Sfx.play("whoosh", -12.0, 0.2, 0.1)


func _use_special() -> bool:
	var spot := Vector3.ZERO
	var map: GameMap = GameManager.map
	if is_instance_valid(target) and target.alive and not target.flying:
		# lead the target a little so it walks into the fire
		spot = map.sample_on(target.path_idx, target.progress + 2.0)
	else:
		spot = map.nearest_road_point(global_position)
		if _hdist(spot) > get_range():
			say("The road's too far from here!", 1)
			return false
	var dur := float(def["special"]["duration"]) * (2.0 if BoonManager.has_flag("inferno") else 1.0)
	var r := PATCH_RADIUS * BoonManager.get_mult("radius", unit_type)
	FirePatch.create(GameManager.main.get_node("Effects"), spot, r, dur, PATCH_BASE_DPS * path_mult("damage"), self)
	FX.explosion(spot, r)
	say("Pitch on the road! Let it burn!", 2)
	attack_anim = 1.0
	return true


func _animate_attack(a: float) -> void:
	var arm_r: Node3D = rig["arm_r"]
	# wind up over the shoulder then throw
	arm_r.rotation.x = deg_to_rad(-40) - sin(a * PI) * 2.0
