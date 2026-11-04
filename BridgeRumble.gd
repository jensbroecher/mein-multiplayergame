extends Node3D
## The sound of steel bridges under the carts' wheels (Harbor Pier's two channel bridges, fed by the generator: `decks`,
## each an AABB round a deck from its top down). A cart on a deck drums on it: a hollow, resonant steel rumble that rises
## with its speed, played on a player of its own that rides with the cart; at every plate joint (`JOINT_STEP`) a small
## clank; driving on or off it, a heavy clang over the expansion joint. All synthesised here (no recording), like
## RailRumble.gd's rails. Each peer does this for every cart it sees, from their positions (remote carts count); nothing
## is synced, and a headless server makes no sound.

@export var decks: Array[AABB] = []

## Metres along the deck between the plate joints' clanks.
const JOINT_STEP := 3.0
## How far over a deck's top a cart's centre may be and still count as on it.
const OVER := 2.6
const VOICES := 6
const RATE := 22050

static var _streams := {}

var _state := {}               # cart id -> {pos, on, run, player}
var _voices: Array[AudioStreamPlayer3D] = []
var _next_voice := 0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_physics_process(false)
		return
	for k in VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 18.0
		p.max_distance = 220.0
		add_child(p, false, Node.INTERNAL_MODE_BACK)
		_voices.append(p)


func _deck_at(pos: Vector3) -> int:
	for i in range(decks.size()):
		var b: AABB = decks[i]
		var top: float = b.end.y
		if pos.x >= b.position.x and pos.x <= b.end.x and pos.z >= b.position.z and pos.z <= b.end.z \
				and pos.y >= top - 0.6 and pos.y <= top + OVER:
			return i
	return -1


func _physics_process(delta: float) -> void:
	if decks.is_empty() or delta <= 0.0:
		return
	var seen := {}
	for c in get_tree().get_nodes_in_group("player_carts"):
		var cart := c as Node3D
		if cart == null or not is_instance_valid(cart):
			continue
		var id: int = cart.get_instance_id()
		seen[id] = true
		var pos: Vector3 = cart.global_position
		var st: Dictionary = _state.get(id, {})
		var last: Vector3 = st.get("pos", pos)
		var step := Vector3(pos.x - last.x, 0.0, pos.z - last.z)
		var speed: float = step.length() / delta
		var deck := -1
		if step.length() < 8.0 and not cart.get("is_exploding") and not cart.get("is_teleporting"):
			deck = _deck_at(pos)
		var was_on: bool = st.get("on", false)
		var on: bool = deck >= 0
		var player: AudioStreamPlayer3D = st.get("player", null)
		if on != was_on and speed > 3.0:
			# Over the expansion joint at either end.
			_play(deck_clang(), pos, lerpf(-14.0, -2.0, clampf(speed / 30.0, 0.0, 1.0)), randf_range(0.92, 1.06))
		var run: float = st.get("run", 0.0)
		if on:
			if player == null:
				player = AudioStreamPlayer3D.new()
				player.bus = &"SFX"
				player.stream = deck_rumble()
				player.unit_size = 16.0
				player.max_distance = 200.0
				add_child(player, false, Node.INTERNAL_MODE_BACK)
			if not player.playing:
				player.play(randf() * 1.5)
			player.global_position = pos
			var k: float = clampf(speed / 32.0, 0.0, 1.0)
			player.volume_db = lerpf(-30.0, -3.0, sqrt(k)) if speed > 0.5 else -60.0
			player.pitch_scale = lerpf(0.7, 1.35, k)
			if speed > 2.0:
				run += speed * delta
				if run >= JOINT_STEP:
					run = fmod(run, JOINT_STEP)
					_play(plate_clank(), pos, lerpf(-22.0, -9.0, k), randf_range(0.9, 1.15))
		else:
			run = 0.0
			if player != null and player.playing:
				player.stop()
		_state[id] = {"pos": pos, "on": on, "run": run, "player": player}
	for id in _state.keys():
		if not seen.has(id):
			var pl: AudioStreamPlayer3D = _state[id].get("player", null)
			if pl != null:
				pl.queue_free()
			_state.erase(id)


func _play(stream: AudioStream, at: Vector3, db: float, pitch: float) -> void:
	var p: AudioStreamPlayer3D = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = stream
	p.global_position = at
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


# ======================================================================================
#  The sounds
# ======================================================================================

