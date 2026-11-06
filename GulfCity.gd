extends "res://BloombayCity.gd"
## Marina Nights' city (regenerate_marina_nights.gd): BloombayCity's facade machinery (city_building.gdshader with its
## `gulf` facades: pointed-arch windows, mashrabiya screens, arcades) on Gulf buildings and towers, so the stage reads
## as its own city, not Mtaa Nights' or Bloombay's:
##   gulf_block   stucco blocks, flat roofed, a parapet of stepped merlons, now and then a wind tower, a small dome
##                or a roof terrace's pergola; setback upper floors on the bigger ones
##   gulf_tower   one of five silhouettes: a sail (a curved blade tapering to a point), a twisted tower (square floor
##                plates turning as they rise), a stepped spire (a three-lobed plan stepping in, a needle), a crown
##                tower (a square shaft under an open lattice crown) and a pair of slender twins joined by a sky bridge
## Domes go into the roofs surface (vertex colour, the roof material): pale stucco or gilded.

const SAND_WALLS := [Color(0.90, 0.80, 0.64), Color(0.86, 0.74, 0.58), Color(0.94, 0.88, 0.76), Color(0.80, 0.68, 0.52), Color(0.92, 0.84, 0.70)]
const GLASS_GULF := [Color(0.32, 0.40, 0.46), Color(0.44, 0.40, 0.32), Color(0.30, 0.42, 0.40), Color(0.40, 0.44, 0.48)]


## Stepped merlons along every edge of a plan's top at `y` (plain stucco, COLOR.a 0.7).
func merlon_rim(x: float, z: float, plan: PackedVector2Array, yaw: float, y: float, street: float, col: Color, pitch := 1.8) -> void:
	var b := Basis(Vector3.UP, yaw)
	var n := plan.size()
	for i in range(n):
		var a: Vector2 = plan[i]
		var e: Vector2 = plan[(i + 1) % n]
		var length: float = a.distance_to(e)
		var cnt: int = maxi(1, int(length / pitch))
		var dir: Vector2 = (e - a) / length
		var ang: float = atan2(dir.y, dir.x)
		for k in range(cnt):
			var c2: Vector2 = a + dir * (length * (float(k) + 0.5) / cnt)
			var w: Vector3 = b * Vector3(c2.x, 0, c2.y)
			var small := plan_shape(0, 0.32)
			prism(x + w.x, z + w.z, small, yaw - ang, y, y + 0.7, street, col, 0.7, 0)
			prism(x + w.x, z + w.z, plan_shape(0, 0.18), yaw - ang, y + 0.7, y + 1.15, street, col, 0.7, 0)


## A dome over (x, top, z), radius `r`: a lathe of a slightly pointed profile into the roofs surface.
func dome(x: float, z: float, top: float, r: float, col: Color) -> void:
	var seg := 14
	var rings: Array = []
	for k in range(7):
		var a: float = PI * 0.5 * float(k) / 6.0
		rings.append(Vector2(r * cos(a), r * sin(a) * 1.15))
	rings[6] = Vector2(0.0, r * 1.25)
	for k in range(rings.size() - 1):
		var p0: Vector2 = rings[k]
		var p1: Vector2 = rings[k + 1]
		for j in range(seg):
			var a0: float = TAU * j / seg
			var a1: float = TAU * (j + 1) / seg
			var q00 := Vector3(x + cos(a0) * p0.x, top + p0.y, z + sin(a0) * p0.x)
			var q01 := Vector3(x + cos(a1) * p0.x, top + p0.y, z + sin(a1) * p0.x)
			var q10 := Vector3(x + cos(a0) * p1.x, top + p1.y, z + sin(a0) * p1.x)
			var q11 := Vector3(x + cos(a1) * p1.x, top + p1.y, z + sin(a1) * p1.x)
			var am: float = (a0 + a1) * 0.5
			var nrm := Vector3(cos(am) * (p0.y - p1.y) * -1.0, p1.x - p0.x, sin(am) * (p0.y - p1.y) * -1.0)
			nrm = Vector3(cos(am), 0.0, sin(am)) * absf(p1.y - p0.y) + Vector3.UP * absf(p0.x - p1.x)
			nrm = nrm.normalized()
			tri(roofs, q00, q01, q11, nrm, col)
			tri(roofs, q00, q11, q10, nrm, col)


