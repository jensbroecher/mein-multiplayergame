# SamuraiBuilder.gd
#
# The Samurai: a 1970s Japanese fastback coupé in "kaido racer" trim, an original design with a made-up
# name. A long flat bonnet, the cabin set well back, a fastback falling to a short deck with a ducktail;
# quad round headlamps in a black grille with a gold crest of crossed blades, quad round taillamps, thin
# chrome blade bumpers, chrome drip rails and window surrounds, a louvred rear window; the street-racing
# kit bolted on: black overfenders riveted round every arch, a long chin spoiler ("deppa") out ahead of
# the nose with an oil cooler behind it, mirrors on the front fenders, and two chrome exhausts that rise
# behind the tail like spears (takeyari), splaying apart in a V like the horns on a samurai's helmet.
# Low, wide tyres on deep-dish eight-spoke rims.
#
# What sets it apart from the fleet: no other car is a road coupé of this era (the Classics are a hot
# rod, a Grand Prix car and a bubble car); the Interceptor's flares are painted on a hatchback under a
# big wing, these are black and riveted on a long-bonnet fastback with no wing; and nothing else has the
# upswept pipes, the chin spoiler or fender mirrors.
#
# The shell, flares, wheel parts and detail map come from CarDesign.gd. The section is the Interceptor's
# (a real greenhouse corner above the side, its parameters keyed together in KEYS, the pillars on that
# corner in the detail map via _upper_s); over the bonnet and the deck the same corner is the panels'
# rolled edge. The arches are cut by lifting the shell's bottom over each wheel in a squared arch
# (_bot_knots) and the overfenders sweep along that outline (build_fender with a box section).
extends "res://CarDesign.gd"

# Wheels: low, wide tyres pushed out to the overfenders.
const WHEEL_X := 0.515
const AXLE_F := -0.720
const AXLE_R := 0.660
const HUB_Y := 0.200

# The section along the car: z; the top of the centre line; belt (the top of the vertical side); px,
# edge (the greenhouse corner: the A-pillar over the windscreen, the roof rail over the cabin, the
# bonnet's and the deck's rolled edges); fillet (how far the corner is rounded off along each side of
# it); bow (the side glass bulging out). The belt rises over the front wheel (the overfender's top must
# stay under it) and kicks up over the rear wheel; the deck ends in a ducktail.
const KEYS := [
	# z       top    belt   px     edge   fillet bow
	[-1.220, 0.340, 0.310, 0.300, 0.330, 0.020, 0.000],
	[-1.190, 0.425, 0.398, 0.420, 0.414, 0.028, 0.000],
	[-1.150, 0.452, 0.430, 0.448, 0.442, 0.032, 0.000],
	[-1.100, 0.466, 0.446, 0.460, 0.456, 0.034, 0.000],
	[-1.000, 0.478, 0.460, 0.464, 0.468, 0.034, 0.000],
	[-0.860, 0.490, 0.473, 0.462, 0.481, 0.034, 0.000],
	[-0.720, 0.498, 0.480, 0.458, 0.489, 0.034, 0.000],
	[-0.560, 0.503, 0.482, 0.452, 0.493, 0.033, 0.000],
	[-0.430, 0.506, 0.483, 0.445, 0.496, 0.032, 0.000],
	[-0.330, 0.510, 0.484, 0.435, 0.499, 0.030, 0.002],
	[-0.250, 0.545, 0.485, 0.415, 0.529, 0.030, 0.004],
	[-0.150, 0.600, 0.487, 0.400, 0.584, 0.030, 0.006],
	[-0.050, 0.660, 0.489, 0.392, 0.644, 0.030, 0.008],
	[0.020, 0.695, 0.491, 0.388, 0.679, 0.030, 0.008],
	[0.100, 0.708, 0.493, 0.386, 0.691, 0.030, 0.008],
	[0.250, 0.705, 0.497, 0.386, 0.689, 0.030, 0.008],
	[0.350, 0.684, 0.502, 0.388, 0.668, 0.032, 0.007],
	[0.500, 0.640, 0.508, 0.395, 0.624, 0.034, 0.005],
	[0.650, 0.597, 0.512, 0.405, 0.581, 0.036, 0.003],
	[0.780, 0.564, 0.512, 0.420, 0.550, 0.036, 0.002],
	[0.900, 0.552, 0.509, 0.438, 0.540, 0.036, 0.000],
	[0.980, 0.550, 0.505, 0.446, 0.539, 0.034, 0.000],
	[1.028, 0.576, 0.499, 0.448, 0.563, 0.024, 0.000],
	[1.055, 0.556, 0.484, 0.440, 0.545, 0.024, 0.000],
	[1.080, 0.500, 0.450, 0.418, 0.492, 0.028, 0.000],
	[1.100, 0.430, 0.400, 0.380, 0.425, 0.024, 0.000],
]
const KEY_NAMES := ["top", "belt", "px", "edge", "fillet", "bow"]
const W_KNOTS := [[-1.22, 0.36], [-1.20, 0.43], [-1.17, 0.465], [-1.12, 0.485], [-1.05, 0.495], [-0.95, 0.500],
	[-0.60, 0.500], [-0.40, 0.495], [0.20, 0.495], [0.45, 0.503], [0.70, 0.505], [0.95, 0.500], [1.03, 0.492],
	[1.07, 0.475], [1.10, 0.43]]

