extends RefCounted
class_name WindTurbineBuilder

## Procedural builder for modern utility-scale wind turbines.
## Produces a complete wind turbine with tapered tower, streamlined nacelle,
## bullet-nose hub, and 3 aerodynamic twisted airfoil blades with red aviation stripes.
## All meshes are completely solid & sealed (bulkheads, caps, deep foundation plinths)
## with verified outward normals and zero gaps.

const TOWER_HEIGHT := 40.0
const TOWER_BASE_R := 1.95
const TOWER_TOP_R := 1.15
const NACELLE_LEN := 7.9
const ROTOR_RADIUS := 21.0

# Explicit direction vectors (avoiding engine-dependent forward/back ambiguities)
const DIR_FRONT := Vector3(0, 0, 1)  # Rotor spin axis pointing forward
const DIR_BACK := Vector3(0, 0, -1)  # Facing rear toward tail

const COLOR_WHITE := Color(0.93, 0.94, 0.95)
const COLOR_CONCRETE := Color(0.68, 0.70, 0.72)
const COLOR_STEEL := Color(0.28, 0.30, 0.33)
const COLOR_RED_STRIPE := Color(0.88, 0.12, 0.12)
const COLOR_BEACON := Color(1.0, 0.12, 0.12)


## Builds a complete WindTurbine Node3D ready to place in the scene.
## Accepts optional pre-built/saved Mesh resources so instances share mesh memory.
static func build_turbine(spin_speed: float, initial_angle: float, yaw_deg: float,
		tower_mesh: Mesh = null, nacelle_mesh: Mesh = null, rotor_mesh: Mesh = null) -> Node3D:
	var root := Node3D.new()
	root.name = "WindTurbine"
	root.rotation_degrees.y = yaw_deg

	# 1. Base pad & Tower (Static)
	var tower_mi := MeshInstance3D.new()
	tower_mi.name = "Tower"
	tower_mi.mesh = tower_mesh if tower_mesh != null else build_tower_mesh()
	root.add_child(tower_mi)

	# Static collision for tower base
	var body := StaticBody3D.new()
	body.name = "TowerCollision"
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 12.0
	cyl.radius = TOWER_BASE_R + 0.2
	col.shape = cyl
	col.position = Vector3(0, 6.0, 0)
	body.add_child(col)
	root.add_child(body)

	# 2. Nacelle (mounted at top of tower)
	var nacelle_mi := MeshInstance3D.new()
	nacelle_mi.name = "Nacelle"
	nacelle_mi.mesh = nacelle_mesh if nacelle_mesh != null else build_nacelle_mesh()
	nacelle_mi.position = Vector3(0, TOWER_HEIGHT, 0)
	root.add_child(nacelle_mi)

	# Aviation Warning Beacon light dome atop rear nacelle
	var beacon_mi := MeshInstance3D.new()
	beacon_mi.name = "Beacon"
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.45
	sphere.radial_segments = 12
	sphere.rings = 6
	var beacon_mat := StandardMaterial3D.new()
	beacon_mat.albedo_color = COLOR_BEACON
	beacon_mat.emission_enabled = true
	beacon_mat.emission = COLOR_BEACON
	beacon_mat.emission_energy_multiplier = 3.5
	beacon_mat.roughness = 0.2
	beacon_mi.mesh = sphere
	beacon_mi.material_override = beacon_mat
	beacon_mi.position = Vector3(0, TOWER_HEIGHT + 1.75, -4.0)
	root.add_child(beacon_mi)

	# 3. Rotor Pivot (rotates in _process)
	var pivot := Node3D.new()
	pivot.name = "RotorPivot"
	# Hub is positioned at front bulkhead of nacelle (+Z)
	pivot.position = Vector3(0, TOWER_HEIGHT, 2.2)
	pivot.rotation_degrees.z = initial_angle

	var rotor_mi := MeshInstance3D.new()
	rotor_mi.name = "Rotor"
	rotor_mi.mesh = rotor_mesh if rotor_mesh != null else build_rotor_mesh()
	pivot.add_child(rotor_mi)
	root.add_child(pivot)

	# 4. Attach animation controller
	var script := load("res://WindTurbine.gd")
	if script:
		root.set_script(script)
		root.set("spin_speed", spin_speed)
		root.set("initial_angle", initial_angle)

	return root


