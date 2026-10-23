# ZephyrBuilder.gd
#
# The Zephyr: an ultra-sleek futuristic cyber-Dakar hyper-coupe / buggy.
# Faithfully rebuilt from the reference concept photo:
# - Low, aerodynamic, organic sculpted nose with continuous horizontal LED light bar
# - Seamless panoramic tinted glass windshield curving from the low cowl over the cockpit
# - Satin-white roof shell cap with panoramic rear glass slot / moonroof
# - Distinctive side window profile tapering into an aggressive rearward triangular blade kink
# - Muscular front and rear sculpted 3D fender arches framing the high-clearance off-road stance
# - Integrated aerodynamic rear wing / spoiler bridge connecting the muscular rear haunches
# - Recessed rear-quarter pod with illuminated amber accent ring
# - Sculpted, organic white doors with dark composite aerodynamic rocker sills
# - Front metallic skid plate / bash guard angled upward under the nose
# - High-travel exposed double-wishbone suspension with visible coilover spring dampers
# - Wide track stance with rugged all-terrain knobby tires
# - Multi-spoke turbine star wheels with bronze/copper outer rims and dark graphite inner spokes
extends "res://CarDesign.gd"

# Wheels and Stance
# Wide rally-raid stance with high ground clearance
const WHEEL_X := 0.630
const AXLE_F := -0.660
const AXLE_R := 0.620
const HUB_Y := 0.270

# Tub half-width (w) along the car (z):
# Athletic waist pinch at the doors, widening at front and rear haunches
const W_KNOTS := [
	[-0.920, 0.270], [-0.840, 0.330], [-0.760, 0.380], [-0.660, 0.410],
	[-0.540, 0.400], [-0.380, 0.380], [-0.180, 0.370], [ 0.050, 0.375],
	[ 0.250, 0.390], [ 0.450, 0.420], [ 0.620, 0.440], [ 0.740, 0.410],
	[ 0.840, 0.330]
]

# Tub bottom (bot) along the car:
# High off-road clearance, belly at 0.255 - 0.265, curving up to the nose skid plate and rear diffuser.
const BOT_KNOTS := [
	[-0.920, 0.280], [-0.840, 0.260], [-0.660, 0.255], [-0.380, 0.260],
	[ 0.050, 0.262], [ 0.380, 0.265], [ 0.620, 0.270], [ 0.760, 0.290],
	[ 0.840, 0.320]
]

# Section keyframes along the car:
# z: position along car
# belt: height of vertical side / rocker top
# sx, sy: shoulder crease position (wide hip / hood edge)
# rx, ry: roof rail / inner hood crease position
# top: centre line top height
# crown: dome / dish of top surface (+ dome, - dish)
const KEYS := [
	# z       belt    sx     sy     rx     ry     top    crown
	[-0.920, 0.280, 0.230, 0.290, 0.120, 0.295, 0.290, 0.010], # nose tip, low and sleek
	[-0.840, 0.310, 0.290, 0.350, 0.170, 0.360, 0.355, 0.016], # low hood
	[-0.760, 0.350, 0.350, 0.430, 0.210, 0.435, 0.430, 0.020], # front fender slope
	[-0.660, 0.380, 0.390, 0.485, 0.235, 0.490, 0.485, 0.024], # front axle plane (dished hood)
	[-0.500, 0.410, 0.380, 0.520, 0.245, 0.560, 0.575, 0.020], # cowl transition to canopy
	[-0.280, 0.435, 0.365, 0.560, 0.250, 0.670, 0.685, 0.016], # steep aerodynamic windshield
	[-0.080, 0.450, 0.355, 0.590, 0.240, 0.755, 0.770, 0.012], # roof header
	[ 0.080, 0.460, 0.355, 0.600, 0.235, 0.765, 0.780, 0.010], # roof peak
	[ 0.280, 0.470, 0.365, 0.605, 0.230, 0.745, 0.758, 0.008], # B-pillar / roof
	[ 0.480, 0.480, 0.385, 0.600, 0.220, 0.680, 0.690, 0.006], # fastback / haunch rise
	[ 0.620, 0.485, 0.410, 0.590, 0.200, 0.615, 0.625, 0.004], # rear haunch crest
	[ 0.740, 0.465, 0.375, 0.560, 0.170, 0.565, 0.570, 0.002], # haunch trailing edge
	[ 0.840, 0.420, 0.285, 0.500, 0.130, 0.505, 0.505, 0.000], # kamm tail cutoff
]
const KEY_NAMES := ["belt", "sx", "sy", "rx", "ry", "top", "crown"]

# Off-road knobby tire half profile (x offset, radius):
# Robust all-terrain carcass with square lugs
const TYRE_HALF := [
	[-0.100, 0.160], [-0.110, 0.175], [-0.118, 0.198], [-0.118, 0.220],
	[-0.112, 0.240], [-0.094, 0.252], [-0.058, 0.258], [0.0, 0.260]
]
const TREAD_ROWS := 26

