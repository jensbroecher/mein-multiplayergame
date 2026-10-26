extends Node

# Split screen with both players on the High camera: drives both carts forward for a few seconds and prints
# each cart's High-view lead, and how far PlayerCart._fit_topdown_lead lets a long lead go sideways and
# along the view's depth. A split-screen half is narrower than the window, so the sideways room is smaller
# than the full-screen view's (the probe's `mode=top` reports that). Headless:
#   Godot --headless --path . res://scratch/coop_high_cam_check.tscn -- [level=res://levels/LakesideLevel.tscn]


func _ready() -> void:
	var level_path := "res://levels/LakesideLevel.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("level="):
			level_path = a.substr(6)
	AudioServer.set_bus_mute(0, true)
	MusicManager.camera_mode = MusicManager.CameraMode.TOP_DOWN
	NetworkManager.current_game_mode = NetworkManager.GameMode.LOCAL_COOP
	NetworkManager.start_local_coop("P1", "P2")
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	Input.action_press("p1_throttle")
	Input.action_press("p2_throttle")
	var t := 0.0
	while t < 14.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	for id in [1, 2]:
		var cart = level.players_container.get_node(str(id))
		var side: Vector3 = cart._fit_topdown_lead(Vector3(40.0, 0.0, -40.0).cross(Vector3.UP).normalized() * 40.0)
		var depth: Vector3 = cart._fit_topdown_lead(Vector3(30.0, 0.0, -30.0).normalized() * 40.0)
		print("cart %d: High %s, split camera %s, lead %.1f m (speed %.1f), a 40 m lead across the view fits to %.1f m, along it to %.1f m" % [
				id, str(cart.is_isometric), str(cart.splitscreen_camera != null), cart._topdown_lead.length(), cart.linear_velocity.length(),
				side.length(), depth.length()])
	Input.action_release("p1_throttle")
	Input.action_release("p2_throttle")
	get_tree().quit()
