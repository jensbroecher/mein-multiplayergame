# MinaKit.gd
#
# Procedural asset kit for Mina del Viento (Stage 4 of Sierra del Viento GP):
# 1. Very Large Array Radio Telescope Dishes (pedestal, alt-azimuth yoke, parabolic dish, quad-pod feeder, red beacon, rails)
# 2. Hot Air Balloons (teardrop envelopes with festive fiesta gore stripes, wicker baskets, propane burners)
# 3. Colossal Mining Haul Trucks (CAT 797F-scale 400-ton open-pit mining dump trucks with colossal 4m tyres)
# 4. Overhead Ore Conveyor Bridges (lattice steel truss spans with ore conveyor belts, support pylons)
# 5. Mobile Floodlight Towers (diesel generator trailer, telescoping mast, 4 high-output floodlight pods)
# 6. Tumbleweeds (rolling desert tumbleweed meshes)
extends RefCounted

const PropKit = preload("res://PropKit.gd")

static func materials() -> Dictionary:
	var m: Dictionary = {}

	# 1. Radio Dish Panels (off-white painted aluminium)
	var mat_dish := StandardMaterial3D.new()
	mat_dish.albedo_color = Color(0.92, 0.93, 0.95)
	mat_dish.roughness = 0.35
	mat_dish.metallic = 0.25
	mat_dish.cull_mode = BaseMaterial3D.CULL_DISABLED
	m["dish_panel"] = mat_dish

	# 2. Structural Steel (dark industrial galvanized steel for pedestals, yokes, trusses, truck chassis)
	var mat_steel := StandardMaterial3D.new()
	mat_steel.albedo_color = Color(0.24, 0.26, 0.28)
	mat_steel.roughness = 0.55
	mat_steel.metallic = 0.8
	m["steel"] = mat_steel

	# 3. Mining Yellow (heavy equipment high-vis polyurethane)
	var mat_yellow := StandardMaterial3D.new()
	mat_yellow.albedo_color = Color(0.94, 0.68, 0.12)
	mat_yellow.roughness = 0.38
	mat_yellow.metallic = 0.1
	m["truck_yellow"] = mat_yellow

	# 4. Colossal Truck Tyres / Dark Rubber
	var mat_rubber := StandardMaterial3D.new()
	mat_rubber.albedo_color = Color(0.12, 0.13, 0.14)
	mat_rubber.roughness = 0.88
	mat_rubber.metallic = 0.0
	m["rubber"] = mat_rubber

	# 5. Truck Cab Glass
	var mat_glass := StandardMaterial3D.new()
	mat_glass.albedo_color = Color(0.15, 0.22, 0.28, 0.85)
	mat_glass.roughness = 0.1
	mat_glass.metallic = 0.9
	m["glass"] = mat_glass

	# 6. Aircraft Warning Beacon (red emissive)
	var mat_beacon := StandardMaterial3D.new()
	mat_beacon.albedo_color = Color(1.0, 0.15, 0.12)
	mat_beacon.emission_enabled = true
	mat_beacon.emission = Color(1.0, 0.18, 0.12)
	mat_beacon.emission_energy_multiplier = 4.5
	m["beacon_red"] = mat_beacon

	# 7. Hot Air Balloon Envelopes (Festive Southwestern patterns)
	var col_schemes = [
		[Color(0.12, 0.38, 0.82), Color(0.96, 0.52, 0.14)], # Cobalt & Desert Sunset Orange
		[Color(0.88, 0.18, 0.24), Color(0.96, 0.84, 0.18)], # Crimson & Sun Gold
		[Color(0.16, 0.68, 0.58), Color(0.88, 0.22, 0.62)], # Turquoise & Desert Magenta
	]
	for idx in range(col_schemes.size()):
		var b_mat := StandardMaterial3D.new()
		b_mat.albedo_color = col_schemes[idx][0]
		b_mat.roughness = 0.6
		b_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m["balloon_%d_a" % idx] = b_mat

		var b_mat2 := StandardMaterial3D.new()
		b_mat2.albedo_color = col_schemes[idx][1]
		b_mat2.roughness = 0.6
		b_mat2.cull_mode = BaseMaterial3D.CULL_DISABLED
		m["balloon_%d_b" % idx] = b_mat2

	# 8. Wicker Basket
	var mat_wicker := StandardMaterial3D.new()
	mat_wicker.albedo_color = Color(0.58, 0.44, 0.28)
	mat_wicker.roughness = 0.9
	m["wicker"] = mat_wicker

	# 9. Burner Flame (glowing emissive orange-gold)
	var mat_flame := StandardMaterial3D.new()
	mat_flame.albedo_color = Color(1.0, 0.72, 0.22, 0.9)
	mat_flame.emission_enabled = true
	mat_flame.emission = Color(1.0, 0.65, 0.15)
	mat_flame.emission_energy_multiplier = 6.0
	mat_flame.cull_mode = BaseMaterial3D.CULL_DISABLED
	m["burner_flame"] = mat_flame

	# 10. Conveyor Belt & Crushed Copper Ore
	var mat_ore := StandardMaterial3D.new()
	mat_ore.albedo_color = Color(0.42, 0.28, 0.22) # Red-brown copper rock with green veins
	mat_ore.roughness = 0.95
	m["copper_ore"] = mat_ore

	# 11. Concrete Footings
	var mat_concrete := StandardMaterial3D.new()
	mat_concrete.albedo_color = Color(0.68, 0.67, 0.65)
	mat_concrete.roughness = 0.85
	m["concrete"] = mat_concrete

	# 12. Floodlight Emitter Pod
	var mat_flood := StandardMaterial3D.new()
	mat_flood.albedo_color = Color(1.0, 0.98, 0.92)
	mat_flood.emission_enabled = true
	mat_flood.emission = Color(1.0, 0.96, 0.88)
	mat_flood.emission_energy_multiplier = 5.0
	m["floodlight"] = mat_flood

	return m


