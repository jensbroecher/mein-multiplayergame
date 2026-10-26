extends Node

const LEVEL_SCENE = preload("res://levels/LakesideLevel.tscn")
const CONFIGURATION_MENU_SCENE = preload("res://ConfigurationMenu.tscn")
const PAUSE_MENU_SCENE = preload("res://PauseMenu.tscn")
const LOADING_SCREEN_SCENE = preload("res://LoadingScreen.tscn")
const PODIUM_SCENE = preload("res://Podium.tscn")
const SCREEN_TRANSITION_SCRIPT = preload("res://ScreenTransition.gd")
const SPLASH_SCREEN_SCENE = preload("res://SplashScreen.tscn")
const SPLASH_SCREEN_SCRIPT = preload("res://SplashScreen.gd")

@onready var lobby = $Lobby
@onready var main_menu = $MainMenu
@onready var car_selection = $CarSelection

var configuration_menu
var pause_menu
var loading_screen
var screen_transition: CanvasLayer
var podium: Control

var _coop_p1_car: int = 0
var _coop_selecting_p2: bool = false
const QUIT_FADE_TIME := 0.6
const QUIT_SOUND_TIME := 0.5

var _level_swap_in_progress: bool = false

func _ready():
	_apply_platform_performance()
	main_menu.start_pressed.connect(_on_menu_start_pressed)
	main_menu.options_pressed.connect(_on_menu_options_pressed)
	main_menu.quit_pressed.connect(_on_menu_quit_pressed)
	car_selection.car_selected.connect(_on_car_selected)
	car_selection.back_requested.connect(_on_car_selection_back)
	NetworkManager.server_disconnected.connect(_on_server_disconnected)
	
	lobby.start_race_requested.connect(_on_lobby_start_race_requested)
	lobby.back_to_menu_requested.connect(_on_lobby_back_to_menu_requested)
	lobby.change_car_requested.connect(_on_lobby_change_car_requested)
	NetworkManager.stage_voting_concluded.connect(_on_stage_voting_concluded)
	
	var config_canvas = CanvasLayer.new()
	config_canvas.name = "ConfigCanvas"
	config_canvas.layer = 10
	add_child(config_canvas)
	
	configuration_menu = CONFIGURATION_MENU_SCENE.instantiate()
	configuration_menu.visible = false
	config_canvas.add_child(configuration_menu)
	configuration_menu.back_pressed.connect(_on_options_back_pressed)
	
	var pause_canvas = CanvasLayer.new()
	pause_canvas.name = "PauseCanvas"
	pause_canvas.layer = 11
	add_child(pause_canvas)
	
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.visible = false
	pause_canvas.add_child(pause_menu)

	loading_screen = LOADING_SCREEN_SCENE.instantiate()
	add_child(loading_screen)

	screen_transition = SCREEN_TRANSITION_SCRIPT.new()
	screen_transition.name = "ScreenTransition"
	add_child(screen_transition)

	if SPLASH_SCREEN_SCRIPT.should_play(self):
		_play_splash()


## The title card the game opens with, over the menu (SplashScreen.gd: the 3D logo and some of the cars).
## Any key skips it; when it is over a swipe takes its place with the menu. Once a launch, and only when
## Main is the running scene, not a test that has instantiated it (SplashScreen.should_play).
func _play_splash() -> void:
	main_menu.hide()
	var canvas := CanvasLayer.new()
	canvas.name = "SplashCanvas"
	# Over the menus and the loading screen (100), under the swipe (120) that takes it away.
	canvas.layer = 105
	add_child(canvas)
	var splash := SPLASH_SCREEN_SCENE.instantiate()
	canvas.add_child(splash)
	await splash.finished
	await _swipe(func():
		canvas.queue_free()
		main_menu.show())


func _apply_platform_performance() -> void:
	# Same physics cadence on phone and PC so LAN multiplayer stays in sync.
	# Graphics (scale, shadows, FPS cap) come from MusicManager settings / options menu.
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 4

## Changes screens behind a swipe: the panel covers the screen, `change` runs, the panel sweeps away.
## A swipe asked for while another is under way is dropped (a double click).
func _swipe(change: Callable) -> void:
	if screen_transition.busy:
		return
	await screen_transition.cover()
	await change.call()
	await screen_transition.reveal()

## Fades to black and gives the button sound time to finish before the app closes.
func _on_menu_quit_pressed() -> void:
	if screen_transition.busy:
		return
	await screen_transition.fade_to_black(QUIT_FADE_TIME)
	await get_tree().create_timer(QUIT_SOUND_TIME, true, false, true).timeout
	get_tree().quit()

