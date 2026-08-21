# regenerate_desert_wadi.gd
# Builds DesertWadiLevel.tscn: technical desert course with sharp hairpins,
# off-road dune cuts, and a wide valley river/lake ford.
#
# Run: open res://regenerate_desert_wadi.tscn and Play Current Scene.
# Does NOT re-import lakeside trees/ramps/props from Level.tscn — those are stripped.
extends Node

func _ready() -> void:
	print("=== Desert Wadi Level Generation ===")
	print("Building technical desert course with river valley. Please wait...")

	var template_path := "res://levels/Level.tscn"
	var target_path := "res://levels/DesertWadiLevel.tscn"

	var dir := DirAccess.open("res://")
	if dir == null:
		push_error("Could not open res://")
		get_tree().quit(1)
		return
	if dir.file_exists(target_path.trim_prefix("res://")):
		dir.remove(target_path.trim_prefix("res://"))
	var err := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(template_path),
		ProjectSettings.globalize_path(target_path)
	)
	if err != OK:
		print("copy_absolute failed (", err, "), will pack from template instance")
	else:
		print("Copied template to DesertWadiLevel.tscn")

	var packed: PackedScene = load(target_path) as PackedScene
	if packed == null:
		packed = load(template_path) as PackedScene
	if packed == null:
		push_error("Could not load desert template")
		get_tree().quit(1)
		return

	var level = packed.instantiate()
	if level == null:
		push_error("Could not instantiate level")
		get_tree().quit(1)
		return

	level.name = "DesertWadiLevel"
	add_child(level)

	# Strip lakeside trees / ramps / props — keep only track infrastructure
	_strip_non_essential_props(level)

	var tg = level.get_node_or_null("TerrainGenerator")
	var track_path = level.get_node_or_null("TrackPath") as Path3D
	if track_path:
		track_path.transform = Transform3D.IDENTITY

	if tg == null or track_path == null:
		push_error("TerrainGenerator or TrackPath missing")
		get_tree().quit(1)
		return

	tg.level_prefix = "desert_wadi"
	tg.track_layout_type = 0 # DEFAULT desert flats
	tg.no_water = true # local valley lake only
	tg.no_grass = true
	tg.terrain_resolution = 400
	tg.hill_height = 42.0
	tg.generate_bridge_supports = false
	# Mild recess only — deep trenches under curbs made cars sink beside the road
	tg.terrain_recession_collision = 0.14
	tg.terrain_recession_visual = 0.22
	tg.road_y_offset = 0.06
	tg.curb_y_offset = 0.06
	tg.sand_width = 17.0
	tg.road_width = 14.0
	tg.terrain_grass_count = 0

	# Desert look (sand dunes palette) — lakeside template ships green grass
	var sand_tex: Texture2D = load("res://materials/sand.png") as Texture2D
	var sand_norm: Texture2D = load("res://materials/sand_normal.png") as Texture2D
	var asphalt_tex: Texture2D = load("res://materials/asphalt.png") as Texture2D
	var rock_tex: Texture2D = load("res://materials/dark_canyon_rock.png") as Texture2D
	var rock_norm: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D
	var stoch: Shader = load("res://terrain_stochastic.gdshader") as Shader
	if stoch and sand_tex:
		var sand_mat := ShaderMaterial.new()
		sand_mat.shader = stoch
		sand_mat.set_shader_parameter("albedo_texture", sand_tex)
		# Let the sand texture drive the look (near-white tint = real dune color).
		sand_mat.set_shader_parameter("albedo", Color(1.0, 0.97, 0.90, 1.0))
		sand_mat.set_shader_parameter("uv_scale", 16.0)
		sand_mat.set_shader_parameter("smoothness", 0.94)  # roughness (shader maps this to ROUGHNESS)
		sand_mat.set_shader_parameter("use_world_uv", true)
		if sand_norm:
			sand_mat.set_shader_parameter("use_normal_map", true)
			sand_mat.set_shader_parameter("normal_texture", sand_norm)
			sand_mat.set_shader_parameter("normal_scale", 0.85)
		sand_mat.set_shader_parameter("enable_edge_fade", true)
		sand_mat.set_shader_parameter("edge_fade_start", 550.0)
		sand_mat.set_shader_parameter("edge_fade_end", 960.0)
		sand_mat.set_shader_parameter("edge_fade_color", Color(0.82, 0.76, 0.68, 1.0))
		tg.grass_material = sand_mat # field is the terrain visual material
	if stoch and asphalt_tex:
		var road_mat := ShaderMaterial.new()
		road_mat.shader = stoch
		road_mat.set_shader_parameter("albedo_texture", asphalt_tex)
		road_mat.set_shader_parameter("albedo", Color(0.65, 0.62, 0.58, 1.0))
		road_mat.set_shader_parameter("uv_scale", 18.0)
		tg.road_material = road_mat

	# Prefer clear/fine weather for a desert feel if the resource exists
	var weather = level.get_node_or_null("WeatherController")
	if weather:
		var fine = load("res://addons/GodotWeatherSystem/weather/fine.tres")
		if fine and "selected_weather" in weather:
			# selected_weather is often an enum index — try time of day for hot sun instead
			if "time_of_day_hours" in weather:
				weather.time_of_day_hours = 14.5

	# Technical closed loop. Start/finish sits on a LONG straight (not a hairpin).
	# Path order begins mid climb-out straight so the gate faces a calm approach.
	#
	# Layout (do NOT recross the original bank — that folded the road mesh):
	#   start → switchbacks → ORIGINAL outward bank → peel SOUTH-WEST into unused
	#   desert → NASCAR inward bowl (far west) → south return → mild kicker →
	#   rejoin original (112, 8) → ORIGINAL hairpins → ORIGINAL river ford.
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.up_vector_enabled = true

	var points: Array = [
		# === START / FINISH: long straight after climb (original) ===
		{"pos": Vector3(292, 5.6, -168), "in": Vector3(0, 0, -22), "out": Vector3(0, 0, 22)},
		{"pos": Vector3(298, 6.0, -125), "in": Vector3(0, 0, -20), "out": Vector3(0, 0, 20)},
		{"pos": Vector3(285, 6.0, -85), "in": Vector3(14, 0, -14), "out": Vector3(-14, 0, 14)},
		# Double-apex switchbacks (original)
		{"pos": Vector3(245, 5.5, -50), "in": Vector3(16, 0, -14), "out": Vector3(-16, 0, 14)},
		{"pos": Vector3(268, 5.0, -12), "in": Vector3(-12, 0, -16), "out": Vector3(12, 0, 16)},
		{"pos": Vector3(235, 5.0, 38), "in": Vector3(18, 0, -12), "out": Vector3(-18, 0, 12)},
		{"pos": Vector3(185, 5.0, 78), "in": Vector3(22, 0, -6), "out": Vector3(-22, 0, 6)},
		# === OUTWARD-BANKED SWEEP (right-hander, original) ===
		{"pos": Vector3(115, 5.0, 115), "in": Vector3(26, 0, -10), "out": Vector3(-26, 0, 10), "tilt": -0.12},
		{"pos": Vector3(45, 5.5, 145), "in": Vector3(20, 0, -12), "out": Vector3(-20, 0, 12), "tilt": -0.28},
		{"pos": Vector3(0, 6.0, 125), "in": Vector3(14, 0, 14), "out": Vector3(-14, 0, -14), "tilt": -0.42},
		{"pos": Vector3(15, 5.5, 75), "in": Vector3(-8, 0, 20), "out": Vector3(8, 0, -20), "tilt": -0.28},
		# Bank exit: original IN handle; OUT peels south then west (south of the bank)
		{"pos": Vector3(72, 5.0, 42), "in": Vector3(-26, 0, 12), "out": Vector3(-16, 0, -16), "tilt": -0.12},
		# Westbound SOUTH of the bank, NORTH of the later return (z ≈ 0..12)
		{"pos": Vector3(45, 5.1, 12), "in": Vector3(16, 0, 16), "out": Vector3(-18, 0, -8)},
		{"pos": Vector3(-40, 5.2, 0), "in": Vector3(28, 0, 6), "out": Vector3(-28, 0, -4)},
		{"pos": Vector3(-120, 5.5, 25), "in": Vector3(24, 0, -12), "out": Vector3(-22, 0, 16)},
		{"pos": Vector3(-155, 5.9, 70), "in": Vector3(10, 0, -24), "out": Vector3(-8, 0, 24)},
		# === NASCAR 180° INWARD left-hander (enter north on east side, exit south on west) ===
		{"pos": Vector3(-165, 6.4, 125), "in": Vector3(4, 0, -26), "out": Vector3(-4, 0, 26), "tilt": 0.12},
		{"pos": Vector3(-200, 7.0, 175), "in": Vector3(16, 0, -22), "out": Vector3(-16, 0, 22), "tilt": 0.28},
		{"pos": Vector3(-255, 7.4, 175), "in": Vector3(26, 0, 0), "out": Vector3(-26, 0, 0), "tilt": 0.42},
		{"pos": Vector3(-285, 7.0, 125), "in": Vector3(16, 0, 22), "out": Vector3(-16, 0, -22), "tilt": 0.28},
		{"pos": Vector3(-270, 6.4, 70), "in": Vector3(-4, 0, 26), "out": Vector3(4, 0, -26), "tilt": 0.12},
		# South on the WEST of the westbound, then east at z ≈ -50 (never recrosses)
		{"pos": Vector3(-255, 5.8, 10), "in": Vector3(-6, 0, 24), "out": Vector3(6, 0, -24)},
		{"pos": Vector3(-210, 5.5, -48), "in": Vector3(-22, 0, 12), "out": Vector3(22, 0, -8)},
		{"pos": Vector3(-90, 5.5, -58), "in": Vector3(-28, 0, 0), "out": Vector3(28, 0, 0)},
		{"pos": Vector3(10, 5.5, -50), "in": Vector3(-26, 0, -4), "out": Vector3(24, 0, 6)},
		{"pos": Vector3(55, 5.8, -28), "in": Vector3(-20, 0, -10), "out": Vector3(18, 0, 12)},
		# Mild continuous kicker (no mesh gap)
		{"pos": Vector3(82, 8.8, -10), "in": Vector3(-14, -0.7, -10), "out": Vector3(14, 0.7, 8)},
		{"pos": Vector3(102, 5.4, 3), "in": Vector3(-12, 0.9, -8), "out": Vector3(12, -0.9, 6)},
		# Rejoin original (112, 8) — out handle kept so hairpins still drop into the river
		{"pos": Vector3(112, 5.0, 8), "in": Vector3(-12, 0, -6), "out": Vector3(16, 0, -20)},
		# === ORIGINAL hairpins into the valley (ford still hits the water) ===
		{"pos": Vector3(128, 5.0, -48), "in": Vector3(8, 0, 18), "out": Vector3(-8, 0, -18)},
		{"pos": Vector3(88, 4.5, -82), "in": Vector3(20, 0, 6), "out": Vector3(-20, 0, -6)},
		{"pos": Vector3(58, 4.5, -118), "in": Vector3(10, 0, 18), "out": Vector3(-10, 0, -18)},
		{"pos": Vector3(98, 4.2, -152), "in": Vector3(-18, 0, 10), "out": Vector3(18, 0, -10)},
		{"pos": Vector3(128, 3.0, -172), "in": Vector3(-12, 0.4, 12), "out": Vector3(12, -0.4, -12)},
		# Drop into river ford / valley lake (original — road y 0.70, water y 1.70)
		{"pos": Vector3(155, 1.10, -190), "in": Vector3(-14, 0.5, 8), "out": Vector3(14, -0.5, -8)},
		{"pos": Vector3(185, 0.70, -206), "in": Vector3(-16, 0.1, 6), "out": Vector3(16, -0.1, -6)},
		{"pos": Vector3(222, 0.70, -220), "in": Vector3(-14, -0.1, 5), "out": Vector3(14, 0.1, -5)},
		{"pos": Vector3(255, 1.10, -232), "in": Vector3(-14, -0.6, 6), "out": Vector3(14, 0.6, -6)},
		# Climb out back toward start straight (original)
		{"pos": Vector3(278, 3.6, -218), "in": Vector3(-8, -0.8, -14), "out": Vector3(8, 0.8, 14)},
		{"pos": Vector3(288, 5.2, -192), "in": Vector3(-3, -0.3, -16), "out": Vector3(3, 0.3, 16)},
		{"pos": Vector3(292, 5.6, -168), "in": Vector3(0, -0.1, -22), "out": Vector3(0, 0.1, 22)},
	]

	for idx in range(points.size()):
		var p = points[idx]
		curve.add_point(p["pos"], p["in"], p["out"])
		if p.has("tilt"):
			curve.set_point_tilt(idx, float(p["tilt"]))

	track_path.curve = curve
	_diagnose_wadi_curve(curve)

	var sd = level.get_node_or_null("SandDunes")
	if sd:
		sd.free()

	# Clear any leftover boost pads then place only wadi pads
	var old_boost = level.get_node_or_null("BoostPads")
	if old_boost:
		old_boost.free()
	var to_free: Array = []
	for child in level.get_children():
		if child is Node and str(child.name).begins_with("BoostPad"):
			to_free.append(child)
	for n in to_free:
		level.remove_child(n)
		n.free()

	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level.add_child(boost_container)
	boost_container.owner = level

	var track_len: float = curve.get_baked_length()
	var river_entry_off: float = curve.get_closest_offset(Vector3(155, 1.10, -190))
	var climb_off: float = curve.get_closest_offset(Vector3(278, 3.6, -218))
	var start_off: float = curve.get_closest_offset(Vector3(292, 5.6, -168))
	var jump_off: float = curve.get_closest_offset(Vector3(55, 5.8, -28))
	var boost_offsets := {
		"BoostPad_PreRiver": fmod(river_entry_off - 22.0 + track_len, track_len),
		"BoostPad_PostClimb": fmod(climb_off + 14.0 + track_len, track_len),
		"BoostPad_Start": fmod(start_off + 40.0 + track_len, track_len),
		"BoostPad_PreJump": fmod(jump_off - 8.0 + track_len, track_len),
	}

	var bp_scene: PackedScene = load("res://BoostPad.tscn")
	for bp_name in boost_offsets.keys():
		var offset: float = float(boost_offsets[bp_name])
		var local_pos: Vector3 = curve.sample_baked(offset)
		var next_offset: float = fmod(offset + 1.5, track_len)
		var tangent: Vector3 = (curve.sample_baked(next_offset) - local_pos)
		if tangent.length_squared() < 1e-6:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()
		var up_vec: Vector3 = curve.sample_baked_up_vector(offset, true)
		if up_vec.length_squared() < 1e-6:
			up_vec = Vector3.UP
		else:
			up_vec = up_vec.normalized()
		var bp = bp_scene.instantiate()
		bp.name = bp_name
		boost_container.add_child(bp)
		bp.owner = level
		bp.position = local_pos + up_vec * 0.05
		bp.basis = Basis.looking_at(tangent, up_vec)
		print("Placed ", bp_name, " at offset ", offset)

	if level.has_method("_rebuild_checkpoints"):
		level._rebuild_checkpoints()
	if level.has_method("_align_checkpoints_to_track"):
		level._align_checkpoints_to_track()

	print("Generating desert wadi world meshes...")
	tg.generate_world()

	# Gate on the long straight (explicit world pos before align snaps to curve)
	var fl = level.get_node_or_null("FinishLine")
	if fl:
		fl.position = Vector3(292, 5.6, -168)
	if level.has_method("_align_start_and_spawns_to_track"):
		level._align_start_and_spawns_to_track()

	for child in tg.get_children():
		_set_owner_recursive(child, level)
	var sp = level.get_node_or_null("SpawnPoints")
	if sp:
		_set_owner_recursive(sp, level)
	_set_owner_recursive(boost_container, level)
	_set_owner_recursive(track_path, level)

	var gc = tg.get_node_or_null("GrassContainer")
	if gc:
		tg.remove_child(gc)
		gc.free()

	# Final pass: never ship template props
	_strip_non_essential_props(level)

	_add_movable_csg_props(level)
	await get_tree().process_frame

	remove_child(level)
	var new_packed := PackedScene.new()
	var err_pack := new_packed.pack(level)
	if err_pack != OK:
		push_error("PackedScene.pack failed: " + str(err_pack))
		get_tree().quit(1)
		return
	var err_save := ResourceSaver.save(new_packed, target_path)
	if err_save != OK:
		push_error("ResourceSaver.save failed: " + str(err_save))
		get_tree().quit(1)
		return
	print("Saved DesertWadiLevel.tscn successfully.")
	get_tree().quit(0)


