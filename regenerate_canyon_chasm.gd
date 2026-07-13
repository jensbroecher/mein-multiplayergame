# regenerate_canyon_chasm.gd
# Generates CanyonChasmLevel.tscn with a custom track curve, boost pads, and gaps.
# Run with: Godot --headless res://regenerate_canyon_chasm.tscn
extends Node

func _ready():
	print("=== Canyon Chasm Level Generation (Scene Ready) ===")

	var template_path = "res://levels/CanyonLevel.tscn"
	var target_path = "res://levels/CanyonChasmLevel.tscn"

	# 1. Duplicate standard CanyonLevel to use as target base
	var dir = DirAccess.open("res://")
	if dir.file_exists(target_path):
		dir.remove(target_path)
	var err = DirAccess.copy_absolute(template_path, target_path)
	if err != OK:
		push_error("Could not copy template to CanyonChasmLevel.tscn: " + str(err))
		get_tree().quit(1)
		return

	# 2. Load and instantiate target scene
	var packed = load(target_path)
	if not packed:
		push_error("Could not load target scene")
		get_tree().quit(1)
		return
	
	var level = packed.instantiate()
	if not level:
		push_error("Could not instantiate target scene")
		get_tree().quit(1)
		return
	
	print("Instantiated target CanyonChasmLevel.tscn")
	add_child(level)
	
	# 3. Locate TerrainGenerator and track path
	var tg = level.get_node_or_null("TerrainGenerator")
	var track_path = level.get_node_or_null("TrackPath")
	if track_path:
		track_path.transform = Transform3D.IDENTITY
	
	if not tg or not track_path:
		push_error("TerrainGenerator or TrackPath node not found in template")
		get_tree().quit(1)
		return
		
	# 4. Set prefix on generator so it uses its own mesh files
	tg.level_prefix = "canyon_chasm"
	tg.track_layout_type = 2 # CANYON
	tg.terrain_resolution = 550 # slightly larger to cover our track comfortably
	
	# 5. Define our custom figure-8 track curve with bridges, steep hill, and gaps
	var curve = Curve3D.new()
	curve.bake_interval = 0.25
	
	# Curve points: {pos, in, out}
	var points = [
		{"pos": Vector3(0, 5, 200), "in": Vector3(0, 0, 30), "out": Vector3(0, 0, -30)},
		{"pos": Vector3(0, 5, 0), "in": Vector3(0, 0, 30), "out": Vector3(0, 0, -30)},
		{"pos": Vector3(0, 5, -100), "in": Vector3(0, 0, 30), "out": Vector3(0, 0, -30)}, # Lower crossing
		{"pos": Vector3(0, 10, -200), "in": Vector3(0, 0, 30), "out": Vector3(0, 0, -30)},
		{"pos": Vector3(50, 15, -280), "in": Vector3(-30, 0, 20), "out": Vector3(30, 0, -20)},
		{"pos": Vector3(150, 20, -300), "in": Vector3(-30, 0, 0), "out": Vector3(30, 0, 0)},
		{"pos": Vector3(250, 15, -200), "in": Vector3(-20, 0, -30), "out": Vector3(20, 0, 30)},
		{"pos": Vector3(200, 10, 0), "in": Vector3(0, 0, -30), "out": Vector3(-18, 0, 28)}, # approach, lead toward ramp entry
		{"pos": Vector3(150, 10, 100), "in": Vector3(18, 0, -28), "out": Vector3(0, 7, -32)}, # Start of hill - smooth lead-in curving onto the ramp
		{"pos": Vector3(150, 30, 0), "in": Vector3(0, -7, 32), "out": Vector3(0, 8, -23)}, # Steep hill
		{"pos": Vector3(150, 50, -50), "in": Vector3(0, -8, 23), "out": Vector3(0, 5, -20)}, # Takeoff 1 (Hill Jump)
		{"pos": Vector3(150, 30, -120), "in": Vector3(0, 5, 20), "out": Vector3(0, -5, -20)}, # Landing 1
		{"pos": Vector3(100, 20, -180), "in": Vector3(30, 0, 20), "out": Vector3(-30, 0, -20)},
		{"pos": Vector3(25, 45, -100), "in": Vector3(20, -2, 0), "out": Vector3(-20, 2, 0)}, # Takeoff 2 (Crossing)
		{"pos": Vector3(-25, 38, -100), "in": Vector3(20, 2, 0), "out": Vector3(-20, -2, 0)}, # Landing 2
		{"pos": Vector3(-100, 20, -100), "in": Vector3(30, 0, -20), "out": Vector3(-30, 0, 20)},
		{"pos": Vector3(-200, 15, 0), "in": Vector3(0, 0, -30), "out": Vector3(0, 0, 30)},
		{"pos": Vector3(-200, 10, 150), "in": Vector3(0, 0, -30), "out": Vector3(0, 0, 30)},
		{"pos": Vector3(-120, 5, 240), "in": Vector3(-30, 0, -20), "out": Vector3(30, 0, 20)},
		{"pos": Vector3(-50, 5, 240), "in": Vector3(-20, 0, 10), "out": Vector3(20, 0, -10)}
	]
	
	for p in points:
		curve.add_point(p["pos"], p["in"], p["out"])
		
	track_path.curve = curve
	print("Configured custom track curve (points: ", curve.point_count, ")")
	
	# 6. Recreate and place Boost Pads dynamically
	var old_boost_pads = level.get_node_or_null("BoostPads")
	if old_boost_pads:
		old_boost_pads.free()
		
	var boost_container = Node3D.new()
	boost_container.name = "BoostPads"
	level.add_child(boost_container)
	boost_container.owner = level
	
	# Offsets of boost pads relative to takeoff zones
	var hill_takeoff_offset = curve.get_closest_offset(Vector3(150, 50, -50))
	var crossing_takeoff_offset = curve.get_closest_offset(Vector3(25, 45, -100))
	
	# Put boost pads at specific offsets
	# - 25 meters before Hill Takeoff to give substantial speed
	# - 20 meters before Crossing Takeoff to clear the chasm
	var boost_offsets = {
		"BoostPad_HillJump": hill_takeoff_offset - 25.0,
		"BoostPad_CrossingJump": crossing_takeoff_offset - 20.0,
		"BoostPad_Start": 40.0
	}
	
	var tp_xform = track_path.transform
	var track_len = curve.get_baked_length()
	
	for bp_name in boost_offsets.keys():
		var offset = fmod(boost_offsets[bp_name] + track_len, track_len)
		var local_pos = curve.sample_baked(offset)
		var global_pos = tp_xform * local_pos
		
		var next_offset = fmod(offset + 1.0, track_len)
		var tangent_local = (curve.sample_baked(next_offset) - local_pos).normalized()
		var tangent_global = ((tp_xform * (local_pos + tangent_local)) - (tp_xform * local_pos)).normalized()
		
		var bp_scene = load("res://BoostPad.tscn")
		var bp = bp_scene.instantiate()
		bp.name = bp_name
		boost_container.add_child(bp)
		bp.owner = level
		
		# Set transform
		bp.position = global_pos
		if tangent_global.length() > 0.01:
			bp.basis = Basis.looking_at(tangent_global, Vector3.UP)
			
		print("Placed boost pad: ", bp_name, " at offset ", offset)

	# 7. Rebuild checkpoints along the curve
	level._rebuild_checkpoints()
	level._align_checkpoints_to_track()

	# 8. Trigger terrain and road mesh generation
	print("Generating world meshes from new curve...")
	tg.generate_world()
	
	# 9. Position FinishLine and spawns along the new track
	print("Aligning FinishLine and spawn points...")
	var fl = level.get_node_or_null("FinishLine")
	if fl:
		fl.position = Vector3(0, 5, 200)
	level._align_start_and_spawns_to_track()
	
	# 10. Fix ownership of generated nodes so everything gets saved in the .tscn
	for child in tg.get_children():
		_set_owner_recursive(child, level)
	var sp = level.get_node_or_null("SpawnPoints")
	if sp:
		_set_owner_recursive(sp, level)
	
	# Remove GrassContainer to prevent bloat (just like regenerate_both.gd does)
	var gc = tg.get_node_or_null("GrassContainer")
	if gc:
		tg.remove_child(gc)
		gc.free()
		print("Stripped GrassContainer to prevent file size bloat.")
		
	remove_child(level)

	# 11. Save target scene
	var new_packed = PackedScene.new()
	var err_pack = new_packed.pack(level)
	if err_pack == OK:
		var err_save = ResourceSaver.save(new_packed, target_path)
		if err_save == OK:
			print("Saved CanyonChasmLevel.tscn successfully.")
		else:
			push_error("ResourceSaver.save failed: " + str(err_save))
			get_tree().quit(1)
			return
	else:
		push_error("PackedScene.pack failed: " + str(err_pack))
		get_tree().quit(1)
		return
		
	get_tree().quit(0)

func _set_owner_recursive(node: Node, scene_root: Node):
	node.owner = scene_root
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