# The bottom of the shell: the front valance, the sills, the rear valance; squared arches lifted over
# each wheel (half-length ARCH_RZ, from ARCH_CY up to ARCH_CY + ARCH_RY, superellipse ARCH_E).
const NOSE_BOT := 0.150
const SILL_Y := 0.140
const TAIL_BOT := 0.200
const ARCH_RZ := 0.258
const ARCH_CY := 0.170
const ARCH_RY := 0.262
const ARCH_E := 2.8
# The overfenders: out to FLARE_OUT, their outer face *_DEPTH deep round the arch, riveted every
# RIVET_STEP or so.
const FLARE_OUT := 0.648
const FRONT_FLARE_DEPTH := 0.042
const REAR_FLARE_DEPTH := 0.046
const RIVETS := 9
# The glass round the greenhouse's corner (as on the Interceptor): the side glass stops PILLAR_PAD short
# of the corner's rounding, the windscreen and rear glass start PILLAR_PAD inboard of it. The windscreen
# runs from the cowl to the header (WS_Z), the rear glass down the fastback (RG_Z), under the louvres.
const PILLAR_PAD := 0.004
const WS_Z := Vector2(-0.325, 0.015)
const RG_Z := Vector2(0.300, 0.770)
const B_Z := 0.285                        # the chrome divider between the door glass and the quarter light
const DOOR_Z := Vector2(-0.425, 0.315)    # the door's shut lines
const LOUVRE_Z := Vector2(0.350, 0.740)
const LOUVRE_X := 0.330
const PIPE_R := 0.022                     # the takeyari exhausts' radius

# Tyres: a low, wide street tyre (half its profile, bead to tread centre), two grooves round the tread.
const TYRE_HALF := [[-0.110, 0.146], [-0.116, 0.153], [-0.119, 0.165], [-0.119, 0.180], [-0.115, 0.191],
	[-0.106, 0.1975], [-0.090, 0.1995], [-0.062, 0.2000], [-0.057, 0.1968], [-0.044, 0.1968], [-0.039, 0.2000],
	[0.0, 0.2000]]

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.20, 0.20, 0.21)
const C_FENDER := Color(0.045, 0.045, 0.05)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_MESH := Color(0.17, 0.17, 0.18)
const C_STEEL := Color(0.13, 0.13, 0.14)
const C_ALLOY := Color(0.78, 0.79, 0.81)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.62, 0.62, 0.64)
const C_TAILLAMP := Color(0.85, 0.06, 0.04)
const C_AMBER := Color(0.95, 0.55, 0.08)
const C_REVERSE := Color(0.86, 0.86, 0.83)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame. The belt here is
## the two-tone's split, low on the side (a 1970s lower-body two-tone), not the window line.
const PAINT_LAYOUT := {
	"nose_z": -1.22, "tail_z": 1.10, "belt_y": 0.345, "side_x": 0.495,
	"door_z": -0.06, "door_y": 0.315, "roundel_r": 0.072,
	"hood_z": -0.90, "hood_r": 0.075, "stripe_w": 0.07, "stripe_gap": 0.03,
}
const ANTENNA_POS := Vector3(0.18, 0.699, 0.22)
var _curve_cache := {}                    # z -> the upper curve's samples, for _upper_s()

const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.220
	nose_cap = 0.055
	nose_cap_y = 0.300
	nose_cap_exp = Vector2(4.5, 3.0)
	tail_tip = 1.100
	tail_cap = 0.045
	tail_cap_y = 0.340
	tail_cap_exp = Vector2(3.5, 2.5)
	# Bottom, bottom corner, side; then the glass, the corner's rounding, the crowned top.
	segment_counts = [2, 3, 4, 7, 6, 9]
	half_ring = 31
	bottom_radius = 0.022
	fender_mat = CB.M_DARK
	fender_col = C_FENDER
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	setup_shell(knots)


## The shell's bottom: flat along the valances and sills, stepping up into a squared arch over each
## wheel.
static func _bot_knots() -> Array:
	var k := [[-1.22, NOSE_BOT + 0.015], [-1.10, NOSE_BOT]]
	for arch in [[AXLE_F, NOSE_BOT, SILL_Y], [AXLE_R, SILL_Y, TAIL_BOT]]:
		var az: float = arch[0]
		k.append([az - ARCH_RZ - 0.012, arch[1]])
		for s in 21:
			var t: float = s / 10.0 - 1.0
			k.append([az + ARCH_RZ * t, ARCH_CY + ARCH_RY * pow(maxf(1.0 - pow(absf(t), ARCH_E), 0.0), 1.0 / ARCH_E)])
		k.append([az + ARCH_RZ + 0.012, arch[2]])
	k.append([1.10, TAIL_BOT + 0.01])
	return k


