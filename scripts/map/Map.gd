class_name GameMap
extends Node3D
## Builds the whole battlefield procedurally: enemy road (Path3D), terrain with
## a road distance field, grass, trees, rocks, village, castle, spawn portal
## and torches. Also answers placement queries (distance to road, blockers).

const ROAD_HALF_WIDTH := 1.7
const MIN_BUILD_DIST := 2.5          ## unit centre must be at least this far from the road centre line
const BUILD_RECT := Rect2(-46.0, -27.0, 90.0, 54.0)
const CASTLE_RECT := Rect2(45.0, -7.0, 22.0, 36.0)
const FLAT_RECT := Rect2(-64.0, -38.0, 134.0, 76.0)


# road distance field
const SDF_ORIGIN := Vector2(-70.0, -50.0)
const SDF_SIZE := Vector2(140.0, 100.0)
const SDF_RES := 0.4
var sdf_w: int
var sdf_h: int
var sdf: PackedFloat32Array
var sdf_texture: ImageTexture

var path_points: Array = []       ## Vector2 road waypoints of the main road
var all_path_points: Array = []   ## one waypoint list per road (most maps have one)
var curves: Array = []            ## Curve3D per road
var lengths: Array = []           ## baked length per road
var _spawn_rr: int = 0
var is_dark: bool = false         ## night map: enemies need light to be seen
var river: Array = []             ## Vector2 river centre line (empty = no river)
var river_width: float = 0.0
var bridges: Array = []           ## Vector2 build platforms on the river
var barricades: Array = []        ## Brunhild's barricades currently on the road
var light_points: Array = []      ## torch posts (night maps reveal enemies near them)
var _reveal_t: float = 0.0
const TORCH_LIGHT := 8.5
var portal_pos: Vector3
var theme: Dictionary = {}
var path: Path3D
var curve: Curve3D
var path_length: float = 0.0
var blockers: Array = []   ## [{pos: Vector2, r: float}]
var flicker_lights: Array = []
var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()

var props: Node3D
var foliage: Node3D


func _ready() -> void:
	var lv: Dictionary = GameManager.level
	all_path_points = lv.get("paths", [lv.get("path", LevelDefs.LEVELS[0]["path"])])
	path_points = all_path_points[0]
	river = lv.get("river", [])
	river_width = float(lv.get("river_width", 0.0))
	bridges = lv.get("bridges", [])
	theme = LevelDefs.theme(lv)
	is_dark = bool(theme.get("dark", false))
	var p0: Vector2 = path_points[0]
	portal_pos = Vector3(p0.x + 3.0, 0.0, p0.y)
	rng.seed = hash(str(lv.get("id", "x")))
	noise.seed = 42
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	props = Node3D.new()
	props.name = "Props"
	add_child(props)
	foliage = Node3D.new()
	foliage.name = "Foliage"
	add_child(foliage)
	var steps := [_build_path, _build_sdf, _build_terrain, _build_river, _build_castle, _build_portal, _build_village,
		_build_torches, _build_rocks, _build_trees, _build_bushes]
	if Profile.high_quality():
		steps.append(_build_grass)
	for st in steps:
		var t0 := Time.get_ticks_usec()
		st.call()
		if OS.has_environment("SIEGE_PROFILE"):
			print("  map %s: %.0f ms" % [st.get_method(), (Time.get_ticks_usec() - t0) / 1000.0])


func _process(_delta: float) -> void:
	if is_dark:
		_reveal_t -= _delta
		if _reveal_t <= 0.0:
			_reveal_t = 0.2
			_reveal_enemies()
	var t := Time.get_ticks_msec() / 1000.0
	for i in flicker_lights.size():
		var l: OmniLight3D = flicker_lights[i]
		if is_instance_valid(l):
			var base: float = l.get_meta("base_energy", 1.5)
			l.light_energy = base * (0.85 + 0.1 * sin(t * 9.0 + i * 1.7) + 0.06 * sin(t * 23.0 + i * 3.1))


## Night maps: enemies near a light can be targeted for a moment.
## Lights: torch posts, the castle, Torch Throwers (big), every soldier's
## lantern (small), fire on the ground and hero ability zones.
func _reveal_enemies() -> void:
	var em = GameManager.enemy_manager
	if em == null:
		return
	var lights: Array = []   # [Vector2, radius]
	for lp in light_points:
		lights.append([lp, TORCH_LIGHT])
	lights.append([Vector2(46, 11), 12.0])
	var um = GameManager.unit_manager
	if um:
		for u in um.units:
			var r := 9.5 if u.unit_type == "torch_thrower" else (6.5 if u.is_hero() or u.unit_type == "cleric" else 4.0)
			lights.append([Vector2(u.global_position.x, u.global_position.z), r])
	var fx_root: Node = GameManager.main.get_node_or_null("Effects") if GameManager.main else null
	if fx_root:
		for n in fx_root.get_children():
			if n is FirePatch:
				lights.append([Vector2(n.global_position.x, n.global_position.z), (n as FirePatch).radius + 3.0])
			elif n is AbilityZone:
				lights.append([Vector2(n.global_position.x, n.global_position.z), (n as AbilityZone).radius + 2.0])
	for e in em.enemies:
		if not is_instance_valid(e) or not e.alive:
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		for l in lights:
			if p.distance_to(l[0]) <= float(l[1]):
				e.reveal_timer = 0.35
				break


# ================================================================ river
func _build_river() -> void:
	if river.size() < 2:
		return
	# densify the centre line (Catmull-Rom) for a smooth ribbon
	var pts: Array[Vector2] = []
	for i in river.size() - 1:
		var p0: Vector2 = river[max(i - 1, 0)]
		var p1: Vector2 = river[i]
		var p2: Vector2 = river[i + 1]
		var p3: Vector2 = river[min(i + 2, river.size() - 1)]
		for k in 8:
			var t := k / 8.0
			var t2 := t * t
			var t3 := t2 * t
			pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	pts.append(river[river.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := river_width * 0.5 + 0.6
	var along := 0.0
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0
	for i in pts.size():
		var a: Vector2 = pts[max(i - 1, 0)]
		var b: Vector2 = pts[min(i + 1, pts.size() - 1)]
		var dir := (b - a).normalized()
		var n := Vector2(-dir.y, dir.x)
		var c: Vector2 = pts[i]
		if i > 0:
			along += c.distance_to(pts[i - 1])
		var y := 0.05 if FLAT_RECT.has_point(c) else height_at(c.x, c.y) + 0.05
		var l := Vector3(c.x + n.x * half, y, c.y + n.y * half)
		var r := Vector3(c.x - n.x * half, y, c.y - n.y * half)
		var v := along / 8.0
		if i > 0:
			for tri in [[prev_l, 0.0, prev_v], [prev_r, 1.0, prev_v], [r, 1.0, v], [prev_l, 0.0, prev_v], [r, 1.0, v], [l, 0.0, v]]:
				st.set_normal(Vector3.UP)
				st.set_uv(Vector2(tri[1], tri[2]))
				st.add_vertex(tri[0])
		prev_l = l
		prev_r = r
		prev_v = v
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/water.gdshader")
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.04
	nt.noise = fn
	mat.set_shader_parameter("noise", nt)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "River"
	add_child(mi)
	# muddy banks with reeds and stones
	for i in range(0, pts.size(), 2):
		var c2: Vector2 = pts[i]
		if not FLAT_RECT.grow(8).has_point(c2):
			continue
		var a2: Vector2 = pts[max(i - 1, 0)]
		var b2: Vector2 = pts[min(i + 1, pts.size() - 1)]
		var d2 := (b2 - a2).normalized()
		var n2 := Vector2(-d2.y, d2.x)
		for side in [1.0, -1.0]:
			var bp: Vector2 = c2 + n2 * side * (half + rng.randf_range(0.2, 0.9))
			var bpos := Vector3(bp.x, 0.0, bp.y)
			if path_distance(bpos) < 3.0:
				continue
			if rng.randf() < 0.5:
				_mesh(props, _rock_mesh(i % 4), Mats.get_mat("rock_dark"), bpos, Vector3(0, rng.randf() * 360, 0), Vector3.ONE * rng.randf_range(0.3, 0.6))
			else:
				for k in 4:
					_mesh(props, ModelBuilder.cyl(0.015, 0.03, rng.randf_range(0.8, 1.4), 4), Mats.flat(Color(0.35, 0.4, 0.2)),
						bpos + Vector3(rng.randf_range(-0.4, 0.4), 0.5, rng.randf_range(-0.4, 0.4)), Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12)))
	_build_road_bridges()
	# build platforms on the water
	for bpt in bridges:
		var pp := Vector3((bpt as Vector2).x, 0, (bpt as Vector2).y)
		var plat := _node(props, "Platform", pp)
		_box(plat, Vector3(0, 0.1, 0), Vector3(3.4, 0.16, 3.4), Mats.get_mat("wood"))
		for cx in [-1.5, 1.5]:
			for cz in [-1.5, 1.5]:
				_cyl(plat, Vector3(cx, -0.2, cz), 0.12, 0.14, 0.9, Mats.get_mat("wood_dark"), 8)
		_box(plat, Vector3(0, 0.2, 1.6), Vector3(3.4, 0.08, 0.15), Mats.get_mat("wood_dark"))
		_box(plat, Vector3(0, 0.2, -1.6), Vector3(3.4, 0.08, 0.15), Mats.get_mat("wood_dark"))
		_light(plat, Vector3(1.5, 1.2, 1.5), Color(1.0, 0.65, 0.3), 0.8, 4.0, true, false)


