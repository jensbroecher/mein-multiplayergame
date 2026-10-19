extends Node

# Plays the game the way a player does, through Main.tscn with the saved settings (window, render
# scale, shadows, the saved car): the menu, the car select screen, then a time trial with the
# throttle held. Prints the frame times of each stage: median, 95th percentile, worst, and the
# frames per second. Run windowed (the saved window mode applies):
#   Godot --path . res://scratch/flow_bench.tscn -- [stage=res://levels/LakesideLevel.tscn] [car=<index>]
#       [race=20] [steer=0.3]
# car= overrides the saved car for this run (the saved one is put back).

var _frames: Array = [] # frame lengths in ms of the stage being measured
var _last_us := 0
var _measuring := false


func _ready() -> void:
	var stage := "res://levels/LakesideLevel.tscn"
	var car := -1
	var race_s := 20.0
	var steer := 0.3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("stage="):
			stage = a.substr(6)
		elif a.begins_with("car="):
			car = int(a.substr(4))
		elif a.begins_with("race="):
			race_s = float(a.substr(5))
		elif a.begins_with("steer="):
			steer = float(a.substr(6))
	process_priority = -1000
	_last_us = Time.get_ticks_usec()
	var main: Node = load("res://Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _wait(3.0)
	await _measure("main menu", 5.0)

	var menu: Node = main.get_node("MainMenu")
	var cs: Node = main.get_node("CarSelection")
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	menu._on_stage_selected(stage)
	await _wait(2.0)
	if car >= 0:
		cs._select_car(car)
	await _measure("car select", 5.0)
	print("BENCH car: ", cs.CAR_PRESETS[cs.current_car_index]["name"])

	cs._on_confirm_pressed()
	var level: Node = null
	while level == null or level.race_state != level.RaceState.RACING or main.loading_screen.visible:
		await get_tree().process_frame
		for n in main.get_children():
			if n.is_in_group("level"):
				level = n
	await _measure("intro + countdown", 7.0)
	Input.action_press("p1_throttle")
	if steer > 0.0:
		Input.action_press("p1_steer_left", steer)
	await _measure("racing", race_s)
	Input.action_release("p1_throttle")
	Input.action_release("p1_steer_left")
	get_tree().quit()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _measuring:
		_frames.append((now - _last_us) / 1000.0)
	_last_us = now


func _wait(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await get_tree().process_frame


func _measure(label: String, seconds: float) -> void:
	_frames.clear()
	_measuring = true
	await _wait(seconds)
	_measuring = false
	var f: Array = _frames.duplicate()
	f.sort()
	if f.is_empty():
		print("BENCH %-18s no frames" % label)
		return
	var total := 0.0
	for x in f:
		total += x
	print("BENCH %-18s %4d frames  %5.1f fps  median %5.1f ms  p95 %5.1f ms  worst %6.1f ms" % [label, f.size(),
			f.size() / (total / 1000.0), f[f.size() / 2], f[int(f.size() * 0.95)], f[f.size() - 1]])
