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

	# Palm groves, kept clear of the gates placed above.
	_build_palms(level_scene)

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
# under those, and no "ramp" either). Each structure is one mesh with a surface per material, plus
# box/cylinder/hull collision for every part a cart can touch, all of a structure's shapes in one
# body. _verify_seafront_clear() checks every footprint against the racing line.
#
# People-sized things (the huts, the bar and its furniture, the lifeguard towers, parasols and
# loungers) are laid out at life size and built inside a scale frame (_scale_about): at life size a
# lounger is shorter than a cart. _tri, _ground, _collider and _note all work through the frame, so a
# builder places things on the sand in its life-size layout and they land on the real sand scaled up.

const TRACK_HALF := 7.5
const CLEAR_BUILDING := 5.0   # metres past the track edge for anything solid
const CLEAR_DECOR := 3.0      # umbrellas, loungers, the fence
const PROP_SCALE := 1.6

const HUT_COLOURS := [Color(0.95, 0.52, 0.45), Color(0.55, 0.85, 0.72), Color(0.52, 0.74, 0.95),
		Color(0.98, 0.86, 0.45), Color(0.78, 0.66, 0.92), Color(0.35, 0.78, 0.80)]
const WHITE := Color(0.95, 0.94, 0.90)
const WOOD := Color(0.62, 0.48, 0.34)
const OLD_WOOD := Color(0.48, 0.42, 0.36)

var _tg: Node3D
var _curve: Curve3D
var _footprints: Array = []   # [name, centre Vector2, radius, clearance]
var _materials: Dictionary = {}
var _frame := Transform3D.IDENTITY       # layout space -> world, see _scale_about
var _frame_inv := Transform3D.IDENTITY


func _build_seafront(level: Node3D, tg: Node3D, curve: Curve3D) -> void:
	_tg = tg
	_curve = curve
	var root := Node3D.new()
	root.name = "Seafront"
	level.add_child(root)
	_build_grandstand(root)
	_build_beach_huts(root)
	_build_pier(root)
	# The middle tower stands on the land side: between the racing line and the sea there's no room.
	_build_lifeguard_tower(root, "LifeguardTowerNorth", Vector3(-56.0, 0.0, -340.0), 0.0,
			[Color(0.98, 0.80, 0.20), WHITE, Color(0.88, 0.22, 0.18)])
	_build_lifeguard_tower(root, "LifeguardTowerMid", Vector3(-27.0, 0.0, -118.0), 0.0,
			[Color(0.30, 0.74, 0.78), WHITE, Color(0.96, 0.50, 0.42)])
	_build_lifeguard_tower(root, "LifeguardTowerSouth", Vector3(-58.0, 0.0, 292.0), 15.0,
			[Color(0.96, 0.62, 0.70), WHITE, Color(0.20, 0.55, 0.75)])
	_build_lighthouse(root)
	_build_shipwreck(root)
	_build_surf_shack(root)
	# The fence before the parasols, which keep clear of it.
	_build_sand_fence(root)
	_build_umbrellas(root)
	_build_boats(root)
	_verify_seafront_clear()


## Builds what follows at `s` times its layout size, grown out from `pivot` (layout and world agree
## there). Call _end_scale() when the structure is done.
func _scale_about(pivot: Vector3, s: float) -> void:
	_frame = Transform3D(Basis.from_scale(Vector3.ONE * s), pivot * (1.0 - s))
	_frame_inv = _frame.affine_inverse()


func _end_scale() -> void:
	_frame = Transform3D.IDENTITY
	_frame_inv = Transform3D.IDENTITY


## Ground height under a layout point, in layout space: whatever stands on it lands on the real sand.
func _ground(x: float, z: float) -> float:
	var w := _frame * Vector3(x, 0.0, z)
	var h := float(_tg.call("_sample_cached_height", w.x, w.z))
	return (_frame_inv * Vector3(w.x, h, w.z)).y


## Lowest ground under a rectangle (for foundations that must not float).
func _ground_min(cx: float, cz: float, hx: float, hz: float) -> float:
	var lo := INF
	for i in range(3):
		for j in range(3):
			lo = minf(lo, _ground(cx + hx * (i - 1), cz + hz * (j - 1)))
	return lo


func _note(name: String, centre: Vector2, radius: float, clearance: float) -> void:
	var w := _frame * Vector3(centre.x, 0.0, centre.y)
	_footprints.append([name, Vector2(w.x, w.z), radius * _frame.basis.get_scale().x, clearance])


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
		# Rusted steel: dull, barely metallic.
		"rust":
			m.metallic = 0.2
			m.roughness = 0.85
		"canvas":
			m.roughness = 0.95
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"glow":
			m.emission_enabled = true
			m.emission = Color(1.0, 0.85, 0.55)
			m.emission_energy_multiplier = 2.5
			m.roughness = 0.1
		# The lifeguard towers' rotating beacons, at rest.
		"beacon":
			m.emission_enabled = true
			m.emission = Color(1.0, 0.42, 0.08)
			m.emission_energy_multiplier = 1.4
			m.roughness = 0.15
		"glass":
			m.metallic = 0.3
			m.roughness = 0.05
			m.albedo_color = Color(1, 1, 1, 0.45)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# One-sided, so the thatch's top and underside are separate faces with their own shading.
		"thatch":
			m.roughness = 1.0
		# Resin-coated boards, bottles: painted but shiny.
		"gloss":
			m.roughness = 0.22
			m.metallic_specular = 0.6
	_materials[key] = m
	return m


func _st(kit: Dictionary, key: String) -> SurfaceTool:
	if not kit.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		kit[key] = st
	return kit[key]


## One triangle facing `out` (Godot's front faces wind clockwise: front normal = (c - a) x (b - a)).
## Vertices go through the scale frame; it keeps the winding, being a uniform scale.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, col: Color, out: Vector3) -> void:
	st.set_color(col)
	var flip := (b - a).cross(c - a).dot(out) > 0.0
	var fb := _frame.basis.orthonormalized()
	st.set_normal(fb * na)
	st.add_vertex(_frame * a)
	st.set_normal(fb * (nc if flip else nb))
	st.add_vertex(_frame * (c if flip else b))
	st.set_normal(fb * (nb if flip else nc))
	st.add_vertex(_frame * (b if flip else c))


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


## A surface of revolution about the vertical through `c`: `profile` holds (radius, height above c)
## from the bottom up, walking the outside. Smooth round the axis, or faceted with `flat` (a lantern's
## panes). Returns its points, for a hull collider.
func _lathe(kit: Dictionary, key: String, c: Vector3, profile: Array, segs: int, col: Color, flat: bool = false) -> PackedVector3Array:
	var st := _st(kit, key)
	var pts := PackedVector3Array()
	for k in profile.size():
		var pk: Vector2 = profile[k]
		for j in segs:
			var a := TAU * j / segs
			pts.append(c + Vector3(cos(a) * pk.x, pk.y, sin(a) * pk.x))
	for k in profile.size() - 1:
		var p0: Vector2 = profile[k]
		var p1: Vector2 = profile[k + 1]
		var d := p1 - p0
		if d.length_squared() < 1e-10:
			continue
		var n2 := Vector2(d.y, -d.x).normalized()
		for j in segs:
			var t0 := TAU * j / segs
			var t1 := TAU * (j + 1) / segs
			var u0 := Vector3(cos(t0), 0.0, sin(t0))
			var u1 := Vector3(cos(t1), 0.0, sin(t1))
			var um := (u0 + u1).normalized()
			var out := um * n2.x + Vector3.UP * n2.y
			var n0 := out if flat else u0 * n2.x + Vector3.UP * n2.y
			var n1 := out if flat else u1 * n2.x + Vector3.UP * n2.y
			var q00 := c + u0 * p0.x + Vector3.UP * p0.y
			var q01 := c + u1 * p0.x + Vector3.UP * p0.y
			var q10 := c + u0 * p1.x + Vector3.UP * p1.y
			var q11 := c + u1 * p1.x + Vector3.UP * p1.y
			_tri(st, q00, q01, q11, n0, n1, n1, col, out)
			_tri(st, q00, q11, q10, n0, n1, n0, col, out)
	return pts


## A hipped roof over the rectangle x0..x1, z0..z1 at y = 0 of `xf`, its ridge `rise` above along the
## longer side, with an underside. Returns its corners, for a hull collider.
func _hip_roof(kit: Dictionary, key: String, xf: Transform3D, x0: float, x1: float, z0: float, z1: float, rise: float, col: Color) -> PackedVector3Array:
	var xm := (x0 + x1) * 0.5
	var zm := (z0 + z1) * 0.5
	var hx := (x1 - x0) * 0.5
	var hz := (z1 - z0) * 0.5
	var c00 := xf * Vector3(x0, 0, z0)
	var c10 := xf * Vector3(x1, 0, z0)
	var c01 := xf * Vector3(x0, 0, z1)
	var c11 := xf * Vector3(x1, 0, z1)
	var faces := []
	var r0: Vector3
	var r1: Vector3
	if hx >= hz:
		r0 = xf * Vector3(xm - (hx - hz), rise, zm)
		r1 = xf * Vector3(xm + (hx - hz), rise, zm)
		faces = [[c00, c10, r1, r0], [c01, c11, r1, r0], [c00, c01, r0], [c10, c11, r1]]
	else:
		r0 = xf * Vector3(xm, rise, zm - (hz - hx))
		r1 = xf * Vector3(xm, rise, zm + (hz - hx))
		faces = [[c00, c01, r1, r0], [c10, c11, r1, r0], [c00, c10, r0], [c01, c11, r1]]
	var up := xf.basis * Vector3.UP
	var st := _st(kit, key)
	for f in faces:
		var a: Vector3 = f[0]
		var b: Vector3 = f[1]
		var c: Vector3 = f[2]
		var n := (b - a).cross(c - a).normalized()
		if n.dot(up) < 0.0:
			n = -n
		_tri(st, a, b, c, n, n, n, col, n)
		if f.size() == 4:
			_tri(st, a, c, f[3], n, n, n, col, n)
	_quad(kit, key, [c00, c10, c11, c01], -up, col.darkened(0.35))
	return PackedVector3Array([c00, c10, c01, c11, r0, r1])


## Block capitals for painted signs, five cells high.
const GLYPHS := {
	"A": [".XX.", "X..X", "XXXX", "X..X", "X..X"],
	"D": ["XXX.", "X..X", "X..X", "X..X", "XXX."],
	"E": ["XXXX", "X...", "XXX.", "X...", "XXXX"],
	"F": ["XXXX", "X...", "XXX.", "X...", "X..."],
	"G": [".XXX", "X...", "X.XX", "X..X", ".XXX"],
	"I": ["XXX", ".X.", ".X.", ".X.", "XXX"],
	"L": ["X...", "X...", "X...", "X...", "XXXX"],
	"R": ["XXX.", "X..X", "XXX.", "X.X.", "X..X"],
	"U": ["X..X", "X..X", "X..X", "X..X", "XXXX"],
}


## `text` in GLYPHS, `cell` metres a cell, centred on `centre` and reading along `right`. It faces
## right x up, so a reader sees it the right way round.
func _pixel_text(kit: Dictionary, key: String, centre: Vector3, right: Vector3, up: Vector3, cell: float, text: String, col: Color) -> void:
	var width := -1
	for ch in text:
		width += (GLYPHS[ch][0] as String).length() + 1
	var face := right.cross(up).normalized()
	var origin := centre - right * (width * cell * 0.5) - up * (2.5 * cell)
	var x := 0
	for ch in text:
		var rows: Array = GLYPHS[ch]
		for r in 5:
			var row: String = rows[r]
			var i := 0
			while i < row.length():
				if row[i] != "X":
					i += 1
					continue
				var j := i
				while j < row.length() and row[j] == "X":
					j += 1
				var lo := origin + right * ((x + i) * cell) + up * ((4 - r) * cell)
				var span := right * ((j - i) * cell)
				_quad(kit, key, [lo, lo + span, lo + span + up * cell, lo + up * cell], face, col)
				i = j
		x += (rows[0] as String).length() + 1


## A low-poly rock: an icosphere pushed about by noise, flat shaded. The wreck's net heaps use it too.
## Returns its points (layout space), for a hull collider.
func _rock(kit: Dictionary, centre: Vector3, size: Vector3, seed_v: int, col: Color, key: String = "rock") -> PackedVector3Array:
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
	var pts := PackedVector3Array()
	for v in verts:
		var d: Vector3 = v
		var r := 1.0 + 0.28 * noise.get_noise_3dv(d * 1.3) + 0.08 * noise.get_noise_3dv(d * 4.0)
		var p := d * r
		# Flatten the tops and the bed a little: weathered, not round.
		p.y = clampf(p.y, -0.85, 0.7)
		pts.append(centre + p * size)
	var st := _st(kit, key)
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
	return pts


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


## Adds a shape at `xf` (layout space) to the body `name`Body under `parent` (at the origin), making
## the body on first use: one body holds all of a structure's shapes.
func _collider(parent: Node3D, name: String, shape: Shape3D, xf: Transform3D) -> void:
	var body := parent.get_node_or_null(name + "Body") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = name + "Body"
		parent.add_child(body)
	_scale_shape(shape, _frame.basis.get_scale().x)
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(_frame.basis.orthonormalized() * xf.basis, _frame * xf.origin)
	body.add_child(cs)


func _scale_shape(shape: Shape3D, s: float) -> void:
	if is_equal_approx(s, 1.0):
		return
	if shape is BoxShape3D:
		(shape as BoxShape3D).size *= s
	elif shape is CylinderShape3D:
		(shape as CylinderShape3D).radius *= s
		(shape as CylinderShape3D).height *= s
	elif shape is SphereShape3D:
		(shape as SphereShape3D).radius *= s
	elif shape is ConvexPolygonShape3D:
		var pts := (shape as ConvexPolygonShape3D).points
		for i in pts.size():
			pts[i] *= s
		(shape as ConvexPolygonShape3D).points = pts


func _box_collider(parent: Node3D, name: String, lo: Vector3, hi: Vector3, yaw_deg: float = 0.0) -> void:
	var shape := BoxShape3D.new()
	shape.size = hi - lo
	_collider(parent, name, shape, Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), (lo + hi) * 0.5))


