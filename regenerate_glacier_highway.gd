# regenerate_glacier_highway.gd
# Generates levels/GlacierHighwayLevel.tscn for the Arctic Cup:
# - Concrete highway design with PBR concrete road deck, highway lane striping shader
# - Continuous concrete Jersey side barriers along all roads, ramps, and viaducts
# - 3 Multi-divergence zones with on- and off-ramps (Express Flyover, Gorge Service Cut, Twin Overpass).
#   Every ramp starts and ends as a nose sitting on the trunk deck edge with trunk-tangent
#   handles, and the trunk barrier gaps are measured off the ramp geometry, so a junction can
#   never end up with overlapping road decks or a guardrail standing across a ramp mouth.
# - Track self-intersection: cars go through an illuminated mountain tunnel directly underneath the elevated highway overpass
# - Procedural alpine terrain: noise-driven glacier valley with ridged snow-capped ranges, a
#   graded shelf (cut and filled) under every carriageway, a crevasse for the Gorge Cut, and a
#   rock spur with a bored tunnel for the underpass. Meshes are written to res://generated/.
# - Checkpoint sequence, starting grid, boost pads, item boxes, and highway infrastructure
extends Node

var main_track_curve: Curve3D

# --- Jersey crash barrier cross-section -----------------------------------------
# u = metres inward from the deck edge, v = metres relative to the deck surface.
# The toe and back foot sit 6cm BELOW the deck so the barrier is embedded in the
# road slab and no coplanar surface fights with the road mesh.
const MeshChunker = preload("res://MeshChunker.gd")
## Level-spanning visual meshes (road ribbons, barriers, terrain) are split into cells this size
## before saving, so cameras and shadow passes (every streetlight's included) draw only the cells
## they can see instead of the whole track. Geometry is unchanged.
const MESH_CHUNK_CELL := 80.0

const BARRIER_PROFILE := [
	Vector2(0.60, -0.06), # road-side toe
	Vector2(0.52, 0.075), # lower slope break (the "kick")
	Vector2(0.30, 0.330), # upper slope break
	Vector2(0.20, 0.810), # top, road side
	Vector2(0.00, 0.810), # top, deck edge
	Vector2(0.00, -0.06), # back foot
]
const BARRIER_VERTS := 6
## Metres over which a barrier run tapers down to deck level at an open end, so a
## gap reads as a real sloped terminal instead of a sliver poking out of the road.
const BARRIER_TERMINAL := 2.4
## Clearance the main barrier keeps from a ramp deck before it may close again.
const GORE_CLEARANCE := 2.5

## Trunk carriageway and ramp widths. A ramp nose is placed exactly one trunk half width
## off the centreline, which is what lets the two decks tile without overlapping.
const MAIN_WIDTH := 16.0
const MAIN_HALF_W := 8.0
const RAMP_WIDTH := 11.5
const RAMP_HALF_W := 5.75
## Minimum turn radius targeted when deriving curve handles. The deck's inner edge sits at
## radius - half_width, so anything near half_width folds the road through itself.
const TRUNK_MIN_RADIUS := 34.0
const RAMP_MIN_RADIUS := 30.0
## Tangential run of a ramp nose along the trunk before it starts to peel away.
const RAMP_NOSE_HANDLE := 22.0
## How far along the trunk the auto-generated entry/exit waypoints sit before stepping out.
const RAMP_NOSE_LEAD := 34.0
## Lateral offset a ramp must exceed before the trunk barrier may close again. Past this the ramp
## deck has genuinely left the trunk shoulder; below it the two decks still meet.
const RAMP_GORE_LATERAL := 13.75

# --- Terrain --------------------------------------------------------------------
## Valley heightfield extent / resolution. 5m cells over 1.1km: fine enough to read as
## ground under the elevated sections, coarse enough to stay cheap.
const ALPINE_TERRAIN_SIZE := 1100.0
const ALPINE_TERRAIN_RES := 220
const ALPINE_TERRAIN_CENTER := Vector2(10.0, -20.0)
## Horizontal reach of a graded road corridor, and the cell size of the carriageway index.
const ROAD_CORRIDOR_RADIUS := 48.0
const ROAD_CELL := 48.0
## Tunnel massif footprint and bore, shared with the portal placement. The footprint's Z edges
## are a whole number of cells away from the portal planes so a cell row lands exactly on each
## portal, and the bore is cut as a channel right through the spur so both portals are open.
const TUNNEL_MASSIF_MIN := Vector2(-150.0, -248.0)
const TUNNEL_MASSIF_MAX := Vector2(150.0, -172.0)
const TUNNEL_Z_NORTH := -240.0
const TUNNEL_Z_SOUTH := -180.0
const TUNNEL_BORE_HALF_W := 12.0
const TUNNEL_ROOF_Y := 9.6
## Road deck level inside the tunnel, used for the bore clearance check.
const TUNNEL_DECK_Y := 2.8
## Thickness of the concrete slab that closes the gap between the tunnel's visible ceiling and
## the rock roof, so no sliver of sky shows through from inside.
const TUNNEL_LINER_TOP := 9.8

## Every carriageway the terrain has to make room for, filled in as the curves are built.
var ROAD_CURVES: Array = []
var _road_xz := PackedVector2Array()
var _road_y := PackedFloat32Array()
var _road_cells := Dictionary()
var _base_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()

func _init_noise() -> void:
	_base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base_noise.seed = 20482
	_base_noise.frequency = 0.0055
	_base_noise.fractal_octaves = 3

	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.seed = 7731
	_detail_noise.frequency = 0.017
	_detail_noise.fractal_octaves = 3

	# Ridged multifractal gives the ranges real crests and gullies.
	_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridge_noise.seed = 90125
	_ridge_noise.frequency = 0.0042
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge_noise.fractal_octaves = 5
	_ridge_noise.fractal_lacunarity = 2.1
	_ridge_noise.fractal_gain = 0.52

## Handles for one control point, from the directions and lengths of the segments either side.
##
## The tangent bisects the incoming and outgoing travel directions, and its length is whatever
## Catmull-Rom wants or whatever the turn radius needs, capped so the control polygon cannot fold
## back on itself. A dead-straight reversal has no bisector, so that case falls back to the
## horizontal perpendicular that points along the chord across the corner.
func _handles_for(seg_in: Vector3, seg_out: Vector3, min_radius: float) -> Array:
	var l_in: float = seg_in.length()
	var l_out: float = seg_out.length()
	# A zero-length segment (a waypoint sitting on top of its neighbour) has no direction, and
	# inventing one from FORWARD is what puts a kink in the curve. Fall back to the other side.
	var u_in: Vector3 = seg_in / l_in if l_in > 0.001 else (seg_out.normalized() if l_out > 0.001 else Vector3.FORWARD)
	var u_out: Vector3 = seg_out / l_out if l_out > 0.001 else u_in
	var dir: Vector3 = u_in + u_out
	if dir.length_squared() < 0.02:
		var perp := Vector3(-u_in.z, 0.0, u_in.x)
		if perp.length_squared() < 1e-6:
			perp = Vector3.RIGHT
		dir = perp.normalized()
		if dir.dot(seg_in + seg_out) < 0.0:
			dir = -dir
	else:
		dir = dir.normalized()
	# A cubic approximates a circular arc of angle theta with handle (4/3)tan(theta/4)R.
	var theta: float = u_in.angle_to(u_out)
	var needed: float = (4.0 / 3.0) * tan(theta * 0.25) * min_radius
	var catmull: float = (l_in + l_out) / 6.0
	var ceiling: float = 0.45 * minf(l_in, l_out)
	var h: float = clampf(maxf(needed, catmull), 2.0, maxf(ceiling, 2.0))
	return [dir * -h, dir * h, needed > ceiling]

## Builds a closed loop curve from bare positions, deriving every handle from the geometry.
##
## Hand-picked handles are the trap here: if a control polygon's handles overshoot each other
## the curve grows a loop, and a loop puts a cusp in the baked points. At a cusp the road's
## cross-sections swing tens of degrees between rings 15cm apart, which folds the deck through
## itself and makes both the surface and the barriers flicker. Handles are therefore computed
## so that
##   - the tangent at each point matches the actual approach and exit directions, and
##   - the turn is wide enough for the deck (a cubic approximates a circular arc of angle
##     theta with handle length (4/3)tan(theta/4)R, so R follows from the handle length).
##
## `rows` are positions; the returned curve appends a closing copy of the first point.
func _build_closed_loop(points: Array, min_radius: float) -> Curve3D:
	var n: int = points.size()
	var handles: Array = []
	for i in range(n):
		var prev: Vector3 = points[(i - 1 + n) % n]
		var cur: Vector3 = points[i]
		var nxt: Vector3 = points[(i + 1) % n]
		var h: Array = _handles_for(cur - prev, nxt - cur, min_radius)
		handles.append(h)
		if h[2]:
			push_warning("Control point %d wants a %.0fm radius but its %.0fm chord only allows it; insert a point there" % [
				i, min_radius, (nxt - prev).length() * 0.5])

	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	for i in range(n + 1):
		var idx: int = i % n
		curve.add_point(points[idx], handles[idx][0], handles[idx][1])
	return curve

## Fails the build if the trunk barrier would stand across any ramp mouth. Cheap insurance:
## the gaps are an optional tail argument, so a call site can silently leave them empty and wall
## every alternative route off without anything else noticing.
func _verify_barrier_gaps(a: Curve3D, b: Curve3D, c: Curve3D, left_gaps: Array, right_gaps: Array) -> void:
	var blocked := 0
	for entry in [[a, "express flyover", 1], [b, "gorge cut", 1], [c, "ridge bypass", -1]]:
		var rc: Curve3D = entry[0]
		var length: float = rc.get_baked_length()
		for end_i in [0, length]:
			var nose: Vector3 = rc.sample_baked(end_i)
			var off: float = main_track_curve.get_closest_offset(nose)
			var gaps: Array = right_gaps if entry[2] > 0 else left_gaps
			var f: float = _barrier_factor_at(off, gaps)
			if f > 0.0:
				blocked += 1
				push_error("Trunk barrier is %.0f%% up across the %s junction at offset %.0fm" % [f * 100.0, entry[1], off])
	if blocked == 0:
		print("  trunk barrier open at all 6 ramp junctions")

## Trunk curve position / tangent / right vector at `off` metres along the circuit.
func _trunk_frame(off: float) -> Dictionary:
	var length: float = main_track_curve.get_baked_length()
	off = clampf(off, 0.0, length)
	var p: Vector3 = main_track_curve.sample_baked(off)
	var nxt: Vector3 = main_track_curve.sample_baked(minf(length, off + 1.0))
	var fwd: Vector3 = (nxt - p).normalized()
	return {"pos": p, "fwd": fwd, "right": Vector3(-fwd.z, 0.0, fwd.x).normalized()}

## Assembles an alternative-route curve whose ends are noses sitting exactly on the trunk
## deck edge (`side` = +1 right / -1 left), with the junction handles aligned to the trunk
## tangent so ramps leave and rejoin the highway tangentially instead of kinking across it.
##
## Junctions are given as world anchors rather than distances along the trunk, so they stay
## where they were authored even when the trunk's own shape is retuned.
##
## `waypoints` are plain positions between the two noses. Interior handles are derived
## Catmull-Rom style against the trunk direction at each end, so the tangent stays continuous
## across the junction; deriving them from the nose position instead leaves a kink where a
## straight nose meets an angled waypoint, which shows up as a pinch in the deck.
func _build_ramp_curve(split_anchor: Vector3, merge_anchor: Vector3, side: int, waypoints: Array,
		entry_lateral: float, exit_lateral: float) -> Curve3D:
	var split: Dictionary = _trunk_frame_at(main_track_curve, split_anchor)
	var merge: Dictionary = _trunk_frame_at(main_track_curve, merge_anchor)
	var s_fwd: Vector3 = split["fwd"]
	var m_fwd: Vector3 = merge["fwd"]
	var s_right: Vector3 = split["right"]
	var m_right: Vector3 = merge["right"]
	var nose_a: Vector3 = split["pos"] + s_right * (MAIN_HALF_W * float(side))
	var nose_b: Vector3 = merge["pos"] + m_right * (MAIN_HALF_W * float(side))

	# The first and last waypoints are offsets of the *curve* `lead` metres before/after the
	# junction. Authoring them as free points leaves whatever angle the author happened to pick
	# between the straight nose and the next waypoint, which shows up as a pinch in the deck a few
	# metres past the junction. Walking the curve rather than stepping in a straight line matters
	# where the trunk turns: a chord from the junction lands well short of the intended offset.
	var lead: float = RAMP_NOSE_LEAD
	var length: float = main_track_curve.get_baked_length()
	# The approach and departure waypoints are pure *offsets of the trunk itself*: at a fixed
	# distance before the split, and before the merge. Anchoring them to the trunk curve is what
	# guarantees the ramp leaves and rejoins along the highway's own tangent no matter how the
	# trunk is retuned, which is what keeps the junction kink-free.
	# The approach and departure waypoints are pure *offsets of the trunk*: `lead` metres past the
	# split, and `lead` metres before the merge. Anchoring them to the trunk curve is what makes
	# the ramp leave and rejoin along the highway's own tangent however the trunk is retuned.
	#
	# Both are measured in the direction of travel and clamped inside the trunk, so they can never
	# invert on a junction near the start or the finish.
	var fa: Dictionary = _trunk_frame_at_offset(main_track_curve, clampf(split["off"] + lead, 0.0, length))
	var fb: Dictionary = _trunk_frame_at_offset(main_track_curve, clampf(merge["off"] - lead, 0.0, length))
	var entry: Vector3 = fa["pos"] + fa["right"] * (float(side) * entry_lateral)
	var exit_pt: Vector3 = fb["pos"] + fb["right"] * (float(side) * exit_lateral)
	var pts: Array = [nose_a, entry]
	pts.append_array(waypoints)
	pts.append(exit_pt)
	pts.append(nose_b)

	# The first and last segment of a ramp leave and arrive *along the trunk*, so the interior
	# handles are derived against those directions rather than against the nose position.
	var first_len: float = (pts[1] - pts[0]).length()
	var last_len: float = (pts[pts.size() - 1] - pts[pts.size() - 2]).length()
	var segs_in := PackedVector3Array()
	var segs_out := PackedVector3Array()
	for i in range(pts.size()):
		var prev_p: Vector3 = pts[i - 1] if i > 0 else pts[0] - s_fwd * first_len
		var next_p: Vector3 = pts[i + 1] if i < pts.size() - 1 else pts[pts.size() - 1] + m_fwd * last_len
		segs_in.append(pts[i] - prev_p)
		segs_out.append(next_p - pts[i])

	var c := Curve3D.new()
	c.bake_interval = 0.25
	for i in range(pts.size()):
		var in_h: Vector3
		var out_h: Vector3
		if i == 0:
			# The nose is a straight continuation of the trunk edge, so the gore opens without
			# a kink and the ramp tracks the shoulder before it peels away.
			in_h = -s_fwd * minf(RAMP_NOSE_HANDLE, first_len)
			out_h = s_fwd * minf(RAMP_NOSE_HANDLE, first_len)
		elif i == pts.size() - 1:
			in_h = -m_fwd * minf(RAMP_NOSE_HANDLE, last_len)
			out_h = m_fwd * minf(RAMP_NOSE_HANDLE, last_len)
		else:
			var h: Array = _handles_for(segs_in[i], segs_out[i], RAMP_MIN_RADIUS)
			in_h = h[0]
			out_h = h[1]
		c.add_point(pts[i], in_h, out_h)
	return c

