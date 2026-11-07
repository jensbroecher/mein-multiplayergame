extends Node

# Time trial: no item boxes anywhere (spawned or placed in the level), no race commentator, one boost in the
# slots at the green light and one more at every gate that counts (up to the two slots; none at the final
# finish), the HUD's lap timer fed each gate and lap, the run saved to TimeTrialRecords, and the end screen's
# lap sheet. A real single-player time trial (the human is id 1); the gates are granted in turn with the lap's
# start moved back, so laps take `lap=` seconds without waiting. The player's own records files are put back.
# Headless:
#   Godot --headless --path . res://scratch/time_trial_items_check.tscn -- [res://levels/X.tscn] [lap=62]

const TTR = preload("res://TimeTrialRecords.gd")
const FILES := ["user://time_trial_records.cfg", "user://lap_records.cfg"]

var fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	var level_path := "res://levels/PinecrestRidgeLevel.tscn"
	var lap_s := 62.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lap="): lap_s = float(a.substr(4))
		elif a.begins_with("res://"): level_path = a
	var backup := {}
	for f in FILES:
		backup[f] = null
		if FileAccess.file_exists(f):
			backup[f] = FileAccess.get_file_as_bytes(f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL
	NetworkManager.time_trial_stage = level_path
	NetworkManager.start_single_player("Tester")
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING or level._race_go_msec == 0:
		await get_tree().process_frame
	await get_tree().process_frame
	var cart = level.players_container.get_node("1")
	cart.can_move = false
	var ui = level.race_ui
	var cps: int = level.checkpoints.size()
	var laps: int = level.get_target_laps()
	print("%s: %d gates, %d laps" % [level_path.get_file(), cps, laps])
	_check(get_tree().get_nodes_in_group("item_boxes").is_empty(), "no item boxes")
	_check(level._commentator == null, "no commentator")
	_check(cart.current_item == 1 and cart.current_item_2 == 0, "one boost at GO (slots %d, %d)" % [cart.current_item, cart.current_item_2])
	_check(ui.timing_panel != null and ui.timing_panel.visible, "lap timer shown")
	var pos_box: Control = ui.get_node("HUDPanel/PositionContainer")
	_check(not pos_box.visible, "position hidden")

	var stats: Dictionary = level.player_stats[1]
	var gate_boosts := 0
	for lap in laps:
		# Each lap a little faster, so the second is a lap record and the third isn't.
		var lap_ms: int = int(lap_s * 1000.0) - [0, 1500, 900][mini(lap, 2)]
		for i in cps:
			cart.current_item = 0
			cart.current_item_2 = 0
			var split: int = int(lap_ms * float(i + 1) / cps)
			stats["lap_start"] = Time.get_ticks_msec() - split
			level._grant_checkpoint(1, i)
			if cart.current_item == 1:
				gate_boosts += 1
			if lap == 0 and i == 0:
				_check(cart.current_item == 1 and cart.current_item_2 == 0, "a gate's boost into slot 1")
				cart.current_item = 1
				level._grant_checkpoint(1, 1)
				_check(cart.current_item == 1 and cart.current_item_2 == 1, "the next gate's into slot 2")
				level._grant_checkpoint(1, 2)
				_check(cart.current_item == 1 and cart.current_item_2 == 1, "both full: still two boosts")
				break
		if lap == 0 and cps > 3:
			# The rest of lap 1 (the first two gates went above).
			for i in range(3, cps):
				cart.current_item = 0
				cart.current_item_2 = 0
				stats["lap_start"] = Time.get_ticks_msec() - int(lap_ms * float(i + 1) / cps)
				level._grant_checkpoint(1, i)
				if cart.current_item == 1:
					gate_boosts += 1
		var shown: Array = []
		for k in ui._t_rows:
			shown.append("%s %s" % [k, ui._t_rows[k].text])
		print("  lap %d: HUD %s, delta '%s %s'" % [lap + 1, ", ".join(shown), ui._t_tag.text, ui._t_delta.text])
	_check(gate_boosts == laps * cps - 1 - 2, "a boost at every gate but the final line (%d)" % gate_boosts)
	_check(cart.current_item == 0, "no boost at the final line")
	_check(stats["finished"], "finished")
	_check(ui._t_lap_times.size() == laps, "HUD got %d laps" % ui._t_lap_times.size())
	_check(not ui._t_running, "HUD clock stopped")
	var rec: Dictionary = TTR.stage(TTR.key_of(level_path))
	print("  saved: %s" % str(rec))
	_check(int(rec["run_ms"]) == int(stats["finish_ms"]) and int(rec["runs"]) == 1, "run saved")
	_check(int(rec["lap_ms"]) > 0 and rec["lap_splits"].size() == cps, "best lap and its splits saved")
	# The run ends at the line by itself: no 30s countdown, the end screen on the next frame.
	_check(float(level.end_timer) <= 0.0, "no end countdown")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(level.race_state == level.RaceState.FINISHED, "the race ended at the line")
	_check(ui.end_panel.visible, "the end screen is up")
	print("  end screen: %s" % ui.get_node("EndPanel/VBoxContainer/LabelFinished").text)
	for row in ui.results_container.get_children():
		_print_texts(row, "    ")
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	for f in FILES:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
		if backup[f] != null:
			var fa := FileAccess.open(f, FileAccess.WRITE)
			fa.store_buffer(backup[f])
			fa.close()
	get_tree().quit()


func _print_texts(n: Node, indent: String) -> void:
	var parts: Array = []
	_collect(n, parts)
	if not parts.is_empty():
		print(indent + " | ".join(parts).replace("\n", " "))


func _collect(n: Node, parts: Array) -> void:
	if n is Label and (n as Label).text != "":
		parts.append((n as Label).text)
	for c in n.get_children():
		if n is Container and c is Container:
			_collect(c, parts)
		elif c is Label:
			_collect(c, parts)
