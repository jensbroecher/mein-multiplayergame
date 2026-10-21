extends SceneTree

func _init():
	print("KEY_BACKSPACE =", KEY_BACKSPACE)
	print("KEY_BACK =", KEY_BACK)
	print("KEY_ESCAPE =", KEY_ESCAPE)
	print("ui_cancel events:")
	for ev in InputMap.action_get_events("ui_cancel"):
		if ev is InputEventKey:
			print("  Key: keycode=", ev.keycode, " phys=", ev.physical_keycode, " key_label=", ev.key_label)
		elif ev is InputEventJoypadButton:
			print("  JoyBtn: button_index=", ev.button_index)
	quit()