## Wooden bridges wherever a road crosses the river.
func _build_road_bridges() -> void:
	for c in curves:
		var cv: Curve3D = c
		var L := cv.get_baked_length()
		var d := 0.0
		var start := -1.0
		while d <= L:
			var p := cv.sample_baked(d)
			var wet := near_water(p, 1.2)
			if wet and start < 0.0:
				start = d
			elif not wet and start >= 0.0:
				_bridge(cv, start, d)
				start = -1.0
			d += 0.5
		if start >= 0.0:
			_bridge(cv, start, L)


func _bridge(cv: Curve3D, a: float, b: float) -> void:
	var pa := cv.sample_baked(a)
	var pb := cv.sample_baked(b)
	var mid := (pa + pb) * 0.5
	var dir := pb - pa
	dir.y = 0
	var length := dir.length() + 1.5
	var yaw := atan2(dir.x, dir.z)
	var br := _node(props, "Bridge", mid, rad_to_deg(yaw))
	var n := int(length / 0.45)
	for i in n:
		var z := -length * 0.5 + (i + 0.5) * (length / n)
		_box(br, Vector3(0, 0.1, z), Vector3(4.4, 0.08, length / n * 0.9), Mats.get_mat("wood"), Vector3(0, 0, (i % 3 - 1) * 1.5))
	for side in [-1.0, 1.0]:
		_box(br, Vector3(2.2 * side, 0.55, 0), Vector3(0.12, 0.1, length), Mats.get_mat("wood_dark"))
		var posts := int(length / 1.6) + 1
		for k in posts:
			var z2: float = -length * 0.5 + k * (length / max(1, posts - 1))
			_box(br, Vector3(2.2 * side, 0.3, z2), Vector3(0.15, 0.6, 0.15), Mats.get_mat("wood_dark"))


# ================================================================ path
func _build_path() -> void:
	for pi in all_path_points.size():
		var pts: Array = all_path_points[pi]
		var pth := Path3D.new()
		pth.name = "EnemyPath%d" % pi
		var c := Curve3D.new()
		c.bake_interval = 0.5
		var n := pts.size()
		for i in n:
			var p: Vector2 = pts[i]
			var prev: Vector2 = pts[max(i - 1, 0)]
			var nxt: Vector2 = pts[min(i + 1, n - 1)]
			var tan := (nxt - prev) * 0.22
			if i == 0 or i == n - 1:
				tan = Vector2.ZERO
			c.add_point(Vector3(p.x, 0, p.y), Vector3(-tan.x, 0, -tan.y), Vector3(tan.x, 0, tan.y))
		pth.curve = c
		add_child(pth)
		curves.append(c)
		lengths.append(c.get_baked_length())
		if pi == 0:
			path = pth
	curve = curves[0]
	path_length = lengths[0]


func path_count() -> int:
	return curves.size()


func length_of(idx: int) -> float:
	return float(lengths[clampi(idx, 0, lengths.size() - 1)])


func sample_on(idx: int, offset: float) -> Vector3:
	var c: Curve3D = curves[clampi(idx, 0, curves.size() - 1)]
	return c.sample_baked(clamp(offset, 0.0, length_of(idx)), true)


func dir_on(idx: int, offset: float) -> Vector3:
	var a := sample_on(idx, offset)
	var b := sample_on(idx, offset + 0.5)
	var d := b - a
	d.y = 0
	if d.length() < 0.001:
		return Vector3.RIGHT
	return d.normalized()


## Enemies alternate between roads on multi-road maps.
func pick_path_for_spawn() -> int:
	if curves.size() <= 1:
		return 0
	_spawn_rr = (_spawn_rr + 1) % curves.size()
	return _spawn_rr


## Nearest point on any road to a world position.
func nearest_road_point(pos: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var bd := INF
	for c in curves:
		var q: Vector3 = (c as Curve3D).get_closest_point(Vector3(pos.x, 0, pos.z))
		var d := q.distance_squared_to(Vector3(pos.x, 0, pos.z))
		if d < bd:
			bd = d
			best = q
	return best


## Distance from a point to the river centre line (99 when there is no river).
func river_distance(pos: Vector3) -> float:
	if river.size() < 2:
		return 99.0
	var p := Vector2(pos.x, pos.z)
	var best := 99.0
	for i in river.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, river[i], river[i + 1])
		best = min(best, p.distance_to(q))
	return best


## Yaw that turns a wall across the road at this point.
func road_yaw_at(pos: Vector3) -> float:
	var best_c: Curve3D = curves[0]
	var bd := INF
	for c in curves:
		var q: Vector3 = (c as Curve3D).get_closest_point(pos)
		var d := q.distance_squared_to(pos)
		if d < bd:
			bd = d
			best_c = c
	var off := best_c.get_closest_offset(pos)
	var a := best_c.sample_baked(off)
	var b := best_c.sample_baked(min(off + 0.5, best_c.get_baked_length()))
	var dir := b - a
	return atan2(dir.x, dir.z) + PI * 0.5


func near_water(pos: Vector3, margin: float = 0.0) -> bool:
	return river_distance(pos) < river_width * 0.5 + margin


func on_bridge(pos: Vector3) -> bool:
	for b in bridges:
		if Vector2(pos.x, pos.z).distance_to(b) < 2.2:
			return true
	return false


func sample_path(offset: float) -> Vector3:
	return curve.sample_baked(clamp(offset, 0.0, path_length), true)


## Direction of travel at a given distance along the road.
func path_direction(offset: float) -> Vector3:
	var a := sample_path(offset)
	var b := sample_path(offset + 0.5)
	var d := b - a
	d.y = 0
	if d.length() < 0.001:
		return Vector3.RIGHT
	return d.normalized()


## Closest distance along the road to a world position.
func closest_offset(pos: Vector3) -> float:
	return curve.get_closest_offset(Vector3(pos.x, 0, pos.z))


# ================================================================ distance field
func _build_sdf() -> void:
	sdf_w = int(SDF_SIZE.x / SDF_RES)
	sdf_h = int(SDF_SIZE.y / SDF_RES)
	sdf = PackedFloat32Array()
	sdf.resize(sdf_w * sdf_h)
	sdf.fill(99.0)
	for c in curves:
		_sdf_add_curve(c)
	var img := Image.create_from_data(sdf_w, sdf_h, false, Image.FORMAT_RF, sdf.to_byte_array())
	sdf_texture = ImageTexture.create_from_image(img)


