# JukeboxBuilder.gd
#
# The Jukebox: a 1950s-style American tailfin cruiser, an original design with a made-up name. Long, low
# and wide: a long bonnet between hooded headlamps, a wide chrome grille over a heavy bumper with two
# bullet guards, a pillarless hardtop behind a wraparound windscreen, and a long deck sunk between two
# tailfins that rise from the rear fenders and end over jet-pipe tail lamps. A chrome spear along each
# flank splits the two-tone, the rear wheels sit half under skirts, and it rolls on wide whitewalls with
# chrome spinner hubcaps.
#
# What sets it apart from the fleet: nothing else is a full-size cruiser (the Classics are a hot rod, a
# Grand Prix car, a bubble car and a Japanese fastback), nothing else has fins, skirts or this much
# chrome, and it is the longest car and the heaviest that isn't a truck.
#
# The shell, wheel parts and detail map come from CarDesign.gd. The section is the Samurai's (a real
# corner above the side, its parameters keyed together in KEYS) with one more parameter: the top's
# exponent. The top runs from the centre line out to the corner as top + (edge - top) (x / px)^pow, so
# with the corner above the centre line and a high exponent it is a flat deck that sweeps up into a fin
# (pow 2 is the Samurai's crowned roof). The fins make the section's outline fold back in y, so
# shell_z() tests the whole half-section (as the Nocturne's does). The arches are cut by lifting the
# shell's bottom over each wheel (_bot_knots): the front one clears the tyre, the rear one stops short
# of its top, which is the skirt.
extends "res://CarDesign.gd"

# Wheels: tall tyres set well inside the body, the rear track narrower so the skirts cover them.
const WHEEL_XF := 0.455
const WHEEL_XR := 0.430
const AXLE_F := -0.780
const AXLE_R := 0.740
const HUB_Y := 0.215

# The section along the car: z; the top of the centre line; belt (the top of the vertical side); px,
# edge (the corner: the bonnet's rolled edge, the A-pillar, the roof rail, the fin's crest); fillet (how
# far the corner is rounded off along each side of it); bow (the side glass bulging out); pow (the top's
# exponent: 2 a crowned panel, higher a flat deck sweeping up to the corner).
const KEYS := [
	# z       top    belt   px     edge   fillet bow    pow
	[-1.300, 0.420, 0.400, 0.380, 0.412, 0.020, 0.000, 2.0],
	[-1.260, 0.478, 0.452, 0.462, 0.469, 0.030, 0.000, 2.0],
	[-1.200, 0.496, 0.470, 0.486, 0.487, 0.036, 0.000, 2.0],
	[-1.100, 0.506, 0.480, 0.496, 0.497, 0.038, 0.000, 2.0],
	[-0.900, 0.514, 0.485, 0.498, 0.504, 0.038, 0.000, 2.0],
	[-0.700, 0.519, 0.487, 0.494, 0.509, 0.038, 0.000, 2.0],
	[-0.520, 0.522, 0.488, 0.486, 0.512, 0.036, 0.000, 2.0],
	[-0.400, 0.524, 0.488, 0.474, 0.514, 0.036, 0.002, 2.0],
	[-0.350, 0.552, 0.489, 0.462, 0.540, 0.050, 0.004, 2.0],
	[-0.290, 0.606, 0.489, 0.448, 0.592, 0.055, 0.006, 2.0],
	[-0.230, 0.656, 0.490, 0.436, 0.641, 0.055, 0.008, 2.0],
	[-0.180, 0.690, 0.490, 0.429, 0.674, 0.050, 0.008, 2.0],
	[-0.130, 0.706, 0.490, 0.426, 0.690, 0.040, 0.008, 2.0],
	[-0.040, 0.713, 0.490, 0.425, 0.697, 0.034, 0.008, 2.0],
	[0.120, 0.715, 0.490, 0.425, 0.699, 0.032, 0.008, 2.0],
	[0.300, 0.709, 0.490, 0.427, 0.693, 0.032, 0.008, 2.0],
	[0.380, 0.690, 0.490, 0.432, 0.674, 0.034, 0.007, 2.0],
	[0.450, 0.650, 0.491, 0.443, 0.635, 0.036, 0.005, 2.0],
	[0.530, 0.590, 0.492, 0.460, 0.577, 0.036, 0.003, 2.0],
	[0.600, 0.540, 0.492, 0.478, 0.530, 0.034, 0.001, 2.0],
	[0.660, 0.514, 0.492, 0.492, 0.510, 0.030, 0.000, 2.2],
	[0.740, 0.503, 0.490, 0.502, 0.518, 0.022, 0.000, 3.0],
	[0.840, 0.495, 0.486, 0.508, 0.538, 0.014, 0.000, 4.2],
	[0.960, 0.485, 0.480, 0.512, 0.564, 0.010, 0.000, 5.5],
	[1.080, 0.474, 0.474, 0.514, 0.590, 0.009, 0.000, 6.5],
	[1.200, 0.462, 0.468, 0.514, 0.613, 0.008, 0.000, 7.0],
	[1.290, 0.452, 0.463, 0.512, 0.629, 0.008, 0.000, 7.0],
	[1.340, 0.446, 0.460, 0.508, 0.636, 0.008, 0.000, 7.0],
]
const KEY_NAMES := ["top", "belt", "px", "edge", "fillet", "bow", "pow"]
const W_KNOTS := [[-1.30, 0.400], [-1.275, 0.470], [-1.24, 0.505], [-1.18, 0.522], [-1.08, 0.531], [-0.90, 0.535],
	[0.95, 0.535], [1.15, 0.531], [1.26, 0.523], [1.31, 0.508], [1.34, 0.470]]
