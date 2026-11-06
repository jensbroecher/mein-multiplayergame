extends SceneTree
## Checks KokereiKit's clearances on the built triangles (life metres, the battery's frame, headless):
##   Godot --headless --path . -s res://scratch/kokerei_clearance_check.gd -- [ovens=50] [road=21.0]
## - the quench tower's passage (|z| < 2.8, y 0.05..6.0) holds nothing, and the quench car and its loco fit in it;
## - nothing of the battery, the guide car, the quench car on its track (QUENCH_Z), kokerei_rails or the quench tower
##   on that track reaches past the race road's near edge `road` (life z in the battery's frame); prints each piece's
##   furthest z toward the road, so the minimum offset from the battery's coke face (z 7.66) can be read off;
## - the gaps between machines and what they work against: the guide car's cage over the quench car, the pusher machine
##   and the pusher bench, the larry car under the coal tower's outlets and beside the ascension pipes.
## Prints PASS or FAIL.
const KokereiKit = preload("res://KokereiKit.gd")
const PropKit = preload("res://PropKit.gd")

var fails := 0


func _init() -> void:
	var ovens := 50
	var road := 21.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ovens="):
			ovens = int(a.substr(6))
		elif a.begins_with("road="):
			road = float(a.substr(5))
	var L: float = KokereiKit.battery_length(ovens)
	var oi: int = ovens / 2
	var ox: float = KokereiKit.oven_x(oi)
	var qz: float = KokereiKit.QUENCH_Z
	var bat := _tris(func(pk, kit): KokereiKit.coke_battery(pk, kit, [], ovens, 3, 3, oi), Transform3D.IDENTITY)
	var guide := _tris(func(pk, kit): KokereiKit.coke_guide_car(pk, kit, true, true), Transform3D(Basis(), Vector3(ox, 0, 0)))
	var pusher := _tris(func(pk, kit): KokereiKit.pusher_machine(pk, kit, true), Transform3D(Basis(), Vector3(ox, 0, 0)))
	var larry := _tris(func(pk, kit): KokereiKit.larry_car(pk, kit), Transform3D(Basis(), Vector3(KokereiKit.oven_x(3), 0, 0)))
	var qcar := _tris(func(pk, kit): KokereiKit.quench_car(pk, kit, 1), Transform3D(Basis(), Vector3(ox, 0, qz)))
	var rails := _tris(func(pk, kit): KokereiKit.kokerei_rails(pk, kit, L + 60.0), Transform3D(Basis(), Vector3(-10, 0, qz)))
	var tower := _tris(func(pk, kit): KokereiKit.quench_tower(pk, kit, []), Transform3D(Basis(), Vector3(L + 30.0, 0, qz)))
	var coal := _tris(func(pk, kit): KokereiKit.coal_tower(pk, kit, []), Transform3D(Basis(), Vector3(KokereiKit.COAL_TOWER_X, 0, 0)))
	var qt_local := _tris(func(pk, kit): KokereiKit.quench_tower(pk, kit, []), Transform3D.IDENTITY)
	var qc_local := _tris(func(pk, kit): KokereiKit.quench_car(pk, kit, 2), Transform3D.IDENTITY)
	var wharf := _tris(func(pk, kit): KokereiKit.coke_wharf(pk, kit, 60.0), Transform3D.IDENTITY)

	print("battery length %.2f, oven %d at x %.2f" % [L, oi, ox])
	_check(qt_local, "quench tower passage |z|<2.8 y 0.05..6.0", AABB(Vector3(-9.0, 0.05, -2.8), Vector3(18.0, 5.95, 5.6)))
	var qb := _bounds(qc_local)
	print("quench car + loco bounds (track frame): %s" % qb)
	if qb.position.z < -2.8 or qb.end.z > 2.8 or qb.end.y > 6.0:
		print("  FAIL: the quench car doesn't fit the tower's passage")
		fails += 1
	# The road: everything along the battery and past it on the quench line stays short of its near edge.
	for e in [["battery", bat], ["guide car", guide], ["quench car", qcar], ["kokerei_rails", rails], ["quench tower", tower], ["coal tower", coal]]:
		var b := _bounds(e[1])
		print("%-14s z %.2f .. %.2f (to the road edge at %.1f: %.2f)" % [e[0], b.position.z, b.end.z, road, road - b.end.z])
		if b.end.z > road - 0.5:
			print("  FAIL: %s comes within 0.5m of the road" % e[0])
			fails += 1
	print("coke face (buckstays) at z %.2f: offset to the road edge %.2f" % [KokereiKit.BUCK_Z, road - KokereiKit.BUCK_Z])
	# Guide car over the quench car: the cage's lowest point over the track vs the car's highest.
	var cage_low := _min_y_in(guide, AABB(Vector3(ox - 1.0, 0.0, qz - 2.0), Vector3(2.0, 20.0, 4.0)))
	var car_high := _max_y_in(qcar, AABB(Vector3(ox - 1.0, 0.0, qz - 2.0), Vector3(2.0, 20.0, 4.0)))
	print("guide cage's underside over the quench car %.2f, the car's top %.2f: gap %.2f" % [cage_low, car_high, cage_low - car_high])
	if cage_low - car_high < 0.03:
		fails += 1
		print("  FAIL: the cage touches the quench car")
	# Pusher machine against the bench and the doors.
	var pb := _bounds(pusher)
	print("pusher machine z %.2f .. %.2f (bench edge -9.42, door faces -7.68)" % [pb.position.z, pb.end.z])
	_check(pusher, "pusher clear of the pusher bench", AABB(Vector3(ox - 6.0, 3.9, -9.42), Vector3(12.0, 0.45, 2.4)))
	# Larry car: under the coal tower's outlets, beside the ascension pipes.
	var lb := _bounds(larry)
	print("larry car bounds %s" % lb)
	var out_low := _min_y_in(coal, AABB(Vector3(-19.5, 12.0, -5.0), Vector3(14.5, 20.0, 10.0)))
	print("coal tower's lowest point over the larry track %.2f vs the larry car's top %.2f" % [out_low, lb.end.y])
	if out_low <= lb.end.y + 0.3:
		fails += 1
		print("  FAIL: the larry car hits the coal tower's outlets")
	# The larry car's whole envelope (x from the tower's buffer stops to the battery) is free of the tower.
	_check(coal, "larry car's envelope through the coal tower", AABB(Vector3(-19.7, 9.85, lb.position.z - 0.05), Vector3(19.7, lb.size.y + 0.4, lb.size.z + 0.1)))
	_check(bat, "ascension pipes clear of the larry car's envelope", AABB(Vector3(10.0, LARRY_TOP_CLEAR, lb.position.z - 0.3), Vector3(L - 20.0, 7.0, lb.size.z + 0.6)))
	var wb := _bounds(wharf)
	print("coke wharf bounds (its frame) %s" % wb)
	print("PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()


const LARRY_TOP_CLEAR := 10.25


func _tris(build: Callable, xf: Transform3D) -> PackedVector3Array:
	var pk: PropKit = KokereiKit.new_kit(1.0)
	var kit := {}
	build.call(pk, kit)
	var raw := PropKit.kit_triangles(kit)
	var out := PackedVector3Array()
	out.resize(raw.size())
	for i in raw.size():
		out[i] = xf * raw[i]
	return out


func _bounds(t: PackedVector3Array) -> AABB:
	var b := AABB(t[0], Vector3.ZERO)
	for p in t:
		b = b.expand(p)
	return b


func _min_y_in(t: PackedVector3Array, box: AABB) -> float:
	var m := INF
	for i in range(0, t.size(), 3):
		var poly: Array = _clip_box([t[i], t[i + 1], t[i + 2]], box)
		for p in poly:
			m = minf(m, (p as Vector3).y)
	return m


func _max_y_in(t: PackedVector3Array, box: AABB) -> float:
	var m := -INF
	for i in range(0, t.size(), 3):
		var poly: Array = _clip_box([t[i], t[i + 1], t[i + 2]], box)
		for p in poly:
			m = maxf(m, (p as Vector3).y)
	return m


func _check(tris: PackedVector3Array, label: String, box: AABB) -> void:
	var hits := 0
	for i in range(0, tris.size(), 3):
		var poly: Array = _clip_box([tris[i], tris[i + 1], tris[i + 2]], box)
		if poly.size() >= 3 and _area(poly) > 1e-5:
			if hits < 6:
				print("    hit: %s %s %s" % [tris[i], tris[i + 1], tris[i + 2]])
			hits += 1
	print("%s: %s" % [label, "clear" if hits == 0 else "%d triangles inside" % hits])
	if hits > 0:
		fails += 1


func _clip_box(poly: Array, box: AABB) -> Array:
	for ax in range(3):
		poly = _clip(poly, ax, box.position[ax], true)
		poly = _clip(poly, ax, box.end[ax], false)
		if poly.is_empty():
			return []
	return poly


func _clip(poly: Array, ax: int, v: float, keep_above: bool) -> Array:
	var out: Array = []
	for i in poly.size():
		var a: Vector3 = poly[i]
		var b: Vector3 = poly[(i + 1) % poly.size()]
		var ina: bool = a[ax] >= v if keep_above else a[ax] <= v
		var inb: bool = b[ax] >= v if keep_above else b[ax] <= v
		if ina:
			out.append(a)
		if ina != inb:
			var t: float = (v - a[ax]) / (b[ax] - a[ax])
			out.append(a.lerp(b, t))
	return out


func _area(poly: Array) -> float:
	var s := Vector3.ZERO
	for i in range(1, poly.size() - 1):
		s += ((poly[i] as Vector3) - poly[0]).cross((poly[i + 1] as Vector3) - poly[0])
	return s.length() * 0.5
