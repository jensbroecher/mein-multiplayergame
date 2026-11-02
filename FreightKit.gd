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
		var dir: Vector3 = d / length
		var right := Vector3(-dir.z, 0.0, dir.x)
		# Both rails: foot, web and head, as beams between the two points.
		for side in [-1.0, 1.0]:
			var o: Vector3 = right * (side * GAUGE_HALF)
			pk.beam(kit, "rail", a + o + Vector3(0, -0.155 * K, 0), b + o + Vector3(0, -0.155 * K, 0), 0.15 * K, 0.03 * K, RAIL, right)
			pk.beam(kit, "rail", a + o + Vector3(0, -0.095 * K, 0), b + o + Vector3(0, -0.095 * K, 0), 0.045 * K, 0.1 * K, RAIL, right)
			pk.beam(kit, "rail", a + o + Vector3(0, -0.0225 * K, 0), b + o + Vector3(0, -0.0225 * K, 0), 0.085 * K, 0.045 * K, RAIL.lightened(0.18), right)
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
		var col := BALLAST * (0.9 + rng.randf() * 0.2)
		col.a = 1.0
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
#  The depot
# ======================================================================================

const CREAM := Color(0.86, 0.79, 0.64)
const TILE := Color(0.56, 0.21, 0.14)
const STONE := Color(0.52, 0.50, 0.46)
const CONCRETE := Color(0.78, 0.77, 0.73)
const WOOD_DARK := Color(0.30, 0.20, 0.13)
const GLASS_DARK := Color(0.07, 0.11, 0.15, 0.9)


## Estación del Viento, built along +x from the origin with its front on z = 0 facing +z (toward the road),
## 44m long, 14m deep: a stone plinth, cream walls, a tiled gable roof, a veranda on posts, windows and
## doors, and a clock tower. Life size; the generator places it.
static func depot(pk: PropKit, kit: Dictionary) -> void:
	var L := 44.0
	var D := 14.0
	pk.block(kit, "matte", Vector3(-0.4, 0, -D - 0.4), Vector3(L + 0.4, 0.9, 0.4), STONE)
	pk.block(kit, "paint", Vector3(0, 0.9, -D), Vector3(L, 6.4, 0), CREAM)
	# Roof: two tiled slopes and the gable ends.
	var rise := 3.4
	pk.beam(kit, "paint", Vector3(L * 0.5, 6.4, 1.0), Vector3(L * 0.5, 6.4 + rise, -D * 0.5), L + 2.4, 0.4, TILE, Vector3.RIGHT)
	pk.beam(kit, "paint", Vector3(L * 0.5, 6.4, -D - 1.0), Vector3(L * 0.5, 6.4 + rise, -D * 0.5), L + 2.4, 0.4, TILE, Vector3.RIGHT)
	for sx in [0.0, L]:
		var n := Vector3(1 if sx > 0.0 else -1, 0, 0)
		pk.tri(kit, "paint", Vector3(sx, 6.4, 0.0), Vector3(sx, 6.4, -D), Vector3(sx, 6.4 + rise, -D * 0.5), n, n, n, CREAM, n)
	# The veranda: a raised walk, a low roof and posts.
	pk.block(kit, "matte", Vector3(-1.0, 0, 0), Vector3(L + 1.0, 0.45, 3.8), CONCRETE)
	pk.beam(kit, "paint", Vector3(L * 0.5, 5.0, 0.2), Vector3(L * 0.5, 5.5, 4.2), L + 2.0, 0.25, TILE.darkened(0.15), Vector3.RIGHT)
	var x := 1.0
	while x < L:
		pk.block(kit, "wood", Vector3(x - 0.17, 0.45, 3.4), Vector3(x + 0.17, 5.2, 3.74), Color(0.90, 0.88, 0.82))
		x += 4.0
	# Windows and doors on the front: glass set a little proud with a white frame.
	var wx := 3.0
	while wx < L - 3.0:
		var door: bool = absf(wx - L * 0.5) < 5.0
		var w := 2.2 if not door else 3.0
		var y0 := 1.7 if not door else 0.9
		var y1 := 4.5 if not door else 4.2
		pk.block(kit, "paint", Vector3(wx - w * 0.5 - 0.15, y0 - 0.15, 0.0), Vector3(wx + w * 0.5 + 0.15, y1 + 0.15, 0.1), Color(0.94, 0.93, 0.9))
		pk.block(kit, "glass" if not door else "wood", Vector3(wx - w * 0.5, y0, 0.08), Vector3(wx + w * 0.5, y1, 0.14), GLASS_DARK if not door else WOOD_DARK)
		wx += 5.0 if not door else 6.0
	# The clock tower over the middle.
	pk.block(kit, "paint", Vector3(L * 0.5 - 3.0, 6.4, -D * 0.5 - 3.0), Vector3(L * 0.5 + 3.0, 14.0, -D * 0.5 + 3.0), CREAM)
	pk.block(kit, "paint", Vector3(L * 0.5 - 3.4, 14.0, -D * 0.5 - 3.4), Vector3(L * 0.5 + 3.4, 14.5, -D * 0.5 + 3.4), TILE.darkened(0.2))
	pk.lathe(kit, "paint", Vector3(L * 0.5, 14.5, -D * 0.5), [Vector2(4.3, 0.0), Vector2(3.2, 1.3), Vector2(1.6, 3.2), Vector2(0.001, 5.4)], 4, TILE, true, Basis(Vector3.UP, PI * 0.25))
	for sz in [-1.0, 1.0]:
		var zc: float = -D * 0.5 + sz * 3.04
		pk.tube(kit, "paint", Vector3(L * 0.5, 11.2, zc), Vector3(L * 0.5, 11.2, zc + sz * 0.12), 2.0, 2.0, 24, Color(0.95, 0.94, 0.88))
		pk.beam(kit, "steel", Vector3(L * 0.5, 11.2, zc + sz * 0.14), Vector3(L * 0.5, 12.5, zc + sz * 0.14), 0.12, 0.05, DARK_HAND)
		pk.beam(kit, "steel", Vector3(L * 0.5, 11.2, zc + sz * 0.14), Vector3(L * 0.5 + 0.95, 11.5, zc + sz * 0.14), 0.12, 0.05, DARK_HAND)
	# A freight shed at the east end: a long low roof on posts over a loading dock.
	pk.block(kit, "matte", Vector3(L + 1.0, 0, -D), Vector3(L + 22.0, 1.3, 0.0), CONCRETE)
	pk.beam(kit, "paint", Vector3(L + 11.5, 5.2, 1.0), Vector3(L + 11.5, 6.6, -D - 1.0), 24.0, 0.3, Color(0.44, 0.46, 0.46), Vector3.RIGHT)
	for px in [L + 2.0, L + 8.0, L + 14.0, L + 20.0]:
		for pz in [-0.6, -D + 0.6]:
			pk.block(kit, "steel", Vector3(px - 0.2, 1.3, pz - 0.2), Vector3(px + 0.2, 5.4, pz + 0.2), Color(0.30, 0.31, 0.30))
	# Luggage and crates on the platform.
	for k in 5:
		pk.block(kit, "wood", Vector3(5.0 + k * 7.3, 0.45, 2.0), Vector3(6.4 + k * 7.3, 1.5 + (k % 2) * 0.4, 3.0), Color(0.54, 0.42, 0.28))


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


