extends "res://PortKit.gd"
## Harbor Pier's vessels (regenerate_harbor_pier.gd), built through a PropKit at life size and grown by the caller
## (PROP_SCALE): the feeder container ship at the terminal, the tug, fishing boats and sailing yachts. Every vessel's
## frame: the bow toward +z, y = 0 the waterline, x = 0 the centre line (SeaBoat.gd's convention, so the small ones
## sail as its models).
##
## A hull is a loft of rings (`hull`): each ring the plan outline at that height, from just under the waterline (a
## blunter outline) up to the sheer (the deck's, flared out at the bow), so the bow flares; rings are doubled where the
## paint changes (antifouling, topsides, sheer stripe) so the colours have hard edges. The bow's sheer rises into a
## forecastle; the stern is a flat transom.

## [height over the waterline, paint] from the bottom ring up; a repeated height starts a new colour.
static func _bands(fb: float, bottom: Color, top: Color, stripe: Color, boot := 0.4) -> Array:
	return [[-1.2, bottom], [boot, bottom], [boot, top], [fb - 0.45, top], [fb - 0.45, stripe], [fb, stripe]]


## Half breadth at t (0 stern .. 1 bow) of a plan outline: full amidships, a flat transom of `transom` share at the
## stern rounding into the sides over `stern_run`, the bow drawn in over `bow_run` to a point.
static func _hb(t: float, half: float, bow_run: float, stern_run: float, transom: float, bluff := 1.0) -> float:
	var h := half
	if t > 1.0 - bow_run:
		var u: float = (t - (1.0 - bow_run)) / bow_run
		h *= pow(maxf(1.0 - u * u, 0.0), 0.55 * bluff)
	if t < stern_run:
		var v: float = (stern_run - t) / stern_run
		h *= lerpf(1.0, transom, v * v)
	return h


