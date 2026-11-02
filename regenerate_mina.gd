# regenerate_mina.gd
#
# Builds levels/MinaLevel.tscn - "Mina del Viento" (Stage 4 Finale of Sierra del Viento GP).
# The game's first official Point-to-Point Rally Sprint stage (~4.6 km descent):
#   - Sector 1: The Observatory Plateau & Dawn Balloon Fiesta (+52m to +42m, tarmac, dishes, balloons)
#   - Sector 2: The Caldera Knife-Edge Rim (+42m to +22m, gravel, haboob dust storm, crosswinds, tumbleweeds)
#   - Sector 3: The Open-Pit Copper Mine Terraces (+22m to -22m, stepped benches, colossal haul trucks, hairpins)
#   - Sector 4: Blast Cutting, Overhead Conveyor Bridges & Pit Depot (-22m to -32m, crushing plant, finish portal)
extends Node

const LEVEL_NAME := "MinaLevel"
const LEVEL_PATH := "res://levels/MinaLevel.tscn"
const RES_PREFIX := "mina_"
const MeshChunker = preload("res://MeshChunker.gd")
const MinaKit = preload("res://MinaKit.gd")
const CactusKit = preload("res://CactusKit.gd")
const FreightKit = preload("res://FreightKit.gd")
const PropKit = preload("res://PropKit.gd")

const MESH_CHUNK_CELL := 80.0

const ROAD_HALF := 7.5
const ROAD_COLLIDE := 8.2
const ROAD_FLAT := 9.2
const ROAD_CUT := 1.8
const ROAD_FILL := 0.75
const GRADE_REACH := 55.0
const CELL := 40.0
const SAMPLE_STEP := 2.5

## The route layout as turtle moves from PLAN_START heading PLAN_HEADING:
## ["S", length] or ["R"/"L", radius, degrees]
const PLAN_START := Vector2(-420.0, -1180.0)
const PLAN_HEADING := 0.837758 # 48 deg in radians
const PLAN := [
	# Sector 1: High Plateau (The Observatory & Balloon Fiesta) ~1,150m
	["S", 260.0],          # 0  Start straight across balloon launch apron
	["R", 210.0, 48.0],    # 1  Sweeping right turn through radio telescope array
	["S", 180.0],          # 2  Array straight past tracking dishes
	["L", 170.0, 42.0],    # 3  Left curve between dual rail beds
	["S", 210.0],          # 4  Pass second array cluster
	["R", 180.0, 36.0],    # 5  Gentle right towards plateau edge
	["S", 190.0],          # 6  Approaching the caldera precipice

	# Sector 2: The Caldera Knife-Edge Rim (Haboob & Crosswinds) ~1,150m
	["L", 120.0, 78.0],    # 7  Sharp left hook hugging the caldera rim
	["S", 240.0],          # 8  Precipice shelf road (haboob strikes!)
	["R", 110.0, 65.0],    # 9  Ridge bend over canyon drop
	["S", 170.0],          # 10 High wind exposure straight
	["L", 95.0, 62.0],     # 11 Tight left switchback hugging cliff face
	["S", 210.0],          # 12 Outer shelf road towards mine entrance
	["R", 105.0, 52.0],    # 13 Rim notch turn into the mine cut

	# Sector 3: The Terraced Open-Pit Copper Mine Spiral ~1,250m
	["S", 150.0],          # 14 Rock cut into the upper quarry terrace (bench 1)
	["R", 155.0, 115.0],   # 15 Spiral right around upper bench (dodge haul trucks)
	["S", 190.0],          # 16 Haul ramp descent to bench 2
	["L", 65.0, 160.0],    # 17 Wide quarry hairpin turn onto bench 2
	["S", 175.0],          # 18 Bench 2 straight
	["R", 125.0, 120.0],   # 19 Spiral right around bench 2
	["S", 210.0],          # 20 Haul ramp descent to bench 3

	# Sector 4: Conveyor Bridges, Blast Cutting & Pit Depot ~950m
	["L", 90.0, 55.0],     # 21 Turn into the primary blast cutting
	["S", 240.0],          # 22 Under overhead ore conveyor bridges 1 & 2
	["R", 70.0, 65.0],     # 23 Right curve through crushing plant
	["L", 70.0, 65.0],     # 24 Left curve entering maintenance yard
	["S", 280.0],          # 25 Final sprint across depot floor to finish portal
]

## Height profile stations along the segments: [seg_idx, frac_along_seg, height_y]
const PROFILE := [
	[0, 0.0, 52.0],
	[0, 1.0, 51.5],
	[2, 1.0, 48.0],
	[4, 1.0, 45.0],
	[6, 1.0, 42.0],   # End of Sector 1 Plateau
	[7, 1.0, 38.5],
	[8, 1.0, 34.0],
	[10, 1.0, 28.5],
	[12, 1.0, 24.0],
	[13, 1.0, 21.5],  # End of Sector 2 Rim
	[14, 1.0, 17.0],
	[15, 1.0, 11.5],  # Bench 1
	[16, 1.0, 3.5],
	[17, 1.0, -2.5],  # Bench 2 Hairpin
	[19, 1.0, -12.0],
	[20, 1.0, -19.5], # Bench 3
	[21, 1.0, -23.5], # Blast Cutting entrance
	[22, 0.5, -26.0], # Under Conveyor Bridge
	[23, 1.0, -29.0],
	[25, 0.0, -31.0],
	[25, 1.0, -32.5], # Finish Portal
]

