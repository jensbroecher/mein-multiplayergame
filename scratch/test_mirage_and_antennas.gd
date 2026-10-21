extends SceneTree

func _init() -> void:
	print("--- VALIDATION START ---")

	# 1. Check CarPaint antenna defaults
	var CarPaint = load("res://CarPaint.gd")
	var car_names = ["Viper", "Shadow", "Strikeforce", "Apex", "Interceptor", "Mudrunner", "Phantom", "Centurion", "Mirage"]
	for cname in car_names:
		var fac: Dictionary = CarPaint.factory(cname)
		var ant: bool = CarPaint.has_antenna(fac)
		if ant != false:
			push_error("FAIL: Car %s factory antenna is %s, expected false!" % [cname, str(ant)])
			quit(1)
			return
		print("  [OK] %s factory antenna: %s" % [cname, str(ant)])

	# 2. Check PlayerCart CAR_PRESETS
	var PlayerCart = load("res://PlayerCart.gd")
	print("  PlayerCart presets count: %d" % PlayerCart.CAR_PRESETS.size())
	var mirage_preset = null
	for p in PlayerCart.CAR_PRESETS:
		if p["name"] == "Mirage":
			mirage_preset = p
			break
	if mirage_preset == null:
		push_error("FAIL: Mirage not found in PlayerCart CAR_PRESETS!")
		quit(1)
		return
	print("  [OK] Mirage found in PlayerCart CAR_PRESETS: %s" % mirage_preset["name"])

	# 3. Load generated/cars/Mirage.tscn and instantiate
	var mirage_scene: PackedScene = load(mirage_preset["model_path"])
	if mirage_scene == null:
		push_error("FAIL: Could not load %s" % mirage_preset["model_path"])
		quit(1)
		return
	var inst: Node3D = mirage_scene.instantiate()
	if inst == null:
		push_error("FAIL: Could not instantiate %s" % mirage_preset["model_path"])
		quit(1)
		return
	print("  [OK] Successfully instantiated Mirage.tscn")

	# Check wheel parts
	for k in ["FL", "FR", "RL", "RR"]:
		var node_name = mirage_preset["wheel_parts"][k]
		var w_node = inst.find_child(node_name, true, false)
		if w_node == null:
			push_error("FAIL: Wheel part node %s not found in Mirage instance!" % node_name)
			quit(1)
			return
		print("  [OK] Found wheel part: %s (%s)" % [k, node_name])

	# 4. Check CarSelection CAR_PRESETS and CAR_ACCENTS
	var CarSelection = load("res://CarSelection.gd")
	var cs_mirage_found = false
	for p in CarSelection.CAR_PRESETS:
		if p["name"] == "Mirage":
			cs_mirage_found = true
			break
	if not cs_mirage_found:
		push_error("FAIL: Mirage not found in CarSelection CAR_PRESETS!")
		quit(1)
		return
	if not CarSelection.CAR_ACCENTS.has("Mirage"):
		push_error("FAIL: Mirage accent color not found in CarSelection CAR_ACCENTS!")
		quit(1)
		return
	print("  [OK] CarSelection has Mirage with accent: %s" % str(CarSelection.CAR_ACCENTS["Mirage"]))

	# 5. Check Lobby CAR_NAMES
	var Lobby = load("res://Lobby.gd")
	if not "Mirage" in Lobby.CAR_NAMES:
		push_error("FAIL: Mirage not in Lobby CAR_NAMES!")
		quit(1)
		return
	print("  [OK] Lobby CAR_NAMES contains Mirage")

	print("--- ALL VALIDATIONS PASSED CLEANLY ---")
	quit(0)