## A box between two corners given in the frame `xf` (a structure's own axes).
func _box_in(parent: Node3D, name: String, xf: Transform3D, lo: Vector3, hi: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = hi - lo
	_collider(parent, name, shape, xf * Transform3D(Basis(), (lo + hi) * 0.5))


## A box of `size` centred on `centre`, its long (z) axis along `dir` and its y axis up.
func _box_along(parent: Node3D, name: String, centre: Vector3, dir: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var z := dir.normalized()
	var x := Vector3.UP.cross(z)
	if x.length_squared() < 1e-6:
		x = Vector3.RIGHT
	x = x.normalized()
	_collider(parent, name, shape, Transform3D(Basis(x, z.cross(x), z), centre))


## A cylinder from a to b.
func _rod_collider(parent: Node3D, name: String, a: Vector3, b: Vector3, r: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = a.distance_to(b)
	var axis := (b - a).normalized()
	if axis.y < 0.0:
		axis = -axis
	var basis := Basis() if axis.is_equal_approx(Vector3.UP) else Basis(Quaternion(Vector3.UP, axis))
	_collider(parent, name, shape, Transform3D(basis, (a + b) * 0.5))


func _hull_collider(parent: Node3D, name: String, pts: PackedVector3Array) -> void:
	var centre := Vector3.ZERO
	for p in pts:
		centre += p
	centre /= maxf(pts.size(), 1)
	var local := PackedVector3Array()
	for p in pts:
		local.append(p - centre)
	var shape := ConvexPolygonShape3D.new()
	shape.points = local
	_collider(parent, name, shape, Transform3D(Basis(), centre))


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
	var roof_shape := BoxShape3D.new()
	roof_shape.size = Vector3(back_x - x0 + 1.6, 0.3, z1 - z0 + 0.8)
	_collider(root, "Grandstand", roof_shape, roof_xf)
	_box_collider(root, "Grandstand", Vector3(x0 - 1.3, roof_y - 1.3, z0 - 0.4), Vector3(x0 - 1.05, roof_y - 0.4, z1 + 0.4))
	_box_collider(root, "Grandstand", Vector3(back_x, top + 1.0, z0 - 0.4), Vector3(back_x + 0.5, roof_y + 0.3, z1 + 0.4))
	for zc in [152.0, 162.0, 172.0, 182.0, 190.0]:
		_note("Grandstand", Vector2(x0, zc), 0.5, CLEAR_BUILDING)


## A row of striped bathing huts with their doors to the sea. Each is laid out at life size round the
## sea edge of its floor and built at PROP_SCALE.
func _build_beach_huts(root: Node3D) -> void:
	var kit := {}
	var w := 2.6
	var d := 2.8
	var front := -25.4
	var z := 26.0
	var i := 0
	while z < 72.0:
		_scale_about(Vector3(front, 0.0, z), PROP_SCALE)
		var x := front + 0.5 + d * 0.5
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
		_box_collider(root, "Hut%d" % i, Vector3(x - d * 0.5 - 0.5, g - 0.3, z - w * 0.5), Vector3(x + d * 0.5, floor_y + wall_h, z + w * 0.5))
		_hull_collider(root, "Hut%d" % i, PackedVector3Array([
			Vector3(x - d * 0.5 - 0.25, floor_y + wall_h, z - w * 0.5 - 0.2), Vector3(x + d * 0.5 + 0.25, floor_y + wall_h, z - w * 0.5 - 0.2),
			Vector3(x - d * 0.5 - 0.25, floor_y + wall_h, z + w * 0.5 + 0.2), Vector3(x + d * 0.5 + 0.25, floor_y + wall_h, z + w * 0.5 + 0.2),
			Vector3(x - d * 0.5 - 0.25, floor_y + wall_h + 1.0, z), Vector3(x + d * 0.5 + 0.25, floor_y + wall_h + 1.0, z)]))
		_note("Hut%d" % i, Vector2(x - d * 0.5 - 0.5, z), 0.2, CLEAR_BUILDING)
		_end_scale()
		z += (w + 0.9) * PROP_SCALE
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
	_box_collider(root, "Pier", Vector3(x_end, top - 0.6, z - half), Vector3(x_land - 1.0, top, z + half))
	_box_collider(root, "Pier", Vector3(x_end, top - 0.22, z - head_half), Vector3(head_x + 6.0, top, z + head_half))
	# Piles in pairs every 6m, braced.
	var x := x_land - 4.0
	while x > x_end - 0.1:
		var bed := _ground(x, z)
		for zz2 in [z - half + 0.2, z + half - 0.2]:
			_tube(kit, "wood", Vector3(x, bed - 0.8, zz2), Vector3(x, top - 0.22, zz2), 0.24, 0.22, 8, OLD_WOOD)
			_rod_collider(root, "Pier", Vector3(x, bed - 0.8, zz2), Vector3(x, top - 0.22, zz2), 0.26)
		_tube(kit, "wood", Vector3(x, bed + 0.2, z - half + 0.2), Vector3(x, top - 0.7, z + half - 0.2), 0.08, 0.08, 5, OLD_WOOD)
		_tube(kit, "wood", Vector3(x, top - 0.7, z - half + 0.2), Vector3(x, bed + 0.2, z + half - 0.2), 0.08, 0.08, 5, OLD_WOOD)
		_box_collider(root, "Pier", Vector3(x - 0.1, bed + 0.1, z - half + 0.2), Vector3(x + 0.1, top - 0.6, z + half - 0.2))
		x -= 6.0
	# Extra piles under the T-head.
	for hx in [x_end + 1.0, head_x, head_x + 5.0]:
		for hz in [z - head_half + 0.5, z - 4.0, z + 4.0, z + head_half - 0.5]:
			var b2 := _ground(hx, hz)
			_tube(kit, "wood", Vector3(hx, b2 - 0.8, hz), Vector3(hx, top - 0.22, hz), 0.26, 0.24, 8, OLD_WOOD)
			_rod_collider(root, "Pier", Vector3(hx, b2 - 0.8, hz), Vector3(hx, top - 0.22, hz), 0.27)
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
		_box_along(root, "Pier", (a + b) * 0.5 + Vector3(0, 0.53, 0), b - a, Vector3(0.14, 1.06, run_len + 0.1))
	# Lamp posts.
	var lx := x_land - 8.0
	while lx > head_x + 6.0:
		for zz3 in [z - half + 0.15, z + half - 0.15]:
			_tube(kit, "metal", Vector3(lx, top, zz3), Vector3(lx, top + 3.2, zz3), 0.07, 0.05, 6, Color(0.15, 0.25, 0.30))
			_block(kit, "glow", Vector3(lx - 0.16, top + 3.2, zz3 - 0.16), Vector3(lx + 0.16, top + 3.6, zz3 + 0.16), Color(1, 1, 1))
			_tube(kit, "metal", Vector3(lx, top + 3.6, zz3), Vector3(lx, top + 3.85, zz3), 0.26, 0.0, 6, Color(0.15, 0.25, 0.30))
			_rod_collider(root, "Pier", Vector3(lx, top, zz3), Vector3(lx, top + 3.85, zz3), 0.18)
		lx -= 18.0
	# Pavilion on the head.
	var pc := Vector3(head_x + 0.5, top, z)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			_tube(kit, "paint", pc + Vector3(cx * 3.0, 0, cz * 3.0), pc + Vector3(cx * 3.0, 3.2, cz * 3.0), 0.14, 0.14, 8, WHITE)
			_rod_collider(root, "Pier", pc + Vector3(cx * 3.0, 0, cz * 3.0), pc + Vector3(cx * 3.0, 3.2, cz * 3.0), 0.16)
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
	var roof_hull := PackedVector3Array([apex, pc + Vector3(0, 3.2, 0) + Vector3(-4.0, 0, -4.0), pc + Vector3(0, 3.2, 0) + Vector3(4.0, 0, -4.0)])
	for e in eaves:
		roof_hull.append(pc + (e as Vector3))
	roof_hull.append(pc + Vector3(-4.0, 3.2, 4.0))
	roof_hull.append(pc + Vector3(4.0, 3.2, 4.0))
	_hull_collider(root, "Pier", roof_hull)
	_commit(root, kit, "Pier")


## A lifeguard tower on braced stilts, in its own frame with the sea at -x: a cabin with a counter
## and a propped-up shutter to the sea, a railed balcony round it, a hipped roof with a loudspeaker
## and a beacon, LIFEGUARD boards over the front and back eaves, stairs down the back and a rescue
## board leaning on the stilts. Laid out at life size, built at PROP_SCALE. `paint` is the body, the
## trim and the roof colour.
func _build_lifeguard_tower(root: Node3D, name: String, at: Vector3, yaw_deg: float, paint: Array) -> void:
	_scale_about(Vector3(at.x, 0.0, at.z), PROP_SCALE)
	var kit := {}
	var g := _ground_min(at.x, at.z, 1.6, 1.6)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), Vector3(at.x, g, at.z))
	var body: Color = paint[0]
	var trim: Color = paint[1]
	var roof: Color = paint[2]
	var red := Color(0.86, 0.15, 0.13)
	var yellow := Color(0.98, 0.82, 0.18)
	var glass := Color(0.12, 0.18, 0.24)
	var deck_y := 3.05
	var top := deck_y + 2.2
	# Cabin (cx0..cx1 by +-cz) and balcony (bx0..bx1 by +-bz).
	var cx0 := -1.0
	var cx1 := 1.4
	var cz := 1.3
	var bx0 := -2.3
	var bx1 := 1.6
	var bz := 1.6

	# Stilts on concrete footings, X-braced on every side, a ring beam under the deck.
	var stilt := func(sx: float, sz: float, y: float) -> Vector3:
		var k := lerpf(1.35, 1.2, clampf(y / (deck_y - 0.2), 0.0, 1.0))
		return Vector3(sx * k, y, sz * k)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(kit, "paint", xf * Transform3D(Basis(), Vector3(sx * 1.35, -0.12, sz * 1.35)), Vector3(0.5, 0.42, 0.5), Color(0.74, 0.72, 0.68))
			_tube(kit, "wood", xf * (stilt.call(sx, sz, 0.08) as Vector3), xf * (stilt.call(sx, sz, deck_y - 0.2) as Vector3), 0.1, 0.085, 8, trim)
	var sides := [[Vector2(-1, -1), Vector2(-1, 1)], [Vector2(1, -1), Vector2(1, 1)], [Vector2(-1, -1), Vector2(1, -1)], [Vector2(-1, 1), Vector2(1, 1)]]
	for sd in sides:
		var a: Vector2 = sd[0]
		var b: Vector2 = sd[1]
		var a0: Vector3 = stilt.call(a.x, a.y, 0.45)
		var b0: Vector3 = stilt.call(b.x, b.y, 0.45)
		var a1: Vector3 = stilt.call(a.x, a.y, deck_y - 0.45)
		var b1: Vector3 = stilt.call(b.x, b.y, deck_y - 0.45)
		_tube(kit, "wood", xf * a0, xf * b1, 0.045, 0.045, 5, trim)
		_tube(kit, "wood", xf * b0, xf * a1, 0.045, 0.045, 5, trim)
		_tube(kit, "wood", xf * a0, xf * b0, 0.05, 0.05, 5, trim)
		_tube(kit, "wood", xf * (stilt.call(a.x, a.y, deck_y - 0.2) as Vector3), xf * (stilt.call(b.x, b.y, deck_y - 0.2) as Vector3), 0.08, 0.08, 6, trim)

	# Balcony: a painted edge beam under planks.
	_box(kit, "paint", xf * Transform3D(Basis(), Vector3((bx0 + bx1) * 0.5, deck_y - 0.17, 0)), Vector3(bx1 - bx0, 0.18, bz * 2.0), body.darkened(0.25))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	var pz := -bz
	while pz < bz - 0.01:
		_box(kit, "wood", xf * Transform3D(Basis(), Vector3((bx0 + bx1) * 0.5, deck_y - 0.04, pz + 0.1)), Vector3(bx1 - bx0 + 0.06, 0.08, 0.18), WOOD.lightened(rng.randf_range(-0.08, 0.1)))
		pz += 0.2

	# Cabin walls. The back has the door; the front is open above a counter.
	var wall := func(lo: Vector3, hi: Vector3, col: Color) -> void:
		_box(kit, "paint", xf * Transform3D(Basis(), (lo + hi) * 0.5), hi - lo, col)
	wall.call(Vector3(cx1 - 0.08, deck_y, -cz), Vector3(cx1, top, -0.45), body)
	wall.call(Vector3(cx1 - 0.08, deck_y, 0.45), Vector3(cx1, top, cz), body)
	wall.call(Vector3(cx1 - 0.08, deck_y + 2.0, -0.45), Vector3(cx1, top, 0.45), body)
	wall.call(Vector3(cx1 - 0.05, deck_y, -0.44), Vector3(cx1 - 0.02, deck_y + 2.0, 0.44), roof.darkened(0.2))
	wall.call(Vector3(cx1 - 0.02, deck_y + 1.35, -0.16), Vector3(cx1 + 0.005, deck_y + 1.7, 0.16), glass)
	for sz in [-1.0, 1.0]:
		wall.call(Vector3(cx0, deck_y, sz * cz - 0.04), Vector3(cx1, top, sz * cz + 0.04), body)
		# Window toward the sea and the lifeguard cross toward the back.
		var zf: float = sz * (cz + 0.04)
		wall.call(Vector3(-0.9, deck_y + 1.2, zf - 0.015), Vector3(-0.2, deck_y + 1.9, zf + 0.015), trim)
		wall.call(Vector3(-0.84, deck_y + 1.26, zf + sz * 0.012 - 0.01), Vector3(-0.26, deck_y + 1.84, zf + sz * 0.012 + 0.01), glass)
		wall.call(Vector3(0.12, deck_y + 1.1, zf - 0.015), Vector3(1.02, deck_y + 2.0, zf + 0.015), WHITE)
		wall.call(Vector3(0.27, deck_y + 1.47, zf + sz * 0.012 - 0.01), Vector3(0.87, deck_y + 1.63, zf + sz * 0.012 + 0.01), red)
		wall.call(Vector3(0.49, deck_y + 1.25, zf + sz * 0.012 - 0.01), Vector3(0.65, deck_y + 1.85, zf + sz * 0.012 + 0.01), red)
	wall.call(Vector3(cx0, deck_y, -cz), Vector3(cx0 + 0.08, deck_y + 1.0, cz), body)
	wall.call(Vector3(cx0, top - 0.25, -cz), Vector3(cx0 + 0.08, top, cz), body)
	for sz in [-1.0, 1.0]:
		wall.call(Vector3(cx0, deck_y, minf(sz * cz, sz * 1.1)), Vector3(cx0 + 0.08, top, maxf(sz * cz, sz * 1.1)), body)
	# A white band round the cabin at the counter, corner boards, the counter top.
	wall.call(Vector3(cx1, deck_y + 0.88, -cz), Vector3(cx1 + 0.015, deck_y + 1.0, -0.45), trim)
	wall.call(Vector3(cx1, deck_y + 0.88, 0.45), Vector3(cx1 + 0.015, deck_y + 1.0, cz), trim)
	wall.call(Vector3(cx0 - 0.015, deck_y + 0.88, -cz), Vector3(cx0, deck_y + 1.0, cz), trim)
	for sz in [-1.0, 1.0]:
		wall.call(Vector3(cx0, deck_y + 0.88, sz * (cz + 0.04) - 0.015), Vector3(cx1, deck_y + 1.0, sz * (cz + 0.04) + 0.015), trim)
	for sx in [cx0, cx1]:
		for sz in [-1.0, 1.0]:
			wall.call(Vector3(sx - 0.07, deck_y, sz * cz - 0.07), Vector3(sx + 0.07, top, sz * cz + 0.07), trim)
	wall.call(Vector3(cx0 - 0.28, deck_y + 1.0, -1.12), Vector3(cx0 + 0.3, deck_y + 1.06, 1.12), WOOD)
	# First-aid box by the door.
	wall.call(Vector3(cx1, deck_y + 1.1, 0.62), Vector3(cx1 + 0.12, deck_y + 1.45, 1.02), WHITE)
	wall.call(Vector3(cx1 + 0.12, deck_y + 1.25, 0.76), Vector3(cx1 + 0.125, deck_y + 1.3, 0.88), red)
	wall.call(Vector3(cx1 + 0.12, deck_y + 1.21, 0.8), Vector3(cx1 + 0.125, deck_y + 1.34, 0.84), red)
	# Shutter hinged under the header, propped out over the counter as an awning.
	var hinge := Vector3(cx0 - 0.04, top - 0.25, 0)
	var tilt := deg_to_rad(18.0)
	var out_dir := Vector3(-cos(tilt), -sin(tilt), 0)
	_box(kit, "paint", xf * Transform3D(Basis(Vector3.BACK, tilt), hinge + out_dir * 0.48), Vector3(0.96, 0.05, 2.3), roof)
	for sz in [-0.95, 0.95]:
		_tube(kit, "metal", xf * Vector3(cx0 - 0.02, deck_y + 1.06, sz), xf * (hinge + out_dir * 0.9 + Vector3(0, -0.03, sz)), 0.018, 0.018, 4, Color(0.75, 0.75, 0.78))
	# Inside: a high chair, binoculars on the counter.
	var seat := Vector3(-0.35, deck_y, 0.2)
	for lx in [-0.2, 0.2]:
		for lz in [-0.2, 0.2]:
			_tube(kit, "wood", xf * (seat + Vector3(lx, 0, lz)), xf * (seat + Vector3(lx * 0.8, 0.8, lz * 0.8)), 0.025, 0.025, 4, trim)
	_box(kit, "paint", xf * Transform3D(Basis(), seat + Vector3(0, 0.82, 0)), Vector3(0.45, 0.05, 0.45), roof)
	_box(kit, "paint", xf * Transform3D(Basis(), seat + Vector3(0.22, 1.12, 0)), Vector3(0.05, 0.55, 0.45), roof)
	for bzz in [0.45, 0.53]:
		_tube(kit, "metal", xf * Vector3(cx0 - 0.08, deck_y + 1.1, bzz), xf * Vector3(cx0 - 0.24, deck_y + 1.1, bzz), 0.035, 0.04, 8, Color(0.1, 0.1, 0.11))

	# Hipped roof with a fascia, a beacon and a loudspeaker on a short mast.
	var rx0 := cx0 - 0.95
	var rx1 := cx1 + 0.45
	var rz := cz + 0.45
	var roof_pts := _hip_roof(kit, "paint", xf * Transform3D(Basis(), Vector3(0, top, 0)), rx0, rx1, -rz, rz, 0.95, roof)
	for e in [[Vector3(rx0, top - 0.18, -rz), Vector3(rx1, top, -rz + 0.06)], [Vector3(rx0, top - 0.18, rz - 0.06), Vector3(rx1, top, rz)],
			[Vector3(rx0, top - 0.18, -rz), Vector3(rx0 + 0.06, top, rz)], [Vector3(rx1 - 0.06, top - 0.18, -rz), Vector3(rx1, top, rz)]]:
		wall.call(e[0], e[1], trim)
	var apex := Vector3((rx0 + rx1) * 0.5, top + 0.95, 0)
	_tube(kit, "metal", xf * (apex - Vector3(0, 0.1, 0)), xf * (apex + Vector3(0, 0.95, 0)), 0.04, 0.035, 6, Color(0.8, 0.8, 0.82))
	_tube(kit, "beacon", xf * (apex + Vector3(0, 0.95, 0)), xf * (apex + Vector3(0, 1.18, 0)), 0.11, 0.11, 10, Color(1.0, 0.55, 0.2))
	_tube(kit, "metal", xf * (apex + Vector3(0, 1.18, 0)), xf * (apex + Vector3(0, 1.24, 0)), 0.12, 0.06, 10, Color(0.2, 0.2, 0.22))
	var horn := apex + Vector3(0, 0.62, 0)
	_tube(kit, "paint", xf * horn, xf * (horn + Vector3(-0.45, -0.1, 0)), 0.06, 0.2, 10, WHITE)
	_tube(kit, "paint", xf * (horn + Vector3(-0.44, -0.098, 0)), xf * (horn + Vector3(-0.46, -0.102, 0)), 0.17, 0.17, 10, Color(0.15, 0.15, 0.16), false)

	# LIFEGUARD boards standing on the front and back eaves.
	for side in [-1.0, 1.0]:
		var ex := rx0 + 0.03 if side < 0.0 else rx1 - 0.03
		var face := Vector3(side, 0, 0)
		var right := Vector3(0, 0, -side)
		var bc := Vector3(ex, top + 0.28, 0)
		_box(kit, "paint", xf * Transform3D(Basis(), bc), Vector3(0.06, 0.6, 2.7), WHITE)
		_box(kit, "paint", xf * Transform3D(Basis(), bc + face * 0.02), Vector3(0.04, 0.5, 2.6), red)
		_pixel_text(kit, "paint", xf * (bc + face * 0.045), xf.basis * right, xf.basis * Vector3.UP, 0.056, "LIFEGUARD", yellow)

	# Railing round the balcony, open at the head of the stairs.
	var runs := [[Vector3(bx0, 0, -bz), Vector3(bx0, 0, bz)], [Vector3(bx0, 0, -bz), Vector3(bx1, 0, -bz)], [Vector3(bx0, 0, bz), Vector3(bx1, 0, bz)],
		[Vector3(bx1, 0, -bz), Vector3(bx1, 0, -0.55)], [Vector3(bx1, 0, 0.55), Vector3(bx1, 0, bz)]]
	for r in runs:
		var a: Vector3 = (r[0] as Vector3) + Vector3(0, deck_y, 0)
		var b: Vector3 = (r[1] as Vector3) + Vector3(0, deck_y, 0)
		var posts := maxi(1, ceili(a.distance_to(b) / 0.8))
		for p in range(posts + 1):
			var pp := a.lerp(b, float(p) / posts)
			_box(kit, "paint", xf * Transform3D(Basis(), pp + Vector3(0, 0.5, 0)), Vector3(0.07, 1.0, 0.07), trim)
		_tube(kit, "paint", xf * (a + Vector3(0, 1.0, 0)), xf * (b + Vector3(0, 1.0, 0)), 0.04, 0.04, 6, trim)
		_tube(kit, "paint", xf * (a + Vector3(0, 0.5, 0)), xf * (b + Vector3(0, 0.5, 0)), 0.025, 0.025, 5, trim)
		_box_along(root, name, xf * ((a + b) * 0.5 + Vector3(0, 0.52, 0)), xf.basis * (b - a), Vector3(0.1, 1.05, a.distance_to(b) + 0.08))
	_lifebuoy(kit, xf * Vector3(bx0 - 0.09, deck_y + 0.55, -0.7), xf.basis * Vector3.LEFT, 0.32, 0.07)
	# Rescue tube clipped to the side rail.
	var rt0 := Vector3(-1.7, deck_y + 0.42, bz + 0.1)
	_tube(kit, "gloss", xf * rt0, xf * (rt0 + Vector3(0.75, 0, 0)), 0.09, 0.09, 8, red)
	_tube(kit, "gloss", xf * (rt0 + Vector3(0.75, 0, 0)), xf * (rt0 + Vector3(0.87, 0, 0)), 0.09, 0.03, 8, red)
	_tube(kit, "gloss", xf * rt0, xf * (rt0 - Vector3(0.12, 0, 0)), 0.09, 0.03, 8, red)
	_tube(kit, "paint", xf * (rt0 - Vector3(0.1, 0, 0)), xf * Vector3(-2.0, deck_y + 1.0, bz), 0.012, 0.012, 3, yellow, false)

	# Stairs down the back: stringers, treads, handrails.
	var foot_x := 5.4
	var fw := xf * Vector3(foot_x, 0, 0)
	var foot_y := _ground(fw.x, fw.z) - g
	var s_top := Vector3(bx1, deck_y, 0)
	var s_foot := Vector3(foot_x, foot_y, 0)
	var run := s_foot - s_top
	var slope := atan2(-run.y, run.x)
	var steps := maxi(4, roundi(-run.y / 0.19))
	for i in steps:
		var p := s_top.lerp(s_foot, (i + 1.0) / (steps + 1.0)) - Vector3(0, 0.025, 0)
		_box(kit, "wood", xf * Transform3D(Basis(), p), Vector3(run.x / (steps + 1.0) + 0.05, 0.05, 1.0), WOOD.lightened(0.05))
	var smid := (s_top + s_foot) * 0.5
	for sz in [-0.55, 0.55]:
		_box(kit, "paint", xf * Transform3D(Basis(Vector3.BACK, -slope), smid + Vector3(0, -0.12, sz)), Vector3(run.length() + 0.1, 0.24, 0.06), trim)
		var h0 := s_top + Vector3(0, 0.95, sz + signf(sz) * 0.04)
		var h1 := s_foot + Vector3(0, 0.95, sz + signf(sz) * 0.04)
		_tube(kit, "paint", xf * h0, xf * h1, 0.035, 0.035, 6, trim)
		for t in [0.0, 0.5, 1.0]:
			var hp := h0.lerp(h1, t)
			_tube(kit, "paint", xf * (hp - Vector3(0, 0.95, 0)), xf * hp, 0.03, 0.03, 5, trim)
		_box_along(root, name, xf * (smid + Vector3(0, 0.45, sz + signf(sz) * 0.04)), xf.basis * run, Vector3(0.08, 1.0, run.length()))
	_box(kit, "paint", xf * Transform3D(Basis(), s_foot + Vector3(0.35, -0.08, 0)), Vector3(0.9, 0.2, 1.4), Color(0.74, 0.72, 0.68))
	_box_along(root, name, xf * (smid + Vector3(0, -0.15, 0)), xf.basis * run, Vector3(1.2, 0.3, run.length()))

	# Rescue board leaning on the stilts, the flag on the balcony's front corner.
	var bf := xf * Vector3(0.25, 0, -2.25)
	var board_foot := Vector3(0.25, _ground(bf.x, bf.z) - g - 0.03, -2.25)
	var board_top := Vector3(0.25, deck_y - 0.75, -1.42)
	var along := (board_top - board_foot).normalized()
	var bx := Vector3(-1, 0, 0)
	var board_basis := Basis(bx, along, bx.cross(along))
	_surfboard(kit, xf * Transform3D(board_basis, board_foot), board_foot.distance_to(board_top) + 0.3, 1, 1, red, yellow, WHITE)
	_box_along(root, name, xf * board_foot.lerp(board_top, 0.55), xf.basis * along, Vector3(0.6, 0.15, board_foot.distance_to(board_top) + 0.3))
	var pole_foot := Vector3(bx0 + 0.08, deck_y, bz - 0.08)
	var pole_top := pole_foot + Vector3(0, 4.3, 0)
	_tube(kit, "metal", xf * pole_foot, xf * pole_top, 0.04, 0.03, 6, Color(0.82, 0.82, 0.84))
	_rod_collider(root, name, xf * pole_foot, xf * pole_top, 0.06)
	# Red over yellow, streaming inland in the sea breeze.
	var fst := _st(kit, "canvas")
	var fcols := [red, yellow]
	for row in 2:
		for col_i in 4:
			var u0 := col_i / 4.0
			var u1 := (col_i + 1) / 4.0
			var v0 := row * 0.36
			var v1 := (row + 1) * 0.36
			var q := func(u: float, v: float) -> Vector3:
				return xf * (pole_top + Vector3(0.05 + u * 1.1, -0.05 - v, 0.09 * sin(u * PI * 1.6)))
			var fnn := xf.basis * Vector3(0, 0, 1)
			_tri(fst, q.call(u0, v0), q.call(u1, v0), q.call(u1, v1), fnn, fnn, fnn, fcols[row], fnn)
			_tri(fst, q.call(u0, v0), q.call(u1, v1), q.call(u0, v1), fnn, fnn, fnn, fcols[row], fnn)

	_commit(root, kit, name)
	# Collision: the braced stilts, the balcony, the cabin, the roof and its boards.
	_box_in(root, name, xf, Vector3(-1.45, -0.4, -1.45), Vector3(1.45, deck_y - 0.26, 1.45))
	_box_in(root, name, xf, Vector3(bx0, deck_y - 0.26, -bz), Vector3(bx1, deck_y, bz))
	_box_in(root, name, xf, Vector3(cx0, deck_y, -cz - 0.07), Vector3(cx1 + 0.12, top, cz + 0.07))
	_hull_collider(root, name, roof_pts)
	_box_in(root, name, xf, Vector3(rx0 - 0.05, top - 0.2, -1.35), Vector3(rx0 + 0.1, top + 0.58, 1.35))
	_box_in(root, name, xf, Vector3(rx1 - 0.1, top - 0.2, -1.35), Vector3(rx1 + 0.05, top + 0.58, 1.35))
	_note(name, Vector2(at.x, at.z), 3.2, CLEAR_BUILDING)
	var sf := xf * Vector3(4.2, 0, 0)
	_note(name + "Stairs", Vector2(sf.x, sf.z), 1.6, CLEAR_BUILDING)
	_end_scale()


# --- Lighthouse -----------------------------------------------------------------------------------
# A banded tower on a masonry terrace on a rock islet off the north end of the bay: a granite plinth
# and door, staircase windows spiralling up, a corbelled gallery with a railing, the watch room, a
# twelve-sided lantern round a brass-ringed lens, a red dome with a ventilator ball and a vane. The
# keeper's cottage stands in a walled yard on the landward side, with steps down to a jetty. The sea
# round the islet is shallow enough to wade, so every part has collision.

const LIGHTHOUSE_AT := Vector3(-100.0, 0.0, -394.0)
const LH_TERRACE := 3.4      # terrace and yard paving above the sea
const LH_SHAFT := 26.0       # terrace to the gallery floor
const LH_R_FOOT := 3.8
const LH_R_TOP := 2.35


## The shaft's radius at height t (0..1) up it: a straight taper flaring out at the foot.
func _lh_radius(t: float) -> float:
	return LH_R_TOP + 1.0 * (1.0 - t) + 0.45 * pow(1.0 - t, 4.0)


func _build_lighthouse(root: Node3D) -> void:
	var kit := {}
	var name := "Lighthouse"
	var c := LIGHTHOUSE_AT
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var ty := LH_TERRACE
	var red := Color(0.80, 0.14, 0.12)
	var iron := Color(0.15, 0.16, 0.18)
	var granite := Color(0.62, 0.60, 0.56)
	var stone := Color(0.84, 0.80, 0.72)
	var masonry := Color(0.68, 0.61, 0.50)
	var brass := Color(0.78, 0.62, 0.30)
	var dark_glass := Color(0.10, 0.14, 0.18)
	var shutter_green := Color(0.16, 0.40, 0.30)
	var yard_x0 := 4.5
	var yard_x1 := 16.0
	var yard_hz := 6.0

	# The islet: rock heaped under the terraces, boulders round its foot.
	var sand_rock := Color(0.74, 0.68, 0.60)
	var masses := [[Vector3(0, -0.6, 0), Vector3(10.5, 4.4, 9.5), 11], [Vector3(10.5, -0.7, 0.5), Vector3(9.0, 4.0, 8.0), 12],
		[Vector3(3.0, -0.9, -6.5), Vector3(7.0, 3.4, 4.5), 13], [Vector3(5.0, -0.9, 7.0), Vector3(7.5, 3.4, 4.5), 14]]
	for m in masses:
		_hull_collider(root, name, _rock(kit, c + (m[0] as Vector3), m[1], m[2], sand_rock))
	for i in range(16):
		var a := TAU * i / 16.0 + rng.randf_range(-0.12, 0.12)
		# Leave the landing on the landward side clear.
		if absf(wrapf(a, -PI, PI)) < 0.3:
			continue
		var r := Vector2(19.0 * cos(a), 13.0 * sin(a)) * rng.randf_range(0.92, 1.08)
		var bp := c + Vector3(6.0 + r.x, 0, r.y)
		var s := rng.randf_range(1.6, 3.4)
		var bed := maxf(_ground(bp.x, bp.z), -2.0)
		var rock_pts := _rock(kit, Vector3(bp.x, bed + s * 0.3, bp.z), Vector3(s * 1.25, s * 0.8, s), 100 + i, sand_rock.darkened(rng.randf_range(0.0, 0.22)))
		_hull_collider(root, name, rock_pts)

	# Round terrace in coursed masonry, the yard beside it on the landward side.
	var course := 0.62
	var y := -1.6
	var k := 0
	while y < ty - 0.25:
		var y1 := minf(y + course, ty - 0.25)
		var col := masonry.darkened(0.1 * (k % 2) + rng.randf_range(0.0, 0.04))
		var r0 := 8.0 - 0.4 * (y + 1.6) / (ty + 1.35)
		var r1 := 8.0 - 0.4 * (y1 + 1.6) / (ty + 1.35)
		_lathe(kit, "paint", c, [Vector2(r0, y), Vector2(r1, y1)], 40, col)
		_block(kit, "paint", Vector3(c.x + yard_x0, y, c.z - yard_hz), Vector3(c.x + yard_x1, y1, c.z + yard_hz), col)
		y = y1
		k += 1
	_lathe(kit, "paint", c, [Vector2(7.6, ty - 0.25), Vector2(7.75, ty - 0.25), Vector2(7.85, ty - 0.2), Vector2(7.85, ty), Vector2(0.0, ty)], 40, stone)
	_block(kit, "paint", Vector3(c.x + yard_x0, ty - 0.25, c.z - yard_hz - 0.1), Vector3(c.x + yard_x1 + 0.1, ty, c.z + yard_hz + 0.1), stone)
	var terrace := CylinderShape3D.new()
	terrace.radius = 7.9
	terrace.height = ty + 2.0
	_collider(root, name, terrace, Transform3D(Basis(), c + Vector3(0, (ty - 2.0) * 0.5, 0)))
	_box_collider(root, name, Vector3(c.x + yard_x0, -2.0, c.z - yard_hz - 0.1), Vector3(c.x + yard_x1 + 0.1, ty, c.z + yard_hz + 0.1))

	# Parapet: whitewashed with a stone coping, round the terrace (but where it opens into the yard)
	# and round the yard, open at the landing steps.
	var walls := []
	var arc_from := asin(yard_hz / 7.6)
	var segs := 18
	for i in segs:
		var a0 := lerpf(arc_from, TAU - arc_from, float(i) / segs)
		var a1 := lerpf(arc_from, TAU - arc_from, float(i + 1) / segs)
		walls.append([c + Vector3(cos(a0) * 7.6, 0, sin(a0) * 7.6), c + Vector3(cos(a1) * 7.6, 0, sin(a1) * 7.6)])
	var yx0 := c.x + 7.6 * cos(arc_from)
	walls.append([Vector3(yx0, 0, c.z - yard_hz + 0.1), Vector3(c.x + yard_x1 - 0.1, 0, c.z - yard_hz + 0.1)])
	walls.append([Vector3(yx0, 0, c.z + yard_hz - 0.1), Vector3(c.x + yard_x1 - 0.1, 0, c.z + yard_hz - 0.1)])
	walls.append([Vector3(c.x + yard_x1 - 0.1, 0, c.z - yard_hz + 0.1), Vector3(c.x + yard_x1 - 0.1, 0, c.z - 1.3)])
	walls.append([Vector3(c.x + yard_x1 - 0.1, 0, c.z + 1.3), Vector3(c.x + yard_x1 - 0.1, 0, c.z + yard_hz - 0.1)])
	for wl in walls:
		var a: Vector3 = wl[0]
		var b: Vector3 = wl[1]
		var mid := (a + b) * 0.5
		var dir := b - a
		var bas := Basis(Vector3.UP, atan2(dir.x, dir.z))
		_box(kit, "paint", Transform3D(bas, Vector3(mid.x, ty + 0.4, mid.z)), Vector3(0.36, 0.8, dir.length() + 0.12), WHITE)
		_box(kit, "paint", Transform3D(bas, Vector3(mid.x, ty + 0.86, mid.z)), Vector3(0.48, 0.12, dir.length() + 0.2), stone)
		_box_along(root, name, Vector3(mid.x, ty + 0.46, mid.z), dir, Vector3(0.48, 0.92, dir.length() + 0.2))

	# Granite plinth with steps up to the door.
	var base := c + Vector3(0, ty, 0)
	_lathe(kit, "paint", base, [Vector2(4.45, 0.0), Vector2(4.45, 1.25), Vector2(4.6, 1.3), Vector2(4.6, 1.5), Vector2(LH_R_FOOT + 0.05, 1.5)], 32, granite)
	var plinth := CylinderShape3D.new()
	plinth.radius = 4.6
	plinth.height = 1.5
	_collider(root, name, plinth, Transform3D(Basis(), base + Vector3(0, 0.75, 0)))
	for s in 5:
		var sx := 4.45 + (5 - s) * 0.36
		_block(kit, "paint", base + Vector3(4.2, 0, -0.95), base + Vector3(sx, 0.3 * (s + 1), 0.95), granite.lightened(0.04 * (s % 2)))
	_box_along(root, name, base + Vector3(5.25, 0.55, 0), Vector3(1.8, -1.5, 0), Vector3(2.2, 0.4, 2.4))

	# The shaft, banded red and white, with the flare at its foot.
	var y0 := ty + 1.5
	var top := ty + LH_SHAFT
	var bands := 6
	var shaft_pts := PackedVector3Array()
	for b in bands:
		var prof := []
		for q in 5:
			var t := (b + q / 4.0) / bands
			prof.append(Vector2(_lh_radius(t), lerpf(y0, top, t) - c.y))
		_lathe(kit, "paint", c, prof, 32, WHITE if b % 2 == 0 else red)
	for q in 9:
		var t := q / 8.0
		for j in 12:
			var a := TAU * j / 12.0
			shaft_pts.append(c + Vector3(cos(a), 0, sin(a)) * _lh_radius(t) + Vector3(0, lerpf(y0, top, t), 0))
	_hull_collider(root, name, shaft_pts)

	# Door: a granite surround and a pediment, facing the yard.
	var rd := _lh_radius(0.03)
	_box(kit, "paint", Transform3D(Basis(), c + Vector3(rd - 0.05, y0 + 1.35, 0)), Vector3(0.4, 2.7, 1.8), granite.lightened(0.08))
	_box(kit, "paint", Transform3D(Basis(), c + Vector3(rd + 0.08, y0 + 1.15, 0)), Vector3(0.2, 2.3, 1.2), Color(0.12, 0.30, 0.36))
	_box(kit, "metal", Transform3D(Basis(), c + Vector3(rd + 0.2, y0 + 1.1, 0.4)), Vector3(0.06, 0.12, 0.06), brass)
	_gable_roof(kit, "paint", Transform3D(Basis(Vector3.UP, PI * 0.5), c + Vector3(rd + 0.15, y0 + 2.7, 0)), 2.2, 0.75, 0.55, granite.lightened(0.08), granite.lightened(0.12))
	# Staircase windows spiralling up, in stone surrounds with sills.
	for i in 6:
		var a := 1.0 + i * 1.05
		var wy := y0 + 4.2 + i * 3.45
		var r := _lh_radius((wy - y0) / (top - y0))
		var u := Vector3(cos(a), 0, sin(a))
		var bas := Basis(Vector3.UP, -a)
		var wc := c + Vector3(0, wy, 0)
		_box(kit, "paint", Transform3D(bas, wc + u * (r - 0.02)), Vector3(0.24, 1.45, 0.95), stone)
		_box(kit, "paint", Transform3D(bas, wc + u * (r + 0.03)), Vector3(0.24, 1.15, 0.62), dark_glass)
		_box(kit, "paint", Transform3D(bas, wc + u * (r + 0.1) - Vector3(0, 0.66, 0)), Vector3(0.3, 0.09, 1.05), stone)

	# Corbelled cornice under the gallery, the gallery and its railing.
	_lathe(kit, "paint", c, [Vector2(LH_R_TOP - 0.02, top - 1.4), Vector2(LH_R_TOP + 0.25, top - 1.0), Vector2(LH_R_TOP + 0.75, top - 0.55), Vector2(LH_R_TOP + 1.2, top - 0.15)], 32, WHITE)
	for i in 20:
		var a := TAU * (i + 0.5) / 20.0
		var u := Vector3(cos(a), 0, sin(a))
		_box(kit, "paint", Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.BACK, 0.75), c + u * (LH_R_TOP + 0.55) + Vector3(0, top - 0.75, 0)), Vector3(1.05, 0.2, 0.22), stone)
	var gal_r := LH_R_TOP + 1.35
	_lathe(kit, "paint", c, [Vector2(LH_R_TOP + 1.2, top - 0.15), Vector2(gal_r, top - 0.15), Vector2(gal_r, top + 0.15), Vector2(0.0, top + 0.15)], 32, iron)
	var rail_r := gal_r - 0.12
	for i in 28:
		var a := TAU * i / 28.0
		var p := c + Vector3(cos(a) * rail_r, top + 0.15, sin(a) * rail_r)
		_block(kit, "metal", p + Vector3(-0.03, 0, -0.03), p + Vector3(0.03, 1.1, 0.03), iron)
		var a1 := TAU * (i + 1) / 28.0
		var p1 := c + Vector3(cos(a1) * rail_r, top + 0.15, sin(a1) * rail_r)
		_tube(kit, "metal", p + Vector3(0, 1.1, 0), p1 + Vector3(0, 1.1, 0), 0.04, 0.04, 5, iron, false)
		_tube(kit, "metal", p + Vector3(0, 0.6, 0), p1 + Vector3(0, 0.6, 0), 0.022, 0.022, 4, iron, false)
		_tube(kit, "metal", p + Vector3(0, 0.12, 0), p1 + Vector3(0, 0.12, 0), 0.022, 0.022, 4, iron, false)
	var gallery := CylinderShape3D.new()
	gallery.radius = gal_r
	gallery.height = 1.6
	_collider(root, name, gallery, Transform3D(Basis(), c + Vector3(0, top + 0.5, 0)))

	# Watch room with portholes and a door onto the gallery.
	var wr := LH_R_TOP - 0.2
	_lathe(kit, "paint", c, [Vector2(wr, top + 0.15), Vector2(wr, top + 2.3)], 32, WHITE)
	_lathe(kit, "paint", c, [Vector2(wr, top + 2.3), Vector2(wr + 0.4, top + 2.4), Vector2(wr + 0.4, top + 2.55), Vector2(1.9, top + 2.55)], 32, iron)
	for i in 3:
		var a := PI * 0.5 + i * PI * 0.5
		var u := Vector3(cos(a), 0, sin(a))
		var pc := c + Vector3(0, top + 1.3, 0)
		_tube(kit, "metal", pc + u * (wr - 0.05), pc + u * (wr + 0.07), 0.36, 0.36, 14, brass)
		_tube(kit, "paint", pc + u * (wr - 0.04), pc + u * (wr + 0.09), 0.28, 0.28, 14, dark_glass)
	_box(kit, "paint", Transform3D(Basis(), c + Vector3(wr + 0.02, top + 1.15, 0)), Vector3(0.1, 1.9, 0.8), Color(0.12, 0.30, 0.36))

	# Lantern: a dark parapet, twelve panes between mullions, the lens inside on its pedestal.
	var l0 := top + 2.55
	_lathe(kit, "paint", c, [Vector2(1.85, l0), Vector2(1.85, l0 + 0.75)], 12, iron, true)
	_lathe(kit, "glass", c, [Vector2(1.8, l0 + 0.75), Vector2(1.8, l0 + 3.0)], 12, Color(0.85, 0.93, 0.95), true)
	for j in 12:
		var a := TAU * j / 12.0
		var p := c + Vector3(cos(a) * 1.81, 0, sin(a) * 1.81)
		_block(kit, "metal", p + Vector3(-0.04, l0 + 0.75, -0.04), p + Vector3(0.04, l0 + 3.0, 0.04), iron)
		var a1 := TAU * (j + 1) / 12.0
		var p1 := c + Vector3(cos(a1) * 1.81, 0, sin(a1) * 1.81)
		for hy in [0.75, 1.9, 3.0]:
			_tube(kit, "metal", p + Vector3(0, l0 + hy, 0), p1 + Vector3(0, l0 + hy, 0), 0.035, 0.035, 4, iron, false)
	_tube(kit, "metal", c + Vector3(0, l0 + 0.75, 0), c + Vector3(0, l0 + 1.1, 0), 0.45, 0.35, 10, iron)
	_tube(kit, "glow", c + Vector3(0, l0 + 1.25, 0), c + Vector3(0, l0 + 2.45, 0), 0.32, 0.32, 12, Color(1, 1, 1))
	var lens := []
	for q in 9:
		var t := q / 8.0
		lens.append(Vector2(0.55 + 0.28 * sin(PI * t), l0 + 1.1 + t * 1.55 - c.y))
	_lathe(kit, "glass", c, lens, 16, Color(0.75, 0.95, 0.85))
	for q in range(0, 9, 2):
		var lp: Vector2 = lens[q]
		_lathe(kit, "metal", c, [Vector2(lp.x - 0.01, lp.y - 0.03), Vector2(lp.x + 0.04, lp.y), Vector2(lp.x - 0.01, lp.y + 0.03)], 16, brass)
	for j in 6:
		var a := TAU * j / 6.0
		var prev := Vector3.ZERO
		for q in 9:
			var lp: Vector2 = lens[q]
			var p := c + Vector3(cos(a) * (lp.x + 0.02), lp.y, sin(a) * (lp.x + 0.02))
			if q > 0:
				_tube(kit, "metal", prev, p, 0.018, 0.018, 4, brass, false)
			prev = p

	# Dome: an overhanging rim, red plates between ribs, a ventilator ball, the spike and a vane.
	var d0 := l0 + 3.0
	_lathe(kit, "paint", c, [Vector2(1.8, d0), Vector2(2.1, d0 + 0.1), Vector2(2.1, d0 + 0.2), Vector2(1.95, d0 + 0.25)], 24, iron)
	var dome := []
	for q in 11:
		var phi := PI * 0.5 * q / 10.0
		dome.append(Vector2(1.95 * cos(phi), d0 + 0.25 + 1.65 * sin(phi) - c.y))
	_lathe(kit, "paint", c, dome, 24, red)
	for j in 12:
		var a := TAU * j / 12.0
		var prev := Vector3.ZERO
		for q in 10:
			var dp: Vector2 = dome[q]
			var p := c + Vector3(cos(a) * (dp.x + 0.03), dp.y, sin(a) * (dp.x + 0.03))
			if q > 0:
				_tube(kit, "metal", prev, p, 0.035, 0.035, 4, iron, false)
			prev = p
	var dtop := d0 + 1.9
	_tube(kit, "metal", c + Vector3(0, dtop - 0.05, 0), c + Vector3(0, dtop + 0.3, 0), 0.18, 0.14, 10, iron)
	var ball := []
	for q in 9:
		var phi := -PI * 0.5 + PI * q / 8.0
		ball.append(Vector2(0.4 * cos(phi), dtop + 0.68 + 0.4 * sin(phi) - c.y))
	_lathe(kit, "metal", c, ball, 16, iron)
	var spike := c + Vector3(0, dtop + 1.08, 0)
	_tube(kit, "metal", spike, spike + Vector3(0, 1.5, 0), 0.05, 0.0, 6, iron)
	var vane := spike + Vector3(0, 0.75, 0)
	_tube(kit, "metal", vane + Vector3(-0.45, -0.3, 0), vane + Vector3(0.45, -0.3, 0), 0.015, 0.015, 4, iron, false)
	_tube(kit, "metal", vane + Vector3(0, -0.3, -0.45), vane + Vector3(0, -0.3, 0.45), 0.015, 0.015, 4, iron, false)
	_box(kit, "metal", Transform3D(Basis(), vane + Vector3(0.05, 0, 0)), Vector3(1.2, 0.03, 0.03), iron)
	_box(kit, "metal", Transform3D(Basis(), vane + Vector3(0.55, 0.08, 0)), Vector3(0.32, 0.26, 0.02), iron)
	var lantern := CylinderShape3D.new()
	lantern.radius = 2.1
	lantern.height = dtop + 1.1 - top
	_collider(root, name, lantern, Transform3D(Basis(), c + Vector3(0, (top + dtop + 1.1) * 0.5, 0)))

	# Keeper's cottage: whitewashed, a red tiled roof with chimneys at both gables, shuttered
	# windows and a porch facing the landing.
	var hx0 := c.x + 7.6
	var hx1 := c.x + 14.0
	var hz := 3.6
	var wall_top := ty + 3.3
	_block(kit, "paint", Vector3(hx0, ty, c.z - hz), Vector3(hx1, wall_top, c.z + hz), WHITE)
	_block(kit, "paint", Vector3(hx0 - 0.05, ty, c.z - hz - 0.05), Vector3(hx1 + 0.05, ty + 0.45, c.z + hz + 0.05), granite)
	var hxm := (hx0 + hx1) * 0.5
	_gable_roof(kit, "paint", Transform3D(Basis(), Vector3(hxm, wall_top, c.z)), hx1 - hx0 + 0.8, hz * 2.0 + 0.3, 2.0, red, WHITE)
	_block(kit, "paint", Vector3(hxm - 0.14, wall_top + 1.96, c.z - hz - 0.2), Vector3(hxm + 0.14, wall_top + 2.1, c.z + hz + 0.2), red.darkened(0.3))
	for sz in [-1.0, 1.0]:
		var cz: float = c.z + sz * (hz - 0.45)
		_block(kit, "paint", Vector3(hxm - 0.4, wall_top + 1.0, cz - 0.38), Vector3(hxm + 0.4, wall_top + 2.95, cz + 0.38), Color(0.60, 0.34, 0.26))
		_block(kit, "paint", Vector3(hxm - 0.5, wall_top + 2.95, cz - 0.48), Vector3(hxm + 0.5, wall_top + 3.08, cz + 0.48), stone)
		for px in [-0.17, 0.17]:
			_tube(kit, "paint", Vector3(hxm + px, wall_top + 3.08, cz), Vector3(hxm + px, wall_top + 3.45, cz), 0.11, 0.09, 8, Color(0.72, 0.40, 0.26))
	# Windows: [centre on the wall, outward normal, along the wall].
	var wins := [
		[Vector3(hx1, ty + 1.75, c.z - 2.2), Vector3.RIGHT, Vector3.BACK], [Vector3(hx1, ty + 1.75, c.z + 2.2), Vector3.RIGHT, Vector3.BACK],
		[Vector3(hx0, ty + 1.75, c.z - 1.7), Vector3.LEFT, Vector3.BACK], [Vector3(hx0, ty + 1.75, c.z + 1.7), Vector3.LEFT, Vector3.BACK],
		[Vector3(hxm, ty + 1.75, c.z - hz), Vector3.FORWARD, Vector3.RIGHT], [Vector3(hxm, ty + 1.75, c.z + hz), Vector3.BACK, Vector3.RIGHT],
	]
	for wi in wins:
		var wc: Vector3 = wi[0]
		var n: Vector3 = wi[1]
		var along: Vector3 = wi[2]
		var size := func(w: float, h: float, d: float) -> Vector3:
			return Vector3(absf(along.x) * w + absf(n.x) * d, h, absf(along.z) * w + absf(n.z) * d)
		_box(kit, "paint", Transform3D(Basis(), wc + n * 0.03), size.call(1.15, 1.45, 0.08), stone)
		_box(kit, "paint", Transform3D(Basis(), wc + n * 0.06), size.call(0.9, 1.2, 0.04), dark_glass)
		_box(kit, "paint", Transform3D(Basis(), wc + n * 0.08), size.call(0.06, 1.2, 0.04), WHITE)
		_box(kit, "paint", Transform3D(Basis(), wc + n * 0.08), size.call(0.9, 0.06, 0.04), WHITE)
		_box(kit, "paint", Transform3D(Basis(), wc + n * 0.1 - Vector3(0, 0.76, 0)), size.call(1.3, 0.08, 0.2), stone)
		for sd in [-1.0, 1.0]:
			_box(kit, "paint", Transform3D(Basis(), wc + along * sd * 0.92 + n * 0.05), size.call(0.5, 1.35, 0.06), shutter_green)
	# Door and porch on the landward front.
	_block(kit, "paint", Vector3(hx1, ty, c.z - 0.62), Vector3(hx1 + 0.08, ty + 2.35, c.z + 0.62), stone)
	_block(kit, "paint", Vector3(hx1 + 0.08, ty, c.z - 0.5), Vector3(hx1 + 0.12, ty + 2.2, c.z + 0.5), shutter_green)
	_gable_roof(kit, "paint", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(hx1 + 0.55, ty + 2.55, c.z)), 1.8, 1.1, 0.5, red, WHITE)
	for sz in [-0.8, 0.8]:
		_tube(kit, "paint", Vector3(hx1 + 0.95, ty, c.z + sz), Vector3(hx1 + 0.95, ty + 2.55, c.z + sz), 0.06, 0.06, 6, WHITE)
	_box_collider(root, name, Vector3(hx0 - 0.1, ty, c.z - hz - 0.1), Vector3(hx1 + 0.15, wall_top, c.z + hz + 0.1))
	_hull_collider(root, name, PackedVector3Array([
		Vector3(hx0 - 0.4, wall_top, c.z - hz - 0.15), Vector3(hx1 + 0.4, wall_top, c.z - hz - 0.15),
		Vector3(hx0 - 0.4, wall_top, c.z + hz + 0.15), Vector3(hx1 + 0.4, wall_top, c.z + hz + 0.15),
		Vector3(hxm, wall_top + 2.0, c.z - hz - 0.15), Vector3(hxm, wall_top + 2.0, c.z + hz + 0.15)]))
	for sz in [-1.0, 1.0]:
		_box_collider(root, name, Vector3(hxm - 0.5, wall_top + 1.0, c.z + sz * (hz - 0.45) - 0.48), Vector3(hxm + 0.5, wall_top + 3.45, c.z + sz * (hz - 0.45) + 0.48))
	_box_collider(root, name, Vector3(hx1, ty, c.z - 0.9), Vector3(hx1 + 1.1, ty + 2.8, c.z + 0.9))

	# Oil drums by the cottage, a bench at the door, the flagstaff on the yard's corner.
	for i in 3:
		var dp := Vector3(hx1 + 0.6 + i * 0.7, ty, c.z - hz - 1.1 + (i % 2) * 0.25)
		_tube(kit, "paint", dp, dp + Vector3(0, 0.9, 0), 0.3, 0.3, 12, [Color(0.25, 0.42, 0.55), Color(0.7, 0.2, 0.15), Color(0.25, 0.42, 0.55)][i])
		_tube(kit, "rust", dp + Vector3(0, 0.3, 0), dp + Vector3(0, 0.34, 0), 0.31, 0.31, 12, RUST, false)
		_rod_collider(root, name, dp, dp + Vector3(0, 0.9, 0), 0.3)
	var bench := Vector3(hx1 + 0.45, ty, c.z + 1.9)
	_block(kit, "wood", bench + Vector3(-0.25, 0.45, -0.8), bench + Vector3(0.25, 0.5, 0.8), WOOD)
	for bz in [-0.65, 0.65]:
		_block(kit, "wood", bench + Vector3(-0.2, 0, bz - 0.04), bench + Vector3(0.2, 0.45, bz + 0.04), OLD_WOOD)
	_box_collider(root, name, bench + Vector3(-0.25, 0, -0.8), bench + Vector3(0.25, 0.5, 0.8))
	var staff := Vector3(c.x + yard_x1 - 1.0, ty, c.z + yard_hz - 1.0)
	_tube(kit, "paint", staff, staff + Vector3(0, 9.0, 0), 0.09, 0.05, 8, WHITE)
	_tube(kit, "metal", staff + Vector3(0, 9.0, 0), staff + Vector3(0, 9.15, 0), 0.09, 0.09, 8, brass)
	var pst := _st(kit, "canvas")
	var pn := Vector3(0, 0, 1)
	_tri(pst, staff + Vector3(0.06, 8.9, 0), staff + Vector3(0.06, 8.2, 0), staff + Vector3(2.4, 8.62, 0.15), pn, pn, pn, red, pn)
	_rod_collider(root, name, staff, staff + Vector3(0, 9.0, 0), 0.12)

	# Landing steps down to a timber jetty, bollards and a lifebuoy at its end.
	var steps := 11
	var sx0 := c.x + yard_x1 + 0.1
	for s in steps:
		var st_y := ty - (s + 1) * (ty - 0.95) / steps
		_block(kit, "paint", Vector3(sx0 + s * 0.34, -1.2, c.z - 1.1), Vector3(sx0 + (s + 1) * 0.34, st_y, c.z + 1.1), masonry.lightened(0.08 * (s % 2)))
	var sx1 := sx0 + steps * 0.34
	_box_along(root, name, Vector3((sx0 + sx1) * 0.5, (ty + 0.95) * 0.5 - 0.35, c.z), Vector3(sx1 - sx0, 0.95 - ty, 0), Vector3(2.8, 0.7, Vector2(sx1 - sx0, ty - 0.95).length()))
	var jy := 0.95
	var jx1 := sx1 + 8.0
	_block(kit, "wood", Vector3(sx1, jy - 0.2, c.z - 1.3), Vector3(jx1, jy, c.z + 1.3), WOOD.darkened(0.08))
	var jx := sx1 + 0.4
	while jx < jx1:
		for sz in [-1.15, 1.15]:
			var bed := _ground(jx, c.z + sz)
			_tube(kit, "wood", Vector3(jx, bed - 0.6, c.z + sz), Vector3(jx, jy + 0.35, c.z + sz), 0.13, 0.12, 8, OLD_WOOD)
			_rod_collider(root, name, Vector3(jx, bed - 0.6, c.z + sz), Vector3(jx, jy + 0.35, c.z + sz), 0.14)
		jx += 2.4
	_box_collider(root, name, Vector3(sx1, jy - 0.25, c.z - 1.3), Vector3(jx1, jy, c.z + 1.3))
	for sz in [-0.9, 0.9]:
		_tube(kit, "metal", Vector3(jx1 - 0.4, jy, c.z + sz), Vector3(jx1 - 0.4, jy + 0.45, c.z + sz), 0.13, 0.11, 10, iron)
	_tube(kit, "wood", Vector3(jx1 - 0.15, jy, c.z), Vector3(jx1 - 0.15, jy + 1.3, c.z), 0.06, 0.06, 6, WHITE)
	_lifebuoy(kit, Vector3(jx1, jy + 0.85, c.z), Vector3.RIGHT, 0.33, 0.07)
	_rod_collider(root, name, Vector3(jx1 - 0.15, jy, c.z), Vector3(jx1 - 0.15, jy + 1.3, c.z), 0.35)

	var mi := _commit(root, kit, "Lighthouse")
	mi.lod_bias = 4.0
	var lamp := OmniLight3D.new()
	lamp.name = "LighthouseLamp"
	lamp.light_color = Color(1.0, 0.85, 0.55)
	lamp.light_energy = 1.2
	lamp.omni_range = 14.0
	lamp.shadow_enabled = false
	lamp.set_meta("no_shadow", true)
	root.add_child(lamp)
	lamp.position = c + Vector3(0, l0 + 1.8, 0)
	_note("Lighthouse", Vector2(c.x + 6.0, c.z), 22.0, CLEAR_BUILDING)


