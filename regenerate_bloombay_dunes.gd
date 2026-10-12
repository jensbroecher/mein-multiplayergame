# regenerate_bloombay_dunes.gd
# Builds BloombayDunesLevel.tscn:
# Coastal Grand Prix circuit featuring a high-speed section along the beach with rolling surf waves,
# a technical climb through wind-sculpted sand dunes, a big dune-crest jump, and a fast beachfront straight.
extends Node

func _ready() -> void:
	print("=== Bloombay Dunes Grand Prix Level Generation ===")
	print("Building coastal dunes & beach circuit with rolling waves. Please wait...")

	var level_scene := Node3D.new()
	level_scene.name = "BloombayDunesLevel"

	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)

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

	# 1. Environment & Lighting (Tropical coastal sun & azure sky)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.58, 0.95)
	sky_mat.sky_horizon_color = Color(0.72, 0.86, 0.96)
	# Below the horizon is open sea.
	sky_mat.ground_bottom_color = Color(0.04, 0.17, 0.28)
	sky_mat.ground_horizon_color = Color(0.62, 0.76, 0.86)
	sky_mat.sun_angle_max = 32.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.90, 0.95, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.20
	# Sea haze: softens the far ocean into the horizon.
	env.fog_enabled = true
	env.fog_light_color = Color(0.70, 0.82, 0.92)
	env.fog_density = 0.0006
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.35
	env_node.environment = env
	level_scene.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-38.0, 55.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 500.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	level_scene.add_child(sun)

	# 2. TrackPath & Curve3D (~1700m coastal & roller-coaster dunes circuit)
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	var curve_pts = [
		# in, out, pos
		# --- SECTOR 1: BEACHFRONT SURF & START/FINISH STRAIGHT (X < -24.0, pure beach sand, offroad) ---
		# 0: Start / Finish Line (Heading North, facing -Z)
		[Vector3(0, 0, 22), Vector3(0, 0, -22), Vector3(-42.0, 0.70, 160.0)],
		# 1: Coastal beach straight heading North
		[Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(-44.0, 0.60, 70.0)],

		# --- SECTOR 2: ALONG THE OCEAN WATER & BREAKING SURF WAVES (X < -24.0) ---
		# 2: Deep shoreline curve right alongside rolling surf waves
		[Vector3(1, 0, 25), Vector3(-1, 0, -25), Vector3(-46.0, 0.55, -20.0)],
		# 3: Ocean surf shoreline straight with majestic waves rolling in from the west
		[Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(-47.0, 0.50, -110.0)],
		# 4: North tidal beach straight
		[Vector3(-2, 0, 25), Vector3(2, 0, -25), Vector3(-45.0, 0.60, -200.0)],
		# 5: North beach sweeping right turn apex
		[Vector3(-8, 0, 20), Vector3(8, 0.2, -20), Vector3(-36.0, 0.85, -270.0)],

		# --- SECTOR 3: INLAND DUNE CLIMB & ROLLER-COASTER PLUNGE 1 (Road starts at X >= -24.0) ---
		# 6: Crossing onto inland asphalt road into the dune canyon
		[Vector3(-14, -0.2, 10), Vector3(14, 0.3, -10), Vector3(-15.0, 1.80, -305.0)],
		# 7: Steep climb through golden sand dune bluffs
		[Vector3(-16, -0.6, -4), Vector3(16, 0.6, 4), Vector3(25.0, 6.50, -315.0)],
		# 8: Ascending the high north dune ridge
		[Vector3(-18, -1.0, -8), Vector3(18, 1.0, 8), Vector3(80.0, 15.0, -295.0)],
		# 9: DUNE CREST 1 — Summit with ocean vista (+24.0m)
		[Vector3(-16, -0.8, -14), Vector3(16, 0.8, 14), Vector3(135.0, 24.0, -250.0)],
		# 10: Roller-coaster plunge down the dune ridge slope
		[Vector3(-12, 1.0, -16), Vector3(12, -1.0, 16), Vector3(175.0, 16.0, -185.0)],
		# 11: DUNE VALLEY 1 — Compression dip into deep dune bowl (+7.0m)
		[Vector3(-6, 1.2, -18), Vector3(6, -1.2, 18), Vector3(195.0, 7.0, -115.0)],

		# --- SECTOR 4: SECOND CLIMB TO SUMMIT & BIG AIR CREST JUMP ---
		# 12: Powering up the eastern dune wall
		[Vector3(-4, -1.2, -18), Vector3(4, 1.2, 18), Vector3(215.0, 17.5, -45.0)],
		# 13: DUNE CREST 2 — High summit sweeping hairpin (+27.5m)
		[Vector3(-8, -0.8, -16), Vector3(8, 0.8, 16), Vector3(205.0, 27.5, 35.0)],
		# 14: Jump Takeoff Ramp on high ridge (+26.0m)
		[Vector3(-4, -0.4, -12), Vector3(4, 1.8, 12), Vector3(180.0, 26.0, 95.0)],
		# 15: Jump Landing slope into dune amphitheater (+13.5m)
		[Vector3(-4, 1.8, -12), Vector3(4, -0.8, 12), Vector3(155.0, 13.5, 145.0)],

		# --- SECTOR 5: DUNE BASIN CHICANE & THIRD DUNE CREST ---
		# 16: DUNE BASIN 2 — Low basin drift sweep (+6.5m)
		[Vector3(6, 1.0, -14), Vector3(-6, -0.6, 14), Vector3(120.0, 6.5, 185.0)],
		# 17: Carving right around golden dune pillars
		[Vector3(12, -0.4, -14), Vector3(-12, 0.4, 14), Vector3(90.0, 11.0, 240.0)],
		# 18: DUNE CREST 3 — Overlook ridge (+21.0m)
		[Vector3(-10, -1.0, -14), Vector3(10, 1.0, 14), Vector3(125.0, 21.0, 285.0)],
		# 19: High dune crest sweeping towards coastal horizon (+19.5m)
		[Vector3(-8, 0.2, -14), Vector3(8, -0.2, 14), Vector3(150.0, 19.5, 340.0)],

		# --- SECTOR 6: DOWNHILL ROLLER-COASTER RETURN TO BEACH ---
		# 20: Sweeping downhill curve carving through dune pass
		[Vector3(14, 1.0, -8), Vector3(-14, -1.0, 8), Vector3(100.0, 12.0, 375.0)],
		# 21: Plunging descent through dune valley cut
		[Vector3(18, 1.0, 2), Vector3(-18, -1.0, -2), Vector3(35.0, 5.5, 360.0)],
		# 22: Coastal approach curve re-entering beach (X < -24.0)
		[Vector3(16, 0.4, 8), Vector3(-16, -0.4, -8), Vector3(-10.0, 2.0, 310.0)],
		# 23: Swooping onto beach sand
		[Vector3(10, 0.2, 14), Vector3(-6, -0.2, -14), Vector3(-36.0, 0.85, 245.0)],
		# 24: Straightening onto finish straight
		[Vector3(4, 0.05, 14), Vector3(-2, -0.05, -14), Vector3(-40.0, 0.70, 205.0)],
		# 25: Closing back to Point 0
		[Vector3(0, 0, 22), Vector3(0, 0, -22), Vector3(-42.0, 0.65, 160.0)]
	]

	for pt in curve_pts:
		curve.add_point(pt[2], pt[0], pt[1])

	track_path.curve = curve
	level_scene.add_child(track_path)

	# 3. TerrainGenerator Setup
	var tg := Node3D.new()
	tg.name = "TerrainGenerator"
	var tg_script: Script = load("res://TerrainGenerator.gd")
	tg.set_script(tg_script)
	tg.set("level_prefix", "bloombay_dunes")
	tg.set("track_layout_type", 0)
	tg.set("terrain_resolution", 420)
	tg.set("terrain_size", Vector2(950.0, 950.0))
	tg.set("hill_height", 14.0)
	tg.set("road_width", 15.0)
	tg.set("curb_outer_width", 17.0)
	tg.set("road_y_offset", 0.06)
	tg.set("curb_y_offset", 0.06)
	tg.set("terrain_recession_collision", 0.12)
	tg.set("terrain_recession_visual", 0.18)
	tg.set("no_water", false)
	tg.set("no_grass", true)
	tg.set("terrain_grass_count", 0)

	var sand_tex: Texture2D = load("res://materials/sand.png") as Texture2D
	var sand_norm: Texture2D = load("res://materials/sand_normal.png") as Texture2D
	var asphalt_tex: Texture2D = load("res://materials/asphalt.png") as Texture2D
	if sand_tex:
		var sand_mat := StandardMaterial3D.new()
		sand_mat.albedo_texture = sand_tex
		sand_mat.albedo_color = Color(1.0, 0.96, 0.88)
		sand_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
		sand_mat.uv1_triplanar = true
		sand_mat.roughness = 0.92
		if sand_norm:
			sand_mat.normal_enabled = true
			sand_mat.normal_texture = sand_norm
			sand_mat.normal_scale = 0.85
		tg.set("grass_material", sand_mat)

	if asphalt_tex:
		var road_mat := StandardMaterial3D.new()
		road_mat.albedo_texture = asphalt_tex
		road_mat.albedo_color = Color(0.92, 0.92, 0.92)
		road_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
		road_mat.roughness = 0.75
		tg.set("road_material", road_mat)

	level_scene.add_child(tg)
	tg.set("track_path", track_path)
	tg.call("generate_world")
	_build_ocean(tg)
	_build_seafront(level_scene, tg, curve)

	# 4. Finish Line & Starting Grid
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")

	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = Vector3(-42.0, 0.76, 160.0)
	finish_line.rotation_degrees = Vector3(0, 0, 0)
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

	# 5. Checkpoints Container (5 milestones + finish line = 6 gates)
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)

	var cp_defs = [
		# name, dist_ratio
		["Checkpoint_1", 0.16],  # Tidal beach straight (along the rolling surf)
		["Checkpoint_2", 0.33],  # Turn inland into dune canyon climb
		["Checkpoint_3", 0.50],  # Dune summit 1 & roller-coaster plunge
		["Checkpoint_4", 0.67],  # Ridge jump landing slope into amphitheater
		["Checkpoint_5", 0.83]   # Third dune crest & coastal descent
	]

	var track_len: float = curve.get_baked_length()
	for cp_info in cp_defs:
		var dist_along := track_len * float(cp_info[1])
		var cp_pos := curve.sample_baked(dist_along)
		var next_pos := curve.sample_baked(minf(track_len, dist_along + 1.5))
		var forward := (next_pos - cp_pos).normalized()
		var rot_y := rad_to_deg(atan2(-forward.x, -forward.z))

		var gate = gate_scene.instantiate()
		gate.name = str(cp_info[0])
		gate.position = cp_pos + Vector3(0, 0.1, 0)
		gate.rotation_degrees = Vector3(0, rot_y, 0)
		checkpoints_container.add_child(gate)

	# 6. Boost Pads
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)

	if boost_scene:
		var bp_defs = [
			# pos, rot_y_deg
			[Vector3(-47.0, 0.55, -80.0), 0.0],    # Beachfront tidal straight speed boost
			[Vector3(35.0, 7.80, -310.0), -70.0],  # Dune climb launcher
			[Vector3(200.0, 9.50, -90.0), -20.0],  # Valley plunge exit into ridge 2
			[Vector3(180.0, 26.05, 95.0), -22.0],  # Takeoff ramp big jump launch boost
			[Vector3(145.0, 20.20, 320.0), 35.0]   # Basin exit towards coastal descent
		]
		for i in range(bp_defs.size()):
			var bp = boost_scene.instantiate()
			bp.name = "BoostPad_%d" % (i + 1)
			bp.position = bp_defs[i][0]
			bp.rotation_degrees = Vector3(0, bp_defs[i][1], 0)
			boost_container.add_child(bp)

	# 7. Scenery Props & Vegetation Containers (empty so user can add custom trees/plants)
	var veg_container := Node3D.new()
	veg_container.name = "Vegetation"
	level_scene.add_child(veg_container)

	# 8. Additional Containers
	for c_name in ["Props", "AlternativePaths", "Environment"]:
		var c := Node3D.new()
		c.name = c_name
		level_scene.add_child(c)

	# 9. Setup Level script connections
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()

	# 10. Set Scene Owners Recursively
	_set_owner_recursive(level_scene, level_scene)

	# 11. Save PackedScene
	remove_child(level_scene)
	var target_path := "res://levels/BloombayDunesLevel.tscn"
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack BloombayDunesLevel.tscn: %d" % pack_err)
		get_tree().quit(1)
		return

	var save_err = ResourceSaver.save(packed_scene, target_path)
	if save_err != OK:
		push_error("Failed to save BloombayDunesLevel.tscn: %d" % save_err)
		get_tree().quit(1)
		return

	print("Successfully generated and saved res://levels/BloombayDunesLevel.tscn!")
	get_tree().quit(0)


