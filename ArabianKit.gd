extends RefCounted
## The Al-Raihana GP's buildings and set pieces (Mountain Pass, Desert Wadi), built through a PropKit at life
## size (y up, the front toward -z) and grown by the caller (PROP_SCALE 1.6, as on every stage). A fictional
## Gulf country: mud-brick forts and watchtowers, houses with wind towers (barjeel) and carved doors, palm-
## frond huts (barasti) in the date gardens, Bedouin tents of black goat hair, the lamps along the mountain
## road, and on the horizon a modern city of tall towers. Nothing here copies a real building.
##
## Materials (keys): "mud" (hut_masonry 3, sun-baked mud plaster over stone: COLOR.a 1 lets the plaster flake on
## flat walls), "lime" (hut_masonry 1, lime-washed plaster), "stucco" (hut_masonry 4), "stone" (hut_masonry 0),
## "timber" / "painted" (hut_wood), "frond" (palm-frond thatch: hut_thatch), "cloth" (two-sided vertex colour),
## and CampKit's "matte", "metal", "steel", "glass", "lamp", "wood". The hut shaders read UVs in world metres,
## so every UV is multiplied by `uvk`, the caller's scale.
##
## Builders take the kit and a local frame (`at`, a Transform3D in the kit's life-size units). Each fills the
## kit; the caller commits it (`commit`, with the tangents the masonry's normal maps need).

const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")

static var uvk := 1.6
static var _mats := {}

const MUD := Color(0.80, 0.62, 0.44)
const MUD_PALE := Color(0.86, 0.72, 0.55)
const LIME := Color(0.92, 0.86, 0.74)
const STUCCO := Color(0.96, 0.93, 0.86)
const TEAK := Color(0.42, 0.26, 0.15)
const TEAK_DARK := Color(0.28, 0.17, 0.10)
const DOOR_BLUE := Color(0.16, 0.36, 0.48)
const DOOR_GREEN := Color(0.20, 0.40, 0.32)
const BRASS := Color(0.78, 0.60, 0.26)
const SHADOW := Color(0.06, 0.05, 0.05)
const POLE := Color(0.46, 0.34, 0.22)
const FROND := Color(0.72, 0.60, 0.40)


static func make_material(key: String) -> Material:
	match key:
		"mud", "lime", "stucco", "stone":
			var m := ShaderMaterial.new()
			m.shader = load("res://hut_masonry.gdshader")
			m.set_shader_parameter("style", {"mud": 3, "lime": 1, "stucco": 4, "stone": 0}[key])
			return m
		"timber", "painted":
			var w := ShaderMaterial.new()
			w.shader = load("res://hut_wood.gdshader")
			w.set_shader_parameter("style", 2 if key == "timber" else 3)
			w.set_shader_parameter("weathering", 0.45)
			return w
		"frond":
			var t := ShaderMaterial.new()
			t.shader = load("res://hut_thatch.gdshader")
			return t
		"cloth":
			var c := CampKit.make_material("canvas")
			c.cull_mode = BaseMaterial3D.CULL_DISABLED
			c.roughness = 0.97
			return c
		"dark":
			var d := CampKit.make_material("matte")
			d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			return d
	return CampKit.make_material(key)


static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	return pk


static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in ["mud", "lime", "stucco", "stone", "frond"]:
		if kit.has(key):
			var st: SurfaceTool = kit[key]
			st.index()
			st.generate_tangents()
	return pk.commit(kit)


## Runs `build` with the kit's frame moved by `local` (life-size units), then puts the frame back.
static func at(pk: PropKit, local: Transform3D, build: Callable) -> void:
	var keep := pk.xf
	pk.set_frame(keep * local)
	build.call()
	pk.set_frame(keep)


# ======================================================================================
#  Pieces
# ======================================================================================

## A wall block in plaster: UVs in metres. `flake` lets mud plaster flake off (COLOR.a).
static func slab(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color, flake := 1.0) -> void:
	pk.block(kit, key, lo, hi, Color(col.r, col.g, col.b, flake), uvk)


## A battered (tapering) block: its foot `lo`..`hi` in x and z, drawn in by `batter` metres on every side at
## the top. Walls of mud brick lean in like this.
static func battered(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, batter: float, col: Color) -> void:
	var c := col
	var b0 := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)]
	var t0 := [Vector3(lo.x + batter, hi.y, lo.z + batter), Vector3(hi.x - batter, hi.y, lo.z + batter),
			Vector3(hi.x - batter, hi.y, hi.z - batter), Vector3(lo.x + batter, hi.y, hi.z - batter)]
	var mid := (lo + hi) * 0.5
	for i in range(4):
		var j := (i + 1) % 4
		var a: Vector3 = b0[i]
		var b: Vector3 = b0[j]
		var tb: Vector3 = t0[j]
		var ta: Vector3 = t0[i]
		var n: Vector3 = (b - a).cross(ta - a).normalized()
		if n.dot(((a + b) * 0.5) - mid) < 0.0:
			n = -n
		var w: float = a.distance_to(b) * uvk
		var h: float = a.distance_to(ta) * uvk
		pk.quad(kit, key, [a, b, tb, ta], n, c, [Vector2(0, 0), Vector2(w, 0), Vector2(w - batter * uvk, h), Vector2(batter * uvk, h)])
	pk.quad(kit, key, t0, Vector3.UP, c, [Vector2(t0[0].x, t0[0].z) * uvk, Vector2(t0[1].x, t0[1].z) * uvk, Vector2(t0[2].x, t0[2].z) * uvk, Vector2(t0[3].x, t0[3].z) * uvk])


## A pyramid on a square base centred at `c` (its base's middle), `w` across, `h` tall.
static func pyramid(pk: PropKit, kit: Dictionary, key: String, c: Vector3, w: float, d: float, h: float, col: Color) -> void:
	var hw := w * 0.5
	var hd := d * 0.5
	var top := c + Vector3(0, h, 0)
	var corners := [c + Vector3(-hw, 0, -hd), c + Vector3(hw, 0, -hd), c + Vector3(hw, 0, hd), c + Vector3(-hw, 0, hd)]
	for i in range(4):
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 4]
		var n := (b - a).cross(top - a).normalized()
		if n.dot((a + b) * 0.5 - c) < 0.0:
			n = -n
		pk.tri(kit, key, a, b, top, n, n, n, col, n, Vector2(0, 0), Vector2(a.distance_to(b) * uvk, 0), Vector2(a.distance_to(b) * 0.5 * uvk, h * uvk))


## Stepped merlons (sharafat) along a parapet top from `a` to `b` (same height), facing `out`: each a block
## with a stepped, pointed top. `pitch` metres apart, `w` wide, `t` thick.
static func merlons(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, col: Color, pitch := 1.1, w := 0.55, t := 0.45, h := 0.55) -> void:
	var d := b - a
	var length := d.length()
	if length < 0.5:
		return
	var along := d / length
	var across := Vector3.UP.cross(along).normalized()
	var n: int = maxi(1, int(length / pitch))
	var gap := length / float(n)
	for i in range(n):
		var c: Vector3 = a + along * (gap * (float(i) + 0.5))
		var basis := Basis(along, Vector3.UP, across)
		pk.box(kit, key, Transform3D(basis, c + Vector3(0, h * 0.3, 0)), Vector3(w, h * 0.6, t), Color(col.r, col.g, col.b, 0.0), uvk)
		pk.box(kit, key, Transform3D(basis, c + Vector3(0, h * 0.72, 0)), Vector3(w * 0.62, h * 0.24, t * 0.9), Color(col.r, col.g, col.b, 0.0), uvk)
		pyramid(pk, kit, key, c + Vector3(0, h * 0.84, 0), w * 0.36, t * 0.8, h * 0.32, col)


## Merlons round a circle (a tower's top).
static func merlon_ring(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: float, col: Color, count := 12) -> void:
	for i in range(count):
		var a0: float = TAU * float(i) / float(count)
		var a1: float = TAU * (float(i) + 0.5) / float(count)
		var p0 := c + Vector3(cos(a0), 0, sin(a0)) * r
		var p1 := c + Vector3(cos(a1), 0, sin(a1)) * r
		merlons(pk, kit, key, p0, p1, col, 10.0, p0.distance_to(p1) * 0.95, 0.45)


## A round tower from `foot` up `h`, radius `r0` at the foot and `r1` at the top (battered), a band and a
## parapet with merlons, arrow slits. Mud or lime.
static func round_tower(pk: PropKit, kit: Dictionary, key: String, foot: Vector3, h: float, r0: float, r1: float, col: Color, slits := 3) -> void:
	# A rubble footing running well under the foot: on a slope the tower stands on it, never on air.
	pk.tube(kit, "stone", foot - Vector3(0, 6.0, 0), foot + Vector3(0, 0.4, 0), r0 + 0.35, r0 + 0.25, 18, Color(0.60, 0.53, 0.44), true, uvk)
	pk.tube(kit, key, foot - Vector3(0, 0.2, 0), foot + Vector3(0, h, 0), r0, r1, 18, Color(col.r, col.g, col.b, 0.3), true, uvk)
	# A moulded band under the parapet, the parapet itself and its walkway floor.
	var top := foot + Vector3(0, h, 0)
	pk.tube(kit, key, top - Vector3(0, 0.25, 0), top + Vector3(0, 0.12, 0), r1 + 0.18, r1 + 0.18, 18, Color(col.r * 1.04, col.g * 1.04, col.b * 1.04, 0.0), true, uvk)
	pk.tube(kit, key, top, top + Vector3(0, 0.9, 0), r1 + 0.1, r1 + 0.1, 18, Color(col.r, col.g, col.b, 0.0), true, uvk)
	merlon_ring(pk, kit, key, top + Vector3(0, 0.9, 0), r1 - 0.12, col, maxi(8, int(r1 * 3.2)))
	# Arrow slits: dark narrow openings, three tiers.
	for tier in range(slits):
		var y: float = h * (0.35 + 0.22 * float(tier))
		var rr: float = lerpf(r0, r1, y / h)
		for k in range(3):
			var a: float = TAU * (float(k) / 3.0 + float(tier) * 0.17)
			var dir := Vector3(cos(a), 0, sin(a))
			var p := foot + Vector3(0, y, 0) + dir * (rr + 0.02)
			pk.box(kit, "dark", Transform3D(Basis.looking_at(dir, Vector3.UP), p), Vector3(0.16, 0.9, 0.06), SHADOW)
	# Water spouts round the top.
	for k in range(4):
		var a: float = TAU * (float(k) + 0.25) / 4.0
		var dir := Vector3(cos(a), 0, sin(a))
		pk.beam(kit, "timber", top + dir * (r1 - 0.2) + Vector3(0, 0.15, 0), top + dir * (r1 + 0.7) + Vector3(0, 0.15, 0), 0.16, 0.16, POLE, Vector3.ZERO, uvk)


