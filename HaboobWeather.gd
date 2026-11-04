extends Node3D
## The haboob over Mina del Viento (regenerate_mina.gd): a dust storm standing over the escarpment, rolling toward the
## north-west. It is a place, not a schedule: how thick the dust is depends on where you are (`intensity_at`), so it
## starts as you reach the escarpment, is thickest along the shelf road, thins as the pit shelters you on the way down
## and is gone in the valley. From the plateau it shows as a wall of dust ahead (the DustWall curtains, faded by their
## own shader as you drive into them).
##
## Where: `zone` (0..1, a grid of ZONE cells from `zone_origin`) says how much of the storm covers a place, and `top`
## the land's natural height there; how far a point lies below that (cut into the pit, the notch or the mouth) shelters
## it. The generator bakes both.
##
## What the cars feel: gust fronts sweep downwind (`gust_at`, the same on every peer: position and wall clock), and
## each pushes the carts this peer drives across their line (and a little along it). The ground shader draws sand
## blowing along the ground (mina_ground.gdshader's `storm`); sheets of dust roll past the camera, sand snakes over the
## road. Nothing streaks across the lens and nothing flashes: the user finds a swinging, flickering view hard to take.

## Peak sideways push of a gust, in m/s^2: against a cart's grip of about 5 it slides it about 8 m/s sideways in a
## full crosswind until the driver steers into it (19, 3-4 m/s, was too gentle to notice). The share of it along the cart's travel (a head or tail wind) is `along_share`.
@export var gust_accel := 42.0
@export var along_share := 0.3
## Where the wind blows toward (x, z), unit.
@export var wind_dir := Vector2(-0.62, -0.78)
## The dust: how near it closes in at its thickest (the fog's start and full depth, metres).
@export var storm_fog_begin := 4.0
@export var storm_fog_end := 230.0
@export var storm_fog_color := Color(0.68, 0.48, 0.32)
@export_range(0.0, 1.0) var storm_sky_affect := 0.86
## The sun through the dust: its share of light left, and its colour.
@export_range(0.0, 1.0) var storm_sunlight := 0.42
@export var storm_sun_color := Color(1.0, 0.66, 0.40)
@export var storm_wind_boost_db := 15.0
@export var wind_audio_path: NodePath
@export var sun_path: NodePath
@export var ground_material: ShaderMaterial
## The dust wall's curtains' materials (mina_dust_wall.gdshader), told how deep in the storm the camera is.
@export var wall_materials: Array[ShaderMaterial] = []
## The storm's grid: origin (x, z), cell size, cells across, and per cell its cover and the land's natural height.
@export var zone_origin := Vector2.ZERO
@export var zone_cell := 16.0
@export var zone_size := Vector2i(1, 1)
@export var zone := PackedFloat32Array()
@export var top := PackedFloat32Array()
## How much shelter the deepest cut gives, and over what depth below the land it grows.
@export var shelter_max := 0.9
@export var shelter_from := 10.0
@export var shelter_to := 72.0
## Storm strength forced (0..1) for tests and shots; negative follows the place.
@export var force_intensity := -1.0

var _env: Environment
var _wind_audio: AudioStreamPlayer
var _wind_base_db := -22.0
var _sun: DirectionalLight3D
var _sun_energy := 1.0
var _sun_color := Color.WHITE
var _fog_begin := 300.0
var _fog_end := 4800.0
var _fog_color := Color.WHITE
var _fog_sky := 0.06
var _fog_aerial := 0.3
var _sheets: GPUParticles3D
var _sheets_mat: ParticleProcessMaterial
var _sand: GPUParticles3D
var _sand_mat: ParticleProcessMaterial
var _warned := false
## The storm where the camera is (smoothed), for the look and the sound.
var here := 0.0
var _last_cam := Vector3(1e9, 0.0, 0.0)


func _ready() -> void:
	var we: WorldEnvironment = get_parent().find_child("WorldEnvironment", false, false) as WorldEnvironment
	if we and we.environment:
		_env = we.environment
		_fog_begin = _env.fog_depth_begin
		_fog_end = _env.fog_depth_end
		_fog_color = _env.fog_light_color
		_fog_sky = _env.fog_sky_affect
		_fog_aerial = _env.fog_aerial_perspective
	_wind_audio = get_node_or_null(wind_audio_path) as AudioStreamPlayer
	if _wind_audio:
		_wind_base_db = _wind_audio.volume_db
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	if _sun:
		_sun_energy = _sun.light_energy
		_sun_color = _sun.light_color
	if Engine.is_editor_hint():
		set_process(false)
		set_physics_process(false)
		return
	_build_particles()


