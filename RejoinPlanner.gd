extends RefCounted
## A way back to the road for an AI cart off the course (PlayerCart._ai_rejoin_goal), when no straight line will do:
## behind a guardrail, a fence or a wall, down a bank, round a pond. A Dijkstra search over a CELL-metre grid round the
## cart, probing the world as it goes:
## - a cell is the ground a ray down finds there (from just over the height it was reached at, so a bridge overhead
##   isn't taken for the ground under it); blocked where that is deep water, the top of something (a tree, a rock, a
##   building) or too steep;
## - a step between neighbouring cells is blocked where the ground climbs more than CLIMB a metre (a cart won't climb
##   much past 35 degrees off the road), falls more than DROP, or where something long but track and ground stands
##   across it at a cart's height (a ray at BUMPER metres over the ground from one to the other: rails, walls, fences;
##   a narrow thing, a trunk or a post, the cart's avoidance steers round);
## - a goal is a drivable cell on the lap: within the road's half width of the lap's line in plan and near its height
##   (on the road, or on the ground where a stage has none: Frostfall Gorge, Pinecrest's forest trail); reaching one
##   behind the cart along the lap costs extra (BEHIND_COST a metre), so it goes on round. The lap's points near the
##   cart are hashed once a search (`_lap_hash`), so a cell's test is a few lookups.
## The cheapest way is the path, as world points the cart then follows. The search stops at MAX_RADIUS from the cart and
## MAX_EXPAND cells: no road in reach and the cart is respawned.
##
## Probes are cached per level (every cart and every search shares them: the barriers don't move), and so is what each
## collider is (track, ground, a thing standing: name checks up its parents are most of a probe's cost), and all
## searches share FRAME_USEC microseconds a physics frame, so one runs over a few frames instead of hitching one (a
## search could take 19ms in one frame). A search is `step`ped once a physics frame until it is `done`.

const CELL := 3.0
const MAX_RADIUS := 80.0
const MAX_EXPAND := 6000
const FRAME_USEC := 1200
const CLIMB := 0.72
const DROP := 3.5
const BUMPER := 0.8
const BUMPER_LOW := 0.35
const BEHIND_COST := 1.2
## How far over the height a cell was reached at its ray starts (a 3m step can't climb more than about 2.2m).
const PROBE_UP := 4.0
const LAP_BUCKET := 6.0
const PROBE_DOWN := 14.0
## A ground cell with something standing within TIGHT_R of a cart there (a sphere TIGHT_R round where the cart's body would
## be) costs TIGHT_COST times as much to cross: ways keep to open ground. Every 3m cell open, a way ran between a guardrail
## and the chevron boards 2m behind it (the cart is 2.7m across) and the bot wedged there.
const TIGHT_R := 1.25
const TIGHT_COST := 3.0

## [kind, ground y, lap offset, tight] by Vector3i(ix, iz, height bucket): kind 0 blocked, 1 ground, 2 road (a goal), 3
## other track (driven on, not a goal: a ramp, a deck off the lap); tight 1 where something stands close (TIGHT_R).
static var _cells := {}
## Whether a step is open, by Vector4i(ix, iz, height bucket, direction).
static var _steps := {}
## Steps and cells closed where a cart stalled (close_step, close_at), by key, until a Time.get_ticks_msec().
static var _step_closed := {}
static var _cell_closed := {}
const CLOSE_MSEC := 20000
static var _level_id := 0
static var _frame := -1
static var _usec_left := 0
## What each collider is, by instance id: 1 track, 2 ground or something to drive on, 3 a thing standing (a prop).
static var _kinds := {}
## Time spent stepping searches (microseconds) and the frames it was spent in, for the probes.
static var total_usec := 0
static var busiest_usec := 0

const DIRS := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]

var done := false
var found := false
## The way back, from the cart's cell to the road, as points on the ground.
var path := PackedVector3Array()
var expanded := 0

