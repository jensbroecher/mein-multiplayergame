extends RefCounted
## The items' symbols: stylised white outlines, one per item (PlayerCart.ItemType's names), shared by
## the item boxes (ItemBox.gd sweeps them into glowing tubes in place of the old "?") and the HUD
## (ItemSymbolIcon.gd draws them in the item slots and the kill feed), so what a box shows is what lands
## in the slot. A boost is a flame, a missile a rocket climbing to the right, a guided missile a smaller
## one with the reticle it's locked on, a shield a heater shield, a shockwave rings round a centre, a
## bomb a round bomb with a lit fuse, lightning a bolt.
##
## Each symbol is a list of strokes in a square from -1 to 1 (y up): {"pts", "closed", "smooth"}, or
## {"dot", "r"} for a filled dot. Smooth strokes are rounded through their points (Catmull-Rom).

const NAMES := ["BOOST", "MISSILE", "GUIDED_MISSILE", "SHIELD", "SHOCKWAVE", "BOMB", "LIGHTNING"]

static var _cache := {}


## The strokes of `item` (a name from NAMES), each a polyline ready to draw: [points, closed], with
## dots as [centre, radius, true] in a third slot. Smoothing is done here.
static func strokes(item: String) -> Array:
	if _cache.has(item):
		return _cache[item]
	var out: Array = []
	for s in _design(item):
		if s.has("dot"):
			out.append([s["dot"], s["r"], true])
			continue
		var pts: PackedVector2Array = s["pts"]
		if s.get("smooth", false):
			pts = _smooth(pts, s.get("closed", false))
		out.append([pts, s.get("closed", false)])
	_cache[item] = out
	return out


static func _design(item: String) -> Array:
	match item:
		"BOOST":
			return [
				{"pts": _v([0.0, -0.92, 0.44, -0.80, 0.68, -0.48, 0.70, -0.08, 0.50, 0.26, 0.58, 0.60, 0.30, 0.38,
						0.18, 0.62, 0.02, 0.96, -0.10, 0.56, -0.32, 0.72, -0.34, 0.32, -0.60, 0.10, -0.70, -0.26,
						-0.60, -0.60, -0.36, -0.84]), "closed": true, "smooth": true},
				{"pts": _v([0.0, -0.62, 0.26, -0.50, 0.32, -0.22, 0.18, 0.10, 0.04, 0.36, -0.06, 0.06, -0.24, -0.06,
						-0.30, -0.32, -0.20, -0.54]), "closed": true, "smooth": true},
			]
		"MISSILE":
			return _rocket(Vector2.ZERO, 1.0)
		"GUIDED_MISSILE":
			var out := _rocket(Vector2(-0.22, -0.22), 0.66)
			var c := Vector2(0.52, 0.52)
			out.append({"pts": _arc(c, 0.3, 0.0, TAU, 28), "closed": true})
			for k in 4:
				var d := Vector2.from_angle(k * PI * 0.5)
				out.append({"pts": PackedVector2Array([c + d * 0.2, c + d * 0.44])})
			out.append({"dot": c, "r": 0.05})
			return out
		"SHIELD":
			var shield := _v([0.0, 0.86, 0.36, 0.72, 0.70, 0.72, 0.70, 0.18, 0.56, -0.32, 0.30, -0.66, 0.0, -0.90,
					-0.30, -0.66, -0.56, -0.32, -0.70, 0.18, -0.70, 0.72, -0.36, 0.72])
			var inner := PackedVector2Array()
			for p in shield:
				inner.append(p * 0.58 + Vector2(0.0, -0.03))
			return [{"pts": shield, "closed": true, "smooth": true}, {"pts": inner, "closed": true, "smooth": true}]
		"SHOCKWAVE":
			var out: Array = [{"pts": _arc(Vector2.ZERO, 0.17, 0.0, TAU, 16), "closed": true}]
			for r in [0.42, 0.66, 0.9]:
				var half: float = 0.62 - r * 0.18
				out.append({"pts": _arc(Vector2.ZERO, r, -half, half, 12)})
				out.append({"pts": _arc(Vector2.ZERO, r, PI - half, PI + half, 12)})
			return out
		"BOMB":
			var c := Vector2(-0.12, -0.18)
			var neck := Vector2.from_angle(PI * 0.25)
			var side := Vector2(-neck.y, neck.x)
			var base := c + neck * 0.56
			var top := c + neck * 0.74
			var spark := Vector2(0.62, 0.70)
			var out: Array = [
				{"pts": _arc(c, 0.6, PI * 0.25 + 0.3, PI * 0.25 + TAU - 0.3, 40)},
				# The cap the fuse comes out of.
				{"pts": PackedVector2Array([base + side * 0.18, top + side * 0.16, top - side * 0.16, base - side * 0.18])},
				# The fuse, curling up to its spark.
				{"pts": PackedVector2Array([top, top + Vector2(0.10, 0.14), Vector2(0.40, 0.66), spark - Vector2(0.08, 0.0)]), "smooth": true},
				# A highlight on the ball.
				{"pts": _arc(c, 0.38, PI * 0.62, PI * 0.95, 8)},
			]
			for k in 6:
				var d := Vector2.from_angle(k * TAU / 6.0 + 0.3)
				out.append({"pts": PackedVector2Array([spark + d * 0.08, spark + d * (0.2 if k % 2 == 0 else 0.14)])})
			return out
		"LIGHTNING":
			# The tips are a little blunt: a needle point mitres out far past the stroke.
			return [{"pts": _v([0.10, 0.92, -0.42, -0.04, -0.04, -0.04, -0.28, -0.86, -0.20, -0.88, 0.44, 0.12, 0.06, 0.12,
					0.40, 0.92]), "closed": true}]
	return []


