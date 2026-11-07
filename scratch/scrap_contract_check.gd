extends SceneTree
## Checks ScrapKit.gd against regenerate_stadtrallye.gd's call sites without running the generator: every builder it calls
## exists and builds with the generator's own arguments (through `new_kit(1.6)` and a frame grown 1.6, or `new_kit(1.0)` for
## the moving parts), every `*_solids` is a list of [Transform3D, Vector3], and the constants it reads are there. Then it
## places the props as `_build_demolition` and `_build_scrapyard` do (the route's lines z 430, z 680 and x 330 there; ground
## at y 0) and prints, for each, what of it stands within the road's corridor (ROAD_HALF 7.5 + `margin`) and how low; and,
## for the moving parts, how low the magnet's upper and the ball's line come over the road through their swings.
##   Godot --headless --path . -s res://scratch/scrap_contract_check.gd [-- margin=1.5]

const PROP_SCALE := 1.6
const ROAD_HALF := 7.5
const BALL_X := 520.0
const HANDLER_AT := Vector2(150.0, 702.0)

var SK: Script
var margin := 1.5


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("margin="):
			margin = float(a.substr(7))
	SK = load("res://ScrapKit.gd")
	var names: Array = []
	for m in SK.get_script_method_list():
		names.append(m["name"])
	for fn in ["crawler_crane", "crawler_crane_solids", "wrecking_ball", "ruin_building", "ruin_building_solids", "rubble_heap", "bale_wall", "scrap_heap",
			"scrap_heap_solids", "material_handler", "material_handler_solids", "material_handler_upper", "scrap_magnet", "car_press", "car_press_solids",
			"scrapyard_office", "scrapyard_office_solids", "weighbridge", "weighbridge_solids", "scrap_fence", "skip", "sorting_bin", "drum_stack", "tyre_pile"]:
		if not names.has(fn):
			print("MISSING ", fn)
	var cm: Dictionary = SK.get_script_constant_map()
	for c in ["CRANE_TIP", "BALL_R", "BALL_H", "CRANE_FOOT_HALF", "HANDLER_RING_Y", "HANDLER_TIP", "MAGNET_HIT_C", "MAGNET_HIT_HALF"]:
		print("const %s = %s" % [c, cm.get(c, "MISSING")])
	var rng := RandomNumberGenerator.new()
	rng.seed = 7601
	# --- The demolition site.
	var ruin_front: float = 430.0 + ROAD_HALF + 10.0
	var rxf := _facing(Vector3(0, 0, -1), Vector3(BALL_X, 0, ruin_front))
	var tris := _prop(rxf, "ruin_building", [7], true)
	_report("ruin", tris, func(p: Vector3) -> bool: return absf(p.z - 430.0) < ROAD_HALF + margin)
	_check_solids("ruin_building_solids", [7])
	var tip: Vector3 = cm["CRANE_TIP"]
	var cxf := _facing(Vector3(0, 0, -1), Vector3.ZERO)
	var tip_off: Vector3 = cxf.basis * (tip * PROP_SCALE)
	cxf.origin = Vector3(BALL_X, 0, 430.0) - Vector3(tip_off.x, 0.0, tip_off.z)
	tris = _prop(cxf, "crawler_crane", [], true)
	_report("crane", tris, func(p: Vector3) -> bool: return absf(p.z - 430.0) < ROAD_HALF + margin)
	_check_solids("crawler_crane_solids", [])
	var tip_w: Vector3 = cxf * (tip * PROP_SCALE)
	var length: float = tip_w.y - 2.2
	var chain_life: float = length / PROP_SCALE - float(cm["BALL_H"]) * 0.5
	print("crane tip %s, ball line %.2f, chain_life %.2f" % [tip_w, length, chain_life])
	var foot: Vector2 = cm["CRANE_FOOT_HALF"]
	var ball_r: float = float(cm["BALL_R"]) * PROP_SCALE
	var crane_front: float = absf(tip_w.z - (cxf * Vector3(0, 0, -foot.y * PROP_SCALE)).z)
	var wall: float = rad_to_deg(asin(clampf((ruin_front - 430.0 - ball_r - 0.3) / length, 0.0, 0.9)))
	var outd: float = maxf(rad_to_deg(asin(clampf((crane_front - ball_r - 2.0) / length, 0.0, 0.9))), wall + 1.5)
	print("ball: wall %.1f, out %.1f degrees" % [wall, outd])
	var ball := _moving("wrecking_ball", [chain_life])
	# The ball's mesh against the ruin and the crane through its swing: the angle about the hang point's x (+ toward +z).
	for deg in [wall, 0.0, -outd]:
		var sw := Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(deg)), tip_w) * Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO)
		var lo := 1e9
		var zmax := -1e9
		var zmin := 1e9
		for v in ball:
			var w: Vector3 = sw * v
			lo = minf(lo, w.y)
			zmax = maxf(zmax, w.z)
			zmin = minf(zmin, w.z)
		print("  ball at %.1f deg: lowest %.2f over the ground, z %.2f..%.2f (ruin front %.2f, crane front %.2f)" % [deg, lo, zmin, zmax, ruin_front,
				(cxf * Vector3(0, 0, -foot.y * PROP_SCALE)).z])
	# Rubble, skips (as placed, with rotation).
	for k in range(3):
		var seed_v: int = rng.randi()
		tris = _prop(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3.ZERO), "rubble_heap", [16.0, 12.0, 4.5, seed_v], false)
	tris = _prop(Transform3D.IDENTITY, "skip", [rng.randi()], false)
	# --- The scrapyard.
	var oxf := _facing(Vector3(-1, 0, 0), Vector3(330.0 + ROAD_HALF + 14.0, 0, 560.0))
	tris = _prop(oxf, "scrapyard_office", [], true)
	_report("office", tris, func(p: Vector3) -> bool: return absf(p.x - 330.0) < ROAD_HALF + margin)
	_check_solids("scrapyard_office_solids", [])
	var wxf := _facing(Vector3(-1, 0, 0), Vector3(330.0 + ROAD_HALF + 14.0, 0, 612.0))
	tris = _prop(wxf, "weighbridge", [], true)
	_report("weighbridge", tris, func(p: Vector3) -> bool: return absf(p.x - 330.0) < ROAD_HALF + margin)
	_check_solids("weighbridge_solids", [])
	var pxf := _facing(Vector3(0, 0, 1), Vector3(HANDLER_AT.x + 34.0, 0, 652.0))
	tris = _prop(pxf, "car_press", [], true)
	_report("press", tris, func(p: Vector3) -> bool: return absf(p.z - 680.0) < ROAD_HALF + margin)
	_check_solids("car_press_solids", [])
	# A bale wall on each side of the lane (the lane runs -x at z 680; right of travel is -z).
	for side in [-1.0, 1.0]:
		var fwd := Vector3(-1, 0, 0)
		var right := Vector3(0, 0, -1)
		var a: Vector3 = Vector3(250.0, 0, 680.0) + right * (side * (ROAD_HALF + 2.2))
		var face: Vector3 = -right * side
		var xf := Transform3D(Basis(fwd, Vector3.UP, face), a)
		if xf.basis.determinant() < 0.0:
			xf = Transform3D(Basis(-fwd, Vector3.UP, face), a + fwd * 24.0)
		tris = _prop(xf, "bale_wall", [24.0 / PROP_SCALE, 4, rng.randi()], false)
		_report("bales side %d" % int(side), tris, func(p: Vector3) -> bool: return absf(p.z - 680.0) < ROAD_HALF + 0.5)
	for k in range(2):
		var sv: int = rng.randi()
		tris = _prop(Transform3D(Basis(Vector3.UP, 0.15), Vector3.ZERO), "scrap_heap", [22.0, 14.0, 7.0, sv], false)
		_check_solids("scrap_heap_solids", [22.0, 14.0, 7.0, sv])
	for fn in ["sorting_bin", "drum_stack", "tyre_pile"]:
		tris = _prop(Transform3D.IDENTITY, fn, [rng.randi()], false)
	tris = _prop(Transform3D.IDENTITY, "scrap_fence", [12.5], false)
	var hb := Transform3D(Basis(), Vector3(HANDLER_AT.x, 0, HANDLER_AT.y))
	tris = _prop(hb, "material_handler", [], true)
	_report("handler base", tris, func(p: Vector3) -> bool: return absf(p.z - 680.0) < ROAD_HALF + margin)
	_check_solids("material_handler_solids", [])
	# The upper and the magnet through the slewing (SlewHazard: the node at the ring, turning about y, the hang node at
	# HANDLER_TIP x 1.6 in it, both meshes grown 1.6).
	var upper := _moving("material_handler_upper", [])
	var magnet := _moving("scrap_magnet", [3])
	var ring_y: float = float(cm["HANDLER_RING_Y"]) * PROP_SCALE
	var tipv: Vector3 = (cm["HANDLER_TIP"] as Vector3) * PROP_SCALE
	var hc: Vector3 = (cm["MAGNET_HIT_C"] as Vector3) * PROP_SCALE
	var hh: Vector3 = (cm["MAGNET_HIT_HALF"] as Vector3) * PROP_SCALE
	for deg in [-82.0, -40.0, 0.0, 40.0, 82.0]:
		var slew := Transform3D(Basis(Vector3.UP, deg_to_rad(deg)), Vector3(HANDLER_AT.x, ring_y, HANDLER_AT.y))
		var gs := Transform3D(Basis.from_scale(Vector3.ONE * PROP_SCALE), Vector3.ZERO)
		var lo_u := 1e9
		for v in upper:
			var w: Vector3 = slew * gs * v
			if absf(w.z - 680.0) < ROAD_HALF + margin:
				lo_u = minf(lo_u, w.y)
		var lo_m := 1e9
		var hang := slew * Transform3D(Basis(), tipv)
		for v in magnet:
			var w2: Vector3 = hang * gs * v
			if absf(w2.z - 680.0) < ROAD_HALF + margin:
				lo_m = minf(lo_m, w2.y)
		var box_c: Vector3 = hang * hc
		print("  slew %+.0f: upper over the road lowest %s, magnet lowest %s, hit box centre (%.1f, %.2f, %.1f) bottom %.2f" % [deg,
				"%.2f" % lo_u if lo_u < 1e8 else "-", "%.2f" % lo_m if lo_m < 1e8 else "-", box_c.x, box_c.y, box_c.z, box_c.y - hh.y])
	print("DONE")
	quit()


