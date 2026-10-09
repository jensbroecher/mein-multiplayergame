extends Node

# Look-dev shots of a level with RC carts standing in for scale. Run windowed:
#   Godot --path . res://scratch/look_shots.tscn -- <level.tscn> <out_dir> [car=x,z,yaw_deg ...]
#       name:x,y,z:tx,ty,tz ...
# A cart is dropped onto the ground at each car= spot. A shot named herd* first waits until the
# Mara Crossing herd is streaming across the road.

const SIZE := Vector2i(1376, 768)
const HERD_CROSS := Vector3(190.0, 7.0, -55.0)
const CART_MODEL := "res://models/cars/20260505221030_500312d9.fbx"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[1]
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var level: Node3D = load(args[0]).instantiate()
	vp.add_child(level)
	MusicManager.set_shadow_quality(3, false)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var cam := Camera3D.new()
	cam.fov = 62.0
	cam.far = 4000.0
	vp.add_child(cam)
	cam.make_current()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := level.get_world_3d().direct_space_state
	for a in args.slice(2):
		if not a.begins_with("car="):
			continue
		var c := a.substr(4).split(",")
		var x := float(c[0])
		var z := float(c[1])
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 400, z), Vector3(x, -400, z))
		var hit := space.intersect_ray(q)
		var y: float = hit.position.y if hit else 0.0
		var car: Node3D = load(CART_MODEL).instantiate()
		vp.add_child(car)
		car.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(c[2]) + 180.0)).scaled(Vector3.ONE * 2.0), Vector3(x, y, z))
		print("CAR at ", car.global_position)
	var herd: Node = level.get_node_or_null("MigrationHerd")
	for a in args.slice(2):
		if a.begins_with("car="):
			continue
		var parts := a.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		if parts[0].begins_with("herd") and herd:
			for i in 3000:
				await get_tree().process_frame
				var near := 0
				for k in herd._xforms.size():
					if herd._visible[k] == 1 and Vector2(herd._xforms[k].origin.x - HERD_CROSS.x, herd._xforms[k].origin.z - HERD_CROSS.z).length() < 16.0:
						near += 1
				if near >= 9:
					break
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out_dir, parts[0]])
		print("SHOT ", parts[0])
	get_tree().quit()
