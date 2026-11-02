# HaboobWeather.gd
#
# Progressive sandstorm weather system for Mina del Viento (Rally Sprint).
# Runs along the 4.5km point-to-point descent:
#   Sector 1 (0 to 1,150m, Plateau): Calm, golden dawn sky, light haze, balloons ascending.
#   Sector 2 (1,150m to 2,300m, Caldera Rim): "HABOOB!" alarm triggers, wall of dust rolls in,
#             howling crosswinds buffet carts toward the precipice, rolling tumbleweeds.
#   Sector 3 (2,300m to 3,600m, Open-Pit Terraces): Plunge into the pit; pit walls provide partial
#             wind shelter, swirling copper-ochre dust, floodlight shafts cut through haze.
#   Sector 4 (3,600m to 4,500m, Conveyor Bridges & Finish): Industrial depot sprint to chequered gate.
extends Node3D

## Peak sideways push of a wind gust in m/s^2 on exposed stretches.
@export var gust_accel := 12.0
## Exponential fog density at the height of the haboob.
@export var storm_fog_density := 0.026
## Rich ochre-copper dust fog color.
@export var storm_fog_color := Color(0.68, 0.44, 0.28)
## Sky obscured by storm fog (0..1).
@export_range(0.0, 1.0) var storm_sky_affect := 0.88
## Wind audio loop volume boost at peak storm (dB).
@export var storm_wind_boost_db := 14.0
@export var wind_audio_path: NodePath
@export var sun_path: NodePath
## Sheltered stretches (x0, z0, x1, z1) with shelter_radius.
@export var shelters: Array[Vector4] = []
@export var shelter_radius := 18.0
## Force storm intensity for testing (-1 follows race progress / schedule).
@export var force_intensity := -1.0

var _env: Environment
var _wind_audio: AudioStreamPlayer
var _wind_base_db := -6.0
var _sun: DirectionalLight3D
var _sun_base_energy := 0.95
var _sun_base_color: Color = Color(1.0, 0.78, 0.55)

var _dust: GPUParticles3D
var _dust_mat: ParticleProcessMaterial
var _warned := false
var intensity := 0.0
var wind_dir := Vector2(0.85, 0.52).normalized()
var progress_ratio := 0.0


func _ready() -> void:
	var we: WorldEnvironment = get_parent().find_child("WorldEnvironment", false, false) as WorldEnvironment
	if we and we.environment:
		_env = we.environment
		_env.fog_enabled = true
		_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		_env.fog_density = 0.0004
		_env.fog_light_color = storm_fog_color
		_env.fog_light_energy = 0.8
		_env.fog_sky_affect = 0.02
	_wind_audio = get_node_or_null(wind_audio_path) as AudioStreamPlayer
	if _wind_audio:
		_wind_base_db = _wind_audio.volume_db
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun:
		_sun_base_energy = _sun.light_energy
		_sun_base_color = _sun.light_color
	_build_dust_particles()


func _build_dust_particles() -> void:
	_dust = GPUParticles3D.new()
	_dust.name = "HaboobDust"
	_dust.amount = 2800
	_dust.lifetime = 1.4
	_dust.local_coords = false
	_dust.emitting = false
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dust.visibility_aabb = AABB(Vector3(-60, -25, -60), Vector3(120, 50, 120))
	_dust.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY

	_dust_mat = ParticleProcessMaterial.new()
	_dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_dust_mat.emission_box_extents = Vector3(28.0, 8.0, 28.0)
	_dust_mat.spread = 12.0
	_dust_mat.initial_velocity_min = 22.0
	_dust_mat.initial_velocity_max = 34.0
	_dust_mat.gravity = Vector3(0.0, -1.5, 0.0)
	_dust_mat.scale_min = 0.8
	_dust_mat.scale_max = 1.6

	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.75, 1.0])
	fade.colors = PackedColorArray([
		Color(0.72, 0.48, 0.32, 0.0),
		Color(0.72, 0.48, 0.32, 0.75),
		Color(0.65, 0.42, 0.26, 0.75),
		Color(0.65, 0.42, 0.26, 0.0)
	])
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	_dust_mat.color_ramp = fade_tex
	_dust.process_material = _dust_mat

	var streak := QuadMesh.new()
	streak.size = Vector2(0.22, 1.1)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true

	var soft := Gradient.new()
	soft.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0)])
	var soft_tex := GradientTexture2D.new()
	soft_tex.gradient = soft
	soft_tex.width = 32
	soft_tex.height = 64
	soft_tex.fill = GradientTexture2D.FILL_RADIAL
	soft_tex.fill_from = Vector2(0.5, 0.5)
	soft_tex.fill_to = Vector2(0.5, 0.0)
	mat.albedo_texture = soft_tex

	mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	mat.distance_fade_min_distance = 1.5
	mat.distance_fade_max_distance = 5.0
	mat.albedo_color = Color(0.78, 0.55, 0.38, 0.6)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = mat
	_dust.draw_pass_1 = streak

	add_child(_dust, false, Node.INTERNAL_MODE_BACK)
	_dust.top_level = true