## How much of the storm is at `p`: its cover there, less the shelter of being cut below the land.
func intensity_at(p: Vector3) -> float:
	if force_intensity >= 0.0:
		return force_intensity
	if zone.is_empty():
		return 0.0
	var gx: float = (p.x - zone_origin.x) / zone_cell
	var gz: float = (p.z - zone_origin.y) / zone_cell
	var ix: int = clampi(int(floor(gx)), 0, zone_size.x - 2)
	var iz: int = clampi(int(floor(gz)), 0, zone_size.y - 2)
	var fx: float = clampf(gx - float(ix), 0.0, 1.0)
	var fz: float = clampf(gz - float(iz), 0.0, 1.0)
	var i0: int = iz * zone_size.x + ix
	var i1: int = i0 + zone_size.x
	var c: float = lerpf(lerpf(zone[i0], zone[i0 + 1], fx), lerpf(zone[i1], zone[i1 + 1], fx), fz)
	if c <= 0.001:
		return 0.0
	var t: float = lerpf(lerpf(top[i0], top[i0 + 1], fx), lerpf(top[i1], top[i1 + 1], fx), fz)
	var shelter: float = shelter_max * smoothstep(shelter_from, shelter_to, t - p.y)
	return c * (1.0 - shelter)


## A gust at `p`: fronts about 150m apart sweeping downwind at the wind's speed, a lull between them (0.3..1).
func gust_at(p: Vector3, t: float) -> float:
	var along: float = p.x * wind_dir.x + p.z * wind_dir.y
	var g: float = 0.5 + 0.5 * sin(along * 0.042 - t * 0.85 + sin(along * 0.009 + t * 0.19) * 1.8)
	return 0.3 + 0.7 * g * g * g


func _clock() -> float:
	return fmod(Time.get_unix_time_from_system(), 86400.0)


func _camera() -> Camera3D:
	var vp := get_viewport()
	return vp.get_camera_3d() if vp else null


func _process(delta: float) -> void:
	var cam: Camera3D = _camera()
	var target := 0.0
	var at := Vector3.ZERO
	if cam:
		at = cam.global_position
		target = intensity_at(at)
	# Eased, so driving into the dust closes the view in over a second or two rather than at once; a camera cut (a
	# respawn, a spectator's switch, a shot) takes the new place's at once.
	if at.distance_to(_last_cam) > 60.0:
		here = target
	else:
		here = lerpf(here, target, clampf(delta * 1.4, 0.0, 1.0))
	_last_cam = at
	var t: float = _clock()
	var g: float = gust_at(at, t)
	if _env:
		_env.fog_depth_begin = lerpf(_fog_begin, storm_fog_begin, here)
		_env.fog_depth_end = lerpf(_fog_end, storm_fog_end, pow(here, 0.6))
		_env.fog_light_color = _fog_color.lerp(storm_fog_color, here)
		_env.fog_sky_affect = lerpf(_fog_sky, storm_sky_affect, here)
		# In the dust everything far off goes the dust's colour, not the sky's.
		_env.fog_aerial_perspective = lerpf(_fog_aerial, 0.0, here)
	if _sun:
		_sun.light_energy = _sun_energy * lerpf(1.0, storm_sunlight, here)
		_sun.light_color = _sun_color.lerp(storm_sun_color, here * 0.8)
	if _wind_audio:
		_wind_audio.volume_db = _wind_base_db + storm_wind_boost_db * here * (0.55 + 0.45 * g)
		_wind_audio.pitch_scale = 1.0 + 0.14 * here * g
	if ground_material:
		ground_material.set_shader_parameter(&"storm", here * (0.6 + 0.4 * g))
		ground_material.set_shader_parameter(&"wind_dir", wind_dir)
	for wm in wall_materials:
		wm.set_shader_parameter(&"inside", here)
	_update_particles(cam, here, g)
	_warn_drivers(target)


func _physics_process(_delta: float) -> void:
	var t: float = _clock()
	var w3 := Vector3(wind_dir.x, 0.0, wind_dir.y)
	for cart in get_tree().get_nodes_in_group("player_carts"):
		if not (cart is RigidBody3D):
			continue
		if cart.has_method("has_physics_authority") and not cart.has_physics_authority():
			continue
		if not cart.get("can_move") or cart.get("is_exploding"):
			continue
		var body := cart as RigidBody3D
		var i: float = intensity_at(body.global_position)
		if i <= 0.01:
			continue
		var v := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
		var fwd: Vector3 = v.normalized() if v.length() > 3.0 else Vector3.ZERO
		var along: Vector3 = fwd * w3.dot(fwd)
		var dir: Vector3 = (w3 - along) + along * along_share
		body.apply_central_force(dir * gust_accel * i * gust_at(body.global_position, t) * body.mass)


# --- Dust in the air -----------------------------------------------------------------------------------------------