## The greenhouse corner at z: [the sharp corner K, where its rounding starts on the glass (T1),
## where it ends on the top (T2), the top's crown].
func _corner(z: float, w: float, belt: float, top: float) -> Array:
	var px: float = minf(prof["px"].at(z), w - 0.005)
	var edge: float = clampf(prof["edge"].at(z), belt + 0.003, top)
	var crown: float = top - edge
	var k := Vector2(px, edge)
	var s := Vector2(w, belt)
	var f: float = prof["fillet"].at(z)
	var t1: Vector2 = k + (s - k).normalized() * minf(f, 0.45 * s.distance_to(k))
	var tx: float = minf(f, 0.45 * px)
	return [k, t1, Vector2(px - tx, _crown_y(px - tx, k, crown)), crown]


## The crowned top's height at x: level at the centre line, down to the corner's height at its x.
static func _crown_y(x: float, k: Vector2, crown: float) -> float:
	return k.y + crown * (1.0 - (x / k.x) * (x / k.x))


## Above the side, as segments with fixed point counts (segment_counts): the glass leaning in from the
## side's top to the corner's rounding, bowed out a little; the rounding (a quadratic through the sharp
## corner, so it meets both tangentially); the crowned top across to the centre line.
func _upper_segments(z: float, w: float, belt: float, top: float) -> Array:
	var c: Array = _corner(z, w, belt, top)
	var k: Vector2 = c[0]
	var t1: Vector2 = c[1]
	var t2: Vector2 = c[2]
	var s := Vector2(w, belt)
	var dir: Vector2 = (t1 - s).normalized()
	var mid: Vector2 = (s + t1) * 0.5 + Vector2(dir.y, -dir.x) * prof["bow"].at(z)
	var glass := PackedVector2Array()
	var rounding := PackedVector2Array()
	for i in 13:
		var u: float = i / 12.0
		glass.append(s.lerp(mid, u).lerp(mid.lerp(t1, u), u))
		rounding.append(t1.lerp(k, u).lerp(k.lerp(t2, u), u))
	var crowned := PackedVector2Array()
	for i in 17:
		var x: float = t2.x * (1.0 - i / 16.0)
		crowned.append(Vector2(x, _crown_y(x, k, c[3])))
	return [glass, rounding, crowned]


## The overfender's section: a lip, a flat outer face standing well proud of the body, a tight
## shoulder, a flat top running back into the body side; underneath, a flat liner in to the body.
func _fender_section(xo: float, x_in: float, d: float) -> Array:
	var w: float = x_in + 0.035
	return [
		[Vector2(xo - 0.010, 0.0), Vector2(xo - 0.001, 0.004), Vector2(xo + 0.001, 0.014), Vector2(xo + 0.001, 0.72 * d),
			Vector2(xo - 0.003, 0.92 * d), Vector2(xo - 0.013, d), Vector2(w + 0.004, d + 0.004), Vector2(x_in, d + 0.004)],
		[Vector2(xo - 0.010, 0.0), Vector2(w + 0.002, 0.0)],
	]


## A wheel arch's outline as an overfender's lip: the shell's bottom from the sill at the door end
## round over the wheel to the outer end, as 18 points spaced along it.
func _arch_lip(z_door: float, z_end: float) -> Array:
	var dense := PackedVector2Array()
	for k in 241:
		var z: float = lerpf(z_door, z_end, k / 240.0)
		dense.append(Vector2(z, prof["bot"].at(z)))
	var pts: PackedVector2Array = CB.resample(dense, 18, 0.0)
	var lip := []
	for p in pts:
		lip.append([p.x, p.y])
	return lip


