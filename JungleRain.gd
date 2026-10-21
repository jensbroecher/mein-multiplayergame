# JungleRain.gd
#
# Tropical downpours on Msitu Falls (mvua, "rain"). Every so often the light goes, the rain comes
# down in sheets, the distance closes in, thunder rolls round the gorge, and the laterite turns
# slick; after the storm the road takes the best part of a minute to dry.
#
# The schedule runs on the wall clock, like WildebeestHerd and NorthlightWeather, so every LAN peer
# sees the same storm at the same moment without anything being synced. The road gets slippery
# through the "ice_grip" meta on its collision bodies, which PlayerCart reads every physics frame
# (and the AI brakes for), so every peer drives on the same grip too.
extends Node3D

## Seconds per weather window. Each window holds at most one storm.
@export var cycle_seconds := 110.0
@export_range(0.0, 1.0) var storm_chance := 0.6
@export var storm_min_seconds := 24.0
@export var storm_max_seconds := 42.0
## Build-up and die-down at either end of a storm.
@export var ramp_seconds := 7.0
## Seconds for the soaked road to dry most of the way (e-folding time) once the rain stops.
@export var dry_seconds := 22.0
@export var rng_seed := 4410
## Road grip at full wetness, as a share of its dry grip (each body keeps its dry grip in the
## "dry_grip" meta).
@export_range(0.0, 1.0) var wet_grip := 0.7
## The road collision bodies whose grip the rain lowers.
@export var road_paths: Array[NodePath] = []
## The ground's material: its `wetness` follows the road's.
@export var ground_material: ShaderMaterial
@export var sun_path: NodePath
## The sky (sky_tropical_cumulus.gdshader): it clouds over and darkens with the storm via the
## rain_sky_blend global uniform, smoothly interpolating every frame without radiance map stalls.
@export var sky_material: ShaderMaterial
@export var storm_sky_top := Color(0.30, 0.34, 0.38)
@export var storm_sky_horizon := Color(0.46, 0.50, 0.50)
## Depth fog at the height of a storm: it closes in to this, in this colour.
@export var storm_fog_begin := 25.0
@export var storm_fog_end := 420.0
@export var storm_fog_color := Color(0.42, 0.47, 0.46)
## Sunlight kept at the height of a storm.
@export_range(0.0, 1.0) var storm_sunlight := 0.22
## The forest's own sound, ducked under the rain's.
@export var ambience_path: NodePath
@export var rain_stream: AudioStream
@export var thunder_stream: AudioStream
## Storm strength forced on (0..1) for testing; negative follows the schedule.
@export var force_intensity := -1.0
## Share of the rain streaks drawn, set by the level of detail (JungleDetail.gd).
var particle_scale := 1.0

var _env: Environment
var _fog_begin := 90.0
var _fog_end := 1700.0
var _fog_color := Color.WHITE
var _fog_sky := 0.0
var _ambient := 1.0
var _sun: DirectionalLight3D
var _sun_energy := 1.0
var _sun_color := Color.WHITE
var _roads: Array[Node] = []
var _sky_base := {}
var _sky_step := -1
var _rain: GPUParticles3D
var _rain_mat: ParticleProcessMaterial
var _rain_audio: AudioStreamPlayer
var _thunder_audio: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _ambience_db := 0.0
var _warned_storm := -1
var _flash_until := 0.0
var _flash_seen := -1
## Rain strength and road wetness right now, refreshed every frame.
var intensity := 0.0
var wetness := 0.0


func _ready() -> void:
	var we: WorldEnvironment = get_parent().find_child("WorldEnvironment", false, false) as WorldEnvironment
	if we and we.environment:
		_env = we.environment
		_fog_begin = _env.fog_depth_begin
		_fog_end = _env.fog_depth_end
		_fog_color = _env.fog_light_color
		_fog_sky = _env.fog_sky_affect
		_ambient = _env.ambient_light_energy
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun:
		_sun_energy = _sun.light_energy
		_sun_color = _sun.light_color
	if sky_material:
		sky_material.set_shader_parameter(&"storm_sky_top", storm_sky_top)
		sky_material.set_shader_parameter(&"storm_sky_horizon", storm_sky_horizon)
	RenderingServer.global_shader_parameter_set(&"rain_sky_blend", 0.0)
	for path in road_paths:
		var n := get_node_or_null(path)
		if n:
			_roads.append(n)
	_build_rain()
	_ambience = get_node_or_null(ambience_path) as AudioStreamPlayer
	if _ambience:
		_ambience_db = _ambience.volume_db
	if rain_stream:
		_rain_audio = AudioStreamPlayer.new()
		_rain_audio.stream = rain_stream
		_rain_audio.bus = &"SFX"
		_rain_audio.volume_db = -80.0
		add_child(_rain_audio, false, Node.INTERNAL_MODE_BACK)
	if thunder_stream:
		_thunder_audio = AudioStreamPlayer.new()
		_thunder_audio.stream = thunder_stream
		_thunder_audio.bus = &"SFX"
		add_child(_thunder_audio, false, Node.INTERNAL_MODE_BACK)


