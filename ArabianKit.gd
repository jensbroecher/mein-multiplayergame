extends RefCounted
## The Al-Raihana GP's buildings and set pieces (Mountain Pass, Desert Wadi), built through a PropKit at life
## size (y up, the front toward -z) and grown by the caller (PROP_SCALE 1.6, as on every stage). A fictional
## Gulf country: mud-brick forts and watchtowers, houses with wind towers (barjeel) and carved doors, palm-
## frond huts (barasti) in the date gardens, Bedouin tents of black goat hair, the lamps along the mountain
## road, and on the horizon a modern city of tall towers. Nothing here copies a real building.
##
## Materials (keys): "mud" (hut_masonry 3, sun-baked mud plaster over stone: COLOR.a 1 lets the plaster flake on
## flat walls), "lime" (hut_masonry 1, lime-washed plaster), "stucco" (hut_masonry 4), "stone" (hut_masonry 0),
## "timber" / "painted" (hut_wood), "frond" (palm-frond thatch: hut_thatch), "cloth" (two-sided vertex colour: for single faces), "awning" (one-sided: for PropKit.panel, which lays both faces),
## and CampKit's "matte", "metal", "steel", "glass", "lamp", "wood". The hut shaders read UVs in world metres,
## so every UV is multiplied by `uvk`, the caller's scale.
##
## Builders take the kit and a local frame (`at`, a Transform3D in the kit's life-size units). Each fills the
## kit; the caller commits it (`commit`, with the tangents the masonry's normal maps need).

const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")

static var uvk := 1.6
static var _mats := {}
## Set by a night or dusk stage's generator (Ramlat Hamra): "lamp" glows (LampGlow.gd). CampKit's gives off no light,
## which suits the day stages (Jebel Sahar, Wadi al-Ghaf).
static var lamps_glow := false

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
		"awning":
			# One-sided canvas for PropKit.panel(), which lays its own back face: in "cloth" (drawn from both sides)
			# the two coplanar faces z-fought (the souk's awnings flickered).
			var aw := CampKit.make_material("canvas")
			aw.roughness = 0.97
			return aw
		"dark":
			var d := CampKit.make_material("matte")
			d.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			return d
		"lamp":
			if lamps_glow:
				return load("res://LampGlow.gd").material()
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
static func door(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, col := TEAK, surround := LIME, gable := true) -> void:
	var o := out.normalized()
	var side := Vector3.UP.cross(o).normalized()
	var basis := Basis(side, Vector3.UP, o)
	# The surround: a frame with a pointed head (a block and a pyramid-ish gable).
	pk.box(kit, "lime", Transform3D(basis, c + o * 0.06 + Vector3(0, h * 0.5 + 0.1, 0)), Vector3(w + 0.6, h + 0.2, 0.12), Color(surround.r, surround.g, surround.b, 0.0), uvk)
	if gable:
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
		tower := true, yard := true, yard_d := -1.0) -> float:
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
		# A caller packing houses gives the yard's depth (the draw is still made, so other callers' houses keep theirs).
		if yard_d > 0.0:
			yd = yard_d
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


const MUD_RED := Color(0.72, 0.48, 0.33)
const WHITE := Color(0.95, 0.93, 0.88)
const STONE_FOOT := Color(0.62, 0.55, 0.46)
## Shutters: weathered teal, faded ochre, oxblood, bare teak.
const NAJDI_SHUTTER := [Color(0.30, 0.44, 0.45), Color(0.62, 0.44, 0.24), Color(0.44, 0.20, 0.15), Color(0.36, 0.25, 0.16)]
const NAJDI_PAINT := [Color(0.72, 0.18, 0.14), Color(0.16, 0.36, 0.56), Color(0.90, 0.70, 0.20), Color(0.18, 0.46, 0.30), Color(0.92, 0.90, 0.84)]


## A fort round a square courtyard `side` across (centred on the origin), its gate toward -z, in a style: 0 the
## Omani round-towered fort of Jebel Sahar (`fort_omani`), 1 the Najdi square-towered fortress of Wadi al-Ghaf
## (`fort_najdi`). Returns the footprint radius.
static func fort(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, side := 46.0, wall_h := 8.0, style := 0) -> float:
	if style == 1:
		return fort_najdi(pk, kit, rng, side, wall_h)
	return fort_omani(pk, kit, rng, side, wall_h)


# ======================================================================================
#  Fort pieces
# ======================================================================================

## A round tower in tiers, each a battered drum set back from the one below: `tiers` is [height, foot radius, top
## radius] from the bottom up. Every tier has a lime band a third of the way up, two staggered rows of loopholes, the
## floor's poles standing out under its top, a moulded band and waterspouts; merlons round the ledge where the next
## tier steps back, and a parapet with merlons on the last. A rubble footing under it all. Returns the parapet's top.
static func tiered_tower(pk: PropKit, kit: Dictionary, key: String, foot: Vector3, tiers: Array, col: Color) -> float:
	var segs := 22
	var r_first: float = (tiers[0] as Array)[1]
	# A rubble plinth flaring out under the ground: where a pad's edge falls away it shows as a talus, not a drum.
	pk.tube(kit, "stone", foot - Vector3(0, 6.0, 0), foot + Vector3(0, 0.45, 0), r_first + 2.4, r_first + 0.3, segs, STONE_FOOT, true, uvk)
	var y := 0.0
	for ti in range(tiers.size()):
		var t: Array = tiers[ti]
		var th: float = t[0]
		var ra: float = t[1]
		var rb: float = t[2]
		var base := foot + Vector3(0, y, 0)
		pk.tube(kit, key, base - Vector3(0, 0.2, 0), base + Vector3(0, th, 0), ra, rb, segs, Color(col.r, col.g, col.b, 0.3), true, uvk)
		var yb: float = th * 0.34
		var rbnd: float = lerpf(ra, rb, yb / th) + 0.035
		pk.tube(kit, "stucco", base + Vector3(0, yb, 0), base + Vector3(0, yb + 0.3, 0), rbnd, rbnd - 0.004, segs, Color(LIME.r, LIME.g, LIME.b, 0.0), false, uvk)
		for row in range(2):
			var ly: float = th * (0.52 + 0.24 * float(row))
			var lr: float = lerpf(ra, rb, ly / th)
			var nl: int = maxi(4, int(TAU * lr / 3.0))
			for k in range(nl):
				var a: float = TAU * (float(k) + 0.5 * float(row)) / float(nl)
				var dir := Vector3(cos(a), 0, sin(a))
				pk.box(kit, "dark", Transform3D(Basis.looking_at(dir, Vector3.UP), base + Vector3(0, ly, 0) + dir * (lr + 0.02)), Vector3(0.14, 0.72, 0.06), SHADOW)
		var top := base + Vector3(0, th, 0)
		var np: int = maxi(8, int(TAU * rb / 0.95))
		for k in range(np):
			var a2: float = TAU * float(k) / float(np)
			var d2 := Vector3(cos(a2), 0, sin(a2))
			pk.tube(kit, "timber", top + d2 * (rb - 0.12) - Vector3(0, 0.6, 0), top + d2 * (rb + 0.34) - Vector3(0, 0.6, 0), 0.07, 0.065, 5, POLE, true, uvk)
		pk.tube(kit, key, top - Vector3(0, 0.32, 0), top + Vector3(0, 0.1, 0), rb + 0.24, rb + 0.24, segs, Color(col.r * 1.04, col.g * 1.04, col.b * 1.04, 0.0), true, uvk)
		if ti == tiers.size() - 1:
			pk.tube(kit, key, top, top + Vector3(0, 1.0, 0), rb + 0.14, rb + 0.14, segs, Color(col.r, col.g, col.b, 0.0), true, uvk)
			merlon_ring(pk, kit, key, top + Vector3(0, 1.0, 0), rb - 0.08, col, maxi(10, int(rb * 4.4)))
		else:
			merlon_ring(pk, kit, key, top + Vector3(0, 0.1, 0), rb + 0.06, col, maxi(10, int(rb * 4.4)))
		for k in range(4):
			var a3: float = TAU * (float(k) + 0.25) / 4.0 + float(ti) * 0.4
			var d3 := Vector3(cos(a3), 0, sin(a3))
			pk.beam(kit, "timber", top + d3 * (rb - 0.2) + Vector3(0, 0.3, 0), top + d3 * (rb + 0.9) + Vector3(0, 0.36, 0), 0.16, 0.16, POLE, Vector3.ZERO, uvk)
		y += th
	return foot.y + y + 1.0


## A battered curtain wall's outer face dressed from a to b (its foot, along the wall), `out` its outward normal, `h`
## high, leaning in `batter` over its height: lime bands, buttresses every 8.5m, two rows of loopholes, waterspouts under
## the walkway, a machicolation a third of the way from each end. `skip` metres either side of its middle are left
## bare (a gatehouse stands there).
static func wall_dress(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, out: Vector3, h: float, batter: float, col: Color, skip := 0.0) -> void:
	var o := out.normalized()
	var d := b - a
	var L := d.length()
	var along := d / L
	var basis := Basis(along, Vector3.UP, o)
	var mid := (a + b) * 0.5
	var inset := func(y: float) -> float:
		return batter * clampf((y - 0.6) / maxf(h - 0.6, 0.1), 0.0, 1.0)
	var clear := func(p: Vector3) -> bool:
		return skip <= 0.0 or absf((p - mid).dot(along)) > skip
	for yb in [h * 0.34, h - 0.55]:
		var segs_b: Array = [[0.0, L]] if skip <= 0.0 else [[0.0, L * 0.5 - skip], [L * 0.5 + skip, L]]
		for sg in segs_b:
			var s0: float = sg[0]
			var s1: float = sg[1]
			if s1 - s0 < 0.5:
				continue
			var c: Vector3 = a + along * ((s0 + s1) * 0.5) + Vector3(0, yb, 0) + o * (0.06 - float(inset.call(yb)))
			pk.box(kit, "stucco", Transform3D(basis, c), Vector3(s1 - s0, 0.26, 0.12), Color(LIME.r, LIME.g, LIME.b, 0.0), uvk)
	var n_b: int = maxi(1, int(L / 8.5))
	for i in range(n_b + 1):
		var p: Vector3 = a + along * (L * float(i) / float(n_b))
		if not clear.call(p) or i == 0 or i == n_b:
			continue
		var c2: Vector3 = p + Vector3(0, h * 0.5, 0) + o * (0.2 - float(inset.call(h * 0.5)))
		pk.box(kit, "mud", Transform3D(basis, c2), Vector3(0.95, h - 1.4, 0.4), Color(col.r * 0.97, col.g * 0.97, col.b * 0.97, 0.3), uvk)
	for row in range(2):
		var ly: float = h * (0.55 + 0.23 * float(row))
		var n_l: int = maxi(1, int(L / 2.4))
		for i in range(n_l):
			var p2: Vector3 = a + along * (L * (float(i) + 0.5 + 0.5 * float(row)) / float(n_l))
			if not clear.call(p2):
				continue
			if (p2 - a).length() > L - 0.6:
				continue
			pk.box(kit, "dark", Transform3D(basis, p2 + Vector3(0, ly, 0) + o * (0.03 - float(inset.call(ly)))), Vector3(0.14, 0.7, 0.04), SHADOW)
	var n_s: int = maxi(1, int(L / 6.0))
	for i in range(n_s):
		var p3: Vector3 = a + along * (L * (float(i) + 0.5) / float(n_s)) + Vector3(0, h - 0.25, 0)
		if not clear.call(p3):
			continue
		pk.beam(kit, "timber", p3 - o * (float(inset.call(h)) + 0.2), p3 + o * (0.9 - float(inset.call(h))), 0.16, 0.16, POLE, Vector3.ZERO, uvk)
	for f in [0.28, 0.72]:
		var p4: Vector3 = a + along * (L * float(f))
		if not clear.call(p4):
			continue
		var cm: Vector3 = p4 + Vector3(0, h - 0.45, 0) + o * (0.45 - float(inset.call(h)))
		pk.box(kit, "mud", Transform3D(basis, cm), Vector3(2.4, 1.6, 0.9), Color(col.r, col.g, col.b, 0.2), uvk)
		for k in range(3):
			pk.box(kit, "dark", Transform3D(basis, cm + along * ((float(k) - 1.0) * 0.7) + o * 0.46 + Vector3(0, -0.2, 0)), Vector3(0.16, 0.55, 0.02), SHADOW)
		pk.box(kit, "dark", Transform3D(basis, cm + Vector3(0, -0.81, 0) + o * 0.1), Vector3(2.2, 0.02, 0.7), SHADOW)


## An old bronze cannon on a timber carriage with spoked wheels, at `c`, its muzzle toward `dir`.
static func cannon(pk: PropKit, kit: Dictionary, c: Vector3, dir: Vector3) -> void:
	var o := Vector3(dir.x, 0, dir.z).normalized()
	var side := Vector3.UP.cross(o).normalized()
	var basis := Basis(side, Vector3.UP, o)
	pk.box(kit, "timber", Transform3D(basis, c + Vector3(0, 0.5, 0) - o * 0.1), Vector3(0.72, 0.34, 1.7), TEAK_DARK, uvk)
	var axb := Basis(o, side, o.cross(side))
	for sd in [-1.0, 1.0]:
		pk.tyre(kit, "timber", c + side * (sd * 0.46) + o * 0.35 + Vector3(0, 0.42, 0), 0.06, 0.42, 0.12, 12, TEAK_DARK, axb)
	pk.tube(kit, "metal", c + Vector3(0, 0.88, 0) - o * 0.75, c + Vector3(0, 0.98, 0) + o * 1.35, 0.22, 0.14, 12, Color(0.34, 0.28, 0.18))
	pk.tube(kit, "metal", c + Vector3(0, 0.98, 0) + o * 1.25, c + Vector3(0, 0.98, 0) + o * 1.42, 0.17, 0.17, 12, Color(0.34, 0.28, 0.18))


