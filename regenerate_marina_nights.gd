# regenerate_marina_nights.gd
# Builds levels/MarinaNightsLevel.tscn, Marina Nights, the Al-Raihana GP's finale: a night street race through the city
# whose skyline the other three stages see on their horizon. No TerrainGenerator road anywhere: every surface the lap
# runs on is laid here (_build_roads, marina_road.gdshader), each section its own: the corniche's asphalt along the sea
# (the start, the Pearl Ring's jump), the arched bridge over the creek's mouth (Jisr al-Qamar, LED studs and lanterns),
# the glass tube out over the sea round the marina (Mamar al-Bahr, its deck lit from its edges, ribs of light overhead),
# Al-Manara Avenue north between the towers, across the fountain plaza (the road stops at its paving and starts again
# past it: either side of the fountain), the north road west over the creek under the arch bridge, the souk's sett-paved
# lanes with nine sharp corners between packed mud-brick houses, and the palm avenue's pavers south to the sea. A ferris
# wheel turns on its island east of the marina; fireworks burst over the water all race long. Al-Manara Avenue runs
# through Qaysariyyat al-Manara, a covered market under a vault of lit lattice; Al-Mu'allaq, a suspended railway, runs
# over the palm avenue and out over the sea to Jazirat al-Fanous, where Burj al-Fanous, a lantern of a tower, sweeps
# the sky with searchlights; airliners come and go over the sea.
# Ramlat Hamra's scene is the template (gates, grid, spawners); the ground is TerrainGenerator's ("marina_nights":
# ArabianTerrain.marina_height, ungraded), its mesh chunked so no mesh takes in more lamps than the mobile renderer
# gives one; every mesh here is built in pieces for the same reason.
#
# Run: Godot --headless --path . res://regenerate_marina_nights.tscn
extends Node

const D = preload("res://ArabianDresser.gd")
const ArabianKit = preload("res://ArabianKit.gd")
const MarinaKit = preload("res://MarinaKit.gd")
const AT = preload("res://ArabianTerrain.gd")
const BloombayCity = preload("res://BloombayCity.gd")
const GulfCity = preload("res://GulfCity.gd")
const MeshChunker = preload("res://MeshChunker.gd")
const ShipKitRef = preload("res://ShipKit.gd")
const PortKitRef = preload("res://PortKit.gd")
const PropKit = preload("res://PropKit.gd")
const LampGlow = preload("res://LampGlow.gd")
const CrowdPlacer = preload("res://CrowdPlacer.gd")
const Airliners = preload("res://Airliners.gd")

const TEMPLATE := "res://levels/RamlatHamraLevel.tscn"
const LEVEL := "res://levels/MarinaNightsLevel.tscn"
const ROOT := "MarinaDressing"
const PS := 1.6
const LAND := AT.MARINA_LAND
## The roads' surface over the land (they lie on it, pulled toward the eye in their shader), the plaza's a centimetre
## higher so it wins where the roads meet its edge.
const ROAD_LIFT := 0.05
const PLAZA_LIFT := 0.06
const ROAD_HALF := 7.5
## The lap, heading east along the corniche from the south-west corner: corner points (x, z) and fillet radii.
const CORNERS := [
	[Vector2(-322.0, 192.0), 34.0],          # the palm avenue (south) onto the corniche (east)
	[Vector2(-230.0, 185.6), 300.0],          # the corniche, 34m in from the sea
	[Vector2(-60.0, 193.7), 300.0],
	[Vector2(10.0, 211.0), 200.0],
	[Vector2(205.0, 211.0), 30.0],           # right, into the glass tube
	[Vector2(205.0, 365.0), 75.0],           # the tube's far west corner
	[Vector2(430.0, 365.0), 75.0],           # its far east corner, back north to the avenue
	[Vector2(430.0, -215.0), 40.0],          # the avenue onto the north road
	[Vector2(316.0, -215.0), 30.0],          # the plaza: round the fountain's north side
	[Vector2(250.0, -267.0), 40.0],
	[Vector2(184.0, -215.0), 30.0],
	[Vector2(-75.0, -215.0), 12.0],          # the souk: left
	[Vector2(-75.0, -175.0), 12.0],          # right
	[Vector2(-160.0, -175.0), 12.0],         # the hairpin: left, left
	[Vector2(-160.0, -147.0), 12.0],
	[Vector2(-110.0, -147.0), 12.0],         # right, right
	[Vector2(-110.0, -110.0), 12.0],
	[Vector2(-230.0, -110.0), 12.0],         # left, right
	[Vector2(-230.0, -75.0), 12.0],
	[Vector2(-322.0, -75.0), 20.0],          # left onto the palm avenue
]
const AVENUE_X := 430.0
const NORTH_Z := -215.0
## Jisr al-Qamar, the corniche's arched bridge over the creek's mouth: a hump ARC_H over the land, ARC_HALF either side
## of where the lap crosses the creek's axis.
const ARC_H := 7.0
const ARC_HALF := 78.0
## The north road over the creek, under the CreekArch: level BRIDGE_Y over the water, ramps either side.
const BRIDGE_Y := 6.2
const BRIDGE_FLAT := 31.0
const BRIDGE_RAMP := 56.0
## Mamar al-Bahr, the glass tube: its deck TUBE_HALF either side, TUBE_Y over the sea, rising to TUBE_CREST at the far
## straight (over the marina's mouth); the vault a circle through the deck's edges and the crown TUBE_CROWN up.
const TUBE_HALF := 9.0
const TUBE_Y := 5.6
const TUBE_CREST := 8.2
const TUBE_CROWN := 13.5
const TUBE_RIB := 6.0
const TUBE_RAMP := 62.0
## The fountain plaza: its middle, the fountain's steps, the ring of planters, the paving's edge.
const PLAZA_C := Vector2(250.0, -215.0)
const FOUNTAIN_R := 25.5
const PLANTER_R := 51.0
const PLAZA_R := 64.0
## Bab al-Lulu, the Pearl Ring over the corniche, and the kicker that throws the carts through it: where its toe stands
## (x on the corniche), the ring this far past the lip. The opening's bottom 4.3m over the ground: no getting under the
## ring, every cart off the kicker (lip 4.65m up) clears it at 25 m/s and more.
const RING_TOE_X := -105.0
const RING_PAST_LIP := 10.0
const RING_RADIUS := 12.5
const RING_TUBE := 1.6
const RING_HC := 15.2
## Dawwar al-Bahr, the ferris wheel: its island's middle, the rims' radius, the hub's height over the land.
const WHEEL_AT := Vector2(640.0, 322.0)
const WHEEL_R := 68.0
const WHEEL_HUB := 84.0
const WHEEL_CABINS := 36
## Districts: downtown's towers east of the creek; the souk between the north road and the palm avenue.
const DOWNTOWN := Rect2(110.0, -470.0, 640.0, 600.0)
const SOUK := Rect2(-348.0, -258.0, 333.0, 206.0)
const LAMP_EVERY := 32.0
## The start's grandstand: opposite the finish line on the sea side, its front this far from the lap's line, its length
## (life size, grown by PS); the crowd barriers along the straight.
const STAND_LAT := ROAD_HALF + 3.6
const STAND_LEN := 24.0
const BARRIER_LAT := ROAD_HALF + 2.7
const GATE_CLEAR := 18.0
## The people (CrowdPlacer: Nyota's figures at this level's 1.6 times life size), a Gulf city's mix:
## [African, South Asian, European, East Asian, Arab or mixed].
const PEOPLE_SCALE := PS / 1.86
const PEOPLE_SKIN := [0.10, 0.34, 0.16, 0.10, 0.30]
## Qaysariyyat al-Manara, the covered arcade over Al-Manara Avenue after the marina walk: from ARCADE_Z0 (its south
## portal) to ARCADE_Z1 (its north one, before the corner onto the north road), the hall HALL_HALF either side of the
## avenue's line to the shop fronts (the shops SHOP_DEPTH deep behind them), in bays BAY long, the vault springing at
## SPRING over the land, each of its two arcs VAULT_R from its foot (the crown about 34m up).
const ARCADE_Z0 := 150.0
const ARCADE_Z1 := -150.0
const HALL_HALF := 16.0
const SHOP_DEPTH := 6.5
const BAY := 10.0
const SPRING := 14.5
const VAULT_R := 19.8
## Al-Mu'allaq, the suspended railway down the palm avenue's line (LINE_X) and on over the corniche and the sea to the
## island: its rails' running surface RAIL_Y up, its two tracks TRACK_OFF either side of the line; frames at FRAME_Z
## (portals over the street, the corner and the island, legs LEG_U out; piers in the sea, SEA_LEG_U out, clear of the
## cruising superyacht's lanes at z 435 and 575), its terminus in the city north of the souk and its station on the
## island's shore.
const LINE_X := -322.0
const RAIL_Y := LAND + 27.0
const TRACK_OFF := 3.0
const FRAME_Z := [-325.0, -295.0, -265.0, -230.0, -195.0, -160.0, -125.0, -95.0, -45.0, -10.0, 25.0, 50.0, 84.0, 118.0, 152.0, 218.0,
		262.0, 306.0, 350.0, 394.0, 460.0, 510.0, 552.0, 608.0, 638.0, 668.0]
const LEG_U := 13.5
const SEA_LEG_U := 10.0
## The city terminus, north of the souk off the road (the line runs over the souk's roofs and the palm avenue without
## stopping: a stop over the street, with no station to be seen from the road, read as a train halting for nothing).
## The city's name in gold (`_build_raihana`): الريحانة, Al-Raihana, on a plinth in the sea off the corniche between the
## creek's mouth and the tube, its front toward the start; the word RAIHANA_WIDTH long, its baseline RAIHANA_TOP over
## the sea, the plinth RAIHANA_DEPTH deep behind its face.
const RAIHANA_AT := Vector2(100.0, 300.0)
const RAIHANA_FACE := Vector2(-0.259, -0.966)
const RAIHANA_WIDTH := 48.0
const RAIHANA_TOP := 5.6
const RAIHANA_DEPTH := 9.0
const RAIHANA_TEXT := "الريحانة"
const STATION_CITY := Vector2(-325.0, -265.0)
const STATION_ISLAND := Vector2(608.0, 668.0)
## Burj al-Fanous's middle on Jazirat al-Fanous (ArabianTerrain.MARINA_ISLAND), south of the railway's station.
const FANOUS_AT := Vector2(-300.0, 812.0)

var d := D.new()
var tg: Node3D
var level: Node3D
var gates: Array = []
var palms_at: Array = []
var people: Array = []
var lights_n := 0

var segs: Array = []
var lap_len := 0.0
## Where things are along the lap (metres from the south-west corner's end).
var s_bc := 0.0          # the corniche crosses the creek's axis
var s_q0 := 0.0          # and its quays
var s_q1 := 0.0
var s_tw := 0.0          # the tube's portals
var s_te := 0.0
var s_mid := 0.0         # the middle of the tube's far straight
var s_pin := 0.0         # in and out of the plaza's paving
var s_pout := 0.0
var s_arch := 0.0        # the north road crosses the creek's axis
var s_aq0 := 0.0         # and its quays
var s_aq1 := 0.0
var s_souk0 := 0.0
var s_souk1 := 0.0
var s_palm1 := 0.0
var s_finish := 0.0


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	level = (load(TEMPLATE) as PackedScene).instantiate()
	level.name = "MarinaNightsLevel"
	add_child(level)
	for n in ["RamlatDressing", "WorldEnvironment", "SunLight", "WeatherController", "Jumps", "BoostPads", ROOT, "MarinaWater", "AlternativePaths"]:
		var old := level.get_node_or_null(n)
		if old:
			level.remove_child(old)
			old.free()
	level.set("alternative_paths", [] as Array[Path3D])
	tg = level.get_node("TerrainGenerator")
	tg.set("level_prefix", "marina_nights")
	tg.set("track_layout_type", 0)
	tg.set("terrain_resolution", 1000)
	tg.set("hill_height", 0.0)
	tg.set("no_water", false)
	tg.set("edge_falloff", false)
	tg.set("clip_to_disc", false)
	tg.set("flat_pads", PackedFloat32Array())
	tg.set("road_gaps", PackedFloat32Array())
	tg.set("road_gap_drift", PackedFloat32Array())
	tg.set("road_height_from_plan", true)
	tg.set("road_width", ROAD_HALF * 2.0)
	tg.set("curb_outer_width", ROAD_HALF * 2.0 + 2.0)
	var path: Path3D = level.get_node("TrackPath")
	path.transform = Transform3D.IDENTITY
	for m in [&"town_route", &"jump_lips"]:
		if path.has_meta(m):
			path.remove_meta(m)
	_plan_lap()
	path.curve = _lap_curve()
	print("Lap: %.0fm (plan %.0fm)" % [path.curve.get_baked_length(), lap_len])
	_plan_ring(path)
	_place_gates(path.curve)
	_place_pads(path.curve)

	d.setup(level, tg, 9191)
	for cp in level.get_node("Checkpoints").get_children():
		gates.append(Vector2(cp.global_position.x, cp.global_position.z))
	var fl: Node3D = level.get_node("FinishLine")
	gates.append(Vector2(fl.global_position.x, fl.global_position.z))
	for rs in ring_spots:
		gates.append(rs)
	print("Baking the ground...")
	tg.generate_world()
	d.setup(level, tg, 9191)
	level._align_start_and_spawns_to_track()

	var root := Node3D.new()
	root.name = ROOT
	level.add_child(root)
	root.owner = level
	root.set_script(load("res://CanyonDetail.gd"))
	_environment()
	_sea()
	_plan_palms()
	_ground_material()
	_build_roads(root)
	_build_plaza(root)
	_build_lap_body(root)
	_build_arc_bridge(root)
	_build_creek_bridge(root)
	_build_arch(root)
	_build_tube(root)
	_build_turn_wall(root)
	_reserve_landmarks()
	_build_souk(root)
	_build_city(root)
	_build_promenade(root)
	_build_start_promenade(root)
	_build_cheers(root)
	_build_lamps(root)
	_build_palms(root)
	_build_railings(root)
	_build_dhows(root)
	_build_ring(root)
	_build_marina(root)
	_build_wheel(root)
	_build_arcade(root)
	_build_suspended(root)
	_build_island(root)
	_build_raihana(root)
	_build_airliners(root)
	_build_far_city(root)
	_build_people(root)
	var fw := Node3D.new()
	fw.name = "Fireworks"
	fw.set_script(load("res://Fireworks.gd"))
	fw.set("area", AABB(Vector3(-560.0, 70.0, 430.0), Vector3(1000.0, 90.0, 140.0)))
	root.add_child(fw)
	fw.owner = level

	# The ground in 80m cells, so each takes in only the lamps near it (Mobile's per-mesh light limit).
	var n_chunked: int = MeshChunker.chunk_scene(tg, "res://generated/marina_nights_", "res://generated/marina_nights_chunks/", 80.0)
	print("Chunked meshes: ", n_chunked, "; real lights: ", lights_n)
	for child in tg.get_children():
		_own(child)
	var grid := level.get_node_or_null("FinishLine/SpawnPoints")
	if grid:
		_own(grid)

	remove_child(level)
	var packed := PackedScene.new()
	var err := packed.pack(level)
	if err == OK:
		err = ResourceSaver.save(packed, LEVEL)
	print("Saved MarinaNightsLevel.tscn: ", err, " in ", (Time.get_ticks_msec() - t0) / 1000.0, "s")
	get_tree().quit(0 if err == OK else 1)


func _own(n: Node) -> void:
	n.owner = level
	if n.scene_file_path != "":
		return
	for c in n.get_children():
		_own(c)


# ======================================================================================
#  The lap: straights and arcs, its heights
# ======================================================================================

func _dir_of(th: float) -> Vector2:
	return Vector2(cos(th), sin(th))


## Right of travel for a heading (x east, z south: a heading east has the south on its right).
func _right_of(th: float) -> Vector2:
	return Vector2(-sin(th), cos(th))


func _fillet(corners: Array) -> void:
	var n: int = corners.size()
	var a_in: Array = []
	var a_out: Array = []
	var arcs: Array = []
	for i in range(n):
		var b: Vector2 = corners[i][0]
		var r: float = corners[i][1]
		var a: Vector2 = corners[(i - 1 + n) % n][0]
		var c: Vector2 = corners[(i + 1) % n][0]
		var d1: Vector2 = (b - a).normalized()
		var d2: Vector2 = (c - b).normalized()
		var ang: float = atan2(d1.x * d2.y - d1.y * d2.x, d1.dot(d2))
		var t: float = r * tan(absf(ang) * 0.5)
		if t > b.distance_to(a) * 0.5 + 0.01 or t > b.distance_to(c) * 0.5 + 0.01:
			push_error("Marina lap: corner %d's radius %.0f does not fit" % [i, r])
		a_in.append(b - d1 * t)
		a_out.append(b + d2 * t)
		if absf(ang) < 0.0001 or r <= 0.0:
			arcs.append(null)
		else:
			arcs.append({"kind": "A", "p0": b - d1 * t, "th0": atan2(d1.y, d1.x), "r": r, "sign": signf(ang), "len": r * absf(ang)})
	segs.clear()
	var s := 0.0
	var prev: Vector2 = a_out[0]
	for k in range(1, n + 1):
		var i: int = k % n
		var p_in: Vector2 = a_in[i]
		var length: float = prev.distance_to(p_in)
		if length > 0.001:
			var dd: Vector2 = (p_in - prev) / length
			segs.append({"kind": "S", "p0": prev, "th0": atan2(dd.y, dd.x), "len": length, "s0": s})
			s += length
		if arcs[i] != null:
			var arc: Dictionary = (arcs[i] as Dictionary).duplicate()
			arc["s0"] = s
			segs.append(arc)
			s += float(arc["len"])
		prev = a_out[i]
	lap_len = s


## Position (x, z), heading and signed curvature (+ turning right) at s along the lap.
func _at(s: float) -> Dictionary:
	s = fposmod(s, lap_len)
	var seg: Dictionary = segs[0]
	for i in range(segs.size() - 1, -1, -1):
		if s >= float(segs[i]["s0"]) - 0.0001:
			seg = segs[i]
			break
	var dd: float = s - float(seg["s0"])
	var p0: Vector2 = seg["p0"]
	var th0: float = seg["th0"]
	if seg["kind"] == "S":
		return {"p": p0 + _dir_of(th0) * dd, "th": th0, "k": 0.0}
	var r: float = seg["r"]
	var sg: float = seg["sign"]
	var c: Vector2 = p0 + _right_of(th0) * r * sg
	var th: float = th0 + sg * dd / r
	return {"p": c - _right_of(th) * r * sg, "th": th, "k": sg / r}


## The lap's point at s with the road's height, and its right in plan.
func _pt(s: float) -> Vector3:
	var a: Dictionary = _at(s)
	var p: Vector2 = a["p"]
	return Vector3(p.x, _lap_y(s), p.y)


func _rt(s: float) -> Vector3:
	var r: Vector2 = _right_of(float(_at(s)["th"]))
	return Vector3(r.x, 0.0, r.y)


func _fw(s: float) -> Vector3:
	var f: Vector2 = _dir_of(float(_at(s)["th"]))
	return Vector3(f.x, 0.0, f.y)


## The s nearest to q in plan (a coarse walk, then a fine one), within [s0, s1] if given.
func _closest_s(q: Vector2, s0 := 0.0, s1 := -1.0) -> float:
	if s1 < 0.0:
		s1 = lap_len
	var best := s0
	var bd := INF
	var s := s0
	while s <= s1:
		var dd: float = (_at(s)["p"] as Vector2).distance_squared_to(q)
		if dd < bd:
			bd = dd
			best = s
		s += 2.0
	var lo: float = best - 2.0
	var hi: float = best + 2.0
	s = lo
	while s <= hi:
		var dd2: float = (_at(s)["p"] as Vector2).distance_squared_to(q)
		if dd2 < bd:
			bd = dd2
			best = s
		s += 0.05
	return fposmod(best, lap_len)


## The first s in [s0, s1] (stepping `step`) where f(s) changes sign, refined by bisection.
func _crossing(f: Callable, s0: float, s1: float, step := 1.0) -> float:
	var a := s0
	var fa: float = f.call(a)
	var b := a + step
	while b <= s1:
		var fb: float = f.call(b)
		if signf(fa) != signf(fb):
			for k in range(30):
				var m: float = (a + b) * 0.5
				var fm: float = f.call(m)
				if signf(fm) == signf(fa):
					a = m
					fa = fm
				else:
					b = m
			return (a + b) * 0.5
		a = b
		fa = fb
		b += step
	push_error("Marina lap: no crossing between s %.0f and %.0f" % [s0, s1])
	return s0


func _plan_lap() -> void:
	_fillet(CORNERS)
	var creek_side := func(s: float) -> float:
		var p: Vector2 = _at(s)["p"]
		return p.x - AT.creek_x(p.y)
	var water := func(s: float) -> float:
		var p: Vector2 = _at(s)["p"]
		return AT.marina_water_d(p.x, p.y)
	s_bc = _crossing(creek_side, 200.0, 500.0, 2.0)
	s_q0 = _crossing(water, s_bc - 60.0, s_bc, 0.5)
	s_q1 = _crossing(water, s_bc, s_bc + 60.0, 0.5)
	s_tw = _crossing(func(s: float) -> float: return (_at(s)["p"] as Vector2).y - 239.0, s_bc + 40.0, s_bc + 260.0, 0.5)
	s_mid = _closest_s(Vector2(317.0, 365.0), s_tw, s_tw + 400.0)
	s_te = _crossing(func(s: float) -> float: return (_at(s)["p"] as Vector2).y - 222.0, s_mid, s_mid + 400.0, 0.5)
	var plaza := func(s: float) -> float:
		var p: Vector2 = _at(s)["p"]
		return p.distance_to(PLAZA_C) - PLAZA_R
	var s_plaza_mid: float = _closest_s(PLAZA_C + Vector2(0.0, -52.0), s_te, s_te + 900.0)
	s_pin = _crossing(plaza, s_plaza_mid - 120.0, s_plaza_mid, 0.25)
	s_pout = _crossing(plaza, s_plaza_mid, s_plaza_mid + 120.0, 0.25)
	s_arch = _crossing(creek_side, s_pout, s_pout + 400.0, 2.0)
	s_aq0 = _crossing(water, s_arch - 60.0, s_arch, 0.5)
	s_aq1 = _crossing(water, s_arch, s_arch + 60.0, 0.5)
	s_souk0 = s_arch + BRIDGE_FLAT + BRIDGE_RAMP
	s_souk1 = _closest_s(Vector2(-322.0, -55.0), s_souk0, lap_len)
	s_palm1 = _closest_s(Vector2(-322.0, 158.0), s_souk1, lap_len)
	print("Lap plan: bridge %.0f (quays %.0f-%.0f), tube %.0f-%.0f, plaza %.0f-%.0f, arch %.0f, souk %.0f-%.0f, palm avenue to %.0f, %.0fm"
			% [s_bc, s_q0, s_q1, s_tw, s_te, s_pin, s_pout, s_arch, s_souk0, s_souk1, s_palm1, lap_len])


## The road's surface height at s: the land, the corniche bridge's hump, the north road's bridge, the tube's deck.
func _lap_y(s: float) -> float:
	var y: float = LAND + ROAD_LIFT
	var db: float = absf(s - s_bc)
	if db < ARC_HALF:
		y += ARC_H * pow(cos(PI * 0.5 * db / ARC_HALF), 2.0)
	var da: float = absf(s - s_arch)
	if da < BRIDGE_FLAT + BRIDGE_RAMP:
		y = lerpf(y, BRIDGE_Y, 1.0 - smoothstep(BRIDGE_FLAT, BRIDGE_FLAT + BRIDGE_RAMP, da))
	if s > s_tw and s < s_te:
		var up: float = smoothstep(s_tw, s_tw + TUBE_RAMP, s) * (1.0 - smoothstep(s_te - TUBE_RAMP, s_te, s))
		var crest: float = exp(-pow((s - s_mid) / 75.0, 2.0))
		y = lerpf(y, TUBE_Y + (TUBE_CREST - TUBE_Y) * crest, up)
	return y


func _lap_curve() -> Curve3D:
	var pts: Array = []
	var s := 0.0
	while s < lap_len - 2.0:
		pts.append(_pt(s))
		s += 4.0
	var c := Curve3D.new()
	c.bake_interval = 0.25
	var n := pts.size()
	for i in range(n):
		var p0: Vector3 = pts[(i - 1 + n) % n]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[(i + 1) % n]
		var hnd: Vector3 = (p2 - p0) / 6.0
		c.add_point(p1, -hnd, hnd)
	# Closed on itself: the first point again.
	var q0: Vector3 = pts[n - 1]
	var q2: Vector3 = pts[1]
	var tq: Vector3 = (q2 - q0) / 6.0
	c.add_point(pts[0], -tq, tq)
	return c


func _place_gates(curve: Curve3D) -> void:
	var fl: Node3D = level.get_node("FinishLine")
	fl.position = curve.sample_baked(curve.get_closest_offset(Vector3(-150.0, LAND, AT.coast_z(-150.0) - 34.0)))
	s_finish = _closest_s(Vector2(fl.position.x, fl.position.z))
	# In lap order: in the tube (or it could be skipped along the promenade), on the avenue, the north road, the souk's
	# long lane (before the market hall), the palm avenue.
	var spots := [["Halfway4", Vector2(317.0, 365.0)], ["Halfway3", Vector2(AVENUE_X, -20.0)], ["Halfway2", Vector2(150.0, NORTH_Z)],
			["Halfway1", Vector2(-172.0, -110.0)], ["HalfwayTown", Vector2(-322.0, 64.0)]]
	var cps: Node = level.get_node("Checkpoints")
	# Only these gates: any other the template carries goes (Jebel Sahar's town gates came down the template chain).
	var wanted: Array = []
	for sp in spots:
		wanted.append(String(sp[0]))
	for cp0 in cps.get_children():
		if not wanted.has(String(cp0.name)):
			cps.remove_child(cp0)
			cp0.free()
	var order: Array[Area3D] = []
	for sp in spots:
		var cp := cps.get_node_or_null(String(sp[0])) as Node3D
		if cp == null:
			cp = (load("res://CheckpointGate.tscn") as PackedScene).instantiate()
			cp.name = String(sp[0])
			cps.add_child(cp)
			cp.owner = level
		var at: Vector2 = sp[1]
		cp.position = curve.sample_baked(curve.get_closest_offset(Vector3(at.x, LAND, at.y)))
		order.append(cp as Area3D)
	order.append(fl as Area3D)
	level.set("checkpoints", order)
	level._align_checkpoints_to_track()


func _place_pads(curve: Curve3D) -> void:
	var pads_node := Node3D.new()
	pads_node.name = "BoostPads"
	level.add_child(pads_node)
	pads_node.owner = level
	var bp: PackedScene = load("res://BoostPad.tscn")
	# Into the Pearl Ring's kicker; up the avenue out of the tube; down the palm avenue toward the sea. None before the
	# souk's corners or into the tube (the AI won't brake while a pad pushes it).
	var spots := [[curve.sample_baked(ring_toe_s - 28.0), "BoostPad_Ring"], [Vector3(AVENUE_X, LAND, 150.0), "BoostPad_Avenue"],
		[Vector3(-322.0, LAND, -20.0), "BoostPad_PalmAvenue"]]
	for at in spots:
		var off: float = curve.get_closest_offset(at[0])
		var p := curve.sample_baked(off)
		var q := curve.sample_baked(off + 2.0)
		var pad: Node3D = bp.instantiate()
		pad.name = at[1]
		pads_node.add_child(pad)
		pad.owner = level
		pad.transform = Transform3D(Basis.looking_at((q - p).normalized(), Vector3.UP), p + Vector3(0, 0.1, 0))


# ======================================================================================
#  Night, the sea, the ground
# ======================================================================================

const HAZE := Color(0.20, 0.18, 0.26)

func _environment() -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://sky_tropical_cumulus.gdshader")
	# Night over the Gulf: deep blue-black overhead, the city's glow warm along the horizon, a high moon.
	sm.set_shader_parameter("sky_top", Color(0.01, 0.02, 0.06))
	sm.set_shader_parameter("sky_horizon", Color(0.20, 0.14, 0.18))
	sm.set_shader_parameter("ground_horizon", Color(0.10, 0.08, 0.10))
	sm.set_shader_parameter("ground_bottom", Color(0.02, 0.02, 0.03))
	sm.set_shader_parameter("sky_curve", 0.28)
	sm.set_shader_parameter("sky_energy", 0.7)
	sm.set_shader_parameter("horizon_haze", HAZE)
	sm.set_shader_parameter("haze_strength", 0.6)
	sm.set_shader_parameter("haze_height", 0.1)
	sm.set_shader_parameter("sun_tint", Color(0.85, 0.90, 1.0))
	sm.set_shader_parameter("sun_disc_degrees", 1.6)
	sm.set_shader_parameter("sun_glow", 0.25)
	sm.set_shader_parameter("sun_horizon_glow", 0.0)
	sm.set_shader_parameter("cloud_lit", Color(0.30, 0.30, 0.38))
	sm.set_shader_parameter("cloud_shade", Color(0.06, 0.06, 0.10))
	sm.set_shader_parameter("cloud_coverage", 0.22)
	sm.set_shader_parameter("cloud_opacity", 0.6)
	sm.set_shader_parameter("cloud_scale", 1.8)
	sm.set_shader_parameter("cloud_seed", 9.1)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.18, 0.30)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.glow_enabled = true
	env.glow_intensity = 0.75
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = HAZE
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	env.fog_depth_begin = 260.0
	env.fog_depth_end = 3800.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.03
	env_node.environment = env
	level.add_child(env_node)
	level.move_child(env_node, 0)
	env_node.owner = level
	var moon := DirectionalLight3D.new()
	moon.name = "SunLight"
	moon.rotation_degrees = Vector3(-52.0, 150.0, 0.0)
	moon.light_color = Color(0.62, 0.70, 0.95)
	moon.light_energy = 0.22
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 200.0
	level.add_child(moon)
	level.move_child(moon, 1)
	moon.owner = level


