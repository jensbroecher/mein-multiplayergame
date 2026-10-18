extends Node

# Look-dev shots of Bloombay Dunes rendered straight into the window (the water reads the screen
# texture, which a SubViewport fills with stray 2D). Run windowed:
#   Godot --path . --resolution 1600x900 res://scratch/bloombay_shots.tscn -- <out_dir>
#       [level=res://levels/BloombayDunesLevel.tscn] [car=x,z,yaw ...] name:x,y,z:tx,ty,tz[:frames[:gap]] ...
# frames>1 saves name_0..name_N, gap seconds apart (default 1), to watch the surf move.

const CART_MODEL := "res://generated/cars/Viper.tscn"
const CarPaint = preload("res://CarPaint.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var level_path := "res://levels/BloombayDunesLevel.tscn"
	for a in args:
		if a.begins_with("level="):
			level_path = a.substr(6)
	AudioServer.set_bus_mute(0, true)
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	MusicManager.set_shadow_quality(3, false)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	for n in get_tree().root.find_children("*", "Control", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 4000.0
	add_child(cam)
	cam.make_current()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := level.get_world_3d().direct_space_state
	for a in args.slice(1):
		if not a.begins_with("car="):
			continue
		var c := a.substr(4).split(",")
		var x := float(c[0])
		var z := float(c[1])
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 400, z), Vector3(x, -400, z)))
		var y: float = hit.position.y if hit else 0.0
		var car: Node3D = load(CART_MODEL).instantiate()
		CarPaint.apply(car, CarPaint.factory("Viper"))
		add_child(car)
		car.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(c[2]) + 180.0)).scaled(Vector3.ONE * 2.0), Vector3(x, y, z))
	for a in args.slice(1):
		if a.begins_with("car=") or a.begins_with("level="):
			continue
		var parts := a.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		var frames := int(parts[3]) if parts.size() > 3 else 1
		var gap := float(parts[4]) if parts.size() > 4 else 1.0
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 20:
			await get_tree().process_frame
		for f in frames:
			if f > 0:
				var until := Time.get_ticks_msec() + int(gap * 1000.0)
				while Time.get_ticks_msec() < until:
					await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var name := parts[0] if frames == 1 else "%s_%d" % [parts[0], f]
			get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
			print("SHOT ", name)
	get_tree().quit()
