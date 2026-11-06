extends Node3D
## A flock of sheep with their shepherd and his dog on Rheinufer's Rhine meadows (Kronburg GP, stage 2). Most of the time
## the sheep graze in area A (slow steps, heads down, now and then one looks up); every `cross_every` seconds the dog
## gathers them and the shepherd leads them across the race road, bunched up, to graze in area B, and the next time back.
##
## Everything a sheep does is a function of the wall clock (Time.get_unix_time_from_system(), WildebeestHerd's way), so
## every machine in a LAN race sees the same flock at the same moment without any network traffic. Only the knocks are
## local: a cart this peer has physics authority over that runs into a sheep throws it aside (it tumbles, runs off a few
## metres, stands, and trots back to its place) and loses a little speed, scaled by the cart's weight (CartWeight.gd).
## The sheep have kinematic bodies on ANIMAL_LAYER (value 4) only, which carts don't collide with and the AI's obstacle
## rays see, so bots steer round them.
##
## The animals are drawn from MultiMeshes (one per kind: sheep, dog, shepherd), posed in sheep_flock.gdshader from each
## instance's custom data (gait phase and stride, head lowered, black-headed or white-faced), so the flock is a draw call
## and its legs walk on a headless server too (where nothing is drawn: only the bodies move). The meshes are built here in
## code at life size and grown by `sheep_scale`. The ground is raycast once the level's collision exists (Level's
## wait_for_collisions, as BoostPad and ItemBox wait) into a height grid over the areas and the crossing.
##
## Place it: add a Node3D with this script (a name free of the game's track and soft words: "SheepFlock") anywhere,
## usually at the origin, and set the exports in its LOCAL frame (game metres): the two areas (centre, half extents along
## the area's own x and z, yaw), and the crossing (`cross_from` on A's side of the road, `cross_to` on B's, both a few
## metres off the verges; the flock queues behind cross_from in a column `COLUMN_ROWS` deep and walks straight to and past
## cross_to). The areas' y only matters until the ground is found. Nothing else is needed: no colliders, no saved meshes.
## `clock_offset` shifts this flock's schedule (two flocks apart); `clock_override` (>= 0) drives it by hand (tests).

const CartWeight = preload("res://CartWeight.gd")

## The animals' collision layer: carts don't collide with it, the AI's obstacle rays see it (WildebeestHerd's).
const ANIMAL_LAYER := 1 << 2
## The cart's collision sphere, added to a sheep's half extents for the bump test (game metres).
const CART_REACH := 1.0
const HIT_COOLDOWN := 0.6
## Speed a cart keeps after hitting a sheep (the fleet's middle; CartWeight scales it), its shove aside and hop (m/s).
const HIT_KEEP := 0.86
const HIT_SHOVE := 1.6
const HIT_HOP := 0.9
## A sheep's half extents at life size (x across, y up from its centre at SHEEP_MID, z along).
const SHEEP_HALF := Vector3(0.32, 0.42, 0.68)
const SHEEP_MID := 0.48
## The knock: thrown for KNOCK_FLY seconds, runs on for KNOCK_RUN, stands for KNOCK_PAUSE, trots back over KNOCK_BACK.
const KNOCK_FLY := 0.75
const KNOCK_RUN := 1.6
const KNOCK_PAUSE := 1.0
const KNOCK_BACK := 5.5
## The column the flock crosses in: sheep a row, the gap between rows and between sheep in a row (life metres).
const COLUMN_PER_ROW := 4
const COLUMN_ROW_GAP := 1.45
const COLUMN_COL_GAP := 1.25
## A walking stride (life metres per gait cycle) for each kind.
const STRIDE := [0.95, 0.9, 1.4]
## Seconds subtracted from the wall clock (small numbers keep the periodic functions exact).
const EPOCH := 1.75e9

## Area A, where the flock grazes before an even-numbered crossing: its centre (local), half extents along its own x and z
## (game metres), and its yaw (radians about y).
@export var area_a_centre := Vector3(-45.0, 0.0, 0.0)
@export var area_a_half := Vector2(26.0, 20.0)
@export var area_a_yaw := 0.0
## Area B, on the road's other side.
@export var area_b_centre := Vector3(45.0, 0.0, 0.0)
@export var area_b_half := Vector2(26.0, 20.0)
@export var area_b_yaw := 0.0
## Where the flock bunches before crossing (A's side) and where its last row reaches (B's side): local, game metres.
@export var cross_from := Vector3(-14.0, 0.0, 0.0)
@export var cross_to := Vector3(14.0, 0.0, 0.0)
## Seconds between crossings (A to B, then back).
@export var cross_every := 110.0
## Seconds the dog takes to gather the flock into its column before it walks.
@export var gather_time := 26.0
## The flock's walking speed across the road, life metres a second (grown by sheep_scale in the game).
@export var walk_speed := 1.6
@export var sheep_count := 36
## Life size to the game's (PROP_SCALE).
@export var sheep_scale := 1.6
## The share of black-headed sheep (the rest white-faced).
@export var black_headed_share := 0.6
@export var with_shepherd := true
@export var with_dog := true
## Seconds added to the wall clock for this flock's schedule.
@export var clock_offset := 0.0
## When >= 0, the clock itself (seconds; tests drive the flock with it).
@export var clock_override := -1.0
@export var rng_seed := 7311
## Bleats (one-shots), played when a sheep is hit and now and then while the flock grazes. May be empty.
@export var bleats: Array[AudioStream] = []
@export var bleat_db := 0.0
@export var bleat_unit_size := 14.0
## Seconds between grazing bleats (a random span).
@export var bleat_every := Vector2(4.0, 12.0)
## Past this distance from the camera the flock isn't drawn (or posed); its bodies still move when carts are near.
@export var draw_range := 700.0
## Cells of the ground's height grid, game metres.
@export var ground_step := 2.0

var _n := 0
var _S := 1.6
var _pos := PackedVector3Array()
var _yaw := PackedFloat32Array()
var _phase := PackedFloat32Array()
var _gait := PackedFloat32Array()
var _head := PackedFloat32Array()
var _size := PackedFloat32Array()
var _variant := PackedFloat32Array()
## Grazing loops: (rx, rz, turn) and (rate, step rate, phase), and which way round.
var _loop_r := PackedVector3Array()
var _loop_w := PackedVector3Array()
var _loop_s := PackedFloat32Array()
## When each sheep looks up from the grass, and its nibbling.
var _look := PackedVector3Array()
## The knocks: local time hit (-1: none), direction, distance thrown and run, roll.
var _knock_t0 := PackedFloat32Array()
var _knock_dir := PackedVector3Array()
var _knock_d := PackedVector2Array()
var _knock_roll := PackedFloat32Array()
var _cooldown := {}
## The plan of the current crossing (see _plan()).
var _plan_k := -2147483648
var _plan := {}
var _homes_cache := {}
## The ground: heights over a grid from _g_origin (local x, z), _g_nx by _g_nz cells of ground_step.
var _g_heights := PackedFloat32Array()
var _g_origin := Vector2.ZERO
var _g_nx := 0
var _g_nz := 0
var _g_ready := false
var _bounds := AABB()
var _mm_sheep: MultiMesh
var _mm_dog: MultiMesh
var _mm_man: MultiMesh
var _mmi: Array[MultiMeshInstance3D] = []
var _bodies: Array[AnimatableBody3D] = []
var _bleat_players: Array[AudioStreamPlayer3D] = []
var _bleat_wait := 3.0
var _headless := false
var _buf := PackedFloat32Array()
var _now := 0.0
var _carts_near := false
var _check_wait := 0.0
## Dog and shepherd: position, yaw, gait phase and amplitude, lying.
var _dog := {"pos": Vector3.ZERO, "yaw": 0.0, "phase": 0.0, "gait": 0.0, "lie": 1.0}
var _man := {"pos": Vector3.ZERO, "yaw": 0.0, "phase": 0.0, "gait": 0.0}
## Carts knocked by a sheep since load (tests read it), and the CPU time of the last update (microseconds).
var bump_count := 0
var last_update_usec := 0