func _sdf_add_curve(c: Curve3D) -> void:
	var pts: PackedVector3Array = c.get_baked_points()
	# subsample to ~2m segments for speed; the curve is smooth so this stays accurate
	var poly: Array[Vector2] = []
	var step: int = max(1, int(2.0 / c.bake_interval))
	for i in range(0, pts.size(), step):
		poly.append(Vector2(pts[i].x, pts[i].z))
	var last := Vector2(pts[pts.size() - 1].x, pts[pts.size() - 1].z)
	if poly[poly.size() - 1] != last:
		poly.append(last)
	var R := 8.0
	for s in poly.size() - 1:
		var a: Vector2 = poly[s]
		var b: Vector2 = poly[s + 1]
		var ab := b - a
		var ab_len2: float = max(ab.length_squared(), 0.0001)
		var minx := int((min(a.x, b.x) - R - SDF_ORIGIN.x) / SDF_RES)
		var maxx := int((max(a.x, b.x) + R - SDF_ORIGIN.x) / SDF_RES) + 1
		var miny := int((min(a.y, b.y) - R - SDF_ORIGIN.y) / SDF_RES)
		var maxy := int((max(a.y, b.y) + R - SDF_ORIGIN.y) / SDF_RES) + 1
		minx = clampi(minx, 0, sdf_w - 1)
		maxx = clampi(maxx, 0, sdf_w - 1)
		miny = clampi(miny, 0, sdf_h - 1)
		maxy = clampi(maxy, 0, sdf_h - 1)
		for gy in range(miny, maxy + 1):
			var wy := SDF_ORIGIN.y + (gy + 0.5) * SDF_RES
			var row := gy * sdf_w
			for gx in range(minx, maxx + 1):
				var wx := SDF_ORIGIN.x + (gx + 0.5) * SDF_RES
				var px := wx - a.x
				var py := wy - a.y
				var t: float = clamp((px * ab.x + py * ab.y) / ab_len2, 0.0, 1.0)
				var dx := px - ab.x * t
				var dy := py - ab.y * t
				var d := sqrt(dx * dx + dy * dy)
				if d < sdf[row + gx]:
					sdf[row + gx] = d


## Distance from a world position to the road centre line (bilinear sample).
func path_distance(pos: Vector3) -> float:
	var fx := (pos.x - SDF_ORIGIN.x) / SDF_RES - 0.5
	var fy := (pos.z - SDF_ORIGIN.y) / SDF_RES - 0.5
	if fx < 0 or fy < 0 or fx >= sdf_w - 1 or fy >= sdf_h - 1:
		return 99.0
	var x0 := int(fx)
	var y0 := int(fy)
	var tx := fx - x0
	var ty := fy - y0
	var i := y0 * sdf_w + x0
	var a: float = lerp(sdf[i], sdf[i + 1], tx)
	var b: float = lerp(sdf[i + sdf_w], sdf[i + sdf_w + 1], tx)
	return lerp(a, b, ty)


# ================================================================ placement queries
func add_blocker(pos: Vector3, r: float) -> void:
	blockers.append({"pos": Vector2(pos.x, pos.z), "r": r})


func is_blocked(pos: Vector3, radius: float) -> bool:
	var p := Vector2(pos.x, pos.z)
	for b in blockers:
		if p.distance_to(b["pos"]) < float(b["r"]) + radius:
			return true
	return false


## Returns "" when the position is a legal build spot, otherwise a short reason.
## allow_road: heroes like Aldric may stand on the road itself.
func placement_error(pos: Vector3, allow_road: bool = false) -> String:
	if not BUILD_RECT.has_point(Vector2(pos.x, pos.z)):
		return "Outside the battlefield"
	if CASTLE_RECT.has_point(Vector2(pos.x, pos.z)):
		return "Too close to the castle"
	if path_distance(pos) < MIN_BUILD_DIST and not allow_road:
		return "Can't stand on the road"
	if near_water(pos, 0.6) and not on_bridge(pos):
		return "Can't build in the river (use a bridge platform)"
	if is_blocked(pos, 0.7):
		return "Something is in the way"
	return ""


func height_at(x: float, z: float) -> float:
	var dx: float = max(0.0, max(FLAT_RECT.position.x - x, x - FLAT_RECT.end.x))
	var dz: float = max(0.0, max(FLAT_RECT.position.y - z, z - FLAT_RECT.end.y))
	var d := sqrt(dx * dx + dz * dz)
	if d <= 0.0:
		return 0.0
	var ramp := smoothstep(0.0, 22.0, d)
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	return ramp * (3.0 + n * 14.0) + d * 0.08


# ================================================================ terrain
func _build_terrain() -> void:
	var x0 := -110.0
	var z0 := -85.0
	var w := 220
	var h := 170
	var step := 1.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	verts.resize((w + 1) * (h + 1))
	norms.resize((w + 1) * (h + 1))
	uvs.resize((w + 1) * (h + 1))
	tans.resize((w + 1) * (h + 1) * 4)
	for j in h + 1:
		for i in w + 1:
			var x := x0 + i * step
			var z := z0 + j * step
			var y := height_at(x, z)
			var k := j * (w + 1) + i
			verts[k] = Vector3(x, y, z)
			var hx := height_at(x + 0.5, z) - height_at(x - 0.5, z)
			var hz := height_at(x, z + 0.5) - height_at(x, z - 0.5)
			norms[k] = Vector3(-hx, 1.0, -hz).normalized()
			uvs[k] = Vector2(x, z)
			tans[k * 4] = 1.0
			tans[k * 4 + 1] = 0.0
			tans[k * 4 + 2] = 0.0
			tans[k * 4 + 3] = 1.0
	for j in h:
		for i in w:
			var a := j * (w + 1) + i
			var b := a + 1
			var c := a + (w + 1)
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/terrain.gdshader")
	for n in ["grass", "dirt"]:
		mat.set_shader_parameter(n + "_albedo", Mats.tex(n + "_albedo"))
		mat.set_shader_parameter(n + "_normal", Mats.tex(n + "_normal"))
		mat.set_shader_parameter(n + "_rough", Mats.tex(n + "_rough"))
	mat.set_shader_parameter("rock_albedo", Mats.tex("rock_albedo"))
	mat.set_shader_parameter("rock_normal", Mats.tex("rock_normal"))
	mat.set_shader_parameter("cobble_albedo", Mats.tex("cobble_albedo"))
	mat.set_shader_parameter("cobble_normal", Mats.tex("cobble_normal"))
	mat.set_shader_parameter("macro_noise", Mats.tex("macro_noise"))
	mat.set_shader_parameter("road_sdf", sdf_texture)
	mat.set_shader_parameter("sdf_origin", SDF_ORIGIN)
	mat.set_shader_parameter("sdf_size", SDF_SIZE)
	mat.set_shader_parameter("road_half_width", ROAD_HALF_WIDTH)
	mat.set_shader_parameter("plaza_rect", Vector4(37.0, 5.5, 49.0, 16.5))
	mat.set_shader_parameter("grass_tint", theme.get("grass_tint", Color.WHITE))
	mat.set_shader_parameter("snow", float(theme.get("snow", 0.0)))
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = 1
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


# ================================================================ prop helpers
func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO,
		scl: Vector3 = Vector3.ONE, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return _mesh(parent, ModelBuilder.box(size), mat, pos, rot_deg)


func _cyl(parent: Node3D, pos: Vector3, top: float, bottom: float, h: float, mat: Material, segs: int = 20) -> MeshInstance3D:
	return _mesh(parent, ModelBuilder.cyl(top, bottom, h, segs), mat, pos)


