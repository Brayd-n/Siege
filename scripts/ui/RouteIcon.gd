class_name RouteIcon
extends Control
## Mini-map of a level's road drawn on parchment for the level-select cards.

var path: Array = []
var paths: Array = []      ## all roads (multi-road maps)
var river: Array = []
var bridges: Array = []
var tint: Color = Color(0.55, 0.62, 0.3)
var locked := false


static func from_level(lv: Dictionary, is_locked: bool = false) -> RouteIcon:
	var all: Array = lv.get("paths", [lv.get("path", [])])
	var r := RouteIcon.new(all[0], LevelDefs.theme(lv).get("icon", Color(0.4, 0.55, 0.3)), is_locked)
	r.paths = all
	r.river = lv.get("river", [])
	r.bridges = lv.get("bridges", [])
	return r


func _init(p: Array = [], t: Color = Color.WHITE, is_locked: bool = false) -> void:
	path = p
	tint = t
	locked = is_locked
	custom_minimum_size = Vector2(236, 118)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _to_px(v: Vector2) -> Vector2:
	# world x -60..60, z -30..30  ->  icon rect with margin
	var m := 8.0
	var w := size.x - m * 2
	var h := size.y - m * 2
	return Vector2(m + (v.x + 60.0) / 120.0 * w, m + (v.y + 30.0) / 60.0 * h)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, tint.darkened(0.55) if not locked else Color(0.15, 0.14, 0.13))
	draw_rect(r.grow(-3), tint.darkened(0.25) if not locked else Color(0.2, 0.19, 0.18))
	if path.size() < 2:
		return
	if river.size() >= 2:
		var rp := PackedVector2Array()
		for p in river:
			var q: Vector2 = _to_px(p)
			rp.append(Vector2(clamp(q.x, 4.0, size.x - 4.0), clamp(q.y, 4.0, size.y - 4.0)))
		draw_polyline(rp, Color(0.25, 0.45, 0.7) if not locked else Color(0.25, 0.25, 0.27), 7.0, true)
		for b in bridges:
			draw_rect(Rect2(_to_px(b) - Vector2(4, 4), Vector2(8, 8)), Color(0.6, 0.45, 0.25))
	var road := Color(0.55, 0.42, 0.28) if not locked else Color(0.35, 0.33, 0.3)
	var all: Array = paths if not paths.is_empty() else [path]
	var pts := PackedVector2Array()
	for pth in all:
		var pp := PackedVector2Array()
		for p in pth:
			pp.append(_to_px(p))
		draw_polyline(pp, Color(0, 0, 0, 0.35), 7.0, true)
		draw_polyline(pp, road, 5.0, true)
		draw_circle(pp[0], 6.0, Color(0.55, 0.25, 0.85) if not locked else Color(0.3, 0.3, 0.3))
		pts = pp
	# portal and castle
	var c := pts[pts.size() - 1]
	draw_rect(Rect2(c + Vector2(-2, -9), Vector2(14, 18)), Color(0.62, 0.6, 0.58) if not locked else Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(c + Vector2(-2, -12), Vector2(4, 4)), Color(0.62, 0.6, 0.58) if not locked else Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(c + Vector2(8, -12), Vector2(4, 4)), Color(0.62, 0.6, 0.58) if not locked else Color(0.3, 0.3, 0.3))