## A wooden door in a plastered surround on a wall facing `out` (horizontal), its foot's middle at `c`:
## studded teak leaves under a pointed arch, a lime surround standing proud.
static func door(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, col := TEAK, surround := LIME) -> void:
	var o := out.normalized()
	var side := Vector3.UP.cross(o).normalized()
	var basis := Basis(side, Vector3.UP, o)
	# The surround: a frame with a pointed head (a block and a pyramid-ish gable).
	pk.box(kit, "lime", Transform3D(basis, c + o * 0.06 + Vector3(0, h * 0.5 + 0.1, 0)), Vector3(w + 0.6, h + 0.2, 0.12), Color(surround.r, surround.g, surround.b, 0.0), uvk)
	var apex := c + o * 0.06 + Vector3(0, h + 0.75, 0)
	var l := c + o * 0.06 + Vector3(0, h + 0.2, 0) - side * (w * 0.5 + 0.3)
	var r := c + o * 0.06 + Vector3(0, h + 0.2, 0) + side * (w * 0.5 + 0.3)
	for z in [0.06, -0.06]:
		var oz: Vector3 = o * z
		pk.tri(kit, "lime", l + oz, r + oz, apex + oz, o * signf(z), o * signf(z), o * signf(z), Color(surround.r, surround.g, surround.b, 0.0), o * signf(z))
	pk.quad(kit, "lime", [l + o * 0.06, apex + o * 0.06, apex - o * 0.06, l - o * 0.06], (Vector3.UP - side).normalized(), surround)
	pk.quad(kit, "lime", [apex + o * 0.06, r + o * 0.06, r - o * 0.06, apex - o * 0.06], (Vector3.UP + side).normalized(), surround)
	# The leaves, a dark gap between them, the studs and a ring knocker.
	for sgn in [-1.0, 1.0]:
		var lc: Vector3 = c + o * 0.14 + side * (sgn * w * 0.25) + Vector3(0, h * 0.5, 0)
		pk.box(kit, "painted" if col != TEAK else "timber", Transform3D(basis, lc), Vector3(w * 0.48, h, 0.08), col, uvk)
		for row in range(5):
			for k in range(2):
				var sp: Vector3 = lc + o * 0.05 + Vector3(0, -h * 0.4 + h * 0.2 * row, 0) + side * (sgn * w * (0.06 + 0.13 * k) * (1.0 if sgn > 0 else 1.0) - sgn * w * 0.12)
				pk.box(kit, "metal", Transform3D(basis, sp), Vector3(0.05, 0.05, 0.03), BRASS)
	pk.box(kit, "metal", Transform3D(basis, c + o * 0.2 + Vector3(0, h * 0.55, 0) + side * 0.12), Vector3(0.12, 0.12, 0.03), BRASS)


## A small window facing `out`, its middle at `c`: a dark opening, a teak frame and a lattice of bars, a
## lime surround.
static func window(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, shutters := false) -> void:
	var o := out.normalized()
	var side := Vector3.UP.cross(o).normalized()
	var basis := Basis(side, Vector3.UP, o)
	pk.box(kit, "lime", Transform3D(basis, c + o * 0.04), Vector3(w + 0.3, h + 0.3, 0.08), Color(LIME.r, LIME.g, LIME.b, 0.0), uvk)
	pk.box(kit, "dark", Transform3D(basis, c + o * 0.09), Vector3(w, h, 0.02), SHADOW)
	for k in range(4):
		var x: float = -w * 0.5 + w * (float(k) + 0.5) / 4.0
		pk.box(kit, "timber", Transform3D(basis, c + o * 0.12 + side * x), Vector3(0.05, h, 0.05), TEAK_DARK, uvk)
	pk.box(kit, "timber", Transform3D(basis, c + o * 0.12), Vector3(w, 0.05, 0.05), TEAK_DARK, uvk)
	if shutters:
		for sgn in [-1.0, 1.0]:
			pk.box(kit, "painted", Transform3D(basis, c + o * 0.12 + side * (sgn * (w * 0.5 + 0.28))), Vector3(w * 0.5, h, 0.05), DOOR_BLUE, uvk)


## Protruding mangrove poles (chandal) along a wall face at height `y`: the beams of the floor or roof inside,
## their ends standing out of the plaster.
static func poles(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, out: Vector3, every := 0.9, stick := 0.35) -> void:
	var d := b - a
	var n: int = maxi(1, int(d.length() / every))
	for i in range(n):
		var p: Vector3 = a + d * ((float(i) + 0.5) / float(n))
		pk.tube(kit, "timber", p - out * 0.1, p + out * stick, 0.07, 0.065, 5, POLE, true, uvk)


## A wind tower (barjeel) standing on a roof at `foot` (its base's middle): a square shaft `w` across, tall
## open bays on all four sides with the partitions inside showing, a cap with merlons, poles through it.
static func wind_tower(pk: PropKit, kit: Dictionary, key: String, foot: Vector3, w: float, h: float, col: Color) -> void:
	var hw := w * 0.5
	var c := Color(col.r, col.g, col.b, 0.0)
	# The closed lower shaft.
	slab(pk, kit, key, foot + Vector3(-hw, 0, -hw), foot + Vector3(hw, h * 0.35, hw), col, 0.0)
	var y0: float = h * 0.35
	var y1: float = h * 0.88
	# Corner piers.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			slab(pk, kit, key, foot + Vector3(sx * hw - (0.36 if sx > 0 else 0.0), y0, sz * hw - (0.36 if sz > 0 else 0.0)),
					foot + Vector3(sx * hw + (0.0 if sx > 0 else 0.36), y1, sz * hw + (0.0 if sz > 0 else 0.36)), col, 0.0)
	# The dark inside and the X partitions that split the air.
	slab(pk, kit, "dark", foot + Vector3(-hw + 0.3, y0, -hw + 0.3), foot + Vector3(hw - 0.3, y1, hw - 0.3), SHADOW, 0.0)
	pk.box(kit, key, Transform3D(Basis(Vector3.UP, PI * 0.25), foot + Vector3(0, (y0 + y1) * 0.5, 0)), Vector3(w * 1.25, y1 - y0, 0.12), c, uvk)
	pk.box(kit, key, Transform3D(Basis(Vector3.UP, -PI * 0.25), foot + Vector3(0, (y0 + y1) * 0.5, 0)), Vector3(w * 1.25, y1 - y0, 0.12), c, uvk)
	# Slender mullions across each face's opening.
	for face in range(4):
		var o := Vector3(cos(face * PI * 0.5), 0, sin(face * PI * 0.5))
		var side := Vector3.UP.cross(o)
		for k in [-1.0, 0.0, 1.0]:
			var p: Vector3 = foot + o * (hw - 0.12) + side * (k * w * 0.2) + Vector3(0, (y0 + y1) * 0.5, 0)
			pk.box(kit, key, Transform3D(Basis(side, Vector3.UP, o), p), Vector3(0.12, y1 - y0, 0.16), c, uvk)
		# A row of carved openings in the cap's frieze.
		pk.box(kit, "dark", Transform3D(Basis(side, Vector3.UP, o), foot + o * (hw + 0.01) + Vector3(0, y1 + 0.35, 0)), Vector3(w * 0.7, 0.18, 0.02), SHADOW)
	# The cap and its merlons.
	slab(pk, kit, key, foot + Vector3(-hw - 0.08, y1, -hw - 0.08), foot + Vector3(hw + 0.08, h, hw + 0.08), col, 0.0)
	for face in range(4):
		var a := Vector3(cos(face * PI * 0.5) - sin(face * PI * 0.5), 0, sin(face * PI * 0.5) + cos(face * PI * 0.5)) * hw
		var b := Vector3(cos((face + 1) * PI * 0.5) - sin((face + 1) * PI * 0.5), 0, sin((face + 1) * PI * 0.5) + cos((face + 1) * PI * 0.5)) * hw
		merlons(pk, kit, key, foot + a * 0.92 + Vector3(0, h, 0), foot + b * 0.92 + Vector3(0, h, 0), col, 0.75, 0.42, 0.3, 0.5)
	# Poles through the shaft at two levels.
	for yy in [y0 - 0.2, y1 + 0.1]:
		for o2 in [Vector3.RIGHT, Vector3.BACK]:
			pk.tube(kit, "timber", foot + Vector3(0, yy, 0) - o2 * (hw + 0.45), foot + Vector3(0, yy, 0) + o2 * (hw + 0.45), 0.06, 0.06, 5, POLE, true, uvk)


## A flat-roofed parapet round a roof `lo`..`hi` (its corners at roof level), `ph` high, merlons on top.
static func parapet(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, ph: float, col: Color, crenellate := true) -> void:
	var t := 0.3
	var y := lo.y
	slab(pk, kit, key, Vector3(lo.x, y, lo.z), Vector3(hi.x, y + ph, lo.z + t), col, 0.0)
	slab(pk, kit, key, Vector3(lo.x, y, hi.z - t), Vector3(hi.x, y + ph, hi.z), col, 0.0)
	slab(pk, kit, key, Vector3(lo.x, y, lo.z + t), Vector3(lo.x + t, y + ph, hi.z - t), col, 0.0)
	slab(pk, kit, key, Vector3(hi.x - t, y, lo.z + t), Vector3(hi.x, y + ph, hi.z - t), col, 0.0)
	if crenellate:
		var yt := y + ph
		merlons(pk, kit, key, Vector3(lo.x + 0.2, yt, lo.z + t * 0.5), Vector3(hi.x - 0.2, yt, lo.z + t * 0.5), col, 0.95, 0.42, t * 0.9, 0.5)
		merlons(pk, kit, key, Vector3(lo.x + 0.2, yt, hi.z - t * 0.5), Vector3(hi.x - 0.2, yt, hi.z - t * 0.5), col, 0.95, 0.42, t * 0.9, 0.5)
		merlons(pk, kit, key, Vector3(lo.x + t * 0.5, yt, lo.z + 0.5), Vector3(lo.x + t * 0.5, yt, hi.z - 0.5), col, 0.95, 0.42, t * 0.9, 0.5)
		merlons(pk, kit, key, Vector3(hi.x - t * 0.5, yt, lo.z + 0.5), Vector3(hi.x - t * 0.5, yt, hi.z - 0.5), col, 0.95, 0.42, t * 0.9, 0.5)


# ======================================================================================
#  Buildings
# ======================================================================================

