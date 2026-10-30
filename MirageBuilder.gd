# MirageBuilder.gd
#
# The Mirage: an all-terrain rally hypercar / Dakar dune supercar.
# A low-slung, razor-sharp supercar coupe body mounted on long-travel trophy buggy suspension:
# high ground clearance, exposed double wishbones and coilover dampers with accent springs,
# wide-track all-terrain tires on concave split 5-spoke sport rims with visible brake calipers.
#
# Angular body styling inspired by modern off-road supercar concepts:
# - Low, pointed wedge nose with sculpted hood air extractors and predatory chevron LED headlights
# - Ultra-wide track with long exposed tubular A-arms and tall coilovers visible between body and wheels
# - High-riding, angular geometric fender winglets floating above the tires
# - Fastback coupe canopy with steeply raked windshield, triangular quarter windows and ducktail rear spoiler
# - Full-width razor-sharp red LED light blade across the rear tail
# - Aggressive rear rally diffuser with vertical aero vanes, twin exhaust ports and heavy-duty skid plates
# - Distinct two-tone styling: metallic silver bodywork over dark composite rocker panels and wheel well liners
extends "res://CarDesign.gd"

# Wheels: wide track for desert stability, long travel clearance
const WHEEL_X := 0.585
const AXLE_F := -0.780
const AXLE_R := 0.650
const HUB_Y := 0.285

# Tub half-width (w) along the car (z):
# Very slim at nose (-1.14 to -0.46) to expose front suspension A-arms and shocks!
const W_KNOTS := [
	[-1.140, 0.210], [-1.040, 0.250], [-0.900, 0.295], [-0.780, 0.320], [-0.600, 0.345],
	[-0.460, 0.385], [-0.200, 0.420], [ 0.100, 0.440], [ 0.350, 0.450], [ 0.650, 0.425],
	[ 0.800, 0.385], [ 0.920, 0.335], [ 1.000, 0.285]
]

# Tub bottom (bot) along the car: high-clearance belly (29-35cm off ground)
const BOT_KNOTS := [
	[-1.140, 0.350], [-1.040, 0.320], [-0.900, 0.295], [-0.780, 0.290], [-0.600, 0.285],
	[-0.460, 0.280], [-0.100, 0.280], [ 0.200, 0.280], [ 0.450, 0.285], [ 0.650, 0.290],
	[ 0.800, 0.300], [ 0.920, 0.330], [ 1.000, 0.360]
]

# Section keyframes along the car:
# z: position along car
# belt: height of vertical side / rocker top
# sx, sy: shoulder crease position (wide hip / hood edge)
# rx, ry: roof rail / A-pillar corner position
# top: center line top height
# crown: dome / dish of top surface (+ dome, - dish)
const KEYS := [
	# z       belt    sx     sy     rx     ry     top    crown
	[-1.140, 0.350, 0.200, 0.355, 0.090, 0.360, 0.355, -0.004], # Chisel nose tip
	[-1.040, 0.365, 0.235, 0.385, 0.130, 0.395, 0.390, -0.006],
	[-0.900, 0.390, 0.280, 0.430, 0.180, 0.445, 0.440, -0.008],
	[-0.780, 0.410, 0.305, 0.465, 0.215, 0.485, 0.480, -0.008], # Front axle plane
	[-0.600, 0.435, 0.330, 0.505, 0.245, 0.530, 0.525, -0.006],
	[-0.460, 0.460, 0.355, 0.540, 0.265, 0.580, 0.575,  0.002], # Cowl / windshield base
	[-0.300, 0.480, 0.380, 0.570, 0.255, 0.670, 0.680,  0.010], # Windshield mid
	[-0.120, 0.495, 0.395, 0.590, 0.240, 0.730, 0.750,  0.012], # Roof header
	[ 0.060, 0.505, 0.405, 0.600, 0.235, 0.745, 0.762,  0.012], # Mid canopy peak
	[ 0.220, 0.515, 0.410, 0.610, 0.230, 0.735, 0.748,  0.010], # Rear glass start
	[ 0.450, 0.530, 0.415, 0.615, 0.225, 0.695, 0.705,  0.008], # Fastback slope
	[ 0.650, 0.540, 0.410, 0.620, 0.215, 0.655, 0.660,  0.005], # Rear axle / haunch peak
	[ 0.800, 0.545, 0.375, 0.625, 0.205, 0.635, 0.640,  0.004], # Rear deck
	[ 0.920, 0.535, 0.330, 0.630, 0.185, 0.655, 0.660,  0.006], # Spoiler upsweep
	[ 1.000, 0.520, 0.280, 0.635, 0.155, 0.675, 0.680,  0.008], # Ducktail trailing edge
]
const KEY_NAMES := ["belt", "sx", "sy", "rx", "ry", "top", "crown"]

# Tires: High-performance rally-raid carcass with aggressive tread blocks
const TYRE_HALF := [
	[-0.110, 0.155], [-0.120, 0.168], [-0.126, 0.188], [-0.127, 0.208], [-0.124, 0.228],
	[-0.115, 0.244], [-0.098, 0.255], [-0.060, 0.259], [0.0, 0.260]
]
const TREAD_ROWS := 24
const BLOCK_H := 0.014

