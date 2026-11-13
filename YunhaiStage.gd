extends "res://MiyoshinoStage.gd"
# The Yunhai GP's stage base (云海, a made-up river megacity at night after Chongqing): what Tianqiao
# (regenerate_tianqiao.gd) and Panlong Lijiao (regenerate_panlong.gd) share, on top of the Miyoshino GP's stage base.
#   - the ground: flat streets in a grid (megacity_ground.gdshader: lanes, crossings, pavements, a park's lawns), a river
#     (`river_pts`, `river_half`) under a dark mirror (`_build_water`), hills round the far city;
#   - the night (`_environment`): a dark purple sky in haze, a weak moon, glow;
#   - the city: `_build_city` fills the grid's blocks round `city_mid` out to `city_near` with MegacityKit towers (lit
#     windows, LED media facades, shop podiums), kept off `_reserved` rectangles and under the course (`_route_low_over`),
#     `_plot_tweak` letting a stage change a plot; `_build_skyline` the far towers out to `skyline_r`;
#   - decks under the lap (`_deck`: slab, glass balustrades or solid parapets, LED strips, columns, rail colliders on
#     `_rails`), roofs with parapets open where the lap passes (`_roof`), people in lines (`_crowd_line`);
#   - the signs' font: Noto Sans CJK SC, a subset of the characters the Yunhai generators use (`CJK_FONT`, made by
#     scratch/yunhai_font_subset.sh), read into a FontFile and saved with the stage (`_load_cjk_font`).
# Every prop is built in game metres in world space (`_city`). Name deck props with "deck" in the key: the runtime's
# DressingColliders makes every other prop mesh solid (and Level's builder hulls anything named "ramp" or "loop").

const MCK = preload("res://MegacityKit.gd")
const CJK_FONT := "res://fonts/NotoSansSC-Yunhai.otf"

## The city's street grid: cells of `grid_cell` with a `grid_street`-wide street along each cell's low x and low z edge.
var grid_origin := Vector2(9.0, 49.0)
var grid_cell := Vector2(120.0, 100.0)
var grid_street := 22.0
## The detailed city reaches `city_near` from `city_mid`; the skyline beyond to `skyline_r`. Towers near the middle are
## up to about `city_tall.x` high, `city_tall.y` at the edge (a share either way at random).
var city_near := 1300.0
var skyline_r := 3600.0
var city_mid := Vector2(380.0, 500.0)
var city_tall := Vector2(78.0, 60.0)
var skyline_clusters: Array = [Vector2(-900.0, 1400.0), Vector2(1100.0, -1300.0), Vector2(2400.0, 900.0), Vector2(-1600.0, -200.0),
	Vector2(600.0, 2600.0)]
## The park's lawns on the ground shader (no streets drawn there).
var park_rect := Rect2(640.0, 984.0, 340.0, 330.0)
## The river's line (plan), half width, bed and water level.
var river_pts: Array = [Vector2(-4000.0, -560.0), Vector2(-800.0, -520.0), Vector2(600.0, -540.0), Vector2(1350.0, -380.0),
	Vector2(1560.0, 300.0), Vector2(1620.0, 1500.0), Vector2(1700.0, 4000.0)]
var river_half := 160.0
var river_bed := -14.0
var water_y := -6.0

var _route_pts: Array = []
var _route_cells := {}
var _reserved: Array = []
var _rails: StaticBody3D
var _bid := 1


## How the decks' columns look: 0 a round column, 1 a motorway's hammerhead pier (a square column, a cap beam across).
var pier_style := 0


## Whether a deck's column may stand at p (on ground g): not on a lower stretch of the lap (where the lap passes under
## itself) nor on what the stage says (`_col_blocked`).
func _col_ok(p: Vector3, g: float) -> bool:
	var key := Vector2i(floori(p.x / 40.0), floori(p.z / 40.0))
	for i in range(key.x - 1, key.x + 2):
		for j in range(key.y - 1, key.y + 2):
			for q in _route_cells.get(Vector2i(i, j), []):
				var v: Vector3 = q
				if v.y < p.y - 3.0 and Vector2(v.x - p.x, v.z - p.z).length() < road_half + 4.0:
					return false
	return not _col_blocked(p, g)


func _col_blocked(_p: Vector3, _g: float) -> bool:
	return false


