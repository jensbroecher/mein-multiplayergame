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
## `length` long, the sheer `fb` over the water rising by `fc` toward the bow (the forecastle) from `fc_from` (t). The
## inside of the forecastle's bulwark is drawn too. `bands` from `_bands`. Returns the deck outline at the sheer (x, z).
static func hull(pk: PropKit, kit: Dictionary, length: float, half: float, half_wl: float, fb: float, bands: Array,
		bow_run := 0.22, bow_wl := 0.3, stern_run := 0.08, transom := 0.72, fc := 0.0, fc_from := 0.82, n := 40) -> PackedVector2Array:
	var hl := length * 0.5
	var rings: Array = []
	var cols: Array = []
	for bd in bands:
		var y: float = bd[0]
		var ring: Array = []
		var f: float = clampf((y + 1.2) / (fb + 1.2), 0.0, 1.0)
		f = pow(f, 1.6)
		for side in [1.0, -1.0]:
			for k in range(n + 1):
				var i: int = k if side > 0.0 else n - k
				var t: float = float(i) / float(n)
				# The stem rakes forward: the sheer's bow tip is at the full length, the waterline's 3% short.
				var z_top: float = -hl + t * length
				var z_wl: float = -hl + t * length * 0.97
				var hb_top: float = _hb(t, half, bow_run, stern_run, transom)
				var hb_wl: float = _hb(t, half_wl, bow_wl, stern_run * 1.4, transom * 0.85, 1.3)
				var x: float = lerpf(hb_wl, hb_top, f) * side
				var z: float = lerpf(z_wl, z_top, f)
				var yy: float = y
				if y >= fb - 0.5 and fc > 0.0:
					yy = y + fc * smoothstep(fc_from, fc_from + 0.1, t)
				ring.append(Vector3(x, yy, z))
		rings.append(ring)
		cols.append(bd[1])
	var count: int = (rings[0] as Array).size()
	for r in range(rings.size() - 1):
		var r0: Array = rings[r]
		var r1: Array = rings[r + 1]
		if absf((r0[0] as Vector3).y - (r1[0] as Vector3).y) < 0.001 and (bands[r][0] == bands[r + 1][0]):
			continue
		var col: Color = cols[r + 1]
		for k in range(count):
			var k2: int = (k + 1) % count
			var a: Vector3 = r0[k]
			var b: Vector3 = r0[k2]
			var c: Vector3 = r1[k2]
			var d: Vector3 = r1[k]
			var mid: Vector3 = (a + b + c + d) * 0.25
			var out := Vector3(mid.x, 0.0, 0.0).normalized() if absf(mid.x) > 0.05 else Vector3(0, 0, signf(mid.z))
			# Plan normal from the outline's direction there.
			var tan_v: Vector3 = (b - a)
			var pn := Vector3(tan_v.z, 0.0, -tan_v.x).normalized()
			if pn.dot(out) < 0.0:
				pn = -pn
			if (b - a).length() < 1e-4:
				continue
			pk.tri(kit, "hull", a, b, c, pn, pn, pn, col, pn)
			pk.tri(kit, "hull", a, c, d, pn, pn, pn, col, pn)
	# The bulwark's inside where the sheer rises above the deck.
	if fc > 0.0:
		var top: Array = rings[rings.size() - 1]
		for k in range(count):
			var k2: int = (k + 1) % count
			var a2: Vector3 = top[k]
			var b2: Vector3 = top[k2]
			if a2.y <= fb + 0.05 and b2.y <= fb + 0.05:
				continue
			var inn := Vector3(-a2.x, 0, 0).normalized() if absf(a2.x) > 0.05 else Vector3(0, 0, -1)
			pk.quad(kit, "hull", [Vector3(a2.x, fb, a2.z), Vector3(b2.x, fb, b2.z), b2, a2], inn, (cols[cols.size() - 1] as Color).darkened(0.25))
			pk.quad(kit, "hull", [a2, b2, b2 + Vector3(0, 0.15, 0), a2 + Vector3(0, 0.15, 0)], Vector3.UP, Color(0.85, 0.85, 0.82))
	var outline := PackedVector2Array()
	for p in rings[rings.size() - 1]:
		outline.append(Vector2((p as Vector3).x, (p as Vector3).z))
	return outline


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

