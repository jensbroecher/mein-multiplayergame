extends Node3D
## Airliners over the Al-Raihana GP's stages (each generator adds one with routes laid out for its stage, through
## `arrival` and `departure`): arrivals coming down the approach to the city's airport and departures climbing out of
## it. A flight leaves each route's start every `every` seconds, placed from the wall clock (seconds into the UTC day,
## as Train.gd's), so every LAN peer sees the same flights unsynced. Each flight is an AirlinerKit airframe
## (generated/airliners/airliner_<frame>.tscn, made by regenerate_airliners.gd) at SCALE, the stages' 1.6, in a livery
## drawn from `fleet` by its number. It banks into turns, flares and lowers its nose on landing, rotates on take-off,
## puts its gear down GEAR_DOWN_AT over the runway on the approach and folds it up after lift-off, flashes its lights
## and roars (its kind's recorded loop, `CLIPS`; `jet_roar`, synthesised, if that is missing). Flights fade in and out at their routes' ends (`vis`) and toward the cameras'
## far plane (the airframe shader). Pooled: a flight takes a free plane when it starts and gives it back when it ends.
## A headless server builds nothing. `clock_override` holds every flight at one reading (lap_shots' clock=).

const AirlinerKit = preload("res://AirlinerKit.gd")

const SCALE := 1.6
## Route samples' spacing, and how far either side heights are smoothed (except on the ground).
const STEP := 10.0
const SMOOTH := 120.0
## The gear comes down this high over the runway on the approach.
const GEAR_DOWN_AT := 650.0
## A turn's bank: as a life-size airliner banks at its own speed in a turn of its size (25 degrees at most).
const G := 9.81 * 1.6
const MAX_BANK := 0.44
## A flight fades in and out over this many seconds at its route's ends.
const FADE := 5.0
const RATE := 22050
## The engines' recorded loops (tools/elevenlabs: a jet on the approach, one climbing out) and the gain that brings
## each clip's measured RMS (scratch/measure_clip_rms.gd) to the -16 dBFS `engine_db` is set for. A missing clip falls
## back on the synthesised `jet_roar`.
const CLIPS := {"arr": ["res://sounds/airliners/jet_approach_loop.wav", 4.5], "dep": ["res://sounds/airliners/jet_climb_loop.wav", 3.3]}

## Each route: {"kind": "arr" or "dep", "pts": PackedVector3Array (the main wheels' path, world), "spd":
## PackedFloat32Array (m/s at each point), "radius": the turns' radius in plan, "every": seconds between flights,
## "phase": seconds, "ground": the runway's height}. `arrival` and `departure` make them.
@export var routes: Array = []
## The airframes and liveries flights are drawn from ("frame:livery"), by a hash of the flight's number.
@export var fleet := PackedStringArray(["twin:raihana", "quad:raihana", "twin:bloombay", "twin:raihana", "twin:matumaini",
		"quad:raihana_cargo", "twin:viento", "twin:sahar"])
## 0 by day, 1 at night: the cabin windows, the tail's floodlights and the lights' strength.
@export var night := 0.0
## The engines' level (dB) on the jet roar loop (see `_place` for take-off and landing).
@export var engine_db := -10.0
@export var clock_override := -1.0

var _built: Array = []
var _active := {}
var _free := {}
var _scenes := {}

static var _roar: AudioStreamWAV = null


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_physics_process(false)
		return
	for spec in fleet:
		AirlinerKit.livery_material(String(spec).get_slice(":", 1))
	for m in AirlinerKit.all_materials():
		(m as ShaderMaterial).set_shader_parameter("night", night)
	for rt in routes:
		_built.append(_build_route(rt))
	_update()


func _physics_process(_delta: float) -> void:
	_update()


func _clock() -> float:
	if clock_override >= 0.0:
		return clock_override
	return fposmod(Time.get_unix_time_from_system(), 86400.0)


