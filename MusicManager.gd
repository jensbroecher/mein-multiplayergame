extends Node

var music_folder = "res://music/"
var playlist = []
var loaded_playlist = []
var _music_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _playback_queue: Array = []
var _last_played_stream: AudioStream = null
var _current_level_key: String = ""
const SETTINGS_FILE = "user://settings.cfg"

var music_volume: float = 0.8
var sfx_volume: float = 0.7
var show_fps: bool = false
var window_mode: int = 0 # 0: Windowed, 1: Fullscreen
var resolution_index: int = 1 # Default 1920x1080
var vsync: bool = false
var anti_aliasing: int = 2 # 0: Disabled, 1: 2x MSAA, 2: 4x MSAA, 3: 8x MSAA, 4: FXAA
# Graphics quality
## Derived from shadow_quality_index > 0 (kept for older code paths).
var shadows_enabled: bool = false
## 0=Off 1=Low 2=Medium 3=High — controls map size, soft filter, and light splits.
var shadow_quality_index: int = 0
## 0=Auto (default), 1=Off, 2=Low, 3=Medium, 4=High, 5=Ultra.
var grass_quality_setting: int = 0
## 0=Off 1=Low 2=Medium 3=High 4=Ultra — active runtime quality applied to meshes and shaders.
var grass_quality_index: int = 4
var _auto_grass_warmup: float = 3.0
var _low_fps_duration: float = 0.0
var render_scale_index: int = 1 # 0:50% 1:75% 2:100% 3:125%
## Preferred renderer: "mobile" or "forward_plus". Applied via restart (--rendering-method).
var renderer_method: String = "mobile"
## Viewport.scaling_3d_mode: 0 bilinear, 1 FSR 1.0, 2 FSR 2.2 (Forward+ only).
var scaling_3d_mode_index: int = 0
## Viewport.fsr_sharpness: 0.0 sharp … 2.0 soft. Default 0.2.
var fsr_sharpness: float = 0.2
var anisotropic_index: int = 1 # 0:Off 1:2x 2:4x 3:8x 4:16x
var max_fps_index: int = 1 # 0:30 1:60 2:120 3:Unlimited
## true = isometric / top-down race cam, false = behind-the-car follower cam.
## Remembered across stages and sessions.
var use_isometric_camera: bool = true

signal camera_mode_changed(is_isometric: bool)

const RESOLUTIONS = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]
const RENDER_SCALES = [0.5, 0.75, 1.0, 1.25]
const ANISOTROPIC_LEVELS = [0, 2, 4, 8, 16]
const MAX_FPS_VALUES = [30, 60, 120, 0] # 0 = unlimited
## Directional shadow atlas size per quality (Off unused).
const SHADOW_ATLAS_SIZES = [512, 1024, 2048, 4096]
const SHADOW_MAX_DISTANCES = [80.0, 140.0, 200.0, 280.0]
const SHADOW_BLURS = [0.4, 0.7, 1.0, 1.25]

const GRASS_SETTING_NAMES = ["Auto", "Off", "Low", "Medium", "High", "Ultra"]
## Grass quality presets: density factor (0..1), draw distance (m), fade range (m)
const GRASS_QUALITY_NAMES = ["Off", "Low", "Medium", "High", "Ultra"]
const GRASS_DENSITIES = [0.0, 0.25, 0.50, 0.75, 1.0]
const GRASS_DISTANCES = [0.0, 130.0, 220.0, 300.0, 350.0]
const GRASS_FADE_RANGES = [0.0, 35.0, 50.0, 50.0, 60.0]


var current_track_index = -1
var player1: AudioStreamPlayer
var player2: AudioStreamPlayer
var active_player: AudioStreamPlayer
var inactive_player: AudioStreamPlayer

var fps_layer: CanvasLayer
var fps_label: Label

## Cached SFX streams so mid-race play() doesn't hitch on HDD load().
var _sfx_cache: Dictionary = {}
const SFX_PRELOAD_PATHS: PackedStringArray = [
	"res://sounds/checkpoint.mp3",
	"res://sounds/finish.mp3",
	"res://sounds/1.mp3",
	"res://sounds/2.mp3",
	"res://sounds/3.mp3",
	"res://sounds/Go.mp3",
	"res://sounds/crash.mp3",
	"res://sounds/electric_lightning_a_#1-1782053835008.wav",
	"res://sounds/stereogenicstudio-swish-swoosh-woosh-sfx-47-357152.mp3",
	"res://sounds/game_bonus_collected_#3-1781737105214.wav",
	"res://sounds/force_field_effect_#1-1781728246336.wav",
]

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
	randomize()
	_music_rng.randomize()
	_ensure_audio_buses()
	
	if not InputMap.has_action("discard_item"):
		InputMap.add_action("discard_item")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_X
		InputMap.action_add_event("discard_item", ev)
		
	load_settings()
	# Exported builds only. Playing from the editor must not quit() to
	# "apply" the renderer — that looks like a silent crash after the menu
	# flashes, and copying --editor-pid / --remote-debug kills the relaunch.
	if _should_restart_for_renderer():
		restart_with_renderer(renderer_method)
		return
	
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
	set_process(show_fps or grass_quality_setting == 0)
	_preload_sfx()

