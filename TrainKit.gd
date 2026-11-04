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
## While a car is built without its bogies (`build(..., false)`), where each would go: [z (life size), axles].
static var _collect: Variant = null
static var _bogie_places := {}


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


## A car's mesh, life size times SCALE, front toward -z, the rails' top at y = 0. Without its bogies
## (`with_bogies` false), Train.gd sets them on the track one by one (`bogies`, `bogie_mesh`), so on a curve they
## follow the rails and the body swings between their pivots, as a real car's does.
static func build(kind: String, variant: int = 0, with_bogies := true) -> ArrayMesh:
	var key := "%s_%d%s" % [kind, variant, "" if with_bogies else "_bare"]
	if _cache.has(key):
		return _cache[key]
	if not with_bogies:
		_collect = []
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
	if not with_bogies:
		_bogie_places["%s_%d" % [kind, variant]] = _collect
		_collect = null
	return mesh


## Where a car's bogies go: [[z along the car (game metres, + toward its back), axles (life size)], ...].
static func bogies(kind: String, variant: int = 0) -> Array:
	var key := "%s_%d" % [kind, variant]
	if not _bogie_places.has(key):
		build(kind, variant, false)
	var out: Array = []
	for b in _bogie_places.get(key, []):
		out.append([float(b[0]) * SCALE, b[1]])
	return out


## One bogie, centred on its pivot at the origin (life size times SCALE).
static func bogie_mesh(axles: Array) -> ArrayMesh:
	var key := "bogie_%s" % str(axles)
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
	_bogie(pk, kit, 0.0, axles)
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
	if _collect != null:
		(_collect as Array).append([z, axles.duplicate()])
		return
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


## A shell lofted through `rings` (from _rrect, all at their own z, the first at the nose), cut at the heights `cuts`
## returns for a z (ascending, as many at every ring) into bands lofted apart, each in its own colour (`colours`, one
## more than the cuts, from the bottom up), so a livery's lines run clean along the cuts however coarse the rings are:
## one loft coloured quad by quad stepped the cab unit's lines into teeth. The lowest band runs round under the car
## from one side to the other, the highest over the top, each band between is a strip down either side. `counts` is how
## many points (by arc length) a band's piece takes at every ring. Both ends are capped, band by band.
static func _banded_shell(pk: PropKit, kit: Dictionary, key: String, rings: Array, cuts: Callable, colours: Array, counts: Array) -> void:
	var nb: int = colours.size()
	# parts[b][j]: the pieces of band b at ring j, each a PackedVector3Array of counts[b] points.
	var parts: Array = []
	for b in nb:
		parts.append([])
	var mids: Array = []
	for ring in rings:
		var z: float = (ring[0] as Vector3).z
		var pts := PackedVector2Array()
		var y0 := INF
		var y1 := -INF
		for p in ring:
			pts.append(Vector2(p.x, p.y))
			y0 = minf(y0, p.y)
			y1 = maxf(y1, p.y)
		mids.append((y0 + y1) * 0.5)
		var cs: Array = cuts.call(z)
		var cl: Array = []
		for k in range(cs.size()):
			cl.append(clampf(float(cs[k]), y0 + 0.004 * float(k + 1), y1 - 0.004 * float(cs.size() - k)))
		for b in nb:
			var lo: float = cl[b - 1] if b > 0 else -INF
			var hi: float = cl[b] if b < nb - 1 else INF
			var pieces: Array = []
			for poly in _ring_pieces(pts, lo, hi):
				pieces.append(_resample(poly, int(counts[b]), z))
			parts[b].append(pieces)
	for b in nb:
		var col: Color = colours[b]
		var nr: int = parts[b].size()
		for q in range((parts[b][0] as Array).size()):
			for j in range(nr - 1):
				var a: PackedVector3Array = parts[b][j][q]
				var c: PackedVector3Array = parts[b][j + 1][q]
				for i in range(a.size() - 1):
					var na: Vector3 = _shell_normal(parts[b], j, q, i, mids)
					var nb2: Vector3 = _shell_normal(parts[b], j, q, i + 1, mids)
					var nc: Vector3 = _shell_normal(parts[b], j + 1, q, i + 1, mids)
					var nd: Vector3 = _shell_normal(parts[b], j + 1, q, i, mids)
					var out: Vector3 = (na + nb2 + nc + nd).normalized()
					pk.tri(kit, key, a[i], a[i + 1], c[i + 1], na, nb2, nc, col, out)
					pk.tri(kit, key, a[i], c[i + 1], c[i], na, nc, nd, col, out)
		# The caps: the band's region of the end face, its pieces joined into one outline, as a fan.
		for end in [0, nr - 1]:
			var outline: Array = []
			for piece in parts[b][end]:
				for p in piece:
					outline.append(p)
			var centre := Vector3.ZERO
			for p in outline:
				centre += p
			centre /= float(outline.size())
			var nz := Vector3(0, 0, -1.0 if end == 0 else 1.0)
			for i in range(outline.size()):
				pk.tri(kit, key, centre, outline[i], outline[(i + 1) % outline.size()], nz, nz, nz, col, nz)


## The outline `pts` (a closed ring from _rrect, from the bottom, counter-clockwise seen from +z) between the heights
## lo and hi (-INF: everything under hi, round the bottom; INF: everything over lo, over the top), as polylines: one
## round the bottom or over the top, else the right side going up and the left going down.
static func _ring_pieces(pts: PackedVector2Array, lo: float, hi: float) -> Array:
	var n: int = pts.size()
	var cross := func(i: int, j: int, y: float) -> Vector2:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		return a.lerp(b, (y - a.y) / (b.y - a.y) if absf(b.y - a.y) > 1e-6 else 0.0)
	# The first point up the right side over `y`, and the last point down the left side over it.
	var right_over := func(y: float) -> int:
		for i in range(1, n):
			if pts[i].y > y:
				return i
		return n - 1
	var left_over := func(y: float) -> int:
		for i in range(n - 1, 0, -1):
			if pts[i].y > y:
				return i
		return 1
	if lo == -INF:
		var ir: int = right_over.call(hi)
		var il: int = left_over.call(hi)
		var poly := PackedVector2Array([cross.call(il, (il + 1) % n, hi)])
		for i in range(il + 1, n):
			poly.append(pts[i])
		for i in range(0, ir):
			poly.append(pts[i])
		poly.append(cross.call(ir - 1, ir, hi))
		return [poly]
	if hi == INF:
		var ir2: int = right_over.call(lo)
		var il2: int = left_over.call(lo)
		var poly2 := PackedVector2Array([cross.call(ir2 - 1, ir2, lo)])
		for i in range(ir2, il2 + 1):
			poly2.append(pts[i])
		poly2.append(cross.call(il2, (il2 + 1) % n, lo))
		return [poly2]
	var r_lo: int = right_over.call(lo)
	var r_hi: int = right_over.call(hi)
	var right := PackedVector2Array([cross.call(r_lo - 1, r_lo, lo)])
	for i in range(r_lo, r_hi):
		right.append(pts[i])
	right.append(cross.call(r_hi - 1, r_hi, hi))
	var l_hi: int = left_over.call(hi)
	var l_lo: int = left_over.call(lo)
	var left := PackedVector2Array([cross.call(l_hi, (l_hi + 1) % n, hi)])
	for i in range(l_hi + 1, l_lo + 1):
		left.append(pts[i])
	left.append(cross.call(l_lo, (l_lo + 1) % n, lo))
	return [right, left]


