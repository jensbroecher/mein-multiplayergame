extends RefCounted
## The Al-Raihana GP's ground shapes, called by TerrainGenerator for Mountain Pass ("mountain") and Desert
## Wadi ("desert_wadi") in place of their plain FBM noise, which read as blobs, not dunes:
##
##   dunes(p)   a field of transverse dunes across the shamal (the north-west wind): each a long gentle
##              windward slope up to a sharp crest and a steep slip face down the lee, the crest lines
##              wandering and breaking into barchan-like segments, smaller dunes riding on the big ones
##              and flat gravel pans (serir) between them where the sand runs thin.
##   jebel(p)   the rock of a mountain: spurs and gullies running down from the summit (ridged noise
##              stretched along the radius), broken crags on top, so the cone reads as a range, not a
##              heap of sand.
##
## Both are static and deterministic: TerrainGenerator, the dressers and the probes all get the same
## heights. Heights are in metres, positions in world xz.

## The shamal blows from the north-west toward the south-east; dune crests run across it.
const WIND := Vector2(0.78, 0.62)
## Dune spacing (metres crest to crest) and how much of it the slip face takes.
const DUNE_WAVELENGTH := 150.0
const SLIP_SHARE := 0.3
## Big dunes up to DUNE_HEIGHT; the small ones riding on them are SMALL_HEIGHT.
const DUNE_HEIGHT := 17.0
const SMALL_WAVELENGTH := 46.0
const SMALL_HEIGHT := 2.6

static var _warp: FastNoiseLite
static var _amp: FastNoiseLite
static var _crest: FastNoiseLite
static var _ridge: FastNoiseLite
static var _crag: FastNoiseLite


static func _noises() -> void:
	if _warp != null:
		return
	_warp = FastNoiseLite.new()
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp.frequency = 0.0022
	_warp.fractal_octaves = 2
	_warp.seed = 7101
	_amp = FastNoiseLite.new()
	_amp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_amp.frequency = 0.0035
	_amp.fractal_type = FastNoiseLite.FRACTAL_NONE
	_amp.seed = 7202
	_crest = FastNoiseLite.new()
	_crest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_crest.frequency = 0.011
	_crest.fractal_type = FastNoiseLite.FRACTAL_NONE
	_crest.seed = 7303
	_ridge = FastNoiseLite.new()
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.0075
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 3
	_ridge.fractal_gain = 0.42
	_ridge.seed = 7404
	_crag = FastNoiseLite.new()
	_crag.noise_type = FastNoiseLite.TYPE_CELLULAR
	_crag.frequency = 0.03
	_crag.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	_crag.fractal_type = FastNoiseLite.FRACTAL_NONE
	_crag.seed = 7505


## One dune's profile over a phase 0..1 (crest at 1 - SLIP_SHARE): a convex windward rise and a steep,
## slightly concave slip face. Sharp at the crest on purpose: real crests are knife edges.
static func _profile(ph: float, slip: float) -> float:
	var crest := 1.0 - slip
	if ph < crest:
		var s := ph / crest
		# Rises slowly off the interdune flat, steepest just under the crest.
		return s * s * (1.6 - 0.6 * s)
	var t := (ph - crest) / slip
	return pow(1.0 - t, 1.7)


