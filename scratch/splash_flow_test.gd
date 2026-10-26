extends SceneTree

# Plays the game's real start-up: Main is the running scene, so the title card plays over the menu.
# Reports what is showing when, presses a key part of the way through (or lets it run out) and checks the
# swipe to the menu. Run windowed:
#   Godot --path . --resolution 1600x900 -s res://scratch/splash_flow_test.gd -- <out_dir> [key=3.0]
# key=<seconds> presses a key then (seconds since Main is running); key=-1 lets the card play to its end
# (it takes about 21 seconds).
var _out := ""
var _key_at := 3.0
var _start := 0
var _first_frame := -1
var _pressed := false
var _pressed_at := 0.0
var _menu_seen_at := -1.0
var _splash_gone_at := -1.0
var _last_menu := false
var _last_splash := false
var _shot_a := false
var _shot_swipe := false
var _shot_menu := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	for a in args.slice(1):
		if a.begins_with("key="):
			_key_at = float(a.substr(4))
	change_scene_to_file("res://Main.tscn")
	_start = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	var main := current_scene
	if main == null or main.name != "Main":
		return false
	# Times are from the first frame Main is running (loading the project and the scene comes before).
	if _first_frame < 0:
		_first_frame = Time.get_ticks_msec()
		print("Main running %.1fs after launch" % [(_first_frame - _start) / 1000.0])
	var t := (Time.get_ticks_msec() - _first_frame) / 1000.0
	var menu: Control = main.get_node("MainMenu")
	var splash_up := main.has_node("SplashCanvas")
	if splash_up != _last_splash or menu.visible != _last_menu:
		print("%.2fs: splash %s, menu %s" % [t, "on screen" if splash_up else "gone", "visible" if menu.visible else "hidden"])
		_last_splash = splash_up
		_last_menu = menu.visible
	if not splash_up and _splash_gone_at < 0.0 and t > 0.5:
		_splash_gone_at = t
	if menu.visible and _menu_seen_at < 0.0 and not splash_up:
		_menu_seen_at = t
	if t > 1.5 and not _shot_a:
		_shot_a = true
		_save("flow_during")
	if _key_at >= 0.0 and t >= _key_at and not _pressed:
		_pressed = true
		_pressed_at = t
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		ev.physical_keycode = KEY_SPACE
		ev.pressed = true
		Input.parse_input_event(ev)
		print("%.2fs: key pressed" % t)
	if _pressed and not _shot_swipe and t >= _pressed_at + 0.2:
		_shot_swipe = true
		_save("flow_swipe")
	if _menu_seen_at >= 0.0 and not _shot_menu and t >= _menu_seen_at + 1.2:
		_shot_menu = true
		_save("flow_menu")
		print("splash gone at %.2fs, menu up at %.2fs: %s" % [_splash_gone_at, _menu_seen_at, "ok" if menu.visible else "MENU NOT VISIBLE"])
		return true
	if t > 30.0:
		print("TIMEOUT: the card never gave way to the menu")
		return true
	return false


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("SHOT ", name)
