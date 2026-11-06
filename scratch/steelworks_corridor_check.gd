extends SceneTree
## Checks SteelworksKit's road-corridor promises on the built triangles (life-size kit coordinates, headless):
##   Godot --headless --path . -s res://scratch/steelworks_corridor_check.gd -- [length=150] [span=20] [clearance=11]
## The hall (road along -z, z 0..-length): nothing in |x| < 6 from y 0.05 to 12; nothing in |x| < 7.5 from y 0.05 to 1.2;
## no floor in |x| < 4.5 (y -1.5..0.05). The pipe bridge (road along z): nothing in |x| < span/2 below `clearance`.
## The works gate (road along z): nothing in |x| < 8 below 11. Prints each offending triangle (up to 12 per box) and PASS
## or FAIL.
const SteelworksKit = preload("res://SteelworksKit.gd")
const PropKit = preload("res://PropKit.gd")

var fails := 0


func _init() -> void:
	var length := 150.0
	var span := 20.0
	var clearance := 11.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("length="):
			length = float(a.substr(7))
		elif a.begins_with("span="):
			span = float(a.substr(5))
		elif a.begins_with("clearance="):
			clearance = float(a.substr(10))
	var pk: PropKit = SteelworksKit.new_kit(1.0)
	var kit := {}
	SteelworksKit.rolling_hall(pk, kit, length, [])
	var tris := PropKit.kit_triangles(kit)
	print("hall: %d triangles" % (tris.size() / 3))
	_check(tris, "hall |x|<6 y<12", AABB(Vector3(-6.0, 0.05, -length + 0.001), Vector3(12.0, 11.95, length - 0.002)))
	_check(tris, "hall |x|<7.5 y<1.2", AABB(Vector3(-7.499, 0.05, -length + 0.001), Vector3(14.998, 1.15, length - 0.002)))
	_check(tris, "hall no floor |x|<4.5", AABB(Vector3(-4.499, -1.5, -length - 1.0), Vector3(8.998, 1.55, length + 2.0)))
	_check(tris, "hall approach z>0", AABB(Vector3(-7.999, 0.05, 0.001), Vector3(15.998, 12.0, 20.0)))
	_check(tris, "hall exit z<-length", AABB(Vector3(-7.999, 0.05, -length - 20.0), Vector3(15.998, 12.0, 19.999)))
	pk = SteelworksKit.new_kit(1.0)
	kit = {}
	SteelworksKit.pipe_bridge(pk, kit, span, clearance, 4)
	tris = PropKit.kit_triangles(kit)
	print("pipe bridge: %d triangles" % (tris.size() / 3))
	_check(tris, "pipe bridge |x|<span/2 y<clearance", AABB(Vector3(-span * 0.5, 0.0, -30.0), Vector3(span, clearance - 0.001, 60.0)))
	pk = SteelworksKit.new_kit(1.0)
	kit = {}
	SteelworksKit.works_gate(pk, kit, [])
	tris = PropKit.kit_triangles(kit)
	print("works gate: %d triangles" % (tris.size() / 3))
	_check(tris, "gate |x|<8 y<11", AABB(Vector3(-7.999, 0.0, -40.0), Vector3(15.998, 11.0, 80.0)))
	print("PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit()


func _check(tris: PackedVector3Array, label: String, box: AABB) -> void:
	var hits := 0
	for i in range(0, tris.size(), 3):
		var poly: Array = [tris[i], tris[i + 1], tris[i + 2]]
		for ax in range(3):
			poly = _clip(poly, ax, box.position[ax], true)
			poly = _clip(poly, ax, box.end[ax], false)
			if poly.is_empty():
				break
		if poly.size() >= 3 and _area(poly) > 1e-5:
			hits += 1
			if hits <= 12:
				print("  %s: triangle %s %s %s" % [label, tris[i], tris[i + 1], tris[i + 2]])
	print("%s: %d triangles inside" % [label, hits])
	if hits > 0:
		fails += 1


func _clip(poly: Array, ax: int, v: float, keep_above: bool) -> Array:
	var out: Array = []
	var n := poly.size()
	for k in range(n):
		var a: Vector3 = poly[k]
		var b: Vector3 = poly[(k + 1) % n]
		var da: float = (a[ax] - v) if keep_above else (v - a[ax])
		var db: float = (b[ax] - v) if keep_above else (v - b[ax])
		if da >= 0.0:
			out.append(a)
		if (da >= 0.0) != (db >= 0.0):
			out.append(a.lerp(b, da / (da - db)))
	return out


func _area(poly: Array) -> float:
	var s := Vector3.ZERO
	for k in range(1, poly.size() - 1):
		s += ((poly[k] as Vector3) - (poly[0] as Vector3)).cross((poly[k + 1] as Vector3) - (poly[0] as Vector3))
	return s.length() * 0.5