## Grain silos: three concrete cylinders with domed tops and a head house with a conveyor, life size,
## origin on the ground at the first silo, silos along +x.
static func silos(pk: PropKit, kit: Dictionary) -> void:
	for k in 3:
		var c := Vector3(k * 10.4, 0, 0)
		pk.tube(kit, "paint", c, c + Vector3(0, 22.0, 0), 5.0, 5.0, 24, CONCRETE.darkened(k * 0.03), false)
		pk.lathe(kit, "paint", c + Vector3(0, 22.0, 0), [Vector2(5.0, 0.0), Vector2(4.6, 0.9), Vector2(3.0, 1.9), Vector2(1.0, 2.5), Vector2(0.001, 2.6)], 24, CONCRETE.lightened(0.05), false)
		for h in [4.0, 9.0, 14.0, 19.0]:
			pk.tube(kit, "paint", c + Vector3(0, h, 0), c + Vector3(0, h + 0.18, 0), 5.06, 5.06, 24, CONCRETE.darkened(0.14), false)
	# The head house stands behind them (-z), with the conveyor to a hopper; a low office with the sign in front.
	pk.block(kit, "paint", Vector3(-3.0, 0, -11.0), Vector3(24.0, 26.0, -6.2), CONCRETE.darkened(0.06))
	pk.block(kit, "paint", Vector3(-3.4, 26.0, -11.4), Vector3(24.4, 27.0, -5.8), Color(0.30, 0.32, 0.34))
	pk.beam(kit, "steel", Vector3(21.0, 26.5, -8.5), Vector3(40.0, 4.0, -8.5), 1.6, 0.9, Color(0.36, 0.38, 0.38))
	pk.beam(kit, "steel", Vector3(40.0, 0.0, -8.5), Vector3(40.0, 4.2, -8.5), 0.5, 0.5, Color(0.3, 0.3, 0.3))
	pk.block(kit, "paint", Vector3(36.0, 0.0, -12.0), Vector3(44.0, 4.0, -5.0), Color(0.62, 0.30, 0.18))
	pk.block(kit, "paint", Vector3(2.0, 0.0, 5.6), Vector3(19.0, 5.2, 11.0), Color(0.90, 0.86, 0.74))
	pk.block(kit, "paint", Vector3(1.4, 5.2, 5.0), Vector3(19.6, 5.5, 11.6), TILE)
	pk.block(kit, "glass", Vector3(4.0, 1.4, 10.98), Vector3(7.0, 3.6, 11.04), GLASS_DARK)
	pk.block(kit, "wood", Vector3(13.0, 0.0, 10.98), Vector3(15.5, 3.4, 11.06), WOOD_DARK)


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


