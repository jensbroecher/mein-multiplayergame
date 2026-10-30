# FulmineBuilder.gd
#
# The Fulmine: a fictional mid-engine supercar, an Italian wedge with a cab-forward greenhouse,
# chamfered surfaces and a knife-edge centre spine. A low shovel nose with a splitter and three
# mesh intakes; slim two-blade LED lamps in dark housings; a raked windscreen running back to a
# shallow roof; scissor-door shut lines in the detail map; big angular side intakes ahead of the
# rear wheels; wide rear haunches; a louvred engine cover; a wing on twin pylons over the tail;
# slim tail lamps over a black mesh panel; twin hexagonal central exhausts. Low-profile tyres,
# broader at the back (build_rear_wheel), on deep-dish directional turbine rims with an accent
# outer ring and a centre-lock nut.
#
# The shell is CarDesign's section loft. Above the side it is keyed along the car (KEYS): a small
# roll at the beltline, an angular chamfer (the flank facet, and the side glass over the cabin), a
# rounded shoulder crease, a shallow upper panel, an inner crease, and the crowned spine to the
# centre line. The arches are cut by lifting the shell's bottom over each wheel in a squared arch
# (_bot_knots), with dark liners inside. The detail map draws the glass (windscreen, side glass,
# rear window), the seals, the door cuts, the bonnet and engine lids, the intakes and the vents.
extends "res://CarDesign.gd"

# Wheels: staggered, the rears broader and taller (hub height = tyre radius).
const AXLE_F := -0.665
const AXLE_R := 0.675
const WHEEL_X_F := 0.444
const WHEEL_X_R := 0.468
const TYRE_R_F := 0.168
const TYRE_R_R := 0.182

# The side (w) along the car: broad and square at the nose, a slight waist at the doors, the
# widest haunches over the rear wheels, the tail cut off almost square. A supercar's nose is
# nearly as wide as its tail; a long taper is what makes a wedge read as a 1960s GT.
const W_KNOTS := [[-1.170, 0.400], [-1.140, 0.448], [-1.100, 0.478], [-1.050, 0.498],
	[-0.980, 0.512], [-0.900, 0.520], [-0.800, 0.524], [-0.660, 0.528], [-0.540, 0.524],
	[-0.400, 0.520], [-0.250, 0.522], [-0.080, 0.530], [0.100, 0.540], [0.280, 0.552],
	[0.450, 0.562], [0.600, 0.568], [0.675, 0.570], [0.820, 0.566], [0.960, 0.564],
	[1.060, 0.558], [1.130, 0.552]]

# The section above the side, keyframed along the car. Per row: z; belt (the top of the vertical
# side); rr (the roll at the beltline); sx, sy (the shoulder crease: the bonnet's fender edge, the
# roof rail over the cabin, the haunch's top over the rear wheels); bx, by (the inner crease);
# top (the spine's height on the centre line); ra, rb (the rounding at the shoulder and inner
# creases).
const KEYS := [
	# z       belt   rr     sx     sy     bx     by     top    ra     rb
	[-1.170, 0.240, 0.004, 0.250, 0.318, 0.150, 0.338, 0.340, 0.004, 0.003],
	[-1.120, 0.268, 0.006, 0.330, 0.338, 0.200, 0.354, 0.356, 0.005, 0.004],
	[-1.060, 0.294, 0.008, 0.385, 0.362, 0.240, 0.376, 0.378, 0.006, 0.004],
	[-1.000, 0.318, 0.010, 0.425, 0.382, 0.270, 0.394, 0.396, 0.006, 0.004],
	[-0.930, 0.344, 0.010, 0.455, 0.397, 0.290, 0.408, 0.410, 0.007, 0.004],
	[-0.860, 0.360, 0.010, 0.470, 0.408, 0.265, 0.420, 0.422, 0.007, 0.004],
	[-0.760, 0.366, 0.012, 0.478, 0.416, 0.250, 0.428, 0.430, 0.007, 0.004],
	[-0.660, 0.370, 0.012, 0.483, 0.421, 0.245, 0.433, 0.435, 0.007, 0.004],
	[-0.560, 0.372, 0.012, 0.480, 0.424, 0.240, 0.436, 0.438, 0.007, 0.004],
	[-0.470, 0.374, 0.012, 0.474, 0.428, 0.235, 0.439, 0.441, 0.007, 0.004],
	[-0.400, 0.376, 0.012, 0.462, 0.436, 0.230, 0.442, 0.444, 0.007, 0.004],
	[-0.320, 0.378, 0.012, 0.438, 0.452, 0.250, 0.466, 0.468, 0.008, 0.005],
	[-0.240, 0.380, 0.012, 0.424, 0.488, 0.235, 0.498, 0.500, 0.008, 0.005],
	[-0.160, 0.382, 0.012, 0.412, 0.516, 0.220, 0.528, 0.530, 0.008, 0.005],
	[-0.060, 0.384, 0.012, 0.404, 0.538, 0.210, 0.549, 0.551, 0.008, 0.005],
	[0.040, 0.386, 0.014, 0.406, 0.544, 0.208, 0.555, 0.557, 0.008, 0.005],
	[0.140, 0.388, 0.016, 0.414, 0.538, 0.220, 0.550, 0.552, 0.008, 0.005],
	[0.240, 0.394, 0.018, 0.430, 0.520, 0.245, 0.534, 0.538, 0.009, 0.005],
	[0.340, 0.402, 0.020, 0.450, 0.496, 0.280, 0.512, 0.518, 0.009, 0.006],
	[0.440, 0.412, 0.022, 0.466, 0.478, 0.305, 0.496, 0.500, 0.010, 0.006],
	[0.560, 0.418, 0.022, 0.478, 0.466, 0.315, 0.486, 0.490, 0.010, 0.006],
	[0.675, 0.420, 0.022, 0.482, 0.464, 0.318, 0.483, 0.486, 0.010, 0.006],
	[0.800, 0.416, 0.022, 0.478, 0.462, 0.316, 0.481, 0.484, 0.010, 0.006],
	[0.960, 0.408, 0.020, 0.470, 0.456, 0.308, 0.475, 0.480, 0.009, 0.006],
	[1.060, 0.396, 0.018, 0.452, 0.448, 0.290, 0.467, 0.472, 0.008, 0.005],
	[1.130, 0.376, 0.014, 0.414, 0.436, 0.240, 0.452, 0.460, 0.006, 0.004],
]
const KEY_NAMES := ["belt", "rr", "sx", "sy", "bx", "by", "top", "ra", "rb"]