## A hammerhead pier under a deck at p (its top `depth` under the road), `rt` across, from the ground g: a square column
## widening into a cap beam as wide as the deck.
func _hammerhead(pk: PropKit, kit: Dictionary, p: Vector3, rt: Vector3, g: float, depth: float, w: float) -> void:
	var conc := Color(0.5, 0.5, 0.52, float(MCK.STYLE_CONCRETE) / 8.0)
	var fw: Vector3 = Vector3.UP.cross(rt).normalized()
	var top: float = p.y - depth
	var cap: float = minf(2.2, (top - g) * 0.3)
	var b := Basis(rt, Vector3.UP, fw)
	pk.box(kit, "tower", Transform3D(b, Vector3(p.x, (g - 1.0 + top - cap) * 0.5, p.z)), Vector3(3.0, top - cap - g + 1.0, 2.4), conc)
	pk.box(kit, "tower", Transform3D(b, Vector3(p.x, top - cap * 0.5, p.z)), Vector3(w * 1.6, cap, 2.6), conc)


## The lowest ground under a plot (its corners and middle), a little under it so the walls reach into the slope.
func _plot_ground(r: Rect2) -> float:
	var g := INF
	for q in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
		g = minf(g, _ground_at(q.x, q.y))
	return minf(g, 0.0) if g < 0.5 else g - 0.5


## A stage's say over one of the city's plots before it is built: `d` holds "podium", "style" and "top" to change.
func _plot_tweak(_plot: Rect2, _d: Dictionary) -> void:
	pass


## The signs' font (see the top); call it in `_build_dressing`, after the run has cleared the stage's old files.
func _load_cjk_font() -> void:
	if FileAccess.file_exists(CJK_FONT):
		var ff := FontFile.new()
		ff.load_dynamic_font(CJK_FONT)
		_jp_font = _save_res(ff, "cjk_font")


func _river_d(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var best := INF
	for i in range(river_pts.size() - 1):
		var a: Vector2 = river_pts[i]
		var b: Vector2 = river_pts[i + 1]
		var ab: Vector2 = b - a
		var t: float = clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * t))
	return best


func _natural(x: float, z: float) -> float:
	var rd: float = _river_d(x, z)
	var h: float = lerpf(river_bed, 0.0, smoothstep(river_half - 30.0, river_half + 25.0, rd))
	# Hills round the far city (Yunhai is a city of hills), rising past 2.6km from its middle.
	var r: float = Vector2(x, z).distance_to(city_mid)
	var hill: float = smoothstep(2500.0, 4200.0, r) * (160.0 + 120.0 * n_ridge.get_noise_2d(x * 0.6, z * 0.6))
	return h + maxf(hill, 0.0) * smoothstep(river_half, river_half + 300.0, rd)


func _masks(_i: int, _x: float, _z: float, _nrm_y: float, _road_d: float) -> Color:
	return Color(0, 0, 0, 0)


func _ground_params(m: ShaderMaterial) -> void:
	m.shader = load("res://megacity_ground.gdshader")
	m.set_shader_parameter("grid_origin", grid_origin)
	m.set_shader_parameter("block", grid_cell)
	m.set_shader_parameter("street", grid_street)
	m.set_shader_parameter("park", Vector4(park_rect.position.x, park_rect.position.y, park_rect.end.x, park_rect.end.y))
	m.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	m.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))


## Air taxis (AirTaxis.gd) flying `routes` ([{"points": [Vector3, ...], "speed": m/s, "count": n}], closed loops smoothed
## through their points) on the wall clock. Check each stage's with res://scratch/flight_path_clearance.gd.
func _build_air_taxis(root: Node3D, routes: Array) -> void:
	var n := Node3D.new()
	n.name = "AirTaxis"
	n.set_script(load("res://AirTaxis.gd"))
	var rs: Array = []
	for r in routes:
		rs.append({"points": PackedVector3Array(r["points"]), "speed": r["speed"], "count": r["count"]})
	n.set("routes", rs)
	n.set("engine_sound", load("res://sounds/yunhai/air_taxi_loop.wav"))
	n.set("engine_rms", -18.1)
	root.add_child(n)


## The city's roads: polished dark asphalt, no centre line (miyoshino_road.gdshader's `city_finish`).
func _road_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("city_finish", 1.0)
	m.set_shader_parameter("city_reflect", 0.8)