func _process(delta):
	if show_fps and fps_label:
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
		var viewport_width = get_viewport().get_visible_rect().size.x
		var label_width = fps_label.get_minimum_size().x
		fps_label.position = Vector2((viewport_width - label_width) / 2.0, 10)
	
	_check_auto_grass_quality(delta)

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)
	# Default to the renderer this process is already using so first-run
	# (or a launch with --rendering-method) does not immediately bounce.
	renderer_method = get_current_rendering_method()
	if err == OK:
		music_volume = config.get_value("audio", "music", 0.8)
		sfx_volume = config.get_value("audio", "sfx", 0.7)
		show_fps = config.get_value("display", "show_fps", false)
		window_mode = config.get_value("display", "window_mode", 0)
		resolution_index = config.get_value("display", "resolution_index", 1)
		vsync = config.get_value("display", "vsync", false)
		anti_aliasing = config.get_value("display", "anti_aliasing", 2)
		shadows_enabled = config.get_value("graphics", "shadows_enabled", false)
		# Prefer explicit quality; migrate old on/off checkbox (true → Medium)
		if config.has_section_key("graphics", "shadow_quality_index"):
			shadow_quality_index = int(config.get_value("graphics", "shadow_quality_index", 2))
		else:
			shadow_quality_index = 2 if shadows_enabled else 0
		shadow_quality_index = clampi(shadow_quality_index, 0, 3)
		shadows_enabled = shadow_quality_index > 0
		if config.has_section_key("graphics", "grass_quality_setting"):
			grass_quality_setting = clampi(int(config.get_value("graphics", "grass_quality_setting", 0)), 0, 5)
		elif config.has_section_key("graphics", "grass_quality_index"):
			grass_quality_setting = 0
		else:
			grass_quality_setting = 0
		grass_quality_setting = clampi(grass_quality_setting, 0, 5)
		render_scale_index = config.get_value("graphics", "render_scale_index", 1)
		if config.has_section_key("graphics", "renderer_method"):
			var saved_renderer := str(config.get_value("graphics", "renderer_method", renderer_method))
			if saved_renderer == "mobile" or saved_renderer == "forward_plus":
				renderer_method = saved_renderer
		scaling_3d_mode_index = clampi(int(config.get_value("graphics", "scaling_3d_mode_index", 0)), 0, 2)
		fsr_sharpness = clampf(float(config.get_value("graphics", "fsr_sharpness", 0.2)), 0.0, 2.0)
		anisotropic_index = config.get_value("graphics", "anisotropic_index", 1)
		max_fps_index = config.get_value("graphics", "max_fps_index", 1)
		use_isometric_camera = config.get_value("gameplay", "use_isometric_camera", true)
		
	# Apply loaded settings
	set_music_volume(music_volume, false)
	set_sfx_volume(sfx_volume, false)
	set_show_fps(show_fps, false)
	call_deferred("_apply_window_settings")
	load_input_settings()

func _apply_window_settings():
	set_resolution(resolution_index, false)
	set_window_mode(window_mode, false)
	set_vsync(vsync, false)
	set_anti_aliasing(anti_aliasing, false)
	set_anisotropic(anisotropic_index, false)
	set_max_fps(max_fps_index, false)
	set_shadow_quality(shadow_quality_index, false)
	set_grass_setting(grass_quality_setting, false)
	apply_fsr_settings()

func save_settings():
	var config = ConfigFile.new()
	config.load(SETTINGS_FILE)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("display", "show_fps", show_fps)
	config.set_value("display", "window_mode", window_mode)
	config.set_value("display", "resolution_index", resolution_index)
	config.set_value("display", "vsync", vsync)
	config.set_value("display", "anti_aliasing", anti_aliasing)
	config.set_value("graphics", "shadows_enabled", shadows_enabled)
	config.set_value("graphics", "shadow_quality_index", shadow_quality_index)
	config.set_value("graphics", "grass_quality_setting", grass_quality_setting)
	config.set_value("graphics", "grass_quality_index", grass_quality_index)
	config.set_value("graphics", "render_scale_index", render_scale_index)
	config.set_value("graphics", "renderer_method", renderer_method)
	config.set_value("graphics", "scaling_3d_mode_index", scaling_3d_mode_index)
	config.set_value("graphics", "fsr_sharpness", fsr_sharpness)
	config.set_value("graphics", "anisotropic_index", anisotropic_index)
	config.set_value("graphics", "max_fps_index", max_fps_index)
	config.set_value("gameplay", "use_isometric_camera", use_isometric_camera)
	config.save(SETTINGS_FILE)

func _shuffle_array(arr: Array) -> void:
	if arr.size() <= 1:
		return
	for i in range(arr.size() - 1, 0, -1):
		var j = _music_rng.randi_range(0, i)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp

func _refill_and_shuffle_queue() -> void:
	if loaded_playlist.is_empty():
		_playback_queue.clear()
		return
	_playback_queue = loaded_playlist.duplicate()
	_shuffle_array(_playback_queue)
	if _last_played_stream != null and _playback_queue.size() > 1 and _playback_queue[0] == _last_played_stream:
		var swap_idx = _music_rng.randi_range(1, _playback_queue.size() - 1)
		var temp = _playback_queue[0]
		_playback_queue[0] = _playback_queue[swap_idx]
		_playback_queue[swap_idx] = temp

func _load_playlist(folder: String = music_folder):
	playlist.clear()
	loaded_playlist.clear()
	_playback_queue.clear()
	current_track_index = -1
	var dir = DirAccess.open(folder)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var clean_name = file_name.trim_suffix(".import").trim_suffix(".remap")
				if clean_name.ends_with(".mp3") or clean_name.ends_with(".wav") or clean_name.ends_with(".ogg"):
					var file_path = folder.path_join(clean_name)
					if not playlist.has(file_path):
						var stream = load(file_path)
						if stream:
							playlist.append(file_path)
							loaded_playlist.append(stream)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	_refill_and_shuffle_queue()