# Where the top's two segments meet, as a share of px: the fin's inner face outboard of it, the deck
# inboard (the same ring points at every station).
const TOP_SPLIT := 0.72

# The bottom of the shell: the front valance, the sills, the rear valance; an arch lifted over each wheel
# (half-length rz, from cy up to cy + ry, superellipse e). The rear one is the skirt's lower edge.
const NOSE_BOT := 0.165
const SILL_Y := 0.150
const TAIL_BOT := 0.185
const FRONT_ARCH := {"z": AXLE_F, "rz": 0.265, "cy": 0.175, "ry": 0.280, "e": 2.6}
const REAR_ARCH := {"z": AXLE_R, "rz": 0.250, "cy": 0.185, "ry": 0.150, "e": 3.0}

# The glass round the greenhouse's corner: behind the A-post the side glass stops PILLAR_PAD short of the
# corner's rounding (the roof rail) and the rear glass starts PILLAR_PAD inboard of it. Ahead of the
# A-post (POST_Z) the windscreen wraps round the corner into the side glass. The windscreen runs from
# the cowl to the header (WS_Z), the rear glass down to the deck (RG_Z).
const PILLAR_PAD := 0.004
const WS_Z := Vector2(-0.395, -0.150)
const RG_Z := Vector2(0.360, 0.635)
const POST_Z := -0.172
const POST_W := 0.009
const B_Z := 0.150                        # the hardtop's glass joint: no pillar, a thin chrome strip
const DOOR_Z := Vector2(-0.405, 0.230)    # the door's shut lines
# The chrome spear along the flank, from behind the front arch to the tail (and a short piece ahead of the
# arch, SPEAR_FRONT_Z): the two-tone splits under it.
const SPEAR_Y := 0.372
const SPEAR_Z := Vector2(-0.490, 1.275)
const SPEAR_FRONT_Z := Vector2(-1.225, -1.070)
const SPEAR_H := 0.010

# Tyres: a tall cross-ply (half its profile, bead to tread centre) with a wide whitewall.
const TYRE_HALF := [[-0.066, 0.148], [-0.074, 0.156], [-0.078, 0.170], [-0.078, 0.190], [-0.074, 0.203],
	[-0.064, 0.211], [-0.045, 0.2145], [-0.040, 0.2120], [-0.030, 0.2120], [-0.025, 0.2150], [0.0, 0.2150]]

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.17, 0.17, 0.18)
const C_WHITEWALL := Color(0.92, 0.92, 0.89)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
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
## the two-tone's split: its pinline lies on the chrome spear's centre line, under the chrome.
const PAINT_LAYOUT := {
	"nose_z": -1.30, "tail_z": 1.34, "belt_y": SPEAR_Y + 0.006, "side_x": 0.535,
	"door_z": -0.09, "door_y": 0.436, "roundel_r": 0.048,
	"hood_z": -0.88, "hood_r": 0.080, "stripe_w": 0.08, "stripe_gap": 0.035,
}
const ANTENNA_POS := Vector3(0.20, 0.482, 0.95)
var _curve_cache := {}                    # z -> the upper curve's samples, for _upper_s()

const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_XF, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_XF, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_XR, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_XR, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.300
	nose_cap = 0.060
	nose_cap_y = 0.335
	nose_cap_exp = Vector2(5.0, 3.5)
	tail_tip = 1.340
	tail_cap = 0.055
	tail_cap_y = 0.360
	tail_cap_exp = Vector2(5.0, 4.0)
	# Bottom, bottom corner, side; then the glass (the fin's outer face), the corner's rounding, the fin's
	# inner face and the deck.
	segment_counts = [2, 3, 4, 6, 6, 8, 7]
	half_ring = 36
	bottom_radius = 0.022
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	setup_shell(knots)


## The shell's bottom: flat along the valances and sills, stepping up into an arch over each wheel.
static func _bot_knots() -> Array:
	var k := [[-1.30, NOSE_BOT + 0.015], [-1.18, NOSE_BOT]]
	for pair in [[FRONT_ARCH, NOSE_BOT, SILL_Y], [REAR_ARCH, SILL_Y, TAIL_BOT]]:
		var arch: Dictionary = pair[0]
		var az: float = arch["z"]
		var rz: float = arch["rz"]
		var e: float = arch["e"]
		k.append([az - rz - 0.012, pair[1]])
		for s in 21:
			var t: float = s / 10.0 - 1.0
			k.append([az + rz * t, float(arch["cy"]) + float(arch["ry"]) * pow(maxf(1.0 - pow(absf(t), e), 0.0), 1.0 / e)])
		k.append([az + rz + 0.012, pair[2]])
	k.append([1.34, TAIL_BOT + 0.01])
	return k


