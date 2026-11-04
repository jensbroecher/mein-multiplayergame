extends RefCounted
## Mina del Viento's set pieces (regenerate_mina.gd), built through a PropKit at life size in their own frames and
## grown by the caller: the haul trucks, the rope shovel, the radio telescopes, the hot air balloons, the
## conveyors and the plant's buildings, and the small things round them.
##
## Every builder lays its prop out with y up and its front toward -z (as PropKit's other kits do), on the ground at
## y = 0. Vehicles are drawn along +x in a turned frame (`_vehicle_frame`): x forward, z to the right, which keeps their
## side profiles readable as outlines.
##
## Material keys: CampKit's vertex-colour ones ("paint" glossy painted steel, "steel", "matte", "rubber", "metal",
## "glassdark", "lamp", "canvas", "wood") and "tyre" (mina_tyre.gdshader), "rubble" (mina_rubble.gdshader),
## "envelope" (mina_balloon.gdshader), "flame" (mina_flame.gdshader).

const PropKit = preload("res://PropKit.gd")
const CampKit = preload("res://CampKit.gd")

static var _mats := {}

## The pit's dust, caked onto everything low on a vehicle.
const DUST := Color(0.66, 0.50, 0.40)
const MINE_YELLOW := Color(0.95, 0.70, 0.09)
const FRAME_BLACK := Color(0.10, 0.10, 0.10)
const RIM_GREY := Color(0.80, 0.78, 0.72)
const GLASS := Color(0.10, 0.14, 0.17)
const STEEL_GREY := Color(0.36, 0.37, 0.38)


static func make_material(key: String) -> Material:
	match key:
		"paint":
			var m := CampKit.make_material("gloss")
			m.roughness = 0.42
			m.metallic = 0.12
			return m
		"glassdark":
			var g := CampKit.make_material("plastic")
			g.roughness = 0.08
			g.metallic = 0.5
			return g
		"tyre":
			var t := ShaderMaterial.new()
			t.shader = load("res://mina_tyre.gdshader")
			return t
		"rubble":
			var r := ShaderMaterial.new()
			r.shader = load("res://mina_rubble.gdshader")
			r.set_shader_parameter("pebble_tex", load("res://materials/dark_canyon_rock.png"))
			r.set_shader_parameter("pebble_normal", load("res://materials/dark_canyon_rock_normal.png"))
			return r
		"envelope":
			var e := ShaderMaterial.new()
			e.shader = load("res://mina_balloon.gdshader")
			return e
		"flame":
			var f := ShaderMaterial.new()
			f.shader = load("res://mina_flame.gdshader")
			return f
	return CampKit.make_material(key)


## A kit growing everything by `scale`, its materials shared with every other kit made here.
static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	return pk


## The materials made so far, by key (the generator saves them so every mesh shares one per key).
static func materials() -> Dictionary:
	return _mats


## Turns the kit so the builder can work with x forward and z to the right (the prop's front is still -z).
static func _vehicle_frame(pk: PropKit) -> Transform3D:
	var base: Transform3D = pk.xf
	pk.set_frame(base * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO))
	return base


## `col` with the pit's dust caked on it, thickest at the ground and gone by `top` metres up.
static func dusty(col: Color, y: float, top := 3.2, amount := 0.55) -> Color:
	return col.lerp(DUST, amount * (1.0 - smoothstep(0.0, top, y)))


# ======================================================================================
#  Haul truck
# ======================================================================================

## A 400-tonne-class mining dump truck at life size, about 15m long, 9.6m wide and 7.6m to its canopy (an original
## design on the usual layout: the operator's cab on the left of an upper deck over the radiator, a diagonal stair
## across the grille, a canopy of the dump body over them, duals at the rear). `load` heaps ore in the body;
## `body_col` paints it. Its front is -z.
static func haul_truck(pk: PropKit, kit: Dictionary, body_col := MINE_YELLOW, load := false, seed_v := 0.3, tank := false) -> void:
	var base: Transform3D = _vehicle_frame(pk)
	var y_c := body_col
	# --- Wheels: 4m tyres, a single at each front corner, duals at the rear --------------------------------------
	var r_out := 2.0
	var r_in := 1.0
	var tw := 1.45
	var axle_f := 3.4
	var axle_r := -3.8
	var tip := Basis(Vector3.RIGHT, PI * 0.5)
	for wz in [-3.75, 3.75]:
		_wheel(pk, kit, Vector3(axle_f, r_out, wz), r_in, r_out, tw, tip, wz > 0.0, seed_v)
	for wz in [-4.05, -2.5, 2.5, 4.05]:
		_wheel(pk, kit, Vector3(axle_r, r_out, wz), r_in, r_out, tw, tip, wz > 0.0, seed_v + 0.4)
	# --- Frame, axles and suspension -------------------------------------------------------------------------
	for sz in [-1.15, 1.15]:
		pk.block(kit, "steel", Vector3(-5.6, 1.45, sz - 0.32), Vector3(6.7, 2.75, sz + 0.32), dusty(FRAME_BLACK, 1.5))
	pk.block(kit, "steel", Vector3(-5.5, 1.7, -1.5), Vector3(-4.9, 2.4, 1.5), dusty(FRAME_BLACK, 1.5))
	pk.block(kit, "steel", Vector3(5.6, 1.7, -1.5), Vector3(6.1, 2.4, 1.5), dusty(FRAME_BLACK, 1.5))
	pk.tube(kit, "steel", Vector3(axle_r, r_out, -1.65), Vector3(axle_r, r_out, 1.65), 0.82, 0.82, 16, dusty(Color(0.16, 0.16, 0.15), 1.0))
	for sz in [-1.0, 1.0]:
		pk.tube(kit, "steel", Vector3(axle_r, r_out, sz * 1.65), Vector3(axle_r, r_out, sz * 1.95), 0.95, 0.7, 16, dusty(FRAME_BLACK, 1.0))
		# Front struts down to the steering knuckles, and the rear struts from the axle housing.
		pk.tube(kit, "paint", Vector3(axle_f, r_out + 0.2, sz * 2.75), Vector3(axle_f + 0.15, 4.35, sz * 2.55), 0.32, 0.32, 10, dusty(Color(0.62, 0.62, 0.60), 2.0))
		pk.tube(kit, "metal", Vector3(axle_f, r_out - 0.1, sz * 2.8), Vector3(axle_f, r_out + 0.6, sz * 2.8), 0.42, 0.42, 10, dusty(Color(0.20, 0.20, 0.20), 1.5))
		pk.tube(kit, "paint", Vector3(axle_r + 0.3, r_out + 0.55, sz * 1.25), Vector3(axle_r + 0.9, 3.2, sz * 1.05), 0.28, 0.28, 10, dusty(Color(0.62, 0.62, 0.60), 2.0))
		# The hoist cylinders, from the frame forward of the rear axle up to the body.
		pk.tube(kit, "metal", Vector3(-0.6, 2.0, sz * 1.55), Vector3(0.3, 3.9, sz * 1.55), 0.3, 0.3, 10, Color(0.70, 0.70, 0.68))
		pk.tube(kit, "paint", Vector3(-0.85, 1.7, sz * 1.55), Vector3(-0.55, 2.1, sz * 1.55), 0.38, 0.38, 10, dusty(y_c, 2.0))
	# --- Front: the radiator, its grille, the bumper, the lamps ------------------------------------------------
	pk.block(kit, "paint", Vector3(4.7, 2.0, -1.95), Vector3(6.95, 4.55, 1.95), dusty(y_c, 2.6, 4.5, 0.4))
	pk.block(kit, "matte", Vector3(6.95, 2.25, -1.7), Vector3(7.02, 4.35, 1.7), Color(0.07, 0.07, 0.07))
	for k in range(9):
		var gy: float = 2.4 + float(k) * 0.22
		pk.block(kit, "steel", Vector3(7.0, gy, -1.68), Vector3(7.08, gy + 0.06, 1.68), Color(0.22, 0.22, 0.22))
	pk.block(kit, "paint", Vector3(6.85, 1.15, -3.25), Vector3(7.5, 2.3, 3.25), dusty(y_c, 1.2, 3.5, 0.55))
	for lz in [-2.7, -2.15, 2.15, 2.7]:
		pk.block(kit, "lamp", Vector3(7.5, 1.85, lz - 0.2), Vector3(7.56, 2.12, lz + 0.2), Color(1.0, 0.97, 0.88))
	# --- Upper deck over the radiator, its railings, the cab on the left, air cleaners on the right -------------
	pk.block(kit, "steel", Vector3(3.97, 4.55, -4.75), Vector3(7.25, 4.8, 4.75), dusty(Color(0.30, 0.30, 0.30), 4.0, 5.0, 0.3))
	for dz in [-4.4, -2.0, 2.0, 4.4]:
		pk.beam(kit, "paint", Vector3(4.0, 2.6, dz * 0.62), Vector3(4.2, 4.55, dz), 0.3, 0.3, dusty(y_c, 3.0))
		pk.beam(kit, "paint", Vector3(6.6, 2.4, dz * 0.45), Vector3(6.9, 4.55, dz), 0.25, 0.25, dusty(y_c, 3.0))
	_railing(pk, kit, [Vector3(7.15, 4.8, -4.7), Vector3(7.15, 4.8, 4.7)], 1.1, y_c)
	_railing(pk, kit, [Vector3(7.15, 4.8, 4.7), Vector3(3.7, 4.8, 4.7)], 1.1, y_c)
	_railing(pk, kit, [Vector3(4.6, 4.8, -4.7), Vector3(7.15, 4.8, -4.7)], 1.1, y_c)
	# Cab.
	var cab_lo := Vector3(4.1, 4.8, -4.45)
	var cab_hi := Vector3(6.7, 7.0, -2.05)
	pk.block(kit, "paint", cab_lo, cab_hi, y_c)
	pk.block(kit, "paint", Vector3(4.0, 6.95, -4.55), Vector3(6.85, 7.12, -1.95), y_c.darkened(0.08))
	pk.block(kit, "glassdark", Vector3(6.7, 5.55, -4.25), Vector3(6.74, 6.8, -2.25), GLASS)
	pk.block(kit, "glassdark", Vector3(4.4, 5.55, -4.49), Vector3(6.5, 6.8, -4.45), GLASS)
	pk.block(kit, "glassdark", Vector3(4.4, 5.55, -2.05), Vector3(6.5, 6.8, -2.01), GLASS)
	pk.block(kit, "matte", Vector3(4.2, 4.82, -4.5), Vector3(6.66, 5.0, -2.0), Color(0.12, 0.12, 0.12))
	for mz in [-4.85, 4.85]:
		pk.beam(kit, "steel", Vector3(7.1, 5.9, mz * 0.97), Vector3(7.5, 6.3, mz * 1.03), 0.08, 0.08, FRAME_BLACK)
		pk.block(kit, "matte", Vector3(7.4, 6.2, mz * 1.03 - 0.25), Vector3(7.55, 6.95, mz * 1.03 + 0.25), FRAME_BLACK)
	for az in [2.6, 3.9]:
		pk.tube(kit, "paint", Vector3(4.3, 5.35, az), Vector3(6.4, 5.35, az), 0.48, 0.48, 14, y_c)
		pk.tube(kit, "matte", Vector3(6.4, 5.35, az), Vector3(6.55, 5.35, az), 0.5, 0.5, 14, Color(0.15, 0.15, 0.15))
	# The stair: from the bumper's left end up across the grille to the deck's right, and a ladder to the bumper.
	_stair(pk, kit, Vector3(7.62, 2.3, -2.9), Vector3(7.62, 4.8, 2.0), y_c)
	for k in range(4):
		var ly: float = 0.5 + float(k) * 0.42
		pk.beam(kit, "steel", Vector3(7.6, ly, -3.5), Vector3(7.6, ly, -2.9), 0.06, 0.06, FRAME_BLACK)
	pk.beam(kit, "steel", Vector3(7.6, 0.4, -3.5), Vector3(7.6, 2.3, -3.5), 0.06, 0.06, FRAME_BLACK)
	pk.beam(kit, "steel", Vector3(7.6, 0.4, -2.9), Vector3(7.6, 2.3, -2.9), 0.06, 0.06, FRAME_BLACK)
	if tank:
		_water_tank(pk, kit, y_c)
		pk.set_frame(base)
		return
	# --- The dump body: sides, floor rising to the tail, the front wall and the canopy over the deck ---------------
	var side_out := PackedVector2Array([
		Vector2(3.75, 4.25), Vector2(-4.6, 4.1), Vector2(-7.55, 5.15), Vector2(-7.6, 5.7), Vector2(-4.2, 7.1),
		Vector2(2.6, 7.1), Vector2(3.75, 7.75),
	])
	for sz in [-1.0, 1.0]:
		var z0: float = 4.35 if sz > 0.0 else -4.8
		var z1: float = 4.8 if sz > 0.0 else -4.35
		pk.extrude(kit, "paint", side_out, z0, z1, 0.06, y_c, func(c: Vector3, _n: Vector3) -> Color: return dusty(y_c, c.y, 5.0, 0.35))
		# Ribs down the outside and the rail along the top.
		for rx in [-6.0, -3.4, -1.0, 1.4]:
			var top_y: float = 7.05 if rx > -4.2 else lerpf(5.7, 7.05, (rx + 7.6) / 3.4)
			pk.block(kit, "paint", Vector3(rx - 0.18, 4.2, sz * 4.8 - 0.12 if sz > 0.0 else -4.92), Vector3(rx + 0.18, top_y, sz * 4.92 if sz > 0.0 else -4.68), dusty(y_c, 3.3, 5.0, 0.4))
		pk.tube(kit, "paint", Vector3(-4.2, 7.12, sz * 4.6), Vector3(2.6, 7.12, sz * 4.6), 0.2, 0.2, 10, y_c)
		pk.tube(kit, "paint", Vector3(-7.58, 5.7, sz * 4.6), Vector3(-4.2, 7.12, sz * 4.6), 0.2, 0.2, 10, y_c)
	# Floor: the flat part and the tail's rise, a slab under them, and the worn inside.
	var inner := y_c.darkened(0.35).lerp(DUST, 0.45)
	pk.quad(kit, "paint", [Vector3(3.6, 4.35, -4.35), Vector3(3.6, 4.35, 4.35), Vector3(-4.6, 4.2, 4.35), Vector3(-4.6, 4.2, -4.35)], Vector3.UP, inner)
	pk.quad(kit, "paint", [Vector3(-4.6, 4.2, -4.35), Vector3(-4.6, 4.2, 4.35), Vector3(-7.55, 5.25, 4.35), Vector3(-7.55, 5.25, -4.35)], Vector3(0.35, 1, 0).normalized(), inner)
	pk.quad(kit, "paint", [Vector3(3.6, 4.1, -4.4), Vector3(-4.6, 3.95, -4.4), Vector3(-4.6, 3.95, 4.4), Vector3(3.6, 4.1, 4.4)], Vector3.DOWN, dusty(FRAME_BLACK, 2.0))
	pk.quad(kit, "paint", [Vector3(-4.6, 3.95, -4.4), Vector3(-7.55, 5.0, -4.4), Vector3(-7.55, 5.0, 4.4), Vector3(-4.6, 3.95, 4.4)], Vector3(-0.35, -1, 0).normalized(), dusty(FRAME_BLACK, 2.0))
	# Under-body beams, and the body's pivot on the frame's tail.
	for bz in [-3.0, -1.2, 1.2, 3.0]:
		pk.block(kit, "steel", Vector3(-6.0, 3.7, bz - 0.15), Vector3(3.5, 4.1, bz + 0.15), dusty(FRAME_BLACK, 2.5))
	for bz in [-1.15, 1.15]:
		pk.block(kit, "steel", Vector3(-5.55, 2.6, bz - 0.25), Vector3(-4.9, 3.95, bz + 0.25), dusty(FRAME_BLACK, 2.5))
	pk.block(kit, "paint", Vector3(3.6, 4.1, -4.8), Vector3(3.95, 7.85, 4.8), y_c)
	pk.block(kit, "paint", Vector3(3.97, 7.75, -4.85), Vector3(7.35, 8.1, 4.85), y_c)
	# The worn lining of the front wall, a few centimetres proud of it (flush, the two flickered).
	pk.block(kit, "paint", Vector3(3.55, 4.35, -4.33), Vector3(3.58, 7.7, 4.33), inner)
	pk.beam(kit, "paint", Vector3(7.3, 7.75, -4.7), Vector3(3.9, 5.6, -4.7), 0.3, 0.3, y_c)
	pk.beam(kit, "paint", Vector3(7.3, 7.75, 4.7), Vector3(3.9, 5.6, 4.7), 0.3, 0.3, y_c)
	# A beacon on the canopy and the rear lamps.
	pk.tube(kit, "lamp", Vector3(5.5, 8.1, 4.2), Vector3(5.5, 8.4, 4.2), 0.16, 0.13, 8, Color(1.0, 0.55, 0.1))
	for tz in [-1.5, 1.5]:
		pk.block(kit, "lamp", Vector3(-5.66, 2.0, tz - 0.22), Vector3(-5.6, 2.25, tz + 0.22), Color(0.9, 0.12, 0.08))
	if load:
		_ore_heap(pk, kit, Vector3(-1.3, 4.25, 0.0), Vector2(4.6, 3.9), 2.6, seed_v)
	pk.set_frame(base)


## One tyre and its rim: the rim's dished face and its bolt circle on the outside (`right`: the +z side).
static func _wheel(pk: PropKit, kit: Dictionary, c: Vector3, r_in: float, r_out: float, w: float, tip: Basis, right: bool, seed_v: float) -> void:
	pk.painted_tyre(kit, "tyre", c, r_in, r_out, w, Color(0, 0, 0), seed_v, tip)
	var out := 1.0 if right else -1.0
	var rim := dusty(RIM_GREY, c.y - r_in * 0.7, 3.0, 0.4)
	# The rim's barrel inside the tyre and its dished face, with the hub standing out of it.
	pk.tube(kit, "paint", c + Vector3(0, 0, -w * 0.48), c + Vector3(0, 0, w * 0.48), r_in, r_in, 20, rim.darkened(0.25), false)
	pk.lathe(kit, "paint", c + Vector3(0, 0, out * w * 0.3), [Vector2(r_in, 0.0), Vector2(r_in * 0.82, 0.12), Vector2(0.62, 0.22), Vector2(0.0, 0.25)], 20, rim, false, Basis(Vector3.RIGHT, PI * 0.5 * out))
	pk.tube(kit, "steel", c + Vector3(0, 0, out * w * 0.45), c + Vector3(0, 0, out * w * 0.62), 0.5, 0.42, 14, Color(0.2, 0.2, 0.2))
	for k in range(12):
		var a: float = TAU * float(k) / 12.0
		var bp: Vector3 = c + Vector3(cos(a) * 0.82, sin(a) * 0.82, out * w * 0.53)
		pk.tube(kit, "steel", bp, bp + Vector3(0, 0, out * 0.08), 0.06, 0.06, 6, Color(0.25, 0.25, 0.25))


