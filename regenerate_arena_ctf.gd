extends "res://ArenaStage.gd"
## Builds levels/ArenaCtfLevel.tscn - Flag Hill, the capture-the-flag arena (ArenaGame.gd, kind "ctf"): a round valley
## about 450m across on a summer afternoon, the flag on a mesa in the middle (four ramps up it, boost pads at their
## feet, pop bumpers on top) and five bases round it on a ring, each on ground of its own:
##   A  Hilltop (north): a broad hill 16m up, gentle all round.
##   B  The Bowl (east): sunk 9m into the ground.
##   C  The Island (south-east): a plateau 11m up with a cliff and a trench toward the middle, a long slope up from
##      the side, and a launch fan (ArenaFan.gd) in front of the trench that throws a car across onto it.
##   D  The Tower (south-west): a concrete deck 16m up on pillars, a long ramp up to it, a launch fan below the far edge.
##   E  Bumper Garden (west): level ground ringed by pop bumpers (ArenaBumper.gd) with two ways in.
## Wooden kickers and launch fans on the ways between, item boxes, rocks and trees, the valley's sides rising steep
## past the ring road. The ground is one heightfield (`_h`) on a 2m grid (HeightMapShape3D, "ArenaGround": track,
## grass), painted by arena_ground.gdshader from its vertex colours (grass, rock, the dirt tracks along the bots'
## graph, sand in the trench).
##
## The bots' graph (ArenaGame's metas "nav_points", "nav_links"): a ring of points round the valley, the mesa's top
## and its ramps' feet, each base and its ways up (the fans one way), laid on the ground's height (`_h`) or the decks.

const HALF := 270.0
const STEP := 2.0
const PLAY_R := 228.0
const MESA_TOP := 9.0
const MESA_R := 34.0
const BASE_RING := 160.0
const HILL_H := 16.0
const ISLAND_H := 11.0
const ISLAND_RING := 172.0
const TOWER_H := 16.0
const LETTERS := ["A", "B", "C", "D", "E"]
const ANGLES := [-90.0, -18.0, 54.0, 126.0, 198.0]

var noise := FastNoiseLite.new()
var base_at: Array = []
var _isl_t := Vector2.ZERO
var _isl_in := Vector2.ZERO
var _tow_t := Vector2.ZERO
var nav_pts := PackedVector3Array()
var nav_links := PackedInt32Array()
var _decks: Array = []


func _configure() -> void:
	level_name = "ArenaCtfLevel"
	level_path = "res://levels/ArenaCtfLevel.tscn"
	stem = "arena_ctf"


func _soft(d: float, a: float, b: float) -> float:
	var t := clampf((d - a) / (b - a), 0.0, 1.0)
	return lerpf(t, smoothstep(0.0, 1.0, t), 0.4)


