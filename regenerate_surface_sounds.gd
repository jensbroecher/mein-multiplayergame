# regenerate_surface_sounds.gd
#
# Bakes the tyre-sliding loops that PlayerCart plays off asphalt (Surfaces.gd): one seamless loop per
# surface, synthesised from filtered noise, saved as generated/surfaces/skid_<surface>.res. Asphalt
# keeps its recorded squeal and screeches.
#
# Each loop is a mix of layers, each scaled to unit RMS before mixing so the weights read as
# loudness: grains (a crackle of short clicks, the stones and grit), band-passed noise (the scrub),
# low noise (the rumble of the tyre ploughing), and per surface a crunch envelope (snow), a stick-slip
# chatter (ice, rock), resonant knocks (planks) or a sweeping formant (mud). The loop's tail is
# crossfaded into its head with equal power, and the whole loop is levelled to LOOP_RMS.
#
# Run headless from the project root:
#   Godot --headless --path . res://regenerate_surface_sounds.tscn
extends Node

const RATE := 44100
const SECONDS := 2.4
const FADE := 0.3
## Every loop's RMS (about -16 dBFS); PlayerCart sets each surface's level (Surfaces.FX sound_db).
const LOOP_RMS := 0.16
const OUT_DIR := "res://generated/surfaces/"

var rng := RandomNumberGenerator.new()
var n := 0


class Bandpass:
	# RBJ band-pass with 0 dB peak; set() retunes it without clearing its state.
	var b0 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func _init(f0: float, q: float) -> void:
		set_to(f0, q)

	func set_to(f0: float, q: float) -> void:
		var w0: float = TAU * f0 / float(RATE)
		var alpha: float = sin(w0) / (2.0 * q)
		var a0: float = 1.0 + alpha
		b0 = alpha / a0
		b2 = -alpha / a0
		a1 = -2.0 * cos(w0) / a0
		a2 = (1.0 - alpha) / a0

	func run(x: float) -> float:
		var y: float = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y


func _pole(cutoff: float) -> float:
	return 1.0 - exp(-TAU * cutoff / float(RATE))


# --------------------------------------------------------------------------------------
#  Layers (each n samples long)
# --------------------------------------------------------------------------------------

