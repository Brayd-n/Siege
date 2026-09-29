class_name ModelBuilder
extends RefCounted
## Builds the placeholder-but-detailed character models out of primitive meshes
## with PBR materials. Every builder returns a Dictionary "rig" holding the
## animatable pivots (arms, legs, head, weapon ...) plus "root".
##
## Convention: characters face +Z, origin at the feet, +X is the character's left.

static var _mesh_cache: Dictionary = {}


# ================================================================ primitives
static func capsule(r: float, h: float) -> CapsuleMesh:
	var key := "cap%.3f_%.3f" % [r, h]
	if not _mesh_cache.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = max(h, r * 2.0 + 0.001)
		m.radial_segments = 14
		m.rings = 6
		_mesh_cache[key] = m
	return _mesh_cache[key]


static func sphere(r: float, segs: int = 16) -> SphereMesh:
	var key := "sph%.3f_%d" % [r, segs]
	if not _mesh_cache.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segs
		m.rings = max(6, segs / 2)
		_mesh_cache[key] = m
	return _mesh_cache[key]


static func box(size: Vector3) -> BoxMesh:
	var key := "box%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if not _mesh_cache.has(key):
		var m := BoxMesh.new()
		m.size = size
		_mesh_cache[key] = m
	return _mesh_cache[key]


static func cyl(top: float, bottom: float, h: float, segs: int = 14) -> CylinderMesh:
	var key := "cyl%.3f_%.3f_%.3f_%d" % [top, bottom, h, segs]
	if not _mesh_cache.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_mesh_cache[key] = m
	return _mesh_cache[key]


static func cone(r: float, h: float, segs: int = 10) -> CylinderMesh:
	return cyl(0.0, r, h, segs)


static func torus(inner: float, outer: float) -> TorusMesh:
	var key := "tor%.3f_%.3f" % [inner, outer]
	if not _mesh_cache.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 20
		m.ring_segments = 8
		_mesh_cache[key] = m
	return _mesh_cache[key]


## Tube following an arc in the YZ plane. Midpoint at origin, tips bend towards -Z.
## Used for bows and crossbow prods.
static func arc_tube(radius: float, angle_deg: float, thick: float, segs: int = 12) -> ArrayMesh:
	var key := "arc%.3f_%.1f_%.3f" % [radius, angle_deg, thick]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := deg_to_rad(angle_deg)
	var ring := 6
	var rings: Array = []
	for i in segs + 1:
		var t := -a * 0.5 + a * float(i) / segs
		var c := Vector3(0.0, radius * sin(t), radius * cos(t) - radius)
		var tangent := Vector3(0.0, cos(t), -sin(t)).normalized()
		var n1 := Vector3.RIGHT
		var n2 := tangent.cross(n1).normalized()
		var taper: float = lerp(1.0, 0.55, abs(float(i) / segs - 0.5) * 2.0)
		var pts: Array = []
		for j in ring:
			var ang := TAU * j / ring
			var dir := (n1 * cos(ang) + n2 * sin(ang))
			pts.append([c + dir * thick * taper, dir])
		rings.append(pts)
	for i in segs:
		for j in ring:
			var j2 := (j + 1) % ring
			var p00 = rings[i][j]
			var p01 = rings[i][j2]
			var p10 = rings[i + 1][j]
			var p11 = rings[i + 1][j2]
			for p in [p00, p10, p11, p00, p11, p01]:
				st.set_normal(p[1])
				st.set_uv(Vector2(float(j) / ring, float(i) / segs))
				st.add_vertex(p[0])
	var mesh := st.commit()
	_mesh_cache[key] = mesh
	return mesh


static func add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.layers = 2
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, name: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	return n


