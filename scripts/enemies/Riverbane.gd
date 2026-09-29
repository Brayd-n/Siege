class_name Riverbane
extends SiegeTroll
## Regenerates constantly (twice as fast near water) unless it is burning.

const REGEN := 0.022


func _init() -> void:
	super._init()
	enemy_type = "riverbane"
	throw_every = 10.0


func _special_process(delta: float) -> void:
	super._special_process(delta)
	if is_burning() or not alive:
		return
	var rate := REGEN * (2.0 if map and map.near_water(global_position, 6.0) else 1.0)
	if hp < max_hp:
		hp = min(max_hp, hp + max_hp * rate * delta)
		_apply_damage(0.0, null, false)