## A polyline resampled to `count` points evenly by length, at depth z.
static func _resample(poly: PackedVector2Array, count: int, z: float) -> PackedVector3Array:
	var lens := PackedFloat32Array([0.0])
	for i in range(1, poly.size()):
		lens.append(lens[i - 1] + poly[i].distance_to(poly[i - 1]))
	var total: float = lens[lens.size() - 1]
	var out := PackedVector3Array()
	var k := 0
	for i in range(count):
		var d: float = total * float(i) / float(maxi(count - 1, 1))
		while k < poly.size() - 2 and lens[k + 1] < d:
			k += 1
		var seg: float = lens[k + 1] - lens[k] if k + 1 < lens.size() else 0.0
		var p: Vector2 = poly[k].lerp(poly[mini(k + 1, poly.size() - 1)], (d - lens[k]) / seg if seg > 1e-6 else 0.0)
		out.append(Vector3(p.x, p.y, z))
	return out


## A shell's normal at point i of piece q of ring j: across the piece and along the rings, turned away from the ring's
## middle.
static func _shell_normal(band: Array, j: int, q: int, i: int, mids: Array) -> Vector3:
	var piece: PackedVector3Array = band[j][q]
	var p: Vector3 = piece[i]
	var across: Vector3 = piece[mini(i + 1, piece.size() - 1)] - piece[maxi(i - 1, 0)]
	var along: Vector3 = (band[mini(j + 1, band.size() - 1)][q] as PackedVector3Array)[i] - (band[maxi(j - 1, 0)][q] as PackedVector3Array)[i]
	var n: Vector3 = across.cross(along)
	if n.length_squared() < 1e-10:
		n = Vector3(p.x, p.y - float(mids[j]), 0.0)
	n = n.normalized()
	if n.dot(Vector3(p.x, p.y - float(mids[j]), 0.0)) < 0.0:
		n = -n
	return n


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


