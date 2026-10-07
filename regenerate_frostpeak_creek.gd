# regenerate_frostpeak_creek.gd
# Builds FrostpeakCreekLevel.tscn:
# Alpine winter Grand Prix circuit with rolling elevation changes, a winding central creek,
# two big jump leaps over the water, two timber bridges, snow-covered road sections with
# slowdown and snow powder VFX, and two branching alternative shortcuts.
#
# The shortcuts are built from _build_ramp_curve() rather than hand-authored points: each end is a
# nose sitting exactly on the trunk deck edge with handles aligned to the trunk tangent, and the
# ramp deck is pinched to that edge until it has pulled clear (see _ramp_deck_extents). That is what
# stops the shortcuts from dead-ending inside the racing surface at a sharp angle, z-fighting the
# trunk asphalt, or folding their own ribbon inside out on a too-tight merge.
extends Node

## Trunk carriageway geometry, mirrored from the TerrainGenerator settings below so the ramp
## noses land on the real deck edge rather than an estimate of it.
const MAIN_ROAD_HALF_W := 7.5      # asphalt half width  (road_width = 15)
const MAIN_CURB_HALF_W := 8.5      # curb outer half width (curb_outer_width = 17)
## Where a shortcut's nose sits and where its deck's inner edge is pinned: on the *asphalt* edge,
## not the curb edge. The trunk road here is a 3m-thick slab on an embankment, so its outer 1m of
## curb is a lip with open air beside it. A shortcut that starts at the curb edge is a zero-width
## knife edge perched on that lip, and a car drifting across the junction drops off it. Starting the
## nose just inside the asphalt gives the gore real width to stand on and covers the transition.
const MAIN_NOSE_LATERAL := MAIN_ROAD_HALF_W - 0.6
## A shortcut nose is a wide paved apron, not a point. It has to reach past the trunk road's own
## outer edge: where the trunk runs more than 12m above natural ground the generator stops grading
## terrain up to it (it treats the section as a bridge), so the road edge there is a 7m drop. A nose
## that stops at the trunk's edge leaves that drop right where a car crosses onto the shortcut.
const MAIN_NOSE_HALF_W := 3.6
## Driving-surface heights above each centreline. Everything that meets another surface is built to
## these, so a joint is flush by construction rather than by eye:
## - the trunk's collision deck is road_y_offset (0.06) + 0.02 above its curve, flat across the full
##   curb-to-curb width out to MAIN_COL_HALF_W (TerrainGenerator._create_track_collision);
## - a shortcut's deck (visual and collision are the same mesh) is 0.05 above its curve at the gutters;
## - a timber bridge's deck box tops out 0.08 above the bridge origin.
const TRUNK_DECK_Y := 0.08
const MAIN_COL_HALF_W := MAIN_CURB_HALF_W + 0.05
const SHORTCUT_DECK_Y := 0.05
const BRIDGE_DECK_TOP := 0.08
## Shortcut deck widths, and the width a shortcut reaches once it is a full gore clear of the trunk.
const RAMP_1_HALF_W := 5.75        # Canyon Cut is 11.5m wide
const RAMP_2_HALF_W := 5.50        # Glade Creek is 11.0m wide
## How far along the trunk a shortcut runs before it is allowed to step out from the shoulder.
##
## The nose sits on the deck edge and the gore exit is a full half-width further out, so the two are
## never collinear with the trunk: the chord between them leans in by atan(half_width / lead). The
## lead exists to make that lean small. At 18m it is 17 degrees and the gore visibly kinks away from
## the shoulder; at 24m it is 13 degrees and the pinned tangent handles absorb it as a gentle S of
## ~90m radius instead. Each route passes its own value.
const RAMP_NOSE_LEAD := 22.0
## Lateral offset the shortcut reaches at the end of its nose run. Anything at or below
## MAIN_NOSE_LATERAL would still be pinched against the trunk deck.
const RAMP_NOSE_LATERAL := 14.0
## Tangential run of the nose handle itself, so the gore opens along the trunk tangent.
const RAMP_NOSE_HANDLE := 16.0
## Tightest centreline radius a shortcut tries to hold when deriving handles. It is a *target*, not a
## guarantee: where a junction leaves too little chord to turn that tightly, the handle is clamped to
## the chord and the turn is spread across the whole segment instead. Left too high it does the
## opposite -- it demands a handle longer than the segment, which concentrates all the curvature into
## one point and is what folded the old shortcut decks inside out. The real radius floor is enforced
## by _verify_ramp_junction against the measured centreline.
const RAMP_MIN_RADIUS := 9.0

## Glade Timber Bridge: where the Glade Creek shortcut crosses the creek.
##
## Z=204 is the southernmost latitude that still carries open water, and being *south* of where the
## shortcut leaves the trunk is the point: the trunk runs almost due south along the east flank, so a
## crossing north of the gore exit would force the ramp to swing through ~100 degrees in the 16m
## between them. South of it the same swing is ~60 degrees over a longer run, which is the difference
## between a 5m radius (deck folded inside out) and a drivable one.
##
## The span is only as long as the water (26m for a 23m channel) so that the shortcut can carry on
## west for a few metres past the far abutment before it turns north. A span pinned dead straight
## meets its departure at a 90 degree corner, and a corner in a road centreline is a cusp: the span
## has to end early enough for the turn to be spread over a real arc.
##
## The span runs due west, square to nothing in particular but square to the road: the shortcut has to
## arrive from the north-east and leave to the north-west, and skewing the span to sit perpendicular
## to the creek instead just moves the same turn to the abutment with even less room for it.

## Where the trunk road centreline lives, so ramp junctions can be measured against it.
var main_track_curve: Curve3D

