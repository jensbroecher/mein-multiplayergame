extends Node3D
## Freight Line's track under the carts' wheels (added and fed by regenerate_freight_line.gd: `lines`, the centre line
## of every stretch of track at the rails' top). A cart that crosses a rail on the ground (at a level crossing, or
## anywhere off the road) clunks over it, its body jolting on the suspension (PlayerCart.jolt); one running along a
## track rattles over the sleepers, a knock and a smaller jolt every SLEEPER_STEP. Each peer does this for every cart
## it sees, from their positions (so remote carts count); nothing is synced and the physics are untouched: the beds'
## collision (FreightKit._bed_faces) is a smooth hump on purpose, since PlayerCart soaks up small kicks and launches
## carts off steeper ones.

const FreightKit = preload("res://FreightKit.gd")

@export var lines: Array[PackedVector3Array] = []

const GAUGE_HALF := FreightKit.GAUGE_HALF
const CELL := 16.0
## How far across from a track's centre a cart counts as on it, and how high its centre may be over the rails' top.
const NEAR := 3.6
const OVER_RAIL := 2.4
## Metres along the track between the knocks of a cart running along it (every third sleeper).
const SLEEPER_STEP := 2.79
const VOICES := 8

## Speeds above this on the raw tracks cause violent shaking and danger of flipping over.
const DANGER_SPEED := 24.5
const FLIP_SPEED := 26.5

var _cells := {}
var _segs: Array = []        # [a, b, line]
var _state := {}             # cart id -> {pos, line, lat, run, fast_time, flip_cd}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0


func _ready() -> void:
	for li in range(lines.size()):
		var pts: PackedVector3Array = lines[li]
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var si: int = _segs.size()
			_segs.append([a, b, li])
			var x0: int = floori((minf(a.x, b.x) - NEAR) / CELL)
			var x1: int = floori((maxf(a.x, b.x) + NEAR) / CELL)
			var z0: int = floori((minf(a.z, b.z) - NEAR) / CELL)
			var z1: int = floori((maxf(a.z, b.z) + NEAR) / CELL)
			for cx in range(x0, x1 + 1):
				for cz in range(z0, z1 + 1):
					var key := Vector2i(cx, cz)
					var bucket: PackedInt32Array = _cells.get(key, PackedInt32Array())
					bucket.append(si)
					_cells[key] = bucket
	for k in VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 14.0
		p.max_distance = 160.0
		add_child(p, false, Node.INTERNAL_MODE_BACK)
		_voices.append(p)


## The track nearest `pos` within NEAR: {line, lat (metres right of its centre), dir (along it), y (the rails' top)}.
func _nearest(pos: Vector3) -> Dictionary:
	var bucket: PackedInt32Array = _cells.get(Vector2i(floori(pos.x / CELL), floori(pos.z / CELL)), PackedInt32Array())
	var best := {}
	var best_d := NEAR
	for si in bucket:
		var a: Vector3 = _segs[si][0]
		var b: Vector3 = _segs[si][1]
		var ab := Vector3(b.x - a.x, 0.0, b.z - a.z)
		var l2: float = ab.length_squared()
		if l2 < 1e-6:
			continue
		var t: float = clampf(Vector3(pos.x - a.x, 0.0, pos.z - a.z).dot(ab) / l2, 0.0, 1.0)
		var foot: Vector3 = a + (b - a) * t
		var off := Vector3(pos.x - foot.x, 0.0, pos.z - foot.z)
		var d: float = off.length()
		if d < best_d:
			best_d = d
			var dir: Vector3 = ab / sqrt(l2)
			best = {"line": _segs[si][2], "lat": off.dot(Vector3(-dir.z, 0.0, dir.x)), "dir": dir, "y": foot.y}
	return best