## Tarmac vs Gravel transitions along total track length (m):
## Plateau (0 to 1,120m): Paved Tarmac
## Rim & Pit (1,120m to 3,950m): Quarry Gravel
## Pit Depot & Finish (3,950m to end): Paved Industrial Concrete / Tarmac
const PAVED_PLATEAU_END := 1120.0
const PAVED_DEPOT_START := 3950.0

## Fine terrain grid bounding box
const FINE_X := Vector2(-580.0, 980.0)
const FINE_Z := Vector2(-1350.0, 2350.0)
const FINE_STEP := 4.5
const OUTER_X := Vector2(-2800.0, 3200.0)
const OUTER_Z := Vector2(-3500.0, 4500.0)
const COARSE_GROWTH := 1.15

## Collision bodies and surfaces
const BODIES := [
	["MinaAsphaltRoad", "asphalt", Color(0, 0, 0, 0)],
	["MinaGravelRoad", "gravel", Color(0.82, 0.60, 0.44, 0.7)],
	["MinaDirtRoad", "dirt", Color(0.78, 0.50, 0.36, 0.75)],
	["MinaGround", "gravel", Color(0.80, 0.60, 0.46, 0.6)],
	["MinaRockFace", "rock", Color(0.78, 0.56, 0.44, 0.5)],
]

# Computed runtime tables
var _plan_segs: Array = []
var _plan_s0: PackedFloat32Array = PackedFloat32Array()
var _plan_len: PackedFloat32Array = PackedFloat32Array()
var _total_track_len := 0.0
var _road_samples: Array = [] # {p: Vector2, s: float, th: float, h: float}

var _grid_x: PackedFloat32Array = PackedFloat32Array()
var _grid_z: PackedFloat32Array = PackedFloat32Array()
var _heights: PackedFloat32Array = PackedFloat32Array()
var _road_d: PackedFloat32Array = PackedFloat32Array()
var _vert_s: PackedFloat32Array = PackedFloat32Array()
var _vert_lat: PackedFloat32Array = PackedFloat32Array()

# Spatial cell buckets for road queries
var _cell_buckets: Dictionary = {}


func _ready() -> void:
	var t_start := Time.get_ticks_msec()
	print("Building %s (%s)..." % [LEVEL_NAME, LEVEL_PATH])

	_build_plan()
	_sample_road()
	_build_grid()

	var level_scene := Node3D.new()
	level_scene.name = LEVEL_NAME
	level_scene.set_script(load("res://levels/Level.gd"))
	level_scene.set("is_point_to_point", true)

	# Players container & spawners before entering tree
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

	# 1. Environment & Sky
	_build_environment(level_scene)

	# 2. TrackPath Curve
	var track_path := _build_track_path(level_scene)

	# 3. Terrain Heightfield & Road Grading
	_evaluate_terrain()

	# 4. Terrain Meshes & Collision Bodies
	_build_terrain(level_scene)

	# 5. Set Dressing (Dishes, Balloons, Trucks, Conveyors, Floodlights, Flora)
	_build_dressing(level_scene)

	# 6. Gameplay & Checkpoints
	_place_gameplay(level_scene, track_path)

	# 7. Weather System
	_setup_weather(level_scene)

	# 8. Setup level and chunking
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()

	var chunked: int = MeshChunker.chunk_scene(level_scene, "res://generated/" + RES_PREFIX, "res://generated/mina_chunks", MESH_CHUNK_CELL)
	print("  chunked %d large meshes" % chunked)

	_set_owner_recursive(level_scene, level_scene)
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

	print("Saved %s in %.1fs (Track length: %.1fm)" % [LEVEL_PATH, (Time.get_ticks_msec() - t_start) / 1000.0, _total_track_len])
	get_tree().quit(0)


# ======================================================================================
#  Plan and Road Sampling
# ======================================================================================

func _build_plan() -> void:
	_plan_segs.clear()
	var x: float = PLAN_START.x
	var z: float = PLAN_START.y
	var heading: float = PLAN_HEADING
	var cur_s: float = 0.0

	for i in range(PLAN.size()):
		var m: Array = PLAN[i]
		var kind: String = m[0]
		var seg_len: float = 0.0
		var seg_data: Dictionary = {"kind": kind, "start": Vector2(x, z), "heading": heading, "s0": cur_s}

		if kind == "S":
			var l: float = m[1]
			seg_len = l
			seg_data["len"] = l
			x += cos(heading) * l
			z += sin(heading) * l
		elif kind == "R" or kind == "L":
			var r: float = m[1]
			var deg: float = m[2]
			var rad: float = deg_to_rad(deg)
			var sign: float = 1.0 if kind == "R" else -1.0
			seg_len = r * rad
			seg_data["r"] = r
			seg_data["deg"] = deg
			seg_data["rad"] = rad
			seg_data["sign"] = sign
			var c: Vector2 = Vector2(x, z) + Vector2(cos(heading + sign * PI * 0.5), sin(heading + sign * PI * 0.5)) * r
			seg_data["c"] = c
			heading += sign * rad
			x = c.x + cos(heading - sign * PI * 0.5) * r
			z = c.y + sin(heading - sign * PI * 0.5) * r

		seg_data["end"] = Vector2(x, z)
		seg_data["end_heading"] = heading
		_plan_s0.append(cur_s)
		_plan_len.append(seg_len)
		_plan_segs.append(seg_data)
		cur_s += seg_len

	_total_track_len = cur_s