## The hull from the waterline outline (`half_wl`, its bow drawn in over `bow_wl`) to the sheer (`half`, `bow_run`),
## `length` long, the sheer `fb` over the water rising by `fc` toward the bow (the forecastle) from `fc_from` (t), and by
## `sheer_bow`/`sheer_stern` in a smooth curve toward either end (a small craft's sheer). `bands` from `_bands`. Normals
## are smooth along each side and up it (taken from the neighbouring points on the same side and the rings at other
## heights), the transom stays flat. Where the sheer stands above `deck_y` (NAN: `fb`) the bulwark's inside is drawn too,
## capped in `cap`. Returns the deck outline at the sheer (x, z).
static func hull(pk: PropKit, kit: Dictionary, length: float, half: float, half_wl: float, fb: float, bands: Array,
		bow_run := 0.22, bow_wl := 0.3, stern_run := 0.08, transom := 0.72, fc := 0.0, fc_from := 0.82, n := 40,
		sheer_bow := 0.0, sheer_stern := 0.0, deck_y := NAN, cap := Color(0.85, 0.85, 0.82)) -> PackedVector2Array:
	var hl := length * 0.5
	var dy: float = fb if is_nan(deck_y) else deck_y
	# Each ring: two sides of n + 1 points (starboard, port), stern to bow.
	var rings: Array = []
	var cols: Array = []
	for bd in bands:
		var y: float = bd[0]
		var sides: Array = []
		var f: float = pow(clampf((y + 1.2) / (fb + 1.2), 0.0, 1.0), 1.6)
		for side in [1.0, -1.0]:
			var pts: Array = []
			for i in range(n + 1):
				var t: float = float(i) / float(n)
				var z_top: float = -hl + t * length
				var z_wl: float = -hl + t * length * 0.97
				var hb_top: float = _hb(t, half, bow_run, stern_run, transom)
				var hb_wl: float = _hb(t, half_wl, bow_wl, stern_run * 1.4, transom * 0.85, 1.3)
				var yy: float = y
				if y >= fb - 0.5:
					yy += fc * smoothstep(fc_from, fc_from + 0.1, t)
					yy += sheer_bow * pow(smoothstep(0.35, 1.0, t), 2.0) + sheer_stern * pow(smoothstep(0.55, 0.0, t), 2.0)
				pts.append(Vector3(lerpf(hb_wl, hb_top, f) * side, yy, lerpf(z_wl, z_top, f)))
			sides.append(pts)
		rings.append(sides)
		cols.append(bd[1])
	# Rings at distinct heights, for the normals' vertical direction.
	var distinct: Array = []
	for r in range(rings.size()):
		if distinct.is_empty() or absf(float(bands[r][0]) - float(bands[distinct[distinct.size() - 1]][0])) > 0.001:
			distinct.append(r)
	var nrm_of := func(r: int, sd: int, i: int) -> Vector3:
		var pts: Array = rings[r][sd]
		var tan_v: Vector3 = (pts[mini(i + 1, n)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)
		var di: int = distinct.find(r)
		if di < 0:
			for k in range(distinct.size()):
				if absf(float(bands[distinct[k]][0]) - float(bands[r][0])) < 0.001:
					di = k
		var lo: int = distinct[maxi(di - 1, 0)]
		var hi: int = distinct[mini(di + 1, distinct.size() - 1)]
		var up_v: Vector3 = (rings[hi][sd][i] as Vector3) - (rings[lo][sd][i] as Vector3)
		var nv: Vector3 = tan_v.cross(up_v).normalized()
		var outward := Vector3((pts[i] as Vector3).x, 0, 0)
		if outward.length() < 0.01:
			outward = Vector3(0, 0, 1)
		if nv.dot(outward) < 0.0:
			nv = -nv
		return nv
	for r in range(rings.size() - 1):
		if absf(float(bands[r][0]) - float(bands[r + 1][0])) < 0.001:
			continue
		var col: Color = cols[r + 1]
		for sd in range(2):
			for i in range(n):
				var a: Vector3 = rings[r][sd][i]
				var b2: Vector3 = rings[r][sd][i + 1]
				var c: Vector3 = rings[r + 1][sd][i + 1]
				var d: Vector3 = rings[r + 1][sd][i]
				if (b2 - a).length() < 1e-4 and (c - d).length() < 1e-4:
					continue
				var fn: Vector3 = (b2 - a).cross(d - a).normalized()
				var outward := Vector3((a + b2).x, 0, 0)
				if fn.dot(outward) < 0.0:
					fn = -fn
				var na: Vector3 = nrm_of.call(r, sd, i)
				var nb: Vector3 = nrm_of.call(r, sd, i + 1)
				var nc: Vector3 = nrm_of.call(r + 1, sd, i + 1)
				var nd: Vector3 = nrm_of.call(r + 1, sd, i)
				pk.tri(kit, "hull", a, b2, c, na, nb, nc, col, fn)
				pk.tri(kit, "hull", a, c, d, na, nc, nd, col, fn)
		# The transom: flat, across the two sides' stern points.
		var s0: Vector3 = rings[r][0][0]
		var p0: Vector3 = rings[r][1][0]
		var s1: Vector3 = rings[r + 1][0][0]
		var p1: Vector3 = rings[r + 1][1][0]
		if absf(s0.x - p0.x) > 0.01:
			var tn := Vector3(0, 0, -1)
			pk.tri(kit, "hull", s0, p0, p1, tn, tn, tn, col, tn)
			pk.tri(kit, "hull", s0, p1, s1, tn, tn, tn, col, tn)
	# The bulwark's inside and its cap where the sheer stands above the deck.
	var top: Array = rings[rings.size() - 1]
	for sd in range(2):
		for i in range(n):
			var a2: Vector3 = top[sd][i]
			var b3: Vector3 = top[sd][i + 1]
			if (a2.y <= dy + 0.05 and b3.y <= dy + 0.05) or (b3 - a2).length() < 1e-4:
				continue
			var inn := Vector3(-signf(a2.x + b3.x), 0, 0)
			pk.quad(kit, "hull", [Vector3(a2.x, dy, a2.z), Vector3(b3.x, dy, b3.z), b3, a2], inn, (cols[cols.size() - 1] as Color).darkened(0.12))
			var ina: Vector3 = a2 + inn * 0.12
			var inb: Vector3 = b3 + inn * 0.12
			pk.quad(kit, "hull", [a2 + Vector3(0, 0.06, 0), b3 + Vector3(0, 0.06, 0), inb + Vector3(0, 0.06, 0), ina + Vector3(0, 0.06, 0)], Vector3.UP, cap)
	if top[0][0].y > dy + 0.05:
		var ts: Vector3 = top[0][0]
		var tp: Vector3 = top[1][0]
		pk.quad(kit, "hull", [Vector3(ts.x, dy, ts.z), Vector3(tp.x, dy, tp.z), tp, ts], Vector3(0, 0, 1), (cols[cols.size() - 1] as Color).darkened(0.12))
	var outline := PackedVector2Array()
	for p in top[0]:
		outline.append(Vector2((p as Vector3).x, (p as Vector3).z))
	for i in range(n, -1, -1):
		outline.append(Vector2((top[1][i] as Vector3).x, (top[1][i] as Vector3).z))
	return outline


## A rubbing strake (or a toe rail) along the hull's side at `y` over the water following the sheer as `hull` laid it
## out: a half-round beam a little proud of the side from t0 to t1.
static func strake(pk: PropKit, kit: Dictionary, key: String, length: float, half: float, half_wl: float, fb: float, y: float,
		bow_run: float, bow_wl: float, stern_run: float, transom: float, size: Vector2, col: Color, t0 := 0.02, t1 := 0.96,
		sheer_bow := 0.0, sheer_stern := 0.0, n := 30) -> void:
	for side in [1.0, -1.0]:
		var prev := Vector3.ZERO
		for i in range(n + 1):
			var t: float = lerpf(t0, t1, float(i) / float(n))
			var p: Vector3 = side_at(t, y, length, half, half_wl, fb, bow_run, bow_wl, stern_run, transom)
			p.y += sheer_bow * pow(smoothstep(0.35, 1.0, t), 2.0) + sheer_stern * pow(smoothstep(0.55, 0.0, t), 2.0)
			p.x = (p.x + size.x * 0.3) * side
			if i > 0:
				pk.beam(kit, key, prev, p, size.x, size.y, col, Vector3(side, 0, 0))
			prev = p


## A point on the hull's starboard side at t (0 stern .. 1 bow) and height y, as `hull` lays it out with the same shape.
static func side_at(t: float, y: float, length: float, half: float, half_wl: float, fb: float, bow_run: float, bow_wl: float,
		stern_run: float, transom: float) -> Vector3:
	var hl := length * 0.5
	var f: float = pow(clampf((y + 1.2) / (fb + 1.2), 0.0, 1.0), 1.6)
	var hb_top: float = _hb(t, half, bow_run, stern_run, transom)
	var hb_wl: float = _hb(t, half_wl, bow_wl, stern_run * 1.4, transom * 0.85, 1.3)
	return Vector3(lerpf(hb_wl, hb_top, f), y, lerpf(-hl + t * length * 0.97, -hl + t * length, f))


## Fills a deck outline at height y (triangulated), facing up.
static func deck(pk: PropKit, kit: Dictionary, key: String, outline: PackedVector2Array, y: float, col: Color) -> void:
	var clean := PackedVector2Array()
	for p in outline:
		if clean.is_empty() or clean[clean.size() - 1].distance_to(p) > 0.02:
			clean.append(p)
	if clean.size() > 2 and clean[0].distance_to(clean[clean.size() - 1]) < 0.02:
		clean.remove_at(clean.size() - 1)
	var idx := Geometry2D.triangulate_polygon(clean)
	for i in range(0, idx.size(), 3):
		var a := Vector3(clean[idx[i]].x, y, clean[idx[i]].y)
		var b := Vector3(clean[idx[i + 1]].x, y, clean[idx[i + 1]].y)
		var c := Vector3(clean[idx[i + 2]].x, y, clean[idx[i + 2]].y)
		pk.tri(kit, key, a, b, c, Vector3.UP, Vector3.UP, Vector3.UP, col, Vector3.UP)


## A row of windows along a wall facing `out` at height y: dark glass panes 1cm proud.
static func window_row(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, out: Vector3, w: float, h: float, gap: float) -> void:
	var length: float = a.distance_to(b)
	var dir: Vector3 = (b - a) / maxf(length, 0.001)
	var n: int = int(floor((length + gap) / (w + gap)))
	if n < 1:
		return
	var start: float = (length - (float(n) * w + float(n - 1) * gap)) * 0.5
	var bs := Basis(dir, Vector3.UP, out)
	for i in range(n):
		var c: Vector3 = a + dir * (start + w * 0.5 + float(i) * (w + gap)) + out * 0.02
		pk.box(kit, "glass", Transform3D(bs, c), Vector3(w, h, 0.03), Color(0.08, 0.11, 0.14, 0.95))


# ======================================================================================
#  The feeder ship
# ======================================================================================

const SHIP_L := 118.0
const SHIP_HALF := 8.8
const SHIP_FB := 3.6
const SHIP_HULL := Color(0.10, 0.17, 0.32)
const SHIP_RED := Color(0.56, 0.14, 0.11)
const SHIP_WHITE := Color(0.93, 0.93, 0.90)

## A feeder container ship at life size: a bluff hull with a raked stem and a forecastle, hatch covers in six bays
## carrying boxes three high (`rng` picks them), the accommodation block and bridge aft with its wings, a mast with
## radars, the funnel in the line's colours, a free-fall lifeboat on the stern, mooring winches fore and aft.
## `labels` gets the name on the bows and the stern. Returns the fairleads (bow and stern) for the mooring lines.
static func container_ship(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, labels: Array, ship_name: String) -> Array:
	var L := SHIP_L
	var hl := L * 0.5
	var fb := SHIP_FB
	var outline := hull(pk, kit, L, SHIP_HALF, SHIP_HALF * 0.97, fb, _bands(fb, SHIP_RED, SHIP_HULL, SHIP_WHITE, 0.6), 0.2, 0.26, 0.07, 0.78, 2.4, 0.84)
	deck(pk, kit, "steel", outline, fb - 0.02, Color(0.36, 0.20, 0.16))
	# The forecastle deck.
	var fc_z: float = -hl + L * 0.93
	var fc_out := PackedVector2Array()
	for p in outline:
		if p.y > fc_z:
			fc_out.append(p)
	if fc_out.size() > 2:
		fc_out.insert(0, Vector2(_hb((fc_z + hl) / L, SHIP_HALF, 0.2, 0.07, 0.78), fc_z))
		fc_out.append(Vector2(-_hb((fc_z + hl) / L, SHIP_HALF, 0.2, 0.07, 0.78), fc_z))
		deck(pk, kit, "steel", fc_out, fb + 2.38, Color(0.36, 0.20, 0.16))
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(0, fb + 1.2, fc_z)), Vector3(SHIP_HALF * 1.6, 2.4, 0.2), SHIP_WHITE)
	# Hatch covers and the boxes on them: six bays of 40ft, seven across, one to three high.
	var bay_len := 13.2
	var z0: float = -hl + 24.0
	for bay in range(6):
		var bz: float = z0 + bay_len * (float(bay) + 0.5)
		if bz > hl - 16.0:
			break
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(0, fb + 0.75, bz)), Vector3(SHIP_HALF * 2.0 - 2.6, 1.5, bay_len - 0.8), Color(0.24, 0.30, 0.26))
		for col in range(7):
			var x: float = (float(col) - 3.0) * 2.5
			var tiers: int = rng.randi_range(1, 3) if bay > 0 else rng.randi_range(1, 2)
			if bay == 5:
				tiers = mini(tiers, 2)
			for tier in range(tiers):
				var paint: Color = BOX_PAINTS[rng.randi() % BOX_PAINTS.size()]
				container(pk, kit, Vector3(x, fb + 1.5 + float(tier) * BOX_40.y, bz), PI * 0.5, BOX_40, paint, rng.randf(), true)
		# A lashing bridge between bays.
		if bay > 0:
			var lz: float = bz - bay_len * 0.5
			for sx in [-1.0, 1.0]:
				pk.beam(kit, "steel", Vector3(sx * (SHIP_HALF - 1.2), fb, lz), Vector3(sx * (SHIP_HALF - 1.2), fb + 3.0, lz), 0.25, 0.25, Color(0.85, 0.7, 0.15))
			pk.beam(kit, "steel", Vector3(-(SHIP_HALF - 1.2), fb + 3.0, lz), Vector3(SHIP_HALF - 1.2, fb + 3.0, lz), 0.4, 0.15, Color(0.85, 0.7, 0.15), Vector3.UP)
	# The accommodation block aft: five decks, then the wheelhouse with its wings across the full beam.
	var az0: float = -hl + 7.0
	var az1: float = -hl + 20.5
	var hw: float = SHIP_HALF - 1.4
	var deck_h := 2.8
	for lv in range(5):
		var y0: float = fb + float(lv) * deck_h
		var inset: float = 0.0 if lv < 3 else 0.6
		blk(pk, kit, "steel", Vector3(-hw + inset, y0, az0 + inset), Vector3(hw - inset, y0 + deck_h, az1 - inset), SHIP_WHITE)
		for sx in [-1.0, 1.0]:
			window_row(pk, kit, Vector3(sx * (hw - inset), y0 + 1.5, az0 + 1.0), Vector3(sx * (hw - inset), y0 + 1.5, az1 - 1.0), Vector3(sx, 0, 0), 0.9, 0.9, 1.4)
		window_row(pk, kit, Vector3(-hw + inset + 1.0, y0 + 1.5, az1 - inset), Vector3(hw - inset - 1.0, y0 + 1.5, az1 - inset), Vector3.BACK, 0.9, 0.9, 1.2)
		# A deck edge rail band.
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(0, y0 + deck_h, (az0 + az1) * 0.5)), Vector3((hw - inset) * 2.0 + 0.3, 0.12, az1 - az0 - inset * 2.0 + 0.3), SHIP_WHITE.darkened(0.08))
	var wy: float = fb + 5.0 * deck_h
	blk(pk, kit, "steel", Vector3(-SHIP_HALF - 0.6, wy, az1 - 6.0), Vector3(SHIP_HALF + 0.6, wy + 3.0, az1 - 0.6), SHIP_WHITE)
	window_row(pk, kit, Vector3(-SHIP_HALF, wy + 1.75, az1 - 0.6), Vector3(SHIP_HALF, wy + 1.75, az1 - 0.6), Vector3.BACK, 1.6, 1.4, 0.18)
	for sx2 in [-1.0, 1.0]:
		window_row(pk, kit, Vector3(sx2 * (SHIP_HALF + 0.6), wy + 1.75, az1 - 5.4), Vector3(sx2 * (SHIP_HALF + 0.6), wy + 1.75, az1 - 1.2), Vector3(sx2, 0, 0), 1.2, 1.4, 0.3)
	blk(pk, kit, "steel", Vector3(-SHIP_HALF - 0.8, wy + 3.0, az1 - 6.3), Vector3(SHIP_HALF + 0.8, wy + 3.25, az1 - 0.3), SHIP_WHITE.darkened(0.1))
	# The mast over the wheelhouse: a tripod, yards, two radar scanners, lights.
	var mz: float = az1 - 3.5
	var my: float = wy + 3.25
	pk.tube(kit, "steel", Vector3(0, my, mz), Vector3(0, my + 7.0, mz), 0.22, 0.14, 8, SHIP_WHITE)
	pk.beam(kit, "steel", Vector3(-3.0, my + 4.0, mz), Vector3(3.0, my + 4.0, mz), 0.18, 0.18, SHIP_WHITE)
	for sx3 in [-1.0, 1.0]:
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(sx3 * 2.2, my + 4.35, mz)), Vector3(0.4, 0.5, 0.4), Color(0.2, 0.2, 0.2))
		pk.box(kit, "steel", Transform3D(Basis(Vector3.UP, 0.4 * sx3), Vector3(sx3 * 2.2, my + 4.75, mz)), Vector3(4.2, 0.18, 0.35), Color(0.92, 0.92, 0.9))
	# The funnel behind the block: the line's blue with a white band and a gold star.
	var fz: float = az0 - 2.2
	blk(pk, kit, "steel", Vector3(-2.4, fb, fz - 2.6), Vector3(2.4, fb + 15.5, fz + 2.6), Color(0.15, 0.30, 0.55))
	blk(pk, kit, "steel", Vector3(-2.45, fb + 11.0, fz - 2.65), Vector3(2.45, fb + 12.6, fz + 2.65), SHIP_WHITE)
	blk(pk, kit, "steel", Vector3(-2.45, fb + 15.0, fz - 2.65), Vector3(2.45, fb + 15.6, fz + 2.65), Color(0.08, 0.08, 0.08))
	for sx4 in [-1.0, 1.0]:
		pk.tube(kit, "steel", Vector3(sx4 * 0.9, fb + 15.0, fz), Vector3(sx4 * 0.9, fb + 17.0, fz), 0.45, 0.45, 8, Color(0.12, 0.12, 0.12))
		var star_c := Vector3(sx4 * 2.46, fb + 8.0, fz)
		var sb := Basis(Vector3.BACK * sx4, Vector3.UP, Vector3.RIGHT * sx4)
		for k in range(5):
			var a0: float = TAU * float(k) / 5.0 + PI * 0.5
			pk.tri(kit, "steel", star_c, star_c + sb * Vector3(cos(a0), sin(a0), 0) * 1.3, star_c + sb * Vector3(cos(a0 + TAU / 10.0), sin(a0 + TAU / 10.0), 0) * 0.55,
					Vector3.RIGHT * sx4, Vector3.RIGHT * sx4, Vector3.RIGHT * sx4, Color(0.95, 0.75, 0.2), Vector3.RIGHT * sx4)
			pk.tri(kit, "steel", star_c, star_c + sb * Vector3(cos(a0 - TAU / 10.0), sin(a0 - TAU / 10.0), 0) * 0.55, star_c + sb * Vector3(cos(a0), sin(a0), 0) * 1.3,
					Vector3.RIGHT * sx4, Vector3.RIGHT * sx4, Vector3.RIGHT * sx4, Color(0.95, 0.75, 0.2), Vector3.RIGHT * sx4)
	# The free-fall lifeboat on its ramp over the transom.
	var lb := Basis(Vector3.RIGHT, deg_to_rad(-30.0))
	pk.box(kit, "steel", Transform3D(lb, Vector3(0, fb + 3.2, -hl + 3.2)), Vector3(1.0, 0.3, 8.0), Color(0.3, 0.3, 0.3))
	pk.box(kit, "plastic", Transform3D(lb, Vector3(0, fb + 4.3, -hl + 3.2)), Vector3(2.8, 2.4, 7.4), Color(0.96, 0.45, 0.08))
	# Mooring winches and bitts fore and aft.
	for wz in [-hl + 2.5, hl - 6.0]:
		var wyy: float = fb if wz < 0.0 else fb + 2.4
		for sx5 in [-1.0, 1.0]:
			pk.tube(kit, "steel", Vector3(sx5 * 3.0 - 0.8, wyy + 0.8, wz), Vector3(sx5 * 3.0 + 0.8, wyy + 0.8, wz), 0.6, 0.6, 10, Color(0.28, 0.42, 0.3))
			bollard(pk, kit, Vector3(sx5 * (SHIP_HALF - 1.5), wyy, wz + 2.0), Color(0.2, 0.2, 0.2))
	# The name on both sides of the bow, on the flat topside just aft of where the hull starts to draw in (a flat label
	# on the curving bow sank into it at one end and stood off it at the other), and across the transom.
	var name_t := 0.775
	var name_y: float = fb - 1.35
	for sx6 in [-1.0, 1.0]:
		var at: Vector3 = side_at(name_t, name_y, L, SHIP_HALF, SHIP_HALF * 0.97, fb, 0.2, 0.26, 0.07, 0.78)
		labels.append([ship_name, Vector3(sx6 * (at.x + 0.12), name_y, at.z), Vector3(sx6, 0, 0), 1.2, SHIP_WHITE, 14.0])
	labels.append([ship_name, Vector3(0, fb - 1.0, -hl - 0.02), Vector3(0, 0, -1), 0.9, SHIP_WHITE, 12.0])
	labels.append(["BLOOMBAY", Vector3(0, fb - 2.4, -hl - 0.02), Vector3(0, 0, -1), 0.6, SHIP_WHITE, 8.0])
	return [Vector3(SHIP_HALF - 1.0, fb + 2.4, hl - 4.0), Vector3(SHIP_HALF - 1.0, fb, -hl + 2.0), Vector3(SHIP_HALF - 1.0, fb, 0.2 * L), Vector3(SHIP_HALF - 1.0, fb, -0.25 * L)]


