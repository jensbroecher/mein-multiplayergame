extends Node3D

const CartWeight = preload("res://CartWeight.gd")
## The chevron boards round the corners break off when a cart hits them. Level.gd adds this once its own runtime
## colliders exist (before DressingColliders), so no level needs regenerating.
##
## The generators build every board of a level into one mesh (Msitu Falls' `Chevrons/ChevronBoards` and
## `ChevronPosts`, Pinecrest Ridge's `Chevrons/ChevronSigns` and its `ChevronSignsBody` boxes). At load the
## triangles are split per sign (their middles within LINK of each other in plan: the boards stand 8m+ apart), each
## sign becomes a node of its own with its meshes re-centred on its middle and a convex hull of its own (the old
## merged mesh, and Pinecrest's boxes, go). A cart faster than BREAK_SPEED coming at a sign knocks it off before it
## touches: the collider goes, the cart loses DRAG of its speed (the carts this peer drives), and the sign flies off
## along the cart's travel (THROW of its speed, a hop up), tumbling end over end about its long axis, bounces and
## settles lying on the ground, where it stays for the race. Slower, it is solid and stops the cart. Local scenery,
## like KnockablePoles: every peer breaks the signs it sees carts hit, from how far they moved; nothing is synced.

const ROOT_NAMES := ["Chevrons"]
## A sign's triangles: middles closer than this in plan are one sign.
const LINK := 1.8
const BREAK_SPEED := 5.0
const DRAG := 0.05
const CART_RADIUS := 1.3
const THROW := Vector2(0.45, 0.7)
const HOP := Vector2(3.5, 6.5)
const GRAVITY := 22.0
## End over end (rad/s) and a little yaw.
const TUMBLE := Vector2(6.0, 11.0)
const YAW := 2.0
const BOUNCE := 0.3
const REST_SPEED := 1.6
## Metres its middle rests over the ground, lying down.
const REST_LIFT := 0.12
const SETTLE_RATE := 7.0
## The knock: a board of timber (Msitu Falls' boards stand on wooden posts) or of steel.
const WOOD_SOUND := "res://sounds/crate_crash.mp3"
const METAL_SOUND := "res://sounds/unused_car_crash_clank.mp3"

## [node, body, centre, radius, long axis (world, horizontal), state 0 standing 1 flying 2 at rest, vel, tumble,
## yaw rate, angle, yaw, basis0, sound, the angle it settles to lying down (NAN until it lands)]
var _signs: Array = []
var _cells := {}
var _cart_prev := {}
var _rng := RandomNumberGenerator.new()
var _level: Node = null


## Finds the levels' chevron meshes and makes a breakable sign of each board.
func build(level: Node) -> void:
	_level = level
	_rng.randomize()
	var t0 := Time.get_ticks_msec()
	for root_name in ROOT_NAMES:
		for root in level.find_children(root_name, "Node3D", true, false):
			if root == self or is_ancestor_of(root):
				continue
			_split_root(root as Node3D)
	print("[BreakableSigns] %d signs (%d ms)" % [_signs.size(), Time.get_ticks_msec() - t0])
	set_physics_process(not _signs.is_empty())


func _split_root(root: Node3D) -> void:
	var meshes: Array = []
	var wood := false
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		meshes.append(mi)
		if String(mi.name).to_lower().contains("post"):
			wood = true
	if meshes.is_empty():
		return
	# Every triangle in the world, with its source surface.
	var tris: Array = []  # [mesh index, surface, a, b, c (indices into that surface), middle]
	var surf_data: Array = []  # per mesh: per surface: [arrays, world xf, material]
	for mi_i in meshes.size():
		var mi: MeshInstance3D = meshes[mi_i]
		var per: Array = []
		var xf: Transform3D = mi.global_transform
		for si in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(verts.size())
				for i in verts.size():
					idx[i] = i
			var mat: Material = mi.material_override if mi.material_override else mi.get_active_material(si)
			per.append([arr, xf, mat, idx])
			for t in range(0, idx.size() - 2, 3):
				var m: Vector3 = xf * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
				tris.append([mi_i, si, t, m])
		surf_data.append(per)
	# Union the triangles whose middles are within LINK in plan.
	var parent := PackedInt32Array()
	parent.resize(tris.size())
	var grid := {}
	for i in tris.size():
		parent[i] = i
		var m: Vector3 = tris[i][3]
		var key := Vector2i(floori(m.x / LINK), floori(m.z / LINK))
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		var cell: PackedInt32Array = grid[key]
		cell.append(i)
		grid[key] = cell
	for key in grid:
		var here: PackedInt32Array = grid[key]
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var other: PackedInt32Array = grid.get(key + Vector2i(dx, dz), PackedInt32Array())
				for i in here:
					var mi_: Vector3 = tris[i][3]
					for j in other:
						if j <= i:
							continue
						var mj: Vector3 = tris[j][3]
						if Vector2(mi_.x - mj.x, mi_.z - mj.z).length() < LINK:
							_union(parent, i, j)
	var groups := {}
	for i in tris.size():
		var r: int = _find(parent, i)
		var g: Array = groups.get(r, [])
		g.append(i)
		groups[r] = g
	for r in groups:
		_make_sign(root, groups[r], tris, surf_data, wood)
	# The merged meshes and the old shared colliders go.
	for mi in meshes:
		(mi as Node).queue_free()
	for b in root.find_children("*", "CollisionObject3D", true, false):
		(b as Node).queue_free()