func _update() -> void:
	var now := _clock()
	var seen := {}
	for ri in range(_built.size()):
		var rt: Dictionary = _built[ri]
		var every: float = rt.every
		var k_hi: int = floori((now - float(rt.phase)) / every)
		var k_lo: int = floori((now - float(rt.phase) - float(rt.total)) / every) + 1
		for k in range(k_lo, k_hi + 1):
			var u: float = now - float(rt.phase) - float(k) * every
			if u < 0.0 or u >= float(rt.total):
				continue
			var key := "%d:%d" % [ri, k]
			seen[key] = true
			var fresh := false
			if not _active.has(key):
				_active[key] = _take(fleet[_pick(ri, k)], ri, k, String(rt.kind))
				fresh = true
			_place(_active[key], rt, u, fresh)
	for key in _active.keys():
		if not seen.has(key):
			_give_back(_active[key])
			_active.erase(key)


func _pick(ri: int, k: int) -> int:
	var h: int = (k * 2654435761 + ri * 40503 + 977) & 0x7fffffff
	return h % maxi(fleet.size(), 1)


# ======================================================================================
#  Planes
# ======================================================================================

func _take(spec: String, ri: int, k: int, kind: String) -> Dictionary:
	var frame: String = spec.get_slice(":", 0)
	var livery: String = spec.get_slice(":", 1)
	var pl: Dictionary
	var pool: Array = _free.get(frame, [])
	if not pool.is_empty():
		pl = pool.pop_back()
	else:
		pl = _new_plane(frame)
	var mat := AirlinerKit.livery_material(livery)
	(pl.body as MeshInstance3D).material_override = mat
	for g in pl.gears:
		(g[0] as MeshInstance3D).material_override = mat
	var h: int = (k * 7919 + ri * 104729) & 0xffff
	(pl.lights as MeshInstance3D).set_instance_shader_parameter("phase", float(h) / 65535.0 * 5.0)
	var audio: AudioStreamPlayer3D = pl.audio
	audio.pitch_scale = 0.93 + float(h % 97) / 97.0 * 0.12
	var clip: Array = _clip(kind)
	audio.stream = clip[0]
	pl["gain"] = float(clip[1])
	(pl.node as Node3D).visible = true
	return pl


static var _clips := {}

## The engines' loop for a kind of flight and its gain: the recording if it is there, else the synthesised roar.
static func _clip(kind: String) -> Array:
	if not _clips.has(kind):
		var c: Array = CLIPS.get(kind, CLIPS["arr"])
		var st: AudioStream = load(String(c[0])) if ResourceLoader.exists(String(c[0])) else null
		_clips[kind] = [st, float(c[1])] if st != null else [jet_roar(), 0.0]
	return _clips[kind]


func _new_plane(frame: String) -> Dictionary:
	if not _scenes.has(frame):
		_scenes[frame] = load("res://generated/airliners/airliner_%s.tscn" % frame)
	var node := Node3D.new()
	node.name = "Flight_%s_%d" % [frame, get_child_count()]
	add_child(node)
	var inst: Node3D = (_scenes[frame] as PackedScene).instantiate()
	node.add_child(inst)
	var params := AirlinerKit.instance_params(frame)
	var body: MeshInstance3D = inst.get_node("Body")
	var gears: Array = []
	for g in inst.get_children():
		if String(g.name).begins_with("Gear"):
			gears.append([g, g.get_meta("fold_axis"), float(g.get_meta("fold_angle")), (g as Node3D).position])
	for mi in [body] + gears.map(func(x: Array) -> MeshInstance3D: return x[0]):
		for key in params.keys():
			(mi as MeshInstance3D).set_instance_shader_parameter(key, params[key])
	var lights: MeshInstance3D = inst.get_node("Lights")
	lights.material_override = AirlinerKit.light_material()
	var audio := AudioStreamPlayer3D.new()
	audio.stream = jet_roar()
	audio.unit_size = 400.0
	audio.max_db = -4.0
	audio.max_distance = 5200.0
	audio.attenuation_filter_cutoff_hz = 2600.0
	audio.attenuation_filter_db = -14.0
	audio.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	node.add_child(audio)
	return {"node": node, "frame": frame, "body": body, "gears": gears, "lights": lights, "audio": audio,
			"contact": AirlinerKit.contact(frame) * SCALE}


