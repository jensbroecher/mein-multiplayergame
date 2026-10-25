extends Node

# Renders a level with its paths drawn over it: the lap (TrackPath) white, the shortcuts
# (AlternativePaths) yellow, any other Path3D cyan, each with a dot every 10m (red at its start).
# Windowed:
#   Godot --path . res://scratch/path_overlay_shots.tscn -- <level.tscn> <out_dir> name:x,y,z:tx,ty,tz[:fov] ...

const SIZE := Vector2i(1376, 768)


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
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	for p in level.find_children("*", "Path3D", true, false):
		var path := p as Path3D
		if path.curve == null or path.curve.point_count < 2:
			continue
		var col := Color(1, 1, 1)
		if path.name == "TrackPath":
			col = Color(1, 1, 1)
		elif path.get_parent().name == "AlternativePaths":
			col = Color(1.0, 0.85, 0.1)
		else:
			col = Color(0.2, 0.9, 1.0)
		vp.add_child(_line_mesh(path, col))
	var cam := Camera3D.new()
	cam.far = 4000.0
	vp.add_child(cam)
	cam.make_current()
	for i in 40:
		await get_tree().process_frame
	for a in args.slice(2):
		var parts := a.split(":")
		var p := parts[1].split(",")
		var t := parts[2].split(",")
		cam.fov = float(parts[3]) if parts.size() > 3 else 60.0
		cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		var target := Vector3(float(t[0]), float(t[1]), float(t[2]))
		var up := Vector3.UP if absf((target - cam.global_position).normalized().y) < 0.98 else Vector3.FORWARD
		cam.look_at(target, up)
		for i in 20:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out_dir, parts[0]])
		print("SHOT ", parts[0])
	get_tree().quit()


func _line_mesh(path: Path3D, col: Color) -> MeshInstance3D:
	var c := path.curve
	var len := c.get_baked_length()
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.vertex_color_use_as_albedo = true
	mat.render_priority = 10
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var w := 0.6
	var s := 0.0
	while s < len:
		var a := path.to_global(c.sample_baked(s)) + Vector3.UP * 0.6
		var b := path.to_global(c.sample_baked(minf(s + 2.0, len))) + Vector3.UP * 0.6
		var d := b - a
		d.y = 0.0
		var side := Vector3(-d.z, 0.0, d.x).normalized() * w
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			im.surface_set_color(col)
			im.surface_add_vertex(v)
		# A dot every 10m, red at the start.
		if fmod(s, 10.0) < 0.01:
			var dot := Color(1, 0.1, 0.1) if s < 0.01 else col.darkened(0.5)
			var r := 1.6 if s < 0.01 else 1.0
			for k in 8:
				var a0 := TAU * k / 8.0
				var a1 := TAU * (k + 1) / 8.0
				for v in [a, a + Vector3(cos(a0), 0, sin(a0)) * r, a + Vector3(cos(a1), 0, sin(a1)) * r]:
					im.surface_set_color(dot)
					im.surface_add_vertex(v)
		s += 2.0
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