func _road_height_at(seg_idx: int, frac: float) -> float:
	# Monotone interpolation across PROFILE stations
	var s_val: float = _plan_s0[seg_idx] + _plan_len[seg_idx] * frac
	var p_count: int = PROFILE.size()

	var s_stations: PackedFloat32Array = PackedFloat32Array()
	var h_stations: PackedFloat32Array = PackedFloat32Array()
	for p in PROFILE:
		var st_idx: int = p[0]
		var st_frac: float = p[1]
		var st_h: float = p[2]
		s_stations.append(_plan_s0[st_idx] + _plan_len[st_idx] * st_frac)
		h_stations.append(st_h)

	if s_val <= s_stations[0]:
		return h_stations[0]
	if s_val >= s_stations[s_stations.size() - 1]:
		return h_stations[h_stations.size() - 1]

	for i in range(s_stations.size() - 1):
		if s_val >= s_stations[i] and s_val <= s_stations[i + 1]:
			var u: float = (s_val - s_stations[i]) / maxf(s_stations[i + 1] - s_stations[i], 0.001)
			return lerpf(h_stations[i], h_stations[i + 1], smoothstep(0.0, 1.0, u))
	return h_stations[0]


func _road_height_at_s(s: float) -> float:
	for i in range(_plan_segs.size()):
		var s0: float = _plan_s0[i]
		var sl: float = _plan_len[i]
		if s <= s0 + sl or i == _plan_segs.size() - 1:
			var frac: float = clampf((s - s0) / maxf(sl, 0.001), 0.0, 1.0)
			return _road_height_at(i, frac)
	return 50.0


func _sample_road() -> void:
	_road_samples.clear()
	_cell_buckets.clear()

	var cur_s: float = 0.0
	while cur_s <= _total_track_len:
		var pos_info: Dictionary = _plan_at(cur_s)
		var p2: Vector2 = pos_info["p"]
		var th: float = pos_info["th"]
		var h: float = _road_height_at_s(cur_s)
		var samp: Dictionary = {"p": p2, "s": cur_s, "th": th, "h": h}
		var s_idx: int = _road_samples.size()
		_road_samples.append(samp)

		# Add to cell buckets
		var cx: int = int(floor(p2.x / CELL))
		var cz: int = int(floor(p2.y / CELL))
		for dx in [-1, 0, 1]:
			for dz in [-1, 0, 1]:
				var cell_key := Vector2i(cx + dx, cz + dz)
				if not _cell_buckets.has(cell_key):
					_cell_buckets[cell_key] = []
				_cell_buckets[cell_key].append(s_idx)

		cur_s += SAMPLE_STEP


func _plan_at(s: float) -> Dictionary:
	s = clampf(s, 0.0, _total_track_len)
	for i in range(_plan_segs.size()):
		var s0: float = _plan_s0[i]
		var sl: float = _plan_len[i]
		if s <= s0 + sl or i == _plan_segs.size() - 1:
			var ds: float = s - s0
			var seg: Dictionary = _plan_segs[i]
			var kind: String = seg["kind"]
			if kind == "S":
				var start: Vector2 = seg["start"]
				var th: float = seg["heading"]
				return {"p": start + Vector2(cos(th), sin(th)) * ds, "th": th}
			else:
				var c: Vector2 = seg["c"]
				var r: float = seg["r"]
				var sign: float = seg["sign"]
				var th0: float = seg["heading"]
				var cur_th: float = th0 + sign * (ds / r)
				var p := c + Vector2(cos(cur_th - sign * PI * 0.5), sin(cur_th - sign * PI * 0.5)) * r
				return {"p": p, "th": cur_th}
	return {"p": PLAN_START, "th": PLAN_HEADING}


func _spot(s: float, lat: float, lift := 0.0) -> Dictionary:
	var pa: Dictionary = _plan_at(s)
	var p2: Vector2 = pa["p"]
	var th: float = pa["th"]
	var r2 := Vector2(-sin(th), cos(th))
	var f2 := Vector2(cos(th), sin(th))
	var pos := Vector3(p2.x + r2.x * lat, _road_height_at_s(s) + lift, p2.y + r2.y * lat)
	var fwd := Vector3(f2.x, 0.0, f2.y)
	return {
		"pos": pos,
		"yaw": rad_to_deg(atan2(-fwd.x, -fwd.z)),
		"fwd": fwd,
		"right": Vector3(r2.x, 0.0, r2.y)
	}