## A handrail along `pts` (a polyline on the floor it guards): posts every 1.5m, a top rail and a knee rail.
static func _railing(pk: PropKit, kit: Dictionary, pts: Array, h: float, col: Color) -> void:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n: int = maxi(int(ceil(a.distance_to(b) / 1.5)), 1)
		for k in range(n + 1):
			var p: Vector3 = a.lerp(b, float(k) / float(n))
			pk.beam(kit, "paint", p, p + Vector3.UP * h, 0.06, 0.06, col)
		pk.beam(kit, "paint", a + Vector3.UP * h, b + Vector3.UP * h, 0.07, 0.07, col)
		pk.beam(kit, "paint", a + Vector3.UP * h * 0.5, b + Vector3.UP * h * 0.5, 0.05, 0.05, col)


## A steel stair from `a` (its foot) to `b` (its head), treads across it and a handrail each side.
static func _stair(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, col: Color) -> void:
	var along: Vector3 = (b - a)
	var across := Vector3(1, 0, 0)
	var steps: int = int(ceil((b.y - a.y) / 0.25))
	for side in [-0.42, 0.42]:
		pk.beam(kit, "steel", a + across * side, b + across * side, 0.06, 0.25, FRAME_BLACK, across)
		pk.beam(kit, "paint", a + across * side + Vector3.UP * 1.0, b + across * side + Vector3.UP * 1.0, 0.06, 0.06, col)
		for k in range(0, 4):
			var p: Vector3 = (a + along * (float(k) / 3.0)) + across * side
			pk.beam(kit, "paint", p, p + Vector3.UP * 1.0, 0.05, 0.05, col)
	for k in range(steps + 1):
		var p2: Vector3 = a + along * (float(k) / float(steps))
		pk.box(kit, "steel", Transform3D(Basis(), p2), Vector3(0.84, 0.05, 0.3), Color(0.3, 0.3, 0.3))


## A heap of broken ore filling an area (centre on the floor it lies on, half sizes in x and z, height).
static func _ore_heap(pk: PropKit, kit: Dictionary, c: Vector3, half: Vector2, h: float, seed_v: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_v * 1000.0) + 17
	var nx := 10
	var nz := 8
	var grid: Array = []
	for i in range(nx + 1):
		var row: Array = []
		for j in range(nz + 1):
			var u: float = float(i) / float(nx) * 2.0 - 1.0
			var v: float = float(j) / float(nz) * 2.0 - 1.0
			var dome: float = maxf(1.0 - pow(absf(u), 2.4) - pow(absf(v), 2.4), 0.0)
			var y: float = h * pow(dome, 0.6) + (rng.randf_range(-0.12, 0.12) if dome > 0.05 else 0.0)
			row.append(c + Vector3(u * half.x, y, v * half.y))
		grid.append(row)
	for i in range(nx):
		for j in range(nz):
			var p00: Vector3 = grid[i][j]
			var p10: Vector3 = grid[i + 1][j]
			var p11: Vector3 = grid[i + 1][j + 1]
			var p01: Vector3 = grid[i][j + 1]
			var col := Color(0.72, 0.52, 0.40).darkened(rng.randf_range(0.0, 0.15))
			var n: Vector3 = (p11 - p00).cross(p10 - p01).normalized()
			if n.y < 0.0:
				n = -n
			pk.quad(kit, "rubble", [p00, p10, p11, p01], n, col)


# ======================================================================================
#  Electric rope shovel
# ======================================================================================

## One crawler track at x `sx`, `length` long, its shoes `hw` either side of its middle, `out` (+1/-1) toward its outer
## side: a chain of shoes round the drive sprocket (rear, +z) and the idler (front, -z), each shoe a plate with a grouser
## across its outside and a drive lug inside; the side frame between the runs with its stiffeners, lower and carrier
## rollers, the sprocket's and the idler's hubs and the propel gearbox behind the sprocket.
static func _crawler(pk: PropKit, kit: Dictionary, sx: float, length: float, hw: float, out: float) -> void:
	var r_path := 1.42
	var yc := 1.45
	var zf: float = -length * 0.5 + 1.6
	var zr: float = length * 0.5 - 1.6
	var run: float = zr - zf
	var perim: float = 2.0 * run + TAU * r_path
	var n: int = int(round(perim / 0.62))
	var shoe := Color(0.24, 0.23, 0.22)
	for k in range(n):
		var u: float = perim * float(k) / float(n)
		var p: Vector3
		var t: Vector3
		if u < run:
			p = Vector3(sx, yc - r_path, zf + u)
			t = Vector3(0, 0, 1)
		elif u < run + PI * r_path:
			var a1: float = (u - run) / r_path
			p = Vector3(sx, yc - cos(a1) * r_path, zr + sin(a1) * r_path)
			t = Vector3(0, sin(a1), cos(a1))
		elif u < 2.0 * run + PI * r_path:
			p = Vector3(sx, yc + r_path, zr - (u - run - PI * r_path))
			t = Vector3(0, 0, -1)
		else:
			var a2: float = (u - 2.0 * run - PI * r_path) / r_path
			p = Vector3(sx, yc + cos(a2) * r_path, zf - sin(a2) * r_path)
			t = Vector3(0, -sin(a2), -cos(a2))
		var nrm: Vector3 = Vector3.RIGHT.cross(t).normalized() * -1.0
		if nrm.dot(p - Vector3(sx, yc, clampf(p.z, zf, zr))) < 0.0:
			nrm = -nrm
		var b := Basis(Vector3.RIGHT, nrm, t)
		var col: Color = dusty(shoe, p.y, 3.0, 0.65).darkened(0.05 * float(k % 3))
		pk.box(kit, "steel", Transform3D(b, p), Vector3(hw * 2.0, 0.3, 0.56), col)
		pk.box(kit, "steel", Transform3D(b, p + nrm * 0.2), Vector3(hw * 2.0 - 0.1, 0.12, 0.13), col.darkened(0.12))
		pk.box(kit, "steel", Transform3D(b, p - nrm * 0.22), Vector3(0.7, 0.16, 0.34), col.darkened(0.2))
	# The side frame inside the chain, sloping in at its ends, ribs down its outer face.
	var fw := 1.15
	var frame_col: Color = dusty(Color(0.18, 0.18, 0.17), 1.0, 3.0, 0.5)
	# (The outline is drawn along z, so it is extruded in a frame turned to put the kit's x along z.)
	var bf: Transform3D = pk.xf
	pk.set_frame(bf * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(sx, 0.0, 0.0)))
	pk.extrude(kit, "steel", PackedVector2Array([Vector2(zf - 0.4, 0.82), Vector2(zr + 0.4, 0.82), Vector2(zr - 0.2, 2.35), Vector2(zf + 0.2, 2.35)]),
			-fw, fw, 0.05, frame_col)
	pk.set_frame(bf)
	for k in range(9):
		var zz: float = lerpf(zf + 0.6, zr - 0.6, float(k) / 8.0)
		pk.block(kit, "steel", Vector3(sx + out * fw - 0.08, 0.82, zz - 0.09), Vector3(sx + out * fw + 0.08, 2.35, zz + 0.09), frame_col.lightened(0.05))
	# The rollers run on the shoes' plates (the bottom run's top at yc - r_path + 0.15), in pairs either side of the
	# drive lugs down the middle, as a real crawler's flanged rollers straddle them: the lower ones under the frame
	# (which they hold up, on brackets down from its foot), the carriers on posts over it under the top run.
	var roll_col := Color(0.34, 0.33, 0.31)
	var plate_lo: float = yc - r_path + 0.15
	var plate_hi: float = yc + r_path - 0.15
	var rr := 0.3
	for k in range(7):
		var zz2: float = lerpf(zf + 0.9, zr - 0.9, float(k) / 6.0)
		var ry: float = plate_lo + rr
		for side in [-1.0, 1.0]:
			pk.tube(kit, "metal", Vector3(sx + side * 0.42, ry, zz2), Vector3(sx + side * 1.0, ry, zz2), rr, rr, 14, roll_col)
			# The flanges.
			for fx in [0.44, 0.98]:
				pk.tube(kit, "metal", Vector3(sx + side * (fx - 0.02), ry, zz2), Vector3(sx + side * (fx + 0.02), ry, zz2), rr + 0.05, rr + 0.05, 14, roll_col.darkened(0.15))
			# A bracket from the frame's foot down to the axle, outboard of the roller.
			pk.block(kit, "steel", Vector3(sx + side * 1.0 - 0.07, ry - 0.08, zz2 - 0.16), Vector3(sx + side * 1.0 + 0.07, 0.86, zz2 + 0.16), frame_col)
		pk.tube(kit, "steel", Vector3(sx - 1.08, ry, zz2), Vector3(sx + 1.08, ry, zz2), 0.09, 0.09, 8, Color(0.22, 0.22, 0.22))
	var cr := 0.2
	for zz3 in [lerpf(zf, zr, 0.33), lerpf(zf, zr, 0.67)]:
		var cy: float = plate_hi - cr
		for side in [-1.0, 1.0]:
			pk.tube(kit, "metal", Vector3(sx + side * 0.42, cy, zz3), Vector3(sx + side * 1.0, cy, zz3), cr, cr, 12, roll_col)
			pk.block(kit, "steel", Vector3(sx + side * 1.04 - 0.06, 2.3, zz3 - 0.12), Vector3(sx + side * 1.04 + 0.06, cy + 0.06, zz3 + 0.12), frame_col)
		pk.tube(kit, "steel", Vector3(sx - 1.1, cy, zz3), Vector3(sx + 1.1, cy, zz3), 0.07, 0.07, 8, Color(0.22, 0.22, 0.22))
	# The sprocket (with its teeth showing past the chain's edge) and the idler, their hubs on the outside.
	for wz in [zf, zr]:
		var drive: bool = wz == zr
		pk.tube(kit, "steel", Vector3(sx - hw + 0.2, yc, wz), Vector3(sx + hw - 0.2, yc, wz), 1.2, 1.2, 20, Color(0.2, 0.2, 0.2))
		pk.tube(kit, "metal", Vector3(sx + out * (hw - 0.2), yc, wz), Vector3(sx + out * (hw + 0.15), yc, wz), 0.75, 0.6, 16, Color(0.36, 0.35, 0.33))
		for kb in range(8):
			var ab: float = TAU * float(kb) / 8.0
			var bp := Vector3(sx + out * (hw + 0.16), yc + sin(ab) * 0.48, wz + cos(ab) * 0.48)
			pk.tube(kit, "steel", bp, bp + Vector3(out * 0.08, 0, 0), 0.06, 0.06, 6, Color(0.2, 0.2, 0.2))
		if drive:
			for kt in range(13):
				var at: float = TAU * float(kt) / 13.0
				var tp := Vector3(sx + out * (hw - 0.1), yc + sin(at) * 1.22, wz + cos(at) * 1.22)
				pk.box(kit, "metal", Transform3D(Basis(Vector3.RIGHT, -at), tp), Vector3(0.18, 0.2, 0.24), Color(0.4, 0.38, 0.35))
			# The propel gearbox and motor behind the sprocket.
			pk.block(kit, "paint", Vector3(sx + out * 0.3 - 0.6, 1.6, zr + 0.6), Vector3(sx + out * 0.3 + 0.6, 2.8, zr + 2.1), Color(0.9, 0.88, 0.84).darkened(0.1))
			pk.tube(kit, "paint", Vector3(sx + out * 0.3, 2.2, zr + 2.1), Vector3(sx + out * 0.3, 2.2, zr + 2.7), 0.45, 0.45, 12, Color(0.62, 0.12, 0.10))