func _node(parent: Node3D, name: String, pos: Vector3, rot_y_deg: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation_degrees.y = rot_y_deg
	parent.add_child(n)
	return n


func _light(parent: Node3D, pos: Vector3, color: Color, energy: float, rng_m: float, flicker: bool = true, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadows
	l.set_meta("base_energy", energy)
	parent.add_child(l)
	if flicker:
		flicker_lights.append(l)
	return l


func _fire(parent: Node3D, pos: Vector3, size: float) -> void:
	var f := FX.fire_emitter(size)
	f.position = pos
	parent.add_child(f)
	f.emitting = true
	_mesh(parent, ModelBuilder.sphere(0.06 * size, 8), Mats.get_mat("fire"), pos + Vector3(0, -0.05, 0), Vector3.ZERO, Vector3.ONE, false)


func _banner(parent: Node3D, pos: Vector3, size: Vector2, mat_key: String, rot_y: float) -> void:
	var q := QuadMesh.new()
	q.size = size
	q.subdivide_width = 4
	q.subdivide_depth = 10
	# Quad UV (0,0) is top-left, which the banner shader expects
	var mi := _mesh(parent, q, Mats.get_mat(mat_key), pos, Vector3(0, rot_y, 0), Vector3.ONE, true)
	mi.name = "Banner"


## Gable roof mesh with its own UVs (so shingle rows follow the slope).
func _roof_mesh(w: float, d: float, rise: float, overhang: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w * 0.5 + overhang
	var hd := d * 0.5 + overhang
	var drop := rise * (overhang / (d * 0.5))
	var ridge_y := rise
	var eave_y := -drop
	var slope_len := Vector2(hd, ridge_y - eave_y).length()
	var tile := 2.2
	for side in [1.0, -1.0]:
		var a := Vector3(-hw, ridge_y, 0)
		var b := Vector3(hw, ridge_y, 0)
		var c := Vector3(hw, eave_y, hd * side)
		var e := Vector3(-hw, eave_y, hd * side)
		var n := (b - a).cross(e - a).normalized()
		if n.y < 0:
			n = -n
		var uv_a := Vector2(-hw / tile, 0)
		var uv_b := Vector2(hw / tile, 0)
		var uv_c := Vector2(hw / tile, slope_len / tile)
		var uv_e := Vector2(-hw / tile, slope_len / tile)
		var quad := [[a, uv_a], [b, uv_b], [c, uv_c], [a, uv_a], [c, uv_c], [e, uv_e]]
		if side < 0:
			quad = [[a, uv_a], [c, uv_c], [b, uv_b], [a, uv_a], [e, uv_e], [c, uv_c]]
		for v in quad:
			st.set_normal(n)
			st.set_uv(v[1])
			st.add_vertex(v[0])
		# underside (dark, reversed)
		var under := [quad[0], quad[2], quad[1], quad[3], quad[5], quad[4]]
		for v in under:
			st.set_normal(-n)
			st.set_uv(v[1])
			st.add_vertex(v[0] + Vector3(0, -0.08, 0))
	st.generate_tangents()
	return st.commit()


func _roof_material(key: String) -> Material:
	var m := Mats.pbr("roof", Color.WHITE, 1.0, false, key)
	m.uv1_triplanar = false
	m.uv1_scale = Vector3.ONE
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# ================================================================ castle
func _build_castle() -> void:
	var castle := _node(props, "Castle", Vector3.ZERO)
	var stone := Mats.get_mat("stone_wall")
	var slate := Mats.get_mat("roof_slate")
	var wall_h := 6.5
	var th := 2.0
	var x_front := 48.0
	var x_back := 66.0
	var z_min := -6.0
	var z_max := 28.0
	var gate_z0 := 8.5
	var gate_z1 := 13.5
	# walls
	_wall(castle, Vector3(x_front, 0, z_min), Vector3(x_front, 0, gate_z0), wall_h, th, stone)
	_wall(castle, Vector3(x_front, 0, gate_z1), Vector3(x_front, 0, z_max), wall_h, th, stone)
	_wall(castle, Vector3(x_front, 0, z_min), Vector3(x_back, 0, z_min), wall_h, th, stone)
	_wall(castle, Vector3(x_front, 0, z_max), Vector3(x_back, 0, z_max), wall_h, th, stone)
	_wall(castle, Vector3(x_back, 0, z_min), Vector3(x_back, 0, z_max), wall_h, th, stone)
	# gate lintel + dark passage
	_box(castle, Vector3(x_front, wall_h - 1.0, 11.0), Vector3(th + 0.4, 2.0, gate_z1 - gate_z0 + 0.4), stone)
	_box(castle, Vector3(x_front + 1.2, 2.6, 11.0), Vector3(2.0, 5.2, gate_z1 - gate_z0), Mats.flat(Color(0.03, 0.025, 0.02), 1.0))
	for i in 7:
		_box(castle, Vector3(x_front - 0.6, 4.6, gate_z0 + 0.5 + i * 0.66), Vector3(0.12, 1.6, 0.12), Mats.get_mat("metal_dark"))
	_box(castle, Vector3(x_front - 0.6, 4.0, 11.0), Vector3(0.14, 0.14, gate_z1 - gate_z0), Mats.get_mat("metal_dark"))
	# open doors
	_box(castle, Vector3(x_front - 0.2, 2.3, gate_z0 - 0.3), Vector3(2.2, 4.6, 0.25), Mats.get_mat("wood_dark"), Vector3(0, 70, 0))
	_box(castle, Vector3(x_front - 0.2, 2.3, gate_z1 + 0.3), Vector3(2.2, 4.6, 0.25), Mats.get_mat("wood_dark"), Vector3(0, -70, 0))
	# merlons over the gate
	for i in 5:
		_box(castle, Vector3(x_front - 0.7, wall_h + 0.45, gate_z0 + 0.5 + i * 1.1), Vector3(0.7, 0.9, 0.6), stone)
	# towers
	_tower(castle, Vector3(x_front, 0, gate_z0 - 1.6), 2.3, 10.5, slate)
	_tower(castle, Vector3(x_front, 0, gate_z1 + 1.6), 2.3, 10.5, slate)
	for p in [Vector3(x_front, 0, z_min), Vector3(x_front, 0, z_max), Vector3(x_back, 0, z_min), Vector3(x_back, 0, z_max)]:
		_tower(castle, p, 2.7, 11.5, slate)
	# keep
	var keep := Vector3(58.5, 0, 11.0)
	_box(castle, keep + Vector3(0, 6.0, 0), Vector3(9.0, 12.0, 11.0), stone)
	for i in 8:
		_box(castle, keep + Vector3(-4.4, 12.45, -5.0 + i * 1.43), Vector3(0.6, 0.9, 0.7), stone)
		_box(castle, keep + Vector3(4.4, 12.45, -5.0 + i * 1.43), Vector3(0.6, 0.9, 0.7), stone)
	for i in 6:
		_box(castle, keep + Vector3(-3.6 + i * 1.44, 12.45, -5.4), Vector3(0.7, 0.9, 0.6), stone)
		_box(castle, keep + Vector3(-3.6 + i * 1.44, 12.45, 5.4), Vector3(0.7, 0.9, 0.6), stone)
	_tower(castle, keep + Vector3(1.5, 0, -3.0), 2.3, 19.0, slate)
	# glowing keep windows
	for i in 3:
		_box(castle, keep + Vector3(-4.52, 8.0, -3.0 + i * 3.0), Vector3(0.1, 1.4, 0.6), Mats.get_mat("window_glow"))
	# banners on gatehouse and keep
	_banner(castle, Vector3(x_front - 1.3, wall_h - 2.4, gate_z0 - 1.6 - 2.35), Vector2(1.3, 3.2), "banner_red", -90)
	_banner(castle, Vector3(x_front - 1.3, wall_h - 2.4, gate_z1 + 1.6 + 2.35), Vector2(1.3, 3.2), "banner_red", -90)
	_banner(castle, keep + Vector3(-4.62, 7.5, 0.8), Vector2(2.0, 5.0), "banner_blue", -90)
	# gate torches
	for z in [gate_z0 - 0.4, gate_z1 + 0.4]:
		var t := Vector3(x_front - 1.25, 3.6, z)
		_box(castle, t + Vector3(0.2, -0.3, 0), Vector3(0.4, 0.12, 0.12), Mats.get_mat("metal_dark"))
		_fire(castle, t, 1.0)
		_light(castle, t + Vector3(-0.8, 0.2, 0), Color(1.0, 0.6, 0.28), 2.5, 10.0, true, false)
	# a couple of rooftops inside the walls for silhouette
	var roof_m := _roof_material("roof_red")
	for p in [Vector3(53.0, 0, 0.0), Vector3(53.0, 0, 22.0), Vector3(62.0, 0, 23.0)]:
		_box(castle, p + Vector3(0, 2.0, 0), Vector3(4.0, 4.0, 3.2), Mats.get_mat("plaster"))
		_mesh(castle, _roof_mesh(4.0, 3.2, 1.8, 0.35), roof_m, p + Vector3(0, 4.0, 0))
	add_blocker(Vector3(57, 0, 11), 14.0)


func _wall(parent: Node3D, a: Vector3, b: Vector3, h: float, th: float, mat: Material) -> void:
	var mid := (a + b) * 0.5
	var len := a.distance_to(b)
	var along_x: bool = abs(b.x - a.x) > abs(b.z - a.z)
	var size := Vector3(len, h, th) if along_x else Vector3(th, h, len)
	_box(parent, mid + Vector3(0, h * 0.5, 0), size, mat)
	# walkway ledge + merlons
	var n := int(len / 1.25)
	for i in n:
		var t := (i + 0.5) / n
		var p := a.lerp(b, t)
		var outer := Vector3(0, 0, -th * 0.4) if along_x else Vector3(-th * 0.4, 0, 0)
		if along_x and a.z > 10.0:
			outer = Vector3(0, 0, th * 0.4)
		if not along_x and a.x > 60.0:
			outer = Vector3(th * 0.4, 0, 0)
		var msize := Vector3(0.7, 0.9, 0.5) if along_x else Vector3(0.5, 0.9, 0.7)
		_box(parent, p + outer + Vector3(0, h + 0.45, 0), msize, mat)


func _tower(parent: Node3D, base: Vector3, r: float, h: float, roof: Material) -> void:
	var stone := Mats.get_mat("stone_wall")
	_cyl(parent, base + Vector3(0, h * 0.5, 0), r, r * 1.08, h, stone, 24)
	_cyl(parent, base + Vector3(0, h + 0.2, 0), r + 0.35, r + 0.25, 0.4, stone, 24)
	var merlons := 10
	for i in merlons:
		var a := TAU * i / merlons
		var p := base + Vector3(cos(a) * (r + 0.15), h + 0.85, sin(a) * (r + 0.15))
		_box(parent, p, Vector3(0.6, 0.9, 0.6), stone, Vector3(0, -rad_to_deg(a), 0))
	_mesh(parent, ModelBuilder.cone(r + 0.55, r * 1.9, 20), roof, base + Vector3(0, h + 0.4 + r * 0.95, 0))
	# flag
	var top := base + Vector3(0, h + 0.4 + r * 1.9, 0)
	_cyl(parent, top + Vector3(0, 0.8, 0), 0.04, 0.05, 1.8, Mats.get_mat("wood_dark"), 6)
	_banner(parent, top + Vector3(0.0, 1.25, 0.55), Vector2(1.0, 0.7), "banner_red", 90)
	# arrow slits
	for i in 3:
		var a2 := PI + (i - 1) * 0.5
		_box(parent, base + Vector3(cos(a2) * (r * 1.04), h * 0.55, sin(a2) * (r * 1.04)), Vector3(0.12, 1.0, 0.12),
			Mats.flat(Color(0.03, 0.03, 0.03), 1.0))


# ================================================================ spawn portal
func _build_portal() -> void:
	var done: Array = []
	for pts in all_path_points:
		var p0: Vector2 = pts[0]
		if done.any(func(q): return (q as Vector2).distance_to(p0) < 4.0):
			continue
		done.append(p0)
		_portal_at(Vector3(p0.x + 3.0, 0.0, p0.y))


func _portal_at(ppos: Vector3) -> void:
	var pnode := _node(props, "SpawnGate", ppos, 0)
	var dark := Mats.get_mat("rock_dark")
	for z in [-4.2, 4.2]:
		_box(pnode, Vector3(0, 3.5, z), Vector3(1.6, 7.0, 1.6), dark, Vector3(0, 0, 3.0 * sign(z)))
		_box(pnode, Vector3(0, 0.4, z), Vector3(2.4, 0.8, 2.4), dark)
	_box(pnode, Vector3(0, 7.4, 0), Vector3(2.0, 1.2, 10.4), dark, Vector3(4, 0, 0))
	_box(pnode, Vector3(0, 8.3, -2.0), Vector3(1.2, 0.8, 1.5), dark, Vector3(0, 0, 20))
	var q := QuadMesh.new()
	q.size = Vector2(7.6, 7.0)
	var portal := _mesh(pnode, q, Mats.get_mat("portal"), Vector3(0.1, 3.5, 0), Vector3(0, 90, 0), Vector3.ONE, false)
	portal.name = "Portal"
	_light(pnode, Vector3(3.0, 3.0, 0), Color(0.5, 0.25, 1.0), 4.0, 14.0, true, false)
	var mist := FX.make_particles({
		"one_shot": false, "amount": 30, "lifetime": 2.5, "direction": Vector3(1, 0.3, 0), "spread": 40.0,
		"vel_min": 0.5, "vel_max": 1.5, "gravity": Vector3(0, 0.2, 0), "size_min": 0.6, "size_max": 1.4,
		"box": Vector3(0.5, 3.0, 3.5), "scale_start": 0.5, "scale_end": 1.5,
		"colors": [Color(0.4, 0.2, 0.8, 0.0), Color(0.35, 0.2, 0.7, 0.5), Color(0.1, 0.6, 0.3, 0.0)],
	})
	mist.position = Vector3(0.5, 3.5, 0)
	pnode.add_child(mist)
	mist.emitting = true
	# rubble & dead stumps
	for i in 8:
		var p := Vector3(rng.randf_range(-3, 4), 0, rng.randf_range(-7, 7))
		if abs(p.z) < 3.5 and p.x > -1:
			continue
		_mesh(pnode, _rock_mesh(i % 4), dark, p, Vector3(0, rng.randf() * 360, 0), Vector3.ONE * rng.randf_range(0.4, 1.0))
	add_blocker(ppos, 6.0)


# ================================================================ village
func _build_village() -> void:
	var houses := [
		[Vector3(-38, 0, -6), 15.0, "roof_red"], [Vector3(-40, 0, 8), -10.0, "roof_slate"],
		[Vector3(-15, 0, 4), 80.0, "roof_red"], [Vector3(-16, 0, -12), 0.0, "roof_slate"],
		[Vector3(7, 0, 4), -15.0, "roof_red"], [Vector3(6, 0, 23), 5.0, "roof_slate"],
		[Vector3(30, 0, 3), 90.0, "roof_red"], [Vector3(31, 0, -12), 20.0, "roof_slate"],
		[Vector3(34, 0, 24), -8.0, "roof_red"], [Vector3(-36, 0, 23), 30.0, "roof_red"],
		[Vector3(-2, 0, -24), 0.0, "roof_red"], [Vector3(-44, 0, -24), 10.0, "roof_slate"],
	]
	var hi := 0
	for h in houses:
		var pos: Vector3 = h[0]
		if path_distance(pos) < 7.0 or is_blocked(pos, 3.0) or near_water(pos, 4.0):
			continue
		var w := rng.randf_range(4.2, 5.6)
		var d := rng.randf_range(3.4, 4.2)
		var ht := rng.randf_range(2.6, 3.4)
		_house(pos, h[1], w, d, ht, h[2], hi % 2 == 0)
		add_blocker(pos, max(w, d) * 0.6 + 0.6)
		# yard clutter
		var fwd := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(h[1]))
		var side := fwd.cross(Vector3.UP)
		var yard := pos + fwd * (d * 0.5 + 2.0)
		if path_distance(yard) > 4.0:
			match hi % 3:
				0:
					_barrel(yard + side * 1.5)
					_barrel(yard + side * 2.3 + fwd * 0.4)
				1:
					_crate(yard - side * 1.8)
					_hay(yard + side * 2.0)
				2:
					_crate(yard + side * 2.0)
					_barrel(yard - side * 2.0)
		if hi % 2 == 1:
			_fence(pos - side * (w * 0.5 + 1.8) - fwd * (d * 0.5 + 1.0), pos - side * (w * 0.5 + 1.8) + fwd * (d * 0.5 + 2.5))
		hi += 1
	# village well
	var well := Vector3(-33, 0, 1.5)
	if path_distance(well) > 4.0 and not near_water(well, 3.0):
		_cyl(props, well + Vector3(0, 0.5, 0), 1.0, 1.1, 1.0, Mats.get_mat("stone_wall"))
		_cyl(props, well + Vector3(0, 0.98, 0), 0.8, 0.8, 0.06, Mats.flat(Color(0.05, 0.08, 0.1), 0.1))
		for s in [-1, 1]:
			_box(props, well + Vector3(0.9 * s, 1.6, 0), Vector3(0.15, 2.2, 0.15), Mats.get_mat("wood_dark"))
		_mesh(props, _roof_mesh(2.4, 1.6, 0.7, 0.2), _roof_material("roof_red"), well + Vector3(0, 2.7, 0), Vector3(0, 90, 0))
		add_blocker(well, 1.6)
	# farm fields with fences near the spawn side
	_fence(Vector3(-44, 0, -9), Vector3(-44, 0, 2))
	_fence(Vector3(-22, 0, 25), Vector3(-10, 0, 25.5))
	_fence(Vector3(24, 0, -26), Vector3(38, 0, -24))


func _house(pos: Vector3, rot_y: float, w: float, d: float, h: float, roof_key: String, chimney: bool) -> void:
	var hn := _node(props, "House", pos, rot_y)
	var beam := Mats.get_mat("wood_dark")
	_box(hn, Vector3(0, 0.3, 0), Vector3(w + 0.3, 0.6, d + 0.3), Mats.get_mat("stone_wall"))
	_box(hn, Vector3(0, 0.6 + h * 0.5, 0), Vector3(w, h, d), Mats.get_mat("plaster"))
	var top := 0.6 + h
	# timber frame
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(hn, Vector3(sx * w * 0.5, 0.6 + h * 0.5, sz * d * 0.5), Vector3(0.24, h, 0.24), beam)
	for sz in [-1, 1]:
		_box(hn, Vector3(0, top - 0.1, sz * (d * 0.5 + 0.02)), Vector3(w + 0.1, 0.2, 0.14), beam)
		_box(hn, Vector3(0, 0.6 + h * 0.45, sz * (d * 0.5 + 0.02)), Vector3(w, 0.16, 0.12), beam)
		for k in [-1, 1]:
			_box(hn, Vector3(k * w * 0.3, 0.6 + h * 0.72, sz * (d * 0.5 + 0.03)), Vector3(0.14, h * 0.6, 0.1), beam, Vector3(0, 0, 38 * k))
	for sx in [-1, 1]:
		_box(hn, Vector3(sx * (w * 0.5 + 0.02), top - 0.1, 0), Vector3(0.14, 0.2, d + 0.1), beam)
	# gable ends
	var rise := d * 0.55
	for sx in [-1, 1]:
		var g := _mesh(hn, ModelBuilder.box(Vector3(0.1, 1, 1)), Mats.get_mat("plaster"), Vector3(sx * w * 0.5, top + rise * 0.5, 0))
		g.mesh = _gable_prism(d, rise)
		g.position = Vector3(sx * w * 0.5, top, 0)
	_mesh(hn, _roof_mesh(w, d, rise, 0.45), _roof_material(roof_key), Vector3(0, top, 0))
	# door & windows (front = +Z)
	_box(hn, Vector3(w * 0.2, 0.6 + 0.95, d * 0.5 + 0.03), Vector3(0.95, 1.9, 0.08), Mats.get_mat("wood"))
	_box(hn, Vector3(w * 0.2, 0.6 + 1.95, d * 0.5 + 0.05), Vector3(1.15, 0.14, 0.12), beam)
	for x in [-w * 0.22]:
		_box(hn, Vector3(x, 0.6 + h * 0.6, d * 0.5 + 0.02), Vector3(0.7, 0.6, 0.06), Mats.get_mat("window_glow"))
		_box(hn, Vector3(x - 0.5, 0.6 + h * 0.6, d * 0.5 + 0.06), Vector3(0.3, 0.7, 0.05), Mats.get_mat("wood"), Vector3(0, 25, 0))
		_box(hn, Vector3(x + 0.5, 0.6 + h * 0.6, d * 0.5 + 0.06), Vector3(0.3, 0.7, 0.05), Mats.get_mat("wood"), Vector3(0, -25, 0))
	_box(hn, Vector3(0, 0.6 + h * 0.6, -d * 0.5 - 0.02), Vector3(0.7, 0.6, 0.06), Mats.get_mat("window_glow"))
	if chimney:
		var c := Vector3(-w * 0.3, top + rise * 0.6, -d * 0.15)
		_box(hn, c, Vector3(0.6, rise * 1.4 + 0.6, 0.6), Mats.get_mat("stone_wall"))
		var sm := FX.smoke_emitter(1.0)
		sm.position = c + Vector3(0, rise * 0.7 + 0.5, 0)
		hn.add_child(sm)
		sm.emitting = true


func _gable_prism(d: float, rise: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hd := d * 0.5
	for sx in [-0.05, 0.05]:
		var nx := Vector3(sign(sx), 0, 0)
		var tri := [Vector3(sx, 0, -hd), Vector3(sx, rise, 0), Vector3(sx, 0, hd)]
		if sx > 0:
			tri = [tri[0], tri[2], tri[1]]
		for v in tri:
			st.set_normal(nx)
			st.set_uv(Vector2(v.z, v.y))
			st.add_vertex(v)
	return st.commit()


func _barrel(p: Vector3) -> void:
	if is_blocked(p, 0.5) or path_distance(p) < 3.5:
		return
	var b := _node(props, "Barrel", p, rng.randf() * 360)
	_mesh(b, ModelBuilder.cyl(0.38, 0.38, 1.0, 16), Mats.get_mat("wood_obj"), Vector3(0, 0.5, 0))
	_mesh(b, ModelBuilder.sphere(0.44, 16), Mats.get_mat("wood_obj"), Vector3(0, 0.5, 0), Vector3.ZERO, Vector3(1, 1.05, 1))
	for y in [0.18, 0.82]:
		_mesh(b, ModelBuilder.torus(0.4, 0.45), Mats.get_mat("metal_dark"), Vector3(0, y, 0))
	add_blocker(p, 0.5)


func _crate(p: Vector3) -> void:
	if is_blocked(p, 0.5) or path_distance(p) < 3.5:
		return
	_box(props, p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), Mats.get_mat("wood"), Vector3(0, rng.randf() * 90, 0))
	if rng.randf() < 0.5:
		_box(props, p + Vector3(0.1, 1.2, 0.05), Vector3(0.6, 0.6, 0.6), Mats.get_mat("wood"), Vector3(0, rng.randf() * 90, 0))
	add_blocker(p, 0.6)


func _hay(p: Vector3) -> void:
	if is_blocked(p, 0.7) or path_distance(p) < 3.5:
		return
	_mesh(props, ModelBuilder.cyl(0.65, 0.65, 1.3, 18), Mats.get_mat("hay"), p + Vector3(0, 0.65, 0), Vector3(0, rng.randf() * 180, 90))
	add_blocker(p, 0.8)


func _fence(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	var n := int(len / 2.0) + 1
	var dir := (b - a).normalized()
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	for i in n:
		var p := a.lerp(b, float(i) / max(1, n - 1))
		if path_distance(p) < 3.2:
			continue
		_box(props, p + Vector3(0, 0.55, 0), Vector3(0.14, 1.1, 0.14), Mats.get_mat("wood_dark"), Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4)))
		if i < n - 1:
			var q := a.lerp(b, (i + 0.5) / max(1, n - 1))
			if path_distance(q) < 3.2:
				continue
			var seg_len: float = len / maxi(1, n - 1)
			for y in [0.45, 0.85]:
				_box(props, q + Vector3(0, y, 0), Vector3(0.07, 0.1, seg_len + 0.1), Mats.get_mat("wood"), Vector3(0, yaw, 0))
			add_blocker(q, 0.6)
		add_blocker(p, 0.4)


# ================================================================ torches along the road
func _build_torches() -> void:
	for pi in curves.size():
		_torches_along(pi)


func _torches_along(pi: int) -> void:
	var d := 14.0
	var side := 1.0
	var spacing := 11.0 if is_dark else 16.0
	while d < length_of(pi) - 8.0:
		var p := sample_on(pi, d)
		var dir := dir_on(pi, d)
		var perp := Vector3(-dir.z, 0, dir.x) * side
		var tp := p + perp * 3.1
		if path_distance(tp) > 2.8 and not is_blocked(tp, 0.6) and BUILD_RECT.has_point(Vector2(tp.x, tp.z)) and not near_water(tp, 1.0):
			_torch_post(tp)
		d += spacing
		side = -side


func _torch_post(p: Vector3) -> void:
	var t := _node(props, "TorchPost", p)
	_mesh(t, ModelBuilder.cyl(0.07, 0.1, 2.2, 8), Mats.get_mat("wood_dark"), Vector3(0, 1.1, 0))
	_mesh(t, ModelBuilder.cyl(0.16, 0.1, 0.25, 8), Mats.get_mat("metal_dark"), Vector3(0, 2.25, 0))
	_fire(t, Vector3(0, 2.45, 0), 1.0)
	_light(t, Vector3(0, 2.7, 0), Color(1.0, 0.58, 0.26), 2.6 if is_dark else 1.8, 11.0 if is_dark else 9.0, true, false)
	add_blocker(p, 0.5)
	light_points.append(Vector2(p.x, p.z))


# ================================================================ rocks
var _rock_meshes: Array = []


func _rock_mesh(variant: int) -> ArrayMesh:
	if _rock_meshes.is_empty():
		for v in 4:
			_rock_meshes.append(_make_rock(v))
	return _rock_meshes[variant % _rock_meshes.size()]


func _make_rock(seed_v: int) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 20
	sm.rings = 12
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var n := FastNoiseLite.new()
	n.seed = 100 + seed_v * 17
	n.frequency = 0.9
	n.fractal_octaves = 3
	var stretch := Vector3(1.0 + seed_v * 0.15, 0.7 + (seed_v % 2) * 0.2, 0.9)
	for i in verts.size():
		var v := verts[i]
		var d := 1.0 + n.get_noise_3dv(v * 1.3) * 0.45
		v = v * d * stretch
		if v.y < -0.25:
			v.y = -0.25 + (v.y + 0.25) * 0.2
		verts[i] = v
	# smooth normals merged across UV seams
	var acc := {}
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]
		var b := verts[idx[t + 1]]
		var c := verts[idx[t + 2]]
		var fn := (c - a).cross(b - a)
		for k in 3:
			var key := _vkey(verts[idx[t + k]])
			acc[key] = acc.get(key, Vector3.ZERO) + fn
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	for i in verts.size():
		var nn: Vector3 = acc.get(_vkey(verts[i]), Vector3.UP)
		norms[i] = nn.normalized()
		if norms[i].dot(verts[i]) < 0:
			norms[i] = -norms[i]
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