## A courtyard house, its front (with the door) toward -z, its footprint `w` x `d` from the origin's
## middle: one or two storeys of plaster on a stone plinth, a parapet with merlons, poles, windows, a wind
## tower on a back corner (`tower`), a walled yard behind with a gate (`yard`). Footprint radius returned.
static func house(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, w: float, d: float, storeys: int, key := "lime",
		tower := true, yard := true) -> float:
	var col: Color = (LIME if key == "lime" else MUD).lerp(MUD_PALE, rng.randf() * 0.4)
	var hw := w * 0.5
	var hd := d * 0.5
	var fh := 3.3
	var h := storeys * fh
	slab(pk, kit, "stone", Vector3(-hw - 0.1, -0.6, -hd - 0.1), Vector3(hw + 0.1, 0.35, hd + 0.1), Color(0.70, 0.62, 0.52), 0.0)
	slab(pk, kit, key, Vector3(-hw, 0.35, -hd), Vector3(hw, h, hd), col, 0.5)
	# A second storey set back over the front, a roof terrace before it.
	if storeys >= 2:
		parapet(pk, kit, key, Vector3(-hw, h, -hd), Vector3(hw, h, hd), 1.1, col)
	else:
		parapet(pk, kit, key, Vector3(-hw, h, -hd), Vector3(hw, h, hd), 1.0, col)
	# Floor-beam poles along the front and back.
	for f in range(storeys):
		var y: float = fh * (f + 1) - 0.25
		poles(pk, kit, Vector3(-hw + 0.4, y, -hd), Vector3(hw - 0.4, y, -hd), Vector3(0, 0, -1), 0.9, 0.3)
		poles(pk, kit, Vector3(-hw + 0.4, y, hd), Vector3(hw - 0.4, y, hd), Vector3(0, 0, 1), 0.9, 0.3)
	# The door: centred or to one side; windows either side and above.
	var dx: float = rng.randf_range(-hw * 0.3, hw * 0.3)
	var dcol: Color = [TEAK, DOOR_BLUE, DOOR_GREEN, TEAK][rng.randi() % 4]
	door(pk, kit, Vector3(dx, 0.35, -hd), Vector3(0, 0, -1), 1.5, 2.3, dcol)
	for f in range(storeys):
		var y: float = fh * f + (1.9 if f == 0 else 1.7)
		var nx: int = maxi(1, int(w / 3.4))
		for k in range(nx):
			var x: float = -hw + w * (float(k) + 0.5) / float(nx)
			if f == 0 and absf(x - dx) < 1.6:
				continue
			window(pk, kit, Vector3(x, y, -hd), Vector3(0, 0, -1), 0.8, 1.0, f == 0 and rng.randf() < 0.5)
		for k in range(maxi(1, int(d / 4.0))):
			var z: float = -hd + d * (float(k) + 0.5) / float(maxi(1, int(d / 4.0)))
			for sx in [-1.0, 1.0]:
				if rng.randf() < 0.6:
					window(pk, kit, Vector3(sx * hw, y, z), Vector3(sx, 0, 0), 0.7, 0.9)
	# Water spouts from the roof.
	for sx in [-0.6, 0.6]:
		pk.beam(kit, "timber", Vector3(hw * sx, h + 0.15, -hd + 0.1), Vector3(hw * sx, h + 0.15, -hd - 0.8), 0.18, 0.14, POLE, Vector3.ZERO, uvk)
	if tower:
		var tw: float = clampf(w * 0.3, 2.2, 3.0)
		var tx: float = (hw - tw * 0.5 - 0.3) * (1.0 if rng.randf() < 0.5 else -1.0)
		wind_tower(pk, kit, key, Vector3(tx, h, hd - tw * 0.5 - 0.3), tw, rng.randf_range(4.8, 6.2), col)
	var reach: float = Vector2(hw, hd).length()
	if yard:
		var yd: float = rng.randf_range(5.0, 8.0)
		var yh := 2.4
		slab(pk, kit, key, Vector3(-hw, 0.0, hd), Vector3(-hw + 0.4, yh, hd + yd), col, 1.0)
		slab(pk, kit, key, Vector3(hw - 0.4, 0.0, hd), Vector3(hw, yh, hd + yd), col, 1.0)
		slab(pk, kit, key, Vector3(-hw, 0.0, hd + yd - 0.4), Vector3(-1.2, yh, hd + yd), col, 1.0)
		slab(pk, kit, key, Vector3(1.2, 0.0, hd + yd - 0.4), Vector3(hw, yh, hd + yd), col, 1.0)
		# A gate in the back wall, a lintel over it.
		pk.box(kit, "timber", Transform3D(Basis(), Vector3(0, yh - 0.1, hd + yd - 0.2)), Vector3(2.8, 0.25, 0.5), POLE, uvk)
		pk.box(kit, "painted", Transform3D(Basis(), Vector3(0, 1.05, hd + yd - 0.2)), Vector3(2.3, 2.1, 0.08), dcol, uvk)
		reach = Vector2(hw, hd + yd).length()
	return reach


## A fort round a square courtyard `side` across (centred on the origin), its gate toward -z: battered
## curtain walls with a walkway and merlons, round towers on three corners, a square tower on the fourth,
## a tall round keep, the gatehouse with a big studded door, rooms along the inside of the walls, a well.
## Returns the footprint radius.
static func fort(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, side := 46.0, wall_h := 8.0) -> float:
	var hs := side * 0.5
	var t := 1.8
	var col := MUD
	# The curtain walls, battered, on a rubble footing.
	for i in range(4):
		var lo: Vector3
		var hi: Vector3
		match i:
			0: lo = Vector3(-hs, 0, -hs); hi = Vector3(hs, wall_h, -hs + t)
			1: lo = Vector3(-hs, 0, hs - t); hi = Vector3(hs, wall_h, hs)
			2: lo = Vector3(-hs, 0, -hs + t); hi = Vector3(-hs + t, wall_h, hs - t)
			3: lo = Vector3(hs - t, 0, -hs + t); hi = Vector3(hs, wall_h, hs - t)
		slab(pk, kit, "stone", Vector3(lo.x - 0.3, -6.0, lo.z - 0.3), Vector3(hi.x + 0.3, 0.6, hi.z + 0.3), Color(0.62, 0.55, 0.46), 0.0)
		battered(pk, kit, "mud", lo + Vector3(0, 0.6, 0), hi, 0.25, Color(col.r, col.g, col.b, 0.3))
	# Merlons along the outer edge of the walkway, a low inner parapet.
	var y := wall_h
	merlons(pk, kit, "mud", Vector3(-hs + 2.5, y, -hs + 0.45), Vector3(hs - 2.5, y, -hs + 0.45), col, 1.15, 0.6, 0.5, 0.75)
	merlons(pk, kit, "mud", Vector3(-hs + 2.5, y, hs - 0.45), Vector3(hs - 2.5, y, hs - 0.45), col, 1.15, 0.6, 0.5, 0.75)
	merlons(pk, kit, "mud", Vector3(-hs + 0.45, y, -hs + 2.5), Vector3(-hs + 0.45, y, hs - 2.5), col, 1.15, 0.6, 0.5, 0.75)
	merlons(pk, kit, "mud", Vector3(hs - 0.45, y, -hs + 2.5), Vector3(hs - 0.45, y, hs - 2.5), col, 1.15, 0.6, 0.5, 0.75)
	# Corner towers: three round, the north-east square and taller.
	var corners := [Vector2(-hs, -hs), Vector2(hs, -hs), Vector2(-hs, hs), Vector2(hs, hs)]
	for k in range(4):
		var cp: Vector2 = corners[k]
		if k == 3:
			slab(pk, kit, "stone", Vector3(cp.x - 4.2, -6.0, cp.y - 4.2), Vector3(cp.x + 4.2, 0.6, cp.y + 4.2), Color(0.62, 0.55, 0.46), 0.0)
			battered(pk, kit, "mud", Vector3(cp.x - 3.8, 0.6, cp.y - 3.8), Vector3(cp.x + 3.8, wall_h + 5.0, cp.y + 3.8), 0.45, Color(col.r, col.g, col.b, 0.3))
			parapet(pk, kit, "mud", Vector3(cp.x - 3.35, wall_h + 5.0, cp.y - 3.35), Vector3(cp.x + 3.35, wall_h + 5.0, cp.y + 3.35), 1.0, col)
			for f in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]:
				window(pk, kit, Vector3(cp.x, wall_h + 2.6, cp.y) + f * 3.45, f, 0.6, 1.0)
		else:
			round_tower(pk, kit, "mud", Vector3(cp.x, 0.0, cp.y), wall_h + 3.5, 4.6, 3.7, col)
	# The keep: a tall round tower inside the south-west corner.
	round_tower(pk, kit, "mud", Vector3(-hs + 9.0, 0.0, hs - 9.0), wall_h + 9.0, 5.6, 4.4, col, 5)
	# The gatehouse: a block standing out of the south wall, a deep arched gate.
	slab(pk, kit, "stone", Vector3(-4.8, -6.0, -hs - 2.5), Vector3(4.8, 0.6, -hs + t), Color(0.62, 0.55, 0.46), 0.0)
	slab(pk, kit, "mud", Vector3(-4.5, 0.6, -hs - 2.2), Vector3(4.5, wall_h + 2.2, -hs + t), col, 0.3)
	parapet(pk, kit, "mud", Vector3(-4.5, wall_h + 2.2, -hs - 2.2), Vector3(4.5, wall_h + 2.2, -hs + t), 0.9, col)
	slab(pk, kit, "dark", Vector3(-1.9, 0.6, -hs - 2.25), Vector3(1.9, 5.6, -hs - 2.21), SHADOW, 0.0)
	door(pk, kit, Vector3(0, 0.6, -hs - 2.2), Vector3(0, 0, -1), 3.2, 4.6, TEAK)
	# A box machicolation over the gate.
	slab(pk, kit, "mud", Vector3(-1.6, wall_h - 0.4, -hs - 3.1), Vector3(1.6, wall_h + 1.4, -hs - 2.2), col, 0.0)
	for k in range(3):
		pk.box(kit, "dark", Transform3D(Basis(), Vector3(-1.0 + k, wall_h + 0.4, -hs - 3.12)), Vector3(0.18, 0.7, 0.02), SHADOW)
	poles(pk, kit, Vector3(-4.0, wall_h - 0.8, -hs - 2.2), Vector3(4.0, wall_h - 0.8, -hs - 2.2), Vector3(0, 0, -1), 0.8, 0.4)
	# Rooms along the inside of the north and east walls, a well in the court.
	slab(pk, kit, "mud", Vector3(-hs + t, 0.0, hs - t - 6.0), Vector3(hs - 12.0, 4.2, hs - t), MUD_PALE, 1.0)
	parapet(pk, kit, "mud", Vector3(-hs + t, 4.2, hs - t - 6.0), Vector3(hs - 12.0, 4.2, hs - t), 0.7, MUD_PALE, false)
	for k in range(4):
		var x: float = -hs + 6.0 + k * 6.0
		door(pk, kit, Vector3(x, 0.0, hs - t - 6.0), Vector3(0, 0, -1), 1.3, 2.2, [TEAK, DOOR_BLUE][k % 2])
	slab(pk, kit, "mud", Vector3(hs - t - 6.0, 0.0, -hs + 8.0), Vector3(hs - t, 4.2, hs - t - 6.0), MUD_PALE, 1.0)
	pk.tube(kit, "stone", Vector3(4, 0, 4), Vector3(4, 0.9, 4), 1.2, 1.2, 12, Color(0.65, 0.58, 0.48), true, uvk)
	pk.tube(kit, "dark", Vector3(4, 0.5, 4), Vector3(4, 0.92, 4), 0.85, 0.85, 12, SHADOW, true)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "timber", Vector3(4 + sx * 1.0, 0.9, 4), Vector3(4 + sx * 1.0, 2.6, 4), 0.14, 0.14, POLE)
	pk.beam(kit, "timber", Vector3(2.8, 2.6, 4), Vector3(5.2, 2.6, 4), 0.14, 0.14, POLE)
	# A flagpole on the keep.
	var kc := Vector3(-hs + 9.0, wall_h + 9.9, hs - 9.0)
	pk.tube(kit, "metal", kc, kc + Vector3(0, 7.0, 0), 0.08, 0.05, 6, Color(0.8, 0.8, 0.78))
	return side * 0.75