func _facing(face: Vector3, at: Vector3) -> Transform3D:
	var z := Vector3(face.x, 0.0, face.z).normalized()
	var x := Vector3.UP.cross(z).normalized()
	return Transform3D(Basis(x, Vector3.UP, z), at)


## Builds a prop as `_add_prop` does (new_kit(1.6), the frame `xf` grown 1.6) and returns its triangles' corners in the world.
func _prop(xf: Transform3D, fn: String, extra: Array, labels: bool) -> PackedVector3Array:
	var pk = SK.new_kit(PROP_SCALE)
	pk.set_frame(Transform3D(xf.basis * Basis.from_scale(Vector3.ONE * PROP_SCALE), xf.origin))
	var kit := {}
	var lab: Array = []
	var args: Array = [pk, kit]
	if labels:
		args.append(lab)
	args.append_array(extra)
	var t0 := Time.get_ticks_msec()
	SK.callv(fn, args)
	var tris: PackedVector3Array = pk.kit_triangles(kit)
	var mesh: ArrayMesh = SK.commit(pk, kit)
	print("%s: %d triangles, %d surfaces, %d labels, %d ms" % [fn, tris.size() / 3, mesh.get_surface_count(), lab.size(), Time.get_ticks_msec() - t0])
	for l in lab:
		if not (l is Array) or (l as Array).size() < 6:
			print("  BAD LABEL ", l)
	return tris


