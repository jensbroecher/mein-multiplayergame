# regenerate_desert_wadi.gd
# Builds DesertWadiLevel.tscn: technical desert course with sharp hairpins,
# off-road cuttable dunes, and a shallow river ford.
#
# Run: open res://regenerate_desert_wadi.tscn and Play Current Scene.
extends Node

func _ready() -> void:
	print("=== Desert Wadi Level Generation ===")
	print("Building technical desert course with river ford. Please wait...")

	var template_path := "res://levels/Level.tscn"
	var target_path := "res://levels/DesertWadiLevel.tscn"

	var dir := DirAccess.open("res://")
	if dir == null:
		push_error("Could not open res://")
		get_tree().quit(1)
		return
	if dir.file_exists(target_path.trim_prefix("res://")):
		dir.remove(target_path.trim_prefix("res://"))
	# DirAccess.copy needs relative or absolute depending on version
	var err := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(template_path),
		ProjectSettings.globalize_path(target_path)
	)
	if err != OK:
		# Fallback: load template and re-save path later via pack
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
	tg.no_water = true # use local river plane only
	tg.no_grass = true
	tg.terrain_resolution = 560
	tg.hill_height = 42.0

	# Technical closed loop: tight hairpins + river ford + elevation changes.
	# Off-road: cutting the switchbacks means leaving sand onto Unified_World terrain.
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	# {pos, in, out} — sharp corners use short handles
	var points: Array = [
		# Start / finish straight
		{"pos": Vector3(0, 5, 170), "in": Vector3(0, 0, 25), "out": Vector3(0, 0, -25)},
		{"pos": Vector3(20, 5, 90), "in": Vector3(-5, 0, 25), "out": Vector3(8, 0, -28)},
		# First tight S
		{"pos": Vector3(70, 5, 40), "in": Vector3(-25, 0, 15), "out": Vector3(28, 0, -12)},
		{"pos": Vector3(110, 5, 10), "in": Vector3(-20, 0, 20), "out": Vector3(18, 0, -22)},
		# Hairpin 1 (left)
		{"pos": Vector3(130, 5, -50), "in": Vector3(5, 0, 22), "out": Vector3(-8, 0, -18)},
		{"pos": Vector3(85, 4.5, -85), "in": Vector3(25, 0, 5), "out": Vector3(-22, 0, -5)},
		{"pos": Vector3(55, 4.5, -120), "in": Vector3(12, 0, 18), "out": Vector3(-10, 0, -20)},
		# Hairpin 2 (right) — inviting dune cut across the inside
		{"pos": Vector3(95, 4, -155), "in": Vector3(-22, 0, 8), "out": Vector3(20, 0, -10)},
		{"pos": Vector3(130, 3, -175), "in": Vector3(-15, 0, 12), "out": Vector3(12, -0.5, -12)},
		# Drop into river ford
		{"pos": Vector3(155, 1.5, -195), "in": Vector3(-12, 1, 10), "out": Vector3(14, -0.4, -8)},
		{"pos": Vector3(185, 1.05, -210), "in": Vector3(-14, 0, 6), "out": Vector3(16, 0, -6)}, # mid-ford
		{"pos": Vector3(220, 1.05, -222), "in": Vector3(-14, 0, 5), "out": Vector3(14, 0.3, -5)},
		{"pos": Vector3(250, 2.0, -230), "in": Vector3(-12, -0.5, 4), "out": Vector3(15, 1.0, 8)},
		# Climb out + long left hairpin uphill
		{"pos": Vector3(280, 5, -200), "in": Vector3(-10, -2, -18), "out": Vector3(8, 1, 20)},
		{"pos": Vector3(300, 6, -140), "in": Vector3(-5, -1, -22), "out": Vector3(0, 0, 24)},
		{"pos": Vector3(270, 6, -90), "in": Vector3(20, 0, -15), "out": Vector3(-22, 0, 12)},
		# Double apex switchbacks (sharp)
		{"pos": Vector3(230, 5.5, -50), "in": Vector3(18, 0, -12), "out": Vector3(-16, 0, 14)},
		{"pos": Vector3(260, 5, -10), "in": Vector3(-16, 0, -14), "out": Vector3(14, 0, 16)},
		{"pos": Vector3(230, 5, 40), "in": Vector3(18, 0, -12), "out": Vector3(-20, 0, 12)},
		{"pos": Vector3(180, 4.5, 80), "in": Vector3(22, 0, -8), "out": Vector3(-24, 0, 6)},
		# Final chicane back to start
		{"pos": Vector3(110, 4.5, 120), "in": Vector3(25, 0, -10), "out": Vector3(-28, 0, 8)},
		{"pos": Vector3(40, 5, 150), "in": Vector3(22, 0, -12), "out": Vector3(-20, 0, 10)},
		{"pos": Vector3(0, 5, 170), "in": Vector3(12, 0, -18), "out": Vector3(0, 0, 25)},
	]

	for p in points:
		curve.add_point(p["pos"], p["in"], p["out"])

	track_path.curve = curve

	# Remove sand dunes if present (template may not have them)
	var sd = level.get_node_or_null("SandDunes")
	if sd:
		sd.free()

	# Boost pads: before river entry, after climb, mid-tech section
	var old_boost = level.get_node_or_null("BoostPads")
	if old_boost:
		old_boost.free()
	# Also free any root-level BoostPad instances from template
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
	var river_entry_off: float = curve.get_closest_offset(Vector3(155, 1.5, -195))
	var climb_off: float = curve.get_closest_offset(Vector3(280, 5, -200))
	var boost_offsets := {
		"BoostPad_PreRiver": fmod(river_entry_off - 22.0 + track_len, track_len),
		"BoostPad_PostClimb": fmod(climb_off + 18.0 + track_len, track_len),
		"BoostPad_Start": 35.0,
	}

	var bp_scene: PackedScene = load("res://BoostPad.tscn")
	for bp_name in boost_offsets.keys():
		var offset: float = float(boost_offsets[bp_name])
		var local_pos: Vector3 = curve.sample_baked(offset)
		var next_offset: float = fmod(offset + 1.5, track_len)
		var tangent: Vector3 = (curve.sample_baked(next_offset) - local_pos)
		tangent.y = 0.0
		if tangent.length_squared() < 1e-6:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()
		var bp = bp_scene.instantiate()
		bp.name = bp_name
		boost_container.add_child(bp)
		bp.owner = level
		bp.position = local_pos + Vector3.UP * 0.05
		bp.basis = Basis.looking_at(tangent, Vector3.UP)
		print("Placed ", bp_name, " at offset ", offset)

	# Checkpoints + finish/spawns
	if level.has_method("_rebuild_checkpoints"):
		level._rebuild_checkpoints()
	if level.has_method("_align_checkpoints_to_track"):
		level._align_checkpoints_to_track()

	print("Generating desert wadi world meshes...")
	tg.generate_world()

	var fl = level.get_node_or_null("FinishLine")
	if fl:
		fl.position = Vector3(0, 5, 170)
	if level.has_method("_align_start_and_spawns_to_track"):
		level._align_start_and_spawns_to_track()

	# Ownership for save
	for child in tg.get_children():
		_set_owner_recursive(child, level)
	var sp = level.get_node_or_null("SpawnPoints")
	if sp:
		_set_owner_recursive(sp, level)
	_set_owner_recursive(boost_container, level)
	_set_owner_recursive(track_path, level)

	# Strip grass if any slipped through
	var gc = tg.get_node_or_null("GrassContainer")
	if gc:
		tg.remove_child(gc)
		gc.free()

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


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node == null:
		return
	node.owner = scene_root
	if node.scene_file_path != "":
		return
	for child in node.get_children():
		_set_owner_recursive(child, scene_root)
