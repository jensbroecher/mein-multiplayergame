extends Node
## The Miyoshino GP's shared stage generator: what Senbon Sakura Pass, Yoshino Rapids, Monzenmachi and the Yamabushi
## Trail (regenerate_senbon_sakura.gd, regenerate_yoshino_rapids.gd, regenerate_monzenmachi.gd,
## regenerate_yamabushi_trail.gd) have in common. Each of those extends this script, describes itself in `_configure()`
## and overrides the hooks below; `_ready()` here runs the build and saves the level.
##
## Things worth knowing before editing:
##
## 1. A road is a Route: straights and arcs filleted from corner points (x east, z south), measured by s from its start,
##    its height a table per metre (`ys`). The lap is `lap`; shortcuts and side roads are more Routes (`_add_route`).
##    Heights are planned by `_plan_heights`: the natural ground along the route (`_road_base`), bridges laid straight
##    from bank to bank, smoothed, no grade over `max_grade`, then the stage's own `_shape_heights`.
## 2. The ground is one heightfield (fine over `fine_x`/`fine_z`, coarsening out to `outer`) of `_natural(x, z)` graded
##    to every route (`_grade`): GROUND_UNDER under the road across its flat band (which may differ left and right: a
##    cliff walkway's valley side has none), then rounded shoulders rising at the cut slope and falling at the fill
##    slope (`_grade_params`). Bridges (`bridges`: [route name, s0, s1]) are not graded under.
## 3. The roads are ribbons over the ground (miyoshino_road.gdshader; `_sections(route)`: [s0, s1, kind, half width,
##    (clip: 1 the start, 2 the end, 3 both trimmed column by column to the lap's road edge, `_off_lap_column`)]),
##    their triangles the track's collision, one body per surface ("LapRoadAsphalt", "LapRoadDirt", ...: the names
##    say "road", so PlayerCart counts them as track; the `surface` meta says what the tyres are on).
##    The ground's bodies are off-road ("MeadowGround", "EarthGround", "CragGround", "WoodsGround").
## 4. Props come from the Miyoshino kits (MiyoshinoTownKit, MiyoshinoPropKit, MiyoshinoRiverKit: life size, grown by
##    PROP_SCALE) through `_add_prop`, batched into one mesh per key and cell under `prop_prefix`; DressingColliders
##    makes them solid at race time. Keep its skip words and PlayerCart's track words out of batch keys ("gate", "road",
##    "track", "ramp", "bridge", "deck", "jump", "pier", "loop", "line", "light", "lake", "water", "flag", "stack"...).
## 5. Trees are MiyoshinoTrees' (cherries, cedar, maple, bamboo) in MultiMesh cells with far stand-ins, as on Zeche
##    Kronprinz (`_build_woods`, the stage's `_tree_pick`).
##
## A generator runs headless and cannot render; `-- map=<file.png>` also saves a plan of the stage (hillshade, roads,
## a dot every 100m of the lap) and `-- maponly=1` stops after it (seconds), to lay a course out.

const MeshChunker = preload("res://MeshChunker.gd")
const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")
const CrowdPlacer = preload("res://CrowdPlacer.gd")

const K_ASPHALT := 0
const K_STONE := 1
const K_DIRT := 2
const K_PLANKS := 3
const K_GRAVEL := 4
const K_PRECINCT := 5
## A flight of steps: the collision is the ramp along the nosings, the ribbon is not drawn (the stage builds the steps).
const K_STEPS := 6
## A flagged footpath: drawn as stone paving, but off-road to the cars (its body's name says nothing of a road) and
## rock to their tyres: a shortcut that costs speed.
const K_FOOTPATH := 7
const KIND_SURFACE := ["asphalt", "asphalt", "dirt", "wood", "gravel", "gravel", "asphalt", "footpath"]
const SURFACE_BODY := {"asphalt": "LapRoadAsphalt", "dirt": "LapRoadDirt", "wood": "LapRoadWood", "gravel": "LapRoadGravel",
		"footpath": "FootpathStones"}
## What a body's surface is to the tyres where it differs from its key.
const SURFACE_META := {"footpath": "rock"}
const SURFACE_DUST := {"dirt": Color(0.50, 0.40, 0.30, 0.6), "gravel": Color(0.62, 0.60, 0.55, 0.55)}

const PROP_SCALE := 1.6
const GROUND_UNDER := 0.07
const SAMPLE_STEP := 3.0
const CELL := 32.0
const GRADE_REACH := 70.0
const MESH_CHUNK_CELL := 80.0
const COARSE_GROWTH := 1.16
const COARSE_MAX := 180.0
const SPECTATOR_SCALE := PROP_SCALE / 1.86
## A Japanese crowd with a few visitors (CrowdPlacer's skin mix: African, South Asian, European, East Asian, Arab).
const SPECTATOR_SKIN := [0.02, 0.03, 0.10, 0.83, 0.02]