# The wheel arches: per axle, its z, the arch's half-length, the base and rise of the arch (a
# superellipse of exponent e, concentric with the tyre), and the x of the well's inner wall.
const ARCHES := [
	# axle    half_l base  rise   e    liner x
	[AXLE_F, 0.182, 0.078, 0.270, 3.2, 0.360],
	[AXLE_R, 0.196, 0.084, 0.294, 3.2, 0.352],
]

# The windscreen's foot, the roof's back, the rear window's foot; the door's cuts and the sill.
const SCREEN_Z := -0.470
const ROOF_Z := -0.150
const REAR_GLASS_Z := 0.235
const DOOR_Z := Vector2(-0.360, 0.090)
const SILL_Y := 0.092
# Half-width of the shut lines drawn in the detail map.
const GAP := 0.0042
# The side intake ahead of the rear wheel: its polygon in side view (z, y).
const INTAKE := [Vector2(0.200, 0.300), Vector2(0.335, 0.346), Vector2(0.462, 0.368),
	Vector2(0.452, 0.126), Vector2(0.318, 0.100), Vector2(0.204, 0.140)]
# The engine cover's louvred panel: z from, to, half-width; the number of slats.
const DECK_PANEL := Vector3(0.315, 0.735, 0.228)
const LOUVRES := 8
# The bonnet's extractor vents, either side of the spine: |x| inner and outer, the centre z, the
# half-length along z.
const BONNET_VENT := Vector4(0.120, 0.320, -0.720, 0.100)

# Tyres: low-profile (half the profile, bead to tread centre).
const TYRE_FRONT := [[-0.080, 0.118], [-0.088, 0.123], [-0.093, 0.131], [-0.094, 0.144],
	[-0.091, 0.155], [-0.082, 0.1635], [-0.058, 0.1665], [0.0, 0.168]]
const TYRE_REAR := [[-0.100, 0.130], [-0.109, 0.135], [-0.115, 0.145], [-0.116, 0.160],
	[-0.112, 0.172], [-0.101, 0.179], [-0.072, 0.1815], [0.0, 0.182]]

# Palette (sRGB; the shader linearises vertex colours).
const C_RUBBER := Color(0.16, 0.16, 0.17)
const C_DARK := Color(0.055, 0.055, 0.062)
const C_DARKER := Color(0.025, 0.025, 0.03)
const C_MESH := Color(0.16, 0.16, 0.17)
const C_STEEL := Color(0.30, 0.30, 0.32)
const C_ALLOY_DARK := Color(0.45, 0.46, 0.48)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.50, 0.50, 0.52)
const C_TAILLAMP := Color(0.90, 0.05, 0.03)
const C_AMBER := Color(0.95, 0.55, 0.08)

