@tool
class_name SnowDrift
extends Area3D

## SnowDrift
## Soft, non-blocking snow drift volume that allows vehicles to sink smoothly
## into the snow without hard collision bumps, while applying powdery snow drag and tire spray.
## Can be scaled in the editor using either the 3D Scale Gizmo, Transform -> Scale, or Dimensions properties.
## Fully supports Godot's Undo/Redo system and eliminates the non-uniform collision warning.

@export_group("Dimensions")
## Total base size of the snow drift volume (Width = X, Height = Y, Length = Z) in meters.
@export var size: Vector3 = Vector3(15.0, 1.2, 18.0):
	set(val):
		var clamped = Vector3(maxf(val.x, 1.0), maxf(val.y, 0.1), maxf(val.z, 1.0))
		size = clamped
		if _col_shape != null:
			_update_drift()

## Width across the road (X axis in meters).
@export var width: float:
	get: return size.x * absf(scale.x)
	set(v):
		if absf(scale.x) > 0.001:
			size = Vector3(v / absf(scale.x), size.y, size.z)
		else:
			size = Vector3(v, size.y, size.z)

## Peak height of the snow drift mound (Y axis in meters).
@export var height: float:
	get: return size.y * absf(scale.y)
	set(v):
		if absf(scale.y) > 0.001:
			size = Vector3(size.x, v / absf(scale.y), size.z)
		else:
			size = Vector3(size.x, v, size.z)

## Length along the road (Z axis in meters).
@export var length: float:
	get: return size.z * absf(scale.z)
	set(v):
		if absf(scale.z) > 0.001:
			size = Vector3(size.x, size.y, v / absf(scale.z))
		else:
			size = Vector3(size.x, size.y, v)

@export_group("Drift Shape")
## Maximum height multiplier for the drift mound.
@export_range(0.2, 3.0, 0.05) var mound_height_ratio: float = 1.0:
	set(val):
		mound_height_ratio = val
		if _col_shape != null:
			_update_drift()

## Seed offset for organic variation between multiple drifts.
@export var seed_offset: float = 0.0:
	set(val):
		seed_offset = val
		if _col_shape != null:
			_update_drift()

## Asymmetry factor: shifts peak mound towards one side (+X or -X) like a wind-blown bank.
@export_range(-1.0, 1.0, 0.05) var bank_asymmetry: float = 0.25:
	set(val):
		bank_asymmetry = val
		if _col_shape != null:
			_update_drift()

@export_group("Material")
@export var snow_color: Color = Color(0.97, 0.985, 1.0):
	set(val):
		snow_color = val
		if _shared_mat != null:
			_update_material()

@export_range(0.0, 1.0, 0.05) var roughness: float = 0.85:
	set(val):
		roughness = val
		if _shared_mat != null:
			_update_material()

@export_group("Editor Tools")
## Drop this snow drift onto the road or terrain directly below it.
@export_tool_button("Snap To Ground") var snap_to_ground_btn: Callable = snap_to_ground

var _col_shape: CollisionShape3D
var _mesh_inst: MeshInstance3D
var _shared_mat: StandardMaterial3D
var _is_updating: bool = false
var _last_synced_scale: Vector3 = Vector3.ZERO


func _enter_tree() -> void:
	add_to_group("snow", true)
	set_meta("is_snow", true)
	set_notify_transform(true)


func _ready() -> void:
	set_notify_transform(true)
	_ensure_nodes()
	_update_drift()
	_sync_collision_shape()

	if not Engine.is_editor_hint():
		if not body_entered.is_connected(_on_body_entered):
			body_entered.connect(_on_body_entered)
		if not body_exited.is_connected(_on_body_exited):
			body_exited.connect(_on_body_exited)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_sync_collision_shape()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if not scale.is_equal_approx(_last_synced_scale):
			_sync_collision_shape()


func _ensure_nodes() -> void:
	# Find or create CollisionShape3D
	_col_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not _col_shape:
		for child in get_children():
			if child is CollisionShape3D:
				_col_shape = child
				break
	if not _col_shape:
		_col_shape = CollisionShape3D.new()
		_col_shape.name = "CollisionShape3D"
		add_child(_col_shape)
		if Engine.is_editor_hint():
			_col_shape.owner = owner if owner else self

	if not (_col_shape.shape is BoxShape3D):
		_col_shape.shape = BoxShape3D.new()

	# Find or create MeshInstance3D
	_mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if not _mesh_inst:
		for child in get_children():
			if child is MeshInstance3D:
				_mesh_inst = child
				break
	if not _mesh_inst:
		_mesh_inst = MeshInstance3D.new()
		_mesh_inst.name = "MeshInstance3D"
		add_child(_mesh_inst)
		if Engine.is_editor_hint():
			_mesh_inst.owner = owner if owner else self