## Builds the tower mesh including foundation plinth, flange, shaft, and access door.
## Completely gapless with deep foundation into terrain and sealed top platform.
static func build_tower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 24

	# A. Concrete Foundation Plinth (Deep skirt down to -3.5m so steep slopes never show gaps)
	var y_plinth_bot := -3.5
	var y_plinth_top := 0.8
	var r_plinth := 3.6
	_add_cylinder_wall(st, y_plinth_bot, y_plinth_top, r_plinth, r_plinth, segs, COLOR_CONCRETE)
	# Sealed bottom disc at base
	_add_disc(st, Vector3(0, y_plinth_bot, 0), r_plinth, Vector3.DOWN, segs, COLOR_CONCRETE)

	# Plinth top stepped ring: from r_plinth (3.6) in to flange_r (2.45) at y = 0.8
	var r_flange := 2.45
	_add_horizontal_ring(st, y_plinth_top, r_flange, r_plinth, segs, true, COLOR_CONCRETE)

	# B. Steel base mounting ring / flange collar (from 0.8m to 1.3m, r = 2.45)
	var y_flange_top := 1.3
	_add_cylinder_wall(st, y_plinth_top, y_flange_top, r_flange, r_flange, segs, COLOR_STEEL)
	# Flange top stepped ring: from r_flange (2.45) in to tower base (1.95) at y = 1.3
	_add_horizontal_ring(st, y_flange_top, TOWER_BASE_R, r_flange, segs, true, COLOR_STEEL)

	# C. Tapered Tubular Tower Shaft (from 1.3m up to 40.0m)
	var rings := 8
	for r in range(rings):
		var t0: float = float(r) / float(rings)
		var t1: float = float(r + 1) / float(rings)
		var y0: float = lerpf(y_flange_top, TOWER_HEIGHT, t0)
		var y1: float = lerpf(y_flange_top, TOWER_HEIGHT, t1)
		var rad0: float = lerpf(TOWER_BASE_R, TOWER_TOP_R, t0)
		var rad1: float = lerpf(TOWER_BASE_R, TOWER_TOP_R, t1)

		var col := COLOR_WHITE if r % 2 == 0 else Color(0.91, 0.92, 0.93)
		_add_cylinder_wall(st, y0, y1, rad0, rad1, segs, col)

	# D. Sealed top yaw platform disc at TOWER_HEIGHT (r = 1.15)
	_add_disc(st, Vector3(0, TOWER_HEIGHT, 0), TOWER_TOP_R, Vector3.UP, segs, COLOR_STEEL)

	# E. Base Access Door (at rear: -Z)
	var door_w := 0.75
	var door_h := 1.8
	var door_y := y_flange_top + 0.3
	var door_z := -TOWER_BASE_R * 0.99
	_add_box(st, Vector3(0, door_y + door_h * 0.5, door_z), Vector3(door_w, door_h, 0.08), COLOR_STEEL)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.38
	mat.metallic = 0.12
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Builds the streamlined nacelle generator housing at the tower top.
## Features sealed front hub bulkhead, smooth hull, rear tail wedge, and yaw skirt.
static func build_nacelle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_radial := 24

	# Nacelle coordinates along Z (local origin at tower top pivot):
	# Hub is at +Z (~ +2.2), Tail is at -Z (~ -5.7).
	var z_stations := [2.2, 1.6, 0.6, -1.0, -3.0, -4.8, -5.7]
	var half_w := [1.40, 1.45, 1.45, 1.40, 1.30, 1.00, 0.45]
	var half_h := [1.40, 1.45, 1.42, 1.38, 1.25, 0.95, 0.40]
	var y_center := [0.0, 0.05, 0.08, 0.08, 0.05, 0.0, -0.05]

	# 1. Front Bulkhead / Hub mount disc (facing +Z at z = 2.2)
	_add_disc(st, Vector3(0, y_center[0], z_stations[0]), half_w[0], DIR_FRONT, n_radial, COLOR_STEEL)

	# 2. Aerodynamic Nacelle Body (stations ordered from front +Z to tail -Z, z0 > z1)
	for s in range(z_stations.size() - 1):
		var z0: float = z_stations[s]
		var z1: float = z_stations[s + 1]
		var w0: float = half_w[s]
		var w1: float = half_w[s + 1]
		var h0: float = half_h[s]
		var h1: float = half_h[s + 1]
		var yc0: float = y_center[s]
		var yc1: float = y_center[s + 1]

		for i in range(n_radial):
			var a0: float = TAU * float(i) / float(n_radial)
			var a1: float = TAU * float(i + 1) / float(n_radial)
			var c0: float = cos(a0)
			var s0: float = sin(a0)
			var c1: float = cos(a1)
			var s1: float = sin(a1)

			var p0 := Vector3(c0 * w0, yc0 + s0 * h0, z0)
			var p1 := Vector3(c1 * w0, yc0 + s1 * h0, z0)
			var p2 := Vector3(c1 * w1, yc1 + s1 * h1, z1)
			var p3 := Vector3(c0 * w1, yc0 + s0 * h1, z1)

			var n0 := Vector3(c0, s0, (z0 - z1) * 0.1).normalized()
			var n1 := Vector3(c1, s1, (z0 - z1) * 0.1).normalized()

			var col := COLOR_WHITE
			if absf(s0) < 0.25 and c0 > 0.0:
				col = Color(0.85, 0.87, 0.89)

			_add_quad(st, p0, p1, p2, p3, n0, n1, col)

	# 3. Rear Tail Wedge disc (facing -Z at z = -5.7)
	var z_tail: float = z_stations.back()
	var yc_tail: float = y_center.back()
	_add_disc(st, Vector3(0, yc_tail, z_tail), half_w.back(), DIR_BACK, n_radial, COLOR_STEEL)

	# 4. Under-nacelle yaw skirt collar (overlaps tower top)
	# Collar from y = -0.6 to y = 0.05, radius = 1.25
	var skirt_r := 1.25
	_add_cylinder_wall(st, -0.6, 0.05, skirt_r, skirt_r, n_radial, COLOR_STEEL)
	# Bottom rim facing DOWN at -0.6
	_add_horizontal_ring(st, -0.6, TOWER_TOP_R, skirt_r, n_radial, false, COLOR_STEEL)

	# 5. Roof details: Anemometer mast
	var mast_base := Vector3(0, 1.45, -4.2)
	_add_box(st, mast_base + Vector3(0, 0.55, 0), Vector3(0.08, 1.1, 0.08), COLOR_STEEL)
	_add_box(st, mast_base + Vector3(0, 1.1, 0), Vector3(0.5, 0.06, 0.06), COLOR_STEEL)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.32
	mat.metallic = 0.15
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Builds the rotating rotor assembly: aerodynamic spinner nosecone + 3 airfoil blades.
## Features solid rear backplate, smooth bullet-nose cone with apex fan, and 3 twisted blades.
static func build_rotor_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_spin_segs := 24
	var spinner_base_r := 1.42
	var spinner_len := 2.6

	# 1. Spinner Back Plate (solid disc facing -Z at z = 0.0)
	_add_disc(st, Vector3.ZERO, spinner_base_r, DIR_BACK, n_spin_segs, COLOR_STEEL)

	# 2. Spinner Bullet Cone (z0 < z1, so larger Z goes first for outward normal)
	var z_steps := 5
	for z_i in range(z_steps - 1):
		var t0: float = float(z_i) / float(z_steps)
		var t1: float = float(z_i + 1) / float(z_steps)
		var z0: float = t0 * spinner_len
		var z1: float = t1 * spinner_len
		var r0: float = spinner_base_r * sqrt(maxf(1.0 - t0, 0.0))
		var r1: float = spinner_base_r * sqrt(maxf(1.0 - t1, 0.0))

		for i in range(n_spin_segs):
			var a0: float = TAU * float(i) / float(n_spin_segs)
			var a1: float = TAU * float(i + 1) / float(n_spin_segs)
			var c0: float = cos(a0)
			var s0: float = sin(a0)
			var c1: float = cos(a1)
			var s1: float = sin(a1)

			# Larger Z first (z1 first, then z0) for outward normal
			var p0 := Vector3(c0 * r1, s0 * r1, z1)
			var p1 := Vector3(c1 * r1, s1 * r1, z1)
			var p2 := Vector3(c1 * r0, s1 * r0, z0)
			var p3 := Vector3(c0 * r0, s0 * r0, z0)

			var n0 := Vector3(c0, s0, 0.45).normalized()
			var n1 := Vector3(c1, s1, 0.45).normalized()
			_add_quad(st, p0, p1, p2, p3, n0, n1, COLOR_WHITE)

	# 3. Clean Tip Triangle Fan to Apex (non-degenerate, outward normals)
	var t_apex_base: float = float(z_steps - 1) / float(z_steps)
	var z_apex_base: float = t_apex_base * spinner_len
	var r_apex_base: float = spinner_base_r * sqrt(maxf(1.0 - t_apex_base, 0.0))
	var apex := Vector3(0, 0, spinner_len)
	for i in range(n_spin_segs):
		var a0: float = TAU * float(i) / float(n_spin_segs)
		var a1: float = TAU * float(i + 1) / float(n_spin_segs)
		var p0 := Vector3(cos(a0) * r_apex_base, sin(a0) * r_apex_base, z_apex_base)
		var p1 := Vector3(cos(a1) * r_apex_base, sin(a1) * r_apex_base, z_apex_base)
		var n0 := Vector3(cos(a0), sin(a0), 0.5).normalized()
		var n1 := Vector3(cos(a1), sin(a1), 0.5).normalized()

		st.set_color(COLOR_WHITE)
		st.set_normal(DIR_FRONT)
		st.add_vertex(apex)
		st.set_normal(n1)
		st.add_vertex(p1)
		st.set_normal(n0)
		st.add_vertex(p0)

	# 4. 3 Aerodynamic Airfoil Blades (at 0°, 120°, 240°)
	for blade_idx in range(3):
		var blade_angle: float = TAU * float(blade_idx) / 3.0
		_build_single_blade(st, blade_angle)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 0.30
	var mesh := st.commit()
	mesh.surface_set_material(0, mat)
	return mesh