## Fails the generation if the baked centreline turns tighter than its own deck, which is what
## folds a ribbon inside out and makes its surface and barriers shimmer.
func _verify_min_radius(curve: Curve3D, half_w: float, label: String) -> void:
	var length: float = curve.get_baked_length()
	var window: float = 8.0
	var worst: float = 1e9
	var worst_at: float = 0.0
	for i in range(int(length) + 1):
		var d: float = float(i)
		var a: Vector3 = curve.sample_baked(maxf(0.0, d - window))
		var b: Vector3 = curve.sample_baked(d)
		var c: Vector3 = curve.sample_baked(minf(length, d + window))
		var v1: Vector3 = b - a
		var v2: Vector3 = c - b
		var area2: float = v1.cross(v2).length()
		if area2 < 1e-6 or v1.length() < 0.01 or v2.length() < 0.01:
			continue
		var r: float = (v1.length() * v2.length() * (v1 + v2).length()) / (2.0 * area2)
		if r < worst:
			worst = r
			worst_at = d
	if worst - half_w < 6.0:
		push_error("%s turns to R=%.1fm at %.0fm (inner edge %.1fm) - the deck folds there" % [label, worst, worst_at, worst - half_w])
	else:
		print("  %s min radius %.1fm at %.0fm (inner edge %.1fm)" % [label, worst, worst_at, worst - half_w])

## Smallest distance a ramp centreline keeps from the trunk centreline. A ramp must never
## drop inside the trunk deck, or its own deck would collapse onto the trunk surface.
func _min_ramp_lateral(alt_curve: Curve3D) -> float:
	var worst: float = 1e9
	var steps: int = int(alt_curve.get_baked_length())
	for i in range(steps + 1):
		worst = minf(worst, absf(_lateral_offset(main_track_curve, alt_curve.sample_baked(float(i)))))
	return worst

## Signed lateral offset of `p` from `curve`'s centreline (positive = right of travel).
func _lateral_offset(curve: Curve3D, p: Vector3) -> float:
	return _trunk_frame_at(curve, p)["lat"]

## Closest point on `curve` to `p`, plus the lateral offset and the right vector there. The
## lateral is measured in `curve`'s own horizontal frame, which is what deck tiling needs.
func _trunk_frame_at(curve: Curve3D, p: Vector3) -> Dictionary:
	var length: float = curve.get_baked_length()
	var off: float = curve.get_closest_offset(p)
	var c: Vector3 = curve.sample_baked(off)
	var nxt: Vector3 = curve.sample_baked(minf(length, off + 1.0))
	var fwd: Vector3 = (nxt - c).normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	return {"pos": c, "fwd": fwd, "right": right, "lat": (p - c).dot(right), "off": off}

## Frame on `curve` a given distance along it, without a nearest-point search.
func _trunk_frame_at_offset(curve: Curve3D, off: float) -> Dictionary:
	var length: float = curve.get_baked_length()
	off = clampf(off, 0.0, length)
	var c: Vector3 = curve.sample_baked(off)
	var nxt: Vector3 = curve.sample_baked(minf(length, off + 1.0))
	var fwd: Vector3 = (nxt - c).normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	return {"pos": c, "fwd": fwd, "right": right, "off": off}

## Absolute lateral reach of a ramp deck at lateral offset `lat`, returned as
## (inner_edge, outer_edge) measured from the trunk centreline.
##
## A ramp starts life as a zero-width nose sitting exactly on the trunk deck edge and
## widens only as its centreline moves clear of it. The inner edge is pinned to the
## trunk edge while that happens, so a ramp deck can never overlap the trunk deck
## (z-fighting) and can never float free of it (a seam down the middle of the road).
func _ramp_deck_extents(lat: float, ramp_half_w: float, main_half_w: float) -> Vector2:
	var d: float = absf(lat)
	var w: float = ramp_half_w * clampf((d - main_half_w) / ramp_half_w, 0.0, 1.0)
	return Vector2(maxf(d - w, main_half_w), d + w)

## Barrier height factor (0 = absent, 1 = full height) at `dist` metres along a curve.
## Runs terminate with a short sloped terminal just outside every gap.
func _barrier_factor_at(dist: float, gaps: Array) -> float:
	if gaps.is_empty():
		return 1.0
	var nearest: float = 1e9
	for gap in gaps:
		var gs: float = gap.x
		var ge: float = gap.y
		if dist >= gs and dist <= ge:
			return 0.0
		nearest = minf(nearest, absf(dist - gs))
		nearest = minf(nearest, absf(dist - ge))
	if nearest > 1e8:
		return 1.0
	return clampf(nearest / BARRIER_TERMINAL, 0.0, 1.0)

## Merges overlapping/adjacent [start, end] intervals.
func _merge_intervals(intervals: Array) -> Array:
	if intervals.is_empty():
		return []
	var sorted: Array = intervals.duplicate()
	sorted.sort_custom(func(a, b): return a.x < b.x)
	var merged: Array = [sorted[0]]
	for iv in sorted.slice(1):
		var last: Vector2 = merged[merged.size() - 1]
		if iv.x <= last.y + 1.0:
			merged[merged.size() - 1] = Vector2(last.x, maxf(last.y, iv.y))
		else:
			merged.append(iv)
	return merged

## Trunk-curve distance ranges where a ramp's deck runs alongside the trunk deck and
## the trunk barrier therefore has to be open (the gore at a split or a merge nose).
## Derived from the ramp geometry itself, so the barrier can never be left standing
## across the mouth of a ramp, and the opening is never wider than it needs to be.
func _junction_gap_intervals(alt_curve: Curve3D, ramp_half_w: float, main_half_w: float) -> Array:
	var main_len: float = main_track_curve.get_baked_length()
	var alt_len: float = alt_curve.get_baked_length()
	if main_len <= 0.0 or alt_len <= 0.0:
		return []
	var step := 1.0
	var open_spans: Array = []
	var run_start: float = -1.0
	var run_end: float = 0.0
	var samples: int = int(ceil(alt_len / step))
	for i in range(samples + 1):
		var t: float = float(i) * step
		var p: Vector3 = alt_curve.sample_baked(minf(t, alt_len))
		var lat: float = _lateral_offset(main_track_curve, p)
		var ext: Vector2 = _ramp_deck_extents(lat, ramp_half_w, main_half_w)
		var alongside: bool = ext.x < main_half_w + GORE_CLEARANCE
		var main_off: float = main_track_curve.get_closest_offset(p)
		if alongside:
			run_end = main_off
			if run_start < 0.0:
				run_start = main_off
		elif run_start >= 0.0:
			open_spans.append(Vector2(run_start, run_end))
			run_start = -1.0
	if run_start >= 0.0:
		open_spans.append(Vector2(run_start, run_end))

	var padded: Array = []
	for span in open_spans:
		padded.append(Vector2(maxf(span.x - 6.0, 0.0), minf(span.y + 6.0, main_len)))
	return _merge_intervals(padded)