func load_playlist_for_level(scene_path: String):
	var path_lower := scene_path.to_lower()
	if path_lower.is_empty():
		var level = get_tree().get_first_node_in_group("level")
		if level:
			path_lower = (level.scene_file_path + " " + level.name).to_lower()

	# Determine the category / level key
	var level_key := "root"
	if path_lower.contains("bloombay") or path_lower.contains("dune") or path_lower.contains("beach"):
		level_key = "beach"
	elif path_lower.contains("pinecrest"):
		level_key = "pinecrest"
	elif path_lower.contains("frost") or path_lower.contains("snow"):
		level_key = "frost"
	elif path_lower.contains("mountain") or path_lower.contains("wadi"):
		level_key = "mountain"
	elif path_lower.contains("canyon"):
		level_key = "canyon"
	elif path_lower.contains("city") or path_lower.contains("harbor"):
		level_key = "city"
	elif path_lower.contains("festival") or path_lower.contains("meadow") or path_lower.ends_with("/level.tscn"):
		level_key = "festival"

	# If the same stage/playlist category is already loaded and active, don't re-read files from disk;
	# keep playing from the remaining non-repeating shuffle bag!
	if level_key == _current_level_key and not loaded_playlist.is_empty():
		return

	_current_level_key = level_key
	playlist.clear()
	loaded_playlist.clear()
	_playback_queue.clear()
	current_track_index = -1

	# Bloombay Dunes: strictly only play music from music/beach/.
	if level_key == "beach":
		var level_folder = music_folder + "beach/"
		var dir = DirAccess.open(level_folder)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					var clean_name = file_name.trim_suffix(".import").trim_suffix(".remap")
					if clean_name.ends_with(".mp3") or clean_name.ends_with(".wav") or clean_name.ends_with(".ogg"):
						var file_path = level_folder.path_join(clean_name)
						if not playlist.has(file_path):
							var stream = load(file_path)
							if stream:
								playlist.append(file_path)
								loaded_playlist.append(stream)
				file_name = dir.get_next()
			dir.list_dir_end()
		if loaded_playlist.is_empty():
			var beach_tracks := [
				"res://music/beach/High_Tide_Chase.mp3",
				"res://music/beach/Salt_Spray_Sprint.mp3",
				"res://music/beach/Sun_Baked_Drift.mp3"
			]
			for track_path in beach_tracks:
				var stream = load(track_path)
				if stream and not playlist.has(track_path):
					playlist.append(track_path)
					loaded_playlist.append(stream)
		_refill_and_shuffle_queue()
		return

	# Pinecrest Ridge: strictly only play dedicated Pinecrest music track.
	if level_key == "pinecrest":
		var level_folder = music_folder + "pinecrest/"
		var dir = DirAccess.open(level_folder)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					var clean_name = file_name.trim_suffix(".import").trim_suffix(".remap")
					if clean_name.ends_with(".mp3") or clean_name.ends_with(".wav") or clean_name.ends_with(".ogg"):
						var file_path = level_folder.path_join(clean_name)
						if not playlist.has(file_path):
							var stream = load(file_path)
							if stream:
								playlist.append(file_path)
								loaded_playlist.append(stream)
				file_name = dir.get_next()
			dir.list_dir_end()
		if loaded_playlist.is_empty():
			var pinecrest_track := "res://music/pinecrest/Where_the_Canopy_Thins.mp3"
			var stream = load(pinecrest_track)
			if stream:
				playlist.append(pinecrest_track)
				loaded_playlist.append(stream)
		_refill_and_shuffle_queue()
		return

	# Frostpeak Creek: strictly only play music from music/frost/.
	if level_key == "frost":
		var level_folder = music_folder + "frost/"
		var dir = DirAccess.open(level_folder)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					var clean_name = file_name.trim_suffix(".import").trim_suffix(".remap")
					if clean_name.ends_with(".mp3") or clean_name.ends_with(".wav") or clean_name.ends_with(".ogg"):
						var file_path = level_folder.path_join(clean_name)
						if not playlist.has(file_path):
							var stream = load(file_path)
							if stream:
								playlist.append(file_path)
								loaded_playlist.append(stream)
				file_name = dir.get_next()
			dir.list_dir_end()
		if loaded_playlist.is_empty():
			var frost_tracks := [
				"res://music/frost/Beneath_the_Glacier.mp3",
				"res://music/frost/First_Light_on_the_Ridge.mp3",
				"res://music/frost/Summit_Drift.mp3"
			]
			for track_path in frost_tracks:
				var stream = load(track_path)
				if stream and not playlist.has(track_path):
					playlist.append(track_path)
					loaded_playlist.append(stream)
		_refill_and_shuffle_queue()
		return

	# Lakeside Meadow / Lakehill: combine festival tracks with original root stage tracks!
	if level_key == "festival":
		# 1. Festival tracks
		var fest_folder = music_folder + "festival/"
		var dir_fest = DirAccess.open(fest_folder)
		if dir_fest:
			dir_fest.list_dir_begin()
			var file_name = dir_fest.get_next()
			while file_name != "":
				if not dir_fest.current_is_dir():
					var clean_name = file_name.trim_suffix(".import").trim_suffix(".remap")
					if clean_name.ends_with(".mp3") or clean_name.ends_with(".wav") or clean_name.ends_with(".ogg"):
						var file_path = fest_folder.path_join(clean_name)
						if not playlist.has(file_path):
							var stream = load(file_path)
							if stream:
								playlist.append(file_path)
								loaded_playlist.append(stream)
				file_name = dir_fest.get_next()
			dir_fest.list_dir_end()
		if loaded_playlist.is_empty():
			var festival_tracks := [
				"res://music/festival/Gold_on_the_Cobblestone.mp3",
				"res://music/festival/Main_Stage_Sunset.mp3",
				"res://music/festival/Midday_Main_Stage.mp3"
			]
			for track_path in festival_tracks:
				var stream = load(track_path)
				if stream and not playlist.has(track_path):
					playlist.append(track_path)
					loaded_playlist.append(stream)

		# 2. Original root tracks from music/
		var dir_root = DirAccess.open(music_folder)
		var added_root_count := 0
		if dir_root:
			dir_root.list_dir_begin()
			var file_name = dir_root.get_next()
			while file_name != "":
				if not dir_root.current_is_dir():
					var clean_name = file_name.trim_suffix(".import").trim_suffix(".remap")
					if clean_name.ends_with(".mp3") or clean_name.ends_with(".wav") or clean_name.ends_with(".ogg"):
						var file_path = music_folder.path_join(clean_name)
						if not playlist.has(file_path):
							var stream = load(file_path)
							if stream:
								playlist.append(file_path)
								loaded_playlist.append(stream)
								added_root_count += 1
				file_name = dir_root.get_next()
			dir_root.list_dir_end()
		if added_root_count == 0:
			var root_tracks := [
				"res://music/ComfyUI_00006_.mp3",
				"res://music/ComfyUI_00012_.mp3",
				"res://music/ComfyUI_00016_.mp3",
				"res://music/ComfyUI_00022_.mp3",
				"res://music/ComfyUI_00023_.mp3",
				"res://music/ComfyUI_00041_.mp3",
				"res://music/ComfyUI_00042_.mp3",
				"res://music/ComfyUI_00044_.mp3"
			]
			for track_path in root_tracks:
				if not playlist.has(track_path):
					var stream = load(track_path)
					if stream:
						playlist.append(track_path)
						loaded_playlist.append(stream)

		_refill_and_shuffle_queue()
		return

	# Level subfolders for mountain, canyon, city
	var subfolder := ""
	if level_key == "mountain":
		subfolder = music_folder + "mountain/"
	elif level_key == "canyon":
		subfolder = music_folder + "canyon/"
	elif level_key == "city":
		subfolder = music_folder + "city/"

	if subfolder != "" and DirAccess.open(subfolder) != null:
		_load_playlist(subfolder)
		if not loaded_playlist.is_empty():
			return

	# Fallback: load from root music folder
	_load_playlist(music_folder)