## Body mesh: shell, overfenders and their rivets, lamps, bumpers, the street-racing kit and the
## running gear seen in the arches.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	var front_lip: Array = _arch_lip(AXLE_F + ARCH_RZ + 0.012, AXLE_F - ARCH_RZ - 0.012)
	var rear_lip: Array = _arch_lip(AXLE_R - ARCH_RZ - 0.012, AXLE_R + ARCH_RZ + 0.012)
	build_fender(b, front_lip, AXLE_F, HUB_Y, FLARE_OUT, FRONT_FLARE_DEPTH, 0.0)
	build_fender(b, rear_lip, AXLE_R, HUB_Y, FLARE_OUT, REAR_FLARE_DEPTH, 0.0)
	_rivets(b, front_lip, AXLE_F, FRONT_FLARE_DEPTH)
	_rivets(b, rear_lip, AXLE_R, REAR_FLARE_DEPTH)
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Chrome rivets round an overfender's outer face, evenly along its lip.
func _rivets(b, lip: Array, hub_z: float, depth: float) -> void:
	var spine: PackedVector2Array = _spine(lip, 40)
	var acc := PackedFloat32Array([0.0])
	for k in range(1, spine.size()):
		acc.append(acc[k - 1] + spine[k].distance_to(spine[k - 1]))
	var total: float = acc[acc.size() - 1]
	var seg := 1
	for r in RIVETS:
		var target: float = total * lerpf(0.05, 0.95, float(r) / (RIVETS - 1))
		while seg < acc.size() - 1 and acc[seg] < target:
			seg += 1
		var t: float = (target - acc[seg - 1]) / maxf(acc[seg] - acc[seg - 1], 1e-9)
		var p: Vector2 = spine[seg - 1].lerp(spine[seg], t)
		var tan: Vector2 = (spine[seg] - spine[seg - 1]).normalized()
		var n2 := Vector2(tan.y, -tan.x)
		if n2.dot(p - Vector2(hub_z, HUB_Y)) < 0.0:
			n2 = -n2
		var c := Vector3(FLARE_OUT + 0.001, p.y + n2.y * depth * 0.42, p.x + n2.x * depth * 0.42)
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.lathe(c, Vector3.RIGHT, PackedVector2Array([Vector2(-0.001, 0.0062), Vector2(0.0015, 0.0058), Vector2(0.0032, 0.004),
				Vector2(0.0042, 0.0)]), 8, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, c - Vector3(0.004, 0.0, 0.0))


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Arch liners: dark walls inside each arch (clear of the front tyre at full lock).
	for arch in [[AXLE_F, 0.29], [AXLE_R, 0.37]]:
		b.rbox(Transform3D(Basis(), Vector3(arch[1], 0.30, arch[0])), Vector3(0.004, 0.13, ARCH_RZ), 0.003, 1, CB.M_DARK,
				C_DARKER)
	# Quad headlamps: a black housing on the nose either side of the grille, two round lamps in it.
	var hl: Array = face_frame(0.315, 0.335, true)
	var hb: Basis = facing(hl[1])
	b.rbox(Transform3D(hb, hl[0]), Vector3(0.118, 0.050, 0.012), 0.018, 2, CB.M_DARK, C_DARKER)
	for dx in [-0.060, 0.060]:
		round_lamp(b, hl[0] + hb.x * dx + hb.z * 0.010, hl[1], 0.040, CB.M_HEADLAMP, Color(1, 1, 1))
	# Indicator in the valance under the outer lamp, a side marker on the front fender's flank.
	var ind: Array = face_frame(0.37, 0.248, true)
	b.rbox(Transform3D(facing(ind[1]), ind[0]), Vector3(0.042, 0.014, 0.008), 0.006, 1, CB.M_TAILLAMP, C_AMBER)
	b.rbox(Transform3D(Basis(), Vector3(prof["w"].at(-1.06) + 0.001, 0.37, -1.06)), Vector3(0.004, 0.011, 0.024), 0.003, 1,
			CB.M_TAILLAMP, C_AMBER)
	b.rbox(Transform3D(Basis(), Vector3(prof["w"].at(1.02) + 0.001, 0.38, 1.02)), Vector3(0.004, 0.011, 0.020), 0.003, 1,
			CB.M_TAILLAMP, C_TAILLAMP)
	# Quad taillamps on a black panel across each side of the tail, a reversing lamp low in the middle.
	var tl: Array = face_frame(0.300, 0.430, false)
	var tb: Basis = facing(tl[1])
	b.rbox(Transform3D(tb, tl[0]), Vector3(0.122, 0.048, 0.010), 0.016, 2, CB.M_DARK, C_DARKER)
	for dx in [-0.062, 0.062]:
		round_lamp(b, tl[0] + tb.x * dx + tb.z * 0.008, tl[1], 0.037, CB.M_TAILLAMP, C_TAILLAMP)
	var rv: Array = face_frame(0.12, 0.318, false)
	b.rbox(Transform3D(facing(rv[1]), rv[0]), Vector3(0.030, 0.012, 0.008), 0.005, 1, CB.M_TAILLAMP, C_REVERSE)
	# Fender mirror: a stalk from the bonnet's shoulder, a black teardrop head, its glass toward the driver.
	var mz := -0.86
	var mx := 0.425
	var my: float = top_y(mx, mz)
	var head := Vector3(mx + 0.018, my + 0.050, mz + 0.008)
	b.tube(PackedVector3Array([Vector3(mx, my - 0.006, mz), Vector3(mx + 0.006, my + 0.022, mz + 0.002), head - Vector3(0.0, 0.010, 0.0)]),
			0.0045, 6, CB.M_CHROME, C_CHROME, false, true)
	b.rbox(Transform3D(Basis(), Vector3(mx, my - 0.002, mz)), Vector3(0.012, 0.004, 0.016), 0.003, 1, CB.M_DARK, C_DARK)
	var mb := Basis(Vector3.UP, -0.22)
	b.rbox(Transform3D(mb, head), Vector3(0.026, 0.017, 0.012), 0.011, 2, CB.M_DARK, C_DARK)
	b.rbox(Transform3D(mb, head + mb.z * 0.011), Vector3(0.020, 0.012, 0.002), 0.002, 1, CB.M_CHROME, C_CHROME)
	# Door handle, chrome.
	b.rbox(Transform3D(Basis(), Vector3(prof["w"].at(0.20) + 0.003, 0.452, 0.20)), Vector3(0.005, 0.007, 0.032), 0.004, 1,
			CB.M_CHROME, C_CHROME)
	# Bonnet pin (mirrored: one each side).
	var pz := -1.10
	b.disc(Vector3(0.30, top_y(0.30, pz) + 0.002, pz), Vector3.UP, 0.011, 0.0, 12, CB.M_CHROME, C_CHROME)
	# Chrome drip rail along the greenhouse's corner, from the A-pillar's foot over the roof and down the
	# fastback's sail.
	var rail := PackedVector3Array()
	for k in 31:
		var z: float = lerpf(-0.30, 0.66, k / 30.0)
		var c: Array = _corner(z, prof["w"].at(z), prof["belt"].at(z), prof["top"].at(z))
		var kk: Vector2 = c[0]
		var t1: Vector2 = c[1]
		var t2: Vector2 = c[2]
		var on: Vector2 = t1 * 0.25 + kk * 0.5 + t2 * 0.25
		var out: Vector2 = (kk - (t1 + t2) * 0.5).normalized()
		var q: Vector2 = on + out * 0.0035
		rail.append(Vector3(q.x, q.y, z))
	b.tube(rail, 0.0045, 6, CB.M_CHROME, C_CHROME, true, true)
	# Running gear in each arch: lower arms, hub carrier, a coil-over, the caliper on the disc.
	for az in [AXLE_F, AXLE_R]:
		for dz in [-0.08, 0.08]:
			b.tube(PackedVector3Array([Vector3(0.20, 0.185, az + dz), Vector3(0.43, 0.160, az)]), 0.011, 8, CB.M_DARK,
					C_STEEL, true, true)
		b.rbox(Transform3D(Basis(), Vector3(0.45, HUB_Y, az)), Vector3(0.016, 0.055, 0.03), 0.008, 1, CB.M_DARK, C_STEEL)
		coilover(b, Vector3(0.345, 0.185, az), Vector3(0.320, 0.400, az + 0.02), 0.014, 0.024, 5.0, C_ALLOY, C_ALLOY_DARK,
				C_CHROME, C_DARK)
		var ca: float = 0.75
		var cp := Vector3(WHEEL_X - 0.030, HUB_Y + cos(ca) * 0.090, az + sin(ca) * 0.090)
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -ca), cp), Vector3(0.016, 0.020, 0.036), 0.007, 2, CB.M_ANODISED,
				Color(1, 1, 1))
	# Takeyari: an exhaust from under the car that bends up behind the tail and rises high over the deck,
	# splaying out a little, chrome, a rolled lip at its open end.
	var pipe: PackedVector3Array = _rounded([Vector3(0.16, 0.118, 0.80), Vector3(0.16, 0.118, 1.10),
			Vector3(0.40, 0.74, 1.46)], 0.09, 6)
	b.tube(pipe, PIPE_R, 14, CB.M_CHROME, C_CHROME, true, false)
	var tip: Vector3 = pipe[pipe.size() - 1]
	var ax: Vector3 = (tip - pipe[pipe.size() - 2]).normalized()
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(tip, ax, PackedVector2Array([Vector2(-0.004, PIPE_R + 0.0005), Vector2(0.002, PIPE_R + 0.0028),
			Vector2(0.006, PIPE_R + 0.0018), Vector2(0.007, PIPE_R - 0.0035)]), 14, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, tip - ax * 0.02)
	b.disc(tip + ax * 0.002, ax, PIPE_R - 0.0033, 0.0, 14, CB.M_DARK, C_DARKER)
	# A hanger from the rear valance to the pipe where it turns up.
	b.tube(PackedVector3Array([Vector3(0.16, 0.205, 1.04), Vector3(0.16, 0.138, 1.07)]), 0.006, 6, CB.M_DARK, C_DARK, false,
			false)