func _ready() -> void:
	print("=== Frostpeak Creek Grand Prix Level Generation ===")
	print("Building alpine snow circuit with central creek and branching route. Please wait...")

	var level_scene := Node3D.new()
	level_scene.name = "FrostpeakCreekLevel"

	var level_script: Script = load("res://levels/Level.gd")
	level_scene.set_script(level_script)
	add_child(level_scene)

	# 1. Environment & Lighting (Crisp Winter Atmosphere)
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.55, 0.92)
	sky_mat.sky_horizon_color = Color(0.72, 0.84, 0.94)
	sky_mat.ground_bottom_color = Color(0.85, 0.90, 0.96)
	sky_mat.ground_horizon_color = Color(0.78, 0.88, 0.95)
	sky_mat.sun_angle_max = 28.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_color = Color(0.88, 0.93, 1.0)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.12
	env_node.environment = env
	level_scene.add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.rotation_degrees = Vector3(-46.0, 42.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 480.0
	sun.directional_shadow_split_1 = 0.1
	sun.directional_shadow_split_2 = 0.25
	sun.directional_shadow_split_3 = 0.55
	level_scene.add_child(sun)

	# Ambient winter wind audio
	var wind_stream = load("res://sounds/dragon-studio-winter-wind-402331.mp3")
	if wind_stream:
		var wind_player := AudioStreamPlayer.new()
		wind_player.name = "WinterWindAudio"
		wind_player.stream = wind_stream
		wind_player.volume_db = -12.0
		wind_player.autoplay = true
		level_scene.add_child(wind_player)

	# Atmospheric Falling Snow Particles
	var snow_particles := GPUParticles3D.new()
	snow_particles.name = "FallingSnow"
	var falling_snow_script = load("res://FallingSnow.gd")
	if falling_snow_script:
		snow_particles.set_script(falling_snow_script)
	snow_particles.amount = 2500
	snow_particles.lifetime = 3.2
	snow_particles.speed_scale = 0.5
	snow_particles.randomness = 0.8
	snow_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow_particles.visibility_aabb = AABB(Vector3(-45, -35, -45), Vector3(90, 45, 90))

	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(35.0, 1.0, 35.0)
	pmat.direction = Vector3(0.2, -1.0, 0.1)
	pmat.spread = 18.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 6.0
	pmat.gravity = Vector3(0, -3.5, 0)
	pmat.scale_min = 0.8
	pmat.scale_max = 1.4
	snow_particles.process_material = pmat

	var snow_quad := QuadMesh.new()
	snow_quad.size = Vector2(0.12, 0.12)
	var fall_snow_mat := StandardMaterial3D.new()
	fall_snow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fall_snow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fall_snow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fall_snow_mat.vertex_color_use_as_albedo = true
	fall_snow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 0.95), Color(1.0, 1.0, 1.0, 0.0)])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 32
	grad_tex.height = 32
	grad_tex.fill = GradientTexture2D.FILL_RADIAL
	grad_tex.fill_from = Vector2(0.5, 0.5)
	grad_tex.fill_to = Vector2(0.5, 0.0)
	fall_snow_mat.albedo_texture = grad_tex
	fall_snow_mat.albedo_color = Color(0.96, 0.98, 1.0, 0.9)

	snow_quad.material = fall_snow_mat
	snow_particles.draw_pass_1 = snow_quad
	level_scene.add_child(snow_particles)

	# 2. TrackPath & Curve3D (~1350m closed circuit with undulating elevations)
	# Central creek meanders near X=0 from Z=+175 to Z=-370.
	var track_path := Path3D.new()
	track_path.name = "TrackPath"
	var curve := Curve3D.new()
	curve.bake_interval = 0.25

	# Clockwise circuit:
	# - Starts on West bank (X=-45m, Y=0.8m) heading North
	# - JUMP 1 over central creek from West bank to East bank
	# - East Ridge climb with branching route (Standard Route A vs Inner Canyon Shortcut B)
	# - Merged road crosses ALPINETIMBERBRIDGE from East bank to West bank
	# - Climbs high Western mountain ridge (Y up to 17.5m)
	# - JUMP 2 Super-Leap over central creek from West bank to East bank
	# - Sweeps through southern meadow glade on solid ground and aligns smoothly into Finish straight!
	var curve_pts = [
		# --- SECTION 0: START / FINISH STRAIGHT (West bank, X = -45m, Y = 0.8m, heading North towards -Z) ---
		# 0: Finish Line / Starting Grid
		[Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(-45.0, 0.8, 120.0)],
		# 1: High-speed valley straight
		[Vector3(0, 0, 25), Vector3(0, 0, -25), Vector3(-45.0, 1.2, 50.0)],
		# 2: Approach to Turn 1
		[Vector3(0, -0.3, 20), Vector3(0, 0.5, -20), Vector3(-45.0, 2.0, -10.0)],

		# --- SECTION 1: CROSSING 1 (JUMP 1 OVER CENTRAL CREEK: WEST TO EAST) ---
		# 3: Jump 1 In-run Embankment Climb
		[Vector3(-6, -1.0, 15), Vector3(6, 1.0, -15), Vector3(-35.0, 5.5, -50.0)],
		# 4: Jump 1 Takeoff Lip (X=-16m, Y=8.5m, launching North-East across creek)
		[Vector3(-10, -0.8, 12), Vector3(14, 1.8, -16), Vector3(-16.0, 8.5, -72.0)],
		# 5: Jump 1 Landing Terrace on East bank (X=+26m, Y=4.5m)
		[Vector3(-14, 1.5, 16), Vector3(8, -0.5, -12), Vector3(26.0, 4.5, -112.0)],

		# --- SECTION 2: EAST FLANK CLIMB & THE FORK (BRANCHING PATH) ---
		# 6: Sweeping along eastern snowy terrace
		[Vector3(-8, -0.5, 12), Vector3(8, 0.6, -14), Vector3(42.0, 6.5, -140.0)],
		# 7: Pre-Fork Approach (Checkpoint 5 placed here right before the split)
		[Vector3(-6, -0.5, 15), Vector3(6, 0.5, -15), Vector3(56.0, 8.5, -175.0)],
		# 8: Standard Route (Route A): Wide outer scenic bluff overlooking valley
		[Vector3(-12, -0.5, 16), Vector3(8, 0.3, -18), Vector3(82.0, 10.5, -215.0)],
		# 9: Standard Route: High vista sweep
		[Vector3(6, 0.3, 16), Vector3(-8, -0.4, -16), Vector3(80.0, 9.5, -255.0)],
		# 10: Re-merging point where Standard and Alternative routes rejoin (Checkpoint 6 placed here)
		# Placed so the run from point 9 into the bridge is one steady left-hander: it has to arrive at
		# point 11 heading due west, and from the old spot (48, -280) heading west-north-west the curve
		# could only get there by hooking back east first, folding the road on the inside of the hook.
		[Vector3(10.8, 0.6, 10.4), Vector3(-5.8, -0.3, -5.5), Vector3(54.0, 5.6, -294.0)],

		# --- SECTION 3: CROSSING 2 (ALPINE TIMBER BRIDGE OVER CREEK: EAST TO WEST) ---
		# 11: East entrance approach to Alpine Bridge
		# 11 and 13 sit 3m past the deck ends (x = +-30) with level handles along the bridge axis, so
		# the road is dead straight and flat over the whole deck. At +-24 the curve was already
		# turning and climbing over the last 6m of deck: the lane edge ran off the deck end onto
		# open ravine on the east side, and the trunk stood 30cm above the deck on the west side.
		[Vector3(8, 0, 0), Vector3(-10, 0, 0), Vector3(33.0, 4.8, -305.0)],
		# 12: Alpine Timber Bridge Center (X = 0m, Z = -305m, Y = 4.8m)
		[Vector3(10, 0, 0), Vector3(-10, 0, 0), Vector3(0.0, 4.8, -305.0)],
		# 13: West exit of Alpine Bridge (Checkpoint 7 placed here)
		[Vector3(10, 0, 0), Vector3(-10, 0, 0), Vector3(-33.0, 4.8, -305.0)],

		# --- SECTION 4: HIGH WESTERN RIDGE OVERLOOK (CLIMB TO SUMMIT) ---
		# 14: Ascending western snowy knoll
		[Vector3(12, -0.5, -6), Vector3(-12, 0.8, 10), Vector3(-55.0, 7.5, -295.0)],
		# 15: Hairpin turn climbing high western ridge
		[Vector3(6, -0.8, -14), Vector3(-4, 0.8, 18), Vector3(-82.0, 11.5, -260.0)],
		# 16: High western ridge traverse overlooking the whole valley
		[Vector3(2, -0.6, -20), Vector3(-2, 0.5, 22), Vector3(-96.0, 15.0, -180.0)],
		# 17: High peak summit traverse
		[Vector3(0, -0.2, -25), Vector3(0, 0.2, 25), Vector3(-98.0, 17.5, -80.0)],
		# 18: High ridge continuing south along mountain crest
		[Vector3(-2, 0.2, -22), Vector3(2, -0.2, 22), Vector3(-92.0, 17.0, 10.0)],
		# 19: Crest turn heading East towards creek (Approach to Jump 2)
		[Vector3(-8, 0.3, -18), Vector3(12, -0.1, 16), Vector3(-68.0, 15.5, 80.0)],

		# --- SECTION 5: CROSSING 3 (JUMP 2 SUPER-LEAP: WEST TO EAST OVER CREEK) ---
		# 20: Jump 2 Takeoff Lip (X=-22m, Y=15.5m, Z=125m, launching South-East across creek)
		[Vector3(-14, 0.2, -10), Vector3(18, 1.8, 12), Vector3(-22.0, 15.5, 125.0)],
		# 21: Jump 2 Landing Terrace on East bank (X=+30m, Y=5.5m, Z=168m)
		[Vector3(-16, 2.0, -12), Vector3(10, -0.6, 10), Vector3(30.0, 5.5, 168.0)],

		# --- SECTION 6: SOUTH MEADOW LOOP & RETURN TO FINISH STRAIGHT ---
		# 22: Sweeping around southern alpine forest (solid ground south of creek)
		[Vector3(-6, 0.4, -14), Vector3(-6, -0.3, 14), Vector3(38.0, 3.5, 215.0)],
		# 23: Southern meadow crossing
		[Vector3(14, 0.3, 0), Vector3(-16, -0.2, 0), Vector3(5.0, 2.2, 245.0)],
		# 24: Turn rounding back toward home straight
		[Vector3(12, 0.2, 10), Vector3(-10, -0.2, -12), Vector3(-35.0, 1.4, 225.0)],
		# 25: Aligning smoothly onto Start / Finish straight
		[Vector3(4, 0.2, 16), Vector3(0, -0.1, -20), Vector3(-45.0, 0.9, 180.0)],
		# 26: Return to Start / Finish Line (smooth loop closure)
		[Vector3(0, 0.1, 20), Vector3(0, 0, -25), Vector3(-45.0, 0.8, 120.0)],
	]

	for pt in curve_pts:
		curve.add_point(pt[2], pt[0], pt[1])
	# Make every handle pair collinear. The authored in/out handles above were not, which put a
	# tangent break -- a corner -- in the road at most control points (46 degrees at point 22, 10-14 at
	# eight others). The road ribbon folds over itself on the inside of a corner, and that fold was the
	# bump felt at the Glade fork and on the run down to the Alpine bridge. The jump lips and landings
	# keep their authored break: that change of pitch is the launch and the touchdown.
	const KEEP_TANGENT_BREAK := [4, 5, 20, 21]
	for i in range(1, curve.point_count - 1):
		if i in KEEP_TANGENT_BREAK:
			continue
		var h_in: Vector3 = curve.get_point_in(i)
		var h_out: Vector3 = curve.get_point_out(i)
		var dir: Vector3 = (h_out.normalized() - h_in.normalized()).normalized()
		curve.set_point_in(i, -dir * h_in.length())
		curve.set_point_out(i, dir * h_out.length())

	track_path.curve = curve
	main_track_curve = curve
	level_scene.add_child(track_path)

	# 3. TerrainGenerator Setup (Frostpeak Creek Snow World)
	var tg := Node3D.new()
	tg.name = "TerrainGenerator"
	var tg_script: Script = load("res://TerrainGenerator.gd")
	tg.set_script(tg_script)
	tg.set("level_prefix", "frostpeak_creek")
	tg.set("track_layout_type", 0)
	tg.set("terrain_resolution", 420)
	tg.set("terrain_size", Vector2(900.0, 900.0))
	tg.set("hill_height", 16.0)
	tg.set("road_width", 15.0)
	tg.set("curb_outer_width", 17.0)
	tg.set("road_y_offset", 0.06)
	tg.set("curb_y_offset", 0.06)
	tg.set("terrain_recession_collision", 0.12)
	tg.set("terrain_recession_visual", 0.18)
	tg.set("no_water", false)
	tg.set("no_grass", true)
	tg.set("terrain_grass_count", 0)
	tg.set("generate_bridge_supports", false)

	# Snow Terrain Material (Pure crisp alpine snow PBR)
	var sand_norm: Texture2D = load("res://materials/sand_normal.png") as Texture2D
	var snow_mat := StandardMaterial3D.new()
	snow_mat.albedo_color = Color(0.97, 0.98, 1.0)
	snow_mat.roughness = 0.92
	snow_mat.metallic = 0.02
	if sand_norm:
		snow_mat.normal_enabled = true
		snow_mat.normal_texture = sand_norm
		snow_mat.normal_scale = 0.4
		snow_mat.uv1_scale = Vector3(0.15, 0.15, 0.15)
		snow_mat.uv1_triplanar = true
	tg.set("grass_material", snow_mat)

	# Alpine mountain circuit: high-contrast dark asphalt tarmac with racing rumble curbs
	tg.set("no_curbs", false)
	tg.set("road_material", _alpine_road_material())

	# 4. Alternative Routes (Branching Shortcut Paths)
	# The shortcut centrelines are laid out *before* the terrain is generated: TerrainGenerator grades
	# the ground under them (it used to know only the trunk, so snow stood up through both shortcut
	# decks) and opens the trunk curb exactly where a shortcut deck crosses it. Their meshes are built
	# after the terrain, because the embankment walls are sized against the finished ground.

	# --- DIVERGENCE 1: Canyon Cut (Inner Snow Ravine Shortcut) ---
	# Forks off the east flank, drops through the inner snow ravine past the drift zone, and
	# rejoins the trunk on the alpine bridge approach. Both ends are noses on the deck edge.
	# The merge sits on the straight run down to the Alpine Timber Bridge rather than at the corner
	# on curve point 10: that corner swings the trunk through ~50 degrees, so a chord arriving from
	# the west cannot meet it tangentially and was leaving a 57 degree merge kink.
	var alt1_curve := _build_ramp_curve(
		Vector3(53.0, 8.52, -174.0), Vector3(42.0, 5.7, -284.0), -1, [
			Vector3(45.0, 7.40, -218.0),
			Vector3(42.0, 6.60, -244.0),
		], 20.0, 16.0)

	# --- DIVERGENCE 2: Glade Creek Bridge (Southern Meadow Shortcut) ---
	# Forks off the east flank, crosses the creek on the Glade Timber Bridge and rejoins the western
	# straight well north of it. The fork is well north of the crossing on purpose: the trunk runs
	# almost due south there, so the shortcut has to swing ~70 degrees out of the gore to reach a
	# west-running crossing, and that swing needs length or the merge radius collapses.
	# The merge is moved well up the western straight so the shortcut has a long parallel run to line
	# up on; meeting it just north of the bridge left no room to swing from a west heading to north.
	#
	# The two crossing waypoints are authored first and the bridge is then fitted to the chord between
	# them. Doing it the other way round -- pinning the road straight across a fixed span -- forces a
	# tangent break at one abutment or the other, and a tangent break in a road centreline is a cusp
	# however good the radius looks either side of it.
	# 2.2m over the water is still ~6m above the creek bed. At 4.8m the shortcut came off the west
	# abutment 3.6m above the trunk with only ~10m left before its deck runs alongside the trunk lane,
	# so it overlapped the trunk while still 1.4-2.6m higher -- a ledge in the middle of the road.
	var glade_cross_east := Vector3(5.0, 2.20, 205.0)
	var glade_cross_west := Vector3(-21.0, 2.20, 201.0)
	var alt2_curve := _build_ramp_curve(
		Vector3(33.0, 5.00, 180.0), Vector3(-45.0, 0.86, 152.0), 1, [
			glade_cross_east,
			glade_cross_west,
			# Carry on west past the abutment before turning north, and space the two turn points
			# far enough apart that the 75 degree swing is spread over a real arc rather than
			# crushed into a single short segment.
			Vector3(-31.0, 1.30, 194.0),
			Vector3(-33.0, 1.05, 182.0),
		], 14.0, 20.0)
	# Bridge geometry is read off the road, never the other way round.
	var glade_axis := (glade_cross_west - glade_cross_east).normalized()
	var glade_center := (glade_cross_east + glade_cross_west) * 0.5
	var glade_length: float = glade_cross_east.distance_to(glade_cross_west)
	var glade_yaw: float = rad_to_deg(atan2(-glade_axis.z, glade_axis.x))
	# Catmull-Rom aims the crossing handles at the neighbouring waypoints, which bowed the road 1.6m
	# off the chord and over the deck edge. Turning both handles of each crossing onto the chord keeps
	# them collinear (no tangent break) and makes the span straight; the swing either side absorbs it.
	for ci in [2, 3]:  # nose, entry, then the two crossing waypoints
		alt2_curve.set_point_in(ci, -glade_axis * alt2_curve.get_point_in(ci).length())
		alt2_curve.set_point_out(ci, glade_axis * alt2_curve.get_point_out(ci).length())

	# The bridge owns the crossing, so the shortcut deck is punched out under it and the ravine
	# (and the water in it) is left open. Without this the cobble deck and its 9m embankment run
	# straight through the middle of the bridge.
	var bridge_mid: float = alt2_curve.get_closest_offset(glade_center)
	var bridge_gap := _span_around(alt2_curve, bridge_mid, glade_length * 0.5)

	var alt1_rings: Array = _shortcut_rings(alt1_curve, RAMP_1_HALF_W, Vector2.ZERO)
	var alt2_rings: Array = _shortcut_rings(alt2_curve, RAMP_2_HALF_W, bridge_gap)
	var openings: Array = []
	openings.append_array(_junction_openings(alt1_rings, -1.0))
	openings.append_array(_junction_openings(alt2_rings, 1.0))
	for o in openings:
		print("  Trunk curb opening %.1f..%.1fm on the %s" % [o.x, o.y, "left" if o.z < 0.0 else "right"])
	tg.set("junction_openings", openings)
	tg.set("extra_road_curves", [[alt1_curve, RAMP_1_HALF_W], [alt2_curve, RAMP_2_HALF_W]])

	level_scene.add_child(tg)
	tg.set("track_path", track_path)
	tg.call("generate_world")

	var alt_container := Node3D.new()
	alt_container.name = "AlternativePaths"
	level_scene.add_child(alt_container)

	var alt1_path := Path3D.new()
	alt1_path.name = "AlternativePath_CanyonCut"
	alt1_path.curve = alt1_curve
	alt_container.add_child(alt1_path)
	_verify_ramp_junction(alt1_curve, RAMP_1_HALF_W, "Canyon Cut shortcut")

	# Generate 3D cobblestone road mesh, curbs, solid stone embankment & collision for Canyon Cut
	_build_cobblestone_road(level_scene, alt1_curve, alt1_rings, RAMP_1_HALF_W, "AlternativeRoad",
		Vector2.ZERO)

	var alt2_path := Path3D.new()
	alt2_path.name = "AlternativePath_GladeBridge"
	alt2_path.curve = alt2_curve
	alt_container.add_child(alt2_path)
	_verify_ramp_junction(alt2_curve, RAMP_2_HALF_W, "Glade Creek shortcut")
	_verify_bridge_alignment(alt2_curve, glade_cross_east, glade_cross_west, RAMP_2_HALF_W, 6.0,
		"Glade Timber Bridge")
	print("  Glade deck gap %.1f..%.1fm (bridge_mid %.1f, span %.1f, route %.1f)" % [
		bridge_gap.x, bridge_gap.y, bridge_mid, glade_length, alt2_curve.get_baked_length()])
	_build_cobblestone_road(level_scene, alt2_curve, alt2_rings, RAMP_2_HALF_W,
		"AlternativeRoad_Glade", bridge_gap)

	# Detailed Glade Timber Bridge across the creek on Alternative Route 2
	# The Glade deck stands about 8.5m over a creek bed at -3.8, so its piers need to be long
	# enough to actually land in the water rather than hovering over it.
	# The deck top sits 8cm above the bridge origin while the shortcut's flat deck is 5cm above its
	# centreline, so the bridge drops 3cm to meet the road flush at both abutments.
	_build_detailed_alpine_bridge(level_scene, glade_center + Vector3(0.0, SHORTCUT_DECK_Y - BRIDGE_DECK_TOP, 0.0),
		glade_length, 12.0, "GladeTimberBridge", glade_yaw, true, 9.5)

	# 5. Alpine Timber Bridge across Creek (Crossing 2: X = -30m to +30m at Z = -305, Y = 4.8m)
	# Full continuous timber truss railings on both sides of the bridge.
	_build_detailed_alpine_bridge(level_scene, Vector3(0.0, 4.8, -305.0), 60.0, 17.6,
		"AlpineTimberBridge", 0.0, true, 9.5, Vector2.ZERO)

	# Baked lengths of the two shortcuts, used below to place their props by fraction rather than
	# by hard-coded distances so they follow the road when a junction is retuned.
	var alt1_len: float = alt1_curve.get_baked_length()
	var alt2_len: float = alt2_curve.get_baked_length()

	# 6. Natural Snow-Covered Sections on Road (Organic surface drifts with "snow" group & "is_snow" meta)
	var snow_sections := Node3D.new()
	snow_sections.name = "SnowCoveredRoadSections"
	level_scene.add_child(snow_sections)

	# Every drift is laid along its road: row by row across the carriageway, stopping short of the
	# curbs, so it follows a bend and can never hang over the road edge onto open air. Trunk drifts are
	# placed by the nearest point on the trunk to their old world anchors.
	var trunk_drift_hw: float = MAIN_ROAD_HALF_W - 0.4
	for td in [
		# Section A: Pre-Jump 1 In-run Snowdrift
		["SnowDrift_Jump1Approach", Vector3(-32.0, 5.68, -52.0), 18.0, 1.15, 0.0],
		# Section B: Eastern Flank Glade
		["SnowDrift_EastGlade", Vector3(45.0, 6.68, -145.0), 16.0, 1.05, 1.8],
		# Section D: High Summit Ridge Snowdrift
		["SnowDrift_SummitRidge", Vector3(-98.0, 17.56, -80.0), 20.0, 1.10, 5.2],
		# Section E: Pre-Jump 2 Summit Snowdrift
		["SnowDrift_Jump2Approach", Vector3(-45.0, 15.56, 100.0), 16.0, 1.20, 7.1],
	]:
		_create_road_snow_drift(snow_sections, td[0], curve, curve.get_closest_offset(td[1]), td[2],
			trunk_drift_hw, td[3], TRUNK_DECK_Y, 0.0, td[4])

	# Sections on the shortcuts are sampled off the curve rather than hard-coded, so they keep
	# sitting on the road when a junction is moved. They sit inside the curbs, on the crowned deck.
	# Section C: Deep snow through the Canyon Cut drift zone
	_create_road_snow_drift(snow_sections, "SnowDrift_AltRouteCut", alt1_curve, alt1_len * 0.58, 22.0,
		RAMP_1_HALF_W - 0.55, 1.30, SHORTCUT_DECK_Y, 0.08, 3.5)
	# Section F: Southern meadow drift on the Glade Creek approach
	_create_road_snow_drift(snow_sections, "SnowDrift_GladeMeadow", alt2_curve, alt2_len * 0.22, 16.0,
		RAMP_2_HALF_W - 0.55, 1.15, SHORTCUT_DECK_Y, 0.08, 4.2)

	# 7. Players node
	var players_node := Node3D.new()
	players_node.name = "Players"
	level_scene.add_child(players_node)

	# 8. Finish Line & Starting Grid
	var gate_scene: PackedScene = load("res://CheckpointGate.tscn")
	var spawn_scene: PackedScene = load("res://SpawnIndicator.tscn")

	var finish_line = gate_scene.instantiate()
	finish_line.name = "FinishLine"
	finish_line.position = Vector3(-45.0, 0.86, 120.0)
	finish_line.rotation_degrees = Vector3(0, 0, 0)
	finish_line.set("is_finish_line", true)
	level_scene.add_child(finish_line)

	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	finish_line.add_child(spawn_points)

	var grid_coords = [
		Vector3(-2.8, 0.05, 5.0),
		Vector3(2.8, 0.05, 5.0),
		Vector3(-2.8, 0.05, 12.0),
		Vector3(2.8, 0.05, 12.0),
		Vector3(-2.8, 0.05, 19.0),
		Vector3(2.8, 0.05, 19.0)
	]
	for i in range(grid_coords.size()):
		var sp := Marker3D.new()
		sp.name = "Spawn%d" % (i + 1)
		sp.position = grid_coords[i]
		sp.gizmo_extents = 0.3
		spawn_points.add_child(sp)

		if spawn_scene:
			var si = spawn_scene.instantiate()
			si.name = "SpawnIndicator"
			sp.add_child(si)

	# 9. Multiplayer Spawners
	var p_spawner := MultiplayerSpawner.new()
	p_spawner.name = "PlayerSpawner"
	p_spawner.set("_spawnable_scenes", PackedStringArray(["uid://cart123"]))
	p_spawner.spawn_path = NodePath("../Players")
	p_spawner.spawn_limit = 6
	level_scene.add_child(p_spawner)

	var proj_spawner := MultiplayerSpawner.new()
	proj_spawner.name = "ProjectileSpawner"
	proj_spawner.spawn_path = NodePath(".")
	level_scene.add_child(proj_spawner)

	# 10. Checkpoints Container (6 curve-aligned milestone checkpoints + Finish Line)
	var checkpoints_container := Node3D.new()
	checkpoints_container.name = "Checkpoints"
	level_scene.add_child(checkpoints_container)

	var track_len: float = curve.get_baked_length()
	# 6 milestone checkpoints spaced along the 1350m track, avoiding mid-air jump gaps:
	# CP 1: 130m - Valley floor straight before Jump 1 in-run
	# CP 2: 330m - East bank climb before branching fork 1
	# CP 3: 470m - Post-merge approach on solid ground before Alpine Timber Bridge
	# CP 4: 700m - Western mountain climb shelf heading South
	# CP 5: 900m - High summit ridge overlook before Jump 2 approach
	# CP 6: 1105m - Jump 2 landing terrace before branching fork 2
	var milestone_offsets = [130.0, 330.0, 470.0, 700.0, 900.0, 1105.0]

	for i in range(milestone_offsets.size()):
		var dist_along: float = milestone_offsets[i]
		var cp_pos := curve.sample_baked(dist_along)
		var next_pos := curve.sample_baked(minf(track_len, dist_along + 1.0))
		var forward := (next_pos - cp_pos).normalized()
		var rot_y := rad_to_deg(atan2(-forward.x, -forward.z))

		var gate = gate_scene.instantiate()
		gate.name = "Checkpoint_%d" % (i + 1)
		gate.position = cp_pos + Vector3(0, 0.1, 0)
		gate.rotation_degrees = Vector3(0, rot_y, 0)
		checkpoints_container.add_child(gate)


	# 12. Boost Pads
	var boost_scene: PackedScene = load("res://BoostPad.tscn")
	var boost_container := Node3D.new()
	boost_container.name = "BoostPads"
	level_scene.add_child(boost_container)

	if boost_scene:
		var bp_defs = [
			# Jump 1 Takeoff pair
			["Boost_Jump1_L", Vector3(-24.0, 7.5, -64.0), 314.0],
			["Boost_Jump1_R", Vector3(-20.0, 7.5, -60.0), 314.0],
			# Jump 2 Takeoff pair
			["Boost_Jump2_L", Vector3(-30.0, 15.5, 118.0), 220.0],
			["Boost_Jump2_R", Vector3(-26.0, 15.5, 114.0), 220.0],
			# Valley Straight Booster
			["Boost_StartStraight", Vector3(-45.0, 1.0, 80.0), 180.0],
			# High Summit Ridge Overlook
			["Boost_SummitStraight", Vector3(-98.0, 17.5, -40.0), 0.0]
		]
		for bp_info in bp_defs:
			var bp = boost_scene.instantiate()
			bp.name = bp_info[0]
			bp.position = bp_info[1]
			bp.rotation_degrees = Vector3(0, bp_info[2], 0)
			boost_container.add_child(bp)

		# Shortcut boosters are sampled off the curves so they stay on the road when a junction is
		# retuned. Each pair sits on the shortcut so taking it is worth the risk of the gore.
		# taking rather than just shorter.
		var alt_boosts = [
			["Boost_AltShortcut_1", alt1_curve, alt1_len * 0.26, 0.0],
			["Boost_AltShortcut_2", alt1_curve, alt1_len * 0.40, 0.0],
			["Boost_AltGlade_1", alt2_curve, alt2_len * 0.18, 0.0],
			# Lead-in for the Glade ramp, on the open meadow west of the bridge.
			["Boost_AltGlade_2", alt2_curve, bridge_mid + glade_length * 0.5 + 0.5, 0.0],
		]
		for b in alt_boosts:
			var spot: Array = _place_on_curve(b[1], b[2], b[3], 0.05)
			var bp2 = boost_scene.instantiate()
			bp2.name = b[0]
			bp2.position = spot[0]
			bp2.rotation_degrees = Vector3(0, spot[1], 0)
			boost_container.add_child(bp2)

	# 13. Item Boxes
	var item_scene: PackedScene = load("res://ItemBox.tscn")
	var item_container := Node3D.new()
	item_container.name = "ItemBoxes"
	level_scene.add_child(item_container)

	if item_scene:
		var item_rows = [
			# Row 1: Valley Straight (Z = 90)
			[Vector3(-48.0, 1.4, 90.0), Vector3(-45.0, 1.4, 90.0), Vector3(-42.0, 1.4, 90.0)],
			# Row 2: Standard Route Bluff (Z = -235)
			[Vector3(84.0, 10.8, -235.0), Vector3(81.0, 10.8, -235.0), Vector3(78.0, 10.8, -235.0)],
			# Row 3: Approach to Alpine Timber Bridge (Z = -305)
			[Vector3(16.0, 5.4, -305.0), Vector3(12.0, 5.4, -305.0)],
			# Row 4: High Summit Ridge before Jump 2 (Z = 40)
			[Vector3(-94.0, 17.8, 40.0), Vector3(-91.0, 17.8, 40.0), Vector3(-88.0, 17.8, 40.0)],
		]
		var item_idx := 1
		for row in item_rows:
			for pos in row:
				var ib = item_scene.instantiate()
				ib.name = "ItemBox_%d" % item_idx
				ib.position = pos
				item_container.add_child(ib)
				item_idx += 1

		# Item rows on the shortcuts, spread across the lane and sampled off the curve.
		var alt_item_rows = [
			[alt1_curve, alt1_len * 0.34, [-3.0, 0.0, 3.0]],
			[alt2_curve, alt2_len * 0.30, [-2.5, 2.5]],
			# Reward row on the landing side of the Glade ramp.
			[alt2_curve, bridge_mid + glade_length * 0.5 + 26.0, [-2.5, 2.5]],
		]
		for arow in alt_item_rows:
			for side_off in arow[2]:
				var spot: Array = _place_on_curve(arow[0], arow[1], side_off, 0.9)
				var ib2 = item_scene.instantiate()
				ib2.name = "ItemBox_%d" % item_idx
				ib2.position = spot[0]
				item_container.add_child(ib2)
				item_idx += 1

	# 14. Vegetation Container (Kept empty - ready for manual tree placement)
	var veg_container := Node3D.new()
	veg_container.name = "Vegetation"
	level_scene.add_child(veg_container)

	# 15. Rebuild Checkpoints Array & Wire up Level
	level_scene.set("track_path", track_path)
	level_scene._setup_checkpoints()

	# 16. Scene Ownership
	_set_owner_recursive(level_scene, level_scene)

	# 17. Save Packed Scene
	remove_child(level_scene)
	var target_path := "res://levels/FrostpeakCreekLevel.tscn"
	var packed_scene := PackedScene.new()
	var pack_err = packed_scene.pack(level_scene)
	if pack_err != OK:
		push_error("Failed to pack FrostpeakCreekLevel.tscn: %d" % pack_err)
		get_tree().quit(1)
		return

	var save_err = ResourceSaver.save(packed_scene, target_path)
	if save_err != OK:
		push_error("Failed to save FrostpeakCreekLevel.tscn: %d" % save_err)
		get_tree().quit(1)
		return

	print("Successfully generated and saved res://levels/FrostpeakCreekLevel.tscn!")
	get_tree().quit(0)


