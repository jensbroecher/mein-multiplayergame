extends Node3D

# Fires a regular missile straight ahead past a marker cart standing off to the side, and prints
# the closest the missile came. Compare with the nudge off (turn 0) to see how much it corrects.
#   Godot --headless --path . res://scratch/missile_nudge_test.tscn

const MISSILE := preload("res://Missile.tscn")

func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, -150)
	add_child(floor_body)
	for c in [[40.0, 3.0], [40.0, 8.0], [60.0, 6.0], [60.0, 15.0], [40.0, 30.0], [90.0, 10.0]]:
		var marker := Node3D.new()
		marker.name = "999"
		marker.add_to_group("player_carts")
		add_child(marker)
		marker.global_position = Vector3(c[1], 1.0, -c[0])
		var m = MISSILE.instantiate()
		m.owner_id = 1
		m.is_guided = false
		add_child(m)
		m.global_position = Vector3(0, 1.0, 0)
		m.global_rotation = Vector3.ZERO
		m.start_position = m.global_position
		var closest := 1e9
		for i in 150:
			await get_tree().physics_frame
			if not is_instance_valid(m) or m.has_exploded:
				break
			closest = minf(closest, m.global_position.distance_to(marker.global_position))
		print("target %3.0fm ahead, %4.1fm to the side (%2.0f deg): missile passed within %.1fm" % [c[0], c[1], rad_to_deg(atan2(c[1], c[0])), closest])
		if is_instance_valid(m):
			m.queue_free()
		marker.queue_free()
		await get_tree().physics_frame
	get_tree().quit()
