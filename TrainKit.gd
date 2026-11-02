extends RefCounted
## Freight Line's rolling stock, built through a PropKit at life size and grown by SCALE (like the
## camps and the matatus): a diesel locomotive, a boxcar, a covered grain hopper, a flatcar (empty, or
## carrying a load of short logs), a tank car and a caboose, and the express: a streamlined cab unit, coaches
## and an observation car. Every car is modelled along z with its nose toward -z, on y = 0 at the top of
## the rail, x across the track (gauge 1.435), and centred on its middle.
##
## `KINDS` is the data Train.gd needs: a car's length, its width and its height above the rail (the
## kill box and the crossings' idea of what a jump can clear) at life size. `build(kind, variant)`
## returns one ArrayMesh with a surface per material key (see `make_material`), cached per kind and
## variant: a train of fourteen cars is a handful of meshes.

const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")

## Game scale, over life size: the same people-sized-things factor the venues use (PROP_SCALE 1.6),
## a little under, so a boxcar stands 6m high beside a 1.5m cart.
const SCALE := 1.5

## length, width and height over the rail (life size, metres). `deck` is the height of what a cart
## could jump onto and over: the flatcar's floor.
const KINDS := {
	"loco": {"len": 19.0, "width": 3.2, "height": 4.5},
	"box": {"len": 15.0, "width": 3.0, "height": 4.2},
	"tank": {"len": 14.0, "width": 3.0, "height": 4.1},
	"flat": {"len": 16.0, "width": 3.0, "height": 1.45},
	"flat_load": {"len": 16.0, "width": 3.0, "height": 3.5},
	"hopper": {"len": 16.0, "width": 3.0, "height": 4.4},
	"caboose": {"len": 10.0, "width": 3.0, "height": 5.0},
	"ploco": {"len": 20.0, "width": 3.2, "height": 4.5},
	"coach": {"len": 26.0, "width": 3.0, "height": 4.6},
	"obs": {"len": 26.0, "width": 3.0, "height": 4.6},
}

const OXIDE := [Color(0.42, 0.17, 0.12), Color(0.17, 0.27, 0.21), Color(0.52, 0.41, 0.27), Color(0.30, 0.31, 0.34)]
const MAROON := Color(0.36, 0.07, 0.06)
const GOLD := Color(0.88, 0.62, 0.15)
const DARK := Color(0.08, 0.08, 0.09)
const IRON := Color(0.16, 0.15, 0.15)
const WOOD := Color(0.36, 0.26, 0.17)
const GLASS := Color(0.07, 0.12, 0.18, 0.9)
const LAMP := Color(1.0, 0.93, 0.70)

static var _cache := {}


static func make_material(key: String) -> StandardMaterial3D:
	var m: StandardMaterial3D
	match key:
		"paint":
			m = CampKit.make_material("gloss")
			m.roughness = 0.5
		"rust":
			m = CampKit.make_material("matte")
			m.roughness = 0.85
		_:
			m = CampKit.make_material(key)
	return m


static func car_length(kind: String) -> float:
	return float(KINDS[kind]["len"]) * SCALE


static func car_height(kind: String) -> float:
	return float(KINDS[kind]["height"]) * SCALE


static func car_half_width(kind: String) -> float:
	return float(KINDS[kind]["width"]) * 0.5 * SCALE


static func build(kind: String, variant: int = 0) -> ArrayMesh:
	var key := "%s_%d" % [kind, variant]
	if _cache.has(key):
		return _cache[key]
	var pk := PropKit.new()
	var mats := {}
	pk.material_for = func(k: String) -> Material:
		if not mats.has(k):
			mats[k] = make_material(k)
		return mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3.ZERO))
	var kit := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match kind:
		"loco":
			_loco(pk, kit, variant)
		"box":
			_box_car(pk, kit, variant, rng)
		"tank":
			_tank_car(pk, kit, variant)
		"flat":
			_flat_car(pk, kit, false, rng)
		"flat_load":
			_flat_car(pk, kit, true, rng)
		"hopper":
			_hopper(pk, kit, variant)
		"caboose":
			_caboose(pk, kit)
		"ploco":
			_cab_unit(pk, kit)
		"coach":
			_coach(pk, kit, false)
		"obs":
			_coach(pk, kit, true)
	var mesh := pk.commit(kit)
	_cache[key] = mesh
	return mesh


static func _jit(c: Color, rng: RandomNumberGenerator, amount := 0.05) -> Color:
	var d := rng.randf_range(-amount, amount)
	return Color(clampf(c.r + d, 0, 1), clampf(c.g + d, 0, 1), clampf(c.b + d, 0, 1), c.a)


# ======================================================================================
#  Shared parts
# ======================================================================================

## A two-axle (or three-axle) truck centred at z: side frames, bolster, axles and wheels.
static func _bogie(pk: PropKit, kit: Dictionary, z: float, axles: Array = [-0.85, 0.85]) -> void:
	var span: float = absf(axles[0]) + 0.5
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 0.98 - 0.07, 0.40, z - span), Vector3(sx * 0.98 + 0.07, 0.74, z + span), IRON)
		for ax in axles:
			pk.tube(kit, "steel", Vector3(sx * 0.62, 0.46, z + ax), Vector3(sx * 0.82, 0.46, z + ax), 0.46, 0.46, 14, Color(0.20, 0.19, 0.19))
			pk.tube(kit, "steel", Vector3(sx * 0.82, 0.46, z + ax), Vector3(sx * 0.98, 0.46, z + ax), 0.14, 0.14, 8, IRON)
	for ax in axles:
		pk.tube(kit, "steel", Vector3(-0.72, 0.46, z + ax), Vector3(0.72, 0.46, z + ax), 0.1, 0.1, 8, IRON)
	pk.block(kit, "steel", Vector3(-1.05, 0.72, z - 0.55), Vector3(1.05, 0.98, z + 0.55), IRON)


## The frame under a car: a deck slab between `y0` and `y1` with end beams and couplers.
static func _underframe(pk: PropKit, kit: Dictionary, half_len: float, y0: float, y1: float, col: Color) -> void:
	pk.block(kit, "steel", Vector3(-1.45, y0, -half_len), Vector3(1.45, y1, half_len), col)
	for sz in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(-1.4, y0 - 0.05, sz * half_len), Vector3(1.4, y1 + 0.12, sz * (half_len + 0.22)), IRON)
		# Coupler shank and knuckle.
		pk.block(kit, "steel", Vector3(-0.17, y0 + 0.05, sz * (half_len + 0.2)), Vector3(0.17, y0 + 0.35, sz * (half_len + 0.85)), DARK)
		pk.block(kit, "steel", Vector3(-0.3, y0 + 0.02, sz * (half_len + 0.75)), Vector3(0.3, y0 + 0.38, sz * (half_len + 1.0)), DARK)


