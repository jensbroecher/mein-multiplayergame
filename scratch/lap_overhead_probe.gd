extends SceneTree

# Lists what is drawn over a level's lap: every triangle of every MeshInstance3D sampled about every metre, each point
# measured against the TrackPath (its lateral distance and its height over the lap's line there). Points within `half`
# of the line and between `low` and `high` over it are counted per node, split into what a cart hits (under `cart`
# metres) and what only the race camera passes through. For finding beams across the road. Headless:
#   Godot --headless --path . -s res://scratch/lap_overhead_probe.gd -- <level.tscn> [half=7.5] [low=0.3] [cart=6]
#       [high=14] [step=2] [skip=Gate,Checkpoint,...] [detail=<node name part>] [mm=1]
# Prints, per node: points under `cart`, points above it, the lowest height and the lap's s range it spans; with detail=,
# for the nodes whose path holds it, every 10m of lap: the lowest height and how far across the road (left, right) it reaches.
# mm=1 takes in MultiMeshInstance3Ds too (their instances read from the buffer: the dummy renderer returns no transforms).

const CELL := 10.0

var _pos := PackedVector3Array()
var _fwd := PackedVector3Array()
var _grid := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	var half := 7.5
	var low := 0.3
	var cart := 6.0
	var high := 14.0
	var step := 2.0
	var detail := ""
	var with_mm := false
	var skip: Array = ["FinishLine", "Checkpoint", "Halfway", "StartLine", "BoostPad", "ItemBox", "Spawn"]
	for a in args.slice(1):
		var kv: PackedStringArray = a.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"half": half = float(kv[1])
			"low": low = float(kv[1])
			"cart": cart = float(kv[1])
			"high": high = float(kv[1])
			"step": step = float(kv[1])
			"skip": skip.append_array(kv[1].split(","))
			"detail": detail = kv[1]
			"mm": with_mm = kv[1] == "1"
	var level: Node3D = load(level_path).instantiate()
	root.add_child(level)
	await process_frame
	var path: Path3D = level.get_node_or_null("TrackPath")
	if path == null:
		print("no TrackPath")
		quit()
		return
	var curve: Curve3D = path.curve
	var length: float = curve.get_baked_length()
	var s := 0.0
	while s < length:
		var p: Vector3 = path.global_transform * curve.sample_baked(s)
		var q: Vector3 = path.global_transform * curve.sample_baked(minf(s + 1.0, length))
		var f: Vector3 = q - p
		f.y = 0.0
		_pos.append(p)
		_fwd.append(f.normalized() if f.length() > 0.01 else Vector3.FORWARD)
		var k := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		# Packed arrays are values: append to the dictionary's own copy and put it back.
		var cell: PackedInt32Array = _grid.get(k, PackedInt32Array())
		cell.append(_pos.size() - 1)
		_grid[k] = cell
		s += step
	print("lap %.0fm, %d samples" % [length, _pos.size()])
	var found := {}
	var meshes: Array = level.find_children("*", "MeshInstance3D", true, false)
	var jobs: Array = []
	for mi in meshes:
		var m: MeshInstance3D = mi
		if m.mesh != null and m.is_visible_in_tree():
			jobs.append([str(level.get_path_to(m)), m.mesh, m.global_transform])
	if with_mm:
		for mmi in level.find_children("*", "MultiMeshInstance3D", true, false):
			var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			if mm == null or mm.mesh == null or not (mmi as Node3D).is_visible_in_tree() or mm.transform_format != MultiMesh.TRANSFORM_3D:
				continue
			var buf: PackedFloat32Array = mm.buffer
			var stride: int = 12 + (4 if mm.use_colors else 0) + (4 if mm.use_custom_data else 0)
			var gx: Transform3D = (mmi as Node3D).global_transform
			var count: int = mini(mm.instance_count, buf.size() / stride)
			for k in count:
				var o: int = k * stride
				var t := Transform3D(Basis(Vector3(buf[o], buf[o + 4], buf[o + 8]), Vector3(buf[o + 1], buf[o + 5], buf[o + 9]), Vector3(buf[o + 2], buf[o + 6], buf[o + 10])),
						Vector3(buf[o + 3], buf[o + 7], buf[o + 11]))
				jobs.append(["%s[%d]" % [str(level.get_path_to(mmi)), k], mm.mesh, gx * t])
	var tested := 0
	for job in jobs:
		var npath: String = job[0]
		var mesh: Mesh = job[1]
		var skipped := false
		for w in skip:
			if w in npath:
				skipped = true
				break
		if skipped:
			continue
		var xf: Transform3D = job[2]
		var box: AABB = xf * mesh.get_aabb()
		if not _near_lap(box.position.x - half, box.end.x + half, box.position.z - half, box.end.z + half):
			continue
		tested += 1
		for si in range(mesh.get_surface_count()):
			if mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr: Array = mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var n: int = idx.size() if idx.size() > 0 else verts.size()
			var t := 0
			while t + 2 < n:
				var a: Vector3 = xf * verts[idx[t] if idx.size() > 0 else t]
				var b: Vector3 = xf * verts[idx[t + 1] if idx.size() > 0 else t + 1]
				var c: Vector3 = xf * verts[idx[t + 2] if idx.size() > 0 else t + 2]
				t += 3
				var x0: float = minf(a.x, minf(b.x, c.x))
				var x1: float = maxf(a.x, maxf(b.x, c.x))
				var z0: float = minf(a.z, minf(b.z, c.z))
				var z1: float = maxf(a.z, maxf(b.z, c.z))
				if not _near_lap(x0 - half, x1 + half, z0 - half, z1 + half):
					continue
				var e: float = maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a)))
				var k: int = clampi(int(ceil(e / 1.0)), 1, 80)
				for i in range(k + 1):
					for j in range(k + 1 - i):
						var u: float = float(i) / float(k)
						var v: float = float(j) / float(k)
						var p: Vector3 = a + (b - a) * u + (c - a) * v
						var hit: Array = _measure(p, half)
						if hit.is_empty():
							continue
						var h: float = hit[1]
						if h < low or h > high:
							continue
						if not found.has(npath):
							found[npath] = {"low": 0, "cam": 0, "min_h": 1e9, "s0": 1e9, "s1": -1e9, "at": p}
						var r: Dictionary = found[npath]
						if h < cart:
							r["low"] += 1
						else:
							r["cam"] += 1
						if h < r["min_h"]:
							r["min_h"] = h
							r["at"] = p
						var sv: float = float(hit[0]) * step
						if detail != "" and detail in npath:
							var bk: int = int(sv / 10.0)
							if not r.has("bins"):
								r["bins"] = {}
							var bins: Dictionary = r["bins"]
							if not bins.has(bk):
								bins[bk] = [1e9, 1e9, -1e9]
							var bn: Array = bins[bk]
							bn[0] = minf(bn[0], h)
							bn[1] = minf(bn[1], hit[2])
							bn[2] = maxf(bn[2], hit[2])
						r["s0"] = minf(r["s0"], sv)
						r["s1"] = maxf(r["s1"], sv)
	var names: Array = found.keys()
	names.sort_custom(func(x, y): return found[x]["min_h"] < found[y]["min_h"])
	for nm in names:
		var r: Dictionary = found[nm]
		var at: Vector3 = r["at"]
		if r.has("bins"):
			var ks: Array = (r["bins"] as Dictionary).keys()
			ks.sort()
			for bk in ks:
				var bn: Array = r["bins"][bk]
				print("   s %d-%d: lowest %.2fm, across %.1f..%.1f" % [bk * 10, bk * 10 + 10, bn[0], bn[1], bn[2]])
		print("OVER %s: %d under %.1fm, %d above, lowest %.2fm at (%.1f, %.1f, %.1f), lap s %.0f-%.0f" % [nm, r["low"], cart, r["cam"], r["min_h"], at.x, at.y, at.z, r["s0"], r["s1"]])
	print("done: %d nodes over the lap (%d meshes and instances, %d near it)" % [names.size(), jobs.size(), tested])
	quit()


func _near_lap(x0: float, x1: float, z0: float, z1: float) -> bool:
	for cx in range(floori(x0 / CELL), floori(x1 / CELL) + 1):
		for cz in range(floori(z0 / CELL), floori(z1 / CELL) + 1):
			if _grid.has(Vector2i(cx, cz)):
				return true
	return false


## [sample index, height over the lap] when p lies within half of the line beside its nearest sample, else [].
func _measure(p: Vector3, half: float) -> Array:
	var best := -1
	var bd := 1e18
	var cx: int = floori(p.x / CELL)
	var cz: int = floori(p.z / CELL)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if not _grid.has(key):
				continue
			for i in _grid[key]:
				var d: float = Vector2(_pos[i].x - p.x, _pos[i].z - p.z).length_squared()
				if d < bd:
					bd = d
					best = i
	if best < 0 or bd > half * half + 4.0:
		return []
	var o: Vector3 = _pos[best]
	var f: Vector3 = _fwd[best]
	var rel := Vector3(p.x - o.x, 0.0, p.z - o.z)
	var lat: float = rel.dot(Vector3(-f.z, 0.0, f.x))
	if absf(lat) > half:
		return []
	return [best, p.y - o.y, lat]