## A crackle: clicks at `per_sec` (Poisson), each a burst of noise decaying over `tau_ms`, through a
## band-pass at `f0`. Click sizes are rand^size_exp, so most are small and a few stand out.
func _grains(per_sec: float, tau_ms: float, f0: float, q: float, size_exp: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var p: float = per_sec / float(RATE)
	var decay: float = exp(-1.0 / (tau_ms * 0.001 * RATE))
	var bp := Bandpass.new(f0, q)
	var env := 0.0
	for i in range(n):
		if rng.randf() < p:
			env = maxf(env, 0.06 + pow(rng.randf(), size_exp))
		env *= decay
		out[i] = bp.run(rng.randf_range(-1.0, 1.0) * env)
	return out


func _band_noise(f0: float, q: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var bp := Bandpass.new(f0, q)
	for i in range(n):
		out[i] = bp.run(rng.randf_range(-1.0, 1.0))
	return out


## Noise through two one-pole low-passes at `cutoff`.
func _low_noise(cutoff: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var a: float = _pole(cutoff)
	var y1 := 0.0
	var y2 := 0.0
	for i in range(n):
		y1 += (rng.randf_range(-1.0, 1.0) - y1) * a
		y2 += (y1 - y2) * a
		out[i] = y2
	return out


## Noise above `lo` and below `hi` (one-pole each way).
func _high_noise(lo: float, hi: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var a_lo: float = _pole(lo)
	var a_hi: float = _pole(hi)
	var low := 0.0
	var top := 0.0
	for i in range(n):
		var w: float = rng.randf_range(-1.0, 1.0)
		top += (w - top) * a_hi
		low += (top - low) * a_lo
		out[i] = top - low
	return out


## A wavering gain around 1: new random targets `per_sec` times a second, smoothed, +-depth.
func _flutter(per_sec: float, depth: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var hold: int = maxi(1, int(RATE / per_sec))
	var a: float = _pole(per_sec * 1.5)
	var target := 0.0
	var v := 0.0
	for i in range(n):
		if i % hold == 0:
			target = rng.randf_range(-1.0, 1.0)
		v += (target - v) * a
		out[i] = maxf(0.0, 1.0 + v * depth)
	return out


## Stick-slip: a pulsing gain at about `hz`, each cycle's length and depth jittered.
func _chatter(hz: float, jitter: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var f: float = hz
	var depth := 1.0
	for i in range(n):
		phase += f / float(RATE)
		if phase >= 1.0:
			phase -= 1.0
			f = hz * rng.randf_range(1.0 - jitter, 1.0 + jitter)
			depth = rng.randf_range(0.5, 1.0)
		# Grip, then a sharp slip at the start of each cycle.
		out[i] = 0.25 + depth * exp(-phase * 6.0)
	return out


## Crunches: events at about `per_sec` (jittered spacing), each a fast rise and a decay of
## `decay_ms` (+-40%), event sizes varied.
func _crunch_env(per_sec: float, decay_ms: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var next := 0
	var env := 0.0
	var peak := 0.0
	var attack := 0
	var decay := 0.0
	var since := 0
	for i in range(n):
		if i >= next:
			peak = rng.randf_range(0.45, 1.0)
			attack = int(RATE * rng.randf_range(0.002, 0.006))
			decay = exp(-1.0 / (decay_ms * 0.001 * RATE * rng.randf_range(0.6, 1.4)))
			since = 0
			next = i + int(RATE / per_sec * rng.randf_range(0.45, 1.55))
		if since < attack:
			env = maxf(env, peak * float(since) / float(maxi(attack, 1)))
		else:
			env *= decay
		since += 1
		out[i] = env
	return out


## Planks: a hollow knock at about `per_sec`, each a damped sine near `f0` and a click.
func _knocks(per_sec: float, f0: float, decay_ms: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var next := 0
	var amp := 0.0
	var f := f0
	var ph := 0.0
	var decay: float = exp(-1.0 / (decay_ms * 0.001 * RATE))
	var click := 0.0
	var click_decay: float = exp(-1.0 / (0.0007 * RATE))
	var hp_y := 0.0
	var a_hp: float = _pole(1500.0)
	for i in range(n):
		if i >= next:
			amp = rng.randf_range(0.5, 1.0)
			f = f0 * rng.randf_range(0.8, 1.25)
			click = amp
			next = i + int(RATE / per_sec * rng.randf_range(0.7, 1.3))
		ph += TAU * f / float(RATE)
		amp *= decay
		click *= click_decay
		var w: float = rng.randf_range(-1.0, 1.0) * click
		hp_y += (w - hp_y) * a_hp
		# The board's note plus its first overtone, and the edge of the tyre on the next plank.
		out[i] = (sin(ph) + 0.35 * sin(ph * 2.7)) * amp + (w - hp_y) * 0.8
	return out


## Squelch: noise through a band-pass whose centre wanders between 180 and 650Hz and is swept
## down from ~900Hz at each slurp (`per_sec`).
func _squelch(per_sec: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	var bp := Bandpass.new(300.0, 4.0)
	var base := 350.0
	var base_target := 350.0
	var sweep := 0.0
	var next := 0
	var a: float = _pole(3.0)
	var sweep_decay: float = exp(-1.0 / (0.07 * RATE))
	for i in range(n):
		if i >= next:
			sweep = rng.randf_range(250.0, 600.0)
			base_target = rng.randf_range(180.0, 650.0)
			next = i + int(RATE / per_sec * rng.randf_range(0.5, 1.5))
		base += (base_target - base) * a
		sweep *= sweep_decay
		if i % 32 == 0:
			bp.set_to(base + sweep, 3.5)
		out[i] = bp.run(rng.randf_range(-1.0, 1.0)) * (0.6 + sweep / 600.0)
	return out


func _mul(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		out[i] = a[i] * b[i]
	return out


func _rms(a: PackedFloat32Array) -> float:
	var s := 0.0
	for v in a:
		s += v * v
	return sqrt(s / float(maxi(a.size(), 1)))


## Mixes [weight, layer] pairs, each layer at unit RMS first.
func _mix(layers: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(n)
	for l in layers:
		var w: float = l[0]
		var a: PackedFloat32Array = l[1]
		var g: float = w / maxf(_rms(a), 1e-6)
		for i in range(n):
			out[i] += a[i] * g
	return out


# --------------------------------------------------------------------------------------
#  Surfaces
# --------------------------------------------------------------------------------------

func _gravel() -> PackedFloat32Array:
	return _mix([
		[1.0, _grains(1300.0, 1.0, 3500.0, 0.8, 2.2)],
		[0.55, _grains(220.0, 2.5, 1600.0, 1.0, 3.0)],
		[0.35, _mul(_band_noise(1100.0, 0.7), _flutter(18.0, 0.4))],
		[0.40, _mul(_low_noise(160.0), _flutter(6.0, 0.3))],
	])


func _dirt() -> PackedFloat32Array:
	return _mix([
		[0.8, _mul(_band_noise(650.0, 0.8), _flutter(14.0, 0.5))],
		[0.45, _grains(380.0, 1.6, 2200.0, 0.8, 2.5)],
		[0.7, _mul(_low_noise(140.0), _flutter(5.0, 0.35))],
		[0.25, _mul(_band_noise(2500.0, 1.2), _flutter(25.0, 0.6))],
	])


func _sand() -> PackedFloat32Array:
	return _mix([
		[0.8, _mul(_high_noise(1100.0, 4500.0), _flutter(40.0, 0.35))],
		[0.65, _mul(_band_noise(450.0, 0.7), _flutter(4.0, 0.4))],
		[0.25, _grains(4000.0, 0.4, 3800.0, 0.9, 1.5)],
		[0.35, _low_noise(120.0)],
	])


func _snow() -> PackedFloat32Array:
	var crunch := _crunch_env(16.0, 60.0)
	var thump := _crunch_env(7.0, 90.0)
	return _mix([
		[1.0, _mul(_grains(5000.0, 0.35, 2600.0, 1.1, 1.8), crunch)],
		[0.25, _mul(_band_noise(3300.0, 8.0), crunch)],
		[0.35, _mul(_high_noise(1500.0, 6000.0), _flutter(20.0, 0.5))],
		[0.45, _mul(_low_noise(110.0), thump)],
	])


func _ice() -> PackedFloat32Array:
	var chatter := _chatter(36.0, 0.25)
	return _mix([
		[0.9, _mul(_high_noise(1800.0, 6500.0), chatter)],
		[0.3, _mul(_band_noise(1900.0, 18.0), _flutter(3.0, 0.5))],
		[0.25, _grains(70.0, 0.8, 4500.0, 0.9, 2.0)],
		[0.3, _mul(_low_noise(200.0), chatter)],
	])


func _grass() -> PackedFloat32Array:
	return _mix([
		[0.9, _mul(_band_noise(1000.0, 0.5), _flutter(22.0, 0.6))],
		[0.35, _grains(160.0, 1.8, 3200.0, 0.9, 2.5)],
		[0.40, _mul(_low_noise(90.0), _flutter(4.0, 0.3))],
	])


func _mud() -> PackedFloat32Array:
	return _mix([
		[0.9, _squelch(9.0)],
		[0.6, _mul(_low_noise(140.0), _flutter(6.0, 0.6))],
		[0.25, _grains(90.0, 3.0, 1800.0, 1.0, 2.0)],
	])


func _wood() -> PackedFloat32Array:
	return _mix([
		[1.0, _knocks(13.0, 210.0, 40.0)],
		[0.45, _mul(_band_noise(900.0, 0.8), _flutter(16.0, 0.4))],
		[0.35, _low_noise(110.0)],
	])


func _rock() -> PackedFloat32Array:
	return _mix([
		[0.8, _grains(500.0, 0.8, 4200.0, 0.8, 2.0)],
		[0.6, _mul(_band_noise(2200.0, 1.0), _chatter(55.0, 0.3))],
		[0.35, _low_noise(150.0)],
	])


# --------------------------------------------------------------------------------------
#  Build
# --------------------------------------------------------------------------------------

## Crossfades the tail into the head (equal power) so the loop has no seam, levels it to LOOP_RMS
## with a soft limit on the peaks, and saves it.
func _save_loop(raw: PackedFloat32Array, surface: String) -> void:
	var fade: int = int(FADE * RATE)
	var loop_n: int = n - fade
	var s := PackedFloat32Array()
	s.resize(loop_n)
	for i in range(loop_n):
		s[i] = raw[i]
	for i in range(fade):
		var t: float = float(i) / float(fade)
		s[i] = raw[i] * sqrt(t) + raw[loop_n + i] * sqrt(1.0 - t)
	# A gentle top cut (one pole at 9kHz, run twice round so the loop point stays seamless).
	var a_top: float = _pole(9000.0)
	var y := 0.0
	for k in range(2):
		for i in range(loop_n):
			y += (s[i] - y) * a_top
			if k == 1:
				s[i] = y
	var g: float = LOOP_RMS / maxf(_rms(s), 1e-6)
	var data := PackedByteArray()
	data.resize(loop_n * 2)
	var peak := 0.0
	for i in range(loop_n):
		var v: float = tanh(s[i] * g * 1.1) / 1.1
		peak = maxf(peak, absf(v))
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = loop_n
	var path: String = OUT_DIR + "skid_" + surface + ".res"
	wav.take_over_path(path)
	var err := ResourceSaver.save(wav, path)
	if err != OK:
		push_error("Could not save %s: %d" % [path, err])
	print("  %s: %.2fs, peak %.2f" % [path, float(loop_n) / RATE, peak])


func _ready() -> void:
	print("=== Surface sounds ===")
	var t0 := Time.get_ticks_msec()
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)
	n = int((SECONDS + FADE) * RATE)
	var builders := {
		"gravel": _gravel, "dirt": _dirt, "sand": _sand, "snow": _snow, "ice": _ice,
		"grass": _grass, "mud": _mud, "wood": _wood, "rock": _rock,
	}
	var seed := 101
	for surface in builders:
		rng.seed = seed
		seed += 37
		_save_loop((builders[surface] as Callable).call(), surface)
	print("Done in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	get_tree().quit(0)