## Places a prop on a curve `at` metres along it, squared to the road, offset `side_offset` metres
## to the right of the direction of travel.
func _place_on_curve(curve: Curve3D, at: float, side_offset: float, y_lift: float = 0.0) -> Array:
	var clamped: float = clampf(at, 0.0, curve.get_baked_length())
	var pos: Vector3 = curve.sample_baked(clamped)
	var fwd: Vector3 = _tangent_at(curve, clamped)
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	return [pos + right * side_offset + Vector3(0.0, y_lift, 0.0),
		rad_to_deg(atan2(-fwd.z, fwd.x))]


## Lays a SnowDrift over `length` metres of road centred `at` metres along `curve`.
##
## The drift gets one cross-section row every 0.25m: the row's centre on the road surface (curve +
## `deck_y`) and its horizontal right vector. SnowDrift builds its height field over those rows, out
## to `half_width` either side, so it bends with the road and ends inside the curbs. `crown` is how
## much higher the deck is on its centreline than at the drift edges.
func _create_road_snow_drift(parent: Node, drift_name: String, curve: Curve3D, at: float, length: float,
		half_width: float, height: float, deck_y: float, crown: float, seed_offset: float) -> void:
	var total: float = curve.get_baked_length()
	var start: float = clampf(at - length * 0.5, 0.0, total)
	var stop: float = clampf(at + length * 0.5, 0.0, total)
	var origin: Vector3 = curve.sample_baked(clampf(at, 0.0, total)) + Vector3(0.0, deck_y, 0.0)
	var centres := PackedVector3Array()
	var rights := PackedVector3Array()
	var n: int = maxi(int((stop - start) / 0.25), 2) + 1
	for i in range(n):
		var d: float = lerpf(start, stop, float(i) / float(n - 1))
		var f: Dictionary = _frame_at_offset(curve, d)
		centres.append((f["pos"] as Vector3) + Vector3(0.0, deck_y, 0.0) - origin)
		rights.append(f["right"])
	var drift_scene: PackedScene = load("res://SnowDrift.tscn")
	var drift = drift_scene.instantiate()
	drift.name = drift_name
	drift.position = origin
	drift.set("size", Vector3(half_width * 2.0, height, length))
	drift.set("drift_half_width", half_width)
	drift.set("base_crown", crown)
	drift.set("seed_offset", seed_offset)
	drift.set("row_centres", centres)
	drift.set("row_rights", rights)
	parent.add_child(drift)


## Handles for one control point, derived from the directions of the segments either side.
##
## The tangent bisects the incoming and outgoing travel directions, and its length is whatever
## Catmull-Rom wants or whatever the turn radius needs, capped so the control polygon cannot fold
## back on itself. A dead-straight reversal has no bisector, so that case falls back to the
## horizontal perpendicular that points along the chord across the corner.
func _handles_for(seg_in: Vector3, seg_out: Vector3, min_radius: float) -> Array:
	var l_in: float = seg_in.length()
	var l_out: float = seg_out.length()
	# A zero-length segment has no direction; inventing one from FORWARD is what puts a kink in
	# the curve, so fall back to the other side.
	var u_in: Vector3 = seg_in / l_in if l_in > 0.001 else (seg_out.normalized() if l_out > 0.001 else Vector3.FORWARD)
	var u_out: Vector3 = seg_out / l_out if l_out > 0.001 else u_in
	var dir: Vector3 = u_in + u_out
	if dir.length_squared() < 0.02:
		var perp := Vector3(-u_in.z, 0.0, u_in.x)
		if perp.length_squared() < 1e-6:
			perp = Vector3.RIGHT
		dir = perp.normalized()
		if dir.dot(seg_in + seg_out) < 0.0:
			dir = -dir
	else:
		dir = dir.normalized()
	# A cubic approximates a circular arc of angle theta with handle (4/3)tan(theta/4)R.
	var theta: float = u_in.angle_to(u_out)
	var needed: float = (4.0 / 3.0) * tan(theta * 0.25) * min_radius
	var catmull: float = (l_in + l_out) / 6.0
	var ceiling: float = 0.45 * minf(l_in, l_out)
	var h: float = clampf(maxf(needed, catmull), 2.0, maxf(ceiling, 2.0))
	return [dir * -h, dir * h, needed > ceiling]