func _exit_tree() -> void:
	# The material is a shared resource and outlives the level: leave it dry.
	if ground_material:
		ground_material.set_shader_parameter(&"wetness", 0.0)
	RenderingServer.global_shader_parameter_set(&"rain_sky_blend", 0.0)


## Rain streaks falling past the camera, emitted from a slab of air above it. Built here rather
## than saved in the level (it is all runtime state). Internal: the generator runs this _ready
## too, and an ordinary child would be saved into the level and turn up twice at runtime.
func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Mvua"
	_rain.amount = 5200
	_rain.lifetime = 1.1
	_rain.local_coords = false
	_rain.emitting = false
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain.visibility_aabb = AABB(Vector3(-50, -40, -50), Vector3(100, 60, 100))
	_rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_rain_mat = ParticleProcessMaterial.new()
	_rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_mat.emission_box_extents = Vector3(26.0, 2.0, 26.0)
	_rain_mat.direction = Vector3(0.12, -1.0, 0.05)
	_rain_mat.spread = 4.0
	_rain_mat.initial_velocity_min = 24.0
	_rain_mat.initial_velocity_max = 30.0
	_rain_mat.gravity = Vector3(0.0, -9.8, 0.0)
	_rain_mat.scale_min = 0.7
	_rain_mat.scale_max = 1.2
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.1, 0.85, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	_rain_mat.color_ramp = fade_tex
	_rain.process_material = _rain_mat
	var streak := QuadMesh.new()
	streak.size = Vector2(0.035, 1.1)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	var soft := Gradient.new()
	soft.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var soft_tex := GradientTexture2D.new()
	soft_tex.gradient = soft
	soft_tex.width = 16
	soft_tex.height = 64
	soft_tex.fill = GradientTexture2D.FILL_RADIAL
	soft_tex.fill_from = Vector2(0.5, 0.5)
	soft_tex.fill_to = Vector2(0.5, 0.0)
	mat.albedo_texture = soft_tex
	# Streaks right at the lens would smear the whole view.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 1.2
	mat.distance_fade_max_distance = 4.0
	mat.albedo_color = Color(0.78, 0.84, 0.86, 0.32)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = mat
	_rain.draw_pass_1 = streak
	add_child(_rain, false, Node.INTERNAL_MODE_BACK)
	_rain.top_level = true


func _clock() -> float:
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## The storm in window `w`: whether there is one, when it starts and how long it lasts.
func _storm(w: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(w, rng_seed))
	var happens: bool = rng.randf() < storm_chance
	var dur: float = lerpf(storm_min_seconds, storm_max_seconds, rng.randf())
	var start: float = float(w) * cycle_seconds + rng.randf() * cycle_seconds * 0.65
	return {"on": happens, "start": start, "end": start + dur, "id": w}


## Rain strength (0..1) and road wetness (0..1) at wall-clock time `t`. Wetness follows the rain
## up and dries off after it. A storm can run on into the next window, and a road can still be
## wet from one two windows back, so those are checked as well.
func _weather_at(t: float) -> Vector2:
	var window: int = int(floor(t / cycle_seconds))
	var rain := 0.0
	var wet := 0.0
	for w in [window - 2, window - 1, window]:
		var st: Dictionary = _storm(w)
		if not st["on"]:
			continue
		var start: float = st["start"]
		var end: float = st["end"]
		var r: float = smoothstep(start, start + ramp_seconds, t) * (1.0 - smoothstep(end - ramp_seconds, end, t))
		rain = maxf(rain, r)
		var soak: float = smoothstep(start, start + ramp_seconds * 2.5, t)
		if t > end:
			soak = exp(-(t - end) / maxf(dry_seconds, 0.1))
		wet = maxf(wet, soak if t >= start else 0.0)
	return Vector2(rain, wet)


## Seconds until the next storm starts, or -1 if none is due in the next window or two.
func seconds_to_next_storm() -> float:
	var t: float = _clock()
	var window: int = int(floor(t / cycle_seconds))
	for w in [window, window + 1, window + 2]:
		var st: Dictionary = _storm(w)
		if st["on"] and float(st["start"]) > t:
			return float(st["start"]) - t
	return -1.0