# Palette (sRGB; shader linearises vertex colours)
const C_RUBBER := Color(0.20, 0.20, 0.21)
const C_DARK := Color(0.06, 0.06, 0.065)
const C_DARKER := Color(0.022, 0.022, 0.025)
const C_CARBON := Color(0.075, 0.075, 0.08)
const C_STEEL := Color(0.14, 0.14, 0.15)
const C_ALLOY := Color(0.82, 0.83, 0.85)
const C_ALLOY_DARK := Color(0.44, 0.45, 0.47)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_RIM := Color(1, 1, 1)
const C_RIM_BARREL := Color(0.40, 0.41, 0.43)
const C_TAILLAMP := Color(0.98, 0.04, 0.03)
const C_AMBER := Color(0.98, 0.58, 0.06)

## Paint layout for car_body.gdshader's patterns
const PAINT_LAYOUT := {
	"nose_z": -1.14, "tail_z": 1.00, "belt_y": 0.46, "side_x": 0.44,
	"door_z": -0.05, "door_y": 0.45, "roundel_r": 0.080,
	"hood_z": -0.78, "hood_r": 0.070, "stripe_w": 0.060, "stripe_gap": 0.022,
}
const ANTENNA_POS := Vector3(0.20, 0.760, 0.16)
const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F), "FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R), "RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}


func _init() -> void:
	nose_tip = -1.140
	nose_cap = 0.028
	nose_cap_y = 0.355
	nose_cap_exp = Vector2(5.5, 3.2)
	tail_tip = 1.000
	tail_cap = 0.025
	tail_cap_y = 0.540
	tail_cap_exp = Vector2(4.2, 3.0)
	# Half-ring segment counts: [bottom, corner, side, lower_shoulder, upper_shoulder, roof_corner, top]
	segment_counts = [2, 3, 4, 4, 5, 5, 8]
	half_ring = 31
	bottom_radius = 0.025
	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	setup_shell(knots)


## The section above the beltline: sculpted shoulder crease, raked glass tumblehome, rounded roof rail, crowned canopy/hood.
func _upper_segments(z: float, w: float, belt: float, top: float) -> Array:
	var sx: float = minf(prof["sx"].at(z), w - 0.005)
	var sy: float = maxf(prof["sy"].at(z), belt + 0.005)
	var rx: float = minf(prof["rx"].at(z), sx - 0.015)
	var ry: float = maxf(prof["ry"].at(z), sy + 0.010)
	var crown: float = prof["crown"].at(z)

	# 1. Belt to shoulder crease: angled muscular tumble
	var shoulder := PackedVector2Array()
	for k in 5:
		var t: float = float(k) / 4.0
		shoulder.append(Vector2(lerpf(w, sx, t), lerpf(belt, sy, t)))

	# 2. Shoulder to roof corner / upper rail: raked side glass / A-pillar
	var glass_side := PackedVector2Array()
	for k in 6:
		var t: float = float(k) / 5.0
		glass_side.append(Vector2(lerpf(sx, rx, t), lerpf(sy, ry, t)))

	# 3. Roof corner / rail rounding
	var r_fillet := 0.018
	var rail := PackedVector2Array()
	for k in 6:
		var a: float = PI * 0.5 * k / 5.0
		rail.append(Vector2(rx - r_fillet * (1.0 - cos(a)), ry + r_fillet * sin(a)))

	# 4. Crowned top from rail in to centreline (0, top)
	var top_pts := PackedVector2Array()
	var x_in: float = rx - r_fillet
	for k in 9:
		var t: float = float(k) / 8.0
		var x: float = lerpf(x_in, 0.0, t)
		var bump: float = crown * sin(t * PI * 0.5)
		top_pts.append(Vector2(x, lerpf(ry + r_fillet, top, t) + bump))

	return [
		PackedVector2Array([shoulder[0], shoulder[2], shoulder[4]]),
		glass_side,
		rail,
		top_pts
	]


## Builds the full body mesh
func build_body(b) -> void:
	build_shell(b)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()
	_side_parts(b)
	b.mirror_x(v0, i0)
	_centre_parts(b)
	_cockpit(b)


