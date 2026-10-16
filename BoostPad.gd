@tool
class_name BoostPad
extends Area3D
## A boost pad. Its look is built here, not imported: a flat bevelled slab, one mesh shared by every
## pad, drawn by boost_pad.gdshader with chevrons streaming toward the pad's front (-z). It is an
## internal child, rebuilt on load, so level files only store the pad's transform.
## With `settle_on_track`, the pad drops onto whatever is under it once the level's collision is
## built, tilts with the slope and turns to face along the TrackPath.

const PAD_WIDTH := 4.0
const PAD_LENGTH := 6.0
const PAD_HEIGHT := 0.08
const PAD_BEVEL := 0.14
const SHADER := preload("res://boost_pad.gdshader")

static var _mesh: ArrayMesh
static var _material: ShaderMaterial

@export var flash_brightness: float = 3.0
## Multiplier for pad boost force / top speed (1.0 = default). Set per pad in the inspector.
@export_range(0.1, 5.0, 0.05) var boost_strength: float = 1.0
## How long the boost lasts in seconds.
@export_range(0.2, 8.0, 0.1) var boost_duration: float = 2.0

@export_group("Editor Tools")
## Drop this pad onto the road under it (editor). Prefer the button; checkbox is a backup.
@export_tool_button("Snap To Ground") var snap_to_ground_btn: Callable = _on_snap_button_pressed
@export var snap_to_ground: bool = false:
	get:
		return false
	set(val):
		if val:
			_on_snap_button_pressed()
		notify_property_list_changed()
## Extra lift along surface normal after snap (meters).
@export_range(0.0, 1.0, 0.01) var ground_snap_lift: float = 0.08
## Align pad to the slope (keeps forward direction projected on the surface).
@export var align_to_slope: bool = true
## At runtime, once the level's collision exists: lie on the surface under the pad, tilted with it,
## facing the way the lap runs there.
@export var settle_on_track: bool = false

var _visual: MeshInstance3D
var _flash := 0.0
var flash_tween: Tween


func _enter_tree() -> void:
	add_to_group("boost_pads")


func _ready() -> void:
	_build_visual()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	if settle_on_track:
		_settle()


func _build_visual() -> void:
	if _visual:
		return
	if _mesh == null:
		_mesh = _pad_mesh()
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	_visual = MeshInstance3D.new()
	_visual.name = "PadVisual"
	_visual.mesh = _mesh
	_visual.material_override = _material
	_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_visual, false, Node.INTERNAL_MODE_BACK)


## The slab: a top face with UVs for the shader, bevelled down to the ground on all four sides. Vertex
## colour red marks the top; green runs down the bevel, for the shader's groove.
static func _pad_mesh() -> ArrayMesh:
	var hw := PAD_WIDTH * 0.5
	var hl := PAD_LENGTH * 0.5
	var b := PAD_BEVEL
	var h := PAD_HEIGHT
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Top, split into a grid so it can follow a gently curved surface if ever bent.
	var nx := 4
	var nz := 6
	var corner := func(i: int, j: int) -> Array:
		var u := float(i) / nx
		var v := float(j) / nz
		return [Vector3(lerpf(-hw + b, hw - b, u), h, lerpf(hl - b, -hl + b, v)), Vector2(u, v)]
	for j in nz:
		for i in nx:
			var q := [corner.call(i, j), corner.call(i + 1, j), corner.call(i + 1, j + 1), corner.call(i, j + 1)]
			for k in [0, 2, 1, 0, 3, 2]:
				st.set_color(Color(1, 0.5, 0))
				st.set_normal(Vector3.UP)
				st.set_uv(q[k][1])
				st.add_vertex(q[k][0])
	# Bevels: top edge to ground edge, in two bands so the groove has a vertex row.
	var top_ring := [Vector3(-hw + b, h, hl - b), Vector3(hw - b, h, hl - b), Vector3(hw - b, h, -hl + b), Vector3(-hw + b, h, -hl + b)]
	var low_ring := [Vector3(-hw, 0, hl), Vector3(hw, 0, hl), Vector3(hw, 0, -hl), Vector3(-hw, 0, -hl)]
	for e in 4:
		var a0: Vector3 = top_ring[e]
		var a1: Vector3 = top_ring[(e + 1) % 4]
		var b0: Vector3 = low_ring[e]
		var b1: Vector3 = low_ring[(e + 1) % 4]
		var n := (b1 - b0).cross(a0 - b0).normalized()
		if n.y < 0.0:
			n = -n
		for band in 2:
			var t0 := band * 0.5
			var t1 := t0 + 0.5
			var q := [a0.lerp(b0, t0), a1.lerp(b1, t0), a1.lerp(b1, t1), a0.lerp(b0, t1)]
			var g := [t0, t0, t1, t1]
			var order := [0, 1, 2, 0, 2, 3]
			# Front faces wind clockwise seen from outside: (c - a) x (b - a) along n.
			if (q[2] - q[0]).cross(q[1] - q[0]).dot(n) < 0.0:
				order = [0, 2, 1, 0, 3, 2]
			for k in order:
				st.set_color(Color(0, g[k], 0))
				st.set_normal(n)
				st.set_uv(Vector2(0, 0))
				st.add_vertex(q[k])
	return st.commit()