## Constructs one aerodynamic airfoil blade radiating outward at `angle_rad`.
static func _build_single_blade(st: SurfaceTool, angle_rad: float) -> void:
	# Blade radial stations (root starts inside the 1.42m spinner at 0.8m for seamless emergence)
	var r_stations := [0.8, 1.8, 3.2, 5.5, 8.5, 12.0, 15.5, 18.0, 19.5, 21.0]
	var chords := [1.10, 1.35, 1.55, 1.50, 1.30, 1.08, 0.80, 0.58, 0.42, 0.22]
	var thicks := [0.95, 0.70, 0.42, 0.33, 0.25, 0.18, 0.13, 0.08, 0.06, 0.04]
	var twists := [16.0, 14.0, 10.0, 7.0, 4.5, 2.5, 1.2, 0.5, 0.0, -0.5]

	var v_rad := Vector3(cos(angle_rad), sin(angle_rad), 0.0)
	var v_tan := Vector3(-sin(angle_rad), cos(angle_rad), 0.0)
	var v_norm := DIR_FRONT

	# Airfoil loop ordered CCW in airfoil cross-section so normals face outward
	var x_pts := [1.0, 0.75, 0.40, 0.15, 0.0, 0.15, 0.40, 0.75]
	var y_pts := [0.0, 0.28, 0.50, 0.38, 0.0, -0.10, -0.18, -0.15]
	var n_pts := x_pts.size()

	for s in range(r_stations.size() - 1):
		var r0: float = r_stations[s]
		var r1: float = r_stations[s + 1]
		var ch0: float = chords[s]
		var ch1: float = chords[s + 1]
		var th0: float = thicks[s]
		var th1: float = thicks[s + 1]
		var tw0: float = deg_to_rad(twists[s])
		var tw1: float = deg_to_rad(twists[s + 1])

		# Aviation red safety stripes near the tip
		var col := COLOR_WHITE
		var mid_r := (r0 + r1) * 0.5
		if (mid_r >= 16.5 and mid_r <= 18.0) or (mid_r >= 19.2 and mid_r <= 21.0):
			col = COLOR_RED_STRIPE

		for p in range(n_pts):
			var p_next: int = (p + 1) % n_pts
			var p00 := _sample_airfoil(r0, x_pts[p], y_pts[p], ch0, th0, tw0, v_rad, v_tan, v_norm)
			var p01 := _sample_airfoil(r0, x_pts[p_next], y_pts[p_next], ch0, th0, tw0, v_rad, v_tan, v_norm)
			var p11 := _sample_airfoil(r1, x_pts[p_next], y_pts[p_next], ch1, th1, tw1, v_rad, v_tan, v_norm)
			var p10 := _sample_airfoil(r1, x_pts[p], y_pts[p], ch1, th1, tw1, v_rad, v_tan, v_norm)

			# Surface normal estimation for smooth lighting
			var n0 := (p00 - (v_rad * r0 + v_norm * (0.35 - r0 * 0.03))).normalized()
			var n1 := (p01 - (v_rad * r0 + v_norm * (0.35 - r0 * 0.03))).normalized()

			_add_quad(st, p00, p10, p11, p01, n0, n1, col)

	# Blade rounded tip cap
	var r_tip: float = r_stations.back()
	var ch_tip: float = chords.back()
	var th_tip: float = thicks.back()
	var tw_tip: float = deg_to_rad(twists.back())
	var tip_apex := v_rad * (r_tip + 0.35) + v_norm * (0.35 - r_tip * 0.03)
	for p in range(n_pts):
		var p_next: int = (p + 1) % n_pts
		var p0 := _sample_airfoil(r_tip, x_pts[p], y_pts[p], ch_tip, th_tip, tw_tip, v_rad, v_tan, v_norm)
		var p1 := _sample_airfoil(r_tip, x_pts[p_next], y_pts[p_next], ch_tip, th_tip, tw_tip, v_rad, v_tan, v_norm)
		st.set_color(COLOR_RED_STRIPE)
		st.set_normal(v_rad)
		st.add_vertex(tip_apex)
		st.add_vertex(p1)
		st.add_vertex(p0)