# Colors & Palette (sRGB; shader linearises vertex colours)
const C_RUBBER := Color(0.18, 0.18, 0.19)
const C_DARK := Color(0.06, 0.06, 0.07)
const C_DARKER := Color(0.025, 0.025, 0.028)
const C_TITANIUM := Color(0.48, 0.50, 0.52)
const C_ALLOY_LIGHT := Color(0.82, 0.83, 0.85)
const C_CHROME := Color(0.92, 0.93, 0.95)
const C_BRONZE := Color(1.0, 1.0, 1.0)
const C_BRONZE_DARK := Color(0.55, 0.55, 0.55)
const C_AMBER := Color(1.0, 0.55, 0.05)
const C_HEADLAMP_WHITE := Color(0.98, 0.99, 1.0)

## Paint layout for car_body.gdshader's livery patterns
const PAINT_LAYOUT := {
	"nose_z": -0.92, "tail_z": 0.84, "belt_y": 0.50, "side_x": 0.40,
	"door_z": 0.0, "door_y": 0.40, "roundel_r": 0.09,
	"hood_z": -0.55, "hood_r": 0.08, "stripe_w": 0.06, "stripe_gap": 0.025,
}

const ANTENNA_POS := Vector3(0.0, 0.81, 0.15)

const WHEEL_POSITIONS := {
	"FL": Vector3(-WHEEL_X, HUB_Y, AXLE_F),
	"FR": Vector3(WHEEL_X, HUB_Y, AXLE_F),
	"RL": Vector3(-WHEEL_X, HUB_Y, AXLE_R),
	"RR": Vector3(WHEEL_X, HUB_Y, AXLE_R),
}

var _prof_cache := {}


func _init() -> void:
	nose_tip = -0.920
	nose_cap = 0.060
	nose_cap_y = 0.300
	nose_cap_exp = Vector2(3.5, 2.0)
	tail_tip = 0.840
	tail_cap = 0.040
	tail_cap_y = 0.440
	tail_cap_exp = Vector2(3.0, 2.0)
	half_ring = 28
	bottom_radius = 0.040

	var knots: Dictionary = keyed_knots(KEYS, KEY_NAMES)
	knots["w"] = W_KNOTS
	knots["bot"] = BOT_KNOTS
	setup_shell(knots)
	_prof_cache = knots


## Custom upper section: sculpts the curved organic shoulder, tumblehome, and domed crown
func _upper(z: float, w: float, belt: float, top: float) -> PackedVector2Array:
	var sx: float = prof["sx"].at(z)
	var sy: float = prof["sy"].at(z)
	var rx: float = prof["rx"].at(z)
	var ry: float = prof["ry"].at(z)
	var crown: float = prof["crown"].at(z)

	var p0 := Vector2(w, belt)
	var p1 := Vector2(sx, sy)
	var p2 := Vector2(rx, ry)
	var p3 := Vector2(0.0, top + crown)

	var out := PackedVector2Array()
	# Smooth 2-stage cubic bezier over the shoulder and onto the roof/canopy
	for k in range(1, 25):
		var t: float = float(k) / 24.0
		out.append(p0.bezier_interpolate(p0.lerp(p1, 0.5), p1.lerp(p0, 0.2), p1, t))
	for k in range(1, 25):
		var t: float = float(k) / 24.0
		out.append(p1.bezier_interpolate(p1.lerp(p2, 0.6), p2.lerp(p3, 0.4), p3, t))
	return out


## Builds the full body mesh
func build_body(b) -> void:
	# 1. Main Monocoque Body Shell
	build_shell(b)

	# 2. Right-hand features (mirrored across X = 0)
	var v0: int = b.vertex_count()
	var i0: int = b.index_count()

	# Muscular 3D Circular Fender Arches (Front & Rear)
	_build_fender_arches(b)

	# Front and Rear Suspension (wishbones, coilovers, knuckles)
	_build_front_suspension(b)
	_build_rear_suspension(b)

	# Aerodynamic Rocker Panel / Side Skirt below doors
	_build_side_rocker(b)

	# Mirror symmetric side parts
	b.mirror_x(v0, i0)

	# 3. Centerline Features (Front to Rear)
	# Front LED light strip across the nose
	_build_front_light_bar(b)

	# Front metallic bash plate / skid plate
	_build_front_skid_plate(b)

	# Integrated Rear Spoiler Bridge with Amber Light Pods
	_build_rear_spoiler_bridge(b)

	# Rear Underbody Diffuser & Chassis center
	_build_rear_diffuser(b)


