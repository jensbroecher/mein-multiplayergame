extends RefCounted
## Canyon Chasm's tornado, modelled in CSG at life size (metres, y up, ground at y = 0):
## A 35m tall vortex funnel with an outer flared trumpet mantle, a billowing rounded anvil dome,
## and a dense inner dust core. It replaces the 50k-triangle Hunyuan FBX
## (models/desert2/d4250e86adc7a52ecf39a804e207694e.fbx, imported at scale 40) with a clean,
## ~6k-triangle baked mesh in generated/tornado.res, which Tornado.tscn draws at scale 1:
## the level holds no CSG runtime nodes and no heavy FBX asset.
##
## regenerate_tornado.gd builds the tree (`build`), lets the CSG update for a frame, and bakes it
## to one mesh (`bake`) in generated/tornado.res. Run it after changing TornadoCSG.gd:
##   Godot --headless --path . res://regenerate_tornado.tscn

const HEIGHT := 35.5
const R_BASE := 1.15
const R_ANVIL_MAX := 19.2


static func build() -> CSGCombiner3D:
	var root := CSGCombiner3D.new()
	root.name = "TornadoCSG"

	# 1. Main Volumetric Vortex Funnel with Billowing Cloud Anvil Crown
	var main_poly := CSGPolygon3D.new()
	main_poly.name = "MainVortex"
	main_poly.mode = CSGPolygon3D.MODE_SPIN
	main_poly.spin_degrees = 360.0
	main_poly.spin_sides = 54
	main_poly.smooth_faces = true

	var pts := PackedVector2Array()

	# A. Apex dome of storm cloud (r = 0, y = 35.5m)
	pts.append(Vector2(0.0, 35.5))

	# B. Rounded convex cloud cap curving outward to upper shelf
	var cap_steps := 12
	for i in range(1, cap_steps + 1):
		var t := float(i) / float(cap_steps)
		var r := t * 16.5
		# Smooth spherical crown bulge
		var y := 35.5 - (1.0 - cos(t * 0.5 * PI)) * 2.2
		pts.append(Vector2(r, y))

	# C. Billowing rounded upper anvil rim (curls outward and rounds under)
	var rim_steps := 8
	for i in range(rim_steps):
		var ang := float(i) / float(rim_steps - 1) * PI
		var r := 16.5 + sin(ang) * 2.7
		var y := 33.3 - (1.0 - cos(ang)) * 1.5
		pts.append(Vector2(r, y))

	# D. Secondary mid-anvil cloud shelf (creates stepped storm tier at y = 28m .. 31m)
	var shelf_steps := 6
	for i in range(shelf_steps):
		var ang := float(i) / float(shelf_steps - 1) * PI
		var r := 14.5 + sin(ang) * 1.8
		var y := 30.5 - (1.0 - cos(ang)) * 1.2
		pts.append(Vector2(r, y))

	# E. Trumpet Trunk descending from shelf down to ground touchdown
	var trunk_steps := 36
	var y_top := 28.5
	for i in range(trunk_steps + 1):
		var t := float(i) / float(trunk_steps) # 0 at y_top, 1 at ground
		var y := lerpf(y_top, 0.0, t)
		var norm_h := 1.0 - t # 1 at y_top, 0 at ground
		# Slender stem at ground (1.15m), sweeping outward mid-body, flaring into shelf
		var r_stem := lerpf(R_BASE, 3.6, pow(norm_h, 0.85))
		var r_flare := (14.5 - 3.6) * pow(norm_h, 2.5)
		var ripple := sin(norm_h * TAU * 3.5) * 0.30 * (0.2 + 0.8 * norm_h)
		var r := r_stem + r_flare + ripple
		pts.append(Vector2(r, y))

	# F. Close base to center axis
	pts.append(Vector2(0.0, 0.0))

	main_poly.polygon = pts
	root.add_child(main_poly)

	# 2. Dense Inner Vortex Core (creates internal density seen through semi-transparency)
	var core_poly := CSGPolygon3D.new()
	core_poly.name = "InnerCore"
	core_poly.mode = CSGPolygon3D.MODE_SPIN
	core_poly.spin_degrees = 360.0
	core_poly.spin_sides = 32
	core_poly.smooth_faces = true

	var core_pts := PackedVector2Array()
	core_pts.append(Vector2(0.0, 26.5))
	var c_steps := 20
	for i in range(c_steps + 1):
		var t := float(i) / float(c_steps)
		var norm_h := 1.0 - t
		var y := norm_h * 26.5
		var r := 0.45 + (5.8 - 0.45) * pow(norm_h, 1.6)
		core_pts.append(Vector2(r, y))
	core_pts.append(Vector2(0.0, 0.0))

	core_poly.polygon = core_pts
	root.add_child(core_poly)

	return root


## Bakes the built CSG tree into one ArrayMesh resource.
static func bake(root: CSGShape3D) -> ArrayMesh:
	var mesh: ArrayMesh = root.bake_static_mesh()
	if mesh == null:
		push_error("TornadoCSG: the CSG has not built its mesh yet")
	return mesh