## Right-hand details, mirrored to the left side
func _side_parts(b) -> void:
	# -------------------------------------------------------------------------
	# 1. Front Long-Travel Suspension (EXPOSED IN FULL VIEW)
	# -------------------------------------------------------------------------
	var knuckle_x := 0.475
	var k_fwd := AXLE_F
	# Lower tubular A-arm
	b.tube(PackedVector3Array([Vector3(0.14, 0.255, k_fwd - 0.14), Vector3(knuckle_x - 0.01, 0.235, k_fwd)]), 0.012, 8, CB.M_DARK, C_STEEL, true, true)
	b.tube(PackedVector3Array([Vector3(0.14, 0.255, k_fwd + 0.14), Vector3(knuckle_x - 0.01, 0.235, k_fwd)]), 0.012, 8, CB.M_DARK, C_STEEL, true, true)
	# Upper tubular A-arm
	b.tube(PackedVector3Array([Vector3(0.16, 0.385, k_fwd - 0.10), Vector3(knuckle_x - 0.01, 0.360, k_fwd)]), 0.010, 8, CB.M_DARK, C_STEEL, true, true)
	b.tube(PackedVector3Array([Vector3(0.16, 0.385, k_fwd + 0.10), Vector3(knuckle_x - 0.01, 0.360, k_fwd)]), 0.010, 8, CB.M_DARK, C_STEEL, true, true)
	# Knuckle upright block & spindle
	b.rbox(Transform3D(Basis(), Vector3(knuckle_x, HUB_Y, k_fwd)), Vector3(0.018, 0.075, 0.032), 0.008, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(knuckle_x, HUB_Y, k_fwd), Vector3(WHEEL_X - 0.02, HUB_Y, k_fwd)]), 0.016, 10, CB.M_ALLOY, C_ALLOY_DARK, false, true)
	# Drive half-shaft
	b.tube(PackedVector3Array([Vector3(0.12, 0.280, k_fwd), Vector3(knuckle_x - 0.01, HUB_Y, k_fwd)]), 0.012, 8, CB.M_DARK, C_STEEL, false, false)
	# Steering tie rod
	b.tube(PackedVector3Array([Vector3(0.15, 0.300, k_fwd + 0.10), Vector3(knuckle_x - 0.01, 0.290, k_fwd + 0.06)]), 0.008, 6, CB.M_ALLOY, C_ALLOY_DARK, false, false)
	# Tall high-travel coilover shock (accent color spring!)
	coilover(b, Vector3(0.365, 0.245, k_fwd - 0.015), Vector3(0.200, 0.540, k_fwd + 0.025), 0.018, 0.030, 7.5, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)

	# -------------------------------------------------------------------------
	# 2. Rear Long-Travel Suspension (EXPOSED)
	# -------------------------------------------------------------------------
	var k_rear := AXLE_R
	# Lower trailing wishbone
	b.tube(PackedVector3Array([Vector3(0.16, 0.265, k_rear - 0.25), Vector3(knuckle_x - 0.01, 0.245, k_rear)]), 0.013, 8, CB.M_DARK, C_STEEL, true, true)
	b.tube(PackedVector3Array([Vector3(0.16, 0.265, k_rear + 0.12), Vector3(knuckle_x - 0.01, 0.245, k_rear)]), 0.013, 8, CB.M_DARK, C_STEEL, true, true)
	# Upper camber link
	b.tube(PackedVector3Array([Vector3(0.18, 0.420, k_rear - 0.10), Vector3(knuckle_x - 0.01, 0.370, k_rear)]), 0.011, 8, CB.M_DARK, C_STEEL, true, true)
	# Knuckle & axle
	b.rbox(Transform3D(Basis(), Vector3(knuckle_x, HUB_Y, k_rear)), Vector3(0.018, 0.076, 0.034), 0.008, 1, CB.M_DARK, C_STEEL)
	b.tube(PackedVector3Array([Vector3(knuckle_x, HUB_Y, k_rear), Vector3(WHEEL_X - 0.02, HUB_Y, k_rear)]), 0.016, 10, CB.M_ALLOY, C_ALLOY_DARK, false, true)
	b.tube(PackedVector3Array([Vector3(0.14, 0.290, k_rear), Vector3(knuckle_x - 0.01, HUB_Y, k_rear)]), 0.013, 8, CB.M_DARK, C_STEEL, false, false)
	# Rear coilover shock
	coilover(b, Vector3(0.375, 0.255, k_rear + 0.025), Vector3(0.220, 0.555, k_rear - 0.025), 0.019, 0.032, 8.0, C_ALLOY, C_ALLOY_DARK, C_CHROME, C_DARK)

	# -------------------------------------------------------------------------
	# 3. High Floating Angular Fender Winglets (Fighter-Jet Carbon Style)
	# -------------------------------------------------------------------------
	_build_floating_winglet(b, AXLE_F, 0.250, 0.570, 0.550, 0.018, true)
	_build_floating_winglet(b, AXLE_R, 0.280, 0.585, 0.580, 0.020, false)

	# -------------------------------------------------------------------------
	# 4. Razor-Sharp Slanted Chevron Headlight Blade (cleanly layered, no Z-fighting)
	# -------------------------------------------------------------------------
	var hl_pos := Vector3(0.190, 0.412, -1.042)
	var hl_dir := Vector3(0.15, -0.06, -0.99).normalized()
	var hl_basis := facing(hl_dir)
	# Recessed dark carbon housing (depth 0.010 -> front face at local z = +0.010)
	b.rbox(Transform3D(hl_basis, hl_pos), Vector3(0.055, 0.022, 0.010), 0.004, 1, CB.M_DARK, C_DARKER)
	# Piercing horizontal LED blade (center +0.010, depth 0.005 -> front face at +0.015, 5mm proud of housing)
	b.rbox(Transform3D(hl_basis, hl_pos + hl_basis.z * 0.010), Vector3(0.040, 0.006, 0.005), 0.003, 1, CB.M_HEADLAMP, Color(1, 1, 1))
	# Angled outer chevron accent blade (center +0.010, depth 0.005 -> front face at +0.015, 5mm proud of housing)
	b.rbox(Transform3D(hl_basis * Basis(Vector3.FORWARD, 0.42), hl_pos + hl_basis.x * 0.038 + hl_basis.z * 0.010), Vector3(0.006, 0.018, 0.005), 0.002, 1, CB.M_HEADLAMP, Color(1, 1, 1))

	# -------------------------------------------------------------------------
	# 5. Sculpted Aerodynamic Wing Mirrors
	# -------------------------------------------------------------------------
	var mirror_c := Vector3(0.360, 0.595, -0.210)
	# Sleek carbon stalk
	b.tube(PackedVector3Array([Vector3(0.320, 0.565, -0.210), mirror_c]), 0.008, 8, CB.M_DARK, C_CARBON, true, false)
	# Aerodynamic painted shell
	var mir_xf := Transform3D(Basis(Vector3.UP, -0.18) * Basis(Vector3.RIGHT, 0.06), mirror_c + Vector3(0.038, 0.012, 0.0))
	b.rbox(mir_xf, Vector3(0.036, 0.018, 0.022), 0.007, 2, CB.M_PAINT, Color(1, 1, 1))
	# Mirror reflective face
	b.rbox(mir_xf * Transform3D(Basis(), Vector3(0.0, 0.0, 0.018)), Vector3(0.030, 0.014, 0.003), 0.003, 1, CB.M_CHROME, C_CHROME)

	# -------------------------------------------------------------------------
	# 6. Lower Door / Rocker Aerodynamic Inset
	# -------------------------------------------------------------------------
	b.rbox(Transform3D(Basis(), Vector3(0.380, 0.290, -0.06)), Vector3(0.020, 0.018, 0.280), 0.006, 1, CB.M_DARK, C_CARBON)

	# -------------------------------------------------------------------------
	# 7. Rear Exhaust Tip & Aero Winglet
	# -------------------------------------------------------------------------
	var ex_c := Vector3(0.110, 0.425, 0.985)
	b.tube(PackedVector3Array([ex_c + Vector3(0, 0, -0.07), ex_c + Vector3(0, 0, 0.035)]), 0.020, 14, CB.M_ALLOY, C_ALLOY, false, false)
	b.tube(PackedVector3Array([ex_c + Vector3(0, 0, -0.06), ex_c + Vector3(0, 0, 0.036)]), 0.016, 12, CB.M_DARK, C_DARKER, false, false)
	# Side aero fin on rear quarter
	b.rbox(Transform3D(Basis(), Vector3(0.325, 0.540, 0.940)), Vector3(0.006, 0.045, 0.060), 0.004, 1, CB.M_DARK, C_CARBON)


