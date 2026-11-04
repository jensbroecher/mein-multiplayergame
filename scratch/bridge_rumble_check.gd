extends Node
## Drives a stand-in cart (a Node3D in "player_carts") across Harbor Pier's inner steel bridge at `speed` and logs what
## BridgeRumble plays: the clangs on and off, the plate clanks, the rumble's level and pitch. Windowed (a headless run
## makes no sound):  Godot --path . res://scratch/bridge_rumble_check.tscn [-- speed=25]

func _ready() -> void:
	var speed := 25.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("speed="):
			speed = float(a.substr(6))
	var level: Node = (load("res://levels/HarborPierLevel.tscn") as PackedScene).instantiate()
	add_child(level)
	var br := level.find_child("BridgeRumble", true, false)
	var cart := RigidBody3D.new()
	cart.freeze = true
	cart.collision_layer = 0
	cart.collision_mask = 0
	cart.add_to_group("player_carts")
	add_child(cart)
	cart.global_position = Vector3(50.0, 4.3, 35.0)
	for i in 5:
		await get_tree().physics_frame
	var was := {}
	var t := 0.0
	var dt := 1.0 / 60.0
	while cart.global_position.x > -10.0:
		await get_tree().physics_frame
		t += dt
		cart.global_position.x -= speed * dt
		for p in br.get_children(true):
			if p is AudioStreamPlayer3D:
				var ap := p as AudioStreamPlayer3D
				var key := ap.get_instance_id()
				if ap.playing and not was.get(key, false):
					var what := "rumble" if (ap.stream as AudioStreamWAV).loop_mode != 0 else ("clang" if ap.stream.get_length() > 0.5 else "clank")
					print("  t=%.2f x=%.1f %s %+.1fdB pitch %.2f" % [t, cart.global_position.x, what, ap.volume_db, ap.pitch_scale])
				was[key] = ap.playing
	get_tree().quit()
