extends Node

# Plans a bot's way back to the road (RejoinPlanner.gd) from given spots of a level and prints it: each point, and for
# each step the solid things a ray at the planner's two bumper heights meets along it (what it looked past). Spectator
# race, headless:
#   Godot --headless --path . res://scratch/rejoin_plan_probe.tscn -- <level.tscn> x,y,z [x,y,z ...]
# The y is a height to look down from (the ground under it is found).

const RejoinPlanner = preload("res://RejoinPlanner.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var points: Array = []
	for a in args.slice(1):
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
	var cart: Node = get_tree().get_first_node_in_group("player_carts")
	var space := level.get_world_3d().direct_space_state
	var lap: Path3D = level.get_node_or_null("TrackPath")
	for p in points:
		var down := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 20.0)
		var g := space.intersect_ray(down)
		var start: Vector3 = (g.position as Vector3) + Vector3.UP * 0.6 if g else p
		# The planner starts where the cart is: park it there.
		cart.freeze = true
		cart.global_position = start
		await get_tree().physics_frame
		var job := RejoinPlanner.new(cart, space, lap, cart._ai_road_half())
		while not job.step():
			await get_tree().physics_frame
		print("FROM %s: found=%s expanded=%d points=%d" % [start, job.found, job.expanded, job.path.size()])
		for i in range(job.path.size()):
			var q: Vector3 = job.path[i]
			var line := "  %2d (%.1f, %.1f, %.1f)" % [i, q.x, q.y, q.z]
			if i > 0:
				var a: Vector3 = job.path[i - 1] - Vector3.UP * 0.5
				var b: Vector3 = q - Vector3.UP * 0.5
				for h in [RejoinPlanner.BUMPER_LOW, RejoinPlanner.BUMPER]:
					var from: Vector3 = a + Vector3.UP * h
					var to: Vector3 = b + Vector3.UP * h
					var seen: Array = []
					var ex: Array[RID] = []
					for k in range(5):
						var rq := PhysicsRayQueryParameters3D.create(from, to)
						rq.exclude = ex
						var hit := space.intersect_ray(rq)
						if hit.is_empty():
							break
						var c: Node = hit.collider
						seen.append("%s at %s n%s narrow=%s%s" % [c.name, hit.position, hit.normal, cart._ai_narrow_obstacle(space, hit, to - from), _sides(space, hit)])
						ex.append(hit.rid)
					if not seen.is_empty():
						line += "\n       @%.2f: %s" % [h, ", ".join(seen)]
			print(line)
	get_tree().quit()


# What the narrow test's side rays meet, 2.2m either way along the face.
func _sides(space: PhysicsDirectSpaceState3D, block: Dictionary) -> String:
	var n: Vector3 = block.normal
	n.y = 0.0
	if n.length_squared() < 1e-4:
		return ""
	n = n.normalized()
	var along := Vector3(-n.z, 0.0, n.x)
	var out := ""
	for sgn in [-1.0, 1.0]:
		var o: Vector3 = (block.position as Vector3) + along * (2.2 * sgn)
		var q := PhysicsRayQueryParameters3D.create(o + n * 0.8, o - n * 0.8)
		var r := space.intersect_ray(q)
		out += " [%s]" % ("-" if r.is_empty() else str(r.collider.name))
	return out