## Al-Raihana's flag on a pole from `foot`, `h` tall, flying toward `fly` (static): a maroon field, a gold band at the
## hoist and a gold eight-pointed star, as on the flag carrier's tails (AirlinerKit's "raihana"). Fictional.
static func national_flag(pk: PropKit, kit: Dictionary, foot: Vector3, h: float, fly := Vector3.RIGHT) -> void:
	pk.tube(kit, "metal", foot, foot + Vector3(0, h, 0), 0.07, 0.05, 6, Color(0.78, 0.78, 0.76))
	pk.tube(kit, "metal", foot + Vector3(0, h, 0), foot + Vector3(0, h + 0.14, 0), 0.1, 0.1, 6, BRASS)
	var fw := 2.6
	var fh := 1.6
	var f := Vector3(fly.x, 0, fly.z).normalized()
	var nrm := Vector3.UP.cross(f).normalized()
	var top: float = foot.y + h - 0.15
	var p0 := Vector3(foot.x, top - fh, foot.z) + f * 0.06
	pk.quad(kit, "cloth", [p0, p0 + f * fw, p0 + f * fw + Vector3(0, fh, 0), p0 + Vector3(0, fh, 0)], nrm, Color(0.50, 0.08, 0.14))
	for sgn in [1.0, -1.0]:
		var lift: Vector3 = nrm * (0.012 * sgn)
		var n2: Vector3 = nrm * sgn
		pk.quad(kit, "cloth", [p0 + lift, p0 + lift + f * 0.5, p0 + lift + f * 0.5 + Vector3(0, fh, 0), p0 + lift + Vector3(0, fh, 0)], n2, Color(0.86, 0.66, 0.22))
		var sc: Vector3 = p0 + lift + f * (fw * 0.6) + Vector3(0, fh * 0.5, 0)
		for k in range(2):
			var a0: float = PI * 0.25 * float(k)
			var pts: Array = []
			for j in range(4):
				var a: float = a0 + PI * 0.5 * float(j)
				pts.append(sc + f * (cos(a) * 0.42) + Vector3(0, sin(a) * 0.42, 0))
			pk.quad(kit, "cloth", pts if sgn > 0 else [pts[3], pts[2], pts[1], pts[0]], n2, Color(0.86, 0.66, 0.22))


## A lookout kiosk (barza) on a roof at `c`: four piers under a flat roof with merlons round it.
static func kiosk(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: float, col: Color) -> void:
	for k in range(4):
		var a: float = TAU * (float(k) + 0.5) / 4.0
		var p := c + Vector3(cos(a), 0, sin(a)) * r
		pk.box(kit, key, Transform3D(Basis(), p + Vector3(0, 1.25, 0)), Vector3(0.5, 2.5, 0.5), Color(col.r, col.g, col.b, 0.0), uvk)
	slab(pk, kit, key, c + Vector3(-r - 0.45, 2.5, -r - 0.45), c + Vector3(r + 0.45, 2.85, r + 0.45), col, 0.0)
	var e: float = r + 0.3
	for sides in [[Vector3(-e, 2.85, -e), Vector3(e, 2.85, -e)], [Vector3(e, 2.85, -e), Vector3(e, 2.85, e)], [Vector3(e, 2.85, e), Vector3(-e, 2.85, e)], [Vector3(-e, 2.85, e), Vector3(-e, 2.85, -e)]]:
		merlons(pk, kit, key, c + (sides[0] as Vector3), c + (sides[1] as Vector3), col, 0.8, 0.4, 0.3, 0.5)


## A row of triangles along a wall face from `a` to `b` (their bases at one height), pointing up, `size` wide with `gap`
## between them, facing `out`: white painted ones laid on the plaster, or dark vents (`dark`), as on Najdi walls.
static func triangles(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, out: Vector3, size: float, gap: float, dark: bool) -> void:
	var d := b - a
	var L := d.length()
	if L < size:
		return
	var along := d / L
	var o := out.normalized()
	var n: int = maxi(1, int(L / (size + gap)))
	var step: float = L / float(n)
	for i in range(n):
		var c: Vector3 = a + along * (step * (float(i) + 0.5)) + o * (0.035 if dark else 0.03)
		var p0: Vector3 = c - along * (size * 0.5)
		var p1: Vector3 = c + along * (size * 0.5)
		var p2: Vector3 = c + Vector3(0, size * 0.72, 0)
		if dark:
			pk.tri(kit, "dark", p0, p1, p2, o, o, o, SHADOW, o)
		else:
			pk.tri(kit, "stucco", p0, p1, p2, o, o, o, Color(WHITE.r, WHITE.g, WHITE.b, 0.0), o)


## A Najdi door on a wall facing `out`, its foot's middle at `c`: a white surround under a heavy timber lintel, two
## leaves of teak painted with bands of sawtooth triangles in red, blue, ochre and green on a white line, a painted
## diamond on each leaf between the bands, a ring knocker. The paint stands 1.2cm proud of the leaves.
static func najdi_door(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, c: Vector3, out: Vector3, w: float, h: float) -> void:
	var o := out.normalized()
	var side := Vector3.UP.cross(o).normalized()
	var basis := Basis(side, Vector3.UP, o)
	pk.box(kit, "stucco", Transform3D(basis, c + o * 0.05 + Vector3(0, h * 0.5 + 0.14, 0)), Vector3(w + 0.6, h + 0.28, 0.1), Color(WHITE.r, WHITE.g, WHITE.b, 0.0), uvk)
	pk.box(kit, "timber", Transform3D(basis, c + o * 0.16 + Vector3(0, h + 0.28, 0)), Vector3(w + 1.1, 0.26, 0.34), POLE, uvk)
	for sgn in [-1.0, 1.0]:
		pk.box(kit, "timber", Transform3D(basis, c + o * 0.12 + side * (sgn * w * 0.25) + Vector3(0, h * 0.5, 0)), Vector3(w * 0.485, h, 0.08), TEAK, uvk)
	pk.box(kit, "dark", Transform3D(basis, c + o * 0.12 + Vector3(0, h * 0.5, 0)), Vector3(0.03, h, 0.081), SHADOW)
	var k0: int = rng.randi() % 4
	var face: Vector3 = c + o * 0.172
	var nb := 4
	var nt: int = maxi(4, int(round(w / 0.24)))
	var tw: float = w / float(nt)
	var gap: float = h * 0.8 / float(nb - 1)
	for bi in range(nb):
		var y: float = h * 0.1 + gap * float(bi)
		var ca: Color = NAJDI_PAINT[(k0 + bi) % 4]
		var cb: Color = NAJDI_PAINT[(k0 + bi + 1) % 4]
		var s0: Vector3 = face - side * (w * 0.5 - 0.03) + Vector3(0, y, 0)
		var s1: Vector3 = s0 + side * (w - 0.06)
		pk.quad(kit, "painted", [s0 - Vector3(0, 0.04, 0), s1 - Vector3(0, 0.04, 0), s1 + Vector3(0, 0.04, 0), s0 + Vector3(0, 0.04, 0)], o, WHITE)
		for ti in range(nt):
			var x0: float = -w * 0.5 + tw * float(ti) + 0.015
			var x1: float = x0 + tw - 0.03
			var xm: float = (x0 + x1) * 0.5
			var up_col: Color = ca if ti % 2 == 0 else cb
			var dn_col: Color = cb if ti % 2 == 0 else ca
			pk.tri(kit, "painted", face + side * x0 + Vector3(0, y + 0.04, 0), face + side * x1 + Vector3(0, y + 0.04, 0), face + side * xm + Vector3(0, y + 0.04 + tw * 0.85, 0), o, o, o, up_col, o)
			pk.tri(kit, "painted", face + side * x0 + Vector3(0, y - 0.04, 0), face + side * x1 + Vector3(0, y - 0.04, 0), face + side * xm + Vector3(0, y - 0.04 - tw * 0.85, 0), o, o, o, dn_col, o)
		if bi < nb - 1:
			var ym: float = y + gap * 0.5
			var dh: float = minf(gap * 0.5 - tw - 0.1, w * 0.2)
			if dh > 0.08:
				var dw: float = dh * 0.75
				var inner: Color = NAJDI_PAINT[(k0 + bi + 2) % 4]
				for sgn2 in [-1.0, 1.0]:
					var dc: Vector3 = face + side * (sgn2 * w * 0.25) + Vector3(0, ym, 0)
					pk.quad(kit, "painted", [dc - Vector3(0, dh, 0), dc + side * dw, dc + Vector3(0, dh, 0), dc - side * dw], o, WHITE)
					var di: Vector3 = dc + o * 0.012
					pk.quad(kit, "painted", [di - Vector3(0, dh * 0.6, 0), di + side * (dw * 0.6), di + Vector3(0, dh * 0.6, 0), di - side * (dw * 0.6)], o, inner)
	pk.box(kit, "metal", Transform3D(basis, c + o * 0.2 + Vector3(0, h * 0.55, 0) + side * 0.15), Vector3(0.14, 0.14, 0.03), BRASS)


## A small window with painted shutters (Najdi), its middle at `c` on a wall facing `out`.
static func shutter_window(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, col: Color) -> void:
	var o := out.normalized()
	var side := Vector3.UP.cross(o).normalized()
	var basis := Basis(side, Vector3.UP, o)
	pk.box(kit, "stucco", Transform3D(basis, c + o * 0.04), Vector3(w + 0.3, h + 0.3, 0.08), Color(WHITE.r, WHITE.g, WHITE.b, 0.0), uvk)
	pk.box(kit, "dark", Transform3D(basis, c + o * 0.09), Vector3(w, h, 0.02), SHADOW)
	for sgn in [-1.0, 1.0]:
		pk.box(kit, "painted", Transform3D(basis, c + o * 0.12 + side * (sgn * w * 0.25)), Vector3(w * 0.48, h, 0.05), col, uvk)
	pk.box(kit, "timber", Transform3D(basis, c + o * 0.14 + Vector3(0, h * 0.5 + 0.12, 0)), Vector3(w + 0.5, 0.16, 0.18), POLE, uvk)


## The outline of a pointed arch `w` wide and `h` high on a wall, its foot's middle at `c`, `side` along the wall: the
## left foot, up the left jamb and round the left arc to the apex, down the right arc and jamb to the right foot. Each
## arc is centred on the spring line on the far side of the middle (a two-centred arch), its head `w` x 0.62 high.
static func arch_outline(c: Vector3, side: Vector3, w: float, h: float, n := 7, head := 0.62) -> Array:
	var hw := w * 0.5
	var hh := minf(w * head, h * 0.6)
	var spring := h - hh
	var cx: float = (hh * hh - hw * hw) / (2.0 * hw)
	var r: float = cx + hw
	var a_apex: float = atan2(hh, -cx)
	var pts: Array = [c - side * hw]
	for i in range(n + 1):
		var a: float = lerpf(PI, a_apex, float(i) / float(n))
		pts.append(c + side * (cx + r * cos(a)) + Vector3(0, spring + r * sin(a), 0))
	for i in range(n - 1, -1, -1):
		var a2: float = lerpf(PI, a_apex, float(i) / float(n))
		pts.append(c - side * (cx + r * cos(a2)) + Vector3(0, spring + r * sin(a2), 0))
	pts.append(c + side * hw)
	return pts


## A pointed-arch opening (dark, or a recess of `fill_key` in `fill_col`) with a lime moulding round it on a wall
## facing `out`, its foot's middle at `c`.
static func arch_opening(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, surround := true, fill_key := "dark", fill_col := SHADOW, trim := LIME, head := 0.62) -> void:
	var o := out.normalized()
	var side := Vector3.UP.cross(o).normalized()
	var pts: Array = arch_outline(c + o * 0.04, side, w, h, 7, head)
	var mid: Vector3 = c + o * 0.04 + Vector3(0, h * 0.5, 0)
	for i in range(pts.size()):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % pts.size()]
		pk.tri(kit, fill_key, mid, a, b, o, o, o, fill_col, o)
	if surround:
		for i in range(pts.size() - 1):
			pk.beam(kit, "stucco", (pts[i] as Vector3) + o * 0.02, (pts[i + 1] as Vector3) + o * 0.02, 0.22, 0.1, Color(trim.r, trim.g, trim.b, 0.0), o, uvk)