## Builds true circular 3D sculpted fender arches framing the off-road tires
func _build_fender_arches(b) -> void:
	# Front Fender: generous circular flare over AXLE_F with clean tire clearance (symmetric 143° to 37°)
	_build_circular_fender(b, AXLE_F, HUB_Y, 0.295, 2.50, 0.64, 0.638, 36)

	# Rear Fender: muscular circular haunch flare over AXLE_R (symmetric 143° to 37°)
	_build_circular_fender(b, AXLE_R, HUB_Y, 0.302, 2.50, 0.64, 0.645, 36)


## Builds one circular sculpted 3D fender: pearl white upper crown, solid return lip & dark inner liner
func _build_circular_fender(b, hub_z: float, hub_y: float, r_arch: float, a_front: float, a_rear: float, x_out: float, segs: int) -> void:
	var outer_grid := []
	var liner_grid := []

	for k in segs + 1:
		var t: float = float(k) / float(segs)
		var a: float = lerpf(a_front, a_rear, t) # angle in (z, y) plane: +z is rear, -z is front
		var z: float = hub_z + r_arch * cos(a)
		var y_arch: float = hub_y + r_arch * sin(a)

		var body_w: float = prof["w"].at(z)
		var x_in: float = body_w - 0.015
		# Use smooth continuous shoulder spline prof["sy"] to guarantee zero jump or step
		var sy: float = prof["sy"].at(z)
		var y_in: float = sy - 0.005

		var rad := Vector2(cos(a), sin(a)) # outward radial unit vector: rad.x is along z, rad.y along y
		# Silky smooth Hermite / smoothstep envelope with plateau over tire:
		var env: float = clampf(sin(t * PI) * 1.30, 0.0, 1.0)
		var flare: float = env * env * (3.0 - 2.0 * env)

		var x_crest: float = lerpf(x_in + 0.005, x_out, flare)
		var y_crest: float = lerpf(y_in, y_arch, flare)
		var th: float = 0.024 * flare

		# Cross-section points:
		# 1. p_in: anchored inside the body shell surface
		var p_in := Vector3(x_in, y_in, z)
		# 2. p_mid1: gentle organic scoop from the hood/body
		var p_mid1 := Vector3(lerpf(x_in, x_crest, 0.35), lerpf(y_in + 0.005, y_crest, 0.42), z)
		# 3. p_mid2: crowned arch crest over the tire
		var p_mid2 := Vector3(lerpf(x_in, x_crest, 0.72), lerpf(y_in + 0.005, y_crest, 0.85) + th * 0.35, z)
		# 4. p_crest: outer circular edge of pearl-white bodywork
		var p_crest := Vector3(x_crest, y_crest, z)
		# 5. p_flange: 20mm solid downward return lip curling under the arch lip
		var p_flange := p_crest - Vector3(0.012 * flare, rad.y * 0.020 * flare, rad.x * 0.020 * flare)

		# Outer pearl-white painted body surface with return lip (solid, stamped appearance)
		outer_grid.append(PackedVector3Array([p_in, p_mid1, p_mid2, p_crest, p_flange]))

		# Watertight dark composite wheel well liner: strictly tucked BELOW the hood/body surface
		# Connects seamlessly to p_flange and vaults the inner wheel well
		var l_lip := p_flange
		var l_tub1 := p_flange - Vector3(0.035 * flare, rad.y * 0.015, rad.x * 0.015)
		var l_tub2_y: float = minf(y_crest - 0.035, y_in - 0.015)
		var l_tub3_y: float = minf(y_arch - 0.055, y_in - 0.020)
		var l_tub2 := Vector3(lerpf(x_crest - 0.060, x_in, 0.50), l_tub2_y, z)
		var l_tub3 := Vector3(x_in - 0.030, l_tub3_y, z)
		liner_grid.append(PackedVector3Array([l_lip, l_tub1, l_tub2, l_tub3]))

	# 1. Outer painted body surface (pearl white)
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.grid(outer_grid, CB.M_PAINT, Color(1, 1, 1), false, false)
	b.orient_away_from(vb, ib, Vector3(0.20, hub_y, hub_z))

	# 2. Dark inner composite wheel well liner:
	# Orient away from a high point above the roof (y = 1.6) so ALL liner normals point
	# DOWN and OUTWARD into the wheel well cavity. This completely eliminates backface culling
	# and ensures the fender is 100% solid and never hollow from any viewing angle!
	vb = b.vertex_count()
	ib = b.index_count()
	b.grid(liner_grid, CB.M_DARK, C_DARKER, false, false)
	b.orient_away_from(vb, ib, Vector3(0.0, 1.6, hub_z))





