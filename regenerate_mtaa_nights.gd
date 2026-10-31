# regenerate_mtaa_nights.gd
#
# Builds levels/MtaaNightsLevel.tscn - the fourth stage of the Matumaini GP: an evening race through a
# city district of Nairobi's kind (all of it made up): a busy avenue, a market street, red murram back
# roads through an estate, a pocket park, and Club Kilele, an open-air club whose grounds the lap runs
# through, across its LED dancefloor under the light show.
#
# The lap (clockwise from above; x east, z south): the start on Kilele Avenue heading east, south down
# Biashara Street (the market), west along Mtaa Road (tarmac, then murram through the estate), south on
# the park's path, west along Mwangaza Road into the club, across the dancefloor, north out of the club's
# north gate up Kanisa Road (murram, past the church), and back onto the avenue.
#
# Three forks, each a choice between paved and loose (AlternativePaths, which the AI takes too):
#   - Biashara Street (tarmac, longer) or the jua kali alley (murram, a zigzag through the workshops,
#     whoops and a plank table-top);
#   - the park's paved path (round two sides of the park) or straight over the lawn (off-road grass, a
#     mound to jump);
#   - the club lane over the dancefloor or the backstage road behind the stage (gravel, a loading-ramp
#     kicker).
# The loose routes are 75-92% as long as the paved ones: an off-road car takes them, a road car stays
# on the tarmac. The trunk itself is about two parts tarmac to one of murram, so neither kind of car has
# the lap to itself (see CLAUDE.md, "Mtaa Nights").
#
# Things worth knowing before editing this file:
#
# 1. Every road is a path of straights and circular arcs (`_fillet`: corner points and radii). The main
#    lap is closed; the forks are open paths that start and end lying exactly on the lap. Everything is
#    placed by (path, s).
#
# 2. There is no road mesh. The ground is one heightfield (GRID metres) built in tiles, flat at y = 0
#    except where a road's profile has bumps. Each vertex carries the distance to the nearest road's edge
#    (a smooth minimum, so junction corners are round), the lateral and the distance along that road,
#    and the surface and zone masks; mtaa_ground.gdshader paints the roads from those. Its collision is
#    split by what each triangle is: AsphaltRoad, MurramRoad, GravelRoad and DanceDeck count as track
#    ("road"/"deck" in the name), CityPaving, ClubPaving, ParkLawn and BareEarth are off-road.
#
# 3. The city's buildings fill every cell of the grid that is neither road, pavement nor one of the
#    open places (the park, the club, the dancefloor): greedy rectangles, so the blocks are solid and
#    nobody can sneak through behind a facade. They are city_building.gdshader (Nyota's facades) with
#    its evening lights on (`lit_share`).
extends Node

const LEVEL_NAME := "MtaaNightsLevel"
const LEVEL_PATH := "res://levels/MtaaNightsLevel.tscn"
const RES_PREFIX := "mtaa_"
const Nyota = preload("res://regenerate_nyota_stadium.gd")
const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")
const MatatuKit = preload("res://MatatuKit.gd")
const StreetLampKit = preload("res://StreetLampKit.gd")
const FoodTruckKit = preload("res://FoodTruckKit.gd")
const MarketStallKit = preload("res://MarketStallKit.gd")
const RoadsideKit = preload("res://RoadsideKit.gd")
const CrowdPlacer = preload("res://CrowdPlacer.gd")

## The ground's grid (metres) and its tiles (in cells); the detailed ground's extent.
const GRID := 2.0
const TILE := 32
const GROUND_MIN := Vector2(-620.0, -480.0)
const GROUND_MAX := Vector2(360.0, 400.0)
## Road samples for the nearest-road lookups: spacing and hash cell.
const SAMPLE_STEP := 1.0
const HASH_CELL := 12.0
## How far a vertex looks for roads.
const REACH := 34.0
## Junction corners round over this (the smooth minimum's k).
const JUNCTION_ROUND := 7.0
## The ground eases from a road's height back to the city's over this.
const GRADE := 6.0

## Surface kinds along a road.
enum { K_ASPHALT, K_MURRAM, K_GRAVEL }
## What a ground triangle is (its collision body).
enum { B_ASPHALT, B_MURRAM, B_GRAVEL, B_DECK, B_PAVING, B_CLUB, B_LAWN, B_EARTH }
const BODIES := [
	["AsphaltRoad", "asphalt"], ["MurramRoad", "dirt"], ["GravelRoad", "gravel"], ["DanceDeck", "asphalt"],
	["CityPaving", "asphalt"], ["ClubPaving", "asphalt"], ["ParkLawn", "grass"], ["BareEarth", "dirt"],
]
const MURRAM_DUST := Color(0.80, 0.44, 0.28, 0.75)

## Half widths.
const AVENUE_HALF := 8.0
const STREET_HALF := 7.0
const ALLEY_HALF := 7.0
const LAWN_HALF := 7.0

## The main lap: corner points and radii, from a point on Kilele Avenue (a straight corner) round
## clockwise. s = 0 at the first point.
const MAIN := [
	[Vector2(-170.0, -250.0), 0.0],
	[Vector2(150.0, -250.0), 26.0],    # onto Biashara Street, south
	[Vector2(150.0, -40.0), 22.0],     # onto Mtaa Road, west
	[Vector2(-120.0, -40.0), 20.0],    # into the park, south
	[Vector2(-120.0, 150.0), 22.0],    # onto Mwangaza Road, west, into the club
	[Vector2(-420.0, 150.0), 24.0],    # out of the club, north up Kanisa Road
	[Vector2(-420.0, -250.0), 30.0],   # back onto the avenue, east
]
## The forks: start and end on the lap, corners between.
## The alley's corners are as tight as a bot coming off the avenue at 40 m/s can take: at 12m it ran
## straight on past the entry.
const YARD := [
	[Vector2(0.0, -250.0), 0.0], [Vector2(60.0, -250.0), 24.0], [Vector2(60.0, -170.0), 16.0],
	[Vector2(105.0, -170.0), 16.0], [Vector2(105.0, -100.0), 16.0], [Vector2(60.0, -100.0), 16.0],
	[Vector2(60.0, -40.0), 18.0], [Vector2(20.0, -40.0), 0.0],
]
const LAWN := [
	[Vector2(-120.0, -10.0), 0.0], [Vector2(-120.0, 15.0), 16.0], [Vector2(-170.0, 60.0), 20.0],
	[Vector2(-170.0, 150.0), 14.0], [Vector2(-200.0, 150.0), 0.0],
]
const BACKSTAGE := [
	[Vector2(-240.0, 150.0), 0.0], [Vector2(-272.0, 150.0), 12.0], [Vector2(-272.0, 112.0), 12.0],
	[Vector2(-310.0, 80.0), 12.0], [Vector2(-420.0, 80.0), 14.0], [Vector2(-420.0, 40.0), 0.0],
]
## Side streets that only dress the city, closed off with barriers where they meet the race: [from, to,
## half width, surface].
const SIDE_STREETS := [
	[Vector2(-300.0, -258.0), Vector2(-300.0, -760.0), 6.5, K_ASPHALT],
	[Vector2(-60.0, -258.0), Vector2(-60.0, -760.0), 6.5, K_ASPHALT],
	[Vector2(90.0, -258.0), Vector2(90.0, -760.0), 6.5, K_ASPHALT],
	[Vector2(-50.0, -242.0), Vector2(-50.0, -47.0), 6.0, K_ASPHALT],
	[Vector2(157.0, -150.0), Vector2(760.0, -150.0), 6.5, K_ASPHALT],
	[Vector2(-427.0, -130.0), Vector2(-960.0, -130.0), 6.5, K_MURRAM],
	[Vector2(-413.0, -130.0), Vector2(-215.0, -130.0), 6.0, K_MURRAM],
	[Vector2(40.0, -33.0), Vector2(40.0, 320.0), 6.0, K_MURRAM],
	[Vector2(-760.0, -560.0), Vector2(760.0, -560.0), 7.0, K_ASPHALT],
	[Vector2(380.0, -760.0), Vector2(380.0, 700.0), 7.0, K_ASPHALT],
	[Vector2(-760.0, 320.0), Vector2(760.0, 320.0), 7.0, K_ASPHALT],
	[Vector2(-560.0, -760.0), Vector2(-560.0, 700.0), 7.0, K_ASPHALT],
]

## The open places: no buildings, their own ground.
const PARK := Rect2(-232.0, -25.0, 104.0, 167.0)
const CLUB := Rect2(-448.0, -25.0, 198.0, 240.0)
const DANCEFLOOR := Rect2(-372.0, 132.0, 60.0, 36.0)
const STAGE := Rect2(-372.0, 96.0, 60.0, 28.0)
const WORKSHOPS := Rect2(28.0, -238.0, 100.0, 186.0)
const CHURCH := Rect2(-406.0, -205.0, 42.0, 62.0)
const FOUNTAIN := Vector2(-205.0, 20.0)

const FINISH_S := 30.0

## The cart's gravity (PlayerCart.GRAVITY plus the engine's), for the jump checks.
const G := 39.8

var _paths: Array = []
var _main: Dictionary
var _alts: Array = []
## Flat samples of every path for the nearest-road lookups.
var _sx := PackedFloat32Array()
var _sz := PackedFloat32Array()
var _ss := PackedFloat32Array()
var _sfx := PackedFloat32Array()
var _sfz := PackedFloat32Array()
var _sp := PackedInt32Array()
var _hash := {}
## Street lamps (position of the pole's foot, the arm's direction) and the lamplight pool's hash.
var _lamps: Array = []
var _lamp_hash := {}
## The ground grid's per-vertex data.
var _nx := 0
var _nz := 0
var _edge := PackedFloat32Array()
var _height := PackedFloat32Array()
var _kind := PackedInt32Array()
var _near_path := PackedInt32Array()
## Building occupancy per ground cell (index of the building, -1 free, -2 kept open).
var _occ := PackedInt32Array()
## Footprints (Rect2 in x, z) the dressing has already used, so props keep off each other.
var _used: Array = []
var _mats := {}


# ======================================================================================
#  Paths: straights and arcs
# ======================================================================================

static func _right_of(th: float) -> Vector2:
	return Vector2(-sin(th), cos(th))


static func _dir_of(th: float) -> Vector2:
	return Vector2(cos(th), sin(th))


## A path through `corners` ([point, radius]): straights joined by arcs of each corner's radius.
## Closed: s = 0 at the first corner's end. Open: from the first point to the last.
func _fillet(path_name: String, corners: Array, closed: bool, half: float) -> Dictionary:
	var n: int = corners.size()
	var a_in: Array = []
	var a_out: Array = []
	var arcs: Array = []
	for i in range(n):
		var b: Vector2 = corners[i][0]
		var r: float = corners[i][1]
		if not closed and (i == 0 or i == n - 1):
			a_in.append(b)
			a_out.append(b)
			arcs.append(null)
			continue
		var a: Vector2 = corners[(i - 1 + n) % n][0]
		var c: Vector2 = corners[(i + 1) % n][0]
		var d1: Vector2 = (b - a).normalized()
		var d2: Vector2 = (c - b).normalized()
		var ang: float = atan2(d1.x * d2.y - d1.y * d2.x, d1.dot(d2))
		var t: float = r * tan(absf(ang) * 0.5)
		if t > b.distance_to(a) * 0.5 + 0.01 or t > b.distance_to(c) * 0.5 + 0.01:
			push_error("%s: corner %d's radius %.0f does not fit" % [path_name, i, r])
		a_in.append(b - d1 * t)
		a_out.append(b + d2 * t)
		if absf(ang) < 0.0001 or r <= 0.0:
			arcs.append(null)
		else:
			arcs.append({"kind": "A", "p0": b - d1 * t, "th0": atan2(d1.y, d1.x), "r": r, "sign": signf(ang), "len": r * absf(ang)})
	var segs: Array = []
	var s := 0.0
	var order: Array = range(n) if not closed else range(1, n + 1)
	var prev: Vector2 = a_out[0]
	for k in order:
		var i: int = k % n
		var p_in: Vector2 = a_in[i]
		var length: float = prev.distance_to(p_in)
		if length > 0.001:
			var d: Vector2 = (p_in - prev) / length
			segs.append({"kind": "S", "p0": prev, "th0": atan2(d.y, d.x), "len": length, "s0": s})
			s += length
		if arcs[i] != null and (closed or (i > 0 and i < n - 1)):
			var arc: Dictionary = (arcs[i] as Dictionary).duplicate()
			arc["s0"] = s
			segs.append(arc)
			s += float(arc["len"])
		prev = a_out[i]
	return {"name": path_name, "closed": closed, "segs": segs, "len": s, "half": half, "kinds": [], "bumps": [], "marks": true, "halves": []}


## Position, heading and signed curvature (+ turning right) on `path` at s.
func _at(path: Dictionary, s: float) -> Dictionary:
	var length: float = path["len"]
	s = fposmod(s, length) if path["closed"] else clampf(s, 0.0, length)
	var segs: Array = path["segs"]
	var seg: Dictionary = segs[0]
	for i in range(segs.size() - 1, -1, -1):
		if s >= float(segs[i]["s0"]) - 0.0001:
			seg = segs[i]
			break
	var d: float = s - float(seg["s0"])
	var p0: Vector2 = seg["p0"]
	var th0: float = seg["th0"]
	if seg["kind"] == "S":
		return {"p": p0 + _dir_of(th0) * d, "th": th0, "k": 0.0}
	var r: float = seg["r"]
	var sign: float = seg["sign"]
	var c: Vector2 = p0 + _right_of(th0) * r * sign
	var th: float = th0 + sign * d / r
	return {"p": c - _right_of(th) * r * sign, "th": th, "k": sign / r}


## The s on `path` nearest to `q` (a coarse walk, then a fine one).
func _s_near(path: Dictionary, q: Vector2) -> float:
	var length: float = path["len"]
	var best := 0.0
	var best_d := INF
	var s := 0.0
	while s <= length:
		var d: float = (_at(path, s)["p"] as Vector2).distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = s
		s += 2.0
	for step in [0.1, 0.005]:
		var around: float = best
		for k in range(-20, 21):
			var s2: float = around + float(k) * step
			var d2: float = (_at(path, s2)["p"] as Vector2).distance_squared_to(q)
			if d2 < best_d:
				best_d = d2
				best = s2
	return best


## The road's surface kind at s, as weights [murram, gravel] (blended over 8m at a change).
func _kind_w(path: Dictionary, s: float) -> Vector2:
	var w := Vector2.ZERO
	for k in path["kinds"]:
		var s0: float = k[0]
		var s1: float = k[1]
		var f: float = smoothstep(s0 - 4.0, s0 + 4.0, s) * (1.0 - smoothstep(s1 - 4.0, s1 + 4.0, s))
		if int(k[2]) == K_MURRAM:
			w.x = maxf(w.x, f)
		elif int(k[2]) == K_GRAVEL:
			w.y = maxf(w.y, f)
	return w


func _half(path: Dictionary, s: float) -> float:
	var h: float = path["half"]
	for hw in path["halves"]:
		var f: float = smoothstep(float(hw[0]) - 10.0, float(hw[0]) + 10.0, s) * (1.0 - smoothstep(float(hw[1]) - 10.0, float(hw[1]) + 10.0, s))
		h = lerpf(h, float(hw[2]), f)
	return h


## The road's height at s: the bumps on its profile ([s, length, height] cosine humps).
func _road_h(path: Dictionary, s: float) -> float:
	var h := 0.0
	for b in path["bumps"]:
		var x: float = (s - float(b[0])) / float(b[1])
		if absf(x) < 0.5:
			h += float(b[2]) * (0.5 + 0.5 * cos(x * TAU))
	return h