## Handle length for a junction gore segment. Capped at 45% of the segment so the tangent-continuous
## handle can never double back through the control point at the far end of it.
func _nose_handle(seg_len: float) -> float:
	return clampf(minf(RAMP_NOSE_HANDLE, seg_len * 0.45), 1.0, seg_len * 0.45)


## Position / tangent / right vector / signed lateral / baked offset of the point on `curve`
## closest to `p`. The lateral is measured in the curve's own horizontal frame, which is what
## deck tiling needs.
func _frame_at(curve: Curve3D, p: Vector3) -> Dictionary:
	var length: float = curve.get_baked_length()
	var off: float = curve.get_closest_offset(p)
	var c: Vector3 = curve.sample_baked(off)
	var fwd: Vector3 = _tangent_at(curve, off)
	var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()
	return {"pos": c, "fwd": fwd, "right": right, "lat": (p - c).dot(right), "off": off}


## Frame on `curve` a given distance along it, without a nearest-point search.
func _frame_at_offset(curve: Curve3D, off: float) -> Dictionary:
	var length: float = curve.get_baked_length()
	off = clampf(off, 0.0, length)
	var c: Vector3 = curve.sample_baked(off)
	var fwd: Vector3 = _tangent_at(curve, off)
	return {"pos": c, "fwd": fwd, "right": Vector3(-fwd.z, 0.0, fwd.x).normalized(), "off": off}


## Unit tangent `off` metres along `curve`.
func _tangent_at(curve: Curve3D, off: float) -> Vector3:
	var length: float = curve.get_baked_length()
	off = clampf(off, 0.0, length)
	var v: Vector3 = curve.sample_baked(minf(length, off + 1.0)) - curve.sample_baked(off)
	return v.normalized() if v.length() > 1e-5 else Vector3.FORWARD


## Builds a shortcut curve whose ends are noses sitting exactly on the trunk deck edge
## (`side` = +1 right of travel / -1 left), with the junction handles aligned to the trunk
## tangent so the shortcut leaves and rejoins along the trunk instead of kinking across it.
##
## Junctions are given as world anchors rather than distances along the trunk, so they stay where
## they were authored even when the trunk's own shape is retuned.
##
## `waypoints` are plain positions between the two noses. Interior handles are derived
## Catmull-Rom style against the trunk direction at each end, so the tangent stays continuous
## across the junction; deriving them from the nose position instead leaves a kink where a
## straight nose meets an angled waypoint, which shows up as a pinch in the deck.
##
## Nothing here forces the ribbon straight between two waypoints. Pinning a straight span looks
## right until the road has to turn at one of its ends, and then the tangent break at that abutment
## is a cusp no matter how good the radius looks either side of it. The Glade bridge is instead
## placed on the road's own chord, and _verify_bridge_alignment() fails the build if the road bows
## far enough off that chord to overhang the deck.
func _build_ramp_curve(split_anchor: Vector3, merge_anchor: Vector3, side: int, waypoints: Array,
		lead: float = RAMP_NOSE_LEAD, lead_out: float = -1.0) -> Curve3D:
	if lead_out < 0.0:
		lead_out = lead
	var split: Dictionary = _frame_at(main_track_curve, split_anchor)
	var merge: Dictionary = _frame_at(main_track_curve, merge_anchor)
	var s_fwd: Vector3 = split["fwd"]
	var m_fwd: Vector3 = merge["fwd"]
	var s_right: Vector3 = split["right"]
	var m_right: Vector3 = merge["right"]
	var nose_a: Vector3 = split["pos"] + s_right * (MAIN_NOSE_LATERAL * float(side))
	var nose_b: Vector3 = merge["pos"] + m_right * (MAIN_NOSE_LATERAL * float(side))

	# The approach and departure points are offsets of the *trunk curve*, `lead` metres past the
	# split and before the merge. Walking the curve rather than stepping in a straight line matters
	# where the trunk turns: a chord from the junction lands well short of the intended offset.
	# Both are measured in the direction of travel and clamped inside the trunk, so they can never
	# invert on a junction near the start or the finish.
	var length: float = main_track_curve.get_baked_length()
	var fa: Dictionary = _frame_at_offset(main_track_curve, clampf(split["off"] + lead, 0.0, length))
	var fb: Dictionary = _frame_at_offset(main_track_curve, clampf(merge["off"] - lead_out, 0.0, length))
	var entry: Vector3 = fa["pos"] + fa["right"] * (float(side) * RAMP_NOSE_LATERAL)
	var exit_pt: Vector3 = fb["pos"] + fb["right"] * (float(side) * RAMP_NOSE_LATERAL)

	var pts: Array = [nose_a, entry]
	pts.append_array(waypoints)
	pts.append(exit_pt)
	pts.append(nose_b)

	# The first and last segments leave and arrive *along the trunk*, so the nose handles are
	# pinned to the trunk tangent rather than derived. Only the nose is pinned, though: the gore exit
	# is a half-width further out, so the chord between them leans away from the trunk, and pinning
	# the exit handle to the same direction as well leaves the control polygon non-monotonic -- the
	# curve sprints forward, stalls, then sprints again, and the stall is a fold. Leaving the exit on
	# Catmull-Rom lets the lean be taken up as one long, gentle curve, and it cannot push the deck
	# back inside the carriageway because the nose leaves exactly along the deck edge.
	var first_len: float = (pts[1] - pts[0]).length()
	var last_len: float = (pts[pts.size() - 1] - pts[pts.size() - 2]).length()
	var segs_in := PackedVector3Array()
	var segs_out := PackedVector3Array()
	for i in range(pts.size()):
		var prev_p: Vector3 = pts[i - 1] if i > 0 else pts[0] - s_fwd * first_len
		var next_p: Vector3 = pts[i + 1] if i < pts.size() - 1 else pts[pts.size() - 1] + m_fwd * last_len
		segs_in.append(pts[i] - prev_p)
		segs_out.append(next_p - pts[i])

	var c := Curve3D.new()
	c.bake_interval = 0.25
	for i in range(pts.size()):
		var in_h: Vector3
		var out_h: Vector3
		if i == 0:
			# The nose is a straight continuation of the trunk edge, so the gore opens without a
			# kink and the ramp tracks the shoulder before it peels away.
			in_h = -s_fwd * _nose_handle(first_len)
			out_h = s_fwd * _nose_handle(first_len)
		elif i == pts.size() - 1:
			in_h = -m_fwd * _nose_handle(last_len)
			out_h = m_fwd * _nose_handle(last_len)
		else:
			var h: Array = _handles_for(segs_in[i], segs_out[i], RAMP_MIN_RADIUS)
			in_h = h[0]
			out_h = h[1]
		c.add_point(pts[i], in_h, out_h)
	return c


## Absolute lateral reach of a shortcut deck at lateral offset `lat`, returned as
## (inner_edge, outer_edge) measured from the trunk centreline.
##
## The inner edge stays pinned at the nose lateral while the deck widens, so the gore opens by
## growing *outward* and never overlaps the trunk carriageway or leaves a seam in the middle of it.
## The outer edge never falls below MAIN_NOSE_HALF_W, so the nose stays a blunt 3.2m of deck
## rather than tapering to a knife edge sitting on the trunk's edge lip.
func _ramp_deck_extents(lat: float, ramp_half_w: float) -> Vector2:
	var d: float = absf(lat)
	var grow: float = ramp_half_w * clampf((d - MAIN_NOSE_LATERAL) / ramp_half_w, 0.0, 1.0)
	return Vector2(minf(d - grow, MAIN_NOSE_LATERAL), d + maxf(grow, MAIN_NOSE_HALF_W))


## Fails the build if a shortcut junction is not actually joined to the trunk.
##
## Every check here caught a real defect at some point: a shortcut dead-ending inside the racing
## surface, a 57 degree merge kink, a ramp whose min radius folded its own deck inside out. They
## are cheap, so the build refuses to save rather than shipping a broken junction.
func _verify_ramp_junction(alt: Curve3D, half_w: float, label: String) -> void:
	var alen: float = alt.get_baked_length()
	var problems := 0

	for end_i in [0.0, alen]:
		var p: Vector3 = alt.sample_baked(end_i)
		var f: Dictionary = _frame_at(main_track_curve, p)
		var lat: float = absf(f["lat"])
		if absf(lat - MAIN_NOSE_LATERAL) > 0.35:
			problems += 1
			push_error("%s end at %.0fm sits %.2fm off the trunk centreline (nose is at %.1fm) - it does not meet the road" % [label, end_i, lat, MAIN_NOSE_LATERAL])
		# The nose must also be tangent to the trunk, or cars get deflected across the lane.
		var ramp_fwd: Vector3 = _tangent_at(alt, 1.0 if end_i == 0.0 else alen - 1.0)
		var err: float = rad_to_deg(ramp_fwd.angle_to(f["fwd"]))
		if err > 12.0:
			problems += 1
			push_error("%s end at %.0fm meets the trunk at %.1f deg (nose must be tangent)" % [label, end_i, err])
		# And it must be at road height, or there is a step cars trip over.
		var trunk_y: float = (f["pos"] as Vector3).y
		if absf(p.y - trunk_y) > 0.30:
			problems += 1
			push_error("%s end at %.0fm is %.2fm off the trunk deck height (nose %+.2f vs trunk %+.2f)" % [label, end_i, absf(p.y - trunk_y), p.y, trunk_y])

	# The ramp must never dive inside the trunk deck, or its own deck would collapse onto it.
	var worst_lat: float = 1e9
	var worst_at: float = 0.0
	for i in range(int(alen) + 1):
		var lat: float = absf(_frame_at(main_track_curve, alt.sample_baked(float(i)))["lat"])
		if lat < worst_lat:
			worst_lat = lat
			worst_at = float(i)
	if worst_lat < MAIN_NOSE_LATERAL - 0.35:
		problems += 1
		push_error("%s runs %.2fm inside the trunk deck edge at %.0fm" % [label, MAIN_NOSE_LATERAL - worst_lat, worst_at])

	# A centreline tighter than the deck folds the ribbon inside out.
	# Only sampled where a full look-ahead window fits: near either end the forward and backward
	# chords have very different lengths, and the circumradius of that triangle collapses to a
	# nonsense value that has nothing to do with the curve's real curvature.
	var win: float = 8.0
	var worst_r: float = 1e9
	var worst_r_at: float = 0.0
	var lo_i: int = int(win) + 1
	var hi_i: int = int(alen) - int(win) - 1
	for i in range(lo_i, maxi(hi_i, lo_i) + 1):
		var d: float = float(i)
		var v1: Vector3 = alt.sample_baked(d) - alt.sample_baked(d - win)
		var v2: Vector3 = alt.sample_baked(d + win) - alt.sample_baked(d)
		var area2: float = v1.cross(v2).length()
		if area2 < 1e-6 or v1.length() < 0.01 or v2.length() < 0.01:
			continue
		var r: float = (v1.length() * v2.length() * (v1 + v2).length()) / (2.0 * area2)
		if r < worst_r:
			worst_r = r
			worst_r_at = d
	if worst_r - half_w < 6.0:
		problems += 1
		push_error("%s turns to R=%.1fm at %.0fm (inner edge %.1fm) - the deck folds there" % [label, worst_r, worst_r_at, worst_r - half_w])

	if problems == 0:
		print("  %s: joined at both ends, min radius %.1fm (inner edge %.1fm), closest to trunk %.2fm" % [
			label, worst_r, worst_r - half_w, worst_lat])


## Fails the build if the road bows far enough off the chord between its two crossing points to
## overhang the bridge deck it is supposed to be sitting on.
##
## The bridge is placed on that chord rather than the road being forced straight across a fixed span,
## which is what keeps the deck continuous. The cost is a little sagitta, and it has to stay inside
## the deck's spare half width: (deck_half_width - road_half_width).
func _verify_bridge_alignment(curve: Curve3D, cross_a: Vector3, cross_b: Vector3, road_half_w: float,
		deck_half_w: float, label: String) -> void:
	var off_a: float = curve.get_closest_offset(cross_a)
	var off_b: float = curve.get_closest_offset(cross_b)
	var chord_dir := (cross_b - cross_a)
	var chord_len: float = chord_dir.length()
	if chord_len < 1.0:
		push_error("%s: crossing points are only %.1fm apart" % [label, chord_len])
		return
	var chord := chord_dir / chord_len
	var margin: float = deck_half_w - road_half_w
	var worst: float = 0.0
	var worst_at: float = 0.0
	var steps: int = maxi(int(off_b - off_a), 2)
	for i in range(steps + 1):
		var t: float = lerpf(off_a, off_b, float(i) / float(steps))
		var p: Vector3 = curve.sample_baked(t)
		var along: Vector3 = cross_a + chord * (p - cross_a).dot(chord)
		var dev: float = (p - along).length()
		if dev > worst:
			worst = dev
			worst_at = t
	if worst > margin:
		push_error("%s: road bows %.2fm off its %.1fm chord at %.0fm, overrunning the deck by %.2fm (spare half width %.2fm)" % [
			label, worst, chord_len, worst_at, worst - margin, margin])
	else:
		print("  %s: %.1fm span, road bows %.2fm off the chord (spare half width %.2fm)" % [
			label, chord_len, worst, margin])