## Paint layout for car_body.gdshader's patterns (see CarPaint.gd), in the cart frame.
const PAINT_LAYOUT := {
	"nose_z": -1.17, "tail_z": 1.13, "belt_y": 0.40, "side_x": 0.56,
	"door_z": -0.09, "door_y": 0.300, "roundel_r": 0.062,
	"hood_z": -0.760, "hood_r": 0.072, "stripe_w": 0.070, "stripe_gap": 0.022,
}
const ANTENNA_POS := Vector3(0.300, 0.480, 0.860)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X_F, TYRE_R_F, AXLE_F), "FR": Vector3(WHEEL_X_F, TYRE_R_F, AXLE_F),
	"RL": Vector3(-WHEEL_X_R, TYRE_R_R, AXLE_R), "RR": Vector3(WHEEL_X_R, TYRE_R_R, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.170
	nose_cap = 0.034
	nose_cap_y = 0.196
	nose_cap_exp = Vector2(5.0, 2.6)
	tail_tip = 1.130
	tail_cap = 0.020
	tail_cap_y = 0.300
	tail_cap_exp = Vector2(6.0, 4.0)
	station_step = 0.022
	refine_tol = 0.012
	# Bottom, bottom corner, side; roll, chamfer, shoulder rounding, panel, inner rounding, spine.
	segment_counts = [2, 3, 4, 4, 6, 3, 4, 3, 6]
	half_ring = 35
	bottom_radius = 0.024
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = _bot_knots()
	setup_shell(knots)


## The shell's bottom: flat along the splitter, the sills and the diffuser, stepping up into a
## squared arch over each wheel.
static func _bot_knots() -> Array:
	var k := []
	var n := 220
	for s in n + 1:
		var z: float = lerpf(-1.170, 1.130, float(s) / n)
		k.append([z, _bottom_base(z)])
	for a in ARCHES:
		var h := 27
		for s in h + 1:
			var t: float = lerpf(-1.0, 1.0, float(s) / h)
			var z: float = a[0] + a[1] * t
			var y: float = a[2] + a[3] * pow(maxf(1.0 - pow(absf(t), a[4]), 0.0), 1.0 / a[4])
			k.append([z, maxf(_bottom_base(z), y)])
	k.sort_custom(func(p, q): return p[0] < q[0])
	# Collapse duplicate z's (the arch's ends) so the profile stays single-valued.
	var out := []
	for p in k:
		if out.is_empty() or absf(float(p[0]) - float(out[out.size() - 1][0])) > 1e-5:
			out.append(p)
		else:
			out[out.size() - 1] = [p[0], maxf(float(p[1]), float(out[out.size() - 1][1]))]
	return out


## The bottom's base line, away from the arches: a small upsweep at the nose, the flat sill, the
## diffuser rising under the tail.
static func _bottom_base(z: float) -> float:
	if z < -1.100:
		return lerpf(0.095, 0.072, clampf((z + 1.170) / 0.070, 0.0, 1.0))
	if z < -0.900:
		return lerpf(0.072, 0.080, (z + 1.100) / 0.200)
	if z < 0.900:
		return lerpf(0.080, 0.086, smoothstep(-0.900, 0.900, z))
	return lerpf(0.086, 0.170, pow(clampf((z - 0.900) / 0.230, 0.0, 1.0), 1.8))


## The arch's ceiling at z, or -1 outside it (for the detail map's wheel wells).
static func _arch_top(z: float) -> float:
	var best := -1.0
	for a in ARCHES:
		var t: float = absf(z - a[0]) / a[1]
		if t < 1.0:
			best = maxf(best, a[2] + a[3] * pow(1.0 - pow(t, a[4]), 1.0 / a[4]))
	return best


static func _line(a: Vector2, c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, c])


## A quadratic Bézier from a over c to e, n + 1 points.
static func _bezier(a: Vector2, c: Vector2, e: Vector2, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var t: float = float(k) / n
		pts.append(a.lerp(c, t).lerp(c.lerp(e, t), t))
	return pts


## Above the side: a small roll from the beltline, the angular chamfer to the shoulder crease
## (rounded off), the shallow upper panel to the inner crease (rounded), and the spine to the
## centre line, crowned with a finite slope there so the mirrored halves meet in a crisp ridge.
func _upper_segments(z: float, w: float, belt: float, _top: float) -> Array:
	var rr: float = clampf(prof["rr"].at(z), 0.004, 0.05)
	var sx: float = minf(prof["sx"].at(z), w - 0.020)
	var sy: float = maxf(prof["sy"].at(z), belt + rr + 0.001)
	var bx: float = minf(prof["bx"].at(z), sx - 0.030)
	var by: float = maxf(prof["by"].at(z), sy + 0.001)
	var top: float = maxf(prof["top"].at(z), by + 0.001)
	var roll_end := Vector2(w - rr, belt + rr)
	var s_pt := Vector2(sx, sy)
	var b_pt := Vector2(bx, by)
	var ra: float = minf(prof["ra"].at(z), 0.35 * s_pt.distance_to(roll_end))
	var rb: float = minf(prof["rb"].at(z), 0.35 * minf(s_pt.distance_to(b_pt), bx))
	var roll := PackedVector2Array()
	for k in 7:
		var a: float = PI * 0.5 * k / 6.0
		roll.append(Vector2(w - rr + rr * cos(a), belt + rr * sin(a)))
	var a1: Vector2 = s_pt + (roll_end - s_pt).normalized() * ra
	var a2: Vector2 = s_pt + (b_pt - s_pt).normalized() * ra
	var b1: Vector2 = b_pt + (s_pt - b_pt).normalized() * rb
	var b2: Vector2 = b_pt + (Vector2(0.0, top) - b_pt).normalized() * rb
	var spine := PackedVector2Array()
	for k in 9:
		var t: float = k / 8.0
		spine.append(Vector2(lerpf(b2.x, 0.0, t), lerpf(b2.y, top, t * t)))
	return [roll, _line(roll_end, a1), _bezier(a1, s_pt, a2, 6), _line(a2, b1),
		_bezier(b1, b_pt, b2, 6), spine]


# ============================================================================================
#  Body
# ============================================================================================

## Body mesh: shell, lamps, intakes, skirts, liners and the aero.
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)