## A small mosque, its door toward -z and its qibla wall at +z, the prayer hall `w` x `d` on a stone plinth: a parapet
## with merlons, the mihrab's bay standing out of the qibla wall, pointed windows along the sides, a minaret at a front
## corner: style 0 slim and round with a railed balcony and a pointed cap; style 1 (Najdi) square and tapering with
## triangular vents, a white band and a stepped crown. Returns the footprint radius.
static func mosque(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, w := 10.0, d := 8.0, style := 0) -> float:
	var col: Color = LIME if style == 0 else MUD_RED
	var key := "stucco" if style == 0 else "mud"
	var hw := w * 0.5
	var hd := d * 0.5
	var h := 4.8
	slab(pk, kit, "stone", Vector3(-hw - 0.25, -0.8, -hd - 0.25), Vector3(hw + 0.25, 0.35, hd + 0.25), Color(0.70, 0.62, 0.52), 0.0)
	slab(pk, kit, key, Vector3(-hw, 0.35, -hd), Vector3(hw, h, hd), col, 0.06)
	parapet(pk, kit, key, Vector3(-hw, h, -hd), Vector3(hw, h, hd), 0.8, col)
	slab(pk, kit, key, Vector3(-1.2, 0.35, hd), Vector3(1.2, h - 0.7, hd + 1.1), col, 0.0)
	if style == 0:
		door(pk, kit, Vector3(0, 0.35, -hd), Vector3(0, 0, -1), 1.7, 2.7, TEAK)
	else:
		najdi_door(pk, kit, rng, Vector3(0, 0.35, -hd), Vector3(0, 0, -1), 1.6, 2.5)
		triangles(pk, kit, Vector3(-hw + 0.3, h - 0.75, -hd), Vector3(hw - 0.3, h - 0.75, -hd), Vector3(0, 0, -1), 0.45, 0.25, false)
	for sx in [-1.0, 1.0]:
		for k in range(maxi(1, int(d / 3.2))):
			var z: float = -hd + d * (float(k) + 0.5) / float(maxi(1, int(d / 3.2)))
			arch_opening(pk, kit, Vector3(sx * hw, 1.3, z), Vector3(sx, 0, 0), 1.0, 2.2)
	var m := Vector3(hw + 0.2, 0.0, -hd - 0.2)
	if style == 0:
		pk.tube(kit, "stone", m + Vector3(0, -0.8, 0), m + Vector3(0, 0.4, 0), 1.6, 1.55, 16, Color(0.70, 0.62, 0.52), true, uvk)
		pk.tube(kit, key, m, m + Vector3(0, 11.0, 0), 1.35, 1.05, 16, Color(col.r, col.g, col.b, 0.05), true, uvk)
		pk.tube(kit, key, m + Vector3(0, 10.6, 0), m + Vector3(0, 11.2, 0), 1.75, 1.75, 16, Color(col.r, col.g, col.b, 0.0), true, uvk)
		merlon_ring(pk, kit, key, m + Vector3(0, 11.2, 0), 1.6, col, 10)
		pk.tube(kit, key, m + Vector3(0, 11.2, 0), m + Vector3(0, 14.2, 0), 0.85, 0.72, 14, Color(col.r, col.g, col.b, 0.0), true, uvk)
		pk.lathe(kit, key, m + Vector3(0, 14.2, 0), [Vector2(0.95, 0.0), Vector2(0.95, 0.25), Vector2(0.6, 1.0), Vector2(0.0, 2.4)], 14, col)
		pk.tube(kit, "metal", m + Vector3(0, 16.5, 0), m + Vector3(0, 17.6, 0), 0.05, 0.04, 6, BRASS)
		for k in range(3):
			var a: float = TAU * float(k) / 3.0
			arch_opening(pk, kit, m + Vector3(cos(a), 0, sin(a)) * 1.1 + Vector3(0, 7.5, 0), Vector3(cos(a), 0, sin(a)), 0.5, 1.2, false)
	else:
		slab(pk, kit, "stone", m + Vector3(-1.8, -0.8, -1.8), m + Vector3(1.8, 0.4, 1.8), Color(0.66, 0.56, 0.44), 0.0)
		battered(pk, kit, key, m + Vector3(-1.6, 0.4, -1.6), m + Vector3(1.6, 13.0, 1.6), 0.45, Color(col.r, col.g, col.b, 0.05))
		for f in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]:
			var sd := Vector3.UP.cross(f)
			for y in [6.0, 8.5]:
				var ins: float = 0.45 * (y - 0.4) / 12.6
				triangles(pk, kit, m + f * (1.6 - ins) - sd * 0.9 + Vector3(0, y, 0), m + f * (1.6 - ins) + sd * 0.9 + Vector3(0, y, 0), f, 0.36, 0.3, true)
			var ins2: float = 0.45 * (10.6 - 0.4) / 12.6
			triangles(pk, kit, m + f * (1.6 - ins2 + 0.02) - sd * 1.05 + Vector3(0, 10.6, 0), m + f * (1.6 - ins2 + 0.02) + sd * 1.05 + Vector3(0, 10.6, 0), f, 0.34, 0.12, false)
		slab(pk, kit, "stucco", m + Vector3(-1.25, 10.25, -1.25), m + Vector3(1.25, 10.55, 1.25), WHITE, 0.0)
		slab(pk, kit, key, m + Vector3(-1.35, 13.0, -1.35), m + Vector3(1.35, 13.6, 1.35), col, 0.0)
		slab(pk, kit, key, m + Vector3(-0.9, 13.6, -0.9), m + Vector3(0.9, 14.6, 0.9), col, 0.0)
		pyramid(pk, kit, key, m + Vector3(0, 14.6, 0), 1.5, 1.5, 1.6, col)
		for e in [[Vector3(-1.3, 13.6, -1.3), Vector3(1.3, 13.6, -1.3)], [Vector3(1.3, 13.6, -1.3), Vector3(1.3, 13.6, 1.3)], [Vector3(1.3, 13.6, 1.3), Vector3(-1.3, 13.6, 1.3)], [Vector3(-1.3, 13.6, 1.3), Vector3(-1.3, 13.6, -1.3)]]:
			merlons(pk, kit, key, m + (e[0] as Vector3), m + (e[1] as Vector3), col, 0.55, 0.32, 0.22, 0.45)
	return Vector2(hw + 2.5, hd + 2.5).length()


# ======================================================================================
#  The forts
# ======================================================================================

## Jebel Sahar's fort, Omani: battered mud curtain walls on a rubble footing, dressed outside with lime bands,
## buttresses, rows of loopholes, waterspouts and machicolations, merlons along the walkway; tiered round towers on
## three corners, a square tower on the fourth; a tiered keep inside the south-west corner with a lookout kiosk and a
## flag; the gatehouse (a pointed arch round the studded door, nested frames, an inscription panel, a machicolation,
## flags, two old cannons before it); inside, arcaded rooms along two walls, stairs up to the walkway, a small mosque
## and the well. Returns the footprint radius.
static func fort_omani(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, side := 46.0, wall_h := 8.0) -> float:
	var hs := side * 0.5
	var t := 1.8
	var col := MUD
	var batter := 0.3
	for i in range(4):
		var lo: Vector3
		var hi: Vector3
		match i:
			0: lo = Vector3(-hs, 0, -hs); hi = Vector3(hs, wall_h, -hs + t)
			1: lo = Vector3(-hs, 0, hs - t); hi = Vector3(hs, wall_h, hs)
			2: lo = Vector3(-hs, 0, -hs + t); hi = Vector3(-hs + t, wall_h, hs - t)
			3: lo = Vector3(hs - t, 0, -hs + t); hi = Vector3(hs, wall_h, hs - t)
		slab(pk, kit, "stone", Vector3(lo.x - 0.3, -6.0, lo.z - 0.3), Vector3(hi.x + 0.3, 0.6, hi.z + 0.3), STONE_FOOT, 0.0)
		battered(pk, kit, "mud", lo + Vector3(0, 0.6, 0), hi, batter, Color(col.r, col.g, col.b, 0.3))
	var y := wall_h
	merlons(pk, kit, "mud", Vector3(-hs + 3.0, y, -hs + 0.5), Vector3(hs - 3.0, y, -hs + 0.5), col, 0.95, 0.58, 0.5, 0.85)
	merlons(pk, kit, "mud", Vector3(-hs + 3.0, y, hs - 0.5), Vector3(hs - 3.0, y, hs - 0.5), col, 0.95, 0.58, 0.5, 0.85)
	merlons(pk, kit, "mud", Vector3(-hs + 0.5, y, -hs + 3.0), Vector3(-hs + 0.5, y, hs - 3.0), col, 0.95, 0.58, 0.5, 0.85)
	merlons(pk, kit, "mud", Vector3(hs - 0.5, y, -hs + 3.0), Vector3(hs - 0.5, y, hs - 3.0), col, 0.95, 0.58, 0.5, 0.85)
	wall_dress(pk, kit, Vector3(-hs + 5.0, 0, -hs), Vector3(hs - 5.0, 0, -hs), Vector3(0, 0, -1), wall_h, batter, col, 5.6)
	wall_dress(pk, kit, Vector3(-hs + 5.0, 0, hs), Vector3(hs - 5.0, 0, hs), Vector3(0, 0, 1), wall_h, batter, col)
	wall_dress(pk, kit, Vector3(-hs, 0, -hs + 5.0), Vector3(-hs, 0, hs - 5.0), Vector3(-1, 0, 0), wall_h, batter, col)
	wall_dress(pk, kit, Vector3(hs, 0, -hs + 5.0), Vector3(hs, 0, hs - 5.0), Vector3(1, 0, 0), wall_h, batter, col)
	var corners := [Vector2(-hs, -hs), Vector2(hs, -hs), Vector2(-hs, hs), Vector2(hs, hs)]
	for k in range(4):
		var cp: Vector2 = corners[k]
		if k == 3:
			slab(pk, kit, "stone", Vector3(cp.x - 4.3, -6.0, cp.y - 4.3), Vector3(cp.x + 4.3, 0.6, cp.y + 4.3), STONE_FOOT, 0.0)
			battered(pk, kit, "mud", Vector3(cp.x - 3.9, 0.6, cp.y - 3.9), Vector3(cp.x + 3.9, wall_h + 6.0, cp.y + 3.9), 0.5, Color(col.r, col.g, col.b, 0.3))
			parapet(pk, kit, "mud", Vector3(cp.x - 3.4, wall_h + 6.0, cp.y - 3.4), Vector3(cp.x + 3.4, wall_h + 6.0, cp.y + 3.4), 1.0, col)
			for f in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]:
				var sd := Vector3.UP.cross(f)
				window(pk, kit, Vector3(cp.x, wall_h + 3.0, cp.y) + f * 3.5, f, 0.65, 1.05, true)
				for row in range(2):
					var ly: float = wall_h * (0.45 + 0.3 * float(row))
					for j in [-1.0, 0.0, 1.0]:
						pk.box(kit, "dark", Transform3D(Basis(sd, Vector3.UP, f), Vector3(cp.x, ly, cp.y) + f * (3.9 - 0.5 * ly / (wall_h + 6.0) + 0.03) + sd * (j * 2.0)), Vector3(0.14, 0.7, 0.04), SHADOW)
				pk.box(kit, "stucco", Transform3D(Basis(sd, Vector3.UP, f), Vector3(cp.x, wall_h * 0.34, cp.y) + f * (3.9 - 0.5 * wall_h * 0.34 / (wall_h + 6.0) + 0.06)), Vector3(7.6, 0.26, 0.12), Color(LIME.r, LIME.g, LIME.b, 0.0), uvk)
				poles(pk, kit, Vector3(cp.x, wall_h + 5.3, cp.y) + f * 3.45 - sd * 3.0, Vector3(cp.x, wall_h + 5.3, cp.y) + f * 3.45 + sd * 3.0, f, 0.9, 0.35)
		else:
			tiered_tower(pk, kit, "mud", Vector3(cp.x, 0.0, cp.y), [[wall_h + 1.8, 4.9, 4.2], [3.4, 3.55, 3.25]], col)
	# The keep: three tiers inside the south-west corner, a lookout kiosk on top and the flag.
	var kc := Vector3(-hs + 9.5, 0.0, hs - 9.5)
	var ktop: float = tiered_tower(pk, kit, "mud", kc, [[wall_h + 4.0, 5.9, 5.1], [4.2, 4.4, 4.1], [3.0, 3.3, 3.1]], col)
	kiosk(pk, kit, "mud", Vector3(kc.x, ktop - 1.0, kc.z), 1.5, col)
	national_flag(pk, kit, Vector3(kc.x + 2.0, ktop - 1.0, kc.z), 7.0)
	# The gatehouse: a tall block out of the south wall, pilasters at its corners, the door deep in a pointed arch.
	slab(pk, kit, "stone", Vector3(-5.4, -6.0, -hs - 3.0), Vector3(5.4, 0.6, -hs + t), STONE_FOOT, 0.0)
	slab(pk, kit, "mud", Vector3(-5.0, 0.6, -hs - 2.6), Vector3(5.0, wall_h + 3.2, -hs + t), col, 0.3)
	for sx in [-1.0, 1.0]:
		slab(pk, kit, "mud", Vector3(sx * 5.0 - 0.55, 0.6, -hs - 2.95), Vector3(sx * 5.0 + 0.55, wall_h + 3.6, -hs - 2.4), col, 0.2)
	parapet(pk, kit, "mud", Vector3(-5.0, wall_h + 3.2, -hs - 2.6), Vector3(5.0, wall_h + 3.2, -hs + t), 1.0, col)
	var gz: float = -hs - 2.6
	arch_opening(pk, kit, Vector3(0, 0.6, gz), Vector3(0, 0, -1), 4.6, 7.4, true, "mud", Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, 0.0))
	window(pk, kit, Vector3(0, 6.8, gz - 0.03), Vector3(0, 0, -1), 0.9, 0.5)
	for k in range(2):
		var fw: float = 5.6 + float(k) * 1.0
		var fh: float = 7.9 + float(k) * 0.9
		pk.box(kit, "stucco", Transform3D(Basis(), Vector3(0, 0.6 + fh, gz - 0.06 - 0.04 * k)), Vector3(fw, 0.26, 0.1), Color(LIME.r, LIME.g, LIME.b, 0.0), uvk)
		for sx2 in [-1.0, 1.0]:
			pk.box(kit, "stucco", Transform3D(Basis(), Vector3(sx2 * fw * 0.5, 0.6 + fh * 0.5, gz - 0.06 - 0.04 * k)), Vector3(0.26, fh, 0.1), Color(LIME.r, LIME.g, LIME.b, 0.0), uvk)
	door(pk, kit, Vector3(0, 0.6, gz - 0.02), Vector3(0, 0, -1), 3.4, 4.9, TEAK, LIME, false)
	slab(pk, kit, "mud", Vector3(-1.7, wall_h + 2.0, gz - 0.95), Vector3(1.7, wall_h + 3.6, gz), col, 0.0)
	for k in range(3):
		pk.box(kit, "dark", Transform3D(Basis(), Vector3(-1.0 + k, wall_h + 2.8, gz - 0.97)), Vector3(0.18, 0.7, 0.02), SHADOW)
	for sx4 in [-1.0, 1.0]:
		poles(pk, kit, Vector3(sx4 * 4.4, wall_h + 2.4, gz), Vector3(sx4 * 2.0, wall_h + 2.4, gz), Vector3(0, 0, -1), 0.8, 0.4)
	for sx3 in [-1.0, 1.0]:
		national_flag(pk, kit, Vector3(sx3 * 4.2, wall_h + 4.2, gz + 1.2), 4.5, Vector3(1, 0, 0))
		cannon(pk, kit, Vector3(sx3 * 3.6, 0.0, gz - 4.0), Vector3(sx3 * 0.25, 0, -1))
	# Inside: arcaded rooms along the north and east walls, stairs to the walkway, the mosque, the well.
	slab(pk, kit, "mud", Vector3(-hs + t, 0.0, hs - t - 6.0), Vector3(hs - 12.0, 4.4, hs - t), MUD_PALE, 1.0)
	parapet(pk, kit, "mud", Vector3(-hs + t, 4.4, hs - t - 6.0), Vector3(hs - 12.0, 4.4, hs - t), 0.7, MUD_PALE, false)
	var n_arch: int = maxi(2, int((hs - 12.0 - (-hs + t)) / 3.4))
	for k in range(n_arch):
		var x: float = -hs + t + (hs - 12.0 - (-hs + t)) * (float(k) + 0.5) / float(n_arch)
		arch_opening(pk, kit, Vector3(x, 0.0, hs - t - 6.0), Vector3(0, 0, -1), 2.2, 3.4)
	slab(pk, kit, "mud", Vector3(hs - t - 6.0, 0.0, -hs + 8.0), Vector3(hs - t, 4.4, hs - t - 6.0), MUD_PALE, 1.0)
	for k in range(3):
		var z: float = -hs + 8.0 + (hs - t - 6.0 - (-hs + 8.0)) * (float(k) + 0.5) / 3.0
		door(pk, kit, Vector3(hs - t - 6.0, 0.0, z), Vector3(-1, 0, 0), 1.3, 2.2, [TEAK, DOOR_BLUE, DOOR_GREEN][k % 3])
	for k in range(int(wall_h / 0.5)):
		var sy: float = float(k) * 0.5
		slab(pk, kit, "mud", Vector3(-hs + t, 0.0, -hs + 6.0 + float(k) * 0.55), Vector3(-hs + t + 1.4, sy + 0.5, -hs + 6.55 + float(k) * 0.55), MUD_PALE, 0.0)
	at(pk, Transform3D(Basis(), Vector3(hs - 13.5, 0.0, -hs + 10.0)), func() -> void:
		mosque(pk, kit, rng, 8.0, 6.5, 0))
	pk.tube(kit, "stone", Vector3(4, 0, 4), Vector3(4, 0.9, 4), 1.2, 1.2, 12, Color(0.65, 0.58, 0.48), true, uvk)
	pk.tube(kit, "dark", Vector3(4, 0.5, 4), Vector3(4, 0.92, 4), 0.85, 0.85, 12, SHADOW, true)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "timber", Vector3(4 + sx * 1.0, 0.9, 4), Vector3(4 + sx * 1.0, 2.6, 4), 0.14, 0.14, POLE)
	pk.beam(kit, "timber", Vector3(2.8, 2.6, 4), Vector3(5.2, 2.6, 4), 0.14, 0.14, POLE)
	return side * 0.75