## A mining rope shovel at life size: crawlers, the revolving house with its cab, gantry and counterweight, the
## boom raised forward with its point sheaves, the dipper handle through the saddle block and the dipper on it,
## hanging from the hoist ropes. The house is turned `swing` radians about the centre pin (0: boom toward -z, the
## crawlers stay put); the dipper is `reach` (0..1) out along the handle and `raise` metres up from its low point.
static func rope_shovel(pk: PropKit, kit: Dictionary, swing := 0.0, reach := 0.6, raise := 6.0) -> void:
	var base: Transform3D = pk.xf
	var white := Color(0.90, 0.88, 0.84)
	var red := Color(0.62, 0.12, 0.10)
	var dark := Color(0.16, 0.16, 0.16)
	# --- Crawlers: two tracks of shoes round a sprocket and an idler, the car body between them -----------------
	for sx in [-4.8, 4.8]:
		_crawler(pk, kit, sx, 13.5, 1.7, -1.0 if sx < 0.0 else 1.0)
	pk.block(kit, "steel", Vector3(-3.3, 1.2, -3.2), Vector3(3.3, 3.4, 3.2), dusty(dark, 1.5, 3.4, 0.5))
	for cz in [-2.4, 2.4]:
		pk.block(kit, "steel", Vector3(-3.6, 1.5, cz - 0.7), Vector3(3.6, 2.7, cz + 0.7), dusty(dark.lightened(0.04), 1.5, 3.0, 0.5))
	pk.tube(kit, "steel", Vector3(0, 3.4, 0), Vector3(0, 4.0, 0), 4.6, 4.6, 32, dark)
	# The swing rack: teeth round the roller circle.
	for k in range(48):
		var ta: float = TAU * float(k) / 48.0
		pk.box(kit, "metal", Transform3D(Basis(Vector3.UP, -ta), Vector3(cos(ta) * 4.66, 3.55, sin(ta) * 4.66)), Vector3(0.14, 0.3, 0.22), Color(0.38, 0.37, 0.35))
	# --- The revolving frame and house, turned by `swing` ------------------------------------------------------
	pk.set_frame(base * Transform3D(Basis(Vector3.UP, swing), Vector3.ZERO))
	pk.block(kit, "steel", Vector3(-5.6, 4.0, -6.5), Vector3(5.6, 4.8, 7.6), Color(0.25, 0.25, 0.25))
	# The house: machinery under a pitched roof, a red band round it, louvres, its door and ladder.
	pk.block(kit, "paint", Vector3(-5.2, 4.8, -2.4), Vector3(5.2, 11.2, 7.2), white)
	pk.block(kit, "paint", Vector3(-5.25, 9.4, -2.45), Vector3(5.25, 10.0, 7.25), red)
	pk.extrude(kit, "paint", PackedVector2Array([Vector2(-5.3, 11.2), Vector2(5.3, 11.2), Vector2(0.0, 12.4)]), -2.5, 7.3, 0.04, white.darkened(0.06))
	for lz in [0.0, 1.5, 3.0, 4.5]:
		pk.block(kit, "matte", Vector3(5.2, 6.4, lz), Vector3(5.24, 8.6, lz + 1.1), Color(0.3, 0.3, 0.3))
		pk.block(kit, "matte", Vector3(-5.24, 6.4, lz), Vector3(-5.2, 8.6, lz + 1.1), Color(0.3, 0.3, 0.3))
	# Counterweight hanging off the back.
	pk.block(kit, "paint", Vector3(-5.0, 4.4, 7.2), Vector3(5.0, 9.0, 8.8), dark.lightened(0.05))
	# Cab at the front left, its windows looking down at the dipper.
	pk.block(kit, "paint", Vector3(-5.2, 6.8, -5.0), Vector3(-2.2, 10.2, -2.4), white)
	pk.block(kit, "glassdark", Vector3(-5.0, 8.0, -5.04), Vector3(-2.4, 9.9, -5.0), GLASS)
	pk.block(kit, "glassdark", Vector3(-5.24, 8.0, -4.8), Vector3(-5.2, 9.9, -2.6), GLASS)
	pk.block(kit, "steel", Vector3(-5.4, 6.6, -5.4), Vector3(-2.0, 6.8, -2.2), Color(0.3, 0.3, 0.3))
	_railing(pk, kit, [Vector3(-5.4, 4.8, 7.6), Vector3(-5.4, 4.8, -2.3)], 1.1, Color(0.92, 0.75, 0.15))
	_railing(pk, kit, [Vector3(5.4, 4.8, -2.3), Vector3(5.4, 4.8, 7.6)], 1.1, Color(0.92, 0.75, 0.15))
	# Ribs down the house's sides, a door, cabinets and lamps on the roof, the boarding stair.
	for rz in range(-2, 8):
		for sd in [-1.0, 1.0]:
			pk.block(kit, "paint", Vector3(sd * 5.2 - 0.06, 4.8, float(rz) - 0.06), Vector3(sd * 5.2 + 0.06, 9.4, float(rz) + 0.06), white.darkened(0.1))
	pk.block(kit, "paint", Vector3(-5.27, 4.85, 5.0), Vector3(-5.22, 7.1, 6.1), white.darkened(0.25))
	pk.block(kit, "steel", Vector3(-5.29, 5.9, 5.85), Vector3(-5.27, 6.05, 5.95), Color(0.2, 0.2, 0.2))
	for cab in [Vector3(-3.4, 11.2, 4.6), Vector3(3.2, 11.2, 5.2)]:
		pk.block(kit, "paint", cab - Vector3(1.0, 0.0, 0.8), cab + Vector3(1.0, 1.5, 0.8), Color(0.72, 0.72, 0.70))
	for lx in [-4.2, -1.4, 1.4, 4.2]:
		pk.box(kit, "steel", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(lx, 10.6, -2.6)), Vector3(0.5, 0.4, 0.3), Color(0.2, 0.2, 0.2))
		pk.box(kit, "lamp", Transform3D(Basis(Vector3.RIGHT, -0.3), Vector3(lx, 10.55, -2.77)), Vector3(0.42, 0.32, 0.04), Color(1.0, 0.97, 0.9))
	_stair(pk, kit, Vector3(-6.4, 1.1, 6.6), Vector3(-6.4, 4.8, 3.0), Color(0.92, 0.75, 0.15))
	pk.block(kit, "steel", Vector3(-6.9, 4.7, 1.6), Vector3(-5.6, 4.8, 3.2), Color(0.3, 0.3, 0.3))
	# The gantry on the roof: an A-frame whose back legs hold the boom's suspension ropes.
	var g_top := Vector3(0.0, 21.0, 2.6)
	for gx in [-3.2, 3.2]:
		pk.beam(kit, "paint", Vector3(gx, 11.6, -0.8), g_top + Vector3(gx * 0.55, 0.0, 0.0), 0.7, 0.7, red)
		pk.beam(kit, "paint", Vector3(gx, 11.6, 6.4), g_top + Vector3(gx * 0.55, 0.0, 0.0), 0.6, 0.6, red)
	pk.beam(kit, "paint", g_top + Vector3(-1.8, 0, 0), g_top + Vector3(1.8, 0, 0), 0.8, 0.8, red)
	# --- The boom: from its foot at the front of the frame, 45 degrees up to the point sheaves ------------------
	var foot := Vector3(0.0, 5.6, -6.2)
	var boom_dir := Vector3(0.0, sin(deg_to_rad(45.0)), -cos(deg_to_rad(45.0)))
	var boom_len := 22.0
	var tip: Vector3 = foot + boom_dir * boom_len
	for bx in [-1.1, 1.1]:
		pk.beam(kit, "paint", foot + Vector3(bx * 1.3, 0, 0), tip + Vector3(bx * 0.8, 0, 0), 1.0, 2.4, white, Vector3.RIGHT)
	for k in range(1, 8):
		var p: Vector3 = foot.lerp(tip, float(k) / 8.0)
		var hw: float = lerpf(1.3, 0.8, float(k) / 8.0) * 1.1
		pk.beam(kit, "paint", p + Vector3(-hw, 0, 0), p + Vector3(hw, 0, 0), 0.3, 0.6, white.darkened(0.08))
	pk.tube(kit, "paint", tip + Vector3(-1.4, 0, 0), tip + Vector3(1.4, 0, 0), 1.6, 1.6, 20, red)
	# Top and bottom plates closing the box girder, a walkway rail along its top, lamps under the point.
	pk.beam(kit, "paint", foot + Vector3(0, 1.15, 0), tip + Vector3(0, 1.15, 0), 2.2, 0.12, white.darkened(0.05), Vector3.RIGHT)
	pk.beam(kit, "paint", foot - Vector3(0, 1.15, 0), tip - Vector3(0, 1.15, 0), 2.2, 0.12, white.darkened(0.15), Vector3.RIGHT)
	var up_n: Vector3 = Vector3.RIGHT.cross(boom_dir).normalized() * -1.0
	for k in range(9):
		var rp: Vector3 = foot.lerp(tip, 0.08 + 0.84 * float(k) / 8.0) + Vector3(-1.1, 0, 0) + up_n * 1.25
		pk.beam(kit, "paint", rp, rp + Vector3.UP * 1.0, 0.06, 0.06, Color(0.92, 0.75, 0.15))
	var r0: Vector3 = foot.lerp(tip, 0.08) + Vector3(-1.1, 1.0, 0) + up_n * 1.25
	var r1: Vector3 = foot.lerp(tip, 0.92) + Vector3(-1.1, 1.0, 0) + up_n * 1.25
	pk.beam(kit, "paint", r0, r1, 0.07, 0.07, Color(0.92, 0.75, 0.15))
	for lx2 in [-0.9, 0.9]:
		pk.box(kit, "lamp", Transform3D(Basis(), tip + Vector3(lx2, -1.9, -0.6)), Vector3(0.5, 0.25, 0.5), Color(1.0, 0.97, 0.9))
	# Suspension ropes from the gantry to the boom's point.
	for bx in [-0.9, 0.9]:
		pk.beam(kit, "steel", g_top + Vector3(bx, 0, 0), tip + Vector3(bx, 1.2, 0.6), 0.12, 0.12, Color(0.18, 0.18, 0.18))
	# --- The handle through the saddle block halfway up the boom, and the dipper on it -------------------------
	var saddle: Vector3 = foot + boom_dir * 9.0 + Vector3(0, 0.8, -0.4)
	pk.block(kit, "paint", saddle - Vector3(1.6, 1.0, 1.0), saddle + Vector3(1.6, 1.0, 1.0), red)
	var hdl_dir := Vector3(0.0, -sin(deg_to_rad(18.0 + 25.0 * (1.0 - reach))), -cos(deg_to_rad(18.0 + 25.0 * (1.0 - reach))))
	var hdl_back: Vector3 = saddle - hdl_dir * 3.0
	var hdl_end: Vector3 = saddle + hdl_dir * lerpf(7.0, 13.0, reach) + Vector3(0, raise * 0.35, 0)
	for hx in [-0.7, 0.7]:
		pk.beam(kit, "paint", hdl_back + Vector3(hx, 0, 0), hdl_end + Vector3(hx, 0, 0), 0.55, 0.8, white.darkened(0.04), Vector3.RIGHT)
	# The dipper: an open-topped bucket, its teeth forward and down, the bail over it to the hoist ropes.
	var d0: Vector3 = hdl_end
	pk.set_frame(base * Transform3D(Basis(Vector3.UP, swing), Vector3.ZERO) * Transform3D(Basis(), d0))
	pk.block(kit, "steel", Vector3(-2.6, -3.6, -1.0), Vector3(2.6, 1.2, -0.7), dusty(Color(0.2, 0.2, 0.2), -2.0, 4.0, 0.3))
	pk.block(kit, "steel", Vector3(-2.6, -3.9, -4.6), Vector3(2.6, -3.5, -0.7), dusty(Color(0.2, 0.2, 0.2), -3.0, 2.0, 0.5))
	for sx in [-2.65, 2.35]:
		pk.block(kit, "steel", Vector3(sx, -3.9, -4.6), Vector3(sx + 0.3, 1.2, -0.7), Color(0.22, 0.22, 0.22))
	pk.block(kit, "steel", Vector3(-2.6, -0.4, -4.7), Vector3(2.6, 0.2, -4.3), Color(0.25, 0.25, 0.25))
	for k in range(6):
		var tx: float = -2.2 + float(k) * 0.88
		pk.beam(kit, "metal", Vector3(tx, -0.1, -4.6), Vector3(tx, 0.7, -5.4), 0.32, 0.22, Color(0.55, 0.53, 0.5))
	_ore_heap(pk, kit, Vector3(0.0, -3.4, -2.6), Vector2(2.3, 1.6), 2.2, 0.8)
	var bail := Vector3(0.0, 3.0, -2.6)
	pk.beam(kit, "paint", Vector3(-2.5, 1.0, -2.6), bail, 0.3, 0.3, red)
	pk.beam(kit, "paint", Vector3(2.5, 1.0, -2.6), bail, 0.3, 0.3, red)
	pk.set_frame(base * Transform3D(Basis(Vector3.UP, swing), Vector3.ZERO))
	var bail_w: Vector3 = d0 + Vector3(0.0, 3.0, -2.6)
	for rx in [-0.5, 0.5]:
		pk.beam(kit, "steel", tip + Vector3(rx, -1.2, -0.4), bail_w + Vector3(rx, 0, 0), 0.1, 0.1, Color(0.15, 0.15, 0.15))
	pk.set_frame(base)


## The haul truck converted to a water truck: a tank on the frame where the body was, spray bars at the back.
static func water_truck(pk: PropKit, kit: Dictionary) -> void:
	haul_truck(pk, kit, Color(0.92, 0.9, 0.86), false, 0.55, true)


static func _water_tank(pk: PropKit, kit: Dictionary, col: Color) -> void:
	var outline := PackedVector2Array([Vector2(3.4, 2.9), Vector2(-6.4, 2.9), Vector2(-6.8, 3.6), Vector2(-6.8, 6.2), Vector2(-6.4, 6.6),
			Vector2(3.0, 6.6), Vector2(3.4, 6.2)])
	pk.extrude(kit, "paint", outline, -3.3, 3.3, 0.5, col, func(c: Vector3, _n: Vector3) -> Color: return dusty(col, c.y, 5.0, 0.4))
	pk.block(kit, "paint", Vector3(-6.2, 4.1, -3.35), Vector3(3.2, 4.5, 3.35), Color(0.12, 0.38, 0.62))
	pk.tube(kit, "steel", Vector3(-6.9, 2.5, -2.6), Vector3(-6.9, 2.5, 2.6), 0.14, 0.14, 8, Color(0.3, 0.3, 0.3))
	for nz in [-2.2, -1.1, 0.0, 1.1, 2.2]:
		pk.tube(kit, "steel", Vector3(-6.9, 2.5, nz), Vector3(-7.1, 2.25, nz), 0.08, 0.06, 6, Color(0.3, 0.3, 0.3))
	pk.block(kit, "paint", Vector3(3.4, 2.9, -4.6), Vector3(3.7, 6.6, 4.6), col)
	pk.block(kit, "paint", Vector3(3.6, 6.4, -4.7), Vector3(7.3, 6.75, 4.7), col)
	_railing(pk, kit, [Vector3(-5.8, 6.6, -2.8), Vector3(2.6, 6.6, -2.8)], 1.0, MINE_YELLOW)


# ======================================================================================
#  Radio telescope
# ======================================================================================

## A radio telescope of the array at life size: a 25m dish on an alt-azimuth pedestal standing on a transporter
## pad, a quadrupod over the dish holding the subreflector, the feed cone in its middle. `az` turns the dish about the
## vertical (0: looking toward -z), `el` lifts it from the horizon (radians).
static func radio_dish(pk: PropKit, kit: Dictionary, az: float, el: float) -> void:
	var base: Transform3D = pk.xf
	var white := Color(0.93, 0.93, 0.92)
	var shade := Color(0.80, 0.80, 0.80)
	# The pad on its piers, the pedestal's splayed legs and the drum of the azimuth bearing.
	pk.block(kit, "matte", Vector3(-6.5, 0.0, -6.5), Vector3(6.5, 0.7, 6.5), Color(0.72, 0.70, 0.66))
	for p in [Vector3(-4.2, 0.7, -4.2), Vector3(4.2, 0.7, -4.2), Vector3(4.2, 0.7, 4.2), Vector3(-4.2, 0.7, 4.2)]:
		pk.beam(kit, "paint", p, Vector3(p.x * 0.4, 8.6, p.z * 0.4), 0.9, 0.9, white)
		pk.block(kit, "matte", p - Vector3(0.8, 0.0, 0.8), p + Vector3(0.8, 0.4, 0.8), Color(0.6, 0.6, 0.58))
	for y in [3.2, 6.0]:
		var f: float = (y - 0.7) / 7.9
		var hw: float = lerpf(4.2, 1.7, f)
		for e in [[Vector3(-1, 0, -1), Vector3(1, 0, -1)], [Vector3(1, 0, -1), Vector3(1, 0, 1)], [Vector3(1, 0, 1), Vector3(-1, 0, 1)], [Vector3(-1, 0, 1), Vector3(-1, 0, -1)]]:
			pk.beam(kit, "paint", e[0] * hw + Vector3(0, y, 0), e[1] * hw + Vector3(0, y, 0), 0.35, 0.35, shade)
	pk.tube(kit, "paint", Vector3(0, 8.4, 0), Vector3(0, 10.0, 0), 2.6, 2.6, 24, white)
	pk.tube(kit, "matte", Vector3(0, 9.0, 0), Vector3(0, 9.3, 0), 2.65, 2.65, 24, Color(0.3, 0.3, 0.3))
	# The yoke turns with the dish.
	pk.set_frame(base * Transform3D(Basis(Vector3.UP, az), Vector3.ZERO))
	var axis_y := 15.5
	pk.block(kit, "paint", Vector3(-4.4, 10.0, -2.2), Vector3(4.4, 11.4, 2.2), white)
	for yx in [-4.0, 4.0]:
		pk.extrude(kit, "paint", PackedVector2Array([Vector2(-2.0, 11.4), Vector2(2.0, 11.4), Vector2(1.0, axis_y + 1.0), Vector2(-1.0, axis_y + 1.0)]),
				yx - 0.45, yx + 0.45, 0.05, white)
		pk.tube(kit, "steel", Vector3(yx - 0.6, axis_y, 0), Vector3(yx + 0.6, axis_y, 0), 0.85, 0.85, 16, Color(0.25, 0.25, 0.25))
	pk.block(kit, "paint", Vector3(-1.4, 11.4, 1.0), Vector3(1.4, 13.6, 2.6), shade)
	# The dish, tilted up by `el` about the elevation axis: its vertex sits on the axis' line, looking along -z.
	var tilt := Basis(Vector3.RIGHT, el)
	var dish_xf := Transform3D(tilt * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, axis_y, -1.2))
	pk.set_frame(base * Transform3D(Basis(Vector3.UP, az), Vector3.ZERO) * dish_xf)
	# In the dish's own frame the boresight is +y and the vertex is at y = 0.
	var r_dish := 12.5
	var focal := 9.0
	var prof_in: Array = []
	var prof_out: Array = []
	for k in range(11):
		var r: float = r_dish * float(k) / 10.0
		var z: float = r * r / (4.0 * focal)
		prof_in.append(Vector2(r, z + 0.05))
		prof_out.append(Vector2(r, z - 0.12))
	prof_out.reverse()
	# Panels inside (lathe walks outward: its faces look up the boresight), the back facing away.
	_dish_surface(pk, kit, prof_in, 36, white, true, "matte")
	_dish_surface(pk, kit, prof_out, 36, shade, false, "matte")
	# The back structure: radial ribs and a hoop truss behind the panels, the hub where they meet.
	pk.tube(kit, "paint", Vector3(0, -2.6, 0), Vector3(0, 0.0, 0), 2.4, 1.6, 20, shade)
	for k in range(12):
		var a: float = TAU * float(k) / 12.0
		var d := Vector3(cos(a), 0.0, sin(a))
		var tip: Vector3 = d * r_dish + Vector3(0, r_dish * r_dish / (4.0 * focal) - 0.2, 0)
		pk.beam(kit, "paint", d * 1.8 + Vector3(0, -2.2, 0), tip, 0.28, 0.28, shade)
	var hoop_r := 8.0
	var hoop_y: float = hoop_r * hoop_r / (4.0 * focal) - 0.9
	for k in range(12):
		var a0: float = TAU * float(k) / 12.0
		var a1: float = TAU * float(k + 1) / 12.0
		pk.beam(kit, "paint", Vector3(cos(a0), 0, sin(a0)) * hoop_r + Vector3(0, hoop_y, 0), Vector3(cos(a1), 0, sin(a1)) * hoop_r + Vector3(0, hoop_y, 0), 0.22, 0.22, shade)
	# The feed cone in the middle and the quadrupod to the subreflector at the focus.
	pk.tube(kit, "paint", Vector3(0, 0.0, 0), Vector3(0, 4.2, 0), 1.3, 0.75, 16, white)
	pk.tube(kit, "matte", Vector3(0, 4.2, 0), Vector3(0, 4.3, 0), 0.75, 0.6, 16, Color(0.35, 0.35, 0.35))
	var focus := Vector3(0, focal - 0.6, 0)
	for k in range(4):
		var a2: float = TAU * (float(k) + 0.5) / 4.0
		var foot := Vector3(cos(a2), 0, sin(a2)) * 7.4
		foot.y = foot.length_squared() / (4.0 * focal) + 0.05
		pk.beam(kit, "paint", foot, focus, 0.32, 0.32, white)
	pk.lathe(kit, "paint", focus, [Vector2(0.0, -0.4), Vector2(1.4, -0.15), Vector2(1.5, 0.2), Vector2(0.0, 0.5)], 18, white)
	pk.set_frame(base)


## A surface of revolution like PropKit.lathe but wound to face up the axis (`up`) or down it, so the dish's panels
## and its back are both outward faces.
static func _dish_surface(pk: PropKit, kit: Dictionary, prof: Array, segs: int, col: Color, up: bool, key := "paint") -> void:
	for k in range(prof.size() - 1):
		var p0: Vector2 = prof[k]
		var p1: Vector2 = prof[k + 1]
		for j in range(segs):
			var t0: float = TAU * float(j) / float(segs)
			var t1: float = TAU * float(j + 1) / float(segs)
			var u0 := Vector3(cos(t0), 0.0, sin(t0))
			var u1 := Vector3(cos(t1), 0.0, sin(t1))
			var q00: Vector3 = u0 * p0.x + Vector3.UP * p0.y
			var q01: Vector3 = u1 * p0.x + Vector3.UP * p0.y
			var q10: Vector3 = u0 * p1.x + Vector3.UP * p1.y
			var q11: Vector3 = u1 * p1.x + Vector3.UP * p1.y
			# The paraboloid's normal at radius r: (-r/2f, 1) across, pointing up its axis.
			var n0: Vector3 = (Vector3.UP - u0 * (p0.x / 18.0)).normalized()
			var n1: Vector3 = (Vector3.UP - u1 * (p1.x / 18.0)).normalized()
			var nm: Vector3 = (n0 + n1).normalized()
			if not up:
				n0 = -n0
				n1 = -n1
				nm = -nm
			if p0.x > 1e-5 or p1.x > 1e-5:
				pk.tri(kit, key, q00, q01, q11, n0, n0, n1, col, nm)
				pk.tri(kit, key, q00, q11, q10, n0, n1, n1, col, nm)


# ======================================================================================
#  Hot air balloons
# ======================================================================================

