# BasiliskBuilder.gd
#
# The Basilisk: a fictional electric super-crossover, an SUV coupé (an original design with a
# made-up name). It stands tall on big wheels inside black arch cladding. Its long bonnet carries a
# raised V: two creases run from the windscreen's corners forward and in to the badge on the nose,
# and outboard of them the fender tops fall away onto a broad shoulder, so the bonnet points like an
# arrowhead. The greenhouse is all black: a raked windscreen between black A-pillars, a glossy black
# glass roof that ends in a spoiler, a fastback rear screen, side glass that ends in a pointed tip;
# behind it a black air vent slashes down each C-pillar into the haunch. Its stare: a slim LED blade
# under the bonnet's leading edge at each corner, turning down as a fang into a tall corner intake
# with vanes; a broad lower grille with fins, a splitter and an alloy skid plate. Along each lower
# door a recessed air channel runs back from behind the front wheel and fades into the door, black
# sills below it. At the back: haunches broader than the cabin, a full-width light bar in a black
# band, a ducktail, a black lower bumper with fins and a skid plate. Ten-spoke turbine rims (faces in
# the rim colour, their sides black), low-profile tyres, calipers in the accent colour.
#
# The section (section(), overridden): the bottom, its corner, the side (which steps in and out
# round the door's air channel, _groove()), then above the side (_upper_segments(), keyed along the
# car in KEYS) a rounded shoulder from the side's top in to S, a run from S to the corner K (the
# side glass over the cabin, the sail panel at the back, the fender top over the bonnet), the
# corner's rounding, and a crowned top to the centre line (the bonnet with its bulge, the
# windscreen, the roof, the rear screen, the deck). Every part of it rises, so the outline is
# monotonic in height and CarDesign's shell_z() holds. The arches are cut by lifting the shell's
# bottom over each wheel (_bot_knots, as on the Interceptor); the cladding (build_fender, in black)
# sweeps along the same outline and dark liners close the arches inside. The detail map finds the
# greenhouse's parts by arc length along the upper curve (_upper_s): the side glass between the
# shoulder and the corner, the pillars and rails on the corner's rounding, the windscreen, roof and
# rear screen inboard of it.
extends "res://CarDesign.gd"

# Wheels: big rims on low-profile tyres (hub height = tyre radius).
const AXLE_F := -0.720
const AXLE_R := 0.680
const WHEEL_X := 0.510
const TYRE_R := 0.190
const HUB_Y := 0.190

# The side (w) along the car: a front fender swell over the front wheel, the doors slimmer, the
# haunches the widest point, over the rear wheels.
const W_KNOTS := [[-1.150, 0.470], [-1.100, 0.518], [-1.040, 0.548], [-0.980, 0.563], [-0.900, 0.570],
	[-0.800, 0.574], [-0.720, 0.575], [-0.630, 0.572], [-0.530, 0.563], [-0.430, 0.555], [-0.300, 0.550],
	[-0.100, 0.549], [0.100, 0.551], [0.250, 0.556], [0.380, 0.566], [0.500, 0.576], [0.600, 0.581],
	[0.700, 0.583], [0.800, 0.581], [0.900, 0.575], [0.990, 0.564], [1.060, 0.548], [1.110, 0.528],
	[1.150, 0.500]]

# The shell's bottom: the chin, the sills and the rear bumper; an arch lifted over each wheel
# (half-length ARCH_RZ, from ARCH_CY up to ARCH_CY + ARCH_RY, a superellipse of exponent ARCH_E).
const NOSE_BOT := 0.165
const SILL_BOT := 0.150
const TAIL_BOT := 0.190
const ARCH_RZ := 0.255
const ARCH_CY := 0.190
const ARCH_RY := 0.215
const ARCH_E := 2.4
# The black cladding round each arch: its outer face's x, its depth out from the arch's edge.
const CLAD_OUT_F := 0.612
const CLAD_OUT_R := 0.618
const CLAD_D := 0.044
# The sills (and the bumpers' lower corners) are black below this height.
const SILL_LINE := 0.188

# The section above the side, keyframed along the car. Per row: z; top (the centre line); belt (the
# top of the side); sh_in, sh_up (the shoulder's top S lies sh_in inboard of the side's top and sh_up
# above it: over the cabin S is the window line, which rises toward the haunches); px, edge (the
# corner K: the bonnet's crease, converging on the nose, the A-pillar, the roof rail, the C-pillar's
# edge, the deck's edge); fillet (the rounding at K); ridge (a bulge down the centre of the top, none
# now); bow (the run from S to K bulging out). Over the bonnet K stands 2.5-3cm over S, so the fender
# tops fall away outward from the creases.
const KEYS := [
	# z       top    belt   sh_in  sh_up  px     edge   fillet ridge  bow
	[-1.150, 0.440, 0.392, 0.020, 0.010, 0.150, 0.432, 0.008, 0.000, 0.001],
	[-1.060, 0.452, 0.403, 0.024, 0.011, 0.185, 0.444, 0.008, 0.000, 0.002],
	[-0.960, 0.466, 0.416, 0.030, 0.012, 0.225, 0.458, 0.008, 0.000, 0.002],
	[-0.850, 0.480, 0.428, 0.034, 0.013, 0.268, 0.472, 0.008, 0.000, 0.002],
	[-0.720, 0.495, 0.441, 0.036, 0.014, 0.320, 0.487, 0.008, 0.000, 0.002],
	[-0.600, 0.505, 0.450, 0.039, 0.016, 0.370, 0.497, 0.009, 0.000, 0.002],
	[-0.480, 0.511, 0.457, 0.043, 0.019, 0.420, 0.504, 0.011, 0.000, 0.002],
	[-0.400, 0.515, 0.462, 0.046, 0.021, 0.460, 0.508, 0.013, 0.000, 0.002],
	[-0.330, 0.545, 0.464, 0.049, 0.022, 0.452, 0.528, 0.015, 0.000, 0.003],
	[-0.250, 0.580, 0.465, 0.052, 0.023, 0.442, 0.560, 0.017, 0.000, 0.004],
	[-0.160, 0.612, 0.466, 0.054, 0.024, 0.430, 0.592, 0.019, 0.000, 0.005],
	[-0.080, 0.636, 0.468, 0.056, 0.025, 0.420, 0.616, 0.021, 0.000, 0.005],
	[0.000, 0.650, 0.469, 0.058, 0.025, 0.413, 0.630, 0.022, 0.000, 0.005],
	[0.150, 0.659, 0.471, 0.061, 0.026, 0.405, 0.640, 0.022, 0.000, 0.005],
	[0.320, 0.656, 0.475, 0.066, 0.028, 0.397, 0.637, 0.022, 0.000, 0.005],
	[0.480, 0.643, 0.480, 0.073, 0.031, 0.387, 0.624, 0.022, 0.000, 0.004],
	[0.620, 0.622, 0.484, 0.079, 0.036, 0.377, 0.603, 0.022, 0.000, 0.004],
	[0.740, 0.597, 0.486, 0.081, 0.038, 0.368, 0.578, 0.022, 0.000, 0.004],
	[0.840, 0.566, 0.483, 0.079, 0.036, 0.364, 0.548, 0.022, 0.000, 0.003],
	[0.940, 0.532, 0.474, 0.072, 0.032, 0.368, 0.517, 0.020, 0.000, 0.003],
	[1.020, 0.514, 0.464, 0.062, 0.027, 0.378, 0.501, 0.018, 0.000, 0.002],
	[1.100, 0.505, 0.455, 0.050, 0.022, 0.388, 0.493, 0.016, 0.000, 0.002],
	[1.150, 0.500, 0.448, 0.042, 0.020, 0.380, 0.488, 0.014, 0.000, 0.001],
]
const KEY_NAMES := ["top", "belt", "sh_in", "sh_up", "px", "edge", "fillet", "ridge", "bow"]
# The bonnet's central bulge: its half-width.
const RIDGE_W := 0.20