func _environment() -> Dictionary:
	return {
		"sky_top": Color(0.015, 0.02, 0.05), "sky_horizon": Color(0.24, 0.13, 0.24), "haze": Color(0.17, 0.11, 0.19),
		"ground_bottom": Color(0.05, 0.04, 0.06), "sky_curve": 0.55, "haze_strength": 1.0, "haze_height": 0.22,
		"sun_tint": Color(0.8, 0.85, 1.0), "sun_glow": 0.03, "sun_horizon_tint": Color(0.5, 0.4, 0.6), "sun_horizon_glow": 0.0,
		"cloud_lit": Color(0.32, 0.2, 0.3), "cloud_shade": Color(0.07, 0.06, 0.1), "cloud_coverage": 0.5, "cloud_opacity": 0.7,
		"cloud_scale": 1.1, "cloud_seed": 31.7, "sky_energy": 1.0,
		"ambient": 0.15, "ambient_color": Color(0.30, 0.27, 0.40), "exposure": 1.2, "glow": 0.95, "bloom": 0.08,
		"fog_begin": 140.0, "fog_end": 2900.0, "fog_curve": 1.5, "fog_density": 1.0, "fog_sky": 0.35, "fog_aerial": 0.15,
		"fog_scatter": 0.0,
		"sun_pitch": -38.0, "sun_yaw": 140.0, "sun_color": Color(0.55, 0.62, 0.9), "sun_energy": 0.35, "shadow_distance": 260.0,
	}


## The route in plan and height every 4m, in 40m cells, for keeping buildings clear of it.
func _sample_route() -> void:
	var s := 0.0
	while s <= lap.length:
		var p: Vector3 = lap.pt(s)
		_route_pts.append(p)
		var key := Vector2i(floori(p.x / 40.0), floori(p.z / 40.0))
		if not _route_cells.has(key):
			_route_cells[key] = []
		(_route_cells[key] as Array).append(p)
		s += 4.0


## The lowest the route passes within `clear` of a plan rectangle (INF if it doesn't).
func _route_low_over(r: Rect2, clear: float) -> float:
	var low := INF
	var g := r.grow(clear)
	for i in range(floori(g.position.x / 40.0), floori(g.end.x / 40.0) + 1):
		for j in range(floori(g.position.y / 40.0), floori(g.end.y / 40.0) + 1):
			var key := Vector2i(i, j)
			if not _route_cells.has(key):
				continue
			for p in _route_cells[key]:
				var q := Vector2((p as Vector3).x, (p as Vector3).z)
				if g.has_point(q):
					low = minf(low, (p as Vector3).y)
	return low


func _reserved_hit(r: Rect2) -> bool:
	for rr in _reserved:
		if (rr as Rect2).intersects(r):
			return true
	return false


func _id() -> int:
	_bid += 1
	return _bid


## Builds a piece of the city in game metres, in world space.
func _city(key: String, build: Callable, range_end := 0.0) -> void:
	_add_prop_game(key, MCK, Transform3D.IDENTITY, build, range_end)