# --- Ocean ---------------------------------------------------------------------------------------
# beach_water.gdshader draws the surf from a baked shore field (see the shader header). The field holds
# one texel per terrain vertex from SHORE_X0 to SHORE_X1. The water mesh is a grid whose lines fall on
# the terrain grid: thirds of a cell across the surf zone, whole cells over the beach and the shelf,
# then wider out to the horizon. It is cut into chunks so cameras only draw what they see.

const SEA_PERIOD := 7.5
const SEA_C_DEEP := 8.0
const SHORE_X0 := -330.0
const SHORE_X1 := 5.0
const SURF_X0 := -125.0
const SURF_X1 := -38.0
const OCEAN_REACH := 4000.0
const OCEAN_CHUNK_ROWS := 60


func _build_ocean(tg: Node3D) -> void:
	var old := tg.get_node_or_null("BloombayWater")
	if old:
		old.free()
	var res: int = int(tg.get("terrain_resolution"))
	var size: Vector2 = tg.get("terrain_size")
	var step: float = size.x / float(res)
	var start: float = -size.x * 0.5

	var field: Dictionary = _bake_shore_field(tg, res, step, start)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://beach_water.gdshader")
	mat.set_shader_parameter("shore_tex", field.texture)
	mat.set_shader_parameter("shore_origin", field.origin)
	mat.set_shader_parameter("shore_step", step)
	mat.set_shader_parameter("shore_size", field.size)
	mat.set_shader_parameter("period", SEA_PERIOD)
	mat.set_shader_parameter("c_deep", SEA_C_DEEP)
	mat.set_shader_parameter("foam_tex", _foam_texture())
	mat.set_shader_parameter("ripple_tex", _ripple_texture())

	var water := Node3D.new()
	water.name = "BloombayWater"
	water.set_meta("water_surface_y", 0.0)
	water.set_meta("water_bounds_min", Vector2(-OCEAN_REACH, -OCEAN_REACH))
	water.set_meta("water_bounds_max", Vector2(OCEAN_REACH, OCEAN_REACH))
	tg.add_child(water)

	# Column x positions: snapped to the terrain grid so the swash sheet lies parallel to the sand.
	var xs := PackedFloat32Array()
	var col_groups: Array[int] = []
	var x_mid: float = start + ceil((SHORE_X0 - start) / step) * step
	var x_surf: float = start + floor((SURF_X0 - start) / step) * step
	var x_beach: float = start + ceil((SURF_X1 - start) / step) * step
	var x_shore_end: float = start + floor((SHORE_X1 - start) / step) * step
	var far_west := _geometric_run(x_mid, -OCEAN_REACH, step * 2.0)
	far_west.reverse()
	xs.append_array(far_west)
	col_groups.append(xs.size() - 1)
	var x := x_mid
	while x < x_surf - 0.01:
		xs.append(x)
		x += step
	col_groups.append(xs.size() - 1)
	x = x_surf
	while x < x_beach - 0.01:
		xs.append(x)
		x += step / 3.0
	col_groups.append(xs.size() - 1)
	x = x_beach
	while x < x_shore_end + 0.01:
		xs.append(x)
		x += step
	x = xs[xs.size() - 1]
	while x < size.x * 0.5 + 5.0:
		x += 10.0
		xs.append(x)
	xs.append_array(_geometric_run(x, OCEAN_REACH, 20.0))
	col_groups.append(xs.size() - 1)

	var zs := PackedFloat32Array()
	var far_south := _geometric_run(start, -OCEAN_REACH, step * 2.0)
	far_south.reverse()
	zs.append_array(far_south)
	for r in range(res + 1):
		zs.append(start + r * step)
	zs.append_array(_geometric_run(-start, OCEAN_REACH, step * 2.0))

	var c0 := 0
	var chunk := 0
	for c1 in col_groups:
		var r0 := 0
		while r0 < zs.size() - 1:
			var r1: int = mini(r0 + OCEAN_CHUNK_ROWS, zs.size() - 1)
			var mi := MeshInstance3D.new()
			mi.name = "Ocean_%d" % chunk
			mi.mesh = tg.call("_save_resource", _ocean_grid(xs, zs, c0, c1, r0, r1), "ocean_%d" % chunk)
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			water.add_child(mi)
			chunk += 1
			r0 = r1
		c0 = c1
	print("Ocean: %d x %d grid in %d chunks" % [xs.size(), zs.size(), chunk])


