extends RefCounted
## What a cart's tyres are on, and what that looks and sounds like. Only paved road (asphalt,
## concrete, brick) takes rubber and screeches; everything else throws its own spray and makes its
## own sliding noise (regenerate_surface_sounds.gd bakes the loops into generated/surfaces/).
##
## PlayerCart asks of() for the ground under it every physics tick. A collider says what it is with
## a "surface" meta (one of NAMES) on itself or an ancestor below the level, which is how a generator
## should mark a new surface. Older levels have no metas: their entry in LEVELS names the surface of
## their nodes by name, then of track (PlayerCart._is_track_surface) and of everything else.

enum { ASPHALT, DIRT, GRAVEL, SAND, SNOW, ICE, GRASS, MUD, WOOD, ROCK }
const NAMES := ["asphalt", "dirt", "gravel", "sand", "snow", "ice", "grass", "mud", "wood", "rock"]
const COUNT := 10

## Per level (the scene's file name): "road" and "ground" defaults, "nodes", lower-case name
## fragments of a collider or its ancestors that override them (first match wins), "gap", the ground
## where the road stops (TerrainGenerator.road_gaps: Pinecrest Ridge's forest trail) if it isn't the
## level's "ground", and "dust", the colour a surface's dust takes on this level (Mara's murram is
## red, not the default brown).
const LEVELS := {
	"LakesideLevel": {"road": ASPHALT, "ground": GRASS},
	"BloombayDunesLevel": {"road": ASPHALT, "ground": SAND, "nodes": [["pier", WOOD]]},
	"PinecrestRidgeLevel": {"road": ASPHALT, "ground": GRASS, "gap": GRAVEL, "nodes": [["boulder", ROCK]],
		"dust": {GRAVEL: Color(0.62, 0.54, 0.44, 0.6)}},
	"FrostpeakCreekLevel": {"road": ASPHALT, "ground": SNOW, "nodes": [["bridgedeck", WOOD], ["abutment", ROCK], ["snowdrift", SNOW]]},
	"GlacierHighwayLevel": {"road": ASPHALT, "ground": SNOW},
	"NorthlightCavernsLevel": {"road": ICE, "ground": SNOW, "nodes": [["snowbank", SNOW], ["marker", ICE]]},
	"FrostfallGorgeLevel": {"road": SNOW, "ground": SNOW, "nodes": [["boulder", ROCK]]},
	"MountainLevel": {"road": ASPHALT, "ground": SAND, "nodes": [["dune", SAND]]},
	"DesertWadiLevel": {"road": SAND, "ground": SAND, "nodes": [["jumpramp", WOOD]]},
	"CanyonChasmLevel": {"road": DIRT, "ground": GRAVEL, "nodes": [["road_sides", GRAVEL]],
		"dust": {GRAVEL: Color(0.80, 0.56, 0.42, 0.6)}},
	"CanyonLevel": {"road": ASPHALT, "ground": GRAVEL},
	"MaraCrossingLevel": {"road": DIRT, "ground": GRASS, "nodes": [["granite", ROCK]],
		"dust": {DIRT: Color(0.82, 0.46, 0.29, 0.75), GRASS: Color(0.80, 0.68, 0.48, 0.45)}},
	"NyotaStadiumLevel": {"road": ASPHALT, "ground": DIRT, "nodes": [["stadiumtrack", DIRT], ["arenainfield", DIRT], ["streetpaving", ASPHALT]],
		"dust": {DIRT: Color(0.76, 0.52, 0.40, 0.75)}},
	"MtaaNightsLevel": {"road": ASPHALT, "ground": ASPHALT, "dust": {DIRT: Color(0.80, 0.44, 0.28, 0.75), GRAVEL: Color(0.70, 0.64, 0.56, 0.6)}},
	"MsituFallsLevel": {"road": DIRT, "ground": DIRT, "nodes": [["mudroad", MUD], ["bridgedeck", WOOD], ["boulder", ROCK]]},
	"HarborPierLevel": {"road": ASPHALT, "ground": SAND, "nodes": [["breakwater", ROCK]]},
}

