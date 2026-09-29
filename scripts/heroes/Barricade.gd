class_name Barricade
extends Node3D
## Spiked wooden barricade Brunhild raises on the road. Ground enemies that
## reach it stop and hack at it until it breaks.

var hp := 300.0
var max_hp := 300.0
var hp_bar: MeshInstance3D


static func create(pos: Vector3, health: float, yaw: float) -> Barricade:
	var b := Barricade.new()
	b.hp = health
	b.max_hp = health
	GameManager.main.get_node("Effects").add_child(b)
	b.global_position = Vector3(pos.x, 0, pos.z)
	b.rotation.y = yaw
	GameManager.map.barricades.append(b)
	return b


func _ready() -> void:
	var wood := Mats.get_mat("wood_obj")
	for i in 5:
		var x := -1.6 + i * 0.8
		ModelBuilder.add_mesh(self, ModelBuilder.cyl(0.13, 0.15, 1.6, 7), wood, Vector3(x, 0.65, 0), Vector3(0, 0, (i - 2) * 4.0))
		ModelBuilder.add_mesh(self, ModelBuilder.cone(0.13, 0.35, 7), wood, Vector3(x, 1.6, 0))
	for y in [0.4, 1.0]:
		ModelBuilder.add_mesh(self, ModelBuilder.box(Vector3(3.6, 0.14, 0.12)), Mats.get_mat("wood_dark"), Vector3(0, y, 0.14))
	for i in 4:
		ModelBuilder.add_mesh(self, ModelBuilder.cone(0.05, 0.9, 5), Mats.get_mat("metal_dark"), Vector3(-1.2 + i * 0.8, 0.8, 0.4), Vector3(70, 0, 0))
	hp_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.0, 0.14)
	hp_bar.mesh = q
	var m := ShaderMaterial.new()
	m.shader = Mats.shader("res://assets/shaders/healthbar.gdshader")
	hp_bar.material_override = m
	hp_bar.position = Vector3(0, 2.3, 0)
	hp_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hp_bar)
	hp_bar.set_instance_shader_parameter("fill", 1.0)
	hp_bar.set_instance_shader_parameter("bar_color", Color(0.9, 0.75, 0.35))
	FX.death_puff(global_position, 1.2)
	Sfx.play("place", 0.0)
	EventBus.wave_completed.connect(func(_n): destroy())
	scale = Vector3(1, 0.1, 1)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)


func take_damage(amount: float) -> void:
	hp -= amount
	hp_bar.set_instance_shader_parameter("fill", clamp(hp / max_hp, 0.0, 1.0))
	FX.hit_sparks(global_position + Vector3.UP, Color(0.8, 0.6, 0.35))
	if hp <= 0.0:
		destroy()


func destroy() -> void:
	if GameManager.map:
		GameManager.map.barricades.erase(self)
	FX.death_puff(global_position, 1.5)
	Sfx.play("hit", -4.0)
	queue_free()


func is_alive() -> bool:
	return hp > 0.0 and is_inside_tree()