## A ladder on a car's corner: two rails and rungs, up the end `sz` of side `sx`.
static func _ladder(pk: PropKit, kit: Dictionary, sx: float, z: float, y0: float, y1: float) -> void:
	var x := sx * 1.52
	pk.block(kit, "steel", Vector3(x - 0.03, y0, z - 0.2), Vector3(x + 0.03, y1, z - 0.15), IRON)
	pk.block(kit, "steel", Vector3(x - 0.03, y0, z + 0.15), Vector3(x + 0.03, y1, z + 0.2), IRON)
	var y := y0 + 0.25
	while y < y1:
		pk.block(kit, "steel", Vector3(x - 0.04, y, z - 0.2), Vector3(x + 0.04, y + 0.05, z + 0.2), IRON)
		y += 0.38


# ======================================================================================
#  Cars
# ======================================================================================

static func _box_car(pk: PropKit, kit: Dictionary, variant: int, rng: RandomNumberGenerator) -> void:
	var col: Color = OXIDE[variant % OXIDE.size()]
	var hl := 7.4
	_underframe(pk, kit, hl, 0.95, 1.2, IRON)
	_bogie(pk, kit, -5.1)
	_bogie(pk, kit, 5.1)
	# The body: a cross-section with an arched roof, extruded along the car.
	var prof := PackedVector2Array([
		Vector2(-1.5, 1.2), Vector2(1.5, 1.2), Vector2(1.5, 3.85), Vector2(1.22, 4.03), Vector2(0.62, 4.15),
		Vector2(0.0, 4.18), Vector2(-0.62, 4.15), Vector2(-1.22, 4.03), Vector2(-1.5, 3.85)])
	pk.extrude(kit, "paint", prof, -hl, hl, 0.04, col)
	var rib := col.darkened(0.16)
	var z := -hl + 0.5
	while z < hl - 0.3:
		for sx in [-1.0, 1.0]:
			pk.block(kit, "paint", Vector3(sx * 1.5 - 0.04, 1.25, z - 0.05), Vector3(sx * 1.5 + 0.04, 3.8, z + 0.05), _jit(rib, rng))
		z += 0.95
	# Sliding doors, a track above them and a stripe along the sill.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * 1.5 - 0.07, 1.3, -1.3), Vector3(sx * 1.5 + 0.07, 3.8, 1.3), col.lightened(0.07))
		pk.block(kit, "steel", Vector3(sx * 1.5 - 0.1, 3.78, -2.2), Vector3(sx * 1.5 + 0.1, 3.86, 2.2), IRON)
		pk.block(kit, "steel", Vector3(sx * 1.5 - 0.09, 2.3, 1.1), Vector3(sx * 1.5 + 0.09, 2.5, 1.2), IRON)
		pk.block(kit, "paint", Vector3(sx * 1.5 - 0.05, 1.2, -hl), Vector3(sx * 1.5 + 0.05, 1.32, hl), col.darkened(0.3))
		# The reporting mark: a pale band in place of lettering.
		pk.block(kit, "paint", Vector3(sx * 1.5 - 0.06, 3.0, -6.6), Vector3(sx * 1.5 + 0.06, 3.14, -3.2), Color(0.85, 0.82, 0.74))
		pk.block(kit, "paint", Vector3(sx * 1.5 - 0.06, 2.72, -6.6), Vector3(sx * 1.5 + 0.06, 2.8, -4.4), Color(0.85, 0.82, 0.74))
	# The roof walk.
	pk.block(kit, "wood", Vector3(-0.3, 4.17, -hl + 0.3), Vector3(0.3, 4.24, hl - 0.3), WOOD)
	for sz in [-1.0, 1.0]:
		for sx in [-1.0, 1.0]:
			_ladder(pk, kit, sx, sz * (hl - 0.45), 1.3, 3.9)
		pk.block(kit, "steel", Vector3(-0.05, 1.3, sz * (hl + 0.04)), Vector3(0.05, 3.0, sz * (hl + 0.1)), IRON)


static func _flat_car(pk: PropKit, kit: Dictionary, loaded: bool, rng: RandomNumberGenerator) -> void:
	var hl := 8.0
	_underframe(pk, kit, hl, 0.95, 1.2, IRON)
	_bogie(pk, kit, -5.6)
	_bogie(pk, kit, 5.6)
	# Side sills and the plank deck.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 1.5 - 0.05, 1.0, -hl), Vector3(sx * 1.5 + 0.05, 1.3, hl), Color(0.14, 0.13, 0.13))
	pk.block(kit, "wood", Vector3(-1.46, 1.2, -hl), Vector3(1.46, 1.3, hl), _jit(WOOD, rng, 0.03))
	var z := -hl + 0.45
	while z < hl:
		pk.block(kit, "wood", Vector3(-1.465, 1.28, z), Vector3(1.465, 1.3, z + 0.02), WOOD.darkened(0.3))
		z += 0.45
	# Stake pockets along both edges, and a low end rail.
	z = -hl + 0.8
	while z < hl - 0.6:
		for sx in [-1.0, 1.0]:
			pk.block(kit, "steel", Vector3(sx * 1.5 - 0.07, 1.3, z - 0.07), Vector3(sx * 1.5 + 0.07, 1.45, z + 0.07), IRON)
		z += 2.4
	for sz in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(-0.05, 1.3, sz * (hl - 0.1)), Vector3(0.05, 1.9, sz * (hl - 0.05)), IRON)
	# A brake wheel on a stand at one end, and the tie-down rings along the sills.
	pk.tube(kit, "steel", Vector3(0.9, 1.3, hl - 0.5), Vector3(0.9, 2.0, hl - 0.5), 0.05, 0.05, 6, IRON)
	pk.tube(kit, "steel", Vector3(0.9, 2.0, hl - 0.5), Vector3(0.9, 2.04, hl - 0.5), 0.3, 0.3, 12, IRON, false)
	if loaded:
		_log_load(pk, kit, hl, rng)


