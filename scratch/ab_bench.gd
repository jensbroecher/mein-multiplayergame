extends Node

# A/B frame-time benchmark: toggles variants back and forth at the same camera spot inside one run,
# so GPU clock and thermal drift between runs can't masquerade as a difference.
# Run windowed (not headless):
#   Godot --path . res://scratch/ab_bench.tscn -- res://levels/X.tscn [samples=6] [shadows=3]
#        variant ...
# Variants: base, storm (Northlight blizzard at full strength), noshadow, nolightshadow, noomni, nospot, nomoonshadow, sky=<shader path>,
#           hide=<path substring>, unshadow=<path substring> (shadow off on matching lights), cheapmat=<path substring> (unshaded grey on matching meshes).
# Several toggles can be combined into one variant with '+', e.g. nolightshadow+sky=res://x.gdshader.

var level_path := ""
var samples := 6
var shadow_q := 3
var variants: Array[String] = []
var level: Node3D
var _orig_sky_shader: Shader
var _undo: Array[Callable] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("res://"): level_path = a
		elif a.begins_with("samples="): samples = int(a.substr(8))
		elif a.begins_with("shadows="): shadow_q = int(a.substr(8))
		else: variants.append(a)
	if not variants.has("base"):
		variants.push_front("base")
	AudioServer.set_bus_mute(0, true)
	MusicManager.window_mode = 0
	MusicManager.resolution_index = 0
	for i in 5:
		await get_tree().process_frame
	var win := get_window()
	win.mode = Window.MODE_WINDOWED
	win.size = Vector2i(1600, 1000)
	for i in 5:
		await get_tree().process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)

	level = load(level_path).instantiate()
	add_child(level)
	MusicManager.set_shadow_quality(shadow_q, false)
	if level.get_node_or_null("NorthlightWeather"):
		level.get_node("NorthlightWeather").force_intensity = 0.0
	var env: WorldEnvironment = level.find_child("WorldEnvironment", true, false)
	if env and env.environment.sky and env.environment.sky.sky_material is ShaderMaterial:
		_orig_sky_shader = (env.environment.sky.sky_material as ShaderMaterial).shader

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
	print("AB ", level_path, " tex=", vp.get_texture().get_size(), " variants=", variants)

	var totals := {}
	for v in variants:
		totals[v] = 0.0
	for s in samples:
		var off := length * (float(s) + 0.5) / float(samples)
		var xf := path.global_transform * curve.sample_baked_with_rotation(off, true)
		var p := xf.origin
		var fwd := -xf.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		cam.global_position = p - fwd * 6.0 + Vector3.UP * 2.6
		cam.look_at(p + fwd * 8.0 + Vector3.UP * 0.8, Vector3.UP)
		var line := "  s%02d" % s
		# Two passes over the variants; the first also warms up shader compiles.
		var best := {}
		for rep in 3:
			for v in variants:
				_apply(v)
				for i in 12:
					await get_tree().process_frame
				var g := 0.0
				for i in 30:
					await get_tree().process_frame
					g += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
				g /= 30.0
				_revert()
				if rep > 0:
					best[v] = minf(best.get(v, 1e9), g)
		for v in variants:
			totals[v] += best[v]
			line += "  %s=%.2f" % [v, best[v]]
		print(line)
	var base: float = totals["base"] / samples
	for v in variants:
		var avg: float = totals[v] / samples
		print("AVG %-40s %.2fms  (%+.2f vs base)" % [v, avg, avg - base])
	get_tree().quit()


func _process(_delta: float) -> void:
	# Drives the aurora clock the way the level does, so a global-uniform sky animates here too.
	RenderingServer.global_shader_parameter_set(&"aurora_clock", Time.get_ticks_msec() * 0.001)


func _apply(variant: String) -> void:
	for part in variant.split("+"):
		_apply_one(part)


func _apply_one(v: String) -> void:
	if v == "base":
		return
	if v == "storm":
		var w: Node = level.get_node_or_null("NorthlightWeather")
		if w:
			w.force_intensity = 1.0
			_undo.append(func(): w.force_intensity = 0.0)
		return
	for n in level.find_children("*", "", true, false):
		var path := str(level.get_path_to(n))
		if v == "noshadow" and n is Light3D and n.shadow_enabled:
			n.shadow_enabled = false
			_undo.append(func(): n.shadow_enabled = true)
		elif v == "nolightshadow" and (n is OmniLight3D or n is SpotLight3D) and n.shadow_enabled:
			n.shadow_enabled = false
			_undo.append(func(): n.shadow_enabled = true)
		elif v == "nomoonshadow" and n is DirectionalLight3D and n.shadow_enabled:
			n.shadow_enabled = false
			_undo.append(func(): n.shadow_enabled = true)
		elif v == "noomni" and n is OmniLight3D and n.visible:
			n.visible = false
			_undo.append(func(): n.visible = true)
		elif v == "nospot" and n is SpotLight3D and n.visible:
			n.visible = false
			_undo.append(func(): n.visible = true)
		elif v.begins_with("unshadow=") and n is Light3D and path.contains(v.substr(9)) and n.shadow_enabled:
			n.shadow_enabled = false
			_undo.append(func(): n.shadow_enabled = true)
		elif v.begins_with("hide=") and n is Node3D and path.contains(v.substr(5)) and n.visible:
			n.visible = false
			_undo.append(func(): n.visible = true)
		elif v.begins_with("cheapmat=") and n is GeometryInstance3D and path.contains(v.substr(9)):
			var old: Material = n.material_override
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_color = Color(0.5, 0.55, 0.6)
			n.material_override = m
			_undo.append(func(): n.material_override = old)
		elif v.begins_with("sky=") and n is WorldEnvironment:
			var mat := n.environment.sky.sky_material as ShaderMaterial
			mat.shader = load(v.substr(4))
			_undo.append(func(): mat.shader = _orig_sky_shader)


func _revert() -> void:
	for f in _undo:
		f.call()
	_undo.clear()