# ======================================================================================
#  Small craft
# ======================================================================================

# --- shared fittings ---

## A right-handed basis whose y is `axis` (a ring or a lathe turned to face along it).
static func axis_basis(axis: Vector3) -> Basis:
	var y := axis.normalized()
	var ref := Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	return Basis(x, y, x.cross(y))

const STAINLESS := Color(0.82, 0.83, 0.85)
const TEAK := Color(0.58, 0.44, 0.30)
const GLASS_TINT := Color(0.06, 0.09, 0.12, 0.95)

## A deckhouse whose front leans back by `rake` at the top: x0..x1 across, z_back..z_front along (front toward +z),
## y0..y1. Its sides are trapezoids, its roof overhangs by `eave` (with an underside) and the front's windows follow
## the rake. Returns nothing; `win` adds a band of windows on the front (and `side_win` per side).
static func deckhouse(pk: PropKit, kit: Dictionary, x0: float, x1: float, z_back: float, z_front: float, y0: float, y1: float,
		rake: float, col: Color, roof_col: Color, eave := 0.15, win := true, side_win := 2) -> void:
	var fb_b := Vector3(x0, y0, z_front)
	var fb_t := Vector3(x0, y1, z_front - rake)
	var ft_b := Vector3(x1, y0, z_front)
	var ft_t := Vector3(x1, y1, z_front - rake)
	var fwd_n := Vector3(0, rake, y1 - y0).normalized()
	pk.quad(kit, "steel", [fb_b, ft_b, ft_t, fb_t], fwd_n, col)
	pk.quad(kit, "steel", [Vector3(x0, y0, z_back), Vector3(x1, y0, z_back), Vector3(x1, y1, z_back), Vector3(x0, y1, z_back)], Vector3.FORWARD, col)
	for sx in [[x0, Vector3.LEFT], [x1, Vector3.RIGHT]]:
		var x: float = sx[0]
		pk.quad(kit, "steel", [Vector3(x, y0, z_back), Vector3(x, y0, z_front), Vector3(x, y1, z_front - rake), Vector3(x, y1, z_back)], sx[1], col)
	# Roof with an eave all round and its underside.
	var r0 := Vector3(x0 - eave, y1, z_back - eave)
	var r1 := Vector3(x1 + eave, y1 + 0.08, z_front - rake + eave * 2.0)
	pk.block(kit, "steel", r0, r1, roof_col)
	if win:
		# The front windows: panes in the raked face, mullions between them.
		var n: int = maxi(int((x1 - x0) / 0.75), 2)
		var pw: float = (x1 - x0 - 0.16) / float(n)
		for i in range(n):
			var cx: float = x0 + 0.08 + pw * (float(i) + 0.5)
			var lo: float = lerpf(y0, y1, 0.48)
			var hi: float = y1 - 0.14
			var zl: float = z_front - rake * ((lo - y0) / (y1 - y0)) + 0.02
			var zh: float = z_front - rake * ((hi - y0) / (y1 - y0)) + 0.02
			var hw: float = pw * 0.5 - 0.05
			pk.quad(kit, "glass", [Vector3(cx - hw, lo, zl), Vector3(cx + hw, lo, zl), Vector3(cx + hw, hi, zh), Vector3(cx - hw, hi, zh)], fwd_n, GLASS_TINT)
		for sx2 in [[x0 - 0.02, Vector3.LEFT], [x1 + 0.02, Vector3.RIGHT]]:
			var x2: float = sx2[0]
			var span: float = z_front - rake * 0.5 - z_back - 0.4
			for k in range(side_win):
				var zc: float = z_back + 0.3 + span * (float(k) + 0.5) / float(side_win)
				var wl: float = span / float(side_win) * 0.4
				pk.quad(kit, "glass", [Vector3(x2, lerpf(y0, y1, 0.48), zc - wl), Vector3(x2, lerpf(y0, y1, 0.48), zc + wl), Vector3(x2, y1 - 0.18, zc + wl), Vector3(x2, y1 - 0.18, zc - wl)], sx2[1], GLASS_TINT)