## A watchtower (burj) on a ridge: a round, battered tower `h` tall, a door a few metres up reached by a
## ladder, slits, a crenellated top. Its foot's middle is at the origin.
static func watchtower(pk: PropKit, kit: Dictionary, h := 11.0, r := 2.9) -> float:
	slab(pk, kit, "stone", Vector3(-r - 0.6, -6.0, -r - 0.6), Vector3(r + 0.6, 0.5, r + 0.6), Color(0.60, 0.53, 0.44), 0.0)
	round_tower(pk, kit, "mud", Vector3(0, 0.5, 0), h, r, r * 0.78, MUD, 3)
	# The door, 3m up on the -z side, and a ladder of poles to it.
	var dy := 3.2
	var dz: float = -lerpf(r, r * 0.78, dy / h) - 0.02
	pk.box(kit, "timber", Transform3D(Basis(), Vector3(0, dy + 1.0, dz)), Vector3(0.9, 1.8, 0.1), TEAK, uvk)
	for sx in [-0.3, 0.3]:
		pk.beam(kit, "timber", Vector3(sx, 0.5, dz - 1.4), Vector3(sx, dy + 0.2, dz - 0.15), 0.08, 0.08, POLE)
	for k in range(6):
		var t: float = (float(k) + 0.5) / 6.0
		var p := Vector3(0, 0.5, dz - 1.4).lerp(Vector3(0, dy + 0.2, dz - 0.15), t)
		pk.beam(kit, "timber", p - Vector3(0.32, 0, 0), p + Vector3(0.32, 0, 0), 0.06, 0.06, POLE)
	return r + 1.5


## A palm-frond hut (barasti): a frame of poles, walls of bound frond panels, a pitched frond roof. Its
## floor's middle at the origin, `w` x `d`, the doorway toward -z.
static func barasti(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, w := 4.5, d := 3.6) -> float:
	var hw := w * 0.5
	var hd := d * 0.5
	var eave := 2.3
	var ridge := 3.4
	var fc := FROND.lerp(Color(0.62, 0.50, 0.32), rng.randf() * 0.5)
	# Wall panels: the frond stalks bound upright, a dark doorway gap in the front.
	for i in range(4):
		var lo: Vector3
		var hi: Vector3
		match i:
			0: lo = Vector3(-hw, 0, -hd); hi = Vector3(-0.5, eave, -hd + 0.12)
			1: lo = Vector3(0.5, 0, -hd); hi = Vector3(hw, eave, -hd + 0.12)
			2: lo = Vector3(-hw, 0, hd - 0.12); hi = Vector3(hw, eave, hd)
			3: lo = Vector3(-hw, 0, -hd); hi = Vector3(-hw + 0.12, eave, hd)
		pk.block(kit, "frond", lo, hi, fc, uvk)
	pk.block(kit, "frond", Vector3(hw - 0.12, 0, -hd), Vector3(hw, eave, hd), fc, uvk)
	pk.block(kit, "frond", Vector3(-0.5, 1.9, -hd), Vector3(0.5, eave, -hd + 0.12), fc, uvk)
	pk.block(kit, "dark", Vector3(-0.5, 0, -hd + 0.05), Vector3(0.5, 1.9, -hd + 0.08), SHADOW)
	# Corner and ridge poles, binding bands.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			pk.tube(kit, "timber", Vector3(sx * hw, -0.2, sz * hd), Vector3(sx * hw, eave + 0.15, sz * hd), 0.08, 0.07, 6, POLE, true, uvk)
		pk.tube(kit, "timber", Vector3(sx * (hw + 0.1), ridge, 0), Vector3(sx * (hw + 0.1), -0.2, 0), 0.08, 0.08, 6, POLE)
	pk.tube(kit, "timber", Vector3(-hw - 0.3, ridge, 0), Vector3(hw + 0.3, ridge, 0), 0.08, 0.08, 6, POLE)
	for y in [0.6, 1.5]:
		for face in [[Vector3(-hw, y, -hd - 0.02), Vector3(hw, y, -hd - 0.02)], [Vector3(-hw, y, hd + 0.02), Vector3(hw, y, hd + 0.02)]]:
			pk.beam(kit, "timber", face[0], face[1], 0.05, 0.05, POLE)
	# The roof: two frond slopes overhanging the walls, the gables filled.
	for sz in [-1.0, 1.0]:
		var a := Vector3(-hw - 0.35, eave - 0.1, sz * (hd + 0.4))
		var b := Vector3(hw + 0.35, eave - 0.1, sz * (hd + 0.4))
		var c := Vector3(hw + 0.35, ridge + 0.1, 0)
		var dd := Vector3(-hw - 0.35, ridge + 0.1, 0)
		var n := (b - a).cross(dd - a).normalized()
		if n.y < 0.0:
			n = -n
		pk.quad(kit, "frond", [a, b, c, dd], n, fc.darkened(0.08), [Vector2(0, 0), Vector2(w * uvk, 0), Vector2(w * uvk, 2.0 * uvk), Vector2(0, 2.0 * uvk)])
		pk.quad(kit, "frond", [dd, c, b, a], -n, fc.darkened(0.3))
	for sx in [-1.0, 1.0]:
		var g0 := Vector3(sx * hw, eave, -hd)
		var g1 := Vector3(sx * hw, eave, hd)
		var g2 := Vector3(sx * hw, ridge, 0)
		pk.tri(kit, "frond", g0, g1, g2, Vector3(sx, 0, 0), Vector3(sx, 0, 0), Vector3(sx, 0, 0), fc, Vector3(sx, 0, 0))
		pk.tri(kit, "frond", g0, g1, g2, Vector3(-sx, 0, 0), Vector3(-sx, 0, 0), Vector3(-sx, 0, 0), fc.darkened(0.3), Vector3(-sx, 0, 0))
	return Vector2(hw + 0.4, hd + 0.4).length()


## A Bedouin tent (bayt al-sha'ar) of black goat hair: three rows of poles, the roof sagging between them
## with woven stripes, a back wall and side walls to the ground, the front open onto carpets, cushions, a
## fire pit with a coffee pot. Its middle at the origin, the open front toward -z, `bays` along x.
static func bedouin_tent(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, bays := 3) -> float:
	var bay := 3.6
	var w: float = bay * bays
	var hw := w * 0.5
	var depth := 6.0
	var hd := depth * 0.5
	var black := Color(0.10, 0.08, 0.07)
	var brown := Color(0.20, 0.15, 0.11)
	var cream := Color(0.84, 0.78, 0.66)
	var heights := [1.7, 2.6, 1.6]       # front, middle and back pole rows
	var zs := [-hd, 0.0, hd]
	var nx: int = bays * 6
	var nz := 8
	var grid: Array = []
	for j in range(nz + 1):
		var zt: float = float(j) / float(nz)
		var z: float = lerpf(-hd, hd, zt)
		var ybase: float
		if zt < 0.5:
			ybase = lerpf(heights[0], heights[1], smoothstep(0.0, 1.0, zt * 2.0))
		else:
			ybase = lerpf(heights[1], heights[2], smoothstep(0.0, 1.0, (zt - 0.5) * 2.0))
		var row: Array = []
		for i in range(nx + 1):
			var xt: float = float(i) / float(nx)
			var x: float = lerpf(-hw, hw, xt)
			# Sags between the pole bays.
			var ph: float = fposmod(x + hw, bay) / bay
			var sag: float = sin(ph * PI) * 0.32 * (1.0 - absf(zt - 0.5) * 0.6)
			row.append(Vector3(x, ybase - sag, z))
		grid.append(row)
	for j in range(nz):
		for i in range(nx):
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i + 1]
			var c: Vector3 = grid[j + 1][i + 1]
			var d: Vector3 = grid[j + 1][i]
			var n := (c - a).cross(b - a).normalized()
			if n.y < 0.0:
				n = -n
			# Strips woven along the tent: black and brown, a cream stripe now and then.
			var strip: int = j
			var col: Color = black if strip % 2 == 0 else brown
			if strip == 3:
				col = cream.darkened(0.1)
			pk.quad(kit, "cloth", [a, b, c, d], n, col)
	# The back wall and side walls hang to the ground.
	var back: Array = grid[nz]
	for i in range(nx):
		var a: Vector3 = back[i]
		var b: Vector3 = back[i + 1]
		pk.quad(kit, "cloth", [a, b, Vector3(b.x, 0, b.z + 0.15), Vector3(a.x, 0, a.z + 0.15)], Vector3(0, 0, 1), brown)
	for sx in [0, nx]:
		for j in range(nz):
			var a: Vector3 = grid[j][sx]
			var b: Vector3 = grid[j + 1][sx]
			if j < 2:
				continue
			pk.quad(kit, "cloth", [a, b, Vector3(b.x, 0, b.z), Vector3(a.x, 0, a.z)], Vector3(signf(float(sx) - 0.5), 0, 0), black)
	# Poles under the ridges and guy ropes out to pegs.
	for r in range(3):
		for i in range(bays + 1):
			var x: float = -hw + bay * float(i)
			var top := Vector3(x, float(heights[r]) - 0.05, zs[r])
			pk.tube(kit, "timber", Vector3(x, 0, zs[r]), top, 0.06, 0.05, 5, POLE)
			if r != 1:
				var peg := Vector3(x, 0.05, float(zs[r]) + signf(float(zs[r])) * 2.6)
				pk.beam(kit, "matte", top, peg, 0.03, 0.03, Color(0.6, 0.55, 0.45))
	# Carpets under the front half, cushions along the back wall, the hearth and the coffee pot.
	var carpets := [Color(0.55, 0.12, 0.10), Color(0.62, 0.30, 0.10), Color(0.32, 0.12, 0.18)]
	for k in range(bays):
		var cx: float = -hw + bay * (float(k) + 0.5)
		var cc: Color = carpets[rng.randi() % carpets.size()]
		pk.block(kit, "cloth", Vector3(cx - 1.5, 0.02, -hd - 1.2), Vector3(cx + 1.5, 0.05, hd - 0.6), cc)
		pk.block(kit, "cloth", Vector3(cx - 1.2, 0.05, -hd - 0.9), Vector3(cx + 1.2, 0.06, hd - 0.9), cc.lightened(0.25))
		for c2 in range(3):
			pk.box(kit, "cloth", Transform3D(Basis(), Vector3(cx - 1.0 + c2, 0.25, hd - 0.9)), Vector3(0.8, 0.4, 0.5), [Color(0.6, 0.15, 0.12), Color(0.15, 0.25, 0.45), Color(0.70, 0.55, 0.20)][c2])
	var fire := Vector3(0, 0, -hd - 2.6)
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		pk.box(kit, "stone", Transform3D(Basis(Vector3.UP, a), fire + Vector3(cos(a), 0.12, sin(a)) * 0.6), Vector3(0.35, 0.25, 0.3), Color(0.5, 0.46, 0.40), uvk)
	pk.block(kit, "dark", fire + Vector3(-0.4, 0.0, -0.4), fire + Vector3(0.4, 0.06, 0.4), Color(0.08, 0.07, 0.06))
	dallah(pk, kit, fire + Vector3(0.25, 0.06, 0.1), 0.9)
	dallah(pk, kit, Vector3(-1.2, 0.06, -hd - 0.4), 0.7)
	return Vector2(hw + 2.6, hd + 3.4).length()


