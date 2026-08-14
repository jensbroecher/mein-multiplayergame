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
	tg.terrain_resolution = 560
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
		sand_mat.set_shader_parameter("smoothness", 0.96)  # roughness (shader maps this to ROUGHNESS)
		sand_mat.set_shader_parameter("use_world_uv", true)
		if rock_tex:
			sand_mat.set_shader_parameter("use_slope_cliff_rock", true)
			sand_mat.set_shader_parameter("cliff_texture", rock_tex)
			sand_mat.set_shader_parameter("cliff_albedo", Color(0.88, 0.78, 0.66, 1.0))
			sand_mat.set_shader_parameter("cliff_uv_scale", 0.065)
			sand_mat.set_shader_parameter("cliff_slope_threshold", 0.45)
			sand_mat.set_shader_parameter("cliff_blend_sharpness", 0.12)
			if rock_norm:
				sand_mat.set_shader_parameter("use_cliff_normal", true)
				sand_mat.set_shader_parameter("cliff_normal_texture", rock_norm)
				sand_mat.set_shader_parameter("cliff_normal_scale", 1.2)
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
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	curve.up_vector_enabled = true

	var points: Array = [
		# === START / FINISH: long straight after climb (northbound-ish) ===
		{"pos": Vector3(292, 5.6, -168), "in": Vector3(0, 0, -22), "out": Vector3(0, 0, 22)},
		{"pos": Vector3(298, 6.0, -125), "in": Vector3(0, 0, -20), "out": Vector3(0, 0, 20)},
		{"pos": Vector3(285, 6.0, -85), "in": Vector3(14, 0, -14), "out": Vector3(-14, 0, 14)},
		# Double-apex switchbacks
		{"pos": Vector3(245, 5.5, -50), "in": Vector3(16, 0, -14), "out": Vector3(-16, 0, 14)},
		{"pos": Vector3(268, 5.0, -12), "in": Vector3(-12, 0, -16), "out": Vector3(12, 0, 16)},
		{"pos": Vector3(235, 5.0, 38), "in": Vector3(18, 0, -12), "out": Vector3(-18, 0, 12)},
		{"pos": Vector3(185, 5.0, 78), "in": Vector3(22, 0, -6), "out": Vector3(-22, 0, 6)},
		# === LONG NASCAR BANKED CURVE (24° High Banked Sweep) ===
		# For this right-hand turn, negative tilt banks the road: left/outer wall is high (+Y), right/inner apron stays low.
		{"pos": Vector3(115, 5.0, 115), "in": Vector3(26, 0, -10), "out": Vector3(-26, 0, 10), "tilt": -0.12},
		{"pos": Vector3(45, 5.5, 145), "in": Vector3(20, 0, -12), "out": Vector3(-20, 0, 12), "tilt": -0.28},
		{"pos": Vector3(0, 6.0, 125), "in": Vector3(14, 0, 14), "out": Vector3(-14, 0, -14), "tilt": -0.42},
		{"pos": Vector3(15, 5.5, 75), "in": Vector3(-8, 0, 20), "out": Vector3(8, 0, -20), "tilt": -0.28},
		{"pos": Vector3(72, 5.0, 42), "in": Vector3(-26, 0, 12), "out": Vector3(26, 0, -12), "tilt": -0.12},
		{"pos": Vector3(112, 5.0, 8), "in": Vector3(-16, 0, 20), "out": Vector3(16, 0, -20)},
		# Hairpin 1
		{"pos": Vector3(128, 5.0, -48), "in": Vector3(8, 0, 18), "out": Vector3(-8, 0, -18)},
		{"pos": Vector3(88, 4.5, -82), "in": Vector3(20, 0, 6), "out": Vector3(-20, 0, -6)},
		{"pos": Vector3(58, 4.5, -118), "in": Vector3(10, 0, 18), "out": Vector3(-10, 0, -18)},
		# Hairpin 2 into valley
		{"pos": Vector3(98, 4.2, -152), "in": Vector3(-18, 0, 10), "out": Vector3(18, 0, -10)},
		{"pos": Vector3(128, 3.0, -172), "in": Vector3(-12, 0.4, 12), "out": Vector3(12, -0.4, -12)},
		# Drop into river ford / valley lake — completely submerged from bank to bank
		{"pos": Vector3(155, 1.10, -190), "in": Vector3(-14, 0.5, 8), "out": Vector3(14, -0.5, -8)},
		{"pos": Vector3(185, 0.70, -206), "in": Vector3(-16, 0.1, 6), "out": Vector3(16, -0.1, -6)},
		{"pos": Vector3(222, 0.70, -220), "in": Vector3(-14, -0.1, 5), "out": Vector3(14, 0.1, -5)},
		{"pos": Vector3(255, 1.10, -232), "in": Vector3(-14, -0.6, 6), "out": Vector3(14, 0.6, -6)},
		# Climb out back toward start straight
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
	var boost_offsets := {
		"BoostPad_PreRiver": fmod(river_entry_off - 22.0 + track_len, track_len),
		"BoostPad_PostClimb": fmod(climb_off + 14.0 + track_len, track_len),
		"BoostPad_Start": fmod(start_off + 40.0 + track_len, track_len),
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


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node == null:
		return
	node.owner = scene_root
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