# The air channel along each lower door: from GROOVE_Z.x, just behind the front arch, where it is
# deepest (its forward end a wall facing back: the outlet), it fades out by GROOVE_Z.y. Its edges at
# full depth (GROOVE_Y), the lower one rising GROOVE_RISE toward the rear, the upper one closing in.
const GROOVE_Z := Vector2(-0.405, 0.300)
const GROOVE_Y := Vector2(0.208, 0.258)
const GROOVE_DEPTH := 0.016
const GROOVE_RISE := 0.010
# Above the channel the side leans in toward its top, SIDE_TUCK in at the belt (less where the side is
# short, over the arches), so the doors catch the light in a gradient instead of reading as a slab.
const SIDE_TUCK := 0.012

# Points per segment of the half-section: the bottom, its corner, the side up to the channel, the
# channel's lower step, its back, its upper step, the side above it; the shoulder, the run to the
# corner, the corner's rounding, the top.
const SEGMENTS := [2, 3, 2, 1, 1, 1, 4, 5, 6, 5, 10]

# The greenhouse. The windscreen runs from the cowl to the header (WS_Z), the glass roof from just
# behind the header to the spoiler (ROOF_Z), the rear screen from under the spoiler to the deck
# (RG_Z); PAD keeps the glass off the corner's rounding (the pillars, the rails).
const PAD := 0.004
# The roof is glass too, but drawn as semi-gloss black (this much of the glass's mirror): as clear
# glass it mirrored the sky and read blue.
const ROOF_GLOSS := 0.35
const WS_Z := Vector2(-0.395, -0.090)
const ROOF_Z := Vector2(-0.072, 0.722)
const RG_Z := Vector2(0.752, 0.945)
# The side glass in side view (z, y): its front edge behind the A-pillar's foot, its line rising at
# the back to a point at the rail (the rail and the window line cut it above and below). The B-pillar
# between the doors' windows.
const DLO := [Vector2(-0.372, 0.40), Vector2(0.455, 0.40), Vector2(0.462, 0.502), Vector2(0.640, 0.612),
	Vector2(0.650, 0.75), Vector2(-0.372, 0.75)]
const B_PILLAR_Z := 0.100
# The C-pillar's vent: a black slash widening up into the roof's rail, from a point on the haunch's
# shoulder, parallel to the side glass's rising rear edge with a blade of body colour (2.3cm) between.
const VENT := [Vector2(0.455, 0.470), Vector2(0.766, 0.599), Vector2(0.703, 0.625)]
# Shut lines: the front door's leading edge, the rear door's back edge (round the arch, up to the
# window line); the flush handles (z of each, its height); the charging flap (right side).
const DOOR_F := -0.420
const REAR_DOOR_EDGE := [Vector2(0.398, 0.150), Vector2(0.398, 0.372), Vector2(0.455, 0.503)]
const HANDLES := [-0.070, 0.330]
const HANDLE_Y := 0.432
const FLAP := Vector3(0.855, 0.445, 0.019)

# The nose in front view (x, y). Its black openings are patches lying on the face (_face_patch): the
# face is nearly flat, so the detail map squeezes it round the tip into a few texels, and a painted
# grille crept up the fan of triangles there as a dark tent. The brow under the bonnet's leading edge
# joins the lamp housings at its ends (the LED blade along their top turning down as a fang to the
# corner intake, three small projectors under the blade); the corner intakes with their vanes; the
# lower grille with its fins. Quads run bottom left, bottom right, top right, top left. The chin is
# black below the sill line (the detail map).
const PATCH_OUT := 0.0025
const PATCH_BEVEL := 0.0015
const BROW_Y := Vector2(0.386, 0.399)
const LAMP_HOUSING := [Vector2(0.250, 0.373), Vector2(0.468, 0.367), Vector2(0.481, 0.401), Vector2(0.250, 0.402)]
const LAMP_BLADE := [Vector2(0.262, 0.3965), Vector2(0.440, 0.3955), Vector2(0.462, 0.3915), Vector2(0.473, 0.3800),
	Vector2(0.478, 0.3540)]
const LAMP_PROJECTORS := [Vector3(0.300, 0.382, 0.0060), Vector3(0.336, 0.381, 0.0060), Vector3(0.372, 0.380, 0.0060)]
const CORNER_INTAKE := [Vector2(0.368, 0.194), Vector2(0.490, 0.202), Vector2(0.472, 0.350), Vector2(0.362, 0.338)]
const CORNER_VANES := [0.398, 0.436]
const GRILLE := [Vector2(-0.330, 0.192), Vector2(0.330, 0.192), Vector2(0.298, 0.288), Vector2(-0.298, 0.288)]
const GRILLE_FINS := [0.214, 0.238, 0.262]
const EMBLEM_Y := 0.350
# The intakes' fins: a blade's section (thickness, then depth: mostly behind the face it stands on).
const FIN_PROFILE := [Vector2(-0.0018, -0.010), Vector2(0.0018, -0.010), Vector2(0.0018, 0.008),
	Vector2(-0.0018, 0.008)]
# The tail: the light bar's height (in a black band), the lower bumper black below TAIL_BLACK_Y.
const TAIL_BAR_Y := 0.440
# The bar's ends: round the tail's corner and down it, a fang like the headlamps'.
const TAIL_FANG := [Vector2(0.495, 0.440), Vector2(0.509, 0.4385), Vector2(0.516, 0.428), Vector2(0.519, 0.394)]
const TAIL_BLACK_Y := 0.312
# The spoiler at the roof's end: the z its blade starts from, its half-span.
const SPOILER_Z := 0.735
const SPOILER_SPAN := 0.352

# Tyres: low-profile (half the profile, bead to tread centre) on big rims.
const TYRE_HALF := [[-0.080, 0.140], [-0.086, 0.147], [-0.089, 0.158], [-0.0895, 0.170], [-0.087, 0.180],
	[-0.080, 0.1868], [-0.058, 0.1893], [0.0, 0.190]]