## The load of a log car: short logs lying across the car in three layers (each nested in the gaps of the one
## below), between steel stakes and two end bulkheads, held down by chains. Every log has bark, a swelling
## barrel and cut faces with rings.
static func _log_load(pk: PropKit, kit: Dictionary, hl: float, rng: RandomNumberGenerator) -> void:
	# End bulkheads: a frame of uprights with two rails, 2.6m high.
	for sz in [-1.0, 1.0]:
		var zb: float = sz * (hl - 0.25)
		for sx in [-1.45, -0.7, 0.0, 0.7, 1.45]:
			pk.block(kit, "steel", Vector3(sx - 0.07, 1.3, zb - 0.07), Vector3(sx + 0.07, 3.0, zb + 0.07), IRON)
		for y in [1.9, 2.5, 3.0]:
			pk.block(kit, "steel", Vector3(-1.5, y - 0.05, zb - 0.06), Vector3(1.5, y + 0.05, zb + 0.06), IRON)
	var spacing := 0.80
	var layers := 3
	for layer in range(layers):
		var y: float = 1.34 + 0.40 + layer * 0.69
		var n: int = 17 - (layer % 2)
		var z0: float = -(float(n) - 1.0) * 0.5 * spacing
		for k in range(n):
			var r: float = rng.randf_range(0.34, 0.41)
			var half: float = rng.randf_range(1.38, 1.62)
			var cx: float = rng.randf_range(-0.12, 0.12)
			_log(pk, kit, Vector3(cx, y + rng.randf_range(-0.02, 0.03), z0 + k * spacing), half, r, rng)
	# Stakes down both sides, every 2.4m, standing over the log ends, and two chains across the top.
	var z := -hl + 0.8
	while z < hl - 0.6:
		for sx in [-1.0, 1.0]:
			pk.block(kit, "steel", Vector3(sx * 1.72 - 0.07, 1.3, z - 0.07), Vector3(sx * 1.72 + 0.07, 3.15, z + 0.07), IRON)
		z += 2.4
	for cz in [-3.2, 3.2]:
		pk.block(kit, "steel", Vector3(-1.78, 3.1, cz - 0.04), Vector3(1.78, 3.16, cz + 0.04), Color(0.10, 0.10, 0.11))
		pk.block(kit, "steel", Vector3(-0.18, 3.08, cz - 0.1), Vector3(0.18, 3.22, cz + 0.1), Color(0.30, 0.30, 0.31))
		for sx in [-1.0, 1.0]:
			pk.block(kit, "steel", Vector3(sx * 1.78 - 0.04, 1.35, cz - 0.04), Vector3(sx * 1.78 + 0.04, 3.1, cz + 0.04), Color(0.10, 0.10, 0.11))


## One log along x centred on c: 3 rings of 8 bark ridges, a cut face at each end.
static func _log(pk: PropKit, kit: Dictionary, c: Vector3, half: float, r: float, rng: RandomNumberGenerator) -> void:
	const SIDES := 8
	var bark := Color(0.31 + rng.randf() * 0.09, 0.23 + rng.randf() * 0.06, 0.16 + rng.randf() * 0.04)
	var rot: float = rng.randf() * TAU
	var rings: Array = []
	var radii: Array = []
	for i in range(3):
		var t: float = float(i) / 2.0
		var rr: float = r * (1.0 + 0.08 * sin(t * PI)) * rng.randf_range(0.97, 1.03)
		radii.append(rr)
		var ring: Array = []
		for k in range(SIDES):
			var a: float = rot + TAU * float(k) / float(SIDES)
			# Fissured bark: every other ridge stands a little proud.
			var rk: float = rr * (1.0 if k % 2 == 0 else 0.92)
			ring.append(Vector3(c.x + lerpf(-half, half, t), c.y + sin(a) * rk, c.z + cos(a) * rk))
		rings.append(ring)
	for i in range(2):
		for k in range(SIDES):
			var k2: int = (k + 1) % SIDES
			var a: Vector3 = rings[i][k]
			var b: Vector3 = rings[i][k2]
			var d: Vector3 = rings[i + 1][k]
			var e: Vector3 = rings[i + 1][k2]
			var col: Color = bark * (0.78 if k % 2 == 1 else 1.0) * rng.randf_range(0.92, 1.08)
			col.a = 1.0
			var na := Vector3(0, a.y - c.y, a.z - c.z).normalized()
			var nb := Vector3(0, b.y - c.y, b.z - c.z).normalized()
			var nd := Vector3(0, d.y - c.y, d.z - c.z).normalized()
			var ne := Vector3(0, e.y - c.y, e.z - c.z).normalized()
			var out := (na + nb).normalized()
			pk.tri(kit, "bark", a, b, e, na, nb, ne, col, out)
			pk.tri(kit, "bark", a, e, d, na, ne, nd, col, out)
	# The cut faces: bark rim, pale sapwood, heartwood with two darker growth rings, a dark pith.
	var bands := [[1.0, 0.88, Color(0.26, 0.18, 0.11)], [0.88, 0.66, Color(0.80, 0.66, 0.42)], [0.66, 0.58, Color(0.55, 0.36, 0.19)],
			[0.58, 0.40, Color(0.68, 0.48, 0.26)], [0.40, 0.33, Color(0.52, 0.33, 0.17)], [0.33, 0.13, Color(0.66, 0.46, 0.25)]]
	for end in [0, 2]:
		var sgn: float = -1.0 if end == 0 else 1.0
		var xc: float = c.x + sgn * half
		var rr: float = radii[end]
		var nrm := Vector3(sgn, 0, 0)
		for bd in bands:
			var fo: float = bd[0]
			var fi: float = bd[1]
			var col2: Color = bd[2] * rng.randf_range(0.94, 1.06)
			col2.a = 1.0
			for k in range(SIDES):
				var a0: float = rot + TAU * float(k) / float(SIDES)
				var a1: float = rot + TAU * float(k + 1) / float(SIDES)
				var po0 := Vector3(xc, c.y + sin(a0) * rr * fo, c.z + cos(a0) * rr * fo)
				var po1 := Vector3(xc, c.y + sin(a1) * rr * fo, c.z + cos(a1) * rr * fo)
				var pi0 := Vector3(xc, c.y + sin(a0) * rr * fi, c.z + cos(a0) * rr * fi)
				var pi1 := Vector3(xc, c.y + sin(a1) * rr * fi, c.z + cos(a1) * rr * fi)
				pk.quad(kit, "wood", [po0, po1, pi1, pi0], nrm, col2)
		var pith := Color(0.28, 0.17, 0.09)
		for k in range(SIDES):
			var a0: float = rot + TAU * float(k) / float(SIDES)
			var a1: float = rot + TAU * float(k + 1) / float(SIDES)
			pk.tri(kit, "wood", Vector3(xc, c.y, c.z), Vector3(xc, c.y + sin(a0) * rr * 0.13, c.z + cos(a0) * rr * 0.13),
					Vector3(xc, c.y + sin(a1) * rr * 0.13, c.z + cos(a1) * rr * 0.13), nrm, nrm, nrm, pith, nrm)


