extends Node3D
## Traffic on a busy road the route crosses (Quer durch Kronburg's Ring: two lanes each way and the trams in the
## median), on the wall clock so every LAN peer sees the same cars in the same places without syncing. Touching a vehicle
## destroys a cart ("crushed", as a train does at Estación Seca): there are no collision bodies (a cart at 60 m/s moves a
## metre a step), `_check_hits` tests every cart this peer drives against each vehicle's box, swept over the tick.
##
## The road is this node's local z axis, from `z_north` to `z_south` (negative z is north). A lane is an x offset in
## `lanes`: a positive one runs toward -z, a negative one toward +z (driving on the right). Its height over this node
## comes from `heights` (every `height_step` metres from z_north), so the road can dive into a tunnel. Each vehicle is a
## slot of `slots` ([lane, kind, t_cross, speed], flattened): it reaches the crossing (z = `crossing_z`) with its nose at
## `t_cross` seconds into the `period`, and does again every period, so a slot is a stream of vehicles one period apart
## (the instances `_insts` holds, as many as the road's length needs). The generator lays them out in platoons, as if
## let go by traffic lights up the road, with gaps between the platoons where nothing comes either way (a bot waits for
## one of those, HazardGate.gd; a player can thread through the platoons' gaps). `meshes` are the kinds (nose toward -z,
## game size; their boxes come from the meshes' AABBs). A vehicle grows in and shrinks away over `fade` at the road's
## ends (in the far haze and inside the tunnel).
##
## Sounds: a tram rings its bell (`bells`) as it nears the crossing and at a cart in its way, and rumbles (`tram_sound`)
## while it is near; a car honks (`horns`) at a cart that passes close in front of it.

@export var meshes: Array[Mesh] = []
@export var lanes := PackedFloat32Array()
@export var slots := PackedFloat32Array()
@export var period := 60.0
@export var z_north := -1150.0
@export var z_south := 480.0
@export var heights := PackedFloat32Array()
@export var height_step := 10.0
@export var fade := 30.0
@export var crossing_z := 0.0
## How far along the road either side of crossing_z the route's band runs (its half width and a little).
@export var band := 9.0
@export var kills := true
## A fraction of the cart's radius that has to reach into a vehicle's box to count as a hit.
@export var hit_share := 0.85
## Seconds into the day; set to hold the traffic still for tests and shots (negative: the wall clock).
@export var clock_override := -1.0
@export var tram_kinds := PackedInt32Array()
@export var bells: Array[AudioStream] = []
@export var horns: Array[AudioStream] = []
@export var tram_sound: AudioStream
@export var bell_db := -4.0
@export var horn_db := -6.0
@export var tram_db := -10.0
@export var sound_unit := 30.0

signal cart_hit(cart: Node)

class Veh:
	var lane := 0
	var kind := 0
	var x := 0.0
	var dir := 1.0
	var speed := 14.0
	var t_cross := 0.0
	var k := 0
	var mm_index := 0
	var length := 4.0
	var half_w := 1.0
	var height := 1.5
	var nose := 0.0         # the mesh's nose offset (its AABB's min z)
	var is_tram := false
	var present := false
	var z_nose := 0.0
	var y := 0.0
	var horn_at := -100.0
	var bell_at := -100.0
	var bell_rung := false
	var rumble: AudioStreamPlayer3D