## Right-hand parts, mirrored to the left by build_body().
func _side_parts(b) -> void:
	# Headlamp: a dark angular housing on the nose's leading edge with two slim LED blades and a
	# short amber marker at its outer end.
	var hl: Array = face_frame(0.310, 0.316, true)
	var hb: Basis = facing(hl[1]) * Basis(Vector3.BACK, 0.085) * Basis(Vector3.RIGHT, 0.05)
	b.rbox(Transform3D(hb, hl[0]), Vector3(0.145, 0.038, 0.010), 0.009, 2, CB.M_DARK, C_DARKER)
	b.rbox(Transform3D(hb, hl[0] + hb * Vector3(0.0, 0.0, 0.001)), Vector3(0.134, 0.032, 0.007), 0.006, 1,
			CB.M_DARK, C_DARK)
	for k in 2:
		b.rbox(Transform3D(hb, hl[0] + hb * Vector3(0.0, -0.010 + 0.020 * k, 0.010)),
				Vector3(0.122 - 0.018 * k, 0.0038, 0.003), 0.0015, 1, CB.M_HEADLAMP, Color(1, 1, 1))
	b.rbox(Transform3D(hb, hl[0] + hb * Vector3(0.130, -0.011, 0.008)), Vector3(0.005, 0.007, 0.003),
			0.0015, 1, CB.M_TAILLAMP, C_AMBER)
	# Mirror: a small angular pod on a short stalk at the A-pillar's foot.
	var foot := Vector3(0.503, 0.402, -0.398)
	var head := Vector3(0.542, 0.434, -0.376)
	b.tube(PackedVector3Array([foot, head]), 0.006, 6, CB.M_DARK, C_DARK, false, false)
	var mb := Basis(Vector3.UP, -0.14) * Basis(Vector3.BACK, 0.05)
	b.rbox(Transform3D(mb, head + Vector3(0.004, 0.006, 0.002)), Vector3(0.036, 0.018, 0.016), 0.009, 2,
			CB.M_PAINT, Color(1, 1, 1))
	b.rbox(Transform3D(mb, head + Vector3(0.007, 0.006, 0.0185)), Vector3(0.030, 0.013, 0.002), 0.002, 1,
			CB.M_CHROME, C_CHROME)
	# Tail lamp: a dark housing across the tail's shoulder with two red blades.
	var tl: Array = face_frame(0.330, 0.386, false)
	var tb: Basis = facing(tl[1]) * Basis(Vector3.BACK, 0.04)
	b.rbox(Transform3D(tb, tl[0]), Vector3(0.150, 0.024, 0.009), 0.007, 2, CB.M_DARK, C_DARKER)
	for k in 2:
		b.rbox(Transform3D(tb, tl[0] + tb * Vector3(0.0, -0.0055 + 0.011 * k, 0.009)),
				Vector3(0.134, 0.0034, 0.003), 0.0015, 1, CB.M_TAILLAMP, C_TAILLAMP)
	# Dark liner closing each wheel well inside.
	for a in ARCHES:
		_arch_liner(b, a[0], a[1], a[5])
	# The black rocker blade between the arches.
	_side_blade(b, -0.440, 0.220, 0.086, 0.086, 0.001, 0.014, CB.M_DARK, C_DARK)
	# The body-colour lip along the side intake's upper edge, and a fin at its trailing edge.
	_side_blade(b, 0.205, 0.458, 0.306, 0.360, 0.004, 0.009, CB.M_PAINT, Color(1, 1, 1))
	_side_blade(b, 0.452, 0.464, 0.130, 0.350, 0.004, 0.010, CB.M_PAINT, Color(1, 1, 1))
	# Three dark-alloy strakes standing in the intake, to give the black recess some depth.
	for fz in [0.270, 0.340, 0.410]:
		var fw: float = prof["w"].at(fz)
		b.rbox(Transform3D(Basis(), Vector3(fw + 0.001, 0.223, fz)), Vector3(0.009, 0.092, 0.0045),
				0.0025, 1, CB.M_ALLOY, C_ALLOY_DARK)


## A vertical ribbon inside an arch: the well's inner wall, following the shell's bottom.
func _arch_liner(b, axle: float, half: float, x: float) -> void:
	var rows := []
	for i in 13:
		var z: float = axle + lerpf(-half + 0.014, half - 0.014, i / 12.0)
		rows.append(PackedVector3Array([Vector3(x, 0.052, z), Vector3(x, prof["bot"].at(z), z)]))
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(rows, CB.M_DARK, C_DARKER, false, false)
	b.orient_toward(vb, ib, Vector3.RIGHT)