## A deck under the lap from s0 to s1: a slab `depth` deep a little wider than the road (its top just under the ribbon),
## glass balustrades with LED feet on both sides (colliders along them), LED strips along its edges below, and columns
## to the ground every `col_step` metres (0: none).
## `glass`: a glass floor (the stage draws the road's ribbon in glass, see Tianqiao's `_glass_roads`): no slab under it,
## only steel edge girders, a rib across every 4m and two stringers, so the city shows through.
func _deck(key: String, s0: float, s1: float, depth: float, led: Color, col_step := 0.0, rails := [true, true], col_floor := 0.0, solid_side := false,
		glass := false) -> void:
	var w: float = road_half + 0.6
	_city(key, func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		var s: float = s0
		while s < s1 - 0.01:
			var sb: float = minf(s + 4.0, s1)
			var a: Vector3 = lap.pt(s) - Vector3(0, 0.05, 0)
			var b: Vector3 = lap.pt(sb) - Vector3(0, 0.05, 0)
			var ra: Vector3 = lap.rt(s)
			var rb: Vector3 = lap.rt(sb)
			var dn := Vector3(0, -depth, 0)
			if glass:
				var steel := Color(0.32, 0.34, 0.38)
				for side in [-1.0, 1.0]:
					var pa: Vector3 = a + ra * w * side
					var pb: Vector3 = b + rb * w * side
					pk.beam(kit, "steel", pa - ra * side * 0.3 - Vector3(0, 0.45, 0), pb - rb * side * 0.3 - Vector3(0, 0.45, 0), 0.6, 0.9, steel)
					MCK.led_line(pk, kit, pa + Vector3(0, -0.45, 0) + ra * side * 0.02, pb + Vector3(0, -0.45, 0) + rb * side * 0.02, led, 0.14)
					pk.beam(kit, "steel", a + ra * w * 0.45 * side - Vector3(0, 0.35, 0), b + rb * w * 0.45 * side - Vector3(0, 0.35, 0), 0.25, 0.5, steel)
					if rails[0 if side < 0.0 else 1]:
						MCK.glass_rail(pk, kit, pa - ra * side * 0.25, pb - rb * side * 0.25, 1.3, led)
				pk.beam(kit, "steel", a - ra * w - Vector3(0, 0.3, 0), a + ra * w - Vector3(0, 0.3, 0), 0.2, 0.4, steel)
				s = sb
				continue
			for side in [-1.0, 1.0]:
				var pa: Vector3 = a + ra * w * side
				var pb: Vector3 = b + rb * w * side
				MCK.wall(pk, kit, pa if side > 0.0 else pb, pb if side > 0.0 else pa, 0.0, 0.0, ra * side, Color(0.3, 0.31, 0.34), MCK.STYLE_CLADDING, 0)
				pk.quad(kit, "tower", [pa + dn, pb + dn, pb, pa], ra * side, Color(0.22, 0.23, 0.26, float(MCK.STYLE_CLADDING) / 8.0),
						[Vector2(s, pa.y - depth), Vector2(sb, pb.y - depth), Vector2(sb, pb.y), Vector2(s, pa.y)])
				MCK.led_line(pk, kit, pa + dn * 0.5 + ra * side * 0.04, pb + dn * 0.5 + rb * side * 0.04, led, 0.14)
				if rails[0 if side < 0.0 else 1]:
					if solid_side:
						pk.quad(kit, "tower", [pa, pb, pb + Vector3(0, 1.1, 0), pa + Vector3(0, 1.1, 0)], -ra * side,
								Color(0.5, 0.5, 0.52, float(MCK.STYLE_CONCRETE) / 8.0), [Vector2(s, 0), Vector2(sb, 0), Vector2(sb, 1.1), Vector2(s, 1.1)])
						pk.quad(kit, "tower", [pa + Vector3(0, 1.1, 0), pb + Vector3(0, 1.1, 0), pb + Vector3(0, 1.1, 0) + rb * side * 0.4,
								pa + Vector3(0, 1.1, 0) + ra * side * 0.4], Vector3.UP, Color(0.6, 0.6, 0.62, float(MCK.STYLE_CONCRETE) / 8.0))
						# An LED line along the parapet's top: the decks read as lines of light from afar.
						MCK.led_line(pk, kit, pa + Vector3(0, 1.13, 0) + ra * side * 0.2, pb + Vector3(0, 1.13, 0) + rb * side * 0.2, led, 0.12)
					else:
						MCK.glass_rail(pk, kit, pa - ra * side * 0.25, pb - rb * side * 0.25, 1.3, led)
			pk.quad(kit, "tower", [a - ra * w + dn, b - rb * w + dn, b + rb * w + dn, a + ra * w + dn], Vector3.DOWN,
					Color(0.16, 0.17, 0.2, float(MCK.STYLE_CLADDING) / 8.0), [Vector2(s, 0), Vector2(sb, 0), Vector2(sb, 2.0 * w), Vector2(s, 2.0 * w)])
			s = sb
		if col_step > 0.0:
			var c: float = s0 + col_step * 0.5
			while c < s1:
				var p: Vector3 = lap.pt(c)
				var g: float = col_floor if col_floor > 0.0 else _ground_at(p.x, p.z)
				if p.y - depth - g > 2.5 and _col_ok(p, g):
					if pier_style == 1:
						_hammerhead(pk, kit, p, lap.rt(c), g, depth, w)
					else:
						pk.tube(kit, "tower", Vector3(p.x, g - 1.0, p.z), Vector3(p.x, p.y - depth, p.z), 2.2, 1.6, 12,
								Color(0.42, 0.42, 0.44, float(MCK.STYLE_CONCRETE) / 8.0))
				c += col_step
	, 2600.0)
	for i in range(2):
		if rails[i]:
			_edge_boxes(_rails, lap, s0, s1, (-1.0 if i == 0 else 1.0) * (road_half + 0.45), 1.4, 0.4)