## Sanity-check the racing line: river ford under water, no near-overlaps.
func _diagnose_wadi_curve(curve: Curve3D) -> void:
	var length: float = curve.get_baked_length()
	print("Wadi baked length: ", length)
	var step := 2.0
	var n: int = maxi(int(length / step), 2)
	var samples: PackedVector3Array = PackedVector3Array()
	samples.resize(n)
	for i in range(n):
		samples[i] = curve.sample_baked(float(i) * step)
	var close_pairs := 0
	var min_sep := 9999.0
	var min_a := Vector3.ZERO
	var min_b := Vector3.ZERO
	var skip: int = 14 # ~28 m along the line
	for i in range(n):
		var a: Vector3 = samples[i]
		for j in range(i + skip, n):
			if i < skip and j > n - skip:
				continue # loop seam
			var b: Vector3 = samples[j]
			var d: float = Vector2(a.x - b.x, a.z - b.z).length()
			if d < 22.0:
				close_pairs += 1
				if d < min_sep:
					min_sep = d
					min_a = a
					min_b = b
	print("Wadi near-crossings (xz<22m, >28m along): ", close_pairs, " min_sep=", min_sep, " a=", min_a, " b=", min_b)
	var wet_n := 0
	var wet_min_y := 999.0
	var wet_max_y := -999.0
	for i in range(n):
		var p: Vector3 = samples[i]
		var d_lake: float = Vector2((p.x - 195.0) / 130.0, (p.z + 208.0) / 105.0).length()
		var in_ford: bool = p.z < -165.0 and p.x > 140.0 and p.x < 280.0
		if d_lake < 1.0 or in_ford:
			wet_n += 1
			wet_min_y = minf(wet_min_y, p.y)
			wet_max_y = maxf(wet_max_y, p.y)
	print("Wadi valley samples: ", wet_n, " y ", wet_min_y, "..", wet_max_y, " (water y=1.70)")
	var fords: Array[Vector3] = [
		Vector3(155, 1.10, -190),
		Vector3(185, 0.70, -206),
		Vector3(222, 0.70, -220),
		Vector3(255, 1.10, -232),
	]
	for q in fords:
		var cp: Vector3 = curve.get_closest_point(q)
		print("  ford ", q, " -> closest ", cp, " dist=", cp.distance_to(q), " underwater=", cp.y < 1.70)


