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
const SLEEPER := Color(0.27, 0.21, 0.16)
const RAIL := Color(0.36, 0.25, 0.19)
const RAIL_TOP := Color(0.66, 0.65, 0.63)
const DECK := Color(0.19, 0.18, 0.17)

static var _streams := {}
## While an Array, track_piece and turnout append the triangles they draw (ballast, sleepers, rails) to it: the track's
## solid surface, so a cart runs over the sleepers and the rails (Estación Seca's RailSurface bodies). Null: none.
static var solid_sink = null
## The bed hump's top under the rails' tops (_bed_faces). -0.15 covers the ballast and the sleepers (Mina del Viento,
## whose track mesh is solid anyway); Estación Seca sets -0.4, under the ballast's top (-0.33), so with its solid
## track surface a cart runs over the sleepers and rails while the hump still eases the ballast's steep lower
## shoulders (from 3.3m out).
static var bed_top := -0.15
static var _mats := {}


## Material keys: "ballast" (rail_ballast.gdshader: UV.x/UV.y the metres from each track's centre), "sleeper"
## (hut_wood's squared timber, UVs in metres with the grain along v), "rail" (rusty web, foot and head sides),
## "railtop" (the running surface, polished by the wheels), "dressed" (hut_masonry's stone, UVs in metres: a
## portal's facade), "tunnel" (unshaded: the dark lining of a tunnel),
## "gloom" (unshaded black, alpha from the vertex colour: the veils of darkness inside a tunnel), and CampKit's.
static func make_material(key: String) -> Material:
	var m: StandardMaterial3D
	match key:
		"ballast":
			var b := ShaderMaterial.new()
			b.shader = load("res://rail_ballast.gdshader")
			b.set_shader_parameter("stones_tex", load("res://materials/dark_canyon_rock.png"))
			b.set_shader_parameter("stones_normal", load("res://materials/dark_canyon_rock_normal.png"))
			b.set_shader_parameter("gauge_half", GAUGE_HALF)
			return b
		"sleeper":
			var w := ShaderMaterial.new()
			w.shader = load("res://hut_wood.gdshader")
			w.set_shader_parameter("style", 2)
			w.set_shader_parameter("weathering", 0.75)
			return w
		"rail":
			m = CampKit.make_material("steel")
			m.metallic = 0.25
			m.roughness = 0.8
		"railtop":
			m = CampKit.make_material("metal")
			m.metallic = 0.9
			m.roughness = 0.24
		"dressed":
			var st := ShaderMaterial.new()
			st.shader = load("res://hut_masonry.gdshader")
			st.set_shader_parameter("style", 0)
			return st
		"tunnel":
			m = CampKit.make_material("matte")
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		"gloom":
			m = StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.disable_fog = true
		"deck":
			m = CampKit.make_material("wood")
		"sage_leaf":
			m = StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = true
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.roughness = 0.95
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			m.metallic_specular = 0.15
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			return m
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


## One rail between two points on its top centre line: foot and web as beams, the head as its two sides (rusty)
## and its top, the running surface (bright); `side_vec` is across the rail.
static func _rail_beams(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, side_vec: Vector3, col: Color) -> void:
	pk.beam(kit, "rail", a + Vector3(0, -0.155 * K, 0), b + Vector3(0, -0.155 * K, 0), 0.15 * K, 0.03 * K, col.darkened(0.15), side_vec)
	pk.beam(kit, "rail", a + Vector3(0, -0.095 * K, 0), b + Vector3(0, -0.095 * K, 0), 0.045 * K, 0.1 * K, col, side_vec)
	var s: Vector3 = Vector3(side_vec.x, 0.0, side_vec.z).normalized() * (0.0425 * K)
	var hb := Vector3(0, -0.045 * K, 0)
	pk.quad(kit, "railtop", [a - s, a + s, b + s, b - s], Vector3.UP, RAIL_TOP)
	for sd in [-1.0, 1.0]:
		var o: Vector3 = s * sd
		pk.quad(kit, "rail", [a + o + hb, b + o + hb, b + o, a + o], o.normalized(), col.lightened(0.06))
	pk.quad(kit, "rail", [a - s + hb, b - s + hb, b + s + hb, a + s + hb], Vector3.DOWN, col.darkened(0.2))


## A sleeper: a squared timber `half_len` either side of `c` (its top's middle) along `across`, `half_w` either
## side along `along`, `h` deep, with UVs in metres for hut_wood (the grain along v, the sleeper's length) and
## `u0` shifting each one's grain. The bottom, buried in the ballast, is left out.
static func _sleeper(pk: PropKit, kit: Dictionary, c: Vector3, along: Vector3, across: Vector3, half_len: float, half_w: float, h: float, col: Color, u0: float) -> void:
	var down := Vector3(0, -h, 0)
	var l: Vector3 = across * half_len
	var w: Vector3 = along * half_w
	var t00: Vector3 = c - l - w
	var t10: Vector3 = c + l - w
	var t11: Vector3 = c + l + w
	var t01: Vector3 = c - l + w
	var len2: float = half_len * 2.0
	var wid2: float = half_w * 2.0
	pk.quad(kit, "sleeper", [t00, t10, t11, t01], Vector3.UP, col, [Vector2(u0, 0), Vector2(u0, len2), Vector2(u0 + wid2, len2), Vector2(u0 + wid2, 0)])
	pk.quad(kit, "sleeper", [t00 + down, t10 + down, t10, t00], -along, col.darkened(0.12), [Vector2(u0, 0), Vector2(u0, len2), Vector2(u0 + h, len2), Vector2(u0 + h, 0)])
	pk.quad(kit, "sleeper", [t11 + down, t01 + down, t01, t11], along, col.darkened(0.12), [Vector2(u0, len2), Vector2(u0, 0), Vector2(u0 + h, 0), Vector2(u0 + h, len2)])
	pk.quad(kit, "sleeper", [t10 + down, t11 + down, t11, t10], across, col.darkened(0.2), [Vector2(u0, 0), Vector2(u0 + wid2, 0), Vector2(u0 + wid2, h), Vector2(u0, h)])
	pk.quad(kit, "sleeper", [t01 + down, t00 + down, t00, t01], -across, col.darkened(0.2), [Vector2(u0, 0), Vector2(u0 + wid2, 0), Vector2(u0 + wid2, h), Vector2(u0, h)])