const RIM_R := 0.136
const SPOKES := 10

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.16, 0.16, 0.17)
const C_CLAD := Color(0.075, 0.075, 0.08)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.03, 0.03, 0.035)
const C_GLOSS := Color(0.02, 0.02, 0.022)
const C_TRIM := Color(0.10, 0.10, 0.11)
const C_STEEL := Color(0.14, 0.14, 0.15)
const C_ALLOY := Color(0.78, 0.79, 0.81)
const C_ALLOY_DARK := Color(0.42, 0.43, 0.45)
const C_DISC := Color(0.26, 0.26, 0.28)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_POCKET := Color(0.05, 0.05, 0.055)
const C_SPOKE := Color(0.07, 0.07, 0.075)
const C_TAILLAMP := Color(0.92, 0.05, 0.03)
const C_AMBER := Color(0.98, 0.58, 0.06)
const C_REVERSE := Color(0.90, 0.90, 0.88)
const C_BUMPER := Color(0.13, 0.13, 0.14)        # black plastic, as the detail map's black reads

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.15, "tail_z": 1.15, "belt_y": 0.462, "side_x": 0.50,
	"door_z": -0.160, "door_y": 0.335, "roundel_r": 0.075,
	"hood_z": -0.820, "hood_r": 0.065, "stripe_w": 0.070, "stripe_gap": 0.024,
}
const ANTENNA_POS := Vector3(0.30, 0.630, 0.50)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}

var _curve_cache := {}                    # z -> the upper curve's samples, for _upper_s()


func _init() -> void:
	nose_tip = -1.150
	nose_cap = 0.120
	nose_cap_y = 0.350
	nose_cap_exp = Vector2(2.0, 5.0)
	tail_tip = 1.150
	tail_cap = 0.050
	# The tips (where each cap's rings close) sit under parts that hide them: the nose's on the emblem,
	# the tail's in the black lower bumper's patch.
	tail_cap_y = 0.250
	tail_cap_exp = Vector2(3.0, 3.0)
	station_step = 0.025
	bottom_radius = 0.025
	fender_mat = CB.M_DARK
	fender_col = C_CLAD
	half_ring = 0
	for k in SEGMENTS:
		half_ring += k
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	setup_shell(knots)


## Stations (CarDesign's) plus rings close to each tip. Both caps are nearly flat faces (exponent 5 up
## and down), whose rings shrink to the tip within the last fraction of a millimetre, where
## CarDesign's stations leave one fan of triangles from the tip across the middle of the face.
func stations() -> PackedFloat64Array:
	var zs: PackedFloat64Array = super()
	for k in range(1, 10):
		var s: float = 0.1 * k
		zs.append(nose_tip + nose_cap * (1.0 - pow(1.0 - pow(s, nose_cap_exp.y), 1.0 / nose_cap_exp.y)))
		zs.append(tail_tip - tail_cap * (1.0 - pow(1.0 - pow(s, tail_cap_exp.y), 1.0 / tail_cap_exp.y)))
	zs.sort()
	var out := PackedFloat64Array()
	for z in zs:
		if out.is_empty() or z - out[out.size() - 1] > 1e-7:
			out.append(z)
	return out


## Where the body's surface is at (x, y), searching from the nose (or from the tail): its z. As
## CarDesign's, then bisected to the surface: in 2mm steps a point on the nearly flat face read
## up to 2mm behind it, and patches laid on it sank into the paint.
func shell_z(x: float, y: float, from_front: bool) -> float:
	var ax: float = absf(x)
	var z: float = nose_tip if from_front else tail_tip
	var dz: float = 0.003 if from_front else -0.003
	for k in 800:
		if _inside_half(section(z), ax, y):
			if k == 0:
				return z
			var lo: float = z - dz
			var hi: float = z
			for m in 16:
				var mid: float = (lo + hi) * 0.5
				if _inside_half(section(mid), ax, y):
					hi = mid
				else:
					lo = mid
			return hi
		z += dz
	return z


## The shell's bottom: level along the chin, the sills and the rear bumper, stepping up into an arch
## over each wheel.
static func _bot_knots() -> Array:
	var k := [[-1.150, 0.180], [-1.080, 0.166], [-1.000, NOSE_BOT]]
	for arch in [[AXLE_F, NOSE_BOT, SILL_BOT], [AXLE_R, SILL_BOT, TAIL_BOT]]:
		var az: float = arch[0]
		k.append([az - ARCH_RZ - 0.012, arch[1]])
		for s in 21:
			var t: float = s / 10.0 - 1.0
			k.append([az + ARCH_RZ * t, ARCH_CY + ARCH_RY * pow(maxf(1.0 - pow(absf(t), ARCH_E), 0.0), 1.0 / ARCH_E)])
		k.append([az + ARCH_RZ + 0.012, arch[2]])
	k.append([1.040, 0.214])
	k.append([1.150, 0.238])
	return k


static func _line(a: Vector2, c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, c])


