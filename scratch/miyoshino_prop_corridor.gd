extends SceneTree
## Checks the torii's clear corridor on its built triangles (headless): nothing may be inside |x| < w/2 - pillar radius
## - 0.05 below y = h. Every triangle is sampled on a fine barycentric grid.
##   Godot --headless --path . -s res://scratch/miyoshino_prop_corridor.gd [-- w,h ...]

const K = preload("res://MiyoshinoPropKit.gd")


func _init() -> void:
	var cases: Array = [Vector2(4.6, 4.4), Vector2(11.0, 7.5), Vector2(1.5, 1.75), Vector2(8.0, 4.0)]
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		cases = []
		for a in args:
			var f := a.split_floats(",")
			cases.append(Vector2(f[0], f[1]))
	for c: Vector2 in cases:
		for style in range(3):
			var pk = K.new_kit(1.0)
			var kit := {}
			K.torii(pk, kit, style, c.x, c.y)
			var tris: PackedVector3Array = K.PropKit.kit_triangles(kit)
			var lim: float = c.x * 0.5 - K.torii_pillar_radius(c.x) - 0.05
			var bad := 0
			var worst := 0.0
			var lowest := INF
			for i in range(0, tris.size(), 3):
				var hit := false
				for u in range(13):
					for v in range(13 - u):
						var p: Vector3 = tris[i] + (tris[i + 1] - tris[i]) * (float(u) / 12.0) + (tris[i + 2] - tris[i]) * (float(v) / 12.0)
						if absf(p.x) < lim - 1e-4:
							lowest = minf(lowest, p.y)
							if p.y < c.y - 1e-4:
								hit = true
								worst = maxf(worst, lim - absf(p.x))
				if hit:
					bad += 1
			print("torii style %d w %.1f h %.1f: %d triangles, corridor |x| < %.3f below %.2f: %s (lowest thing inside it at y %.3f)" % [style, c.x, c.y, tris.size() / 3, lim, c.y,
					"CLEAR" if bad == 0 else "%d TRIANGLES INSIDE, up to %.3f in" % [bad, worst], lowest])
	quit()