## A streamlined diesel cab unit for the express, in the coaches' teal, cream and gold: a full-width "bulldog" nose
## (the body's rounded section carried forward, its top dropping from the cab's roof down a raked two-pane windscreen
## onto a rounded hood and over a bulging front to a pilot), not the tapering bullet it had been, which read as the
## Bloombay monorail. A cream band runs along the sides between gold lines and sweeps down into a V on the nose under
## a big headlight; the cab has side windows and a door, the engine room portholes and louvres, the roof fans and a
## horn.
static func _cab_unit(pk: PropKit, kit: Dictionary) -> void:
	var hl := 10.0
	# The frame's end beams tucked under the nose and the tail (a full-length frame stood out in front of the nose).
	_underframe(pk, kit, hl - 0.35, 0.95, 1.3, IRON)
	_bogie(pk, kit, -6.4, [-1.8, 0.0, 1.8])
	_bogie(pk, kit, 6.4, [-1.8, 0.0, 1.8])
	# The section from the nose's tip back: [z, half width, bottom, top, corner radius].
	const WS_FOOT := -7.75
	const WS_HEAD := -6.75
	var sections: Array = [
		[-10.15, 1.06, 1.32, 1.98, 0.55],
		[-10.06, 1.31, 1.22, 2.28, 0.62],
		[-9.88, 1.45, 1.17, 2.54, 0.7],
		[-9.55, 1.52, 1.15, 2.76, 0.74],
		[-9.05, 1.545, 1.15, 2.93, 0.74],
		[-8.4, 1.55, 1.15, 3.08, 0.7],
		[WS_FOOT, 1.55, 1.15, 3.24, 0.66],
		[WS_HEAD, 1.55, 1.15, 4.12, 0.6],
		[-6.35, 1.55, 1.15, 4.3, 0.55],
		[9.9, 1.55, 1.15, 4.3, 0.55],
	]
	# The livery: teal below, a gold line, cream above, the line sweeping down along the nose to a teal chin under the
	# headlight. Each colour is a band of its own (_banded_shell), so the line stays clean down the curved nose.
	const BAND_LO := 2.45
	var rings: Array = []
	for sc in sections:
		rings.append(_rrect(sc[1], sc[2], sc[3], sc[4], sc[0], 10))
	var cuts := func(z: float) -> Array:
		var lo: float = BAND_LO - 0.6 * smoothstep(-6.4, -10.1, z)
		return [lo - 0.1, lo]
	_banded_shell(pk, kit, "paint", rings, cuts, [TEAL, PGOLD, CREAM], [34, 3, 44])
	# The windscreen: two panes on the flat of the raked slope between WS_FOOT and WS_HEAD, a centre post between them,
	# each in a dark frame; all standing off the paint along the slope's normal.
	var foot := Vector3(0.0, 3.24, WS_FOOT)
	var head := Vector3(0.0, 4.12, WS_HEAD)
	var up_slope: Vector3 = (head - foot).normalized()
	var ws_n := Vector3(0.0, up_slope.z, -up_slope.y)
	for sx in [-1.0, 1.0]:
		var xa: float = sx * 0.08
		var xb: float = sx * 0.86
		var b0: Vector3 = foot + up_slope * 0.12
		var t0: Vector3 = head - up_slope * 0.1
		pk.quad(kit, "steel", [b0 + Vector3(xa - sx * 0.04, 0, 0) + ws_n * 0.02, b0 + Vector3(xb + sx * 0.06, 0, 0) + ws_n * 0.02,
				t0 + Vector3(xb + sx * 0.06, 0, 0) + ws_n * 0.02, t0 + Vector3(xa - sx * 0.04, 0, 0) + ws_n * 0.02], ws_n, Color(0.1, 0.1, 0.11))
		var g0: Vector3 = b0 + up_slope * 0.05
		var g1: Vector3 = t0 - up_slope * 0.05
		pk.quad(kit, "glass", [g0 + Vector3(xa, 0, 0) + ws_n * 0.04, g0 + Vector3(xb, 0, 0) + ws_n * 0.04, g1 + Vector3(xb, 0, 0) + ws_n * 0.04,
				g1 + Vector3(xa, 0, 0) + ws_n * 0.04], ws_n, PGLASS)
	# The cab: a side window either side and a door behind it, each framed (on the side's straight part, under the
	# roof's curve); grab irons beside the door.
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.55
		pk.block(kit, "steel", Vector3(x - 0.02 if sx > 0 else x - 0.03, 2.94, -6.28), Vector3(x + 0.03 if sx > 0 else x + 0.02, 3.68, -5.0), Color(0.1, 0.1, 0.11))
		pk.block(kit, "glass", Vector3(x - 0.02 if sx > 0 else x - 0.045, 3.0, -6.22), Vector3(x + 0.045 if sx > 0 else x + 0.02, 3.62, -5.06), PGLASS)
		for door in [[-4.75, -3.85]]:
			pk.block(kit, "steel", Vector3(x - 0.02 if sx > 0 else x - 0.03, 1.35, door[0]), Vector3(x + 0.03 if sx > 0 else x + 0.02, 3.68, door[0] + 0.05), Color(0.1, 0.1, 0.11))
			pk.block(kit, "steel", Vector3(x - 0.02 if sx > 0 else x - 0.03, 1.35, door[1] - 0.05), Vector3(x + 0.03 if sx > 0 else x + 0.02, 3.68, door[1]), Color(0.1, 0.1, 0.11))
			pk.block(kit, "steel", Vector3(x - 0.02 if sx > 0 else x - 0.03, 3.63, door[0]), Vector3(x + 0.03 if sx > 0 else x + 0.02, 3.68, door[1]), Color(0.1, 0.1, 0.11))
			pk.block(kit, "glass", Vector3(x - 0.02 if sx > 0 else x - 0.045, 3.0, door[0] + 0.15), Vector3(x + 0.045 if sx > 0 else x + 0.02, 3.55, door[1] - 0.15), PGLASS)
			pk.tube(kit, "steel", Vector3(x + sx * 0.08, 1.6, door[0] - 0.15), Vector3(x + sx * 0.08, 3.3, door[0] - 0.15), 0.025, 0.025, 6, Color(0.75, 0.76, 0.77), true)
		# Portholes along the engine room, in the cream band, and louvred grilles toward the rear.
		for wz in [-1.6, 1.2, 4.0]:
			pk.tube(kit, "steel", Vector3(x, 3.12, wz), Vector3(x + sx * 0.035, 3.12, wz), 0.36, 0.36, 14, Color(0.74, 0.75, 0.76), true)
			pk.tube(kit, "glass", Vector3(x + sx * 0.035, 3.12, wz), Vector3(x + sx * 0.05, 3.12, wz), 0.29, 0.29, 14, PGLASS, true)
		pk.block(kit, "steel", Vector3(x - 0.02 if sx > 0 else x - 0.035, 2.75, 5.8), Vector3(x + 0.035 if sx > 0 else x + 0.02, 3.55, 9.1), Color(0.14, 0.15, 0.16))
		var lz := 5.95
		while lz < 9.0:
			pk.block(kit, "steel", Vector3(x - 0.02 if sx > 0 else x - 0.06, 2.8, lz), Vector3(x + 0.06 if sx > 0 else x + 0.02, 3.5, lz + 0.07), Color(0.32, 0.34, 0.35))
			lz += 0.2
	# The headlight, set into the slope of the hood's front (a chrome rim round a lamp, both tilted with the surface),
	# and two marker lights low on the nose.
	var hl_c := Vector3(0.0, 2.41, -9.97)
	var hl_n := Vector3(0.0, 0.57, -0.82).normalized()
	pk.tube(kit, "steel", hl_c - hl_n * 0.04, hl_c + hl_n * 0.05, 0.27, 0.25, 16, Color(0.78, 0.79, 0.8), true)
	pk.tube(kit, "lamp", hl_c + hl_n * 0.05, hl_c + hl_n * 0.065, 0.2, 0.2, 16, LAMP, true)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "lamp", Vector3(sx * 0.66, 1.52, -10.0), Vector3(sx * 0.66, 1.52, -10.2), 0.1, 0.1, 10, Color(1.0, 0.86, 0.6), true)
	# The pilot: a plough plate raked back under the nose, with its cheeks.
	var pt0 := 1.15
	var pt1 := 0.36
	var pz0 := -9.95
	var pz1 := -10.75
	var pcol := Color(0.26, 0.27, 0.28)
	pk.quad(kit, "steel", [Vector3(-1.32, pt0, pz0), Vector3(1.32, pt0, pz0), Vector3(1.2, pt1, pz1), Vector3(-1.2, pt1, pz1)], Vector3(0, -0.8, -1.0).normalized(), pcol)
	# Its back, 4cm behind (the plate had one face: from behind, the rear unit's pilot wasn't there), and a bottom edge.
	var pb := Vector3(0, 0.03, 0.03)
	pk.quad(kit, "steel", [Vector3(-1.32, pt0, pz0) + pb, Vector3(1.32, pt0, pz0) + pb, Vector3(1.2, pt1, pz1) + pb, Vector3(-1.2, pt1, pz1) + pb], Vector3(0, 0.8, 1.0).normalized(), pcol.darkened(0.3))
	pk.quad(kit, "steel", [Vector3(-1.2, pt1, pz1), Vector3(1.2, pt1, pz1), Vector3(1.2, pt1, pz1) + pb, Vector3(-1.2, pt1, pz1) + pb], Vector3(0, -1, -0.3).normalized(), pcol.darkened(0.2))
	for sx in [-1.0, 1.0]:
		pk.tri(kit, "steel", Vector3(sx * 1.32, pt0, pz0), Vector3(sx * 1.2, pt1, pz1), Vector3(sx * 1.32, pt1, pz0), Vector3(sx, 0, 0), Vector3(sx, 0, 0), Vector3(sx, 0, 0), pcol.darkened(0.2), Vector3(sx, 0, 0))
		pk.tri(kit, "steel", Vector3(sx * 1.32, pt0, pz0), Vector3(sx * 1.2, pt1, pz1), Vector3(sx * 1.32, pt1, pz0), Vector3(-sx, 0, 0), Vector3(-sx, 0, 0), Vector3(-sx, 0, 0), pcol.darkened(0.35), Vector3(-sx, 0, 0))
	for k in range(5):
		var bx: float = -0.9 + 0.45 * float(k)
		pk.beam(kit, "steel", Vector3(bx, pt0 - 0.08, pz0 - 0.1), Vector3(bx * 0.95, pt1 + 0.08, pz1 + 0.06), 0.06, 0.06, pcol.darkened(0.35), Vector3(1, 0, 0))
	# The horn, roof fans over the engine and the dynamic brake's hatch toward the rear.
	pk.tube(kit, "steel", Vector3(0.0, 4.3, -5.4), Vector3(0.0, 4.72, -5.4), 0.1, 0.18, 8, Color(0.7, 0.62, 0.35), true)
	for fz in [-2.0, 0.6, 3.2]:
		pk.tube(kit, "steel", Vector3(0.0, 4.28, fz), Vector3(0.0, 4.4, fz), 0.55, 0.55, 14, Color(0.2, 0.21, 0.22), true)
		pk.tube(kit, "steel", Vector3(0.0, 4.4, fz), Vector3(0.0, 4.43, fz), 0.48, 0.48, 14, Color(0.35, 0.36, 0.37), false)
	pk.block(kit, "paint", Vector3(-0.9, 4.28, 6.0), Vector3(0.9, 4.58, 9.4), ROOF_GREY.darkened(0.15))
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