## Wadi al-Ghaf's fortress, Najdi: red-brown mud walls leaning in hard on a rubble footing, a white band under the
## walkway painted with triangles, a row of triangular vents, stepped merlons; square tapering towers on the corners
## (rows of triangular vents, a white frieze, shuttered windows, spouts, a parapet with merlons); the murabba'a, a
## tall square keep in the court's north-west quarter (shuttered windows on every floor, white bands, triangle
## friezes and vents, a stepped crown, the flag); the gate in a white-banded block with the painted Najdi door under
## a heavy lintel; inside, rooms along two walls, the mosque with its square minaret, the well. Returns the radius.
static func fort_najdi(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, side := 30.0, wall_h := 7.5) -> float:
	var hs := side * 0.5
	var t := 1.7
	var col := MUD_RED
	var batter := 0.45
	for i in range(4):
		var lo: Vector3
		var hi: Vector3
		match i:
			0: lo = Vector3(-hs, 0, -hs); hi = Vector3(hs, wall_h, -hs + t)
			1: lo = Vector3(-hs, 0, hs - t); hi = Vector3(hs, wall_h, hs)
			2: lo = Vector3(-hs, 0, -hs + t); hi = Vector3(-hs + t, wall_h, hs - t)
			3: lo = Vector3(hs - t, 0, -hs + t); hi = Vector3(hs, wall_h, hs - t)
		slab(pk, kit, "stone", Vector3(lo.x - 0.3, -6.0, lo.z - 0.3), Vector3(hi.x + 0.3, 0.5, hi.z + 0.3), STONE_FOOT, 0.0)
		battered(pk, kit, "mud", lo + Vector3(0, 0.5, 0), hi, batter, Color(col.r, col.g, col.b, 0.06))
	var faces := [[Vector3(-hs + 4.5, 0, -hs), Vector3(hs - 4.5, 0, -hs), Vector3(0, 0, -1)], [Vector3(-hs + 4.5, 0, hs), Vector3(hs - 4.5, 0, hs), Vector3(0, 0, 1)],
			[Vector3(-hs, 0, -hs + 4.5), Vector3(-hs, 0, hs - 4.5), Vector3(-1, 0, 0)], [Vector3(hs, 0, -hs + 4.5), Vector3(hs, 0, hs - 4.5), Vector3(1, 0, 0)]]
	for fi in range(4):
		var fa: Vector3 = faces[fi][0]
		var fb: Vector3 = faces[fi][1]
		var fo: Vector3 = faces[fi][2]
		var along: Vector3 = (fb - fa).normalized()
		var L: float = fa.distance_to(fb)
		var yb: float = wall_h - 0.9
		var ins: float = batter * (yb - 0.5) / (wall_h - 0.5)
		var runs: Array = [[0.0, L]] if fi != 0 else [[0.0, L * 0.5 - 4.6], [L * 0.5 + 4.6, L]]
		for rr in runs:
			var r0: float = rr[0]
			var r1: float = rr[1]
			var pa: Vector3 = fa + along * r0
			var pb: Vector3 = fa + along * r1
			pk.box(kit, "stucco", Transform3D(Basis(along, Vector3.UP, fo), (pa + pb) * 0.5 + Vector3(0, yb, 0) + fo * (0.06 - ins)), Vector3(r1 - r0, 0.5, 0.12), Color(WHITE.r, WHITE.g, WHITE.b, 0.0), uvk)
			triangles(pk, kit, pa + Vector3(0, yb - 0.75, 0) + fo * (0.02 - ins), pb + Vector3(0, yb - 0.75, 0) + fo * (0.02 - ins), fo, 0.5, 0.3, false)
			var ly: float = wall_h * 0.6
			var ins2: float = batter * (ly - 0.5) / (wall_h - 0.5)
			triangles(pk, kit, pa + Vector3(0, ly, 0) + fo * (0.0 - ins2), pb + Vector3(0, ly, 0) + fo * (0.0 - ins2), fo, 0.46, 1.1, true)
			var n_s: int = maxi(1, int((r1 - r0) / 5.5))
			for k in range(n_s):
				var ps: Vector3 = pa + along * ((r1 - r0) * (float(k) + 0.5) / float(n_s)) + Vector3(0, wall_h - 0.2, 0)
				pk.beam(kit, "timber", ps - fo * (batter + 0.2), ps + fo * (0.9 - batter), 0.16, 0.16, POLE, Vector3.ZERO, uvk)
		merlons(pk, kit, "mud", fa + Vector3(0, wall_h, 0) + fo * -0.5 + along * -1.0, fb + Vector3(0, wall_h, 0) + fo * -0.5 + along * 1.0, col, 0.9, 0.5, 0.45, 0.75)
	# Square towers on the corners, tapering.
	for cp in [Vector2(-hs, -hs), Vector2(hs, -hs), Vector2(-hs, hs), Vector2(hs, hs)]:
		_najdi_tower(pk, kit, rng, Vector3(cp.x, 0.0, cp.y), 8.8, 6.8, wall_h + 6.0, col)
	# The murabba'a.
	var kc := Vector3(-hs + 9.0, 0.0, hs - 9.0)
	var ktop: float = _najdi_tower(pk, kit, rng, kc, 10.5, 8.2, wall_h + 15.0, col, 4)
	national_flag(pk, kit, Vector3(kc.x + 2.5, ktop, kc.z), 6.5)
	# The gate block.
	slab(pk, kit, "stone", Vector3(-4.6, -6.0, -hs - 2.4), Vector3(4.6, 0.5, -hs + t), STONE_FOOT, 0.0)
	slab(pk, kit, "mud", Vector3(-4.3, 0.5, -hs - 2.1), Vector3(4.3, wall_h + 2.6, -hs + t), col, 0.15)
	parapet(pk, kit, "mud", Vector3(-4.3, wall_h + 2.6, -hs - 2.1), Vector3(4.3, wall_h + 2.6, -hs + t), 1.0, col)
	var gz: float = -hs - 2.1
	slab(pk, kit, "dark", Vector3(-1.9, 0.5, gz - 0.03), Vector3(1.9, 5.2, gz - 0.01), SHADOW, 0.0)
	najdi_door(pk, kit, rng, Vector3(0, 0.5, gz - 0.02), Vector3(0, 0, -1), 3.4, 4.5)
	pk.box(kit, "stucco", Transform3D(Basis(), Vector3(0, wall_h + 1.4, gz - 0.06)), Vector3(8.0, 0.5, 0.12), Color(WHITE.r, WHITE.g, WHITE.b, 0.0), uvk)
	triangles(pk, kit, Vector3(-3.8, wall_h + 0.6, gz - 0.02), Vector3(3.8, wall_h + 0.6, gz - 0.02), Vector3(0, 0, -1), 0.5, 0.25, false)
	triangles(pk, kit, Vector3(-3.0, 6.4, gz - 0.02), Vector3(3.0, 6.4, gz - 0.02), Vector3(0, 0, -1), 0.34, 0.7, true)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "timber", Vector3(sx * 3.0, wall_h + 2.4, gz), Vector3(sx * 3.0, wall_h + 2.4, gz - 0.9), 0.16, 0.16, POLE, Vector3.ZERO, uvk)
		cannon(pk, kit, Vector3(sx * 3.4, 0.0, gz - 3.8), Vector3(sx * 0.2, 0, -1))
	# Inside: rooms along the east and north walls, the mosque, the well.
	slab(pk, kit, "mud", Vector3(hs - t - 5.5, 0.0, -hs + t), Vector3(hs - t, 4.2, hs - 9.0), col.lerp(MUD_PALE, 0.25), 1.0)
	parapet(pk, kit, "mud", Vector3(hs - t - 5.5, 4.2, -hs + t), Vector3(hs - t, 4.2, hs - 9.0), 0.7, col.lerp(MUD_PALE, 0.25), true)
	for k in range(3):
		var z: float = -hs + t + (hs - 9.0 - (-hs + t)) * (float(k) + 0.5) / 3.0
		najdi_door(pk, kit, rng, Vector3(hs - t - 5.5, 0.0, z), Vector3(-1, 0, 0), 1.3, 2.2)
		shutter_window(pk, kit, Vector3(hs - t - 5.5, 2.8, z + 1.8), Vector3(-1, 0, 0), 0.7, 0.8, NAJDI_SHUTTER[k % 4])
	at(pk, Transform3D(Basis(), Vector3(2.0, 0.0, -hs + 9.5)), func() -> void:
		mosque(pk, kit, rng, 8.0, 6.0, 1))
	pk.tube(kit, "stone", Vector3(-3, 0, 2), Vector3(-3, 0.9, 2), 1.2, 1.2, 12, Color(0.65, 0.58, 0.48), true, uvk)
	pk.tube(kit, "dark", Vector3(-3, 0.5, 2), Vector3(-3, 0.92, 2), 0.85, 0.85, 12, SHADOW, true)
	for sx2 in [-1.0, 1.0]:
		pk.beam(kit, "timber", Vector3(-3 + sx2 * 1.0, 0.9, 2), Vector3(-3 + sx2 * 1.0, 2.6, 2), 0.14, 0.14, POLE)
	pk.beam(kit, "timber", Vector3(-4.2, 2.6, 2), Vector3(-1.8, 2.6, 2), 0.14, 0.14, POLE)
	return side * 0.75