## Straights and arcs through filleted corners, measured by s (metres from its start).
class Route:
	var name := ""
	var segs: Array = []
	var length := 0.0
	var closed := true
	var half := 7.5
	var ys := PackedFloat32Array()
	## For a shortcut: the lap's s where it leaves and joins.
	var from_s := 0.0
	var to_s := 0.0
	## Its own steepest grade (0: the stage's max_grade).
	var grade_max := 0.0
	## A shortcut's cross fall at each end (metres up per metre right of travel), held to `tilt_in` metres from its start
	## and `tilt_out` from its end, then easing out over TILT_FADE: see `tilt`.
	var tilt0 := 0.0
	var tilt1 := 0.0
	var tilt_in := 0.0
	var tilt_out := 0.0
	const TILT_FADE := 14.0

	static func dir_of(th: float) -> Vector2:
		return Vector2(cos(th), sin(th))

	## Right of travel for a heading (x east, z south: heading east has the south on its right).
	static func right_of(th: float) -> Vector2:
		return Vector2(-sin(th), cos(th))

	## Fillets [point, radius] corners. An open path's first and last points are its ends (their radii are ignored).
	func build(corners: Array, is_closed: bool) -> void:
		closed = is_closed
		var n: int = corners.size()
		var a_in: Array = []
		var a_out: Array = []
		var arcs: Array = []
		for i in range(n):
			var b: Vector2 = corners[i][0]
			if not closed and (i == 0 or i == n - 1):
				a_in.append(b)
				a_out.append(b)
				arcs.append(null)
				continue
			var r: float = corners[i][1]
			var a: Vector2 = corners[(i - 1 + n) % n][0]
			var c: Vector2 = corners[(i + 1) % n][0]
			var d1: Vector2 = (b - a).normalized()
			var d2: Vector2 = (c - b).normalized()
			var ang: float = atan2(d1.x * d2.y - d1.y * d2.x, d1.dot(d2))
			var t: float = r * tan(absf(ang) * 0.5)
			var room_a: float = b.distance_to(a) * (1.0 if (not closed and i == 1) else 0.5)
			var room_c: float = b.distance_to(c) * (1.0 if (not closed and i == n - 2) else 0.5)
			if t > room_a + 0.01 or t > room_c + 0.01:
				push_error("%s: corner %d's radius %.0f does not fit (needs %.0fm of each leg, has %.0f and %.0f)" % [name, i, r, t, room_a, room_c])
			a_in.append(b - d1 * t)
			a_out.append(b + d2 * t)
			if absf(ang) < 0.0001 or r <= 0.0:
				arcs.append(null)
			else:
				arcs.append({"kind": "A", "p0": b - d1 * t, "th0": atan2(d1.y, d1.x), "r": r, "sign": signf(ang), "len": r * absf(ang)})
		segs = []
		var s := 0.0
		var prev: Vector2 = a_out[0]
		var k1: int = n + 1 if closed else n
		for k in range(1, k1):
			var i: int = k % n
			var p_in: Vector2 = a_in[i]
			var l: float = prev.distance_to(p_in)
			if l > 0.001:
				var dd: Vector2 = (p_in - prev) / l
				segs.append({"kind": "S", "p0": prev, "th0": atan2(dd.y, dd.x), "len": l, "s0": s})
				s += l
			if arcs[i] != null:
				var arc: Dictionary = (arcs[i] as Dictionary).duplicate()
				arc["s0"] = s
				segs.append(arc)
				s += float(arc["len"])
			prev = a_out[i]
		length = s

	func wrap_s(s: float) -> float:
		return fposmod(s, length) if closed else clampf(s, 0.0, length)

	## Position (x, z), heading and signed curvature at s.
	func at(s: float) -> Dictionary:
		var past := 0.0
		if not closed:
			# Past an open route's ends it runs straight on.
			if s < 0.0:
				past = s
			elif s > length:
				past = s - length
		s = wrap_s(s)
		var seg: Dictionary = segs[0]
		for i in range(segs.size() - 1, -1, -1):
			if s >= float(segs[i]["s0"]) - 0.0001:
				seg = segs[i]
				break
		var dd: float = s - float(seg["s0"])
		var p0: Vector2 = seg["p0"]
		var th0: float = seg["th0"]
		if seg["kind"] == "S":
			return {"p": p0 + dir_of(th0) * (dd + past), "th": th0, "k": 0.0}
		var r: float = seg["r"]
		var sg: float = seg["sign"]
		var c: Vector2 = p0 + right_of(th0) * r * sg
		var th: float = th0 + sg * dd / r
		return {"p": c - right_of(th) * r * sg + dir_of(th) * past, "th": th, "k": sg / r}

	func y(s: float) -> float:
		var n: int = ys.size()
		if n == 0:
			return 0.0
		if closed:
			var f: float = fposmod(s, length)
			var i: int = int(floor(f))
			return lerpf(ys[i % n], ys[(i + 1) % n], f - float(i))
		var g: float = clampf(s, 0.0, float(n - 1))
		var j: int = mini(int(floor(g)), n - 2)
		return lerpf(ys[j], ys[j + 1], g - float(j))

	func pt(s: float) -> Vector3:
		var p: Vector2 = at(s)["p"]
		return Vector3(p.x, y(s), p.y)

	func rt(s: float) -> Vector3:
		var r: Vector2 = right_of(float(at(s)["th"]))
		return Vector3(r.x, 0.0, r.y)

	## The cross fall at s: a shortcut meeting the lap at a slant where the lap climbs leans with the lap's slope at its
	## ends, so both its edges lie on the road's height (held level across, one corner stood over the road's edge and
	## the other sank into the ground graded to it).
	func tilt(s: float) -> float:
		if tilt0 == 0.0 and tilt1 == 0.0:
			return 0.0
		var w0: float = 1.0 - smoothstep(tilt_in, tilt_in + TILT_FADE, s)
		var w1: float = 1.0 - smoothstep(tilt_out, tilt_out + TILT_FADE, length - s)
		return tilt0 * w0 + tilt1 * w1

	## A point on the road's surface: `lat` right of the centreline, with the cross fall.
	func surf(s: float, lat: float) -> Vector3:
		return pt(s) + rt(s) * lat + Vector3(0.0, tilt(s) * lat, 0.0)

	func fw(s: float) -> Vector3:
		var f: Vector2 = dir_of(float(at(s)["th"]))
		return Vector3(f.x, 0.0, f.y)

	## A spot on the route: `lat` metres right of the centreline, `lift` over the road, the yaw facing the way of travel.
	func spot(s: float, lat: float, lift: float) -> Dictionary:
		var fwd: Vector3 = fw(s)
		var right: Vector3 = rt(s)
		var pos: Vector3 = surf(s, lat) + Vector3(0, lift, 0)
		return {"pos": pos, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": right}

	## The s nearest to q in plan (a coarse walk, then a fine one).
	func closest_s(q: Vector2) -> float:
		var best := 0.0
		var bd := INF
		var s := 0.0
		while s <= length:
			var d: float = (at(s)["p"] as Vector2).distance_squared_to(q)
			if d < bd:
				bd = d
				best = s
			s += 4.0
		s = best - 4.0
		var hi: float = best + 4.0
		while s <= hi:
			var d2: float = (at(s)["p"] as Vector2).distance_squared_to(q)
			if d2 < bd:
				bd = d2
				best = s
			s += 0.1
		return wrap_s(best)

	## The grade (rise per metre) at s.
	func grade(s: float) -> float:
		return y(s + 0.5) - y(s - 0.5)


# ---- What a stage sets in _configure().
var level_name := "MiyoshinoLevel"
var level_path := "res://levels/MiyoshinoLevel.tscn"
## The prefix of every generated file ("senbon_"); props, trees, roads and crowd get "<stem>prop_", "<stem>tree_"...
var stem := "miyoshino"
var title := "Miyoshino"
var corners: Array = []
var closed := true
var road_half := 7.5
var fine_x := Vector2(-600.0, 600.0)
var fine_z := Vector2(-600.0, 600.0)
var fine_step := 4.0
var outer := 6000.0
var max_grade := 0.09
var cut_slope := 0.66
var fill_slope := 0.55
## Half the box (metres) the road's height is smoothed with along the route.
var smooth_half := 15
var seed_base := 7100
## [route name, s0, s1, hump]: decks, not graded under.
var bridges: Array = []
## A point-to-point stage: the start gantry at `start_s`, the finish `finish_runout` before the path's end.
var point_to_point := false
var start_s := 60.0
var finish_runout := 120.0
## The finish line's place on a circuit (a point near the lap).
var finish_at := Vector2.ZERO
## What bare ground is to the tyres ("dirt", "gravel", "sand").
var bare_surface := "dirt"
## Colliders are built for ground triangles within this of the fine grid's box.
var collide_margin := 160.0

var level: Node3D
var lap: Route
var routes: Array = []
var _route_by_name := {}

var n_land := FastNoiseLite.new()
var n_hill := FastNoiseLite.new()
var n_wood := FastNoiseLite.new()
var n_fine := FastNoiseLite.new()
var n_ridge := FastNoiseLite.new()

var _seg_a := PackedVector3Array()
var _seg_b := PackedVector3Array()
## Per graded segment: the flat band left and right of the line, the cut and fill slopes.
var _seg_par: Array = []
## Per graded segment: the road's cross fall there (Route.tilt), metres up per metre right of the line.
var _seg_tilt := PackedFloat32Array()
var _seg_cells := {}

var _grid_x := PackedFloat32Array()
var _grid_z := PackedFloat32Array()
var _heights := PackedFloat32Array()
var _road_d := PackedFloat32Array()
var _ground_mat: ShaderMaterial
var _road_mat: ShaderMaterial
var _road_faces := {}

var _batches := {}
var _saved_mats := {}
var _missing := {}
var _occ := {}
var _camp_mats := {}
var _people: Array = []
var _jump_lips: Array = []
var _args := {}
var t_start := 0

var town_kit: Script
var prop_kit: Script
var river_kit: Script


# ======================================================================================
#  Hooks a stage overrides
# ======================================================================================

func _configure() -> void:
	pass


## The natural ground before any road is graded into it.
func _natural(_x: float, _z: float) -> float:
	return 0.0


## The road's height at a point of a route before smoothing (the ground, a touch over it).
func _road_base(_r: Route, _s: float, p: Vector2) -> float:
	return _natural(p.x, p.y) + GROUND_UNDER


## A stage's own shaping of a route's planned heights (kickers, a level square, a flight of steps).
func _shape_heights(_r: Route, _ys: PackedFloat32Array) -> void:
	pass


## [flat band left, flat band right, cut slope, fill slope] for a route's grading at s.
func _grade_params(r: Route, _s: float) -> Array:
	return [r.half + 2.0, r.half + 2.0, cut_slope, fill_slope]


## A route's surface sections: [s0, s1, kind, half width].
func _sections(r: Route) -> Array:
	return [[0.0, r.length, K_ASPHALT, r.half]]


## More routes (shortcuts, side roads): call _add_route here. Runs after the lap's heights are planned.
func _plan_routes() -> void:
	pass


## The ground's masks at a vertex: Color(rock, bare ground, cherry grove, cedar forest); `wet` goes to UV2.y.
func _masks(_i: int, x: float, z: float, nrm_y: float, road_d: float) -> Color:
	var off: float = smoothstep(road_half + 4.0, road_half + 16.0, road_d)
	var rock: float = 1.0 - smoothstep(0.62, 0.78, nrm_y)
	return Color(rock, 0.0, _grove_w(x, z) * off, _forest_w(x, z) * off)


func _wet(_x: float, _z: float) -> float:
	return 0.0


## How much cherry grove (0..1) and cedar forest (0..1) grows at a point.
func _grove_w(_x: float, _z: float) -> float:
	return 0.0


func _forest_w(_x: float, _z: float) -> float:
	return 0.0


## Fallen blossom on the road at a point (0..1).
func _petals_at(x: float, z: float) -> float:
	return clampf(_grove_w(x, z) * 1.4, 0.0, 1.0)


## Sky, sun and fog: overrides of _build_environment's defaults.
func _environment() -> Dictionary:
	return {}


func _ground_params(_m: ShaderMaterial) -> void:
	pass


func _road_params(_m: ShaderMaterial) -> void:
	pass


## Water, structures the roads need (before the gameplay), then gates, pads and jumps, then the dressing.
func _build_water(_root: Node3D) -> void:
	pass


func _place_gameplay(_root: Node3D) -> void:
	pass


func _build_dressing(_root: Node3D) -> void:
	pass


## A tree for a spot: [kind, scale] or [] for none. `roll` is a random 0..1 for the density test.
func _tree_pick(_x: float, _z: float, _roll: float, _rng: RandomNumberGenerator) -> Array:
	return []


## After everything is built, before the level is saved (scripts, sounds, metas).
func _finish(_root: Node3D) -> void:
	pass


# ======================================================================================
#  The build
# ======================================================================================

func _ready() -> void:
	t_start = Time.get_ticks_msec()
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = String(a).split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_configure()
	print("=== %s (Miyoshino GP) Level Generation ===" % title)
	var map_only: bool = _args.has("maponly")
	if not map_only:
		_clear_generated()
	_init_noise()
	lap = Route.new()
	lap.name = "lap"
	lap.half = road_half
	lap.build(corners, closed)
	routes = [lap]
	_route_by_name["lap"] = lap
	_plan_heights(lap)
	_report_profile(lap)
	_plan_routes()
	for r in routes:
		_add_samples(r)
	if map_only:
		fine_step = maxf(fine_step, 8.0)
	_build_heights()
	print("  heights built (%.1fs)" % _secs())
	_check_decks()
	_check_shortcuts_ground()
	if _args.has("map"):
		_save_map(String(_args["map"]))
	if map_only:
		get_tree().quit(0)
		return

	level = Node3D.new()
	level.name = level_name
	level.set_script(load("res://levels/Level.gd"))
	if point_to_point:
		level.set("is_point_to_point", true)
	var players_node := Node3D.new()
	players_node.name = "Players"
	level.add_child(players_node)
	var p_spawner := MultiplayerSpawner.new()
	p_spawner.name = "PlayerSpawner"
	p_spawner.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	p_spawner.spawn_path = NodePath("../Players")
	p_spawner.spawn_limit = 6
	level.add_child(p_spawner)
	var proj_spawner := MultiplayerSpawner.new()
	proj_spawner.name = "ProjectileSpawner"
	proj_spawner.spawn_path = NodePath(".")
	level.add_child(proj_spawner)
	add_child(level)

	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	track_path.curve = _route_curve(lap, 0.0, lap.length)
	level.add_child(track_path)

	var gm := ShaderMaterial.new()
	gm.shader = load("res://miyoshino_ground.gdshader")
	gm.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	gm.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	gm.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	gm.set_shader_parameter("rock_tex", load("res://materials/dark_rock.png"))
	gm.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	gm.set_shader_parameter("gravel_normal", load("res://materials/dark_canyon_rock_normal.png"))
	_ground_params(gm)
	_ground_mat = _save_res(gm, "ground_material") as ShaderMaterial
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	level.add_child(terrain)
	_build_terrain(terrain)
	print("  terrain built (%.1fs)" % _secs())

	var rm := ShaderMaterial.new()
	rm.shader = load("res://miyoshino_road.gdshader")
	rm.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	rm.set_shader_parameter("stone_tex", load("res://materials/concrete.png"))
	rm.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	rm.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	rm.set_shader_parameter("gravel_tex", load("res://materials/dark_canyon_rock.png"))
	rm.set_shader_parameter("wood_tex", load("res://materials/dirt.png"))
	_road_params(rm)
	_road_mat = _save_res(rm, "road_material") as ShaderMaterial
	_build_roads(level)
	_build_water(level)
	_build_environment(level)
	_gameplay_base(level)
	_place_gameplay(level)
	if not _jump_lips.is_empty():
		track_path.set_meta(&"jump_lips", _jump_lips)

	town_kit = _kit_script("res://MiyoshinoTownKit.gd")
	prop_kit = _kit_script("res://MiyoshinoPropKit.gd")
	river_kit = _kit_script("res://MiyoshinoRiverKit.gd")
	_build_dressing(level)
	_clear_people_from_props()
	if not _people.is_empty():
		CrowdPlacer.build(level, _people, SPECTATOR_SCALE, SPECTATOR_SKIN, seed_base + 21,
				func(res: Resource, n: String) -> Resource: return _save_res(res, n, stem + "crowd_"))
	_flush_batches(level)
	_build_woods(level)
	_build_road_bodies(level)
	_build_shortcut_paths(level)
	_finish(level)

	level.set("track_path", track_path)
	level._setup_checkpoints()
	var chunked: int = MeshChunker.chunk_scene(level, "res://generated/" + stem + "_", "res://generated/%s_chunks" % stem, MESH_CHUNK_CELL)
	print("  chunked %d large meshes" % chunked)
	_set_owner_recursive(level, level)
	remove_child(level)
	var packed := PackedScene.new()
	var err = packed.pack(level)
	if err != OK:
		push_error("Failed to pack %s: %d" % [level_path, err])
		get_tree().quit(1)
		return
	err = ResourceSaver.save(packed, level_path)
	if err != OK:
		push_error("Failed to save %s: %d" % [level_path, err])
		get_tree().quit(1)
		return
	print("Saved %s in %.1fs" % [level_path, _secs()])
	get_tree().quit(0)


func _secs() -> float:
	return (Time.get_ticks_msec() - t_start) / 1000.0


func _clear_generated() -> void:
	var gen := DirAccess.open("res://generated/")
	if gen == null:
		return
	var cleared := 0
	for f in gen.get_files():
		if f.begins_with(stem) and (f.ends_with(".res") or f.ends_with(".tscn")):
			gen.remove(f)
			cleared += 1
	var chunks := "res://generated/%s_chunks" % stem
	var cd := DirAccess.open(chunks)
	if cd:
		for f in cd.get_files():
			cd.remove(f)
			cleared += 1
	print("  cleared %d old files" % cleared)


func _init_noise() -> void:
	n_hill.seed = seed_base + 1
	n_hill.frequency = 0.008
	n_hill.fractal_octaves = 3
	n_land.seed = seed_base + 2
	n_land.frequency = 0.0025
	n_land.fractal_octaves = 3
	n_wood.seed = seed_base + 3
	n_wood.frequency = 0.006
	n_wood.fractal_octaves = 3
	n_fine.seed = seed_base + 4
	n_fine.frequency = 0.03
	n_fine.fractal_octaves = 2
	n_ridge.seed = seed_base + 5
	n_ridge.frequency = 0.0011
	n_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	n_ridge.fractal_octaves = 4


# ======================================================================================
#  Routes and their heights
# ======================================================================================

## Another road: a shortcut or a side road, open, its ends on the lap where `pin` says (the lap's height there).
## `pts` are [point, radius] corners; the first and last are its ends.
## `pin_ends`: the route leaves and joins the lap, level with it at both ends; `pin_far_end` false: only its start
## does (a side road running on from the lap's end).
func _add_route(route_name: String, pts: Array, half: float, pin_ends := true, grade_max := 0.0, pin_far_end := true) -> Route:
	var r := Route.new()
	r.name = route_name
	r.half = half
	r.grade_max = grade_max
	r.build(pts, false)
	var pin0 := NAN
	var pin1 := NAN
	if pin_ends:
		r.from_s = lap.closest_s(pts[0][0])
		r.to_s = lap.closest_s(pts[pts.size() - 1][0])
		pin0 = lap.y(r.from_s)
		pin1 = lap.y(r.to_s) if pin_far_end else NAN
	_plan_heights(r, pin0, pin1)
	routes.append(r)
	_route_by_name[route_name] = r
	return r


func _bridges_of(r: Route) -> Array:
	var out: Array = []
	for b in bridges:
		if String(b[0]) == r.name:
			out.append(b)
	return out


func _on_bridge(r: Route, s: float, margin := 0.0) -> bool:
	for b in bridges:
		if String(b[0]) == r.name and s > float(b[1]) + margin and s < float(b[2]) - margin:
			return true
	return false


func _plan_heights(r: Route, pin0 := NAN, pin1 := NAN) -> void:
	var n: int = int(ceil(r.length)) + 1
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in range(n):
		var p: Vector2 = r.at(float(i))["p"]
		raw[i] = _road_base(r, float(i), p)
	# Decks run straight from bank to bank (with a little hump).
	var spans: Array = _bridges_of(r)
	for b in spans:
		var i0: int = clampi(int(floor(float(b[1]))), 0, n - 1)
		var i1: int = clampi(int(ceil(float(b[2]))), 0, n - 1)
		var ya: float = raw[i0]
		var yb: float = raw[i1]
		for i in range(i0, i1 + 1):
			var t: float = float(i - i0) / maxf(float(i1 - i0), 1.0)
			raw[i] = lerpf(ya, yb, t) + float(b[3]) * sin(t * PI)
	var cur := raw
	var sh: int = mini(smooth_half, maxi(2, n / 10))
	for pass_i in range(2):
		var out := PackedFloat32Array()
		out.resize(n)
		for i in range(n):
			var acc := 0.0
			for k in range(-sh, sh + 1):
				acc += cur[_wrap_i(i + k, n, r.closed)]
			out[i] = acc / float(sh * 2 + 1)
		cur = out
	var mg: float = r.grade_max if r.grade_max > 0.0 else max_grade
	# A pinned route (a shortcut) is level with the lap across the lap's own width at both ends.
	var hold: int = 0
	var hold1: int = 0
	var pins := {}
	if not is_nan(pin0):
		# Where it lies on or beside the lap's road, each sample takes the lap's height at its nearest point: pinned to
		# the height at the lap's centreline, a path meeting the lap at a slant stood over the road's edge or under it.
		var reach: float = lap.half + 2.5
		while hold < n / 3 and _lap_offset(r.at(float(hold))["p"]) < reach:
			pins[hold] = lap.y(lap.closest_s(r.at(float(hold))["p"]))
			hold += 1
		var far_pinned: bool = not is_nan(pin1)
		while far_pinned and hold1 < n / 3 and _lap_offset(r.at(float(n - 1 - hold1))["p"]) < reach:
			pins[n - 1 - hold1] = lap.y(lap.closest_s(r.at(float(n - 1 - hold1))["p"]))
			hold1 += 1
		hold = maxi(hold - 1, 0)
		hold1 = maxi(hold1 - 1, 0)
		pin0 = pins.get(hold, pin0)
		pin1 = pins.get(n - 1 - hold1, pin1)
		# Across its width each end leans with the lap's grade where it meets it.
		for e in ([0, 1] if far_pinned else [0]):
			var se: float = 0.0 if e == 0 else r.length
			var sl: float = lap.closest_s(r.at(se)["p"])
			var t_l: Vector3 = lap.fw(sl)
			var lean: float = lap.grade(sl) * r.rt(se).dot(t_l)
			if e == 0:
				r.tilt0 = lean
				r.tilt_in = float(hold) + 1.0
			else:
				r.tilt1 = lean
				r.tilt_out = float(hold1) + 1.0
		if absf(r.tilt0) > 0.005 or absf(r.tilt1) > 0.005:
			print("  %s leans with the lap's grade at its ends: %.1f%% and %.1f%% across" % [r.name, r.tilt0 * 100.0, r.tilt1 * 100.0])
		var d0: float = pin0 - cur[hold]
		var d1: float = pin1 - cur[n - 1 - hold1] if far_pinned else 0.0
		for i in range(n):
			cur[i] += d0 * (1.0 - smoothstep(float(hold), float(hold) + 40.0, float(i))) + d1 * (1.0 - smoothstep(float(hold1), float(hold1) + 40.0, float(n - 1 - i)))
		for i in pins:
			cur[i] = pins[i]
	# No grade over the limit: relax both ways round.
	for iter in range(3 if r.closed else 2):
		for i in range(1, n):
			cur[i] = clampf(cur[i], cur[i - 1] - mg, cur[i - 1] + mg)
		if r.closed:
			cur[0] = clampf(cur[0], cur[n - 1] - mg, cur[n - 1] + mg)
		for i in range(n - 2, -1, -1):
			cur[i] = clampf(cur[i], cur[i + 1] - mg, cur[i + 1] + mg)
		if r.closed:
			cur[n - 1] = clampf(cur[n - 1], cur[0] - mg, cur[0] + mg)
	# Round the vertical curves.
	var sm := cur.duplicate()
	var rh: int = 6 if n > 120 else 3
	for i in range(n):
		var acc2 := 0.0
		for k in range(-rh, rh + 1):
			acc2 += cur[_wrap_i(i + k, n, r.closed)]
		sm[i] = acc2 / float(rh * 2 + 1)
	if not is_nan(pin0):
		for i in pins:
			sm[i] = pins[i]
		# Round the sag (or crest) where the level end meets the climb: the pins end in a kink (a footpath climbing away
		# turned 25% within a metre), which the ground, graded from samples metres apart on a 4m grid, cut across and came
		# up through the paving. Only where an edge is on the lap's own ground (`LAP_GROUND_OWN`) must it keep the lap's
		# height; from there a cubic eases into the profile `END_EASE` metres on, matching both slopes.
		var own: float = lap.half + LAP_GROUND_OWN + 0.25
		for e in ([0, 1] if not is_nan(pin1) else [0]):
			var hb := 0
			while hb < n / 3 and _nearest_lap_edge(r, float(hb if e == 0 else n - 1 - hb)) <= own:
				hb += 1
			hb = maxi(hb, 1)
			var ee: int = mini(hb + END_EASE, n / 2)
			if ee - hb < 4:
				continue
			var ia: int = hb if e == 0 else n - 1 - hb
			var ib: int = ee if e == 0 else n - 1 - ee
			var stp: int = 1 if e == 0 else -1
			var ya: float = sm[ia]
			var yb: float = sm[ib]
			var ga: float = sm[ia] - sm[ia - stp]
			var gb: float = (sm[ib + stp] - sm[ib - stp]) * 0.5
			var L: float = float(ee - hb)
			for k in range(1, ee - hb):
				var t: float = float(k) / L
				var t2: float = t * t
				var t3: float = t2 * t
				sm[ia + k * stp] = (2.0 * t3 - 3.0 * t2 + 1.0) * ya + (t3 - 2.0 * t2 + t) * ga * L + (-2.0 * t3 + 3.0 * t2) * yb + (t3 - t2) * gb * L
		# After the grade clamp a pinned end may not meet the lap: that would be a step in the road.
		if absf(cur[hold + 1] - pin0) > 0.3 or (not is_nan(pin1) and absf(cur[n - 2 - hold1] - pin1) > 0.3):
			push_warning("%s: %s can't reach the lap's height within its grade: %.1fm off at its start, %.1fm at its end" % [
					title, r.name, cur[hold + 1] - pin0, cur[n - 2 - hold1] - pin1])
	_shape_heights(r, sm)
	r.ys = sm


## A shortcut against the ground: where the built ground comes within 3cm of its surface (or over it), grass shows
## through the paving. Prints the worst place.
func _check_shortcuts_ground() -> void:
	for sc in shortcuts:
		var r: Route = _route_by_name.get(String(sc[0]))
		if r == null:
			continue
		var bad := 0
		var worst := -INF
		var worst_at := Vector3.ZERO
		var s := 0.0
		while s <= r.length:
			var h: float = _half_at(r, s)
			var lat: float = -h
			while lat <= h + 0.01:
				var k: int = _kind_at(r, s)
				if k >= 0 and not _on_bridge(r, s):
					var c: Vector2 = _off_lap_column(r, lat)
					if s >= c.x and s <= c.y:
						var p: Vector3 = r.surf(s, lat)
						var over: float = _ground_at(p.x, p.z) - (p.y - 0.03)
						if over > 0.0:
							bad += 1
							if over > worst:
								worst = over
								worst_at = Vector3(s, lat, over)
				lat += h * 0.5
			s += 0.5
		if bad > 0 and worst > 0.12:
			push_warning("%s: ground through %s's paving at %d points, worst %.2fm over it at s %.1f, lateral %.1f" % [
					title, r.name, bad, worst, worst_at.x, worst_at.y])
		elif bad > 0:
			print("  %s: the ground within 3cm of its paving at %d points (worst %.2fm over, s %.1f, lateral %.1f): lifted there" % [
					r.name, bad, worst, worst_at.x, worst_at.y])
		else:
			print("  %s clear of the ground" % r.name)


## Every bridge deck against the ground under it: where the built ground comes within 5cm of the deck's surface (or
## over it) across the deck's width, the grass shows through the planks. Prints each span's worst places.
func _check_decks() -> void:
	for b in bridges:
		var r: Route = _route_by_name.get(String(b[0]))
		if r == null or (b.size() > 4 and bool(b[4])):
			continue
		var bad := 0
		var worst := -INF
		var worst_at := Vector3.ZERO
		var s: float = float(b[1])
		while s <= float(b[2]):
			var h: float = _half_at(r, s)
			var lat: float = -h
			while lat <= h + 0.01:
				var p: Vector3 = r.pt(s) + r.rt(s) * lat
				var over: float = _ground_at(p.x, p.z) - (p.y - 0.05)
				if over > 0.0:
					bad += 1
					if over > worst:
						worst = over
						worst_at = Vector3(s, lat, over)
				lat += 1.0
			s += 1.0
		if bad > 0:
			push_warning("%s: ground through the deck of %s's span %.0f-%.0f at %d points, worst %.2fm over it at s %.0f, lateral %.0f" % [
					title, r.name, float(b[1]), float(b[2]), bad, worst, worst_at.x, worst_at.y])
		else:
			print("  deck %s %.0f-%.0f clear of the ground" % [r.name, float(b[1]), float(b[2])])


## Distance in plan from a point to the lap's centreline.
func _lap_offset(q: Vector2) -> float:
	return (lap.at(lap.closest_s(q))["p"] as Vector2).distance_to(q)


## How near a route's row at s comes to the lap's centreline in plan: the nearer of its centre and its edges.
func _nearest_lap_edge(r: Route, s: float) -> float:
	var a: Dictionary = r.at(s)
	var c: Vector2 = a["p"]
	var rt2: Vector2 = Route.right_of(float(a["th"]))
	return minf(_lap_offset(c), minf(_lap_offset(c + rt2 * r.half), _lap_offset(c - rt2 * r.half)))


## How far a shortcut's profile eases from its level ends into its climb (`_plan_heights`).
const END_EASE := 16



var _off_lap_cache := {}

## How far a shortcut's ribbon stays off the lap's road where it meets it.
const OFF_LAP_MARGIN := 0.2

## Where a column of a shortcut's ribbon (at lateral `lv`) starts and ends: the first and last s at which it is `margin`
## clear of the lap's road.
func _off_lap_column(r: Route, lv: float, margin := OFF_LAP_MARGIN) -> Vector2:
	var key: String = "%s/%.3f/%.3f" % [r.name, lv, margin]
	if _off_lap_cache.has(key):
		return _off_lap_cache[key]
	var off_at := func(s: float) -> float:
		var q: Vector3 = r.pt(s) + r.rt(s) * lv
		return _lap_offset(Vector2(q.x, q.z))
	var need: float = lap.half + margin
	var ends: Array = []
	for dir in [1.0, -1.0]:
		var s0: float = 0.0 if dir > 0.0 else r.length
		var mid: float = r.length * 0.5
		# The last time the column is on the road (a route may start beside the road and cross it at a slant), until it
		# is well clear of it.
		var last_bad := NAN
		var s: float = s0
		while (s <= mid if dir > 0.0 else s >= mid):
			var o: float = off_at.call(s)
			if o < need:
				last_bad = s
			elif o > need + 20.0:
				break
			s += 0.5 * dir
		if is_nan(last_bad):
			ends.append(s0)
			continue
		var lo: float = last_bad
		var hi: float = clampf(last_bad + 0.5 * dir, 0.0, r.length)
		for _i in 6:
			var m: float = (lo + hi) * 0.5
			if off_at.call(m) >= need:
				hi = m
			else:
				lo = m
		ends.append(hi)
	var v := Vector2(ends[0], ends[1])
	_off_lap_cache[key] = v
	return v


## Where a shortcut's own surface starts and ends: from where its first column leaves the lap's road to where its last
## reaches it. A section marked to clip (its fifth field: 1 its start, 2 its end, 3 both) then trims each column to its own `_off_lap_column`, so the
## ribbon's end follows the road's edge: cut square, it lay over the road's edge meeting the lap at a slant, or (held
## back until both edges were clear) left a wedge of grass between them.
func _off_lap_range(r: Route, margin := OFF_LAP_MARGIN) -> Vector2:
	var a: float = INF
	var b: float = -INF
	for lv in [-r.half, -r.half * 0.5, 0.0, r.half * 0.5, r.half]:
		var c: Vector2 = _off_lap_column(r, lv, margin)
		a = minf(a, c.x)
		b = maxf(b, c.y)
	return Vector2(a, b)


func _wrap_i(i: int, n: int, is_closed: bool) -> int:
	if is_closed:
		return ((i % n) + n) % n
	return clampi(i, 0, n - 1)


func _report_profile(r: Route) -> void:
	var lo := INF
	var hi := -INF
	var steep := 0.0
	var at := 0
	for i in range(r.ys.size() - 1):
		lo = minf(lo, r.ys[i])
		hi = maxf(hi, r.ys[i])
		var g: float = absf(r.ys[i + 1] - r.ys[i])
		if g > steep:
			steep = g
			at = i
	print("  %s %.0fm, road from %.1f to %.1fm, steepest %.1f%% at %dm" % [r.name, r.length, lo, hi, steep * 100.0, at])
	if _args.has("profile"):
		var s := 0.0
		while s < r.length:
			var p: Vector2 = r.at(s)["p"]
			print("    s %5.0f  (%7.1f, %7.1f)  y %6.1f  natural %6.1f  grade %5.1f%%" % [s, p.x, p.y, r.y(s), _natural(p.x, p.y), r.grade(s) * 100.0])
			s += 50.0


# Shorthands for the lap.
func _at(s: float) -> Dictionary:
	return lap.at(s)


func _pt(s: float) -> Vector3:
	return lap.pt(s)


func _rt(s: float) -> Vector3:
	return lap.rt(s)


func _fw(s: float) -> Vector3:
	return lap.fw(s)


func _spot(s: float, lat: float, lift: float) -> Dictionary:
	return lap.spot(s, lat, lift)


func _closest_s(q: Vector2) -> float:
	return lap.closest_s(q)


# ======================================================================================
#  The grading and the heightfield
# ======================================================================================

func _add_samples(r: Route) -> void:
	var s := 0.0
	while s < r.length:
		# A shortcut is graded from finer samples: its eased ends curve over a few metres.
		var s2: float = minf(s + (SAMPLE_STEP if r == lap or r.length > 600.0 else 1.5), r.length)
		var mid: float = (s + s2) * 0.5
		if not _on_bridge(r, mid, 1.0):
			var par: Array = _grade_params(r, mid).duplicate()
			par.append(r == lap)
			_add_seg(r.pt(s), r.pt(s2), par, r.tilt(mid))
		elif _cut_under(r, mid):
			# Under a deck the ground may only be cut: DECK_CLEAR under it across its width and a little more, banking up
			# beyond like a cutting (where a road crosses a ravine at a slant, the bank had stood up through the planks).
			var h: float = _half_at(r, mid) + 1.5
			var a: Vector3 = r.pt(s) - Vector3(0, DECK_CLEAR - GROUND_UNDER, 0)
			var b: Vector3 = r.pt(s2) - Vector3(0, DECK_CLEAR - GROUND_UNDER, 0)
			_add_seg(a, b, [h, h, 0.9, 0.0, false, true])
		s = s2


## How far the ground stays under a deck's surface.
const DECK_CLEAR := 0.6

## A shortcut's paving lies at least this far over the built ground (`_build_roads`).
const RIBBON_OVER_GROUND := 0.04

## How far past its road's edge the lap alone sets the ground (`_grade`).
const LAP_GROUND_OWN := 0.5


## Whether the ground under a route's deck at s is cut down under it (not under the rafts, which lie on the water).
func _cut_under(r: Route, s: float) -> bool:
	for b in bridges:
		if String(b[0]) == r.name and s > float(b[1]) and s < float(b[2]):
			return not (b.size() > 4 and bool(b[4]))
	return false


func _add_seg(a: Vector3, b: Vector3, par: Array, tilt := 0.0) -> void:
	_seg_tilt.append(tilt)
	_seg_a.append(a)
	_seg_b.append(b)
	_seg_par.append(par)
	var idx: int = _seg_a.size() - 1
	var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z))
	var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z))
	for gx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
		for gz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
			var key := Vector2i(gx, gz)
			if not _seg_cells.has(key):
				_seg_cells[key] = PackedInt32Array()
			var arr: PackedInt32Array = _seg_cells[key]
			arr.append(idx)
			_seg_cells[key] = arr