static func _arc(c: Vector2, r: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 7:
		var a: float = lerpf(a0, a1, k / 6.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


## A quadratic Bézier from a over c to e, n + 1 points.
static func _bezier(a: Vector2, c: Vector2, e: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var t: float = float(k) / n
		pts.append(a.lerp(c, t).lerp(c.lerp(e, t), t))
	return pts


## The door's air channel at z, on a side running from s0 up to the belt: [depth, its lower edge, its
## upper edge]. Away from it the (empty) steps rest at one height on the side; they move to the
## channel's edges over 5cm either side of it, while it has no depth.
func _groove(z: float, s0: float, belt: float) -> Array:
	var rest: float = lerpf(s0, belt, 0.4)
	var f: float = clampf((z - GROOVE_Z.x) / (GROOVE_Z.y - GROOVE_Z.x), 0.0, 1.0)
	var y_lo: float = GROOVE_Y.x + GROOVE_RISE * f
	var y_hi: float = lerpf(GROOVE_Y.y, y_lo + 0.014, f * f)
	var d: float = GROOVE_DEPTH * clampf((z - GROOVE_Z.x) / 0.008, 0.0, 1.0) \
			* (1.0 - smoothstep(GROOVE_Z.x + 0.12, GROOVE_Z.y, z))
	var k: float = smoothstep(GROOVE_Z.x - 0.05, GROOVE_Z.x, z) * (1.0 - smoothstep(GROOVE_Z.y, GROOVE_Z.y + 0.05, z))
	y_lo = clampf(lerpf(rest, y_lo, k), s0, belt)
	y_hi = clampf(lerpf(rest, y_hi, k), y_lo, belt)
	return [minf(d, (y_hi - y_lo) / 0.8), y_lo, y_hi]


## The side's lean at z: Vector2(how far its top is tucked in from w, the slope dx/dy it leaves its
## top at, for the shoulder to carry on from).
func _side_lean(z: float) -> Vector2:
	var bot: float = prof["bot"].at(z)
	var belt: float = prof["belt"].at(z)
	var rb: float = minf(bottom_radius, (belt - bot) * 0.3)
	var h: float = belt - float(_groove(z, bot + rb, belt)[2])
	var tuck: float = SIDE_TUCK * clampf(h / 0.15, 0.0, 1.0)
	return Vector2(tuck, -2.0 * tuck / maxf(h, 0.01))


## The x of the side's top at z (where the shoulder starts).
func _w_top(z: float) -> float:
	return float(prof["w"].at(z)) - _side_lean(z).x


## The door's air channel at z, as section() lays it: [depth, its lower edge, its upper edge].
func _groove_at(z: float) -> Array:
	var bot: float = prof["bot"].at(z)
	var belt: float = prof["belt"].at(z)
	var rb: float = minf(bottom_radius, (belt - bot) * 0.3)
	return _groove(z, bot + rb, belt)


## The right half of the section at z (half_ring + 1 points, the bottom of the centre line to its
## top), caps applied: the bottom, its corner, the side stepping in and out round the door's air
## channel and leaning in above it, then the upper segments.
func section(z: float) -> PackedVector2Array:
	var bot: float = prof["bot"].at(z)
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	var rb: float = minf(bottom_radius, (belt - bot) * 0.3)
	var s0: float = bot + rb
	var g: Array = _groove(z, s0, belt)
	var d: float = g[0]
	var y_lo: float = g[1]
	var y_hi: float = g[2]
	var tuck: float = SIDE_TUCK * clampf((belt - y_hi) / 0.15, 0.0, 1.0)
	var lean := PackedVector2Array()
	for i in 9:
		var t: float = i / 8.0
		lean.append(Vector2(w - tuck * t * t, lerpf(y_hi, belt, t)))
	var segs := [
		_line(Vector2(0.0, bot), Vector2(w - rb, bot)),
		_arc(Vector2(w - rb, bot + rb), rb, -PI * 0.5, 0.0),
		_line(Vector2(w, s0), Vector2(w, y_lo)),
		_line(Vector2(w, y_lo), Vector2(w - d, y_lo + d * 0.45)),
		_line(Vector2(w - d, y_lo + d * 0.45), Vector2(w - d, y_hi - d * 0.30)),
		_line(Vector2(w - d, y_hi - d * 0.30), Vector2(w, y_hi)),
		lean,
	]
	segs.append_array(_upper_segments(z, w - tuck, belt, 0.0))
	var sec := PackedVector2Array([(segs[0] as PackedVector2Array)[0]])
	for k in segs.size():
		var rs: PackedVector2Array = CB.resample(segs[k], int(SEGMENTS[k]) + 1, 0.0)
		for m in range(1, rs.size()):
			sec.append(rs[m])
	var c: Array = _cap(z)
	var cap: Vector2 = c[0]
	if cap != Vector2.ONE:
		var cy: float = c[1]
		for k in sec.size():
			sec[k] = Vector2(sec[k].x * cap.x, cy + (sec[k].y - cy) * cap.y)
	return sec


## The corners of the section above the side at z: {s: the shoulder's top, k: the corner, t1 and t2:
## where its rounding starts and ends, top: the centre line's height}.
func _corners(z: float, w: float, belt: float) -> Dictionary:
	var sp := Vector2(w - float(prof["sh_in"].at(z)), belt + float(prof["sh_up"].at(z)))
	var top: float = prof["top"].at(z)
	var edge: float = clampf(prof["edge"].at(z), sp.y + 0.004, top)
	var px: float = minf(prof["px"].at(z), sp.x - 0.010)
	var k := Vector2(px, edge)
	var f: float = prof["fillet"].at(z)
	var t1: Vector2 = k + (sp - k).normalized() * minf(f, 0.45 * sp.distance_to(k))
	var tx: float = minf(f, 0.45 * px)
	var t2 := Vector2(px - tx, _crown_y(px - tx, z, k, top))
	return {"s": sp, "k": k, "t1": t1, "t2": t2, "top": top}


## The crowned top's height at x: the corner's height at its x, rising to the centre line, plus the
## bonnet's central bulge (a smooth bump RIDGE_W either side of the centre).
func _crown_y(x: float, z: float, k: Vector2, top: float) -> float:
	var ridge: float = clampf(prof["ridge"].at(z), 0.0, top - k.y)
	var q: float = x / k.x
	var r: float = maxf(1.0 - (x / RIDGE_W) * (x / RIDGE_W), 0.0)
	return k.y + (top - k.y - ridge) * (1.0 - q * q) + ridge * r * r


## Above the side, as segments (each starting where the last ended; w is the side's top): the
## shoulder, a cubic from the side's top, carrying on its lean, rolling in to S; the run from S to the
## corner's rounding, bowed out a little; the rounding (a quadratic through the sharp corner K); the
## crowned top across to the centre line.
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var c: Dictionary = _corners(z, w, belt)
	var sp: Vector2 = c["s"]
	var k: Vector2 = c["k"]
	var t1: Vector2 = c["t1"]
	var t2: Vector2 = c["t2"]
	var top: float = c["top"]
	var h1: float = (sp.y - belt) * 0.55
	var p0 := Vector2(w, belt)
	var p1 := Vector2(w + _side_lean(z).y * h1, belt + h1)
	var p2 := Vector2(lerpf(w, sp.x, 0.45), sp.y)
	var shoulder := PackedVector2Array()
	for i in 13:
		shoulder.append(p0.bezier_interpolate(p1, p2, sp, i / 12.0))
	var dir: Vector2 = (t1 - sp).normalized()
	var mid: Vector2 = (sp + t1) * 0.5 + Vector2(dir.y, -dir.x) * float(prof["bow"].at(z))
	var run := PackedVector2Array()
	for i in 13:
		var u: float = i / 12.0
		run.append(sp.lerp(mid, u).lerp(mid.lerp(t1, u), u))
	var crowned := PackedVector2Array()
	for i in 25:
		var x: float = t2.x * (1.0 - i / 24.0)
		crowned.append(Vector2(x, _crown_y(x, z, k, top)))
	return [shoulder, run, _bezier(t1, k, t2, 8), crowned]


## The cladding's section: a lip, a flat outer face standing proud of the body, a chamfer onto its
## top, which runs back into the body side; underneath, a flat liner in to the body side.
func _fender_section(xo: float, x_in: float, d: float) -> Array:
	return [
		[Vector2(xo - 0.012, 0.0), Vector2(xo - 0.002, 0.004), Vector2(xo + 0.001, 0.012), Vector2(xo + 0.002, 0.55 * d),
			Vector2(xo - 0.003, 0.85 * d), Vector2(xo - 0.016, d), Vector2(x_in + 0.025, d + 0.003),
			Vector2(x_in, d + 0.003)],
		[Vector2(xo - 0.012, 0.0), Vector2(x_in + 0.010, 0.0)],
	]


## A wheel arch's outline as the cladding's lip: the shell's bottom from the sill at the door end round
## over the wheel to the outer end, as 22 points spaced along it.
func _arch_lip(z_door: float, z_end: float) -> Array:
	var dense := PackedVector2Array()
	for k in 241:
		var z: float = lerpf(z_door, z_end, k / 240.0)
		dense.append(Vector2(z, prof["bot"].at(z)))
	var pts: PackedVector2Array = CB.resample(dense, 22, 0.0)
	var lip := []
	for p in pts:
		lip.append([p.x, p.y])
	return lip


# ============================================================================================
#  Body
# ============================================================================================

## Body mesh: the shell, the cladding, lamps, intakes, mirrors, the running gear in the arches, the
## spoiler and the tail's lamps and bumper.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	# The cladding: from the sill at the door end round the arch to its outer foot (taken on to the
	# bumper's bottom, it hung below it like a mud flap).
	build_fender(b, _arch_lip(AXLE_F + ARCH_RZ + 0.012, AXLE_F - ARCH_RZ), AXLE_F, HUB_Y, CLAD_OUT_F, CLAD_D, 0.06)
	build_fender(b, _arch_lip(AXLE_R - ARCH_RZ - 0.012, AXLE_R + ARCH_RZ), AXLE_R, HUB_Y, CLAD_OUT_R, CLAD_D, 0.06)
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Points on the nose (or tail) at the front-view (x, y) points of `line`, `out` proud of the surface
## along its normal, `n` samples along it.
func _on_face_line(line: Array, front: bool, out: float, n: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var total := 0.0
	for k in range(1, line.size()):
		total += (line[k] as Vector2).distance_to(line[k - 1])
	for s in n:
		var target: float = total * s / (n - 1)
		var k := 1
		var acc := 0.0
		while k < line.size() - 1 and acc + (line[k] as Vector2).distance_to(line[k - 1]) < target:
			acc += (line[k] as Vector2).distance_to(line[k - 1])
			k += 1
		var seg: float = (line[k] as Vector2).distance_to(line[k - 1])
		var p2: Vector2 = (line[k - 1] as Vector2).lerp(line[k], clampf((target - acc) / maxf(seg, 1e-6), 0.0, 1.0))
		var f: Array = face_frame(p2.x, p2.y, front)
		pts.append((f[0] as Vector3) + (f[1] as Vector3) * out)
	return pts


## A lamp tube: its UVs zeroed, so the headlamp material's reflector rings (drawn round the UV
## origin) stay off it.
func _lamp_tube(b, path: PackedVector3Array, r: float, mat: int, col: Color) -> void:
	var vb: int = b.vertex_count()
	b.tube(path, r, 8, mat, col, true, true)
	for k in range(vb, b.vertex_count()):
		b._uv[k] = Vector2.ZERO


## A patch lying on the nose's (front) or the tail's face over the front-view quad q (bottom left,
## bottom right, top right, top left), `out` proud of it, its border tucked just under the surface over
## the last PATCH_BEVEL so no edge shows: the black openings, which the detail map can't draw there.
func _face_patch(b, q: Array, front: bool, out: float, nu: int, nv: int, mat: int, col: Color) -> void:
	var us: PackedFloat32Array = _patch_steps(nu, PATCH_BEVEL / maxf((q[1] as Vector2).distance_to(q[0]), 0.01))
	var vs: PackedFloat32Array = _patch_steps(nv, PATCH_BEVEL / maxf((q[3] as Vector2).distance_to(q[0]), 0.01))
	var rows := []
	for i in vs.size():
		var row := PackedVector3Array()
		for j in us.size():
			var p2: Vector2 = (q[0] as Vector2).lerp(q[1], us[j]).lerp((q[3] as Vector2).lerp(q[2], us[j]), vs[i])
			var f: Array = face_frame(p2.x, p2.y, front)
			var rim: bool = i == 0 or i == vs.size() - 1 or j == 0 or j == us.size() - 1
			row.append((f[0] as Vector3) + (f[1] as Vector3) * (-0.001 if rim else out))
		rows.append(row)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, mat, col, false, false)
	b.orient_toward(vb, ib, Vector3.FORWARD if front else Vector3.BACK)


## A patch's grid steps from 0 to 1: n even ones, and one just inside each end (`e` in).
static func _patch_steps(n: int, e: float) -> PackedFloat32Array:
	var out := PackedFloat32Array([0.0, e])
	for k in range(1, n):
		out.append(float(k) / n)
	out.append(1.0 - e)
	out.append(1.0)
	return out


## A rounded box set on the nose's (front) or the tail's face at (x, y), turned with the face's normal
## there and `out` proud of it.
func _on_face(b, x: float, y: float, front: bool, h: Vector3, r: float, mat: int, col: Color, out: float) -> void:
	var f: Array = face_frame(x, y, front)
	var nrm: Vector3 = f[1]
	b.rbox(Transform3D(facing(nrm), (f[0] as Vector3) + nrm * out), h, r, 2, mat, col)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Arch liners: dark walls inside each arch (the front one clear of its tyre at full lock).
	for arch in [[AXLE_F, 0.300], [AXLE_R, 0.360]]:
		b.rbox(Transform3D(Basis(), Vector3(arch[1], 0.290, arch[0])), Vector3(0.004, 0.130, ARCH_RZ), 0.003, 1,
				CB.M_DARK, C_DARKER)
	# Running gear in each arch: two lower arms, the upright, a coil-over, the caliper on the disc.
	for az in [AXLE_F, AXLE_R]:
		for dz in [-0.075, 0.075]:
			b.tube(PackedVector3Array([Vector3(0.20, 0.205, az + dz), Vector3(0.44, 0.180, az)]), 0.010, 8, CB.M_DARK,
					C_STEEL, true, true)
		b.rbox(Transform3D(Basis(), Vector3(0.452, HUB_Y, az)), Vector3(0.014, 0.055, 0.028), 0.007, 1, CB.M_DARK, C_STEEL)
		coilover(b, Vector3(0.360, 0.205, az), Vector3(0.330, 0.400, az + 0.020), 0.013, 0.022, 6.0, C_ALLOY,
				C_ALLOY_DARK, C_CHROME, C_DARK)
		var ca := 0.85
		var cp := Vector3(WHEEL_X + 0.026, HUB_Y + cos(ca) * 0.100, az + sin(ca) * 0.100)
		b.rbox(Transform3D(Basis(Vector3.RIGHT, ca), cp), Vector3(0.015, 0.020, 0.040), 0.008, 2, CB.M_ANODISED,
				Color(1, 1, 1))
	# Headlamp: the black housing, the LED blade along its top (half sunk into it) turning down as a
	# fang to the corner intake, three small projectors under the blade.
	_face_patch(b, LAMP_HOUSING, true, PATCH_OUT, 12, 3, CB.M_DARK, C_DARKER)
	_lamp_tube(b, _on_face_line(LAMP_BLADE, true, -0.0008, 20), 0.0045, CB.M_HEADLAMP, Color(1, 1, 1))
	for l in LAMP_PROJECTORS:
		var f: Array = face_frame(l.x, l.y, true)
		var nrm: Vector3 = f[1]
		var c: Vector3 = (f[0] as Vector3) + nrm * 0.0025
		var vb: int = b.vertex_count()
		var ib: int = b.index_count()
		b.lathe(c, nrm, PackedVector2Array([Vector2(-0.004, l.z + 0.0016), Vector2(0.0015, l.z + 0.0016),
				Vector2(0.0015, l.z)]), 14, CB.M_DARK, C_TRIM)
		b.orient_away_from(vb, ib, c - nrm * 0.004)
		lens(b, c + nrm * 0.001, nrm, l.z, l.z * 0.3, 14)
	# The corner intake, vanes standing upright in it.
	_face_patch(b, CORNER_INTAKE, true, PATCH_OUT, 6, 8, CB.M_DARK, C_DARKER)
	for fx in CORNER_VANES:
		sweep(b, _on_face_line([Vector2(fx, 0.344), Vector2(fx + 0.006, 0.199)], true, 0.0, 8), Vector3.RIGHT,
				Vector3.FORWARD, PackedVector2Array(FIN_PROFILE), CB.M_ALLOY, C_ALLOY_DARK)
	# Mirror: a black pod on a stalk from the shoulder by the A-pillar's foot, its glass at the back, a
	# turn signal along its outer edge.
	var mz := -0.345
	var cm: Dictionary = _corners(mz, _w_top(mz), prof["belt"].at(mz))
	var sp: Vector2 = cm["s"]
	var foot := Vector3(sp.x + 0.008, sp.y - 0.003, mz)
	var head := Vector3(0.592, sp.y + 0.040, mz + 0.012)
	b.tube(PackedVector3Array([foot, foot.lerp(head, 0.5) + Vector3(0.0, 0.010, 0.0), head]), 0.0065, 6, CB.M_DARK,
			C_DARK, false, false)
	var mb := Basis(Vector3.UP, -0.12) * Basis(Vector3.BACK, 0.05)
	b.rbox(Transform3D(mb, head + Vector3(0.012, 0.004, 0.0)), Vector3(0.040, 0.019, 0.017), 0.012, 2, CB.M_DARK,
			C_GLOSS)
	b.rbox(Transform3D(mb, head + Vector3(0.014, 0.004, 0.0170)), Vector3(0.034, 0.014, 0.002), 0.002, 1,
			CB.M_CHROME, C_CHROME)
	b.rbox(Transform3D(mb, head + Vector3(0.048, 0.000, -0.010)), Vector3(0.004, 0.006, 0.006), 0.002, 1,
			CB.M_TAILLAMP, C_AMBER)
	# Tail: the light bar's end wrapping round the corner; a reflector and a reversing lamp low on the
	# black bumper; fins hanging under it.
	_lamp_tube(b, _on_face_line(TAIL_FANG, false, -0.0015, 12), 0.0062, CB.M_TAILLAMP, C_TAILLAMP)
	_on_face(b, 0.452, 0.272, false, Vector3(0.0045, 0.028, 0.003), 0.002, CB.M_TAILLAMP, C_TAILLAMP, 0.004)
	_on_face(b, 0.330, 0.290, false, Vector3(0.018, 0.0055, 0.003), 0.002, CB.M_TAILLAMP, C_REVERSE, 0.004)
	for x in [0.105, 0.245]:
		slab(b, PackedVector2Array([Vector2(1.040, 0.198), Vector2(1.136, 0.206), Vector2(1.136, 0.236),
				Vector2(1.040, 0.224)]), x, 0.006, CB.M_DARK, C_DARK)


func _centre_parts(b) -> void:
	# The tail's light bar across its face, in its black band.
	_lamp_tube(b, _on_face_line([Vector2(-0.500, TAIL_BAR_Y), Vector2(0.500, TAIL_BAR_Y)], false, -0.0015, 33),
			0.0062, CB.M_TAILLAMP, C_TAILLAMP)
	# The black lower bumper's middle as a patch: the detail map draws the rest, but round the tail's
	# tip it can't hold an edge.
	_face_patch(b, [Vector2(-0.470, 0.196), Vector2(0.470, 0.196), Vector2(0.470, TAIL_BLACK_Y + 0.003),
			Vector2(-0.470, TAIL_BLACK_Y + 0.003)], false, PATCH_OUT, 28, 4, CB.M_DARK, C_BUMPER)
	# The nose's brow, joining the lamp housings under the bonnet's leading edge; the lower grille.
	_face_patch(b, [Vector2(-0.252, BROW_Y.x), Vector2(0.252, BROW_Y.x), Vector2(0.252, BROW_Y.y),
			Vector2(-0.252, BROW_Y.y)], true, PATCH_OUT - 0.0007, 24, 2, CB.M_DARK, C_DARKER)
	_face_patch(b, GRILLE, true, PATCH_OUT, 26, 5, CB.M_DARK, C_DARKER)
	# The lower grille's fins: dark alloy blades across it, a divider down its middle.
	for y in GRILLE_FINS:
		sweep(b, _on_face_line([Vector2(-0.300, y), Vector2(0.300, y)], true, 0.0, 17), Vector3.UP, Vector3.FORWARD,
				PackedVector2Array(FIN_PROFILE), CB.M_ALLOY, C_ALLOY_DARK)
	sweep(b, _on_face_line([Vector2(0.0, 0.284), Vector2(0.0, 0.196)], true, 0.0, 6), Vector3.RIGHT, Vector3.FORWARD,
			PackedVector2Array(FIN_PROFILE), CB.M_ALLOY, C_ALLOY_DARK)
	# The splitter: a black blade under the nose following its plan.
	var path := PackedVector3Array()
	for k in 19:
		var x: float = lerpf(-0.480, 0.480, k / 18.0)
		path.append(Vector3(x, 0.160, shell_z(x, 0.188, true) - 0.006))
	sweep(b, path, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.004, 0.004), Vector2(0.090, 0.004),
			Vector2(0.090, -0.004), Vector2(-0.004, -0.004)]), CB.M_DARK, C_DARK)
	# The emblem on the nose: a chrome diamond with a smaller one in the accent colour.
	var ef: Array = face_frame(0.0, EMBLEM_Y, true)
	var en: Vector3 = ef[1]
	var eb: Basis = facing(en) * Basis(Vector3.BACK, PI * 0.25)
	b.rbox(Transform3D(eb, (ef[0] as Vector3) + en * 0.002), Vector3(0.014, 0.014, 0.003), 0.002, 1, CB.M_CHROME,
			C_CHROME)
	b.rbox(Transform3D(eb, (ef[0] as Vector3) + en * 0.0045), Vector3(0.008, 0.008, 0.002), 0.0015, 1, CB.M_ANODISED,
			Color(1, 1, 1))
	_spoiler(b)
	# The ducktail: a lip along the deck's trailing edge, kicked up.
	var lip := PackedVector3Array()
	for k in 15:
		var x: float = lerpf(-0.420, 0.420, k / 14.0)
		lip.append(Vector3(x, top_y(x, 1.120) - 0.003, 1.120))
	sweep(b, lip, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(0.0, -0.004), Vector2(0.030, 0.008),
			Vector2(0.030, 0.013), Vector2(0.0, 0.001)]), CB.M_PAINT, Color(1, 1, 1))