func _on_menu_start_pressed():
	if NetworkManager.current_game_mode == NetworkManager.GameMode.SPECTATOR:
		if NetworkManager.inspect_mode:
			NetworkManager.start_inspect()
		else:
			NetworkManager.start_spectator()
		await start_game(true)
		return
	await _swipe(func():
		main_menu.hide()
		car_selection.show())

func _on_menu_options_pressed():
	await _swipe(func():
		main_menu.hide()
		configuration_menu.show())


func _on_options_back_pressed() -> void:
	await _swipe(func():
		configuration_menu.hide()
		main_menu.show())

func _on_car_selected(car_index: int):
	# Confirm pressed again while the screen is swiping away.
	if screen_transition.busy:
		return
	# If changing car while already inside the multiplayer lobby room:
	if lobby.visible or lobby.is_in_room:
		NetworkManager.set_local_car(car_index)
		await _swipe(func():
			car_selection.hide()
			lobby.show()
			lobby.enter_room_view())
		return

	if NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP:
		if not _coop_selecting_p2:
			# P1 just selected — save their car and show selection again for P2
			_coop_p1_car = car_index
			_coop_selecting_p2 = true
			await _swipe(func(): car_selection.show_for_player(2))
		else:
			# P2 just selected — finalize both and start
			_coop_selecting_p2 = false
			NetworkManager.local_car_index = _coop_p1_car
			NetworkManager.local_p2_car_index = car_index
			
			var p_name = "Player 1"
			var config = ConfigFile.new()
			if config.load("user://settings.cfg") == OK:
				var saved_name = config.get_value("player", "name", "")
				if not saved_name.is_empty():
					p_name = saved_name
			
			var p2_name = NetworkManager.local_p2_name
			if p2_name.is_empty():
				p2_name = "Player 2"
				
			NetworkManager.start_local_coop(p_name, p2_name)
			await start_game(true)
		return
	NetworkManager.local_car_index = car_index
	if NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER:
		await _swipe(func():
			car_selection.hide()
			lobby.show()
			lobby.show_connection_view())
	else:
		# Load saved player name
		var p_name = "SoloRacer"
		var config = ConfigFile.new()
		if config.load("user://settings.cfg") == OK:
			var saved_name = config.get_value("player", "name", "")
			if not saved_name.is_empty():
				p_name = saved_name
			
		NetworkManager.start_single_player(p_name)
		await start_game(true)

## Back out of the car select screen: to player 1's pick from player 2's, to the lobby room when
## changing car there, otherwise to the menu screen it came from.
func _on_car_selection_back() -> void:
	if screen_transition.busy:
		return
	if _coop_selecting_p2:
		_coop_selecting_p2 = false
		await _swipe(func(): car_selection.show_for_player(1))
		return
	await _swipe(func():
		car_selection.hide()
		if lobby.is_in_room:
			lobby.show()
			lobby.enter_room_view()
		else:
			main_menu.show())

func _on_lobby_start_race_requested():
	if not multiplayer.is_server():
		return
	await start_game(true)

func _on_lobby_back_to_menu_requested():
	if screen_transition.busy:
		return
	NetworkManager.disconnect_peer()
	await _swipe(func():
		lobby.hide()
		main_menu.show())

func _on_lobby_change_car_requested():
	await _swipe(func():
		lobby.hide()
		car_selection.show())

func _on_stage_voting_concluded(winning_stage: String):
	if multiplayer.is_server():
		load_stage(winning_stage, "Loading voted track")
 