static func new_pk() -> Array:
	var pk := PropKit.new()
	var mats := materials()
	pk.material_for = func(k: String): return mats.get(k, null)
	var kit: Dictionary = {}
	return [pk, kit]


## Constructs a Very Large Array Radio Telescope Dish.
## Sits on dual rail tracks; dish points up at tilt_deg (0=vertical zenith, 45=angled skyward).
static func radio_dish(dish_radius := 12.0, tilt_deg := 42.0, azimuth_deg := 25.0) -> ArrayMesh:
	var setup := new_pk()
	var pk: PropKit = setup[0]
	var kit: Dictionary = setup[1]

	# 1. Base Rail Bogies and Concrete/Steel Pedestal Platform
	var base_w := 9.0
	var base_l := 9.0
	var base_h := 1.8
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(0.0, base_h * 0.5, 0.0)), Vector3(base_w, base_h, base_l), Color.WHITE)

	# 4 Heavy Steel Rail Wheels (2 axles on left track, 2 on right track)
	var rail_gauge := 7.0
	for x_side in [-rail_gauge * 0.5, rail_gauge * 0.5]:
		for z_pos in [-3.2, 3.2]:
			pk.tyre(kit, "steel", Vector3(x_side, 0.45, z_pos), 0.25, 0.65, 0.4, 12, Color.WHITE, Basis(Vector3.FORWARD, PI * 0.5))

	# 2. Lattice Pedestal Tower (tapering upwards to yoke bearing)
	var tower_top_y := 12.0
	var top_w := 4.2
	var b_hw := base_w * 0.42
	var t_hw := top_w * 0.5

	# 4 Corner Tower Columns
	var c_sw := Vector3(-b_hw, base_h, -b_hw)
	var c_se := Vector3(b_hw, base_h, -b_hw)
	var c_nw := Vector3(-b_hw, base_h, b_hw)
	var c_ne := Vector3(b_hw, base_h, b_hw)

	var t_sw := Vector3(-t_hw, tower_top_y, -t_hw)
	var t_se := Vector3(t_hw, tower_top_y, -t_hw)
	var t_nw := Vector3(-t_hw, tower_top_y, t_hw)
	var t_ne := Vector3(t_hw, tower_top_y, t_hw)

	var col_th := 0.45
	pk.beam(kit, "steel", c_sw, t_sw, col_th, col_th, Color.WHITE)
	pk.beam(kit, "steel", c_se, t_se, col_th, col_th, Color.WHITE)
	pk.beam(kit, "steel", c_nw, t_nw, col_th, col_th, Color.WHITE)
	pk.beam(kit, "steel", c_ne, t_ne, col_th, col_th, Color.WHITE)

	# Horizontal Bracing Rings
	for frac in [0.35, 0.70, 1.0]:
		var h_sw = c_sw.lerp(t_sw, frac)
		var h_se = c_se.lerp(t_se, frac)
		var h_nw = c_nw.lerp(t_nw, frac)
		var h_ne = c_ne.lerp(t_ne, frac)
		pk.beam(kit, "steel", h_sw, h_se, 0.3, 0.3, Color.WHITE)
		pk.beam(kit, "steel", h_se, h_ne, 0.3, 0.3, Color.WHITE)
		pk.beam(kit, "steel", h_ne, h_nw, 0.3, 0.3, Color.WHITE)
		pk.beam(kit, "steel", h_nw, h_sw, 0.3, 0.3, Color.WHITE)

	# 3. Azimuth Yoke & Elevation Pivot Hub
	var hub_y := tower_top_y + 1.2
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(0.0, hub_y, 0.0)), Vector3(top_w * 0.9, 2.0, top_w * 0.9), Color.WHITE)

	# Two Yoke Upright Arms holding the elevation axle
	var arm_h := 3.8
	var arm_w := 1.2
	var arm_dist := 4.8
	var axle_y := hub_y + arm_h
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(-arm_dist * 0.5, hub_y + arm_h * 0.5, 0.0)), Vector3(arm_w, arm_h, 2.2), Color.WHITE)
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(arm_dist * 0.5, hub_y + arm_h * 0.5, 0.0)), Vector3(arm_w, arm_h, 2.2), Color.WHITE)

	# 4. Parabolic Reflector Dish (tilted on the elevation axle)
	var az_rad := deg_to_rad(azimuth_deg)
	var tilt_rad := deg_to_rad(tilt_deg)
	var dish_basis := Basis(Vector3.UP, az_rad) * Basis(Vector3.RIGHT, tilt_rad)
	var dish_center := Vector3(0.0, axle_y, 0.0)

	# Parabolic Dish Profile: z(r) = r^2 / (4 * f), focal length f = 8.5m
	var focal_f := 8.5
	var prof_dish: Array = []
	var dish_segs := 24
	var steps := 8
	for s in range(steps + 1):
		var r: float = float(s) / float(steps) * dish_radius
		var depth: float = (r * r) / (4.0 * focal_f)
		# profile in lathe: x is radial distance, y is along axis (dish pointing along +UP)
		prof_dish.append(Vector2(r, depth))

	# Lathe parabolic dish using dish_panel material
	pk.lathe(kit, "dish_panel", dish_center, prof_dish, dish_segs, Color.WHITE, false, dish_basis)

	# Dish Backing Steel Truss Ribs (radial support beams on convex side)
	for d_idx in range(8):
		var ang := TAU * float(d_idx) / 8.0
		var r_dir := Vector3(cos(ang), 0.0, sin(ang))
		var inner_pt: Vector3 = dish_center + dish_basis * (r_dir * 1.5 - Vector3.UP * 0.4)
		var last_y: float = float((prof_dish[-1] as Vector2).y)
		var outer_pt: Vector3 = dish_center + dish_basis * (r_dir * (dish_radius * 0.95) + Vector3.UP * (last_y - 0.4))
		pk.beam(kit, "steel", inner_pt, outer_pt, 0.35, 0.35, Color.WHITE)

	# 5. Quad-pod Feeder Horn & Sub-Reflector
	# Feeder sits at focal point: (0, focal_f, 0) in dish coordinates
	var focal_pt := dish_center + dish_basis * Vector3(0.0, focal_f, 0.0)
	# Sub-reflector small disc at focal point
	var prof_sub := [Vector2(0.0, 0.0), Vector2(1.1, 0.1), Vector2(0.8, -0.3)]
	pk.lathe(kit, "steel", focal_pt, prof_sub, 12, Color.WHITE, false, dish_basis)

	# 4 Struts from dish rim (at 75% radius) to focal point
	for f_idx in range(4):
		var fang := TAU * (float(f_idx) + 0.5) / 4.0
		var fr_dir := Vector3(cos(fang), 0.0, sin(fang))
		var base_pt := dish_center + dish_basis * (fr_dir * (dish_radius * 0.72) + Vector3.UP * ((dish_radius * 0.72) ** 2 / (4.0 * focal_f)))
		pk.beam(kit, "steel", base_pt, focal_pt, 0.16, 0.16, Color.WHITE)

	# 6. Aircraft Obstruction Beacon (red emissive light at the focal apex)
	var beacon_pt := focal_pt + dish_basis * Vector3(0.0, 0.6, 0.0)
	pk.box(kit, "beacon_red", Transform3D(Basis(), beacon_pt), Vector3(0.5, 0.5, 0.5), Color.WHITE)

	return pk.commit(kit)