## A soft, ragged puff of dust: a radial falloff broken up by noise, so the sheets don't read as discs.
func _puff_texture() -> ImageTexture:
	var n := FastNoiseLite.new()
	n.frequency = 0.045
	n.fractal_octaves = 4
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var r: float = Vector2(x - 63.5, y - 63.5).length() / 63.5
			var a: float = (1.0 - smoothstep(0.25, 1.0, r)) * clampf(0.55 + n.get_noise_2d(x, y) * 0.9, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _build_particles() -> void:
	# Sheets of dust rolling past, big and slow, and gone before they reach the lens.
	_sheets = GPUParticles3D.new()
	_sheets.name = "DustSheets"
	_sheets.amount = 70
	_sheets.lifetime = 7.0
	_sheets.preprocess = 4.0
	_sheets.local_coords = false
	_sheets.emitting = false
	_sheets.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sheets.visibility_aabb = AABB(Vector3(-200, -60, -200), Vector3(400, 120, 400))
	_sheets_mat = ParticleProcessMaterial.new()
	_sheets_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_sheets_mat.emission_box_extents = Vector3(90.0, 14.0, 90.0)
	_sheets_mat.spread = 8.0
	_sheets_mat.initial_velocity_min = 9.0
	_sheets_mat.initial_velocity_max = 14.0
	_sheets_mat.gravity = Vector3.ZERO
	_sheets_mat.scale_min = 1.0
	_sheets_mat.scale_max = 2.2
	_sheets_mat.angle_min = -180.0
	_sheets_mat.angle_max = 180.0
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	_sheets_mat.color_ramp = ft
	_sheets.process_material = _sheets_mat
	var quad := QuadMesh.new()
	quad.size = Vector2(22.0, 14.0)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.84, 0.62, 0.42)
	m.albedo_texture = _puff_texture()
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 9.0
	m.distance_fade_max_distance = 30.0
	m.disable_receive_shadows = true
	quad.material = m
	_sheets.draw_pass_1 = quad
	# Internal: the generator runs this _ready too, and an ordinary child would be saved into the level.
	add_child(_sheets, false, Node.INTERNAL_MODE_BACK)
	_sheets.top_level = true
	# Sand snaking low over the ground: thin streaks along the wind, ankle high.
	_sand = GPUParticles3D.new()
	_sand.name = "BlowingSand"
	_sand.amount = 260
	_sand.lifetime = 1.3
	_sand.local_coords = false
	_sand.emitting = false
	_sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sand.visibility_aabb = AABB(Vector3(-60, -10, -60), Vector3(120, 20, 120))
	_sand.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_sand_mat = ParticleProcessMaterial.new()
	_sand_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_sand_mat.emission_box_extents = Vector3(30.0, 0.35, 30.0)
	_sand_mat.spread = 6.0
	_sand_mat.initial_velocity_min = 15.0
	_sand_mat.initial_velocity_max = 21.0
	_sand_mat.gravity = Vector3(0.0, -0.5, 0.0)
	_sand_mat.scale_min = 0.7
	_sand_mat.scale_max = 1.4
	var sf := Gradient.new()
	sf.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	sf.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
	var sft := GradientTexture1D.new()
	sft.gradient = sf
	_sand_mat.color_ramp = sft
	_sand.process_material = _sand_mat
	var streak := QuadMesh.new()
	streak.size = Vector2(0.22, 2.6)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.vertex_color_use_as_albedo = true
	sm.albedo_color = Color(0.74, 0.55, 0.38)
	var soft := Gradient.new()
	soft.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	soft.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	var st := GradientTexture2D.new()
	st.gradient = soft
	st.width = 16
	st.height = 64
	st.fill = GradientTexture2D.FILL_RADIAL
	st.fill_from = Vector2(0.5, 0.5)
	st.fill_to = Vector2(0.5, 0.0)
	sm.albedo_texture = st
	sm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	sm.distance_fade_min_distance = 3.0
	sm.distance_fade_max_distance = 9.0
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = sm
	_sand.draw_pass_1 = streak
	add_child(_sand, false, Node.INTERNAL_MODE_BACK)
	_sand.top_level = true


func _update_particles(cam: Camera3D, i: float, g: float) -> void:
	if _sheets == null:
		return
	var w3 := Vector3(wind_dir.x, 0.0, wind_dir.y)
	_sheets.emitting = i > 0.04 and cam != null
	_sand.emitting = i > 0.08 and cam != null
	if cam == null:
		return
	if _sheets.emitting:
		_sheets.amount_ratio = clampf(i, 0.0, 1.0)
		_sheets_mat.direction = w3
		# Upwind of the camera, so they have rolled into view by the time they are thick.
		_sheets.global_position = cam.global_position - w3 * 60.0 + Vector3.UP * 4.0
	if _sand.emitting:
		_sand.amount_ratio = clampf(i * (0.45 + 0.55 * g), 0.0, 1.0)
		_sand_mat.direction = (w3 + Vector3.DOWN * 0.02).normalized()
		# Over the ground ahead of the camera, where the car is.
		var fwd: Vector3 = -cam.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var p: Vector3 = cam.global_position + fwd * 14.0 - w3 * 12.0
		var space := get_world_3d().direct_space_state
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p + Vector3.DOWN * 60.0))
		if hit:
			_sand.global_position = (hit.position as Vector3) + Vector3.UP * 0.4


## "HABOOB!" on the HUD the first time the dust closes in round the camera during the race.
func _warn_drivers(i: float) -> void:
	if _warned or i < 0.3:
		return
	var level: Node = get_tree().get_first_node_in_group("level")
	if level == null or not ("race_state" in level) or level.race_state != 1:
		return
	_warned = true
	if level.has_method("_all_race_uis"):
		for ui in level._all_race_uis():
			if ui and ui.has_method("show_message"):
				ui.show_message("HABOOB!", 2.5)