## A trawler, about 15m: a red or blue hull with a white sheer, the wheelhouse forward, a mast with a boom and
## lights, a gantry over the stern with a net drum, fish boxes on deck. `paint` the hull.
static func fishing_boat(pk: PropKit, kit: Dictionary, paint: Color, cabin: Color) -> void:
	var L := 15.0
	var hl := L * 0.5
	var fb := 1.6
	var outline := hull(pk, kit, L, 2.4, 2.2, fb, _bands(fb, Color(0.22, 0.22, 0.22), paint, SHIP_WHITE, 0.25), 0.34, 0.42, 0.1, 0.62, 0.9, 0.7, 24)
	deck(pk, kit, "wood", outline, fb - 0.3, Color(0.52, 0.42, 0.30))
	# Wheelhouse forward of midships.
	blk(pk, kit, "steel", Vector3(-1.5, fb - 0.3, 0.6), Vector3(1.5, fb + 2.2, 4.0), cabin)
	blk(pk, kit, "steel", Vector3(-1.65, fb + 2.2, 0.4), Vector3(1.65, fb + 2.4, 4.3), cabin.darkened(0.2))
	window_row(pk, kit, Vector3(-1.4, fb + 1.6, 4.0), Vector3(1.4, fb + 1.6, 4.0), Vector3.BACK, 0.8, 0.7, 0.15)
	for sx in [-1.0, 1.0]:
		window_row(pk, kit, Vector3(sx * 1.5, fb + 1.6, 1.0), Vector3(sx * 1.5, fb + 1.6, 3.6), Vector3(sx, 0, 0), 0.7, 0.6, 0.3)
	# Mast and boom.
	pk.tube(kit, "steel", Vector3(0, fb + 2.4, 2.4), Vector3(0, fb + 8.5, 2.4), 0.09, 0.06, 6, SHIP_WHITE)
	pk.tube(kit, "steel", Vector3(0, fb + 3.0, 2.0), Vector3(0, fb + 1.5, -3.5), 0.06, 0.05, 6, SHIP_WHITE)
	pk.beam(kit, "steel", Vector3(-1.0, fb + 6.5, 2.4), Vector3(1.0, fb + 6.5, 2.4), 0.06, 0.06, SHIP_WHITE)
	pk.box(kit, "lamp", Transform3D(Basis(), Vector3(0, fb + 8.6, 2.4)), Vector3(0.2, 0.2, 0.2), Color(1, 0.95, 0.85))
	# The stern gantry and the net drum.
	for sx2 in [-1.0, 1.0]:
		pk.beam(kit, "steel", Vector3(sx2 * 1.7, fb - 0.3, -hl + 1.4), Vector3(sx2 * 1.5, fb + 3.4, -hl + 1.0), 0.14, 0.14, Color(0.9, 0.62, 0.1))
	pk.beam(kit, "steel", Vector3(-1.6, fb + 3.4, -hl + 1.0), Vector3(1.6, fb + 3.4, -hl + 1.0), 0.16, 0.16, Color(0.9, 0.62, 0.1))
	pk.tube(kit, "steel", Vector3(-1.2, fb + 0.4, -hl + 3.0), Vector3(1.2, fb + 0.4, -hl + 3.0), 0.55, 0.55, 10, Color(0.2, 0.36, 0.5))
	pk.tube(kit, "canvas", Vector3(-1.1, fb + 0.4, -hl + 3.0), Vector3(1.1, fb + 0.4, -hl + 3.0), 0.75, 0.75, 10, Color(0.24, 0.42, 0.34))
	# Fish boxes.
	for k in range(4):
		pk.box(kit, "plastic", Transform3D(Basis(Vector3.UP, 0.2 * float(k)), Vector3(-0.8 + 0.5 * float(k % 2), fb - 0.05 + 0.35 * float(k / 2), -1.0 - 0.3 * float(k))), Vector3(0.9, 0.35, 0.6), [Color(0.2, 0.4, 0.75), Color(0.9, 0.4, 0.1)][k % 2])
	# Tyres along the sides as fenders.
	for k2 in range(4):
		for sx3 in [-1.0, 1.0]:
			var z: float = -3.5 + 2.3 * float(k2)
			pk.tyre(kit, "rubber", Vector3(sx3 * (_hb((z + hl) / L, 2.4, 0.34, 0.1, 0.62) + 0.1), fb - 0.5, z), 0.18, 0.4, 0.22, 10, Color(0.06, 0.06, 0.06), Basis(Vector3.BACK, PI * 0.5))