func _sync_collision_shape() -> void:
	if not _col_shape or not (_col_shape.shape is BoxShape3D):
		return

	var cur_scale := scale
	_last_synced_scale = cur_scale

	var sx = maxf(absf(cur_scale.x), 0.001)
	var sy = maxf(absf(cur_scale.y), 0.001)
	var sz = maxf(absf(cur_scale.z), 0.001)

	# Counter-scale the CollisionShape3D child so its global scale is ALWAYS (1, 1, 1).
	# This completely eliminates Godot's "Non-uniformly scaled CollisionShape3D" warning
	# while preserving standard transform scaling, gizmo manipulation, and full Undo/Redo!
	_col_shape.scale = Vector3(1.0 / sx, 1.0 / sy, 1.0 / sz)

	var box := _col_shape.shape as BoxShape3D
	var trigger_height: float = (size.y * sy) + 2.0
	box.size = Vector3(size.x * sx, trigger_height, size.z * sz)

	# Keep trigger centered vertically relative to the scaled drift volume
	_col_shape.position = Vector3(0.0, (trigger_height * 0.5 - 0.2) / sy, 0.0)


func _update_drift() -> void:
	if _is_updating:
		return
	_is_updating = true

	_ensure_nodes()
	_update_mesh()
	_update_material()
	_sync_collision_shape()

	_is_updating = false


func _update_material() -> void:
	if not _mesh_inst:
		return

	if not _shared_mat:
		_shared_mat = StandardMaterial3D.new()
		var sand_norm: Texture2D = load("res://materials/sand_normal.png") as Texture2D
		if sand_norm:
			_shared_mat.normal_enabled = true
			_shared_mat.normal_texture = sand_norm
			_shared_mat.normal_scale = 0.35
			_shared_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
			_shared_mat.uv1_triplanar = true

	_shared_mat.albedo_color = snow_color
	_shared_mat.roughness = roughness
	_shared_mat.metallic = 0.01

	_shared_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	# CULL_DISABLED guarantees all sides and top surfaces are 100% visible from any camera angle
	_shared_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shared_mat.rim_enabled = false

	_mesh_inst.material_override = _shared_mat