## The spoiler at the roof's end: a black blade lying on the roof, its trailing edge standing off over
## the rear screen, a strip of brake light under it.
func _spoiler(b) -> void:
	var path := PackedVector3Array()
	for k in 17:
		var x: float = lerpf(-SPOILER_SPAN, SPOILER_SPAN, k / 16.0)
		path.append(Vector3(x, top_y(x, SPOILER_Z) + 0.002, SPOILER_Z))
	sweep(b, path, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.040, -0.002), Vector2(-0.010, 0.005),
			Vector2(0.045, 0.010), Vector2(0.074, 0.010), Vector2(0.078, 0.005), Vector2(0.050, -0.002),
			Vector2(0.000, -0.005)]), CB.M_DARK, C_GLOSS)
	var light := PackedVector3Array()
	for k in 9:
		var x: float = lerpf(-0.110, 0.110, k / 8.0)
		light.append(Vector3(x, top_y(x, SPOILER_Z) + 0.002, SPOILER_Z + 0.066))
	_lamp_tube(b, light, 0.0028, CB.M_TAILLAMP, C_TAILLAMP)


# ============================================================================================
#  Wheels
# ============================================================================================

## A wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1): a
## low-profile tyre on a big rim of ten turbine spokes, its lip in the rim colour and its pockets
## black, the brake disc behind, a hub with five nuts and a cap ringed in the accent colour.
func build_wheel(b, side: float) -> void:
	tyre(b, TYRE_HALF, 48, C_RUBBER)
	var hw: float = -float(TYRE_HALF[0][0])
	var lip_x: float = hw + 0.004
	var face_x: float = lip_x - 0.020
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.012, RIM_R), Vector2(lip_x - 0.002, RIM_R + 0.006),
			Vector2(lip_x + 0.003, RIM_R + 0.004), Vector2(lip_x + 0.004, RIM_R - 0.003),
			Vector2(lip_x, RIM_R - 0.008)]), 48, CB.M_RIM, C_RIM, "out", Vector3(lip_x - 0.03, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x, RIM_R - 0.008), Vector2(face_x + 0.004, RIM_R - 0.012),
			Vector2(face_x, RIM_R - 0.016)]), 48, CB.M_DARK, C_POCKET, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(face_x, RIM_R - 0.016), Vector2(face_x - 0.006, RIM_R - 0.008),
			Vector2(-hw + 0.012, RIM_R - 0.006), Vector2(-hw + 0.004, RIM_R + 0.002)]), 48, CB.M_DARK, C_POCKET, "in")
	# Behind the spokes: a dark back, the brake disc.
	b.disc(Vector3(face_x - 0.052, 0.0, 0.0), Vector3.RIGHT, RIM_R - 0.012, 0.0, 32, CB.M_DARK, C_DARKER)
	b.disc(Vector3(face_x - 0.038, 0.0, 0.0), Vector3.RIGHT, RIM_R - 0.024, 0.042, 36, CB.M_ALLOY, C_DISC)
	for k in SPOKES:
		_turbine_spoke(b, TAU * k / SPOKES, 0.30, 0.034, RIM_R - 0.012, face_x + 0.014, face_x + 0.001, 0.0068,
				0.0105, 0.011)
	# The hub: a boss in the rim colour, five chrome nuts, a dark cap in a ring of the accent colour.
	var hx: float = face_x + 0.014
	wheel_lathe(b, PackedVector2Array([Vector2(hx - 0.012, 0.040), Vector2(hx + 0.003, 0.040),
			Vector2(hx + 0.008, 0.035)]), 24, CB.M_RIM, C_RIM, "out", Vector3(hx - 0.004, 0.0, 0.0))
	b.disc(Vector3(hx + 0.008, 0.0, 0.0), Vector3.RIGHT, 0.035, 0.0, 24, CB.M_RIM, C_RIM)
	for k in 5:
		var g: Array = wheel_frame(TAU * k / 5.0 + 0.3)
		bar(b, (g[0] as Vector3) * 0.0275 + Vector3(hx + 0.0105, 0.0, 0.0), Vector3(0.0025, 0.0033, 0.0033),
				CB.M_CHROME, C_CHROME)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(hx + 0.008, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.0215),
			Vector2(0.006, 0.0215), Vector2(0.007, 0.0185)]), 20, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(hx + 0.004, 0.0, 0.0))
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(hx + 0.008, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.0185),
			Vector2(0.0065, 0.016), Vector2(0.0095, 0.0)]), 20, CB.M_DARK, C_GLOSS)
	b.orient_away_from(vb, ib, Vector3(hx + 0.002, 0.0, 0.0))
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