## A roof at height y over a plan rectangle (its top 6cm under the road's ribbon), with a parapet round it except on
## the sides in `open` (0 north, 1 east, 2 south, 3 west), each an [side, from, to] stretch left open, and colliders.
## The sides run clockwise seen from above: north from its west end, east from its north end, south from its EAST end,
## west from its south end; `from`/`to` are metres along the side from where it starts.
func _roof(r: Rect2, y: float, open: Array, dots := true) -> void:
	var plan := MCK.rect_plan(r.get_center(), r.size.x * 0.5, r.size.y * 0.5)
	_city("roof_deck", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
		MCK.flat(pk, kit, plan, y - 0.2, Vector3.UP, Color(0.3, 0.3, 0.33), MCK.STYLE_CONCRETE)
		# Helipad-style markings and a walkway grid: LED dots round the edge.
		var c: Vector2 = r.get_center()
		for i in range(24 if dots else 0):
			var a: float = TAU * float(i) / 24.0
			var p := c + Vector2(cos(a), sin(a)) * minf(r.size.x, r.size.y) * 0.42
			pk.block(kit, "neon", Vector3(p.x - 0.2, y - 0.06, p.y - 0.2), Vector3(p.x + 0.2, y + 0.0, p.y + 0.2), Color(0.3, 0.9, 1.0))
	, 2600.0)
	# "Deck": the roofs are driven on (PlayerCart counts them as track; the AI may cut across them).
	var body := _body(level, "RoofDeck_%d" % _bid)
	body.set_meta(&"surface", "asphalt")
	_box_shape(body, Transform3D(Basis(), Vector3(r.get_center().x, y - 1.2, r.get_center().y)), Vector3(r.size.x, 2.0, r.size.y))
	# Parapets: [a, b] per side, broken where open.
	var sides: Array = [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end],
		[r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]
	for si in range(4):
		var a2: Vector2 = sides[si][0]
		var b2: Vector2 = sides[si][1]
		var pieces: Array = [[0.0, a2.distance_to(b2)]]
		for o in open:
			if int(o[0]) != si:
				continue
			var nxt: Array = []
			for pc in pieces:
				var f0: float = o[1]
				var f1: float = o[2]
				if f1 <= pc[0] or f0 >= pc[1]:
					nxt.append(pc)
					continue
				if f0 > pc[0]:
					nxt.append([pc[0], f0])
				if f1 < pc[1]:
					nxt.append([f1, pc[1]])
			pieces = nxt
		var dir: Vector2 = (b2 - a2).normalized()
		for pc in pieces:
			var pa: Vector2 = a2 + dir * float(pc[0])
			var pb: Vector2 = a2 + dir * float(pc[1])
			if pa.distance_to(pb) < 0.5:
				continue
			var seg := PackedVector2Array([pa, pb])
			_city("roof_deck", func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
				var out := Vector2(dir.y, -dir.x)
				var inn: Vector2 = -out * 0.4
				# Both faces run down past the roof's surface (y - 0.2): from y - 0.1 a slot under the parapet showed the lit
				# facade below through it. The outer face stands 4cm proud of the building's wall under it, or the two shared a
				# plane where it reaches down past the roof and flickered along every roof's edge.
				var po: Vector2 = pa + out * 0.04
				var qo: Vector2 = pb + out * 0.04
				MCK.wall(pk, kit, Vector3(po.x, 0, po.y), Vector3(qo.x, 0, qo.y), y - 0.6, y + 1.2, Vector3(out.x, 0, out.y), Color(0.2, 0.21, 0.24), MCK.STYLE_CLADDING, 0)
				pk.quad(kit, "tower", [Vector3(pa.x, y + 1.2, pa.y), Vector3(po.x, y + 1.2, po.y), Vector3(qo.x, y + 1.2, qo.y), Vector3(pb.x, y + 1.2, pb.y)],
						Vector3.UP, Color(0.5, 0.5, 0.52, float(MCK.STYLE_CONCRETE) / 8.0))
				MCK.wall(pk, kit, Vector3(pb.x + inn.x, 0, pb.y + inn.y), Vector3(pa.x + inn.x, 0, pa.y + inn.y), y - 0.25, y + 1.2, Vector3(-out.x, 0, -out.y),
						Color(0.42, 0.42, 0.44), MCK.STYLE_CONCRETE, 0)
				pk.quad(kit, "tower", [Vector3(pa.x, y + 1.2, pa.y), Vector3(pb.x, y + 1.2, pb.y), Vector3(pb.x + inn.x, y + 1.2, pb.y + inn.y),
						Vector3(pa.x + inn.x, y + 1.2, pa.y + inn.y)], Vector3.UP, Color(0.5, 0.5, 0.52, float(MCK.STYLE_CONCRETE) / 8.0))
				MCK.led_line(pk, kit, Vector3(pa.x, y + 1.27, pa.y) + Vector3(inn.x, 0, inn.y) * 0.5, Vector3(pb.x, y + 1.27, pb.y) + Vector3(inn.x, 0, inn.y) * 0.5,
						Color(0.3, 0.85, 1.0, 0.6), 0.1)
			, 2600.0)
			var mid: Vector2 = (pa + pb) * 0.5
			_box_shape(_rails, Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), Vector3(mid.x, y + 0.6, mid.y)), Vector3(pa.distance_to(pb), 1.8, 0.5))
			if seg.size() < 0:
				pass


