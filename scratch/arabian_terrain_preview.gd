extends SceneTree
## Hillshaded height map of a level's TerrainGenerator ground (its base shapes, the road not blended in),
## with the lap drawn over it in red, to judge the dunes and the jebel without a re-bake.
##   Godot --headless --path . -s res://scratch/arabian_terrain_preview.gd -- <level.tscn> <out.png> [step=4] [half=900]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var level_path: String = args[0]
	var out: String = args[1]
	var step := 4.0
	var half := 900.0
	for a in args.slice(2):
		if a.begins_with("step="):
			step = float(a.substr(5))
		elif a.begins_with("half="):
			half = float(a.substr(5))
	var level: Node = (load(level_path) as PackedScene).instantiate()
	var tg = level.get_node("TerrainGenerator")
	var path: Path3D = level.get_node("TrackPath")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = tg.noise_frequency
	noise.seed = 12345
	noise.fractal_octaves = 4
	var n: int = int(half * 2.0 / step)
	var h := PackedFloat32Array()
	h.resize(n * n)
	var lo := 1e9
	var hi := -1e9
	for j in range(n):
		for i in range(n):
			var x: float = -half + i * step
			var z: float = -half + j * step
			var y: float = tg._get_terrain_height(x, z, noise, path.curve, false, false)
			h[j * n + i] = y
			lo = minf(lo, y)
			hi = maxf(hi, y)
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var sun := Vector3(-0.6, 0.7, -0.4).normalized()
	for j in range(1, n - 1):
		for i in range(1, n - 1):
			var dx: float = h[j * n + i + 1] - h[j * n + i - 1]
			var dz: float = h[(j + 1) * n + i] - h[(j - 1) * n + i]
			var nn := Vector3(-dx, 2.0 * step, -dz).normalized()
			var shade: float = clampf(nn.dot(sun), 0.0, 1.0)
			var t: float = (h[j * n + i] - lo) / maxf(hi - lo, 0.01)
			var base := Color(0.85, 0.62, 0.38).lerp(Color(0.45, 0.38, 0.34), smoothstep(0.35, 0.8, t))
			img.set_pixel(i, j, base * (0.35 + 0.75 * shade))
	var c: Curve3D = path.curve
	var length: float = c.get_baked_length()
	var s := 0.0
	while s < length:
		var p: Vector3 = c.sample_baked(s)
		var pi_: int = int((p.x + half) / step)
		var pj: int = int((p.z + half) / step)
		if pi_ >= 0 and pj >= 0 and pi_ < n and pj < n:
			img.set_pixel(pi_, pj, Color(0.9, 0.1, 0.1))
		s += step * 0.5
	img.save_png(out)
	print("HEIGHTS ", lo, " .. ", hi, " -> ", out)
	level.free()
	quit(0)
