extends Node

func _ready() -> void:
	print("--- TESTING CONCRETE FOOTBRIDGE COLLISION & CLEARANCE ---")
	
	var scene := load("res://ConcreteFootbridge.tscn") as PackedScene
	if not scene:
		printerr("Failed to load ConcreteFootbridge.tscn!")
		get_tree().quit(1)
		return
		
	var bridge := scene.instantiate() as Node3D
	add_child(bridge)
	
	# Wait for physics frames so CSG collision shapes generate in PhysicsServer3D
	for i in range(5):
		await get_tree().physics_frame
		
	var space_state := bridge.get_world_3d().direct_space_state
	var all_passed := true
	
	# Test 1: Under-bridge road clearance at center (0, 0, 0) -> (0, 8, 0)
	var query_clearance := PhysicsRayQueryParameters3D.create(
		Vector3(0, 0.5, 0),
		Vector3(0, 8.0, 0)
	)
	var res_clearance := space_state.intersect_ray(query_clearance)
	if res_clearance.is_empty():
		printerr("FAIL: No collision found above road center!")
		all_passed = false
	else:
		var soffit_y: float = res_clearance.position.y
		print("Soffit contact Y at center: %0.3f m" % soffit_y)
		if soffit_y < 4.8 or soffit_y > 5.1:
			printerr("FAIL: Road clearance out of expected range [4.8, 5.1]! Got: %0.3f" % soffit_y)
			all_passed = false
		else:
			print("PASS: Road clearance is %.2f m (target ~4.96 m)" % soffit_y)

	# Test 2: Walkway deck surface at center (0, 12, 0) -> (0, 6, 0)
	var query_deck := PhysicsRayQueryParameters3D.create(
		Vector3(0, 12.0, 0),
		Vector3(0, 6.0, 0)
	)
	var res_deck := space_state.intersect_ray(query_deck)
	if res_deck.is_empty():
		printerr("FAIL: Walkway deck did not register collision!")
		all_passed = false
	else:
		var deck_y: float = res_deck.position.y
		print("Walkway deck Y at center: %0.3f m" % deck_y)
		if deck_y < 8.1 or deck_y > 8.4:
			printerr("FAIL: Deck surface out of expected range [8.1, 8.4]! Got: %0.3f" % deck_y)
			all_passed = false
		else:
			print("PASS: Walkway deck surface is %.2f m (target ~8.25 m)" % deck_y)

	# Test 3: Left Ramp slope contact (X = -15, Z = 0)
	var query_left := PhysicsRayQueryParameters3D.create(
		Vector3(-15.0, 10.0, 0),
		Vector3(-15.0, 0.0, 0)
	)
	var res_left := space_state.intersect_ray(query_left)
	if res_left.is_empty():
		printerr("FAIL: Left ramp surface did not register collision!")
		all_passed = false
	else:
		print("PASS: Left ramp surface contact at Y = %.2f m" % res_left.position.y)

	# Test 4: Right Ramp slope contact (X = +15, Z = 0)
	var query_right := PhysicsRayQueryParameters3D.create(
		Vector3(15.0, 10.0, 0),
		Vector3(15.0, 0.0, 0)
	)
	var res_right := space_state.intersect_ray(query_right)
	if res_right.is_empty():
		printerr("FAIL: Right ramp surface did not register collision!")
		all_passed = false
	else:
		print("PASS: Right ramp surface contact at Y = %.2f m" % res_right.position.y)

	# Test 5: Parapet side walls at (X = 0, Y = 9.0, Z = 0 -> +6.0)
	var query_parapet := PhysicsRayQueryParameters3D.create(
		Vector3(0, 9.0, 0),
		Vector3(0, 9.0, 6.0)
	)
	var res_parapet := space_state.intersect_ray(query_parapet)
	if res_parapet.is_empty():
		printerr("FAIL: Parapet wall did not register collision!")
		all_passed = false
	else:
		print("PASS: Parapet wall contact at Z = %.2f m (inner edge)" % res_parapet.position.z)

	if all_passed:
		print("=== ALL FOOTBRIDGE COLLISION TESTS PASSED ===")
		get_tree().quit(0)
	else:
		printerr("=== FOOTBRIDGE COLLISION TESTS HAD FAILURES ===")
		get_tree().quit(1)