## The ground graded to the roads: GROUND_UNDER below a road across its flat band, then rounded shoulders out to the
## natural ground. Returns the height and the distance to the nearest road's centreline.
func _grade(h: float, x: float, z: float) -> Vector2:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var upper := 1e9
	var lower := -1e9
	var touched := false
	var flat_y := NAN
	var flat_lat := 1e9
	var lap_y := NAN
	var lap_lat := 1e9
	var best_d := 1e9
	var cut_touched := false
	var seen := {}
	var reach: int = ceili(GRADE_REACH / CELL)
	for gz in range(cz - reach, cz + reach + 1):
		for gx in range(cx - reach, cx + reach + 1):
			var bucket: PackedInt32Array = _seg_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				if seen.has(i):
					continue
				seen[i] = true
				var a: Vector3 = _seg_a[i]
				var b: Vector3 = _seg_b[i]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = sx * sx + sz * sz
				if l2 < 1e-6:
					continue
				var tu: float = ((x - a.x) * sx + (z - a.z) * sz) / l2
				var t: float = clampf(tu, 0.0, 1.0)
				# Beside the segment, not past its ends: only there does its flat band hold the ground at its height (past
				# the end of the last segment before a deck, it had held the ground up through the deck's first metres).
				var beside: bool = tu >= -0.02 and tu <= 1.02
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				var lateral: float = sqrt(fx * fx + fz * fz)
				if lateral > GRADE_REACH:
					continue
				var par: Array = _seg_par[i]
				if par.size() > 5 and bool(par[5]):
					var cut_y: float = lerpf(a.y, b.y, t) - GROUND_UNDER
					var over_c: float = maxf(0.0, lateral - float(par[0]))
					upper = minf(upper, cut_y + over_c * over_c / (over_c + 4.0) * float(par[2]))
					cut_touched = true
					continue
				best_d = minf(best_d, lateral)
				# Right of travel is (-sz, sx).
				var right: bool = (-sz * fx + sx * fz) >= 0.0
				var flat: float = float(par[1]) if right else float(par[0])
				var foot_y: float = lerpf(a.y, b.y, t) - GROUND_UNDER
				if _seg_tilt[i] != 0.0:
					foot_y += _seg_tilt[i] * clampf(lateral if right else -lateral, -float(par[0]), float(par[1]))
				var over: float = maxf(0.0, lateral - flat)
				var soft: float = over * over / (over + 4.0)
				upper = minf(upper, foot_y + soft * float(par[2]))
				lower = maxf(lower, foot_y - soft * float(par[3]))
				touched = true
				if beside and lateral <= flat and lateral < flat_lat:
					flat_lat = lateral
					flat_y = foot_y
				if beside and par.size() > 4 and bool(par[4]) and lateral <= minf(flat, lap.half + LAP_GROUND_OWN) and lateral < lap_lat:
					lap_lat = lateral
					lap_y = foot_y
	if not touched:
		return Vector2(minf(h, upper) if cut_touched else h, best_d)
	# Under the lap's road and LAP_GROUND_OWN past its edge the lap's height wins: where a shortcut joins it at a grade,
	# the shortcut's flat band (nearer in plan) had lifted the ground up through the lap's road. Only that far: across
	# its whole flat band the lap's verge held the ground at its height under a shortcut meeting it at a slant, and the
	# grass came up through the shortcut's near edge.
	if not is_nan(lap_y):
		return Vector2(minf(lap_y, upper) if cut_touched else lap_y, best_d)
	if not is_nan(flat_y):
		return Vector2(minf(flat_y, upper) if cut_touched else flat_y, best_d)
	var res: float = upper if lower > upper else clampf(h, lower, upper)
	return Vector2(res, best_d)


