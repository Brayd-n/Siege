class_name Keys
extends RefCounted
## Rebindable key actions. Defaults live here; the player's overrides are
## stored in the profile settings ("binds": {action: keycode}).

const ACTIONS := [
	["cam_up", "Camera forward", KEY_W],
	["cam_down", "Camera back", KEY_S],
	["cam_left", "Camera left", KEY_A],
	["cam_right", "Camera right", KEY_D],
	["rot_left", "Rotate left", KEY_Q],
	["rot_right", "Rotate right", KEY_E],
	["start_wave", "Start wave", KEY_SPACE],
	["talk", "Talk to soldier", KEY_T],
	["special", "Soldier special", KEY_G],
	["targeting", "Cycle targeting", KEY_TAB],
	["hero", "Place / select hero", KEY_H],
	["ability1", "Hero ability 1", KEY_Z],
	["ability2", "Hero ability 2", KEY_X],
	["pause", "Pause", KEY_P],
	["speed", "Toggle speed", KEY_F],
]


static func default_code(action: String) -> int:
	for a in ACTIONS:
		if a[0] == action:
			return int(a[2])
	return 0


static func code(action: String) -> int:
	if Profile.data.is_empty():
		return default_code(action)
	var binds: Dictionary = Profile.setting("binds") if Profile.setting("binds") is Dictionary else {}
	return int(binds.get(action, default_code(action)))


static func pressed(action: String) -> bool:
	return Input.is_key_pressed(code(action))


static func bind(action: String, keycode: int) -> void:
	var binds: Dictionary = (Profile.setting("binds") as Dictionary).duplicate() if Profile.setting("binds") is Dictionary else {}
	# a key can only do one thing: clear it from other actions
	for a in ACTIONS:
		if a[0] != action and code(a[0]) == keycode:
			binds[a[0]] = 0
	binds[action] = keycode
	Profile.set_setting("binds", binds)


static func reset() -> void:
	Profile.set_setting("binds", {})


static func key_name(action: String) -> String:
	var c := code(action)
	return OS.get_keycode_string(c) if c != 0 else "(none)"
