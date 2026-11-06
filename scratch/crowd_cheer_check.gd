extends SceneTree
## Drives a stand-in cart (a node in "player_carts") along Marina Nights' start straight at `speed` and prints which of
## the promenade's cheering sections (CrowdCheers.gd) went off, when, and with which clip and volume. Windowed (the
## cheers do nothing headless), audio muted:
##   Godot --path . --resolution 640x360 -s res://scratch/crowd_cheer_check.gd -- [level=res://levels/MarinaNightsLevel.tscn] [speed=30]

func _init() -> void:
	var level_path := "res://levels/MarinaNightsLevel.tscn"
	var speed := 30.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("speed="):
			speed = float(a.substr(6))
	AudioServer.set_bus_mute(0, true)
	var level: Node3D = (load(level_path) as PackedScene).instantiate()
	get_root().add_child(level)
	var cheers: Node3D = level.find_child("PromenadeCheers", true, false)
	var path: Path3D = level.get_node("TrackPath")
	var curve := path.curve
	var cart := Node3D.new()
	cart.add_to_group("player_carts")
	get_root().add_child(cart)
	for i in range(10):
		await physics_frame
	var players: Array = []
	for sec in cheers.get_children():
		for p in sec.get_children():
			if p is AudioStreamPlayer3D:
				players.append([sec.name, p, false])
	print("%d sections" % players.size())
	var fl: Node3D = level.get_node("FinishLine")
	var s0: float = curve.get_closest_offset(fl.global_position) - 140.0
	var t := 0.0
	var fired := 0
	while t < 260.0 / speed:
		var s: float = fposmod(s0 + t * speed, curve.get_baked_length())
		cart.global_position = curve.sample_baked(s)
		await physics_frame
		t += 1.0 / 60.0
		for e in players:
			var p: AudioStreamPlayer3D = e[1]
			if p.playing and not bool(e[2]):
				fired += 1
				print("  %.1fs  %s  %s  %.1f dB" % [t, e[0], (p.stream as AudioStream).resource_path.get_file(), p.volume_db])
			e[2] = p.playing
	print("%d cheers as one cart passed at %.0f m/s" % [fired, speed])
	quit()