## The envelope's outline from the mouth up (radius, height), life size: an inverted teardrop about 18m across and 22m
## tall.
const ENVELOPE := [
	[2.3, 0.0], [3.3, 1.6], [5.0, 3.9], [6.8, 6.6], [8.2, 9.4], [9.0, 12.0], [9.1, 14.0], [8.6, 16.2], [7.4, 18.3],
	[5.5, 20.1], [3.0, 21.4], [0.0, 21.9],
]
## Balloon liveries: [style, colours...]. Styles: 0 gores in two colours, 1 bands up the envelope, 2 a zigzag band
## round the equator, 3 a diamond pattern, 4 a sunburst from the crown.
const BALLOONS := [
	[0, Color(0.92, 0.18, 0.16), Color(0.98, 0.84, 0.22)],
	[1, Color(0.85, 0.12, 0.16), Color(0.96, 0.50, 0.10), Color(0.98, 0.84, 0.20), Color(0.20, 0.62, 0.30), Color(0.14, 0.38, 0.78), Color(0.46, 0.20, 0.62)],
	[2, Color(0.10, 0.48, 0.62), Color(0.96, 0.92, 0.82), Color(0.84, 0.30, 0.16)],
	[3, Color(0.96, 0.90, 0.84), Color(0.16, 0.30, 0.66)],
	[4, Color(0.98, 0.70, 0.10), Color(0.86, 0.16, 0.22)],
	[0, Color(0.20, 0.30, 0.70), Color(0.95, 0.95, 0.95)],
	[2, Color(0.70, 0.18, 0.40), Color(0.98, 0.80, 0.30), Color(0.20, 0.20, 0.30)],
	[1, Color(0.15, 0.55, 0.50), Color(0.95, 0.85, 0.70), Color(0.92, 0.45, 0.20)],
]
const GORES := 24


static func _envelope_colour(livery: Array, g: int, h01: float, a: float) -> Color:
	var style: int = livery[0]
	var cols: Array = livery.slice(1)
	match style:
		0:
			return cols[g % 2]
		1:
			return cols[clampi(int(h01 * float(cols.size()) * 0.999), 0, cols.size() - 1)]
		2:
			var band: float = 0.42 + 0.06 * absf(fmod(a * 8.0 / TAU * 2.0, 2.0) - 1.0) * 2.0 - 0.06
			if h01 > band - 0.07 and h01 < band + 0.07:
				return cols[2]
			return cols[0] if h01 < band else cols[1]
		3:
			var du: float = fmod(a / TAU * 12.0 + h01 * 6.0, 1.0)
			var dv: float = fmod(a / TAU * 12.0 - h01 * 6.0 + 10.0, 1.0)
			return cols[1] if (du < 0.5) != (dv < 0.5) else cols[0]
		4:
			if h01 > 0.62:
				return cols[1] if g % 2 == 0 else cols[0]
			return cols[0] if g % 4 < 2 else cols[1]
	return cols[0]


## A hot air balloon at life size, its basket's floor at y = 0 and the envelope's mouth over it, in livery `style`
## (BALLOONS). The flame over the burner is its own surface ("flame"), lit by the `burn` instance uniform.
static func balloon(pk: PropKit, kit: Dictionary, style: int, tilt := Basis()) -> void:
	var base: Transform3D = pk.xf
	var mouth_y := 4.1
	pk.set_frame(base * Transform3D(tilt, Vector3.ZERO))
	_envelope(pk, kit, BALLOONS[style % BALLOONS.size()], Transform3D(Basis(), Vector3(0, mouth_y, 0)), 1.0)
	# The scoop round the mouth, the load cables down to the burner frame.
	for k in range(8):
		var a: float = TAU * float(k) / 8.0
		var top := Vector3(cos(a) * 2.2, mouth_y + 0.1, sin(a) * 2.2)
		pk.beam(kit, "steel", top, Vector3(cos(a) * 0.55, 2.35, sin(a) * 0.55), 0.03, 0.03, Color(0.2, 0.2, 0.2))
	_basket(pk, kit)
	pk.set_frame(base)


## The envelope through `xf` (its mouth at the origin, up its axis), squashed onto the ground below `flat_y` (in the
## envelope's frame) when it lies inflating.
static func _envelope(pk: PropKit, kit: Dictionary, livery: Array, xf: Transform3D, _scale: float, flat_y := -1e9) -> void:
	var n: int = ENVELOPE.size()
	var rings := 3
	var prof: Array = []
	for k in range(n - 1):
		for r in range(rings):
			var t: float = float(r) / float(rings)
			var a: Array = ENVELOPE[k]
			var b: Array = ENVELOPE[k + 1]
			prof.append(Vector2(lerpf(float(a[0]), float(b[0]), t), lerpf(float(a[1]), float(b[1]), t)))
	prof.append(Vector2(0.0, float(ENVELOPE[n - 1][1])))
	var sub := 2
	var segs: int = GORES * sub
	var top_h: float = float(ENVELOPE[n - 1][1])
	for k in range(prof.size() - 1):
		var p0: Vector2 = prof[k]
		var p1: Vector2 = prof[k + 1]
		var d: Vector2 = p1 - p0
		var n2: Vector2 = Vector2(d.y, -d.x).normalized()
		for j in range(segs):
			var t0: float = TAU * float(j) / float(segs)
			var t1: float = TAU * float(j + 1) / float(segs)
			# Each gore bulges a little between its seams.
			var bul0: float = 1.0 + 0.025 * sin(PI * float(j % sub) / float(sub))
			var bul1: float = 1.0 + 0.025 * sin(PI * float((j + 1) % sub) / float(sub))
			var u0 := Vector3(cos(t0), 0.0, sin(t0))
			var u1 := Vector3(cos(t1), 0.0, sin(t1))
			var q00: Vector3 = xf * (u0 * p0.x * bul0 + Vector3.UP * p0.y)
			var q01: Vector3 = xf * (u1 * p0.x * bul1 + Vector3.UP * p0.y)
			var q10: Vector3 = xf * (u0 * p1.x * bul0 + Vector3.UP * p1.y)
			var q11: Vector3 = xf * (u1 * p1.x * bul1 + Vector3.UP * p1.y)
			var nn0: Vector3 = xf.basis * (u0 * n2.x + Vector3.UP * n2.y)
			var nn1: Vector3 = xf.basis * (u1 * n2.x + Vector3.UP * n2.y)
			if flat_y > -1e8:
				q00.y = maxf(q00.y, flat_y)
				q01.y = maxf(q01.y, flat_y)
				q10.y = maxf(q10.y, flat_y)
				q11.y = maxf(q11.y, flat_y)
			var g: int = j / sub
			var h01: float = (p0.y + p1.y) * 0.5 / top_h
			var col: Color = _envelope_colour(livery, g, h01, (t0 + t1) * 0.5)
			var uv00 := Vector2(float(j) / float(sub), p0.y / top_h)
			var uv01 := Vector2(float(j + 1) / float(sub), p0.y / top_h)
			var uv10 := Vector2(float(j) / float(sub), p1.y / top_h)
			var uv11 := Vector2(float(j + 1) / float(sub), p1.y / top_h)
			var out: Vector3 = (nn0 + nn1).normalized()
			if p0.x > 1e-5 or p1.x > 1e-5:
				pk.tri(kit, "envelope", q00, q01, q11, nn0, nn1, nn1, col, out, uv00, uv01, uv11)
				pk.tri(kit, "envelope", q00, q11, q10, nn0, nn1, nn0, col, out, uv00, uv11, uv10)


## The wicker basket (floor at y = 0), its padded rim, the burner frame and twin burners over it, the flame.
static func _basket(pk: PropKit, kit: Dictionary) -> void:
	var wicker := Color(0.62, 0.46, 0.28)
	pk.block(kit, "canvas", Vector3(-0.75, 0.0, -0.75), Vector3(0.75, 1.1, 0.75), wicker)
	pk.block(kit, "matte", Vector3(-0.8, 1.05, -0.8), Vector3(0.8, 1.2, 0.8), Color(0.30, 0.20, 0.14))
	for c in [Vector3(-0.7, 1.2, -0.7), Vector3(0.7, 1.2, -0.7), Vector3(0.7, 1.2, 0.7), Vector3(-0.7, 1.2, 0.7)]:
		pk.beam(kit, "steel", c, Vector3(c.x * 0.8, 2.35, c.z * 0.8), 0.04, 0.04, Color(0.25, 0.25, 0.25))
	pk.block(kit, "steel", Vector3(-0.6, 2.3, -0.6), Vector3(0.6, 2.4, 0.6), Color(0.6, 0.6, 0.6))
	for bx in [-0.22, 0.22]:
		pk.tube(kit, "metal", Vector3(bx, 2.4, 0), Vector3(bx, 2.75, 0), 0.2, 0.2, 10, Color(0.75, 0.74, 0.7))
	# The flame: a cone up into the mouth, UV.y from its root to its tip.
	var root := Vector3(0, 2.8, 0)
	var tip := Vector3(0, 5.8, 0)
	for k in range(10):
		var a0: float = TAU * float(k) / 10.0
		var a1: float = TAU * float(k + 1) / 10.0
		var p0: Vector3 = root + Vector3(cos(a0), 0, sin(a0)) * 0.42
		var p1: Vector3 = root + Vector3(cos(a1), 0, sin(a1)) * 0.42
		var n0 := Vector3(cos(a0), 0.2, sin(a0)).normalized()
		pk.tri(kit, "flame", p0, p1, tip, n0, n0, n0, Color.WHITE, n0, Vector2(float(k) / 10.0, 0.0), Vector2(float(k + 1) / 10.0, 0.0), Vector2(float(k) / 10.0, 1.0))


## A balloon being cold-inflated: the envelope lying on its side downwind of its basket (on its side too), half full
## and slumped onto the ground, an inflator fan blowing into the mouth. Its mouth toward -z.
static func balloon_inflating(pk: PropKit, kit: Dictionary, style: int) -> void:
	var lie := Transform3D(Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(1.0, 1.0, 0.62)), Vector3(0, 5.2, -2.0))
	_envelope(pk, kit, BALLOONS[style % BALLOONS.size()], lie, 1.0, 0.25)
	# The basket on its side at the mouth, the fan behind it.
	var base: Transform3D = pk.xf
	pk.set_frame(base * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.75, -3.6)))
	_basket(pk, kit)
	pk.set_frame(base)
	var fan_c := Vector3(1.8, 1.0, -6.8)
	pk.tube(kit, "paint", fan_c, fan_c + Vector3(-0.5, 0.15, 1.2), 0.95, 0.95, 16, Color(0.85, 0.2, 0.15))
	pk.block(kit, "steel", fan_c + Vector3(-0.7, -1.0, -0.6), fan_c + Vector3(0.7, -0.6, 0.6), Color(0.25, 0.25, 0.25))


# ======================================================================================
#  Pit equipment and small things
# ======================================================================================

