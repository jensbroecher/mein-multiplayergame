extends RefCounted
## Freight Line's rolling stock, built through a PropKit at life size and grown by SCALE (like the
## camps and the matatus): a diesel locomotive, a boxcar, a flatcar (empty, or carrying pipes), a
## tank car and a caboose. Every car is modelled along z with its nose toward -z, on y = 0 at the top of
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
	"flat_load": {"len": 16.0, "width": 3.0, "height": 2.9},
	"caboose": {"len": 10.0, "width": 3.0, "height": 5.0},
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
			_loco(pk, kit)
		"box":
			_box_car(pk, kit, variant, rng)
		"tank":
			_tank_car(pk, kit, variant)
		"flat":
			_flat_car(pk, kit, false, rng)
		"flat_load":
			_flat_car(pk, kit, true, rng)
		"caboose":
			_caboose(pk, kit)
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
	# Stake pockets with stakes along both edges.
	z = -hl + 0.8
	while z < hl - 0.6:
		for sx in [-1.0, 1.0]:
			pk.block(kit, "steel", Vector3(sx * 1.5 - 0.07, 1.3, z - 0.07), Vector3(sx * 1.5 + 0.07, 1.45, z + 0.07), IRON)
		z += 2.4
	for sz in [-1.0, 1.0]:
		pk.block(kit, "steel", Vector3(-0.05, 1.3, sz * (hl - 0.1)), Vector3(0.05, 1.9, sz * (hl - 0.05)), IRON)
	if not loaded:
		return
	# Concrete pipes in two bunks, three layers of 4, 3 and 2, chained down.
	var pipe := Color(0.62, 0.61, 0.58)
	for bz in [-4.4, 4.4]:
		pk.block(kit, "wood", Vector3(-1.3, 1.3, bz - 0.9), Vector3(1.3, 1.45, bz + 0.9), WOOD.darkened(0.2))
		for layer in 3:
			var n := 4 - layer
			for k in n:
				var px: float = (k - (n - 1) * 0.5) * 0.72
				var py: float = 1.45 + 0.34 + layer * 0.62
				pk.tube(kit, "rust", Vector3(px, py, bz - 1.9), Vector3(px, py, bz + 1.9), 0.34, 0.34, 14, _jit(pipe, rng), true)
		for sx in [-1.0, 1.0]:
			pk.block(kit, "steel", Vector3(sx * 1.38 - 0.03, 1.4, bz - 0.04), Vector3(sx * 1.38 + 0.03, 2.9, bz + 0.04), IRON)


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


static func _loco(pk: PropKit, kit: Dictionary) -> void:
	var hl := 9.5
	_underframe(pk, kit, hl, 0.95, 1.38, IRON)
	_bogie(pk, kit, -6.2, [-1.8, 0.0, 1.8])
	_bogie(pk, kit, 6.2, [-1.8, 0.0, 1.8])
	pk.block(kit, "steel", Vector3(-1.2, 0.55, -2.0), Vector3(1.2, 1.0, 2.0), IRON)   # fuel tank
	# Short hood (the nose), cab and long hood.
	pk.block(kit, "paint", Vector3(-1.4, 1.38, -9.0), Vector3(1.4, 3.1, -5.2), MAROON)
	pk.block(kit, "paint", Vector3(-1.3, 3.1, -8.8), Vector3(1.3, 3.35, -5.2), MAROON.darkened(0.15))
	pk.block(kit, "paint", Vector3(-1.55, 1.38, -5.2), Vector3(1.55, 4.3, -1.6), MAROON)
	pk.block(kit, "paint", Vector3(-1.68, 4.3, -5.45), Vector3(1.68, 4.46, -1.35), MAROON.darkened(0.3))
	pk.block(kit, "paint", Vector3(-1.45, 1.38, -1.6), Vector3(1.45, 3.55, 9.2), MAROON)
	pk.block(kit, "paint", Vector3(-1.2, 3.55, -1.4), Vector3(1.2, 3.8, 5.6), MAROON.darkened(0.15))
	pk.block(kit, "paint", Vector3(-1.3, 3.55, 5.6), Vector3(1.3, 4.35, 9.2), MAROON.darkened(0.2))
	# The gold livery: a band along the hood and cab sides, a chevron stripe on the nose.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * 1.46 - 0.04, 1.75, -9.0), Vector3(sx * 1.46 + 0.04, 2.05, 9.2), GOLD)
		pk.block(kit, "paint", Vector3(sx * 1.56 - 0.04, 1.75, -5.2), Vector3(sx * 1.56 + 0.04, 2.05, -1.6), GOLD)
	pk.block(kit, "paint", Vector3(-1.41, 1.75, -9.05), Vector3(1.41, 2.05, -8.95), GOLD)
	pk.block(kit, "paint", Vector3(-1.2, 3.35 - 0.02, -8.85), Vector3(1.2, 3.35 + 0.02, -8.0), GOLD)
	# The cab's windows (front, sides) and its door.
	for sx in [-1.0, 1.0]:
		pk.block(kit, "glass", Vector3(sx * 0.65 - 0.5, 3.0, -5.24), Vector3(sx * 0.65 + 0.5, 4.05, -5.2), GLASS)
		pk.block(kit, "glass", Vector3(sx * 1.55 - 0.03, 3.0, -4.6), Vector3(sx * 1.55 + 0.03, 4.05, -2.8), GLASS)
		pk.block(kit, "paint", Vector3(sx * 1.56 - 0.03, 1.5, -3.3), Vector3(sx * 1.56 + 0.03, 2.9, -2.3), MAROON.darkened(0.2))
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
