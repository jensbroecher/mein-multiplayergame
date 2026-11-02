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

var _cells := {}
var _segs: Array = []        # [a, b, line]
var _state := {}             # cart id -> {pos, line, lat, run}
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
		if st.has("lat") and int(st.get("line", -1)) == int(tr["line"]):
			var was: float = st["lat"]
			for r in [-GAUGE_HALF, GAUGE_HALF]:
				if (was - r) * (lat - r) < 0.0 and speed > 2.0:
					# Over a rail: a heavy clunk, the nose kicked up a little.
					var lift: float = clampf(0.5 + speed * 0.045, 0.6, 2.2)
					cart.jolt(lift, lift * 0.35)
					_play(FreightKit.rail_clunk(), pos, lerpf(-16.0, -5.0, clampf(speed / 30.0, 0.0, 1.0)), randf_range(0.9, 1.08))
			# Along the track over the sleepers: a smaller jolt and a knock every SLEEPER_STEP.
			var along: float = absf(vel.dot(tr["dir"]))
			if absf(lat) < GAUGE_HALF + 1.4 and speed > 3.0 and along > 0.6 * speed:
				run += along * delta
				if run >= SLEEPER_STEP:
					run = fmod(run, SLEEPER_STEP)
					var small: float = clampf(0.25 + speed * 0.022, 0.3, 1.0)
					cart.jolt(small * randf_range(0.8, 1.2), small * randf_range(-0.4, 0.4))
					_play(FreightKit.sleeper_knock(), pos, lerpf(-22.0, -10.0, clampf(speed / 30.0, 0.0, 1.0)), randf_range(0.85, 1.15))
			else:
				run = 0.0
		_state[id] = {"pos": pos, "line": tr["line"], "lat": lat, "run": run}
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
