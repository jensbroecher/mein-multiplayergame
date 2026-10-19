extends Node
# Presses buttons and lists which button sound each one made (MusicManager's hook on every
# BaseButton in the tree). Headless:  Godot --headless --path . res://scratch/ui_sound_test.tscn
var heard: Array = []
func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	MusicManager.child_entered_tree.connect(func(n: Node):
		if n is AudioStreamPlayer and n.stream:
			heard.append(n.stream.resource_path.get_file()))
	var plain := Button.new()
	var important := Button.new()
	important.set_meta(&"ui_important", true)
	var silent := Button.new()
	silent.set_meta(&"ui_silent", true)
	var check := CheckButton.new()
	var option := OptionButton.new()
	for b in [plain, important, silent, check, option]:
		add_child(b)
	await get_tree().process_frame
	for pair in [["plain", plain], ["important", important], ["silent", silent], ["check", check]]:
		heard.clear()
		pair[1].pressed.emit()
		print("%-10s -> %s" % [pair[0], heard if not heard.is_empty() else "nothing"])
	# A button that was in the tree before the hook ran and one added later both work, and a button
	# that leaves and comes back isn't hooked twice.
	heard.clear()
	remove_child(plain)
	add_child(plain)
	plain.pressed.emit()
	print("re-added   -> %s (want one sound)" % [heard])
	# The real screen.
	var main: Node = load("res://Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var cs: Control = main.get_node("CarSelection")
	heard.clear()
	cs._confirm_btn.pressed.emit()
	print("car select CONFIRM -> %s" % [heard])
	heard.clear()
	cs._back_btn.pressed.emit()
	print("car select BACK    -> %s" % [heard])
	get_tree().quit()
