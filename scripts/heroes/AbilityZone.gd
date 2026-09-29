class_name AbilityZone
extends Node3D
## A lingering ability area (Rain of Arrows, Consecrate): glowing ring,
## particles, and a callback every tick while it lasts.

var radius := 4.0
var duration := 4.0
var interval := 0.25
var color := Color(1, 0.9, 0.5)
var on_tick: Callable
var _age := 0.0
var _t := 0.0
var _ring: MeshInstance3D


static func create(pos: Vector3, r: float, dur: float, tick: float, col: Color, cb: Callable, particles: Dictionary = {}) -> AbilityZone:
	var z := AbilityZone.new()
	z.radius = r
	z.duration = dur
	z.interval = tick
	z.color = col
	z.on_tick = cb
	var parent: Node = GameManager.main.get_node("Effects") if GameManager.main else FX.root()
	parent.add_child(z)
	z.global_position = Vector3(pos.x, 0.06, pos.z)
	if not particles.is_empty():
		var p := FX.make_particles(particles)
		z.add_child(p)
		p.position = particles.get("emit_offset", Vector3(0, 0.3, 0))
		p.emitting = true
	return z


func _ready() -> void:
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.96
	t.outer_radius = 1.0
	t.rings = 48
	t.ring_segments = 4
	_ring.mesh = t
	_ring.material_override = Mats.emissive(color, 2.0)
	_ring.scale = Vector3(radius, 0.05, radius)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var fill := MeshInstance3D.new()
	var q := CylinderMesh.new()
	q.top_radius = radius
	q.bottom_radius = radius
	q.height = 0.02
	fill.mesh = q
	fill.material_override = Mats.flat(Color(color.r, color.g, color.b, 0.16), 1.0)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fill)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 1.4
	l.omni_range = radius * 1.6
	l.position.y = 1.5
	add_child(l)


func _process(delta: float) -> void:
	_age += delta
	_t -= delta
	_ring.rotation.y += delta * 0.8
	if _t <= 0.0:
		_t = interval
		if on_tick.is_valid():
			on_tick.call(global_position, radius)
	if _age >= duration:
		queue_free()
