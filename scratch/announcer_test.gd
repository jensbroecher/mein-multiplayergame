extends Node

# Walks splitscreen player 1 through every gate for the whole race (Level._grant_checkpoint) and
# lists what the announcer says at each one, then what the countdown and the finish said. Also
# reports what the start gantry's ticker would show. Headless:
#   Godot --headless --path . res://scratch/announcer_test.tscn -- [res://levels/X.tscn]

var _heard: Dictionary = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0] if args.size() > 0 else "res://levels/LakesideLevel.tscn"
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.LOCAL_COOP
	NetworkManager.start_local_coop("P1", "P2")
	MusicManager.child_entered_tree.connect(_on_sound)
	var level: Node = load(level_path).instantiate()
	add_child(level)
	while level.race_state != level.RaceState.RACING:
		await get_tree().process_frame
	_say_since("lobby")
	# Intro and countdown.
	await get_tree().create_timer(7.2).timeout
	_say_since("countdown")
	var music: AudioStream = MusicManager.active_player.stream
	print("MUSIC playing=%s %s, loaded: %s" % [MusicManager.active_player.playing,
			music.resource_path.get_file() if music else "none", ", ".join(MusicManager._music_streams.keys().map(func(p): return p.get_file()))])
	var gates: int = level.checkpoints.size()
	for lap in NetworkManager.max_laps:
		for i in gates:
			level._grant_checkpoint(1, i)
			await get_tree().process_frame
			_say_since("lap %d gate %d/%d" % [lap + 1, i + 1, gates])
	await get_tree().create_timer(1.5).timeout
	_say_since("after the finish")
	var fl: Node = level.get_node("FinishLine")
	var texts: Array = []
	for t in fl._ticker_next if not fl._ticker_next.is_empty() else fl._ticker_shown:
		if t.has("text"):
			texts.append(t["text"])
	print("TICKER: ", " | ".join(texts), "  flag=", fl._flag_on)
	get_tree().quit()


var _order: Array = []

func _on_sound(node: Node) -> void:
	if node is AudioStreamPlayer and node.stream:
		var path: String = node.stream.resource_path
		_order.append(path.get_file() if path != "" else "beep")


func _say_since(label: String) -> void:
	var said: Array = _order.duplicate()
	_order.clear()
	print("%-22s %s" % [label, ", ".join(said) if not said.is_empty() else "-"])