## Collision for a stretch of bedded track between the rail-top points a and b, as triangles appended to `faces`: a low,
## wide hump a cart rolls over, rising 7 degrees from under the ground (0.8m below the rails' tops, 5.4m out from them)
## to 15cm under the rails' tops and level between them; a cart at full speed comes off it about 4 m/s upward, a hop of
## a few tens of centimetres. PlayerCart smooths only the pop off small edges: shorter, steeper ramps (the ballast's
## own shoulders, ramps up to the rails) threw carts crossing a turnout at 33 m/s a metre into the air, and a longer
## 17-degree one launched them like a kicker. The rails' heads stand 15cm proud of it.
static func _bed_faces(faces: Array, a: Vector3, b: Vector3, right_a: Vector3, right_b: Vector3) -> void:
	var foot: float = GAUGE_HALF + 5.4
	var prof: Array = [[-foot, -0.8], [-GAUGE_HALF, bed_top], [GAUGE_HALF, bed_top], [foot, -0.8]]
	for k in range(prof.size() - 1):
		var p0a: Vector3 = a + right_a * float(prof[k][0]) + Vector3(0, float(prof[k][1]), 0)
		var p1a: Vector3 = a + right_a * float(prof[k + 1][0]) + Vector3(0, float(prof[k + 1][1]), 0)
		var p0b: Vector3 = b + right_b * float(prof[k][0]) + Vector3(0, float(prof[k][1]), 0)
		var p1b: Vector3 = b + right_b * float(prof[k + 1][0]) + Vector3(0, float(prof[k + 1][1]), 0)
		faces.append_array([p0a, p1a, p1b, p0a, p1b, p0b])


## A stretch of track along `pts` (rail-top points, the line's own spacing). `bed[i]` says whether segment
## i (pts[i] to pts[i + 1]) has ballast and sleepers; a crossing's has none (its deck is laid over it). With
## `faces`, the bed's collision (see _bed_faces) is appended to it as triangles. Every point's "across" is mitred
## between the segments either side of it (`before` and `after`, when given, are the line's points beyond the piece's
## ends), so on a curve the beds and rails of two segments meet without a gap on the outside or an overlap inside.
static func track_piece(pts: Array, bed: Array, seed_v: int = 0, faces = null, before = null, after = null) -> ArrayMesh:
	var pk := new_kit()
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 77
	var rights: Array = []
	for i in range(pts.size()):
		var pa: Vector3 = pts[i - 1] if i > 0 else (before if before != null else pts[i])
		var pb: Vector3 = pts[i + 1] if i < pts.size() - 1 else (after if after != null else pts[i])
		var dd := Vector3(pb.x - pa.x, 0.0, pb.z - pa.z).normalized()
		rights.append(Vector3(-dd.z, 0.0, dd.x))
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
		var right := Vector3(-dir.z, 0.0, dir.x).normalized()
		var ra: Vector3 = rights[i]
		var rb: Vector3 = rights[i + 1]
		# Both rails: foot, web and head, between the two points.
		for side in [-1.0, 1.0]:
			_rail_beams(pk, kit, a + ra * (side * GAUGE_HALF), b + rb * (side * GAUGE_HALF), right, RAIL)
		if not bed[i]:
			sleeper_at = 0.0
			continue
		if faces != null:
			_bed_faces(faces, a, b, ra, rb)
		# The ballast: a flat top and two sloped shoulders, UV.x the metres across from the track's centre.
		var ya: float = a.y - 0.22 * K
		var yb: float = b.y - 0.22 * K
		var foot_drop := 0.55 * K
		var tl_a := a + ra * -BALLAST_TOP_HALF
		tl_a.y = ya
		var tr_a := a + ra * BALLAST_TOP_HALF
		tr_a.y = ya
		var tl_b := b + rb * -BALLAST_TOP_HALF
		tl_b.y = yb
		var tr_b := b + rb * BALLAST_TOP_HALF
		tr_b.y = yb
		var fl_a := a + ra * -BALLAST_FOOT_HALF
		fl_a.y = ya - foot_drop
		var fr_a := a + ra * BALLAST_FOOT_HALF
		fr_a.y = ya - foot_drop
		var fl_b := b + rb * -BALLAST_FOOT_HALF
		fl_b.y = yb - foot_drop
		var fr_b := b + rb * BALLAST_FOOT_HALF
		fr_b.y = yb - foot_drop
		var col := ballast_colour(a)
		var T := BALLAST_TOP_HALF
		var F := BALLAST_FOOT_HALF
		pk.quad(kit, "ballast", [tl_a, tr_a, tr_b, tl_b], Vector3.UP, col, [Vector2(-T, 99), Vector2(T, 99), Vector2(T, 99), Vector2(-T, 99)])
		var n_left := (right * -1.0 + Vector3.UP * 0.9).normalized()
		var n_right := (right + Vector3.UP * 0.9).normalized()
		pk.quad(kit, "ballast", [fl_a, tl_a, tl_b, fl_b], n_left, col, [Vector2(-F, 99), Vector2(-T, 99), Vector2(-T, 99), Vector2(-F, 99)])
		pk.quad(kit, "ballast", [tr_a, fr_a, fr_b, tr_b], n_right, col, [Vector2(T, 99), Vector2(F, 99), Vector2(F, 99), Vector2(T, 99)])
		# Sleepers, every SLEEPER_SPACING metres along the line.
		while sleeper_at < length:
			var c: Vector3 = a + dir * sleeper_at
			var sy: float = c.y - 0.22 * K
			_sleeper(pk, kit, Vector3(c.x, sy + 0.0525 * K, c.z), dir, right, SLEEPER_HALF, 0.13 * K, 0.085 * K, SLEEPER * (0.85 + rng.randf() * 0.3), rng.randf() * 40.0)
			sleeper_at += SLEEPER_SPACING
		sleeper_at -= length
	if solid_sink is Array:
		(solid_sink as Array).append_array(PropKit.kit_triangles(kit))
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
	# Plank joints across the deck every 1.2m, the flangeways inside the rails and a pale edge strip at each end, their
	# tops 1.2, 2.4 and 3.6cm over the deck: at a few millimetres apart (where joints cross flangeways) they flickered.
	var n := int(half_len * 2.0 / 1.2)
	for k in range(n + 1):
		var p: Vector3 = a + rail_dir * (float(k) * 1.2)
		p.y = top + 0.006
		pk.beam(kit, "deck", p - right * half_w, p + right * half_w, 0.04, 0.012, DECK.darkened(0.45), rail_dir)
	for side in [-1.0, 1.0]:
		var o: Vector3 = right * (side * half_w)
		pk.beam(kit, "deck", slab_a + o + Vector3(0, 0.018, 0), slab_b + o + Vector3(0, 0.018, 0), 0.12, 0.036, Color(0.68, 0.66, 0.60), right)
		# The flangeway: a dark strip just inside each rail.
		var fo: Vector3 = right * (side * (GAUGE_HALF - 0.1))
		pk.beam(kit, "deck", slab_a + fo + Vector3(0, 0.012, 0), slab_b + fo + Vector3(0, 0.012, 0), 0.06, 0.024, Color(0.04, 0.04, 0.04), right)
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