## Constructs a Hot Air Balloon (airborne or tethered).
## radius ~ 6.2m, height ~ 17m. Has colorful vertical gore stripes, wicker basket, burner flame.
static func hot_air_balloon(style_idx := 0, with_flame := true) -> ArrayMesh:
	var setup := new_pk()
	var pk: PropKit = setup[0]
	var kit: Dictionary = setup[1]

	var mat_a_key := "balloon_%d_a" % (style_idx % 3)
	var mat_b_key := "balloon_%d_b" % (style_idx % 3)

	# 1. Teardrop Envelope Profile (from bottom neck y=0 up to top crown y=16.5m)
	# Smooth teardrop curve points: (radius, y)
	var env_pts = [
		Vector2(1.3, 0.0),    # neck opening
		Vector2(1.8, 1.2),
		Vector2(3.2, 3.0),
		Vector2(4.8, 5.5),
		Vector2(6.0, 8.5),    # maximum equator belly
		Vector2(6.2, 11.0),
		Vector2(5.4, 13.5),
		Vector2(3.8, 15.4),
		Vector2(1.8, 16.2),
		Vector2(0.0, 16.5),   # crown apex
	]

	# Build vertical gore panels (alternating colours a and b around 16 gores)
	var gores := 16
	for g in range(gores):
		var mat_key = mat_a_key if (g % 2 == 0) else mat_b_key
		var t0 := TAU * float(g) / float(gores)
		var t1 := TAU * float(g + 1) / float(gores)
		var u0 := Vector3(cos(t0), 0.0, sin(t0))
		var u1 := Vector3(cos(t1), 0.0, sin(t1))

		for k in range(env_pts.size() - 1):
			var p0: Vector2 = env_pts[k]
			var p1: Vector2 = env_pts[k + 1]
			var q00 := Vector3(u0.x * p0.x, p0.y, u0.z * p0.x)
			var q01 := Vector3(u1.x * p0.x, p0.y, u1.z * p0.x)
			var q10 := Vector3(u0.x * p1.x, p1.y, u0.z * p1.x)
			var q11 := Vector3(u1.x * p1.x, p1.y, u1.z * p1.x)

			var n0 := (q00 + q01).normalized()
			var n1 := (q10 + q11).normalized()
			if p0.x > 0.001 or p1.x > 0.001:
				pk.tri(kit, mat_key, q00, q01, q11, n0, n0, n1, Color.WHITE, n0)
				pk.tri(kit, mat_key, q00, q11, q10, n0, n1, n1, Color.WHITE, n0)

	# 2. Suspension Cables down to Basket
	var basket_top_y := -2.4
	var basket_bot_y := -3.8
	var basket_hw := 1.1

	var cable_attach_r := 1.35
	var c_angles = [0.25 * PI, 0.75 * PI, 1.25 * PI, 1.75 * PI]
	var b_corners = [
		Vector3(basket_hw, basket_top_y, basket_hw),
		Vector3(-basket_hw, basket_top_y, basket_hw),
		Vector3(-basket_hw, basket_top_y, -basket_hw),
		Vector3(basket_hw, basket_top_y, -basket_hw),
	]
	for i in range(4):
		var top_cable := Vector3(cos(c_angles[i]) * cable_attach_r, 0.1, sin(c_angles[i]) * cable_attach_r)
		pk.beam(kit, "steel", top_cable, b_corners[i], 0.03, 0.03, Color.WHITE)

	# 3. Wicker Basket (woven gondola)
	var basket_size := Vector3(basket_hw * 2.0, basket_top_y - basket_bot_y, basket_hw * 2.0)
	var basket_center := Vector3(0.0, (basket_top_y + basket_bot_y) * 0.5, 0.0)
	pk.box(kit, "wicker", Transform3D(Basis(), basket_center), basket_size, Color.WHITE)

	# 4. Propane Burner Frame & Flame
	var burner_y := -1.3
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(0.0, burner_y, 0.0)), Vector3(0.7, 0.25, 0.7), Color.WHITE)
	if with_flame:
		# Emissive vertical flame column
		var flame_size := Vector3(0.45, 1.1, 0.45)
		pk.box(kit, "burner_flame", Transform3D(Basis(), Vector3(0.0, burner_y + 0.65, 0.0)), flame_size, Color.WHITE)

	return pk.commit(kit)


