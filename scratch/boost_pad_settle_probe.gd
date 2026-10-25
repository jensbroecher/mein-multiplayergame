extends Node

# Lists every boost pad's saved position and where it settled once the level's collision existed, how
# upright it lies (TILTED past 37 degrees) and what the ray under its middle hits. Spectator race, headless:
#   Godot --headless --path . res://scratch/boost_pad_settle_probe.tscn -- [res://levels/LakesideLevel.tscn]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0] if args.size() > 0 else "res://levels/LakesideLevel.tscn"
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node = load(level_path).instantiate()
	var saved := {}
	for p in level.find_children("*", "Area3D", true, false):
		if p.get_script() and str(p.get_script().resource_path).ends_with("BoostPad.gd"):
			saved[String(p.name)] = (p as Node3D).transform.origin
	add_child(level)
	await level.wait_for_collisions()
	for i in 30:
		await get_tree().physics_frame
	var space := (level as Node3D).get_world_3d().direct_space_state
	for p in level.find_children("*", "Area3D", true, false):
		if not (p.get_script() and str(p.get_script().resource_path).ends_with("BoostPad.gd")):
			continue
		var g: Vector3 = (p as Node3D).global_position
		var q := PhysicsRayQueryParameters3D.create(g + Vector3.UP * 4.0, g - Vector3.UP * 6.0, 1)
		var hit := space.intersect_ray(q)
		var under := String((hit["collider"] as Node).name) if not hit.is_empty() else "-"
		var up_y: float = (p as Node3D).global_transform.basis.y.normalized().y
		print("PAD %-22s saved %s  now %s  up.y %.2f%s  ray hits %s" % [p.name, saved.get(String(p.name), Vector3.ZERO), g, up_y, "  TILTED" if up_y < 0.8 else "", under])
	get_tree().quit()