## A spot on `path`: the ground `lat` metres right of the centreline at s, and the yaw that faces along
## the path (a node's -z ahead).
func _spot(path: Dictionary, s: float, lat: float, lift := 0.0) -> Dictionary:
	var pa: Dictionary = _at(path, s)
	var p2: Vector2 = pa["p"]
	var r2: Vector2 = _right_of(float(pa["th"]))
	var f2: Vector2 = _dir_of(float(pa["th"]))
	var q: Vector2 = p2 + r2 * lat
	var pos := Vector3(q.x, _road_h(path, s) + lift, q.y)
	var fwd := Vector3(f2.x, 0.0, f2.y)
	return {"pos": pos, "yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)), "fwd": fwd, "right": Vector3(r2.x, 0.0, r2.y), "p2": q}


func _plan_paths() -> void:
	_paths.clear()
	_main = _fillet("Main", MAIN, true, STREET_HALF)
	_paths.append(_main)
	var yard := _fillet("JuaKaliShortcut", YARD, false, ALLEY_HALF)
	var lawn := _fillet("BustaniShortcut", LAWN, false, LAWN_HALF)
	var back := _fillet("BackstageShortcut", BACKSTAGE, false, ALLEY_HALF)
	_alts = [yard, lawn, back]
	_paths.append_array(_alts)
	# The avenue is wider than the other streets.
	_main["halves"] = [[-1000.0, _s_near(_main, Vector2(140.0, -250.0)), AVENUE_HALF],
			[_s_near(_main, Vector2(-420.0, -200.0)), _main["len"] + 1000.0, AVENUE_HALF]]
	# Murram on Mtaa Road through the estate and on Kanisa Road past the church.
	_main["kinds"] = [
		[_s_near(_main, Vector2(70.0, -40.0)), _s_near(_main, Vector2(-100.0, -40.0)), K_MURRAM],
		[_s_near(_main, Vector2(-420.0, -35.0)), _s_near(_main, Vector2(-420.0, -205.0)), K_MURRAM],
	]
	yard["kinds"] = [[_s_near(yard, Vector2(40.0, -250.0)), yard["len"] + 100.0, K_MURRAM]]
	yard["marks"] = false
	lawn["marks"] = false
	back["kinds"] = [[_s_near(back, Vector2(-262.0, 150.0)), _s_near(back, Vector2(-420.0, 70.0)), K_GRAVEL]]
	back["marks"] = false
	# Speed humps on Mtaa Road, whoops on Kanisa Road and in the alley, the lawn's mound.
	var mtaa0: float = _s_near(_main, Vector2(0.0, -40.0))
	var mtaa1: float = _s_near(_main, Vector2(-70.0, -40.0))
	_main["bumps"] = [[mtaa0, 7.0, 0.35], [mtaa1, 7.0, 0.35]]
	var w0: float = _s_near(_main, Vector2(-420.0, -95.0))
	for k in range(5):
		_main["bumps"].append([w0 + float(k) * 10.0, 8.0, 0.5])
	var yw: float = _s_near(yard, Vector2(60.0, -88.0))
	for k in range(4):
		yard["bumps"].append([yw + float(k) * 9.0, 7.0, 0.45])
	lawn["bumps"] = [[_s_near(lawn, Vector2(-150.0, 42.0)), 30.0, 2.2]]
	for path in _paths:
		print("  %s: %.0fm" % [path["name"], path["len"]])
	# The side streets.
	for sd in SIDE_STREETS:
		var p := _fillet("Side", [[sd[0], 0.0], [sd[1], 0.0]], false, float(sd[2]))
		p["side"] = true
		if int(sd[3]) != K_ASPHALT:
			p["kinds"] = [[-100.0, float(p["len"]) + 100.0, int(sd[3])]]
			p["marks"] = false
		_paths.append(p)


## Lengths of each fork's two routes, printed; errors if a loose route isn't the shorter.
func _verify_forks() -> void:
	for alt in _alts:
		var a: Dictionary = alt
		var p0: Vector2 = _at(a, 0.0)["p"]
		var p1: Vector2 = _at(a, a["len"])["p"]
		var s0: float = _s_near(_main, p0)
		var s1: float = _s_near(_main, p1)
		var main_len: float = fposmod(s1 - s0, _main["len"])
		var ratio: float = float(a["len"]) / main_len
		print("  fork %s: %.0fm against the lap's %.0fm (%.2f)" % [a["name"], a["len"], main_len, ratio])
		if ratio > 0.97 or ratio < 0.6:
			push_error("%s is %.2f of the lap it bypasses" % [a["name"], ratio])
		if p0.distance_to(_at(_main, s0)["p"]) > 0.15 or p1.distance_to(_at(_main, s1)["p"]) > 0.15:
			push_error("%s does not start and end on the lap: %.2fm and %.2fm off (s %.1f, %.1f)" % [a["name"], p0.distance_to(_at(_main, s0)["p"]), p1.distance_to(_at(_main, s1)["p"]), s0, s1])
	# Loose and paved metres on the lap itself (outside the forks).
	var paved := 0.0
	var loose := 0.0
	var s := 0.0
	while s < float(_main["len"]):
		var bypassed := false
		for alt in _alts:
			var s0: float = _s_near(_main, _at(alt, 0.0)["p"])
			var s1: float = _s_near(_main, _at(alt, alt["len"])["p"])
			if s >= s0 and s <= s1:
				bypassed = true
		if not bypassed:
			var w: Vector2 = _kind_w(_main, s)
			loose += maxf(w.x, w.y)
			paved += 1.0 - maxf(w.x, w.y)
		s += 1.0
	print("  the lap outside the forks: %.0fm paved, %.0fm murram (%.2f : 1)" % [paved, loose, paved / maxf(loose, 1.0)])


# ======================================================================================
#  Nearest-road lookups
# ======================================================================================

func _index_paths() -> void:
	_sx.clear()
	_sz.clear()
	_ss.clear()
	_sfx.clear()
	_sfz.clear()
	_sp.clear()
	_hash.clear()
	for pi in range(_paths.size()):
		var path: Dictionary = _paths[pi]
		var length: float = path["len"]
		var n: int = maxi(1, int(ceil(length / SAMPLE_STEP)))
		for i in range(n + (0 if path["closed"] else 1)):
			var s: float = length * float(i) / float(n)
			var pa: Dictionary = _at(path, s)
			var p: Vector2 = pa["p"]
			var f: Vector2 = _dir_of(float(pa["th"]))
			var idx: int = _sx.size()
			_sx.append(p.x)
			_sz.append(p.y)
			_ss.append(s)
			_sfx.append(f.x)
			_sfz.append(f.y)
			_sp.append(pi)
			var key := Vector2i(floori(p.x / HASH_CELL), floori(p.y / HASH_CELL))
			if not _hash.has(key):
				_hash[key] = PackedInt32Array()
			var arr: PackedInt32Array = _hash[key]
			arr.append(idx)
			_hash[key] = arr


## Every path within `reach` of q: [{path, s, lat, edge, point}], nearest edge first.
func _roads_near(q: Vector2, reach := REACH) -> Array:
	var best := {}
	var r: int = int(ceil(reach / HASH_CELL))
	var cx: int = floori(q.x / HASH_CELL)
	var cz: int = floori(q.y / HASH_CELL)
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var key := Vector2i(cx + dx, cz + dz)
			if not _hash.has(key):
				continue
			for idx in (_hash[key] as PackedInt32Array):
				var ddx: float = q.x - _sx[idx]
				var ddz: float = q.y - _sz[idx]
				var d2: float = ddx * ddx + ddz * ddz
				var pi: int = _sp[idx]
				if not best.has(pi) or d2 < float(best[pi][0]):
					best[pi] = [d2, idx]
	var out: Array = []
	for pi in best:
		var idx: int = best[pi][1]
		var path: Dictionary = _paths[pi]
		var fx: float = _sfx[idx]
		var fz: float = _sfz[idx]
		var ddx: float = q.x - _sx[idx]
		var ddz: float = q.y - _sz[idx]
		var along: float = ddx * fx + ddz * fz
		var lat: float = ddx * -fz + ddz * fx
		var s: float = _ss[idx] + along
		var length: float = path["len"]
		var half: float = _half(path, s)
		var edge: float = absf(lat) - half
		if not path["closed"]:
			if s < 0.0:
				edge = maxf(edge, -s)
			elif s > length:
				edge = maxf(edge, s - length)
			s = clampf(s, 0.0, length)
		else:
			s = fposmod(s, length)
		if edge > reach:
			continue
		out.append({"path": pi, "s": s, "lat": lat, "edge": edge, "point": Vector2(_sx[idx], _sz[idx]) + Vector2(fx, fz) * along, "half": half})
	out.sort_custom(func(a, b): return float(a["edge"]) < float(b["edge"]))
	return out


## The distance to the nearest road edge with junction corners rounded: a smooth minimum over roads
## that are really different (where a fork lies on the lap, the two are the same road).
func _edge_of(roads: Array) -> float:
	if roads.is_empty():
		return REACH
	var e: float = roads[0]["edge"]
	var p0: Vector2 = roads[0]["point"]
	for k in range(1, mini(roads.size(), 4)):
		var b: float = roads[k]["edge"]
		if (roads[k]["point"] as Vector2).distance_to(p0) < 2.5 and absf(b - e) < 1.0:
			continue
		var h: float = maxf(JUNCTION_ROUND - absf(e - b), 0.0) / JUNCTION_ROUND
		e = minf(e, b) - h * h * JUNCTION_ROUND * 0.25
	return e


func _in_rect(r: Rect2, p: Vector2, grow := 0.0) -> bool:
	return r.grow(grow).has_point(p)


# ======================================================================================
#  Street lamps (planned first: the ground bakes a pool of light round each)
# ======================================================================================

const LAMP_SCALE := 1.35
## The luminaire's place on a lamp at LAMP_SCALE: along the arm and up.
const LAMP_REACH := 2.6
const LAMP_TOP := 11.9
const LAMP_POOL := 17.0
## Only lamps along the race carry a real light (the rest glow and pool on the ground).
const LAMP_LIGHT_RANGE := 26.0


## Lamps along every race path's paved stretches (and sparser along the murram), on alternating sides,
## kept off junction mouths and out of the club.
func _plan_lamps() -> void:
	_lamps.clear()
	var paths: Array = [_main]
	paths.append_array(_alts)
	for path in paths:
		var p: Dictionary = path
		if p == _alts[1]:
			continue
		var length: float = p["len"]
		var s := 8.0
		var side := 1.0
		while s < length - 4.0:
			var kw: Vector2 = _kind_w(p, s)
			var loose: bool = maxf(kw.x, kw.y) > 0.5
			var half: float = _half(p, s)
			var sp: Dictionary = _spot(p, s, side * (half + 1.3))
			var q: Vector2 = sp["p2"]
			var ok: bool = not _in_rect(CLUB, q, 2.0) and not _in_rect(PARK, q, -2.0)
			if ok:
				var roads: Array = _roads_near(q, 12.0)
				ok = _edge_of(roads) > 0.9
			if ok:
				for l in _lamps:
					if (l["p"] as Vector2).distance_to(q) < 16.0:
						ok = false
						break
			if ok:
				# The arm reaches back over the road.
				var rt: Vector3 = sp["right"]
				_lamps.append({"p": q, "arm": -Vector2(rt.x, rt.z) * side, "light": true})
			s += 52.0 if loose else 38.0
			side = -side
	# The park's own path lamps, both sides.
	var s0: float = _s_near(_main, Vector2(-120.0, -20.0))
	var s1: float = _s_near(_main, Vector2(-120.0, 125.0))
	var s := s0
	while s < s1:
		for side in [-1.0, 1.0]:
			var sp: Dictionary = _spot(_main, s, side * (STREET_HALF + 1.6))
			if _edge_of(_roads_near(sp["p2"], 12.0)) > 0.9:
				var rt: Vector3 = sp["right"]
				_lamps.append({"p": sp["p2"], "arm": -Vector2(rt.x, rt.z) * side, "light": side > 0.0, "park": true})
		s += 34.0
	_lamp_hash.clear()
	for i in range(_lamps.size()):
		var lp: Vector2 = _lamp_pool_centre(_lamps[i])
		var key := Vector2i(floori(lp.x / 32.0), floori(lp.y / 32.0))
		if not _lamp_hash.has(key):
			_lamp_hash[key] = []
		_lamp_hash[key].append(i)
	print("  street lamps: %d" % _lamps.size())


func _lamp_pool_centre(l: Dictionary) -> Vector2:
	return (l["p"] as Vector2) + (l["arm"] as Vector2) * LAMP_REACH


func _lamp_light_at(q: Vector2) -> float:
	var cx: int = floori(q.x / 32.0)
	var cz: int = floori(q.y / 32.0)
	var sum := 0.0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not _lamp_hash.has(key):
				continue
			for i in _lamp_hash[key]:
				var d: float = _lamp_pool_centre(_lamps[i]).distance_to(q)
				if d < LAMP_POOL:
					var f: float = 1.0 - d / LAMP_POOL
					sum += f * f
	return clampf(sum, 0.0, 1.0)


# ======================================================================================
#  Ground data
# ======================================================================================

func _vi(ix: int, iz: int) -> int:
	return iz * _nx + ix


func _grid_pos(ix: int, iz: int) -> Vector2:
	return Vector2(GROUND_MIN.x + float(ix) * GRID, GROUND_MIN.y + float(iz) * GRID)


var _cols := PackedColorArray()
var _custom := PackedFloat32Array()
var _uv := PackedVector2Array()
var _uv2 := PackedVector2Array()


## Per vertex: the edge distance, height, what it is, and the shader's data.
func _compute_ground() -> void:
	_nx = int(round((GROUND_MAX.x - GROUND_MIN.x) / GRID)) + 1
	_nz = int(round((GROUND_MAX.y - GROUND_MIN.y) / GRID)) + 1
	var n: int = _nx * _nz
	_edge.resize(n)
	_height.resize(n)
	_kind.resize(n)
	_near_path.resize(n)
	_cols.resize(n)
	_custom.resize(n * 4)
	_uv.resize(n)
	_uv2.resize(n)
	var lawn: Dictionary = _alts[1]
	var lawn_i: int = _paths.find(lawn)
	var t0: int = Time.get_ticks_msec()
	for iz in range(_nz):
		for ix in range(_nx):
			var i: int = _vi(ix, iz)
			var q: Vector2 = _grid_pos(ix, iz)
			var all_roads: Array = _roads_near(q)
			# The lawn's route is grass, not a road: it only shapes the ground (its mound) and wears a trail.
			var roads: Array = all_roads.filter(func(r): return int(r["path"]) != lawn_i)
			var e: float = _edge_of(roads)
			var h := 0.0
			var murram := 0.0
			var gravel := 0.0
			var lat := 0.0
			var along := 0.0
			var marks := 0.0
			var half := STREET_HALF
			var pi := -1
			if not roads.is_empty():
				var r0: Dictionary = roads[0]
				pi = r0["path"]
				var path: Dictionary = _paths[pi]
				var s: float = r0["s"]
				var kw: Vector2 = _kind_w(path, s)
				murram = kw.x
				gravel = kw.y
				lat = r0["lat"]
				along = s
				half = r0["half"]
				h = _road_h(path, s) * (1.0 - smoothstep(0.3, GRADE, e))
				marks = 1.0 if path["marks"] else 0.0
				marks *= 1.0 - maxf(murram, gravel)
				# No lane lines where another road joins.
				var p0: Vector2 = r0["point"]
				for k in range(1, roads.size()):
					if (roads[k]["point"] as Vector2).distance_to(p0) < 2.5:
						continue
					marks *= smoothstep(2.0, 9.0, float(roads[k]["edge"]))
					break
			var trail := 0.0
			for r in all_roads:
				if int(r["path"]) == lawn_i:
					var ls: float = r["s"]
					var lh: float = _road_h(lawn, ls) * (1.0 - smoothstep(float(r["half"]), float(r["half"]) + 16.0, absf(float(r["lat"]))))
					h = maxf(h, lh)
					trail = (1.0 - smoothstep(1.5, 5.5, absf(absf(float(r["lat"])) - 2.2))) * 0.5
			var club: float = 1.0 if _in_rect(CLUB, q) else 0.0
			var in_park: bool = _in_rect(PARK, q)
			var grass: float = 1.0 if in_park else 0.0
			var earth: float = 0.0
			if _in_rect(WORKSHOPS, q):
				earth = 1.0
			if murram > 0.5 and e < 5.0:
				earth = maxf(earth, 1.0 - smoothstep(2.5, 5.0, e))
			earth = maxf(earth, trail * grass)
			if club > 0.5:
				marks = 0.0
			var kind: int
			if e <= 0.0:
				if _in_rect(DANCEFLOOR, q):
					kind = B_DECK
				elif gravel > 0.5:
					kind = B_GRAVEL
				elif murram > 0.5:
					kind = B_MURRAM
				else:
					kind = B_ASPHALT
			elif club > 0.5:
				kind = B_CLUB
			elif in_park:
				kind = B_LAWN
			elif earth > 0.5:
				kind = B_EARTH
			else:
				kind = B_PAVING
			_edge[i] = e
			_height[i] = h
			_kind[i] = kind
			_near_path[i] = pi
			_cols[i] = Color(murram, gravel, grass, earth)
			_custom[i * 4] = clampf(e, -40.0, 40.0)
			_custom[i * 4 + 1] = lat
			_custom[i * 4 + 2] = along
			_custom[i * 4 + 3] = marks
			_uv[i] = Vector2(club, half)
			_uv2[i] = Vector2(_lamp_light_at(q), 0.0)
	print("  ground data: %d x %d vertices in %.1fs" % [_nx, _nz, (Time.get_ticks_msec() - t0) / 1000.0])


## The ground's height under q (bilinear on the grid; the triangles split the same way as the mesh).
func _ground_y(q: Vector2) -> float:
	return _grid_lerp(_height, q)


func _edge_at(q: Vector2) -> float:
	return _grid_lerp(_edge, q)


## A per-vertex value at q, interpolated on the mesh's own triangles (the edge distance is linear across
## each one, so this is exact where a single road is nearest).
func _grid_lerp(data: PackedFloat32Array, q: Vector2) -> float:
	var fx: float = (q.x - GROUND_MIN.x) / GRID
	var fz: float = (q.y - GROUND_MIN.y) / GRID
	var ix: int = clampi(floori(fx), 0, _nx - 2)
	var iz: int = clampi(floori(fz), 0, _nz - 2)
	var u: float = clampf(fx - float(ix), 0.0, 1.0)
	var v: float = clampf(fz - float(iz), 0.0, 1.0)
	var h00: float = data[_vi(ix, iz)]
	var h10: float = data[_vi(ix + 1, iz)]
	var h01: float = data[_vi(ix, iz + 1)]
	var h11: float = data[_vi(ix + 1, iz + 1)]
	# Triangles (00, 10, 01) and (10, 11, 01).
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


# ======================================================================================
#  Buildings: where they stand
# ======================================================================================

enum { S_TOWER, S_MARKET, S_MID, S_ESTATE, S_SHED, S_WALL }
## Building rects: {r: Rect2, style, top, col, glass}.
var _buildings: Array = []


## How far back from a road's edge a building stands, by the road.
func _setback(path: Dictionary, s: float) -> float:
	if path.has("side"):
		return 4.0
	if path == _alts[0]:
		return 6.0
	if path == _alts[2]:
		return 4.0
	var kw: Vector2 = _kind_w(path, s)
	if kw.x > 0.5:
		return 7.5
	var p: Vector2 = _at(path, s)["p"]
	# Biashara Street's pavements hold the market.
	if p.x > 120.0 and p.y > -245.0 and p.y < -45.0:
		return 13.0
	return 6.5


func _style_at(q: Vector2) -> int:
	if _in_rect(WORKSHOPS, q):
		return S_SHED
	if q.y < -262.0 or (q.y < -200.0 and q.x < 170.0):
		return S_TOWER
	if q.x > 100.0 and q.y > -250.0 and q.y < -30.0:
		return S_MARKET
	# The estate: south of Mtaa Road, and either side of Kanisa Road.
	if (q.y > -40.0 and q.x > -120.0 and q.x < 160.0) or (q.x < -380.0 and q.y < -25.0 and q.y > -230.0) or (q.y > -200.0 and q.y < -40.0 and q.x < -60.0):
		return S_ESTATE
	return S_MID


## Marks each ground cell buildable or not, then covers the buildable ones with rectangles.
func _plan_buildings() -> void:
	var ncx: int = _nx - 1
	var ncz: int = _nz - 1
	_occ.resize(ncx * ncz)
	var open_rects: Array = [PARK.grow(2.0), CLUB.grow(2.0), CHURCH]
	for iz in range(ncz):
		for ix in range(ncx):
			var c: Vector2 = _grid_pos(ix, iz) + Vector2(GRID, GRID) * 0.5
			var e: float = (_edge[_vi(ix, iz)] + _edge[_vi(ix + 1, iz)] + _edge[_vi(ix, iz + 1)] + _edge[_vi(ix + 1, iz + 1)]) * 0.25
			var free := true
			for r in open_rects:
				if (r as Rect2).has_point(c):
					free = false
			if free and e < 14.0:
				var pi: int = _near_path[_vi(ix, iz)]
				if pi >= 0:
					var roads: Array = _roads_near(c, 20.0)
					for r in roads:
						var rp: Dictionary = _paths[int(r["path"])]
						if rp == _alts[1]:
							continue
						if float(r["edge"]) < _setback(rp, float(r["s"])):
							free = false
							break
				if e < 3.0:
					free = false
			# The ground's outermost ring stays open (the far city starts past it).
			if ix < 2 or iz < 2 or ix > ncx - 3 or iz > ncz - 3:
				free = false
			_occ[iz * ncx + ix] = -1 if free else -2
	# Greedy rectangles, sized by the style where each starts.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	_buildings.clear()
	for iz in range(ncz):
		for ix in range(ncx):
			if _occ[iz * ncx + ix] != -1:
				continue
			var c0: Vector2 = _grid_pos(ix, iz)
			var style: int = _style_at(c0)
			var size_r: Vector2
			match style:
				S_TOWER:
					size_r = Vector2(18.0, 34.0)
				S_MARKET:
					size_r = Vector2(12.0, 22.0)
				S_ESTATE:
					size_r = Vector2(8.0, 14.0)
				S_SHED:
					size_r = Vector2(10.0, 18.0)
				_:
					size_r = Vector2(16.0, 28.0)
			var tw: int = maxi(2, int(rng.randf_range(size_r.x, size_r.y) / GRID))
			var th: int = maxi(2, int(rng.randf_range(size_r.x, size_r.y) / GRID))
			var w := 0
			while w < tw and ix + w < ncx and _occ[iz * ncx + ix + w] == -1:
				w += 1
			var h := 1
			while h < th and iz + h < ncz:
				var row_ok := true
				for k in range(w):
					if _occ[(iz + h) * ncx + ix + k] != -1:
						row_ok = false
						break
				if not row_ok:
					break
				h += 1
			var bi: int = _buildings.size()
			for dz in range(h):
				for dx in range(w):
					_occ[(iz + dz) * ncx + ix + dx] = bi
			var rect := Rect2(c0, Vector2(float(w), float(h)) * GRID)
			# A strip a cell or two wide is a garden wall or a lean-to, not a building.
			var thin: bool = mini(w, h) <= 2
			var st: int = S_WALL if thin and style != S_SHED and style != S_ESTATE else style
			_buildings.append({"r": rect, "style": st})
	print("  buildings: %d" % _buildings.size())


# ======================================================================================
#  Ground mesh and collision
# ======================================================================================

func _ground_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://mtaa_ground.gdshader")
	m.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("dirt_tex", load("res://materials/dirt.png"))
	m.set_shader_parameter("dirt_normal", load("res://materials/dirt_normal.png"))
	m.set_shader_parameter("grass_tex", load("res://materials/grass.png"))
	m.set_shader_parameter("cobble_tex", load("res://materials/cobblestone.png"))
	return _save_res(m, "ground_mat") as ShaderMaterial


## The ground in TILE x TILE cell tiles (visual), and its collision in one body per kind. Cells under a
## building are left out of both (nobody sees or reaches them), and so are cells under the dancefloor's
## glass (it draws its own top; the collision stays, as DanceDeck).
func _build_ground(parent: Node3D) -> void:
	var mat := _ground_material()
	var ncx: int = _nx - 1
	var ncz: int = _nz - 1
	# Plain Arrays (references): a packed array held in an Array is a copy every time it's read.
	var faces: Array = []
	for k in range(BODIES.size()):
		faces.append([])
	var root := Node3D.new()
	root.name = "CityGround"
	parent.add_child(root)
	var tiles := 0
	var tris := 0
	var deck := DANCEFLOOR.grow(-0.01)
	for tz in range(0, ncz, TILE):
		for tx in range(0, ncx, TILE):
			var verts := PackedVector3Array()
			var normals := PackedVector3Array()
			var cols := PackedColorArray()
			var custom := PackedFloat32Array()
			var uvs := PackedVector2Array()
			var uv2s := PackedVector2Array()
			var idx := PackedInt32Array()
			var remap := {}
			for iz in range(tz, mini(tz + TILE, ncz)):
				for ix in range(tx, mini(tx + TILE, ncx)):
					var ci: int = iz * ncx + ix
					var under_building: bool = _occ[ci] >= 0
					var c: Vector2 = _grid_pos(ix, iz) + Vector2(GRID, GRID) * 0.5
					var a: int = _vi(ix, iz)
					var b: int = _vi(ix + 1, iz)
					var d: int = _vi(ix, iz + 1)
					var e: int = _vi(ix + 1, iz + 1)
					for tri in [[a, b, d], [b, e, d]]:
						var pa := _vpos(tri[0])
						var pb := _vpos(tri[1])
						var pc := _vpos(tri[2])
						if not under_building:
							var bk: int = _tri_kind(tri)
							var fl: Array = faces[bk]
							fl.append(pa)
							fl.append(pb)
							fl.append(pc)
						if under_building or deck.has_point(c):
							continue
						for v in tri:
							if not remap.has(v):
								remap[v] = verts.size()
								verts.append(_vpos(v))
								normals.append(_vnormal(v))
								cols.append(_cols[v])
								for k in range(4):
									custom.append(_custom[v * 4 + k])
								uvs.append(_uv[v])
								uv2s.append(_uv2[v])
						# Grid order a, b, d runs clockwise seen from above: a front face looking up.
						idx.append_array([remap[tri[0]], remap[tri[1]], remap[tri[2]]])
			if idx.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = verts
			arrays[Mesh.ARRAY_NORMAL] = normals
			arrays[Mesh.ARRAY_COLOR] = cols
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			arrays[Mesh.ARRAY_TEX_UV2] = uv2s
			arrays[Mesh.ARRAY_CUSTOM0] = custom
			arrays[Mesh.ARRAY_INDEX] = idx
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
					Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
			mesh.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.name = "GroundTile_%d_%d" % [tx / TILE, tz / TILE]
			mi.mesh = _save_res(mesh, "ground_%d_%d" % [tx / TILE, tz / TILE])
			root.add_child(mi)
			tiles += 1
			tris += idx.size() / 3
	for k in range(BODIES.size()):
		var f := PackedVector3Array(faces[k])
		if f.is_empty():
			continue
		var body := StaticBody3D.new()
		body.name = BODIES[k][0]
		body.set_meta(&"surface", BODIES[k][1])
		if k == B_MURRAM or k == B_EARTH:
			body.set_meta(&"dust_color", MURRAM_DUST)
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(f)
		shape.backface_collision = true
		var cs := CollisionShape3D.new()
		cs.name = BODIES[k][0] + "Shape"
		cs.shape = _save_res(shape, "collision_" + String(BODIES[k][0]).to_lower())
		body.add_child(cs)
		parent.add_child(body)
		print("    %s: %d triangles" % [BODIES[k][0], f.size() / 3])
	print("  ground: %d tiles, %d triangles" % [tiles, tris])


func _vpos(v: int) -> Vector3:
	var ix: int = v % _nx
	var iz: int = v / _nx
	var q: Vector2 = _grid_pos(ix, iz)
	return Vector3(q.x, _height[v], q.y)


func _vnormal(v: int) -> Vector3:
	var ix: int = v % _nx
	var iz: int = v / _nx
	var hl: float = _height[_vi(maxi(ix - 1, 0), iz)]
	var hr: float = _height[_vi(mini(ix + 1, _nx - 1), iz)]
	var hd: float = _height[_vi(ix, maxi(iz - 1, 0))]
	var hu: float = _height[_vi(ix, mini(iz + 1, _nz - 1))]
	return Vector3(-(hr - hl) / (2.0 * GRID), 1.0, -(hu - hd) / (2.0 * GRID)).normalized()


## A ground triangle's body: a road kind if it lies on a road (by its mean edge distance), else the
## kind most of its corners are.
func _tri_kind(tri: Array) -> int:
	var e: float = (_edge[tri[0]] + _edge[tri[1]] + _edge[tri[2]]) / 3.0
	if e <= 0.0:
		var best: int = tri[0]
		for v in tri:
			if _edge[v] < _edge[best]:
				best = v
		var k: int = _kind[best]
		return k if k <= B_DECK else B_ASPHALT
	var counts := {}
	for v in tri:
		var k: int = _kind[v]
		if k <= B_DECK:
			continue
		counts[k] = int(counts.get(k, 0)) + 1
	var out: int = B_PAVING
	var most := 0
	for k in counts:
		if int(counts[k]) > most:
			most = counts[k]
			out = k
	return out


# ======================================================================================
#  The city's buildings
# ======================================================================================

const CITY_CELL := 96.0
const BAY := 4.0
const SHOP_UNIT := 6.0
const STOREY := 4.6
const SHOP_H := 6.0
## city_building.gdshader's vertex alpha: windows, an iron-roofed low block, plain, glass.
const A_BLOCK := 0.0
const A_LOW := 0.25
const A_PLAIN := 0.7
const A_GLASS := 1.0
## The dusk sky the glass reflects (city_building.gdshader's refl_*), matched to _build_environment.
const REFL_TOP := Color(0.10, 0.12, 0.30)
const REFL_HORIZON := Color(0.98, 0.56, 0.36)
const REFL_GROUND := Color(0.09, 0.08, 0.09)
const REFL_CLOUD := Color(1.0, 0.62, 0.50)
const ESTATE_PAINTS := [
	Color(0.86, 0.80, 0.62), Color(0.72, 0.84, 0.80), Color(0.92, 0.74, 0.58), Color(0.78, 0.66, 0.84),
	Color(0.94, 0.90, 0.80), Color(0.66, 0.76, 0.90), Color(0.90, 0.62, 0.48), Color(0.80, 0.86, 0.60),
]


func _building_material() -> ShaderMaterial:
	if _mats.has("building"):
		return _mats["building"]
	var m := ShaderMaterial.new()
	m.shader = load("res://city_building.gdshader")
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("refl_top", REFL_TOP)
	m.set_shader_parameter("refl_horizon", REFL_HORIZON)
	m.set_shader_parameter("refl_ground", REFL_GROUND)
	m.set_shader_parameter("refl_cloud", REFL_CLOUD)
	m.set_shader_parameter("sky_reflect", Color(0.55, 0.42, 0.52))
	m.set_shader_parameter("glass_dark", Color(0.06, 0.06, 0.09))
	m.set_shader_parameter("lit_share", 0.38)
	m.set_shader_parameter("lit_color", Color(1.0, 0.76, 0.46))
	m.set_shader_parameter("lit_energy", 0.7)
	_mats["building"] = _save_res(m, "building_mat")
	return _mats["building"]


## Walls round `r` from y0 to y1, UV per city_building.gdshader (bays and shop fronts whole on every
## wall); `v_off` lifts the facade's own height (a house's single storey drawn as an upper floor, without
## a shop front).
func _walls(b, r: Rect2, y0: float, y1: float, col: Color, style: int, v_off := 0.0) -> void:
	var poly: Array = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var bays := 0
	var shops := 0
	var ctr: Vector2 = r.get_center()
	for k in range(4):
		var a: Vector2 = poly[k]
		var c: Vector2 = poly[(k + 1) % 4]
		var len: float = a.distance_to(c)
		var mid: Vector2 = (a + c) * 0.5
		var o: Vector2 = (mid - ctr)
		o = Vector2(signf(o.x), 0.0) if absf(o.x) * r.size.y > absf(o.y) * r.size.x else Vector2(0.0, signf(o.y))
		var out3 := Vector3(o.x, 0.0, o.y)
		var nb: int = maxi(1, int(round(len / BAY)))
		var ns: int = maxi(1, int(round(len / SHOP_UNIT)))
		var u0: float = float(bays) * BAY
		var u1: float = float(bays + nb) * BAY
		var s0: float = float(shops) * SHOP_UNIT
		var s1: float = float(shops + ns) * SHOP_UNIT
		var h0: float = v_off
		var h1: float = y1 - y0 + v_off
		var st := float(style)
		var p0 := Vector3(a.x, y0, a.y)
		var p1 := Vector3(c.x, y0, c.y)
		var p2 := Vector3(c.x, y1, c.y)
		var p3 := Vector3(a.x, y1, a.y)
		b.tri2(p0, p1, p2, out3, col, Vector2(u0, h0), Vector2(u1, h0), Vector2(u1, h1), Vector2(s0, st), Vector2(s1, st), Vector2(s1, st))
		b.tri2(p0, p2, p3, out3, col, Vector2(u0, h0), Vector2(u1, h1), Vector2(u0, h1), Vector2(s0, st), Vector2(s1, st), Vector2(s0, st))
		bays += nb
		shops += ns


func _flat_roof(b, r: Rect2, y: float, col: Color) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var c := Vector3(r.end.x, y, r.end.y)
	b.tri(a, Vector3(c.x, y, a.z), c, Vector3.UP, col, Vector2(a.x, a.z), Vector2(c.x, a.z), Vector2(c.x, c.z))
	b.tri(a, c, Vector3(a.x, y, c.z), Vector3.UP, col, Vector2(a.x, a.z), Vector2(c.x, c.z), Vector2(a.x, c.z))


## A shallow pitched iron roof over `r` (the ridge along its long side), overhanging a little.
func _pitched_roof(b, r: Rect2, y: float, col: Color, rise: float) -> void:
	var rr: Rect2 = r.grow(0.5)
	var along_x: bool = rr.size.x >= rr.size.y
	var roof_col := Color(col.r, col.g, col.b, A_LOW)
	var gable_col := Color(col.r, col.g, col.b, A_PLAIN)
	if along_x:
		var zc: float = rr.get_center().y
		var ridge0 := Vector3(rr.position.x, y + rise, zc)
		var ridge1 := Vector3(rr.end.x, y + rise, zc)
		for side in [-1.0, 1.0]:
			var ze: float = zc + side * rr.size.y * 0.5
			var e0 := Vector3(rr.position.x, y, ze)
			var e1 := Vector3(rr.end.x, y, ze)
			var n := Vector3(0, rr.size.y * 0.5, side * rise).normalized()
			b.quad(e0, e1, ridge1, ridge0, n, roof_col)
		for xe in [r.position.x, r.end.x]:
			b.tri(Vector3(xe, y, r.position.y), Vector3(xe, y, r.end.y), Vector3(xe, y + rise, zc), Vector3(signf(xe - r.get_center().x), 0, 0), gable_col)
	else:
		var xc: float = rr.get_center().x
		var ridge0 := Vector3(xc, y + rise, rr.position.y)
		var ridge1 := Vector3(xc, y + rise, rr.end.y)
		for side in [-1.0, 1.0]:
			var xe2: float = xc + side * rr.size.x * 0.5
			var e0 := Vector3(xe2, y, rr.position.y)
			var e1 := Vector3(xe2, y, rr.end.y)
			var n := Vector3(side * rise, rr.size.x * 0.5, 0).normalized()
			b.quad(e0, e1, ridge1, ridge0, n, roof_col)
		for ze2 in [r.position.y, r.end.y]:
			b.tri(Vector3(r.position.x, y, ze2), Vector3(r.end.x, y, ze2), Vector3(xc, y + rise, ze2), Vector3(0, 0, signf(ze2 - r.get_center().y)), gable_col)


func _build_city(parent: Node3D) -> void:
	var mat := _building_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	var cells := {}
	var bodies := {}
	var root := Node3D.new()
	root.name = "City"
	parent.add_child(root)
	var boards: Array = []
	for bi in range(_buildings.size()):
		var bd: Dictionary = _buildings[bi]
		var r: Rect2 = (bd["r"] as Rect2).grow(-0.12)
		var style: int = bd["style"]
		var c2: Vector2 = r.get_center()
		var key := Vector2i(floori(c2.x / CITY_CELL), floori(c2.y / CITY_CELL))
		if not cells.has(key):
			cells[key] = Nyota.Builder.new()
			var body := StaticBody3D.new()
			body.name = "CityBlock_%d_%d" % [key.x, key.y]
			body.set_meta(&"surface", "rock")
			root.add_child(body)
			bodies[key] = body
		var b = cells[key]
		var y0: float = minf(minf(_ground_y(r.position), _ground_y(r.end)), minf(_ground_y(Vector2(r.position.x, r.end.y)), _ground_y(Vector2(r.end.x, r.position.y)))) - 0.3
		var top := 0.0
		var paint: Color = Nyota.WALL_PAINTS[rng.randi() % Nyota.WALL_PAINTS.size()]
		var win_style := float(rng.randi() % 4)
		match style:
			S_TOWER, S_MARKET, S_MID:
				var storeys: int
				if style == S_TOWER:
					storeys = rng.randi_range(4, 13)
				elif style == S_MARKET:
					storeys = rng.randi_range(2, 5)
				else:
					storeys = rng.randi_range(3, 7)
				# Smaller plots stay lower.
				if minf(r.size.x, r.size.y) < 12.0:
					storeys = mini(storeys, 4)
				top = y0 + 0.3 + SHOP_H + float(storeys) * STOREY
				var glass: bool = style == S_TOWER and minf(r.size.x, r.size.y) >= 16.0 and rng.randf() < 0.3
				var col := Color(paint.r, paint.g, paint.b, A_GLASS if glass else A_BLOCK)
				if glass:
					col = Color(rng.randf_range(0.3, 0.6), rng.randf_range(0.4, 0.7), rng.randf_range(0.5, 0.8), A_GLASS)
				_walls(b, r, y0, top, col, int(win_style))
				_flat_roof(b, r, top, col)
				# A parapet, black water tanks, a stair housing.
				var trim := Color(paint.r * 0.8, paint.g * 0.8, paint.b * 0.8, A_PLAIN)
				for k in range(4):
					pass
				b.box(Vector3(c2.x, top + 0.5, r.position.y + 0.15), Vector3(r.size.x, 1.0, 0.3), 0.0, trim)
				b.box(Vector3(c2.x, top + 0.5, r.end.y - 0.15), Vector3(r.size.x, 1.0, 0.3), 0.0, trim)
				b.box(Vector3(r.position.x + 0.15, top + 0.5, c2.y), Vector3(0.3, 1.0, r.size.y - 0.6), 0.0, trim)
				b.box(Vector3(r.end.x - 0.15, top + 0.5, c2.y), Vector3(0.3, 1.0, r.size.y - 0.6), 0.0, trim)
				if rng.randf() < 0.75 and r.size.x > 7.0 and r.size.y > 7.0:
					for k in range(rng.randi_range(1, 3)):
						var tp := Vector3(rng.randf_range(r.position.x + 2.0, r.end.x - 2.0), top + 1.2, rng.randf_range(r.position.y + 2.0, r.end.y - 2.0))
						b.box(tp, Vector3(2.2, 2.4, 2.2), rng.randf() * PI, Color(0.07, 0.07, 0.08, A_PLAIN))
				if style == S_TOWER and r.size.x > 14.0 and r.size.y > 14.0 and rng.randf() < 0.5:
					b.box(Vector3(c2.x, top + 1.8, c2.y), Vector3(5.0, 3.6, 6.0), 0.0, Color(0.70, 0.68, 0.64, A_PLAIN))
				# Billboards on roofs that face the race.
				if style != S_MID and rng.randf() < 0.35 and r.size.x > 14.0 and r.size.y > 14.0:
					boards.append([r, top])
			S_ESTATE, S_SHED:
				var tall: bool = style == S_ESTATE and rng.randf() < 0.2 and minf(r.size.x, r.size.y) >= 8.0
				top = y0 + 0.3 + (9.6 if tall else rng.randf_range(4.6, 5.6))
				var ep: Color = ESTATE_PAINTS[rng.randi() % ESTATE_PAINTS.size()]
				if style == S_SHED:
					ep = Color(0.55, 0.52, 0.48).lerp(Color(0.62, 0.40, 0.30), rng.randf())
				var col2 := Color(ep.r, ep.g, ep.b, A_LOW)
				_walls(b, r, y0, top, col2, 0 if style == S_ESTATE else 3, SHOP_H - (y0 + 0.3 - y0) - 0.2)
				_pitched_roof(b, r, top, col2, minf(r.size.x, r.size.y) * 0.14)
				top += minf(r.size.x, r.size.y) * 0.14
			_:
				# A garden wall or a lean-to.
				top = y0 + 0.3 + 2.8
				var wc := Color(paint.r * 0.85, paint.g * 0.85, paint.b * 0.85, A_PLAIN)
				_walls(b, r, y0, top, wc, 0)
				_flat_roof(b, r, top, wc)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(r.size.x, top - y0, r.size.y)
		cs.shape = box
		cs.position = Vector3(c2.x, (top + y0) * 0.5, c2.y) - (bodies[key] as Node3D).position
		(bodies[key] as StaticBody3D).add_child(cs)
	var tris := 0
	for key in cells:
		var b = cells[key]
		if b.is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.name = "Buildings_%d_%d" % [key.x, key.y]
		mi.mesh = _save_res(b.commit(), "city_%d_%d" % [key.x, key.y])
		mi.material_override = mat
		mi.visibility_range_end = 1300.0
		(bodies[key] as Node3D).add_child(mi)
		tris += b.verts.size() / 3
	print("  city: %d buildings in %d cells, %d triangles" % [_buildings.size(), cells.size(), tris])
	_build_billboards(root, boards, rng)


## Sponsor hoardings on roofs, each on a steel frame, facing the nearest race road (StadiumAds' atlas,
## stadium_boards.gdshader; half of them LED boards that cycle). Fictional sponsors only.
const ADS := [
	["CLUB KILELE", "FRIDAY  SATURDAY  LIVE DJS", Color(0.10, 0.04, 0.16), Color(1.0, 0.30, 0.75), Color(0.25, 0.85, 1.0), 1],
	["MATUMAINI GP", "RC VIBE GRAND PRIX", Color(0.93, 0.42, 0.07), Color(1, 1, 1), Color(0.05, 0.32, 0.17), 0],
	["KAHAWA BORA", "COFFEE FROM THE HIGHLANDS", Color(0.95, 0.90, 0.78), Color(0.30, 0.17, 0.08), Color(0.62, 0.36, 0.14), 2],
	["SIMU+", "4G  5G  EVERYWHERE", Color(0.97, 0.97, 0.96), Color(0.08, 0.52, 0.24), Color(0.95, 0.75, 0.10), 0],
	["JUA SOLAR", "POWER FROM THE SUN", Color(0.98, 0.78, 0.10), Color(0.08, 0.08, 0.08), Color(0.93, 0.42, 0.07), 2],
	["BARABARA TYRES", "GRIP ON ANY ROAD", Color(0.07, 0.07, 0.08), Color(0.98, 0.80, 0.12), Color(0.85, 0.85, 0.85), 0],
	["MTAA FM 98.4", "THE SOUND OF THE CITY", Color(0.75, 0.08, 0.20), Color(1, 1, 1), Color(0.98, 0.80, 0.15), 1],
	["MBUNI AIR", "FLY THE SAVANNA", Color(0.28, 0.58, 0.88), Color(1, 1, 1), Color(0.98, 0.82, 0.25), 2],
	["HARAKA PAY", "SEND  PAY  SAVE", Color(0.09, 0.48, 0.24), Color(1, 1, 1), Color(0.98, 0.80, 0.12), 0],
	["CHAI MOTO", "HOT TEA, COLD DRINKS", Color(0.74, 0.09, 0.10), Color(1, 1, 1), Color(0.98, 0.80, 0.15), 1],
	["TWIGA CEMENT", "BUILT TO LAST", Color(0.52, 0.53, 0.55), Color(0.98, 0.55, 0.12), Color(0.15, 0.15, 0.16), 2],
	["MAJI SAFI", "PURE SPRING WATER", Color(0.72, 0.88, 0.98), Color(0.05, 0.22, 0.52), Color(0.10, 0.50, 0.85), 0],
	["NYAMA CHOMA HOUSE", "OPEN TILL LATE", Color(0.22, 0.10, 0.05), Color(0.98, 0.70, 0.25), Color(0.85, 0.20, 0.10), 1],
	["RC VIBE GP", "SEASON 2026", Color(0.30, 0.12, 0.50), Color(1, 1, 1), Color(0.98, 0.72, 0.20), 2],
	["SIMBA MOTORS", "SINCE 1974", Color(0.45, 0.06, 0.08), Color(0.98, 0.82, 0.35), Color(0.98, 0.82, 0.35), 0],
	["BAHATI LOTTO", "TRY YOUR LUCK", Color(0.80, 0.10, 0.50), Color(0.99, 0.92, 0.20), Color(1, 1, 1), 1],
]
var _boards_mat: ShaderMaterial


func _build_billboards(parent: Node3D, spots: Array, rng: RandomNumberGenerator) -> void:
	_boards_mat = ShaderMaterial.new()
	_boards_mat.shader = load("res://stadium_boards.gdshader")
	_boards_mat.set_shader_parameter("led_energy", 1.6)
	_boards_mat = _save_res(_boards_mat, "boards_mat") as ShaderMaterial
	var kit := _kit()
	var k := {}
	var n := 0
	for sp in spots:
		var r: Rect2 = sp[0]
		var top: float = sp[1]
		var c: Vector2 = r.get_center()
		var roads: Array = _roads_near(c, 60.0).filter(func(rd): return not (_paths[int(rd["path"])] as Dictionary).has("side"))
		if roads.is_empty():
			continue
		var to_road: Vector2 = (roads[0]["point"] as Vector2) - c
		if to_road.length() < 1.0:
			continue
		# Face the road along the nearer axis, from the roof's edge on that side.
		var f := Vector2(signf(to_road.x), 0.0) if absf(to_road.x) > absf(to_road.y) else Vector2(0.0, signf(to_road.y))
		var w: float = minf(28.0, (r.size.y if f.x != 0.0 else r.size.x) - 2.0)
		var h: float = w / 8.0
		var edge_p: Vector2 = c + Vector2(f.x * r.size.x * 0.5, f.y * r.size.y * 0.5) - f * 2.0
		var side := Vector2(-f.y, f.x)
		var y0: float = top + 2.5
		var a := Vector3(edge_p.x - side.x * w * 0.5, y0, edge_p.y - side.y * w * 0.5)
		var bb := Vector3(edge_p.x + side.x * w * 0.5, y0, edge_p.y + side.y * w * 0.5)
		var face := Vector3(f.x, 0.0, f.y)
		var ad: int = n % ADS.size()
		var led: bool = rng.randf() < 0.5
		var col := Color(float(ad) / 64.0, 1.0 if led else 0.0, 0.0, 1.0)
		var p0 := a
		var p1 := bb
		if face.cross(Vector3.UP).dot(bb - a) > 0.0:
			p0 = bb
			p1 = a
		var up := Vector3(0, h, 0)
		kit.quad(k, "boards", [p0 + face * 0.05, p1 + face * 0.05, p1 + up + face * 0.05, p0 + up + face * 0.05], face, col,
				[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		kit.quad(k, "steel", [p1, p0, p0 + up, p1 + up], -face, Color(0.10, 0.10, 0.11))
		for t in [0.1, 0.5, 0.9]:
			var leg: Vector3 = a.lerp(bb, t) - face * 0.6
			kit.beam(k, "steel", Vector3(leg.x, top, leg.z), leg + Vector3(0, h, 0), 0.25, 0.25, Color(0.16, 0.16, 0.17), face)
		# Lamps on arms over the top, shining down on it.
		for t2 in [0.25, 0.75]:
			var lp: Vector3 = p0.lerp(p1, t2) + up + face * 1.2
			kit.block(k, "lamp", lp - Vector3(0.4, 0.1, 0.4), lp + Vector3(0.4, 0.15, 0.4), Color(1.0, 0.95, 0.85))
		n += 1
	if n == 0:
		return
	var mi := MeshInstance3D.new()
	mi.name = "RoofBillboards"
	mi.mesh = _save_res(kit.commit(k), "billboards")
	mi.visibility_range_end = 1200.0
	parent.add_child(mi)
	var ads := Node.new()
	ads.name = "SponsorArt"
	ads.set_script(load("res://StadiumAds.gd"))
	var targets: Array[ShaderMaterial] = [_boards_mat]
	ads.set("targets", targets)
	ads.set("ads", ADS)
	parent.add_child(ads)
	print("  billboards: %d" % n)


## The city past the detailed ground: boxes out to the horizon, tallest in the business district to
## the north-east the avenue looks toward, and the ground under them. No collision: nobody gets there.
func _build_far_city(parent: Node3D) -> void:
	var mat := _building_material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 6060
	var cells := {}
	var cbd := Vector2(1100.0, -1300.0)
	var step := 64.0
	var count := 0
	var x := -2600.0
	while x < 2600.0 and count <= 12000:
		var z := -2600.0
		while z < 2600.0:
			var q := Vector2(x, z) + Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
			z += step
			if q.x > GROUND_MIN.x - 50.0 and q.x < GROUND_MAX.x + 50.0 and q.y > GROUND_MIN.y - 50.0 and q.y < GROUND_MAX.y + 50.0:
				continue
			if q.length() > 2600.0 or rng.randf() < 0.25:
				continue
			var d_cbd: float = q.distance_to(cbd)
			var tall: float = exp(-pow(d_cbd / 520.0, 2.0))
			var h: float = rng.randf_range(10.0, 30.0) + tall * rng.randf_range(60.0, 190.0)
			var w: float = rng.randf_range(22.0, 46.0)
			var dd: float = rng.randf_range(22.0, 46.0)
			var key := Vector2i(floori(q.x / 700.0), floori(q.y / 700.0))
			if not cells.has(key):
				cells[key] = Nyota.Builder.new()
			var b = cells[key]
			var glass: bool = tall > 0.3 and rng.randf() < 0.6
			var paint: Color = Nyota.WALL_PAINTS[rng.randi() % Nyota.WALL_PAINTS.size()]
			var col := Color(paint.r, paint.g, paint.b, A_GLASS if glass else A_BLOCK)
			var r := Rect2(q - Vector2(w, dd) * 0.5, Vector2(w, dd))
			_walls(b, r, -0.5, h, col, rng.randi() % 4)
			_flat_roof(b, r, h, col)
			count += 1
		x += step
	# The grid above holds about 5000; anything near this is a loop gone wrong (it once ran away and
	# took the machine's memory with it).
	if count > 12000:
		push_error("far city: %d blocks" % count)
	for key in cells:
		var mi := MeshInstance3D.new()
		mi.name = "FarCity_%d_%d" % [key.x, key.y]
		mi.mesh = _save_res(cells[key].commit(), "farcity_%d_%d" % [key.x, key.y])
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	# The ground past the detailed tiles: four big quads round them.
	var g := Nyota.Builder.new()
	var gc := Color(0.20, 0.19, 0.18)
	var big := 4200.0
	var y := -0.04
	var rects := [
		Rect2(-big, -big, 2.0 * big, GROUND_MIN.y + big),
		Rect2(-big, GROUND_MAX.y, 2.0 * big, big - GROUND_MAX.y),
		Rect2(-big, GROUND_MIN.y, GROUND_MIN.x + big, GROUND_MAX.y - GROUND_MIN.y),
		Rect2(GROUND_MAX.x, GROUND_MIN.y, big - GROUND_MAX.x, GROUND_MAX.y - GROUND_MIN.y),
	]
	for rr in rects:
		_flat_roof(g, rr, y, gc)
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.vertex_color_is_srgb = true
	gm.roughness = 0.9
	var gmi := MeshInstance3D.new()
	gmi.name = "FarGround"
	gmi.mesh = _save_res(g.commit(), "far_ground")
	gmi.material_override = _save_res(gm, "far_ground_mat")
	gmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(gmi)
	print("  far city: %d blocks" % count)


## Hills round the horizon: the Ngong-like knuckles against the sunset to the west-south-west.
func _build_hills(parent: Node3D) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 3131
	noise.frequency = 0.0009
	var segs := 160
	var rings := [2600.0, 3000.0, 3400.0, 3800.0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array = []
	for ri in range(rings.size()):
		var row: Array = []
		for k in range(segs):
			var a: float = TAU * float(k) / float(segs)
			var rad: float = rings[ri]
			var p := Vector2(cos(a), sin(a)) * rad
			# The knuckles to the west-south-west (about 165 degrees from east, round through south).
			var sw: float = exp(-pow(wrapf(a - deg_to_rad(168.0), -PI, PI) / 0.30, 2.0))
			var knuckles: float = absf(sin(a * 24.0)) * 0.5 + 0.5
			var h: float = (60.0 + noise.get_noise_2d(p.x, p.y) * 80.0) + sw * 420.0 * knuckles
			var t: float = float(ri) / float(rings.size() - 1)
			var y: float = -2.0 + h * sin(t * PI * 0.9) if ri > 0 else -2.0
			row.append(Vector3(p.x, y, p.y))
		grid.append(row)
	for ri in range(rings.size() - 1):
		for k in range(segs):
			var k2: int = (k + 1) % segs
			var quad := [grid[ri][k], grid[ri][k2], grid[ri + 1][k2], grid[ri + 1][k]]
			for t in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = quad[t[0]]
				var b: Vector3 = quad[t[1]]
				var c: Vector3 = quad[t[2]]
				var order: Array = t if (c - a).cross(b - a).dot(-a.normalized() + Vector3.UP * 0.3) >= 0.0 else [t[0], t[2], t[1]]
				for idx in order:
					st.set_color(Color(0.16, 0.15, 0.20))
					st.add_vertex(quad[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "HorizonHills"
	mi.mesh = _save_res(st.commit(), "hills")
	var m := ShaderMaterial.new()
	m.shader = load("res://distant_mountain.gdshader")
	m.set_shader_parameter("haze_color", HAZE)
	m.set_shader_parameter("haze_base", 0.75)
	m.set_shader_parameter("haze_top", 0.35)
	m.set_shader_parameter("peak_height", 480.0)
	mi.material_override = _save_res(m, "hills_mat")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ======================================================================================
#  Materials, kits, colliders
# ======================================================================================

func _save_res(res: Resource, res_name: String) -> Resource:
	if not DirAccess.dir_exists_absolute("res://generated/"):
		DirAccess.make_dir_absolute("res://generated/")
	var file_path: String = "res://generated/" + RES_PREFIX + res_name + ".res"
	res.take_over_path(file_path)
	ResourceSaver.save(res, file_path)
	return load(file_path)


## The material for a PropKit key, made once and saved, so every mesh of the level shares it.
func _material(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match key:
		"boards":
			m = _boards_mat
		"neon", "bulb", "led":
			var sm := ShaderMaterial.new()
			sm.shader = load("res://neon_emissive.gdshader")
			sm.set_shader_parameter("energy", {"neon": 4.0, "bulb": 6.0, "led": 2.5}[key])
			m = sm
		"tyre":
			var tm := ShaderMaterial.new()
			tm.shader = load("res://tyre_wall.gdshader")
			m = tm
		"concrete":
			var cm := StandardMaterial3D.new()
			cm.vertex_color_use_as_albedo = true
			cm.vertex_color_is_srgb = true
			cm.albedo_texture = load("res://materials/concrete.png")
			cm.uv1_triplanar = true
			cm.uv1_scale = Vector3(0.25, 0.25, 0.25)
			cm.roughness = 0.9
			m = cm
		"paint":
			m = CampKit.make_material("gloss")
		"timber":
			m = CampKit.make_material("wood")
		"lamp":
			var lm := StandardMaterial3D.new()
			lm.vertex_color_use_as_albedo = true
			lm.vertex_color_is_srgb = true
			lm.emission_enabled = true
			lm.emission = Color(1.0, 0.92, 0.78)
			lm.emission_energy_multiplier = 4.0
			m = lm
		_:
			m = CampKit.make_material(key)
	m = _save_res(m, "mat_" + key)
	_mats[key] = m
	return m


func _kit() -> PropKit:
	var kit := PropKit.new()
	kit.material_for = _material
	return kit


func _commit(parent: Node, kit: PropKit, k: Dictionary, node_name: String, range_end := 600.0, shadow := true) -> MeshInstance3D:
	if k.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = _save_res(kit.commit(k), node_name.to_snake_case())
	if range_end > 0.0:
		mi.visibility_range_end = range_end
		mi.visibility_range_end_margin = 20.0
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## A static body of boxes: each [centre, size, yaw].
func _boxes_body(parent: Node, body_name: String, boxes: Array, surface := "rock") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.set_meta(&"surface", surface)
	for bx in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bx[1]
		cs.shape = shape
		cs.transform = Transform3D(Basis(Vector3.UP, float(bx[2]) if bx.size() > 2 else 0.0), bx[0])
		body.add_child(cs)
	parent.add_child(body)
	return body


## True where a prop of radius `r` can stand at q: off every road by `road_margin`, out of the
## buildings, and clear of what's been placed.
var _why := {}


func _clear(q: Vector2, r: float, road_margin := 1.0) -> bool:
	if q.x < GROUND_MIN.x + 4.0 or q.y < GROUND_MIN.y + 4.0 or q.x > GROUND_MAX.x - 4.0 or q.y > GROUND_MAX.y - 4.0:
		_why["outside"] = int(_why.get("outside", 0)) + 1
		return false
	if _edge_at(q) < road_margin + r:
		_why["road"] = int(_why.get("road", 0)) + 1
		return false
	var ncx: int = _nx - 1
	var c0 := Vector2i(floori((q.x - r - GROUND_MIN.x) / GRID), floori((q.y - r - GROUND_MIN.y) / GRID))
	var c1 := Vector2i(floori((q.x + r - GROUND_MIN.x) / GRID), floori((q.y + r - GROUND_MIN.y) / GRID))
	for cz in range(maxi(c0.y, 0), mini(c1.y, _nz - 2) + 1):
		for cx in range(maxi(c0.x, 0), mini(c1.x, ncx - 1) + 1):
			if _occ[cz * ncx + cx] >= 0:
				_why["building"] = int(_why.get("building", 0)) + 1
				return false
	for u in _used:
		if (u as Rect2).grow(r).has_point(q):
			_why["used"] = int(_why.get("used", 0)) + 1
			return false
	return true


## _clear for something long lying along `fwd` (a van at the kerb): its middle and both ends, each
## `r` (half its width) clear, the whole of it at least `road_margin` off the road.
func _clear_long(q: Vector2, fwd: Vector2, half_len: float, r: float, road_margin := 0.3) -> bool:
	for t in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		if not _clear(q + fwd * half_len * float(t), r, road_margin):
			return false
	return true


func _use(q: Vector2, r: float) -> void:
	_used.append(Rect2(q - Vector2(r, r), Vector2(r, r) * 2.0))


func _xf(q: Vector2, yaw: float, scale := 1.0, lift := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), Vector3(q.x, _ground_y(q) + lift, q.y))


func _multimesh(mesh: Mesh, xfs: Array, node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	# The dummy renderer drops set_instance_transform(); write the buffer itself (CLAUDE.md).
	mm.buffer = PropKit.transform_buffer(xfs)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	return mmi


## Instances of `mesh` in cells of `cell` metres, each drawn to `range_end`.
func _cells(parent: Node, mesh: Mesh, xfs: Array, prefix: String, cell: float, range_end: float, shadow := true) -> void:
	var cells := {}
	for t in xfs:
		var o: Vector3 = (t as Transform3D).origin
		var key := Vector2i(floori(o.x / cell), floori(o.z / cell))
		if not cells.has(key):
			cells[key] = []
		cells[key].append(t)
	for key in cells:
		var mmi := _multimesh(mesh, cells[key], "%s_%d_%d" % [prefix, key.x, key.y])
		mmi.visibility_range_end = range_end
		mmi.visibility_range_end_margin = 20.0
		if not shadow:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


# ======================================================================================
#  Street lamps, trees, barriers
# ======================================================================================

func _build_lamps(parent: Node3D) -> void:
	var mats := {}
	var kit := PropKit.new()
	kit.material_for = func(key: String) -> Material:
		if not mats.has(key):
			var m: StandardMaterial3D = StreetLampKit.make_material(key)
			if key == "lamp":
				# Dusk: the lens burns bright enough to bloom.
				m.emission = Color(1.0, 0.86, 0.62)
				m.emission_energy_multiplier = 7.0
			mats[key] = _save_res(m, "streetlamp_" + key)
		return mats[key]
	kit.set_frame(Transform3D.IDENTITY)
	var mesh: ArrayMesh = _save_res(StreetLampKit.new(kit).build(), "streetlamp")
	var root := Node3D.new()
	root.name = "StreetLamps"
	parent.add_child(root)
	var xfs: Array = []
	var lights := 0
	for l in _lamps:
		var p: Vector2 = l["p"]
		var arm: Vector2 = l["arm"]
		var sc: float = 1.05 if l.has("park") else LAMP_SCALE
		var x := Vector3(arm.x, 0.0, arm.y)
		var bs := Basis(x, Vector3.UP, Vector3(-arm.y, 0.0, arm.x)).scaled(Vector3.ONE * sc)
		var y: float = _ground_y(p)
		xfs.append(Transform3D(bs, Vector3(p.x, y, p.y)))
		_use(p, 0.8)
		if l["light"]:
			var om := OmniLight3D.new()
			om.name = "LampLight_%d" % lights
			var lp: Vector2 = p + arm * LAMP_REACH * sc / LAMP_SCALE
			om.position = Vector3(lp.x, y + LAMP_TOP * sc / LAMP_SCALE - 0.6, lp.y)
			om.light_color = Color(1.0, 0.80, 0.56)
			om.light_energy = 1.6
			om.omni_range = LAMP_LIGHT_RANGE
			om.omni_attenuation = 1.3
			om.shadow_enabled = false
			om.distance_fade_enabled = true
			om.distance_fade_begin = 170.0
			om.distance_fade_length = 40.0
			om.set_meta(&"no_shadow", true)
			root.add_child(om)
			lights += 1
	_cells(root, mesh, xfs, "Lamps", 160.0, 420.0)
	print("  lamps: %d, %d with a light" % [xfs.size(), lights])


## Jacarandas in flower (Nyota Stadium's street trees, its saved meshes): along the avenue's pavements,
## round the park, in the club's grounds and the churchyard.
func _build_trees(parent: Node3D) -> void:
	var near_meshes: Array = []
	var far_meshes: Array = []
	for v in range(3):
		near_meshes.append(load("res://generated/nyota_tree_%d.res" % v))
		far_meshes.append(load("res://generated/nyota_tree_far_%d.res" % v))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var spots: Array = []
	# The avenue and Mwangaza Road: a row each side, between the kerb and the shops.
	for path_span in [[Vector2(-400.0, -250.0), Vector2(130.0, -250.0)], [Vector2(-130.0, 150.0), Vector2(-245.0, 150.0)]]:
		var s0: float = _s_near(_main, path_span[0])
		var s1: float = _s_near(_main, path_span[1])
		if s1 < s0:
			s1 += float(_main["len"])
		var s := s0
		while s < s1:
			for side in [-1.0, 1.0]:
				var sp: Dictionary = _spot(_main, s, side * (_half(_main, s) + 3.6))
				spots.append([sp["p2"], rng.randf_range(0.68, 0.85)])
			s += rng.randf_range(22.0, 30.0)
	# The park: scattered, clear of both routes and the fountain.
	for k in range(140):
		var q := Vector2(rng.randf_range(PARK.position.x + 4.0, PARK.end.x - 4.0), rng.randf_range(PARK.position.y + 4.0, PARK.end.y - 4.0))
		if q.distance_to(FOUNTAIN) < 16.0:
			continue
		var lawn_d: float = _path_distance(_alts[1], q)
		if lawn_d < 15.0:
			continue
		spots.append([q, rng.randf_range(0.85, 1.15)])
	# The club's grounds: along the walls.
	for k in range(26):
		var t: float = float(k) / 26.0
		var q2: Vector2
		if k < 13:
			q2 = Vector2(lerpf(CLUB.position.x + 8.0, CLUB.end.x - 8.0, t * 2.0), CLUB.end.y - 6.0)
		else:
			q2 = Vector2(CLUB.position.x + 6.0, lerpf(CLUB.position.y + 10.0, CLUB.end.y - 30.0, (t - 0.5) * 2.0))
		spots.append([q2, rng.randf_range(0.8, 1.0)])
	var near := {}
	var far := {}
	var count := 0
	for sp in spots:
		var q: Vector2 = sp[0]
		if not _clear(q, 2.0, 2.0):
			continue
		var s: float = sp[1]
		var v: int = rng.randi() % 3
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.92, 1.08), s)), Vector3(q.x, _ground_y(q), q.y))
		_use(q, 2.0)
		var key := Vector3i(floori(q.x / 160.0), floori(q.y / 160.0), v)
		if not near.has(key):
			near[key] = []
		near[key].append(xf)
		var fk := Vector3i(floori(q.x / 400.0), floori(q.y / 400.0), v)
		if not far.has(fk):
			far[fk] = []
		far[fk].append(xf)
		count += 1
	var root := Node3D.new()
	root.name = "Jacarandas"
	parent.add_child(root)
	for k in near:
		var mmi := _multimesh(near_meshes[k.z], near[k], "Tree_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.visibility_range_end = Nyota.TREE_NEAR + Nyota.TREE_FADE * 0.5 + Nyota.TREE_FADE_JITTER + 160.0 * 0.72
		mmi.visibility_range_end_margin = 10.0
		root.add_child(mmi)
	for k in far:
		var mmi2 := _multimesh(far_meshes[k.z], far[k], "TreeFar_%d_%d_%d" % [k.x, k.y, k.z])
		mmi2.visibility_range_begin = maxf(0.0, Nyota.TREE_NEAR - Nyota.TREE_FADE * 0.5 - Nyota.TREE_FADE_JITTER - 400.0 * 0.72)
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi2)
	print("  jacarandas: %d" % count)


## The distance from q to the nearest point of `path` (in plan).
func _path_distance(path: Dictionary, q: Vector2) -> float:
	return (_at(path, _s_near(path, q))["p"] as Vector2).distance_to(q)


const BARRIER_SCALE := 1.8
## A crowd barrier's length (life size) and a jersey block's.
const BARRIER_LEN := 2.24
const JERSEY_LEN := 2.0
var _barrier_runs: Array = []
var _jersey_runs: Array = []


## A concrete jersey barrier at life size along x: 2m long, 0.81m high, the safety-shape profile, in
## four sections painted red and white in turn.
func _jersey(kit: PropKit, k: Dictionary) -> void:
	var prof := PackedVector2Array([Vector2(-0.30, 0.0), Vector2(0.30, 0.0), Vector2(0.30, 0.075), Vector2(0.20, 0.33),
			Vector2(0.075, 0.81), Vector2(-0.075, 0.81), Vector2(-0.20, 0.33), Vector2(-0.30, 0.075)])
	kit.set_frame(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	for i in range(4):
		var z0: float = -1.0 + float(i) * 0.5
		var col := Color(0.80, 0.12, 0.10) if i % 2 else Color(0.84, 0.83, 0.80)
		kit.extrude(k, "concrete", prof, z0 + 0.005, z0 + 0.495, 0.015, col)
	kit.reset_frame()


## Lays the barrier runs ([a, b] in plan) as MultiMesh pieces with a box collider each run.
func _build_barriers(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Barriers"
	parent.add_child(root)
	var kit := _kit()
	var camp := CampKit.new(kit)
	var k := {}
	camp.crowd_barrier(k)
	var crowd_mesh: ArrayMesh = _save_res(kit.commit(k), "crowd_barrier")
	var kj := {}
	_jersey(kit, kj)
	var jersey_mesh: ArrayMesh = _save_res(kit.commit(kj), "jersey")
	for spec in [[_barrier_runs, crowd_mesh, BARRIER_LEN, 1.1, 0.5, "CrowdBarrier"], [_jersey_runs, jersey_mesh, JERSEY_LEN, 0.81, 0.6, "Jersey"]]:
		var runs: Array = spec[0]
		var xfs: Array = []
		var boxes: Array = []
		var piece: float = float(spec[2]) * BARRIER_SCALE
		for run in runs:
			var a: Vector2 = run[0]
			var b: Vector2 = run[1]
			var len: float = a.distance_to(b)
			if len < 1.0:
				continue
			var d: Vector2 = (b - a) / len
			var n: int = maxi(1, int(round(len / piece)))
			var yaw: float = -atan2(d.y, d.x)
			for i in range(n):
				var q: Vector2 = a + d * (float(i) + 0.5) * len / float(n)
				xfs.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(len / float(n) / piece, 1.0, 1.0) * BARRIER_SCALE), Vector3(q.x, _ground_y(q), q.y)))
			var mid: Vector2 = (a + b) * 0.5
			var hgt: float = float(spec[3]) * BARRIER_SCALE
			boxes.append([Vector3(mid.x, _ground_y(mid) + hgt * 0.5, mid.y), Vector3(len, hgt, float(spec[4]) * BARRIER_SCALE), yaw])
		if xfs.is_empty():
			continue
		_cells(root, spec[1], xfs, String(spec[5]) + "s", 120.0, 380.0)
		_boxes_body(root, String(spec[5]) + "Body", boxes, "rock")
		print("  %s: %d pieces in %d runs" % [spec[5], xfs.size(), runs.size()])


## A barrier run along `path` from s0 to s1, `lat` metres right of its centreline (pieces of ~8m so it
## follows bends).
func _run_along(list: Array, path: Dictionary, s0: float, s1: float, lat: float) -> void:
	var n: int = maxi(1, int(ceil(absf(s1 - s0) / 8.0)))
	var prev: Vector2 = _spot(path, s0, lat)["p2"]
	for i in range(1, n + 1):
		var s: float = lerpf(s0, s1, float(i) / float(n))
		var q: Vector2 = _spot(path, s, lat)["p2"]
		list.append([prev, q])
		prev = q


## Closes every side street where it meets the race with a row of jersey blocks across its mouth.
func _plan_side_closures() -> void:
	var race: Array = [_main]
	race.append_array(_alts)
	for sd in SIDE_STREETS:
		for end in [0, 1]:
			var p: Vector2 = sd[end]
			var other: Vector2 = sd[1 - end]
			var d: Vector2 = (other - p).normalized()
			var near_race := false
			for rp in race:
				if rp == _alts[1]:
					continue
				var s: float = _s_near(rp, p)
				var rq: Vector2 = _at(rp, s)["p"]
				if rq.distance_to(p) < _half(rp, s) + 2.0:
					near_race = true
			if not near_race:
				continue
			var half: float = sd[2]
			var q: Vector2 = p + d * 2.2
			var side := Vector2(-d.y, d.x)
			_jersey_runs.append([q - side * (half + 3.0), q + side * (half + 3.0)])


# ======================================================================================
#  Vehicles, stalls, kiosks
# ======================================================================================

const MATATU_SCALE := 2.0
var _vehicle_mats := {}


func _vehicle_kit() -> PropKit:
	var kit := PropKit.new()
	kit.material_for = func(key: String) -> Material:
		if not _vehicle_mats.has(key):
			_vehicle_mats[key] = _save_res(MatatuKit.make_material(key), "matatu_" + key)
		return _vehicle_mats[key]
	kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * MATATU_SCALE), Vector3.ZERO))
	return kit