var _cart: Node
var _space: PhysicsDirectSpaceState3D
var _lap: Path3D
var _lap_len := 1.0
var _start_off := 0.0
var _road_half := 7.5
var _start: Vector3
var _exclude: Array[RID] = []
var _open: Array = []          # binary heap of [cost, key]
var _g := {}                   # key -> cost
var _parent := {}              # key -> key
var _closed := {}
var _best_goal = null
var _best_cost := INF
var _lap_hash := {}
static var _tight_shape: SphereShape3D = null            # Vector2i(LAP_BUCKET cell) -> Array of Vector4(x, y, z, lap offset)


func _init(cart: Node, space: PhysicsDirectSpaceState3D, lap: Path3D, road_half: float) -> void:
	_cart = cart
	_space = space
	_lap = lap
	_road_half = road_half
	_lap_len = maxf(lap.curve.get_baked_length(), 1.0)
	_start = (cart as Node3D).global_position
	_start_off = lap.curve.get_closest_offset(lap.to_local(_start))
	var lvl := cart.get_tree().get_first_node_in_group("level")
	var id: int = lvl.get_instance_id() if lvl else 0
	if id != _level_id:
		_level_id = id
		_cells.clear()
		_steps.clear()
		_step_closed.clear()
		_cell_closed.clear()
		_kinds.clear()
	for c in cart.get_tree().get_nodes_in_group("player_carts"):
		if c is CollisionObject3D:
			_exclude.append((c as CollisionObject3D).get_rid())
	# The lap's points within reach, every 1.5m.
	var o := 0.0
	while o < _lap_len:
		var lp: Vector3 = lap.to_global(lap.curve.sample_baked(o))
		if Vector2(lp.x - _start.x, lp.z - _start.z).length() < MAX_RADIUS + _road_half + 10.0:
			var hk := Vector2i(floori(lp.x / LAP_BUCKET), floori(lp.z / LAP_BUCKET))
			if not _lap_hash.has(hk):
				_lap_hash[hk] = []
			_lap_hash[hk].append(Vector4(lp.x, lp.y, lp.z, o))
		o += 1.5
	# The cart's own cell, at the ground under it (probed from just over the cart, not a bridge above it).
	var key: Vector3i = _key_at(_start, _start.y - 0.6)
	var cell = _probe(key, _start.y + 1.0 - PROBE_UP)
	if cell == null:
		cell = PackedFloat32Array([1.0, _start.y - 0.75, -1.0, 0.0])
		_cells[key] = cell
	_g[key] = 0.0
	_push(0.0, key)


## Closes the cell at `p` (a point of a way back the cart stalled short of) for every search on this level for the
## next CLOSE_MSEC.
static func close_at(p: Vector3) -> void:
	var ix := floori(p.x / CELL)
	var iz := floori(p.z / CELL)
	var iy := floori(p.y / 4.0)
	var until := Time.get_ticks_msec() + CLOSE_MSEC
	for b in range(iy - 2, iy + 3):
		_cell_closed[Vector3i(ix, iz, b)] = until


## Closes the step from `a` to `b` (two points of a way back: the cart stalled between them) both ways round for every
## search on this level for the next CLOSE_MSEC; a cell, `b`'s, if they aren't neighbours. Not for good: the stall may
## have been another cart in the way, and over a race closed steps sealed a bot in behind Pinecrest's summit tyre wall.
static func close_step(a: Vector3, b: Vector3) -> void:
	var ka := Vector2i(floori(a.x / CELL), floori(a.z / CELL))
	var kb := Vector2i(floori(b.x / CELL), floori(b.z / CELL))
	var d := kb - ka
	var di := DIRS.find(d)
	if di < 0:
		close_at(b)
		return
	var dr := DIRS.find(-d)
	var ba := floori(a.y / 4.0)
	var bb := floori(b.y / 4.0)
	var until := Time.get_ticks_msec() + CLOSE_MSEC
	for band in range(-2, 3):
		_step_closed[Vector4i(ka.x, ka.y, ba + band, di)] = until
		_step_closed[Vector4i(kb.x, kb.y, bb + band, dr)] = until