func play_race_music(force_new: bool = false):
	if force_new or active_player == null or not active_player.playing or not loaded_playlist.has(active_player.stream):
		play_next()

func play_next():
	if loaded_playlist.is_empty():
		return
	if active_player == null or inactive_player == null:
		return
		
	if _playback_queue.is_empty():
		_refill_and_shuffle_queue()
		
	if _playback_queue.is_empty():
		return
		
	var stream: AudioStream = _playback_queue.pop_front()
	_last_played_stream = stream
	current_track_index = loaded_playlist.find(stream)
	
	if stream:
		var prev_active = active_player
		active_player = inactive_player
		inactive_player = prev_active
		
		active_player.stream = stream
		active_player.volume_db = -80.0
		if not active_player.is_inside_tree():
			return
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
	set_process(show_fps or grass_quality_setting == 0)
	if save: save_settings()

func get_render_scale() -> float:
	if render_scale_index < 0 or render_scale_index >= RENDER_SCALES.size():
		return 0.75
	return RENDER_SCALES[render_scale_index]

func _apply_render_scale_to_viewport(base_scale: float = 1.0) -> void:
	var vp = get_viewport()
	if vp:
		vp.scaling_3d_scale = clamp(base_scale * get_render_scale(), 0.25, 2.0)

func set_resolution(index: int, save: bool = true):
	if index < 0 or index >= RESOLUTIONS.size():
		return
	resolution_index = index
	var target_size = RESOLUTIONS[index]
	
	var win = get_window()
	# Keep UI design scale size constant at 1080p so UI size doesn't change relative to screen
	win.content_scale_size = Vector2i(1920, 1080)
	
	if win.mode == Window.MODE_FULLSCREEN:
		# Scale 3D rendering resolution relative to native screen size, then quality scale
		var screen_size = DisplayServer.screen_get_size(win.current_screen)
		var render_scale = float(target_size.y) / float(screen_size.y)
		_apply_render_scale_to_viewport(render_scale)
	else:
		win.size = target_size
		_apply_render_scale_to_viewport(1.0)
		var screen_id = win.current_screen
		var screen_size = DisplayServer.screen_get_size(screen_id)
		win.position = (screen_size - target_size) / 2
	
	if save: save_settings()

func set_window_mode(mode: int, save: bool = true):
	window_mode = mode
	var win = get_window()
	var target_size = RESOLUTIONS[resolution_index]
	
	win.content_scale_size = Vector2i(1920, 1080)
	
	if mode == 1:
		win.mode = Window.MODE_FULLSCREEN
		var screen_size = DisplayServer.screen_get_size(win.current_screen)
		var render_scale = float(target_size.y) / float(screen_size.y)
		_apply_render_scale_to_viewport(render_scale)
	else:
		win.mode = Window.MODE_WINDOWED
		win.size = target_size
		_apply_render_scale_to_viewport(1.0)
		var screen_id = win.current_screen
		var screen_size = DisplayServer.screen_get_size(screen_id)
		win.position = (screen_size - target_size) / 2
	if save: save_settings()

func set_vsync(enabled: bool, save: bool = true):
	vsync = enabled
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	if save: save_settings()

func set_anti_aliasing(index: int, save: bool = true):
	anti_aliasing = index
	var vp = get_viewport()
	if vp:
		match index:
			0: # Disabled
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			1: # 2x MSAA
				vp.msaa_3d = Viewport.MSAA_2X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			2: # 4x MSAA
				vp.msaa_3d = Viewport.MSAA_4X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			3: # 8x MSAA
				vp.msaa_3d = Viewport.MSAA_8X
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			4: # FXAA
				vp.msaa_3d = Viewport.MSAA_DISABLED
				vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if save: save_settings()

func set_render_scale(index: int, save: bool = true):
	if index < 0 or index >= RENDER_SCALES.size():
		return
	render_scale_index = index
	# Re-apply current window/resolution so base scale * quality scale is correct
	set_resolution(resolution_index, false)
	apply_fsr_settings()
	if save: save_settings()


func get_current_rendering_method() -> String:
	var method := ""
	if RenderingServer.has_method("get_current_rendering_method"):
		method = str(RenderingServer.call("get_current_rendering_method"))
	if method.is_empty():
		method = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "mobile"))
	if method != "mobile" and method != "forward_plus":
		return "mobile"
	return method