func _build_track_path(parent: Node) -> Path3D:
	var path := Path3D.new()
	path.name = "TrackPath"
	var curve := Curve3D.new()

	var step := 12.0
	var cur_s: float = 0.0
	while cur_s <= _total_track_len:
		var sp: Dictionary = _spot(cur_s, 0.0, 0.0)
		curve.add_point(sp["pos"])
		cur_s += step
	if cur_s < _total_track_len + step * 0.5:
		var sp_end: Dictionary = _spot(_total_track_len, 0.0, 0.0)
		curve.add_point(sp_end["pos"])

	path.curve = curve
	parent.add_child(path)
	return path


# ======================================================================================
#  Terrain Grid & Elevation
# ======================================================================================

func _build_grid() -> void:
	_grid_x.clear()
	_grid_z.clear()

	# Coarse outer grid expanding to horizon
	var x := FINE_X.x
	var row_x := PackedFloat32Array()
	var d := FINE_STEP
	while x > OUTER_X.x:
		x -= d
		d *= COARSE_GROWTH
		row_x.append(x)
	row_x.reverse()
	for v in row_x: _grid_x.append(v)

	x = FINE_X.x
	while x <= FINE_X.y:
		_grid_x.append(x)
		x += FINE_STEP

	d = FINE_STEP
	while x < OUTER_X.y:
		d *= COARSE_GROWTH
		x += d
		_grid_x.append(x)

	# Z grid
	var z := FINE_Z.x
	var row_z := PackedFloat32Array()
	d = FINE_STEP
	while z > OUTER_Z.x:
		z -= d
		d *= COARSE_GROWTH
		row_z.append(z)
	row_z.reverse()
	for v in row_z: _grid_z.append(v)

	z = FINE_Z.x
	while z <= FINE_Z.y:
		_grid_z.append(z)
		z += FINE_STEP

	d = FINE_STEP
	while z < OUTER_Z.y:
		d *= COARSE_GROWTH
		z += d
		_grid_z.append(z)

	var total_verts: int = _grid_x.size() * _grid_z.size()
	_heights.resize(total_verts)
	_road_d.resize(total_verts)
	_vert_s.resize(total_verts)
	_vert_lat.resize(total_verts)


## Base natural terrain height: high plateau in north, giant open-pit copper caldera in south.
func _base_height(x: float, z: float) -> float:
	# Sector 1 High Plateau (z < -450): elevation ~50m to 54m with gentle desert swell
	if z < -450.0:
		var swell := sin(x * 0.008) * cos(z * 0.007) * 2.5 + sin((x + z) * 0.015) * 1.2
		return 52.0 + swell

	# Center of the giant open-pit copper mine caldera
	var pit_center := Vector2(380.0, 950.0)
	var q := Vector2(x, z) - pit_center
	var r: float = q.length()

	# Outer crater rim at R = 850m, floor at R = 180m
	if r > 850.0:
		var mesa_swell := sin(x * 0.006) * 3.0 + cos(z * 0.006) * 2.5
		return 44.0 + mesa_swell

	# Stepped open-pit mining benches:
	# Terraces stepped every 12 meters vertically down to -34m!
	var u: float = clampf((r - 180.0) / 670.0, 0.0, 1.0) # 0 at bottom, 1 at rim
	var smooth_h := lerpf(-33.0, 42.0, u)

	# Quantize into authentic horizontal excavation benches with stepped cuts
	var bench_h := 12.0
	var bench_idx: float = floor((smooth_h + 36.0) / bench_h)
	var bench_y: float = bench_idx * bench_h - 36.0
	var frac: float = (smooth_h + 36.0 - bench_idx * bench_h) / bench_h
	# Stepped shelf with steep 75% rise
	var stepped_h: float = bench_y + smoothstep(0.55, 0.95, frac) * bench_h

	# Blend stepped benches inside the active pit
	return lerpf(smooth_h, stepped_h, 0.72)


func _evaluate_terrain() -> void:
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()

	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var x: float = _grid_x[ix]
			var idx: int = iz * nx + ix

			var base_h := _base_height(x, z)

			# Find nearest road sample
			var p2 := Vector2(x, z)
			var cx: int = int(floor(x / CELL))
			var cz: int = int(floor(z / CELL))
			var cell_key := Vector2i(cx, cz)

			var best_d := 1e9
			var best_s := 0.0
			var best_lat := 0.0
			var road_h := base_h

			if _cell_buckets.has(cell_key):
				var bucket: Array = _cell_buckets[cell_key]
				for s_idx in bucket:
					var samp: Dictionary = _road_samples[s_idx]
					var sp: Vector2 = samp["p"]
					var d_val: float = p2.distance_to(sp)
					if d_val < best_d:
						best_d = d_val
						best_s = samp["s"]
						road_h = samp["h"]
						var th: float = samp["th"]
						var r2 := Vector2(-sin(th), cos(th))
						best_lat = (p2 - sp).dot(r2)

			_road_d[idx] = best_d
			_vert_s[idx] = best_s
			_vert_lat[idx] = best_lat

			# Grade terrain to road height
			if best_d <= ROAD_FLAT:
				_heights[idx] = road_h
			elif best_d < GRADE_REACH:
				var excess := best_d - ROAD_FLAT
				var cut_bound := road_h + excess * ROAD_CUT
				var fill_bound := road_h - excess * ROAD_FILL
				_heights[idx] = clampf(base_h, fill_bound, cut_bound)
			else:
				_heights[idx] = base_h


