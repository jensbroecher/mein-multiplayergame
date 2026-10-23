extends SceneTree

func _init() -> void:
	print("--- ZEPHYR VALIDATION START ---")

	# 1. Check CarPaint factory defaults
	var CarPaint = load("res://CarPaint.gd")
	var fac: Dictionary = CarPaint.factory("Zephyr")
	if fac.is_empty():
		push_error("FAIL: CarPaint.factory('Zephyr') returned empty dictionary!")
		quit(1)
		return
	print("  [OK] Zephyr factory paint: ", fac)

	# 2. Check PlayerCart CAR_PRESETS
	var PlayerCart = load("res://PlayerCart.gd")
	var zephyr_preset = null
	for p in PlayerCart.CAR_PRESETS:
		if p["name"] == "Zephyr":
			zephyr_preset = p
			break
	if zephyr_preset == null:
		push_error("FAIL: Zephyr not found in PlayerCart CAR_PRESETS!")
		quit(1)
		return
	print("  [OK] Zephyr found in PlayerCart: speed=%.1f, accel=%.1f, grip=%.1f, offroad=%.1f" % [
		zephyr_preset["max_speed"], zephyr_preset["acceleration"], zephyr_preset["grip"], zephyr_preset["offroad"]
	])

	# 3. Check CarSelection CAR_PRESETS & CAR_ACCENTS
	var CarSelection = load("res://CarSelection.gd")
	var cs_found := false
	for p in CarSelection.CAR_PRESETS:
		if p["name"] == "Zephyr":
			cs_found = true
			break
	if not cs_found:
		push_error("FAIL: Zephyr not found in CarSelection CAR_PRESETS!")
		quit(1)
		return
	if not CarSelection.CAR_ACCENTS.has("Zephyr"):
		push_error("FAIL: Zephyr accent color missing from CarSelection CAR_ACCENTS!")
		quit(1)
		return
	print("  [OK] CarSelection preset and accent verified: ", CarSelection.CAR_ACCENTS["Zephyr"])

	# 4. Check Lobby CAR_NAMES
	var Lobby = load("res://Lobby.gd")
	if not "Zephyr" in Lobby.CAR_NAMES:
		push_error("FAIL: Zephyr not in Lobby CAR_NAMES!")
		quit(1)
		return
	print("  [OK] Lobby CAR_NAMES contains Zephyr")

	# 5. Load and instantiate generated/cars/Zephyr.tscn
	var zephyr_scene: PackedScene = load("res://generated/cars/Zephyr.tscn")
	if zephyr_scene == null:
		push_error("FAIL: Could not load res://generated/cars/Zephyr.tscn")
		quit(1)
		return
	var inst: Node3D = zephyr_scene.instantiate()
	if inst == null:
		push_error("FAIL: Could not instantiate Zephyr scene!")
		quit(1)
		return
	print("  [OK] Successfully instantiated Zephyr.tscn")

	# Check node hierarchy
	var model = inst.find_child("Model", true, false)
	if model == null:
		push_error("FAIL: Model child node not found!")
		quit(1)
		return
	var body = inst.find_child("Body", true, false)
	if body == null or not (body is MeshInstance3D):
		push_error("FAIL: Body MeshInstance3D not found!")
		quit(1)
		return
	print("  [OK] Body mesh has %d surfaces, triangle count=%d" % [
		body.mesh.get_surface_count(), body.mesh.get_faces().size() / 3
	])

	# Check wheels
	for k in ["FL", "FR", "RL", "RR"]:
		var wheel_node_name = "Wheel_" + k
		var w_node = inst.find_child(wheel_node_name, true, false)
		if w_node == null or not (w_node is MeshInstance3D):
			push_error("FAIL: Wheel node %s not found!" % wheel_node_name)
			quit(1)
			return
		print("  [OK] Found %s at position: %s" % [wheel_node_name, str(w_node.position)])

	# Check antenna placement
	var ant = inst.find_child("AntennaPlacement", true, false)
	if ant == null:
		push_error("FAIL: AntennaPlacement node not found!")
		quit(1)
		return
	print("  [OK] Found AntennaPlacement at position: %s" % str(ant.position))

	# Test applying factory paint
	CarPaint.apply(inst, fac)
	print("  [OK] Successfully applied factory paint to Zephyr instance")

	inst.free()
	print("--- ALL ZEPHYR VALIDATIONS PASSED CLEANLY ---")
	quit(0)