## Half of `curve`'s baked length either side of `centre`, as a Vector2(start, end) in metres.
## Used to punch the bridge crossing out of a shortcut deck.
func _span_around(curve: Curve3D, centre: float, half_len: float) -> Vector2:
	var length: float = curve.get_baked_length()
	return Vector2(maxf(centre - half_len, 0.0), minf(centre + half_len, length))


## Builds a detailed timber truss bridge: deck, wheel guards, stone abutments and wing walls,
## under-deck girders, cross-braced truss railings, and trestle bents on stone piers.
##
## `pier_depth` is how far the trestle's stone piers reach down from the cap beam into the creek
## bed. It has to be set per bridge from the depth of the water it stands in; too short and the
## piers float above the creek, too long and they spear through it.
##
## `winter_dressing` adds the accumulated-snow pass (snow caps on every up-facing timber, icicles
## along the deck edge and rails, drifts banked against the abutments) plus the extra balusters and
## longitudinal bracing that turn the railing from a few posts into a real truss.
func _build_detailed_alpine_bridge(parent: Node, center: Vector3, length: float, width: float,
		bridge_name: String = "AlpineTimberBridge", yaw_deg: float = 0.0, winter_dressing: bool = false,
		pier_depth: float = 5.0, rail_gap: Vector2 = Vector2.ZERO) -> void:
	var bridge_root := Node3D.new()
	bridge_root.name = bridge_name
	bridge_root.position = center
	bridge_root.rotation_degrees = Vector3(0, yaw_deg, 0)

	# 1. PBR Materials
	var wood_mat := StandardMaterial3D.new()
	var wood_tex: Texture2D = load("res://materials/wood_planks.png") as Texture2D
	var wood_norm: Texture2D = load("res://materials/wood_planks_normal.png") as Texture2D
	var wood_rough: Texture2D = load("res://materials/wood_planks_roughness.png") as Texture2D
	if wood_tex:
		wood_mat.albedo_texture = wood_tex
	if wood_norm:
		wood_mat.normal_enabled = true
		wood_mat.normal_texture = wood_norm
		wood_mat.normal_scale = 1.0
	if wood_rough:
		wood_mat.roughness_texture = wood_rough
	wood_mat.roughness = 0.82
	wood_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	wood_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	wood_mat.uv1_triplanar = true

	# Darker heavy timber for railings, girders & trusses
	var timber_mat := StandardMaterial3D.new()
	if wood_tex:
		timber_mat.albedo_texture = wood_tex
		timber_mat.albedo_color = Color(0.72, 0.68, 0.65)
	if wood_norm:
		timber_mat.normal_enabled = true
		timber_mat.normal_texture = wood_norm
		timber_mat.normal_scale = 0.8
	timber_mat.roughness = 0.88
	timber_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	timber_mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	timber_mat.uv1_triplanar = true

	# Stone masonry for piers & abutments
	var stone_mat := StandardMaterial3D.new()
	var stone_tex: Texture2D = load("res://materials/dark_canyon_rock.png") as Texture2D
	var stone_norm: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D
	if stone_tex:
		stone_mat.albedo_texture = stone_tex
	if stone_norm:
		stone_mat.normal_enabled = true
		stone_mat.normal_texture = stone_norm
		stone_mat.normal_scale = 0.9
	stone_mat.roughness = 0.90
	stone_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	stone_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	stone_mat.uv1_triplanar = true

	# 2. Driving Deck (spanning length=54m from X=-27 to +27, full 17.6m width to cover road and curbs)
	var deck_body := StaticBody3D.new()
	deck_body.name = "BridgeDeck"
	deck_body.add_to_group("track_surface", true)
	deck_body.position = Vector3(0, -0.12, 0)

	var deck_col := CollisionShape3D.new()
	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(length, 0.40, width)
	deck_col.shape = deck_shape
	deck_body.add_child(deck_col)

	var deck_mesh := MeshInstance3D.new()
	deck_mesh.name = "BridgeDeck_Mesh"
	var dm := BoxMesh.new()
	dm.size = Vector3(length, 0.38, width)
	deck_mesh.mesh = dm
	deck_mesh.material_override = wood_mat
	deck_body.add_child(deck_mesh)
	bridge_root.add_child(deck_body)

	# 3. Heavy Timber Wheel-Guard Curbs (left & right deck edges)
	var curb_h := 0.32
	var curb_w := 0.40
	for side in [-1.0, 1.0]:
		var curb_z = side * (width * 0.5 - curb_w * 0.5)
		var curb_inst := MeshInstance3D.new()
		curb_inst.name = "WheelGuard_" + ("N" if side < 0 else "S")
		var cm := BoxMesh.new()
		cm.size = Vector3(length, curb_h, curb_w)
		curb_inst.mesh = cm
		curb_inst.material_override = timber_mat
		curb_inst.position = Vector3(0, 0.16, curb_z)
		bridge_root.add_child(curb_inst)

	# 4. Proportional Stone Shore Abutments (embedded into riverbanks)
	# Deep enough to reach below the creek bed, not just below the top of the bank. The abutments
	# sit just inside the deck ends, which is already out over the bank slope: at a fixed 6.6m the
	# Glade abutments hung in mid-air above the bank (base at world y -1.8 over ground that keeps
	# falling towards the water), and the hollow end of the shortcut's embankment showed under them
	# as a dark wedge. Tying the depth to the pier depth buries the base in every case.
	var abut_len: float = 3.2
	var abut_h: float = maxf(6.6, pier_depth + 1.0)
	# Top 2cm under the deck top rather than flush with the bridge origin (8cm under it): the abutment
	# runs 0.4m past the deck end under the approach road, and at the seam between the two it showed
	# as an 8cm-deep slot.
	var abut_y: float = BRIDGE_DECK_TOP - 0.02 - abut_h * 0.5
	for side in [-1.0, 1.0]:
		var x_pos = side * (length * 0.5 - abut_len * 0.5 + 0.4)
		var abut := StaticBody3D.new()
		abut.name = "StoneAbutment_" + ("E" if side > 0 else "W")
		abut.add_to_group("track_surface", true)
		abut.position = Vector3(x_pos, abut_y, 0)

		var a_col := CollisionShape3D.new()
		var a_shape := BoxShape3D.new()
		a_shape.size = Vector3(abut_len, abut_h, width + 0.6)
		a_col.shape = a_shape
		abut.add_child(a_col)

		var a_mesh := MeshInstance3D.new()
		a_mesh.name = "Abutment_Mesh"
		a_mesh.mesh = _tapered_box_mesh(
			Vector3(abut_len + 0.8, 0.0, width + 1.2),
			Vector3(abut_len, 0.0, width + 0.6), abut_h)
		a_mesh.material_override = stone_mat
		abut.add_child(a_mesh)
		bridge_root.add_child(abut)

		# Stone Wing Walls flanking the approach, angled back into the bank embankment
		for wing_side in [-1.0, 1.0]:
			var wing := MeshInstance3D.new()
			wing.name = "WingWall_" + ("E" if side > 0 else "W") + ("_N" if wing_side < 0 else "_S")
			# Same reasoning as the abutment: a 4.2m wing wall stopped above the bank and floated.
			var wing_h: float = abut_h * 0.75
			wing.mesh = _tapered_box_mesh(Vector3(3.2, 0.0, 0.9), Vector3(2.6, 0.0, 0.7), wing_h)
			wing.material_override = stone_mat
			wing.position = Vector3(side * (length * 0.5 + 0.8), -0.1 - wing_h * 0.5, wing_side * (width * 0.5 + 0.5))
			wing.rotation_degrees = Vector3(0, -side * wing_side * 28.0, 0)
			bridge_root.add_child(wing)

	# 5. Longitudinal Under-Deck Girders (4 heavy timber stringers)
	for g_idx in range(4):
		var gz = -width * 0.40 + g_idx * (width * 0.80 / 3.0)
		var girder := MeshInstance3D.new()
		girder.name = "Girder_%d" % g_idx
		var gm := BoxMesh.new()
		gm.size = Vector3(length - 4.0, 0.70, 0.50)
		girder.mesh = gm
		girder.material_override = timber_mat
		girder.position = Vector3(0, -0.65, gz)
		bridge_root.add_child(girder)

	# 6. Clean Alpine Timber Truss Railings (North and South)
	# Spaced across the full span with solid corner posts at deck ends and clean diagonal X-trusses.
	var rail_z_dist := width * 0.5 - 0.20
	var num_bays: int = maxi(int(round(length / 3.75)), 2)
	var bay_w: float = length / float(num_bays)
	var has_gap: bool = rail_gap.y > rail_gap.x
	var half_len: float = length * 0.5

	for side in [-1.0, 1.0]:
		var rail_side_name = "N" if side < 0 else "S"
		var rz = side * rail_z_dist
		var gap_here: bool = has_gap and side > 0.0
		var runs: Array = [Vector2(-half_len, half_len)]
		if gap_here:
			runs = [Vector2(-half_len, rail_gap.x), Vector2(rail_gap.y, half_len)]

		var in_gap := func(x: float) -> bool:
			return gap_here and x > (rail_gap.x + 0.1) and x < (rail_gap.y - 0.1)

		for run_i in range(runs.size()):
			var run: Vector2 = runs[run_i]
			var run_len: float = run.y - run.x
			if run_len <= 0.5:
				continue
			var run_mid: float = (run.x + run.y) * 0.5
			var suffix := "" if runs.size() == 1 else "_%d" % run_i

			# Solid Railing Collision Wall
			var rail_col_body := StaticBody3D.new()
			rail_col_body.name = "GuardrailCol_" + rail_side_name + suffix
			rail_col_body.position = Vector3(run_mid, 0.80, rz)
			var r_col := CollisionShape3D.new()
			var r_shape := BoxShape3D.new()
			r_shape.size = Vector3(run_len, 1.60, 0.40)
			r_col.shape = r_shape
			rail_col_body.add_child(r_col)
			bridge_root.add_child(rail_col_body)

			# Top Handrail Beam
			var top_rail := MeshInstance3D.new()
			top_rail.name = "TopRail_" + rail_side_name + suffix
			var trm := BoxMesh.new()
			trm.size = Vector3(run_len, 0.28, 0.38)
			top_rail.mesh = trm
			top_rail.material_override = timber_mat
			top_rail.position = Vector3(run_mid, 1.45, rz)
			bridge_root.add_child(top_rail)

			# Mid Rail Beam
			var mid_rail := MeshInstance3D.new()
			mid_rail.name = "MidRail_" + rail_side_name + suffix
			var mrm := BoxMesh.new()
			mrm.size = Vector3(run_len, 0.20, 0.22)
			mid_rail.mesh = mrm
			mid_rail.material_override = timber_mat
			mid_rail.position = Vector3(run_mid, 0.85, rz)
			bridge_root.add_child(mid_rail)

		# Vertical Posts and Diagonal X-Braces
		for p_idx in range(num_bays + 1):
			var px = -half_len + float(p_idx) * bay_w

			# Transverse floor cross-beam under the deck at each post
			if side > 0:
				var floor_beam := MeshInstance3D.new()
				floor_beam.name = "FloorBent_%d" % p_idx
				var fbm := BoxMesh.new()
				fbm.size = Vector3(0.40, 0.50, width + 0.6)
				floor_beam.mesh = fbm
				floor_beam.material_override = timber_mat
				floor_beam.position = Vector3(px, -0.45, 0)
				bridge_root.add_child(floor_beam)

			if in_gap.call(px):
				continue

			var is_terminal: bool = (p_idx == 0 or p_idx == num_bays)
			var post := MeshInstance3D.new()
			post.name = "Post_" + rail_side_name + "_%d" % p_idx
			var post_m := BoxMesh.new()
			post_m.size = Vector3(0.42 if is_terminal else 0.34, 1.60, 0.42 if is_terminal else 0.34)
			post.mesh = post_m
			post.material_override = timber_mat
			post.position = Vector3(px, 0.75, rz)
			bridge_root.add_child(post)

			# Diagonal X-Bracing between adjacent posts
			if p_idx < num_bays:
				var next_px = px + bay_w
				var mid_x = (px + next_px) * 0.5
				if in_gap.call(mid_x):
					continue
				var brace_len = sqrt(bay_w * bay_w + 0.70 * 0.70)
				var brace_angle = rad_to_deg(atan2(0.70, bay_w))

				var b1 := MeshInstance3D.new()
				b1.name = "XBrace1_" + rail_side_name + "_%d" % p_idx
				var bm1 := BoxMesh.new()
				bm1.size = Vector3(brace_len, 0.14, 0.14)
				b1.mesh = bm1
				b1.material_override = timber_mat
				b1.position = Vector3(mid_x, 1.15, rz)
				b1.rotation_degrees = Vector3(0, 0, brace_angle)
				bridge_root.add_child(b1)

				var b2 := MeshInstance3D.new()
				b2.name = "XBrace2_" + rail_side_name + "_%d" % p_idx
				var bm2 := BoxMesh.new()
				bm2.size = Vector3(brace_len, 0.14, 0.14)
				b2.mesh = bm2
				b2.material_override = timber_mat
				b2.position = Vector3(mid_x, 1.15, rz)
				b2.rotation_degrees = Vector3(0, 0, -brace_angle)
				bridge_root.add_child(b2)

		# Terminal post at the opening (gap start)
		if gap_here and rail_gap.x > -half_len and rail_gap.x < half_len:
			var near_post := false
			for q_idx in range(num_bays + 1):
				var qx = -half_len + float(q_idx) * bay_w
				if absf(qx - rail_gap.x) < 0.8:
					near_post = true
					break
			if not near_post:
				var end_post := MeshInstance3D.new()
				end_post.name = "Post_" + rail_side_name + "_gap_%d" % int(rail_gap.x)
				var ep_m := BoxMesh.new()
				ep_m.size = Vector3(0.42, 1.60, 0.42)
				end_post.mesh = ep_m
				end_post.material_override = timber_mat
				end_post.position = Vector3(rail_gap.x, 0.75, rz)
				bridge_root.add_child(end_post)
	# 7. Creek Bed Heavy Timber Trestle Bents with Stone Cutwaters
	# Open trestle bents with continuous wooden piles extending into the riverbed,
	# transverse sway X-braces, collar ties, and compact stone footing plinths.
	const DECK_UNDER := -0.31
	var cap_h := 0.60
	var cap_top: float = DECK_UNDER - 0.70
	var cap_y: float = cap_top - cap_h * 0.5
	var pile_top: float = cap_top - cap_h
	var pile_bot: float = -pier_depth + 0.8
	var pile_h: float = pile_top - pile_bot
	var pile_y: float = (pile_top + pile_bot) * 0.5

	# Bent spacing:
	# For short bridges (<=35m like Glade Timber Bridge ~24m), use 1 centered bent at x = 0.
	# For long bridges (>35m like Alpine Timber Bridge 60m), use 2 bents at +/- 13.0m.
	var bent_xs: Array[float] = []
	if length > 35.0:
		bent_xs = [-13.0, 13.0]
	else:
		bent_xs = [0.0]

	var num_piles: int = 5 if width >= 15.0 else 4

	for b_idx in range(bent_xs.size()):
		var x_bent: float = bent_xs[b_idx]
		var bent_root := Node3D.new()
		bent_root.name = "TrestleBent_%d" % b_idx
		bent_root.position = Vector3(x_bent, 0, 0)

		# Transverse Cap Beam under stringers
		var cap_beam := MeshInstance3D.new()
		cap_beam.name = "CapBeam"
		var cbm := BoxMesh.new()
		cbm.size = Vector3(0.65, cap_h, width - 0.4)
		cap_beam.mesh = cbm
		cap_beam.material_override = timber_mat
		cap_beam.position = Vector3(0, cap_y, 0)
		bent_root.add_child(cap_beam)

		# Horizontal Collar Ties (mid-height and lower ties)
		for tie_frac in [0.45, 0.82]:
			var tie_y: float = lerpf(pile_top, pile_bot, tie_frac)
			var tie := MeshInstance3D.new()
			tie.name = "CollarTie_%.0f" % (tie_frac * 100.0)
			var tm := BoxMesh.new()
			tm.size = Vector3(0.30, 0.32, width - 0.8)
			tie.mesh = tm
			tie.material_override = timber_mat
			tie.position = Vector3(0, tie_y, 0)
			bent_root.add_child(tie)

		# Timber Piles & Riverbed Stone Footing Plinths
		var pile_span: float = width - 2.4
		var pile_step: float = pile_span / float(num_piles - 1)
		for p_i in range(num_piles):
			var pile_z: float = -pile_span * 0.5 + float(p_i) * pile_step

			# Timber Pile running down to riverbed
			var pile := MeshInstance3D.new()
			pile.name = "Pile_%d" % p_i
			pile.mesh = _tapered_box_mesh(
				Vector3(0.48, 0.0, 0.48),
				Vector3(0.38, 0.0, 0.38),
				pile_h)
			pile.material_override = timber_mat
			pile.position = Vector3(0, pile_y, pile_z)
			bent_root.add_child(pile)

			# Individual Stone Footing Plinth / Cutwater in riverbed
			var plinth := MeshInstance3D.new()
			plinth.name = "Plinth_%d" % p_i
			plinth.mesh = _tapered_box_mesh(
				Vector3(1.10, 0.0, 1.10),
				Vector3(0.85, 0.0, 0.85),
				1.2)
			plinth.material_override = stone_mat
			plinth.position = Vector3(0, pile_bot - 0.4, pile_z)
			bent_root.add_child(plinth)

		# Transverse Sway Bracing (X-bracing between piles in the bent plane)
		for p_i in range(num_piles - 1):
			var z1: float = -pile_span * 0.5 + float(p_i) * pile_step
			var z2: float = z1 + pile_step
			var z_mid: float = (z1 + z2) * 0.5
			var dz: float = z2 - z1
			var dy: float = pile_h * 0.65
			var brace_len: float = sqrt(dz * dz + dy * dy)
			var brace_ang: float = rad_to_deg(atan2(dy, dz))

			for k in 2:
				var sway := MeshInstance3D.new()
				sway.name = "SwayBrace_%d_%d" % [p_i, k]
				var sm := BoxMesh.new()
				sm.size = Vector3(0.18, 0.18, brace_len)
				sway.mesh = sm
				sway.material_override = timber_mat
				sway.position = Vector3(0.22 if k == 0 else -0.22, pile_y + 0.3, z_mid)
				sway.rotation_degrees = Vector3(brace_ang if k == 0 else -brace_ang, 0, 0)
				bent_root.add_child(sway)

		# Per-pile collision matching the visible piles and their stone plinths. One solid slab
		# across the bent used to sit here: 8.3m tall, nearly the full bridge width, and entirely
		# invisible -- it walled off the channel under the deck. Boxes on the piles themselves keep
		# the carts-out-of-the-timber protection without blocking the waterway.
		var bent_col_body := StaticBody3D.new()
		bent_col_body.name = "BentCollision"
		for p_i in range(num_piles):
			var col_z: float = -pile_span * 0.5 + float(p_i) * pile_step
			var b_col := CollisionShape3D.new()
			b_col.name = "PileCol_%d" % p_i
			var b_shape := BoxShape3D.new()
			b_shape.size = Vector3(0.55, pile_h + 0.6, 0.55)
			b_col.shape = b_shape
			b_col.position = Vector3(0, pile_y, col_z)
			bent_col_body.add_child(b_col)

			var pl_col := CollisionShape3D.new()
			pl_col.name = "PlinthCol_%d" % p_i
			var pl_shape := BoxShape3D.new()
			pl_shape.size = Vector3(1.10, 1.2, 1.10)
			pl_col.shape = pl_shape
			pl_col.position = Vector3(0, pile_bot - 0.4, col_z)
			bent_col_body.add_child(pl_col)
		bent_root.add_child(bent_col_body)

		bridge_root.add_child(bent_root)

	# 8. No longitudinal members between the trestle bents. A girt and an X-brace used to run the
	# full 26m between the Alpine bents at mid-height, straight across the open channel: from the
	# creek they read as two thin wires strung across the water, not as timberwork. The bents are
	# already tied together by the four deck girders and the floor beams above them, and each bent
	# carries its own sway bracing, so the waterway is left open.

	if winter_dressing:
		_dress_bridge_for_winter(bridge_root, length, width, timber_mat, rail_gap)

	parent.add_child(bridge_root)