## A rocket climbing to the upper right, centred on `c`, `s` its size: a body with a pointed nose, a
## band, two fins and three lines of exhaust.
static func _rocket(c: Vector2, s: float) -> Array:
	var rot := PI * 0.22
	var body := _v([-0.56, 0.14, 0.30, 0.14, 0.56, 0.08, 0.76, 0.0, 0.56, -0.08, 0.30, -0.14, -0.56, -0.14])
	var parts: Array = [
		{"pts": body, "closed": true},
		{"pts": _v([0.18, 0.14, 0.18, -0.14])},
		{"pts": _v([-0.30, 0.14, -0.56, 0.42, -0.70, 0.42, -0.56, 0.14])},
		{"pts": _v([-0.30, -0.14, -0.56, -0.42, -0.70, -0.42, -0.56, -0.14])},
		{"pts": _v([-0.70, 0.0, -0.96, 0.0])},
		{"pts": _v([-0.70, 0.08, -0.88, 0.18])},
		{"pts": _v([-0.70, -0.08, -0.88, -0.18])},
	]
	for p in parts:
		var pts: PackedVector2Array = p["pts"]
		for i in pts.size():
			pts[i] = c + pts[i].rotated(rot) * s
		p["pts"] = pts
	return parts


static func _v(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		out.append(Vector2(flat[i], flat[i + 1]))
	return out


static func _arc(c: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n + 1):
		out.append(c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * r)
	if is_equal_approx(fposmod(a1 - a0, TAU), 0.0):
		out.remove_at(out.size() - 1)
	return out


## Catmull-Rom through the points, 6 steps a span.
static func _smooth(pts: PackedVector2Array, closed: bool) -> PackedVector2Array:
	var n := pts.size()
	var out := PackedVector2Array()
	var spans := n if closed else n - 1
	for i in range(spans):
		var p0 := pts[(i - 1 + n) % n] if (closed or i > 0) else pts[0]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n] if (closed or i + 2 < n) else pts[n - 1]
		for k in 6:
			var t := k / 6.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	if not closed:
		out.append(pts[n - 1])
	return out
