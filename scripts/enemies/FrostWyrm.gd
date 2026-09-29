class_name FrostWyrm
extends Dragon
## Ice dragon: its breath freezes soldiers solid instead of burning them.

const FREEZE_TIME := 3.0


func _init() -> void:
	super._init()
	enemy_type = "frost_wyrm"
	breath_colors = [Color(0.9, 0.97, 1.0, 1), Color(0.45, 0.75, 1.0, 0.9), Color(0.1, 0.2, 0.4, 0.0)]


func _breath_hit(u: FriendlyUnit) -> void:
	u.take_damage(BREATH_DAMAGE * 0.45, self)
	u.stun(FREEZE_TIME, "frozen")