## `variant` 2 is the yard switcher (`_switcher`); the rest the road diesel in maroon and gold.
static func _loco(pk: PropKit, kit: Dictionary, variant := 0) -> void:
	if variant == 2:
		_switcher(pk, kit)
		return
	_road_diesel(pk, kit, variant)
	return
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


const SAFETY_YELLOW := Color(0.93, 0.70, 0.07)
const RAIL_WHITE := Color(0.88, 0.88, 0.84)


## A rounded rectangle in the x-y plane (x across, y up), counter-clockwise from +z: hw half wide, y0 to y1, its top
## corners rounded by r (`crown` raises the middle of the top), for PropKit.extrude along z.
static func _round_top(hw: float, y0: float, y1: float, r: float, crown := 0.0, segs := 5) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-hw, y0), Vector2(hw, y0)])
	for i in range(segs + 1):
		var a: float = PI * 0.5 * float(i) / float(segs)
		pts.append(Vector2(hw - r + r * cos(a), y1 - r + r * sin(a)))
	if crown > 0.0:
		pts.append(Vector2(0.0, y1 + crown))
	for i in range(segs + 1):
		var a2: float = PI * 0.5 + PI * 0.5 * float(i) / float(segs)
		pts.append(Vector2(-hw + r + r * cos(a2), y1 - r + r * sin(a2)))
	return pts