## A covered grain hopper: a ribbed barrel under three roof hatches, on three discharge bays, with a platform
## and brake wheel at each end. `variant` 1 is the dark colourway.
static func _hopper(pk: PropKit, kit: Dictionary, variant: int) -> void:
	var col := Color(0.70, 0.70, 0.66) if variant % 2 == 0 else Color(0.30, 0.20, 0.15)
	var band := Color(0.90, 0.70, 0.12) if variant % 2 == 0 else Color(0.88, 0.82, 0.70)
	var hl := 8.0
	_underframe(pk, kit, hl, 0.95, 1.2, IRON)
	_bogie(pk, kit, -5.8)
	_bogie(pk, kit, 5.8)
	# The barrel: a rounded section from 1.9 to 4.0, a little narrower than the car at the top.
	var rings: Array = [_rrect(1.5, 1.85, 3.95, 0.34, -hl + 0.4, 4), _rrect(1.5, 1.85, 3.95, 0.34, hl - 0.4, 4)]
	_loft(pk, kit, "paint", rings, func(p: Vector3, _i: int) -> Color:
		if p.y < 2.45 and p.y > 2.2:
			return band
		return col
	, true, true)
	# Ribs standing out of the sides every 1.6m.
	var z := -hl + 1.2
	while z < hl - 0.8:
		for sx in [-1.0, 1.0]:
			pk.block(kit, "paint", Vector3(sx * 1.5 - 0.05, 2.0, z - 0.06), Vector3(sx * 1.5 + 0.05, 3.6, z + 0.06), col.darkened(0.18))
		z += 1.6
	# Three roof hatches with lids and a walkway between them.
	for hz in [-4.8, 0.0, 4.8]:
		pk.tube(kit, "steel", Vector3(0.0, 3.9, hz), Vector3(0.0, 4.2, hz), 0.55, 0.5, 12, col.darkened(0.2), true)
		pk.tube(kit, "steel", Vector3(0.0, 4.2, hz), Vector3(0.0, 4.26, hz), 0.62, 0.62, 12, IRON, true)
	pk.block(kit, "wood", Vector3(-0.3, 3.95, -hl + 0.6), Vector3(0.3, 4.0, hl - 0.6), WOOD.darkened(0.1))
	# The discharge bays: three funnels, 2.9m long, narrowing to a gate at the bottom.
	for bz in [-4.4, 0.0, 4.4]:
		var top: Array = [Vector3(-1.4, 1.9, bz - 1.45), Vector3(1.4, 1.9, bz - 1.45), Vector3(1.4, 1.9, bz + 1.45), Vector3(-1.4, 1.9, bz + 1.45)]
		var bot: Array = [Vector3(-0.35, 1.0, bz - 0.35), Vector3(0.35, 1.0, bz - 0.35), Vector3(0.35, 1.0, bz + 0.35), Vector3(-0.35, 1.0, bz + 0.35)]
		for k in 4:
			var k2: int = (k + 1) % 4
			var n: Vector3 = ((top[k2] - top[k]).cross(bot[k] - top[k])).normalized()
			var mid: Vector3 = (top[k] + top[k2] + bot[k] + bot[k2]) * 0.25
			if n.dot(mid - Vector3(0, 1.45, bz)) < 0.0:
				n = -n
			pk.quad(kit, "paint", [top[k], top[k2], bot[k2], bot[k]], n, col.darkened(0.12))
		pk.block(kit, "steel", Vector3(-0.42, 0.82, bz - 0.42), Vector3(0.42, 1.0, bz + 0.42), IRON)
		pk.beam(kit, "steel", Vector3(0.55, 0.86, bz), Vector3(1.05, 0.86, bz), 0.1, 0.1, IRON)
	# End platforms with a brake wheel on a post, and ladders.
	for sz in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(-1.5, 1.22, sz * hl), Vector3(1.5, 1.3, sz * (hl + 0.9)), IRON)
		pk.tube(kit, "steel", Vector3(1.0, 1.3, sz * (hl - 0.6)), Vector3(1.0, 2.2, sz * (hl - 0.6)), 0.05, 0.05, 6, IRON)
		pk.tube(kit, "steel", Vector3(1.0, 2.2, sz * (hl - 0.6)), Vector3(1.0, 2.24, sz * (hl - 0.6)), 0.32, 0.32, 12, IRON, false)
		for sx in [-1.0, 1.0]:
			_ladder(pk, kit, sx, sz * (hl - 0.45), 1.3, 3.8)


# ======================================================================================
#  The express: a cab unit, coaches, an observation car
# ======================================================================================

const CREAM := Color(0.93, 0.89, 0.76)
const TEAL := Color(0.08, 0.29, 0.41)
const PGOLD := Color(0.86, 0.66, 0.20)
const ROOF_GREY := Color(0.55, 0.57, 0.58)
const PGLASS := Color(0.05, 0.09, 0.13)


## A rounded rectangle in the x-y plane at depth z, counter-clockwise seen from +z, from the bottom edge:
## `n` + 1 points on each of the four corner arcs, so rings with different sizes still pair up point by point.
static func _rrect(hw: float, y0: float, y1: float, r: float, z: float, n := 4, edge_pts := 3) -> Array:
	r = minf(r, minf(hw, (y1 - y0) * 0.5) - 0.001)
	var cs := [Vector2(hw - r, y0 + r), Vector2(hw - r, y1 - r), Vector2(-hw + r, y1 - r), Vector2(-hw + r, y0 + r)]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	var pts: Array = []
	for c in 4:
		for k in range(n + 1):
			var a: float = float(starts[c]) + PI * 0.5 * float(k) / float(n)
			pts.append(Vector3(cs[c].x + cos(a) * r, cs[c].y + sin(a) * r, z))
		# The vertical edges get `edge_pts` points of their own (after the bottom-right and the top-left arcs),
		# so a colour boundary on a flat side is not decided by one tall quad.
		if c == 0 or c == 2:
			var ya: float = y0 + r if c == 0 else y1 - r
			var yb: float = y1 - r if c == 0 else y0 + r
			for k in range(1, edge_pts + 1):
				pts.append(Vector3(hw if c == 0 else -hw, lerpf(ya, yb, float(k) / float(edge_pts + 1)), z))
	return pts


