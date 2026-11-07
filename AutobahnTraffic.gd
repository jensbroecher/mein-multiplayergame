extends Node3D
## Traffic on a straight road along this node's -z (Kronburger Hütte's Autobahn viaduct, Rheinufer's A 58 and A 47):
## `meshes` (vehicles, nose toward -z) driven along `lanes` (x offsets; positive lanes run toward -z, negative ones back
## toward +z) over `length` metres, on the wall clock so every peer sees the same traffic, each vehicle at its own speed
## and spacing. A vehicle shrinks to nothing over `fade` metres at either end. One MultiMesh per vehicle kind; nothing is
## drawn on a headless server.
##
## With `kills` (Rheinufer's A 47 westbound, which the race may take against the traffic) touching a vehicle destroys a
## cart, as CrossTraffic's do: no collision bodies (a cart closing at 70 m/s moves more than a metre a step), each cart
## this peer drives is tested against every vehicle's box (from its mesh's AABB), swept over the tick. Without it the
## vehicles are scenery and carts pass through them.

@export var meshes: Array[Mesh] = []
@export var lanes := PackedFloat32Array([5.0, -5.0])
@export var length := 1000.0
@export var per_lane := 7
@export var speeds := Vector2(26.0, 42.0)
@export var fade := 40.0
## Optional: the road's height (over this node's y) every `height_step` metres along its length (Rheinufer's A 47 rises
## over the Rhine; Kronburger Hütte's viaduct is level and leaves it empty). Vehicles follow it and pitch with it.
@export var heights := PackedFloat32Array()
@export var height_step := 10.0
@export var kills := false
## A fraction of the cart's radius that has to reach into a vehicle's box to count as a hit.
@export var hit_share := 0.85
## Seconds into the day; set to hold the traffic still for tests and shots (negative: the wall clock).
@export var clock_override := -1.0

signal cart_hit(cart: Node)

var _mmis: Array[MultiMeshInstance3D] = []
## Per vehicle: [kind, index in its kind, lane x, direction (+1 toward -z), speed, phase].
var _cars: Array = []
## Per kind: the mesh's AABB (the hit box).
var _boxes: Array[AABB] = []
var _headless := false
var _prev_pos := {}


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	if meshes.is_empty():
		set_process(false)
		set_physics_process(false)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4747
	var counts: Array[int] = []
	counts.resize(meshes.size())
	counts.fill(0)
	for li in range(lanes.size()):
		var lane_speed: float = rng.randf_range(speeds.x, speeds.y) * (1.12 if absf(lanes[li]) < 8.0 else 0.92)
		for k in range(per_lane):
			var kind: int = rng.randi_range(0, meshes.size() - 1)
			var phase: float = (float(k) + rng.randf_range(-0.3, 0.3)) / float(per_lane) * length
			_cars.append([kind, counts[kind], lanes[li], 1.0 if lanes[li] > 0.0 else -1.0, lane_speed * rng.randf_range(0.97, 1.03), phase])
			counts[kind] += 1
	for m in meshes:
		_boxes.append(m.get_aabb() if m != null else AABB(Vector3(-1.2, 0, -2.5), Vector3(2.4, 2.0, 5.0)))
	set_physics_process(kills)
	if _headless:
		set_process(false)
		return
	for i in range(meshes.size()):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[i]
		mm.instance_count = counts[i]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		# The vehicles move: DressingColliders would freeze a collider (and its wobble, drawing the car) where each stood at load.
		mmi.set_meta(&"skip_dressing_colliders", true)
		var top := 12.0
		for h in heights:
			top = maxf(top, h + 12.0)
		mmi.custom_aabb = AABB(Vector3(-20, -2, -length - 20), Vector3(40, top, length + 40))
		add_child(mmi, false, Node.INTERNAL_MODE_BACK)
		_mmis.append(mmi)


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fposmod(Time.get_unix_time_from_system(), 86400.0)