## Constructs a Colossal Open-Pit Mining Haul Truck (CAT 797F scale).
## 15m long, 9m wide, 7.5m high. Front wheels turn slightly.
static func haul_truck() -> ArrayMesh:
	var setup := new_pk()
	var pk: PropKit = setup[0]
	var kit: Dictionary = setup[1]

	# 1. 6 Colossal Wheels (2 front, 4 dual-rear)
	# Tyre dimensions: outer radius 2.0m, inner rim 1.0m, width 1.35m
	var tyre_r_out := 2.0
	var tyre_r_in := 0.95
	var tyre_w := 1.35
	var front_z := 4.2
	var rear_z := -3.6
	var axle_track := 6.6

	# Left Front Wheel (slight steering turn)
	var b_steer_l := Basis(Vector3.UP, deg_to_rad(-8.0)) * Basis(Vector3.FORWARD, PI * 0.5)
	pk.tyre(kit, "rubber", Vector3(-axle_track * 0.5, tyre_r_out, front_z), tyre_r_in, tyre_r_out, tyre_w, 16, Color.WHITE, b_steer_l)
	pk.tube(kit, "steel", Vector3(-axle_track * 0.5 - 0.2, tyre_r_out, front_z), Vector3(-axle_track * 0.5 + 0.2, tyre_r_out, front_z), 0.9, 0.9, 12, Color.WHITE)

	# Right Front Wheel
	var b_steer_r := Basis(Vector3.UP, deg_to_rad(-8.0)) * Basis(Vector3.FORWARD, PI * 0.5)
	pk.tyre(kit, "rubber", Vector3(axle_track * 0.5, tyre_r_out, front_z), tyre_r_in, tyre_r_out, tyre_w, 16, Color.WHITE, b_steer_r)
	pk.tube(kit, "steel", Vector3(axle_track * 0.5 - 0.2, tyre_r_out, front_z), Vector3(axle_track * 0.5 + 0.2, tyre_r_out, front_z), 0.9, 0.9, 12, Color.WHITE)

	# Dual Rear Wheels on Left Side
	var b_flat := Basis(Vector3.FORWARD, PI * 0.5)
	pk.tyre(kit, "rubber", Vector3(-axle_track * 0.5 - 0.75, tyre_r_out, rear_z), tyre_r_in, tyre_r_out, tyre_w, 16, Color.WHITE, b_flat)
	pk.tyre(kit, "rubber", Vector3(-axle_track * 0.5 + 0.75, tyre_r_out, rear_z), tyre_r_in, tyre_r_out, tyre_w, 16, Color.WHITE, b_flat)

	# Dual Rear Wheels on Right Side
	pk.tyre(kit, "rubber", Vector3(axle_track * 0.5 - 0.75, tyre_r_out, rear_z), tyre_r_in, tyre_r_out, tyre_w, 16, Color.WHITE, b_flat)
	pk.tyre(kit, "rubber", Vector3(axle_track * 0.5 + 0.75, tyre_r_out, rear_z), tyre_r_in, tyre_r_out, tyre_w, 16, Color.WHITE, b_flat)

	# 2. Heavy Chassis Frame & Lower Drivetrain
	var chassis_w := 3.6
	var chassis_l := 12.0
	var chassis_y := 2.2
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(0.0, chassis_y, 0.0)), Vector3(chassis_w, 1.4, chassis_l), Color.WHITE)

	# Massive Front Radiator Grille
	var rad_z := front_z + 2.2
	var rad_h := 2.8
	var rad_y := 3.2
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(0.0, rad_y, rad_z)), Vector3(chassis_w * 0.95, rad_h, 0.9), Color.WHITE)

	# Front Bumper & Twin Headlight Clusters
	var b_y := 1.2
	pk.box(kit, "steel", Transform3D(Basis(), Vector3(0.0, b_y, rad_z + 0.6)), Vector3(chassis_w * 1.5, 0.9, 0.8), Color.WHITE)
	# Headlights
	pk.box(kit, "floodlight", Transform3D(Basis(), Vector3(-1.8, b_y, rad_z + 1.05)), Vector3(0.7, 0.35, 0.2), Color.WHITE)
	pk.box(kit, "floodlight", Transform3D(Basis(), Vector3(1.8, b_y, rad_z + 1.05)), Vector3(0.7, 0.35, 0.2), Color.WHITE)

	# 3. Main Deck & Forward Operator Cab (Offset to Front-Left)
	var deck_y := chassis_y + 1.8 # y ~ 4.0
	var deck_w := 8.2
	var deck_l := 4.2
	pk.box(kit, "truck_yellow", Transform3D(Basis(), Vector3(0.0, deck_y, front_z)), Vector3(deck_w, 0.45, deck_l), Color.WHITE)

	# Operator Cab (on front-left corner)
	var cab_pos := Vector3(-2.6, deck_y + 1.4, front_z + 0.4)
	var cab_size := Vector3(2.4, 2.4, 2.6)
	pk.box(kit, "truck_yellow", Transform3D(Basis(), cab_pos), cab_size, Color.WHITE)
	# Cab Windshield & Windows
	pk.box(kit, "glass", Transform3D(Basis(), cab_pos + Vector3(0.0, 0.3, 1.32)), Vector3(2.1, 1.4, 0.1), Color.WHITE)
	pk.box(kit, "glass", Transform3D(Basis(), cab_pos + Vector3(-1.22, 0.3, 0.0)), Vector3(0.1, 1.4, 2.1), Color.WHITE)

	# Right-side Equipment Deck / Air Filters
	pk.tube(kit, "steel", Vector3(2.2, deck_y + 0.2, front_z + 0.6), Vector3(2.2, deck_y + 2.0, front_z + 0.6), 0.65, 0.65, 12, Color.WHITE)
	pk.tube(kit, "steel", Vector3(3.4, deck_y + 0.2, front_z + 0.6), Vector3(3.4, deck_y + 2.0, front_z + 0.6), 0.65, 0.65, 12, Color.WHITE)

	# Front Diagonal Access Stairway
	pk.beam(kit, "steel", Vector3(0.0, b_y + 0.4, rad_z + 0.7), Vector3(-1.4, deck_y, front_z + 1.8), 0.65, 0.15, Color.WHITE)

	# 4. Colossal Mining Dump Bed (Rock Body Box)
	# 11.5m long, 8.8m wide, 4.0m deep. Angled canopy extending over the cab!
	var bed_pivot_z := rear_z - 1.2
	var bed_pivot_y := chassis_y + 1.2
	var bed_tilt_deg := 4.0
	var b_bed := Basis(Vector3.RIGHT, deg_to_rad(-bed_tilt_deg))

	# Bed Floor
	var bed_l := 10.5
	var bed_w := 8.4
	var bed_center := Vector3(0.0, bed_pivot_y + 1.4, bed_pivot_z + bed_l * 0.45)
	pk.box(kit, "truck_yellow", Transform3D(b_bed, bed_center), Vector3(bed_w, 0.6, bed_l), Color.WHITE)

	# Bed Left & Right Slanted Rock Walls
	var wall_h := 3.2
	var w_left_pos := bed_center + b_bed * Vector3(-bed_w * 0.5 + 0.25, wall_h * 0.5, 0.0)
	var w_right_pos := bed_center + b_bed * Vector3(bed_w * 0.5 - 0.25, wall_h * 0.5, 0.0)
	pk.box(kit, "truck_yellow", Transform3D(b_bed, w_left_pos), Vector3(0.5, wall_h, bed_l), Color.WHITE)
	pk.box(kit, "truck_yellow", Transform3D(b_bed, w_right_pos), Vector3(0.5, wall_h, bed_l), Color.WHITE)

	# Bed Front Bulkhead & Forward Canopy (Protects Cab from falling rocks)
	var front_wall_pos := bed_center + b_bed * Vector3(0.0, wall_h * 0.5, bed_l * 0.5 - 0.25)
	pk.box(kit, "truck_yellow", Transform3D(b_bed, front_wall_pos), Vector3(bed_w, wall_h, 0.5), Color.WHITE)
	# Overhead Cab Canopy extension
	var canopy_pos := front_wall_pos + b_bed * Vector3(0.0, wall_h * 0.48, 2.4)
	pk.box(kit, "truck_yellow", Transform3D(b_bed, canopy_pos), Vector3(bed_w * 0.95, 0.4, 4.8), Color.WHITE)

	# Exterior Reinforcing Ribs along the dump bed sides
	for rib_s in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		var r_pos_l := bed_center + b_bed * Vector3(-bed_w * 0.5 - 0.2, wall_h * 0.5, rib_s)
		var r_pos_r := bed_center + b_bed * Vector3(bed_w * 0.5 + 0.2, wall_h * 0.5, rib_s)
		pk.box(kit, "truck_yellow", Transform3D(b_bed, r_pos_l), Vector3(0.35, wall_h, 0.4), Color.WHITE)
		pk.box(kit, "truck_yellow", Transform3D(b_bed, r_pos_r), Vector3(0.35, wall_h, 0.4), Color.WHITE)

	# Hydraulic Hoist Cylinders under dump body
	pk.tube(kit, "steel", Vector3(-1.4, chassis_y, -0.6), Vector3(-1.4, chassis_y + 2.2, 0.2), 0.35, 0.35, 10, Color.WHITE)
	pk.tube(kit, "steel", Vector3(1.4, chassis_y, -0.6), Vector3(1.4, chassis_y + 2.2, 0.2), 0.35, 0.35, 10, Color.WHITE)

	return pk.commit(kit)


