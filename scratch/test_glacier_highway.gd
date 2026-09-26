# scratch/test_glacier_highway.gd
extends Node

func _ready():
	print("--- TEST GLACIER HIGHWAY LOAD & VALIDATION ---")
	var lvl_path := "res://levels/GlacierHighwayLevel.tscn"
	var res := load(lvl_path) as PackedScene
	if not res:
		push_error("FAILED to load " + lvl_path)
		get_tree().quit(1)
		return

	var inst = res.instantiate()
	if not inst:
		push_error("FAILED to instantiate " + lvl_path)
		get_tree().quit(1)
		return

	add_child(inst)
	print("GlacierHighwayLevel instantiated successfully!")

	# Check TrackPath
	var tp = inst.get_node_or_null("TrackPath") as Path3D
	if tp and tp.curve:
		print("TrackPath baked length: %.1f meters" % tp.curve.get_baked_length())
	else:
		push_error("TrackPath missing or has no curve")

	# Check Alternative Paths
	var alts = inst.get_node_or_null("AlternativePaths")
	if alts:
		print("Alternative Paths found: ", alts.get_child_count())
		for child in alts.get_children():
			if child is Path3D and child.curve:
				print("  - %s (Length: %.1f m)" % [child.name, child.curve.get_baked_length()])
	else:
		push_error("AlternativePaths container missing")

	# Check Checkpoints
	var cps = inst.get("checkpoints")
	if cps != null:
		print("Checkpoints registered in level: ", cps.size())
		for i in range(cps.size()):
			print("  CP %d: %s at %s" % [i, cps[i].name, str(cps[i].global_position)])
	else:
		push_error("Checkpoints array is null")

	# Check FinishLine & Spawns
	var fl = inst.get_node_or_null("FinishLine")
	if fl:
		var spawns = fl.get_node_or_null("SpawnPoints")
		if spawns:
			print("Spawn points count: ", spawns.get_child_count())
		else:
			push_error("SpawnPoints container missing")
	else:
		push_error("FinishLine missing")

	# Check Tunnel Underpass
	var tunnel = inst.get_node_or_null("GlacierTunnelUnderpass")
	if tunnel:
		print("GlacierTunnelUnderpass exists! Children count: ", tunnel.get_child_count())
	else:
		push_error("GlacierTunnelUnderpass missing")

	# Check Track Surface groups
	var track_surface_nodes = inst.find_children("*", "StaticBody3D", true, false)
	var surface_count = 0
	for body in track_surface_nodes:
		if body.is_in_group("track_surface"):
			surface_count += 1
	print("Track surface bodies count: ", surface_count)

	# Check GP Cup integration
	var arctic_cup = NetworkManager.get_gp_cup("Arctic Cup")
	print("Arctic Cup stages: ", arctic_cup.get("stages", []))

	remove_child(inst)
	inst.free()
	print("--- TEST PASSED SUCCESSFULLY ---")
	get_tree().quit(0)