## A brass coffee pot (dallah): a lathe of the waisted body, the domed lid with its finial, the long beak.
static func dallah(pk: PropKit, kit: Dictionary, foot: Vector3, s := 1.0) -> void:
	var prof := [Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.15, 0.04), Vector2(0.13, 0.1), Vector2(0.08, 0.16), Vector2(0.07, 0.2),
			Vector2(0.1, 0.24), Vector2(0.09, 0.28), Vector2(0.04, 0.32), Vector2(0.015, 0.38), Vector2(0.0, 0.39)]
	var scaled: Array = []
	for p in prof:
		scaled.append((p as Vector2) * s)
	pk.lathe(kit, "metal", foot, scaled, 12, BRASS)
	pk.tube(kit, "metal", foot + Vector3(0.1, 0.06, 0) * s, foot + Vector3(0.24, 0.3, 0) * s, 0.025 * s, 0.012 * s, 5, BRASS)


## A lamp of the mountain road: a tall tapered octagonal mast on a plinth, two swept arms with flat
## luminaires, the arms along ±x. Its foot's middle at the origin.
static func road_lamp(pk: PropKit, kit: Dictionary, h := 11.0, arms := 2) -> void:
	var grey := Color(0.58, 0.58, 0.56)
	pk.block(kit, "stone", Vector3(-0.45, -0.6, -0.45), Vector3(0.45, 0.45, 0.45), Color(0.72, 0.68, 0.60))
	pk.tube(kit, "metal", Vector3(0, 0.45, 0), Vector3(0, h, 0), 0.17, 0.08, 8, grey)
	pk.tube(kit, "metal", Vector3(0, 0.45, 0), Vector3(0, 1.4, 0), 0.22, 0.2, 8, grey.darkened(0.15))
	for k in range(arms):
		var sx: float = 1.0 if k == 0 else -1.0
		var p0 := Vector3(0, h - 0.4, 0)
		var p1 := Vector3(sx * 1.2, h + 0.3, 0)
		var p2 := Vector3(sx * 2.4, h + 0.45, 0)
		pk.tube(kit, "metal", p0, p1, 0.07, 0.06, 6, grey, false)
		pk.tube(kit, "metal", p1, p2, 0.06, 0.05, 6, grey)
		# The luminaire: a flat housing, its glowing lens underneath.
		pk.box(kit, "metal", Transform3D(Basis(Vector3.FORWARD, sx * 0.08), p2 + Vector3(sx * 0.35, -0.05, 0)), Vector3(0.95, 0.16, 0.42), grey.lightened(0.2))
		pk.box(kit, "lamp", Transform3D(Basis(Vector3.FORWARD, sx * 0.08), p2 + Vector3(sx * 0.35, -0.14, 0)), Vector3(0.8, 0.03, 0.32), Color(1.0, 0.88, 0.62))


## A distant tower for the skyline (only seen from 1-3km): a tapering square or round shaft in bands of
## glass and stone, set back in tiers, a crown and a spire. In the "lime" / "glass" keys; `h` metres tall.
static func skyline_tower(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, h: float, w: float, style: int) -> void:
	var glass_cols := [Color(0.42, 0.56, 0.62), Color(0.55, 0.62, 0.58), Color(0.62, 0.58, 0.50), Color(0.38, 0.46, 0.56)]
	var gcol: Color = glass_cols[rng.randi() % glass_cols.size()]
	var tiers: int = 3 + rng.randi() % 3
	var y := 0.0
	var ww := w
	for t in range(tiers):
		var th: float = h * (0.42 if t == 0 else 0.58 / float(tiers - 1)) * (0.85 if t == tiers - 1 else 1.0)
		var top_w: float = ww * (0.9 if style == 0 else 0.82)
		if style == 1:
			pk.tube(kit, "metal", Vector3(0, y, 0), Vector3(0, y + th, 0), ww * 0.5, top_w * 0.5, 12, gcol, true)
		else:
			# A square shaft whose faces are glass between stone fins at the corners.
			pk.box(kit, "metal", Transform3D(Basis(), Vector3(0, y + th * 0.5, 0)), Vector3((ww + top_w) * 0.5, th, (ww + top_w) * 0.5), gcol)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					pk.box(kit, "stucco", Transform3D(Basis(), Vector3(sx * ww * 0.47, y + th * 0.5, sz * ww * 0.47)), Vector3(ww * 0.1, th, ww * 0.1), STUCCO, 0.0)
		# A band of stone between tiers.
		pk.box(kit, "stucco", Transform3D(Basis(), Vector3(0, y + th, 0)), Vector3(top_w * 1.02, h * 0.012, top_w * 1.02), STUCCO, 0.0)
		y += th
		ww = top_w * 0.82
	# Crown and spire.
	pk.tube(kit, "metal", Vector3(0, y, 0), Vector3(0, y + h * 0.05, 0), ww * 0.4, ww * 0.25, 8, gcol.lightened(0.2))
	pk.tube(kit, "metal", Vector3(0, y + h * 0.05, 0), Vector3(0, y + h * (0.12 + rng.randf() * 0.12), 0), ww * 0.08, 0.3, 6, Color(0.8, 0.8, 0.78))


## A dome on a drum: `c` the drum's foot, radius `r`, the drum `drum` tall, a slightly pointed crown and a
## brass finial.
static func dome(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: float, drum: float, col: Color) -> void:
	pk.tube(kit, key, c, c + Vector3(0, drum, 0), r, r, 20, Color(col.r, col.g, col.b, 0.0), true, uvk)
	pk.tube(kit, key, c + Vector3(0, drum - 0.2, 0), c + Vector3(0, drum + 0.15, 0), r + 0.15, r + 0.15, 20, Color(col.r, col.g, col.b, 0.0), true, uvk)
	var prof: Array = []
	for k in range(9):
		var a: float = PI * 0.5 * float(k) / 8.0
		# A little fuller than a hemisphere at the shoulder, drawn to a point at the top.
		prof.append(Vector2(r * cos(a) * (1.0 + 0.06 * sin(a * 2.0)), r * sin(a) * 1.18))
	prof[prof.size() - 1] = Vector2(0.0, r * 1.25)
	pk.lathe(kit, "stucco", c + Vector3(0, drum + 0.15, 0), prof, 20, col)
	pk.tube(kit, "metal", c + Vector3(0, drum + 0.1 + r * 1.22, 0), c + Vector3(0, drum + r * 1.22 + 1.4, 0), 0.08, 0.03, 6, BRASS)
	pk.lathe(kit, "metal", c + Vector3(0, drum + r * 1.22 + 0.4, 0), [Vector2(0, 0), Vector2(0.18, 0.12), Vector2(0, 0.3)], 8, BRASS)


## A row of pointed arches (an arcade) along x from `x0` to `x1` at depth `z`, facing -z: piers, the arches'
## heads, a dark loggia behind, a cornice. `h` to the springing, `bay` metres a bay.
static func arcade(pk: PropKit, kit: Dictionary, key: String, x0: float, x1: float, z: float, y0: float, h: float, bay: float, col: Color) -> void:
	var n: int = maxi(1, int((x1 - x0) / bay))
	var b: float = (x1 - x0) / float(n)
	var c := Color(col.r, col.g, col.b, 0.0)
	slab(pk, kit, "dark", Vector3(x0, y0, z + 0.3), Vector3(x1, y0 + h + b * 0.55, z + 0.35), SHADOW, 0.0)
	for i in range(n + 1):
		var x: float = x0 + b * i
		slab(pk, kit, key, Vector3(x - 0.35, y0, z - 0.1), Vector3(x + 0.35, y0 + h, z + 0.3), col, 0.0)
	for i in range(n):
		var xl: float = x0 + b * i + 0.35
		var xr: float = x0 + b * (i + 1) - 0.35
		var xm: float = (xl + xr) * 0.5
		var ys: float = y0 + h
		var apex: float = ys + (xr - xl) * 0.55
		var top: float = ys + b * 0.55 + 0.4
		# The spandrels either side of the pointed head, as two quads from the springing to the top.
		for side in [[xl - 0.35, xl, xm], [xr + 0.35, xr, xm]]:
			var xo: float = side[0]
			var xi: float = side[1]
			var xa: float = side[2]
			pk.quad(kit, key, [Vector3(xo, ys, z - 0.1), Vector3(xi, ys, z - 0.1), Vector3(xa, apex, z - 0.1), Vector3(xo, top, z - 0.1)], Vector3(0, 0, -1), c)
			pk.quad(kit, key, [Vector3(xa, apex, z - 0.1), Vector3(xa, top, z - 0.1), Vector3(xo, top, z - 0.1), Vector3(xo, top, z - 0.1)], Vector3(0, 0, -1), c)
		pk.quad(kit, key, [Vector3(xl - 0.35, top, z - 0.1), Vector3(xr + 0.35, top, z - 0.1), Vector3(xm, apex, z - 0.1), Vector3(xm, apex, z - 0.1)], Vector3(0, 0, -1), c)
	slab(pk, kit, key, Vector3(x0 - 0.5, y0 + h + b * 0.55 + 0.4, z - 0.25), Vector3(x1 + 0.5, y0 + h + b * 0.55 + 0.9, z + 0.4), col, 0.0)


