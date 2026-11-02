extends Node

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var Level = load("res://levels/FreightLevel.tscn").instantiate()
	add_child(Level)

	for i in 20:
		await get_tree().physics_frame

	var space = Level.get_world_3d().direct_space_state
	var pos = Vector3(139.9259, 2.272735, 297.6652)
	# Test horizontal ray from 5m away towards pos
	var from = pos + Vector3(5, 1.0, 0)
	var to = pos + Vector3(0, 1.0, 0)
	var q = PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	var hit = space.intersect_ray(q)
	print("Horizontal ray from (pos + 5, 1, 0) to (pos, 1, 0): hit=", hit.collider.name if hit else "none")

	get_tree().quit()