## A Gulf block: `storeys` over `ground`, `w` x `d`, turned `yaw`.
func gulf_block(x: float, z: float, ground: float, w: float, d: float, yaw: float, storeys: int, col: Color, style: int, rng: RandomNumberGenerator) -> void:
	var plan := PackedVector2Array([Vector2(-w, -d) * 0.5, Vector2(w, -d) * 0.5, Vector2(w, d) * 0.5, Vector2(-w, d) * 0.5])
	var top: float = ground + SHOP_H + float(maxi(storeys - 1, 0)) * STOREY + 0.6
	prism(x, z, plan, yaw, ground - 2.0, top, ground, col, 0.0, style)
	var b := Basis(Vector3.UP, yaw)
	var trim: Color = col.lightened(0.12)
	# A setback top floor on the bigger blocks, its own merlons.
	var up_top := top
	if storeys >= 5 and w > 20.0 and rng.randf() < 0.6:
		var plan2 := PackedVector2Array([Vector2(-w * 0.32, -d * 0.3), Vector2(w * 0.32, -d * 0.3), Vector2(w * 0.32, d * 0.3), Vector2(-w * 0.32, d * 0.3)])
		up_top = top + STOREY
		prism(x, z, plan2, yaw, top, up_top, ground, col, 0.0, style)
		merlon_rim(x, z, plan2, yaw, up_top, ground, trim)
	merlon_rim(x, z, plan, yaw, top, ground, trim)
	# Roof features: a wind tower, a dome, or a pergola.
	var pick: float = rng.randf()
	if pick < 0.35:
		var o: Vector3 = b * Vector3(rng.randf_range(-w, w) * 0.3, 0, rng.randf_range(-d, d) * 0.3)
		var tw: float = rng.randf_range(1.6, 2.4)
		prism(x + o.x, z + o.z, plan_shape(0, tw), yaw, top, top + 6.5, ground, trim, 0.7, 0)
		# Its open bays: a dark band (glass kind, unlit) and a cap.
		prism(x + o.x, z + o.z, plan_shape(0, tw * 0.98), yaw, top + 3.4, top + 6.0, ground, Color(0.06, 0.05, 0.05), 0.75, 0)
		prism(x + o.x, z + o.z, plan_shape(0, tw * 1.08), yaw, top + 6.0, top + 6.6, ground, trim, 0.7, 0)
		merlon_rim(x + o.x, z + o.z, plan_shape(0, tw), yaw, top + 6.6, ground, trim, 0.9)
	elif pick < 0.55:
		var gold: bool = rng.randf() < 0.25
		var r: float = minf(w, d) * rng.randf_range(0.16, 0.26)
		prism(x, z, plan_shape(3, r), yaw, up_top, up_top + 1.4, ground, trim, 0.7, 0)
		dome(x, z, up_top + 1.4, r, Color(0.86, 0.66, 0.30) if gold else Color(0.94, 0.90, 0.82))
	elif pick < 0.7:
		# A roof terrace's pergola: posts and slats.
		var pw: float = w * 0.35
		var pd: float = d * 0.35
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var o2: Vector3 = b * Vector3(sx * pw, 0, sz * pd)
				prism(x + o2.x, z + o2.z, plan_shape(0, 0.15), yaw, up_top, up_top + 2.8, ground, trim, 0.7, 0)
		for k in range(7):
			var o3: Vector3 = b * Vector3(-pw + 2.0 * pw * float(k) / 6.0, 0, 0)
			prism(x + o3.x, z + o3.z, PackedVector2Array([Vector2(-0.1, -pd), Vector2(0.1, -pd), Vector2(0.1, pd), Vector2(-0.1, pd)]), yaw,
					up_top + 2.8, up_top + 3.0, ground, Color(0.40, 0.28, 0.18), 0.7, 0)
	count += 1