func _paved_at(s: float) -> float:
	if s < PAVED_PLATEAU_END:
		return 1.0 - smoothstep(PAVED_PLATEAU_END - 24.0, PAVED_PLATEAU_END, s)
	elif s > PAVED_DEPOT_START:
		return smoothstep(PAVED_DEPOT_START, PAVED_DEPOT_START + 30.0, s)
	return 0.0


# ======================================================================================
#  Terrain Meshes & Collision Bodies
# ======================================================================================

func _build_terrain(parent: Node) -> void:
	var nx: int = _grid_x.size()
	var nz: int = _grid_z.size()
	var total_verts := nx * nz

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()

	verts.resize(total_verts)
	normals.resize(total_verts)
	colors.resize(total_verts)
	uvs.resize(total_verts)
	uv2s.resize(total_verts)

	for iz in range(nz):
		var z: float = _grid_z[iz]
		for ix in range(nx):
			var idx: int = iz * nx + ix
			var x: float = _grid_x[ix]
			var h: float = _heights[idx]

			verts[idx] = Vector3(x, h, z)
			uvs[idx] = Vector2(x, z)

			# Fast grid normal
			var ixl: int = maxi(ix - 1, 0)
			var ixr: int = mini(ix + 1, nx - 1)
			var izd: int = maxi(iz - 1, 0)
			var izu: int = mini(iz + 1, nz - 1)
			var dhdx: float = (_heights[iz * nx + ixr] - _heights[iz * nx + ixl]) / maxf(_grid_x[ixr] - _grid_x[ixl], 0.01)
			var dhdz: float = (_heights[izu * nx + ix] - _heights[izd * nx + ix]) / maxf(_grid_z[izu] - _grid_z[izd], 0.01)
			var nrm := Vector3(-dhdx, 1.0, -dhdz).normalized()
			normals[idx] = nrm

			# canyon_ground.gdshader masks:
			# COLOR.r: rock / cliff faces
			# COLOR.g: road band
			# COLOR.b: sand / gravel
			# COLOR.a: signed lateral distance (lat / 24.0 + 0.5)
			var d_val: float = _road_d[idx]
			var rock := 1.0 - smoothstep(0.55, 0.82, nrm.y)
			var band: float = 1.0 if d_val < 22.0 else 0.0
			var sand: float = 0.7 if d_val < ROAD_FLAT + 6.0 else 0.15
			var lat_enc: float = clampf(_vert_lat[idx] / 24.0 + 0.5, 0.0, 1.0) if d_val < 30.0 else 0.5
			colors[idx] = Color(rock, band, sand, lat_enc)

			# UV2.x: track s, UV2.y: 1.0 paved asphalt, 0.0 gravel
			var s_val: float = _vert_s[idx]
			uv2s[idx] = Vector2(s_val, _paved_at(s_val))

	# Build triangle faces
	var visual_indices := PackedInt32Array()
	var body_faces: Array = []
	for _b in range(BODIES.size()):
		body_faces.append(PackedVector3Array())

	for iz in range(nz - 1):
		for ix in range(nx - 1):
			var a: int = iz * nx + ix
			var b: int = a + 1
			var c: int = a + nx
			var d: int = a + nx + 1

			# Split cell along diagonal with closer heights to prevent sawtooth artifacts
			var tris: Array
			if absf(_heights[a] - _heights[d]) <= absf(_heights[b] - _heights[c]):
				tris = [[a, b, d], [a, d, c]]
			else:
				tris = [[a, b, c], [b, d, c]]

			for tri in tris:
				var i0: int = tri[0]
				var i1: int = tri[1]
				var i2: int = tri[2]

				visual_indices.append(i0)
				visual_indices.append(i1)
				visual_indices.append(i2)

				# Which collision body
				var p0: Vector3 = verts[i0]
				var p1: Vector3 = verts[i1]
				var p2: Vector3 = verts[i2]

				var on_road := (_road_d[i0] < ROAD_COLLIDE and _road_d[i1] < ROAD_COLLIDE and _road_d[i2] < ROAD_COLLIDE)
				var b_idx := 3 # MinaGround
				if on_road:
					var pave := _paved_at(_vert_s[i0])
					b_idx = 0 if pave > 0.5 else 1 # MinaAsphaltRoad or MinaGravelRoad
				elif colors[i0].r > 0.65 or colors[i1].r > 0.65:
					b_idx = 4 # MinaRockFace

				var bf: PackedVector3Array = body_faces[b_idx]
				bf.append(p0)
				bf.append(p1)
				bf.append(p2)

	# 1. Visual Terrain Mesh
	var ground_mat := ShaderMaterial.new()
	ground_mat.shader = load("res://canyon_ground.gdshader")
	ground_mat.set_shader_parameter("road_half_width", ROAD_HALF)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_INDEX] = visual_indices

	var vis_mesh := ArrayMesh.new()
	vis_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	vis_mesh.surface_set_material(0, ground_mat)

	var mi := MeshInstance3D.new()
	mi.name = "MinaGround_Visual"
	mi.mesh = _save_baked_resource(vis_mesh, "ground_visual")
	parent.add_child(mi)

	# 2. Collision Bodies
	for b_i in range(BODIES.size()):
		var b_info: Array = BODIES[b_i]
		var b_name: String = b_info[0]
		var surf_name: String = b_info[1]
		var dust_col: Color = b_info[2]
		var f_array: PackedVector3Array = body_faces[b_i]
		if f_array.is_empty():
			continue

		var sb := StaticBody3D.new()
		sb.name = b_name
		sb.set_meta("surface", surf_name)
		if dust_col.a > 0.0:
			sb.set_meta("dust_color", dust_col)

		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(f_array)
		var col_node := CollisionShape3D.new()
		col_node.name = "CollisionShape3D"
		col_node.shape = shape
		sb.add_child(col_node)
		parent.add_child(sb)