func _update_mesh() -> void:
	if not _mesh_inst:
		return

	var w: float = size.x
	var h: float = size.y * mound_height_ratio
	var l: float = size.z

	# Deep skirt sunken below road and terrain ensures zero gaps on slopes
	const SKIRT_DEPTH: float = -0.30

	const GRID_X := 24
	const GRID_Z := 28

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Generate Top Surface Grid Vertices
	var top_verts: Array = []
	for iz in range(GRID_Z + 1):
		var v_line: Array = []
		var v_frac: float = float(iz) / float(GRID_Z)
		var v: float = v_frac * 2.0 - 1.0 # -1.0 to 1.0
		for ix in range(GRID_X + 1):
			var u_frac: float = float(ix) / float(GRID_X)
			var u: float = u_frac * 2.0 - 1.0 # -1.0 to 1.0

			# Subtle organic boundary curvature
			var px: float = u * (w * 0.5) * (1.0 + 0.05 * sin(v * PI * 2.0 + seed_offset))
			var pz: float = v * (l * 0.5) * (1.0 + 0.04 * cos(u * PI * 2.0 + seed_offset * 1.5))

			# Natural snow mound envelope
			var dist_u: float = clampf(1.0 - absf(u), 0.0, 1.0)
			var dist_v: float = clampf(1.0 - absf(v), 0.0, 1.0)
			var fade_u: float = smoothstep(0.0, 0.20, dist_u)
			var fade_v: float = smoothstep(0.0, 0.16, dist_v)
			var env: float = pow(fade_u * fade_v, 0.75)

			# Wind bank asymmetry and natural powder ripples
			var bank: float = 0.90 + bank_asymmetry * sin(u * 1.5 + seed_offset)
			var ripple: float = 0.06 * sin(v * 8.0 + u * 3.0 + seed_offset) + 0.03 * cos(v * 16.0 - u * 5.0)
			var py: float = maxf(0.04, h * env * (bank + ripple))

			v_line.append(Vector3(px, py, pz))
		top_verts.append(v_line)

	var num_verts_per_layer: int = (GRID_X + 1) * (GRID_Z + 1)

	# 2. Add Top Layer Vertices
	for iz in range(GRID_Z + 1):
		for ix in range(GRID_X + 1):
			var pt: Vector3 = top_verts[iz][ix]
			st.set_uv(Vector2(float(ix) / float(GRID_X) * (w * 0.25), float(iz) / float(GRID_Z) * (l * 0.25)))
			st.add_vertex(pt)

	# 3. Add Bottom Skirt Vertices
	for iz in range(GRID_Z + 1):
		for ix in range(GRID_X + 1):
			var pt: Vector3 = top_verts[iz][ix]
			st.set_uv(Vector2(float(ix) / float(GRID_X) * (w * 0.25), float(iz) / float(GRID_Z) * (l * 0.25)))
			st.add_vertex(Vector3(pt.x, SKIRT_DEPTH, pt.z))

	# 4. Indices: Top Surface (Facing UP)
	for iz in range(GRID_Z):
		for ix in range(GRID_X):
			var i0 = iz * (GRID_X + 1) + ix
			var i1 = i0 + 1
			var i2 = (iz + 1) * (GRID_X + 1) + ix
			var i3 = i2 + 1

			st.add_index(i0); st.add_index(i2); st.add_index(i1)
			st.add_index(i1); st.add_index(i2); st.add_index(i3)

	# 5. Indices: Bottom Base (Facing DOWN)
	var b_offset = num_verts_per_layer
	for iz in range(GRID_Z):
		for ix in range(GRID_X):
			var i0 = b_offset + iz * (GRID_X + 1) + ix
			var i1 = i0 + 1
			var i2 = b_offset + (iz + 1) * (GRID_X + 1) + ix
			var i3 = i2 + 1

			st.add_index(i0); st.add_index(i1); st.add_index(i2)
			st.add_index(i1); st.add_index(i3); st.add_index(i2)

	# 6. Indices: Perimeter Skirt Walls
	# South skirt (iz = 0)
	for ix in range(GRID_X):
		var t0 = ix; var t1 = ix + 1
		var b0 = b_offset + ix; var b1 = b_offset + ix + 1
		st.add_index(t0); st.add_index(t1); st.add_index(b0)
		st.add_index(t1); st.add_index(b1); st.add_index(b0)

	# North skirt (iz = GRID_Z)
	for ix in range(GRID_X):
		var t0 = GRID_Z * (GRID_X + 1) + ix
		var t1 = t0 + 1
		var b0 = b_offset + t0
		var b1 = b_offset + t1
		st.add_index(t0); st.add_index(b0); st.add_index(t1)
		st.add_index(t1); st.add_index(b0); st.add_index(b1)

	# West skirt (ix = 0)
	for iz in range(GRID_Z):
		var t0 = iz * (GRID_X + 1)
		var t1 = (iz + 1) * (GRID_X + 1)
		var b0 = b_offset + t0
		var b1 = b_offset + t1
		st.add_index(t0); st.add_index(b0); st.add_index(t1)
		st.add_index(t1); st.add_index(b0); st.add_index(b1)

	# East skirt (ix = GRID_X)
	for iz in range(GRID_Z):
		var t0 = iz * (GRID_X + 1) + GRID_X
		var t1 = (iz + 1) * (GRID_X + 1) + GRID_X
		var b0 = b_offset + t0
		var b1 = b_offset + t1
		st.add_index(t0); st.add_index(t1); st.add_index(b0)
		st.add_index(t1); st.add_index(b1); st.add_index(b0)

	st.generate_normals()
	st.generate_tangents()
	_mesh_inst.mesh = st.commit()


## Snaps this snow drift to the road or terrain surface directly underneath it.
func snap_to_ground() -> bool:
	if not is_inside_tree():
		return false

	var world := get_world_3d()
	if not world:
		return false

	if Engine.is_editor_hint() and world.space.is_valid():
		PhysicsServer3D.space_set_active(world.space, true)

	var space := world.direct_space_state
	if not space:
		return false

	var from := global_position + Vector3(0, 50.0, 0)
	var to := global_position - Vector3(0, 100.0, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		var n: Vector3 = hit.normal
		if n.y > 0.3:
			var fwd: Vector3 = -global_transform.basis.z
			fwd = (fwd - n * fwd.dot(n)).normalized()
			if fwd.length_squared() > 0.001:
				var r: Vector3 = fwd.cross(n).normalized()
				fwd = n.cross(r).normalized()
				global_transform.basis = Basis(r, n, -fwd).orthonormalized()
		return true

	return false


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("enter_snow_drift"):
		body.enter_snow_drift()
	elif "is_in_snow" in body:
		body.set("is_in_snow", true)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("exit_snow_drift"):
		body.exit_snow_drift()
	elif "is_in_snow" in body:
		body.set("is_in_snow", false)