## A sailing yacht, about 11m: a white hull with a blue boot top, a low cabin with windows, the mast (12m) with its
## boom and the main furled on it in its blue cover, stays, a pulpit and guard rails.
static func sailboat(pk: PropKit, kit: Dictionary, stripe: Color) -> void:
	var L := 11.0
	var hl := L * 0.5
	var fb := 1.2
	var outline := hull(pk, kit, L, 1.85, 1.5, fb, _bands(fb, Color(0.12, 0.14, 0.2), SHIP_WHITE, stripe, 0.12), 0.42, 0.5, 0.06, 0.8, 0.0, 0.8, 24)
	deck(pk, kit, "plastic", outline, fb - 0.02, Color(0.88, 0.86, 0.8))
	blk(pk, kit, "plastic", Vector3(-1.1, fb, -1.2), Vector3(1.1, fb + 0.7, 2.4), SHIP_WHITE)
	for sx in [-1.0, 1.0]:
		window_row(pk, kit, Vector3(sx * 1.1, fb + 0.4, -0.8), Vector3(sx * 1.1, fb + 0.4, 2.0), Vector3(sx, 0, 0), 0.6, 0.22, 0.25)
	pk.tube(kit, "steel", Vector3(0, fb + 0.7, 1.0), Vector3(0, fb + 13.0, 1.0), 0.09, 0.06, 6, Color(0.82, 0.83, 0.85))
	pk.tube(kit, "steel", Vector3(0, fb + 1.6, 0.9), Vector3(0, fb + 1.5, -4.4), 0.07, 0.07, 6, Color(0.82, 0.83, 0.85))
	pk.tube(kit, "canvas", Vector3(0, fb + 1.75, 0.6), Vector3(0, fb + 1.65, -4.0), 0.22, 0.16, 8, Color(0.12, 0.22, 0.42))
	# Forestay and backstay, shrouds.
	pk.tube(kit, "steel", Vector3(0, fb + 12.8, 1.0), Vector3(0, fb + 0.1, hl - 0.2), 0.012, 0.012, 3, Color(0.6, 0.6, 0.6), false)
	pk.tube(kit, "steel", Vector3(0, fb + 12.8, 1.0), Vector3(0, fb + 0.1, -hl + 0.3), 0.012, 0.012, 3, Color(0.6, 0.6, 0.6), false)
	for sx2 in [-1.0, 1.0]:
		pk.tube(kit, "steel", Vector3(0, fb + 11.0, 1.0), Vector3(sx2 * 1.6, fb + 0.1, 0.8), 0.01, 0.01, 3, Color(0.6, 0.6, 0.6), false)
	# Pulpit and guard rails.
	for sx3 in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for k in range(7):
			var z: float = -hl + 0.5 + float(k) * (L - 1.4) / 6.0
			var p := Vector3(sx3 * (_hb((z + hl) / L, 1.85, 0.42, 0.06, 0.8) - 0.12), fb, z)
			pk.beam(kit, "steel", p, p + Vector3(0, 0.6, 0), 0.025, 0.025, Color(0.8, 0.8, 0.82))
			if k > 0:
				pk.beam(kit, "steel", prev + Vector3(0, 0.6, 0), p + Vector3(0, 0.6, 0), 0.02, 0.02, Color(0.8, 0.8, 0.82))
			prev = p


