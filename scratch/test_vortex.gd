extends SceneTree

func _init() -> void:
	print("--- VORTEX VALIDATION START ---")

	# 1. Check CarPaint factory defaults
	var CarPaint = load("res://CarPaint.gd")
	var fac: Dictionary = CarPaint.factory("Vortex")
	if fac.is_empty():
		push_error("FAIL: CarPaint.factory('Vortex') returned empty dictionary!")
		quit(1)
		return
	if fac.get("antenna", true) != false:
		push_error("FAIL: Vortex factory antenna is not false!")
		quit(1)
		return
	print("  [OK] Vortex factory paint: ", fac)

	# 2. Check PlayerCart CAR_PRESETS
	var PlayerCart = load("res://PlayerCart.gd")
	print("  PlayerCart presets count: %d" % PlayerCart.CAR_PRESETS.size())
	var vortex_preset = null
	for p in PlayerCart.CAR_PRESETS:
		if p["name"] == "Vortex":
			vortex_preset = p
			break
	if vortex_preset == null:
		push_error("FAIL: Vortex not found in PlayerCart CAR_PRESETS!")
		quit(1)
		return
	print("  [OK] Vortex found in PlayerCart: speed=%.1f, accel=%.1f, grip=%.1f, offroad=%.1f" % [
		vortex_preset["max_speed"], vortex_preset["acceleration"], vortex_preset["grip"], vortex_preset["offroad"]
	])

	# 3. Check CarSelection CAR_PRESETS & CAR_ACCENTS
	var CarSelection = load("res://CarSelection.gd")
	var cs_vortex_found := false
	for p in CarSelection.CAR_PRESETS:
		if p["name"] == "Vortex":
			cs_vortex_found = true
			break
	if not cs_vortex_found:
		push_error("FAIL: Vortex not found in CarSelection CAR_PRESETS!")
		quit(1)
		return
	if not CarSelection.CAR_ACCENTS.has("Vortex"):
		push_error("FAIL: Vortex accent color missing from CarSelection CAR_ACCENTS!")
		quit(1)
		return
	print("  [OK] CarSelection preset and accent verified: ", CarSelection.CAR_ACCENTS["Vortex"])

	# 4. Check Lobby CAR_NAMES
	var Lobby = load("res://Lobby.gd")
	if not "Vortex" in Lobby.CAR_NAMES:
		push_error("FAIL: Vortex not in Lobby CAR_NAMES!")
		quit(1)
		return
	print("  [OK] Lobby CAR_NAMES contains Vortex")

	# 5. Load and instantiate generated/cars/Vortex.tscn
	var vortex_scene: PackedScene = load("res://generated/cars/Vortex.tscn")
	if vortex_scene == null:
		push_error("FAIL: Could not load res://generated/cars/Vortex.tscn")
		quit(1)
		return
	var inst: Node3D = vortex_scene.instantiate()
	if inst == null:
		push_error("FAIL: Could not instantiate Vortex scene!")
		quit(1)
		return
	print("  [OK] Successfully instantiated Vortex.tscn")

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
	print("  [OK] Successfully applied factory paint to Vortex instance")

	inst.free()
	print("--- ALL VORTEX VALIDATIONS PASSED CLEANLY ---")
	quit(0)