var _insts: Array[Veh] = []
var _mmis: Array[MultiMeshInstance3D] = []
var _headless := false
var _prev_pos := {}
var _intervals: Array = []
var _players: Array[AudioStreamPlayer3D] = []
var _next_player := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_rng.seed = 991
	var boxes: Array = []
	for m in meshes:
		var ab: AABB = m.get_aabb() if m != null else AABB(Vector3(-1, 0, -2), Vector3(2, 1.5, 4))
		boxes.append(ab)
	var counts: Array[int] = []
	counts.resize(meshes.size())
	counts.fill(0)
	var road_len: float = z_south - z_north
	var n: int = floori(slots.size() / 4.0)
	for i in range(n):
		var lane: int = int(slots[i * 4])
		var kind: int = int(slots[i * 4 + 1])
		var t_c: float = slots[i * 4 + 2]
		var v: float = maxf(slots[i * 4 + 3], 1.0)
		var ab: AABB = boxes[kind]
		var copies: int = ceili((road_len + ab.size.z) / (v * period)) + 1
		for k in range(copies):
			var veh := Veh.new()
			veh.lane = lane
			veh.kind = kind
			veh.x = lanes[lane]
			veh.dir = 1.0 if lanes[lane] > 0.0 else -1.0
			veh.speed = v
			veh.t_cross = t_c
			veh.k = k
			veh.length = ab.size.z
			veh.half_w = ab.size.x * 0.5
			veh.height = ab.size.y + ab.position.y
			veh.nose = ab.position.z
			veh.is_tram = tram_kinds.has(kind)
			veh.mm_index = counts[kind]
			counts[kind] += 1
			_insts.append(veh)
	if not _headless:
		for i in range(meshes.size()):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[i]
			mm.instance_count = counts[i]
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Traffic%d" % i
			mmi.multimesh = mm
			# The vehicles move: DressingColliders would freeze a collider (and its wobble, drawing the car) where each stood at load.
			mmi.set_meta(&"skip_dressing_colliders", true)
			var lo: float = -12.0
			var hi: float = 14.0
			for h in heights:
				lo = minf(lo, h - 4.0)
				hi = maxf(hi, h + 14.0)
			var wide: float = 4.0
			for l in lanes:
				wide = maxf(wide, absf(l) + 6.0)
			mmi.custom_aabb = AABB(Vector3(-wide, lo, z_north - 40.0), Vector3(wide * 2.0, hi - lo, road_len + 80.0))
			add_child(mmi, false, Node.INTERNAL_MODE_BACK)
			_mmis.append(mmi)
		for j in range(6):
			var p := AudioStreamPlayer3D.new()
			p.name = "Voice%d" % j
			p.unit_size = sound_unit
			p.max_distance = 600.0
			p.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
			add_child(p, false, Node.INTERNAL_MODE_BACK)
			_players.append(p)
		if tram_sound != null:
			for veh in _insts:
				if veh.is_tram:
					var r := AudioStreamPlayer3D.new()
					r.stream = tram_sound
					r.volume_db = tram_db
					r.unit_size = sound_unit
					r.max_distance = 500.0
					r.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
					add_child(r, false, Node.INTERNAL_MODE_BACK)
					veh.rumble = r
	_place(_clock())


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## Seconds into the traffic's cycle.
func cycle_time() -> float:
	return fposmod(_clock(), period)


func _height(z: float) -> float:
	if heights.size() < 2:
		return 0.0
	var f: float = clampf((z - z_north) / height_step, 0.0, float(heights.size() - 1))
	var i: int = mini(int(f), heights.size() - 2)
	return lerpf(heights[i], heights[i + 1], f - float(i))


## Distance from a lane's start to the crossing.
func _to_cross(dir: float) -> float:
	return (z_south - crossing_z) if dir > 0.0 else (crossing_z - z_north)


func _place(t: float) -> void:
	var road_len: float = z_south - z_north
	for veh in _insts:
		var c: float = _to_cross(veh.dir)
		var u: float = fposmod(t - veh.t_cross + c / veh.speed, period)
		var d: float = (u + float(veh.k) * period) * veh.speed
		veh.present = d > 0.0 and d - veh.length < road_len
		veh.z_nose = (z_south - d) if veh.dir > 0.0 else (z_north + d)
		var zc: float = veh.z_nose + veh.dir * veh.length * 0.5
		veh.y = _height(zc)
		if _headless:
			continue
		var mm: MultiMesh = _mmis[veh.kind].multimesh
		if not veh.present:
			mm.set_instance_transform(veh.mm_index, Transform3D(Basis.from_scale(Vector3.ONE * 0.001), Vector3(0, -500.0, 0)))
			continue
		var edge: float = minf(d, road_len - (d - veh.length))
		var sc: float = clampf(edge / maxf(fade, 0.01), 0.0, 1.0)
		var slope: float = (_height(zc - 2.0) - _height(zc + 2.0)) / 4.0
		var basis := Basis() if veh.dir > 0.0 else Basis(Vector3.UP, PI)
		basis = basis * Basis(Vector3.RIGHT, atan(slope) * veh.dir)
		# The mesh's nose at z_nose: heading -z its nose is its AABB's min z, heading +z (turned) the AABB's min z, negated.
		var oz: float = veh.z_nose - veh.nose if veh.dir > 0.0 else veh.z_nose + veh.nose
		mm.set_instance_transform(veh.mm_index, Transform3D(basis.scaled(Vector3.ONE * maxf(sc, 0.001)), Vector3(veh.x, veh.y, oz)))