func _ready() -> void:
	print("=== Glacier Highway Grand Prix Level Generation ===")
	print("Building multi-tier arctic concrete expressway with tunnel underpass and ramps...")

	var level_scene := Node3D.new()
	level_scene.name = "GlacierHighwayLevel"

	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)

	# 0. Core Nodes (must exist before entering tree for @onready variables)
	var players_node := Node3D.new()
	players_node.name = "Players"
	level_scene.add_child(players_node)

	var p_spawner := MultiplayerSpawner.new()
	p_spawner.name = "PlayerSpawner"
	p_spawner.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	p_spawner.spawn_path = NodePath("../Players")
	p_spawner.spawn_limit = 6
	level_scene.add_child(p_spawner)

	var proj_spawner := MultiplayerSpawner.new()
	proj_spawner.name = "ProjectileSpawner"
	proj_spawner.spawn_path = NodePath(".")
	level_scene.add_child(proj_spawner)

	add_child(level_scene)

	# 1. Environment & Lighting (Crisp High-Arctic Atmosphere)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.48, 0.88)
	sky_mat.sky_horizon_color = Color(0.70, 0.82, 0.94)
	sky_mat.ground_bottom_color = Color(0.86, 0.91, 0.97)
	sky_mat.ground_horizon_color = Color(0.76, 0.86, 0.95)
	sky_mat.sun_angle_max = 30.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.85, 0.92, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.10
	env_node.environment = env
	level_scene.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-42.0, 38.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.91)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 550.0
	sun.directional_shadow_split_1 = 0.10
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	level_scene.add_child(sun)

	# Ambient Winter Wind Audio
	var wind_stream = load("res://sounds/dragon-studio-winter-wind-402331.mp3")
	if wind_stream:
		var wind_player := AudioStreamPlayer.new()
		wind_player.name = "WinterWindAudio"
		wind_player.stream = wind_stream
		wind_player.volume_db = -11.0
		wind_player.autoplay = true
		level_scene.add_child(wind_player)

	# Falling Snow Particles
	var snow_particles := GPUParticles3D.new()
	snow_particles.name = "FallingSnow"
	var falling_snow_script = load("res://FallingSnow.gd")
	if falling_snow_script:
		snow_particles.set_script(falling_snow_script)
	snow_particles.amount = 2600
	snow_particles.lifetime = 3.5
	snow_particles.speed_scale = 0.55
	snow_particles.randomness = 0.8
	snow_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow_particles.visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 60, 120))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(45.0, 1.0, 45.0)
	pmat.direction = Vector3(0.25, -1.0, 0.15)
	pmat.spread = 16.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 6.5
	pmat.gravity = Vector3(0, -3.2, 0)
	pmat.scale_min = 0.7
	pmat.scale_max = 1.3
	snow_particles.process_material = pmat

	var snow_quad := QuadMesh.new()
	snow_quad.size = Vector2(0.12, 0.12)
	var fall_snow_mat := StandardMaterial3D.new()
	fall_snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fall_snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fall_snow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fall_snow_mat.vertex_color_use_as_albedo = true
	fall_snow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 0.95), Color(1.0, 1.0, 1.0, 0.0)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 32
	grad_tex.height = 32
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	fall_snow_mat.albedo_texture = grad_tex
	fall_snow_mat.albedo_color = Color(0.96, 0.98, 1.0, 0.9)
	snow_quad.material = fall_snow_mat
	snow_particles.draw_pass_1 = snow_quad
	level_scene.add_child(snow_particles)

	# 2. Main TrackPath & Curve3D (~1900m closed circuit)
	# Clockwise circuit:
	# - Starts on South glacier floor (X=-65, Y=2.8, Z=180) heading North
	# - Divergence 1: Approaches on-ramp to Express Viaduct Flyover
	# - Tunnel Underpass: Crosses through mountain tunnel (Z=-170 to Z=-240, Y=2.8)
	# - Divergence 2: Gorge cut off-ramp splits left into glacier bed
	# - Alpine Summit Climb: Sweeps around eastern mountain flank (Y up to 16.5m)
	# - Overpass Viaduct: Crosses high overhead at Z=-205m directly above the tunnel underpass!
	# - Divergence 3: Twin Viaduct split descending west mountain ridge
	# - Sweeps south across glacier valley and straightens smoothly into Finish Line
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	var curve_pts: Array = [
		# --- SECTION 0: START / FINISH STRAIGHT (Heading North, Y = 2.8m) ---
		Vector3(-85.0, 2.8, 280.0),  # 0 Finish Line
		Vector3(-85.0, 2.8, 160.0),  # 1 South straight
		Vector3(-82.0, 2.8, 30.0),   # 2 Pre-Divergence 1 (Express On-Ramp)

		# --- SECTION 1: VALLEY MEANDER & MERGE ---
		Vector3(-55.0, 2.8, -50.0),  # 3 Lower glacier curve
		Vector3(-18.0, 2.8, -115.0), # 4 Post-Divergence 1 Rejoin
		Vector3(0.0, 2.8, -150.0),   # 5 Tunnel Approach Straight (Aligning to X = 0)

		# --- SECTION 2: THE TUNNEL UNDERPASS (Crossing Directly Under High Overpass at Z = -180m) ---
		Vector3(0.0, 2.8, -180.0),   # 6 Tunnel Entrance Portal & Crossover Apex
		Vector3(0.0, 2.8, -210.0),   # 7 Tunnel Underpass Midpoint
		Vector3(0.0, 2.8, -240.0),   # 8 Tunnel Exit Portal
		Vector3(0.0, 2.8, -270.0),   # 9 North Basin Runout Straight

		# --- SECTION 3: NORTH GLACIER BASIN & DIVERGENCE 2 ---
		Vector3(30.0, 3.8, -320.0),  # 10 Pre-Divergence 2 (Gorge Cut Off-Ramp)
		Vector3(80.0, 5.8, -370.0),  # 11 North Rim broad curve
		Vector3(140.0, 8.5, -370.0), # 12 Post-Divergence 2 Rejoin

		# --- SECTION 4: ALPINE EAST FLANK CLIMB ---
		Vector3(195.0, 12.0, -320.0),# 13 East flank climb
		Vector3(210.0, 15.0, -240.0),# 14 Eastern summit traverse
		Vector3(180.0, 16.5, -180.0),# 15 Summit vista bend
		Vector3(135.0, 16.5, -180.0),# 16 East Overpass Approach Straight

		# --- SECTION 5: THE HIGH OVERPASS VIADUCT (Soaring Directly Across Z = -180m) ---
		Vector3(70.0, 16.5, -180.0), # 17 High East viaduct span
		Vector3(0.0, 16.5, -180.0),  # 18 OVERPASS CROSSING APEX (directly above Pt 6)
		Vector3(-70.0, 16.5, -180.0),# 19 High West viaduct span / Pre-Divergence 3
		Vector3(-135.0, 16.5, -165.0),# 20 West Overpass Abutment

		# --- SECTION 6: WEST RIDGE DESCENT & DIVERGENCE 3 REJOIN ---
		Vector3(-170.0, 13.0, -90.0),# 21 Mountain viaduct descent
		Vector3(-168.0, 9.0, -15.0), # 22 Outer shelf sweep
		Vector3(-145.0, 5.5, 60.0),  # 23 Post-Divergence 3 Rejoin
		Vector3(-138.0, 3.8, 140.0), # 24 Valley landing

		# --- SECTION 7: SOUTH GLACIER SWEEPER & HOME STRAIGHT ---
		Vector3(-135.0, 2.8, 220.0), # 25 South sweeper
		Vector3(-135.0, 2.8, 290.0), # 26 Turnaround loop entry
		Vector3(-110.0, 2.8, 325.0), # 27 Turnaround apex (U-turn onto the home straight)
		Vector3(-85.0, 2.8, 290.0),  # 28 Aligning straight north
	]

	# Handles are derived from the geometry rather than hand-picked: see _build_closed_loop.
	var curve := _build_closed_loop(curve_pts, TRUNK_MIN_RADIUS)
	_verify_min_radius(curve, MAIN_HALF_W, "trunk")

	track_path.curve = curve
	main_track_curve = curve
	level_scene.add_child(track_path)
	ROAD_CURVES = [curve]
	_init_noise()

	# 3. Terrain is built at the end (step 9), once every carriageway curve exists

	# 4. Materials setup
	var concrete_tex: Texture2D = load("res://materials/concrete.png") as Texture2D
	var concrete_norm: Texture2D = load("res://materials/concrete_normal.png") as Texture2D
	var concrete_rough: Texture2D = load("res://materials/concrete_roughness.png") as Texture2D

	var highway_shader = load("res://concrete_highway.gdshader")
	var highway_mat := ShaderMaterial.new()
	highway_mat.shader = highway_shader
	if concrete_tex:
		highway_mat.set_shader_parameter("concrete_texture", concrete_tex)
	if concrete_norm:
		highway_mat.set_shader_parameter("concrete_normal", concrete_norm)
	if concrete_rough:
		highway_mat.set_shader_parameter("concrete_roughness", concrete_rough)
	highway_mat.set_shader_parameter("concrete_color", Color(0.88, 0.90, 0.93))
	highway_mat.set_shader_parameter("stripe_color", Color(0.97, 0.98, 1.0))
	highway_mat.set_shader_parameter("uv_scale", 0.22)
	highway_mat.set_shader_parameter("circuit_length", curve.get_baked_length())

	var barrier_mat := StandardMaterial3D.new()
	if concrete_tex:
		barrier_mat.albedo_texture = concrete_tex
	if concrete_norm:
		barrier_mat.normal_enabled = true
		barrier_mat.normal_texture = concrete_norm
		barrier_mat.normal_scale = 0.8
	if concrete_rough:
		barrier_mat.roughness_texture = concrete_rough
	barrier_mat.albedo_color = Color(0.80, 0.82, 0.85)
	barrier_mat.roughness = 0.88
	barrier_mat.uv1_scale = Vector3(0.3, 0.3, 0.3)
	barrier_mat.uv1_triplanar = true
	barrier_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var girder_mat := StandardMaterial3D.new()
	girder_mat.albedo_color = Color(0.38, 0.40, 0.44)
	girder_mat.roughness = 0.85
	girder_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
	girder_mat.uv1_triplanar = true
	girder_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 5. Alternative Route Curves
	#
	# Every ramp starts and ends as a nose sitting exactly on the trunk deck edge, with its
	# handles aligned to the trunk tangent, so a ramp can never overlap the trunk deck or
	# leave a seam across it. The curves are built BEFORE the road meshes because the trunk
	# barrier gaps are derived from where each ramp actually runs alongside the trunk.
	var alt_container := Node3D.new()
	alt_container.name = "AlternativePaths"
	level_scene.add_child(alt_container)

	# --- DIVERGENCE 1: Summit Viaduct Express Flyover (climbs out over the open valley) ---
	var alt1_path := Path3D.new()
	alt1_path.name = "AlternativePath_ViaductExpress"
	var alt1_curve := _build_ramp_curve(Vector3(-76.0, 2.8, 60.0), Vector3(7.0, 2.8, -166.0), 1, [
		Vector3(-40.0, 5.00, 0.0),     # climbing out into the open arctic valley
		Vector3(-23.0, 10.50, -50.0),  # high scenic viaduct apex
		Vector3(3.0, 7.00, -100.0),    # off-ramp descent, safely east of the trunk
	], 15.0, 15.0)
	alt1_path.curve = alt1_curve
	alt_container.add_child(alt1_path)

	# --- DIVERGENCE 2: Glacier Gorge Service Cut (drops into the crevasse and climbs out) ---
	var alt2_path := Path3D.new()
	alt2_path.name = "AlternativePath_GorgeCut"
	var alt2_curve := _build_ramp_curve(Vector3(2.0, 2.8, -272.0), Vector3(140.0, 8.5, -368.0), 1, [
		Vector3(52.0, 1.80, -298.0),    # crevasse floor, well below the rim
		Vector3(84.0, 2.60, -332.0),    # still down in the cut
		Vector3(96.0, 6.50, -356.0),    # smooth ascending on-ramp
	], 15.0, 15.0)
	alt2_path.curve = alt2_curve
	alt_container.add_child(alt2_path)

	# --- DIVERGENCE 3: Twin Overpass Ridge Bypass (outer scenic viaduct) ---
	var alt3_path := Path3D.new()
	alt3_path.name = "AlternativePath_RidgeBypass"
	var alt3_curve := _build_ramp_curve(Vector3(-72.0, 16.5, -176.0), Vector3(-137.0, 5.7, 50.0), -1, [
		Vector3(-112.0, 13.00, -100.0),# panoramic descent along the west flank
		Vector3(-126.0, 9.20, -22.0),  # long descending grade
	], 15.0, 15.0)
	alt3_path.curve = alt3_curve
	alt_container.add_child(alt3_path)

	# A ramp centreline that strayed inside the trunk deck would collapse its own deck onto the
	# trunk surface, so fail loudly rather than shipping a broken junction. The tolerance covers
	# the nearest-point ambiguity where a ramp runs exactly along the trunk's edge on a curve.
	for entry in [[alt1_curve, "express flyover"], [alt2_curve, "gorge cut"], [alt3_curve, "ridge bypass"]]:
		var min_lat: float = _min_ramp_lateral(entry[0])
		if min_lat < MAIN_HALF_W - 0.5:
			push_error("%s dips to %.2fm from the trunk centreline (needs >= %.2f)" % [entry[1], min_lat, MAIN_HALF_W - 0.5])
		_verify_min_radius(entry[0], RAMP_HALF_W, entry[1])

	# 6. Build Main Highway Road Mesh & Side Barriers
	#
	# The barrier gaps are measured off the ramp geometry: the trunk barrier is only open
	# while a ramp deck actually runs alongside the trunk deck, which is exactly the gore.
	var main_left_gaps: Array = []
	var main_right_gaps: Array = []
	for entry in [[alt1_curve, 1], [alt2_curve, 1], [alt3_curve, -1]]:
		var spans: Array = _junction_gap_intervals(entry[0], RAMP_HALF_W, MAIN_HALF_W)
		if entry[1] > 0:
			main_right_gaps.append_array(spans)
		else:
			main_left_gaps.append_array(spans)
	main_left_gaps = _merge_intervals(main_left_gaps)
	main_right_gaps = _merge_intervals(main_right_gaps)
	print("  trunk barrier gaps - left: %s  right: %s" % [main_left_gaps, main_right_gaps])

	# NOTE the explicit gap arguments: without them the trunk gets no barrier gaps at all and
	# every ramp entrance is walled off. _verify_barrier_gaps below fails the build if so.
	_build_highway_road_mesh(level_scene, curve, MAIN_WIDTH, "MainHighway", highway_mat, barrier_mat, girder_mat,
			true, true, 0, 0.0, main_left_gaps, main_right_gaps)
	_verify_barrier_gaps(alt1_curve, alt2_curve, alt3_curve, main_left_gaps, main_right_gaps)
	# (junction guidance decals were removed - the gantry signs mark the splits)

	# 7. Ramp decks (tiled against the trunk shoulder, gore barrier only where they separate)
	_build_highway_road_mesh(level_scene, alt1_curve, RAMP_WIDTH, "ExpressFlyoverRoad", highway_mat, barrier_mat, girder_mat, true, true, 1, MAIN_HALF_W)
	_build_highway_road_mesh(level_scene, alt2_curve, RAMP_WIDTH, "GorgeServiceRoad", highway_mat, barrier_mat, girder_mat, true, false, 1, MAIN_HALF_W)
	_build_highway_road_mesh(level_scene, alt3_curve, RAMP_WIDTH, "RidgeBypassRoad", highway_mat, barrier_mat, girder_mat, true, true, -1, MAIN_HALF_W)

	# 8. Build the Tunnel Underpass System (Z = -180m to Z = -240m, X = 0m, Y = 2.8m, Length = 60m)
	_build_tunnel_underpass(level_scene, Vector3(0, 2.8, -210.0), 60.0, 18.5, barrier_mat, girder_mat)

	# 9. Terrain: the valley has to know where every carriageway runs, so this is built last
	#    and carves the Gorge Cut crevasse around its service road.
	ROAD_CURVES.append(alt1_curve)
	ROAD_CURVES.append(alt2_curve)
	ROAD_CURVES.append(alt3_curve)
	_build_road_index()
	var terrain_container := Node3D.new()
	terrain_container.name = "TerrainEnvironment"
	level_scene.add_child(terrain_container)
	_build_alpine_terrain(terrain_container, alt2_curve)

	# 10. Finish Line & Starting Grid
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")

	var fl_pos := curve.sample_baked(2.0)
	var fl_next := curve.sample_baked(3.0)
	var fl_fwd := (fl_next - fl_pos).normalized()
	var fl_rot_y := rad_to_deg(atan2(-fl_fwd.x, -fl_fwd.z))

	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = fl_pos + Vector3(0, 0.06, 0)
	finish_line.rotation_degrees = Vector3(0, fl_rot_y, 0)
	finish_line.set("is_finish_line", true)
	level_scene.add_child(finish_line)

	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	finish_line.add_child(spawn_points)

	var grid_coords = [
		Vector3(-2.8, 0.05, 5.0),
		Vector3(2.8, 0.05, 5.0),
		Vector3(-2.8, 0.05, 12.0),
		Vector3(2.8, 0.05, 12.0),
		Vector3(-2.8, 0.05, 19.0),
		Vector3(2.8, 0.05, 19.0)
	]
	for i in range(grid_coords.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid_coords[i]
		sp.gizmo_extents = 0.3
		spawn_points.add_child(sp)

		if spawn_scene:
			var si = spawn_scene.instantiate()
			si.name = "SpawnIndicator"
			sp.add_child(si)

	# 11. Checkpoints Container (5 curve-aligned checkpoints on trunk sections + Finish Line)
	# NOTE: NO checkpoints inside the tunnel underpass per user specification!
	#
	# Kept deliberately sparse and spread around the lap. Each one is snapped to the nearest
	# baked point, so they stay in order of travel automatically.
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)

	var track_len: float = curve.get_baked_length()
	var target_cp_positions = [
		Vector3(-85.0, 2.8, 160.0),  # CP 1: South Straight (trunk, before the first split)
		Vector3(0.0, 2.8, -265.0),   # CP 2: North Basin Runout (after the tunnel, before the Gorge Cut)
		Vector3(140.0, 8.5, -370.0), # CP 3: North Rim (Gorge Cut rejoin / east flank entry)
		Vector3(0.0, 16.5, -180.0),  # CP 4: Overpass Viaduct Apex (high set piece)
		Vector3(-138.0, 5.5, 60.0),  # CP 5: Valley Landing (Ridge Bypass rejoin)
	]

	# Find exact baked distance for each checkpoint by closest sample along curve
	var sample_step := 1.0
	var sample_count := int(track_len / sample_step)
	var milestone_offsets = []
	for target in target_cp_positions:
		var best_dist: float = 0.0
		var best_d2: float = 1e9
		for s in range(sample_count):
			var d_eval: float = s * sample_step
			var pt_eval := curve.sample_baked(d_eval)
			var d2 = pt_eval.distance_squared_to(target)
			if d2 < best_d2:
				best_d2 = d2
				best_dist = d_eval
		milestone_offsets.append(best_dist)

	for i in range(milestone_offsets.size()):
		var dist_along: float = milestone_offsets[i]
		var cp_pos := curve.sample_baked(dist_along)
		var next_pos := curve.sample_baked(minf(track_len, dist_along + 1.0))
		var forward := (next_pos - cp_pos).normalized()
		var rot_y := rad_to_deg(atan2(-forward.x, -forward.z))

		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = cp_pos + Vector3(0, 0.1, 0)
		gate.rotation_degrees = Vector3(0, rot_y, 0)
		checkpoints_container.add_child(gate)

	# 12. Boost Pads
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)

	if boost_scene:
		var bp_defs = [
			# South Straight Launch Boosters
			["Boost_Start_L", Vector3(-87.5, 2.8, 160.0), 0.0],
			["Boost_Start_R", Vector3(-82.5, 2.8, 160.0), 0.0],
			# Express Flyover Boosters (Divergence 1 Reward)
			["Boost_Express_1", Vector3(-34.3, 6.9, -13.1), -20.0],
			["Boost_Express_2", Vector3(-23.5, 10.7, -48.8), -10.0],
			# Gorge Service Cut Booster (Divergence 2)
			["Boost_Gorge_Launch", Vector3(74.2, 2.15, -319.4), -40.0],
			# High Overpass Viaduct Boosters (Section 5 Crossing)
			["Boost_Overpass_L", Vector3(5.0, 16.5, -178.0), -90.0],
			["Boost_Overpass_R", Vector3(5.0, 16.5, -182.0), -90.0],
			# West Ridge Descent Booster
			["Boost_RidgeDescent", Vector3(-165.3, 8.3, 0.5), -165.0],
			# Scenic Bypass Viaduct Booster
			["Boost_BypassViaduct", Vector3(-116.3, 11.8, -71.4), 172.0]
		]
		for bp_info in bp_defs:
			var bp = boost_scene.instantiate()
			bp.name = bp_info[0]
			bp.position = bp_info[1]
			bp.rotation_degrees = Vector3(0, bp_info[2], 0)
			boost_container.add_child(bp)

	# 13. Item Boxes
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	level_scene.add_child(item_container)

	if item_scene:
		var item_rows = [
			# Row 1: South Straight (Z = 120m)
			[Vector3(-88.0, 3.4, 120.0), Vector3(-85.0, 3.4, 120.0), Vector3(-82.0, 3.4, 120.0)],
			# Row 2: Pre-Tunnel Highway (Z = -135m)
			[Vector3(-5.0, 3.4, -135.0), Vector3(-1.5, 3.4, -135.0), Vector3(2.0, 3.4, -135.0)],
			# Row 3: Gorge Cut Secret Cache (crevasse floor)
			[Vector3(53.0, 2.4, -298.0), Vector3(58.0, 2.4, -303.0)],
			# Row 4: High East Ridge Vista (Z = -220m)
			[Vector3(208.0, 15.6, -220.0), Vector3(205.0, 15.6, -220.0), Vector3(202.0, 15.6, -220.0)],
			# Row 5: South Straight Home Run (Z = 160m)
			[Vector3(-88.0, 3.4, 160.0), Vector3(-85.0, 3.4, 160.0), Vector3(-82.0, 3.4, 160.0)]
		]
		var item_idx := 1
		for row in item_rows:
			for pos in row:
				var ib = item_scene.instantiate()
				ib.name = "ItemBox_%d" % item_idx
				ib.position = pos
				item_container.add_child(ib)
				item_idx += 1

	# 14. Highway Overhead Gantries & Streetlights
	var props_container := Node3D.new()
	props_container.name = "HighwayProps"
	level_scene.add_child(props_container)
	_build_highway_gantries(props_container)
	_build_highway_streetlights(props_container, curve, main_left_gaps, main_right_gaps)
	_build_jumbotron(props_container)

	# 15. Setup Checkpoints & Level wiring
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()

	# Split the big visual meshes into cells (collision shapes are separate and stay whole).
	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/glacier_highway_", "res://generated/glacier_highway_chunks", MESH_CHUNK_CELL)
	print("Chunked %d large meshes" % chunked)

	# 16. Scene Ownership
	_set_owner_recursive(level_scene, level_scene)

	# 17. Save Packed Scene
	remove_child(level_scene)
	var target_path := "res://levels/GlacierHighwayLevel.tscn"
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack GlacierHighwayLevel.tscn: %d" % pack_err)
		get_tree().quit(1)
		return

	var save_err = ResourceSaver.save(packed_scene, target_path)
	if save_err != OK:
		push_error("Failed to save GlacierHighwayLevel.tscn: %d" % save_err)
		get_tree().quit(1)
		return

	print("Successfully generated and saved res://levels/GlacierHighwayLevel.tscn!")
	get_tree().quit(0)