## Distance in plan to the nearest graded road segment (any route; bridges' spans are not graded and don't count).
func _road_dist(x: float, z: float) -> float:
	var cx: int = floori(x / CELL)
	var cz: int = floori(z / CELL)
	var best := 1e18
	for gz in range(cz - 2, cz + 3):
		for gx in range(cx - 2, cx + 3):
			var bucket: PackedInt32Array = _seg_cells.get(Vector2i(gx, gz), PackedInt32Array())
			for i in bucket:
				var a: Vector3 = _seg_a[i]
				var b: Vector3 = _seg_b[i]
				var sx: float = b.x - a.x
				var sz: float = b.z - a.z
				var l2: float = maxf(sx * sx + sz * sz, 1e-6)
				var t: float = clampf(((x - a.x) * sx + (z - a.z) * sz) / l2, 0.0, 1.0)
				var fx: float = x - (a.x + sx * t)
				var fz: float = z - (a.z + sz * t)
				best = minf(best, fx * fx + fz * fz)
	return sqrt(best) if best < 1e17 else 1e9


## Distance in plan to any route's line, bridges included (a walk along the routes: for placing things, not per vertex).
func _route_dist(x: float, z: float) -> float:
	var d: float = _road_dist(x, z)
	var q := Vector2(x, z)
	for b in bridges:
		var r: Route = _route_by_name.get(String(b[0]))
		if r == null:
			continue
		var s: float = float(b[1])
		while s <= float(b[2]):
			d = minf(d, (r.at(s)["p"] as Vector2).distance_to(q))
			s += 3.0
	return d


func _grid_axis(fine: Vector2) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var left := PackedFloat32Array()
	var step: float = fine_step
	var x: float = fine.x
	while x > -outer:
		step = minf(step * COARSE_GROWTH, COARSE_MAX)
		x -= step
		left.append(maxf(x, -outer))
	left.reverse()
	out.append_array(left)
	var n: int = int(round((fine.y - fine.x) / fine_step))
	for i in range(n + 1):
		out.append(fine.x + float(i) * fine_step)
	step = fine_step
	x = fine.y
	while x < outer:
		step = minf(step * COARSE_GROWTH, COARSE_MAX)
		x += step
		out.append(minf(x, outer))
	return out


## The grid's lines halved inside `ranges` (Vector2 from, to): round the shortcuts' ends, whose paving eases from the
## lap's height into a climb within a few metres, which 4m cells cut across.
func _refine_axis(axis: PackedFloat32Array, ranges: Array) -> PackedFloat32Array:
	if ranges.is_empty():
		return axis
	var out := PackedFloat32Array()
	for i in range(axis.size()):
		out.append(axis[i])
		if i + 1 < axis.size():
			var m: float = (axis[i] + axis[i + 1]) * 0.5
			# Only the fine cells (the coarse ones grow away from the fine area).
			if axis[i + 1] - axis[i] > fine_step * 1.25:
				continue
			for rg in ranges:
				if m > (rg as Vector2).x and m < (rg as Vector2).y:
					out.append(m)
					break
	return out


## More places a stage wants its grid halved: [x ranges, z ranges] (Vector2 from, to); none by default.
func _extra_refine() -> Array:
	return [[], []]


## Where the grid is halved: a square `END_REFINE` either side of each shortcut's ends (and `_extra_refine`).
const END_REFINE := 26.0

func _end_refine_ranges() -> Array:
	var extra: Array = _extra_refine()
	var xs: Array = (extra[0] as Array).duplicate()
	var zs: Array = (extra[1] as Array).duplicate()
	for sc in shortcuts:
		var r: Route = _route_by_name.get(String(sc[0]))
		if r == null:
			continue
		for se in [0.0, r.length]:
			var p: Vector2 = r.at(se)["p"]
			xs.append(Vector2(p.x - END_REFINE, p.x + END_REFINE))
			zs.append(Vector2(p.y - END_REFINE, p.y + END_REFINE))
	return [xs, zs]


func _build_heights() -> void:
	var refine: Array = _end_refine_ranges()
	_grid_x = _refine_axis(_grid_axis(fine_x), refine[0])
	_grid_z = _refine_axis(_grid_axis(fine_z), refine[1])
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	print("  terrain grid %d x %d = %d vertices" % [nx, nz, nx * nz])
	_heights.resize(nx * nz)
	_road_d.resize(nx * nz)
	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var x: float = _grid_x[ix]
			var i: int = iz * nx + ix
			var g: Vector2 = _grade(_natural(x, z), x, z)
			_heights[i] = g.x
			_road_d[i] = minf(g.y, 1.0e7)


## Ground height at any (x, z) from the built heightfield, on the mesh's own triangles.
func _ground_at(x: float, z: float) -> float:
	var ix: int = _bsearch(_grid_x, x)
	var iz: int = _bsearch(_grid_z, z)
	var nx: int = _grid_x.size()
	var x0: float = _grid_x[ix]
	var x1: float = _grid_x[ix + 1]
	var z0: float = _grid_z[iz]
	var z1: float = _grid_z[iz + 1]
	var tx: float = clampf((x - x0) / (x1 - x0), 0.0, 1.0)
	var tz: float = clampf((z - z0) / (z1 - z0), 0.0, 1.0)
	var h00: float = _heights[iz * nx + ix]
	var h10: float = _heights[iz * nx + ix + 1]
	var h01: float = _heights[(iz + 1) * nx + ix]
	var h11: float = _heights[(iz + 1) * nx + ix + 1]
	if absf(h00 - h11) <= absf(h10 - h01):
		if tx >= tz:
			return h00 + (h10 - h00) * tx + (h11 - h10) * tz
		return h00 + (h11 - h01) * tx + (h01 - h00) * tz
	if tx + tz <= 1.0:
		return h00 + (h10 - h00) * tx + (h01 - h00) * tz
	return h11 + (h01 - h11) * (1.0 - tx) + (h10 - h11) * (1.0 - tz)


func _bsearch(arr: PackedFloat32Array, v: float) -> int:
	var lo := 0
	var hi: int = arr.size() - 2
	while lo < hi:
		var mid: int = (lo + hi + 1) >> 1
		if arr[mid] <= v:
			lo = mid
		else:
			hi = mid - 1
	return clampi(lo, 0, arr.size() - 2)


## The slope (rise per metre) of the built ground at a point, over `span` metres.
func _slope_at(x: float, z: float, span := 3.0) -> float:
	var g: float = _ground_at(x, z)
	return Vector2(_ground_at(x + span, z) - g, _ground_at(x, z + span) - g).length() / span


## The lowest and highest ground under a footprint (a w x d rectangle at c turned yaw), sampled every 2m.
## Where something standing at (x, z) stands: the built ground, unless the stage laid something over it there (Yoshino
## Rapids' village sidewalk). `_beside` and the start's crowd stand on it.
func _stand_y(x: float, z: float) -> float:
	return _ground_at(x, z)


func _ground_range(c: Vector2, w: float, d: float, yaw: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var nx: int = maxi(2, ceili(w / 2.0))
	var nz: int = maxi(2, ceili(d / 2.0))
	for i in range(nx + 1):
		for j in range(nz + 1):
			var p: Vector2 = c + ax * (float(i) / float(nx) - 0.5) * w + az * (float(j) / float(nz) - 0.5) * d
			var g: float = _ground_at(p.x, p.y)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	return Vector2(lo, hi)


func _ground_bodies() -> Array:
	return [["MeadowGround", "grass", Color(0, 0, 0, 0)], ["EarthGround", bare_surface, Color(0.52, 0.44, 0.34, 0.55)],
			["CragGround", "rock", Color(0, 0, 0, 0)], ["WoodsGround", "dirt", Color(0.40, 0.31, 0.22, 0.5)]]


func _build_terrain(parent: Node3D) -> void:
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	uvs.resize(nx * nz)
	uv2s.resize(nx * nz)
	for iz in range(nz):
		for ix in range(nx):
			var i: int = iz * nx + ix
			var x: float = _grid_x[ix]
			var z: float = _grid_z[iz]
			verts[i] = Vector3(x, _heights[i], z)
			uvs[i] = Vector2(x, z)
			uv2s[i] = Vector2(minf(_road_d[i], 99.0), _wet(x, z))
			var ixl: int = maxi(ix - 1, 0)
			var ixr: int = mini(ix + 1, nx - 1)
			var izd: int = maxi(iz - 1, 0)
			var izu: int = mini(iz + 1, nz - 1)
			var dhdx: float = (_heights[iz * nx + ixr] - _heights[iz * nx + ixl]) / maxf(_grid_x[ixr] - _grid_x[ixl], 0.01)
			var dhdz: float = (_heights[izu * nx + ix] - _heights[izd * nx + ix]) / maxf(_grid_z[izu] - _grid_z[izd], 0.01)
			var nrm := Vector3(-dhdx, 1.0, -dhdz).normalized()
			normals[i] = nrm
			colors[i] = _masks(i, x, z, nrm.y, _road_d[i])
	var near_idx := PackedInt32Array()
	var far_idx := PackedInt32Array()
	var bodies: Array = _ground_bodies()
	var faces: Array = []
	for b in bodies:
		faces.append(PackedVector3Array())
	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var i: int = iz * nx + ix
			var a: int = i
			var b: int = i + 1
			var c: int = i + nx
			var d: int = i + nx + 1
			var tris: Array
			if absf(_heights[a] - _heights[d]) <= absf(_heights[b] - _heights[c]):
				tris = [[a, b, d], [a, d, c]]
			else:
				tris = [[a, b, c], [b, d, c]]
			for tri in tris:
				var p0: Vector3 = verts[tri[0]]
				var p1: Vector3 = verts[tri[1]]
				var p2: Vector3 = verts[tri[2]]
				if (p2 - p0).cross(p1 - p0).y < 0.0:
					tri = [tri[0], tri[2], tri[1]]
					p1 = verts[tri[1]]
					p2 = verts[tri[2]]
				var far := false
				for k in range(3):
					var v: Vector3 = verts[tri[k]]
					if v.x < fine_x.x or v.x > fine_x.y or v.z < fine_z.x or v.z > fine_z.y:
						far = true
				if far:
					far_idx.append_array([tri[0], tri[1], tri[2]])
				else:
					near_idx.append_array([tri[0], tri[1], tri[2]])
				var cen: Vector3 = (p0 + p1 + p2) / 3.0
				if cen.x < fine_x.x - collide_margin or cen.x > fine_x.y + collide_margin or cen.z < fine_z.x - collide_margin or cen.z > fine_z.y + collide_margin:
					continue
				var rk: float = (colors[tri[0]].r + colors[tri[1]].r + colors[tri[2]].r) / 3.0
				var bg: float = (colors[tri[0]].g + colors[tri[1]].g + colors[tri[2]].g) / 3.0
				var fo: float = (colors[tri[0]].a + colors[tri[1]].a + colors[tri[2]].a) / 3.0
				var k: int = 0
				if rk > 0.5:
					k = 2
				elif bg > 0.5:
					k = 1
				elif fo > 0.6:
					k = 3
				var f: PackedVector3Array = faces[k]
				f.append(p0)
				f.append(p1)
				f.append(p2)
				faces[k] = f
	var near_mesh: ArrayMesh = _compact_mesh2(verts, normals, colors, uvs, uv2s, near_idx, _ground_mat)
	var inst := MeshInstance3D.new()
	inst.name = "GroundMesh"
	inst.mesh = _save_res(near_mesh, "ground_visual")
	parent.add_child(inst)
	var far_mesh: ArrayMesh = _compact_mesh2(verts, normals, colors, uvs, uv2s, far_idx, _ground_mat)
	var far_inst := MeshInstance3D.new()
	far_inst.name = "FarGround"
	far_inst.mesh = _save_res(far_mesh, "ground", stem + "far_")
	far_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(far_inst)
	for k in range(bodies.size()):
		var f: PackedVector3Array = faces[k]
		if f.is_empty():
			continue
		var body := StaticBody3D.new()
		body.name = bodies[k][0]
		body.set_meta(&"surface", bodies[k][1])
		if (bodies[k][2] as Color).a > 0.0:
			body.set_meta(&"dust_color", bodies[k][2])
		parent.add_child(body)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(f)
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		cs.shape = _save_res(shape, String(bodies[k][0]).to_snake_case() + "_shape")
		body.add_child(cs)
		print("  %s: %d triangles" % [bodies[k][0], f.size() / 3])
	print("  ground: %d near and %d far triangles" % [near_idx.size() / 3, far_idx.size() / 3])


func _compact_mesh2(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, uvs: PackedVector2Array,
		uv2s: PackedVector2Array, idx: PackedInt32Array, mat: Material) -> ArrayMesh:
	var remap := PackedInt32Array()
	remap.resize(verts.size())
	remap.fill(-1)
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nc := PackedColorArray()
	var nu := PackedVector2Array()
	var nu2 := PackedVector2Array()
	var ni := PackedInt32Array()
	ni.resize(idx.size())
	for k in range(idx.size()):
		var v: int = idx[k]
		if remap[v] < 0:
			remap[v] = nv.size()
			nv.append(verts[v])
			nn.append(normals[v])
			nc.append(colors[v])
			nu.append(uvs[v])
			nu2.append(uv2s[v])
		ni[k] = remap[v]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = nv
	arrays[Mesh.ARRAY_NORMAL] = nn
	arrays[Mesh.ARRAY_COLOR] = nc
	arrays[Mesh.ARRAY_TEX_UV] = nu
	arrays[Mesh.ARRAY_TEX_UV2] = nu2
	arrays[Mesh.ARRAY_INDEX] = ni
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	return mesh


# ======================================================================================
#  The roads: ribbons and their collision
# ======================================================================================

func _kind_at(r: Route, s: float) -> int:
	for k in _sections(r):
		if s >= float(k[0]) and s < float(k[1]):
			return int(k[2])
	return -1


func _build_roads(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Roads"
	root.add_child(node)
	var piece := 0
	for r in routes:
		var secs: Array = _sections(r)
		var bounds: Array = []
		for k in secs:
			if float(k[0]) > 0.5:
				bounds.append(float(k[0]))
		for sec in secs:
			var s0: float = sec[0]
			var s1: float = sec[1]
			var kind: int = sec[2]
			var w: float = sec[3]
			if s1 - s0 < 0.5:
				continue
			var surface: String = KIND_SURFACE[kind]
			if not _road_faces.has(surface):
				_road_faces[surface] = PackedVector3Array()
			var faces: PackedVector3Array = _road_faces[surface]
			var lats: Array = [-w, -w * 0.5, 0.0, w * 0.5, w]
			# Each column runs from its own start to its own end: trimmed to the lap's road edge where the section says
			# (fifth field: 1 its start, 2 its end, 3 both), else the section's.
			var clip: int = int(sec[4]) if sec.size() > 4 else 0
			var col_a: Array = []
			var col_b: Array = []
			for lv in lats:
				var c := Vector2(s0, s1)
				if clip != 0:
					c = _off_lap_column(r, lv)
				col_a.append(maxf(s0, c.x) if clip & 1 else s0)
				col_b.append(minf(s1, c.y) if clip & 2 else s1)
			if clip != 0:
				print("  %s meets the lap's road edge: its columns start at %s and end at %s" % [r.name,
						", ".join(col_a.map(func(v): return "%.1f" % v)), ", ".join(col_b.map(func(v): return "%.1f" % v))])
			var n_steps: int = maxi(1, ceili(s1 - s0))
			var lifted := 0.0
			var r0 := 0
			while r0 < n_steps:
				var r1: int = mini(r0 + 48, n_steps)
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				for i in range(r0, r1):
					var ta: float = float(i) / float(n_steps)
					var tb: float = float(i + 1) / float(n_steps)
					for j in range(lats.size() - 1):
						var quad: Array = [
								[lerpf(col_a[j], col_b[j], ta), lats[j]], [lerpf(col_a[j + 1], col_b[j + 1], ta), lats[j + 1]],
								[lerpf(col_a[j], col_b[j], tb), lats[j]], [lerpf(col_a[j + 1], col_b[j + 1], tb), lats[j + 1]]]
						for t in [[0, 2, 1], [1, 2, 3]]:
							for k in t:
								var sv: float = quad[k][0]
								var lv: float = quad[k][1]
								var pos: Vector3 = r.surf(sv, lv)
								if r != lap and not _on_bridge(r, sv):
									# Where a shortcut eases from the lap's height into a climb within a few metres, the
									# ground's grid cut across the sag and stood up to 8cm through the paving: never
									# under the ground and RIBBON_OVER_GROUND.
									var gy: float = _ground_at(pos.x, pos.z) + RIBBON_OVER_GROUND
									if gy > pos.y:
										lifted = maxf(lifted, gy - pos.y)
										pos.y = gy
								var edge: float = INF
								for bb in bounds:
									edge = minf(edge, absf(sv - float(bb)))
								var fwd: Vector3 = (r.pt(sv + 0.5) - r.pt(sv - 0.5)).normalized()
								st.set_normal(r.rt(sv).cross(fwd).normalized())
								st.set_color(Color(clampf(edge / 4.0, 0.0, 1.0), _petals_at(pos.x, pos.z), 0.0, 1.0))
								st.set_uv(Vector2(lv, sv))
								st.set_uv2(Vector2(float(K_STONE if kind == K_FOOTPATH else kind), w))
								st.add_vertex(pos)
								faces.append(pos)
				if kind != K_STEPS:
					var mesh: ArrayMesh = st.commit()
					mesh.surface_set_material(0, _road_mat)
					var mi := MeshInstance3D.new()
					mi.name = "Road_%d" % piece
					mi.mesh = _save_res(mesh, "ribbon_%d" % piece, stem + "road_")
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					node.add_child(mi)
					piece += 1
				r0 = r1
			if lifted > 0.0:
				print("  %s %.0f-%.0f: the paving lifted over the ground by up to %.2fm" % [r.name, s0, s1, lifted])
			_road_faces[surface] = faces
	# Decks have sides and an underside (a ribbon alone is a sheet of paper from beside a bridge). Not a span that carries
	# its own deck (fifth field true: Yoshino Rapids' rafts), where the fascia stood up over the bank as a brown wedge.
	for b in bridges:
		var br: Route = _route_by_name.get(String(b[0]))
		if br != null and not (b.size() > 4 and bool(b[4])):
			_build_deck_slab(node, br, float(b[1]), float(b[2]), piece)
			piece += 1
	print("  roads: %d pieces" % piece)


## A deck's fascia and soffit along a bridge span: `DECK_THICK` deep, a hand wider than the ribbon.
const DECK_THICK := 0.45

func _build_deck_slab(node: Node3D, r: Route, s0: float, s1: float, idx: int) -> void:
	var pk := PropKit.new()
	var kit_mat: Material = _deck_material()
	pk.material_for = func(_k: String) -> Material: return kit_mat
	var kit := {}
	var col := Color(0.50, 0.40, 0.30)
	var w: float = _half_at(r, (s0 + s1) * 0.5) + 0.12
	var s: float = s0 - 1.0
	while s < s1 + 1.0:
		var sb: float = minf(s + 3.0, s1 + 1.0)
		var a: Vector3 = r.pt(s)
		var b: Vector3 = r.pt(sb)
		var ra: Vector3 = r.rt(s)
		var rb: Vector3 = r.rt(sb)
		var dn := Vector3(0, -DECK_THICK, 0)
		var top := Vector3(0, -0.03, 0)
		var u0: float = s * 0.5
		var u1: float = sb * 0.5
		for side in [-1.0, 1.0]:
			var pa: Vector3 = a + ra * w * side
			var pb: Vector3 = b + rb * w * side
			pk.quad(kit, "d", [pa + dn, pb + dn, pb + top, pa + top], ra * side, col,
					[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 0.3), Vector2(u0, 0.3)])
		pk.quad(kit, "d", [a - ra * w + dn, b - rb * w + dn, b + rb * w + dn, a + ra * w + dn], Vector3.DOWN, col.darkened(0.3),
				[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, w), Vector2(u0, w)])
		s = sb
	var mi := MeshInstance3D.new()
	mi.name = "DeckSpan_%d" % idx
	mi.mesh = _save_res(pk.commit(kit), "span_%d" % idx, stem + "road_")
	node.add_child(mi)


