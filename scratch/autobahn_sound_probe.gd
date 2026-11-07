extends SceneTree
## Rides a camera (and a stand-in cart in "player_carts") along Rheinufer's A 47 westbound against its traffic and logs
## AutobahnTraffic's sound every `every` seconds: each voice's vehicle, distance, closing speed, engine pitch (the
## Doppler shift: over 1 approaching, under 1 going away) and whether its horn is sounding; then the honks counted.
## Only the traffic node is taken from the level. Windowed (sounds are off headless; the master bus is muted):
##   Godot --path . --fixed-fps 60 -s res://scratch/autobahn_sound_probe.gd -- [level=res://levels/RheinuferLevel.tscn]
##       [node=Verkehr/A47Traffic] [from=-340,-378.9] [dir=1,0] [speed=40] [seconds=14] [every=0.5] [y=]
## CrossTraffic works too (its engine voices: `_engines`), e.g. Quer durch Kronburg's Ring with a standing camera:
##   -- level=res://levels/StadtrallyeLevel.tscn node=Ring/RingTraffic from=<x>,<z> speed=0 y=<height>

func _init() -> void:
	var level_path := "res://levels/RheinuferLevel.tscn"
	var node_path := "Verkehr/A47Traffic"
	var from := Vector2(-340.0, -378.9)
	var dir := Vector2(1.0, 0.0)
	var speed := 40.0
	var seconds := 14.0
	var every := 0.5
	var fixed_y := NAN
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("node="): node_path = a.substr(5)
		elif a.begins_with("from="): from = Vector2(float(a.substr(5).split(",")[0]), float(a.substr(5).split(",")[1]))
		elif a.begins_with("dir="): dir = Vector2(float(a.substr(4).split(",")[0]), float(a.substr(4).split(",")[1])).normalized()
		elif a.begins_with("speed="): speed = float(a.substr(6))
		elif a.begins_with("seconds="): seconds = float(a.substr(8))
		elif a.begins_with("every="): every = float(a.substr(6))
		elif a.begins_with("y="): fixed_y = float(a.substr(2))
	AudioServer.set_bus_mute(0, true)
	var level: Node = (load(level_path) as PackedScene).instantiate()
	var traffic: Node3D = level.get_node(node_path)
	var xf: Transform3D = traffic.global_transform if traffic.is_inside_tree() else traffic.transform
	traffic.get_parent().remove_child(traffic)
	traffic.owner = null
	traffic.transform = xf
	get_root().add_child(traffic)
	var cam := Camera3D.new()
	get_root().add_child(cam)
	cam.current = true
	var cart := Node3D.new()
	cart.add_to_group("player_carts")
	get_root().add_child(cart)
	var hs: Array = traffic.get("heights")
	var t := 0.0
	var next := 0.0
	var honks := 0
	var was_honking := {}
	while t < seconds:
		var p2: Vector2 = from + dir * (speed * t)
		# The road's height from the traffic's own table (distance along its -z from its start).
		var local: Vector3 = traffic.global_transform.affine_inverse() * Vector3(p2.x, 0, p2.y)
		var y: float = traffic.global_position.y + (traffic.call("_height", -local.z) if hs.size() > 1 and "_voices" in traffic else 0.0)
		if not is_nan(fixed_y):
			y = fixed_y
		cam.global_position = Vector3(p2.x, y + 2.5, p2.y)
		cam.look_at(cam.global_position + Vector3(dir.x, 0, dir.y))
		cart.global_position = Vector3(p2.x, y + 0.6, p2.y)
		await process_frame
		t += 1.0 / 60.0
		if "_engines" in traffic:
			if t >= next:
				next += every
				var line2 := "t=%5.2f:" % t
				for en in traffic.get("_engines"):
					if en[1] != null:
						var pl: AudioStreamPlayer3D = en[0]
						line2 += "  %s %.0fm p%.2f %+.0fdB%s" % [pl.stream.resource_path.get_file().get_basename(), pl.global_position.distance_to(cam.global_position),
								pl.pitch_scale, pl.volume_db, "" if pl.playing else " SILENT"]
				print(line2)
			continue
		var voices: Array = traffic.get("_voices")
		for vo in voices:
			var h: bool = vo.horn.playing
			if h and not was_honking.get(vo, false):
				honks += 1
				print("t=%5.2f HONK from vehicle %d, %.0fm away" % [t, vo.car, vo.horn.global_position.distance_to(cam.global_position)])
			was_honking[vo] = h
		if t >= next:
			next += every
			var line := "t=%5.2f at x %.0f:" % [t, p2.x]
			for vo in voices:
				if vo.car < 0:
					continue
				var d: float = vo.engine.global_position.distance_to(cam.global_position)
				line += "  #%d %.0fm p%.2f%s" % [vo.car, d, vo.engine.pitch_scale, " H" if vo.horn.playing else ""]
			print(line)
	print("HONKS %d in %.0fs" % [honks, seconds])
	quit()
