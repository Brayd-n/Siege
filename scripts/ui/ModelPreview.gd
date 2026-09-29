class_name ModelPreview
extends TextureRect
## A slowly turning 3D model inside a UI panel (Heroes screen, Codex).

var vp: SubViewport
var holder: Node3D
var cam: Camera3D


func _init(size_px: Vector2i = Vector2i(260, 300)) -> void:
	custom_minimum_size = Vector2(size_px)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.size = size_px
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.45)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	cam = Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.4
	key.light_color = Color(1.0, 0.9, 0.78)
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 1.0
	rim.light_color = Color(0.6, 0.7, 1.0)
	vp.add_child(rim)
	holder = Node3D.new()
	vp.add_child(holder)
	texture = vp.get_texture()


## Show a model rig (from ModelBuilder). `extent` is roughly how tall it is.
func show_rig(rig: Dictionary, extent: float = 2.2) -> void:
	for c in holder.get_children():
		c.queue_free()
	holder.add_child(rig["root"])
	var d := extent * 2.3 + 1.2
	cam.position = Vector3(0, extent * 0.55, d)
	cam.look_at(Vector3(0, extent * 0.45, 0), Vector3.UP)


func _process(delta: float) -> void:
	holder.rotation.y += delta * 0.6