func start_game(is_host: bool):
	if not is_host:
		return
	await _show_loading("Loading race")
	# Whichever screen the race starts from is done with, behind the loading screen.
	main_menu.hide()
	car_selection.hide()
	lobby.hide()
	if loading_screen:
		loading_screen.set_progress(0.15)

	var level_scene = LEVEL_SCENE
	var status := "Loading race"
	if NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER:
		lobby.hide()
		if NetworkManager.multiplayer_mode == NetworkManager.MultiplayerMode.GRAND_PRIX:
			NetworkManager.current_gp_name = NetworkManager.selected_mp_cup
			NetworkManager.current_gp_stage = 0
			var gp_data = NetworkManager.get_gp_cup(NetworkManager.selected_mp_cup)
			if gp_data and gp_data["stages"].size() > 0:
				status = "Loading GP stage 1"
				level_scene = load(gp_data["stages"][0])
		else:
			status = "Loading track"
			level_scene = load(NetworkManager.current_single_stage)
	elif NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_GP \
			or (NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP and NetworkManager.is_coop_gp):
		var gp_data = NetworkManager.get_gp_cup(NetworkManager.current_gp_name)
		if gp_data:
			var stage_idx = NetworkManager.current_gp_stage
			if stage_idx < gp_data["stages"].size():
				status = "Loading stage %d" % (stage_idx + 1)
				if loading_screen:
					loading_screen.set_status(status)
				level_scene = load(gp_data["stages"][stage_idx])
	elif NetworkManager.current_game_mode == NetworkManager.GameMode.SINGLE_PLAYER_TIME_TRIAL \
			or NetworkManager.current_game_mode == NetworkManager.GameMode.LOCAL_COOP \
			or NetworkManager.current_game_mode == NetworkManager.GameMode.SPECTATOR:
		if loading_screen:
			loading_screen.set_status("Loading track")
		level_scene = load(NetworkManager.time_trial_stage)

	if loading_screen:
		loading_screen.set_progress(0.45)
	await get_tree().process_frame

	var level = level_scene.instantiate()
	if loading_screen:
		loading_screen.set_progress(0.7)
		loading_screen.set_status("Preparing track")
	add_child(level)
	# Apply shadow/quality settings to newly spawned lights & carts
	MusicManager.refresh_level_graphics()
	if loading_screen:
		loading_screen.set_progress(0.85)
		loading_screen.set_status("Building collisions")
	# Finish prop collision bake under the overlay so the first race seconds stay smooth.
	if level.has_method("wait_for_collisions"):
		await level.wait_for_collisions()
	else:
		await get_tree().process_frame
		await get_tree().process_frame
	if loading_screen:
		loading_screen.set_progress(0.98)
	await get_tree().process_frame
	await _hide_loading()
	# Clients will get the level spawned automatically by MultiplayerSpawner

## Called from RaceUI (child of Level). Must not free Level mid-callback.
func load_gp_stage(stage_idx: int) -> void:
	if _level_swap_in_progress:
		return
	call_deferred("_load_gp_stage_impl", stage_idx)

func _load_gp_stage_impl(stage_idx: int) -> void:
	if _level_swap_in_progress:
		return
	_level_swap_in_progress = true
	# Keep this coroutine alive even if something pauses the tree mid-swap.
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_menu:
		pause_menu.hide()

	await _show_loading("Loading next stage")

	# Fully drop the previous race before allocating the next (critical on Android).
	if loading_screen:
		loading_screen.set_status("Clearing previous race")
		loading_screen.set_progress(0.2)
	await _unload_all_levels()
	if loading_screen:
		loading_screen.set_status("Loading stage %d" % (stage_idx + 1))
		loading_screen.set_progress(0.4)

	var gp_data = NetworkManager.get_gp_cup(NetworkManager.current_gp_name)
	if gp_data and stage_idx < gp_data["stages"].size():
		NetworkManager.current_gp_stage = stage_idx
		var stage_path: String = gp_data["stages"][stage_idx]
		if loading_screen:
			loading_screen.set_status("Loading stage %d" % (stage_idx + 1))
			loading_screen.set_progress(0.55)
		var next_level_scene: PackedScene = load(stage_path)
		if next_level_scene == null:
			push_error("Failed to load stage: ", stage_path)
			await _hide_loading()
			_level_swap_in_progress = false
			process_mode = Node.PROCESS_MODE_INHERIT
			_on_server_disconnected()
			return
		if loading_screen:
			loading_screen.set_progress(0.75)
			loading_screen.set_status("Preparing track")
		var next_level = next_level_scene.instantiate()
		add_child(next_level)
		MusicManager.refresh_level_graphics()
		if loading_screen:
			loading_screen.set_progress(0.85)
			loading_screen.set_status("Building collisions")
		if next_level.has_method("wait_for_collisions"):
			await next_level.wait_for_collisions()
		else:
			await get_tree().process_frame
			await get_tree().process_frame
		if loading_screen:
			loading_screen.set_progress(0.98)
		await get_tree().process_frame
	else:
		# GP Finished!
		await _hide_loading()
		_level_swap_in_progress = false
		process_mode = Node.PROCESS_MODE_INHERIT
		if NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER and multiplayer.multiplayer_peer != null:
			return_to_lobby()
		else:
			_on_server_disconnected()
		return

	await _hide_loading()
	_level_swap_in_progress = false
	process_mode = Node.PROCESS_MODE_INHERIT