## A square Najdi tower at `foot` (its middle), `w0` across at the foot tapering to `w1`, `h` tall: rows of triangular
## vents and shuttered windows on each face (`floors` of them), white bands painted with triangles, spouts, a parapet
## with stepped merlons. Returns its top.
static func _najdi_tower(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, foot: Vector3, w0: float, w1: float, h: float, col: Color, floors := 2, door_face := Vector3.ZERO) -> float:
	var b: float = (w0 - w1) * 0.5
	battered(pk, kit, "stone", foot + Vector3(-w0 * 0.5 - 2.3, -6.0, -w0 * 0.5 - 2.3), foot + Vector3(w0 * 0.5 + 2.3, 0.5, w0 * 0.5 + 2.3), 1.95, STONE_FOOT)
	battered(pk, kit, "mud", foot + Vector3(-w0 * 0.5, 0.5, -w0 * 0.5), foot + Vector3(w0 * 0.5, h, w0 * 0.5), b, Color(col.r, col.g, col.b, 0.06))
	var half_at := func(y: float) -> float:
		return w0 * 0.5 - b * clampf((y - 0.5) / (h - 0.5), 0.0, 1.0)
	for f in [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]:
		var sd := Vector3.UP.cross(f)
		for fl in range(floors):
			var y: float = h * (0.32 + 0.6 * float(fl) / float(maxi(floors, 1)))
			var hw: float = half_at.call(y)
			if fl == 0 and f.is_equal_approx(door_face):
				continue
			shutter_window(pk, kit, foot + f * (hw + 0.01) + Vector3(0, y, 0), f, 0.7, 0.85, NAJDI_SHUTTER[(fl + rng.randi() % 2) % 4])
			var vy: float = y + 1.1
			var hv: float = half_at.call(vy)
			triangles(pk, kit, foot + f * hv - sd * (hv - 0.7) + Vector3(0, vy, 0), foot + f * hv + sd * (hv - 0.7) + Vector3(0, vy, 0), f, 0.46, 0.5, true)
		var yb: float = h - 1.1
		var hb: float = half_at.call(yb)
		pk.box(kit, "stucco", Transform3D(Basis(sd, Vector3.UP, f), foot + f * (hb + 0.06) + Vector3(0, yb, 0)), Vector3(hb * 2.0 + 0.1, 0.5, 0.12), Color(WHITE.r, WHITE.g, WHITE.b, 0.0), uvk)
		triangles(pk, kit, foot + f * (hb + 0.02) - sd * (hb - 0.2) + Vector3(0, yb - 0.72, 0), foot + f * (hb + 0.02) + sd * (hb - 0.2) + Vector3(0, yb - 0.72, 0), f, 0.48, 0.24, false)
		for k in [-0.5, 0.5]:
			pk.beam(kit, "timber", foot + f * (hb - 0.2) + sd * (k * hb) + Vector3(0, h - 0.25, 0), foot + f * (hb + 0.85) + sd * (k * hb) + Vector3(0, h - 0.2, 0), 0.16, 0.16, POLE, Vector3.ZERO, uvk)
	var e: float = w1 * 0.5
	parapet(pk, kit, "mud", foot + Vector3(-e, h, -e), foot + Vector3(e, h, e), 1.0, col)
	return foot.y + h + 1.0


## A watchtower (burj) on a ridge, its foot's middle at the origin, `h` tall: style 0 a tiered round tower (Omani) with
## a door a few metres up reached by a ladder of poles, a flag; style 1 a square tapering Najdi tower. Returns the
## footprint radius.
static func watchtower(pk: PropKit, kit: Dictionary, h := 11.0, r := 2.9, style := 0) -> float:
	slab(pk, kit, "stone", Vector3(-r - 0.6, -6.0, -r - 0.6), Vector3(r + 0.6, 0.5, r + 0.6), Color(0.60, 0.53, 0.44), 0.0)
	var dy := 3.2
	var dz: float
	if style == 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(h * 1000.0 + r * 10.0)
		_najdi_tower(pk, kit, rng, Vector3(0, 0.0, 0), r * 2.0, r * 1.5, h + 0.5, MUD_RED, 2, Vector3(0, 0, -1))
		dz = -(r - (r * 0.25) * dy / (h + 0.5)) - 0.02
	else:
		tiered_tower(pk, kit, "mud", Vector3(0, 0.5, 0), [[h * 0.72, r, r * 0.86], [h * 0.28, r * 0.74, r * 0.68]], MUD)
		national_flag(pk, kit, Vector3(r * 0.3, h + 1.5, 0), 3.5)
		dz = -lerpf(r, r * 0.86, dy / (h * 0.72)) - 0.02
	pk.box(kit, "timber", Transform3D(Basis(), Vector3(0, dy + 1.0, dz)), Vector3(0.9, 1.8, 0.1), TEAK, uvk)
	for sx in [-0.3, 0.3]:
		pk.beam(kit, "timber", Vector3(sx, 0.5, dz - 1.4), Vector3(sx, dy + 0.2, dz - 0.15), 0.08, 0.08, POLE)
	for k in range(6):
		var tk: float = (float(k) + 0.5) / 6.0
		var p := Vector3(0, 0.5, dz - 1.4).lerp(Vector3(0, dy + 0.2, dz - 0.15), tk)
		pk.beam(kit, "timber", p - Vector3(0.32, 0, 0), p + Vector3(0.32, 0, 0), 0.06, 0.06, POLE)
	return r + 1.5


## A Najdi house (Wadi al-Ghaf's village), its front (the door) toward -z, `w` x `d` round the origin: red-brown mud on
## a stone plinth, one or two storeys (the second a roof room over the back half, a terrace before it), a white band
## under the parapet painted with triangles, triangular vents high up, small shuttered windows, stepped merlons on the
## parapet, wooden spouts, the painted Najdi door; a walled yard behind. Returns the footprint radius.
static func house_najdi(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator, w: float, d: float, storeys: int, yard := true, yard_d := -1.0) -> float:
	var col: Color = MUD_RED.lerp(MUD_PALE, rng.randf() * 0.35)
	var hw := w * 0.5
	var hd := d * 0.5
	var fh := 3.4
	var h := fh
	slab(pk, kit, "stone", Vector3(-hw - 0.1, -0.6, -hd - 0.1), Vector3(hw + 0.1, 0.35, hd + 0.1), Color(0.66, 0.56, 0.44), 0.0)
	slab(pk, kit, "mud", Vector3(-hw, 0.35, -hd), Vector3(hw, h, hd), col, 0.06)
	var shut: Color = NAJDI_SHUTTER[rng.randi() % 4]
	_najdi_band(pk, kit, Vector3(-hw, h, -hd), Vector3(hw, h, hd))
	parapet(pk, kit, "mud", Vector3(-hw, h, -hd), Vector3(hw, h, hd), 1.0, col)
	najdi_door(pk, kit, rng, Vector3(rng.randf_range(-hw * 0.3, hw * 0.3), 0.35, -hd), Vector3(0, 0, -1), 1.4, 2.3)
	for k in range(maxi(1, int(w / 4.0))):
		var x: float = -hw + w * (float(k) + 0.5) / float(maxi(1, int(w / 4.0)))
		if rng.randf() < 0.7:
			shutter_window(pk, kit, Vector3(x, 2.0, -hd), Vector3(0, 0, -1), 0.6, 0.7, shut)
	triangles(pk, kit, Vector3(-hw + 0.4, h - 1.5, -hd), Vector3(hw - 0.4, h - 1.5, -hd), Vector3(0, 0, -1), 0.3, 0.9, true)
	if storeys >= 2:
		var z0: float = -hd + d * 0.45
		slab(pk, kit, "mud", Vector3(-hw + 0.3, h, z0), Vector3(hw - 0.3, h + fh, hd - 0.3), col, 0.06)
		_najdi_band(pk, kit, Vector3(-hw + 0.3, h + fh, z0), Vector3(hw - 0.3, h + fh, hd - 0.3))
		parapet(pk, kit, "mud", Vector3(-hw + 0.3, h + fh, z0), Vector3(hw - 0.3, h + fh, hd - 0.3), 0.9, col)
		for k in range(maxi(1, int(w / 3.6))):
			var x2: float = -hw + 0.3 + (w - 0.6) * (float(k) + 0.5) / float(maxi(1, int(w / 3.6)))
			shutter_window(pk, kit, Vector3(x2, h + 1.7, z0), Vector3(0, 0, -1), 0.6, 0.75, shut)
		triangles(pk, kit, Vector3(-hw + 0.7, h + fh - 1.3, z0), Vector3(hw - 0.7, h + fh - 1.3, z0), Vector3(0, 0, -1), 0.3, 0.8, true)
	for sx in [-0.6, 0.6]:
		pk.beam(kit, "timber", Vector3(hw * sx, h + 0.2, -hd + 0.1), Vector3(hw * sx, h + 0.2, -hd - 0.85), 0.16, 0.14, POLE, Vector3.ZERO, uvk)
	poles(pk, kit, Vector3(-hw + 0.4, h - 0.3, -hd), Vector3(hw - 0.4, h - 0.3, -hd), Vector3(0, 0, -1), 0.95, 0.28)
	var reach: float = Vector2(hw, hd).length()
	if yard:
		var yd: float = rng.randf_range(5.0, 8.0)
		if yard_d > 0.0:
			yd = yard_d
		var yh := 2.5
		slab(pk, kit, "mud", Vector3(-hw, 0.0, hd), Vector3(-hw + 0.45, yh, hd + yd), col, 1.0)
		slab(pk, kit, "mud", Vector3(hw - 0.45, 0.0, hd), Vector3(hw, yh, hd + yd), col, 1.0)
		slab(pk, kit, "mud", Vector3(-hw, 0.0, hd + yd - 0.45), Vector3(-1.2, yh, hd + yd), col, 1.0)
		slab(pk, kit, "mud", Vector3(1.2, 0.0, hd + yd - 0.45), Vector3(hw, yh, hd + yd), col, 1.0)
		merlons(pk, kit, "mud", Vector3(-hw + 0.2, yh, hd + yd - 0.22), Vector3(-1.4, yh, hd + yd - 0.22), col, 0.9, 0.4, 0.35, 0.5)
		merlons(pk, kit, "mud", Vector3(1.4, yh, hd + yd - 0.22), Vector3(hw - 0.2, yh, hd + yd - 0.22), col, 0.9, 0.4, 0.35, 0.5)
		najdi_door(pk, kit, rng, Vector3(0, 0.0, hd + yd), Vector3(0, 0, 1), 2.2, 2.1)
		reach = Vector2(hw, hd + yd).length()
	return reach


## The white band under a Najdi parapet round a roof `lo`..`hi` (its corners at roof level), painted with triangles.
static func _najdi_band(pk: PropKit, kit: Dictionary, lo: Vector3, hi: Vector3) -> void:
	var y: float = lo.y - 0.55
	for e in [[Vector3(lo.x, y, lo.z), Vector3(hi.x, y, lo.z), Vector3(0, 0, -1)], [Vector3(hi.x, y, hi.z), Vector3(lo.x, y, hi.z), Vector3(0, 0, 1)],
			[Vector3(lo.x, y, hi.z), Vector3(lo.x, y, lo.z), Vector3(-1, 0, 0)], [Vector3(hi.x, y, lo.z), Vector3(hi.x, y, hi.z), Vector3(1, 0, 0)]]:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var o: Vector3 = e[2]
		var along: Vector3 = (b - a).normalized()
		pk.box(kit, "stucco", Transform3D(Basis(along, Vector3.UP, o), (a + b) * 0.5 + o * 0.05 + Vector3(0, 0.28, 0)), Vector3(a.distance_to(b) + 0.1, 0.42, 0.1), Color(WHITE.r, WHITE.g, WHITE.b, 0.0), uvk)
		triangles(pk, kit, a + o * 0.02 + Vector3(0, -0.42, 0), b + o * 0.02 + Vector3(0, -0.42, 0), o, 0.4, 0.22, false)


# ======================================================================================
#  The villa (Wadi al-Ghaf): curved walls, arch bays, stairs, boulders
# ======================================================================================

const VILLA_SAND := Color(0.86, 0.73, 0.56)
const VILLA_PALE := Color(0.93, 0.84, 0.69)
const VILLA_DEEP := Color(0.76, 0.61, 0.45)
const VILLA_ROCK := Color(0.84, 0.62, 0.45)


## A curved wall round `c` (its foot's middle) between radii r - t and r, from `y0` to `y1` over its foot, over the
## angles a0..a1 (from +x toward +z): outer and inner faces and the top, closed at its ends unless a full ring. UVs in
## metres (u round the wall, v up it), as the slabs'.
static func ring_wall(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: float, t: float, y0: float, y1: float, a0: float, a1: float, segs: int, col: Color) -> void:
	var cc := Color(col.r, col.g, col.b, 0.0)
	var ri: float = r - t
	var full: bool = absf(a1 - a0) >= TAU - 1e-3
	var hv: float = (y1 - y0) * uvk
	for j in range(segs):
		var t0: float = lerpf(a0, a1, float(j) / float(segs))
		var t1: float = lerpf(a0, a1, float(j + 1) / float(segs))
		var u0 := Vector3(cos(t0), 0, sin(t0))
		var u1 := Vector3(cos(t1), 0, sin(t1))
		var um := (u0 + u1).normalized()
		var lo: Vector3 = c + Vector3(0, y0, 0)
		var hi: Vector3 = c + Vector3(0, y1, 0)
		var s0: float = t0 * r * uvk
		var s1: float = t1 * r * uvk
		pk.tri(kit, key, lo + u0 * r, lo + u1 * r, hi + u1 * r, u0, u1, u1, cc, um, Vector2(s0, 0), Vector2(s1, 0), Vector2(s1, hv))
		pk.tri(kit, key, lo + u0 * r, hi + u1 * r, hi + u0 * r, u0, u1, u0, cc, um, Vector2(s0, 0), Vector2(s1, hv), Vector2(s0, hv))
		pk.tri(kit, key, lo + u0 * ri, hi + u1 * ri, lo + u1 * ri, -u0, -u1, -u1, cc, -um, Vector2(s0, 0), Vector2(s1, hv), Vector2(s1, 0))
		pk.tri(kit, key, lo + u0 * ri, hi + u0 * ri, hi + u1 * ri, -u0, -u0, -u1, cc, -um, Vector2(s0, 0), Vector2(s0, hv), Vector2(s1, hv))
		pk.tri(kit, key, hi + u0 * ri, hi + u0 * r, hi + u1 * r, Vector3.UP, Vector3.UP, Vector3.UP, cc, Vector3.UP, Vector2(s0, 2), Vector2(s0, 2 + t * uvk), Vector2(s1, 2 + t * uvk))
		pk.tri(kit, key, hi + u0 * ri, hi + u1 * r, hi + u1 * ri, Vector3.UP, Vector3.UP, Vector3.UP, cc, Vector3.UP, Vector2(s0, 2), Vector2(s1, 2 + t * uvk), Vector2(s1, 2))
	if not full:
		for e in [[a0, -1.0], [a1, 1.0]]:
			var a: float = e[0]
			var u := Vector3(cos(a), 0, sin(a))
			var tg := Vector3(-sin(a), 0, cos(a)) * float(e[1])
			pk.quad(kit, key, [c + Vector3(0, y0, 0) + u * ri, c + Vector3(0, y0, 0) + u * r, c + Vector3(0, y1, 0) + u * r, c + Vector3(0, y1, 0) + u * ri], tg, cc,
					[Vector2(0, 0), Vector2(t * uvk, 0), Vector2(t * uvk, hv), Vector2(0, hv)])