## Wheels over a rail (RailRumble.gd): a short heavy thump, a scrape of grit and the rail's steel ringing briefly.
static func rail_clunk() -> AudioStreamWAV:
	if _streams.has("rail_clunk"):
		return _streams["rail_clunk"]
	const RATE := 22050
	var n: int = int(RATE * 0.32)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in range(n):
		var t: float = float(i) / RATE
		var attack: float = minf(t * 1500.0, 1.0)
		var thump: float = sin(TAU * (95.0 - 40.0 * minf(t * 20.0, 1.0)) * t) * exp(-t * 38.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.35
		var grit: float = lp * exp(-t * 60.0) * 0.6
		var ring: float = (sin(TAU * 1730.0 * t) + 0.6 * sin(TAU * 2610.0 * t + 0.7) + 0.35 * sin(TAU * 3980.0 * t + 1.3)) * exp(-t * 22.0) * 0.22
		out[i] = (thump + grit + ring) * attack
	_streams["rail_clunk"] = _pcm(out, RATE, false, 0.9)
	return _streams["rail_clunk"]


## Wheels over a sleeper in the ballast (RailRumble.gd): a dull wooden knock and a rattle of stones.
static func sleeper_knock() -> AudioStreamWAV:
	if _streams.has("sleeper_knock"):
		return _streams["sleeper_knock"]
	const RATE := 22050
	var n: int = int(RATE * 0.16)
	var rng := RandomNumberGenerator.new()
	rng.seed = 815
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in range(n):
		var t: float = float(i) / RATE
		var knock: float = (sin(TAU * 150.0 * t) + 0.5 * sin(TAU * 236.0 * t)) * exp(-t * 55.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.5
		lp2 += (lp - lp2) * 0.3
		var stones: float = (lp - lp2) * exp(-t * 28.0) * 1.4
		out[i] = (knock + stones) * minf(t * 1200.0, 1.0)
	_streams["sleeper_knock"] = _pcm(out, RATE, false, 0.8)
	return _streams["sleeper_knock"]


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
	var wood_col := Color(0.34, 0.26, 0.19)
	pk.tube(kit, "wood", Vector3(0, 0, 0), Vector3(0, 2.0, 0), 0.30, 0.28, 10, wood_col, true)
	pk.tube(kit, "wood", Vector3(0, 2.0, 0), Vector3(0, 6.0, 0), 0.28, 0.24, 10, wood_col, false)
	pk.tube(kit, "wood", Vector3(0, 6.0, 0), Vector3(0, 11.0, 0), 0.24, 0.20, 10, wood_col, false)
	for y in [10.2, 8.6]:
		pk.beam(kit, "wood", Vector3(-1.5, y, 0), Vector3(1.5, y, 0), 0.16, 0.2, Color(0.30, 0.22, 0.16))
		for sx in [-1.35, -0.45, 0.45, 1.35]:
			pk.tube(kit, "glass", Vector3(sx, y + 0.1, 0), Vector3(sx, y + 0.42, 0), 0.1, 0.07, 8, Color(0.40, 0.62, 0.52, 0.8), true)
	pk.beam(kit, "steel", Vector3(-0.6, 8.6, 0), Vector3(0, 10.0, 0), 0.07, 0.07, Color(0.2, 0.2, 0.2))
	pk.beam(kit, "steel", Vector3(0.6, 8.6, 0), Vector3(0, 10.0, 0), 0.07, 0.07, Color(0.2, 0.2, 0.2))


static func _add_sage_spray(st: SurfaceTool, pos: Vector3, cluster_r: float, rng: RandomNumberGenerator, sage_deep: Color, sage_mid: Color, sage_tip: Color) -> void:
	# 4-way crossed fans per cluster for volumetric density
	for fan_idx in 4:
		var fan_ang: float = float(fan_idx) * PI / 4.0 + rng.randf_range(-0.15, 0.15)
		var fan_dir := Vector3(cos(fan_ang), 0.0, sin(fan_ang))
		var fan_tilt := rng.randf_range(-0.35, 0.35)
		var fan_up := Vector3(0, 1, 0).rotated(fan_dir, fan_tilt)
		var fan_right := fan_dir.cross(fan_up).normalized()
		
		var fan_base: Vector3 = pos + Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03))
		var normal: Vector3 = (fan_base.normalized() + Vector3.UP * 0.7).normalized()
		
		# 3-toothed serrated tridentate fan (Artemisia tridentata)
		for lobe in 3:
			var lobe_offset: float = (float(lobe) - 1.0) * cluster_r * 0.5
			var lobe_h: float = cluster_r * (1.2 if lobe == 1 else 0.95) * rng.randf_range(0.9, 1.1)
			var lobe_w: float = cluster_r * 0.34
			
			var v0 := fan_base + fan_right * (lobe_offset * 0.3)
			var v1 := fan_base + fan_right * (lobe_offset - lobe_w * 0.5) + fan_up * (lobe_h * 0.55)
			var v2 := fan_base + fan_right * (lobe_offset + lobe_w * 0.5) + fan_up * (lobe_h * 0.55)
			var v3 := fan_base + fan_right * lobe_offset + fan_up * lobe_h
			
			# Natural dusty sagebrush colors with sun-bleached tips
			var c_base: Color = sage_deep.lerp(sage_mid, rng.randf_range(0.15, 0.35))
			var c_mid: Color = sage_mid * rng.randf_range(0.95, 1.05)
			var c_tip: Color = sage_tip.lerp(sage_mid, rng.randf_range(0.0, 0.3)) * rng.randf_range(0.98, 1.05)
			
			# Triangle 1: v0, v1, v2
			st.set_normal(normal)
			st.set_color(c_base)
			st.add_vertex(v0)
			st.set_color(c_mid)
			st.add_vertex(v1)
			st.set_color(c_mid)
			st.add_vertex(v2)
			
			# Triangle 2: v1, v3, v2
			st.set_normal(normal)
			st.set_color(c_mid)
			st.add_vertex(v1)
			st.set_color(c_tip)
			st.add_vertex(v3)
			st.set_color(c_mid)
			st.add_vertex(v2)

	# Fluffy horizontal cap triangles
	for cap in 3:
		var cap_r: float = cluster_r * 0.8
		var cap_c: Vector3 = pos + Vector3(rng.randf_range(-0.04, 0.04), cluster_r * 0.45, rng.randf_range(-0.04, 0.04))
		var cap_ang: float = rng.randf() * TAU
		for t in 3:
			var a0: float = cap_ang + float(t) * TAU / 3.0
			var a1: float = a0 + TAU / 3.0
			var p_c: Vector3 = cap_c
			var p_a: Vector3 = cap_c + Vector3(cos(a0), rng.randf_range(-0.03, 0.03), sin(a0)) * cap_r
			var p_b: Vector3 = cap_c + Vector3(cos(a1), rng.randf_range(-0.03, 0.03), sin(a1)) * cap_r
			
			st.set_normal(Vector3.UP)
			st.set_color(sage_mid)
			st.add_vertex(p_c)
			st.set_color(sage_tip)
			st.add_vertex(p_a)
			st.set_color(sage_tip)
			st.add_vertex(p_b)