## Front suspension: Double wishbone A-arms and long-travel coilover shock
func _build_front_suspension(b) -> void:
	var kx := 0.520
	var z := AXLE_F
	# Upper and Lower A-arms (tubular steel)
	for dz in [-0.075, 0.075]:
		# Lower wishbone
		b.tube(PackedVector3Array([Vector3(0.20, 0.225, z + dz * 1.2), Vector3(kx - 0.02, 0.205, z + dz * 0.2)]),
				0.012, 6, CB.M_DARK, C_DARK, true, true)
		# Upper wishbone
		b.tube(PackedVector3Array([Vector3(0.26, 0.340, z + dz * 0.8), Vector3(kx - 0.02, 0.320, z + dz * 0.15)]),
				0.009, 6, CB.M_DARK, C_DARK, true, true)

	# Wheel upright / steering knuckle
	b.rbox(Transform3D(Basis(), Vector3(kx, 0.265, z)), Vector3(0.016, 0.085, 0.028), 0.007, 1, CB.M_DARK, C_DARK)
	# Stub axle spindle
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, z), Vector3(kx + 0.09, HUB_Y, z)]), 0.014, 8,
			CB.M_ALLOY, C_TITANIUM, false, true)
	# Steering tie-rod
	b.tube(PackedVector3Array([Vector3(0.22, 0.260, z + 0.075), Vector3(kx - 0.02, 0.260, z + 0.065)]),
			0.008, 6, CB.M_ALLOY, C_TITANIUM, true, true)

	# Angled coilover shock absorber (damper body + bronze coil spring)
	coilover(b, Vector3(0.44, 0.215, z - 0.015), Vector3(0.32, 0.460, z + 0.010),
			0.016, 0.026, 7.0, C_TITANIUM, C_DARK, C_CHROME, C_DARK)


## Rear suspension: Trailing wishbones, drive half-shaft and coilover
func _build_rear_suspension(b) -> void:
	var kx := 0.530
	var z := AXLE_R
	# Lower trailing arms
	b.tube(PackedVector3Array([Vector3(0.22, 0.235, z - 0.110), Vector3(kx - 0.02, 0.215, z)]),
				0.013, 6, CB.M_DARK, C_DARK, true, true)
	b.tube(PackedVector3Array([Vector3(0.22, 0.235, z + 0.085), Vector3(kx - 0.02, 0.215, z)]),
				0.013, 6, CB.M_DARK, C_DARK, true, true)
	# Upper control arm
	b.tube(PackedVector3Array([Vector3(0.28, 0.360, z - 0.055), Vector3(kx - 0.02, 0.330, z)]),
				0.010, 6, CB.M_DARK, C_DARK, true, true)

	# Knuckle & axle spindle
	b.rbox(Transform3D(Basis(), Vector3(kx, 0.270, z)), Vector3(0.016, 0.090, 0.030), 0.007, 1, CB.M_DARK, C_DARK)
	b.tube(PackedVector3Array([Vector3(kx, HUB_Y, z), Vector3(kx + 0.09, HUB_Y, z)]), 0.014, 8,
			CB.M_ALLOY, C_TITANIUM, false, true)

	# Drive half-shaft from center diff
	b.tube(PackedVector3Array([Vector3(0.12, 0.265, z), Vector3(kx - 0.02, HUB_Y, z)]), 0.011, 8,
			CB.M_ALLOY, C_TITANIUM, false, false)

	# Rear coilover shock absorber
	coilover(b, Vector3(0.45, 0.225, z + 0.020), Vector3(0.33, 0.510, z - 0.030),
			0.017, 0.027, 7.5, C_TITANIUM, C_DARK, C_CHROME, C_DARK)


## Sculpted aerodynamic dark composite rocker sill running below the door
func _build_side_rocker(b) -> void:
	# Main aerodynamic side blade / rocker panel running between wheel cutouts
	var sill_xf := Transform3D(Basis(), Vector3(0.395, 0.248, -0.025))
	b.rbox(sill_xf, Vector3(0.024, 0.010, 0.345), 0.005, 2, CB.M_DARK, C_DARK)

	# Aero step undercut tucked beneath the door
	var step_xf := Transform3D(Basis(), Vector3(0.380, 0.258, -0.025))
	b.rbox(step_xf, Vector3(0.018, 0.012, 0.335), 0.004, 1, CB.M_DARK, C_DARKER)

	# Rear aerodynamic vertical winglet framing the rear wheel entrance
	var winglet_xf := Transform3D(Basis(Vector3.UP, -0.12), Vector3(0.422, 0.272, 0.285))
	b.rbox(winglet_xf, Vector3(0.006, 0.026, 0.042), 0.004, 1, CB.M_DARK, C_DARK)


## Front LED continuous light bar curving across the nose lip
func _build_front_light_bar(b) -> void:
	var path := PackedVector3Array()
	var segs := 16
	for k in segs + 1:
		var t: float = float(k) / segs * 2.0 - 1.0 # -1.0 to 1.0
		var x: float = t * 0.240
		var z_curve: float = -0.915 + 0.045 * (t * t)
		var y_curve: float = 0.290 + 0.012 * (1.0 - t * t)
		path.append(Vector3(x, y_curve, z_curve))

	# Thin glowing LED blade
	b.tube(path, 0.0055, 8, CB.M_HEADLAMP, C_HEADLAMP_WHITE, true, true)


