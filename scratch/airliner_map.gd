extends SceneTree
## A map of a level's skies for laying out its Airliners routes: the ground (TerrainGenerator's own inside the rim, the
## FarCountry backdrop's triangles past it) shaded by height, the lap in red, the skyline in blue, the race cameras'
## 4km reach from the lap as a ring, and each route of the level's Airliners node (arrivals yellow, departures cyan,
## darker the higher) with a dot every km. Prints, per route, its length and time, the lowest it comes over the ground
## (away from its runway), and how near it passes the lap and how high it is there. Headless:
##   Godot --headless --path . -s res://scratch/airliner_map.gd -- <level.tscn> <out.png> [half=5500] [px=10]

const Airliners = preload("res://Airliners.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	var out: String = args[1]
	var half := 5500.0
	var px := 10.0
	for a in args.slice(2):
		if a.begins_with("half="):
			half = float(a.substr(5))
		elif a.begins_with("px="):
			px = float(a.substr(3))
	var root: Node = (load(level_path) as PackedScene).instantiate()
	var n: int = int(half * 2.0 / px)
	var hgt := PackedFloat32Array()
	hgt.resize(n * n)
	hgt.fill(-1e9)
	# The country past the rim: its mesh's triangles, rasterised.
	var far := root.find_child("FarCountry", true, false) as MeshInstance3D
	if far:
		var arr := far.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var ids: PackedInt32Array = idx if idx != null else PackedInt32Array(range(v.size()))
		for t in range(0, ids.size(), 3):
			_raster(hgt, n, half, px, v[ids[t]], v[ids[t + 1]], v[ids[t + 2]])
	# Inside the rim: the terrain generator's heights.
	var tg = root.get_node_or_null("TerrainGenerator")
	var path: Path3D = root.get_node("TrackPath")
	if tg:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = tg.noise_frequency
		noise.seed = 12345
		noise.fractal_octaves = 4
		for j in range(n):
			for i in range(n):
				var x: float = -half + (i + 0.5) * px
				var z: float = -half + (j + 0.5) * px
				if x * x + z * z < 880.0 * 880.0:
					hgt[j * n + i] = tg._get_terrain_height(x, z, noise, path.curve, false, false)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var sun := Vector3(-0.6, 0.75, -0.3).normalized()
	for j in range(n):
		for i in range(n):
			var y: float = hgt[j * n + i]
			if y < -1e8:
				img.set_pixel(i, j, Color(0.12, 0.2, 0.32))
				continue
			var yx: float = hgt[j * n + mini(i + 1, n - 1)]
			var yz: float = hgt[mini(j + 1, n - 1) * n + i]
			if yx < -1e8:
				yx = y
			if yz < -1e8:
				yz = y
			var nrm := Vector3(-(yx - y) / px, 1.0, -(yz - y) / px).normalized()
			var shade: float = clampf(nrm.dot(sun), 0.25, 1.0)
			var c: Color
			if y < 0.3:
				c = Color(0.2, 0.36, 0.5)
			else:
				c = Color(0.86, 0.68, 0.45).lerp(Color(0.45, 0.34, 0.27), clampf(y / 300.0, 0.0, 1.0))
			img.set_pixel(i, j, c * shade)
	# The skyline.
	for sk in root.find_children("Skyline*", "MeshInstance3D", true, false):
		var ab: AABB = (sk as MeshInstance3D).mesh.get_aabb()
		_rect(img, n, half, px, Vector2(ab.position.x, ab.position.z), Vector2(ab.end.x, ab.end.z), Color(0.3, 0.45, 0.95))
	# The lap and the cameras' reach.
	var c3 := path.curve
	var L := c3.get_baked_length()
	var lap: Array = []
	var s := 0.0
	while s < L:
		var p := c3.sample_baked(s)
		lap.append(Vector2(p.x, p.z))
		s += 5.0
	for p in lap:
		_dot(img, n, half, px, p, 1, Color(0.9, 0.1, 0.1))
	var centre := Vector2.ZERO
	for p in lap:
		centre += p
	centre /= float(lap.size())
	for k in range(720):
		var a: float = TAU * k / 720.0
		_dot(img, n, half, px, centre + Vector2.from_angle(a) * 4000.0, 0, Color(1, 1, 1))
		_dot(img, n, half, px, centre + Vector2.from_angle(a) * 2000.0, 0, Color(0.8, 0.8, 0.8))
	# The routes.
	var air := root.find_child("Airliners", true, false)
	if air:
		var routes: Array = air.get("routes")
		for ri in range(routes.size()):
			var rt: Dictionary = Airliners.build_route(routes[ri])
			var pos: PackedVector3Array = rt.pos
			var sv: PackedFloat32Array = rt.s
			var arr_k: bool = rt.kind == "arr"
			var lowest := 1e9
			var low_at := Vector3.ZERO
			var nearest := 1e9
			var near_at := Vector3.ZERO
			var next_km := 0.0
			for j in range(pos.size()):
				var q: Vector3 = pos[j]
				var hh: float = q.y - float(rt.ground)
				var col := (Color(1.0, 0.85, 0.1) if arr_k else Color(0.2, 0.95, 1.0)).darkened(clampf(hh / 1800.0, 0.0, 0.75))
				_dot(img, n, half, px, Vector2(q.x, q.z), 1, col)
				if sv[j] >= next_km:
					_dot(img, n, half, px, Vector2(q.x, q.z), 3, col)
					next_km += 1000.0
				var g: float = _ground_at(hgt, n, half, px, q.x, q.z)
				if hh > 1.0 and g > -1e8 and q.y - g < lowest:
					lowest = q.y - g
					low_at = q
				for p in lap:
					var dd: float = (p as Vector2).distance_to(Vector2(q.x, q.z))
					if dd < nearest:
						nearest = dd
						near_at = q
			print("route %d %s: %.1fkm, %.0fs, every %.0fs; lowest %.0fm over the ground at (%.0f, %.0f, %.0f); nearest the lap %.0fm, %.0fm up, at (%.0f, %.0f)" % [
				ri, rt.kind, float(sv[sv.size() - 1]) / 1000.0, float(rt.total), float(rt.every), lowest, low_at.x, low_at.y, low_at.z,
				nearest, near_at.y, near_at.x, near_at.z])
	img.save_png(out)
	print("map ", out, " (", n, "px, ", px, "m a pixel, north up)")
	root.free()
	quit()


func _ground_at(hgt: PackedFloat32Array, n: int, half: float, px: float, x: float, z: float) -> float:
	var i: int = int((x + half) / px)
	var j: int = int((z + half) / px)
	if i < 0 or j < 0 or i >= n or j >= n:
		return -1e9
	return hgt[j * n + i]


func _raster(hgt: PackedFloat32Array, n: int, half: float, px: float, a: Vector3, b: Vector3, c: Vector3) -> void:
	var x0: int = maxi(int((minf(a.x, minf(b.x, c.x)) + half) / px), 0)
	var x1: int = mini(int((maxf(a.x, maxf(b.x, c.x)) + half) / px), n - 1)
	var z0: int = maxi(int((minf(a.z, minf(b.z, c.z)) + half) / px), 0)
	var z1: int = mini(int((maxf(a.z, maxf(b.z, c.z)) + half) / px), n - 1)
	if x0 > x1 or z0 > z1:
		return
	var d: float = (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
	if absf(d) < 1e-6:
		return
	for j in range(z0, z1 + 1):
		for i in range(x0, x1 + 1):
			var x: float = -half + (i + 0.5) * px
			var z: float = -half + (j + 0.5) * px
			var w1: float = ((x - a.x) * (c.z - a.z) - (c.x - a.x) * (z - a.z)) / d
			var w2: float = ((b.x - a.x) * (z - a.z) - (x - a.x) * (b.z - a.z)) / d
			var w0: float = 1.0 - w1 - w2
			if w0 >= -0.001 and w1 >= -0.001 and w2 >= -0.001:
				hgt[j * n + i] = maxf(hgt[j * n + i], a.y * w0 + b.y * w1 + c.y * w2)


func _dot(img: Image, n: int, half: float, px: float, p: Vector2, r: int, col: Color) -> void:
	var ci: int = int((p.x + half) / px)
	var cj: int = int((p.y + half) / px)
	for j in range(cj - r, cj + r + 1):
		for i in range(ci - r, ci + r + 1):
			if i >= 0 and j >= 0 and i < n and j < n:
				img.set_pixel(i, j, col)


func _rect(img: Image, n: int, half: float, px: float, lo: Vector2, hi: Vector2, col: Color) -> void:
	for j in range(int((lo.y + half) / px), int((hi.y + half) / px) + 1):
		for i in range(int((lo.x + half) / px), int((hi.x + half) / px) + 1):
			if i >= 0 and j >= 0 and i < n and j < n:
				img.set_pixel(i, j, img.get_pixel(i, j).lerp(col, 0.45))