## A boulder: a displaced, flattened sphere in sun-bleached sandstone, about 1m across at scale 1.
static func rock(seed_v: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 1.3
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 7
	var arrays: Array = sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	var base := Color(0.58 + rng.randf() * 0.08, 0.46 + rng.randf() * 0.06, 0.36 + rng.randf() * 0.05)
	for i in range(verts.size()):
		var v: Vector3 = verts[i]
		var n: float = noise.get_noise_3dv(v * 2.0 + Vector3(seed_v, 0, 0))
		v *= 1.0 + n * 0.45
		v.y = maxf(v.y, -0.12) * 0.8
		verts[i] = v
		cols.append(base * (0.88 + 0.2 * (v.y + 0.3)))
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var st := SurfaceTool.new()
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.create_from(tmp, 0)
	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	mesh.surface_set_material(0, m)
	return mesh


## A tunnel portal: a masonry wall 28m wide and 12.5m high with an arched opening 8.4m wide (the arch's
## crown 8.9m over the rails), a dark lining running 26m into the hill behind it, and a keystone. The
## wall's front face is on z = 0 and the lining runs toward +z; x across, y up from the rail's top. The
## trains drive into the lining and on, under the hill, where its terrain hides them.
static func portal(pk: PropKit, kit: Dictionary) -> void:
	var stone := Color(0.60, 0.55, 0.48)
	var outline := PackedVector2Array([Vector2(-14.0, -0.8), Vector2(-4.2, -0.8), Vector2(-4.2, 7.2)])
	var rr := (4.2 * 4.2 + 1.7 * 1.7) / (2.0 * 1.7)
	var cy := 8.9 - rr
	for k in range(1, 12):
		var x: float = -4.2 + 8.4 * float(k) / 12.0
		outline.append(Vector2(x, cy + sqrt(rr * rr - x * x)))
	outline.append_array(PackedVector2Array([Vector2(4.2, 7.2), Vector2(4.2, -0.8), Vector2(14.0, -0.8), Vector2(14.0, 12.5), Vector2(-14.0, 12.5)]))
	pk.extrude(kit, "matte", outline, 0.0, 3.4, 0.0, stone, func(p: Vector3, n: Vector3) -> Color:
		# Courses of stone: every 0.9m a slightly different shade.
		var course: int = int(floor(p.y / 0.9))
		return stone * (0.88 + 0.08 * float((course * 7) % 3))
	)
	# Cornice along the top and a keystone over the crown.
	pk.block(kit, "matte", Vector3(-14.4, 12.5, -0.4), Vector3(14.4, 13.2, 3.8), stone.lightened(0.12))
	pk.block(kit, "matte", Vector3(-0.8, 8.7, -0.35), Vector3(0.8, 10.2, 0.2), stone.lightened(0.2))
	# The lining: inward-facing dark panels.
	var dark := Color(0.015, 0.015, 0.018)
	var hw := 4.4
	var top := 9.2
	var depth := 26.0
	var fl := -0.4
	pk.quad(kit, "matte", [Vector3(-hw, fl, 0), Vector3(hw, fl, 0), Vector3(hw, fl, depth), Vector3(-hw, fl, depth)], Vector3.UP, dark)
	pk.quad(kit, "matte", [Vector3(-hw, top, 0), Vector3(-hw, top, depth), Vector3(hw, top, depth), Vector3(hw, top, 0)], Vector3.DOWN, dark)
	pk.quad(kit, "matte", [Vector3(-hw, fl, 0), Vector3(-hw, fl, depth), Vector3(-hw, top, depth), Vector3(-hw, top, 0)], Vector3.RIGHT, dark)
	pk.quad(kit, "matte", [Vector3(hw, fl, 0), Vector3(hw, top, 0), Vector3(hw, top, depth), Vector3(hw, fl, depth)], Vector3.LEFT, dark)
	pk.quad(kit, "matte", [Vector3(-hw, fl, depth), Vector3(hw, fl, depth), Vector3(hw, top, depth), Vector3(-hw, top, depth)], Vector3.FORWARD * -1.0 * -1.0, dark)


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