## A blade lying on the right flank, swept along z: `out` from the body's side, `half_h` tall.
func _side_blade(b, z0: float, z1: float, y0: float, y1: float, out: float, half_h: float, mat: int,
		col: Color) -> void:
	var path := PackedVector3Array()
	for k in 9:
		var f: float = k / 8.0
		var z: float = lerpf(z0, z1, f)
		path.append(Vector3(prof["w"].at(z) + out, lerpf(y0, y1, f), z))
	sweep(b, path, Vector3.RIGHT, Vector3.UP, PackedVector2Array([Vector2(-0.014, -half_h),
			Vector2(0.002, -half_h * 0.75), Vector2(0.002, half_h * 0.75), Vector2(-0.014, half_h)]),
			mat, col)


## A flat plate on the nose's face: `pts` in (x, y), each projected onto the shell and pushed `off`
## along the face's normal, fanned from a projected centre so it hugs the nose's curvature.
func _nose_plate(b, pts: Array, off: float, mat: int, col: Color) -> void:
	var c := Vector2.ZERO
	for v in pts:
		c += v
	c /= pts.size()
	var nsum := Vector3.ZERO
	var ids := []
	for v in pts:
		nsum += (face_frame(v.x, v.y, true)[1] as Vector3)
	var fc: Array = face_frame(c.x, c.y, true)
	nsum += fc[1]
	var nrm: Vector3 = nsum.normalized()
	var ci: int = b.vertex((fc[0] as Vector3) + nrm * off, nrm, mat, col)
	for v in pts:
		var f: Array = face_frame(v.x, v.y, true)
		ids.append(b.vertex((f[0] as Vector3) + (f[1] as Vector3) * off, nrm, mat, col))
	for k in ids.size():
		b.tri(ci, ids[k], ids[(k + 1) % ids.size()])


