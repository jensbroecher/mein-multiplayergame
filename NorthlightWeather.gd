# NorthlightWeather.gd
#
# Blizzards on Northlight Caverns. Every so often the wind gets up: snow streams across the road,
# the distance whites out, the aurora disappears behind it, and gusts shove the carts sideways
# (which, on the ice, they feel). The cavern is sheltered from all of it.
#
# The schedule runs on the wall clock, like WildebeestHerd, so every LAN peer sees the same storm
# at the same moment without anything being synced. Gusts only push carts this peer has physics
# authority over, so each cart is pushed exactly once.
extends Node3D

## Seconds per weather window. Each window holds at most one storm, so storms come round about
## every cycle_seconds / storm_chance.
@export var cycle_seconds := 100.0
@export_range(0.0, 1.0) var storm_chance := 0.65
@export var storm_min_seconds := 22.0
@export var storm_max_seconds := 36.0
## Build-up and die-down at either end of a storm.
@export var ramp_seconds := 7.0
@export var rng_seed := 7741
## Exponential fog density at the height of a storm. 0.03 leaves about 100m of visibility.
@export var storm_fog_density := 0.03
## Dark and cold: it is night, and a pale fog lit by nothing reads as daylight.
@export var storm_fog_color := Color(0.20, 0.25, 0.33)
## How much of the sky the storm hides; at 1 the aurora is gone entirely.
@export_range(0.0, 1.0) var storm_sky_affect := 0.85
## Peak sideways push of a gust, in m/s^2.
@export var gust_accel := 7.0
## Moon brightness kept at the height of a storm.
@export_range(0.0, 1.0) var storm_moonlight := 0.55
## Wind loop turned up by this many dB at the height of a storm.
@export var storm_wind_boost_db := 12.0
@export var wind_audio_path: NodePath
@export var moon_path: NodePath
## Sheltered stretches, as segments (x0, z0, x1, z1) with shelter_radius around them.
@export var shelters: Array[Vector4] = []
@export var shelter_radius := 13.0
## Storm strength forced on (0..1) for testing; negative follows the schedule.
@export var force_intensity := -1.0

var _env: Environment
var _wind_audio: AudioStreamPlayer
var _wind_base_db := 0.0
var _moon: DirectionalLight3D
var _moon_base := 1.0
var _snow: GPUParticles3D
var _snow_mat: ParticleProcessMaterial
var _warned_storm := -1
## Strength and wind of the storm right now, refreshed every frame.
var intensity := 0.0
var wind_dir := Vector2(1.0, 0.0)
var _storm_id := -1


func _ready() -> void:
	var we: WorldEnvironment = get_parent().find_child("WorldEnvironment", false, false) as WorldEnvironment
	if we and we.environment:
		_env = we.environment
		_env.fog_enabled = true
		_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		_env.fog_density = 0.0
		_env.fog_light_color = storm_fog_color
		_env.fog_light_energy = 1.0
		_env.fog_sky_affect = 0.0
	_wind_audio = get_node_or_null(wind_audio_path) as AudioStreamPlayer
	if _wind_audio:
		_wind_base_db = _wind_audio.volume_db
	_moon = get_node_or_null(moon_path) as DirectionalLight3D
	if _moon:
		_moon_base = _moon.light_energy
	_build_snow()


## Blowing snow: streaks aligned to their velocity, emitted upwind of the camera so they stream
## through the view. Spawned here rather than saved in the level, it is all runtime state.
func _build_snow() -> void:
	_snow = GPUParticles3D.new()
	_snow.name = "BlizzardSnow"
	_snow.amount = 3400
	_snow.lifetime = 1.5
	_snow.local_coords = false
	_snow.emitting = false
	_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_snow.visibility_aabb = AABB(Vector3(-70, -30, -70), Vector3(140, 60, 140))
	# Each streak faces the camera with its long axis along its velocity, so it reads as snow
	# driven sideways by the wind rather than as rain.
	_snow.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_snow_mat = ParticleProcessMaterial.new()
	_snow_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_snow_mat.emission_box_extents = Vector3(30.0, 9.0, 30.0)
	_snow_mat.spread = 9.0
	_snow_mat.initial_velocity_min = 20.0
	_snow_mat.initial_velocity_max = 30.0
	_snow_mat.gravity = Vector3(0.0, -4.0, 0.0)
	_snow_mat.scale_min = 0.6
	_snow_mat.scale_max = 1.3
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	_snow_mat.color_ramp = fade_tex
	_snow.process_material = _snow_mat

	var streak := QuadMesh.new()
	streak.size = Vector2(0.07, 0.7)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	# Streaks right in front of the lens would cover half the screen: fade them out up close.
	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 1.5
	mat.distance_fade_max_distance = 5.0
	mat.albedo_color = Color(0.88, 0.94, 1.0, 0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = mat
	_snow.draw_pass_1 = streak
	add_child(_snow)
	_snow.top_level = true


func _clock() -> float:
	return fmod(Time.get_unix_time_from_system(), 86400.0)


## Storm strength (0..1), wind direction and storm id at wall-clock time `t`. A storm can start
## late in its window and run on into the next one, so the previous window is checked as well.
func _storm_at(t: float) -> Array:
	var window: int = int(floor(t / cycle_seconds))
	var best := 0.0
	var dir := Vector2(1.0, 0.0)
	var id := -1
	for w in [window - 1, window]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(w, rng_seed))
		var happens: bool = rng.randf() < storm_chance
		var dur: float = lerpf(storm_min_seconds, storm_max_seconds, rng.randf())
		var start: float = float(w) * cycle_seconds + rng.randf() * cycle_seconds * 0.7
		var ang: float = rng.randf() * TAU
		if not happens:
			continue
		var s: float = smoothstep(start, start + ramp_seconds, t) * (1.0 - smoothstep(start + dur - ramp_seconds, start + dur, t))
		if s > best:
			best = s
			dir = Vector2(cos(ang), sin(ang))
			id = w
	return [best, dir, id]