## Drop lakeside trees, ramps, and other decorative instances from Level.tscn.
func _strip_non_essential_props(level: Node) -> void:
	var keep := {
		"TerrainGenerator": true,
		"TrackPath": true,
		"FinishLine": true,
		"Checkpoints": true,
		"AlternativePaths": true,
		"WeatherController": true,
		"PlayerSpawner": true,
		"ProjectileSpawner": true,
		"SpawnPoints": true,
		"BoostPads": true,
		"RaceUI": true,
		"WorldEnvironment": true,
		"DirectionalLight3D": true,
		"Sun": true,
		"AudioListener3D": true,
		"Minimap": true,
		"PauseMenu": true,
		"Players": true,
		"RockRidges": true,
		"JumpRamps": true,
	}
	var to_free: Array = []
	for child in level.get_children():
		var n := str(child.name)
		if keep.has(n):
			continue
		if child is MultiplayerSpawner:
			continue
		if n.begins_with("Halfway") or n.begins_with("Checkpoint"):
			continue
		if n.contains("Weather") or n.contains("Environment") or n.contains("Light"):
			continue
		if n.begins_with("BoostPad"):
			continue
		# Everything else from the lakeside template (trees, ramps, FBX props, etc.)
		to_free.append(child)
	for node in to_free:
		print("Stripping prop: ", node.name)
		level.remove_child(node)
		node.free()
	# Remove decorative meshes stuck under Checkpoints (gates only)
	var cps = level.get_node_or_null("Checkpoints")
	if cps:
		var cp_free: Array = []
		for c in cps.get_children():
			var cn := str(c.name)
			if cn.begins_with("Halfway") or cn.begins_with("Checkpoint") or cn == "FinishLine":
				continue
			cp_free.append(c)
		for c in cp_free:
			print("Stripping checkpoint prop: ", c.name)
			cps.remove_child(c)
			c.free()
	# Empty alternative shortcut paths so lakeside alts don't remain
	var alts = level.get_node_or_null("AlternativePaths")
	if alts:
		for c in alts.get_children():
			alts.remove_child(c)
			c.free()
	# Ensure Players container exists for MultiplayerSpawner
	if level.get_node_or_null("Players") == null:
		var players := Node3D.new()
		players.name = "Players"
		level.add_child(players)
		players.owner = level


