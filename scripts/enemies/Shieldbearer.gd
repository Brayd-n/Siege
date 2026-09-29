class_name Shieldbearer
extends Enemy
## Tower shield: ranged NORMAL damage from the front is mostly blocked.
## Crossbow bolts (piercing), arcane, fire and melee get through.

const BLOCK := 0.75
const FRONT_DOT := 0.35
var _block_text_cd := 0.0


func _init() -> void:
	enemy_type = "shieldbearer"
	height = 1.5


func _special_process(delta: float) -> void:
	_block_text_cd = max(0.0, _block_text_cd - delta)


func _modify_incoming(amount: float, dtype: int, source: Node) -> float:
	if dtype != Damage.Type.NORMAL or not is_instance_valid(source) or not (source is Node3D):
		return amount
	var to_src: Vector3 = (source as Node3D).global_position - global_position
	to_src.y = 0
	if to_src.length() < 4.2:
		return amount   # melee reaches around the shield
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	if fwd.dot(to_src.normalized()) > FRONT_DOT:
		if _block_text_cd <= 0.0:
			_block_text_cd = 1.2
			FX.float_text(global_position + Vector3.UP * 2.2, "BLOCKED", Color(0.8, 0.8, 0.85), 34)
			FX.hit_sparks(global_position + fwd * 0.5 + Vector3.UP * 1.1, Color(0.9, 0.85, 0.6))
		return amount * (1.0 - BLOCK)
	return amount