## A harbour tug, about 26m: a broad hull with a heavy black rubber fender all round, red topsides, a tall
## wheelhouse with windows all round, twin funnels, a towing winch and an H-bitt aft, the bow's push fender.
static func tug(pk: PropKit, kit: Dictionary) -> void:
	var L := 26.0
	var hl := L * 0.5
	var fb := 2.4
	var outline := hull(pk, kit, L, 5.0, 4.6, fb, _bands(fb, Color(0.12, 0.12, 0.12), Color(0.72, 0.16, 0.12), Color(0.95, 0.94, 0.9), 0.35), 0.3, 0.38, 0.14, 0.55, 0.8, 0.7, 28)
	deck(pk, kit, "steel", outline, fb - 0.02, Color(0.32, 0.30, 0.28))
	# The rubber fender round the sheer.
	for k in range(outline.size()):
		var a: Vector2 = outline[k]
		var b: Vector2 = outline[(k + 1) % outline.size()]
		if a.distance_to(b) < 0.05:
			continue
		var ya: float = fb - 0.55
		pk.beam(kit, "rubber", Vector3(a.x * 1.04, ya, a.y * 1.02), Vector3(b.x * 1.04, ya, b.y * 1.02), 0.55, 0.45, Color(0.06, 0.06, 0.06), Vector3.UP)
	blk(pk, kit, "steel", Vector3(-3.4, fb, -2.0), Vector3(3.4, fb + 2.6, 5.0), SHIP_WHITE)
	blk(pk, kit, "steel", Vector3(-2.6, fb + 2.6, 0.0), Vector3(2.6, fb + 5.4, 4.2), SHIP_WHITE)
	for side in [[Vector3(-2.6, fb + 4.5, 4.2), Vector3(2.6, fb + 4.5, 4.2), Vector3.BACK], [Vector3(-2.6, fb + 4.5, 0.0), Vector3(2.6, fb + 4.5, 0.0), Vector3.FORWARD],
			[Vector3(2.6, fb + 4.5, 0.2), Vector3(2.6, fb + 4.5, 4.0), Vector3.RIGHT], [Vector3(-2.6, fb + 4.5, 0.2), Vector3(-2.6, fb + 4.5, 4.0), Vector3.LEFT]]:
		window_row(pk, kit, side[0], side[1], side[2], 0.9, 1.3, 0.12)
	blk(pk, kit, "steel", Vector3(-2.8, fb + 5.4, -0.2), Vector3(2.8, fb + 5.6, 4.4), Color(0.2, 0.2, 0.2))
	pk.tube(kit, "steel", Vector3(0, fb + 5.6, 2.0), Vector3(0, fb + 9.0, 2.0), 0.1, 0.08, 6, SHIP_WHITE)
	for sx in [-1.0, 1.0]:
		blk(pk, kit, "steel", Vector3(sx * 2.2 - 0.6, fb + 2.6, -2.0), Vector3(sx * 2.2 + 0.6, fb + 6.0, -0.8), Color(0.72, 0.16, 0.12))
		blk(pk, kit, "steel", Vector3(sx * 2.2 - 0.62, fb + 5.5, -2.02), Vector3(sx * 2.2 + 0.62, fb + 6.02, -0.78), Color(0.08, 0.08, 0.08))
	pk.tube(kit, "steel", Vector3(-1.4, fb + 0.9, -6.5), Vector3(1.4, fb + 0.9, -6.5), 0.7, 0.7, 10, Color(0.3, 0.42, 0.3))
	for sx2 in [-1.0, 1.0]:
		pk.box(kit, "steel", Transform3D(Basis(), Vector3(sx2 * 1.0, fb + 0.8, -10.0)), Vector3(0.4, 1.6, 0.4), Color(0.85, 0.75, 0.2))
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(0, fb + 1.3, -10.0)), Vector3(2.4, 0.35, 0.4), Color(0.85, 0.75, 0.2))
	pk.box(kit, "rubber", Transform3D(Basis(), Vector3(0, fb - 0.6, hl + 0.2)), Vector3(3.0, 2.2, 1.2), Color(0.06, 0.06, 0.06))