func _ready() -> void:
	_S = sheep_scale
	_n = maxi(sheep_count, 1)
	_headless = DisplayServer.get_name() == "headless"
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in range(_n):
		_pos.append(Vector3.ZERO)
		_yaw.append(rng.randf() * TAU)
		_phase.append(rng.randf())
		_gait.append(0.0)
		_head.append(1.0)
		_size.append(rng.randf_range(0.9, 1.08))
		_variant.append(1.0 if rng.randf() < black_headed_share else 0.0)
		_loop_r.append(Vector3(rng.randf_range(1.0, 2.4), rng.randf_range(0.7, 1.6), rng.randf() * TAU) * Vector3(_S, _S, 1.0))
		_loop_w.append(Vector3(rng.randf_range(0.05, 0.09), rng.randf_range(0.28, 0.55), rng.randf() * TAU))
		_loop_s.append(1.0 if rng.randf() < 0.5 else -1.0)
		_look.append(Vector3(rng.randf_range(0.05, 0.11), rng.randf() * TAU, rng.randf() * TAU))
		_knock_t0.append(-1.0)
		_knock_dir.append(Vector3.ZERO)
		_knock_d.append(Vector2.ZERO)
		_knock_roll.append(0.0)
	_bounds = _compute_bounds()
	_build_bodies()
	if not _headless:
		_build_visuals()
		_build_audio()
	_update(0.0)
	_find_ground()


# ======================================================================================
#  The schedule
# ======================================================================================

## Seconds on a clock every machine shares (less EPOCH), shifted by clock_offset.
func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return Time.get_unix_time_from_system() - EPOCH + clock_offset


## A point in an area: (u, v) -1..1 across its half extents.
func _area_point(b: bool, u: float, v: float) -> Vector3:
	var c: Vector3 = area_b_centre if b else area_a_centre
	var h: Vector2 = area_b_half if b else area_a_half
	var yaw: float = area_b_yaw if b else area_a_yaw
	return c + Basis(Vector3.UP, yaw) * Vector3(u * h.x, 0.0, v * h.y)


## Where every sheep grazes after crossing k (in B after an even k, in A after an odd one): a few loose groups.
func _homes(k: int) -> PackedVector3Array:
	if _homes_cache.has(k):
		return _homes_cache[k]
	var b: bool = posmod(k, 2) == 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rng_seed, k])
	var groups: Array = []
	var ng: int = rng.randi_range(3, 5)
	for g in range(ng):
		groups.append(Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5)))
	var h: Vector2 = area_b_half if b else area_a_half
	var margin := Vector2(clampf(3.0 * _S / maxf(h.x, 0.1), 0.0, 0.5), clampf(3.0 * _S / maxf(h.y, 0.1), 0.0, 0.5))
	var out := PackedVector3Array()
	for i in range(_n):
		var best := Vector3.ZERO
		var best_d := -1.0
		for attempt in range(8):
			var g: Vector2 = groups[(i + attempt * 7) % ng] if attempt < 4 else groups[i % ng]
			var uv := Vector2(g.x + rng.randfn() * 0.22, g.y + rng.randfn() * 0.22)
			uv = Vector2(clampf(uv.x, -1.0 + margin.x, 1.0 - margin.x), clampf(uv.y, -1.0 + margin.y, 1.0 - margin.y))
			var p: Vector3 = _area_point(b, uv.x, uv.y)
			var nearest := 1e9
			for q in out:
				nearest = minf(nearest, Vector2(q.x - p.x, q.z - p.z).length())
			if nearest > best_d:
				best_d = nearest
				best = p
			if nearest > 2.4 * _S:
				break
		out.append(best)
	_homes_cache[k] = out
	if _homes_cache.size() > 6:
		_homes_cache.erase(_homes_cache.keys().min())
	return out


## A grazing sheep's offset from its home at time t: a small loop walked in steps (it stops, grazes, steps on).
func _loop(i: int, t: float) -> Vector3:
	var r: Vector3 = _loop_r[i]
	var w: Vector3 = _loop_w[i]
	var x: float = w.y * t + w.z
	# theta' = rate (2/3)(1 - cos x)^2: never backwards, pausing where cos x is near 1.
	var th: float = _loop_s[i] * (w.x / w.y) * (2.0 / 3.0) * (1.5 * x - 2.0 * sin(x) + 0.25 * sin(2.0 * x))
	var e := Vector3(r.x * cos(th), 0.0, r.y * sin(th))
	return Basis(Vector3.UP, r.z) * e


