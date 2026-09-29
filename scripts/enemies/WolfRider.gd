class_name WolfRider
extends Enemy
## Very fast goblin cavalry on a wolf.


func _init() -> void:
	enemy_type = "wolf_rider"
	height = 1.7


func _animate(_delta: float) -> void:
	var s := anim_t * 3.2
	var legs: Array = rig.get("legs", [])
	for i in legs.size():
		var phase := 0.0 if i in [0, 3] else PI
		(legs[i] as Node3D).rotation.x = sin(s + phase) * 0.7
	(rig["body"] as Node3D).position.y = abs(sin(s)) * 0.12
	(rig["body"] as Node3D).rotation.x = sin(s) * 0.05
	(rig["head"] as Node3D).rotation.x = sin(s + 0.5) * 0.12
	(rig["tail"] as Node3D).rotation.y = sin(s * 0.7) * 0.4
	(rig["arm_r"] as Node3D).rotation.x = -0.5 - attack_anim * 1.5