func _give_back(pl: Dictionary) -> void:
	(pl.node as Node3D).visible = false
	(pl.audio as AudioStreamPlayer3D).stop()
	if not _free.has(pl.frame):
		_free[pl.frame] = []
	(_free[pl.frame] as Array).append(pl)


## Puts a plane where its flight is `u` seconds after it started along route `rt`.
func _place(pl: Dictionary, rt: Dictionary, u: float, fresh: bool) -> void:
	var t: PackedFloat32Array = rt.t
	var n: int = t.size()
	var i: int = clampi(t.bsearch(u, true) - 1, 0, n - 2)
	var f: float = clampf((u - t[i]) / maxf(t[i + 1] - t[i], 1e-4), 0.0, 1.0)
	var pos: PackedVector3Array = rt.pos
	var sv: PackedFloat32Array = rt.s
	var vv: PackedFloat32Array = rt.v
	var p: Vector3 = pos[i].lerp(pos[i + 1], f)
	var s: float = lerpf(sv[i], sv[i + 1], f)
	var v: float = lerpf(vv[i], vv[i + 1], f)
	var ground: float = rt.ground
	var h: float = p.y - ground
	# Heading and climb over a few samples either side; the turn over 150m either side.
	var ia: int = maxi(i - 3, 0)
	var ib: int = mini(i + 4, n - 1)
	var d: Vector3 = pos[ib] - pos[ia]
	var plan := Vector3(d.x, 0.0, d.z)
	if plan.length_squared() < 1e-6:
		plan = Vector3(0, 0, -1)
	var gamma: float = atan2(d.y, plan.length())
	var ja: int = maxi(i - 15, 0)
	var jb: int = mini(i + 15, n - 1)
	var h0 := Vector2(pos[mini(ja + 2, n - 1)].x - pos[ja].x, pos[mini(ja + 2, n - 1)].z - pos[ja].z)
	var h1 := Vector2(pos[jb].x - pos[maxi(jb - 2, 0)].x, pos[jb].z - pos[maxi(jb - 2, 0)].z)
	var kappa := 0.0
	if h0.length_squared() > 1e-6 and h1.length_squared() > 1e-6 and sv[jb] > sv[ja]:
		kappa = h0.angle_to(h1) / (sv[jb] - sv[ja])
	var bank: float = clampf(atan(v * v * kappa / G), -MAX_BANK, MAX_BANK)
	var pitch: float
	var ext: float
	var db: float = engine_db
	if rt.kind == "arr":
		var s_td: float = rt.s_ground
		if s < s_td:
			# The approach: nose a little up; the flare over the last 30m.
			pitch = gamma + deg_to_rad(5.5) + deg_to_rad(3.0) * (1.0 - _smooth(0.0, 30.0, h))
		else:
			# Rolling out: the nose comes down, reverse thrust roars for a while.
			pitch = deg_to_rad(5.0) * (1.0 - _smooth(s_td, s_td + 380.0, s))
			db += 3.0 * (1.0 - _smooth(s_td + 300.0, s_td + 1200.0, s)) - 6.0 * _smooth(s_td + 900.0, s_td + 1800.0, s)
		ext = clampf((GEAR_DOWN_AT - h) / 70.0, 0.0, 1.0)
	else:
		var s_lof: float = rt.s_ground
		if s <= s_lof:
			pitch = deg_to_rad(9.0) * _smooth(s_lof - 450.0, s_lof, s)
		else:
			pitch = lerpf(deg_to_rad(9.0), gamma + deg_to_rad(6.5), _smooth(s_lof, s_lof + 800.0, s))
		ext = 1.0 - _smooth(s_lof + 300.0, s_lof + 1300.0, s)
		db += 5.0 * (1.0 - _smooth(500.0, 1800.0, h))
	pitch = clampf(pitch, deg_to_rad(-6.0), deg_to_rad(18.0))
	var b := Basis.looking_at(plan.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, -bank)
	var origin: Vector3 = p - b * (pl.contact as Vector3)
	var node: Node3D = pl.node
	node.transform = Transform3D(b.scaled(Vector3.ONE * SCALE), origin)
	for g in pl.gears:
		var gm: MeshInstance3D = g[0]
		gm.visible = ext > 0.02
		gm.transform = Transform3D(Basis(g[1] as Vector3, float(g[2]) * (1.0 - _ease(ext))), g[3])
	var vis: float = _smooth(0.0, FADE, u) * _smooth(0.0, FADE, float(rt.total) - u)
	(pl.body as MeshInstance3D).set_instance_shader_parameter("vis", vis)
	(pl.lights as MeshInstance3D).set_instance_shader_parameter("vis", vis)
	for g in pl.gears:
		(g[0] as MeshInstance3D).set_instance_shader_parameter("vis", vis)
	var audio: AudioStreamPlayer3D = pl.audio
	audio.volume_db = db + float(pl.get("gain", 0.0)) + linear_to_db(maxf(vis, 0.001))
	if fresh:
		node.reset_physics_interpolation()
		audio.play(fposmod(u, maxf(audio.stream.get_length(), 1.0)))
	elif not audio.playing:
		audio.play()