## The plan of crossing k: for each sheep where it starts, queues, crosses to and settles, and when.
func _get_plan(k: int) -> Dictionary:
	if k == _plan_k:
		return _plan
	var to_b: bool = posmod(k, 2) == 0
	var cs: Vector3 = cross_from if to_b else cross_to
	var ce: Vector3 = cross_to if to_b else cross_from
	var fdir := Vector3(ce.x - cs.x, 0.0, ce.z - cs.z)
	if fdir.length_squared() < 1e-4:
		fdir = Vector3.FORWARD
	fdir = fdir.normalized()
	var side := Vector3(-fdir.z, 0.0, fdir.x)
	var src: PackedVector3Array = _homes(k - 1)
	var dst: PackedVector3Array = _homes(k)
	var t_k: float = float(k) * cross_every
	var vw: float = walk_speed * _S
	var rows: int = int(ceil(float(_n) / float(COLUMN_PER_ROW)))
	var row_gap: float = COLUMN_ROW_GAP * _S
	var col_gap: float = COLUMN_COL_GAP * _S
	var col_len: float = float(rows - 1) * row_gap
	var dvec: Vector3 = (ce - cs) + fdir * col_len
	dvec.y = 0.0
	# Slots: the sheep nearest the road take the front rows, each row ordered across.
	var order: Array = range(_n)
	order.sort_custom(func(a: int, b: int) -> bool: return src[a].dot(fdir) > src[b].dot(fdir))
	var slot := PackedInt32Array()
	slot.resize(_n)
	var j := 0
	while j < _n:
		var row_ids: Array = order.slice(j, mini(j + COLUMN_PER_ROW, _n))
		row_ids.sort_custom(func(a: int, b: int) -> bool: return src[a].dot(side) < src[b].dot(side))
		for c in range(row_ids.size()):
			slot[row_ids[c]] = j + c
		j += COLUMN_PER_ROW
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rng_seed, k, 99])
	var p0 := PackedVector3Array()
	var p1 := PackedVector3Array()
	var p3 := PackedVector3Array()
	var ts := PackedFloat32Array()
	var t2 := PackedFloat32Array()
	var t3 := PackedFloat32Array()
	var tg: float = gather_time
	var centroid := Vector3.ZERO
	var spread := 0.0
	for q in src:
		centroid += q
	centroid /= float(_n)
	for q in src:
		spread = maxf(spread, Vector2(q.x - centroid.x, q.z - centroid.z).length())
	for i in range(_n):
		var sl: int = slot[i]
		var row: int = sl / COLUMN_PER_ROW
		var col: int = sl % COLUMN_PER_ROW
		var off: Vector3 = -fdir * (float(row) * row_gap) + side * ((float(col) - float(COLUMN_PER_ROW - 1) * 0.5) * col_gap + (float(row % 2) - 0.5) * col_gap * 0.35)
		off += Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15)) * _S
		var q1: Vector3 = cs + off
		var hs: Vector3 = src[i]
		var d: float = Vector2(q1.x - hs.x, q1.z - hs.z).length()
		var vg: float = maxf(vw * 0.8, d / tg * 1.05)
		var t0: float = maxf(0.0, tg - d / vg)
		var q0: Vector3 = hs + _loop(i, t_k + t0)
		var v_c: float = vw * (1.0 + 0.08 * (1.0 - float(row) / float(maxi(rows - 1, 1))))
		var a2: float = tg + dvec.length() / v_c
		var hd: Vector3 = dst[i]
		var q2: Vector3 = q1 + dvec
		var a3: float = a2 + Vector2(hd.x - q2.x, hd.z - q2.z).length() / (vw * 0.85)
		p0.append(q0)
		p1.append(q1)
		p3.append(hd + _loop(i, t_k + a3))
		ts.append(t0)
		t2.append(a2)
		t3.append(a3)
	_plan_k = k
	# The shepherd's posts beside the crossing, on the same side of it both ways (so he and the dog carry on from one
	# crossing to the next where they stopped).
	var f_ab := Vector3(cross_to.x - cross_from.x, 0.0, cross_to.z - cross_from.z).normalized()
	var s_ab := Vector3(-f_ab.z, 0.0, f_ab.x)
	var w_a: Vector3 = cross_from - f_ab * 5.0 * _S + s_ab * 7.0 * _S
	var w_b: Vector3 = cross_to + f_ab * 5.0 * _S + s_ab * 7.0 * _S
	var w_src: Vector3 = w_a if to_b else w_b
	var w_dst: Vector3 = w_b if to_b else w_a
	_plan = {"src": src, "dst": dst, "p0": p0, "p1": p1, "p3": p3, "ts": ts, "t2": t2, "t3": t3, "dvec": dvec, "fdir": fdir, "side": side,
			"cs": cs, "ce": ce, "t_k": t_k, "col_len": col_len, "v_front": vw * 1.08, "v_rear": vw, "centroid": centroid, "spread": spread,
			"w_src": w_src, "w_dst": w_dst, "s_ab": s_ab}
	return _plan


## Sheep i's place (local, ground height not yet set) at clock t, how it moves (0 grazing, 1 walking) and its head.
func _sheep_at(i: int, t: float, pl: Dictionary, tau: float) -> Vector3:
	var ts: float = pl["ts"][i]
	if tau < ts:
		return (pl["src"][i] as Vector3) + _loop(i, t)
	var tg: float = gather_time
	if tau < tg:
		var s: float = (tau - ts) / maxf(tg - ts, 0.01)
		s = s * s * (3.0 - 2.0 * s) * 0.35 + s * 0.65
		return (pl["p0"][i] as Vector3).lerp(pl["p1"][i], s)
	var t2: float = pl["t2"][i]
	if tau < t2:
		return (pl["p1"][i] as Vector3) + (pl["dvec"] as Vector3) * ((tau - tg) / maxf(t2 - tg, 0.01))
	var t3: float = pl["t3"][i]
	if tau < t3:
		var s3: float = (tau - t2) / maxf(t3 - t2, 0.01)
		return ((pl["p1"][i] as Vector3) + (pl["dvec"] as Vector3)).lerp(pl["p3"][i], s3)
	return (pl["dst"][i] as Vector3) + _loop(i, t)


## The shepherd's place: at his post by the source side, walking ahead of the column across, then to the far post.
func _man_at(pl: Dictionary, tau: float) -> Vector3:
	var tg: float = gather_time
	var fdir: Vector3 = pl["fdir"]
	var side: Vector3 = pl["side"]
	var lead: Vector3 = (pl["cs"] as Vector3) + fdir * 4.0 * _S + side * 2.5 * _S
	var dvec: Vector3 = pl["dvec"]
	var t_front: float = tg + dvec.length() / float(pl["v_front"])
	if tau < tg - 12.0:
		return pl["w_src"]
	if tau < tg:
		return (pl["w_src"] as Vector3).lerp(lead, smoothstep(tg - 12.0, tg, tau))
	if tau < t_front:
		return lead + dvec * ((tau - tg) / (t_front - tg))
	var end: Vector3 = lead + dvec
	var d: float = end.distance_to(pl["w_dst"])
	var t_back: float = d / (1.1 * _S)
	return end.lerp(pl["w_dst"], clampf((tau - t_front) / maxf(t_back, 0.01), 0.0, 1.0))


## The dog's place: lying by the shepherd, then an outrun round the flock to behind it, working it into the column and
## following its last row across, then back to the shepherd. Returns (place, lying 0..1).
func _dog_at(pl: Dictionary, tau: float) -> Array:
	var tg: float = gather_time
	var fdir: Vector3 = pl["fdir"]
	var side: Vector3 = pl["side"]
	var lie_src: Vector3 = (pl["w_src"] as Vector3) - (pl["s_ab"] as Vector3) * 2.0 * _S
	var lie_dst: Vector3 = (pl["w_dst"] as Vector3) - (pl["s_ab"] as Vector3) * 2.0 * _S
	var c: Vector3 = pl["centroid"]
	var r: float = float(pl["spread"]) + 6.0 * _S
	var flank: Vector3 = c + side * r
	var behind: Vector3 = c - fdir * r
	var t_out: float = tg * 0.3
	var rear: Vector3 = (pl["cs"] as Vector3) - fdir * (float(pl["col_len"]) + 5.0 * _S)
	var dvec: Vector3 = pl["dvec"]
	var t_rear: float = tg + dvec.length() / float(pl["v_rear"])
	if tau < 0.0:
		return [lie_src, 1.0]
	if tau < t_out:
		var s: float = tau / t_out
		var p: Vector3 = lie_src.lerp(flank, clampf(s * 2.0, 0.0, 1.0)) if s < 0.5 else flank.lerp(behind, (s - 0.5) * 2.0)
		return [p, 0.0]
	if tau < tg:
		var s2: float = (tau - t_out) / (tg - t_out)
		return [behind.lerp(rear, s2 * s2 * (3.0 - 2.0 * s2)) + side * (sin(tau * 0.7) * 5.0 * _S * (1.0 - s2 * 0.6)), 0.0]
	if tau < t_rear:
		var s3: float = (tau - tg) / (t_rear - tg)
		return [rear + dvec * s3 + side * (sin(tau * 0.9) * 3.0 * _S), 0.0]
	var end: Vector3 = rear + dvec
	var t_back: float = end.distance_to(lie_dst) / (2.6 * _S)
	var s4: float = clampf((tau - t_rear) / maxf(t_back, 0.01), 0.0, 1.0)
	return [end.lerp(lie_dst, s4), smoothstep(0.95, 1.0, s4) if tau - t_rear < t_back + 2.0 else 1.0]