## A hollow steel deck drumming under the wheels, a seamless 2s loop: the deck's low resonances (whole cycles in the
## loop, so it joins up), a band of rumbling noise through them, and the plates' faint ring, beating slowly.
static func deck_rumble() -> AudioStreamWAV:
	if _streams.has("deck_rumble"):
		return _streams["deck_rumble"]
	var length := 2.0
	var n: int = int(RATE * length)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3301
	var out := PackedFloat32Array()
	out.resize(n)
	# Noise, low-passed twice and band-passed (the difference of two low passes), wrapped round so the loop is seamless:
	# run it twice and keep the second pass, which starts where the first ended.
	var lp := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	var noise := PackedFloat32Array()
	noise.resize(n)
	var seq := PackedFloat32Array()
	seq.resize(n)
	for i in range(n):
		seq[i] = rng.randf_range(-1.0, 1.0)
	for pass_i in 2:
		for i in range(n):
			lp += (seq[i] - lp) * 0.08
			lp2 += (lp - lp2) * 0.08
			lp3 += (seq[i] - lp3) * 0.012
			if pass_i == 1:
				noise[i] = (lp2 - lp3 * 0.6)
	var peak := 0.0
	for i in range(n):
		var t: float = float(i) / RATE
		# Whole cycles in 2s: frequencies on the 0.5Hz grid.
		var body: float = sin(TAU * 62.0 * t) * 0.45 + sin(TAU * 93.5 * t + 0.6) * 0.3 + sin(TAU * 141.0 * t + 1.9) * 0.18
		var beat: float = 0.75 + 0.25 * sin(TAU * 3.5 * t)
		var ring: float = (sin(TAU * 612.0 * t) * 0.5 + sin(TAU * 873.5 * t + 1.1) * 0.35 + sin(TAU * 1291.0 * t + 2.3) * 0.2) * (0.5 + 0.5 * sin(TAU * 1.5 * t))
		var v: float = body * beat * (0.6 + 1.6 * absf(noise[i])) + noise[i] * 2.2 + ring * 0.05
		out[i] = v
		peak = maxf(peak, absf(v))
	for i in range(n):
		out[i] /= maxf(peak, 0.001)
	_streams["deck_rumble"] = _pcm(out, true, 0.8)
	return _streams["deck_rumble"]


## A wheel over a plate joint: a short dull clank, a tick of the steel's ring.
static func plate_clank() -> AudioStreamWAV:
	if _streams.has("plate_clank"):
		return _streams["plate_clank"]
	var n: int = int(RATE * 0.18)
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in range(n):
		var t: float = float(i) / RATE
		var thud: float = sin(TAU * (130.0 - 50.0 * minf(t * 30.0, 1.0)) * t) * exp(-t * 45.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.4
		var tick: float = lp * exp(-t * 90.0) * 0.5
		var ring: float = (sin(TAU * 1180.0 * t) + 0.5 * sin(TAU * 1730.0 * t + 0.4)) * exp(-t * 30.0) * 0.18
		out[i] = (thud + tick + ring) * minf(t * 1500.0, 1.0)
	_streams["plate_clank"] = _pcm(out, false, 0.7)
	return _streams["plate_clank"]


## The wheels over a bridge's expansion joint: a heavy metallic bang, its plates rattling, the girders ringing on.
static func deck_clang() -> AudioStreamWAV:
	if _streams.has("deck_clang"):
		return _streams["deck_clang"]
	var n: int = int(RATE * 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in range(n):
		var t: float = float(i) / RATE
		var bang: float = sin(TAU * (88.0 - 30.0 * minf(t * 12.0, 1.0)) * t) * exp(-t * 14.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.45
		var rattle: float = lp * exp(-t * 26.0) * (0.6 + 0.4 * sin(TAU * 38.0 * t))
		var ring: float = (sin(TAU * 410.0 * t) * 0.5 + sin(TAU * 655.0 * t + 0.8) * 0.4 + sin(TAU * 1043.0 * t + 1.7) * 0.3 + sin(TAU * 1580.0 * t + 0.3) * 0.2) * exp(-t * 5.5) * 0.3
		out[i] = (bang + rattle + ring) * minf(t * 1500.0, 1.0)
	_streams["deck_clang"] = _pcm(out, false, 0.9)
	return _streams["deck_clang"]


static func _pcm(samples: PackedFloat32Array, loop: bool, gain: float) -> AudioStreamWAV:
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = int(clampf(samples[i] / maxf(peak, 0.001) * gain, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
