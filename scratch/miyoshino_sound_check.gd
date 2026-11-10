extends SceneTree
## Lists what a level's StageAmbience plays (each layer's clip and level) and its PeriodicSound players (headless):
##   Godot --headless --path . -s res://scratch/miyoshino_sound_check.gd -- res://levels/X.tscn ...
func _init() -> void:
	for path in OS.get_cmdline_user_args():
		var name: String = path.get_file().get_basename()
		var layers: Array = (load("res://StageAmbience.gd") as Script).get_script_constant_map()["STAGES"].get(name, [])
		var db: Dictionary = (load("res://StageAmbience.gd") as Script).get_script_constant_map()["CLIP_DB"]
		print("== %s" % name)
		for l in layers:
			var clips: Array = db.keys().filter(func(p: String): return p.begins_with("res://sounds/%s/" % l[0]))
			print("  layer %s at %.0f dBFS: %d clips %s" % [l[0], l[1], clips.size(), str(clips.map(func(p): return p.get_file()))])
			for c in clips:
				if not ResourceLoader.exists(c):
					print("    MISSING ", c)
		var lvl: Node = (load(path) as PackedScene).instantiate()
		for p in lvl.find_children("*", "AudioStreamPlayer3D", true, false):
			if p.get_script() and String(p.get_script().resource_path).ends_with("PeriodicSound.gd"):
				print("  periodic %s: %s every %.0fs at %s, %.0f dB, unit %.0f" % [p.name, p.stream.resource_path.get_file() if p.stream else "-", p.every, p.position, p.volume_db, p.unit_size])
		lvl.free()
	quit()