func _sandstone_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var sand: Texture2D = load("res://materials/sand.png") as Texture2D
	var sand_n: Texture2D = load("res://materials/sand_normal.png") as Texture2D
	var rock: Texture2D = load("res://materials/dark_canyon_rock.png") as Texture2D
	if sand:
		mat.albedo_texture = sand
	else:
		mat.albedo_color = Color(0.86, 0.74, 0.58)
	if sand_n:
		mat.normal_enabled = true
		mat.normal_texture = sand_n
		mat.normal_scale = 1.1
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
	mat.roughness = 0.92
	return mat


func _add_csg_box(parent: Node, size: Vector3, pos: Vector3, rot_deg: Vector3, mat: Material) -> MeshInstance3D:
	# MeshInstance instead of CSGBox3D — PackedScene.pack() signal-11s on CSG in 4.7.
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = mat
	parent.add_child(mi)
	var body := StaticBody3D.new()
	mi.add_child(body)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	return mi


func _add_csg_sphere(parent: Node, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 5
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	var body := StaticBody3D.new()
	mi.add_child(body)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	body.add_child(col)
	return mi


func _add_rock_ridge(parent: Node, ridge_name: String, origin: Vector3, yaw_deg: float, length: float, height: float, width: float) -> Node3D:
	var comb := Node3D.new()
	comb.name = ridge_name
	comb.position = origin
	comb.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(comb)
	var mat := _sandstone_mat()
	# Main sandstone fin
	_add_csg_box(comb, Vector3(width, height, length), Vector3(0, height * 0.40, 0), Vector3(5, 0, 7), mat)
	# Offset slab
	_add_csg_box(comb, Vector3(width * 0.72, height * 0.78, length * 0.52), Vector3(width * 0.42, height * 0.30, -length * 0.10), Vector3(-8, 16, -6), mat)
	# Low shelf
	_add_csg_box(comb, Vector3(width * 1.15, height * 0.28, length * 0.7), Vector3(-width * 0.15, height * 0.12, length * 0.08), Vector3(2, -8, 4), mat)
	# Boulders
	_add_csg_sphere(comb, width * 0.48, Vector3(-width * 0.22, height * 0.16, length * 0.32), mat)
	_add_csg_sphere(comb, width * 0.32, Vector3(width * 0.38, height * 0.14, -length * 0.28), mat)
	return comb


func _add_jump_ramp(parent: Node, ramp_name: String, origin: Vector3, yaw_deg: float, length: float, height: float, width: float) -> Node3D:
	var comb := Node3D.new()
	comb.name = ramp_name
	comb.position = origin
	comb.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(comb)
	var mat := _sandstone_mat()
	# Wedge: long box pitched as a kicker
	_add_csg_box(comb, Vector3(width, height, length), Vector3(0, height * 0.35, 0), Vector3(-18, 0, 0), mat)
	_add_csg_box(comb, Vector3(width * 1.05, height * 0.45, length * 0.55), Vector3(0, height * 0.18, length * 0.12), Vector3(-8, 0, 0), mat)
	_add_csg_sphere(comb, width * 0.28, Vector3(-width * 0.42, height * 0.12, -length * 0.2), mat)
	_add_csg_sphere(comb, width * 0.24, Vector3(width * 0.4, height * 0.1, length * 0.18), mat)
	return comb


func _add_movable_csg_props(level: Node) -> void:
	var old_r = level.get_node_or_null("RockRidges")
	if old_r:
		old_r.free()
	var old_j = level.get_node_or_null("JumpRamps")
	if old_j:
		old_j.free()

	var ridges := Node3D.new()
	ridges.name = "RockRidges"
	level.add_child(ridges)
	# Off-track sandstone fins — select and move in the editor.
	_add_rock_ridge(ridges, "RockRidge_WestBowl", Vector3(-320, 4.0, 120), 18.0, 38.0, 14.0, 7.5)
	_add_rock_ridge(ridges, "RockRidge_WestOuter", Vector3(-300, 5.0, 210), -32.0, 32.0, 12.0, 6.5)
	_add_rock_ridge(ridges, "RockRidge_NorthMesa", Vector3(-40, 5.5, -80), 55.0, 26.0, 10.0, 6.0)
	_add_rock_ridge(ridges, "RockRidge_Switchback", Vector3(210, 4.5, 10), 110.0, 22.0, 9.0, 5.5)
	_add_rock_ridge(ridges, "RockRidge_BankOutside", Vector3(20, 4.0, 190), 8.0, 30.0, 11.0, 6.2)
	_add_rock_ridge(ridges, "RockRidge_RiverNorth", Vector3(130, 2.5, -250), -20.0, 24.0, 8.5, 5.8)
	_add_rock_ridge(ridges, "RockRidge_RiverSouth", Vector3(270, 2.0, -270), 40.0, 20.0, 7.5, 5.2)
	_add_rock_ridge(ridges, "RockRidge_JumpFlank", Vector3(40, 4.0, -70), 72.0, 18.0, 8.0, 5.0)

	var ramps := Node3D.new()
	ramps.name = "JumpRamps"
	level.add_child(ramps)
	# Wedge local +Z is up-ramp; yaw = atan2(dir.x, dir.z) so +Z follows the racing line.
	_add_jump_ramp(ramps, "JumpRamp_Takeoff", Vector3(82, 6.0, -10), 58.0, 14.0, 4.8, 12.0)
	_add_jump_ramp(ramps, "JumpRamp_Landing", Vector3(102, 4.5, 3), 56.0, 12.0, 3.6, 12.5)

	_set_owner_recursive(ridges, level)
	_set_owner_recursive(ramps, level)
	print("Added movable RockRidges + JumpRamps (select parent Node3D in the scene tree and translate).")


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node == null:
		return
	node.owner = scene_root
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
