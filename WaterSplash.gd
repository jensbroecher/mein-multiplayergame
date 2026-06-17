extends Node3D

func _ready():
	# Performance protection: Limit to 6 active water splashes in the scene
	var active_splashes = get_tree().get_nodes_in_group("water_splashes")
	if active_splashes.size() >= 6:
		var oldest = active_splashes[0]
		if is_instance_valid(oldest) and oldest != self:
			oldest.queue_free()
	
	add_to_group("water_splashes")
	
	var max_lifetime = 0.0
	for child in get_children():
		if child is GPUParticles3D:
			child.emitting = true
			max_lifetime = max(max_lifetime, child.lifetime)
	
	get_tree().create_timer(max_lifetime + 0.5).timeout.connect(queue_free)