func _physics_process(_delta: float) -> void:
	var t: float = _clock()
	_place(t)
	if kills:
		_check_hits()
	if not _headless:
		_update_sounds(t)


# ======================================================================================
#  Hits
# ======================================================================================

func _check_hits() -> void:
	var carts := get_tree().get_nodes_in_group("player_carts")
	var seen := {}
	var wide: float = 4.0
	for l in lanes:
		wide = maxf(wide, absf(l) + 4.0)
	var inv: Transform3D = global_transform.affine_inverse()
	for c in carts:
		var cart := c as Node3D
		if cart == null or not is_instance_valid(cart):
			continue
		var id := cart.get_instance_id()
		seen[id] = true
		var pos: Vector3 = inv * cart.global_position
		var prev: Vector3 = _prev_pos.get(id, pos)
		_prev_pos[id] = pos
		if absf(pos.x) > wide + 3.0 and absf(prev.x) > wide + 3.0:
			continue
		if not _cart_can_die(cart):
			continue
		var r: float = float(cart.get("collision_radius")) * hit_share
		for k in 5:
			var p: Vector3 = prev.lerp(pos, k / 4.0)
			var veh: Veh = _vehicle_at(p, r)
			if veh != null:
				_kill(cart, veh)
				break


func _vehicle_at(p: Vector3, r: float) -> Veh:
	for veh in _insts:
		if not veh.present:
			continue
		if absf(p.x - veh.x) > veh.half_w + r:
			continue
		var z0: float = veh.z_nose if veh.dir > 0.0 else veh.z_nose - veh.length
		var z1: float = z0 + veh.length
		var q := Vector3(
			maxf(absf(p.x - veh.x) - veh.half_w, 0.0),
			maxf(maxf(veh.y - 0.8 - p.y, p.y - (veh.y + veh.height)), 0.0),
			maxf(maxf(z0 - p.z, p.z - z1), 0.0))
		if q.length() < r:
			return veh
	return null


func _cart_can_die(cart: Node) -> bool:
	if not cart.has_method("has_physics_authority") or not cart.has_physics_authority():
		return false
	for flag in ["is_exploding", "is_finished_race", "is_teleporting", "is_drowned"]:
		if cart.get(flag):
			return false
	return true


func _kill(cart: Node, veh: Veh) -> void:
	print("CrossTraffic %s: a %s hit cart %s" % [name, "tram" if veh.is_tram else "vehicle", cart.name])
	cart_hit.emit(cart)
	if not _headless:
		_voice(horns if not veh.is_tram else bells, Vector3(veh.x, veh.y + 1.5, veh.z_nose), horn_db if not veh.is_tram else bell_db)
	if multiplayer.multiplayer_peer != null:
		cart.explode_rpc.rpc(0, "traffic")
	else:
		cart.explode(0, "traffic")


# ======================================================================================
#  The timetable at the crossing (for HazardGate.gd)
# ======================================================================================

