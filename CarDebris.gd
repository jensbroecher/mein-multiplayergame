extends RefCounted
## Tears a procedural car apart for an explosion. The saved cars are one `Body` mesh (every bumper,
## wing, shock and lamp merged into it) plus four wheels, so the pieces are found in the mesh itself:
## triangles that share vertices belong to one piece. The biggest piece is the shell; the rest
## (bumpers, shocks, wings, mirrors, lamps, exhausts...) can come off on their own.
##
## PlayerCart calls prepare() when a cart spawns. A worker thread splits the body then, under the
## loading screen, and builds a mesh for every piece that can come off, plus the shell cut into
## shards for the cars that disintegrate. Nothing is analysed at the explosion: roll() picks the
## damage, tear() assembles it (one new body mesh at most) and PlayerCart flies the pieces.
##
## Piece meshes are centred on their own middle, so they spin about it; `center` is where that sits
## in the body's frame. They keep the body's vertex layout and material, so they draw in the same
## pipeline and take the paint job and the fade like the body does.

## The smallest piece that tears off on its own; smaller ones (bolts, trim lines) stay on the shell.
const MIN_PART_TRIS := 60
## Pieces this big fly off singly when the shell disintegrates; the rest of it goes as shards.
const BIG_PART_TRIS := 100
const MAX_OWN_PARTS := 22
const SHARDS := 11

static var _plans: Dictionary = {}
static var _tasks: Dictionary = {}
static var _mutex := Mutex.new()


## Starts splitting `body`'s mesh for `key` (the car's model) unless that's done or under way.
static func prepare(key: String, body: MeshInstance3D) -> void:
	if body == null or _plans.has(key) or _tasks.has(key):
		return
	var mesh := body.mesh as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 1:
		return
	# Read the arrays here, on the main thread; the worker only works on them.
	var arrays := mesh.surface_get_arrays(0)
	var material := mesh.surface_get_material(0)
	_tasks[key] = WorkerThreadPool.add_task(func(): _build_plan(key, arrays, material), false, "car debris " + key)


## The plan for `key`, or {} while it's still being built (or for a car that can't be split).
static func get_plan(key: String) -> Dictionary:
	_mutex.lock()
	var plan: Dictionary = _plans.get(key, {})
	_mutex.unlock()
	return plan


## What an explosion does to the car. Wheels are PlayerCart's; `parts` is how many body pieces come
## off, `disintegrate` shatters the shell too. Few cars lose everything.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var corners := ["FL", "FR", "RL", "RR"]
	corners.shuffle()
	var r := rng.randf()
	var wheels := 0
	var parts := 0
	var disintegrate := false
	if r < 0.12:
		# Scorched, mostly in one piece.
		wheels = rng.randi_range(0, 1)
		parts = rng.randi_range(2, 4)
	elif r < 0.42:
		# The wheels go.
		wheels = [2, 2, 3, 4][rng.randi() % 4]
		parts = rng.randi_range(1, 3)
	elif r < 0.80:
		# Stripped: bumpers, wings and shocks fly, a wheel or two.
		wheels = rng.randi_range(0, 2)
		parts = rng.randi_range(5, 10)
	else:
		disintegrate = true
		wheels = rng.randi_range(2, 4)
	return {"wheels": corners.slice(0, wheels), "parts": parts, "disintegrate": disintegrate}


## Assembles `damage` (from roll()) from `plan`: {"stay": the body's mesh without what came off (null:
## leave the body as it is), "hide_body": the body is gone, "pieces": [{mesh, center, size}]}.
static func tear(plan: Dictionary, damage: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var parts: Array = plan["parts"]
	var result := {"stay": null, "hide_body": false, "pieces": []}
	if damage["disintegrate"]:
		for i in plan["own"]:
			result["pieces"].append(parts[i])
		result["pieces"].append_array(plan["shards"])
		result["hide_body"] = true
		return result
	var count := mini(int(damage["parts"]), parts.size())
	if count <= 0:
		return result
	# Parts to lose: weighted toward the big and the outlying, none twice.
	var weights := PackedFloat32Array()
	var total := 0.0
	for p in parts:
		var w: float = p["weight"]
		weights.append(w)
		total += w
	var gone := {}
	for n in count:
		var pick := rng.randf() * total
		for i in parts.size():
			if gone.has(i):
				continue
			pick -= weights[i]
			if pick <= 0.0:
				gone[i] = true
				total -= weights[i]
				result["pieces"].append(parts[i])
				break
	# The body keeps the shell, the small fittings and every part that stayed.
	var idx: PackedInt32Array = (plan["rest"] as PackedInt32Array).duplicate()
	for i in parts.size():
		if not gone.has(i):
			idx.append_array(parts[i]["idx"])
	var arrays: Array = (plan["arrays"] as Array).duplicate()
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, plan["material"])
	result["stay"] = mesh
	return result