func _make_sign(root: Node3D, members: Array, tris: Array, surf_data: Array, wood: bool) -> void:
	# The sign's world vertices per source surface.
	var parts := {}  # "mesh:surface" -> {verts, normals, uvs, colors, mat}
	var all_pts := PackedVector3Array()
	for i in members:
		var tr: Array = tris[i]
		var sd: Array = surf_data[tr[0]][tr[1]]
		var arr: Array = sd[0]
		var xf: Transform3D = sd[1]
		var idx: PackedInt32Array = sd[3]
		var key := "%d:%d" % [tr[0], tr[1]]
		if not parts.has(key):
			parts[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray(),
				"has_n": arr[Mesh.ARRAY_NORMAL] != null, "has_uv": arr[Mesh.ARRAY_TEX_UV] != null, "has_c": arr[Mesh.ARRAY_COLOR] != null, "mat": sd[2]}
		var p: Dictionary = parts[key]
		var nb: Basis = xf.basis.inverse().transposed()
		var pv: PackedVector3Array = p["v"]
		var pn: PackedVector3Array = p["n"]
		var puv: PackedVector2Array = p["uv"]
		var pc: PackedColorArray = p["c"]
		for k in 3:
			var vi: int = idx[int(tr[2]) + k]
			var w: Vector3 = xf * (arr[Mesh.ARRAY_VERTEX][vi] as Vector3)
			pv.append(w)
			all_pts.append(w)
			if p["has_n"]:
				pn.append((nb * (arr[Mesh.ARRAY_NORMAL][vi] as Vector3)).normalized())
			if p["has_uv"]:
				puv.append(arr[Mesh.ARRAY_TEX_UV][vi])
			if p["has_c"]:
				pc.append(arr[Mesh.ARRAY_COLOR][vi])
		p["v"] = pv
		p["n"] = pn
		p["uv"] = puv
		p["c"] = pc
	if all_pts.size() < 3:
		return
	var lo := all_pts[0]
	var hi := all_pts[0]
	var sum := Vector3.ZERO
	for q in all_pts:
		lo = lo.min(q)
		hi = hi.max(q)
		sum += q
	var centre: Vector3 = sum / float(all_pts.size())
	# Its long axis: the widest way in plan (principal axis of the points' spread).
	var sxx := 0.0
	var szz := 0.0
	var sxz := 0.0
	for q in all_pts:
		var dx: float = q.x - centre.x
		var dz: float = q.z - centre.z
		sxx += dx * dx
		szz += dz * dz
		sxz += dx * dz
	var ang: float = 0.5 * atan2(2.0 * sxz, sxx - szz)
	var long := Vector3(cos(ang), 0.0, sin(ang))
	var node := Node3D.new()
	node.name = "ChevronSign_%d" % _signs.size()
	add_child(node)
	node.global_position = centre
	for key in parts:
		var p: Dictionary = parts[key]
		var verts: PackedVector3Array = p["v"]
		for i in verts.size():
			verts[i] -= centre
		var na: Array = []
		na.resize(Mesh.ARRAY_MAX)
		na[Mesh.ARRAY_VERTEX] = verts
		if p["has_n"]:
			na[Mesh.ARRAY_NORMAL] = p["n"]
		if p["has_uv"]:
			na[Mesh.ARRAY_TEX_UV] = p["uv"]
		if p["has_c"]:
			na[Mesh.ARRAY_COLOR] = p["c"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, na)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = p["mat"]
		mi.visibility_range_end = 400.0
		node.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "SignBody"
	body.set_meta(&"surface", "wood" if wood else "rock")
	var hull := ConvexPolygonShape3D.new()
	var local_pts := PackedVector3Array()
	for q in all_pts:
		local_pts.append(q - centre)
	hull.points = local_pts
	var cs := CollisionShape3D.new()
	cs.shape = hull
	body.add_child(cs)
	node.add_child(body)
	var radius: float = maxf(Vector2(hi.x - lo.x, hi.z - lo.z).length() * 0.5, 0.5)
	var s: Array = [node, body, centre, radius, long, 0, Vector3.ZERO, 0.0, 0.0, 0.0, 0.0, node.global_basis, WOOD_SOUND if wood else METAL_SOUND, NAN]
	var ck := Vector2i(floori(centre.x / 8.0), floori(centre.z / 8.0))
	var cell: Array = _cells.get(ck, [])
	cell.append(_signs.size())
	_cells[ck] = cell
	_signs.append(s)