## Front metallic skid plate / bash guard angled under the nose
func _build_front_skid_plate(b) -> void:
	# Angled titanium plate extending to nose lip
	var skid_xf := Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0.0, 0.250, -0.800))
	b.rbox(skid_xf, Vector3(0.185, 0.010, 0.125), 0.010, 2, CB.M_ALLOY, C_TITANIUM)

	# Dual lower recovery / intake strakes
	for sx in [-0.09, 0.09]:
		b.tube(PackedVector3Array([Vector3(sx, 0.260, -0.880), Vector3(sx, 0.230, -0.700)]),
				0.007, 6, CB.M_DARK, C_DARK, true, true)


## Integrated Aerodynamic Rear Wing Bridge spanning the rear haunches
func _build_rear_spoiler_bridge(b) -> void:
	# 1. Twin sculpted aerodynamic swan-neck pylons rising from the rear haunches
	for sx in [-1.0, 1.0]:
		var pylon_path := PackedVector3Array([
			Vector3(0.240 * sx, 0.585, 0.620),
			Vector3(0.235 * sx, 0.645, 0.680),
			Vector3(0.230 * sx, 0.695, 0.740)
		])
		# Sleek, streamlined carbon-fiber pylon
		b.oval_tube(pylon_path, 0.012, 0.038, Vector3.FORWARD, 8, CB.M_DARK, C_DARK, true)

		# 2. Sleek aerodynamic carbon endplate fins at the wingtips (clean, sharp, no dots or pods!)
		var ep_pos := Vector3(0.372 * sx, 0.705, 0.745)
		var ep_rot := Basis(Vector3.UP, 0.06 * sx)
		b.rbox(Transform3D(ep_rot, ep_pos), Vector3(0.005, 0.038, 0.058), 0.004, 1, CB.M_DARK, C_DARK)

	# 3. Main aerodynamic aerofoil wing plane spanning between haunches
	var wing_path := PackedVector3Array()
	var n_pts := 20
	for k in n_pts + 1:
		var t: float = float(k) / float(n_pts) * 2.0 - 1.0 # -1.0 to 1.0
		var x: float = t * 0.368
		# Elegant aerodynamic camber: slightly bowed in center for downforce
		var y: float = 0.705 - 0.010 * (1.0 - t * t)
		var z: float = 0.745 + 0.012 * (t * t)
		wing_path.append(Vector3(x, y, z))

	# Sculpted pearl-white aerofoil blade
	b.oval_tube(wing_path, 0.014, 0.062, Vector3.UP, 10, CB.M_PAINT, Color(1, 1, 1), true)

	# 4. Motorsport carbon-composite gurney flap / wickerbill trailing edge
	var lip_path := PackedVector3Array([
		Vector3(-0.365, 0.708, 0.782),
		Vector3( 0.365, 0.708, 0.782)
	])
	b.tube(lip_path, 0.0035, 6, CB.M_DARK, C_DARK, true, true)



## Rear underbody diffuser and chassis frame
func _build_rear_diffuser(b) -> void:
	# Rear chassis bottom plate
	b.rbox(Transform3D(Basis(), Vector3(0.0, 0.240, 0.05)), Vector3(0.150, 0.012, 0.680), 0.008, 2, CB.M_DARK, C_DARK)

	# Upswept rear diffuser tunnel at the tail
	var diff_xf := Transform3D(Basis(Vector3.RIGHT, -0.20), Vector3(0.0, 0.305, 0.740))
	b.rbox(diff_xf, Vector3(0.170, 0.009, 0.080), 0.006, 1, CB.M_DARK, C_DARK)

	# Vertical diffuser fins
	for fx in [-0.12, -0.04, 0.04, 0.12]:
		var fin_pts := PackedVector2Array([
			Vector2(0.660, 0.280), Vector2(0.790, 0.335),
			Vector2(0.790, 0.290), Vector2(0.660, 0.250)
		])
		slab(b, fin_pts, fx, 0.005, CB.M_DARK, C_DARK)


# ============================================================================================
#  Wheel & Rim (Deep-Concave Turbine Star Wheels with Bronze Facets & Rotor Assembly)
# ============================================================================================