## A mobile light plant at life size (front, drawbar and lamps toward -z): a single-axle trailer chassis on leaf
## springs with mudguards, an A-frame drawbar with its hitch eye and jockey wheel, the generator canopy (chamfered
## roof, louvred vents, door seams and handles, the control panel at the back, exhaust stack, lifting eye, amber
## beacon, hazard stripes), four outriggers on screw jacks, and a three-stage telescopic mast with its winch and
## cable carrying a crossbar of four finned LED floods, tilted down toward -z.
static func light_tower(pk: PropKit, kit: Dictionary) -> void:
	var y := MINE_YELLOW
	var black := FRAME_BLACK
	var grey := Color(0.62, 0.63, 0.62)
	var dark := Color(0.06, 0.06, 0.07)
	# --- Chassis -------------------------------------------------------------------------------------------------
	for rx in [-0.55, 0.55]:
		pk.block(kit, "steel", Vector3(rx - 0.05, 0.52, -1.95), Vector3(rx + 0.05, 0.68, 1.95), dusty(black, 0.5, 1.5, 0.6))
		# The leaf spring under the rail, its shackles at each end.
		pk.block(kit, "steel", Vector3(rx - 0.04, 0.4, -0.35), Vector3(rx + 0.04, 0.46, 0.75), Color(0.15, 0.15, 0.15))
		for sz in [-0.33, 0.73]:
			pk.block(kit, "steel", Vector3(rx - 0.05, 0.42, sz - 0.03), Vector3(rx + 0.05, 0.54, sz + 0.03), Color(0.15, 0.15, 0.15))
	for cz in [-1.85, -0.9, 0.0, 0.9, 1.85]:
		pk.block(kit, "steel", Vector3(-0.6, 0.55, cz - 0.04), Vector3(0.6, 0.66, cz + 0.04), dusty(black, 0.5, 1.5, 0.6))
	pk.tube(kit, "steel", Vector3(-1.0, 0.37, 0.2), Vector3(1.0, 0.37, 0.2), 0.05, 0.05, 10, Color(0.14, 0.14, 0.14))
	for sx in [-1.0, 1.0]:
		var wc := Vector3(sx, 0.37, 0.2)
		var turn := Basis(Vector3.FORWARD, PI * 0.5)
		pk.tyre(kit, "rubber", wc, 0.2, 0.37, 0.22, 18, Color(0.07, 0.07, 0.07), turn)
		pk.tube(kit, "paint", wc - Vector3(sx * 0.1, 0, 0), wc + Vector3(sx * 0.1, 0, 0), 0.2, 0.2, 18, Color(0.82, 0.82, 0.8), false)
		pk.tube(kit, "paint", wc + Vector3(sx * 0.08, 0, 0), wc + Vector3(sx * 0.12, 0, 0), 0.19, 0.17, 18, Color(0.82, 0.82, 0.8))
		pk.tube(kit, "steel", wc + Vector3(sx * 0.12, 0, 0), wc + Vector3(sx * 0.17, 0, 0), 0.07, 0.06, 10, Color(0.3, 0.3, 0.3))
		for k in range(5):
			var a: float = TAU * float(k) / 5.0
			var bp: Vector3 = wc + Vector3(sx * 0.12, sin(a) * 0.11, cos(a) * 0.11)
			pk.tube(kit, "steel", bp, bp + Vector3(sx * 0.03, 0, 0), 0.015, 0.015, 6, Color(0.25, 0.25, 0.25))
		# The mudguard: an arc of plates over the tyre, on a stay from the rail.
		var segs := 7
		for k in range(segs):
			var a0: float = lerpf(-1.35, 1.35, float(k) / segs)
			var a1: float = lerpf(-1.35, 1.35, float(k + 1) / segs)
			var p0: Vector3 = wc + Vector3(0, cos(a0), sin(a0)) * 0.45
			var p1: Vector3 = wc + Vector3(0, cos(a1), sin(a1)) * 0.45
			pk.beam(kit, "paint", p0, p1, 0.3, 0.025, dusty(black, 0.7, 1.2, 0.5), Vector3.RIGHT)
		pk.beam(kit, "steel", Vector3(sx * 0.6, 0.6, 0.2), Vector3(sx * 0.95, 0.8, 0.2), 0.05, 0.05, black)
	# --- Drawbar, hitch eye, jockey wheel, safety chains ---------------------------------------------------------
	for rx in [-0.5, 0.5]:
		pk.beam(kit, "steel", Vector3(rx, 0.6, -1.9), Vector3(0.0, 0.55, -3.0), 0.09, 0.11, dusty(y, 0.5, 1.5, 0.6))
	pk.block(kit, "steel", Vector3(-0.07, 0.5, -3.15), Vector3(0.07, 0.6, -2.95), Color(0.2, 0.2, 0.2))
	pk.tyre(kit, "steel", Vector3(0, 0.55, -3.27), 0.05, 0.11, 0.05, 14, Color(0.25, 0.25, 0.25))
	pk.tube(kit, "steel", Vector3(0.22, 0.25, -2.55), Vector3(0.22, 0.95, -2.55), 0.045, 0.045, 10, black)
	pk.block(kit, "steel", Vector3(0.12, 0.6, -2.62), Vector3(0.18, 0.66, -2.48), black)
	pk.beam(kit, "steel", Vector3(0.22, 0.95, -2.55), Vector3(0.38, 0.95, -2.55), 0.03, 0.03, Color(0.6, 0.1, 0.08))
	pk.tyre(kit, "rubber", Vector3(0.22, 0.1, -2.55), 0.03, 0.1, 0.06, 12, Color(0.07, 0.07, 0.07), Basis(Vector3.FORWARD, PI * 0.5))
	for cx in [-0.12, 0.12]:
		for k in range(5):
			var c: Vector3 = Vector3(cx * (1.0 - k * 0.15), 0.52 - 0.06 * sin(PI * k / 4.0), -2.95 + k * 0.12)
			pk.tyre(kit, "steel", c, 0.012, 0.03, 0.012, 6, Color(0.5, 0.5, 0.5), Basis(Vector3.RIGHT, PI * 0.5 * float(k % 2)))
	# --- Generator canopy -----------------------------------------------------------------------------------------
	var hw := 0.8
	var top := 1.95
	pk.extrude(kit, "paint", PackedVector2Array([Vector2(-hw, 0.7), Vector2(hw, 0.7), Vector2(hw, top - 0.14), Vector2(hw - 0.14, top),
			Vector2(-hw + 0.14, top), Vector2(-hw, top - 0.14)]), -1.8, 1.8, 0.03, dusty(y, 0.7, 2.2, 0.45))
	for side in [-1.0, 1.0]:
		var fx: float = side * (hw + 0.004)
		# Two doors: seams, hinges and a handle each.
		for dz in [[-1.55, -0.05], [0.05, 1.55]]:
			for zz in dz:
				pk.block(kit, "matte", Vector3(fx - 0.006, 0.8, zz - 0.012), Vector3(fx + 0.006, top - 0.2, zz + 0.012), dark)
			pk.block(kit, "matte", Vector3(fx - 0.006, top - 0.21, dz[0]), Vector3(fx + 0.006, top - 0.19, dz[1]), dark)
			pk.block(kit, "matte", Vector3(fx - 0.006, 0.79, dz[0]), Vector3(fx + 0.006, 0.81, dz[1]), dark)
			pk.block(kit, "metal", Vector3(fx - 0.01, 1.2, dz[1] - 0.16), Vector3(fx + side * 0.04, 1.32, dz[1] - 0.12), Color(0.2, 0.2, 0.2))
			# The louvred vent in the door's upper half.
			var v0: float = dz[0] + 0.25
			var v1: float = dz[1] - 0.3
			pk.block(kit, "matte", Vector3(fx - 0.006, 1.35, v0), Vector3(fx + 0.006, 1.68, v1), dark)
			for k in range(6):
				var vy: float = 1.38 + 0.05 * k
				pk.box(kit, "paint", Transform3D(Basis(Vector3.FORWARD, side * 0.6), Vector3(fx + side * 0.012, vy, (v0 + v1) * 0.5)),
						Vector3(0.012, 0.045, v1 - v0), y.darkened(0.15))
		# Hazard stripes along the skirt, a fuel cap on the right.
		_hazard_band(pk, kit, Vector3(fx + side * 0.004, 0.0, 0.0), Vector3(0, 0, 1), Vector3(side, 0, 0), -1.8, 1.8, 0.71, 0.82)
		if side > 0.0:
			pk.tube(kit, "metal", Vector3(fx, 1.05, -1.3), Vector3(fx + 0.06, 1.05, -1.3), 0.06, 0.06, 12, Color(0.2, 0.2, 0.2))
	# The control panel at the back, behind a window, its displays lit, and an e-stop.
	pk.block(kit, "matte", Vector3(-0.55, 0.95, 1.8), Vector3(0.55, 1.7, 1.81), dark)
	pk.block(kit, "glassdark", Vector3(-0.5, 1.0, 1.81), Vector3(0.5, 1.65, 1.82), GLASS)
	for k in range(3):
		pk.block(kit, "lamp", Vector3(-0.4 + k * 0.3, 1.42, 1.805), Vector3(-0.22 + k * 0.3, 1.52, 1.81), Color(0.4, 0.9, 0.5))
	pk.tube(kit, "paint", Vector3(0.35, 1.15, 1.8), Vector3(0.35, 1.15, 1.86), 0.05, 0.05, 12, Color(0.85, 0.1, 0.08))
	_hazard_band(pk, kit, Vector3(0.0, 0.0, 1.804), Vector3(-1, 0, 0), Vector3(0, 0, 1), -0.8, 0.8, 0.71, 0.82)
	# Roof: exhaust stack with its rain flap, a lifting eye, the amber beacon.
	pk.tube(kit, "metal", Vector3(0.45, top, -1.25), Vector3(0.45, top + 0.55, -1.25), 0.05, 0.05, 10, Color(0.25, 0.24, 0.23))
	pk.box(kit, "metal", Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0.45, top + 0.57, -1.23)), Vector3(0.12, 0.01, 0.12), Color(0.25, 0.24, 0.23))
	pk.tyre(kit, "steel", Vector3(0, top + 0.1, -0.4), 0.05, 0.1, 0.03, 12, Color(0.2, 0.2, 0.2), Basis(Vector3.FORWARD, PI * 0.5))
	pk.block(kit, "steel", Vector3(-0.08, top, -0.45), Vector3(0.08, top + 0.03, -0.35), Color(0.2, 0.2, 0.2))
	pk.tube(kit, "matte", Vector3(-0.55, top, -1.5), Vector3(-0.55, top + 0.05, -1.5), 0.08, 0.08, 12, dark)
	pk.tube(kit, "lamp", Vector3(-0.55, top + 0.05, -1.5), Vector3(-0.55, top + 0.2, -1.5), 0.065, 0.05, 12, Color(1.0, 0.55, 0.1))
	# --- Outriggers on screw jacks ----------------------------------------------------------------------------------
	for c in [Vector3(-1.85, 0.0, -1.45), Vector3(1.85, 0.0, -1.45), Vector3(-1.85, 0.0, 1.45), Vector3(1.85, 0.0, 1.45)]:
		var sgn: float = signf(c.x)
		pk.block(kit, "steel", Vector3(minf(sgn * 0.5, sgn * 1.0), 0.57, c.z - 0.07), Vector3(maxf(sgn * 0.5, sgn * 1.0), 0.71, c.z + 0.07), dusty(y, 0.6, 1.5, 0.6))
		pk.block(kit, "steel", Vector3(minf(sgn * 0.95, c.x), 0.59, c.z - 0.055), Vector3(maxf(sgn * 0.95, c.x), 0.69, c.z + 0.055), Color(0.55, 0.56, 0.56))
		for pz in [-0.03, 0.03]:
			pk.block(kit, "steel", Vector3(c.x - 0.002, 0.58, c.z + pz - 0.01), Vector3(c.x + 0.002, 0.72, c.z + pz + 0.01), Color(0.2, 0.2, 0.2))
		pk.tube(kit, "steel", Vector3(c.x, 0.1, c.z), Vector3(c.x, 0.95, c.z), 0.055, 0.055, 10, dusty(y, 0.4, 1.2, 0.6))
		pk.tube(kit, "metal", Vector3(c.x, 0.06, c.z), Vector3(c.x, 0.35, c.z), 0.03, 0.03, 8, Color(0.6, 0.6, 0.6))
		pk.block(kit, "steel", Vector3(c.x - 0.2, 0.0, c.z - 0.2), Vector3(c.x + 0.2, 0.05, c.z + 0.2), dusty(black, 0.0, 0.5, 0.8))
		pk.beam(kit, "steel", Vector3(c.x, 0.97, c.z), Vector3(c.x + sgn * 0.18, 0.97, c.z), 0.025, 0.025, black)
		pk.tube(kit, "matte", Vector3(c.x + sgn * 0.18, 0.97, c.z), Vector3(c.x + sgn * 0.18, 1.08, c.z), 0.02, 0.02, 6, dark)
	# --- Mast: three telescoping sections on a pivot bracket at the back, a winch and its cable ---------------------
	var mz := 1.35
	pk.block(kit, "steel", Vector3(-0.22, top, mz - 0.22), Vector3(0.22, top + 0.12, mz + 0.22), black)
	for bx in [-0.2, 0.2]:
		pk.block(kit, "steel", Vector3(bx - 0.025, top + 0.1, mz - 0.18), Vector3(bx + 0.025, top + 0.45, mz + 0.18), black)
	pk.tube(kit, "metal", Vector3(-0.26, top + 0.32, mz), Vector3(0.26, top + 0.32, mz), 0.035, 0.035, 8, Color(0.6, 0.6, 0.6))
	var sections := [[top + 0.12, 4.7, 0.26], [4.5, 7.2, 0.2], [7.0, 9.25, 0.15]]
	for sec in sections:
		var w: float = sec[2]
		pk.block(kit, "metal", Vector3(-w * 0.5, sec[0], mz - w * 0.5), Vector3(w * 0.5, sec[1], mz + w * 0.5), grey.lightened(0.08 * (w < 0.2 as int)))
		# The collar at the top of each section, where the next one slides out.
		pk.block(kit, "steel", Vector3(-w * 0.5 - 0.025, sec[1] - 0.14, mz - w * 0.5 - 0.025), Vector3(w * 0.5 + 0.025, sec[1], mz + w * 0.5 + 0.025), Color(0.3, 0.3, 0.3))
	# A hydraulic ram that raised the mast, from the roof to the first section.
	pk.tube(kit, "paint", Vector3(0, top + 0.05, mz - 0.75), Vector3(0, 2.9, mz - 0.15), 0.06, 0.06, 10, dark)
	pk.tube(kit, "metal", Vector3(0, 2.6, mz - 0.33), Vector3(0, 3.2, mz - 0.13), 0.035, 0.035, 8, Color(0.75, 0.75, 0.75))
	# The winch on the mast's side: drum, gear case, crank.
	pk.tube(kit, "steel", Vector3(0.14, 2.65, mz), Vector3(0.36, 2.65, mz), 0.09, 0.09, 14, Color(0.3, 0.3, 0.3))
	pk.block(kit, "paint", Vector3(0.36, 2.52, mz - 0.1), Vector3(0.44, 2.78, mz + 0.1), y)
	pk.beam(kit, "steel", Vector3(0.44, 2.65, mz), Vector3(0.5, 2.65, mz), 0.03, 0.03, black)
	pk.beam(kit, "steel", Vector3(0.5, 2.65, mz), Vector3(0.5, 2.45, mz - 0.1), 0.03, 0.03, black)
	pk.tube(kit, "matte", Vector3(0.25, 2.75, mz + 0.06), Vector3(0.0, 9.2, mz + 0.09), 0.012, 0.012, 5, Color(0.5, 0.5, 0.5), false)
	# The power cable spirals loosely down the mast.
	var prev := Vector3(-0.12, 9.1, mz)
	for k in range(1, 26):
		var cy: float = lerpf(9.1, top + 0.3, float(k) / 25.0)
		var a: float = float(k) * 1.1
		var cr: float = lerpf(0.11, 0.18, float(k) / 25.0)
		var q := Vector3(-cos(a) * cr, cy, mz + sin(a) * cr)
		pk.tube(kit, "rubber", prev, q, 0.018, 0.018, 5, dark, false)
		prev = q
	# --- The lamp head: a crossbar, a junction box and four LED floods on yokes, tilted down toward -z -------------
	var hy := 9.35
	pk.block(kit, "steel", Vector3(-1.38, hy - 0.06, mz - 0.06), Vector3(1.38, hy + 0.06, mz + 0.06), Color(0.28, 0.28, 0.28))
	pk.block(kit, "steel", Vector3(-0.2, hy - 0.18, mz - 0.1), Vector3(0.2, hy - 0.06, mz + 0.1), Color(0.3, 0.3, 0.3))
	pk.block(kit, "paint", Vector3(-0.14, hy - 0.4, mz + 0.08), Vector3(0.14, hy - 0.18, mz + 0.2), Color(0.85, 0.85, 0.82))
	var aim := Basis(Vector3.RIGHT, deg_to_rad(-22.0))
	for lx in [-1.12, -0.37, 0.37, 1.12]:
		var hc := Vector3(lx, hy + 0.32, mz - 0.05)
		# Yoke: two arms up from the bar to the housing's pivots.
		for yx in [-0.33, 0.33]:
			pk.block(kit, "steel", Vector3(lx + yx - 0.02, hy + 0.06, mz - 0.08), Vector3(lx + yx + 0.02, hc.y + 0.04, mz - 0.02), Color(0.22, 0.22, 0.22))
			pk.tube(kit, "metal", Vector3(lx + yx - 0.04, hc.y, hc.z), Vector3(lx + yx + 0.04, hc.y, hc.z), 0.04, 0.04, 8, Color(0.5, 0.5, 0.5))
		var hx := Transform3D(aim, hc)
		pk.box(kit, "paint", hx, Vector3(0.6, 0.46, 0.1), Color(0.18, 0.18, 0.19))
		# Cooling fins on the back.
		for k in range(9):
			var fx: float = lerpf(-0.26, 0.26, float(k) / 8.0)
			pk.box(kit, "steel", hx * Transform3D(Basis(), Vector3(fx, 0.0, 0.08)), Vector3(0.015, 0.42, 0.07), Color(0.24, 0.24, 0.25))
		# Bezel, lens, a 4 x 3 grid of LEDs behind it, and the visor over it.
		pk.box(kit, "steel", hx * Transform3D(Basis(), Vector3(0, 0, -0.055)), Vector3(0.6, 0.46, 0.012), Color(0.1, 0.1, 0.1))
		pk.box(kit, "glassdark", hx * Transform3D(Basis(), Vector3(0, 0, -0.062)), Vector3(0.52, 0.38, 0.004), Color(0.3, 0.3, 0.32))
		for gx in range(4):
			for gy in range(3):
				var lp := Vector3(lerpf(-0.18, 0.18, gx / 3.0), lerpf(-0.12, 0.12, gy / 2.0), -0.068)
				pk.box(kit, "lamp", hx * Transform3D(Basis(), lp), Vector3(0.075, 0.075, 0.006), Color(1.0, 0.97, 0.9))
		pk.box(kit, "paint", hx * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-25.0)), Vector3(0, 0.255, -0.1)), Vector3(0.6, 0.012, 0.16), Color(0.18, 0.18, 0.19))
		pk.tube(kit, "rubber", Vector3(lx, hc.y - 0.2, hc.z + 0.12), Vector3(lx * 0.3, hy - 0.2, mz + 0.14), 0.012, 0.012, 5, dark, false)


## A black band from `a0` to `a1` along `along` (on the plane through `o`, facing `n`), between heights `y0` and
## `y1`, with yellow stripes slanting across it: the hazard marking along a machine's skirt.
static func _hazard_band(pk: PropKit, kit: Dictionary, o: Vector3, along: Vector3, n: Vector3, a0: float, a1: float, y0: float, y1: float) -> void:
	var at := func(a: float, yy: float, lift: float) -> Vector3: return o + along * a + Vector3(0, yy, 0) + n * lift
	pk.panel(kit, "paint", [at.call(a0, y0, 0.0), at.call(a0, y1, 0.0), at.call(a1, y1, 0.0), at.call(a1, y0, 0.0)], n, Color(0.05, 0.05, 0.05), Color(0.05, 0.05, 0.05))
	var h: float = y1 - y0
	var w := 0.07
	var a: float = a0 - h
	while a < a1:
		var b0: float = clampf(a, a0, a1)
		var b1: float = clampf(a + w, a0, a1)
		var t0: float = clampf(a + h, a0, a1)
		var t1: float = clampf(a + w + h, a0, a1)
		if b1 > b0 or t1 > t0:
			pk.panel(kit, "paint", [at.call(b0, y0, 0.003), at.call(t0, y1, 0.003), at.call(t1, y1, 0.003), at.call(b1, y0, 0.003)], n,
					MINE_YELLOW, MINE_YELLOW)
		a += w * 2.0