## A white yacht fender on its line, hanging from `top` down the hull's side facing `out`.
static func fender(pk: PropKit, kit: Dictionary, top: Vector3, out: Vector3, drop := 0.7, col := Color(0.92, 0.92, 0.9)) -> void:
	var c: Vector3 = top - Vector3(0, drop, 0) + out * 0.14
	pk.tube(kit, "matte", top, c + Vector3(0, 0.3, 0), 0.01, 0.01, 4, Color(0.9, 0.9, 0.85), false)
	pk.lathe(kit, "plastic", c - Vector3(0, 0.3, 0), [Vector2(0.001, 0.0), Vector2(0.08, 0.02), Vector2(0.12, 0.1), Vector2(0.12, 0.5), Vector2(0.08, 0.58), Vector2(0.001, 0.6)], 10, col)


## An old tyre hung by a rope over the side as a fender.
static func tyre_fender(pk: PropKit, kit: Dictionary, top: Vector3, out: Vector3, drop := 0.55) -> void:
	var c: Vector3 = top - Vector3(0, drop, 0) + out * 0.16
	pk.tube(kit, "matte", top, c + Vector3(0, 0.3, 0), 0.02, 0.02, 4, Color(0.7, 0.62, 0.42), false)
	pk.tyre(kit, "rubber", c, 0.17, 0.36, 0.2, 14, Color(0.05, 0.05, 0.05), axis_basis(out))


## A guard rail along points: stanchions every `every` metres and two wires (or tubes when `tube`).
static func lifelines(pk: PropKit, kit: Dictionary, pts: Array, h := 0.62, every := 2.1, tube := false) -> void:
	var t0: float = 0.022 if tube else 0.01
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		pk.tube(kit, "steel", p, p + Vector3(0, h, 0), 0.016, 0.014, 5, STAINLESS, false)
		if i > 0:
			var q: Vector3 = pts[i - 1]
			pk.tube(kit, "steel", q + Vector3(0, h, 0), p + Vector3(0, h, 0), t0 * 1.6, t0 * 1.6, 4, STAINLESS, false)
			pk.tube(kit, "steel", q + Vector3(0, h * 0.5, 0), p + Vector3(0, h * 0.5, 0), t0, t0, 4, STAINLESS, false)


## Points along the deck's edge on one side (`side` +1 starboard), `inset` in from the sheer, from t0 to t1, at the sheer's height.
static func edge_points(length: float, half: float, half_wl: float, fb: float, side: float, inset: float, t0: float, t1: float, count: int,
		bow_run: float, bow_wl: float, stern_run: float, transom: float, sheer_bow := 0.0, sheer_stern := 0.0) -> Array:
	var out: Array = []
	for i in range(count):
		var t: float = lerpf(t0, t1, float(i) / float(maxi(count - 1, 1)))
		var p: Vector3 = side_at(t, fb, length, half, half_wl, fb, bow_run, bow_wl, stern_run, transom)
		p.y += sheer_bow * pow(smoothstep(0.35, 1.0, t), 2.0) + sheer_stern * pow(smoothstep(0.55, 0.0, t), 2.0)
		out.append(Vector3((p.x - inset) * side, p.y, p.z))
	return out


## A navigation light: a small housing with a lens of `col`.
static func nav_light(pk: PropKit, kit: Dictionary, p: Vector3, col: Color) -> void:
	pk.box(kit, "steel", Transform3D(Basis(), p), Vector3(0.16, 0.2, 0.16), Color(0.15, 0.15, 0.15))
	pk.box(kit, "lamp", Transform3D(Basis(), p + Vector3(0, 0.02, 0)), Vector3(0.12, 0.12, 0.17), col)


## A radar scanner: a pedestal and a long slotted array.
static func radar(pk: PropKit, kit: Dictionary, p: Vector3, length := 1.6, yaw := 0.3) -> void:
	pk.box(kit, "steel", Transform3D(Basis(), p + Vector3(0, 0.15, 0)), Vector3(0.28, 0.3, 0.28), Color(0.9, 0.9, 0.88))
	pk.box(kit, "steel", Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.38, 0)), Vector3(length, 0.14, 0.2), Color(0.92, 0.92, 0.9))


## A life raft canister in its cradle (a white drum with bands).
static func liferaft(pk: PropKit, kit: Dictionary, p: Vector3, axis: Vector3) -> void:
	pk.tube(kit, "plastic", p - axis * 0.5, p + axis * 0.5, 0.3, 0.3, 12, Color(0.94, 0.94, 0.92), true)
	for k in [-0.3, 0.3]:
		pk.tube(kit, "steel", p + axis * (k - 0.025), p + axis * (k + 0.025), 0.315, 0.315, 12, Color(0.2, 0.2, 0.2), false)
	pk.box(kit, "steel", Transform3D(Basis(), p - Vector3(0, 0.28, 0)), Vector3(0.7, 0.08, 0.7) + axis.abs() * 0.4, Color(0.3, 0.3, 0.3))


# --- the trawler ---

const TRAWLER := {"L": 15.5, "half": 2.45, "wl": 2.25, "fb": 1.55, "bow": 0.34, "bow_wl": 0.42, "stern": 0.1, "transom": 0.6, "sb": 0.85, "ss": 0.25}