## High floating angular fender winglets (Carbon composite)
func _build_floating_winglet(b, axle_z: float, half_len: float, flare_x: float, winglet_y: float, thick: float, front: bool) -> void:
	var z_front := axle_z - half_len
	var z_rear := axle_z + half_len
	var mount_x := 0.330 if front else 0.380

	# 3-segment angular floating blade
	var pts_outer := [
		Vector3(flare_x - 0.035, winglet_y - 0.045, z_front),
		Vector3(flare_x,         winglet_y,         axle_z),
		Vector3(flare_x - 0.025, winglet_y - 0.035, z_rear)
	]
	var pts_inner := [
		Vector3(mount_x, winglet_y - 0.020, z_front + 0.04),
		Vector3(mount_x, winglet_y + 0.025, axle_z),
		Vector3(mount_x, winglet_y - 0.015, z_rear - 0.04)
	]

	# Build upper carbon surface and lower dark composite liner
	for k in 2:
		var o0: Vector3 = pts_outer[k]
		var o1: Vector3 = pts_outer[k + 1]
		var i0: Vector3 = pts_inner[k]
		var i1: Vector3 = pts_inner[k + 1]
		var o0_top := Vector3(o0.x, o0.y + thick, o0.z)
		var o1_top := Vector3(o1.x, o1.y + thick, o1.z)
		var i0_top := Vector3(i0.x, i0.y + thick, i0.z)
		var i1_top := Vector3(i1.x, i1.y + thick, i1.z)

		# Upper carbon composite face (M_DARK)
		b.quad(
			b.vertex(o0_top, Vector3.UP, CB.M_DARK, C_CARBON),
			b.vertex(o1_top, Vector3.UP, CB.M_DARK, C_CARBON),
			b.vertex(i1_top, Vector3.UP, CB.M_DARK, C_CARBON),
			b.vertex(i0_top, Vector3.UP, CB.M_DARK, C_CARBON)
		)
		# Outer chamfer edge (M_DARK)
		b.quad(
			b.vertex(o0, Vector3.RIGHT, CB.M_DARK, C_CARBON),
			b.vertex(o1, Vector3.RIGHT, CB.M_DARK, C_CARBON),
			b.vertex(o1_top, Vector3.RIGHT, CB.M_DARK, C_CARBON),
			b.vertex(o0_top, Vector3.RIGHT, CB.M_DARK, C_CARBON)
		)
		# Lower dark composite face (M_DARK)
		b.quad(
			b.vertex(i0, Vector3.DOWN, CB.M_DARK, C_DARK),
			b.vertex(i1, Vector3.DOWN, CB.M_DARK, C_DARK),
			b.vertex(o1, Vector3.DOWN, CB.M_DARK, C_DARK),
			b.vertex(o0, Vector3.DOWN, CB.M_DARK, C_DARK)
		)

	# Structural carbon support bracket to body
	b.tube(PackedVector3Array([Vector3(mount_x - 0.03, winglet_y - 0.05, axle_z), Vector3(flare_x - 0.04, winglet_y - 0.01, axle_z)]), 0.010, 6, CB.M_DARK, C_CARBON, true, true)