## A vehicle's place at time t: [its transform in this node's frame, the distance from the road's start (0..length)].
func _place(c: Array, t: float) -> Array:
	var speed: float = c[4]
	var s: float = fposmod(t * speed + float(c[5]), length)
	var dir: float = c[3]
	var z: float = -s if dir > 0.0 else -(length - s)
	var sc: float = clampf(minf(s, length - s) / fade, 0.0, 1.0)
	var basis := Basis() if dir > 0.0 else Basis(Vector3.UP, PI)
	var y := 0.0
	if heights.size() > 1:
		var d: float = -z
		y = _height(d)
		var slope: float = (_height(d + 2.0) - _height(d - 2.0)) / 4.0
		basis = basis * Basis(Vector3.RIGHT, atan(slope) * dir)
	return [Transform3D(basis.scaled(Vector3.ONE * maxf(sc, 0.001)), Vector3(c[2], y, z)), sc]


func _process(_delta: float) -> void:
	var t: float = _clock()
	for c in _cars:
		var pl: Array = _place(c, t)
		_mmis[c[0]].multimesh.set_instance_transform(c[1], pl[0])


func _height(d: float) -> float:
	var f: float = clampf(d / height_step, 0.0, float(heights.size() - 1))
	var i: int = mini(int(f), heights.size() - 2)
	return lerpf(heights[i], heights[i + 1], f - float(i))


# ======================================================================================
#  Hits (kills)
# ======================================================================================

func _physics_process(_delta: float) -> void:
	var carts := get_tree().get_nodes_in_group("player_carts")
	if carts.is_empty():
		return
	var wide: float = 4.0
	for l in lanes:
		wide = maxf(wide, absf(l) + 4.0)
	var inv: Transform3D = global_transform.affine_inverse()
	var t: float = -1.0
	var placed: Array = []
	for cn in carts:
		var cart := cn as Node3D
		if cart == null or not is_instance_valid(cart):
			continue
		var id := cart.get_instance_id()
		var pos: Vector3 = inv * cart.global_position
		var prev: Vector3 = _prev_pos.get(id, pos)
		_prev_pos[id] = pos
		# A respawn's jump is no sweep.
		if prev.distance_to(pos) > 12.0:
			prev = pos
		if absf(pos.x) > wide + 3.0 and absf(prev.x) > wide + 3.0:
			continue
		if pos.z > 5.0 or pos.z < -length - 5.0:
			continue
		if not _cart_can_die(cart):
			continue
		if t < 0.0:
			t = _clock()
			for c in _cars:
				placed.append(_place(c, t))
		var r: float = float(cart.get("collision_radius")) * hit_share
		for k in 5:
			var p: Vector3 = prev.lerp(pos, k / 4.0)
			var hit: int = _vehicle_at(p, r, placed)
			if hit >= 0:
				_kill(cart)
				break


## The index of a vehicle whose box (in its own frame, scaled as drawn) the sphere at p with radius r reaches into, or -1.
func _vehicle_at(p: Vector3, r: float, placed: Array) -> int:
	for i in _cars.size():
		var c: Array = _cars[i]
		if absf(p.x - float(c[2])) > 4.0 + r:
			continue
		var sc: float = placed[i][1]
		if sc < 0.5:
			continue
		var xf: Transform3D = placed[i][0]
		var ab: AABB = _boxes[c[0]]
		var q: Vector3 = xf.affine_inverse() * p
		var lo: Vector3 = ab.position
		var hi: Vector3 = ab.end
		var d := Vector3(maxf(maxf(lo.x - q.x, q.x - hi.x), 0.0), maxf(maxf(lo.y - 0.6 - q.y, q.y - hi.y), 0.0), maxf(maxf(lo.z - q.z, q.z - hi.z), 0.0))
		if d.length() * sc < r:
			return i
	return -1


func _cart_can_die(cart: Node) -> bool:
	if not cart.has_method("has_physics_authority") or not cart.has_physics_authority():
		return false
	for flag in ["is_exploding", "is_finished_race", "is_teleporting", "is_drowned"]:
		if cart.get(flag):
			return false
	return true


func _kill(cart: Node) -> void:
	print("AutobahnTraffic %s: a vehicle hit cart %s" % [name, cart.name])
	cart_hit.emit(cart)
	if multiplayer.multiplayer_peer != null:
		cart.explode_rpc.rpc(0, "traffic")
	else:
		cart.explode(0, "traffic")
	_prev_pos.erase(cart.get_instance_id())