## The sea and the creek: one plane at y 0 (named "...Water": PlayerCart's general water branch reads its height),
## night colours, the city's glow in its reflections.
func _sea() -> void:
	var water := MeshInstance3D.new()
	water.name = "MarinaWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(7000.0, 7000.0)
	plane.subdivide_width = 40
	plane.subdivide_depth = 40
	water.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.seamless = true
	nt.as_normal_map = true
	mat.set_shader_parameter("noise_tex", nt)
	mat.set_shader_parameter("normal_tex", nt)
	mat.set_shader_parameter("water_color", Color(0.005, 0.015, 0.03))
	mat.set_shader_parameter("shallow_color", Color(0.04, 0.10, 0.12))
	mat.set_shader_parameter("deep_water_color", Color(0.004, 0.01, 0.02))
	mat.set_shader_parameter("sky_tint", Color(0.30, 0.26, 0.30))
	mat.set_shader_parameter("sky_reflect", 0.5)
	mat.set_shader_parameter("transparency", 0.25)
	mat.set_shader_parameter("metallic", 0.75)
	mat.set_shader_parameter("roughness", 0.05)
	mat.set_shader_parameter("wave_strength", 0.5)
	mat.set_shader_parameter("wave_scale", 7000.0 / 1600.0)
	mat.set_shader_parameter("water_fade_start", 2600.0)
	mat.set_shader_parameter("water_fade_end", 3500.0)
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.set_meta("water_surface_y", 0.0)
	level.add_child(water)
	water.owner = level


## Whether (x, z) is on the marina's promenade (where the corniche ran before the tube took the lap out to sea).
func _on_marina_walk(x: float, z: float) -> bool:
	return x > 150.0 and x < 470.0 and AT.coast_z(x) - z < 64.0 and AT.coast_z(x) - z > -2.0


func _plan_palms() -> void:
	var s := 0.0
	while s < lap_len:
		var p: Vector3 = _pt(s)
		var right: Vector3 = _rt(s)
		var corniche: bool = s < s_bc - ARC_HALF - 10.0 or s > s_palm1 + 40.0
		var avenue: bool = s > s_souk1 + 32.0 and s < s_palm1 - 10.0
		var boulevard: bool = s > s_te + 20.0 and absf(p.x - AVENUE_X) < 4.0 and p.z > NORTH_Z + 60.0 and not (p.z < ARCADE_Z0 + 8.0 and p.z > ARCADE_Z1 - 8.0)
		if corniche or avenue or boulevard:
			for sd in [-1.0, 1.0]:
				# On the corniche only the sea's side (+z) has the promenade.
				if corniche and right.z * sd < 0.0:
					continue
				var pp: Vector3 = p + right * sd * (ROAD_HALF + 4.5)
				if _in_stand(Vector2(pp.x, pp.z), 2.0):
					continue
				# A palm this far out stands clear of a gate's posts (6.85m): only keep it off the gate's own ground.
				if AT.marina_water_d(pp.x, pp.z) > -4.0 or d.road_dist(pp.x, pp.z, 30.0) < ROAD_HALF + 3.0 or _near_gate(Vector2(pp.x, pp.z), -10.0):
					continue
				if _near_rail_foot(pp.x, pp.z, 5.0):
					continue
				palms_at.append(Vector2(pp.x, pp.z))
		s += 16.0
	# The promenade's seaward row along the balustrade, the corniche's and the marina's.
	var x := -620.0
	while x < 720.0:
		var z: float = AT.coast_z(x) - 9.0
		if AT.marina_water_d(x, z) < -4.0 and d.road_dist(x, z, 30.0) > ROAD_HALF + 6.0 and not (x > 600.0) and not _in_stand(Vector2(x, z), 2.0):
			palms_at.append(Vector2(x, z))
		x += 22.0
	# The marina walk's inland row.
	x = 170.0
	while x < 420.0:
		var z2: float = AT.coast_z(x) - 46.0
		if d.road_dist(x, z2, 30.0) > ROAD_HALF + 6.0:
			palms_at.append(Vector2(x, z2))
		x += 18.0
	# Jazirat al-Fanous: a ring round its shore and an avenue up the walk from the railway's station.
	var isl: Vector2 = AT.MARINA_ISLAND
	for k in range(56):
		var a: float = TAU * float(k) / 56.0
		var dir := Vector2(cos(a), sin(a))
		var r := AT.MARINA_ISLAND_R * 0.6
		while r < AT.MARINA_ISLAND_R * 1.4 and AT.marina_island_d(isl.x + dir.x * r, isl.y + dir.y * r) < -16.0:
			r += 2.0
		var pp2: Vector2 = isl + dir * r
		if pp2.distance_to(FANOUS_AT) > 84.0 and absf(pp2.x - LINE_X) > 14.0:
			palms_at.append(pp2)
	var zw := STATION_ISLAND.y + 14.0
	while zw < FANOUS_AT.y - 86.0:
		for sdw in [-1.0, 1.0]:
			palms_at.append(Vector2(LINE_X + sdw * 13.0, zw))
		zw += 13.0
	# The plaza's planters (one palm each: _plaza_planters lists them).
	for a in _plaza_planters():
		palms_at.append(PLAZA_C + Vector2(cos(float(a)), sin(float(a))) * PLANTER_R)


func _near_gate(c: Vector2, r: float) -> bool:
	for g in gates:
		if c.distance_to(g) < r + GATE_CLEAR:
			return true
	return false


var palm_hash := {}

func _ground_material() -> void:
	for p in palms_at:
		var k := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
		if not palm_hash.has(k):
			palm_hash[k] = []
		palm_hash[k].append(p)
	var map: Texture2D = d.ground_map(1024, 1000.0, func(x: float, z: float) -> Color:
		var coast: float = AT.coast_z(x) - z
		var pr := 0.0
		if x > 140.0 and x < 480.0:
			# The marina walk: a broad promenade from the quay to the town.
			if coast > 1.5 and coast < 62.0:
				pr = clampf((coast - 1.5) / 60.5, 0.0, 1.0)
		elif coast > 1.5 and coast < 34.0 - ROAD_HALF - 2.5:
			pr = clampf((coast - 1.5) / (34.0 - ROAD_HALF - 4.0), 0.0, 1.0)
		# Jazirat al-Fanous is paved over, quay to quay.
		if AT.marina_island_d(x, z) < -1.0:
			pr = 1.0
		var bed := 0.0
		var key := Vector2i(floori(x / 8.0), floori(z / 8.0))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for p in palm_hash.get(key + Vector2i(dx, dz), []):
					bed = maxf(bed, 1.0 - smoothstep(1.6, 2.6, (p as Vector2).distance_to(Vector2(x, z))))
		return Color(pr, bed, 0.0, 1.0))
	var m := ShaderMaterial.new()
	m.shader = load("res://marina_ground.gdshader")
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("stone_tex", load("res://materials/cobblestone.png"))
	m.set_shader_parameter("stone_normal", load("res://materials/cobblestone_normal.png"))
	m.set_shader_parameter("sand_tex", load("res://materials/sand.png"))
	m.set_shader_parameter("ground_map", map)
	m.set_shader_parameter("land_y", LAND)
	m = d.save(m, "ground_material") as ShaderMaterial
	tg.set("grass_material", m)
	(tg.get_node("Terrain_Visual") as MeshInstance3D).material_override = m


func _light(parent: Node3D, nm: String, at: Vector3, col: Color, energy: float, rng_m: float, fade := 150.0) -> OmniLight3D:
	var om := OmniLight3D.new()
	om.name = nm
	om.position = at
	om.light_color = col
	om.light_energy = energy
	om.omni_range = rng_m
	om.omni_attenuation = 1.2
	om.shadow_enabled = false
	om.distance_fade_enabled = true
	om.distance_fade_begin = fade
	om.distance_fade_length = 40.0
	om.set_meta(&"no_shadow", true)
	parent.add_child(om)
	om.owner = level
	lights_n += 1
	return om


func _mesh_node(parent: Node3D, nm: String, mesh: Mesh, range_end := 0.0, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = d.save(mesh, nm.to_lower())
	if range_end > 0.0:
		mi.visibility_range_end = range_end
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.owner = level
	return mi


func _box_shape(body: Node3D, xf: Transform3D, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.transform = xf
	body.add_child(cs)


func _cyl_shape(body: Node3D, at: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = at
	body.add_child(cs)


## A box along the lap from s0 to s1 at lateral u (its middle), v up from the road's surface (its middle), `w` across
## and `h` high: rails, walls, parapets. As a transform and a size for _box_shape.
func _lap_box(s0: float, s1: float, u: float, v: float, w: float, h: float) -> Array:
	var a: Vector3 = _pt(s0) + _rt(s0) * u
	var b: Vector3 = _pt(s1) + _rt(s1) * u
	var mid: Vector3 = (a + b) * 0.5 + Vector3(0.0, v, 0.0)
	var dir: Vector3 = b - a
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	var x: Vector3 = Vector3.UP.cross(flat).normalized()
	var z: Vector3 = dir.normalized()
	var y: Vector3 = z.cross(x).normalized()
	return [Transform3D(Basis(x, y, z), mid), Vector3(w, h, dir.length() + 0.05)]


# ======================================================================================
#  The roads: every surface the lap runs on
# ======================================================================================

var _road_mat: ShaderMaterial

func _road_material() -> ShaderMaterial:
	if _road_mat:
		return _road_mat
	var m := ShaderMaterial.new()
	m.shader = load("res://marina_road.gdshader")
	m.set_shader_parameter("asphalt_tex", load("res://materials/asphalt.png"))
	m.set_shader_parameter("sett_tex", load("res://materials/cobblestone.png"))
	m.set_shader_parameter("sett_normal", load("res://materials/cobblestone_normal.png"))
	m.set_shader_parameter("concrete_tex", load("res://materials/concrete.png"))
	m.set_shader_parameter("plaza_c", PLAZA_C)
	m.set_shader_parameter("plaza_r0", FOUNTAIN_R)
	m.set_shader_parameter("plaza_r1", PLAZA_R)
	m.set_shader_parameter("half_w", ROAD_HALF)
	_road_mat = d.save(m, "road_material") as ShaderMaterial
	return _road_mat


## The sections of the lap: [s0, s1, kind (marina_road.gdshader), half width, body name]. The plaza (s_pin..s_pout) has
## no ribbon: its paving is a disc of its own.
func _road_sections() -> Array:
	var b0: float = s_bc - ARC_HALF
	var b1: float = s_bc + ARC_HALF
	var a0: float = s_arch - BRIDGE_FLAT - BRIDGE_RAMP
	var a1: float = s_arch + BRIDGE_FLAT + BRIDGE_RAMP
	return [
		[0.0, b0, 0, ROAD_HALF, "CornicheRoad"],
		[b0, b1, 3, ROAD_HALF, "QamarBridgeDeck"],
		[b1, s_tw, 0, ROAD_HALF, "CornicheRoad"],
		[s_tw, s_te, 4, TUBE_HALF, "TubeDeck"],
		[s_te, s_pin, 0, ROAD_HALF, "AvenueRoad"],
		[s_pout, a0, 0, ROAD_HALF, "NorthRoad"],
		[a0, a1, 3, ROAD_HALF, "CreekBridgeDeck"],
		[a1, s_souk1, 1, ROAD_HALF, "SoukRoad"],
		[s_souk1, s_palm1, 2, ROAD_HALF, "PalmAvenueRoad"],
		[s_palm1, lap_len, 0, ROAD_HALF, "CornicheRoad"],
	]


## The ribbons, in pieces of 48m (meshes) and 96m (bodies), with the kind's change marked for the threshold.
func _build_roads(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Roads"
	root.add_child(node)
	node.owner = level
	var secs := _road_sections()
	var bounds: Array = []
	for sec in secs:
		bounds.append(float(sec[0]))
		bounds.append(float(sec[1]))
	var mat := _road_material()
	var lats := [-1.0, -0.5, 0.0, 0.5, 1.0]
	var piece := 0
	for sec in secs:
		var s0: float = sec[0]
		var s1: float = sec[1]
		var kind: int = sec[2]
		var half: float = sec[3]
		if s1 - s0 < 0.5:
			continue
		var n_steps: int = maxi(1, ceili(s1 - s0))
		var rows: Array = []        # each row: [s per lateral vertex]
		for i in range(n_steps + 1):
			var s: float = lerpf(s0, s1, float(i) / float(n_steps))
			var row: Array = []
			for l in lats:
				row.append(s)
			rows.append(row)
		# The ends against the plaza: each vertex on the paving's circle.
		if is_equal_approx(s1, s_pin):
			rows[rows.size() - 1] = _row_on_circle(s1, lats, half, true)
		if is_equal_approx(s0, s_pout):
			rows[0] = _row_on_circle(s0, lats, half, false)
		# Meshes every 48 rows, bodies every 96.
		var r0 := 0
		while r0 < rows.size() - 1:
			var r1: int = mini(r0 + 48, rows.size() - 1)
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			var faces := PackedVector3Array()
			for i in range(r0, r1):
				for j in range(lats.size() - 1):
					var quad: Array = []
					for rc in [[i, j], [i, j + 1], [i + 1, j], [i + 1, j + 1]]:
						var s: float = rows[rc[0]][rc[1]]
						var lat: float = float(lats[rc[1]]) * half
						quad.append([s, lat])
					# A (row i, left), B (row i, right), C (row i+1, left), D (row i+1, right): (A, C, B), (B, C, D).
					for t in [[0, 2, 1], [1, 2, 3]]:
						for k in t:
							var sv: float = quad[k][0]
							var lv: float = quad[k][1]
							var pos: Vector3 = _pt(sv) + _rt(sv) * lv
							var edge: float = INF
							for bb in bounds:
								edge = minf(edge, absf(sv - float(bb)))
							if kind == 4 and (absf(sv - s_tw) < 0.01 or absf(sv - s_te) < 0.01):
								edge = 0.0
							var fwd: Vector3 = (_pt(sv + 0.5) - _pt(sv - 0.5)).normalized()
							st.set_normal(_rt(sv).cross(fwd).normalized())
							st.set_color(Color(clampf(edge / 4.0, 0.0, 1.0), 0.0, 0.0, 1.0))
							st.set_uv(Vector2(lv, sv))
							st.set_uv2(Vector2(float(kind), 0.0))
							st.add_vertex(pos)
							faces.append(pos)
			var mesh: ArrayMesh = st.commit()
			mesh.surface_set_material(0, mat)
			_mesh_node(node, "Road_%d" % piece, mesh, 0.0, false)
			piece += 1
			_lap_faces.append_array(faces)
			r0 = r1
	print("Roads: %d pieces" % piece)


## Every triangle the lap runs on (the roads, the bridges' and the tube's decks, the plaza's paving) in one body: across
## the seams between separate bodies a cart's sphere caught the next one's leading edge on the corniche bridge's slopes
## and was thrown a metre up (scratch/lap_hop_probe.tscn). Named "...Road" (track), surface asphalt.
var _lap_faces := PackedVector3Array()

func _build_lap_body(root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "LapRoad"
	body.set_meta(&"surface", "asphalt")
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(_lap_faces)
	cs.shape = d.save(sh, "lap_road_shape")
	body.add_child(cs)
	root.add_child(body)
	_own(body)
	print("Lap road body: %d triangles" % (_lap_faces.size() / 3))


## The s of each lateral vertex where it meets the plaza's circle (`toward`: the road runs into the plaza).
func _row_on_circle(s_c: float, lats: Array, half: float, _toward: bool) -> Array:
	var row: Array = []
	for l in lats:
		var lat: float = float(l) * half
		var f := func(s: float) -> float:
			var p: Vector3 = _pt(s) + _rt(s) * lat
			return Vector2(p.x, p.z).distance_to(PLAZA_C) - PLAZA_R
		var a: float = s_c - 4.0
		var b: float = s_c + 4.0
		var fa: float = f.call(a)
		for k in range(40):
			var m: float = (a + b) * 0.5
			var fm: float = f.call(m)
			if signf(fm) == signf(fa):
				a = m
				fa = fm
			else:
				b = m
		row.append((a + b) * 0.5)
	return row


# ======================================================================================
#  The fountain plaza
# ======================================================================================

## The angles of the plaza's planters round PLANTER_R: every 12 degrees but where the roads come in.
## The distance in plan from q to the lap's line (sampled every 2m from the planned lap; works before the world exists).
func _lap_dist(q: Vector2) -> float:
	var best := 1e9
	var s := 0.0
	while s < lap_len:
		best = minf(best, (_at(s)["p"] as Vector2).distance_to(q))
		s += 2.0
	return best


func _plaza_planters() -> Array:
	var out: Array = []
	var gaps: Array = []
	for s in [s_pin, s_pout]:
		var p: Vector3 = _pt(s)
		gaps.append(atan2(p.z - PLAZA_C.y, p.x - PLAZA_C.x))
	var k := 0
	while k < 30:
		var a: float = TAU * float(k) / 30.0
		var ok := true
		for g in gaps:
			if absf(angle_difference(a, float(g))) < (ROAD_HALF + 5.0) / PLANTER_R:
				ok = false
		# Nor where the lap curves round the fountain near the ring (two palms stood 4.3m from its line).
		var pc: Vector2 = PLAZA_C + Vector2(cos(a), sin(a)) * PLANTER_R
		if _lap_dist(pc) < ROAD_HALF + 4.5:
			ok = false
		if ok:
			out.append(a)
		k += 1
	return out


func _build_plaza(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "FountainPlaza"
	root.add_child(node)
	node.owner = level
	var mat := _road_material()
	var y: float = LAND + PLAZA_LIFT
	# The paving: four quarters (each takes in its own lamps), rings every 2m, segments every 2 degrees.
	for q in range(4):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var faces := PackedVector3Array()
		var na := 45
		var r_steps := [FOUNTAIN_R - 0.3]
		var rr: float = FOUNTAIN_R + 1.5
		while rr < PLAZA_R:
			r_steps.append(rr)
			rr += 2.0
		r_steps.append(PLAZA_R)
		for i in range(na):
			var a0: float = PI * 0.5 * (float(q) + float(i) / na)
			var a1: float = PI * 0.5 * (float(q) + float(i + 1) / na)
			for j in range(r_steps.size() - 1):
				var ra: float = r_steps[j]
				var rb: float = r_steps[j + 1]
				var p00 := Vector3(PLAZA_C.x + cos(a0) * ra, y, PLAZA_C.y + sin(a0) * ra)
				var p01 := Vector3(PLAZA_C.x + cos(a1) * ra, y, PLAZA_C.y + sin(a1) * ra)
				var p10 := Vector3(PLAZA_C.x + cos(a0) * rb, y, PLAZA_C.y + sin(a0) * rb)
				var p11 := Vector3(PLAZA_C.x + cos(a1) * rb, y, PLAZA_C.y + sin(a1) * rb)
				# Front faces up: (c - a) x (b - a) points up.
				for tri in [[p00, p10, p01], [p01, p10, p11]]:
					var tv: Array = tri
					var nrm: Vector3 = ((tv[2] as Vector3) - (tv[0] as Vector3)).cross((tv[1] as Vector3) - (tv[0] as Vector3))
					if nrm.y < 0.0:
						tv = [tri[0], tri[2], tri[1]]
					for v in tv:
						st.set_normal(Vector3.UP)
						st.set_color(Color(1.0, 0.0, 0.0, 1.0))
						st.set_uv(Vector2((v as Vector3).x, (v as Vector3).z))
						st.set_uv2(Vector2(5.0, 0.0))
						st.add_vertex(v)
						# Solid at the roads' own height (drawn a centimetre over them, so it wins where they meet).
						faces.append(Vector3((v as Vector3).x, LAND + ROAD_LIFT, (v as Vector3).z))
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, mat)
		_mesh_node(node, "PlazaDeckPaving_%d" % q, mesh, 0.0, false)
		_lap_faces.append_array(faces)
	# The fountain on its steps, its show, its collider (the steps and the column).
	var at := Vector3(PLAZA_C.x, LAND, PLAZA_C.y)
	var pk := MarinaKit.new_kit(1.0)
	pk.set_frame(Transform3D(Basis(), at))
	var kit := {}
	var water: Vector2 = MarinaKit.plaza_fountain(pk, kit, FOUNTAIN_R)
	var fbody := StaticBody3D.new()
	fbody.name = "PlazaFountain"
	fbody.set_meta(&"surface", "rock")
	node.add_child(fbody)
	var fmi := MeshInstance3D.new()
	fmi.name = "FountainStone"
	fmi.mesh = d.save(MarinaKit.commit(pk, kit), "plaza_fountain")
	fbody.add_child(fmi)
	_cyl_shape(fbody, at + Vector3(0, 1.1, 0), FOUNTAIN_R + 0.1, 2.6)
	_cyl_shape(fbody, at + Vector3(0, 7.0, 0), 3.0, 14.0)
	_own(fbody)
	var show := Node3D.new()
	show.name = "FountainShow"
	show.set_script(load("res://FountainShow.gd"))
	show.position = at
	show.set("basin_radius", water.y)
	show.set("water_y", water.x)
	show.set("ring_radius", water.y - 2.0)
	show.set("ring_jets", 28)
	show.set("base_y", 0.55)
	node.add_child(show)
	show.owner = level
	# The planters (a palm each), lit bollards between them, closing the ring but where the roads come in.
	var ppk := MarinaKit.new_kit(PS)
	var pkit := {}
	var pbody := StaticBody3D.new()
	pbody.name = "PlazaPlanters"
	pbody.set_meta(&"surface", "rock")
	node.add_child(pbody)
	var angles: Array = _plaza_planters()
	for a in angles:
		var c := Vector3(PLAZA_C.x + cos(float(a)) * PLANTER_R, LAND, PLAZA_C.y + sin(float(a)) * PLANTER_R)
		ppk.set_frame(Transform3D(Basis(Vector3.UP, float(a)).scaled(Vector3.ONE * PS), c))
		MarinaKit.planter(ppk, pkit, 1.25, 0.7)
		_cyl_shape(pbody, c + Vector3(0, 0.8, 0), 1.25 * PS + 0.05, 1.6)
	# Bollards every 3m between neighbouring planters (where both sides of the gap are planters).
	var da: float = TAU / 30.0
	for a in angles:
		var nxt: float = float(a) + da
		var has_next := false
		for b in angles:
			if absf(angle_difference(float(b), nxt)) < 0.01:
				has_next = true
		if not has_next:
			continue
		for k in range(1, 4):
			var ab: float = float(a) + da * float(k) / 4.0
			var c2 := Vector3(PLAZA_C.x + cos(ab) * PLANTER_R, LAND, PLAZA_C.y + sin(ab) * PLANTER_R)
			ppk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), c2))
			MarinaKit.bollard(ppk, pkit)
			_cyl_shape(pbody, c2 + Vector3(0, 0.8, 0), 0.4, 1.6)
	var pmi := MeshInstance3D.new()
	pmi.name = "PlanterRing"
	pmi.mesh = d.save(MarinaKit.commit(ppk, pkit), "plaza_planters")
	pbody.add_child(pmi)
	_own(pbody)
	# The terraces outside the ring: café tables under parasols, benches facing the fountain, lantern posts (lit),
	# people at the tables and standing at the planters watching.
	var tpk := MarinaKit.new_kit(PS)
	var tkit := {}
	var tbody := StaticBody3D.new()
	tbody.name = "PlazaTerraces"
	tbody.set_meta(&"surface", "rock")
	node.add_child(tbody)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	var cols := [Color(0.90, 0.88, 0.82), Color(0.62, 0.16, 0.14), Color(0.14, 0.32, 0.44), Color(0.78, 0.62, 0.30)]
	var lamp_k := 0
	for i in range(len(angles)):
		var a: float = angles[i]
		# A lantern post on every other planter's outside.
		if i % 2 == 0:
			var lp := Vector3(PLAZA_C.x + cos(a) * (PLANTER_R + 3.2), LAND, PLAZA_C.y + sin(a) * (PLANTER_R + 3.2))
			tpk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), lp))
			MarinaKit.lantern_post(tpk, tkit, 3.4)
			_cyl_shape(tbody, lp + Vector3(0, 1.0, 0), 0.55, 2.0)
			if lamp_k % 2 == 0:
				_light(node, "PlazaLamp_%d" % lamp_k, lp + Vector3(0, 4.6 * PS, 0), Color(1.0, 0.78, 0.5), 2.4, 22.0)
			lamp_k += 1
		# Between the planters: a café table or a bench, people.
		var am: float = a + TAU / 60.0
		var r_t: float = PLANTER_R + 7.0 + rng.randf_range(-0.5, 1.5)
		var c3 := Vector3(PLAZA_C.x + cos(am) * r_t, LAND, PLAZA_C.y + sin(am) * r_t)
		if rng.randf() < 0.65:
			tpk.set_frame(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * PS), c3))
			MarinaKit.cafe_set(tpk, tkit, rng, cols[rng.randi() % cols.size()], 3 + rng.randi() % 2, true)
			_cyl_shape(tbody, c3 + Vector3(0, 0.6, 0), 1.25 * PS, 1.2)
			# Seated people at it, facing in.
			for k in range(rng.randi_range(1, 3)):
				var b: float = rng.randf() * TAU
				var o := Vector3(cos(b), 0.0, sin(b))
				people.append([c3 + o * 0.72 * PS + Vector3(0, 0.45 * PS, 0), -o, true, false])
		else:
			var inward := Vector3(PLAZA_C.x - c3.x, 0.0, PLAZA_C.y - c3.z).normalized()
			tpk.set_frame(Transform3D(Basis.looking_at(inward, Vector3.UP).scaled(Vector3.ONE * PS), c3))
			MarinaKit.bench(tpk, tkit, 2.0)
			_box_shape(tbody, Transform3D(Basis.looking_at(inward, Vector3.UP), c3 + Vector3(0, 0.5, 0)), Vector3(2.2 * PS, 1.0, 0.6 * PS))
			for k in range(rng.randi_range(0, 2)):
				var side := Basis.looking_at(inward, Vector3.UP) * Vector3((float(k) - 0.5) * 0.8 * PS, 0, 0)
				people.append([c3 + side + Vector3(0, 0.45 * PS, 0), inward, true, false])
		# Standing by the planters, watching the race.
		if rng.randf() < 0.7:
			var r_p: float = PLANTER_R + 2.4
			var bp: float = a + TAU / 60.0 + rng.randf_range(-0.04, 0.04)
			var pp := Vector3(PLAZA_C.x + cos(bp) * r_p, LAND, PLAZA_C.y + sin(bp) * r_p)
			# Off the lap where it rounds the fountain (one stood 3.2m from its line).
			if _lap_dist(Vector2(pp.x, pp.z)) > ROAD_HALF + 2.5:
				people.append([pp, Vector3(PLAZA_C.x - pp.x, 0, PLAZA_C.y - pp.z).normalized(), false, false])
	var tmi := MeshInstance3D.new()
	tmi.name = "TerraceFurniture"
	tmi.mesh = d.save(MarinaKit.commit(tpk, tkit), "plaza_terraces")
	tmi.visibility_range_end = 600.0
	tbody.add_child(tmi)
	_own(tbody)
	# The fountain's own lights round it, under the bowls' glow.
	for k in range(4):
		var a2: float = TAU * (float(k) + 0.5) / 4.0
		_light(node, "PlazaFountainGlow_%d" % k, at + Vector3(cos(a2) * (FOUNTAIN_R + 4.0), 2.5, sin(a2) * (FOUNTAIN_R + 4.0)), Color(0.55, 0.75, 1.0), 1.6, 20.0, 200.0)
	print("Plaza: %d planters, %d people so far" % [angles.size(), people.size()])


# ======================================================================================
#  The bridges
# ======================================================================================