## Runs the search on with what is left of this frame's rays; true once it is done (`found` says whether it found a way).
func step() -> bool:
	if done:
		return true
	if not is_instance_valid(_cart):
		done = true
		return true
	var f := Engine.get_physics_frames()
	if f != _frame:
		_frame = f
		_usec_left = FRAME_USEC
	if _usec_left <= 0:
		return false
	var t0 := Time.get_ticks_usec()
	var r := _run(t0 + _usec_left)
	var spent := Time.get_ticks_usec() - t0
	_usec_left -= spent
	total_usec += spent
	busiest_usec = maxi(busiest_usec, spent)
	return r


func _run(until: int) -> bool:
	while not _open.is_empty():
		# Out of this frame's time: on next frame (a cell is done whole, so this is checked before each).
		if Time.get_ticks_usec() >= until:
			return false
		var top: Array = _pop()
		var cost: float = top[0]
		var key: Vector3i = top[1]
		if _closed.has(key) or cost > float(_g.get(key, INF)) + 1e-4:
			continue
		if cost >= _best_cost:
			break
		_closed[key] = true
		expanded += 1
		var cell: PackedFloat32Array = _cells[key]
		if int(cell[0]) == 2:
			var goal_cost := cost + _behind_cost(cell[2])
			if goal_cost < _best_cost:
				_best_cost = goal_cost
				_best_goal = key
			continue
		if expanded >= MAX_EXPAND:
			break
		var here := _centre(key, cell[1])
		for di in range(DIRS.size()):
			# Out of time halfway through a cell (a stretch of jungle: every tree a first look): back on the queue whole,
			# its neighbours so far are cached and cheap the second time.
			if di > 0 and Time.get_ticks_usec() >= until:
				_closed.erase(key)
				expanded -= 1
				_push(cost, key)
				return false
			var d: Vector2i = DIRS[di]
			var nkey := _neighbour_key(key, d, cell[1])
			if _closed.has(nkey):
				continue
			var ncell = _probe(nkey, cell[1])
			if ncell == null or int(ncell[0]) == 0:
				continue
			if _cell_closed.has(nkey) and Time.get_ticks_msec() < int(_cell_closed[nkey]):
				continue
			var there := _centre(nkey, ncell[1])
			if Vector2(there.x - _start.x, there.z - _start.z).length() > MAX_RADIUS:
				continue
			if not _step_open(key, di, cell, ncell, here, there):
				continue
			var run: float = CELL * (1.4142 if d.x != 0 and d.y != 0 else 1.0)
			var rise: float = (ncell[1] - cell[1]) / run
			var w: float = run * (1.0 + 2.0 * maxf(rise, 0.0) + 0.8 * maxf(-rise - 0.4, 0.0))
			if int(ncell[0]) >= 2:
				w *= 0.85
			elif ncell[3] > 0.5:
				w *= TIGHT_COST
			var ng: float = cost + w
			if ng < float(_g.get(nkey, INF)):
				_g[nkey] = ng
				_parent[nkey] = key
				_push(ng, nkey)
	done = true
	found = _best_goal != null
	if found:
		var k = _best_goal
		var pts: Array[Vector3] = []
		while k != null:
			var c: PackedFloat32Array = _cells[k]
			pts.push_front(_centre(k, c[1]) + Vector3.UP * 0.5)
			k = _parent.get(k, null)
		path = PackedVector3Array(pts)
	return true