## Where the body's surface is at (x, y), searching from the nose (or from the tail): its z. The fins
## stand over the deck between them, so the section's outline isn't monotonic in y (CarDesign's test
## assumes it is): this tests the whole half-section, then bisects to the surface.
func shell_z(x: float, y: float, from_front: bool) -> float:
	var q := Vector2(absf(x), y)
	var z: float = nose_tip if from_front else tail_tip
	var dz: float = 0.004 if from_front else -0.004
	for k in 600:
		if Geometry2D.is_point_in_polygon(q, section(z)):
			var lo: float = z - dz
			var hi: float = z
			for m in 12:
				var mid: float = (lo + hi) * 0.5
				if Geometry2D.is_point_in_polygon(q, section(mid)):
					hi = mid
				else:
					lo = mid
			return hi
		z += dz
	return z


## The corner at z: [the sharp corner K, where its rounding starts on the side below it (T1), where it
## ends on the top (T2), the top's exponent].
func _corner(z: float, w: float, belt: float, top: float) -> Array:
	var px: float = minf(prof["px"].at(z), w - 0.005)
	var edge: float = maxf(prof["edge"].at(z), belt + 0.003)
	var k := Vector2(px, edge)
	var s := Vector2(w, belt)
	var f: float = prof["fillet"].at(z)
	var e: float = prof["pow"].at(z)
	var t1: Vector2 = k + (s - k).normalized() * minf(f, 0.45 * s.distance_to(k))
	var tx: float = minf(f, 0.25 * px)
	return [k, t1, Vector2(px - tx, _top_at(px - tx, k, top, e)), e]


## The top's height at x: `top` at the centre line, the corner's height at its x, as (x / px)^e between.
static func _top_at(x: float, k: Vector2, top: float, e: float) -> float:
	return top + (k.y - top) * pow(clampf(x / k.x, 0.0, 1.0), e)


## Above the side, as segments with fixed point counts (segment_counts): the glass leaning in from the
## side's top to the corner's rounding, bowed out a little (over the deck, the fin's outer face); the
## rounding (a quadratic through the sharp corner, so it meets both tangentially); the top in two
## parts, from the rounding in to TOP_SPLIT (the fin's inner face) and on to the centre line.
func _upper_segments(z: float, w: float, belt: float, top: float) -> Array:
	var c: Array = _corner(z, w, belt, top)
	var k: Vector2 = c[0]
	var t1: Vector2 = c[1]
	var t2: Vector2 = c[2]
	var e: float = c[3]
	var s := Vector2(w, belt)
	var dir: Vector2 = (t1 - s).normalized()
	var mid: Vector2 = (s + t1) * 0.5 + Vector2(dir.y, -dir.x) * prof["bow"].at(z)
	var glass := PackedVector2Array()
	var rounding := PackedVector2Array()
	for i in 13:
		var u: float = i / 12.0
		glass.append(s.lerp(mid, u).lerp(mid.lerp(t1, u), u))
		rounding.append(t1.lerp(k, u).lerp(k.lerp(t2, u), u))
	var x_split: float = k.x * TOP_SPLIT
	var inner := PackedVector2Array()
	for i in 25:
		# Closer together toward the corner, where a fin's face is steepest.
		var x: float = lerpf(t2.x, x_split, pow(i / 24.0, 1.5))
		inner.append(Vector2(x, _top_at(x, k, top, e)))
	var deck := PackedVector2Array()
	for i in 17:
		var x: float = x_split * (1.0 - i / 16.0)
		deck.append(Vector2(x, _top_at(x, k, top, e)))
	return [glass, rounding, inner, deck]


## A wheel arch's outline along the body's side, as points (x just proud of the side, the shell's
## bottom, z) from one end of the arch to the other.
func _arch_path(arch: Dictionary, proud: float) -> PackedVector3Array:
	var az: float = arch["z"]
	var rz: float = arch["rz"]
	var path := PackedVector3Array()
	for k in 33:
		var z: float = az + rz * (k / 16.0 - 1.0)
		path.append(Vector3(prof["w"].at(z) + proud, prof["bot"].at(z), z))
	return path


## A lathe whose surface faces away from its axis (or toward it, `inward`: the inside of a pipe).
func _lathe(b, c: Vector3, axis: Vector3, profile: PackedVector2Array, segs: int, mat: int, col: Color,
		inward := false) -> void:
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(c, axis, profile, segs, mat, col)
	var radial := 0.0
	for k in range(vb, b.vertex_count()):
		var d: Vector3 = b._v[k] - c
		radial += b._n[k].dot(d - axis * d.dot(axis))
	if (radial > 0.0) == inward:
		b.flip(vb, ib)