func _centre_parts(b) -> void:
	# The grille between the headlamps: black, five thin bars, the crest in its middle.
	var gr: Array = face_frame(0.0, 0.335, true)
	var gb: Basis = facing(gr[1])
	b.rbox(Transform3D(gb, gr[0]), Vector3(0.190, 0.046, 0.010), 0.012, 2, CB.M_DARK, C_DARKER)
	for k in 5:
		bar(b, gr[0] + gb.y * (-0.032 + 0.016 * k) + gb.z * 0.010, Vector3(0.180, 0.0025, 0.003), CB.M_DARK, C_MESH)
	_crest(b, gr[0] + gb.z * 0.016, gb)
	# Front bumper: a thin chrome blade across the nose and round its corners, a black rubber strip on it.
	var blade := PackedVector2Array([Vector2(-0.020, 0.0), Vector2(0.020, 0.0), Vector2(0.018, 0.011), Vector2(0.010, 0.019),
			Vector2(-0.010, 0.019), Vector2(-0.018, 0.011)])
	face_strip(b, 0.228, true, 0.470, blade, CB.M_CHROME, C_CHROME, 0.0)
	face_strip(b, 0.228, true, 0.400, PackedVector2Array([Vector2(-0.005, 0.017), Vector2(0.005, 0.017), Vector2(0.004, 0.022),
			Vector2(-0.004, 0.022)]), CB.M_DARK, C_DARK, 0.0)
	# The oil cooler under the bumper, behind the chin spoiler: a black core with alloy fins.
	var oc: Array = face_frame(0.0, 0.180, true)
	var ob: Basis = facing(oc[1])
	b.rbox(Transform3D(ob, oc[0] + ob.z * 0.004), Vector3(0.165, 0.024, 0.010), 0.006, 1, CB.M_DARK, C_DARKER)
	for k in 5:
		bar(b, oc[0] + ob.y * (-0.016 + 0.008 * k) + ob.z * 0.014, Vector3(0.155, 0.0016, 0.002), CB.M_ALLOY, C_ALLOY_DARK)
	# Chin spoiler (deppa): a long plate in the paint jutting out under the nose, endplates at its ends.
	var dz: float = shell_z(0.0, 0.18, true)
	var lip_y := 0.128
	sweep(b, PackedVector3Array([Vector3(-0.47, lip_y, dz), Vector3(0.47, lip_y, dz)]), Vector3.BACK, Vector3.UP,
			PackedVector2Array([Vector2(0.10, 0.0), Vector2(-0.125, 0.010), Vector2(-0.135, 0.017), Vector2(-0.126, 0.024),
			Vector2(0.10, 0.016)]), CB.M_PAINT, Color(1, 1, 1))
	for sx in [-1.0, 1.0]:
		slab(b, PackedVector2Array([Vector2(dz + 0.04, lip_y + 0.010), Vector2(dz - 0.128, lip_y + 0.016),
				Vector2(dz - 0.118, lip_y + 0.040), Vector2(dz + 0.04, lip_y + 0.052)]), sx * 0.472, 0.007, CB.M_DARK, C_DARK)
	# Rear bumper and the black valance under it.
	face_strip(b, 0.290, false, 0.475, blade, CB.M_CHROME, C_CHROME, 0.0)
	var va: Array = face_frame(0.0, 0.245, false)
	b.rbox(Transform3D(facing(va[1]), va[0]), Vector3(0.36, 0.028, 0.008), 0.008, 1, CB.M_DARK, C_DARK)
	# Tail garnish between the taillamps, a chrome edge along its top.
	var tg: Array = face_frame(0.0, 0.430, false)
	var tgb: Basis = facing(tg[1])
	b.rbox(Transform3D(tgb, tg[0]), Vector3(0.165, 0.040, 0.008), 0.010, 1, CB.M_DARK, C_DARKER)
	b.rbox(Transform3D(tgb, tg[0] + tgb.y * 0.042 + tgb.z * 0.004), Vector3(0.165, 0.003, 0.004), 0.002, 1, CB.M_CHROME, C_CHROME)
	# Louvres over the rear window: black slats across it, level with the ground, in a black frame.
	var slats: int = 9
	for k in slats:
		var z: float = lerpf(LOUVRE_Z.x, LOUVRE_Z.y - 0.040, float(k) / (slats - 1))
		var path := PackedVector3Array()
		for i in 23:
			var x: float = lerpf(-LOUVRE_X, LOUVRE_X, i / 22.0)
			path.append(Vector3(x, top_y(x, z), z))
		sweep(b, path, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(0.0, 0.004), Vector2(0.042, 0.004),
				Vector2(0.042, 0.010), Vector2(0.0, 0.010)]), CB.M_DARK, C_DARK)
	for sx in [-1.0, 1.0]:
		var side := PackedVector3Array()
		for i in 17:
			var z: float = lerpf(LOUVRE_Z.x - 0.01, LOUVRE_Z.y + 0.008, i / 16.0)
			side.append(Vector3(sx * (LOUVRE_X + 0.012), top_y(LOUVRE_X + 0.012, z) + 0.006, z))
		b.tube(side, 0.008, 6, CB.M_DARK, C_DARK, true, true)
	# Wipers resting on the cowl.
	for x in [-0.16, 0.20]:
		var wz := -0.315
		var p0 := Vector3(x, top_y(x, wz) + 0.006, wz)
		var p1 := Vector3(x - 0.26, top_y(x - 0.26, wz - 0.012) + 0.007, wz - 0.012)
		b.tube(PackedVector3Array([p0, p1]), 0.0045, 5, CB.M_DARK, C_DARK, true, true)
	# Tow hook under the rear valance.
	b.tube(_rounded([Vector3(-0.30, 0.20, 1.06), Vector3(-0.30, 0.20, 1.13), Vector3(-0.25, 0.20, 1.13),
			Vector3(-0.25, 0.20, 1.06)], 0.018), 0.007, 8, CB.M_ANODISED, Color(1, 1, 1), false, false)