## How each surface looks and sounds.
##   dust: colour of the cloud the wheels raise (alpha: how thick; 0 = none), dust_size its puffs'
##     size, dust_rise how much it lifts (it hangs in the air, or falls back like sand), dust_roll how
##     much of it a car raises just driving rather than sliding.
##   grit: colour of what the tyres fling (alpha 0 = nothing), grit_size, grit_gravity.
##   sound: the sliding loop in generated/surfaces/ ("" = the asphalt squeal and screeches),
##     sound_db its level at a full slide (the loops are all baked at -16 dBFS RMS; about -13 puts
##     them level with the asphalt squeal, -21 dBFS played at -8 dB), roll_db how much quieter it
##     plays just rolling at speed (-80: silent when rolling). The surfaces with real recordings
##     (RECORDED_CLIPS: driving-on sounds, not just slides) roll only a few dB under a full slide.
const FX := [
	# ASPHALT
	{"dust": Color(0.90, 0.90, 0.90, 0.0), "dust_size": 0.3, "dust_rise": 0.4, "dust_roll": 0.0,
	"grit": Color(0, 0, 0, 0), "grit_size": 0.0, "grit_gravity": 0.0, "sound": "", "sound_db": 0.0, "roll_db": -80.0},
	# DIRT
	{"dust": Color(0.66, 0.52, 0.38, 0.7), "dust_size": 0.85, "dust_rise": 0.55, "dust_roll": 0.55,
	"grit": Color(0.42, 0.32, 0.22, 1.0), "grit_size": 0.05, "grit_gravity": 11.0, "sound": "skid_dirt", "sound_db": -13.0, "roll_db": -15.0},
	# GRAVEL
	{"dust": Color(0.72, 0.66, 0.58, 0.6), "dust_size": 0.75, "dust_rise": 0.45, "dust_roll": 0.45,
	"grit": Color(0.46, 0.43, 0.40, 1.0), "grit_size": 0.055, "grit_gravity": 14.0, "sound": "skid_gravel", "sound_db": -12.0, "roll_db": -5.0},
	# SAND
	{"dust": Color(0.93, 0.84, 0.64, 0.6), "dust_size": 0.75, "dust_rise": 0.15, "dust_roll": 0.7,
	"grit": Color(0.88, 0.76, 0.52, 1.0), "grit_size": 0.035, "grit_gravity": 12.0, "sound": "skid_sand", "sound_db": -13.5, "roll_db": -5.0},
	# SNOW
	{"dust": Color(0.97, 0.98, 1.0, 0.85), "dust_size": 1.0, "dust_rise": 0.6, "dust_roll": 0.8,
	"grit": Color(0.92, 0.95, 1.0, 1.0), "grit_size": 0.07, "grit_gravity": 7.0, "sound": "skid_snow", "sound_db": -12.5, "roll_db": -5.0},
	# ICE
	{"dust": Color(0.90, 0.95, 1.0, 0.4), "dust_size": 0.35, "dust_rise": 0.3, "dust_roll": 0.0,
	"grit": Color(0.85, 0.93, 1.0, 1.0), "grit_size": 0.03, "grit_gravity": 9.0, "sound": "skid_ice", "sound_db": -13.0, "roll_db": -6.0},
	# GRASS
	{"dust": Color(0.62, 0.58, 0.42, 0.35), "dust_size": 0.45, "dust_rise": 0.4, "dust_roll": 0.3,
	"grit": Color(0.36, 0.48, 0.20, 1.0), "grit_size": 0.05, "grit_gravity": 6.0, "sound": "skid_grass", "sound_db": -14.5, "roll_db": -16.0},
	# MUD
	{"dust": Color(0.30, 0.22, 0.14, 0.45), "dust_size": 0.45, "dust_rise": 0.1, "dust_roll": 0.5,
	"grit": Color(0.24, 0.17, 0.10, 1.0), "grit_size": 0.07, "grit_gravity": 15.0, "sound": "skid_mud", "sound_db": -12.5, "roll_db": -12.0},
	# WOOD
	{"dust": Color(0.70, 0.62, 0.50, 0.25), "dust_size": 0.35, "dust_rise": 0.4, "dust_roll": 0.0,
	"grit": Color(0, 0, 0, 0), "grit_size": 0.0, "grit_gravity": 0.0, "sound": "skid_wood", "sound_db": -13.0, "roll_db": -14.0},
	# ROCK
	{"dust": Color(0.70, 0.67, 0.62, 0.45), "dust_size": 0.45, "dust_rise": 0.45, "dust_roll": 0.0,
	"grit": Color(0.50, 0.47, 0.44, 1.0), "grit_size": 0.045, "grit_gravity": 14.0, "sound": "skid_rock", "sound_db": -13.0, "roll_db": -80.0},
]

const SOUND_DIR := "res://generated/surfaces/"