## A weathered boulder, base on y = 0: an icosphere (two subdivisions, 320 triangles) swollen and dented by noise and
## stretched by `stretch`, its base cut flat where it sits sunk in the ground and, on about half of them, its top cut
## by a bedding plane; smooth normals. The vertex colour is SandstoneKit's (r how shaded: the foot; g desert varnish)
## for canyon_rock.gdshader (`mat`), so the beds run on from the hills' rock. The earlier lumps of flat facets read
## as mushrooms, and the canyon's fallen blocks as bricks on this plain.
static func boulder(seed_v: int, stretch: Vector3, mat: Material) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.7
	noise.fractal_octaves = 3
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 13 + 5
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
		Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in range(verts.size()):
		verts[i] = (verts[i] as Vector3).normalized()
	for _sd in range(2):
		var cache := {}
		var nf: Array = []
		for f in faces:
			var m: Array = []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var key := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
				if not cache.has(key):
					verts.append(((verts[e[0]] as Vector3) + (verts[e[1]] as Vector3)).normalized())
					cache[key] = verts.size() - 1
				m.append(cache[key])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var top: float = rng.randf_range(0.5, 0.75) if rng.randf() < 0.5 else 2.0
	var pts := PackedVector3Array()
	var lo := INF
	var hi := -INF
	for v in verts:
		var d: Vector3 = v
		var r: float = 1.0 + 0.22 * noise.get_noise_3dv(d * 1.1) + 0.06 * noise.get_noise_3dv(d * 3.2 + Vector3(7, 0, 0))
		var p: Vector3 = d * r
		p.y = clampf(p.y, -0.45, top)
		p *= stretch
		pts.append(p)
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in pts:
		var h: float = (p.y - lo) / maxf(hi - lo, 0.01)
		var varnish: float = clampf(0.5 + 0.8 * noise.get_noise_3dv(p * 0.9 + Vector3(0, 30, 0)), 0.0, 1.0) * 0.6
		st.set_color(Color((1.0 - smoothstep(0.0, 0.35, h)) * 0.55, varnish, 0.0))
		st.add_vertex(Vector3(p.x, p.y - lo, p.z))
	for f in faces:
		var a: Vector3 = pts[f[0]]
		var b: Vector3 = pts[f[1]]
		var c: Vector3 = pts[f[2]]
		# Front faces wind clockwise seen from outside (CLAUDE.md): (c - a) x (b - a) points out.
		if (c - a).cross(b - a).dot((a + b + c) / 3.0) > 0.0:
			st.add_index(f[0])
			st.add_index(f[1])
			st.add_index(f[2])
		else:
			st.add_index(f[0])
			st.add_index(f[2])
			st.add_index(f[1])
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## A sagebrush bush (Artemisia tridentata): a gnarled, spreading woody desert shrub with twisting stems,
## dense multi-plane foliage sprays of silvery grey-green leaves with sunlit straw tips, and dead dry twigs
## poking through. About 1.5m across and 0.75m tall.
static func sage(seed_v: int) -> ArrayMesh:
	var pk := new_kit()
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	
	var wood_col := Color(0.38, 0.32, 0.24)
	var leaf_st: SurfaceTool = pk.st(kit, "sage_leaf")
	
	# Dusty desert sagebrush palette (silvery-grey green with straw highlights)
	var sage_deep := Color(0.32, 0.38, 0.28)
	var sage_mid := Color(0.48, 0.55, 0.42)
	var sage_tip := Color(0.66, 0.65, 0.48)
	
	# 9 to 12 main gnarled woody branches radiating out into a compact, bushy dome
	var num_branches := rng.randi_range(9, 12)
	var foliage_spots: Array = []
	
	for b in num_branches:
		var ang := TAU * float(b) / float(num_branches) + rng.randf_range(-0.2, 0.2)
		var reach := rng.randf_range(0.45, 0.82)
		var h := rng.randf_range(0.38, 0.68)
		
		var p0 := Vector3(rng.randf_range(-0.08, 0.08), -0.02, rng.randf_range(-0.08, 0.08))
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var mid_reach := reach * rng.randf_range(0.42, 0.58)
		var p1 := p0 + dir * mid_reach + Vector3(0, h * rng.randf_range(0.45, 0.6), 0) + Vector3(rng.randf_range(-0.06, 0.06), 0, rng.randf_range(-0.06, 0.06))
		var p2 := p0 + dir * reach + Vector3(0, h, 0)
		
		# Gnarled stem
		pk.tube(kit, "wood", p0, p1, 0.042, 0.026, 4, wood_col, true)
		pk.tube(kit, "wood", p1, p2, 0.026, 0.015, 3, wood_col.lightened(0.08), true)
		
		# Foliage along branch: both at mid and at tip
		foliage_spots.append({"pos": p1 + Vector3(0, 0.05, 0), "r": rng.randf_range(0.24, 0.32)})
		foliage_spots.append({"pos": p2, "r": rng.randf_range(0.26, 0.36)})
		
		# Secondary twigs branching out
		for tw in range(rng.randi_range(1, 2)):
			var tw_ang := ang + rng.randf_range(-0.7, 0.7)
			var tw_dir := Vector3(cos(tw_ang), 0.0, sin(tw_ang))
			var tw_reach := reach * rng.randf_range(0.7, 1.05)
			var tw_h := h * rng.randf_range(0.65, 0.95)
			var tw_tip := p1 + tw_dir * (tw_reach - mid_reach) + Vector3(0, tw_h - p1.y, 0)
			pk.tube(kit, "wood", p1, tw_tip, 0.02, 0.01, 3, wood_col.lightened(0.12), true)
			foliage_spots.append({"pos": tw_tip, "r": rng.randf_range(0.22, 0.30)})
			
			# Occasional dry stick protruding
			if rng.randf() < 0.4:
				var stick_tip := tw_tip + (tw_dir + Vector3(0, 0.6, 0)).normalized() * rng.randf_range(0.12, 0.22)
				pk.tube(kit, "wood", tw_tip, stick_tip, 0.01, 0.004, 3, wood_col.lightened(0.22), true)
	
	# Center crown foliage to fill the core dome
	for c_idx in 4:
		var c_ang := TAU * float(c_idx) / 4.0 + rng.randf_range(-0.3, 0.3)
		var c_dist := rng.randf_range(0.08, 0.22)
		var c_pos := Vector3(cos(c_ang) * c_dist, rng.randf_range(0.35, 0.55), sin(c_ang) * c_dist)
		foliage_spots.append({"pos": c_pos, "r": rng.randf_range(0.28, 0.38)})

	# Build all foliage sprays
	for spot in foliage_spots:
		_add_sage_spray(leaf_st, spot["pos"], spot["r"], rng, sage_deep, sage_mid, sage_tip)

	return pk.commit(kit)


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