## Lie on the surface under the pad once the level's collision exists, tilted with it and facing along
## the lap. Checkpoint gates settle the same way (CheckpointGate._settle_on_ground).
func _settle() -> void:
	await get_tree().physics_frame
	var level: Node = get_parent()
	while level and not level.is_in_group("level"):
		level = level.get_parent()
	if level and level.has_method("wait_for_collisions"):
		await level.wait_for_collisions()
	if not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var up := Vector3.UP
	var centre := global_position
	# Four corners and the middle: the lowest of them sets the height, so no edge floats.
	var hits: Array[Vector3] = []
	var normal_sum := Vector3.ZERO
	for o in [Vector3.ZERO, Vector3(1.6, 0, 2.6), Vector3(-1.6, 0, 2.6), Vector3(1.6, 0, -2.6), Vector3(-1.6, 0, -2.6)]:
		var p: Vector3 = centre + global_transform.basis.orthonormalized() * o + Vector3(0.031, 0.0, 0.017)
		var q := PhysicsRayQueryParameters3D.create(p + up * 4.0, p - up * 6.0, 1)
		q.hit_back_faces = false
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			hits.append(hit.position)
			normal_sum += hit.normal
	if hits.is_empty():
		return
	var y := INF
	var mid_y := 0.0
	for hp in hits:
		y = minf(y, hp.y)
		mid_y += hp.y
	mid_y /= hits.size()
	var normal := normal_sum.normalized() if normal_sum.length() > 0.01 else Vector3.UP
	if normal.y < 0.5:
		normal = Vector3.UP
	var fwd := -global_transform.basis.z
	var path := _find_track_path()
	if path and path.curve:
		var off := path.curve.get_closest_offset(path.to_local(centre))
		var a := path.to_global(path.curve.sample_baked(off - 2.0))
		var b := path.to_global(path.curve.sample_baked(off + 2.0))
		if a.distance_squared_to(b) > 0.01:
			fwd = b - a
	fwd = (fwd - normal * fwd.dot(normal)).normalized()
	var sc := global_transform.basis.get_scale()
	# Half sunk between the lowest corner and the mean, so it neither floats nor vanishes on a crest.
	var settle_y := lerpf(y, mid_y, 0.5)
	global_transform = Transform3D(Basis.looking_at(fwd, normal).scaled(sc), Vector3(centre.x, settle_y, centre.z) + normal * 0.01)


func _on_snap_button_pressed() -> void:
	print("[BoostPad] Snap requested for '", name, "' at ", global_position)
	var ok := snap_pad_to_ground()
	if ok:
		print("[BoostPad] OK — snapped '", name, "' to ", global_position)
	else:
		push_warning("[BoostPad] FAILED for '", name, "'. Open the full Level scene, not BoostPad.tscn alone.")