## A wooden-built stern trawler, about 15m: a sheered hull with a white bulwark band and a rubbing strake, a deck 0.9m
## under the bulwark, the wheelhouse forward with raked windows, a mast and derrick on its foredeck, a hatch and
## winches amidships, and over the stern a gantry with the net drum, its net and the otter boards; fish boxes, life
## raft, lifebuoys, tyres on ropes. `paint` the hull, `cabin` the wheelhouse.
static func fishing_boat(pk: PropKit, kit: Dictionary, paint: Color, cabin: Color) -> void:
	var T := TRAWLER
	var L: float = T["L"]
	var hl := L * 0.5
	var fb: float = T["fb"]
	var deck_y: float = fb - 0.75
	var outline := hull(pk, kit, L, T["half"], T["wl"], fb, _bands(fb, Color(0.20, 0.20, 0.21), paint, SHIP_WHITE, 0.2),
			T["bow"], T["bow_wl"], T["stern"], T["transom"], 0.0, 0.8, 36, T["sb"], T["ss"], deck_y, Color(0.32, 0.24, 0.17))
	deck(pk, kit, "wood", outline, deck_y, Color(0.50, 0.40, 0.29))
	strake(pk, kit, "wood", L, T["half"], T["wl"], fb, fb - 0.62, T["bow"], T["bow_wl"], T["stern"], T["transom"], Vector2(0.12, 0.1), Color(0.24, 0.18, 0.13), 0.02, 0.96, T["sb"], T["ss"])
	strake(pk, kit, "wood", L, T["half"], T["wl"], fb, 0.55, T["bow"], T["bow_wl"], T["stern"], T["transom"], Vector2(0.1, 0.08), paint.darkened(0.35), 0.04, 0.92, T["sb"] * 0.3, T["ss"] * 0.3)
	# The wheelhouse, set forward: a low deckhouse and the house on it, raked windows, a rail round its roof.
	var wx := 1.45
	deckhouse(pk, kit, -wx - 0.15, wx + 0.15, -0.6, 3.6, deck_y, deck_y + 1.1, 0.0, cabin.darkened(0.08), cabin.darkened(0.25), 0.05, false)
	deckhouse(pk, kit, -wx, wx, 0.6, 3.3, deck_y + 1.1, deck_y + 2.85, 0.45, cabin, Color(0.26, 0.28, 0.3), 0.18, true, 2)
	var roof_y: float = deck_y + 2.93
	var rr: Array = [Vector3(-wx + 0.1, roof_y, 0.7), Vector3(-wx + 0.1, roof_y, 2.8), Vector3(wx - 0.1, roof_y, 2.8), Vector3(wx - 0.1, roof_y, 0.7)]
	lifelines(pk, kit, rr, 0.5, 2.0, true)
	radar(pk, kit, Vector3(0, roof_y, 1.5), 1.4, 0.6)
	liferaft(pk, kit, Vector3(-0.7, roof_y + 0.36, 2.2), Vector3.BACK)
	pk.lathe(kit, "steel", Vector3(0.8, roof_y, 2.4), [Vector2(0.001, 0.0), Vector2(0.06, 0.0), Vector2(0.05, 0.4), Vector2(0.16, 0.45), Vector2(0.18, 0.6), Vector2(0.001, 0.62)], 8, Color(0.85, 0.85, 0.82))
	for ax in [-1.2, -0.9]:
		pk.tube(kit, "steel", Vector3(ax, roof_y, 1.0), Vector3(ax, roof_y + 2.4, 1.0), 0.02, 0.012, 4, Color(0.9, 0.9, 0.9), false)
	for sx in [-1.0, 1.0]:
		var ring_c := Vector3(sx * (wx + 0.04), deck_y + 1.7, 0.9)
		pk.tyre(kit, "plastic", ring_c, 0.2, 0.3, 0.08, 12, Color(0.92, 0.3, 0.12), axis_basis(Vector3(sx, 0, 0)))
		nav_light(pk, kit, Vector3(sx * (wx + 0.12), deck_y + 2.5, 3.0), Color(0.2, 1.0, 0.3) if sx > 0 else Color(1.0, 0.2, 0.15))
	# The foremast with a crosstree, lights and a derrick boom to the hatch.
	var mz := 4.6
	pk.tube(kit, "steel", Vector3(0, deck_y, mz), Vector3(0, deck_y + 7.2, mz), 0.1, 0.06, 8, SHIP_WHITE)
	pk.tube(kit, "steel", Vector3(-0.9, deck_y + 5.6, mz), Vector3(0.9, deck_y + 5.6, mz), 0.04, 0.04, 6, SHIP_WHITE)
	nav_light(pk, kit, Vector3(0, deck_y + 7.25, mz), Color(1, 0.96, 0.85))
	nav_light(pk, kit, Vector3(0, deck_y + 5.9, mz + 0.1), Color(1, 0.96, 0.85))
	pk.tube(kit, "steel", Vector3(0, deck_y + 1.2, mz - 0.1), Vector3(0, deck_y + 3.4, -1.6), 0.07, 0.05, 6, SHIP_WHITE)
	pk.tube(kit, "steel", Vector3(0, deck_y + 6.6, mz), Vector3(0, deck_y + 3.4, -1.6), 0.012, 0.012, 3, Color(0.3, 0.3, 0.3), false)
	pk.tube(kit, "steel", Vector3(0, deck_y + 3.35, -1.6), Vector3(0, deck_y + 1.4, -1.6), 0.01, 0.01, 3, Color(0.3, 0.3, 0.3), false)
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(0, deck_y + 1.35, -1.6)), Vector3(0.12, 0.2, 0.08), Color(0.85, 0.6, 0.1))
	# The fish hold's hatch and the trawl winches.
	pk.block(kit, "wood", Vector3(-0.8, deck_y, -2.6), Vector3(0.8, deck_y + 0.35, -1.0), Color(0.42, 0.33, 0.24))
	pk.block(kit, "steel", Vector3(-0.85, deck_y + 0.35, -2.65), Vector3(0.85, deck_y + 0.42, -0.95), Color(0.30, 0.42, 0.34))
	for sx in [-1.0, 1.0]:
		var wc := Vector3(sx * 1.0, deck_y + 0.45, 0.0)
		pk.box(kit, "steel", Transform3D(Basis(), wc - Vector3(0, 0.22, 0)), Vector3(0.7, 0.45, 0.8), Color(0.22, 0.36, 0.30))
		pk.tube(kit, "steel", wc + Vector3(-0.3, 0.2, 0), wc + Vector3(0.3, 0.2, 0), 0.28, 0.28, 12, Color(0.18, 0.2, 0.2))
		for e in [-0.32, 0.32]:
			pk.tube(kit, "steel", wc + Vector3(e - 0.02, 0.2, 0), wc + Vector3(e + 0.02, 0.2, 0), 0.36, 0.36, 12, Color(0.22, 0.36, 0.30))
	# The stern gantry: two tapered legs, a beam with blocks, the otter boards hanging at its feet.
	var gz: float = -hl + 0.9
	var gcol := Color(0.92, 0.62, 0.12)
	for sx in [-1.0, 1.0]:
		var foot := Vector3(sx * 1.75, deck_y, gz + 0.3)
		var head := Vector3(sx * 1.5, deck_y + 3.5, gz - 0.2)
		pk.tube(kit, "steel", foot, head, 0.11, 0.07, 8, gcol)
		pk.tube(kit, "steel", foot + Vector3(0, 0, 1.4), head + Vector3(0, -0.4, 0.1), 0.06, 0.05, 6, gcol)
		pk.box(kit, "steel", Transform3D(Basis(), head + Vector3(0, -0.35, -0.1)), Vector3(0.18, 0.3, 0.18), Color(0.25, 0.25, 0.25))
		# An otter board: a heavy steel door, rust brown, hung on the gantry's side.
		var ob := Basis(Vector3.BACK, Vector3.UP, Vector3(sx, 0, 0)).rotated(Vector3.UP, 0.05 * sx)
		pk.box(kit, "steel", Transform3D(ob, Vector3(sx * 2.0, deck_y + 0.9, gz + 0.9)), Vector3(1.4, 0.9, 0.08), Color(0.36, 0.2, 0.12))
		pk.box(kit, "steel", Transform3D(ob, Vector3(sx * 2.04, deck_y + 0.9, gz + 0.9)), Vector3(1.2, 0.08, 0.06), Color(0.2, 0.2, 0.2))
	pk.tube(kit, "steel", Vector3(-1.6, deck_y + 3.5, gz - 0.2), Vector3(1.6, deck_y + 3.5, gz - 0.2), 0.12, 0.12, 8, gcol)
	# The net drum on its stand, wound with green net and orange floats.
	var dz: float = gz + 1.9
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", Vector3(sx * 1.05, deck_y, dz), Vector3(sx * 1.05, deck_y + 1.0, dz), 0.12, 0.12, gcol)
		pk.tube(kit, "steel", Vector3(sx * 0.98, deck_y + 0.95, dz), Vector3(sx * 0.92, deck_y + 0.95, dz), 0.62, 0.62, 16, Color(0.25, 0.3, 0.32))
	pk.tube(kit, "canvas", Vector3(-0.92, deck_y + 0.95, dz), Vector3(0.92, deck_y + 0.95, dz), 0.48, 0.48, 16, Color(0.20, 0.38, 0.28), false)
	for k in range(7):
		var a: float = TAU * float(k) / 7.0
		pk.lathe(kit, "plastic", Vector3(-0.7 + 0.23 * float(k), deck_y + 0.95 + sin(a) * 0.5, dz + cos(a) * 0.5), [Vector2(0.001, -0.07), Vector2(0.07, 0.0), Vector2(0.001, 0.07)], 6, Color(0.95, 0.45, 0.1))
	# Fish boxes stacked by the hatch.
	for k2 in range(6):
		var bx: float = -1.4 + 0.62 * float(k2 % 2)
		var by: float = deck_y + 0.17 + 0.33 * float(k2 / 2)
		var bcol: Color = [Color(0.18, 0.36, 0.72), Color(0.92, 0.42, 0.10), Color(0.18, 0.36, 0.72)][k2 % 3]
		pk.box(kit, "plastic", Transform3D(Basis(Vector3.UP, 0.04 * float(k2 % 3)), Vector3(bx + 0.2, by, -3.4)), Vector3(0.58, 0.3, 0.42), bcol)
		pk.box(kit, "plastic", Transform3D(Basis(), Vector3(bx + 0.2, by + 0.13, -3.4)), Vector3(0.5, 0.05, 0.34), bcol.darkened(0.4))
	# Tyres on ropes along the sides.
	for k3 in range(5):
		var t: float = 0.2 + 0.15 * float(k3)
		for sx in [-1.0, 1.0]:
			var p: Vector3 = side_at(t, fb, L, T["half"], T["wl"], fb, T["bow"], T["bow_wl"], T["stern"], T["transom"])
			p.y += T["sb"] * pow(smoothstep(0.35, 1.0, t), 2.0) + T["ss"] * pow(smoothstep(0.55, 0.0, t), 2.0)
			tyre_fender(pk, kit, Vector3(sx * p.x, p.y, p.z), Vector3(sx, 0, 0), 0.75)