## Centerline components (front skid plate, hood extractors, rear light blade, diffuser)
func _centre_parts(b) -> void:
	# -------------------------------------------------------------------------
	# 1. Front Chisel Bash Guard & Tubular Skid Frame
	# -------------------------------------------------------------------------
	var skid_angle := 0.32
	var skid_xf := Transform3D(Basis(Vector3.RIGHT, skid_angle), Vector3(0.0, 0.295, -1.040))
	# Brushed alloy plate ramping up to meet the lower chisel chin
	b.rbox(skid_xf, Vector3(0.180, 0.007, 0.100), 0.005, 1, CB.M_ALLOY, C_ALLOY)
	# Lower central intake cavity with dark mesh
	var mesh_c := Vector3(0.0, 0.340, -1.065)
	b.rbox(Transform3D(Basis(), mesh_c), Vector3(0.140, 0.026, 0.016), 0.005, 1, CB.M_DARK, C_DARKER)
	for k in 4:
		bar(b, mesh_c + Vector3(0, -0.016 + 0.011 * k, 0.010), Vector3(0.130, 0.002, 0.002), CB.M_DARK, C_CARBON)

	# Rugged tubular bull-nose frame bar
	b.tube(_rounded([
		Vector3(-0.16, 0.310, -1.02), Vector3(-0.13, 0.340, -1.07),
		Vector3( 0.13, 0.340, -1.07), Vector3( 0.16, 0.310, -1.02)
	], 0.03), 0.012, 8, CB.M_ALLOY, C_ALLOY, true, true)

	# Red recovery tow points
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(Basis(), Vector3(0.08 * sx, 0.300, -1.060)), Vector3(0.010, 0.014, 0.022), 0.004, 1, CB.M_ANODISED, Color(1, 1, 1))

	# -------------------------------------------------------------------------
	# 2. Sleek Recessed Hood Air Extractor Vents
	# -------------------------------------------------------------------------
	for sx in [-1.0, 1.0]:
		var vent_pos := Vector3(0.110 * sx, 0.465, -0.780)
		var vent_xf := Transform3D(Basis(Vector3.RIGHT, 0.22), vent_pos)
		b.rbox(vent_xf, Vector3(0.040, 0.004, 0.055), 0.003, 1, CB.M_DARK, C_CARBON)
		for k in 2:
			bar(b, vent_pos + vent_xf.basis * Vector3(0.0, 0.003, -0.025 + 0.030 * k), Vector3(0.034, 0.002, 0.003), CB.M_DARK, C_DARKER)

	# -------------------------------------------------------------------------
	# 3. Rear Fastback Engine Louvers
	# -------------------------------------------------------------------------
	for k in 4:
		var lz: float = 0.360 + 0.085 * k
		var ly: float = 0.710 - 0.022 * k
		b.rbox(Transform3D(Basis(Vector3.RIGHT, 0.26), Vector3(0.0, ly, lz)), Vector3(0.120 - 0.014 * k, 0.005, 0.018), 0.003, 1, CB.M_DARK, C_CARBON)

	# -------------------------------------------------------------------------
	# 4. Full-Width Sharp Red LED Rear Light Blade & Recessed Black Fascia (Zero Z-fighting)
	# -------------------------------------------------------------------------
	var tail_y := 0.575
	var tail_z := 0.998
	var tb_len := 0.270
	# Recessed dark matte fascia plate covering the rear center (stands proud of shell 0.998 at z = 1.006)
	b.rbox(Transform3D(Basis(), Vector3(0.0, tail_y - 0.03, tail_z)), Vector3(tb_len + 0.015, 0.065, 0.008), 0.005, 1, CB.M_DARK, C_DARKER)
	# Continuous red emissive LED blade (stands 5mm proud of fascia plate at z = 1.011)
	b.rbox(Transform3D(Basis(), Vector3(0.0, tail_y, tail_z + 0.009)), Vector3(tb_len, 0.008, 0.004), 0.003, 1, CB.M_TAILLAMP, C_TAILLAMP)

	# -------------------------------------------------------------------------
	# 4. Integrated Rear Ducktail Spoiler Trailing Lip
	# -------------------------------------------------------------------------
	var sp_path := PackedVector3Array([
		Vector3(-0.270, 0.665, 0.985),
		Vector3( 0.000, 0.680, 1.000),
		Vector3( 0.270, 0.665, 0.985)
	])
	b.tube(sp_path, 0.007, 6, CB.M_PAINT, Color(1, 1, 1), true, true)

	# -------------------------------------------------------------------------
	# 5. Aggressive Rear Rally Diffuser
	# -------------------------------------------------------------------------
	var diff_angle := -0.24
	var diff_c := Vector3(0.0, 0.315, 0.920)
	var diff_xf := Transform3D(Basis(Vector3.RIGHT, diff_angle), diff_c)
	# Diffuser tray
	b.rbox(diff_xf, Vector3(0.260, 0.008, 0.110), 0.006, 1, CB.M_DARK, C_CARBON)
	# 4 vertical aero strakes / fins
	for x in [-0.17, -0.055, 0.055, 0.17]:
		b.rbox(diff_xf * Transform3D(Basis(), Vector3(x, -0.022, 0.0)), Vector3(0.004, 0.022, 0.100), 0.002, 1, CB.M_DARK, C_DARK)
	# Center rear skid guard
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.275, 0.790)), Vector3(0.150, 0.008, 0.130), 0.006, 1, CB.M_ALLOY, C_ALLOY_DARK)


