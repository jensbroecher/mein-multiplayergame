extends RefCounted
## Canyon Chasm's tornado, modelled in CSG at life size (metres, y up, ground at y = 0):
## Three concentric volumetric shells (a dense opaque-hearted InnerCore, a swirling MidVortex
## funnel wall, and a billowing OuterMantle with storm anvil crown) baked in back-to-front
## order into a single ArrayMesh surface in generated/tornado.res, with COLOR.r encoding the
## shell layer (0.0 = core, 0.5 = mid vortex, 1.0 = outer mantle).
##
## regenerate_tornado.gd builds the tree (`build`), lets the CSG update for a frame, and bakes it
## to one mesh (`bake`) in generated/tornado.res. Run it after changing TornadoCSG.gd:
##   Godot --headless --path . res://regenerate_tornado.tscn

const HEIGHT := 35.5
const R_BASE := 1.85
const R_ANVIL_MAX := 18.8


static func _envelope_radius(norm_h: float, shell_t: float) -> float:
	# Wide basal dust skirt flare where the vortex meets the canyon floor
	var foot_flare := exp(-norm_h * 14.0) * 2.15
	# Muscular trunk widening steadily into the upper funnel
	var r_stem := lerpf(R_BASE, 5.8, pow(norm_h, 0.80))
	var r_flare := 10.5 * pow(norm_h, 2.25)
	# Smooth billowing storm-cloud shelves without re-entrant horizontal overhangs
	var collar_bulge := exp(-pow((norm_h - 0.77) / 0.068, 2.0)) * 1.65
	var anvil_bulge := exp(-pow((norm_h - 0.895) / 0.062, 2.0)) * 3.10
	# Gentle organic vertical undulation along the trunk (phase-shifted per shell)
	var wave := sin(norm_h * TAU * 3.2 + shell_t * 2.1) * 0.24 * (0.25 + 0.75 * norm_h) * (1.0 - smoothstep(0.82, 0.96, norm_h))
	var raw_r := r_stem + r_flare + foot_flare + collar_bulge + anvil_bulge + wave

	# Smoothly round the upper dome to 0 at the apex
	var dome_start := 0.885
	if norm_h > dome_start:
		var u := clampf((norm_h - dome_start) / (1.0 - dome_start), 0.0, 1.0)
		var dome_cap := sqrt(maxf(0.0, 1.0 - u * u))
		raw_r *= dome_cap

	# Converge shell radii near the upper dome so the crown never shows stepped concentric rims
	var top_converge := smoothstep(0.75, 0.96, norm_h)
	var shell_scale := lerpf(lerpf(0.76, 0.94, top_converge), 1.0, shell_t)
	return raw_r * shell_scale


static func _build_shell_poly(poly_name: String, shell_t: float, max_y: float, sides: int, steps: int) -> CSGPolygon3D:
	var poly := CSGPolygon3D.new()
	poly.name = poly_name
	poly.mode = CSGPolygon3D.MODE_SPIN
	poly.spin_degrees = 360.0
	poly.spin_sides = sides
	poly.smooth_faces = true
	poly.set_meta("shell_t", shell_t)

	var pts := PackedVector2Array()
	# Top apex on center axis
	pts.append(Vector2(0.0, max_y))

	# Monotonically descending profile from apex down to ground touchdown
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var norm_h := 1.0 - t
		var y := norm_h * max_y
		# Keep non-zero radius at ground touchdown
		var r := maxf(0.25, _envelope_radius(maxf(norm_h, 0.002), shell_t))
		pts.append(Vector2(r, y))

	# Close base on center axis
	pts.append(Vector2(0.0, 0.0))
	poly.polygon = pts
	return poly


static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "TornadoCSG"

	# Built in strict inner-to-outer order so back-face culled shells draw back-to-front:
	# 1. Dense Inner Core (shell_t = 0.0): blocks sky/background bleed-through
	root.add_child(_build_shell_poly("InnerCore", 0.0, HEIGHT - 0.12, 36, 40))
	# 2. Swirling Middle Vortex Wall (shell_t = 0.5): intermediate helical bands
	root.add_child(_build_shell_poly("MidVortex", 0.5, HEIGHT - 0.05, 44, 48))
	# 3. Billowing Outer Dust Mantle & Anvil (shell_t = 1.0): sculpted outer dust sheath
	root.add_child(_build_shell_poly("OuterMantle", 1.0, HEIGHT, 54, 56))

	return root


## Bakes each CSG shell in inner-to-outer order into one single-surface ArrayMesh,
## tagging COLOR.r with the shell layer (0.0 = InnerCore, 0.5 = MidVortex, 1.0 = OuterMantle).
static func bake(root: Node3D) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var baked_any := false
	for child in root.get_children():
		if not (child is CSGShape3D):
			continue
		var csg := child as CSGShape3D
		var shell_t: float = float(csg.get_meta("shell_t", 1.0))
		var sub_mesh: ArrayMesh = csg.bake_static_mesh()
		if sub_mesh == null or sub_mesh.get_surface_count() == 0:
			push_error("TornadoCSG: shell %s has not built its mesh yet" % csg.name)
			return null

		baked_any = true
		var shell_col := Color(shell_t, 1.0, 0.0, 1.0)
		for s in range(sub_mesh.get_surface_count()):
			var arrays := sub_mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()

			if indices.size() > 0:
				for idx in indices:
					if norms.size() > idx:
						st.set_normal(norms[idx])
					if uvs.size() > idx:
						st.set_uv(uvs[idx])
					st.set_color(shell_col)
					st.add_vertex(verts[idx])
			else:
				for i in range(verts.size()):
					if norms.size() > i:
						st.set_normal(norms[i])
					if uvs.size() > i:
						st.set_uv(uvs[i])
					st.set_color(shell_col)
					st.add_vertex(verts[i])

	if not baked_any:
		push_error("TornadoCSG: no CSG shells found to bake")
		return null

	st.index()
	return st.commit()
