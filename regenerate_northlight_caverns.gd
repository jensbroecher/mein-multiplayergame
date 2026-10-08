# regenerate_northlight_caverns.gd
#
# Builds levels/NorthlightCavernsLevel.tscn - the third Arctic Cup stage. A night race under
# the northern lights.
#
# Theme: the circuit is cut into a glacier on a polar night. The start/finish straight runs
# across a frozen lake under the aurora, the road then dives into a glacier ice cavern (a
# 190m translucent gallery with glowing veins and light shafts), comes out onto a high ice
# shelf, crosses a 50m crevasse on a natural ice arch, and sweeps home through a field of
# seracs. Two alternative routes: the Meltwater Cut, a sunken frozen channel, and the Serac
# Ledge, a narrow shelf between ice towers.
#
# Three things are worth knowing before editing this file, because none of them are obvious
# from the geometry:
#
# 1. The cavern does NOT bore a hole through the terrain heightfield. The heightfield is
#    raised into a glacier ridge over the whole cavern stretch and corridor grading is
#    switched off inside it, so the passage is a closed swept shell sitting inside solid
#    rock and the terrain closes both portals on its own. That is also why the shell is
#    authored with inward-facing normals and cull_disabled: from the driver's seat only its
#    inside is ever visible, and a wrong winding there would show as a missing wall.
#
# 2. The ice arch over the crevasse is not a separate structure either. The road mesh's
#    underside dips as a parabola inside the bridge span, so the arch springs straight out
#    of the deck geometry and can never drift out of register with it.
#
# 3. Road edges are ploughed snow banks, not crash barriers. Alternative-route decks are
#    tiled onto the trunk deck edge exactly like the highway ramps (see _ramp_deck_extents),
#    and the trunk bank opens itself wherever a route runs alongside it.
extends Node

const LEVEL_NAME := "NorthlightCavernsLevel"
const LEVEL_PATH := "res://levels/NorthlightCavernsLevel.tscn"
const RES_PREFIX := "northlight_"

## Where the trunk centreline lives, so route junctions can be measured against it.
var main_track_curve: Curve3D

# --- Road geometry --------------------------------------------------------------------
## Trunk carriageway and route widths. A route nose sits exactly one trunk half width off
## the centreline, which is what lets the two decks tile without overlapping.
const MeshChunker = preload("res://MeshChunker.gd")
## Level-spanning visual meshes (road ribbons, barriers, terrain) are split into cells this size
## before saving, so cameras and shadow passes (every streetlight's included) draw only the cells
## they can see instead of the whole track. Geometry is unchanged.
const MESH_CHUNK_CELL := 80.0

const MAIN_WIDTH := 15.0
const MAIN_HALF_W := 7.5
const ROUTE_WIDTH := 11.0
const ROUTE_HALF_W := 5.5
## Minimum turn radius targeted when deriving curve handles. The deck's inner edge sits at
## radius - half_width, so anything near half_width folds the road through itself.
const TRUNK_MIN_RADIUS := 28.0
const ROUTE_MIN_RADIUS := 16.0
## Tangential run of a route nose along the trunk before it starts to peel away.
const ROUTE_NOSE_HANDLE := 18.0
## How far along the trunk the auto-generated entry/exit waypoints sit before stepping out.
const ROUTE_NOSE_LEAD := 30.0
## Lateral offset those waypoints sit at. Past this the route deck has genuinely left the
## trunk shoulder, which is what lets the trunk bank close again.
const ROUTE_NOSE_LATERAL := 14.5
## Clearance the trunk bank keeps from a route deck before it may close again.
const GORE_CLEARANCE := 2.5
## Baked curve resolution. 0.4m keeps a 15m deck smooth through the tightest corner without
## quadrupling the vertex count against 0.25m.
const BAKE_INTERVAL := 0.4

## Ploughed snow bank cross-section, as (metres inward from the deck edge, metres above the
## deck). The road-side toe and the outer foot both sit below the deck so the bank is
## embedded in the slab and no coplanar surface fights with the road mesh.
const BANK_PROFILE := [
	Vector2(1.15, -0.12),   # road-side toe
	Vector2(1.05, 0.45),    # cut face, near vertical
	Vector2(0.72, 1.90),    # crest
	Vector2(0.24, 2.10),    # top
	Vector2(0.00, 1.90),    # outer shoulder, level with the deck edge
	Vector2(-0.70, -0.12),  # outer foot, spread onto the shoulder
]
const BANK_VERTS := 6
## Metres over which a bank run tapers down to deck level at an open end, so a gap reads as
## a real sloped terminal instead of a sliver poking out of the road.
const BANK_TERMINAL := 2.6
## Thickness of the ordinary ice shelf under a deck, and the depth of the arch at the centre
## of the crevasse span.
const DECK_SLAB := 0.55
const ARCH_DEPTH := 22.0
## Where the underside's parabola puts its vertices across the deck. 0 at the edges, 1 in the
## middle: that is the shape that makes an arch read as an arch instead of as a hanging slab.
const UNDER_DIP := [0.0, 0.58, 1.0, 1.0, 0.58, 0.0]
const UNDER_VERTS := 6

# --- Terrain --------------------------------------------------------------------------
## Icefield heightfield extent / resolution. 6.25m cells over 1.4km: coarse enough to stay
## cheap, fine enough that the ice cliff at each cavern portal reads as a cliff and not as a
## staircase.
const TERRAIN_SIZE := 1400.0
const TERRAIN_RES := 224
const TERRAIN_CENTER := Vector2(40.0, -10.0)
## Horizontal reach of a graded road corridor, and the cell size of the carriageway index.
const ROAD_CORRIDOR_RADIUS := 46.0
const ROAD_CELL := 46.0

## Frozen lake on the start/finish straight. The road runs scraped flat across it, so the
## terrain is not graded there: the corridor would otherwise saw a shallow trough along the
## ice. The same ellipse drives the ground shader, so the shoreline can never disagree with
## the heightfield about where the water ends.
const LAKE_CENTER := Vector2(-150.0, 250.0)
const LAKE_RADIUS := Vector2(172.0, 196.0)
const LAKE_FEATHER := 26.0
const LAKE_SURFACE_Y := 2.66

## Glacier ridge built over the cavern stretch. The height along the ridge steps up over a
## few metres at each portal, which is what turns the mouth into a near-vertical ice face
## instead of a long ramp the tunnel would be buried under.
##
## The massif the cavern is a hole in. HALF_W is the full-height crest, FEATHER is the long
## flank beyond it. These have to clear the cavern shell by a wide margin - the shell's crown is
## 15m over the deck and the ridge here is 60m - so the passage is unambiguously interior.
const CAVERN_MASS_HALF_W := 48.0
const CAVERN_MASS_FEATHER := 78.0
const CAVERN_RIDGE_HEIGHT := 58.0
## Extra height at the summit, partway along the span, so the ridge has a peak instead of being
## a slab of constant height.
const CAVERN_SUMMIT := 26.0
## Broad low apron tying the massif into the icefield, so it does not read as a dropped lump.
const CAVERN_APRON := 17.0
## Crevasse crossed by the ice arch, as a slot in the ice: a centre, a direction, and a
## half-length that tapers to nothing at both tips so the slot never ends on a flat wall.
const CREVASSE_CENTER := Vector2(212.0, -242.0)
const CREVASSE_DIR := Vector2(0.832, 0.555)
const CREVASSE_HALF_LEN := 145.0
const CREVASSE_HALF_W := 26.0
const CREVASSE_DEPTH := 26.0
## Extra corridor radius either side of the slot that the road bridges rather than crosses.
const CREVASSE_ABUTMENT := 10.0

## The cavern shell: a closed cross-section swept along the road. Ordering runs from the
## left wall foot, up and over the crown, down to the right wall foot, and the loop closes
## with the cavern floor - so the gap between the deck edge and the wall has a floor under it
## instead of opening onto the void beneath the heightfield.
const CAVERN_PROFILE := [
	Vector2(-11.0, -2.40),  # left wall foot
	Vector2(-11.0, 3.20),   # springing
	Vector2(-10.2, 8.20),
	Vector2(-7.8, 12.40),
	Vector2(-4.0, 14.80),
	Vector2(0.0, 15.40),   # crown
	Vector2(4.0, 14.80),
	Vector2(7.8, 12.40),
	Vector2(10.2, 8.20),
	Vector2(11.0, 3.20),
	Vector2(11.0, -2.40),  # right wall foot
]
const CAVERN_VERTS := 11
## Widest half width of the shell, i.e. how far out the gallery floor has to reach. The road is
## 15m wide and its banks carry on to 8.6m, so the shell has to clear both.
const CAVERN_HALF_WIDTH := 11.0
## How far the shell reaches past each portal, into the rock. The terrain closes the portal
## on its own; this only guarantees there is no daylight gap at the exact plane.
## The shell ends exactly at the portal planes. Any overshoot here and the arch protrudes from
## the face as a free-standing hoop; with the ramp starting at the portal the mouth reads as a
## notch in the cliff instead.
const CAVERN_OVERSHOOT := 0.0

## Every carriageway the terrain has to make room for, filled in as the curves are built.
var ROAD_CURVES: Array = []
## Road sample index, used by corridor grading. The lateral search has to be on *horizontal*
## distance rather than Curve3D.get_closest_offset(): inside the cavern the ridge overhead
## would otherwise win every nearest-point query and the shelf under the road would never be
## cut.
var _road_xz := PackedVector2Array()
var _road_y := PackedFloat32Array()
var _road_off := PackedFloat32Array()
var _road_ci := PackedInt32Array()
var _road_cells := Dictionary()
## Curve index -> array of [start, end] distance-along ranges where the terrain must NOT be
## graded to the road: the cavern (solid rock overhead), the crevasse bridge (open sky
## underneath) and the frozen lake (the road is scraped into the ice, not built on it).
var _no_grade: Dictionary = {}

## Cavern portals, as distance-along ranges along the trunk. Filled in once the trunk curve
## exists and read back by the terrain, the cavern shell and the portal dressing.
var _cavern_range := Vector2(0.0, 0.0)
## World Z of each portal. The cavern runs due north along X = 0, so this is an exact lookup and
## it lets the terrain audit check the mouths without a nearest-point query per triangle.
var _cavern_portal_z := Vector2(0.0, 0.0)
## Crevasse bridge span along the trunk, derived from the slot geometry.
var _bridge_range := Vector2(-1.0, -1.0)
## Cavern centreline in plan view, with the trunk offset of each sample. Sampled well past both
## portals so the glacier ridge's along-strip can be extrapolated, not just sampled.
var _cavern_line := PackedVector2Array()
var _cavern_off := PackedFloat32Array()
## The cavern's own deck profile as (z, y) samples, so the terrain audit can measure the gallery
## floor against the road height *at that point* rather than against a single figure for a 190m
## stretch that dips 30cm along the way.
var _cavern_zs := PackedFloat32Array()
var _cavern_ys := PackedFloat32Array()

## The finished icefield heights, kept so meshes laid over the terrain afterwards (the cavern
## cap) can sit on the ground that was actually built.
var _terrain_heights := PackedFloat32Array()
var _terrain_origin := Vector2.ZERO
var _terrain_step := 1.0

var _base_noise := FastNoiseLite.new()
var _detail_noise := FastNoiseLite.new()
var _ridge_noise := FastNoiseLite.new()
var _sastrugi_noise := FastNoiseLite.new()

## The road is 15m wide with a 2.1m bank either side, so the cut floor has to be flat past about
## 9m. That is ALL the corridor does inside the cavern.
##
## The tunnel wall is not part of the corridor. The massif is 70m tall and the corridor reach is
## 11m wide, so any blend that climbs the full height across that span is an 85-degree facet on a
## 6.25m heightfield grid - which is what the chevrons along the tunnel were. The massif has to
## reach full height over its own 35m flank instead (CAVERN_MASS_HALF_W), where a gradient of
## about 2.0 is steep but coherent, and the corridor only has to flatten the floor it sits on.
const GLACIER_GALLERY_FLAT_W := 12.0
const GLACIER_GALLERY_HALF_W := 15.0
## Where the audit samples the tunnel wall: clear of the gallery's falloff, so it measures the
## massif rather than the cut through it. Has to track GLACIER_GALLERY_HALF_W.
const WALL_PROBE_LAT := 28.0

# ======================================================================================
#  Curve construction
# ======================================================================================

func _init_noise() -> void:
	_base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_base_noise.seed = 51207
	_base_noise.frequency = 0.0052
	_base_noise.fractal_octaves = 3

	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail_noise.seed = 33914
	_detail_noise.frequency = 0.018
	_detail_noise.fractal_octaves = 3

	# Ridged multifractal gives the ranges real crests and gullies.
	_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_ridge_noise.seed = 77451
	_ridge_noise.frequency = 0.0040
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge_noise.fractal_octaves = 5
	_ridge_noise.fractal_lacunarity = 2.1
	_ridge_noise.fractal_gain = 0.52

	# Sastrugi: wind-carved ridges stretched along the prevailing valley direction.
	_sastrugi_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_sastrugi_noise.seed = 60118
	_sastrugi_noise.frequency = 0.020
	_sastrugi_noise.fractal_octaves = 2


## Handles for one control point, from the directions and lengths of the segments either side.
##
## The tangent bisects the incoming and outgoing travel directions, and its length is whatever
## Catmull-Rom wants or whatever the turn radius needs, capped so the control polygon cannot
## fold back on itself. A dead-straight reversal has no bisector, so that case falls back to
## the horizontal perpendicular that points along the chord across the corner.
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
## cross-sections swing tens of degrees between rings 40cm apart, which folds the deck through
## itself and makes both the surface and the banks flicker. Handles are therefore computed so
## that the tangent at each point matches the actual approach and exit directions, and the
## turn is wide enough for the deck.
##
## `points` are positions; the returned curve appends a closing copy of the first point.
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
	curve.bake_interval = BAKE_INTERVAL
	for i in range(n + 1):
		var idx: int = i % n
		curve.add_point(points[idx], handles[idx][0], handles[idx][1])
	return curve


## Assembles an alternative-route curve whose ends are noses sitting exactly on the trunk deck
## edge (`side` = +1 right / -1 left), with the junction handles aligned to the trunk tangent
## so routes leave and rejoin along the trunk rather than kinking across it.
##
## Junctions are given as world anchors rather than distances along the trunk, so they stay
## where they were authored even when the trunk's own shape is retuned. `waypoints` are plain
## positions between the two noses; interior handles are derived against the trunk direction at
## each end, so the tangent stays continuous across the junction.
func _build_route_curve(split_anchor: Vector3, merge_anchor: Vector3, side: int,
		waypoints: Array) -> Curve3D:
	var split: Dictionary = _frame_at(main_track_curve, split_anchor)
	var merge: Dictionary = _frame_at(main_track_curve, merge_anchor)
	var s_fwd: Vector3 = split["fwd"]
	var m_fwd: Vector3 = merge["fwd"]
	var s_right: Vector3 = split["right"]
	var m_right: Vector3 = merge["right"]
	var nose_a: Vector3 = split["pos"] + s_right * (MAIN_HALF_W * float(side))
	var nose_b: Vector3 = merge["pos"] + m_right * (MAIN_HALF_W * float(side))

	# The approach and departure waypoints are pure offsets of the trunk: `lead` metres past
	# the split, and `lead` metres before the merge. Anchoring them to the trunk curve is what
	# makes the route leave and rejoin along the trunk's own tangent however it is retuned.
	var lead: float = ROUTE_NOSE_LEAD
	var length: float = main_track_curve.get_baked_length()
	var fa: Dictionary = _frame_at_offset(main_track_curve, clampf(split["off"] + lead, 0.0, length))
	var fb: Dictionary = _frame_at_offset(main_track_curve, clampf(merge["off"] - lead, 0.0, length))
	var entry: Vector3 = fa["pos"] + fa["right"] * (float(side) * ROUTE_NOSE_LATERAL)
	var exit_pt: Vector3 = fb["pos"] + fb["right"] * (float(side) * ROUTE_NOSE_LATERAL)
	var pts: Array = [nose_a, entry]
	pts.append_array(waypoints)
	pts.append(exit_pt)
	pts.append(nose_b)

	# The first and last segment of a route leave and arrive along the trunk, so the interior
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
	c.bake_interval = BAKE_INTERVAL
	for i in range(pts.size()):
		var in_h: Vector3
		var out_h: Vector3
		if i == 0:
			in_h = -s_fwd * minf(ROUTE_NOSE_HANDLE, first_len)
			out_h = s_fwd * minf(ROUTE_NOSE_HANDLE, first_len)
		elif i == pts.size() - 1:
			in_h = -m_fwd * minf(ROUTE_NOSE_HANDLE, last_len)
			out_h = m_fwd * minf(ROUTE_NOSE_HANDLE, last_len)
		else:
			var h: Array = _handles_for(segs_in[i], segs_out[i], ROUTE_MIN_RADIUS)
			in_h = h[0]
			out_h = h[1]
		c.add_point(pts[i], in_h, out_h)
	return c


## Fails the generation if a baked centreline turns tighter than its own deck, which is what
## folds a ribbon inside out and makes its surface and banks shimmer.
## Fails the build if any two non-adjacent parts of the circuit come within a road's width of
## each other.
##
## This is the check the level was missing for three iterations, and it is worth being explicit
## about why a per-sample sweep missed it: every earlier probe looked for geometry standing *up*
## off the deck, or it filtered results by collider name and threw away the one thing it was
## meant to find (the snow banks live inside the road's own StaticBody3D, so a name filter hides
## them). A crossing is none of those things - both roads are perfectly well-formed, and both are
## correctly built right on top of each other. The only thing that detects it is comparing the
## centreline against itself at a distance along the lap, which is what this does.
##
## The along-track distance has to wrap. A circuit's offset 0 and its offset (length - 5) are
## five metres apart on the road and a full lap apart in the parameter; testing only
## abs(i - j) compares a point with itself across the seam and buries every real overlap under a
## flood of false positives.
func _verify_plan(curve: Curve3D, length: float, label: String) -> void:
	var step := 2.0
	var n: int = int(length / step)
	var samples := PackedVector3Array()
	samples.resize(n)
	for i in range(n):
		samples[i] = curve.sample_baked(float(i) * step)

	var min_along := 200.0    # closer than this along the track and it is the same corner
	var min_across := 26.0    # 15m carriageway + 2.1m bank + shoulder + margin
	var worst := 1e9
	var worst_a := 0
	var worst_b := 0
	var bad := 0
	for i in range(n):
		var a: Vector3 = samples[i]
		for j in range(i + 1, n):
			var raw := absi(j - i)
			# The wrap is the whole point. Offset 0 and offset (length - 5) are five metres apart on
			# the road and a full lap apart in the parameter; without this line the seam compares a
			# point with itself and reports a wall of false positives that hide the real overlaps.
			var along := mini(raw, n - raw)
			if along * step < min_along:
				continue
			var b: Vector3 = samples[j]
			var d := Vector2(a.x - b.x, a.z - b.z).length()
			if d < worst:
				worst = d
				worst_a = i * int(step)
				worst_b = j * int(step)
			if d < min_across:
				bad += 1
				if bad <= 8:
					push_error("%s crosses itself at %.0fm (%.0f, %.0f) and %.0fm (%.0f, %.0f): only %.1fm apart, needs %.0fm" % [
						label, float(i) * step, a.x, a.z, float(j) * step, b.x, b.z, d, min_across])
	if bad == 0:
		print("  %s plan clear: tightest self-approach %.1fm" % [label, worst])
	else:
		print("  %s plan has %d overlapping stretches (tightest %.1fm)" % [label, bad, worst])


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
	var at: Vector3 = curve.sample_baked(worst_at)
	if worst - half_w < 6.0:
		push_error("%s turns to R=%.1fm at %.0fm, (%.0f, %.0f) (inner edge %.1fm) - the deck folds there" % [label, worst, worst_at, at.x, at.z, worst - half_w])
	else:
		print("  %s min radius %.1fm at %.0fm, (%.0f, %.0f) (inner edge %.1fm)" % [label, worst, worst_at, at.x, at.z, worst - half_w])


## Smallest distance a route centreline keeps from the trunk centreline. A route must never
## drop inside the trunk deck, or its own deck would collapse onto the trunk surface.
func _min_route_lateral(route_curve: Curve3D) -> float:
	var worst: float = 1e9
	var steps: int = int(route_curve.get_baked_length())
	for i in range(steps + 1):
		worst = minf(worst, absf(_lateral_offset(main_track_curve, route_curve.sample_baked(float(i)))))
	return worst