func is_forward_plus() -> bool:
	return get_current_rendering_method() == "forward_plus"


func set_renderer_method(method: String, save: bool = true) -> void:
	if method != "mobile" and method != "forward_plus":
		return
	renderer_method = method
	if save:
		save_settings()


func set_scaling_3d_mode(index: int, save: bool = true) -> void:
	scaling_3d_mode_index = clampi(index, 0, 2)
	apply_fsr_settings()
	if save:
		save_settings()


func set_fsr_sharpness(value: float, save: bool = true) -> void:
	fsr_sharpness = clampf(value, 0.0, 2.0)
	apply_fsr_settings()
	if save:
		save_settings()


func apply_fsr_settings() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	if is_forward_plus():
		vp.scaling_3d_mode = scaling_3d_mode_index
		vp.fsr_sharpness = fsr_sharpness
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR


func _cmdline_has_rendering_method() -> bool:
	for arg in OS.get_cmdline_args():
		var a := str(arg)
		if a == "--rendering-method" or a.begins_with("--rendering-method="):
			return true
	return false


func _should_restart_for_renderer() -> bool:
	if OS.has_feature("headless"):
		return false
	# Editor Play sessions always start with project.godot's renderer.
	# Quitting here closes the game after the menu appears, with no error.
	if OS.has_feature("editor"):
		return false
	if renderer_method != "mobile" and renderer_method != "forward_plus":
		return false
	if renderer_method == get_current_rendering_method():
		return false
	# Already launched with an override — do not loop if it failed to apply.
	if _cmdline_has_rendering_method():
		return false
	return true


func _project_root_path() -> String:
	var p := ProjectSettings.globalize_path("res://")
	while p.ends_with("/") or p.ends_with("\\"):
		p = p.substr(0, p.length() - 1)
	return p


func _renderer_restart_args(method: String) -> PackedStringArray:
	var args := PackedStringArray()
	if OS.has_feature("editor"):
		# Fresh game process — do not reuse --remote-debug / --editor-pid.
		args.append("--path")
		args.append(_project_root_path())
		args.append("--rendering-method")
		args.append(method)
		args.append(str(ProjectSettings.get_setting("application/run/main_scene", "res://Main.tscn")))
		return args
	args.append("--rendering-method")
	args.append(method)
	return args


func restart_with_renderer(method: String) -> void:
	if method != "mobile" and method != "forward_plus":
		return
	var args := _renderer_restart_args(method)
	print("Restarting with renderer '%s' args=%s" % [method, str(args)])
	if OS.has_feature("editor"):
		var pid := OS.create_instance(args)
		if pid < 0:
			push_error("Could not start a new game instance with renderer '%s'." % method)
			return
		get_tree().quit()
		return
	OS.set_restart_on_exit(true, args)
	get_tree().quit()

func set_anisotropic(index: int, save: bool = true):
	if index < 0 or index >= ANISOTROPIC_LEVELS.size():
		return
	anisotropic_index = index
	var level = ANISOTROPIC_LEVELS[index]
	# ProjectSettings keys map to Viewport/texture defaults at runtime via RenderingServer
	match level:
		0:
			ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", 0)
		2:
			ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", 1)
		4:
			ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", 2)
		8:
			ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", 3)
		16:
			ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", 4)
		_:
			ProjectSettings.set_setting("rendering/textures/default_filters/anisotropic_filtering_level", 1)
	if save: save_settings()

func set_max_fps(index: int, save: bool = true):
	if index < 0 or index >= MAX_FPS_VALUES.size():
		return
	max_fps_index = index
	Engine.max_fps = MAX_FPS_VALUES[index]
	if save: save_settings()

func set_use_isometric_camera(enabled: bool, save: bool = true) -> void:
	if use_isometric_camera == enabled:
		return
	use_isometric_camera = enabled
	camera_mode_changed.emit(use_isometric_camera)
	if save:
		save_settings()


func set_shadows_enabled(enabled: bool, save: bool = true):
	# Back-compat: toggle maps to Off vs Medium
	set_shadow_quality(2 if enabled else 0, save)


func set_shadow_quality(index: int, save: bool = true) -> void:
	shadow_quality_index = clampi(index, 0, 3)
	shadows_enabled = shadow_quality_index > 0
	_apply_shadow_quality_global()
	_apply_shadows_to_tree(get_tree().root if get_tree() else null)
	if get_tree():
		get_tree().call_group("player_carts", "apply_shadow_setting", shadows_enabled)
	if save:
		save_settings()


func _apply_shadow_quality_global() -> void:
	var q: int = shadow_quality_index
	var atlas: int = SHADOW_ATLAS_SIZES[q] if q > 0 else SHADOW_ATLAS_SIZES[0]
	# Runtime atlas + soft filter (mobile renderer respects these)
	RenderingServer.directional_shadow_atlas_set_size(atlas, true)
	var soft_q: int = RenderingServer.SHADOW_QUALITY_HARD
	match q:
		0, 1:
			soft_q = RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW if q == 1 else RenderingServer.SHADOW_QUALITY_HARD
		2:
			soft_q = RenderingServer.SHADOW_QUALITY_SOFT_LOW
		3:
			soft_q = RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM
	RenderingServer.directional_soft_shadow_filter_set_quality(soft_q)
	var vp := get_viewport()
	if vp:
		vp.positional_shadow_atlas_size = atlas if q > 0 else 512