## The Grand Prix is over: swap the last race for the podium (every peer gets this from
## NetworkManager.gp_show_podium). `ranking` is NetworkManager.build_gp_ranking(), best first.
func show_gp_podium(cup_name: String, ranking: Array) -> void:
	call_deferred("_show_gp_podium_impl", cup_name, ranking)

func _show_gp_podium_impl(cup_name: String, ranking: Array) -> void:
	if _level_swap_in_progress or podium != null:
		return
	_level_swap_in_progress = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_menu:
		pause_menu.hide()
	await _show_loading("Preparing the podium")
	await _unload_all_levels()
	podium = PODIUM_SCENE.instantiate()
	podium.setup(cup_name, ranking)
	podium.finished.connect(_on_podium_finished)
	add_child(podium)
	# New shaders compile in the background and draw nothing until they are ready: let that happen
	# under the loading screen.
	for _i in range(45):
		await get_tree().process_frame
	await _hide_loading()
	_level_swap_in_progress = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if podium != null:
		podium.start()

func _on_podium_finished() -> void:
	_free_podium()
	MusicManager.stop_music()
	if NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER and multiplayer.multiplayer_peer != null:
		return_to_lobby()
	else:
		_on_server_disconnected()

func _free_podium() -> void:
	if podium != null and is_instance_valid(podium):
		podium.queue_free()
	podium = null


func load_stage(stage_path: String, status_title: String = "Loading stage") -> void:
	if _level_swap_in_progress:
		return
	call_deferred("_load_stage_impl", stage_path, status_title)

func _load_stage_impl(stage_path: String, status_title: String) -> void:
	if _level_swap_in_progress:
		return
	_level_swap_in_progress = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_menu:
		pause_menu.hide()

	await _show_loading(status_title)
	if loading_screen:
		loading_screen.set_status("Clearing previous race")
		loading_screen.set_progress(0.2)
	await _unload_all_levels()
	if loading_screen:
		loading_screen.set_status(status_title)
		loading_screen.set_progress(0.4)

	var next_level_scene: PackedScene = load(stage_path)
	if next_level_scene == null:
		push_error("Failed to load stage: ", stage_path)
		await _hide_loading()
		_level_swap_in_progress = false
		process_mode = Node.PROCESS_MODE_INHERIT
		_on_server_disconnected()
		return

	if loading_screen:
		loading_screen.set_progress(0.65)
		loading_screen.set_status("Preparing track")
	var next_level = next_level_scene.instantiate()
	add_child(next_level)
	MusicManager.refresh_level_graphics()
	if loading_screen:
		loading_screen.set_progress(0.85)
		loading_screen.set_status("Building collisions")
	if next_level.has_method("wait_for_collisions"):
		await next_level.wait_for_collisions()
	else:
		await get_tree().process_frame
		await get_tree().process_frame
	if loading_screen:
		loading_screen.set_progress(0.98)
	await get_tree().process_frame
	await _hide_loading()
	_level_swap_in_progress = false
	process_mode = Node.PROCESS_MODE_INHERIT

func return_to_lobby():
	call_deferred("_return_to_lobby_impl")

func _return_to_lobby_impl():
	if _level_swap_in_progress:
		return
	_level_swap_in_progress = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_menu:
		pause_menu.hide()
	await _show_loading("Returning to lobby")
	await _unload_all_levels()
	await _hide_loading()
	_level_swap_in_progress = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if NetworkManager.current_game_mode == NetworkManager.GameMode.MULTIPLAYER and multiplayer.multiplayer_peer != null:
		lobby.show()
		lobby.enter_room_view()
	else:
		_on_server_disconnected()


func _find_level_nodes() -> Array[Node]:
	var levels: Array[Node] = []
	for child in get_children():
		if child == null or not is_instance_valid(child):
			continue
		var n := str(child.name)
		if child.is_in_group("level") or n == "Level" or n.begins_with("OldLevel"):
			levels.append(child)
	return levels