## A flat slab round `c` from radius `r_in` to `r` (0: a disc), `y0` to `y1` over `c`, over the angles a0..a1: top,
## underside and rim (and the inner rim of an annulus). UVs in metres.
static func disc_slab(pk: PropKit, kit: Dictionary, key: String, c: Vector3, r: float, y0: float, y1: float, a0: float, a1: float, segs: int, col: Color, r_in := 0.0) -> void:
	var cc := Color(col.r, col.g, col.b, 0.0)
	for j in range(segs):
		var t0: float = lerpf(a0, a1, float(j) / float(segs))
		var t1: float = lerpf(a0, a1, float(j + 1) / float(segs))
		var u0 := Vector3(cos(t0), 0, sin(t0))
		var u1 := Vector3(cos(t1), 0, sin(t1))
		for lev in [[y1, Vector3.UP], [y0, Vector3.DOWN]]:
			var y: float = lev[0]
			var n: Vector3 = lev[1]
			var o: Vector3 = c + Vector3(0, y, 0)
			var p0: Vector3 = o + u0 * r
			var p1: Vector3 = o + u1 * r
			var uv := func(p: Vector3) -> Vector2:
				return Vector2(p.x - c.x, p.z - c.z) * uvk
			if r_in <= 0.0:
				pk.tri(kit, key, o, p0, p1, n, n, n, cc, n, uv.call(o), uv.call(p0), uv.call(p1))
			else:
				var q0: Vector3 = o + u0 * r_in
				var q1: Vector3 = o + u1 * r_in
				pk.tri(kit, key, q0, p0, p1, n, n, n, cc, n, uv.call(q0), uv.call(p0), uv.call(p1))
				pk.tri(kit, key, q0, p1, q1, n, n, n, cc, n, uv.call(q0), uv.call(p1), uv.call(q1))
	ring_wall(pk, kit, key, c, r, 0.0001, y0, y1, a0, a1, segs, col)
	if r_in > 0.0:
		ring_wall(pk, kit, key, c, r_in + 0.0001, 0.0001, y0, y1, a0, a1, segs, col)


## A bay of a wall pierced by an arch, from `l` to `r` (points on its floor, the front face), `depth` thick toward
## `inward`: the opening `w_open` wide and `h_open` to its apex (`head` its head's height over its width: 0.62
## pointed, 0.5 round), front and back faces up to `top` over the floor, the arch's soffit through the wall, the top,
## and with `ends` the two end faces. The columns or piers either side are the caller's.
static func arch_bay(pk: PropKit, kit: Dictionary, key: String, l: Vector3, r: Vector3, inward: Vector3, depth: float, w_open: float, h_open: float, top: float, col: Color, head := 0.62, ends := false) -> void:
	var cc := Color(col.r, col.g, col.b, 0.0)
	var side := (r - l).normalized()
	var inn := (inward - side * inward.dot(side)).normalized()
	var o := -inn
	var mid := (l + r) * 0.5
	var outline: Array = arch_outline(mid, side, w_open, h_open, 7, head)
	var back: Vector3 = inn * depth
	var up_top := Vector3(0, top, 0)
	var lj: Vector3 = outline[0]
	var rj: Vector3 = outline[outline.size() - 1]
	for face in range(2):
		var off: Vector3 = Vector3.ZERO if face == 0 else back
		var n: Vector3 = o if face == 0 else inn
		# The piers' faces either side of the opening, floor to top.
		pk.quad(kit, key, [l + off, lj + off, lj + up_top + off - Vector3(0, lj.y - l.y, 0), l + up_top + off], n, cc)
		pk.quad(kit, key, [rj + off, r + off, r + up_top + off, rj + up_top + off - Vector3(0, rj.y - r.y, 0)], n, cc)
		# The spandrels: each stretch of the head up to the top.
		for i in range(1, outline.size() - 2):
			var a: Vector3 = outline[i]
			var b: Vector3 = outline[i + 1]
			var at := Vector3(a.x, l.y + top, a.z)
			var bt := Vector3(b.x, l.y + top, b.z)
			pk.quad(kit, key, [a + off, b + off, bt + off, at + off], n, cc)
	# The soffit: jambs and head, through the wall, facing into the opening.
	var centre: Vector3 = mid + Vector3(0, h_open * 0.45, 0)
	for i in range(outline.size() - 1):
		var a2: Vector3 = outline[i]
		var b2: Vector3 = outline[i + 1]
		var m2: Vector3 = (a2 + b2) * 0.5
		var toward: Vector3 = centre - m2
		toward -= inn * toward.dot(inn)
		pk.quad(kit, key, [a2, b2, b2 + back, a2 + back], toward.normalized(), cc)
	pk.quad(kit, key, [l + up_top, r + up_top, r + up_top + back, l + up_top + back], Vector3.UP, cc)
	if ends:
		pk.quad(kit, key, [l, l + back, l + back + up_top, l + up_top], -side, cc)
		pk.quad(kit, key, [r, r + up_top, r + back + up_top, r + back], side, cc)


## A column on `foot` up to `h`: a square base, a round shaft, a capital.
static func column(pk: PropKit, kit: Dictionary, foot: Vector3, h: float, r: float, col: Color) -> void:
	var cc := Color(col.r, col.g, col.b, 0.0)
	pk.box(kit, "stucco", Transform3D(Basis(), foot + Vector3(0, 0.15, 0)), Vector3(r * 2.6, 0.3, r * 2.6), cc, uvk)
	pk.tube(kit, "stucco", foot + Vector3(0, 0.3, 0), foot + Vector3(0, h - 0.3, 0), r, r * 0.92, 10, cc, false, uvk)
	pk.box(kit, "stucco", Transform3D(Basis(), foot + Vector3(0, h - 0.15, 0)), Vector3(r * 2.7, 0.3, r * 2.7), cc, uvk)


## A ring of arches round `c` on radius `ra` from angle a0 to a1 in `n` bays: columns, arch bays `depth` deep toward
## the middle, springing at `spring` over the floor, `top` high.
static func curved_arcade(pk: PropKit, kit: Dictionary, c: Vector3, ra: float, a0: float, a1: float, n: int, spring: float, top: float, depth: float, col: Color) -> void:
	var pts: Array = []
	for i in range(n + 1):
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(c + Vector3(cos(a), 0, sin(a)) * ra)
	for i in range(n + 1):
		column(pk, kit, pts[i], spring, 0.24, col)
	for i in range(n):
		var l: Vector3 = pts[i]
		var r: Vector3 = pts[i + 1]
		var chord: float = l.distance_to(r)
		var w: float = chord - 0.56
		var inward: Vector3 = (c - (l + r) * 0.5)
		inward.y = 0.0
		var lo := l
		var ro := r
		# Laid along the bay's chord, its front face 2cm out from the columns' middles.
		arch_bay(pk, kit, "stucco", lo, ro, inward, depth, w, spring + w * 0.62, top, col)


## Straight stairs down toward -z from the edge of a floor at `z_top`, `y_top` over the ground (y 0), between x0 and
## x1: steps of `rise` and `run`, with stepped cheek walls 0.5m wide either side, `cheek` over each step.
static func stairs(pk: PropKit, kit: Dictionary, x0: float, x1: float, z_top: float, y_top: float, rise: float, run: float, col: Color, cheek_col: Color, cheek := 0.75) -> void:
	var n: int = maxi(1, int(round(y_top / rise)))
	var rs: float = y_top / float(n)
	for i in range(1, n):
		var top: float = y_top - rs * float(i)
		var za: float = z_top - run * float(i)
		var zb: float = z_top - run * float(i - 1)
		slab(pk, kit, "stucco", Vector3(x0, -0.4, za), Vector3(x1, top, zb), col, 0.0)
		for xs in [[x0 - 0.5, x0], [x1, x1 + 0.5]]:
			slab(pk, kit, "stucco", Vector3(xs[0], -0.4, za), Vector3(xs[1], top + cheek, zb), cheek_col, 0.0)
	for xs in [[x0 - 0.5, x0], [x1, x1 + 0.5]]:
		slab(pk, kit, "stucco", Vector3(xs[0], -0.4, z_top - 0.02), Vector3(xs[1], y_top + cheek, z_top + 0.5), cheek_col, 0.0)


## A smooth, rounded sandstone boulder, its middle at `c` (buried below it), half sizes `size`: an ellipsoid swelled
## and dented by a few low waves, its foot buried.
static func sand_boulder(pk: PropKit, kit: Dictionary, c: Vector3, size: Vector3, rng: RandomNumberGenerator, col: Color) -> void:
	var rings := 10
	var segs := 20
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	var cc := Color(col.r, col.g, col.b, 0.0)
	var grid: Array = []
	var nrm: Array = []
	for i in range(rings + 1):
		var lat: float = lerpf(-0.45, 1.0, float(i) / float(rings)) * PI * 0.5
		var row: Array = []
		var nrow: Array = []
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs)
			var bump: float = 1.0 + 0.08 * sin(a * 2.0 + ph[0]) * cos(lat) + 0.05 * sin(a * 3.0 + lat * 2.5 + ph[1]) + 0.04 * cos(lat * 3.0 + ph[2]) + 0.03 * sin(a * 5.0 + ph[3])
			var dir := Vector3(cos(a) * cos(lat), sin(lat), sin(a) * cos(lat))
			row.append(c + Vector3(dir.x * size.x, dir.y * size.y, dir.z * size.z) * bump)
			nrow.append(Vector3(dir.x / size.x, dir.y / size.y, dir.z / size.z).normalized())
		grid.append(row)
		nrm.append(nrow)
	for i in range(rings):
		for j in range(segs):
			var j1: int = (j + 1) % segs
			var p00: Vector3 = grid[i][j]
			var p01: Vector3 = grid[i][j1]
			var p10: Vector3 = grid[i + 1][j]
			var p11: Vector3 = grid[i + 1][j1]
			var out: Vector3 = ((p00 + p11) * 0.5 - c).normalized()
			var u := func(p: Vector3) -> Vector2:
				return Vector2(atan2(p.z - c.z, p.x - c.x) * maxf(size.x, size.z), p.y - c.y + size.y) * uvk
			pk.tri(kit, "stucco", p00, p01, p11, nrm[i][j], nrm[i][j1], nrm[i + 1][j1], cc, out, u.call(p00), u.call(p01), u.call(p11))
			pk.tri(kit, "stucco", p00, p11, p10, nrm[i][j], nrm[i + 1][j1], nrm[i + 1][j], cc, out, u.call(p00), u.call(p11), u.call(p10))