# --- the yacht ---

const YACHT := {"L": 11.5, "half": 1.9, "wl": 1.45, "fb": 1.15, "bow": 0.45, "bow_wl": 0.55, "stern": 0.05, "transom": 0.82, "sb": 0.32, "ss": 0.08}

## A cruising yacht, about 11.5m: a white hull with a coloured sheer stripe and a boot top, a teak-trimmed deck, a cabin
## trunk with sloping sides and long tinted windows, a cockpit with coamings, a wheel and winches, a swim platform; the
## mast with two sets of spreaders, shrouds and stays, the boom with its lazy bag, the genoa furled on the forestay; bow
## pulpit, pushpit and lifelines; fenders out.
static func sailboat(pk: PropKit, kit: Dictionary, stripe: Color) -> void:
	var Y := YACHT
	var L: float = Y["L"]
	var hl := L * 0.5
	var fb: float = Y["fb"]
	var outline := hull(pk, kit, L, Y["half"], Y["wl"], fb, _bands(fb, Color(0.12, 0.14, 0.2), SHIP_WHITE, stripe, 0.12),
			Y["bow"], Y["bow_wl"], Y["stern"], Y["transom"], 0.0, 0.8, 32, Y["sb"], Y["ss"], fb - 0.02, SHIP_WHITE)
	deck(pk, kit, "plastic", outline, fb - 0.02, Color(0.90, 0.89, 0.85))
	strake(pk, kit, "wood", L, Y["half"], Y["wl"], fb, fb + 0.03, Y["bow"], Y["bow_wl"], Y["stern"], Y["transom"], Vector2(0.05, 0.06), TEAK, 0.03, 0.93, Y["sb"], Y["ss"])
	# The cabin trunk: sides leaning in, a sloped front, windows along each side, a hatch and handrails on the roof.
	var cz0 := -1.4
	var cz1 := 2.6
	var cy0: float = fb - 0.02
	var cy1: float = fb + 0.62
	var bw := 1.2
	var tw := 1.0
	var c_col := Color(0.95, 0.95, 0.93)
	var p := [Vector3(-bw, cy0, cz0), Vector3(bw, cy0, cz0), Vector3(bw, cy0, cz1), Vector3(-bw, cy0, cz1),
			Vector3(-tw, cy1, cz0), Vector3(tw, cy1, cz0), Vector3(tw, cy1, cz1 - 0.7), Vector3(-tw, cy1, cz1 - 0.7)]
	pk.quad(kit, "plastic", [p[0], p[1], p[5], p[4]], Vector3.FORWARD, c_col)
	pk.quad(kit, "plastic", [p[3], p[2], p[6], p[7]], Vector3(0, 0.7, 0.62).normalized(), c_col)
	pk.quad(kit, "plastic", [p[1], p[2], p[6], p[5]], Vector3(0.62, 0.2, 0).normalized(), c_col)
	pk.quad(kit, "plastic", [p[3], p[0], p[4], p[7]], Vector3(-0.62, 0.2, 0).normalized(), c_col)
	pk.quad(kit, "plastic", [p[4], p[5], p[6], p[7]], Vector3.UP, Color(0.90, 0.89, 0.85))
	for sx in [-1.0, 1.0]:
		var wa := Vector3(sx * lerpf(bw, tw, 0.5) + sx * 0.015, (cy0 + cy1) * 0.5 + 0.04, cz0 + 0.5)
		var wb := Vector3(sx * lerpf(bw, tw, 0.5) + sx * 0.015, (cy0 + cy1) * 0.5 + 0.04, cz1 - 1.0)
		var n_w := Vector3(sx * 0.62, 0.2, 0).normalized()
		pk.quad(kit, "glass", [wa - Vector3(0, 0.1, 0) + Vector3(sx * 0.03, 0, 0), wb - Vector3(0, 0.1, 0) + Vector3(sx * 0.03, 0, 0), wb + Vector3(0, 0.1, 0), wa + Vector3(0, 0.1, 0)], n_w, GLASS_TINT)
		pk.beam(kit, "wood", Vector3(sx * (tw - 0.15), cy1 + 0.06, cz0 + 0.3), Vector3(sx * (tw - 0.15), cy1 + 0.06, cz1 - 1.1), 0.04, 0.05, TEAK, Vector3.UP)
	pk.block(kit, "plastic", Vector3(-0.38, cy1, cz1 - 1.5), Vector3(0.38, cy1 + 0.08, cz1 - 0.85), Color(0.2, 0.22, 0.25, 0.9))
	# The cockpit: a sole under the deck, coamings, seats, the wheel on its pedestal and two winches.
	var kz0: float = -hl + 0.8
	var kz1: float = cz0
	pk.block(kit, "wood", Vector3(-0.85, fb - 0.42, kz0), Vector3(0.85, fb - 0.38, kz1), TEAK)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "plastic", Vector3(sx * 0.85 - (0.04 if sx > 0 else 0.0), fb - 0.42, kz0), Vector3(sx * 0.85 + (0.0 if sx > 0 else 0.04), fb + 0.3, kz1), SHIP_WHITE)
		pk.block(kit, "wood", Vector3(minf(sx * 0.55, sx * 0.85), fb - 0.05, kz0 + 0.2), Vector3(maxf(sx * 0.55, sx * 0.85), fb - 0.0, kz1 - 0.1), TEAK)
		pk.lathe(kit, "steel", Vector3(sx * 0.95, fb + 0.3, kz1 - 0.6), [Vector2(0.001, 0.0), Vector2(0.09, 0.0), Vector2(0.08, 0.14), Vector2(0.06, 0.18), Vector2(0.001, 0.2)], 10, STAINLESS)
	pk.block(kit, "plastic", Vector3(-0.85, fb - 0.42, kz0 - 0.02), Vector3(0.85, fb - 0.0, kz0 + 0.02), SHIP_WHITE)
	var wh := Vector3(0, fb - 0.4, kz0 + 0.9)
	pk.tube(kit, "steel", wh, wh + Vector3(0, 0.8, 0), 0.07, 0.06, 8, STAINLESS)
	var wheel_c: Vector3 = wh + Vector3(0, 1.05, 0.12)
	pk.tyre(kit, "steel", wheel_c, 0.36, 0.4, 0.04, 20, STAINLESS, axis_basis(Vector3.BACK))
	for k in range(4):
		var a: float = TAU * float(k) / 4.0
		pk.tube(kit, "steel", wheel_c, wheel_c + Vector3(cos(a), sin(a), 0) * 0.37, 0.012, 0.012, 4, STAINLESS, false)
	# The swim platform and its ladder.
	pk.block(kit, "wood", Vector3(-1.3, 0.25, -hl - 0.55), Vector3(1.3, 0.32, -hl + 0.05), TEAK)
	for k2 in range(3):
		pk.tube(kit, "steel", Vector3(-0.2, 0.32 - 0.25 * float(k2), -hl - 0.5), Vector3(0.2, 0.32 - 0.25 * float(k2), -hl - 0.5), 0.015, 0.015, 4, STAINLESS, false)
	# The rig: mast, two sets of spreaders, shrouds, stays, the boom with its lazy bag, the furled genoa.
	var mz := 1.6
	var mtop: float = fb + 14.0
	pk.tube(kit, "steel", Vector3(0, cy1, mz), Vector3(0, mtop, mz), 0.1, 0.07, 8, Color(0.84, 0.85, 0.87))
	for sp in [[fb + 5.4, 0.95], [fb + 9.8, 0.62]]:
		pk.tube(kit, "steel", Vector3(-sp[1], sp[0], mz), Vector3(sp[1], sp[0], mz), 0.025, 0.02, 5, Color(0.84, 0.85, 0.87))
	var chain := Vector3(1.65, fb + 0.05, mz - 0.1)
	for sx in [-1.0, 1.0]:
		var ch := Vector3(sx * chain.x, chain.y, chain.z)
		pk.tube(kit, "steel", ch, Vector3(sx * 0.95, fb + 5.4, mz), 0.008, 0.008, 3, Color(0.6, 0.6, 0.62), false)
		pk.tube(kit, "steel", Vector3(sx * 0.95, fb + 5.4, mz), Vector3(sx * 0.62, fb + 9.8, mz), 0.008, 0.008, 3, Color(0.6, 0.6, 0.62), false)
		pk.tube(kit, "steel", Vector3(sx * 0.62, fb + 9.8, mz), Vector3(0, mtop - 0.3, mz), 0.008, 0.008, 3, Color(0.6, 0.6, 0.62), false)
	var stem := Vector3(0, fb + Y["sb"] + 0.05, hl - 0.15)
	pk.tube(kit, "steel", Vector3(0, mtop - 0.2, mz), stem, 0.01, 0.01, 3, Color(0.6, 0.6, 0.62), false)
	pk.tube(kit, "steel", Vector3(0, mtop - 0.2, mz), Vector3(0, fb + Y["ss"] + 0.2, -hl + 0.2), 0.01, 0.01, 3, Color(0.6, 0.6, 0.62), false)
	# The genoa furled round the forestay: a spiral roll, fat low down, in its blue UV strip.
	var g0: Vector3 = stem + (Vector3(0, mtop - 0.6, mz) - stem) * 0.03
	var g1: Vector3 = stem + (Vector3(0, mtop - 0.6, mz) - stem) * 0.92
	pk.tube(kit, "canvas", g0, g1, 0.13, 0.03, 8, Color(0.92, 0.92, 0.88))
	pk.tube(kit, "canvas", g0 + Vector3(0.02, 0, 0), g0 + (g1 - g0) * 0.85 + Vector3(0.02, 0, 0), 0.115, 0.04, 8, stripe.darkened(0.2))
	# The boom and its lazy bag.
	var by: float = cy1 + 0.9
	pk.tube(kit, "steel", Vector3(0, by, mz - 0.1), Vector3(0, by - 0.1, -hl + 1.5), 0.07, 0.06, 8, Color(0.84, 0.85, 0.87))
	pk.tube(kit, "canvas", Vector3(0, by + 0.15, mz - 0.3), Vector3(0, by + 0.1, -hl + 1.8), 0.14, 0.09, 10, stripe.darkened(0.3))
	pk.tube(kit, "steel", Vector3(0, mtop - 0.2, mz), Vector3(0, by - 0.05, -hl + 1.6), 0.008, 0.008, 3, Color(0.5, 0.5, 0.5), false)
	# Pulpit, pushpit and lifelines; fenders out.
	for sx in [-1.0, 1.0]:
		var pts: Array = edge_points(L, Y["half"], Y["wl"], fb, sx, 0.1, 0.06, 0.9, 6, Y["bow"], Y["bow_wl"], Y["stern"], Y["transom"], Y["sb"], Y["ss"])
		lifelines(pk, kit, pts, 0.62)
		pk.tube(kit, "steel", pts[pts.size() - 1] + Vector3(0, 0.62, 0), stem + Vector3(0, 0.62, -0.4), 0.022, 0.022, 5, STAINLESS, false)
		pk.tube(kit, "steel", pts[0] + Vector3(0, 0.62, 0), Vector3(sx * 0.4, fb + Y["ss"] + 0.62, -hl + 0.15), 0.022, 0.022, 5, STAINLESS, false)
		for k3 in range(3):
			var e: Vector3 = pts[1 + k3]
			fender(pk, kit, e + Vector3(0, 0.62, 0), Vector3(sx, 0, 0), 1.1)
	pk.tube(kit, "steel", Vector3(-0.4, fb + Y["ss"] + 0.62, -hl + 0.15), Vector3(0.4, fb + Y["ss"] + 0.62, -hl + 0.15), 0.022, 0.022, 5, STAINLESS, false)
	nav_light(pk, kit, Vector3(0, mtop + 0.12, mz), Color(1, 0.96, 0.85))