## Packs a timber truss bridge out with winter detail: snow lying on wheel guards and handrails,
## icicles hanging off the deck edge, and snow coping on the stone abutments.
##
## `rail_gap` mirrors the railing opening, so no snow cap or icicle is left floating
## across a stretch of railing that is not there.
func _dress_bridge_for_winter(bridge_root: Node3D, length: float, width: float, timber_mat: Material,
		rail_gap: Vector2) -> void:
	var snow := _alpine_snow_material(1.10, 1.16, 1.28)

	var curb_h := 0.32
	var curb_w := 0.40
	var rail_z_dist := width * 0.5 - 0.20
	var has_gap: bool = rail_gap.y > rail_gap.x
	var half_len: float = length * 0.5

	# Snow lying along the wheel guards and the handrails: a slab per run, sitting proud of the
	# timber so it reads as accumulation rather than as a differently coloured beam.
	for side in [-1.0, 1.0]:
		var rail_side_name := "N" if side < 0 else "S"
		var runs: Array = [Vector2(-half_len, half_len)]
		if has_gap and side > 0.0:
			runs = [Vector2(-half_len, rail_gap.x), Vector2(rail_gap.y, half_len)]

		for run_i in range(runs.size()):
			var run: Vector2 = runs[run_i]
			if run.y - run.x <= 0.5:
				continue
			var run_mid: float = (run.x + run.y) * 0.5
			var run_len: float = run.y - run.x
			var suffix := "" if runs.size() == 1 else "_%d" % run_i

			var guard_cap := MeshInstance3D.new()
			guard_cap.name = "SnowCap_WheelGuard_" + rail_side_name + suffix
			var gcm := BoxMesh.new()
			gcm.size = Vector3(run_len, 0.14, curb_w + 0.12)
			guard_cap.mesh = gcm
			guard_cap.material_override = snow
			guard_cap.position = Vector3(run_mid, 0.16 + curb_h + 0.05, side * (width * 0.5 - curb_w * 0.5))
			bridge_root.add_child(guard_cap)

			var rail_cap := MeshInstance3D.new()
			rail_cap.name = "SnowCap_TopRail_" + rail_side_name + suffix
			var rcm := BoxMesh.new()
			rcm.size = Vector3(run_len, 0.12, 0.46)
			rail_cap.mesh = rcm
			rail_cap.material_override = snow
			rail_cap.position = Vector3(run_mid, 1.45 + 0.14 + 0.05, side * rail_z_dist)
			bridge_root.add_child(rail_cap)

	_add_bridge_icicles(bridge_root, length, width, rail_gap)

	# Deliberately no snow drift banked against the abutments. The deck here is the full carriageway
	# width and the bridge ends in mid-air over the creek, so a drift either sat across the driving
	# line as a kerb to climb at both ends, or outboard of it with no deck underneath to sit on --
	# which is where the pale floating slabs at the bridge ends came from. The winter read comes
	# from the snow lying on the wheel guards and handrails, plus the coping on the abutments.
	#
	# Snow on the outboard stone abutment copings.
	for side in [-1.0, 1.0]:
		for wing_side in [-1.0, 1.0]:
			var coping := MeshInstance3D.new()
			coping.name = "SnowCap_Abutment_" + ("E" if side > 0 else "W") + ("_N" if wing_side < 0 else "_S")
			var cm := BoxMesh.new()
			cm.size = Vector3(2.6, 0.14, 0.70)
			coping.mesh = cm
			coping.material_override = snow
			coping.position = Vector3(side * (length * 0.5 - 1.2), 0.05, wing_side * (width * 0.5 + 0.15))
			bridge_root.add_child(coping)


## A box tapered from `bottom` to `top` (X/Z sizes) over `height`, centred on the origin in X/Z and
## spanning y = -height/2 .. +height/2.
##
## Everything structural on these bridges used to be an axis-aligned BoxMesh, and a pier, an
## abutment, a wing wall and a pile all read as the same hard rectangle. A batter -- wider at the
## base -- is what makes masonry and hewn timber look like masonry and hewn timber, and it costs
## eight vertices.
##
## Face winding is corrected against the face normal rather than reasoned out per side, so no face
## ends up inside-out and lit from the wrong direction.
func _tapered_box_mesh(bottom: Vector3, top: Vector3, height: float) -> ArrayMesh:
	var hy: float = height * 0.5
	var bx: float = bottom.x * 0.5
	var bz: float = bottom.z * 0.5
	var tx: float = top.x * 0.5
	var tz: float = top.z * 0.5
	var b: Array = [
		Vector3(-bx, -hy, -bz), Vector3(bx, -hy, -bz),
		Vector3(bx, -hy, bz), Vector3(-bx, -hy, bz),
	]
	var t: Array = [
		Vector3(-tx, hy, -tz), Vector3(tx, hy, -tz),
		Vector3(tx, hy, tz), Vector3(-tx, hy, tz),
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Flat shading. With SurfaceTool's default smooth group every corner vertex averaged the normals
	# of the three faces meeting there, so each face was lit as if it were a rounded pillow and the
	# triplanar stone/wood projection smeared into the brown streaks seen on the abutments and piles.
	st.set_smooth_group(-1)
	for i in range(4):
		var j: int = (i + 1) % 4
		_add_outward_quad(st, b[i], b[j], t[j], t[i])
	_add_outward_quad(st, t[0], t[1], t[2], t[3])
	_add_outward_quad(st, b[0], b[1], b[2], b[3])
	st.generate_normals()
	return st.commit()


## Emits the two triangles of a planar quad, flipping the winding if it faces inward.
## Godot's front faces wind clockwise, so the face normal is (c - a) x (b - a) -- the same as
## Plane(a, b, c) and generate_normals(). The right-handed (b - a) x (c - a) points the other way and
## turned every abutment, wing wall and pile inside-out: near faces culled, far faces seen from inside.
func _add_outward_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	var centre: Vector3 = (a + b + c + d) * 0.25
	if n.dot(centre) < 0.0:
		st.add_vertex(a); st.add_vertex(d); st.add_vertex(c)
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
	else:
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
		st.add_vertex(a); st.add_vertex(c); st.add_vertex(d)


## Hangs icicles along both deck edges as one MultiMesh per bridge.
##
## The old pass placed one icicle every 1.8m at a cycling length, built from _tapered_box_mesh with
## the wide end at the *bottom* -- so each one was an upside-down square spike standing on its point,
## and the even spacing read as a row of teeth. Real icicles hang point-down, round, in irregular
## clusters with long ones among many short ones and bare stretches in between.
##
## One MultiMeshInstance3D instead of one MeshInstance3D per icicle: ~150 icicles on the Alpine
## bridge become a single draw call. The layout is seeded from the bridge name, so regenerating the
## level gives the same icicles every time.
func _add_bridge_icicles(bridge_root: Node3D, length: float, width: float, rail_gap: Vector2) -> void:
	const DECK_UNDERSIDE := -0.29  # deck slab bottom is -0.31; the base sinks 2cm into the timber
	var half_len: float = length * 0.5
	var has_gap: bool = rail_gap.y > rail_gap.x

	# Floor beams cross under the deck at every railing post and stick 0.3m out past the deck edge.
	# Keep icicles off them so none spear through a beam.
	var num_bays: int = maxi(int(round(length / 3.75)), 2)
	var bay_w: float = length / float(num_bays)
	var post_xs: Array[float] = []
	for p_idx in range(num_bays + 1):
		post_xs.append(-half_len + float(p_idx) * bay_w)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(bridge_root.name))

	var xforms: Array[Transform3D] = []
	var tints: Array[Color] = []
	for side in [-1.0, 1.0]:
		var phase_a: float = rng.randf() * TAU
		var phase_b: float = rng.randf() * TAU
		var x: float = -half_len + 0.5 + rng.randf() * 0.4
		while x < half_len - 0.5:
			var here: float = x
			x += rng.randf_range(0.18, 0.75)
			if has_gap and side > 0.0 and here > rail_gap.x and here < rail_gap.y:
				continue
			var on_beam := false
			for px in post_xs:
				if absf(here - px) < 0.32:
					on_beam = true
					break
			if on_beam:
				continue
			# Slow envelope along the span: heavy dripping patches, sparse ones and bare runs.
			var env: float = 0.5 + 0.5 * sin(here * 0.42 + phase_a) * sin(here * 0.13 + phase_b)
			if rng.randf() > 0.25 + env * 0.85:
				continue
			# Mostly short, a few long: a power curve, scaled by the envelope.
			var drop: float = 0.10 + (0.25 + 1.05 * env) * pow(rng.randf(), 2.2)
			var radius: float = clampf(0.018 + drop * 0.075, 0.022, 0.085)
			var lean := Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
			var basis := Basis.from_euler(Vector3(lean.x, rng.randf() * TAU, lean.z))
			basis = basis * Basis.from_scale(Vector3(radius, drop, radius))
			var z: float = side * (width * 0.5 - 0.06 - rng.randf() * 0.14)
			xforms.append(Transform3D(basis, Vector3(here, DECK_UNDERSIDE, z)))
			# Slight per-icicle variation: some milky, some clearer and bluer.
			var milk: float = rng.randf()
			tints.append(Color(lerpf(0.86, 1.0, milk), lerpf(0.93, 1.0, milk), 1.0))

	if xforms.is_empty():
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _icicle_unit_mesh()
	mm.instance_count = xforms.size()
	# Write the raw buffer rather than set_instance_transform/color: the generator runs headless, and
	# the dummy renderer drops per-instance setters, so the saved MultiMesh had no transforms at all.
	# Layout per instance: 3x4 row-major transform (basis rows + origin), then RGBA.
	var buf := PackedFloat32Array()
	buf.resize(xforms.size() * 16)
	for i in range(xforms.size()):
		var t: Transform3D = xforms[i]
		var c: Color = tints[i]
		var o := i * 16
		for r in range(3):
			buf[o + r * 4 + 0] = t.basis.x[r]
			buf[o + r * 4 + 1] = t.basis.y[r]
			buf[o + r * 4 + 2] = t.basis.z[r]
			buf[o + r * 4 + 3] = t.origin[r]
		buf[o + 12] = c.r
		buf[o + 13] = c.g
		buf[o + 14] = c.b
		buf[o + 15] = c.a
	mm.buffer = buf

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Icicles"
	mmi.multimesh = mm
	mmi.material_override = _ice_material()
	# Thin slivers: their shadows are a few pixels of noise and cost a full shadow pass.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bridge_root.add_child(mmi)