## Detailed cockpit: twin carbon bucket seats with accent harnesses, sports steering yoke, dash display
func _cockpit(b) -> void:
	for sx in [-1.0, 1.0]:
		_seat(b, 0.150 * sx)
	# Digital dashboard binnacle
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0.0, 0.545, -0.300)), Vector3(0.250, 0.030, 0.014), 0.007, 1, CB.M_DARK, C_DARK)
	# Central telemetry screen
	b.rbox(Transform3D(Basis(Vector3.RIGHT, -0.32), Vector3(0.0, 0.545, -0.292)), Vector3(0.055, 0.020, 0.004), 0.003, 1, CB.M_CHROME, Color(0.1, 0.15, 0.25))
	# Steering wheel on driver's side (-X)
	_steering(b, -0.150)


## Carbon bucket racing seat
func _seat(b, x: float) -> void:
	var floor_y := 0.285
	var rake := Basis(Vector3.RIGHT, 0.26)
	var seat_c := Vector3(x, floor_y + 0.040, -0.04)
	# Cushion
	b.rbox(Transform3D(Basis(), seat_c), Vector3(0.105, 0.030, 0.120), 0.015, 2, CB.M_DARK, C_DARK)
	# Backrest
	var back_c := Vector3(x, floor_y + 0.240, 0.100)
	b.rbox(Transform3D(rake, back_c), Vector3(0.105, 0.190, 0.026), 0.015, 2, CB.M_DARK, C_DARK)
	# Side bolsters
	for sx in [-1.0, 1.0]:
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.092 * sx, -0.035, -0.030)), Vector3(0.015, 0.150, 0.038), 0.011, 2, CB.M_DARK, C_CARBON)
		# Racing harness shoulder straps (accent color M_ANODISED)
		b.rbox(Transform3D(rake, back_c + rake * Vector3(0.040 * sx, 0.010, -0.028)), Vector3(0.010, 0.160, 0.003), 0.002, 1, CB.M_ANODISED, Color(1, 1, 1))
	# Headrest
	b.rbox(Transform3D(rake, back_c + rake * Vector3(0.0, 0.200, -0.008)), Vector3(0.065, 0.045, 0.028), 0.015, 2, CB.M_DARK, C_DARK)


## Futuristic sports steering wheel
func _steering(b, x: float) -> void:
	var c := Vector3(x, 0.540, -0.210)
	var tilt := Basis(Vector3.RIGHT, -0.36)
	var ring := PackedVector3Array()
	# D-cut sports steering wheel
	for k in 21:
		var a: float = TAU * k / 20.0
		var r: float = 0.060
		var py: float = sin(a) * r
		if py < -0.030:
			py = -0.030
		ring.append(c + tilt * Vector3(cos(a) * r, py, 0.0))
	b.tube(ring, 0.007, 6, CB.M_DARK, C_CARBON, true, false)
	b.tube(PackedVector3Array([c + tilt * Vector3(-0.052, 0.0, 0.0), c + tilt * Vector3(0.052, 0.0, 0.0)]), 0.005, 6, CB.M_DARK, C_CARBON, false, false)
	b.rbox(Transform3D(tilt, c), Vector3(0.020, 0.016, 0.007), 0.004, 1, CB.M_ANODISED, Color(1, 1, 1))
	b.tube(PackedVector3Array([c, c + Vector3(0.0, 0.0, -0.08)]), 0.010, 8, CB.M_DARK, C_STEEL, true, false)