# --- Shipwreck ------------------------------------------------------------------------------------
# A wooden trawler driven ashore bow first at the south end of the beach and heeled toward the dunes,
# so its deck faces the dune descent, where the lap comes down toward it. The hull is a function of
# s (0 transom, 1 stem) and a (0 keel, 1 sheer) in its own frame: +z forward, +y up from the
# baseline amidships, +x the landward (low) side. The planking runs in strakes between fixed a.

const WRECK_AT := Vector2(-68.0, 370.0)
const WRECK_YAW := 38.0        # degrees; the bow points up the beach, to the south-east
const WRECK_HEEL := 17.0       # degrees, toward the dunes
const WRECK_TRIM := 3.5        # degrees, bow up
const WRECK_BURY := 1.35       # the baseline amidships, below the sand
const WRECK_LEN := 22.0
const WRECK_BEAM := 6.2
const WRECK_DEPTH := 3.3       # baseline to the lowest point of the sheer
const WRECK_BULWARK := 0.85    # sheer above the deck
const WRECK_PLANK := 0.07
const WRECK_LAP := 0.025       # each strake's lower edge stands proud of the one below
const WRECK_STRAKES := 16
const WRECK_STATIONS := 44
const WRECK_DECK_STRIPS := 16
const HULL_RED := Color(0.56, 0.20, 0.15)
const HULL_BLUE := Color(0.15, 0.40, 0.55)
const HULL_WHITE := Color(0.86, 0.84, 0.78)
const HULL_YELLOW := Color(0.90, 0.68, 0.22)
const BARE_WOOD := Color(0.56, 0.53, 0.48)
const HOLD_WOOD := Color(0.32, 0.27, 0.22)
const DECK_WOOD := Color(0.52, 0.47, 0.40)
const RUST := Color(0.42, 0.22, 0.12)
const NET_GREEN := Color(0.20, 0.42, 0.30)
const BEACH_SAND := Color(0.88, 0.80, 0.62)

var _wreck_xf: Transform3D
var _wreck_edges: Array = []   # a at each strake edge, keel to sheer


func _build_shipwreck(root: Node3D) -> void:
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var basis := Basis(Vector3.UP, deg_to_rad(WRECK_YAW)) * Basis(Vector3.RIGHT, deg_to_rad(-WRECK_TRIM)) * Basis(Vector3.BACK, deg_to_rad(-WRECK_HEEL))
	_wreck_xf = Transform3D(basis, Vector3(WRECK_AT.x, _ground(WRECK_AT.x, WRECK_AT.y) - WRECK_BURY, WRECK_AT.y))
	_wreck_edges = _wreck_strake_edges()
	var gone := _wreck_plan_damage(rng)
	_wreck_hull(kit, gone, rng)
	_wreck_transom(kit, rng)
	_wreck_deck(kit, rng)
	_wreck_frames(kit, gone, rng)
	_wreck_rails(kit, gone)
	var house := _wreck_wheelhouse(kit, rng)
	_wreck_rig(kit)
	_wreck_stern_gear(kit, rng)
	_wreck_ground_tackle(root, kit)
	_wreck_debris(root, kit, rng)
	_commit(root, kit, "Shipwreck")

	# Collision: the hull's convex outline above the sand, and the wheelhouse.
	var pts := PackedVector3Array()
	for i in 12:
		for a in [0.3, 0.6, 0.85, 1.0]:
			for side in [-1.0, 1.0]:
				var w := _wreck_xf * _wreck_point(i / 11.0, a, side)
				if w.y > _ground(w.x, w.z) - 0.6:
					pts.append(w - _wreck_xf.origin)
	var hull_shape := ConvexPolygonShape3D.new()
	hull_shape.points = pts
	_collider(root, "Shipwreck", hull_shape, Transform3D(Basis(), _wreck_xf.origin))
	var house_shape := BoxShape3D.new()
	house_shape.size = house.size
	_collider(root, "ShipwreckHouse", house_shape, _wreck_xf * Transform3D(Basis(), house.get_center()))
	# Above the bulwarks: the mast, the stern gantry and the net drum.
	var xf := _wreck_xf
	var me := _wreck_deck_edge(0.665)
	var mast_foot := Vector3(0, me.y - 0.05, me.z)
	_rod_collider(root, "Shipwreck", xf * mast_foot, xf * (mast_foot + Vector3(0, 7.2, 0)), 0.16)
	var ge := _wreck_deck_edge(0.03)
	var bar := _wreck_gantry_top()
	for sx in [-1.0, 1.0]:
		_rod_collider(root, "Shipwreck", xf * _wreck_deck_point(ge, sx * 2.05 / ge.x), xf * Vector3(sx * 2.05, bar.y, bar.z), 0.12)
	_rod_collider(root, "Shipwreck", xf * Vector3(-2.15, bar.y, bar.z), xf * Vector3(2.15, bar.y, bar.z), 0.13)
	var de := _wreck_deck_edge(0.068)
	var axle := Vector3(0, de.y + 0.95, de.z)
	_rod_collider(root, "Shipwreck", xf * (axle + Vector3(-1.25, 0, 0)), xf * (axle + Vector3(1.25, 0, 0)), 0.64)
	_note("Shipwreck", WRECK_AT, 12.0, CLEAR_BUILDING)
	_verify_wreck_bedded()


## Top of the bulwark above the baseline: low aft of amidships, sweeping up to a high bow.
func _wreck_sheer(s: float) -> float:
	return WRECK_DEPTH + 0.5 * pow(1.0 - s, 2.0) + 1.7 * pow(s, 3.0)


## Bottom of the section: the buttocks rise to the transom, the forefoot sweeps up into the stem.
func _wreck_keel(s: float) -> float:
	return 0.9 * pow(1.0 - smoothstep(0.0, 0.35, s), 2.0) + 2.0 * pow(smoothstep(0.72, 1.0, s), 2.0)


## Half-breadth at the sheer: a wide transom, full amidships, a fine bow.
func _wreck_half_beam(s: float) -> float:
	if s < 0.45:
		return WRECK_BEAM * 0.5 * lerpf(0.8, 1.0, sin(PI * 0.5 * s / 0.45))
	var t := (s - 0.45) / 0.55
	return WRECK_BEAM * 0.5 * pow(maxf(1.0 - t * t, 0.0), 0.75)


## A point on the outside of the planking (side -1 seaward, +1 landward). The sections go from a
## round bilge amidships to a V at the bow; the stem rakes forward and the transom aft.
func _wreck_point(s: float, a: float, side: float) -> Vector3:
	var n := lerpf(lerpf(2.6, 3.2, smoothstep(0.0, 0.4, s)), 1.5, smoothstep(0.5, 1.0, s))
	var th := clampf(a, 0.0, 1.0) * PI * 0.5
	var x := pow(sin(th), 2.0 / n)
	var h := lerpf(1.0 - pow(cos(th), 2.0 / n), x, lerpf(0.12, 0.5, smoothstep(0.55, 1.0, s)))
	var z := (s - 0.5) * WRECK_LEN - 1.5 * (1.0 - h) * smoothstep(0.6, 1.0, s) + 1.1 * (1.0 - h) * (1.0 - smoothstep(0.0, 0.2, s))
	return Vector3(side * x * _wreck_half_beam(s), lerpf(_wreck_keel(s), _wreck_sheer(s), h), z)


func _wreck_normal(s: float, a: float, side: float) -> Vector3:
	var s0 := clampf(s - 0.004, 0.0, 0.992)
	var a0 := clampf(a - 0.004, 0.0, 0.992)
	var along := _wreck_point(s0 + 0.008, a, side) - _wreck_point(s0, a, side)
	var round_ := _wreck_point(s, a0 + 0.008, side) - _wreck_point(s, a0, side)
	var n := along.cross(round_).normalized()
	var th := clampf(a, 0.0, 1.0) * PI * 0.5
	return -n if n.dot(Vector3(side * sin(th), -cos(th), 0.0)) < 0.0 else n