## The yard switcher: an end-cab diesel (the cab at +z), safety yellow on a black frame. A long hood with a rounded
## top, panelled doors, louvres and the radiator grille at its front, fans and the exhaust on top; the cab with
## windows all round under a crowned black roof, a beacon and horns; walkways round the hood with white handrails,
## steps at the corners, black-and-yellow chevrons across both ends, twin headlights, ditch and marker lights,
## air tanks and the fuel tank under the frame, hoses at the couplers. Life size, the length of a "loco" (19m).
static func _switcher(pk: PropKit, kit: Dictionary) -> void:
	var hl := 9.5
	var deck := 1.38
	_underframe(pk, kit, hl, 0.95, deck, DARK)
	_bogie(pk, kit, -5.6, [-1.15, 1.15])
	_bogie(pk, kit, 5.6, [-1.15, 1.15])
	# Under the frame: the fuel tank (rounded, with a gauge), two air tanks along the sides.
	pk.extrude(kit, "steel", _round_top(1.15, 0.42, 0.95, 0.2, 0.0, 3), -3.4, 2.4, 0.05, IRON)
	pk.block(kit, "steel", Vector3(1.16, 0.7, -0.4), Vector3(1.2, 0.85, 0.2), RAIL_WHITE)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "steel", Vector3(sx * 1.05, 0.78, 2.9), Vector3(sx * 1.05, 0.78, 4.4), 0.2, 0.2, 10, IRON)
	# --- The ends: a pilot under each end sill in yellow with black chevrons, the end sill's edge yellow too.
	for sz in [-1.0, 1.0]:
		_pilot(pk, kit, hl, sz, SAFETY_YELLOW, DARK)
	# --- The walkway (diamond plate) round the hood, the steps at the corners.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 1.17 - 0.0 if sx > 0.0 else -1.58, deck, -hl), Vector3(1.58 if sx > 0.0 else -1.17, deck + 0.04, 3.4), IRON.lightened(0.08))
		for sz in [-1.0, 1.0]:
			var z0: float = sz * (hl - 0.05)
			var z1: float = sz * (hl - 0.75)
			for k in 2:
				var ty: float = 0.5 + 0.42 * float(k)
				pk.block(kit, "steel", Vector3(sx * 1.2 if sx > 0.0 else -1.62, ty, minf(z0, z1)), Vector3(1.62 if sx > 0.0 else -1.2, ty + 0.05, maxf(z0, z1)), IRON)
				pk.block(kit, "paint", Vector3(sx * 1.58 if sx > 0.0 else -1.63, ty + 0.05, minf(z0, z1)), Vector3(1.63 if sx > 0.0 else -1.58, ty + 0.08, maxf(z0, z1)), SAFETY_YELLOW)
			pk.block(kit, "steel", Vector3(sx * 1.58 if sx > 0.0 else -1.62, 0.45, minf(z0, z1) - 0.03), Vector3(1.62 if sx > 0.0 else -1.58, deck, minf(z0, z1)), DARK)
			pk.block(kit, "steel", Vector3(sx * 1.58 if sx > 0.0 else -1.62, 0.45, maxf(z0, z1)), Vector3(1.62 if sx > 0.0 else -1.58, deck, maxf(z0, z1) + 0.03), DARK)
	# --- The long hood: rounded top, from the front end to the cab.
	var hood_hw := 1.12
	var hood_top := 3.5
	var hz0 := -9.0
	var hz1 := 3.4
	pk.extrude(kit, "paint", _round_top(hood_hw, deck, hood_top, 0.32), hz0, hz1, 0.04, SAFETY_YELLOW)
	# Doors down both sides (seams, handles), louvres on the ones by the radiator, a black band along the sill.
	for sx in [-1.0, 1.0]:
		var fx: float = sx * (hood_hw + 0.012)
		var z := hz0 + 0.5
		var door := 0
		while z < hz1 - 0.6:
			pk.block(kit, "paint", Vector3(fx - 0.012, 1.6, z - 0.015), Vector3(fx + 0.012, 3.15, z + 0.015), SAFETY_YELLOW.darkened(0.35))
			pk.block(kit, "steel", Vector3(fx + sx * 0.02 - 0.02, 2.3, z + 0.55), Vector3(fx + sx * 0.02 + 0.02, 2.36, z + 0.75), RAIL_WHITE)
			if door < 3:
				var y := 2.45
				while y < 3.05:
					pk.block(kit, "paint", Vector3(fx - 0.02, y, z + 0.2), Vector3(fx + 0.02, y + 0.05, z + 1.2), DARK)
					y += 0.12
			z += 1.45
			door += 1
		pk.block(kit, "paint", Vector3(sx * hood_hw - 0.02, deck + 0.04, hz0), Vector3(sx * hood_hw + 0.02, deck + 0.2, hz1), DARK)
	# The radiator grille on the hood's front, framed, with bars; number boards and twin headlights over it.
	var fz := hz0 - 0.02
	pk.block(kit, "steel", Vector3(-0.85, 1.6, fz - 0.03), Vector3(0.85, 3.0, fz), DARK)
	var gy := 1.7
	while gy < 2.95:
		pk.block(kit, "steel", Vector3(-0.8, gy, fz - 0.06), Vector3(0.8, gy + 0.04, fz - 0.03), IRON.lightened(0.15))
		gy += 0.11
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 0.62 - 0.22, 3.12, fz - 0.03), Vector3(sx * 0.62 + 0.22, 3.36, fz), DARK)
		pk.block(kit, "lamp", Vector3(sx * 0.62 - 0.18, 3.15, fz - 0.05), Vector3(sx * 0.62 + 0.18, 3.33, fz - 0.03), RAIL_WHITE)
	for sx in [-0.2, 0.2]:
		pk.tube(kit, "steel", Vector3(sx, 3.25, fz), Vector3(sx, 3.25, fz - 0.12), 0.13, 0.13, 12, DARK)
		pk.tube(kit, "lamp", Vector3(sx, 3.25, fz - 0.12), Vector3(sx, 3.25, fz - 0.14), 0.1, 0.1, 12, LAMP)
	# On top: two radiator fans, the exhaust stack, an air intake, sand fillers, lifting eyes.
	for z2 in [-7.6, -6.2]:
		pk.tube(kit, "steel", Vector3(0, hood_top - 0.02, z2), Vector3(0, hood_top + 0.1, z2), 0.55, 0.55, 18, DARK)
		pk.tube(kit, "steel", Vector3(0, hood_top + 0.1, z2), Vector3(0, hood_top + 0.12, z2), 0.5, 0.5, 18, IRON.lightened(0.2), false)
		for k in 4:
			var ang: float = PI * 0.25 * float(k)
			var d2 := Vector3(cos(ang), 0, sin(ang)) * 0.48
			pk.beam(kit, "steel", Vector3(z2 * 0.0, hood_top + 0.13, z2) - d2, Vector3(0, hood_top + 0.13, z2) + d2, 0.04, 0.02, DARK)
	pk.tube(kit, "steel", Vector3(0.0, hood_top, -2.2), Vector3(0.0, hood_top + 0.55, -2.2), 0.17, 0.15, 10, DARK)
	pk.block(kit, "paint", Vector3(-0.55, hood_top - 0.02, 0.4), Vector3(0.55, hood_top + 0.28, 1.8), SAFETY_YELLOW.darkened(0.08))
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 0.45 - 0.2, hood_top + 0.18, 0.55), Vector3(sx * 0.45 + 0.2, hood_top + 0.3, 1.65), DARK)
		pk.tube(kit, "steel", Vector3(sx * 0.7, hood_top - 0.1, -8.6), Vector3(sx * 0.7, hood_top + 0.08, -8.6), 0.1, 0.1, 8, DARK)
	# --- The cab: full width, a crowned black roof with drip rails, windows all round, a door at the back.
	var cz0 := 3.4
	var cz1 := 8.9
	var cab_hw := 1.5
	var cab_top := 4.55
	pk.extrude(kit, "paint", _round_top(cab_hw, deck, cab_top, 0.18), cz0, cz1, 0.04, SAFETY_YELLOW)
	pk.extrude(kit, "steel", _round_top(cab_hw + 0.06, cab_top - 0.02, cab_top + 0.12, 0.1, 0.1), cz0 - 0.1, cz1 + 0.1, 0.03, DARK)
	# Front windows over the hood, side sliders, rear windows either side of the door; dark rubber frames.
	for sx in [-1.0, 1.0]:
		var wx0: float = sx * 0.3
		var wx1: float = sx * 1.3
		pk.block(kit, "steel", Vector3(minf(wx0, wx1) - 0.05, 3.62, cz0 - 0.03), Vector3(maxf(wx0, wx1) + 0.05, 4.4, cz0), DARK)
		pk.block(kit, "glass", Vector3(minf(wx0, wx1), 3.67, cz0 - 0.05), Vector3(maxf(wx0, wx1), 4.35, cz0 - 0.03), GLASS)
		var sxf: float = sx * (cab_hw + 0.0)
		for wz in [[4.0, 5.6], [5.9, 7.4]]:
			pk.block(kit, "steel", Vector3(sxf - 0.03, 3.05, float(wz[0]) - 0.05), Vector3(sxf + 0.03, 4.25, float(wz[1]) + 0.05), DARK)
			pk.block(kit, "glass", Vector3(sxf - 0.05, 3.1, float(wz[0])), Vector3(sxf + 0.05, 4.2, float(wz[1])), GLASS)
		pk.block(kit, "steel", Vector3(sxf - 0.04, 3.62, 5.69), Vector3(sxf + 0.04, 3.68, 7.41), DARK)
		# A visor over the side windows, the grab irons up the cab's corner.
		pk.block(kit, "steel", Vector3(minf(sxf, sxf + sx * 0.22), 4.3, 3.9), Vector3(maxf(sxf, sxf + sx * 0.22), 4.34, 7.5), DARK)
		pk.block(kit, "steel", Vector3(sxf + sx * 0.05 - 0.02, 1.6, 8.75), Vector3(sxf + sx * 0.05 + 0.02, 3.6, 8.79), RAIL_WHITE)
		pk.block(kit, "steel", Vector3(sx * 0.95 - 0.35, 3.3, cz1), Vector3(sx * 0.95 + 0.35, 4.15, cz1 + 0.03), DARK)
		pk.block(kit, "glass", Vector3(sx * 0.95 - 0.3, 3.35, cz1 + 0.03), Vector3(sx * 0.95 + 0.3, 4.1, cz1 + 0.05), GLASS)
	pk.block(kit, "paint", Vector3(-0.38, 1.5, cz1), Vector3(0.38, 3.95, cz1 + 0.03), SAFETY_YELLOW.darkened(0.15))
	pk.block(kit, "glass", Vector3(-0.25, 3.0, cz1 + 0.03), Vector3(0.25, 3.75, cz1 + 0.05), GLASS)
	pk.block(kit, "steel", Vector3(0.22, 2.4, cz1 + 0.03), Vector3(0.3, 2.5, cz1 + 0.09), RAIL_WHITE)
	# A black band round the cab at the window sills, the builder's plate.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * cab_hw - 0.015, 2.85, cz0), Vector3(sx * cab_hw + 0.015, 2.95, cz1), DARK)
		pk.block(kit, "steel", Vector3(sx * cab_hw - 0.02, 2.2, 4.3), Vector3(sx * cab_hw + 0.02, 2.5, 4.8), Color(0.75, 0.6, 0.25))
	# Rear headlights and number boards; markers and ditch lights at both ends.
	for sx in [-0.25, 0.25]:
		pk.tube(kit, "steel", Vector3(sx, 4.25, cz1), Vector3(sx, 4.25, cz1 + 0.12), 0.11, 0.11, 12, DARK)
		pk.tube(kit, "lamp", Vector3(sx, 4.25, cz1 + 0.12), Vector3(sx, 4.25, cz1 + 0.14), 0.08, 0.08, 12, LAMP)
	for sz in [-1.0, 1.0]:
		var ez: float = sz * (hl + 0.27)
		for sx in [-1.0, 1.0]:
			pk.block(kit, "lamp", Vector3(sx * 1.15 - 0.12, 1.12, ez), Vector3(sx * 1.15 + 0.12, 1.3, ez + sz * 0.05), LAMP)
	# The roof: an amber beacon, the horns, the bell and an antenna.
	pk.tube(kit, "steel", Vector3(0.0, cab_top + 0.2, 6.2), Vector3(0.0, cab_top + 0.28, 6.2), 0.14, 0.14, 10, DARK)
	pk.tube(kit, "lamp", Vector3(0.0, cab_top + 0.28, 6.2), Vector3(0.0, cab_top + 0.5, 6.2), 0.11, 0.09, 10, Color(1.0, 0.55, 0.05))
	for k in 3:
		var hx: float = -0.7 + 0.18 * float(k)
		pk.tube(kit, "steel", Vector3(hx, cab_top + 0.25, 4.6), Vector3(hx, cab_top + 0.25, 4.6 - 0.35 - 0.1 * float(k)), 0.03, 0.08, 8, IRON.lightened(0.3))
	pk.tube(kit, "steel", Vector3(0.75, cab_top + 0.2, 7.6), Vector3(0.75, cab_top + 0.9, 7.6), 0.012, 0.012, 4, DARK)
	pk.lathe(kit, "steel", Vector3(-0.9, hood_top, 2.6), [Vector2(0.0, 0.0), Vector2(0.12, 0.02), Vector2(0.14, 0.22), Vector2(0.09, 0.3), Vector2(0.0, 0.32)], 10, Color(0.75, 0.6, 0.25))
	# --- Handrails: stanchions along both walkways and across the ends (open in the middle for the steps), white.
	for sx in [-1.0, 1.0]:
		var rx: float = sx * 1.56
		for z3 in [-9.3, -7.3, -5.3, -3.3, -1.3, 0.7, 2.7]:
			pk.block(kit, "steel", Vector3(rx - 0.025, deck, z3 - 0.025), Vector3(rx + 0.025, deck + 1.1, z3 + 0.025), RAIL_WHITE)
		for ry in [deck + 0.55, deck + 1.08]:
			pk.tube(kit, "steel", Vector3(rx, ry, -9.3), Vector3(rx, ry, 3.4), 0.025, 0.025, 6, RAIL_WHITE, false)
			pk.tube(kit, "steel", Vector3(rx, ry, -9.3), Vector3(sx * 0.45, ry, -9.3), 0.025, 0.025, 6, RAIL_WHITE, false)
		pk.block(kit, "steel", Vector3(sx * 0.45 - 0.025, deck, -9.325), Vector3(sx * 0.45 + 0.025, deck + 1.1, -9.275), RAIL_WHITE)
		for ry2 in [deck + 0.55, deck + 1.08]:
			pk.tube(kit, "steel", Vector3(rx, ry2, 9.3), Vector3(sx * 0.5, ry2, 9.3), 0.025, 0.025, 6, RAIL_WHITE, false)
		pk.block(kit, "steel", Vector3(rx - 0.025, deck, 9.275), Vector3(rx + 0.025, deck + 1.1, 9.325), RAIL_WHITE)
		pk.block(kit, "steel", Vector3(sx * 0.5 - 0.025, deck, 9.275), Vector3(sx * 0.5 + 0.025, deck + 1.1, 9.325), RAIL_WHITE)