## Signed lateral offset of `p` from `curve`'s centreline (positive = right of travel).
func _lateral_offset(curve: Curve3D, p: Vector3) -> float:
	return _frame_at(curve, p)["lat"]


## Closest point on `curve` to `p`, plus the lateral offset and the right vector there. The
## lateral is measured in `curve`'s own horizontal frame, which is what deck tiling needs.
func _frame_at(curve: Curve3D, p: Vector3) -> Dictionary:
	var length: float = curve.get_baked_length()
	var off: float = curve.get_closest_offset(p)
	var c: Vector3 = curve.sample_baked(off)
	var nxt: Vector3 = curve.sample_baked(minf(length, off + 1.0))
	var fwd: Vector3 = (nxt - c).normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	return {"pos": c, "fwd": fwd, "right": right, "lat": (p - c).dot(right), "off": off}


## Frame on `curve` a given distance along it, without a nearest-point search.
func _frame_at_offset(curve: Curve3D, off: float) -> Dictionary:
	var length: float = curve.get_baked_length()
	off = clampf(off, 0.0, length)
	var c: Vector3 = curve.sample_baked(off)
	var nxt: Vector3 = curve.sample_baked(minf(length, off + 1.0))
	var fwd: Vector3 = (nxt - c).normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	return {"pos": c, "fwd": fwd, "right": right, "off": off}


## Absolute lateral reach of a route deck at lateral offset `lat`, returned as
## (inner_edge, outer_edge) measured from the trunk centreline.
##
## A route starts life as a zero-width nose sitting exactly on the trunk deck edge and widens
## only as its centreline moves clear of it. The inner edge is pinned to the trunk edge while
## that happens, so a route deck can never overlap the trunk deck (z-fighting) and can never
## float free of it (a seam down the middle of the road).
func _route_deck_extents(lat: float, route_half_w: float, trunk_half_w: float) -> Vector2:
	var d: float = absf(lat)
	var w: float = route_half_w * clampf((d - trunk_half_w) / route_half_w, 0.0, 1.0)
	return Vector2(maxf(d - w, trunk_half_w), d + w)


## Bank height factor (0 = absent, 1 = full height) at `dist` metres along a curve.
## Runs terminate with a short sloped terminal just outside every gap.
func _bank_factor_at(dist: float, gaps: Array) -> float:
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
	return clampf(nearest / BANK_TERMINAL, 0.0, 1.0)


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


## Trunk-curve distance ranges where a route's deck runs alongside the trunk deck and the
## trunk bank therefore has to be open (the gore at a split or a merge nose).
##
## Derived from the route geometry itself, so the bank can never be left standing across the
## mouth of a route, and the opening is never wider than it needs to be.
func _junction_gap_intervals(route_curve: Curve3D, route_half_w: float, trunk_half_w: float) -> Array:
	var trunk_len: float = main_track_curve.get_baked_length()
	var route_len: float = route_curve.get_baked_length()
	if trunk_len <= 0.0 or route_len <= 0.0:
		return []
	var step := 1.0
	var open_spans: Array = []
	var run_start: float = -1.0
	var run_end: float = 0.0
	var samples: int = int(ceil(route_len / step))
	for i in range(samples + 1):
		var t: float = float(i) * step
		var p: Vector3 = route_curve.sample_baked(minf(t, route_len))
		var lat: float = _lateral_offset(main_track_curve, p)
		var ext: Vector2 = _route_deck_extents(lat, route_half_w, trunk_half_w)
		var alongside: bool = ext.x < trunk_half_w + GORE_CLEARANCE
		var trunk_off: float = main_track_curve.get_closest_offset(p)
		if alongside:
			run_end = trunk_off
			if run_start < 0.0:
				run_start = trunk_off
		elif run_start >= 0.0:
			open_spans.append(Vector2(run_start, run_end))
			run_start = -1.0
	if run_start >= 0.0:
		open_spans.append(Vector2(run_start, run_end))

	var padded: Array = []
	for span in open_spans:
		padded.append(Vector2(maxf(span.x - 6.0, 0.0), minf(span.y + 6.0, trunk_len)))
	return _merge_intervals(padded)


## A route leaves and rejoins the trunk, so it is *supposed* to touch it - but only at its two
## noses. Anywhere else the two decks sharing space means a crossing, which is what walls off a
## junction in a way nothing else in this file would catch.
func _verify_route_vs_trunk(route: Curve3D, label: String) -> void:
	var route_len: float = route.get_baked_length()
	var step := 2.0
	var trunk_len: float = main_track_curve.get_baked_length()
	var bad := 0
	var worst := 1e9
	var off := route_len * 0.12
	while off < route_len * 0.88:
		var p: Vector3 = route.sample_baked(off)
		var lat: float = absf(_lateral_offset(main_track_curve, p))
		var ext: Vector2 = _route_deck_extents(lat, ROUTE_HALF_W, MAIN_HALF_W)
		# The route's deck may reach the trunk edge (that is the gore) but never inside it.
		var inside: float = MAIN_HALF_W - ext.x
		if inside > 0.5:
			bad += 1
			if bad <= 6:
				push_error("%s deck reaches %.1fm inside the trunk edge at offset %.0fm" % [label, inside, off])
		if lat < worst:
			worst = lat
		off += step
	if bad == 0:
		print("  %s clears the trunk (closest approach %.1fm)" % [label, worst])
	else:
		print("  %s overlaps the trunk at %d places" % [label, bad])


## Fails the build if the trunk bank would stand across any route mouth. Cheap insurance: the
## gaps are an optional tail argument, so a call site can silently leave them empty and wall
## every alternative route off without anything else noticing.
func _verify_gaps(routes: Array, left_gaps: Array, right_gaps: Array) -> void:
	var blocked := 0
	for entry in routes:
		var rc: Curve3D = entry[0]
		var length: float = rc.get_baked_length()
		for end_i in [0, length]:
			var nose: Vector3 = rc.sample_baked(end_i)
			var off: float = main_track_curve.get_closest_offset(nose)
			var gaps: Array = right_gaps if entry[1] > 0 else left_gaps
			var f: float = _bank_factor_at(off, gaps)
			if f > 0.0:
				blocked += 1
				push_error("Trunk bank is %.0f%% up across the %s junction at offset %.0fm" % [f * 100.0, entry[2], off])
	if blocked == 0:
		print("  trunk bank open at all %d route mouths" % (routes.size() * 2))# ======================================================================================
#  Road mesh
# ======================================================================================

## Emits a flat end cap for a bank run with its own vertices, so a terminal keeps a crisp
## face instead of inheriting the smoothed normals of the bank sides.
func _emit_cap(st: SurfaceTool, first_index: int, profile: PackedVector3Array, want_normal: Vector3) -> int:
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
		st.add_index(first_index)
		st.add_index(first_index + k)
		st.add_index(first_index + k + 1)
	return first_index + order.size()


## Depth of the underside at `t` across the deck, from the dip profile. Returns 1 in the
## middle of the deck and 0 at its edges.
func _under_dip_at(t: float) -> float:
	var f: float = clampf(t, 0.0, 1.0) * float(UNDER_VERTS - 1)
	var i: int = clampi(int(f), 0, UNDER_VERTS - 2)
	var frac: float = f - float(i)
	var a: float = UNDER_DIP[i]
	var b: float = UNDER_DIP[i + 1]
	return lerpf(a, b, frac)


