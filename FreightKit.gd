extends RefCounted
## Freight Line's props (regenerate_freight_line.gd), built through a PropKit: railway track (ballast,
## sleepers, rails), the planked crossings, the crossing signs and signals' masts, and the sounds the
## trains and crossings make (synthesised, since nothing recorded suits them).
##
## Everything is laid out in the world's frame (no scaling): a rail's top is `T`, the ballast's top lies
## 22cm under it and the sleepers stand 5cm proud of the ballast, as on a real line.

const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")

## The track is grown with the rolling stock (TrainKit.SCALE), so a bogie stands on its rails.
const K := 1.5
const GAUGE_HALF := 0.7175 * K
const BALLAST_TOP_HALF := 1.9 * K
const BALLAST_FOOT_HALF := 3.0 * K
const SLEEPER_SPACING := 0.62 * K
const SLEEPER_HALF := 1.3 * K

const BALLAST := Color(0.50, 0.47, 0.43)
const SLEEPER := Color(0.30, 0.22, 0.16)
const RAIL := Color(0.34, 0.27, 0.23)
const DECK := Color(0.19, 0.18, 0.17)

static var _streams := {}
static var _mats := {}


static func make_material(key: String) -> StandardMaterial3D:
	var m: StandardMaterial3D
	match key:
		"rail":
			m = CampKit.make_material("metal")
			m.roughness = 0.45
		"ballast":
			m = CampKit.make_material("matte")
			m.roughness = 1.0
		"deck", "sleeper":
			m = CampKit.make_material("wood")
		_:
			m = CampKit.make_material(key)
	return m


static func new_kit() -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	return pk


## The ballast's colour at a point: a slow variation by position, so two beds that overlap (where a turnout's
## tracks run close) are the same colour there and do not flicker against each other.
static func ballast_colour(p: Vector3) -> Color:
	var v: float = 0.93 + 0.07 * sin(p.x * 0.21 + 0.7) * cos(p.z * 0.17 - 0.4)
	return Color(BALLAST.r * v, BALLAST.g * v, BALLAST.b * v)


## One rail between two points on its top centre line: foot, web and head as beams; `side_vec` is across the rail.
static func _rail_beams(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, side_vec: Vector3, col: Color) -> void:
	pk.beam(kit, "rail", a + Vector3(0, -0.155 * K, 0), b + Vector3(0, -0.155 * K, 0), 0.15 * K, 0.03 * K, col, side_vec)
	pk.beam(kit, "rail", a + Vector3(0, -0.095 * K, 0), b + Vector3(0, -0.095 * K, 0), 0.045 * K, 0.1 * K, col, side_vec)
	pk.beam(kit, "rail", a + Vector3(0, -0.0225 * K, 0), b + Vector3(0, -0.0225 * K, 0), 0.085 * K, 0.045 * K, col.lightened(0.18), side_vec)


## A stretch of track along `pts` (rail-top points, the line's own spacing). `bed[i]` says whether segment
## i (pts[i] to pts[i + 1]) has ballast and sleepers; a crossing's has none (its deck is laid over it).
static func track_piece(pts: Array, bed: Array, seed_v: int = 0) -> ArrayMesh:
	var pk := new_kit()
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 77
	var sleeper_at := 0.0
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d: Vector3 = b - a
		var length: float = d.length()
		if length < 0.01:
			continue
		# A bed entry of 0 (an int) skips the segment altogether: a turnout draws that stretch itself.
		if bed[i] is int and int(bed[i]) == 0:
			sleeper_at = 0.0
			continue
		var dir: Vector3 = d / length
		var right := Vector3(-dir.z, 0.0, dir.x)
		# Both rails: foot, web and head, as beams between the two points.
		for side in [-1.0, 1.0]:
			var o: Vector3 = right * (side * GAUGE_HALF)
			_rail_beams(pk, kit, a + o, b + o, right, RAIL)
		if not bed[i]:
			sleeper_at = 0.0
			continue
		# The ballast: a flat top and two sloped shoulders.
		var ya: float = a.y - 0.22 * K
		var yb: float = b.y - 0.22 * K
		var foot_drop := 0.55 * K
		var tl_a := a + right * -BALLAST_TOP_HALF
		tl_a.y = ya
		var tr_a := a + right * BALLAST_TOP_HALF
		tr_a.y = ya
		var tl_b := b + right * -BALLAST_TOP_HALF
		tl_b.y = yb
		var tr_b := b + right * BALLAST_TOP_HALF
		tr_b.y = yb
		var fl_a := a + right * -BALLAST_FOOT_HALF
		fl_a.y = ya - foot_drop
		var fr_a := a + right * BALLAST_FOOT_HALF
		fr_a.y = ya - foot_drop
		var fl_b := b + right * -BALLAST_FOOT_HALF
		fl_b.y = yb - foot_drop
		var fr_b := b + right * BALLAST_FOOT_HALF
		fr_b.y = yb - foot_drop
		var col := ballast_colour(a)
		pk.quad(kit, "ballast", [tl_a, tr_a, tr_b, tl_b], Vector3.UP, col)
		var n_left := (right * -1.0 + Vector3.UP * 0.9).normalized()
		var n_right := (right + Vector3.UP * 0.9).normalized()
		pk.quad(kit, "ballast", [fl_a, tl_a, tl_b, fl_b], n_left, col.darkened(0.08))
		pk.quad(kit, "ballast", [tr_a, fr_a, fr_b, tr_b], n_right, col.darkened(0.08))
		# Sleepers, every SLEEPER_SPACING metres along the line.
		while sleeper_at < length:
			var c: Vector3 = a + dir * sleeper_at
			var sy: float = c.y - 0.22 * K
			pk.beam(kit, "sleeper", Vector3(c.x, sy + 0.01 * K, c.z) - dir * 0.13 * K, Vector3(c.x, sy + 0.01 * K, c.z) + dir * 0.13 * K,
					SLEEPER_HALF * 2.0, 0.085 * K, SLEEPER * (0.8 + rng.randf() * 0.4), right)
			sleeper_at += SLEEPER_SPACING
		sleeper_at -= length
	return pk.commit(kit)