## A deck's edges from s0 to s1: walkways either side of the road (stone, flush with it), a balustrade along their outsides
## (stone posts and a rail, an LED strip under it), the deck's slab and fascia under them (a colour-drifting LED line
## along it), and where the deck stands over the land, retaining walls down to the ground. Solid: the walkways (part of
## the deck), the balustrade. `rail_u` is where the balustrade stands.
func _deck_edges(parent: Node3D, nm: String, s0: float, s1: float, rail_u: float, lanterns_every: float, lamp_lights: int) -> void:
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var body := StaticBody3D.new()
	body.name = nm + "Walkways"
	body.set_meta(&"surface", "asphalt")
	parent.add_child(body)
	var rails := StaticBody3D.new()
	rails.name = nm + "Balustrade"
	rails.set_meta(&"surface", "rock")
	parent.add_child(rails)
	var faces := PackedVector3Array()
	var stone := Color(0.84, 0.78, 0.68)
	var step := 2.0
	var n: int = maxi(1, ceili((s1 - s0) / step))
	for i in range(n):
		var sa: float = lerpf(s0, s1, float(i) / n)
		var sb: float = lerpf(s0, s1, float(i + 1) / n)
		var pa: Vector3 = _pt(sa)
		var pb: Vector3 = _pt(sb)
		var ra: Vector3 = _rt(sa)
		var rb: Vector3 = _rt(sb)
		for sd in [-1.0, 1.0]:
			var w0: float = ROAD_HALF
			var w1: float = rail_u + 0.25
			# Flush with the deck (3cm): at 15cm the walkways' kerb was a step at the road's very edge.
			var up := Vector3(0, 0.03, 0)
			# The walkway's top and its kerb face.
			var q0: Vector3 = pa + ra * sd * w0 + up
			var q1: Vector3 = pa + ra * sd * w1 + up
			var q2: Vector3 = pb + rb * sd * w1 + up
			var q3: Vector3 = pb + rb * sd * w0 + up
			pk.quad(kit, "marble", [q0, q1, q2, q3], Vector3.UP, stone.darkened(0.1))
			faces.append_array(PackedVector3Array([q0, q1, q2, q0, q2, q3]))
			var k0: Vector3 = pa + ra * sd * w0
			var k3: Vector3 = pb + rb * sd * w0
			pk.quad(kit, "marble", [k0, q0, q3, k3], -ra * sd, stone.darkened(0.25))
			faces.append_array(PackedVector3Array([k0, q0, q3, k0, q3, k3]))
			# The slab's fascia under the walkway's outer edge and the LED line along it.
			var f0: Vector3 = pa + ra * sd * (w1 + 0.1)
			var f1: Vector3 = pb + rb * sd * (w1 + 0.1)
			pk.quad(kit, "marble", [f0 + up, f1 + up, f1 - Vector3(0, 1.1, 0), f0 - Vector3(0, 1.1, 0)], ra * sd, stone.darkened(0.15))
			pk.quad(kit, "marble", [q1, f0 + up, f1 + up, q2], Vector3.UP, stone)
			var led_a: Vector3 = f0 + ra * sd * 0.02 - Vector3(0, 0.35, 0)
			var led_b: Vector3 = f1 + rb * sd * 0.02 - Vector3(0, 0.35, 0)
			pk.tri(kit, "ledchase", led_a - Vector3(0, 0.06, 0), led_b - Vector3(0, 0.06, 0), led_b + Vector3(0, 0.06, 0), ra * sd, rb * sd, rb * sd, Color.WHITE, ra * sd,
					Vector2(sa, 0), Vector2(sb, 0), Vector2(sb, 1))
			pk.tri(kit, "ledchase", led_a - Vector3(0, 0.06, 0), led_b + Vector3(0, 0.06, 0), led_a + Vector3(0, 0.06, 0), ra * sd, rb * sd, ra * sd, Color.WHITE, ra * sd,
					Vector2(sa, 0), Vector2(sb, 1), Vector2(sa, 1))
			# The slab's underside.
			pk.quad(kit, "marble", [pa + ra * sd * (w1 + 0.1) - Vector3(0, 1.1, 0), pb + rb * sd * (w1 + 0.1) - Vector3(0, 1.1, 0), pb - Vector3(0, 1.1, 0), pa - Vector3(0, 1.1, 0)], Vector3.DOWN, stone.darkened(0.35))
			# The balustrade: a base rail, posts, a handrail with an LED strip under it.
			var ba: Vector3 = pa + ra * sd * rail_u + up
			var bb: Vector3 = pb + rb * sd * rail_u + up
			pk.beam(kit, "marble", ba + Vector3(0, 0.12, 0), bb + Vector3(0, 0.12, 0), 0.34, 0.24, stone)
			pk.beam(kit, "marble", ba + Vector3(0, 1.0, 0), bb + Vector3(0, 1.0, 0), 0.32, 0.14, stone.lightened(0.1))
			pk.beam(kit, "led", ba + Vector3(0, 0.9, 0) - ra * sd * 0.12, bb + Vector3(0, 0.9, 0) - rb * sd * 0.12, 0.05, 0.04, MarinaKit.WARM)
			pk.box(kit, "marble", Transform3D(Basis(), ba + Vector3(0, 0.55, 0)), Vector3(0.16, 0.7, 0.16), stone)
			var bx: Array = _lap_box(sa, sb, sd * rail_u, 0.03 + 0.7, 0.4, 1.4)
			_box_shape(rails, bx[0], bx[1])
			# Over the land: a retaining wall from the ground up to the walkway's edge.
			var ga: float = d.ground(f0.x, f0.z)
			var gb: float = d.ground(f1.x, f1.z)
			if AT.marina_water_d(f0.x, f0.z) < -1.5 and pa.y - 1.1 > ga + 0.05:
				pk.quad(kit, "marble", [f0 - Vector3(0, 1.1, 0), f1 - Vector3(0, 1.1, 0), Vector3(f1.x, gb - 0.3, f1.z), Vector3(f0.x, ga - 0.3, f0.z)], ra * sd, Color(0.74, 0.68, 0.58))
				var wb: Array = _lap_box(sa, sb, sd * (w1 + 0.3), 0.03 - (pa.y - ga) * 0.5, 0.6, (pa.y - ga) + 0.3)
				_box_shape(rails, wb[0], wb[1])
	# Wing walls flaring out from the balustrade's start on the way in: a cart coming in wide is turned onto the deck,
	# not let past the balustrade's end to wedge beside the ramp (two bots did on the creek bridge).
	for sd in [-1.0, 1.0]:
		var n_w := 9
		for i in range(n_w):
			var ta: float = float(i) / n_w
			var tb: float = float(i + 1) / n_w
			var sa: float = s0 - 20.0 * (1.0 - ta)
			var sb: float = s0 - 20.0 * (1.0 - tb)
			var ua: float = sd * (rail_u + 5.0 * (1.0 - ta) * (1.0 - ta))
			var ub: float = sd * (rail_u + 5.0 * (1.0 - tb) * (1.0 - tb))
			var a: Vector3 = _pt(sa) + _rt(sa) * ua + Vector3(0, 0.03, 0)
			var b: Vector3 = _pt(sb) + _rt(sb) * ub + Vector3(0, 0.03, 0)
			pk.beam(kit, "marble", a + Vector3(0, 0.45, 0), b + Vector3(0, 0.45, 0), 0.4, 1.2, stone)
			pk.beam(kit, "led", a + Vector3(0, 1.06, 0), b + Vector3(0, 1.06, 0), 0.08, 0.04, MarinaKit.WARM)
			var mid: Vector3 = (a + b) * 0.5 + Vector3(0, 0.45, 0)
			var dir: Vector3 = (b - a)
			var flat := Vector3(dir.x, 0.0, dir.z).normalized()
			_box_shape(rails, Transform3D(Basis(Vector3.UP.cross(flat).normalized(), Vector3.UP, flat), mid), Vector3(0.5, 1.5, dir.length() + 0.1))
	# Lantern posts on the balustrade, some lit.
	if lanterns_every > 0.0:
		var s := s0 + lanterns_every * 0.5
		var k := 0
		var mid: float = (s0 + s1) * 0.5
		while s < s1:
			for sd in [-1.0, 1.0]:
				var lp: Vector3 = _pt(s) + _rt(s) * sd * rail_u + Vector3(0, 0.03, 0)
				pk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), lp))
				MarinaKit.lantern_post(pk, kit, 3.0)
				pk.set_frame(Transform3D.IDENTITY)
				if k < lamp_lights * 2 and absf(s - mid) < lanterns_every * float(lamp_lights) * 0.5 + 1.0:
					_light(parent, "%sLantern_%d" % [nm, k], lp + Vector3(0, 4.2 * PS, 0), Color(1.0, 0.8, 0.52), 2.2, 22.0)
					k += 1
			s += lanterns_every
	var cs := CollisionShape3D.new()
	var sh := ConcavePolygonShape3D.new()
	sh.backface_collision = true
	sh.set_faces(faces)
	cs.shape = d.save(sh, nm.to_lower() + "_walkways")
	body.add_child(cs)
	_own(body)
	var mi := MeshInstance3D.new()
	mi.name = nm + "Structure"
	mi.mesh = d.save(MarinaKit.commit(pk, kit), nm.to_lower() + "_edges")
	rails.add_child(mi)
	_own(rails)


## Jisr al-Qamar: the corniche's humped bridge over the creek's mouth, on two arch ribs of white stone springing from
## the quays, spandrel columns up to the deck, LEDs along the ribs' undersides, lanterns on the balustrade, uplights at
## the springings washing the arches.
func _build_arc_bridge(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "QamarBridge"
	root.add_child(node)
	node.owner = level
	_deck_edges(node, "Qamar", s_bc - ARC_HALF, s_bc + ARC_HALF, 9.4, 14.0, 2)
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var white := Color(0.90, 0.87, 0.80)
	var spring0: float = s_q0 - 4.0
	var spring1: float = s_q1 + 4.0
	var hs: float = (spring1 - spring0) * 0.5
	var sc: float = (spring0 + spring1) * 0.5
	var crown: float = _lap_y(s_bc) - 1.12
	var base: float = 0.4
	var rise: float = crown - base
	var big_r: float = (hs * hs + rise * rise) / (2.0 * rise)
	var cy: float = crown - big_r
	var arch_y := func(s: float) -> float:
		var dd: float = s - sc
		return cy + sqrt(maxf(big_r * big_r - dd * dd, 0.0))
	for u in [-6.0, 6.0]:
		var n := 40
		for i in range(n):
			var sa: float = lerpf(spring0, spring1, float(i) / n)
			var sb: float = lerpf(spring0, spring1, float(i + 1) / n)
			var a: Vector3 = _pt(sa) + _rt(sa) * u
			var b: Vector3 = _pt(sb) + _rt(sb) * u
			a.y = arch_y.call(sa)
			b.y = arch_y.call(sb)
			pk.beam(kit, "marble", a - Vector3(0, 0.7, 0), b - Vector3(0, 0.7, 0), 2.0, 1.4, white, _rt(sa))
			# A line of light along each rib's outer face (seen from the sea and from up the creek).
			var side_o: Vector3 = _rt(sa) * signf(u) * 1.02
			var side_ob: Vector3 = _rt(sb) * signf(u) * 1.02
			var on: Vector3 = _rt(sa) * signf(u)
			pk.tri(kit, "ledchase", a + side_o - Vector3(0, 0.25, 0), b + side_ob - Vector3(0, 0.25, 0), b + side_ob - Vector3(0, 0.55, 0), on, on, on, Color.WHITE, on,
					Vector2(sa, 0), Vector2(sb, 0), Vector2(sb, 1))
			pk.tri(kit, "ledchase", a + side_o - Vector3(0, 0.25, 0), b + side_ob - Vector3(0, 0.55, 0), a + side_o - Vector3(0, 0.55, 0), on, on, on, Color.WHITE, on,
					Vector2(sa, 0), Vector2(sb, 1), Vector2(sa, 1))
			# The intrados's LED, drifting colours along the arch.
			var la: Vector3 = a - Vector3(0, 1.42, 0)
			var lb: Vector3 = b - Vector3(0, 1.42, 0)
			var rr: Vector3 = _rt(sa) * 0.5
			pk.tri(kit, "ledchase", la - rr, lb - rr, lb + rr, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Color.WHITE, Vector3.DOWN, Vector2(sa, 0), Vector2(sb, 0), Vector2(sb, 1))
			pk.tri(kit, "ledchase", la - rr, lb + rr, la + rr, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Color.WHITE, Vector3.DOWN, Vector2(sa, 0), Vector2(sb, 1), Vector2(sa, 1))
		# Spandrel columns from the rib up to the slab every 5m.
		var s := spring0 + 5.0
		while s < spring1 - 4.0:
			var top: float = _lap_y(s) - 1.1
			var bot: float = arch_y.call(s)
			if top - bot > 0.6:
				var c: Vector3 = _pt(s) + _rt(s) * u
				pk.box(kit, "marble", Transform3D(Basis.looking_at(_fw(s), Vector3.UP), Vector3(c.x, (top + bot) * 0.5, c.z)), Vector3(1.0, top - bot, 1.0), white.darkened(0.05))
			s += 5.0
	# The abutments: stone blocks on the quays from the bed up under the slab at the springings.
	for e in [[spring0, -1.0], [spring1, 1.0]]:
		var se: float = e[0]
		var dir: float = e[1]
		for k in range(4):
			var sk: float = se + dir * float(k) * 2.0
			var c2: Vector3 = _pt(sk)
			pk.box(kit, "stone", Transform3D(Basis.looking_at(_fw(sk), Vector3.UP), Vector3(c2.x, (-4.5 + _lap_y(sk) - 1.1) * 0.5, c2.z)),
					Vector3(19.5, _lap_y(sk) - 1.1 + 4.5, 2.1), Color(0.78, 0.72, 0.62), 1.0)
		var up_at: Vector3 = _pt(se)
		for u2 in [-6.0, 6.0]:
			_light(node, "QamarUplight_%d_%d" % [int(dir), int(u2)], Vector3(up_at.x, 1.2, up_at.z) + _rt(se) * u2 - _fw(se) * dir * 3.0,
					Color(0.35, 0.65, 1.0), 3.0, 24.0, 300.0)
	# Under a body (no shapes: nothing reaches them), so DressingColliders leaves them be.
	var ab := StaticBody3D.new()
	ab.name = "QamarArchesBody"
	node.add_child(ab)
	var mi := MeshInstance3D.new()
	mi.name = "QamarArches"
	mi.mesh = d.save(MarinaKit.commit(pk, kit), "qamar_arches")
	ab.add_child(mi)
	_own(ab)
	print("Jisr al-Qamar: crown %.1fm over the water, span %.0fm" % [_lap_y(s_bc), spring1 - spring0])


## The north road's bridge over the creek: its deck's edges (the CreekArch, _build_arch, stands over it).
func _build_creek_bridge(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "CreekBridge"
	root.add_child(node)
	node.owner = level
	_deck_edges(node, "Creek", s_arch - BRIDGE_FLAT - BRIDGE_RAMP, s_arch + BRIDGE_FLAT + BRIDGE_RAMP, 9.2, 0.0, 0)


## The arch over the north road's bridge: a steel arch rib either side of the deck, springing from stone piers on the
## quays, hangers down to the deck's edge, lights along the ribs. Named "CreekArch" (not "...Bridge": PlayerCart counts
## that as road).
func _build_arch(root: Node3D) -> void:
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var span: float = AT.MARINA_CREEK_HALF + 14.0
	var steel := Color(0.85, 0.86, 0.88)
	for sd in [-1.0, 1.0]:
		var pts: Array = []
		for i in range(25):
			var t: float = float(i) / 24.0
			var s: float = s_arch - span + 2.0 * span * t
			var p: Vector3 = _pt(s) + Vector3(0, 0.15, 0)
			var rise: float = 24.0 * sin(PI * t)
			pts.append([p + _rt(s) * sd * 10.8 + Vector3(0, rise, 0), p + _rt(s) * sd * 10.8, s])
		for i in range(pts.size() - 1):
			pk.tube(kit, "metal", pts[i][0], pts[i + 1][0], 0.55, 0.55, 8, steel, false)
			if i % 2 == 1:
				pk.tube(kit, "metal", pts[i][0], (pts[i][1] as Vector3) - _rt(float(pts[i][2])) * sd * 1.3, 0.07, 0.07, 5, steel)
				pk.box(kit, "led", Transform3D(Basis(), (pts[i][0] as Vector3) + Vector3(0, 0.7, 0)), Vector3(0.35, 0.2, 0.35), Color(0.75, 0.85, 1.0))
			# An LED line along the rib's top.
			pk.tube(kit, "led", (pts[i][0] as Vector3) + Vector3(0, 0.56, 0), (pts[i + 1][0] as Vector3) + Vector3(0, 0.56, 0), 0.06, 0.06, 4, Color(0.7, 0.85, 1.0), false)
		# Piers on the quays under the arch's feet.
		for e in [0, pts.size() - 1]:
			var f: Vector3 = pts[e][1]
			pk.block(kit, "stone", Vector3(f.x - 1.6, LAND - 3.0, f.z - 1.6), Vector3(f.x + 1.6, f.y + 0.8, f.z + 1.6), Color(0.76, 0.70, 0.60))
	var body := StaticBody3D.new()
	body.name = "CreekArchPiers"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "CreekArch"
	mi.mesh = d.save(MarinaKit.commit(pk, kit), "creek_arch")
	body.add_child(mi)
	for sd in [-1.0, 1.0]:
		for e in [s_arch - span, s_arch + span]:
			var f2: Vector3 = _pt(e) + _rt(e) * sd * 10.8
			_box_shape(body, Transform3D(Basis(), Vector3(f2.x, f2.y + 1.5, f2.z)), Vector3(3.2, 4.0, 3.2))
	_own(body)


# ======================================================================================
#  Mamar al-Bahr, the glass tube
# ======================================================================================

var _tube_cc := 0.0      # the vault circle's centre over the deck
var _tube_rr := 0.0      # and its radius

## A point of the tube's cross-section at s: `u` across (right +), `v` up from the deck.
func _tube_at(s: float, u: float, v: float) -> Vector3:
	return _pt(s) + _rt(s) * u + Vector3(0.0, v, 0.0)


## The vault's circle at angle phi (0 at the right, PI/2 at the crown), radius `r`.
func _vault(s: float, phi: float, r: float) -> Vector3:
	return _tube_at(s, cos(phi) * r, _tube_cc + sin(phi) * r)


func _build_tube(root: Node3D) -> void:
	_tube_cc = (TUBE_CROWN * TUBE_CROWN - TUBE_HALF * TUBE_HALF) / (2.0 * TUBE_CROWN)
	_tube_rr = TUBE_CROWN - _tube_cc
	var node := Node3D.new()
	node.name = "GlassTube"
	root.add_child(node)
	node.owner = level
	var walls := StaticBody3D.new()
	walls.name = "TubeWalls"
	walls.set_meta(&"surface", "rock")
	node.add_child(walls)
	var steel := Color(0.86, 0.88, 0.90)
	var white := Color(0.92, 0.92, 0.94)
	# The vault springs from the upstands' tops, 0.7m up.
	var phi0: float = asin((0.7 - _tube_cc) / _tube_rr)
	var phi1: float = PI - phi0
	var arc_n := 18
	var piece_len := 48.0
	var s := s_tw
	var piece := 0
	var rib_s: float = s_tw
	while s < s_te - 0.01:
		var se: float = minf(s + piece_len, s_te)
		var pk := MarinaKit.new_kit(1.0)
		var kit := {}
		var n: int = maxi(1, ceili((se - s) / 2.0))
		for i in range(n):
			var sa: float = lerpf(s, se, float(i) / n)
			var sb: float = lerpf(s, se, float(i + 1) / n)
			for sd in [-1.0, 1.0]:
				# The upstand along the deck's edge, its LED line, its collider (taller than it, inside the glass).
				var ua: float = sd * (TUBE_HALF + 0.0)
				pk.beam(kit, "marble", _tube_at(sa, ua, 0.35), _tube_at(sb, ua, 0.35), 0.6, 0.7, white, _rt(sa))
				pk.beam(kit, "led", _tube_at(sa, sd * (TUBE_HALF - 0.32), 0.71), _tube_at(sb, sd * (TUBE_HALF - 0.32), 0.71), 0.06, 0.03, Color(0.4, 0.85, 1.0), _rt(sa))
				var wb: Array = _lap_box(sa, sb, sd * (TUBE_HALF + 0.15), 1.7, 0.9, 3.4)
				_box_shape(walls, wb[0], wb[1])
				# The girder under the deck: its slanted fascia, an LED line along its top.
				var f0: Vector3 = _tube_at(sa, sd * (TUBE_HALF + 0.35), 0.0)
				var f1: Vector3 = _tube_at(sb, sd * (TUBE_HALF + 0.35), 0.0)
				var g0: Vector3 = _tube_at(sa, sd * (TUBE_HALF - 2.6), -1.7)
				var g1: Vector3 = _tube_at(sb, sd * (TUBE_HALF - 2.6), -1.7)
				pk.quad(kit, "paintsteel", [f0, f1, g1, g0], (_rt(sa) * sd + Vector3(0, -0.8, 0)).normalized(), white.darkened(0.1))
				pk.quad(kit, "marble", [_tube_at(sa, sd * (TUBE_HALF + 0.3), 0.0), f0, f1, _tube_at(sb, sd * (TUBE_HALF + 0.3), 0.0)], Vector3.UP, white)
				pk.beam(kit, "led", f0 + _rt(sa) * sd * 0.04 - Vector3(0, 0.12, 0), f1 + _rt(sb) * sd * 0.04 - Vector3(0, 0.12, 0), 0.06, 0.08, MarinaKit.WARM, _rt(sa))
			pk.quad(kit, "paintsteel", [_tube_at(sa, -(TUBE_HALF - 2.6), -1.7), _tube_at(sb, -(TUBE_HALF - 2.6), -1.7), _tube_at(sb, TUBE_HALF - 2.6, -1.7), _tube_at(sa, TUBE_HALF - 2.6, -1.7)], Vector3.DOWN, white.darkened(0.3))
			# The glass over this 2m: one strip round the vault.
			for j in range(arc_n):
				var p0: float = lerpf(phi0, phi1, float(j) / arc_n)
				var p1: float = lerpf(phi0, phi1, float(j + 1) / arc_n)
				var a0: Vector3 = _vault(sa, p0, _tube_rr)
				var a1: Vector3 = _vault(sa, p1, _tube_rr)
				var b0: Vector3 = _vault(sb, p0, _tube_rr)
				var b1: Vector3 = _vault(sb, p1, _tube_rr)
				var out: Vector3 = (a0 + a1) * 0.5 - _tube_at(sa, 0.0, _tube_cc)
				var u0: float = (p0 - phi0) * _tube_rr
				var u1: float = (p1 - phi0) * _tube_rr
				pk.tri(kit, "tubeglass", a0, b0, b1, out, out, out, Color.WHITE, out, Vector2(u0, sa), Vector2(u0, sb), Vector2(u1, sb))
				pk.tri(kit, "tubeglass", a0, b1, a1, out, out, out, Color.WHITE, out, Vector2(u0, sa), Vector2(u1, sb), Vector2(u1, sa))
		# Ribs every TUBE_RIB: steel round the vault, an LED strip along their inner faces; purlins between them.
		while rib_s <= se + 0.001 and rib_s <= s_te:
			for j in range(arc_n):
				var p0: float = lerpf(phi0, phi1, float(j) / arc_n)
				var p1: float = lerpf(phi0, phi1, float(j + 1) / arc_n)
				pk.beam(kit, "ribsteel", _vault(rib_s, p0, _tube_rr - 0.28), _vault(rib_s, p1, _tube_rr - 0.28), 0.32, 0.5, steel, _fw(rib_s))
				pk.beam(kit, "ribled", _vault(rib_s, p0, _tube_rr - 0.55), _vault(rib_s, p1, _tube_rr - 0.55), 0.1, 0.05, Color(0.75, 0.92, 1.0), _fw(rib_s))
			var nxt: float = minf(rib_s + TUBE_RIB, s_te)
			if nxt > rib_s + 0.5:
				for ph in [0.35, 0.95, PI * 0.5, PI - 0.95, PI - 0.35]:
					pk.tube(kit, "ribsteel", _vault(rib_s, ph, _tube_rr - 0.22), _vault(nxt, ph, _tube_rr - 0.22), 0.09, 0.09, 6, steel, false)
			rib_s += TUBE_RIB
		# Piers every 24m where the deck stands over the water: two round columns from the bed to the girder, a cap, a
		# lit ring at the waterline.
		var sp: float = ceilf((s - s_tw) / 24.0) * 24.0 + s_tw
		while sp < se:
			var c: Vector3 = _pt(sp)
			var gy: float = d.ground(c.x, c.z)
			if c.y - 1.7 - gy > 1.0:
				for u in [-4.6, 4.6]:
					var base: Vector3 = _tube_at(sp, u, 0.0)
					pk.tube(kit, "marble", Vector3(base.x, gy - 0.5, base.z), Vector3(base.x, c.y - 1.7, base.z), 0.95, 0.85, 12, white.darkened(0.08))
					if gy < 0.0:
						pk.tube(kit, "led", Vector3(base.x, 0.15, base.z), Vector3(base.x, 0.45, base.z), 1.0, 0.92, 12, Color(0.35, 0.75, 1.0), false)
				pk.box(kit, "marble", Transform3D(Basis.looking_at(_fw(sp), Vector3.UP), c - Vector3(0, 2.15, 0)), Vector3(12.0, 0.9, 2.2), white.darkened(0.12))
			sp += 24.0
		var mi := MeshInstance3D.new()
		mi.name = "Tube_%d" % piece
		mi.mesh = d.save(MarinaKit.commit(pk, kit), "tube_%d" % piece)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		walls.add_child(mi)
		piece += 1
		s = se
	# The portals at both ends: a deep stone frame round the vault's end, an LED line round its inside, the name over it.
	var ppk := MarinaKit.new_kit(1.0)
	var pkit := {}
	for e in [[s_tw, 1.0], [s_te, -1.0]]:
		var se2: float = e[0]
		var inward: float = e[1]
		var sa2: float = se2 - inward * 0.2
		var sb2: float = se2 + inward * 2.2
		for j in range(arc_n):
			var p0: float = lerpf(phi0, phi1, float(j) / arc_n)
			var p1: float = lerpf(phi0, phi1, float(j + 1) / arc_n)
			for ss in [sa2, sb2]:
				var o0: Vector3 = _vault(ss, p0, _tube_rr + 1.6)
				var o1: Vector3 = _vault(ss, p1, _tube_rr + 1.6)
				var i0: Vector3 = _vault(ss, p0, _tube_rr + 0.1)
				var i1: Vector3 = _vault(ss, p1, _tube_rr + 0.1)
				var fn: Vector3 = _fw(se2) * (-inward if ss == sa2 else inward)
				pk_quad2(ppk, pkit, "marble", [o0, o1, i1, i0], fn, Color(0.93, 0.91, 0.86))
			pk_quad2(ppk, pkit, "marble", [_vault(sa2, p0, _tube_rr + 1.6), _vault(sb2, p0, _tube_rr + 1.6), _vault(sb2, p1, _tube_rr + 1.6), _vault(sa2, p1, _tube_rr + 1.6)],
					_vault(se2, (p0 + p1) * 0.5, 1.0) - _tube_at(se2, 0.0, _tube_cc), Color(0.90, 0.88, 0.82))
			pk_quad2(ppk, pkit, "led", [_vault(sa2 - inward * 0.02, p0, _tube_rr + 0.15), _vault(sa2 - inward * 0.02, p1, _tube_rr + 0.15),
					_vault(sa2 - inward * 0.02, p1, _tube_rr + 0.45), _vault(sa2 - inward * 0.02, p0, _tube_rr + 0.45)], -_fw(se2) * inward, Color(1.0, 0.85, 0.55))
		# The frame's feet down to the ground either side.
		for sd in [-1.0, 1.0]:
			var foot: Vector3 = _tube_at((sa2 + sb2) * 0.5, sd * (TUBE_HALF + 1.4), 0.0)
			ppk.box(pkit, "marble", Transform3D(Basis.looking_at(_fw(se2), Vector3.UP), Vector3(foot.x, LAND + 0.4, foot.z)), Vector3(2.4, 1.6, 2.6), Color(0.86, 0.84, 0.78))
		var lbl := Label3D.new()
		lbl.name = "TubeName_%d" % int(inward)
		lbl.text = "MAMAR AL-BAHR"
		lbl.font_size = 96
		lbl.pixel_size = 0.03
		lbl.modulate = Color(1.4, 1.15, 0.8)
		lbl.outline_size = 0
		lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		lbl.double_sided = false
		var top_at: Vector3 = _tube_at(sa2 - inward * 0.05, 0.0, TUBE_CROWN + 1.0)
		# Read from the way the carts come: toward the entrance from the corniche, back into the tube at the exit.
		lbl.transform = Transform3D(Basis.looking_at(_fw(se2), Vector3.UP), top_at)
		node.add_child(lbl)
		lbl.owner = level
	var pmi := MeshInstance3D.new()
	pmi.name = "TubePortals"
	pmi.mesh = d.save(MarinaKit.commit(ppk, pkit), "tube_portals")
	walls.add_child(pmi)
	_own(walls)
	# Light inside: a lamp under the crown every 32m.
	var sl: float = s_tw + 16.0
	var k := 0
	while sl < s_te - 8.0:
		_light(node, "TubeLight_%d" % k, _tube_at(sl, 0.0, TUBE_CROWN - 2.2), Color(0.75, 0.9, 1.0), 1.8, 17.0, 170.0)
		k += 1
		sl += 32.0
	print("Mamar al-Bahr: %.0fm, %d pieces, %d lights, deck %.1f-%.1fm" % [s_te - s_tw, piece, k, TUBE_Y, TUBE_CREST])


## Round the outside of the right turn into the tube (just off the bridge's crest), a wall of dark stone with glowing
## chevrons pointing into the turn: a cart that runs wide slides along it into the portal (one bot in eighteen had
## gone on onto the promenade and stuck by the quay).
func _build_turn_wall(root: Node3D) -> void:
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var body := StaticBody3D.new()
	body.name = "TubeTurnWall"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	# From where the corner's arc starts to the portal, on the left (the outside of a right turn).
	var s0: float = s_tw - 62.0
	var s1: float = s_tw + 1.0
	var u: float = -(ROAD_HALF + 1.6)
	var n: int = ceili((s1 - s0) / 2.0)
	var dark := Color(0.16, 0.16, 0.18)
	for i in range(n):
		var sa: float = lerpf(s0, s1, float(i) / n)
		var sb: float = lerpf(s0, s1, float(i + 1) / n)
		var a: Vector3 = _pt(sa) + _rt(sa) * u
		var b: Vector3 = _pt(sb) + _rt(sb) * u
		pk.beam(kit, "marble", a + Vector3(0, 0.6, 0), b + Vector3(0, 0.6, 0), 0.6, 1.3, dark)
		pk.beam(kit, "led", a + Vector3(0, 1.28, 0) + _rt(sa) * 0.31, b + Vector3(0, 1.28, 0) + _rt(sb) * 0.31, 0.04, 0.06, Color(1.0, 0.75, 0.3))
		var bx: Array = _lap_box(sa, sb, u, 0.75, 0.7, 1.5)
		_box_shape(body, bx[0], bx[1])
	# Chevrons on its face toward the road, every 4m: two strokes of light pointing the way the road turns.
	var s := s0 + 2.0
	while s < s1 - 1.0:
		var c: Vector3 = _pt(s) + _rt(s) * (u + 0.31) + Vector3(0, 0.62, 0)
		var f: Vector3 = _fw(s)
		var r: Vector3 = _rt(s)
		for k in range(2):
			var off: float = (float(k) - 0.5) * 0.7
			var tip: Vector3 = c + f * (off + 0.28)
			var top: Vector3 = c + f * (off - 0.12) + Vector3(0, 0.38, 0)
			var bot: Vector3 = c + f * (off - 0.12) - Vector3(0, 0.38, 0)
			pk.beam(kit, "led", top + r * 0.02, tip + r * 0.02, 0.12, 0.03, Color(1.0, 0.72, 0.25), r)
			pk.beam(kit, "led", tip + r * 0.02, bot + r * 0.02, 0.12, 0.03, Color(1.0, 0.72, 0.25), r)
		s += 4.0
	var mi := MeshInstance3D.new()
	mi.name = "TurnWallMesh"
	mi.mesh = d.save(MarinaKit.commit(pk, kit), "tube_turn_wall")
	body.add_child(mi)
	_own(body)


## A quad with both faces (for the portal frame's faces, whichever way the kit's frame turns them).
func pk_quad2(pk, kit: Dictionary, key: String, p: Array, n: Vector3, col: Color) -> void:
	pk.quad(kit, key, p, n.normalized(), col)


# ======================================================================================
#  Footprints: oriented boxes in plan (the souk packs its houses with them; nothing overlaps, so no roofs or plinths
#  at one height z-fight where two houses would have run into each other)
# ======================================================================================

var _foot: Array = []
var _fgrid := {}
const FCELL := 24.0

func _obb(c: Vector2, basis: Basis, hx: float, hz: float) -> Dictionary:
	var x3: Vector3 = basis.x
	var z3: Vector3 = basis.z
	return {"c": c, "ax": Vector2(x3.x, x3.z).normalized(), "az": Vector2(z3.x, z3.z).normalized(), "hx": hx, "hz": hz}


func _obb_hit(a: Dictionary, b: Dictionary, margin: float) -> bool:
	var dd: Vector2 = (b["c"] as Vector2) - (a["c"] as Vector2)
	for axis in [a["ax"], a["az"], b["ax"], b["az"]]:
		var l: Vector2 = axis
		var ra: float = float(a["hx"]) * absf((a["ax"] as Vector2).dot(l)) + float(a["hz"]) * absf((a["az"] as Vector2).dot(l))
		var rb: float = float(b["hx"]) * absf((b["ax"] as Vector2).dot(l)) + float(b["hz"]) * absf((b["az"] as Vector2).dot(l))
		if absf(dd.dot(l)) > ra + rb + margin:
			return false
	return true


func _foot_cells(o: Dictionary, margin: float) -> Array:
	var c: Vector2 = o["c"]
	var r: float = Vector2(float(o["hx"]), float(o["hz"])).length() + margin
	var out: Array = []
	for gz in range(floori((c.y - r) / FCELL), floori((c.y + r) / FCELL) + 1):
		for gx in range(floori((c.x - r) / FCELL), floori((c.x + r) / FCELL) + 1):
			out.append(Vector2i(gx, gz))
	return out


func _foot_free(o: Dictionary, margin: float) -> bool:
	for k in _foot_cells(o, margin):
		for i in _fgrid.get(k, []):
			if _obb_hit(o, _foot[i], margin):
				return false
	return true


func _foot_add(o: Dictionary) -> void:
	_foot.append(o)
	var i: int = _foot.size() - 1
	for k in _foot_cells(o, 0.0):
		if not _fgrid.has(k):
			_fgrid[k] = []
		(_fgrid[k] as Array).append(i)


func _obb_corners(o: Dictionary) -> Array:
	var c: Vector2 = o["c"]
	var ax: Vector2 = (o["ax"] as Vector2) * float(o["hx"])
	var az: Vector2 = (o["az"] as Vector2) * float(o["hz"])
	return [c - ax - az, c + ax - az, c + ax + az, c - ax + az, c - az, c + az, c - ax, c + ax]


## Whether a footprint keeps `clear` metres from the lap's line everywhere (its corners and the middles of its sides),
## 12m beside a raised deck (its walkways and walls), and off the plaza and the water.
func _lap_clear(o: Dictionary, clear: float) -> bool:
	for p in _obb_corners(o):
		var q: Vector2 = p
		var near: Array = d.road_near(q.x, q.y, clear + 14.0)
		var dist: float = near[0]
		if dist < clear + _corner_room(float(near[2])):
			return false
		if dist < 12.0 and _lap_y(float(near[2])) > LAND + ROAD_LIFT + 0.3:
			return false
		if AT.marina_water_d(q.x, q.y) > -3.0:
			return false
		if q.distance_to(PLAZA_C) < PLAZA_R + 8.0:
			return false
	return true


## Extra room beside the lap where it turns sharply (the souk's corners) and along the 32m out of each: a cart that runs
## wide has a few metres of pavement to come back from before the house fronts (a bot wedged there, 1.7m off the road).
func _corner_room(s: float) -> float:
	# From 8m before a corner to 32m past it, where a car run wide out of it goes (car 4 wedged in the houses 29m past
	# the right-hander at (-230, -75) in two races of three; with three of it a race, none in two).
	for ds in [-8.0, 0.0, 8.0, 16.0, 24.0, 32.0]:
		if absf(float(_at(s - ds)["k"])) > 0.03:
			return 2.3
	return 0.0


func _obb_has(o: Dictionary, q: Vector2, grow: float) -> bool:
	var dd: Vector2 = q - (o["c"] as Vector2)
	return absf(dd.dot(o["ax"])) <= float(o["hx"]) + grow and absf(dd.dot(o["az"])) <= float(o["hz"]) + grow


# ======================================================================================
#  The souk
# ======================================================================================

## The souk: houses packed close along both sides of its lanes (fronts a pavement's width off the road, lanterns and
## awnings on them), the blocks behind filled with more (courtyards, roof terraces, wind towers, water tanks, dishes),
## mud walls along the lanes wherever no house fronts them, a market hall on the long lane, a watchtower over the roofs,
## strings of bulbs across the lanes. Each 40m cell one mesh (DressingColliders makes it solid: a trimesh).
func _build_souk(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Souk"
	root.add_child(node)
	node.owner = level
	var cells := {}
	var get_kit := func(c: Vector2) -> Array:
		var key := Vector2i(floori(c.x / 40.0), floori(c.y / 40.0))
		if not cells.has(key):
			cells[key] = [MarinaKit.new_kit(PS), {}]
		return cells[key]
	var n_front := 0
	var n_fill := 0
	# The market hall, Souk al-Lulu, on the long lane's south side, and the watchtower inside the bend's block.
	var s_hall: float = _closest_s(Vector2(-170.0, -110.0), s_souk0, s_souk1)
	var hb: Basis = Basis.looking_at(_rt(s_hall), Vector3.UP)
	var hp: Vector3 = _pt(s_hall) - _rt(s_hall) * (9.2 + 7.6)
	var hall := _obb(Vector2(hp.x, hp.z), hb, 15.4, 7.6)
	if _lap_clear(hall, 8.9) and _foot_free(hall, 0.2):
		_foot_add(hall)
		var hk: Array = get_kit.call(Vector2(hp.x, hp.z))
		(hk[0] as PropKit).set_frame(Transform3D(hb.scaled(Vector3.ONE * PS), Vector3(hp.x, LAND, hp.z)))
		MarinaKit.souk_hall(hk[0], hk[1], 19.2, 9.5)
		var sign := Label3D.new()
		sign.name = "SoukHallName"
		sign.text = "SOUK AL-LULU"
		sign.font_size = 96
		sign.pixel_size = 0.018
		sign.modulate = Color(1.5, 1.2, 0.75)
		sign.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		sign.double_sided = false
		# On the upper storey's front over the arcade, read from the lane.
		sign.transform = Transform3D(Basis.looking_at(-_rt(s_hall), Vector3.UP), hp + _rt(s_hall) * (7.6 - 0.6 * PS + 0.12) + Vector3(0, LAND + 5.5 * PS, 0) - Vector3(0, hp.y, 0))
		node.add_child(sign)
		sign.owner = level
		_light(node, "SoukHallLight", hp + _rt(s_hall) * 10.0 + Vector3(0, 5.0, 0), Color(1.0, 0.72, 0.42), 2.2, 20.0)
	var tower_at := Vector2(-128.0, -205.0)
	var tw := _obb(tower_at, Basis(), 4.6 * PS, 4.6 * PS)
	if _foot_free(tw, 0.3) and _lap_clear(tw, 9.0):
		_foot_add(tw)
		var tk: Array = get_kit.call(tower_at)
		(tk[0] as PropKit).set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), Vector3(tower_at.x, LAND, tower_at.y)))
		ArabianKit.watchtower(tk[0], tk[1], 15.0, 3.4)
		_light(node, "SoukTowerLight", Vector3(tower_at.x, LAND + 26.0, tower_at.y), Color(1.0, 0.75, 0.45), 2.0, 22.0, 400.0)
	# Along the lanes, both sides, from the north road's end to the palm avenue.
	for sd in [-1.0, 1.0]:
		var s: float = s_souk0 + 1.0
		while s < s_souk1 + 30.0:
			var hr := RandomNumberGenerator.new()
			hr.seed = int(s * 10.0) * 7 + (1 if sd > 0.0 else 2)
			var w: float = hr.randf_range(5.0, 7.6) * PS
			var dep: float = hr.randf_range(6.0, 8.6) * PS
			var sc: float = s + w * 0.5
			var p: Vector3 = _pt(sc)
			var r: Vector3 = _rt(sc)
			var c3: Vector3 = p + r * sd * (9.2 + maxf(_corner_room(sc), maxf(_corner_room(s), _corner_room(s + w))) + dep * 0.5)
			var basis := Basis.looking_at(-r * sd, Vector3.UP)
			var o := _obb(Vector2(c3.x, c3.z), basis, w * 0.5, dep * 0.5)
			if _lap_clear(o, 8.9) and _foot_free(o, 0.12):
				_foot_add(o)
				var kk: Array = get_kit.call(Vector2(c3.x, c3.z))
				(kk[0] as PropKit).set_frame(Transform3D(basis.scaled(Vector3.ONE * PS), Vector3(c3.x, LAND, c3.z)))
				_souk_house(kk[0], kk[1], hr, w / PS, dep / PS, true)
				n_front += 1
				s += w + hr.randf_range(0.15, 0.4)
			else:
				s += 1.2
	# The blocks behind, filled from big houses to small, turned to the nearest lane.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5151
	var cand: Array = []
	var gz: float = SOUK.position.y
	while gz < SOUK.end.y:
		var gx: float = SOUK.position.x
		while gx < SOUK.end.x:
			cand.append(Vector2(gx + rng.randf_range(-1.5, 1.5), gz + rng.randf_range(-1.5, 1.5)))
			gx += 4.0
		gz += 4.0
	for i in range(cand.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp = cand[i]
		cand[i] = cand[j]
		cand[j] = tmp
	# Each spot's heading (the nearest lane's) once; spots on a lane are no use.
	var spots: Array = []
	for c in cand:
		var q: Vector2 = c
		var near: Array = d.road_near(q.x, q.y, 72.0)
		if float(near[0]) < 10.5:
			continue
		var yaw := 0.0
		if float(near[0]) < 72.0:
			yaw = float(_at(float(near[2]))["th"])
		spots.append([q, yaw])
	var sizes := [[8.6, 8.0], [7.6, 7.2], [6.6, 6.4], [5.6, 5.6], [4.6, 4.8]]
	for pass_i in range(sizes.size()):
		for sp in spots:
			var q: Vector2 = sp[0]
			var basis := Basis(Vector3.UP, -float(sp[1]) + (PI * 0.5 if rng.randf() < 0.5 else 0.0))
			var sz: Array = sizes[pass_i]
			var w: float = float(sz[0]) * PS * rng.randf_range(0.9, 1.08)
			var dep: float = float(sz[1]) * PS * rng.randf_range(0.9, 1.08)
			var yard: bool = pass_i < 2 and rng.randf() < 0.45
			var yd: float = rng.randf_range(5.0, 7.0) * PS if yard else 0.0
			var o := _obb(q, basis, w * 0.5, (dep + yd) * 0.5)
			if not _foot_free(o, 0.12) or not _lap_clear(o, 9.6):
				continue
			_foot_add(o)
			var hr2 := RandomNumberGenerator.new()
			hr2.seed = 90000 + n_fill
			var kk: Array = get_kit.call(q)
			# The house's own middle is forward of the footprint's by half the yard.
			var hc: Vector3 = Vector3(q.x, LAND, q.y) - basis.z * (yd * 0.5)
			(kk[0] as PropKit).set_frame(Transform3D(basis.scaled(Vector3.ONE * PS), hc))
			_souk_fill_house(kk[0], kk[1], hr2, w / PS, dep / PS, yard, yd / PS)
			n_fill += 1
	# Mud walls along the lanes wherever no house fronts them (no way through between the blocks).
	var n_wall := 0
	for sd in [-1.0, 1.0]:
		var run: Array = []
		var s := s_souk0 + 1.0
		while s < s_souk1 + 30.0:
			var e: Vector3 = _pt(s) + _rt(s) * sd * (9.4 + _corner_room(s))
			var q := Vector2(e.x, e.z)
			var covered: bool = d.road_dist(q.x, q.y, 20.0) < 8.6
			if not covered:
				for k in _foot_cells({"c": q, "hx": 0.5, "hz": 0.5}, 0.5):
					for i in _fgrid.get(k, []):
						if _obb_has(_foot[i], q, 0.5):
							covered = true
							break
					if covered:
						break
			if covered or AT.marina_water_d(q.x, q.y) > -2.0 or q.distance_to(PLAZA_C) < PLAZA_R + 6.0:
				if run.size() > 1:
					n_wall += _souk_wall(get_kit, run)
				run = []
			else:
				run.append(Vector3(e.x, LAND, e.z))
			s += 1.0
		if run.size() > 1:
			n_wall += _souk_wall(get_kit, run)
	for key in cells:
		var kv: Array = cells[key]
		var mi := MeshInstance3D.new()
		mi.name = "SoukBlock_%d_%d" % [key.x, key.y]
		mi.mesh = d.save(MarinaKit.commit(kv[0], kv[1]), "souk_%d_%d" % [key.x, key.y])
		mi.visibility_range_end = 1100.0
		node.add_child(mi)
		mi.owner = level
	print("Souk: %d houses on the lanes, %d behind, %d wall runs, %d cells" % [n_front, n_fill, n_wall, cells.size()])
	_souk_festoons(node)


## A house on a lane: ArabianKit's courtyard house without its yard (the blocks behind fill that), one to three storeys,
## two lanterns on brackets either side of the door, an awning over it.
func _souk_house(pk: PropKit, kit: Dictionary, hr: RandomNumberGenerator, w: float, dep: float, lanterns: bool) -> void:
	var storeys: int = 1 + hr.randi() % 2 + (1 if hr.randf() < 0.15 else 0)
	var key: String = "mud" if hr.randf() < 0.55 else "lime"
	ArabianKit.house(pk, kit, hr, w, dep, storeys, key, hr.randf() < 0.45, false)
	if lanterns:
		for sx in [-1.0, 1.0]:
			var lp := Vector3(sx * w * 0.32, 2.9, -dep * 0.5 - 0.5)
			pk.beam(kit, "timber", lp + Vector3(0, 0.4, 0.5), lp + Vector3(0, 0.4, 0), 0.06, 0.06, ArabianKit.POLE)
			pk.box(kit, "led", Transform3D(Basis(), lp), Vector3(0.28, 0.4, 0.28), Color(1.0, 0.66, 0.32))
	if hr.randf() < 0.7:
		var aw: Color = [Color(0.62, 0.16, 0.12), Color(0.15, 0.30, 0.45), Color(0.70, 0.52, 0.18), Color(0.20, 0.38, 0.25)][hr.randi() % 4]
		# Out a metre (life): over the pavement, short of the road (a gate settling under it would duck).
		pk.panel(kit, "awning", [Vector3(-w * 0.36, 2.62, -dep * 0.5 - 0.03), Vector3(w * 0.36, 2.62, -dep * 0.5 - 0.03), Vector3(w * 0.36, 2.25, -dep * 0.5 - 0.95),
				Vector3(-w * 0.36, 2.25, -dep * 0.5 - 0.95)], Vector3(0, 1, -0.4).normalized(), aw, aw.darkened(0.4))


## A house behind the lanes: ArabianKit's house (its yard when there's room), a roof terrace's clutter: water tanks,
## an air-conditioner, a dish, a washing line.
func _souk_fill_house(pk: PropKit, kit: Dictionary, hr: RandomNumberGenerator, w: float, dep: float, yard: bool, yd_life: float) -> void:
	var storeys: int = 1 + hr.randi() % 3
	var key: String = "mud" if hr.randf() < 0.6 else "lime"
	ArabianKit.house(pk, kit, hr, w, dep, storeys, key, hr.randf() < 0.55, yard, yd_life)
	var h: float = storeys * 3.3
	var white := Color(0.88, 0.88, 0.86)
	if hr.randf() < 0.7:
		var tx: float = hr.randf_range(-w * 0.3, w * 0.3)
		var tz: float = hr.randf_range(-dep * 0.25, dep * 0.25)
		pk.tube(kit, "paintsteel", Vector3(tx, h, tz), Vector3(tx, h + 1.1, tz), 0.55, 0.55, 10, white)
		for k in range(4):
			var a: float = TAU * (float(k) + 0.5) / 4.0
			pk.beam(kit, "metal", Vector3(tx + cos(a) * 0.4, h, tz + sin(a) * 0.4), Vector3(tx + cos(a) * 0.4, h + 0.25, tz + sin(a) * 0.4), 0.06, 0.06, Color(0.3, 0.3, 0.3))
	if hr.randf() < 0.6:
		pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(hr.randf_range(-w * 0.3, w * 0.3), h + 0.35, dep * 0.3)), Vector3(0.9, 0.7, 0.6), Color(0.82, 0.82, 0.80))
	if hr.randf() < 0.4:
		var dp := Vector3(hr.randf_range(-w * 0.35, w * 0.35), h + 0.9, -dep * 0.3)
		pk.tube(kit, "metal", Vector3(dp.x, h, dp.z), dp, 0.04, 0.04, 5, Color(0.5, 0.5, 0.5))
		pk.lathe(kit, "paintsteel", dp, [Vector2(0.0, 0.0), Vector2(0.45, 0.12), Vector2(0.55, 0.22)], 10, white, false, Basis(Vector3.RIGHT, -1.0))
	if hr.randf() < 0.3:
		var lx: float = w * 0.35
		var ly: float = h + 1.4
		pk.beam(kit, "metal", Vector3(-lx, h, 0), Vector3(-lx, ly, 0), 0.05, 0.05, Color(0.4, 0.4, 0.4))
		pk.beam(kit, "metal", Vector3(lx, h, 0), Vector3(lx, ly, 0), 0.05, 0.05, Color(0.4, 0.4, 0.4))
		var cols := [Color(0.85, 0.2, 0.2), Color(0.95, 0.95, 0.9), Color(0.2, 0.4, 0.8), Color(0.9, 0.75, 0.2)]
		for k in range(5):
			var x0: float = lerpf(-lx, lx, (float(k) + 0.3) / 5.0)
			pk.panel(kit, "awning", [Vector3(x0, ly - 0.02, 0), Vector3(x0 + 0.5, ly - 0.02, 0), Vector3(x0 + 0.5, ly - 0.7, 0), Vector3(x0, ly - 0.7, 0)],
					Vector3(0, 0, -1), cols[hr.randi() % cols.size()], cols[hr.randi() % cols.size()])