## A turbine spoke at angle a, from the hub (radius r0, its face at x0) to the rim (r1, x1), curving
## `twist` radians ahead toward the rim, half-width w0 widening to w1, `th` thick: its face in the rim
## colour, its sides black.
func _turbine_spoke(b, a: float, twist: float, r0: float, r1: float, x0: float, x1: float, w0: float, w1: float,
		th: float) -> void:
	var n := 7
	var face_rows := []
	var sides := [[], []]
	var tg_sum := Vector3.ZERO
	for i in n + 1:
		var t: float = float(i) / n
		var f: Array = wheel_frame(a + twist * t * t)
		var rd: Vector3 = f[0]
		var tg: Vector3 = f[1]
		tg_sum += tg
		var half: float = lerpf(w0, w1, t)
		var c: Vector3 = rd * lerpf(r0, r1, t) + Vector3(lerpf(x0, x1, t), 0.0, 0.0)
		var pa: Vector3 = c + tg * half
		var pb: Vector3 = c - tg * half
		face_rows.append(PackedVector3Array([pa, pb]))
		(sides[0] as Array).append(PackedVector3Array([pa, pa - Vector3(th, 0.0, 0.0)]))
		(sides[1] as Array).append(PackedVector3Array([pb, pb - Vector3(th, 0.0, 0.0)]))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(face_rows, CB.M_RIM, C_RIM, false, false)
	b.orient_toward(vb, ib, Vector3.RIGHT)
	for s in 2:
		vb = b.vertex_count()
		ib = b.index_count()
		b.grid(sides[s], CB.M_DARK, C_SPOKE, false, false)
		b.orient_toward(vb, ib, tg_sum * (1.0 if s == 0 else -1.0))


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	return {
		"dlo": _inset(PackedVector2Array(DLO), 0.008),
		"vent": _inset(PackedVector2Array(VENT), 0.003),
	}