## Overhead Heavy Ore Conveyor Bridge spanning across the track.
## span: horizontal width across road (e.g. 36m). height: road clearance (e.g. 9.5m).
static func conveyor_bridge(span := 36.0, clearance := 9.5) -> ArrayMesh:
	var setup := new_pk()
	var pk: PropKit = setup[0]
	var kit: Dictionary = setup[1]

	var truss_h := 3.2
	var truss_w := 3.8
	var bridge_y := clearance + truss_h * 0.5

	# 1. Main Horizontal Lattice Truss Box
	# Top and Bottom Chord Beams
	var half_span := span * 0.5
	var chords = [
		[Vector3(-half_span, clearance, -truss_w * 0.5), Vector3(half_span, clearance, -truss_w * 0.5)],
		[Vector3(-half_span, clearance, truss_w * 0.5), Vector3(half_span, clearance, truss_w * 0.5)],
		[Vector3(-half_span, clearance + truss_h, -truss_w * 0.5), Vector3(half_span, clearance + truss_h, -truss_w * 0.5)],
		[Vector3(-half_span, clearance + truss_h, truss_w * 0.5), Vector3(half_span, clearance + truss_h, truss_w * 0.5)],
	]
	for ch in chords:
		pk.beam(kit, "steel", ch[0], ch[1], 0.35, 0.35, Color.WHITE)

	# Diagonal Warren Truss Struts along both sides
	var bays := 8
	var bay_len: float = span / float(bays)
	for b in range(bays):
		var x0 := -half_span + float(b) * bay_len
		var x1 := x0 + bay_len
		for z_side in [-truss_w * 0.5, truss_w * 0.5]:
			var p_bl := Vector3(x0, clearance, z_side)
			var p_br := Vector3(x1, clearance, z_side)
			var p_tl := Vector3(x0, clearance + truss_h, z_side)
			var p_tr := Vector3(x1, clearance + truss_h, z_side)

			pk.beam(kit, "steel", p_bl, p_tr if (b % 2 == 0) else p_tl, 0.2, 0.2, Color.WHITE)
			pk.beam(kit, "steel", p_br, p_tr, 0.25, 0.25, Color.WHITE)

	# 2. Rubber Conveyor Belt & Crushed Copper Ore inside the truss
	var belt_y := clearance + 1.1
	pk.box(kit, "rubber", Transform3D(Basis(), Vector3(0.0, belt_y, 0.0)), Vector3(span + 2.0, 0.15, 2.0), Color.WHITE)
	# Crushed Copper Ore Ridge riding on top of the belt
	pk.box(kit, "copper_ore", Transform3D(Basis(), Vector3(0.0, belt_y + 0.3, 0.0)), Vector3(span + 2.0, 0.45, 1.4), Color.WHITE)

	# 3. Two Incline Support Trestle Towers on each side of the roadway
	for x_side in [-half_span + 1.5, half_span - 1.5]:
		# Concrete Foundation Pad
		pk.box(kit, "concrete", Transform3D(Basis(), Vector3(x_side, 0.5, 0.0)), Vector3(3.2, 1.0, 5.2), Color.WHITE)
		# Steel Trestle Legs from footing up to bridge bottom
		var f_sw := Vector3(x_side - 1.0, 1.0, -2.0)
		var f_se := Vector3(x_side + 1.0, 1.0, -2.0)
		var f_nw := Vector3(x_side - 1.0, 1.0, 2.0)
		var f_ne := Vector3(x_side + 1.0, 1.0, 2.0)

		var b_sw := Vector3(x_side - 0.7, clearance, -truss_w * 0.5)
		var b_se := Vector3(x_side + 0.7, clearance, -truss_w * 0.5)
		var b_nw := Vector3(x_side - 0.7, clearance, truss_w * 0.5)
		var b_ne := Vector3(x_side + 0.7, clearance, truss_w * 0.5)

		pk.beam(kit, "steel", f_sw, b_sw, 0.38, 0.38, Color.WHITE)
		pk.beam(kit, "steel", f_se, b_se, 0.38, 0.38, Color.WHITE)
		pk.beam(kit, "steel", f_nw, b_nw, 0.38, 0.38, Color.WHITE)
		pk.beam(kit, "steel", f_ne, b_ne, 0.38, 0.38, Color.WHITE)

	return pk.commit(kit)