## A mud wall along a run of lane edge (world points on the ground): 2.6m (life) high with a coping and merlons.
func _souk_wall(get_kit: Callable, run: Array) -> int:
	var mid: Vector3 = run[run.size() / 2]
	var kk: Array = get_kit.call(Vector2(mid.x, mid.z))
	var pk: PropKit = kk[0]
	var kit: Dictionary = kk[1]
	pk.set_frame(Transform3D.IDENTITY)
	var col := ArabianKit.MUD.lerp(ArabianKit.MUD_PALE, 0.3)
	for i in range(run.size() - 1):
		var a: Vector3 = run[i]
		var b: Vector3 = run[i + 1]
		var h: float = 2.6 * PS
		pk.beam(kit, "mud", a + Vector3(0, h * 0.5 - 0.3, 0), b + Vector3(0, h * 0.5 - 0.3, 0), 0.55, h + 0.6, Color(col.r, col.g, col.b, 0.08), Vector3.ZERO, 1.0)
		pk.beam(kit, "lime", a + Vector3(0, h + 0.05, 0), b + Vector3(0, h + 0.05, 0), 0.7, 0.18, ArabianKit.LIME, Vector3.ZERO, 1.0)
	return 1


## Strings of bulbs across the souk's lanes every 12m (house front to house front, sagging) on its straight runs, and a
## warm light under every other one. Named "...Light..." so DressingColliders leaves them soft.
func _souk_festoons(parent: Node3D) -> void:
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var cols := [Color(1.0, 0.75, 0.4), Color(1.0, 0.5, 0.3), Color(0.9, 0.9, 0.6), Color(0.6, 0.85, 1.0)]
	var s: float = s_souk0
	var k := 0
	while s < s_souk1:
		if absf(float(_at(s)["k"])) > 0.02 or absf(float(_at(s + 6.0)["k"])) > 0.02 or absf(float(_at(s - 6.0)["k"])) > 0.02:
			s += 3.0
			continue
		var p: Vector3 = _pt(s)
		var right: Vector3 = _rt(s)
		var a: Vector3 = p + right * 9.1
		var b: Vector3 = p - right * 9.1
		a.y = LAND + 5.2
		b.y = LAND + 5.2
		var cnt := 18
		for i in range(cnt + 1):
			var t: float = float(i) / cnt
			var bp: Vector3 = a.lerp(b, t) - Vector3(0, sin(PI * t) * 1.3, 0)
			pk.box(kit, "led", Transform3D(Basis(), bp), Vector3(0.18, 0.18, 0.18), cols[(i + k) % cols.size()])
			if i < cnt:
				pk.beam(kit, "matte", bp, a.lerp(b, float(i + 1) / cnt) - Vector3(0, sin(PI * float(i + 1) / cnt) * 1.3, 0), 0.03, 0.03, Color(0.1, 0.1, 0.1))
		if k % 2 == 0:
			_light(parent, "SoukLight_%d" % k, Vector3(p.x, LAND + 4.0, p.z), Color(1.0, 0.7, 0.42), 2.6, 20.0, 120.0)
		k += 1
		s += 12.0
	var mi := MeshInstance3D.new()
	mi.name = "SoukLightStrings"
	mi.mesh = d.save(MarinaKit.commit(pk, kit), "souk_light_strings")
	mi.visibility_range_end = 500.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.owner = level
	print("Souk light strings: ", k)


# ======================================================================================
#  The city
# ======================================================================================

## The night material for the city's walls: lit rooms, offices and shop fronts (city_building.gdshader's evening
## lights, as Mtaa Nights), the glass reflecting a night sky.
func _city_material() -> ShaderMaterial:
	var m: ShaderMaterial = BloombayCity.wall_material(Color(0.02, 0.03, 0.07), Color(0.22, 0.16, 0.18), Color(0.04, 0.04, 0.05), Color(0.10, 0.10, 0.14))
	m.set_shader_parameter("gulf", true)
	m.set_shader_parameter("lit_share", 0.5)
	m.set_shader_parameter("lit_energy", 1.2)
	m.set_shader_parameter("lit_color", Color(1.0, 0.80, 0.55))
	m.set_shader_parameter("sky_reflect", Color(0.10, 0.12, 0.22))
	m.set_shader_parameter("glass_dark", Color(0.03, 0.05, 0.10))
	return d.save(m, "city_walls") as ShaderMaterial


var _city_mat: ShaderMaterial
var _roof_mat: StandardMaterial3D

## Room for a building of radius r at c: on land, off the lap (`setback` past its edge), the plaza, the marina walk,
## the souk, the wheel's shore; clear of what stands already and the palms.
func _free_plot(c: Vector2, r: float, setback: float) -> bool:
	if AT.marina_water_d(c.x, c.y) > -(r + 4.0):
		return false
	if d.road_dist(c.x, c.y, r + ROAD_HALF + setback + 30.0) < r + ROAD_HALF + setback:
		return false
	if _near_gate(c, r):
		return false
	if c.distance_to(PLAZA_C) < PLAZA_R + 14.0 + r:
		return false
	if c.x > 130.0 and c.x < 490.0 and AT.coast_z(c.x) - c.y < 72.0 + r:
		return false
	if SOUK.grow(6.0 + r).has_point(c):
		return false
	if c.x > 560.0 and c.y > 140.0:
		return false
	var o := _obb(c, Basis(), r * 0.72, r * 0.72)
	if not _foot_free(o, 3.0):
		return false
	for p in palms_at:
		if c.distance_to(p) < r + 3.0:
			return false
	return true


## The road's heading near (x, z), as a yaw for a building to face it.
func _face_road(c: Vector2) -> float:
	var near: Array = d.road_near(c.x, c.y, 200.0)
	var f: Vector3 = _fw(float(near[2]))
	return atan2(f.x, f.z)


func _build_city(root: Node3D) -> void:
	_city_mat = _city_material()
	_roof_mat = d.save(BloombayCity.roof_material(), "city_roofs") as StandardMaterial3D
	var cells := {}
	var rng := d.rng
	var towers := 0
	var blocks := 0
	# Small cells within the lamps' reach of the lap (each takes in only the lights near it), big ones beyond.
	var cell_of := func(c: Vector2) -> Vector3i:
		if d.road_dist(c.x, c.y, 90.0) < 90.0 or c.distance_to(PLAZA_C) < 160.0:
			return Vector3i(floori(c.x / 55.0), floori(c.y / 55.0), 0)
		return Vector3i(floori(c.x / 220.0), floori(c.y / 220.0), 1)
	# Towers first (downtown), tallest near the avenue's middle and round the plaza.
	for k in range(1400):
		var c := Vector2(rng.randf_range(DOWNTOWN.position.x, DOWNTOWN.end.x), rng.randf_range(DOWNTOWN.position.y, DOWNTOWN.end.y))
		var w: float = rng.randf_range(20.0, 32.0)
		var r: float = w * 0.75
		if not _free_plot(c, r, 6.0):
			continue
		var focus: float = 1.0 - clampf(minf(c.distance_to(Vector2(AVENUE_X + 60.0, -60.0)), c.distance_to(PLAZA_C) + 40.0) / 400.0, 0.0, 1.0)
		var h: float = lerpf(70.0, 300.0, focus * rng.randf_range(0.6, 1.0))
		var kind: int = towers % 5
		_foot_add(_obb(c, Basis(), r * (1.6 if kind == 4 else 1.0), r * (1.6 if kind == 4 else 1.0)))
		var key: Vector3i = cell_of.call(c)
		if not cells.has(key):
			cells[key] = GulfCity.new()
			(cells[key] as GulfCity).begin()
		(cells[key] as GulfCity).gulf_tower(c.x, c.y, LAND, w, h, kind, rng)
		towers += 1
		if towers >= 36:
			break
	# Blocks everywhere else on land: hotels and flats along the corniche, offices and flats inland.
	for k in range(10000):
		var c := Vector2(rng.randf_range(-760.0, 820.0), rng.randf_range(-760.0, 260.0))
		var w: float = rng.randf_range(18.0, 36.0)
		var dd: float = rng.randf_range(14.0, 26.0)
		var r: float = Vector2(w, dd).length() * 0.5
		if not _free_plot(c, r, 5.0):
			continue
		var near_road: float = d.road_dist(c.x, c.y, 120.0)
		var storeys: int = rng.randi_range(3, 7) if near_road < 120.0 else rng.randi_range(2, 5)
		if AT.coast_z(c.x) - c.y < 150.0:
			storeys = rng.randi_range(6, 14)   # hotels on the waterfront
		_foot_add(_obb(c, Basis(), r, r))
		var key: Vector3i = cell_of.call(c)
		if not cells.has(key):
			cells[key] = GulfCity.new()
			(cells[key] as GulfCity).begin()
		(cells[key] as GulfCity).gulf_block(c.x, c.y, LAND, w, dd, _face_road(c), storeys, GulfCity.SAND_WALLS[rng.randi() % GulfCity.SAND_WALLS.size()], rng.randi() % 4, rng)
		blocks += 1
	var node := Node3D.new()
	node.name = "City"
	root.add_child(node)
	node.owner = level
	for key in cells:
		var bc: GulfCity = cells[key]
		var mi := MeshInstance3D.new()
		mi.name = "CityBlock_%d_%d_%d" % [key.x, key.y, key.z]
		mi.mesh = d.save(bc.commit(_city_mat, _roof_mat), "city_%d_%d_%d" % [key.x, key.y, key.z])
		node.add_child(mi)
		mi.owner = level
	print("City: ", towers, " towers, ", blocks, " blocks in ", cells.size(), " cells")


## The city carries on past the terrain's edge, west, north and east: low blocks and towers with lit windows on a
## flat plain, out to the fog (the sea lies south). No colliders. Built `far` (no merlons or pergolas) in FAR_CELL
## cells: whole and in full detail it was one 133MB file, which GitHub refuses.
const FAR_CELL := 1300.0

func _build_far_city(root: Node3D) -> void:
	var far_cells := {}
	var r := RandomNumberGenerator.new()
	r.seed = 6161
	for k in range(900):
		var c := Vector2(r.randf_range(-2600.0, 2600.0), r.randf_range(-2600.0, 400.0))
		if absf(c.x) < 1000.0 and absf(c.y) < 1000.0:
			continue
		if c.y > AT.coast_z(c.x) - 60.0:
			continue
		var fk := Vector2i(floori(c.x / FAR_CELL), floori(c.y / FAR_CELL))
		if not far_cells.has(fk):
			var nb := GulfCity.new()
			nb.far = true
			nb.begin()
			far_cells[fk] = nb
		var bc: GulfCity = far_cells[fk]
		if r.randf() < 0.08:
			bc.gulf_tower(c.x, c.y, LAND, r.randf_range(22.0, 34.0), r.randf_range(80.0, 220.0), r.randi() % 5, r)
		else:
			bc.gulf_block(c.x, c.y, LAND, r.randf_range(25.0, 50.0), r.randf_range(20.0, 40.0), r.randf() * TAU, r.randi_range(2, 8),
					GulfCity.SAND_WALLS[r.randi() % GulfCity.SAND_WALLS.size()], r.randi() % 4, r)
	for fk in far_cells:
		var mi := MeshInstance3D.new()
		# "...Skyline": DressingColliders leaves it be (nothing reaches it).
		mi.name = "FarSkyline_%d_%d" % [fk.x, fk.y]
		mi.mesh = d.save((far_cells[fk] as GulfCity).commit(_city_mat, _roof_mat), "far_city_%d_%d" % [fk.x, fk.y])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		mi.owner = level
	# The plain under it.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cells := 70
	for j in range(cells):
		for i in range(cells):
			var x0: float = -3500.0 + i * 100.0
			var z0: float = -3500.0 + j * 100.0
			var cx: float = x0 + 50.0
			var cz: float = z0 + 50.0
			if absf(cx) < 1000.0 and absf(cz) < 1000.0:
				continue
			if cz > AT.coast_z(cx) - 20.0:
				continue
			for q in [[Vector3(x0, LAND - 0.3, z0), Vector3(x0 + 100, LAND - 0.3, z0), Vector3(x0 + 100, LAND - 0.3, z0 + 100)],
					[Vector3(x0, LAND - 0.3, z0), Vector3(x0 + 100, LAND - 0.3, z0 + 100), Vector3(x0, LAND - 0.3, z0 + 100)]]:
				for v in q:
					st.set_normal(Vector3.UP)
					st.set_color(Color(0.20, 0.18, 0.16))
					st.add_vertex(v)
	var pm := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	pm.surface_set_material(0, mat)
	var pmi := MeshInstance3D.new()
	pmi.name = "FarGround"
	pmi.mesh = d.save(pm, "far_ground")
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pmi)
	pmi.owner = level