## Seconds until the next storm starts, or -1 if none is due in the next window or two.
func seconds_to_next_storm() -> float:
	var t: float = _clock()
	var window: int = int(floor(t / cycle_seconds))
	for w in [window, window + 1, window + 2]:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2i(w, rng_seed))
		var happens: bool = rng.randf() < storm_chance
		rng.randf()
		var start: float = float(w) * cycle_seconds + rng.randf() * cycle_seconds * 0.7
		if happens and start > t:
			return start - t
	return -1.0


## 1 deep in a shelter, falling to 0 a few metres outside it.
func shelter_at(p: Vector3) -> float:
	var best := 0.0
	var q := Vector2(p.x, p.z)
	for s in shelters:
		var a := Vector2(s.x, s.y)
		var b := Vector2(s.z, s.w)
		var ab: Vector2 = b - a
		var u: float = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d: float = q.distance_to(a + ab * u)
		best = maxf(best, 1.0 - smoothstep(shelter_radius - 4.0, shelter_radius + 4.0, d))
	return best


func _gust(t: float) -> float:
	return clampf(0.62 + 0.38 * sin(t * 1.3) * cos(t * 0.47 + 1.7), 0.15, 1.0)


func _process(_delta: float) -> void:
	var t: float = _clock()
	var storm: Array = _storm_at(t)
	intensity = storm[0] if force_intensity < 0.0 else force_intensity
	wind_dir = storm[1]
	_storm_id = storm[2]
	_warn_drivers()

	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	var here: float = intensity
	if cam:
		here *= 1.0 - shelter_at(cam.global_position)

	if _env:
		_env.fog_density = storm_fog_density * here
		_env.fog_sky_affect = storm_sky_affect * here
	if _moon:
		_moon.light_energy = _moon_base * lerpf(1.0, storm_moonlight, here)
	if _wind_audio:
		_wind_audio.volume_db = _wind_base_db + storm_wind_boost_db * here
		_wind_audio.pitch_scale = 1.0 + 0.12 * here

	_snow.emitting = here > 0.02
	if _snow.emitting:
		_snow.amount_ratio = here
		var w3 := Vector3(wind_dir.x, 0.0, wind_dir.y)
		_snow_mat.direction = (w3 + Vector3.DOWN * 0.12).normalized()
		if cam:
			# Upwind of the camera, so the streaks have crossed the view by the time they expire.
			_snow.global_position = cam.global_position - w3 * 16.0 + Vector3.UP * 2.0


func _physics_process(_delta: float) -> void:
	if intensity <= 0.001:
		return
	var push: float = gust_accel * intensity * _gust(_clock())
	var w3 := Vector3(wind_dir.x, 0.0, wind_dir.y)
	for cart in get_tree().get_nodes_in_group("player_carts"):
		if not (cart is RigidBody3D):
			continue
		if cart.has_method("has_physics_authority") and not cart.has_physics_authority():
			continue
		if not cart.get("can_move") or cart.get("is_exploding"):
			continue
		var here: float = 1.0 - shelter_at(cart.global_position)
		if here > 0.0:
			(cart as RigidBody3D).apply_central_force(w3 * push * here * (cart as RigidBody3D).mass)


## A warning on the HUD a few seconds before a storm hits, once per storm, during the race.
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
				ui.show_message("BLIZZARD!", 2.5)