## A pilot under the end sill at `sz` (-1 the front): a plate in `col` and the sill's edge above it, striped at 45 degrees
## in `stripe` (painted on, 2.5cm proud, clipped to each plate), hoses and the cut lever.
static func _pilot(pk: PropKit, kit: Dictionary, hl: float, sz: float, col: Color, stripe: Color) -> void:
	var zf: float = sz * (hl + 0.24)
	pk.block(kit, "paint", Vector3(-1.45, 0.42, sz * (hl + 0.02)), Vector3(1.45, 0.95, zf), col)
	pk.block(kit, "paint", Vector3(-1.42, 1.0, zf), Vector3(1.42, 1.42, zf + sz * 0.02), col)
	for band in [[0.42, 0.95, zf + sz * 0.025], [1.0, 1.42, zf + sz * 0.045]]:
		var y0: float = band[0]
		var y1: float = band[1]
		var pz: float = band[2]
		var x := -1.4 - (y1 - y0)
		while x < 1.4:
			var xs := [x, x + 0.22, x + 0.22 + (y1 - y0), x + (y1 - y0)]
			var pts: Array = []
			for k in 4:
				pts.append(Vector3(clampf(float(xs[k]), -1.38, 1.38), y0 if k < 2 else y1, pz))
			if (pts[1] as Vector3).x - (pts[0] as Vector3).x > 0.01 or (pts[2] as Vector3).x - (pts[3] as Vector3).x > 0.01:
				pk.quad(kit, "paint", pts, Vector3(0, 0, sz), stripe)
			x += 0.5
	for hx in [-0.6, 0.6]:
		pk.tube(kit, "steel", Vector3(hx, 0.9, zf), Vector3(hx, 0.45, zf + sz * 0.25), 0.04, 0.04, 6, DARK)
	pk.beam(kit, "steel", Vector3(-1.3, 1.25, zf + sz * 0.08), Vector3(0.0, 1.25, zf + sz * 0.08), 0.04, 0.04, RAIL_WHITE)


## Hood doors down one side of a hood from z0 to z1 (face at |x| = fx): seams and handles, louvres on the first
## `louvres` doors from z0's end.
static func _hood_doors(pk: PropKit, kit: Dictionary, fx: float, sx: float, z0: float, z1: float, col: Color, louvres: int, pitch := 1.45) -> void:
	var z := z0 + 0.4
	var door := 0
	while z < z1 - 0.5:
		pk.block(kit, "paint", Vector3(fx - 0.012, 1.6, z - 0.015), Vector3(fx + 0.012, 3.1, z + 0.015), col.darkened(0.35))
		pk.block(kit, "steel", Vector3(fx + sx * 0.02 - 0.02, 2.3, z + 0.55), Vector3(fx + sx * 0.02 + 0.02, 2.36, z + 0.75), RAIL_WHITE)
		if door < louvres:
			var y := 2.45
			while y < 3.0:
				pk.block(kit, "paint", Vector3(fx - 0.02, y, z + 0.2), Vector3(fx + 0.02, y + 0.05, z + pitch - 0.25), DARK)
				y += 0.12
		z += pitch
		door += 1


