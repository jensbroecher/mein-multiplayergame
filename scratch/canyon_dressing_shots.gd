extends Node

# Shots of the Canyon Course's roadside dressing, aimed from the level itself, so they follow the props
# when the generator moves them. Run windowed:
#   Godot --path . res://scratch/canyon_dressing_shots.tscn -- <out_dir> [level=res://levels/CanyonLevel.tscn]
#       [only=signs,kickers,start,windmill,parador,lines] [name:x,y,z:tx,ty,tz[:fov] ...]
# signs: each SectionSigns label from up the road and from the side; kickers: each BajadaKickers mesh from
# beside the trail; start: the start/finish area (FinishLine) from above and from the grid; windmill: the
# Parador's windmill (ParadorWindmill), two frames a second apart so a turning rotor shows; parador: the
# Parador's corners up close, in its own frame (found from the windmill's node); lines: the power line where
# it leaves the road ([line_s=2459], metres along the lap) and its run west over the canyon wall.

const SIZE := Vector2i(1376, 768)

var _vp: SubViewport
var _cam: Camera3D
var _out := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var level_path := "res://levels/CanyonLevel.tscn"
	var only := PackedStringArray(["signs", "kickers", "start", "windmill", "parador", "lines"])
	var extra: Array = []
	var line_s := 2459.0
	for a in args.slice(1):
		if a.begins_with("level="):
			level_path = a.substr(6)
		elif a.begins_with("line_s="):
			line_s = float(a.substr(7))
		elif a.begins_with("only="):
			only = a.substr(5).split(",")
		elif ":" in a:
			extra.append(a)
	AudioServer.set_bus_mute(0, true)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var level: Node3D = load(level_path).instantiate()
	_vp.add_child(level)
	MusicManager.set_shadow_quality(3, false)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.far = 4000.0
	_vp.add_child(_cam)
	_cam.make_current()
	for i in 40:
		await get_tree().process_frame
	if "signs" in only:
		var signs := level.get_node_or_null("SectionSigns")
		var k := 0
		if signs:
			for lab in signs.find_children("*", "Label3D", true, false):
				var l := lab as Label3D
				var p := l.global_position
				var n := l.global_basis.z
				n.y = 0.0
				n = n.normalized()
				var side := Vector3.UP.cross(n).normalized()
				await _shot("sign%d_front" % k, p + n * 20.0 + side * 3.0 + Vector3.UP * 1.0, p - Vector3.UP * 1.2)
				await _shot("sign%d_side" % k, p + side * 16.0 + n * 6.0 + Vector3.UP * 0.5, p - Vector3.UP * 1.2)
				print("SIGN %d '%s' at %s" % [k, l.text, p])
				k += 1
	if "kickers" in only:
		var kk := level.get_node_or_null("BajadaKickers")
		var k := 0
		if kk:
			for mi in kk.find_children("Kicker*", "MeshInstance3D", true, false):
				var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
				var c := bb.get_center()
				await _shot("kicker%d_a" % k, c + Vector3(14.0, 5.0, 10.0), c)
				await _shot("kicker%d_b" % k, c + Vector3(-14.0, 4.0, -10.0), c)
				k += 1
	if "start" in only:
		var fl := level.get_node_or_null("FinishLine") as Node3D
		if fl:
			var p := fl.global_position
			var f := -fl.global_basis.z
			var r := fl.global_basis.x
			await _shot("start_high", p - f * 45.0 + Vector3.UP * 28.0, p + f * 20.0)
			await _shot("start_grid", p - f * 22.0 + Vector3.UP * 3.0, p + f * 10.0 + Vector3.UP * 2.0)
			await _shot("start_left", p + f * 25.0 - r * 30.0 + Vector3.UP * 9.0, p)
			await _shot("start_right", p + f * 25.0 + r * 30.0 + Vector3.UP * 9.0, p)
			await _shot("start_top", p + Vector3.UP * 110.0 + f * 0.1, p, 70.0)
	if "windmill" in only:
		var wm := level.find_child("ParadorWindmill", true, false) as Node3D
		if wm:
			# The node sits on the wheel's hub, the wheel facing its -z.
			var p := wm.global_position
			var eye := p - wm.global_basis.z * 14.0 + wm.global_basis.x * 6.0 - Vector3.UP * 3.0
			await _shot("windmill_0", eye, p, 40.0)
			for i in 60:
				await get_tree().process_frame
			await _shot("windmill_1", eye, p, 40.0)
	if "parador" in only:
		var wm2 := level.find_child("ParadorWindmill", true, false) as Node3D
		if wm2:
			# regenerate_canyon.gd: the windmill sits at WINDMILL_BASE + WINDMILL_HUB in the Parador's frame
			# (x along the road, z away from it, life size grown by PROP_SCALE 1.6).
			var b := wm2.global_basis.orthonormalized()
			var o: Vector3 = wm2.global_position - b * (Vector3(31.0, 10.6, 16.1) * 1.6)
			var at := func(v: Vector3) -> Vector3: return o + b * (v * 1.6)
			for sh in [["parador_patio", Vector3(23.0, 2.6, -19.0), Vector3(29.0, 0.8, -11.5)],
					["parador_patio_close", Vector3(25.5, 1.6, -14.5), Vector3(28.0, 0.6, -11.5)],
					["parador_pumps", Vector3(-1.0, 2.6, -21.0), Vector3(-8.0, 1.2, -11.5)],
					["parador_shop", Vector3(6.0, 2.4, -17.0), Vector3(11.0, 1.4, -7.0)],
					["parador_workshop", Vector3(-22.0, 2.6, -16.0), Vector3(-30.0, 1.4, -6.0)],
					["parador_motel", Vector3(-8.0, 3.0, 2.0), Vector3(-22.0, 1.4, 15.0)],
					["parador_back", Vector3(12.0, 3.0, 4.0), Vector3(22.0, 2.0, 16.0)],
					["parador_overview", Vector3(-10.0, 30.0, -55.0), Vector3(0.0, 0.0, 0.0)],
					["parador_drops", Vector3(10.0, 7.0, -36.0), Vector3(22.0, 4.0, -14.0)],
					["parador_islands", Vector3(-2.5, 1.7, -14.0), Vector3(-8.0, 1.0, -9.5)],
					["parador_shopfront", Vector3(10.0, 1.8, -15.5), Vector3(11.0, 0.8, -11.5)]]:
				await _shot(sh[0], at.call(sh[1]), at.call(sh[2]), 60.0)
	if "lines" in only:
		# The power line: where it leaves the road (line_s=, metres along the lap, 17m right of it) from the
		# road and from above, and its far run west over the canyon wall.
		var track := level.get_node_or_null("TrackPath") as Path3D
		if track:
			var c: Curve3D = track.curve
			var off: float = line_s
			var p: Vector3 = track.to_global(c.sample_baked(off))
			var ahead: Vector3 = track.to_global(c.sample_baked(off + 2.0))
			var f: Vector3 = (ahead - p)
			f.y = 0.0
			f = f.normalized()
			var r: Vector3 = f.cross(Vector3.UP)
			var pole: Vector3 = p + r * 17.0
			await _shot("line_turn", p - f * 40.0 + Vector3.UP * 6.0 - r * 4.0, pole + Vector3.UP * 6.0, 60.0)
			await _shot("line_turn_high", pole - f * 50.0 - r * 30.0 + Vector3.UP * 45.0, pole + r * 60.0, 60.0)
			await _shot("line_wall", pole + f * 30.0 + Vector3.UP * 12.0, pole + r * 130.0 + Vector3.UP * 20.0, 55.0)
	for a in extra:
		var parts: PackedStringArray = (a as String).split(":")
		var pp := parts[1].split(",")
		var t := parts[2].split(",")
		await _shot(parts[0], Vector3(float(pp[0]), float(pp[1]), float(pp[2])), Vector3(float(t[0]), float(t[1]), float(t[2])), float(parts[3]) if parts.size() > 3 else 62.0)
	get_tree().quit()


func _shot(nm: String, from: Vector3, at: Vector3, fov := 62.0) -> void:
	_cam.fov = fov
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	for i in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_vp.get_texture().get_image().save_png("%s/%s.png" % [_out, nm])
	print("SHOT ", nm)
