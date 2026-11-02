extends Node

func _ready() -> void:
	var level_scene = load("res://levels/FreightLevel.tscn")
	var level = level_scene.instantiate()
	add_child(level)
	
	for i in 10:
		await get_tree().physics_frame
	
	var space = get_viewport().find_world_3d().direct_space_state
	var bs0 = level.find_child("BufferStop_0", true, false)
	var forward: Vector3 = bs0.global_transform.basis.z.normalized()
	
	# Test various heights through the buffer stop
	for h in [0.5, 1.0, 1.5, 1.7, 2.0]:
		var ray = PhysicsRayQueryParameters3D.create(
			bs0.global_position - forward * 3.0 + Vector3(0, h, 0),
			bs0.global_position + forward * 8.0 + Vector3(0, h, 0)
		)
		var res = space.intersect_ray(ray)
		if not res.is_empty():
			print("Ray at height ", h, ": HIT ", res.collider.name, " at ", res.position)
		else:
			print("Ray at height ", h, ": MISS")
	
	get_tree().quit()