## Builds the road deck, the ploughed snow banks along both edges, and the ice shelf (or the
## crevasse arch) under the carriageway.
##
## Trunk (`route_side` = 0): pass the bank gap intervals in metres along the curve, normally
## produced by _junction_gap_intervals() so a bank can never be left standing across the mouth
## of a route.
##
## Alternative route: pass route_side = -1 (leaves the trunk on its left) or +1 (right)
## together with the trunk half width. The route deck is then built as a nose on the trunk deck
## edge that widens as it clears the shoulder, so trunk and route tile perfectly: no overlapping
## road surfaces, no gap down the middle, and the gore bank disappears exactly where the two
## decks meet.
##
## `arch_range` is the span over which the underside leaves the deck and becomes the ice arch
## over the crevasse; pass Vector2(-1.0, -1.0) for an ordinary slab.
func _build_road_mesh(parent: Node, curve: Curve3D, width: float, node_name: String,
		road_mat: Material, bank_mat: Material, under_mat: Material,
		route_side: int, trunk_half_w: float,
		left_gaps: Array, right_gaps: Array, arch_range: Vector2) -> void:
	var baked := curve.get_baked_points()
	if baked.size() < 2:
		return

	var half_w: float = width * 0.5
	var total_len: float = curve.get_baked_length()
	var is_route: bool = route_side != 0
	var trunk: Curve3D = main_track_curve if is_route else null

	# Which side of the trunk the route really sits on, measured off the curve itself so the
	# deck tiling follows the geometry rather than the node name.
	var side: int = signi(route_side)
	if trunk != null:
		var lat_a: float = _lateral_offset(trunk, curve.sample_baked(total_len * 0.15))
		var lat_b: float = _lateral_offset(trunk, curve.sample_baked(total_len * 0.85))
		var strongest: float = absf(lat_a) if absf(lat_a) >= absf(lat_b) else absf(lat_b)
		side = signi(lat_a if absf(lat_a) >= absf(lat_b) else lat_b)
		if side == 0:
			side = signi(route_side)

	# --- Pass 1: per-ring frames, deck extents, bank heights --------------------------
	var n_rings: int = baked.size()
	var ring_frame := PackedVector3Array()
	var ring_lat := PackedFloat32Array()
	var ring_y_bias := PackedFloat32Array()
	var deck_left := PackedFloat32Array()
	var deck_right := PackedFloat32Array()
	var bank_left := PackedFloat32Array()
	var bank_right := PackedFloat32Array()
	var ring_depth := PackedFloat32Array()
	var dist_along := PackedFloat32Array()

	# Outward 2D normals of the bank profile, averaged per vertex. Profiles are authored
	# counter-clockwise in (u, v), so the outward normal of edge P->Q is (dy, -dx).
	var prof_nrm := PackedVector2Array()
	var acc := Vector2.ZERO
	for i in range(BANK_VERTS):
		var prev: Vector2 = BANK_PROFILE[(i + BANK_VERTS - 1) % BANK_VERTS]
		var here: Vector2 = BANK_PROFILE[i]
		var nxt: Vector2 = BANK_PROFILE[(i + 1) % BANK_VERTS]
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

		if i > 0:
			cum += p.distance_to(baked[i - 1])

		var d_l: float = -half_w
		var d_r: float = half_w
		var b_l: float = 1.0
		var b_r: float = 1.0
		var frame: Vector3 = right
		var lat_here: float = 0.0
		var y_bias: float = 0.0

		if is_route and trunk != null:
			var frame_info: Dictionary = _frame_at(trunk, p)
			lat_here = frame_info["lat"]
			var trunk_right: Vector3 = frame_info["right"]
			var ext: Vector2 = _route_deck_extents(lat_here, half_w, trunk_half_w)
			# Trunk-lateral the deck edges should sit at, signed to this route's side.
			var lat_in: float = float(side) * ext.x
			var lat_out: float = float(side) * ext.y
			d_l = minf(lat_in, lat_out)
			d_r = maxf(lat_in, lat_out)
			# While the deck is still tiling against the trunk shoulder its cross-section must be
			# laid out along the *trunk's* right vector, otherwise the inner edge slides off the
			# trunk deck by half_w*cos(divergence) and the two roads part company. Once the route
			# has pulled clear, blend back to its own perpendicular so it is a normal ribbon.
			var blend: float = clampf((absf(lat_here) - (trunk_half_w + half_w)) / 25.0, 0.0, 1.0)
			frame = (trunk_right * (1.0 - blend) + right * blend)
			if frame.length_squared() < 1e-6:
				frame = right
			frame = frame.normalized()
			# While tiling, the route deck must also sit at exactly the trunk's height. The
			# route's own curve sags a few centimetres there (Catmull-Rom handle overshoot in Y),
			# and the trunk's slab edge then stands proud of the route surface as a lip.
			#
			# Deliberately tight and clamped: the correction belongs to the gore only. Tying it to
			# the 25m frame blend instead let it reach the far reaches of the route, where it is
			# metres above the trunk, and moved those decks bodily out from under their own banks.
			var seam: float = clampf((absf(lat_here) - (trunk_half_w + half_w)) / 6.0, 0.0, 1.0)
			y_bias = clampf(frame_info["pos"].y - p.y, -0.35, 0.35) * (1.0 - seam)
			# Gore-side bank only comes up once the route deck has opened the same clearance the
			# trunk bank uses to close (GORE_CLEARANCE). Tying the two together is what keeps the
			# whole junction bank-free.
			var gore_h: float = clampf((ext.x - trunk_half_w - GORE_CLEARANCE) / 3.0, 0.0, 1.0)
			var outer_w: float = ext.y - ext.x
			var outer_h: float = clampf((outer_w - 1.3) / 2.2, 0.0, 1.0)
			if side > 0:
				b_l = gore_h
				b_r = outer_h
			else:
				b_l = outer_h
				b_r = gore_h
		else:
			b_l = _bank_factor_at(cum, left_gaps)
			b_r = _bank_factor_at(cum, right_gaps)

		# Ordinary slab, or the parabola that becomes the ice arch over the crevasse.
		var depth: float = DECK_SLAB
		if arch_range.y > arch_range.x and cum > arch_range.x and cum < arch_range.y:
			var t: float = (cum - arch_range.x) / maxf(arch_range.y - arch_range.x, 0.001)
			depth += ARCH_DEPTH * 4.0 * t * (1.0 - t)

		ring_frame.append(frame)
		ring_lat.append(lat_here)
		ring_y_bias.append(y_bias)
		deck_left.append(d_l)
		deck_right.append(d_r)
		bank_left.append(b_l)
		bank_right.append(b_r)
		ring_depth.append(depth)
		dist_along.append(cum)

	# --- Pass 2: vertices -------------------------------------------------------------
	var st_road := SurfaceTool.new()
	st_road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_bank := SurfaceTool.new()
	st_bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_under := SurfaceTool.new()
	st_under.begin(Mesh.PRIMITIVE_TRIANGLES)

	var prof_left: Array = []
	var prof_right: Array = []

	for i in range(n_rings):
		var p: Vector3 = baked[i] + Vector3.UP * ring_y_bias[i]
		var fwd: Vector3 = Vector3.FORWARD
		if i < n_rings - 1:
			fwd = (baked[i + 1] - baked[i]).normalized()
		elif i > 0:
			fwd = (baked[i] - baked[i - 1]).normalized()
		var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
		var frame: Vector3 = ring_frame[i]
		var up := Vector3.UP
		# Cross-section offsets are trunk-lateral targets minus the ring's own lateral, so a
		# vertex lands exactly where the tiling wants it.
		var shift: float = -ring_lat[i]
		var d_l: float = deck_left[i]
		var d_r: float = deck_right[i]
		var uv_y: float = dist_along[i]
		var width_now: float = d_r - d_l

		# Markings: dashed ice-edge lines through every gore, solid banks elsewhere.
		var edge_l_mode: float = 1.0
		var edge_r_mode: float = 1.0
		var route_val: float = 1.0 if is_route else 0.0
		var gore_val: float = 0.0
		if is_route:
			var open_l: float = 1.0 - clampf((width_now - 2.0) / 3.0, 0.0, 1.0)
			# The gore edge is the one facing the trunk, the outboard edge is always full.
			if side > 0:
				edge_l_mode = open_l
			else:
				edge_r_mode = open_l
			gore_val = clampf(1.0 - width_now / 4.5, 0.0, 1.0) * 0.7
		else:
			edge_l_mode = 0.5 if _in_any_gap(uv_y, left_gaps) else 1.0
			edge_r_mode = 0.5 if _in_any_gap(uv_y, right_gaps) else 1.0

		# Centre crown, faded out at the route noses so the transition is flush and tangent.
		var crown: float = 0.04
		if is_route:
			crown = 0.04 * clampf(width_now / 9.0, 0.0, 1.0)

		# --- 1. ROAD DECK (5 points across: L edge, L lane, centre, R lane, R edge) ---
		for k in range(5):
			var t: float = float(k) * 0.25
			var lat: float = lerpf(d_l, d_r, t)
			var v: Vector3 = p + frame * (lat + shift)
			if k == 2:
				v += up * crown
			st_road.set_color(Color(edge_l_mode, edge_r_mode, route_val, gore_val))
			st_road.set_uv(Vector2(t, uv_y))
			st_road.add_vertex(v)

		# --- 2. SNOW BANKS (fixed profile, flat across, smooth along) ---
		# Vertices are laid out as one blocked left profile then one blocked right profile, so a
		# ring is 2 * BANK_VERTS vertices and each side is indexed as a closed prism.
		var pl := PackedVector3Array()
		var pr := PackedVector3Array()
		for k in range(BANK_VERTS):
			var prof: Vector2 = BANK_PROFILE[k]
			var n2: Vector2 = prof_nrm[k]
			# Left edge: profile u runs toward the road (+lateral). Right edge: mirrored.
			var v_l := p + frame * (d_l + shift + prof.x) + up * (prof.y * bank_left[i])
			var n_l := (right * n2.x + up * n2.y).normalized()
			st_bank.set_normal(n_l)
			st_bank.set_uv(Vector2(0.0, uv_y * 0.3))
			st_bank.add_vertex(v_l)
			pl.append(v_l)
		for k in range(BANK_VERTS):
			var prof: Vector2 = BANK_PROFILE[k]
			var n2: Vector2 = prof_nrm[k]
			var v_r := p + frame * (d_r + shift - prof.x) + up * (prof.y * bank_right[i])
			var n_r := (-right * n2.x + up * n2.y).normalized()
			st_bank.set_normal(n_r)
			st_bank.set_uv(Vector2(1.0, uv_y * 0.3))
			st_bank.add_vertex(v_r)
			pr.append(v_r)
		prof_left.append(pl)
		prof_right.append(pr)

		# --- 3. UNDERSIDE: ice shelf, deepening into the arch across the crevasse span ---
		for k in range(UNDER_VERTS):
			var t2: float = float(k) / float(UNDER_VERTS - 1)
			var lat2: float = lerpf(d_l, d_r, t2)
			var v2: Vector3 = p + frame * (lat2 + shift) - up * (ring_depth[i] * _under_dip_at(t2))
			st_under.set_uv(Vector2(t2, uv_y * 0.2))
			st_under.add_vertex(v2)

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

	# --- Pass 4: bank side quads + solid caps at every start/end ----------------------
	# Each ring is 2 * BANK_VERTS vertices: the left profile then the right profile.
	var ring_stride: int = BANK_VERTS * 2
	var cap_base: int = n_rings * ring_stride
	for i in range(n_rings - 1):
		for s in range(2): # 0 = left, 1 = right
			var base: int = i * ring_stride + BANK_VERTS * s
			var nxt_base: int = base + ring_stride
			var h0: float = bank_left[i] if s == 0 else bank_right[i]
			var h1: float = bank_left[i + 1] if s == 0 else bank_right[i + 1]
			var profiles: Array = prof_left if s == 0 else prof_right
			var fwd: Vector3 = Vector3.FORWARD
			if i < n_rings - 1:
				fwd = (baked[i + 1] - baked[i]).normalized()
			var nxt_fwd: Vector3 = fwd
			if i + 2 < n_rings:
				nxt_fwd = (baked[i + 2] - baked[i + 1]).normalized()

			if h0 > 0.06 or h1 > 0.06:
				# Right-hand profiles are mirrored, so their quads wind the other way to keep
				# every face normal pointing out of the snow.
				for c in range(BANK_VERTS):
					var a: int = base + c
					var b: int = base + ((c + 1) % BANK_VERTS)
					var c_idx: int = nxt_base + c
					var d: int = nxt_base + ((c + 1) % BANK_VERTS)
					if s == 0:
						st_bank.add_index(a); st_bank.add_index(c_idx); st_bank.add_index(b)
						st_bank.add_index(b); st_bank.add_index(c_idx); st_bank.add_index(d)
					else:
						st_bank.add_index(a); st_bank.add_index(b); st_bank.add_index(c_idx)
						st_bank.add_index(b); st_bank.add_index(d); st_bank.add_index(c_idx)

			var starts: bool = (i == 0 and h0 > 0.06) or (h0 <= 0.06 and h1 > 0.06)
			var ends: bool = (i == n_rings - 2 and h1 > 0.06) or (h0 > 0.06 and h1 <= 0.06)
			if starts:
				var ring: int = i if i == 0 else i + 1
				cap_base = _emit_cap(st_bank, cap_base, profiles[ring], -fwd if i == 0 else -nxt_fwd)
			if ends:
				var ring2: int = i + 1 if i == n_rings - 2 else i
				cap_base = _emit_cap(st_bank, cap_base, profiles[ring2], nxt_fwd if i == n_rings - 2 else fwd)

	# --- Pass 5: underside (5 quads per segment, ends capped) -------------------------
	for i in range(n_rings - 1):
		var u0: int = i * UNDER_VERTS
		var u1: int = (i + 1) * UNDER_VERTS
		for c in range(UNDER_VERTS - 1):
			var a: int = u0 + c
			var b: int = u0 + c + 1
			var c_idx: int = u1 + c
			var d: int = u1 + c + 1
			st_under.add_index(a); st_under.add_index(b); st_under.add_index(c_idx)
			st_under.add_index(b); st_under.add_index(d); st_under.add_index(c_idx)
	# Cap the two ends so the shelf is not an open hollow tube.
	for c in range(1, UNDER_VERTS - 1):
		st_under.add_index(0)
		st_under.add_index(c)
		st_under.add_index(c + 1)
		var e0: int = (n_rings - 1) * UNDER_VERTS
		st_under.add_index(e0)
		st_under.add_index(e0 + c + 1)
		st_under.add_index(e0 + c)

	# --- Pass 6: commit meshes, collision --------------------------------------------
	# Meshes and collision shapes go to res://generated/ as binary resources, the same way the
	# other levels' terrain is stored. Inlining them would put tens of megabytes of vertex data
	# into the text scene file, which is slow to save, slow to parse and unreviewable.
	st_road.generate_normals()
	st_road.generate_tangents()
	var road_mesh: ArrayMesh = _save_baked_resource(st_road.commit(), "%s_deck" % node_name)

	# Normals are authored above (crisp across the profile, smooth along the run) and
	# generate_normals() is deliberately NOT called on the banks.
	var bank_mesh: ArrayMesh = _save_baked_resource(st_bank.commit(), "%s_bank" % node_name)

	st_under.generate_normals()
	st_under.generate_tangents()
	var under_mesh: ArrayMesh = _save_baked_resource(st_under.commit(), "%s_underside" % node_name)

	var static_body := StaticBody3D.new()
	static_body.name = node_name + "_Collision"
	static_body.add_to_group("track_surface", true)

	var road_inst := MeshInstance3D.new()
	road_inst.name = node_name + "_DeckMesh"
	road_inst.mesh = road_mesh
	road_inst.material_override = road_mat
	static_body.add_child(road_inst)

	var bank_inst := MeshInstance3D.new()
	bank_inst.name = node_name + "_BankMesh"
	bank_inst.mesh = bank_mesh
	bank_inst.material_override = bank_mat
	static_body.add_child(bank_inst)

	var under_inst := MeshInstance3D.new()
	under_inst.name = node_name + "_UndersideMesh"
	under_inst.mesh = under_mesh
	under_inst.material_override = under_mat
	static_body.add_child(under_inst)

	# TriMesh collision for precise driving and bank bounces, stored alongside the visuals.
	var col_shape := CollisionShape3D.new()
	col_shape.name = "DeckCollision"
	var r_trimesh: Shape3D = road_mesh.create_trimesh_shape()
	if r_trimesh is ConcavePolygonShape3D:
		(r_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_shape.shape = _save_baked_resource(r_trimesh, "%s_deck_collision" % node_name)
	static_body.add_child(col_shape)

	var col_under := CollisionShape3D.new()
	col_under.name = "UndersideCollision"
	var u_trimesh: Shape3D = under_mesh.create_trimesh_shape()
	if u_trimesh is ConcavePolygonShape3D:
		(u_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_under.shape = _save_baked_resource(u_trimesh, "%s_underside_collision" % node_name)
	static_body.add_child(col_under)

	var col_bank := CollisionShape3D.new()
	col_bank.name = "BankCollision"
	var b_trimesh: Shape3D = bank_mesh.create_trimesh_shape()
	if b_trimesh is ConcavePolygonShape3D:
		(b_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_bank.shape = _save_baked_resource(b_trimesh, "%s_bank_collision" % node_name)
	static_body.add_child(col_bank)

	parent.add_child(static_body)


## True when `dist` metres along a curve falls inside one of the [start, end] intervals.
func _in_any_gap(dist: float, gaps: Array) -> bool:
	for gap in gaps:
		if dist >= gap.x and dist <= gap.y:
			return true
	return false


## World point `lat` metres to the side of `curve`, `off` metres along it.
##
## Props, boost pads and item boxes are all placed through this rather than by hand-writing
## coordinates: a route's own curve moves when the layout is retuned, and a hardcoded position
## is then silently in the middle of the snowbank.
func _point_on(curve: Curve3D, off: float, lat: float, y_offset: float = 0.0) -> Dictionary:
	var f: Dictionary = _frame_at_offset(curve, off)
	var p: Vector3 = f["pos"] + f["right"] * lat + Vector3.UP * y_offset
	var rot_y: float = rad_to_deg(atan2(-f["fwd"].x, -f["fwd"].z))
	return {"pos": p, "yaw": rot_y, "fwd": f["fwd"], "right": f["right"]}# ======================================================================================
#  Ice cavern
# ======================================================================================

## Builds the glacier ice cavern: the swept shell the road drives through, the columns and
## lights inside it, the light shafts hanging off the crown, and the block rings that frame
## each mouth.
##
## The shell's cross-section is a closed loop (see CAVERN_PROFILE), so the sweep leaves no open
## edge anywhere - including the floor strip that closes the gap between the deck edge and the
## wall foot. Without that strip the 3.5m gap beside the carriageway would look straight
## through the shell into the void underneath the heightfield.
func _build_cavern(parent: Node, ice_mat: Material, vein_light_mat: Color) -> void:
	var shell := StaticBody3D.new()
	shell.name = "IceCavern"
	shell.add_to_group("track_surface", true)

	var start: float = _cavern_range.x - CAVERN_OVERSHOOT
	var finish: float = _cavern_range.y + CAVERN_OVERSHOOT
	var step := 1.5
	var ring_count: int = int((finish - start) / step) + 1

	# Inward-facing normals for the closed profile: for an edge P->Q the inward normal of a
	# counter-clockwise loop in (u, v) is (dv, -du). Averaging the two adjacent edges and
	# re-normalising is what keeps the corners from being faceted.
	var prof_nrm := PackedVector2Array()
	for i in range(CAVERN_VERTS):
		var prev: Vector2 = CAVERN_PROFILE[(i - 1 + CAVERN_VERTS) % CAVERN_VERTS]
		var here: Vector2 = CAVERN_PROFILE[i]
		var nxt: Vector2 = CAVERN_PROFILE[(i + 1) % CAVERN_VERTS]
		var e_in: Vector2 = (here - prev).normalized()
		var e_out: Vector2 = (nxt - here).normalized()
		var n: Vector2 = Vector2(e_in.y, -e_in.x) + Vector2(e_out.y, -e_out.x)
		prof_nrm.append(n.normalized() if n.length_squared() > 1e-6 else Vector2(0.0, -1.0))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(ring_count):
		var off: float = start + float(r) * step
		var f: Dictionary = _frame_at_offset(main_track_curve, minf(off, main_track_curve.get_baked_length()))
		var p: Vector3 = f["pos"]
		var right: Vector3 = f["right"]
		for i in range(CAVERN_VERTS):
			var prof: Vector2 = CAVERN_PROFILE[i]
			var n2: Vector2 = prof_nrm[i]
			var v: Vector3 = p + right * prof.x + Vector3.UP * prof.y
			st.set_normal((right * n2.x + Vector3.UP * n2.y).normalized())
			st.set_uv(Vector2(prof.x * 0.05, off * 0.05))
			st.add_vertex(v)

	# Side walls: one quad strip per profile edge, wrapping the closed loop.
	for r in range(ring_count - 1):
		var r0: int = r * CAVERN_VERTS
		var r1: int = (r + 1) * CAVERN_VERTS
		for i in range(CAVERN_VERTS):
			var j: int = (i + 1) % CAVERN_VERTS
			var a: int = r0 + i
			var b: int = r0 + j
			var c_idx: int = r1 + j
			var d: int = r1 + i
			st.add_index(a); st.add_index(b); st.add_index(c_idx)
			st.add_index(a); st.add_index(c_idx); st.add_index(d)

	# Deliberately NO end caps.
	#
	# The shell's cross-section is a closed loop, which is what keeps the passage watertight from
	# the side, but the tube itself is open at both ends - and those ends are the two mouths of the
	# cavern, sitting in the open gorge either side of the glacier. Capping them (which an earlier
	# revision of this file did, on the reasoning that the shell disappears into rock) drops a
	# solid disc of ice straight across each entrance.

	var shell_mesh: ArrayMesh = _save_baked_resource(st.commit(), "cavern_shell")
	var shell_inst := MeshInstance3D.new()
	shell_inst.name = "CavernShellMesh"
	shell_inst.mesh = shell_mesh
	shell_inst.material_override = ice_mat
	shell.add_child(shell_inst)

	var shell_col := CollisionShape3D.new()
	shell_col.name = "CavernCollision"
	var shell_shape: Shape3D = shell_mesh.create_trimesh_shape()
	if shell_shape is ConcavePolygonShape3D:
		(shell_shape as ConcavePolygonShape3D).backface_collision = true
	shell_col.shape = _save_baked_resource(shell_shape, "cavern_shell_collision")
	shell.add_child(shell_col)
	parent.add_child(shell)

	# --- Interior dressing -------------------------------------------------------------
	var props := Node3D.new()
	props.name = "CavernInterior"
	parent.add_child(props)

	# No columns and no light shafts. Both were there to make the gallery read as "a cave" and
	# both made it read as something else: the columns were props against the walls, and the
	# additive shaft quads read as a flat sheet hanging off the ceiling rather than as light.
	# The shell, the vein lighting and the portal rings carry it.

	var rng := RandomNumberGenerator.new()
	rng.seed = 0x4E4C5643  # "NLVC"

	# Vein lighting, alternating sides down the gallery.
	var lights := Node3D.new()
	lights.name = "CavernVeinLights"
	props.add_child(lights)
	var off: float = start + 8.0
	var li := 0
	while off < finish:
		var f2: Dictionary = _frame_at_offset(main_track_curve, off)
		var side: float = 1.0 if (li % 2 == 0) else -1.0
		var l := OmniLight3D.new()
		l.name = "VeinLight_%d" % li
		l.position = f2["pos"] + f2["right"] * (7.5 * side) + Vector3.UP * 5.0
		l.light_color = vein_light_mat
		l.light_energy = 2.6
		l.omni_range = 34.0
		l.omni_attenuation = 1.15
		l.light_specular = 0.6
		lights.add_child(l)
		off += 26.0
		li += 1

	# Block rings around both mouths, so the arch reads as a carved opening in an ice face
	# rather than as a hole where the terrain happened to stop.
	_build_portal_ring(props, ice_mat, start, 1.0)
	_build_portal_ring(props, ice_mat, finish, -1.0)


## Half width of the cap laid over the cavern shell; its edges sink into the massif's flanks.
const CAP_HALF_W := 36.0
## Depth of snow and rock over the shell's crown.
const CAP_COVER := 6.0
## How far the cap starts behind each portal plane. The portal face leans back across this gap,
## from the arch outline to the cap, so the mouth is a sloped face rather than a sheer cut.
const CAP_FACE_SETBACK := 8.0
const CAP_LAT_SAMPLES := 29
const CAP_FACE_ROWS := 5


## Icefield height at a world point, bilinear over the heightfield that was actually built.
func _terrain_height_at(x: float, z: float) -> float:
	var stride: int = TERRAIN_RES + 1
	var gx: float = clampf((x - _terrain_origin.x) / _terrain_step, 0.0, float(TERRAIN_RES) - 0.001)
	var gz: float = clampf((z - _terrain_origin.y) / _terrain_step, 0.0, float(TERRAIN_RES) - 0.001)
	var ix: int = int(gx)
	var iz: int = int(gz)
	var fx: float = gx - float(ix)
	var fz: float = gz - float(iz)
	var h00: float = _terrain_heights[iz * stride + ix]
	var h10: float = _terrain_heights[iz * stride + ix + 1]
	var h01: float = _terrain_heights[(iz + 1) * stride + ix]
	var h11: float = _terrain_heights[(iz + 1) * stride + ix + 1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


## Height of the shell's outer surface above the deck at lateral `u`, from the upper half of
## CAVERN_PROFILE (the walls are vertical below the springing).
func _shell_top_at(u: float) -> float:
	var a: float = absf(u)
	var best: float = -INF
	for i in range(CAVERN_VERTS - 1):
		var p: Vector2 = CAVERN_PROFILE[i]
		var q: Vector2 = CAVERN_PROFILE[i + 1]
		var lo: float = minf(absf(p.x), absf(q.x))
		var hi: float = maxf(absf(p.x), absf(q.x))
		if a < lo or a > hi or hi - lo < 1e-4:
			continue
		var t: float = (a - absf(p.x)) / (absf(q.x) - absf(p.x))
		best = maxf(best, lerpf(p.y, q.y, t))
	return best


## Cross-section of the cap at one trunk offset, left to right, in world space.
func _cap_section(off: float) -> PackedVector3Array:
	var f: Dictionary = _frame_at_offset(main_track_curve, off)
	var p: Vector3 = f["pos"]
	var right: Vector3 = f["right"]
	# Near the mouths the cap is a low hood over the arch; further in it fills the saddle up toward
	# the flanks' height, so the two flanks and the cap read as one mountain, not two peaks with a
	# trench between them.
	var inward: float = minf(off - _cavern_range.x, _cavern_range.y - off)
	var edge_l: Vector3 = p - right * CAP_HALF_W
	var edge_r: Vector3 = p + right * CAP_HALF_W
	var flank: float = minf(_terrain_height_at(edge_l.x, edge_l.z), _terrain_height_at(edge_r.x, edge_r.z)) - p.y
	var hood: float = 15.4 + CAP_COVER
	var crown_base: float = maxf(hood, lerpf(hood, flank * 0.9, smoothstep(12.0, 75.0, inward)))
	var out := PackedVector3Array()
	for k in range(CAP_LAT_SAMPLES):
		var u: float = lerpf(-CAP_HALF_W, CAP_HALF_W, float(k) / float(CAP_LAT_SAMPLES - 1))
		var q: Vector3 = p + right * u
		var ground: float = _terrain_height_at(q.x, q.z) - p.y
		var t: float = absf(u) / CAP_HALF_W
		var crown: float = crown_base + _detail_noise.get_noise_2d(q.x * 0.7, q.z * 0.7) * 2.5
		var arch: float = crown * pow(maxf(1.0 - t * t, 0.0), 0.6)
		if absf(u) <= CAVERN_HALF_WIDTH:
			arch = maxf(arch, _shell_top_at(u) + 1.5)
		# Out at the edges the cap dives under the flank, so there is no seam to see between them.
		var y: float = lerpf(ground - 2.5, arch, 1.0 - smoothstep(0.6, 1.0, t))
		out.append(q + Vector3.UP * y)
	return out


## Resamples a polyline to `n` points evenly spaced along its length.
func _resample_polyline(pts: PackedVector3Array, n: int) -> PackedVector3Array:
	var cum := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		cum.append(cum[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total: float = cum[cum.size() - 1]
	var out := PackedVector3Array()
	var j := 0
	for k in range(n):
		var d: float = total * float(k) / float(n - 1)
		while j < pts.size() - 2 and cum[j + 1] < d:
			j += 1
		var seg: float = maxf(cum[j + 1] - cum[j], 1e-5)
		out.append(pts[j].lerp(pts[j + 1], clampf((d - cum[j]) / seg, 0.0, 1.0)))
	return out


## Snow and rock laid over the cavern shell, joining the massif's two flanks into one mountain,
## with a sloped portal face around each arch.
##
## The heightfield can't roof the passage (anything above the deck over the carriageway would be
## a wall), so on its own the massif is two mounds with the glass shell lying in the gap between
## them, which from outside reads as a pipe in a trench rather than a tunnel. This cap is a
## separate mesh over the shell. It casts no shadow, so the gallery is lit as before, and it's
## single-sided, so from inside the cavern you still see through the shell to the sky.
func _build_cavern_cap(parent: Node, ground_mat: Material) -> void:
	var start: float = _cavern_range.x
	var finish: float = _cavern_range.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# In an array so the lambda below shares it: GDScript lambdas capture locals by value.
	var vcount := [0]

	# Godot's front faces wind clockwise: generate_normals() gives (c - a) x (b - a), so each quad
	# is wound to make that point along `facing`.
	var add_grid := func(rows: Array, facing_of: Callable) -> void:
		var cols: int = (rows[0] as PackedVector3Array).size()
		var base: int = vcount[0]
		for row in rows:
			for v in row:
				st.set_uv(Vector2(v.x, v.z))
				st.add_vertex(v)
				vcount[0] += 1
		for r in range(rows.size() - 1):
			for c in range(cols - 1):
				var a: int = base + r * cols + c
				var b: int = a + 1
				var d: int = a + cols
				var e: int = d + 1
				var pa: Vector3 = rows[r][c]
				var pb: Vector3 = rows[r][c + 1]
				var pd: Vector3 = rows[r + 1][c]
				var facing: Vector3 = facing_of.call(pa)
				if (pd - pa).cross(pb - pa).dot(facing) > 0.0:
					st.add_index(a); st.add_index(b); st.add_index(d)
					st.add_index(b); st.add_index(e); st.add_index(d)
				else:
					st.add_index(a); st.add_index(d); st.add_index(b)
					st.add_index(b); st.add_index(d); st.add_index(e)

	# The cap proper.
	var rows: Array = []
	var off: float = start + CAP_FACE_SETBACK
	while off < finish - CAP_FACE_SETBACK:
		rows.append(_cap_section(off))
		off += 3.0
	rows.append(_cap_section(finish - CAP_FACE_SETBACK))
	add_grid.call(rows, func(_p: Vector3) -> Vector3: return Vector3.UP)

	# Portal faces: from the shell's outline at the portal plane back to the first cap section,
	# with the middle rows pushed about by noise so the face is broken rock, not a ruled surface.
	for end in [[start, start + CAP_FACE_SETBACK, -1.0], [finish, finish - CAP_FACE_SETBACK, 1.0]]:
		var f: Dictionary = _frame_at_offset(main_track_curve, end[0])
		var outline := PackedVector3Array()
		for prof in CAVERN_PROFILE:
			outline.append(f["pos"] + f["right"] * prof.x + Vector3.UP * prof.y)
		var inner: PackedVector3Array = _resample_polyline(outline, CAP_LAT_SAMPLES)
		var outer: PackedVector3Array = _cap_section(end[1])
		var outward: Vector3 = f["fwd"] * end[2]
		var face_rows: Array = []
		for r in range(CAP_FACE_ROWS):
			var t: float = float(r) / float(CAP_FACE_ROWS - 1)
			var row := PackedVector3Array()
			for k in range(CAP_LAT_SAMPLES):
				var v: Vector3 = inner[k].lerp(outer[k], t)
				var bulge: float = sin(t * PI) * (_detail_noise.get_noise_2d(v.x * 1.3 + v.y, v.z * 1.3) * 2.2 + 0.8)
				row.append(v + outward * bulge)
			face_rows.append(row)
		add_grid.call(face_rows, func(_p: Vector3) -> Vector3: return outward + Vector3.UP * 0.3)

	st.generate_normals()
	st.generate_tangents()
	var mesh: ArrayMesh = _save_baked_resource(st.commit(), "cavern_cap")
	var body := StaticBody3D.new()
	body.name = "CavernCap"
	var inst := MeshInstance3D.new()
	inst.name = "CavernCapMesh"
	inst.mesh = mesh
	inst.material_override = ground_mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(inst)
	var col := CollisionShape3D.new()
	col.name = "CavernCapCollision"
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	col.shape = _save_baked_resource(shape, "cavern_cap_collision")
	body.add_child(col)
	parent.add_child(body)


## A ring of tilted ice slabs standing against the cliff face around a cavern mouth, plus the
## two lights that make the opening legible from a distance.
##
## Two things this got wrong first time, both of which are only visible from a driver's seat:
##
##  - The blocks were positioned at `profile.y * 0.45 - 1.4`, which ignores the block's own
##    half-height. A 6m slab at that formula floats two metres in the air, and the crown points
##    put them at head height over the middle of the road. Every block is now placed by its BASE,
##    sunk into the ground.
##  - The ring used the full shell profile, crown included. The crown sits at lateral 0, i.e.
##    directly over the carriageway, so those blocks were the ones ending up in the road. Only the
##    lower shoulders - below the springing - carry blocks at all.
func _build_portal_ring(parent: Node, ice_mat: Material, off: float, dir: float) -> void:
	var length: float = main_track_curve.get_baked_length()
	off = clampf(off, 0.0, length)
	var f: Dictionary = _frame_at_offset(main_track_curve, off)

	var ring := Node3D.new()
	ring.name = "PortalRing_%d" % int(off)
	ring.position = f["pos"]
	var yaw: float = rad_to_deg(atan2(-f["fwd"].x, -f["fwd"].z))
	ring.rotation_degrees = Vector3(0.0, yaw, 0.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = 0x504F5254 + int(off)
	var lib: Array = _serac_library()

	var spring_y: float = 0.0
	for prof in CAVERN_PROFILE:
		spring_y = maxf(spring_y, prof.y)

	for i in range(CAVERN_VERTS):
		var prof: Vector2 = CAVERN_PROFILE[i]
		# Below the springing only: above it there is no ground to stand a block on, and the
		# crown points sit over the carriageway.
		if prof.y > spring_y - 6.0 or prof.y < -1.0:
			continue
		var side: float = signf(prof.x)
		if side == 0.0:
			continue
		for k in range(2):
			var pick: int = rng.randi_range(0, lib.size() - 2)
			var w: float = rng.randf_range(2.6, 5.0)
			var h: float = rng.randf_range(2.0, 5.0)
			# Outboard of the shell wall, stepped back along the road so the pair frames the
			# mouth rather than blocking it.
			var along_off: float = dir * (2.0 + float(k) * 4.5 + rng.randf_range(-1.0, 1.0))
			var lateral: float = side * (absf(prof.x) + 2.6 + rng.randf_range(0.0, 2.0))
			var mi := MeshInstance3D.new()
			mi.name = "PortalBlock_%d_%d" % [i, k]
			mi.mesh = lib[pick]["mesh"]
			mi.material_override = ice_mat
			mi.scale = Vector3(w, h, w * rng.randf_range(0.7, 1.2))
			# Placed by its BASE: the block mesh is centred on its own origin, so the origin sits
			# half a block above the ground unless that is added back.
			mi.position = Vector3(lateral, h * 0.5 - 1.6, along_off)
			mi.rotation_degrees = Vector3(
				rng.randf_range(-10.0, 10.0), rng.randf_range(-30.0, 30.0), -side * rng.randf_range(8.0, 26.0))
			ring.add_child(mi)
			var cs := CollisionShape3D.new()
			cs.name = "PortalBlockCollision"
			cs.shape = lib[pick]["shape"]
			cs.position = mi.position
			cs.scale = mi.scale
			cs.rotation_degrees = mi.rotation_degrees
			ring.add_child(cs)

	# One light per shoulder, at the springing, aimed into the mouth.
	for side2 in [-1.0, 1.0]:
		var l := OmniLight3D.new()
		l.name = "PortalLight_%s" % ("L" if side2 < 0.0 else "R")
		l.position = Vector3(side2 * (CAVERN_HALF_WIDTH + 1.0), spring_y * 0.55, dir * 3.0)
		l.light_color = Color(0.66, 0.86, 1.0)
		l.light_energy = 2.6
		l.omni_range = 32.0
		l.omni_attenuation = 1.25
		ring.add_child(l)

	parent.add_child(ring)


## True inside the stretch of glacier the cavern is cut through.
##
## A heightfield has no holes. That is the whole constraint on this stage: the terrain cannot be a
## mountain AND a tunnel at the same time, because anything above the road deck over the carriageway
## is a wall the car drives into. So the massif is solid only *beside* the passage, and a narrow
## corridor is cut through it for the road. The roof is the swept shell, seated in that slot - which
## is exactly how a real glacier tunnel works.
func _inside_cavern_mass(px: float, pz: float) -> bool:
	if _cavern_line.size() < 2:
		return false
	var near: Vector2 = _cavern_nearest(px, pz)
	if near.x > CAVERN_MASS_HALF_W + CAVERN_MASS_FEATHER:
		return false
	return near.y > _cavern_range.x and near.y < _cavern_range.y


func _road_cell_key(cx: int, cz: int) -> int:
	# Bias the cell index so neighbouring cells cannot collide.
	return (cx + 32768) * 65536 + (cz + 32768)


func _build_road_index() -> void:
	_road_xz = PackedVector2Array()
	_road_y = PackedFloat32Array()
	_road_off = PackedFloat32Array()
	_road_ci = PackedInt32Array()
	_road_cells.clear()
	for ci in range(ROAD_CURVES.size()):
		var rc: Curve3D = ROAD_CURVES[ci]
		var length: float = rc.get_baked_length()
		var steps: int = int(length / 2.0)
		for i in range(steps + 1):
			var off: float = minf(float(i) * 2.0, length)
			var p: Vector3 = rc.sample_baked(off)
			var idx: int = _road_xz.size()
			_road_xz.append(Vector2(p.x, p.z))
			_road_y.append(p.y)
			_road_off.append(off)
			_road_ci.append(ci)
			var key: int = _road_cell_key(int(floor(p.x / ROAD_CELL)), int(floor(p.z / ROAD_CELL)))
			var bucket: PackedInt32Array = _road_cells.get(key, PackedInt32Array())
			bucket.append(idx)
			_road_cells[key] = bucket
	print("  road index: %d samples in %d cells" % [_road_xz.size(), _road_cells.size()])


## True where the terrain must be left alone: solid rock over the cavern, open sky under the
## crevasse bridge, and bare lake ice under the scraped start straight.


## True where the terrain must be left alone: the crevasse span (open sky underneath the arch)
## and the frozen lake (the road is scraped into the ice, not built on it).
func _grade_blocked(curve_index: int, off: float) -> bool:
	var spans: Array = _no_grade.get(curve_index, [])
	for sp in spans:
		if off >= sp.x and off <= sp.y:
			return true
	return false


## How far the corridor has cut down at lateral distance `d` from the carriageway centre.
##
## Inside the glacier this is a floor cut and nothing else: 1 (fully cut to road level) across the
## carriageway and its banks, falling to 0 by GLACIER_GALLERY_HALF_W. It never climbs, so the wall
## beside the tunnel is left entirely to the massif's own profile.
func _gallery_wall_blend(d: float) -> float:
	var t: float = clampf((d - GLACIER_GALLERY_FLAT_W) / maxf(GLACIER_GALLERY_HALF_W - GLACIER_GALLERY_FLAT_W, 0.001), 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)


func _apply_road_corridors(h: float, px: float, pz: float) -> float:
	var cx: int = int(floor(px / ROAD_CELL))
	var cz: int = int(floor(pz / ROAD_CELL))
	var in_glacier: bool = _inside_cavern_mass(px, pz)
	var reach: float = GLACIER_GALLERY_HALF_W if in_glacier else ROAD_CORRIDOR_RADIUS
	var flat: float = GLACIER_GALLERY_FLAT_W if in_glacier else 13.0
	var shelf: float = h
	var weight: float = -1.0
	var ceiling: float = 1e9
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			var bucket: PackedInt32Array = _road_cells.get(_road_cell_key(gx, gz), PackedInt32Array())
			for s in bucket:
				if _grade_blocked(_road_ci[s], _road_off[s]):
					continue
				# Only the trunk's own corridor cuts the gallery. A route running past the mouth
				# inside a corridor radius of it would otherwise plane the cliff the mouth is in.
				if in_glacier and _road_ci[s] != 0:
					continue
				var dx: float = px - _road_xz[s].x
				var dz: float = pz - _road_xz[s].y
				var d2: float = dx * dx + dz * dz
				if d2 > reach * reach:
					continue
				var d: float = sqrt(d2)
				var road_y: float = _road_y[s]
				var s_shelf: float = road_y - 0.12 - DECK_SLAB
				if road_y - h > 4.5:
					# Genuine bridge span: only guarantee the deck is not buried, never fill.
					if d < 14.0:
						ceiling = minf(ceiling, s_shelf)
					continue
				var t: float = _gallery_wall_blend(d) if in_glacier else 1.0 - smoothstep(flat, reach, d)
				if not in_glacier:
					t = t * t * (3.0 - 2.0 * t)
				if t > 0.0 and (t > weight or (is_equal_approx(t, weight) and s_shelf < shelf)):
					weight = t
					shelf = s_shelf
	if weight > 0.0:
		h = lerpf(h, shelf, weight)
	return minf(h, ceiling)


## Plan-view position relative to the crevasse: x is the signed position along the slot in
## units of its half length, y is the perpendicular distance in units of its half width.
func _crevasse_slot(px: float, pz: float) -> Vector2:
	var d := Vector2(px - CREVASSE_CENTER.x, pz - CREVASSE_CENTER.y)
	var along: float = d.dot(CREVASSE_DIR) / CREVASSE_HALF_LEN
	var perp_v: Vector2 = d - CREVASSE_DIR * d.dot(CREVASSE_DIR)
	return Vector2(along, perp_v.length() / CREVASSE_HALF_W)


## Cuts the crevasse the ice arch bridges: a slot that tapers to nothing at both tips, so it
## never ends on a flat wall. The rim is raised only well outside the corridor radius - any
## closer and it would push terrain up through the deck at the abutments.
func _apply_crevasse(h: float, px: float, pz: float) -> float:
	var slot: Vector2 = _crevasse_slot(px, pz)
	# Outside the footprint entirely. This has to be an OR, not an AND: the slot's footprint is a
	# rectangle in (along, across) space, and testing both conditions with AND lets the rim escape
	# sideways forever along the strip where |along| < 1 - which is the entire plane that happens
	# to project near the slot's axis, 500m from the slot and 4.5m higher than it should be.
	if absf(slot.x) >= 1.0 or slot.y >= 3.4:
		return h
	var taper: float = 1.0 - smoothstep(0.45, 1.0, absf(slot.x))
	if taper <= 0.0:
		return h
	h += 4.5 * taper * smoothstep(2.2, 3.4, slot.y)
	var across: float = 1.0 - smoothstep(0.30, 1.0, slot.y)
	if across <= 0.0:
		return h
	across = across * across * (3.0 - 2.0 * across)
	return h - CREVASSE_DEPTH * taper * pow(across, 0.75)


## Nearest point on the cavern centreline, extrapolating past both ends. Returns
## (distance, trunk offset).
func _cavern_nearest(px: float, pz: float) -> Vector2:
	var n: int = _cavern_line.size()
	if n < 2:
		return Vector2(1e9, 0.0)
	var p := Vector2(px, pz)
	var best_d := 1e9
	var best_off := 0.0
	for i in range(n - 1):
		var a: Vector2 = _cavern_line[i]
		var b: Vector2 = _cavern_line[i + 1]
		var ab: Vector2 = b - a
		var len2: float = ab.length_squared()
		var t: float = 0.0 if len2 < 1e-6 else (p - a).dot(ab) / len2
		var q: Vector2 = a + ab * clampf(t, 0.0, 1.0)
		var d: float = p.distance_to(q)
		if d < best_d:
			best_d = d
			# The *unclamped* t is the point. It extrapolates past both ends of the line, so a
			# terrain vertex north of the cavern reports a trunk offset north of the north portal
			# instead of saturating at the last sample. Without that, the ridge's along-strip holds
			# its final value for everything beyond the end, the whole northern approach ends up
			# as high as the portal, and the mouth is buried in a hillside.
			best_off = lerpf(_cavern_off[i], _cavern_off[i + 1], t)
	return Vector2(best_d, best_off)


## Height of the massif the cavern is bored through, above the surrounding icefield.
##
## A cave mouth is a notch in a face, and the massif exists to be that face. Two things this must
## not be, both of which it was:
##
##  - A smooth dome. It reads as a lump of dough however tall it is.
##  - A set of hard creases. Ridged noise plus a steep falloff produced 86-degree facets on a
##    6.25m grid - which is what the chevrons in the sky above it were. A 6.25m grid cannot carry
##    a sharp ridge, so the shaping has to be smooth *in the height function* and get its
##    character from the ground shader's relief instead.
##
## So the profile is a single smooth dome per flank, the ribbing is a gentle undulation whose
## gradient is bounded, and nothing here is allowed to exceed a slope the grid can represent.
func _cavern_mass(px: float, pz: float) -> float:
	if _cavern_line.size() < 2:
		return 0.0
	# The massif is measured off the cavern's own axis (due north along X = 0, between the portal
	# planes), not off the nearest point of the trunk. The trunk bends away right outside both
	# mouths, and beside the end faces the nearest segment flipped between the straight and the
	# bend, so the distance-along jumped and the end faces came out as a row of 10m sawteeth.
	var lat: float = absf(px)
	var z_s: float = maxf(_cavern_portal_z.x, _cavern_portal_z.y)
	var z_n: float = minf(_cavern_portal_z.x, _cavern_portal_z.y)
	var inward: float = minf(z_s - pz, pz - z_n)
	# Zero at the portal plane and steep beside the mouth, so the arch is an opening in a face.
	# Further out the ramp lengthens, so the massif's ends round off into the icefield instead
	# of standing as a straight cliff the full width of the mountain; the jitter keeps that edge
	# from being a ruled line.
	var ramp: float = 28.0 + 0.55 * maxf(lat - 18.0, 0.0)
	var ragged: float = _detail_noise.get_noise_2d(px * 0.9, pz * 0.9) * 5.0 * smoothstep(20.0, 45.0, lat)
	var along: float = smoothstep(2.0 + maxf(ragged, 0.0), 2.0 + ramp + ragged, inward)
	if along <= 0.0:
		return 0.0

	# A plain dome rather than a flat-topped plateau. The shoulders roll off over the feather,
	# which is what stops the whole massif reading as a wall with a lid.
	var perp: float = 1.0 - smoothstep(CAVERN_MASS_HALF_W, CAVERN_MASS_HALF_W + CAVERN_MASS_FEATHER, lat)
	var dome: float = perp * perp * (3.0 - 2.0 * perp)

	var rocky: float = clampf(_ridge_noise.get_noise_2d(px * 0.35, pz * 0.35) * 0.5 + 0.5, 0.0, 1.0)
	var crest: float = CAVERN_RIDGE_HEIGHT * (0.86 + 0.28 * rocky)
	# A summit partway along the span, so the ridge has a peak instead of a constant height.
	var peak: float = 1.0 - clampf(absf(pz - (z_s + z_n) * 0.5) / maxf((z_s - z_n) * 0.55, 1.0), 0.0, 1.0)
	crest += CAVERN_SUMMIT * peak * peak * (0.75 + 0.35 * rocky)

	# Zero at the gallery edge, full height across the inner flank. A single smoothstep over
	# 15-48m: at 29m lateral (where the audit probes the wall) it is already a third of the way
	# up, and the gradient over the whole span stays near 2.0, which the 6.25m grid carries as a
	# steep but coherent face.
	#
	# Two ways this was broken before: squeezing the full 70m rise into the corridor's own 15m
	# reach (85-degree facets, the chevrons), and the opposite - spreading it over 15-70m with a
	# double smoothing, which left the wall at 8% height where it is measured and reported the
	# mountain as absent while standing in front of it.
	var rise: float = smoothstep(GLACIER_GALLERY_HALF_W, CAVERN_MASS_HALF_W, lat)
	var massif: float = crest * along * dome * rise

	# Ribbing, as a bounded undulation rather than a crease. The previous form used
	# 1 - |2n - 1|, which folds a sharp valley along every zero crossing of the noise, and sampled
	# it at 2.6:0.35 - a 7:1 stretch, so all those valleys ran parallel and converged with the
	# dome's radial falloff into the chevrons. Squaring the raw noise gives soft crests instead,
	# and matching the two axes' frequency stops them lining up with the dome at all.
	var rib: float = _sastrugi_noise.get_noise_2d(px * 0.55, pz * 0.55)
	massif += rib * CAVERN_RIDGE_HEIGHT * 0.09 * along * perp * rise

	# Apron tying the base into the icefield over a much longer span than the ridge itself. It has
	# to be *ramped in* away from the mouths: the first version used a fade that evaluated to
	# zero at the portal, so its inverse put the apron at full height exactly on the mouth and
	# walled the entrance in.
	var clear_of_mouths: float = smoothstep(4.0, 90.0, inward)
	var apron: float = CAVERN_APRON * clear_of_mouths * rise * (1.0 - smoothstep(150.0, 340.0, lat))
	return maxf(massif, 0.0) + apron


## Natural polar ground: a wind-worked icefield, a dead-flat frozen lake on the start straight,
## the glacier mass over the cavern, and ridged ranges closing in beyond the valley shoulder.
func _icefield_height(px: float, pz: float) -> float:
	# The lake mask is needed first so the ground *approaching* the shore can be calmed as well.
	# Snow noise that survives right up to the water's edge is what turns a shoreline into a 2m
	# ice cliff instead of a beach of drifted ice.
	var lp: Vector2 = (Vector2(px, pz) - LAKE_CENTER) / LAKE_RADIUS
	var lake: float = 1.0 - smoothstep(1.0, 1.0 + LAKE_FEATHER / LAKE_RADIUS.x, lp.length())
	var calm: float = 1.0 - 0.78 * lake

	var h: float = 2.30
	h += _base_noise.get_noise_2d(px, pz) * 3.1 * calm
	h += _detail_noise.get_noise_2d(px, pz) * 2.1 * calm
	# Sastrugi: wind-carved ridges stretched along the prevailing valley direction.
	h += _sastrugi_noise.get_noise_2d(px * 3.1, pz * 0.5) * 0.85 * calm
	h += _ridge_noise.get_noise_2d(px * 4.2, pz * 4.2) * 0.40 * calm

	# Frozen lake. The plate is flat, with only the faintest ripple: a frozen lake that follows
	# the snow noise reads as a drift, not as ice.
	if lake > 0.0:
		h = lerpf(h, LAKE_SURFACE_Y + _sastrugi_noise.get_noise_2d(px * 2.2, pz * 0.9) * 0.14, lake)

	h += _cavern_mass(px, pz) * (1.0 - lake)

	# Ranges. Suppressed over the lake, so the icefield there really is flat, and held off the
	# circuit itself so the road never climbs into a cliff.
	var axis_x: float = 60.0 + sin(pz * 0.0040) * 55.0
	var flank: float = smoothstep(140.0, 400.0, absf(px - axis_x))
	var north: float = smoothstep(400.0, 700.0, -(pz + 20.0))
	var south: float = smoothstep(440.0, 720.0, pz + 20.0)
	var mask: float = maxf(maxf(flank, north), south) * (1.0 - lake)
	var ridge: float = clampf(_ridge_noise.get_noise_2d(px, pz) * 0.5 + 0.5, 0.0, 1.0)
	h += mask * 16.0 + pow(mask, 2.2) * 130.0 + mask * 40.0 * ridge

	# The heightfield has to end somewhere, so the last stretch before the footprint edge climbs
	# hard enough to close the horizon. Without it the flat cut edge of the mesh is visible from
	# any elevated camera as a straight line against the sky.
	var edge_r: float = maxf(absf(px - TERRAIN_CENTER.x), absf(pz - TERRAIN_CENTER.y)) / (TERRAIN_SIZE * 0.5)
	h += smoothstep(0.84, 1.0, edge_r) * 95.0
	return h


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


## Builds the icefield: one heightfield carrying the snow, the lake, the glacier, the crevasse
## and the graded corridors under every road.
##
## The big mesh is written to res://generated/ like the other levels' terrain, which keeps this
## .tscn small.
func _build_icefield(parent: Node, ground_mat: Material) -> void:
	var res: int = TERRAIN_RES
	var step_x: float = TERRAIN_SIZE / float(res)
	var step_z: float = TERRAIN_SIZE / float(res)
	var start_x: float = TERRAIN_CENTER.x - TERRAIN_SIZE * 0.5
	var start_z: float = TERRAIN_CENTER.y - TERRAIN_SIZE * 0.5
	var stride: int = res + 1

	# Coarse mask so the expensive per-vertex road queries only run near a carriageway.
	var mask_res: int = 96
	var mask := PackedByteArray()
	mask.resize(mask_res * mask_res)
	var cell_x: float = TERRAIN_SIZE / float(mask_res)
	var cell_z: float = TERRAIN_SIZE / float(mask_res)
	for road in ROAD_CURVES:
		var rc: Curve3D = road
		var rlen: float = rc.get_baked_length()
		var steps: int = int(rlen / 6.0)
		for i in range(steps + 1):
			var p: Vector3 = rc.sample_baked(float(i) * 6.0)
			var cx: int = int((p.x - start_x) / cell_x)
			var cz: int = int((p.z - start_z) / cell_z)
			var rad_x: int = int(ceil(58.0 / cell_x))
			var rad_z: int = int(ceil(58.0 / cell_z))
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
			var h: float = _icefield_height(px, pz)
			h = _apply_crevasse(h, px, pz)
			var mx: int = clampi(int((px - start_x) / cell_x), 0, mask_res - 1)
			if mask[mz * mask_res + mx] == 1:
				h = _apply_road_corridors(h, px, pz)
			heights[idx] = h

	_audit_cavern(heights, stride, res, start_x, start_z, step_x, step_z)
	_terrain_heights = heights
	_terrain_origin = Vector2(start_x, start_z)
	_terrain_step = step_x

	var mesh := _build_heightfield_mesh(heights, stride, res, start_x, start_z, step_x, step_z)
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true

	var body := StaticBody3D.new()
	body.name = "Icefield"
	body.add_to_group("track_surface", true)
	var inst := MeshInstance3D.new()
	inst.name = "IcefieldMesh"
	inst.mesh = _save_baked_resource(mesh, "icefield_visual")
	inst.material_override = ground_mat
	inst.lod_bias = 8.0
	body.add_child(inst)
	var col := CollisionShape3D.new()
	col.name = "IcefieldCollision"
	col.shape = _save_baked_resource(shape, "icefield_collision_shape")
	body.add_child(col)
	parent.add_child(body)


## Audits the cavern straight off the heightfield that was actually built.
##
## The cavern is a gallery cut through a massif, roofed by the swept shell rather than by
## terrain - a heightfield cannot have a hole in it. So what has to be true is:
##
##  - The gallery is clear. Inside the shell's width, the terrain must stay at or below road
##    level. Anything above the deck there is a wall the car drives into, and that is exactly the
##    bug that walled this entrance in twice.
##  - The walls are there. Just outside the gallery's cut there must be solid mass rising well
##    above the crown, or the shell is a hoop standing on a snowfield.
##  - Both mouths are notched into that mass rather than opening onto a plain.
##
## Note there is deliberately no check for rock overhead. That was one of the two bad audits
## here: it measured "is there terrain above the passage" and reported PASS on a tunnel whose
## entrance was a solid 45m wall, because it never measured whether anything could get in.
func _audit_cavern(heights: PackedFloat32Array, stride: int, res: int,
		start_x: float, start_z: float, step_x: float, step_z: float) -> void:
	var z_south: float = maxf(_cavern_portal_z.x, _cavern_portal_z.y)
	var z_north: float = minf(_cavern_portal_z.x, _cavern_portal_z.y)
	if _cavern_ys.size() < 2:
		push_error("Cavern range is empty - cannot audit the cavern")
		return

	var crown: float = CAVERN_PROFILE[5].y
	var mouth_margin := 14.0
	# The massif ramps up over 30m from each portal, so the wall has to be measured well inside
	# that. Probing 14m in measured the ramp, not the mountain, and reported the walls as absent
	# while 80m of ice was standing right there.
	var wall_margin := 46.0

	# Worst thing standing in the driving space, worst wall beside the gallery, cliffs at the
	# mouths. Each starts at a sentinel and "never updated" has to be distinguishable from
	# "measured fine", or the check passes without having looked at anything.
	var obstruction: float = -1e9
	var obstruction_at := Vector2.ZERO
	var wall_min: float = 1e9
	var wall_at := Vector2.ZERO
	var gallery_cells := 0
	var wall_cells := 0
	var ramp_best: float = -1e9
	var south_best: float = -1e9
	var north_best: float = -1e9

	for gz in range(res + 1):
		var pz: float = start_z + float(gz) * step_z
		var band: int = 0
		if pz <= z_south - wall_margin and pz >= z_north + wall_margin:
			band = 1
		elif pz <= z_south - mouth_margin and pz >= z_north + mouth_margin:
			band = 4   # the mouth-adjacent apron, where the massif is still rising
		elif pz <= z_south + step_z * 1.5 and pz > z_south - mouth_margin * 2.0:
			band = 2
		elif pz < z_north - step_z * 1.5 and pz >= z_north + mouth_margin * 2.0:
			band = 3
		if band == 0:
			continue
		for gx in range(res + 1):
			var px: float = start_x + float(gx) * step_x
			var lat: float = absf(px)
			if lat > CAVERN_MASS_HALF_W + 10.0:
				continue
			var h: float = heights[gz * stride + gx]
			var above: float = h - _cavern_deck_at_z(pz)

			if band == 1 and lat <= CAVERN_HALF_WIDTH:
				gallery_cells += 1
				if above > obstruction:
					obstruction = above
					obstruction_at = Vector2(px, pz)
			elif band == 4:
				# Inside the ramp but outside the mouth: the ground here should be climbing, and
				# if it is still at road level this far in the mouth reads as a cutting, not a
				# portal. Reported, not fatal - it is a shape judgement, not a collision.
				if above > ramp_best:
					ramp_best = above
			elif band == 1 and lat >= WALL_PROBE_LAT:
				wall_cells += 1
				# The LOWEST wall point along the passage: that is what decides whether the shell is
				# set into a mountain or standing on the snow.
				#
				# Measured at a lateral distance clear of the gallery's own falloff. Inside it the
				# corridor grading is deliberately pulling terrain down toward road level, so a
				# sample taken at 16m lateral reads the cut and not the mountain - which is how the
				# first attempt reported the walls as absent while the massif was standing there.
				if above < wall_min:
					wall_min = above
					wall_at = Vector2(px, pz)
			else:
				if band == 2 and above > south_best:
					south_best = above
				elif band == 3 and above > north_best:
					north_best = above

	if gallery_cells == 0:
		push_error("The cavern audit examined no gallery cells - the check passed without looking at anything")
	elif obstruction <= 0.3:
		print("  cavern gallery clear: nothing rises more than %.1fm above the road across %d cells under the shell" % [
			obstruction, gallery_cells])
	else:
		push_error("Terrain stands %.1fm above the road inside the cavern at (%.0f, %.0f) - the entrance is walled in and the car cannot get through" % [
			obstruction, obstruction_at.x, obstruction_at.y])

	if ramp_best > 6.0:
		print("  massif reaches %.1fm within the apron beyond each mouth" % ramp_best)
	else:
		push_error("The ground barely rises beyond the cavern mouths (%.1fm) - the entrances read as cuttings in a plain rather than as portals in a mountain" % ramp_best)

	if wall_cells == 0:
		push_error("The cavern audit examined no wall cells beside the gallery")
	elif wall_min >= crown:
		print("  cavern walls: lowest solid mass beside the gallery is %.1fm above the road, clearing the %.1fm shell crown by %.1fm" % [
			wall_min, crown, wall_min - crown])
	else:
		push_error("The ice beside the cavern is only %.1fm above the road at (%.0f, %.0f) - below the %.1fm shell crown, so the tunnel stands in the open rather than in a mountain" % [
			wall_min, wall_at.x, wall_at.y, crown])

	for entry in [[south_best, "south"], [north_best, "north"]]:
		var best: float = entry[0]
		var label: String = entry[1]
		if best <= 1e8:
			continue
		if best >= 12.0:
			print("  %s mouth is notched into a %.1fm face" % [label, best])
		else:
			push_error("The %s cavern mouth is not in a face - the ice beside it is only %.1fm above the road, so the tunnel opens onto a plain" % [
				label, best])


## Road height at a world Z on the cavern stretch. The stretch runs due north along X = 0, so the
## cached (z, y) profile can be searched directly - no nearest-point query needed.
func _cavern_deck_at_z(pz: float) -> float:
	var n: int = _cavern_zs.size()
	if n < 2:
		return 0.0
	for i in range(n - 1):
		var z0: float = _cavern_zs[i]
		var z1: float = _cavern_zs[i + 1]
		var lo_z: float = minf(z0, z1)
		var hi_z: float = maxf(z0, z1)
		if pz >= lo_z and pz <= hi_z:
			var t: float = 0.0 if is_equal_approx(z0, z1) else (pz - z0) / (z1 - z0)
			return lerpf(_cavern_ys[i], _cavern_ys[i + 1], t)
	return _cavern_ys[0] if pz > _cavern_zs[0] else _cavern_ys[n - 1]


func _corridor_distances(px: float, pz: float) -> Vector2:
	var best := 1e9
	var cx: int = int(floor(px / ROAD_CELL))
	var cz: int = int(floor(pz / ROAD_CELL))
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			var bucket: PackedInt32Array = _road_cells.get(_road_cell_key(gx, gz), PackedInt32Array())
			for s in bucket:
				var d: float = Vector2(px - _road_xz[s].x, pz - _road_xz[s].y).length()
				if d < best:
					best = d
	var cave := 1e9
	if _cavern_line.size() > 0:
		cave = _cavern_nearest(px, pz).x
	return Vector2(best, cave)


## Builds one irregular ice block for the serac field and the floes.
##
## A serac is a fractured slab of glacier ice: it tapers towards the top, it leans, and its faces
## are flat fractures meeting at odd angles. Scaling a BoxMesh gives you a box, and a hundred
## identically sized boxes scattered over a snowfield read as a hundred identically sized boxes -
## they look like scenery props, not like ice. So the shapes are generated once, from a jittered
## prism whose top closes on a tilted plane (a fracture face, not a lid), and the scatter instances
## those. The jitter is per-ring as well as per-side, so the facets do not line up vertically
## either.
func _make_ice_block_mesh(rng: RandomNumberGenerator, sides: int, taper: float, lean: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_t := [0.0, 0.30, 0.68, 1.0]
	var rings: Array = []
	for ti in ring_t:
		var t: float = ti
		var r: float = lerpf(1.0, taper, t)
		var pts := PackedVector3Array()
		for i in range(sides):
			var a: float = TAU * float(i) / float(sides)
			var jr: float = r * rng.randf_range(0.80, 1.20)
			var ang: float = a + rng.randf_range(-0.10, 0.10)
			pts.append(Vector3(cos(ang) * jr, t + rng.randf_range(-0.05, 0.05), sin(ang) * jr))
		rings.append(pts)
	# Lean: shear the whole block sideways with height, the way a calved slab tips.
	for ti2 in range(rings.size()):
		var pts2: PackedVector3Array = rings[ti2]
		var tilted := PackedVector3Array()
		for v in pts2:
			tilted.append(Vector3(v.x + v.y * lean, v.y, v.z + v.y * lean * 0.35))
		rings[ti2] = tilted

	# Recentre on the origin before emitting. The rings run y = 0..1, i.e. the mesh stands ON its
	# own origin rather than being centred on it - so a caller placing an instance at
	# "ground + half the height" leaves a block hanging by 0.46 * its height in the air, which is
	# most of a 20m serac. Everything downstream then has to know the offset, so fix it here.
	for pts3 in rings:
		for v in pts3:
			st.set_uv(Vector2(v.x * 0.5 + 0.5, v.y))
			st.add_vertex(Vector3(v.x, v.y - 0.5, v.z))

	# Side quads, split along the a-c diagonal.
	#
	# The second triangle has to be (d, c, a), not (b, c, d): the two have to share the DIAGONAL
	# edge a-c. Sharing b-c instead - which is a perimeter edge of the quad - folds the pair back
	# on itself and leaves the quad's other diagonal open, so every band of every block ends up
	# with a 1-edge gap down it. That reads as holes straight through the ice.
	for r in range(rings.size() - 1):
		for i in range(sides):
			var j: int = (i + 1) % sides
			var a: int = r * sides + i
			var b: int = r * sides + j
			var c: int = (r + 1) * sides + j
			var d: int = (r + 1) * sides + i
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(d); st.add_index(c); st.add_index(a)

	# Fracture face on top, fanned from a centre pushed off to one side.
	var top_row: int = (rings.size() - 1) * sides
	var centre := Vector3(rng.randf_range(-0.30, 0.30) + lean, 0.54, rng.randf_range(-0.30, 0.30) + lean * 0.35)
	var centre_idx: int = rings.size() * sides
	st.set_uv(Vector2(0.5, 1.0))
	st.add_vertex(centre)
	for i in range(sides):
		var j2: int = (i + 1) % sides
		st.add_index(centre_idx)
		st.add_index(top_row + j2)
		st.add_index(top_row + i)
	# Flat base.
	var base_idx: int = centre_idx + 1
	st.set_uv(Vector2(0.5, 0.0))
	st.add_vertex(Vector3(0.0, -0.54, 0.0))
	for i in range(sides):
		var j3: int = (i + 1) % sides
		st.add_index(base_idx)
		st.add_index(i)
		st.add_index(j3)

	st.generate_normals()
	return st.commit()


## Cached copy of the block library, so the serac field, the portal rings and the arch footings
## all instance the same seven meshes instead of each building its own.
var _serac_lib: Array = []


func _serac_library() -> Array:
	if _serac_lib.is_empty():
		_serac_lib = _build_serac_library()
	return _serac_lib


## Lowest ground under a block of half-width `foot`, rotated by `yaw`, i.e. the height it has to
## be sunk to before any corner is left hanging.
##
## Sampling the centre is not enough on a slope, and the serac field deliberately ends up on the
## massif flanks, which is where the slope is steepest. The rotation matters too: the instances are
## yawed, so an axis-aligned corner sample can still miss the corner that is actually in the air.
func _ground_under_rotated(x: float, z: float, foot: float, yaw: float) -> float:
	var c := cos(yaw)
	var s := sin(yaw)
	var lowest := _graded_height(x, z)
	for o in [Vector2(foot, foot), Vector2(-foot, foot), Vector2(foot, -foot), Vector2(-foot, -foot)]:
		lowest = minf(lowest, _graded_height(x + o.x * c - o.y * s, z + o.x * s + o.y * c))
	return lowest


## Ground height with the road corridors applied, which is what a prop standing on the terrain
## actually sees. The heightfield is built with the same function, so this matches the mesh.
func _graded_height(x: float, z: float) -> float:
	return _apply_road_corridors(_icefield_height(x, z), x, z)


## A small library of shared serac shapes, plus one convex collision shape each.
##
## Sharing matters twice over: 150 instances of seven meshes is seven meshes in memory, and one
## convex shape per variant instead of 150 is the difference between the field being cheap and the
## field costing more than the terrain.
func _build_serac_library() -> Array:
	var lib: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x53455242  # "SERB"
	# sides, taper, lean
	var specs := [
		# sides, taper, lean
		[6, 0.42, 0.12],
		[5, 0.55, -0.10],
		[7, 0.34, 0.06],
		[6, 0.68, -0.16],
		[5, 0.28, 0.18],
		[8, 0.50, 0.02],
		[6, 0.80, -0.06],
	]
	for i in range(specs.size()):
		var mesh: ArrayMesh = _make_ice_block_mesh(rng, specs[i][0], specs[i][1], specs[i][2])
		lib.append({"mesh": mesh, "shape": mesh.create_convex_shape()})
	return lib


## One material per library variant, tinted slightly differently. A single material across a
## hundred blocks gives every one of them exactly the same colour, which is a large part of what
## makes a scattered field read as copies of one prop.
func _tint_variants(base: Material) -> Array:
	var tints := [
		Color(1.00, 1.00, 1.00),
		Color(0.88, 0.95, 1.04),
		Color(1.06, 1.02, 0.95),
		Color(0.82, 0.92, 1.02),
		Color(1.04, 1.06, 1.02),
		Color(0.94, 0.88, 0.90),
		Color(0.90, 1.00, 0.96),
	]
	var out: Array = []
	for i in range(tints.size()):
		var m: ShaderMaterial = (base as ShaderMaterial).duplicate()
		m.set_shader_parameter("ice_color", Color(0.60, 0.78, 0.92) * tints[i])
		m.set_shader_parameter("deep_color", Color(0.22, 0.44, 0.64) * tints[i])
		m.set_shader_parameter("aurora_tint", Color(0.20, 0.62, 0.52) * tints[i])
		out.append(m)
	return out


## Scatters ice: a field of seracs across the whole circuit, and flat floes on the frozen lake.
##
## Placement is clustered rather than even. An even scatter of anything reads as debris dropped on
## the terrain; seracs come in lines, because that is where the glacier actually broke, so a noise
## mask decides where the field is thick and where the snow is clean. Everything is still rejected
## if it lands on a carriageway, inside the cavern's glacier, or over the crevasse.
func _build_ice_scatter(parent: Node, ice_mat: Material) -> void:
	var root := Node3D.new()
	root.name = "IceScatter"
	parent.add_child(root)

	var bodies := StaticBody3D.new()
	bodies.name = "SeracBodies"
	root.add_child(bodies)

	var lib: Array = _serac_library()
	var mats: Array = _tint_variants(ice_mat)
	var flat_idx: int = lib.size() - 1
	var flat_mesh: ArrayMesh = lib[flat_idx]["mesh"]
	var flat_shape: Shape3D = lib[flat_idx]["shape"]

	var rng := RandomNumberGenerator.new()
	rng.seed = 0x53455241  # "SERA"
	var cluster := FastNoiseLite.new()
	cluster.seed = 4492
	cluster.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cluster.frequency = 0.0062
	cluster.fractal_octaves = 3

	var cell := 30.0
	var x0: float = -320.0
	var x1: float = 360.0
	var z0: float = -520.0
	var z1: float = 450.0
	var seracs := 0
	var floes := 0
	var px := x0
	while px < x1:
		var pz := z0
		while pz < z1:
			var cx: float = px + rng.randf_range(-cell * 0.48, cell * 0.48)
			var cz: float = pz + rng.randf_range(-cell * 0.48, cell * 0.48)
			var dists: Vector2 = _corridor_distances(cx, cz)
			if dists.x < 15.0 or dists.y < CAVERN_MASS_HALF_W + 30.0:
				pz += cell
				continue
			# Not on the massif. The flanks are steep enough that a block placed on one reads as
			# stuck to a cliff at a bad angle rather than as ice standing on the glacier, and the
			# sampling below cannot sink a block reliably onto a slope this steep.
			if _cavern_mass(cx, cz) > 6.0:
				pz += cell
				continue
			var slot: Vector2 = _crevasse_slot(cx, cz)
			if absf(slot.x) < 1.0 and slot.y < 1.3:
				pz += cell
				continue
			# Field thickness. Squaring the noise is what turns an even scatter into a field:
			# most of the icefield gets nothing, and what does get seracs gets them in lines.
			var density: float = cluster.get_noise_2d(cx, cz) * 0.5 + 0.5
			density = density * density
			if rng.randf() > 0.015 + density * 1.15:
				pz += cell
				continue
			var on_lake: bool = (Vector2(cx, cz) - LAKE_CENTER).length() / LAKE_RADIUS.x < 0.94
			if on_lake:
				# Floes are thin plates of drifted ice lying on the lake, so they stay low.
				var mi := MeshInstance3D.new()
				mi.name = "LakeFloe_%d" % floes
				mi.mesh = flat_mesh
				mi.material_override = mats[rng.randi_range(0, mats.size() - 1)]
				var fw: float = rng.randf_range(5.0, 15.0)
				mi.scale = Vector3(fw, rng.randf_range(0.22, 0.5), fw * rng.randf_range(0.5, 0.95))
				# Same reasoning as the seracs: on the lake plate the surface is flat, but a floe
				# is wide enough that a single sample still leaves a lip.
				mi.position = Vector3(cx, LAKE_SURFACE_Y - 0.07, cz)
				mi.rotation_degrees = Vector3(rng.randf_range(-3.0, 3.0), rng.randf_range(0.0, 360.0), rng.randf_range(-3.0, 3.0))
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				bodies.add_child(mi)
				var cs := CollisionShape3D.new()
				cs.name = "FloeCollision"
				cs.shape = flat_shape
				cs.position = mi.position
				cs.scale = mi.scale
				cs.rotation_degrees = mi.rotation_degrees
				bodies.add_child(cs)
				floes += 1
				pz += cell
				continue

			# Seracs. Each hit seeds a small cluster along one bearing: a glacier breaks up in
			# lines of blocks sharing an orientation, and a cluster reads as part of the ice
			# where an isolated block reads as a prop someone dropped.
			var var_idx: int = rng.randi_range(0, lib.size() - 2)
			var bearing: float = rng.randf_range(0.0, TAU)
			var count: int = 1 if rng.randf() > 0.55 else rng.randi_range(2, 4)
			for c in range(count):
				var jx: float = cx
				var jz: float = cz
				if c > 0:
					var step_len: float = rng.randf_range(6.0, 22.0)
					var spread: float = rng.randf_range(-0.22, 0.22)
					jx += cos(bearing + spread) * step_len
					jz += sin(bearing + spread) * step_len
					var jd: Vector2 = _corridor_distances(jx, jz)
					if jd.x < 15.0 or jd.y < CAVERN_MASS_HALF_W + 30.0:
						continue
					if _cavern_mass(jx, jz) > 6.0:
						continue
					var jslot: Vector2 = _crevasse_slot(jx, jz)
					if absf(jslot.x) < 1.0 and jslot.y < 1.3:
						continue
				# Tall, narrow, heavily tapered: an ice tower, not a block. The occasional one
				# has toppled and lies as a low slab.
				var standing: bool = rng.randf() < 0.84
				var w: float = rng.randf_range(2.6, 6.0)
				var d: float = rng.randf_range(2.6, 6.0)
				var hgt: float = rng.randf_range(8.0, 22.0) if standing else rng.randf_range(3.0, 5.5)
				var mi2 := MeshInstance3D.new()
				mi2.name = "Serac_%d" % seracs
				mi2.mesh = lib[var_idx]["mesh"]
				mi2.material_override = mats[var_idx % mats.size()]
				mi2.scale = Vector3(w, hgt, d)
				# Sit the block on the LOWEST ground under its four corners, not the height at its
				# centre. On the massif flanks - which is exactly where the field is thickest - a
				# centre sample is metres above the downhill corner, so the block hangs in the air
				# with a visible gap under one side.
				# The block is rotated, so its footprint is not axis-aligned; the corner samples
				# have to follow the rotation or a steep flank still leaves a corner in the air.
				var yaw: float = rng.randf_range(0.0, TAU)
				var foot: float = w * 0.5
				var ground: float = _ground_under_rotated(jx, jz, foot, yaw)
				# Sunk well into the snow, or they look dropped on top of it.
				mi2.position = Vector3(jx, ground + hgt * 0.5 - 3.0, jz)
				mi2.rotation_degrees = Vector3(
					rng.randf_range(-7.0, 7.0) if standing else rng.randf_range(-20.0, 20.0),
					rad_to_deg(yaw),
					rng.randf_range(-7.0, 7.0) if standing else rng.randf_range(-20.0, 20.0))
				bodies.add_child(mi2)
				var cs2 := CollisionShape3D.new()
				cs2.name = "SeracCollision"
				cs2.shape = lib[var_idx]["shape"]
				cs2.position = mi2.position
				cs2.scale = mi2.scale
				cs2.rotation_degrees = mi2.rotation_degrees
				bodies.add_child(cs2)
				seracs += 1
			pz += cell
		px += cell
	print("  ice scatter: %d seracs, %d lake floes" % [seracs, floes])


## A natural ice arch straddling the road, built as a swept half-annulus so it has real
## thickness and its own collision. Two of them, at anchors on the circuit.
func _build_ice_arches(parent: Node, ice_mat: Material, anchors: Array) -> void:
	var root := Node3D.new()
	root.name = "IceArches"
	parent.add_child(root)

	for entry in anchors:
		var anchor: Vector3 = entry[0]
		var half_span: float = entry[1]
		var height: float = entry[2]
		var thick: float = entry[3]
		var along_len: float = entry[4]

		var off: float = main_track_curve.get_closest_offset(anchor)
		var f: Dictionary = _frame_at_offset(main_track_curve, off)
		var pos: Vector3 = f["pos"]
		var yaw: float = rad_to_deg(atan2(-f["fwd"].x, -f["fwd"].z))

		var body := StaticBody3D.new()
		body.name = "IceArch_%d" % int(off)
		body.position = pos + Vector3.UP * -1.0
		body.rotation_degrees = Vector3(0.0, yaw, 0.0)

		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 18
		var rings := 5
		# Closed cross-section: inner arc out, outer arc back. Same winding convention as the
		# cavern shell, so one normal routine covers both.
		var profile := PackedVector2Array()
		for i in range(seg + 1):
			var t: float = PI * float(i) / float(seg)
			profile.append(Vector2(half_span * cos(t), (height + 1.0) * sin(t)))
		for i in range(seg + 1):
			var t2: float = PI * (1.0 - float(i) / float(seg))
			profile.append(Vector2((half_span + thick) * cos(t2), (height + 1.0 + thick) * sin(t2)))
		var pn := PackedVector2Array()
		var n := profile.size()
		for i in range(n):
			var prev: Vector2 = profile[(i - 1 + n) % n]
			var here: Vector2 = profile[i]
			var nxt: Vector2 = profile[(i + 1) % n]
			var e_in: Vector2 = (here - prev).normalized()
			var e_out: Vector2 = (nxt - here).normalized()
			var nn: Vector2 = Vector2(e_in.y, -e_in.x) + Vector2(e_out.y, -e_out.x)
			pn.append(nn.normalized() if nn.length_squared() > 1e-6 else Vector2(0.0, 1.0))

		for r in range(rings):
			var lz: float = lerpf(-along_len * 0.5, along_len * 0.5, float(r) / float(rings - 1))
			for i in range(n):
				var p2: Vector2 = profile[i]
				# Local space, not world: the body's yaw already orients the arch along the road.
				# Writing world-oriented vertices here as well rotates the arch twice, which on
				# any corner steeper than a hairpin lands one springing on the carriageway.
				st.set_normal(Vector3(pn[i].x, pn[i].y, 0.0))
				st.set_uv(Vector2(p2.x * 0.06, lz * 0.06))
				st.add_vertex(Vector3(p2.x, p2.y, lz))
		for r in range(rings - 1):
			var r0: int = r * n
			var r1: int = (r + 1) * n
			for i in range(n):
				var j: int = (i + 1) % n
				st.add_index(r0 + i); st.add_index(r0 + j); st.add_index(r1 + j)
				st.add_index(r0 + i); st.add_index(r1 + j); st.add_index(r1 + i)

		# End caps: the swept tube is open at both z ends, and without them you can see into the
		# hollow between the inner and outer walls from any angle off straight-on - which reads
		# as the arch having open sides. The cap is the annulus band itself: one quad per arc
		# segment joining the inner edge to the matching outer edge, plus the two sole quads at
		# the springings. (A triangle fan from one vertex would also fill the driving opening,
		# which is outside the profile loop but inside the fan.)
		#
		# Winding is irrelevant here - the ice shader is cull_disabled and every cap vertex gets
		# an explicit +-Z normal - so only the pairing matters: inner k to outer k.
		# SurfaceTool cannot be read back, so emitted vertices are counted here for the cap
		# indices below.
		var emitted: int = rings * n
		for end_r in [0, rings - 1]:
			var nz := Vector3(0.0, 0.0, 1.0 if end_r == rings - 1 else -1.0)
			var lz: float = lerpf(-along_len * 0.5, along_len * 0.5, float(end_r) / float(rings - 1))
			for k in range(seg):
				# Inner arc runs profile[0..seg], outer arc profile[seg+1..2*seg+1]; the outer
				# index mirrors the inner one because the outer arc was authored back from t=PI
				# down to 0.
				for pi in [k, k + 1, n - 2 - k, n - 1 - k]:
					st.set_normal(nz)
					st.set_uv(Vector2(0.5, 0.5))
					st.add_vertex(Vector3(profile[pi].x, profile[pi].y, lz))
					emitted += 1
				var cb: int = emitted - 4
				st.add_index(cb); st.add_index(cb + 1); st.add_index(cb + 2)
				st.add_index(cb); st.add_index(cb + 2); st.add_index(cb + 3)
		var arch_mesh: ArrayMesh = _save_baked_resource(st.commit(), "ice_arch_%d" % int(off))
		var mi := MeshInstance3D.new()
		mi.name = "ArchMesh"
		mi.mesh = arch_mesh
		mi.material_override = ice_mat
		body.add_child(mi)
		var cs := CollisionShape3D.new()
		cs.name = "ArchCollision"
		var shp: Shape3D = arch_mesh.create_trimesh_shape()
		if shp is ConcavePolygonShape3D:
			(shp as ConcavePolygonShape3D).backface_collision = true
		cs.shape = _save_baked_resource(shp, "ice_arch_%d_collision" % int(off))
		body.add_child(cs)
		root.add_child(body)

		# A cluster of blocks at each springing, so the arch looks founded rather than placed.
		var rng := RandomNumberGenerator.new()
		rng.seed = 0x41524348 + int(off)
		var lib: Array = _serac_library()
		for s in [-1.0, 1.0]:
			for i in range(5):
				var pick: int = rng.randi_range(0, lib.size() - 2)
				var b := MeshInstance3D.new()
				b.name = "Footing_%s_%d" % ["L" if s < 0.0 else "R", i]
				b.mesh = lib[pick]["mesh"]
				b.material_override = ice_mat
				var bw: float = rng.randf_range(2.4, 5.0)
				b.scale = Vector3(bw, rng.randf_range(2.0, 4.0), bw * rng.randf_range(0.7, 1.2))
				b.position = Vector3(float(s) * (half_span + thick * 0.4) + rng.randf_range(-1.5, 1.5),
						rng.randf_range(0.4, 1.6), rng.randf_range(-along_len * 0.5, along_len * 0.5))
				b.rotation_degrees = Vector3(rng.randf_range(-12.0, 12.0), rng.randf_range(0.0, 360.0), rng.randf_range(-12.0, 12.0))
				body.add_child(b)
				# The arch ring has its own trimesh, but these footings are separate instances:
				# without a shape each one is a rock you can drive straight through. The library
				# shapes are convex, so one shared shape per variant is cheap.
				var bcs := CollisionShape3D.new()
				bcs.name = "FootingCollision_%s_%d" % ["L" if s < 0.0 else "R", i]
				bcs.shape = lib[pick]["shape"]
				bcs.position = b.position
				bcs.scale = b.scale
				bcs.rotation_degrees = b.rotation_degrees
				body.add_child(bcs)


## Trackside lamps along both road edges, alternating sides, with a spotlight on every other
## one aimed back at the road.
##
## The first version stood the poles ON the snow bank at a fixed +1.9m, which assumed every metre
## of bank is exactly crest height: wherever the bank opens at a junction, or the road crowns, or
## the terrain falls away, the pole floated in the air or sank into the deck - and at 6.88m
## lateral it was standing on the driving surface anyway. So the lamps now stand PAST the bank,
## outside the deck entirely, with their feet in the actual ground under them and a pole long
## enough to reach over the bank from there.
func _build_edge_markers(parent: Node, curve: Curve3D, label: String,
		left_gaps: Array, right_gaps: Array, spacing: float) -> void:
	var length: float = curve.get_baked_length()
	var root := Node3D.new()
	root.name = "EdgeMarkers_" + label
	parent.add_child(root)

	# Ice lamp posts: a frosted hexagonal post, a dark collar, and a cluster of glowing crystals.
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.62, 0.78, 0.92)
	pole_mat.metallic = 0.15
	pole_mat.roughness = 0.28
	pole_mat.rim_enabled = true
	pole_mat.rim = 0.45
	pole_mat.rim_tint = 0.6

	var collar_mat := StandardMaterial3D.new()
	collar_mat.albedo_color = Color(0.16, 0.22, 0.32)
	collar_mat.metallic = 0.6
	collar_mat.roughness = 0.4

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.70, 0.95, 1.0)
	head_mat.roughness = 0.12
	head_mat.emission_enabled = true
	head_mat.emission = Color(0.38, 0.82, 1.0)
	head_mat.emission_energy_multiplier = 1.5
	head_mat.rim_enabled = true
	head_mat.rim = 0.6

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.09
	pole_mesh.bottom_radius = 0.17
	pole_mesh.height = 5.2
	pole_mesh.radial_segments = 6
	pole_mesh.rings = 1
	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = 0.24
	collar_mesh.bottom_radius = 0.13
	collar_mesh.height = 0.22
	collar_mesh.radial_segments = 6
	collar_mesh.rings = 1
	var head_mesh := _make_lamp_crystal_mesh()

	var count := int(length / spacing)
	for i in range(count):
		var off: float = float(i) * spacing + spacing * 0.5
		if off > length - 4.0:
			continue
		# Inside the cavern the cave's own lighting already does this job, and lamps in a
		# gallery read as scaffolding.
		var f: Dictionary = _frame_at_offset(curve, off)
		var p: Vector3 = f["pos"]
		if main_track_curve and curve == main_track_curve:
			if off > _cavern_range.x - 30.0 and off < _cavern_range.y + 30.0:
				continue
		var side: float = 1.0 if (i % 2 == 0) else -1.0
		var gaps: Array = right_gaps if side > 0 else left_gaps
		if not gaps.is_empty() and _bank_factor_at(off, gaps) < 0.6:
			continue
		# Past the bank, outside the deck: trunk deck ends at 7.5m, the bank carries to ~8.7m,
		# so 10.2m is clear of both with room for the pole.
		var lat: float = side * (_road_half_width(curve) + 2.7)
		var foot_xz: Vector3 = p + f["right"] * lat
		var ground: float = _graded_height(foot_xz.x, foot_xz.z)

		var node := StaticBody3D.new()
		node.name = "Marker_%d_%d" % [i, int(side)]
		# Feet sunk into the real ground, not floating at a fixed height above the deck.
		node.position = Vector3(foot_xz.x, ground - 0.4, foot_xz.z)
		node.rotation_degrees = Vector3(0.0, rad_to_deg(atan2(-f["fwd"].x, -f["fwd"].z)), 0.0)
		var pole := MeshInstance3D.new()
		pole.name = "Pole"
		pole.mesh = pole_mesh
		pole.material_override = pole_mat
		pole.position = Vector3(0.0, 2.6, 0.0)
		node.add_child(pole)
		var collar := MeshInstance3D.new()
		collar.name = "Collar"
		collar.mesh = collar_mesh
		collar.material_override = collar_mat
		collar.position = Vector3(0.0, 5.25, 0.0)
		node.add_child(collar)
		var head := MeshInstance3D.new()
		head.name = "Head"
		head.mesh = head_mesh
		head.material_override = head_mat
		head.position = Vector3(0.0, 5.3, 0.0)
		# Each lamp's cluster turned differently, so a row of them doesn't read as copies.
		head.rotation_degrees = Vector3(0.0, float(i * 47 % 360), 0.0)
		# The glow is the light; a shadow from it would sit on the road under its own lamp.
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(head)
		var cs := CollisionShape3D.new()
		cs.name = "PoleCollision"
		var shp := CylinderShape3D.new()
		shp.radius = 0.18
		shp.height = 5.2
		cs.shape = shp
		cs.position = pole.position
		node.add_child(cs)
		root.add_child(node)

		if i % 2 == 0:
			# Aimed at the road 10m ahead of the lamp, from local +X (right shoulder) or -X
			# back toward the centreline. The node is yaw-aligned to travel, so local -Z is
			# forward and local X is lateral: the beam goes inward and forward onto the deck.
			var lx: float = side * (_road_half_width(curve) + 2.7)
			var spot := SpotLight3D.new()
			spot.name = "Spot"
			spot.position = Vector3(0.0, 5.1, 0.0)
			spot.rotation_degrees = Vector3(
				-rad_to_deg(atan2(4.6, sqrt(lx * lx + 100.0))),
				rad_to_deg(atan2(lx, 10.0)), 0.0)
			spot.light_color = Color(0.82, 0.93, 1.0)
			spot.light_energy = 7.0
			spot.spot_range = 42.0
			spot.spot_angle = 52.0
			spot.spot_attenuation = 1.0
			node.add_child(spot)


## The lamp head: a tall hexagonal ice crystal with three smaller ones leaning out around its base,
## merged into one mesh so each lamp costs a single draw. Origin at the base of the cluster.
func _make_lamp_crystal_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Main crystal, then three satellites: [radius, body height, tip height, lean (deg), yaw (deg)].
	var parts := [[0.17, 0.62, 0.34, 0.0, 0.0], [0.09, 0.30, 0.18, 34.0, 20.0],
		[0.08, 0.26, 0.16, 38.0, 140.0], [0.10, 0.34, 0.20, 30.0, 260.0]]
	for part in parts:
		var r: float = part[0]
		var body: float = part[1]
		var tip: float = part[2]
		var basis := Basis(Vector3.UP, deg_to_rad(part[4])) * Basis(Vector3.RIGHT, deg_to_rad(part[3]))
		var origin := Vector3(0.0, 0.0, 0.0) if part[3] == 0.0 else basis * Vector3(0.0, 0.05, 0.0)
		var bottom := Vector3(0.0, -tip * 0.5, 0.0)
		var top := Vector3(0.0, body + tip, 0.0)
		var ring_lo: Array = []
		var ring_hi: Array = []
		for k in range(6):
			var a: float = TAU * float(k) / 6.0
			ring_lo.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
			ring_hi.append(Vector3(cos(a) * r * 0.92, body, sin(a) * r * 0.92))
		var tris: Array = []
		for k in range(6):
			var j: int = (k + 1) % 6
			tris.append([ring_lo[k], ring_lo[j], ring_hi[j]])
			tris.append([ring_lo[k], ring_hi[j], ring_hi[k]])
			tris.append([ring_hi[k], ring_hi[j], top])
			tris.append([ring_lo[j], ring_lo[k], bottom])
		var centre := Vector3(0.0, body * 0.5, 0.0)
		for t in tris:
			var a3: Vector3 = basis * t[0] + origin
			var b3: Vector3 = basis * t[1] + origin
			var c3: Vector3 = basis * t[2] + origin
			var outward: Vector3 = (a3 + b3 + c3) / 3.0 - (basis * centre + origin)
			# Front faces: (c - a) x (b - a) along the outward direction (see _build_cavern_cap).
			if (c3 - a3).cross(b3 - a3).dot(outward) < 0.0:
				var tmp: Vector3 = b3
				b3 = c3
				c3 = tmp
			st.add_vertex(a3)
			st.add_vertex(b3)
			st.add_vertex(c3)
	st.generate_normals()
	return st.commit()


## Deck half width of a road, so the marker stakes are driven into the crown of the bank and
## cannot drift off it if a road width is ever retuned.
func _road_half_width(curve: Curve3D) -> float:
	return ROUTE_HALF_W if curve != main_track_curve else MAIN_HALF_W


## A pair of tall ice pylons flanking the trunk at each route split, with glowing caps. These
## are the only "signage" on a stage with no road signs, and they double as the visual shorthand
## for "there is a fork here".
func _build_junction_pylons(parent: Node, ice_mat: Material, routes: Array) -> void:
	var root := Node3D.new()
	root.name = "JunctionPylons"
	parent.add_child(root)

	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.65, 1.0, 0.85)

	for entry in routes:
		var rc: Curve3D = entry[0]
		var label: String = entry[2]
		var side: int = entry[1]
		for end_i in [0.0, rc.get_baked_length()]:
			var nose: Vector3 = rc.sample_baked(end_i)
			var trunk_off: float = main_track_curve.get_closest_offset(nose)
			var f: Dictionary = _frame_at_offset(main_track_curve, trunk_off)
			var group := Node3D.new()
			group.name = "Pylons_%s_%d" % [label, int(trunk_off)]
			group.position = f["pos"]
			group.rotation_degrees = Vector3(0.0, rad_to_deg(atan2(-f["fwd"].x, -f["fwd"].z)), 0.0)
			for s in [-1.0, 1.0]:
				var lat2: float = float(s) * (MAIN_HALF_W + 3.4)
				var body := StaticBody3D.new()
				body.name = "Pylon_%s_%d" % ["L" if s < 0.0 else "R", int(trunk_off)]
				body.position = Vector3(lat2, 0.0, 0.0)
				var mi := MeshInstance3D.new()
				mi.name = "PylonMesh"
				# A tapered post, not a box: this is the one piece of built scenery on the stage,
				# so it should read as something someone set up rather than as another ice block.
				var bm := CylinderMesh.new()
				bm.top_radius = 1.15
				bm.bottom_radius = 1.7
				bm.height = 11.0
				bm.radial_segments = 6
				mi.mesh = bm
				mi.material_override = ice_mat
				mi.position = Vector3(0.0, 5.0, 0.0)
				mi.rotation_degrees = Vector3(0.0, float(s) * 11.0, float(s) * 3.5)
				body.add_child(mi)
				var cap := MeshInstance3D.new()
				cap.name = "CapMesh"
				var cm := BoxMesh.new()
				cm.size = Vector3(2.3, 0.6, 2.3)
				cap.mesh = cm
				cap.material_override = glow_mat
				cap.position = Vector3(0.0, 10.7, 0.0)
				body.add_child(cap)
				var cs := CollisionShape3D.new()
				cs.name = "PylonCollision"
				var shp := BoxShape3D.new()
				shp.size = Vector3(1.9, 11.0, 1.9)
				cs.shape = shp
				cs.position = mi.position
				body.add_child(cs)
				group.add_child(body)
			root.add_child(group)


## Dark water filling the crevasse slot under the ice arch.
##
## The slot floor drops to -22m mid-span while the bridge deck crosses at +10m, so a plane at -6m
## sits 16m under the cars and 16m over the deepest floor: deep, still, black water that catches
## the arch lights. Shaped as a strip along the slot rather than a disc, so it cannot disagree
## with the slot about where the water ends.
##
## The node name has to contain "Water": PlayerCart has no TerrainGenerator to ask on this stage,
## so it falls back to level.find_child("*Water*") and reads water_surface_y and the bounds off
## its metadata. Miss either and cars drive through the slot without a splash.
func _build_crevasse_water(parent: Node) -> void:
	var water_y := -6.0
	var dir := CREVASSE_DIR
	var half_len := 75.0
	var half_w := 20.0
	var center := CREVASSE_CENTER + dir * -35.0

	var node := MeshInstance3D.new()
	node.name = "CrevasseWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(half_w * 2.0, half_len * 2.0)
	node.mesh = plane
	node.position = Vector3(center.x, water_y, center.y)
	# PlaneMesh's long axis is Z: yaw it onto the slot direction.
	node.rotation_degrees = Vector3(0.0, rad_to_deg(atan2(dir.x, dir.y)), 0.0)

	var noise := FastNoiseLite.new()
	noise.seed = 77031
	noise.frequency = 0.02
	var noise_tex := NoiseTexture2D.new()
	noise_tex.seamless = true
	noise_tex.as_normal_map = true
	noise_tex.noise = noise

	var mat := ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.set_shader_parameter("water_color", Color(0.008, 0.030, 0.060))
	mat.set_shader_parameter("shallow_color", Color(0.05, 0.16, 0.24))
	mat.set_shader_parameter("sky_tint", Color(0.35, 0.55, 0.75))
	mat.set_shader_parameter("sky_reflect", 0.65)
	mat.set_shader_parameter("transparency", 0.45)
	mat.set_shader_parameter("metallic", 0.60)
	mat.set_shader_parameter("roughness", 0.10)
	node.material_override = mat

	# Bounds the cart checks against, as the strip's own AABB.
	var ex := absf(dir.x) * half_len + absf(dir.y) * half_w
	var ez := absf(dir.y) * half_len + absf(dir.x) * half_w
	node.set_meta("water_surface_y", water_y)
	node.set_meta("water_bounds_min", Vector2(center.x - ex, center.y - ez))
	node.set_meta("water_bounds_max", Vector2(center.x + ex, center.y + ez))
	parent.add_child(node)


## A pair of lights under the crevasse arch, so the bridge reads from the shelf above and the
## slot below it is not a black hole.
func _build_crevasse_lights(parent: Node) -> void:
	var root := Node3D.new()
	root.name = "CrevasseLights"
	parent.add_child(root)
	var steps := 7
	for i in range(steps):
		var t: float = float(i) / float(steps - 1)
		var off: float = lerpf(_bridge_range.x + 6.0, _bridge_range.y - 6.0, t)
		var f: Dictionary = _frame_at_offset(main_track_curve, off)
		var l := OmniLight3D.new()
		l.name = "CrevasseLight_%d" % i
		l.position = f["pos"] + f["right"] * (8.0 if i % 2 == 0 else -8.0) - Vector3.UP * 13.0
		l.light_color = Color(0.40, 0.85, 1.0)
		# Strong and long-ranged on purpose: the slot is 26m deep and 50m across, so anything that
		# only lights its own patch leaves the crossing as a black trench from the shelf above.
		l.light_energy = 6.5
		l.omni_range = 52.0
		l.omni_attenuation = 1.2
		root.add_child(l)


# ======================================================================================
#  Utilities
# ======================================================================================

## Writes a generated mesh/shape to res://generated/ and returns the loaded resource, so the
## level scene references the file instead of inlining megabytes of vertex data.
func _save_baked_resource(res: Resource, res_name: String) -> Resource:
	if not DirAccess.dir_exists_absolute("res://generated/"):
		DirAccess.make_dir_absolute("res://generated/")
	var file_path: String = "res://generated/" + RES_PREFIX + res_name + ".res"
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


## Paints the menu tile: a procedural aurora over the glacier, so the course list has a picture
## that matches the stage instead of borrowing another track's photograph.
##
## The composition is the stage's own read in three bands - sky, silhouetted ice wall, frozen
## lake - with the road receding to a vanishing point under a glowing arch, because that silhouette
## is what makes the tile legible at the 128px the menu actually draws it at.
func _build_menu_tile() -> void:
	const SIZE := 512
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var ridge := FastNoiseLite.new()
	ridge.seed = 90210
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge.frequency = 0.010
	ridge.fractal_octaves = 4
	var veil := FastNoiseLite.new()
	veil.seed = 1357
	veil.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	veil.frequency = 0.028
	veil.fractal_octaves = 3

	var stars := RandomNumberGenerator.new()
	stars.seed = 24680
	var star_list: Array = []
	for i in range(170):
		star_list.append([stars.randf(), stars.randf(), stars.randf_range(0.35, 1.0)])

	# Band edges, in normalised units.
	const HORIZON := 0.60
	const RIDGE_BOTTOM := 0.78

	for y in range(SIZE):
		var v: float = float(y) / float(SIZE - 1)
		for x in range(SIZE):
			var u: float = float(x) / float(SIZE - 1)
			var col := Color(0.006, 0.010, 0.028)

			# --- Sky: dome gradient, two aurora curtains, stars ---------------------------
			var t: float = clampf(v / HORIZON, 0.0, 1.0)
			col = Color(0.010, 0.020, 0.058).lerp(Color(0.045, 0.090, 0.165), pow(t, 1.8))
			var az: float = u * 9.4
			var c1: float = 0.34 + 0.07 * sin(az * 0.7) + 0.04 * sin(az * 2.1)
			var band1: float = exp(-pow((t - c1) / 0.17, 2.0))
			var band2: float = exp(-pow((t - (c1 - 0.21)) / 0.13, 2.0)) * 0.7
			var stri: float = 0.42 + 0.85 * (veil.get_noise_2d(u * 30.0, v * 11.0) * 0.5 + 0.5)
			var foot: float = smoothstep(0.0, 0.09, t - (c1 - 0.17))
			var amount: float = (band1 + band2) * stri * foot
			var tint: Color = Color(0.10, 0.95, 0.55).lerp(Color(0.48, 0.40, 1.0),
					clampf((t - c1 + 0.17) / 0.36, 0.0, 1.0))
			var sky_col: Color = col + tint * amount * 0.9
			for s in star_list:
				var su: float = s[0]
				var sv: float = s[1]
				var d: float = Vector2(u - su, (v - sv) * 1.0).length()
				if d < 0.0035:
					sky_col += Color(0.85, 0.90, 1.0) * (1.0 - d / 0.0035) * s[2] * (1.0 - amount * 0.75)

			# --- Ice wall ------------------------------------------------------------------
			# The ridge is a silhouette with a lit rim along its crest: without the rim it reads as
			# a black bar across the bottom of the tile rather than as a glacier.
			var g: float = ridge.get_noise_2d(u * 5.0, 0.0) * 0.5 + 0.5
			var g2: float = ridge.get_noise_2d(u * 13.0, 7.0) * 0.5 + 0.5
			var skyline: float = HORIZON + 0.010 + g * 0.135 + g2 * 0.028
			var wall := Color(0.0, 0.0, 0.0)
			if v >= HORIZON and v < RIDGE_BOTTOM:
				var depth: float = clampf((v - skyline) / maxf(RIDGE_BOTTOM - skyline, 0.001), 0.0, 1.0)
				if v < skyline:
					wall = Color(0.0, 0.0, 0.0)
				else:
					var lit: float = pow(1.0 - depth, 3.0)
					# Faint aurora spill on the upper ice.
					var spill: float = exp(-pow((v - skyline) / 0.045, 2.0)) * amount * 0.22
					wall = Color(0.042, 0.072, 0.128).lerp(Color(0.010, 0.020, 0.044), depth)
					wall += tint * spill * 1.4
					wall += Color(0.14, 0.27, 0.40) * lit
					# Seracs standing on the crest, so the skyline is not a smooth wave.
					var blk: float = ridge.get_noise_2d(u * 34.0, 21.0) * 0.5 + 0.5
					var notch: float = smoothstep(0.70, 0.86, blk) * 0.055 * (1.0 - depth * 3.0)
					if notch > 0.0:
						wall = wall.lerp(Color(0.020, 0.038, 0.070), clampf(notch / 0.055, 0.0, 1.0))

			# --- Frozen lake and the road --------------------------------------------------
			var lake := Color(0.0, 0.0, 0.0)
			if v >= RIDGE_BOTTOM:
				var fl: float = clampf((v - RIDGE_BOTTOM) / (1.0 - RIDGE_BOTTOM), 0.0, 1.0)
				lake = Color(0.020, 0.042, 0.072).lerp(Color(0.045, 0.085, 0.125), pow(fl, 0.6))
				# Ice cracks catching the aurora.
				var crack: float = 0.0
				if fl > 0.06:
					crack = pow(1.0 - abs(veil.get_noise_2d(u * 9.0, fl * 5.0 + 3.0) * 2.0 - 1.0), 10.0)
				lake += Color(0.16, 0.30, 0.42) * crack * fl * 0.55

				# Road: a trapezoid narrowing to a vanishing point, with glowing edge stakes.
				var rt: float = clampf(fl, 0.0, 1.0)
				var cx: float = 0.44 - 0.03 * (1.0 - rt)
				var hw: float = 0.010 + 0.150 * pow(rt, 1.6)
				var du: float = absf(u - cx)
				if du < hw and rt > 0.02:
					var shade: float = 0.30 + 0.30 * rt
					lake = Color(0.20, 0.26, 0.34) * shade + Color(0.02, 0.05, 0.08)
					# Dashed centre line.
					if du < hw * 0.06 and fmod(v * 26.0, 2.0) < 1.0:
						lake = Color(0.55, 0.72, 0.82)
				# Edge stakes, every so often along the run.
				var edge_frac: float = (du - hw * 0.94) / maxf(hw * 0.10, 0.0008)
				if rt > 0.05 and absf(edge_frac) < 1.2 and fmod(v * 14.0, 3.0) < 1.1:
					lake = Color(0.42, 0.95, 1.0)
				# The arch over the road.
				var at: float = (rt - 0.42) / 0.075
				if absf(at) < 1.0:
					var arch_hw: float = hw * 1.85 * sqrt(maxf(1.0 - at * at, 0.0))
					if du < arch_hw:
						lake = lake.lerp(Color(0.55, 1.0, 0.92), 0.72 - 0.35 * absf(at))

			col = sky_col
			if wall != Color(0.0, 0.0, 0.0):
				col = wall
			if lake != Color(0.0, 0.0, 0.0):
				col = lake

			img.set_pixel(x, y, col)

	var out := "res://images/menu/tile_northlight_caverns.jpg"
	if img.save_jpg(out, 0.94) == OK:
		print("  wrote menu tile %s" % out)
	else:
		push_warning("Could not write the menu tile")


# ======================================================================================
#  Level build
# ======================================================================================

func _ready() -> void:
	print("=== Northlight Caverns Arctic Cup Level Generation ===")
	print("Building polar night icefield: glacier cavern, crevasse ice arch, frozen lake, aurora sky...")

	var level_scene := Node3D.new()
	level_scene.name = LEVEL_NAME

	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)

	# 0. Core nodes (must exist before entering the tree for @onready variables)
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

	_build_menu_tile()

	# 1. Environment: a polar night. The sky shader carries the aurora, the directional light is
	# a low moon, and everything else on the stage is lit to match that rather than fighting it.
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	# Through a ShaderMaterial, not by assigning the Shader directly: Sky.sky_material is typed
	# Material, and handing it a bare Shader is rejected silently, leaving a black sky.
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://aurora_sky.gdshader")
	sky.sky_material = sky_mat
	env.sky = sky
	# Ambient from an explicit colour rather than from the sky. Sampling the sky for ambient sounds
	# right on a night stage and is unusable in practice: the dome's radiance is dominated by a
	# narrow, very bright aurora band, so the fill ends up both far too dim on the ground and the
	# wrong colour everywhere. A fixed cool fill keeps the snow readable and leaves the aurora to
	# be the sky's job.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.51, 0.62)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.45
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.14
	env.glow_hdr_threshold = 0.92
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.06
	env_node.environment = env
	level_scene.add_child(env_node)

	var moon := DirectionalLight3D.new()
	moon.name = "MoonLight"
	moon.rotation_degrees = Vector3(-21.0, 143.0, 0.0)
	moon.light_color = Color(0.74, 0.82, 1.0)
	moon.light_energy = 1.05
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 460.0
	moon.directional_shadow_split_1 = 0.12
	moon.directional_shadow_split_2 = 0.28
	moon.directional_shadow_split_3 = 0.58
	level_scene.add_child(moon)

	# Unshadowed fill from the opposite quarter. Night stages read as black holes without one: the
	# moon is behind half the circuit for most of the lap.
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-34.0, -40.0, 0.0)
	fill.light_color = Color(0.42, 0.62, 0.78)
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	level_scene.add_child(fill)

	# Hand the sky shader the moon's direction so the disc in the sky sits where the light is.
	sky_mat.set_shader_parameter("moon_dir", -moon.global_transform.basis.z)
	sky_mat.set_shader_parameter("moon_brightness", 1.0)
	sky_mat.set_shader_parameter("aurora_intensity", 1.3)
	# No stars: an aurora at this brightness drowns most of them anyway, and the ones that
	# survive read as dirt on the lens against the curtains.
	sky_mat.set_shader_parameter("star_brightness", 0.0)

	# Ambient wind
	var wind_stream = load("res://sounds/dragon-studio-winter-wind-402331.mp3")
	if wind_stream:
		var wind_player := AudioStreamPlayer.new()
		wind_player.name = "WinterWindAudio"
		wind_player.stream = wind_stream
		wind_player.volume_db = -14.0
		wind_player.autoplay = true
		level_scene.add_child(wind_player)

	# Spindrift. Reused from the daylight stages with a slower fall and a tighter box: at night
	# the flakes are only visible where they cross a lit surface.
	var snow_particles := GPUParticles3D.new()
	snow_particles.name = "FallingSnow"
	var falling_snow_script = load("res://FallingSnow.gd")
	if falling_snow_script:
		snow_particles.set_script(falling_snow_script)
	snow_particles.amount = 2200
	snow_particles.lifetime = 4.5
	snow_particles.speed_scale = 0.45
	snow_particles.randomness = 0.85
	snow_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow_particles.visibility_aabb = AABB(Vector3(-45, -30, -45), Vector3(90, 50, 90))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(34.0, 1.0, 34.0)
	pmat.direction = Vector3(0.35, -1.0, 0.2)
	pmat.spread = 14.0
	pmat.initial_velocity_min = 1.4
	pmat.initial_velocity_max = 5.0
	pmat.gravity = Vector3(0, -2.4, 0)
	pmat.scale_min = 0.6
	pmat.scale_max = 1.2
	snow_particles.process_material = pmat

	var snow_quad := QuadMesh.new()
	snow_quad.size = Vector2(0.11, 0.11)
	var fall_snow_mat := StandardMaterial3D.new()
	fall_snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fall_snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fall_snow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fall_snow_mat.vertex_color_use_as_albedo = true
	fall_snow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.85, 0.95, 1.0, 0.75), Color(0.7, 0.9, 1.0, 0.0)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 32
	grad_tex.height = 32
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	fall_snow_mat.albedo_texture = grad_tex
	fall_snow_mat.albedo_color = Color(0.86, 0.95, 1.0, 0.8)
	snow_quad.material = fall_snow_mat
	snow_particles.draw_pass_1 = snow_quad
	level_scene.add_child(snow_particles)

	# 2. Main TrackPath & Curve3D (~2km closed circuit)
	#
	# Clockwise circuit, starting on the frozen lake:
	#  - Start/finish straight across the lake, under the aurora
	#  - Lake shore and the Meltwater Cut divergence
	#  - The Ice Cavern: a 190m gallery through the glacier, entered and left through ice cliffs
	#  - North basin onto the high ice shelf, and the Serac Ledge divergence
	#  - The crevasse, crossed on the ice arch
	#  - Serac field, then home across the shelf and back over the lake on the west straight
	#
	# The closing complex (points 20-24) exists because a closed lap cannot simply run the start
	# straight one way and come back along it the other: the return has to travel *past* the line
	# and hook back onto the straight through the ice, which is what makes the finish line sit on
	# a straight instead of on a hairpin.
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	#
	# On plan this is a loop that never touches itself. That is not an aesthetic preference: two
	# stretches closer than about 26m centre-to-centre put a 15m carriageway and two 2.1m snow banks
	# in the same space, and the result is a crossing that looks passable from above and is walled
	# off from the driver's seat. So the plan is checked explicitly by _verify_plan() below.
	#
	# Reading it as a shape: the start straight runs south down the east side of the lake, the
	# circuit goes north through the cavern and out around the shelf, and the way home crosses the
	# southern ice westward - south of the start straight's own southern end, which is the only
	# place on the map where that crossing is legal - then climbs the far side of the lake and
	# hairpins at the north end to join the straight.
	var curve_pts: Array = [
		# --- SECTION 0: START / FINISH, frozen lake (running south) ---
		Vector3(-112.0, 3.00, 430.0),  # 0  finish line, with straight road both sides of it
		Vector3(-112.0, 2.99, 250.0),  # 1  lake straight
		# --- SECTION 1: lake shore and the Meltwater Cut divergence ---
		Vector3(-110.0, 2.96, 160.0),  # 2  shoreline
		Vector3(-100.0, 2.85, 40.0),   # 3  Meltwater Cut splits right
		Vector3(-74.0, 2.75, -34.0),   # 4  shore sweep
		Vector3(-34.0, 2.65, -78.0),   # 5  cavern apron
		# --- SECTION 2: THE ICE CAVERN ---
		Vector3(0.0, 2.50, -110.0),    # 6  south portal
		Vector3(0.0, 2.30, -172.0),    # 7  first chamber
		Vector3(0.0, 2.30, -238.0),    # 8  second chamber
		Vector3(0.0, 2.60, -300.0),    # 9  north portal
		# --- SECTION 3: north basin and the ice shelf ---
		Vector3(26.0, 3.30, -354.0),   # 10
		Vector3(92.0, 4.70, -382.0),   # 11  Serac Ledge splits left
		Vector3(152.0, 6.40, -368.0),  # 12
		Vector3(198.0, 8.60, -314.0),  # 13
		Vector3(214.0, 10.20, -240.0), # 14  crevasse, spanned by the ice arch
		Vector3(200.0, 10.00, -166.0), # 15
		Vector3(158.0, 8.20, -108.0),  # 16  shelf exit
		# --- SECTION 4: serac field, and the way home around the south of the lake ---
		Vector3(104.0, 6.20, -62.0),   # 17
		Vector3(50.0, 4.40, -30.0),    # 18
		Vector3(0.0, 3.85, 20.0),      # 19  back onto the ice
		Vector3(40.0, 3.70, 120.0),    # 20  turning south, east of the outbound diagonal
		Vector3(10.0, 3.58, 240.0),    # 21  running back down the middle of the lake
		Vector3(-30.0, 3.45, 350.0),   # 22  still clear of the start straight
		Vector3(-10.0, 3.38, 430.0),   # 23  south of the finish line, where the road is open
		Vector3(20.0, 3.30, 490.0),    # 24  swinging out east, away from the start straight
		Vector3(-30.0, 3.22, 530.0),   # 25  bottom of the arc
		Vector3(-90.0, 3.14, 510.0),   # 26  turning back west
		Vector3(-112.0, 3.06, 470.0),  # 27  onto the line of the start straight, running north
	]

	# Handles are derived from the geometry rather than hand-picked: see _build_closed_loop.
	var curve := _build_closed_loop(curve_pts, TRUNK_MIN_RADIUS)
	_verify_min_radius(curve, MAIN_HALF_W, "trunk")

	track_path.curve = curve
	main_track_curve = curve
	level_scene.add_child(track_path)
	ROAD_CURVES = [curve]
	_init_noise()

	var trunk_len: float = curve.get_baked_length()
	print("  trunk length %.0fm" % trunk_len)
	_verify_plan(curve, trunk_len, "trunk")

	# 3. Feature ranges, measured off the curve so they follow it if the layout is retuned.
	_measure_feature_ranges(curve)

	# 4. Materials
	var concrete_tex: Texture2D = load("res://materials/concrete.png") as Texture2D
	var concrete_norm: Texture2D = load("res://materials/concrete_normal.png") as Texture2D
	var rock_tex: Texture2D = load("res://materials/dark_rock.png") as Texture2D
	var rock_norm: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D

	var road_mat := ShaderMaterial.new()
	road_mat.shader = load("res://ice_road.gdshader")
	if concrete_tex:
		road_mat.set_shader_parameter("grain_texture", concrete_tex)
	if concrete_norm:
		road_mat.set_shader_parameter("grain_normal", concrete_norm)
	road_mat.set_shader_parameter("trunk_width", MAIN_WIDTH)
	road_mat.set_shader_parameter("ramp_width", ROUTE_WIDTH)
	road_mat.set_shader_parameter("circuit_length", trunk_len)
	road_mat.set_shader_parameter("clear_zone", 30.0)
	road_mat.set_shader_parameter("aurora_amount", 0.14)

	var bank_mat := StandardMaterial3D.new()
	bank_mat.albedo_color = Color(0.87, 0.92, 1.00)
	bank_mat.roughness = 0.84
	bank_mat.metallic = 0.0
	bank_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	bank_mat.uv1_triplanar = true
	bank_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A whisper of emission: at night an unlit snowbank is just a black shape, and the stage is
	# meant to be readable without every metre of it having a lamp on it.
	bank_mat.emission_enabled = true
	bank_mat.emission = Color(0.26, 0.40, 0.52)
	bank_mat.emission_energy_multiplier = 0.10

	var under_mat := ShaderMaterial.new()
	under_mat.shader = load("res://glacier_ice.gdshader")
	under_mat.set_shader_parameter("vein_density", 0.15)
	under_mat.set_shader_parameter("vein_glow", 0.20)
	under_mat.set_shader_parameter("frost_line", 8.0)
	under_mat.set_shader_parameter("normal_strength", 0.22)
	if rock_tex:
		under_mat.set_shader_parameter("rock_albedo", rock_tex)
	if rock_norm:
		under_mat.set_shader_parameter("ice_normal", rock_norm)

	# The cavern's own walls: the brightest thing on the stage, because they are the only light
	# source in there.
	var ice_mat := ShaderMaterial.new()
	ice_mat.shader = load("res://glacier_ice.gdshader")
	ice_mat.set_shader_parameter("vein_density", 0.22)
	ice_mat.set_shader_parameter("vein_glow", 0.30)
	ice_mat.set_shader_parameter("ice_scale", 0.11)
	ice_mat.set_shader_parameter("normal_strength", 0.32)
	if rock_norm:
		ice_mat.set_shader_parameter("ice_normal", rock_norm)

	# The seracs and floes get their own, much quieter variant of the same shader. The cavern walls
	# are meant to glow - they are the only light source in there - but a snowfield littered with
	# glowing blocks reads as neon scenery rather than as ice catching the aurora.
	var serac_mat := ShaderMaterial.new()
	serac_mat.shader = load("res://glacier_ice.gdshader")
	serac_mat.set_shader_parameter("vein_density", 0.08)
	serac_mat.set_shader_parameter("vein_glow", 0.06)
	serac_mat.set_shader_parameter("ice_scale", 0.09)
	serac_mat.set_shader_parameter("frost_line", 26.0)
	serac_mat.set_shader_parameter("ice_color", Color(0.82, 0.91, 0.98))
	serac_mat.set_shader_parameter("deep_color", Color(0.30, 0.52, 0.70))
	serac_mat.set_shader_parameter("normal_strength", 0.30)
	if rock_norm:
		serac_mat.set_shader_parameter("ice_normal", rock_norm)

	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://polar_night_ground.gdshader")
	ground_mat.set_shader_parameter("lake_center", LAKE_CENTER)
	ground_mat.set_shader_parameter("lake_radius", LAKE_RADIUS)
	ground_mat.set_shader_parameter("lake_feather", LAKE_FEATHER)
	ground_mat.set_shader_parameter("aurora_amount", 0.09)
	if rock_tex:
		ground_mat.set_shader_parameter("rock_albedo", rock_tex)
	if rock_norm:
		ground_mat.set_shader_parameter("rock_normal", rock_norm)

	# 5. Alternative routes
	#
	# Every route starts and ends as a nose sitting exactly on the trunk deck edge, with its
	# handles aligned to the trunk tangent, so a route can never overlap the trunk deck or leave
	# a seam across it. The curves are built BEFORE the road meshes because the trunk bank gaps
	# are derived from where each route actually runs alongside the trunk.
	var alt_container := Node3D.new()
	alt_container.name = "AlternativePaths"
	level_scene.add_child(alt_container)

	# --- ROUTE 1: Meltwater Cut (splits right, a frozen channel sunk below the icefield) ---
	var alt1_path := Path3D.new()
	alt1_path.name = "AlternativePath_MeltwaterCut"
	# The waypoints are the trunk's own corners offset to the right by about 30m, so the route
	# shadows the trunk the whole way instead of trying to cut across it. A route that crosses
	# the trunk anywhere but its two noses is not a shortcut, it is a second junction - and the
	# _verify_route_vs_trunk check below fails the build on one.
	# The waypoints run south in z, the same way the trunk does out of the split. They used to sit
	# north of the auto-generated entry waypoint, which made the route double back on itself and
	# fold its own deck - _verify_min_radius caught it at R=6m, which is why the ordering matters
	# and not just the offsets.
	var alt1_curve := _build_route_curve(Vector3(-100.0, 2.85, 40.0), Vector3(-17.0, 2.62, -93.0), 1, [
		Vector3(-62.0, 1.95, 8.0),     # dropping off the shelf into the channel
		Vector3(-44.0, 1.35, -32.0),    # channel floor, running parallel to the trunk
	])
	alt1_path.curve = alt1_curve
	alt_container.add_child(alt1_path)

	# --- ROUTE 2: Serac Ledge (splits left, a narrow shelf between ice towers) ---
	var alt2_path := Path3D.new()
	alt2_path.name = "AlternativePath_SeracLedge"
	var alt2_curve := _build_route_curve(Vector3(92.0, 4.70, -382.0), Vector3(200.0, 10.00, -166.0), -1, [
		Vector3(232.0, 7.60, -330.0),  # out onto the ledge
		Vector3(250.0, 9.60, -260.0),  # between the seracs, high above the shelf
	])
	alt2_path.curve = alt2_curve
	alt_container.add_child(alt2_path)

	var routes: Array = [[alt1_curve, 1, "MeltwaterCut"], [alt2_curve, -1, "SeracLedge"]]
	for entry in routes:
		var rc: Curve3D = entry[0]
		var min_lat: float = _min_route_lateral(rc)
		if min_lat < MAIN_HALF_W - 0.5:
			push_error("%s dips to %.2fm from the trunk centreline (needs >= %.2f)" % [entry[2], min_lat, MAIN_HALF_W - 0.5])
		_verify_min_radius(rc, ROUTE_HALF_W, entry[2])
		_verify_plan(rc, rc.get_baked_length(), entry[2])
		_verify_route_vs_trunk(rc, entry[2])

	# 6. Trunk deck and banks
	#
	# The bank gaps are measured off the route geometry: the trunk bank is only open while a
	# route deck actually runs alongside the trunk deck, which is exactly the gore.
	var main_left_gaps: Array = []
	var main_right_gaps: Array = []
	for entry in routes:
		var spans: Array = _junction_gap_intervals(entry[0], ROUTE_HALF_W, MAIN_HALF_W)
		if entry[1] > 0:
			main_right_gaps.append_array(spans)
		else:
			main_left_gaps.append_array(spans)
	main_left_gaps = _merge_intervals(main_left_gaps)
	main_right_gaps = _merge_intervals(main_right_gaps)
	print("  trunk bank gaps - left: %s  right: %s" % [main_left_gaps, main_right_gaps])

	# NOTE the explicit gap arguments: without them the trunk gets no bank gaps at all and every
	# route entrance is walled off. _verify_gaps below fails the build if so.
	_build_road_mesh(level_scene, curve, MAIN_WIDTH, "MainIceRoad", road_mat, bank_mat, under_mat,
			0, 0.0, main_left_gaps, main_right_gaps, _bridge_range)
	_verify_gaps(routes, main_left_gaps, main_right_gaps)

	# 7. Route decks (tiled against the trunk shoulder, gore bank only where they separate)
	_build_road_mesh(level_scene, alt1_curve, ROUTE_WIDTH, "MeltwaterCutRoad", road_mat, bank_mat, under_mat,
			1, MAIN_HALF_W, [], [], Vector2(-1.0, -1.0))
	_build_road_mesh(level_scene, alt2_curve, ROUTE_WIDTH, "SeracLedgeRoad", road_mat, bank_mat, under_mat,
			-1, MAIN_HALF_W, [], [], Vector2(-1.0, -1.0))

	# 8. The glacier cavern
	var cavern_container := Node3D.new()
	cavern_container.name = "Cavern"
	level_scene.add_child(cavern_container)
	_build_cavern(cavern_container, ice_mat, Color(0.62, 0.84, 1.0))

	# 9. Terrain: the icefield has to know where every carriageway runs, so this is built after
	#    the roads exist and after the crevasse is known.
	ROAD_CURVES.append(alt1_curve)
	ROAD_CURVES.append(alt2_curve)
	_build_road_index()
	var terrain_container := Node3D.new()
	terrain_container.name = "TerrainEnvironment"
	level_scene.add_child(terrain_container)
	_build_icefield(terrain_container, ground_mat)
	_build_cavern_cap(cavern_container, ground_mat)

	# 10. Finish line & starting grid
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
		Vector3(-2.9, 0.05, 5.0),
		Vector3(2.9, 0.05, 5.0),
		Vector3(-2.9, 0.05, 12.5),
		Vector3(2.9, 0.05, 12.5),
		Vector3(-2.9, 0.05, 20.0),
		Vector3(2.9, 0.05, 20.0)
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

	# 11. Checkpoints. Placed by fraction of the lap rather than by hand-picked coordinates, so
	#     they stay spread out and in order of travel however the layout is retuned.
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)

	var cp_fractions := [0.11, 0.24, 0.47, 0.70, 0.87]
	for i in range(cp_fractions.size()):
		var dist_along: float = float(cp_fractions[i]) * trunk_len
		var cp_pos := curve.sample_baked(dist_along)
		var next_pos := curve.sample_baked(minf(trunk_len, dist_along + 1.0))
		var forward := (next_pos - cp_pos).normalized()
		var rot_y := rad_to_deg(atan2(-forward.x, -forward.z))
		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = cp_pos + Vector3(0, 0.1, 0)
		gate.rotation_degrees = Vector3(0, rot_y, 0)
		checkpoints_container.add_child(gate)
		print("  checkpoint %d at %.0fm (%.0f%%)" % [i + 1, dist_along, cp_fractions[i] * 100.0])

	# 12. Boost pads, placed on the curves rather than as world coordinates.
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)

	if boost_scene:
		# [label, curve, distance along, lateral, height]
		var bp_defs = [
			["Boost_Lake_L", curve, 0.06 * trunk_len, -4.6, 0.1],
			["Boost_Lake_R", curve, 0.06 * trunk_len, 4.6, 0.1],
			["Boost_Shore", curve, 0.20 * trunk_len, 0.0, 0.1],
			["Boost_Cavern_Entry", curve, _cavern_range.x - 40.0, 3.8, 0.1],
			["Boost_Cavern_Mid", curve, (_cavern_range.x + _cavern_range.y) * 0.5, -4.2, 0.1],
			["Boost_Arch", curve, (_bridge_range.x + _bridge_range.y) * 0.5, 4.4, 0.1],
			["Boost_Shelf_Exit", curve, 0.68 * trunk_len, -4.4, 0.1],
			["Boost_Home_Run", curve, 0.84 * trunk_len, 3.0, 0.1],
			# Route rewards: one on the channel floor, one at the top of the ledge.
			["Boost_Meltwater", alt1_curve, alt1_curve.get_baked_length() * 0.5, 0.0, 0.1],
			["Boost_Meltwater_Exit", alt1_curve, alt1_curve.get_baked_length() - 22.0, 0.0, 0.1],
			["Boost_SeracLedge", alt2_curve, alt2_curve.get_baked_length() * 0.55, 0.0, 0.1],
		]
		for bp_info in bp_defs:
			var bp = boost_scene.instantiate()
			bp.name = bp_info[0]
			var spot: Dictionary = _point_on(bp_info[1], bp_info[2], bp_info[3], bp_info[4])
			bp.position = spot["pos"]
			bp.rotation_degrees = Vector3(0, spot["yaw"], 0)
			boost_container.add_child(bp)

	# 13. Item boxes. Rows on the fast lines and one hidden cache down in the meltwater channel.
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	level_scene.add_child(item_container)

	if item_scene:
		# [curve, distance along, laterals]
		var item_rows = [
			[curve, 0.05 * trunk_len, [-5.2, 0.0, 5.2]],
			[curve, 0.19 * trunk_len, [-4.6, 0.0, 4.6]],
			[curve, _cavern_range.x - 70.0, [-4.0, 4.0]],
			[curve, _cavern_range.y + 45.0, [-4.0, 0.0, 4.0]],
			[curve, 0.62 * trunk_len, [-4.4, 4.4]],
			[curve, 0.80 * trunk_len, [-4.6, 0.0, 4.6]],
			[alt1_curve, alt1_curve.get_baked_length() * 0.45, [0.0]],
		]
		var item_idx := 1
		for row in item_rows:
			for lat in row[2]:
				var ib = item_scene.instantiate()
				ib.name = "ItemBox_%d" % item_idx
				var spot2: Dictionary = _point_on(row[0], row[1], lat, 1.4)
				ib.position = spot2["pos"]
				item_container.add_child(ib)
				item_idx += 1

	# 14. Trackside dressing
	var props_container := Node3D.new()
	props_container.name = "TracksideProps"
	level_scene.add_child(props_container)

	_build_edge_markers(props_container, curve, "Trunk", main_left_gaps, main_right_gaps, 40.0)
	_build_edge_markers(props_container, alt1_curve, "Meltwater", [], [], 40.0)
	_build_edge_markers(props_container, alt2_curve, "Ledge", [], [], 40.0)
	_build_ice_scatter(props_container, serac_mat)
	# Arch anchors are kept well clear of the route gores. An arch over a split is tempting as a
	# landmark, but the route climbs past the trunk's shoulder there, and the arch's soffit ends up
	# barely a metre over the route deck - a landmark you cannot drive under.
	_build_ice_arches(props_container, serac_mat, [
		[Vector3(-112.0, 3.0, 268.0), 13.0, 12.0, 2.2, 16.0],
		[Vector3(26.0, 3.30, -354.0), 12.0, 11.0, 2.0, 14.0],
	])
	_build_junction_pylons(props_container, serac_mat, routes)
	_build_crevasse_lights(props_container)
	_build_crevasse_water(props_container)
	# No jumbotron on this stage: it sits on the lake shore, where the lighting is flat and the
	# board reads as a floating black slab against the snow.

	# 15. Checkpoints & level wiring
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()

	# Split the big visual meshes into cells (collision shapes are separate and stay whole).
	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/" + RES_PREFIX, "res://generated/northlight_chunks", MESH_CHUNK_CELL)
	print("Chunked %d large meshes" % chunked)

	# 16. Scene ownership
	_set_owner_recursive(level_scene, level_scene)

	# 17. Save Packed Scene
	remove_child(level_scene)
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack %s: %d" % [LEVEL_PATH, pack_err])
		get_tree().quit(1)
		return

	var save_err = ResourceSaver.save(packed_scene, LEVEL_PATH)
	if save_err != OK:
		push_error("Failed to save %s: %d" % [LEVEL_PATH, save_err])
		get_tree().quit(1)
		return

	print("Successfully generated and saved %s!" % LEVEL_PATH)
	get_tree().quit(0)


