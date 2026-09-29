class_name Bat
extends Enemy
## Fast flying swarm. Weaves around while it flies.

var weave := 0.0


func _init() -> void:
	enemy_type = "bat"
	height = 0.4
	flying = true
	fly_height = 3.2


func _ready() -> void:
	super._ready()
	weave = randf() * TAU
	lateral = randf_range(-1.5, 1.5)


func _animate(_delta: float) -> void:
	var flap := sin(anim_t * 5.5)
	var wings: Array = rig["wings"]
	(wings[0] as Node3D).rotation.z = flap * 0.9
	(wings[1] as Node3D).rotation.z = -flap * 0.9
	fly_height = 3.0 + sin(anim_t * 0.9 + weave) * 0.6
	lateral = sin(anim_t * 0.45 + weave) * 1.6


func aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.1