## Positions from `from` (exclusive) to `to`, spacing starting at `first` and growing 30% a step.
func _geometric_run(from: float, to: float, first: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var dir := signf(to - from)
	var gap := first
	var v := from
	while absf(to - v) > gap * 0.5:
		v += dir * gap
		if (to - v) * dir < 0.0:
			v = to
		out.append(v)
		gap *= 1.3
	if out.is_empty() or out[out.size() - 1] != to:
		out.append(to)
	return out


func _ocean_grid(xs: PackedFloat32Array, zs: PackedFloat32Array, c0: int, c1: int, r0: int, r1: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var idx := PackedInt32Array()
	var w := c1 - c0 + 1
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			verts.append(Vector3(xs[c], 0.0, zs[r]))
			normals.append(Vector3.UP)
	for r in range(r1 - r0):
		for c in range(w - 1):
			var i := r * w + c
			idx.append_array([i, i + 1, i + w, i + 1, i + w + 1, i + w])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Waves lift, drop and lean the surface; the swash sheet climbs the beach.
	var lo := Vector3(xs[c0] - 2.0, -4.0, zs[r0] - 2.0)
	var hi := Vector3(xs[c1] + 2.0, 4.0, zs[r1] + 2.0)
	mesh.custom_aabb = AABB(lo, hi - lo)
	return mesh


## Shore field texels (see beach_water.gdshader): ground height, wave travel time to the waterline,
## surf weight, shallowest depth seaward along the row.
func _bake_shore_field(tg: Node3D, res: int, step: float, start: float) -> Dictionary:
	var heights: PackedFloat32Array = tg.get("_visual_heights")
	var stride := res + 1
	var col0 := int(ceil((SHORE_X0 - start) / step))
	var col1 := int(floor((SHORE_X1 - start) / step))
	var w := col1 - col0 + 1
	var h := stride
	var n := w * h
	var ground := PackedFloat32Array()
	ground.resize(n)
	for r in range(h):
		for c in range(w):
			ground[r * w + c] = heights[r * stride + col0 + c]

	# Travel time: eikonal |grad T| = 1/c with c = sqrt(g*depth), solved by fast sweeping from the
	# waterline (land is T = 0; water next to land starts at its share of the cell to the waterline).
	var big := 1.0e9
	var tt := PackedFloat32Array()
	tt.resize(n)
	var slow := PackedFloat32Array()
	slow.resize(n)
	var fixed := PackedByteArray()
	fixed.resize(n)
	for i in range(n):
		var depth: float = maxf(-ground[i], 0.0)
		slow[i] = 1.0 / minf(sqrt(9.8 * maxf(depth, 0.1)), SEA_C_DEEP)
		if ground[i] >= 0.0:
			tt[i] = 0.0
			fixed[i] = 1
		else:
			tt[i] = big
	for r in range(h):
		for c in range(w):
			var i := r * w + c
			if fixed[i] == 1:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var cc: int = c + o.x
				var rr: int = r + o.y
				if cc < 0 or cc >= w or rr < 0 or rr >= h:
					continue
				var gl: float = ground[rr * w + cc]
				if gl >= 0.0:
					var frac: float = -ground[i] / (gl - ground[i])
					tt[i] = minf(tt[i], frac * step * slow[i])
	for _round in range(3):
		for sweep in range(4):
			var r_from := 0 if sweep < 2 else h - 1
			var r_to := h if sweep < 2 else -1
			var r_dir := 1 if sweep < 2 else -1
			var c_from := 0 if sweep % 2 == 0 else w - 1
			var c_to := w if sweep % 2 == 0 else -1
			var c_dir := 1 if sweep % 2 == 0 else -1
			var r := r_from
			while r != r_to:
				var c := c_from
				while c != c_to:
					var i := r * w + c
					if fixed[i] == 0:
						var a: float = minf(tt[i - 1] if c > 0 else big, tt[i + 1] if c < w - 1 else big)
						var b: float = minf(tt[i - w] if r > 0 else big, tt[i + w] if r < h - 1 else big)
						var f: float = slow[i] * step
						var t_new: float
						if absf(a - b) >= f:
							t_new = minf(a, b) + f
						else:
							t_new = (a + b + sqrt(2.0 * f * f - (a - b) * (a - b))) * 0.5
						if t_new < tt[i]:
							tt[i] = t_new
					c += c_dir
				r += r_dir

	var img := Image.create(w, h, false, Image.FORMAT_RGBAH)
	for r in range(h):
		var shallowest := 1000.0
		for c in range(w):
			var i := r * w + c
			var px: float = start + (col0 + c) * step
			shallowest = minf(shallowest, maxf(-ground[i], 0.0))
			var weight: float = 1.0 - smoothstep(-25.0, -5.0, px)
			var tv: float = tt[i] if tt[i] < big * 0.5 else 0.0
			img.set_pixel(c, r, Color(ground[i], tv, weight, shallowest))
	var tex := ImageTexture.create_from_image(img)
	return {
		"texture": tg.call("_save_resource", tex, "shore_field"),
		"origin": Vector2(start + col0 * step, start),
		"size": Vector2(w, h),
	}


func _foam_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.seed = 7
	noise.frequency = 0.035
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.invert = true
	tex.noise = noise
	return tex


func _ripple_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = 42
	noise.frequency = 0.02
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.as_normal_map = true
	tex.bump_strength = 6.0
	tex.noise = noise
	return tex


# --- Seafront structures ---------------------------------------------------------------------------
# Everything lives under "Seafront" (not "Props"/"Environment": Level.gd bakes trimesh colliders
# under those). Each structure is one mesh with a surface per material, plus simple box/cylinder
# collision where a cart can reach it. _verify_seafront_clear() checks every footprint against the
# racing line.

const TRACK_HALF := 7.5
const CLEAR_BUILDING := 5.0   # metres past the track edge for anything solid
const CLEAR_DECOR := 3.0      # umbrellas, loungers, the fence

const HUT_COLOURS := [Color(0.95, 0.52, 0.45), Color(0.55, 0.85, 0.72), Color(0.52, 0.74, 0.95),
		Color(0.98, 0.86, 0.45), Color(0.78, 0.66, 0.92), Color(0.35, 0.78, 0.80)]
const WHITE := Color(0.95, 0.94, 0.90)
const WOOD := Color(0.62, 0.48, 0.34)
const OLD_WOOD := Color(0.48, 0.42, 0.36)

var _tg: Node3D
var _curve: Curve3D
var _footprints: Array = []   # [name, centre Vector2, radius, clearance]
var _materials: Dictionary = {}


func _build_seafront(level: Node3D, tg: Node3D, curve: Curve3D) -> void:
	_tg = tg
	_curve = curve
	var root := Node3D.new()
	root.name = "Seafront"
	level.add_child(root)
	_build_grandstand(root)
	_build_beach_huts(root)
	_build_pier(root)
	_build_lifeguard_tower(root, "LifeguardTowerNorth", Vector3(-56.0, 0.0, -340.0), 0.0)
	_build_lifeguard_tower(root, "LifeguardTowerMid", Vector3(-63.5, 0.0, -125.0), 0.0)
	_build_lifeguard_tower(root, "LifeguardTowerSouth", Vector3(-58.0, 0.0, 292.0), 15.0)
	_build_lighthouse(root)
	_build_shipwreck(root)
	_build_surf_shack(root)
	_build_umbrellas(root)
	_build_sand_fence(root)
	_build_boats(root)
	_verify_seafront_clear()


func _ground(x: float, z: float) -> float:
	return float(_tg.call("_sample_cached_height", x, z))


## Lowest ground under a rectangle (for foundations that must not float).
func _ground_min(cx: float, cz: float, hx: float, hz: float) -> float:
	var lo := INF
	for i in range(3):
		for j in range(3):
			lo = minf(lo, _ground(cx + hx * (i - 1), cz + hz * (j - 1)))
	return lo


func _note(name: String, centre: Vector2, radius: float, clearance: float) -> void:
	_footprints.append([name, centre, radius, clearance])


func _verify_seafront_clear() -> void:
	var bad := 0
	for f in _footprints:
		var c: Vector2 = f[1]
		var p := _curve.get_closest_point(Vector3(c.x, _ground(c.x, c.y), c.y))
		var gap: float = Vector2(p.x, p.z).distance_to(c) - float(f[2]) - TRACK_HALF
		if gap < float(f[3]):
			push_error("Seafront: %s is %.1fm off the track edge (wants %.1fm)" % [f[0], gap, f[3]])
			bad += 1
	print("Seafront: %d footprints checked, %d too close to the track" % [_footprints.size(), bad])


# --- Mesh kit -------------------------------------------------------------------------------------

func _mat(key: String) -> Material:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.8
	match key:
		# Plain painted timber: wood_planks.png is too dark to tint.
		"wood":
			m.roughness = 0.9
		"wreck":
			m.roughness = 0.95
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"rock":
			m.albedo_texture = load("res://materials/dark_rock.png")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(0.18, 0.18, 0.18)
			m.roughness = 0.95
		"metal":
			m.metallic = 0.6
			m.roughness = 0.4
		"canvas":
			m.roughness = 0.95
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"glow":
			m.emission_enabled = true
			m.emission = Color(1.0, 0.85, 0.55)
			m.emission_energy_multiplier = 2.5
			m.roughness = 0.1
		"glass":
			m.metallic = 0.3
			m.roughness = 0.05
			m.albedo_color = Color(1, 1, 1, 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials[key] = m
	return m


func _st(kit: Dictionary, key: String) -> SurfaceTool:
	if not kit.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		kit[key] = st
	return kit[key]


## One triangle facing `out` (Godot's front faces wind clockwise: front normal = (c - a) x (b - a)).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col: Color, out: Vector3) -> void:
	st.set_color(col)
	var flip := (b - a).cross(c - a).dot(out) > 0.0
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nc if flip else nb)
	st.add_vertex(c if flip else b)
	st.set_normal(nb if flip else nc)
	st.add_vertex(b if flip else c)


func _quad(kit: Dictionary, key: String, p: Array, n: Vector3, col: Color) -> void:
	var st := _st(kit, key)
	_tri(st, p[0], p[1], p[2], n, n, n, col, n)
	_tri(st, p[0], p[2], p[3], n, n, n, col, n)


func _box(kit: Dictionary, key: String, xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for a in range(3):
		for sgn in [-1.0, 1.0]:
			var n: Vector3 = axes[a] * sgn
			var u: Vector3 = axes[(a + 1) % 3]
			var v: Vector3 = axes[(a + 2) % 3]
			var c: Vector3 = n * h
			var hu: Vector3 = u * h
			var hv: Vector3 = v * h
			var pts := [xf * (c - hu - hv), xf * (c + hu - hv), xf * (c + hu + hv), xf * (c - hu + hv)]
			_quad(kit, key, pts, (xf.basis * n).normalized(), col)


## Axis-aligned box from its min corner to its max corner (world space).
func _block(kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color) -> void:
	_box(kit, key, Transform3D(Basis(), (lo + hi) * 0.5), hi - lo, col)


## A tapered tube from a to b (radius ra at a, rb at b), smooth sided, with caps.
func _tube(kit: Dictionary, key: String, a: Vector3, b: Vector3, ra: float, rb: float, segs: int, col: Color, caps: bool = true) -> void:
	var st := _st(kit, key)
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(axis).normalized()
	var slope := (ra - rb) / maxf((b - a).length(), 0.001)
	for i in range(segs):
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		var n0 := (d0 + axis * slope).normalized()
		var n1 := (d1 + axis * slope).normalized()
		var p00 := a + d0 * ra
		var p01 := a + d1 * ra
		var p10 := b + d0 * rb
		var p11 := b + d1 * rb
		var mid := (d0 + d1).normalized()
		_tri(st, p00, p01, p11, n0, n1, n1, col, mid)
		_tri(st, p00, p11, p10, n0, n1, n0, col, mid)
		if caps:
			if rb > 0.0:
				_tri(st, b, p10, p11, axis, axis, axis, col, axis)
			if ra > 0.0:
				_tri(st, a, p01, p00, -axis, -axis, -axis, col, -axis)


func _gable_roof(kit: Dictionary, key: String, xf: Transform3D, w: float, d: float, h: float, col: Color, gable_col: Color) -> void:
	# Ridge along local z; eaves at y = 0, width w (x), depth d (z).
	var hw := w * 0.5
	var hd := d * 0.5
	var l0 := xf * Vector3(-hw, 0, -hd)
	var l1 := xf * Vector3(-hw, 0, hd)
	var r0 := xf * Vector3(hw, 0, -hd)
	var r1 := xf * Vector3(hw, 0, hd)
	var t0 := xf * Vector3(0, h, -hd)
	var t1 := xf * Vector3(0, h, hd)
	var nl := (xf.basis * Vector3(-h, hw, 0)).normalized()
	var nr := (xf.basis * Vector3(h, hw, 0)).normalized()
	_quad(kit, key, [l0, l1, t1, t0], nl, col)
	_quad(kit, key, [r0, t0, t1, r1], nr, col)
	var st := _st(kit, key)
	var nf := (xf.basis * Vector3.BACK).normalized()
	_tri(st, l1, r1, t1, nf, nf, nf, gable_col, nf)
	_tri(st, l0, t0, r0, -nf, -nf, -nf, gable_col, -nf)
	# Underside, so the eaves aren't see-through from below.
	var nd := -(xf.basis * Vector3.UP).normalized()
	_quad(kit, key, [l0, r0, r1, l1], nd, col.darkened(0.3))


## A low-poly rock: an icosphere pushed about by noise, flat shaded.
func _rock(kit: Dictionary, centre: Vector3, size: Vector3, seed_v: int, col: Color) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.9
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in verts.size():
		verts[i] = (verts[i] as Vector3).normalized()
	for _s in range(2):
		var cache := {}
		var nf := []
		for f in faces:
			var m := []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var k := "%d_%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]
				if not cache.has(k):
					verts.append(((verts[e[0]] as Vector3) + (verts[e[1]] as Vector3)).normalized())
					cache[k] = verts.size() - 1
				m.append(cache[k])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var pts := []
	for v in verts:
		var d: Vector3 = v
		var r := 1.0 + 0.28 * noise.get_noise_3dv(d * 1.3) + 0.08 * noise.get_noise_3dv(d * 4.0)
		var p := d * r
		# Flatten the tops and the bed a little: weathered, not round.
		p.y = clampf(p.y, -0.85, 0.7)
		pts.append(centre + p * size)
	var st := _st(kit, "rock")
	for f in faces:
		var a: Vector3 = pts[f[0]]
		var b: Vector3 = pts[f[1]]
		var c: Vector3 = pts[f[2]]
		var out := ((a + b + c) / 3.0 - centre)
		var n := (b - a).cross(c - a).normalized()
		if n.dot(out) < 0.0:
			n = -n
		var shade := col.lightened(clampf(n.y, 0.0, 1.0) * 0.12)
		_tri(st, a, b, c, n, n, n, shade, out)


func _commit(parent: Node3D, kit: Dictionary, name: String) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for key in kit.keys():
		var st: SurfaceTool = kit[key]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mat(key))
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = _tg.call("_save_resource", mesh, "seafront_" + name.to_snake_case())
	parent.add_child(mi)
	return mi


func _collider(parent: Node3D, name: String, shape: Shape3D, xf: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.name = name + "Body"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.global_transform = xf


func _box_collider(parent: Node3D, name: String, lo: Vector3, hi: Vector3, yaw_deg: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = hi - lo
	_collider(parent, name, shape, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), (lo + hi) * 0.5))


# --- Structures -----------------------------------------------------------------------------------

## Covered grandstand facing the finish line from the dune side of the beach.
func _build_grandstand(root: Node3D) -> void:
	var kit := {}
	var x0 := -27.0           # front (sea side)
	var z0 := 146.0
	var z1 := 194.0
	var tiers := 7
	var tier_d := 1.05
	var tier_h := 0.55
	var base := _ground_min(-22.0, 170.0, 6.0, 24.0) - 0.6
	var front_y := maxf(_ground(x0, 170.0), base + 0.6) + 0.9
	var concrete := Color(0.86, 0.85, 0.80)
	var seat_cols := [Color(0.10, 0.55, 0.70), Color(0.95, 0.55, 0.30), Color(0.98, 0.98, 0.95)]
	# Front wall with sponsor-coloured panels.
	_block(kit, "paint", Vector3(x0 - 0.3, base, z0), Vector3(x0, front_y + 0.9, z1), concrete)
	var z := z0 + 1.0
	var k := 0
	while z < z1 - 4.0:
		var c: Color = [Color(0.10, 0.45, 0.70), Color(0.95, 0.75, 0.20), Color(0.90, 0.30, 0.30)][k % 3]
		_block(kit, "paint", Vector3(x0 - 0.36, front_y - 0.1, z), Vector3(x0 - 0.3, front_y + 0.75, z + 3.6), c)
		z += 4.6
		k += 1
	for i in range(tiers):
		var tx := x0 + i * tier_d
		var ty := front_y + i * tier_h
		_block(kit, "paint", Vector3(tx, base, z0), Vector3(tx + tier_d, ty, z1), concrete.darkened(0.04 * (i % 2)))
		# Bench seats in team colours, broken by two aisles.
		for seg in [[z0 + 0.6, 160.0], [161.6, 178.4], [180.0, z1 - 0.6]]:
			_block(kit, "paint", Vector3(tx + 0.35, ty, seg[0]), Vector3(tx + 0.85, ty + 0.42, seg[1]), seat_cols[i % 3])
	var back_x := x0 + tiers * tier_d
	var top := front_y + tiers * tier_h
	_block(kit, "paint", Vector3(back_x, base, z0), Vector3(back_x + 0.4, top + 4.2, z1), concrete)
	# Side walls.
	for zz in [z0 - 0.4, z1]:
		_block(kit, "paint", Vector3(x0 - 0.3, base, zz), Vector3(back_x + 0.4, top + 1.0, zz + 0.4), concrete.darkened(0.05))
	# Cantilevered roof on steel posts, striped canvas edge.
	var roof_y := top + 4.2
	var zz2 := z0
	while zz2 <= z1 + 0.01:
		_tube(kit, "metal", Vector3(back_x + 0.2, base, zz2), Vector3(back_x + 0.2, roof_y + 0.3, zz2), 0.18, 0.18, 8, Color(0.85, 0.86, 0.88))
		_tube(kit, "metal", Vector3(back_x + 0.2, roof_y + 0.3, zz2), Vector3(x0 - 1.0, roof_y - 0.5, zz2), 0.12, 0.08, 6, Color(0.85, 0.86, 0.88))
		zz2 += 8.0
	var roof_xf := Transform3D(Basis(Vector3.BACK, atan2(0.8, back_x - x0 + 1.4)), Vector3((back_x + x0 - 1.0) * 0.5, roof_y - 0.05, (z0 + z1) * 0.5))
	_box(kit, "paint", roof_xf, Vector3(back_x - x0 + 1.6, 0.18, z1 - z0 + 0.8), Color(0.96, 0.97, 0.97))
	var stripe := 0
	var sz := z0 - 0.4
	while sz < z1 + 0.4:
		var sc: Color = Color(0.10, 0.55, 0.70) if stripe % 2 == 0 else Color(0.97, 0.97, 0.95)
		_block(kit, "canvas", Vector3(x0 - 1.25, roof_y - 1.25, sz), Vector3(x0 - 1.1, roof_y - 0.45, minf(sz + 1.6, z1 + 0.4)), sc)
		sz += 1.6
		stripe += 1
	_commit(root, kit, "Grandstand")
	_box_collider(root, "Grandstand", Vector3(x0 - 0.4, base, z0 - 0.4), Vector3(back_x + 0.5, top + 1.0, z1 + 0.4))
	for zc in [152.0, 162.0, 172.0, 182.0, 190.0]:
		_note("Grandstand", Vector2(x0, zc), 0.5, CLEAR_BUILDING)


## A row of striped bathing huts with their doors to the sea.
func _build_beach_huts(root: Node3D) -> void:
	var kit := {}
	var z := 24.0
	var i := 0
	while z < 74.0:
		var x := -23.5
		var w := 2.6
		var d := 2.8
		var g := _ground_min(x, z, d * 0.5, w * 0.5)
		var floor_y := maxf(_ground(x - d * 0.5, z), g) + 0.35
		var col: Color = HUT_COLOURS[i % HUT_COLOURS.size()]
		# Stilts and floor.
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				_block(kit, "wood", Vector3(x + cx * (d * 0.5 - 0.15) - 0.1, g - 0.3, z + cz * (w * 0.5 - 0.15) - 0.1), Vector3(x + cx * (d * 0.5 - 0.15) + 0.1, floor_y, z + cz * (w * 0.5 - 0.15) + 0.1), WOOD)
		_block(kit, "wood", Vector3(x - d * 0.5 - 0.5, floor_y - 0.12, z - w * 0.5), Vector3(x + d * 0.5, floor_y, z + w * 0.5), WOOD)
		# Walls in vertical stripes of colour and white.
		var wall_h := 2.4
		var n := 8
		for s in range(n):
			var sc: Color = col if s % 2 == 0 else WHITE
			var za := z - w * 0.5 + w * s / n
			var zb := z - w * 0.5 + w * (s + 1) / n
			_block(kit, "paint", Vector3(x - d * 0.5, floor_y, za), Vector3(x - d * 0.5 + 0.08, floor_y + wall_h, zb), sc)
			_block(kit, "paint", Vector3(x + d * 0.5 - 0.08, floor_y, za), Vector3(x + d * 0.5, floor_y + wall_h, zb), sc)
		for s in range(n):
			var sc2: Color = col if s % 2 == 0 else WHITE
			var xa := x - d * 0.5 + d * s / n
			var xb := x - d * 0.5 + d * (s + 1) / n
			_block(kit, "paint", Vector3(xa, floor_y, z - w * 0.5), Vector3(xb, floor_y + wall_h, z - w * 0.5 + 0.08), sc2)
			_block(kit, "paint", Vector3(xa, floor_y, z + w * 0.5 - 0.08), Vector3(xb, floor_y + wall_h, z + w * 0.5), sc2)
		# Door on the sea side.
		_block(kit, "paint", Vector3(x - d * 0.5 - 0.04, floor_y + 0.05, z - 0.55), Vector3(x - d * 0.5, floor_y + 1.95, z + 0.55), col.darkened(0.35))
		_gable_roof(kit, "paint", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, floor_y + wall_h, z)), w + 0.4, d + 0.5, 1.0, WHITE.darkened(0.05), col)
		_box_collider(root, "Hut%d" % i, Vector3(x - d * 0.5 - 0.5, g - 0.3, z - w * 0.5), Vector3(x + d * 0.5, floor_y + wall_h + 0.8, z + w * 0.5))
		_note("Hut%d" % i, Vector2(x - d * 0.5 - 0.5, z), 0.2, CLEAR_BUILDING)
		z += 3.6
		i += 1
	_commit(root, kit, "BeachHuts")