## Mobile Industrial Floodlight Trailer (illuminates open-pit quarry tiers).
static func floodlight_tower() -> ArrayMesh:
	var setup := new_pk()
	var pk: PropKit = setup[0]
	var kit: Dictionary = setup[1]

	# 1. Trailer Base & Generator Box
	pk.box(kit, "truck_yellow", Transform3D(Basis(), Vector3(0.0, 0.75, 0.0)), Vector3(1.8, 0.9, 2.8), Color.WHITE)
	# 2 Wheels on axle
	pk.tyre(kit, "rubber", Vector3(-1.15, 0.45, 0.0), 0.2, 0.45, 0.3, 12, Color.WHITE, Basis(Vector3.FORWARD, PI * 0.5))
	pk.tyre(kit, "rubber", Vector3(1.15, 0.45, 0.0), 0.2, 0.45, 0.3, 12, Color.WHITE, Basis(Vector3.FORWARD, PI * 0.5))

	# 2. Telescoping Vertical Mast (height 8.5m)
	var mast_h := 8.5
	pk.beam(kit, "steel", Vector3(0.0, 1.2, 0.4), Vector3(0.0, mast_h, 0.4), 0.25, 0.25, Color.WHITE)

	# 3. Crossbar & 4 High-Output LED Floodlight Pods
	var bar_y := mast_h
	pk.beam(kit, "steel", Vector3(-1.6, bar_y, 0.4), Vector3(1.6, bar_y, 0.4), 0.15, 0.15, Color.WHITE)

	# 4 Angled Light Pods pointing downward into the pit
	var pod_tilt := Basis(Vector3.RIGHT, deg_to_rad(35.0))
	for x_pos in [-1.2, -0.4, 0.4, 1.2]:
		var pod_center := Vector3(x_pos, bar_y - 0.25, 0.55)
		pk.box(kit, "steel", Transform3D(pod_tilt, pod_center), Vector3(0.55, 0.4, 0.25), Color.WHITE)
		pk.box(kit, "floodlight", Transform3D(pod_tilt, pod_center + pod_tilt * Vector3(0.0, 0.0, 0.14)), Vector3(0.48, 0.32, 0.05), Color.WHITE)

	return pk.commit(kit)