func _physics_process(delta: float) -> void:
	for cart in get_tree().get_nodes_in_group("player_carts"):
		var c := cart as Node3D
		if c == null:
			continue
		var pos: Vector3 = c.global_position
		var cid: int = c.get_instance_id()
		var prev: Vector3 = _cart_prev.get(cid, pos)
		_cart_prev[cid] = pos
		var vel: Vector3 = (pos - prev) / maxf(delta, 0.001)
		var speed: float = Vector2(vel.x, vel.z).length()
		if speed < BREAK_SPEED or speed > 90.0:
			continue
		var ck := Vector2i(floori(pos.x / 8.0), floori(pos.z / 8.0))
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				for si in _cells.get(ck + Vector2i(dx, dz), []):
					var s: Array = _signs[si]
					if int(s[5]) != 0:
						continue
					var centre: Vector3 = s[2]
					# Reached by the next step: the knock comes before the collider would stop the cart.
					var reach: float = float(s[3]) + CART_RADIUS + speed * delta * 1.5
					if Vector2(pos.x - centre.x, pos.z - centre.z).length() > reach or absf(pos.y - centre.y) > 3.5:
						continue
					_knock(si, c, vel)
	for s in _signs:
		if int(s[5]) == 1:
			_fly(s, delta)


func _knock(si: int, cart: Node3D, vel: Vector3) -> void:
	var s: Array = _signs[si]
	s[5] = 1
	var body: StaticBody3D = s[1]
	if is_instance_valid(body):
		body.queue_free()
	if cart.has_method("has_physics_authority") and cart.has_physics_authority() and cart is RigidBody3D:
		(cart as RigidBody3D).linear_velocity *= 1.0 - DRAG * CartWeight.loss_share(cart)
	var flat := Vector3(vel.x, 0.0, vel.z)
	s[6] = flat * _rng.randf_range(THROW.x, THROW.y) + Vector3.UP * _rng.randf_range(HOP.x, HOP.y)
	# End over end, away from the cart: about the board's long axis, the way that tips its top along the travel.
	var long: Vector3 = s[4]
	var tip_sign: float = signf(long.cross(Vector3.UP).dot(flat))
	s[7] = _rng.randf_range(TUMBLE.x, TUMBLE.y) * (tip_sign if tip_sign != 0.0 else 1.0)
	s[8] = _rng.randf_range(-YAW, YAW)
	_play(s, (s[0] as Node3D).global_position, flat.length())


func _fly(s: Array, delta: float) -> void:
	var node: Node3D = s[0]
	if not is_instance_valid(node):
		s[5] = 2
		return
	var dt: float = minf(delta, 0.05)
	var long: Vector3 = s[4]
	if not is_nan(float(s[13])):
		# Landed: it lies down where it is, face up or face down.
		s[9] = move_toward(float(s[9]), float(s[13]), SETTLE_RATE * dt)
		if is_equal_approx(float(s[9]), float(s[13])):
			s[5] = 2
		node.global_basis = Basis(Vector3.UP, float(s[10])) * Basis(long, float(s[9])) * (s[11] as Basis)
		return
	var vel: Vector3 = s[6]
	vel += Vector3.DOWN * GRAVITY * dt
	var pos: Vector3 = node.global_position + vel * dt
	s[9] = float(s[9]) + float(s[7]) * dt
	s[10] = float(s[10]) + float(s[8]) * dt
	var ground: float = _ground_y(pos)
	if pos.y <= ground + REST_LIFT and vel.y < 0.0:
		pos.y = ground + REST_LIFT
		vel.y = -vel.y * BOUNCE
		vel.x *= 0.55
		vel.z *= 0.55
		s[7] = float(s[7]) * 0.5
		s[8] = float(s[8]) * 0.5
		if vel.length() < REST_SPEED:
			# The nearer of face up and face down, eased there (SETTLE_RATE).
			s[13] = (floor(float(s[9]) / PI) + 0.5) * PI
			vel = Vector3.ZERO
	s[6] = vel
	node.global_position = pos
	node.global_basis = Basis(Vector3.UP, float(s[10])) * Basis(long, float(s[9])) * (s[11] as Basis)


## The ground under `p`: past the carts and what stands on the ground (DressingColliders' plant and rock cells, trunks,
## the other signs), or a sign came to rest on top of a shrub's box.
func _ground_y(p: Vector3) -> float:
	var excl: Array = []
	for cart in get_tree().get_nodes_in_group("player_carts"):
		if cart is CollisionObject3D:
			excl.append((cart as CollisionObject3D).get_rid())
	var space := get_world_3d().direct_space_state
	for attempt in 6:
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN * 40.0)
		q.exclude = excl
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			break
		var n := String((hit["collider"] as Node).name) if hit["collider"] is Node else ""
		if n.begins_with("DressingSolid") or n.begins_with("TreeTrunks") or n == "SignBody":
			excl.append(hit["rid"])
			continue
		return float(hit["position"].y)
	return p.y - 40.0


func _play(s: Array, at: Vector3, speed: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = load(String(s[12]))
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = 20.0
	p.volume_db = lerpf(-8.0, -1.0, clampf(speed / 40.0, 0.0, 1.0))
	p.pitch_scale = _rng.randf_range(0.9, 1.1)
	p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = _find(parent, a)
	var rb: int = _find(parent, b)
	if ra != rb:
		parent[ra] = rb