## Body mesh: shell, arch trims, lamps, bumpers, chrome and the running gear seen under it.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Arch liners: dark walls inside each arch (the front one clear of the tyre at full lock).
	b.rbox(Transform3D(Basis(), Vector3(0.255, 0.315, AXLE_F)), Vector3(0.004, 0.140, float(FRONT_ARCH["rz"])), 0.003, 1,
			CB.M_DARK, C_DARKER)
	b.rbox(Transform3D(Basis(), Vector3(0.320, 0.262, AXLE_R)), Vector3(0.004, 0.075, float(REAR_ARCH["rz"])), 0.003, 1,
			CB.M_DARK, C_DARKER)
	# A chrome lip round the front arch and along the skirt's edge.
	b.tube(_arch_path(FRONT_ARCH, -0.002), 0.0075, 8, CB.M_CHROME, C_CHROME, true, true)
	b.tube(_arch_path(REAR_ARCH, -0.002), 0.0065, 8, CB.M_CHROME, C_CHROME, true, true)
	# The headlamp, hooded: a painted pod standing out of the nose, the lamp set back in it.
	var hl: Array = face_frame(0.405, 0.408, true)
	var hf: Vector3 = hl[1]
	var hc: Vector3 = hl[0]
	_lathe(b, hc, hf, PackedVector2Array([Vector2(-0.030, 0.082), Vector2(0.022, 0.081), Vector2(0.040, 0.077),
			Vector2(0.050, 0.070)]), 28, CB.M_PAINT, Color(1, 1, 1))
	_lathe(b, hc, hf, PackedVector2Array([Vector2(0.050, 0.070), Vector2(0.046, 0.066), Vector2(0.012, 0.065)]), 28,
			CB.M_CHROME, C_CHROME, true)
	round_lamp(b, hc + hf * 0.018, hf, 0.060, CB.M_HEADLAMP, Color(1, 1, 1))
	# Parking lamp under it, in a chrome bezel.
	var pk: Array = face_frame(0.405, 0.292, true)
	var pb: Basis = facing(pk[1])
	b.rbox(Transform3D(pb, pk[0]), Vector3(0.050, 0.019, 0.008), 0.012, 2, CB.M_CHROME, C_CHROME)
	b.rbox(Transform3D(pb, pk[0] + pb.z * 0.005), Vector3(0.041, 0.012, 0.007), 0.008, 2, CB.M_TAILLAMP, C_AMBER)
	# The tail lamp under the fin: a chrome jet pipe, a red bullet in its mouth.
	var tl: Array = face_frame(0.425, 0.408, false)
	var tf: Vector3 = tl[1]
	var tc: Vector3 = tl[0]
	_lathe(b, tc, tf, PackedVector2Array([Vector2(-0.030, 0.064), Vector2(0.026, 0.063), Vector2(0.050, 0.057),
			Vector2(0.058, 0.050)]), 28, CB.M_CHROME, C_CHROME)
	_lathe(b, tc, tf, PackedVector2Array([Vector2(0.058, 0.050), Vector2(0.054, 0.046), Vector2(0.020, 0.045)]), 28,
			CB.M_DARK, C_DARKER, true)
	_lathe(b, tc, tf, PackedVector2Array([Vector2(0.020, 0.045), Vector2(0.046, 0.040), Vector2(0.070, 0.026),
			Vector2(0.084, 0.010), Vector2(0.088, 0.0)]), 24, CB.M_TAILLAMP, C_TAILLAMP)
	# A small lamp in the fin's end, over it.
	var fl: Array = face_frame(0.478, 0.560, false)
	var fb: Basis = facing(fl[1])
	b.rbox(Transform3D(fb, fl[0]), Vector3(0.016, 0.040, 0.006), 0.010, 2, CB.M_CHROME, C_CHROME)
	b.rbox(Transform3D(fb, fl[0] + fb.z * 0.004), Vector3(0.010, 0.033, 0.006), 0.007, 2, CB.M_TAILLAMP, C_TAILLAMP)
	# Reversing lamp inboard of the jet pipe.
	var rv: Array = face_frame(0.300, 0.408, false)
	round_lamp(b, rv[0] + (rv[1] as Vector3) * 0.006, rv[1], 0.024, CB.M_TAILLAMP, C_REVERSE)
	# Chrome along the corner: the drip rail from the A-post over the roof and down the rear pillar, and a
	# bead along each fin's crest.
	_corner_rail(b, POST_Z, 0.600, 0.0045)
	_corner_rail(b, 0.800, 1.318, 0.0040)
	# Door mirror: a chrome bullet on a stalk, its glass toward the driver.
	var mz := -0.300
	var mw: float = prof["w"].at(mz)
	var head := Vector3(mw + 0.050, 0.540, mz - 0.010)
	b.tube(PackedVector3Array([Vector3(mw - 0.004, 0.498, mz), Vector3(mw + 0.030, 0.512, mz - 0.004), head - Vector3(0.0, 0.016, 0.0)]),
			0.0050, 6, CB.M_CHROME, C_CHROME, false, true)
	_lathe(b, head, Vector3.FORWARD, PackedVector2Array([Vector2(-0.006, 0.027), Vector2(0.008, 0.026), Vector2(0.026, 0.016),
			Vector2(0.036, 0.004), Vector2(0.037, 0.0)]), 16, CB.M_CHROME, C_CHROME)
	b.disc(head + Vector3.BACK * 0.006, Vector3.BACK, 0.027, 0.0, 16, CB.M_CHROME, C_CHROME)
	b.disc(head + Vector3.BACK * 0.0065, Vector3.BACK, 0.023, 0.0, 16, CB.M_DARK, C_STEEL)
	# Door handle, chrome.
	b.rbox(Transform3D(Basis(), Vector3(prof["w"].at(0.14) + 0.003, 0.455, 0.14)), Vector3(0.005, 0.007, 0.036), 0.004, 1,
			CB.M_CHROME, C_CHROME)
	# A gunsight ornament on the front fender's crown.
	var gz := -1.120
	var gx := 0.400
	var gy: float = top_y(gx, gz)
	b.rbox(Transform3D(Basis(), Vector3(gx, gy + 0.004, gz)), Vector3(0.005, 0.006, 0.030), 0.004, 1, CB.M_CHROME, C_CHROME)
	_lathe(b, Vector3(gx, gy + 0.018, gz + 0.004), Vector3.FORWARD, PackedVector2Array([Vector2(-0.026, 0.0), Vector2(-0.022, 0.006),
			Vector2(0.004, 0.0085), Vector2(0.024, 0.006), Vector2(0.036, 0.0)]), 10, CB.M_CHROME, C_CHROME)
	# Front running gear in the arch: lower arms, hub carrier, a coil-over.
	for dz in [-0.08, 0.08]:
		b.tube(PackedVector3Array([Vector3(0.16, 0.190, AXLE_F + dz), Vector3(0.375, 0.170, AXLE_F)]), 0.011, 8, CB.M_DARK,
				C_STEEL, true, true)
	b.rbox(Transform3D(Basis(), Vector3(0.385, HUB_Y, AXLE_F)), Vector3(0.016, 0.055, 0.03), 0.008, 1, CB.M_DARK, C_STEEL)
	coilover(b, Vector3(0.300, 0.190, AXLE_F), Vector3(0.280, 0.420, AXLE_F + 0.02), 0.014, 0.024, 5.0, C_ALLOY, C_ALLOY_DARK,
			C_CHROME, C_DARK)
	# The live rear axle's leaf spring and its half of the axle tube.
	b.rbox(Transform3D(Basis(), Vector3(0.330, 0.180, AXLE_R)), Vector3(0.022, 0.007, 0.300), 0.004, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(0.0, HUB_Y, AXLE_R), Vector3(0.385, HUB_Y, AXLE_R)]), 0.024, 10, CB.M_DARK, C_STEEL,
			false, true)
	# Exhaust: a chrome tailpipe out under the rear bumper.
	var pipe := PackedVector3Array([Vector3(0.300, 0.170, 1.060), Vector3(0.300, 0.166, 1.385)])
	b.tube(pipe, 0.019, 12, CB.M_CHROME, C_CHROME, true, false)
	_lathe(b, pipe[1], Vector3.BACK, PackedVector2Array([Vector2(0.0, 0.019), Vector2(0.0, 0.0155), Vector2(-0.040, 0.0155)]),
			12, CB.M_DARK, C_DARKER, true)
	b.disc(pipe[1] - Vector3(0.0, 0.0, 0.040), Vector3.BACK, 0.0155, 0.0, 12, CB.M_DARK, C_DARKER)
	b.disc(pipe[1], Vector3.BACK, 0.019, 0.0155, 12, CB.M_CHROME, C_CHROME)