## A tower of `kind` (0 sail, 1 twisted, 2 stepped spire, 3 crown, 4 twins), `h` tall to its roof, `w` across.
func gulf_tower(x: float, z: float, ground: float, w: float, h: float, kind: int, rng: RandomNumberGenerator) -> void:
	var yaw: float = rng.randf() * TAU
	var glass: Color = GLASS_GULF[rng.randi() % GLASS_GULF.size()]
	var stone: Color = SAND_WALLS[rng.randi() % SAND_WALLS.size()]
	var pod_h: float = SHOP_H + STOREY
	var pod := plan_shape(1, w * 0.8)
	prism(x, z, pod, yaw, ground - 2.0, ground + pod_h, ground, stone, 0.0, 0)
	merlon_rim(x, z, pod, yaw, ground + pod_h, ground, stone.lightened(0.1))
	var y0: float = ground + pod_h
	var segs := 14
	match kind:
		0:
			# The sail: a D plan, its round back to one side, the blade tapering to a point at the top, leaning back.
			for k in range(segs):
				var t0: float = float(k) / segs
				var t1: float = float(k + 1) / segs
				var sh: float = 1.0 - pow(t1, 1.6) * 0.92
				var off := Vector2(0, -w * 0.35 * pow(t1, 2.0))
				var plan := PackedVector2Array()
				for i in range(9):
					var a: float = -PI * 0.5 + PI * float(i) / 8.0
					plan.append(off + Vector2(cos(a) * w * 0.55, sin(a) * w * 0.5) * sh)
				plan.append(off + Vector2(-w * 0.1, w * 0.5) * sh)
				plan.append(off + Vector2(-w * 0.1, -w * 0.5) * sh)
				prism(x, z, plan, yaw, y0 + h * t0, y0 + h * t1, ground, glass, 1.0, 0)
			prism(x, z, plan_shape(3, 0.5), yaw, y0 + h, y0 + h * 1.12, ground, Color(0.85, 0.86, 0.88), 0.7, 0)
		1:
			# Twisted: square plates turning 4 degrees a segment.
			for k in range(segs):
				var t0: float = float(k) / segs
				var t1: float = float(k + 1) / segs
				var r: float = w * 0.5 * (1.0 - 0.18 * t1)
				prism(x, z, plan_shape(1, r), yaw + deg_to_rad(5.5) * k, y0 + h * t0, y0 + h * t1, ground, glass, 1.0, 0)
			prism(x, z, plan_shape(1, w * 0.36), yaw + deg_to_rad(5.5) * segs, y0 + h, y0 + h + 6.0, ground, stone, 0.7, 0)
		2:
			# Stepped spire: a three-lobed plan stepping in at three heights, a needle.
			var r := w * 0.55
			var yb := y0
			for tier in range(4):
				var th: float = h * [0.42, 0.26, 0.18, 0.14][tier]
				var plan := PackedVector2Array()
				for i in range(18):
					var a: float = TAU * float(i) / 18.0
					var lobe: float = 0.72 + 0.28 * cos(a * 3.0)
					plan.append(Vector2(cos(a), sin(a)) * r * lobe)
				prism(x, z, plan, yaw, yb, yb + th, ground, glass, 1.0, 0)
				prism(x, z, plan_shape(3, r * 0.82), yaw, yb + th - 0.8, yb + th, ground, stone.lightened(0.15), 0.7, 0)
				yb += th
				r *= 0.74
			prism(x, z, plan_shape(3, 0.9), yaw, yb, yb + h * 0.22, ground, Color(0.86, 0.87, 0.90), 0.7, 0)
			prism(x, z, plan_shape(3, 0.25), yaw, yb + h * 0.22, yb + h * 0.38, ground, Color(0.86, 0.87, 0.90), 0.7, 0)
		3:
			# Crown: a square shaft, an open lattice crown of posts and rings over it.
			var r2 := w * 0.48
			prism(x, z, plan_shape(1, r2), yaw, y0, y0 + h, ground, glass, 1.0, 0)
			var cb := Basis(Vector3.UP, yaw)
			for ring in range(4):
				var yy: float = y0 + h + ring * 4.5
				prism(x, z, plan_shape(1, r2 * (1.0 - ring * 0.12)), yaw, yy, yy + 0.7, ground, stone, 0.7, 0, true)
			for i in range(8):
				var a: float = TAU * float(i) / 8.0 + PI / 8.0
				var o: Vector3 = cb * Vector3(cos(a), 0, sin(a)) * r2 * 0.95
				prism(x + o.x, z + o.z, plan_shape(0, 0.35), yaw, y0 + h, y0 + h + 16.0, ground, stone, 0.7, 0)
		4:
			# Twins: two slender shafts and a sky bridge between them two thirds up.
			var cb := Basis(Vector3.UP, yaw)
			var sep: float = w * 0.75
			for sd in [-1.0, 1.0]:
				var o: Vector3 = cb * Vector3(sd * sep, 0, 0)
				prism(x + o.x, z + o.z, plan_shape(2, w * 0.36), yaw, y0, y0 + h, ground, glass, 1.0, 0)
				prism(x + o.x, z + o.z, plan_shape(2, w * 0.25), yaw, y0 + h, y0 + h + 8.0, ground, stone, 0.7, 0)
				prism(x + o.x, z + o.z, plan_shape(3, 0.3), yaw, y0 + h + 8.0, y0 + h + 30.0, ground, Color(0.86, 0.87, 0.90), 0.7, 0)
			var bridge := PackedVector2Array([Vector2(-sep, -2.5), Vector2(sep, -2.5), Vector2(sep, 2.5), Vector2(-sep, 2.5)])
			prism(x, z, bridge, yaw, y0 + h * 0.66, y0 + h * 0.66 + 7.0, ground, glass, 1.0, 0)
	count += 1