## The road diesel (the freights' locomotives): a six-axle hood unit in maroon with a gold band. A short hood with a
## rounded top and gold chevrons on its nose ahead of the cab, a windscreen of two panes over it; the cab under a
## crowned black roof with horns and a bell; the long hood with panelled, louvred doors, a raised dynamic-brake
## housing with its grilles and fan, twin exhausts, and the radiator section at the back with mesh grilles down both
## sides and three fans on top; walkways round the hoods with white handrails, steps at the corners, pilots striped in
## gold, a plough under the front one, twin headlights and ditch lights at both ends, the fuel tank and air tanks
## underneath. `variant` 1 has a black roof over the long hood's radiators (a later batch). Life size, 19m.
static func _road_diesel(pk: PropKit, kit: Dictionary, variant: int) -> void:
	var hl := 9.5
	var deck := 1.38
	var body := MAROON
	var gold := GOLD
	_underframe(pk, kit, hl, 0.95, deck, DARK)
	_bogie(pk, kit, -6.2, [-1.8, 0.0, 1.8])
	_bogie(pk, kit, 6.2, [-1.8, 0.0, 1.8])
	# Underneath: the fuel tank (rounded, a gold stripe and a gauge) and the air tanks.
	pk.extrude(kit, "steel", _round_top(1.2, 0.35, 0.95, 0.24, 0.0, 3), -3.8, 3.2, 0.06, DARK)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * 1.2 - 0.015, 0.7, -3.7), Vector3(sx * 1.2 + 0.015, 0.78, 3.1), gold)
		pk.tube(kit, "steel", Vector3(sx * 1.05, 0.78, 3.4), Vector3(sx * 1.05, 0.78, 4.6), 0.2, 0.2, 10, IRON)
	pk.block(kit, "steel", Vector3(1.21, 0.5, -0.4), Vector3(1.25, 0.66, 0.2), RAIL_WHITE)
	# Pilots, striped gold on maroon; a plough under the front one.
	_pilot(pk, kit, hl, -1.0, body, gold)
	_pilot(pk, kit, hl, 1.0, body, gold)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", Vector3(sx * 1.45, 0.25, -hl - 0.3), Vector3(0.0, 0.25, -hl - 0.95), 0.36, 0.06, DARK, Vector3.UP)
	# Walkways and the corner steps (gold edges).
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(1.12 if sx > 0.0 else -1.58, deck, -hl), Vector3(1.58 if sx > 0.0 else -1.12, deck + 0.04, hl), IRON.lightened(0.08))
		pk.block(kit, "paint", Vector3(sx * 1.46 - 0.02, 1.1, -hl), Vector3(sx * 1.46 + 0.02, 1.3, hl), gold)
		for sz in [-1.0, 1.0]:
			var z0: float = minf(sz * (hl - 0.05), sz * (hl - 0.75))
			var z1: float = maxf(sz * (hl - 0.05), sz * (hl - 0.75))
			for k in 2:
				var ty: float = 0.5 + 0.42 * float(k)
				pk.block(kit, "steel", Vector3(1.2 if sx > 0.0 else -1.62, ty, z0), Vector3(1.62 if sx > 0.0 else -1.2, ty + 0.05, z1), IRON)
				pk.block(kit, "paint", Vector3(1.58 if sx > 0.0 else -1.63, ty + 0.05, z0), Vector3(1.63 if sx > 0.0 else -1.58, ty + 0.08, z1), gold)
			pk.block(kit, "steel", Vector3(1.58 if sx > 0.0 else -1.62, 0.45, z0 - 0.03), Vector3(1.62 if sx > 0.0 else -1.58, deck, z0), DARK)
			pk.block(kit, "steel", Vector3(1.58 if sx > 0.0 else -1.62, 0.45, z1), Vector3(1.62 if sx > 0.0 else -1.58, deck, z1 + 0.03), DARK)
	# --- The short hood (the nose): rounded, gold chevrons on its face, the headlights and number boards at its top.
	var sh_z0 := -9.0
	var sh_z1 := -5.4
	var sh_top := 3.25
	pk.extrude(kit, "paint", _round_top(1.1, deck, sh_top, 0.3), sh_z0, sh_z1, 0.05, body)
	var nz := sh_z0 - 0.025
	for k in 3:
		var yb: float = 1.55 + 0.42 * float(k)
		for sx in [-1.0, 1.0]:
			pk.quad(kit, "paint", [Vector3(0.0, yb, nz), Vector3(sx * 1.02, yb + 0.55, nz), Vector3(sx * 1.02, yb + 0.75, nz), Vector3(0.0, yb + 0.2, nz)], Vector3(0, 0, -1), gold)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 0.68 - 0.24, 2.92, nz - 0.02), Vector3(sx * 0.68 + 0.24, 3.12, nz), DARK)
		pk.block(kit, "lamp", Vector3(sx * 0.68 - 0.2, 2.95, nz - 0.04), Vector3(sx * 0.68 + 0.2, 3.09, nz - 0.02), RAIL_WHITE)
		pk.tube(kit, "steel", Vector3(sx * 0.2, 2.95, nz), Vector3(sx * 0.2, 2.95, nz - 0.12), 0.13, 0.13, 12, DARK)
		pk.tube(kit, "lamp", Vector3(sx * 0.2, 2.95, nz - 0.12), Vector3(sx * 0.2, 2.95, nz - 0.14), 0.1, 0.1, 12, LAMP)
		# Ditch lights on the pilot's corners, and the nose's grab irons.
		pk.block(kit, "lamp", Vector3(sx * 1.2 - 0.13, 1.5, -hl - 0.3), Vector3(sx * 1.2 + 0.13, 1.72, -hl - 0.26), LAMP)
		pk.block(kit, "steel", Vector3(sx * 0.55 - 0.18, 2.55, nz - 0.08), Vector3(sx * 0.55 + 0.18, 2.58, nz - 0.05), RAIL_WHITE)
	# The nose door on the right, a bell on the hood.
	pk.block(kit, "paint", Vector3(1.11, 1.55, -8.4), Vector3(1.13, 3.0, -7.4), body.darkened(0.25))
	pk.lathe(kit, "steel", Vector3(0.0, sh_top - 0.02, -6.4), [Vector2(0.0, 0.0), Vector2(0.12, 0.02), Vector2(0.14, 0.22), Vector2(0.09, 0.3), Vector2(0.0, 0.32)], 10, gold.darkened(0.1))
	# --- The cab: full width, a windscreen of two panes over the nose, side windows, a black roof with horns.
	var cz0 := -5.4
	var cz1 := -1.7
	var cab_top := 4.5
	pk.extrude(kit, "paint", _round_top(1.5, deck, cab_top, 0.2), cz0, cz1, 0.04, body)
	pk.extrude(kit, "steel", _round_top(1.56, cab_top - 0.02, cab_top + 0.12, 0.1, 0.1), cz0 - 0.1, cz1 + 0.1, 0.03, DARK)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(minf(sx * 0.12, sx * 1.32), 3.4, cz0 - 0.03), Vector3(maxf(sx * 0.12, sx * 1.32), 4.3, cz0), DARK)
		pk.block(kit, "glass", Vector3(minf(sx * 0.17, sx * 1.27), 3.45, cz0 - 0.05), Vector3(maxf(sx * 0.17, sx * 1.27), 4.25, cz0 - 0.03), GLASS)
		var fx: float = sx * 1.5
		for wz in [[-5.1, -4.0], [-3.8, -2.2]]:
			pk.block(kit, "steel", Vector3(fx - 0.03, 3.1, float(wz[0]) - 0.05), Vector3(fx + 0.03, 4.2, float(wz[1]) + 0.05), DARK)
			pk.block(kit, "glass", Vector3(fx - 0.05, 3.15, float(wz[0])), Vector3(fx + 0.05, 4.15, float(wz[1])), GLASS)
		pk.block(kit, "steel", Vector3(minf(fx, fx + sx * 0.2), 4.27, -5.2), Vector3(maxf(fx, fx + sx * 0.2), 4.31, -2.1), DARK)
		# The gold band along the cab's sides, the number under the windows.
		pk.block(kit, "paint", Vector3(fx - 0.015, 1.65, cz0), Vector3(fx + 0.015, 1.95, cz1), gold)
		pk.block(kit, "paint", Vector3(fx - 0.02, 2.45, -3.6), Vector3(fx + 0.02, 2.85, -2.6), gold)
	for k in 3:
		var hx: float = 0.3 + 0.18 * float(k)
		pk.tube(kit, "steel", Vector3(hx, cab_top + 0.25, -3.0), Vector3(hx, cab_top + 0.25, -3.0 + 0.35 + 0.1 * float(k)), 0.03, 0.08, 8, IRON.lightened(0.3))
	pk.tube(kit, "steel", Vector3(-0.8, cab_top + 0.2, -2.4), Vector3(-0.8, cab_top + 0.9, -2.4), 0.012, 0.012, 4, DARK)
	pk.block(kit, "steel", Vector3(-0.3, cab_top + 0.12, -4.2), Vector3(0.3, cab_top + 0.3, -3.4), DARK)
	# --- The long hood: rounded, doors with louvres behind the cab, the dynamic brake housing, the radiator section.
	var lh_z0 := -1.7
	var lh_z1 := 9.1
	var lh_top := 3.5
	pk.extrude(kit, "paint", _round_top(1.12, deck, lh_top, 0.32), lh_z0, lh_z1, 0.05, body)
	for sx in [-1.0, 1.0]:
		var fx2: float = sx * 1.132
		_hood_doors(pk, kit, fx2, sx, lh_z0, 5.6, body, 2)
		pk.block(kit, "paint", Vector3(fx2 - 0.015, 1.65, lh_z0), Vector3(fx2 + 0.015, 1.95, lh_z1), gold)
		# The radiator grilles: dark mesh panels in frames down both sides of the back.
		pk.block(kit, "steel", Vector3(fx2 - 0.02, 2.2, 5.9), Vector3(fx2 + 0.02, 3.3, 8.8), DARK)
		var gz := 6.0
		while gz < 8.75:
			pk.block(kit, "steel", Vector3(fx2 + sx * 0.02 - 0.015, 2.25, gz), Vector3(fx2 + sx * 0.02 + 0.015, 3.25, gz + 0.04), IRON.lightened(0.18))
			gz += 0.16
	# The dynamic brake housing: raised, wider, with a grille strip each side and a fan.
	pk.extrude(kit, "paint", _round_top(1.18, lh_top - 0.6, lh_top + 0.32, 0.25), -0.9, 2.1, 0.04, body)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(sx * 1.18 - 0.02, 3.15, -0.7), Vector3(sx * 1.18 + 0.02, 3.6, 1.9), DARK)
	pk.tube(kit, "steel", Vector3(0, lh_top + 0.3, 0.6), Vector3(0, lh_top + 0.38, 0.6), 0.5, 0.5, 18, DARK)
	# Twin exhausts, then the radiator fans (on a black roof on variant 1).
	for z2 in [3.0, 3.8]:
		pk.tube(kit, "steel", Vector3(0, lh_top - 0.05, z2), Vector3(0, lh_top + 0.35, z2), 0.16, 0.14, 10, DARK)
	if variant == 1:
		pk.extrude(kit, "steel", _round_top(1.0, lh_top - 0.02, lh_top + 0.04, 0.2), 6.0, 9.0, 0.02, DARK)
	for z3 in [6.5, 7.5, 8.5]:
		pk.tube(kit, "steel", Vector3(0, lh_top - 0.02, z3), Vector3(0, lh_top + 0.1, z3), 0.45, 0.45, 16, DARK)
		pk.tube(kit, "steel", Vector3(0, lh_top + 0.1, z3), Vector3(0, lh_top + 0.12, z3), 0.41, 0.41, 16, IRON.lightened(0.2), false)
		for k in 4:
			var ang: float = PI * 0.25 * float(k)
			var d2 := Vector3(cos(ang), 0, sin(ang)) * 0.4
			pk.beam(kit, "steel", Vector3(0, lh_top + 0.13, z3) - d2, Vector3(0, lh_top + 0.13, z3) + d2, 0.04, 0.02, DARK)
	# The long hood's end: twin headlights, number boards, gold chevrons, ditch lights on the rear pilot.
	var ez := lh_z1 + 0.025
	for k in 3:
		var yb2: float = 1.55 + 0.42 * float(k)
		for sx in [-1.0, 1.0]:
			pk.quad(kit, "paint", [Vector3(0.0, yb2, ez), Vector3(0.0, yb2 + 0.2, ez), Vector3(sx * 1.02, yb2 + 0.75, ez), Vector3(sx * 1.02, yb2 + 0.55, ez)], Vector3(0, 0, 1), gold)
	for sx in [-1.0, 1.0]:
		pk.tube(kit, "steel", Vector3(sx * 0.2, 3.15, ez), Vector3(sx * 0.2, 3.15, ez + 0.12), 0.12, 0.12, 12, DARK)
		pk.tube(kit, "lamp", Vector3(sx * 0.2, 3.15, ez + 0.12), Vector3(sx * 0.2, 3.15, ez + 0.14), 0.09, 0.09, 12, LAMP)
		pk.block(kit, "lamp", Vector3(sx * 1.2 - 0.13, 1.5, hl + 0.26), Vector3(sx * 1.2 + 0.13, 1.72, hl + 0.3), Color(0.9, 0.12, 0.08))
	# --- Handrails along both walkways and across the ends (open in the middle), white.
	for sx in [-1.0, 1.0]:
		var rx: float = sx * 1.56
		for z4 in [-9.3, -7.4, -5.5, -1.6, 0.6, 2.8, 5.0, 7.2, 9.3]:
			pk.block(kit, "steel", Vector3(rx - 0.025, deck, z4 - 0.025), Vector3(rx + 0.025, deck + 1.1, z4 + 0.025), RAIL_WHITE)
		for ry in [deck + 0.55, deck + 1.08]:
			pk.tube(kit, "steel", Vector3(rx, ry, -9.3), Vector3(rx, ry, -5.5), 0.025, 0.025, 6, RAIL_WHITE, false)
			pk.tube(kit, "steel", Vector3(rx, ry, -1.6), Vector3(rx, ry, 9.3), 0.025, 0.025, 6, RAIL_WHITE, false)
			for zz in [-9.3, 9.3]:
				pk.tube(kit, "steel", Vector3(rx, ry, zz), Vector3(sx * 0.45, ry, zz), 0.025, 0.025, 6, RAIL_WHITE, false)
		for zz2 in [-9.3, 9.3]:
			pk.block(kit, "steel", Vector3(sx * 0.45 - 0.025, deck, zz2 - 0.025), Vector3(sx * 0.45 + 0.025, deck + 1.1, zz2 + 0.025), RAIL_WHITE)
