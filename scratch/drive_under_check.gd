extends Node

# Mina del Viento: can a cart get under the haul trucks and the conveyors? Sweeps a sphere the size of a cart's
# (PlayerCart: 0.75m) through the level's collision, 0.85m over the ground: across each truck between its axles and
# along it between its inner wheels, and across each conveyor's low run midway between two supports. Also checks
# that every sign is solid. Headless:
#   Godot --headless --path . res://scratch/drive_under_check.tscn

const R := 0.75
const LIFT := 0.85

var space: PhysicsDirectSpaceState3D
var fails := 0


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	NetworkManager.start_inspect()
	NetworkManager.current_game_mode = NetworkManager.GameMode.SPECTATOR
	NetworkManager.inspect_mode = true
	var level: Node3D = (load("res://levels/MinaLevel.tscn") as PackedScene).instantiate()
	add_child(level)
	for i in 30:
		await get_tree().physics_frame
	space = level.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = R
	for n in level.find_children("PitTruck_*", "StaticBody3D", true, false):
		var t: Transform3D = (n as Node3D).global_transform
		_sweep(sphere, n.name + " across", t * Vector3(-14, LIFT, 0.4), t * Vector3(14, LIFT, 0.4))
		_sweep(sphere, n.name + " along", t * Vector3(0, LIFT, -16), t * Vector3(0, LIFT, 16))
	# Conveyor A's long low run: across it midway between supports.
	var gen = load("res://regenerate_mina.gd")
	var pts: Array = gen.CONVEYOR_A
	for i in range(pts.size() - 1):
		var a := Vector3(pts[i][0], 0, pts[i][1])
		var b := Vector3(pts[i + 1][0], 0, pts[i + 1][1])
		var length := a.distance_to(b)
		var nsup: int = maxi(int(floor(length / 1.6 / 12.0)), 1)
		var mid: Vector3 = a.lerp(b, (floorf(nsup * 0.5) + 0.5) / nsup)
		var side: Vector3 = Vector3((b - a).z, 0, -(b - a).x).normalized()
		var g := _ground(mid)
		_sweep(sphere, "conveyor A run %d" % i, Vector3(mid.x, g + LIFT, mid.z) - side * 3.5, Vector3(mid.x, g + LIFT, mid.z) + side * 3.5)
	for n in level.find_children("Sign_*", "StaticBody3D", true, false):
		var shapes := 0
		for c in n.get_children():
			if c is CollisionShape3D:
				shapes += 1
		if shapes == 0:
			fails += 1
			print("  FAIL  %s has no collider" % n.name)
	print("signs solid: %d" % level.find_children("Sign_*", "StaticBody3D", true, false).size())
	print("RESULT: %s (%d failed)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit()


## The ground under `p`, from `above` metres over `near` (a height it is close to: the step before), so a ray under
## a truck's frame finds the floor, not the truck.
func _ground(p: Vector3, near := NAN, above := 1.0) -> float:
	var top: float = p.y + 200.0 if is_nan(near) else near + above
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, top, p.z), Vector3(p.x, top - 400.0, p.z))
	var hit := space.intersect_ray(q)
	return (hit["position"] as Vector3).y if hit else (near if not is_nan(near) else p.y)


func _sweep(sphere: SphereShape3D, what: String, from: Vector3, to: Vector3) -> void:
	# Ride the ground under the path: sample it and sweep each step at LIFT over it.
	var steps := 40
	var prev := from
	var g: float = _ground(from)
	prev.y = g + LIFT
	for k in range(1, steps + 1):
		var p: Vector3 = from.lerp(to, float(k) / steps)
		g = _ground(p, g)
		p.y = g + LIFT
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sphere
		q.transform = Transform3D(Basis(), prev)
		q.motion = p - prev
		var r: PackedFloat32Array = space.cast_motion(q)
		if r.size() > 0 and r[0] < 1.0:
			var at: Vector3 = prev + (p - prev) * r[0]
			var info := space.get_rest_info(_at(sphere, prev + (p - prev) * minf(r[1], 1.0)))
			var who: String = str(instance_from_id(info["collider_id"]).get_path()) if info else "?"
			if what.begins_with("conveyor") and not who.contains("Conveyor"):
				print("  n/a   %s: something else stands there (%s)" % [what, who.get_slice("MinaLevel/", 1)])
				return
			print("  FAIL  %s: blocked at %s by %s" % [what, str(at), who.get_slice("MinaLevel/", 1)])
			fails += 1
			return
		prev = p
	print("  ok    %s" % what)


func _at(sphere: SphereShape3D, p: Vector3) -> PhysicsShapeQueryParameters3D:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis(), p)
	return q