## The lap's nearest point to `p` in plan (x, y, z, lap offset), from `_lap_hash`; w is -1 if none is near.
func _lap_near(p: Vector3) -> Vector4:
	var best := Vector4(0, 0, 0, -1.0)
	var bd := INF
	var hk := Vector2i(floori(p.x / LAP_BUCKET), floori(p.z / LAP_BUCKET))
	var reach := int(ceil((_road_half + 2.0) / LAP_BUCKET))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			for q in _lap_hash.get(hk + Vector2i(dx, dz), []):
				var v: Vector4 = q
				var d := Vector2(v.x - p.x, v.z - p.z).length_squared()
				if d < bd:
					bd = d
					best = v
	return best


## Extra cost of reaching the road at lap offset `off`: behind the cart (going back), a little for each metre.
func _behind_cost(off: float) -> float:
	if off < 0.0:
		return 0.0
	var d := fposmod(off - _start_off + _lap_len * 0.5, _lap_len) - _lap_len * 0.5
	return maxf(-d, 0.0) * BEHIND_COST


func _key_at(p: Vector3, y: float) -> Vector3i:
	return Vector3i(floori(p.x / CELL), floori(p.z / CELL), floori(y / 4.0))


func _neighbour_key(key: Vector3i, d: Vector2i, y: float) -> Vector3i:
	return Vector3i(key.x + d.x, key.y + d.y, floori(y / 4.0))


func _centre(key: Vector3i, y: float) -> Vector3:
	return Vector3((float(key.x) + 0.5) * CELL, y, (float(key.y) + 0.5) * CELL)


## What `collider` is (cached by instance): 1 track, 2 ground (or anything to drive on that isn't a prop), 3 a prop.
func _kind_of(collider: Object) -> int:
	if collider == null:
		return 3
	var id := collider.get_instance_id()
	if _kinds.has(id):
		return _kinds[id]
	var gap_flag = _cart.get("_on_road_gap_ground")
	var k := 2
	if _cart._is_track_surface(collider):
		k = 1
	elif _cart._is_world_terrain_collider(collider):
		k = 2
	elif _cart._is_blocking_prop(collider):
		k = 3
	_cart.set("_on_road_gap_ground", gap_flag)
	# The terrain counts as track within the road's corridor (_is_track_surface's own rule): never cache it as track.
	if k != 1 or not _cart._is_world_terrain_collider(collider):
		_kinds[id] = k
	return k


## The cell at `key`, reached from ground at height `from_y`: [kind, ground y, lap offset], cached.
func _probe(key: Vector3i, from_y: float):
	if _cells.has(key):
		return _cells[key]
	var c := _centre(key, 0.0)
	var q := PhysicsRayQueryParameters3D.create(Vector3(c.x, from_y + PROBE_UP, c.z), Vector3(c.x, from_y - PROBE_DOWN, c.z))
	q.exclude = _exclude
	q.collision_mask = 1
	var hit := _space.intersect_ray(q)
	var out := PackedFloat32Array([0.0, from_y, -1.0, 0.0])
	if not hit.is_empty():
		var p: Vector3 = hit.position
		var n: Vector3 = hit.normal
		out[1] = p.y
		var kind := _kind_of(hit.collider)
		if kind == 1:
			out[0] = 3.0
		elif kind == 2:
			# Ground: anything flat enough that isn't the top of a thing (a rock, a tree, a crate, a building: what the
			# obstacle avoidance steers round) or under deep water. Not by name: many stages' ground isn't "terrain".
			if n.y >= 0.6 and not _cart._deep_water_at(p):
				out[0] = 1.0
		# On the lap (on its road, or on the ground of a stage without one): a goal.
		if out[0] > 0.5:
			var near := _lap_near(p)
			if near.w >= 0.0 and Vector2(near.x - p.x, near.z - p.z).length() < _road_half + (1.0 if out[0] > 2.5 else 0.0) \
					and absf(near.y - p.y) < 3.0:
				out[0] = 2.0
				out[2] = near.w
		if int(out[0]) == 1 and _tight(p):
			out[3] = 1.0
	_cells[key] = out
	return out