## Skins a stack of rings (each an Array of Vector3 with the same count, closed loops) with smooth normals.
## `col_fn(point, ring index)` colours a vertex; `cap_first` / `cap_last` close the ends with a flat fan.
static func _loft(pk: PropKit, kit: Dictionary, key: String, rings: Array, col_fn: Callable, cap_first := false, cap_last := false) -> void:
	var nr: int = rings.size()
	var np: int = (rings[0] as Array).size()
	var centres: Array = []
	for ring in rings:
		var c := Vector3.ZERO
		for p in ring:
			c += p
		centres.append(c / float(np))
	# Face normals, oriented away from the ring's centre.
	var fnorm: Array = []
	for i in range(nr - 1):
		var row: Array = []
		for j in range(np):
			var j2: int = (j + 1) % np
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j2]
			var d: Vector3 = rings[i + 1][j]
			var e: Vector3 = rings[i + 1][j2]
			var n: Vector3 = (b - a).cross(d - a) + (e - b).cross(e - d)
			if n.length_squared() < 1e-12:
				n = a - centres[i]
			n = n.normalized()
			var mid: Vector3 = (a + b + d + e) * 0.25
			var away: Vector3 = mid - (centres[i] + centres[i + 1]) * 0.5
			away.z = 0.0
			if n.dot(away) < 0.0:
				n = -n
			row.append(n)
		fnorm.append(row)
	# Vertex normals: the mean of the faces round the vertex.
	var vn: Array = []
	for i in range(nr):
		var row: Array = []
		for j in range(np):
			var n := Vector3.ZERO
			for di in [-1, 0]:
				for dj in [-1, 0]:
					var fi: int = i + di
					var fj: int = posmod(j + dj, np)
					if fi >= 0 and fi < nr - 1:
						n += fnorm[fi][fj]
			row.append(n.normalized() if n.length_squared() > 1e-9 else Vector3.UP)
		vn.append(row)
	for i in range(nr - 1):
		for j in range(np):
			var j2: int = (j + 1) % np
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j2]
			var d: Vector3 = rings[i + 1][j]
			var e: Vector3 = rings[i + 1][j2]
			var col: Color = col_fn.call((a + b + d + e) * 0.25, i)
			pk.tri(kit, key, a, b, e, vn[i][j], vn[i][j2], vn[i + 1][j2], col, fnorm[i][j])
			pk.tri(kit, key, a, e, d, vn[i][j], vn[i + 1][j2], vn[i + 1][j], col, fnorm[i][j])
	for end in [0, 1]:
		if (end == 0 and not cap_first) or (end == 1 and not cap_last):
			continue
		var ri: int = 0 if end == 0 else nr - 1
		var out := Vector3(0, 0, -1.0 if end == 0 else 1.0)
		for j in range(np):
			var j2: int = (j + 1) % np
			var col: Color = col_fn.call(centres[ri], ri)
			pk.tri(kit, key, centres[ri], rings[ri][j], rings[ri][j2], out, out, out, col, out)


## A streamlined diesel cab unit for the express: a bullet nose with a raked windscreen, cream upper body over
## a teal skirt with a gold stripe, louvres, round windows, roof fans and a horn.
static func _cab_unit(pk: PropKit, kit: Dictionary) -> void:
	var hl := 10.0
	_underframe(pk, kit, hl, 0.95, 1.3, IRON)
	_bogie(pk, kit, -6.4, [-1.8, 0.0, 1.8])
	_bogie(pk, kit, 6.4, [-1.8, 0.0, 1.8])
	var rings: Array = []
	var nose_hw: Array = []
	# The nose: fourteen rings from the tip back to the body, narrowing and sinking toward the tip.
	const NOSE_RINGS := 14
	for k in range(NOSE_RINGS):
		var u: float = 1.0 - float(k) / float(NOSE_RINGS - 1)
		var hw: float = 1.55 * (1.0 - 0.82 * pow(u, 2.6))
		var y1: float = 4.3 - 1.7 * pow(u, 2.0)
		var y0: float = 1.15 + 0.7 * pow(u, 2.2)
		var rad: float = lerpf(0.55, hw * 0.95, pow(u, 1.5))
		rings.append(_rrect(hw, y0, y1, rad, -6.0 - 4.0 * u, 10))
		nose_hw.append(hw)
	rings.append(_rrect(1.55, 1.15, 4.3, 0.55, 9.9, 10))
	var body := func(p: Vector3, _i: int) -> Color:
		if p.y < 2.2:
			return TEAL
		if p.y > 4.18:
			return ROOF_GREY
		return CREAM
	_loft(pk, kit, "paint", rings, body, true, true)
	# The gold stripe along each side of the body, over the teal skirt's top edge.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * 1.55 - 0.02, 2.2, -6.0), Vector3(sx * 1.55 + 0.02, 2.32, 9.9), PGOLD)
	# The windscreen: a dark glass strip over the top of the sloping nose, a hair off the paint, following the
	# rings' points either side of the roof's centre line.
	var glass_ring: Callable = func(k: int) -> Array:
		var out: Array = []
		var ring: Array = rings[k]
		# Points straddling the top centre: arc 0 is points 0-10, the right edge 11-13, the top-right arc 14-24 and the
		# top-left arc 25-35 (the centre is between 24 and 25).
		for i in range(19, 31):
			var q: Vector3 = ring[i]
			out.append(q + Vector3(0.0, 0.035, -0.02))
		return out
	for k in range(2, NOSE_RINGS - 1):
		var r0: Array = glass_ring.call(k)
		var r1: Array = glass_ring.call(k + 1)
		for i in range(r0.size() - 1):
			pk.quad(kit, "matte", [r0[i], r1[i], r1[i + 1], r0[i + 1]], Vector3.UP, PGLASS)
	# Side detail: louvres in two banks, three round windows.
	for sx in [-1.0, 1.0]:
		for bank in [[-3.4, 0.4], [2.2, 6.4]]:
			var z0: float = bank[0]
			while z0 < float(bank[1]):
				pk.block(kit, "steel", Vector3(sx * 1.55 - 0.03, 2.55, z0), Vector3(sx * 1.55 + 0.03, 3.6, z0 + 0.1), Color(0.18, 0.19, 0.2))
				z0 += 0.22
		for wz in [-5.2, 8.0, 9.2]:
			pk.tube(kit, "glass", Vector3(sx * 1.55, 3.05, wz), Vector3(sx * 1.55 + sx * 0.04, 3.05, wz), 0.34, 0.34, 12, PGLASS, true)
	# Headlight on the tip, ditch lights lower down, a horn on the roof.
	pk.tube(kit, "lamp", Vector3(0.0, 2.15, -10.02), Vector3(0.0, 2.15, -10.1), 0.2, 0.2, 10, LAMP, true)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "lamp", Vector3(sx * 0.62, 1.95, -8.8), Vector3(sx * 0.62, 1.95, -8.88), 0.12, 0.12, 8, LAMP, true)
	pk.tube(kit, "steel", Vector3(0.0, 4.3, 2.0), Vector3(0.0, 4.75, 2.0), 0.1, 0.18, 8, Color(0.7, 0.62, 0.35), true)
	# Roof fans over the engine and a dynamic-brake hump at the rear.
	for fz in [-2.0, 0.6, 3.2]:
		pk.tube(kit, "steel", Vector3(0.0, 4.28, fz), Vector3(0.0, 4.4, fz), 0.55, 0.55, 14, Color(0.2, 0.21, 0.22), true)
	pk.block(kit, "paint", Vector3(-0.9, 4.28, 6.0), Vector3(0.9, 4.62, 9.4), ROOF_GREY.darkened(0.15))
	for sx in [-1.0, 1.0]:
		_ladder(pk, kit, sx, 9.0, 1.3, 2.6)