## Free every active/leftover race level and yield briefly so RAM/VRAM can drop.
## Never awaits tree_exited unboundedly — that hangs if the signal already fired
## (e.g. after remove_child) or never arrives on some Android free paths.
func _unload_all_levels() -> void:
	var levels := _find_level_nodes()
	for level in levels:
		if not is_instance_valid(level):
			continue
		# Stop scripts/physics/render immediately so they don't keep allocating.
		level.process_mode = Node.PROCESS_MODE_DISABLED
		if level is Node3D:
			(level as Node3D).visible = false
		level.name = "OldLevel_%d" % level.get_instance_id()

		# Detach first so the race UI is out of the tree, then free without
		# awaiting tree_exited (remove_child already emits it → infinite hang).
		var parent := level.get_parent()
		if parent != null:
			parent.remove_child(level)
		level.queue_free()

	# Wait until freed or timeout — never block the loading screen forever.
	const MAX_WAIT_FRAMES := 45
	for _i in range(MAX_WAIT_FRAMES):
		var any_alive := false
		for level in levels:
			if is_instance_valid(level):
				any_alive = true
				break
		if not any_alive:
			break
		await get_tree().process_frame

	# Extra idle frames: Android needs a moment after free before VRAM/RAM drops.
	# Avoids (old level + new level + runtime collision bake) peak OOM.
	for _i in range(4):
		await get_tree().process_frame
	# Flush pending GPU work from the previous stage (best-effort).
	RenderingServer.force_sync()
	await get_tree().process_frame
	if MusicManager:
		MusicManager.stop_music()


## Back to the main menu from a race or the podium. Swipes round the change, unless a swipe or the
## loading screen already covers it.
func _on_server_disconnected():
	if screen_transition.busy or (loading_screen != null and loading_screen.visible):
		_return_to_menu_now()
		return
	await screen_transition.cover()
	_return_to_menu_now()
	await screen_transition.reveal()

func _return_to_menu_now():
	_free_podium()
	# Don't free mid-callback from a level UI without deferring.
	if _level_swap_in_progress:
		# Still tear down; swap flag will clear after.
		pass
	# Free any race levels (including renamed leftovers).
	for level in _find_level_nodes():
		if is_instance_valid(level):
			level.process_mode = Node.PROCESS_MODE_DISABLED
			if level.get_parent() == self:
				remove_child(level)
			level.queue_free()
	
	NetworkManager.disconnect_peer()
	
	lobby.hide()
	car_selection.hide()
	main_menu.show()
	MusicManager.stop_music()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _find_level_nodes().size() > 0:
			var focus = get_viewport().gui_get_focus_owner()
			if focus is LineEdit or focus is TextEdit:
				return
			if pause_menu.visible:
				pause_menu.hide()
			else:
				pause_menu.show_pause_menu()
			get_viewport().set_input_as_handled()

func _input(event: InputEvent):
	var toggle_pause := false
	if event.is_action_pressed("ui_cancel"):
		toggle_pause = true
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE or key_event.key_label == KEY_ESCAPE \
				or key_event.keycode == KEY_BACKSPACE or key_event.physical_keycode == KEY_BACKSPACE or key_event.key_label == KEY_BACKSPACE \
				or key_event.keycode == KEY_BACK or key_event.physical_keycode == KEY_BACK or key_event.key_label == KEY_BACK:
			toggle_pause = true
	if toggle_pause and (_find_level_nodes().size() > 0):
		# Don't steal Backspace while typing in a focused LineEdit
		var focus = get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		if pause_menu.visible:
			pause_menu.hide()
		else:
			pause_menu.show_pause_menu()
		get_viewport().set_input_as_handled()

func restart_race():
	if _level_swap_in_progress:
		return
	call_deferred("_restart_race_impl")

func _restart_race_impl() -> void:
	if _level_swap_in_progress:
		return
	_level_swap_in_progress = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_menu:
		pause_menu.hide()
	await _show_loading("Restarting race")
	if loading_screen:
		loading_screen.set_status("Clearing track")
		loading_screen.set_progress(0.25)
	await _unload_all_levels()
	# start_game shows/hides loading itself; keep flag until done
	_level_swap_in_progress = false
	process_mode = Node.PROCESS_MODE_INHERIT
	await start_game(true)


## The loading screen comes in behind the swipe's panel, which is its colour, then fades off it.
func _show_loading(message: String) -> void:
	if loading_screen == null:
		return
	if loading_screen.visible:
		# Already up (a restart loads twice): just say what's next.
		loading_screen.set_status(message)
		return
	await screen_transition.cover()
	await loading_screen.show_loading(message)
	screen_transition.fade_out()


## The panel takes over from the loading screen at once, then sweeps away to show what's under it.
func _hide_loading() -> void:
	if loading_screen == null:
		return
	await screen_transition.set_covered()
	await loading_screen.hide_loading()
	screen_transition.reveal()