## Reliable editor snap: TrackPath + mesh height sample. Always moves if a TrackPath exists.
func snap_pad_to_ground() -> bool:
	if not is_inside_tree():
		push_warning("[BoostPad] Not in tree.")
		return false

	var origin: Vector3 = global_position
	var path := _find_track_path()
	var target: Vector3 = origin
	var normal: Vector3 = Vector3.UP
	var used_path := false

	# 1) Snap XZ (and base Y) to nearest track centerline — always works in editor
	if path != null and path.curve != null:
		var local: Vector3 = path.to_local(origin)
		var off: float = path.curve.get_closest_offset(local)
		var baked: Vector3 = path.curve.sample_baked(off)
		target = path.to_global(baked)
		used_path = true
		# Surface orientation from path samples
		var blen: float = maxf(path.curve.get_baked_length(), 1.0)
		var p0: Vector3 = path.to_global(path.curve.sample_baked(maxf(off - 1.0, 0.0)))
		var p1: Vector3 = path.to_global(path.curve.sample_baked(minf(off + 1.0, blen)))
		var tangent: Vector3 = p1 - p0
		tangent.y = 0.0
		if tangent.length_squared() > 1e-6:
			tangent = tangent.normalized()
		else:
			tangent = -global_transform.basis.z
			tangent.y = 0.0
			if tangent.length_squared() < 1e-6:
				tangent = Vector3.FORWARD
			else:
				tangent = tangent.normalized()
		# Keep lateral offset from path (don't force center if user placed pad beside road)
		var path_xz := Vector3(target.x, 0.0, target.z)
		var origin_xz := Vector3(origin.x, 0.0, origin.z)
		var lateral: Vector3 = origin_xz - path_xz
		# Cap lateral so pad stays on sand strip (~8m half-width)
		var lat_len: float = lateral.length()
		if lat_len > 7.5:
			lateral = lateral * (7.5 / lat_len)
		target.x = path_xz.x + lateral.x
		target.z = path_xz.z + lateral.z

	# 2) Refine Y with a downward sample against road meshes (and physics if available)
	var sample_xz: Vector3 = Vector3(target.x, origin.y, target.z)
	var surface: Dictionary = _sample_surface_y(sample_xz)
	if not surface.is_empty():
		target.y = float(surface.y)
		if surface.has("normal"):
			normal = surface.normal
	elif used_path:
		# Path centerline Y + small lift
		target.y = target.y + ground_snap_lift
	else:
		return false

	if normal.length_squared() < 1e-8:
		normal = Vector3.UP
	else:
		normal = normal.normalized()
	if normal.y < 0.2:
		normal = Vector3.UP

	var sc: Vector3 = global_transform.basis.get_scale()
	var b: Basis
	if align_to_slope:
		var fwd: Vector3 = -global_transform.basis.z
		fwd = fwd - normal * fwd.dot(normal)
		if fwd.length_squared() < 1e-6:
			fwd = Vector3.FORWARD
		else:
			fwd = fwd.normalized()
		b = Basis.looking_at(fwd, normal)
	else:
		var flat_fwd: Vector3 = -global_transform.basis.z
		flat_fwd.y = 0.0
		if flat_fwd.length_squared() < 1e-6:
			flat_fwd = Vector3.FORWARD
		else:
			flat_fwd = flat_fwd.normalized()
		b = Basis.looking_at(flat_fwd, Vector3.UP)

	b = b.scaled(sc.abs())
	global_transform = Transform3D(b, target + normal * maxf(ground_snap_lift, 0.0))
	return true