## Matatus waiting at the kerb: [position (plan), yaw, livery]. A box each.
func _build_matatus(parent: Node3D, spots: Array) -> void:
	var root := Node3D.new()
	root.name = "Matatus"
	parent.add_child(root)
	var kit := _vehicle_kit()
	var meshes := {}
	var boxes: Array = []
	for i in range(spots.size()):
		var sp: Array = spots[i]
		var q: Vector2 = sp[0]
		var li: int = int(sp[2]) % MatatuKit.LIVERIES.size()
		if not meshes.has(li):
			meshes[li] = _save_res(MatatuKit.new(kit).build(MatatuKit.LIVERIES[li]), "matatu_%d" % li)
		var mi := MeshInstance3D.new()
		mi.name = "Matatu_%d" % i
		mi.mesh = meshes[li]
		mi.transform = _xf(q, float(sp[1]))
		mi.visibility_range_end = 420.0
		root.add_child(mi)
		boxes.append([mi.position + Vector3(0, 2.6, 0), Vector3(1.95, 2.15, 5.4) * MATATU_SCALE, float(sp[1])])
		_use(q, 5.5)
	_boxes_body(root, "MatatuBodies", boxes, "rock")
	print("  matatus: %d" % spots.size())


func _build_food_trucks(parent: Node3D, spots: Array) -> void:
	var kit := _vehicle_kit()
	var boxes: Array = []
	for i in range(spots.size()):
		var sp: Array = spots[i]
		var mi := MeshInstance3D.new()
		mi.name = "FoodTruck_%d" % i
		mi.mesh = _save_res(FoodTruckKit.new(kit).build_truck(FoodTruckKit.TRUCKS[int(sp[2])]), "foodtruck_%d" % int(sp[2]))
		mi.transform = _xf(sp[0], float(sp[1]))
		mi.visibility_range_end = 420.0
		parent.add_child(mi)
		boxes.append([mi.position + Vector3(0, 2.8, 0), Vector3(2.1, 2.6, 6.2) * MATATU_SCALE, float(sp[1])])
		_use(sp[0], 7.0)
	_boxes_body(parent, "FoodTruckBodies", boxes, "rock")