func _apply_shadows_to_tree(node: Node) -> void:
	if node == null:
		return
	var enabled: bool = shadows_enabled
	var q: int = shadow_quality_index
	if node is DirectionalLight3D:
		var dl := node as DirectionalLight3D
		dl.shadow_enabled = enabled
		if enabled:
			# Near-field quality for cars: more splits + sane max distance
			if q >= 3:
				dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			elif q == 2:
				dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			else:
				dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			dl.directional_shadow_max_distance = SHADOW_MAX_DISTANCES[q]
			dl.directional_shadow_blend_splits = true
			dl.directional_shadow_fade_start = 0.7
			dl.shadow_blur = SHADOW_BLURS[q]
			# Sane shadow bias + normal bias eliminates self-shadow acne and checkerboard
			# dither patterns on terrain hills while maintaining tight vehicle contact shadows.
			dl.shadow_bias = 0.04 if q <= 1 else 0.035
			dl.shadow_normal_bias = 2.4 if q <= 1 else 2.0
			dl.directional_shadow_pancake_size = 15.0
	elif node is OmniLight3D:
		(node as OmniLight3D).shadow_enabled = enabled and q >= 2
	elif node is SpotLight3D:
		(node as SpotLight3D).shadow_enabled = enabled and q >= 2
	for child in node.get_children():
		_apply_shadows_to_tree(child)

func set_grass_setting(setting_idx: int, save: bool = true) -> void:
	grass_quality_setting = clampi(setting_idx, 0, 5)
	_low_fps_duration = 0.0
	_auto_grass_warmup = 3.0
	if grass_quality_setting == 0:
		# Auto: start at Ultra (4), will drop to Low (1) if framerate < 60 FPS
		set_grass_quality(4, false)
	else:
		# Manual: 1: Off (0), 2: Low (1), 3: Medium (2), 4: High (3), 5: Ultra (4)
		set_grass_quality(grass_quality_setting - 1, false)
	set_process(show_fps or grass_quality_setting == 0)
	if save:
		save_settings()

func set_grass_quality(index: int, save: bool = true) -> void:
	grass_quality_index = clampi(index, 0, 4)
	if is_inside_tree() and get_tree():
		_apply_grass_quality_to_tree(get_tree().root)
	if save:
		save_settings()

func _check_auto_grass_quality(delta: float) -> void:
	if grass_quality_setting != 0:
		return
	# Already at Low (1) or Off (0); no need to downgrade
	if grass_quality_index <= 1:
		return
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	# Only evaluate during active gameplay when carts exist
	var carts := tree.get_nodes_in_group("player_carts")
	if carts.is_empty():
		_low_fps_duration = 0.0
		return
	
	# Wait out initial track loading / scene spawn hitches
	if _auto_grass_warmup > 0.0:
		_auto_grass_warmup -= delta
		return
	
	var fps := Engine.get_frames_per_second()
	if fps < 60:
		_low_fps_duration += delta
		if _low_fps_duration >= 1.0:
			_set_auto_grass_low()
	else:
		_low_fps_duration = maxf(0.0, _low_fps_duration - delta)

func _set_auto_grass_low() -> void:
	if grass_quality_index == 1:
		return
	print("[MusicManager] Auto grass: Framerate below 60 FPS (%d FPS). Setting grass shader to Low." % Engine.get_frames_per_second())
	set_grass_quality(1, false)

func _apply_grass_quality_to_tree(node: Node) -> void:
	if node == null:
		return
	var q: int = grass_quality_index
	var density: float = GRASS_DENSITIES[q]
	var max_dist: float = GRASS_DISTANCES[q]
	var fade_r: float = GRASS_FADE_RANGES[q]

	if node.name == "GrassContainer":
		if node is Node3D:
			(node as Node3D).visible = (q > 0)
		if q > 0:
			for child in node.get_children():
				if child is MultiMeshInstance3D:
					var mmi := child as MultiMeshInstance3D
					mmi.visible = true
					mmi.visibility_range_end = max_dist
					mmi.visibility_range_end_margin = 35.0
					mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
					if mmi.multimesh:
						var total_count: int = mmi.multimesh.instance_count
						var visible_count: int = int(round(total_count * density))
						if visible_count >= total_count:
							mmi.multimesh.visible_instance_count = -1
						else:
							mmi.multimesh.visible_instance_count = max(1, visible_count)
					if mmi.material_override is ShaderMaterial:
						var sm := mmi.material_override as ShaderMaterial
						sm.set_shader_parameter("max_dist", max_dist)
						sm.set_shader_parameter("fade_r", fade_r)
		return

	if node.name == "VegetationContainer":
		for child in node.get_children():
			if child is MultiMeshInstance3D:
				var mmi := child as MultiMeshInstance3D
				var nname := mmi.name.to_lower()
				if "flower" in nname or "grass" in nname:
					mmi.visible = (q > 0)
					if q > 0:
						mmi.visibility_range_end = max_dist
						mmi.visibility_range_end_margin = 35.0
						mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
						if mmi.multimesh:
							var total_count: int = mmi.multimesh.instance_count
							var visible_count: int = int(round(total_count * density))
							if visible_count >= total_count:
								mmi.multimesh.visible_instance_count = -1
							else:
								mmi.multimesh.visible_instance_count = max(1, visible_count)
						if mmi.material_override is ShaderMaterial:
							var sm := mmi.material_override as ShaderMaterial
							sm.set_shader_parameter("max_dist", max_dist)
							sm.set_shader_parameter("fade_r", fade_r)

	for child in node.get_children():
		_apply_grass_quality_to_tree(child)

## Call after a level is spawned so lights and grass pick up current settings.
func refresh_level_graphics() -> void:
	set_shadow_quality(shadow_quality_index, false)
	if grass_quality_setting == 0:
		_low_fps_duration = 0.0
		_auto_grass_warmup = 3.0
		set_grass_quality(4, false)
	else:
		set_grass_quality(grass_quality_index, false)
	set_anisotropic(anisotropic_index, false)
	# Re-apply render scale in case a new viewport path was created
	set_resolution(resolution_index, false)
	apply_fsr_settings()