# ======================================================================================
#  The promenades, the lamps, the palms, the balustrades
# ======================================================================================

## The marina walk (where the corniche ran before the tube took the lap out to sea) and the corniche's sea front:
## benches facing the sea, kiosks with café tables round them, lantern posts along the quay (some lit), people
## strolling and at the tables. Solid: a body of boxes and cylinders.
func _build_promenade(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Promenade"
	root.add_child(node)
	node.owner = level
	var body := StaticBody3D.new()
	body.name = "PromenadeFurniture"
	body.set_meta(&"surface", "rock")
	node.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2626
	var pieces := {}
	var get_kit := func(c: Vector2) -> Array:
		var key := Vector2i(floori(c.x / 60.0), floori(c.y / 60.0))
		if not pieces.has(key):
			pieces[key] = [MarinaKit.new_kit(PS), {}]
		return pieces[key]
	var cols := [Color(0.90, 0.88, 0.82), Color(0.62, 0.16, 0.14), Color(0.14, 0.32, 0.44), Color(0.78, 0.62, 0.30)]
	var clear := func(q: Vector2, r: float) -> bool:
		if d.road_dist(q.x, q.y, 40.0) < ROAD_HALF + 4.0 + r or _near_gate(q, r) or _in_stand(q, r + 1.0):
			return false
		if AT.marina_water_d(q.x, q.y) > -2.0:
			return false
		for p in palms_at:
			if q.distance_to(p) < r + 2.0:
				return false
		return true
	var x := -330.0
	var n := 0
	var lit := 0
	while x < 470.0:
		var cz: float = AT.coast_z(x)
		var walk: bool = x > 150.0
		# A lantern post on the quay every 20m (every third lit on the marina walk, every fourth on the corniche).
		var lq := Vector2(x, cz - 3.2)
		if clear.call(lq, 0.8):
			var kk: Array = get_kit.call(lq)
			(kk[0] as PropKit).set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), Vector3(lq.x, LAND, lq.y)))
			MarinaKit.lantern_post(kk[0], kk[1], 3.0)
			_cyl_shape(body, Vector3(lq.x, LAND + 1.0, lq.y), 0.55, 2.0)
			if n % (3 if walk else 4) == 0:
				_light(node, "PromenadeLamp_%d" % lit, Vector3(lq.x, LAND + 4.2 * PS, lq.y), Color(1.0, 0.8, 0.52), 2.0, 20.0)
				lit += 1
		# Benches facing the sea between them.
		var bq := Vector2(x + 10.0, AT.coast_z(x + 10.0) - 5.5)
		if clear.call(bq, 2.0):
			var kk2: Array = get_kit.call(bq)
			var sea := Vector3(0, 0, 1)
			(kk2[0] as PropKit).set_frame(Transform3D(Basis.looking_at(sea, Vector3.UP).scaled(Vector3.ONE * PS), Vector3(bq.x, LAND, bq.y)))
			MarinaKit.bench(kk2[0], kk2[1], 2.0)
			_box_shape(body, Transform3D(Basis(), Vector3(bq.x, LAND + 0.5, bq.y)), Vector3(2.2 * PS, 1.0, 0.6 * PS))
			if rng.randf() < 0.5:
				people.append([Vector3(bq.x + rng.randf_range(-0.8, 0.8) * PS, LAND + 0.45 * PS, bq.y), sea, true, false])
		# On the marina walk: kiosks every 60m with café tables, people strolling.
		if walk and n % 3 == 1:
			var kq := Vector2(x, cz - 26.0)
			if clear.call(kq, 4.0):
				var kk3: Array = get_kit.call(kq)
				(kk3[0] as PropKit).set_frame(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * PS), Vector3(kq.x, LAND, kq.y)))
				MarinaKit.kiosk(kk3[0], kk3[1], rng)
				_cyl_shape(body, Vector3(kq.x, LAND + 2.0, kq.y), 2.0 * PS, 4.0)
				for t in range(4):
					var a: float = TAU * (float(t) + rng.randf()) / 4.0
					var tq: Vector2 = kq + Vector2(cos(a), sin(a)) * 8.5
					if not clear.call(tq, 2.0):
						continue
					(kk3[0] as PropKit).set_frame(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * PS), Vector3(tq.x, LAND, tq.y)))
					MarinaKit.cafe_set(kk3[0], kk3[1], rng, cols[rng.randi() % cols.size()], 3 + rng.randi() % 2, true)
					_cyl_shape(body, Vector3(tq.x, LAND + 0.6, tq.y), 1.25 * PS, 1.2)
					for m in range(rng.randi_range(0, 3)):
						var b: float = rng.randf() * TAU
						var o := Vector3(cos(b), 0.0, sin(b))
						people.append([Vector3(tq.x, LAND + 0.45 * PS, tq.y) + o * 0.72 * PS, -o, true, false])
			for m in range(rng.randi_range(1, 4)):
				var pq := Vector2(x + rng.randf_range(-10.0, 10.0), cz - rng.randf_range(8.0, 40.0))
				if clear.call(pq, 0.6):
					var facing := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
					people.append([Vector3(pq.x, LAND, pq.y), facing, false, false])
		n += 1
		x += 20.0
	for key in pieces:
		var kv: Array = pieces[key]
		var mi := MeshInstance3D.new()
		mi.name = "PromenadePiece_%d_%d" % [key.x, key.y]
		mi.mesh = d.save(MarinaKit.commit(kv[0], kv[1]), "promenade_%d_%d" % [key.x, key.y])
		mi.visibility_range_end = 650.0
		body.add_child(mi)
	_own(body)
	print("Promenade: %d stops, %d lamps lit" % [n, lit])


## Whether q (x, z) lies within `margin` of the start's grandstand (opposite the finish line, on the sea side).
func _in_stand(q: Vector2, margin := 0.0) -> bool:
	if s_finish <= 0.0:
		return false
	var p: Vector3 = _pt(s_finish)
	var r: Vector3 = _rt(s_finish)
	var f: Vector3 = _fw(s_finish)
	var dd := Vector3(q.x - p.x, 0.0, q.y - p.z)
	var along: float = dd.dot(f)
	var lat: float = dd.dot(r)
	var half: float = STAND_LEN * PS * 0.5
	return absf(along) < half + margin and lat > STAND_LAT - 1.0 - margin and lat < STAND_LAT + 6.0 * 0.9 * PS + 1.5 + margin


## The start's promenade (the corniche's sea front by the grid and the line, and the city side opposite): a grandstand
## opposite the finish line under a canopy (named "Grandstand": StageAmbience cheers from it at the green light and the
## first finish), people two deep behind crowd barriers along both sides of the straight, banner poles at the line,
## shade sails over benches, kiosks with café tables, strings of lights between the palms, flower beds, a balloon seller,
## fishermen at the rail with their rods out, people strolling. Solid: the barriers, kiosks, masts and poles (a body of
## boxes and cylinders), the stand (a single mesh: DressingColliders makes it a trimesh), the people (DressingColliders).
func _build_start_promenade(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "StartPromenade"
	root.add_child(node)
	node.owner = level
	var body := StaticBody3D.new()
	body.name = "StartPromenadeSolids"
	body.set_meta(&"surface", "rock")
	node.add_child(body)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1212
	var taken: Array = []          # [Vector2, radius] of what stands on the promenade
	var free := func(q: Vector2, r: float) -> bool:
		if AT.marina_water_d(q.x, q.y) > -2.0 - r or d.road_dist(q.x, q.y, 30.0) < ROAD_HALF + 1.5 + r:
			return false
		for t in taken:
			if q.distance_to(t[0]) < r + float(t[1]):
				return false
		for pa in palms_at:
			if q.distance_to(pa) < r + 1.0:
				return false
		return true
	# The grandstand opposite the line.
	var sf: float = s_finish
	var rt: Vector3 = _rt(sf)
	var front: Vector3 = _pt(sf) + rt * STAND_LAT
	front.y = LAND
	var sb := Basis.looking_at(-rt, Vector3.UP)
	var spk := MarinaKit.new_kit(PS)
	spk.set_frame(Transform3D(sb.scaled(Vector3.ONE * PS), front))
	var skit := {}
	var seats: Array = MarinaKit.grandstand(spk, skit, STAND_LEN, 5)
	var stand := MeshInstance3D.new()
	stand.name = "Grandstand"
	stand.mesh = d.save(MarinaKit.commit(spk, skit), "grandstand")
	node.add_child(stand)
	stand.owner = level
	var seated := 0
	for st in seats:
		if rng.randf() < 0.72:
			var w: Vector3 = front + sb * ((st as Vector3) * PS)
			people.append([w, -rt, true, true])
			seated += 1
	var lbl := Label3D.new()
	lbl.name = "GrandstandName"
	lbl.text = "RC VIBE GP  -  MARINA NIGHTS"
	lbl.font_size = 96
	lbl.pixel_size = 0.009
	lbl.modulate = Color(1.4, 1.1, 0.7)
	lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	lbl.double_sided = false
	# On the front wall, read from the road.
	lbl.transform = Transform3D(Basis.looking_at(rt, Vector3.UP), front - rt * 0.2 + Vector3(0, 0.55 * PS, 0))
	node.add_child(lbl)
	lbl.owner = level
	# Crowd barriers along both sides of the straight, people two deep behind them (a third cheering or waving flags).
	var bpk := MarinaKit.new_kit(PS)
	var bkit := {}
	var ck = load("res://CampKit.gd").new(bpk)
	var n_bar := 0
	# The sea side's start past the south-west corner's exit (a bot run wide out of it stuck at the line's end).
	for side in [[1.0, sf - 105.0, sf + 34.0], [-1.0, sf - 95.0, sf + 34.0]]:
		var sd: float = side[0]
		var s: float = side[1]
		while s < float(side[2]):
			var p: Vector3 = _pt(s)
			var r: Vector3 = _rt(s)
			var bq: Vector3 = p + r * sd * BARRIER_LAT
			if _in_stand(Vector2(bq.x, bq.z), 1.0) or AT.marina_water_d(bq.x, bq.z) > -2.0:
				s += 3.0
				continue
			var fwd: Vector3 = _fw(s)
			var bb := Basis(fwd, Vector3.UP, fwd.cross(Vector3.UP)).orthonormalized()
			bpk.set_frame(Transform3D(bb.scaled(Vector3.ONE * PS), Vector3(bq.x, LAND, bq.z)))
			ck.crowd_barrier(bkit)
			_box_shape(body, Transform3D(bb, Vector3(bq.x, LAND + 0.85, bq.z)), Vector3(2.3 * PS, 1.7, 0.35))
			taken.append([Vector2(bq.x, bq.z), 1.9])
			n_bar += 1
			# Two rows behind it, a person every metre and a bit (some gaps).
			for row in [1.2, 2.3]:
				for k in range(3):
					if rng.randf() > 0.78:
						continue
					var along: float = (float(k) - 1.0) * 1.15 + rng.randf_range(-0.2, 0.2)
					var pp: Vector3 = bq + fwd * along + r * sd * (float(row) + rng.randf_range(-0.15, 0.15))
					var q := Vector2(pp.x, pp.z)
					var near_palm := false
					for pa in palms_at:
						if q.distance_to(pa) < 1.1:
							near_palm = true
					if near_palm or AT.marina_water_d(q.x, q.y) > -2.0:
						continue
					people.append([Vector3(pp.x, LAND, pp.z), -r * sd + fwd * rng.randf_range(-0.25, 0.25), false, rng.randf() < 0.35])
			s += 2.3 * PS + 0.12
	var bmi := MeshInstance3D.new()
	bmi.name = "StartBarriers"
	bmi.mesh = d.save(MarinaKit.commit(bpk, bkit), "start_barriers")
	bmi.visibility_range_end = 500.0
	body.add_child(bmi)
	# Everything else on the promenade, in one kit.
	var pk := MarinaKit.new_kit(PS)
	var kit := {}
	# Banner poles either side of the line, behind the barriers.
	for sd in [-1.0, 1.0]:
		var s2: float = sf - 36.0
		while s2 <= sf + 26.0:
			var p2: Vector3 = _pt(s2) + _rt(s2) * sd * (BARRIER_LAT + 0.6)
			var q2 := Vector2(p2.x, p2.z)
			if not _in_stand(q2, 0.5):
				var toward: Vector3 = -_rt(s2) * sd
				pk.set_frame(Transform3D(Basis(toward, Vector3.UP, toward.cross(Vector3.UP)).scaled(Vector3.ONE * PS), Vector3(p2.x, LAND, p2.z)))
				MarinaKit.banner_pole(pk, kit, 6.2)
				_cyl_shape(body, Vector3(p2.x, LAND + 1.5, p2.z), 0.15, 3.0)
				taken.append([q2, 1.0])
			s2 += 12.0
	# Along the promenade from the south-west corner to the bridge: shade sails over benches, kiosks with café tables,
	# flower beds, fishermen at the rail, people strolling.
	var cols := [Color(0.90, 0.88, 0.82), Color(0.62, 0.16, 0.14), Color(0.14, 0.32, 0.44), Color(0.78, 0.62, 0.30)]
	var s3: float = 10.0
	var k3 := 0
	while s3 < s_bc - ARC_HALF - 10.0:
		var p3: Vector3 = _pt(s3)
		var r3: Vector3 = _rt(s3)
		var f3: Vector3 = _fw(s3)
		var coast_lat: float = (AT.coast_z(p3.x) - p3.z) / maxf(r3.z, 0.3)
		var mid_lat: float = (BARRIER_LAT + 3.5 + coast_lat - 3.0) * 0.5
		var mid: Vector3 = p3 + r3 * mid_lat
		var q3 := Vector2(mid.x, mid.z)
		match k3 % 4:
			0:
				# A shade sail over two benches.
				if free.call(q3, 5.0) and not _in_stand(q3, 6.0):
					var a: Vector3 = mid - f3 * 4.0 * PS - r3 * 2.0 * PS + Vector3(0, 3.6 * PS, 0)
					var b: Vector3 = mid + f3 * 4.0 * PS - r3 * 1.0 * PS + Vector3(0, 4.4 * PS, 0)
					var c: Vector3 = mid + f3 * 0.5 * PS + r3 * 3.0 * PS + Vector3(0, 3.0 * PS, 0)
					pk.set_frame(Transform3D(Basis(), Vector3(0, LAND, 0)))
					MarinaKit.shade_sail(pk, kit, a - Vector3(0, LAND, 0), b - Vector3(0, LAND, 0), c - Vector3(0, LAND, 0))
					for m in [a, b, c]:
						_cyl_shape(body, Vector3(m.x, LAND + 1.5, m.z), 0.2, 3.0)
					for bsd in [-1.0, 1.0]:
						var bc: Vector3 = mid + f3 * bsd * 1.6 * PS
						# The two benches face each other under the sail.
						pk.set_frame(Transform3D(Basis.looking_at(f3 * -bsd, Vector3.UP).scaled(Vector3.ONE * PS), Vector3(bc.x, LAND, bc.z)))
						MarinaKit.bench(pk, kit, 2.0)
						_box_shape(body, Transform3D(Basis.looking_at(f3 * -bsd, Vector3.UP), Vector3(bc.x, LAND + 0.5, bc.z)), Vector3(2.2 * PS, 1.0, 0.6 * PS))
						for m2 in range(rng.randi_range(0, 2)):
							var side_off: Vector3 = Basis.looking_at(f3 * -bsd, Vector3.UP) * Vector3((float(m2) - 0.5) * 0.8 * PS, 0, 0)
							people.append([bc + side_off + Vector3(0, 0.45 * PS, 0), -f3 * bsd, true, false])
					taken.append([q3, 5.5 * PS])
			1:
				# A kiosk with café tables round it.
				if free.call(q3, 4.0) and not _in_stand(q3, 5.0):
					pk.set_frame(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * PS), Vector3(q3.x, LAND, q3.y)))
					MarinaKit.kiosk(pk, kit, rng)
					_cyl_shape(body, Vector3(q3.x, LAND + 2.0, q3.y), 2.0 * PS, 4.0)
					taken.append([q3, 3.0 * PS])
					for t in range(3):
						var a2: float = TAU * (float(t) + rng.randf()) / 3.0
						var tq: Vector2 = q3 + Vector2(cos(a2), sin(a2)) * 7.5
						if not free.call(tq, 1.6) or _in_stand(tq, 2.0):
							continue
						pk.set_frame(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * PS), Vector3(tq.x, LAND, tq.y)))
						MarinaKit.cafe_set(pk, kit, rng, cols[rng.randi() % cols.size()], 3 + rng.randi() % 2, true)
						_cyl_shape(body, Vector3(tq.x, LAND + 0.6, tq.y), 1.25 * PS, 1.2)
						taken.append([tq, 1.4 * PS])
						for m3 in range(rng.randi_range(1, 3)):
							var b2: float = rng.randf() * TAU
							var o2 := Vector3(cos(b2), 0.0, sin(b2))
							people.append([Vector3(tq.x, LAND + 0.45 * PS, tq.y) + o2 * 0.72 * PS, -o2, true, false])
			2:
				# Flower beds.
				for fo in [-6.0, 6.0]:
					var fq: Vector3 = mid + f3 * fo
					var q4 := Vector2(fq.x, fq.z)
					if free.call(q4, 1.6 * PS) and not _in_stand(q4, 2.0):
						pk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), Vector3(fq.x, LAND, fq.z)))
						MarinaKit.flower_bed(pk, kit, rng, 1.4)
						_cyl_shape(body, Vector3(fq.x, LAND + 0.3, fq.z), 1.5 * PS, 0.6)
						taken.append([q4, 1.6 * PS])
			3:
				# A balloon seller near the stand (once), else a family out walking.
				var bq2: Vector3 = mid + f3 * rng.randf_range(-4.0, 4.0)
				var q5 := Vector2(bq2.x, bq2.z)
				if free.call(q5, 1.0) and not _in_stand(q5, 1.0):
					var facing := (f3 * (1.0 if rng.randf() < 0.5 else -1.0) + r3 * rng.randf_range(-0.4, 0.4)).normalized()
					people.append([Vector3(bq2.x, LAND, bq2.z), facing, false, false])
					if absf(s3 - sf) < 80.0 and k3 % 8 == 3:
						pk.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), Vector3(bq2.x, LAND, bq2.z)))
						MarinaKit.balloon_bunch(pk, kit, rng, Vector3(0.35, 1.2, 0.0), 12)
					else:
						for kid in range(rng.randi_range(0, 2)):
							var kp: Vector3 = bq2 + Basis(Vector3.UP, rng.randf() * TAU) * Vector3(1.4, 0, 0)
							people.append([Vector3(kp.x, LAND, kp.z), facing, false, false, -1, 0.6])
						if rng.randf() < 0.7:
							var ap: Vector3 = bq2 + Basis(Vector3.UP, rng.randf() * TAU) * Vector3(1.0, 0, 0)
							people.append([Vector3(ap.x, LAND, ap.z), facing, false, false])
					taken.append([q5, 1.5])
		# Fishermen at the rail with their rods out over the sea.
		if rng.randf() < 0.45:
			var fx: float = p3.x + rng.randf_range(-6.0, 6.0)
			var fq2 := Vector2(fx, AT.coast_z(fx) - 2.6)
			if free.call(fq2, 0.8):
				people.append([Vector3(fq2.x, LAND, fq2.y), Vector3(0, 0, 1), false, false])
				var hand := Vector3(fq2.x + 0.3, LAND + 1.55, fq2.y + 0.4)
				var tip := hand + Vector3(rng.randf_range(-1.0, 1.0), 2.4, 3.6)
				pk.set_frame(Transform3D.IDENTITY)
				pk.tube(kit, "matte", hand, tip, 0.03, 0.012, 4, Color(0.12, 0.12, 0.12), false)
				pk.tube(kit, "matte", tip, Vector3(tip.x, 0.0, tip.z + 0.5), 0.004, 0.004, 3, Color(0.85, 0.85, 0.85), false)
				taken.append([fq2, 1.0])
		k3 += 1
		s3 += 22.0
	# Strings of lights between neighbouring palms on the corniche's promenade.
	var corniche_palms: Array = []
	for pa in palms_at:
		var v: Vector2 = pa
		if v.x < s_bc_x() - 70.0 and v.x > -360.0 and AT.coast_z(v.x) - v.y < 40.0 and AT.coast_z(v.x) - v.y > 2.0:
			corniche_palms.append(v)
	pk.set_frame(Transform3D.IDENTITY)
	var strings := 0
	var bulbs := [Color(1.0, 0.78, 0.42), Color(1.0, 0.55, 0.3), Color(0.95, 0.92, 0.7), Color(0.6, 0.82, 1.0)]
	for i in range(corniche_palms.size()):
		var a3: Vector2 = corniche_palms[i]
		var best := -1
		var bd := INF
		for j in range(corniche_palms.size()):
			if j == i:
				continue
			var b3: Vector2 = corniche_palms[j]
			var dist: float = a3.distance_to(b3)
			if b3.x > a3.x and dist > 7.0 and dist < 26.0 and dist < bd:
				bd = dist
				best = j
		if best < 0:
			continue
		var b4: Vector2 = corniche_palms[best]
		var pa3 := Vector3(a3.x, LAND + 5.6, a3.y)
		var pb3 := Vector3(b4.x, LAND + 5.6, b4.y)
		var cnt: int = int(bd / 0.9)
		for k in range(cnt + 1):
			var t: float = float(k) / cnt
			var bp: Vector3 = pa3.lerp(pb3, t) - Vector3(0, sin(PI * t) * 0.9, 0)
			pk.box(kit, "led", Transform3D(Basis(), bp), Vector3(0.16, 0.16, 0.16), bulbs[(k + i) % bulbs.size()])
			if k < cnt:
				var t2: float = float(k + 1) / cnt
				pk.beam(kit, "matte", bp, pa3.lerp(pb3, t2) - Vector3(0, sin(PI * t2) * 0.9, 0), 0.025, 0.025, Color(0.1, 0.1, 0.1))
		strings += 1
	var pmi := MeshInstance3D.new()
	pmi.name = "StartPromenadeDressing"
	pmi.mesh = d.save(MarinaKit.commit(pk, kit), "start_promenade")
	pmi.visibility_range_end = 650.0
	body.add_child(pmi)
	_own(body)
	# A few warm lights over the stand and the barriers.
	for k4 in range(3):
		var sl: float = sf + (float(k4) - 1.0) * 14.0
		_light(node, "StandLight_%d" % k4, _pt(sl) + _rt(sl) * (STAND_LAT + 3.0) + Vector3(0, 9.0, 0), Color(1.0, 0.85, 0.6), 2.4, 24.0)
	print("Start promenade: grandstand %d seated, %d barriers, %d light strings, %d people in all so far" % [seated, n_bar, strings, people.size()])


## x of the corniche's crossing of the creek.
func s_bc_x() -> float:
	return (_at(s_bc)["p"] as Vector2).x


## The street lamps: a mast every LAMP_EVERY along the lap, alternating sides, each with a real light (faded out with
## distance), on the ground beside the road. None in the tube, on the bridges (their lanterns), in the plaza or in the
## souk (its strings of bulbs).
func _build_lamps(root: Node3D) -> void:
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	ArabianKit.road_lamp(pk, kit, 7.0, 1)
	var mesh: ArrayMesh = d.save(MarinaKit.commit(pk, kit), "street_lamp") as ArrayMesh
	var node := Node3D.new()
	node.name = "StreetLamps"
	root.add_child(node)
	node.owner = level
	var skips := [[s_bc - ARC_HALF - 6.0, s_bc + ARC_HALF + 6.0], [s_tw - 8.0, s_te + 8.0], [s_pin - 10.0, s_pout + 10.0],
		[s_arch - BRIDGE_FLAT - BRIDGE_RAMP - 6.0, s_souk1 + 6.0]]
	var xfs: Array = []
	var s := 8.0
	var k := 0
	while s < lap_len:
		var skip := false
		for sk in skips:
			if s > float(sk[0]) and s < float(sk[1]):
				skip = true
		if skip:
			s += 4.0
			continue
		var p: Vector3 = _pt(s)
		var right: Vector3 = _rt(s)
		var sd: float = 1.0 if k % 2 == 0 else -1.0
		k += 1
		var lp: Vector3 = p + right * sd * (ROAD_HALF + 1.4)
		var g: float = d.ground(lp.x, lp.z)
		var ok: bool = absf(g - LAND) < 0.3 and d.road_dist(lp.x, lp.z, 30.0) > ROAD_HALF + 0.8 and not _near_gate(Vector2(lp.x, lp.z), -6.0)
		# None in the arcade (its own lights) or at the railway's feet.
		if absf(lp.x - AVENUE_X) < HALL_HALF + 2.0 and lp.z < ARCADE_Z0 + 4.0 and lp.z > ARCADE_Z1 - 4.0:
			ok = false
		if _near_rail_foot(lp.x, lp.z, 4.0):
			ok = false
		for pa in palms_at:
			if Vector2(lp.x, lp.z).distance_to(pa) < 3.0:
				ok = false
		if ok:
			# The arm (local +x) reaches over the road.
			var arm := -right * sd
			var b := Basis(arm, Vector3.UP, arm.cross(Vector3.UP)).scaled(Vector3.ONE * PS)
			xfs.append(Transform3D(b, Vector3(lp.x, g - 0.1, lp.z)))
			_light(node, "LampLight_%d" % xfs.size(), Vector3(lp.x, g, lp.z) + arm * 2.7 * PS + Vector3(0, 7.2 * PS, 0), Color(1.0, 0.82, 0.58), 3.2, 34.0)
		s += LAMP_EVERY
	d.scatter(node, mesh, xfs, "Lamps", 160.0, 900.0, 0.0, true, false)
	print("Street lamps: ", xfs.size())


func _build_palms(root: Node3D) -> void:
	var palms := d.palms()
	var near_mats := palms.materials(1)
	var far_mats := palms.materials(2)
	var lists := {}
	for p in palms_at:
		var v: int = d.rng.randi() % 4
		if not lists.has(v):
			lists[v] = []
		var g: float = d.ground(p.x, p.y)
		# In the plaza's planters the palm stands on the planter's soil.
		if (p as Vector2).distance_to(PLAZA_C) < PLANTER_R + 0.5 and (p as Vector2).distance_to(PLAZA_C) > PLANTER_R - 0.5:
			g = LAND + 0.6 * PS
		lists[v].append(Transform3D(Basis(Vector3.UP, d.rng.randf() * TAU).scaled(Vector3.ONE * d.rng.randf_range(1.0, 1.2)), Vector3(p.x, g - 0.2, p.y)))
	for v in lists:
		var nm: ArrayMesh = d.save(palms.mesh(v, 0, near_mats), "datepalm_%d" % v) as ArrayMesh
		var fm: ArrayMesh = d.save(palms.mesh(v, 1, far_mats), "datepalm_far_%d" % v) as ArrayMesh
		d.scatter(root, nm, lists[v], "TallNear_palm%d" % v, 120.0, D.DatePalmKit.NEAR + D.DatePalmKit.FADE, 0.0, true, false)
		d.scatter(root, fm, lists[v], "Tall_palm%d" % v, 120.0, 1500.0, D.DatePalmKit.NEAR - D.DatePalmKit.FADE)
	print("Palms: ", palms_at.size())


## The balustrade along the sea and the creek's quays (solid: boxes along it), broken where the lap's decks pass over.
func _build_railings(root: Node3D) -> void:
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var body := StaticBody3D.new()
	body.name = "QuayRailBody"
	var segs_n := 0
	var runs: Array = []
	var line: Array = []
	var x := -900.0
	while x <= 900.0:
		line.append(Vector2(x, AT.coast_z(x) - 1.6))
		x += 4.0
	runs.append(line)
	for sd in [-1.0, 1.0]:
		var l2: Array = []
		var z := 260.0
		while z > AT.MARINA_CREEK_HEAD:
			l2.append(Vector2(AT.creek_x(z) + sd * (AT.MARINA_CREEK_HALF + 1.6), z))
			z -= 4.0
		runs.append(l2)
	for run in runs:
		for i in range(run.size() - 1):
			var a: Vector2 = run[i]
			var b: Vector2 = run[i + 1]
			var m := (a + b) * 0.5
			if AT.marina_water_d(m.x, m.y) > -0.8 or d.road_dist(m.x, m.y, 30.0) < TUBE_HALF + 2.5:
				continue
			# Not across the marina's gangways or the wheel's pier.
			if absf(m.x - WHEEL_AT.x) < 11.0:
				continue
			var y: float = LAND
			var a3 := Vector3(a.x, y, a.y)
			var b3 := Vector3(b.x, y, b.y)
			pk.beam(kit, "stone", a3 + Vector3(0, 0.25, 0), b3 + Vector3(0, 0.25, 0), 0.4, 0.5, Color(0.78, 0.72, 0.62))
			pk.beam(kit, "stone", a3 + Vector3(0, 1.05, 0), b3 + Vector3(0, 1.05, 0), 0.32, 0.12, Color(0.86, 0.80, 0.70))
			for t in [0.25, 0.5, 0.75]:
				var bp: Vector3 = a3.lerp(b3, t)
				pk.box(kit, "stone", Transform3D(Basis(), bp + Vector3(0, 0.75, 0)), Vector3(0.14, 0.5, 0.14), Color(0.86, 0.80, 0.70))
			var dir := (b3 - a3).normalized()
			_box_shape(body, Transform3D(Basis(dir.cross(Vector3.UP).normalized(), Vector3.UP, dir), (a3 + b3) * 0.5 + Vector3(0, 0.6, 0)), Vector3(0.45, 1.3, a.distance_to(b) + 0.1))
			segs_n += 1
	var mi := MeshInstance3D.new()
	mi.name = "QuayRail"
	mi.mesh = d.save(MarinaKit.commit(pk, kit), "quay_rail")
	mi.visibility_range_end = 700.0
	body.add_child(mi)
	root.add_child(body)
	body.set_meta(&"surface", "rock")
	_own(body)
	print("Quay rail: ", segs_n, " pieces")