var _deck_mat: Material

func _deck_material() -> Material:
	if _deck_mat == null:
		var w := ShaderMaterial.new()
		w.shader = load("res://hut_wood.gdshader")
		w.set_shader_parameter("style", 2)
		w.set_shader_parameter("weathering", 0.5)
		_deck_mat = _save_res(w, "deck_side_material")
	return _deck_mat


func _half_at(r: Route, s: float) -> float:
	for k in _sections(r):
		if s >= float(k[0]) and s < float(k[1]):
			return float(k[3])
	return r.half


func _build_road_bodies(root: Node3D) -> void:
	for surface in _road_faces.keys():
		var faces: PackedVector3Array = _road_faces[surface]
		if faces.is_empty():
			continue
		var body := StaticBody3D.new()
		body.name = SURFACE_BODY.get(surface, "LapRoad" + String(surface).capitalize())
		body.set_meta(&"surface", SURFACE_META.get(surface, surface))
		if SURFACE_DUST.has(surface):
			body.set_meta(&"dust_color", SURFACE_DUST[surface])
		var cs := CollisionShape3D.new()
		var sh := ConcavePolygonShape3D.new()
		sh.backface_collision = true
		sh.set_faces(faces)
		cs.shape = _save_res(sh, "road_shape_" + String(surface))
		body.add_child(cs)
		root.add_child(body)
		print("  %s: %d triangles" % [body.name, faces.size() / 3])


## More driven surface (a square's paving, a deck a kit built): triangles for a surface's body.
func _add_road_faces(surface: String, tris: PackedVector3Array) -> void:
	if not _road_faces.has(surface):
		_road_faces[surface] = PackedVector3Array()
	var f: PackedVector3Array = _road_faces[surface]
	f.append_array(tris)
	_road_faces[surface] = f


func _route_curve(r: Route, s0: float, s1: float, lead := 0.0) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var pts: Array = []
	if r.closed:
		var n: int = int(ceil(r.length / 4.0))
		var step: float = r.length / float(n)
		for i in range(n):
			pts.append(r.pt(float(i) * step) + Vector3(0, 0.02, 0))
		for i in range(n + 1):
			var k: int = i % n
			var a: Vector3 = pts[(k - 1 + n) % n]
			var c: Vector3 = pts[(k + 1) % n]
			var hnd: Vector3 = (c - a) / 6.0
			curve.add_point(pts[k], -hnd, hnd)
		return curve
	# An open route; a shortcut is led in and out along the lap (`lead` metres of it either end).
	if lead > 0.0:
		pts.append(lap.pt(r.from_s - lead) + Vector3(0, 0.02, 0))
	var m: int = maxi(2, int(ceil((s1 - s0) / 4.0)))
	for i in range(m + 1):
		pts.append(r.pt(lerpf(s0, s1, float(i) / float(m))) + Vector3(0, 0.02, 0))
	if lead > 0.0:
		pts.append(lap.pt(r.to_s + lead) + Vector3(0, 0.02, 0))
	for i in range(pts.size()):
		var a2: Vector3 = pts[maxi(i - 1, 0)]
		var c2: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var h2: Vector3 = (c2 - a2) / 6.0
		curve.add_point(pts[i], -h2, h2)
	return curve


## [route name, ai_chance_scale] for every route the bots may take as a shortcut (the stage fills it).
var shortcuts: Array = []

func _build_shortcut_paths(root: Node3D) -> void:
	if shortcuts.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "AlternativePaths"
	root.add_child(holder)
	var list: Array[Path3D] = []
	for sc in shortcuts:
		var r: Route = _route_by_name.get(String(sc[0]))
		if r == null:
			continue
		var path := Path3D.new()
		path.name = String(sc[0])
		path.set_meta(&"ai_chance_scale", float(sc[1]))
		path.curve = _route_curve(r, 0.0, r.length, 10.0)
		holder.add_child(path)
		list.append(path)
		var by_lap: float = fposmod(r.to_s - r.from_s, lap.length) if lap.closed else r.to_s - r.from_s
		print("  shortcut %s: %.0fm against the lap's %.0fm (%.0fm to %.0fm)" % [r.name, r.length, by_lap, r.from_s, r.to_s])
	root.set("alternative_paths", list)


# ======================================================================================
#  Gameplay
# ======================================================================================

var _gate_scene: PackedScene
var _boost_scene: PackedScene
var _cps: Node3D
var _pads: Node3D

func _gate(parent: Node, gate_name: String, s: float, finish: bool) -> Node3D:
	var c: Dictionary = lap.spot(s, 0.0, 0.05)
	var g: Node3D = _gate_scene.instantiate()
	g.name = gate_name
	g.position = c["pos"]
	g.rotation_degrees = Vector3(0, c["yaw"], 0)
	if finish:
		g.set("is_finish_line", true)
	parent.add_child(g)
	return g