func _vkey(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0))


func _build_rocks() -> void:
	var rock := Mats.get_mat("rock")
	var placed := 0
	var tries := 0
	while placed < 34 and tries < 600:
		tries += 1
		var p := Vector3(rng.randf_range(-62, 66), 0, rng.randf_range(-36, 36))
		var big := rng.randf() < 0.3
		var s := rng.randf_range(1.0, 1.9) if big else rng.randf_range(0.3, 0.8)
		if path_distance(p) < 3.5 + s or is_blocked(p, s) or CASTLE_RECT.grow(2).has_point(Vector2(p.x, p.z)) or near_water(p, s + 0.5):
			continue
		var mi := _mesh(props, _rock_mesh(placed), rock, p + Vector3(0, s * 0.15, 0), Vector3(rng.randf_range(-10, 10), rng.randf() * 360, 0), Vector3.ONE * s)
		mi.name = "Rock"
		if BUILD_RECT.has_point(Vector2(p.x, p.z)):
			add_blocker(p, s * 0.9)
		placed += 1
	# boulders on the hills
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(70, 95)
		var p2 := Vector3(cos(a) * r * 1.1 + 3.0, 0, sin(a) * r * 0.75)
		p2.y = height_at(p2.x, p2.z)
		var s2 := rng.randf_range(1.5, 4.0)
		_mesh(props, _rock_mesh(i), Mats.get_mat("rock"), p2, Vector3(rng.randf_range(-15, 15), rng.randf() * 360, 0), Vector3.ONE * s2)