## A timber pier from the beach out past the sandbar, a pavilion on its T-head.
func _build_pier(root: Node3D) -> void:
	var kit := {}
	var z := 100.0
	var x_land := -61.5
	var x_end := -176.0
	var top := 2.6
	var half := 2.2
	var head_x := x_end + 10.0
	var head_half := 9.0
	# Stone abutment on the sand, with steps up its south side.
	var ab_g := _ground_min(x_land + 2.0, z, 3.0, half + 1.0) - 0.4
	_block(kit, "rock", Vector3(x_land - 1.0, ab_g, z - half - 0.6), Vector3(x_land + 4.0, top, z + half + 0.6), Color(0.78, 0.74, 0.66))
	for s in range(6):
		var sy := top - 0.43 * (s + 1)
		_block(kit, "rock", Vector3(x_land - 1.0, ab_g, z + half + 0.6 + s * 0.45), Vector3(x_land + 4.0, sy, z + half + 1.05 + s * 0.45), Color(0.80, 0.76, 0.68))
	_box_collider(root, "PierAbutment", Vector3(x_land - 1.0, ab_g, z - half - 0.6), Vector3(x_land + 4.0, top, z + half + 3.4))
	_note("PierAbutment", Vector2(x_land + 4.0, z), 0.5, CLEAR_BUILDING)
	# Deck boards over joists.
	_block(kit, "wood", Vector3(x_end, top - 0.22, z - half), Vector3(x_land - 1.0, top, z + half), WOOD)
	_block(kit, "wood", Vector3(x_end, top - 0.22, z - head_half), Vector3(head_x + 6.0, top, z + head_half), WOOD)
	for zz in [z - half + 0.3, z + half - 0.3]:
		_block(kit, "wood", Vector3(x_end, top - 0.6, zz - 0.15), Vector3(x_land - 1.0, top - 0.22, zz + 0.15), OLD_WOOD)
	# Piles in pairs every 6m, braced; the shallow ones get colliders.
	var x := x_land - 4.0
	while x > x_end - 0.1:
		var bed := _ground(x, z)
		for zz2 in [z - half + 0.2, z + half - 0.2]:
			_tube(kit, "wood", Vector3(x, bed - 0.8, zz2), Vector3(x, top - 0.22, zz2), 0.24, 0.22, 8, OLD_WOOD)
			if bed > -1.0:
				var shape := CylinderShape3D.new()
				shape.radius = 0.26
				shape.height = top - bed + 0.8
				_collider(root, "PierPile", shape, Transform3D(Basis(), Vector3(x, (bed - 0.8 + top) * 0.5, zz2)))
		_tube(kit, "wood", Vector3(x, bed + 0.2, z - half + 0.2), Vector3(x, top - 0.7, z + half - 0.2), 0.08, 0.08, 5, OLD_WOOD)
		_tube(kit, "wood", Vector3(x, top - 0.7, z - half + 0.2), Vector3(x, bed + 0.2, z + half - 0.2), 0.08, 0.08, 5, OLD_WOOD)
		x -= 6.0
	# Extra piles under the T-head.
	for hx in [x_end + 1.0, head_x, head_x + 5.0]:
		for hz in [z - head_half + 0.5, z - 4.0, z + 4.0, z + head_half - 0.5]:
			var b2 := _ground(hx, hz)
			_tube(kit, "wood", Vector3(hx, b2 - 0.8, hz), Vector3(hx, top - 0.22, hz), 0.26, 0.24, 8, OLD_WOOD)
	# Railings: posts and two rails down each side and round the head.
	var rail_col := Color(0.92, 0.92, 0.88)
	var runs := [
		[Vector3(x_land - 1.0, top, z - half), Vector3(head_x + 6.0, top, z - half)],
		[Vector3(x_land - 1.0, top, z + half), Vector3(head_x + 6.0, top, z + half)],
		[Vector3(head_x + 6.0, top, z - head_half), Vector3(head_x + 6.0, top, z - half)],
		[Vector3(head_x + 6.0, top, z + half), Vector3(head_x + 6.0, top, z + head_half)],
		[Vector3(x_end, top, z - head_half), Vector3(head_x + 6.0, top, z - head_half)],
		[Vector3(x_end, top, z + head_half), Vector3(head_x + 6.0, top, z + head_half)],
		[Vector3(x_end, top, z - head_half), Vector3(x_end, top, z + head_half)],
	]
	for r in runs:
		var a: Vector3 = r[0]
		var b: Vector3 = r[1]
		var run_len := a.distance_to(b)
		var posts := maxi(1, int(run_len / 2.0))
		for p in range(posts + 1):
			var pp := a.lerp(b, float(p) / posts)
			_block(kit, "paint", pp + Vector3(-0.06, 0.0, -0.06), pp + Vector3(0.06, 1.05, 0.06), rail_col)
		_tube(kit, "paint", a + Vector3(0, 1.0, 0), b + Vector3(0, 1.0, 0), 0.05, 0.05, 5, rail_col)
		_tube(kit, "paint", a + Vector3(0, 0.55, 0), b + Vector3(0, 0.55, 0), 0.035, 0.035, 5, rail_col)
	# Lamp posts.
	var lx := x_land - 8.0
	while lx > head_x + 6.0:
		for zz3 in [z - half + 0.15, z + half - 0.15]:
			_tube(kit, "metal", Vector3(lx, top, zz3), Vector3(lx, top + 3.2, zz3), 0.07, 0.05, 6, Color(0.15, 0.25, 0.30))
			_block(kit, "glow", Vector3(lx - 0.16, top + 3.2, zz3 - 0.16), Vector3(lx + 0.16, top + 3.6, zz3 + 0.16), Color(1, 1, 1))
			_tube(kit, "metal", Vector3(lx, top + 3.6, zz3), Vector3(lx, top + 3.85, zz3), 0.26, 0.0, 6, Color(0.15, 0.25, 0.30))
		lx -= 18.0
	# Pavilion on the head.
	var pc := Vector3(head_x + 0.5, top, z)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			_tube(kit, "paint", pc + Vector3(cx * 3.0, 0, cz * 3.0), pc + Vector3(cx * 3.0, 3.2, cz * 3.0), 0.14, 0.14, 8, WHITE)
	_block(kit, "paint", pc + Vector3(-3.4, 3.2, -3.4), pc + Vector3(3.4, 3.45, 3.4), WHITE)
	var apex := pc + Vector3(0, 5.6, 0)
	var eaves := [Vector3(-4.0, 3.45, -4.0), Vector3(4.0, 3.45, -4.0), Vector3(4.0, 3.45, 4.0), Vector3(-4.0, 3.45, 4.0)]
	var pst := _st(kit, "paint")
	for q in range(4):
		var e1: Vector3 = pc + eaves[q]
		var e2: Vector3 = pc + eaves[(q + 1) % 4]
		var ncol: Color = Color(0.10, 0.55, 0.70) if q % 2 == 0 else Color(0.97, 0.97, 0.95)
		var nn := (e2 - e1).cross(apex - e1).normalized()
		if nn.y < 0.0:
			nn = -nn
		_tri(pst, e1, e2, apex, nn, nn, nn, ncol, nn)
		_tri(pst, e1, e2, pc + Vector3(0, 3.45, 0), Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, ncol.darkened(0.3), Vector3.DOWN)
	_commit(root, kit, "Pier")