## Where p lies along its section's upper curve, in metres from the side's top: Vector4(s, s where the
## shoulder ends (S), where the corner's rounding starts (T1), where it ends (T2)). The curve
## (_upper_segments) is sampled once per z, which is one column of the detail map.
func _upper_s(p: Vector3) -> Vector4:
	if not _curve_cache.has(p.z):
		var segs: Array = _upper_segments(p.z, _w_top(p.z), prof["belt"].at(p.z), 0.0)
		var c_pts := PackedVector2Array()
		var c_acc := PackedFloat32Array()
		var c_marks := PackedFloat32Array()
		for seg in segs:
			for q in (seg as PackedVector2Array):
				if not c_pts.is_empty() and q.distance_squared_to(c_pts[c_pts.size() - 1]) < 1e-14:
					continue
				c_acc.append(0.0 if c_pts.is_empty() else c_acc[c_acc.size() - 1] + q.distance_to(c_pts[c_pts.size() - 1]))
				c_pts.append(q)
			c_marks.append(c_acc[c_acc.size() - 1])
		_curve_cache[p.z] = [c_pts, c_acc, c_marks]
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
	return Vector4(best, marks[0], marks[1], marks[2])


## A rounded intersection of two half-planes given as distances (negative inside), corner radius r.
static func _round_and(a: float, b: float, r: float) -> float:
	var q := Vector2(maxf(a + r, 0.0), maxf(b + r, 0.0))
	return q.length() + minf(maxf(a + r, b + r), 0.0) - r