## The planks and rubber panels laid over a crossing: `centre` on the road at the rail's top height less the
## rail head, `rail_dir` along the rails, `half_len` the deck's half length along them (the road's width),
## and `half_w` its half width across them. Rails stand a few centimetres proud of the deck.
static func crossing_deck(centre: Vector3, rail_dir: Vector3, half_len: float, half_w: float) -> ArrayMesh:
	var pk := new_kit()
	var kit := {}
	var right := Vector3(-rail_dir.z, 0.0, rail_dir.x)
	var top := centre.y - 0.065 * K * 0.7
	# The deck's slab and, in it, the gaps along the rails (flangeways) as dark strips.
	var a := centre - rail_dir * half_len
	var b := centre + rail_dir * half_len
	var slab_a := a
	slab_a.y = top
	var slab_b := b
	slab_b.y = top
	pk.beam(kit, "deck", slab_a - Vector3(0, 0.05, 0), slab_b - Vector3(0, 0.05, 0), half_w * 2.0, 0.1, DECK, right)
	# Plank joints across the deck every 1.2m, a pale edge strip at each end.
	var n := int(half_len * 2.0 / 1.2)
	for k in range(n + 1):
		var p: Vector3 = a + rail_dir * (float(k) * 1.2)
		p.y = top + 0.003
		pk.beam(kit, "deck", p - right * half_w, p + right * half_w, 0.04, 0.006, DECK.darkened(0.45), rail_dir)
	for side in [-1.0, 1.0]:
		var o: Vector3 = right * (side * half_w)
		pk.beam(kit, "deck", slab_a + o + Vector3(0, 0.002, 0), slab_b + o + Vector3(0, 0.002, 0), 0.12, 0.012, Color(0.68, 0.66, 0.60), right)
		# The flangeway: a dark strip just inside each rail.
		var fo: Vector3 = right * (side * (GAUGE_HALF - 0.1))
		pk.beam(kit, "deck", slab_a + fo + Vector3(0, 0.004, 0), slab_b + fo + Vector3(0, 0.004, 0), 0.06, 0.006, Color(0.04, 0.04, 0.04), right)
	return pk.commit(kit)


# ======================================================================================
#  Sounds
# ======================================================================================

