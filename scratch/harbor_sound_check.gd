extends Node
## Harbor Pier's sounds: StageAmbience's layers (clips and the level each plays at), every SeaBoat's engine and horn,
## and the idling tug. Windowed (SeaBoat adds no sound on a headless server):
##   Godot --path . res://scratch/harbor_sound_check.tscn [-- res://levels/HarborPierLevel.tscn]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://levels/HarborPierLevel.tscn"
	var amb = load("res://StageAmbience.gd")
	print("STAGE ", path.get_file())
	for l in amb.layers_for(path):
		var clips: Array = amb.CLIP_DB.keys().filter(func(p: String): return p.begins_with("res://sounds/%s/" % l[0]))
		print("  layer %s at %.1f dBFS: %d clips" % [l[0], l[1], clips.size()])
		for c in clips:
			print("    %s  volume %+.1f dB" % [c.get_file(), float(l[1]) - float(amb.CLIP_DB[c])])
	var level: Node = (load(path) as PackedScene).instantiate()
	add_child(level)
	for i in 3:
		await get_tree().process_frame
	for n in level.find_children("*", "Node3D", true, false):
		if n.get_script() == load("res://SeaBoat.gd"):
			var line := "  boat %s:" % n.name
			for p in n.find_children("*", "AudioStreamPlayer3D", true, false):
				var ap := p as AudioStreamPlayer3D
				line += " %s(%s %+.1fdB unit %.0fm pitch %.2f%s)" % [ap.name, ap.stream.resource_path.get_file() if ap.stream else "-", ap.volume_db, ap.unit_size, ap.pitch_scale, " playing" if ap.playing else ""]
			print(line)
	var idle := level.find_child("TugAlongsideEngine", true, false) as AudioStreamPlayer3D
	if idle:
		print("  idle tug: %+.1fdB pitch %.2f autoplay %s" % [idle.volume_db, idle.pitch_scale, idle.autoplay])
	var diesel := load("res://sounds/harbor/boat_diesel_engine.wav") as AudioStreamWAV
	print("  diesel loops: ", diesel.loop_mode != AudioStreamWAV.LOOP_DISABLED, " (mode ", diesel.loop_mode, ")")
	get_tree().quit()