## Builds the 3D concrete highway road mesh, Jersey crash barriers, and viaduct piers along a Curve3D.
##
## Trunk highway (ramp_side = 0): pass the barrier gap intervals in metres along the curve,
## normally produced by _junction_gap_intervals() so a barrier can never be left standing
## across the mouth of a ramp.
##
## Alternative route: pass ramp_side = -1 (leaves the trunk on its left) or +1 (right) together
## with the trunk deck half width. The ramp deck is then built as a nose on the trunk deck edge
## that widens as it clears the shoulder, so trunk and ramp tile perfectly: no overlapping road
## surfaces, no gap down the middle, and the gore barrier disappears exactly where the two decks
## meet. The ramp's gore-side barrier is only raised once the ramp has pulled away from the trunk.
func _build_highway_road_mesh(parent: Node, curve: Curve3D, width: float, node_name: String, road_mat: Material, barrier_mat: Material, girder_mat: Material, has_barriers: bool, has_piers: bool, ramp_side: int = 0, main_half_w: float = 0.0, left_gaps: Array = [], right_gaps: Array = []) -> void:
	var baked := curve.get_baked_points()
	if baked.size() < 2:
		return

	var half_w: float = width * 0.5
	var total_len: float = curve.get_baked_length()
	var is_ramp: bool = ramp_side != 0
	var trunk: Curve3D = main_track_curve if is_ramp else null

	# Which side of the trunk the ramp really sits on, measured off the curve itself so the
	# deck tiling follows the geometry rather than the node name.
	var side: int = signi(ramp_side)
	if trunk != null:
		var lat_a: float = _lateral_offset(trunk, curve.sample_baked(total_len * 0.15))
		var lat_b: float = _lateral_offset(trunk, curve.sample_baked(total_len * 0.85))
		if absf(lat_a) >= absf(lat_b):
			side = signi(lat_a) if lat_a != 0.0 else signi(ramp_side)
		else:
			side = signi(lat_b) if lat_b != 0.0 else signi(ramp_side)
		if side == 0:
			side = signi(ramp_side)

	# --- Pass 1: per-ring frames, deck extents and barrier heights ---------------------
	var n_rings: int = baked.size()
	var ring_pos := PackedVector3Array()
	var ring_right := PackedVector3Array()
	var ring_fwd := PackedVector3Array()
	## Per-ring frame the cross-section is laid out in, plus the trunk-lateral of the ring
	## itself. Cross-section offsets are *deltas* from the ring's own lateral, which is what
	## keeps a ramp deck glued to the trunk deck edge while the two diverge.
	var ring_frame := PackedVector3Array()
	var ring_lat := PackedFloat32Array()
	var ring_y_bias := PackedFloat32Array()
	var deck_left := PackedFloat32Array()
	var deck_right := PackedFloat32Array()
	var bar_left := PackedFloat32Array()
	var bar_right := PackedFloat32Array()
	var dist_along := PackedFloat32Array()

	# Outward 2D normals of the barrier profile, averaged per vertex. Profiles are authored
	# counter-clockwise in (u, v), so the outward normal of edge P->Q is (dy, -dx).
	var prof_nrm := PackedVector2Array()
	var acc := Vector2.ZERO
	for i in range(BARRIER_VERTS):
		var prev: Vector2 = BARRIER_PROFILE[(i + BARRIER_VERTS - 1) % BARRIER_VERTS]
		var here: Vector2 = BARRIER_PROFILE[i]
		var nxt: Vector2 = BARRIER_PROFILE[(i + 1) % BARRIER_VERTS]
		var e_in: Vector2 = (here - prev).normalized()
		var e_out: Vector2 = (nxt - here).normalized()
		acc += Vector2(e_in.y, -e_in.x)
		acc += Vector2(e_out.y, -e_out.x)
		prof_nrm.append(acc.normalized())
		acc = Vector2.ZERO

	var cum: float = 0.0
	for i in range(n_rings):
		var p: Vector3 = baked[i]
		var fwd := Vector3.FORWARD
		if i < n_rings - 1:
			fwd = (baked[i + 1] - p).normalized()
		elif i > 0:
			fwd = (p - baked[i - 1]).normalized()
		var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
		var up := Vector3.UP

		if i > 0:
			cum += p.distance_to(baked[i - 1])

		var d_l: float = -half_w
		var d_r: float = half_w
		var b_l: float = 1.0
		var b_r: float = 1.0
		var frame: Vector3 = right
		var lat_here: float = 0.0
		var y_bias: float = 0.0

		if is_ramp and trunk != null:
			var frame_info: Dictionary = _trunk_frame_at(trunk, p)
			lat_here = frame_info["lat"]
			var trunk_right: Vector3 = frame_info["right"]
			var ext: Vector2 = _ramp_deck_extents(lat_here, half_w, main_half_w)
			# Trunk-lateral the deck edges should sit at, signed to this ramp's side.
			var lat_in: float = float(side) * ext.x
			var lat_out: float = float(side) * ext.y
			d_l = minf(lat_in, lat_out)
			d_r = maxf(lat_in, lat_out)
			# While the deck is still tiling against the trunk shoulder its cross-section must be
			# laid out along the *trunk's* right vector, otherwise the inner edge slides off the
			# trunk deck by 8m*cos(divergence) and the two roads part company. Once the ramp has
			# pulled clear, blend back to the ramp's own perpendicular so it is a normal ribbon.
			var blend: float = clampf((absf(lat_here) - (main_half_w + half_w)) / 25.0, 0.0, 1.0)
			frame = (trunk_right * (1.0 - blend) + right * blend)
			if frame.length_squared() < 1e-6:
				frame = right
			frame = frame.normalized()
			# While tiling, the ramp deck must also sit at exactly the trunk's height. The ramp's
			# own curve sags a few centimetres there (Catmull-Rom handle overshoot in Y), and the
			# trunk's slab edge then stands proud of the ramp surface as a lip across the gore.
			#
			# Deliberately tight and clamped: the correction belongs to the gore only. Tying it to
			# the 25m frame blend instead let it reach the viaduct spans, where the ramp is 8m above
			# the trunk, and it moved those decks bodily out from under their own piers.
			var seam: float = clampf((absf(lat_here) - (main_half_w + half_w)) / 6.0, 0.0, 1.0)
			y_bias = clampf(frame_info["pos"].y - p.y, -0.35, 0.35) * (1.0 - seam)
			# Gore-side barrier only comes up once the ramp deck has opened the same clearance
			# the trunk barrier uses to close (GORE_CLEARANCE). Tying the two together is what
			# keeps the whole junction barrier-free: raise the ramp's gore barrier any earlier and
			# it stands in the middle of the gore, cutting the crossing window down to a few
			# metres even though the trunk looks open.
			var gore_h: float = clampf((ext.x - main_half_w - GORE_CLEARANCE) / 3.0, 0.0, 1.0)
			var outer_w: float = ext.y - ext.x
			var outer_h: float = clampf((outer_w - 1.3) / 2.2, 0.0, 1.0)
			if side > 0:
				b_l = gore_h
				b_r = outer_h
			else:
				b_l = outer_h
				b_r = gore_h
		else:
			b_l = _barrier_factor_at(cum, left_gaps)
			b_r = _barrier_factor_at(cum, right_gaps)

		if not has_barriers:
			b_l = 0.0
			b_r = 0.0

		ring_pos.append(p)
		ring_fwd.append(fwd)
		ring_right.append(right)
		ring_frame.append(frame)
		ring_lat.append(lat_here)
		ring_y_bias.append(y_bias)
		deck_left.append(d_l)
		deck_right.append(d_r)
		bar_left.append(b_l)
		bar_right.append(b_r)
		dist_along.append(cum)

	# --- Pass 2: vertices -------------------------------------------------------------
	var st_road := SurfaceTool.new()
	st_road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_barrier := SurfaceTool.new()
	st_barrier.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_girder := SurfaceTool.new()
	st_girder.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Cached barrier profile rings, reused for the end caps.
	var prof_left := []
	var prof_right := []

	for i in range(n_rings):
		var p: Vector3 = ring_pos[i]
		var fwd: Vector3 = ring_fwd[i]
		var right: Vector3 = ring_right[i]
		var frame: Vector3 = ring_frame[i]
		# Cross-section offsets are trunk-lateral targets minus the ring's own lateral, so a
		# vertex lands exactly where the tiling wants it.
		var shift: float = -ring_lat[i]
		# Height correction that keeps a tiled ramp deck flush with the trunk it leans on.
		p += Vector3.UP * ring_y_bias[i]
		var up := Vector3.UP
		var d_l: float = deck_left[i]
		var d_r: float = deck_right[i]
		var uv_y: float = dist_along[i]

		# Road markings: dashed edge lines through every gore, solid barriers elsewhere.
		var edge_l_mode: float = 1.0
		var edge_r_mode: float = 1.0
		var road_type_val: float = 1.0 if is_ramp else 0.0
		var gore_val: float = 0.0
		var width_now: float = d_r - d_l

		if is_ramp:
			var open_l: float = 1.0 - clampf((width_now - 2.0) / 3.0, 0.0, 1.0)
			# The gore edge is the one facing the trunk, the outboard edge is always solid.
			if side > 0:
				edge_l_mode = open_l
			else:
				edge_r_mode = open_l
			# Paint the gore nose only where the deck is genuinely still merging in.
			gore_val = clampf(1.0 - width_now / 4.5, 0.0, 1.0) * 0.7
		else:
			edge_l_mode = 0.5 if _in_any_gap(uv_y, left_gaps) else 1.0
			edge_r_mode = 0.5 if _in_any_gap(uv_y, right_gaps) else 1.0

		# Centre crown, faded out at the ramp noses so the transition is flush and tangent.
		var crown: float = 0.04
		if is_ramp:
			crown = 0.04 * clampf(width_now / 9.0, 0.0, 1.0)

		# --- 1. ROAD DECK (5 points across: L edge, L lane, centre, R lane, R edge) ---
		var center_lat: float = (d_l + d_r) * 0.5
		for k in range(5):
			var t: float = float(k) * 0.25
			var lat: float = lerpf(d_l, d_r, t)
			var v: Vector3 = p + frame * (lat + shift)
			if k == 2:
				v += up * crown
			st_road.set_color(Color(edge_l_mode, edge_r_mode, road_type_val, gore_val))
			st_road.set_uv(Vector2(t, uv_y))
			st_road.add_vertex(v)

		# --- 2. JERSEY BARRIERS (fixed profile, flat across the profile, smooth along it) ---
		# Vertices are laid out as one blocked left profile then one blocked right profile, so
		# a ring is 2 * BARRIER_VERTS vertices and each side is indexed as a closed prism.
		var pl := PackedVector3Array()
		var pr := PackedVector3Array()
		for k in range(BARRIER_VERTS):
			var prof: Vector2 = BARRIER_PROFILE[k]
			var n2: Vector2 = prof_nrm[k]
			# Left edge: profile u runs toward the road (+lateral). Right edge: mirrored.
			var v_l := p + frame * (d_l + shift + prof.x) + up * (prof.y * bar_left[i])
			var n_l := (right * n2.x + up * n2.y).normalized()
			st_barrier.set_normal(n_l)
			st_barrier.set_uv(Vector2(0.0, uv_y * 0.3))
			st_barrier.add_vertex(v_l)
			pl.append(v_l)
		for k in range(BARRIER_VERTS):
			var prof: Vector2 = BARRIER_PROFILE[k]
			var n2: Vector2 = prof_nrm[k]
			var v_r := p + frame * (d_r + shift - prof.x) + up * (prof.y * bar_right[i])
			var n_r := (-right * n2.x + up * n2.y).normalized()
			st_barrier.set_normal(n_r)
			st_barrier.set_uv(Vector2(1.0, uv_y * 0.3))
			st_barrier.add_vertex(v_r)
			pr.append(v_r)
		prof_left.append(pl)
		prof_right.append(pr)

		# --- 3. UNDER-DECK BOX GIRDER ---
		var box_drop: float = _girder_depth(p.y)
		var g_inset: float = minf(0.2, maxf(width_now * 0.25, 0.05))
		var gb_l: float = d_l + g_inset
		var gb_r: float = d_r - g_inset
		st_girder.set_uv(Vector2(0.0, uv_y * 0.2))
		st_girder.add_vertex(p + frame * (d_l + shift) - up * 0.12)
		st_girder.set_uv(Vector2(0.3, uv_y * 0.2))
		st_girder.add_vertex(p + frame * (gb_l + shift) - up * box_drop)
		st_girder.set_uv(Vector2(0.7, uv_y * 0.2))
		st_girder.add_vertex(p + frame * (gb_r + shift) - up * box_drop)
		st_girder.set_uv(Vector2(1.0, uv_y * 0.2))
		st_girder.add_vertex(p + frame * (d_r + shift) - up * 0.12)

	# --- Pass 3: road deck triangles (4 quads per segment) ---------------------------
	for i in range(n_rings - 1):
		var r0: int = i * 5
		var r1: int = (i + 1) * 5
		for c in range(4):
			var a: int = r0 + c
			var b: int = r0 + c + 1
			var c_idx: int = r1 + c
			var d: int = r1 + c + 1
			st_road.add_index(a); st_road.add_index(c_idx); st_road.add_index(b)
			st_road.add_index(b); st_road.add_index(c_idx); st_road.add_index(d)

	# --- Pass 4: barrier side quads + solid caps at every start/end ------------------
	# Each ring is 2 * BARRIER_VERTS vertices: the left profile then the right profile.
	var ring_stride: int = BARRIER_VERTS * 2
	var cap_base: int = n_rings * ring_stride
	for i in range(n_rings - 1):
		for s in range(2): # 0 = left, 1 = right
			var base: int = i * ring_stride + BARRIER_VERTS * s
			var nxt_base: int = base + ring_stride
			var h0: float = bar_left[i] if s == 0 else bar_right[i]
			var h1: float = bar_left[i + 1] if s == 0 else bar_right[i + 1]
			var profiles: Array = prof_left if s == 0 else prof_right
			var fwd: Vector3 = ring_fwd[i]
			var nxt_fwd: Vector3 = ring_fwd[i + 1]

			if h0 > 0.06 or h1 > 0.06:
				# Right-hand profiles are mirrored, so their quads wind the other way to keep
				# every face normal pointing out of the concrete.
				for c in range(BARRIER_VERTS):
					var a: int = base + c
					var b: int = base + ((c + 1) % BARRIER_VERTS)
					var c_idx: int = nxt_base + c
					var d: int = nxt_base + ((c + 1) % BARRIER_VERTS)
					if s == 0:
						st_barrier.add_index(a); st_barrier.add_index(c_idx); st_barrier.add_index(b)
						st_barrier.add_index(b); st_barrier.add_index(c_idx); st_barrier.add_index(d)
					else:
						st_barrier.add_index(a); st_barrier.add_index(b); st_barrier.add_index(c_idx)
						st_barrier.add_index(b); st_barrier.add_index(d); st_barrier.add_index(c_idx)

			var starts: bool = (i == 0 and h0 > 0.06) or (h0 <= 0.06 and h1 > 0.06)
			var ends: bool = (i == n_rings - 2 and h1 > 0.06) or (h0 > 0.06 and h1 <= 0.06)
			if starts:
				var ring: int = i if i == 0 else i + 1
				cap_base = _emit_barrier_cap(st_barrier, cap_base, profiles[ring], -fwd if i == 0 else -nxt_fwd)
			if ends:
				var ring: int = i + 1 if i == n_rings - 2 else i
				cap_base = _emit_barrier_cap(st_barrier, cap_base, profiles[ring], nxt_fwd if i == n_rings - 2 else fwd)

	# --- Pass 5: girder (left drop face, soffit, right rise face; top left open) ------
	for i in range(n_rings - 1):
		var g0: int = i * 4
		var g1: int = (i + 1) * 4
		for c in range(3):
			var a: int = g0 + c
			var b: int = g0 + c + 1
			var c_idx: int = g1 + c
			var d: int = g1 + c + 1
			st_girder.add_index(a); st_girder.add_index(c_idx); st_girder.add_index(b)
			st_girder.add_index(b); st_girder.add_index(c_idx); st_girder.add_index(d)

	# Cap the girder ends so there are no open hollow holes.
	st_girder.add_index(0); st_girder.add_index(1); st_girder.add_index(2)
	st_girder.add_index(0); st_girder.add_index(2); st_girder.add_index(3)
	var e0: int = (n_rings - 1) * 4
	st_girder.add_index(e0 + 0); st_girder.add_index(e0 + 2); st_girder.add_index(e0 + 1)
	st_girder.add_index(e0 + 0); st_girder.add_index(e0 + 3); st_girder.add_index(e0 + 2)

	# --- Pass 6: viaduct piers --------------------------------------------------------
	var pier_root := Node3D.new()
	pier_root.name = node_name + "_Pylons"
	parent.add_child(pier_root)
	if has_piers:
		var last_pier_dist: float = -100.0
		for i in range(n_rings):
			# Supports must ride on the *corrected* deck height, otherwise a bent's crosshead ends
			# up above the road surface wherever the gore seam correction applies.
			var p: Vector3 = ring_pos[i] + Vector3.UP * ring_y_bias[i]
			var cum_i: float = dist_along[i]
			# Never drop a bent under the knife-edge nose of a ramp.
			var near_ramp_ends: bool = is_ramp and (cum_i < 48.0 or (total_len - cum_i) < 48.0)
			var over_lower_road: bool = false
			if p.y > 4.5 and trunk != null:
				var closest_off: float = trunk.get_closest_offset(p)
				var closest_pt: Vector3 = trunk.sample_baked(closest_off)
				var horiz_dist: float = Vector2(p.x - closest_pt.x, p.z - closest_pt.z).length()
				if horiz_dist < 15.0:
					over_lower_road = true
			if absf(p.x) < 13.0 and absf(p.z - (-180.0)) < 20.0:
				over_lower_road = true
			if p.y > 6.0 and not near_ramp_ends and not over_lower_road and (cum_i - last_pier_dist >= 24.0):
				last_pier_dist = cum_i
				_build_viaduct_pier(pier_root, p, ring_fwd[i], ring_right[i], maxf(deck_right[i] - deck_left[i], 1.0) * 0.5, p.y, barrier_mat)

	# Two monumental bents flanking the tunnel approach, clear of the rock face so they read
	# as the viaduct landing in the open valley.
	if node_name == "MainHighway" and has_piers:
		_build_viaduct_pier(pier_root, Vector3(-15.5, 16.5, -174.5), Vector3(-1, 0, 0), Vector3(0, 0, -1), half_w, 16.5, barrier_mat)
		_build_viaduct_pier(pier_root, Vector3(15.5, 16.5, -174.5), Vector3(-1, 0, 0), Vector3(0, 0, -1), half_w, 16.5, barrier_mat)

	# --- Pass 7: commit meshes, collision ---------------------------------------------
	# Meshes and collision shapes go to res://generated/ as binary resources, the same way the
	# other levels' terrain is stored. Inlining them would put tens of megabytes of vertex data
	# into the text scene file, which is slow to save, slow to parse and unreviewable.
	st_road.generate_normals()
	st_road.generate_tangents()
	var road_mesh: ArrayMesh = _save_baked_resource(st_road.commit(), "%s_deck" % node_name)

	# Normals are authored above (crisp across the profile, smooth along the run) and
	# generate_normals() is deliberately NOT called on the barrier.
	var barrier_mesh: ArrayMesh = _save_baked_resource(st_barrier.commit(), "%s_barrier" % node_name)

	st_girder.generate_normals()
	st_girder.generate_tangents()
	var girder_mesh: ArrayMesh = _save_baked_resource(st_girder.commit(), "%s_girder" % node_name)

	var static_body := StaticBody3D.new()
	static_body.name = node_name + "_Collision"
	static_body.add_to_group("track_surface", true)

	var road_inst := MeshInstance3D.new()
	road_inst.name = node_name + "_DeckMesh"
	road_inst.mesh = road_mesh
	road_inst.material_override = road_mat
	static_body.add_child(road_inst)

	var barrier_inst := MeshInstance3D.new()
	barrier_inst.name = node_name + "_BarrierMesh"
	barrier_inst.mesh = barrier_mesh
	barrier_inst.material_override = barrier_mat
	static_body.add_child(barrier_inst)

	var girder_inst := MeshInstance3D.new()
	girder_inst.name = node_name + "_GirderMesh"
	girder_inst.mesh = girder_mesh
	girder_inst.material_override = girder_mat
	static_body.add_child(girder_inst)

	# TriMesh collision for precise driving and barrier bounces, stored alongside the visuals.
	var col_shape := CollisionShape3D.new()
	col_shape.name = "DeckCollision"
	var r_trimesh: Shape3D = road_mesh.create_trimesh_shape()
	if r_trimesh is ConcavePolygonShape3D:
		(r_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_shape.shape = _save_baked_resource(r_trimesh, "%s_deck_collision" % node_name)
	static_body.add_child(col_shape)

	var col_barrier := CollisionShape3D.new()
	col_barrier.name = "BarrierCollision"
	var b_trimesh: Shape3D = barrier_mesh.create_trimesh_shape()
	if b_trimesh is ConcavePolygonShape3D:
		(b_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_barrier.shape = _save_baked_resource(b_trimesh, "%s_barrier_collision" % node_name)
	static_body.add_child(col_barrier)

	parent.add_child(static_body)


## True when `dist` metres along a curve falls inside one of the [start, end] intervals.
func _in_any_gap(dist: float, gaps: Array) -> bool:
	for gap in gaps:
		if dist >= gap.x and dist <= gap.y:
			return true
	return false


## Emits a flat end cap for a barrier run with its own vertices, so a terminal keeps a crisp
## face instead of inheriting the smoothed normals of the barrier sides.
func _emit_barrier_cap(st: SurfaceTool, first_index: int, profile: PackedVector3Array, want_normal: Vector3) -> int:
	if profile.size() < 3:
		return first_index
	# Newell's method: robust for the non-planar rings a tapering terminal produces.
	var n := Vector3.ZERO
	for i in range(profile.size()):
		var a: Vector3 = profile[i]
		var b: Vector3 = profile[(i + 1) % profile.size()]
		n += (b - a).cross(a - profile[0])
	if n.length_squared() < 1e-12:
		return first_index
	n = n.normalized()
	var order := PackedInt32Array()
	if n.dot(want_normal) < 0.0:
		for i in range(profile.size() - 1, -1, -1):
			order.append(i)
	else:
		for i in range(profile.size()):
			order.append(i)
	for idx in order:
		st.set_normal(want_normal)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(profile[idx])
	for k in range(1, order.size() - 1):
		st.add_index(first_index); st.add_index(first_index + k); st.add_index(first_index + k + 1)
	return first_index + order.size()



## Builds a heavy concrete viaduct bent with crosshead beam and dual cylindrical columns.
func _build_viaduct_pier(parent: Node, pos: Vector3, fwd: Vector3, right: Vector3, half_w: float, height: float, mat: Material) -> void:
	var pier := StaticBody3D.new()
	pier.name = "Pier_%d_%d" % [int(pos.x), int(pos.z)]
	pier.position = pos

	var rot_y := rad_to_deg(atan2(-fwd.x, -fwd.z))
	pier.rotation_degrees = Vector3(0, rot_y, 0)

	# Crosshead Cap Beam under the deck
	var beam_inst := MeshInstance3D.new()
	beam_inst.name = "CrossheadBeam"
	var bm := BoxMesh.new()
	bm.size = Vector3(half_w * 2.2, 1.2, 2.2)
	beam_inst.mesh = bm
	beam_inst.material_override = mat
	beam_inst.position = Vector3(0, -1.1, 0)
	pier.add_child(beam_inst)

	var beam_col := CollisionShape3D.new()
	beam_col.name = "CrossheadBeamCol"
	var beam_shape := BoxShape3D.new()
	beam_shape.size = bm.size
	beam_col.shape = beam_shape
	beam_col.position = beam_inst.position
	pier.add_child(beam_col)

	# Dual Heavy Concrete Columns extending down to ground level
	var col_h = maxf(height - 1.2, 1.0)
	var col_r = 1.0
	for side in [-1.0, 1.0]:
		var col_x = side * (half_w * 0.55)
		var col_inst := MeshInstance3D.new()
		col_inst.name = "Column_" + ("L" if side < 0 else "R")
		var cm := CylinderMesh.new()
		cm.top_radius = col_r
		cm.bottom_radius = col_r * 1.15
		cm.height = col_h
		cm.radial_segments = 16
		col_inst.mesh = cm
		col_inst.material_override = mat
		col_inst.position = Vector3(col_x, -1.2 - col_h * 0.5, 0)
		pier.add_child(col_inst)

		var col_col := CollisionShape3D.new()
		col_col.name = "ColumnCol_" + ("L" if side < 0 else "R")
		var col_shape := CylinderShape3D.new()
		col_shape.radius = col_r * 1.08
		col_shape.height = col_h
		col_col.shape = col_shape
		col_col.position = col_inst.position
		pier.add_child(col_col)

		# Column Footing
		var foot_inst := MeshInstance3D.new()
		foot_inst.name = "Footing_" + ("L" if side < 0 else "R")
		var fm := BoxMesh.new()
		fm.size = Vector3(3.2, 1.0, 3.2)
		foot_inst.mesh = fm
		foot_inst.material_override = mat
		foot_inst.position = Vector3(col_x, -height + 0.5, 0)
		pier.add_child(foot_inst)

		var foot_col := CollisionShape3D.new()
		foot_col.name = "FootingCol_" + ("L" if side < 0 else "R")
		var foot_shape := BoxShape3D.new()
		foot_shape.size = fm.size
		foot_col.shape = foot_shape
		foot_col.position = foot_inst.position
		pier.add_child(foot_col)

	parent.add_child(pier)


## Builds the reinforced concrete tunnel underpass with portals, vaulted ceiling, and interior lighting.
func _build_tunnel_underpass(parent: Node, center: Vector3, length: float, width: float, mat: Material, dark_mat: Material) -> void:
	var tunnel_root := Node3D.new()
	tunnel_root.name = "GlacierTunnelUnderpass"
	tunnel_root.position = center

	var half_len: float = length * 0.5
	var half_w: float = width * 0.5
	var wall_h: float = 6.2
	var wall_th: float = 1.2

	# 1. Left and Right Tunnel Walls
	for side in [-1.0, 1.0]:
		var wall_body := StaticBody3D.new()
		wall_body.name = "TunnelWall_" + ("L" if side < 0 else "R")
		wall_body.position = Vector3(side * (half_w + wall_th * 0.5), wall_h * 0.5, 0)

		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(wall_th, wall_h, length)
		col.shape = shape
		wall_body.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = shape.size
		mesh_inst.mesh = bm
		mesh_inst.material_override = mat
		wall_body.add_child(mesh_inst)
		tunnel_root.add_child(wall_body)

	# 2. Vaulted Arch Ceiling
	#
	# The slab runs from the visible ceiling right up to the rock roof and spans the full bore,
	# so from inside the tunnel there is no gap to see sky through at the portals.
	var liner_bot: float = wall_h - 0.4
	var liner_top: float = TUNNEL_LINER_TOP
	var ceiling_body := StaticBody3D.new()
	ceiling_body.name = "TunnelCeiling"
	var c_col := CollisionShape3D.new()
	var c_shape := BoxShape3D.new()
	c_shape.size = Vector3(TUNNEL_BORE_HALF_W * 2.0, liner_top - liner_bot, length)
	c_col.shape = c_shape
	ceiling_body.add_child(c_col)

	var c_mesh := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = c_shape.size
	c_mesh.mesh = cm
	c_mesh.material_override = dark_mat
	ceiling_body.add_child(c_mesh)
	ceiling_body.position = Vector3(0, (liner_bot + liner_top) * 0.5, 0)
	tunnel_root.add_child(ceiling_body)

	# 3. Portals at Entrance (South, Z = +half_len) and Exit (North, Z = -half_len)
	for p_end in [-1.0, 1.0]:
		var p_z = p_end * half_len
		var portal_name = "Portal_" + ("North" if p_end < 0 else "South")

		var portal_node := StaticBody3D.new()
		portal_node.name = portal_name
		portal_node.position = Vector3(0, 0, p_z)

		# Portal Arch Header
		var header := MeshInstance3D.new()
		header.name = "ArchHeader"
		var hm := BoxMesh.new()
		hm.size = Vector3(width + 4.5, 2.8, 3.5)
		header.mesh = hm
		header.material_override = mat
		header.position = Vector3(0, wall_h + 1.4, 0)
		portal_node.add_child(header)

		var h_col := CollisionShape3D.new()
		var h_shape := BoxShape3D.new()
		h_shape.size = hm.size
		h_col.shape = h_shape
		h_col.position = header.position
		portal_node.add_child(h_col)

		# Portal Side Buttresses
		for side in [-1.0, 1.0]:
			var buttress := MeshInstance3D.new()
			buttress.name = "Buttress_" + ("L" if side < 0 else "R")
			var btm := BoxMesh.new()
			btm.size = Vector3(3.2, wall_h + 2.5, 3.5)
			buttress.mesh = btm
			buttress.material_override = mat
			buttress.position = Vector3(side * (half_w + 1.8), (wall_h + 2.5) * 0.5, 0)
			portal_node.add_child(buttress)

			var b_col := CollisionShape3D.new()
			var b_shape := BoxShape3D.new()
			b_shape.size = btm.size
			b_col.shape = b_shape
			b_col.position = buttress.position
			portal_node.add_child(b_col)

			# Wing-wall flaring into snow mountain
			var wing := MeshInstance3D.new()
			wing.name = "WingWall_" + ("L" if side < 0 else "R")
			var wm := BoxMesh.new()
			wm.size = Vector3(4.5, wall_h + 1.5, 2.0)
			wing.mesh = wm
			wing.material_override = mat
			wing.position = Vector3(side * (half_w + 4.2), (wall_h + 1.5) * 0.5, p_end * 1.5)
			wing.rotation_degrees = Vector3(0, side * 32.0, 0)
			portal_node.add_child(wing)

			var w_col := CollisionShape3D.new()
			var w_shape := BoxShape3D.new()
			w_shape.size = wm.size
			w_col.shape = w_shape
			w_col.position = wing.position
			w_col.rotation_degrees = wing.rotation_degrees
			portal_node.add_child(w_col)

		# Overhead Illuminated Portal Sign Board
		var sign_inst := MeshInstance3D.new()
		sign_inst.name = "PortalSign"
		var sm := BoxMesh.new()
		sm.size = Vector3(14.0, 1.4, 0.25)
		sign_inst.mesh = sm
		var sign_mat := StandardMaterial3D.new()
		sign_mat.albedo_color = Color(0.08, 0.16, 0.32)
		sign_mat.emission_enabled = true
		sign_mat.emission = Color(0.12, 0.45, 0.85)
		sign_mat.emission_energy_multiplier = 0.8
		sign_inst.material_override = sign_mat
		sign_inst.position = Vector3(0, wall_h + 1.5, p_end * 1.8)
		portal_node.add_child(sign_inst)

		tunnel_root.add_child(portal_node)

	# 4. Interior Tunnel LED Strip Lights (6 pairs casting warm amber glow)
	#
	# These hang from the *underside* of the ceiling liner. That liner is a deep slab running
	# from the visible ceiling up to the rock roof (so no sky shows through at the portals), so
	# anything positioned off wall_h alone ends up buried inside the concrete.
	var lamp_y: float = liner_bot - 0.12
	var light_z_steps = [-24.0, -15.0, -6.0, 6.0, 15.0, 24.0]
	for lz in light_z_steps:
		for side in [-1.0, 1.0]:
			var lamp_x = side * (half_w - 1.2)
			var omni := OmniLight3D.new()
			omni.name = "TunnelLight_%d_%s" % [int(lz), "L" if side < 0 else "R"]
			omni.position = Vector3(lamp_x, lamp_y - 0.45, lz)
			omni.light_color = Color(1.0, 0.84, 0.55) # warm sodium/amber tunnel glow
			omni.light_energy = 1.5
			omni.omni_range = 18.0
			omni.omni_attenuation = 0.9
			tunnel_root.add_child(omni)

			# Emissive lamp fixture mesh
			var fixture := MeshInstance3D.new()
			fixture.name = "Fixture_%d_%s" % [int(lz), "L" if side < 0 else "R"]
			var fm := BoxMesh.new()
			fm.size = Vector3(0.5, 0.2, 1.8)
			fixture.mesh = fm
			var f_mat := StandardMaterial3D.new()
			f_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			f_mat.albedo_color = Color(1.0, 0.90, 0.65)
			fixture.material_override = f_mat
			fixture.position = Vector3(lamp_x, lamp_y, lz)
			tunnel_root.add_child(fixture)

	parent.add_child(tunnel_root)


## Builds the alpine terrain: a glacier valley with a graded shelf under every road, a
## crevasse for the Gorge Cut, and ridged snow-capped ranges enclosing the circuit, plus the
## rock massif the tunnel bores through.
##
## Everything is generated from noise instead of boxes and prisms, so the skyline has real
## ridgelines, gullies and snow lines. The big meshes are written to res://generated/ like the
## other levels' terrain, which keeps this .tscn small.
func _build_alpine_terrain(parent: Node, gorge_curve: Curve3D) -> void:
	var terrain_root := Node3D.new()
	terrain_root.name = "AlpineMountains"

	# --- 1. Valley + range heightfield ------------------------------------------------
	var res: int = ALPINE_TERRAIN_RES
	var step_x: float = ALPINE_TERRAIN_SIZE / float(res)
	var step_z: float = ALPINE_TERRAIN_SIZE / float(res)
	var start_x: float = ALPINE_TERRAIN_CENTER.x - ALPINE_TERRAIN_SIZE * 0.5
	var start_z: float = ALPINE_TERRAIN_CENTER.y - ALPINE_TERRAIN_SIZE * 0.5
	var stride: int = res + 1

	# Coarse mask so the expensive per-vertex road queries only run near a carriageway.
	var mask_res: int = 96
	var mask := PackedByteArray()
	mask.resize(mask_res * mask_res)
	var cell_x: float = ALPINE_TERRAIN_SIZE / float(mask_res)
	var cell_z: float = ALPINE_TERRAIN_SIZE / float(mask_res)
	for road in ROAD_CURVES:
		var rc: Curve3D = road
		var rlen: float = rc.get_baked_length()
		var steps: int = int(rlen / 6.0)
		for i in range(steps + 1):
			var p: Vector3 = rc.sample_baked(float(i) * 6.0)
			var cx: int = int((p.x - start_x) / cell_x)
			var cz: int = int((p.z - start_z) / cell_z)
			var rad_x: int = int(ceil(60.0 / cell_x))
			var rad_z: int = int(ceil(60.0 / cell_z))
			for gz in range(maxi(cz - rad_z, 0), mini(cz + rad_z + 1, mask_res)):
				for gx in range(maxi(cx - rad_x, 0), mini(cx + rad_x + 1, mask_res)):
					mask[gz * mask_res + gx] = 1

	var heights := PackedFloat32Array()
	heights.resize(stride * stride)
	for gz in range(res + 1):
		var pz: float = start_z + float(gz) * step_z
		var mz: int = clampi(int((pz - start_z) / cell_z), 0, mask_res - 1)
		for gx in range(res + 1):
			var px: float = start_x + float(gx) * step_x
			var idx: int = gz * stride + gx
			var h: float = _alpine_height(px, pz)
			h = _apply_crevasse(h, px, pz, gorge_curve)
			var mx: int = clampi(int((px - start_x) / cell_x), 0, mask_res - 1)
			if mask[mz * mask_res + mx] == 1:
				h = _apply_road_corridors(h, px, pz)
			heights[idx] = h

	var valley_mesh := _build_heightfield_mesh(heights, stride, res, start_x, start_z, step_x, step_z)
	var valley_shape: ConcavePolygonShape3D = valley_mesh.create_trimesh_shape()
	valley_shape.backface_collision = true

	var valley_body := StaticBody3D.new()
	valley_body.name = "GlacierValley"
	var valley_mesh_inst := MeshInstance3D.new()
	valley_mesh_inst.name = "ValleyMesh"
	valley_mesh_inst.mesh = _save_baked_resource(valley_mesh, "alpine_terrain_visual")
	valley_mesh_inst.material_override = _alpine_material()
	valley_mesh_inst.lod_bias = 8.0
	valley_body.add_child(valley_mesh_inst)
	var valley_col := CollisionShape3D.new()
	valley_col.name = "ValleyCollision"
	valley_col.shape = _save_baked_resource(valley_shape, "alpine_terrain_collision_shape")
	valley_body.add_child(valley_col)
	terrain_root.add_child(valley_body)

	# --- 2. Tunnel massif: a rock ridge with a portal notch the highway drives through --
	var massif_mesh := _build_tunnel_massif()
	var massif_shape: ConcavePolygonShape3D = massif_mesh.create_trimesh_shape()
	massif_shape.backface_collision = true

	var massif_body := StaticBody3D.new()
	massif_body.name = "TunnelMassif"
	var massif_inst := MeshInstance3D.new()
	massif_inst.name = "MassifMesh"
	massif_inst.mesh = _save_baked_resource(massif_mesh, "alpine_massif_visual")
	massif_inst.material_override = _alpine_material()
	massif_body.add_child(massif_inst)
	var massif_col := CollisionShape3D.new()
	massif_col.name = "MassifCollision"
	massif_col.shape = _save_baked_resource(massif_shape, "alpine_massif_collision_shape")
	massif_body.add_child(massif_col)
	terrain_root.add_child(massif_body)

	parent.add_child(terrain_root)

	_verify_tunnel_is_open(massif_mesh, valley_mesh)
	_audit_portal_closure(massif_mesh)

## Both portals must be closed by rock from the tunnel roof upward. A missing or collapsed
## lintel leaves the bore open to the sky from outside, which reads as "the mountain above the
## tunnel has disappeared" from the far side of the circuit.
func _audit_portal_closure(massif: ArrayMesh) -> void:
	var arrays: Array = massif.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var probe_lo: float = TUNNEL_ROOF_Y
	for plane in [[TUNNEL_Z_NORTH, "north"], [TUNNEL_Z_SOUTH, "south"]]:
		# How far the rock has to reach. The south portal sits in a deliberately low col (the
		# viaduct crosses 5m above it), so the test is "closed up to the local ridge", not a
		# fixed height.
		var ridge: float = _massif_crest(0.0, plane[0])
		var probe_hi: float = minf(TUNNEL_ROOF_Y + 6.0, ridge - 0.3)
		var covered := false
		for t in range(idx.size() / 3):
			var a: Vector3 = verts[idx[t * 3]]
			var b: Vector3 = verts[idx[t * 3 + 1]]
			var c: Vector3 = verts[idx[t * 3 + 2]]
			var cz: float = (a.z + b.z + c.z) / 3.0
			if absf(cz - plane[0]) > 1.5:
				continue
			var cx: float = (a.x + b.x + c.x) / 3.0
			if absf(cx) > TUNNEL_BORE_HALF_W - 1.0:
				continue
			var lo: float = minf(a.y, minf(b.y, c.y))
			var hi: float = maxf(a.y, maxf(b.y, c.y))
			if lo <= probe_lo + 0.3 and hi >= probe_hi:
				covered = true
				break
		if covered:
			print("  %s portal closed by rock above the bore (roof %.1fm -> ridge %.1fm)" % [plane[1], probe_lo, ridge])
		else:
			push_error("The %s portal has no rock above the bore between y=%.1f and %.1f - the mountain reads as a hollow shell from outside" % [plane[1], probe_lo, probe_hi])

## Guards the one thing a heightfield cannot express: a hole through a rock face. The bore and
## both portal approaches are swept for any triangle standing between the deck and the tunnel
## ceiling. Terrain *below* deck level is the road's own embankment and is expected.
func _verify_tunnel_is_open(massif: ArrayMesh, valley: ArrayMesh) -> void:
	# Clearance box a car needs: the carriageway plus a little air, extended past each portal.
	var z_south: float = TUNNEL_Z_SOUTH + 6.0
	var z_north: float = TUNNEL_Z_NORTH - 6.0
	var half_w: float = MAIN_HALF_W - 0.5
	var y_lo: float = TUNNEL_DECK_Y + 0.05
	var y_hi: float = 6.4
	var blocked: int = 0
	var worst := ""
	for label in [["massif", massif], ["valley", valley]]:
		var arrays: Array = label[1].surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(idx.size() / 3):
			var a: Vector3 = verts[idx[t * 3]]
			var b: Vector3 = verts[idx[t * 3 + 1]]
			var c: Vector3 = verts[idx[t * 3 + 2]]
			var minx: float = minf(a.x, minf(b.x, c.x))
			var maxx: float = maxf(a.x, maxf(b.x, c.x))
			var minz: float = minf(a.z, minf(b.z, c.z))
			var maxz: float = maxf(a.z, maxf(b.z, c.z))
			if maxx < -half_w or minx > half_w or maxz < z_north or minz > z_south:
				continue
			var miny: float = minf(a.y, minf(b.y, c.y))
			var maxy: float = maxf(a.y, maxf(b.y, c.y))
			if maxy < y_lo or miny > y_hi:
				continue
			blocked += 1
			if blocked <= 4:
				worst += "\n    %s tri %d  x[%.1f %.1f] z[%.1f %.1f] y[%.2f %.2f]" % [
					label[0], t, minx, maxx, minz, maxz, miny, maxy]
	if blocked > 0:
		push_error("Tunnel bore is obstructed by %d triangle(s) - a portal will be walled off:%s" % [blocked, worst])
	else:
		print("  tunnel bore clear: no terrain between deck and ceiling across both portals")

## Natural alpine ground: a broad glacial valley along the circuit, foothills starting
## right at the valley shoulder, and ridged massifs rising beyond them.
func _alpine_height(px: float, pz: float) -> float:
	# Rolling snowfield on the valley floor: long dunes, medium drifts and wind-carved
	# sastrugi so the glacier floor is not a featureless white sheet.
	var h: float = 1.7
	h += _base_noise.get_noise_2d(px, pz) * 3.4
	h += _detail_noise.get_noise_2d(px, pz) * 2.6
	# Sastrugi: wind-carved ridges stretched along the prevailing valley direction.
	h += _detail_noise.get_noise_2d(px * 3.4, pz * 0.55) * 0.85
	h += _ridge_noise.get_noise_2d(px * 4.5, pz * 4.5) * 0.45

	# The valley axis meanders gently north-south.
	var axis_x: float = 10.0 + sin(pz * 0.0042) * 42.0
	var dx: float = absf(px - axis_x)
	var flank: float = maxf(smoothstep(120.0, 380.0, dx), smoothstep(320.0, 640.0, dx) * 0.0)
	# North closes in behind the basin; the south stays open around start/finish.
	var north: float = smoothstep(340.0, 640.0, -(pz + 20.0))
	var south: float = smoothstep(430.0, 720.0, pz + 20.0)
	var mask: float = maxf(maxf(flank, north), south)

	# Ridged multifractal: sharp crests and rounded gullies instead of lumpy blobs.
	var ridge: float = clampf(_ridge_noise.get_noise_2d(px, pz) * 0.5 + 0.5, 0.0, 1.0)
	var h_mountains: float = mask * 18.0 + pow(mask, 2.2) * 128.0 + mask * 42.0 * ridge
	h += h_mountains

	# The heightfield has to end somewhere, so the last stretch before the footprint edge
	# climbs hard enough to close the horizon. Without this the flat cut edge of the mesh is
	# visible from any elevated camera as a straight line against the sky.
	var edge_r: float = maxf(absf(px - ALPINE_TERRAIN_CENTER.x), absf(pz - ALPINE_TERRAIN_CENTER.y)) / (ALPINE_TERRAIN_SIZE * 0.5)
	h += smoothstep(0.84, 1.0, edge_r) * 95.0
	return h

## Cuts the Gorge Cut's crevasse: a raised ice rim with a trough dropped well below the
## service road, so the shortcut really does dive between walls instead of running over a
## flat snowfield. The cut deepens along the route and is shallow at both junctions, where it
## has to tie back into the trunk highway.
func _apply_crevasse(h: float, px: float, pz: float, gorge_curve: Curve3D) -> float:
	if gorge_curve == null:
		return h
	var off: float = gorge_curve.get_closest_offset(Vector3(px, 0.0, pz))
	var c: Vector3 = gorge_curve.sample_baked(off)
	var d: float = Vector2(px - c.x, pz - c.z).length()
	if d > 120.0:
		return h
	var depth: float = 1.8 + 6.2 * smoothstep(10.0, 48.0, off)
	# Raise an ice rim either side of the cut, then drop the trough under the service road.
	var rim: float = smoothstep(30.0, 95.0, d) * 9.0
	var with_rim: float = h + rim
	var trough: float = 1.0 - smoothstep(17.0, 30.0, d)
	if trough <= 0.0:
		return with_rim
	trough = trough * trough * (3.0 - 2.0 * trough)
	return lerpf(with_rim, c.y - depth, trough)

## Depth of the box girder under a deck at height `y`. Thicker girders under higher decks.
func _girder_depth(deck_y: float) -> float:
	return clampf(0.55 + (deck_y - 2.6) * 0.30, 0.55, 1.05)

## Ground height that puts the underside of a deck's girder exactly on the shelf, so the
## embankment carries the road instead of leaving it hovering.
func _shelf_y(deck_y: float) -> float:
	return deck_y - 0.12 - _girder_depth(deck_y)

## Builds a horizontal index of every carriageway sample.
##
## Corridor shaping has to work on *horizontal* distance, not Curve3D.get_closest_offset(): the
## high overpass flies directly over the tunnel, so a 3D nearest-point query hands the terrain
## the viaduct 14m overhead instead of the road 15m away, and the tunnel bore ends up uncut.
func _build_road_index() -> void:
	_road_xz = PackedVector2Array()
	_road_y = PackedFloat32Array()
	_road_cells.clear()
	for road in ROAD_CURVES:
		var rc: Curve3D = road
		var length: float = rc.get_baked_length()
		var steps: int = int(length / 2.0)
		for i in range(steps + 1):
			var p: Vector3 = rc.sample_baked(minf(float(i) * 2.0, length))
			var idx: int = _road_xz.size()
			_road_xz.append(Vector2(p.x, p.z))
			_road_y.append(p.y)
			var key: int = _road_cell_key(int(floor(p.x / ROAD_CELL)), int(floor(p.z / ROAD_CELL)))
			var bucket: PackedInt32Array = _road_cells.get(key, PackedInt32Array())
			bucket.append(idx)
			_road_cells[key] = bucket
	print("  road index: %d samples in %d cells" % [_road_xz.size(), _road_cells.size()])

func _road_cell_key(cx: int, cz: int) -> int:
	# Bias the cell index so neighbouring cells cannot collide.
	return (cx + 32768) * 65536 + (cz + 32768)

## Graded shelf under every carriageway so the highway sits on the ground (or in a cutting)
## instead of hovering over it. The shelf is cut *and* filled, which is what turns a dip in the
## snow into an embankment carrying the road.
##
## The nearest carriageway decides the shelf, so where roads cross (the tunnel running under the
## overpass) the lower deck always wins. Elevated viaduct sections only impose a ceiling: their
## bents and the valley beneath them must stay visible.
func _apply_road_corridors(h: float, px: float, pz: float) -> float:
	var cx: int = int(floor(px / ROAD_CELL))
	var cz: int = int(floor(pz / ROAD_CELL))
	var shelf: float = h
	var weight: float = -1.0
	var ceiling: float = 1e9
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			var bucket: PackedInt32Array = _road_cells.get(_road_cell_key(gx, gz), PackedInt32Array())
			for s in bucket:
				var dx: float = px - _road_xz[s].x
				var dz: float = pz - _road_xz[s].y
				var d2: float = dx * dx + dz * dz
				if d2 > ROAD_CORRIDOR_RADIUS * ROAD_CORRIDOR_RADIUS:
					continue
				var d: float = sqrt(d2)
				var road_y: float = _road_y[s]
				var s_shelf: float = _shelf_y(road_y)
				if road_y - h > 4.5:
					# Genuine bridge span: only guarantee the deck is not buried, never fill.
					if d < 14.0:
						ceiling = minf(ceiling, s_shelf)
					continue
				var t: float = 1.0 - smoothstep(13.0, ROAD_CORRIDOR_RADIUS, d)
				t = t * t * (3.0 - 2.0 * t)
				if t > 0.0 and (t > weight or (is_equal_approx(t, weight) and s_shelf < shelf)):
					weight = t
					shelf = s_shelf
	if weight > 0.0:
		h = lerpf(h, shelf, weight)
	return minf(h, ceiling)

## Heightfield -> smooth-shaded ArrayMesh with world-space UVs for triplanar mapping.
func _build_heightfield_mesh(heights: PackedFloat32Array, stride: int, res: int,
		start_x: float, start_z: float, step_x: float, step_z: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for gz in range(res + 1):
		for gx in range(res + 1):
			var idx: int = gz * stride + gx
			var h: float = heights[idx]
			var h_l: float = heights[gz * stride + maxi(gx - 1, 0)]
			var h_r: float = heights[gz * stride + mini(gx + 1, res)]
			var h_d: float = heights[maxi(gz - 1, 0) * stride + gx]
			var h_u: float = heights[mini(gz + 1, res) * stride + gx]
			var dx: float = float(mini(gx + 1, res) - maxi(gx - 1, 0)) * step_x
			var dz: float = float(mini(gz + 1, res) - maxi(gz - 1, 0)) * step_z
			var px: float = start_x + float(gx) * step_x
			var pz: float = start_z + float(gz) * step_z
			# Analytic normals from the height gradient: no faceting on the big surfaces.
			st.set_normal(Vector3(h_l - h_r, dx, h_d - h_u).normalized())
			st.set_uv(Vector2(px, pz))
			st.add_vertex(Vector3(px, h, pz))
	for gz in range(res):
		for gx in range(res):
			var i: int = gz * stride + gx
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + stride)
			st.add_index(i + 1)
			st.add_index(i + stride + 1)
			st.add_index(i + stride)
	st.generate_tangents()
	return st.commit()

## The rock spur the tunnel passes through.
##
## A fine local heightfield (the valley grid is far too coarse for a 24m wide portal). The
## 2m grid is aligned so a cell row lands exactly on each portal plane. Inside the bore the
## surface is the tunnel roof, and every quad in the bore's width that is not that roof is
## dropped - so the bore is an open channel through the whole spur, with the rock face closing
## around it at each end and the concrete portal structure filling the last few metres.
func _build_tunnel_massif() -> ArrayMesh:
	var res_x: int = 150
	var res_z: int = 38 # (248 - 172) / 2m cells
	var x0: float = TUNNEL_MASSIF_MIN.x
	var x1: float = TUNNEL_MASSIF_MAX.x
	var z0: float = TUNNEL_MASSIF_MIN.y
	var z1: float = TUNNEL_MASSIF_MAX.y
	var step_x: float = (x1 - x0) / float(res_x)
	var step_z: float = (z1 - z0) / float(res_z)
	var stride: int = res_x + 1

	var heights := PackedFloat32Array()
	heights.resize(stride * (res_z + 1))
	for gz in range(res_z + 1):
		var pz: float = z0 + float(gz) * step_z
		for gx in range(res_x + 1):
			var px: float = x0 + float(gx) * step_x
			heights[gz * stride + gx] = _massif_heightfield(px, pz)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for gz in range(res_z + 1):
		for gx in range(res_x + 1):
			var idx: int = gz * stride + gx
			var h: float = heights[idx]
			var h_l: float = heights[gz * stride + maxi(gx - 1, 0)]
			var h_r: float = heights[gz * stride + mini(gx + 1, res_x)]
			var h_d: float = heights[maxi(gz - 1, 0) * stride + gx]
			var h_u: float = heights[mini(gz + 1, res_z) * stride + gx]
			var dx: float = float(mini(gx + 1, res_x) - maxi(gx - 1, 0)) * step_x
			var dz: float = float(mini(gz + 1, res_z) - maxi(gz - 1, 0)) * step_z
			var px: float = x0 + float(gx) * step_x
			var pz: float = z0 + float(gz) * step_z
			st.set_normal(Vector3(h_l - h_r, dx, h_d - h_u).normalized())
			st.set_uv(Vector2(px, pz))
			st.add_vertex(Vector3(px, h, pz))
	for gz in range(res_z):
		for gx in range(res_x):
			var cx: float = x0 + (float(gx) + 0.5) * step_x
			# Nothing may stand across the bore's width. The tunnel roof is flat, so any quad in
			# there that spans a real height difference is a portal wall or the edge of the bored
			# section - drop those and the passage stays open.
			if absf(cx) < TUNNEL_BORE_HALF_W:
				var h_lo: float = minf(minf(heights[gz * stride + gx], heights[gz * stride + gx + 1]),
						minf(heights[(gz + 1) * stride + gx], heights[(gz + 1) * stride + gx + 1]))
				var h_hi: float = maxf(maxf(heights[gz * stride + gx], heights[gz * stride + gx + 1]),
						maxf(heights[(gz + 1) * stride + gx], heights[(gz + 1) * stride + gx + 1]))
				if h_hi - h_lo > 1.5:
					continue
			var i: int = gz * stride + gx
			st.add_index(i)
			st.add_index(i + 1)
			st.add_index(i + stride)
			st.add_index(i + 1)
			st.add_index(i + stride + 1)
			st.add_index(i + stride)

	# The rock over the tunnel. A heightfield carries only one surface per column, so the bore has
	# to be left empty and the mass above it supplied separately.
	#
	# This started life as a cap surface plus two lintel faces, but a single face either way round
	# is not something to gamble the look of the level on: a wrong winding there does not look
	# like a bug, it looks like the mountain has no top. So the plug is a closed solid whose top
	# follows the ridge, and every face's winding is decided from its own geometry.
	_emit_bore_plug(st, stride * (res_z + 1))

	st.generate_tangents()
	return st.commit()

## True while the point is within the stretch of tunnel the bore actually occupies.
func _in_bore_band(pz: float) -> bool:
	return pz > TUNNEL_Z_NORTH - 1.0 and pz < TUNNEL_Z_SOUTH + 1.0

## Surface height of the massif heightfield at (px, pz): the spur's rock, dropped to the tunnel
## roof inside the bore's width so the passage is open, and cut away to a narrow trench where
## the highway approaches either portal from outside the bore.
func _massif_heightfield(px: float, pz: float) -> float:
	var h: float = _massif_crest(px, pz)
	if _in_bore_band(pz):
		var in_x: float = 1.0 - smoothstep(TUNNEL_BORE_HALF_W, TUNNEL_BORE_HALF_W + 5.0, absf(px))
		return lerpf(h, TUNNEL_ROOF_Y, in_x)
	# Outside the bore the highway is in the open, so the spur has to get out of its way.
	# Without this the spur simply stops, leaving a bare open-topped slot beside the portal -
	# which from the far side of the circuit reads as the mountain having no top at all.
	var c: Vector3 = main_track_curve.sample_baked(main_track_curve.get_closest_offset(Vector3(px, h, pz)))
	var d: float = Vector2(px - c.x, pz - c.z).length()
	if d < 16.0:
		h = minf(h, lerpf(c.y - 1.2, h, smoothstep(9.0, 16.0, d)))
	return h

## The spur's natural rock height: a ridge whose face stands on the south portal plane, with a
## skirt at the north end so the footprint never ends on an open edge, a low col where the
## viaduct crosses overhead, and hard shoulders clear of the viaduct's span.
func _massif_crest(px: float, pz: float) -> float:
	var base: float = _alpine_height(px, pz) - 1.4
	var x_prof: float = 1.0 - smoothstep(40.0, 150.0, absf(px))
	var z_south: float = 1.0 - smoothstep(TUNNEL_Z_SOUTH, TUNNEL_Z_SOUTH + 2.0, pz)
	var z_north: float = smoothstep(TUNNEL_Z_NORTH - 8.0, TUNNEL_Z_NORTH - 2.0, pz)
	var z_amp: float = 0.35 + 0.65 * smoothstep(TUNNEL_Z_SOUTH - 6.0, TUNNEL_Z_SOUTH - 26.0, pz)
	var x_amp: float = 1.0 + 0.9 * smoothstep(75.0, 145.0, absf(px))
	var ridge: float = clampf(_ridge_noise.get_noise_2d(px * 1.4, pz * 1.4) * 0.5 + 0.5, 0.0, 1.0)
	return base + (24.0 + 18.0 * ridge) * x_prof * z_south * z_north * z_amp * x_amp

## Closed rock solid filling the bore: a ridge-following top, a flat underside at the tunnel
## roof, and four walls, so no view direction can see sky through the mountain. Each face is
## wound from its own geometry so it can never end up invisible.
func _emit_bore_plug(st: SurfaceTool, first: int) -> void:
	var bot: float = TUNNEL_ROOF_Y - 0.5
	var half_w: float = TUNNEL_BORE_HALF_W + 8.0
	var z_a: float = TUNNEL_Z_NORTH - 0.5
	var z_b: float = TUNNEL_Z_SOUTH + 0.5
	var cols: int = 9
	var rows: int = 25
	var quads: Array = []
	var top_y := func(px: float, pz: float) -> float: return _massif_crest(px, pz) - 0.35
	var at := func(r: int, c: int) -> Vector3:
		var pz: float = lerpf(z_a, z_b, float(r) / float(rows))
		var px: float = lerpf(-half_w, half_w, float(c) / float(cols))
		return Vector3(px, top_y.call(px, pz), pz)
	var floor_at := func(r: int, c: int) -> Vector3:
		return Vector3((at.call(r, c) as Vector3).x, bot, (at.call(r, c) as Vector3).z)
	for r in range(rows):
		for c in range(cols):
			quads.append([at.call(r, c), at.call(r, c + 1), at.call(r + 1, c + 1), at.call(r + 1, c), Vector3(0, -1, 0)])
			quads.append([floor_at.call(r, c), floor_at.call(r, c + 1), floor_at.call(r + 1, c + 1), floor_at.call(r + 1, c), Vector3(0, 1, 0)])
	for c in range(cols):
		quads.append([floor_at.call(0, c), floor_at.call(0, c + 1), at.call(0, c + 1), at.call(0, c), Vector3(0, 0, 1)])
		quads.append([floor_at.call(rows, c + 1), floor_at.call(rows, c), at.call(rows, c), at.call(rows, c + 1), Vector3(0, 0, -1)])
	for r in range(rows):
		quads.append([floor_at.call(r + 1, 0), floor_at.call(r, 0), at.call(r, 0), at.call(r + 1, 0), Vector3(1, 0, 0)])
		quads.append([floor_at.call(r, cols), floor_at.call(r + 1, cols), at.call(r + 1, cols), at.call(r, cols), Vector3(-1, 0, 0)])

	var base: int = first
	var centre := Vector3(0.0, 20.0, (z_a + z_b) * 0.5)
	for q in quads:
		for p in [q[0], q[1], q[2], q[3]]:
			var v: Vector3 = p
			st.set_normal((v - centre).normalized())
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
		var n: Vector3 = ((q[1] as Vector3) - (q[0] as Vector3)).cross((q[2] as Vector3) - (q[0] as Vector3))
		if n.dot(q[4] as Vector3) > 0.0:
			st.add_index(base); st.add_index(base + 1); st.add_index(base + 2)
			st.add_index(base); st.add_index(base + 2); st.add_index(base + 3)
		else:
			st.add_index(base); st.add_index(base + 2); st.add_index(base + 1)
			st.add_index(base); st.add_index(base + 3); st.add_index(base + 2)
		base += 4

## Snow-and-rock material for the alpine terrain.
func _alpine_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://alpine_snow.gdshader")
	if mat.shader:
		var rock: Texture2D = load("res://materials/dark_rock.png") as Texture2D
		var rock_n: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D
		if rock:
			mat.set_shader_parameter("rock_albedo", rock)
		if rock_n:
			mat.set_shader_parameter("rock_normal", rock_n)
		mat.set_shader_parameter("rock_tint", Color(1.45, 1.48, 1.58))
		mat.set_shader_parameter("snow_color", Color(0.78, 0.825, 0.90))
	return mat

## Writes a generated mesh/shape to res://generated/ and returns the loaded resource, so the
## level scene references the file instead of inlining megabytes of vertex data.
func _save_baked_resource(res: Resource, res_name: String) -> Resource:
	if not DirAccess.dir_exists_absolute("res://generated/"):
		DirAccess.make_dir_absolute("res://generated/")
	var file_path: String = "res://generated/glacier_highway_" + res_name + ".res"
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	return load(file_path)


## Builds a trackside jumbotron beside the start/finish straight: a screen on a steel frame
## showing the race from a chase camera the players never see. The screen is a live render
## target, so it is deliberately small and refreshed a few times a second (see Jumbotron.gd).
func _build_jumbotron(parent: Node) -> void:
	var screen := Node3D.new()
	screen.name = "Jumbotron"
	var board_script: Script = load("res://Jumbotron.gd")
	if board_script:
		screen.set_script(board_script)
	# NOTE: added to the tree at the very end of this function, once the broadcast viewport
	# exists - entering the tree runs Jumbotron._ready(), which looks the viewport up.

	# Beside the main straight, facing oncoming traffic (the field runs from Z=280 toward Z=160).
	var yaw: float = deg_to_rad(-18.0)
	screen.position = Vector3(-56.0, 0.0, 238.0)
	screen.rotation.y = yaw

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.30, 0.33, 0.37)
	steel.metallic = 0.85
	steel.roughness = 0.45
	var dark_steel := StandardMaterial3D.new()
	dark_steel.albedo_color = Color(0.16, 0.18, 0.21)
	dark_steel.metallic = 0.7
	dark_steel.roughness = 0.55

	var panel_size := Vector2(15.0, 8.44)
	var panel_height: float = 13.0
	var tilt: float = deg_to_rad(-7.0)

	# Broadcast viewport. Kept deliberately plain and close to the proven jetski VideoScreen:
	# the render target starts armed (UPDATE_ONCE) and the camera is current from the start, and
	# `own_world_3d` is left alone - it already defaults to inheriting the parent's World3D, so
	# the board sees the real race rather than a copy.
	var viewport := SubViewport.new()
	viewport.name = "BroadcastViewport"
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var vp_cam := Camera3D.new()
	vp_cam.name = "BroadcastCamera"
	vp_cam.current = true
	vp_cam.fov = 55.0
	vp_cam.near = 0.5
	vp_cam.far = 300.0
	viewport.add_child(vp_cam)
	screen.add_child(viewport)

	# The screen face gets its material from Jumbotron.gd at runtime, which binds the
	# viewport's texture to an albedo.
	var panel := MeshInstance3D.new()
	panel.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = panel_size
	panel.mesh = quad
	panel.position = Vector3(0.0, panel_height, 0.0)
	panel.rotation.x = tilt
	screen.add_child(panel)

	# Housing behind the screen
	var housing := MeshInstance3D.new()
	housing.name = "Housing"
	var hb := BoxMesh.new()
	hb.size = Vector3(panel_size.x + 0.9, panel_size.y + 0.9, 0.8)
	housing.mesh = hb
	housing.material_override = dark_steel
	housing.position = Vector3(0.0, panel_height, -0.55)
	housing.rotation.x = tilt
	screen.add_child(housing)

	# Truss frame and legs
	var frame_top := MeshInstance3D.new()
	frame_top.name = "FrameTop"
	var fb := BoxMesh.new()
	fb.size = Vector3(panel_size.x + 1.6, 0.45, 0.45)
	frame_top.mesh = fb
	frame_top.material_override = steel
	frame_top.position = Vector3(0.0, panel_height + panel_size.y * 0.5 + 0.5, -0.3)
	screen.add_child(frame_top)

	var frame_bottom := MeshInstance3D.new()
	frame_bottom.name = "FrameBottom"
	frame_bottom.mesh = fb
	frame_bottom.material_override = steel
	frame_bottom.position = Vector3(0.0, panel_height - panel_size.y * 0.5 - 0.5, -0.3)
	screen.add_child(frame_bottom)

	var leg_h: float = panel_height - panel_size.y * 0.5 - 0.5
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		leg.name = "Leg_%s" % ("L" if side < 0.0 else "R")
		var lb := BoxMesh.new()
		lb.size = Vector3(0.55, leg_h, 0.55)
		leg.mesh = lb
		leg.material_override = steel
		leg.position = Vector3(side * (panel_size.x * 0.5 + 0.55), leg_h * 0.5, -0.3)
		screen.add_child(leg)

		var brace := MeshInstance3D.new()
		brace.name = "Brace_%s" % ("L" if side < 0.0 else "R")
		var bb := BoxMesh.new()
		bb.size = Vector3(0.3, 0.3, 5.0)
		brace.mesh = bb
		brace.material_override = steel
		brace.position = Vector3(side * (panel_size.x * 0.5 + 0.55), leg_h * 0.35, 2.2)
		screen.add_child(brace)

	parent.add_child(screen)

## Builds highway overhead gantry signs spanning across the 4-lane concrete highway.
func _build_highway_gantries(parent: Node) -> void:
	var gantry_defs = [
		[Vector3(-85.0, 2.8, 220.0), 0.0, "GLACIER HIGHWAY GP • SPEED LIMIT: NONE"],
		[Vector3(-83.5, 2.8, 85.0), 0.0, "RIGHT LANE: EXPRESS FLYOVER ↗ • ELEVATED BYPASS"],
		[Vector3(0.0, 2.8, -173.0), 0.0, "TUNNEL APPROACH • CLEARANCE 6.0M • LOW BEAM LIGHTS"],
		[Vector3(0.0, 2.8, -265.0), 0.0, "RIGHT LANE: GLACIER GORGE CUT ↘ • CANYON RUN"],
		[Vector3(0.0, 16.5, -180.0), -90.0, "GLACIER OVERPASS VIADUCT • HIGH SUMMIT CROSSING"],
		[Vector3(-50.0, 16.5, -180.0), -90.0, "LEFT LANE: RIDGE BYPASS ↖ • SCENIC VIADUCT"]
	]

	var steel_mat := StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.42, 0.45, 0.49)
	steel_mat.metallic = 0.85
	steel_mat.roughness = 0.35

	for i in range(gantry_defs.size()):
		var g_info = gantry_defs[i]
		var g_pos: Vector3 = g_info[0]
		var g_yaw: float = g_info[1]

		var gantry := StaticBody3D.new()
		gantry.name = "HighwayGantry_%d" % (i + 1)
		gantry.position = g_pos
		gantry.rotation_degrees = Vector3(0, g_yaw, 0)

		# Horizontal Truss Span across road (width = 19m, clearance height = 6.2m)
		var span := MeshInstance3D.new()
		span.name = "TrussSpan"
		var sm := BoxMesh.new()
		sm.size = Vector3(19.0, 1.1, 1.2)
		span.mesh = sm
		span.material_override = steel_mat
		span.position = Vector3(0, 6.2, 0)
		gantry.add_child(span)

		var span_col := CollisionShape3D.new()
		span_col.name = "SpanCol"
		var span_shape := BoxShape3D.new()
		span_shape.size = sm.size
		span_col.shape = span_shape
		span_col.position = span.position
		gantry.add_child(span_col)

		# Left and Right Vertical Support Columns
		for side in [-1.0, 1.0]:
			var col := MeshInstance3D.new()
			col.name = "Support_" + ("L" if side < 0 else "R")
			var cm := CylinderMesh.new()
			cm.top_radius = 0.40
			cm.bottom_radius = 0.45
			cm.height = 6.8
			col.mesh = cm
			col.material_override = steel_mat
			col.position = Vector3(side * 9.2, 3.4, 0)
			gantry.add_child(col)

			var col_col := CollisionShape3D.new()
			col_col.name = "SupportCol_" + ("L" if side < 0 else "R")
			var col_shape := CylinderShape3D.new()
			col_shape.radius = 0.45
			col_shape.height = 6.8
			col_col.shape = col_shape
			col_col.position = col.position
			gantry.add_child(col_col)

		# Overhead Green Interstate Sign Board
		var sign_board := MeshInstance3D.new()
		sign_board.name = "SignBoard"
		var sbm := BoxMesh.new()
		sbm.size = Vector3(14.0, 1.8, 0.20)
		sign_board.mesh = sbm
		var sign_mat := StandardMaterial3D.new()
		sign_mat.albedo_color = Color(0.04, 0.32, 0.16) # Interstate highway green
		sign_mat.emission_enabled = true
		sign_mat.emission = Color(0.08, 0.42, 0.22)
		sign_mat.emission_energy_multiplier = 0.4
		sign_board.material_override = sign_mat
		sign_board.position = Vector3(0, 6.2, 0.65)
		gantry.add_child(sign_board)

		# Legend on the sign face. Sized to wrap inside the 14m x 1.8m board.
		var sign_text := Label3D.new()
		sign_text.name = "SignText"
		sign_text.text = g_info[2]
		sign_text.font_size = 96
		sign_text.pixel_size = 0.0085
		sign_text.width = 1650
		sign_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sign_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sign_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sign_text.modulate = Color(0.94, 0.96, 0.98)
		sign_text.outline_size = 0
		sign_text.no_depth_test = false
		sign_text.double_sided = false
		sign_text.position = Vector3(0, 6.2, 0.78)
		gantry.add_child(sign_text)

		parent.add_child(gantry)