## Qasr al-Hamra, a desert palace hotel: a domed central hall over an arcaded front, two crenellated wings with wind
## towers, corner towers with small domes, a pool before it in a paved court. Its front toward -z, the court's
## middle 18m in front of the hall. Returns the footprint radius.
static func palace(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator) -> float:
	var col := Color(0.90, 0.78, 0.62)
	var pale := Color(0.95, 0.88, 0.76)
	# The court: paving, the pool and its rim.
	slab(pk, kit, "stucco", Vector3(-30, -0.5, -32), Vector3(30, 0.15, -6), Color(0.88, 0.82, 0.72), 0.0)
	slab(pk, kit, "stone", Vector3(-12, 0.15, -27), Vector3(12, 0.45, -13), Color(0.92, 0.88, 0.80), 0.0)
	slab(pk, kit, "matte", Vector3(-11.4, 0.2, -26.4), Vector3(11.4, 0.46, -13.6), Color(0.10, 0.36, 0.44), 0.0)
	slab(pk, kit, "glass", Vector3(-11.4, 0.42, -26.4), Vector3(11.4, 0.43, -13.6), Color(0.35, 0.70, 0.78, 0.55), 0.0)
	# The central hall: two storeys, the arcade across its front, the great dome.
	slab(pk, kit, "stone", Vector3(-16, -0.6, -6), Vector3(16, 0.5, 14), Color(0.70, 0.62, 0.52), 0.0)
	slab(pk, kit, "stucco", Vector3(-15, 0.5, -3), Vector3(15, 10.0, 13), col, 0.0)
	arcade(pk, kit, "stucco", -15.0, 15.0, -5.6, 0.5, 4.2, 3.75, pale)
	slab(pk, kit, "stucco", Vector3(-15, 0.5, -5.9), Vector3(15, 0.7, -3), pale, 0.0)
	parapet(pk, kit, "stucco", Vector3(-15, 10.0, -3), Vector3(15, 10.0, 13), 1.0, pale)
	for k in range(6):
		window(pk, kit, Vector3(-12.5 + k * 5.0, 7.6, -3.0), Vector3(0, 0, -1), 1.1, 1.6, false)
	dome(pk, kit, "stucco", Vector3(0, 10.0, 5.0), 6.2, 3.2, pale)
	for sx in [-1.0, 1.0]:
		dome(pk, kit, "stucco", Vector3(sx * 10.5, 10.0, 8.5), 2.2, 1.4, pale)
	# The wings: a storey and a half, crenellated, wind towers, poles.
	for sx in [-1.0, 1.0]:
		var x0: float = sx * 15.0
		var x1: float = sx * 34.0
		var lo := Vector3(minf(x0, x1), 0.5, -1.0)
		var hi := Vector3(maxf(x0, x1), 6.5, 12.0)
		slab(pk, kit, "stone", Vector3(lo.x, -0.6, lo.z - 0.2), Vector3(hi.x, 0.5, hi.z + 0.2), Color(0.70, 0.62, 0.52), 0.0)
		slab(pk, kit, "mud", lo, hi, col, 0.25)
		parapet(pk, kit, "mud", Vector3(lo.x, 6.5, lo.z), Vector3(hi.x, 6.5, hi.z), 0.9, col)
		arcade(pk, kit, "mud", lo.x + 0.5, hi.x - 0.5, -2.6, 0.5, 2.8, 3.1, col)
		poles(pk, kit, Vector3(lo.x + 0.5, 6.2, hi.z), Vector3(hi.x - 0.5, 6.2, hi.z), Vector3(0, 0, 1), 0.9, 0.35)
		wind_tower(pk, kit, "mud", Vector3(sx * 24.5, 6.5, 8.0), 2.8, 5.8, col)
		# The corner tower at the wing's end, its little dome.
		var tc := Vector3(sx * 36.0, 0.0, 5.5)
		round_tower(pk, kit, "mud", tc, 10.5, 3.6, 3.0, col, 3)
		dome(pk, kit, "stucco", tc + Vector3(0, 11.4, 0), 2.1, 0.9, pale)
	# Lamps along the court.
	for k in range(6):
		var x: float = -25.0 + k * 10.0
		pk.tube(kit, "metal", Vector3(x, 0.15, -30.5), Vector3(x, 3.6, -30.5), 0.07, 0.05, 6, Color(0.20, 0.18, 0.15))
		pk.box(kit, "lamp", Transform3D(Basis(), Vector3(x, 3.85, -30.5)), Vector3(0.45, 0.6, 0.45), Color(1.0, 0.86, 0.6))
	return 42.0


## A dromedary at life size (2m at the shoulder), facing -z, standing (`couched` false) or lying down with its
## legs folded under it. Vertex colour, a woven saddle blanket on some (`blanket`).
static func camel(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, couched := false, blanket := false) -> void:
	var hide: Color = [Color(0.72, 0.54, 0.36), Color(0.62, 0.45, 0.30), Color(0.80, 0.66, 0.48), Color(0.55, 0.40, 0.27)][rng.randi() % 4]
	var dark := hide.darkened(0.25)
	var drop: float = 1.25 if couched else 0.0
	var body_y: float = 1.55 - drop
	# The barrel of the body and the hump.
	pk.lathe(kit, "matte", Vector3(0, body_y, 0), [Vector2(0.0, -0.75), Vector2(0.42, -0.6), Vector2(0.55, -0.1), Vector2(0.5, 0.45), Vector2(0.3, 0.7), Vector2(0.0, 0.78)],
			10, hide, false, Basis(Vector3.RIGHT, PI * 0.5))
	pk.lathe(kit, "matte", Vector3(0, body_y + 0.35, 0.05), [Vector2(0.0, 0.0), Vector2(0.4, 0.05), Vector2(0.32, 0.4), Vector2(0.12, 0.62), Vector2(0.0, 0.66)], 10, hide)
	# Neck: down and forward from the chest, then up to the head.
	var chest := Vector3(0, body_y + 0.1, -0.7)
	var low := Vector3(0, body_y - 0.05, -1.25)
	var throat := Vector3(0, body_y + 0.55, -1.6)
	var poll := Vector3(0, body_y + 0.95, -1.65)
	pk.tube(kit, "matte", chest, low, 0.26, 0.2, 8, hide, false)
	pk.tube(kit, "matte", low, throat, 0.2, 0.16, 8, hide, false)
	pk.tube(kit, "matte", throat, poll, 0.16, 0.15, 8, hide, true)
	# The head: a long muzzle, ears, eyes.
	pk.tube(kit, "matte", poll + Vector3(0, 0.02, 0.05), poll + Vector3(0, -0.12, -0.55), 0.15, 0.1, 8, hide, true)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "matte", poll + Vector3(sx * 0.09, 0.08, 0.05), poll + Vector3(sx * 0.14, 0.2, 0.1), 0.035, 0.015, 4, dark)
		pk.box(kit, "matte", Transform3D(Basis(), poll + Vector3(sx * 0.13, 0.0, -0.18)), Vector3(0.03, 0.04, 0.05), SHADOW)
	# Legs: long and knobbly-kneed standing, folded flat under the body lying down.
	for leg in [Vector3(-0.28, 0, -0.5), Vector3(0.28, 0, -0.5), Vector3(-0.26, 0, 0.55), Vector3(0.26, 0, 0.55)]:
		if couched:
			var k0 := Vector3(leg.x * 1.5, 0.18, leg.z - 0.1)
			pk.tube(kit, "matte", Vector3(leg.x, body_y - 0.3, leg.z), k0, 0.12, 0.1, 6, hide, true)
			pk.tube(kit, "matte", k0, k0 + Vector3(0, -0.05, 0.55 if leg.z < 0 else -0.5), 0.09, 0.08, 6, dark, true)
		else:
			var hip := Vector3(leg.x, body_y - 0.35, leg.z)
			var knee := Vector3(leg.x, 0.72, leg.z + (-0.05 if leg.z < 0 else 0.08))
			pk.tube(kit, "matte", hip, knee, 0.13, 0.07, 6, hide, false)
			pk.lathe(kit, "matte", knee, [Vector2(0, -0.06), Vector2(0.08, -0.04), Vector2(0.08, 0.05), Vector2(0, 0.07)], 6, dark)
			pk.tube(kit, "matte", knee, Vector3(leg.x, 0.08, leg.z), 0.06, 0.05, 6, hide, false)
			pk.lathe(kit, "matte", Vector3(leg.x, 0.0, leg.z - 0.04), [Vector2(0, 0), Vector2(0.12, 0.0), Vector2(0.1, 0.08), Vector2(0, 0.09)], 8, dark)
	# The tail.
	pk.tube(kit, "matte", Vector3(0, body_y + 0.2, 0.78), Vector3(0, body_y - 0.45, 0.85), 0.05, 0.03, 5, dark, true)
	if blanket:
		var cols := [Color(0.62, 0.12, 0.10), Color(0.15, 0.22, 0.45), Color(0.70, 0.45, 0.10)]
		var bc: Color = cols[rng.randi() % cols.size()]
		for sx in [-1.0, 1.0]:
			pk.quad(kit, "cloth", [Vector3(sx * 0.52, body_y + 0.2, -0.45), Vector3(sx * 0.52, body_y + 0.2, 0.45), Vector3(sx * 0.58, body_y - 0.35, 0.45), Vector3(sx * 0.58, body_y - 0.35, -0.45)],
					Vector3(sx, 0, 0), bc)
		pk.box(kit, "cloth", Transform3D(Basis(), Vector3(0, body_y + 0.62, 0.05)), Vector3(0.9, 0.12, 0.8), bc.lightened(0.2))