## A lifeguard hut up on stilts, with a ramp of slats and a flag.
func _build_lifeguard_tower(root: Node3D, name: String, at: Vector3, yaw_deg: float) -> void:
	var kit := {}
	var g := _ground_min(at.x, at.z, 1.6, 1.6)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(at.x, g, at.z))
	var yellow := Color(0.98, 0.80, 0.20)
	var red := Color(0.88, 0.22, 0.18)
	var legs_h := 2.8
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			_tube(kit, "wood", xf * Vector3(cx * 1.3, -0.6, cz * 1.3), xf * Vector3(cx * 1.1, legs_h, cz * 1.1), 0.12, 0.1, 6, WHITE)
	_tube(kit, "wood", xf * Vector3(-1.25, 0.8, -1.25), xf * Vector3(1.25, 0.8, 1.25), 0.06, 0.06, 5, WHITE)
	_tube(kit, "wood", xf * Vector3(-1.25, 0.8, 1.25), xf * Vector3(1.25, 0.8, -1.25), 0.06, 0.06, 5, WHITE)
	_box(kit, "wood", xf * Transform3D(Basis(), Vector3(-0.3, legs_h, 0)), Vector3(3.4, 0.15, 3.0), WOOD)
	# Cabin: back and sides painted, front open with a counter facing the sea (-x locally).
	_box(kit, "paint", xf * Transform3D(Basis(), Vector3(0.95, legs_h + 1.05, 0)), Vector3(0.1, 2.1, 2.6), yellow)
	for sz in [-1, 1]:
		_box(kit, "paint", xf * Transform3D(Basis(), Vector3(0.1, legs_h + 1.05, sz * 1.25)), Vector3(1.8, 2.1, 0.1), yellow)
	_box(kit, "paint", xf * Transform3D(Basis(), Vector3(-0.75, legs_h + 0.5, 0)), Vector3(0.1, 1.0, 2.6), red)
	_box(kit, "paint", xf * Transform3D(Basis(Vector3.BACK, 0.12), Vector3(0.0, legs_h + 2.25, 0)), Vector3(2.6, 0.12, 3.2), red)
	# Ramp down the back.
	var ramp_from := xf * Vector3(1.1, legs_h, 0)
	var ramp_to := xf * Vector3(4.6, 0.0, 0)
	var steps := 9
	for s in range(steps):
		var p := ramp_from.lerp(ramp_to, (s + 0.5) / steps)
		_box(kit, "wood", Transform3D(xf.basis, p), Vector3(0.28, 0.06, 1.0), WOOD)
	_tube(kit, "wood", xf * Vector3(1.1, legs_h, -0.5), xf * Vector3(4.6, 0.0, -0.5), 0.06, 0.06, 5, OLD_WOOD)
	_tube(kit, "wood", xf * Vector3(1.1, legs_h, 0.5), xf * Vector3(4.6, 0.0, 0.5), 0.06, 0.06, 5, OLD_WOOD)
	# Flag.
	var pole_top := xf * Vector3(0.9, legs_h + 5.2, 1.2)
	_tube(kit, "metal", xf * Vector3(0.9, legs_h + 2.2, 1.2), pole_top, 0.04, 0.03, 5, Color(0.8, 0.8, 0.82))
	var fl := xf.basis * Vector3(0, 0, 1)
	var st := _st(kit, "canvas")
	var f0 := pole_top + Vector3(0, -0.05, 0)
	var f1 := pole_top + Vector3(0, -0.85, 0)
	var f2 := f1 + fl * 1.3 + Vector3(0, 0.1, 0)
	var f3 := f0 + fl * 1.3 + Vector3(0, -0.1, 0)
	var fn := xf.basis * Vector3.RIGHT
	_tri(st, f0, f1, f2, fn, fn, fn, red, fn)
	_tri(st, f0, f2, f3, fn, fn, fn, yellow, fn)
	_commit(root, kit, name)
	_box_collider(root, name, Vector3(at.x - 1.5, g - 0.5, at.z - 1.5), Vector3(at.x + 1.5, g + legs_h + 2.4, at.z + 1.5), yaw_deg)
	_note(name, Vector2(at.x, at.z), 2.0, CLEAR_BUILDING)