const STALL_SCALE := 2.0
var _stall_mats := {}


## MarketStallKit's stalls: [position (plan), yaw (the front toward the stall's +z), kind, variant].
func _build_stalls(parent: Node3D, spots: Array, node_name: String) -> void:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	var kit := PropKit.new()
	kit.material_for = func(key: String) -> Material:
		if not _stall_mats.has(key):
			_stall_mats[key] = _save_res(MarketStallKit.make_stall_material(key), "stall_" + key)
		return _stall_mats[key]
	kit.set_frame(Transform3D(Basis().scaled(Vector3.ONE * STALL_SCALE), Vector3.ZERO))
	var meshes := {}
	var boxes: Array = []
	for i in range(spots.size()):
		var sp: Array = spots[i]
		var key := "%d_%d" % [sp[2], sp[3]]
		if not meshes.has(key):
			meshes[key] = _save_res(MarketStallKit.new(kit).build_stall(int(sp[2]), int(sp[3])), "stall_" + key)
		var mi := MeshInstance3D.new()
		mi.name = "Stall_%d" % i
		mi.mesh = meshes[key]
		mi.transform = _xf(sp[0], float(sp[1]))
		mi.visibility_range_end = 380.0
		root.add_child(mi)
		# The counter and the back: a box over the stall's footprint, below the awning.
		boxes.append([mi.position + Vector3(0, 1.6, 0), Vector3(3.0, 3.2, 2.2) * STALL_SCALE * Vector3(1, 0.5, 1), float(sp[1])])
		_use(sp[0], 3.4)
	_boxes_body(root, node_name + "Bodies", boxes, "rock")
	print("  %s: %d" % [node_name, spots.size()])