## Distance from p to a polyline.
static func _sd_polyline(p: Vector2, line: Array) -> float:
	var best := 1e9
	for k in range(1, line.size()):
		var a: Vector2 = line[k - 1]
		var e: Vector2 = (line[k] as Vector2) - a
		var f: float = clampf((p - a).dot(e) / maxf(e.length_squared(), 1e-12), 0.0, 1.0)
		best = minf(best, (a + e * f).distance_to(p))
	return best


## The shell's shade (CarDesign): the door's air channel darkens and turns matte with its depth.
func _shell_shade(p: Vector3) -> float:
	var z: float = p.z
	if z > GROOVE_Z.x - 0.002 and z < GROOVE_Z.y:
		var w: float = prof["w"].at(z)
		var x: float = absf(p.x)
		var g: Array = _groove_at(z)
		if float(g[0]) > 0.0005 and p.y > float(g[1]) - 0.001 and p.y < float(g[2]) + 0.001 and x < w - 0.0005:
			return lerpf(1.0, 0.25, clampf((w - x) / GROOVE_DEPTH, 0.0, 1.0))
	return 1.0


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0
	var x: float = absf(p.x)
	var y: float = p.y
	var z: float = p.z
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	var szy := Vector2(z, y)
	var fxy := Vector2(x, y)
	# Underneath: the floor and the arches' ceilings (not up the faces at the tips, whose normals read
	# poorly there).
	if n.y < -0.55 and (y < 0.25 or (z > nose_tip + 0.04 and z < tail_tip - 0.04)):
		black = 1.0
	# The sills and the bumpers' lower corners: black below the sill line.
	if n.y < 0.5:
		black = maxf(black, _cover(y - SILL_LINE, fp))
	# The door's air channel: black inside, on its back and its steps.
	if z > GROOVE_Z.x - 0.004 and z < GROOVE_Z.y:
		var g: Array = _groove_at(z)
		if float(g[0]) > 0.0008 and y > float(g[1]) - 0.001 and y < float(g[2]) + 0.001 and x < w - 0.0006:
			black = 1.0
	# The greenhouse: the glass, the pillars and rails, the vent.
	if y > belt - 0.006 and z > WS_Z.x - 0.08 and z < RG_Z.y + 0.06 and n.y > -0.3:
		var u: Vector4 = _upper_s(p)
		var s: float = u.x
		var above: float = (u.y + 0.004) - s            # < 0: above the window line (the shoulder's top)
		var below_rail: float = s - (u.z - PAD)         # < 0: below the corner's rounding
		var inboard: float = (u.w + PAD) - s            # < 0: inboard of the rounding (on the top)
		# The rails and the pillars, the top between the panes: black from the cowl to the roof's end.
		var frame: float = maxf(-below_rail, maxf(WS_Z.x - 0.006 - z, z - (ROOF_Z.y + 0.014)))
		black = maxf(black, _cover(frame, fp))
		# The windscreen, the glass roof and the rear screen, inboard of the rounding.
		var ws_d: float = _round_and(inboard, maxf(WS_Z.x - z, z - WS_Z.y), 0.020)
		var roof_d: float = _round_and(inboard + 0.004, maxf(ROOF_Z.x - z, z - ROOF_Z.y), 0.016)
		var rg_d: float = _round_and(inboard, maxf(RG_Z.x - z, z - RG_Z.y), 0.020)
		glass = maxf(glass, _cover(minf(ws_d, rg_d), fp))
		glass = maxf(glass, ROOF_GLOSS * _cover(roof_d, fp))
		black = maxf(black, _cover(rg_d - 0.010, fp))
		# The side glass between the window line and the rail, in a black seal; the A-pillar's foot in
		# front of it black, the B-pillar across it.
		var dlo: float = maxf(_sd_rounded(szy, sh["dlo"]), maxf(above, below_rail))
		glass = maxf(glass, _cover(dlo, fp) * (1.0 - _cover(absf(z - B_PILLAR_Z) - 0.012, fp)))
		black = maxf(black, _cover(dlo - 0.008, fp))
		black = maxf(black, _cover(maxf(maxf(above, below_rail), maxf(WS_Z.x - 0.006 - z, z - DLO[0].x)), fp))
	# The C-pillar's vent, down to its point below the belt.
	if n.x > 0.15 and n.y > -0.3 and z > 0.40 and z < 0.80 and y > 0.44:
		black = maxf(black, _cover(_sd_rounded(szy, sh["vent"]), fp))
	# The nose: the chin black (the openings are patches, _face_patch).
	if n.z < -0.2 and z < -0.98:
		black = maxf(black, _cover(y - SILL_LINE - 0.004, fp))
	# The tail: the light bar's black band, the black lower bumper, the tailgate's shut line.
	if n.z > 0.25 and z > 1.0:
		black = maxf(black, _cover(maxf(absf(y - TAIL_BAR_Y) - 0.0135, x - 0.524), fp))
		black = maxf(black, _cover(maxf(absf(x - 0.517) - 0.009, maxf(0.384 - y, y - TAIL_BAR_Y)), fp) \
				* float(n.z > 0.5))
		black = maxf(black, _cover(y - TAIL_BLACK_Y, fp))
	# The sides: the doors' shut lines, the flush handles, the charging flap.
	if n.x > 0.5 and x > w - SIDE_TUCK - 0.004 and y > SILL_LINE and y < belt + 0.002:
		var sy: float = belt + float(prof["sh_up"].at(z))
		var d_door: float = _sd_polyline(szy, REAR_DOOR_EDGE)
		if y < sy:
			d_door = minf(d_door, minf(absf(z - DOOR_F), absf(z - B_PILLAR_Z)))
		gap = maxf(gap, _cover(d_door - 0.0018, fp))
		for hz in HANDLES:
			var d_h: float = _sd_box(szy - Vector2(hz, HANDLE_Y), Vector2(0.026, 0.0045)) - 0.003
			gap = maxf(gap, _cover(absf(d_h) - 0.0016, fp))
		if p.x > 0.0:
			gap = maxf(gap, _cover(absf(szy.distance_to(Vector2(FLAP.x, FLAP.y)) - FLAP.z) - 0.0018, fp))
	# The bonnet: its shut lines just inboard of the creases, and across in front of the cowl.
	if n.y > 0.4 and z < WS_Z.x - 0.005 and z > -1.09:
		var ck: Vector2 = (_corners(z, _w_top(z), belt) as Dictionary)["k"]
		var xg: float = ck.x - 0.012
		gap = maxf(gap, _cover(absf(x - xg) - 0.0018, fp))
		gap = maxf(gap, _cover(absf(z - (WS_Z.x - 0.022)) - 0.0018, fp) * float(x < xg))
	return Color(glass, gap, chrome, black)
