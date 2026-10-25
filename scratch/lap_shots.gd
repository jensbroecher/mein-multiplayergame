extends Node

# Shots of a level along its lap: a chase camera behind and above the racing line at given distances
# along the TrackPath, with a cart standing on the road for scale. Run windowed:
#   Godot --path . res://scratch/lap_shots.tscn -- res://levels/X.tscn <out_dir> [every=N] [s=<m> ...]
#       [high=1] [back=12] [up=4.5] [ahead=26] [nocar] [name:x,y,z:tx,ty,tz ...]
# every=N takes N shots evenly round the lap; s=<m> one at that distance. high=1 lifts the camera for an
# overview of the section. Explicit name:pos:target shots work as in shots.gd.

const CART_MODEL := "res://generated/cars/Viper.tscn"
const CarPaint = preload("res://CarPaint.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path := args[0]
	var out_dir := args[1]
	AudioServer.set_bus_mute(0, true)
	MusicManager.window_mode = 0
	MusicManager.resolution_index = 0
	for i in 5:
		await get_tree().process_frame
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	var vp := get_viewport()
	vp.scaling_3d_scale = 1.0
	vp.msaa_3d = Viewport.MSAA_4X
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	MusicManager.set_shadow_quality(3, false)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	cam.make_current()
	var back := 12.0
	var up := 4.5
	var ahead := 26.0
	var with_car := true
	var offsets: Array = []
	var path: Path3D = level.get_node_or_null("TrackPath")
	var length: float = path.curve.get_baked_length() if path else 0.0
	print("LAP LENGTH ", length)
	for a in args.slice(2):
		if a.begins_with("back="):
			back = float(a.substr(5))
		elif a.begins_with("up="):
			up = float(a.substr(3))
		elif a.begins_with("ahead="):
			ahead = float(a.substr(6))
		elif a.begins_with("high="):
			up = 30.0
			back = 45.0
			ahead = 40.0
		elif a == "nocar":
			with_car = false
		elif a.begins_with("every="):
			var n := int(a.substr(6))
			for k in n:
				offsets.append(length * k / float(n))
		elif a.begins_with("s="):
			offsets.append(float(a.substr(2)))
	# Let the level build its runtime collision before standing carts on it.
	for i in 20:
		await get_tree().physics_frame
	var space := level.get_world_3d().direct_space_state
	var car: Node3D = null
	if with_car:
		car = load(CART_MODEL).instantiate()
		CarPaint.apply(car, CarPaint.factory("Viper"))
		add_child(car)
	for off in offsets:
		var o: float = fposmod(off, length)
		var p0: Vector3 = path.to_global(path.curve.sample_baked(o))
		var pb: Vector3 = path.to_global(path.curve.sample_baked(fposmod(o - back, length)))
		var pa: Vector3 = path.to_global(path.curve.sample_baked(fposmod(o + ahead, length)))
		var fwd: Vector3 = (pa - pb)
		fwd.y = 0.0
		fwd = fwd.normalized()
		if car:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p0 + Vector3.UP * 20.0, p0 + Vector3.DOWN * 40.0))
			var gy: float = hit.position.y if hit else p0.y
			car.global_transform = Transform3D(Basis.looking_at(-fwd, Vector3.UP).scaled(Vector3.ONE * 2.0), Vector3(p0.x, gy, p0.z))
		cam.global_position = pb + Vector3.UP * up
		cam.look_at(pa + Vector3.UP * 1.0, Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var nm := "s%05d" % int(o)
		vp.get_texture().get_image().save_png("%s/%s.png" % [out_dir, nm])
		print("SHOT ", nm, " at ", p0)
	for a in args.slice(2):
		if a.count(":") < 2:
			continue
		var parts := a.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out_dir, parts[0]])
		print("SHOT ", parts[0])
	get_tree().quit()
