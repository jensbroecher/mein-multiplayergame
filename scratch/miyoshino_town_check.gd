extends SceneTree
## Checks the Miyoshino great gate's corridor on its built triangles (headless):
##   Godot --headless --path . -s res://scratch/miyoshino_town_check.gd [-- x=4.3 y=6.6 beyond=3.0]
## Builds MiyoshinoTownKit.great_gate at life size and FAILS if any triangle reaches into |x| < x, y < y, through the
## gate's whole depth and `beyond` metres past both faces. Prints the nearest things to the corridor too.

func _init() -> void:
	var cx := 4.3
	var cy := 6.6
	var beyond := 3.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("x="):
			cx = float(a.substr(2))
		elif a.begins_with("y="):
			cy = float(a.substr(2))
		elif a.begins_with("beyond="):
			beyond = float(a.substr(7))
	var K: Object = load("res://MiyoshinoTownKit.gd")
	var pk = K.call("new_kit", 1.0)
	var kit := {}
	K.call("great_gate", pk, kit, [])
	var bad := 0
	var total := 0
	var zmax := 0.0
	var all: Array = []
	for key in kit.keys():
		var st: SurfaceTool = kit[key]
		var arr: Array = st.commit_to_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var n: int = (idx as PackedInt32Array).size() if idx != null and (idx as PackedInt32Array).size() > 0 else v.size()
		for i in range(0, n, 3):
			var a: Vector3 = v[idx[i]] if idx != null and (idx as PackedInt32Array).size() > 0 else v[i]
			var b: Vector3 = v[idx[i + 1]] if idx != null and (idx as PackedInt32Array).size() > 0 else v[i + 1]
			var c: Vector3 = v[idx[i + 2]] if idx != null and (idx as PackedInt32Array).size() > 0 else v[i + 2]
			all.append([a, b, c, key])
			zmax = maxf(zmax, maxf(absf(a.z), maxf(absf(b.z), absf(c.z))))
	var lo := Vector3(-cx, -50.0, -zmax - beyond)
	var hi := Vector3(cx, cy, zmax + beyond)
	var near_x := 99.0
	var near_y := 99.0
	for t in all:
		total += 1
		var a: Vector3 = t[0]
		var b: Vector3 = t[1]
		var c: Vector3 = t[2]
		if _tri_box(a, b, c, lo, hi):
			bad += 1
			if bad <= 12:
				print("  IN CORRIDOR (%s): %s %s %s" % [t[3], a.snappedf(0.01), b.snappedf(0.01), c.snappedf(0.01)])
		# The margins: the lowest thing over the road, the nearest thing beside it.
		if minf(absf(a.x), minf(absf(b.x), absf(c.x))) < cx and _tri_box(a, b, c, Vector3(-cx, -50, lo.z), Vector3(cx, 99, hi.z)):
			near_y = minf(near_y, minf(a.y, minf(b.y, c.y)))
		if minf(a.y, minf(b.y, c.y)) < cy:
			for p in [a, b, c]:
				if (p as Vector3).y < cy:
					near_x = minf(near_x, absf((p as Vector3).x))
	print("gate: %d triangles, depth +-%.2f; corridor |x| < %.2f, y < %.2f, |z| < %.2f" % [total, zmax, cx, cy, zmax + beyond])
	print("lowest thing over the road: y %.3f; nearest vertex under %.1f: |x| %.3f" % [near_y, cy, near_x])
	print("PASS" if bad == 0 else "FAIL: %d triangles reach into the corridor" % bad)
	quit(0 if bad == 0 else 1)


## Triangle against an axis-aligned box (separating axes; touching the box's faces does not count).
func _tri_box(a: Vector3, b: Vector3, c: Vector3, lo: Vector3, hi: Vector3) -> bool:
	var ctr: Vector3 = (lo + hi) * 0.5
	var h: Vector3 = (hi - lo) * 0.5 - Vector3.ONE * 1e-4
	var v: Array = [a - ctr, b - ctr, c - ctr]
	var e: Array = [v[1] - v[0], v[2] - v[1], v[0] - v[2]]
	var axes: Array = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for ax in axes:
		var mn: float = minf((v[0] as Vector3).dot(ax), minf((v[1] as Vector3).dot(ax), (v[2] as Vector3).dot(ax)))
		var mx: float = maxf((v[0] as Vector3).dot(ax), maxf((v[1] as Vector3).dot(ax), (v[2] as Vector3).dot(ax)))
		var r: float = h.dot((ax as Vector3).abs())
		if mn > r or mx < -r:
			return false
	var n: Vector3 = (e[0] as Vector3).cross(e[1])
	if absf(n.dot(v[0])) > h.dot(n.abs()):
		return false
	for ax in axes:
		for ed in e:
			var s: Vector3 = (ax as Vector3).cross(ed)
			if s.length_squared() < 1e-12:
				continue
			var p0: float = (v[0] as Vector3).dot(s)
			var p1: float = (v[1] as Vector3).dot(s)
			var p2: float = (v[2] as Vector3).dot(s)
			var r2: float = h.dot(s.abs())
			if minf(p0, minf(p1, p2)) > r2 or maxf(p0, maxf(p1, p2)) < -r2:
				return false
	return true
