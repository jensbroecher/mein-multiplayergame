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
## Wooden kickers and launch fans on the ways between, item boxes. The ground is one heightfield (`_h`) on a 2m grid
## (HeightMapShape3D, "ArenaGround": track, grass), painted by arena_ground.gdshader from its vertex colours (how
## open the ground is, rock, the dirt tracks along the bots' graph, sand in the trench).
##
## The country (the user found the first version bare: a brown bowl wall with cones for trees): past the play area's
## edge (`PLAY_R`, the invisible fence `FENCE_OUT` on) the ground rises as a rocky bank into wooded hills and, far
## off, ranges (`_side`); the heightfield carries it to the square's edge and a ring of ground (`_build_backdrop`,
## "BackdropGround": the same function and shader, rings of squares growing out to `BACK_R`) carries it on. Woods
## (`_build_woods`, WoodlandBuilder's spruce, fir, larch, birch, oak and lime, near meshes crossfading to stand-ins,
## under a JungleDetail) cover the hills, in groves inside the play area too, hazel at their edges; the far stand-ins
## alone run on over the ranges' feet. Granite boulders (`_build_boulders`, Lakeside's) lie along the bank, crop out
## of the hills and sit by the groves. Meadow grass (`_build_meadow`, MeadowGrass.gd as on Lakeside Meadows) grows
## wherever the ground is open: shorter in the play area, none on the tracks, pads, sand and rock or under anything.
## Everything that grows or lies inside the fence keeps off what is driven (`_plan_clear`, `_clear_d`): the bots'
## graph, the bases, the mesa and its ramps (nothing within `OPEN_R` of the middle), the kickers' and fans' flights.
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
const FENCE_OUT := 14.0
## Nothing grows within this of the middle (the mesa, its ramps, the spawns, the open fans).
const OPEN_R := 108.0
const BACK_R := 1750.0
const BACK_SEGS := 90
## The woods: 3D trees out to `WOODS_R`, the far stand-ins alone on to `FAR_WOODS_R`; cells of `FOREST_CELL`.
const WOODS_R := 440.0
const FAR_WOODS_R := 860.0
const FOREST_CELL := 96.0
const FAR_CELL := 320.0
const TREE_KINDS := ["spruce", "fir", "larch", "birch", "oak", "lime"]
## The kickers: [toe, toward].
const KICKERS := [[Vector2(0, -124), Vector2(0, -170)], [Vector2(95, -30), Vector2(140, -45)], [Vector2(-95, -30), Vector2(-140, -45)],
	[Vector2(-40, 100), Vector2(-70, 140)]]
const MEADOW_STEP := 0.5

const Woodland = preload("res://WoodlandBuilder.gd")
const MeadowGrass = preload("res://MeadowGrass.gd")
const PropKit = preload("res://PropKit.gd")
const ANGLES := [-90.0, -18.0, 54.0, 126.0, 198.0]

var noise := FastNoiseLite.new()
var bump := FastNoiseLite.new()
var roll := FastNoiseLite.new()
var ridge := FastNoiseLite.new()
var grove := FastNoiseLite.new()
var crop := FastNoiseLite.new()
## What is driven: [a, b, radius] in plan (`_plan_clear`).
var _clear: Array = []
var _heights := PackedFloat32Array()
var _n := 0
## Each ground vertex's dirt and how open it is (1 meadow .. 0 under trees).
var _dirt := PackedFloat32Array()
var _woodv := PackedFloat32Array()
var _ground_mat: ShaderMaterial
## Footprints the meadow leaves bare: [x, z, radius].
var _stamps: Array = []
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
	var h := 2.4 + 2.0 * noise.get_noise_2d(x, z) + 0.2 * bump.get_noise_2d(x, z)
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
	return h + _side(p, r)


## The country past the play area's edge: a bank (the fence stands on it), wooded hills rolling up behind it, and
## from about 170m out the ranges, their ridges cut by `ridge`.
func _side(p: Vector2, r: float) -> float:
	var s := r - PLAY_R
	if s <= 0.0:
		return 0.0
	var ro := roll.get_noise_2d(p.x, p.y)
	var bank := (13.0 + 5.0 * ro) * smoothstep(0.0, 30.0, s)
	var hills := (32.0 + 26.0 * ro) * smoothstep(12.0, 200.0, s)
	var ri := 1.0 - absf(ridge.get_noise_2d(p.x, p.y))
	var ranges := (50.0 + 250.0 * pow(ri, 2.4)) * smoothstep(170.0, 1050.0, s) * (0.72 + 0.28 * ro)
	return bank + hills + ranges


## Where the bases stand, the island's and the tower's axes (also used by scratch/arena_ctf_map.gd).
func setup_layout() -> void:
	noise.seed = 31337
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	bump.seed = 31338
	bump.frequency = 0.07
	bump.fractal_octaves = 2
	roll.seed = 31339
	roll.frequency = 0.0026
	roll.fractal_octaves = 4
	ridge.seed = 31340
	ridge.frequency = 0.0011
	ridge.fractal_octaves = 4
	grove.seed = 31341
	grove.frequency = 0.011
	grove.fractal_octaves = 2
	crop.seed = 31342
	crop.frequency = 0.021
	crop.fractal_octaves = 2
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
		"fog_begin": 320.0, "fog_end": 2600.0, "fog_sky": 0.05,
		"sun_pitch": -48.0, "sun_yaw": 35.0, "sun_energy": 1.3, "shadow_distance": 300.0,
	})
	var world := Node3D.new()
	world.name = "World"
	level.add_child(world)
	_plan_nav()
	_plan_clear()
	_build_ground(world)
	_build_backdrop(world)
	_build_mesa(world)
	_build_bases(world)
	_build_tower(world)
	_build_island_fan(world)
	_build_garden(world)
	_build_ways(world)
	_build_boundary(world)
	_build_boulders(world)
	_build_woods(world)
	_build_meadow(world)
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