## A blast-hole drill at life size (mast end toward -z): two crawler tracks (shoes round a sprocket and an idler,
## rollers, the frame), a railed deck on them with four levelling jacks, the power pack (louvred engine house, radiator
## grille, exhausts, air cleaners, hydraulic tank), a dust collector, the operator's cab (glazed all round, a ROPS roof
## with lamps, mirrors, a ladder up to the deck), and the drill mast: a lattice tower on its pivot with two raise rams,
## a crown block on top, the rotary head part way up with its hoses, the drill pipe down through the centraliser into the
## dust hood on the ground, a rod carousel beside it, work lamps and hazard stripes.
static func drill_rig(pk: PropKit, kit: Dictionary) -> void:
	var c := Color(0.92, 0.36, 0.10)
	var dark := Color(0.13, 0.13, 0.13)
	var steel := Color(0.42, 0.43, 0.44)
	var white := Color(0.93, 0.92, 0.88)
	# --- Crawlers -------------------------------------------------------------------------------------------------
	for sx in [-1.95, 1.95]:
		_drill_track(pk, kit, sx, 7.4, 0.42)
	# The carbody between the tracks.
	pk.block(kit, "steel", Vector3(-1.5, 0.55, -1.6), Vector3(1.5, 1.15, 1.6), dusty(dark, 0.6, 1.5, 0.6))
	# --- Deck: a frame, chequer plate on it, rails round its edge, levelling jacks at its corners ----------------------
	pk.block(kit, "steel", Vector3(-2.55, 1.15, -3.7), Vector3(2.55, 1.5, 4.3), dusty(c.darkened(0.25), 1.2, 2.5))
	pk.block(kit, "metal", Vector3(-2.5, 1.5, -3.65), Vector3(2.5, 1.53, 4.25), Color(0.5, 0.5, 0.5))
	_hazard_band(pk, kit, Vector3(0, 0, 4.302), Vector3(-1, 0, 0), Vector3(0, 0, 1), -2.55, 2.55, 1.18, 1.47)
	for jc in [Vector3(-2.35, 0, -3.4), Vector3(2.35, 0, -3.4), Vector3(-2.35, 0, 4.0), Vector3(2.35, 0, 4.0)]:
		var jsx: float = signf(jc.x)
		var jx: float = jc.x + jsx * 0.55
		pk.block(kit, "paint", Vector3(minf(jc.x, jx) - 0.05, 1.05, jc.z - 0.22), Vector3(maxf(jc.x, jx) + 0.05, 1.45, jc.z + 0.22), c)
		pk.tube(kit, "paint", Vector3(jx, 0.55, jc.z), Vector3(jx, 1.45, jc.z), 0.16, 0.16, 12, c)
		pk.tube(kit, "metal", Vector3(jx, 0.12, jc.z), Vector3(jx, 0.6, jc.z), 0.1, 0.1, 10, Color(0.8, 0.8, 0.78))
		pk.block(kit, "steel", Vector3(jx - 0.32, 0.0, jc.z - 0.32), Vector3(jx + 0.32, 0.12, jc.z + 0.32), dusty(dark, 0.0, 0.6, 0.8))
	_railing(pk, kit, [Vector3(0.2, 1.53, 4.2), Vector3(2.45, 1.53, 4.2), Vector3(2.45, 1.53, -0.6)], 1.05, Color(0.98, 0.8, 0.1))
	_railing(pk, kit, [Vector3(-2.45, 1.53, -0.6), Vector3(-2.45, 1.53, 0.2)], 1.05, Color(0.98, 0.8, 0.1))
	# --- The power pack and compressor house -------------------------------------------------------------------------
	var hx0 := -2.2
	var hx1 := 2.0
	var hz0 := 0.5
	var hz1 := 4.0
	pk.extrude(kit, "paint", PackedVector2Array([Vector2(hx0, 1.53), Vector2(hx1, 1.53), Vector2(hx1, 3.75), Vector2(hx1 - 0.25, 4.0),
			Vector2(hx0 + 0.25, 4.0), Vector2(hx0, 3.75)]), hz0, hz1, 0.03, dusty(c, 1.6, 4.0, 0.4))
	for side in [-1.0, 1.0]:
		var fx: float = hx0 - 0.004 if side < 0.0 else hx1 + 0.004
		for dz in [[0.65, 2.15], [2.3, 3.85]]:
			for zz in dz:
				pk.block(kit, "matte", Vector3(fx - 0.006, 1.65, zz - 0.012), Vector3(fx + 0.006, 3.65, zz + 0.012), dark)
			pk.block(kit, "matte", Vector3(fx - 0.006, 2.6, dz[0] + 0.2), Vector3(fx + 0.006, 3.4, dz[1] - 0.2), dark)
			for k in range(7):
				pk.box(kit, "paint", Transform3D(Basis(Vector3.FORWARD, side * 0.6), Vector3(fx + side * 0.015, 2.66 + 0.11 * k, (dz[0] + dz[1]) * 0.5)),
						Vector3(0.015, 0.09, dz[1] - dz[0] - 0.4), c.darkened(0.12))
			pk.block(kit, "metal", Vector3(fx - 0.02, 2.2, dz[1] - 0.2), Vector3(fx + side * 0.05, 2.32, dz[1] - 0.12), dark)
	# The radiator grille at the back: a dark core behind bars.
	pk.block(kit, "matte", Vector3(-1.7, 1.8, hz1), Vector3(1.5, 3.6, hz1 + 0.01), Color(0.05, 0.05, 0.05))
	for k in range(14):
		var gx: float = lerpf(-1.62, 1.42, float(k) / 13.0)
		pk.block(kit, "metal", Vector3(gx - 0.025, 1.8, hz1 + 0.01), Vector3(gx + 0.025, 3.6, hz1 + 0.05), Color(0.3, 0.3, 0.3))
	# On the roof: two exhaust stacks, two air cleaners, the hydraulic tank, a beacon.
	for ex in [0.9, 1.3]:
		pk.tube(kit, "metal", Vector3(ex, 4.0, 3.1), Vector3(ex, 4.9, 3.1), 0.08, 0.08, 10, Color(0.25, 0.24, 0.22))
		pk.box(kit, "metal", Transform3D(Basis(Vector3.RIGHT, -0.4), Vector3(ex, 4.92, 3.12)), Vector3(0.18, 0.012, 0.18), Color(0.25, 0.24, 0.22))
	for ax in [-1.4, -0.8]:
		pk.tube(kit, "paint", Vector3(ax, 4.0, 1.4), Vector3(ax, 4.55, 1.4), 0.24, 0.24, 14, dark)
		pk.tube(kit, "paint", Vector3(ax, 4.55, 1.4), Vector3(ax, 4.62, 1.4), 0.2, 0.12, 14, dark)
	pk.tube(kit, "paint", Vector3(-0.2, 4.25, 0.8), Vector3(1.7, 4.25, 0.8), 0.25, 0.25, 14, white)
	pk.tube(kit, "matte", Vector3(1.5, 4.0, 3.7), Vector3(1.5, 4.05, 3.7), 0.08, 0.08, 10, dark)
	pk.tube(kit, "lamp", Vector3(1.5, 4.05, 3.7), Vector3(1.5, 4.2, 3.7), 0.065, 0.05, 10, Color(1.0, 0.55, 0.1))
	# The dust collector beside the cab: a filter drum on legs, its hose to the hood at the mast's foot.
	pk.tube(kit, "paint", Vector3(1.55, 2.0, -1.1), Vector3(1.55, 3.6, -1.1), 0.55, 0.55, 18, white)
	pk.tube(kit, "paint", Vector3(1.55, 1.53, -1.1), Vector3(1.55, 2.0, -1.1), 0.2, 0.55, 18, white.darkened(0.1))
	pk.tube(kit, "paint", Vector3(1.55, 3.6, -1.1), Vector3(1.55, 3.75, -1.1), 0.55, 0.45, 18, white.darkened(0.05))
	for k in range(5):
		var hy: float = lerpf(2.2, 1.3, float(k) / 4.0)
		var hz: float = lerpf(-1.6, -3.4, float(k) / 4.0)
		var hy2: float = lerpf(2.2, 1.3, float(k + 1) / 4.0) if k < 4 else 0.6
		var hz2: float = lerpf(-1.6, -3.4, float(k + 1) / 4.0) if k < 4 else -4.0
		pk.tube(kit, "rubber", Vector3(1.4, hy, hz), Vector3(1.2, hy2, hz2), 0.12, 0.12, 10, dark, false)
	# --- The operator's cab, front left -------------------------------------------------------------------------------
	var cx0 := -2.45
	var cx1 := -0.35
	var cz0 := -2.9
	var cz1 := -0.55
	var cy0 := 1.53
	var cy1 := 4.0
	pk.block(kit, "paint", Vector3(cx0, cy0, cz0), Vector3(cx1, cy0 + 0.9, cz1), c)
	for post in [Vector2(cx0, cz0), Vector2(cx1, cz0), Vector2(cx0, cz1), Vector2(cx1, cz1)]:
		pk.block(kit, "paint", Vector3(post.x - 0.06, cy0 + 0.9, post.y - 0.06), Vector3(post.x + 0.06, cy1, post.y + 0.06), white)
	pk.block(kit, "glassdark", Vector3(cx0 + 0.06, cy0 + 0.9, cz0 + 0.03), Vector3(cx1 - 0.06, cy1 - 0.05, cz0 + 0.06), GLASS)
	pk.block(kit, "glassdark", Vector3(cx0 + 0.06, cy0 + 0.9, cz1 - 0.06), Vector3(cx1 - 0.06, cy1 - 0.05, cz1 - 0.03), GLASS)
	pk.block(kit, "glassdark", Vector3(cx0 + 0.03, cy0 + 0.9, cz0 + 0.06), Vector3(cx0 + 0.06, cy1 - 0.05, cz1 - 0.06), GLASS)
	pk.block(kit, "glassdark", Vector3(cx1 - 0.06, cy0 + 0.9, cz0 + 0.06), Vector3(cx1 - 0.03, cy1 - 0.05, cz1 - 0.06), GLASS)
	pk.block(kit, "paint", Vector3(cx0 - 0.12, cy1, cz0 - 0.15), Vector3(cx1 + 0.12, cy1 + 0.16, cz1 + 0.12), white)
	pk.block(kit, "steel", Vector3(cx0 - 0.08, cy1 + 0.16, cz0 - 0.1), Vector3(cx1 + 0.08, cy1 + 0.24, cz1 + 0.08), dark)
	for lx in [cx0 + 0.3, cx1 - 0.3]:
		pk.box(kit, "steel", Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(lx, cy1 + 0.36, cz0 + 0.05)), Vector3(0.3, 0.2, 0.14), dark)
		pk.box(kit, "lamp", Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(lx, cy1 + 0.36, cz0 - 0.03)), Vector3(0.24, 0.14, 0.02), Color(1.0, 0.97, 0.9))
	pk.beam(kit, "steel", Vector3(cx0 + 0.6, cy1 - 0.15, cz0 + 0.04), Vector3(cx0 + 1.1, cy0 + 1.2, cz0 + 0.03), 0.03, 0.02, dark)
	for mz in [cz0 + 0.2]:
		pk.beam(kit, "steel", Vector3(cx0, 3.4, mz), Vector3(cx0 - 0.35, 3.5, mz - 0.1), 0.04, 0.04, dark)
		pk.block(kit, "matte", Vector3(cx0 - 0.42, 3.25, mz - 0.25), Vector3(cx0 - 0.36, 3.75, mz + 0.0), dark)
	# The ladder up the side to the deck.
	for lz in [-0.25, 0.25]:
		pk.beam(kit, "paint", Vector3(-2.75, 0.1, lz), Vector3(-2.58, 1.53, lz), 0.05, 0.05, Color(0.98, 0.8, 0.1))
	for k in range(5):
		var ly: float = 0.35 + 0.27 * k
		pk.beam(kit, "steel", Vector3(-2.73 + 0.03 * k, ly, -0.25), Vector3(-2.73 + 0.03 * k, ly, 0.25), 0.04, 0.04, steel)
	# --- The mast -------------------------------------------------------------------------------------------------------
	var mx := 0.55
	var mz := -3.35
	var mh := 17.5
	var half := 0.42
	var chords: Array = []
	for ox in [-half, half]:
		for oz in [-half, half]:
			chords.append(Vector2(mx + ox, mz + oz))
	for ch in chords:
		pk.block(kit, "paint", Vector3(ch.x - 0.07, 1.53, ch.y - 0.07), Vector3(ch.x + 0.07, mh, ch.y + 0.07), c)
	var bay := 1.1
	var nb: int = int((mh - 2.0) / bay)
	for k in range(nb):
		var y0: float = 2.0 + bay * k
		var y1: float = y0 + bay
		for f in range(4):
			var a2: Vector2 = chords[[0, 1, 3, 2][f]]
			var b2: Vector2 = chords[[1, 3, 2, 0][f]]
			var flip: bool = (k + f) % 2 == 0
			pk.beam(kit, "paint", Vector3(a2.x, y0 if flip else y1, a2.y), Vector3(b2.x, y1 if flip else y0, b2.y), 0.06, 0.06, c.darkened(0.08))
			pk.beam(kit, "paint", Vector3(a2.x, y0, a2.y), Vector3(b2.x, y0, b2.y), 0.06, 0.06, c.darkened(0.08))
	# The crown block on top: a sheave in a frame under a cap.
	pk.block(kit, "paint", Vector3(mx - 0.55, mh, mz - 0.55), Vector3(mx + 0.55, mh + 0.25, mz + 0.55), c)
	pk.tube(kit, "metal", Vector3(mx - 0.15, mh + 0.6, mz), Vector3(mx + 0.15, mh + 0.6, mz), 0.38, 0.38, 16, steel)
	for sx2 in [-0.22, 0.22]:
		pk.block(kit, "paint", Vector3(mx + sx2 - 0.04, mh + 0.25, mz - 0.4), Vector3(mx + sx2 + 0.04, mh + 1.05, mz + 0.4), c)
	pk.block(kit, "paint", Vector3(mx - 0.3, mh + 1.05, mz - 0.45), Vector3(mx + 0.3, mh + 1.15, mz + 0.45), white)
	# Mast pivot on the deck and the two raise rams.
	pk.block(kit, "paint", Vector3(mx - 0.7, 1.53, mz + 0.35), Vector3(mx + 0.7, 2.3, mz + 0.95), c.darkened(0.15))
	pk.tube(kit, "metal", Vector3(mx - 0.75, 2.0, mz + 0.65), Vector3(mx + 0.75, 2.0, mz + 0.65), 0.12, 0.12, 10, steel)
	for rx in [-0.35, 0.35]:
		pk.tube(kit, "paint", Vector3(mx + rx * 2.0, 1.6, -0.7), Vector3(mx + rx, 4.6, mz + 0.5), 0.14, 0.14, 10, c.darkened(0.1))
		pk.tube(kit, "metal", Vector3(mx + rx * 1.5, 3.2, mz + 1.6), Vector3(mx + rx, 6.4, mz + 0.45), 0.08, 0.08, 10, Color(0.85, 0.85, 0.82))
	# The rotary head on the mast's face, its hoses looping down, the pipe below it into the ground.
	var head_y := 9.0
	pk.block(kit, "paint", Vector3(mx - 0.5, head_y - 0.6, mz - 0.95), Vector3(mx + 0.5, head_y + 0.6, mz - 0.45), dark)
	pk.tube(kit, "paint", Vector3(mx, head_y + 0.6, mz - 0.7), Vector3(mx, head_y + 1.1, mz - 0.7), 0.25, 0.25, 12, c)
	pk.tube(kit, "metal", Vector3(mx, 0.0, mz - 0.7), Vector3(mx, head_y - 0.6, mz - 0.7), 0.1, 0.1, 12, Color(0.55, 0.55, 0.55))
	var hp := Vector3(mx + 0.3, head_y + 0.9, mz - 0.6)
	for k in range(8):
		var t1: float = float(k + 1) / 8.0
		var q := Vector3(mx + 0.3 + sin(t1 * PI) * 1.1, lerpf(head_y + 0.9, 2.0, t1) + sin(t1 * PI) * 1.4, lerpf(mz - 0.6, mz + 1.0, t1))
		pk.tube(kit, "rubber", hp, q, 0.07, 0.07, 8, dark, false)
		hp = q
	# The centraliser at the mast's foot and the dust hood (a skirt of rubber curtain) round the hole.
	pk.block(kit, "paint", Vector3(mx - 0.45, 1.0, mz - 1.0), Vector3(mx + 0.45, 1.25, mz - 0.4), c.darkened(0.15))
	pk.tube(kit, "rubber", Vector3(mx, 0.0, mz - 0.7), Vector3(mx, 0.75, mz - 0.7), 0.8, 0.65, 18, Color(0.08, 0.08, 0.08))
	pk.tube(kit, "paint", Vector3(mx, 0.75, mz - 0.7), Vector3(mx, 0.95, mz - 0.7), 0.66, 0.66, 18, c)
	# The rod carousel beside the mast: five rods in a cage.
	for k in range(5):
		var a3: float = TAU * float(k) / 5.0
		var rp := Vector2(mx + 1.0 + cos(a3) * 0.28, mz + sin(a3) * 0.28)
		pk.tube(kit, "metal", Vector3(rp.x, 1.6, rp.y), Vector3(rp.x, 9.6, rp.y), 0.08, 0.08, 8, Color(0.5, 0.5, 0.5))
	for cy in [1.8, 5.5, 9.4]:
		pk.tube(kit, "paint", Vector3(mx + 1.0, cy, mz), Vector3(mx + 1.0, cy + 0.15, mz), 0.42, 0.42, 14, c)
	# Work lamps up the mast, hazard stripes on its foot.
	for ly2 in [6.0, 12.0]:
		pk.box(kit, "steel", Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(mx - half - 0.15, ly2, mz - half - 0.1)), Vector3(0.3, 0.22, 0.14), dark)
		pk.box(kit, "lamp", Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(mx - half - 0.15, ly2, mz - half - 0.18)), Vector3(0.24, 0.16, 0.02), Color(1.0, 0.97, 0.9))
	_hazard_band(pk, kit, Vector3(0, 0, mz - half - 0.075), Vector3(1, 0, 0), Vector3(0, 0, -1), mx - half - 0.07, mx + half + 0.07, 1.6, 2.4)


## A drill's crawler at x `sx`: `length` long, its shoes `hw` either side, round a sprocket (rear) and an idler (front),
## rollers under its frame and a carrier on top.
static func _drill_track(pk: PropKit, kit: Dictionary, sx: float, length: float, hw: float) -> void:
	var r := 0.5
	var yc := 0.55
	var zf: float = -length * 0.5 + r
	var zr: float = length * 0.5 - r
	var run: float = zr - zf
	var perim: float = 2.0 * run + TAU * r
	var n: int = int(round(perim / 0.3))
	var shoe := Color(0.18, 0.18, 0.17)
	for k in range(n):
		var u: float = perim * float(k) / float(n)
		var p: Vector3
		var t: Vector3
		if u < run:
			p = Vector3(sx, yc - r, zf + u)
			t = Vector3(0, 0, 1)
		elif u < run + PI * r:
			var a1: float = (u - run) / r
			p = Vector3(sx, yc - cos(a1) * r, zr + sin(a1) * r)
			t = Vector3(0, sin(a1), cos(a1))
		elif u < 2.0 * run + PI * r:
			p = Vector3(sx, yc + r, zr - (u - run - PI * r))
			t = Vector3(0, 0, -1)
		else:
			var a2: float = (u - 2.0 * run - PI * r) / r
			p = Vector3(sx, yc + cos(a2) * r, zf - sin(a2) * r)
			t = Vector3(0, -sin(a2), -cos(a2))
		var nrm: Vector3 = Vector3.RIGHT.cross(t).normalized() * -1.0
		if nrm.dot(p - Vector3(sx, yc, clampf(p.z, zf, zr))) < 0.0:
			nrm = -nrm
		var b := Basis(Vector3.RIGHT, nrm, t)
		var col: Color = dusty(shoe, p.y, 1.5, 0.7).darkened(0.05 * float(k % 3))
		pk.box(kit, "steel", Transform3D(b, p + nrm * 0.03), Vector3(hw * 2.0, 0.08, 0.27), col)
		pk.box(kit, "steel", Transform3D(b, p + nrm * 0.09), Vector3(hw * 2.0 - 0.04, 0.05, 0.06), col.darkened(0.1))
	# The frame between the runs, the rollers under it, the carrier, the sprocket and the idler.
	var fc: Color = dusty(Color(0.16, 0.16, 0.16), 0.5, 1.5, 0.6)
	pk.block(kit, "steel", Vector3(sx - hw * 0.6, yc - 0.18, zf), Vector3(sx + hw * 0.6, yc + 0.32, zr), fc)
	for k in range(6):
		var zz: float = lerpf(zf + 0.4, zr - 0.4, float(k) / 5.0)
		pk.tube(kit, "metal", Vector3(sx - hw * 0.7, yc - r + 0.2, zz), Vector3(sx + hw * 0.7, yc - r + 0.2, zz), 0.13, 0.13, 10, Color(0.3, 0.3, 0.3))
	pk.tube(kit, "metal", Vector3(sx - hw * 0.5, yc + r - 0.15, 0.0), Vector3(sx + hw * 0.5, yc + r - 0.15, 0.0), 0.1, 0.1, 10, Color(0.3, 0.3, 0.3))
	for wz in [zf, zr]:
		pk.tube(kit, "steel", Vector3(sx - hw * 0.75, yc, wz), Vector3(sx + hw * 0.75, yc, wz), r - 0.06, r - 0.06, 16, Color(0.2, 0.2, 0.2))
		var out: float = signf(sx)
		pk.tube(kit, "metal", Vector3(sx + out * hw * 0.75, yc, wz), Vector3(sx + out * (hw * 0.75 + 0.08), yc, wz), 0.22, 0.18, 12, Color(0.35, 0.34, 0.32))
	pk.block(kit, "paint", Vector3(sx - 0.25, yc - 0.1, zr + 0.1), Vector3(sx + 0.25, yc + 0.35, zr + 0.6), Color(0.2, 0.2, 0.2))


## A tumbleweed (radius about 0.45m): a tangle of dry twigs round a hollow, its stem broken off. `seed_v` varies it.
static func tumbleweed(pk: PropKit, kit: Dictionary, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + seed_v
	var straw := Color(0.70, 0.58, 0.40)
	for k in range(150):
		var p := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.28, 0.45)
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		var steps := 4
		var q: Vector3 = p
		var col: Color = straw.darkened(rng.randf_range(0.0, 0.3))
		for s in range(steps):
			var nq: Vector3 = q + d * rng.randf_range(0.08, 0.16)
			# Twigs curve round the ball, in its outer shell, rather than leaving it or crossing its hollow.
			nq = nq.normalized() * clampf(nq.length(), 0.3, 0.47)
			pk.tube(kit, "matte", q, nq, 0.008, 0.006, 3, col, false)
			d = (d + Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))).normalized()
			q = nq