## Strake edges spaced evenly round the girth amidships; the planks taper toward the ends.
func _wreck_strake_edges() -> Array:
	var acc: Array = [0.0]
	var prev := _wreck_point(0.45, 0.0, 1.0)
	for i in range(1, 401):
		var p := _wreck_point(0.45, i / 400.0, 1.0)
		acc.append(float(acc[-1]) + p.distance_to(prev))
		prev = p
	var edges: Array = [0.0]
	var j := 0
	for k in range(1, WRECK_STRAKES):
		var target: float = float(acc[-1]) * k / WRECK_STRAKES
		while float(acc[j + 1]) < target:
			j += 1
		edges.append((j + (target - float(acc[j])) / (float(acc[j + 1]) - float(acc[j]))) / 400.0)
	edges.append(1.0)
	return edges


## a where the outside of the planking reaches the deck's edge.
func _wreck_deck_a(s: float) -> float:
	var y := _wreck_sheer(s) - WRECK_BULWARK
	var lo := 0.0
	var hi := 1.0
	for _i in 22:
		var m := (lo + hi) * 0.5
		if _wreck_point(s, m, 1.0).y < y:
			lo = m
		else:
			hi = m
	return lo


## The deck's edge inside the planking at s: half-width, height and z.
func _wreck_deck_edge(s: float) -> Vector3:
	var a := _wreck_deck_a(s)
	var p := _wreck_point(s, a, 1.0) - _wreck_normal(s, a, 1.0) * WRECK_PLANK
	return Vector3(maxf(p.x, 0.0), _wreck_sheer(s) - WRECK_BULWARK, p.z)


## A point on the deck (u -1 seaward edge, +1 landward edge), with 10cm of camber amidships.
func _wreck_deck_point(e: Vector3, u: float) -> Vector3:
	return Vector3(u * e.x, e.y + 0.035 * e.x * (1.0 - u * u), e.z)


## Paint by strake, as on a Mediterranean trawler: red bottom, a white boot-top, blue topsides, a
## yellow band and a white sheer strake.
func _wreck_strake_paint(k: int) -> Color:
	if k == WRECK_STRAKES - 1 or k == 7:
		return HULL_WHITE
	if k == WRECK_STRAKES - 2:
		return HULL_YELLOW
	return HULL_BLUE if k > 7 else HULL_RED


## Which planks are gone, keyed Vector3i(station, strake, side) with side 0 seaward, 1 landward.
## The seaward side is stove in amidships, a ragged oval in which each strake ends at its own frame;
## the landward bulwark is broken in one bay, and a few planks have sprung at either end.
func _wreck_plan_damage(rng: RandomNumberGenerator) -> Dictionary:
	var spans := []   # [side, strake, s0, s1]
	for k in WRECK_STRAKES - 1:
		var e := ((k + 0.5) / WRECK_STRAKES - 0.6) / 0.36
		if absf(e) < 1.0:
			var half := 0.105 * sqrt(1.0 - e * e) * rng.randf_range(0.7, 1.1)
			spans.append([0, k, 0.585 - half + rng.randf_range(-0.04, 0.04), 0.585 + half + rng.randf_range(-0.04, 0.04)])
	# The sheer strake still spans the hole but for one bay.
	spans.append([0, WRECK_STRAKES - 1, 0.60, 0.645])
	spans.append([0, 11, 0.86, 0.92])
	spans.append([0, 12, 0.875, 0.90])
	spans.append([0, 9, 0.18, 0.23])
	for k in range(WRECK_STRAKES - 3, WRECK_STRAKES):
		spans.append([1, k, 0.47 + rng.randf_range(-0.02, 0.02), 0.555 + rng.randf_range(-0.02, 0.02)])
	spans.append([1, 10, 0.30, 0.34])
	var gone := {}
	for sp in spans:
		for i in WRECK_STATIONS:
			var sm := (i + 0.5) / WRECK_STATIONS
			if sm > float(sp[2]) and sm < float(sp[3]):
				gone[Vector3i(i, int(sp[1]), int(sp[0]))] = true
	return gone


## A quad in the wreck's frame, with a normal per corner.
func _wquad(kit: Dictionary, key: String, p: Array, n: Array, col: Color) -> void:
	var st := _st(kit, key)
	var w := []
	var wn := []
	for i in 4:
		w.append(_wreck_xf * (p[i] as Vector3))
		wn.append((_wreck_xf.basis * (n[i] as Vector3)).normalized())
	var out: Vector3 = ((wn[0] as Vector3) + (wn[1] as Vector3) + (wn[2] as Vector3) + (wn[3] as Vector3)).normalized()
	_tri(st, w[0], w[1], w[2], wn[0], wn[1], wn[2], col, out)
	_tri(st, w[0], w[2], w[3], wn[0], wn[2], wn[3], col, out)


func _wbox(kit: Dictionary, key: String, c: Vector3, size: Vector3, col: Color, b: Basis = Basis()) -> void:
	_box(kit, key, _wreck_xf * Transform3D(b, c), size, col)


func _wtube(kit: Dictionary, key: String, a: Vector3, b: Vector3, ra: float, rb: float, segs: int, col: Color, caps: bool = true) -> void:
	_tube(kit, key, _wreck_xf * a, _wreck_xf * b, ra, rb, segs, col, caps)