func build_wheel(b, side: float) -> void:
	# 1. Knobby Off-Road Tire Carcass
	tyre(b, TYRE_HALF, 36, C_RUBBER)

	# 2. Modern All-Terrain Knobby Tread Blocks (Clean, dense rectangular lugs)
	for k in TREAD_ROWS:
		var a: float = TAU * k / float(TREAD_ROWS)
		var f: Array = wheel_frame(a)
		var r: Vector3 = f[0]
		var t: Vector3 = f[1]

		# Outer shoulder blocks (both sides)
		for sx in [-1.0, 1.0]:
			var c_sh: Vector3 = r * 0.252 + Vector3(0.078 * sx, 0.0, 0.0)
			block(b, c_sh, Vector3.RIGHT, t, r, 0.022, 0.014, 0.016, 0.82, CB.M_RUBBER, C_RUBBER)

		# Inner paired tread blocks (staggered pattern)
		var offset_sign := 1.0 if k % 2 == 0 else -1.0
		var c_mid1: Vector3 = r * 0.258 + Vector3(0.036 * offset_sign, 0.0, 0.0) + t * 0.008
		var c_mid2: Vector3 = r * 0.258 + Vector3(-0.036 * offset_sign, 0.0, 0.0) - t * 0.008
		block(b, c_mid1, Vector3.RIGHT, t, r, 0.025, 0.013, 0.015, 0.85, CB.M_RUBBER, C_RUBBER)
		block(b, c_mid2, Vector3.RIGHT, t, r, 0.025, 0.013, 0.015, 0.85, CB.M_RUBBER, C_RUBBER)

	# 3. High-Performance Brake Assembly Behind Rims
	# Cross-drilled carbon-ceramic brake rotor disc
	b.disc(Vector3(0.028, 0.0, 0.0), Vector3.RIGHT, 0.136, 0.045, 28, CB.M_ALLOY, C_TITANIUM)
	# Center rotor mounting hat in dark iron
	b.disc(Vector3(0.033, 0.0, 0.0), Vector3.RIGHT, 0.054, 0.032, 20, CB.M_DARK, C_DARK)
	# Monobloc 6-piston high-performance sport brake caliper
	var cal_xf := Transform3D(Basis(Vector3.RIGHT, 0.40), Vector3(0.036, 0.088, -0.042))
	b.rbox(cal_xf, Vector3(0.015, 0.038, 0.020), 0.005, 2, CB.M_DARK, C_DARKER)

	# 4. Multi-Piece Stepped Wheel Rim with Beadlock Perimeter
	# Outer Bronze Lip Ring
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.088, 0.166), Vector2(0.098, 0.170), Vector2(0.106, 0.165),
		Vector2(0.104, 0.155), Vector2(0.096, 0.148)
	]), 36, CB.M_RIM, C_BRONZE, "out", Vector3(0.05, 0.0, 0.0))

	# Stepped Concave Rim Shelf
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.096, 0.148), Vector2(0.082, 0.142), Vector2(0.065, 0.134)
	]), 36, CB.M_RIM, C_BRONZE_DARK, "+x")

	# Perimeter Beadlock Hex Rivet Studs (20 chrome studs)
	for i in 20:
		var a_stud: float = TAU * i / 20.0
		var c_stud := Vector3(0.101, sin(a_stud) * 0.156, cos(a_stud) * 0.156)
		b.tube(PackedVector3Array([c_stud, c_stud + Vector3(0.005, 0, 0)]), 0.0028, 6, CB.M_ALLOY, C_CHROME, false, true)

	# Deep Inner Wheel Barrel (Dark graphite)
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.065, 0.134), Vector2(0.020, 0.142), Vector2(-0.090, 0.156),
		Vector2(-0.098, 0.164)
	]), 36, CB.M_DARK, C_DARK, "in")

	# 5. Sunken Center Lock Hub & Lug Nuts
	wheel_lathe(b, PackedVector2Array([
		Vector2(0.032, 0.046), Vector2(0.042, 0.044), Vector2(0.046, 0.036)
	]), 20, CB.M_DARK, C_DARK, "out", Vector3(0.02, 0.0, 0.0))

	# 5 Chrome lug nuts set into the hub bowl
	for j in 5:
		var a_lug: float = TAU * j / 5.0
		var c_lug := Vector3(0.039, sin(a_lug) * 0.028, cos(a_lug) * 0.028)
		b.tube(PackedVector3Array([c_lug, c_lug + Vector3(0.006, 0, 0)]), 0.0038, 6, CB.M_ALLOY, C_CHROME, false, true)

	# Bronze Center Star Cap
	var vb: int = b.vertex_count()
	var ib: int = b.index_count()
	b.lathe(Vector3(0.045, 0.0, 0.0), Vector3.RIGHT, PackedVector2Array([
		Vector2(0.0, 0.022), Vector2(0.004, 0.018), Vector2(0.008, 0.010), Vector2(0.010, 0.0)
	]), 18, CB.M_RIM, C_BRONZE)
	b.orient_away_from(vb, ib, Vector3(0.03, 0.0, 0.0))

	# 6. 10 Directional Sculpted Turbine Star Blades:
	# Deep concave plunge (x=0.036 at hub to x=0.080 at rim: 44mm concave dish!)
	# Faceted aerofoil blade shape with bronze face and dark graphite pocket
	for k in 10:
		var ang: float = TAU * k / 10.0
		var f0: Array = wheel_frame(ang)
		var f1: Array = wheel_frame(ang + 0.13) # directional aerodynamic twist
		var rd0: Vector3 = f0[0]
		var tg0: Vector3 = f0[1]
		var rd1: Vector3 = f1[0]
		var tg1: Vector3 = f1[1]

		var w_in := 0.011
		var w_out := 0.017
		var p_in_lead  := rd0 * 0.044 + tg0 * w_in  + Vector3(0.036, 0.0, 0.0)
		var p_in_trail := rd0 * 0.044 - tg0 * w_in  + Vector3(0.034, 0.0, 0.0)
		var p_in_ridge := rd0 * 0.044 + Vector3(0.041, 0.0, 0.0)

		var p_out_lead  := rd1 * 0.140 + tg1 * w_out + Vector3(0.078, 0.0, 0.0)
		var p_out_trail := rd1 * 0.140 - tg1 * w_out + Vector3(0.073, 0.0, 0.0)
		var p_out_ridge := rd1 * 0.140 + Vector3(0.082, 0.0, 0.0)

		# Backing points inside the barrel
		var p_back_in_lead   := p_in_lead - Vector3(0.012, 0, 0)
		var p_back_in_trail  := p_in_trail - Vector3(0.012, 0, 0)
		var p_back_out_lead  := p_out_lead - Vector3(0.016, 0, 0)
		var p_back_out_trail := p_out_trail - Vector3(0.016, 0, 0)

		# Facet 1: Leading sculpted bronze blade face
		face(b, [p_in_lead, p_in_ridge, p_out_ridge, p_out_lead], (tg0 + tg1).normalized() + Vector3.RIGHT * 0.6, CB.M_RIM, C_BRONZE)
		# Facet 2: Trailing sculpted bronze blade face
		face(b, [p_in_ridge, p_in_trail, p_out_trail, p_out_ridge], -(tg0 + tg1).normalized() + Vector3.RIGHT * 0.6, CB.M_RIM, C_BRONZE)

		# Facet 3: Directional leading flank (catching specular light)
		face(b, [p_in_lead, p_out_lead, p_back_out_lead, p_back_in_lead], (tg0 + tg1).normalized(), CB.M_RIM, C_BRONZE_DARK)

		# Facet 4: Trailing dark graphite relief pocket (milled forged appearance)
		face(b, [p_in_trail, p_back_in_trail, p_back_out_trail, p_out_trail], -(tg0 + tg1).normalized(), CB.M_DARK, C_DARK)

		# Back face
		face(b, [p_back_in_lead, p_back_out_lead, p_back_out_trail, p_back_in_trail], -Vector3.RIGHT, CB.M_DARK, C_DARKER)

	if side < 0.0:
		# Mirror across X for left wheels
		b.mirror_in_place()


