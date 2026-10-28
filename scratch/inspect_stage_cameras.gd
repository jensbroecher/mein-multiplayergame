extends SceneTree

func _init() -> void:
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
		print("\n--- STAGE: ", path.get_file())
		var packed := load(path) as PackedScene
		if not packed:
			print("FAILED TO LOAD: ", path)
			continue
		var state := packed.get_state()
		var node_count := state.get_node_count()
		var found_finish := false
		var found_track := false
		for i in node_count:
			var nname := state.get_node_name(i)
			if nname == "FinishLine":
				print("Found FinishLine node at index ", i)
				found_finish = true
			elif nname == "TrackPath":
				print("Found TrackPath node at index ", i)
				found_track = true
	quit()
