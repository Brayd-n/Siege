class_name UiTheme
extends RefCounted
## Shared fonts, colours and a medieval UI Theme built in code.

const GOLD := Color(0.93, 0.76, 0.38)
const GOLD_DIM := Color(0.62, 0.5, 0.28)
const PARCHMENT := Color(0.93, 0.88, 0.76)
const INK := Color(0.12, 0.09, 0.06)
const PANEL_BG := Color(0.075, 0.062, 0.05, 0.9)
const RED := Color(0.9, 0.3, 0.25)
const GREEN := Color(0.45, 0.85, 0.4)
const CLASS_COLORS := {
	"archer": Color(0.5, 0.85, 0.45),
	"knight": Color(0.6, 0.72, 1.0),
	"crossbowman": Color(0.9, 0.7, 0.42),
	"torch_thrower": Color(1.0, 0.55, 0.3),
	"spearman": Color(0.78, 0.82, 0.45),
	"battle_mage": Color(0.72, 0.58, 1.0),
	"cleric": Color(1.0, 0.92, 0.62),
	"trebuchet": Color(0.85, 0.68, 0.5),
}

static var _fonts: Dictionary = {}
static var _theme: Theme = null


static func _font(file: String) -> Font:
	if _fonts.has(file):
		return _fonts[file]
	var f: Font = null
	var p := "res://assets/fonts/" + file
	if ResourceLoader.exists(p):
		f = load(p)
	else:
		f = ThemeDB.fallback_font
	_fonts[file] = f
	return f


static func font_title() -> Font:
	return _font("Cinzel-Bold.ttf")


static func font_body() -> Font:
	return _font("Alegreya-Medium.ttf")


static func font_bold() -> Font:
	return _font("Alegreya-Bold.ttf")


static func font_italic() -> Font:
	return _font("Alegreya-Italic.ttf")


static func panel_style(bg: Color = PANEL_BG, border: Color = GOLD_DIM, radius: int = 6, border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.set_content_margin_all(10)
	return s


static func button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(4)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 5
	s.content_margin_bottom = 5
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font_body()
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("normal", "Button", button_style(Color(0.2, 0.15, 0.1, 0.95), GOLD_DIM))
	t.set_stylebox("hover", "Button", button_style(Color(0.32, 0.24, 0.14, 0.98), GOLD))
	t.set_stylebox("pressed", "Button", button_style(Color(0.12, 0.09, 0.06, 1.0), GOLD))
	t.set_stylebox("disabled", "Button", button_style(Color(0.14, 0.13, 0.12, 0.8), Color(0.3, 0.28, 0.25)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PARCHMENT)
	t.set_color("font_hover_color", "Button", Color(1, 0.95, 0.8))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.42))
	t.set_color("font_color", "Label", PARCHMENT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "Label", 0)
	t.set_font_size("font_size", "Button", 17)
	var tip := panel_style(Color(0.06, 0.05, 0.04, 0.96), GOLD_DIM, 4, 1)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", PARCHMENT)
	t.set_font_size("font_size", "TooltipLabel", 16)
	# progress bar
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.1, 0.05, 0.04)
	pb_bg.set_corner_radius_all(3)
	var pb_fg := StyleBoxFlat.new()
	pb_fg.bg_color = Color(0.4, 0.75, 0.3)
	pb_fg.set_corner_radius_all(3)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fg)
	_theme = t
	return t


static func label(text: String, size: int = 18, color: Color = PARCHMENT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