# ======================================================================================
#  Environment & Weather
# ======================================================================================

func _build_environment(parent: Node) -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://sky_tropical_cumulus.gdshader")
	# Desert dawn sky
	sky_mat.set_shader_parameter("sky_top", Color(0.12, 0.22, 0.58))
	sky_mat.set_shader_parameter("sky_horizon", Color(0.95, 0.62, 0.38))
	sky_mat.set_shader_parameter("ground_horizon", Color(0.68, 0.45, 0.30))
	sky_mat.set_shader_parameter("ground_bottom", Color(0.32, 0.22, 0.18))
	sky_mat.set_shader_parameter("sun_tint", Color(1.0, 0.78, 0.45))
	sky_mat.set_shader_parameter("sun_disc_degrees", 1.2)
	sky_mat.set_shader_parameter("sun_glow", 0.8)
	sky_mat.set_shader_parameter("cloud_lit", Color(1.0, 0.72, 0.52))
	sky_mat.set_shader_parameter("cloud_shade", Color(0.35, 0.28, 0.36))
	sky_mat.set_shader_parameter("cloud_coverage", 0.28)
	sky.sky_material = sky_mat

	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0004
	env.fog_light_color = Color(0.72, 0.48, 0.32)
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	# Morning sun low from the south-east
	sun.rotation_degrees = Vector3(-28.0, 45.0, 0.0)
	parent.add_child(sun)


func _setup_weather(parent: Node) -> void:
	var haboob := Node3D.new()
	haboob.name = "HaboobWeather"
	haboob.set_script(load("res://HaboobWeather.gd"))
	haboob.set("sun_path", NodePath("../SunLight"))

	# Add wind audio stream player
	var wind_audio := AudioStreamPlayer.new()
	wind_audio.name = "DesertWindLoop"
	wind_audio.stream = load("res://sounds/winter_wind_loop.mp3")
	wind_audio.volume_db = -8.0
	wind_audio.autoplay = true
	parent.add_child(wind_audio)

	haboob.set("wind_audio_path", NodePath("../DesertWindLoop"))
	parent.add_child(haboob)


# ======================================================================================
#  Dressing (Dishes, Balloons, Haul Trucks, Conveyors, Floodlights, Flora)
# ======================================================================================

