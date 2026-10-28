extends RefCounted
## Canyon Chasm's double-rail corrugated steel jump guardrail (Barrier / Barrier2), modelled in CSG
## at life size in the exact unscaled local frame of the level's Barrier nodes:
## - Spans Z [-5.67 .. +5.73] (11.40m long), X [-1.03 .. +0.59] (1.62m wide), Y [-SINK .. 3.92m]
## - Three heavy galvanized steel H-posts on beveled base plates with corner anchor bolts and
##   under-grade pedestals (`SINK = 0.55m`) so the bases sit flush on the banked jump ramp
## - Two profiled W-beam corrugated steel guardrail rails (`y = 1.48m` and `y = 2.98m`) on the
##   road-facing (`-X`) side with spacer blocks and post bolts.
##
## Replaced the Hunyuan FBX `models/concrete/3947899e2e8ccf226587409e9b0ce96a.fbx` (imported at
## scale 10): Barrier and Barrier2 in `CanyonChasmLevel.tscn` keep their position and rotation at scale 1.0.

const SINK := 0.55

const COL_STEEL := Color(0.56, 0.60, 0.66)
const COL_POST := Color(0.42, 0.46, 0.51)
const COL_BASE := Color(0.30, 0.33, 0.37)
const COL_BOLT := Color(0.20, 0.22, 0.25)

static var _placeholder_mats := {}
static var _final_mats := {}


static func build() -> CSGCombiner3D:
	var root := CSGCombiner3D.new()
	root.name = "ChasmBarrierCSG"

	var m_steel := _mat("galv", COL_STEEL)
	var m_post := _mat("galv", COL_POST)
	var m_base := _mat("iron", COL_BASE)
	var m_bolt := _mat("iron", COL_BOLT)

	# In Barrier/Barrier2's local frame, +X faces the road and -X faces the cliff drop-off.
	# Place the H-posts on the cliff side (-X) and the corrugated W-beam rails on the road side (+X).
	# 1. Three Steel H-Posts & Beveled Base Plates along Z (-4.55, +0.03, +4.61)
	for pz in [-4.55, 0.03, 4.61]:
		var zf: float = float(pz)
		# Under-grade anchor plinth + stepped beveled base plate
		_add(root, _box(Vector3(-0.07, (0.20 - SINK) * 0.5, zf), Vector3(1.46, 0.20 + SINK, 1.36), m_base), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(-0.07, 0.26, zf), Vector3(1.22, 0.14, 1.14), m_post), CSGShape3D.OPERATION_UNION)
		# Four corner anchor bolts
		for bx in [-0.50, 0.36]:
			for bz in [-0.42, 0.42]:
				_add(root, _box(Vector3(float(bx), 0.36, zf + float(bz)), Vector3(0.14, 0.10, 0.14), m_bolt), CSGShape3D.OPERATION_UNION)
		# H-post flanges & web rising to Y = 3.92 on the outer (-X) side
		_add(root, _box(Vector3(-0.40, 2.10, zf), Vector3(0.10, 3.64, 0.44), m_post), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(0.14, 2.10, zf), Vector3(0.10, 3.64, 0.44), m_post), CSGShape3D.OPERATION_UNION)
		_add(root, _box(Vector3(-0.13, 2.10, zf), Vector3(0.46, 3.64, 0.12), m_base), CSGShape3D.OPERATION_UNION)
		# Slanted top post cap
		_add(root, _box(Vector3(-0.13, 3.90, zf), Vector3(0.68, 0.08, 0.50), m_post), CSGShape3D.OPERATION_UNION)
		# Spacer blocks between post (+X flange) and upper/lower W-beam rails (+X road side)
		for ry in [1.48, 2.98]:
			_add(root, _box(Vector3(0.30, float(ry), zf), Vector3(0.26, 0.68, 0.36), m_base), CSGShape3D.OPERATION_UNION)

	# 2. Two Corrugated W-Beam Guardrail Bands on the road-facing (+X) side (Y = 1.48 and Y = 2.98, Z [-5.67 .. +5.73])
	for ry in [1.48, 2.98]:
		var ryf: float = float(ry)
		var rail_prof := _w_beam_profile(ryf)
		_add(root, _extrude_z(rail_prof, -5.67, 5.73, m_steel), CSGShape3D.OPERATION_UNION)
		# Splice bolt heads on the road-facing (+X) face at the 3 posts
		for pz in [-4.55, 0.03, 4.61]:
			for by in [-0.28, 0.0, 0.28]:
				_add(root, _box(Vector3(0.72, ryf + float(by), float(pz)), Vector3(0.08, 0.09, 0.09), m_bolt), CSGShape3D.OPERATION_UNION)

	return root