# ---------------------------------------------------------------------------------------------
#  Building the plan (worker thread)
# ---------------------------------------------------------------------------------------------

static func _build_plan(key: String, arrays: Array, material: Material) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var pieces := _split(verts, idx)
	if pieces.size() < 2:
		return
	pieces.sort_custom(func(a, b): return a["idx"].size() > b["idx"].size())
	var shell: Dictionary = pieces[0]
	var shell_box: AABB = shell["aabb"]

	# The shell and the fittings too small to tear off make up the rest.
	var rest: PackedInt32Array = shell["idx"].duplicate()
	var parts: Array = []
	var scratch := PackedInt32Array()
	scratch.resize(verts.size())
	scratch.fill(-1)
	for i in range(1, pieces.size()):
		var p: Dictionary = pieces[i]
		if p["idx"].size() / 3 < MIN_PART_TRIS:
			rest.append_array(p["idx"])
			continue
		var box: AABB = p["aabb"]
		var out := box.get_center() - shell_box.get_center()
		var half := shell_box.size * 0.5
		var outward := Vector3(absf(out.x) / half.x, absf(out.y) / maxf(half.y, 0.1) * 0.5, absf(out.z) / half.z).length() / 1.4
		parts.append({
			"idx": p["idx"],
			"center": box.get_center(),
			"size": box.size,
			"mesh": _piece_mesh(arrays, p["idx"], box.get_center(), material, scratch),
			"weight": sqrt(float(p["idx"].size() / 3)) * (0.3 + outward),
		})

	# Big parts that fly off alone when the car disintegrates (parts is already biggest first).
	var own: Array = []
	for i in parts.size():
		if parts[i]["idx"].size() / 3 >= BIG_PART_TRIS and own.size() < MAX_OWN_PARTS:
			own.append(i)
	# Everything else is cut into shards.
	var pool: PackedInt32Array = rest.duplicate()
	for i in parts.size():
		if not own.has(i):
			pool.append_array(parts[i]["idx"])
	var shards := _shards(arrays, pool, key, material, scratch)

	var plan := {
		"arrays": arrays,
		"material": material,
		"rest": rest,
		"parts": parts,
		"own": own,
		"shards": shards,
	}
	_mutex.lock()
	_plans[key] = plan
	_mutex.unlock()