## Vertical surface sample at XZ (world). Returns {y, normal} or {}.
func _sample_surface_y(at: Vector3) -> Dictionary:
	var from: Vector3 = Vector3(at.x, at.y + 150.0, at.z)
	var to: Vector3 = Vector3(at.x, at.y - 400.0, at.z)
	var dir: Vector3 = (to - from).normalized()
	var max_d: float = from.distance_to(to)

	# Physics first
	var world := get_world_3d()
	if world:
		if Engine.is_editor_hint() and world.space.is_valid():
			PhysicsServer3D.space_set_active(world.space, true)
		var space := world.direct_space_state
		if space:
			var query := PhysicsRayQueryParameters3D.create(from, to)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			query.collision_mask = 0xFFFFFFFF
			query.exclude = [get_rid()]
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				return {"y": hit.position.y, "normal": hit.normal}

	# Mesh sample (road meshes only — small enough for editor)
	var best_y: float = -1.0e12
	var best_n: Vector3 = Vector3.UP
	var found := false
	for mi in _collect_road_meshes():
		var faces: PackedVector3Array = mi.mesh.get_faces()
		if faces.size() < 3 or faces.size() > 400000:
			continue
		var xform: Transform3D = mi.global_transform
		# AABB reject
		var aabb: AABB = xform * mi.get_aabb()
		aabb = aabb.grow(2.0)
		if at.x < aabb.position.x or at.x > aabb.position.x + aabb.size.x:
			continue
		if at.z < aabb.position.z or at.z > aabb.position.z + aabb.size.z:
			continue
		var i := 0
		while i + 2 < faces.size():
			var a: Vector3 = xform * faces[i]
			var b: Vector3 = xform * faces[i + 1]
			var c: Vector3 = xform * faces[i + 2]
			i += 3
			var hitp = Geometry3D.ray_intersects_triangle(from, dir, a, b, c)
			if hitp == null:
				continue
			var p: Vector3 = hitp as Vector3
			var t: float = from.distance_to(p)
			if t < 0.001 or t > max_d:
				continue
			# Highest hit under the pad (top surface)
			if p.y > best_y:
				best_y = p.y
				var n: Vector3 = (b - a).cross(c - a)
				if n.length_squared() > 1e-12:
					n = n.normalized()
					if n.y < 0.0:
						n = -n
					best_n = n
				found = true
	if found:
		return {"y": best_y, "normal": best_n}
	return {}


func _collect_road_meshes() -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var root := _scene_root()
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == null or node == self or self.is_ancestor_of(node):
			continue
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			var n := str(mi.name)
			if mi.mesh != null and (
					n.contains("Visual_Road") or n.contains("Road") or n.contains("Curbs")
					or n.contains("Track") or n.contains("Terrain_Visual")
			):
				out.append(mi)
		for c in node.get_children():
			stack.append(c)
	return out


func _find_track_path() -> Path3D:
	if get_tree() == null:
		return null
	var level = get_tree().get_first_node_in_group("level")
	if level and level.get("track_path") is Path3D:
		return level.track_path as Path3D
	if level:
		var p = level.get_node_or_null("TrackPath")
		if p is Path3D:
			return p as Path3D
	var n: Node = self
	while n:
		var tp = n.get_node_or_null("TrackPath")
		if tp is Path3D:
			return tp as Path3D
		n = n.get_parent()
	return null


func _scene_root() -> Node:
	if get_tree() == null:
		return get_parent()
	if Engine.is_editor_hint() and get_tree().edited_scene_root:
		return get_tree().edited_scene_root
	if get_tree().current_scene:
		return get_tree().current_scene
	return get_tree().root


func _on_body_entered(body: Node3D):
	if body.has_method("client_start_pad_boost"):
		flash_boost_pad()
		var is_mp: bool = false
		var nm: Node = get_node_or_null("/root/NetworkManager")
		if nm and "current_game_mode" in nm and "GameMode" in nm:
			is_mp = (nm.current_game_mode == nm.GameMode.MULTIPLAYER)
		if not is_mp:
			if body.get("is_local_player") or body.get("is_ai"):
				body.client_start_pad_boost(boost_strength, boost_duration)
		else:
			if body.has_method("is_multiplayer_authority") and body.is_multiplayer_authority():
				body.client_start_pad_boost.rpc(boost_strength, boost_duration)


func flash_boost_pad():
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	_set_flash(flash_brightness / 3.0)
	flash_tween = create_tween()
	flash_tween.tween_method(_set_flash, flash_brightness / 3.0, 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_flash(v: float) -> void:
	_flash = v
	if _visual:
		_visual.set_instance_shader_parameter(&"flash", v)