func _build_dressing(parent: Node) -> void:
	var dressing := Node3D.new()
	dressing.name = "MinaDressing"
	parent.add_child(dressing)

	# 1. Very Large Array Radio Dishes along Sector 1 Plateau
	var dish_mesh := MinaKit.radio_dish()
	var dishes_node := Node3D.new()
	dishes_node.name = "RadioDishes"
	dressing.add_child(dishes_node)

	var dish_stations = [
		[280.0, 32.0, 42.0, 25.0],
		[360.0, -32.0, 48.0, 30.0],
		[490.0, 34.0, 38.0, 15.0],
		[580.0, -35.0, 45.0, 28.0],
		[710.0, 36.0, 40.0, 20.0],
		[820.0, -34.0, 46.0, 35.0],
		[960.0, 38.0, 36.0, 18.0],
		[1050.0, -36.0, 44.0, 22.0],
	]
	for d_info in dish_stations:
		var s: float = d_info[0]
		var lat: float = d_info[1]
		var sp: Dictionary = _spot(s, lat, 0.0)
		var dish_inst := MeshInstance3D.new()
		dish_inst.name = "RadioDish_%.0fm" % s
		dish_inst.mesh = dish_mesh
		dish_inst.position = sp["pos"]
		dish_inst.rotation_degrees = Vector3(0.0, sp["yaw"] + (25.0 if lat > 0 else -25.0), 0.0)
		dishes_node.add_child(dish_inst)

	# 2. Hot Air Balloons: 4 tethered on launch apron, 8 airborne floating across the stage
	var balloons_node := Node3D.new()
	balloons_node.name = "HotAirBalloons"
	dressing.add_child(balloons_node)

	# 4 Tethered on Ground at Launch Field
	var tether_spots = [
		[120.0, 45.0, 3.8, 0],
		[160.0, -42.0, 3.8, 1],
		[220.0, 52.0, 3.8, 2],
		[250.0, -48.0, 3.8, 0],
	]
	for b_info in tether_spots:
		var s: float = b_info[0]
		var lat: float = b_info[1]
		var alt: float = b_info[2]
		var style: int = b_info[3]
		var sp: Dictionary = _spot(s, lat, alt)
		var b_inst := MeshInstance3D.new()
		b_inst.name = "TetheredBalloon_%.0fm" % s
		b_inst.mesh = MinaKit.hot_air_balloon(style, true)
		b_inst.position = sp["pos"]
		balloons_node.add_child(b_inst)

	# 8 Airborne Drifting Balloons at varying altitudes
	var air_spots = [
		[450.0, 65.0, 35.0, 1],
		[750.0, -75.0, 48.0, 2],
		[1100.0, 85.0, 62.0, 0],
		[1500.0, -95.0, 75.0, 1],
		[2000.0, 110.0, 55.0, 2],
		[2600.0, -120.0, 68.0, 0],
		[3200.0, 95.0, 80.0, 1],
		[3800.0, -110.0, 72.0, 2],
	]
	for b_info in air_spots:
		var s: float = b_info[0]
		var lat: float = b_info[1]
		var alt: float = b_info[2]
		var style: int = b_info[3]
		var sp: Dictionary = _spot(s, lat, alt)
		var b_inst := MeshInstance3D.new()
		b_inst.name = "AirborneBalloon_%.0fm" % s
		b_inst.mesh = MinaKit.hot_air_balloon(style, true)
		b_inst.position = sp["pos"]
		balloons_node.add_child(b_inst)

	# 3. Colossal Mining Haul Trucks (CAT 797F) in Open-Pit Mine
	var truck_mesh := MinaKit.haul_truck()
	var trucks_node := Node3D.new()
	trucks_node.name = "HaulTrucks"
	dressing.add_child(trucks_node)

	var truck_spots = [
		[2450.0, 13.5, 0.0, -12.0],  # Bench 1 outside shoulder
		[2650.0, -13.0, 0.0, 185.0], # Bench 1 inside chicane
		[2850.0, 14.0, 0.0, -8.0],   # Ramp descent
		[3050.0, -13.5, 0.0, 175.0], # Bench 2 outside hairpin
		[3250.0, 14.2, 0.0, 5.0],    # Bench 2 straight
		[3500.0, -13.8, 0.0, 180.0], # Bench 3
		[4150.0, 16.0, 0.0, -25.0],  # Depot service bay
		[4350.0, -16.5, 0.0, 90.0],  # Depot unloading dock
	]
	for t_info in truck_spots:
		var s: float = t_info[0]
		var lat: float = t_info[1]
		var yaw_rel: float = t_info[3]
		var sp: Dictionary = _spot(s, lat, 0.0)
		var t_inst := MeshInstance3D.new()
		t_inst.name = "HaulTruck_%.0fm" % s
		t_inst.mesh = truck_mesh
		t_inst.position = sp["pos"]
		t_inst.rotation_degrees = Vector3(0.0, sp["yaw"] + yaw_rel, 0.0)
		trucks_node.add_child(t_inst)

	# 4. Overhead Ore Conveyor Bridges in Sector 4
	var conveyor_mesh := MinaKit.conveyor_bridge(36.0, 9.5)
	var conveyors_node := Node3D.new()
	conveyors_node.name = "ConveyorBridges"
	dressing.add_child(conveyors_node)

	for bridge_s in [3510.0, 3630.0]:
		var sp: Dictionary = _spot(bridge_s, 0.0, 0.0)
		var c_inst := MeshInstance3D.new()
		c_inst.name = "ConveyorBridge_%.0fm" % bridge_s
		c_inst.mesh = conveyor_mesh
		c_inst.position = sp["pos"]
		c_inst.rotation_degrees = Vector3(0.0, sp["yaw"] + 90.0, 0.0)
		conveyors_node.add_child(c_inst)

	# 5. Mobile Floodlight Towers illuminating Quarry Benches
	var tower_mesh := MinaKit.floodlight_tower()
	var towers_node := Node3D.new()
	towers_node.name = "FloodlightTowers"
	dressing.add_child(towers_node)

	var tower_spots = [
		[2500.0, 16.0, -35.0],
		[2900.0, -16.0, 145.0],
		[3300.0, 16.5, -45.0],
		[3700.0, -16.0, 135.0],
		[4100.0, 18.0, -90.0],
		[4450.0, -18.0, 90.0],
	]
	for tw in tower_spots:
		var s: float = tw[0]
		var lat: float = tw[1]
		var yaw_rel: float = tw[2]
		var sp: Dictionary = _spot(s, lat, 0.0)
		var tw_inst := MeshInstance3D.new()
		tw_inst.name = "FloodlightTower_%.0fm" % s
		tw_inst.mesh = tower_mesh
		tw_inst.position = sp["pos"]
		tw_inst.rotation_degrees = Vector3(0.0, sp["yaw"] + yaw_rel, 0.0)
		towers_node.add_child(tw_inst)

	# 6. Desert Cacti & Sagebrush on High Plateau
	_build_plateau_flora(dressing)