## The ground's height at (x, z).
func _h(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var r := p.length()
	var h := 2.4 + 2.0 * noise.get_noise_2d(x, z)
	# The mesa and its four ramps.
	var mesa := MESA_TOP * (1.0 - smoothstep(MESA_R, MESA_R + 14.0, r))
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		var along := p.dot(d)
		var lat := absf(p.dot(Vector2(-d.y, d.x)))
		if along > MESA_R - 4.0:
			var ramp := MESA_TOP * (1.0 - _soft(along, MESA_R, MESA_R + 50.0))
			mesa = maxf(mesa, ramp * (1.0 - smoothstep(7.0, 11.0, lat)))
	h = maxf(h, mesa)
	# A: the hill.
	var da := p.distance_to(base_at[0])
	h = maxf(h, HILL_H * (1.0 - _soft(da, 22.0, 108.0)) + 1.5)
	# B: the bowl.
	var db := p.distance_to(base_at[1])
	h -= 9.0 * (1.0 - _soft(db, 24.0, 76.0))
	# C: the island, its cliff and trench toward the middle, its long slope from the side.
	var dc := p.distance_to(base_at[2])
	if dc < 110.0:
		var dirv: Vector2 = (p - (base_at[2] as Vector2)) / maxf(dc, 0.01)
		# A cliff all round but for one lane up the back (along _isl_t), a trench round the cliff's foot that rises
		# into the lane (the way out for a car that falls in).
		var w_back := smoothstep(0.72, 0.9, dirv.dot(_isl_t))
		var back := ISLAND_H * (1.0 - _soft(dc, 22.0, 92.0))
		var cliff := ISLAND_H * (1.0 - smoothstep(22.0, 25.5, dc))
		h = maxf(h, lerpf(cliff, back, w_back) + 1.0)
		h -= 6.5 * (1.0 - w_back) * smoothstep(23.0, 27.0, dc) * (1.0 - smoothstep(37.0, 44.0, dc))
	# E: level ground for the bumper garden.
	var de := p.distance_to(base_at[4])
	h = lerpf(h, 2.2, 1.0 - smoothstep(30.0, 46.0, de))
	# The valley's sides.
	h += 52.0 * smoothstep(PLAY_R, PLAY_R + 36.0, r) + 30.0 * smoothstep(PLAY_R + 36.0, HALF, r)
	return h


## Where the bases stand, the island's and the tower's axes (also used by scratch/arena_ctf_map.gd).
func setup_layout() -> void:
	noise.seed = 31337
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	base_at.clear()
	for i in 5:
		var a := deg_to_rad(float(ANGLES[i]))
		# The island stands further out, its moat clear of the ring road.
		var rr := ISLAND_RING if i == 2 else BASE_RING
		base_at.append(Vector2(cos(a), sin(a)) * rr)
	var cdir: Vector2 = (base_at[2] as Vector2).normalized()
	_isl_in = -cdir
	_isl_t = Vector2(-cdir.y, cdir.x)
	var ddir: Vector2 = (base_at[3] as Vector2).normalized()
	_tow_t = Vector2(ddir.y, -ddir.x)


func _build(level: Node3D) -> void:
	setup_layout()
	game.set("kind", "ctf")
	game.set("match_seconds", 360.0)
	game.set("win_score", 300)
	_environment({
		"sky_top": Color(0.24, 0.45, 0.8), "sky_horizon": Color(0.78, 0.86, 0.94), "haze": Color(0.8, 0.86, 0.92),
		"ground_bottom": Color(0.4, 0.45, 0.38), "sun_color": Color(1.0, 0.96, 0.88), "sun_glow": 0.5,
		"cloud_lit": Color(1, 1, 0.98), "cloud_shade": Color(0.66, 0.7, 0.8), "cloud_coverage": 0.38,
		"ambient": 0.6, "exposure": 1.05, "glow": 0.3, "bloom": 0.04,
		"fog_begin": 250.0, "fog_end": 1800.0, "fog_sky": 0.05,
		"sun_pitch": -48.0, "sun_yaw": 35.0, "sun_energy": 1.3, "shadow_distance": 300.0,
	})
	var world := Node3D.new()
	world.name = "World"
	level.add_child(world)
	_plan_nav()
	_build_ground(world)
	_build_mesa(world)
	_build_bases(world)
	_build_tower(world)
	_build_island_fan(world)
	_build_garden(world)
	_build_ways(world)
	_build_boundary(world)
	_build_trees(world)
	_spawns()
	var outline: Array = []
	var ring := PackedVector2Array()
	for k in 64:
		var a := k * TAU / 64.0
		ring.append(Vector2(cos(a), sin(a)) * PLAY_R)
	outline.append(ring)
	var m := PackedVector2Array()
	for k in 24:
		var a := k * TAU / 24.0
		m.append(Vector2(cos(a), sin(a)) * (MESA_R + 4.0))
	outline.append(m)
	game.set_meta(&"outline", outline)
	game.set_meta(&"nav_points", nav_pts)
	game.set_meta(&"nav_links", nav_links)
	print("  flag hill: %d nav points, %d links" % [nav_pts.size(), nav_links.size() / 3])


# ======================================================================================
#  The bots' graph
# ======================================================================================

func _nav(x: float, z: float, y := INF) -> int:
	nav_pts.append(Vector3(x, (_h(x, z) if y == INF else y) + 0.6, z))
	return nav_pts.size() - 1


func _link(a: int, b: int, one_way := false) -> void:
	nav_links.append(a)
	nav_links.append(b)
	nav_links.append(1 if one_way else 0)


func _nearest_of(ids: Array, p: Vector2) -> int:
	var best := -1
	var bd := INF
	for i in ids:
		var q: Vector3 = nav_pts[i]
		var d := Vector2(q.x, q.z).distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best


var _ring_ids: Array = []
var _base_ids: Array = []
var _tower_top := -1


func _plan_nav() -> void:
	var top := _nav(0.0, 0.0)
	var feet: Array = []
	for d in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
		var mid := _nav(d.x * 50.0, d.y * 50.0)
		var foot := _nav(d.x * 92.0, d.y * 92.0)
		_link(top, mid)
		_link(mid, foot)
		feet.append(foot)
	# The ring road between the mesa and the bases, every 20 degrees.
	for k in 18:
		var a := k * TAU / 18.0
		var p := Vector2(cos(a), sin(a)) * 118.0
		# Round the island's trench and the bowl's rim.
		_ring_ids.append(_nav(p.x, p.y))
	for k in 18:
		_link(_ring_ids[k], _ring_ids[(k + 1) % 18])
	for f in feet:
		var q: Vector3 = nav_pts[f]
		_link(f, _nearest_of(_ring_ids, Vector2(q.x, q.z)))
	# A: up the hill from the ring.
	var a_id := _nav(base_at[0].x, base_at[0].y)
	_link(a_id, _nearest_of(_ring_ids, base_at[0]))
	# B: down into the bowl.
	var b_id := _nav(base_at[1].x, base_at[1].y)
	_link(b_id, _nearest_of(_ring_ids, base_at[1]))
	# C: the island: up its slope from the side (two ways), the fan one way.
	var c_id := _nav(base_at[2].x, base_at[2].y)
	var c_mid: Vector2 = base_at[2] + _isl_t * 50.0
	var c_foot: Vector2 = base_at[2] + _isl_t * 95.0
	var cm := _nav(c_mid.x, c_mid.y)
	var cf := _nav(c_foot.x, c_foot.y)
	_link(c_id, cm)
	_link(cm, cf)
	_link(cf, _nearest_of(_ring_ids, c_foot))
	var fan_at: Vector2 = base_at[2] + _isl_in * 50.0
	var c_fan := _nav(fan_at.x, fan_at.y)
	_link(c_fan, _nearest_of(_ring_ids, fan_at))
	_link(c_fan, c_id, true)
	# D: the tower: the ramp's foot, the deck; the fan under the far edge one way.
	var d_c: Vector2 = base_at[3]
	_tower_top = _nav(d_c.x, d_c.y, TOWER_H)
	var d_ramp_top: Vector2 = d_c + _tow_t * 13.0
	var d_foot: Vector2 = d_c + _tow_t * (14.0 + TOWER_RAMP)
	var drt := _nav(d_ramp_top.x, d_ramp_top.y, TOWER_H)
	var dft := _nav(d_foot.x, d_foot.y)
	_link(_tower_top, drt)
	_link(drt, dft)
	_link(dft, _nearest_of(_ring_ids, d_foot))
	var dfan: Vector2 = d_c - _tow_t * 24.0
	var d_fan := _nav(dfan.x, dfan.y)
	_link(d_fan, _nearest_of(_ring_ids, dfan))
	_link(d_fan, _tower_top, true)
	# E: in through the garden's gaps (toward the middle and round the side).
	var e_id := _nav(base_at[4].x, base_at[4].y)
	_link(e_id, _nearest_of(_ring_ids, base_at[4]))
	_base_ids = [a_id, b_id, c_id, _tower_top, e_id]


const TOWER_RAMP := 84.0


# ======================================================================================
#  The ground
# ======================================================================================

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _build_ground(world: Node3D) -> void:
	var n := int(HALF * 2.0 / STEP) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = _h(-HALF + i * STEP, -HALF + j * STEP)
	# The dirt tracks: the graph's links on the ground (not the fans', not the decks').
	var segs: Array = []
	var k := 0
	while k + 2 < nav_links.size():
		if nav_links[k + 2] == 0:
			var a := nav_pts[nav_links[k]]
			var b := nav_pts[nav_links[k + 1]]
			if a.y < 30.0 and b.y < 30.0 and not (absf(a.y - TOWER_H - 0.6) < 0.01 or absf(b.y - TOWER_H - 0.6) < 0.01):
				segs.append([Vector2(a.x, a.z), Vector2(b.x, b.z)])
		k += 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var x := -HALF + i * STEP
			var z := -HALF + j * STEP
			var y: float = heights[j * n + i]
			var hl: float = heights[j * n + maxi(i - 1, 0)]
			var hr: float = heights[j * n + mini(i + 1, n - 1)]
			var hu: float = heights[maxi(j - 1, 0) * n + i]
			var hd: float = heights[mini(j + 1, n - 1) * n + i]
			var nrm := Vector3(hl - hr, 2.0 * STEP, hu - hd).normalized()
			var p := Vector2(x, z)
			var dirt := 0.0
			for s in segs:
				var d := _seg_dist(p, s[0], s[1])
				if d < 9.0:
					dirt = maxf(dirt, 1.0 - smoothstep(4.0, 8.5, d))
			for b in base_at:
				dirt = maxf(dirt, 1.0 - smoothstep(12.0, 18.0, p.distance_to(b)))
			dirt = maxf(dirt, 1.0 - smoothstep(MESA_R - 4.0, MESA_R, p.length()))
			var sand := 1.0 - smoothstep(-2.0, 0.5, y)
			var rock := smoothstep(PLAY_R + 4.0, PLAY_R + 20.0, p.length()) * 0.7
			st.set_normal(nrm)
			st.set_color(Color(1.0, rock, dirt * 0.85, sand))
			st.add_vertex(Vector3(x, y, z))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	var mesh := st.commit()
	var body := StaticBody3D.new()
	body.name = "ArenaGround"
	body.set_meta(&"surface", "grass")
	body.add_to_group(&"track_surface", true)
	world.add_child(body)
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	hm.map_data = heights
	cs.shape = _save_res(hm, "ground_shape")
	cs.scale = Vector3(STEP, 1.0, STEP)
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "GroundMesh"
	mi.mesh = _save_res(mesh, "ground_mesh")
	var sm := ShaderMaterial.new()
	sm.shader = load("res://arena_ground.gdshader")
	sm.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	sm.set_shader_parameter("rock_tex", load("res://materials/dark_canyon_rock.png"))
	sm.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	mi.material_override = _save_res(sm, "ground_material")
	body.add_child(mi)
	print("  ground %dx%d (%.1fs)" % [n, n, (Time.get_ticks_msec() - t0) * 0.001])


# ======================================================================================
#  The middle, the bases, the tower, the fans, the garden
# ======================================================================================

func _build_mesa(world: Node3D) -> void:
	var fs := Marker3D.new()
	fs.name = "FlagSpawn"
	fs.position = Vector3(0, _h(0, 0) + 0.1, 0)
	game.add_child(fs)
	# A round plinth under the flag, flush with the mesa.
	cyl(world, 6.0, 6.4, 0.3, Transform3D(Basis(), Vector3(0, _h(0, 0) + 0.08, 0)), mat("plinth", Color(0.9, 0.9, 0.92), 0.5), 40)
	for k in 3:
		var a := k * TAU / 3.0 + PI / 6.0
		var p := Vector2(cos(a), sin(a)) * 17.0
		bumper(world, "MesaBumper%d" % k, Transform3D(Basis(), Vector3(p.x, _h(p.x, p.y), p.y)), 2.0, 0.0, Color(1.0, 0.3, 0.75), 18.0)
	for d in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
		var at: Vector2 = d * 96.0
		boost_pad(world, "RampBoost_%d_%d" % [int(d.x), int(d.y)], Vector3(at.x, _h(at.x, at.y), at.y), Vector3(0, 0, 0))
		item_spot(Vector3(d.x * 26.0, _h(d.x * 26.0, d.y * 26.0), d.y * 26.0))


func _build_bases(world: Node3D) -> void:
	var bases := Node3D.new()
	bases.name = "Bases"
	game.add_child(bases)
	var pad := tex_mat("pad", "res://materials/concrete.png", Color(0.75, 0.76, 0.8), 4.0, 0.6)
	for i in 5:
		var p: Vector2 = base_at[i]
		var y := _h(p.x, p.y) if i != 3 else TOWER_H
		var b := Node3D.new()
		b.name = "Base_%s" % LETTERS[i]
		b.set_meta(&"letter", LETTERS[i])
		b.position = Vector3(p.x, y, p.y)
		bases.add_child(b)
		if i != 3:
			cyl(world, 9.5, 10.0, 0.24, Transform3D(Basis(), Vector3(p.x, y + 0.04, p.y)), pad, 48)
		# Item boxes on the way out of each base.
		var out := p.normalized()
		var q := p - out * 30.0
		item_spot(Vector3(q.x, _h(q.x, q.y), q.y))


func _build_tower(world: Node3D) -> void:
	var c: Vector2 = base_at[3]
	var conc := tex_mat("concrete", "res://materials/concrete.png", Color(0.7, 0.71, 0.74), 5.0, 0.7)
	var stripe := mat("hazard", Color(1.0, 0.75, 0.1), 0.5, 0.0, 0.6)
	var t3 := Vector3(_tow_t.x, 0, _tow_t.y)
	var deck_b := Basis.looking_at(-t3, Vector3.UP)
	# The deck: 28m square, its top at TOWER_H.
	box(world, "TowerDeck", Vector3(28, 1.2, 28), Transform3D(deck_b, Vector3(c.x, TOWER_H - 0.6, c.y)), conc, "asphalt", true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var off := deck_b * Vector3(sx * 10.0, 0, sz * 10.0)
			var g := _h(c.x + off.x, c.y + off.z)
			box(world, "TowerPillar", Vector3(2.2, TOWER_H - g, 2.2), Transform3D(Basis(), Vector3(c.x + off.x, (TOWER_H + g) * 0.5 - 0.6, c.y + off.z)), conc, "rock")
	# Kerbs round the deck except where the ramp joins (+t side).
	for side in [[Vector3(0, 0, -1), 28.0], [Vector3(-1, 0, 0), 28.0], [Vector3(1, 0, 0), 28.0]]:
		var n: Vector3 = side[0]
		var at := deck_b * (n * 13.6)
		var size := Vector3(28.0, 0.9, 0.8) if n.z != 0.0 else Vector3(0.8, 0.9, 28.0)
		box(world, "TowerKerb", size, Transform3D(deck_b, Vector3(c.x + at.x, TOWER_H + 0.45, c.y + at.z)), stripe, "rock")
	# The ramp: from the deck's edge along t down to the ground.
	var top := Vector3(c.x, TOWER_H, c.y) + t3 * 14.0
	var foot2: Vector2 = c + _tow_t * (14.0 + TOWER_RAMP)
	var foot := Vector3(foot2.x, _h(foot2.x, foot2.y) - 0.15, foot2.y)
	var along := foot - top
	var length := along.length()
	var fwd := along.normalized()
	var right := Vector3.UP.cross(-fwd).normalized()
	var up := (-fwd).cross(right).normalized()
	var rb := Basis(right, up, -fwd)
	var mid := (top + foot) * 0.5 - up * 0.6
	box(world, "TowerRamp", Vector3(12, 1.2, length + 1.0), Transform3D(rb, mid), conc, "asphalt", true)
	for sx in [-1.0, 1.0]:
		box(world, "TowerRampKerb", Vector3(0.6, 0.9, length), Transform3D(rb, mid + right * sx * 6.3 + up * 1.05), stripe, "rock")
	# Pillars under the ramp.
	for k in range(1, 5):
		var p := top.lerp(foot, k / 5.0)
		var g := _h(p.x, p.z)
		if p.y - g > 2.5:
			box(world, "RampPillar", Vector3(1.6, p.y - g, 1.6), Transform3D(Basis(), Vector3(p.x, (p.y + g) * 0.5 - 0.8, p.z)), conc, "rock")
	# The launch fan under the far edge, throwing onto the deck.
	var fan_at: Vector2 = c - _tow_t * 24.0
	var fy := _h(fan_at.x, fan_at.y)
	var tf := fan(world, "TowerFan", facing(Vector3(fan_at.x, fy, fan_at.y), Vector3(c.x, fy, c.y)), 48.0, 0.0, 3.6, Color(1.0, 0.6, 0.2))
	tf.set("land_at", Vector3(0, TOWER_H - fy, -26.0))
	var lab := Label3D.new()
	lab.text = "TOWER"
	lab.font_size = 200
	lab.pixel_size = 0.03
	lab.modulate = Color(1, 0.85, 0.4)
	lab.transform = Transform3D(rb.rotated(rb.x, 0.0), top + up * 3.0 - fwd * 2.0)
	lab.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	world.add_child(lab)


func _build_island_fan(world: Node3D) -> void:
	var c: Vector2 = base_at[2]
	var at: Vector2 = c + _isl_in * 50.0
	var y := _h(at.x, at.y)
	var f := fan(world, "IslandFan", facing(Vector3(at.x, y, at.y), Vector3(c.x, y, c.y)), 46.0, 0.0, 3.6, Color(0.3, 1.0, 0.6))
	f.set("land_at", Vector3(0, _h(c.x + _isl_in.x * 12.0, c.y + _isl_in.y * 12.0) - y, -38.0))


func _build_garden(world: Node3D) -> void:
	var c: Vector2 = base_at[4]
	var to_mid := -c.normalized()
	for k in 12:
		var a := k * TAU / 12.0
		var dir := Vector2(cos(a), sin(a))
		# Two gaps: toward the middle and round to the north.
		if dir.dot(to_mid) > 0.85 or dir.dot(Vector2(to_mid.y, -to_mid.x)) > 0.85:
			continue
		var p := c + dir * 24.0
		bumper(world, "GardenBumper%d" % k, Transform3D(Basis(), Vector3(p.x, _h(p.x, p.y), p.y)), 2.2, 0.0,
			[Color(1.0, 0.3, 0.75), Color(1.0, 0.8, 0.2), Color(0.3, 0.9, 1.0)][k % 3], 19.0)
	for k in 3:
		var a := k * TAU / 3.0
		var p := c + Vector2(cos(a), sin(a)) * 13.0
		bumper(world, "GardenPop%d" % k, Transform3D(Basis(), Vector3(p.x, _h(p.x, p.y), p.y)), 1.4, 0.0, Color(0.6, 1.0, 0.3), 16.0)


## Wooden kickers and fans along the ways between the middle and the bases; boost pads; item boxes on the ring.
func _build_ways(world: Node3D) -> void:
	for spec in [[Vector2(0, -124), Vector2(0, -170)], [Vector2(95, -30), Vector2(140, -45)], [Vector2(-95, -30), Vector2(-140, -45)],
			[Vector2(-40, 100), Vector2(-70, 140)]]:
		var a: Vector2 = spec[0]
		var b: Vector2 = spec[1]
		kicker(world, "Kicker_%d_%d" % [int(a.x), int(a.y)], Vector3(a.x, _h(a.x, a.y), a.y), Vector3(b.x, 0, b.y), 9.0, 2.2, 10.0, 0.45)
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var p := Vector2(cos(a), sin(a)) * 132.0
		item_spot(Vector3(p.x, _h(p.x, p.y), p.y))
	# Two fans in the open, straight up, for the fun of it.
	for p in [Vector2(70, 70), Vector2(-70, -70)]:
		fan(world, "OpenFan", Transform3D(Basis(), Vector3(p.x, _h(p.x, p.y), p.y)), 30.0, 0.0, 3.2)


func _build_boundary(world: Node3D) -> void:
	# An invisible fence past the ring where the valley's sides steepen.
	for k in 48:
		var a := (k + 0.5) * TAU / 48.0
		var p := Vector2(cos(a), sin(a)) * (PLAY_R + 14.0)
		var size := Vector3(2.0 * (PLAY_R + 14.0) * tan(PI / 48.0) + 1.0, 40.0, 1.0)
		box(world, "Fence%d" % k, size, facing(Vector3(p.x, _h(p.x, p.y) + 18.0, p.y), Vector3.ZERO), null, "rock", false, false)
	# Rocks round the bases and the valley's edge.
	var rock := tex_mat("rock", "res://materials/dark_canyon_rock.png", Color(0.75, 0.7, 0.64), 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for k in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(PLAY_R - 6.0, PLAY_R + 10.0)
		var p := Vector2(cos(a), sin(a)) * r
		var s := rng.randf_range(2.0, 5.0)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = s
		sm.height = s * 1.3
		sm.radial_segments = 7
		sm.rings = 4
		mi.mesh = sm
		mi.material_override = rock
		mi.transform = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, rng.randf_range(0.6, 1.0), rng.randf_range(0.8, 1.3))),
			Vector3(p.x, _h(p.x, p.y) + s * 0.2, p.y))
		mi.name = "Rock%d" % k
		world.add_child(mi)


