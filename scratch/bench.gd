extends Node

const MeshChunker = preload("res://MeshChunker.gd")

# Frame-time benchmark for one level, with the game's autoloads and the player's shadow settings.
# Run windowed (not headless):
#   Godot --path . res://scratch/bench.tscn -- res://levels/X.tscn [samples=24] [scale=1.0] [shadows=3]
#        [hide=<path substring>]... [shot=<dir>] [omni=0] [spot=0] [sky=<process mode>] [skyshader=<path>] [snow=0]
# Prints per-sample GPU ms / CPU ms / primitives / draw calls, then the averages.

var level_path := ""
var samples := 24
var render_scale := 1.0
var shadow_q := 3
var hides: Array[String] = []
var shot_dir := ""
var omni_on := true
var spot_on := true
var sky_mode := -1
var sky_shader := ""
var snow_on := true
var chunk_cell := 0.0
var probe := Vector2(-1, -1)
var probe_sample := -1
var win_size := Vector2i(1600, 1000)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("res://"): level_path = a
		elif a.begins_with("samples="): samples = int(a.substr(8))
		elif a.begins_with("scale="): render_scale = float(a.substr(6))
		elif a.begins_with("shadows="): shadow_q = int(a.substr(8))
		elif a.begins_with("hide="): hides.append(a.substr(5))
		elif a.begins_with("shot="): shot_dir = a.substr(5)
		elif a == "omni=0": omni_on = false
		elif a == "spot=0": spot_on = false
		elif a.begins_with("sky="): sky_mode = int(a.substr(4))
		elif a.begins_with("skyshader="): sky_shader = a.substr(10)
		elif a == "snow=0": snow_on = false
		elif a.begins_with("chunk="): chunk_cell = float(a.substr(6))
		elif a.begins_with("probe="):
			var pr := a.substr(6).split(",")
			probe_sample = int(pr[0]); probe = Vector2(float(pr[1]), float(pr[2]))
	AudioServer.set_bus_mute(0, true)
	# MusicManager applies its window settings deferred; point them at a fixed window first.
	MusicManager.window_mode = 0
	MusicManager.resolution_index = 0
	for i in 5:
		await get_tree().process_frame
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = win_size
	for i in 5:
		await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := get_viewport()
	vp.scaling_3d_scale = render_scale
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)

	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	MusicManager.set_shadow_quality(shadow_q, false)
	_apply_experiments(level)

	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 4000.0
	add_child(cam)
	cam.make_current()

	var path: Path3D = level.get_node_or_null("TrackPath")
	var curve := path.curve
	var length := curve.get_baked_length()
	for i in 20:
		await get_tree().process_frame
	print("BENCH ", level_path, " win=", win.size, " tex=", vp.get_texture().get_size(), " scale=", render_scale, " args=", OS.get_cmdline_user_args())
	var tot_gpu := 0.0
	var tot_cpu := 0.0
	var tot_prims := 0.0
	var tot_draws := 0.0
	var worst_gpu := 0.0
	var tot_sh := 0.0
	var tot_vis := 0.0
	for s in samples:
		var off := length * (float(s) + 0.5) / float(samples)
		var xf := path.global_transform * curve.sample_baked_with_rotation(off, true)
		var p := xf.origin
		var fwd := -xf.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		cam.global_position = p - fwd * 6.0 + Vector3.UP * 2.6
		cam.look_at(p + fwd * 8.0 + Vector3.UP * 0.8, Vector3.UP)
		for i in 15:
			await get_tree().process_frame
		if s == probe_sample:
			var tex_size := Vector2(vp.get_texture().get_size())
			var vis := vp.get_visible_rect().size
			var pt := probe / tex_size * vis
			var o := cam.project_ray_origin(pt)
			var d := cam.project_ray_normal(pt)
			for n in level.find_children("*", "GeometryInstance3D", true, false):
				if not n.is_visible_in_tree(): continue
				var aabb: AABB = n.global_transform * n.get_aabb()
				if aabb.intersects_ray(o, d) != null:
					var mat = n.material_override if n.material_override else (n.mesh.surface_get_material(0) if n is MeshInstance3D and n.mesh else null)
					print("PROBE ", level.get_path_to(n), " dist=", (aabb.get_center() - o).length(), " mat=", mat.shader.resource_path if mat is ShaderMaterial else mat)
		var g := 0.0
		var c := 0.0
		var n := 40
		var t0 := Time.get_ticks_usec()
		for i in n:
			await get_tree().process_frame
			g += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
		c = (Time.get_ticks_usec() - t0) / 1000.0 / n
		g /= n
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var sh_prims := vp.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		var vis_prims := vp.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)
		tot_sh += sh_prims; tot_vis += vis_prims
		print("  s%02d gpu=%.2fms frame=%.2fms prims=%dk (vis %dk, shadow %dk) draws=%d" % [s, g, c, prims / 1000, vis_prims / 1000, sh_prims / 1000, draws])
		tot_gpu += g; tot_cpu += c; tot_prims += prims; tot_draws += draws
		worst_gpu = max(worst_gpu, g)
		if shot_dir != "" and s % 4 == 0:
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("%s/s%02d.png" % [shot_dir, s])
	print("AVG gpu=%.2fms worst_gpu=%.2fms frame=%.2fms prims=%dk (vis %dk, shadow %dk) draws=%d" % [tot_gpu / samples, worst_gpu, tot_cpu / samples, tot_prims / samples / 1000, tot_vis / samples / 1000, tot_sh / samples / 1000, tot_draws / samples])
	get_tree().quit()


func _apply_experiments(level: Node) -> void:
	if chunk_cell > 0.0:
		var t0 := Time.get_ticks_msec()
		var n_chunked := 0
		for mi in level.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh and mi.mesh.resource_path.begins_with("res://generated/"):
				if MeshChunker.chunk_instance(mi, chunk_cell) != mi:
					n_chunked += 1
		print("chunked ", n_chunked, " meshes in ", Time.get_ticks_msec() - t0, "ms")
	for n in level.find_children("*", "", true, false):
		var p := str(level.get_path_to(n))
		for h in hides:
			if p.contains(h) and n is Node3D:
				n.visible = false
		if n is OmniLight3D and not omni_on: n.visible = false
		if n is SpotLight3D and not spot_on: n.visible = false
		if n is GPUParticles3D and not snow_on and n.name == "FallingSnow": n.visible = false
		if n is WorldEnvironment and sky_mode >= 0 and n.environment.sky:
			n.environment.sky.process_mode = sky_mode
		if n is WorldEnvironment and sky_shader != "" and n.environment.sky:
			(n.environment.sky.sky_material as ShaderMaterial).shader = load(sky_shader)
