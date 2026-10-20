extends Node

# Menu tiles for Nyota Stadium, rendered into a fixed-size SubViewport at twice the size and scaled
# down. Carts can be placed anywhere, mid-air over a jump included. Run windowed:
#   Godot --path . res://scratch/nyota_shots.tscn -- <out_dir> [cart=Model,x,y,z,heading_deg,pitch_deg ...]
#       name:x,y,z:tx,ty,tz ...
# `freeze` stops the LED boards cycling, for diffing shots a few cm apart.
# A cart's y of "g" puts it on the ground there. Heading 0 faces -z (north), 90 faces -x (west).
# Models are the procedural cars, res://generated/cars/<Model>.tscn (Viper, Shadow, Apex, ...), in
# their factory paint.

const SIZE := Vector2i(1376, 768)
const CarPaint = preload("res://CarPaint.gd")

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	AudioServer.set_bus_mute(0, true)
	var vp := SubViewport.new()
	vp.size = SIZE * 2
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var level: Node3D = load("res://levels/NyotaStadiumLevel.tscn").instantiate()
	vp.add_child(level)
	MusicManager.set_shadow_quality(3, false)
	# `freeze` stops the LED boards cycling their adverts, so two shots a few cm apart differ only by flicker.
	if args.has("freeze"):
		for mi in level.find_children("*", "MeshInstance3D", true, false):
			var sm := mi.material_override as ShaderMaterial
			if sm != null and sm.shader != null and sm.shader.resource_path.ends_with("stadium_boards.gdshader"):
				sm.set_shader_parameter("cycle_seconds", 1.0e9)
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
	for a in args.slice(1):
		if not a.begins_with("cart="):
			continue
		var c := a.substr(5).split(",")
		var x := float(c[1])
		var z := float(c[3])
		var y: float
		if c[2] == "g":
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 200, z), Vector3(x, -50, z)))
			y = (hit.position.y if hit else 0.0) + 0.75
		else:
			y = float(c[2])
		var model: Node3D = load("res://generated/cars/%s.tscn" % c[0]).instantiate()
		CarPaint.apply(model, CarPaint.factory(c[0]))
		vp.add_child(model)
		var heading := deg_to_rad(float(c[4]))
		var pitch := deg_to_rad(float(c[5])) if c.size() > 5 else 0.0
		var b := Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, pitch)
		model.global_transform = Transform3D(b * Basis(Vector3.UP, PI) * 2.0, Vector3(x, y, z) + b * Vector3(0, -0.6072377, 0))
	for a in args.slice(1):
		if a.begins_with("cart=") or a == "freeze":
			continue
		var parts := a.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		cam.look_at(Vector3(float(t[0]), float(t[1]), float(t[2])), Vector3.UP)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		img.save_png("%s/%s.png" % [out_dir, parts[0]])
		print("SHOT ", parts[0])
	get_tree().quit()
