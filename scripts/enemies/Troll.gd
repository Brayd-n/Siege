class_name Troll
extends Enemy
## Huge, slow, shrugs off normal damage. Weak to piercing and fire.


func _init() -> void:
	enemy_type = "troll"
	height = 3.3


func _animate(delta: float) -> void:
	var s := sin(anim_t * 1.8)
	if rig.has("leg_l"):
		(rig["leg_l"] as Node3D).rotation.x = s * 0.45
		(rig["leg_r"] as Node3D).rotation.x = -s * 0.45
	(rig["arm_l"] as Node3D).rotation.x = -s * 0.25
	(rig["arm_r"] as Node3D).rotation.x = s * 0.2 - attack_anim * 2.2
	(rig["body"] as Node3D).position.y = abs(s) * 0.12
	(rig["torso"] as Node3D).rotation.z = s * 0.08
	if attack_anim > 0.7:
		EventBus.camera_shake.emit(0.05)