# ======================================================================================
#  The ground
# ======================================================================================

func _compute_bounds() -> AABB:
	var pts: Array = [cross_from, cross_to]
	for b in [false, true]:
		for u in [-1.0, 1.0]:
			for v in [-1.0, 1.0]:
				pts.append(_area_point(b, u, v))
	var box := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		box = box.expand(p)
	# Room round it: the column queues behind the crossing, the dog runs round the flock.
	var m: float = float(int(ceil(float(maxi(sheep_count, 1)) / float(COLUMN_PER_ROW)))) * COLUMN_ROW_GAP * sheep_scale + 14.0 * sheep_scale
	return box.grow(m)


func _find_ground() -> void:
	# In a level generator (regenerate_*.gd) the level is packed and the tree quits: nothing to find.
	var cur: Node = get_tree().current_scene
	if cur and String(cur.name).to_lower().contains("regenerate"):
		return
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	var level: Node = get_parent()
	while level and not level.is_in_group("level"):
		level = level.get_parent()
	if level and level.has_method("wait_for_collisions"):
		await level.wait_for_collisions()
	for i in 3:
		await get_tree().physics_frame
	if not is_inside_tree():
		return
	var step: float = maxf(ground_step, 0.5)
	_g_origin = Vector2(_bounds.position.x, _bounds.position.z)
	_g_nx = int(ceil(_bounds.size.x / step)) + 1
	_g_nz = int(ceil(_bounds.size.z / step)) + 1
	var heights := PackedFloat32Array()
	heights.resize(_g_nx * _g_nz)
	heights.fill(NAN)
	var space := get_world_3d().direct_space_state
	var top: float = _bounds.end.y + 200.0
	var bot: float = _bounds.position.y - 200.0
	var done := 0
	for iz in range(_g_nz):
		for ix in range(_g_nx):
			var lx: float = _g_origin.x + float(ix) * step + 0.013
			var lz: float = _g_origin.y + float(iz) * step + 0.017
			heights[iz * _g_nx + ix] = _ray_ground(space, lx, lz, top, bot)
			done += 1
			if done % 500 == 0:
				await get_tree().physics_frame
				if not is_inside_tree():
					return
	# Fill holes from their neighbours (or the areas' height).
	var fallback: float = (area_a_centre.y + area_b_centre.y) * 0.5
	for k in range(heights.size()):
		if is_nan(heights[k]):
			var found := false
			for r in range(1, 6):
				var ix2: int = k % _g_nx
				var iz2: int = k / _g_nx
				for dz in range(-r, r + 1):
					for dx in range(-r, r + 1):
						var x2: int = ix2 + dx
						var z2: int = iz2 + dz
						if x2 >= 0 and z2 >= 0 and x2 < _g_nx and z2 < _g_nz and not is_nan(heights[z2 * _g_nx + x2]):
							heights[k] = heights[z2 * _g_nx + x2]
							found = true
							break
					if found:
						break
				if found:
					break
			if not found:
				heights[k] = fallback
	_g_heights = heights
	_g_ready = true


## The ground's height (local) under (lx, lz): the lowest level-ish surface a ray down meets, so a fence or a prop on the
## meadow isn't taken for the ground.
func _ray_ground(space: PhysicsDirectSpaceState3D, lx: float, lz: float, top: float, bot: float) -> float:
	var from: Vector3 = to_global(Vector3(lx, top, lz))
	var to: Vector3 = to_global(Vector3(lx, bot, lz))
	var exclude: Array[RID] = []
	var best := NAN
	for attempt in range(4):
		var q := PhysicsRayQueryParameters3D.create(from, to, 1, exclude)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var lp: Vector3 = to_local(hit["position"])
		if (hit["normal"] as Vector3).y > 0.55:
			best = lp.y
		exclude.append(hit["rid"])
	return best


func _ground(lx: float, lz: float) -> float:
	if not _g_ready:
		return area_a_centre.y
	var step: float = maxf(ground_step, 0.5)
	var fx: float = clampf((lx - _g_origin.x) / step, 0.0, float(_g_nx - 1) - 0.001)
	var fz: float = clampf((lz - _g_origin.y) / step, 0.0, float(_g_nz - 1) - 0.001)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	var o: int = iz * _g_nx + ix
	return lerpf(lerpf(_g_heights[o], _g_heights[o + 1], tx), lerpf(_g_heights[o + _g_nx], _g_heights[o + _g_nx + 1], tx), tz)


# ======================================================================================
#  The update
# ======================================================================================

func _process(delta: float) -> void:
	_update(delta)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_check_wait -= _delta
	if _check_wait <= 0.0:
		_check_wait = 0.25
		_carts_near = _any_cart_near()
	if _carts_near:
		for i in range(_bodies.size()):
			_bodies[i].transform = Transform3D(Basis(Vector3.UP, _yaw[i]), _pos[i])
		_check_carts()


func _any_cart_near() -> bool:
	var reach: AABB = _bounds.grow(150.0)
	for node in get_tree().get_nodes_in_group("player_carts"):
		var cart := node as Node3D
		if cart and is_instance_valid(cart) and reach.has_point(to_local(cart.global_position)):
			return true
	return false


func _camera_near() -> bool:
	if _headless:
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	var cam := vp.get_camera_3d()
	if cam == null:
		return true
	var c: Vector3 = to_local(cam.global_position)
	var d: float = _bounds.grow(-0.0).get_center().distance_to(c) - _bounds.size.length() * 0.5
	return d < draw_range


