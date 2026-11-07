extends SceneTree
## Checks where each procedural car's antenna stands (its AntennaPlacement, the builder's ANTENNA_POS): the body's
## surface straight under (or over) its foot, so the rod neither floats over the paint nor starts deep inside it, how
## steep the surface is there, and anything of the body (or its glass) the rod's 0.8m runs into. Headless:
##   Godot --headless --path . -s res://scratch/antenna_check.gd -- [cars=Bootlegger,Meteor,...] [rod=0.8]
## gap: the foot's height over the surface under it (+ floating, - sunk). The rod is PlayerCart.tscn's Visuals/Antenna/Rod
## (from the foot up, 1cm thick at the foot). Prints OK when the foot is within -2.5..+0.3cm of the surface on ground
## flatter than 35 degrees and nothing is in the rod's way.

const RegenCars = preload("res://regenerate_cars.gd")


func _init() -> void:
	var only: PackedStringArray = []
	var rod := 0.8
	for a in OS.get_cmdline_user_args():
		if a.begins_with("cars="):
			only = a.substr(5).split(",")
		elif a.begins_with("rod="):
			rod = float(a.substr(4))
	var bad := 0
	for car in RegenCars.CARS:
		var car_name: String = car["name"]
		if not only.is_empty() and not only.has(car_name):
			continue
		var scene: PackedScene = load("res://generated/cars/%s.tscn" % car_name)
		var root: Node3D = scene.instantiate()
		var model: Node3D = root.get_node("Model")
		var place: Node3D = model.get_node_or_null("AntennaPlacement")
		if place == null:
			print("%-12s no AntennaPlacement" % car_name)
			bad += 1
			root.free()
			continue
		var foot: Vector3 = place.position
		var tris := PackedVector3Array()
		for part in ["Body", "Glass"]:
			var mi := model.get_node_or_null(part) as MeshInstance3D
			if mi != null:
				tris.append_array(mi.mesh.get_faces())
		# The surface under the foot: the nearest crossing of a vertical line through it, above or below.
		var hits: Array = _hits(tris, Vector2(foot.x, foot.z))
		var best = null
		for h in hits:
			if best == null or absf(float(h[0]) - foot.y) < absf(float(best[0]) - foot.y):
				best = h
		var line := "%-12s foot (%.3f, %.3f, %.3f)" % [car_name, foot.x, foot.y, foot.z]
		var ok := true
		if best == null:
			line += "  NOTHING under it"
			ok = false
		else:
			var gap: float = foot.y - float(best[0])
			var slope: float = rad_to_deg(acos(clampf(absf((best[1] as Vector3).y), 0.0, 1.0)))
			line += "  surface %.3f  gap %+.1fcm  slope %.0f deg" % [float(best[0]), gap * 100.0, slope]
			if gap > 0.003 or gap < -0.025 or slope > 35.0:
				ok = false
		# Anything in the rod's way: crossings of five lines up the rod (its axis and 1.2cm either side), from 2cm over the
		# foot (or over the surface, if the foot is sunk) to its top.
		var y0: float = maxf(foot.y, float(best[0]) if best != null else foot.y) + 0.02
		var blocked := []
		for off in [Vector2.ZERO, Vector2(0.012, 0), Vector2(-0.012, 0), Vector2(0, 0.012), Vector2(0, -0.012)]:
			for h in _hits(tris, Vector2(foot.x, foot.z) + off):
				if float(h[0]) > y0 and float(h[0]) < foot.y + rod:
					blocked.append("%.3f" % float(h[0]))
		if not blocked.is_empty():
			line += "  BLOCKED at y " + ", ".join(blocked.slice(0, 4))
			ok = false
		print(line + ("  OK" if ok else "  <--"))
		if not ok:
			bad += 1
		root.free()
	print("RESULT: %s (%d to fix)" % ["PASS" if bad == 0 else "FAIL", bad])
	quit()


## Where a vertical line at (x, z) crosses the triangles: [y, the triangle's normal] each.
static func _hits(tris: PackedVector3Array, p: Vector2) -> Array:
	var out: Array = []
	for i in range(0, tris.size(), 3):
		var a: Vector3 = tris[i]
		var b: Vector3 = tris[i + 1]
		var c: Vector3 = tris[i + 2]
		var minx: float = minf(a.x, minf(b.x, c.x))
		var maxx: float = maxf(a.x, maxf(b.x, c.x))
		var minz: float = minf(a.z, minf(b.z, c.z))
		var maxz: float = maxf(a.z, maxf(b.z, c.z))
		if p.x < minx or p.x > maxx or p.y < minz or p.y > maxz:
			continue
		var hit = Geometry3D.ray_intersects_triangle(Vector3(p.x, 10.0, p.y), Vector3.DOWN, a, b, c)
		if hit == null:
			hit = Geometry3D.ray_intersects_triangle(Vector3(p.x, 10.0, p.y), Vector3.DOWN, a, c, b)
		if hit != null:
			out.append([(hit as Vector3).y, (b - a).cross(c - a).normalized()])
	return out