## The loose pieces of a mesh: triangles joined through shared vertices, each as its index list and
## bounds. (Union-find over the triangles.)
static func _split(verts: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var parent := PackedInt32Array()
	parent.resize(verts.size())
	for i in verts.size():
		parent[i] = i
	for t in range(0, idx.size(), 3):
		_union(parent, idx[t], idx[t + 1])
		_union(parent, idx[t], idx[t + 2])
	var piece_of := {}
	var pieces: Array = []
	for t in range(0, idx.size(), 3):
		var root := _find(parent, idx[t])
		if not piece_of.has(root):
			piece_of[root] = pieces.size()
			pieces.append({"idx": PackedInt32Array(), "aabb": AABB(verts[idx[t]], Vector3.ZERO)})
		var p: Dictionary = pieces[piece_of[root]]
		var box: AABB = p["aabb"]
		for k in 3:
			var i: int = idx[t + k]
			p["idx"].append(i)
			box = box.expand(verts[i])
		p["aabb"] = box
	return pieces


static func _find(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _union(parent: PackedInt32Array, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb


## `pool`'s triangles cut into SHARDS pieces: each triangle goes to the nearest of a few seed points
## spread over the car (farthest-point picks from a sample), so the cuts run in jagged cells.
static func _shards(arrays: Array, pool: PackedInt32Array, key: String, material: Material, scratch: PackedInt32Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var tri_count := pool.size() / 3
	var centroids := PackedVector3Array()
	centroids.resize(tri_count)
	for t in tri_count:
		centroids[t] = (verts[pool[t * 3]] + verts[pool[t * 3 + 1]] + verts[pool[t * 3 + 2]]) / 3.0
	var rng := RandomNumberGenerator.new()
	rng.seed = key.hash()
	var sample := PackedVector3Array()
	for i in 400:
		sample.append(centroids[rng.randi() % tri_count])
	var seeds := PackedVector3Array([sample[0]])
	while seeds.size() < SHARDS:
		var far := sample[0]
		var far_d := -1.0
		for s in sample:
			var d := INF
			for seed_point in seeds:
				d = minf(d, s.distance_squared_to(seed_point))
			if d > far_d:
				far_d = d
				far = s
		seeds.append(far)
	var cells: Array = []
	for i in SHARDS:
		cells.append({"idx": PackedInt32Array(), "sum": Vector3.ZERO})
	for t in tri_count:
		var c := centroids[t]
		var best := 0
		var best_d := INF
		for i in SHARDS:
			var d := c.distance_squared_to(seeds[i])
			if d < best_d:
				best_d = d
				best = i
		var cell: Dictionary = cells[best]
		cell["idx"].append(pool[t * 3])
		cell["idx"].append(pool[t * 3 + 1])
		cell["idx"].append(pool[t * 3 + 2])
		cell["sum"] += c
	var shards: Array = []
	for cell in cells:
		var n: int = cell["idx"].size() / 3
		if n < 20:
			continue
		var center: Vector3 = cell["sum"] / float(n)
		var mesh := _piece_mesh(arrays, cell["idx"], center, material, scratch)
		shards.append({"mesh": mesh, "center": center, "size": mesh.get_aabb().size})
	return shards


## A mesh of the triangles in `idx` (indices into `arrays`' vertices), moved so `center` is its
## origin. Every channel of the body is carried over, so it draws like the body. `scratch` maps
## source vertex to piece vertex (all -1 on entry and on return).
static func _piece_mesh(arrays: Array, idx: PackedInt32Array, center: Vector3, material: Material, scratch: PackedInt32Array) -> ArrayMesh:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]

	var used := PackedInt32Array()
	var out_idx := PackedInt32Array()
	out_idx.resize(idx.size())
	for j in idx.size():
		var src := idx[j]
		var mapped := scratch[src]
		if mapped < 0:
			mapped = used.size()
			scratch[src] = mapped
			used.append(src)
		out_idx[j] = mapped

	var n := used.size()
	var o_verts := PackedVector3Array()
	var o_normals := PackedVector3Array()
	var o_tangents := PackedFloat32Array()
	var o_colors := PackedColorArray()
	var o_uv := PackedVector2Array()
	var o_uv2 := PackedVector2Array()
	o_verts.resize(n)
	o_normals.resize(n)
	o_tangents.resize(n * 4)
	o_colors.resize(n)
	o_uv.resize(n)
	o_uv2.resize(n)
	for k in n:
		var src := used[k]
		o_verts[k] = verts[src] - center
		o_normals[k] = normals[src]
		o_tangents[k * 4] = tangents[src * 4]
		o_tangents[k * 4 + 1] = tangents[src * 4 + 1]
		o_tangents[k * 4 + 2] = tangents[src * 4 + 2]
		o_tangents[k * 4 + 3] = tangents[src * 4 + 3]
		o_colors[k] = colors[src]
		o_uv[k] = uv[src]
		o_uv2[k] = uv2[src]
		scratch[src] = -1

	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = o_verts
	out[Mesh.ARRAY_NORMAL] = o_normals
	out[Mesh.ARRAY_TANGENT] = o_tangents
	out[Mesh.ARRAY_COLOR] = o_colors
	out[Mesh.ARRAY_TEX_UV] = o_uv
	out[Mesh.ARRAY_TEX_UV2] = o_uv2
	out[Mesh.ARRAY_INDEX] = out_idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	mesh.surface_set_material(0, material)
	return mesh