## A rectangular bar along a polyline (world space): w across it, h along each point's `up`.
func _sweep(kit: Dictionary, key: String, pts: Array, ups: Array, w: float, h: float, col: Color) -> void:
	var count := pts.size()
	if count < 2:
		return
	var rings := []
	var dirs := []
	for i in count:
		var t: Vector3 = ((pts[mini(i + 1, count - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var up: Vector3 = ups[i]
		up = (up - t * up.dot(t)).normalized()
		var side := t.cross(up)
		var c: Vector3 = pts[i]
		rings.append([c - side * w * 0.5 - up * h * 0.5, c + side * w * 0.5 - up * h * 0.5, c + side * w * 0.5 + up * h * 0.5, c - side * w * 0.5 + up * h * 0.5])
		dirs.append([-up, side, up, -side])
	for i in count - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for f in 4:
			var g := (f + 1) % 4
			var out: Vector3 = ((dirs[i][f] as Vector3) + (dirs[i + 1][f] as Vector3)).normalized()
			_quad(kit, key, [r0[f], r0[g], r1[g], r1[f]], out, col)
	_quad(kit, key, rings[0], ((pts[0] as Vector3) - (pts[1] as Vector3)).normalized(), col)
	_quad(kit, key, rings[count - 1], ((pts[count - 1] as Vector3) - (pts[count - 2] as Vector3)).normalized(), col)


## A rope or wire between two world points, sagging `sag` metres at its middle.
func _rope(kit: Dictionary, key: String, a: Vector3, b: Vector3, sag: float, r: float, col: Color) -> void:
	var segs := 6 if sag > 0.0 else 1
	var prev := a
	for i in range(1, segs + 1):
		var t := float(i) / segs
		var p := a.lerp(b, t) + Vector3(0, -4.0 * sag * t * (1.0 - t), 0)
		_tube(kit, key, prev, p, r, r, 4, col, false)
		prev = p


## Runs of stations along which present.call(i) holds for every cell i between them.
func _wreck_runs(present: Callable) -> Array:
	var runs := []
	var cur := []
	for i in WRECK_STATIONS:
		if present.call(i):
			if cur.is_empty():
				cur.append(float(i) / WRECK_STATIONS)
			cur.append(float(i + 1) / WRECK_STATIONS)
		elif not cur.is_empty():
			runs.append(cur)
			cur = []
	if not cur.is_empty():
		runs.append(cur)
	return runs


## The planking: each strake a plank per station with a dark seam along its lower edge, its inside
## face (painted above the deck, bare in the hold) and its cut ends where its neighbours are gone.
## Planks wholly under the sand are left out.
func _wreck_hull(kit: Dictionary, gone: Dictionary, rng: RandomNumberGenerator) -> void:
	var n := WRECK_STATIONS
	var ns := WRECK_STRAKES
	var peel := FastNoiseLite.new()
	peel.seed = 31
	peel.frequency = 0.16
	peel.fractal_type = FastNoiseLite.FRACTAL_NONE
	# Rust runs down from the chainplates (both sides) and the hawse pipe (landward).
	var fittings := [[0.64, -1], [0.70, -1], [0.935, 1]]
	for side_i in 2:
		var side := -1.0 if side_i == 0 else 1.0
		var pts := []
		var nrm := []
		var above := []
		for i in n + 1:
			var s := float(i) / n
			var pr := []
			var nr := []
			var hr := []
			for k in ns + 1:
				var p := _wreck_point(s, _wreck_edges[k], side)
				var w := _wreck_xf * p
				pr.append(p)
				nr.append(_wreck_normal(s, _wreck_edges[k], side))
				hr.append(w.y - _ground(w.x, w.z))
			pts.append(pr)
			nrm.append(nr)
			above.append(hr)
		for i in n:
			var sm := (i + 0.5) / n
			for k in ns:
				if gone.has(Vector3i(i, k, side_i)):
					continue
				var clear := maxf(maxf(above[i][k], above[i][k + 1]), maxf(above[i + 1][k], above[i + 1][k + 1]))
				if clear < -0.25:
					continue
				var p00: Vector3 = pts[i][k]
				var p10: Vector3 = pts[i + 1][k]
				var p01: Vector3 = pts[i][k + 1]
				var p11: Vector3 = pts[i + 1][k + 1]
				var n00: Vector3 = nrm[i][k]
				var n10: Vector3 = nrm[i + 1][k]
				var n01: Vector3 = nrm[i][k + 1]
				var n11: Vector3 = nrm[i + 1][k + 1]

				var col := _wreck_strake_paint(k)
				# Paint goes first round the hole and toward the bow.
				var bare := 0.36 - 0.35 * (1.0 - smoothstep(0.0, 0.14, absf(sm - 0.585))) * (1.0 - side_i) - 0.15 * smoothstep(0.8, 1.0, sm)
				if peel.get_noise_2d((p00.z + p11.z) * 0.5, k * 1.9 + side_i * 50.0) > bare:
					col = BARE_WOOD
				else:
					col = col.lerp(Color(0.82, 0.82, 0.78), 0.12)
				col = col.darkened(0.07 * peel.get_noise_2d(p00.z * 3.0 + 400.0, k * 5.0) + 0.03 * (k % 2))
				for f in fittings:
					if (int(f[1]) < 0 or int(f[1]) == side_i) and absf(sm - float(f[0])) < 0.6 / n and k > ns - 8:
						col = col.lerp(RUST, 0.55 * float(k - (ns - 8)) / 7.0)
				# Dark and wet at the sand, weedy where the swash reaches.
				var hc := (float(above[i][k]) + float(above[i + 1][k + 1])) * 0.5
				col = col.lerp(Color(0.30, 0.27, 0.20), (1.0 - smoothstep(0.0, 0.5, hc)) * 0.5)
				var wy := (_wreck_xf * ((p00 + p11) * 0.5)).y
				col = col.lerp(Color(0.22, 0.28, 0.14), (1.0 - smoothstep(0.05, 0.5, wy)) * 0.55)

				var lo0 := p00 + n00 * WRECK_LAP
				var lo1 := p10 + n10 * WRECK_LAP
				var md0 := lo0.lerp(p01, 0.16)
				var md1 := lo1.lerp(p11, 0.16)
				var nm0 := n00.lerp(n01, 0.16)
				var nm1 := n10.lerp(n11, 0.16)
				_wquad(kit, "wreck", [lo0, lo1, md1, md0], [n00, n10, nm1, nm0], col.darkened(0.28))
				_wquad(kit, "wreck", [md0, md1, p11, p01], [nm0, nm1, n11, n01], col)
				if (i + k * 3) % 9 == 0 and i > 0 and not gone.has(Vector3i(i - 1, k, side_i)):
					var f := (p10 - p00).normalized() * 0.015
					_wquad(kit, "wreck", [lo0 - f + n00 * 0.004, lo0 + f + n00 * 0.004, p01 + f + n01 * 0.004, p01 - f + n01 * 0.004], [n00, n00, n01, n01], col.darkened(0.45))

				var in00 := p00 - n00 * WRECK_PLANK
				var in10 := p10 - n10 * WRECK_PLANK
				var in01 := p01 - n01 * WRECK_PLANK
				var in11 := p11 - n11 * WRECK_PLANK
				var inside := HULL_WHITE.darkened(0.15) if (p00.y + p11.y) * 0.5 > _wreck_sheer(sm) - WRECK_BULWARK else HOLD_WOOD
				_wquad(kit, "wreck", [in00, in10, in11, in01], [-n00, -n10, -n11, -n01], inside.darkened(rng.randf_range(0.0, 0.08)))

				var cut := BARE_WOOD.darkened(0.15)
				var down := (p00 - p01).normalized()
				var fwd := (p10 - p00).normalized()
				if k > 0:
					if gone.has(Vector3i(i, k - 1, side_i)):
						_wquad(kit, "wreck", [lo0, lo1, in10, in00], [down, down, down, down], cut)
					else:
						_wquad(kit, "wreck", [lo0, lo1, p10, p00], [down, down, down, down], col.darkened(0.45))
				if k == ns - 1 or gone.has(Vector3i(i, k + 1, side_i)):
					_wquad(kit, "wreck", [p01, p11, in11, in01], [-down, -down, -down, -down], cut)
				if i == 0 or gone.has(Vector3i(i - 1, k, side_i)):
					_wquad(kit, "wreck", [lo0, p01, in01, in00], [-fwd, -fwd, -fwd, -fwd], cut)
				if i + 1 < n and gone.has(Vector3i(i + 1, k, side_i)):
					_wquad(kit, "wreck", [lo1, p11, in11, in10], [fwd, fwd, fwd, fwd], cut)


## The transom: flat and raked, planked across in the strakes' colours.
func _wreck_transom(kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var aft := Vector3(0.0, -1.1, -(_wreck_sheer(0.0) - _wreck_keel(0.0))).normalized()
	var deck_y := _wreck_sheer(0.0) - WRECK_BULWARK
	for k in WRECK_STRAKES:
		var p0 := _wreck_point(0.0, _wreck_edges[k], -1.0)
		var p1 := _wreck_point(0.0, _wreck_edges[k], 1.0)
		var p2 := _wreck_point(0.0, _wreck_edges[k + 1], 1.0)
		var p3 := _wreck_point(0.0, _wreck_edges[k + 1], -1.0)
		var top := _wreck_xf * ((p2 + p3) * 0.5)
		if top.y < _ground(top.x, top.z) - 0.3:
			continue
		var col := _wreck_strake_paint(k).lerp(BARE_WOOD, 0.25).darkened(rng.randf_range(0.0, 0.1))
		var wy := (_wreck_xf * ((p0 + p2) * 0.5)).y
		col = col.lerp(Color(0.22, 0.28, 0.14), (1.0 - smoothstep(0.05, 0.5, wy)) * 0.55)
		var m0 := p0.lerp(p3, 0.16)
		var m1 := p1.lerp(p2, 0.16)
		_wquad(kit, "wreck", [p0, p1, m1, m0], [aft, aft, aft, aft], col.darkened(0.28))
		_wquad(kit, "wreck", [m0, m1, p2, p3], [aft, aft, aft, aft], col)
		var t := -aft * WRECK_PLANK
		var inside := HULL_WHITE.darkened(0.15) if p2.y > deck_y else HOLD_WOOD
		_wquad(kit, "wreck", [p0 + t, p1 + t, p2 + t, p3 + t], [-aft, -aft, -aft, -aft], inside)


## Deck planks run fore and aft; amidships the hold has fallen in, and sand has drifted down the
## heeled deck against the low bulwark.
func _wreck_deck(kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var n := WRECK_STATIONS
	var nd := WRECK_DECK_STRIPS
	var hole := {}
	for j in nd:
		var u := -1.0 + 2.0 * (j + 0.5) / nd
		if absf(u) < 0.62:
			var half := 0.09 * sqrt(1.0 - pow(u / 0.62, 2.0))
			var s0 := 0.515 - half + rng.randf_range(-0.03, 0.03)
			var s1 := 0.515 + half + rng.randf_range(-0.03, 0.03)
			for i in n:
				var sm := (i + 0.5) / n
				if sm > s0 and sm < s1:
					hole[Vector2i(i, j)] = true
	var drift := FastNoiseLite.new()
	drift.seed = 8
	drift.frequency = 0.3
	drift.fractal_type = FastNoiseLite.FRACTAL_NONE
	var edges := []
	for i in n + 1:
		edges.append(_wreck_deck_edge(float(i) / n))
	var tone := []
	for j in nd:
		tone.append(rng.randf_range(-0.06, 0.10))
	var thick := Vector3(0, 0.09, 0)
	var cut := DECK_WOOD.darkened(0.3)
	for i in n:
		var sm := (i + 0.5) / n
		var e0: Vector3 = edges[i]
		var e1: Vector3 = edges[i + 1]
		for j in nd:
			if hole.has(Vector2i(i, j)):
				continue
			var u0 := -1.0 + 2.0 * j / nd
			var u1 := -1.0 + 2.0 * (j + 1) / nd
			var q00 := _wreck_deck_point(e0, u0)
			var q01 := _wreck_deck_point(e0, u1)
			var q10 := _wreck_deck_point(e1, u0)
			var q11 := _wreck_deck_point(e1, u1)
			var fwd := (q10 - q00).normalized()
			var across := (q01 - q00).normalized()
			var up := fwd.cross(across).normalized()
			if up.y < 0.0:
				up = -up
			var um := (u0 + u1) * 0.5
			var col := DECK_WOOD.darkened(float(tone[j]) + rng.randf_range(-0.03, 0.03))
			var sand := clampf(smoothstep(0.1, 0.85, um) * (0.75 + 0.7 * drift.get_noise_2d(sm * WRECK_LEN, um * 4.0)), 0.0, 1.0)
			col = col.lerp(BEACH_SAND, sand * 0.9)
			var qm0 := q00.lerp(q01, 0.1)
			var qm1 := q10.lerp(q11, 0.1)
			_wquad(kit, "wreck", [q00, q10, qm1, qm0], [up, up, up, up], col.darkened(0.3 * (1.0 - sand)))
			_wquad(kit, "wreck", [qm0, qm1, q11, q01], [up, up, up, up], col)
			# Underneath and the broken ends show only round the hold.
			if sm > 0.36 and sm < 0.7:
				_wquad(kit, "wreck", [q00 - thick, q10 - thick, q11 - thick, q01 - thick], [-up, -up, -up, -up], HOLD_WOOD)
			if hole.has(Vector2i(i - 1, j)):
				_wquad(kit, "wreck", [q00, q01, q01 - thick, q00 - thick], [-fwd, -fwd, -fwd, -fwd], cut)
			if hole.has(Vector2i(i + 1, j)):
				_wquad(kit, "wreck", [q10, q11, q11 - thick, q10 - thick], [fwd, fwd, fwd, fwd], cut)
			if hole.has(Vector2i(i, j - 1)):
				_wquad(kit, "wreck", [q00, q10, q10 - thick, q00 - thick], [-across, -across, -across, -across], cut)
			if hole.has(Vector2i(i, j + 1)):
				_wquad(kit, "wreck", [q01, q11, q11 - thick, q01 - thick], [across, across, across, across], cut)

	# Deck beams across the hold, the middle one broken and hanging.
	var up_w := _wreck_xf.basis * Vector3.UP
	for bs in [0.455, 0.515, 0.575]:
		var e := _wreck_deck_edge(bs)
		var y: float = e.y - 0.17
		if bs == 0.515:
			for sgn in [-1.0, 1.0]:
				_sweep(kit, "wreck", [_wreck_xf * Vector3(sgn * e.x, y, e.z), _wreck_xf * Vector3(sgn * 0.15, y - 0.6, e.z + 0.12 * sgn)], [up_w, up_w], 0.14, 0.16, HOLD_WOOD.lightened(0.12))
		else:
			_sweep(kit, "wreck", [_wreck_xf * Vector3(-e.x, y, e.z), _wreck_xf * Vector3(e.x, y, e.z)], [up_w, up_w], 0.14, 0.16, HOLD_WOOD.lightened(0.12))
	# The hatch cover fell in with it and lies propped on the sand in the hold.
	var hold := _wreck_xf * Vector3(0.2, 0.0, (0.51 - 0.5) * WRECK_LEN)
	hold.y = _ground(hold.x, hold.z)
	var hb := _wreck_xf.basis * Basis(Vector3.UP, 0.3) * Basis(Vector3.RIGHT, -0.55)
	for p in range(5):
		var off := hb * Vector3(0, 0, -0.6 + p * 0.3)
		_box(kit, "wreck", Transform3D(hb, hold + Vector3(0, 0.45, 0) + off), Vector3(1.6, 0.07, 0.28), DECK_WOOD.darkened(0.1 + 0.05 * (p % 2)))


## Frames stand bare where planks or deck are gone, some snapped off; elsewhere only the bulwark
## stanchions show above the deck.
func _wreck_frames(kit: Dictionary, gone: Dictionary, rng: RandomNumberGenerator) -> void:
	var n := WRECK_STATIONS
	var ns := WRECK_STRAKES
	var timber := HOLD_WOOD.lightened(0.18)
	for side_i in 2:
		var side := -1.0 if side_i == 0 else 1.0
		for i in range(1, n):
			var s := float(i) / n
			var open := false
			for k in ns:
				if gone.has(Vector3i(i - 1, k, side_i)) or gone.has(Vector3i(i, k, side_i)):
					open = true
			if open or (s > 0.42 and s < 0.62):
				if open and rng.randf() < 0.2:
					continue
				var lean := rng.randf_range(-0.15, 0.15) if open else 0.0
				var top := 1.0
				if open and rng.randf() < 0.4:
					top = rng.randf_range(0.6, 0.92)
					# Snapped only where nothing above the break is still planked.
					for k in ns:
						if float(_wreck_edges[k + 1]) > top and not (gone.has(Vector3i(i - 1, k, side_i)) and gone.has(Vector3i(i, k, side_i))):
							top = 1.0
				var path := []
				var ups := []
				for k in ns + 1:
					var a: float = minf(float(_wreck_edges[k]), top)
					var nn := _wreck_normal(s, a, side)
					path.append(_wreck_xf * (_wreck_point(s, a, side) - nn * (WRECK_PLANK + 0.075) + Vector3(0, 0, lean * a * a)))
					ups.append(_wreck_xf.basis * nn)
					if a >= top:
						break
				# Drop the frame's buried foot, keeping one point in the sand.
				while path.size() > 2:
					var q: Vector3 = path[1]
					if q.y > _ground(q.x, q.z) - 0.3:
						break
					path.pop_front()
					ups.pop_front()
				_sweep(kit, "wreck", path, ups, 0.12, 0.15, timber.darkened(rng.randf_range(0.0, 0.12)))
			elif i % 2 == 0 and s > 0.03 and s < 0.95:
				var ad := _wreck_deck_a(s)
				var n0 := _wreck_normal(s, ad, side)
				var n1 := _wreck_normal(s, 1.0, side)
				var b0 := _wreck_xf * (_wreck_point(s, ad, side) - n0 * (WRECK_PLANK + 0.06))
				var b1 := _wreck_xf * (_wreck_point(s, 1.0, side) - n1 * (WRECK_PLANK + 0.06))
				_sweep(kit, "wreck", [b0, b1], [_wreck_xf.basis * n0, _wreck_xf.basis * n1], 0.11, 0.12, HULL_WHITE.darkened(0.2))


## Cap rails along the sheer and across the transom, rubbing strakes at deck level, and the keel
## running up into the stem.
func _wreck_rails(kit: Dictionary, gone: Dictionary) -> void:
	var b := _wreck_xf.basis
	var cap_col := HULL_WHITE.darkened(0.25)
	for side_i in 2:
		var side := -1.0 if side_i == 0 else 1.0
		var cap_ok := func(i: int) -> bool:
			return not gone.has(Vector3i(i, WRECK_STRAKES - 1, side_i))
		for run in _wreck_runs(cap_ok):
			var pts := []
			var ups := []
			for s in run:
				var p := _wreck_point(s, 1.0, side) - _wreck_normal(s, 1.0, side) * (WRECK_PLANK * 0.5) + Vector3(0, 0.045, 0)
				pts.append(_wreck_xf * p)
				ups.append(b * Vector3.UP)
			_sweep(kit, "wreck", pts, ups, 0.22, 0.09, cap_col)
		var rub_ok := func(i: int) -> bool:
			var ad := _wreck_deck_a((i + 0.5) / WRECK_STATIONS)
			for k in WRECK_STRAKES:
				if float(_wreck_edges[k + 1]) > ad:
					return not gone.has(Vector3i(i, k, side_i))
			return true
		for run in _wreck_runs(rub_ok):
			var pts := []
			var ups := []
			for s in run:
				var ad := _wreck_deck_a(s)
				var nn := _wreck_normal(s, ad, side)
				pts.append(_wreck_xf * (_wreck_point(s, ad, side) + nn * 0.045))
				ups.append(b * nn)
			_sweep(kit, "wreck", pts, ups, 0.14, 0.09, Color(0.20, 0.18, 0.16))
	var t := Vector3(0, 0.045, WRECK_PLANK * 0.5)
	_sweep(kit, "wreck", [_wreck_xf * (_wreck_point(0.0, 1.0, -1.0) + t), _wreck_xf * (_wreck_point(0.0, 1.0, 1.0) + t)], [b * Vector3.UP, b * Vector3.UP], 0.22, 0.09, cap_col)

	# Keel and stem: one timber from the transom along the bottom and up to the stem head.
	var line := []
	for i in WRECK_STATIONS + 1:
		line.append(_wreck_point(float(i) / WRECK_STATIONS, 0.0, 0.0))
	for k in range(1, WRECK_STRAKES + 1):
		line.append(_wreck_point(1.0, _wreck_edges[k], 0.0))
	line.append(_wreck_point(1.0, 1.0, 0.0) + Vector3(0, 0.22, 0.08))
	var pts := []
	var ups := []
	for i in line.size():
		var tng: Vector3 = (line[mini(i + 1, line.size() - 1)] as Vector3) - (line[maxi(i - 1, 0)] as Vector3)
		var outward := Vector3(0, -tng.z, tng.y).normalized()
		var w := _wreck_xf * ((line[i] as Vector3) + outward * 0.03)
		if w.y < _ground(w.x, w.z) - 0.5 and pts.size() < 2:
			pts.clear()
			ups.clear()
		pts.append(w)
		ups.append(b * outward)
	_sweep(kit, "wreck", pts, ups, 0.17, 0.2, Color(0.40, 0.36, 0.31))


## The wheelhouse aft: white with blue trim, most of its windows out, the door hanging open, with
## the stack, radar, lights and a lifebuoy still on it. Returns its box in the wreck's frame.
func _wreck_wheelhouse(kit: Dictionary, rng: RandomNumberGenerator) -> AABB:
	var z0 := (0.12 - 0.5) * WRECK_LEN
	var z1 := (0.28 - 0.5) * WRECK_LEN
	var base := _wreck_sheer(0.28) - WRECK_BULWARK + 0.03
	var hw := 1.55
	var h := 2.3
	var zc := (z0 + z1) * 0.5
	var lz := z1 - z0
	var paint := HULL_WHITE.darkened(0.03)
	_wbox(kit, "paint", Vector3(0, base + h * 0.5, zc), Vector3(hw * 2.0, h, lz), paint)
	_wbox(kit, "paint", Vector3(0, base + 0.2, zc), Vector3(hw * 2.0 + 0.04, 0.4, lz + 0.04), HULL_BLUE)
	_wbox(kit, "paint", Vector3(0, base + h + 0.06, zc + 0.15), Vector3(hw * 2.0 + 0.3, 0.12, lz + 0.5), paint.darkened(0.1))
	_wbox(kit, "paint", Vector3(0, base + h - 0.02, z1 + 0.38), Vector3(hw * 2.0 + 0.3, 0.1, 0.06), HULL_BLUE)

	# Windows: centre on the wall, the wall's outward normal, width, height.
	var wins := []
	for x in [-0.95, 0.0, 0.95]:
		wins.append([Vector3(x, base + 1.55, z1), Vector3(0, 0, 1), 0.78, 0.7])
	for z in [z1 - 0.75, z1 - 2.0]:
		wins.append([Vector3(-hw, base + 1.5, z), Vector3(-1, 0, 0), 0.9, 0.62])
	wins.append([Vector3(hw, base + 1.5, z1 - 0.75), Vector3(1, 0, 0), 0.9, 0.62])
	wins.append([Vector3(-0.6, base + 1.6, z0), Vector3(0, 0, -1), 0.6, 0.5])
	for wi in wins:
		var c: Vector3 = wi[0]
		var nn: Vector3 = wi[1]
		var ww: float = wi[2]
		var wh: float = wi[3]
		var flat := func(d: float) -> Vector3:
			return Vector3(d if nn.x != 0.0 else ww, wh, d if nn.z != 0.0 else ww)
		_wbox(kit, "paint", c + nn * 0.01, flat.call(0.02) + Vector3(0.12, 0.12, 0.12) * Vector3(1.0 - absf(nn.x), 1.0, 1.0 - absf(nn.z)), HULL_BLUE)
		if rng.randf() < 0.65:
			_wbox(kit, "paint", c + nn * 0.02, flat.call(0.02), Color(0.05, 0.06, 0.07))
		else:
			_wbox(kit, "gloss", c + nn * 0.02, flat.call(0.02), Color(0.10, 0.16, 0.20))
		# Rust weeping from the frame's lower corners.
		var along := Vector3(nn.z, 0, nn.x)
		for sx in [-1.0, 1.0]:
			var ln := rng.randf_range(0.35, 0.9)
			var sc: Vector3 = c + along * sx * (ww * 0.5 - 0.04) + Vector3(0, -wh * 0.5 - 0.06 - ln * 0.5, 0) + nn * 0.006
			_wbox(kit, "paint", sc, Vector3(0.01 if nn.x != 0.0 else 0.05, ln, 0.01 if nn.z != 0.0 else 0.05), RUST.lerp(paint, rng.randf_range(0.3, 0.55)))

	# The landward door, hanging open, and the lifebuoy beside it.
	var hinge := Vector3(hw, base + 0.05, z0 + 0.25)
	_wbox(kit, "paint", Vector3(hw + 0.012, base + 1.0, z0 + 0.65), Vector3(0.02, 1.85, 0.75), Color(0.05, 0.06, 0.07))
	var door := Basis(Vector3.UP, deg_to_rad(105.0))
	_wbox(kit, "paint", hinge + door * Vector3(0.03, 0.95, 0.38), Vector3(0.05, 1.85, 0.75), HULL_BLUE.darkened(0.1), door)
	_lifebuoy(kit, _wreck_xf * Vector3(hw + 0.09, base + 1.35, z0 + 1.7), _wreck_xf.basis * Vector3.RIGHT, 0.32, 0.075)

	# On the roof: stack, radar, searchlight, whips, and the side lights.
	var roof := base + h + 0.12
	_wtube(kit, "rust", Vector3(-0.95, roof - 0.1, z0 + 0.55), Vector3(-0.95, roof + 1.3, z0 + 0.4), 0.17, 0.17, 10, RUST.darkened(0.2))
	_wtube(kit, "rust", Vector3(-0.95, roof + 1.3, z0 + 0.4), Vector3(-0.95, roof + 1.55, z0 + 0.37), 0.185, 0.185, 10, Color(0.08, 0.08, 0.08))
	_wtube(kit, "metal", Vector3(0.3, roof, zc - 0.4), Vector3(0.3, roof + 0.75, zc - 0.4), 0.05, 0.05, 6, HULL_WHITE)
	_wbox(kit, "paint", Vector3(0.3, roof + 0.8, zc - 0.4), Vector3(1.5, 0.1, 0.18), HULL_WHITE.darkened(0.1), Basis(Vector3.UP, 0.6))
	_wtube(kit, "metal", Vector3(0.6, roof, z1 - 0.2), Vector3(0.6, roof + 0.3, z1 - 0.2), 0.04, 0.04, 6, Color(0.3, 0.3, 0.32))
	_wtube(kit, "metal", Vector3(0.6, roof + 0.35, z1 - 0.35), Vector3(0.6, roof + 0.35, z1 - 0.02), 0.12, 0.13, 10, Color(0.3, 0.3, 0.32))
	_wtube(kit, "metal", Vector3(1.4, roof, z0 + 0.1), Vector3(1.4, roof + 2.6, z0 + 0.1), 0.025, 0.012, 4, HULL_WHITE)
	_wtube(kit, "metal", Vector3(-1.4, roof, z0 + 0.1), Vector3(-1.4, roof + 1.1, z0 + 0.1), 0.025, 0.02, 4, HULL_WHITE)
	_wtube(kit, "metal", Vector3(-1.4, roof + 1.1, z0 + 0.1), Vector3(-2.1, roof + 2.0, z0 - 0.3), 0.02, 0.012, 4, HULL_WHITE)
	for sl in [[-1.0, Color(0.15, 0.7, 0.3)], [1.0, Color(0.85, 0.15, 0.12)]]:
		var sx: float = sl[0]
		_wbox(kit, "paint", Vector3(sx * (hw + 0.1), roof - 0.35, z1 - 0.3), Vector3(0.04, 0.3, 0.5), paint)
		_wbox(kit, "gloss", Vector3(sx * (hw + 0.16), roof - 0.35, z1 - 0.2), Vector3(0.1, 0.16, 0.22), sl[1])
	return AABB(Vector3(-hw, base, z0), Vector3(hw * 2.0, h, lz))


## The mast forward of the hold with its crosstree, derrick and rigging; one shroud has parted.
func _wreck_rig(kit: Dictionary) -> void:
	var e := _wreck_deck_edge(0.665)
	var foot := Vector3(0, e.y - 0.05, e.z)
	var top := foot + Vector3(0, 7.2, 0)
	var spar := Color(0.42, 0.36, 0.30)
	var wire := Color(0.18, 0.17, 0.16)
	_wtube(kit, "wreck", foot, top, 0.15, 0.09, 10, spar)
	var tree := foot + Vector3(0, 5.5, 0)
	_wbox(kit, "wreck", tree, Vector3(1.9, 0.09, 0.12), spar.darkened(0.1))
	_wbox(kit, "gloss", top + Vector3(0, 0.08, 0), Vector3(0.14, 0.18, 0.14), HULL_WHITE)
	# Derrick topped up aft over the hold, its hook hanging.
	var boom_end := Vector3(0.3, foot.y + 3.0, -0.6)
	_wtube(kit, "wreck", foot + Vector3(0, 1.1, -0.15), boom_end, 0.1, 0.07, 8, spar)
	var xf := _wreck_xf
	_rope(kit, "metal", xf * (top - Vector3(0, 0.1, 0)), xf * boom_end, 0.05, 0.018, wire)
	var hook := xf * boom_end + Vector3(0, -1.3, 0)
	_rope(kit, "metal", xf * boom_end, hook, 0.0, 0.015, wire)
	_box(kit, "rust", Transform3D(xf.basis, hook + Vector3(0, -0.12, 0)), Vector3(0.2, 0.28, 0.14), RUST)
	# Forestay to the stem head, shrouds to the chainplates, backstay to the gantry.
	_rope(kit, "metal", xf * (top - Vector3(0, 0.15, 0)), xf * (_wreck_point(1.0, 1.0, 0.0) + Vector3(0, 0.3, 0.05)), 0.1, 0.02, wire)
	for side in [-1.0, 1.0]:
		var from := xf * (tree + Vector3(side * 0.9, 0, 0))
		_rope(kit, "metal", from, xf * (_wreck_point(0.64, 1.0, side) + Vector3(0, 0.08, 0)), 0.0, 0.02, wire)
		if side > 0.0:
			_rope(kit, "metal", from, xf * (_wreck_point(0.70, 1.0, side) + Vector3(0, 0.08, 0)), 0.0, 0.02, wire)
		else:
			# Parted: it hangs from the crosstree and trails across the deck.
			var loose := xf * Vector3(-1.4, _wreck_sheer(0.6) - WRECK_BULWARK + 0.05, 2.2)
			_rope(kit, "metal", from, loose, 0.6, 0.02, wire)
	_rope(kit, "metal", xf * (top - Vector3(0, 0.15, 0)), xf * _wreck_gantry_top(), 0.15, 0.02, wire)


## Middle of the stern gantry's crossbar.
func _wreck_gantry_top() -> Vector3:
	var e := _wreck_deck_edge(0.03)
	return Vector3(0, e.y + 3.4, e.z - 0.45)


## The stern gantry, the net drum behind the wheelhouse, and the net run off it over the transom
## and heaped on the sand.
func _wreck_stern_gear(kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var xf := _wreck_xf
	var e := _wreck_deck_edge(0.03)
	var orange := Color(0.78, 0.42, 0.18)
	var crossbar := _wreck_gantry_top()
	for sx in [-1.0, 1.0]:
		var footp := _wreck_deck_point(e, sx * 2.05 / e.x)
		var topp := Vector3(sx * 2.05, crossbar.y, crossbar.z)
		_wtube(kit, "rust", footp, topp, 0.11, 0.1, 8, orange.lerp(RUST, rng.randf_range(0.2, 0.6)))
		_wtube(kit, "rust", footp.lerp(topp, 0.5), footp + Vector3(0, 0.05, 1.3), 0.07, 0.07, 6, orange.lerp(RUST, 0.5))
	_wtube(kit, "rust", Vector3(-2.15, crossbar.y, crossbar.z), Vector3(2.15, crossbar.y, crossbar.z), 0.12, 0.12, 8, orange.lerp(RUST, 0.35))
	_rope(kit, "metal", xf * crossbar, xf * (crossbar + Vector3(0, -0.7, 0)), 0.0, 0.02, Color(0.18, 0.17, 0.16))
	_wbox(kit, "rust", crossbar + Vector3(0, -0.9, 0), Vector3(0.18, 0.4, 0.3), RUST)

	var ed := _wreck_deck_edge(0.068)
	var axle := Vector3(0, ed.y + 0.95, ed.z)
	_wtube(kit, "rust", axle + Vector3(-1.25, 0, 0), axle + Vector3(1.25, 0, 0), 0.3, 0.3, 12, RUST)
	_wtube(kit, "canvas", axle + Vector3(-1.12, 0, 0), axle + Vector3(1.12, 0, 0), 0.52, 0.52, 14, NET_GREEN)
	for sx in [-1.0, 1.0]:
		_wtube(kit, "rust", axle + Vector3(sx * 1.15, 0, 0), axle + Vector3(sx * 1.21, 0, 0), 0.64, 0.64, 16, RUST.lightened(0.08))
		_wbox(kit, "rust", Vector3(sx * 1.32, (axle.y + ed.y) * 0.5, axle.z), Vector3(0.1, axle.y - ed.y + 0.1, 0.5), orange.lerp(RUST, 0.6))

	# Net: off the bottom of the drum, along the deck, over the transom and down onto the sand.
	var hull_rows := [
		axle + Vector3(0, -0.45, -0.25),
		Vector3(0, ed.y + 0.18, -10.3),
		_wreck_point(0.0, 1.0, 0.0) + Vector3(0, 0.15, -0.08),
		_wreck_point(0.0, 0.8, 0.0) + Vector3(0, 0.0, -0.35),
	]
	var rows := []
	var widths := [0.3, 0.35, 0.25, 0.3, 0.9, 1.4]
	for r in hull_rows:
		rows.append(xf * (r as Vector3))
	var side_w := xf.basis * Vector3.RIGHT
	side_w = Vector3(side_w.x, 0, side_w.z).normalized()
	var back := xf.basis * Vector3.BACK
	back = -Vector3(back.x, 0, back.z).normalized()
	var last: Vector3 = rows[-1]
	for d in [1.3, 3.0]:
		var p: Vector3 = last + back * d + side_w * 0.4 * d
		p.y = _ground(p.x, p.z) + 0.06
		rows.append(p)
	for i in 2:
		var hp := xf * (axle + Vector3(0.5 - 0.9 * i, -0.55, -0.75 - 0.2 * i))
		_rock(kit, hp, Vector3(0.75, 0.38, 0.6), 310 + i, NET_GREEN.darkened(0.08 * i), "canvas")
	var strands := 4
	for k in strands:
		var u := -1.0 + 2.0 * k / (strands - 1) + rng.randf_range(-0.25, 0.25)
		var r := rng.randf_range(0.07, 0.11)
		var col := NET_GREEN.lerp(Color(0.25, 0.45, 0.48), rng.randf_range(0.0, 0.5)).darkened(rng.randf_range(0.0, 0.2))
		var prev: Vector3 = (rows[0] as Vector3) + side_w * u * float(widths[0])
		for row in rows.size() - 1:
			for step in range(1, 5):
				var t := step / 4.0
				var w := lerpf(float(widths[row]), float(widths[row + 1]), t) * rng.randf_range(0.8, 1.0)
				var p: Vector3 = (rows[row] as Vector3).lerp(rows[row + 1], t) + side_w * (u * w + rng.randf_range(-0.08, 0.08)) + Vector3(0, rng.randf_range(-0.03, 0.06), 0)
				_tube(kit, "canvas", prev, p, r, r, 6, col, false)
				# Floats strung along the head rope.
				if k == strands - 1 and step % 2 == 0:
					var fd := (p - prev).normalized()
					_tube(kit, "gloss", p - fd * 0.1, p + fd * 0.1, 0.11, 0.11, 8, Color(0.95, 0.45, 0.10))
				prev = p
	var heap: Vector3 = rows[-1]
	for i in 3:
		var hp: Vector3 = heap + back * (0.4 * i - 0.2) + side_w * (0.9 * i - 0.9)
		hp.y = _ground(hp.x, hp.z) + 0.05
		_rock(kit, hp, Vector3(1.1, 0.45, 0.9) * (1.0 - 0.15 * i), 300 + i, NET_GREEN.darkened(0.05 * i), "canvas")
	for i in 4:
		var fp: Vector3 = heap + back * rng.randf_range(-1.0, 1.0) + side_w * rng.randf_range(-1.5, 1.5)
		fp.y = _ground(fp.x, fp.z) + 0.25
		_tube(kit, "gloss", fp, fp + side_w.rotated(Vector3.UP, rng.randf_range(0.0, PI)) * 0.2, 0.11, 0.11, 8, Color(0.95, 0.45, 0.10))


## Windlass and bitts on the foredeck; the cable runs out of the landward hawse and up the beach
## to the anchor, which the salvors dragged clear and left.
func _wreck_ground_tackle(root: Node3D, kit: Dictionary) -> void:
	var xf := _wreck_xf
	var e := _wreck_deck_edge(0.86)
	var wl := _wreck_deck_point(e, 0.0) + Vector3(0, 0.38, 0)
	_wtube(kit, "rust", wl + Vector3(-0.55, 0, 0), wl + Vector3(0.55, 0, 0), 0.17, 0.17, 10, RUST)
	for sx in [-0.62, 0.0, 0.62]:
		_wbox(kit, "rust", wl + Vector3(sx, -0.2, 0), Vector3(0.08, 0.5, 0.45), RUST.darkened(0.15))
	var eb := _wreck_deck_edge(0.80)
	for sx in [-0.45, 0.45]:
		var bp := _wreck_deck_point(eb, sx / eb.x)
		_wtube(kit, "wreck", bp - Vector3(0, 0.1, 0), bp + Vector3(0, 0.55, 0), 0.11, 0.11, 8, Color(0.30, 0.26, 0.22))
	var bp0 := _wreck_deck_point(eb, -0.45 / eb.x)
	var bp1 := _wreck_deck_point(eb, 0.45 / eb.x)
	_wtube(kit, "wreck", bp0 + Vector3(-0.15, 0.42, 0), bp1 + Vector3(0.15, 0.42, 0), 0.045, 0.045, 6, Color(0.30, 0.26, 0.22))

	var hs := 0.935
	var ha := 0.84
	var hn := _wreck_normal(hs, ha, 1.0)
	var hp := _wreck_point(hs, ha, 1.0)
	_wtube(kit, "rust", hp - hn * 0.15, hp + hn * 0.06, 0.13, 0.15, 10, RUST)
	# Cable on deck from the windlass to the hawse.
	var path := [xf * (wl + Vector3(0.45, -0.1, 0)), xf * (hp - hn * 0.25 + Vector3(0, 0.05, 0))]
	var mouth := xf * (hp + hn * 0.08)
	var out_w := xf.basis * hn
	out_w = Vector3(out_w.x, 0, out_w.z).normalized()
	var bow_w := xf.basis * Vector3.BACK
	bow_w = Vector3(bow_w.x, 0, bow_w.z).normalized()
	var touch := mouth + out_w * 1.3 + bow_w * 0.6
	touch.y = _ground(touch.x, touch.z)
	var hang_ctrl := Vector3(mouth.x + out_w.x * 0.3, touch.y + 0.2, mouth.z + out_w.z * 0.3)
	path.append(mouth)
	for i in range(1, 9):
		var t := i / 8.0
		path.append(mouth.lerp(hang_ctrl, t).lerp(hang_ctrl.lerp(touch, t), t))
	# Slack across the sand to the anchor's ring.
	var ring := touch + out_w * 2.5 + bow_w * 4.0
	var span := ring - touch
	var lateral := span.cross(Vector3.UP).normalized()
	for i in range(1, 11):
		var t := i / 10.0
		var p := touch + span * t + lateral * sin(t * PI * 1.5) * 0.8
		p.y = _ground(p.x, p.z) + 0.02
		path.append(p)
	_wreck_chain(kit, path)
	_wreck_anchor(root, kit, ring, span.normalized())


## Chain links along a world polyline, alternately flat and upright.
func _wreck_chain(kit: Dictionary, path: Array) -> void:
	var pitch := 0.24
	var idx := 0
	for seg in path.size() - 1:
		var a: Vector3 = path[seg]
		var b: Vector3 = path[seg + 1]
		var len_ := a.distance_to(b)
		var t := (b - a).normalized()
		var d := 0.0
		while d < len_:
			var c := a + t * d
			var w0 := t.cross(Vector3.UP if absf(t.y) < 0.9 else Vector3.RIGHT).normalized()
			var w := w0 if idx % 2 == 0 else t.cross(w0).normalized()
			var col := RUST.darkened(0.1 * (idx % 3))
			var prev := Vector3.ZERO
			for i in 9:
				var ang := TAU * i / 8.0
				var p := c + t * cos(ang) * 0.16 + w * sin(ang) * 0.09
				if i > 0:
					_tube(kit, "rust", prev, p, 0.03, 0.03, 4, col, false)
				prev = p
			d += pitch
			idx += 1


## An admiralty anchor lying on its side: stock flat on the sand, one arm buried, one in the air.
func _wreck_anchor(root: Node3D, kit: Dictionary, ring: Vector3, dir: Vector3) -> void:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	var across := d.cross(Vector3.UP).normalized()
	var iron := RUST.darkened(0.15)
	var r0 := ring
	r0.y = _ground(r0.x, r0.z) + 0.12
	var crown := ring + d * 2.3
	crown.y = _ground(crown.x, crown.z) + 0.1
	_tube(kit, "rust", r0 + d * 0.15, crown, 0.08, 0.11, 8, iron)
	for i in 10:
		var a0 := TAU * i / 10.0
		var a1 := TAU * (i + 1) / 10.0
		_tube(kit, "rust", r0 + (d * cos(a0) + Vector3.UP * sin(a0)) * 0.18 - d * 0.05, r0 + (d * cos(a1) + Vector3.UP * sin(a1)) * 0.18 - d * 0.05, 0.035, 0.035, 4, iron, false)
	var stock := r0 + d * 0.4 + Vector3(0, -0.04, 0)
	_tube(kit, "rust", stock - across * 1.1, stock + across * 1.1, 0.05, 0.05, 6, iron)
	var elbow := crown + Vector3.UP * 0.7 - d * 0.15
	var tip := crown + Vector3.UP * 1.25 - d * 0.55
	_tube(kit, "rust", crown, elbow, 0.1, 0.09, 8, iron)
	_tube(kit, "rust", elbow, tip, 0.09, 0.06, 8, iron)
	var palm := Basis(across, (tip - elbow).normalized().cross(across).normalized(), (tip - elbow).normalized()).orthonormalized()
	_box(kit, "rust", Transform3D(Basis(across, palm.y, palm.z), elbow.lerp(tip, 0.45) - palm.y * 0.04), Vector3(0.55, 0.06, 0.5), iron.lightened(0.05))
	_tube(kit, "rust", crown, crown - Vector3.UP * 0.5 - d * 0.2, 0.1, 0.09, 8, iron)
	_rod_collider(root, "Shipwreck", r0, crown, 0.14)
	_rod_collider(root, "Shipwreck", stock - across * 1.1, stock + across * 1.1, 0.09)
	_rod_collider(root, "Shipwreck", crown, elbow, 0.13)
	_rod_collider(root, "Shipwreck", elbow, tip, 0.13)


## Planks torn out of the side and washed up, and a few things washed off the deck.
func _wreck_debris(root: Node3D, kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var sea := _wreck_xf.basis * Vector3.LEFT
	sea = Vector3(sea.x, 0, sea.z).normalized()
	var fwd := _wreck_xf.basis * Vector3.BACK
	fwd = Vector3(fwd.x, 0, fwd.z).normalized()
	var at := Vector3(WRECK_AT.x, 0, WRECK_AT.y)
	# [seaward, forward, length, yaw, colour]
	var planks := [
		[5.0, 1.5, 3.2, 0.3, HULL_BLUE], [6.5, -1.0, 2.4, 1.2, BARE_WOOD], [5.5, 4.0, 2.8, -0.5, HULL_RED],
		[-6.0, 7.0, 2.6, 0.8, HULL_BLUE], [-7.5, 2.0, 1.8, -1.1, HULL_YELLOW], [4.0, -6.5, 2.0, 0.6, HULL_BLUE],
	]
	for pl in planks:
		var c: Vector3 = at + sea * float(pl[0]) + fwd * float(pl[1])
		var dir := fwd.rotated(Vector3.UP, float(pl[3]))
		var half := float(pl[2]) * 0.5
		var e0 := c - dir * half
		var e1 := c + dir * half
		e0.y = _ground(e0.x, e0.z) + 0.01
		e1.y = _ground(e1.x, e1.z) + 0.01
		var b := Basis.looking_at(e1 - e0, Vector3.UP)
		b = b * Basis(Vector3.BACK, rng.randf_range(-0.15, 0.15))
		var col: Color = (pl[4] as Color).lerp(BARE_WOOD, 0.35).darkened(rng.randf_range(0.0, 0.12))
		_box(kit, "wreck", Transform3D(b, (e0 + e1) * 0.5), Vector3(0.32, 0.06, half * 2.0), col)
	# An oil drum and a fish box washed up the beach, another box wedged against the low bulwark.
	var drum := at - sea * 7.0 + fwd * 9.5
	drum.y = _ground(drum.x, drum.z) + 0.16
	var drum_dir := (fwd.rotated(Vector3.UP, 1.1) + Vector3(0, 0.12, 0)).normalized()
	_tube(kit, "paint", drum - drum_dir * 0.45, drum + drum_dir * 0.45, 0.3, 0.3, 12, Color(0.30, 0.40, 0.50))
	for k in [-0.2, 0.2]:
		_tube(kit, "rust", drum + drum_dir * (k - 0.02), drum + drum_dir * (k + 0.02), 0.315, 0.315, 12, RUST, false)
	_rod_collider(root, "Shipwreck", drum - drum_dir * 0.45, drum + drum_dir * 0.45, 0.3)
	var crate := at - sea * 5.0 - fwd * 4.0
	crate.y = _ground(crate.x, crate.z) + 0.1
	var crate_b := Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, 0.2)
	_box(kit, "gloss", Transform3D(crate_b, crate), Vector3(0.6, 0.32, 0.4), Color(0.95, 0.75, 0.15))
	var crate_shape := BoxShape3D.new()
	crate_shape.size = Vector3(0.6, 0.32, 0.4)
	_collider(root, "Shipwreck", crate_shape, Transform3D(crate_b, crate))
	var ed := _wreck_deck_edge(0.36)
	var deck_box := _wreck_deck_point(ed, 0.8)
	_wbox(kit, "gloss", deck_box + Vector3(-0.3, 0.17, 0), Vector3(0.6, 0.32, 0.4), Color(0.20, 0.50, 0.75), Basis(Vector3.UP, 0.25))


## Every section aft of the forefoot must reach into the sand: a gap under the hull reads as floating.
func _verify_wreck_bedded() -> void:
	var worst := -INF
	var at := 0.0
	for i in 45:
		var s := 0.88 * i / 44.0
		var low := INF
		for j in 17:
			for side in [-1.0, 1.0]:
				var w := _wreck_xf * _wreck_point(s, j / 16.0, side)
				low = minf(low, w.y - _ground(w.x, w.z))
		if low > worst:
			worst = low
			at = s
	if worst > 0.0:
		push_error("Shipwreck: the hull clears the sand by %.2fm at s=%.2f" % [worst, at])
	print("Shipwreck: every section reaches the sand (worst %.2fm at s=%.2f)" % [worst, at])


const STRAW := Color(0.80, 0.68, 0.42)
const BAMBOO := Color(0.78, 0.66, 0.42)


## Beach bar under a shaggy thatch. The board rack is on its north side, which the road comes in
## facing; the counter, the sign and the tables face the sea. Laid out at life size round `c` and
## built at PROP_SCALE, grown landward from the tables.
func _build_surf_shack(root: Node3D) -> void:
	var kit := {}
	var c := Vector3(-14.0, 0.0, 236.0)
	_scale_about(Vector3(c.x - 7.5, 0.0, c.z), PROP_SCALE)
	var g := _ground_min(c.x, c.z, 5.0, 4.0)
	var fl := maxf(g, _ground(c.x - 5.0, c.z)) + 0.7
	var rng := RandomNumberGenerator.new()
	rng.seed = 236
	var teak := Color(0.46, 0.29, 0.17)
	var teal := Color(0.16, 0.56, 0.60)

	# Deck: a dark skirt into the sand, planks across it, two steps up from the sea side.
	_block(kit, "wood", Vector3(c.x - 5.0, g - 0.3, c.z - 4.0), Vector3(c.x + 5.0, fl - 0.08, c.z + 4.0), OLD_WOOD.darkened(0.1))
	var px := c.x - 5.0
	while px < c.x + 5.0 - 0.01:
		_block(kit, "wood", Vector3(px + 0.015, fl - 0.08, c.z - 4.05), Vector3(px + 0.235, fl, c.z + 4.05), WOOD.darkened(rng.randf_range(-0.08, 0.14)))
		px += 0.25
	for s in range(2):
		var sy := fl - 0.25 * (s + 1)
		_block(kit, "wood", Vector3(c.x - 5.35 - 0.35 * s, g - 0.2, c.z - 1.5), Vector3(c.x - 5.0 - 0.35 * s, sy, c.z + 1.5), WOOD.darkened(0.06 * (s + 1)))

	# Bamboo posts up to a ring beam just under the thatch.
	var beam_y := fl + 3.23
	var post_pts := [Vector3(c.x - 4.6, 0, c.z - 3.6), Vector3(c.x + 4.6, 0, c.z - 3.6), Vector3(c.x + 4.6, 0, c.z + 3.6), Vector3(c.x - 4.6, 0, c.z + 3.6)]
	for pp in post_pts:
		var p: Vector3 = pp
		_bamboo(kit, Vector3(p.x, fl - 0.1, p.z), Vector3(p.x, beam_y + 0.05, p.z), 0.13, BAMBOO)
	for i in range(4):
		var a: Vector3 = post_pts[i]
		var b: Vector3 = post_pts[(i + 1) % 4]
		_bamboo(kit, Vector3(a.x, beam_y, a.z), Vector3(b.x, beam_y, b.z), 0.09, BAMBOO.darkened(0.1))

	# Counter: bamboo-clad front, lashed, under a teak top with short returns.
	_block(kit, "wood", Vector3(c.x - 3.1, fl, c.z - 3.0), Vector3(c.x - 2.4, fl + 1.1, c.z + 3.0), OLD_WOOD.darkened(0.2))
	var pz := c.z - 2.97
	var k := 0
	while pz < c.z + 3.0:
		_tube(kit, "wood", Vector3(c.x - 3.15, fl, pz), Vector3(c.x - 3.15, fl + 1.1, pz), 0.048, 0.048, 6, BAMBOO.darkened(0.12 * (k % 3)), false)
		pz += 0.1
		k += 1
	for ry in [0.22, 0.92]:
		_tube(kit, "wood", Vector3(c.x - 3.21, fl + ry, c.z - 3.0), Vector3(c.x - 3.21, fl + ry, c.z + 3.0), 0.018, 0.018, 4, Color(0.36, 0.26, 0.16), false)
	for zs in [-1.0, 1.0]:
		_block(kit, "wood", Vector3(c.x - 3.1, fl, c.z + zs * 3.0 - 0.06), Vector3(c.x - 1.9, fl + 1.1, c.z + zs * 3.0 + 0.06), teal)
	_block(kit, "wood", Vector3(c.x - 3.55, fl + 1.1, c.z - 3.25), Vector3(c.x - 2.2, fl + 1.18, c.z + 3.25), teak)
	# Beer tap, glasses and a jar of straws on the counter.
	var tap := Vector3(c.x - 2.75, fl + 1.18, c.z - 1.4)
	_tube(kit, "metal", tap, tap + Vector3(0, 0.38, 0), 0.04, 0.04, 8, Color(0.85, 0.86, 0.88))
	_tube(kit, "metal", tap + Vector3(0, 0.38, -0.22), tap + Vector3(0, 0.38, 0.22), 0.035, 0.035, 8, Color(0.85, 0.86, 0.88))
	for ti in range(3):
		var hz := -0.18 + ti * 0.18
		_tube(kit, "gloss", tap + Vector3(-0.04, 0.38, hz), tap + Vector3(-0.07, 0.56, hz), 0.016, 0.022, 6, [Color(0.9, 0.3, 0.2), Color(0.98, 0.78, 0.2), Color(0.2, 0.55, 0.85)][ti])
	for gi in range(4):
		var gp := Vector3(c.x - 3.2 + rng.randf_range(-0.12, 0.12), fl + 1.18, c.z + 0.2 + gi * 0.55)
		_tube(kit, "gloss", gp, gp + Vector3(0, 0.15, 0), 0.035, 0.042, 8, [Color(0.98, 0.6, 0.2), Color(0.95, 0.4, 0.55), Color(0.4, 0.8, 0.9), Color(0.98, 0.85, 0.35)][gi])
		_tube(kit, "paint", gp + Vector3(0.01, 0.1, 0), gp + Vector3(0.03, 0.24, 0.01), 0.005, 0.005, 3, WHITE, false)

	# Back bar: cupboard with teal doors, shelves of bottles, a cooler.
	_block(kit, "wood", Vector3(c.x + 4.3, fl, c.z - 3.4), Vector3(c.x + 4.4, fl + 2.6, c.z + 3.4), OLD_WOOD)
	_block(kit, "wood", Vector3(c.x + 3.5, fl, c.z - 3.2), Vector3(c.x + 4.3, fl + 0.95, c.z + 3.2), OLD_WOOD.darkened(0.1))
	_block(kit, "wood", Vector3(c.x + 3.45, fl + 0.95, c.z - 3.25), Vector3(c.x + 4.3, fl + 1.0, c.z + 3.25), teak)
	var dz := c.z - 3.1
	while dz < c.z + 3.0:
		_block(kit, "paint", Vector3(c.x + 3.47, fl + 0.08, dz), Vector3(c.x + 3.5, fl + 0.87, dz + 0.72), teal.lightened(0.08))
		_block(kit, "metal", Vector3(c.x + 3.44, fl + 0.6, dz + 0.6), Vector3(c.x + 3.47, fl + 0.68, dz + 0.64), Color(0.8, 0.8, 0.75))
		dz += 0.78
	var bottle_cols := [Color(0.12, 0.42, 0.18), Color(0.55, 0.30, 0.08), Color(0.62, 0.80, 0.86), Color(0.70, 0.12, 0.12), Color(0.10, 0.25, 0.50)]
	for shelf_y in [1.0, 1.55, 2.05]:
		if shelf_y > 1.0:
			_block(kit, "wood", Vector3(c.x + 3.92, fl + shelf_y - 0.05, c.z - 3.2), Vector3(c.x + 4.3, fl + shelf_y, c.z + 3.2), teak)
		var bz := c.z - 3.05
		while bz < c.z + 3.05:
			if rng.randf() > 0.15:
				_bottle(kit, Vector3(c.x + 4.1 + rng.randf_range(-0.05, 0.05), fl + shelf_y, bz), rng.randf_range(0.2, 0.3), bottle_cols[rng.randi() % bottle_cols.size()])
			bz += rng.randf_range(0.13, 0.2)
	_block(kit, "paint", Vector3(c.x + 2.4, fl, c.z + 2.3), Vector3(c.x + 3.2, fl + 0.5, c.z + 3.1), Color(0.95, 0.95, 0.93))
	_block(kit, "paint", Vector3(c.x + 2.37, fl + 0.5, c.z + 2.27), Vector3(c.x + 3.23, fl + 0.6, c.z + 3.13), Color(0.15, 0.45, 0.8))

	# Bar stools along the counter.
	for i in range(5):
		var stool := Vector3(c.x - 4.1, fl, c.z - 2.4 + i * 1.2)
		for lg in range(3):
			var la := TAU * lg / 3.0
			_tube(kit, "wood", stool + Vector3(cos(la) * 0.2, 0, sin(la) * 0.2), stool + Vector3(0, 0.74, 0), 0.025, 0.025, 4, BAMBOO.darkened(0.15))
		_tube(kit, "wood", stool + Vector3(0, 0.3, 0) + Vector3(0.12, 0, 0), stool + Vector3(0, 0.3, 0) + Vector3(-0.06, 0, 0.1), 0.015, 0.015, 3, BAMBOO, false)
		_tube(kit, "paint", stool + Vector3(0, 0.74, 0), stool + Vector3(0, 0.82, 0), 0.22, 0.2, 10, HUT_COLOURS[i % 6])

	_thatch(kit, rng, Vector3(c.x, fl + 2.7, c.z), 6.2, 5.2, 2.3)

	# String lights round the eaves, sagging between the corners.
	var eave_y := fl + 2.7
	var corners := [Vector3(c.x - 6.0, 0, c.z - 5.0), Vector3(c.x + 6.0, 0, c.z - 5.0), Vector3(c.x + 6.0, 0, c.z + 5.0), Vector3(c.x - 6.0, 0, c.z + 5.0)]
	var bulb_cols := [Color(1.0, 0.85, 0.55), Color(1.0, 0.55, 0.35), Color(0.6, 0.9, 0.8), Color(1.0, 0.75, 0.9)]
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var segs := int(a.distance_to(b) / 0.55)
		var prev := Vector3.ZERO
		for s in range(segs + 1):
			var t := float(s) / segs
			var p := a.lerp(b, t)
			p.y = eave_y - 0.42 - 0.35 * 4.0 * t * (1.0 - t)
			if s > 0:
				_tube(kit, "metal", prev, p, 0.008, 0.008, 3, Color(0.1, 0.1, 0.1), false)
			if s > 0 and s < segs:
				_block(kit, "glow", p + Vector3(-0.035, -0.11, -0.035), p + Vector3(0.035, -0.03, 0.035), bulb_cols[s % 4])
			prev = p

	# Sign hung from the sea-side eave: a sun rising out of the waves.
	_beach_bar_sign(kit, Vector3(c.x - 5.75, eave_y - 0.95, c.z))
	for zs in [-0.9, 0.9]:
		_tube(kit, "metal", Vector3(c.x - 5.75, eave_y - 0.6, c.z + zs), Vector3(c.x - 5.75, eave_y + 0.15, c.z + zs), 0.01, 0.01, 3, Color(0.25, 0.25, 0.25), false)

	# Lifebuoy on the north-west post.
	_lifebuoy(kit, Vector3(c.x - 4.6, fl + 1.7, c.z + 3.78), Vector3(0, 0, 1), 0.3, 0.075)

	# Chalkboard menu out on the sand.
	_menu_board(kit, Vector3(c.x - 6.7, _ground(c.x - 6.7, c.z - 2.4), c.z - 2.4))
	_box_collider(root, "SurfShack", Vector3(c.x - 7.0, _ground(c.x - 6.7, c.z - 2.4) - 0.1, c.z - 2.8), Vector3(c.x - 6.4, _ground(c.x - 6.7, c.z - 2.4) + 1.0, c.z - 2.0))

	# Cable-spool tables and log stools in front, one under a parasol.
	for ti in range(2):
		var tp := Vector3([c.x - 8.3, c.x - 8.8][ti], 0.0, [c.z + 1.8, c.z - 2.2][ti])
		tp.y = _ground(tp.x, tp.z)
		_tube(kit, "wood", tp + Vector3(0, -0.1, 0), tp + Vector3(0, 0.06, 0), 0.55, 0.55, 14, WOOD.darkened(0.15))
		_tube(kit, "wood", tp + Vector3(0, 0.06, 0), tp + Vector3(0, 0.66, 0), 0.24, 0.24, 10, OLD_WOOD)
		_tube(kit, "wood", tp + Vector3(0, 0.66, 0), tp + Vector3(0, 0.74, 0), 0.6, 0.6, 14, WOOD)
		_rod_collider(root, "SurfShack", tp + Vector3(0, -0.1, 0), tp + Vector3(0, 0.74, 0), 0.6)
		for si in range(3):
			var sa := TAU * si / 3.0 + ti * 0.7
			var sp := tp + Vector3(cos(sa) * 0.95, 0, sin(sa) * 0.95)
			sp.y = _ground(sp.x, sp.z)
			_tube(kit, "wood", sp + Vector3(0, -0.1, 0), sp + Vector3(0, 0.45, 0), 0.19, 0.18, 9, OLD_WOOD.lightened(0.1))
			_rod_collider(root, "SurfShack", sp + Vector3(0, -0.1, 0), sp + Vector3(0, 0.45, 0), 0.19)
		for gi in range(2):
			var gp := tp + Vector3(0.2 - gi * 0.35, 0.74, 0.15 * gi)
			_tube(kit, "gloss", gp, gp + Vector3(0, 0.15, 0), 0.035, 0.042, 8, [Color(0.98, 0.6, 0.2), Color(0.4, 0.8, 0.9)][gi])
		if ti == 0:
			_umbrella(kit, tp, Vector3.ZERO, [teal, WHITE])
			var canopy := CylinderShape3D.new()
			canopy.radius = 1.3
			canopy.height = 0.3
			_collider(root, "SurfShack", canopy, Transform3D(Basis(), tp + Vector3(0, 2.05, 0)))
		_note("ShackTable%d" % ti, Vector2(tp.x, tp.z), 1.2, CLEAR_DECOR)

	# Board rack on the north side: boards stand on their tails against a bamboo rail, decks out.
	var rack_z := c.z + 5.7
	for rx in [c.x - 4.4, c.x - 1.0, c.x + 2.4]:
		var rg := _ground(rx, rack_z)
		_bamboo(kit, Vector3(rx, rg - 0.3, rack_z), Vector3(rx, rg + 1.6, rack_z), 0.07, BAMBOO)
	var rg0 := _ground(c.x - 1.0, rack_z)
	_bamboo(kit, Vector3(c.x - 4.5, rg0 + 1.45, rack_z), Vector3(c.x + 2.5, rg0 + 1.45, rack_z), 0.05, BAMBOO.darkened(0.08))
	_bamboo(kit, Vector3(c.x - 4.5, rg0 + 0.3, rack_z), Vector3(c.x + 2.5, rg0 + 0.3, rack_z), 0.05, BAMBOO.darkened(0.08))
	var rack_boards := [
		[0, 0, 2.05, Color(0.98, 0.45, 0.32), WHITE, Color(0.98, 0.45, 0.32)],
		[1, 1, 2.75, Color(0.98, 0.93, 0.80), Color(0.20, 0.58, 0.80), Color(0.20, 0.58, 0.80)],
		[2, 2, 1.80, Color(0.98, 0.85, 0.30), Color(0.12, 0.45, 0.55), Color(0.98, 0.85, 0.30)],
		[0, 2, 1.95, WHITE, Color(0.90, 0.25, 0.30), Color(0.90, 0.25, 0.30)],
		[1, 0, 2.85, Color(0.35, 0.75, 0.70), WHITE, Color(0.98, 0.93, 0.80)],
		[0, 1, 2.0, Color(0.55, 0.45, 0.85), Color(0.98, 0.85, 0.30), Color(0.55, 0.45, 0.85)],
	]
	for i in range(rack_boards.size()):
		var bd: Array = rack_boards[i]
		var bx := c.x - 3.9 + i * 1.1 + rng.randf_range(-0.08, 0.08)
		var lean := deg_to_rad(-11.0 - rng.randf_range(0.0, 3.0))
		var foot := Vector3(bx, _ground(bx, rack_z + 0.4) - 0.04, rack_z + 0.09 + 1.45 * tan(-lean))
		var bb := Basis(Vector3.UP, rng.randf_range(-0.06, 0.06)) * Basis(Vector3.RIGHT, lean) * Basis(Vector3.UP, rng.randf_range(-0.05, 0.05))
		_surfboard(kit, Transform3D(bb, foot), bd[2], bd[0], bd[1], bd[3], bd[4], bd[5])
	_box_collider(root, "BoardRack", Vector3(c.x - 4.6, rg0 - 0.3, rack_z - 0.15), Vector3(c.x + 2.6, rg0 + 1.6, rack_z + 0.45))
	_note("BoardRack", Vector2(c.x - 1.0, rack_z), 3.6, CLEAR_BUILDING)

	# A longboard on two sawhorses, being waxed.
	var hz := c.z + 6.7
	var hg := _ground(c.x + 4.0, hz)
	for sx in [c.x + 3.1, c.x + 4.9]:
		_sawhorse(kit, Vector3(sx, hg, hz))
	var lb_basis := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	_surfboard(kit, Transform3D(lb_basis, Vector3(c.x + 2.6, hg + 0.80, hz)), 2.8, 1, 0, Color(0.98, 0.93, 0.80), Color(0.95, 0.40, 0.30), Color(0.95, 0.40, 0.30))
	_block(kit, "paint", Vector3(c.x + 4.5, hg + 0.84, hz - 0.08), Vector3(c.x + 4.62, hg + 0.88, hz + 0.02), Color(0.98, 0.75, 0.82))
	_box_collider(root, "Sawhorses", Vector3(c.x + 2.5, hg - 0.2, hz - 0.45), Vector3(c.x + 5.5, hg + 0.9, hz + 0.45))
	_note("Sawhorses", Vector2(c.x + 4.0, hz), 1.6, CLEAR_BUILDING)

	# One short board stuck nose-up in the sand by the tables.
	var sp2 := Vector3(c.x - 7.2, 0.0, c.z + 4.3)
	sp2.y = _ground(sp2.x, sp2.z)
	var stuck := Basis(Vector3.UP, 0.9) * Basis(Vector3.FORWARD, 0.12) * Basis(Vector3.RIGHT, PI)
	_surfboard(kit, Transform3D(stuck, sp2 + Vector3(0, 1.75, 0)), 1.95, 0, 2, Color(0.20, 0.58, 0.80), WHITE, Color(0.98, 0.85, 0.30))
	var stuck_axis := stuck * Vector3.UP
	_box_along(root, "SurfShack", sp2 + Vector3(0, 0.8, 0), stuck_axis, Vector3(0.55, 0.12, 1.9))
	_note("StuckBoard", Vector2(sp2.x, sp2.z), 0.5, CLEAR_DECOR)

	_commit(root, kit, "SurfShack")
	_box_collider(root, "SurfShack", Vector3(c.x - 5.7, g - 0.3, c.z - 4.0), Vector3(c.x + 5.0, fl + 2.7, c.z + 4.0))
	# The thatch overhangs the deck on every side.
	var ey := fl + 2.7
	_hull_collider(root, "SurfShack", PackedVector3Array([
		Vector3(c.x - 6.2, ey - 0.4, c.z - 5.2), Vector3(c.x + 6.2, ey - 0.4, c.z - 5.2), Vector3(c.x - 6.2, ey - 0.4, c.z + 5.2),
		Vector3(c.x + 6.2, ey - 0.4, c.z + 5.2), Vector3(c.x - 1.0, ey + 2.3, c.z), Vector3(c.x + 1.0, ey + 2.3, c.z)]))
	_note("SurfShack", Vector2(c.x, c.z), 6.4, CLEAR_BUILDING)
	_end_scale()


## A bamboo cane: a tube with a raised node every 45cm.
func _bamboo(kit: Dictionary, a: Vector3, b: Vector3, r: float, col: Color) -> void:
	_tube(kit, "wood", a, b, r, r * 0.92, 8, col)
	var dir := (b - a).normalized()
	var nodes := int(a.distance_to(b) / 0.45)
	for i in range(1, nodes + 1):
		var p := a.lerp(b, float(i) / (nodes + 1))
		_tube(kit, "wood", p - dir * 0.025, p + dir * 0.025, r * 1.14, r * 1.14, 8, col.lightened(0.18))


func _bottle(kit: Dictionary, base: Vector3, h: float, col: Color) -> void:
	var up := Vector3.UP
	_tube(kit, "gloss", base, base + up * h * 0.66, 0.034, 0.034, 8, col)
	_tube(kit, "paint", base + up * h * 0.22, base + up * h * 0.48, 0.0355, 0.0355, 8, Color(0.95, 0.92, 0.82), false)
	_tube(kit, "gloss", base + up * h * 0.66, base + up * h * 0.8, 0.034, 0.013, 8, col, false)
	_tube(kit, "gloss", base + up * h * 0.8, base + up * h, 0.013, 0.013, 6, col, false)
	_tube(kit, "metal", base + up * h, base + up * (h + 0.015), 0.015, 0.015, 6, Color(0.8, 0.7, 0.3))


## A hipped thatch: the eave rectangle (half sizes hx by hz) at `eave`, the ridge `rise` above, laid in
## four courses that each end in a shaggy fringe, with bamboo rafters showing underneath.
func _thatch(kit: Dictionary, rng: RandomNumberGenerator, eave: Vector3, hx: float, hz: float, rise: float) -> void:
	var st := _st(kit, "thatch")
	var straw := STRAW
	var ridge_hx := hx - hz
	var level := func(v: float) -> Array:
		var ax := hx - v * hz
		var az := hz * (1.0 - v)
		var y := eave.y + v * rise
		return [Vector3(eave.x - ax, y, eave.z - az), Vector3(eave.x + ax, y, eave.z - az), Vector3(eave.x + ax, y, eave.z + az), Vector3(eave.x - ax, y, eave.z + az)]
	var outs := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	# Base surface, top and underside.
	var lo: Array = level.call(0.0)
	var hi: Array = level.call(1.0)
	for i in range(4):
		var o: Vector3 = outs[i]
		var n := (o * rise + Vector3.UP * hz).normalized()
		var a: Vector3 = lo[i]
		var b: Vector3 = lo[(i + 1) % 4]
		var ha: Vector3 = hi[i]
		var hb: Vector3 = hi[(i + 1) % 4]
		_tri(st, a, b, hb, n, n, n, straw.darkened(0.08), n)
		_tri(st, a, hb, ha, n, n, n, straw.darkened(0.08), n)
		_tri(st, a, b, hb, -n, -n, -n, straw.lightened(0.05), -n)
		_tri(st, a, hb, ha, -n, -n, -n, straw.lightened(0.05), -n)
	# Courses: a fringe of straw tufts along each level, hanging down the slope (straight down at the eave).
	var courses := 4
	for kc in range(courses):
		var v := float(kc) / courses
		var ring: Array = level.call(v + 0.02)
		for i in range(4):
			var o: Vector3 = outs[i]
			var n := (o * rise + Vector3.UP * hz).normalized()
			var down := (o * hz - Vector3.UP * rise).normalized()
			if kc == 0:
				down = (o * 0.35 - Vector3.UP).normalized()
			var a: Vector3 = ring[i]
			var b: Vector3 = ring[(i + 1) % 4]
			var along := (b - a).normalized()
			var edge_len := a.distance_to(b)
			var fn := n if kc > 0 else (o + Vector3.UP * 0.3).normalized()
			# Narrow overlapping blades of uneven length, so the edge reads as straw, not bunting.
			for layer in range(2 if kc == 0 else 1):
				var spacing := 0.13
				var u := -0.05 + layer * spacing * 0.5
				while u < edge_len + 0.05:
					var wdt := rng.randf_range(0.10, 0.2)
					var lift := n * (0.07 + 0.02 * kc + 0.035 * layer) + Vector3.UP * (0.04 * layer)
					var p0 := a + along * (u - wdt * 0.5) + lift
					var p1 := a + along * (u + wdt * 0.5) + lift
					var drop := rng.randf_range(0.35, 0.75) * (0.8 if layer == 1 else 1.0)
					var tip := (p0 + p1) * 0.5 + down * drop + along * rng.randf_range(-0.07, 0.07)
					var col := straw.darkened(rng.randf_range(-0.10, 0.2))
					_tri(st, p0, p1, tip, fn, fn, fn, col, fn)
					_tri(st, p0, p1, tip, -fn, -fn, -fn, col.darkened(0.15), -fn)
					u += spacing
	# Ridge and hips capped with darker bundles.
	var cap := straw.darkened(0.25)
	_tube(kit, "thatch", hi[0] + Vector3(-0.15, 0.08, 0), hi[1] + Vector3(0.15, 0.08, 0), 0.16, 0.16, 8, cap)
	var hip_tops := [hi[0], hi[1], hi[1], hi[0]]
	for i in range(4):
		_tube(kit, "thatch", lo[i] + Vector3(0, 0.06, 0), hip_tops[i] + Vector3(0, 0.08, 0), 0.1, 0.12, 6, cap)
	# Rafters under the thatch, from the eaves up to the ridge.
	var ridge_a: Vector3 = hi[0]
	var ridge_b: Vector3 = hi[1]
	for i in [0, 2]:
		var a: Vector3 = lo[i]
		var b: Vector3 = lo[(i + 1) % 4]
		var n := ((outs[i] as Vector3) * rise + Vector3.UP * hz).normalized()
		var steps := int(a.distance_to(b) / 1.1)
		for s in range(steps + 1):
			var p := a.lerp(b, float(s) / steps)
			var top := Vector3(clampf(p.x, ridge_a.x, ridge_b.x), ridge_a.y, eave.z)
			_tube(kit, "wood", p - n * 0.1, top - n * 0.1, 0.045, 0.04, 5, BAMBOO.darkened(0.2), false)
	for i in [1, 3]:
		var mid: Vector3 = (lo[i] + lo[(i + 1) % 4]) * 0.5
		var n2 := ((outs[i] as Vector3) * rise + Vector3.UP * hz).normalized()
		var top2: Vector3 = ridge_b if i == 1 else ridge_a
		_tube(kit, "wood", mid - n2 * 0.1, top2 - n2 * 0.1, 0.045, 0.04, 5, BAMBOO.darkened(0.2), false)


## A surfboard in its own frame: tail at the origin, nose up +y, deck facing +z.
## style 0 shortboard (pointed nose, squash tail, three fins), 1 longboard (round nose, one big fin),
## 2 fish (wide full tail, twin keels). design 0 stripes near the nose, 1 two-tone, 2 centre stripe.
func _surfboard(kit: Dictionary, xf: Transform3D, length: float, style: int, design: int, deck: Color, accent: Color, rail: Color) -> void:
	var p := {
		"len": length,
		"w": [0.50, 0.57, 0.56][style],
		"thick": [0.062, 0.078, 0.066][style],
		"tail": [0.56, 0.60, 0.80][style],
		"nose": [0.80, 0.40, 0.62][style],
		"rocker": [0.13, 0.10, 0.08][style],
	}
	var ts: Array = []
	for i in range(31):
		ts.append(float(i) / 30.0)
	# A ring on each stripe edge keeps the colour edges crisp.
	var edges: Array = [[0.60, 0.635, 0.66, 0.68], [0.42], []][design]
	ts.append_array(edges)
	ts.sort()
	var around := 16
	var st := _st(kit, "gloss")
	var nb := xf.basis.inverse().transposed()
	for i in range(ts.size() - 1):
		var t0: float = ts[i]
		var t1: float = ts[i + 1]
		if t1 - t0 < 1e-4:
			continue
		var tm := (t0 + t1) * 0.5
		for j in range(around):
			# Offset by half a step so a quad sits on the deck's centre line and on each rail.
			var a0 := TAU * (j - 0.5) / around
			var a1 := TAU * (j + 0.5) / around
			var am := TAU * j / around
			var col := _board_colour(tm, am, design, deck, accent, rail)
			var q00 := xf * _board_point(p, t0, a0)
			var q01 := xf * _board_point(p, t0, a1)
			var q10 := xf * _board_point(p, t1, a0)
			var q11 := xf * _board_point(p, t1, a1)
			var n00 := (nb * _board_normal(p, t0, a0)).normalized()
			var n01 := (nb * _board_normal(p, t0, a1)).normalized()
			var n10 := (nb * _board_normal(p, t1, a0)).normalized()
			var n11 := (nb * _board_normal(p, t1, a1)).normalized()
			var out := (nb * Vector3(cos(am), 0.0, sin(am))).normalized()
			_tri(st, q00, q01, q11, n00, n01, n11, col, out)
			_tri(st, q00, q11, q10, n00, n11, n10, col, out)
	# Tail cap.
	var tail_c := xf * Vector3(0.0, 0.0, _board_point(p, 0.0, 0.0).z)
	var down := (nb * Vector3.DOWN).normalized()
	for j in range(around):
		var a0 := TAU * (j - 0.5) / around
		var a1 := TAU * (j + 0.5) / around
		_tri(st, tail_c, xf * _board_point(p, 0.0, a0), xf * _board_point(p, 0.0, a1), down, down, down, rail, down)
	# Stringer down the deck of the painted designs.
	if design != 2:
		var sc := Color(0.55, 0.40, 0.25)
		for i in range(1, 29):
			var t0 := float(i) / 30.0
			var t1 := float(i + 1) / 30.0
			var d0 := _board_point(p, t0, PI * 0.5) + Vector3(0, 0, 0.0015)
			var d1 := _board_point(p, t1, PI * 0.5) + Vector3(0, 0, 0.0015)
			var up := (nb * _board_normal(p, t0, PI * 0.5)).normalized()
			_quad(kit, "gloss", [xf * (d0 + Vector3(-0.005, 0, 0)), xf * (d0 + Vector3(0.005, 0, 0)), xf * (d1 + Vector3(0.005, 0, 0)), xf * (d1 + Vector3(-0.005, 0, 0))], up, sc)
	# Fins under the tail.
	var fin_col := Color(0.20, 0.22, 0.25) if style != 1 else accent
	var half_at := func(y: float) -> float:
		return absf(_board_point(p, y / length, 0.0).x)
	var fins: Array = []
	match style:
		0:
			fins = [[0.0, 0.05, 0.17, 0.11], [0.62 * half_at.call(0.28), 0.22, 0.33, 0.10], [-0.62 * half_at.call(0.28), 0.22, 0.33, 0.10]]
		1:
			fins = [[0.0, 0.08, 0.30, 0.2]]
		2:
			fins = [[0.6 * half_at.call(0.15), 0.05, 0.26, 0.09], [-0.6 * half_at.call(0.15), 0.05, 0.26, 0.09]]
	for f in fins:
		var fx: float = f[0]
		var y0: float = f[1]
		var y1: float = f[2]
		var depth: float = f[3]
		var bz0 := _board_point(p, y0 / length, -PI * 0.5).z + 0.004
		var bz1 := _board_point(p, y1 / length, -PI * 0.5).z + 0.004
		var tip := Vector3(fx, y0 - 0.03, bz0 - depth)
		var b0 := Vector3(fx, y0, bz0)
		var b1 := Vector3(fx, y1, bz1)
		for side in [-1.0, 1.0]:
			var o := Vector3(0.004 * side, 0, 0)
			var fn := (nb * Vector3(side, 0, 0)).normalized()
			_tri(st, xf * (b0 + o), xf * (b1 + o), xf * (tip + o), fn, fn, fn, fin_col, fn)
		var edge_n := (nb * Vector3(0, 1, -0.3)).normalized()
		_quad(kit, "gloss", [xf * (b1 + Vector3(-0.004, 0, 0)), xf * (b1 + Vector3(0.004, 0, 0)), xf * (tip + Vector3(0.004, 0, 0)), xf * (tip + Vector3(-0.004, 0, 0))], edge_n, fin_col)


## A point on a board's skin: t along it (0 tail, 1 nose), a round its cross-section (0 the +x rail,
## PI/2 the middle of the deck, 3PI/2 the bottom).
func _board_point(p: Dictionary, t: float, a: float) -> Vector3:
	var tail: float = p["tail"]
	var f := tail + (1.0 - tail) * sin(PI * 0.5 * minf(t / 0.42, 1.0))
	if t > 0.5:
		f *= pow(clampf((1.0 - t) / 0.5, 0.0, 1.0), float(p["nose"]))
	var half := 0.5 * float(p["w"]) * f
	var th := 0.5 * float(p["thick"]) * (0.3 + 0.7 * sin(PI * clampf(t, 0.0, 1.0)))
	var c := cos(a)
	var s := sin(a)
	var x := half * signf(c) * pow(absf(c), 0.55)
	var z := th * signf(s) * pow(absf(s), 0.85)
	if s < 0.0:
		z *= 0.55
	var rk: float = p["rocker"]
	var lift := rk * pow(smoothstep(0.55, 1.0, t), 2.0) + rk * 0.35 * pow(1.0 - minf(t / 0.3, 1.0), 2.0)
	return Vector3(x, t * float(p["len"]), z + lift)


func _board_normal(p: Dictionary, t: float, a: float) -> Vector3:
	var along := _board_point(p, minf(t + 0.004, 1.0), a) - _board_point(p, maxf(t - 0.004, 0.0), a)
	var round_ := _board_point(p, t, a + 0.02) - _board_point(p, t, a - 0.02)
	var n := along.cross(round_)
	var guess := Vector3(cos(a), 0.0, sin(a))
	if n.length_squared() < 1e-12:
		return (guess + Vector3(0, 0.4 if t > 0.5 else -0.4, 0)).normalized()
	n = n.normalized()
	return n if n.dot(guess) > 0.0 else -n


func _board_colour(t: float, a: float, design: int, deck: Color, accent: Color, rail: Color) -> Color:
	var s := sin(a)
	if absf(s) < 0.45:
		return rail
	if s < 0.0:
		return Color(0.96, 0.96, 0.93)
	match design:
		0:
			if (t > 0.60 and t < 0.635) or (t > 0.66 and t < 0.68):
				return accent
		1:
			if t < 0.42:
				return accent
		2:
			if absf(cos(a)) < 0.2:
				return accent
	return deck


func _sawhorse(kit: Dictionary, at: Vector3) -> void:
	var top := at + Vector3(0, 0.72, 0)
	_block(kit, "wood", top + Vector3(-0.06, 0.0, -0.45), top + Vector3(0.06, 0.06, 0.45), WOOD)
	for zs in [-0.35, 0.35]:
		for xs in [-1.0, 1.0]:
			_tube(kit, "wood", at + Vector3(xs * 0.22, -0.1, zs), top + Vector3(0, 0, zs), 0.03, 0.03, 4, OLD_WOOD)


func _lifebuoy(kit: Dictionary, centre: Vector3, axis: Vector3, radius: float, tube_r: float) -> void:
	var side := axis.cross(Vector3.UP).normalized()
	var up := side.cross(axis).normalized()
	var segs := 16
	for i in range(segs):
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var p0 := centre + (side * cos(a0) + up * sin(a0)) * radius
		var p1 := centre + (side * cos(a1) + up * sin(a1)) * radius
		var col := Color(0.92, 0.22, 0.18) if (i / 2) % 2 == 0 else WHITE
		_tube(kit, "gloss", p0, p1, tube_r, tube_r, 8, col, false)
	# Grab line looped round it.
	for i in range(4):
		var a := TAU * (i + 0.5) / 4.0
		var p := centre + (side * cos(a) + up * sin(a)) * (radius + tube_r)
		_tube(kit, "paint", p - axis * 0.02, p + axis * 0.02, 0.012, 0.012, 4, Color(0.85, 0.8, 0.6), false)


## A-frame chalkboard with a menu chalked on the sea side.
func _menu_board(kit: Dictionary, at: Vector3) -> void:
	var slate := Color(0.13, 0.19, 0.16)
	var chalk := [Color(0.95, 0.95, 0.9), Color(0.98, 0.75, 0.82), Color(0.98, 0.88, 0.5)]
	for side in [-1.0, 1.0]:
		var b := Basis(Vector3.BACK, side * 0.22)
		var centre := at + Vector3(side * 0.13, 0.5, 0)
		_box(kit, "wood", Transform3D(b, centre), Vector3(0.04, 1.0, 0.7), OLD_WOOD)
		_box(kit, "paint", Transform3D(b, centre + b * Vector3(side * 0.005, 0, 0)), Vector3(0.045, 0.86, 0.58), slate)
		if side < 0.0:
			var face := b * Vector3(-1, 0, 0)
			var y := 0.3
			var line := 0
			while y > -0.34:
				var w := 0.42 if line == 0 else 0.2 + 0.22 * fposmod(line * 0.618, 1.0)
				var col: Color = chalk[1] if line == 0 else chalk[0]
				var lc := centre + b * Vector3(-0.033, y, -0.2 + w * 0.5)
				var lx := b * Vector3(0, 0, w * 0.5)
				var ly := b * Vector3(0, 0.012 if line > 0 else 0.022, 0)
				_quad(kit, "paint", [lc - lx - ly, lc + lx - ly, lc + lx + ly, lc - lx + ly], face, col)
				if line > 0:
					var pc := centre + b * Vector3(-0.033, y, 0.21)
					var px2 := b * Vector3(0, 0, 0.03)
					_quad(kit, "paint", [pc - px2 - ly, pc + px2 - ly, pc + px2 + ly, pc - px2 + ly], face, chalk[2])
				y -= 0.095 if line > 0 else 0.13
				line += 1


## The bar's sign: a plank board with a sun rising out of two waves, facing the sea (-x).
func _beach_bar_sign(kit: Dictionary, centre: Vector3) -> void:
	var w := 1.0     # half width along z
	var h := 0.36    # half height
	_block(kit, "wood", centre + Vector3(0.0, -h - 0.05, -w - 0.05), centre + Vector3(0.06, h + 0.05, w + 0.05), OLD_WOOD)
	var face := Vector3(-1, 0, 0)
	var fx := centre.x - 0.004
	var sky := [Color(0.98, 0.62, 0.38), Color(0.98, 0.78, 0.45), Color(0.98, 0.9, 0.62)]
	for bnd in range(3):
		var y0 := centre.y + h - (bnd + 1) * (h * 2.0 / 3.0)
		var y1 := centre.y + h - bnd * (h * 2.0 / 3.0)
		_quad(kit, "paint", [Vector3(fx, y0, centre.z - w), Vector3(fx, y0, centre.z + w), Vector3(fx, y1, centre.z + w), Vector3(fx, y1, centre.z - w)], face, sky[2 - bnd])
	# Sun: a half disc on the horizon.
	var st := _st(kit, "paint")
	var sun_c := Vector3(fx - 0.004, centre.y - 0.08, centre.z)
	for i in range(12):
		var a0 := PI * i / 12.0
		var a1 := PI * (i + 1) / 12.0
		_tri(st, sun_c, sun_c + Vector3(0, sin(a0), cos(a0)) * 0.3, sun_c + Vector3(0, sin(a1), cos(a1)) * 0.3, face, face, face, Color(0.98, 0.42, 0.22), face)
	# Two waves across the bottom, white crest lines over blue.
	for wv in range(2):
		var base_y := centre.y - h + 0.02 + wv * 0.13
		var col: Color = [Color(0.12, 0.42, 0.68), Color(0.2, 0.62, 0.78)][wv]
		var segs := 20
		for s in range(segs):
			var z0 := centre.z - w + 2.0 * w * s / segs
			var z1 := centre.z - w + 2.0 * w * (s + 1) / segs
			var c0 := base_y + 0.12 + 0.05 * sin(z0 * 7.0 + wv * 1.8)
			var c1 := base_y + 0.12 + 0.05 * sin(z1 * 7.0 + wv * 1.8)
			var lx := fx - 0.008 - wv * 0.003
			_quad(kit, "paint", [Vector3(lx, centre.y - h, z0), Vector3(lx, centre.y - h, z1), Vector3(lx, c1, z1), Vector3(lx, c0, z0)], face, col)
			_quad(kit, "paint", [Vector3(lx - 0.002, c0 - 0.02, z0), Vector3(lx - 0.002, c1 - 0.02, z1), Vector3(lx - 0.002, c1 + 0.01, z1), Vector3(lx - 0.002, c0 + 0.01, z0)], face, WHITE)


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


## Parasol sets spread over the dry sand between the racing line and the dune fence, and round the
## beach's far ends: rejection-sampled per zone, PARASOL_GAP apart and clear of everything noted so far.
const PARASOL_ZONES := [
	# x from, x to, z from, z to, sets
	[-32.0, -16.0, -246.0, -104.0, 10],
	[-32.0, -16.0, -96.0, 20.0, 8],
	[-32.0, -16.0, 76.0, 138.0, 5],
	[-64.0, -30.0, -352.0, -292.0, 5],
	[-64.0, -26.0, 296.0, 352.0, 4],
]
const PARASOL_GAP := 11.0
const PARASOL_SET_R := 1.9     # a set's footprint at life size


func _build_umbrellas(root: Node3D) -> void:
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var placed: Array = []
	for zone in PARASOL_ZONES:
		var got := 0
		var tries := 0
		while got < int(zone[4]) and tries < 600:
			tries += 1
			var p := Vector2(rng.randf_range(zone[0], zone[1]), rng.randf_range(zone[2], zone[3]))
			if not _parasol_spot_ok(p, placed):
				continue
			_parasol_set(root, kit, rng, p, placed.size())
			placed.append(p)
			got += 1
	_commit(root, kit, "Umbrellas")
	print("Seafront: %d parasol sets" % placed.size())


func _parasol_spot_ok(p: Vector2, placed: Array) -> bool:
	for o in placed:
		if p.distance_to(o) < PARASOL_GAP:
			return false
	var y := _ground(p.x, p.y)
	# Dry sand above the swash, nearly level.
	if y < 0.8:
		return false
	var slope := maxf(absf(_ground(p.x + 2.0, p.y) - _ground(p.x - 2.0, p.y)), absf(_ground(p.x, p.y + 2.0) - _ground(p.x, p.y - 2.0))) / 4.0
	if slope > 0.2:
		return false
	var r := PARASOL_SET_R * PROP_SCALE
	var q := _curve.get_closest_point(Vector3(p.x, y, p.y))
	if Vector2(q.x, q.z).distance_to(p) - r - TRACK_HALF < CLEAR_DECOR + 0.5:
		return false
	for f in _footprints:
		if p.distance_to(f[1]) < float(f[2]) + r + 1.5:
			return false
	return true


## One parasol with loungers under it facing the sea, sometimes a towel spread in front and a cool
## box, laid out at life size round the parasol's foot and built at PROP_SCALE.
func _parasol_set(root: Node3D, kit: Dictionary, rng: RandomNumberGenerator, p: Vector2, n: int) -> void:
	_scale_about(Vector3(p.x, 0.0, p.y), PROP_SCALE)
	var at := Vector3(p.x, _ground(p.x, p.y), p.y)
	var tilt := Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
	_umbrella(kit, at, tilt, [HUT_COLOURS[rng.randi() % 6], WHITE])
	var top := at + (Vector3.UP + tilt).normalized() * 2.4
	_rod_collider(root, "Parasols", at + Vector3(0, -0.3, 0), top, 0.06)
	var canopy := CylinderShape3D.new()
	canopy.radius = 1.3
	canopy.height = 0.3
	_collider(root, "Parasols", canopy, Transform3D(Basis(), top - Vector3(0, 0.35, 0)))
	# Backrests to the land: the loungers face the sea, side by side either side of the pole.
	var yaw := -PI * 0.5 + rng.randf_range(-0.35, 0.35)
	var b := Basis(Vector3.UP, yaw)
	var count := 1 if rng.randf() < 0.3 else 2
	var lounger_col: Color = [Color(0.95, 0.95, 0.92), Color(0.25, 0.55, 0.75), HUT_COLOURS[rng.randi() % 6]][rng.randi() % 3]
	for i in count:
		var off := 0.55 if count == 1 else (i - 0.5) * 0.95
		var lp := at + b * Vector3(off, 0, 0.2)
		lp.y = _ground(lp.x, lp.z)
		_lounger(kit, lp, yaw, lounger_col)
		var box := BoxShape3D.new()
		box.size = Vector3(0.7, 0.62, 1.55)
		_collider(root, "Loungers", box, Transform3D(b, lp + b * Vector3(0, 0.31, -0.05)))
	if rng.randf() < 0.6:
		var tp := at + Vector3(-2.3, 0, rng.randf_range(-1.0, 1.0))
		tp.y = _ground(tp.x, tp.z) + 0.02
		_box(kit, "canvas", Transform3D(Basis(Vector3.UP, rng.randf_range(-0.5, 0.5)), tp), Vector3(1.8, 0.03, 0.9), HUT_COLOURS[rng.randi() % 6])
	if rng.randf() < 0.4:
		var cp := at + b * Vector3(1.4 if count == 2 else -0.6, 0, 0.6)
		cp.y = _ground(cp.x, cp.z)
		var cb := Basis(Vector3.UP, rng.randf_range(0.0, PI))
		_box(kit, "gloss", Transform3D(cb, cp + Vector3(0, 0.17, 0)), Vector3(0.55, 0.34, 0.36), Color(0.20, 0.50, 0.80))
		_box(kit, "paint", Transform3D(cb, cp + Vector3(0, 0.37, 0)), Vector3(0.57, 0.06, 0.38), WHITE)
		var cool := BoxShape3D.new()
		cool.size = Vector3(0.57, 0.4, 0.38)
		_collider(root, "Loungers", cool, Transform3D(cb, cp + Vector3(0, 0.2, 0)))
	_note("Parasol%d" % n, p, PARASOL_SET_R, CLEAR_DECOR)
	_end_scale()


## Weathered slatted sand fence along the dune foot, half buried in places: posts at the ends of each
## bay, slats between, two wires. Built at PROP_SCALE (a bay is 2m at life size); each bay is one
## thin box of collision.
func _build_sand_fence(root: Node3D) -> void:
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var k := PROP_SCALE
	var bay := 2.0 * k
	var z := -248.0
	var grey := Color(0.60, 0.56, 0.50)
	while z < 128.0:
		# Gaps where the beach paths come down from the dunes.
		if absf(z - 0.0) < 5.0 or absf(z + 100.0) < 5.0:
			z += bay
			continue
		var x := -12.5 + 1.2 * sin(z * 0.05) + 0.6 * sin(z * 0.17)
		var x2 := -12.5 + 1.2 * sin((z + bay) * 0.05) + 0.6 * sin((z + bay) * 0.17)
		var y := _ground(x, z)
		var y2 := _ground(x2, z + bay)
		var bury := rng.randf_range(0.0, 0.5) * k
		_tube(kit, "wood", Vector3(x, y - 0.4 * k, z), Vector3(x, y + 1.3 * k - bury, z), 0.06 * k, 0.05 * k, 6, grey.darkened(0.1))
		for s in range(7):
			var t := (s + 0.5) / 7.0
			var sx := lerpf(x, x2, t)
			var sz := lerpf(z, z + bay, t)
			var sy := lerpf(y, y2, t)
			var lean := Vector3(rng.randf_range(-0.08, 0.08) * k, 0, 0)
			_tube(kit, "wood", Vector3(sx, sy - 0.3 * k, sz), Vector3(sx, sy + 1.1 * k - bury, sz) + lean, 0.035 * k, 0.03 * k, 4, grey.lightened(rng.randf_range(-0.1, 0.1)), false)
		for wy in [0.35, 0.85]:
			_tube(kit, "wood", Vector3(x, y + wy * k - bury, z), Vector3(x2, y2 + wy * k - bury, z + bay), 0.015 * k, 0.015 * k, 3, Color(0.3, 0.3, 0.3), false)
		var lo := minf(y, y2) - 0.3 * k
		var hi := maxf(y, y2) + 1.2 * k - bury
		_box_along(root, "SandFence", Vector3((x + x2) * 0.5, (lo + hi) * 0.5, z + bay * 0.5), Vector3(x2 - x, 0, bay), Vector3(0.2, hi - lo, Vector2(x2 - x, bay).length() + 0.1))
		_note("Fence", Vector2(x, z), 0.2, CLEAR_DECOR)
		z += bay
	_commit(root, kit, "SandFence")


## A yacht at anchor beyond the bar and two sailing boats far out.
func _build_boats(root: Node3D) -> void:
	var yacht: Node3D = load("res://models/boats/super_yacht02.glb").instantiate()
	yacht.name = "AnchoredYacht"
	root.add_child(yacht)
	yacht.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-70.0)).scaled(Vector3.ONE * 0.08), Vector3(-360.0, 0.25, -60.0))
	# Its box, from the model's own bounds.
	var bounds := AABB()
	var first := true
	for m in yacht.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var local := yacht.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	if not first:
		var hull := BoxShape3D.new()
		hull.size = bounds.size * 0.08
		_collider(root, "AnchoredYacht", hull, Transform3D(yacht.global_transform.basis.orthonormalized(), yacht.global_transform * bounds.get_center()))
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
		var sail_hull := BoxShape3D.new()
		sail_hull.size = Vector3(2.4, 1.6, 9.0)
		_collider(root, "Sailboat%d" % b, sail_hull, Transform3D(bs, at + Vector3(0, 0.4, 0)))
		_rod_collider(root, "Sailboat%d" % b, at + Vector3(0, 0.9, 0), at + Vector3(0, 12.0, 0), 0.1)


# --- Palms ---------------------------------------------------------------------------------------
# Coconut palms in groves along the land side of the beach and round the water in the dunes,
# instanced from a few shapes (_palm_mesh): a slender ringed trunk that leans and curves back up
# (palm_trunk.gdshader), a crown of arching fronds, each two leaflet cards hung in a V from its midrib
# (palm_fronds.gdshader, atlas drawn by _palm_frond_texture), and coconuts. They lean toward open
# water. Each palm crossfades to a coarse stand-in round PALM_NEAR (tree_lod.gdshaderinc), and every
# trunk has a collider. The root is "Palms", not "Vegetation": Level.gd bakes trimesh colliders under
# that.

## Trunk height and base lean (radians), the share of the lean the trunk curves back out of by the
## top, the frond count and length, coconuts, and dead fronds hanging under the crown.
const PALM_SHAPES := [
	{"h": 11.0, "lean": 0.32, "curve": 0.75, "fronds": 26, "len": 5.4, "nuts": 7, "dead": 2},
	{"h": 13.5, "lean": 0.16, "curve": 0.8, "fronds": 28, "len": 5.8, "nuts": 8, "dead": 1},
	{"h": 8.5, "lean": 0.52, "curve": 0.62, "fronds": 22, "len": 4.9, "nuts": 5, "dead": 2},
	{"h": 15.5, "lean": 0.08, "curve": 0.9, "fronds": 26, "len": 5.6, "nuts": 4, "dead": 0},
]
const PALM_BEACH := 95
const PALM_SHORE := 170
const PALM_DRY := 0.45          # lowest ground a palm stands on (the water is at 0)
const PALM_BANK := 0.8          # by the water, the foot stays a few metres up the bank
const PALM_CLEAR_BEACH := 5.0   # trunk to track edge on the beach
const PALM_CLEAR_DUNES := 9.0   # and in the dunes, where carts fly over the crests
const PALM_GATE_CLEAR := 16.0
## Detailed palms crossfade to the stand-in over PALM_NEAR +- PALM_FADE/2 (tree_lod.gdshaderinc).
const PALM_NEAR := 160.0
const PALM_FADE := 50.0
const PALM_FADE_JITTER := 15.0
const PALM_CELL := 120.0
const PALM_FAR_CELL := 320.0
const FROND_ROWS := 4           # atlas rows: three green fronds and a dead one
## Trunk bases stay out of these (x0, z0, x1, z1): the hut row, and the grandstand with room for
## the crowns of palms leaning over it from behind.
const PALM_KEEP_OUT := [Rect2(-28.0, 19.0, 9.0, 60.0), Rect2(-33.0, 140.0, 25.0, 60.0)]

var _frond_tex: Texture2D


## A float RGB + alpha canvas for drawing the frond atlas (members, so drawing edits in place).
class LeafCanvas:
	var w := 0
	var rgb := PackedFloat32Array()
	var alpha := PackedFloat32Array()

	func _init(size: int, bg: Color) -> void:
		w = size
		rgb.resize(size * size * 3)
		alpha.resize(size * size)
		for i in range(size * size):
			rgb[i * 3] = bg.r
			rgb[i * 3 + 1] = bg.g
			rgb[i * 3 + 2] = bg.b

	func _put(i: int, a: float, col: Color) -> void:
		var k: float = a if alpha[i] > 0.0 else 1.0
		rgb[i * 3] = lerpf(rgb[i * 3], col.r, k)
		rgb[i * 3 + 1] = lerpf(rgb[i * 3 + 1], col.g, k)
		rgb[i * 3 + 2] = lerpf(rgb[i * 3 + 2], col.b, k)
		alpha[i] = maxf(alpha[i], a)

	## An antialiased dot.
	func dot(c: Vector2, r: float, col: Color) -> void:
		var x0: int = maxi(0, int(c.x - r - 1.0))
		var x1: int = mini(w - 1, int(c.x + r + 1.0))
		var y0: int = maxi(0, int(c.y - r - 1.0))
		var y1: int = mini(w - 1, int(c.y + r + 1.0))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var a: float = clampf(r + 0.5 - Vector2(x + 0.5, y + 0.5).distance_to(c), 0.0, 1.0)
				if a > 0.0:
					_put(y * w + x, a, col)

	## A stroke of dots from `a` to `b`, `r` tapering to `r2`.
	func line(a: Vector2, b: Vector2, r: float, r2: float, col: Color) -> void:
		var n: int = maxi(1, int(a.distance_to(b) / 0.7))
		for k in range(n + 1):
			var t: float = float(k) / float(n)
			dot(a.lerp(b, t), lerpf(r, r2, t), col)

	## A leaflet from `base` along `dir`: pointed, widest a third of the way out, lighter along its
	## midrib, and turning `tip` toward its point (a dry or sun-scorched end).
	func leaflet(base: Vector2, dir: Vector2, length: float, width: float, col: Color, rib: Color, tip: Color) -> void:
		var d: Vector2 = dir.normalized()
		var perp := Vector2(-d.y, d.x)
		var ends: Array = [base, base + d * length, base + perp * width, base - perp * width, base + d * length * 0.4 + perp * width, base + d * length * 0.4 - perp * width]
		var lo := Vector2(1e9, 1e9)
		var hi := Vector2(-1e9, -1e9)
		for e in ends:
			lo = Vector2(minf(lo.x, e.x), minf(lo.y, e.y))
			hi = Vector2(maxf(hi.x, e.x), maxf(hi.y, e.y))
		for y in range(maxi(0, int(lo.y) - 1), mini(w - 1, int(hi.y) + 2)):
			for x in range(maxi(0, int(lo.x) - 1), mini(w - 1, int(hi.x) + 2)):
				var q := Vector2(x + 0.5, y + 0.5) - base
				var along: float = q.dot(d) / length
				if along < 0.0 or along > 1.0:
					continue
				var across: float = q.dot(perp)
				var half: float = width * pow(sin(PI * clampf(pow(along, 0.75), 0.0, 1.0)), 0.7)
				var a: float = clampf(half - absf(across) + 0.5, 0.0, 1.0)
				if a <= 0.0:
					continue
				var c: Color = col.lerp(col.lightened(0.15), along * 0.6)
				c = c.lerp(tip, smoothstep(0.7, 1.0, along))
				var r: float = clampf(1.2 - absf(across) / maxf(width * 0.12, 0.6), 0.0, 1.0)
				c = c.lerp(rib, r * 0.5)
				_put(y * w + x, a, c)


## Mipmapped RGBA8 image of the canvas whose every mip keeps level 0's coverage at alpha
## `cutoff` (each level's alpha scaled up until as many texels pass the test), so fronds do not
## thin out to nothing with distance.
func _coverage_mipmaps(cv: LeafCanvas, cutoff: float) -> Image:
	var size: int = cv.w
	var rgb: PackedFloat32Array = cv.rgb
	var alpha: PackedFloat32Array = cv.alpha
	var target := 0.0
	for a in alpha:
		if a >= cutoff:
			target += 1.0
	target /= float(alpha.size())
	var data := PackedByteArray()
	var scale := 1.0
	while true:
		var n: int = size * size
		var level := PackedByteArray()
		level.resize(n * 4)
		for i in range(n):
			level[i * 4] = int(clampf(rgb[i * 3], 0.0, 1.0) * 255.0 + 0.5)
			level[i * 4 + 1] = int(clampf(rgb[i * 3 + 1], 0.0, 1.0) * 255.0 + 0.5)
			level[i * 4 + 2] = int(clampf(rgb[i * 3 + 2], 0.0, 1.0) * 255.0 + 0.5)
			level[i * 4 + 3] = int(clampf(alpha[i] * scale, 0.0, 1.0) * 255.0 + 0.5)
		data.append_array(level)
		if size == 1:
			break
		var half: int = size / 2
		var rgb2 := PackedFloat32Array()
		rgb2.resize(half * half * 3)
		var alpha2 := PackedFloat32Array()
		alpha2.resize(half * half)
		for y in range(half):
			for x in range(half):
				var sa := 0.0
				var sr := 0.0
				var sg := 0.0
				var sb := 0.0
				for dy in range(2):
					for dx in range(2):
						var i2: int = (y * 2 + dy) * size + x * 2 + dx
						var wgt: float = alpha[i2] + 0.001
						sa += alpha[i2]
						sr += rgb[i2 * 3] * wgt
						sg += rgb[i2 * 3 + 1] * wgt
						sb += rgb[i2 * 3 + 2] * wgt
				var j: int = y * half + x
				var wsum: float = sa + 0.004
				alpha2[j] = sa * 0.25
				rgb2[j * 3] = sr / wsum
				rgb2[j * 3 + 1] = sg / wsum
				rgb2[j * 3 + 2] = sb / wsum
		size = half
		rgb = rgb2
		alpha = alpha2
		var lo := 1.0
		var hi := 16.0
		for it in range(14):
			var mid: float = (lo + hi) * 0.5
			var covered := 0
			var need: float = cutoff / mid
			for a2 in alpha:
				if a2 >= need:
					covered += 1
			if float(covered) / float(alpha.size()) < target:
				lo = mid
			else:
				hi = mid
		scale = hi
	return Image.create_from_data(cv.w, cv.w, true, Image.FORMAT_RGBA8, data)


## The frond atlas: FROND_ROWS rows, each one side of a frond laid flat with its base at the left
## and its tip at the right, the midrib along the row's top edge and the leaflets sweeping down and
## out toward the tip, longest a third of the way along. Rows 0-2 are green, row 3 a dead frond.
func _palm_frond_texture() -> Texture2D:
	if _frond_tex:
		return _frond_tex
	const W := 1024
	const ROW := 256
	var cv := LeafCanvas.new(W, Color(0.30, 0.44, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3141
	var greens := [[Color(0.23, 0.41, 0.08), Color(0.37, 0.53, 0.12)], [Color(0.31, 0.45, 0.09), Color(0.46, 0.55, 0.14)],
			[Color(0.18, 0.35, 0.07), Color(0.29, 0.47, 0.10)]]
	for row in range(FROND_ROWS):
		var dead := row == FROND_ROWS - 1
		var y0: float = float(row * ROW) + 5.0
		var n := 76
		for k in range(n):
			# Dead fronds have lost leaflets; a few go missing from green ones too.
			if rng.randf() < (0.2 if dead else 0.04):
				continue
			var u: float = lerpf(0.14, 0.975, float(k) / float(n - 1)) + rng.randf_range(-0.002, 0.002)
			var s: float = (u - 0.14) / 0.835
			var prof: float = (0.42 + 0.58 * smoothstep(0.0, 0.32, s)) * (1.0 - 0.72 * smoothstep(0.45, 1.0, s))
			var ang: float = deg_to_rad(lerpf(60.0, 34.0, s) + rng.randf_range(-3.0, 3.0) + (14.0 if dead else 0.0))
			var dir := Vector2(cos(ang), sin(ang))
			var base := Vector2(u * W, y0)
			# Fits the row, and ends before the tip.
			var length: float = minf((ROW - 16.0) * prof / dir.y, (W - 6.0 - base.x) / dir.x) * rng.randf_range(0.93, 1.0)
			if length < 12.0:
				continue
			var col: Color
			var tip: Color
			if dead:
				col = Color(0.50, 0.38, 0.22).lerp(Color(0.64, 0.52, 0.32), rng.randf())
				tip = col.darkened(0.2)
			else:
				var pair: Array = greens[row]
				col = (pair[0] as Color).lerp(pair[1], rng.randf())
				# Sun-scorched tips on some.
				tip = col.lerp(Color(0.62, 0.55, 0.26), 0.6) if rng.randf() < 0.3 else col.lightened(0.08)
			cv.leaflet(base, dir, length, 4.6 + rng.randf() * 0.8, col, col.lightened(0.3), tip)
		var rib := Color(0.55, 0.43, 0.27) if dead else Color(0.68, 0.66, 0.36)
		cv.line(Vector2(0.0, y0 - 1.0), Vector2(W - 6.0, y0 - 1.0), 3.4, 1.2, rib)
	var img := _coverage_mipmaps(cv, 0.5)
	_frond_tex = _tg.call("_save_resource", ImageTexture.create_from_image(img), "palm_fronds")
	return _frond_tex


func _palm_materials(lod_mode: int) -> Array:
	var trunk := ShaderMaterial.new()
	trunk.shader = load("res://palm_trunk.gdshader")
	var fronds := ShaderMaterial.new()
	fronds.shader = load("res://palm_fronds.gdshader")
	fronds.set_shader_parameter("frond_tex", _palm_frond_texture())
	for m in [trunk, fronds]:
		m.set_shader_parameter("lod_mode", lod_mode)
		m.set_shader_parameter("lod_fade_begin", PALM_NEAR - PALM_FADE * 0.5)
		m.set_shader_parameter("lod_fade_end", PALM_NEAR + PALM_FADE * 0.5)
		m.set_shader_parameter("lod_jitter", PALM_FADE_JITTER)
	var nuts := StandardMaterial3D.new()
	nuts.vertex_color_use_as_albedo = true
	nuts.vertex_color_is_srgb = true
	nuts.roughness = 0.55
	return [trunk, fronds, nuts]


## One vertex of a palm surface.
func _pv(st: SurfaceTool, c: Array) -> void:
	st.set_normal(c[1])
	st.set_uv(c[2])
	st.set_uv2(c[3])
	st.set_color(c[4])
	st.add_vertex(c[0])


## A quad of four [position, normal, uv, uv2, colour] corners, wound so its front faces the normals.
func _pquad(st: SurfaceTool, c: Array) -> void:
	var n: Vector3 = (c[0][1] as Vector3) + c[1][1] + c[2][1] + c[3][1]
	var order := [0, 1, 2, 0, 2, 3]
	if ((c[2][0] as Vector3) - c[0][0]).cross((c[1][0] as Vector3) - c[0][0]).dot(n) < 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		_pv(st, c[i])


## A tube along `pts` with `radii`, round it UV.x 0..1 and along it UV.y in metres from the first
## point, COLOR rgb `tint` and a `boot` per point.
func _palm_tube(st: SurfaceTool, pts: Array, radii: Array, boot: Array, sides: int, tint: Color) -> void:
	var lens: Array = [0.0]
	for k in range(1, pts.size()):
		lens.append(float(lens[k - 1]) + (pts[k] as Vector3).distance_to(pts[k - 1]))
	var rings: Array = []
	var side := Vector3.FORWARD
	for k in range(pts.size()):
		var tan: Vector3 = ((pts[mini(k + 1, pts.size() - 1)] as Vector3) - pts[maxi(k - 1, 0)]).normalized()
		# Carried along the trunk, so the tube doesn't twist where it bends.
		side = (side - tan * side.dot(tan)).normalized()
		var up := tan.cross(side)
		var ring: Array = []
		for j in range(sides + 1):
			var a: float = TAU * float(j) / float(sides)
			var n: Vector3 = side * cos(a) + up * sin(a)
			ring.append([(pts[k] as Vector3) + n * float(radii[k]), n, Vector2(float(j) / float(sides), lens[k]), Vector2.ZERO, Color(tint.r, tint.g, tint.b, boot[k])])
		rings.append(ring)
	for k in range(pts.size() - 1):
		for j in range(sides):
			_pquad(st, [rings[k][j], rings[k][j + 1], rings[k + 1][j + 1], rings[k + 1][j]])


## A frond: the two leaflet cards hung from the midrib in a V, and in the detailed palm a stalk
## where it leaves the crown. `az` is its direction round the trunk, `elev` its angle at the root
## (up positive), `bend` how far it has arched down by the tip, `keel` how far the leaflets hang below
## the midrib's plane and `twist` how far it rolls toward the tip.
func _palm_frond(st: SurfaceTool, root: Vector3, az: float, elev: float, bend: float, length: float, width: float,
		keel: float, twist: float, segs: int, row: int, tint: Color, phase: float, stalk: bool) -> void:
	var horiz := Vector3(cos(az), 0.0, sin(az))
	var s0 := Vector3(-horiz.z, 0.0, horiz.x)
	var pts: Array = [root]
	var p := root
	for k in range(segs):
		var t: float = (float(k) + 0.5) / float(segs)
		var e: float = elev - bend * pow(t, 1.6)
		p += (horiz * cos(e) + Vector3.UP * sin(e)) * (length / float(segs))
		pts.append(p)
	var v0: float = (float(row) + 0.01) / float(FROND_ROWS)
	var v1: float = (float(row) + 0.99) / float(FROND_ROWS)
	var rows: Array = []   # per sample: [inner corner, outer corner] for each side
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		var tan: Vector3 = ((pts[mini(k + 1, segs)] as Vector3) - pts[maxi(k - 1, 0)]).normalized()
		var up: Vector3 = tan.cross(s0).normalized()
		if up.y < 0.0:
			up = -up
		var roll: float = twist * t
		var sd: Vector3 = s0 * cos(roll) + up * sin(roll)
		var ud: Vector3 = up * cos(roll) - s0 * sin(roll)
		var hang: float = keel * (0.6 + 0.4 * t)
		var shade: float = lerpf(0.55, 1.0, sqrt(t))
		var col := Color(tint.r, tint.g, tint.b, shade)
		var u: float = lerpf(0.004, 0.996, t)
		var pair: Array = []
		for side in [-1.0, 1.0]:
			var d: Vector3 = sd * side * cos(hang) - ud * sin(hang)
			var n: Vector3 = d.cross(tan).normalized()
			if n.dot(ud) < 0.0:
				n = -n
			n = (n + Vector3.UP * 0.25).normalized()
			pair.append([[pts[k], n, Vector2(u, v0), Vector2(t, phase), col], [(pts[k] as Vector3) + d * width, n, Vector2(u, v1), Vector2(t, phase), col]])
		rows.append(pair)
	for k in range(segs):
		for s in range(2):
			_pquad(st, [rows[k][s][0], rows[k][s][1], rows[k + 1][s][1], rows[k + 1][s][0]])
	if not stalk:
		return
	# The stalk out to the first leaflets, textured with the atlas's midrib.
	var rib_v: float = (float(row) + 4.0 / 256.0) / float(FROND_ROWS)
	var rings: Array = []
	for k in range(3):
		var t: float = 0.075 * float(k)
		var f: float = t * float(segs)
		var c: Vector3 = (pts[int(f)] as Vector3).lerp(pts[int(f) + 1], f - floorf(f))
		var tan: Vector3 = ((pts[int(f) + 1] as Vector3) - pts[int(f)]).normalized()
		var up: Vector3 = tan.cross(s0).normalized()
		var ring: Array = []
		for j in range(5):
			var a: float = TAU * float(j) / 4.0
			var n: Vector3 = s0 * cos(a) + up * sin(a)
			ring.append([c + n * lerpf(0.07, 0.04, t / 0.15) * length / 5.2, n, Vector2(lerpf(0.004, 0.996, t), rib_v), Vector2(t, phase), Color(tint.r, tint.g, tint.b, 0.7)])
		rings.append(ring)
	for k in range(2):
		for j in range(4):
			_pquad(st, [rings[k][j], rings[k][j + 1], rings[k + 1][j + 1], rings[k + 1][j]])


## A rough ball for a coconut.
func _palm_nut(st: SurfaceTool, c: Vector3, r: float, col: Color) -> void:
	var lat := 4
	var lon := 6
	var ring: Array = []
	for i in range(lat + 1):
		var row: Array = []
		var th: float = PI * float(i) / float(lat)
		for j in range(lon + 1):
			var ph: float = TAU * float(j) / float(lon)
			var n := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			row.append([c + n * Vector3(r, r * 1.1, r), n, Vector2.ZERO, Vector2.ZERO, col])
		ring.append(row)
	for i in range(lat):
		for j in range(lon):
			_pquad(st, [ring[i][j], ring[i][j + 1], ring[i + 1][j + 1], ring[i + 1][j]])


## Palm shape `variant` leaning toward +X, its foot at the origin. Surfaces: the trunk, the fronds,
## and in the detailed palm (`lod` 0) the coconuts. `lod` 1 is the stand-in: fewer rings and sides,
## two fronds in three, coarser cards, no stalks.
func _palm_mesh(variant: int, lod: int, mats: Array) -> ArrayMesh:
	var sh: Dictionary = PALM_SHAPES[variant]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5501 + variant * 37
	var h: float = sh["h"]
	var lean: float = sh["lean"]
	var tint := Color(rng.randf_range(0.94, 1.04), rng.randf_range(0.95, 1.02), rng.randf_range(0.92, 1.0))
	# Trunk: leaning at the foot and curving back up toward the crown, with a little wander.
	var segs: int = 14 if lod == 0 else 5
	var pts: Array = [Vector3(0.0, -0.8, 0.0)]
	var p := Vector3.ZERO
	var wander: float = rng.randf_range(0.0, TAU)
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		if k > 0:
			var th: float = lean * (1.0 - float(sh["curve"]) * pow(t, 1.3))
			p += Vector3(sin(th), cos(th), 0.0) * (h / float(segs))
		pts.append(p + Vector3(0.0, 0.0, sin(t * 4.0 + wander) * 0.12 * t))
	var radii: Array = [0.46]
	var boot: Array = [0.0]
	for k in range(segs + 1):
		var t: float = float(k) / float(segs)
		radii.append(0.27 * (1.0 - 0.3 * t) + 0.17 * (1.0 - smoothstep(0.0, 0.1, t)))
		boot.append(smoothstep(h - 0.9, h, t * h))
	# The boot: a bulge of old frond bases the crown sits in.
	var top: Vector3 = pts[pts.size() - 1]
	var tdir: Vector3 = (top - (pts[pts.size() - 2] as Vector3)).normalized()
	for b in [[0.35, 0.27], [0.7, 0.25], [0.95, 0.15]]:
		pts.append(top + tdir * float(b[0]))
		radii.append(b[1])
		boot.append(1.0)
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_palm_tube(st, pts, radii, boot, 9 if lod == 0 else 5, tint)
	var crown: Vector3 = top + tdir * 0.6
	# Fronds round the crown on the golden angle, youngest at the top pointing up, oldest drooping
	# below, the dead ones hanging down the trunk.
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = sh["fronds"]
	var dead: int = sh["dead"]
	for i in range(n):
		var age: float = float(i) / float(n - 1)
		var az: float = float(i) * 2.39996 + rng.randf_range(-0.2, 0.2)
		var is_dead: bool = i >= n - dead
		var spear: bool = i < 2
		# Every frond draws its numbers, so the stand-in's fronds match the detailed palm's.
		var flen: float = float(sh["len"]) * lerpf(0.78, 1.0, smoothstep(0.0, 0.35, age)) * rng.randf_range(0.92, 1.08)
		var elev: float = lerpf(1.05, -0.3, age) + rng.randf_range(-0.12, 0.12)
		var bend: float = lerpf(0.7, 1.5, age) + rng.randf_range(-0.15, 0.15)
		var twist: float = rng.randf_range(-0.35, 0.35)
		var phase: float = rng.randf()
		var row: int = rng.randi() % (FROND_ROWS - 1)
		var spear_elev: float = 1.35 + rng.randf_range(-0.1, 0.1)
		var dead_elev: float = -1.15 + rng.randf_range(-0.15, 0.15)
		if lod == 1 and (i % 3 == 2 or is_dead or spear):
			continue
		var keel: float = lerpf(0.6, 1.0, age)
		var width: float = flen * 0.19
		var ftint := tint * Color(1.0, 1.0, 1.0).lerp(Color(1.08, 1.02, 0.78), age * 0.6)
		if spear:
			flen *= 0.6
			elev = spear_elev
			bend = 0.2
			keel = 1.2
			width *= 0.45
		if is_dead:
			flen *= 0.85
			elev = dead_elev
			bend = 0.25
			keel = 1.1
			row = FROND_ROWS - 1
			ftint = Color(1.0, 1.0, 1.0)
		var root: Vector3 = crown + Vector3(cos(az), 0.0, sin(az)) * 0.12 - Vector3(0.0, 0.5 * age, 0.0)
		if lod == 1:
			width *= 1.15
		_palm_frond(st2, root, az, elev, bend, flen, width, keel, twist, 10 if lod == 0 else 3, row, ftint, phase, lod == 0)
	st.index()
	st.commit(mesh)
	mesh.surface_set_material(0, mats[0])
	st2.index()
	st2.commit(mesh)
	mesh.surface_set_material(1, mats[1])
	if lod == 0 and int(sh["nuts"]) > 0:
		var st3 := SurfaceTool.new()
		st3.begin(Mesh.PRIMITIVE_TRIANGLES)
		for b in range(2):
			var ba: float = rng.randf_range(0.0, TAU)
			var bc: Vector3 = crown + Vector3(cos(ba), 0.0, sin(ba)) * 0.3 - Vector3(0.0, 0.45, 0.0)
			for k in range(int(float(sh["nuts"]) * 0.5) + b):
				var nc: Vector3 = bc + Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.14, 0.08), rng.randf_range(-0.16, 0.16))
				var ripe: float = rng.randf()
				_palm_nut(st3, nc, rng.randf_range(0.12, 0.15), Color(0.36, 0.44, 0.14).lerp(Color(0.62, 0.44, 0.18), ripe * ripe))
		st3.index()
		st3.commit(mesh)
		mesh.surface_set_material(2, mats[2])
	return mesh


## Simplex noise for where the palms grow thick (no fractal: one even scale of groves).
var _grove_noise: FastNoiseLite


## Can a palm stand here: dry, not too steep, clear of the racing line, the gates, the beach
## structures and the other palms (trunk bases `gap` apart)?
func _palm_ok(x: float, z: float, gates: Array, taken: Array, gap: float) -> bool:
	var y := _ground(x, z)
	if y < PALM_DRY:
		return false
	var slope := maxf(absf(_ground(x + 1.5, z) - _ground(x - 1.5, z)), absf(_ground(x, z + 1.5) - _ground(x, z - 1.5))) / 3.0
	if slope > 0.45:
		return false
	var c := Vector2(x, z)
	var p := _curve.get_closest_point(Vector3(x, y, z))
	if Vector2(p.x, p.z).distance_to(c) - TRACK_HALF < (PALM_CLEAR_BEACH if x < -15.0 else PALM_CLEAR_DUNES):
		return false
	for g in gates:
		if c.distance_to(g) < PALM_GATE_CLEAR:
			return false
	for r in PALM_KEEP_OUT:
		if (r as Rect2).has_point(c):
			return false
	for f in _footprints:
		if c.distance_to(f[1]) < float(f[2]) + 2.5:
			return false
	for o in taken:
		if c.distance_to(o) < gap:
			return false
	return true


## Direction to the nearest water within 14m (ground below the surface), or zero.
func _water_dir(x: float, z: float) -> Vector2:
	for r in [5.0, 9.0, 14.0]:
		for i in range(12):
			var a: float = TAU * float(i) / 12.0
			var d := Vector2(cos(a), sin(a))
			if _ground(x + d.x * r, z + d.y * r) < -0.1:
				return d
	return Vector2.ZERO


func _build_palms(level: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Palms"
	level.add_child(root)
	_grove_noise = FastNoiseLite.new()
	_grove_noise.seed = 77
	_grove_noise.frequency = 0.02
	_grove_noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var gates: Array = []
	for g in [level.get_node("FinishLine")] + level.get_node("Checkpoints").get_children():
		gates.append(Vector2((g as Node3D).position.x, (g as Node3D).position.z))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7023
	var taken: Array = []
	var spots: Array = []   # [foot, lean direction, variant, scale]
	# The beach: groves along its land side, leaning out to sea, the strongest leaners nearest it.
	var tries := 0
	var beach := 0
	while beach < PALM_BEACH and tries < 40000:
		tries += 1
		var x: float = rng.randf_range(-34.0, 6.0)
		var z: float = rng.randf_range(-390.0, 390.0)
		if _grove_noise.get_noise_2d(x, z) < 0.0 and rng.randf() > 0.12:
			continue
		if not _palm_ok(x, z, gates, taken, 3.4):
			continue
		var pick: float = rng.randf() * (1.0 - clampf((x + 34.0) / 40.0, 0.0, 1.0) * 0.5)
		var v: int = 2 if pick > 0.62 else (0 if pick > 0.3 else (1 if rng.randf() < 0.6 else 3))
		taken.append(Vector2(x, z))
		spots.append([Vector3(x, _ground(x, z), z), Vector2(-1.0, 0.0).rotated(rng.randf_range(-0.6, 0.6)), v, rng.randf_range(0.85, 1.15)])
		beach += 1
	# Round the water in the dunes and along the island's far shore, leaning over it; thickest near
	# the track, where they are seen.
	tries = 0
	var shore := 0
	while shore < PALM_SHORE and tries < 120000:
		tries += 1
		var x2: float = rng.randf_range(-12.0, 470.0)
		var z2: float = rng.randf_range(-470.0, 470.0)
		var y2 := _ground(x2, z2)
		if y2 < PALM_BANK or y2 > 3.2:
			continue
		var p := _curve.get_closest_point(Vector3(x2, y2, z2))
		if rng.randf() > exp(-Vector2(p.x - x2, p.z - z2).length() / 220.0):
			continue
		var wet := _water_dir(x2, z2)
		if wet == Vector2.ZERO or not _palm_ok(x2, z2, gates, taken, 3.8):
			continue
		var v2: int = [0, 0, 1, 1, 2, 3][rng.randi() % 6]
		taken.append(Vector2(x2, z2))
		spots.append([Vector3(x2, y2, z2), wet.rotated(rng.randf_range(-0.45, 0.45)), v2, rng.randf_range(0.85, 1.15)])
		shore += 1
	# Meshes, then the palms in cells: the detailed ones near, the stand-ins far, and the trunks.
	var near_mats := _palm_materials(1)
	var far_mats := _palm_materials(2)
	var near_meshes: Array = []
	var far_meshes: Array = []
	for v3 in range(PALM_SHAPES.size()):
		near_meshes.append(_tg.call("_save_resource", _palm_mesh(v3, 0, near_mats), "palm_%d" % v3))
		far_meshes.append(_tg.call("_save_resource", _palm_mesh(v3, 1, far_mats), "palm_far_%d" % v3))
	var near := {}
	var far := {}
	var bodies := {}
	for s in spots:
		var foot: Vector3 = s[0]
		var d: Vector2 = s[1]
		var sc: float = s[3]
		var yaw: float = atan2(-d.y, d.x)
		var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), foot)
		var nk := Vector3i(floori(foot.x / PALM_CELL), floori(foot.z / PALM_CELL), s[2])
		var fk := Vector3i(floori(foot.x / PALM_FAR_CELL), floori(foot.z / PALM_FAR_CELL), s[2])
		if not near.has(nk):
			near[nk] = []
		near[nk].append(xf)
		if not far.has(fk):
			far[fk] = []
		far[fk].append(xf)
		# The trunk's foot, tipped with its lean: carts only reach the first few metres.
		var bk := Vector2i(nk.x, nk.y)
		if not bodies.has(bk):
			var body := StaticBody3D.new()
			body.name = "PalmTrunks_%d_%d" % [bk.x, bk.y]
			root.add_child(body)
			bodies[bk] = body
		var lean: float = PALM_SHAPES[s[2]]["lean"]
		var axis := (Vector3(sin(lean) * d.x, cos(lean), sin(lean) * d.y)).normalized()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.36 * sc
		cyl.height = 4.0 * sc
		var cs := CollisionShape3D.new()
		cs.shape = cyl
		cs.transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)), foot + axis * cyl.height * 0.5 - Vector3(0.0, 0.6, 0.0))
		bodies[bk].add_child(cs)
	# Ranges are measured to a cell's centre, so they're padded by half a cell's diagonal: a cell
	# only switches off once every palm in it has faded, and the shader does the visible swap. The
	# stand-ins cast no shadow (the shadow pass can't tell which of the two a palm is showing).
	for k in near.keys():
		var mmi := _multimesh(near_meshes[k.z], near[k], "Palms_%d_%d_%d" % [k.x, k.y, k.z])
		mmi.visibility_range_end = PALM_NEAR + PALM_FADE * 0.5 + PALM_FADE_JITTER + PALM_CELL * 0.72
		mmi.visibility_range_end_margin = 10.0
		root.add_child(mmi)
	for k in far.keys():
		var mmi2 := _multimesh(far_meshes[k.z], far[k], "PalmsFar_%d_%d_%d" % [k.x, k.y, k.z])
		mmi2.visibility_range_begin = maxf(0.0, PALM_NEAR - PALM_FADE * 0.5 - PALM_FADE_JITTER - PALM_FAR_CELL * 0.72)
		mmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi2)
	print("Palms: %d on the beach, %d by the water" % [beach, shore])


func _transform_buffer(transforms: Array) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(transforms.size() * 12)
	for i in range(transforms.size()):
		var t: Transform3D = transforms[i]
		var b: Basis = t.basis
		var o: int = i * 12
		buf[o] = b.x.x
		buf[o + 1] = b.y.x
		buf[o + 2] = b.z.x
		buf[o + 3] = t.origin.x
		buf[o + 4] = b.x.y
		buf[o + 5] = b.y.y
		buf[o + 6] = b.z.y
		buf[o + 7] = t.origin.y
		buf[o + 8] = b.x.z
		buf[o + 9] = b.y.z
		buf[o + 10] = b.z.z
		buf[o + 11] = t.origin.z
	return buf


func _multimesh(mesh: Mesh, transforms: Array, node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	# The dummy renderer drops set_instance_transform(); write the buffer itself (CLAUDE.md).
	mm.buffer = _transform_buffer(transforms)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	return mmi


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