# --- the tug ---

const TUG := {"L": 26.0, "half": 5.0, "wl": 4.6, "fb": 2.4, "bow": 0.3, "bow_wl": 0.38, "stern": 0.14, "transom": 0.55, "sb": 0.9, "ss": 0.2}

## A harbour tug, about 26m: a broad sheered hull, red over black, a heavy rubber fender all round its sheer and a big
## push fender on the bow, bulwarks; a lower deckhouse with portholes and doors, the pilot house over it with windows
## leaning out all round under a visor, its mast with radar and lights; twin rounded funnels, a fire monitor on the
## roof, the towing winch and hook aft, bitts, life rafts, rails.
static func tug(pk: PropKit, kit: Dictionary) -> void:
	var T := TUG
	var L: float = T["L"]
	var hl := L * 0.5
	var fb: float = T["fb"]
	var deck_y: float = fb - 0.9
	var red := Color(0.72, 0.15, 0.11)
	var outline := hull(pk, kit, L, T["half"], T["wl"], fb, _bands(fb, Color(0.11, 0.11, 0.12), red, red.darkened(0.15), 0.35),
			T["bow"], T["bow_wl"], T["stern"], T["transom"], 0.0, 0.8, 32, T["sb"], T["ss"], deck_y, Color(0.12, 0.12, 0.12))
	deck(pk, kit, "steel", outline, deck_y, Color(0.30, 0.31, 0.30))
	# The fender: two rubber strakes round the sheer.
	strake(pk, kit, "rubber", L, T["half"], T["wl"], fb, fb - 0.3, T["bow"], T["bow_wl"], T["stern"], T["transom"], Vector2(0.55, 0.5), Color(0.06, 0.06, 0.06), 0.0, 0.99, T["sb"], T["ss"], 40)
	strake(pk, kit, "rubber", L, T["half"], T["wl"], fb, 0.9, T["bow"], T["bow_wl"], T["stern"], T["transom"], Vector2(0.35, 0.3), Color(0.07, 0.07, 0.07), 0.1, 0.9, T["sb"] * 0.4, T["ss"] * 0.4, 30)
	var bow_y: float = fb + T["sb"]
	pk.tube(kit, "rubber", Vector3(-2.2, bow_y - 1.3, hl + 0.2), Vector3(2.2, bow_y - 1.3, hl + 0.2), 0.75, 0.75, 14, Color(0.06, 0.06, 0.06))
	pk.tube(kit, "rubber", Vector3(-1.6, bow_y - 2.4, hl - 0.4), Vector3(1.6, bow_y - 2.4, hl - 0.4), 0.6, 0.6, 14, Color(0.06, 0.06, 0.06))
	# Lower deckhouse with portholes and doors.
	var white := Color(0.95, 0.95, 0.93)
	pk.block(kit, "steel", Vector3(-3.4, deck_y, -2.4), Vector3(3.4, deck_y + 2.5, 5.2), white)
	for sx in [-1.0, 1.0]:
		for k in range(4):
			var pz: float = -1.6 + 1.8 * float(k)
			var pc := Vector3(sx * 3.41, deck_y + 1.6, pz)
			pk.tyre(kit, "steel", pc, 0.22, 0.3, 0.05, 12, Color(0.5, 0.5, 0.52), axis_basis(Vector3(sx, 0, 0)))
			pk.lathe(kit, "glass", pc, [Vector2(0.001, 0.0), Vector2(0.23, 0.0), Vector2(0.001, 0.01)], 12, GLASS_TINT, false, axis_basis(Vector3(sx, 0, 0)))
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(sx * 3.43, deck_y + 1.0, 4.2)), Vector3(0.06, 1.9, 0.8), Color(0.85, 0.85, 0.83))
	lifelines(pk, kit, [Vector3(-3.3, deck_y + 2.5, -2.3), Vector3(-3.3, deck_y + 2.5, 5.1), Vector3(3.3, deck_y + 2.5, 5.1), Vector3(3.3, deck_y + 2.5, -2.3)], 1.0, 2.4, true)
	# The pilot house: windows leaning out all round, a visor, a dark roof.
	var py0: float = deck_y + 2.5
	var py1: float = py0 + 2.7
	var hx := 2.5
	var hz0 := 0.2
	var hz1 := 4.0
	var lean := 0.3
	var corners := [Vector3(-hx, py0, hz0), Vector3(hx, py0, hz0), Vector3(hx, py0, hz1), Vector3(-hx, py0, hz1)]
	var top_c := [Vector3(-hx - lean, py1, hz0 - lean), Vector3(hx + lean, py1, hz0 - lean), Vector3(hx + lean, py1, hz1 + lean), Vector3(-hx - lean, py1, hz1 + lean)]
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var at: Vector3 = top_c[i]
		var bt: Vector3 = top_c[(i + 1) % 4]
		var mid: Vector3 = (a + b) * 0.5
		var o := Vector3(mid.x, 0, mid.z - (hz0 + hz1) * 0.5).normalized()
		var fn: Vector3 = (b - a).cross(at - a).normalized()
		if fn.dot(o) < 0.0:
			fn = -fn
		pk.quad(kit, "steel", [a, b, b.lerp(bt, 0.35), a.lerp(at, 0.35)], fn, white)
		var lo_a: Vector3 = a.lerp(at, 0.35) + fn * 0.02
		var lo_b: Vector3 = b.lerp(bt, 0.35) + fn * 0.02
		var n_p: int = 4 if i % 2 == 0 else 3
		for k in range(n_p):
			var u0: float = (float(k) + 0.06) / float(n_p)
			var u1: float = (float(k) + 0.94) / float(n_p)
			pk.quad(kit, "glass", [lo_a.lerp(lo_b, u0), lo_a.lerp(lo_b, u1), (at + fn * 0.02).lerp(bt + fn * 0.02, u1) - Vector3(0, 0.08, 0), (at + fn * 0.02).lerp(bt + fn * 0.02, u0) - Vector3(0, 0.08, 0)], fn, GLASS_TINT)
		pk.beam(kit, "steel", at + fn * 0.05, bt + fn * 0.05, 0.12, 0.12, Color(0.15, 0.15, 0.15), fn)
	pk.block(kit, "steel", Vector3(-hx - lean - 0.35, py1, hz0 - lean - 0.35), Vector3(hx + lean + 0.35, py1 + 0.18, hz1 + lean + 0.35), Color(0.16, 0.16, 0.17))
	# Mast with radar, lights and horns; the fire monitor; searchlight.
	var rt: float = py1 + 0.18
	pk.tube(kit, "steel", Vector3(0, rt, 1.4), Vector3(0, rt + 4.0, 1.4), 0.12, 0.08, 8, white)
	pk.tube(kit, "steel", Vector3(-1.2, rt + 2.6, 1.4), Vector3(1.2, rt + 2.6, 1.4), 0.05, 0.05, 6, white)
	radar(pk, kit, Vector3(0, rt + 2.66, 1.4), 2.2, 0.2)
	nav_light(pk, kit, Vector3(0, rt + 4.05, 1.4), Color(1, 0.96, 0.85))
	nav_light(pk, kit, Vector3(-1.1, rt + 2.75, 1.5), Color(1.0, 0.2, 0.15))
	nav_light(pk, kit, Vector3(1.1, rt + 2.75, 1.5), Color(0.2, 1.0, 0.3))
	pk.lathe(kit, "steel", Vector3(0, rt, 3.4), [Vector2(0.001, 0.0), Vector2(0.25, 0.0), Vector2(0.18, 0.5), Vector2(0.001, 0.5)], 8, red)
	pk.tube(kit, "steel", Vector3(0, rt + 0.6, 3.3), Vector3(0, rt + 0.9, 4.6), 0.09, 0.06, 8, red)
	pk.lathe(kit, "steel", Vector3(1.4, rt, 3.2), [Vector2(0.001, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.3), Vector2(0.18, 0.32), Vector2(0.2, 0.55), Vector2(0.001, 0.58)], 8, Color(0.85, 0.85, 0.82))
	# Twin funnels, rounded, red with black tops, aft of the house.
	for sx in [-1.0, 1.0]:
		var fc := Vector3(sx * 2.0, deck_y + 2.5, -1.6)
		pk.lathe(kit, "steel", fc, [Vector2(0.001, 0.0), Vector2(0.55, 0.0), Vector2(0.55, 2.4), Vector2(0.5, 3.0), Vector2(0.001, 3.0)], 12, red, false, Basis.from_scale(Vector3(1.0, 1.0, 1.5)))
		pk.lathe(kit, "steel", fc + Vector3(0, 2.6, 0), [Vector2(0.56, 0.0), Vector2(0.56, 0.45), Vector2(0.001, 0.45)], 12, Color(0.08, 0.08, 0.08), false, Basis.from_scale(Vector3(1.0, 1.0, 1.5)))
	# The towing winch, the hook on its stand, an H-bitt, bollards; life rafts on the house's roof edge.
	pk.tube(kit, "steel", Vector3(-1.6, deck_y + 0.9, -4.8), Vector3(1.6, deck_y + 0.9, -4.8), 0.75, 0.75, 14, Color(0.25, 0.38, 0.30))
	for e in [-1.7, 1.7]:
		pk.tube(kit, "steel", Vector3(e - 0.06, deck_y + 0.9, -4.8), Vector3(e + 0.06, deck_y + 0.9, -4.8), 0.95, 0.95, 14, Color(0.2, 0.3, 0.25))
	pk.tube(kit, "canvas", Vector3(-1.5, deck_y + 0.9, -4.8), Vector3(1.5, deck_y + 0.9, -4.8), 0.82, 0.82, 14, Color(0.75, 0.66, 0.42), false)
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(0, deck_y + 0.6, -8.2)), Vector3(0.6, 1.2, 0.6), Color(0.86, 0.72, 0.18))
	pk.box(kit, "steel", Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, deck_y + 1.25, -8.5)), Vector3(0.3, 0.3, 0.8), Color(0.2, 0.2, 0.2))
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "steel", Vector3(sx * 0.8, deck_y, -10.2), Vector3(sx * 0.8, deck_y + 1.2, -10.2), 0.22, 0.22, 10, Color(0.86, 0.72, 0.18))
		bollard(pk, kit, Vector3(sx * 3.6, deck_y, 7.0), Color(0.86, 0.72, 0.18))
		bollard(pk, kit, Vector3(sx * 3.4, deck_y, -9.0), Color(0.86, 0.72, 0.18))
		liferaft(pk, kit, Vector3(sx * 2.6, deck_y + 2.86, -0.9), Vector3.BACK)
	pk.tube(kit, "steel", Vector3(-0.8, deck_y + 1.0, -10.2), Vector3(0.8, deck_y + 1.0, -10.2), 0.16, 0.16, 10, Color(0.86, 0.72, 0.18))
