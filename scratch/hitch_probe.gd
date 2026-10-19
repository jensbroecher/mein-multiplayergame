extends Node

# Hunts first-use hitches: starts a spectator race (6 AI carts), then has a cart use each item in
# turn, twice, and prints the longest frames after each use with the pipeline compilations the
# renderer did in that window (a draw-time compilation is a stall). Also times the frames round the
# countdown and GO. The bots' own items are taken away so only the probe's uses count. Run windowed:
#   Godot --path . --resolution 1280x720 res://scratch/hitch_probe.tscn -- [level=res://levels/LakesideLevel.tscn]
#       [items=lightning,shockwave,missile,guided,bomb,boost,shield] [repeats=2] [gap=2.0] [cart=100]
# items= also takes cart effects: respawn, explode, splash, fade, unfade, shocked (the lightning's
# slow and blue blink on the cart itself), and explode_wheels / explode_parts / explode_shatter
# (an explosion with that damage forced).

const ITEMS := {"boost": 1, "missile": 2, "guided": 3, "shield": 4, "shockwave": 5, "bomb": 6, "lightning": 7}
const COMPILES := {
	"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"spec": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}

var _frames: Array = [] # [usec at frame start, frame length in ms, process ms, physics ms, render cpu ms]
var _last_us := 0
var _strip_items := false
var _level: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path := "res://levels/LakesideLevel.tscn"
	var items: PackedStringArray = ["lightning", "shockwave", "missile", "guided", "bomb", "boost", "shield"]
	var repeats := 2
	var gap := 2.0
	var cart_id := "100"
	for a in args:
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("items="):
			items = a.substr(6).split(",")
		elif a.begins_with("repeats="):
			repeats = int(a.substr(8))
		elif a.begins_with("gap="):
			gap = float(a.substr(4))
		elif a.begins_with("cart="):
			cart_id = a.substr(5)
		elif a == "premusic":
			# Load the stage's playlist before the race, so GO finds it loaded.
			MusicManager.load_playlist_for_level(level_path)
	process_priority = -1000
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var t_load := Time.get_ticks_usec()
	_level = load(level_path).instantiate()
	add_child(_level)
	print("PROBE level instanced in %.0f ms" % ((Time.get_ticks_usec() - t_load) / 1000.0))
	_last_us = Time.get_ticks_usec()

	while _level.race_state != _level.RaceState.RACING:
		await get_tree().process_frame
	_strip_items = true
	var t_race := Time.get_ticks_usec()
	_mark()
	# Intro (3.5s) + countdown (3s) + a second of racing.
	await _wait(8.0)
	_report("countdown+GO", t_race)
	MusicManager._current_level_key = ""
	var t_music := Time.get_ticks_usec()
	MusicManager.load_playlist_for_level(_level.scene_file_path)
	print("PROBE reloading the stage playlist took %.0f ms (%d tracks)" % [(Time.get_ticks_usec() - t_music) / 1000.0, MusicManager.playlist.size()])

	var cart: Node = _level.find_child(cart_id, true, false)
	for item in items:
		for r in repeats:
			if not is_instance_valid(cart):
				print("PROBE no cart ", cart_id)
				break
			var t0 := _mark()
			match item:
				"respawn":
					cart.respawn()
				"explode":
					cart.explode(0)
				"explode_wheels":
					cart.damage_override = {"wheels": ["FL", "RR"], "parts": 0, "disintegrate": false}
					cart.explode(0)
				"explode_parts":
					cart.damage_override = {"wheels": [], "parts": 8, "disintegrate": false}
					cart.explode(0)
				"explode_shatter":
					cart.damage_override = {"wheels": ["FL"], "parts": 0, "disintegrate": true}
					cart.explode(0)
				"splash":
					cart._spawn_splash(cart.global_position)
				"fade":
					cart._set_visuals_alpha(0.5)
				"unfade":
					cart._set_visuals_alpha(1.0)
				"shocked":
					cart.apply_lightning_slow_multicast()
				_:
					cart._execute_use_item(ITEMS[item])
			await _wait(gap)
			_report("%s #%d" % [item, r + 1], t0)
	get_tree().quit()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	# The previous frame's split, read at the start of this one.
	_frames.append([_last_us, (now - _last_us) / 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, RenderingServer.get_frame_setup_time_cpu()])
	_last_us = now
	if _strip_items:
		for c in get_tree().get_nodes_in_group("player_carts"):
			c.current_item = 0
			c.current_item_2 = 0


var _compile_base := {}

func _mark() -> int:
	for k in COMPILES:
		_compile_base[k] = Performance.get_monitor(COMPILES[k])
	return Time.get_ticks_usec()


func _wait(seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await get_tree().process_frame


func _report(label: String, since_us: int) -> void:
	var lens: Array = []
	for f in _frames:
		if f[0] >= since_us:
			lens.append(f[1])
	lens.sort()
	lens.reverse()
	var top: Array = []
	for i in mini(4, lens.size()):
		top.append("%.0f" % lens[i])
	var median: float = lens[lens.size() / 2] if not lens.is_empty() else 0.0
	var at := ""
	for i in _frames.size():
		var f: Array = _frames[i]
		if f[0] >= since_us and f[1] > 60.0:
			at += " %.0fms@%.2fs" % [f[1], (f[0] - since_us) / 1000000.0]
			# Process, physics and render setup of the long frame (reported on the next one).
			if i + 1 < _frames.size():
				var n: Array = _frames[i + 1]
				at += "(process %.0f physics %.0f render-setup %.0f)" % [n[2], n[3], n[4]]
	var comp := ""
	for k in COMPILES:
		var d: int = int(Performance.get_monitor(COMPILES[k]) - _compile_base[k])
		if d != 0:
			comp += " %s=%d" % [k, d]
	print("PROBE %-16s longest ms [%s] median %.1f compiles:%s" % [label, ", ".join(top), median, comp if comp != "" else " none"])
	if at != "":
		print("PROBE   long frames (start of frame, s after mark):", at)