## The crest on the grille: a gold ring (the accent) round two crossed blades, on a black disc.
func _crest(b, c: Vector3, basis: Basis) -> void:
	var fwd: Vector3 = basis.z
	b.disc(c, fwd, 0.030, 0.0, 24, CB.M_DARK, C_DARKER)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, fwd, PackedVector2Array([Vector2(0.0, 0.033), Vector2(0.004, 0.032), Vector2(0.005, 0.028), Vector2(0.0, 0.027)]),
			24, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, c - fwd * 0.01)
	for s in [-1.0, 1.0]:
		var rb: Basis = basis * Basis(Vector3.BACK, s * PI * 0.25)
		b.rbox(Transform3D(rb, c + fwd * 0.003), Vector3(0.0035, 0.024, 0.002), 0.0015, 1, CB.M_ANODISED, Color(1, 1, 1))
		# The guard across each blade near its hilt.
		b.rbox(Transform3D(rb, c + fwd * 0.004 + rb.y * -0.013), Vector3(0.008, 0.0018, 0.0025), 0.001, 1, CB.M_ANODISED,
				Color(1, 1, 1))


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1): a low,
## wide tyre round a deep-dish rim (a polished lip and dish, eight spokes broadening to the rim, a centre
## with four nuts), the brake disc behind it.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 48, C_RUBBER)
	# The dish: the polished lip, then its face stepping deep in to where the spokes meet the rim.
	wheel_lathe(b, PackedVector2Array([Vector2(0.098, 0.152), Vector2(0.108, 0.1555), Vector2(0.116, 0.1535),
			Vector2(0.118, 0.148), Vector2(0.114, 0.1435)]), 48, CB.M_CHROME, C_CHROME, "out", Vector3(0.09, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.114, 0.1435), Vector2(0.088, 0.1340), Vector2(0.080, 0.1300)]), 48,
			CB.M_CHROME, C_CHROME, "+x")
	# The ring the spokes run into, and the barrel behind.
	wheel_lathe(b, PackedVector2Array([Vector2(0.080, 0.1300), Vector2(0.079, 0.1180)]), 48, CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.079, 0.1180), Vector2(0.066, 0.1200), Vector2(0.060, 0.1380),
			Vector2(-0.098, 0.1400), Vector2(-0.108, 0.1460)]), 48, CB.M_RIM, C_RIM_BARREL, "in")
	# Brake disc behind the spokes, a dark well behind that.
	b.disc(Vector3(-0.004, 0.0, 0.0), Vector3.RIGHT, 0.108, 0.044, 36, CB.M_ALLOY, C_ALLOY_DARK)
	b.disc(Vector3(-0.018, 0.0, 0.0), Vector3.LEFT, 0.108, 0.044, 36, CB.M_ALLOY, C_ALLOY_DARK)
	wheel_lathe(b, PackedVector2Array([Vector2(-0.018, 0.108), Vector2(-0.004, 0.108)]), 36, CB.M_ALLOY, C_ALLOY_DARK,
			"out", Vector3(-0.011, 0.0, 0.0))
	b.disc(Vector3(-0.050, 0.0, 0.0), Vector3.RIGHT, 0.138, 0.0, 32, CB.M_DARK, C_DARKER)
	# Eight broad spokes, a little wider at the rim than at the hub.
	for k in 8:
		spoke(b, TAU * (k + 0.5) / 8.0, 0.0, 0.034, 0.121, 0.086, 0.080, 0.0115, 0.0165, 0.013, CB.M_RIM, C_RIM)
	# Centre: a raised boss, four chrome nuts, a cap.
	wheel_lathe(b, PackedVector2Array([Vector2(0.080, 0.044), Vector2(0.090, 0.042), Vector2(0.094, 0.036)]), 24,
			CB.M_RIM, C_RIM, "out", Vector3(0.07, 0.0, 0.0))
	b.disc(Vector3(0.094, 0.0, 0.0), Vector3.RIGHT, 0.036, 0.0, 24, CB.M_RIM, C_RIM)
	for k in 4:
		var g: Array = wheel_frame(TAU * (k + 0.5) / 4.0)
		var nc: Vector3 = (g[0] as Vector3) * 0.024 + Vector3(0.097, 0.0, 0.0)
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.lathe(nc - Vector3(0.004, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.0055), Vector2(0.006, 0.0055),
				Vector2(0.008, 0.003), Vector2(0.0085, 0.0)]), 6, CB.M_CHROME, C_CHROME)
		b.orient_away_from(vb, ib, nc - Vector3(0.006, 0.0, 0.0))
	var vb2: int = b.vertex_count()
	var ib2: int = b.index_count()
	b.lathe(Vector3(0.094, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.012), Vector2(0.006, 0.011),
			Vector2(0.009, 0.006), Vector2(0.010, 0.0)]), 14, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb2, ib2, Vector3(0.088, 0.0, 0.0))
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Side glass in side view (z, y): the door glass and the quarter light behind it, which runs back to
	# a point where the fastback's sail closes in. Its top is the A-pillar and the roof rail (_upper_s),
	# so the polygon reaches above them.
	shapes["side"] = _inset(PackedVector2Array([Vector2(-0.272, 0.492), Vector2(0.30, 0.507), Vector2(0.60, 0.520),
			Vector2(0.44, 0.80), Vector2(-0.272, 0.80)]), 0.014)
	return shapes


