extends Node

var music_folder = "res://music/"
var playlist = []
var loaded_playlist = []
const SETTINGS_FILE = "user://settings.cfg"

var music_volume: float = 0.8
var sfx_volume: float = 0.7
var show_fps: bool = false
var window_mode: int = 0 # 0: Windowed, 1: Fullscreen
var vsync: bool = false

var current_track_index = -1
var player1: AudioStreamPlayer
var player2: AudioStreamPlayer
var active_player: AudioStreamPlayer
var inactive_player: AudioStreamPlayer

var fps_layer: CanvasLayer
var fps_label: Label

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
	load_settings()
	
	# Configure two audio players for crossfading
	player1 = AudioStreamPlayer.new()
	player1.bus = "Music"
	player1.volume_db = -80.0
	add_child(player1)
	
	player2 = AudioStreamPlayer.new()
	player2.bus = "Music"
	player2.volume_db = -80.0
	add_child(player2)
	
	active_player = player1
	inactive_player = player2
	
	player1.finished.connect(_on_track_finished)
	player2.finished.connect(_on_track_finished)
	_load_playlist()
	
	# Create FPS layer and label
	fps_layer = CanvasLayer.new()
	fps_layer.layer = 128
	
	fps_label = Label.new()
	fps_label.name = "FPSLabel"
	fps_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.8))
	fps_label.add_theme_font_size_override("font_size", 16)
	
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	style_box.content_margin_left = 10
	style_box.content_margin_right = 10
	style_box.content_margin_top = 5
	style_box.content_margin_bottom = 5
	style_box.corner_radius_top_left = 4
	style_box.corner_radius_top_right = 4
	style_box.corner_radius_bottom_left = 4
	style_box.corner_radius_bottom_right = 4
	fps_label.add_theme_stylebox_override("normal", style_box)
	
	fps_label.text = "FPS: 60"
	fps_layer.add_child(fps_label)
	add_child(fps_layer)
	
	# We will position it dynamically in _process relative to the actual viewport size
	fps_label.position = Vector2(0, 10)
	
	fps_layer.visible = show_fps

func _process(_delta):
	if show_fps and fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
		var viewport_width = get_viewport().get_visible_rect().size.x
		var label_width = fps_label.get_minimum_size().x
		fps_label.position = Vector2(viewport_width - label_width - 20, 10)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	if err == OK:
		music_volume = config.get_value("audio", "music", 0.8)
		sfx_volume = config.get_value("audio", "sfx", 0.7)
		show_fps = config.get_value("display", "show_fps", false)
		window_mode = config.get_value("display", "window_mode", 0)
		vsync = config.get_value("display", "vsync", false)
		
	# Apply loaded settings
	set_music_volume(music_volume, false)
	set_sfx_volume(sfx_volume, false)
	set_show_fps(show_fps, false)
	set_window_mode(window_mode, false)
	set_vsync(vsync, false)

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "show_fps", show_fps)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "vsync", vsync)
	config.save(SETTINGS_FILE)

func _load_playlist():
	playlist.clear()
	loaded_playlist.clear()
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
		for path in playlist:
			var stream = load(path)
			if stream:
				loaded_playlist.append(stream)

func play_race_music():
	if not active_player.playing:
		play_next()

func play_next():
	if loaded_playlist.is_empty():
		return
		
	current_track_index = (current_track_index + 1) % loaded_playlist.size()
	
	if current_track_index == 0:
		loaded_playlist.shuffle()
		
	var stream = loaded_playlist[current_track_index]
	
	if stream:
		var prev_active = active_player
		active_player = inactive_player
		inactive_player = prev_active
		
		active_player.stream = stream
		active_player.volume_db = -80.0
		active_player.play()
		
		# Crossfade tween
		var tween = create_tween()
		tween.tween_property(inactive_player, "volume_db", -80.0, 2.0)
		tween.parallel().tween_property(active_player, "volume_db", -10.0, 2.0)
		tween.tween_callback(inactive_player.stop)
	else:
		play_next()

func _on_track_finished():
	if not active_player.playing:
		await get_tree().create_timer(1.0).timeout
		if not active_player.playing:
			play_next()

# Independent volume controls for the UI
func set_music_volume(linear_val: float, save: bool = true):
	music_volume = linear_val
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx == -1: bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))
	if save: save_settings()

func set_sfx_volume(linear_val: float, save: bool = true):
	sfx_volume = linear_val
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx == -1: bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(linear_val))
	if save: save_settings()

func set_show_fps(enabled: bool, save: bool = true):
	show_fps = enabled
	if fps_layer:
		fps_layer.visible = enabled
	if save: save_settings()

func set_window_mode(mode: int, save: bool = true):
	window_mode = mode
	if mode == 1:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if save: save_settings()

func set_vsync(enabled: bool, save: bool = true):
	vsync = enabled
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if save: save_settings()