## Dhows moored along the creek's quays (the bridges kept clear), most strung with lights.
func _build_dhows(root: Node3D) -> void:
	var meshes: Array = []
	for v in range(3):
		var pk := MarinaKit.new_kit(1.0)
		var kit := {}
		var r := RandomNumberGenerator.new()
		r.seed = 300 + v
		ArabianKit.dhow(pk, kit, r, [17.0, 21.0, 14.0][v], v != 2)
		meshes.append(d.save(MarinaKit.commit(pk, kit), "dhow_%d" % v))
	var node := Node3D.new()
	node.name = "Dhows"
	root.add_child(node)
	node.owner = level
	var n := 0
	for sd in [-1.0, 1.0]:
		var z := 200.0
		while z > AT.MARINA_CREEK_HEAD + 30.0:
			var x: float = AT.creek_x(z) + sd * (AT.MARINA_CREEK_HALF - 7.0)
			if d.road_dist(x, z, 60.0) > 40.0:
				var v: int = d.rng.randi() % 3
				var t := Vector3(AT.creek_x(z - 2.0) - AT.creek_x(z + 2.0), 0, -4.0).normalized()
				var mi := MeshInstance3D.new()
				mi.name = "Dhow_%d" % n
				mi.mesh = meshes[v]
				mi.transform = Transform3D(Basis.looking_at(t * (1.0 if d.rng.randf() < 0.5 else -1.0), Vector3.UP).scaled(Vector3.ONE * PS),
						Vector3(x, -0.2, z))
				mi.visibility_range_end = 700.0
				node.add_child(mi)
				mi.owner = level
				n += 1
				z -= 34.0
			else:
				z -= 10.0
	print("Dhows: ", n)


# ======================================================================================
#  Bab al-Lulu, the Pearl Ring
# ======================================================================================

var ring_spots: Array = []
var ring_toe_s := 0.0
var ring_s := 0.0

## Where the Pearl Ring's kicker and the ring stand along the corniche (before the bake, so gates and planting keep
## clear of them), the kicker (WoodenRamp, as wide as the road, dark steel and gold) and the TrackPath's jump_lips.
func _plan_ring(path: Path3D) -> void:
	var curve := path.curve
	ring_toe_s = curve.get_closest_offset(Vector3(RING_TOE_X, LAND, AT.coast_z(RING_TOE_X) - 34.0))
	var ramp: Node3D = (load("res://WoodenRamp.tscn") as PackedScene).instantiate()
	ramp.name = "PearlKicker"
	ramp.set("length", 14.0)
	ramp.set("height", 4.0)
	ramp.set("width", 16.0)
	ramp.set("curve", 0.6)
	ramp.set("wood_color", Color(0.30, 0.30, 0.34))
	ramp.set("trim_color", Color(0.86, 0.66, 0.28))
	var toe := curve.sample_baked(ring_toe_s)
	var ahead := curve.sample_baked(ring_toe_s + 2.0) - toe
	ahead.y = 0.0
	ramp.transform = Transform3D(Basis.looking_at(ahead.normalized(), Vector3.UP), toe)
	var jumps := Node3D.new()
	jumps.name = "Jumps"
	level.add_child(jumps)
	jumps.owner = level
	jumps.add_child(ramp)
	ramp.owner = level
	path.set_meta(&"jump_lips", [ramp.lip_info()])
	ring_s = ring_toe_s + 14.0 + RING_PAST_LIP
	var rp := curve.sample_baked(ring_s)
	ring_spots = [Vector2(toe.x, toe.z), Vector2(rp.x, rp.z)]
	print("Pearl Ring: kicker at s ", ring_toe_s, ", ring at s ", ring_s)


func _build_ring(root: Node3D) -> void:
	var p: Vector3 = d.curve.sample_baked(ring_s)
	var q: Vector3 = d.curve.sample_baked(ring_s + 2.0)
	var tan_v := q - p
	tan_v.y = 0.0
	tan_v = tan_v.normalized()
	var side := Vector3.UP.cross(tan_v).normalized()
	var basis := Basis(side, Vector3.UP, tan_v)
	# Its foot 0.65m under the road's surface: the opening's bottom 3.65m over the road, 0.35m under the kicker's lip,
	# as when it was tuned (the old TerrainGenerator road stood 0.6m higher on the land).
	var origin := Vector3(p.x, LAND + ROAD_LIFT - 0.65, p.z)
	var pk := MarinaKit.new_kit(1.0)
	pk.set_frame(Transform3D(basis, origin))
	var kit := {}
	ArabianKit.pearl_ring(pk, kit, RING_RADIUS, RING_TUBE, RING_HC)
	var body := StaticBody3D.new()
	body.name = "PearlRing"
	body.set_meta(&"surface", "rock")
	root.add_child(body)
	var mi := MeshInstance3D.new()
	mi.name = "PearlRingMesh"
	mi.mesh = d.save(MarinaKit.commit(pk, kit), "pearl_ring")
	body.add_child(mi)
	# The ring's collider: a capsule along each of 32 arcs of the torus; the pylons.
	for i in range(32):
		var a0: float = TAU * i / 32.0
		var a1: float = TAU * (i + 1) / 32.0
		var c0 := Vector3(0, RING_HC, 0) + Vector3(cos(a0), sin(a0), 0) * RING_RADIUS
		var c1 := Vector3(0, RING_HC, 0) + Vector3(cos(a1), sin(a1), 0) * RING_RADIUS
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = RING_TUBE
		cap.height = c0.distance_to(c1) + RING_TUBE * 2.0
		cs.shape = cap
		var dir := (c1 - c0).normalized()
		var local := Transform3D(Basis(dir.cross(Vector3(0, 0, 1)).normalized(), dir, Vector3(0, 0, 1)).orthonormalized(), (c0 + c1) * 0.5)
		cs.transform = Transform3D(basis, origin) * local
		body.add_child(cs)
	for sx in [-1.0, 1.0]:
		_cyl_shape(body, origin + basis * Vector3(sx * (RING_RADIUS + RING_TUBE + 0.9), (RING_HC + 1.0) * 0.5, 0), 1.8, RING_HC + 1.0)
	_own(body)
	for sx in [-1.0, 1.0]:
		_light(root, "RingUplight_%d" % int(sx), origin + basis * Vector3(sx * (RING_RADIUS + RING_TUBE + 0.9), 3.0, 0), Color(1.0, 0.82, 0.5), 3.0, 26.0, 300.0)
	print("Pearl Ring built")


# ======================================================================================
#  The marina, the boats, the ferris wheel
# ======================================================================================

## The marina between the tube's legs: pontoons out from the quay with finger berths, sailing yachts and motor yachts in
## them, superyachts on the outer pontoon; two yachts cruising offshore outside the tube (SeaBoat, on the wall clock).
func _build_marina(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Marina"
	root.add_child(node)
	node.owner = level
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var meshes := {}
	for k in [["sail_blue", Color(0.12, 0.24, 0.48)], ["sail_red", Color(0.62, 0.14, 0.12)], ["sail_teal", Color(0.10, 0.42, 0.44)]]:
		var bpk := ShipKitRef.new_port_kit(1.0)
		var bkit := {}
		ShipKitRef.sailboat(bpk, bkit, k[1])
		var sail_mesh: ArrayMesh = PortKitRef.commit_port(bpk, bkit)
		# Its navigation lights glow (PortKit's lamp, CampKit's, gives off no light).
		LampGlow.fix_mesh(sail_mesh, LampGlow.material())
		meshes[k[0]] = d.save(sail_mesh, "boat_" + String(k[0]))
	# The yachts (MarinaKit.yacht, the bow toward +z): three superyachts and two motor yachts in different paint.
	for k2 in [["super0", 44.0, 0], ["super1", 44.0, 1], ["super3", 46.0, 3], ["motor2", 24.0, 2], ["motor0", 26.0, 0]]:
		var ypk := MarinaKit.new_kit(1.0)
		var ykit := {}
		var yr := RandomNumberGenerator.new()
		yr.seed = int(float(k2[1]) * 13.0) + int(k2[2])
		MarinaKit.yacht(ypk, ykit, yr, float(k2[1]), int(k2[2]))
		meshes[k2[0]] = d.save(MarinaKit.commit(ypk, ykit), "yacht_" + String(k2[0]))
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var x0 := 232.0
	var x1 := 404.0
	var off := 16.0
	var finger := 26.0
	var main: Array = []
	var x := x0
	while x <= x1:
		main.append(Vector3(x, 0.45, AT.coast_z(x) + off))
		x += 10.0
	for i in range(main.size() - 1):
		ArabianKit.pontoon(pk, kit, main[i], main[i + 1], 3.0)
	for gx in [x0 + 30.0, x1 - 30.0]:
		pk.beam(kit, "timber", Vector3(gx, LAND, AT.coast_z(gx) - 0.5), Vector3(gx, 0.5, AT.coast_z(gx) + off - 1.5), 2.0, 0.15, Color(0.5, 0.38, 0.26))
	var placed := 0
	x = x0 + 9.0
	while x <= x1 - 9.0:
		var base := Vector3(x, 0.45, AT.coast_z(x) + off + 1.5)
		ArabianKit.pontoon(pk, kit, base, base + Vector3(0, 0, finger), 1.6)
		for sd in [-1.0, 1.0]:
			if rng.randf() < 0.2:
				continue
			var kind: String = ["sail_blue", "sail_red", "sail_teal", "motor2", "sail_blue", "motor0"][rng.randi() % 6]
			var mi := MeshInstance3D.new()
			mi.name = "Yacht_%d" % placed
			mi.mesh = meshes[kind]
			var bx: float = x + sd * 4.6
			var bz: float = base.z + finger * 0.5
			var yaw := 0.0
			mi.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * (PS if kind.begins_with("sail") else 1.0)), Vector3(bx, -0.15, bz))
			mi.visibility_range_end = 900.0
			node.add_child(mi)
			mi.owner = level
			placed += 1
		x += 18.0
	var outer: Array = []
	x = x0
	while x <= x1:
		outer.append(Vector3(x, 0.45, AT.coast_z(x) + off + finger + 4.0))
		x += 10.0
	for i in range(outer.size() - 1):
		ArabianKit.pontoon(pk, kit, outer[i], outer[i + 1], 3.0)
	for k in range(3):
		var cx: float = lerpf(x0 + 36.0, x1 - 36.0, float(k) / 2.0)
		var mi2 := MeshInstance3D.new()
		mi2.name = "Superyacht_%d" % k
		mi2.mesh = meshes[["super0", "super1", "super3"][k]]
		mi2.transform = Transform3D(Basis(Vector3.UP, PI * 0.5 * (1.0 if k % 2 == 0 else -1.0)), Vector3(cx, -0.25, AT.coast_z(cx) + off + finger + 13.0))
		mi2.visibility_range_end = 2000.0
		node.add_child(mi2)
		mi2.owner = level
	var pmi := MeshInstance3D.new()
	pmi.name = "Pontoons"
	pmi.mesh = d.save(MarinaKit.commit(pk, kit), "pontoons")
	pmi.visibility_range_end = 900.0
	node.add_child(pmi)
	pmi.owner = level
	# Cruising offshore, outside the tube and clear of the land: a superyacht and a motor yacht on long loops (their
	# hulls turned bow +z for SeaBoat; the loops' straights along the node's z, here east-west).
	var sb: Script = load("res://SeaBoat.gd")
	for c in [["CruisingSuperyacht", "super1", Vector2(-150.0, 505.0), 90.0, 380.0, 70.0, 4.5, 0.0], ["CruisingMotorYacht", "motor2", Vector2(300.0, 470.0), 90.0, 200.0, 45.0, 7.0, 0.4]]:
		var r := Node3D.new()
		r.name = "Boat"
		var hull := MeshInstance3D.new()
		hull.name = "Hull"
		hull.mesh = meshes[c[1]]
		r.add_child(hull)
		hull.owner = r
		var ps := PackedScene.new()
		ps.pack(r)
		var path := "res://generated/marina_nights_boat_%s.tscn" % c[1]
		ResourceSaver.save(ps, path)
		r.free()
		var boat := Node3D.new()
		boat.set_script(sb)
		boat.name = c[0]
		var cc: Vector2 = c[2]
		boat.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(c[3]))), Vector3(cc.x, 0.0, cc.y))
		boat.set("model", load(path))
		boat.set("model_scale", 1.0)
		boat.set("draft", 0.0)
		boat.set("length", c[4])
		boat.set("turn_radius", c[5])
		boat.set("speed", c[6])
		boat.set("phase", c[7])
		boat.set("body_top", 12.0)
		boat.set("wake_width", 10.0)
		node.add_child(boat)
		boat.owner = level
	print("Marina: ", placed, " yachts in berths, 3 superyachts, 2 cruising")


## Dawwar al-Bahr, the ferris wheel, on a round island east of the marina with a footbridge to the shore: the stand and
## its pavilion, the rotor (FerrisWheel.gd turns it and keeps its cabins level), lit. Under a body with boxes for the
## stand, so DressingColliders leaves its moving meshes alone.
func _build_wheel(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "WheelIsland"
	root.add_child(node)
	node.owner = level
	var ipk := MarinaKit.new_kit(1.0)
	var ikit := {}
	var ic := Vector3(WHEEL_AT.x, 0.0, WHEEL_AT.y)
	ipk.lathe(ikit, "stone", ic, [Vector2(50.0, -12.0), Vector2(46.0, LAND - 0.3), Vector2(46.0, LAND), Vector2(0.0, LAND)], 48, Color(0.72, 0.66, 0.56))
	ipk.lathe(ikit, "led", ic, [Vector2(46.2, LAND - 0.25), Vector2(46.2, LAND - 0.1)], 48, Color(0.35, 0.75, 1.0))
	# The footbridge from the shore.
	var shore := Vector3(WHEEL_AT.x, LAND, AT.coast_z(WHEEL_AT.x) - 2.0)
	var land_end := Vector3(WHEEL_AT.x, LAND, WHEEL_AT.y - 45.0)
	ipk.beam(ikit, "marble", shore + Vector3(0, -0.2, 0), land_end + Vector3(0, -0.2, 0), 5.0, 0.6, Color(0.86, 0.84, 0.78))
	for sx in [-2.4, 2.4]:
		ipk.beam(ikit, "led", shore + Vector3(sx, 0.9, 0), land_end + Vector3(sx, 0.9, 0), 0.08, 0.08, MarinaKit.WARM)
	var z := shore.z + 8.0
	while z < land_end.z:
		ipk.tube(ikit, "marble", Vector3(WHEEL_AT.x, -6.0, z), Vector3(WHEEL_AT.x, LAND - 0.5, z), 0.8, 0.8, 10, Color(0.86, 0.84, 0.78))
		z += 12.0
	_mesh_node(node, "WheelIslandStone", MarinaKit.commit(ipk, ikit))
	# The wheel: its axle turned toward the start's straight, so the corniche sees its face.
	var face := Vector2(-150.0, 185.0) - WHEEL_AT
	var yaw: float = atan2(face.x, face.y)
	var basis := Basis(Vector3.UP, yaw)
	var body := StaticBody3D.new()
	body.name = "FerrisWheelBody"
	body.set_meta(&"surface", "rock")
	node.add_child(body)
	var wheel := Node3D.new()
	wheel.name = "FerrisWheel"
	wheel.set_script(load("res://FerrisWheel.gd"))
	wheel.transform = Transform3D(basis, Vector3(WHEEL_AT.x, LAND + WHEEL_HUB, WHEEL_AT.y))
	wheel.set("cabin_radius", WHEEL_R + 3.4)
	wheel.set("cabins", WHEEL_CABINS)
	body.add_child(wheel)
	var spk := MarinaKit.new_kit(1.0)
	var skit := {}
	MarinaKit.wheel_stand(spk, skit, WHEEL_HUB, WHEEL_R)
	var stand := MeshInstance3D.new()
	stand.name = "WheelStand"
	stand.mesh = d.save(MarinaKit.commit(spk, skit), "wheel_stand")
	stand.position = Vector3(0, -WHEEL_HUB, 0)
	stand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wheel.add_child(stand)
	var rotor := Node3D.new()
	rotor.name = "Rotor"
	wheel.add_child(rotor)
	var rpk := MarinaKit.new_kit(1.0)
	var rkit := {}
	MarinaKit.wheel_rotor(rpk, rkit, WHEEL_R, WHEEL_CABINS)
	var rmi := MeshInstance3D.new()
	rmi.name = "WheelRimGlow"
	rmi.mesh = d.save(MarinaKit.commit(rpk, rkit), "wheel_rotor")
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rotor.add_child(rmi)
	var cpk := MarinaKit.new_kit(1.0)
	var ckit := {}
	MarinaKit.cabin(cpk, ckit)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = d.save(MarinaKit.commit(cpk, ckit), "wheel_cabin")
	mm.instance_count = WHEEL_CABINS
	var xfs: Array = []
	for i in range(WHEEL_CABINS):
		var b: float = TAU * float(i) / float(WHEEL_CABINS)
		xfs.append(Transform3D(Basis(), Vector3(cos(b), sin(b), 0.0) * (WHEEL_R + 3.4)))
	mm.buffer = D.PropKit.transform_buffer(xfs)
	var cmi := MultiMeshInstance3D.new()
	cmi.name = "Cabins"
	cmi.multimesh = mm
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cmi.set_meta(&"skip_dressing_colliders", true)
	wheel.add_child(cmi)
	# The stand's feet and the platform (the legs splay along the wheel's plane, 15m either side of it).
	for side in [-1.0, 1.0]:
		for fx in [-1.0, 1.0]:
			var foot: Vector3 = Vector3(WHEEL_AT.x, LAND, WHEEL_AT.y) + basis * Vector3(fx * WHEEL_HUB * 0.42, 0.0, side * 15.0)
			_box_shape(body, Transform3D(basis, foot + Vector3(0, 1.5, 0)), Vector3(6.0, 3.0, 6.0))
	_own(body)
	_light(node, "WheelGlow", Vector3(WHEEL_AT.x, LAND + 8.0, WHEEL_AT.y), Color(0.5, 0.75, 1.0), 3.0, 40.0, 900.0)
	print("Dawwar al-Bahr: %d cabins, hub %.0fm up, facing the corniche" % [WHEEL_CABINS, WHEEL_HUB])


func _build_people(root: Node3D) -> void:
	if people.is_empty():
		return
	var crowd: Node3D = CrowdPlacer.build(root, people, PEOPLE_SCALE, PEOPLE_SKIN, 8181, func(res: Resource, n: String) -> Resource: return d.save(res, n))
	_own(crowd)
	print("People: ", people.size())


# ======================================================================================
#  Qaysariyyat al-Manara: the covered arcade over Al-Manara Avenue
# ======================================================================================

## The vault's profile across the hall (x the offset across the avenue, y up over the land): a pointed arch of two
## arcs springing from the shop fronts at SPRING, each arc's centre VAULT_R from its foot; from the west foot over the
## crown to the east one.
func _vault_profile(n_half: int) -> Array:
	var cx: float = VAULT_R - HALL_HALF
	var top: float = acos(cx / VAULT_R)
	var pts: Array = []
	for i in range(n_half + 1):
		var a: float = top * float(i) / float(n_half)
		pts.append(Vector2(cx - VAULT_R * cos(a), SPRING + VAULT_R * sin(a)))
	for i in range(n_half - 1, -1, -1):
		var a2: float = top * float(i) / float(n_half)
		pts.append(Vector2(-(cx - VAULT_R * cos(a2)), SPRING + VAULT_R * sin(a2)))
	return pts


## The arcade (the user's "modern souk" over the road after the marina walk): a hall HALL_HALF either side of the
## avenue's line from ARCADE_Z0 to ARCADE_Z1, bay by bay: two storeys of shops either side (lit interiors behind
## pointed arches, canopies, the gallery's lattice balustrade, arched windows above, a cornice with a line of light),
## and over it a pointed vault of mashrabiya lattice ("lattice", backlit gold) between carved ribs with lines of light
## along them, lanterns hanging from the crown; a portal at each end between two lantern towers, the name over it;
## the lattice's light thrown on the road and the walkways (arcade_floor_light.gdshader). Café tables and planters on
## the walkways, shoppers below and on the galleries. The shop fronts are solid (one box a side, its pilasters'
## faces), so are the portals, the towers and the furniture.
func _build_arcade(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Arcade"
	root.add_child(node)
	node.owner = level
	var body := StaticBody3D.new()
	body.name = "ArcadeWalls"
	body.set_meta(&"surface", "rock")
	node.add_child(body)
	body.owner = level
	var prof: Array = _vault_profile(12)
	var nb: int = int(round((ARCADE_Z0 - ARCADE_Z1) / BAY))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var awn_cols := [Color(0.72, 0.12, 0.16), Color(0.06, 0.45, 0.48), Color(0.90, 0.66, 0.16), Color(0.42, 0.18, 0.46), Color(0.12, 0.30, 0.62)]
	for g0 in range(0, nb, 2):
		var pk := MarinaKit.new_kit(1.0)
		var kit := {}
		for b in range(g0, mini(g0 + 2, nb)):
			var za: float = ARCADE_Z0 - float(b) * BAY
			var zb: float = za - BAY
			_arcade_rib(pk, kit, prof, za)
			if b == nb - 1:
				_arcade_rib(pk, kit, prof, zb)
			_arcade_vault(pk, kit, prof, za - 0.48, zb + 0.48)
			for sd in [-1.0, 1.0]:
				_arcade_front(pk, kit, rng, sd, za, zb, awn_cols)
				_arcade_walk(pk, kit, sd, za, zb)
			# A lantern hung from the crown.
			var crown: float = (prof[12] as Vector2).y
			var lc := Vector3(AVENUE_X, LAND + crown - 7.5, (za + zb) * 0.5)
			pk.box(kit, "metal", Transform3D(Basis(), lc + Vector3(0, 3.6, 0)), Vector3(0.08, 7.2, 0.08), MarinaKit.GOLD)
			pk.lathe(kit, "metal", lc, [Vector2(0.0, 1.5), Vector2(0.5, 1.2), Vector2(0.75, 0.75)], 8, MarinaKit.GOLD, true)
			pk.lathe(kit, "led", lc, [Vector2(0.75, 0.75), Vector2(0.95, 0.0), Vector2(0.62, -1.1)], 8, MarinaKit.WARM, true)
			pk.lathe(kit, "metal", lc, [Vector2(0.62, -1.1), Vector2(0.3, -1.4), Vector2(0.0, -1.9)], 8, MarinaKit.GOLD, true)
		_mesh_node(node, "ArcadeBays_%d" % g0, MarinaKit.commit(pk, kit), 900.0, true)
	for e in [[ARCADE_Z0, 1.0], [ARCADE_Z1, -1.0]]:
		var pk2 := MarinaKit.new_kit(1.0)
		var kit2 := {}
		_arcade_portal(pk2, kit2, prof, float(e[0]), float(e[1]), node, body)
		_mesh_node(node, "ArcadePortal_%d" % (0 if float(e[1]) > 0.0 else 1), MarinaKit.commit(pk2, kit2), 1400.0, true)
	# The shop fronts' collision: a box a side, from the pilasters' faces back.
	for sd in [-1.0, 1.0]:
		_box_shape(body, Transform3D(Basis(), Vector3(AVENUE_X + sd * (HALL_HALF + 0.05), LAND + SPRING * 0.5, (ARCADE_Z0 + ARCADE_Z1) * 0.5)),
				Vector3(1.9, SPRING, ARCADE_Z0 - ARCADE_Z1))
	# The light thrown on the floor, in 10m pieces (each fades toward the ends).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := ARCADE_Z1 + 1.0
	while z < ARCADE_Z0 - 1.0:
		var z2: float = minf(z + 10.0, ARCADE_Z0 - 1.0)
		var f0: float = clampf(minf(z - ARCADE_Z1, ARCADE_Z0 - z) / 25.0, 0.0, 1.0)
		var f1: float = clampf(minf(z2 - ARCADE_Z1, ARCADE_Z0 - z2) / 25.0, 0.0, 1.0)
		var xa: float = AVENUE_X - HALL_HALF + 0.9
		var xb: float = AVENUE_X + HALL_HALF - 0.9
		var y: float = LAND + 0.14
		var q := [[Vector3(xa, y, z), f0], [Vector3(xb, y, z), f0], [Vector3(xb, y, z2), f1], [Vector3(xa, y, z2), f1]]
		# Facing up: clockwise seen from above.
		for k in [0, 2, 1, 0, 3, 2]:
			var v: Vector3 = q[k][0]
			st.set_color(Color(1, 1, 1, float(q[k][1])))
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)
		z = z2
	var fm := ShaderMaterial.new()
	fm.shader = load("res://arcade_floor_light.gdshader")
	var fl_mesh := st.commit()
	fl_mesh.surface_set_material(0, d.save(fm, "arcade_floor_light_mat"))
	var fl := _mesh_node(node, "ArcadeFloorLight", fl_mesh, 400.0, false)
	fl.extra_cull_margin = 2.0
	# The hall's lights: down its length, alternating sides, under the galleries' cornices.
	var k := 0
	z = ARCADE_Z0 - 10.0
	while z > ARCADE_Z1 + 5.0:
		var sd2: float = 1.0 if k % 2 == 0 else -1.0
		_light(node, "ArcadeLight_%d" % k, Vector3(AVENUE_X + sd2 * 11.0, LAND + 10.5, z), Color(1.0, 0.74, 0.46), 2.6, 27.0, 260.0)
		k += 1
		z -= 20.0
	# The market's murmur under the vault (tools/elevenlabs; -36.7 dBFS RMS, about -30 inside the hall), from four
	# players along it at slightly different speeds so they never fall into step.
	var amb: AudioStream = load("res://sounds/arcade/souk_arcade_loop.wav")
	for ai in range(4):
		var ap := AudioStreamPlayer3D.new()
		ap.name = "ArcadeAmbience_%d" % ai
		ap.stream = amb
		ap.autoplay = true
		ap.unit_size = 26.0
		ap.max_distance = 150.0
		ap.volume_db = 3.5
		ap.pitch_scale = [0.97, 1.0, 1.03, 0.985][ai]
		ap.bus = &"SFX"
		ap.position = Vector3(AVENUE_X, LAND + 6.0, lerpf(ARCADE_Z0 - 38.0, ARCADE_Z1 + 38.0, float(ai) / 3.0))
		node.add_child(ap)
		ap.owner = level
	# The walkways' furniture: café tables and planters by turns, none by the avenue's gate; people.
	var gate_z: float = -20.0
	var fi := 0
	z = ARCADE_Z0 - 7.5
	while z > ARCADE_Z1 + 7.0:
		for sd3 in [-1.0, 1.0]:
			if absf(z - gate_z) < 14.0:
				continue
			var c := Vector3(AVENUE_X + sd3 * 12.3, LAND + 0.11, z + (2.5 if sd3 > 0.0 else -2.5))
			var pk3 := MarinaKit.new_kit(PS)
			var kit3 := {}
			if fi % 3 != 2:
				pk3.set_frame(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * PS), c))
				MarinaKit.cafe_set(pk3, kit3, rng, awn_cols[fi % awn_cols.size()], 4, false)
				_cyl_shape(body, c + Vector3(0, 0.6, 0), 0.75 * PS, 1.2)
				for ch in range(4):
					var a: float = TAU * float(ch) / 4.0 + 0.4
					if rng.randf() < 0.6:
						var o := Vector3(cos(a), 0, sin(a))
						people.append([c + o * 0.72 * PS + Vector3(0, 0.45 * PS, 0), -o, true, false])
			else:
				pk3.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), c))
				MarinaKit.planter(pk3, kit3, 0.9, 0.55)
				pk3.set_frame(Transform3D(Basis().scaled(Vector3.ONE * PS), c + Vector3(0, 0.55 * PS, 0)))
				MarinaKit.flower_bed(pk3, kit3, rng, 0.7)
				_cyl_shape(body, c + Vector3(0, 0.5, 0), 0.95 * PS, 1.0)
			_mesh_node(node, "ArcadeFurniture_%d" % fi, MarinaKit.commit(pk3, kit3), 260.0, false)
			fi += 1
		z -= BAY * 2.0
	# Shoppers along the walkways and up on the galleries.
	for i in range(90):
		var sd4: float = -1.0 if rng.randf() < 0.5 else 1.0
		var zz: float = rng.randf_range(ARCADE_Z1 + 6.0, ARCADE_Z0 - 6.0)
		if absf(zz - gate_z) < 9.0:
			continue
		if i < 66:
			var u: float = rng.randf_range(ROAD_HALF + 1.6, HALL_HALF - 1.4)
			var face := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
			people.append([Vector3(AVENUE_X + sd4 * u, LAND + 0.11, zz), face, false, false])
		else:
			people.append([Vector3(AVENUE_X + sd4 * (HALL_HALF - 1.4), LAND + 7.75, zz), Vector3(-sd4, 0, rng.randf_range(-0.4, 0.4)).normalized(), false, false])
	print("Arcade: %d bays, %d furniture" % [nb, fi])


## A rib across the hall at z: carved stone along the vault's profile with a line of light along its underside, on
## pilasters up the shop fronts with gold capitals.
func _arcade_rib(pk: PropKit, kit: Dictionary, prof: Array, z: float) -> void:
	var stone := Color(0.84, 0.70, 0.50)
	for i in range(prof.size() - 1):
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		var mid: Vector2 = (a + b) * 0.5
		var dir2: Vector2 = (b - a).normalized()
		var n2 := Vector2(dir2.y, -dir2.x)
		if n2.dot(mid - Vector2(0.0, SPRING)) < 0.0:
			n2 = -n2
		var bx := Basis(Vector3(dir2.x, dir2.y, 0.0), Vector3(n2.x, n2.y, 0.0), Vector3(0, 0, 1))
		pk.box(kit, "marble", Transform3D(bx, Vector3(AVENUE_X + mid.x + n2.x * 0.2, LAND + mid.y + n2.y * 0.2, z)), Vector3(a.distance_to(b) + 0.1, 1.3, 0.95), stone)
		pk.box(kit, "led", Transform3D(bx, Vector3(AVENUE_X + mid.x - n2.x * 0.47, LAND + mid.y - n2.y * 0.47, z)), Vector3(a.distance_to(b) + 0.02, 0.06, 0.26), MarinaKit.WARM)
	for sd in [-1.0, 1.0]:
		pk.box(kit, "marble", Transform3D(Basis(), Vector3(AVENUE_X + sd * (HALL_HALF - 0.2), LAND + SPRING * 0.5, z)), Vector3(1.4, SPRING, 1.3), stone)
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(AVENUE_X + sd * (HALL_HALF - 0.35), LAND + SPRING - 0.4, z)), Vector3(1.9, 0.5, 1.7), MarinaKit.GOLD)
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(AVENUE_X + sd * (HALL_HALF - 0.35), LAND + 0.25, z)), Vector3(1.9, 0.5, 1.7), Color(0.55, 0.45, 0.33))