## Builds a wheel: rugged all-terrain tire with chunky lugs, around a deep concave 5-spoke sport rim
func build_wheel(b, side: float) -> void:
	# -------------------------------------------------------------------------
	# 1. Tire Carcass & All-Terrain Tread
	# -------------------------------------------------------------------------
	tyre(b, TYRE_HALF, 44, C_RUBBER)
	for row in TREAD_ROWS:
		var odd: bool = row % 2 == 1
		var f: Array = wheel_frame(TAU * (row + (0.5 if odd else 0.0)) / TREAD_ROWS)
		var r_dir: Vector3 = f[0]
		var t_dir: Vector3 = f[1]
		var xs: Array = [-0.070, 0.0, 0.070] if odd else [-0.035, 0.035]
		for x in xs:
			var rc: float = carcass_r(TYRE_HALF, x) - 0.002
			var skew: Vector3 = (Vector3.RIGHT + t_dir * (0.28 if odd else -0.28)).normalized()
			block(b, r_dir * (rc + 0.4 * BLOCK_H) + Vector3(x, 0.0, 0.0), skew, t_dir, r_dir, 0.025, BLOCK_H, 0.022, 0.82, CB.M_RUBBER, C_RUBBER)
		# Sidewall shoulder lugs for aggressive side bite
		for sx in [-1.0, 1.0]:
			var up: Vector3 = (r_dir * 0.72 + Vector3(0.68 * sx, 0.0, 0.0)).normalized()
			var lug: float = 0.018 if odd else 0.012
			block(b, r_dir * 0.234 + Vector3(0.106 * sx, 0.0, 0.0), up.cross(t_dir).normalized(), t_dir, up, lug, 0.013, 0.020, 0.78, CB.M_RUBBER, C_RUBBER)

	# -------------------------------------------------------------------------
	# 2. Rim Barrel, Lip & Concave Face
	# -------------------------------------------------------------------------
	# Outer rim lip
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.092, 0.158), Vector2(0.102, 0.165), Vector2(0.108, 0.163),
		Vector2(0.108, 0.154), Vector2(0.102, 0.149)
	]), 44, CB.M_RIM, C_RIM, "out", Vector3(0.08, 0.0, 0.0))
	# Stepped flange into concave well
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.102, 0.149), Vector2(0.088, 0.146), Vector2(0.076, 0.144)
	]), 44, CB.M_RIM, C_RIM, "+x")
	# Inner rim barrel
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.076, 0.144), Vector2(0.070, 0.155), Vector2(-0.095, 0.158),
		Vector2(-0.104, 0.164)
	]), 44, CB.M_RIM, C_RIM_BARREL, "in")

	# -------------------------------------------------------------------------
	# 3. Brake Rotor & Accent Caliper
	# -------------------------------------------------------------------------
	# Drilled brake rotor
	b.disc(Vector3(0.025, 0.0, 0.0), Vector3.RIGHT, 0.138, 0.045, 32, CB.M_ALLOY, C_ALLOY)
	# Multi-piston racing caliper in accent color (M_ANODISED) at 2 o'clock
	var cal_angle := PI * 0.35
	var cal_pos := Vector3(0.038, sin(cal_angle) * 0.115, cos(cal_angle) * 0.115)
	var cal_xf := Transform3D(Basis(Vector3.RIGHT, -cal_angle), cal_pos)
	b.rbox(cal_xf, Vector3(0.016, 0.038, 0.022), 0.008, 1, CB.M_ANODISED, Color(1, 1, 1))

	# -------------------------------------------------------------------------
	# 4. Deep Concave 5-Spoke Wheel Face (Inspired by Reference Image)
	# -------------------------------------------------------------------------
	# Central recessed hub
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.048, 0.046), Vector2(0.068, 0.046), Vector2(0.072, 0.038)
	]), 24, CB.M_RIM, C_RIM, "out", Vector3(0.05, 0.0, 0.0))
	# Center lock nut in accent color (M_ANODISED)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.072, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0.0, 0.036), Vector2(0.006, 0.030), Vector2(0.010, 0.018), Vector2(0.012, 0.0)
	]), 18, CB.M_ANODISED, Color(1, 1, 1))
	b.orient_away_from(vb, ib, Vector3(0.05, 0.0, 0.0))

	# 5 sculpted directional spokes curving gracefully from outer rim (x ~ 0.076) into recessed hub (x ~ 0.066)
	for k in 5:
		var a: float = TAU * k / 5.0
		for da in [-0.070, 0.070]:
			spoke(b, a + da, 0.0, 0.042, 0.144, 0.066, 0.076, 0.008, 0.010, 0.013, CB.M_RIM, C_RIM)

	if side < 0.0:
		b.mirror_in_place()