## Red and white lighthouse on a rock islet off the north end of the bay, with the keeper's cottage.
func _build_lighthouse(root: Node3D) -> void:
	var kit := {}
	var c := Vector3(-100.0, 0.0, -394.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var sand_rock := Color(0.70, 0.64, 0.56)
	_rock(kit, c + Vector3(0, 0.6, 0), Vector3(9.0, 3.4, 8.0), 11, sand_rock)
	for i in range(11):
		var a := TAU * i / 11.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(7.5, 12.0)
		var s := rng.randf_range(1.6, 3.6)
		var bed := _ground(c.x + cos(a) * r, c.z + sin(a) * r)
		_rock(kit, Vector3(c.x + cos(a) * r, maxf(bed, -2.0) + s * 0.25, c.z + sin(a) * r), Vector3(s * 1.2, s * 0.8, s), 100 + i, sand_rock.darkened(rng.randf_range(0.0, 0.2)))
	var base_y := 2.5
	var red := Color(0.82, 0.16, 0.14)
	var bands := 6
	var h := 19.0
	for b in range(bands):
		var y0 := base_y + h * b / bands
		var y1 := base_y + h * (b + 1) / bands
		var r0 := lerpf(2.9, 1.9, float(b) / bands)
		var r1 := lerpf(2.9, 1.9, float(b + 1) / bands)
		_tube(kit, "paint", c + Vector3(0, y0, 0), c + Vector3(0, y1, 0), r0, r1, 20, WHITE if b % 2 == 0 else red, false)
	_tube(kit, "paint", c + Vector3(0, base_y - 1.5, 0), c + Vector3(0, base_y + 0.4, 0), 3.4, 3.2, 20, Color(0.55, 0.52, 0.48))
	# Door and little windows up the tower.
	_box(kit, "paint", Transform3D(Basis(), c + Vector3(2.85, base_y + 1.1, 0)), Vector3(0.2, 2.0, 1.1), Color(0.18, 0.32, 0.42))
	for wy in [7.5, 12.5, 17.0]:
		var rr := lerpf(2.9, 1.9, (wy - base_y) / h)
		_box(kit, "paint", Transform3D(Basis(Vector3.UP, 0.4), c + Vector3(cos(0.4) * rr, wy, -sin(0.4) * rr)), Vector3(0.2, 0.9, 0.6), Color(0.12, 0.16, 0.2))
	# Gallery, lantern room, dome.
	var top := base_y + h
	_tube(kit, "paint", c + Vector3(0, top, 0), c + Vector3(0, top + 0.35, 0), 3.0, 3.0, 24, Color(0.2, 0.22, 0.24))
	for i in range(24):
		var a := TAU * i / 24.0
		var p := c + Vector3(cos(a) * 2.9, top + 0.35, sin(a) * 2.9)
		_block(kit, "metal", p + Vector3(-0.04, 0, -0.04), p + Vector3(0.04, 1.0, 0.04), Color(0.2, 0.22, 0.24))
	for i in range(24):
		var a0 := TAU * i / 24.0
		var a1 := TAU * (i + 1) / 24.0
		_tube(kit, "metal", c + Vector3(cos(a0) * 2.9, top + 1.3, sin(a0) * 2.9), c + Vector3(cos(a1) * 2.9, top + 1.3, sin(a1) * 2.9), 0.04, 0.04, 4, Color(0.2, 0.22, 0.24), false)
	_tube(kit, "glow", c + Vector3(0, top + 0.35, 0), c + Vector3(0, top + 2.6, 0), 1.0, 1.0, 12, Color(1, 1, 1))
	_tube(kit, "glass", c + Vector3(0, top + 0.35, 0), c + Vector3(0, top + 2.6, 0), 1.6, 1.6, 8, Color(0.8, 0.9, 0.95), false)
	for i in range(8):
		var a := TAU * (i + 0.5) / 8.0
		_tube(kit, "metal", c + Vector3(cos(a) * 1.62, top + 0.35, sin(a) * 1.62), c + Vector3(cos(a) * 1.62, top + 2.6, sin(a) * 1.62), 0.05, 0.05, 4, Color(0.15, 0.15, 0.17))
	_tube(kit, "paint", c + Vector3(0, top + 2.6, 0), c + Vector3(0, top + 4.2, 0), 1.9, 0.25, 16, red)
	_tube(kit, "metal", c + Vector3(0, top + 4.2, 0), c + Vector3(0, top + 5.0, 0), 0.08, 0.02, 6, Color(0.2, 0.2, 0.2))
	# Keeper's cottage on the landward side of the rock.
	var hc := c + Vector3(6.0, 1.6, 2.0)
	_block(kit, "paint", hc + Vector3(-2.5, -1.2, -3.0), hc + Vector3(2.5, 2.2, 3.0), WHITE)
	_gable_roof(kit, "paint", Transform3D(Basis(), hc + Vector3(0, 2.2, 0)), 5.8, 6.8, 1.8, red, WHITE)
	_block(kit, "paint", hc + Vector3(-2.56, 0.2, -0.5), hc + Vector3(-2.5, 1.4, 0.5), Color(0.18, 0.32, 0.42))
	_block(kit, "paint", hc + Vector3(-0.7, 2.4, -2.0), hc + Vector3(0.2, 4.3, -1.3), Color(0.6, 0.55, 0.5))
	var mi := _commit(root, kit, "Lighthouse")
	mi.lod_bias = 4.0
	var lamp := OmniLight3D.new()
	lamp.name = "LighthouseLamp"
	lamp.light_color = Color(1.0, 0.85, 0.55)
	lamp.light_energy = 1.2
	lamp.omni_range = 12.0
	lamp.shadow_enabled = false
	lamp.set_meta("no_shadow", true)
	root.add_child(lamp)
	lamp.position = c + Vector3(0, top + 1.5, 0)
	var shape := CylinderShape3D.new()
	shape.radius = 9.0
	shape.height = 6.0
	_collider(root, "LighthouseRock", shape, Transform3D(Basis(), c + Vector3(0, 0.0, 0)))
	_note("Lighthouse", Vector2(c.x, c.z), 12.0, CLEAR_BUILDING)


## An old fishing boat, broken-backed and half sunk in the swash at the south end of the beach.
func _build_shipwreck(root: Node3D) -> void:
	var kit := {}
	var at := Vector3(-68.5, 0.5, 370.0)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(38.0)) * Basis(Vector3.FORWARD, deg_to_rad(-16.0)) * Basis(Vector3.RIGHT, deg_to_rad(4.0)), at)
	var length := 18.0
	var beam := 5.2
	var depth := 3.4
	var stations := 18
	var arc := 12
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var hull := func(s: float, a: float) -> Vector3:
		# s along the keel (0 stern, 1 bow), a round the hull from port gunwale (0) to starboard (1).
		var taper := sqrt(maxf(0.0, 1.0 - pow(absf(2.0 * s - 1.0) * (1.0 if s > 0.5 else 0.85), 3.0)))
		var w := beam * 0.5 * maxf(taper, 0.06)
		var phi := PI * a
		var sheer := depth * (0.15 * pow(2.0 * s - 1.0, 2.0))
		return Vector3(-cos(phi) * w, -sin(phi) * depth * (0.55 + 0.45 * taper) + sheer, (s - 0.5) * length)
	var red_bottom := Color(0.55, 0.22, 0.18)
	var plank := Color(0.42, 0.36, 0.30)
	for i in range(stations):
		var s0 := float(i) / stations
		var s1 := float(i + 1) / stations
		for j in range(arc):
			var a0 := float(j) / arc
			var a1 := float(j + 1) / arc
			# The bow half has lost most of its planking.
			var lost := s0 > 0.55 and rng.randf() < lerpf(0.35, 0.85, (s0 - 0.55) / 0.45)
			if lost:
				continue
			var p00: Vector3 = xf * hull.call(s0, a0)
			var p01: Vector3 = xf * hull.call(s0, a1)
			var p10: Vector3 = xf * hull.call(s1, a0)
			var p11: Vector3 = xf * hull.call(s1, a1)
			var centre: Vector3 = xf * Vector3(0, -depth * 0.3, (lerpf(s0, s1, 0.5) - 0.5) * length)
			var out := ((p00 + p11) * 0.5 - centre).normalized()
			var col := red_bottom if absf(a0 - 0.5) < 0.3 else plank
			_quad(kit, "wreck", [p00, p01, p11, p10], out, col.darkened(rng.randf_range(0.0, 0.18)))
	# Ribs, standing clear where the planks are gone.
	for i in range(1, stations, 2):
		var s := float(i) / stations
		for j in range(arc):
			var a: Vector3 = xf * hull.call(s, float(j) / arc)
			var b: Vector3 = xf * hull.call(s, float(j + 1) / arc)
			var inward: Vector3 = (xf.basis * Vector3(0, 0.25, 0))
			_tube(kit, "wreck", a + inward * 0.4, b + inward * 0.4, 0.13, 0.13, 4, OLD_WOOD.darkened(0.2))
	# Keel, stem and a snapped mast.
	_tube(kit, "wreck", xf * Vector3(0, -depth, -length * 0.5), xf * Vector3(0, -depth * 0.6, length * 0.5), 0.25, 0.2, 6, OLD_WOOD.darkened(0.3))
	_tube(kit, "wreck", xf * Vector3(0, -depth * 0.6, length * 0.5), xf * Vector3(0, depth * 0.4, length * 0.5 + 0.8), 0.2, 0.15, 6, OLD_WOOD.darkened(0.3))
	_tube(kit, "wreck", xf * Vector3(0, -depth * 0.8, -1.0), xf * Vector3(0.8, 3.8, -0.4), 0.22, 0.16, 8, OLD_WOOD)
	# Wheelhouse, tipped over the stern.
	_box(kit, "wreck", xf * Transform3D(Basis(Vector3.RIGHT, 0.1), Vector3(0, 0.6, -length * 0.3)), Vector3(3.0, 2.2, 3.2), Color(0.62, 0.66, 0.62))
	_box(kit, "wreck", xf * Transform3D(Basis(Vector3.RIGHT, 0.1), Vector3(0, 1.8, -length * 0.3)), Vector3(3.4, 0.2, 3.6), Color(0.40, 0.35, 0.30))
	_commit(root, kit, "Shipwreck")
	_box_collider(root, "Shipwreck", at + Vector3(-2.5, -0.5, -8.5), at + Vector3(2.5, 3.0, 8.5), 38.0)
	_note("Shipwreck", Vector2(at.x, at.z), 9.0, CLEAR_BUILDING)