## What is driven, in plan: the graph's links, the bases, the tower's ramp, the fans' and kickers' flights, the item
## boxes on the ring. Nothing that grows or lies inside the fence comes nearer than each one's radius.
func _plan_clear() -> void:
	var k := 0
	while k + 2 < nav_links.size():
		var a := nav_pts[nav_links[k]]
		var b := nav_pts[nav_links[k + 1]]
		_clear.append([Vector2(a.x, a.z), Vector2(b.x, b.z), 15.0])
		k += 3
	for i in 5:
		_clear.append([base_at[i], base_at[i], 62.0 if i == 2 else 42.0])
	var d_c: Vector2 = base_at[3]
	_clear.append([d_c, d_c + _tow_t * (24.0 + TOWER_RAMP), 16.0])
	_clear.append([d_c - _tow_t * 42.0, d_c, 14.0])
	var c_c: Vector2 = base_at[2]
	_clear.append([c_c + _isl_in * 64.0, c_c, 14.0])
	for spec in KICKERS:
		var a2: Vector2 = spec[0]
		var dir: Vector2 = ((spec[1] as Vector2) - a2).normalized()
		_clear.append([a2 - dir * 14.0, a2 + dir * 85.0, 11.0])
	for i in 6:
		var a3 := i * TAU / 6.0 + 0.3
		var q := Vector2(cos(a3), sin(a3)) * 132.0
		_clear.append([q, q, 8.0])


## How far `p` is clear of everything driven (negative: on it). Inside OPEN_R nothing is clear.
func _clear_d(p: Vector2) -> float:
	var best := p.length() - OPEN_R
	for c in _clear:
		if best < -1.0:
			return best
		best = minf(best, _seg_dist(p, c[0], c[1]) - float(c[2]))
	return best


## How wooded the ground is at `p` (0 open meadow .. 1 forest): groves in the play area's outer ring, clear of what
## is driven; past the fence forest nearly everywhere, thinning on the high ranges.
func _woods(p: Vector2, y: float) -> float:
	var r := p.length()
	if r < OPEN_R:
		return 0.0
	var g := smoothstep(-0.05, 0.4, grove.get_noise_2d(p.x, p.y))
	if r < PLAY_R + FENCE_OUT:
		var inside := g * smoothstep(0.0, 7.0, _clear_d(p))
		return lerpf(inside, maxf(inside, 0.55 + 0.45 * g), smoothstep(PLAY_R - 6.0, PLAY_R + FENCE_OUT, r))
	var w := 0.55 + 0.45 * g
	return w * (1.0 - smoothstep(175.0, 265.0, y + 40.0 * (g - 0.5)))


## Bare rock at `p`: outcrops on the bank and the hills (the shader adds every steep face), the ranges' heads.
func _rock(p: Vector2, y: float) -> float:
	var s := p.length() - PLAY_R
	if s <= 0.0:
		return 0.0
	var c := smoothstep(0.32, 0.6, crop.get_noise_2d(p.x, p.y))
	return clampf(0.85 * c * smoothstep(0.0, 14.0, s) + smoothstep(190.0, 300.0, y + 50.0 * c), 0.0, 1.0)


## The ground's colour data at `p`: r how open (1 meadow, 0 under trees), g rock, b the dirt tracks, a sand.
func _paint(p: Vector2, y: float, dirt: float) -> Color:
	var sand := 1.0 - smoothstep(-2.0, 0.5, y)
	return Color(1.0 - _woods(p, y), _rock(p, y), dirt * 0.85, sand)


func _dirt_at(p: Vector2, segs: Array) -> float:
	if p.length() > PLAY_R:
		return 0.0
	var dirt := 0.0
	for sg in segs:
		var d := _seg_dist(p, sg[0], sg[1])
		if d < 9.0:
			dirt = maxf(dirt, 1.0 - smoothstep(4.0, 8.5, d))
	for b in base_at:
		dirt = maxf(dirt, 1.0 - smoothstep(12.0, 18.0, p.distance_to(b)))
	return maxf(dirt, 1.0 - smoothstep(MESA_R - 4.0, MESA_R, p.length()))


func _build_ground(world: Node3D) -> void:
	var n := int(HALF * 2.0 / STEP) + 1
	_n = n
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = _h(-HALF + i * STEP, -HALF + j * STEP)
	_heights = heights
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
	_dirt.resize(n * n)
	_woodv.resize(n * n)
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
			var dirt := _dirt_at(p, segs)
			var col := _paint(p, y, dirt)
			_dirt[j * n + i] = dirt
			_woodv[j * n + i] = col.r
			st.set_normal(nrm)
			st.set_color(col)
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
	sm.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	_ground_mat = _save_res(sm, "ground_material")
	mi.material_override = _ground_mat
	body.add_child(mi)
	print("  ground %dx%d (%.1fs)" % [n, n, (Time.get_ticks_msec() - t0) * 0.001])