## A single icicle of unit radius and unit length: base ring at y = 0, point at y = -1.
## Round (8 sides), with a slight bulge-and-pinch profile so it reads as dripped ice rather than
## a machined cone. Vertex colour runs from frosty white at the root to clear blue at the tip.
func _icicle_unit_mesh() -> ArrayMesh:
	const SIDES := 8
	const RINGS := 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root_col := Color(0.94, 0.97, 1.0)
	var tip_col := Color(0.40, 0.60, 0.86)

	var rings: Array = []
	for r in range(RINGS):
		var t: float = float(r) / float(RINGS)
		var radius: float = pow(1.0 - t, 1.5) * (1.0 + 0.10 * sin(t * 15.0))
		if t < 0.12:
			radius *= 1.0 + (0.12 - t) * 2.5  # small flare where it freezes onto the edge
		var ring: Array = []
		for s in range(SIDES):
			var a: float = TAU * float(s) / float(SIDES)
			ring.append(Vector3(cos(a) * radius, -t, sin(a) * radius))
		rings.append([ring, root_col.lerp(tip_col, t)])
	var tip := Vector3(0.0, -1.0, 0.0)

	for r in range(RINGS - 1):
		var ra: Array = rings[r][0]
		var rb: Array = rings[r + 1][0]
		var ca: Color = rings[r][1]
		var cb: Color = rings[r + 1][1]
		for s in range(SIDES):
			var n: int = (s + 1) % SIDES
			st.set_color(ca); st.add_vertex(ra[s])
			st.set_color(ca); st.add_vertex(ra[n])
			st.set_color(cb); st.add_vertex(rb[n])
			st.set_color(ca); st.add_vertex(ra[s])
			st.set_color(cb); st.add_vertex(rb[n])
			st.set_color(cb); st.add_vertex(rb[s])
	var last: Array = rings[RINGS - 1][0]
	var lc: Color = rings[RINGS - 1][1]
	for s in range(SIDES):
		var n: int = (s + 1) % SIDES
		st.set_color(lc); st.add_vertex(last[s])
		st.set_color(lc); st.add_vertex(last[n])
		st.set_color(tip_col); st.add_vertex(tip)

	st.index()
	st.generate_normals()
	var mesh := st.commit()
	# Winding is checked rather than assumed: if the side faces came out facing inward, flip them.
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var outward := 0.0
	for i in range(verts.size()):
		outward += normals[i].dot(Vector3(verts[i].x, 0.0, verts[i].z))
	if outward < 0.0:
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, idx.size(), 3):
			var tmp := idx[i + 1]
			idx[i + 1] = idx[i + 2]
			idx[i + 2] = tmp
		arrays[Mesh.ARRAY_INDEX] = idx
		for i in range(normals.size()):
			normals[i] = -normals[i]
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh = ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Icicle material: opaque, glossy, cold-tinted ice. The old one was alpha-blended with backface
## culling off, which made every icicle sort against the snow and sky behind it and flicker between
## white and invisible; at this size the transparency was never visible anyway. Rim light, clearcoat
## and backlight give the glassy edge and the glow when the sun is behind the bridge instead.
func _ice_material() -> Material:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	# Kept well below snow white: next to the snow caps the ice has to read as cold and glassy,
	# and on slivers this thin a strong rim or clearcoat lights nearly every pixel at a grazing
	# angle and clips the whole icicle to a flat white silhouette.
	m.albedo_color = Color(0.56, 0.73, 0.89)
	m.roughness = 0.12
	m.metallic_specular = 0.6
	m.rim_enabled = true
	m.rim = 0.2
	m.rim_tint = 0.6
	# Glows cold blue when the sun is behind the bridge (Forward+).
	m.backlight_enabled = true
	m.backlight = Color(0.30, 0.50, 0.70)
	# Under a deck the icicles sit in shadow; a faint cold self-glow keeps them from going grey.
	m.emission_enabled = true
	m.emission = Color(0.20, 0.34, 0.50)
	m.emission_energy_multiplier = 0.15
	return m


## Winter snow material for the bridges. `snow_bias` above 1 holds snow further up a slope than
## the shader default, which is what an accumulated drift on a manmade structure does.
func _alpine_snow_material(snow_bias: float = 1.0, tint_r: float = 0.92, tint_g: float = 0.95, tint_b: float = 1.06) -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://alpine_snow.gdshader")
	if mat.shader == null:
		# Fall back to plain PBR snow rather than dropping the geometry entirely.
		var plain := StandardMaterial3D.new()
		plain.albedo_color = Color(0.97, 0.98, 1.0)
		plain.roughness = 0.88
		return plain
	var rock: Texture2D = load("res://materials/dark_rock.png") as Texture2D
	var rock_n: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D
	if rock:
		mat.set_shader_parameter("rock_albedo", rock)
	if rock_n:
		mat.set_shader_parameter("rock_normal", rock_n)
	mat.set_shader_parameter("rock_tint", Color(0.95, 0.98, 1.10))
	mat.set_shader_parameter("snow_color", Color(0.90, 0.94, 1.02) * Color(tint_r, tint_g, tint_b))
	# A lower snow slope threshold keeps snow on the near-vertical faces of drifts and icicles
	# instead of only on the flat tops.
	mat.set_shader_parameter("snow_slope", 0.66 - 0.30 * clampf(snow_bias, 0.0, 1.0))
	mat.set_shader_parameter("snow_line", 400.0)
	mat.set_shader_parameter("normal_strength", 0.35)
	return mat


## High quality alpine asphalt material for the main circuit and shortcut routes.
## Replaces the high-frequency cobblestone pattern with clean mountain asphalt,
## eliminating moiré aliasing while preserving natural road roughness and grip.
func _alpine_road_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var albedo: Texture2D = load("res://materials/asphalt.png") as Texture2D
	var normal_tex: Texture2D = load("res://materials/concrete_normal.png") as Texture2D
	if albedo:
		m.albedo_texture = albedo
		m.albedo_color = Color(0.88, 0.90, 0.93)
	if normal_tex:
		m.normal_enabled = true
		m.normal_texture = normal_tex
		m.normal_scale = 0.45
	m.roughness = 0.80
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.uv1_scale = Vector3(0.18, 0.18, 0.18)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _cobblestone_material() -> StandardMaterial3D:
	return _alpine_road_material()