# ============================================================================================
#  Detail Map (Seamless Panoramic Wrap-Around Glass Canopy, Moonroof, Shutlines)
# ============================================================================================

func _detail_shapes() -> Dictionary:
	var shapes := {}

	# Rear Panoramic Moonroof / Glass Slot in the roof (x, z)
	shapes["moonroof"] = _inset(PackedVector2Array([
		Vector2(-0.125, 0.120), Vector2( 0.125, 0.120),
		Vector2( 0.110, 0.440), Vector2(-0.110, 0.440)
	]), 0.012)

	# Clean door shutlines (z, y)
	shapes["door_front"] = PackedVector2Array([
		Vector2(-0.350, 0.265), Vector2(-0.320, 0.450)
	])
	shapes["door_rear"] = PackedVector2Array([
		Vector2( 0.240, 0.490), Vector2( 0.280, 0.265)
	])

	return shapes


## Samples the detail map texel:
## R = glass, G = panel gap, B = chrome, A = dark rubber / plastic
func _detail_at(p: Vector3, n: Vector3, fp: float, shapes: Dictionary) -> Color:
	var c := Color(0, 0, 0, 0)
	var ax: float = absf(p.x)

	# 1. Cockpit Lower Boundaries (Front-to-Rear Wrap-Around Canopy):
	# Front cowl bow curve: sweeping smoothly back from z = -0.65 in center to z = -0.48 at cowl corner
	var ax_norm: float = clampf(ax / 0.28, 0.0, 1.0)
	var cowl_z: float = -0.65 + 0.17 * (ax_norm * ax_norm)

	# Door beltline / lower glass boundary:
	# From cowl corner (-0.48, 0.50), along door waist, sweeping up to rear blade tip (0.435, 0.555)
	var belt_y: float = 0.460
	if p.z < -0.48:
		belt_y = lerpf(0.440, 0.500, ax_norm)
	elif p.z <= 0.22:
		var t_door: float = (p.z - (-0.15)) / 0.35
		belt_y = 0.455 + 0.035 * (t_door * t_door)
	elif p.z <= 0.435:
		var t_blade: float = clampf((p.z - 0.22) / (0.435 - 0.22), 0.0, 1.0)
		belt_y = lerpf(0.490, 0.555, t_blade)
	else:
		belt_y = 10.0 # Behind the blade tip: rear haunch bodywork

	# Lateral half-width envelope: keeps glass strictly on the canopy monocoque, never on wide fender flares
	var max_glass_x: float = 0.315
	if p.z > 0.22:
		max_glass_x = lerpf(0.315, 0.240, clampf((p.z - 0.22) / (0.435 - 0.22), 0.0, 1.0))

	# 2. Windshield Top Header & Upper Roof Rail:
	# Convex aerodynamic dome arch over the cockpit:
	# In the center (ax = 0), glass flows high over the driver's head to z = 0.02,
	# curving gracefully down and forward to z = -0.10 at the side roof rail (ax = 0.26)
	var t_roof_w: float = clampf(ax / 0.26, 0.0, 1.0)
	var z_header: float = 0.02 - 0.12 * (t_roof_w * t_roof_w)

	# Side window upper roof rail (cantrail):
	# Slopes gracefully down along the rear quarter into the blade tip (z = 0.435, y = 0.555)
	var roof_rail_y: float = 0.705
	if p.z > 0.18:
		var t_top: float = clampf((p.z - 0.18) / (0.435 - 0.18), 0.0, 1.0)
		roof_rail_y = lerpf(0.705, 0.555, t_top)

	# 3. Continuous Panoramic Wrap-Around Glass Canopy
	# Seamless wrap-around glass:
	# - Above lower beltline / cowl
	# - Within lateral envelope
	# - Either forward of windshield header (visor windshield) OR below roof rail (side windows)
	var above_belt: bool = (p.z >= cowl_z and p.y >= belt_y and p.z <= 0.435 and ax <= max_glass_x)
	var in_canopy: bool = above_belt and (p.z < z_header or p.y < roof_rail_y)

	if in_canopy:
		var dist_cowl: float = p.z - cowl_z
		var dist_belt: float = p.y - belt_y
		var dist_side_x: float = max_glass_x - ax
		var dist_blade_tip: float = 0.435 - p.z
		var dist_roof_header: float = z_header - p.z if p.y >= roof_rail_y - 0.04 else 10.0
		var dist_roof_rail: float = roof_rail_y - p.y if p.z >= z_header - 0.05 else 10.0

		# Black ceramic frit / rubber perimeter seals framing the glass
		if dist_cowl < 0.014 or dist_belt < 0.010 or dist_side_x < 0.008 or dist_blade_tip < 0.008 or dist_roof_header < 0.012 or dist_roof_rail < 0.010:
			c.a = maxf(c.a, 0.95)
		else:
			c.r = 1.0
			c.a = 0.95

	# 4. White Roof & Panoramic Moonroof Glass Slot
	# The white roof is the central upper shell behind the windshield header:
	var on_roof: bool = (p.z >= z_header and p.y >= roof_rail_y and ax <= 0.28 and p.z <= 0.46)
	if on_roof:
		# Check rubber weatherstrip perimeter where white roof meets windshield header
		if absf(p.z - z_header) < 0.010:
			c.a = maxf(c.a, 0.95)

		# Panoramic moonroof glass slot in the roof
		if p.z >= 0.12 and p.z <= 0.44 and n.y > 0.18:
			var sd_mr: float = _sd_rounded(Vector2(p.x, p.z), shapes["moonroof"])
			var cov_seal: float = _cover(sd_mr, fp)
			var cov_mr: float = _cover(sd_mr + 0.008, fp)
			if cov_seal > 0.0:
				c.a = maxf(c.a, cov_seal)
			if cov_mr > 0.0:
				c.r = maxf(c.r, cov_mr)
				c.a = maxf(c.a, cov_mr * 0.95)

	# 5. Clean Door Shutlines
	if absf(n.x) > 0.35 and p.y < 0.50:
		var d_df: float = _sd_poly(Vector2(p.z, p.y), shapes["door_front"] as PackedVector2Array)
		var d_dr: float = _sd_poly(Vector2(p.z, p.y), shapes["door_rear"] as PackedVector2Array)
		var cov_df: float = _cover(absf(d_df) - 0.0025, fp)
		var cov_dr: float = _cover(absf(d_dr) - 0.0025, fp)
		var cov_gap: float = maxf(cov_df, cov_dr)
		if cov_gap > 0.0:
			c.g = maxf(c.g, cov_gap)

	# 6. Lower Door Sill / Rocker Dark Composite Band
	if p.y < 0.285 and absf(n.x) > 0.40 and p.z >= -0.38 and p.z <= 0.33:
		c.a = maxf(c.a, 0.95)

	return c