func _process(delta: float) -> void:
	var t: float = _clock()
	var wx: Vector2 = _weather_at(t)
	intensity = wx.x
	wetness = wx.y
	if force_intensity >= 0.0:
		intensity = force_intensity
		wetness = maxf(force_intensity, 0.0)
	_warn_drivers()
	_lightning(t, delta)

	if _env:
		_env.fog_depth_begin = lerpf(_fog_begin, storm_fog_begin, intensity)
		_env.fog_depth_end = lerpf(_fog_end, storm_fog_end, intensity)
		_env.fog_light_color = _fog_color.lerp(storm_fog_color, intensity)
		_env.fog_sky_affect = lerpf(_fog_sky, 0.75, intensity)
		_env.ambient_light_energy = _ambient * lerpf(1.0, 0.7, intensity)
	if _sun:
		var flash: float = 1.0 if Time.get_ticks_msec() / 1000.0 < _flash_until else 0.0
		_sun.light_energy = _sun_energy * lerpf(1.0, storm_sunlight, intensity) + flash * 2.5
		_sun.light_color = _sun_color.lerp(Color(0.8, 0.86, 1.0), maxf(intensity * 0.5, flash))
	if ground_material:
		ground_material.set_shader_parameter(&"wetness", wetness)
	RenderingServer.global_shader_parameter_set(&"rain_sky_blend", intensity)
	for road in _roads:
		if is_instance_valid(road):
			var dry: float = float(road.get_meta(&"dry_grip", 1.0))
			road.set_meta(&"ice_grip", dry * lerpf(1.0, wet_grip, wetness))
	if _ambience:
		_ambience.volume_db = _ambience_db - 16.0 * intensity
	if _rain_audio:
		var target_db: float = lerpf(-60.0, -4.0, sqrt(intensity))
		_rain_audio.volume_db = target_db
		if intensity > 0.01 and not _rain_audio.playing:
			_rain_audio.play()
		elif intensity <= 0.01 and _rain_audio.playing:
			_rain_audio.stop()

	if _rain:
		_rain.emitting = intensity > 0.02
		if _rain.emitting:
			_rain.amount_ratio = intensity * particle_scale
			var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
			if cam:
				# Above and a little ahead of the camera, so the streaks fill the view as they fall.
				var fwd: Vector3 = -cam.global_transform.basis.z
				fwd.y = 0.0
				_rain.global_position = cam.global_position + fwd.normalized() * 8.0 + Vector3.UP * 16.0


## Clouds the sky over to `step` tenths of a storm (or smooth float via global uniform).
func _set_sky(step: int) -> void:
	RenderingServer.global_shader_parameter_set(&"rain_sky_blend", clampf(float(step) / 10.0, 0.0, 1.0))


## Now and then in a storm, lightning: the light flickers white and the thunder follows a second
## or three later. Seeded per few seconds of wall clock, so every peer sees the same flash.
func _lightning(t: float, _delta: float) -> void:
	if intensity < 0.6:
		return
	var slot: int = int(floor(t / 9.0))
	if slot == _flash_seen:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(slot, rng_seed + 7))
	if rng.randf() > 0.55:
		_flash_seen = slot
		return
	var at: float = float(slot) * 9.0 + rng.randf() * 8.0
	if t < at:
		return
	_flash_seen = slot
	var now: float = Time.get_ticks_msec() / 1000.0
	_flash_until = now + rng.randf_range(0.08, 0.18)
	if _thunder_audio:
		var delay: float = rng.randf_range(0.8, 2.6)
		_thunder_audio.volume_db = rng.randf_range(-8.0, 0.0)
		_thunder_audio.pitch_scale = rng.randf_range(0.8, 1.1)
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(_thunder_audio):
				_thunder_audio.play())


## A warning on the HUD a few seconds before a storm breaks, once per storm, during the race.
func _warn_drivers() -> void:
	var level: Node = get_tree().get_first_node_in_group("level")
	if level == null or not ("race_state" in level) or level.race_state != 1:
		return
	var due: float = seconds_to_next_storm()
	if due < 0.0 or due > 4.0:
		return
	var window: int = int(floor((_clock() + due) / cycle_seconds))
	if window == _warned_storm:
		return
	_warned_storm = window
	if level.has_method("_all_race_uis"):
		for ui in level._all_race_uis():
			if ui and ui.has_method("show_message"):
				ui.show_message("MVUA! RAIN!", 2.5)