## A tunnel portal closing the end of a cutting: a stone facade with a segmental arch (8.4m wide, its crown 8.9m over
## the rail), a central bay 16m wide and 15m high between two pilasters, and wings out to either side whose tops
## follow the hill behind them (`wing_l`, `wing_r`: [metres out, height over the rail] from the bay's edge outward;
## left empty, a wing slopes straight down to 1m at 24.5m). Then a vaulted lining running 24m into the hill, unshaded
## so no sunlight or sky reaches into it, from dim stone at the mouth to black, with a weak lamp on each wall every 6m,
## and a black plug at its end. The facade's front face is on z = 0, its back on z = 3.4 (PORTAL_BACK); x across, y
## up from the rail's top. `tunnel_fog` adds the veils a train fades into; the generator keeps the hill clear of the
## lining and covering it.
const PORTAL_HW := 4.2
const PORTAL_SPRING := 7.0
const PORTAL_CROWN := 8.9
const PORTAL_BAY := 8.0
const PORTAL_TOP := 15.0
const PORTAL_BACK := 3.4
const PORTAL_DEPTH := 24.0
const PORTAL_WING_END := 24.5
const PORTAL_STONE := Color(0.62, 0.57, 0.49)


## The arch's section (the opening's outline from the left springing over to the right) and its circle.
static func _portal_arch() -> Dictionary:
	var hw := PORTAL_HW
	var rise: float = PORTAL_CROWN - PORTAL_SPRING
	var rr: float = (hw * hw + rise * rise) / (2.0 * rise)
	var cy: float = PORTAL_CROWN - rr
	var arch: Array = []
	const ARCH_N := 18
	for k in range(ARCH_N + 1):
		var x: float = -hw + 2.0 * hw * float(k) / float(ARCH_N)
		arch.append(Vector2(x, cy + sqrt(rr * rr - x * x)))
	return {"rr": rr, "cy": cy, "arch": arch}