## Knockable Tumbleweed Mesh (dry desert scrub sphere).
static func tumbleweed_mesh(radius := 0.65) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var mat_brush := StandardMaterial3D.new()
	mat_brush.albedo_color = Color(0.62, 0.52, 0.36)
	mat_brush.roughness = 0.95
	mat_brush.cull_mode = BaseMaterial3D.CULL_DISABLED

	# 6 crossed multi-plane fans forming a bristly tangled sphere
	var planes := 6
	for p in range(planes):
		var yaw := TAU * float(p) / float(planes)
		var pitch := ((p % 3) - 1.0) * 0.35
		var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)

		var p0 := rot * Vector3(-radius, -radius * 0.8, 0.0)
		var p1 := rot * Vector3(radius, -radius * 0.8, 0.0)
		var p2 := rot * Vector3(radius, radius * 0.8, 0.0)
		var p3 := rot * Vector3(-radius, radius * 0.8, 0.0)

		var n := rot * Vector3.FORWARD
		st.set_normal(n)
		st.set_color(Color(0.65, 0.55, 0.38))

		st.set_uv(Vector2(0, 1))
		st.add_vertex(p0)
		st.set_uv(Vector2(1, 1))
		st.add_vertex(p1)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p2)

		st.set_uv(Vector2(0, 1))
		st.add_vertex(p0)
		st.set_uv(Vector2(1, 0))
		st.add_vertex(p2)
		st.set_uv(Vector2(0, 0))
		st.add_vertex(p3)

	st.set_material(mat_brush)
	return st.commit()