## The lattice vault between two ribs (za > zb): its panels along the profile, UV in metres (along the profile, along
## the hall).
func _arcade_vault(pk: PropKit, kit: Dictionary, prof: Array, za: float, zb: float) -> void:
	var s := 0.0
	for i in range(prof.size() - 1):
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		var l: float = a.distance_to(b)
		var dir2: Vector2 = (b - a) / l
		var n2 := Vector2(dir2.y, -dir2.x)
		if n2.dot((a + b) * 0.5 - Vector2(0.0, SPRING)) > 0.0:
			n2 = -n2
		var p := [Vector3(AVENUE_X + a.x, LAND + a.y, za), Vector3(AVENUE_X + b.x, LAND + b.y, za), Vector3(AVENUE_X + b.x, LAND + b.y, zb),
				Vector3(AVENUE_X + a.x, LAND + a.y, zb)]
		pk.quad(kit, "lattice", p, Vector3(n2.x, n2.y, 0.0), Color(1, 1, 1), [Vector2(s, za), Vector2(s + l, za), Vector2(s + l, zb), Vector2(s, zb)])
		s += l


## A pointed arch's outline in a wall: from (z0, y0) up to the point (zc, y_tip) and down to (z1, y0).
func _pointed(z0: float, z1: float, y0: float, y_tip: float, n: int) -> Array:
	var zc: float = (z0 + z1) * 0.5
	var pts: Array = []
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		pts.append(Vector2(lerpf(z0, zc, t), y0 + (y_tip - y0) * (1.0 - (1.0 - t) * (1.0 - t))))
	for i in range(n - 1, -1, -1):
		var t2: float = float(i) / float(n)
		pts.append(Vector2(lerpf(z1, zc, t2), y0 + (y_tip - y0) * (1.0 - (1.0 - t2) * (1.0 - t2))))
	return pts


## One side (sd) of the hall through one bay (za > zb).
func _arcade_front(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, sd: float, za: float, zb: float, awn_cols: Array) -> void:
	var stone := Color(0.88, 0.78, 0.62)
	var x0: float = AVENUE_X + sd * HALL_HALF
	var n := Vector3(-sd, 0.0, 0.0)
	var zc: float = (za + zb) * 0.5
	var ow := 3.3
	var y_open := 5.0
	var y_tip := 6.9
	var y_gal := 7.6
	var y_top: float = SPRING - 0.6
	var wall := func(z0: float, z1: float, y0: float, y1: float, key: String, col: Color, off := 0.0) -> void:
		var xx: float = x0 - sd * off
		pk.quad(kit, key, [Vector3(xx, LAND + y0, z0), Vector3(xx, LAND + y0, z1), Vector3(xx, LAND + y1, z1), Vector3(xx, LAND + y1, z0)], n, col)
	# Ground floor: the piers either side of the shop's opening, and the spandrel over its pointed arch.
	wall.call(zb, zc - ow, 0.0, y_gal, "marble", stone)
	wall.call(zc + ow, za, 0.0, y_gal, "marble", stone)
	var arch: Array = _pointed(zc - ow, zc + ow, y_open, y_tip, 6)
	for i in range(arch.size() - 1):
		var a: Vector2 = arch[i]
		var b: Vector2 = arch[i + 1]
		pk.quad(kit, "marble", [Vector3(x0, LAND + a.y, a.x), Vector3(x0, LAND + b.y, b.x), Vector3(x0, LAND + y_gal, b.x), Vector3(x0, LAND + y_gal, a.x)], n, stone)
		# A gold line round the arch.
		pk.beam(kit, "metal", Vector3(x0 - sd * 0.05, LAND + a.y + 0.12, a.x), Vector3(x0 - sd * 0.05, LAND + b.y + 0.12, b.x), 0.08, 0.16, MarinaKit.GOLD, n)
	# The shop: a lit room behind the opening (the back wall glowing, the side walls stone, a dark ceiling), its goods.
	var back: float = x0 + sd * SHOP_DEPTH
	var room_n := Vector3(-sd, 0, 0)
	pk.quad(kit, "glasslit", [Vector3(back, LAND, zc - ow), Vector3(back, LAND, zc + ow), Vector3(back, LAND + y_tip, zc + ow), Vector3(back, LAND + y_tip, zc - ow)],
			room_n, Color(1.0, 0.72, 0.42).darkened(rng.randf_range(0.0, 0.3)))
	for sz in [-1.0, 1.0]:
		var zz: float = zc + sz * ow
		pk.quad(kit, "marble", [Vector3(x0, LAND, zz), Vector3(back, LAND, zz), Vector3(back, LAND + y_tip, zz), Vector3(x0, LAND + y_tip, zz)], Vector3(0, 0, -sz), stone.darkened(0.25))
	pk.quad(kit, "matte", [Vector3(x0, LAND + y_tip, zc - ow), Vector3(back, LAND + y_tip, zc - ow), Vector3(back, LAND + y_tip, zc + ow), Vector3(x0, LAND + y_tip, zc + ow)],
			Vector3.DOWN, Color(0.22, 0.14, 0.09))
	# A lit panel in its ceiling: the shop reads lit from the hall.
	pk.quad(kit, "glasslit", [Vector3(x0 + sd * 1.2, LAND + y_tip - 0.03, zc - ow + 0.8), Vector3(back - sd * 1.0, LAND + y_tip - 0.03, zc - ow + 0.8),
			Vector3(back - sd * 1.0, LAND + y_tip - 0.03, zc + ow - 0.8), Vector3(x0 + sd * 1.2, LAND + y_tip - 0.03, zc + ow - 0.8)], Vector3.DOWN, Color(1.0, 0.86, 0.62))
	pk.quad(kit, "tile", [Vector3(x0, LAND + 0.06, zc - ow), Vector3(back, LAND + 0.06, zc - ow), Vector3(back, LAND + 0.06, zc + ow), Vector3(x0, LAND + 0.06, zc + ow)],
			Vector3.UP, Color(0.55, 0.22, 0.14))
	var kind: int = rng.randi() % 4
	for gi in range(5):
		var gz: float = zc - ow + 0.6 + float(gi) * (ow * 2.0 - 1.2) / 4.0
		var gx: float = back - sd * 0.6
		match kind:
			0:
				# Carpets hung on the back wall.
				pk.box(kit, "tile", Transform3D(Basis(), Vector3(gx + sd * 0.4, LAND + 3.0, gz)), Vector3(0.06, 3.6, 0.7),
						Color.from_hsv(rng.randf_range(0.0, 0.08) if rng.randf() < 0.7 else 0.6, 0.7, 0.55))
			1:
				# Lamps: glowing glass in every colour.
				for ly in [2.2, 3.4, 4.6]:
					pk.box(kit, "led", Transform3D(Basis(), Vector3(gx, LAND + ly + rng.randf_range(-0.2, 0.2), gz)), Vector3(0.5, 0.6, 0.5),
							Color.from_hsv(rng.randf(), 0.75, 0.9))
			2:
				# Spices and sweets heaped on a counter.
				pk.box(kit, "timber", Transform3D(Basis(), Vector3(x0 + sd * 2.0, LAND + 0.55, gz)), Vector3(1.2, 1.1, 1.3), Color(0.4, 0.26, 0.15))
				pk.lathe(kit, "matte", Vector3(x0 + sd * 2.0, LAND + 1.1, gz), [Vector2(0.45, 0.0), Vector2(0.3, 0.3), Vector2(0.0, 0.42)], 8,
						Color.from_hsv(rng.randf_range(0.0, 0.14), 0.85, 0.75))
			_:
				# Gold in glass cases.
				pk.box(kit, "timber", Transform3D(Basis(), Vector3(x0 + sd * 2.4, LAND + 0.5, gz)), Vector3(1.0, 1.0, 1.3), Color(0.25, 0.15, 0.1))
				pk.box(kit, "led", Transform3D(Basis(), Vector3(x0 + sd * 2.4, LAND + 1.05, gz)), Vector3(0.8, 0.12, 1.1), Color(0.9, 0.7, 0.3))
	# A canopy over two openings in five.
	if rng.randf() < 0.4:
		var col: Color = awn_cols[rng.randi() % awn_cols.size()]
		var ax: float = x0 - sd * 2.6
		pk.quad(kit, "awning", [Vector3(x0 - sd * 0.1, LAND + 6.4, zc - ow - 0.4), Vector3(x0 - sd * 0.1, LAND + 6.4, zc + ow + 0.4), Vector3(ax, LAND + 5.5, zc + ow + 0.4),
				Vector3(ax, LAND + 5.5, zc - ow - 0.4)], Vector3(-sd * 0.3, 1.0, 0.0).normalized(), col)
		pk.quad(kit, "awning", [Vector3(ax, LAND + 5.5, zc - ow - 0.4), Vector3(ax, LAND + 5.5, zc + ow + 0.4), Vector3(ax, LAND + 5.1, zc + ow + 0.4),
				Vector3(ax, LAND + 5.1, zc - ow - 0.4)], n, col.darkened(0.15))
	# The gallery: its floor out over the walkway, the lattice balustrade, a gold rail on it.
	var bx: float = x0 - sd * 2.3
	pk.box(kit, "marble", Transform3D(Basis(), Vector3((x0 + bx) * 0.5, LAND + y_gal - 0.2, zc)), Vector3(2.4, 0.4, BAY + 0.02), stone)
	pk.box(kit, "led", Transform3D(Basis(), Vector3(bx + sd * 0.05, LAND + y_gal - 0.42, zc)), Vector3(0.1, 0.05, BAY - 0.2), MarinaKit.WARM)
	pk.quad(kit, "lattice", [Vector3(bx, LAND + y_gal, zb), Vector3(bx, LAND + y_gal, za), Vector3(bx, LAND + y_gal + 1.5, za), Vector3(bx, LAND + y_gal + 1.5, zb)], n,
			Color(1, 1, 1), [Vector2(zb, y_gal), Vector2(za, y_gal), Vector2(za, y_gal + 1.5), Vector2(zb, y_gal + 1.5)])
	pk.box(kit, "metal", Transform3D(Basis(), Vector3(bx, LAND + y_gal + 1.58, zc)), Vector3(0.14, 0.12, BAY), MarinaKit.GOLD)
	# The upper floor: the wall, an arched door onto the gallery (lit), the cornice and its line of light.
	wall.call(zb, za, y_gal, y_top, "marble", stone)
	var door: Array = _pointed(zc - 1.4, zc + 1.4, y_gal + 3.2, y_gal + 4.4, 4)
	var dpts: Array = [Vector2(zc - 1.4, y_gal + 0.15), Vector2(zc + 1.4, y_gal + 0.15)]
	var poly := PackedVector2Array()
	poly.append(Vector2(zc + 1.4, y_gal + 0.15))
	poly.append(Vector2(zc - 1.4, y_gal + 0.15))
	for q in door:
		poly.append(q)
	var tris := Geometry2D.triangulate_polygon(poly)
	for t in range(0, tris.size(), 3):
		var a3: Vector2 = poly[tris[t]]
		var b3: Vector2 = poly[tris[t + 1]]
		var c3: Vector2 = poly[tris[t + 2]]
		pk.tri(kit, "glasslit", Vector3(x0 - sd * 0.03, LAND + a3.y, a3.x), Vector3(x0 - sd * 0.03, LAND + b3.y, b3.x), Vector3(x0 - sd * 0.03, LAND + c3.y, c3.x),
				n, n, n, Color(1.0, 0.78, 0.5), n)
	dpts.clear()
	pk.box(kit, "marble", Transform3D(Basis(), Vector3(x0 - sd * 0.3, LAND + y_top + 0.3, zc)), Vector3(0.9, 0.6, BAY + 0.02), stone.lightened(0.05))
	pk.box(kit, "led", Transform3D(Basis(), Vector3(x0 - sd * 0.62, LAND + y_top - 0.05, zc)), Vector3(0.08, 0.06, BAY - 0.1), MarinaKit.WARM)


## The walkway's floor through one bay on one side: patterned tiles from the kerb to the shop fronts, the kerb along
## the road's edge.
func _arcade_walk(pk: PropKit, kit: Dictionary, sd: float, za: float, zb: float) -> void:
	var u0: float = ROAD_HALF + 0.3
	var u1: float = HALL_HALF - 0.85
	var y: float = LAND + 0.11
	pk.box(kit, "marble", Transform3D(Basis(), Vector3(AVENUE_X + sd * (ROAD_HALF + 0.15), LAND + 0.06, (za + zb) * 0.5)), Vector3(0.3, 0.14, za - zb), Color(0.75, 0.70, 0.62))
	var cells := 4
	var cz: float = (za - zb) / float(cells)
	var cu: float = (u1 - u0) / 3.0
	for i in range(cells):
		for j in range(3):
			var z0: float = zb + float(i) * cz
			var ua: float = u0 + float(j) * cu
			var col: Color = Color(0.86, 0.80, 0.70) if (i + j) % 2 == 0 else Color(0.70, 0.60, 0.48)
			var inset := 0.08
			var pts := [Vector3(AVENUE_X + sd * (ua + inset), y, z0 + inset), Vector3(AVENUE_X + sd * (ua + cu - inset), y, z0 + inset),
					Vector3(AVENUE_X + sd * (ua + cu - inset), y, z0 + cz - inset), Vector3(AVENUE_X + sd * (ua + inset), y, z0 + cz - inset)]
			pk.quad(kit, "tile", pts, Vector3.UP, col)
	pk.quad(kit, "tile", [Vector3(AVENUE_X + sd * u0, y - 0.01, zb), Vector3(AVENUE_X + sd * u1, y - 0.01, zb), Vector3(AVENUE_X + sd * u1, y - 0.01, za),
			Vector3(AVENUE_X + sd * u0, y - 0.01, za)], Vector3.UP, Color(0.36, 0.30, 0.25))


## A portal at the hall's end z, facing `out` (+1: toward +z): a tall stone frame round the vault's pointed opening,
## gold lines round it and a lattice band over it with the name, between two lantern towers. Solid.
func _arcade_portal(pk: PropKit, kit: Dictionary, prof: Array, z: float, out: float, node: Node3D, body: StaticBody3D) -> void:
	var stone := Color(0.88, 0.78, 0.60)
	var top := 41.0
	var half_w := 22.0
	var th := 2.6
	var zf: float = z + out * th
	var nf := Vector3(0, 0, out)
	# The blocks either side of the opening and the top over the arch, both faces; the arch's soffit through it.
	for sd in [-1.0, 1.0]:
		var cx: float = AVENUE_X + sd * (HALL_HALF + half_w) * 0.5
		pk.box(kit, "marble", Transform3D(Basis(), Vector3(cx, LAND + top * 0.5, z + out * th * 0.5)), Vector3(half_w - HALL_HALF, top, th), stone)
		_box_shape(body, Transform3D(Basis(), Vector3(cx, LAND + top * 0.5, z + out * th * 0.5)), Vector3(half_w - HALL_HALF, top, th))
	for i in range(prof.size() - 1):
		var a: Vector2 = prof[i]
		var b: Vector2 = prof[i + 1]
		for zz in [z, zf]:
			var nn: Vector3 = nf if zz == zf else -nf
			pk.quad(kit, "marble", [Vector3(AVENUE_X + a.x, LAND + a.y, zz), Vector3(AVENUE_X + b.x, LAND + b.y, zz), Vector3(AVENUE_X + b.x, LAND + top, zz),
					Vector3(AVENUE_X + a.x, LAND + top, zz)], nn, stone)
		var dir2: Vector2 = (b - a).normalized()
		var n2 := Vector2(dir2.y, -dir2.x)
		if n2.dot((a + b) * 0.5 - Vector2(0.0, SPRING)) > 0.0:
			n2 = -n2
		pk.quad(kit, "marble", [Vector3(AVENUE_X + a.x, LAND + a.y, z), Vector3(AVENUE_X + b.x, LAND + b.y, z), Vector3(AVENUE_X + b.x, LAND + b.y, zf),
				Vector3(AVENUE_X + a.x, LAND + a.y, zf)], Vector3(n2.x, n2.y, 0.0), stone.darkened(0.15))
		# A gold line round the arch on the outer face.
		var off := Vector2(-n2.x, -n2.y) * 0.5
		pk.beam(kit, "metal", Vector3(AVENUE_X + a.x + off.x, LAND + a.y + off.y, zf + out * 0.06), Vector3(AVENUE_X + b.x + off.x, LAND + b.y + off.y, zf + out * 0.06),
				0.35, 0.12, MarinaKit.GOLD, nf)
	pk.box(kit, "marble", Transform3D(Basis(), Vector3(AVENUE_X, LAND + top + 0.4, z + out * th * 0.5)), Vector3(half_w * 2.0 + 0.6, 0.8, th + 0.6), stone.lightened(0.05))
	# The frame's gold lines and the lattice band with the name.
	for sd in [-1.0, 1.0]:
		pk.beam(kit, "metal", Vector3(AVENUE_X + sd * (half_w - 0.9), LAND + 0.5, zf + out * 0.06), Vector3(AVENUE_X + sd * (half_w - 0.9), LAND + top - 0.9, zf + out * 0.06),
				0.35, 0.12, MarinaKit.GOLD, nf)
	pk.beam(kit, "metal", Vector3(AVENUE_X - half_w + 0.9, LAND + top - 0.9, zf + out * 0.06), Vector3(AVENUE_X + half_w - 0.9, LAND + top - 0.9, zf + out * 0.06),
			0.35, 0.12, MarinaKit.GOLD, Vector3.UP)
	var crown: float = (prof[12] as Vector2).y
	var by0: float = crown + 1.2
	pk.quad(kit, "lattice", [Vector3(AVENUE_X - 15.0, LAND + by0, zf + out * 0.05), Vector3(AVENUE_X + 15.0, LAND + by0, zf + out * 0.05),
			Vector3(AVENUE_X + 15.0, LAND + top - 1.6, zf + out * 0.05), Vector3(AVENUE_X - 15.0, LAND + top - 1.6, zf + out * 0.05)], nf, Color(1, 1, 1),
			[Vector2(-15.0, by0), Vector2(15.0, by0), Vector2(15.0, top - 1.6), Vector2(-15.0, top - 1.6)])
	var lbl := Label3D.new()
	lbl.name = "ArcadeName_%d" % (0 if out > 0.0 else 1)
	lbl.text = "QAYSARIYYAT AL-MANARA"
	lbl.font_size = 64
	lbl.pixel_size = 0.03
	lbl.outline_size = 0
	lbl.modulate = Color(1.5, 1.15, 0.6)
	lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	lbl.double_sided = false
	lbl.position = Vector3(AVENUE_X, LAND + (by0 + top - 1.6) * 0.5, zf + out * 0.15)
	lbl.rotation = Vector3(0.0, 0.0 if out > 0.0 else PI, 0.0)
	node.add_child(lbl)
	lbl.owner = level
	# The lantern towers either side.
	for sd in [-1.0, 1.0]:
		var tx: float = AVENUE_X + sd * (half_w + 2.8)
		var tz: float = z + out * th * 0.5
		pk.box(kit, "marble", Transform3D(Basis(), Vector3(tx, LAND + 23.0, tz)), Vector3(5.0, 46.0, 5.0), stone)
		_box_shape(body, Transform3D(Basis(), Vector3(tx, LAND + 23.0, tz)), Vector3(5.0, 46.0, 5.0))
		for f in [[Vector3(sd, 0, 0), 2.52], [Vector3(0, 0, out), 2.52]]:
			var fn: Vector3 = f[0]
			var fc: Vector3 = Vector3(tx, LAND, tz) + fn * float(f[1])
			var across: Vector3 = Vector3.UP.cross(fn).normalized()
			pk.quad(kit, "lattice", [fc + across * -1.6 + Vector3(0, 22.0, 0), fc + across * 1.6 + Vector3(0, 22.0, 0), fc + across * 1.6 + Vector3(0, 38.0, 0),
					fc + across * -1.6 + Vector3(0, 38.0, 0)], fn, Color(1, 1, 1), [Vector2(-1.6, 22.0), Vector2(1.6, 22.0), Vector2(1.6, 38.0), Vector2(-1.6, 38.0)])
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(tx, LAND + 46.3, tz)), Vector3(6.0, 0.6, 6.0), MarinaKit.GOLD)
		pk.lathe(kit, "led", Vector3(tx, LAND + 46.6, tz), [Vector2(2.6, 0.0), Vector2(2.9, 1.6), Vector2(2.2, 3.4), Vector2(1.0, 4.8), Vector2(0.0, 5.6)], 8,
				Color(0.35, 0.24, 0.08), true)
		pk.tube(kit, "metal", Vector3(tx, LAND + 52.0, tz), Vector3(tx, LAND + 56.0, tz), 0.25, 0.05, 6, MarinaKit.GOLD)
		_light(node, "ArcadePortalLight_%d_%d" % [0 if out > 0.0 else 1, 0 if sd < 0.0 else 1], Vector3(tx - sd * 4.0, LAND + 3.0, zf + out * 6.0),
				Color(1.0, 0.8, 0.55), 4.0, 40.0, 500.0)


# ======================================================================================
#  Al-Mu'allaq: the suspended railway down the palm avenue and over the sea to the island
# ======================================================================================

## Whether a frame at z stands in the sea (a pier) or on land (a portal over the street, the promenade or the island).
func _frame_in_sea(z: float) -> bool:
	return z > 225.0 and z < STATION_ISLAND.x - 1.0


## The frames' legs (world xz): two a frame.
func _rail_legs() -> Array:
	var out: Array = []
	for z in FRAME_Z:
		var u: float = SEA_LEG_U if _frame_in_sea(float(z)) else LEG_U
		for sd in [-1.0, 1.0]:
			out.append(Vector2(LINE_X + sd * u, float(z)))
	return out


## A box truss from a to b: chords at the corners of its section (`h` along `up`, `w` along `side`, from the a-b line at
## its bottom middle), verticals and diagonals on both sides every `step`, ties across top and bottom.
func _truss(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, up: Vector3, side: Vector3, h: float, w: float, step: float, chord: float, web: float, col: Color) -> void:
	var L: float = a.distance_to(b)
	var dir: Vector3 = (b - a) / L
	var n: int = maxi(int(round(L / step)), 1)
	var hw: float = w * 0.5
	for c in [[-hw, 0.0], [hw, 0.0], [-hw, h], [hw, h]]:
		var o: Vector3 = side * float(c[0]) + up * float(c[1])
		pk.beam(kit, "paintsteel", a + o, b + o, chord, chord, col, up)
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		var p: Vector3 = a.lerp(b, t)
		for sd in [-hw, hw]:
			pk.beam(kit, "paintsteel", p + side * sd, p + side * sd + up * h, web, web, col, dir)
		pk.beam(kit, "paintsteel", p - side * hw, p + side * hw, web, web, col, up)
		pk.beam(kit, "paintsteel", p - side * hw + up * h, p + side * hw + up * h, web, web, col, up)
		if i < n:
			var q: Vector3 = a.lerp(b, float(i + 1) / float(n))
			for sd2 in [-hw, hw]:
				if i % 2 == 0:
					pk.beam(kit, "paintsteel", p + side * sd2, q + side * sd2 + up * h, web, web, col, side)
				else:
					pk.beam(kit, "paintsteel", p + side * sd2 + up * h, q + side * sd2, web, web, col, side)


## The line: on each track a box-truss girder with the rail hung under it on brackets (its running surface RAIL_Y), a
## line of light along its foot; lattice portals over the street and the island and piers in the sea (on concrete
## caps), each carrying both girders on a lattice crossbeam; a station at each end (platforms at the cars' floors,
## railings, a canopy, lift towers down to the ground, the line's name), and the two trains (SuspendedTrains.gd).
func _build_suspended(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Muallaq"
	root.add_child(node)
	node.owner = level
	var body := StaticBody3D.new()
	body.name = "MuallaqFrames"
	body.set_meta(&"surface", "rock")
	node.add_child(body)
	body.owner = level
	var steel := Color(0.20, 0.24, 0.26)
	var cool := Color(0.7, 0.85, 1.0)
	var top_y: float = RAIL_Y + 4.4
	var beam_top: float = RAIL_Y + 6.8
	# The girders, span by span (between frames), both tracks in each piece.
	for fi in range(FRAME_Z.size() - 1):
		var z0: float = FRAME_Z[fi]
		var z1: float = FRAME_Z[fi + 1]
		var pk := MarinaKit.new_kit(1.0)
		var kit := {}
		for sd in [-1.0, 1.0]:
			var tx: float = LINE_X + sd * TRACK_OFF
			var a := Vector3(tx, RAIL_Y + 1.4, z0)
			var b := Vector3(tx, RAIL_Y + 1.4, z1)
			_truss(pk, kit, a, b, Vector3.UP, Vector3.RIGHT, 3.0, 2.2, 3.0, 0.34, 0.16, steel)
			# The rail, and its brackets up to the girder on the side away from the cars' hangers.
			pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(tx, RAIL_Y - 0.25, (z0 + z1) * 0.5)), Vector3(0.5, 0.5, absf(z1 - z0)), steel.darkened(0.2))
			var nb: int = maxi(int(absf(z1 - z0) / 3.0), 1)
			for k in range(nb + 1):
				var zk: float = lerpf(z0, z1, float(k) / float(nb))
				pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(tx + 0.75, RAIL_Y + 0.6, zk)), Vector3(0.18, 1.7, 0.3), steel)
			pk.box(kit, "led", Transform3D(Basis(), Vector3(tx - 1.12, RAIL_Y + 1.3, (z0 + z1) * 0.5)), Vector3(0.06, 0.06, absf(z1 - z0)), cool)
		_mesh_node(node, "MuallaqGirders_%d" % fi, MarinaKit.commit(pk, kit), 1300.0, true)
	# The frames.
	for fi2 in range(FRAME_Z.size()):
		var z: float = FRAME_Z[fi2]
		var sea: bool = _frame_in_sea(z)
		var u: float = SEA_LEG_U if sea else LEG_U
		var pk2 := MarinaKit.new_kit(1.0)
		var kit2 := {}
		var foot_y: float = 0.6 if sea else LAND - 0.2
		for sd in [-1.0, 1.0]:
			var lx: float = LINE_X + sd * u
			_truss(pk2, kit2, Vector3(lx - 0.8, foot_y, z), Vector3(lx - 0.8, beam_top, z), Vector3.RIGHT, Vector3(0, 0, 1), 1.6, 1.6, 2.2, 0.32, 0.14, steel)
			_box_shape(body, Transform3D(Basis(), Vector3(lx, (foot_y + beam_top) * 0.5, z)), Vector3(1.8, beam_top - foot_y, 1.8))
			if sea:
				pk2.lathe(kit2, "marble", Vector3(lx, -4.0, z), [Vector2(2.4, 0.0), Vector2(2.4, 4.4), Vector2(2.0, 4.8), Vector2(0.0, 4.8)], 12, Color(0.62, 0.60, 0.56))
			else:
				pk2.box(kit2, "marble", Transform3D(Basis(), Vector3(lx, LAND + 0.2, z)), Vector3(2.6, 0.6, 2.6), Color(0.62, 0.60, 0.56))
		_truss(pk2, kit2, Vector3(LINE_X - u, top_y, z), Vector3(LINE_X + u, top_y, z), Vector3.UP, Vector3(0, 0, 1), beam_top - top_y, 1.6, 2.4, 0.34, 0.14, steel)
		_mesh_node(node, "MuallaqFrame_%d" % fi2, MarinaKit.commit(pk2, kit2), 1300.0, true)
	# The stations.
	for st_i in range(2):
		var zr: Vector2 = STATION_CITY if st_i == 0 else STATION_ISLAND
		_rail_station(node, body, zr, "AL-MADINA" if st_i == 0 else "JAZIRAT AL-FANOUS", st_i, st_i == 0)
	# The trains: two cars hung cab to cab outward, the same car mesh twice.
	var pkc := MarinaKit.new_kit(PS)
	var kitc := {}
	MarinaKit.hanging_car(pkc, kitc, true)
	var car_mesh: ArrayMesh = d.save(MarinaKit.commit(pkc, kitc), "muallaq_car") as ArrayMesh
	var trains := Node3D.new()
	trains.name = "MuallaqTrains"
	trains.set_script(load("res://SuspendedTrains.gd"))
	var stop0: float = (STATION_CITY.x + STATION_CITY.y) * 0.5
	var stop1: float = (STATION_ISLAND.x + STATION_ISLAND.y) * 0.5
	trains.set("start", Vector3(LINE_X, RAIL_Y, stop0))
	trains.set("end", Vector3(LINE_X, RAIL_Y, stop1))
	node.add_child(trains)
	trains.owner = level
	var half: float = MarinaKit.CAR_LEN * 0.5 * PS + 0.25
	for ti in range(2):
		var tr := Node3D.new()
		tr.name = "Train%d" % ti
		tr.set_meta("track", Vector3((-1.0 if ti == 0 else 1.0) * TRACK_OFF, 0.0, 0.0))
		trains.add_child(tr)
		tr.owner = level
		for ci in range(2):
			var mi := MeshInstance3D.new()
			mi.name = "Car%d" % ci
			mi.mesh = car_mesh
			# The car mesh is built at PS already (MarinaKit.new_kit(PS) scales its frame).
			mi.transform = Transform3D(Basis(Vector3.UP, 0.0 if ci == 0 else PI), Vector3(0, 0, -half if ci == 0 else half))
			tr.add_child(mi)
			mi.owner = level
	print("Al-Mu'allaq: %d frames, line %.0fm" % [FRAME_Z.size(), stop1 - stop0])


