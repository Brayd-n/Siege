extends CanvasLayer
## Slide-in notifications (achievements, quest completion, level ups, crowns).
## Lives above every scene so rewards show up in menus and in battle.

var box: VBoxContainer
var queue: Array = []
var showing := 0


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_top = 70
	add_child(box)
	Profile.toast.connect(show_toast)


func show_toast(title: String, body: String, color: Color) -> void:
	if showing >= 3:
		queue.append([title, body, color])
		return
	showing += 1
	var p := PanelContainer.new()
	var st := UiTheme.panel_style(Color(0.07, 0.06, 0.05, 0.95), color, 6, 2)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(330, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	p.add_child(vb)
	vb.add_child(UiTheme.label(title, 18, color, UiTheme.font_title()))
	var b := UiTheme.label(body, 15, UiTheme.PARCHMENT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = 310
	vb.add_child(b)
	box.add_child(p)
	p.modulate.a = 0.0
	Sfx.play("upgrade", -8.0, 0.0, 0.3)
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_done.bind(p))


func _done(p: Control) -> void:
	p.queue_free()
	showing -= 1
	if not queue.is_empty():
		var q: Array = queue.pop_front()
		show_toast(q[0], q[1], q[2])
