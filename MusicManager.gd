extends Node

var music_folder = "res://music/"
var playlist = []
var current_track_index = -1
var audio_player: AudioStreamPlayer

func _ensure_audio_buses():
	# Ensure "Music" bus exists
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	
	# Ensure "SFX" bus exists
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

func _ready():
	_ensure_audio_buses()
	
	# Configure the audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.bus = "Music" # We'll ensure this exists or use Master
	audio_player.volume_db = -10.0 # Initial background level
	add_child(audio_player)
	
	audio_player.finished.connect(_on_track_finished)
	
	_load_playlist()
	# Music only starts when play_race_music() is called

func _load_playlist():
	playlist.clear()
	var dir = DirAccess.open(music_folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".mp3") or file_name.ends_with(".wav") or file_name.ends_with(".ogg"):
					playlist.append(music_folder + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	if playlist.size() > 0:
		playlist.shuffle()

func play_race_music():
	if not audio_player.playing:
		play_next()

func play_next():
	if playlist.is_empty():
		return
		
	current_track_index = (current_track_index + 1) % playlist.size()
	
	if current_track_index == 0:
		playlist.shuffle()
		
	var track_path = playlist[current_track_index]
	var stream = load(track_path)
	
	if stream:
		audio_player.stream = stream
		audio_player.play()
	else:
		play_next()

func _on_track_finished():
	await get_tree().create_timer(1.0).timeout
	play_next()

# Independent volume controls for the UI
func set_music_volume(linear_val: float):
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx == -1: bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))

func set_sfx_volume(linear_val: float):
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx == -1: bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))

# Helper methods for game control if needed
func set_volume(volume_db: float):
	audio_player.volume_db = volume_db

func stop():
	audio_player.stop()

func play():
	if not audio_player.playing:
		audio_player.play()