## The start gantry and its grid, the finish (a point-to-point stage's own), the holders for gates and pads.
func _gameplay_base(root: Node3D) -> void:
	_gate_scene = load("res://CheckpointGate.tscn")
	_boost_scene = load("res://BoostPad.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var holder: Node3D
	if point_to_point:
		holder = _gate(root, "StartLine", start_s, true)
		_gate(root, "FinishLine", lap.length - finish_runout, true)
	else:
		holder = _gate(root, "FinishLine", lap.closest_s(finish_at), true)
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	holder.add_child(spawn_points)
	var grid := [Vector3(-2.9, 0.05, 5.0), Vector3(2.9, 0.05, 5.0), Vector3(-2.9, 0.05, 12.5), Vector3(2.9, 0.05, 12.5),
		Vector3(-2.9, 0.05, 20.0), Vector3(2.9, 0.05, 20.0)]
	for i in range(grid.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid[i]
		spawn_points.add_child(sp)
		var si = spawn_scene.instantiate()
		si.name = "SpawnIndicator"
		sp.add_child(si)
	_cps = Node3D.new()
	_cps.name = "Checkpoints"
	root.add_child(_cps)
	_pads = Node3D.new()
	_pads.name = "BoostPads"
	root.add_child(_pads)


func _finish_s() -> float:
	return lap.length - finish_runout if point_to_point else lap.closest_s(finish_at)


func _checkpoints(at: Array) -> void:
	for i in range(at.size()):
		_gate(_cps, "Checkpoint_%d" % (i + 1), float(at[i]), false)
		print("  checkpoint %d at %.0fm" % [i + 1, float(at[i])])


## Boost pads: [name, s, lateral] on the lap, or [name, s, lateral, route].
func _boosts(pads: Array) -> void:
	for p in pads:
		var r: Route = lap if p.size() < 4 else (_route_by_name[String(p[3])] as Route)
		var b: Node3D = _boost_scene.instantiate()
		b.name = p[0]
		var sp: Dictionary = r.spot(float(p[1]), float(p[2]), 0.08)
		b.position = sp["pos"]
		b.rotation_degrees = Vector3(0, sp["yaw"], 0)
		_pads.add_child(b)


## A wooden kicker across a route, its toe at s: WoodenRamp.tscn, its lip noted for the jump tests.
func _kicker(root: Node3D, jump_name: String, r: Route, toe: float, length: float, height: float, curve := 0.4, trestle := false,
		wood := Color(0.50, 0.38, 0.28)) -> void:
	var j: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	j.name = jump_name
	var sp: Dictionary = r.spot(toe, 0.0, 0.0)
	j.position = sp["pos"]
	j.rotation_degrees = Vector3(0, sp["yaw"], 0)
	j.set("length", length)
	j.set("height", height)
	j.set("curve", curve)
	j.set("width", _half_at(r, toe) * 2.0)
	j.set("trestle", trestle)
	j.set("wood_color", wood)
	root.add_child(j)
	if r == lap:
		var lp: Dictionary = r.spot(toe + length, 0.0, 0.0)
		var slope: float = height / length * (1.0 + curve)
		_jump_lips.append({"name": jump_name, "lip": (lp["pos"] as Vector3) + Vector3(0, height, 0),
				"dir": ((lp["fwd"] as Vector3) + Vector3(0, slope, 0)).normalized()})


# ======================================================================================
#  Sky and light
# ======================================================================================

## A clear spring day by default; the stage's _environment() overrides any of these.
func _build_environment(root: Node3D) -> void:
	var p := {
		"sky_top": Color(0.26, 0.47, 0.80), "sky_horizon": Color(0.80, 0.86, 0.92), "haze": Color(0.82, 0.87, 0.92),
		"ground_bottom": Color(0.40, 0.46, 0.42), "sky_curve": 0.42, "haze_strength": 0.9, "haze_height": 0.16,
		"sun_tint": Color(1.0, 0.96, 0.88), "sun_glow": 0.5, "sun_horizon_tint": Color(1.0, 0.90, 0.78), "sun_horizon_glow": 0.0,
		"cloud_lit": Color(1.0, 0.99, 0.97), "cloud_shade": Color(0.66, 0.70, 0.80), "cloud_coverage": 0.34, "cloud_opacity": 0.9,
		"cloud_scale": 1.25, "cloud_seed": 12.3, "sky_energy": 1.0,
		"ambient": 0.6, "ambient_color": Color(0.92, 0.94, 1.0), "exposure": 1.05, "glow": 0.3, "bloom": 0.05,
		"fog_begin": 180.0, "fog_end": 3400.0, "fog_curve": 1.3, "fog_density": 1.0, "fog_sky": 0.06, "fog_aerial": 0.4,
		"fog_scatter": 0.25,
		"sun_pitch": -50.0, "sun_yaw": 25.0, "sun_color": Color(1.0, 0.96, 0.88), "sun_energy": 1.35, "shadow_distance": 320.0,
	}
	var over: Dictionary = _environment()
	for k in over:
		p[k] = over[k]
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_tropical_cumulus.gdshader")
	sm.set_shader_parameter("sky_top", p["sky_top"])
	sm.set_shader_parameter("sky_horizon", p["sky_horizon"])
	sm.set_shader_parameter("ground_horizon", p["haze"])
	sm.set_shader_parameter("ground_bottom", p["ground_bottom"])
	sm.set_shader_parameter("sky_curve", p["sky_curve"])
	sm.set_shader_parameter("horizon_haze", p["haze"])
	sm.set_shader_parameter("haze_strength", p["haze_strength"])
	sm.set_shader_parameter("haze_height", p["haze_height"])
	sm.set_shader_parameter("sun_tint", p["sun_tint"])
	sm.set_shader_parameter("sun_disc_degrees", 1.1)
	sm.set_shader_parameter("sun_glow", p["sun_glow"])
	sm.set_shader_parameter("sun_horizon_tint", p["sun_horizon_tint"])
	sm.set_shader_parameter("sun_horizon_glow", p["sun_horizon_glow"])
	sm.set_shader_parameter("cloud_lit", p["cloud_lit"])
	sm.set_shader_parameter("cloud_shade", p["cloud_shade"])
	sm.set_shader_parameter("cloud_coverage", p["cloud_coverage"])
	sm.set_shader_parameter("cloud_opacity", p["cloud_opacity"])
	sm.set_shader_parameter("cloud_scale", p["cloud_scale"])
	sm.set_shader_parameter("cloud_seed", p["cloud_seed"])
	if p.has("sky_energy"):
		sm.set_shader_parameter("sky_energy", p["sky_energy"])
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = p["ambient"]
	env.ambient_light_color = p["ambient_color"]
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = p["exposure"]
	env.glow_enabled = true
	env.glow_intensity = p["glow"]
	env.glow_bloom = p["bloom"]
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = p["haze"]
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = p["fog_scatter"]
	env.fog_density = p["fog_density"]
	env.fog_depth_begin = p["fog_begin"]
	env.fog_depth_end = p["fog_end"]
	env.fog_depth_curve = p["fog_curve"]
	env.fog_sky_affect = p["fog_sky"]
	env.fog_aerial_perspective = p["fog_aerial"]
	env_node.environment = env
	root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(p["sun_pitch"], p["sun_yaw"], 0.0)
	sun.light_color = p["sun_color"]
	sun.light_energy = p["sun_energy"]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = p["shadow_distance"]
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	root.add_child(sun)


# ======================================================================================
#  The woods
# ======================================================================================

var tree_cell := 240.0
var tree_far_range := 1900.0
var tree_step := 11.0
## How far past the fine grid trees are planted (stand-ins on the coarse ground).
var tree_margin := 0.0
## Trunks keep this far from a road's line: [kind -> metres], default `tree_clear`.
var tree_clear := 14.0
var tree_clear_kind := {"sakura": 13.0, "yamazakura": 13.0, "shidare": 13.0, "sugi": 11.5, "momiji": 12.0, "momiji_red": 12.0, "take": 11.0}
## Trees placed one by one: [kind, x, z, scale, variant, (base y)]; they are planted whatever stands near, on the ground
## or, given a sixth field, at that height (a roof garden's planter).
var extra_trees: Array = []
## Where every tree was planted: Vector3(x, scale, z).
var _tree_spots: Array = []
const TREE_FALLBACK := {"sakura": "lime", "yamazakura": "birch", "shidare": "alder", "sugi": "spruce", "momiji": "alder", "momiji_red": "alder", "take": "poplar"}

func _build_woods(root: Node3D) -> void:
	var t0 := Time.get_ticks_msec()
	var node := Node3D.new()
	node.name = "Woodland"
	root.add_child(node)
	var miyo: bool = ResourceLoader.exists("res://MiyoshinoTrees.gd") and (load("res://MiyoshinoTrees.gd") as Script).can_instantiate()
	var w = load("res://MiyoshinoTrees.gd").new() if miyo else load("res://WoodlandBuilder.gd").new()
	if not miyo:
		push_warning("%s: MiyoshinoTrees.gd isn't there yet: planting WoodlandBuilder stand-ins" % title)
	var tp: String = stem + "tree_"
	w.save_res = func(res: Resource, n: String) -> Resource: return _save_res(res, n, tp)
	var kinds: Array = []
	var meshes := {}
	var lod_mats: Array[ShaderMaterial] = []
	var leaf_near: ShaderMaterial
	var leaf_far: ShaderMaterial
	if miyo:
		leaf_near = _save_res(w.miyo_leaf_material(1, 0.12, 14.0), "leaf_near", tp)
		leaf_far = _save_res(w.miyo_leaf_material(2, 0.12, 14.0), "leaf_far", tp)
	else:
		leaf_near = _save_res(w.leaf_material(1, 0.14, 18.0), "leaf_near", tp)
		leaf_far = _save_res(w.leaf_material(2, 0.14, 18.0), "leaf_far", tp)
	lod_mats.append(leaf_near)
	lod_mats.append(leaf_far)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base + 41
	var cells := {}
	var counts := {}
	var add := func(kind: String, variant: int, px: float, pz: float, sc: float, base_y: float) -> void:
		var mkey: String = "%s_%d" % [kind, variant]
		if not meshes.has(mkey):
			var real: String = kind if miyo else String(TREE_FALLBACK.get(kind, "oak"))
			var bark_key: String = w.miyo_bark_key(kind) if miyo else real
			var bn: ShaderMaterial = _save_res(w.bark_material(bark_key, 1), "bark_%s_near" % kind, tp)
			var bf: ShaderMaterial = _save_res(w.bark_material(bark_key, 2), "bark_%s_far" % kind, tp)
			lod_mats.append(bn)
			lod_mats.append(bf)
			var near_m: Mesh
			var far_m: Mesh
			if miyo:
				near_m = w.miyo_mesh(kind, variant, 0, bn, leaf_near)
				far_m = w.miyo_mesh(kind, variant, 1, bf, leaf_far)
			else:
				near_m = w.tree_mesh(real, variant, 0, bn, leaf_near)
				far_m = w.tree_mesh(real, variant, 1, bf, leaf_far)
			meshes[mkey] = [_save_res(near_m, "tree_%s" % mkey, tp), _save_res(far_m, "tree_%s_far" % mkey, tp)]
			kinds.append(mkey)
		var mi: int = kinds.find(mkey)
		var g: float = _ground_at(px, pz) if is_nan(base_y) else base_y + 0.3
		var lean := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.05))
		var xf := Transform3D(lean * Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.1), sc)), Vector3(px, g - 0.3, pz))
		var key := Vector3i(floori(px / tree_cell), floori(pz / tree_cell), mi)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(xf)
		counts[kind] = int(counts.get(kind, 0)) + 1
		_tree_spots.append(Vector3(px, sc, pz))
	# Trees the stage placed one by one (avenues, a sacred tree): [kind, x, z, scale, variant].
	for e in extra_trees:
		add.call(String(e[0]), int(e[4]) if e.size() > 4 else 0, float(e[1]), float(e[2]), float(e[3]), float(e[5]) if e.size() > 5 else NAN)
	var step: float = tree_step
	var x: float = fine_x.x - tree_margin + 20.0
	while x < fine_x.y + tree_margin - 20.0:
		var z: float = fine_z.x - tree_margin + 20.0
		while z < fine_z.y + tree_margin - 20.0:
			var px: float = x + rng.randf_range(-0.45, 0.45) * step
			var pz: float = z + rng.randf_range(-0.45, 0.45) * step
			var roll: float = rng.randf()
			z += step
			var pick: Array = _tree_pick(px, pz, roll, rng)
			if pick.is_empty():
				continue
			var kind: String = pick[0]
			if _occupied(px, pz) or _route_dist(px, pz) < float(tree_clear_kind.get(kind, tree_clear)) * maxf(float(pick[1]), 1.0):
				continue
			if _slope_at(px, pz) > 0.75:
				continue
			add.call(kind, int(pick[2]) if pick.size() > 2 else 0, px, pz, float(pick[1]), NAN)
		x += step
	var cell_r: float = tree_cell * 0.72
	var near_end: float = 120.0 + cell_r
	var total := 0
	for key in cells.keys():
		var list: Array = cells[key]
		var mid := Vector3((float(key.x) + 0.5) * tree_cell, 0.0, (float(key.y) + 0.5) * tree_cell)
		var local: Array = []
		for t in list:
			local.append(Transform3D((t as Transform3D).basis, (t as Transform3D).origin - mid))
		var srng := RandomNumberGenerator.new()
		srng.seed = key.x * 7919 + key.y * 104729 + key.z * 31
		for i in range(local.size() - 1, 0, -1):
			var j := srng.randi_range(0, i)
			var tmp: Transform3D = local[i]
			local[i] = local[j]
			local[j] = tmp
		total += local.size()
		var pair: Array = meshes[kinds[key.z]]
		var near_mmi := _multimesh(node, "Tree_%d_%d_%d" % [key.x, key.y, key.z], pair[0], local, near_end, false)
		near_mmi.position = mid
		near_mmi.visibility_range_end_margin = 10.0
		var proxy := _multimesh(node, "TreeShadow_%d_%d_%d" % [key.x, key.y, key.z], pair[1], local, near_end, true)
		proxy.position = mid
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		var far_mmi := _multimesh(node, "Trees_far_%d_%d_%d" % [key.x, key.y, key.z], pair[1], local, tree_far_range, false)
		far_mmi.position = mid
		far_mmi.visibility_range_end_margin = tree_far_range * 0.1
		far_mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		far_mmi.set_meta(&"base_range", tree_far_range)
	var detail := Node3D.new()
	detail.name = "JungleDetail"
	detail.set_script(load("res://JungleDetail.gd"))
	detail.set("lod_materials", lod_mats)
	detail.set("tree_fade", 40.0)
	detail.set("tree_fade_jitter", 12.0)
	detail.set("forest_cell", tree_cell)
	node.add_child(detail)
	print("  trees: %d %s in %d cells (%.1fs)" % [total, str(counts), cells.size(), (Time.get_ticks_msec() - t0) / 1000.0])


# ======================================================================================
#  Props: batches, footprints, people, small helpers
# ======================================================================================

func _kit_script(path: String) -> Script:
	if ResourceLoader.exists(path):
		var sc: Script = load(path)
		if sc != null and sc.can_instantiate():
			return sc
	push_warning("%s: %s isn't there (or doesn't parse) yet" % [title, path])
	return null


func _has_fn(script: Script, fn: String) -> bool:
	if script == null:
		return false
	var cur: Script = script
	while cur != null:
		for m in cur.get_script_method_list():
			if m["name"] == fn:
				return true
		cur = cur.get_base_script()
	return false


## Builds one prop into the batch `key`: `xf` places it rigidly (the kit's life-size frame is grown by PROP_SCALE about
## its origin), `build` is called as build(pk, kit, labels). Labels come back in the kit's life-size coordinates.
func _add_prop(key: String, kit_script: Script, xf: Transform3D, build: Callable, range_end := 0.0) -> void:
	_add_prop_scaled(key, kit_script, xf, build, range_end, PROP_SCALE)


## The same at game scale (bridges and walkways are built in game metres).
func _add_prop_game(key: String, kit_script: Script, xf: Transform3D, build: Callable, range_end := 0.0) -> void:
	_add_prop_scaled(key + "_g", kit_script, xf, build, range_end, 1.0)


func _add_prop_scaled(key: String, kit_script: Script, xf: Transform3D, build: Callable, range_end: float, scale: float) -> void:
	if kit_script == null:
		return
	if not _batches.has(key):
		_batches[key] = {"pk": kit_script.new_kit(scale), "kit": {}, "labels": [], "range": range_end, "script": kit_script, "scale": scale}
	else:
		# The kits keep their UV scale (uvk) in statics shared between them: set it back for this batch's scale.
		kit_script.new_kit(scale)
	var b: Dictionary = _batches[key]
	var pk: PropKit = b["pk"]
	var frame := Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * scale), xf.origin)
	pk.set_frame(frame)
	var labels: Array = []
	build.call(pk, b["kit"], labels)
	for l in labels:
		var out: Array = [l[0], frame * (l[1] as Vector3), (xf.basis * (l[2] as Vector3)).normalized(), float(l[3]) * scale, l[4],
				float(l[5]) * scale if l.size() > 5 else 0.0]
		(b["labels"] as Array).append(out)


## Calls a kit's builder by name, skipping (and warning once about) one the kit lacks.
func _kit_call(script: Script, fn: String, args: Array) -> bool:
	if script == null or not _has_fn(script, fn):
		if not _missing.has(fn):
			_missing[fn] = true
			push_warning("%s: %s has no %s() yet" % [title, script.resource_path.get_file() if script else "(no kit)", fn])
		return false
	script.callv(fn, args)
	return true


## A kit's static value by name (a size, an extent), or `fallback` if the kit or the function is missing.
func _kit_value(script: Script, fn: String, args: Array, fallback: Variant) -> Variant:
	if script == null or not _has_fn(script, fn):
		return fallback
	return script.callv(fn, args)