## People standing at a spot on a deck or roof (y given), facing `face`.
func _crowd_line(a: Vector3, b: Vector3, face: Vector3, every: float, rng: RandomNumberGenerator, share := 0.7) -> void:
	var l: float = a.distance_to(b)
	var n: int = int(l / every)
	for i in range(n):
		if rng.randf() > share:
			continue
		var p: Vector3 = a.lerp(b, (float(i) + rng.randf()) / float(maxi(n, 1)))
		var f: Vector3 = (face + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))).normalized()
		_person(p, f, rng.randf_range(0.92, 1.06))


func _sag(a: Vector3, b: Vector3, sag: float, n: int) -> Array:
	var out: Array = []
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		out.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	return out


func _build_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9901
	var count := 0
	var i0: int = floori((-city_near + city_mid.x - grid_origin.x) / grid_cell.x)
	var i1: int = floori((city_near + city_mid.x - grid_origin.x) / grid_cell.x)
	var j0: int = floori((-city_near + city_mid.y - grid_origin.y) / grid_cell.y)
	var j1: int = floori((city_near + city_mid.y - grid_origin.y) / grid_cell.y)
	for i in range(i0, i1 + 1):
		for j in range(j0, j1 + 1):
			var cell := Rect2(grid_origin + Vector2(float(i) * grid_cell.x + grid_street, float(j) * grid_cell.y + grid_street),
					grid_cell - Vector2(grid_street, grid_street))
			var mid: Vector2 = cell.get_center()
			if mid.distance_to(city_mid) > city_near or _river_d(mid.x, mid.y) < river_half + 40.0:
				continue
			# Split the block into one to four plots.
			var plots: Array = []
			var r: float = rng.randf()
			if r < 0.3:
				plots = [cell.grow(-4.0)]
			elif r < 0.65:
				var hx: float = cell.size.x * 0.5
				plots = [Rect2(cell.position, Vector2(hx, cell.size.y)).grow(-4.0), Rect2(cell.position + Vector2(hx, 0), Vector2(hx, cell.size.y)).grow(-4.0)]
			else:
				var hx2: float = cell.size.x * 0.5
				var hz2: float = cell.size.y * 0.5
				for q in [Vector2(0, 0), Vector2(hx2, 0), Vector2(0, hz2), Vector2(hx2, hz2)]:
					plots.append(Rect2(cell.position + q, Vector2(hx2, hz2)).grow(-4.0))
			for pl in plots:
				var plot: Rect2 = pl
				if _reserved_hit(plot):
					continue
				var d: float = plot.get_center().distance_to(city_mid)
				# Under the course the city is mid-rise (the Yunhai Center towers over it); taller toward the far clusters.
				var tall: float = lerpf(city_tall.x, city_tall.y, clampf(d / city_near, 0.0, 1.0))
				# On hilly ground (Wangjiang) a tower stands on the lowest ground under its plot; `top` is its roof's height.
				var g: float = _plot_ground(plot)
				var top: float = g + rng.randf_range(tall * 0.45, tall * 1.25)
				var low: float = _route_low_over(plot, road_half + 14.0)
				if low < INF:
					top = minf(top, low - 18.0)
				if top - g < 14.0:
					continue
				var shrink: float = rng.randf_range(0.0, 0.18)
				var b: Rect2 = plot.grow(-minf(plot.size.x, plot.size.y) * shrink)
				var style: int = [MCK.STYLE_OFFICE, MCK.STYLE_FLATS, MCK.STYLE_FLATS, MCK.STYLE_MEDIA, MCK.STYLE_OFFICE][rng.randi() % 5]
				if style == MCK.STYLE_MEDIA and rng.randf() < 0.6:
					style = MCK.STYLE_OFFICE
				var tint: Color = Color.from_hsv(rng.randf_range(0.05, 0.6), rng.randf_range(0.05, 0.3), rng.randf_range(0.45, 0.75))
				var id := _id()
				var podium: float = 10.0 if top > 40.0 and rng.randf() < 0.7 else 0.0
				var tweak := {"podium": podium, "style": style, "top": top}
				_plot_tweak(plot, tweak)
				podium = tweak["podium"]
				style = tweak["style"]
				top = tweak["top"]
				var key: String = _cell_key("city", Vector3(b.get_center().x, 0, b.get_center().y), 360.0)
				var near_route: bool = low < INF or _route_low_over(plot, 120.0) < INF
				var corners_led: bool = rng.randf() < 0.35
				var led_col := Color.from_hsv(rng.randf(), 0.7, 1.0, 0.0)
				var ch: float = 3.0 if rng.randf() < 0.4 else 0.0
				_city(key, func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
					MCK.tower(pk, kit, b.get_center(), b.size.x * 0.5 - (3.0 if podium > 0.0 else 0.0), b.size.y * 0.5 - (3.0 if podium > 0.0 else 0.0),
							g, top, tint, style, id, ch, podium, corners_led, led_col, near_route)
				, 3200.0)
				count += 1
	print("  city: %d buildings round the course" % count)