## Builds the shortcut road deck, its curbs, its rock embankment and collision.
##
## `half_width` is the FULL road half width.
## The deck smoothly blends to the trunk road edge only within the junction zones
## (first 14m and last 14m). Outside of junctions, it is strictly symmetrical with
## constant half_width to prevent cross-section inversion or inverted geometry.
##
## `skip_span` is a (start, end) range of metres along the curve to leave empty, used where a
## bridge takes over the crossing: the deck and embankment stop at the abutments so they
## never run through the middle of the bridge or wall off the ravine below it.
func _build_cobblestone_road(parent: Node, curve: Curve3D, rings: Array, half_width: float,
		node_name: String, skip_span: Vector2 = Vector2.ZERO) -> void:
	if rings.size() < 2:
		return

	var total_len: float = curve.get_baked_length()
	var curb_w: float = 0.5
	var max_curb_h: float = 0.22
	var deck_crown: float = 0.08
	var max_wall_drop: float = 3.2
	var gap: bool = skip_span.y > skip_span.x
	# The embankment is extended to the cached terrain height below, so it does not float
	# above the creek bed when the shortcut is far above natural ground.

	var road_mat := _alpine_road_material()

	# 2. Retaining Wall / Embankment Material (Alpine dark canyon rock)
	var wall_mat := StandardMaterial3D.new()
	var rock_tex: Texture2D = load("res://materials/dark_canyon_rock.png") as Texture2D
	var rock_norm: Texture2D = load("res://materials/dark_canyon_rock_normal.png") as Texture2D
	if rock_tex:
		wall_mat.albedo_texture = rock_tex
	if rock_norm:
		wall_mat.normal_enabled = true
		wall_mat.normal_texture = rock_norm
		wall_mat.normal_scale = 0.85
	wall_mat.roughness = 0.90
	wall_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	wall_mat.uv1_triplanar = true
	wall_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var st_deck := SurfaceTool.new()
	st_deck.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_wall := SurfaceTool.new()
	st_wall.begin(Mesh.PRIMITIVE_TRIANGLES)

	## Vertices emitted per cross-section ring.
	const DECK_VERTS := 7
	const WALL_VERTS := 4
	var wall_verts := 0
	## World positions of each wall ring (outer base, outer top, inner top, inner base), kept so the
	## cut ends at a bridge gap can be closed off afterwards.
	var wall_ring_pos: Array[PackedVector3Array] = []
	## The deck cross-section of each ring, so an end wall can be cut to the road's actual profile.
	var deck_ring_pos: Array = []
	var terrain_node: Node3D = parent.get_node_or_null("TerrainGenerator")
	var has_cache: bool = terrain_node != null and terrain_node.has_method("_sample_cached_height") \
		and (terrain_node.get("_visual_heights") as PackedFloat32Array).size() > 0

	for ring in rings:
		var p: Vector3 = ring["p"]
		var right: Vector3 = ring["right"]
		var outer: float = ring["outer"]
		var inner: float = ring["inner"]
		var cum_dist: float = ring["cum"]

		# Taper curbs and embankment smoothly at junctions with main track
		var junc_dist: float = minf(cum_dist, total_len - cum_dist)
		var junc_taper: float = clampf(junc_dist / 10.0, 0.0, 1.0)
		var outer_curb_h: float = max_curb_h * (junc_taper * junc_taper)
		# Inner edge meets main track carriageway: suppress curb completely near junctions so road merges flush
		var inner_curb_h: float = max_curb_h * clampf((junc_dist - 10.0) / 6.0, 0.0, 1.0)

		# Within 6m of a bridge abutment the crown flattens out and the embankment loses its batter,
		# so the road arrives at the flat timber deck level and the walls meet the stone flush.
		var bridge_taper: float = 1.0
		if gap:
			if cum_dist <= skip_span.x:
				bridge_taper = clampf((skip_span.x - cum_dist) / 6.0, 0.0, 1.0)
			elif cum_dist >= skip_span.y:
				bridge_taper = clampf((cum_dist - skip_span.y) / 6.0, 0.0, 1.0)
		var total_wall_taper: float = minf(junc_taper * junc_taper, bridge_taper)
		var crown: float = deck_crown * junc_taper * bridge_taper
		# The curbs fade out into the bridge too: the deck has its own wheel guards further out, and a
		# 27cm curb ending square at the deck joint is a block in the lane for anyone leaving the bridge.
		outer_curb_h *= bridge_taper
		inner_curb_h *= bridge_taper

		var outer_gut: float = outer - curb_w
		var inner_gut: float = inner + curb_w
		# Where the deck overlaps the trunk it has to *be* the trunk deck, not float a few centimetres
		# off it, and a curb standing on the trunk's asphalt is a kerb in the middle of a lane.
		outer_curb_h *= _trunk_curb_factor(p + right * outer)
		inner_curb_h *= _trunk_curb_factor(p + right * inner)
		var deck_lats: Array = [outer, outer_gut, outer_gut, 0.0, inner_gut, inner_gut, inner]
		var deck_lift: Array = [outer_curb_h, outer_curb_h, 0.0, crown, 0.0, inner_curb_h, inner_curb_h]
		var deck_uvx: Array = [0.0, 0.3, 0.4, 2.5, 4.6, 4.7, 5.0]
		var deck_pts: Array[Vector3] = []
		for k in range(DECK_VERTS):
			var at: Vector3 = p + right * float(deck_lats[k])
			at.y = _deck_height_at(at, p.y + SHORTCUT_DECK_Y + float(deck_lift[k]))
			deck_pts.append(at)

		# Ground is sampled under each wall's own base, not under the centreline. On the creek banks
		# the ground falls away across the road, so a drop measured at the centre left the downhill
		# wall ending in mid-air as a hanging curtain beside the bridge.
		var outer_base_xz: Vector3 = p + right * (outer + 0.35 * total_wall_taper)
		var inner_base_xz: Vector3 = p + right * (inner - 0.35 * total_wall_taper)
		var outer_ground: float = deck_pts[0].y - max_wall_drop
		var inner_ground: float = deck_pts[6].y - max_wall_drop
		if has_cache:
			var centre_h: float = terrain_node._sample_cached_height(p.x, p.z)
			outer_ground = minf(outer_ground, minf(centre_h,
				terrain_node._sample_cached_height(outer_base_xz.x, outer_base_xz.z)) - 0.5)
			inner_ground = minf(inner_ground, minf(centre_h,
				terrain_node._sample_cached_height(inner_base_xz.x, inner_base_xz.z)) - 0.5)

		var uv_y: float = cum_dist * 0.40
		for k in range(DECK_VERTS):
			st_deck.set_uv(Vector2(deck_uvx[k], uv_y))
			st_deck.add_vertex(deck_pts[k])

		# --- WALL MESH VERTICES (4 points: outer base/top, inner top/base) ---
		var wall_uv_y: float = cum_dist * 0.25
		var ring_pos := PackedVector3Array([
			Vector3(outer_base_xz.x, outer_ground, outer_base_xz.z),
			deck_pts[0],
			deck_pts[6],
			Vector3(inner_base_xz.x, inner_ground, inner_base_xz.z),
		])
		var wall_uvx: Array = [0.0, 1.0, 1.0, 0.0]
		for k in range(WALL_VERTS):
			st_wall.set_uv(Vector2(wall_uvx[k], wall_uv_y))
			st_wall.add_vertex(ring_pos[k])
		wall_ring_pos.append(ring_pos)
		deck_ring_pos.append(deck_pts)
		wall_verts += WALL_VERTS

	for i in range(rings.size() - 1):
		if rings[i]["gap_after"]:
			# End walls where the road stops at the bridge gap. The embankment is just two side walls
			# and a deck surface, so without these its cut end was an open, hollow shell: from the
			# creek you looked straight into it, the deck's underside was back-face culled and
			# invisible, and the inside of the walls showed as a dark wedge below the abutment.
			#
			# The top edge follows the deck's own cross-section vertex for vertex. A single quad from
			# curb top to curb top stood 22cm proud of the road across its whole width -- in the
			# collision mesh as well, so every car leaving or joining the bridge hit it.
			for end_ring in [i, i + 1]:
				var q: PackedVector3Array = wall_ring_pos[end_ring]
				var top: Array = deck_ring_pos[end_ring]
				var n: int = top.size()
				for k in range(n - 1):
					var t0: float = float(k) / float(n - 1)
					var t1: float = float(k + 1) / float(n - 1)
					var e0: int = wall_verts
					var quad := [q[0].lerp(q[3], t0), top[k], top[k + 1], q[0].lerp(q[3], t1)]
					for vi in range(4):
						st_wall.set_uv(Vector2(lerpf(t0, t1, 0.0 if vi < 2 else 1.0), 0.0 if (vi == 0 or vi == 3) else 1.0))
						st_wall.add_vertex(quad[vi])
					wall_verts += 4
					st_wall.add_index(e0 + 0); st_wall.add_index(e0 + 1); st_wall.add_index(e0 + 2)
					st_wall.add_index(e0 + 0); st_wall.add_index(e0 + 2); st_wall.add_index(e0 + 3)
			continue

		var r0: int = i * DECK_VERTS
		var r1: int = (i + 1) * DECK_VERTS
		for c in range(DECK_VERTS - 1):
			var a = r0 + c
			var b = r0 + c + 1
			var c_idx = r1 + c
			var d = r1 + c + 1
			st_deck.add_index(a); st_deck.add_index(c_idx); st_deck.add_index(b)
			st_deck.add_index(b); st_deck.add_index(c_idx); st_deck.add_index(d)

		var w0: int = i * WALL_VERTS
		var w1: int = (i + 1) * WALL_VERTS
		# Outer / Right Wall
		var rb0 = w0 + 0; var rt0 = w0 + 1
		var rb1 = w1 + 0; var rt1 = w1 + 1
		st_wall.add_index(rb0); st_wall.add_index(rt0); st_wall.add_index(rb1)
		st_wall.add_index(rt0); st_wall.add_index(rt1); st_wall.add_index(rb1)
		# Inner / Left Wall
		var rt_in0 = w0 + 2; var rb_in0 = w0 + 3
		var rt_in1 = w1 + 2; var rb_in1 = w1 + 3
		st_wall.add_index(rt_in0); st_wall.add_index(rb_in0); st_wall.add_index(rt_in1)
		st_wall.add_index(rb_in0); st_wall.add_index(rb_in1); st_wall.add_index(rt_in1)

	st_deck.generate_normals()
	st_deck.generate_tangents()
	var deck_mesh: ArrayMesh = st_deck.commit()

	st_wall.generate_normals()
	st_wall.generate_tangents()
	var wall_mesh: ArrayMesh = st_wall.commit()

	var static_body := StaticBody3D.new()
	static_body.name = node_name + "_Collision"
	static_body.add_to_group("track_surface", true)

	var deck_inst := MeshInstance3D.new()
	deck_inst.name = node_name + "_Deck"
	deck_inst.mesh = deck_mesh
	deck_inst.material_override = road_mat
	static_body.add_child(deck_inst)

	var wall_inst := MeshInstance3D.new()
	wall_inst.name = node_name + "_Embankment"
	wall_inst.mesh = wall_mesh
	wall_inst.material_override = wall_mat
	static_body.add_child(wall_inst)

	var col_shape := CollisionShape3D.new()
	col_shape.name = "CollisionShape3D"
	var r_trimesh = deck_mesh.create_trimesh_shape()
	if r_trimesh is ConcavePolygonShape3D:
		(r_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_shape.shape = r_trimesh
	static_body.add_child(col_shape)

	var col_wall_shape := CollisionShape3D.new()
	col_wall_shape.name = "CollisionShape3D_Embankment"
	var r_wall_trimesh = wall_mesh.create_trimesh_shape()
	if r_wall_trimesh is ConcavePolygonShape3D:
		(r_wall_trimesh as ConcavePolygonShape3D).backface_collision = true
	col_wall_shape.shape = r_wall_trimesh
	static_body.add_child(col_wall_shape)

	parent.add_child(static_body)


## Cross-section rings for a shortcut deck: one every RING_STEP metres of arc length, plus one exactly
## on each end of `skip_span` so the deck stops precisely at the bridge abutments instead of up to a
## ring spacing short of them (which left the abutment top showing in the gap).
##
## Rings are placed by arc length, not on the raw baked points: the baked list repeats a point at
## every control point, and the old forward vector taken between two identical points came out as
## zero, collapsing that ring to a single point -- a hole through the deck at every waypoint. The
## direction here is taken across +-0.5m of curve instead.
##
## Each ring is {p, right, outer, inner, cum, gap_after}. `outer` / `inner` are the signed lateral
## positions of the deck edges: symmetric +-half_width except in the junction gores, where the deck is
## pinched onto the trunk deck edge (see _ramp_deck_extents).
func _shortcut_rings(curve: Curve3D, half_width: float, skip_span: Vector2) -> Array:
	const RING_STEP := 0.25
	var total_len: float = curve.get_baked_length()
	var gap: bool = skip_span.y > skip_span.x
	var offs: Array[float] = []
	var d := 0.0
	while d < total_len - 0.05:
		if not (gap and d > skip_span.x - 0.05 and d < skip_span.y + 0.05):
			offs.append(d)
		d += RING_STEP
	offs.append(total_len)
	if gap:
		offs.append(skip_span.x)
		offs.append(skip_span.y)
	offs.sort()

	var rings: Array = []
	for off in offs:
		var p: Vector3 = curve.sample_baked(off)
		var t: Vector3 = curve.sample_baked(minf(off + 0.5, total_len)) - curve.sample_baked(maxf(off - 0.5, 0.0))
		t.y = 0.0
		var fwd: Vector3 = t.normalized() if t.length() > 1e-4 else Vector3.FORWARD
		var right := Vector3(-fwd.z, 0.0, fwd.x).normalized()

		# Junction gore apron is strictly confined to the first 14m and last 14m of the shortcut curve.
		# Outside the junction zone, the shortcut is a clean, symmetric road of width 2 * half_width.
		var outer: float = half_width
		var inner: float = -half_width
		var to_end: float = minf(off, total_len - off)
		if to_end < 14.0:
			var trunk_frame := _frame_at(main_track_curve, p)
			var lat: float = trunk_frame["lat"]
			var dd: float = absf(lat)
			var ext: Vector2 = _ramp_deck_extents(lat, half_width)
			# The nose apron grows out of the trunk's curb edge over its first 8m instead of starting
			# at full width: at full width its square end stuck 2m past the trunk edge as a flap
			# hanging over the snow.
			ext.y = maxf(lerpf(MAIN_CURB_HALF_W, ext.y, smoothstep(0.0, 8.0, to_end)), ext.x + 1.0)
			var sgn: float = signf(lat)
			if is_zero_approx(sgn):
				sgn = 1.0
			var blend: float = clampf(to_end / 14.0, 0.0, 1.0)
			if sgn > 0.0:
				outer = lerpf(ext.y - dd, half_width, blend)
				inner = lerpf(ext.x - dd, -half_width, blend)
			else:
				outer = lerpf(-(ext.x - dd), half_width, blend)
				inner = lerpf(-(ext.y - dd), -half_width, blend)
		if outer < inner:
			var tmp := outer
			outer = inner
			inner = tmp
		rings.append({"p": p, "right": right, "outer": outer, "inner": inner, "cum": off,
			"gap_after": gap and is_equal_approx(off, skip_span.x)})
	return rings


## Height of a shortcut deck vertex at world position `at` whose own height would be `own_y`.
##
## Over the trunk's collision deck it is the trunk deck, exactly; for 5m beyond the trunk's edge it
## eases from there to its own height. That is what makes the junctions seamless: the shortcut curve
## only matches the trunk at the nose, and everywhere else in the gore the two surfaces used to sit at
## whatever heights their own curves gave -- up to 23cm apart -- with a step wherever they met.
## Surfaces more than 2.5m apart vertically are not the same junction and are left alone.
func _deck_height_at(at: Vector3, own_y: float) -> float:
	var tp: Vector3 = main_track_curve.get_closest_point(Vector3(at.x, own_y, at.z))
	var trunk_y: float = tp.y + TRUNK_DECK_Y
	if absf(own_y - trunk_y) > 2.5:
		return own_y
	var lat: float = Vector2(at.x - tp.x, at.z - tp.z).length()
	var w: float = smoothstep(MAIN_COL_HALF_W, MAIN_COL_HALF_W + 5.0, lat)
	return lerpf(trunk_y, own_y, w)


## 0 where a curb at `at` would stand on the trunk deck, easing to 1 over the 3m beyond its edge.
func _trunk_curb_factor(at: Vector3) -> float:
	var tp: Vector3 = main_track_curve.get_closest_point(at)
	if absf(at.y - tp.y) > 2.5:
		return 1.0
	var lat: float = Vector2(at.x - tp.x, at.z - tp.z).length()
	return smoothstep(MAIN_COL_HALF_W, MAIN_COL_HALF_W + 3.0, lat)


## Trunk curb openings for one shortcut, as Vector3(start, end, side) offsets along the trunk.
##
## The trunk curb on `side` is dropped wherever any part of the curb strip lies under this shortcut's
## deck. Reading it off the deck footprint replaces hand-measured offset ranges that went stale every
## time a junction moved, leaving a curb running across the shortcut entrance or a gap in the curb
## with no road behind it.
func _junction_openings(rings: Array, side: float) -> Array:
	var quads: Array = []
	for i in range(rings.size() - 1):
		if rings[i]["gap_after"]:
			continue
		var a: Dictionary = rings[i]
		var b: Dictionary = rings[i + 1]
		var poly := PackedVector2Array()
		for q in [a["p"] + a["right"] * a["outer"], b["p"] + b["right"] * b["outer"],
				b["p"] + b["right"] * b["inner"], a["p"] + a["right"] * a["inner"]]:
			poly.append(Vector2(q.x, q.z))
		quads.append(poly)

	var trunk_len: float = main_track_curve.get_baked_length()
	var hit_offs: Array[float] = []
	var d := 0.0
	while d < trunk_len:
		var f: Dictionary = _frame_at_offset(main_track_curve, d)
		var covered := false
		for lat in [MAIN_ROAD_HALF_W + 0.1, (MAIN_ROAD_HALF_W + MAIN_CURB_HALF_W) * 0.5, MAIN_CURB_HALF_W - 0.1]:
			var q: Vector3 = f["pos"] + f["right"] * side * float(lat)
			var q2 := Vector2(q.x, q.z)
			for poly in quads:
				if Geometry2D.is_point_in_polygon(q2, poly):
					covered = true
					break
			if covered:
				break
		if covered:
			hit_offs.append(d)
		d += 0.25

	# Runs closer than 3m are one opening (a 1-2m stub of curb between two runs is just debris), and a
	# run shorter than 2m is a sliver where a deck corner grazes the curb strip, not a junction.
	var out: Array = []
	var run_start := -1.0
	var run_end := -1.0
	for o in hit_offs:
		if run_start < 0.0:
			run_start = o
		elif o - run_end > 3.0:
			if run_end - run_start >= 2.0:
				out.append(Vector3(run_start - 0.4, run_end + 0.4, side))
			run_start = o
		run_end = o
	if run_start >= 0.0 and run_end - run_start >= 2.0:
		out.append(Vector3(run_start - 0.4, run_end + 0.4, side))
	return out


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	if node != scene_root:
		node.owner = scene_root
	for child in node.get_children():
		if child.owner != null and child.owner != scene_root:
			continue
		_set_owner_recursive(child, scene_root)