static func _pcm(samples: PackedFloat32Array, rate: int, loop: bool, gain := 0.8) -> AudioStreamWAV:
	var n: int = samples.size()
	var peak := 0.001
	for i in range(n):
		peak = maxf(peak, absf(samples[i]))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(samples[i] / peak * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


## A crossing's bell: two strokes of a bright, slightly out-of-tune bell, and the quiet before the next
## pair, as a seamless loop of 0.9s.
static func bell() -> AudioStreamWAV:
	if _streams.has("bell"):
		return _streams["bell"]
	const RATE := 22050
	var n: int = int(RATE * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	for stroke in 2:
		var t0: int = int(RATE * 0.0) + stroke * int(RATE * 0.45)
		for i in range(int(RATE * 0.44)):
			var t: float = float(i) / RATE
			var env: float = exp(-t * 7.0) * minf(t * 900.0, 1.0)
			var v: float = sin(TAU * 1180.0 * t) + 0.55 * sin(TAU * 1894.0 * t) + 0.35 * sin(TAU * 2790.0 * t) + 0.2 * sin(TAU * 3523.0 * t)
			var k: int = t0 + i
			if k < n:
				out[k] += v * env
	_streams["bell"] = _pcm(out, RATE, true)
	return _streams["bell"]


## A locomotive's horn: a three-note chord of reedy tones, long, long, short, long.
static func horn() -> AudioStreamWAV:
	if _streams.has("horn"):
		return _streams["horn"]
	const RATE := 22050
	# Blasts: [start, length] seconds.
	var blasts := [[0.0, 1.5], [1.8, 1.5], [3.6, 0.5], [4.4, 2.2]]
	var n: int = int(RATE * 7.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var freqs := [311.0, 392.0, 466.0]
	for bl in blasts:
		var i0: int = int(float(bl[0]) * RATE)
		var cnt: int = int(float(bl[1]) * RATE)
		for i in range(cnt):
			var t: float = float(i) / RATE
			var env: float = minf(t * 14.0, 1.0) * minf((float(bl[1]) - t) * 12.0, 1.0)
			var v := 0.0
			for f in freqs:
				var ph: float = fmod(t * f, 1.0)
				# A buzzy near-square tone: reed horns are rich in odd harmonics.
				v += (1.0 if ph < 0.46 else -1.0) * 0.5 + sin(TAU * t * f) * 0.7
			out[i0 + i] += v * env * (0.85 + 0.15 * sin(TAU * 5.5 * t))
	# A little room.
	for i in range(int(RATE * 0.09), n):
		out[i] += out[i - int(RATE * 0.09)] * 0.22
	_streams["horn"] = _pcm(out, RATE, false)
	return _streams["horn"]


## The rumble of a diesel on the move: a low engine note with a lumpy beat and a hiss of wheels, a seamless
## loop of 4s.
static func diesel() -> AudioStreamWAV:
	if _streams.has("diesel"):
		return _streams["diesel"]
	const RATE := 22050
	var n: int = RATE * 4
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in range(n):
		var t: float = float(i) / RATE
		var white: float = rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.04
		lp2 += (lp - lp2) * 0.08
		# 16 cylinders' beat at idle-and-a-bit, whole cycles over the loop so it joins up.
		var beat: float = 0.6 + 0.4 * sin(TAU * 12.0 * t)
		var engine: float = sin(TAU * 48.0 * t) * 0.7 + sin(TAU * 96.0 * t) * 0.4 + sin(TAU * 144.0 * t) * 0.25
		out[i] = engine * beat * 0.7 + lp2 * 7.0
	_streams["diesel"] = _pcm(out, RATE, true)
	return _streams["diesel"]


## Wheels over rail joints: a steady clatter of paired knocks at a joint's pace, over a hiss. 3s loop.
static func clatter() -> AudioStreamWAV:
	if _streams.has("clatter"):
		return _streams["clatter"]
	const RATE := 22050
	var n: int = RATE * 3
	var rng := RandomNumberGenerator.new()
	rng.seed = 7731
	var out := PackedFloat32Array()
	out.resize(n)
	var hiss := 0.0
	for i in range(n):
		var white: float = rng.randf_range(-1.0, 1.0)
		hiss += (white - hiss) * 0.35
		out[i] = (white - hiss) * 0.05
	# 20 joints a second, each a two-axle knock (a bogie's wheels a few ms apart).
	var joint := 0.0
	while joint < 3.0:
		for axle in 4:
			var t0: float = joint + float(axle) * 0.0042 + (0.012 if axle >= 2 else 0.0)
			var i0: int = int(t0 * RATE)
			for k in range(int(RATE * 0.03)):
				var t: float = float(k) / RATE
				var idx: int = (i0 + k) % n
				out[idx] += sin(TAU * (260.0 + 40.0 * axle) * t) * exp(-t * 150.0) * 0.5
		joint += 0.05
	_streams["clatter"] = _pcm(out, RATE, true)
	return _streams["clatter"]


# ======================================================================================
#  Yard fittings (the station and the cooperative are YardKit and FactoryKit)
# ======================================================================================

const DARK_HAND := Color(0.06, 0.06, 0.06)


## A water tower: a tank on eight braced legs under a conical roof, with a ladder and a spout. Origin on the
## ground at the middle, life size, 17m tall.
static func water_tower(pk: PropKit, kit: Dictionary) -> void:
	var tank_y := 11.0
	var r := 3.9
	for k in 8:
		var a: float = TAU * k / 8.0
		var foot := Vector3(cos(a) * 5.4, 0, sin(a) * 5.4)
		var top := Vector3(cos(a) * (r - 0.3), tank_y, sin(a) * (r - 0.3))
		pk.beam(kit, "steel", foot, top, 0.42, 0.42, Color(0.30, 0.20, 0.14))
	for k in 8:
		var a0: float = TAU * k / 8.0
		var a1: float = TAU * (k + 1) / 8.0
		for h in [3.7, 7.2]:
			var f: float = 1.0 - h / tank_y * 0.3
			var p0 := Vector3(cos(a0) * 5.4 * f, h, sin(a0) * 5.4 * f)
			var p1 := Vector3(cos(a1) * 5.4 * f, h, sin(a1) * 5.4 * f)
			pk.beam(kit, "steel", p0, p1, 0.22, 0.22, Color(0.25, 0.22, 0.2))
		# Diagonals.
		var d0 := Vector3(cos(a0) * 5.4 * 0.95, 3.7, sin(a0) * 5.4 * 0.95)
		var d1 := Vector3(cos(a1) * 5.4 * 0.9, 7.2, sin(a1) * 5.4 * 0.9)
		pk.beam(kit, "steel", d0, d1, 0.12, 0.12, Color(0.25, 0.22, 0.2))
	pk.tube(kit, "wood", Vector3(0, tank_y, 0), Vector3(0, tank_y + 5.0, 0), r, r, 20, Color(0.50, 0.35, 0.22), true)
	for h in [0.6, 1.8, 3.0, 4.2]:
		pk.tube(kit, "steel", Vector3(0, tank_y + h, 0), Vector3(0, tank_y + h + 0.12, 0), r + 0.06, r + 0.06, 20, Color(0.18, 0.18, 0.18), false)
	pk.lathe(kit, "paint", Vector3(0, tank_y + 5.0, 0), [Vector2(r + 0.6, 0.0), Vector2(r * 0.6, 1.4), Vector2(0.001, 3.0)], 20, Color(0.44, 0.42, 0.40), false)
	# Ladder up one side and the spout.
	pk.beam(kit, "steel", Vector3(r + 0.1, 0.0, -0.3), Vector3(r + 0.1, tank_y + 5.0, -0.3), 0.08, 0.08, DARK_HAND)
	pk.beam(kit, "steel", Vector3(r + 0.1, 0.0, 0.3), Vector3(r + 0.1, tank_y + 5.0, 0.3), 0.08, 0.08, DARK_HAND)
	var y := 0.6
	while y < tank_y + 5.0:
		pk.beam(kit, "steel", Vector3(r + 0.1, y, -0.3), Vector3(r + 0.1, y, 0.3), 0.06, 0.06, DARK_HAND)
		y += 0.6
	pk.tube(kit, "steel", Vector3(-r + 0.3, tank_y - 0.8, 0), Vector3(-r - 4.0, tank_y - 2.4, 0), 0.4, 0.4, 10, Color(0.2, 0.2, 0.2))


## A telegraph pole: a tapering timber shaft, two crossarms with four insulators each. Origin on the ground,
## life size, 11m tall. The wires are added by the generator between poles.
static func pole(pk: PropKit, kit: Dictionary) -> void:
	pk.tube(kit, "wood", Vector3(0, 0, 0), Vector3(0, 11.0, 0), 0.30, 0.20, 10, Color(0.34, 0.26, 0.19), true)
	for y in [10.2, 8.6]:
		pk.beam(kit, "wood", Vector3(-1.5, y, 0), Vector3(1.5, y, 0), 0.16, 0.2, Color(0.30, 0.22, 0.16))
		for sx in [-1.35, -0.45, 0.45, 1.35]:
			pk.tube(kit, "glass", Vector3(sx, y + 0.1, 0), Vector3(sx, y + 0.42, 0), 0.1, 0.07, 8, Color(0.40, 0.62, 0.52, 0.8), true)
	pk.beam(kit, "steel", Vector3(-0.6, 8.6, 0), Vector3(0, 10.0, 0), 0.07, 0.07, Color(0.2, 0.2, 0.2))
	pk.beam(kit, "steel", Vector3(0.6, 8.6, 0), Vector3(0, 10.0, 0), 0.07, 0.07, Color(0.2, 0.2, 0.2))


## A sagebrush bush: ten grey-green lobes round a woody base, 1.4m across and 0.9m tall at scale 1.
static func sage(seed_v: int) -> ArrayMesh:
	var pk := new_kit()
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for k in 6:
		var a: float = rng.randf() * TAU
		var d: float = rng.randf_range(0.0, 0.55)
		var c := Vector3(cos(a) * d, 0.28 + rng.randf() * 0.2, sin(a) * d)
		var r: float = rng.randf_range(0.26, 0.42)
		var col := Color(0.36 + rng.randf() * 0.1, 0.40 + rng.randf() * 0.08, 0.27 + rng.randf() * 0.05)
		pk.lathe(kit, "leaf", c, [Vector2(0.001, -r * 0.7), Vector2(r, 0.0), Vector2(r * 0.8, r * 0.45), Vector2(0.001, r * 0.8)], 6, col, false)
	pk.tube(kit, "wood", Vector3(0, 0, 0), Vector3(0, 0.3, 0), 0.08, 0.05, 5, Color(0.30, 0.24, 0.18), false)
	return pk.commit(kit)


## A boulder at unit height (base on y = 0, top at y = 1): a lumpy dome that is widest at its foot, with a flat
## base to sink into the ground, built from flat-shaded facets in banded sandstone. `aspect` is its half width
## over its height: about 1.7 for the low stones a cart can ride over, about 1 for the taller ones.
static func rock(seed_v: int, aspect: float) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 1.0
	noise.fractal_octaves = 2
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 31 + 7
	const SEGS := 12
	const RINGS := 7
	var ax: float = aspect * rng.randf_range(0.92, 1.12)
	var az: float = aspect * rng.randf_range(0.82, 1.05)
	var grid: Array = []
	var lo := INF
	var hi := -INF
	for i in range(RINGS + 1):
		var phi: float = PI * float(i) / float(RINGS)
		var row: Array = []
		for j in range(SEGS):
			var th: float = TAU * float(j) / float(SEGS) + 0.3
			var u := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			var n1: float = noise.get_noise_3dv(u * 1.7 + Vector3(seed_v * 0.37, 0.0, 0.0))
			var n2: float = noise.get_noise_3dv(u * 4.1 + Vector3(0.0, seed_v * 0.11, 0.0))
			var p: Vector3 = u * (1.0 + 0.24 * n1 + 0.07 * n2)
			# The lower half is squashed to a flat foot; the width is greatest low down and eases in toward the top.
			var y: float = p.y if p.y >= 0.0 else p.y * 0.5
			y = maxf(y, -0.32)
			var f: float = 1.0 + 0.24 * (1.0 - smoothstep(-0.32, 0.65, y)) - 0.20 * smoothstep(0.25, 1.1, y)
			row.append(Vector3(p.x * f * ax, y, p.z * f * az))
			lo = minf(lo, y)
			hi = maxf(hi, y)
		grid.append(row)
	var k: float = 1.0 / maxf(hi - lo, 0.001)
	for i in range(RINGS + 1):
		for j in range(SEGS):
			var p: Vector3 = grid[i][j]
			grid[i][j] = Vector3(p.x * k, (p.y - lo) * k, p.z * k)
	var tints := [Color(0.56, 0.42, 0.31), Color(0.50, 0.39, 0.30), Color(0.62, 0.50, 0.38)]
	var base: Color = tints[seed_v % tints.size()]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre := Vector3(0.0, 0.4, 0.0)
	for i in range(RINGS):
		for j in range(SEGS):
			var j2: int = (j + 1) % SEGS
			var q: Array = [grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j]]
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var a: Vector3 = q[tri[0]]
				var b: Vector3 = q[tri[1]]
				var c: Vector3 = q[tri[2]]
				if (c - a).cross(b - a).length_squared() < 1e-9:
					continue
				var mid: Vector3 = (a + b + c) / 3.0
				var out: Vector3 = mid - centre
				if (c - a).cross(b - a).dot(out) < 0.0:
					var t: Vector3 = b
					b = c
					c = t
				# Sandstone beds: bands up the stone, a darker foot, a bleached top, a little per-facet variation.
				var band: float = 0.93 + 0.07 * sin(mid.y * 17.0 + float(seed_v))
				var shade: float = band * (0.82 + 0.2 * smoothstep(0.0, 0.5, mid.y)) * rng.randf_range(0.94, 1.06)
				var col := Color(base.r * shade, base.g * shade, base.b * shade)
				for v in [a, b, c]:
					st.set_smooth_group(-1)
					st.set_color(col)
					st.add_vertex(v)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	mesh.surface_set_material(0, m)
	return mesh


## The wind over the plain: a low steady roar with long gusts and a thin hiss on top, a seamless loop of 14s.
static func wind() -> AudioStreamWAV:
	const RATE := 22050
	const SECONDS := 14.0
	var n: int = int(RATE * SECONDS)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var low2 := 0.0
	var band := 0.0
	for i in range(n):
		var t: float = float(i) / RATE
		var white: float = rng.randf_range(-1.0, 1.0)
		low += (white - low) * 0.015
		low2 += (low - low2) * 0.04
		band += (white - band) * 0.18
		var gust: float = 0.5 + 0.5 * sin(t * TAU / 7.0) * sin(t * TAU / 3.5 + 0.9)
		out[i] = low2 * 10.0 * (0.4 + gust) + (white - band) * 0.07 * gust * gust
	# Crossfade the end into the start so it loops without a click.
	var fade: int = int(RATE * 1.2)
	for i in range(fade):
		var f: float = float(i) / float(fade)
		out[i] = out[i] * sqrt(f) + out[n - fade + i] * sqrt(1.0 - f)
	var wav := _pcm(out.slice(0, n - fade), RATE, true, 0.7)
	return wav


## A tunnel portal: a stone facade with a segmental arch (8.4m wide, its crown 8.9m over the rail) standing in
## front of the hill: a central bay 16m wide and 15m high between two pilasters, its wings stepping down toward
## the ground on both sides (where the hill or the cutting is higher than a wing, the wing simply ends in it),
## and a vaulted lining running 24m into the hill that darkens to pitch black, with a lamp on each wall every
## 6m. The facade's front face is on z = 0, its back on z = 3.4; the lining runs on from there toward +z; x
## across, y up from the rail's top. The trains run into the lining and on, past its black end, where the hill
## hides them.
static func portal(pk: PropKit, kit: Dictionary) -> void:
	var stone := Color(0.62, 0.57, 0.49)
	const HW := 4.2
	const SPRING := 7.0
	const CROWN := 8.9
	const BAY := 8.0
	const TOP := 15.0
	const WING_SLOPE := 0.85
	var half_w: float = BAY + (TOP - 1.0) / WING_SLOPE
	var rr: float = (HW * HW + (CROWN - SPRING) * (CROWN - SPRING)) / (2.0 * (CROWN - SPRING))
	var cy: float = CROWN - rr
	var arch: Array = []
	const ARCH_N := 18
	for k in range(ARCH_N + 1):
		var x: float = -HW + 2.0 * HW * float(k) / float(ARCH_N)
		arch.append(Vector2(x, cy + sqrt(rr * rr - x * x)))
	# The facade's outline: the opening cut from the bottom edge, the top a flat bay with sloping wings.
	var outline := PackedVector2Array([Vector2(-half_w, -0.8), Vector2(-HW, -0.8)])
	for p in arch:
		outline.append(p)
	outline.append_array(PackedVector2Array([Vector2(HW, -0.8), Vector2(half_w, -0.8), Vector2(half_w, 1.0),
			Vector2(BAY, TOP), Vector2(-BAY, TOP), Vector2(-half_w, 1.0)]))
	pk.extrude(kit, "matte", outline, 0.0, 3.4, 0.0, stone, func(p: Vector3, _n: Vector3) -> Color:
		# Courses of dressed stone, 0.9m high, each a shade of its own.
		var course: int = int(floor(p.y / 0.9))
		var shade: float = 0.86 + 0.07 * float((course * 7 + int(floor(p.x / 2.0)) * 3) % 4)
		return stone * shade
	)
	# The arch ring of voussoirs, a little proud of the facade, alternating light and dark.
	var a0: float = atan2(SPRING - cy, -HW)
	var a1: float = atan2(SPRING - cy, HW)
	var prev_in := Vector3.ZERO
	var prev_out := Vector3.ZERO
	const RING_N := 14
	for k in range(RING_N + 1):
		var a: float = lerpf(a0, a1, float(k) / float(RING_N))
		var pin := Vector3(cos(a) * rr, cy + sin(a) * rr, -0.1)
		var pout := Vector3(cos(a) * (rr + 0.85), cy + sin(a) * (rr + 0.85), -0.1)
		if k > 0:
			var col: Color = stone.lightened(0.16) if k % 2 == 0 else stone.lightened(0.04)
			pk.quad(kit, "matte", [prev_in, prev_out, pout, pin], Vector3(0, 0, -1), col)
		prev_in = pin
		prev_out = pout
	# Keystone, a string course across the bay, two pilasters either side of the arch and a coping along the top.
	pk.block(kit, "matte", Vector3(-0.7, CROWN - 0.1, -0.3), Vector3(0.7, CROWN + 1.35, 0.1), stone.lightened(0.24))
	pk.block(kit, "matte", Vector3(-BAY - 0.3, 11.0, -0.3), Vector3(BAY + 0.3, 11.35, 0.1), stone.lightened(0.14))
	for sx in [-1.0, 1.0]:
		pk.block(kit, "matte", Vector3(sx * 6.6 - 0.6, -0.8, -0.35), Vector3(sx * 6.6 + 0.6, TOP, 0.1), stone.lightened(0.07))
		pk.block(kit, "matte", Vector3(sx * 6.6 - 0.8, TOP - 0.1, -0.5), Vector3(sx * 6.6 + 0.8, TOP + 0.3, 0.2), stone.lightened(0.2))
		# The wing's coping, along its sloping top.
		pk.beam(kit, "matte", Vector3(sx * BAY, TOP + 0.1, 1.7), Vector3(sx * half_w, 1.1, 1.7), 4.0, 0.5, stone.lightened(0.14), Vector3(0, 0, 1))
	pk.beam(kit, "matte", Vector3(-BAY, TOP + 0.1, 1.7), Vector3(BAY, TOP + 0.1, 1.7), 4.0, 0.5, stone.lightened(0.14), Vector3(0, 0, 1))
	# The lining: the arch's section lofted along z from the back of the facade, shading to black.
	var section: Array = [Vector2(-HW, -0.45)]
	for p in arch:
		section.append(p)
	section.append(Vector2(HW, -0.45))
	var depth := 24.0
	const SLICES := 8
	for sl in range(SLICES):
		var z0: float = 3.4 + depth * float(sl) / float(SLICES)
		var z1: float = 3.4 + depth * float(sl + 1) / float(SLICES)
		var c0: Color = _tunnel_shade(float(sl) / float(SLICES))
		var c1: Color = _tunnel_shade(float(sl + 1) / float(SLICES))
		for k in range(section.size()):
			var k2: int = (k + 1) % section.size()
			var pa: Vector2 = section[k]
			var pb: Vector2 = section[k2]
			var edge: Vector2 = pb - pa
			# Facing in toward the tunnel's axis.
			var n2 := Vector2(-edge.y, edge.x).normalized()
			var mid: Vector2 = (pa + pb) * 0.5
			if n2.dot(Vector2(0.0, 4.0) - mid) < 0.0:
				n2 = -n2
			var n3 := Vector3(n2.x, n2.y, 0.0)
			pk.tri(kit, "matte", Vector3(pa.x, pa.y, z0), Vector3(pb.x, pb.y, z0), Vector3(pb.x, pb.y, z1), n3, n3, n3, c0, n3)
			pk.tri(kit, "matte", Vector3(pa.x, pa.y, z0), Vector3(pb.x, pb.y, z1), Vector3(pa.x, pa.y, z1), n3, n3, n3, c1, n3)
	# The black end: a plug filling the section.
	var zend: float = 3.4 + depth
	var plug_c := Vector3(0.0, 3.5, zend)
	for k in range(section.size()):
		var k2: int = (k + 1) % section.size()
		pk.tri(kit, "matte", plug_c, Vector3(section[k].x, section[k].y, zend), Vector3(section[k2].x, section[k2].y, zend),
				Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1), Color(0, 0, 0), Vector3(0, 0, -1))
	# Lamps on both walls, warm, getting smaller into the dark.
	for lz in [6.0, 12.0, 18.0]:
		for sx in [-1.0, 1.0]:
			pk.block(kit, "lamp", Vector3(sx * (HW - 0.12) - 0.1, 5.2, lz - 0.2), Vector3(sx * (HW - 0.12) + 0.1, 5.7, lz + 0.2), Color(1.0, 0.82, 0.50))


## The lining's colour at `t` (0 at the facade, 1 at the black end): dim concrete falling off to nothing.
static func _tunnel_shade(t: float) -> Color:
	var v: float = 0.42 * pow(maxf(1.0 - t, 0.0), 1.7)
	return Color(v * 1.05, v, v * 0.95)



# ======================================================================================
#  Turnouts, buffer stops and platforms
# ======================================================================================

const STEEL_DARK := Color(0.20, 0.19, 0.19)
const BLADE := Color(0.46, 0.40, 0.36)

## The value of a table of [t, value] rows (t ascending) at `t`, linearly between rows and held at the ends.
static func _table_at(rows: Array, t: float) -> float:
	if t <= float(rows[0][0]):
		return float(rows[0][1])
	for i in range(1, rows.size()):
		if t <= float(rows[i][0]):
			var t0: float = rows[i - 1][0]
			var t1: float = rows[i][0]
			return lerpf(float(rows[i - 1][1]), float(rows[i][1]), (t - t0) / maxf(t1 - t0, 0.0001))
	return float(rows[rows.size() - 1][1])


## The part of a turnout where the two tracks are too close to have beds of their own: both tracks' rails with
## the switch blades (lighter, with stretcher bars and heel blocks), a frog where the branch's inner rail crosses
## the through track's, a check rail opposite it, one set of long sleepers and one ballast bed, and a switch stand
## with its lever, target and rod beside the toe. `through` is the through track's centre line (rail-top points,
## straight), `branch` the diverging track's, both from the toe, `side` +1 when the branch leaves to the right of
## the way of travel and -1 to the left. The mesh is in the world's frame. `zone_end` (returned in `info`) is how
## far along the through track this covers.
static func turnout(through: Array, branch: Array, side: float, info: Dictionary = {}) -> ArrayMesh:
	var pk := new_kit()
	var kit := {}
	var a: Vector3 = through[0]
	var dir := Vector3(through[through.size() - 1].x - a.x, 0.0, through[through.size() - 1].z - a.z).normalized()
	var right := Vector3(-dir.z, 0.0, dir.x)
	# Through track: height by distance. Branch: position, direction, distance and lateral offset (toward `side`).
	var ty: Array = []
	for p in through:
		ty.append([Vector3(p.x - a.x, 0.0, p.z - a.z).dot(dir), p.y])
	var bs: Array = []
	var lat_rows: Array = []
	var by_rows: Array = []
	for i in range(branch.size()):
		var p: Vector3 = branch[i]
		var d: Vector3 = branch[mini(i + 1, branch.size() - 1)] - branch[maxi(i - 1, 0)]
		d.y = 0.0
		d = d.normalized()
		var rel := Vector3(p.x - a.x, 0.0, p.z - a.z)
		var t: float = rel.dot(dir)
		var lat: float = rel.dot(right) * side
		bs.append({"p": p, "d": d, "r": Vector3(-d.z, 0.0, d.x), "t": t, "lat": lat})
		lat_rows.append([t, lat])
		by_rows.append([t, p.y])
	# Where the branch is far enough off (4.4m between the tracks) for sleepers of its own.
	var t_end: float = float(bs[bs.size() - 1]["t"])
	for b in bs:
		if float(b["lat"]) >= 4.4:
			t_end = float(b["t"])
			break
	if info != null:
		info["zone_end"] = t_end
	# --- Ballast and sleepers over the whole width, from the through track's far side to the branch's far rail.
	var step := 1.5
	var tt := 0.0
	var rows_b: Array = []
	while tt <= t_end + 0.01:
		var lat: float = _table_at(lat_rows, tt)
		var y: float = _table_at(ty, tt)
		rows_b.append([tt, lat, y])
		tt += step
	for i in range(rows_b.size() - 1):
		var r0: Array = rows_b[i]
		var r1: Array = rows_b[i + 1]
		var pts_top: Array = []
		var pts_foot: Array = []
		for rr in [r0, r1]:
			var c: Vector3 = a + dir * float(rr[0])
			var ylev: float = float(rr[2]) - 0.22 * K
			var lo: float = -BALLAST_TOP_HALF - (float(rr[1]) if side < 0.0 else 0.0)
			var hi: float = BALLAST_TOP_HALF + (float(rr[1]) if side > 0.0 else 0.0)
			var flo: float = lo - (BALLAST_FOOT_HALF - BALLAST_TOP_HALF)
			var fhi: float = hi + (BALLAST_FOOT_HALF - BALLAST_TOP_HALF)
			pts_top.append([Vector3(c.x, ylev, c.z) + right * lo, Vector3(c.x, ylev, c.z) + right * hi])
			pts_foot.append([Vector3(c.x, ylev - 0.55 * K, c.z) + right * flo, Vector3(c.x, ylev - 0.55 * K, c.z) + right * fhi])
		var col := ballast_colour(a + dir * float(r0[0]))
		pk.quad(kit, "ballast", [pts_top[0][0], pts_top[0][1], pts_top[1][1], pts_top[1][0]], Vector3.UP, col)
		pk.quad(kit, "ballast", [pts_foot[0][0], pts_top[0][0], pts_top[1][0], pts_foot[1][0]], (-right + Vector3.UP * 0.9).normalized(), col.darkened(0.08))
		pk.quad(kit, "ballast", [pts_top[0][1], pts_foot[0][1], pts_foot[1][1], pts_top[1][1]], (right + Vector3.UP * 0.9).normalized(), col.darkened(0.08))
	var sleeper_t := 0.4 * K
	var srng := RandomNumberGenerator.new()
	srng.seed = 31
	while sleeper_t < t_end:
		var lat2: float = _table_at(lat_rows, sleeper_t)
		var y2: float = _table_at(ty, sleeper_t)
		var lo2: float = -SLEEPER_HALF - (lat2 if side < 0.0 else 0.0)
		var hi2: float = SLEEPER_HALF + (lat2 if side > 0.0 else 0.0)
		var c2: Vector3 = a + dir * sleeper_t
		var ctr := Vector3(c2.x, y2 - 0.22 * K + 0.01 * K, c2.z) + right * ((lo2 + hi2) * 0.5)
		pk.beam(kit, "sleeper", ctr - dir * 0.13 * K, ctr + dir * 0.13 * K, hi2 - lo2, 0.085 * K, SLEEPER * (0.8 + srng.randf() * 0.4), right)
		sleeper_t += SLEEPER_SPACING
	# --- The branch's rails: both start on the through rails (a hair higher, so they do not fight) and part from them.
	var inner_pts: Array = []
	for i in range(bs.size()):
		var b: Dictionary = bs[i]
		if float(b["t"]) > t_end + 3.0:
			break
		var blade: bool = float(b["t"]) < 9.0
		var col_r: Color = BLADE if blade else RAIL
		if i + 1 < bs.size() and float(bs[i + 1]["t"]) <= t_end + 3.0:
			var n: Dictionary = bs[i + 1]
			for sd in [-1.0, 1.0]:
				var pa: Vector3 = (b["p"] as Vector3) + (b["r"] as Vector3) * (sd * GAUGE_HALF) + Vector3(0, 0.012 * K, 0)
				var pb: Vector3 = (n["p"] as Vector3) + (n["r"] as Vector3) * (sd * GAUGE_HALF) + Vector3(0, 0.012 * K, 0)
				_rail_beams(pk, kit, pa, pb, b["r"], col_r)
		# The inner rail of the branch (the one nearer the through track).
		inner_pts.append((b["p"] as Vector3) - (b["r"] as Vector3) * (side * GAUGE_HALF))
	# Stretcher bars between the blades, heel blocks where the blades end.
	for tb in [1.4 * K, 3.6 * K]:
		var yb: float = _table_at(by_rows, tb)
		var bi: int = 0
		for i in range(bs.size()):
			if float(bs[i]["t"]) >= tb:
				bi = i
				break
		var bb: Dictionary = bs[bi]
		var l: Vector3 = (bb["p"] as Vector3) - (bb["r"] as Vector3) * GAUGE_HALF
		var r: Vector3 = (bb["p"] as Vector3) + (bb["r"] as Vector3) * GAUGE_HALF
		l.y = yb - 0.1 * K
		r.y = yb - 0.1 * K
		pk.beam(kit, "steel", l, r, 0.16 * K, 0.04 * K, STEEL_DARK, dir)
	for sd in [-1.0, 1.0]:
		var hb: Dictionary = bs[0]
		for i in range(bs.size()):
			if float(bs[i]["t"]) >= 9.0:
				hb = bs[i]
				break
		var hp: Vector3 = (hb["p"] as Vector3) + (hb["r"] as Vector3) * (sd * GAUGE_HALF)
		pk.block(kit, "steel", hp + Vector3(-0.2 * K, -0.16 * K, -0.3 * K), hp + Vector3(0.2 * K, -0.02 * K, 0.3 * K), STEEL_DARK)
	# --- The frog: where the branch's inner rail meets the through track's rail on the branch's side.
	var frog_set := false
	var frog_pos := Vector3.ZERO
	var frog_dir := dir
	for i in range(1, inner_pts.size()):
		var u0: float = Vector3(inner_pts[i - 1].x - a.x, 0.0, inner_pts[i - 1].z - a.z).dot(right) * side
		var u1: float = Vector3(inner_pts[i].x - a.x, 0.0, inner_pts[i].z - a.z).dot(right) * side
		if u0 < GAUGE_HALF and u1 >= GAUGE_HALF:
			var f: float = (GAUGE_HALF - u0) / maxf(u1 - u0, 0.0001)
			frog_pos = (inner_pts[i - 1] as Vector3).lerp(inner_pts[i], f)
			frog_dir = ((inner_pts[i] as Vector3) - (inner_pts[i - 1] as Vector3))
			frog_dir.y = 0.0
			frog_dir = frog_dir.normalized()
			frog_set = true
			break
	if frog_set:
		var fa: Vector3 = frog_pos - frog_dir * 0.7 * K
		var fb: Vector3 = frog_pos + frog_dir * 1.3 * K
		pk.beam(kit, "steel", fa + Vector3(0, -0.01 * K, 0), fb + Vector3(0, -0.01 * K, 0), 0.5 * K, 0.1 * K, STEEL_DARK, Vector3(-frog_dir.z, 0, frog_dir.x))
		pk.beam(kit, "steel", fa + Vector3(0, 0.02 * K, 0), fb + Vector3(0, 0.02 * K, 0), 0.2 * K, 0.06 * K, STEEL_DARK.lightened(0.15), Vector3(-frog_dir.z, 0, frog_dir.x))
		# Wing rails either side of the nose, and the check rail inside the opposite through rail.
		for sd in [-1.0, 1.0]:
			var wo: Vector3 = Vector3(-frog_dir.z, 0, frog_dir.x) * (sd * 0.42 * K)
			_rail_beams(pk, kit, fa + wo + Vector3(0, 0.0, 0), fb + wo + Vector3(0, 0.0, 0), Vector3(-frog_dir.z, 0, frog_dir.x), RAIL)
		var tf: float = Vector3(frog_pos.x - a.x, 0.0, frog_pos.z - a.z).dot(dir)
		var cy: float = _table_at(ty, tf)
		var cpos: Vector3 = a + dir * tf + right * (-side * (GAUGE_HALF - 0.2 * K))
		cpos.y = cy
		_rail_beams(pk, kit, cpos - dir * 2.4 * K, cpos + dir * 2.4 * K, right, RAIL)
	# --- The switch stand beside the toe, on the side away from the branch: base, post, lever with its weight, a
	# target disc, and a rod across to the stretcher bar.
	var st: Vector3 = a + dir * 2.6 * K + right * (-side * (SLEEPER_HALF + 1.0 * K))
	var base_y: float = _table_at(ty, 2.6 * K) - 0.58 * K
	pk.block(kit, "steel", Vector3(st.x - 0.28 * K, base_y, st.z - 0.28 * K), Vector3(st.x + 0.28 * K, base_y + 0.4 * K, st.z + 0.28 * K), Color(0.62, 0.61, 0.58))
	pk.tube(kit, "steel", Vector3(st.x, base_y + 0.4 * K, st.z), Vector3(st.x, base_y + 1.5 * K, st.z), 0.06 * K, 0.05 * K, 8, STEEL_DARK)
	var lever_end: Vector3 = Vector3(st.x, base_y + 1.15 * K, st.z) + (right * (-side) * 0.9 * K) + Vector3(0, 0.55 * K, 0)
	pk.beam(kit, "steel", Vector3(st.x, base_y + 1.15 * K, st.z), lever_end, 0.06 * K, 0.06 * K, STEEL_DARK, dir)
	pk.tube(kit, "steel", lever_end - Vector3(0, 0.1 * K, 0), lever_end + Vector3(0, 0.1 * K, 0), 0.13 * K, 0.13 * K, 8, Color(0.55, 0.1, 0.08))
	# The target: a disc on the post's top, its face along the track (green for the main line).
	pk.tube(kit, "steel", Vector3(st.x, base_y + 1.5 * K, st.z) - dir * 0.02 * K, Vector3(st.x, base_y + 1.5 * K, st.z) + dir * 0.02 * K, 0.3 * K, 0.3 * K, 14, Color(0.05, 0.1, 0.05), true)
	pk.tube(kit, "lamp", Vector3(st.x, base_y + 1.5 * K, st.z) - dir * 0.03 * K, Vector3(st.x, base_y + 1.5 * K, st.z) - dir * 0.05 * K, 0.22 * K, 0.22 * K, 14, Color(0.25, 0.9, 0.3), true)
	var rod_to: Vector3 = a + dir * 1.4 * K
	rod_to.y = _table_at(ty, 1.4 * K) - 0.12 * K
	var rod_from := Vector3(st.x, base_y + 0.25 * K, st.z)
	pk.beam(kit, "steel", rod_from, Vector3(rod_to.x, rod_from.y, rod_to.z), 0.05 * K, 0.05 * K, STEEL_DARK, dir)
	return pk.commit(kit)


## A heap of ballast: a polar grid of facets over (rx, rz) from the centre `c` (on the ground), rising `h` at the middle
## with a lumpy crown (noise), the vertex colours mixing ballast grey and earth, and loose stones on it. Normals come
## from the height field so the facets shade as one lumpy surface.
static func _ballast_heap(pk: PropKit, kit: Dictionary, c: Vector3, rx: float, rz: float, h: float, seed_v: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.9
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE
	var rings := 6
	var segs := 18
	var height := func(u: float, v: float) -> float:
		var r: float = sqrt(u * u + v * v)
		if r >= 1.0:
			return 0.0
		var crown: float = pow(1.0 - r * r, 1.1)
		return h * crown * (0.82 + 0.3 * noise.get_noise_2d(u * 3.0, v * 3.0))
	var pts: Array = []
	var cols: Array = []
	for i in range(rings + 1):
		var row: Array = []
		var crow: Array = []
		var rr: float = float(i) / float(rings)
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs)
			var u: float = cos(a) * rr
			var v: float = sin(a) * rr
			row.append(c + Vector3(u * rx, float(height.call(u, v)), v * rz))
			var t: float = 0.5 + 0.5 * noise.get_noise_2d(u * 7.0 + 31.0, v * 7.0)
			crow.append(BALLAST.lerp(Color(0.56, 0.46, 0.34), t * 0.8).darkened(0.12 + 0.12 * (1.0 - rr)))
		pts.append(row)
		cols.append(crow)
	for i in range(rings):
		for j in range(segs):
			var j2: int = (j + 1) % segs
			var a0: Vector3 = pts[i][j]
			var b0: Vector3 = pts[i][j2]
			var a1: Vector3 = pts[i + 1][j]
			var b1: Vector3 = pts[i + 1][j2]
			var col: Color = cols[i][j].lerp(cols[i + 1][j2], 0.5)
			var n: Vector3 = (b0 - a0).cross(a1 - a0).normalized()
			if n.y < 0.0:
				n = -n
			if i == 0:
				pk.tri(kit, "ballast", a0, a1, b1, n, n, n, col, n)
			else:
				pk.quad(kit, "ballast", [a0, b0, b1, a1], n, col)
	# Loose stones: small tilted boxes on the heap's surface.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 5
	for k in range(46):
		var a2: float = rng.randf() * TAU
		var rr2: float = sqrt(rng.randf()) * 0.92
		var u2: float = cos(a2) * rr2
		var v2: float = sin(a2) * rr2
		var sz: float = rng.randf_range(0.14, 0.32)
		var p: Vector3 = c + Vector3(u2 * rx, float(height.call(u2, v2)) + sz * 0.15, v2 * rz)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
		var g: float = rng.randf_range(0.34, 0.52)
		pk.box(kit, "ballast", Transform3D(basis, p), Vector3(sz * 1.3, sz * 0.8, sz), Color(g, g * 0.97, g * 0.9))


## A buffer stop at the dead end of a track, life size, in a frame where the track runs along +z toward the stop
## (the arriving train comes from -z), x across, y up from the rail's top: a concrete slab and anchor block under
## a red-and-white striped buffer beam on two steel uprights, two buffer heads, two hydraulic cylinders back to the
## anchor, diagonal braces, a bank of earth behind, the rail ends on the slab, and a red lamp on its own post.
static func buffer_stop(pk: PropKit, kit: Dictionary) -> void:
	var concrete := Color(0.66, 0.65, 0.62)
	var red := Color(0.78, 0.10, 0.08)
	var white := Color(0.93, 0.92, 0.88)
	var steel := Color(0.30, 0.31, 0.32)
	# Slab, anchor block and the bank behind them.
	pk.block(kit, "matte", Vector3(-2.3, -0.8, 0.2), Vector3(2.3, -0.25, 4.7), concrete)
	pk.block(kit, "matte", Vector3(-2.0, -0.25, 2.5), Vector3(2.0, 0.6, 4.5), concrete.darkened(0.06))
	# The bank behind: a low heap of ballast and earth (a bumpy mound of vertex-coloured facets with loose stones on it),
	# its crown just under the anchor block's top so it backs the stop without towering over it.
	_ballast_heap(pk, kit, Vector3(0.0, -0.6, 6.4), 3.2, 2.3, 1.05, 77)
	# Two uprights: an H section each, standing on the slab.
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.75
		pk.block(kit, "steel", Vector3(x - 0.05, -0.25, 0.55), Vector3(x + 0.05, 1.95, 1.05), steel)
		pk.block(kit, "steel", Vector3(x - 0.3, -0.25, 0.5), Vector3(x + 0.3, 1.95, 0.6), steel)
		pk.block(kit, "steel", Vector3(x - 0.3, -0.25, 1.0), Vector3(x + 0.3, 1.95, 1.1), steel)
		# Diagonal brace back to the anchor block.
		pk.beam(kit, "steel", Vector3(x, 1.7, 0.8), Vector3(x, 0.55, 2.6), 0.14, 0.14, steel, Vector3(1, 0, 0))
	# The beam: eight stripes, red and white, over a dark steel back plate, and a dark strip along its top.
	pk.block(kit, "steel", Vector3(-2.15, 0.82, 0.3), Vector3(2.15, 1.42, 0.55), Color(0.16, 0.16, 0.17))
	for k in 8:
		var x0: float = -2.0 + 0.5 * float(k)
		pk.block(kit, "paint", Vector3(x0, 0.86, 0.1), Vector3(x0 + 0.5, 1.38, 0.34), red if k % 2 == 0 else white)
	pk.block(kit, "steel", Vector3(-2.1, 1.38, 0.08), Vector3(2.1, 1.46, 0.5), Color(0.14, 0.14, 0.15))
	# The buffer heads (1.75m apart, as a wagon's) on short stems, with a rim; hydraulic cylinders behind.
	for sx in [-1.0, 1.0]:
		var x2: float = sx * 0.875
		pk.tube(kit, "steel", Vector3(x2, 1.12, 0.1), Vector3(x2, 1.12, -0.12), 0.13, 0.13, 10, Color(0.12, 0.12, 0.13))
		pk.tube(kit, "steel", Vector3(x2, 1.12, -0.12), Vector3(x2, 1.12, -0.2), 0.27, 0.27, 16, Color(0.20, 0.20, 0.21))
		pk.tube(kit, "steel", Vector3(x2, 1.12, -0.2), Vector3(x2, 1.12, -0.24), 0.2, 0.2, 16, Color(0.36, 0.36, 0.38))
		pk.tube(kit, "steel", Vector3(x2, 1.12, 0.55), Vector3(x2, 1.12, 1.9), 0.17, 0.17, 12, Color(0.36, 0.38, 0.40))
		pk.tube(kit, "steel", Vector3(x2, 1.12, 1.9), Vector3(x2, 1.12, 2.55), 0.09, 0.09, 8, Color(0.74, 0.75, 0.77))
		pk.block(kit, "steel", Vector3(x2 - 0.3, 0.8, 2.5), Vector3(x2 + 0.3, 1.44, 2.7), steel)
	# The rails end on the slab, their ends painted white, with a tie bar between them.
	for sx in [-1.0, 1.0]:
		var rx: float = sx * GAUGE_HALF / K
		pk.block(kit, "rail", Vector3(rx - 0.04, -0.12, 0.0), Vector3(rx + 0.04, 0.0, 0.62), RAIL.lightened(0.1))
		pk.block(kit, "paint", Vector3(rx - 0.05, -0.1, 0.5), Vector3(rx + 0.05, 0.02, 0.64), white)
	pk.block(kit, "steel", Vector3(-GAUGE_HALF / K, -0.14, 0.15), Vector3(GAUGE_HALF / K, -0.08, 0.2), steel)
	# The lamp post with its red lamp facing the arriving train, and a plate with the white border.
	pk.tube(kit, "steel", Vector3(2.2, -0.25, 0.9), Vector3(2.2, 2.7, 0.9), 0.06, 0.06, 8, steel)
	pk.block(kit, "steel", Vector3(2.0, 2.6, 0.78), Vector3(2.4, 3.05, 1.02), Color(0.12, 0.12, 0.13))
	pk.tube(kit, "lamp", Vector3(2.2, 2.82, 0.78), Vector3(2.2, 2.82, 0.72), 0.14, 0.14, 12, Color(1.0, 0.12, 0.08), true)
	pk.block(kit, "paint", Vector3(-2.7, 1.7, 0.85), Vector3(-1.9, 2.3, 0.92), white)
	pk.block(kit, "paint", Vector3(-2.64, 1.76, 0.83), Vector3(-1.96, 2.24, 0.9), red.darkened(0.1))
	pk.tube(kit, "steel", Vector3(-2.3, -0.25, 0.9), Vector3(-2.3, 1.75, 0.9), 0.05, 0.05, 8, steel)