# ======================================================================================
#  The districts
# ======================================================================================

## Spectators and passers-by for CrowdPlacer: [position, facing, seated, false, pose (or -1)].
var _people: Array = []
## Standing poses, weighted: a street (idle, clap, film, arms crossed, hands on hips, drink), and a dance
## floor (cheer, clap, wave, drink, idle, film).
const STREET_POSES := [[7, 0.32], [8, 0.10], [10, 0.12], [11, 0.14], [13, 0.18], [15, 0.14]]
const DANCE_POSES := [[9, 0.30], [8, 0.22], [14, 0.20], [15, 0.10], [7, 0.08], [10, 0.10]]
const SPECTATOR_SKIN := [0.86, 0.06, 0.05, 0.02, 0.01]
const PEOPLE_SCALE := 1.0


func _pose(rng: RandomNumberGenerator, table: Array) -> int:
	var r: float = rng.randf()
	for e in table:
		r -= float(e[1])
		if r <= 0.0:
			return int(e[0])
	return int(table[0][0])


func _person(q: Vector2, face: Vector2, pose: int, seated := false, y := INF) -> void:
	var gy: float = _ground_y(q) if y == INF else y
	var spot: Array = [Vector3(q.x, gy, q.y), Vector3(face.x, 0.0, face.y), seated, false]
	if pose >= 0:
		spot.append(pose)
	_people.append(spot)


## [s0, s1] on the main lap between the points nearest a and b, s1 >= s0 (across the lap's start too).
func _span(a: Vector2, b: Vector2) -> Array:
	var s0: float = _s_near(_main, a)
	var s1: float = _s_near(_main, b)
	if s1 < s0:
		s1 += float(_main["len"])
	return [s0, s1]


## Rows of people along `path` from s0 to s1 on one side (`side` +-1), behind a crowd barrier at
## `barrier` metres from the road's edge, in `rows` rows from `first` metres out, facing the road.
func _crowd_rows(path: Dictionary, s0: float, s1: float, side: float, barrier: float, first: float, rows: int, gap: float, rng: RandomNumberGenerator, table: Array) -> void:
	_run_along(_barrier_runs, path, s0, s1, side * (_half(path, s0) + barrier))
	var s := s0
	while s < s1:
		var half: float = _half(path, s)
		for r in range(rows):
			var sp: Dictionary = _spot(path, s + rng.randf_range(-0.5, 0.5), side * (half + first + float(r) * 1.35 + rng.randf_range(-0.3, 0.3)))
			var q: Vector2 = sp["p2"]
			if not _clear(q, 0.5, first - 0.6):
				continue
			var rt: Vector3 = sp["right"]
			_person(q, -Vector2(rt.x, rt.z) * side, _pose(rng, table))
		s += gap


func _plan_avenue(rng: RandomNumberGenerator) -> Array:
	# The crowd at the start: both pavements from the corner to past the line.
	var sp: Array = _span(Vector2(-380.0, -250.0), Vector2(-20.0, -250.0))
	for side in [-1.0, 1.0]:
		_crowd_rows(_main, float(sp[0]), float(sp[1]), side, 0.6, 2.2, 3, 1.35, rng, STREET_POSES)
	# A matatu stage on the avenue's north side, east of the crowd.
	var mats: Array = []
	var ms: Array = _span(Vector2(5.0, -250.0), Vector2(110.0, -250.0))
	var s: float = ms[0]
	var li := 0
	while s < float(ms[1]):
		var spot: Dictionary = _spot(_main, s, -(AVENUE_HALF + 2.3))
		var fw2 := Vector2((spot["fwd"] as Vector3).x, (spot["fwd"] as Vector3).z)
		if _clear_long(spot["p2"], fw2, 5.2, 1.9):
			mats.append([spot["p2"], deg_to_rad(float(spot["yaw"])), li])
			li += 1
			# Touts and passengers by the open door.
			for k in range(rng.randi_range(1, 3)):
				var rt: Vector3 = spot["right"]
				var pq: Vector2 = (spot["p2"] as Vector2) - Vector2(rt.x, rt.z) * rng.randf_range(3.4, 5.0) + Vector2((spot["fwd"] as Vector3).x, (spot["fwd"] as Vector3).z) * rng.randf_range(-4.0, 4.0)
				_person(pq, Vector2(rt.x, rt.z), _pose(rng, STREET_POSES))
		s += 13.0
	return mats


func _plan_mwangaza(rng: RandomNumberGenerator) -> Array:
	var mats: Array = []
	var ms: Array = _span(Vector2(-140.0, 150.0), Vector2(-205.0, 150.0))
	var s: float = ms[0]
	var li := 5
	while s < float(ms[1]):
		var spot: Dictionary = _spot(_main, s, -(STREET_HALF + 2.4))
		var fw3 := Vector2((spot["fwd"] as Vector3).x, (spot["fwd"] as Vector3).z)
		if _clear_long(spot["p2"], fw3, 5.2, 1.9):
			mats.append([spot["p2"], deg_to_rad(float(spot["yaw"])), li])
			li += 1
		s += 13.0
	# The queue at the club's gate, behind a barrier on the south pavement.
	var qs: Array = _span(Vector2(-208.0, 150.0), Vector2(-246.0, 150.0))
	_crowd_rows(_main, float(qs[0]), float(qs[1]), -1.0, 0.6, 2.0, 3, 1.25, rng, [[7, 0.4], [10, 0.25], [15, 0.15], [11, 0.2]])
	return mats


## Biashara Street: stalls on both pavements behind crowd barriers, shoppers in front of them, the sellers
## behind their counters.
func _plan_market(rng: RandomNumberGenerator) -> Array:
	var stalls: Array = []
	var ms: Array = _span(Vector2(150.0, -228.0), Vector2(150.0, -62.0))
	for side in [-1.0, 1.0]:
		_run_along(_barrier_runs, _main, float(ms[0]), float(ms[1]), side * (STREET_HALF + 0.6))
		var s: float = ms[0]
		while s < float(ms[1]):
			var spot: Dictionary = _spot(_main, s, side * (STREET_HALF + 5.4))
			var q: Vector2 = spot["p2"]
			var rt: Vector3 = spot["right"]
			var to_road: Vector2 = -Vector2(rt.x, rt.z) * side
			if _clear(q, 2.6, 2.0):
				var yaw: float = atan2(to_road.x, to_road.y)
				stalls.append([q, yaw, rng.randi() % 6, rng.randi() % 3])
				_person(q - to_road * 1.4, to_road, _pose(rng, [[7, 0.5], [13, 0.3], [11, 0.2]]))
				for k in range(rng.randi_range(1, 4)):
					var f2 := Vector2((spot["fwd"] as Vector3).x, (spot["fwd"] as Vector3).z)
					var pq: Vector2 = q + to_road * rng.randf_range(2.9, 3.6) + f2 * rng.randf_range(-2.6, 2.6)
					_person(pq, -to_road.rotated(rng.randf_range(-0.6, 0.6)), _pose(rng, STREET_POSES))
			s += 7.0
	return stalls


## Kiosks on the murram roads' verges, with a few people round each.
func _plan_estate(rng: RandomNumberGenerator) -> Array:
	var kiosks: Array = []
	_why.clear()
	for span in [[Vector2(60.0, -40.0), Vector2(-95.0, -40.0)], [Vector2(-420.0, -40.0), Vector2(-420.0, -200.0)]]:
		var ms: Array = _span(span[0], span[1])
		var s: float = float(ms[0]) + rng.randf_range(4.0, 12.0)
		while s < float(ms[1]):
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var spot: Dictionary = _spot(_main, s, side * (STREET_HALF + 3.9))
			var q: Vector2 = spot["p2"]
			var rt: Vector3 = spot["right"]
			var to_road: Vector2 = -Vector2(rt.x, rt.z) * side
			if _clear(q, 2.4, 1.2):
				kiosks.append([q, atan2(to_road.x, to_road.y), 5 if rng.randf() < 0.6 else 0, rng.randi() % 3])
				for k in range(rng.randi_range(1, 3)):
					var f2 := Vector2((spot["fwd"] as Vector3).x, (spot["fwd"] as Vector3).z)
					_person(q + to_road * rng.randf_range(3.0, 3.6) + f2 * rng.randf_range(-2.5, 2.5), -to_road, _pose(rng, STREET_POSES))
			s += rng.randf_range(18.0, 32.0)
	return kiosks