## The far skyline: towers to skyline_r as plain boxes in a few big meshes, taller toward clusters, none in the river.
func _build_skyline(_root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9911
	var count := 0
	var clusters: Array = skyline_clusters
	for k in range(5200):
		var a: float = rng.randf() * TAU
		var d: float = sqrt(rng.randf_range(city_near * city_near, skyline_r * skyline_r))
		var c: Vector2 = city_mid + Vector2(cos(a), sin(a)) * d
		if _river_d(c.x, c.y) < river_half + 30.0:
			continue
		var g: float = _natural(c.x, c.y)
		var near_cluster := INF
		for cl in clusters:
			near_cluster = minf(near_cluster, c.distance_to(cl))
		var h: float = rng.randf_range(25.0, 70.0) + 180.0 * exp(-near_cluster * near_cluster / (2.0 * 420.0 * 420.0)) * rng.randf_range(0.5, 1.2)
		var w: float = rng.randf_range(16.0, 34.0)
		var dpt: float = rng.randf_range(16.0, 34.0)
		var style: int = [MCK.STYLE_OFFICE, MCK.STYLE_FLATS, MCK.STYLE_FLATS, MCK.STYLE_MEDIA][rng.randi() % 4] if h < 150.0 or rng.randf() < 0.7 else MCK.STYLE_MEDIA
		var tint: Color = Color.from_hsv(rng.randf_range(0.05, 0.6), rng.randf_range(0.05, 0.3), rng.randf_range(0.45, 0.75))
		var id := _id()
		var key: String = _cell_key("skyline", Vector3(c.x, 0, c.y), 1200.0)
		_city(key, func(pk: PropKit, kit: Dictionary, _l: Array) -> void:
			MCK.prism(pk, kit, MCK.rect_plan(c, w * 0.5, dpt * 0.5), g - 2.0, g + h, tint, style, id, true)
		)
		count += 1
	print("  skyline: %d towers" % count)


func _build_water(root: Node3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "RiverSurface"
	var pm := PlaneMesh.new()
	pm.size = Vector2(12000.0, 12000.0)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.03, 0.05)
	m.roughness = 0.06
	m.metallic = 0.6
	m.metallic_specular = 1.0
	mi.material_override = _save_res(m, "river_material")
	mi.position = Vector3(city_mid.x, water_y, city_mid.y)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