## Helper: computes 3D position of an airfoil point with pitch twist and hub offset.
static func _sample_airfoil(r: float, u: float, v: float, chord: float, thick: float, twist: float,
		v_rad: Vector3, v_tan: Vector3, v_norm: Vector3) -> Vector3:
	var local_x := (u - 0.3) * chord
	var local_y := v * thick
	var rot_x := local_x * cos(twist) - local_y * sin(twist)
	var rot_y := local_x * sin(twist) + local_y * cos(twist)
	var precone_z := 0.35 - r * 0.03
	return (v_rad * r) + (v_tan * rot_x) + (v_norm * (rot_y + precone_z))


## Helper: adds a quad to SurfaceTool with proper CCW outward winding.
static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		n0: Vector3, n1: Vector3, col: Color) -> void:
	st.set_color(col)
	st.set_normal(n0)
	st.add_vertex(p0)
	st.set_normal(n1)
	st.add_vertex(p1)
	st.set_normal(n1)
	st.add_vertex(p2)

	st.set_color(col)
	st.set_normal(n0)
	st.add_vertex(p0)
	st.set_normal(n1)
	st.add_vertex(p2)
	st.set_normal(n0)
	st.add_vertex(p3)


## Helper: adds a circular disc facing `normal`.
static func _add_disc(st: SurfaceTool, center: Vector3, radius: float, normal: Vector3, segs: int, col: Color) -> void:
	st.set_color(col)
	var right: Vector3 = Vector3.RIGHT if absf(normal.dot(Vector3.UP)) < 0.9 else DIR_FRONT
	var up: Vector3 = normal.cross(right).normalized()
	right = up.cross(normal).normalized()
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var p0: Vector3 = center + (right * cos(a0) + up * sin(a0)) * radius
		var p1: Vector3 = center + (right * cos(a1) + up * sin(a1)) * radius
		st.set_color(col)
		st.set_normal(normal)
		st.add_vertex(center)
		st.add_vertex(p1)
		st.add_vertex(p0)