## A dhow at life size (`length` metres, bow toward -z, waterline at y 0): a lofted teak hull, the stem raking forward,
## a high square stern with its gallery, a deck with a rail, the mast raked forward with its long yard and furled
## lateen sail, an awning over the after deck. `lit` strings festoon bulbs from the masthead to bow and stern and
## along the awning (a dinner-cruise dhow at night), and sets lanterns on the rail.
static func dhow(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, length := 18.0, lit := true) -> void:
	var half_w: float = length * 0.15
	var n := 14
	var rings: Array = []
	var deck_pts: Array = []
	for i in range(n + 1):
		var t: float = float(i) / float(n)           # 0 bow (-z) .. 1 stern (+z)
		var z: float = lerpf(-length * 0.5, length * 0.5, t)
		# Plan: a fine bow, full amidships, a broad square-ish stern.
		var w: float = half_w * pow(sin(PI * clampf(t * 0.9 + 0.08, 0.0, 1.0)), 0.55) * (0.55 + 0.45 * smoothstep(0.0, 0.5, t))
		if t > 0.85:
			w = maxf(w, half_w * 0.7)
		# Sheer: rising toward the bow and the stern.
		var top: float = 1.3 + 1.1 * pow(1.0 - t, 2.5) + 1.3 * pow(t, 4.0)
		var keel: float = -1.4 * sin(PI * clampf(t * 1.05, 0.0, 1.0)) - 0.15
		# The stem rakes forward: the bow's top lies ahead of its foot.
		var zt: float = z - (1.0 - t) * (1.0 - t) * 1.8
		rings.append([z, zt, w, top, keel])
		deck_pts.append(Vector2(w * 0.92, zt))
	var wood := Color(0.42, 0.27, 0.15)
	var dark := Color(0.22, 0.14, 0.08)
	var white := Color(0.88, 0.86, 0.80)
	for i in range(n):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for sx in [-1.0, 1.0]:
			# Three panels a side: the bottom (dark antifouling), the side up to the wale, the topsides.
			var pts_a := [Vector3(0, float(a[4]), float(a[0])), Vector3(sx * float(a[2]) * 0.8, -0.5, float(a[0])),
				Vector3(sx * float(a[2]), 0.25, lerpf(float(a[0]), float(a[1]), 0.3)), Vector3(sx * float(a[2]) * 0.96, float(a[3]), float(a[1]))]
			var pts_b := [Vector3(0, float(b[4]), float(b[0])), Vector3(sx * float(b[2]) * 0.8, -0.5, float(b[0])),
				Vector3(sx * float(b[2]), 0.25, lerpf(float(b[0]), float(b[1]), 0.3)), Vector3(sx * float(b[2]) * 0.96, float(b[3]), float(b[1]))]
			for k in range(3):
				var col: Color = [Color(0.18, 0.16, 0.14), white, wood][k]
				var q: Array = [pts_a[k], pts_b[k], pts_b[k + 1], pts_a[k + 1]]
				var nrm: Vector3 = ((q[1] as Vector3) - (q[0] as Vector3)).cross((q[3] as Vector3) - (q[0] as Vector3)).normalized()
				if nrm.x * sx < 0.0:
					nrm = -nrm
				pk.quad(kit, "wood", q, nrm, col)
		# The rail along the sheer.
		for sx2 in [-1.0, 1.0]:
			pk.beam(kit, "wood", Vector3(sx2 * float(a[2]) * 0.96, float(a[3]) + 0.12, float(a[1])),
					Vector3(sx2 * float(b[2]) * 0.96, float(b[3]) + 0.12, float(b[1])), 0.14, 0.24, dark)
	# The transom, the deck (a level platform a little under the sheer amidships).
	var st: Array = rings[n]
	pk.quad(kit, "wood", [Vector3(-float(st[2]), 0.25, float(st[1])), Vector3(float(st[2]), 0.25, float(st[1])),
			Vector3(float(st[2]) * 0.96, float(st[3]), float(st[1])), Vector3(-float(st[2]) * 0.96, float(st[3]), float(st[1]))], Vector3(0, 0, 1), wood)
	var deck_y := 1.15
	pk.block(kit, "wood", Vector3(-half_w * 0.85, deck_y - 0.1, -length * 0.36), Vector3(half_w * 0.85, deck_y, length * 0.44), Color(0.55, 0.40, 0.25))
	# The poop: a raised after deck with a carved gallery on the transom.
	pk.block(kit, "wood", Vector3(-half_w * 0.8, deck_y, length * 0.3), Vector3(half_w * 0.8, deck_y + 1.0, length * 0.5), wood)
	for k in range(5):
		pk.box(kit, "wood", Transform3D(Basis(), Vector3(-half_w * 0.6 + k * half_w * 0.3, deck_y + 1.4, length * 0.5 + 0.05)), Vector3(0.12, 0.7, 0.12), dark)
	pk.beam(kit, "wood", Vector3(-half_w * 0.8, deck_y + 1.8, length * 0.5 + 0.05), Vector3(half_w * 0.8, deck_y + 1.8, length * 0.5 + 0.05), 0.14, 0.14, dark)
	# Mast raked forward, the yard slung across it, the sail furled along the yard.
	var foot := Vector3(0, deck_y, -length * 0.08)
	var head := foot + Vector3(0, length * 0.62, -length * 0.08)
	pk.tube(kit, "wood", foot, head, 0.17, 0.11, 8, wood)
	var yard_a := head + Vector3(0, -1.2, -length * 0.42) + Vector3(0, -length * 0.18, 0)
	var yard_b := head + Vector3(0, -1.0, length * 0.38) + Vector3(0, length * 0.08, 0)
	pk.tube(kit, "wood", yard_a, yard_b, 0.08, 0.06, 6, dark)
	pk.tube(kit, "cloth", yard_a.lerp(yard_b, 0.06) + Vector3(0, -0.22, 0), yard_a.lerp(yard_b, 0.92) + Vector3(0, -0.22, 0), 0.22, 0.12, 8, Color(0.92, 0.88, 0.78))
	# Stays from the masthead to the stem and the stern.
	var stem: Vector3 = Vector3(0, float(rings[0][3]) + 0.2, float(rings[0][1]))
	var stern := Vector3(0, deck_y + 1.9, length * 0.48)
	pk.beam(kit, "matte", head, stem, 0.03, 0.03, Color(0.3, 0.26, 0.2))
	pk.beam(kit, "matte", head, stern, 0.03, 0.03, Color(0.3, 0.26, 0.2))
	# An awning over the after deck on poles.
	var aw0 := length * 0.06
	var aw1 := length * 0.42
	for z in [aw0, (aw0 + aw1) * 0.5, aw1]:
		for sx in [-1.0, 1.0]:
			pk.tube(kit, "wood", Vector3(sx * half_w * 0.75, deck_y, z), Vector3(sx * half_w * 0.75, deck_y + 2.3, z), 0.05, 0.05, 5, dark)
	var aw_col: Color = [Color(0.85, 0.80, 0.70), Color(0.62, 0.16, 0.12), Color(0.18, 0.30, 0.50)][rng.randi() % 3]
	pk.panel(kit, "cloth", [Vector3(-half_w * 0.85, deck_y + 2.3, aw0), Vector3(half_w * 0.85, deck_y + 2.3, aw0),
			Vector3(half_w * 0.85, deck_y + 2.3, aw1), Vector3(-half_w * 0.85, deck_y + 2.3, aw1)], Vector3.UP, aw_col, aw_col.darkened(0.4))
	# Tables and cushions under the awning.
	for k in range(3):
		var z: float = lerpf(aw0 + 1.0, aw1 - 1.0, float(k) / 2.0)
		pk.block(kit, "wood", Vector3(-0.6, deck_y, z - 0.5), Vector3(0.6, deck_y + 0.45, z + 0.5), wood)
		for sx in [-1.0, 1.0]:
			pk.block(kit, "cloth", Vector3(sx * 1.05 - 0.3, deck_y, z - 0.6), Vector3(sx * 1.05 + 0.3, deck_y + 0.3, z + 0.6), aw_col.lightened(0.3))
	if not lit:
		return
	var bulb := Color(1.0, 0.82, 0.5)
	for line in [[head, stem], [head, stern]]:
		var a3: Vector3 = line[0]
		var b3: Vector3 = line[1]
		var cnt: int = int(a3.distance_to(b3) / 0.9)
		for k in range(1, cnt):
			var p: Vector3 = a3.lerp(b3, float(k) / cnt) + Vector3(0, -sin(PI * float(k) / cnt) * 0.4, 0)
			pk.box(kit, "lamp", Transform3D(Basis(), p), Vector3(0.12, 0.12, 0.12), bulb)
	for sx in [-1.0, 1.0]:
		var cnt2 := 14
		for k in range(cnt2 + 1):
			var z: float = lerpf(aw0, aw1, float(k) / cnt2)
			pk.box(kit, "lamp", Transform3D(Basis(), Vector3(sx * half_w * 0.86, deck_y + 2.2, z)), Vector3(0.11, 0.11, 0.11), bulb)
	for z in [-length * 0.3, length * 0.2]:
		for sx in [-1.0, 1.0]:
			pk.box(kit, "lamp", Transform3D(Basis(), Vector3(sx * half_w * 0.9, 2.0, z)), Vector3(0.22, 0.32, 0.22), Color(1.0, 0.7, 0.35))


## The roundabout's island and fountain (Marina Nights), in metres (scale 1), the middle at the origin on the ground:
## a kerb ring of radius `r`, a planted ring with a low wall, the basin (its rim at `r * 0.68`, water 0.6m up, glowing
## lamps round its inside), a three-tiered fountain in the middle on a fluted column. FountainShow.gd adds the water,
## the jets and the lights.
static func fountain(pk: PropKit, kit: Dictionary, r: float) -> void:
	var stone := Color(0.86, 0.80, 0.70)
	var dark := Color(0.40, 0.34, 0.28)
	pk.lathe(kit, "stone", Vector3.ZERO, [Vector2(r - 0.2, -0.5), Vector2(r, 0.3), Vector2(r - 0.4, 0.35), Vector2(r - 0.6, 0.3)], 48, stone)
	# Planting: a dark soil ring between the kerb and the bed wall.
	var rb: float = r * 0.68
	pk.lathe(kit, "matte", Vector3.ZERO, [Vector2(r - 0.6, 0.3), Vector2(rb + 0.8, 0.45)], 48, Color(0.16, 0.13, 0.10))
	# The basin: an outer wall with a moulded coping, its inside face, the floor.
	pk.lathe(kit, "stone", Vector3.ZERO, [Vector2(rb + 0.8, 0.45), Vector2(rb + 0.8, 1.0), Vector2(rb + 1.0, 1.05), Vector2(rb + 1.0, 1.25),
			Vector2(rb, 1.3), Vector2(rb - 0.1, 1.2)], 48, stone)
	# Its inside face (the profile running down faces inward) and the floor.
	pk.lathe(kit, "stone", Vector3.ZERO, [Vector2(rb - 0.1, 1.2), Vector2(rb - 0.1, 0.05)], 48, dark)
	pk.lathe(kit, "matte", Vector3.ZERO, [Vector2(rb - 0.1, 0.05), Vector2(0.0, 0.05)], 48, Color(0.08, 0.12, 0.14))
	# Lamps round the basin's inside, under the water line.
	for k in range(24):
		var a: float = TAU * k / 24.0
		pk.box(kit, "lamp", Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a), 0, sin(a)) * (rb - 0.3) + Vector3(0, 0.35, 0)), Vector3(0.25, 0.2, 0.5), Color(1.0, 0.95, 0.85))
	# The column and three bowls.
	pk.lathe(kit, "stone", Vector3.ZERO, [Vector2(2.6, 0.0), Vector2(2.4, 0.8), Vector2(1.2, 1.4), Vector2(0.9, 2.2), Vector2(0.8, 6.5), Vector2(0.6, 11.0)], 20, stone)
	for t in [[2.2, 6.0, 0.8], [5.8, 3.8, 0.6], [9.4, 2.2, 0.45]]:
		var y: float = t[0]
		var br: float = t[1]
		var dep: float = t[2]
		pk.lathe(kit, "stone", Vector3(0, y, 0), [Vector2(0.6, -dep), Vector2(br * 0.7, -dep * 0.6), Vector2(br, 0.0), Vector2(br + 0.15, 0.12),
				Vector2(br - 0.05, 0.16), Vector2(0.0, 0.0)], 32, stone)
		# A ring of glowing lamps under each bowl's lip.
		for k in range(16):
			var a2: float = TAU * k / 16.0
			pk.box(kit, "lamp", Transform3D(Basis(), Vector3(cos(a2), 0, sin(a2)) * (br - 0.1) + Vector3(0, y - 0.15, 0)), Vector3(0.2, 0.1, 0.2), Color(1.0, 0.92, 0.75))
	pk.lathe(kit, "metal", Vector3(0, 11.0, 0), [Vector2(0.0, 0.0), Vector2(0.5, 0.3), Vector2(0.3, 1.0), Vector2(0.12, 1.6), Vector2(0.0, 2.2)], 12, BRASS)