## A sign: a board on two posts, `kind` "warn" (yellow, black border), "info" (white on green), "mine" (orange).
## Its text is a Label3D the generator adds (`board_face` gives where): the board faces -z at `c`, turned by `yaw`.
## `drops` (x the post at -x, y the one at +x) runs a post that much further down, to ground lower than the origin's.
static func sign_board(pk: PropKit, kit: Dictionary, c: Vector3, yaw: float, kind: String, w := 3.2, h := 1.6, post := 2.2, drops := Vector2.ZERO) -> void:
	var base: Transform3D = pk.xf
	pk.set_frame(base * Transform3D(Basis(Vector3.UP, yaw), c))
	var face := {"warn": Color(0.96, 0.78, 0.10), "info": Color(0.08, 0.40, 0.24), "mine": Color(0.94, 0.46, 0.10)}.get(kind, Color.WHITE) as Color
	for px in [-w * 0.36, w * 0.36]:
		var foot: float = -(drops.x if px < 0.0 else drops.y) - 0.25
		pk.beam(kit, "steel", Vector3(px, foot, 0.05), Vector3(px, post + h, 0.05), 0.1, 0.1, Color(0.55, 0.55, 0.55))
		# A concrete footing round the post where it goes into the ground.
		pk.block(kit, "matte", Vector3(px - 0.14, foot + 0.25 - 0.05, -0.09), Vector3(px + 0.14, foot + 0.25 + 0.08, 0.19), Color(0.62, 0.6, 0.56))
	pk.block(kit, "paint", Vector3(-w * 0.5, post, -0.02), Vector3(w * 0.5, post + h, 0.02), Color(0.08, 0.08, 0.08))
	pk.block(kit, "paint", Vector3(-w * 0.5 + 0.08, post + 0.08, -0.05), Vector3(w * 0.5 - 0.08, post + h - 0.08, -0.02), face)
	pk.set_frame(base)


## The mine's gate: a guard hut, a boom barrier raised beside it, flags, and an arch over the road with the mine's
## name. In the road's frame: x across it (-x left of travel), the arch's legs `half_w` out either side, z along it.
## `labels` receives [text, position, outward normal, cap height, colour] for the generator's Label3Ds.
static func mine_gate(pk: PropKit, kit: Dictionary, labels: Array, half_w := 11.5) -> void:
	var o := Color(0.94, 0.46, 0.10)
	var white := Color(0.92, 0.91, 0.88)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * half_w - 0.5, 0.0, -0.5), Vector3(sx * half_w + 0.5, 7.4, 0.5), o)
		pk.block(kit, "matte", Vector3(sx * half_w - 0.9, 0.0, -0.9), Vector3(sx * half_w + 0.9, 0.5, 0.9), Color(0.62, 0.6, 0.56))
	pk.block(kit, "paint", Vector3(-half_w - 0.6, 6.0, -0.45), Vector3(half_w + 0.6, 7.6, 0.45), Color(0.12, 0.12, 0.12))
	# The orange panel faces the carts coming (they drive toward -z, so they see its +z side).
	pk.block(kit, "paint", Vector3(-half_w + 0.5, 6.15, 0.45), Vector3(half_w - 0.5, 7.45, 0.5), o)
	labels.append(["MINA DEL VIENTO", Vector3(0, 6.8, 0.53), Vector3(0, 0, 1), 0.8, Color(0.08, 0.08, 0.08), half_w * 1.7])
	labels.append(["MINA DEL VIENTO", Vector3(0, 6.8, -0.48), Vector3(0, 0, -1), 0.8, Color(0.9, 0.9, 0.88), half_w * 1.7])
	# The boom (raised) on a post at the road's edge; the guard house beside it is a prop of its own (guard_house).
	pk.block(kit, "paint", Vector3(half_w - 0.3, 0.0, 2.6), Vector3(half_w + 0.3, 1.2, 3.2), white)
	var pivot := Vector3(half_w, 1.05, 2.9)
	var boom_tip: Vector3 = pivot + Vector3(-0.35, 7.0, 0.0)
	for k in range(7):
		var a: Vector3 = pivot.lerp(boom_tip, float(k) / 7.0)
		var b: Vector3 = pivot.lerp(boom_tip, float(k + 1) / 7.0)
		pk.beam(kit, "paint", a, b, 0.14, 0.14, Color(0.9, 0.12, 0.1) if k % 2 == 0 else white)


## The guard house at the mine's gate, life size, its front (and the window to the road) toward -z: a rendered
## block house on a plinth with steps, framed windows all round (a sliding hatch to the road), a door, a canopy on
## two columns over the front with the post's name on its fascia, an air-conditioner, a water tank on the roof, a
## radio mast, a solar panel and a floodlight, a bench and a bin. Labels go into `labels`.
static func guard_house(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var wall := Color(0.9, 0.88, 0.83)
	var o := Color(0.94, 0.46, 0.10)
	var frame := Color(0.25, 0.26, 0.27)
	var conc := Color(0.62, 0.6, 0.56)
	var dark := Color(0.08, 0.08, 0.08)
	var hx := 3.0
	var hz := 2.0
	var fy := 0.35
	var wy := 3.0
	# Plinth and the steps up to the door (front right).
	pk.block(kit, "matte", Vector3(-hx - 0.15, 0.0, -hz - 0.15), Vector3(hx + 0.15, fy, hz + 0.15), conc)
	pk.block(kit, "matte", Vector3(-hx - 0.15, 0.0, -3.4), Vector3(hx + 0.15, fy, -hz - 0.15), conc.lightened(0.05))
	pk.block(kit, "matte", Vector3(-hx - 0.15, 0.0, -3.7), Vector3(hx + 0.15, fy * 0.5, -3.4), conc.darkened(0.05))
	# The walls, a darker skirt along their foot.
	pk.block(kit, "paint", Vector3(-hx, fy, -hz), Vector3(hx, wy, hz), wall)
	pk.block(kit, "matte", Vector3(-hx - 0.02, fy, -hz - 0.02), Vector3(hx + 0.02, fy + 0.4, hz + 0.02), Color(0.55, 0.5, 0.44))
	# Windows: [centre along the wall, width] on each wall; the front has the hatch to the road.
	var wins := [
		[Vector3(0, 0, -1), [[-1.2, 2.0], [1.45, 0.9]]],
		[Vector3(-1, 0, 0), [[0.0, 1.8]]],
		[Vector3(1, 0, 0), [[0.0, 1.6]]],
		[Vector3(0, 0, 1), [[-1.0, 1.2], [1.2, 1.2]]],
	]
	for wv in wins:
		var n: Vector3 = wv[0]
		var along := Vector3(-n.z, 0, n.x)
		var face: float = hz if absf(n.z) > 0.5 else hx
		for w in wv[1]:
			var c: Vector3 = n * face + along * float(w[0])
			var ww: float = w[1]
			var y0: float = 1.25
			var y1: float = 2.45
			var lo: Vector3 = c + along * (-ww * 0.5) + Vector3(0, y0, 0)
			var hi: Vector3 = c + along * (ww * 0.5) + Vector3(0, y1, 0)
			# Glass 1.5cm proud, the frame round it 4cm proud, a sill under it.
			pk.block(kit, "glassdark", Vector3(minf(lo.x, hi.x), y0, minf(lo.z, hi.z)) + n * 0.005, Vector3(maxf(lo.x, hi.x), y1, maxf(lo.z, hi.z)) + n * 0.015, GLASS)
			for e in [[lo, Vector3(hi.x, y0 + 0.08, hi.z) if absf(n.z) > 0.5 else Vector3(hi.x, y0 + 0.08, hi.z)],
					[Vector3(lo.x, y1 - 0.08, lo.z), hi]]:
				var a: Vector3 = e[0]
				var b: Vector3 = e[1]
				pk.block(kit, "steel", Vector3(minf(a.x, b.x), a.y, minf(a.z, b.z)) + n * 0.015, Vector3(maxf(a.x, b.x), b.y, maxf(a.z, b.z)) + n * 0.04, frame)
			for t in [-0.5, 0.0, 0.5]:
				var m: Vector3 = c + along * (ww * t)
				var m0: Vector3 = m - along * 0.035
				var m1: Vector3 = m + along * 0.035
				pk.block(kit, "steel", Vector3(minf(m0.x, m1.x), y0, minf(m0.z, m1.z)) + n * 0.015, Vector3(maxf(m0.x, m1.x), y1, maxf(m0.z, m1.z)) + n * 0.04, frame)
			var s0: Vector3 = c + along * (-ww * 0.5 - 0.08)
			var s1: Vector3 = c + along * (ww * 0.5 + 0.08)
			pk.block(kit, "matte", Vector3(minf(s0.x, s1.x), y0 - 0.1, minf(s0.z, s1.z)), Vector3(maxf(s0.x, s1.x), y0, maxf(s0.z, s1.z)) + n * 0.12, conc)
	# The door, front right, with its frame and handle.
	pk.block(kit, "paint", Vector3(2.15, fy, -hz - 0.02), Vector3(2.85, 2.45, -hz), Color(0.3, 0.45, 0.55))
	pk.block(kit, "steel", Vector3(2.08, fy, -hz - 0.04), Vector3(2.15, 2.52, -hz), frame)
	pk.block(kit, "steel", Vector3(2.85, fy, -hz - 0.04), Vector3(2.92, 2.52, -hz), frame)
	pk.block(kit, "steel", Vector3(2.08, 2.45, -hz - 0.04), Vector3(2.92, 2.52, -hz), frame)
	pk.block(kit, "metal", Vector3(2.22, 1.3, -hz - 0.07), Vector3(2.3, 1.36, -hz - 0.02), Color(0.7, 0.7, 0.7))
	# The roof slab, its canopy out over the front on two columns, an orange fascia all round with the name.
	pk.block(kit, "matte", Vector3(-hx - 0.3, wy, -3.7), Vector3(hx + 0.3, wy + 0.18, hz + 0.3), conc.lightened(0.1))
	pk.block(kit, "paint", Vector3(-hx - 0.34, wy - 0.05, -3.74), Vector3(hx + 0.34, wy + 0.42, -3.7), o)
	pk.block(kit, "paint", Vector3(-hx - 0.34, wy - 0.05, hz + 0.3), Vector3(hx + 0.34, wy + 0.42, hz + 0.34), o)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * (hx + 0.3) - 0.02, wy - 0.05, -3.7), Vector3(sx * (hx + 0.3) + 0.02, wy + 0.42, hz + 0.3), o)
		pk.block(kit, "steel", Vector3(sx * (hx - 0.1) - 0.09, fy, -3.55), Vector3(sx * (hx - 0.1) + 0.09, wy, -3.37), frame)
	labels.append(["CONTROL DE ACCESO", Vector3(0, wy + 0.19, -3.76), Vector3(0, 0, -1), 0.26, Color(0.08, 0.08, 0.08), 2.0 * hx])
	# Lamps under the canopy.
	for lx in [-1.4, 1.4]:
		pk.block(kit, "lamp", Vector3(lx - 0.3, wy - 0.03, -3.0), Vector3(lx + 0.3, wy, -2.85), Color(1.0, 0.97, 0.9))
	# On the roof: the water tank on a stand, the radio mast, a solar panel, the floodlight.
	pk.block(kit, "steel", Vector3(-2.2, wy + 0.18, 0.4), Vector3(-1.0, wy + 0.5, 1.6), frame)
	pk.tube(kit, "paint", Vector3(-1.6, wy + 0.5, 1.0), Vector3(-1.6, wy + 1.75, 1.0), 0.58, 0.55, 18, dark)
	pk.tube(kit, "paint", Vector3(-1.6, wy + 1.75, 1.0), Vector3(-1.6, wy + 1.95, 1.0), 0.55, 0.2, 18, dark)
	pk.tube(kit, "metal", Vector3(2.4, wy + 0.18, 1.5), Vector3(2.4, wy + 5.2, 1.5), 0.04, 0.03, 8, Color(0.7, 0.7, 0.7))
	for k in range(3):
		var ay: float = wy + 3.6 + 0.5 * k
		pk.beam(kit, "metal", Vector3(2.4, ay, 1.5), Vector3(2.4 + 0.5 - 0.1 * k, ay, 1.5), 0.02, 0.02, Color(0.7, 0.7, 0.7))
	var sp := Basis(Vector3.RIGHT, deg_to_rad(25.0))
	pk.box(kit, "steel", Transform3D(sp, Vector3(0.6, wy + 0.6, 0.8)), Vector3(1.6, 0.05, 1.0), Color(0.6, 0.6, 0.62))
	pk.box(kit, "glassdark", Transform3D(sp, Vector3(0.6, wy + 0.63, 0.8)), Vector3(1.5, 0.01, 0.9), Color(0.08, 0.12, 0.25))
	pk.beam(kit, "steel", Vector3(0.6, wy + 0.18, 1.1), Vector3(0.6, wy + 0.45, 1.1), 0.05, 0.05, frame)
	pk.box(kit, "steel", Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(2.7, wy + 0.5, -1.7)), Vector3(0.5, 0.35, 0.2), frame)
	pk.box(kit, "lamp", Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(2.7, wy + 0.47, -1.8)), Vector3(0.42, 0.27, 0.02), Color(1.0, 0.97, 0.9))
	# The air-conditioner on the side wall, its pipes up the wall.
	pk.block(kit, "paint", Vector3(hx + 0.02, 1.5, 0.3), Vector3(hx + 0.32, 2.1, 1.3), Color(0.92, 0.92, 0.9))
	pk.tube(kit, "matte", Vector3(hx + 0.031, 1.8, 0.8), Vector3(hx + 0.031, 1.8, 0.8), 0.22, 0.22, 16, Color(0.3, 0.3, 0.3))
	for k in range(6):
		pk.block(kit, "matte", Vector3(hx + 0.32, 1.55 + 0.09 * k, 0.4), Vector3(hx + 0.33, 1.6 + 0.09 * k, 1.2), Color(0.35, 0.35, 0.35))
	pk.tube(kit, "metal", Vector3(hx + 0.06, 2.1, 1.2), Vector3(hx + 0.06, 2.8, 1.2), 0.025, 0.025, 6, Color(0.85, 0.85, 0.85))
	# A bench and a bin under the canopy.
	pk.block(kit, "steel", Vector3(-2.6, fy + 0.42, -2.9), Vector3(-1.0, fy + 0.47, -2.5), Color(0.55, 0.4, 0.25))
	for bx in [-2.5, -1.1]:
		pk.block(kit, "steel", Vector3(bx - 0.03, fy, -2.85), Vector3(bx + 0.03, fy + 0.42, -2.55), frame)
	pk.tube(kit, "paint", Vector3(0.6, fy, -2.9), Vector3(0.6, fy + 0.8, -2.9), 0.25, 0.27, 14, Color(0.15, 0.4, 0.2))