## Builds highway streetlights along the outer barrier edges with illuminating spotlights.
func _build_highway_streetlights(parent: Node, curve: Curve3D, left_gaps: Array = [], right_gaps: Array = []) -> void:
	var total_len := curve.get_baked_length()
	var step_dist := 65.0
	var count := int(total_len / step_dist)

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.65, 0.68, 0.72)
	pole_mat.metallic = 0.75
	pole_mat.roughness = 0.4

	for i in range(count):
		var dist = i * step_dist
		var p := curve.sample_baked(dist)
		# Skip lights inside the tunnel underpass (it has its own interior LED strip lights)
		if p.z < -165.0 and p.z > -245.0 and p.y < 5.0:
			continue

		var next_p := curve.sample_baked(minf(total_len, dist + 1.0))
		var fwd := (next_p - p).normalized()
		var right := Vector3(-fwd.z, 0, fwd.x).normalized()

		# Place alternating on left or right barrier
		var side := 1.0 if (i % 2 == 0) else -1.0

		# Do not place a streetlight inside or near an on-ramp/off-ramp barrier gap on this side
		var gaps_to_check = right_gaps if side > 0 else left_gaps
		var in_gap = false
		for gap in gaps_to_check:
			if dist >= (gap.x - 8.0) and dist <= (gap.y + 8.0):
				in_gap = true
				break
		if in_gap:
			continue

		# Barrier-mounted mast: the pole stands on the Jersey barrier top so it is supported
		# by the deck instead of floating past the shoulder.
		var pole_pos = p + right * (side * 7.9)

		var light_node := StaticBody3D.new()
		light_node.name = "Streetlight_%d" % i
		light_node.position = pole_pos

		var rot_y := rad_to_deg(atan2(-fwd.x, -fwd.z))
		light_node.rotation_degrees = Vector3(0, rot_y + (180.0 if side > 0 else 0.0), 0)

		# Vertical Pole (height = 8.5m, based on the barrier crown)
		var pole_base: float = 0.81
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.12
		pm.bottom_radius = 0.22
		pm.height = 8.5
		pole.mesh = pm
		pole.material_override = pole_mat
		pole.position = Vector3(0, pole_base + 4.25, 0)
		light_node.add_child(pole)

		var pole_col := CollisionShape3D.new()
		pole_col.name = "PoleCol"
		var pole_shape := CylinderShape3D.new()
		pole_shape.radius = 0.22
		pole_shape.height = 8.5
		pole_col.shape = pole_shape
		pole_col.position = pole.position
		light_node.add_child(pole_col)

		# Horizontal Overhanging Arm
		var arm := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.08
		am.bottom_radius = 0.10
		am.height = 3.2
		arm.mesh = am
		arm.material_override = pole_mat
		arm.position = Vector3(1.4, pole_base + 8.2, 0)
		arm.rotation_degrees = Vector3(0, 0, -80.0)
		light_node.add_child(arm)

		# LED Luminaire Head
		var head := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(0.9, 0.2, 0.4)
		head.mesh = hm
		var head_mat := StandardMaterial3D.new()
		head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		head_mat.albedo_color = Color(0.92, 0.96, 1.0)
		head.material_override = head_mat
		head.position = Vector3(2.8, pole_base + 8.4, 0)
		light_node.add_child(head)

		# SpotLight illuminating the concrete highway road surface
		var spot := SpotLight3D.new()
		spot.name = "Spot"
		spot.position = Vector3(2.8, pole_base + 8.3, 0)
		spot.rotation_degrees = Vector3(-90, 0, 0)
		spot.light_color = Color(0.88, 0.94, 1.0) # Cool winter LED
		spot.light_energy = 1.6
		spot.spot_range = 22.0
		spot.spot_angle = 50.0
		spot.spot_attenuation = 1.1
		light_node.add_child(spot)

		parent.add_child(light_node)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