## The signs' Japanese (the kits and the stages write romaji; `_jp` turns what it knows into this, drawn in Yuji Syuku,
## fonts/YujiSyuku-Regular.ttf, SIL Open Font License). A text not listed stays as it is.
const JP_FONT := "res://fonts/YujiSyuku-Regular.ttf"
const JP := {"CHAYA": "茶屋", "DANGO": "だんご", "HASHI": "箸", "ICHI NO NABIKI": "一の靡", "NI NO NABIKI": "二の靡",
	"SAN NO NABIKI": "三の靡", "YON NO NABIKI": "四の靡", "KAMI SENBON": "上千本", "NAKA SENBON": "中千本",
	"SHIMO SENBON": "下千本", "KANMI": "甘味", "KINGYO": "金魚", "KURA": "蔵", "KUZU": "葛", "MIYAGE": "みやげ", "MOCHI": "餅",
	"OKUGAKE": "奥駈道", "OMEN": "お面", "RINGO AME": "りんご飴", "RYOKAN HANAMINE": "旅館 花峰", "RYOKAN KINPU": "旅館 金峰",
	"RYOKAN SAKURAYA": "旅館 桜屋", "SAKE": "酒", "SANJO": "山上", "SOBA": "そば", "TOZANGUCHI": "登山口", "STOP": "止まれ", "TAKOYAKI": "たこ焼き",
	"TOFU": "豆腐", "UDON": "うどん", "WASHI": "和紙", "YADO YOSHINO": "宿 吉野", "YAMAGOYA": "山小屋",
	"YOSHINO SEIZAI": "吉野製材", "YOSHINO SUGI": "吉野杉"}
var _jp_font: Font

func _jp(text: String) -> String:
	if _jp_font == null:
		_jp_font = load(JP_FONT) if ResourceLoader.exists(JP_FONT) else ThemeDB.fallback_font
	if _jp_font == ThemeDB.fallback_font:
		return text
	return String(JP.get(text, text))


## Footprints (life size, in the prop's frame) of the props people are placed round, by builder; "machiya" is its
## frontage zone in front of the facade only when it is the sweet shop (variant 4: a bench and a parasol out front).
const SOLID_FOOT := {"red_bench": Rect2(-1.0, -0.7, 2.0, 1.3), "stone_lantern": Rect2(-0.65, -0.65, 1.3, 1.3),
	"bonbori": Rect2(-0.3, -0.3, 0.6, 0.6), "komainu": Rect2(-0.5, -0.7, 1.0, 1.4), "vending_machine": Rect2(-0.55, -0.45, 1.1, 0.95),
	"nobori": Rect2(-0.2, -0.2, 0.9, 0.4), "hokora": Rect2(-0.55, -0.5, 1.1, 1.05), "stone_marker": Rect2(-0.25, -0.25, 0.5, 0.5),
	"wood_lantern_post": Rect2(-0.3, -0.3, 0.6, 0.85), "yatai": Rect2(-0.2, -1.95, 3.1, 2.25), "chozuya": Rect2(-1.9, -1.7, 3.8, 3.4),
	"ema_rack": Rect2(-1.6, -0.5, 3.2, 1.0), "kei_truck": Rect2(-0.95, -1.8, 1.9, 3.6), "utility_pole": Rect2(-0.3, -0.3, 0.6, 0.6),
	"koinobori_pole": Rect2(-0.5, -0.5, 1.0, 1.0), "chaya": Rect2(-1.6, -7.1, 12.2, 10.0), "curve_mirror": Rect2(-0.5, -0.3, 1.0, 0.6),
	"cairn": Rect2(-0.45, -0.45, 0.9, 0.9), "sake_barrels": Rect2(-1.5, -0.4, 3.0, 0.8), "bell_tower": Rect2(-4.2, -4.0, 8.4, 8.0),
	"shrine_hall": Rect2(-4.7, -7.4, 9.4, 10.1), "main_hall": Rect2(-13.2, -19.7, 26.4, 28.0), "summit_shrine": Rect2(-2.6, -2.6, 5.2, 5.2),
	"summit_hall": Rect2(-10.0, -15.3, 20.0, 19.0), "pagoda": Rect2(-5.6, -5.6, 11.2, 12.6)}
## [frame, life-size rect] for every prop people must not stand in.
var _solids: Array = []

func _note_solid(fn: String, xf: Transform3D, args: Array) -> void:
	if fn == "machiya":
		if args.size() > 3 and int(args[3]) == 4:
			_solids.append([xf, Rect2(0.0, 0.0, float(args[0]), 3.3)])
		# The house itself (a spectator in front of a house had stood half inside its wall).
		if args.size() > 1:
			_solids.append([xf, Rect2(0.0, -float(args[1]), float(args[0]), float(args[1]) + 0.25)])
		return
	if fn == "jizo_row" and args.size() > 0:
		var n: float = float(args[0])
		_solids.append([xf, Rect2(-0.25 * n - 0.4, -0.45, 0.5 * n + 0.8, 0.9)])
		return
	if SOLID_FOOT.has(fn):
		_solids.append([xf, SOLID_FOOT[fn]])


## Drops the spectators standing inside a prop (a person by a bench, a lantern, a shop's front had come out inside it).
func _clear_people_from_props() -> void:
	var keep: Array = []
	var dropped := 0
	for person in _people:
		var p: Vector3 = person[0]
		var inside := false
		for sd in _solids:
			var xf: Transform3D = sd[0]
			var q: Vector3 = xf.affine_inverse() * p / PROP_SCALE
			var rect: Rect2 = (sd[1] as Rect2).grow(0.3 * float(person[5]))
			if rect.has_point(Vector2(q.x, q.z)) and absf(q.y) < 4.0:
				inside = true
				break
		if inside:
			dropped += 1
		else:
			keep.append(person)
	_people = keep
	print("  people: %d kept, %d dropped from inside props" % [keep.size(), dropped])


## Stands for the labels array in _put's argument list.
const LBL := "@labels"

## One call of a kit's builder into the batch `key` at `xf`: `args` are what follows (pk, kit); LBL stands for the
## labels array. Returns false if the kit lacks the builder.
func _put(key: String, kit_script: Script, xf: Transform3D, fn: String, args: Array = [], range_end := 0.0) -> bool:
	if kit_script == null or not _has_fn(kit_script, fn):
		if not _missing.has(fn):
			_missing[fn] = true
			push_warning("%s: %s has no %s() yet" % [title, kit_script.resource_path.get_file() if kit_script else "(a kit that is missing)", fn])
		return false
	_note_solid(fn, xf, args)
	_add_prop(key, kit_script, xf, func(pk: PropKit, kit: Dictionary, labels: Array) -> void:
		var a: Array = [pk, kit]
		for v in args:
			if v is String and v == LBL:
				a.append(labels)
			elif v is String:
				a.append(_jp(v))
			else:
				a.append(v)
		kit_script.callv(fn, a), range_end)
	return true


## The same for builders that take world points (a railing from a to b): the frame is the world's, grown by
## PROP_SCALE about the origin, so pass points through _life().
func _put_world(prefix: String, at: Vector3, kit_script: Script, fn: String, args: Array = [], range_end := 0.0) -> bool:
	return _put(_cell_key(prefix, at), kit_script, Transform3D.IDENTITY, fn, args, range_end)


## A world point in a world-framed prop's life-size coordinates.
func _life(p: Vector3) -> Vector3:
	return p / PROP_SCALE


## Where other routes (shortcuts, side roads) leave or join `r`: [s0, s1, side] along `r`, the mouth's width and a
## margin either side, on the side the other route lies.
func _route_mouths(r: Route) -> Array:
	var out: Array = []
	if r != lap:
		return out
	for o in routes:
		if o == r or o.closed:
			continue
		for end in [[0.0, 1.0, o.from_s], [o.length, -1.0, o.to_s]]:
			# A point on the other route just past the lap's road edge.
			var probe_s: float = float(end[0]) + float(end[1]) * (r.half + 2.0)
			var q: Vector3 = o.pt(probe_s)
			var s_m: float = r.closest_s(Vector2(q.x, q.z))
			var rel: Vector3 = q - r.pt(s_m)
			var side: float = 1.0 if rel.dot(r.rt(s_m)) >= 0.0 else -1.0
			var w: float = o.half + 7.0
			out.append([s_m - w, s_m + w, side])
	return out


## White guardrails wherever the ground falls away beside a route (more than `drop` under the road within 10m of its
## edge), with colliders: [[s0, s1, side]] of what was built.
func _auto_guardrails(root: Node3D, r: Route, s_from: float, s_to: float, drop := 2.4, skip: Array = []) -> Array:
	var runs: Array = []
	var body: StaticBody3D = _body(root, "GuardrailBody_" + r.name.to_pascal_case())
	for side in [-1.0, 1.0]:
		var run0 := -1.0
		var s: float = s_from
		while s <= s_to + 4.0:
			var bad := false
			if s <= s_to and not _on_bridge(r, s, -6.0):
				var h: float = _half_at(r, s)
				var road_y: float = r.y(s)
				var p: Vector3 = r.pt(s)
				var rt: Vector3 = r.rt(s) * side
				var low: float = INF
				for d in [4.0, 7.0, 10.0]:
					var q: Vector3 = p + rt * (h + d)
					low = minf(low, _ground_at(q.x, q.z))
				bad = road_y - low > drop
				for sk in skip:
					if s > float(sk[0]) and s < float(sk[1]):
						bad = false
			if bad and run0 < 0.0:
				run0 = s
			elif not bad and run0 >= 0.0:
				if s - run0 >= 12.0:
					runs.append([run0 - 6.0, s + 2.0, side])
				run0 = -1.0
			s += 4.0
	# Cut the runs open where a shortcut leaves or joins this route (a guardrail had closed the torii path's exit).
	var mouths: Array = _route_mouths(r)
	var cut: Array = []
	for run in runs:
		var pieces: Array = [[float(run[0]), float(run[1])]]
		for m in mouths:
			if float(m[2]) != float(run[2]):
				continue
			var next: Array = []
			for pc in pieces:
				var a0: float = pc[0]
				var a1: float = pc[1]
				var m0: float = float(m[0])
				var m1: float = float(m[1])
				if m1 <= a0 or m0 >= a1:
					next.append(pc)
					continue
				if m0 - a0 >= 6.0:
					next.append([a0, m0])
				if a1 - m1 >= 6.0:
					next.append([m1, a1])
			pieces = next
		for pc in pieces:
			cut.append([pc[0], pc[1], run[2]])
	runs = cut
	var count := 0
	for run in runs:
		var side: float = run[2]
		var s: float = run[0]
		while s < float(run[1]) - 0.5:
			var sb: float = minf(s + 12.0, float(run[1]))
			var h: float = _half_at(r, s)
			var a: Vector3 = r.pt(s) + r.rt(s) * side * (h + 0.9)
			var b: Vector3 = r.pt(sb) + r.rt(sb) * side * (h + 0.9)
			a.y -= GROUND_UNDER
			b.y -= GROUND_UNDER
			_put_world("guard", a, prop_kit, "guardrail", [_life(a), _life(b)], 600.0)
			count += 1
			s = sb
		_edge_boxes(body, r, float(run[0]), float(run[1]), side * (_half_at(r, float(run[0])) + 0.9), 1.2, 0.4)
	print("  guardrails on %s: %d runs, %d pieces" % [r.name, runs.size(), count])
	return runs


func _cell_key(prefix: String, p: Vector3, cell := 140.0) -> String:
	return "%s_%d_%d" % [prefix, floori(p.x / cell), floori(p.z / cell)]


func _flush_batches(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Scenery"
	root.add_child(node)
	var tris := 0
	var keys: Array = _batches.keys()
	keys.sort()
	var pp: String = stem + "prop_"
	for key in keys:
		var b: Dictionary = _batches[key]
		var pk: PropKit = b["pk"]
		pk.reset_frame()
		if (b["kit"] as Dictionary).is_empty():
			continue
		var mesh: ArrayMesh = (b["script"] as Script).commit(pk, b["kit"])
		for si in range(mesh.get_surface_count()):
			var m: Material = mesh.surface_get_material(si)
			if m == null:
				continue
			if m.resource_path.is_empty():
				var id: int = m.get_instance_id()
				if not _saved_mats.has(id):
					_saved_mats[id] = _save_res(m, "mat_%d" % _saved_mats.size(), pp)
				mesh.surface_set_material(si, _saved_mats[id])
		tris += MeshChunker.triangle_count(mesh)
		var mi := MeshInstance3D.new()
		mi.name = String(key).to_pascal_case()
		mi.mesh = _save_res(mesh, key, pp)
		if float(b["range"]) > 0.0:
			mi.visibility_range_end = float(b["range"])
			mi.visibility_range_end_margin = float(b["range"]) * 0.08
		node.add_child(mi)
		for l in b["labels"]:
			var lab := Label3D.new()
			lab.text = _jp(String(l[0]))
			if _jp_font != null and _jp_font != ThemeDB.fallback_font:
				lab.font = _jp_font
			lab.font_size = 64
			lab.pixel_size = _fit_pixel(lab.text, 64, float(l[3]) / 44.8, float(l[5]))
			lab.modulate = l[4]
			lab.outline_size = 4
			lab.outline_modulate = Color(0.05, 0.05, 0.05)
			lab.double_sided = false
			lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			var n: Vector3 = l[2]
			lab.transform = Transform3D(Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.BACK), l[1])
			if float(b["range"]) > 0.0:
				lab.visibility_range_end = float(b["range"])
			mi.add_child(lab)
	print("  props: %d meshes, %d triangles, %d materials" % [keys.size(), tris, _saved_mats.size()])


func _fit_pixel(text: String, font_size: int, pixel: float, max_w: float) -> float:
	if max_w <= 0.0:
		return pixel
	var f: Font = _jp_font if _jp_font != null else ThemeDB.fallback_font
	var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if w * pixel <= max_w:
		return pixel
	return max_w / maxf(w, 1.0)


## A kit's mesh at life size (for things a script turns, under a node grown by PROP_SCALE), its materials saved.
func _kit_mesh(script: Script, res_name: String, build: Callable, scale := 1.0) -> ArrayMesh:
	if script == null:
		return null
	var pk: PropKit = script.new_kit(scale)
	var kit := {}
	build.call(pk, kit)
	if kit.is_empty():
		return null
	var mesh: ArrayMesh = script.commit(pk, kit)
	var pp: String = stem + "prop_"
	for si in range(mesh.get_surface_count()):
		var m: Material = mesh.surface_get_material(si)
		if m != null and m.resource_path.is_empty():
			var id: int = m.get_instance_id()
			if not _saved_mats.has(id):
				_saved_mats[id] = _save_res(m, "mat_%d" % _saved_mats.size(), pp)
			mesh.surface_set_material(si, _saved_mats[id])
	return _save_res(mesh, res_name, pp)


## A frame facing `face` (its +z) standing upright at `at`.
func _facing(face: Vector3, at: Vector3) -> Transform3D:
	var z := Vector3(face.x, 0.0, face.z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), at)


## A frame beside a route: at s, `lat` right of the line (on the built ground, or what the stage laid over it:
## `_stand_y`), its +z (front) toward the road.
func _beside(r: Route, s: float, lat: float, lift := 0.0) -> Transform3D:
	var sp: Dictionary = r.spot(s, lat, 0.0)
	var pos: Vector3 = sp["pos"]
	pos.y = _stand_y(pos.x, pos.z) + lift
	var face: Vector3 = -(sp["right"] as Vector3) * signf(lat) if absf(lat) > 0.01 else (sp["fwd"] as Vector3)
	return _facing(face, pos)