## The dune field's height at (x, z), 0 on the interdune flats up to about DUNE_HEIGHT + SMALL_HEIGHT.
## `scale` 0..1 shrinks it (where the field fades into something else).
static func dunes(x: float, z: float, scale := 1.0) -> float:
	_noises()
	if scale <= 0.0:
		return 0.0
	var w := WIND.normalized()
	var across := Vector2(-w.y, w.x)
	var p := Vector2(x, z)
	# Along the wind, warped across it so the crest lines wander and fork.
	var u: float = p.dot(w) + _warp.get_noise_2d(x, z) * 70.0
	var v: float = p.dot(across)
	var ph: float = fposmod(u / DUNE_WAVELENGTH, 1.0)
	var big: float = _profile(ph, SLIP_SHARE)
	# The crest's height wanders along it (v) and breaks into segments: barchan horns where it drops.
	var seg: float = 0.55 + 0.45 * _crest.get_noise_2d(v * 0.7, floorf(u / DUNE_WAVELENGTH) * 37.0)
	var amp: float = clampf(0.55 + 0.6 * _amp.get_noise_2d(x, z), 0.0, 1.0)
	var h: float = big * DUNE_HEIGHT * amp * clampf(seg, 0.15, 1.0)
	# Small dunes riding on the big ones, oblique to them, fewer on the flats.
	var w2 := w.rotated(0.35)
	var u2: float = p.dot(w2) + _warp.get_noise_2d(x * 2.3 + 400.0, z * 2.3) * 22.0
	var ph2: float = fposmod(u2 / SMALL_WAVELENGTH, 1.0)
	h += _profile(ph2, 0.3) * SMALL_HEIGHT * (0.35 + 0.65 * amp)
	return h * scale


## How much of the ground at (x, z) is a gravel pan between dunes (0..1): where the dune field's sand
## runs thin. The ground shader paints it; the dressers put the stones there.
static func serir(x: float, z: float) -> float:
	_noises()
	var amp: float = clampf(0.55 + 0.6 * _amp.get_noise_2d(x, z), 0.0, 1.0)
	return 1.0 - smoothstep(0.05, 0.35, amp)


## The rock of a mountain whose summit is at `centre`, `radius` across the foot: spurs and gullies running
## down from the top (ridged noise stretched along the radius) and crags, scaled by `share` 0..1 (how far
## up the mountain this is). Returns metres to add to the mountain's smooth cone, roughly -9..+16.
static func jebel(x: float, z: float, centre: Vector2, share: float) -> float:
	_noises()
	if share <= 0.0:
		return 0.0
	var d := Vector2(x, z) - centre
	var r := d.length()
	var a := atan2(d.y, d.x)
	# Half in polar terms, so the spurs run down the slope (the radius slowed against the angle), warped so
	# they bend and fork instead of radiating like spokes.
	var wa: float = a + _warp.get_noise_2d(x * 1.7, z * 1.7) * 0.9
	# Near the summit the polar part fades out (the angle is meaningless there and pinched to a star).
	var polar: float = smoothstep(20.0, 140.0, r)
	var sx: float = cos(wa) * (r * 0.45 + 110.0) * polar + x * 0.6
	var sz: float = sin(wa) * (r * 0.45 + 110.0) * polar + z * 0.6
	var ridges: float = _ridge.get_noise_2d(sx, sz)   # -1..1, ridged
	var crags: float = clampf(_crag.get_noise_2d(x, z) * 1.4, -1.0, 1.0)
	var spur: float = (ridges * 0.5 + 0.5)
	return (spur * 22.0 - 9.0 + crags * 3.5) * share


## Ramlat Hamra's sand sea: linear (seif) dunes running east-west, MEGA_SPACING apart, each a ridge MEGA_HEIGHT high
## with a sharp crest and MEGA_HALF either side of it, salt-crusted corridors (sabkha) flat between them; lower
## stretches of the middle ridge where the lap goes over it off-road (MEGA_SADDLES: x, how far down, half width), a great star dune (MEGA_PEAK), and the small
## dunes riding on the ridges. Ridge centres lie at z = MEGA_RIDGE_Z + k * MEGA_SPACING.
const MEGA_SPACING := 350.0
const MEGA_RIDGE_Z := 15.0
const MEGA_HALF := 0.3
const MEGA_HEIGHT := 50.0
## Where the lap crosses the middle ridge off-road (Ramlat Hamra): low enough to drive, still 30m over the salt.
const MEGA_SADDLES := [Vector3(430.0, 0.12, 80.0), Vector3(40.0, 0.1, 70.0)]
const MEGA_PEAK := Vector3(-120.0, 365.0, 46.0)

