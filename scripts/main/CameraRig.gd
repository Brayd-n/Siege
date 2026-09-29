class_name CameraRig
extends Node3D
## Top-down / isometric strategy camera.
## WASD / arrows pan, mouse wheel zooms, middle or right mouse drag rotates,
## Q / E rotate, edge scrolling optional. Includes a small screen shake.

@export var pan_speed: float = 30.0
@export var min_distance: float = 16.0
@export var max_distance: float = 85.0
@export var bounds := Rect2(-60.0, -40.0, 128.0, 80.0)

var distance: float = 58.0
var target_distance: float = 58.0
var pitch_deg: float = 56.0
var yaw: float = 0.0
var target_yaw: float = 0.0
var _rotating: bool = false
var _rotate_button: int = 0
var _drag_moved: float = 0.0
var _shake: float = 0.0
var _last_usec: int = 0

@onready var pitch_node: Node3D = $Pitch
@onready var camera: Camera3D = $Pitch/Camera3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.camera_shake.connect(func(s: float): _shake = max(_shake, s))
	position = Vector3(-4.0, 0.0, 2.0)
	_apply()


func _process(delta: float) -> void:
	# use real time so camera speed ignores the 2x game speed and pause
	var now := Time.get_ticks_usec()
	var real_dt: float = clamp((now - _last_usec) / 1000000.0, 0.0, 0.1) if _last_usec > 0 else delta
	_last_usec = now
	var input := Vector2.ZERO
	if Keys.pressed("cam_up") or Input.is_key_pressed(KEY_UP):
		input.y -= 1
	if Keys.pressed("cam_down") or Input.is_key_pressed(KEY_DOWN):
		input.y += 1
	if Keys.pressed("cam_left") or Input.is_key_pressed(KEY_LEFT):
		input.x -= 1
	if Keys.pressed("cam_right") or Input.is_key_pressed(KEY_RIGHT):
		input.x += 1
	if Keys.pressed("rot_left"):
		target_yaw += 1.6 * real_dt
	if Keys.pressed("rot_right"):
		target_yaw -= 1.6 * real_dt
	if input != Vector2.ZERO:
		var move := Vector3(input.x, 0, input.y).normalized().rotated(Vector3.UP, yaw)
		position += move * pan_speed * real_dt * (distance / 50.0) * float(Profile.setting("camera_speed"))
	position.x = clamp(position.x, bounds.position.x, bounds.end.x)
	position.z = clamp(position.z, bounds.position.y, bounds.end.y)
	distance = lerp(distance, target_distance, clamp(real_dt * 8.0, 0.0, 1.0))
	yaw = lerp_angle(yaw, target_yaw, clamp(real_dt * 10.0, 0.0, 1.0))
	_shake = max(0.0, _shake - real_dt * 1.5)
	_apply()


func _apply() -> void:
	rotation.y = yaw
	# pitch gets slightly steeper when zoomed out, flatter when zoomed in
	var z := inverse_lerp(min_distance, max_distance, distance)
	var p: float = lerp(46.0, pitch_deg + 6.0, z)
	pitch_node.rotation_degrees.x = -p
	camera.position = Vector3(0, 0, distance)
	if _shake > 0.0:
		camera.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.6
	camera.far = 600.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_distance = max(min_distance, target_distance * 0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_distance = min(max_distance, target_distance * 1.1)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE or mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rotating = true
				_rotate_button = mb.button_index
				_drag_moved = 0.0
			elif mb.button_index == _rotate_button:
				_rotating = false
	elif event is InputEventMouseMotion and _rotating:
		var mm := event as InputEventMouseMotion
		_drag_moved += mm.relative.length()
		target_yaw -= mm.relative.x * 0.006
		pitch_deg = clamp(pitch_deg + mm.relative.y * 0.15, 40.0, 75.0)


## True if the last right-button press turned into a drag (so it shouldn't cancel).
func was_dragging() -> bool:
	return _drag_moved > 6.0


func focus_on(p: Vector3) -> void:
	position = Vector3(p.x, 0, p.z)