## The in-pit crusher: a steel tower over the gyratory crusher, the dump pocket's concrete walls where the trucks back
## up (its open side toward -z, on a pad `pad_y` above the crusher's foot), the feeder and the conveyor's head below.
static func crusher(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var clad := Color(0.86, 0.84, 0.78)
	var trim := Color(0.94, 0.46, 0.10)
	var conc := Color(0.70, 0.68, 0.64)
	# The pocket: a concrete retaining block, the truck stops on its lip.
	pk.block(kit, "matte", Vector3(-12.0, 0.0, -2.0), Vector3(12.0, 6.0, 10.0), conc)
	pk.block(kit, "matte", Vector3(-12.0, 6.0, -2.4), Vector3(12.0, 7.2, -1.2), Color(0.85, 0.75, 0.2))
	for k in range(12):
		var sx: float = -11.0 + float(k) * 2.0
		pk.block(kit, "paint", Vector3(sx, 6.0, -2.45), Vector3(sx + 1.0, 7.2, -2.4), Color(0.1, 0.1, 0.1))
	# The crusher house: a tall clad box with a gabled roof and a band of windows.
	pk.block(kit, "paint", Vector3(-8.0, 6.0, -1.0), Vector3(8.0, 26.0, 12.0), clad)
	pk.block(kit, "paint", Vector3(-8.05, 22.0, -1.05), Vector3(8.05, 23.0, 12.05), trim)
	pk.extrude(kit, "paint", PackedVector2Array([Vector2(-8.3, 26.0), Vector2(8.3, 26.0), Vector2(0.0, 29.0)]), -1.2, 12.2, 0.05, clad.darkened(0.15))
	for wx in [-6.5, -3.5, -0.5, 2.5, 5.5]:
		pk.block(kit, "glassdark", Vector3(wx, 18.0, -1.04), Vector3(wx + 2.0, 20.5, -1.0), GLASS)
	labels.append(["TRITURADORA 1", Vector3(0, 24.4, -1.08), Vector3(0, 0, -1), 1.3, Color(0.12, 0.12, 0.12), 14.0])
	# The rock breaker's boom on the pocket's lip.
	pk.block(kit, "paint", Vector3(8.5, 7.2, 0.5), Vector3(10.5, 8.0, 2.5), MINE_YELLOW)
	pk.beam(kit, "paint", Vector3(9.5, 8.0, 1.5), Vector3(6.0, 13.0, -3.0), 0.6, 0.6, MINE_YELLOW)
	pk.beam(kit, "paint", Vector3(6.0, 13.0, -3.0), Vector3(3.5, 8.0, -1.0), 0.5, 0.5, MINE_YELLOW)
	# Stairs up the side.
	for k in range(10):
		var y0: float = 6.0 + float(k) * 1.8
		pk.block(kit, "steel", Vector3(8.0, y0, 2.0 + float(k % 2) * 6.0), Vector3(9.4, y0 + 0.12, 4.0 + float(k % 2) * 6.0), Color(0.25, 0.25, 0.25))
	pk.beam(kit, "paint", Vector3(9.4, 6.0, 2.0), Vector3(9.4, 24.0, 2.0), 0.12, 0.12, trim)


## A truck shop: a hangar of corrugated steel with three tall bays open toward -z (their insides in shadow), an office
## block along one end, a gantry crane's rail inside. About 66m by 34m by 24m (life size, not grown).
static func truck_shop(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var clad := Color(0.78, 0.80, 0.80)
	var trim := Color(0.94, 0.46, 0.10)
	var hw := 33.0
	var d := 34.0
	var h := 22.0
	# Walls: the back and the ends whole, the front between the three openings.
	pk.block(kit, "paint", Vector3(-hw, 0.0, d - 0.4), Vector3(hw, h, d), clad)
	for sx in [-1.0, 1.0]:
		pk.block(kit, "paint", Vector3(sx * hw - 0.2, 0.0, 0.0), Vector3(sx * hw + 0.2, h, d), clad)
	var door_h := 17.0
	# Four pillars between three 17m bays.
	for pr in [[-hw, -29.25], [-12.25, -8.5], [8.5, 12.25], [29.25, hw]]:
		pk.block(kit, "paint", Vector3(pr[0], 0.0, -0.2), Vector3(pr[1], h, 0.2), clad)
	pk.block(kit, "paint", Vector3(-hw, door_h, -0.2), Vector3(hw, h, 0.2), clad)
	pk.block(kit, "paint", Vector3(-hw - 0.1, h - 2.2, -0.3), Vector3(hw + 0.1, h - 1.2, -0.2), trim)
	# The dark inside of each bay (a back wall well in, the floor), a truck-shaped gloom.
	pk.block(kit, "matte", Vector3(-hw + 0.3, 0.02, 0.5), Vector3(hw - 0.3, 0.06, d - 0.5), Color(0.30, 0.29, 0.28))
	pk.block(kit, "matte", Vector3(-hw + 0.3, 0.0, d - 0.6), Vector3(hw - 0.3, h - 0.3, d - 0.45), Color(0.12, 0.12, 0.12))
	pk.block(kit, "matte", Vector3(-hw + 0.3, h - 0.6, 0.3), Vector3(hw - 0.3, h - 0.3, d - 0.3), Color(0.14, 0.14, 0.14))
	pk.block(kit, "steel", Vector3(-hw + 0.5, h - 3.0, 4.0), Vector3(hw - 0.5, h - 2.4, 4.6), MINE_YELLOW)
	pk.block(kit, "steel", Vector3(-hw + 0.5, h - 3.0, d - 6.0), Vector3(hw - 0.5, h - 2.4, d - 5.4), MINE_YELLOW)
	# Roof: a low pitch with a ridge vent.
	var ridge := Vector3(0.0, h + 2.6, d * 0.5)
	var roof_col: Color = clad.darkened(0.12)
	pk.quad(kit, "paint", [Vector3(-hw - 0.5, h, -0.5), Vector3(hw + 0.5, h, -0.5), Vector3(hw + 0.5, ridge.y, ridge.z), Vector3(-hw - 0.5, ridge.y, ridge.z)], Vector3(0, 1, -0.15).normalized(), roof_col)
	pk.quad(kit, "paint", [Vector3(-hw - 0.5, ridge.y, ridge.z), Vector3(hw + 0.5, ridge.y, ridge.z), Vector3(hw + 0.5, h, d + 0.5), Vector3(-hw - 0.5, h, d + 0.5)], Vector3(0, 1, 0.15).normalized(), roof_col)
	for sx in [-1.0, 1.0]:
		pk.tri(kit, "paint", Vector3(sx * hw, h, 0.0), Vector3(sx * hw, h, d), Vector3(sx * hw, ridge.y, ridge.z), Vector3(sx, 0, 0), Vector3(sx, 0, 0), Vector3(sx, 0, 0), clad, Vector3(sx, 0, 0))
	pk.block(kit, "paint", Vector3(-hw * 0.8, ridge.y - 0.2, ridge.z - 1.2), Vector3(hw * 0.8, ridge.y + 0.9, ridge.z + 1.2), clad.darkened(0.2))
	# Office block on the right end.
	pk.block(kit, "paint", Vector3(hw, 0.0, 2.0), Vector3(hw + 12.0, 7.0, 22.0), Color(0.92, 0.90, 0.86))
	for wz in [4.0, 8.0, 12.0, 16.0]:
		pk.block(kit, "glassdark", Vector3(hw + 12.0, 3.6, wz), Vector3(hw + 12.04, 5.6, wz + 2.6), GLASS)
	pk.block(kit, "glassdark", Vector3(hw + 1.0, 3.6, 1.96), Vector3(hw + 11.0, 5.6, 2.0), GLASS)
	labels.append(["TALLER DE CAMIONES", Vector3(0, h - 1.7, -0.32), Vector3(0, 0, -1), 1.4, Color(0.1, 0.1, 0.1), hw * 1.6])


## A conical stockpile of crushed ore, `r` across its foot, at the angle of repose, with the stacker's boom over it.
static func stockpile(pk: PropKit, kit: Dictionary, r: float) -> void:
	var h: float = r * tan(deg_to_rad(34.0))
	var rings := 8
	var segs := 36
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var prev: Array = []
	for i in range(rings + 1):
		var t: float = float(i) / float(rings)
		var ring: Array = []
		for j in range(segs):
			var a: float = TAU * float(j) / float(segs)
			var rr: float = r * (1.0 - t) * (1.0 + (rng.randf_range(-0.03, 0.03) if i > 0 and i < rings else 0.0))
			ring.append(Vector3(cos(a) * rr, h * t + (0.6 if i == rings else 0.0) - (0.3 if i == 0 else 0.0), sin(a) * rr))
		if not prev.is_empty():
			for j in range(segs):
				var a0: Vector3 = prev[j]
				var a1: Vector3 = prev[(j + 1) % segs]
				var b0: Vector3 = ring[j]
				var b1: Vector3 = ring[(j + 1) % segs]
				var n: Vector3 = (b1 - a0).cross(a1 - b0).normalized()
				if n.y < 0.0:
					n = -n
				var col := Color(0.62, 0.50, 0.42).darkened(0.05 * float(i % 2))
				pk.quad(kit, "rubble", [a0, a1, b1, b0], n, col)
		prev = ring
	# The stacker: a boom out over the apex on a tower at the pile's edge, its conveyor dropping ore on the top.
	var tower := Vector3(r + 6.0, 0.0, 0.0)
	pk.block(kit, "steel", tower + Vector3(-2.0, 0.0, -2.0), tower + Vector3(2.0, 1.0, 2.0), Color(0.6, 0.6, 0.58))
	for c in [Vector3(-1.4, 0, -1.4), Vector3(1.4, 0, -1.4), Vector3(1.4, 0, 1.4), Vector3(-1.4, 0, 1.4)]:
		pk.beam(kit, "paint", tower + c + Vector3(0, 1.0, 0), tower + c * 0.5 + Vector3(0, h + 6.0, 0), 0.4, 0.4, MINE_YELLOW)
	var head := Vector3(0.0, h + 5.0, 0.0)
	pk.beam(kit, "paint", tower + Vector3(0, h + 6.0, 0), head, 1.4, 1.8, MINE_YELLOW)
	pk.block(kit, "steel", head + Vector3(-1.2, -1.5, -1.2), head + Vector3(1.2, 0.8, 1.2), Color(0.3, 0.3, 0.3))


## A conveyor along `pts` (the belt's line, life size): a belt in a troughed frame on trestles every 12m down to the
## ground (`ground`: Callable(x, z) -> y in the kit's frame, or none for y = 0), and over the segments listed in
## `bridges` (indices: segment i runs pts[i] to pts[i + 1]) a covered truss gallery instead, on towers at its ends.
static func conveyor_run(pk: PropKit, kit: Dictionary, pts: Array, bridges: Array, ground := Callable()) -> void:
	var frame_col := Color(0.42, 0.44, 0.46)
	var gal_col := Color(0.86, 0.84, 0.78)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var dir: Vector3 = (b - a).normalized()
		var side: Vector3 = Vector3(dir.z, 0.0, -dir.x).normalized()
		var length: float = a.distance_to(b)
		# The belt and its ore, the stringers either side.
		pk.beam(kit, "rubber", a + Vector3.UP * 0.05, b + Vector3.UP * 0.05, 1.6, 0.08, Color(0.08, 0.08, 0.08), side)
		pk.beam(kit, "rubble", a + Vector3.UP * 0.22, b + Vector3.UP * 0.22, 1.0, 0.25, Color(0.62, 0.48, 0.38), side)
		for sd in [-1.0, 1.0]:
			pk.beam(kit, "steel", a + side * sd * 1.0, b + side * sd * 1.0, 0.18, 0.5, frame_col, side)
		if bridges.has(i):
			_gallery(pk, kit, a, b, side, gal_col)
			for e in [a, b]:
				_tower(pk, kit, e, side, ground)
			continue
		var n: int = maxi(int(floor(length / 12.0)), 1)
		for k in range(n + 1):
			var p: Vector3 = a.lerp(b, float(k) / float(n))
			if (k == 0 and i > 0) or (k == n and bridges.has(i + 1)):
				continue
			var gy: float = ground.call(p.x, p.z) if ground.is_valid() else 0.0
			for sd in [-1.0, 1.0]:
				var top: Vector3 = p + side * sd * 1.0 - Vector3.UP * 0.25
				pk.beam(kit, "steel", Vector3(top.x, gy, top.z) + side * sd * 0.3, top, 0.22, 0.22, frame_col, dir)
			pk.beam(kit, "steel", p - side * 1.1 - Vector3.UP * 0.3, p + side * 1.1 - Vector3.UP * 0.3, 0.2, 0.2, frame_col)


## A covered gallery over a conveyor span: Warren trusses each side, a roof, a floor walkway.
static func _gallery(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, side: Vector3, col: Color) -> void:
	var length: float = a.distance_to(b)
	var bays: int = maxi(int(round(length / 4.0)), 2)
	var lo := Vector3.UP * -0.6
	var hi := Vector3.UP * 2.6
	for sd in [-1.0, 1.0]:
		var o: Vector3 = side * sd * 1.9
		pk.beam(kit, "paint", a + o + lo, b + o + lo, 0.3, 0.3, col)
		pk.beam(kit, "paint", a + o + hi, b + o + hi, 0.3, 0.3, col)
		for k in range(bays):
			var p0: Vector3 = a.lerp(b, float(k) / float(bays))
			var p1: Vector3 = a.lerp(b, float(k + 1) / float(bays))
			if k % 2 == 0:
				pk.beam(kit, "paint", p0 + o + lo, p1 + o + hi, 0.2, 0.2, col)
			else:
				pk.beam(kit, "paint", p0 + o + hi, p1 + o + lo, 0.2, 0.2, col)
			pk.beam(kit, "paint", p0 + o + lo, p0 + o + hi, 0.18, 0.18, col)
	var dir: Vector3 = (b - a).normalized()
	# Roof sheet and the floor under the belt, both a little wider than the trusses.
	pk.beam(kit, "paint", a + hi + Vector3.UP * 0.25, b + hi + Vector3.UP * 0.25, 4.3, 0.12, col.darkened(0.1), side)
	pk.beam(kit, "steel", a + lo, b + lo, 3.8, 0.12, Color(0.35, 0.36, 0.37), side)
	# Corrugated side sheets over the upper half (the truss shows below them).
	for sd in [-1.0, 1.0]:
		var o2: Vector3 = side * sd * 1.95
		pk.beam(kit, "paint", a + o2 + Vector3.UP * 1.6, b + o2 + Vector3.UP * 1.6, 0.05, 2.0, col.darkened(0.05), side)


## A conveyor's support tower down to the ground at `p`: four legs, braced, a head frame.
static func _tower(pk: PropKit, kit: Dictionary, p: Vector3, side: Vector3, ground: Callable) -> void:
	var gy: float = ground.call(p.x, p.z) if ground.is_valid() else 0.0
	var dir: Vector3 = side.cross(Vector3.UP).normalized()
	var col := Color(0.42, 0.44, 0.46)
	var feet: Array = []
	for sd in [-1.0, 1.0]:
		for fd in [-1.0, 1.0]:
			feet.append(p + side * sd * 2.4 + dir * fd * 1.6)
	for f in feet:
		var top: Vector3 = f - Vector3.UP * 0.7
		pk.beam(kit, "paint", Vector3(f.x, gy, f.z), top, 0.4, 0.4, col)
		pk.block(kit, "matte", Vector3(f.x - 0.6, gy - 0.3, f.z - 0.6), Vector3(f.x + 0.6, gy + 0.4, f.z + 0.6), Color(0.66, 0.64, 0.6))
	var h: float = p.y - 0.7 - gy
	var levels: int = maxi(int(h / 5.0), 1)
	for k in range(1, levels + 1):
		var y: float = gy + h * float(k) / float(levels + 1)
		for e in [[0, 1], [1, 3], [3, 2], [2, 0]]:
			var a: Vector3 = feet[e[0]]
			var b: Vector3 = feet[e[1]]
			pk.beam(kit, "paint", Vector3(a.x, y, a.z), Vector3(b.x, y, b.z), 0.2, 0.2, col)


## A heap of blasted rock at the foot of the pit's face (centre on the floor, half sizes, height), for the shovel.
static func muck_pile(pk: PropKit, kit: Dictionary, half: Vector2, h: float, seed_v: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_v * 1000.0) + 91
	var nx := 22
	var nz := 14
	var grid: Array = []
	for i in range(nx + 1):
		var row: Array = []
		for j in range(nz + 1):
			var u: float = float(i) / float(nx) * 2.0 - 1.0
			var v: float = float(j) / float(nz) * 2.0 - 1.0
			# Steep toward the face (+z), its slope of repose toward the shovel.
			var dome: float = maxf(1.0 - pow(absf(u), 3.0) - pow(absf(v - 0.25) / 1.25, 2.0), 0.0)
			var y: float = h * pow(dome, 0.7) + (rng.randf_range(-0.25, 0.25) if dome > 0.04 else -0.3)
			row.append(Vector3(u * half.x, y, v * half.y))
		grid.append(row)
	for i in range(nx):
		for j in range(nz):
			var p00: Vector3 = grid[i][j]
			var p10: Vector3 = grid[i + 1][j]
			var p11: Vector3 = grid[i + 1][j + 1]
			var p01: Vector3 = grid[i][j + 1]
			var n: Vector3 = (p11 - p00).cross(p10 - p01).normalized()
			if n.y < 0.0:
				n = -n
			pk.quad(kit, "rubble", [p00, p10, p11, p01], n, Color(0.70, 0.60, 0.52).darkened(rng.randf_range(0.0, 0.12)))


## A thickener: a round concrete tank `r` in radius with its walkway bridge to the middle, the rake's drive there,
## the slurry's surface inside.
static func thickener(pk: PropKit, kit: Dictionary, r: float) -> void:
	var conc := Color(0.74, 0.72, 0.68)
	pk.tube(kit, "matte", Vector3(0, 0, 0), Vector3(0, 4.2, 0), r, r, 40, conc, false)
	pk.tube(kit, "matte", Vector3(0, 0, 0), Vector3(0, 4.0, 0), r - 0.4, r - 0.4, 40, conc.darkened(0.2), false)
	pk.lathe(kit, "matte", Vector3.ZERO, [Vector2(r - 0.45, 3.5), Vector2(0.0, 3.6)], 40, Color(0.36, 0.40, 0.38))
	pk.lathe(kit, "matte", Vector3.ZERO, [Vector2(r + 0.05, 4.2), Vector2(r - 0.45, 4.2)], 40, conc.lightened(0.1))
	pk.beam(kit, "steel", Vector3(-r - 1.0, 4.6, 0), Vector3(0, 4.6, 0), 1.4, 0.6, Color(0.42, 0.44, 0.46))
	_railing(pk, kit, [Vector3(-r - 1.0, 4.9, 0.7), Vector3(0, 4.9, 0.7)], 1.0, MINE_YELLOW)
	pk.tube(kit, "paint", Vector3(0, 3.8, 0), Vector3(0, 6.2, 0), 1.5, 1.5, 16, Color(0.20, 0.42, 0.68))
	pk.tube(kit, "paint", Vector3(0, 6.2, 0), Vector3(0, 7.0, 0), 0.9, 0.6, 12, Color(0.85, 0.85, 0.82))


## A grandstand `length` long: seven tiers of benches rising away from the front (toward +z), on a steel frame, under
## a roof on posts at the back. `spots` receives a seat for a spectator every metre or so: [position, facing].
static func grandstand(pk: PropKit, kit: Dictionary, length: float, spots: Array) -> void:
	var tiers := 7
	var rise := 0.45
	var run := 0.85
	var frame := Color(0.40, 0.42, 0.44)
	var seat := Color(0.94, 0.46, 0.10)
	var hl: float = length * 0.5
	for t in range(tiers):
		var z0: float = float(t) * run
		var y: float = 0.6 + float(t) * rise
		pk.block(kit, "matte", Vector3(-hl, y - 0.12, z0), Vector3(hl, y, z0 + run), Color(0.72, 0.70, 0.66))
		pk.block(kit, "matte", Vector3(-hl, y - rise - 0.12, z0), Vector3(hl, y - 0.12, z0 + 0.06), Color(0.66, 0.64, 0.6))
		pk.block(kit, "paint", Vector3(-hl + 0.3, y, z0 + 0.45), Vector3(hl - 0.3, y + 0.42, z0 + 0.8), seat if t % 2 == 0 else seat.darkened(0.15))
		var n: int = int(length / 0.9)
		for k in range(n):
			spots.append([Vector3(-hl + 0.6 + float(k) * (length - 1.2) / float(maxi(n - 1, 1)), y + 0.42, z0 + 0.62), Vector3(0, 0, -1)])
	var back_z: float = float(tiers) * run
	var top_y: float = 0.6 + float(tiers) * rise
	pk.block(kit, "paint", Vector3(-hl, 0.0, back_z), Vector3(hl, top_y + 3.6, back_z + 0.25), frame.lightened(0.3))
	var bays: int = int(length / 6.0)
	for k in range(bays + 1):
		var x: float = -hl + float(k) * length / float(bays)
		pk.beam(kit, "steel", Vector3(x, 0.0, back_z - 0.2), Vector3(x, top_y + 3.6, back_z - 0.2), 0.3, 0.3, frame)
		pk.beam(kit, "steel", Vector3(x, top_y + 3.6, back_z), Vector3(x, top_y + 2.9, -0.6), 0.25, 0.4, frame)
		pk.beam(kit, "steel", Vector3(x, 0.0, 0.1), Vector3(x, 0.6, 0.1), 0.25, 0.25, frame)
	pk.quad(kit, "paint", [Vector3(-hl - 0.4, top_y + 3.65, back_z + 0.3), Vector3(hl + 0.4, top_y + 3.65, back_z + 0.3),
			Vector3(hl + 0.4, top_y + 2.95, -0.8), Vector3(-hl - 0.4, top_y + 2.95, -0.8)], Vector3(0, 1, 0.1).normalized(), Color(0.86, 0.86, 0.84))
	pk.quad(kit, "paint", [Vector3(-hl - 0.4, top_y + 2.95, -0.8), Vector3(hl + 0.4, top_y + 2.95, -0.8),
			Vector3(hl + 0.4, top_y + 3.65, back_z + 0.3), Vector3(-hl - 0.4, top_y + 3.65, back_z + 0.3)], Vector3(0, -1, -0.1).normalized(), Color(0.5, 0.5, 0.5))
	pk.block(kit, "paint", Vector3(-hl - 0.4, top_y + 2.6, -0.85), Vector3(hl + 0.4, top_y + 3.3, -0.7), seat)