## Whether something but track, ground and carts stands within TIGHT_R of a cart's body on the ground at `p`.
func _tight(p: Vector3) -> bool:
	if _tight_shape == null:
		_tight_shape = SphereShape3D.new()
		_tight_shape.radius = TIGHT_R
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _tight_shape
	q.transform = Transform3D(Basis(), p + Vector3.UP * (TIGHT_R + 0.3))
	q.exclude = _exclude
	q.collision_mask = 1
	for r in _space.intersect_shape(q, 6):
		var c: Object = r.collider
		if c == null or _cart._is_world_terrain_collider(c):
			continue
		if _kind_of(c) == 1:
			continue
		return true
	return false


## Whether a cart can drive from cell `a` to its neighbour in direction `di` (cached either way round).
func _step_open(a: Vector3i, di: int, ca: PackedFloat32Array, cb: PackedFloat32Array, pa: Vector3, pb: Vector3) -> bool:
	var run: float = Vector2(pb.x - pa.x, pb.z - pa.z).length()
	var rise: float = (cb[1] - ca[1]) / maxf(run, 0.1)
	if rise > CLIMB and int(cb[0]) < 2:
		return false
	if ca[1] - cb[1] > DROP:
		return false
	var skey := Vector4i(a.x, a.y, a.z, di)
	if _step_closed.has(skey) and Time.get_ticks_msec() < int(_step_closed[skey]):
		return false
	if _steps.has(skey):
		return _steps[skey]
	# Two heights over the ground (BUMPER_LOW and BUMPER): with the ground on one side higher than on the other (a cut
	# bank above Pinecrest's road), one ray at 0.7m passed over the guardrail at the low end, the step was taken for
	# open, and bots drove into the rail at the end of their way back and stopped there.
	var open := true
	for h in [BUMPER_LOW, BUMPER]:
		var from: Vector3 = pa + Vector3.UP * h
		var to: Vector3 = pb + Vector3.UP * h
		for _i in range(4):
			var q := PhysicsRayQueryParameters3D.create(from, to)
			q.exclude = _exclude
			q.collision_mask = 1
			q.hit_back_faces = false
			var hit := _space.intersect_ray(q)
			if hit.is_empty():
				break
			var kind := _kind_of(hit.collider)
			if kind == 1 or _cart._is_world_terrain_collider(hit.collider) or (hit.normal as Vector3).y >= 0.55:
				break
			# A narrow thing (a trunk, a post, a rock: PlayerCart._ai_narrow_obstacle) is no bar, the obstacle avoidance
			# steers round it; only a long one is (a rail, a fence, a wall). Every trunk blocking, ways back through the
			# jungle wove from tree to tree. The ray goes on from behind it: a chevron board in front of Pinecrest's
			# summit tyre wall hid the wall, and bots drove into it at the end of their way back again and again.
			if not _cart._ai_narrow_obstacle(_space, hit, to - from):
				open = false
				break
			var hp: Vector3 = hit.position
			if hp.distance_to(to) < 0.8:
				break
			from = hp + (to - hp).normalized() * 0.6
		if not open:
			break
	_steps[skey] = open
	return open


# A binary heap of [cost, key] by cost.
func _push(cost: float, key: Vector3i) -> void:
	_open.append([cost, key])
	var i := _open.size() - 1
	while i > 0:
		var parent_i := (i - 1) >> 1
		if float(_open[parent_i][0]) <= cost:
			break
		_open[i] = _open[parent_i]
		i = parent_i
	_open[i] = [cost, key]


func _pop() -> Array:
	var top: Array = _open[0]
	var last: Array = _open.pop_back()
	if _open.is_empty():
		return top
	var i := 0
	var n := _open.size()
	while true:
		var l := i * 2 + 1
		if l >= n:
			break
		var r := l + 1
		var m := l
		if r < n and float(_open[r][0]) < float(_open[l][0]):
			m = r
		if float(_open[m][0]) >= float(last[0]):
			break
		_open[i] = _open[m]
		i = m
	_open[i] = last
	return top
