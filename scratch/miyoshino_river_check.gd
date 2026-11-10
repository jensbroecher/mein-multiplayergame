extends SceneTree
## Headless checks of MiyoshinoRiverKit.gd: builds every builder, prints its triangles, and for the driven structures
## (road_bridge 0 and 1, suspension_bridge, ledge_walk, timber_chute) the corridor check's count, which must be 0:
##   Godot --headless --path . -s res://scratch/miyoshino_river_check.gd -- [span=60] [hw=6]
## The bridges cross a 9m deep valley under a deck with a 1.2m hump, then a dipping deck over a 30m gorge; the
## ledge walk runs along a 45-degree slope, the chute down a hillside with a hollow under it.

const K = preload("res://MiyoshinoRiverKit.gd")

var span := 60.0
var hw := 6.0
var fails := 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("span="):
			span = float(a.substr(5))
		elif a.begins_with("hw="):
			hw = float(a.substr(3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var props: Array = [
		["log_raft(10, 7.5)", 1.6, func(pk, kit): K.log_raft(pk, kit, 10, 7.5, rng), 1200],
		["raft_cargo 0", 1.6, func(pk, kit): K.raft_cargo(pk, kit, 0, rng), 0], ["raft_cargo 1", 1.6, func(pk, kit): K.raft_cargo(pk, kit, 1, rng), 0],
		["raft_cargo 2", 1.6, func(pk, kit): K.raft_cargo(pk, kit, 2, rng), 0],
		["log_stack", 1.6, func(pk, kit): K.log_stack(pk, kit, 6, 6.0, rng), 0], ["log_pile", 1.6, func(pk, kit): K.log_pile(pk, kit, 9, 4.0, rng), 0],
		["plank_stack", 1.6, func(pk, kit): K.plank_stack(pk, kit), 0],
		["sawmill", 1.6, func(pk, kit): K.sawmill(pk, kit, []), 9000], ["water_wheel", 1.6, func(pk, kit): K.water_wheel(pk, kit), 0],
		["river_boat 0", 1.6, func(pk, kit): K.river_boat(pk, kit, 0), 0], ["river_boat 1", 1.6, func(pk, kit): K.river_boat(pk, kit, 1), 0],
		["river_boat 2", 1.6, func(pk, kit): K.river_boat(pk, kit, 2), 0], ["yana", 1.6, func(pk, kit): K.yana(pk, kit), 0],
		["kinma_sled", 1.6, func(pk, kit): K.kinma_sled(pk, kit, rng), 0],
	]
	for p in props:
		var pk = K.new_kit(float(p[1]))
		var kit := {}
		(p[2] as Callable).call(pk, kit)
		_report(p[0], kit, int(p[3]), -1)
	var hump := func(t: float) -> float: return 20.0 + 1.2 * (1.0 - pow(2.0 * clampf(t / span, 0.0, 1.0) - 1.0, 2.0))
	var valley := func(_x: float, t: float) -> float: return 20.0 - 9.0 * maxf(0.0, 1.0 - pow(2.0 * t / span - 1.0, 2.0))
	var dip := func(t: float) -> float: return 50.0 - 1.5 * (1.0 - pow(2.0 * clampf(t / span, 0.0, 1.0) - 1.0, 2.0)) + 0.03 * t
	var gorge := func(x: float, t: float) -> float: return 50.0 - 30.0 * clampf(minf(t, span - t) / 6.0, 0.0, 1.0) + 0.05 * x
	for c in [["valley, humped deck", hump, valley], ["gorge, dipping deck", dip, gorge]]:
		for style in 2:
			var pk = K.new_kit(1.0)
			var kit := {}
			K.road_bridge(pk, kit, span, hw, c[1], c[2], style)
			_report("road_bridge style %d (%s)" % [style, c[0]], kit, 9000, K.check_corridor(kit, span, hw, c[1]))
		var pk2 = K.new_kit(1.0)
		var kit2 := {}
		K.suspension_bridge(pk2, kit2, span, hw, c[1], c[2])
		_report("suspension_bridge (%s)" % c[0], kit2, 8000, K.check_corridor(kit2, span, hw, c[1]))
	# The ledge walk on a slope, both sides, and the chute.
	for sd in [1.0, -1.0]:
		var pts := PackedVector3Array()
		var rts := PackedVector3Array()
		for k in 31:
			var s: float = 2.0 * float(k)
			pts.append(Vector3(sd * 5.0 * sin(s / 60.0 * PI * 0.9), 30.0 + 0.08 * s, -s))
		for k in 31:
			var f: Vector3 = pts[mini(k + 1, 30)] - pts[maxi(k - 1, 0)]
			rts.append(Vector3(f.x, 0, f.z).normalized().cross(Vector3.UP).normalized())
		var slope := func(x: float, z: float) -> float:
			var s: float = clampf(-z, -20.0, 80.0)
			return 30.0 + 0.08 * s + sd * (sd * 5.0 * sin(s / 60.0 * PI * 0.9) - sd * 1.5 - x)
		var pk = K.new_kit(1.0)
		var kit := {}
		K.ledge_walk(pk, kit, pts, rts, 5.0, sd, slope)
		_report("ledge_walk side %+d (60m: 60 a metre allowed)" % int(sd), kit, 3600, K.check_path_corridor(kit, pts, rts, 5.0))
		if sd > 0.0:
			var cliff := func(_x: float, _z: float) -> float: return -200.0
			var pk3 = K.new_kit(1.0)
			var kit3 := {}
			K.ledge_walk(pk3, kit3, pts, rts, 5.0, sd, cliff)
			_report("ledge_walk over nothing", kit3, 3600, K.check_path_corridor(kit3, pts, rts, 5.0))
			var ground := func(x: float, z: float) -> float:
				var s: float = clampf(-z, -20.0, 80.0)
				return 30.0 + 0.08 * s - 0.15 - 5.0 * pow(sin(clampf(s / 60.0, 0.0, 1.0) * PI), 2.0) - 0.05 * x
			var pk4 = K.new_kit(1.0)
			var kit4 := {}
			K.timber_chute(pk4, kit4, pts, rts, 5.0, ground)
			_report("timber_chute", kit4, 0, K.check_path_corridor(kit4, pts, rts, 5.0))
	print("RESULT ", "ok" if fails == 0 else "%d FAILED" % fails)
	quit()


func _report(name: String, kit: Dictionary, budget: int, corridor: int) -> void:
	var tris: int = int(PropKit_triangles(kit) / 3.0)
	var lo := Vector3.ONE * INF
	var hi := Vector3.ONE * -INF
	for v in K.PropKit.kit_triangles(kit):
		lo = lo.min(v)
		hi = hi.max(v)
	var line := "%s: %d triangles" % [name, tris]
	if budget > 0:
		line += " (budget %d%s)" % [budget, "" if tris <= budget else " OVER"]
		if tris > budget:
			fails += 1
	if corridor >= 0:
		line += ", corridor %d %s" % [corridor, "" if corridor == 0 else str(K.corridor_notes)]
		if corridor > 0:
			fails += 1
	print(line, "  box ", lo.snappedf(0.01), " .. ", hi.snappedf(0.01))


func PropKit_triangles(kit: Dictionary) -> int:
	return K.PropKit.kit_triangles(kit).size()