func _centre_parts(b) -> void:
	# Front splitter: a plate following the nose's plan, with a fence at each end.
	var path := PackedVector3Array()
	for k in 9:
		var x: float = lerpf(-0.470, 0.470, k / 8.0)
		var z: float = -1.178 + 0.060 * pow(absf(x) / 0.470, 2.4)
		path.append(Vector3(x, 0.070, z))
	sweep(b, path, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.004, 0.004), Vector2(0.080, 0.004),
			Vector2(0.080, -0.004), Vector2(-0.004, -0.004)]), CB.M_DARK, C_DARK)
	for sx in [-1.0, 1.0]:
		slab(b, PackedVector2Array([Vector2(-1.180, 0.058), Vector2(-1.096, 0.058), Vector2(-1.062, 0.090),
				Vector2(-1.166, 0.094)]), 0.470 * sx, 0.006, CB.M_DARK, C_DARK)
	# Front intakes: a wide hexagonal central mouth and a big angular corner intake on each side,
	# both black plates with vertical fins, and a body-colour centre blade in the mouth.
	_nose_plate(b, [Vector2(-0.148, 0.232), Vector2(0.148, 0.232), Vector2(0.170, 0.180),
			Vector2(0.120, 0.148), Vector2(-0.120, 0.148), Vector2(-0.170, 0.180)],
			0.006, CB.M_DARK, C_DARKER)
	for k in 4:
		var fx: float = -0.102 + 0.068 * k
		var f: Array = face_frame(fx, 0.190, true)
		bar(b, (f[0] as Vector3) - (f[1] as Vector3) * 0.014, Vector3(0.0025, 0.033, 0.005),
				CB.M_DARK, C_MESH)
	var fb: Array = face_frame(0.0, 0.190, true)
	var fbb: Basis = facing(fb[1])
	b.rbox(Transform3D(fbb, fb[0] + fbb * Vector3(0.0, 0.0, 0.012)), Vector3(0.012, 0.078, 0.006), 0.004, 1,
			CB.M_PAINT, Color(1, 1, 1))
	for sx in [-1.0, 1.0]:
		_nose_plate(b, [Vector2(0.238 * sx, 0.238), Vector2(0.400 * sx, 0.252),
				Vector2(0.410 * sx, 0.170), Vector2(0.252 * sx, 0.155)],
				0.006, CB.M_DARK, C_DARKER)
		for k in 3:
			var cx: float = (0.286 + 0.052 * k) * sx
			var f: Array = face_frame(cx, 0.205, true)
			bar(b, (f[0] as Vector3) - (f[1] as Vector3) * 0.014, Vector3(0.0025, 0.038, 0.005),
					CB.M_DARK, C_MESH)
	# Engine cover: painted slats across the black panel behind the rear window.
	for k in LOUVRES:
		var z: float = DECK_PANEL.x + 0.020 + (DECK_PANEL.y - DECK_PANEL.x - 0.040) * k / (LOUVRES - 1)
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.42), Vector3(0.0, top_y(0.0, z) + 0.006, z)),
				Vector3(DECK_PANEL.z - 0.014, 0.0026, 0.010), 0.002, 1, CB.M_PAINT, Color(1, 1, 1))
	# Wing: the plane (in the paint), its endplates and two blade pylons.
	var wing_path := PackedVector3Array([Vector3(-0.448, 0.556, 1.070), Vector3(0.448, 0.556, 1.070)])
	sweep(b, wing_path, Vector3.BACK, Vector3.UP, PackedVector2Array([Vector2(-0.046, -0.006),
			Vector2(-0.046, 0.004), Vector2(0.032, 0.011), Vector2(0.056, 0.008), Vector2(0.054, 0.001),
			Vector2(0.000, -0.009)]), CB.M_PAINT, Color(1, 1, 1))
	for sx in [-1.0, 1.0]:
		slab(b, PackedVector2Array([Vector2(1.006, 0.520), Vector2(1.124, 0.531), Vector2(1.128, 0.586),
				Vector2(1.006, 0.572)]), 0.450 * sx, 0.009, CB.M_DARK, C_DARK)
		var x: float = 0.235 * sx
		var foot := Vector3(x, top_y(absf(x), 0.955) - 0.004, 0.955)
		var head := Vector3(x, 0.548, 1.062)
		b.rbox(Transform3D(Basis(Vector3.RIGHT, atan2(1.062 - 0.955, 0.548 - foot.y)), foot.lerp(head, 0.5)),
				Vector3(0.006, foot.distance_to(head) * 0.5 + 0.012, 0.016), 0.004, 1, CB.M_DARK, C_DARK)
	# Rear valance: a wide black mesh band with bars, between the tail lamps and the exhausts.
	var tg: Array = face_frame(0.0, 0.245, false)
	var tgb: Basis = facing(tg[1])
	b.rbox(Transform3D(tgb, tg[0]), Vector3(0.300, 0.045, 0.008), 0.008, 2, CB.M_DARK, C_DARKER)
	for k in 6:
		bar(b, (tg[0] as Vector3) + tgb * Vector3(0.0, -0.034 + 0.0136 * k, 0.008), Vector3(0.284, 0.0020, 0.003),
				CB.M_DARK, C_MESH)
	# Twin hexagonal central exhausts, set low in the black bumper.
	for sx in [-1.0, 1.0]:
		var ep := Vector3(0.078 * sx, 0.168, 1.158)
		b.tube(PackedVector3Array([Vector3(0.078 * sx, 0.168, 0.990), ep]), 0.033, 6, CB.M_ALLOY, C_ALLOY_DARK,
				false, false)
		b.disc(ep - Vector3(0.0, 0.0, 0.004), Vector3.BACK, 0.027, 0.0, 6, CB.M_DARK, C_DARKER)
		b.lathe(ep + Vector3(0.0, 0.0, -0.002), Vector3.BACK, PackedVector2Array([Vector2(0.0, 0.034),
				Vector2(0.005, 0.034), Vector2(0.005, 0.028), Vector2(0.001, 0.027)]), 6, CB.M_CHROME, C_CHROME)
	# Diffuser under the tail, with fins.
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.30), Vector3(0.0, 0.100, 1.060)), Vector3(0.440, 0.006, 0.072),
			0.004, 1, CB.M_DARK, C_DARK)
	for k in 5:
		b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.30), Vector3(-0.290 + 0.145 * k, 0.103, 1.060)),
				Vector3(0.004, 0.024, 0.068), 0.002, 1, CB.M_DARK, C_DARKER)
	# Fuel filler on the right rear quarter, on the chamfer above the intake.
	var fdir := Vector3(0.447, 0.894, 0.0).normalized()
	var fc := Vector3(0.510, 0.448, 0.560)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(fc, fdir, PackedVector2Array([Vector2(0.0, 0.024), Vector2(0.005, 0.024), Vector2(0.007, 0.018),
			Vector2(0.007, 0.0)]), 18, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, fc - fdir * 0.01)


# ============================================================================================
#  Wheels
# ============================================================================================

## A front wheel centred on the origin, axle along X, its face toward +X (side = 1) or -X (side = -1).
func build_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_FRONT, 0.118, 0.026)


## A rear wheel: the broader tyre, its rim's face set a little deeper (a deeper dish).
func build_rear_wheel(b, side: float) -> void:
	_wheel(b, side, TYRE_REAR, 0.130, 0.032)