## The lining's cross-section, a closed loop: the arch with a floor under the track.
static func _portal_section() -> Array:
	var section: Array = [Vector2(-PORTAL_HW, -0.45)]
	section.append_array(_portal_arch()["arch"])
	section.append(Vector2(PORTAL_HW, -0.45))
	return section


static func portal(pk: PropKit, kit: Dictionary, wing_l: Array = [], wing_r: Array = [], top := PORTAL_TOP) -> void:
	var stone := PORTAL_STONE
	var hw := PORTAL_HW
	var bay := PORTAL_BAY
	var ad: Dictionary = _portal_arch()
	var rr: float = ad["rr"]
	var cy: float = ad["cy"]
	var arch: Array = ad["arch"]
	var left: Array = wing_l if not wing_l.is_empty() else [[PORTAL_WING_END, 1.0]]
	var right: Array = wing_r if not wing_r.is_empty() else [[PORTAL_WING_END, 1.0]]
	var end_l: float = left[left.size() - 1][0]
	var end_r: float = right[right.size() - 1][0]
	# The facade's outline: the opening cut from the bottom edge, the bay's flat top, the wings' tops.
	var outline := PackedVector2Array([Vector2(-end_l, -0.8), Vector2(-hw, -0.8)])
	for p in arch:
		outline.append(p)
	outline.append(Vector2(hw, -0.8))
	outline.append(Vector2(end_r, -0.8))
	for k in range(right.size() - 1, -1, -1):
		outline.append(Vector2(right[k][0], right[k][1]))
	outline.append(Vector2(bay, top))
	outline.append(Vector2(-bay, top))
	for k in range(left.size()):
		outline.append(Vector2(-float(left[k][0]), float(left[k][1])))
	# Dressed stone in big courses (hut_masonry's rubble at 0.55: blocks about a metre across), clear of its moss.
	pk.extrude(kit, "dressed", outline, 0.0, PORTAL_BACK, 0.0, stone, Callable(), 0.55, Vector2(0.0, 3.0))
	# The arch ring of voussoirs, a little proud of the facade, alternating light and dark.
	var a0: float = atan2(PORTAL_SPRING - cy, -hw)
	var a1: float = atan2(PORTAL_SPRING - cy, hw)
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
			# The ring's soffit, back to the facade's face.
			pk.quad(kit, "matte", [prev_in, pin, pin + Vector3(0, 0, 0.1), prev_in + Vector3(0, 0, 0.1)], -(Vector3(pin.x, pin.y - cy, 0.0)).normalized(), col.darkened(0.1))
		prev_in = pin
		prev_out = pout
	# Keystone, a string course across the bay, two pilasters either side of the arch and a coping along the top (their
	# stones offset clear of the masonry shader's moss, which grows at the foot of v).
	var mossless := Vector2(0.0, 3.0)
	pk.block(kit, "dressed", Vector3(-0.7, PORTAL_CROWN - 0.1, -0.3), Vector3(0.7, PORTAL_CROWN + 1.35, 0.1), stone.lightened(0.24), 0.55, mossless)
	pk.block(kit, "dressed", Vector3(-bay - 0.3, 11.0, -0.3), Vector3(bay + 0.3, 11.35, 0.1), stone.lightened(0.14), 0.55, mossless)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "dressed", Vector3(sx * 6.6 - 0.6, -0.8, -0.35), Vector3(sx * 6.6 + 0.6, top, 0.1), stone.lightened(0.07), 0.55, mossless)
		pk.block(kit, "dressed", Vector3(sx * 6.6 - 0.8, top - 0.1, -0.5), Vector3(sx * 6.6 + 0.8, top + 0.3, 0.2), stone.lightened(0.2), 0.55, mossless)
	pk.beam(kit, "matte", Vector3(-bay, top + 0.1, 1.7), Vector3(bay, top + 0.1, 1.7), 4.0, 0.5, stone.lightened(0.14), Vector3(0, 0, 1))
	# The wings' coping, along their tops, overhanging the wing's end a little (flush, its end shared the wall's plane).
	for wing in [[left, -1.0], [right, 1.0]]:
		var pts: Array = wing[0]
		var sg: float = wing[1]
		var prev := Vector3(sg * bay, top + 0.1, 1.7)
		for k in range(pts.size()):
			var cur := Vector3(sg * float(pts[k][0]), float(pts[k][1]) + 0.1, 1.7)
			if k == pts.size() - 1:
				cur += (cur - prev).normalized() * 0.15
			pk.beam(kit, "matte", prev, cur, 4.0, 0.5, stone.lightened(0.14), Vector3(0, 0, 1))
			prev = cur
	# The lining: the arch's section lofted along z from the back of the facade, shading to black.
	var section: Array = _portal_section()
	const SLICES := 10
	for sl in range(SLICES):
		var z0: float = PORTAL_BACK + PORTAL_DEPTH * float(sl) / float(SLICES)
		var z1: float = PORTAL_BACK + PORTAL_DEPTH * float(sl + 1) / float(SLICES)
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
			pk.tri(kit, "tunnel", Vector3(pa.x, pa.y, z0), Vector3(pb.x, pb.y, z0), Vector3(pb.x, pb.y, z1), n3, n3, n3, c0, n3)
			pk.tri(kit, "tunnel", Vector3(pa.x, pa.y, z0), Vector3(pb.x, pb.y, z1), Vector3(pa.x, pa.y, z1), n3, n3, n3, c1, n3)
	# The black end: a plug filling the section.
	var zend: float = PORTAL_BACK + PORTAL_DEPTH
	var plug_c := Vector3(0.0, 3.5, zend)
	for k in range(section.size()):
		var k2: int = (k + 1) % section.size()
		pk.tri(kit, "tunnel", plug_c, Vector3(section[k].x, section[k].y, zend), Vector3(section[k2].x, section[k2].y, zend),
				Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1), Color(0, 0, 0), Vector3(0, 0, -1))
	# Lamps on both walls, weak and warm.
	for lz in [6.0, 12.0, 18.0]:
		for sx in [-1.0, 1.0]:
			pk.block(kit, "lamp", Vector3(sx * (hw - 0.12) - 0.1, 5.2, lz - 0.2), Vector3(sx * (hw - 0.12) + 0.1, 5.7, lz + 0.2), Color(0.55, 0.42, 0.24))