# ============================================================================================
#  Detail map: Windshield, canopy glass, panel shut lines, two-tone lower carbon panels
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}
	# Side door shut line in side view (z, y)
	shapes["door"] = _inset(PackedVector2Array([
		Vector2(-0.350, 0.300), Vector2(0.150, 0.300),
		Vector2(0.180, 0.550), Vector2(-0.320, 0.530)
	]), 0.025)
	# Diagonal lower-door carbon blade slash (from reference image)
	shapes["door_slash"] = PackedVector2Array([
		Vector2(-0.350, 0.300), Vector2(0.150, 0.300),
		Vector2(0.080, 0.440), Vector2(-0.250, 0.380)
	])
	return shapes


func _detail_at(p: Vector3, n: Vector3, fp: float, sh: Dictionary) -> Color:
	var glass := 0.0
	var gap := 0.0
	var chrome := 0.0
	var black := 0.0

	var w: float = prof["w"].at(p.z)
	var sx: float = prof["sx"].at(p.z)
	var sy: float = prof["sy"].at(p.z)
	var rx: float = prof["rx"].at(p.z)
	var ry: float = prof["ry"].at(p.z)

	# -------------------------------------------------------------------------
	# 1. Glass (Windshield, Side Windows, Rear Hatch) -> R channel
	# -------------------------------------------------------------------------
	# Windshield: from cowl (z = -0.45) up to roof header (z = -0.13), inside A-pillars
	if p.z > -0.440 and p.z < -0.135:
		if p.x < rx - 0.018 and p.y > sy + 0.012:
			glass = 1.0
	# Side windows: from A-pillar to B/C pillar, between shoulder and roof rail
	if p.z >= -0.280 and p.z <= 0.160:
		if p.y > sy + 0.014 and p.y < ry - 0.010 and p.x > rx + 0.010:
			glass = 1.0
	# Rear fastback glass: small engine viewing window
	if p.z > 0.240 and p.z < 0.520:
		if p.x < rx - 0.022 and p.y > 0.640 and n.y > 0.35:
			glass = 1.0

	# Black rubber window seals bordering glass
	if glass == 0.0:
		# Windshield rubber seal
		if p.z > -0.455 and p.z < -0.120 and p.x < rx and p.y > sy:
			if (p.x >= rx - 0.022 or p.z <= -0.430 or p.z >= -0.145):
				black = maxf(black, 0.95)
		# Side window rubber seal
		if p.z >= -0.300 and p.z <= 0.180 and p.x > rx and p.y > sy - 0.005 and p.y < ry + 0.015:
			if (p.y <= sy + 0.018 or p.y >= ry - 0.008 or p.z <= -0.270 or p.z >= 0.150):
				black = maxf(black, 0.95)

	# -------------------------------------------------------------------------
	# 2. Two-Tone Carbon Lower Body & Door Slash -> A channel
	# -------------------------------------------------------------------------
	# Lower body rockers: below beltline on lower sides
	if p.y < 0.350 and n.y < 0.6:
		black = maxf(black, 0.95)
	# Diagonal lower-door carbon blade slash (signature styling from concept image)
	if p.x > w - 0.025 and p.z > -0.36 and p.z < 0.16 and p.y < 0.46:
		var d_slash: float = _sd_poly(Vector2(p.z, p.y), sh["door_slash"] as PackedVector2Array)
		black = maxf(black, _cover(d_slash, fp) * 0.95)
	# Roof center carbon spine / canopy detail
	if p.z >= -0.120 and p.z <= 0.600 and p.y > 0.68 and absf(p.x) < 0.09:
		black = maxf(black, 0.95)
	# Front chin spoiler area
	if p.z < -1.000 and p.y < 0.370:
		black = maxf(black, 0.95)
	# Rear recessed tail fascia
	if p.z > 0.880 and p.y < 0.620 and n.z > 0.4:
		black = maxf(black, 0.98)
	# Rear diffuser & lower bumper
	if p.z > 0.850 and p.y < 0.440:
		black = maxf(black, 0.95)
	# Underside
	if n.y < -0.45:
		black = maxf(black, 1.0)

	# -------------------------------------------------------------------------
	# 3. Panel Gaps & Shut Lines -> G channel
	# -------------------------------------------------------------------------
	# Door shut lines on side panels
	if p.x > w - 0.020 and p.z > -0.38 and p.z < 0.20 and p.y < sy:
		gap = maxf(gap, _cover(absf(_sd_rounded(Vector2(p.z, p.y), sh["door"])) - 0.0022, fp))
	# Front hood shut lines
	if n.y > 0.5 and p.z > -1.00 and p.z < -0.47:
		var hood_edge := 0.240 + (p.z + 0.78) * 0.06
		gap = maxf(gap, _cover(absf(absf(p.x) - hood_edge) - 0.0020, fp))
		if absf(p.z - (-0.470)) < 0.012:
			gap = maxf(gap, _cover(absf(p.z - (-0.470)) - 0.0020, fp))
	# Rear engine hatch / deck shut line
	if p.z > 0.580 and p.z < 0.840 and n.y > 0.4:
		gap = maxf(gap, _cover(absf(absf(p.x) - 0.230) - 0.0020, fp))

	return Color(glass, gap, chrome, black)
