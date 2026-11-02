extends SceneTree

func _init() -> void:
	var gen = load("res://regenerate_mina.gd").new()
	gen._build_plan()
	var sp1 = gen._spot(3804.0, 0.0, 0.0)
	var sp2 = gen._spot(3945.0, 0.0, 0.0)
	print("s=3804m pos=", sp1["pos"], " yaw=", sp1["yaw"])
	print("s=3945m pos=", sp2["pos"], " yaw=", sp2["yaw"])
	
	var level_scene = load("res://levels/MinaLevel.tscn").instantiate()
	var query = PhysicsRayQueryParameters3D.new()
	print("Checking nodes under MinaLevel...")
	var cb = level_scene.find_child("ConveyorBridge_3820m", true, false)
	if cb:
		print("cb found: ", cb, " pos=", cb.position, " children=", cb.get_children())
	var static_bodies = level_scene.find_children("*", "StaticBody3D", true, false)
	print("Total static bodies: ", static_bodies.size())
	for sb in static_bodies:
		if sb.name.begins_with("Conveyor") or sb.name.begins_with("Bridge"):
			print("Bridge sb: ", sb.name)
	level_scene.free()
	quit(0)