## A coach: a long rounded body with a window band (nine windows a side), a vestibule door at each end, a
## teal skirt, a gold stripe, roof air-conditioners, passenger trucks and a battery box. With `observation`
## the rear end is a glazed beavertail with a tail lamp and a drumhead sign.
static func _coach(pk: PropKit, kit: Dictionary, observation: bool) -> void:
	var hl := 12.9
	_underframe(pk, kit, hl, 0.95, 1.2, IRON)
	_bogie(pk, kit, -9.0, [-1.25, 1.25])
	_bogie(pk, kit, 9.0, [-1.25, 1.25])
	var z_end: float = hl - 0.2
	var rings: Array = [_rrect(1.5, 1.0, 4.05, 0.55, -z_end, 4)]
	if observation:
		rings.append(_rrect(1.5, 1.0, 4.05, 0.55, z_end - 3.4, 4))
		# The tail: the width closes in over 3.2m, the roof and floor keeping their height.
		for k in range(1, 7):
			var t: float = float(k) / 6.0
			var hw: float = maxf(1.5 * sqrt(maxf(1.0 - t * t, 0.0)), 0.12)
			rings.append(_rrect(hw, 1.0, 4.05, minf(0.55, hw), z_end - 3.4 + 3.4 * t, 4))
	else:
		rings.append(_rrect(1.5, 1.0, 4.05, 0.55, z_end, 4))
	var glass_tail: bool = observation
	_loft(pk, kit, "paint", rings, func(p: Vector3, _i: int) -> Color:
		if glass_tail and p.z > z_end - 3.4 and p.y > 2.2 and p.y < 3.45:
			return PGLASS
		if p.y < 2.05:
			return TEAL
		if p.y > 3.8:
			return ROOF_GREY
		return CREAM
	, true, true)
	# The gold pinstripe along each side, over the teal skirt's top edge.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * 1.5 - 0.02, 2.05, -z_end), Vector3(sx * 1.5 + 0.02, 2.15, z_end - (3.4 if observation else 0.0)), PGOLD)
	# Windows along both sides: dark glass set a hair proud with a bright frame bar over and under it.
	var wz := -z_end + 3.0
	var last_w: float = z_end - 3.0 - (3.6 if observation else 0.0)
	while wz <= last_w:
		for sx in [-1.0, 1.0]:
			pk.block(kit, "glass", Vector3(sx * 1.5 - (0.0 if sx > 0 else 0.03), 2.25, wz - 0.72), Vector3(sx * 1.5 + (0.03 if sx > 0 else 0.0), 3.35, wz + 0.72), PGLASS)
			pk.block(kit, "steel", Vector3(sx * 1.5 - 0.03, 3.35, wz - 0.78), Vector3(sx * 1.5 + 0.03, 3.42, wz + 0.78), Color(0.74, 0.75, 0.76))
			pk.block(kit, "steel", Vector3(sx * 1.5 - 0.03, 2.18, wz - 0.78), Vector3(sx * 1.5 + 0.03, 2.25, wz + 0.78), Color(0.74, 0.75, 0.76))
		wz += 2.2
	# Vestibule doors and the end diaphragm frame.
	for sz in [-1.0, 1.0]:
		if observation and sz > 0:
			continue
		for sx in [-1.0, 1.0]:
			pk.block(kit, "steel", Vector3(sx * 1.5 - 0.03, 1.3, sz * 11.7 - 0.55), Vector3(sx * 1.5 + 0.03, 3.5, sz * 11.7 + 0.55), Color(0.20, 0.22, 0.24))
			pk.block(kit, "glass", Vector3(sx * 1.5 - 0.04, 2.4, sz * 11.7 - 0.3), Vector3(sx * 1.5 + 0.04, 3.3, sz * 11.7 + 0.3), PGLASS)
			pk.block(kit, "steel", Vector3(sx * 1.52 - 0.03, 0.95, sz * 11.7 - 0.5), Vector3(sx * 1.52 + 0.03, 1.3, sz * 11.7 + 0.5), IRON)
		pk.block(kit, "steel", Vector3(-1.0, 1.2, sz * (z_end - 0.02)), Vector3(1.0, 3.7, sz * (z_end + 0.12)), Color(0.12, 0.12, 0.13))
	# Roof: air-conditioners, vents and a conduit run.
	for az in [-8.0, -2.8, 2.8, 8.0 if not observation else 6.4]:
		pk.block(kit, "steel", Vector3(-0.6, 4.05, az - 0.9), Vector3(0.6, 4.55, az + 0.9), Color(0.62, 0.64, 0.65))
		pk.block(kit, "steel", Vector3(-0.5, 4.55, az - 0.8), Vector3(0.5, 4.6, az + 0.8), Color(0.40, 0.42, 0.43))
	# Under the floor: a battery box each side, an air tank between.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 1.0 - 0.45, 0.55, -3.2), Vector3(sx * 1.0 + 0.45, 1.0, -0.9), Color(0.20, 0.20, 0.21))
	pk.tube(kit, "steel", Vector3(0.0, 0.7, 1.5), Vector3(0.0, 0.7, 5.5), 0.28, 0.28, 10, Color(0.24, 0.24, 0.25), true)
	if observation:
		# The tail lamp, a drumhead sign over it, a gold rail round the platform edge.
		pk.block(kit, "lamp", Vector3(-0.22, 2.0, z_end - 0.02), Vector3(0.22, 2.4, z_end + 0.12), Color(1.0, 0.18, 0.12))
		pk.block(kit, "lamp", Vector3(-0.6, 3.5, z_end - 0.6), Vector3(0.6, 3.95, z_end - 0.4), Color(1.0, 0.86, 0.55))
		pk.block(kit, "steel", Vector3(-0.75, 3.95, z_end - 0.7), Vector3(0.75, 4.0, z_end - 0.3), PGOLD)


