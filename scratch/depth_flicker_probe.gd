extends Node

# Tells depth-precision flicker (z-fighting) from everything else. Each view is rendered in the same frame by
# four cameras sharing the level's world, so anything animated (TIME) is the same in all four:
#   A  near = 0.05 (the race cameras' default)   at the spot
#   B  near = 0.05                               3cm to the camera's right
#   C  near = `near` (default 1.0)               at the spot
#   D  near = `near`                             3cm to the camera's right
# A against C differs only where the depth buffer can't separate two surfaces (precision); A against B is
# what flickers as the camera moves at the default near, C against D at the larger one (parallax edges are
# thin lines in both, z-fighting shows as blocks). Prints the driver, the adapter, whether the GPU takes a
# D24 depth buffer (Godot's Mobile renderer prefers it, and Apple Silicon has none, so Macs get D32 float),
# and per view the share of pixels that differ; writes <name>_A.png, _C.png and the diffs (_AC, _AB, _CD).
# Run windowed:
#   Godot --path . --resolution 1600x900 res://scratch/depth_flicker_probe.tscn -- <out_dir>
#       [level=res://levels/NyotaStadiumLevel.tscn] [near=1.0] [msaa=4] [size=1600x900] [fov=70]
#       [chase=<s>,<s>,...] [back=14] [up=10] [ahead=20] [hide=<node name fragment>] name:x,y,z:tx,ty,tz ...
# chase=s puts the camera as the High Chase does (back along the lap, up, looking at the road ahead).

const SHIFT := 0.03
const DIFF_MIN := 0.10

var _vps: Array[SubViewport] = []
var _cams: Array[Camera3D] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir := args[0]
	var level_path := "res://levels/NyotaStadiumLevel.tscn"
	var near_b := 1.0
	var msaa := 4
	var size := Vector2i(1600, 900)
	var fov := 70.0
	var back := 14.0
	var up := 10.0
	var ahead := 20.0
	var chase: Array = []
	var hides: Array = []
	for a in args.slice(1):
		if a.begins_with("level="): level_path = a.substr(6)
		elif a.begins_with("near="): near_b = float(a.substr(5))
		elif a.begins_with("msaa="): msaa = int(a.substr(5))
		elif a.begins_with("fov="): fov = float(a.substr(4))
		elif a.begins_with("back="): back = float(a.substr(5))
		elif a.begins_with("up="): up = float(a.substr(3))
		elif a.begins_with("ahead="): ahead = float(a.substr(6))
		elif a.begins_with("hide="): hides.append(a.substr(5))
		elif a.begins_with("size="):
			var wh := a.substr(5).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("chase="):
			for s in a.substr(6).split(","):
				chase.append(float(s))
	AudioServer.set_bus_mute(0, true)
	print("DRIVER ", RenderingServer.get_current_rendering_driver_name(), " / ", RenderingServer.get_video_adapter_name(),
		" / ", RenderingServer.get_video_adapter_api_version())
	var rd := RenderingServer.get_rendering_device()
	if rd != null:
		var usage := RenderingDevice.TEXTURE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		print("D24_UNORM_S8 supported: ", rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_D24_UNORM_S8_UINT, usage),
			"  D32_SFLOAT_S8 supported: ", rd.texture_is_format_supported_for_usage(RenderingDevice.DATA_FORMAT_D32_SFLOAT_S8_UINT, usage))
	var level: Node3D = load(level_path).instantiate()
	add_child(level)
	MusicManager.set_shadow_quality(3, false)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		n.visible = false
	var nears := [0.05, 0.05, near_b, near_b]
	for i in 4:
		var vp := SubViewport.new()
		vp.size = size
		vp.msaa_3d = {2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X, 8: Viewport.MSAA_8X}.get(msaa, Viewport.MSAA_DISABLED)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = fov
		cam.near = nears[i]
		cam.far = 4000.0
		vp.add_child(cam)
		cam.make_current()
		_vps.append(vp)
		_cams.append(cam)
	for i in 10:
		await get_tree().physics_frame
	for frag in hides:
		for n in level.find_children("*" + frag + "*", "Node3D", true, false):
			n.visible = false
	var shots: Array = []
	var path: Path3D = level.get_node_or_null("TrackPath")
	for s in chase:
		if path == null:
			push_error("no TrackPath for chase=")
			break
		var curve := path.curve
		var len := curve.get_baked_length()
		var p: Vector3 = path.to_global(curve.sample_baked(fposmod(s, len)))
		var q: Vector3 = path.to_global(curve.sample_baked(fposmod(s + 2.0, len)))
		var fwd := Vector3(q.x - p.x, 0, q.z - p.z).normalized()
		shots.append(["chase%d" % int(s), p - fwd * back + Vector3.UP * up, p + fwd * ahead])
	for a in args.slice(1):
		if a.contains("=") or not a.contains(":"):
			continue
		var parts := a.split(":")
		var pp := parts[1].split(",")
		var tt := parts[2].split(",")
		shots.append([parts[0], Vector3(float(pp[0]), float(pp[1]), float(pp[2])), Vector3(float(tt[0]), float(tt[1]), float(tt[2]))])
	for shot in shots:
		var pos: Vector3 = shot[1]
		var target: Vector3 = shot[2]
		for i in 4:
			_cams[i].global_position = pos
			_cams[i].look_at(target, Vector3.UP)
			if i % 2 == 1:
				_cams[i].global_position += _cams[i].global_basis.x * SHIFT
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var imgs: Array[Image] = []
		for vp in _vps:
			imgs.append(vp.get_texture().get_image())
		var name: String = shot[0]
		imgs[0].save_png("%s/%s_A.png" % [out_dir, name])
		imgs[2].save_png("%s/%s_C.png" % [out_dir, name])
		var ac := _diff(imgs[0], imgs[2], "%s/%s_AC.png" % [out_dir, name])
		var ab := _diff(imgs[0], imgs[1], "%s/%s_AB.png" % [out_dir, name])
		var cd := _diff(imgs[2], imgs[3], "%s/%s_CD.png" % [out_dir, name])
		print("VIEW %s at %s: precision (A/C) %.2f%%   moving 3cm near 0.05 (A/B) %.2f%%   near %.2f (C/D) %.2f%%" % [name, pos, ac, ab, near_b, cd])
	get_tree().quit()


## The share of pixels (in %) whose colour differs by more than DIFF_MIN in any channel; writes a mask image:
## the first picture dimmed, differing pixels red.
func _diff(a: Image, b: Image, path: String) -> float:
	var w := a.get_width()
	var h := a.get_height()
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	var n := 0
	for y in h:
		for x in w:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b)))
			if d > DIFF_MIN:
				n += 1
				out.set_pixel(x, y, Color(1, 0, 0))
			else:
				out.set_pixel(x, y, ca * 0.35)
	out.save_png(path)
	return 100.0 * float(n) / float(w * h)