const CUSTOM_ACTIONS = [
	"p1_throttle", "p1_brake", "p1_steer_left", "p1_steer_right", "p1_boost", "p1_discard_item", "p1_respawn", "p1_toggle_camera",
	"p2_throttle", "p2_brake", "p2_steer_left", "p2_steer_right", "p2_boost", "p2_discard_item", "p2_respawn", "p2_toggle_camera"
]

func _ensure_custom_actions():
	for action in CUSTOM_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

func _get_default_action_event(action: String) -> InputEvent:
	match action:
		"p1_throttle":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_W
			return ev
		"p1_brake":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_S
			return ev
		"p1_steer_left":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_A
			return ev
		"p1_steer_right":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_D
			return ev
		"p1_boost":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_SPACE
			return ev
		"p1_discard_item":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_Q
			return ev
		"p1_respawn":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_R
			return ev
		"p1_toggle_camera":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_C
			return ev
			
		"p2_throttle":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_UP
			return ev
		"p2_brake":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_DOWN
			return ev
		"p2_steer_left":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_LEFT
			return ev
		"p2_steer_right":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_RIGHT
			return ev
		"p2_boost":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_KP_0
			return ev
		"p2_discard_item":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_BACKSPACE
			return ev
		"p2_respawn":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_BACKSLASH
			return ev
		"p2_toggle_camera":
			var ev = InputEventKey.new()
			ev.physical_keycode = KEY_P
			return ev
	return null

func serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "keycode": event.physical_keycode}
	elif event is InputEventJoypadButton:
		return {"type": "joy_button", "device": event.device, "button_index": event.button_index}
	elif event is InputEventJoypadMotion:
		return {"type": "joy_motion", "device": event.device, "axis": event.axis, "axis_value": event.axis_value}
	return {}

func deserialize_event(dict: Dictionary) -> InputEvent:
	if not dict or not dict.has("type"): return null
	match dict["type"]:
		"key":
			var ev = InputEventKey.new()
			ev.physical_keycode = dict["keycode"]
			return ev
		"joy_button":
			var ev = InputEventJoypadButton.new()
			ev.device = dict.get("device", 0)
			ev.button_index = dict["button_index"]
			return ev
		"joy_motion":
			var ev = InputEventJoypadMotion.new()
			ev.device = dict.get("device", 0)
			ev.axis = dict["axis"]
			ev.axis_value = dict.get("axis_value", 1.0)
			return ev
	return null

func load_input_settings():
	_ensure_custom_actions()
	var config = ConfigFile.new()
	var has_config = config.load(SETTINGS_FILE) == OK
	
	for action in CUSTOM_ACTIONS:
		InputMap.action_erase_events(action)
		var applied = false
		if has_config and config.has_section_key("input_v2", action):
			var data = config.get_value("input_v2", action)
			var event = deserialize_event(data)
			if event:
				InputMap.action_add_event(action, event)
				applied = true
		
		if not applied:
			var default_event = _get_default_action_event(action)
			if default_event:
				InputMap.action_add_event(action, default_event)

func save_action_event(action_name: String, event: InputEvent):
	var config = ConfigFile.new()
	config.load(SETTINGS_FILE)
	var data = serialize_event(event)
	config.set_value("input_v2", action_name, data)
	config.save(SETTINGS_FILE)
	
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)

func get_event_friendly_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var keycode = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		return OS.get_keycode_string(keycode)
	elif event is InputEventJoypadButton:
		var btn_name = "Joy %d Button %d" % [event.device + 1, event.button_index]
		match event.button_index:
			JOY_BUTTON_A: btn_name = "Joy %d A/Cross" % (event.device + 1)
			JOY_BUTTON_B: btn_name = "Joy %d B/Circle" % (event.device + 1)
			JOY_BUTTON_X: btn_name = "Joy %d Square" % (event.device + 1)
			JOY_BUTTON_Y: btn_name = "Joy %d Triangle" % (event.device + 1)
			JOY_BUTTON_LEFT_SHOULDER: btn_name = "Joy %d LB/L1" % (event.device + 1)
			JOY_BUTTON_RIGHT_SHOULDER: btn_name = "Joy %d RB/R1" % (event.device + 1)
			JOY_BUTTON_START: btn_name = "Joy %d Start" % (event.device + 1)
			JOY_BUTTON_BACK: btn_name = "Joy %d Back/Share" % (event.device + 1)
			JOY_BUTTON_LEFT_STICK: btn_name = "Joy %d L-Stick Press" % (event.device + 1)
			JOY_BUTTON_RIGHT_STICK: btn_name = "Joy %d R-Stick Press" % (event.device + 1)
			JOY_BUTTON_DPAD_UP: btn_name = "Joy %d Dpad Up" % (event.device + 1)
			JOY_BUTTON_DPAD_DOWN: btn_name = "Joy %d Dpad Down" % (event.device + 1)
			JOY_BUTTON_DPAD_LEFT: btn_name = "Joy %d Dpad Left" % (event.device + 1)
			JOY_BUTTON_DPAD_RIGHT: btn_name = "Joy %d Dpad Right" % (event.device + 1)
		return btn_name
	elif event is InputEventJoypadMotion:
		var dir = "Pos" if event.axis_value > 0 else "Neg"
		var motion_name = "Joy %d Axis %d %s" % [event.device + 1, event.axis, dir]
		match event.axis:
			JOY_AXIS_LEFT_X:
				motion_name = ("Joy %d L-Stick Right" if event.axis_value > 0 else "Joy %d L-Stick Left") % (event.device + 1)
			JOY_AXIS_LEFT_Y:
				motion_name = ("Joy %d L-Stick Down" if event.axis_value > 0 else "Joy %d L-Stick Up") % (event.device + 1)
			JOY_AXIS_RIGHT_X:
				motion_name = ("Joy %d R-Stick Right" if event.axis_value > 0 else "Joy %d R-Stick Left") % (event.device + 1)
			JOY_AXIS_RIGHT_Y:
				motion_name = ("Joy %d R-Stick Down" if event.axis_value > 0 else "Joy %d R-Stick Up") % (event.device + 1)
			JOY_AXIS_TRIGGER_LEFT:
				motion_name = "Joy %d Left Trigger" % (event.device + 1)
			JOY_AXIS_TRIGGER_RIGHT:
				motion_name = "Joy %d Right Trigger" % (event.device + 1)
		return motion_name
	return "None"