# ================================================================ humanoid base
## cfg keys: skin, torso, legs, arms, boots, belt (Materials); bulk, height (floats)
static func humanoid(cfg: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Rig"
	var bulk: float = cfg.get("bulk", 1.0)
	var skin: Material = cfg["skin"]
	var torso_m: Material = cfg["torso"]
	var legs_m: Material = cfg["legs"]
	var arms_m: Material = cfg.get("arms", torso_m)
	var boots_m: Material = cfg.get("boots", Mats.leather(Color(0.25, 0.17, 0.11)))
	var belt_m: Material = cfg.get("belt", Mats.leather(Color(0.3, 0.2, 0.12)))
	var body := pivot(root, "Body")
	body.scale = Vector3.ONE * cfg.get("height", 1.0)
	var hips := pivot(body, "Hips", Vector3(0, 0.92, 0))
	var rig := {"root": root, "body": body, "hips": hips}
	for side in [1, -1]:
		var nm := "LegL" if side > 0 else "LegR"
		var leg := pivot(hips, nm, Vector3(0.115 * side * bulk, -0.02, 0))
		add_mesh(leg, capsule(0.1 * bulk, 0.56), legs_m, Vector3(0, -0.26, 0))
		add_mesh(leg, capsule(0.085 * bulk, 0.52), legs_m, Vector3(0, -0.6, 0))
		add_mesh(leg, box(Vector3(0.15, 0.13, 0.29) * Vector3(bulk, 1, 1)), boots_m, Vector3(0, -0.855, 0.05))
		rig["leg_l" if side > 0 else "leg_r"] = leg
	var torso := pivot(hips, "Torso", Vector3(0, 0.04, 0))
	rig["torso"] = torso
	add_mesh(torso, capsule(0.23, 0.74), torso_m, Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(bulk * 1.02, 1, 0.72 * bulk))
	add_mesh(torso, cyl(0.24, 0.24, 0.08), belt_m, Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(bulk, 1, 0.76 * bulk))
	add_mesh(torso, box(Vector3(0.07, 0.07, 0.03)), Mats.get_mat("gold"), Vector3(0, 0.03, 0.18 * bulk))
	var head := pivot(torso, "Head", Vector3(0, 0.76, 0))
	rig["head"] = head
	add_mesh(head, cyl(0.06, 0.075, 0.14), skin, Vector3(0, -0.03, 0))
	add_mesh(head, sphere(0.15), skin, Vector3(0, 0.13, 0), Vector3.ZERO, Vector3(0.94, 1.08, 1.0))
	add_mesh(head, sphere(0.034, 8), skin, Vector3(0, 0.115, 0.145), Vector3.ZERO, Vector3(0.9, 1.0, 1.3))
	var eye_m: Material = cfg.get("eyes", Mats.get_mat("eye_dark"))
	for s in [1, -1]:
		add_mesh(head, sphere(0.022, 8), eye_m, Vector3(0.052 * s, 0.155, 0.128))
	for side in [1, -1]:
		var nm := "ArmL" if side > 0 else "ArmR"
		var arm := pivot(torso, nm, Vector3(0.3 * side * bulk, 0.6, 0))
		add_mesh(arm, sphere(0.09), arms_m, Vector3.ZERO)
		add_mesh(arm, capsule(0.075 * bulk, 0.36), arms_m, Vector3(0, -0.17, 0))
		add_mesh(arm, capsule(0.066 * bulk, 0.34), arms_m, Vector3(0, -0.43, 0))
		add_mesh(arm, sphere(0.066), skin, Vector3(0, -0.61, 0.01))
		var hand := pivot(arm, "Hand", Vector3(0, -0.62, 0.02))
		rig["arm_l" if side > 0 else "arm_r"] = arm
		rig["hand_l" if side > 0 else "hand_r"] = hand
	return rig


# ================================================================ weapons
static func make_bow(parent: Node3D, size: float = 1.0) -> Node3D:
	var bow := pivot(parent, "Bow")
	var r := 0.62 * size
	var ang := 112.0
	add_mesh(bow, arc_tube(r, ang, 0.022 * size), Mats.get_mat("wood_obj"))
	var half := deg_to_rad(ang * 0.5)
	var string_z := r * cos(half) - r
	var string_len := 2.0 * r * sin(half)
	var s := add_mesh(bow, cyl(0.004, 0.004, string_len, 4), Mats.flat(Color(0.85, 0.82, 0.7)), Vector3(0, 0, string_z))
	s.name = "String"
	add_mesh(bow, cyl(0.03, 0.03, 0.14), Mats.leather(Color(0.3, 0.18, 0.1)), Vector3.ZERO)
	return bow


static func make_sword(parent: Node3D, length: float = 0.85) -> Node3D:
	var sw := pivot(parent, "Sword")
	add_mesh(sw, cyl(0.022, 0.025, 0.2), Mats.leather(Color(0.22, 0.12, 0.08)), Vector3(0, 0.02, 0))
	add_mesh(sw, sphere(0.035, 8), Mats.get_mat("gold"), Vector3(0, -0.09, 0))
	add_mesh(sw, box(Vector3(0.28, 0.035, 0.05)), Mats.get_mat("gold"), Vector3(0, 0.13, 0))
	add_mesh(sw, box(Vector3(0.065, length, 0.014)), Mats.get_mat("metal"), Vector3(0, 0.15 + length * 0.5, 0))
	add_mesh(sw, cone(0.033, 0.1, 4), Mats.get_mat("metal"), Vector3(0, 0.15 + length + 0.05, 0), Vector3.ZERO, Vector3(1, 1, 0.22))
	return sw


static func make_crossbow(parent: Node3D) -> Node3D:
	var cb := pivot(parent, "Crossbow")
	add_mesh(cb, box(Vector3(0.07, 0.08, 0.72)), Mats.get_mat("wood_obj"), Vector3(0, 0, 0.2))
	add_mesh(cb, box(Vector3(0.05, 0.12, 0.18)), Mats.get_mat("wood_obj"), Vector3(0, -0.07, -0.12))
	var prod := pivot(cb, "Prod", Vector3(0, 0.02, 0.52))
	var arc := add_mesh(prod, arc_tube(0.42, 95.0, 0.02), Mats.get_mat("metal_dark"))
	arc.rotation_degrees = Vector3(0, 0, 90)
	var half := deg_to_rad(47.5)
	var sz := 0.42 * cos(half) - 0.42
	var sl := 2.0 * 0.42 * sin(half)
	add_mesh(prod, cyl(0.004, 0.004, sl, 4), Mats.flat(Color(0.8, 0.78, 0.7)), Vector3(0, 0, sz), Vector3(0, 0, 90))
	var bolt := add_mesh(cb, cyl(0.012, 0.012, 0.45, 6), Mats.get_mat("wood_obj"), Vector3(0, 0.05, 0.3), Vector3(90, 0, 0))
	bolt.name = "LoadedBolt"
	return cb


static func make_torch(parent: Node3D, lit: bool = true) -> Node3D:
	var t := pivot(parent, "Torch")
	add_mesh(t, cyl(0.03, 0.038, 0.62, 8), Mats.get_mat("wood_dark"), Vector3(0, 0.2, 0))
	add_mesh(t, cyl(0.055, 0.045, 0.14, 8), Mats.get_mat("rope"), Vector3(0, 0.5, 0))
	add_mesh(t, sphere(0.05, 8), Mats.get_mat("fire"), Vector3(0, 0.6, 0))
	if lit:
		var f := FX.fire_emitter(0.55)
		f.position = Vector3(0, 0.6, 0)
		f.name = "Flame"
		t.add_child(f)
		f.emitting = true
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 1.1
		l.omni_range = 3.5
		l.position = Vector3(0, 0.75, 0)
		l.name = "Light"
		t.add_child(l)
	return t


static func make_axe(parent: Node3D) -> Node3D:
	var ax := pivot(parent, "Axe")
	add_mesh(ax, cyl(0.03, 0.035, 1.0, 8), Mats.get_mat("wood_obj"), Vector3(0, 0.35, 0))
	add_mesh(ax, box(Vector3(0.04, 0.3, 0.32)), Mats.get_mat("metal_dark"), Vector3(0, 0.75, 0.14))
	add_mesh(ax, cone(0.04, 0.14, 6), Mats.get_mat("metal_dark"), Vector3(0, 0.92, 0))
	return ax


static func make_club(parent: Node3D, size: float = 1.0) -> Node3D:
	var c := pivot(parent, "Club")
	add_mesh(c, cyl(0.12 * size, 0.06 * size, 1.4 * size, 10), Mats.get_mat("bark"), Vector3(0, 0.55 * size, 0))
	for i in 3:
		add_mesh(c, cone(0.05 * size, 0.14 * size, 6), Mats.get_mat("bone"),
			Vector3(0.1 * size * cos(i * 2.1), 1.05 * size, 0.1 * size * sin(i * 2.1)), Vector3(0, 0, 70 + i * 40))
	return c


# ================================================================ friendly units
static func build_unit(type: String) -> Dictionary:
	match type:
		"archer":
			return _archer()
		"knight":
			return _knight()
		"crossbowman":
			return _crossbowman()
		"torch_thrower":
			return _torch_thrower()
		"spearman":
			return _spearman()
		"battle_mage":
			return _battle_mage()
		"cleric":
			return _cleric()
		"trebuchet":
			return _trebuchet()
	return _archer()


static func _human_skin() -> Material:
	return Mats.skin(Color(0.86, 0.66, 0.52))


static func _archer() -> Dictionary:
	var green := Color(0.2, 0.36, 0.16)
	var rig := humanoid({
		"skin": _human_skin(), "torso": Mats.cloth(green), "legs": Mats.cloth(Color(0.32, 0.25, 0.17)),
		"arms": Mats.leather(Color(0.42, 0.3, 0.2)), "bulk": 0.95,
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	# hood & cowl
	add_mesh(head, sphere(0.175), Mats.cloth(green.darkened(0.15)), Vector3(0, 0.16, -0.035), Vector3.ZERO, Vector3(1.0, 1.02, 1.0))
	add_mesh(head, cone(0.1, 0.3, 8), Mats.cloth(green.darkened(0.15)), Vector3(0, 0.12, -0.2), Vector3(-120, 0, 0))
	add_mesh(torso, capsule(0.26, 0.4), Mats.cloth(green.darkened(0.15)), Vector3(0, 0.66, -0.02), Vector3.ZERO, Vector3(1.05, 0.55, 0.85))
	# quiver
	var q := add_mesh(torso, cyl(0.075, 0.065, 0.55), Mats.leather(Color(0.36, 0.22, 0.12)), Vector3(0.1, 0.42, -0.2), Vector3(-10, 0, -18))
	for i in 4:
		add_mesh(q, box(Vector3(0.02, 0.1, 0.05)), Mats.flat(Color(0.9, 0.9, 0.85)), Vector3(0.03 * (i - 1.5), 0.33, 0.0))
	# belt pouch
	add_mesh(torso, box(Vector3(0.12, 0.1, 0.07)), Mats.leather(Color(0.35, 0.22, 0.12)), Vector3(-0.18, -0.03, 0.1))
	var bow := make_bow(rig["hand_l"], 1.0)
	bow.rotation_degrees = Vector3(0, 0, 0)
	rig["weapon"] = bow
	# ready pose: bow arm forward
	(rig["arm_l"] as Node3D).rotation_degrees = Vector3(-80, 0, -8)
	(rig["arm_r"] as Node3D).rotation_degrees = Vector3(-70, -25, 10)
	return rig


static func _knight() -> Dictionary:
	var blue := Color(0.14, 0.2, 0.46)
	var metal := Mats.get_mat("metal")
	var rig := humanoid({
		"skin": _human_skin(), "torso": metal, "legs": Mats.get_mat("metal_dark"), "arms": metal,
		"boots": metal, "bulk": 1.12,
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	# great helm
	add_mesh(head, cyl(0.165, 0.175, 0.3, 16), metal, Vector3(0, 0.15, 0))
	add_mesh(head, sphere(0.168), metal, Vector3(0, 0.29, 0), Vector3.ZERO, Vector3(1, 0.55, 1))
	add_mesh(head, box(Vector3(0.24, 0.025, 0.02)), Mats.get_mat("eye_dark"), Vector3(0, 0.18, 0.17))
	add_mesh(head, box(Vector3(0.02, 0.2, 0.02)), Mats.get_mat("gold"), Vector3(0, 0.12, 0.178))
	var plume := add_mesh(head, capsule(0.05, 0.36), Mats.cloth(Color(0.7, 0.08, 0.06)), Vector3(0, 0.38, -0.08), Vector3(-60, 0, 0))
	plume.name = "Plume"
	# tabard over armour
	add_mesh(torso, box(Vector3(0.36, 0.62, 0.03)), Mats.cloth(blue), Vector3(0, 0.12, 0.18))
	add_mesh(torso, box(Vector3(0.36, 0.62, 0.03)), Mats.cloth(blue), Vector3(0, 0.12, -0.18))
	add_mesh(torso, box(Vector3(0.1, 0.1, 0.035)), Mats.get_mat("gold"), Vector3(0, 0.36, 0.195), Vector3(0, 0, 45))
	# pauldrons
	for s in [1, -1]:
		add_mesh(torso, sphere(0.14), metal, Vector3(0.3 * s * 1.12, 0.63, 0), Vector3.ZERO, Vector3(1.25, 0.8, 1.15))
	# cape
	var cape := add_mesh(torso, box(Vector3(0.5, 1.05, 0.03)), Mats.cloth(Color(0.5, 0.06, 0.05)), Vector3(0, 0.12, -0.24), Vector3(8, 0, 0))
	cape.name = "Cape"
	# shield
	var shield := pivot(rig["arm_l"], "Shield", Vector3(0.1, -0.4, 0.04))
	add_mesh(shield, cyl(0.34, 0.34, 0.05, 20), Mats.cloth(blue), Vector3.ZERO, Vector3(0, 0, 90))
	add_mesh(shield, torus(0.32, 0.36), metal, Vector3.ZERO, Vector3(0, 0, 90))
	add_mesh(shield, sphere(0.07), Mats.get_mat("gold"), Vector3(0.03, 0, 0))
	add_mesh(shield, box(Vector3(0.01, 0.5, 0.08)), Mats.get_mat("gold"), Vector3(0.028, 0, 0))
	add_mesh(shield, box(Vector3(0.01, 0.08, 0.5)), Mats.get_mat("gold"), Vector3(0.028, 0.05, 0))
	shield.rotation_degrees = Vector3(0, -20, 0)
	var sw := make_sword(rig["hand_r"], 0.85)
	sw.rotation_degrees = Vector3(60, 0, 0)
	rig["weapon"] = sw
	(rig["arm_r"] as Node3D).rotation_degrees = Vector3(-30, 0, 0)
	(rig["arm_l"] as Node3D).rotation_degrees = Vector3(-35, 20, -10)
	return rig


static func _crossbowman() -> Dictionary:
	var ochre := Color(0.5, 0.34, 0.14)
	var rig := humanoid({
		"skin": _human_skin(), "torso": Mats.leather(Color(0.4, 0.28, 0.17)), "legs": Mats.cloth(Color(0.24, 0.2, 0.16)),
		"arms": Mats.cloth(ochre), "bulk": 1.05,
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	# kettle hat
	add_mesh(head, cyl(0.28, 0.28, 0.025, 20), Mats.get_mat("metal"), Vector3(0, 0.2, 0))
	add_mesh(head, sphere(0.165), Mats.get_mat("metal"), Vector3(0, 0.21, 0), Vector3.ZERO, Vector3(1, 0.85, 1))
	# beard
	add_mesh(head, sphere(0.1), Mats.cloth(Color(0.3, 0.18, 0.1)), Vector3(0, 0.03, 0.09), Vector3.ZERO, Vector3(1.1, 0.9, 0.8))
	# tabard with stripe
	add_mesh(torso, box(Vector3(0.38, 0.6, 0.03)), Mats.cloth(ochre), Vector3(0, 0.12, 0.17))
	add_mesh(torso, box(Vector3(0.08, 0.6, 0.032)), Mats.cloth(Color(0.55, 0.1, 0.08)), Vector3(0, 0.12, 0.172))
	# bolt case on hip
	add_mesh(torso, box(Vector3(0.1, 0.25, 0.1)), Mats.leather(Color(0.3, 0.2, 0.12)), Vector3(0.24, -0.08, -0.05))
	var cb := make_crossbow(rig["hand_r"])
	cb.rotation_degrees = Vector3(80, 0, 0)
	cb.position = Vector3(0.12, 0.0, 0.0)
	rig["weapon"] = cb
	(rig["arm_r"] as Node3D).rotation_degrees = Vector3(-80, 15, 0)
	(rig["arm_l"] as Node3D).rotation_degrees = Vector3(-75, -25, 0)
	return rig


static func _torch_thrower() -> Dictionary:
	var red := Color(0.6, 0.18, 0.06)
	var rig := humanoid({
		"skin": _human_skin(), "torso": Mats.cloth(red), "legs": Mats.cloth(Color(0.22, 0.16, 0.12)),
		"arms": Mats.cloth(red.darkened(0.1)), "bulk": 1.08,
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	# leather cap + bandana
	add_mesh(head, sphere(0.16), Mats.leather(Color(0.32, 0.2, 0.12)), Vector3(0, 0.2, -0.01), Vector3.ZERO, Vector3(1.02, 0.7, 1.02))
	add_mesh(head, cyl(0.155, 0.16, 0.05, 16), Mats.cloth(Color(0.75, 0.55, 0.15)), Vector3(0, 0.18, 0))
	add_mesh(head, sphere(0.09), Mats.cloth(Color(0.2, 0.12, 0.08)), Vector3(0, 0.05, 0.1), Vector3.ZERO, Vector3(1.2, 0.7, 0.8))
	# leather apron (soot-stained)
	add_mesh(torso, box(Vector3(0.36, 0.7, 0.03)), Mats.leather(Color(0.22, 0.16, 0.12)), Vector3(0, 0.02, 0.18))
	# satchel of spare torches
	var bag := add_mesh(torso, box(Vector3(0.3, 0.32, 0.14)), Mats.leather(Color(0.36, 0.24, 0.14)), Vector3(0, 0.35, -0.22))
	for i in 3:
		add_mesh(bag, cyl(0.025, 0.03, 0.4, 6), Mats.get_mat("wood_dark"), Vector3(-0.08 + i * 0.08, 0.2, 0), Vector3(0, 0, -8 + i * 8))
	add_mesh(torso, box(Vector3(0.07, 0.07, 0.07)), Mats.flat(Color(0.12, 0.1, 0.08), 0.5), Vector3(-0.2, 0.0, 0.12))
	var t := make_torch(rig["hand_r"], true)
	t.rotation_degrees = Vector3(60, 0, 0)
	rig["weapon"] = t
	(rig["arm_r"] as Node3D).rotation_degrees = Vector3(-40, 0, 5)
	(rig["arm_l"] as Node3D).rotation_degrees = Vector3(-10, 0, -8)
	return rig


# ================================================================ enemies
static func build_enemy(type: String) -> Dictionary:
	match type:
		"goblin":
			return _goblin(false)
		"goblin_archer":
			return _goblin(true)
		"orc":
			return _orc()
		"troll":
			return _troll()
		"wolf_rider":
			return _wolf_rider()
		"dragon":
			return _dragon()
		"shaman":
			return _shaman()
		"shieldbearer":
			return _shieldbearer()
		"sapper":
			return _sapper()
		"bat":
			return _bat()
		"necromancer":
			return _necromancer(false)
		"skeleton":
			return _skeleton()
		"warlord":
			return _warlord()
		"siege_troll":
			return _siege_troll(false)
		"riverbane":
			return _siege_troll(true)
		"hollow_king":
			return _necromancer(true)
		"shade":
			return _shade()
		"frost_wyrm":
			return _dragon({"scales": Mats.pbr("scales", Color(0.55, 0.72, 0.9), 2.2, false, "", 1.5),
				"belly": Mats.pbr("scales", Color(0.9, 0.95, 1.0), 3.0, false, "", 1.0),
				"wing": Color(0.35, 0.5, 0.7), "eye": Color(0.4, 0.85, 1.0)})
		"elder_dragon":
			return _dragon({"scales": Mats.pbr("scales", Color(0.16, 0.14, 0.16), 2.2, false, "", 1.6),
				"belly": Mats.pbr("scales", Color(0.75, 0.55, 0.2), 3.0, false, "", 1.0),
				"wing": Color(0.2, 0.08, 0.12), "eye": Color(1.0, 0.85, 0.2), "horns": 1.6})
	return _goblin(false)


static func _goblin(archer: bool) -> Dictionary:
	var skin := Mats.skin(Color(0.38, 0.52, 0.2))
	var rig := humanoid({
		"skin": skin, "torso": Mats.leather(Color(0.3, 0.24, 0.16)), "legs": skin,
		"arms": skin, "boots": Mats.leather(Color(0.2, 0.15, 0.1)), "bulk": 1.1,
		"height": 0.62, "eyes": Mats.get_mat("eye_yellow"),
	})
	var head: Node3D = rig["head"]
	head.scale = Vector3.ONE * 1.45
	(rig["torso"] as Node3D).rotation_degrees.x = 18
	for s in [1, -1]:
		add_mesh(head, cone(0.05, 0.26, 6), skin, Vector3(0.16 * s, 0.17, -0.02), Vector3(0, 0, -78 * s), Vector3(1, 1, 0.5))
	add_mesh(head, cone(0.035, 0.12, 6), skin, Vector3(0, 0.11, 0.2), Vector3(80, 0, 0))
	# loincloth
	add_mesh(rig["hips"], box(Vector3(0.3, 0.26, 0.24)), Mats.cloth(Color(0.35, 0.28, 0.2)), Vector3(0, -0.1, 0))
	if archer:
		add_mesh(head, sphere(0.18), Mats.cloth(Color(0.16, 0.14, 0.12)), Vector3(0, 0.17, -0.04), Vector3.ZERO, Vector3(1.05, 1.0, 1.0))
		var bow := make_bow(rig["hand_l"], 0.6)
		rig["weapon"] = bow
		(rig["arm_l"] as Node3D).rotation_degrees = Vector3(-70, 0, -5)
	else:
		var d := pivot(rig["hand_r"], "Blade")
		add_mesh(d, cyl(0.02, 0.022, 0.12, 6), Mats.leather(), Vector3(0, 0, 0))
		add_mesh(d, box(Vector3(0.05, 0.35, 0.012)), Mats.get_mat("metal_dark"), Vector3(0, 0.22, 0))
		d.rotation_degrees = Vector3(70, 0, 0)
		rig["weapon"] = d
	return rig


static func _orc() -> Dictionary:
	var skin := Mats.skin(Color(0.3, 0.4, 0.2))
	var rig := humanoid({
		"skin": skin, "torso": Mats.leather(Color(0.25, 0.2, 0.15)), "legs": Mats.cloth(Color(0.2, 0.18, 0.15)),
		"arms": skin, "boots": Mats.get_mat("metal_dark"), "bulk": 1.5, "height": 1.15,
		"eyes": Mats.get_mat("eye_red"),
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	torso.rotation_degrees.x = 10
	head.scale = Vector3(1.2, 1.1, 1.15)
	for s in [1, -1]:
		add_mesh(head, cone(0.025, 0.1, 6), Mats.get_mat("bone"), Vector3(0.06 * s, 0.07, 0.13), Vector3(-15, 0, 0))
		add_mesh(torso, sphere(0.17), Mats.get_mat("metal_dark"), Vector3(0.45 * s, 0.64, 0), Vector3.ZERO, Vector3(1.2, 0.75, 1.1))
		add_mesh(torso, cone(0.05, 0.2, 6), Mats.get_mat("metal_dark"), Vector3(0.5 * s, 0.8, 0), Vector3(0, 0, -20 * s))
	add_mesh(head, box(Vector3(0.24, 0.05, 0.1)), skin, Vector3(0, 0.2, 0.1))
	add_mesh(torso, box(Vector3(0.48, 0.4, 0.05)), Mats.get_mat("metal_dark"), Vector3(0, 0.34, 0.18))
	add_mesh(rig["hips"], box(Vector3(0.5, 0.35, 0.34)), Mats.leather(Color(0.2, 0.15, 0.1)), Vector3(0, -0.12, 0))
	var ax := make_axe(rig["hand_r"])
	ax.rotation_degrees = Vector3(70, 0, 0)
	rig["weapon"] = ax
	(rig["arm_r"] as Node3D).rotation_degrees = Vector3(-25, 0, 0)
	return rig


static func _troll() -> Dictionary:
	var skin := Mats.skin(Color(0.42, 0.46, 0.46))
	var rig := humanoid({
		"skin": skin, "torso": skin, "legs": skin, "arms": skin, "boots": skin,
		"belt": Mats.leather(Color(0.2, 0.15, 0.1)), "bulk": 2.0, "height": 1.7,
		"eyes": Mats.get_mat("eye_yellow"),
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	torso.rotation_degrees.x = 28
	head.scale = Vector3(0.85, 0.8, 0.9)
	head.rotation_degrees.x = -22
	add_mesh(head, box(Vector3(0.26, 0.1, 0.2)), skin, Vector3(0, 0.02, 0.1))
	for s in [1, -1]:
		add_mesh(head, cone(0.03, 0.09, 6), Mats.get_mat("bone"), Vector3(0.08 * s, 0.1, 0.19))
		var arm: Node3D = rig["arm_l" if s > 0 else "arm_r"]
		arm.scale = Vector3(1.2, 1.45, 1.2)
		add_mesh(torso, sphere(0.2), Mats.get_mat("moss"), Vector3(0.36 * s, 0.66, -0.05), Vector3.ZERO, Vector3(1.2, 0.5, 1.0))
	add_mesh(torso, sphere(0.3), skin, Vector3(0, 0.1, 0.1), Vector3.ZERO, Vector3(1.3, 1.1, 1.1))
	add_mesh(torso, sphere(0.25), Mats.get_mat("moss"), Vector3(0, 0.55, -0.16), Vector3.ZERO, Vector3(1.4, 0.5, 0.9))
	add_mesh(rig["hips"], box(Vector3(0.62, 0.35, 0.44)), Mats.leather(Color(0.22, 0.17, 0.12)), Vector3(0, -0.12, 0))
	var club := make_club(rig["hand_r"], 0.9)
	club.rotation_degrees = Vector3(80, 0, 0)
	rig["weapon"] = club
	return rig


static func _wolf_rider() -> Dictionary:
	var root := Node3D.new()
	root.name = "Rig"
	var fur := Mats.get_mat("fur_grey")
	var body := pivot(root, "Body")
	var wolf := pivot(body, "Wolf", Vector3(0, 0, 0))
	add_mesh(wolf, capsule(0.3, 1.25), fur, Vector3(0, 0.78, -0.05), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.9))
	add_mesh(wolf, sphere(0.34), fur, Vector3(0, 0.86, 0.38), Vector3.ZERO, Vector3(1, 1.05, 1))
	var head := pivot(wolf, "Head", Vector3(0, 1.02, 0.72))
	add_mesh(head, sphere(0.2), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.9, 1.1))
	add_mesh(head, box(Vector3(0.14, 0.13, 0.3)), fur, Vector3(0, -0.04, 0.24))
	add_mesh(head, sphere(0.04, 8), Mats.flat(Color(0.05, 0.04, 0.04), 0.3), Vector3(0, -0.01, 0.4))
	for s in [1, -1]:
		add_mesh(head, cone(0.06, 0.16, 6), fur, Vector3(0.1 * s, 0.2, -0.04), Vector3(-10, 0, -15 * s))
		add_mesh(head, sphere(0.025, 8), Mats.get_mat("eye_yellow"), Vector3(0.08 * s, 0.06, 0.16))
	var tail := add_mesh(wolf, cone(0.1, 0.6, 8), fur, Vector3(0, 0.9, -0.8), Vector3(-120, 0, 0))
	tail.name = "Tail"
	var legs: Array = []
	for z in [0.45, -0.45]:
		for s in [1, -1]:
			var leg := pivot(wolf, "Leg", Vector3(0.17 * s, 0.7, z))
			add_mesh(leg, capsule(0.07, 0.62), fur, Vector3(0, -0.32, 0))
			add_mesh(leg, sphere(0.06, 8), Mats.get_mat("fur_dark"), Vector3(0, -0.66, 0.03))
			legs.append(leg)
	# goblin rider
	var skin := Mats.skin(Color(0.38, 0.52, 0.2))
	var rider := humanoid({"skin": skin, "torso": Mats.leather(Color(0.28, 0.22, 0.15)), "legs": skin,
		"arms": skin, "bulk": 1.1, "height": 0.55, "eyes": Mats.get_mat("eye_yellow")})
	var rroot: Node3D = rider["root"]
	body.add_child(rroot)
	rroot.position = Vector3(0, 0.62, -0.1)
	(rider["head"] as Node3D).scale = Vector3.ONE * 1.4
	(rider["leg_l"] as Node3D).rotation_degrees = Vector3(-70, 0, 35)
	(rider["leg_r"] as Node3D).rotation_degrees = Vector3(-70, 0, -35)
	for s in [1, -1]:
		add_mesh(rider["head"], cone(0.05, 0.24, 6), skin, Vector3(0.16 * s, 0.17, -0.02), Vector3(0, 0, -78 * s), Vector3(1, 1, 0.5))
	var spear := pivot(rider["hand_r"], "Spear")
	add_mesh(spear, cyl(0.02, 0.02, 1.8, 6), Mats.get_mat("wood_obj"), Vector3(0, 0.3, 0))
	add_mesh(spear, cone(0.05, 0.2, 6), Mats.get_mat("metal_dark"), Vector3(0, 1.3, 0))
	spear.rotation_degrees = Vector3(75, 0, 0)
	(rider["arm_r"] as Node3D).rotation_degrees = Vector3(-30, 0, 0)
	return {"root": root, "body": body, "wolf": wolf, "head": head, "legs": legs, "tail": tail,
		"rider": rider, "weapon": spear, "arm_r": rider["arm_r"], "torso": rider["torso"]}


static func _dragon(pal: Dictionary = {}) -> Dictionary:
	var root := Node3D.new()
	root.name = "Rig"
	var scales: Material = pal.get("scales", Mats.get_mat("dragon_scales"))
	var belly: Material = pal.get("belly", Mats.get_mat("dragon_belly"))
	var eye_c: Color = pal.get("eye", Color(1.0, 0.55, 0.1))
	var horn_s: float = pal.get("horns", 1.0)
	var bone := Mats.get_mat("bone")
	var body := pivot(root, "Body")
	add_mesh(body, capsule(1.0, 4.6), scales, Vector3(0, 0, 0), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.85))
	add_mesh(body, capsule(0.82, 3.8), belly, Vector3(0, -0.28, 0.1), Vector3(90, 0, 0), Vector3(0.9, 1.0, 0.7))
	# back spikes
	for i in 7:
		add_mesh(body, cone(0.14, 0.5, 6), bone, Vector3(0, 0.9 - abs(i - 3) * 0.05, 1.8 - i * 0.6), Vector3(-25, 0, 0))
	# neck chain
	var neck := pivot(body, "Neck", Vector3(0, 0.3, 1.9))
	var neck_pts := [Vector3(0, 0.2, 0.3), Vector3(0, 0.6, 0.8), Vector3(0, 1.05, 1.25), Vector3(0, 1.5, 1.6), Vector3(0, 1.9, 1.9)]
	for i in neck_pts.size():
		add_mesh(neck, sphere(0.62 - i * 0.07), scales, neck_pts[i])
		add_mesh(neck, cone(0.08, 0.3, 6), bone, neck_pts[i] + Vector3(0, 0.55 - i * 0.06, -0.1), Vector3(-30, 0, 0))
	var head := pivot(neck, "Head", Vector3(0, 2.25, 2.25))
	add_mesh(head, sphere(0.55), scales, Vector3.ZERO, Vector3.ZERO, Vector3(0.95, 0.75, 1.2))
	add_mesh(head, box(Vector3(0.62, 0.34, 0.9)), scales, Vector3(0, -0.02, 0.72))
	var jaw := pivot(head, "Jaw", Vector3(0, -0.2, 0.2))
	add_mesh(jaw, box(Vector3(0.56, 0.16, 1.05)), belly, Vector3(0, -0.06, 0.55))
	for s in [1, -1]:
		add_mesh(head, cone(0.1 * horn_s, 0.8 * horn_s, 8), bone, Vector3(0.28 * s, 0.35, -0.35), Vector3(-120, 0, 12 * s))
		add_mesh(head, sphere(0.08, 8), Mats.emissive(eye_c, 4.0), Vector3(0.27 * s, 0.14, 0.4))
		for k in 3:
			add_mesh(jaw, cone(0.025, 0.1, 4), bone, Vector3(0.22 * s, 0.05, 0.3 + k * 0.25), Vector3.ZERO)
	var mouth := pivot(head, "Mouth", Vector3(0, -0.1, 1.2))
	# wings
	var wings: Array = []
	for s in [1, -1]:
		var w := pivot(body, "WingL" if s > 0 else "WingR", Vector3(0.7 * s, 0.7, 0.7))
		w.scale = Vector3(s, 1, 1)
		_wing(w, pal.get("wing", Color(-1, 0, 0)))
		wings.append(w)
	# tail
	var tail := pivot(body, "Tail", Vector3(0, 0, -2.2))
	var parent := tail
	var segs: Array = []
	for i in 7:
		var seg := pivot(parent, "T%d" % i, Vector3(0, -0.04, -0.75 if i > 0 else 0.0))
		add_mesh(seg, sphere(0.62 - i * 0.075), scales, Vector3.ZERO)
		add_mesh(seg, cone(0.08, 0.3, 6), bone, Vector3(0, 0.5 - i * 0.06, 0), Vector3(-30, 0, 0))
		segs.append(seg)
		parent = seg
	add_mesh(parent, cone(0.3, 0.7, 4), bone, Vector3(0, 0, -0.5), Vector3(-90, 0, 0), Vector3(1, 1, 0.3))
	# legs (tucked for flight)
	for z in [1.2, -1.1]:
		for s in [1, -1]:
			var leg := pivot(body, "Leg", Vector3(0.7 * s, -0.5, z))
			add_mesh(leg, capsule(0.24, 1.1), scales, Vector3(0, -0.35, -0.25), Vector3(-50, 0, 0))
			for k in 3:
				add_mesh(leg, cone(0.05, 0.22, 4), bone, Vector3(0.08 * (k - 1), -0.72, -0.55), Vector3(-150, 0, 0))
	return {"root": root, "body": body, "neck": neck, "head": head, "jaw": jaw, "mouth": mouth,
		"wings": wings, "tail": segs}


## Wing: bones + membrane. Built for the left side (+X), mirrored via scale for the right.
static func _wing(w: Node3D, tint: Color = Color(-1, 0, 0)) -> void:
	var bone_m := Mats.get_mat("bone")
	var pts := [
		Vector3(0, 0, 0),        # 0 shoulder
		Vector3(2.4, 0.5, -0.3), # 1 elbow
		Vector3(5.6, 0.3, -0.6), # 2 tip 1
		Vector3(5.0, 0.0, -2.2), # 3 tip 2
		Vector3(3.8, -0.1, -3.2),# 4 tip 3
		Vector3(1.9, -0.1, -3.0),# 5 tip 4
		Vector3(0.0, -0.1, -2.4),# 6 body attach
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := [[0, 1, 6], [1, 5, 6], [1, 4, 5], [1, 3, 4], [1, 2, 3]]
	for t in tris:
		var a: Vector3 = pts[t[0]]
		var b: Vector3 = pts[t[1]]
		var c: Vector3 = pts[t[2]]
		# sag the membrane a little between bones
		var mid := (a + b + c) / 3.0 + Vector3(0, -0.15, 0)
		for tri in [[a, b, mid], [b, c, mid], [c, a, mid]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			if n.y < 0:
				n = -n
			for v in tri:
				st.set_normal(n)
				st.set_uv(Vector2(v.x, v.z) * 0.3)
				st.add_vertex(v)
	var mem := MeshInstance3D.new()
	mem.mesh = st.commit()
	mem.material_override = Mats.get_mat("dragon_wing")
	if tint.r >= 0.0:
		var wm := (Mats.get_mat("dragon_wing") as StandardMaterial3D).duplicate() as StandardMaterial3D
		wm.albedo_color = tint
		wm.backlight = tint * 1.4
		mem.material_override = wm
	mem.layers = 2
	w.add_child(mem)
	# bones
	for pair in [[0, 1], [1, 2], [1, 3], [1, 4], [1, 5]]:
		var a2: Vector3 = pts[pair[0]]
		var b2: Vector3 = pts[pair[1]]
		var len := a2.distance_to(b2)
		var mi := add_mesh(w, cyl(0.05, 0.1, len, 6), bone_m, (a2 + b2) * 0.5)
		mi.quaternion = Quaternion(Vector3.UP, (b2 - a2).normalized())
	add_mesh(w, cone(0.08, 0.35, 4), bone_m, Vector3(2.4, 0.75, -0.3))


static func _spearman() -> Dictionary:
	var olive := Color(0.33, 0.38, 0.2)
	var rig := humanoid({
		"skin": _human_skin(), "torso": Mats.cloth(olive), "legs": Mats.cloth(Color(0.26, 0.22, 0.18)),
		"arms": Mats.get_mat("metal_dark"), "bulk": 1.05,
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	# nasal helm
	add_mesh(head, sphere(0.168), Mats.get_mat("metal"), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1, 0.9, 1))
	add_mesh(head, box(Vector3(0.03, 0.14, 0.02)), Mats.get_mat("metal"), Vector3(0, 0.13, 0.16))
	add_mesh(head, cone(0.03, 0.1, 6), Mats.get_mat("metal"), Vector3(0, 0.36, 0))
	# quilted gambeson with chain skirt
	add_mesh(torso, cyl(0.26, 0.3, 0.3, 14), Mats.get_mat("metal_dark"), Vector3(0, -0.06, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	add_mesh(torso, box(Vector3(0.38, 0.5, 0.03)), Mats.cloth(Color(0.75, 0.68, 0.4)), Vector3(0, 0.25, 0.17))
	add_mesh(torso, box(Vector3(0.38, 0.08, 0.035)), Mats.cloth(olive.darkened(0.3)), Vector3(0, 0.3, 0.172))
	# round shield on the back
	var sh := add_mesh(torso, cyl(0.3, 0.3, 0.04, 18), Mats.cloth(Color(0.6, 0.5, 0.2)), Vector3(0, 0.35, -0.22), Vector3(90, 0, 0))
	add_mesh(sh, sphere(0.06, 8), Mats.get_mat("metal"), Vector3(0, -0.03, 0))
	# pike held in both hands
	var pike := pivot(rig["hand_r"], "Pike")
	add_mesh(pike, cyl(0.022, 0.026, 3.2, 6), Mats.get_mat("wood_obj"), Vector3(0, 0.9, 0))
	add_mesh(pike, cone(0.05, 0.3, 4), Mats.get_mat("metal"), Vector3(0, 2.62, 0), Vector3.ZERO, Vector3(1, 1, 0.35))
	add_mesh(pike, cyl(0.035, 0.035, 0.08, 6), Mats.get_mat("metal_dark"), Vector3(0, 2.44, 0))
	pike.rotation_degrees = Vector3(78, 0, 0)
	rig["weapon"] = pike
	(rig["arm_r"] as Node3D).rotation_degrees = Vector3(-35, 0, 0)
	(rig["arm_l"] as Node3D).rotation_degrees = Vector3(-55, 25, 0)
	return rig


static func _battle_mage() -> Dictionary:
	var purple := Color(0.26, 0.16, 0.48)
	var rig := humanoid({
		"skin": _human_skin(), "torso": Mats.cloth(purple), "legs": Mats.cloth(purple.darkened(0.3)),
		"arms": Mats.cloth(purple), "bulk": 0.95,
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	var hips: Node3D = rig["hips"]
	# long robe
	add_mesh(hips, cyl(0.25, 0.42, 0.95, 16), Mats.cloth(purple), Vector3(0, -0.45, 0))
	add_mesh(hips, cyl(0.43, 0.44, 0.06, 16), Mats.cloth(Color(0.85, 0.7, 0.3)), Vector3(0, -0.9, 0))
	add_mesh(torso, box(Vector3(0.06, 0.62, 0.03)), Mats.cloth(Color(0.85, 0.7, 0.3)), Vector3(0, 0.25, 0.17))
	# wide brimmed pointed hat
	add_mesh(head, cyl(0.3, 0.3, 0.025, 20), Mats.cloth(purple.darkened(0.2)), Vector3(0, 0.22, 0))
	var tip := add_mesh(head, cone(0.17, 0.55, 12), Mats.cloth(purple.darkened(0.2)), Vector3(0, 0.5, -0.03), Vector3(-12, 0, 0))
	tip.name = "HatTip"
	# long white beard
	add_mesh(head, cone(0.09, 0.3, 8), Mats.cloth(Color(0.9, 0.9, 0.88)), Vector3(0, -0.02, 0.1), Vector3(180, 0, 0))
	# staff with glowing orb
	var staff := pivot(rig["hand_r"], "Staff")
	add_mesh(staff, cyl(0.025, 0.03, 1.7, 6), Mats.get_mat("wood_dark"), Vector3(0, 0.45, 0))
	add_mesh(staff, torus(0.06, 0.09), Mats.get_mat("gold"), Vector3(0, 1.3, 0))
	var orb := add_mesh(staff, sphere(0.09, 12), Mats.emissive(Color(0.6, 0.4, 1.0), 4.0), Vector3(0, 1.36, 0))
	orb.name = "Orb"
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.45, 1.0)
	l.light_energy = 0.9
	l.omni_range = 3.0
	l.position = Vector3(0, 1.4, 0)
	staff.add_child(l)
	staff.rotation_degrees = Vector3(12, 0, 0)
	rig["weapon"] = staff
	(rig["arm_r"] as Node3D).rotation_degrees = Vector3(-20, 0, 8)
	(rig["arm_l"] as Node3D).rotation_degrees = Vector3(-50, -20, -10)
	return rig


static func _cleric() -> Dictionary:
	var cream := Color(0.9, 0.86, 0.74)
	var rig := humanoid({
		"skin": _human_skin(), "torso": Mats.cloth(cream), "legs": Mats.cloth(cream.darkened(0.2)),
		"arms": Mats.cloth(cream), "bulk": 1.0,
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	var hips: Node3D = rig["hips"]
	add_mesh(hips, cyl(0.26, 0.4, 0.95, 16), Mats.cloth(cream), Vector3(0, -0.45, 0))
	add_mesh(hips, cyl(0.41, 0.42, 0.06, 16), Mats.get_mat("gold"), Vector3(0, -0.9, 0))
	# hood and mantle
	add_mesh(head, sphere(0.175), Mats.cloth(cream.darkened(0.08)), Vector3(0, 0.16, -0.04))
	add_mesh(torso, capsule(0.28, 0.4), Mats.cloth(Color(0.55, 0.12, 0.1)), Vector3(0, 0.62, -0.02), Vector3.ZERO, Vector3(1.05, 0.5, 0.85))
	# gold sun emblem
	add_mesh(torso, box(Vector3(0.05, 0.22, 0.03)), Mats.get_mat("gold"), Vector3(0, 0.32, 0.18))
	add_mesh(torso, box(Vector3(0.16, 0.05, 0.03)), Mats.get_mat("gold"), Vector3(0, 0.36, 0.18))
	# faint halo
	var halo := add_mesh(head, torus(0.17, 0.2), Mats.emissive(Color(1.0, 0.9, 0.55), 2.2), Vector3(0, 0.46, -0.05), Vector3(-15, 0, 0), Vector3(1, 0.3, 1))
	halo.name = "Halo"
	# censer staff
	var staff := pivot(rig["hand_r"], "Staff")
	add_mesh(staff, cyl(0.022, 0.026, 1.5, 6), Mats.get_mat("wood_obj"), Vector3(0, 0.4, 0))
	add_mesh(staff, box(Vector3(0.04, 0.3, 0.04)), Mats.get_mat("gold"), Vector3(0, 1.2, 0))
	add_mesh(staff, box(Vector3(0.22, 0.04, 0.04)), Mats.get_mat("gold"), Vector3(0, 1.26, 0))
	staff.rotation_degrees = Vector3(10, 0, 0)
	rig["weapon"] = staff
	(rig["arm_r"] as Node3D).rotation_degrees = Vector3(-20, 0, 6)
	(rig["arm_l"] as Node3D).rotation_degrees = Vector3(-60, -30, 0)
	return rig


static func _trebuchet() -> Dictionary:
	# engineer standing beside the machine
	var rig := humanoid({
		"skin": _human_skin(), "torso": Mats.leather(Color(0.36, 0.26, 0.16)), "legs": Mats.cloth(Color(0.25, 0.22, 0.2)),
		"arms": Mats.cloth(Color(0.5, 0.4, 0.28)), "bulk": 1.1,
	})
	var root: Node3D = rig["root"]
	var body: Node3D = rig["body"]
	body.position = Vector3(1.35, 0, -0.4)
	add_mesh(rig["head"], cyl(0.17, 0.18, 0.1, 14), Mats.leather(Color(0.3, 0.2, 0.12)), Vector3(0, 0.22, 0))
	add_mesh(rig["torso"], box(Vector3(0.36, 0.6, 0.03)), Mats.leather(Color(0.2, 0.15, 0.1)), Vector3(0, 0.05, 0.17))
	var mallet := pivot(rig["hand_r"], "Mallet")
	add_mesh(mallet, cyl(0.02, 0.02, 0.5, 6), Mats.get_mat("wood_obj"), Vector3(0, 0.1, 0))
	add_mesh(mallet, box(Vector3(0.1, 0.1, 0.18)), Mats.get_mat("wood_dark"), Vector3(0, 0.35, 0))
	mallet.rotation_degrees = Vector3(50, 0, 0)
	# the trebuchet frame (faces +Z)
	var tr := pivot(root, "Trebuchet")
	var wood := Mats.get_mat("wood_obj")
	var dark := Mats.get_mat("wood_dark")
	for sx in [-0.45, 0.45]:
		add_mesh(tr, box(Vector3(0.14, 0.14, 2.6)), dark, Vector3(sx, 0.2, 0))
		add_mesh(tr, box(Vector3(0.12, 1.9, 0.12)), wood, Vector3(sx, 1.1, 0.35), Vector3(-12, 0, 0))
		add_mesh(tr, box(Vector3(0.12, 1.9, 0.12)), wood, Vector3(sx, 1.1, -0.35), Vector3(12, 0, 0))
		for z in [-1.0, 1.0]:
			add_mesh(tr, cyl(0.16, 0.16, 0.08, 10), dark, Vector3(sx * 1.2, 0.18, z), Vector3(0, 0, 90))
	add_mesh(tr, box(Vector3(1.0, 0.12, 0.12)), dark, Vector3(0, 0.2, 1.2))
	add_mesh(tr, box(Vector3(1.0, 0.12, 0.12)), dark, Vector3(0, 0.2, -1.2))
	add_mesh(tr, cyl(0.06, 0.06, 1.1, 8), Mats.get_mat("metal_dark"), Vector3(0, 1.95, 0), Vector3(0, 0, 90))
	var arm := pivot(tr, "Arm", Vector3(0, 1.95, 0))
	add_mesh(arm, box(Vector3(0.1, 0.1, 3.0)), wood, Vector3(0, 0, -0.6))
	add_mesh(arm, box(Vector3(0.55, 0.55, 0.55)), Mats.get_mat("stone_dark"), Vector3(0, -0.3, 0.9))
	var sling := add_mesh(arm, sphere(0.2, 10), Mats.get_mat("rock"), Vector3(0, 0.05, -2.1))
	sling.name = "Stone"
	arm.rotation_degrees = Vector3(-35, 0, 0)
	rig["arm"] = arm
	rig["weapon"] = mallet
	(rig["arm_r"] as Node3D).rotation_degrees = Vector3(-30, 0, 0)
	return rig


static func _shaman() -> Dictionary:
	var rig := _goblin(false)
	var head: Node3D = rig["head"]
	# strip the dagger and give a skull staff
	var w: Node3D = rig["weapon"]
	w.get_parent().remove_child(w)
	w.free()
	for i in 5:
		var a := -0.8 + i * 0.4
		add_mesh(head, box(Vector3(0.03, 0.22, 0.06)), Mats.cloth([Color(0.8, 0.2, 0.15), Color(0.2, 0.6, 0.3), Color(0.9, 0.8, 0.2)][i % 3]),
			Vector3(sin(a) * 0.12, 0.34, -0.08 + cos(a) * 0.02), Vector3(-20, 0, rad_to_deg(-a) * 0.5))
	add_mesh(rig["torso"], capsule(0.25, 0.5), Mats.cloth(Color(0.3, 0.22, 0.15)), Vector3(0, 0.45, -0.05), Vector3.ZERO, Vector3(1.1, 0.7, 0.9))
	var staff := pivot(rig["hand_r"], "Staff")
	add_mesh(staff, cyl(0.02, 0.025, 1.1, 6), Mats.get_mat("wood_dark"), Vector3(0, 0.3, 0))
	add_mesh(staff, sphere(0.07, 8), Mats.get_mat("bone"), Vector3(0, 0.88, 0))
	var orb := add_mesh(staff, sphere(0.05, 8), Mats.emissive(Color(0.3, 1.0, 0.4), 4.0), Vector3(0, 0.98, 0))
	orb.name = "Orb"
	staff.rotation_degrees = Vector3(15, 0, 0)
	rig["weapon"] = staff
	return rig


# ================================================================ new enemies & bosses
static func _shieldbearer() -> Dictionary:
	var skin := Mats.skin(Color(0.55, 0.42, 0.25))
	var rig := humanoid({
		"skin": skin, "torso": Mats.get_mat("metal_dark"), "legs": Mats.leather(Color(0.25, 0.2, 0.15)),
		"arms": Mats.leather(Color(0.3, 0.22, 0.15)), "boots": Mats.get_mat("metal_dark"), "bulk": 1.25,
		"height": 0.85, "eyes": Mats.get_mat("eye_yellow"),
	})
	var head: Node3D = rig["head"]
	head.scale = Vector3.ONE * 1.25
	add_mesh(head, sphere(0.17), Mats.get_mat("metal_dark"), Vector3(0, 0.17, -0.01), Vector3.ZERO, Vector3(1.05, 0.85, 1.05))
	add_mesh(head, box(Vector3(0.04, 0.16, 0.05)), Mats.get_mat("metal_dark"), Vector3(0, 0.12, 0.16))
	for s2 in [1, -1]:
		add_mesh(head, cone(0.04, 0.2, 6), skin, Vector3(0.17 * s2, 0.15, -0.02), Vector3(0, 0, -78 * s2), Vector3(1, 1, 0.5))
	# tower shield on the left arm, held in front
	var sh := pivot(rig["hand_l"], "Shield")
	add_mesh(sh, box(Vector3(0.62, 0.95, 0.06)), Mats.get_mat("wood_dark"), Vector3(0, 0.1, 0.12))
	add_mesh(sh, box(Vector3(0.66, 0.06, 0.08)), Mats.get_mat("metal_dark"), Vector3(0, 0.55, 0.12))
	add_mesh(sh, box(Vector3(0.66, 0.06, 0.08)), Mats.get_mat("metal_dark"), Vector3(0, -0.35, 0.12))
	add_mesh(sh, sphere(0.08, 8), Mats.get_mat("metal"), Vector3(0, 0.1, 0.17))
	add_mesh(sh, box(Vector3(0.36, 0.06, 0.02)), Mats.emissive(Color(0.8, 0.2, 0.1), 0.6), Vector3(0, 0.25, 0.16), Vector3(0, 0, 45))
	add_mesh(sh, box(Vector3(0.36, 0.06, 0.02)), Mats.emissive(Color(0.8, 0.2, 0.1), 0.6), Vector3(0, 0.25, 0.16), Vector3(0, 0, -45))
	sh.rotation_degrees = Vector3(80, -20, 0)
	(rig["arm_l"] as Node3D).rotation_degrees = Vector3(-75, 0, 15)
	var sw := make_sword(rig["hand_r"], 0.6)
	sw.rotation_degrees = Vector3(70, 0, 0)
	rig["weapon"] = sw
	rig["shield"] = sh
	return rig


static func _sapper() -> Dictionary:
	var rig := _goblin(false)
	var torso: Node3D = rig["torso"]
	var keg := pivot(torso, "Keg", Vector3(0, 0.4, -0.3))
	add_mesh(keg, cyl(0.2, 0.2, 0.42, 12), Mats.get_mat("wood_obj"), Vector3.ZERO, Vector3(0, 0, 90))
	for x in [-0.14, 0.14]:
		add_mesh(keg, cyl(0.215, 0.215, 0.04, 12), Mats.get_mat("metal_dark"), Vector3(x, 0, 0), Vector3(0, 0, 90))
	add_mesh(keg, cyl(0.012, 0.012, 0.22, 4), Mats.get_mat("rope"), Vector3(0, 0.26, 0), Vector3(20, 0, 0))
	var spark := add_mesh(keg, sphere(0.045, 6), Mats.emissive(Color(1.0, 0.6, 0.15), 6.0), Vector3(0, 0.37, 0.04))
	spark.name = "Spark"
	rig["spark"] = spark
	var head: Node3D = rig["head"]
	add_mesh(head, cyl(0.16, 0.17, 0.1, 10), Mats.leather(Color(0.25, 0.2, 0.14)), Vector3(0, 0.25, 0))
	return rig


static func _bat() -> Dictionary:
	var root := Node3D.new()
	root.name = "Rig"
	var body := pivot(root, "Body")
	var fur := Mats.get_mat("fur_dark")
	add_mesh(body, sphere(0.22), fur, Vector3.ZERO, Vector3.ZERO, Vector3(0.9, 0.85, 1.2))
	var head := pivot(body, "Head", Vector3(0, 0.08, 0.22))
	add_mesh(head, sphere(0.14), fur)
	for s in [1, -1]:
		add_mesh(head, cone(0.05, 0.16, 5), fur, Vector3(0.07 * s, 0.14, -0.02), Vector3(0, 0, -12 * s))
		add_mesh(head, sphere(0.025, 6), Mats.emissive(Color(1.0, 0.2, 0.15), 4.0), Vector3(0.05 * s, 0.03, 0.12))
	var wings: Array = []
	var wing_m := (Mats.get_mat("dragon_wing") as StandardMaterial3D).duplicate() as StandardMaterial3D
	wing_m.albedo_color = Color(0.16, 0.1, 0.12)
	wing_m.backlight = Color(0.35, 0.1, 0.1)
	for s in [1, -1]:
		var w := pivot(body, "Wing", Vector3(0.15 * s, 0.05, 0))
		add_mesh(w, box(Vector3(0.62, 0.02, 0.38)), wing_m, Vector3(0.33 * s, 0, -0.05))
		add_mesh(w, box(Vector3(0.3, 0.02, 0.26)), wing_m, Vector3(0.7 * s, 0, -0.12), Vector3(0, 12 * s, 0))
		wings.append(w)
	return {"root": root, "body": body, "head": head, "wings": wings}


static func _necromancer(king: bool) -> Dictionary:
	var robe := Mats.cloth(Color(0.12, 0.08, 0.14) if not king else Color(0.08, 0.06, 0.06))
	var skin := Mats.skin(Color(0.62, 0.62, 0.55)) if not king else Mats.get_mat("bone")
	var rig := humanoid({
		"skin": skin, "torso": robe, "legs": robe, "arms": robe, "boots": robe,
		"bulk": 1.0 if not king else 1.35, "height": 1.0 if not king else 1.25,
		"eyes": Mats.emissive(Color(0.6, 1.0, 0.4) if not king else Color(0.4, 0.8, 1.0), 5.0),
	})
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	# long robe skirt + hood
	add_mesh(rig["hips"], cone(0.42, 0.95, 12), robe, Vector3(0, -0.45, 0), Vector3(180, 0, 0), Vector3(1, 1, 0.85))
	add_mesh(head, sphere(0.2), robe, Vector3(0, 0.16, -0.04), Vector3.ZERO, Vector3(1.1, 1.15, 1.15))
	add_mesh(torso, cone(0.26, 0.4, 10), robe, Vector3(0, 0.76, -0.08), Vector3(-160, 0, 0), Vector3(1.2, 1, 0.8))
	var staff := pivot(rig["hand_r"], "Staff")
	add_mesh(staff, cyl(0.022, 0.028, 1.5, 6), Mats.get_mat("wood_dark"), Vector3(0, 0.45, 0))
	add_mesh(staff, sphere(0.09, 8), Mats.get_mat("bone"), Vector3(0, 1.22, 0))
	var orb := add_mesh(staff, sphere(0.07, 8), Mats.emissive(Color(0.55, 1.0, 0.35) if not king else Color(0.35, 0.8, 1.0), 5.0), Vector3(0, 1.36, 0))
	orb.name = "Orb"
	staff.rotation_degrees = Vector3(12, 0, 0)
	rig["weapon"] = staff
	if king:
		var crown := pivot(head, "Crown", Vector3(0, 0.36, 0))
		add_mesh(crown, cyl(0.17, 0.16, 0.08, 12), Mats.get_mat("metal_dark"))
		for i in 7:
			var a := TAU * i / 7.0
			add_mesh(crown, cone(0.03, 0.2, 5), Mats.get_mat("bone"), Vector3(cos(a) * 0.16, 0.12, sin(a) * 0.16))
		for s in [1, -1]:
			add_mesh(torso, sphere(0.16), Mats.get_mat("bone"), Vector3(0.38 * s, 0.68, 0), Vector3.ZERO, Vector3(1.1, 0.7, 1.0))
			for k in 3:
				add_mesh(torso, cone(0.03, 0.18, 4), Mats.get_mat("bone"), Vector3(0.38 * s + 0.05 * (k - 1), 0.8, 0), Vector3(0, 0, -15 * s))
	return rig


static func _skeleton() -> Dictionary:
	var bone := Mats.get_mat("bone")
	var root := Node3D.new()
	root.name = "Rig"
	var body := pivot(root, "Body")
	body.scale = Vector3.ONE * 0.8
	var hips := pivot(body, "Hips", Vector3(0, 0.92, 0))
	var rig := {"root": root, "body": body, "hips": hips}
	add_mesh(hips, box(Vector3(0.3, 0.1, 0.14)), bone)
	for side in [1, -1]:
		var leg := pivot(hips, "Leg", Vector3(0.1 * side, -0.02, 0))
		add_mesh(leg, cyl(0.03, 0.03, 0.46, 5), bone, Vector3(0, -0.24, 0))
		add_mesh(leg, cyl(0.025, 0.025, 0.44, 5), bone, Vector3(0, -0.66, 0))
		add_mesh(leg, box(Vector3(0.08, 0.04, 0.18)), bone, Vector3(0, -0.88, 0.04))
		rig["leg_l" if side > 0 else "leg_r"] = leg
	var torso := pivot(hips, "Torso", Vector3(0, 0.04, 0))
	rig["torso"] = torso
	add_mesh(torso, cyl(0.03, 0.03, 0.62, 5), bone, Vector3(0, 0.32, -0.05))
	for i in 4:
		add_mesh(torso, torus(0.11 - i * 0.008, 0.135 - i * 0.008), bone, Vector3(0, 0.3 + i * 0.09, 0.0), Vector3(90, 0, 0), Vector3(1.2, 1, 0.3))
	var head := pivot(torso, "Head", Vector3(0, 0.7, 0))
	rig["head"] = head
	add_mesh(head, sphere(0.13), bone, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(0.9, 1.0, 1.0))
	add_mesh(head, box(Vector3(0.14, 0.06, 0.1)), bone, Vector3(0, 0.02, 0.05))
	for s in [1, -1]:
		add_mesh(head, sphere(0.03, 6), Mats.emissive(Color(0.4, 1.0, 0.5), 5.0), Vector3(0.045 * s, 0.13, 0.11))
	for side in [1, -1]:
		var arm := pivot(torso, "Arm", Vector3(0.2 * side, 0.6, 0))
		add_mesh(arm, cyl(0.025, 0.025, 0.34, 5), bone, Vector3(0, -0.17, 0))
		add_mesh(arm, cyl(0.02, 0.02, 0.32, 5), bone, Vector3(0, -0.5, 0))
		var hand := pivot(arm, "Hand", Vector3(0, -0.66, 0.02))
		rig["arm_l" if side > 0 else "arm_r"] = arm
		rig["hand_l" if side > 0 else "hand_r"] = hand
	var sw := make_sword(rig["hand_r"], 0.5)
	sw.rotation_degrees = Vector3(70, 0, 0)
	rig["weapon"] = sw
	return rig


static func _warlord() -> Dictionary:
	var rig := _orc()
	var head: Node3D = rig["head"]
	var torso: Node3D = rig["torso"]
	var crown := pivot(head, "Crown", Vector3(0, 0.3, 0))
	add_mesh(crown, cyl(0.17, 0.16, 0.08, 12), Mats.get_mat("gold"))
	for i in 5:
		var a := TAU * i / 5.0
		add_mesh(crown, cone(0.035, 0.16, 5), Mats.get_mat("gold"), Vector3(cos(a) * 0.15, 0.1, sin(a) * 0.15))
	# war banner on the back
	var pole := pivot(torso, "Banner", Vector3(0, 0.4, -0.25))
	add_mesh(pole, cyl(0.025, 0.025, 2.2, 6), Mats.get_mat("wood_dark"), Vector3(0, 0.9, 0))
	add_mesh(pole, box(Vector3(0.6, 0.8, 0.02)), Mats.cloth(Color(0.5, 0.08, 0.05)), Vector3(0.32, 1.55, 0))
	add_mesh(pole, sphere(0.1, 8), Mats.get_mat("bone"), Vector3(0, 2.05, 0))
	# war horn
	add_mesh(torso, cone(0.06, 0.4, 8), Mats.get_mat("bone"), Vector3(0.28, 0.2, 0.12), Vector3(0, 0, 70))
	add_mesh(torso, box(Vector3(0.55, 0.45, 0.06)), Mats.get_mat("gold"), Vector3(0, 0.36, 0.2))
	return rig


static func _siege_troll(river: bool) -> Dictionary:
	var rig := _troll()
	var torso: Node3D = rig["torso"]
	for s in [1, -1]:
		add_mesh(torso, sphere(0.28), Mats.get_mat("moss"), Vector3(0.3 * s, 0.7, -0.2), Vector3.ZERO, Vector3(1.4, 0.6, 1.1))
	for i in 5:
		add_mesh(torso, cone(0.09, 0.3, 5), Mats.get_mat("rock_dark"), Vector3(-0.3 + i * 0.15, 0.78, -0.25), Vector3(-30, 0, 0))
	var boulder := pivot(rig["hand_l"], "Boulder")
	add_mesh(boulder, sphere(0.35, 8), Mats.get_mat("rock"), Vector3(0, -0.1, 0.1), Vector3.ZERO, Vector3(1.0, 0.85, 0.9))
	rig["boulder"] = boulder
	if river:
		for k in 6:
			add_mesh(torso, sphere(0.12, 6), Mats.flat(Color(0.2, 0.45, 0.4)), Vector3(-0.35 + k * 0.14, 0.15 + (k % 3) * 0.25, 0.28), Vector3.ZERO, Vector3(1, 0.4, 0.4))
	return rig


static func _shade() -> Dictionary:
	var ghost := StandardMaterial3D.new()
	ghost.albedo_color = Color(0.2, 0.25, 0.35, 0.55)
	ghost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost.emission_enabled = true
	ghost.emission = Color(0.25, 0.35, 0.6)
	ghost.emission_energy_multiplier = 0.8
	ghost.rim_enabled = true
	ghost.rim = 1.0
	var rig := humanoid({
		"skin": ghost, "torso": ghost, "legs": ghost, "arms": ghost, "boots": ghost, "belt": ghost,
		"bulk": 1.2, "height": 1.35, "eyes": Mats.emissive(Color(0.7, 0.9, 1.0), 6.0),
	})
	add_mesh(rig["hips"], cone(0.45, 1.1, 12), ghost, Vector3(0, -0.5, 0), Vector3(180, 0, 0))
	add_mesh(rig["head"], sphere(0.21), ghost, Vector3(0, 0.17, -0.05), Vector3.ZERO, Vector3(1.1, 1.2, 1.2))
	var scythe := pivot(rig["hand_r"], "Scythe")
	add_mesh(scythe, cyl(0.025, 0.025, 1.8, 6), Mats.get_mat("wood_dark"), Vector3(0, 0.5, 0))
	add_mesh(scythe, box(Vector3(0.05, 0.08, 0.7)), Mats.get_mat("metal_dark"), Vector3(0, 1.38, 0.3), Vector3(20, 0, 0))
	scythe.rotation_degrees = Vector3(20, 0, 0)
	rig["weapon"] = scythe
	return rig


# ================================================================ helpers
## Replace every MeshInstance3D material under a node (used for placement ghost).
static func override_materials(n: Node, mat: Material) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).material_override = mat
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		override_materials(c, mat)


static func set_shadows(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		set_shadows(c, on)
