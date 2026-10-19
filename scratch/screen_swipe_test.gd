extends Node
# Drives Main.tscn's screen changes through the swipe (ScreenTransition) and prints which screens
# are showing once each one is done: menu -> car select -> back, options and back, a double press,
# the loading cover in and out, and exit to the menu. Headless:
#   Godot --headless --path . res://scratch/screen_swipe_test.tscn

var main: Node
var fails := 0


func _ready() -> void:
	main = load("res://Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var cs: Control = main.get_node("CarSelection")
	var menu: Control = main.get_node("MainMenu")
	var lobby: Control = main.get_node("Lobby")
	var cfg: Control = main.configuration_menu
	var swipe: CanvasLayer = main.screen_transition

	_expect("start", menu.visible and not cs.visible)

	main._on_menu_start_pressed()
	await _settled()
	_expect("menu -> car select", cs.visible and not menu.visible)

	cs._on_back_pressed()
	await _settled()
	_expect("car select -> back to menu", not cs.visible and menu.visible)

	# Timed on a warm frame: the swipe is under way a frame after the press, with the old screen still
	# up, and the whole cover and reveal take about 0.85s.
	var t0 := Time.get_ticks_msec()
	main._on_menu_options_pressed()
	await get_tree().process_frame
	_expect("swipe under way a frame after the press, old screen still up", swipe.busy and menu.visible)
	await _settled()
	var took := Time.get_ticks_msec() - t0
	print("   options swipe took %d ms" % took)
	_expect("swipe lasts 0.7-1.3s", took > 700 and took < 1300)
	_expect("menu -> options", cfg.visible and not menu.visible)
	cfg._on_back_pressed()
	await _settled()
	_expect("options -> back to menu", not cfg.visible and menu.visible)

	# A second press while the first swipe is running does nothing.
	main._on_menu_start_pressed()
	main._on_menu_start_pressed()
	await _settled()
	_expect("double press: one car select", cs.visible and not menu.visible)
	cs._on_back_pressed()
	cs._on_back_pressed()
	await _settled()
	_expect("double back: one menu", not cs.visible and menu.visible)

	lobby.is_in_room = true
	main._on_lobby_change_car_requested()
	await _settled()
	_expect("lobby -> car select", cs.visible and not lobby.visible)
	cs._on_back_pressed()
	await _settled()
	_expect("car select -> lobby", not cs.visible and lobby.visible)
	lobby.is_in_room = false
	lobby.hide()
	main_menu_show(menu)

	await main._show_loading("Testing")
	_expect("loading cover in", main.loading_screen.visible)
	await get_tree().create_timer(0.4).timeout
	await main._hide_loading()
	_expect("loading hidden at once, panel still sweeping", not main.loading_screen.visible and swipe.busy)
	await _settled()
	_expect("loading swipe done", not swipe.busy and not swipe.visible)

	menu.hide()
	main._on_server_disconnected()
	await get_tree().process_frame
	_expect("exit swipe starts", swipe.busy)
	await _settled()
	_expect("exit -> menu", menu.visible and not swipe.busy)

	print("RESULT: %s" % ("all passed" if fails == 0 else "%d FAILED" % fails))
	get_tree().quit(0 if fails == 0 else 1)


func main_menu_show(menu: Control) -> void:
	menu.show()


func _settled() -> void:
	await get_tree().process_frame
	while main.screen_transition.busy:
		await get_tree().process_frame
	await get_tree().process_frame


func _expect(what: String, ok: bool) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		fails += 1
