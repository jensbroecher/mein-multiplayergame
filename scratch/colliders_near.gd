extends Node

# Lists what is solid near a point of a level, once its runtime colliders exist (Level.gd's and
# DressingColliders.gd's): each collider within `radius` of each point, its node path, layer and the
# distance. Spectator race, headless:
#   Godot --headless --path . res://scratch/colliders_near.tscn -- <level.tscn> x,y,z [x,y,z ...] [radius=3]
#       [route=<Path3D path>:<s0>:<s1>[:<lateral half>]]
# route= also lists, every metre of that path between s0 and s1, every surface a ray straight down
# through it meets (to find ground poking up through a deck); with a lateral half width, across the
# path too every 0.5m, as the first surface's height (or "--" where a ray finds nothing within 12m).


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var radius := 3.0
	var points: Array = []
	var route := ""
	for a in args.slice(1):
		if a.begins_with("radius="):
			radius = float(a.substr(7))
		elif a.begins_with("route="):
			route = a.substr(6)
		else:
			var p := a.split(",")
			points.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	AudioServer.set_bus_mute(0, true)
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.start_spectator()
	var level: Node3D = load(args[0]).instantiate()
	add_child(level)
	await level.wait_for_collisions()
	for i in 30:
		await get_tree().physics_frame
	var space := level.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius
	for p in points:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), p)
		q.collision_mask = 0xFFFFFFFF
		print("NEAR %s (r %.1f):" % [p, radius])
		for h in space.intersect_shape(q, 32):
			var c: Node = h["collider"]
			if c.is_in_group("player_carts"):
				continue
			var layer: int = (c as CollisionObject3D).collision_layer if c is CollisionObject3D else -1
			var owner_shape := ""
			if c is CollisionObject3D:
				var sid: int = h["shape"]
				var ow: int = (c as CollisionObject3D).shape_find_owner(sid)
				var on: Object = (c as CollisionObject3D).shape_owner_get_owner(ow)
				if on is Node:
					owner_shape = String((on as Node).name)
			print("  %s  layer %d  shape %s" % [level.get_path_to(c), layer, owner_shape])
	if route != "":
		var parts := route.split(":")
		var path := level.get_node(parts[0]) as Path3D
		var s0 := float(parts[1])
		var s1 := float(parts[2])
		var half := float(parts[3]) if parts.size() > 3 else 0.0
		var sv := s0
		while half > 0.0 and sv <= s1:
			var c := path.to_global(path.curve.sample_baked(sv))
			var t := (path.to_global(path.curve.sample_baked(sv + 0.5)) - c)
			t.y = 0.0
			var r := Vector3(-t.z, 0.0, t.x).normalized()
			var line := "  s=%5.1f " % sv
			var l := -half
			while l <= half + 0.01:
				var p2: Vector3 = c + r * l
				var q2 := PhysicsRayQueryParameters3D.create(p2 + Vector3.UP * 3.0, p2 + Vector3.DOWN * 12.0)
				var h2 := space.intersect_ray(q2)
				line += "    --" if h2.is_empty() else " %+5.1f" % ((h2["position"] as Vector3).y - c.y)
				l += 0.5
			print(line)
			sv += 1.0
		sv = s0 if half <= 0.0 else s1 + 1.0
		while sv <= s1:
			var p: Vector3 = path.to_global(path.curve.sample_baked(sv))
			var hits := PackedStringArray()
			var ex: Array = []
			for k in range(5):
				var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 8.0, p + Vector3.DOWN * 12.0)
				q.exclude = ex
				var h := space.intersect_ray(q)
				if h.is_empty():
					break
				hits.append("%s %.2f" % [(h["collider"] as Node).name, (h["position"] as Vector3).y - p.y])
				ex.append(h["rid"])
			print("  s=%5.1f  line y %.2f: %s" % [sv, p.y, ", ".join(hits)])
			sv += 1.0
	get_tree().quit()