## Bab al-Lulu, the Pearl Ring (Marina Nights): a gilded ring `radius` metres to its centre line standing over the road,
## its centre `hc` up, on two tapering pylons either side (lateral ±x); a frieze of eight-pointed stars round its face,
## LED strips round its inside edge, a glowing pearl at its crown. Built in metres in its own frame (the road along z).
static func pearl_ring(pk: PropKit, kit: Dictionary, radius: float, tube: float, hc: float) -> void:
	var gold := Color(0.86, 0.66, 0.28)
	var segs := 64
	var rings := 12
	# The torus, in the x-y plane (the road passes through along z).
	for i in range(segs):
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		for j in range(rings):
			var b0: float = TAU * j / rings
			var b1: float = TAU * (j + 1) / rings
			var pts: Array = []
			var nrm: Array = []
			for ab in [[a0, b0], [a1, b0], [a1, b1], [a0, b1]]:
				var ca: Vector3 = Vector3(cos(ab[0]), sin(ab[0]), 0)
				var n: Vector3 = ca * cos(ab[1]) + Vector3(0, 0, 1) * sin(ab[1])
				pts.append(Vector3(0, hc, 0) + ca * radius + n * tube)
				nrm.append(n)
			var nm: Vector3 = ((nrm[0] as Vector3) + nrm[2]).normalized()
			pk.tri(kit, "metal", pts[0], pts[1], pts[2], nrm[0], nrm[1], nrm[2], gold, nm)
			pk.tri(kit, "metal", pts[0], pts[2], pts[3], nrm[0], nrm[2], nrm[3], gold, nm)
	# LED strips on the inside edge (both faces' inner rims) and stars round both faces.
	for i in range(segs):
		var a0: float = TAU * i / segs
		var a1: float = TAU * (i + 1) / segs
		for zf in [-1.0, 1.0]:
			var p0 := Vector3(0, hc, 0) + Vector3(cos(a0), sin(a0), 0) * (radius - tube * 0.75) + Vector3(0, 0, zf * tube * 0.7)
			var p1 := Vector3(0, hc, 0) + Vector3(cos(a1), sin(a1), 0) * (radius - tube * 0.75) + Vector3(0, 0, zf * tube * 0.7)
			pk.beam(kit, "lamp", p0, p1, 0.18, 0.18, Color(0.55, 0.85, 1.0))
	for i in range(16):
		var a: float = TAU * (float(i) + 0.5) / 16.0
		for zf in [-1.0, 1.0]:
			var c := Vector3(0, hc, 0) + Vector3(cos(a), sin(a), 0) * radius + Vector3(0, 0, zf * (tube + 0.05))
			for k in range(2):
				var rot := Basis(Vector3(0, 0, 1), a + PI * 0.25 * k)
				pk.box(kit, "lamp", Transform3D(rot, c), Vector3(1.3, 1.3, 0.12), Color(1.0, 0.85, 0.5))
	# The pearl at the crown.
	pk.lathe(kit, "lamp", Vector3(0, hc + radius + tube - 0.2, 0), [Vector2(0, 0), Vector2(1.2, 0.4), Vector2(1.6, 1.5), Vector2(1.2, 2.6), Vector2(0, 3.0)], 16, Color(1.0, 0.97, 0.92))
	# The pylons: tapering, faced in stone with gold bands, from the ground up to the ring's sides.
	var px: float = radius + tube + 0.9
	for sx in [-1.0, 1.0]:
		pk.block(kit, "stone", Vector3(sx * px - 2.2, -1.0, -2.2), Vector3(sx * px + 2.2, 1.2, 2.2), Color(0.80, 0.74, 0.64))
		pk.tube(kit, "stone", Vector3(sx * px, 1.2, 0), Vector3(sx * px, hc + 1.0, 0), 1.6, 1.0, 8, Color(0.88, 0.82, 0.72))
		for y in [3.0, hc * 0.5, hc - 1.0]:
			pk.tube(kit, "metal", Vector3(sx * px, y, 0), Vector3(sx * px, y + 0.5, 0), lerpf(1.62, 1.02, y / hc), lerpf(1.6, 1.0, y / hc), 8, gold)
		pk.box(kit, "lamp", Transform3D(Basis(), Vector3(sx * px, 1.4, 0)), Vector3(1.0, 0.4, 3.6), Color(1.0, 0.85, 0.55))


## A motor superyacht `length` metres long at life size (bow toward -z, waterline y 0): a sharp white hull with a dark
## boot stripe, three decks stepping back with dark glass bands lit from within, a radar arch, a sun deck, blue light
## under the stern and portholes along the hull. Lights on (`lit`), for the night.
static func superyacht(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, length := 40.0) -> void:
	var white := Color(0.94, 0.94, 0.95)
	var hw: float = length * 0.1
	var fb: float = length * 0.08
	var n := 16
	var rings: Array = []
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		var z: float = lerpf(-length * 0.5, length * 0.5, t)
		var w: float = hw * pow(clampf(t * 1.25, 0.0, 1.0), 0.5)
		var top: float = fb + 0.6 * pow(1.0 - t, 2.0)
		var zt: float = z - (1.0 - t) * (1.0 - t) * length * 0.06
		rings.append([z, zt, w, top])
	for i in range(n):
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for sx in [-1.0, 1.0]:
			var pa := [Vector3(0, -length * 0.03, float(a[0])), Vector3(sx * float(a[2]) * 0.85, -0.2, float(a[0])), Vector3(sx * float(a[2]), 0.25, float(a[0])),
				Vector3(sx * float(a[2]), float(a[3]), float(a[1]))]
			var pb := [Vector3(0, -length * 0.03, float(b[0])), Vector3(sx * float(b[2]) * 0.85, -0.2, float(b[0])), Vector3(sx * float(b[2]), 0.25, float(b[0])),
				Vector3(sx * float(b[2]), float(b[3]), float(b[1]))]
			for k in range(3):
				var col: Color = [Color(0.10, 0.12, 0.16), Color(0.12, 0.14, 0.20), white][k]
				var q: Array = [pa[k], pb[k], pb[k + 1], pa[k + 1]]
				var nrm: Vector3 = ((q[1] as Vector3) - (q[0] as Vector3)).cross((q[3] as Vector3) - (q[0] as Vector3)).normalized()
				if nrm.x * sx < 0.0:
					nrm = -nrm
				pk.quad(kit, "gloss", q, nrm, col)
		# Portholes, lit.
		if i % 2 == 0 and i > 2 and i < n - 1:
			for sx2 in [-1.0, 1.0]:
				pk.box(kit, "lamp", Transform3D(Basis(), Vector3(sx2 * float(a[2]) * 1.005, fb * 0.55, float(a[0]))), Vector3(0.05, 0.28, 0.4), Color(1.0, 0.88, 0.65))
	var st: Array = rings[n]
	pk.quad(kit, "gloss", [Vector3(-float(st[2]), 0.25, float(st[1])), Vector3(float(st[2]), 0.25, float(st[1])), Vector3(float(st[2]), float(st[3]), float(st[1])),
			Vector3(-float(st[2]), float(st[3]), float(st[1]))], Vector3(0, 0, 1), white)
	pk.block(kit, "gloss", Vector3(-hw * 0.95, fb - 0.1, -length * 0.38), Vector3(hw * 0.95, fb, length * 0.5), Color(0.62, 0.48, 0.32))
	# Three decks stepping back and in, each a white band over a dark glass band.
	var y := fb
	var z0: float = -length * 0.25
	var z1: float = length * 0.38
	var w2: float = hw * 0.88
	for deck in range(3):
		var h: float = 2.6
		pk.block(kit, "glass", Vector3(-w2, y, z0 + 0.6), Vector3(w2, y + h * 0.7, z1 - 0.6), Color(0.06, 0.08, 0.12, 1.0))
		# Lit rooms behind the glass.
		for k in range(int((z1 - z0) / 3.0)):
			if rng.randf() < 0.65:
				var zz: float = z0 + 1.5 + k * 3.0
				for sx in [-1.0, 1.0]:
					pk.box(kit, "lamp", Transform3D(Basis(), Vector3(sx * (w2 + 0.01), y + h * 0.35, zz)), Vector3(0.02, h * 0.55, 2.4), Color(1.0, 0.86, 0.62))
		pk.block(kit, "gloss", Vector3(-w2 - 0.25, y + h * 0.7, z0), Vector3(w2 + 0.25, y + h, z1), white)
		# The raked front.
		pk.quad(kit, "glass", [Vector3(-w2, y, z0 + 0.6), Vector3(w2, y, z0 + 0.6), Vector3(w2, y + h * 0.7, z0 + 2.0), Vector3(-w2, y + h * 0.7, z0 + 2.0)],
				Vector3(0, 0.5, -1).normalized(), Color(0.06, 0.08, 0.12, 1.0))
		y += h
		z0 += length * 0.08
		z1 -= length * 0.1
		w2 *= 0.9
	# The radar arch and mast lights.
	var ac: float = (z0 + z1) * 0.5
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "gloss", Vector3(sx * w2, y, ac + 1.0), Vector3(sx * w2 * 0.4, y + 3.0, ac), 0.4, 0.6, white)
	pk.beam(kit, "gloss", Vector3(-w2 * 0.45, y + 3.0, ac), Vector3(w2 * 0.45, y + 3.0, ac), 0.5, 0.6, white)
	pk.tube(kit, "metal", Vector3(0, y + 3.3, ac), Vector3(0, y + 6.5, ac), 0.12, 0.08, 6, Color(0.8, 0.8, 0.8))
	pk.box(kit, "lamp", Transform3D(Basis(), Vector3(0, y + 6.6, ac)), Vector3(0.3, 0.3, 0.3), Color(1.0, 1.0, 1.0))
	pk.box(kit, "lamp", Transform3D(Basis(), Vector3(-hw * 0.9, fb + 0.4, -length * 0.3)), Vector3(0.2, 0.2, 0.2), Color(1.0, 0.1, 0.1))
	pk.box(kit, "lamp", Transform3D(Basis(), Vector3(hw * 0.9, fb + 0.4, -length * 0.3)), Vector3(0.2, 0.2, 0.2), Color(0.1, 1.0, 0.2))
	# Blue underwater light off the stern.
	pk.quad(kit, "lamp", [Vector3(-hw * 1.4, -0.3, length * 0.45), Vector3(hw * 1.4, -0.3, length * 0.45), Vector3(hw * 1.8, -0.3, length * 0.62), Vector3(-hw * 1.8, -0.3, length * 0.62)],
			Vector3.UP, Color(0.15, 0.45, 1.0))


## A floating pontoon walkway from `a` to `b` (y at the deck), `w` wide: timber planks on dark floats, cleats, a light
## post every 12m.
static func pontoon(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, w := 2.4) -> void:
	var d := b - a
	var length := d.length()
	var dir := d / length
	var side := Vector3.UP.cross(dir).normalized()
	var basis := Basis(side, Vector3.UP, dir)
	pk.box(kit, "matte", Transform3D(basis, (a + b) * 0.5 - Vector3(0, 0.35, 0)), Vector3(w * 0.9, 0.5, length), Color(0.10, 0.10, 0.11))
	pk.box(kit, "timber", Transform3D(basis, (a + b) * 0.5), Vector3(w, 0.12, length), Color(0.52, 0.40, 0.28), uvk)
	var cnt: int = int(length / 12.0)
	for k in range(cnt + 1):
		var p: Vector3 = a + dir * (length * float(k) / maxf(cnt, 1))
		pk.tube(kit, "metal", p + side * (w * 0.5 - 0.1), p + side * (w * 0.5 - 0.1) + Vector3(0, 1.1, 0), 0.05, 0.05, 6, Color(0.85, 0.85, 0.85))
		pk.box(kit, "lamp", Transform3D(basis, p + side * (w * 0.5 - 0.1) + Vector3(0, 1.2, 0)), Vector3(0.18, 0.18, 0.18), Color(1.0, 0.9, 0.7))
