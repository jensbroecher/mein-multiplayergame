extends SceneTree

func _init():
	# Add Backspace to ui_cancel
	var ev_bs = InputEventKey.new()
	ev_bs.keycode = KEY_BACKSPACE
	ev_bs.physical_keycode = KEY_BACKSPACE
	InputMap.action_add_event("ui_cancel", ev_bs)
	
	# Create a LineEdit
	var line_edit = LineEdit.new()
	line_edit.text = "Hello"
	root.add_child(line_edit)
	line_edit.grab_focus()
	line_edit.caret_column = 5
	
	print("Initial text: ", line_edit.text)
	
	# Simulate pressing Backspace
	var key_press = InputEventKey.new()
	key_press.pressed = true
	key_press.keycode = KEY_BACKSPACE
	key_press.physical_keycode = KEY_BACKSPACE
	
	print("is_action_pressed('ui_cancel'): ", key_press.is_action_pressed("ui_cancel"))
	
	line_edit._gui_input(key_press)
	print("Text after gui_input: ", line_edit.text)
	
	quit()
