extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var stages = [
		"res://levels/LakesideLevel.tscn",
		"res://levels/PinecrestRidgeLevel.tscn",
		"res://levels/HarborPierLevel.tscn",
		"res://levels/BloombayDunesLevel.tscn",
		"res://levels/FrostpeakCreekLevel.tscn",
		"res://levels/GlacierHighwayLevel.tscn",
		"res://levels/NorthlightCavernsLevel.tscn",
		"res://levels/FrostfallGorgeLevel.tscn",
		"res://levels/MountainLevel.tscn",
		"res://levels/CanyonLevel.tscn",
		"res://levels/CanyonChasmLevel.tscn",
		"res://levels/DesertWadiLevel.tscn",
		"res://levels/MaraCrossingLevel.tscn",
		"res://levels/NyotaStadiumLevel.tscn",
		"res://levels/MsituFallsLevel.tscn"
	]
	
	for path in stages:
		print("========================================")
		print("STAGE: ", path.get_file().get_basename())
		var lvl: Node = load(path).instantiate()
		add_child(lvl)
		await get_tree().process_frame
		
		var finish := lvl.get_node_or_null("FinishLine") as Node3D
		if finish:
			var fwd := -finish.global_basis.z
			var from = finish.global_position + Vector3(0.0, 10.0, 0.0) - fwd * 25.0
			var to = finish.global_position + fwd * 45.0
			print("  FinishLine pos: %s, fwd: %s" % [finish.global_position, fwd])
			print("  Default Inspect: from: %s, to: %s" % [from, to])
		
		var track := lvl.get_node_or_null("TrackPath") as Path3D
		if track and track.curve:
			var curve := track.curve
			var length := curve.get_baked_length()
			print("  Track length: %.1f m, point count: %d" % [length, curve.point_count])
			for pct in [0.0, 0.2, 0.4, 0.6, 0.8]:
				var dist: float = length * float(pct)
				var p: Vector3 = curve.sample_baked(dist)
				var p_next: Vector3 = curve.sample_baked(minf(dist + 20.0, length))
				var dir: Vector3 = (p_next - p).normalized()
				print("  Track %.0f%%: pos=%s, dir=%s" % [float(pct) * 100.0, p, dir])
		
		# Look for interesting children/landmarks
		var landmarks := []
		for child in lvl.get_children():
			var cname: String = child.name
			if not (cname.begins_with("Halfway") or cname.begins_with("Track") or cname == "FinishLine"):
				landmarks.append(cname)
		print("  Key nodes: ", landmarks)
		
		remove_child(lvl)
		lvl.queue_free()
		await get_tree().process_frame
		
	get_tree().quit()
