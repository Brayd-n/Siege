class_name Skeleton
extends Enemy
## Raised dead. Rises out of the ground when spawned.


func _init() -> void:
	enemy_type = "skeleton"
	height = 1.2


func _ready() -> void:
	super._ready()
	model_root.position.y = -1.0
	create_tween().tween_property(model_root, "position:y", 0.0, 0.6)