## Where p lies along its section's upper curve, in metres from the side's top: Vector3(s, s where the
## corner's rounding starts, s where it ends). The curve (_upper_segments) is sampled once per z, which
## is one column of the detail map.
func _upper_s(p: Vector3) -> Vector3:
	if not _curve_cache.has(p.z):
		var segs: Array = _upper_segments(p.z, prof["w"].at(p.z), prof["belt"].at(p.z), prof["top"].at(p.z))
		var pts := PackedVector2Array()
		var acc := PackedFloat32Array()
		var marks := PackedFloat32Array()
		for seg in segs:
			for q in (seg as PackedVector2Array):
				if not pts.is_empty() and q.distance_squared_to(pts[pts.size() - 1]) < 1e-14:
					continue
				acc.append(0.0 if pts.is_empty() else acc[acc.size() - 1] + q.distance_to(pts[pts.size() - 1]))
				pts.append(q)
			marks.append(acc[acc.size() - 1])
		_curve_cache[p.z] = [pts, acc, marks]
	var entry: Array = _curve_cache[p.z]
	var pts: PackedVector2Array = entry[0]
	var acc: PackedFloat32Array = entry[1]
	var marks: PackedFloat32Array = entry[2]
	var q := Vector2(absf(p.x), p.y)
	var best := 0.0
	var best_d := 1e9
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var e: Vector2 = pts[k + 1] - a
		var f: float = clampf((q - a).dot(e) / maxf(e.length_squared(), 1e-12), 0.0, 1.0)
		var dd: float = (a + e * f).distance_squared_to(q)
		if dd < best_d:
			best_d = dd
			best = lerpf(acc[k], acc[k + 1], f)
	return Vector3(best, marks[0], marks[1])


