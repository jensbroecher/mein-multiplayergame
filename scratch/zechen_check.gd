extends SceneTree
## Headless checks for ZechenKit.gd: builds every piece at life size (scale 1), prints its triangles and bounds, and tests
## the clearances the generator relies on against the triangles themselves (sampled every ~8cm over each triangle):
##   the coal washer's passage: nothing within |x| <= 7.5, 0 <= y <= 7.0 (any z);
##   the loading bunker's track: nothing within |x| <= 2.6, 0 <= y <= 5.6 (any z);
##   the headframe's and the landmark's footprints.
##   Godot --headless --path . -s res://scratch/zechen_check.gd

const ZK = preload("res://ZechenKit.gd")


func _init() -> void:
	var pieces: Array = [
		["malakoff", func(pk, kit, labels): ZK.malakoff_tower(pk, kit, labels)],
		["headframe", func(pk, kit, labels): ZK.headframe(pk, kit, labels)],
		["sheave", func(pk, kit, _labels): ZK.headframe_sheave(pk, kit)],
		["winding_house0", func(pk, kit, labels): ZK.winding_house(pk, kit, labels, 0)],
		["winding_house1", func(pk, kit, labels): ZK.winding_house(pk, kit, labels, 1)],
		["lohnhalle", func(pk, kit, labels): ZK.lohnhalle(pk, kit, labels)],
		["coal_washer", func(pk, kit, labels): ZK.coal_washer(pk, kit, labels)],
		["gallery_50m", func(pk, kit, _labels): ZK.conveyor_gallery(pk, kit, Vector3(0, 3, 0), Vector3(40, 15, 30), 3.2, func(p: Vector3) -> float: return 0.0)],
		["gallery_10m_flat", func(pk, kit, _labels): ZK.conveyor_gallery(pk, kit, Vector3(0, 8, 0), Vector3(10, 8, 0), 3.2)],
		["coal_bunker", func(pk, kit, labels): ZK.coal_bunker(pk, kit, labels)],
		["mine_cart0", func(pk, kit, _labels): ZK.mine_cart(pk, kit, 0)],
		["mine_cart1", func(pk, kit, _labels): ZK.mine_cart(pk, kit, 1)],
		["mine_cart2", func(pk, kit, _labels): ZK.mine_cart(pk, kit, 2)],
		["narrow_gauge_10m", func(pk, kit, _labels): ZK.narrow_gauge(pk, kit, 10.0)],
		["summit_landmark", func(pk, kit, labels): ZK.summit_landmark(pk, kit, labels, true)],
		["summit_wheel", func(pk, kit, _labels): ZK.summit_wheel(pk, kit)],
		["fence_25m", func(pk, kit, _labels): ZK.industrial_fence(pk, kit, 25.0)],
		["floodlight_mast", func(pk, kit, _labels): ZK.floodlight_mast(pk, kit)],
		["plaque_board", func(pk, kit, labels): ZK.plaque_board(pk, kit, labels, "TITEL\nZeile eins\nZeile zwei")],
		["rust_skip", func(pk, kit, _labels): ZK.rust_skip(pk, kit)],
		["cable_drum", func(pk, kit, _labels): ZK.cable_drum(pk, kit)],
	]
	for p in pieces:
		var pk = ZK.new_kit(1.0)
		var kit := {}
		var labels: Array = []
		(p[1] as Callable).call(pk, kit, labels)
		var tris: PackedVector3Array = PropKit_tris(kit)
		var aabb := AABB()
		for i in range(tris.size()):
			if i == 0:
				aabb = AABB(tris[0], Vector3.ZERO)
			else:
				aabb = aabb.expand(tris[i])
		var keys: Array = kit.keys()
		keys.sort()
		print("%-18s %6d tris  aabb %s .. %s  keys %s  labels %d" % [p[0], tris.size() / 3, aabb.position, aabb.end, ",".join(keys), labels.size()])
		for l in labels:
			print("    label '%s' at %s cap %.2f" % [l[0], l[1], l[3]])
		if p[0] == "coal_washer":
			_clear(tris, 7.5, 0.0, 7.0, "washer passage |x|<=7.5 y 0..7.0")
		if p[0] == "coal_bunker":
			_clear(tris, 2.6, 0.0, 5.6, "bunker track |x|<=2.6 y 0..5.6")
	for i in 3:
		var m: ArrayMesh = ZK.buddleia_mesh(10 + i)
		print("buddleia %d: %d tris aabb %s" % [i, _mesh_tris(m), m.get_aabb()])
		var g: ArrayMesh = ZK.goldenrod_mesh(10 + i)
		print("goldenrod %d: %d tris aabb %s" % [i, _mesh_tris(g), g.get_aabb()])
	print("hubs ", ZK.headframe_sheave_hubs(), " rope exits ", ZK.headframe_rope_exits())
	print("stubs ", ZK.coal_washer_stubs(), " bunker stub ", ZK.coal_bunker_stub())
	quit()


func PropKit_tris(kit: Dictionary) -> PackedVector3Array:
	return preload("res://PropKit.gd").kit_triangles(kit)


func _mesh_tris(m: ArrayMesh) -> int:
	var t := 0
	for k in m.get_surface_count():
		var arr: Array = m.surface_get_arrays(k)
		var idx = arr[Mesh.ARRAY_INDEX]
		t += int((idx as PackedInt32Array).size() / 3.0) if idx != null else int((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
	return t


## Samples every triangle and reports any point inside |x| <= hx, y0 <= y <= y1.
func _clear(tris: PackedVector3Array, hx: float, y0: float, y1: float, what: String) -> void:
	var bad := 0
	var worst: Array = []
	for i in range(0, tris.size(), 3):
		var a: Vector3 = tris[i]
		var b: Vector3 = tris[i + 1]
		var c: Vector3 = tris[i + 2]
		var lo := Vector3(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y)), 0)
		var hi := Vector3(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y)), 0)
		if lo.x > hx or hi.x < -hx or lo.y > y1 or hi.y < y0:
			continue
		var n: int = clampi(int(maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) / 0.08) + 1, 1, 200)
		var hit := false
		for u in range(n + 1):
			for v in range(n + 1 - u):
				var p: Vector3 = a + (b - a) * (float(u) / float(n)) + (c - a) * (float(v) / float(n))
				if absf(p.x) <= hx and p.y >= y0 + 0.001 and p.y <= y1:
					hit = true
					if worst.size() < 12:
						worst.append([p, a, b, c])
					break
			if hit:
				break
		if hit:
			bad += 1
	print("CLEARANCE %s: %s (%d triangles inside)" % [what, "OK" if bad == 0 else "FAIL", bad])
	for w in worst:
		print("    at %s  tri %s %s %s" % w)