## Real recorded tyre loops layered in alongside the synthesised ones (scratch/measure_surface_rms.gd):
## [path, gain_db], gain_db normalising the clip's measured RMS to the synthesised loops' -16 dBFS
## baseline, so a surface's existing `sound_db`/`roll_db` still set its level the same way.
## pick_clip() takes one at random whenever a cart enters that surface.
const RECORDED_CLIPS := {
	GRAVEL: [
		["res://sounds/continuous_gravel_tire_1.wav", -11.20],
		["res://sounds/continuous_gravel_tire_2.wav", -11.12],
		["res://sounds/continuous_gravel_tire_3.wav", -11.18],
		["res://sounds/continuous_gravel_tire_4.wav", -11.14],
	],
	SAND: [
		["res://sounds/continuous_sand_crunching.wav", -11.10],
		["res://sounds/continuous_sand_crunching_2.wav", -11.09],
		["res://sounds/continuous_sand_tire_2.wav", -11.20],
	],
	SNOW: [
		["res://sounds/driving_on_snow_1.wav", -10.93],
		["res://sounds/driving_on_snow_2.wav", -11.00],
		["res://sounds/driving_on_snow_3.wav", -10.96],
		["res://sounds/snow_impact_and_driving.wav", -11.09],
	],
	ICE: [
		["res://sounds/driving_on_ice_1.wav", -11.17],
		["res://sounds/driving_on_ice_2.wav", -11.14],
		["res://sounds/driving_on_ice_3.wav", -10.89],
	],
}

static var _streams := {}
static var _key_level_id := 0
static var _key := ""


## The surface of `collider` on the level `level` (its scene's root), which PlayerCart counts as
## track (`is_track`) or not.
static func of(collider: Object, level: Node, is_track: bool) -> int:
	var table: Dictionary = LEVELS.get(_level_key(level), {})
	var rules: Array = table.get("nodes", [])
	var cur: Node = collider as Node
	while cur and cur != level:
		if cur.has_meta(&"surface"):
			return from_name(cur.get_meta(&"surface"))
		var nm := str(cur.name).to_lower()
		for rule in rules:
			if nm.contains(rule[0]):
				return rule[1]
		cur = cur.get_parent()
	if is_track:
		return int(table.get("road", ASPHALT))
	return int(table.get("ground", GRASS))


## The ground in a road gap on `level` (its "gap" entry), else `ground`.
static func of_road_gap(level: Node, ground: int) -> int:
	return int(LEVELS.get(_level_key(level), {}).get("gap", ground))


static func from_name(value: Variant) -> int:
	if value is int:
		return clampi(value, 0, COUNT - 1)
	var i := NAMES.find(str(value).to_lower())
	return i if i >= 0 else ASPHALT


## The colour of the dust `surface` raises on `level`: the level's own, else the surface's.
static func dust_color(surface: int, level: Node) -> Color:
	var table: Dictionary = LEVELS.get(_level_key(level), {})
	var own: Dictionary = table.get("dust", {})
	if own.has(surface):
		return own[surface]
	return fx(surface)["dust"]


## What the tyres fling there: a darker shade of the level's own dust where it has one.
static func grit_color(surface: int, level: Node) -> Color:
	var table: Dictionary = LEVELS.get(_level_key(level), {})
	var own: Dictionary = table.get("dust", {})
	var grit: Color = fx(surface)["grit"]
	if own.has(surface) and grit.a > 0.0:
		var c: Color = (own[surface] as Color).darkened(0.35)
		return Color(c.r, c.g, c.b, 1.0)
	return grit


static func is_paved(surface: int) -> bool:
	return surface == ASPHALT


static func fx(surface: int) -> Dictionary:
	return FX[clampi(surface, 0, COUNT - 1)]


## A sliding loop for `surface` and the extra gain (dB) it needs to sit level with the rest: a
## random take of the real recordings if there are any, else the synthesised loop at 0 dB. Call once
## per surface change (it rerolls the take every call), not every tick.
static func pick_clip(surface: int) -> Dictionary:
	var clips: Array = RECORDED_CLIPS.get(surface, [])
	if not clips.is_empty():
		var pick: Array = clips[randi() % clips.size()]
		var path: String = pick[0]
		if not _streams.has(path):
			_streams[path] = load(path) if ResourceLoader.exists(path) else null
		var s: AudioStream = _streams[path]
		if s != null:
			return {"stream": s, "gain_db": float(pick[1])}
	var nm: String = fx(surface)["sound"]
	if nm.is_empty():
		return {"stream": null, "gain_db": 0.0}
	if not _streams.has(nm):
		var path2 := SOUND_DIR + nm + ".res"
		_streams[nm] = load(path2) if ResourceLoader.exists(path2) else null
	return {"stream": _streams[nm], "gain_db": 0.0}


## The level's scene file name (its LEVELS key), remembered for the last level asked about: every
## cart asks every physics tick.
static func _level_key(level: Node) -> String:
	if level == null:
		return ""
	if level.get_instance_id() == _key_level_id:
		return _key
	var path := str(level.scene_file_path)
	_key = str(level.name) if path.is_empty() else path.get_file().get_basename()
	_key_level_id = level.get_instance_id()
	return _key