# ================================================================ trees
var _tree_meshes: Array = []


func _tube(st: SurfaceTool, a: Vector3, b: Vector3, ra: float, rb: float, segs: int = 8) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.RIGHT if abs(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var u := axis.cross(ref).normalized()
	var v := axis.cross(u).normalized()
	var len := a.distance_to(b)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := u * cos(a0) + v * sin(a0)
		var d1 := u * cos(a1) + v * sin(a1)
		var quad := [
			[a + d0 * ra, d0, Vector2(float(i) / segs, 0)], [b + d0 * rb, d0, Vector2(float(i) / segs, len)],
			[b + d1 * rb, d1, Vector2(float(i + 1) / segs, len)], [a + d0 * ra, d0, Vector2(float(i) / segs, 0)],
			[b + d1 * rb, d1, Vector2(float(i + 1) / segs, len)], [a + d1 * ra, d1, Vector2(float(i + 1) / segs, 0)],
		]
		for q in quad:
			st.set_normal(q[1])
			st.set_uv(q[2])
			st.add_vertex(q[0])


func _card(st: SurfaceTool, center: Vector3, right: Vector3, up: Vector3, sphere_c: Vector3, shade: float) -> void:
	var corners := [center - right - up, center + right - up, center + right + up, center - right + up]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for k in [0, 1, 2, 0, 2, 3]:
		var p: Vector3 = corners[k]
		var n := (p - sphere_c).normalized()
		n = (n + Vector3.UP * 0.3).normalized()
		var h: float = clamp((p.y - sphere_c.y) * 0.25 + 0.75, 0.45, 1.1) * shade
		st.set_color(Color(h, h, h))
		st.set_normal(n)
		st.set_uv(uvs[k])
		st.add_vertex(p)


func _make_oak(variant: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 500 + variant
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := r.randf_range(2.6, 3.4)
	var lean := Vector3(r.randf_range(-0.3, 0.3), 0, r.randf_range(-0.3, 0.3))
	_tube(bark, Vector3(0, -0.2, 0), Vector3(0, h * 0.5, 0) + lean * 0.5, 0.36, 0.26, 10)
	_tube(bark, Vector3(0, h * 0.5, 0) + lean * 0.5, Vector3(0, h, 0) + lean, 0.26, 0.18, 10)
	var canopy_c := Vector3(0, h + 1.5, 0) + lean
	for i in 4:
		var a := TAU * i / 4.0 + r.randf() * 0.5
		var tip := canopy_c + Vector3(cos(a) * 1.3, r.randf_range(-0.2, 0.6), sin(a) * 1.3)
		_tube(bark, Vector3(0, h * 0.8, 0) + lean * 0.8, tip, 0.12, 0.04, 6)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blobs := 7
	for bi in blobs:
		var bc := canopy_c + Vector3(r.randf_range(-1.3, 1.3), r.randf_range(-0.6, 1.2), r.randf_range(-1.3, 1.3))
		var shade := r.randf_range(0.8, 1.05)
		for ci in 13:
			var c := bc + Vector3(r.randf_range(-0.7, 0.7), r.randf_range(-0.5, 0.6), r.randf_range(-0.7, 0.7))
			var nrm := Vector3(r.randf_range(-1, 1), r.randf_range(-0.6, 1), r.randf_range(-1, 1)).normalized()
			var right := nrm.cross(Vector3.UP if abs(nrm.y) < 0.95 else Vector3.RIGHT).normalized()
			var up := right.cross(nrm).normalized()
			var s := r.randf_range(0.9, 1.3)
			_card(leaves, c, right * s, up * s, canopy_c, shade)
	var mesh := bark.commit()
	leaves.commit(mesh)
	mesh.surface_set_material(0, Mats.get_mat("bark"))
	mesh.surface_set_material(1, Mats.get_mat("leaves"))
	return mesh


func _make_pine(variant: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 900 + variant
	var bark := SurfaceTool.new()
	bark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := r.randf_range(6.5, 8.0)
	_tube(bark, Vector3(0, -0.2, 0), Vector3(0, h, 0), 0.28, 0.05, 8)
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := 8
	for ti in tiers:
		var t := float(ti) / (tiers - 1)
		var y: float = lerp(1.4, h - 0.3, t)
		var rad: float = lerp(2.3, 0.45, t) * r.randf_range(0.9, 1.1)
		var count := 7 if ti < tiers - 2 else 5
		var off := r.randf() * TAU
		for k in count:
			var a := off + TAU * k / count
			var outward := Vector3(cos(a), 0, sin(a))
			var droop := rad * 0.35
			var base := Vector3(0, y + 0.15, 0)
			var tip := Vector3(0, y - droop, 0) + outward * rad
			var side := outward.cross(Vector3.UP).normalized()
			var w := rad * 0.55
			var quad := [
				[base - side * w * 0.2, Vector2(0.4, 1.0)], [base + side * w * 0.2, Vector2(0.6, 1.0)],
				[tip + side * w, Vector2(1.0, 0.0)], [tip - side * w, Vector2(0.0, 0.0)],
			]
			var shade := 0.6 + t * 0.4
			for idx in [0, 1, 2, 0, 2, 3]:
				var p: Vector3 = quad[idx][0]
				var n := ((p - Vector3(0, y - 0.8, 0)).normalized() + Vector3.UP * 0.5).normalized()
				var hsh: float = clamp(shade * (0.75 + (p - base).length() / rad * 0.35), 0.4, 1.1)
				leaves.set_color(Color(hsh, hsh, hsh))
				leaves.set_normal(n)
				leaves.set_uv(quad[idx][1])
				leaves.add_vertex(p)
	var mesh := bark.commit()
	leaves.commit(mesh)
	mesh.surface_set_material(0, Mats.get_mat("bark"))
	mesh.surface_set_material(1, Mats.get_mat("needles"))
	return mesh


func _build_trees() -> void:
	for v in 3:
		_tree_meshes.append(_make_oak(v))
	for v in 2:
		_tree_meshes.append(_make_pine(v))
	var tints: Array = theme.get("leaf_tints", [Color.WHITE])
	# scattered trees inside the battlefield
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 800:
		tries += 1
		var p := Vector3(rng.randf_range(-58, 44), 0, rng.randf_range(-34, 34))
		if path_distance(p) < 5.5 or is_blocked(p, 2.0) or CASTLE_RECT.grow(3).has_point(Vector2(p.x, p.z)) or near_water(p, 2.5):
			continue
		_place_tree(p, rng.randi() % 5, tints)
		placed += 1
	# dense forest ring around the flat area
	for i in 260:
		var p2 := Vector3(rng.randf_range(-105, 105), 0, rng.randf_range(-80, 80))
		var inside := FLAT_RECT.grow(-3.0).has_point(Vector2(p2.x, p2.z))
		if inside or near_water(p2, 3.0):
			continue
		var near_gate := false
		for pts2 in all_path_points:
			var g: Vector2 = pts2[0]
			if abs(p2.z - g.y) < 7 and p2.x < g.x + 1 and p2.x > g.x - 19:
				near_gate = true
		if near_gate:
			continue
		p2.y = height_at(p2.x, p2.z) - 0.2
		_place_tree(p2, 3 + rng.randi() % 2 if rng.randf() < 0.65 else rng.randi() % 3, tints)


func _place_tree(p: Vector3, variant: int, tints: Array) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _tree_meshes[variant]
	mi.position = p
	mi.rotation.y = rng.randf() * TAU
	mi.scale = Vector3.ONE * rng.randf_range(0.85, 1.35)
	mi.layers = 2
	foliage.add_child(mi)
	mi.set_instance_shader_parameter("tint", tints[rng.randi() % tints.size()])
	if p.y <= 0.01:
		add_blocker(p, 1.4)


# ================================================================ bushes
func _make_bush(variant: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 1300 + variant
	var leaves := SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Vector3(0, 0.55, 0)
	for i in 26:
		var p := c + Vector3(r.randf_range(-0.8, 0.8), r.randf_range(-0.3, 0.45), r.randf_range(-0.8, 0.8))
		var nrm := Vector3(r.randf_range(-1, 1), r.randf_range(-0.3, 1), r.randf_range(-1, 1)).normalized()
		var right := nrm.cross(Vector3.UP if abs(nrm.y) < 0.95 else Vector3.RIGHT).normalized()
		var up := right.cross(nrm).normalized()
		var sz := r.randf_range(0.55, 0.8)
		_card(leaves, p, right * sz, up * sz, c - Vector3(0, 0.4, 0), r.randf_range(0.75, 1.0))
	var mesh := leaves.commit()
	mesh.surface_set_material(0, Mats.get_mat("leaves"))
	return mesh


func _build_bushes() -> void:
	var meshes := [_make_bush(0), _make_bush(1), _make_bush(2)]
	var tints: Array = theme.get("leaf_tints", [Color.WHITE])
	var placed := 0
	var tries := 0
	while placed < 70 and tries < 900:
		tries += 1
		var p := Vector3(rng.randf_range(-62, 66), 0, rng.randf_range(-37, 37))
		if path_distance(p) < 5.0 or is_blocked(p, 1.0) or CASTLE_RECT.grow(2).has_point(Vector2(p.x, p.z)) or near_water(p, 1.5):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[placed % meshes.size()]
		mi.position = p
		mi.rotation.y = rng.randf() * TAU
		mi.scale = Vector3.ONE * rng.randf_range(0.8, 1.5)
		mi.layers = 2
		foliage.add_child(mi)
		mi.set_instance_shader_parameter("tint", tints[rng.randi() % tints.size()])
		if BUILD_RECT.has_point(Vector2(p.x, p.z)):
			add_blocker(p, 0.8)
		placed += 1


# ================================================================ grass
func _grass_tuft() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for b in 5:
		var a := r.randf() * TAU
		var base := Vector3(cos(a), 0, sin(a)) * r.randf_range(0.0, 0.22)
		var h := r.randf_range(0.28, 0.55)
		var w := r.randf_range(0.035, 0.055)
		var face := r.randf() * TAU
		var side := Vector3(cos(face), 0, sin(face))
		var bend := Vector3(-side.z, 0, side.x) * r.randf_range(0.05, 0.18)
		var n := Vector3(-side.z, 0.5, side.x).normalized()
		var p0l := base - side * w
		var p0r := base + side * w
		var p1l := base + bend * 0.35 + Vector3(0, h * 0.5, 0) - side * w * 0.7
		var p1r := base + bend * 0.35 + Vector3(0, h * 0.5, 0) + side * w * 0.7
		var tip := base + bend + Vector3(0, h, 0)
		var verts := [[p0l, 0.0], [p0r, 0.0], [p1r, 0.5], [p0l, 0.0], [p1r, 0.5], [p1l, 0.5], [p1l, 0.5], [p1r, 0.5], [tip, 1.0]]
		for v in verts:
			st.set_normal(n)
			st.set_uv(Vector2(0.5, v[1]))
			st.add_vertex(v[0])
	return st.commit()


func _build_grass() -> void:
	var tuft := _grass_tuft()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/grass.gdshader")
	mat.set_shader_parameter("macro_noise", Mats.tex("macro_noise"))
	mat.set_shader_parameter("root_color", theme.get("blade_root", Color(0.09, 0.15, 0.035)))
	mat.set_shader_parameter("tip_color", theme.get("blade_tip", Color(0.24, 0.36, 0.08)))
	var chunk := 16.0
	var spacing := 0.62
	var area := FLAT_RECT.grow(-1.0)
	var cx0 := int(floor(area.position.x / chunk))
	var cx1 := int(ceil(area.end.x / chunk))
	var cz0 := int(floor(area.position.y / chunk))
	var cz1 := int(ceil(area.end.y / chunk))
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	var dens := FastNoiseLite.new()
	dens.seed = 9
	dens.frequency = 0.06
	for cz in range(cz0, cz1):
		for cx in range(cx0, cx1):
			var xforms: Array[Transform3D] = []
			var x := cx * chunk
			while x < (cx + 1) * chunk:
				var z := cz * chunk
				while z < (cz + 1) * chunk:
					var p := Vector3(x + r.randf_range(0, spacing), 0, z + r.randf_range(0, spacing))
					z += spacing
					if not area.has_point(Vector2(p.x, p.z)):
						continue
					var d := path_distance(p)
					if d < ROAD_HALF_WIDTH + 0.2 + r.randf() * 0.8:
						continue
					if not river.is_empty() and near_water(p, 0.3):
						continue
					if CASTLE_RECT.has_point(Vector2(p.x, p.z)) or (p.x > 37 and p.x < 49 and p.z > 5.5 and p.z < 16.5):
						continue
					if dens.get_noise_2d(p.x, p.z) < -0.35:
						continue
					var s := r.randf_range(0.7, 1.35)
					var b := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.8, 1.2), s))
					xforms.append(Transform3D(b, p))
				x += spacing
			if xforms.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = tuft
			mm.instance_count = xforms.size()
			for i in xforms.size():
				mm.set_instance_transform(i, xforms[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = mat
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.layers = 1
			foliage.add_child(mmi)