## A chrome bead along the section's corner from z0 to z1, standing just proud of its rounding.
func _corner_rail(b, z0: float, z1: float, r: float) -> void:
	var rail := PackedVector3Array()
	for k in 33:
		var z: float = lerpf(z0, z1, k / 32.0)
		var c: Array = _corner(z, prof["w"].at(z), prof["belt"].at(z), prof["top"].at(z))
		var kk: Vector2 = c[0]
		var t1: Vector2 = c[1]
		var t2: Vector2 = c[2]
		var on: Vector2 = t1 * 0.25 + kk * 0.5 + t2 * 0.25
		var out: Vector2 = (kk - (t1 + t2) * 0.5).normalized()
		var q: Vector2 = on + out * (r * 0.7)
		var cap: Array = _cap(z)
		var cs: Vector2 = cap[0]
		rail.append(Vector3(q.x * cs.x, float(cap[1]) + (q.y - float(cap[1])) * cs.y if cs != Vector2.ONE else q.y, z))
	b.tube(rail, r, 6, CB.M_CHROME, C_CHROME, true, true)


func _centre_parts(b) -> void:
	# The grille: a wide dark mouth in a thick chrome surround, an egg-crate of chrome bars in it.
	var gr: Array = face_frame(0.0, 0.318, true)
	var gb: Basis = facing(gr[1])
	var gc: Vector3 = gr[0]
	var ghx := 0.292
	var ghy := 0.056
	b.rbox(Transform3D(gb, gc), Vector3(ghx, ghy, 0.010), 0.010, 1, CB.M_DARK, C_DARKER)
	var loop: Array = []
	for q in [Vector2(0.0, -ghy), Vector2(ghx, -ghy), Vector2(ghx, ghy), Vector2(-ghx, ghy), Vector2(-ghx, -ghy),
			Vector2(0.0, -ghy)]:
		loop.append(gc + gb.x * q.x + gb.y * q.y + gb.z * 0.012)
	b.tube(_rounded(loop, 0.050, 6), 0.013, 10, CB.M_CHROME, C_CHROME, false, false)
	for k in 3:
		bar(b, gc + gb.y * (-0.028 + 0.028 * k) + gb.z * 0.013, Vector3(ghx - 0.012, 0.0040, 0.004), CB.M_CHROME, C_CHROME)
	for k in 13:
		bar(b, gc + gb.x * (ghx - 0.030) * (k / 6.0 - 1.0) + gb.z * 0.011, Vector3(0.0028, ghy - 0.010, 0.003), CB.M_CHROME,
				C_CHROME)
	# A crest in the middle of it: a disc in the accent colour in a chrome ring, a chrome wing either side.
	var em: Vector3 = gc + gb.z * 0.019
	b.disc(em + gb.y * 0.012, gb.z, 0.020, 0.0, 20, CB.M_ANODISED, Color(1, 1, 1))
	_lathe(b, em + gb.y * 0.012 - gb.z * 0.004, gb.z, PackedVector2Array([Vector2(0.0, 0.024), Vector2(0.006, 0.023),
			Vector2(0.007, 0.020), Vector2(0.004, 0.019)]), 20, CB.M_CHROME, C_CHROME)
	for s in [-1.0, 1.0]:
		var wing: Basis = gb * Basis(Vector3.BACK, -s * 1.22)
		b.rbox(Transform3D(wing, em + gb.y * 0.012 + wing.y * 0.064), Vector3(0.0050, 0.042, 0.003), 0.002, 1, CB.M_CHROME,
				C_CHROME)
	# Front bumper: a heavy chrome bar across the nose and round its corners, two bullet guards on it.
	var bumper := PackedVector2Array([Vector2(-0.036, 0.0), Vector2(0.036, 0.0), Vector2(0.033, 0.022), Vector2(0.018, 0.038),
			Vector2(-0.018, 0.038), Vector2(-0.033, 0.022)])
	face_strip(b, 0.214, true, 0.518, bumper, CB.M_CHROME, C_CHROME, 0.0)
	for sx in [-1.0, 1.0]:
		var bg: Array = face_frame(sx * 0.215, 0.214, true)
		var bf: Vector3 = bg[1]
		_lathe(b, (bg[0] as Vector3) + bf * 0.026, bf, PackedVector2Array([Vector2(0.0, 0.034), Vector2(0.020, 0.033),
				Vector2(0.044, 0.024), Vector2(0.060, 0.010), Vector2(0.064, 0.0)]), 18, CB.M_CHROME, C_CHROME)
	# The rocket on the bonnet's nose: a chrome bullet on a stem, a little fin on its back.
	var oz := -1.150
	var oy: float = top_y(0.0, oz)
	var oc := Vector3(0.0, oy + 0.024, oz)
	b.rbox(Transform3D(Basis(), Vector3(0.0, oy + 0.006, oz + 0.010)), Vector3(0.006, 0.012, 0.026), 0.005, 1, CB.M_CHROME,
			C_CHROME)
	_lathe(b, oc, Vector3.FORWARD, PackedVector2Array([Vector2(-0.060, 0.0), Vector2(-0.052, 0.008), Vector2(-0.020, 0.0125),
			Vector2(0.030, 0.011), Vector2(0.062, 0.005), Vector2(0.074, 0.0)]), 12, CB.M_CHROME, C_CHROME)
	slab(b, PackedVector2Array([Vector2(oz + 0.012, oy + 0.032), Vector2(oz + 0.062, oy + 0.032), Vector2(oz + 0.070, oy + 0.052),
			Vector2(oz + 0.050, oy + 0.050)]), 0.0, 0.004, CB.M_CHROME, C_CHROME)
	# Rear bumper, the same bar.
	face_strip(b, 0.236, false, 0.518, bumper, CB.M_CHROME, C_CHROME, 0.0)
	# The tail panel between the lamps: brushed alloy between two chrome edges, the boot's handle over it.
	var tp: Array = face_frame(0.0, 0.408, false)
	var tb: Basis = facing(tp[1])
	var tc: Vector3 = tp[0]
	b.rbox(Transform3D(tb, tc), Vector3(0.255, 0.030, 0.006), 0.006, 1, CB.M_ALLOY, C_ALLOY)
	for s in [-1.0, 1.0]:
		b.rbox(Transform3D(tb, tc + tb.y * s * 0.032 + tb.z * 0.004), Vector3(0.262, 0.0040, 0.005), 0.003, 1, CB.M_CHROME,
				C_CHROME)
	b.rbox(Transform3D(tb, tc + tb.z * 0.008), Vector3(0.050, 0.010, 0.006), 0.005, 2, CB.M_CHROME, C_CHROME)
	# The plate under it, dark in a chrome frame.
	var lp: Array = face_frame(0.0, 0.318, false)
	var lb: Basis = facing(lp[1])
	b.rbox(Transform3D(lb, lp[0]), Vector3(0.092, 0.034, 0.005), 0.006, 1, CB.M_CHROME, C_CHROME)
	b.rbox(Transform3D(lb, (lp[0] as Vector3) + lb.z * 0.003), Vector3(0.084, 0.027, 0.004), 0.004, 1, CB.M_DARK, C_DARK)
	# The rear axle's differential.
	_lathe(b, Vector3(0.0, HUB_Y, AXLE_R), Vector3.RIGHT, PackedVector2Array([Vector2(-0.085, 0.024), Vector2(-0.060, 0.050),
			Vector2(-0.020, 0.068), Vector2(0.020, 0.068), Vector2(0.060, 0.050), Vector2(0.085, 0.024)]), 14, CB.M_DARK, C_STEEL)
	# Wipers resting on the cowl.
	for x in [-0.14, 0.22]:
		var wz := -0.392
		var p0 := Vector3(x, top_y(x, wz) + 0.006, wz)
		var p1 := Vector3(x - 0.27, top_y(x - 0.27, wz - 0.010) + 0.007, wz - 0.010)
		b.tube(PackedVector3Array([p0, p1]), 0.0045, 5, CB.M_CHROME, C_CHROME, true, true)


## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1): a tall
## tyre with a wide whitewall on a steel wheel in the rim colour, under a chrome hubcap with a
## three-bladed spinner.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 48, C_RUBBER)
	# The whitewall: a band lying on the outer sidewall, a hair proud of it.
	wheel_lathe(b, PackedVector2Array([Vector2(0.0735, 0.1545), Vector2(0.0758, 0.1580), Vector2(0.0792, 0.1700),
			Vector2(0.0792, 0.1820), Vector2(0.0780, 0.1850)]), 48, CB.M_RUBBER, C_WHITEWALL, "+x")
	# The steel wheel: its lip at the bead, the dish stepping in to the hubcap.
	wheel_lathe(b, PackedVector2Array([Vector2(0.058, 0.1490), Vector2(0.068, 0.1525), Vector2(0.072, 0.1500),
			Vector2(0.070, 0.1450), Vector2(0.056, 0.1380)]), 48, CB.M_RIM, C_RIM, "out", Vector3(0.05, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(0.056, 0.1380), Vector2(0.050, 0.1200), Vector2(0.052, 0.1000)]), 48,
			CB.M_RIM, C_RIM, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(0.056, 0.1380), Vector2(-0.060, 0.1400), Vector2(-0.066, 0.1480)]), 48,
			CB.M_RIM, C_RIM_BARREL, "in")
	# A dark well behind the hubcap (regenerate_cars.gd gives it its back face and the wheel its inner face).
	b.disc(Vector3(-0.040, 0.0, 0.0), Vector3.RIGHT, 0.139, 0.0, 32, CB.M_DARK, C_DARKER)
	# The hubcap: a broad chrome dome, a raised ring on it, a boss in the middle.
	var hx := 0.052
	wheel_lathe(b, PackedVector2Array([Vector2(hx - 0.002, 0.1050), Vector2(hx + 0.008, 0.1020), Vector2(hx + 0.015, 0.0900),
			Vector2(hx + 0.019, 0.0700)]), 40, CB.M_CHROME, C_CHROME, "out", Vector3(hx - 0.10, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(hx + 0.019, 0.0700), Vector2(hx + 0.024, 0.0660), Vector2(hx + 0.024, 0.0600),
			Vector2(hx + 0.020, 0.0560)]), 40, CB.M_CHROME, C_CHROME, "out", Vector3(hx - 0.10, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(hx + 0.020, 0.0560), Vector2(hx + 0.022, 0.0300)]), 40, CB.M_CHROME, C_CHROME,
			"+x")
	wheel_lathe(b, PackedVector2Array([Vector2(hx + 0.022, 0.0300), Vector2(hx + 0.030, 0.0270), Vector2(hx + 0.036, 0.0150),
			Vector2(hx + 0.038, 0.0)]), 20, CB.M_CHROME, C_CHROME, "out", Vector3(hx - 0.10, 0.0, 0.0))
	# The spinner: three blades from the boss out over the ring.
	for k in 3:
		spoke(b, TAU * k / 3.0, 0.0, 0.020, 0.090, hx + 0.033, hx + 0.024, 0.0075, 0.0045, 0.008, CB.M_CHROME, C_CHROME)
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Side glass in side view (z, y): from the cowl back to the rear pillar, which leans forward. Its top
	# is the roof rail (_upper_s), so the polygon reaches above it.
	shapes["side"] = _inset(PackedVector2Array([Vector2(-0.400, 0.504), Vector2(0.490, 0.504), Vector2(0.385, 0.80),
			Vector2(-0.400, 0.80)]), 0.012)
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


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var szy := Vector2(p.z, p.y)
	var x: float = absf(p.x)
	var side: bool = n.x > 0.5
	# The glass, as one pane round the greenhouse: the side glass under the roof rail, the windscreen and
	# the rear glass inboard of it; ahead of the A-post the windscreen runs on round the corner into the
	# side glass (both reach over the rounding there, so they join).
	if p.y > 0.47 and p.z > WS_Z.x - 0.05 and p.z < RG_Z.y + 0.05:
		var u: Vector3 = _upper_s(p)
		var wrap: bool = p.z < POST_Z + POST_W
		var rail: float = u.x - ((u.z + 0.012) if wrap else (u.y - PILLAR_PAD))
		var d: float = maxf(_sd_rounded(szy, sh["side"]), rail)
		var inboard: float = ((u.y - 0.012) if wrap else (u.z + PILLAR_PAD)) - u.x
		d = minf(d, _round_and(inboard, maxf(WS_Z.x - p.z, p.z - WS_Z.y), 0.03))
		d = minf(d, _round_and((u.z + PILLAR_PAD) - u.x, maxf(RG_Z.x - p.z, p.z - RG_Z.y), 0.045))
		glass = _cover(d, fp)
		black = _cover(d - 0.0028, fp)
		chrome = maxf(_cover(d - 0.0100, fp) - black, 0.0)
		# The A-post, chrome, where the wrapped screen ends; the hardtop's thin glass joint.
		if u.x < u.z + 0.014:
			var post: float = _cover(absf(p.z - POST_Z) - POST_W, fp) * black
			var joint: float = _cover(absf(p.z - B_Z) - 0.0035, fp) * black * float(u.x < u.y)
			chrome = maxf(chrome, maxf(post, joint))
			glass *= 1.0 - maxf(_cover(absf(p.z - POST_Z) - POST_W, fp), _cover(absf(p.z - B_Z) - 0.0035, fp) * float(u.x < u.y))
	if side:
		# The spear: a chrome strip with round ends from behind the front arch to the tail, and its piece
		# between the headlamp and the arch.
		for span in [SPEAR_Z, SPEAR_FRONT_Z]:
			var mid: float = (span.x + span.y) * 0.5
			var half: float = (span.y - span.x) * 0.5
			chrome = maxf(chrome, _cover(_sd_box(Vector2(p.z - mid, p.y - SPEAR_Y), Vector2(half - 0.008, SPEAR_H - 0.008))
					- 0.008, fp))
		# A chrome strip along the sill between the arches.
		chrome = maxf(chrome, _cover(_sd_box(Vector2(p.z + 0.010, p.y - 0.176), Vector2(0.455, 0.0015)) - 0.006, fp))
		# Door shut lines from the sill to the window line.
		if p.y > 0.19 and p.y < 0.497 and absf(p.y - SPEAR_Y) > SPEAR_H + 0.002:
			gap = maxf(gap, _cover(absf(p.z - DOOR_Z.x) - 0.0022, fp))
			gap = maxf(gap, _cover(absf(p.z - DOOR_Z.y) - 0.0022, fp))
	# Bonnet: its shut lines along the shoulders and across the cowl, a chrome strip down its middle; the
	# boot lid on the deck between the fins.
	if n.y > 0.45:
		if p.z < -0.40:
			gap = maxf(gap, _cover(absf(x - 0.440) - 0.002, fp) * float(p.z > -1.215))
			gap = maxf(gap, _cover(absf(p.z + 0.415) - 0.002, fp) * float(x < 0.440))
			gap = maxf(gap, _cover(absf(p.z + 1.215) - 0.002, fp) * float(x < 0.440))
			chrome = maxf(chrome, _cover(x - 0.006, fp) * float(p.z > -1.090) * float(p.z < -0.450))
		if p.z > 0.66:
			gap = maxf(gap, _cover(absf(x - 0.330) - 0.002, fp) * float(p.z > 0.700) * float(p.z < 1.300))
			gap = maxf(gap, _cover(absf(p.z - 0.700) - 0.002, fp) * float(x < 0.330))
	# Underside, and the arches' ceilings.
	if n.y < -0.55:
		black = maxf(black, 0.9)
	return Color(glass, gap, chrome, black)