static func _tank_car(pk: PropKit, kit: Dictionary, variant: int) -> void:
	var col := Color(0.76, 0.76, 0.72) if variant % 2 == 0 else Color(0.10, 0.10, 0.11)
	var hl := 6.3
	_underframe(pk, kit, 7.0, 0.95, 1.2, IRON)
	_bogie(pk, kit, -4.9)
	_bogie(pk, kit, 4.9)
	var cy := 2.75
	var r := 1.45
	pk.tube(kit, "paint", Vector3(0, cy, -hl), Vector3(0, cy, hl), r, r, 24, col, false)
	for sz in [-1.0, 1.0]:
		var basis := Basis(Vector3.RIGHT, PI * 0.5 * sz)
		pk.lathe(kit, "paint", Vector3(0, cy, sz * hl), [Vector2(r, 0.0), Vector2(r * 0.97, 0.22), Vector2(r * 0.85, 0.42), Vector2(r * 0.6, 0.57), Vector2(r * 0.25, 0.65), Vector2(0.001, 0.67)], 24, col, false, basis)
		# Saddle under the tank.
		pk.block(kit, "steel", Vector3(-1.1, 1.2, sz * 4.9 - 0.3), Vector3(1.1, cy - 0.9, sz * 4.9 + 0.3), IRON)
	# Bands, the dome hatch and a walkway along the top with its handrails.
	for z in [-3.0, 0.0, 3.0]:
		pk.tube(kit, "steel", Vector3(0, cy, z - 0.05), Vector3(0, cy, z + 0.05), r + 0.03, r + 0.03, 24, IRON, false)
	pk.tube(kit, "steel", Vector3(0, cy + r - 0.1, -0.5), Vector3(0, cy + r + 0.25, -0.5), 0.55, 0.5, 14, IRON)
	pk.block(kit, "wood", Vector3(-0.3, cy + r - 0.02, -hl + 0.4), Vector3(0.3, cy + r + 0.05, hl - 0.4), WOOD)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 0.62 - 0.02, cy + r + 0.55, -hl + 0.5), Vector3(sx * 0.62 + 0.02, cy + r + 0.6, hl - 0.5), IRON)
		for z in [-4.8, -2.4, 0.0, 2.4, 4.8]:
			pk.block(kit, "steel", Vector3(sx * 0.62 - 0.02, cy + r, z - 0.02), Vector3(sx * 0.62 + 0.02, cy + r + 0.6, z + 0.02), IRON)
		_ladder(pk, kit, sx, 6.9, 1.3, 3.2)
	# A hazard-coloured band along the middle.
	pk.tube(kit, "paint", Vector3(0, cy, 1.4), Vector3(0, cy, 2.1), r + 0.015, r + 0.015, 24, GOLD, false)


static func _caboose(pk: PropKit, kit: Dictionary) -> void:
	var hl := 4.6
	_underframe(pk, kit, 5.0, 0.95, 1.25, IRON)
	_bogie(pk, kit, -3.0)
	_bogie(pk, kit, 3.0)
	var red := Color(0.55, 0.10, 0.07)
	pk.block(kit, "paint", Vector3(-1.45, 1.25, -hl), Vector3(1.45, 3.9, hl), red)
	pk.block(kit, "paint", Vector3(-1.55, 3.9, -hl - 0.2), Vector3(1.55, 4.02, hl + 0.2), red.darkened(0.25))
	# The cupola.
	pk.block(kit, "paint", Vector3(-1.0, 4.02, -1.3), Vector3(1.0, 5.0, 1.3), red)
	pk.block(kit, "paint", Vector3(-1.12, 5.0, -1.45), Vector3(1.12, 5.12, 1.45), red.darkened(0.25))
	for sx in [-1.0, 1.0]:
		pk.block(kit, "glass", Vector3(sx * 1.0 - 0.03, 4.3, -0.9), Vector3(sx * 1.0 + 0.03, 4.85, 0.9), GLASS)
		for sz in [-1.0, 1.0]:
			pk.block(kit, "glass", Vector3(sx * 0.45 - 0.35, 4.3, sz * 1.3 - 0.03), Vector3(sx * 0.45 + 0.35, 4.85, sz * 1.3 + 0.03), GLASS)
		# Side windows and the gold sill stripe.
		for z in [-2.9, -0.9, 1.1, 3.0]:
			pk.block(kit, "glass", Vector3(sx * 1.45 - 0.04, 2.4, z - 0.4), Vector3(sx * 1.45 + 0.04, 3.3, z + 0.4), GLASS)
		pk.block(kit, "paint", Vector3(sx * 1.45 - 0.05, 1.5, -hl), Vector3(sx * 1.45 + 0.05, 1.75, hl), GOLD)
	# End platforms, rails and the marker lamps.
	for sz in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(-1.4, 1.2, sz * hl), Vector3(1.4, 1.3, sz * (hl + 1.1)), IRON)
		for sx in [-1.0, 1.0]:
			pk.block(kit, "steel", Vector3(sx * 1.35 - 0.03, 1.3, sz * (hl + 1.05)), Vector3(sx * 1.35 + 0.03, 2.3, sz * (hl + 1.1)), IRON)
		pk.block(kit, "steel", Vector3(-1.38, 2.25, sz * (hl + 1.05)), Vector3(1.38, 2.3, sz * (hl + 1.1)), IRON)
		pk.block(kit, "lamp", Vector3(-1.2, 3.0, sz * hl + sz * 0.02), Vector3(-0.9, 3.25, sz * hl + sz * 0.1), Color(0.9, 0.12, 0.08))
		pk.block(kit, "lamp", Vector3(0.9, 3.0, sz * hl + sz * 0.02), Vector3(1.2, 3.25, sz * hl + sz * 0.1), Color(0.9, 0.12, 0.08))
	# A smokestack.
	pk.tube(kit, "steel", Vector3(0.6, 3.9, 1.8), Vector3(0.6, 4.6, 1.8), 0.14, 0.14, 8, DARK)