## Surf shack bar under a thatch, boards leaning on the rail.
func _build_surf_shack(root: Node3D) -> void:
	var kit := {}
	var c := Vector3(-14.0, 0.0, 236.0)
	var g := _ground_min(c.x, c.z, 5.0, 4.0)
	var fl := maxf(g, _ground(c.x - 5.0, c.z)) + 0.7
	_block(kit, "wood", Vector3(c.x - 5.0, g - 0.3, c.z - 4.0), Vector3(c.x + 5.0, fl, c.z + 4.0), WOOD)
	for cx in [-4.6, 4.6]:
		for cz in [-3.6, 3.6]:
			_tube(kit, "wood", Vector3(c.x + cx, fl, c.z + cz), Vector3(c.x + cx, fl + 3.0, c.z + cz), 0.16, 0.14, 6, OLD_WOOD)
	# Bar counter facing the sea and a back wall of shelves.
	_block(kit, "wood", Vector3(c.x - 3.2, fl, c.z - 3.0), Vector3(c.x - 2.4, fl + 1.1, c.z + 3.0), Color(0.30, 0.62, 0.66))
	_block(kit, "wood", Vector3(c.x - 3.5, fl + 1.1, c.z - 3.2), Vector3(c.x - 2.2, fl + 1.2, c.z + 3.2), WOOD)
	_block(kit, "wood", Vector3(c.x + 3.6, fl, c.z - 3.4), Vector3(c.x + 4.4, fl + 2.6, c.z + 3.4), OLD_WOOD)
	for sy in [0.9, 1.6]:
		_block(kit, "paint", Vector3(c.x + 3.3, fl + sy, c.z - 3.0), Vector3(c.x + 3.6, fl + sy + 0.06, c.z + 3.0), WOOD)
	for i in range(5):
		var stool := Vector3(c.x - 4.1, fl, c.z - 2.4 + i * 1.2)
		_tube(kit, "metal", stool, stool + Vector3(0, 0.75, 0), 0.05, 0.05, 5, Color(0.3, 0.3, 0.3))
		_tube(kit, "paint", stool + Vector3(0, 0.75, 0), stool + Vector3(0, 0.82, 0), 0.22, 0.22, 8, HUT_COLOURS[i % 6])
	# Thatch: a low hipped pyramid with a deep overhang.
	var straw := Color(0.80, 0.68, 0.42)
	var apex := Vector3(c.x, fl + 5.2, c.z)
	var corners := [Vector3(c.x - 6.2, fl + 2.7, c.z - 5.2), Vector3(c.x + 6.2, fl + 2.7, c.z - 5.2), Vector3(c.x + 6.2, fl + 2.7, c.z + 5.2), Vector3(c.x - 6.2, fl + 2.7, c.z + 5.2)]
	var st := _st(kit, "canvas")
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var n := (b - a).cross(apex - a).normalized()
		if n.y < 0.0:
			n = -n
		_tri(st, a, b, apex, n, n, n, straw.darkened(0.05 * i), n)
	# Surfboards leaning on the south rail.
	var board_cols := [Color(0.95, 0.40, 0.30), Color(0.25, 0.65, 0.85), Color(0.98, 0.85, 0.30), Color(0.95, 0.95, 0.92)]
	for i in range(4):
		var foot := Vector3(c.x - 3.0 + i * 1.6, g, c.z + 4.6)
		var b_xf := Transform3D(Basis(Vector3.RIGHT, -0.28) * Basis(Vector3.FORWARD, 0.05 * (i - 1.5)), foot + Vector3(0, 1.15, 0))
		_box(kit, "paint", b_xf, Vector3(0.55, 2.3, 0.07), board_cols[i])
		_box(kit, "paint", b_xf, Vector3(0.08, 2.32, 0.09), WHITE)
	_commit(root, kit, "SurfShack")
	_box_collider(root, "SurfShack", Vector3(c.x - 5.0, g - 0.3, c.z - 4.0), Vector3(c.x + 5.0, fl + 3.0, c.z + 4.8))
	_note("SurfShack", Vector2(c.x, c.z), 6.4, CLEAR_BUILDING)