func _physics_process(delta: float) -> void:
	if _segs.is_empty() or delta <= 0.0:
		return
	var seen := {}
	for c in get_tree().get_nodes_in_group("player_carts"):
		var cart := c as Node3D
		if cart == null or not is_instance_valid(cart) or not cart.has_method("jolt"):
			continue
		var id: int = cart.get_instance_id()
		seen[id] = true
		var pos: Vector3 = cart.global_position
		var st: Dictionary = _state.get(id, {})
		var last: Vector3 = st.get("pos", pos)
		var step := Vector3(pos.x - last.x, 0.0, pos.z - last.z)
		if step.length() > 8.0 or cart.get("is_exploding") or cart.get("is_teleporting"):
			_state[id] = {"pos": pos}
			continue
		var tr: Dictionary = _nearest(pos)
		if tr.is_empty() or pos.y - float(tr["y"]) > OVER_RAIL or pos.y - float(tr["y"]) < -1.0:
			_state[id] = {"pos": pos}
			continue
		var vel: Vector3 = step / delta
		var speed: float = vel.length()
		var lat: float = tr["lat"]
		var run: float = st.get("run", 0.0)
		var fast_time: float = st.get("fast_time", 0.0)
		var flip_cd: float = maxf(0.0, float(st.get("flip_cd", 0.0)) - delta)
		var on_track: bool = absf(lat) < GAUGE_HALF + 1.2
		var surf: int = int(cart.get("surface")) if cart.get("surface") != null else -1
		var is_road_crossing: bool = surf == 0 or surf == 8 # Surfaces.ASPHALT or Surfaces.WOOD

		if st.has("lat") and int(st.get("line", -1)) == int(tr["line"]):
			var was: float = st["lat"]
			for r in [-GAUGE_HALF, GAUGE_HALF]:
				if (was - r) * (lat - r) < 0.0 and speed > 2.0:
					# Over a rail: a heavy clunk, the nose kicked up a little.
					var lift: float = clampf(0.5 + speed * 0.045, 0.6, 2.2)
					cart.jolt(lift, lift * 0.35, randf_range(-0.3, 0.3))
					_play(FreightKit.rail_clunk(), pos, lerpf(-16.0, -5.0, clampf(speed / 30.0, 0.0, 1.0)), randf_range(0.9, 1.08))

			# Shaking / rattling to simulate that the tracks are not a smooth surface
			var along: float = absf(vel.dot(tr["dir"]))
			if on_track and speed > 2.0:
				var rattle_scale: float = clampf(speed / 16.0, 0.25, 1.25)
				# Rapid chassis chatter: lift, pitch, and roll
				cart.jolt(randf_range(-0.35, 0.45) * rattle_scale, randf_range(-0.3, 0.3) * rattle_scale, randf_range(-0.35, 0.35) * rattle_scale)
				# Physical micro-bumps on sleepers/ballast
				var has_auth: bool = not cart.has_method("has_physics_authority") or cart.has_physics_authority()
				if cart.get("is_on_ground") and not is_road_crossing and has_auth:
					var cmass: float = float(cart.get("mass")) if cart.get("mass") != null else 1200.0
					var bump: Vector3 = (Vector3.UP * randf_range(0.25, 0.75) + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))) * (cmass * 0.12 * rattle_scale)
					cart.apply_central_impulse(bump)

				# Rhythmic sleeper knocks proportional to speed
				run += (along if along > 1.0 else speed * 0.7) * delta
				var step_dist := 1.3
				if run >= step_dist:
					run = fmod(run, step_dist)
					_play(FreightKit.sleeper_knock(), pos, lerpf(-20.0, -8.0, clampf(speed / 30.0, 0.0, 1.0)), randf_range(0.85, 1.15))
			else:
				run = 0.0

			# When going too fast on the train tracks, flip over and be thrown to the side!
			if on_track and not is_road_crossing and speed > DANGER_SPEED:
				fast_time += delta
				var has_auth: bool = not cart.has_method("has_physics_authority") or cart.has_physics_authority()
				if flip_cd <= 0.0 and has_auth and (fast_time >= 0.22 or speed > FLIP_SPEED):
					var side_norm := Vector3(-tr["dir"].z, 0.0, tr["dir"].x)
					var throw_side: Vector3 = side_norm * (1.0 if lat >= 0.0 else -1.0)
					var up_force: float = randf_range(6.5, 9.5)
					var side_force: float = randf_range(5.5, 8.5)
					var cmass: float = float(cart.get("mass")) if cart.get("mass") != null else 1200.0
					var throw_impulse: Vector3 = (throw_side * side_force + Vector3.UP * up_force + vel.normalized() * 1.5) * cmass
					cart.apply_central_impulse(throw_impulse)
					cart.air_angular_velocity = Vector3(
						randf_range(-8.0, 8.0),
						randf_range(-4.0, 4.0),
						randf_range(11.0, 17.0) * (1.0 if lat >= 0.0 else -1.0)
					)
					_play(FreightKit.rail_clunk(), pos, 2.0, randf_range(0.82, 0.95))
					flip_cd = 2.5
					fast_time = 0.0
			else:
				fast_time = 0.0
		_state[id] = {"pos": pos, "line": tr["line"], "lat": lat, "run": run, "fast_time": fast_time, "flip_cd": flip_cd}
	for id in _state.keys():
		if not seen.has(id):
			_state.erase(id)


func _play(stream: AudioStream, at: Vector3, db: float, pitch: float) -> void:
	var p: AudioStreamPlayer3D = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = stream
	p.global_position = at
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()