## The jua kali workshops along the alley: wrecks waiting for parts, tyre stacks, oil drums, sheet steel,
## and the people at work. Each has its own box.
func _build_workshops(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "JuaKali"
	parent.add_child(root)
	var kit := _kit()
	var camp := CampKit.new(kit)
	var road := RoadsideKit.new(kit)
	var k := {}
	var boxes: Array = []
	var yard: Dictionary = _alts[0]
	var s := 50.0
	var wrecks := 0
	while s < float(yard["len"]) - 45.0:
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		var spot: Dictionary = _spot(yard, s, side * (ALLEY_HALF + 3.2))
		var q: Vector2 = spot["p2"]
		var yaw: float = deg_to_rad(float(spot["yaw"]))
		var pick: float = rng.randf()
		if pick < 0.3 and wrecks < 6 and _clear(q, 2.2, 1.0):
			var faded := Color(rng.randf_range(0.3, 0.6), rng.randf_range(0.25, 0.45), rng.randf_range(0.2, 0.4))
			kit.set_frame(_xf(q, yaw, 2.0))
			camp.vehicle(k, "suv" if rng.randf() < 0.5 else "van", faded)
			boxes.append([Vector3(q.x, _ground_y(q) + 1.8, q.y), Vector3(3.8, 3.6, 9.6), yaw])
			_use(q, 4.0)
			wrecks += 1
		elif pick < 0.6 and _clear(q, 1.4, 1.0):
			for t in range(rng.randi_range(2, 4)):
				var tq: Vector2 = q + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
				kit.set_frame(_xf(tq, rng.randf() * TAU, 2.0))
				road.tyre_stack(k, rng.randi_range(2, 6), rng)
			boxes.append([Vector3(q.x, _ground_y(q) + 1.4, q.y), Vector3(4.2, 2.8, 4.2), 0.0])
			_use(q, 2.6)
		elif _clear(q, 1.2, 1.0):
			for t in range(rng.randi_range(2, 5)):
				var dq: Vector2 = q + Vector2(rng.randf_range(-1.4, 1.4), rng.randf_range(-1.4, 1.4))
				kit.set_frame(_xf(dq, rng.randf() * TAU, 2.0))
				road.oil_drum(k, [Color(0.15, 0.35, 0.65), Color(0.70, 0.18, 0.12), Color(0.12, 0.40, 0.20), Color(0.30, 0.30, 0.32)][rng.randi() % 4])
			boxes.append([Vector3(q.x, _ground_y(q) + 0.9, q.y), Vector3(3.8, 1.8, 3.8), 0.0])
			_use(q, 2.2)
			var rt: Vector3 = spot["right"]
			_person(q - Vector2(rt.x, rt.z) * side * 2.6, Vector2(rt.x, rt.z) * side, _pose(rng, [[11, 0.3], [13, 0.4], [7, 0.3]]))
		s += rng.randf_range(10.0, 16.0)
	kit.reset_frame()
	_commit(root, kit, k, "JuaKaliProps", 360.0)
	_boxes_body(root, "JuaKaliBodies", boxes, "rock")
	# A welder's blue light in one shed.
	var weld := OmniLight3D.new()
	weld.name = "WeldingLight"
	var wq: Vector2 = _spot(yard, float(yard["len"]) * 0.45, ALLEY_HALF + 4.0)["p2"]
	weld.position = Vector3(wq.x, 2.5, wq.y)
	weld.light_color = Color(0.55, 0.70, 1.0)
	weld.light_energy = 2.0
	weld.omni_range = 12.0
	weld.set_meta(&"no_shadow", true)
	root.add_child(weld)


## The park: a fountain on its west lawn, benches along the paths and round the fountain, a hedge along
## Mtaa Road and the club's wall, people on the benches and out walking.
func _build_park(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "Bustani"
	parent.add_child(root)
	var kit := _kit()
	var road := RoadsideKit.new(kit)
	var k := {}
	var boxes: Array = []
	# The fountain: a stone basin, a low pool wall, a column with three bowls.
	var fy: float = _ground_y(FOUNTAIN)
	var stone := Color(0.72, 0.70, 0.66)
	kit.reset_frame()
	kit.lathe(k, "concrete", Vector3(FOUNTAIN.x, fy, FOUNTAIN.y), [Vector2(8.6, 0.0), Vector2(8.6, 0.85), Vector2(8.0, 0.95), Vector2(7.6, 0.95), Vector2(7.6, 0.4)], 40, stone)
	kit.lathe(k, "concrete", Vector3(FOUNTAIN.x, fy, FOUNTAIN.y), [Vector2(1.2, 0.4), Vector2(0.9, 2.0), Vector2(2.6, 2.4), Vector2(2.6, 2.6), Vector2(0.6, 2.6), Vector2(0.5, 4.0), Vector2(1.6, 4.3), Vector2(1.6, 4.5), Vector2(0.35, 4.5), Vector2(0.3, 5.6), Vector2(0.0, 5.9)], 24, stone)
	boxes.append([Vector3(FOUNTAIN.x, fy + 0.6, FOUNTAIN.y), Vector3(15.0, 1.2, 15.0), 0.0])
	boxes.append([Vector3(FOUNTAIN.x, fy + 0.6, FOUNTAIN.y), Vector3(15.0, 1.2, 15.0), PI * 0.25])
	_use(FOUNTAIN, 10.0)
	var pool := MeshInstance3D.new()
	pool.name = "FountainPool"
	var disc := CylinderMesh.new()
	disc.top_radius = 7.7
	disc.bottom_radius = 7.7
	disc.height = 0.05
	disc.radial_segments = 40
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.05, 0.12, 0.16)
	wm.roughness = 0.04
	wm.metallic = 0.3
	disc.material = _save_res(wm, "fountain_water_mat")
	pool.mesh = _save_res(disc, "fountain_water")
	pool.position = Vector3(FOUNTAIN.x, fy + 0.7, FOUNTAIN.y)
	root.add_child(pool)
	var glow := OmniLight3D.new()
	glow.name = "FountainLight"
	glow.position = Vector3(FOUNTAIN.x, fy + 1.4, FOUNTAIN.y)
	glow.light_color = Color(0.45, 0.75, 1.0)
	glow.light_energy = 1.4
	glow.omni_range = 14.0
	glow.set_meta(&"no_shadow", true)
	root.add_child(glow)
	# Benches round the fountain, facing it, and people on them or strolling round.
	for i in range(8):
		var a: float = TAU * float(i) / 8.0 + 0.2
		var bq: Vector2 = FOUNTAIN + Vector2(cos(a), sin(a)) * 12.5
		var face: Vector2 = (FOUNTAIN - bq).normalized()
		kit.set_frame(_xf(bq, atan2(-face.x, -face.y) + PI, 2.0))
		road.bench(k, 1.8)
		boxes.append([Vector3(bq.x, fy + 0.9, bq.y), Vector3(3.8, 1.8, 1.4), -atan2(face.y, face.x) + PI * 0.5])
		_use(bq, 2.2)
		if rng.randf() < 0.6:
			_person(bq + face * 0.15, face, rng.randi_range(0, 6), true, fy + 0.88)
	for i in range(24):
		var a2: float = rng.randf() * TAU
		var pq: Vector2 = FOUNTAIN + Vector2(cos(a2), sin(a2)) * rng.randf_range(15.0, 30.0)
		if _clear(pq, 0.6, 3.0) and _path_distance(_alts[1], pq) > 10.0:
			_person(pq, Vector2(cos(a2 + PI), sin(a2 + PI)), _pose(rng, STREET_POSES))
	# Benches along the paved path's west verge.
	var ps: Array = _span(Vector2(-120.0, -20.0), Vector2(-120.0, 130.0))
	var s: float = float(ps[0]) + 6.0
	while s < float(ps[1]):
		var spot: Dictionary = _spot(_main, s, STREET_HALF + 3.2)
		var q: Vector2 = spot["p2"]
		if _clear(q, 1.6, 2.0) and _path_distance(_alts[1], q) > 12.0:
			var rt: Vector3 = spot["right"]
			var face2: Vector2 = -Vector2(rt.x, rt.z)
			kit.set_frame(_xf(q, atan2(-face2.x, -face2.y) + PI, 2.0))
			road.bench(k, 1.8)
			boxes.append([Vector3(q.x, _ground_y(q) + 0.9, q.y), Vector3(3.8, 1.8, 1.4), deg_to_rad(float(spot["yaw"]))])
			_use(q, 2.2)
			if rng.randf() < 0.5:
				_person(q + face2 * 0.15, face2, rng.randi_range(0, 6), true, _ground_y(q) + 0.88)
		s += 24.0
	kit.reset_frame()
	# The hedge along Mtaa Road and along the club's wall.
	var hedge_col := Color(0.16, 0.30, 0.12)
	for run in [[Vector2(PARK.position.x, PARK.position.y - 1.0), Vector2(PARK.end.x - 3.0, PARK.position.y - 1.0)],
			[Vector2(PARK.position.x - 1.0, PARK.position.y), Vector2(PARK.position.x - 1.0, PARK.end.y - 4.0)]]:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var mid: Vector2 = (a + b) * 0.5
		var len: float = a.distance_to(b)
		var yaw2: float = -atan2((b - a).y, (b - a).x)
		kit.box(k, "matte", Transform3D(Basis(Vector3.UP, yaw2), Vector3(mid.x, _ground_y(mid) + 0.9, mid.y)), Vector3(len, 1.8, 1.6), hedge_col)
		boxes.append([Vector3(mid.x, _ground_y(mid) + 0.9, mid.y), Vector3(len, 1.8, 1.6), yaw2])
	_commit(root, kit, k, "ParkFurniture", 420.0)
	_boxes_body(root, "ParkBodies", boxes, "rock")


## The church on Kanisa Road: a whitewashed nave under a red iron roof, a bell tower with a lit cross, its
## name on a board by the road, and the faithful outside.
func _build_church(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "Kanisa"
	parent.add_child(root)
	var b = Nyota.Builder.new()
	var white := Color(0.93, 0.91, 0.86, A_PLAIN)
	var y0: float = _ground_y(CHURCH.get_center()) - 0.3
	var nave := Rect2(-394.0, -183.0, 30.0, 16.0)
	_walls(b, nave, y0, y0 + 10.0, white, 0)
	_pitched_roof(b, nave, y0 + 10.0, Color(0.62, 0.16, 0.12), 6.0)
	var tower := Rect2(-403.0, -179.0, 8.0, 8.0)
	_walls(b, tower, y0, y0 + 24.0, white, 0)
	_flat_roof(b, tower, y0 + 24.0, white)
	b.box(Vector3(tower.get_center().x, y0 + 24.5, tower.get_center().y), Vector3(9.0, 1.0, 9.0), 0.0, Color(0.80, 0.78, 0.74, A_PLAIN))
	var mi := MeshInstance3D.new()
	mi.name = "ChurchBuilding"
	mi.mesh = _save_res(b.commit(), "church")
	mi.material_override = _building_material()
	root.add_child(mi)
	_boxes_body(root, "ChurchBody", [
		[Vector3(nave.get_center().x, y0 + 8.0, nave.get_center().y), Vector3(nave.size.x, 16.0, nave.size.y), 0.0],
		[Vector3(tower.get_center().x, y0 + 12.5, tower.get_center().y), Vector3(9.0, 25.0, 9.0), 0.0],
	], "rock")
	# The cross on the tower, in neon, and a pool of its light.
	var kit := _kit()
	var k := {}
	var top := Vector3(tower.get_center().x, y0 + 25.0, tower.get_center().y)
	kit.block(k, "neon", top + Vector3(-0.3, 0.0, -0.3), top + Vector3(0.3, 6.0, 0.3), Color(0.92, 0.96, 1.0))
	kit.block(k, "neon", top + Vector3(-0.3, 3.6, -1.9), top + Vector3(0.3, 4.2, 1.9), Color(0.92, 0.96, 1.0))
	_commit(root, kit, k, "ChurchCross", 1500.0, false)
	k = {}
	# Its name on a board by the road.
	var bq := Vector2(-411.5, -197.0)
	var by: float = _ground_y(bq)
	kit.box(k, "paint", Transform3D(Basis(), Vector3(bq.x, by + 4.4, bq.y)), Vector3(0.3, 2.4, 13.0), Color(0.08, 0.12, 0.32))
	for pz in [-5.5, 5.5]:
		kit.tube(k, "metal", Vector3(bq.x + 0.3, by, bq.y + float(pz)), Vector3(bq.x + 0.3, by + 3.3, bq.y + float(pz)), 0.12, 0.12, 8, Color(0.5, 0.5, 0.52))
	_commit(root, kit, k, "ChurchSign", 500.0)
	var sign := Label3D.new()
	sign.name = "ChurchNameLabel"
	sign.text = "KANISA LA AMANI"
	sign.font_size = 64
	sign.pixel_size = 0.02
	sign.outline_size = 12
	sign.modulate = Color(1.0, 0.95, 0.85)
	sign.outline_modulate = Color(0.04, 0.06, 0.2)
	sign.position = Vector3(bq.x - 0.2, by + 4.4, bq.y)
	sign.rotation_degrees = Vector3(0, -90, 0)
	root.add_child(sign)
	_use(bq, 7.0)
	for i in range(14):
		var q := Vector2(rng.randf_range(-412.0, -406.0), rng.randf_range(-186.0, -164.0))
		_person(q, Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), _pose(rng, [[7, 0.5], [11, 0.2], [13, 0.3]]))


## A sign before each fork: an arrow board each way, the loose route's in orange, the paved one's in
## blue, on posts at the road's right side, facing the traffic.
func _build_fork_signs(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "ForkSigns"
	parent.add_child(root)
	var kit := _kit()
	var k := {}
	var boxes: Array = []
	var signs := [
		[_alts[0], "JUA KALI LANE", "MURRAM", "BIASHARA ST", "TARMAC"],
		[_alts[1], "BUSTANI LAWN", "OFF-ROAD", "PARK ROAD", "PAVED"],
		[_alts[2], "BACKSTAGE", "GRAVEL", "DANCEFLOOR", "PAVED"],
	]
	for sg in signs:
		var alt: Dictionary = sg[0]
		var s_fork: float = _s_near(_main, _at(alt, 0.0)["p"])
		var s: float = s_fork - 10.0
		var half: float = _half(_main, s)
		var spot: Dictionary = _spot(_main, s, half + 2.4)
		var q: Vector2 = spot["p2"]
		var fwd: Vector3 = spot["fwd"]
		var rt: Vector3 = spot["right"]
		var y: float = _ground_y(q)
		var face: Vector3 = -fwd
		# Two boards side by side across the verge: left the paved route (straight on), right the loose.
		for j in range(2):
			var c: Vector3 = Vector3(q.x, y + 6.2, q.y) + rt * (float(j) * 7.4 - 3.7) + rt * 3.7
			var col := Color(0.10, 0.28, 0.62) if j == 0 else Color(0.85, 0.36, 0.06)
			kit.box(k, "paint", Transform3D(Basis(rt, Vector3.UP, -face), c), Vector3(7.0, 3.6, 0.2), col)
			# The arrow: straight up the board for the paved route, turning right for the loose one.
			var tip: Vector3 = c + face * 0.12 + Vector3(0, 1.45, 0) if j == 0 else c + face * 0.12 + rt * 3.0 + Vector3(0, 0.6, 0)
			var dir: Vector3 = Vector3.UP if j == 0 else rt
			var perp: Vector3 = rt if j == 0 else Vector3.UP
			var base: Vector3 = tip - dir * 1.1
			kit.tri(k, "neon", tip, base + perp * 0.8, base - perp * 0.8, face, face, face, Color(1, 1, 1), face)
			kit.box(k, "neon", Transform3D(Basis(perp, dir, face), base - dir * 0.6), Vector3(0.45, 1.3, 0.05), Color(1, 1, 1))
			for line in range(2):
				var lab := Label3D.new()
				lab.name = "ForkLabel"
				lab.text = String(sg[(3 if j == 0 else 1) + line])
				lab.font_size = 40 if line == 0 else 32
				lab.pixel_size = 0.02
				lab.outline_size = 10
				lab.modulate = Color(1, 1, 1)
				lab.outline_modulate = col.darkened(0.5)
				lab.position = c + face * 0.14 + Vector3(0, -0.55 - float(line) * 0.85, 0)
				lab.basis = Basis(rt, Vector3.UP, face)
				root.add_child(lab)
			for px in [-2.8, 2.8]:
				var pp: Vector3 = Vector3(c.x, y, c.z) + rt * float(px)
				kit.tube(k, "metal", pp, pp + Vector3(0, 4.4, 0), 0.14, 0.14, 8, Color(0.5, 0.5, 0.52))
				boxes.append([pp + Vector3(0, 2.2, 0), Vector3(0.4, 4.4, 0.4), 0.0])
		_use(q + Vector2(rt.x, rt.z) * 3.7, 7.5)
	_commit(root, kit, k, "ForkSignBoards", 500.0)
	_boxes_body(root, "ForkSignBodies", boxes, "rock")


# ======================================================================================
#  Club Kilele
# ======================================================================================

const CLUB_WALL_H := 4.2
## The gates: the east one's z span (the lane comes in at z = 150), the north one's x span (Kanisa Road
## goes out at x = -420).
const GATE_E := Vector2(137.0, 163.0)
const GATE_N := Vector2(-433.0, -407.0)
const MURAL := [Color(0.95, 0.20, 0.55), Color(0.10, 0.62, 0.66), Color(0.98, 0.76, 0.16), Color(0.45, 0.22, 0.70), Color(0.96, 0.46, 0.12), Color(0.15, 0.40, 0.75)]
const DECK_Y := 2.2


## A box in the kit from its centre and size, turned by yaw.
func _kbox(kit: PropKit, k: Dictionary, key: String, c: Vector3, size: Vector3, col: Color, yaw := 0.0) -> void:
	kit.box(k, key, Transform3D(Basis(Vector3.UP, yaw), c), size, col)


## A square truss from a to b: four chords and zigzag braces.
func _truss(kit: PropKit, k: Dictionary, a: Vector3, b: Vector3, w: float) -> void:
	var ax: Vector3 = (b - a).normalized()
	var s1: Vector3 = ax.cross(Vector3.UP if absf(ax.y) < 0.9 else Vector3.RIGHT).normalized()
	var s2: Vector3 = ax.cross(s1).normalized()
	var col := Color(0.70, 0.71, 0.73)
	var corners: Array = [(s1 + s2) * w * 0.5, (s1 - s2) * w * 0.5, (-s1 - s2) * w * 0.5, (-s1 + s2) * w * 0.5]
	for c in corners:
		kit.tube(k, "metal", a + c, b + c, 0.05, 0.05, 6, col, false)
	var len: float = a.distance_to(b)
	var n: int = maxi(1, int(len / 1.2))
	for i in range(n):
		var p0: Vector3 = a + ax * len * float(i) / float(n)
		var p1: Vector3 = a + ax * len * float(i + 1) / float(n)
		for j in range(4):
			var c0: Vector3 = corners[j]
			var c1: Vector3 = corners[(j + 1) % 4]
			kit.tube(k, "metal", p0 + c0, p1 + c1, 0.025, 0.025, 4, col, false)


## A cone along -y from the origin, `length` long, radius r0 at the tip and r1 at the end; UV.y 0 at the
## tip to 1 at the end (club_beam.gdshader fades along it).
func _cone_mesh(length: float, r0: float, r1: float, segs := 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	for i in range(rings):
		for j in range(segs):
			var t0: float = float(i) / float(rings)
			var t1: float = float(i + 1) / float(rings)
			var a0: float = TAU * float(j) / float(segs)
			var a1: float = TAU * float(j + 1) / float(segs)
			var pts: Array = []
			for tv in [[t0, a0], [t0, a1], [t1, a1], [t1, a0]]:
				var t: float = tv[0]
				var r: float = lerpf(r0, r1, t)
				pts.append([Vector3(cos(tv[1]) * r, -t * length, sin(tv[1]) * r), Vector3(cos(tv[1]), 0.0, sin(tv[1])), t])
			for tri in [[0, 2, 1], [0, 3, 2]]:
				for v in tri:
					st.set_normal(pts[v][1])
					st.set_uv(Vector2(0.0, pts[v][2]))
					st.add_vertex(pts[v][0])
	return st.commit()


func _label(parent: Node, label_name: String, text: String, pos: Vector3, yaw_deg: float, size: int, col: Color, outline: Color) -> Label3D:
	var l := Label3D.new()
	l.name = label_name
	l.text = text
	l.font_size = size
	l.pixel_size = 0.02
	l.outline_size = maxi(8, size / 8)
	l.modulate = col
	l.outline_modulate = outline
	l.shaded = false
	l.position = pos
	l.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(l)
	return l


func _build_club(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.name = "ClubKilele"
	parent.add_child(root)
	var kit := _kit()
	var k := {}
	var boxes: Array = []

	# --- The walls, painted with a mural in bands, and the gates' pylons and lintels. ---
	var segs: Array = [
		[Vector2(CLUB.position.x, CLUB.position.y), Vector2(GATE_N.x, CLUB.position.y)],
		[Vector2(GATE_N.y, CLUB.position.y), Vector2(CLUB.end.x, CLUB.position.y)],
		[Vector2(CLUB.end.x, CLUB.position.y), Vector2(CLUB.end.x, GATE_E.x)],
		[Vector2(CLUB.end.x, GATE_E.y), Vector2(CLUB.end.x, CLUB.end.y)],
		[Vector2(CLUB.position.x, CLUB.end.y), Vector2(CLUB.end.x, CLUB.end.y)],
		[Vector2(CLUB.position.x, CLUB.position.y), Vector2(CLUB.position.x, CLUB.end.y)],
	]
	for sg in segs:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var len: float = a.distance_to(b)
		var d: Vector2 = (b - a) / len
		var yaw: float = -atan2(d.y, d.x)
		var n: int = maxi(1, int(len / 6.0))
		for i in range(n):
			var q: Vector2 = a + d * (float(i) + 0.5) * len / float(n)
			var y: float = _ground_y(q)
			var col: Color = MURAL[(i + int(absf(a.x + a.y))) % MURAL.size()]
			_kbox(kit, k, "matte", Vector3(q.x, y + 0.5, q.y), Vector3(len / float(n) + 0.02, 1.0, 1.0), Color(0.12, 0.10, 0.12), yaw)
			_kbox(kit, k, "matte", Vector3(q.x, y + 1.0 + (CLUB_WALL_H - 1.0) * 0.5, q.y), Vector3(len / float(n) + 0.02, CLUB_WALL_H - 1.0, 1.0), col.lerp(Color(0.9, 0.85, 0.8), 0.15 * float(i % 3)), yaw)
		var mid: Vector2 = (a + b) * 0.5
		boxes.append([Vector3(mid.x, _ground_y(mid) + CLUB_WALL_H * 0.5, mid.y), Vector3(len, CLUB_WALL_H, 1.0), yaw])
	# Gate arches.
	var gates := [
		[Vector3(CLUB.end.x - 1.0, 0.0, GATE_E.x - 3.0), Vector3(CLUB.end.x - 1.0, 0.0, GATE_E.y + 3.0), "CLUB KILELE", 90.0, Color(3.2, 0.6, 2.2)],
		[Vector3(GATE_N.x - 3.0, 0.0, CLUB.position.y + 1.0), Vector3(GATE_N.y + 3.0, 0.0, CLUB.position.y + 1.0), "ASANTE  KWAHERI", 0.0, Color(0.5, 2.4, 3.0)],
	]
	for g in gates:
		var p0: Vector3 = g[0]
		var p1: Vector3 = g[1]
		for p in [p0, p1]:
			var gy: float = _ground_y(Vector2(p.x, p.z))
			_kbox(kit, k, "matte", Vector3(p.x, gy + 6.5, p.z), Vector3(3.6, 13.0, 3.6), Color(0.10, 0.09, 0.12))
			kit.block(k, "neon", Vector3(p.x - 1.85, gy + 0.5, p.z - 0.2), Vector3(p.x - 1.75, gy + 12.5, p.z + 0.2), Color(1.0, 0.3, 0.8))
			kit.block(k, "neon", Vector3(p.x + 1.75, gy + 0.5, p.z - 0.2), Vector3(p.x + 1.85, gy + 12.5, p.z + 0.2), Color(0.3, 0.9, 1.0))
			boxes.append([Vector3(p.x, gy + 6.5, p.z), Vector3(3.6, 13.0, 3.6), 0.0])
		var mid3: Vector3 = (p0 + p1) * 0.5
		var span: Vector3 = p1 - p0
		var along_z: bool = absf(span.z) > absf(span.x)
		var lsize := Vector3(2.6, 3.0, span.length() + 3.6) if along_z else Vector3(span.length() + 3.6, 3.0, 2.6)
		var gy2: float = _ground_y(Vector2(mid3.x, mid3.z))
		_kbox(kit, k, "matte", Vector3(mid3.x, gy2 + 11.5, mid3.z), lsize, Color(0.08, 0.07, 0.10))
		var face := Vector3(1, 0, 0) if along_z else Vector3(0, 0, 1)
		var lab_pos: Vector3 = Vector3(mid3.x, gy2 + 11.5, mid3.z) + face * 1.35
		_label(root, "GateLabel", g[2], lab_pos, g[3], 150, g[4], Color(0.15, 0.02, 0.2))
		# Neon lines above and below the name.
		for dy in [-1.25, 1.25]:
			var c: Vector3 = lab_pos + Vector3(0, dy, 0) + face * 0.02
			var hs: Vector3 = (Vector3(0, 0, lsize.z * 0.45) if along_z else Vector3(lsize.x * 0.45, 0, 0))
			kit.block(k, "neon", c - hs - Vector3(0.03, 0.06, 0.03), c + hs + Vector3(0.03, 0.06, 0.03), Color(1.0, 0.85, 0.3))

	# --- The stage: a deck, a truss over it, the LED wall, the DJ booth, the sound. ---
	var sy: float = _ground_y(STAGE.get_center())
	var sc: Vector2 = STAGE.get_center()
	_kbox(kit, k, "matte", Vector3(sc.x, sy + DECK_Y * 0.5, sc.y), Vector3(STAGE.size.x, DECK_Y, STAGE.size.y), Color(0.06, 0.06, 0.07))
	kit.block(k, "neon", Vector3(STAGE.position.x, sy + DECK_Y - 0.12, STAGE.end.y + 0.01), Vector3(STAGE.end.x, sy + DECK_Y - 0.02, STAGE.end.y + 0.06), Color(1.0, 0.25, 0.7))
	boxes.append([Vector3(sc.x, sy + DECK_Y * 0.5, sc.y), Vector3(STAGE.size.x, DECK_Y, STAGE.size.y), 0.0])
	var tr := STAGE.grow(1.0)
	var top_y: float = sy + 19.0
	var cols := [Vector2(tr.position.x, tr.position.y), Vector2(tr.end.x, tr.position.y), Vector2(tr.end.x, tr.end.y), Vector2(tr.position.x, tr.end.y)]
	for c in cols:
		_truss(kit, k, Vector3(c.x, sy, c.y), Vector3(c.x, top_y, c.y), 0.9)
		_kbox(kit, k, "metal", Vector3(c.x, sy + 0.1, c.y), Vector3(1.6, 0.2, 1.6), Color(0.3, 0.3, 0.32))
		boxes.append([Vector3(c.x, sy + top_y * 0.5, c.y), Vector3(1.2, top_y - sy, 1.2), 0.0])
	for i in range(4):
		var a: Vector2 = cols[i]
		var b: Vector2 = cols[(i + 1) % 4]
		_truss(kit, k, Vector3(a.x, top_y, a.y), Vector3(b.x, top_y, b.y), 0.9)
	# A dark canopy over the back half.
	_kbox(kit, k, "canvas", Vector3(sc.x, top_y + 0.8, tr.position.y + tr.size.y * 0.3), Vector3(tr.size.x + 1.0, 0.15, tr.size.y * 0.6), Color(0.05, 0.05, 0.06))
	# The LED wall and its frame.
	var wall_w := 36.0
	var wall_h := 12.5
	var wall_y0: float = sy + DECK_Y + 1.2
	var wall_z: float = STAGE.position.y + 1.6
	_kbox(kit, k, "matte", Vector3(sc.x, wall_y0 + wall_h * 0.5, wall_z - 0.35), Vector3(wall_w + 1.2, wall_h + 1.2, 0.6), Color(0.04, 0.04, 0.05))
	var screen_mat := ShaderMaterial.new()
	screen_mat.shader = load("res://club_screen.gdshader")
	screen_mat.set_shader_parameter("aspect", wall_w / wall_h)
	screen_mat = _save_res(screen_mat, "screen_mat") as ShaderMaterial
	var screen := MeshInstance3D.new()
	screen.name = "LedWallScreen"
	var qm := QuadMesh.new()
	qm.size = Vector2(wall_w, wall_h)
	screen.mesh = _save_res(qm, "screen_quad")
	screen.material_override = screen_mat
	screen.position = Vector3(sc.x, wall_y0 + wall_h * 0.5, wall_z)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(screen)
	# The DJ booth at the front of the deck, the DJ and two MCs.
	var booth := Vector3(sc.x, sy + DECK_Y, STAGE.end.y - 6.0)
	_kbox(kit, k, "matte", booth + Vector3(0, 0.75, 0), Vector3(9.0, 1.5, 2.6), Color(0.08, 0.08, 0.09))
	kit.block(k, "neon", booth + Vector3(-4.4, 0.2, 1.31), booth + Vector3(4.4, 1.3, 1.36), Color(0.35, 0.2, 1.0))
	for dx in [-2.6, 0.0, 2.6]:
		_kbox(kit, k, "metal", booth + Vector3(dx, 1.58, -0.1), Vector3(1.8, 0.16, 1.6), Color(0.2, 0.2, 0.22))
	_person(Vector2(booth.x, booth.z - 2.2), Vector2(0, 1), 9, false, booth.y)
	_person(Vector2(booth.x - 6.0, booth.z - 1.0), Vector2(0, 1), 14, false, booth.y)
	_person(Vector2(booth.x + 6.0, booth.z - 1.0), Vector2(0, 1), 8, false, booth.y)
	# Line arrays hanging from the front truss, sub stacks either side of the stage.
	for sx in [STAGE.position.x + 3.0, STAGE.end.x - 3.0]:
		_kbox(kit, k, "matte", Vector3(sx, top_y - 5.5, tr.end.y + 0.8), Vector3(1.8, 8.5, 1.8), Color(0.05, 0.05, 0.06))
	for sx2 in [STAGE.position.x - 4.5, STAGE.end.x + 4.5]:
		for tier in range(2):
			_kbox(kit, k, "matte", Vector3(sx2, sy + 1.3 + float(tier) * 2.6, STAGE.end.y + 3.0), Vector3(3.6, 2.5, 3.0), Color(0.05, 0.05, 0.06))
		boxes.append([Vector3(sx2, sy + 2.6, STAGE.end.y + 3.0), Vector3(3.6, 5.2, 3.0), 0.0])
	# The VIP deck west of the stage, and a fence behind both.
	var vip := Rect2(-410.0, 98.0, 32.0, 28.0)
	var vc: Vector2 = vip.get_center()
	_kbox(kit, k, "timber", Vector3(vc.x, sy + 0.6, vc.y), Vector3(vip.size.x, 1.2, vip.size.y), Color(0.36, 0.24, 0.16))
	kit.block(k, "neon", Vector3(vip.position.x, sy + 1.05, vip.end.y + 0.01), Vector3(vip.end.x, sy + 1.15, vip.end.y + 0.06), Color(0.95, 0.75, 0.25))
	for i in range(6):
		var sq := Vector3(vip.position.x + 4.0 + float(i) * 4.8, sy + 1.2, vip.position.y + 6.0 + float(i % 2) * 10.0)
		_kbox(kit, k, "canvas", sq + Vector3(0, 0.4, 0), Vector3(3.6, 0.8, 1.6), Color(0.85, 0.82, 0.76))
		_person(Vector2(sq.x, sq.z), Vector2(0, 1), rng.randi_range(0, 6), true, sq.y + 0.84)
	_label(root, "VipLabel", "VIP", Vector3(vc.x, sy + 4.0, vip.end.y + 0.5), 0.0, 120, Color(3.0, 2.2, 0.6), Color(0.2, 0.1, 0.0))
	_kbox(kit, k, "matte", Vector3(vc.x, sy + 3.2, vip.end.y + 0.3), Vector3(6.0, 2.6, 0.3), Color(0.05, 0.04, 0.06))
	boxes.append([Vector3(vc.x, sy + 0.6, vc.y), Vector3(vip.size.x, 1.2, vip.size.y), 0.0])
	var fence_z: float = STAGE.position.y - 4.0
	_kbox(kit, k, "matte", Vector3((vip.position.x + STAGE.end.x) * 0.5, sy + 1.4, fence_z), Vector3(STAGE.end.x - vip.position.x, 2.8, 0.4), Color(0.12, 0.12, 0.14))
	boxes.append([Vector3((vip.position.x + STAGE.end.x) * 0.5, sy + 1.4, fence_z), Vector3(STAGE.end.x - vip.position.x, 2.8, 0.4), 0.0])

	# --- The dancefloor. ---
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = load("res://club_dancefloor.gdshader")
	floor_mat.set_shader_parameter("size", DANCEFLOOR.size)
	floor_mat = _save_res(floor_mat, "dancefloor_mat") as ShaderMaterial
	var fst := SurfaceTool.new()
	fst.begin(Mesh.PRIMITIVE_TRIANGLES)
	var f0 := Vector3(DANCEFLOOR.position.x, 0.025, DANCEFLOOR.position.y)
	var fc := [f0, f0 + Vector3(DANCEFLOOR.size.x, 0, 0), f0 + Vector3(DANCEFLOOR.size.x, 0, DANCEFLOOR.size.y), f0 + Vector3(0, 0, DANCEFLOOR.size.y)]
	var fuv := [Vector2(0, 0), Vector2(DANCEFLOOR.size.x, 0), DANCEFLOOR.size, Vector2(0, DANCEFLOOR.size.y)]
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for v in tri:
			fst.set_normal(Vector3.UP)
			fst.set_uv(fuv[v])
			fst.add_vertex(fc[v])
	var dance := MeshInstance3D.new()
	dance.name = "DanceDeckFloor"
	dance.mesh = _save_res(fst.commit(), "dancefloor")
	dance.material_override = floor_mat
	root.add_child(dance)
	for e in [[Vector2(DANCEFLOOR.position.x, DANCEFLOOR.position.y), Vector2(DANCEFLOOR.end.x, DANCEFLOOR.position.y)],
			[Vector2(DANCEFLOOR.position.x, DANCEFLOOR.end.y), Vector2(DANCEFLOOR.end.x, DANCEFLOOR.end.y)],
			[Vector2(DANCEFLOOR.position.x, DANCEFLOOR.position.y), Vector2(DANCEFLOOR.position.x, DANCEFLOOR.end.y)],
			[Vector2(DANCEFLOOR.end.x, DANCEFLOOR.position.y), Vector2(DANCEFLOOR.end.x, DANCEFLOOR.end.y)]]:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var lo := Vector3(minf(a.x, b.x) - 0.15, 0.0, minf(a.y, b.y) - 0.15)
		var hi := Vector3(maxf(a.x, b.x) + 0.15, 0.035, maxf(a.y, b.y) + 0.15)
		kit.block(k, "chrome", lo, hi, Color(0.8, 0.8, 0.82))
	# Barriers along the lane, a neon tube along their top rail over the floor.
	var lane_s: Array = _span(Vector2(-286.0, 150.0), Vector2(-394.0, 150.0))
	_run_along(_barrier_runs, _main, float(lane_s[0]), float(lane_s[1]), STREET_HALF + 0.6)
	var lane_s2: Array = _span(Vector2(-258.0, 150.0), Vector2(-394.0, 150.0))
	_run_along(_barrier_runs, _main, float(lane_s2[0]), float(lane_s2[1]), -(STREET_HALF + 0.6))
	for side in [-1.0, 1.0]:
		var z: float = 150.0 - side * (STREET_HALF + 0.6)
		kit.tube(k, "neon", Vector3(DANCEFLOOR.position.x, 2.0, z), Vector3(DANCEFLOOR.end.x, 2.0, z), 0.06, 0.06, 6, Color(1.0, 0.3, 0.8) if side > 0.0 else Color(0.3, 0.9, 1.0))

	# --- Bars along the south wall. ---
	var bars := [[Rect2(-404.0, 186.0, 32.0, 20.0), "BAR KILELE", Color(3.0, 1.6, 0.4)], [Rect2(-336.0, 186.0, 32.0, 20.0), "NYAMA CHOMA", Color(3.0, 0.9, 0.3)]]
	for bar in bars:
		var r: Rect2 = bar[0]
		var c2: Vector2 = r.get_center()
		var by: float = _ground_y(c2)
		_kbox(kit, k, "wood", Vector3(c2.x, by + 1.2, r.position.y + 4.0), Vector3(r.size.x - 4.0, 2.4, 2.4), Color(0.30, 0.18, 0.10))
		kit.block(k, "neon", Vector3(r.position.x + 2.0, by + 0.25, r.position.y + 2.78), Vector3(r.end.x - 2.0, by + 0.35, r.position.y + 2.82), Color(1.0, 0.6, 0.15))
		_kbox(kit, k, "wood", Vector3(c2.x, by + 2.6, r.end.y - 2.0), Vector3(r.size.x - 4.0, 5.2, 1.4), Color(0.18, 0.12, 0.08))
		for shelf in range(3):
			for b2 in range(int(r.size.x - 6.0) * 2):
				var bx: float = r.position.x + 3.0 + float(b2) * 0.5
				var bcol := Color.from_hsv(rng.randf(), 0.7, 1.0)
				kit.block(k, "led", Vector3(bx, by + 2.2 + float(shelf) * 1.1, r.end.y - 2.8), Vector3(bx + 0.22, by + 2.75 + float(shelf) * 1.1, r.end.y - 2.6), bcol)
		# The canopy on posts, the bar's name in neon along its front.
		for px in [r.position.x + 1.0, c2.x, r.end.x - 1.0]:
			for pz in [r.position.y + 1.0, r.end.y - 0.5]:
				kit.tube(k, "metal", Vector3(px, by, pz), Vector3(px, by + 8.4, pz), 0.16, 0.16, 8, Color(0.25, 0.25, 0.27))
				boxes.append([Vector3(px, by + 4.2, pz), Vector3(0.5, 8.4, 0.5), 0.0])
		_kbox(kit, k, "canvas", Vector3(c2.x, by + 8.6, c2.y), Vector3(r.size.x + 2.0, 0.4, r.size.y + 1.0), Color(0.10, 0.08, 0.12))
		_label(root, "BarLabel", bar[1], Vector3(c2.x, by + 9.9, r.position.y + 0.4), 0.0, 120, bar[2], Color(0.2, 0.05, 0.0))
		boxes.append([Vector3(c2.x, by + 1.2, r.position.y + 4.0), Vector3(r.size.x - 4.0, 2.4, 2.4), 0.0])
		boxes.append([Vector3(c2.x, by + 2.6, r.end.y - 2.0), Vector3(r.size.x - 4.0, 5.2, 1.4), 0.0])
		var warm := OmniLight3D.new()
		warm.name = "BarLight"
		warm.position = Vector3(c2.x, by + 7.0, c2.y)
		warm.light_color = Color(1.0, 0.70, 0.40)
		warm.light_energy = 2.0
		warm.omni_range = 20.0
		warm.set_meta(&"no_shadow", true)
		root.add_child(warm)
		# Stools, the drinkers at the counter and the bartenders behind it.
		for i in range(int(r.size.x / 2.2)):
			var sx3: float = r.position.x + 3.0 + float(i) * 2.2
			kit.tube(k, "metal", Vector3(sx3, by, r.position.y + 1.6), Vector3(sx3, by + 1.4, r.position.y + 1.6), 0.07, 0.07, 6, Color(0.6, 0.6, 0.62))
			kit.lathe(k, "plastic", Vector3(sx3, by + 1.4, r.position.y + 1.6), [Vector2(0.45, 0.0), Vector2(0.45, 0.14), Vector2(0.0, 0.16)], 10, Color(0.8, 0.15, 0.3))
			if rng.randf() < 0.7:
				_person(Vector2(sx3, r.position.y + 1.6), Vector2(0, 1), rng.randi_range(0, 6), true, by + 1.55)
		for i in range(3):
			_person(Vector2(r.position.x + 6.0 + float(i) * 10.0, r.position.y + 6.4), Vector2(0, -1), _pose(rng, [[7, 0.4], [15, 0.3], [13, 0.3]]))
		for i in range(26):
			var pq := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y - 9.0, r.position.y - 1.0))
			if _clear(pq, 0.5, 4.0):
				_person(pq, Vector2(rng.randf_range(-0.5, 0.5), 1.0).normalized(), _pose(rng, [[15, 0.35], [7, 0.25], [8, 0.1], [9, 0.1], [10, 0.1], [13, 0.1]]))
		_use(c2, 12.0)

	# --- Festoon lights strung across the floor between two rows of poles. ---
	var bulbs: Array = []
	var pole_n: Array = []
	var pole_s: Array = []
	for i in range(6):
		var x: float = DANCEFLOOR.position.x - 8.0 + float(i) * (DANCEFLOOR.size.x + 16.0) / 5.0
		pole_n.append(Vector3(x, 0.0, DANCEFLOOR.position.y - 2.5))
		pole_s.append(Vector3(x, 0.0, DANCEFLOOR.end.y + 2.5))
	var pole_h := 10.5
	for p in pole_n + pole_s:
		kit.tube(k, "metal", p, p + Vector3(0, pole_h, 0), 0.17, 0.13, 8, Color(0.22, 0.22, 0.24))
		boxes.append([p + Vector3(0, pole_h * 0.5, 0), Vector3(0.5, pole_h, 0.5), 0.0])
		_use(Vector2(p.x, p.z), 0.8)
	var strings: Array = []
	for i in range(6):
		strings.append([pole_n[i], pole_s[i]])
		if i < 5:
			strings.append([pole_n[i], pole_s[i + 1]])
			strings.append([pole_n[i], pole_n[i + 1]])
			strings.append([pole_s[i], pole_s[i + 1]])
	for st in strings:
		var a3: Vector3 = (st[0] as Vector3) + Vector3(0, pole_h - 0.3, 0)
		var b3: Vector3 = (st[1] as Vector3) + Vector3(0, pole_h - 0.3, 0)
		var n2: int = int(a3.distance_to(b3) / 1.6)
		var prev: Vector3 = a3
		for j in range(1, n2 + 1):
			var t: float = float(j) / float(n2)
			var p2: Vector3 = a3.lerp(b3, t) - Vector3(0, 4.0 * 1.3 * t * (1.0 - t), 0)
			kit.tube(k, "matte", prev, p2, 0.02, 0.02, 3, Color(0.05, 0.05, 0.05), false)
			bulbs.append(Transform3D(Basis(), p2 - Vector3(0, 0.2, 0)))
			prev = p2
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.16
	bulb_mesh.height = 0.36
	bulb_mesh.radial_segments = 8
	bulb_mesh.rings = 4
	var bulb_mat := ShaderMaterial.new()
	bulb_mat.shader = load("res://neon_emissive.gdshader")
	bulb_mat.set_shader_parameter("energy", 5.0)
	bulb_mesh.material = _save_res(bulb_mat, "bulb_mat")
	var bmm := _multimesh(_save_res(bulb_mesh, "bulb"), bulbs, "FestoonBulbs")
	bmm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bmm)

	# --- The car park in the north of the grounds, a light tower each side. ---
	for i in range(10):
		var pq2 := Vector2(-395.0 + float(i % 5) * 12.0, 10.0 + float(i / 5) * 24.0)
		if not _clear(pq2, 3.0, 2.0):
			continue
		kit.set_frame(_xf(pq2, PI * 0.5 + (PI if i / 5 == 1 else 0.0), 2.0))
		CampKit.new(kit).vehicle(k, "suv", Color.from_hsv(rng.randf(), 0.5, rng.randf_range(0.3, 0.9)))
		kit.reset_frame()
		boxes.append([Vector3(pq2.x, _ground_y(pq2) + 1.8, pq2.y), Vector3(9.6, 3.6, 3.9), 0.0])
		_use(pq2, 5.0)
	for lt in [Vector2(-300.0, 20.0), Vector2(-400.0, 55.0)]:
		var ly: float = _ground_y(lt)
		kit.tube(k, "metal", Vector3(lt.x, ly, lt.y), Vector3(lt.x, ly + 16.0, lt.y), 0.3, 0.2, 8, Color(0.5, 0.5, 0.52))
		kit.block(k, "lamp", Vector3(lt.x - 1.5, ly + 15.6, lt.y - 0.4), Vector3(lt.x + 1.5, ly + 16.6, lt.y + 0.4), Color(1, 1, 1))
		boxes.append([Vector3(lt.x, ly + 8.0, lt.y), Vector3(0.8, 16.0, 0.8), 0.0])
		var ol := OmniLight3D.new()
		ol.name = "YardLight"
		ol.position = Vector3(lt.x, ly + 14.0, lt.y)
		ol.light_color = Color(0.95, 0.92, 0.85)
		ol.light_energy = 1.6
		ol.omni_range = 34.0
		ol.set_meta(&"no_shadow", true)
		root.add_child(ol)
		_use(lt, 1.5)

	# --- Backstage: trucks, generators and road cases along the gravel road. ---
	var back: Dictionary = _alts[2]
	var bs: float = _s_near(back, Vector2(-330.0, 80.0))
	for i in range(3):
		var sp: Dictionary = _spot(back, bs + float(i) * 22.0, ALLEY_HALF + 3.5)
		var q3: Vector2 = sp["p2"]
		if not _clear(q3, 2.5, 1.0):
			continue
		var yaw3: float = deg_to_rad(float(sp["yaw"]))
		kit.set_frame(_xf(q3, yaw3, 2.0))
		CampKit.new(kit).vehicle(k, "van", Color(0.85, 0.85, 0.86))
		kit.reset_frame()
		boxes.append([Vector3(q3.x, _ground_y(q3) + 2.0, q3.y), Vector3(4.0, 4.0, 11.0), yaw3])
		_use(q3, 5.5)
	for i in range(5):
		var sp2: Dictionary = _spot(back, bs - 10.0 + float(i) * 15.0, -(ALLEY_HALF + 2.5))
		var q4: Vector2 = sp2["p2"]
		if not _clear(q4, 1.6, 1.0):
			continue
		var yaw4: float = deg_to_rad(float(sp2["yaw"]))
		var y4: float = _ground_y(q4)
		if i % 2 == 0:
			_kbox(kit, k, "paint", Vector3(q4.x, y4 + 1.4, q4.y), Vector3(2.6, 2.8, 5.0), Color(0.85, 0.75, 0.15), yaw4)
			_kbox(kit, k, "matte", Vector3(q4.x, y4 + 2.9, q4.y), Vector3(0.4, 0.4, 0.4), Color(0.1, 0.1, 0.1), yaw4)
		else:
			for c3 in range(3):
				_kbox(kit, k, "matte", Vector3(q4.x, y4 + 0.6 + float(c3) * 1.2, q4.y), Vector3(2.2, 1.15, 1.6), Color(0.12, 0.12, 0.13), yaw4 + float(c3) * 0.2)
		boxes.append([Vector3(q4.x, y4 + 1.6, q4.y), Vector3(2.8, 3.2, 5.0), yaw4])
		_use(q4, 2.8)

	_commit(root, kit, k, "ClubBuild", 900.0)
	_boxes_body(root, "ClubBodies", boxes, "rock")

	# --- The light show (ClubLights.gd turns and colours it all). ---
	var show := Node3D.new()
	show.name = "ClubLights"
	show.set_script(load("res://ClubLights.gd"))
	root.add_child(show)
	var beam_mat := ShaderMaterial.new()
	beam_mat.shader = load("res://club_beam.gdshader")
	beam_mat.set_shader_parameter("energy", 0.32)
	beam_mat = _save_res(beam_mat, "beam_mat") as ShaderMaterial
	var laser_mat := ShaderMaterial.new()
	laser_mat.shader = beam_mat.shader
	laser_mat.set_shader_parameter("energy", 1.4)
	laser_mat.set_shader_parameter("near_fade", 4.0)
	laser_mat = _save_res(laser_mat, "laser_mat") as ShaderMaterial
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.7, 0.9, 0.7)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.08, 0.08, 0.09)
	head_mat.metallic = 0.5
	head_mat.roughness = 0.4
	head_mesh.material = _save_res(head_mat, "head_mat")
	var head_res: Mesh = _save_res(head_mesh, "moving_head")
	var hang_beam: Mesh = _save_res(_cone_mesh(34.0, 0.14, 2.6), "beam_hang")
	var sky_beam: Mesh = _save_res(_cone_mesh(70.0, 0.14, 3.4), "beam_sky")
	var laser_beam: Mesh = _save_res(_cone_mesh(110.0, 0.04, 0.09, 6), "beam_laser")
	var heads: Array[Node3D] = []
	var beams: Array[GeometryInstance3D] = []
	var head_spots: Array = []
	for i in range(10):
		head_spots.append([Vector3(STAGE.position.x + 3.0 + float(i) * (STAGE.size.x - 6.0) / 9.0, top_y - 0.9, tr.end.y + 0.2), -0.55, hang_beam])
	for i in range(6):
		head_spots.append([Vector3(STAGE.position.x + 5.0 + float(i) * (STAGE.size.x - 10.0) / 5.0, sy + DECK_Y + 0.5, STAGE.end.y - 1.0), PI + 0.3, sky_beam])
	for i in range(head_spots.size()):
		var hs: Array = head_spots[i]
		var pivot := Node3D.new()
		pivot.name = "Head_%d" % i
		pivot.position = hs[0]
		pivot.rotation = Vector3(float(hs[1]), 0.0, 0.0)
		show.add_child(pivot)
		var body := MeshInstance3D.new()
		body.name = "HeadBody"
		body.mesh = head_res
		pivot.add_child(body)
		var beam := MeshInstance3D.new()
		beam.name = "BeamCone"
		beam.mesh = hs[2]
		beam.material_override = beam_mat
		beam.position = Vector3(0, -0.45, 0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.extra_cull_margin = 8.0
		pivot.add_child(beam)
		heads.append(pivot)
		beams.append(beam)
	var lasers: Array[Node3D] = []
	var laser_meshes: Array[GeometryInstance3D] = []
	for i in range(8):
		var pivot2 := Node3D.new()
		pivot2.name = "Laser_%d" % i
		pivot2.position = Vector3(sc.x + (float(i) - 3.5) * 1.1, wall_y0 + wall_h + 0.8, wall_z + 0.4)
		show.add_child(pivot2)
		var lm := MeshInstance3D.new()
		lm.name = "LaserBeam"
		lm.mesh = laser_beam
		lm.material_override = laser_mat
		lm.rotation_degrees = Vector3(-90, 0, 0)
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lm.set_instance_shader_parameter(&"tint", Vector3(0.2, 1.0, 0.35) if i % 2 == 0 else Vector3(0.2, 0.85, 1.0))
		pivot2.add_child(lm)
		lasers.append(pivot2)
		laser_meshes.append(lm)
	var washes: Array[Light3D] = []
	for i in range(6):
		var w := OmniLight3D.new()
		w.name = "Wash_%d" % i
		w.position = Vector3(DANCEFLOOR.position.x + 8.0 + float(i % 3) * 22.0, 9.0, DANCEFLOOR.position.y + (6.0 if i < 3 else DANCEFLOOR.size.y - 6.0))
		w.omni_range = 19.0
		w.light_energy = 2.2
		w.set_meta(&"no_shadow", true)
		w.distance_fade_enabled = true
		w.distance_fade_begin = 220.0
		w.distance_fade_length = 40.0
		show.add_child(w)
		washes.append(w)
	show.set("heads", heads)
	show.set("beams", beams)
	show.set("lasers", lasers)
	show.set("laser_meshes", laser_meshes)
	show.set("washes", washes)
	show.set("floor_material", floor_mat)
	show.set("screen_material", screen_mat)

	# --- The crowd on the floor either side of the lane, in front of the stage and at the gate inside. ---
	for strip in [Rect2(DANCEFLOOR.position.x + 1.0, DANCEFLOOR.position.y + 1.2, DANCEFLOOR.size.x - 2.0, 150.0 - STREET_HALF - 2.2 - DANCEFLOOR.position.y - 1.2),
			Rect2(DANCEFLOOR.position.x + 1.0, 150.0 + STREET_HALF + 2.2, DANCEFLOOR.size.x - 2.0, DANCEFLOOR.end.y - 1.2 - (150.0 + STREET_HALF + 2.2)),
			Rect2(STAGE.position.x + 6.0, STAGE.end.y + 5.5, STAGE.size.x - 12.0, DANCEFLOOR.position.y - STAGE.end.y - 6.0)]:
		var r2: Rect2 = strip
		var z := r2.position.y + 0.6
		while z < r2.end.y:
			var x := r2.position.x + rng.randf_range(0.0, 0.8)
			while x < r2.end.x:
				var pq3 := Vector2(x + rng.randf_range(-0.35, 0.35), z + rng.randf_range(-0.35, 0.35))
				var ok := true
				for p in pole_n + pole_s:
					if Vector2(p.x, p.z).distance_to(pq3) < 1.0:
						ok = false
				if ok and rng.randf() < 0.88:
					var to_stage: Vector2 = (Vector2(sc.x, STAGE.end.y) - pq3).normalized()
					var y5: float = 0.03 if DANCEFLOOR.has_point(pq3) else _ground_y(pq3)
					_person(pq3, to_stage.rotated(rng.randf_range(-0.5, 0.5)), _pose(rng, DANCE_POSES), false, y5)
				x += rng.randf_range(1.45, 1.8)
			z += rng.randf_range(1.4, 1.7)
	print("  club: %d moving heads, %d lasers, %d bulbs" % [heads.size(), lasers.size(), bulbs.size()])


# ======================================================================================
#  Gameplay
# ======================================================================================

## A Path3D's curve along `path` from s0 for `length`, every 2m, at the road's height.
func _curve(path: Dictionary, s0: float, length: float, closed: bool) -> Curve3D:
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	var n: int = maxi(2, int(round(length / 2.0)))
	var pts: Array = []
	for i in range(n + (0 if closed else 1)):
		var s: float = s0 + length * float(i) / float(n)
		var p2: Vector2 = _at(path, s)["p"]
		pts.append(Vector3(p2.x, _road_h(path, s), p2.y))
	var m: int = pts.size()
	for i in range(m + (1 if closed else 0)):
		var k: int = i % m
		var a: Vector3 = pts[(k - 1 + m) % m] if (closed or k > 0) else pts[k]
		var c: Vector3 = pts[(k + 1) % m] if (closed or k < m - 1) else pts[k]
		var hnd: Vector3 = (c - a) / (6.0 if (closed or (k > 0 and k < m - 1)) else 3.0)
		curve.add_point(pts[k], -hnd, hnd)
	return curve


func _place_gameplay(level: Node3D) -> Path3D:
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	# The curve starts FINISH_S before the line, like the other generated levels.
	track_path.curve = _curve(_main, 0.0, _main["len"], true)
	level.add_child(track_path)
	var alt_root := Node3D.new()
	alt_root.name = "AlternativePaths"
	level.add_child(alt_root)
	for alt in _alts:
		var p := Path3D.new()
		p.name = alt["name"]
		p.curve = _curve(alt, 0.0, alt["len"], false)
		alt_root.add_child(p)

	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var fl: Dictionary = _spot(_main, FINISH_S, 0.0, 0.06)
	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = fl["pos"]
	finish_line.rotation_degrees = Vector3(0, fl["yaw"], 0)
	finish_line.set("is_finish_line", true)
	level.add_child(finish_line)
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	finish_line.add_child(spawn_points)
	var grid := [Vector3(-3.2, 0.05, 5.0), Vector3(3.2, 0.05, 5.0), Vector3(-3.2, 0.05, 12.5), Vector3(3.2, 0.05, 12.5), Vector3(-3.2, 0.05, 20.0), Vector3(3.2, 0.05, 20.0)]
	for i in range(grid.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid[i]
		spawn_points.add_child(sp)
		if spawn_scene:
			var si = spawn_scene.instantiate()
			si.name = "SpawnIndicator"
			sp.add_child(si)

	# Checkpoints on the trunk only (never on lap a fork bypasses): Mtaa Road's murram and Kanisa Road.
	var cps := Node3D.new()
	cps.name = "Checkpoints"
	level.add_child(cps)
	var cp_s: Array = [_s_near(_main, Vector2(-70.0, -40.0)), _s_near(_main, Vector2(-420.0, -55.0))]
	cp_s.sort()
	for i in range(cp_s.size()):
		var c: Dictionary = _spot(_main, cp_s[i], 0.0, 0.1)
		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = c["pos"]
		gate.rotation_degrees = Vector3(0, c["yaw"], 0)
		cps.add_child(gate)
		print("  checkpoint %d at %.0fm" % [i + 1, cp_s[i]])

	# Boost pads: on the avenue after the start, on the lawn before the mound, out of the club.
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var pads := Node3D.new()
	pads.name = "BoostPads"
	level.add_child(pads)
	var pad_defs := [
		["Boost_Avenue_L", _main, _s_near(_main, Vector2(-250.0, -250.0)), -3.2],
		["Boost_Avenue_R", _main, _s_near(_main, Vector2(-250.0, -250.0)), 3.2],
		["Boost_Lawn", _alts[1], _s_near(_alts[1], Vector2(-134.0, 26.0)), 0.0],
		["Boost_Kanisa", _main, _s_near(_main, Vector2(-420.0, 5.0)), 0.0],
	]
	for pd in pad_defs:
		var bp = boost_scene.instantiate()
		bp.name = pd[0]
		var sp2: Dictionary = _spot(pd[1], pd[2], pd[3], 0.08)
		bp.position = sp2["pos"]
		bp.rotation_degrees = Vector3(0, sp2["yaw"], 0)
		pads.add_child(bp)

	# Item boxes in rows on calm stretches of the trunk.
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var items := Node3D.new()
	items.name = "ItemBoxes"
	level.add_child(items)
	var rows := [Vector2(-300.0, -250.0), Vector2(-20.0, -250.0), Vector2(-15.0, -40.0), Vector2(-420.0, -170.0), Vector2(-292.0, 150.0)]
	var n := 1
	for rq in rows:
		var s: float = _s_near(_main, rq)
		for lat in [-4.0, 0.0, 4.0]:
			var ib = item_scene.instantiate()
			ib.name = "ItemBox_%d" % n
			ib.position = _spot(_main, s, lat, 1.4)["pos"]
			items.add_child(ib)
			n += 1

	# The jumps: a plank table-top in the alley, a loading-ramp kicker backstage.
	var ramp_scene: PackedScene = load("res://WoodenRamp.tscn")
	var jumps := Node3D.new()
	jumps.name = "PlankJumps"
	level.add_child(jumps)
	var lips: Array = []
	var jump_defs := [
		["AlleyJump", _alts[0], _s_near(_alts[0], Vector2(105.0, -150.0)), {"length": 6.0, "height": 1.2, "width": ALLEY_HALF * 2.0, "curve": 0.5, "table_length": 6.0, "tail_length": 7.0}],
		["LoadingJump", _alts[2], _s_near(_alts[2], Vector2(-345.0, 80.0)), {"length": 7.5, "height": 1.5, "width": ALLEY_HALF * 2.0, "curve": 0.5, "table_length": 0.0, "tail_length": 0.0}],
	]
	for jd in jump_defs:
		var r = ramp_scene.instantiate()
		r.name = jd[0]
		var sp3: Dictionary = _spot(jd[1], jd[2], 0.0, 0.0)
		r.position = sp3["pos"]
		r.rotation_degrees = Vector3(0, sp3["yaw"], 0)
		for key in jd[3]:
			r.set(key, jd[3][key])
		jumps.add_child(r)
		var lip_s: float = float(jd[2]) + float(jd[3]["length"])
		var lp: Dictionary = _spot(jd[1], lip_s, 0.0, float(jd[3]["height"]))
		lips.append({"name": jd[0], "lip": lp["pos"], "dir": lp["fwd"]})
		_use(sp3["p2"], 1.0)
	track_path.set_meta(&"jump_lips", lips)
	return track_path


# ======================================================================================
#  Sky and light
# ======================================================================================

const HAZE := Color(0.52, 0.38, 0.42)

func _build_environment(level: Node3D) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	# Early evening over the city: the sun a hand above the hills to the west-south-west, deep violet-blue
	# overhead, the horizon burning orange and pink, a few clouds lit from below.
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	sky_mat.set_shader_parameter("sky_top", Color(0.08, 0.10, 0.28))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.98, 0.52, 0.34))
	sky_mat.set_shader_parameter("ground_horizon", Color(0.30, 0.20, 0.22))
	sky_mat.set_shader_parameter("ground_bottom", Color(0.08, 0.07, 0.09))
	sky_mat.set_shader_parameter("sky_curve", 0.32)
	sky_mat.set_shader_parameter("sky_energy", 0.9)
	sky_mat.set_shader_parameter("horizon_haze", HAZE)
	sky_mat.set_shader_parameter("haze_strength", 0.45)
	sky_mat.set_shader_parameter("haze_height", 0.12)
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.62, 0.30))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.4)
	sky_mat.set_shader_parameter("sun_glow", 0.75)
	sky_mat.set_shader_parameter("sun_horizon_glow", 0.9)
	sky_mat.set_shader_parameter("sun_horizon_tint", Color(1.0, 0.45, 0.22))
	sky_mat.set_shader_parameter("sun_horizon_height", 0.30)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.56, 0.42))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.24, 0.18, 0.32))
	sky_mat.set_shader_parameter("cloud_coverage", 0.42)
	sky_mat.set_shader_parameter("cloud_opacity", 0.9)
	sky_mat.set_shader_parameter("cloud_scale", 1.3)
	sky_mat.set_shader_parameter("cloud_seed", 21.7)
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 0.9
	env.fog_sun_scatter = 0.35
	env.fog_density = 1.0
	env.fog_depth_begin = 220.0
	env.fog_depth_end = 2600.0
	env.fog_depth_curve = 1.6
	env.fog_sky_affect = 0.04
	env.fog_aerial_perspective = 0.3
	env_node.environment = env
	level.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	# Low in the west-south-west (Nairobi, a late-October evening), throwing long shadows down the avenue.
	sun.rotation_degrees = Vector3(-9.0, -76.0, 0.0)
	sun.light_color = Color(1.0, 0.64, 0.40)
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 320.0
	level.add_child(sun)


