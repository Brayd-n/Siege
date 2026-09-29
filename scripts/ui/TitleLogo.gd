class_name TitleLogo
extends Control
## The Siegewatch logo, drawn in code: a heraldic shield with a watchtower,
## crossed swords behind it, and the title in engraved gold letters.

var t := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(380, 120)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var c := Vector2(58, 60)
	var gold := Color(1.0, 0.78, 0.32)
	var gold_dark := Color(0.55, 0.36, 0.1)
	# crossed swords
	for s in [-1.0, 1.0]:
		var dir := Vector2(s * 0.62, -0.78).normalized()
		var a := c - dir * 52.0
		var b := c + dir * 58.0
		draw_line(a, b, Color(0.15, 0.12, 0.1), 9.0, true)
		draw_line(a, b, Color(0.82, 0.84, 0.88), 5.0, true)
		draw_line(a + dir * 4.0, b - dir * 6.0, Color(1, 1, 1, 0.6), 1.5, true)
		var guard := a + dir * 14.0
		var perp := Vector2(-dir.y, dir.x)
		draw_line(guard - perp * 11.0, guard + perp * 11.0, gold_dark, 6.0, true)
		draw_line(guard - perp * 10.0, guard + perp * 10.0, gold, 3.5, true)
		draw_circle(a, 5.0, gold)
	# shield
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var w := 40.0
	var top := c.y - 44.0
	var shape := [Vector2(-w, 0), Vector2(w, 0), Vector2(w, 34), Vector2(w * 0.8, 56), Vector2(0, 84), Vector2(-w * 0.8, 56), Vector2(-w, 34)]
	for p in shape:
		pts.append(Vector2(c.x + p.x, top + p.y))
		cols.append(Color(0.45, 0.07, 0.06).lerp(Color(0.2, 0.03, 0.03), p.y / 84.0))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_colored_polygon(pts, Color.WHITE)
	draw_polygon(pts, cols)
	draw_polyline(outline, gold_dark, 7.0, true)
	draw_polyline(outline, gold, 3.5, true)
	# watchtower
	var tw := Color(0.92, 0.86, 0.72)
	var base_y := top + 64.0
	draw_rect(Rect2(c.x - 11, base_y - 34, 22, 34), tw)
	for i in 3:
		draw_rect(Rect2(c.x - 14 + i * 10, base_y - 42, 7, 9), tw)
	draw_rect(Rect2(c.x - 4, base_y - 12, 8, 12), Color(0.25, 0.05, 0.04))
	var glow := 0.6 + 0.4 * sin(t * 2.5)
	draw_rect(Rect2(c.x - 3, base_y - 28, 6, 7), Color(1.0, 0.75, 0.3).lerp(Color(1, 0.95, 0.7), glow))
	# title text
	var f := UiTheme.font_title()
	var pos := Vector2(116, 70)
	var title := "SIEGEWATCH"
	draw_string_outline(f, pos + Vector2(2, 3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 10, Color(0, 0, 0, 0.6))
	draw_string_outline(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 6, gold_dark)
	draw_string(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, gold)
	# shine sweep
	var sweep := fmod(t * 0.35, 1.6) - 0.3
	var sx := pos.x + sweep * 240.0
	if sx < pos.x + 240.0:
		draw_rect(Rect2(sx, pos.y - 32, 14, 38), Color(1, 1, 0.85, 0.07))
	draw_string(UiTheme.font_italic(), Vector2(118, 98), "The Kingdom's Last Watch", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.88, 0.8, 0.66))
