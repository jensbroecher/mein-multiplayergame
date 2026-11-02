extends Node

# Raycasts the collision straight down along a line on a level and prints the surface's height and what it is, to find
# steps and walls in a road. Headless:
#   Godot --headless --path . res://scratch/route_surface_scan.tscn -- <level.tscn> x0,z0 x1,z1 [step=0.5]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level: Node3D = load(args[0]).instantiate()
	add_child(level)
	var a := args[1].split_floats(",")
	var b := args[2].split_floats(",")
	var step := 0.5
	for x in args.slice(3):
		if x.begins_with("step="):
			step = float(x.substr(5))
	for i in 30:
		await get_tree().physics_frame
	var space := level.get_world_3d().direct_space_state
	var p0 := Vector2(a[0], a[1])
	var p1 := Vector2(b[0], b[1])
	var n := int(p0.distance_to(p1) / step)
	var prev := NAN
	for k in range(n + 1):
		var p := p0.lerp(p1, float(k) / float(n))
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 200.0, p.y), Vector3(p.x, -200.0, p.y))
		var hit := space.intersect_ray(q)
		if hit:
			var y: float = hit.position.y
			var mark := "  <<< STEP %.2f" % (y - prev) if not is_nan(prev) and absf(y - prev) > 0.3 else ""
			print("%7.1f %7.1f  y=%7.2f  n=(%.2f,%.2f,%.2f)  %s%s" % [p.x, p.y, y, hit.normal.x, hit.normal.y, hit.normal.z, (hit.collider as Node).name, mark])
			prev = y
	get_tree().quit()