## Measures the stretches where the terrain must be left alone, plus the cavern centreline the
## glacier ridge is raised along.
func _measure_feature_ranges(curve: Curve3D) -> void:
	var length: float = curve.get_baked_length()
	_cavern_range = Vector2(
		curve.get_closest_offset(Vector3(0.0, 0.0, -110.0)),
		curve.get_closest_offset(Vector3(0.0, 0.0, -300.0)))
	_cavern_portal_z = Vector2(
		curve.sample_baked(_cavern_range.x).z,
		curve.sample_baked(_cavern_range.y).z)

	# The crevasse bridge span: the stretch of trunk over the slot, widened by the abutments.
	var b_lo := -1.0
	var b_hi := -1.0
	var steps := int(length / 1.0)
	for i in range(steps + 1):
		var off: float = float(i)
		var p: Vector3 = curve.sample_baked(off)
		var slot: Vector2 = _crevasse_slot(p.x, p.z)
		if slot.y < 1.0 and absf(slot.x) < 1.0:
			if b_lo < 0.0:
				b_lo = off
			b_hi = off
	if b_lo < 0.0:
		push_error("No trunk stretch crosses the crevasse - the ice arch would have nothing to span")
		_bridge_range = Vector2(-1.0, -1.0)
	else:
		_bridge_range = Vector2(maxf(b_lo - CREVASSE_ABUTMENT, 0.0), minf(b_hi + CREVASSE_ABUTMENT, length))
	print("  cavern portals at %.0fm and %.0fm (%.0fm long)" % [
		_cavern_range.x, _cavern_range.y, _cavern_range.y - _cavern_range.x])
	print("  crevasse bridge span %.0fm to %.0fm (%.0fm)" % [
		_bridge_range.x, _bridge_range.y, _bridge_range.y - _bridge_range.x])

	# Frozen lake stretches: the trunk over the lake plate, where the corridor is switched off.
	var spans: Array = []
	var run_start := -1.0
	for i in range(steps + 1):
		var off2: float = float(i)
		var p2: Vector3 = curve.sample_baked(off2)
		var over_lake: bool = (Vector2(p2.x, p2.z) - LAKE_CENTER).length() / LAKE_RADIUS.x < 1.0
		if over_lake:
			if run_start < 0.0:
				run_start = off2
		elif run_start >= 0.0:
			spans.append(Vector2(run_start, off2 - 1.0))
			run_start = -1.0
	if run_start >= 0.0:
		spans.append(Vector2(run_start, length))
	print("  frozen lake stretches: %s" % [spans])

	# Cavern centreline for the glacier ridge, extended well past both portals so the ridge's
	# along-strip can be evaluated (and extrapolated) for terrain outside the passage.
	_cavern_line = PackedVector2Array()
	_cavern_off = PackedFloat32Array()
	var lo: float = maxf(_cavern_range.x - 150.0, 0.0)
	var hi: float = minf(_cavern_range.y + 150.0, length)
	var n: int = int((hi - lo) / 10.0) + 1
	for i in range(n + 1):
		var off3: float = minf(lo + float(i) * 10.0, length)
		var p3: Vector3 = curve.sample_baked(off3)
		_cavern_line.append(Vector2(p3.x, p3.z))
		_cavern_off.append(off3)

	# The deck profile the terrain audit measures the gallery floor against.
	_cavern_zs = PackedFloat32Array()
	_cavern_ys = PackedFloat32Array()
	var m: int = int((_cavern_range.y - _cavern_range.x) / 4.0) + 1
	for i in range(m + 1):
		var off4: float = clampf(_cavern_range.x + float(i) * 4.0, 0.0, length)
		var p4: Vector3 = curve.sample_baked(off4)
		_cavern_zs.append(p4.z)
		_cavern_ys.append(p4.y)

	# The cavern does not need to be on this list: corridor grading switches off over the massif
	# spatially, in _inside_cavern_mass, so no road sample can reach in and cut a gallery into it.
	# What is here is the crevasse span (open sky underneath the arch) and the frozen lake (the
	# road is scraped into the ice, not built on it).
	_no_grade = {
		0: _merge_intervals(
			[_bridge_range if _bridge_range.y > _bridge_range.x else Vector2(-1.0, -1.0)] + spans)
	}