## The lining's colour at `t` (0 at the facade, 1 at the black end), for the unshaded lining: dim stone at the mouth
## falling off to nothing within a third of the way in.
static func _tunnel_shade(t: float) -> Color:
	var v: float = 0.3 * pow(maxf(1.0 - t * 1.6, 0.0), 2.2)
	return Color(v * 1.05, v, v * 0.92)


## The darkness inside a portal's lining (its own mesh, in the portal's frame, with the "gloom" material): black veils
## across the section, more opaque the deeper they stand, so a train running in fades into the dark instead of
## staying lit by the sky all the way to the plug. Each veil faces the mouth.
static func tunnel_fog(pk: PropKit, kit: Dictionary) -> void:
	var section: Array = _portal_section()
	var veils: Array = [[1.2, 0.22], [3.0, 0.3], [5.5, 0.38], [8.5, 0.46], [12.5, 0.56], [17.5, 0.7]]
	var centre := Vector2(0.0, 3.6)
	for v in veils:
		var z: float = PORTAL_BACK + float(v[0])
		var col := Color(0.0, 0.0, 0.0, float(v[1]))
		for k in range(section.size()):
			var k2: int = (k + 1) % section.size()
			var pa: Vector2 = section[k]
			var pb: Vector2 = section[k2]
			pk.tri(kit, "gloom", Vector3(centre.x, centre.y, z), Vector3(pa.x, pa.y, z), Vector3(pb.x, pb.y, z),
					Vector3(0, 0, -1), Vector3(0, 0, -1), Vector3(0, 0, -1), col, Vector3(0, 0, -1))



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
## far along the through track the tracks are too close for beds of their own; the shared bed runs TURNOUT_OVERLAP
## beyond it, under the tracks' own beds (3cm lower, so the two never share a plane), and the branch's rails run
## TURNOUT_RAILS beyond it, to the sample the branch's own track starts from. With `faces`, the collision (both
## tracks' humps, see _bed_faces) is appended to it.
const TURNOUT_OVERLAP := 4.5
const TURNOUT_RAILS := 3.0