## A desert villa of rendered sandstone among smooth boulders, its front toward -z (life size, the courtyard's
## paving at y 0): a terrace 1.8m up with stairs down to the courtyard; the hall in the middle (a great pointed
## arch over a balconied window and a round-arched porch, slender turrets with little domes at its corners, a round
## belvedere of arches on its roof); on the left a half-round loggia of pointed arches under a flat roof; on the right
## a domed drum, its lower storey ringed by a curved arcade, a big arched window above; a round tower at the far end;
## in the courtyard a round pool and a round stone majlis with cushions; boulders round it. Returns the footprint
## radius.
static func villa(pk: PropKit, kit: Dictionary, rng: RandomNumberGenerator) -> float:
	# Built mirrored, so that seen from the front the dome stands on the right as in the picture it was drawn from.
	var keep := pk.xf
	pk.set_frame(keep * Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO))
	var col := VILLA_SAND
	var pale := VILLA_PALE
	var deep := VILLA_DEEP
	var fy := 1.8
	# The courtyard, the pool and the majlis.
	slab(pk, kit, "stucco", Vector3(-24, -0.6, -30), Vector3(26, 0.05, -4.0), Color(0.78, 0.67, 0.52), 0.0)
	var pc := Vector3(-8.0, 0.05, -16.5)
	ring_wall(pk, kit, "stucco", pc, 4.6, 0.5, -0.25, 0.5, 0.0, TAU, 32, pale)
	disc_slab(pk, kit, "matte", pc, 4.12, -0.25, 0.18, 0.0, TAU, 32, Color(0.10, 0.36, 0.44))
	disc_slab(pk, kit, "glass", pc, 4.11, 0.33, 0.34, 0.0, TAU, 32, Color(0.35, 0.70, 0.78, 0.55))
	var mc := Vector3(3.0, 0.05, -18.5)
	disc_slab(pk, kit, "stucco", mc, 4.0, -0.25, 0.22, 0.0, TAU, 32, deep)
	var gap := 0.42
	ring_wall(pk, kit, "stucco", mc, 3.8, 0.8, 0.22, 0.66, PI * 0.5 + gap, PI * 0.5 + TAU - gap, 28, pale)
	ring_wall(pk, kit, "stucco", mc, 3.8, 0.28, 0.66, 1.15, PI * 0.5 + gap, PI * 0.5 + TAU - gap, 28, col)
	var cushion := [Color(0.50, 0.08, 0.14), Color(0.12, 0.42, 0.44), Color(0.90, 0.84, 0.72)]
	for k in range(9):
		var a: float = PI * 0.5 + gap + 0.18 + (TAU - 2.0 * gap - 0.36) * float(k) / 8.0
		var u := Vector3(cos(a), 0, sin(a))
		pk.box(kit, "cloth", Transform3D(Basis(Vector3.UP, -a + PI * 0.5), mc + u * 3.25 + Vector3(0, 0.78, 0)), Vector3(0.9, 0.22, 0.7), cushion[k % 3])
	pk.tube(kit, "stucco", mc + Vector3(0, 0.22, 0), mc + Vector3(0, 0.62, 0), 0.9, 0.9, 16, Color(pale.r, pale.g, pale.b, 0.0), true, uvk)
	# The terrace: its retaining wall with blind arches, parapets, the stairs.
	slab(pk, kit, "stucco", Vector3(-21, -0.6, -4.0), Vector3(23, fy, 22), deep, 0.0)
	for x in [-18.5, -14.5, -10.5, -6.5, 7.0, 11.0, 21.0]:
		arch_opening(pk, kit, Vector3(x, 0.2, -4.0), Vector3(0, 0, -1), 1.3, 1.35, true, "stucco", Color(deep.r * 0.82, deep.g * 0.82, deep.b * 0.82, 0.0), pale)
	for run in [[-21.0, -4.4], [4.4, 14.1], [19.4, 23.0]]:
		slab(pk, kit, "stucco", Vector3(run[0], fy, -4.0), Vector3(run[1], fy + 0.95, -3.6), col, 0.0)
		slab(pk, kit, "stucco", Vector3(float(run[0]) - 0.06, fy + 0.95, -4.08), Vector3(float(run[1]) + 0.06, fy + 1.08, -3.52), pale, 0.0)
	for sx in [-21.0, 22.6]:
		slab(pk, kit, "stucco", Vector3(sx, fy, -3.6), Vector3(sx + 0.4, fy + 0.95, 22), col, 0.0)
		slab(pk, kit, "stucco", Vector3(sx - 0.06, fy + 0.95, -3.6), Vector3(sx + 0.46, fy + 1.08, 22), pale, 0.0)
	stairs(pk, kit, -3.9, 3.9, -4.0, fy, 0.3, 0.42, Color(0.84, 0.74, 0.60), pale)
	stairs(pk, kit, 14.6, 18.9, -4.0, fy, 0.3, 0.42, Color(0.84, 0.74, 0.60), pale)
	# The hall.
	var hh := 10.5
	slab(pk, kit, "stucco", Vector3(-6.5, fy, 2.0), Vector3(6.5, fy + hh, 16.0), col, 0.0)
	slab(pk, kit, "stucco", Vector3(-6.75, fy + hh - 0.3, 1.75), Vector3(6.75, fy + hh + 0.12, 16.25), pale, 0.0)
	for e in [[Vector3(-6.5, 0, 1.9), Vector3(6.5, 0, 2.3)], [Vector3(-6.5, 0, 15.7), Vector3(6.5, 0, 16.1)], [Vector3(-6.6, 0, 2.3), Vector3(-6.2, 0, 15.7)], [Vector3(6.2, 0, 2.3), Vector3(6.6, 0, 15.7)]]:
		slab(pk, kit, "stucco", Vector3(e[0].x, fy + hh + 0.12, e[0].z), Vector3(e[1].x, fy + hh + 1.0, e[1].z), col, 0.0)
	arch_opening(pk, kit, Vector3(0, fy, 2.0), Vector3(0, 0, -1), 7.6, 9.4, true, "stucco", Color(deep.r, deep.g, deep.b, 0.0), pale)
	# The window over the porch, its mullions and transom, the balcony.
	arch_opening(pk, kit, Vector3(0, fy + 5.0, 1.93), Vector3(0, 0, -1), 3.0, 3.7, true, "dark", SHADOW, pale)
	for x in [-0.5, 0.5]:
		pk.box(kit, "timber", Transform3D(Basis(), Vector3(x, fy + 6.55, 1.86)), Vector3(0.09, 3.1, 0.08), TEAK_DARK, uvk)
	pk.box(kit, "timber", Transform3D(Basis(), Vector3(0, fy + 6.9, 1.86)), Vector3(2.95, 0.09, 0.08), TEAK_DARK, uvk)
	slab(pk, kit, "stucco", Vector3(-2.1, fy + 4.72, 1.0), Vector3(2.1, fy + 4.97, 1.94), pale, 0.0)
	for k in range(15):
		var bx: float = -1.96 + 3.92 * float(k) / 14.0
		pk.tube(kit, "stucco", Vector3(bx, fy + 4.97, 1.1), Vector3(bx, fy + 5.8, 1.1), 0.055, 0.055, 6, Color(pale.r, pale.g, pale.b, 0.0), false, uvk)
	pk.box(kit, "stucco", Transform3D(Basis(), Vector3(0, fy + 5.85, 1.1)), Vector3(4.1, 0.1, 0.16), Color(pale.r, pale.g, pale.b, 0.0), uvk)
	# The porch: a round arch through a block standing out of the great arch, the door at its back.
	arch_bay(pk, kit, "stucco", Vector3(-2.9, fy, -1.6), Vector3(2.9, fy, -1.6), Vector3(0, 0, 1), 3.5, 3.0, 4.3, 5.0, col, 0.5, true)
	slab(pk, kit, "stucco", Vector3(-3.05, fy + 5.0, -1.75), Vector3(3.05, fy + 5.25, 1.9), pale, 0.0)
	for e2 in [[Vector3(-2.9, 0, -1.6), Vector3(2.9, 0, -1.3)], [Vector3(-2.9, 0, -1.3), Vector3(-2.6, 0, 1.9)], [Vector3(2.6, 0, -1.3), Vector3(2.9, 0, 1.9)]]:
		slab(pk, kit, "stucco", Vector3(e2[0].x, fy + 5.25, e2[0].z), Vector3(e2[1].x, fy + 5.85, e2[1].z), col, 0.0)
	door(pk, kit, Vector3(0, fy, 1.9), Vector3(0, 0, -1), 2.0, 3.0, TEAK, pale, false)
	for sx2 in [-1.0, 1.0]:
		pk.box(kit, "lamp", Transform3D(Basis(), Vector3(sx2 * 1.25, fy + 3.3, 1.75)), Vector3(0.22, 0.34, 0.22), Color(1.0, 0.86, 0.6))
	# The turrets at the hall's front corners.
	for sx3 in [-1.0, 1.0]:
		var tc := Vector3(sx3 * 6.9, fy, 2.3)
		pk.tube(kit, "stucco", tc, tc + Vector3(0, hh + 1.6, 0), 1.0, 0.92, 16, Color(col.r, col.g, col.b, 0.0), true, uvk)
		pk.tube(kit, "stucco", tc + Vector3(0, hh - 0.3, 0), tc + Vector3(0, hh + 0.1, 0), 1.12, 1.12, 16, Color(pale.r, pale.g, pale.b, 0.0), true, uvk)
		pk.tube(kit, "stucco", tc + Vector3(0, hh + 1.6, 0), tc + Vector3(0, hh + 1.9, 0), 1.08, 1.08, 16, Color(pale.r, pale.g, pale.b, 0.0), true, uvk)
		pk.lathe(kit, "stucco", tc + Vector3(0, hh + 1.9, 0), [Vector2(0.98, 0.0), Vector2(0.92, 0.45), Vector2(0.62, 1.0), Vector2(0.0, 1.55)], 16, pale)
		pk.tube(kit, "metal", tc + Vector3(0, hh + 3.4, 0), tc + Vector3(0, hh + 4.2, 0), 0.05, 0.02, 6, BRASS)
		arch_opening(pk, kit, tc + Vector3(0, 7.2, -0.98), Vector3(0, 0, -1), 0.42, 1.1, false)
	# The belvedere on the roof: eight arches round a little floor, a flat roof with a ring of parapet.
	var bc := Vector3(-2.2, fy + hh + 0.12, 10.5)
	disc_slab(pk, kit, "stucco", bc, 2.5, 0.0, 0.25, 0.0, TAU, 24, pale)
	curved_arcade(pk, kit, bc + Vector3(0, 0.25, 0), 1.95, 0.0, TAU, 8, 1.75, 2.7, 0.3, col)
	disc_slab(pk, kit, "stucco", bc + Vector3(0, 2.95, 0), 2.4, 0.0, 0.3, 0.0, TAU, 24, pale)
	ring_wall(pk, kit, "stucco", bc + Vector3(0, 3.25, 0), 2.3, 0.22, 0.0, 0.55, 0.0, TAU, 24, col)
	# The left wing: a half-round loggia, its back a block against the hall.
	var cl := Vector3(-11.8, fy, 8.0)
	pk.tube(kit, "stucco", cl, cl + Vector3(0, 5.0, 0), 3.9, 3.9, 24, Color(col.r, col.g, col.b, 0.0), true, uvk)
	curved_arcade(pk, kit, cl, 6.2, PI, PI * 1.74, 5, 3.0, 5.0, 0.45, col)
	for k in range(5):
		var a2: float = lerpf(PI, PI * 1.74, (float(k) + 0.5) / 5.0)
		var u2 := Vector3(cos(a2), 0, sin(a2))
		arch_opening(pk, kit, cl + u2 * 3.96, u2, 1.3, 2.7, true, "dark", SHADOW, pale)
	disc_slab(pk, kit, "stucco", cl, 6.6, 5.0, 5.42, PI, TAU, 28, pale)
	ring_wall(pk, kit, "stucco", cl + Vector3(0, 5.42, 0), 6.5, 0.32, 0.0, 0.8, PI, PI * 1.86, 22, col)
	slab(pk, kit, "stucco", Vector3(-18.4, fy, 8.0), Vector3(-6.5, fy + 5.42, 16.0), col, 0.0)
	slab(pk, kit, "stucco", Vector3(-18.4, fy + 5.42, 8.0), Vector3(-18.0, fy + 6.22, 16.0), col, 0.0)
	slab(pk, kit, "stucco", Vector3(-18.4, fy + 5.42, 15.6), Vector3(-6.5, fy + 6.22, 16.0), col, 0.0)
	for k in range(3):
		arch_opening(pk, kit, Vector3(-18.4, fy + 1.2, 9.5 + k * 2.4), Vector3(-1, 0, 0), 1.0, 2.0, true, "dark", SHADOW, pale)
	# The right wing: the domed drum, a curved arcade round its lower storey, the big window above.
	var cr := Vector3(12.2, fy, 8.6)
	pk.tube(kit, "stucco", cr, cr + Vector3(0, 9.0, 0), 5.2, 5.2, 28, Color(col.r, col.g, col.b, 0.0), true, uvk)
	curved_arcade(pk, kit, cr, 7.3, PI * 1.25, TAU, 6, 3.0, 5.0, 0.45, col)
	for k in range(6):
		var a3: float = lerpf(PI * 1.25, TAU, (float(k) + 0.5) / 6.0)
		var u3 := Vector3(cos(a3), 0, sin(a3))
		arch_opening(pk, kit, cr + u3 * 5.26, u3, 1.3, 2.7, true, "dark", SHADOW, pale)
	disc_slab(pk, kit, "stucco", cr, 7.7, 5.0, 5.42, PI * 1.25, TAU, 24, pale, 5.18)
	ring_wall(pk, kit, "stucco", cr + Vector3(0, 5.42, 0), 7.6, 0.32, 0.0, 0.8, PI * 1.25, TAU, 22, col)
	pk.tube(kit, "stucco", cr + Vector3(0, 8.55, 0), cr + Vector3(0, 9.0, 0), 5.35, 5.35, 28, Color(pale.r, pale.g, pale.b, 0.0), true, uvk)
	var fw := Vector3(0, 0, -1)
	arch_opening(pk, kit, cr + fw * 5.27 + Vector3(0, 5.7, 0), fw, 2.7, 2.75, true, "dark", SHADOW, pale)
	for x2 in [-0.45, 0.45]:
		pk.box(kit, "timber", Transform3D(Basis(), cr + fw * 5.33 + Vector3(x2, 6.95, 0)), Vector3(0.08, 2.45, 0.06), TEAK_DARK, uvk)
	for a4 in [PI * 1.2, PI * 1.8, PI * 0.15]:
		var u4 := Vector3(cos(a4), 0, sin(a4))
		arch_opening(pk, kit, cr + u4 * 5.27 + Vector3(0, 6.0, 0), u4, 1.1, 2.1, true, "dark", SHADOW, pale)
	dome(pk, kit, "stucco", cr + Vector3(0, 9.0, 0), 5.2, 0.45, pale)
	slab(pk, kit, "stucco", Vector3(6.5, fy, 8.0), Vector3(8.6, fy + 8.0, 16.0), col, 0.0)
	# The round tower at the far right, standing on the courtyard below the terrace's corner.
	var tt := Vector3(21.2, -0.5, 16.5)
	pk.tube(kit, "stucco", tt, tt + Vector3(0, fy + 9.2, 0), 2.7, 2.45, 20, Color(col.r, col.g, col.b, 0.0), true, uvk)
	pk.tube(kit, "stucco", tt + Vector3(0, fy + 9.2, 0), tt + Vector3(0, fy + 9.55, 0), 2.62, 2.62, 20, Color(pale.r, pale.g, pale.b, 0.0), true, uvk)
	ring_wall(pk, kit, "stucco", tt + Vector3(0, fy + 9.55, 0), 2.55, 0.25, 0.0, 0.75, 0.0, TAU, 20, col)
	for k in range(3):
		var a5: float = PI * (1.35 + 0.3 * float(k))
		var u5 := Vector3(cos(a5), 0, sin(a5))
		arch_opening(pk, kit, tt + u5 * 2.52 + Vector3(0, 4.0 + 2.6 * float(k), 0), u5, 0.8, 1.5, true, "dark", SHADOW, pale)
	# Boulders round it, smooth sandstone, their feet buried.
	for b in [[-27.0, 10.0, 7.0, 5.5, 6.0], [-26.0, -9.0, 5.0, 4.0, 5.0], [-20.0, -31.0, 6.0, 4.5, 5.0], [28.0, 6.0, 6.5, 6.0, 6.0],
			[27.5, 21.0, 5.0, 5.0, 5.0], [25.5, -15.0, 4.5, 3.5, 4.0], [18.0, -32.0, 5.0, 3.8, 4.5], [-7.0, 28.0, 8.0, 7.0, 6.0],
			[11.0, 28.5, 7.0, 6.0, 6.0], [-15.5, -25.5, 1.6, 1.2, 1.4], [12.5, -25.0, 1.4, 1.0, 1.2], [22.0, -22.0, 2.0, 1.6, 1.8],
			[-23.0, 22.0, 4.0, 3.5, 3.5]]:
		var sz := Vector3(b[2], b[3], b[4])
		sand_boulder(pk, kit, Vector3(b[0], sz.y * 0.3, b[1]), sz, rng, VILLA_ROCK.lerp(VILLA_DEEP, rng.randf() * 0.4))
	pk.set_frame(keep)
	return 44.0


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
	for k in range(17):
		var a: float = PI * 0.5 * float(k) / 16.0
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
	pk.panel(kit, "awning", [Vector3(-half_w * 0.85, deck_y + 2.3, aw0), Vector3(half_w * 0.85, deck_y + 2.3, aw0),
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


## Saif al-Hamra, the sword gate (Ramlat Hamra): two giant curved swords crossed over the road like an arch, as Mombasa's
## tusks cross over their avenue, each held up from a pedestal at either side, its blade sweeping up and over to cross the
## other above the road's middle, its point beyond. In metres in its own frame: x across the road (the swords' guards at
## ±half_span), y up from the road (the pedestals' feet at `foot_l`/`foot_r`, the ground beside it), z along it (the
## two blades 1.5m apart along z, so they pass each other where they cross). Each blade is a circular arc from the guard
## (rising at 72 degrees, `guard_y` up) through the crossing (`cross_y` over the road's middle), its edge on the outside
## of the curve, a wedge in section (polished steel, faces flat so they catch the light), a fuller along it and a gold
## inlay by the hilt; a glowing line runs along the spine (the arch's underside). The hilt: a gold crossguard with ball
## finials and langets, a wrapped grip with gold bands, a gold pommel resting on its pedestal (stone, crenellated, a star
## medallion on each face). Returns the blades' middle lines, [[Vector3...], [Vector3...]] (for colliders).
static func sword_gate(pk: PropKit, kit: Dictionary, half_span := 13.5, guard_y := 9.0, cross_y := 24.0, foot_l := 0.0, foot_r := 0.0) -> Array:
	var steel := Color(0.86, 0.88, 0.90)
	var gold := Color(0.90, 0.70, 0.30)
	var grip_col := Color(0.30, 0.06, 0.05)
	var lines: Array = []
	var a0 := deg_to_rad(72.0)
	var g := Vector2(-half_span, guard_y)
	var d0 := Vector2(cos(a0), sin(a0))
	var nrm0 := Vector2(sin(a0), -cos(a0))
	var cg := Vector2(0.0, cross_y) - g
	var big_r: float = cg.length_squared() / (2.0 * cg.dot(nrm0))
	var o: Vector2 = g + nrm0 * big_r
	var th_g: float = atan2(g.y - o.y, g.x - o.x)
	var th_t: float = deg_to_rad(84.0)
	var n := 44
	for side in [-1.0, 1.0]:
		var sx: float = -side          # the left sword (side -1) is drawn as computed; the right one mirrored
		var zo: float = side * 0.75
		var foot: float = foot_l if side < 0.0 else foot_r
		var spine: Array = []
		var edge: Array = []
		var tw: Array = []
		var mid: Array = []
		for i in range(n + 1):
			var u: float = float(i) / n
			var th: float = lerpf(th_g, th_t, u)
			var c2: Vector2 = o + Vector2(cos(th), sin(th)) * big_r
			var out2 := Vector2(cos(th), sin(th))
			# The blade's width: 2.3m at the guard to 1.9m, a little wider toward the point (the yelman), then to the point.
			var w: float = lerpf(2.3, 1.9, u)
			if u > 0.6:
				w = lerpf(1.9, 2.15, smoothstep(0.6, 0.78, u))
			if u > 0.8:
				w *= 1.0 - pow((u - 0.8) / 0.2, 1.6)
			var t: float = lerpf(0.6, 0.38, u) * (1.0 - smoothstep(0.85, 1.0, u) * 0.9)
			var cs := Vector3(c2.x * sx, c2.y, zo)
			var ce := Vector3((c2.x + out2.x * w) * sx, c2.y + out2.y * w, zo)
			spine.append(cs)
			edge.append(ce)
			tw.append(t)
			mid.append((cs + ce) * 0.5)
		lines.append(mid)
		# The faces: front and back, each from the spine's edge (at ±t/2) to the cutting edge (z at zo).
		for i in range(n):
			for fz in [-1.0, 1.0]:
				var s0: Vector3 = spine[i] + Vector3(0, 0, fz * float(tw[i]) * 0.5)
				var s1: Vector3 = spine[i + 1] + Vector3(0, 0, fz * float(tw[i + 1]) * 0.5)
				var e0: Vector3 = edge[i]
				var e1: Vector3 = edge[i + 1]
				var fn: Vector3 = (s1 - s0).cross(e0 - s0).normalized()
				if fn.z * fz < 0.0:
					fn = -fn
				pk.quad(kit, "chrome", [s0, s1, e1, e0], fn, steel)
				# The fuller: a dark groove along the blade, a third of the way out from the spine, 1cm proud.
				var fa0: Vector3 = s0.lerp(e0, 0.22) + fn * 0.012
				var fa1: Vector3 = s1.lerp(e1, 0.22) + fn * 0.012
				var fb0: Vector3 = s0.lerp(e0, 0.30) + fn * 0.012
				var fb1: Vector3 = s1.lerp(e1, 0.30) + fn * 0.012
				if i < int(n * 0.8):
					pk.quad(kit, "metal", [fa0, fa1, fb1, fb0], fn, Color(0.38, 0.40, 0.44))
				# A gold inlay near the hilt: lozenges down the blade's middle.
				if i < 7 and i % 2 == 0:
					var mc: Vector3 = (s0.lerp(e0, 0.62) + s1.lerp(e1, 0.62)) * 0.5 + fn * 0.015
					var along: Vector3 = (s1 - s0).normalized()
					var across: Vector3 = (e0 - s0).normalized()
					pk.quad(kit, "metal", [mc - along * 0.45, mc - across * 0.28, mc + along * 0.45, mc + across * 0.28], fn, gold)
			# The spine's face (the arch's underside) and its line of light.
			var sb0: Vector3 = spine[i] + Vector3(0, 0, float(tw[i]) * 0.5)
			var sf0: Vector3 = spine[i] - Vector3(0, 0, float(tw[i]) * 0.5)
			var sb1: Vector3 = spine[i + 1] + Vector3(0, 0, float(tw[i + 1]) * 0.5)
			var sf1: Vector3 = spine[i + 1] - Vector3(0, 0, float(tw[i + 1]) * 0.5)
			var inward: Vector3 = ((spine[i] as Vector3) - (edge[i] as Vector3)).normalized()
			pk.quad(kit, "chrome", [sf0, sf1, sb1, sb0], inward, steel.darkened(0.1))
			var lw: float = minf(float(tw[i]), float(tw[i + 1])) * 0.22
			pk.quad(kit, "lamp", [spine[i] + inward * 0.01 - Vector3(0, 0, lw), spine[i + 1] + inward * 0.01 - Vector3(0, 0, lw),
					spine[i + 1] + inward * 0.01 + Vector3(0, 0, lw), spine[i] + inward * 0.01 + Vector3(0, 0, lw)], inward, Color(1.0, 0.78, 0.45))
		# The point closes on itself; the guard's end of the blade is capped by the guard.
		# The hilt: a crossguard across the blade's width at its foot, langets, the grip down from it, the pommel.
		var gs: Vector3 = spine[0]
		var ge: Vector3 = edge[0]
		var across0: Vector3 = (ge - gs).normalized()
		var gc: Vector3 = (gs + ge) * 0.5
		var down0 := Vector3(-d0.x * sx, -d0.y, 0.0)
		var ga: Vector3 = gs - across0 * 1.3
		var gb: Vector3 = ge + across0 * 1.3
		pk.beam(kit, "metal", ga, gb, 0.75, 0.55, gold, Vector3(0, 0, 1))
		for e in [[ga, -1.0], [gb, 1.0]]:
			var ep: Vector3 = e[0]
			var tipp: Vector3 = ep + across0 * float(e[1]) * 0.5 + down0 * 0.7
			pk.beam(kit, "metal", ep, tipp, 0.45, 0.45, gold, Vector3(0, 0, 1))
			pk.lathe(kit, "metal", tipp - Vector3(0, 0.42, 0), [Vector2(0.001, 0.0), Vector2(0.32, 0.12), Vector2(0.45, 0.42), Vector2(0.32, 0.72), Vector2(0.001, 0.84)], 12, gold)
		for fz in [-1.0, 1.0]:
			var lz := Vector3(0, 0, fz * 0.36)
			pk.tri(kit, "metal", gc + lz - across0 * 0.6, gc + lz + across0 * 0.6, gc + lz + Vector3(d0.x * sx, d0.y, 0) * 1.6, Vector3(0, 0, fz), Vector3(0, 0, fz), Vector3(0, 0, fz), gold, Vector3(0, 0, fz))
		var grip_len := 4.6
		var pommel: Vector3 = gc + down0 * grip_len
		pk.tube(kit, "matte", gc, pommel, 0.42, 0.48, 12, grip_col)
		for k in range(4):
			var bp: Vector3 = gc.lerp(pommel, 0.12 + 0.25 * k)
			pk.tube(kit, "metal", bp - down0 * 0.12, bp + down0 * 0.12, 0.52, 0.52, 12, gold)
		pk.lathe(kit, "metal", pommel - Vector3(0, 0.55, 0), [Vector2(0.001, 0.0), Vector2(0.55, 0.15), Vector2(0.75, 0.55), Vector2(0.55, 1.0), Vector2(0.2, 1.2), Vector2(0.001, 1.25)], 14, gold)
		pk.box(kit, "lamp", Transform3D(Basis(), pommel + Vector3(0, 0.75, 0)), Vector3(0.32, 0.32, 0.32), Color(0.9, 0.12, 0.1))
		# The pedestal under the pommel: a footing, a battered shaft with a star medallion on each face, a cornice and
		# merlons, a gold cradle round the grip.
		var px: float = pommel.x
		var top: float = pommel.y - 0.45
		var stone := Color(0.84, 0.66, 0.48)
		slab(pk, kit, "stone", Vector3(px - 3.6, foot - 3.0, -3.6 + zo), Vector3(px + 3.6, foot + 1.0, 3.6 + zo), stone.darkened(0.12), 0.0)
		battered(pk, kit, "mud", Vector3(px - 3.0, foot + 1.0, -3.0 + zo), Vector3(px + 3.0, top - 0.6, 3.0 + zo), 0.25, Color(stone.r, stone.g, stone.b, 0.15))
		slab(pk, kit, "stone", Vector3(px - 3.25, top - 0.6, -3.25 + zo), Vector3(px + 3.25, top, 3.25 + zo), stone.lightened(0.1), 0.0)
		merlons(pk, kit, "mud", Vector3(px - 2.9, top, -3.0 + zo), Vector3(px + 2.9, top, -3.0 + zo), stone, 1.1, 0.6, 0.45, 0.7)
		merlons(pk, kit, "mud", Vector3(px - 2.9, top, 3.0 + zo), Vector3(px + 2.9, top, 3.0 + zo), stone, 1.1, 0.6, 0.45, 0.7)
		merlons(pk, kit, "mud", Vector3(px - 3.0, top, -2.4 + zo), Vector3(px - 3.0, top, 2.4 + zo), stone, 1.1, 0.6, 0.45, 0.7)
		merlons(pk, kit, "mud", Vector3(px + 3.0, top, -2.4 + zo), Vector3(px + 3.0, top, 2.4 + zo), stone, 1.1, 0.6, 0.45, 0.7)
		var my: float = (foot + 1.0 + top - 0.6) * 0.5
		for f in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var fc: Vector3 = Vector3(px, my, zo) + f * 2.86
			var fb := Basis(Vector3.UP.cross(f).normalized(), Vector3.UP, f)
			for rot in [0.0, PI * 0.25]:
				pk.box(kit, "metal", Transform3D(fb * Basis(Vector3(0, 0, 1), rot), fc + f * 0.05), Vector3(1.3, 1.3, 0.08), gold)
			pk.box(kit, "lamp", Transform3D(fb, fc + f * 0.1), Vector3(0.36, 0.36, 0.06), Color(1.0, 0.75, 0.4))
		pk.tube(kit, "metal", pommel + down0 * -0.6 - Vector3(0, 0.1, 0), pommel + down0 * -0.6 + Vector3(0, 0.25, 0), 0.68, 0.68, 14, gold)
	return lines