## A low-profile tyre (half profile `half`) on a deep-dish directional turbine rim of radius rim_r,
## its blades set `dish` in from the lip: ten twisted blades, an accent ring on the lip and a
## centre-lock nut in the accent colour.
func _wheel(b, side: float, half: Array, rim_r: float, dish: float) -> void:
	tyre(b, half, 48, C_RUBBER)
	var hw: float = -float(half[0][0])
	var lip_x: float = hw + 0.004
	var face_x: float = lip_x - dish
	# Rim: the outer lip, the dish down to the blade face, the barrel behind.
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x - 0.010, rim_r), Vector2(lip_x - 0.001, rim_r + 0.005),
			Vector2(lip_x + 0.003, rim_r + 0.004), Vector2(lip_x + 0.005, rim_r - 0.004),
			Vector2(lip_x + 0.001, rim_r - 0.009)]), 48, CB.M_RIM, C_RIM, "out", Vector3(lip_x - 0.03, 0.0, 0.0))
	wheel_lathe(b, PackedVector2Array([Vector2(lip_x + 0.001, rim_r - 0.009), Vector2(face_x + 0.003, rim_r - 0.013),
			Vector2(face_x, rim_r - 0.017)]), 48, CB.M_RIM, C_RIM_BARREL, "+x")
	wheel_lathe(b, PackedVector2Array([Vector2(face_x, rim_r - 0.017), Vector2(face_x - 0.006, rim_r - 0.008),
			Vector2(-hw + 0.010, rim_r - 0.004), Vector2(-hw + 0.004, rim_r + 0.002)]), 48, CB.M_RIM, C_RIM_BARREL,
			"in")
	# The accent ring on the lip, facing out.
	b.disc(Vector3(lip_x + 0.0015, 0.0, 0.0), Vector3.RIGHT, rim_r + 0.0035, rim_r - 0.011, 48, CB.M_ANODISED,
			Color(1, 1, 1))
	# Behind the blades: a dark back and the drilled brake disc.
	b.disc(Vector3(face_x - 0.032, 0.0, 0.0), Vector3.RIGHT, rim_r - 0.010, 0.0, 32, CB.M_DARK, C_DARKER)
	b.disc(Vector3(face_x - 0.024, 0.0, 0.0), Vector3.RIGHT, rim_r - 0.030, 0.042, 32, CB.M_ALLOY, C_ALLOY_DARK)
	# Ten directional turbine blades, twisted the same way, wider at the rim.
	for k in 10:
		spoke(b, TAU * k / 10.0, 0.38, 0.040, rim_r - 0.009, face_x - 0.014, face_x + 0.014, 0.010, 0.016,
				0.007, CB.M_RIM, C_RIM)
	# Hub, then the centre-lock nut: a hex in the accent colour, a chrome cap.
	wheel_lathe(b, PackedVector2Array([Vector2(face_x - 0.006, 0.042), Vector2(face_x + 0.008, 0.042),
			Vector2(face_x + 0.014, 0.035)]), 24, CB.M_RIM, C_RIM, "out", Vector3(face_x, 0.0, 0.0))
	b.disc(Vector3(face_x + 0.014, 0.0, 0.0), Vector3.RIGHT, 0.035, 0.0, 24, CB.M_RIM, C_RIM)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(face_x + 0.014, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.028),
			Vector2(0.014, 0.028), Vector2(0.016, 0.024)]), 6, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(face_x + 0.008, 0.0, 0.0))
	b.disc(Vector3(face_x + 0.030, 0.0, 0.0), Vector3.RIGHT, 0.023, 0.0, 6, CB.M_ANODISED, Color(1, 1, 1))
	vb = b.vertex_count()
	ib = b.index_count()
	b.lathe(Vector3(face_x + 0.030, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([Vector2(0.0, 0.012),
			Vector2(0.004, 0.011), Vector2(0.007, 0.0)]), 16, CB.M_CHROME, C_CHROME)
	b.orient_away_from(vb, ib, Vector3(face_x + 0.028, 0.0, 0.0))
	if side < 0.0:
		# Built facing +X; the left wheels face -X.
		b.mirror_in_place()


# ============================================================================================
#  Detail map
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	shapes["intake"] = _inset(PackedVector2Array(INTAKE), 0.014)
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var black := 0.0
	var x: float = absf(p.x)
	var z: float = p.z
	var w: float = prof["w"].at(z)
	var belt: float = prof["belt"].at(z)
	var rr: float = prof["rr"].at(z)
	var sx: float = prof["sx"].at(z)
	var sy: float = prof["sy"].at(z)
	var bx: float = prof["bx"].at(z)
	# The underside.
	if n.y < -0.55:
		black = 1.0
	# Side glass on the chamfer facet: a trapezoid raked back with the A-pillar and in again at
	# the B-pillar.
	if n.x > 0.28 and p.y > belt and p.y < sy + 0.02 and z > -0.46 and z < 0.26:
		var lo: float = belt + rr + 0.006
		var hi: float = sy - 0.016
		var up: float = clampf((p.y - lo) / maxf(hi - lo, 0.010), 0.0, 1.0)
		var front: float = lerpf(SCREEN_Z, -0.170, up)
		var back: float = lerpf(0.085, 0.015, up)
		var d: float = maxf(maxf(lo - p.y, p.y - hi), maxf(front - z, z - back))
		d = maxf(d, (sx + 0.010) - x)
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.014, fp))
	# Windscreen: the top between the A-pillars, its foot sweeping back toward them.
	if n.y > 0.40 and z > SCREEN_Z - 0.06 and z < ROOF_Z + 0.02:
		var pillar: float = sx - 0.100
		var foot: float = SCREEN_Z + 0.045 * pow(clampf(x / maxf(pillar, 0.05), 0.0, 1.0), 2.0)
		var d: float = maxf(maxf(x - pillar, foot - z), z - ROOF_Z)
		glass = maxf(glass, _cover(d, fp))
		black = maxf(black, _cover(d - 0.009, fp))
	# Rear window: the top from the roof's back down to the engine cover, narrowing at the back.
	if n.y > 0.40 and z > 0.000 and z < REAR_GLASS_Z + 0.02:
		var taper: float = 1.0 - 0.22 * clampf(z / REAR_GLASS_Z, 0.0, 1.0)
		var pillar_r: float = (sx - 0.060) * taper
		var d_r: float = maxf(maxf(x - pillar_r, 0.0 - z), z - REAR_GLASS_Z)
		glass = maxf(glass, _cover(d_r, fp))
		black = maxf(black, _cover(d_r - 0.009, fp))
	# Engine cover: the black louvred panel.
	if n.y > 0.45 and z > DECK_PANEL.x and z < DECK_PANEL.y and x < DECK_PANEL.z:
		black = 1.0
	# The roof panel between the screens is black carbon, tying the canopy together.
	if n.y > 0.55 and z > ROOF_Z - 0.012 and z < 0.008 and x < sx - 0.028:
		black = 1.0
	# Bonnet extractor vents: black slots either side of the spine.
	if n.y > 0.40 and absf(x - (BONNET_VENT.x + BONNET_VENT.y) * 0.5) < (BONNET_VENT.y - BONNET_VENT.x) * 0.5:
		if absf(z - BONNET_VENT.z) < BONNET_VENT.w + 0.012:
			var vent: float = _sd_box(Vector2(x - (BONNET_VENT.x + BONNET_VENT.y) * 0.5,
					z - BONNET_VENT.z), Vector2((BONNET_VENT.y - BONNET_VENT.x) * 0.5, BONNET_VENT.w)) - 0.008
			var slots: float = absf(fposmod(z - BONNET_VENT.z + BONNET_VENT.w, 0.030) - 0.015) - 0.006
			black = maxf(black, _cover(vent, fp) * _cover(slots, fp))
			gap = maxf(gap, _cover(absf(vent) - 0.002, fp) * _cover(vent + 0.004, fp))
	# Side intake ahead of the rear wheel, with its body-colour blade and mesh slats.
	if n.x > 0.30 and z > 0.190 and z < 0.480 and p.y > 0.09 and p.y < 0.380:
		var di: float = _sd_rounded(Vector2(z, p.y), sh["intake"])
		black = maxf(black, _cover(di, fp))
		if p.y > 0.150 and p.y < 0.330:
			var slat: float = absf(fposmod(p.y - 0.145, 0.042) - 0.021) - 0.0035
			gap = maxf(gap, _cover(di + 0.004, fp) * _cover(slat, fp))
	# The nose's lower face and the tail's lower face are black.
	if n.z < -0.45 and p.y < 0.170 and z < -1.03:
		black = maxf(black, 1.0)
	if n.z > 0.45 and z > 1.050 and p.y < 0.225:
		black = maxf(black, 1.0)
	# Door shut lines: the front and rear cuts and the sill on the flank, the cuts carried up
	# across the chamfer to the glass (a scissor door's raked rear cut).
	if n.x > 0.30 and p.y < belt + 0.06 and p.y > SILL_Y - 0.02:
		if z > DOOR_Z.x and z < DOOR_Z.y:
			var dz: float = minf(absf(z - DOOR_Z.x), absf(z - DOOR_Z.y))
			gap = maxf(gap, _cover(dz - GAP, fp))
		if z > DOOR_Z.x - 0.003 and z < DOOR_Z.y + 0.003:
			gap = maxf(gap, _cover(absf(p.y - SILL_Y) - GAP, fp))
	elif n.y > 0.25 and n.x > 0.20 and z > DOOR_Z.x - 0.01 and z < DOOR_Z.y + 0.01:
		var dz2: float = minf(absf(z - DOOR_Z.x), absf(z - DOOR_Z.y))
		gap = maxf(gap, _cover(dz2 - GAP, fp))
	# The beltline's shut line under the side glass.
	if n.x > 0.35 and z > DOOR_Z.x - 0.01 and z < DOOR_Z.y + 0.01:
		gap = maxf(gap, _cover(absf(p.y - (belt + rr)) - 0.0028, fp))
	# Bonnet lid: its edge along the shoulder crease and its front and cowl lines.
	if n.y > 0.42 and z < -0.32:
		var edge: float = sx - 0.058
		if z > -1.02 and z < -0.440:
			gap = maxf(gap, _cover(absf(x - edge) - GAP, fp))
			gap = maxf(gap, _cover(absf(z + 1.005) - GAP, fp) * float(x < edge))
	# Engine lid: its edge round the louvred panel.
	if n.y > 0.42 and z > 0.26:
		var de: float = maxf(maxf(z - (DECK_PANEL.y + 0.020), (DECK_PANEL.x - 0.020) - z),
				x - (DECK_PANEL.z + 0.020))
		gap = maxf(gap, _cover(absf(de) - GAP, fp))
	# The fuel filler's ring on the right rear quarter.
	if n.x > 0.4 and p.x > 0.0 and z > 0.48 and z < 0.64 and p.y > 0.38 and p.y < 0.52:
		gap = maxf(gap, _cover(absf(Vector2(z - 0.560, p.y - 0.448).length() - 0.026) - 0.003, fp))
	return Color(glass, gap, 0.0, black)