## 1 deep in a shelter, falling to 0 outside it.
func shelter_at(p: Vector3) -> float:
	var best := 0.0
	var q := Vector2(p.x, p.z)
	for s in shelters:
		var a := Vector2(s.x, s.y)
		var b := Vector2(s.z, s.w)
		var ab: Vector2 = b - a
		var u: float = clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d: float = q.distance_to(a + ab * u)
		best = maxf(best, 1.0 - smoothstep(shelter_radius - 5.0, shelter_radius + 5.0, d))
	return best


func _gust(t: float) -> float:
	return clampf(0.65 + 0.35 * sin(t * 1.5) * cos(t * 0.53 + 1.2), 0.2, 1.0)


func _process(_delta: float) -> void:
	if force_intensity >= 0.0:
		intensity = force_intensity
	else:
		_compute_intensity()

	_warn_drivers()

	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	var here: float = intensity
	if cam:
		here *= 1.0 - shelter_at(cam.global_position)

	if _env:
		_env.fog_density = lerpf(0.0004, storm_fog_density, here)
		_env.fog_sky_affect = lerpf(0.02, storm_sky_affect, here)

	if _sun:
		_sun.light_energy = _sun_base_energy * lerpf(1.0, 0.42, here)
		_sun.light_color = _sun_base_color.lerp(Color(0.88, 0.58, 0.32), here * 0.75)

	if _wind_audio:
		_wind_audio.volume_db = _wind_base_db + storm_wind_boost_db * here
		_wind_audio.pitch_scale = 1.0 + 0.15 * here

	_dust.emitting = here > 0.03
	if _dust.emitting:
		_dust.amount_ratio = here
		var w3 := Vector3(wind_dir.x, 0.0, wind_dir.y)
		_dust_mat.direction = (w3 + Vector3.DOWN * 0.1).normalized()
		if cam:
			_dust.global_position = cam.global_position - w3 * 15.0 + Vector3.UP * 1.5


func _compute_intensity() -> void:
	# Measure highest progress along track from carts
	var level = get_tree().get_first_node_in_group("level")
	var best_off := 0.0
	var t_len := 4500.0
	if level and "track_path" in level and level.track_path and level.track_path.curve:
		var curve = level.track_path.curve
		t_len = maxf(curve.get_baked_length(), 1.0)
		for cart in get_tree().get_nodes_in_group("player_carts"):
			if is_instance_valid(cart) and cart is Node3D:
				var off = curve.get_closest_offset(level.track_path.to_local(cart.global_position))
				if off > best_off:
					best_off = off

	progress_ratio = clampf(best_off / t_len, 0.0, 1.0)

	# Plateau (0.0 to 0.24): Calm morning
	# Approach to Rim (0.24 to 0.32): Dust wall builds up rapidly!
	# Rim & Upper Pit (0.32 to 0.70): Peak haboob storm!
	# Lower Pit & Depot (0.70 to 1.0): Pit basin dust haze (~0.85)
	if progress_ratio < 0.24:
		intensity = 0.0
	elif progress_ratio < 0.32:
		intensity = smoothstep(0.24, 0.32, progress_ratio)
	elif progress_ratio < 0.70:
		intensity = 1.0
	else:
		intensity = lerpf(1.0, 0.85, (progress_ratio - 0.70) / 0.30)


func _physics_process(_delta: float) -> void:
	if intensity <= 0.005:
		return
	var clock := Time.get_ticks_msec() / 1000.0
	var push := gust_accel * intensity * _gust(clock)
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


func _warn_drivers() -> void:
	if _warned or intensity < 0.15:
		return
	_warned = true
	var level: Node = get_tree().get_first_node_in_group("level")
	if level and level.has_method("_all_race_uis"):
		for ui in level._all_race_uis():
			if ui and ui.has_method("show_message"):
				ui.show_message("HABOOB INCOMING!", 3.0)

