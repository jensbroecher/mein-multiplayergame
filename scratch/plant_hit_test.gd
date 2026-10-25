extends Node

# Checks DressingColliders.gd on a level: that a plant or object drawn as MultiMesh instances is solid
# (a shape query at its foot finds its collider), and that a small plant wobbles when a cart passes
# through it (a stand-in in the "player_carts" group is moved through it; the wobble reads carts'
# positions, so it needs no physics). Logs the lean; windowed, it also saves frames. Spectator race:
#   Godot --path . res://scratch/plant_hit_test.tscn -- <out_dir> [level=res://levels/CanyonLevel.tscn]
#       [match=PlantsNear_barrel] [index=0] [speed=14]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var level_path := "res://levels/CanyonLevel.tscn"
	var filter := "PlantsNear_barrel"
	var index := 0
	var speed := 14.0
	for a in args.slice(1):
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("match="): filter = a.substr(6)
		elif a.begins_with("index="): index = int(a.substr(6))
		elif a.begins_with("speed="): speed = float(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	for i in 5:
		await get_tree().physics_frame
	var dc = level.get_node("DressingColliders")
	var entry: Array = []
	var k := 0
	for e in dc._wobble:
		if filter in String((e[0][0] as Node).name):
			if k == index:
				entry = e
				break
			k += 1
	if entry.is_empty():
		print("no plant matching ", filter)
		get_tree().quit()
		return
	var foot: Vector3 = entry[3]
	print("PLANT %s at %s, radius %.2f, drawn by %d MultiMeshes" % [(entry[0][0] as Node).name, foot, float(entry[4]), (entry[0] as Array).size()])
	# Solid?
	var q := PhysicsShapeQueryParameters3D.new()
	var probe := SphereShape3D.new()
	probe.radius = 0.15
	q.shape = probe
	q.transform = Transform3D(Basis(), foot + Vector3.UP * 0.6)
	var hits: Array = (level as Node3D).get_world_3d().direct_space_state.intersect_shape(q, 8)
	var names := PackedStringArray()
	for h in hits:
		names.append(String((h["collider"] as Node).name))
	print("SOLID at its foot: ", names)
	# A stand-in cart driving through it.
	for c in get_tree().get_nodes_in_group("player_carts"):
		c.remove_from_group("player_carts")
	var ghost := Node3D.new()
	add_child(ghost)
	ghost.add_to_group("player_carts")
	var dir := Vector3(1, 0, 0.25).normalized()
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = foot + Vector3(-4, 2.5, 6)
	cam.look_at(foot + Vector3(0, 0.8, 0))
	cam.make_current()
	var t := -0.6
	var shot := 0
	var windowed := DisplayServer.get_name() != "headless"
	while t < 2.5:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		ghost.global_position = foot + dir * (t * speed) + Vector3.UP * 0.5
		if fmod(t + 10.0, 0.1) < dt:
			print("t=%5.2f lean %5.1f deg" % [t, rad_to_deg(float(entry[6]))])
		if windowed and shot < 6 and t > 0.0 and fmod(t, 0.12) < dt:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/hit_%d.png" % [out_dir, shot])
			shot += 1
	get_tree().quit()
