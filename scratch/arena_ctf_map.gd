extends SceneTree
## A hillshaded plan of the capture-the-flag arena's ground (regenerate_arena_ctf.gd's `_h`), the bots' graph over it:
## -s res://scratch/arena_ctf_map.gd -- <out.png> [cell=1.5]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var gen = load("res://regenerate_arena_ctf.gd").new()
	gen.setup_layout()
	gen._plan_nav()
	var n := 540
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var cell := 1.0
	for j in n:
		for i in n:
			var x := -270.0 + i * cell
			var z := -270.0 + j * cell
			var h: float = gen._h(x, z)
			var hx: float = gen._h(x + 1.0, z) - h
			var hz: float = gen._h(x, z + 1.0) - h
			var shade := clampf(0.6 - hx * 0.6 - hz * 0.6, 0.1, 1.0)
			var t := clampf((h + 10.0) / 40.0, 0.0, 1.0)
			var c := Color(0.2, 0.5, 0.25).lerp(Color(0.95, 0.85, 0.6), t) * shade
			if h < 0.0:
				c = Color(0.2, 0.3, 0.7) * shade
			img.set_pixel(i, j, c)
	var pts: PackedVector3Array = gen.nav_pts
	var links: PackedInt32Array = gen.nav_links
	var k := 0
	while k + 2 < links.size():
		var a: Vector3 = pts[links[k]]
		var b: Vector3 = pts[links[k + 1]]
		for s in 60:
			var p := a.lerp(b, s / 60.0)
			var px := int(p.x + 270.0)
			var pz := int(p.z + 270.0)
			if px >= 0 and px < n and pz >= 0 and pz < n:
				img.set_pixel(px, pz, Color(1, 0, 0) if links[k + 2] == 1 else Color(1, 1, 1))
		k += 3
	img.save_png(out)
	print("MAP ", out)
	quit()