func _build_trees(world: Node3D) -> void:
	var trunk_m := mat("trunk", Color(0.36, 0.26, 0.18), 0.9)
	var leaf_m := mat("leaf", Color(0.2, 0.42, 0.18), 0.85)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.4
	trunk.height = 4.0
	trunk.radial_segments = 6
	trunk.material = trunk_m
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 3.2
	crown.height = 9.0
	crown.radial_segments = 8
	crown.material = leaf_m
	var xt: Array = []
	var xc: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 520:
		var a := rng.randf() * TAU
		var r := rng.randf_range(PLAY_R + 18.0, HALF - 10.0)
		var p := Vector2(cos(a), sin(a)) * r
		var y := _h(p.x, p.y)
		var s := rng.randf_range(0.8, 1.5)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		xt.append(Transform3D(b, Vector3(p.x, y + 2.0 * s, p.y)))
		xc.append(Transform3D(b, Vector3(p.x, y + 7.5 * s, p.y)))
	for pair in [["TreeTrunks", trunk, xt], ["TreeCrowns", crown, xc]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[1]
		mm.instance_count = (pair[2] as Array).size()
		# Written by hand: headless, set_instance_transform keeps nothing.
		var buf := PackedFloat32Array()
		buf.resize(mm.instance_count * 12)
		for i in mm.instance_count:
			var t: Transform3D = pair[2][i]
			var o := i * 12
			buf[o] = t.basis.x.x
			buf[o + 1] = t.basis.y.x
			buf[o + 2] = t.basis.z.x
			buf[o + 3] = t.origin.x
			buf[o + 4] = t.basis.x.y
			buf[o + 5] = t.basis.y.y
			buf[o + 6] = t.basis.z.y
			buf[o + 7] = t.origin.y
			buf[o + 8] = t.basis.x.z
			buf[o + 9] = t.basis.y.z
			buf[o + 10] = t.basis.z.z
			buf[o + 11] = t.origin.z
		mm.buffer = buf
		var mmi := MultiMeshInstance3D.new()
		mmi.name = pair[0]
		mmi.multimesh = _save_res(mm, String(pair[0]).to_lower())
		world.add_child(mmi)


## The spawns: in teams red (even) south of the mesa, blue (odd) north, facing it; all against all the same six.
func _spawns() -> void:
	for i in 6:
		var row := i / 2
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var x := (row - 1) * 14.0
		var z := sgn * 104.0
		spawn(Vector3(x, _h(x, z) + 0.6, z), Vector3(0, 0, 0))
