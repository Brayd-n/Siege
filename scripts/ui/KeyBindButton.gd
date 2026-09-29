class_name KeyBindButton
extends Button
## Settings button that waits for a key press and rebinds an action.

var action := ""
var waiting := false


func setup(act: String) -> void:
	action = act
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(120, 0)
	pressed.connect(_start)
	_refresh()


func _refresh() -> void:
	text = "Press a key..." if waiting else Keys.key_name(action)


func _start() -> void:
	waiting = true
	_refresh()


func _input(event: InputEvent) -> void:
	if not waiting or not (event is InputEventKey) or not event.pressed:
		return
	var k := (event as InputEventKey).keycode
	get_viewport().set_input_as_handled()
	waiting = false
	if k != KEY_ESCAPE:
		Keys.bind(action, k)
	for b in get_tree().get_nodes_in_group("keybind_buttons"):
		(b as KeyBindButton)._refresh()
	_refresh()


func _ready() -> void:
	add_to_group("keybind_buttons")