# ======================================================================================
#  Build
# ======================================================================================

func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)


func _ready() -> void:
	print("=== Mtaa Nights (Matumaini GP) Level Generation ===")
	var t_start: int = Time.get_ticks_msec()
	var level := Node3D.new()
	level.name = LEVEL_NAME
	level.set_script(load("res://levels/Level.gd"))
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

	# 1. The roads.
	_plan_paths()
	_verify_forks()
	_index_paths()
	_plan_lamps()
	# 2. The ground and where the buildings stand.
	_compute_ground()
	_plan_buildings()
	var world := Node3D.new()
	world.name = "Mtaa"
	level.add_child(world)
	_build_ground(world)
	_build_city(world)
	_build_far_city(world)
	_build_hills(world)
	# 3. Dressing: what stands at fixed places first, then what fills in round it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2610
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	world.add_child(dressing)
	_build_lamps(dressing)
	_build_club(dressing, rng)
	_build_church(dressing, rng)
	_build_park(dressing, rng)
	_build_fork_signs(dressing)
	_build_trees(dressing)
	var mats: Array = _plan_avenue(rng)
	mats.append_array(_plan_mwangaza(rng))
	_build_matatus(dressing, mats)
	_build_stalls(dressing, _plan_market(rng), "MarketStalls")
	_build_stalls(dressing, _plan_estate(rng), "Kiosks")
	_build_workshops(dressing, rng)
	_build_food_trucks(dressing, [[Vector2(-283.0, 199.0), PI * 0.5, 0], [Vector2(-266.0, 199.0), PI * 0.5, 2]])
	_plan_side_closures()
	_build_barriers(dressing)
	CrowdPlacer.build(dressing, _people, PEOPLE_SCALE, SPECTATOR_SKIN, 2610, func(res: Resource, n: String) -> Resource: return _save_res(res, n))
	print("  people: %d" % _people.size())
	# 4. Sky, light, gameplay.
	_build_environment(level)
	var track_path := _place_gameplay(level)

	# 5. Save.
	level.set("track_path", track_path)
	level._setup_checkpoints()
	_set_owner_recursive(level, level)
	remove_child(level)
	var packed := PackedScene.new()
	var err = packed.pack(level)
	if err != OK:
		push_error("Failed to pack %s: %d" % [LEVEL_PATH, err])
		get_tree().quit(1)
		return
	err = ResourceSaver.save(packed, LEVEL_PATH)
	if err != OK:
		push_error("Failed to save %s: %d" % [LEVEL_PATH, err])
		get_tree().quit(1)
		return
	print("Saved %s in %.1fs" % [LEVEL_PATH, (Time.get_ticks_msec() - t_start) / 1000.0])
	get_tree().quit(0)