## A station over the line from zr.x to zr.y: a platform outside each track at the cars' floor (railings on its outer
## edge, benches, lights), a canopy over the frames, the line's name and the station's on its fascia both ways, and two
## glazed lift towers down to the ground.
func _rail_station(node: Node3D, body: StaticBody3D, zr: Vector2, nm: String, idx: int, hall := false) -> void:
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var steel := Color(0.20, 0.24, 0.26)
	var floor_y: float = RAIL_Y + MarinaKit.CAR_FLOOR * PS
	var z0: float = zr.x - 1.0
	var z1: float = zr.y + 1.0
	var zc: float = (z0 + z1) * 0.5
	var zl: float = z1 - z0
	for sd in [-1.0, 1.0]:
		var u0: float = TRACK_OFF + MarinaKit.CAR_W * 0.5 * PS + 0.12
		var u1: float = LEG_U - 0.9
		var ux: float = (u0 + u1) * 0.5
		pk.box(kit, "marble", Transform3D(Basis(), Vector3(LINE_X + sd * ux, floor_y - 0.3, zc)), Vector3(u1 - u0, 0.6, zl), Color(0.80, 0.78, 0.74))
		pk.box(kit, "led", Transform3D(Basis(), Vector3(LINE_X + sd * (u0 + 0.05), floor_y + 0.01, zc)), Vector3(0.14, 0.02, zl), Color(1.0, 0.85, 0.3))
		pk.box(kit, "led", Transform3D(Basis(), Vector3(LINE_X + sd * ux, floor_y - 0.62, zc)), Vector3(0.3, 0.04, zl - 1.0), MarinaKit.WARM * 0.7)
		# Railing on its outer edge.
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(LINE_X + sd * (u1 - 0.05), floor_y + 1.1, zc)), Vector3(0.08, 0.08, zl), Color(0.8, 0.82, 0.85))
		pk.box(kit, "yglass", Transform3D(Basis(), Vector3(LINE_X + sd * (u1 - 0.05), floor_y + 0.55, zc)), Vector3(0.04, 1.0, zl), Color(0.2, 0.25, 0.3))
		for bz in range(3):
			var zz: float = z0 + zl * (float(bz) + 0.5) / 3.0
			pk.box(kit, "timber", Transform3D(Basis(), Vector3(LINE_X + sd * (u1 - 0.9), floor_y + 0.45, zz)), Vector3(0.6, 0.1, 2.4), Color(0.5, 0.32, 0.18))
		# A lift tower down to the ground at each end, glazed and lit (a terminus has its hall instead).
		for ez in ([] if hall else [z0 + 3.0, z1 - 3.0]):
			var lx: float = LINE_X + sd * (LEG_U - 3.4)
			var ground_y: float = LAND
			var h: float = floor_y + 3.2 - ground_y
			pk.box(kit, "glasslit", Transform3D(Basis(), Vector3(lx, ground_y + h * 0.5, ez)), Vector3(2.8, h, 2.8), Color(0.22, 0.30, 0.38))
			for cx in [-1.45, 1.45]:
				for cz in [-1.45, 1.45]:
					pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(lx + cx, ground_y + h * 0.5, ez + cz)), Vector3(0.2, h, 0.2), steel)
			pk.box(kit, "paintsteel", Transform3D(Basis(), Vector3(lx, ground_y + h + 0.2, ez)), Vector3(3.2, 0.4, 3.2), steel)
			_box_shape(body, Transform3D(Basis(), Vector3(lx, ground_y + h * 0.5, ez)), Vector3(3.0, h, 3.0))
		people.append([Vector3(LINE_X + sd * (u1 - 1.6), floor_y, zc + (3.0 if sd > 0.0 else -4.0)), Vector3(-sd, 0, 0), false, false])
		people.append([Vector3(LINE_X + sd * (u1 - 2.3), floor_y, zc - 9.0), Vector3(-sd, 0, 0.3).normalized(), false, false])
	# The canopy: a shallow vault over the frames, its fascia lit, the names on it.
	var cy: float = RAIL_Y + 7.3
	var span: float = LEG_U + 1.0
	var segs := 10
	for i in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var x0: float = lerpf(-span, span, t0)
		var x1: float = lerpf(-span, span, t1)
		var y0: float = cy + 2.2 * (1.0 - pow(x0 / span, 2.0))
		var y1: float = cy + 2.2 * (1.0 - pow(x1 / span, 2.0))
		var nn := Vector3(-(y1 - y0), x1 - x0, 0.0).normalized()
		pk.quad(kit, "paintsteel", [Vector3(LINE_X + x0, y0, z0 - 2.0), Vector3(LINE_X + x1, y1, z0 - 2.0), Vector3(LINE_X + x1, y1, z1 + 2.0), Vector3(LINE_X + x0, y0, z1 + 2.0)],
				nn, Color(0.85, 0.87, 0.9))
		pk.quad(kit, "paintsteel", [Vector3(LINE_X + x0, y0 - 0.15, z0 - 2.0), Vector3(LINE_X + x1, y1 - 0.15, z0 - 2.0), Vector3(LINE_X + x1, y1 - 0.15, z1 + 2.0),
				Vector3(LINE_X + x0, y0 - 0.15, z1 + 2.0)], -nn, Color(0.35, 0.37, 0.4))
	for ez2 in [z0 - 2.0, z1 + 2.0]:
		pk.box(kit, "led", Transform3D(Basis(), Vector3(LINE_X, cy - 0.3, ez2)), Vector3(span * 2.0, 0.12, 0.12), Color(0.55, 0.85, 1.0))
		var lbl := Label3D.new()
		lbl.name = "MuallaqStationName_%d_%d" % [idx, 0 if ez2 < zc else 1]
		lbl.text = "AL-MU'ALLAQ  -  " + nm
		lbl.font_size = 64
		lbl.pixel_size = 0.022
		lbl.modulate = Color(0.75, 1.0, 1.25)
		lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		lbl.double_sided = false
		lbl.position = Vector3(LINE_X, cy + 0.6, ez2 + (-0.2 if ez2 < zc else 0.2))
		lbl.rotation = Vector3(0.0, PI if ez2 < zc else 0.0, 0.0)
		node.add_child(lbl)
		lbl.owner = level
	_mesh_node(node, "MuallaqStation_%d" % idx, MarinaKit.commit(pk, kit), 1300.0, true)
	for li in range(3):
		_light(node, "MuallaqStationLight_%d_%d" % [idx, li], Vector3(LINE_X + (-6.0 if li % 2 == 0 else 6.0), floor_y + 3.2, lerpf(z0 + 6.0, z1 - 6.0, float(li) / 2.0)),
				Color(0.9, 0.95, 1.0), 2.2, 22.0, 400.0)
	_light(node, "MuallaqUnderLight_%d" % idx, Vector3(LINE_X, floor_y - 3.0, zc), Color(1.0, 0.82, 0.6), 3.0, 30.0, 400.0)
	if hall:
		_terminus_hall(node, body, zr, floor_y)


## A terminus's hall under its platforms, on the ground among the city's blocks: two wings of pale stone under the
## platforms (two tiers of tall pointed windows lit from inside on their long faces, a gold cornice with a line of
## light, the line's name along them), a lower glazed hall between them under the tracks (the cars hang over its roof,
## clear of it), a grand pointed entrance at each end under a canopy with the station's name over it. Solid.
func _terminus_hall(node: Node3D, body: StaticBody3D, zr: Vector2, floor_y: float) -> void:
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	var stone := Color(0.90, 0.84, 0.72)
	var warm := Color(1.0, 0.80, 0.52)
	var z0: float = zr.x - 1.0
	var z1: float = zr.y + 1.0
	var zc: float = (z0 + z1) * 0.5
	var zl: float = z1 - z0
	var top: float = floor_y - 0.65
	var u_in: float = TRACK_OFF + MarinaKit.CAR_W * 0.5 * PS + 0.4
	var u_out: float = LEG_U - 1.2
	var low_top: float = LAND + 12.0
	for sd in [-1.0, 1.0]:
		var ux: float = (u_in + u_out) * 0.5
		var wing := Transform3D(Basis(), Vector3(LINE_X + sd * ux, (LAND + top) * 0.5, zc))
		pk.box(kit, "marble", wing, Vector3(u_out - u_in, top - LAND, zl), stone)
		_box_shape(body, wing, Vector3(u_out - u_in, top - LAND, zl))
		# Two tiers of pointed windows on the outer face, every 7.5m.
		var xo: float = LINE_X + sd * (u_out + 0.04)
		var n := Vector3(sd, 0.0, 0.0)
		var zw := z0 + 6.0
		while zw < z1 - 4.0:
			for tier in [[3.0, 9.5, 11.0], [12.5, 19.0, 20.5]]:
				var y0: float = LAND + float(tier[0])
				var y1: float = LAND + float(tier[1])
				var yt: float = LAND + float(tier[2])
				var pts := [Vector3(xo, y0, zw - 1.6), Vector3(xo, y0, zw + 1.6), Vector3(xo, y1, zw + 1.6), Vector3(xo, yt, zw), Vector3(xo, y1, zw - 1.6)]
				pk.tri(kit, "glasslit", pts[0], pts[1], pts[2], n, n, n, warm, n)
				pk.tri(kit, "glasslit", pts[0], pts[2], pts[4], n, n, n, warm, n)
				pk.tri(kit, "glasslit", pts[4], pts[2], pts[3], n, n, n, warm, n)
			zw += 7.5
		pk.box(kit, "metal", Transform3D(Basis(), Vector3(LINE_X + sd * (u_out + 0.15), top - 0.6, zc)), Vector3(0.4, 0.5, zl + 0.4), MarinaKit.GOLD)
		pk.box(kit, "led", Transform3D(Basis(), Vector3(LINE_X + sd * (u_out + 0.38), top - 0.95, zc)), Vector3(0.06, 0.08, zl), warm)
		var lbl := Label3D.new()
		lbl.name = "MuallaqTerminusName_%d" % (0 if sd < 0.0 else 1)
		lbl.text = "AL-MU'ALLAQ"
		lbl.font_size = 64
		lbl.pixel_size = 0.045
		lbl.modulate = Color(0.75, 1.0, 1.25)
		lbl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		lbl.double_sided = false
		lbl.position = Vector3(LINE_X + sd * (u_out + 0.3), top - 2.6, zc)
		lbl.rotation = Vector3(0.0, sd * PI * 0.5, 0.0)
		node.add_child(lbl)
		lbl.owner = level
	# The lower hall between the wings, under the tracks: its glazed roof well under the cars.
	var mid := Transform3D(Basis(), Vector3(LINE_X, (LAND + low_top) * 0.5, zc))
	pk.box(kit, "marble", mid, Vector3(u_in * 2.0 + 0.1, low_top - LAND, zl), stone.darkened(0.06))
	_box_shape(body, mid, Vector3(u_in * 2.0 + 0.1, low_top - LAND, zl))
	pk.quad(kit, "glasslit", [Vector3(LINE_X - u_in, low_top + 0.03, z0 + 1.0), Vector3(LINE_X + u_in, low_top + 0.03, z0 + 1.0),
			Vector3(LINE_X + u_in, low_top + 0.03, z1 - 1.0), Vector3(LINE_X - u_in, low_top + 0.03, z1 - 1.0)], Vector3.UP, Color(0.5, 0.62, 0.72))
	# A grand entrance at each end: a pointed arch of light with dark doors in it, a canopy over them, the name above.
	for e in [[z0, -1.0], [z1, 1.0]]:
		var ze: float = float(e[0]) + float(e[1]) * 0.05
		var ne := Vector3(0.0, 0.0, float(e[1]))
		var arch: Array = _pointed(-4.2, 4.2, 7.5, 10.8, 6)
		var poly := PackedVector2Array()
		poly.append(Vector2(4.2, 0.2))
		poly.append(Vector2(-4.2, 0.2))
		for q in arch:
			poly.append(q)
		var tris := Geometry2D.triangulate_polygon(poly)
		for t in range(0, tris.size(), 3):
			var a3: Vector2 = poly[tris[t]]
			var b3: Vector2 = poly[tris[t + 1]]
			var c3: Vector2 = poly[tris[t + 2]]
			pk.tri(kit, "glasslit", Vector3(LINE_X + a3.x, LAND + a3.y, ze), Vector3(LINE_X + b3.x, LAND + b3.y, ze), Vector3(LINE_X + c3.x, LAND + c3.y, ze),
					ne, ne, ne, warm, ne)
		pk.quad(kit, "matte", [Vector3(LINE_X - 3.0, LAND + 0.2, ze + float(e[1]) * 0.02), Vector3(LINE_X + 3.0, LAND + 0.2, ze + float(e[1]) * 0.02),
				Vector3(LINE_X + 3.0, LAND + 4.6, ze + float(e[1]) * 0.02), Vector3(LINE_X - 3.0, LAND + 4.6, ze + float(e[1]) * 0.02)], ne, Color(0.18, 0.12, 0.08))
		pk.box(kit, "marble", Transform3D(Basis(), Vector3(LINE_X, LAND + 6.2, float(e[0]) + float(e[1]) * 2.6)), Vector3(13.0, 0.5, 5.2), stone.lightened(0.04))
		pk.box(kit, "led", Transform3D(Basis(), Vector3(LINE_X, LAND + 5.92, float(e[0]) + float(e[1]) * 2.6)), Vector3(12.0, 0.05, 4.6), warm)
		var nl := Label3D.new()
		nl.name = "MuallaqTerminusEntrance_%d" % (0 if float(e[1]) < 0.0 else 1)
		nl.text = "MAHATTAT AL-MADINA"
		nl.font_size = 64
		nl.pixel_size = 0.022
		nl.modulate = Color(1.4, 1.15, 0.65)
		nl.alpha_cut = Label3D.ALPHA_CUT_DISCARD
		nl.double_sided = false
		nl.position = Vector3(LINE_X, LAND + 11.6, float(e[0]) + float(e[1]) * 0.1)
		nl.rotation = Vector3(0.0, 0.0 if float(e[1]) > 0.0 else PI, 0.0)
		node.add_child(nl)
		nl.owner = level
		_light(node, "MuallaqTerminusLight_%d" % (0 if float(e[1]) < 0.0 else 1), Vector3(LINE_X, LAND + 4.0, float(e[0]) + float(e[1]) * 7.0),
				Color(1.0, 0.82, 0.58), 3.0, 26.0, 500.0)
		for k in range(3):
			people.append([Vector3(LINE_X + (float(k) - 1.0) * 3.0, LAND, float(e[0]) + float(e[1]) * (8.0 + float(k))), ne, false, false])
	_mesh_node(node, "MuallaqTerminus", MarinaKit.commit(pk, kit), 1400.0, true)


# ======================================================================================
#  Jazirat al-Fanous: the island, Burj al-Fanous and its searchlights
# ======================================================================================

## Burj al-Fanous (MarinaKit.fanous_tower) in the island's middle, floodlit from its podium; eight searchlights round
## the podium sweeping the sky (SkyBeams.gd, club_beam.gdshader); lantern posts along the walk from the railway's
## station to the podium; people strolling.
func _build_island(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Fanous"
	root.add_child(node)
	node.owner = level
	var pk := MarinaKit.new_kit(1.0)
	var kit := {}
	pk.set_frame(Transform3D(Basis(), Vector3(FANOUS_AT.x, LAND, FANOUS_AT.y)))
	var top: float = MarinaKit.fanous_tower(pk, kit)
	pk.reset_frame()
	_mesh_node(node, "BurjAlFanous", MarinaKit.commit(pk, kit), 0.0, true)
	for k in range(6):
		var a: float = TAU * (float(k) + 0.5) / 6.0
		_light(node, "FanousFlood_%d" % k, Vector3(FANOUS_AT.x + cos(a) * 52.0, LAND + 9.0, FANOUS_AT.y + sin(a) * 52.0), Color(1.0, 0.76, 0.46), 5.0, 72.0, 3000.0)
	_light(node, "FanousBeacon", Vector3(FANOUS_AT.x, LAND + top + 1.0, FANOUS_AT.y), Color(1.0, 0.2, 0.15), 3.0, 40.0, 3000.0)
	# The searchlights.
	var beams := Node3D.new()
	beams.name = "FanousSkyBeams"
	beams.set_script(load("res://SkyBeams.gd"))
	node.add_child(beams)
	beams.owner = level
	var bmesh := _beam_cone(1700.0, 1.4, 42.0)
	var bmat := ShaderMaterial.new()
	bmat.shader = load("res://club_beam.gdshader")
	bmat.set_shader_parameter("energy", 0.09)
	bmat.set_shader_parameter("near_fade", 60.0)
	bmesh.surface_set_material(0, d.save(bmat, "fanous_beam_mat"))
	var saved: Mesh = d.save(bmesh, "fanous_beam") as Mesh
	for i in range(8):
		var a2: float = TAU * (float(i) + 0.5) / 8.0
		var b := MeshInstance3D.new()
		b.name = "Beam%d" % i
		b.mesh = saved
		b.position = Vector3(FANOUS_AT.x + cos(a2) * 70.0, LAND + 6.5, FANOUS_AT.y + sin(a2) * 70.0)
		b.set_meta("phase", a2)
		b.set_meta("spin", 1.0 if i % 2 == 0 else -1.0)
		b.set_instance_shader_parameter("tint", Color(1.0, 0.92, 0.78))
		b.set_instance_shader_parameter("strength", 1.0)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beams.add_child(b)
		b.owner = level
	# The walk from the station to the podium: lantern posts either side, and people about.
	var pk2 := MarinaKit.new_kit(1.0)
	var kit2 := {}
	MarinaKit.lantern_post(pk2, kit2)
	var post: ArrayMesh = d.save(MarinaKit.commit(pk2, kit2), "island_lantern_post") as ArrayMesh
	var xfs: Array = []
	var z := STATION_ISLAND.y + 8.0
	var walk_end: float = FANOUS_AT.y - 82.0
	while z < walk_end:
		for sd in [-1.0, 1.0]:
			xfs.append(Transform3D(Basis().scaled(Vector3.ONE * PS), Vector3(LINE_X + sd * 9.0, LAND, z)))
		_light(node, "IslandWalkLight_%d" % xfs.size(), Vector3(LINE_X, LAND + 6.0, z), Color(1.0, 0.82, 0.58), 1.8, 18.0, 900.0)
		z += 16.0
	d.scatter(node, post, xfs, "IslandPosts", 200.0, 1200.0, 0.0, false, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7711
	for i in range(36):
		var a3: float = rng.randf() * TAU
		var r: float = rng.randf_range(84.0, 120.0)
		var p := Vector2(FANOUS_AT.x + cos(a3) * r, FANOUS_AT.y + sin(a3) * r)
		if i < 12:
			p = Vector2(LINE_X + rng.randf_range(-6.0, 6.0), rng.randf_range(STATION_ISLAND.y + 6.0, walk_end))
		if AT.marina_island_d(p.x, p.y) > -6.0:
			continue
		people.append([Vector3(p.x, LAND, p.y), Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), false, false])
	print("Jazirat al-Fanous: the tower %.0fm, 8 searchlights" % top)


## The city's name in gold, الريحانة (Al-Raihana), standing on a stone plinth in the sea, read from the corniche, the
## bridge's crest and the tube: Amiri Bold (fonts/, SIL Open Font License) through a TextMesh, baked to a mesh (no font
## at runtime), RAIHANA_WIDTH long, drawn by raihana_letters.gdshader. The plinth's top is the word's baseline,
## RAIHANA_TOP over the sea; under the ر's tail and the ي's dots, which hang below the baseline, its front steps back
## into a bay so they hang free (on the top they would be buried, and ي without its dots reads as another letter). An
## LED line along the plinth's top edges, the name in Latin letters on its face where nothing hangs, uplights, and a gold
## glint on the water before it (raihana_glint.gdshader).
func _build_raihana(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "RaihanaName"
	root.add_child(node)
	node.owner = level
	var font: FontFile = load("res://fonts/Amiri-Bold.ttf")
	var tm := TextMesh.new()
	tm.text = RAIHANA_TEXT
	tm.font = font
	tm.font_size = 64
	tm.pixel_size = 0.05
	tm.depth = 0.35
	tm.curve_step = 0.4
	var arrays: Array = tm.get_mesh_arrays()
	var word := ArrayMesh.new()
	word.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var box: AABB = word.get_aabb()
	# TextMesh centres the line box (ascent over descent) on its origin, which puts the baseline here.
	var baseline: float = (font.get_descent(64) - font.get_ascent(64)) * 0.5 * tm.pixel_size
	var s: float = RAIHANA_WIDTH / box.size.x
	var cx: float = box.position.x + box.size.x * 0.5
	# What hangs below the baseline (the ر's tail, the ي's dots), in the frame's x.
	var hang0 := INF
	var hang1 := -INF
	for v in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		if v.y < baseline - 0.08:
			hang0 = minf(hang0, (v.x - cx) * s)
			hang1 = maxf(hang1, (v.x - cx) * s)
	var xa: float = hang0 - 0.8
	var xb: float = hang1 + 0.8
	var frame := Transform3D(Basis(Vector3.UP, atan2(RAIHANA_FACE.x, RAIHANA_FACE.y)), Vector3(RAIHANA_AT.x, 0.0, RAIHANA_AT.y))
	# In the frame: x along the word, +z its front; the word's back face 0.15m in front of the bay's back wall (z 0).
	var mi := _mesh_node(node, "RaihanaWord", word)
	mi.transform = frame * Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(-cx * s, RAIHANA_TOP - baseline * s, tm.depth * 0.5 * s + 0.15))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://raihana_letters.gdshader")
	mat.set_shader_parameter("y0", box.position.y)
	mat.set_shader_parameter("y1", box.end.y)
	mi.material_override = d.save(mat, "raihana_letters_material")
	var front: float = 0.15 + tm.depth * s
	var face: float = front + 0.4
	var hl: float = RAIHANA_WIDTH * 0.5 + 4.0
	var top := RAIHANA_TOP
	var pale := Color(0.88, 0.82, 0.72)
	var trim := Color(0.94, 0.90, 0.82)
	var pk := MarinaKit.new_kit(1.0)
	pk.set_frame(frame)
	var kit := {}
	# The stone course at the waterline (the bay's floor), the pale body either side of the bay and behind it, the
	# cornice, the LED line along the top edges.
	pk.block(kit, "stone", Vector3(-hl - 0.8, -4.6, -RAIHANA_DEPTH - 0.8), Vector3(hl + 0.8, 0.9, face + 0.8), Color(0.44, 0.40, 0.35), 1.0)
	for part in [[-hl, xa, face], [xb, hl, face], [xa, xb, 0.0]]:
		var x0: float = part[0]
		var x1: float = part[1]
		var z1: float = part[2]
		pk.block(kit, "stucco", Vector3(x0, 0.9, -RAIHANA_DEPTH), Vector3(x1, top - 0.45, z1), pale, 1.0)
		pk.block(kit, "stucco", Vector3(x0 - (0.25 if x0 == -hl else 0.0), top - 0.45, -RAIHANA_DEPTH - 0.25), Vector3(x1 + (0.25 if x1 == hl else 0.0), top, z1 + 0.1), trim, 1.0)
		pk.block(kit, "led", Vector3(x0, top - 0.36, z1 + 0.1), Vector3(x1, top - 0.24, z1 + 0.13), Color(1.0, 0.72, 0.34))
	# The bay's side walls' edges catch the light too.
	for xe in [xa, xb]:
		pk.block(kit, "led", Vector3(xe - 0.06, 0.9, face - 0.03), Vector3(xe + 0.06, top - 0.45, face + 0.1), Color(1.0, 0.72, 0.34))
	var plinth := _mesh_node(node, "RaihanaPlinth", MarinaKit.commit(pk, kit))
	plinth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# The name in Latin letters on the plinth's face, on the side where nothing hangs.
	var lab := Label3D.new()
	lab.name = "RaihanaLatin"
	lab.text = "AL-RAIHANA"
	lab.font_size = 96
	lab.pixel_size = 0.024
	lab.modulate = Color(2.2, 1.55, 0.7)
	lab.shaded = false
	lab.double_sided = false
	lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	var left_mid: float = (-hl + xa) * 0.5
	var right_mid: float = (xb + hl) * 0.5
	var lx: float = left_mid if (xa + hl) >= (hl - xb) else right_mid
	lab.transform = frame * Transform3D(Basis(), Vector3(lx, top - 2.1, face + 0.06))
	node.add_child(lab)
	lab.owner = level
	# Uplights before the word, over the water.
	for k in range(3):
		_light(node, "RaihanaLight_%d" % k, frame * Vector3((float(k) - 1.0) * RAIHANA_WIDTH * 0.33, top + 1.2, face + 4.0), Color(1.0, 0.78, 0.5), 3.0, 24.0, 220.0)
	# The glint on the water before it.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z0: float = face + 1.0
	var z1g: float = face + 55.0
	var corners := [Vector3(-hl, 0.04, z0), Vector3(hl, 0.04, z0), Vector3(hl, 0.04, z1g), Vector3(-hl, 0.04, z1g)]
	var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[i])
		st.add_vertex(frame * (corners[i] as Vector3))
	var glint := _mesh_node(node, "RaihanaGlint", st.commit(), 0.0, false)
	var gm := ShaderMaterial.new()
	gm.shader = load("res://raihana_glint.gdshader")
	gm.render_priority = 3
	glint.material_override = d.save(gm, "raihana_glint_material")
	print("Raihana: the word %.0f x %.0fm (scale %.2f), %d triangles; hanging from x %.1f to %.1f" % [box.size.x * s, box.size.y * s, s,
			(arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3, hang0, hang1])


## A searchlight's beam: an open cone along +y from radius r0 at its foot to r1 at L, UV.y 0 at the foot to 1 at the far
## end (club_beam.gdshader), normals out from its axis.
func _beam_cone(L: float, r0: float, r1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	for i in range(n):
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var p00: Vector3 = d0 * r0
		var p01: Vector3 = d1 * r0
		var p10: Vector3 = d0 * r1 + Vector3(0, L, 0)
		var p11: Vector3 = d1 * r1 + Vector3(0, L, 0)
		for v in [[p00, d0, 0.0], [p10, d0, 1.0], [p11, d1, 1.0], [p00, d0, 0.0], [p11, d1, 1.0], [p01, d1, 0.0]]:
			st.set_normal(v[1])
			st.set_uv(Vector2(0.0, float(v[2])))
			st.add_vertex(v[0])
	return st.commit()


## Airliners over the sea at night (Airliners.gd): arrivals from the west along the coast 1km offshore, beyond the island,
## down the glide path to an airport east of the city (out of sight); departures from it climbing out west 1.7km
## offshore and turning inland far off. Landing lights, strobes, lit cabins and floodlit tails.
func _build_airliners(root: Node3D) -> void:
	var arr: Dictionary = Airliners.arrival(Vector3(5400.0, 0.0, 1250.0), Vector2(1.0, 0.0),
			[[Vector3(-11000.0, 1150.0, 3600.0), 170.0]], 9000.0, 105.0, 0.0, 2600.0)
	var dep: Dictionary = Airliners.departure(Vector3(6200.0, 0.0, 1950.0), Vector2(-1.0, 0.0),
			[[Vector3(-4500.0, 1050.0, 1950.0), 182.0], [Vector3(-10500.0, 2200.0, -1200.0), 210.0]], 2800.0, 105.0, 52.0, 2600.0)
	var node := Node3D.new()
	node.name = "Airliners"
	node.set_script(Airliners)
	node.set("routes", [arr, dep])
	node.set("night", 1.0)
	root.add_child(node)
	node.owner = level
	# Clear of the island's tower (its beacon about 309m up).
	var b: Dictionary = Airliners.build_route(arr)
	var nearest := 1e9
	for q in (b.pos as PackedVector3Array):
		nearest = minf(nearest, Vector2(q.x, q.z).distance_to(FANOUS_AT))
	print("Airliners over the sea: arrivals pass %.0fm from Burj al-Fanous" % nearest)


## Keeps the city's blocks and towers off the new set pieces: the arcade's hall and portals, the railway's legs, lift
## towers and the station over the street.
func _reserve_landmarks() -> void:
	_foot_add(_obb(Vector2(AVENUE_X, (ARCADE_Z0 + ARCADE_Z1) * 0.5), Basis(), HALL_HALF + SHOP_DEPTH + 5.5, (ARCADE_Z0 - ARCADE_Z1) * 0.5 + 6.0))
	for leg in _rail_legs():
		if not _frame_in_sea((leg as Vector2).y):
			_foot_add(_obb(leg, Basis(), 2.6, 2.6))
	# The city terminus stands in a forecourt of its own, so it reads as a station from the souk and the street.
	_foot_add(_obb(Vector2(LINE_X, (STATION_CITY.x + STATION_CITY.y) * 0.5), Basis(), LEG_U + 18.0, (STATION_CITY.y - STATION_CITY.x) * 0.5 + 22.0))


## Whether (x, z) is too near the railway's legs or a station's lift towers for a palm or a street lamp.
func _near_rail_foot(x: float, z: float, r: float) -> bool:
	for leg in _rail_legs():
		if (leg as Vector2).distance_to(Vector2(x, z)) < r:
			return true
	for zr in [STATION_CITY, STATION_ISLAND]:
		var v: Vector2 = zr
		if z > v.x - 6.0 and z < v.y + 6.0 and absf(absf(x - LINE_X) - (LEG_U - 3.4)) < r + 1.5:
			return true
	return false



## The start promenade's crowd cheering the racers by (CrowdCheers.gd): a section behind each side's barriers every 30m
## along the straight and a louder one at the grandstand.
func _build_cheers(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "PromenadeCheers"
	node.set_script(load("res://CrowdCheers.gd"))
	root.add_child(node)
	node.owner = level
	var sf: float = s_finish
	var k := 0
	for side in [[1.0, sf - 100.0, sf + 30.0], [-1.0, sf - 90.0, sf + 30.0]]:
		var s: float = float(side[1])
		while s <= float(side[2]):
			var sw: float = fposmod(s, lap_len)
			var p: Vector3 = _pt(sw) + _rt(sw) * float(side[0]) * (BARRIER_LAT + 2.5)
			var sec := Node3D.new()
			sec.name = "Section%d" % k
			sec.position = Vector3(p.x, LAND + 2.0, p.z)
			node.add_child(sec)
			sec.owner = level
			k += 1
			s += 30.0
	var g: Vector3 = _pt(sf) + _rt(sf) * (STAND_LAT + 6.0)
	var gs := Node3D.new()
	gs.name = "SectionStand"
	gs.position = Vector3(g.x, LAND + 5.0, g.z)
	gs.set_meta("gain", 4.0)
	node.add_child(gs)
	gs.owner = level
	print("Cheering sections: ", k + 1)