## The country past the heightfield's square, to BACK_R: rings of squares (BACK_SEGS a side) growing outward, in the
## ground's own material. The first ring lies a little under the heightfield six metres inside its edge, the second
## just under its edge, so the two overlap with no crack; nothing drives out here (the fence).
func _build_backdrop(world: Node3D) -> void:
	var halves: Array = [HALF - 6.0, HALF, HALF + 6.0]
	while float(halves[-1]) < BACK_R:
		halves.append(float(halves[-1]) * 1.075 + 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var per := BACK_SEGS * 4
	for ri in halves.size():
		var half: float = halves[ri]
		var under := 0.7 if ri == 0 else (0.14 if ri == 1 else 0.0)
		var e := maxf(half * 2.0 / BACK_SEGS * 0.5, 2.0)
		for q in per:
			var side := q / BACK_SEGS
			var t := float(q % BACK_SEGS) / BACK_SEGS * 2.0 - 1.0
			var p := Vector2.ZERO
			match side:
				0:
					p = Vector2(t, -1.0)
				1:
					p = Vector2(1.0, t)
				2:
					p = Vector2(-t, 1.0)
				_:
					p = Vector2(-1.0, -t)
			p *= half
			var y := _h(p.x, p.y)
			var nrm := Vector3(_h(p.x - e, p.y) - _h(p.x + e, p.y), 2.0 * e, _h(p.x, p.y - e) - _h(p.x, p.y + e)).normalized()
			st.set_normal(nrm)
			st.set_color(_paint(p, y, 0.0))
			st.add_vertex(Vector3(p.x, y - under, p.y))
	for ri in halves.size() - 1:
		for q in per:
			var a := ri * per + q
			var b := ri * per + (q + 1) % per
			var c := a + per
			var d := b + per
			# Wound to face up: Godot's front faces look along (c - a) x (b - a).
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	var mi := MeshInstance3D.new()
	mi.name = "BackdropGround"
	mi.mesh = _save_res(st.commit(), "backdrop_mesh")
	mi.material_override = _ground_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	print("  backdrop: %d rings to %.0fm (%.1fs)" % [halves.size(), float(halves[-1]), (Time.get_ticks_msec() - t0) * 0.001])


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
	_stamps.append([0.0, 0.0, 7.0])
	for k in 3:
		var a := k * TAU / 3.0 + PI / 6.0
		var p := Vector2(cos(a), sin(a)) * 17.0
		bumper(world, "MesaBumper%d" % k, Transform3D(Basis(), Vector3(p.x, _h(p.x, p.y), p.y)), 2.0, 0.0, Color(1.0, 0.3, 0.75), 18.0)
		_stamps.append([p.x, p.y, 3.0])
	for d in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
		var at: Vector2 = d * 96.0
		boost_pad(world, "RampBoost_%d_%d" % [int(d.x), int(d.y)], Vector3(at.x, _h(at.x, at.y), at.y), Vector3(0, 0, 0))
		_stamps.append([at.x, at.y, 4.6])
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
			_stamps.append([p.x, p.y, 10.6])
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
			_stamps.append([c.x + off.x, c.y + off.z, 2.2])
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
			_stamps.append([p.x, p.z, 1.8])
	# No grass up through the ramp where it comes down to the ground.
	for k in 40:
		var p := top.lerp(foot, k / 39.0)
		if p.y - _h(p.x, p.z) < 2.6:
			_stamps.append([p.x, p.z, 7.4])
	# The launch fan under the far edge, throwing onto the deck.
	var fan_at: Vector2 = c - _tow_t * 24.0
	var fy := _h(fan_at.x, fan_at.y)
	_stamps.append([fan_at.x, fan_at.y, 4.6])
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
	_stamps.append([at.x, at.y, 4.6])
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
		_stamps.append([p.x, p.y, 3.2])
	for k in 3:
		var a := k * TAU / 3.0
		var p := c + Vector2(cos(a), sin(a)) * 13.0
		bumper(world, "GardenPop%d" % k, Transform3D(Basis(), Vector3(p.x, _h(p.x, p.y), p.y)), 1.4, 0.0, Color(0.6, 1.0, 0.3), 16.0)
		_stamps.append([p.x, p.y, 2.4])


## Wooden kickers and fans along the ways between the middle and the bases; boost pads; item boxes on the ring.
func _build_ways(world: Node3D) -> void:
	for spec in KICKERS:
		var a: Vector2 = spec[0]
		var b: Vector2 = spec[1]
		kicker(world, "Kicker_%d_%d" % [int(a.x), int(a.y)], Vector3(a.x, _h(a.x, a.y), a.y), Vector3(b.x, 0, b.y), 9.0, 2.2, 10.0, 0.45)
		var kc: Vector2 = a + (b - a).normalized() * 4.5
		_stamps.append([kc.x, kc.y, 8.0])
	for k in 6:
		var a := k * TAU / 6.0 + 0.3
		var p := Vector2(cos(a), sin(a)) * 132.0
		item_spot(Vector3(p.x, _h(p.x, p.y), p.y))
	# Two fans in the open, straight up, for the fun of it.
	for p in [Vector2(70, 70), Vector2(-70, -70)]:
		fan(world, "OpenFan", Transform3D(Basis(), Vector3(p.x, _h(p.x, p.y), p.y)), 30.0, 0.0, 3.2)
		_stamps.append([p.x, p.y, 4.2])


func _build_boundary(world: Node3D) -> void:
	# An invisible fence on the bank past the ring.
	for k in 48:
		var a := (k + 0.5) * TAU / 48.0
		var p := Vector2(cos(a), sin(a)) * (PLAY_R + FENCE_OUT)
		var size := Vector3(2.0 * (PLAY_R + FENCE_OUT) * tan(PI / 48.0) + 1.0, 40.0, 1.0)
		box(world, "Fence%d" % k, size, facing(Vector3(p.x, _h(p.x, p.y) + 18.0, p.y), Vector3.ZERO), null, "rock", false, false)


# ======================================================================================
#  Boulders, woods, meadow
# ======================================================================================

## Where a boulder or a trunk stands, in 6m cells: nothing else is planted there.
var _taken := {}


func _take(p: Vector2, r: float) -> void:
	var n := int(ceil(r / 6.0))
	var c := Vector2i(floori(p.x / 6.0), floori(p.y / 6.0))
	for dj in range(-n, n + 1):
		for di in range(-n, n + 1):
			_taken[c + Vector2i(di, dj)] = true


func _is_taken(p: Vector2) -> bool:
	return _taken.has(Vector2i(floori(p.x / 6.0), floori(p.y / 6.0)))


func _slope(p: Vector2, e := 3.0) -> float:
	var g := _h(p.x, p.y)
	return Vector2(_h(p.x + e, p.y) - g, _h(p.x, p.y + e) - g).length() / e


func _cells_add(cells: Dictionary, key: Variant, xf: Transform3D) -> void:
	if not cells.has(key):
		cells[key] = []
	(cells[key] as Array).append(xf)


## A MultiMesh of `xfs` (world transforms) round its cell's middle, shuffled: drawing the first N thins it evenly.
func _mm(parent: Node3D, node_name: String, mesh: Mesh, xfs: Array, key: Vector3i, cell: float) -> MultiMeshInstance3D:
	var mid := Vector3((float(key.x) + 0.5) * cell, 0.0, (float(key.y) + 0.5) * cell)
	var local: Array = []
	for t in xfs:
		local.append(Transform3D((t as Transform3D).basis, (t as Transform3D).origin - mid))
	var rng := RandomNumberGenerator.new()
	rng.seed = key.x * 7919 + key.y * 104729 + key.z * 31
	for i in range(local.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Transform3D = local[i]
		local[i] = local[j]
		local[j] = tmp
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = local.size()
	# Written whole: headless, set_instance_transform keeps nothing.
	mm.buffer = PropKit.transform_buffer(local)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.position = mid
	parent.add_child(mmi)
	return mmi


## A boulder (Lakeside Meadows'): an icosphere pushed about by noise, weathered flat on top, its bed flattened; its
## colour the occlusion (r) and the height over its foot (g) granite_rock.gdshader reads.
func _rock_mesh(variant: int, size: Vector3, mat: Material, subdiv := 3) -> ArrayMesh:
	var rn := FastNoiseLite.new()
	rn.seed = 300 + variant * 17
	rn.frequency = 0.8
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in verts.size():
		verts[i] = (verts[i] as Vector3).normalized()
	for _sd in subdiv:
		var cache := {}
		var nf: Array = []
		for f in faces:
			var m: Array = []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var key := "%d_%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]
				if not cache.has(key):
					verts.append(((verts[e[0]] as Vector3) + (verts[e[1]] as Vector3)).normalized())
					cache[key] = verts.size() - 1
				m.append(cache[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var pts := PackedVector3Array()
	for v in verts:
		var d: Vector3 = v
		var r: float = 1.0 + 0.24 * rn.get_noise_3dv(d * 1.2) + 0.07 * rn.get_noise_3dv(d * 3.5)
		var q: Vector3 = d * r
		q.y = clampf(q.y, -0.7, 0.62 + 0.1 * rn.get_noise_3dv(d * 2.0))
		pts.append(q * size)
	var y_min := INF
	for q in pts:
		y_min = minf(y_min, q.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size():
		var h: float = pts[i].y - y_min
		st.set_color(Color(clampf(0.35 + h * 0.9, 0.35, 1.0), clampf(h / 1.5, 0.0, 1.0), 0.0))
		st.add_vertex(pts[i])
	for f in faces:
		var a: Vector3 = pts[f[0]]
		var b: Vector3 = pts[f[1]]
		var c: Vector3 = pts[f[2]]
		# Wound to face out (Godot's front faces: (c - a) x (b - a) outward).
		if (c - a).cross(b - a).dot((a + b + c) / 3.0) > 0.0:
			st.add_index(f[0])
			st.add_index(f[1])
			st.add_index(f[2])
		else:
			st.add_index(f[0])
			st.add_index(f[2])
			st.add_index(f[1])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Granite boulders: in twos to fours along the bank at the play area's edge, by the groves inside it (clear of
## what is driven), and cropping out of the hills where `crop` says rock. Bedded into the ground, deeper on a slope.
## Those inside the fence are solid (their hulls, DressingColliders' `hull_collider`).
func _build_boulders(world: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Boulders"
	world.add_child(node)
	var gm := ShaderMaterial.new()
	gm.shader = load("res://granite_rock.gdshader")
	gm.set_shader_parameter("dust_color", Color(0.30, 0.36, 0.18))
	gm = _save_res(gm, "mat_granite")
	var shapes := [Vector3(1.0, 0.75, 0.9), Vector3(1.4, 0.55, 1.0), Vector3(0.8, 0.95, 0.75), Vector3(1.1, 0.7, 1.2)]
	# Past the fence nobody comes near them: a quarter of the triangles (320 a boulder; 564 at 1,280 cost 0.7ms).
	var meshes: Array = []
	var coarse: Array = []
	for v in shapes.size():
		meshes.append(_save_res(_rock_mesh(v, shapes[v], gm), "boulder_%d" % v))
		coarse.append(_save_res(_rock_mesh(v, shapes[v], gm, 2), "boulder_%d_coarse" % v))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Clusters: [middle, how many, sizes].
	var spots: Array = []
	for k in 56:
		var a := rng.randf() * TAU
		spots.append([Vector2(cos(a), sin(a)) * (PLAY_R + rng.randf_range(-3.0, 30.0)), rng.randi_range(2, 4), Vector2(1.5, 4.2)])
	var tries := 0
	var placed := 0
	while placed < 30 and tries < 4000:
		tries += 1
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * rng.randf_range(OPEN_R + 4.0, PLAY_R - 8.0)
		if _clear_d(p) < 6.0:
			continue
		spots.append([p, rng.randi_range(1, 3), Vector2(0.9, 2.3)])
		placed += 1
	tries = 0
	placed = 0
	while placed < 170 and tries < 9000:
		tries += 1
		var a := rng.randf() * TAU
		var p := Vector2(cos(a), sin(a)) * rng.randf_range(PLAY_R + 24.0, PLAY_R + 360.0)
		if crop.get_noise_2d(p.x, p.y) < 0.26:
			continue
		spots.append([p, rng.randi_range(1, 3), Vector2(2.6, 7.5)])
		placed += 1
	var inside := {}
	var outside := {}
	var count := 0
	for sp in spots:
		var c: Vector2 = sp[0]
		var sizes: Vector2 = sp[2]
		for i in int(sp[1]):
			var size := rng.randf_range(sizes.x, sizes.y) * (1.0 if i == 0 else 0.6)
			var p := c + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * size * (0.0 if i == 0 else 1.6)
			var v := rng.randi() % meshes.size()
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size * rng.randf_range(0.85, 1.2),
				size * rng.randf_range(0.8, 1.15), size * rng.randf_range(0.85, 1.2)))
			var is_in := p.length() < PLAY_R + FENCE_OUT
			if p.length() < PLAY_R - 2.0 and _clear_d(p) < size * 1.5 + 2.0:
				continue
			var sy: float = (shapes[v] as Vector3).y * size
			var xf := Transform3D(basis, Vector3(p.x, _h(p.x, p.y) + sy * 0.25 - minf(_slope(p) * size * 0.55, sy * 0.3), p.y))
			_cells_add(inside if is_in else outside, Vector3i(floori(p.x / 120.0), floori(p.y / 120.0), v), xf)
			_take(p, size * 1.2)
			_stamps.append([p.x, p.y, size * 1.25])
			count += 1
	for k in inside.keys():
		var mmi := _mm(node, "Boulders_in_%d_%d_%d" % [k.x, k.y, k.z], meshes[k.z], inside[k], k, 120.0)
		mmi.set_meta(&"hull_collider", true)
	for k in outside.keys():
		var mmi := _mm(node, "Boulders_out_%d_%d_%d" % [k.x, k.y, k.z], coarse[k.z], outside[k], k, 120.0)
		mmi.set_meta(&"skip_dressing_colliders", true)
	print("  boulders: %d (%.1fs)" % [count, (Time.get_ticks_msec() - t0) * 0.001])


## The woods (see the header): which tree grows where is `_woods`' density and a species noise; broadleaves in the
## valley, conifers on the hills, larches by the rock. Tree_/TreeShadow_ near cells and TreeFar_ stand-in cells hold
## the same trees (JungleDetail moves the crossfade with the Detail Level); the hills' depth is TreeDeep_/TreeDeepFar_
## (thinned by it), and from WOODS_R to FAR_WOODS_R only stand-ins. Trees inside the fence are solid (DressingColliders'
## trunk cylinders, from the near cells); the rest carry `skip_dressing_colliders`.
func _build_woods(world: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Woodland"
	world.add_child(node)
	var w = Woodland.new()
	w.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n)
	var leaf_near: ShaderMaterial = _save_res(w.leaf_material(1, 0.14, 18.0), "leaf_near")
	var leaf_far: ShaderMaterial = _save_res(w.leaf_material(2, 0.14, 18.0), "leaf_far")
	var lod_mats: Array[ShaderMaterial] = [leaf_near, leaf_far]
	var near_meshes: Array = []
	var far_meshes: Array = []
	for kind in TREE_KINDS:
		var bn: ShaderMaterial = _save_res(w.bark_material(kind, 1), "bark_%s_near" % kind)
		var bf: ShaderMaterial = _save_res(w.bark_material(kind, 2), "bark_%s_far" % kind)
		lod_mats.append(bn)
		lod_mats.append(bf)
		near_meshes.append(_save_res(w.tree_mesh(kind, 0, 0, bn, leaf_near), "tree_%s" % kind))
		far_meshes.append(_save_res(w.tree_mesh(kind, 0, 1, bf, leaf_far), "tree_%s_far" % kind))
	var hazel_bark: ShaderMaterial = _save_res(w.bark_material("hazel", 0), "bark_hazel")
	var hazel_leaf: ShaderMaterial = _save_res(w.leaf_material(0, 0.08, 4.0), "leaf_shrub")
	var shrubs: Array = [_save_res(w.shrub_mesh(0, hazel_bark, hazel_leaf), "shrub_hazel_0"), _save_res(w.shrub_mesh(1, hazel_bark, hazel_leaf), "shrub_hazel_1")]
	print("  tree meshes (%.1fs)" % ((Time.get_ticks_msec() - t0) * 0.001))
	var species := FastNoiseLite.new()
	species.seed = 777
	species.frequency = 0.007
	species.fractal_type = FastNoiseLite.FRACTAL_NONE
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var near_in := {}
	var near_out := {}
	var far := {}
	var deep_near := {}
	var deep_far := {}
	var plants_in := {}
	var plants_out := {}
	var counts := {"inside": 0, "hills": 0, "deep": 0, "far": 0, "shrubs": 0}
	var step := 8.5
	var x := -WOODS_R
	while x < WOODS_R:
		var z := -WOODS_R
		while z < WOODS_R:
			var p := Vector2(x + rng.randf_range(-0.45, 0.45) * step, z + rng.randf_range(-0.45, 0.45) * step)
			var roll_a := rng.randf()
			var roll_b := rng.randf()
			var sc := rng.randf_range(0.85, 1.25)
			var turn := rng.randf() * TAU
			var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.045))
			z += step
			var r := p.length()
			if r < OPEN_R or r > WOODS_R:
				continue
			var y := _h(p.x, p.y)
			var dens := _woods(p, y)
			var is_in := r < PLAY_R + FENCE_OUT
			# The hazel grows at the woods' edges, where the trees thin out.
			if dens > 0.12 and dens < 0.62 and roll_b < 0.3 and not _is_taken(p) and (not is_in or _clear_d(p) > 4.0) and _slope(p) < 0.6:
				var sb := Basis(Vector3.UP, turn).scaled(Vector3.ONE * rng.randf_range(0.9, 1.5))
				_cells_add(plants_in if is_in else plants_out, Vector3i(floori(p.x / FOREST_CELL), floori(p.y / FOREST_CELL), rng.randi() % 2),
					Transform3D(sb, Vector3(p.x, y - 0.1, p.y)))
				_take(p, 1.0)
				_stamps.append([p.x, p.y, 1.3])
				counts["shrubs"] += 1
				continue
			if roll_a > dens * (0.8 if is_in else 1.0):
				continue
			if is_in and _clear_d(p) < 3.0:
				continue
			# No trunk on the fence's line: half a tree would be out of reach behind it.
			if absf(r - PLAY_R - FENCE_OUT) < 3.0 or _is_taken(p):
				continue
			var slope := _slope(p)
			var rock := _rock(p, y)
			if slope > 0.8 or rock > 0.62:
				continue
			var kn := species.get_noise_2d(p.x, p.y)
			var hill := smoothstep(PLAY_R - 10.0, PLAY_R + 45.0, r)
			var kind := "oak"
			# Larches (not pines: their bare orange trunks stood out of these woods like poles) by the rock and here and there.
			if rock > 0.22 or (roll_b > 0.9 and hill > 0.5):
				kind = "larch"
			elif roll_b < hill * 0.86 or y > 120.0:
				kind = "spruce" if kn > -0.1 else "fir"
				if roll_b < 0.09 and y < 110.0:
					kind = "birch"
			elif kn > 0.25:
				kind = "lime" if roll_b < 0.7 else "birch"
			elif kn < -0.3:
				kind = "birch" if roll_b < 0.75 else "oak"
			elif roll_b < 0.35:
				kind = "birch"
			var ki: int = TREE_KINDS.find(kind)
			var xf := Transform3D(lean * Basis(Vector3.UP, turn).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.1), sc)),
				Vector3(p.x, y - 0.25 - minf(slope * 1.2, 1.0), p.y))
			var key := Vector3i(floori(p.x / FOREST_CELL), floori(p.y / FOREST_CELL), ki)
			var fkey := Vector3i(floori(p.x / FAR_CELL), floori(p.y / FAR_CELL), ki)
			if r - PLAY_R > 70.0 and rng.randf() < 0.65:
				_cells_add(deep_near, key, xf)
				_cells_add(deep_far, fkey, xf)
				counts["deep"] += 1
			else:
				_cells_add(near_in if is_in else near_out, key, xf)
				_cells_add(far, fkey, xf)
				counts["inside" if is_in else "hills"] += 1
			_take(p, 0.5)
			_stamps.append([p.x, p.y, 1.1 * sc])
		x += step
	# The far woods: stand-ins alone, wider apart and a little bigger, up the ranges' feet.
	step = 19.0
	x = -FAR_WOODS_R
	while x < FAR_WOODS_R:
		var z := -FAR_WOODS_R
		while z < FAR_WOODS_R:
			var p := Vector2(x + rng.randf_range(-0.45, 0.45) * step, z + rng.randf_range(-0.45, 0.45) * step)
			var roll_a := rng.randf()
			var sc := rng.randf_range(1.25, 1.8)
			var turn := rng.randf() * TAU
			z += step
			var r := p.length()
			if r < WOODS_R or r > FAR_WOODS_R:
				continue
			var y := _h(p.x, p.y)
			if roll_a > _woods(p, y) or _rock(p, y) > 0.6 or _slope(p, 6.0) > 0.85:
				continue
			var ki: int = TREE_KINDS.find("spruce" if species.get_noise_2d(p.x, p.y) > -0.1 else "fir")
			_cells_add(deep_far, Vector3i(floori(p.x / FAR_CELL), floori(p.y / FAR_CELL), ki + 100),
				Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * sc), Vector3(p.x, y - 0.6, p.y)))
			counts["far"] += 1
		x += step
	var near_end: float = Woodland.TREE_NEAR + Woodland.TREE_FADE * 0.5 + Woodland.TREE_FADE_JITTER + FOREST_CELL * 0.72
	var far_begin: float = maxf(0.0, Woodland.TREE_NEAR - Woodland.TREE_FADE * 0.5 - Woodland.TREE_FADE_JITTER - FAR_CELL * 0.72)
	for pair in [[near_in, "in", false], [near_out, "out", true]]:
		var cells: Dictionary = pair[0]
		for k in cells.keys():
			var mmi := _mm(node, "Tree_%s_%d_%d_k%d" % [pair[1], k.x, k.y, k.z], near_meshes[k.z], cells[k], k, FOREST_CELL)
			mmi.visibility_range_end = near_end
			mmi.visibility_range_end_margin = 10.0
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if pair[2]:
				mmi.set_meta(&"skip_dressing_colliders", true)
			var proxy := _mm(node, "TreeShadow_%s_%d_%d_k%d" % [pair[1], k.x, k.y, k.z], far_meshes[k.z], cells[k], k, FOREST_CELL)
			proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			proxy.visibility_range_end = near_end
			proxy.visibility_range_end_margin = 10.0
			proxy.set_meta(&"skip_dressing_colliders", true)
	for k in far.keys():
		var mmi2 := _mm(node, "TreeFar_%d_%d_k%d" % [k.x, k.y, k.z], far_meshes[k.z], far[k], k, FAR_CELL)
		mmi2.visibility_range_begin = far_begin
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi2.set_meta(&"skip_dressing_colliders", true)
	for k in deep_near.keys():
		var mmi3 := _mm(node, "TreeDeep_%d_%d_k%d" % [k.x, k.y, k.z], near_meshes[k.z], deep_near[k], k, FOREST_CELL)
		mmi3.visibility_range_end = near_end
		mmi3.visibility_range_end_margin = 10.0
		mmi3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi3.set_meta(&"skip_dressing_colliders", true)
	for k in deep_far.keys():
		var mmi4 := _mm(node, "TreeDeepFar_%d_%d_k%d" % [k.x, k.y, k.z], far_meshes[k.z % 100], deep_far[k], k, FAR_CELL)
		if k.z < 100:
			mmi4.visibility_range_begin = far_begin
		mmi4.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi4.set_meta(&"skip_dressing_colliders", true)
	for pair in [[plants_in, "in", false], [plants_out, "out", true]]:
		var cells: Dictionary = pair[0]
		for k in cells.keys():
			var mmi5 := _mm(node, "Plants_%s_%d_%d_%d" % [pair[1], k.x, k.y, k.z], shrubs[k.z], cells[k], k, FOREST_CELL)
			mmi5.visibility_range_end = 150.0 + FOREST_CELL * 0.72
			mmi5.visibility_range_end_margin = 10.0
			mmi5.set_meta(&"base_range", mmi5.visibility_range_end)
			mmi5.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if pair[2]:
				mmi5.set_meta(&"skip_dressing_colliders", true)
	var detail := Node3D.new()
	detail.name = "JungleDetail"
	detail.set_script(load("res://JungleDetail.gd"))
	detail.set("lod_materials", lod_mats)
	detail.set("tree_fade", Woodland.TREE_FADE)
	detail.set("tree_fade_jitter", Woodland.TREE_FADE_JITTER)
	detail.set("forest_cell", FOREST_CELL)
	node.add_child(detail)
	print("  woods: %s (%.1fs)" % [str(counts), (Time.get_ticks_msec() - t0) * 0.001])