func _build_plateau_flora(parent: Node) -> void:
	var flora_node := Node3D.new()
	flora_node.name = "PlateauFlora"
	parent.add_child(flora_node)

	# Saguaro Cacti along Plateau straightaways
	var ckit := CactusKit.new()
	var c_mesh: ArrayMesh = ckit.build("saguaro", 0, 0, ckit.material())
	var cur_s: float = 60.0
	while cur_s < 1050.0:
		for side in [-18.0, 18.0]:
			var sp: Dictionary = _spot(cur_s, side + sin(cur_s * 0.3) * 4.0, 0.0)
			var mi := MeshInstance3D.new()
			mi.name = "Cactus_%.0fm" % cur_s
			mi.mesh = c_mesh
			mi.position = sp["pos"]
			mi.rotation_degrees = Vector3(0.0, randf_range(0.0, 360.0), 0.0)
			flora_node.add_child(mi)
		cur_s += 45.0


# ======================================================================================
#  Gameplay & Checkpoints
# ======================================================================================

func _place_gameplay(parent: Node, _track_path: Path3D) -> void:
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")
	var boost_scene: PackedScene = load("res://BoostPad.tscn")

	# 1. StartLine Gate at s = 25m
	var start_s := 25.0
	var sp_start: Dictionary = _spot(start_s, 0.0, 0.06)
	var start_line = gate_scene.instantiate()
	start_line.name = "StartLine"
	start_line.position = sp_start["pos"]
	start_line.rotation_degrees = Vector3(0, sp_start["yaw"], 0)
	start_line.set("is_finish_line", false)
	parent.add_child(start_line)

	# 6 Spawn points behind StartLine
	var spawn_container := Node3D.new()
	spawn_container.name = "SpawnPoints"
	start_line.add_child(spawn_container)

	var grid_coords = [
		Vector3(-2.8, 0.05, 5.0), Vector3(2.8, 0.05, 5.0),
		Vector3(-2.8, 0.05, 12.0), Vector3(2.8, 0.05, 12.0),
		Vector3(-2.8, 0.05, 19.0), Vector3(2.8, 0.05, 19.0),
	]
	for i in range(grid_coords.size()):
		var sp_m := Marker3D.new()
		sp_m.name = "Spawn%d" % (i + 1)
		sp_m.position = grid_coords[i]
		sp_m.gizmo_extents = 0.3
		spawn_container.add_child(sp_m)
		if spawn_scene:
			var si = spawn_scene.instantiate()
			si.name = "SpawnIndicator"
			sp_m.add_child(si)

	# 2. Checkpoints evenly spaced every ~340m
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	parent.add_child(checkpoints_container)

	var cp_interval := 340.0
	var cp_s: float = start_s + cp_interval
	var cp_idx := 1
	while cp_s < _total_track_len - 150.0:
		var c_spot: Dictionary = _spot(cp_s, 0.0, 0.08)
		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % cp_idx
		gate.position = c_spot["pos"]
		gate.rotation_degrees = Vector3(0, c_spot["yaw"], 0)
		checkpoints_container.add_child(gate)
		cp_s += cp_interval
		cp_idx += 1

	# 3. FinishLine Gate at s = total_len - 25m
	var finish_s := _total_track_len - 25.0
	var sp_finish: Dictionary = _spot(finish_s, 0.0, 0.06)
	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = sp_finish["pos"]
	finish_line.rotation_degrees = Vector3(0, sp_finish["yaw"], 0)
	finish_line.set("is_finish_line", true)
	parent.add_child(finish_line)

	# 4. Strategic Boost Pads
	if boost_scene:
		var boost_spots = [
			[240.0, 0.0],   # Start straight
			[1350.0, 0.0],  # Approaching rim straight
			[2800.0, 0.0],  # Mine ramp descent
			[4150.0, 0.0],  # Final depot sprint
		]
		for b_pt in boost_spots:
			var bs: float = b_pt[0]
			var blat: float = b_pt[1]
			var b_spot: Dictionary = _spot(bs, blat, 0.04)
			var pad = boost_scene.instantiate()
			pad.position = b_spot["pos"]
			pad.rotation_degrees = Vector3(0, b_spot["yaw"], 0)
			parent.add_child(pad)


func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	for child in node.get_children():
		child.owner = new_owner
		_set_owner_recursive(child, new_owner)


func _save_baked_resource(res: Resource, res_name: String) -> Resource:
	var path := "res://generated/" + RES_PREFIX + res_name + ".res"
	res.take_over_path(path)
	ResourceSaver.save(res, path)
	return load(path)