static func _w_beam_profile(cy: float) -> PackedVector2Array:
	# Cross-section in (X, Y) of a corrugated W-beam guardrail facing +X (road side, X in [0.34 .. 0.74], height 1.12m)
	return PackedVector2Array([
		Vector2(0.42, cy - 0.56),
		Vector2(0.58, cy - 0.50),
		Vector2(0.74, cy - 0.30),
		Vector2(0.72, cy - 0.16),
		Vector2(0.48, cy - 0.04),
		Vector2(0.48, cy + 0.04),
		Vector2(0.72, cy + 0.16),
		Vector2(0.74, cy + 0.30),
		Vector2(0.58, cy + 0.50),
		Vector2(0.42, cy + 0.56),
		Vector2(0.34, cy + 0.48),
		Vector2(0.50, cy + 0.42),
		Vector2(0.62, cy + 0.24),
		Vector2(0.38, cy + 0.06),
		Vector2(0.38, cy - 0.06),
		Vector2(0.62, cy - 0.24),
		Vector2(0.50, cy - 0.42),
		Vector2(0.34, cy - 0.48),
	])


static func _extrude_z(poly: PackedVector2Array, z0: float, z1: float, mat: Material) -> CSGPolygon3D:
	var p := CSGPolygon3D.new()
	p.polygon = poly
	p.depth = z1 - z0
	p.position = Vector3(0.0, 0.0, z1)
	p.material = mat
	return p


static func _box(at: Vector3, size: Vector3, mat: Material, b := Basis()) -> CSGBox3D:
	var box := CSGBox3D.new()
	box.size = size
	box.transform = Transform3D(b, at)
	box.material = mat
	return box


static func _add(parent: CSGShape3D, child: CSGShape3D, op: int) -> void:
	child.operation = op if parent.get_child_count() > 0 else CSGShape3D.OPERATION_UNION
	parent.add_child(child)


static func _mat(key: String, col: Color) -> StandardMaterial3D:
	var tag := "%s:%s" % [key, col.to_html(false)]
	if not _placeholder_mats.has(tag):
		var m := StandardMaterial3D.new()
		m.resource_name = tag
		m.albedo_color = col
		_placeholder_mats[tag] = m
	return _placeholder_mats[tag]


static func _final_material(key: String) -> Material:
	if _final_mats.has(key):
		return _final_mats[key]
	var sm := StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	sm.vertex_color_is_srgb = true
	sm.normal_enabled = true
	sm.normal_texture = load("res://materials/dark_canyon_rock_normal.png")
	sm.uv1_scale = Vector3(0.45, 0.45, 0.45)
	if key == "galv":
		sm.metallic = 0.90
		sm.metallic_specular = 0.78
		sm.roughness = 0.22
		sm.normal_scale = 0.14
	else:
		sm.metallic = 0.82
		sm.metallic_specular = 0.65
		sm.roughness = 0.34
		sm.normal_scale = 0.20
	_final_mats[key] = sm
	return sm


static func bake(root: CSGShape3D) -> ArrayMesh:
	var src: ArrayMesh = root.bake_static_mesh()
	var out := ArrayMesh.new()
	if src == null:
		push_error("ChasmBarrierCSG: CSG has not built its mesh yet")
		return out
	var tools := {}
	var order: Array[String] = []
	for si in range(src.get_surface_count()):
		var mat := src.surface_get_material(si)
		var tag := mat.resource_name.split(":") if mat and mat.resource_name.contains(":") else PackedStringArray(["galv", "8a94a1"])
		var key: String = tag[0]
		var col := Color(tag[1])
		if not tools.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = st
			order.append(key)
		var st: SurfaceTool = tools[key]
		var arr := src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := idx.size() if not idx.is_empty() else v.size()
		for t in range(0, count - 2, 3):
			var ids := [t, t + 1, t + 2] if idx.is_empty() else [idx[t], idx[t + 1], idx[t + 2]]
			for i in ids:
				var p: Vector3 = v[i]
				st.set_color(col)
				st.set_normal(n[i])
				st.set_uv(Vector2(p.z, p.y))
				st.add_vertex(p)
	for key in order:
		var st: SurfaceTool = tools[key]
		st.generate_tangents()
		st.index()
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, _final_material(key))
	return out