## The meadow (MeadowGrass.gd, meadow_grass.gdshader, MeadowDetail.gd, as on Lakeside Meadows): tufts of real blades
## standing on the heightfield from a height texture, grown as a 0.5m map says (R how much, G how tall): thinner and
## shorter under the trees, a little shorter in the play area and shorter still along the
## tracks, none on the tracks, the sand, rock and steep ground, or under anything standing (`_stamps`).
func _build_meadow(world: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Meadow"
	node.set_script(load("res://MeadowDetail.gd"))
	world.add_child(node)
	var cells_n := _n - 1
	var tall := FastNoiseLite.new()
	tall.seed = 5150
	tall.frequency = 0.018
	tall.fractal_octaves = 2
	var base := PackedByteArray()
	base.resize(cells_n * cells_n * 2)
	for j in cells_n:
		var z := -HALF + (j + 0.5) * STEP
		for i in cells_n:
			var x := -HALF + (i + 0.5) * STEP
			var h00: float = _heights[j * _n + i]
			var h10: float = _heights[j * _n + i + 1]
			var h01: float = _heights[(j + 1) * _n + i]
			var h11: float = _heights[(j + 1) * _n + i + 1]
			var g := (h00 + h10 + h01 + h11) * 0.25
			var steep := maxf(absf(h10 - h00), maxf(absf(h01 - h00), absf(h11 - h00))) / STEP
			if steep > 0.95:
				continue
			var p := Vector2(x, z)
			var dirt := (_dirt[j * _n + i] + _dirt[j * _n + i + 1] + _dirt[(j + 1) * _n + i] + _dirt[(j + 1) * _n + i + 1]) * 0.25
			var woods := 1.0 - _woodv[j * _n + i]
			var amount := (1.0 - smoothstep(0.06, 0.3, dirt)) * smoothstep(-0.4, 1.0, g) * (1.0 - smoothstep(0.25, 0.6, _rock(p, g)))
			amount *= lerpf(1.0, 0.4, woods) * (1.0 - smoothstep(0.7, 0.95, steep))
			var height := lerpf(0.62, 1.0, tall.get_noise_2d(x, z) * 0.5 + 0.5) * lerpf(1.0, 0.75, woods)
			height *= lerpf(0.78, 1.0, smoothstep(PLAY_R - 20.0, PLAY_R + 20.0, p.length()))
			height *= lerpf(1.0, 0.5, smoothstep(0.0, 0.06, dirt))
			var k := (j * cells_n + i) * 2
			base[k] = int(round(clampf(amount, 0.0, 1.0) * 255.0))
			base[k + 1] = int(round(clampf(height, 0.0, 1.0) * 255.0))
	var side := int(HALF * 2.0 / MEADOW_STEP)
	var img := Image.create_from_data(cells_n, cells_n, false, Image.FORMAT_RG8, base)
	img.resize(side, side, Image.INTERPOLATE_BILINEAR)
	var data := img.get_data()
	var cleared := 0
	for sp in _stamps:
		var c := Vector2(float(sp[0]), float(sp[1]))
		var rad := float(sp[2])
		var i0 := maxi(0, int((c.x - rad + HALF) / MEADOW_STEP))
		var i1 := mini(side - 1, int((c.x + rad + HALF) / MEADOW_STEP) + 1)
		var j0 := maxi(0, int((c.y - rad + HALF) / MEADOW_STEP))
		var j1 := mini(side - 1, int((c.y + rad + HALF) / MEADOW_STEP) + 1)
		for tj in range(j0, j1 + 1):
			for ti in range(i0, i1 + 1):
				var q := Vector2(-HALF + (ti + 0.5) * MEADOW_STEP, -HALF + (tj + 0.5) * MEADOW_STEP)
				var keep := smoothstep(rad - 0.5, rad + 0.3, q.distance_to(c))
				var k := (tj * side + ti) * 2
				if keep < 1.0 and data[k] > 0:
					data[k] = int(data[k] * keep)
					cleared += 1
	var grass_tex: Texture2D = _save_res(MeadowGrass.grass_texture(data, side), "meadow_map")
	var ht: Array = MeadowGrass.height_texture(_heights, _n)
	var height_tex: Texture2D = _save_res(ht[0], "meadow_heights")
	var height_grid := Vector4(-HALF, -HALF, STEP, _n)
	var grass_grid := Vector3(-HALF, -HALF, HALF * 2.0)
	var mats: Array[ShaderMaterial] = []
	var mms: Array[MultiMesh] = []
	var cells := 0
	for tier in MeadowGrass.TIERS.size():
		var t: Dictionary = MeadowGrass.TIERS[tier]
		var mesh: Mesh = _save_res(MeadowGrass.tuft_mesh(tier, 1301 + tier), "meadow_tuft_%d" % tier)
		var mm: MultiMesh = _save_res(MeadowGrass.cell_multimesh(tier, mesh, 2203 + tier), "meadow_cells_%d" % tier)
		var gmat: ShaderMaterial = _save_res(MeadowGrass.material(tier, height_tex, ht[1], grass_tex, height_grid, grass_grid), "meadow_mat_%d" % tier)
		mats.append(gmat)
		mms.append(mm)
		var size: float = t["cell"]
		var fade_end: float = (t["fade"] as Vector2).y
		var reach: float = size * 0.71
		var count := int(ceil(HALF * 2.0 / size))
		var span := int(size / MEADOW_STEP)
		var gs := int(size / STEP)
		for cj in count:
			for ci in count:
				var x0: float = -HALF + ci * size
				var z0: float = -HALF + cj * size
				var any := false
				var tj := 0
				while tj < span and not any:
					var ti := 0
					while ti < span:
						var a := int((x0 + HALF) / MEADOW_STEP) + ti
						var b := int((z0 + HALF) / MEADOW_STEP) + tj
						if a < side and b < side and data[(b * side + a) * 2] > 0:
							any = true
							break
						ti += 3
					tj += 3
				if not any:
					continue
				var lo := INF
				var hi := -INF
				var g0i := int((x0 + HALF) / STEP)
				var g0j := int((z0 + HALF) / STEP)
				for gj in range(g0j, mini(g0j + gs + 1, _n)):
					for gi in range(g0i, mini(g0i + gs + 1, _n)):
						var h: float = _heights[gj * _n + gi]
						lo = minf(lo, h)
						hi = maxf(hi, h)
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "Grass%d_%d_%d" % [tier, ci, cj]
				mmi.multimesh = mm
				mmi.material_override = gmat
				mmi.position = Vector3(x0, 0.0, z0)
				# The tufts are at y = 0 in the MultiMesh; the shader lifts them onto the ground.
				mmi.custom_aabb = AABB(Vector3(-1.5, lo - 1.0, -1.5), Vector3(size + 3.0, hi - lo + 3.5, size + 3.0))
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mmi.visibility_range_end = fade_end + reach
				mmi.set_meta(&"fade_end", fade_end)
				mmi.set_meta(&"reach", reach)
				node.add_child(mmi)
				cells += 1
	node.set("materials", mats)
	node.set("multimeshes", mms)
	print("  meadow: %d cells in %d tiers, %d texels under things cleared (%.1fs)" % [cells, mms.size(), cleared, (Time.get_ticks_msec() - t0) * 0.001])


## The spawns: in teams red (even) south of the mesa, blue (odd) north, facing it; all against all the same six.
func _spawns() -> void:
	for i in 6:
		var row := i / 2
		var sgn := 1.0 if i % 2 == 0 else -1.0
		var x := (row - 1) * 14.0
		var z := sgn * 104.0
		spawn(Vector3(x, _h(x, z) + 0.6, z), Vector3(0, 0, 0))