## A moving part's mesh as `_kit_mesh` builds it (new_kit(1.0)), its corners at life size.
func _moving(fn: String, extra: Array) -> PackedVector3Array:
	var pk = SK.new_kit(1.0)
	var kit := {}
	SK.callv(fn, [pk, kit] + extra)
	var tris: PackedVector3Array = pk.kit_triangles(kit)
	var keys: Array = kit.keys()
	print("%s: %d triangles, keys %s" % [fn, tris.size() / 3, keys])
	return tris


func _report(what: String, tris: PackedVector3Array, in_corridor: Callable) -> void:
	var n := 0
	var lo := 1e9
	for v in tris:
		if in_corridor.call(v):
			n += 1
			lo = minf(lo, v.y)
	if n == 0:
		print("  %s: nothing within the road's corridor" % what)
	else:
		print("  %s: %d corners within the road's corridor, the lowest %.2f over the ground" % [what, n, lo])


func _check_solids(fn: String, args: Array) -> void:
	var list = SK.callv(fn, args)
	if not (list is Array):
		print("  %s: NOT AN ARRAY" % fn)
		return
	for e in list:
		if not (e is Array) or (e as Array).size() != 2 or not (e[0] is Transform3D) or not (e[1] is Vector3):
			print("  %s: BAD ENTRY %s" % [fn, e])
			return
	print("  %s: %d boxes" % [fn, (list as Array).size()])