func _umbrella(kit: Dictionary, at: Vector3, tilt: Vector3, cols: Array) -> void:
	var top := at + (Vector3.UP + tilt).normalized() * 2.4
	_tube(kit, "paint", at + Vector3(0, -0.3, 0), top, 0.035, 0.03, 5, WHITE)
	var axis := (top - at).normalized()
	var side := axis.cross(Vector3.RIGHT).normalized()
	var up := side.cross(axis).normalized()
	var st := _st(kit, "canvas")
	var segs := 10
	for i in range(segs):
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var r0 := top - axis * 0.55 + (side * cos(a0) + up * sin(a0)) * 1.35
		var r1 := top - axis * 0.55 + (side * cos(a1) + up * sin(a1)) * 1.35
		var apex := top + axis * 0.08
		var n := (r1 - r0).cross(apex - r0).normalized()
		if n.dot(axis) < 0.0:
			n = -n
		_tri(st, r0, r1, apex, n, n, n, cols[i % cols.size()], n)


func _lounger(kit: Dictionary, at: Vector3, yaw: float, col: Color) -> void:
	var b := Basis(Vector3.UP, yaw)
	_box(kit, "paint", Transform3D(b, at + Vector3(0, 0.28, 0)), Vector3(0.65, 0.08, 1.4), col)
	_box(kit, "paint", Transform3D(b * Basis(Vector3.RIGHT, 0.9), at + b * Vector3(0, 0.55, -0.85)), Vector3(0.65, 0.08, 0.7), col)
	for cx in [-0.28, 0.28]:
		for cz in [-0.6, 0.6]:
			_box(kit, "metal", Transform3D(b, at + b * Vector3(cx, 0.12, cz)), Vector3(0.04, 0.28, 0.04), WHITE)


## Umbrellas, loungers and towels in groups along the dune side of the beach and round the far ends.
func _build_umbrellas(root: Node3D) -> void:
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var groups := [
		[Vector2(-23.0, 92.0), 9.0, 7], [Vector2(-23.0, 118.0), 7.0, 5], [Vector2(-23.0, 8.0), 8.0, 5],
		[Vector2(-23.0, -60.0), 9.0, 6], [Vector2(-24.0, -150.0), 8.0, 5],
		[Vector2(-50.0, -320.0), 10.0, 6], [Vector2(-48.0, 318.0), 9.0, 6],
	]
	var n := 0
	for gdef in groups:
		var centre: Vector2 = gdef[0]
		for i in range(int(gdef[2])):
			# Spread along the beach, not across it toward the racing line.
			var p := centre + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-1.0, 1.0) * float(gdef[1]))
			var y := _ground(p.x, p.y)
			var cols := [HUT_COLOURS[rng.randi() % 6], WHITE]
			_umbrella(kit, Vector3(p.x, y, p.y), Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12)), cols)
			var yaw := rng.randf_range(-0.4, 0.4) + PI * 0.5
			for side in [-0.9, 0.9]:
				if rng.randf() < 0.75:
					var lp := Vector3(p.x + side * 0.3, 0, p.y + side)
					lp.y = _ground(lp.x, lp.z)
					_lounger(kit, lp, yaw, [Color(0.95, 0.95, 0.92), Color(0.25, 0.55, 0.75)][rng.randi() % 2])
			if rng.randf() < 0.6:
				var tp := Vector3(p.x - 2.0, 0, p.y + rng.randf_range(-1.5, 1.5))
				tp.y = _ground(tp.x, tp.z) + 0.02
				_box(kit, "canvas", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)), tp), Vector3(1.8, 0.03, 0.9), HUT_COLOURS[rng.randi() % 6])
			_note("Umbrella%d" % n, p, 1.6, CLEAR_DECOR)
			n += 1
	_commit(root, kit, "Umbrellas")


## Weathered slatted sand fence along the dune foot, half buried in places.
func _build_sand_fence(root: Node3D) -> void:
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var z := -248.0
	var grey := Color(0.60, 0.56, 0.50)
	while z < 128.0:
		# Gaps where the huts, the grandstand and the beach paths are.
		if (z > 140.0 and z < 200.0) or (absf(z - 0.0) < 4.0) or (absf(z + 100.0) < 4.0):
			z += 2.0
			continue
		var x := -12.5 + 1.2 * sin(z * 0.05) + 0.6 * sin(z * 0.17)
		var x2 := -12.5 + 1.2 * sin((z + 2.0) * 0.05) + 0.6 * sin((z + 2.0) * 0.17)
		var y := _ground(x, z)
		var y2 := _ground(x2, z + 2.0)
		var bury := rng.randf_range(0.0, 0.5)
		_tube(kit, "wood", Vector3(x, y - 0.4, z), Vector3(x, y + 1.3 - bury, z), 0.06, 0.05, 5, grey.darkened(0.1))
		for s in range(7):
			var t := (s + 0.5) / 7.0
			var sx := lerpf(x, x2, t)
			var sz := lerpf(z, z + 2.0, t)
			var sy := lerpf(y, y2, t)
			var lean := Vector3(rng.randf_range(-0.08, 0.08), 0, 0)
			_tube(kit, "wood", Vector3(sx, sy - 0.3, sz), Vector3(sx, sy + 1.1 - bury, sz) + lean, 0.035, 0.03, 3, grey.lightened(rng.randf_range(-0.1, 0.1)), false)
		_tube(kit, "wood", Vector3(x, y + 0.85 - bury, z), Vector3(x2, y2 + 0.85 - bury, z + 2.0), 0.015, 0.015, 3, Color(0.3, 0.3, 0.3), false)
		_note("Fence", Vector2(x, z), 0.2, CLEAR_DECOR)
		z += 2.0
	_commit(root, kit, "SandFence")


## A yacht at anchor beyond the bar and two sailing boats far out.
func _build_boats(root: Node3D) -> void:
	var yacht: Node3D = load("res://models/boats/super_yacht02.glb").instantiate()
	yacht.name = "AnchoredYacht"
	root.add_child(yacht)
	yacht.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-70.0)).scaled(Vector3.ONE * 0.08), Vector3(-360.0, 0.25, -60.0))
	for b in range(2):
		var kit := {}
		var at: Vector3 = [Vector3(-620.0, 0.0, 180.0), Vector3(-900.0, 0.0, -320.0)][b]
		var yaw: float = [0.5, -0.9][b]
		var bs := Basis(Vector3.UP, yaw)
		_box(kit, "paint", Transform3D(bs, at + Vector3(0, 0.3, 0)), Vector3(2.4, 1.2, 9.0), WHITE)
		_box(kit, "paint", Transform3D(bs, at + Vector3(0, 0.95, -0.5)), Vector3(1.8, 0.4, 3.0), Color(0.75, 0.75, 0.72))
		_tube(kit, "metal", at + Vector3(0, 0.9, 0), at + Vector3(0, 12.0, 0), 0.08, 0.06, 5, Color(0.8, 0.8, 0.8))
		var st := _st(kit, "canvas")
		var fwd := bs * Vector3(0, 0, 1)
		var sail_n := bs * Vector3.RIGHT
		_tri(st, at + Vector3(0, 1.4, 0), at + Vector3(0, 11.8, 0), at + Vector3(0, 1.4, 0) - fwd * 4.5, sail_n, sail_n, sail_n, Color(0.97, 0.96, 0.92), sail_n)
		_tri(st, at + Vector3(0, 1.6, 0) + fwd * 0.3, at + Vector3(0, 10.5, 0), at + Vector3(0, 1.4, 0) + fwd * 4.2, sail_n, sail_n, sail_n, [Color(0.85, 0.3, 0.25), Color(0.25, 0.5, 0.8)][b], sail_n)
		_commit(root, kit, "Sailboat%d" % b)


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
