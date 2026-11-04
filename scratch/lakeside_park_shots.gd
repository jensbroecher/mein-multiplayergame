extends Node
## Photographs the Lakeside Meadows' park things where they are right now (windowed, seconds):
##   Godot --path . --resolution 1600x900 res://scratch/lakeside_park_shots.tscn -- <dir> [rider=0] [frames=1] [gap=0.5]
##       [name:x,y,z:tx,ty,tz ...]
## Saves rider.png (a chase view of rider N of LakesideDressing/Paths/Cyclists, `frames` of them `gap` seconds apart:
## rider_0.png ...), rider_side.png, airship.png (from under the airship) and airship_far.png (from the start), and any
## named shots; with `trails=1` a view of each path piece's middle (trail_<name>.png, one in four pieces). Cameras are lifted
## out of the ground. Cyclists.gd and Airship.gd run on the wall clock, so each run catches them somewhere else.

var _dir := ""
var _level: Node3D
var _cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_dir)
	var rider := 0
	var frames := 1
	var gap := 0.5
	var named: Array = []
	var trails := false
	for a in args.slice(1):
		if a == "trails=1":
			trails = true
		if a.begins_with("rider="):
			rider = int(a.substr(6))
		elif a.begins_with("frames="):
			frames = int(a.substr(7))
		elif a.begins_with("gap="):
			gap = float(a.substr(4))
		elif a.contains(":"):
			named.append(a)
	_level = (load("res://levels/LakesideLevel.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_level)
	await get_tree().process_frame
	_cam = Camera3D.new()
	_cam.far = 4000.0
	get_tree().root.add_child(_cam)
	_cam.make_current()
	await _wait(45)
	for s in named:
		var parts: PackedStringArray = (s as String).split(":")
		var p := _v(parts[1])
		var t := _v(parts[2])
		_cam.global_position = p
		_cam.look_at(t, Vector3.UP)
		await _shot(parts[0])
	var cyc := _level.get_node_or_null("LakesideDressing/Paths/Cyclists")
	if cyc:
		var bodies: Array = cyc.get_children(true).filter(func(c): return c is AnimatableBody3D)
		if rider < bodies.size():
			for f in range(frames):
				var b: Node3D = bodies[rider]
				var fwd: Vector3 = -b.global_transform.basis.z
				var right: Vector3 = b.global_transform.basis.x
				_cam.global_position = _lift(b.global_position - fwd * 7.0 + Vector3.UP * 3.0 + right * 2.0)
				_cam.look_at(b.global_position + Vector3.UP * 1.2, Vector3.UP)
				await _shot("rider" if frames == 1 else "rider_%d" % f)
				if f == 0:
					_cam.global_position = _lift(b.global_position + right * 5.5 + Vector3.UP * 1.6)
					_cam.look_at(b.global_position + Vector3.UP * 1.1, Vector3.UP)
					await _shot("rider_side")
				if frames > 1:
					await get_tree().create_timer(gap).timeout
			print("RIDER at ", (bodies[rider] as Node3D).global_position)
	if trails:
		var paths := _level.get_node_or_null("LakesideDressing/Paths")
		var k := 0
		if paths:
			for c in paths.get_children():
				if c is MeshInstance3D and String(c.name).begins_with("Trail_"):
					k += 1
					if k % 4 != 1:
						continue
					var box: AABB = (c as MeshInstance3D).global_transform * (c as MeshInstance3D).mesh.get_aabb()
					var mid := box.get_center()
					_cam.global_position = _lift(mid + Vector3(14.0, 12.0, 14.0))
					_cam.look_at(mid, Vector3.UP)
					await _shot(String(c.name).to_lower())
	var ship := _level.get_node_or_null("LakesideDressing/Airship") as Node3D
	if ship:
		var sp := ship.global_position
		var fwd2: Vector3 = -ship.global_transform.basis.z
		_cam.global_position = sp + fwd2 * 70.0 + ship.global_transform.basis.x * 90.0 - Vector3.UP * 30.0
		_cam.look_at(sp, Vector3.UP)
		await _shot("airship")
		_cam.global_position = Vector3(20.0, 6.0, 110.0)
		_cam.look_at(sp, Vector3.UP)
		_cam.fov = 40.0
		await _shot("airship_far")
		print("AIRSHIP at ", sp)
	get_tree().quit()


## `p` raised to 1.8m over whatever is under it.
func _lift(p: Vector3) -> Vector3:
	var space := _cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 300.0, p - Vector3.UP * 300.0)
	var hit := space.intersect_ray(q)
	if hit and p.y < (hit.position as Vector3).y + 1.8:
		p.y = (hit.position as Vector3).y + 1.8
	return p


func _v(s: String) -> Vector3:
	var c := s.split(",")
	return Vector3(float(c[0]), float(c[1]), float(c[2]))


func _wait(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _shot(n: String) -> void:
	await _wait(4)
	var img := get_tree().root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_dir, n])
	print("SHOT ", n)