func get_action_friendly_text(action_name: String) -> String:
	var events = InputMap.action_get_events(action_name)
	if events.size() > 0:
		return get_event_friendly_text(events[0])
	return "None"

# Stub functions to prevent compilation errors if called elsewhere
func get_action_key_text(action_name: String) -> String:
	# Fallback to checking p1 action
	return get_action_friendly_text("p1_" + action_name)

func save_action_key(action_name: String, keycode: int):
	# Fallback to saving p1 key
	var ev = InputEventKey.new()
	ev.physical_keycode = keycode
	save_action_event("p1_" + action_name, ev)

func set_default_controller_bindings(player_index: int):
	var prefix = "p1_" if player_index == 1 else "p2_"
	var dev = 0 if player_index == 1 else 1
	
	# Throttle: Right Trigger (Axis 5, positive)
	var throttle_ev = InputEventJoypadMotion.new()
	throttle_ev.device = dev
	throttle_ev.axis = JOY_AXIS_TRIGGER_RIGHT
	throttle_ev.axis_value = 1.0
	save_action_event(prefix + "throttle", throttle_ev)
	
	# Brake: Left Trigger (Axis 4, positive)
	var brake_ev = InputEventJoypadMotion.new()
	brake_ev.device = dev
	brake_ev.axis = JOY_AXIS_TRIGGER_LEFT
	brake_ev.axis_value = 1.0
	save_action_event(prefix + "brake", brake_ev)
	
	# Steer Left: Left Stick Left (Axis 0, negative)
	var steer_l_ev = InputEventJoypadMotion.new()
	steer_l_ev.device = dev
	steer_l_ev.axis = JOY_AXIS_LEFT_X
	steer_l_ev.axis_value = -1.0
	save_action_event(prefix + "steer_left", steer_l_ev)
	
	# Steer Right: Left Stick Right (Axis 0, positive)
	var steer_r_ev = InputEventJoypadMotion.new()
	steer_r_ev.device = dev
	steer_r_ev.axis = JOY_AXIS_LEFT_X
	steer_r_ev.axis_value = 1.0
	save_action_event(prefix + "steer_right", steer_r_ev)
	
	# Use Item/Boost: Button A (0)
	var boost_ev = InputEventJoypadButton.new()
	boost_ev.device = dev
	boost_ev.button_index = JOY_BUTTON_A
	save_action_event(prefix + "boost", boost_ev)
	
	# Discard Item: Button B (1)
	var discard_ev = InputEventJoypadButton.new()
	discard_ev.device = dev
	discard_ev.button_index = JOY_BUTTON_B
	save_action_event(prefix + "discard_item", discard_ev)
	
	# Respawn: Button Y (3)
	var respawn_ev = InputEventJoypadButton.new()
	respawn_ev.device = dev
	respawn_ev.button_index = JOY_BUTTON_Y
	save_action_event(prefix + "respawn", respawn_ev)
	
	# Toggle Camera: Button X (2)
	var cam_ev = InputEventJoypadButton.new()
	cam_ev.device = dev
	cam_ev.button_index = JOY_BUTTON_X
	save_action_event(prefix + "toggle_camera", cam_ev)

func set_default_keyboard_bindings(player_index: int):
	var prefix = "p1_" if player_index == 1 else "p2_"
	var keys = ["throttle", "brake", "steer_left", "steer_right", "boost", "discard_item", "respawn", "toggle_camera"]
	for suffix in keys:
		var action = prefix + suffix
		var default_event = _get_default_action_event(action)
		if default_event:
			save_action_event(action, default_event)

func stop_music():
	if active_player:
		active_player.stop()
	if inactive_player:
		inactive_player.stop()

func _preload_sfx() -> void:
	for path in SFX_PRELOAD_PATHS:
		_cached_sfx(path)


func _cached_sfx(path: String) -> AudioStream:
	if _sfx_cache.has(path):
		return _sfx_cache[path]
	var stream: AudioStream = load(path)
	_sfx_cache[path] = stream
	return stream


func play_sfx(stream_or_path: Variant, volume_db: float = 0.0, pitch_scale: float = 1.0):
	var ap = AudioStreamPlayer.new()
	ap.bus = &"SFX"
	ap.volume_db = volume_db
	ap.pitch_scale = pitch_scale
	if stream_or_path is String:
		ap.stream = _cached_sfx(stream_or_path)
	else:
		ap.stream = stream_or_path
	add_child(ap)
	ap.play()
	ap.finished.connect(ap.queue_free)


## Single short race-start beep (not a multi-beep sample). is_go = higher/longer final tone.
func play_race_start_beep(is_go: bool = false) -> void:
	var freq: float = 1320.0 if is_go else 880.0
	var duration: float = 0.28 if is_go else 0.11
	var volume_db: float = -4.0 if is_go else -8.0
	play_sfx(_make_beep_stream(freq, duration), volume_db, 1.0)


func _make_beep_stream(freq_hz: float, duration_sec: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration_sec)
	if count < 2:
		count = 2
	var data := PackedByteArray()
	data.resize(count * 2)
	var attack := 0.008
	var release := 0.025
	for i in range(count):
		var t := float(i) / float(sample_rate)
		var env := 1.0
		if t < attack:
			env = t / attack
		elif t > duration_sec - release:
			env = maxf(0.0, (duration_sec - t) / release)
		var sample := int(sin(t * freq_hz * TAU) * 0.35 * env * 32767.0)
		# little-endian int16
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
