extends Node
## The recorded background of each stage (sounds/<kind>/): birds and insects over the meadows, the
## woods, the beach, the stadium crowd, the rainforest, wind and snow. Level adds one; it plays under
## a level's own baked ambiences (Bloombay's surf, Msitu's forest, the winter wind), never instead.
##
## A stage has one or two layers, each a kind of clip at a level. A layer plays its clips in random
## order, crossfading into the next before one ends (the clips don't loop). The recordings were made
## at very different levels (-12 to -49 dBFS), so each is brought to its layer's level by its own
## measured loudness (CLIP_DB, the clip's RMS in dBFS).

const CROSSFADE := 4.0

## Measured RMS (dBFS) of every clip.
const CLIP_DB := {
	"res://sounds/beach/beach_ambiance_1.wav": -33.2,
	"res://sounds/beach/beach_ambiance_2.wav": -25.5,
	"res://sounds/beach/beach_ambiance_3.wav": -28.7,
	"res://sounds/beach/beach_ambiance_4.wav": -46.1,
	"res://sounds/city/city_ambiance1.wav": -39.7,
	"res://sounds/city/city_ambiance2.wav": -34.3,
	"res://sounds/city/city_ambiance3.wav": -34.5,
	"res://sounds/city/city_ambiance4.wav": -40.5,
	"res://sounds/harbor/harbor_pier_ambiance.wav": -35.4,
	"res://sounds/harbor/harbor_pier_ambiance2.wav": -40.8,
	"res://sounds/blizzard/blizzard_1.wav": -20.5,
	"res://sounds/blizzard/blizzard_2.wav": -22.3,
	"res://sounds/blizzard/blizzard_3.wav": -11.7,
	"res://sounds/blizzard/blizzard_4.wav": -30.3,
	"res://sounds/forest/forest_ambience_1.wav": -42.2,
	"res://sounds/forest/forest_ambience_2.wav": -48.2,
	"res://sounds/forest/forest_ambience_3.wav": -47.6,
	"res://sounds/insects_birds/birds_chirping,_inse_1.wav": -45.0,
	"res://sounds/insects_birds/birds_chirping,_inse_2.wav": -46.5,
	"res://sounds/insects_birds/birds_chirping,_inse_3.wav": -49.5,
	"res://sounds/insects_birds/birds_chirping,_inse_4.wav": -41.6,
	"res://sounds/rainforest/tropical_rainforest_1.wav": -44.0,
	"res://sounds/rainforest/tropical_rainforest_2.wav": -44.5,
	"res://sounds/rainforest/tropical_rainforest_3.wav": -37.0,
	"res://sounds/rainforest/tropical_rainforest_4.wav": -45.6,
	"res://sounds/stadium/stadium_ambiance_1.wav": -29.3,
	"res://sounds/stadium/stadium_ambiance_2.wav": -37.3,
	"res://sounds/stadium/stadium_ambiance_3.wav": -15.0,
	"res://sounds/stadium/stadium_ambiance_4.wav": -14.9,
}

## Per stage (the level file's name): [kind, level in dBFS] layers. Stages not listed have none
## (the deserts, Mountain Pass's dunes included: nothing recorded suits them, and the forest's
## birdsong over sand dunes didn't fit).
const STAGES := {
	"LakesideLevel": [["insects_birds", -31.0], ["forest", -37.0]],
	"PinecrestRidgeLevel": [["forest", -30.0], ["insects_birds", -38.0]],
	# The harbour's own recordings, the town all round it under them (the boat engines and horns are SeaBoat's, in 3D).
	"HarborPierLevel": [["harbor", -30.0], ["city", -38.0]],
	"BloombayDunesLevel": [["beach", -32.0]],
	"MaraCrossingLevel": [["insects_birds", -30.0]],
	"NyotaStadiumLevel": [["stadium", -27.0]],
	"MsituFallsLevel": [["rainforest", -30.0]],
	"MtaaNightsLevel": [["stadium", -36.0]],
	"MarinaNightsLevel": [["city", -36.0], ["harbor", -38.0]],
	"FrostpeakCreekLevel": [["blizzard", -37.0]],
	"GlacierHighwayLevel": [["blizzard", -37.0]],
	"FrostfallGorgeLevel": [["blizzard", -36.0]],
	"NorthlightCavernsLevel": [["blizzard", -33.0]],
}

## The crowd's roar (a 13s swell that dies away), on the stages with a stadium crowd: at the green light and when
## the first racer finishes (`roar()`, from Level). Its measured RMS and the level it is brought to.
const ROAR := "res://sounds/Huge_stadium_crowd.wav"
const ROAR_DB := -15.1
const ROAR_LEVEL := -21.0

## Grandstands (a node named "Grandstand": Lakeside, Bloombay Dunes, Mina del Viento's at the finish) cheer at the same
## moments, in 3D from the stand's middle: a smaller crowd than a stadium's, heard from the start or the finish
## beside it (Mina's stands 4.7km from the start, so only its finish hears it).
const CHEER := "res://sounds/Fans_cheering.wav"
const CHEER_DB := -1.0
const CHEER_UNIT := 35.0