static func _smooth(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _ease(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


# ======================================================================================
#  Routes
# ======================================================================================

## Samples a route every STEP along its plan, its corners rounded to `radius`: positions (heights smoothed except on
## the ground), distances, speeds and the times they are reached; where it touches down or lifts off.
static func build_route(rt: Dictionary) -> Dictionary:
	var pts: PackedVector3Array = rt["pts"]
	var spd: PackedFloat32Array = rt["spd"]
	var radius: float = rt.get("radius", 3500.0)
	var ground: float = rt.get("ground", 0.0)
	var n := pts.size()
	var p2: Array = []
	for q in pts:
		p2.append(Vector2(q.x, q.z))
	var cum := PackedFloat32Array([0.0])
	for i in range(1, n):
		cum.append(cum[i - 1] + ((p2[i] as Vector2) - (p2[i - 1] as Vector2)).length())
	var xs: Array = []
	var ps: Array = []
	var start: Vector2 = p2[0]
	var start_s := 0.0
	for i in range(1, n):
		var corner: Vector2 = p2[i]
		if i == n - 1:
			_walk_line(xs, ps, start, corner, start_s, cum[i], true)
			break
		var d0: Vector2 = (corner - (p2[i - 1] as Vector2)).normalized()
		var d1: Vector2 = ((p2[i + 1] as Vector2) - corner).normalized()
		var turn: float = d0.angle_to(d1)
		if absf(turn) < 0.002:
			_walk_line(xs, ps, start, corner, start_s, cum[i], false)
			start = corner
			start_s = cum[i]
			continue
		var tl: float = radius * tan(absf(turn) * 0.5)
		tl = minf(tl, 0.45 * minf((corner - (p2[i - 1] as Vector2)).length(), ((p2[i + 1] as Vector2) - corner).length()))
		var r: float = tl / tan(absf(turn) * 0.5)
		var a: Vector2 = corner - d0 * tl
		var b: Vector2 = corner + d1 * tl
		_walk_line(xs, ps, start, a, start_s, cum[i] - tl, false)
		var right := Vector2(-d0.y, d0.x)
		var centre: Vector2 = a + right * r * signf(turn)
		var th0: float = (a - centre).angle()
		var steps: int = maxi(ceili(r * absf(turn) / STEP), 1)
		for k in range(steps):
			var w: float = float(k) / float(steps)
			xs.append(centre + Vector2.from_angle(th0 + turn * w) * r)
			ps.append(lerpf(cum[i] - tl, cum[i] + tl, w))
		start = b
		start_s = cum[i] + tl
	# Heights and speeds by the distance along the polyline.
	var m: int = xs.size()
	var ys := PackedFloat32Array()
	var vs := PackedFloat32Array()
	ys.resize(m)
	vs.resize(m)
	for j in range(m):
		var sp: float = ps[j]
		var seg: int = clampi(cum.bsearch(sp, true) - 1, 0, n - 2)
		var w: float = clampf((sp - cum[seg]) / maxf(cum[seg + 1] - cum[seg], 1e-3), 0.0, 1.0)
		ys[j] = lerpf(pts[seg].y, pts[seg + 1].y, w)
		vs[j] = lerpf(spd[seg], spd[seg + 1], w)
	# Smoothed in the air (a running mean), never under the runway; on the ground it stays on it.
	var half: int = int(SMOOTH / STEP)
	var ysm := PackedFloat32Array()
	ysm.resize(m)
	for j in range(m):
		if ys[j] <= ground + 0.01:
			ysm[j] = ground
			continue
		var acc := 0.0
		var cnt := 0
		for q in range(maxi(j - half, 0), mini(j + half, m - 1) + 1):
			acc += ys[q]
			cnt += 1
		ysm[j] = maxf(acc / float(cnt), ground)
	var pos := PackedVector3Array()
	var s := PackedFloat32Array()
	var t := PackedFloat32Array()
	pos.resize(m)
	s.resize(m)
	t.resize(m)
	for j in range(m):
		var xz: Vector2 = xs[j]
		pos[j] = Vector3(xz.x, ysm[j], xz.y)
		if j > 0:
			var ds: float = (pos[j] - pos[j - 1]).length()
			s[j] = s[j - 1] + ds
			t[j] = t[j - 1] + ds / maxf((vs[j] + vs[j - 1]) * 0.5, 2.0)
	# Where it touches down (an arrival's first sample on the ground) or lifts off (a departure's last).
	var kind: String = rt.get("kind", "arr")
	var s_ground := 0.0
	if kind == "arr":
		s_ground = s[m - 1]
		for j in range(m):
			if ysm[j] <= ground + 0.02:
				s_ground = s[j]
				break
	else:
		for j in range(m):
			if ysm[j] <= ground + 0.02:
				s_ground = s[j]
	return {"kind": kind, "pos": pos, "s": s, "t": t, "v": vs, "total": t[m - 1], "every": rt.get("every", 90.0),
			"phase": rt.get("phase", 0.0), "ground": ground, "s_ground": s_ground}


func _build_route(rt: Dictionary) -> Dictionary:
	return build_route(rt)


static func _walk_line(xs: Array, ps: Array, a: Vector2, b: Vector2, sa: float, sb: float, last: bool) -> void:
	var L: float = (b - a).length()
	var steps: int = maxi(ceili(L / STEP), 1)
	for k in range(steps + (1 if last else 0)):
		var w: float = float(k) / float(steps)
		xs.append(a.lerp(b, w))
		ps.append(lerpf(sa, sb, w))


## An arrival: from the `entry` points ([Vector3, speed] each, far out and high) to the final approach fix
## `final_len` out on the runway's extended centre line, down the 3-degree glide path to cross the threshold 15m up,
## touching down 500m past it and rolling out 2.6km to a crawl. Heights are the main wheels', `threshold.y` the
## runway's.
static func arrival(threshold: Vector3, heading: Vector2, entry: Array, final_len := 9000.0, every := 90.0,
		phase := 0.0, radius := 3500.0) -> Dictionary:
	var h := heading.normalized()
	var glide := tan(deg_to_rad(3.0))
	var th := Vector2(threshold.x, threshold.z)
	var pts := PackedVector3Array()
	var spd := PackedFloat32Array()
	for e in entry:
		pts.append(e[0])
		spd.append(float(e[1]))
	var faf: Vector2 = th - h * final_len
	pts.append(Vector3(faf.x, threshold.y + 15.0 + final_len * glide, faf.y))
	spd.append(128.0)
	pts.append(Vector3(th.x, threshold.y + 15.0, th.y))
	spd.append(114.0)
	var td: Vector2 = th + h * 500.0
	pts.append(Vector3(td.x, threshold.y, td.y))
	spd.append(108.0)
	var stop: Vector2 = th + h * 2600.0
	pts.append(Vector3(stop.x, threshold.y, stop.y))
	spd.append(20.0)
	return {"kind": "arr", "pts": pts, "spd": spd, "radius": radius, "every": every, "phase": phase, "ground": threshold.y}


## A departure: from the runway's start (its height the runway's) rolling `roll` metres to lift off, climbing out
## straight ahead at about 7 degrees for 3.5km, then on through the `exits` ([Vector3, speed] each, climbing away).
static func departure(start: Vector3, heading: Vector2, exits: Array, roll := 2800.0, every := 90.0, phase := 0.0,
		radius := 3500.0) -> Dictionary:
	var h := heading.normalized()
	var s0 := Vector2(start.x, start.z)
	var pts := PackedVector3Array()
	var spd := PackedFloat32Array()
	pts.append(start)
	spd.append(6.0)
	var lof: Vector2 = s0 + h * roll
	pts.append(Vector3(lof.x, start.y, lof.y))
	spd.append(128.0)
	var out: Vector2 = s0 + h * (roll + 3500.0)
	pts.append(Vector3(out.x, start.y + 3500.0 * tan(deg_to_rad(7.0)), out.y))
	spd.append(152.0)
	for e in exits:
		pts.append(e[0])
		spd.append(float(e[1]))
	return {"kind": "dep", "pts": pts, "spd": spd, "radius": radius, "every": every, "phase": phase, "ground": start.y}


# ======================================================================================
#  The engines' roar
# ======================================================================================

## A distant jet's roar, a seamless 6s loop: broadband rumble (noise through low passes, swelling and fading slowly as
## the air carries it), a dull low end and a faint fan whine that only tells close by. About -16 dBFS RMS.
static func jet_roar() -> AudioStreamWAV:
	if _roar != null:
		return _roar
	var length := 6.0
	var n: int = int(RATE * length)
	var xf: int = int(RATE * 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var raw := PackedFloat32Array()
	raw.resize(n + xf)
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	var brown := 0.0
	var gust := 0.0
	var gust_t := 0.0
	for i in range(n + xf):
		var w: float = rng.randf_range(-1.0, 1.0)
		lp1 += (w - lp1) * 0.30
		lp2 += (w - lp2) * 0.06
		lp3 += (lp2 - lp3) * 0.10
		brown = brown * 0.996 + w * 0.06
		# The roar swells and fades on gusts.
		if i % 2205 == 0:
			gust_t = rng.randf_range(0.7, 1.25)
		gust += (gust_t - gust) * 0.0004
		var t: float = float(i) / RATE
		var whine: float = (sin(TAU * 1870.0 * t + 0.4 * sin(TAU * 0.7 * t)) * 0.6 + sin(TAU * 2440.0 * t) * 0.4) * 0.025
		raw[i] = (lp1 * 0.35 + lp2 * 1.1 + lp3 * 1.6 + brown * 0.9) * gust + whine
	# Seamless: the tail crossfaded into the head.
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = raw[i]
	for i in range(xf):
		var w2: float = float(i) / float(xf)
		out[i] = raw[n + i] * (1.0 - w2) + raw[i] * w2
	var rms := 0.0
	for v in out:
		rms += v * v
	rms = sqrt(rms / float(n))
	var gain: float = 0.158 / maxf(rms, 1e-5)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		bytes.encode_s16(i * 2, int(clampf(out[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	_roar = wav
	return wav