static func megadunes(x: float, z: float) -> float:
	_noises()
	var warp: float = _warp.get_noise_2d(x * 0.5, z * 0.5) * 34.0
	var ph: float = fposmod((z - MEGA_RIDGE_Z - warp) / MEGA_SPACING + 0.5, 1.0) - 0.5
	var t: float = clampf(1.0 - absf(ph) / MEGA_HALF, 0.0, 1.0)
	# A concave foot rising to a knife-edge crest; steeper on the south (lee) side.
	var prof: float = pow(t, 1.5 if ph < 0.0 else 1.25)
	var amp: float = MEGA_HEIGHT * clampf(0.72 + 0.4 * _amp.get_noise_2d(x * 0.6, z), 0.35, 1.05)
	# The crest's height wanders along the ridge (it never runs level for long).
	amp *= 0.8 + 0.2 * _crest.get_noise_2d(x * 0.5, floorf((z - MEGA_RIDGE_Z) / MEGA_SPACING + 0.5) * 51.0)
	var ridge_k: float = floorf((z - MEGA_RIDGE_Z) / MEGA_SPACING + 0.5)
	if ridge_k == 0.0:
		for s in MEGA_SADDLES:
			amp *= 1.0 - float(s.y) * exp(-pow((x - float(s.x)) / float(s.z), 2.0))
	var h: float = amp * prof
	var pd: float = Vector2(x - MEGA_PEAK.x, z - MEGA_PEAK.y).length()
	h += MEGA_PEAK.z * pow(clampf(1.0 - pd / 190.0, 0.0, 1.0), 1.6)
	# Small dunes on the ridges' flanks, ripples of sand across the corridors.
	h += dunes(x, z, 0.12 + 0.6 * smoothstep(0.0, 0.3, t))
	return h


## How much of (x, z) is a sabkha corridor's salt flat (0..1): the flat between the ridges.
static func sabkha(x: float, z: float) -> float:
	_noises()
	var warp: float = _warp.get_noise_2d(x * 0.5, z * 0.5) * 34.0
	var ph: float = fposmod((z - MEGA_RIDGE_Z - warp) / MEGA_SPACING + 0.5, 1.0) - 0.5
	return smoothstep(MEGA_HALF + 0.02, MEGA_HALF + 0.08, absf(ph))


## Marina Nights (Al-Raihana GP, stage 4): the city on its shore. Land at MARINA_LAND, the sea south of the coast
## (`coast_z`), the creek (`creek_x`, MARINA_CREEK_HALF wide either side) running inland from the sea to its head at
## MARINA_CREEK_HEAD; quays drop steeply to the bed (the quay walls are the dresser's).
const MARINA_LAND := 2.2
const MARINA_BED := -4.5
const MARINA_CREEK_HALF := 30.0
const MARINA_CREEK_HEAD := -250.0

static func coast_z(x: float) -> float:
	return 235.0 + 18.0 * sin(x / 140.0) + 6.0 * sin(x / 47.0 + 1.3)


static func creek_x(z: float) -> float:
	return 60.0 + 28.0 * sin(z / 110.0)


## How far (x, z) lies inside the water (negative on land), in metres: the sea, the creek and its rounded head.
static func marina_water_d(x: float, z: float) -> float:
	var sea: float = z - coast_z(x)
	var cz: float = maxf(z, MARINA_CREEK_HEAD)
	var across: float = absf(x - creek_x(cz))
	var creek: float = MARINA_CREEK_HALF - Vector2(across, z - cz).length()
	return maxf(sea, creek)


static func marina_height(x: float, z: float) -> float:
	var w: float = marina_water_d(x, z)
	if w < -1.0:
		return MARINA_LAND
	# The quay: land to the wall's foot within a metre and a half, the bed past it, deeper out to sea.
	var t: float = smoothstep(-1.0, 1.5, w)
	var bed: float = MARINA_BED - clampf((z - coast_z(x)) / 60.0, 0.0, 1.0) * 6.0
	return lerpf(MARINA_LAND, bed, t)