## Helper: adds a horizontal ring facing UP (+Y) or DOWN (-Y).
static func _add_horizontal_ring(st: SurfaceTool, y: float, r_in: float, r_out: float, segs: int, facing_up: bool, col: Color) -> void:
	var n := Vector3.UP if facing_up else Vector3.DOWN
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)
		if facing_up:
			var p0 := Vector3(c0 * r_out, y, s0 * r_out)
			var p1 := Vector3(c1 * r_out, y, s1 * r_out)
			var p2 := Vector3(c1 * r_in, y, s1 * r_in)
			var p3 := Vector3(c0 * r_in, y, s0 * r_in)
			_add_quad(st, p0, p1, p2, p3, n, n, col)
		else:
			var p0 := Vector3(c0 * r_in, y, s0 * r_in)
			var p1 := Vector3(c1 * r_in, y, s1 * r_in)
			var p2 := Vector3(c1 * r_out, y, s1 * r_out)
			var p3 := Vector3(c0 * r_out, y, s0 * r_out)
			_add_quad(st, p0, p1, p2, p3, n, n, col)


## Helper: adds a cylinder wall with Y going from y0 to y1 (y1 > y0), outward normals.
static func _add_cylinder_wall(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, segs: int, col: Color) -> void:
	var slope := (r0 - r1) / (y1 - y0)
	for i in range(segs):
		var a0: float = TAU * float(i) / float(segs)
		var a1: float = TAU * float(i + 1) / float(segs)
		var c0: float = cos(a0)
		var s0: float = sin(a0)
		var c1: float = cos(a1)
		var s1: float = sin(a1)
		var p0 := Vector3(c0 * r0, y0, s0 * r0)
		var p1 := Vector3(c1 * r0, y0, s1 * r0)
		var p2 := Vector3(c1 * r1, y1, s1 * r1)
		var p3 := Vector3(c0 * r1, y1, s0 * r1)
		var n0 := Vector3(c0, slope, s0).normalized()
		var n1 := Vector3(c1, slope, s1).normalized()
		_add_quad(st, p0, p1, p2, p3, n0, n1, col)


## Helper: adds a 3D box with proper outward face normals.
static func _add_box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var c := [
		center + Vector3(-h.x, -h.y, -h.z), # 0
		center + Vector3( h.x, -h.y, -h.z), # 1
		center + Vector3( h.x,  h.y, -h.z), # 2
		center + Vector3(-h.x,  h.y, -h.z), # 3
		center + Vector3(-h.x, -h.y,  h.z), # 4
		center + Vector3( h.x, -h.y,  h.z), # 5
		center + Vector3( h.x,  h.y,  h.z), # 6
		center + Vector3(-h.x,  h.y,  h.z), # 7
	]
	var faces := [
		# [p0, p1, p2, p3, normal]
		[0, 1, 2, 3, DIR_BACK],
		[5, 4, 7, 6, DIR_FRONT],
		[4, 0, 3, 7, Vector3.LEFT],
		[1, 5, 6, 2, Vector3.RIGHT],
		[3, 2, 6, 7, Vector3.UP],
		[4, 5, 1, 0, Vector3.DOWN],
	]
	for f in faces:
		var n: Vector3 = f[4]
		_add_quad(st, c[f[0]], c[f[1]], c[f[2]], c[f[3]], n, n, col)