static func turnout(through: Array, branch: Array, side: float, info: Dictionary = {}, faces = null) -> ArrayMesh:
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
	# --- Ballast and sleepers over the whole width, from the through track's far side to the branch's far rail. UV.x is
	# the metres across from the through track's centre, UV.y from the branch's, for the stains between the rails.
	var step := 1.5
	var tt := -1.5
	var rows_b: Array = []
	while tt <= t_end + TURNOUT_OVERLAP + 0.01:
		var lat: float = _table_at(lat_rows, tt)
		var y: float = _table_at(ty, tt)
		rows_b.append([tt, lat, y])
		tt += step
	for i in range(rows_b.size() - 1):
		var r0: Array = rows_b[i]
		var r1: Array = rows_b[i + 1]
		var pts_top: Array = []
		var pts_foot: Array = []
		var uvs_top: Array = []
		var uvs_foot: Array = []
		for rr in [r0, r1]:
			var c: Vector3 = a + dir * float(rr[0])
			var ylev: float = float(rr[2]) - 0.22 * K - 0.03
			var bl: float = side * float(rr[1])
			var lo: float = -BALLAST_TOP_HALF - (float(rr[1]) if side < 0.0 else 0.0)
			var hi: float = BALLAST_TOP_HALF + (float(rr[1]) if side > 0.0 else 0.0)
			var flo: float = lo - (BALLAST_FOOT_HALF - BALLAST_TOP_HALF)
			var fhi: float = hi + (BALLAST_FOOT_HALF - BALLAST_TOP_HALF)
			pts_top.append([Vector3(c.x, ylev, c.z) + right * lo, Vector3(c.x, ylev, c.z) + right * hi])
			pts_foot.append([Vector3(c.x, ylev - 0.55 * K, c.z) + right * flo, Vector3(c.x, ylev - 0.55 * K, c.z) + right * fhi])
			uvs_top.append([Vector2(lo, lo - bl), Vector2(hi, hi - bl)])
			uvs_foot.append([Vector2(flo, flo - bl), Vector2(fhi, fhi - bl)])
		var col := ballast_colour(a + dir * float(r0[0]))
		pk.quad(kit, "ballast", [pts_top[0][0], pts_top[0][1], pts_top[1][1], pts_top[1][0]], Vector3.UP, col,
				[uvs_top[0][0], uvs_top[0][1], uvs_top[1][1], uvs_top[1][0]])
		pk.quad(kit, "ballast", [pts_foot[0][0], pts_top[0][0], pts_top[1][0], pts_foot[1][0]], (-right + Vector3.UP * 0.9).normalized(), col,
				[uvs_foot[0][0], uvs_top[0][0], uvs_top[1][0], uvs_foot[1][0]])
		pk.quad(kit, "ballast", [pts_top[0][1], pts_foot[0][1], pts_foot[1][1], pts_top[1][1]], (right + Vector3.UP * 0.9).normalized(), col,
				[uvs_top[0][1], uvs_foot[0][1], uvs_foot[1][1], uvs_top[1][1]])
	var sleeper_t := 0.4 * K
	var srng := RandomNumberGenerator.new()
	srng.seed = 31
	while sleeper_t < t_end:
		var lat2: float = _table_at(lat_rows, sleeper_t)
		var y2: float = _table_at(ty, sleeper_t)
		var lo2: float = -SLEEPER_HALF - (lat2 if side < 0.0 else 0.0)
		var hi2: float = SLEEPER_HALF + (lat2 if side > 0.0 else 0.0)
		var c2: Vector3 = a + dir * sleeper_t
		var ctr := Vector3(c2.x, y2 - 0.22 * K + 0.0525 * K, c2.z) + right * ((lo2 + hi2) * 0.5)
		_sleeper(pk, kit, ctr, dir, right, (hi2 - lo2) * 0.5, 0.13 * K, 0.085 * K, SLEEPER * (0.85 + srng.randf() * 0.3), srng.randf() * 40.0)
		sleeper_t += SLEEPER_SPACING
	# --- Collision: the through track's hump and the branch's, along each.
	if faces != null:
		for i in range(through.size() - 1):
			var p0: Vector3 = through[i]
			var p1: Vector3 = through[i + 1]
			if Vector3(p0.x - a.x, 0.0, p0.z - a.z).dot(dir) > t_end + TURNOUT_OVERLAP:
				break
			_bed_faces(faces, p0, p1, right, right)
		for i in range(bs.size() - 1):
			if float(bs[i + 1]["t"]) > t_end + TURNOUT_RAILS:
				break
			_bed_faces(faces, bs[i]["p"], bs[i + 1]["p"], bs[i]["r"], bs[i + 1]["r"])
	# --- The branch's rails: both start on the through rails (a hair higher where the blades lie against them, so they
	# do not fight; level again by 12m, so they meet the branch's own track without a step) and part from them.
	var inner_pts: Array = []
	for i in range(bs.size()):
		var b: Dictionary = bs[i]
		if float(b["t"]) > t_end + TURNOUT_RAILS:
			break
		var blade: bool = float(b["t"]) < 9.0
		var col_r: Color = BLADE if blade else RAIL
		if i + 1 < bs.size() and float(bs[i + 1]["t"]) <= t_end + TURNOUT_RAILS:
			var n: Dictionary = bs[i + 1]
			var lift_a := Vector3(0, 0.012 * K * (1.0 - smoothstep(6.0, 12.0, float(b["t"]))), 0)
			var lift_b := Vector3(0, 0.012 * K * (1.0 - smoothstep(6.0, 12.0, float(n["t"]))), 0)
			for sd in [-1.0, 1.0]:
				var pa: Vector3 = (b["p"] as Vector3) + (b["r"] as Vector3) * (sd * GAUGE_HALF) + lift_a
				var pb: Vector3 = (n["p"] as Vector3) + (n["r"] as Vector3) * (sd * GAUGE_HALF) + lift_b
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
	# Where the stand is, for its collider (the bed's mesh has none of its own): its base's middle, its height, the
	# lever's reach and the track's heading.
	info["stand"] = Vector3(st.x, base_y, st.z)
	info["stand_h"] = 1.62 * K
	info["stand_reach"] = 0.9 * K
	info["stand_dir"] = dir
	info["stand_out"] = right * (-side)
	if solid_sink is Array:
		(solid_sink as Array).append_array(PropKit.kit_triangles(kit))
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
			# UVs far from any rail: no oil or rust stains on the heap.
			var off := Vector2(99, 99)
			if i == 0:
				pk.tri(kit, "ballast", a0, a1, b1, n, n, n, col, n, off, off, off)
			else:
				pk.quad(kit, "ballast", [a0, b0, b1, a1], n, col, [off, off, off, off])
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
		pk.box(kit, "matte", Transform3D(basis, p), Vector3(sz * 1.3, sz * 0.8, sz), Color(g, g * 0.97, g * 0.9))


const BUFFER_PLATE := [Vector3(-2.3, 2.26, 0.78), 1.45]

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
	# The plate the generator letters FIN DE VIA on (BUFFER_PLATE: its middle and inner width), over the upright's top.
	pk.block(kit, "paint", Vector3(-3.15, 2.0, 0.85), Vector3(-1.45, 2.52, 0.92), white)
	pk.block(kit, "paint", Vector3(-3.09, 2.06, 0.83), Vector3(-1.51, 2.46, 0.9), red.darkened(0.1))
	pk.tube(kit, "steel", Vector3(-2.3, -0.25, 0.9), Vector3(-2.3, 2.02, 0.9), 0.05, 0.05, 8, steel)