func _update(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_now += delta
	var visible_now: bool = _camera_near()
	for m in _mmi:
		m.visible = visible_now
	if not visible_now and not _carts_near and delta > 0.0:
		last_update_usec = Time.get_ticks_usec() - t0
		return
	var t: float = _clock()
	var k: int = floori(t / cross_every)
	var tau: float = t - float(k) * cross_every
	var pl: Dictionary = _get_plan(k)
	var tg: float = gather_time
	var stride: float = float(STRIDE[0]) * _S
	var blend: float = 1.0 - exp(-delta * 5.0)
	var flock_c := Vector3.ZERO
	var buf_on: bool = visible_now and _mm_sheep != null
	if buf_on and _buf.size() != _n * 16:
		_buf.resize(_n * 16)
	for i in range(_n):
		var p: Vector3 = _sheep_at(i, t, pl, tau)
		var walking: bool = tau >= float(pl["ts"][i]) and tau < float(pl["t3"][i])
		var hop := 0.0
		var roll := 0.0
		var knocked := false
		var kt: float = _knock_t0[i]
		if kt >= 0.0:
			var u: float = _now - kt
			var kd: Vector2 = _knock_d[i]
			var dir: Vector3 = _knock_dir[i]
			var off := Vector3.ZERO
			if u < KNOCK_FLY:
				var s: float = u / KNOCK_FLY
				off = dir * kd.x * (1.0 - (1.0 - s) * (1.0 - s))
				hop = 4.0 * 0.7 * _S * s * (1.0 - s)
				roll = _knock_roll[i] * smoothstep(0.0, 1.0, s)
			elif u < KNOCK_FLY + KNOCK_RUN:
				var s2: float = (u - KNOCK_FLY) / KNOCK_RUN
				off = dir * (kd.x + kd.y * (1.0 - (1.0 - s2) * (1.0 - s2)))
			elif u < KNOCK_FLY + KNOCK_RUN + KNOCK_PAUSE:
				off = dir * (kd.x + kd.y)
			elif u < KNOCK_FLY + KNOCK_RUN + KNOCK_PAUSE + KNOCK_BACK:
				var s3: float = (u - KNOCK_FLY - KNOCK_RUN - KNOCK_PAUSE) / KNOCK_BACK
				off = dir * (kd.x + kd.y) * (1.0 - smoothstep(0.0, 1.0, s3))
			else:
				_knock_t0[i] = -1.0
			p += off
			knocked = true
		p.y = _ground(p.x, p.z)
		var prev: Vector3 = _pos[i]
		var mv := Vector3(p.x - prev.x, 0.0, p.z - prev.z)
		var dist: float = mv.length()
		var speed: float = dist / maxf(delta, 0.001) if delta > 0.0 else 0.0
		_pos[i] = p
		# Face the way it moves (turning smoothly), legs keeping pace with the ground covered.
		if dist > 0.002 and not (knocked and _now - kt < KNOCK_FLY):
			var target: float = atan2(-mv.x, -mv.z)
			var turn: float = 1.0 - exp(-delta * (4.0 if speed > 0.6 else 1.6))
			_yaw[i] = lerp_angle(_yaw[i], target, turn)
		_phase[i] = fmod(_phase[i] + dist / stride, 1.0)
		var amp_t: float = clampf(speed / (0.55 * _S), 0.0, 1.0)
		_gait[i] = lerpf(_gait[i], amp_t, blend)
		flock_c += p
		# The head: down while grazing (nibbling, now and then looking up), up while walking or knocked.
		var lk: Vector3 = _look[i]
		var head: float = 0.12
		if not walking and not knocked:
			var up: float = smoothstep(0.8, 0.95, sin(t * lk.x + lk.y))
			head = clampf(1.0 - up - 0.55 * amp_t, 0.0, 1.0) - 0.06 * (0.5 + 0.5 * sin(t * 6.5 + lk.z))
		_head[i] = lerpf(_head[i], clampf(head, 0.0, 1.0), blend)
		if buf_on:
			var yaw: float = _yaw[i]
			var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var pitch: float = 0.0
			if _g_ready:
				var ahead: float = _ground(p.x + fwd.x * 0.6 * _S, p.z + fwd.z * 0.6 * _S)
				var back: float = _ground(p.x - fwd.x * 0.6 * _S, p.z - fwd.z * 0.6 * _S)
				pitch = atan2(ahead - back, 1.2 * _S)
			var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
			if roll != 0.0:
				basis = basis * Basis(Vector3.BACK, roll)
			basis = basis.scaled(Vector3.ONE * _S * _size[i])
			var origin: Vector3 = p + Vector3(0.0, hop + (SHEEP_MID * _S * absf(sin(roll)) * 0.9 if roll != 0.0 else 0.0), 0.0)
			var o: int = i * 16
			_buf[o] = basis.x.x
			_buf[o + 1] = basis.y.x
			_buf[o + 2] = basis.z.x
			_buf[o + 3] = origin.x
			_buf[o + 4] = basis.x.y
			_buf[o + 5] = basis.y.y
			_buf[o + 6] = basis.z.y
			_buf[o + 7] = origin.y
			_buf[o + 8] = basis.x.z
			_buf[o + 9] = basis.y.z
			_buf[o + 10] = basis.z.z
			_buf[o + 11] = origin.z
			_buf[o + 12] = _phase[i]
			_buf[o + 13] = _gait[i]
			_buf[o + 14] = 0.0 if knocked else _head[i]
			_buf[o + 15] = _variant[i]
	if buf_on:
		_mm_sheep.buffer = _buf
	flock_c /= float(_n)
	if with_shepherd:
		_update_figure(_man, _man_at(pl, tau), 0.0, delta, 2, _mm_man if visible_now else null, flock_c)
	if with_dog:
		var dg: Array = _dog_at(pl, tau)
		_update_figure(_dog, dg[0], dg[1], delta, 1, _mm_dog if visible_now else null, flock_c)
	if visible_now and not _bleat_players.is_empty() and delta > 0.0:
		_bleat_wait -= delta
		if _bleat_wait <= 0.0:
			_bleat_wait = randf_range(bleat_every.x, bleat_every.y)
			_bleat(_pos[randi() % _n])
	last_update_usec = Time.get_ticks_usec() - t0


## The dog or the shepherd: placed on the ground, turned the way it goes, its gait from the ground covered.
func _update_figure(f: Dictionary, p: Vector3, lie: float, delta: float, kind: int, mm: MultiMesh, flock_c: Vector3) -> void:
	p.y = _ground(p.x, p.z)
	var prev: Vector3 = f["pos"]
	var mv := Vector3(p.x - prev.x, 0.0, p.z - prev.z)
	var dist: float = mv.length()
	var speed: float = dist / maxf(delta, 0.001) if delta > 0.0 else 0.0
	f["pos"] = p
	if dist > 0.003:
		f["yaw"] = lerp_angle(float(f["yaw"]), atan2(-mv.x, -mv.z), 1.0 - exp(-delta * 5.0))
	elif delta > 0.0 and speed < 0.05:
		# Standing or lying: face the flock.
		var to: Vector3 = flock_c - p
		if to.length() > 1.0:
			f["yaw"] = lerp_angle(float(f["yaw"]), atan2(-to.x, -to.z), 1.0 - exp(-delta * 0.8))
	var stride: float = float(STRIDE[kind]) * _S
	f["phase"] = fmod(float(f["phase"]) + dist / stride, 1.0)
	f["gait"] = lerpf(float(f["gait"]), clampf(speed / ((0.6 if kind == 2 else 0.8) * _S), 0.0, 1.0), 1.0 - exp(-delta * 5.0))
	if kind == 1:
		f["lie"] = lerpf(float(f["lie"]), lie, 1.0 - exp(-delta * 3.0))
	if mm == null:
		return
	var basis: Basis = Basis(Vector3.UP, float(f["yaw"])).scaled(Vector3.ONE * _S)
	var origin: Vector3 = p
	if kind == 1:
		origin.y -= 0.27 * _S * float(f["lie"])
	var b := PackedFloat32Array([basis.x.x, basis.y.x, basis.z.x, origin.x, basis.x.y, basis.y.y, basis.z.y, origin.y, basis.x.z, basis.y.z, basis.z.z, origin.z,
			float(f["phase"]), float(f["gait"]), float(f.get("lie", 0.0)), 0.0])
	mm.buffer = b


# ======================================================================================
#  Carts
# ======================================================================================

func _check_carts() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var box: AABB = _flock_box().grow(CART_REACH + 2.0 * _S)
	var hw: float = SHEEP_HALF.x * _S + CART_REACH
	var hl: float = SHEEP_HALF.z * _S + CART_REACH
	var hh: float = SHEEP_HALF.y * _S + 1.0
	for node in get_tree().get_nodes_in_group("player_carts"):
		var cart := node as RigidBody3D
		if cart == null or not is_instance_valid(cart):
			continue
		if cart.has_method("has_physics_authority") and not cart.has_physics_authority():
			continue
		var cp: Vector3 = to_local(cart.global_position)
		if not box.has_point(cp):
			continue
		var id: int = cart.get_instance_id()
		if now < float(_cooldown.get(id, 0.0)):
			continue
		for i in range(_n):
			if _knock_t0[i] >= 0.0 and _now - _knock_t0[i] < KNOCK_FLY + 0.4:
				continue
			var d: Vector3 = cp - _pos[i]
			if absf(d.x) > hl + 1.0 or absf(d.z) > hl + 1.0:
				continue
			var lcl: Vector3 = Basis(Vector3.UP, -_yaw[i]) * d
			var dy: float = d.y - SHEEP_MID * _S
			if absf(lcl.x) > hw or absf(lcl.z) > hl or dy < -hh or dy > hh:
				continue
			_bump(cart, i)
			_cooldown[id] = now + HIT_COOLDOWN
			break


## The box round the flock as it stands now (local).
func _flock_box() -> AABB:
	var box := AABB(_pos[0], Vector3.ZERO)
	for p in _pos:
		box = box.expand(p)
	return box


func _bump(cart: RigidBody3D, i: int) -> void:
	var v: Vector3 = cart.linear_velocity
	var hv := Vector3(v.x, 0.0, v.z)
	var speed: float = hv.length()
	var lv: Vector3 = global_transform.basis.inverse() * hv
	var away: Vector3 = _pos[i] - to_local(cart.global_position)
	away.y = 0.0
	away = away.normalized() if away.length_squared() > 1e-4 else Vector3.FORWARD
	var dir: Vector3 = (Vector3(lv.x, 0.0, lv.z).normalized() * 0.75 + away * 0.6)
	dir = dir.normalized() if dir.length_squared() > 1e-4 else away
	var push: float = CartWeight.push_share(cart)
	_knock_t0[i] = _now
	_knock_dir[i] = dir
	_knock_d[i] = Vector2(clampf(speed * 0.12, 1.5, 4.5) * _S * push, 3.5 * _S)
	var side: float = signf(Vector3(-dir.z, 0.0, dir.x).dot(away) + 0.01)
	_knock_roll[i] = side * TAU * clampf(speed / 20.0, 0.25, 1.0)
	# The cart: most of its speed kept, nudged off the sheep and lifted a little (a heavy car ploughs on).
	var loss: float = CartWeight.loss_share(cart)
	# Nudged aside (across its own travel, away from the sheep), not back.
	var travel: Vector3 = Vector3(lv.x, 0.0, lv.z).normalized() if lv.length_squared() > 1e-4 else Vector3.ZERO
	var aside: Vector3 = -away - travel * (-away).dot(travel)
	aside = aside.normalized() if aside.length_squared() > 1e-4 else Vector3(-travel.z, 0.0, travel.x)
	var shove: Vector3 = global_transform.basis * aside * HIT_SHOVE * loss
	cart.linear_velocity = hv * CartWeight.keep(cart, HIT_KEEP) + Vector3(shove.x, 0.0, shove.z) + Vector3.UP * (v.y + HIT_HOP * loss)
	bump_count += 1
	_bleat(_pos[i])


# ======================================================================================
#  Bodies, meshes, sound
# ======================================================================================

func _build_bodies() -> void:
	var shape := BoxShape3D.new()
	shape.size = Vector3(SHEEP_HALF.x * 2.0, SHEEP_HALF.y * 2.0, SHEEP_HALF.z * 2.0) * _S
	for i in range(_n):
		var b := AnimatableBody3D.new()
		b.sync_to_physics = false
		b.collision_layer = ANIMAL_LAYER
		b.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(0, SHEEP_MID * _S, 0)
		b.add_child(cs)
		add_child(b, false, Node.INTERNAL_MODE_BACK)
		_bodies.append(b)


func _build_visuals() -> void:
	var shader: Shader = load("res://sheep_flock.gdshader")
	var defs: Array = [
		[sheep_mesh(), 0, _n, PackedFloat32Array([0, 0, 0.25, 0.75, 0.0, 0.5, 0, 0]), PackedFloat32Array([0, 0, 0.42, 0.42, 0.42, 0.42, 0, 0])],
		[dog_mesh(), 1, 1 if with_dog else 0, PackedFloat32Array([0, 0, 0.0, 0.5, 0.5, 0.0, 0, 0]), PackedFloat32Array([0, 0, 0.6, 0.6, 0.6, 0.6, 0, 0])],
		[shepherd_mesh(), 2, 1 if with_shepherd else 0, PackedFloat32Array([0, 0, 0.0, 0.5, 0.5, 0, 0, 0]), PackedFloat32Array([0, 0, 0.42, 0.42, 0.32, 0, 0, 0])],
	]
	for d in defs:
		var count: int = d[2]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = d[0]
		mm.instance_count = count
		mm.custom_aabb = _bounds.grow(8.0 * _S)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("kind", d[1])
		mat.set_shader_parameter("part_phase", d[3])
		mat.set_shader_parameter("part_amp", d[4])
		(d[0] as ArrayMesh).surface_set_material(0, mat)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = ["Sheep", "Dog", "Shepherd"][int(d[1])]
		mmi.multimesh = mm
		# DressingColliders gives MultiMeshes trunks or boxes at race time: not these, which move.
		mmi.set_meta(&"skip_dressing_colliders", true)
		add_child(mmi, false, Node.INTERNAL_MODE_BACK)
		_mmi.append(mmi)
		match int(d[1]):
			0:
				_mm_sheep = mm
			1:
				_mm_dog = mm if count > 0 else null
			2:
				_mm_man = mm if count > 0 else null


func _build_audio() -> void:
	if bleats.is_empty():
		return
	for k in range(3):
		var ap := AudioStreamPlayer3D.new()
		ap.bus = &"SFX"
		ap.volume_db = bleat_db
		ap.unit_size = bleat_unit_size
		ap.max_distance = bleat_unit_size * 14.0
		add_child(ap, false, Node.INTERNAL_MODE_BACK)
		_bleat_players.append(ap)


func _bleat(at: Vector3) -> void:
	if _bleat_players.is_empty():
		return
	var ap: AudioStreamPlayer3D = _bleat_players[0]
	for p in _bleat_players:
		if not p.playing:
			ap = p
			break
	ap.stream = bleats[randi() % bleats.size()]
	ap.pitch_scale = randf_range(0.88, 1.16)
	ap.position = at + Vector3(0, 0.8 * _S, 0)
	ap.play()


# ======================================================================================
#  The meshes (life size, front toward -z, feet on y = 0): see sheep_flock.gdshader for the vertex data
# ======================================================================================

class _MB:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()

	func _v(p: Vector3, n: Vector3, c: Color, part: int, region: int, piv: Vector2) -> int:
		pos.append(p)
		nrm.append(n.normalized())
		col.append(c)
		uv.append(Vector2(part, region))
		uv2.append(piv)
		return pos.size() - 1

	## A triangle wound to face `out` (Godot's front faces are clockwise: normal (c - a) x (b - a)).
	func tri(a: int, b: int, c: int, out: Vector3) -> void:
		if (pos[c] - pos[a]).cross(pos[b] - pos[a]).dot(out) < 0.0:
			idx.append_array([a, c, b])
		else:
			idx.append_array([a, b, c])

	## An ellipsoid at c with radii r, its axes turned by `bs`, `nu` round and `nv` from pole to pole; `lump` puts wool's
	## bumps on it; `squash` (0..1) flattens its underside.
	func ellipsoid(c: Vector3, r: Vector3, nu: int, nv: int, colr: Color, part: int, region: int, piv: Vector2, bs := Basis(), lump := 0.0,
			seed_v := 0.0, belly_dark := 0.0) -> void:
		var base: int = pos.size()
		for j in range(nv + 1):
			var th: float = PI * float(j) / float(nv)
			for i in range(nu):
				var ph: float = TAU * float(i) / float(nu)
				var d := Vector3(sin(th) * cos(ph), sin(th) * sin(ph), cos(th))
				var l: float = 1.0 + lump * (sin(ph * 5.0 + th * 3.0 + seed_v) * 0.6 + sin(ph * 3.0 - th * 5.0 + seed_v * 2.0) * 0.4) * sin(th)
				var lp := Vector3(d.x * r.x, d.y * r.y, d.z * r.z) * l
				var p: Vector3 = c + bs * lp
				var n: Vector3 = bs * Vector3(d.x / r.x, d.y / r.y, d.z / r.z)
				var cc: Color = colr
				if belly_dark > 0.0:
					cc = colr.darkened(belly_dark * clampf(-d.y, 0.0, 1.0))
				_v(p, n, cc, part, region, piv)
		for j in range(nv):
			for i in range(nu):
				var a: int = base + j * nu + i
				var b: int = base + j * nu + (i + 1) % nu
				var c2: int = base + (j + 1) * nu + (i + 1) % nu
				var d2: int = base + (j + 1) * nu + i
				var out: Vector3 = (pos[a] + pos[c2]) * 0.5 - c
				if j > 0:
					tri(a, b, c2, out)
				if j < nv - 1:
					tri(a, c2, d2, out)

	## A tube from a to b (radii ra, rb), `n` sides, a cap at b if `cap_b`.
	func tube(a: Vector3, b: Vector3, ra: float, rb: float, n: int, colr: Color, part: int, region: int, piv: Vector2, cap_b := true, cap_a := false) -> void:
		var ax: Vector3 = (b - a).normalized()
		var s: Vector3 = ax.cross(Vector3.UP if absf(ax.y) < 0.95 else Vector3.RIGHT).normalized()
		var u: Vector3 = s.cross(ax).normalized()
		var base: int = pos.size()
		for e in range(2):
			var c: Vector3 = a if e == 0 else b
			var r: float = ra if e == 0 else rb
			for i in range(n):
				var t: float = TAU * float(i) / float(n)
				var d: Vector3 = s * cos(t) + u * sin(t)
				_v(c + d * r, d, colr, part, region, piv)
		for i in range(n):
			var i0: int = base + i
			var i1: int = base + (i + 1) % n
			var j0: int = base + n + i
			var j1: int = base + n + (i + 1) % n
			var out: Vector3 = (pos[i0] + pos[j1]) * 0.5 - (a + b) * 0.5
			tri(i0, i1, j1, out)
			tri(i0, j1, j0, out)
		for e in [[cap_b, b, ax, n], [cap_a, a, -ax, 0]]:
			if not e[0]:
				continue
			var cc: int = _v(e[1], e[2], colr, part, region, piv)
			for i in range(n):
				tri(cc, base + int(e[3]) + i, base + int(e[3]) + (i + 1) % n, e[2])

	func commit() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


static var _sheep_mesh: ArrayMesh
static var _dog_mesh: ArrayMesh
static var _man_mesh: ArrayMesh


## A sheep at life size: 1.35m long, its back 0.82m up; a woolly body, a head and neck that lower to graze (part 1), four
## legs (2-5) and a short tail (6); the face, ears and legs in the variant's colour, about 580 triangles.
static func sheep_mesh() -> ArrayMesh:
	if _sheep_mesh:
		return _sheep_mesh
	var mb := _MB.new()
	var white := Color(1, 1, 1)
	# The body: a full, lumpy ellipsoid, the belly's wool a little dirtier.
	mb.ellipsoid(Vector3(0, 0.59, 0.03), Vector3(0.31, 0.26, 0.57), 12, 8, white, 0, 0, Vector2.ZERO, Basis(), 0.085, 1.3, 0.35)
	# Neck and head (part 1), pivoting low inside the chest so the muzzle reaches the grass.
	var piv := Vector2(0.62, -0.38)
	mb.tube(Vector3(0, 0.62, -0.36), Vector3(0, 0.79, -0.6), 0.14, 0.1, 8, white, 1, 0, piv, false)
	var hb := Basis(Vector3.RIGHT, deg_to_rad(28.0))
	mb.ellipsoid(Vector3(0, 0.78, -0.72), Vector3(0.085, 0.1, 0.16), 8, 5, white, 1, 1, piv, hb)
	mb.ellipsoid(Vector3(0, 0.87, -0.65), Vector3(0.09, 0.06, 0.085), 6, 4, white, 1, 0, piv, Basis(), 0.08, 3.0)
	for sx in [-1.0, 1.0]:
		mb.ellipsoid(Vector3(sx * 0.12, 0.83, -0.66), Vector3(0.085, 0.022, 0.04), 4, 3, white, 1, 1, piv, Basis(Vector3.BACK, sx * 0.35))
		mb.ellipsoid(Vector3(sx * 0.072, 0.83, -0.77), Vector3(0.016, 0.016, 0.016), 4, 2, white, 1, 2, piv)
	mb.ellipsoid(Vector3(0, 0.71, -0.86), Vector3(0.035, 0.028, 0.02), 4, 2, white, 1, 2, piv)
	# Legs (parts 2-5: front left, front right, rear left, rear right): woolly tops, thin shanks, dark hooves.
	var legs: Array = [[2, Vector3(-0.12, 0.0, -0.36)], [3, Vector3(0.12, 0.0, -0.36)], [4, Vector3(-0.13, 0.0, 0.38)], [5, Vector3(0.13, 0.0, 0.38)]]
	for lg in legs:
		var part: int = lg[0]
		var f: Vector3 = lg[1]
		var lp := Vector2(0.5, f.z)
		mb.tube(f + Vector3(0, 0.52, 0), f + Vector3(0, 0.4, 0), 0.07, 0.045, 5, white, part, 0, lp, true)
		mb.tube(f + Vector3(0, 0.42, 0), f + Vector3(0, 0.07, 0), 0.04, 0.032, 5, white, part, 1, lp, false)
		mb.tube(f + Vector3(0, 0.08, 0), f + Vector3(0, 0.0, -0.01), 0.036, 0.042, 5, white, part, 2, lp, true)
	mb.tube(Vector3(0, 0.7, 0.55), Vector3(0, 0.5, 0.63), 0.06, 0.04, 5, white, 6, 0, Vector2(0.7, 0.55), true)
	_sheep_mesh = mb.commit()
	return _sheep_mesh


## A sheepdog (a black and white collie) at life size: 1.0m long, 0.55m at the shoulder; legs 2-5, a bushy tail (6).
static func dog_mesh() -> ArrayMesh:
	if _dog_mesh:
		return _dog_mesh
	var mb := _MB.new()
	var blk := Color(0.07, 0.07, 0.07)
	var wht := Color(0.92, 0.91, 0.88)
	mb.ellipsoid(Vector3(0, 0.44, 0.02), Vector3(0.13, 0.14, 0.34), 10, 6, blk, 0, 3, Vector2.ZERO, Basis(), 0.04, 2.0)
	mb.ellipsoid(Vector3(0, 0.42, -0.26), Vector3(0.12, 0.13, 0.12), 8, 5, wht, 0, 3, Vector2.ZERO, Basis(), 0.05, 4.0)
	mb.tube(Vector3(0, 0.48, -0.26), Vector3(0, 0.6, -0.4), 0.09, 0.07, 6, blk, 0, 3, Vector2.ZERO, false)
	mb.ellipsoid(Vector3(0, 0.62, -0.44), Vector3(0.08, 0.08, 0.1), 8, 5, blk, 0, 3, Vector2.ZERO)
	mb.ellipsoid(Vector3(0, 0.58, -0.55), Vector3(0.04, 0.04, 0.08), 6, 4, wht, 0, 3, Vector2.ZERO, Basis(Vector3.RIGHT, 0.2))
	mb.ellipsoid(Vector3(0, 0.585, -0.63), Vector3(0.02, 0.018, 0.012), 4, 2, blk, 0, 2, Vector2.ZERO)
	for sx in [-1.0, 1.0]:
		mb.ellipsoid(Vector3(sx * 0.05, 0.7, -0.42), Vector3(0.025, 0.05, 0.02), 4, 3, blk, 0, 3, Vector2.ZERO, Basis(Vector3.BACK, sx * 0.4) * Basis(Vector3.RIGHT, -0.4))
	var legs: Array = [[2, Vector3(-0.07, 0, -0.24)], [3, Vector3(0.07, 0, -0.24)], [4, Vector3(-0.07, 0, 0.26)], [5, Vector3(0.07, 0, 0.26)]]
	for lg in legs:
		var f: Vector3 = lg[1]
		var lp := Vector2(0.4, f.z)
		mb.tube(f + Vector3(0, 0.42, 0), f + Vector3(0, 0.12, 0), 0.04, 0.028, 5, blk if lg[0] > 3 else wht, lg[0], 3, lp, false)
		mb.tube(f + Vector3(0, 0.13, 0), f + Vector3(0, 0.0, -0.03), 0.028, 0.03, 5, wht, lg[0], 3, lp, true)
	mb.tube(Vector3(0, 0.47, 0.33), Vector3(0, 0.36, 0.5), 0.05, 0.055, 6, blk, 6, 3, Vector2(0.47, 0.33), false)
	mb.tube(Vector3(0, 0.36, 0.5), Vector3(0, 0.24, 0.6), 0.055, 0.03, 6, wht, 6, 3, Vector2(0.47, 0.33), true)
	_dog_mesh = mb.commit()
	return _dog_mesh


## The shepherd at life size (1.8m): a long loden coat, a broad felt hat, a bag; legs 2 and 3, the left arm (4) swings, the
## right hand holds his crook.
static func shepherd_mesh() -> ArrayMesh:
	if _man_mesh:
		return _man_mesh
	var mb := _MB.new()
	var coat := Color(0.36, 0.38, 0.27)
	var trousers := Color(0.20, 0.19, 0.17)
	var skin := Color(0.80, 0.62, 0.50)
	var felt := Color(0.18, 0.15, 0.12)
	var boot := Color(0.12, 0.09, 0.07)
	var wood := Color(0.42, 0.30, 0.18)
	for lg in [[2, -0.1], [3, 0.1]]:
		var x: float = lg[1]
		var lp := Vector2(0.95, 0.0)
		mb.tube(Vector3(x, 0.98, 0), Vector3(x, 0.1, 0.02), 0.075, 0.06, 6, trousers, lg[0], 3, lp, false)
		mb.ellipsoid(Vector3(x, 0.06, -0.05), Vector3(0.06, 0.06, 0.14), 6, 3, boot, lg[0], 3, lp)
	# The coat: a long flared body from the shoulders to below the knees, the collar, the bag on its strap.
	var prof: Array = [[0.36, 0.48], [0.31, 0.75], [0.25, 1.1], [0.24, 1.38], [0.17, 1.5]]
	for k in range(prof.size() - 1):
		var a: Array = prof[k]
		var b: Array = prof[k + 1]
		mb.tube(Vector3(0, a[1], 0), Vector3(0, b[1], 0), a[0], b[0], 10, coat, 0, 3, Vector2.ZERO, k == prof.size() - 2, k == 0)
	mb.tube(Vector3(0, 1.48, 0), Vector3(0, 1.56, 0), 0.08, 0.07, 6, skin, 0, 3, Vector2.ZERO, false)
	mb.ellipsoid(Vector3(0, 1.66, -0.01), Vector3(0.095, 0.115, 0.105), 8, 5, skin, 0, 3, Vector2.ZERO)
	mb.ellipsoid(Vector3(0, 1.735, 0), Vector3(0.3, 0.02, 0.3), 12, 3, felt, 0, 3, Vector2.ZERO)
	mb.tube(Vector3(0, 1.74, 0), Vector3(0, 1.86, 0), 0.115, 0.1, 10, felt, 0, 3, Vector2.ZERO, true)
	mb.ellipsoid(Vector3(0.24, 1.0, 0.1), Vector3(0.07, 0.13, 0.15), 6, 4, Color(0.4, 0.3, 0.18), 0, 3, Vector2.ZERO)
	# The left arm swings (part 4); the right holds the crook out in front, its hook over his head.
	mb.tube(Vector3(-0.27, 1.44, 0), Vector3(-0.3, 0.9, 0.03), 0.065, 0.055, 6, coat, 4, 3, Vector2(1.44, 0.0), false)
	mb.ellipsoid(Vector3(-0.3, 0.86, 0.03), Vector3(0.045, 0.06, 0.04), 4, 3, skin, 4, 3, Vector2(1.44, 0.0))
	mb.tube(Vector3(0.27, 1.44, 0), Vector3(0.32, 1.16, -0.12), 0.065, 0.06, 6, coat, 0, 3, Vector2.ZERO, false)
	mb.tube(Vector3(0.32, 1.16, -0.12), Vector3(0.33, 1.2, -0.36), 0.06, 0.055, 6, coat, 0, 3, Vector2.ZERO, false)
	mb.ellipsoid(Vector3(0.33, 1.2, -0.39), Vector3(0.045, 0.06, 0.045), 4, 3, skin, 0, 3, Vector2.ZERO)
	mb.tube(Vector3(0.33, 0.0, -0.42), Vector3(0.33, 1.98, -0.38), 0.018, 0.018, 5, wood, 0, 3, Vector2.ZERO, false)
	var prev := Vector3(0.33, 1.98, -0.38)
	for k in range(1, 6):
		var a2: float = PI * float(k) / 5.0
		var p := Vector3(0.33, 1.98 + sin(a2) * 0.1, -0.38 + (1.0 - cos(a2)) * 0.1)
		mb.tube(prev, p, 0.018, 0.018, 5, wood, 0, 3, Vector2.ZERO, k == 5)
		prev = p
	_man_mesh = mb.commit()
	return _man_mesh