## `variant` 2 is the yard switcher: safety yellow with black chevron-coloured trim instead of the maroon and gold.
static func _loco(pk: PropKit, kit: Dictionary, variant := 0) -> void:
	var body_col: Color = MAROON if variant != 2 else Color(0.90, 0.68, 0.08)
	var trim_col: Color = GOLD if variant != 2 else Color(0.08, 0.08, 0.09)
	var hl := 9.5
	_underframe(pk, kit, hl, 0.95, 1.38, IRON)
	_bogie(pk, kit, -6.2, [-1.8, 0.0, 1.8])
	_bogie(pk, kit, 6.2, [-1.8, 0.0, 1.8])
	pk.block(kit, "steel", Vector3(-1.2, 0.55, -2.0), Vector3(1.2, 1.0, 2.0), IRON)   # fuel tank
	# Short hood (the nose), cab and long hood.
	pk.block(kit, "paint", Vector3(-1.4, 1.38, -9.0), Vector3(1.4, 3.1, -5.2), body_col)
	pk.block(kit, "paint", Vector3(-1.3, 3.1, -8.8), Vector3(1.3, 3.35, -5.2), body_col.darkened(0.15))
	pk.block(kit, "paint", Vector3(-1.55, 1.38, -5.2), Vector3(1.55, 4.3, -1.6), body_col)
	pk.block(kit, "paint", Vector3(-1.68, 4.3, -5.45), Vector3(1.68, 4.46, -1.35), body_col.darkened(0.3))
	pk.block(kit, "paint", Vector3(-1.45, 1.38, -1.6), Vector3(1.45, 3.55, 9.2), body_col)
	pk.block(kit, "paint", Vector3(-1.2, 3.55, -1.4), Vector3(1.2, 3.8, 5.6), body_col.darkened(0.15))
	pk.block(kit, "paint", Vector3(-1.3, 3.55, 5.6), Vector3(1.3, 4.35, 9.2), body_col.darkened(0.2))
	# The gold livery: a band along the hood and cab sides, a chevron stripe on the nose.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * 1.46 - 0.04, 1.75, -9.0), Vector3(sx * 1.46 + 0.04, 2.05, 9.2), trim_col)
		pk.block(kit, "paint", Vector3(sx * 1.56 - 0.04, 1.75, -5.2), Vector3(sx * 1.56 + 0.04, 2.05, -1.6), trim_col)
	pk.block(kit, "paint", Vector3(-1.41, 1.75, -9.05), Vector3(1.41, 2.05, -8.95), trim_col)
	pk.block(kit, "paint", Vector3(-1.2, 3.35 - 0.02, -8.85), Vector3(1.2, 3.35 + 0.02, -8.0), trim_col)
	# The cab's windows (front, sides) and its door.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "glass", Vector3(sx * 0.65 - 0.5, 3.0, -5.24), Vector3(sx * 0.65 + 0.5, 4.05, -5.2), GLASS)
		pk.block(kit, "glass", Vector3(sx * 1.55 - 0.03, 3.0, -4.6), Vector3(sx * 1.55 + 0.03, 4.05, -2.8), GLASS)
		pk.block(kit, "paint", Vector3(sx * 1.56 - 0.03, 1.5, -3.3), Vector3(sx * 1.56 + 0.03, 2.9, -2.3), body_col.darkened(0.2))
	# Headlight, number boards and ditch lights on the nose.
	pk.block(kit, "lamp", Vector3(-0.3, 3.5, -8.95), Vector3(0.3, 3.9, -8.8), LAMP)
	pk.block(kit, "steel", Vector3(-0.35, 3.45, -8.85), Vector3(0.35, 3.95, -8.75), DARK)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "lamp", Vector3(sx * 0.95 - 0.17, 1.6, -9.04), Vector3(sx * 0.95 + 0.17, 1.9, -8.96), LAMP)
		pk.block(kit, "lamp", Vector3(sx * 1.02 - 0.18, 3.1, -9.04), Vector3(sx * 1.02 + 0.18, 3.35, -8.96), Color(0.95, 0.95, 0.9))
	# Radiator fans on the back of the long hood, exhaust stacks and the horn.
	for z in [6.5, 7.5, 8.5]:
		pk.tube(kit, "steel", Vector3(0, 4.35, z), Vector3(0, 4.42, z), 0.46, 0.46, 14, DARK)
	for z in [1.0, 2.6]:
		pk.tube(kit, "steel", Vector3(0, 3.8, z), Vector3(0, 4.25, z), 0.2, 0.18, 10, DARK)
	pk.tube(kit, "steel", Vector3(-0.6, 4.46, -3.4), Vector3(-0.6, 4.8, -3.4), 0.1, 0.18, 8, Color(0.7, 0.62, 0.35))
	# Walkways, handrails and the end steps.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 1.45, 1.36, -1.6), Vector3(sx * 1.75, 1.42, 9.2), IRON)
		pk.block(kit, "steel", Vector3(sx * 1.7 - 0.02, 2.4, -1.6), Vector3(sx * 1.7 + 0.02, 2.45, 9.2), Color(0.55, 0.55, 0.5))
		for z in [-1.6, 1.4, 4.4, 7.4, 9.2]:
			pk.block(kit, "steel", Vector3(sx * 1.7 - 0.02, 1.4, z - 0.02), Vector3(sx * 1.7 + 0.02, 2.45, z + 0.02), Color(0.55, 0.55, 0.5))
		_ladder(pk, kit, sx, -3.0, 0.9, 2.6)