## When in the cycle some vehicle covers the route's band, as [start, end] pairs within [0, period).
func cover_intervals(_gate: Node = null) -> Array:
	if not _intervals.is_empty():
		return _intervals
	var n: int = floori(slots.size() / 4.0)
	var raw: Array = []
	for i in range(n):
		var kind: int = int(slots[i * 4 + 1])
		var t_c: float = slots[i * 4 + 2]
		var v: float = maxf(slots[i * 4 + 3], 1.0)
		var length: float = meshes[kind].get_aabb().size.z if kind < meshes.size() and meshes[kind] != null else 4.0
		var a: float = fposmod(t_c - band / v, period)
		var b: float = a + (2.0 * band + length) / v
		if b > period:
			raw.append([a, period])
			raw.append([0.0, b - period])
		else:
			raw.append([a, b])
	raw.sort_custom(func(p, q): return p[0] < q[0])
	for iv in raw:
		if not _intervals.is_empty() and float(iv[0]) <= float(_intervals[-1][1]) + 0.05:
			_intervals[-1][1] = maxf(float(_intervals[-1][1]), float(iv[1]))
		else:
			_intervals.append([float(iv[0]), float(iv[1])])
	return _intervals


## The longest clear stretch of the cycle at the crossing (seconds), for the generator's report.
func longest_gap() -> float:
	var ivs: Array = cover_intervals()
	if ivs.is_empty():
		return period
	var best := 0.0
	for i in range(ivs.size()):
		var end_t: float = float(ivs[i][1])
		var next_t: float = float(ivs[(i + 1) % ivs.size()][0]) + (period if i == ivs.size() - 1 else 0.0)
		best = maxf(best, next_t - end_t)
	return best


# ======================================================================================
#  Sounds
# ======================================================================================

func _update_sounds(t: float) -> void:
	var carts := get_tree().get_nodes_in_group("player_carts")
	var inv: Transform3D = global_transform.affine_inverse()
	var cart_pos: Array = []
	for c in carts:
		if c is Node3D and is_instance_valid(c):
			cart_pos.append(inv * (c as Node3D).global_position)
	for veh in _insts:
		if veh.rumble != null:
			var near: bool = veh.present and absf(veh.z_nose - crossing_z) < 450.0
			if near:
				veh.rumble.position = Vector3(veh.x, veh.y + 1.5, veh.z_nose + veh.dir * veh.length * 0.5)
				if not veh.rumble.playing:
					veh.rumble.play(_rng.randf() * maxf(veh.rumble.stream.get_length() - 1.0, 0.0))
			elif veh.rumble.playing:
				veh.rumble.stop()
		if not veh.present:
			veh.bell_rung = false
			continue
		var ahead_of_cross: float = (veh.z_nose - crossing_z) * veh.dir
		if veh.is_tram:
			# Approaching the crossing: one ring 70m out.
			if not veh.bell_rung and ahead_of_cross > 0.0 and ahead_of_cross < 70.0:
				veh.bell_rung = true
				_ring(veh, t)
			elif ahead_of_cross < -20.0:
				veh.bell_rung = false
		for p in cart_pos:
			var cp: Vector3 = p
			# A cart in front of the vehicle in its lane (within 30m of its nose for a tram, 9m for a car) or right beside it.
			var in_front: float = (veh.z_nose - cp.z) * veh.dir
			var across: float = absf(cp.x - veh.x)
			if absf(cp.y - veh.y) > 6.0:
				continue
			if veh.is_tram:
				if in_front > 0.0 and in_front < 30.0 and across < 4.0 and t - veh.bell_at > 3.0:
					_ring(veh, t)
			elif in_front > -veh.length and in_front < 9.0 and across < veh.half_w + 3.5 and t - veh.horn_at > 4.0:
				veh.horn_at = t
				_voice(horns, Vector3(veh.x, veh.y + 1.0, veh.z_nose), horn_db)


func _ring(veh: Veh, t: float) -> void:
	veh.bell_at = t
	_voice(bells, Vector3(veh.x, veh.y + 3.0, veh.z_nose), bell_db)


func _voice(streams: Array, at: Vector3, db: float) -> void:
	if streams.is_empty() or _players.is_empty():
		return
	var p: AudioStreamPlayer3D = _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(0.95, 1.05)
	p.position = at
	p.play()