## A rounded intersection of two half-planes given as distances (negative inside), corner radius r.
static func _round_and(a: float, b: float, r: float) -> float:
	var q := Vector2(maxf(a + r, 0.0), maxf(b + r, 0.0))
	return q.length() + minf(maxf(a + r, b + r), 0.0) - r


## A pane of glass from its signed distance d: [glass, black seal, chrome surround] coverages.
static func _pane(d: float, fp: float) -> Array:
	return [_cover(d, fp), _cover(d - 0.0028, fp), maxf(_cover(d - 0.0095, fp) - _cover(d - 0.0028, fp), 0.0)]


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var szy := Vector2(p.z, p.y)
	var x: float = absf(p.x)
	var side: bool = n.x > 0.3
	# The glass, cut by the greenhouse's corner: the side glass stops short of the corner's rounding (the
	# A-pillar, the roof rail), the windscreen and the rear glass start inboard of it.
	var below_rail := -1e3
	var ws_d := 1e3
	var rg_d := 1e3
	if p.y > 0.46 and p.z > WS_Z.x - 0.05 and p.z < RG_Z.y + 0.05:
		var u: Vector3 = _upper_s(p)
		below_rail = u.x - (u.y - PILLAR_PAD)
		var inboard: float = (u.z + PILLAR_PAD) - u.x
		ws_d = _round_and(inboard, maxf(WS_Z.x - p.z, p.z - WS_Z.y), 0.03)
		rg_d = _round_and(inboard, maxf(RG_Z.x - p.z, p.z - RG_Z.y), 0.05)
	# Side glass in a chrome surround, the chrome divider between the door glass and the quarter light.
	if n.x > 0.2 and p.y > 0.47:
		var d: float = maxf(_sd_rounded(szy, sh["side"]), below_rail)
		var pane: Array = _pane(d, fp)
		glass = maxf(glass, pane[0])
		black = maxf(black, pane[1])
		chrome = maxf(chrome, pane[2])
		var divider: float = _cover(absf(p.z - B_Z) - 0.0065, fp) * pane[1]
		chrome = maxf(chrome, divider)
		glass *= 1.0 - _cover(absf(p.z - B_Z) - 0.0065, fp)
	# Windscreen and rear glass, each in a chrome surround.
	if n.z < -0.05:
		var pane: Array = _pane(ws_d, fp)
		glass = maxf(glass, pane[0])
		black = maxf(black, pane[1])
		chrome = maxf(chrome, pane[2])
	if n.z > 0.05:
		var pane: Array = _pane(rg_d, fp)
		glass = maxf(glass, pane[0])
		black = maxf(black, pane[1])
		chrome = maxf(chrome, pane[2])
	if side:
		# Door shut lines from the sill to the window line, and a chrome strip along the window's foot.
		if p.y > 0.16 and p.y < 0.495:
			gap = maxf(gap, _cover(absf(p.z - DOOR_Z.x) - 0.0022, fp))
			gap = maxf(gap, _cover(absf(p.z - DOOR_Z.y) - 0.0022, fp))
		# Fuel cap on the right rear quarter.
		if p.x > 0.0:
			gap = maxf(gap, _cover(absf(Vector2(p.z - 0.88, p.y - 0.445).length() - 0.026) - 0.002, fp))
	# Bonnet: its shut lines along the shoulders and across the cowl; the boot lid on the deck.
	if n.y > 0.45:
		if p.z < -0.30:
			gap = maxf(gap, _cover(absf(x - 0.448) - 0.002, fp) * float(p.z > -1.165))
			gap = maxf(gap, _cover(absf(p.z + 0.338) - 0.002, fp) * float(x < 0.448))
			gap = maxf(gap, _cover(absf(p.z + 1.165) - 0.002, fp) * float(x < 0.448))
		if p.z > 0.76:
			gap = maxf(gap, _cover(absf(x - 0.405) - 0.002, fp) * float(p.z > 0.785) * float(p.z < 1.035))
			gap = maxf(gap, _cover(absf(p.z - 0.785) - 0.002, fp) * float(x < 0.405))
	# Underside, and the arches' ceilings.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, chrome, black)
