class_name HudIcon
extends Control
## Small vector icons drawn in code (heart, coin, flag, skull, star).

@export var kind: String = "coin"
@export var tint: Color = Color.WHITE


func _init(k: String = "coin", c: Color = Color.WHITE, s: float = 26.0) -> void:
	kind = k
	tint = c
	custom_minimum_size = Vector2(s, s)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := size
	var c := s * 0.5
	var r: float = min(s.x, s.y) * 0.45
	match kind:
		"heart":
			var col := Color(0.85, 0.15, 0.15)
			draw_circle(c + Vector2(-r * 0.45, -r * 0.2), r * 0.52, col)
			draw_circle(c + Vector2(r * 0.45, -r * 0.2), r * 0.52, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.95, -r * 0.05), c + Vector2(r * 0.95, -r * 0.05), c + Vector2(0, r * 0.95)]), col)
			draw_circle(c + Vector2(-r * 0.5, -r * 0.35), r * 0.15, Color(1, 0.6, 0.6, 0.8))
		"coin":
			draw_circle(c, r, Color(0.75, 0.52, 0.1))
			draw_circle(c, r * 0.82, Color(1.0, 0.8, 0.28))
			draw_circle(c, r * 0.55, Color(0.9, 0.65, 0.18))
			draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.15, Color(1, 1, 0.8, 0.8))
		"flag":
			draw_line(c + Vector2(-r * 0.6, -r), c + Vector2(-r * 0.6, r), Color(0.8, 0.7, 0.5), 2.5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.55, -r), c + Vector2(r, -r * 0.6), c + Vector2(-r * 0.55, -r * 0.1)]), Color(0.9, 0.25, 0.2))
		"skull":
			var bone := Color(0.9, 0.87, 0.78)
			draw_circle(c + Vector2(0, -r * 0.15), r * 0.75, bone)
			draw_rect(Rect2(c + Vector2(-r * 0.45, r * 0.25), Vector2(r * 0.9, r * 0.55)), bone)
			draw_circle(c + Vector2(-r * 0.3, -r * 0.15), r * 0.2, Color(0.1, 0.08, 0.06))
			draw_circle(c + Vector2(r * 0.3, -r * 0.15), r * 0.2, Color(0.1, 0.08, 0.06))
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + i * PI / 5
				var rr := r if i % 2 == 0 else r * 0.45
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, tint)
		"moon":
			draw_circle(c, r * 0.9, Color(0.75, 0.2, 0.9))
			draw_circle(c + Vector2(r * 0.35, -r * 0.2), r * 0.75, Color(0.08, 0.06, 0.05))