var _layers: Array = []
var _roar: AudioStreamPlayer
var _cheers: Array[AudioStreamPlayer3D] = []


## The layers for the stage at `level_path`, or none.
static func layers_for(level_path: String) -> Array:
	return STAGES.get(level_path.get_file().get_basename(), [])


func setup(level_path: String) -> void:
	name = "StageAmbience"
	for l in layers_for(level_path):
		var clips: Array = CLIP_DB.keys().filter(func(p: String): return p.begins_with("res://sounds/%s/" % l[0]))
		if clips.is_empty():
			continue
		clips.shuffle()
		# Loaded with the stage: loading a 30s clip mid-race would stall a frame.
		var streams: Array = clips.map(func(p: String): return load(p))
		var players: Array = []
		for i in range(2):
			var ap := AudioStreamPlayer.new()
			ap.bus = &"SFX"
			add_child(ap)
			players.append(ap)
		_layers.append({"clips": clips, "streams": streams, "next": 0, "level": float(l[1]), "players": players, "on": 0})
		if l[0] == "stadium" and _roar == null:
			_roar = AudioStreamPlayer.new()
			_roar.stream = load(ROAR)
			_roar.bus = &"SFX"
			# The stadium layer's own level sets how loud its crowd roars (Mtaa's club is quieter than Nyota's bowl).
			_roar.volume_db = ROAR_LEVEL - ROAR_DB + (float(l[1]) + 27.0)
			add_child(_roar)


## The crowd roars, where there is one; a roar already under way isn't cut short.
func roar() -> void:
	if _roar != null and not _roar.playing:
		_roar.play()
	for ap in _cheers:
		if not ap.playing:
			ap.pitch_scale = randf_range(0.94, 1.06)
			ap.play()


## Where the grandstands' cheers come from (for tests).
func cheer_spots() -> Array:
	return _cheers.map(func(ap: AudioStreamPlayer3D) -> Vector3: return ap.global_position)


func _ready() -> void:
	for layer in _layers:
		_start_next(layer, 0.0)
	_find_grandstands(get_parent())


func _find_grandstands(level: Node) -> void:
	if level == null:
		return
	var stream: AudioStream = null
	for g in level.find_children("Grandstand", "Node3D", true, false):
		# Its middle: the meshes under it (or it), which are often built in world space round an origin elsewhere.
		var box := AABB()
		var any := false
		var meshes: Array = g.find_children("*", "MeshInstance3D", true, false)
		if g is MeshInstance3D:
			meshes.append(g)
		for m in meshes:
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			var b: AABB = mi.global_transform * mi.mesh.get_aabb()
			box = b if not any else box.merge(b)
			any = true
		if stream == null:
			stream = load(CHEER)
		var ap := AudioStreamPlayer3D.new()
		ap.stream = stream
		ap.bus = &"SFX"
		ap.volume_db = CHEER_DB
		ap.unit_size = CHEER_UNIT
		ap.max_distance = 400.0
		add_child(ap)
		ap.global_position = box.get_center() if any else (g as Node3D).global_position
		_cheers.append(ap)


func _process(_delta: float) -> void:
	for layer in _layers:
		var ap: AudioStreamPlayer = layer["players"][layer["on"]]
		if not ap.playing or ap.stream == null:
			_start_next(layer, 0.0)
		elif ap.get_playback_position() > ap.stream.get_length() - CROSSFADE and not ap.has_meta(&"fading"):
			_start_next(layer, CROSSFADE)


## Starts the layer's next clip on its other player, fading it in over `fade` s while the one
## playing fades out.
func _start_next(layer: Dictionary, fade: float) -> void:
	var clips: Array = layer["clips"]
	var path: String = clips[layer["next"]]
	var stream: AudioStream = layer["streams"][layer["next"]]
	layer["next"] = (int(layer["next"]) + 1) % clips.size()
	var old: AudioStreamPlayer = layer["players"][layer["on"]]
	layer["on"] = 1 - int(layer["on"])
	var ap: AudioStreamPlayer = layer["players"][layer["on"]]
	ap.remove_meta(&"fading")
	ap.stream = stream
	var target: float = float(layer["level"]) - float(CLIP_DB[path])
	ap.volume_db = target - 30.0 if fade > 0.0 else target
	ap.play(0.0 if fade > 0.0 else randf() * maxf(ap.stream.get_length() - CROSSFADE * 2.0, 0.0))
	if fade > 0.0:
		ap.create_tween().tween_property(ap, "volume_db", target, fade)
		if old.playing:
			old.set_meta(&"fading", true)
			var tw := old.create_tween()
			tw.tween_property(old, "volume_db", old.volume_db - 30.0, fade)
			tw.tween_callback(old.stop)