## A frame across a route (a gate, a torii): at s on the road, its +z back along the way the cars come from.
func _across(r: Route, s: float, lift := 0.0) -> Transform3D:
	var sp: Dictionary = r.spot(s, 0.0, lift)
	return _facing(-(sp["fwd"] as Vector3), sp["pos"])


func _note_rect(c: Vector2, w: float, d: float, yaw: float, margin := 1.0) -> void:
	var ax := Vector2(cos(yaw), -sin(yaw))
	var az := Vector2(sin(yaw), cos(yaw))
	var hw: float = w * 0.5 + margin
	var hd: float = d * 0.5 + margin
	var r: float = sqrt(hw * hw + hd * hd)
	for i in range(floori((c.x - r) / 4.0), floori((c.x + r) / 4.0) + 1):
		for j in range(floori((c.y - r) / 4.0), floori((c.y + r) / 4.0) + 1):
			var q := Vector2((float(i) + 0.5) * 4.0, (float(j) + 0.5) * 4.0) - c
			if absf(q.dot(ax)) < hw + 2.0 and absf(q.dot(az)) < hd + 2.0:
				_occ[Vector2i(i, j)] = true


## Notes the footprint of a prop placed with a frame: `lo` and `hi` its life-size x/z box in the frame.
func _note_frame(xf: Transform3D, lo: Vector2, hi: Vector2, margin := 1.0) -> void:
	var c: Vector3 = xf * (Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.y + hi.y) * 0.5) * PROP_SCALE)
	var yaw: float = atan2(-xf.basis.x.z, xf.basis.x.x)
	_note_rect(Vector2(c.x, c.z), (hi.x - lo.x) * PROP_SCALE, (hi.y - lo.y) * PROP_SCALE, yaw, margin)


func _note_circle(c: Vector2, r: float) -> void:
	_note_rect(c, r * 2.0, r * 2.0, 0.0, 0.0)


func _occupied(x: float, z: float) -> bool:
	return _occ.has(Vector2i(floori(x / 4.0), floori(z / 4.0)))


func _multimesh(parent: Node3D, node_name: String, mesh: Mesh, xfs: Array, range_end := 0.0, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if range_end > 0.0:
		mmi.visibility_range_end = range_end
	parent.add_child(mmi)
	return mmi


func _player(parent: Node3D, node_name: String, path: String, at: Vector3, db: float, unit: float, max_d: float) -> AudioStreamPlayer3D:
	if not ResourceLoader.exists(path):
		push_warning("%s: sound %s is missing" % [title, path])
		return null
	var p := AudioStreamPlayer3D.new()
	p.name = node_name
	p.stream = load(path)
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = max_d
	p.bus = &"SFX"
	p.autoplay = true
	p.position = at
	parent.add_child(p)
	return p


## The RC Vibe GP flag (LogoFlag.gd builds its pole and flag) at s on the lap, `lat` right of its line, streaming away
## from the road so the grid sees it broadside. Placed by Level.gd beside the gantry it had stood by the power lines.
func _logo_flag(root: Node3D, s: float, lat: float, pole := 14.0) -> void:
	var sp: Dictionary = lap.spot(s, lat, 0.0)
	var at: Vector3 = sp["pos"]
	at.y = _ground_at(at.x, at.z)
	var fly: Vector3 = (sp["right"] as Vector3) * signf(lat)
	var flag := Node3D.new()
	flag.name = "LogoFlag"
	flag.set_script(load("res://LogoFlag.gd"))
	flag.set("pole_height", pole)
	flag.transform = Transform3D(Basis(fly, Vector3.UP, fly.cross(Vector3.UP)), at)
	root.add_child(flag)
	_note_circle(Vector2(at.x, at.z), 3.0)
	_solids.append([Transform3D(Basis(), at), Rect2(-0.6, -0.6, 1.2, 1.2)])


## A one-shot struck every `every` seconds on the wall clock (PeriodicSound.gd: LAN peers hear it together).
func _periodic(parent: Node3D, node_name: String, path: String, at: Vector3, db: float, unit: float, max_d: float, every: float, phase: float) -> void:
	if not ResourceLoader.exists(path):
		push_warning("%s: sound %s is missing" % [title, path])
		return
	var p := AudioStreamPlayer3D.new()
	p.set_script(load("res://PeriodicSound.gd"))
	p.name = node_name
	p.stream = load(path)
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = max_d
	p.bus = &"SFX"
	p.position = at
	p.set("every", every)
	p.set("phase", phase)
	parent.add_child(p)


func _camp_material(key: String) -> Material:
	if not _camp_mats.has(key):
		_camp_mats[key] = _save_res(CampKit.make_material(key), "camp_mat_" + key, stem + "prop_")
	return _camp_mats[key]


## A spectator: [position, facing, seated, in a stand, pose (-1: drawn), size].
## The share of the start's crowd in yukata (a stage's festival: Yoshino Rapids).
var crowd_yukata := 0.0

func _person(pos: Vector3, face: Vector3, size := 1.0, seated := false, pose := -1, yukata := false) -> void:
	_people.append([pos, face.normalized(), seated, false, pose, size, yukata])


## Crowd barriers with people behind them along both sides of the lap from s0 to s1 (the start; `tag` names another
## place's, the finish's), each row of people behind them missing `gaps` of the time, `per_row` people a row a barrier.
func _build_start_crowd(root: Node3D, s0: float, s1: float, lat: float, skip_from: float, skip_to: float, seed_v: int,
		sides: Array = [-1.0, 1.0], tag := "Start", gaps: Array = [0.25, 0.6], per_row := 1) -> void:
	var node := Node3D.new()
	node.name = tag + "Venue" if sides.size() == 2 else (tag + "VenueLeft" if float(sides[0]) < 0.0 else tag + "VenueRight")
	root.add_child(node)
	var pk := PropKit.new()
	pk.material_for = func(key: String) -> Material: return _camp_material(key)
	var camp := CampKit.new(pk)
	var bkit := {}
	var body := StaticBody3D.new()
	body.name = tag + "BarriersBody"
	node.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var step: float = 2.3 * PROP_SCALE
	var s: float = s0
	var count := 0
	while s < s1:
		for side in sides:
			if s > skip_from and s < skip_to:
				continue
			var sp: Dictionary = lap.spot(s, side * lat, 0.0)
			var pos: Vector3 = sp["pos"]
			pos.y = _stand_y(pos.x, pos.z)
			var fwd: Vector3 = sp["fwd"]
			var xf := Transform3D(Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)), pos)
			pk.set_frame(xf.scaled_local(Vector3.ONE * PROP_SCALE))
			camp.crowd_barrier(bkit)
			var bs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(step, 1.8, 0.35)
			bs.shape = bx
			bs.transform = Transform3D(xf.basis, pos + Vector3(0, 0.9, 0))
			body.add_child(bs)
			_note_rect(Vector2(pos.x, pos.z), step, 1.0, atan2(fwd.x, fwd.z))
			count += 1
			for slot in range(gaps.size() * per_row):
				var row: int = slot / per_row
				if rng.randf() < float(gaps[row]):
					continue
				var plat: float = side * (lat + 1.6 + float(row) * 1.5 + rng.randf_range(0.0, 0.7))
				var along: float = (float(slot % per_row) + 0.5) / float(per_row) - 0.5
				var ps: Dictionary = lap.spot(s + along * step + rng.randf_range(-1.2, 1.2) / float(per_row), plat, 0.0)
				var pp: Vector3 = ps["pos"]
				pp.y = _stand_y(pp.x, pp.z)
				var face: Vector3 = -(ps["right"] as Vector3) * side
				face = (face + (ps["fwd"] as Vector3) * rng.randf_range(-0.5, 0.5)).normalized()
				_person(pp, face, rng.randf_range(0.9, 1.08), false, -1, crowd_yukata > 0.0 and rng.randf() < crowd_yukata)
		s += step
	pk.reset_frame()
	var bmi := MeshInstance3D.new()
	bmi.name = "Barriers"
	bmi.mesh = _save_res(pk.commit(bkit), tag.to_lower() + "_barriers" + ("" if sides.size() == 2 else ("_l" if float(sides[0]) < 0.0 else "_r")), stem + "prop_")
	bmi.visibility_range_end = 700.0
	node.add_child(bmi)
	print("  %s: %d barriers, %d spectators so far" % [tag.to_lower(), count, _people.size()])


## Box colliders along a route from s0 to s1 at `lat` (right of the line), `h` high over the road.
func _edge_boxes(body: StaticBody3D, r: Route, s0: float, s1: float, lat: float, h: float, thick := 0.5) -> void:
	var s: float = s0
	while s < s1 - 0.5:
		var sb: float = minf(s + 6.0, s1)
		var a: Vector3 = r.pt(s) + r.rt(s) * lat
		var b: Vector3 = r.pt(sb) + r.rt(sb) * lat
		var l: float = a.distance_to(b)
		if l > 0.1:
			var cs := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(thick, h + 0.6, l + 0.3)
			cs.shape = bx
			var fwd: Vector3 = (b - a) / l
			var x: Vector3 = Vector3.UP.cross(fwd).normalized()
			cs.transform = Transform3D(Basis(x, fwd.cross(x).normalized(), fwd).orthonormalized(), (a + b) * 0.5 + Vector3(0, h * 0.5 - 0.3, 0))
			body.add_child(cs)
		s = sb


func _body(root: Node3D, body_name: String) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = body_name
	root.add_child(b)
	return b


func _box_shape(body: StaticBody3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	cs.transform = xf
	body.add_child(cs)


func _save_res(res: Resource, res_name: String, prefix := "") -> Resource:
	if prefix.is_empty():
		prefix = stem + "_"
	if not DirAccess.dir_exists_absolute("res://generated/"):
		DirAccess.make_dir_absolute("res://generated/")
	var file_path: String = "res://generated/" + prefix + res_name + ".res"
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	return load(file_path)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)


func _rect_weight(x: float, z: float, r: Array, blend: float) -> float:
	var dx: float = maxf(float(r[0]) - x, x - float(r[2]))
	var dz: float = maxf(float(r[1]) - z, z - float(r[3]))
	return 1.0 - smoothstep(0.0, blend, maxf(dx, dz))


func _in_rect(x: float, z: float, r: Array, pad := 0.0) -> bool:
	return x > float(r[0]) - pad and x < float(r[2]) + pad and z > float(r[1]) - pad and z < float(r[3]) + pad


## Cubic Hermite from (x0, y0, slope m0) to (x1, y1, slope m1), clamped outside.
func _hermite(x: float, x0: float, y0: float, m0: float, x1: float, y1: float, m1: float) -> float:
	var h: float = x1 - x0
	var t: float = clampf((x - x0) / h, 0.0, 1.0)
	var t2: float = t * t
	var t3: float = t2 * t
	return (2.0 * t3 - 3.0 * t2 + 1.0) * y0 + (t3 - 2.0 * t2 + t) * h * m0 + (-2.0 * t3 + 3.0 * t2) * y1 + (t3 - t2) * h * m1


# ======================================================================================
#  The plan of the stage as a picture (-- map=<file.png>)
# ======================================================================================

## What stands in water at a point for the map: its surface height, or NAN (a stage with water overrides it).
func _map_water(_x: float, _z: float) -> float:
	return NAN


func _save_map(path: String) -> void:
	var px := 2.0
	var w: int = int((fine_x.y - fine_x.x) / px)
	var h: int = int((fine_z.y - fine_z.x) / px)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var lo := INF
	var hi := -INF
	for j in range(0, h, 8):
		for i in range(0, w, 8):
			var g: float = _ground_at(fine_x.x + float(i) * px, fine_z.x + float(j) * px)
			lo = minf(lo, g)
			hi = maxf(hi, g)
	for j in range(h):
		for i in range(w):
			var x: float = fine_x.x + (float(i) + 0.5) * px
			var z: float = fine_z.x + (float(j) + 0.5) * px
			var g: float = _ground_at(x, z)
			var gx: float = _ground_at(x + px, z) - g
			var gz: float = _ground_at(x, z + px) - g
			var nrm := Vector3(-gx / px, 1.0, -gz / px).normalized()
			var shade: float = clampf(0.35 + 0.75 * nrm.dot(Vector3(-0.5, 0.7, -0.5).normalized()), 0.0, 1.2)
			var t: float = (g - lo) / maxf(hi - lo, 1.0)
			var col: Color = Color(0.35, 0.50, 0.28).lerp(Color(0.72, 0.66, 0.50), t) * shade
			# Contours every 10m.
			if absf(fposmod(g, 10.0) - 5.0) > 4.75:
				col = col.darkened(0.25)
			var wy: float = _map_water(x, z)
			if not is_nan(wy) and g < wy:
				col = Color(0.20, 0.45, 0.75).lerp(Color(0.10, 0.22, 0.50), clampf((wy - g) / 2.0, 0.0, 1.0))
			img.set_pixel(i, j, col)
	var dot := func(p: Vector2, r: int, col: Color) -> void:
		var ci: int = int((p.x - fine_x.x) / px)
		var cj: int = int((p.y - fine_z.x) / px)
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if di * di + dj * dj <= r * r and ci + di >= 0 and ci + di < w and cj + dj >= 0 and cj + dj < h:
					img.set_pixel(ci + di, cj + dj, col)
	for r in routes:
		var is_lap: bool = r == lap
		var s := 0.0
		while s < r.length:
			var p: Vector2 = r.at(s)["p"]
			var kind: int = _kind_at(r, s)
			var c: Color = Color(1, 1, 1) if is_lap else Color(1.0, 0.9, 0.2)
			if kind == K_DIRT or kind == K_GRAVEL:
				c = c.darkened(0.25)
			if _on_bridge(r, s):
				c = Color(1.0, 0.4, 0.3)
			dot.call(p, 2 if is_lap else 1, c)
			s += 1.5
	var s2 := 0.0
	var k := 0
	while s2 < lap.length:
		var p2: Vector2 = lap.at(s2)["p"]
		dot.call(p2, 5 if k % 5 == 0 else 3, Color(0.9, 0.1, 0.1) if k % 5 != 0 else Color(0.1, 0.1, 0.9))
		s2 += 100.0
		k += 1
	dot.call(lap.at(0.0)["p"], 7, Color(0, 0, 0))
	img.save_png(path)
	print("  map saved to %s (%d x %d px at %.0fm a pixel; x %.0f..%.0f east, z %.0f..%.0f south; ground %.0f..%.0fm; a red dot every 100m of the lap, blue every 500m, black at s 0)" % [
			path, w, h, px, fine_x.x, fine_x.y, fine_z.x, fine_z.y, lo, hi])
