class_name Orc
extends Enemy
## Armoured brute. Resistant to arrows thanks to armour; crossbows pierce it.


func _init() -> void:
	enemy_type = "orc"
	height = 2.2


func _animate(delta: float) -> void:
	super._animate(delta)
	if rig.has("torso"):
		(rig["torso"] as Node3D).rotation.z = sin(anim_t * 1.3) * 0.06
