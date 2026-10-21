# RC Vibe GP (Godot 4.8, GDScript)

## Godot executable

Portable install, not on PATH:

- `D:\Godot\Godot_v4.8-beta1_win64_console.exe` (or latest in `D:\Godot`): use this one from the shell, because it prints to stdout/stderr
- `D:\Godot\Godot_v4.8-beta1_win64.exe`: GUI editor
- On macOS: `/Applications/Godot.app/Contents/MacOS/Godot` (prints to stdout as well)

## Scratch folder is committed and never deleted

The `scratch/` folder contains permanent test, verification, look-dev, and audit scripts for the project.
- **Do NOT exclude `scratch/` from git** (never add it to `.gitignore`).
- **Do NOT delete or clean up files in `scratch/`**. Any new test scripts or probes created there are preserved so they can be re-run whenever needed.

## Levels are generated, not hand-edited

Each level in `levels/*Level.tscn` (plus its meshes in `generated/*.res`) is written by a generator script
in the project root: `regenerate_<level>.gd`, run through the matching `regenerate_<level>.tscn`.
Don't edit the generated `.tscn`/`.res` files by hand, because the next regeneration overwrites them.
Change the generator and regenerate instead.

Regenerate headless from the project root (the scene saves the level and quits by itself):

```sh
"/d/Godot/Godot_v4.8-dev6_win64_console.exe" --headless --path . res://regenerate_frostpeak_creek.tscn
```

Afterwards, check the output for `ERROR:` lines from the generator. Generators like Frostpeak Creek run
self-checks (`_verify_ramp_junction`, `_verify_bridge_alignment`) that `push_error` on bad geometry but
still save the level. You can ignore these at exit: "Node not found: Players/PlayerSpawner" (`Level.gd` runs
outside a game), "Leaked instance dependency", and RID/ObjectDB leak messages.

`LakesideLevel.tscn` and `MountainLevel.tscn` can each be written by several generators (`regenerate_both`,
`regenerate_custom_path`, `regenerate_desert`, ...). Don't regenerate them unless you know which one made the
current file. `LakesideLevel.tscn` (the Lakeside Course) is dressed by `regenerate_lakeside.gd`: run that after any of
the others re-bakes it (see Lakeside Course below).

## Lakeside Course (Bloombay GP, stage 1)

- `regenerate_lakeside.gd` dresses `levels/LakesideLevel.tscn` as an RC race meeting and replaces everything under
  `LakesideDressing` on every run: the paddock, race control, the camera and lap towers, catch fences, crowd
  barriers, tyre walls, hay, cones, the grandstand across the first corner, the campsite on the hill, the
  orange kicker, the woods and the boulders. The terrain, road and grass stay TerrainGenerator's.
- It grades flat pads (`TerrainGenerator.flat_pads`: paddock, grandstand footing, campsite terraces) and mows
  the venue's verges (`grass_clearings`, no tall grass there). Both are applied after the road blend, so keep
  them off the road. The world is re-baked only when they change (or with `-- rebake`): about 13 minutes,
  nearly all of it the 4M grass blades. A run without a bake takes about 30s. Pad heights come from the
  natural ground (pads cleared first), so they are the same on every run. The grass chunks are written
  through `MultiMesh.buffer` and seeded, so a headless bake keeps them and a re-bake reproduces them.
- People-sized things are built at life size in `PropKit.gd` (one SurfaceTool per material key, everything
  through a frame that places, scales and even shears a prop) and scaled by `PROP_SCALE` (1.6), like
  Bloombay's seafront. `_verify_clear` errors on any footprint too close to the road.
- The camp's motorhomes, caravans, van, SUV, tents, gazebo, chairs, barbecue and cool box (and the crowd
  barrier and cone) are `CampKit.gd`, shared with Bloombay Dunes' inland camps: see "Camps" below.
- The venue sits in road coordinates (s along the TrackPath, lateral right of travel +). The first corner
  (s = 0, the origin) is a single sharp point; `_offset_run` wraps fences and tyre walls round its outside.
  Its inside is tight: anything there stands along the bisector, clear of both legs.
- The kicker after the long bridge (`KICKER_*`) replaced the old `Ramps/NewRamp` curl: a transition into a
  25 degree lip 9.2m up, cut square. The deck is its own body `KickerJump` (driven on as road), the sides and
  back `KickerFrame`. Boost pads 5 to 7 are re-seated on the deck. The TrackPath's `jump_lips` meta records
  the lip: `res://scratch/nyota_jump_test.tscn -- level=res://levels/LakesideLevel.tscn speeds=30,40,50,60` (carts
  land 63 to 105m out on the straight and keep their speed).
- The lap boards are `LapBoard.gd` nodes: Level's `_feed_gantry` also calls the `lap_boards` group with the
  standings, and the LED label shows the leader's lap, then FINISH.
- Sponsor boards draw `StadiumAds.gd` artwork: its `ads` export takes a level's own 16 sponsors (the
  generator's `ADS`, fictional); layout 3 is a run of colour bars. Boards are 8:1 like the artwork, spanning
  two fence bays where the fence runs straight.
- The sky is the level's own (Msitu Falls' static cumulus shader, a sun from the south-west); the shared
  `GodotWeatherSystem` controller is gone from this level because its fog washed the sky out.
  `regenerate_desert_wadi.gd`, which copies LakesideLevel.tscn as its template, puts the weather controller back and
  clears the pads (`_reset_lakeside_template`).
- The woods are `WoodlandBuilder.gd`: oak, lime, birch, spruce and hazel, Msitu Falls' technique (bark
  tubes, leaf-spray cards with the crown's normals, near/far crossfade), with `JungleDetail.gd` scaling them
  by detail level. A broadleaf grows from its crown inward: clusters in the crown's shell, grouped into
  limbs, pipe-model radii. Each kind keeps its crown off the road (`TREE_ROAD_CLEAR`); trunks within 40m of
  the road are solid. `res://scratch/woodland_preview.gd` (`-s`, windowed) renders every tree on a flat
  meadow in seconds. Boulders use `granite_rock.gdshader` with a mossy foot.
- AI races (`scratch/ai_race_test`, speed=2) show falls at about 680m, round the loop (2600m) and between
  the two lakes at 3120 to 3132m; the undressed level had them too. None come from the venue's props. The
  old curl threw carts off the road at 2213m; the kicker doesn't.

## Frostpeak Creek road joints

- Surfaces that meet are built to shared heights above their centrelines: trunk collision deck +0.08
  (`TRUNK_DECK_Y`), shortcut deck +0.05 (`SHORTCUT_DECK_Y`), timber bridge deck top +0.08 above the bridge
  origin (`BRIDGE_DECK_TOP`). Change one and the joints step.
- The shortcut curves are built *before* `generate_world()`. TerrainGenerator then lowers terrain under
  them (`extra_road_curves`) and opens the trunk curb where a shortcut deck crosses it (`junction_openings`,
  computed from the deck footprint, not hand-entered).
- Gores are paved: where a shortcut edge runs within 4m of the trunk's collision edge it is pulled onto
  the trunk deck (`GORE_FILL_FULL/END`), and its height follows the trunk's 12cm shoulder bevel
  (`TRUNK_SHOULDER_DROP`). The trunk curb only opens where the deck covers the whole curb strip.
  TerrainGenerator carves under the deck's real outline and heights (`_deck_sections`), not a fixed width.
- Trunk control-point handles are made collinear after the curve is built, except at the jump lips and
  landings. A non-collinear pair is a corner in the road, and the road ribbon folds on its inside.

## Curbs

`curb_stripes.gdshader` draws the red/white kerb only where the curb mesh's vertex colour red channel is
1 (corners), and a plain shoulder with a white edge line elsewhere. TerrainGenerator writes that weight
(`_apply_curb_corner_weights`) when it builds the curbs. To update the saved curb meshes of every level
without regenerating them, run `res://refresh_curb_corners.tscn` headless.

## Race gates

- Every level's FinishLine and checkpoints are instances of `CheckpointGate.tscn`. `CheckpointGate.gd`
  builds the gate in code as internal children: shared meshes, box collision and the banner text. Level
  files only store the gate's transform, so a change to the gate shows on every level without
  regenerating any of them.
- The finish line (`is_finish_line`, or a node named FinishLine) is the start gantry. Its LED screen
  (`start_lights.gdshader`, a slim panel) runs a ticker: the GP, the stage, the leader's lap and the
  standings. Level sets the title (`set_ticker_title`) and feeds it its standings rows on every peer
  (`_feed_gantry`). The text is drawn into a SubViewport strip that renders only when the text changes.
  New standings wait until the strip wraps round to the title, so the swap doesn't show. The screen waves
  a chequered flag once the leader is on the last lap. `Level.start_race()` calls `show_start_lights(step)`
  at each countdown beat: 0 = lamps up and dark, 1..3 = that many red, 4 = green. The screen hangs under
  the beam because the front row's chase camera sees nothing above about 7.7m at the gantry. Keep the
  lamp energy low: brighter, ACES bleaches the red to coral and the green to mint.
- Checkpoints are an aluminium truss with a CHECKPOINT banner. `gate_color` colours the banner's bands and
  the ballast blocks. The truss is 8m tall, because carts cresting a rise pass through at up to 5.7m
  (Pinecrest's checkpoint 5).
- Levels put the gate origin anywhere from on the road to 0.4m under it (the older levels), or 3m under
  it (Canyon's Halfway1). Once the level has built its runtime collision, `_settle_on_ground()` stands
  the gate on the road under its centre and puts the feet on the ground.
  It also lowers a checkpoint (down to 4.6m) under anything more than 3m above the road, such as
  Glacier Highway's sign gantries. Lower hits come from props' collision hulls reaching over the road.
  The rays are nudged off the gate line because a ray straight down a terrain grid line can miss.
- The feet's colliders are 2.5m walls. A cart that clips the top edge of a low block gets launched,
  because PlayerCart only smooths edges up to `STEP_SMOOTH_MAX_HEIGHT`.
- `res://scratch/gate_shots.tscn -- <level> <dir> [carts=N] [fov=75] [lap=N] [all=x,y,z:tx,ty,tz]
  name:gate:x,y,z:tx,ty,tz[:step[:scroll]]` renders gates from cameras in gate space (X across the road,
  grid on +Z), with any start-light step (-1 for none) and the ticker `scroll` LEDs along. `lap=` feeds
  the ticker six racers with the leader on that lap.

## Announcer

The race calls are `voice/lola/` clips, listed per line with their takes in `MusicManager.VOICE_LINES`.
`play_voice(line)` picks a take at random. Level calls 3/2/1/go in the countdown, and at each gate the
player is counted for (`_play_lap_cue`) the chime `sounds/checkpoint_passed.wav` plus a call: "checkpoint",
"final lap" when they cross the line onto the last lap, "finish" at the line, and then the place if it's
first to third (`_announce_place`). The podium calls each place as it's revealed.
- A human who drives on past the gate they need without being counted gets "checkpoint missed"
  (`_watch_missed_checkpoints`, server). It follows the cart along the racing line like the AI's gate
  credit does, and fires once as the cart passes `MISS_DISTANCE` (14m; a gate's area is 8m deep) beyond
  the gate, until a gate counts. A step along the line over `MISS_MAX_STEP` is a re-sync, not driving
  (a respawn resets the line). Bots don't hear it: they are credited by progress.
- `res://scratch/announcer_test.tscn` (headless) walks a player through every gate and lists what was
  said. `res://scratch/missed_checkpoint_test.tscn -- [level] [skip=N]` drives a cart along the line past
  all gates but one (16m wide of its area) and reports when the call comes; `skip=-1` is a clean lap,
  which must say nothing (checked on Meadow, Northlight, Frostpeak, Nyota and Glacier).

## Button sounds and the screen swipe

- MusicManager hooks every `BaseButton` that enters the tree (`node_added`): pressing one plays
  `ui_confirm.wav`. A button with the meta `ui_important` (Confirm on car select, Host/Ready/Start in
  the lobby, the podium's Continue, the end-of-race action button, the pause menu's Restart/Exit) plays
  `ui_confirm_important.wav` instead; `ui_silent` keeps one quiet. New buttons need nothing. Both
  sound files are 3s long with silence after about a second. `res://scratch/ui_sound_test.tscn`.
- `ScreenTransition.gd` (a CanvasLayer built in code, a child of Main, `screen_swipe.gdshader`) sweeps a
  navy panel across the screen: `cover()`, `set_covered()`, `reveal()` (sweeps away and fades),
  `fade_out()`. Its colour is the loading screen's, which is opaque, so one hands over to the other
  unseen. `Main._swipe(change)` covers, runs `change`, reveals, and drops a second request while one is
  under way (`busy`): use it for every screen change a player causes. `_show_loading` covers and then
  fades off the loading screen; `_hide_loading` snaps the panel over it and reveals; a restart loads
  twice and the second `_show_loading` just changes the text. `_on_server_disconnected` (back to the
  menu) swipes unless a swipe or the loading screen already covers it.
- MainMenu and ConfigurationMenu no longer hide themselves after emitting (`start_pressed`,
  `back_pressed`): the swipe would have shown an empty screen first, so Main hides them inside the swipe.
  `start_game` hides every menu behind the loading cover. MainMenu's own pages (mode, cup, course) change
  without a swipe.
- `res://scratch/screen_swipe_test.tscn` (headless) walks the flows and checks the timing (about 0.9s
  for cover and reveal, `COVER_TIME`/`REVEAL_TIME`); `res://scratch/swipe_shots.tscn -- <dir>` renders
  the swipe over the menu.

## First-use freezes

- A shader compiles when the first thing using it enters the scene, so an effect whose material
  nothing else uses froze the race the first time it went off (the lightning: 85-130ms on a cold cache).
  `FxWarmup.gd`, added by Level, holds hidden copies of the effects' meshes, particles and materials
  (missiles, bombs, splashes, the lightning's arc and sparks) for the level's lifetime. Hidden instances
  never draw but still compile. Each PlayerCart adds hidden twins of its meshes in their fade materials
  (`_add_fx_twins`). Give a new effect a shared material and a stand-in there.
- Flashes on plain meshes (the antenna) only change values on a copy with emission always on
  (`_fx_material`). Turning `emission_enabled` or transparency on and off swaps the shader.
- The blast's fire and smoke (the cart's own particle nodes) compile when they first burn: each cart adds
  hidden copies of them to its `FxTwins` (`_add_fx_twins`). That took the first explosion of a race from
  up to 56ms to under 25.
- Music: MusicManager keeps track paths and loads only the playing track and the next one, on a
  background thread. Level picks the playlist in `_ready`, so the first track is loaded by GO.
  `load()`ing a stage's whole folder at GO froze the game for about a second.
- `res://scratch/hitch_probe.tscn -- [level=...] [items=lightning,missile,...,fade,shocked,splash]
  [repeats=2] [gap=2.0]` (windowed) uses each item or cart effect in turn in a spectator race. It prints
  the longest frames and the pipeline compilations after each use. A `surface` compilation on a first
  use is a stall.

## Boost pads

`BoostPad.gd` builds the pad itself as an internal child: a flat bevelled slab (4x6m, 8cm), one mesh
shared by every pad, drawn by `boost_pad.gdshader` with chevrons streaming toward the pad's front (-z).
The trigger flash is the per-instance shader parameter `flash`. Level files only store the transform,
so a change to the pad shows on every level. With `settle_on_track`, a pad drops onto the surface
under it at runtime (after `wait_for_collisions`), tilts with it and faces along the TrackPath.
Bloombay sets it on.

## Frostpeak sky

`sky_winter_cirrus.gdshader` (sky shader, set by the generator) draws the sky gradient, sun and static cirrus.
Tune the look with its uniforms (`cloud_coverage`, `cloud_opacity`, `cloud_scale`, `wind_dir`,
`streak_length`, `cloud_seed`). Keep it free of `TIME`: that makes Godot rebuild the radiance map every frame.
Distance mist is the Environment's depth fog (set in the generator), and the sky shader adds a matching haze band along
the horizon (`horizon_haze`, `haze_strength`, `haze_height`). Keep `fog_light_color` and `horizon_haze` the same
colour. Keep `fog_sky_affect` low: fog on the sky is uniform and washes out the blue overhead.

## Snow drifts

`SnowDrift.gd` is a height field laid over road rows (`row_centres`/`row_rights`, set by the generator).
Cars ride on its packed layer and carve the loose powder at runtime. The mesh and packed collider are
internal children rebuilt on load, so the level file only stores the row data. PlayerCart reads
`snow_depth_at()` at its nose for drag and the speed cap (`snow_plough_depth`).

## Procedural mesh winding

Godot front faces wind **clockwise**, and `generate_normals()` gives a face normal of `(c - a) x (b - a)`.
If you check winding with the right-handed `(b - a) x (c - a)`, the mesh comes out inside-out: near
faces get culled and you see the far faces from the inside. To confirm, render it or compare against
`generate_normals()`.

## Headless gotchas

- The generator runs on the dummy renderer, which ignores `MultiMesh.set_instance_transform()`/
  `set_instance_color()`. Those instances are saved with no transforms and stay invisible. Write
  `MultiMesh.buffer` directly instead (see the icicles in `regenerate_frostpeak_creek.gd`).
- A windowed `look_shots`-style run on macOS can stall after its first shot when its window goes behind
  others (the OS throttles it): the process sits idle with no more `SHOT` lines. Kill it and rerun.
- Headless can't render screenshots. To look at a level, run a `SceneTree` script (`-s`) with the
  windowed console exe and `--resolution 1600x900`, place a `Camera3D`, and save
  `root.get_texture().get_image()`.

## Large meshes are chunked

`MeshChunker.gd` splits level-spanning visual meshes (road ribbons, barriers, terrain) into an XZ grid
so cameras and shadow passes only draw nearby cells. This matters because at Medium/High shadow quality
`MusicManager._apply_shadows_to_tree` turns on shadows for every light, and each streetlight's shadow
pass used to redraw the whole track. Glacier Highway and Northlight Caverns call
`MeshChunker.chunk_scene()` just before setting ownership (`MESH_CHUNK_CELL`). Chunks go to
`generated/<level>_chunks/`, and the whole-mesh visual `.res` files they replace are deleted. Collision
shapes stay whole. To measure a level, run `res://scratch/bench.tscn` windowed:
`-- res://levels/X.tscn samples=12 [chunk=80] [omni=0] [spot=0] [shadows=N] [hide=<path>] [shot=<dir>]`.
In zsh, split a variable that holds several args with `${=args}`.

## Cars climbing small edges

The cart is one sphere, so the solver deflects it upward off any lip, and at racing speed a 1cm seam
threw it about 1m into the air. `PlayerCart._soften_edge_pops` tells edges from sloped faces (it casts a ray
toward the contact and compares normals). For edges up to `STEP_SMOOTH_MAX_HEIGHT` it caps the upward speed
at what's needed to reach the top. Ramps and jump lips are untouched. `res://scratch/hop_test.tscn`
(headless) drives a cart over steps and a ramp and prints the hop heights.

## Northlight Caverns (Svartfjell GP, night stage)

- The aurora sky reads the `aurora_clock` global shader uniform (`[shader_globals]` in project.godot,
  advanced by `AuroraClock.gd`), never `TIME`. A sky shader that uses `TIME` rebuilds the radiance
  cubemap every frame (2.5ms here); a global float moves the visible sky without touching it.
- `MusicManager._apply_shadows_to_tree` leaves lights with the meta `no_shadow` unshadowed. Every lamp,
  cavern, crevasse and spire light has it, and so does the fill DirectionalLight: shadowed, those cost 5ms.
- The road bodies carry the meta `ice_grip`. PlayerCart reads it into `surface_grip`, which scales lateral
  grip fully and braking, traction and rolling resistance in part (`ICE_*_SHARE`); the AI brakes earlier
  for it. The banks' collision is a separate `...SnowBank` body: under the road body, a bank face counted
  as road, which cancels lateral gravity, so a car sliding wide on the ice rode up the bank and over it.
- Road meshes keep only the rings their shape needs (`_select_rings`, 2cm tolerance, rings up to 4m
  apart), which cut the trunk by 92%. Slab edges are chamfered below the graded ground
  (`SLAB_CHAMFER`/`SLAB_FOOT`), or a cart that slid into a gore could wedge under a deck and fall through.
- The Northlight Spire: the trunk climbs a 285-degree spiral (`SPIRE_*`), crosses its own run-in on an
  ice arch, and jumps off a lip onto a landing hill (`LAND_*`). Spans more than `ELEVATED_MIN` over the
  ground get ice walls down to it (`_wall_profile`), the jump gap has no deck (`voids`), and neither is
  graded. `_verify_spire_arch` checks the clearance over the run-in and `_verify_spire_jump` flies carts
  off the lip. Checkpoint 4 sits on top, or the snowfield inside the spiral skips the climb.
- Blizzards: `NorthlightWeather.gd` schedules storms on the wall clock (like WildebeestHerd), drives the
  fog, sky, moon, wind audio and streaking snow, and pushes carts it has physics authority over; the
  cavern is sheltered. `force_intensity` pins it; `look_shots` and `ai_race_test` take `weather=0..1`.
- The Thin Ice (`THIN_ICE_*`, `_plan_thin_ice`) skips the spire across the lake. It has road only to and
  from the lake; across it (`_thin_plate`, a `voids` span in the road mesh) it is open ice: a 0.75m-grid
  sheet (`_build_thin_ice_sheet`) copying the natural lake surface (`_icefield_natural`) over a lead cut
  into the lake (`_apply_lead`), with the holes cut out of the sheet itself, since the terrain's 6.25m
  grid can't hold a round hole. Pressure ridges either side stop the holes being driven round. The AI
  follows its own S between the holes (the route's Path3D, held to it by the `ai_lane_limit` meta) and also
  sees the holes as layer-4 markers. `_verify_thin_ice_line` checks that line's clearance from each hole.
  Only the holes hold water: a pool under each, `HOLE_WATER_DROP` under the lowest ice round it
  (`_plan_hole_water`). The lake's natural surface dips to 2.1m, so one water level under the whole
  sheet stood above the ice in the dips, showed through it, and splashed carts driving on it. The rubble
  round the holes is loose (`KnockableIce.gd`, like `KnockablePoles.gd`). `res://scratch/thin_ice_leak_probe.tscn`
  raycasts the crossing for gaps in the sheet.
- Water is the `RiverWater` node (`NorthlightWater.gd`): `surface_at()` answers for the crevasse pool and
  the Thin Ice holes (its `_rim()` copies the generator's `_hole_rim()`). Both draw with `still_water.gdshader` (ripples sized in world metres), not the ocean shader,
  whose fine chop tiled across the mesh reads as a far-off sea from close by. No checkpoint may sit on trunk a route bypasses (`_verify_checkpoints_clear_routes`), or a car
  that takes the route never drives through it and its lap never counts.
- `glacier_ice.gdshader` takes world normals through `MODEL_NORMAL_MATRIX`: the floes and seracs are
  scaled very unevenly. It reads its pattern from the world position; anything that moves (the loose
  rubble) needs `object_space` on, or the pattern stays put while the mesh slides through it. `polar_night_ground.gdshader` samples its noise on the vertical planes on steep
  faces (`surf_fbm`); sampled from above it is constant down a cliff and paints streaks and V shapes.
  The heightfield splits each cell along the diagonal joining the closer heights
  (`_build_heightfield_mesh`); one fixed diagonal saws steep slopes that cross it into teeth.
- `res://scratch/ab_bench.tscn -- res://levels/X.tscn [samples=6] variant ...` switches variants
  (`storm`, `nolightshadow`, `nomoonshadow`, `unshadow=`, `sky=`, `hide=`, `cheapmat=`) back and forth
  within one run. On macOS, separate `bench.tscn` runs differ by up to 2x with the GPU's clock.

## Frostfall Gorge (off-road stage)

- No road mesh: the whole lap is the heightfield `GorgeGround`, so PlayerCart counts every metre as
  off-road. Keep "road", "track", "ramp", "bridge", "deck" and "snow" out of node names on this level:
  `_is_track_surface` treats the first five as road, and a "snow" ancestor turns on snow drag.
- The river falls 34m, so its water is a `RiverWater` node (`RiverWater.gd`, strips and pools), not a
  flat plane. PlayerCart picks it up by name and updates `water_surface_y` from `surface_at()` every
  physics frame. The same strip data in the generator carves the gorge and builds the water meshes.
- `_verify_jumps()` flies carts over the gully gaps and the mega-jump at 30 m/s^2 gravity and prints
  landing distance and impact; `_verify_trail_ground()` checks grade and cross slope along the trail.
- `res://scratch/ai_race_test.tscn -- res://levels/X.tscn seconds=330 speed=4` races 6 AI carts
  headless and lists every respawn with where it happened. `res://scratch/water_drop_test.tscn` drops a
  cart at given points and reports whether it drowns.
- Spruces swap to their far mesh one tree at a time: `spruce.gdshader` dithers each tree between LODs
  (`lod_mode`). The cells' visibility ranges are padded by half a cell diagonal, so a whole cell never
  pops in or out.

## Mara Crossing (Matumaini GP, stage 1)

- `regenerate_mara_crossing.gd` builds its own heightfield. There is no road mesh: the ground is
  graded flat under both roads (main lap and the `CrocJumpPath` alternative), and
  `savanna_ground.gdshader` paints the murram road from the signed distance across it, baked into vertex alpha.
  The ground's collision is split into `MurramRoad` (track) and `SavannaGround` (off-road) bodies.
- Write the real lateral distance into vertex alpha wherever it's known, not 0 off the road band.
  A 0 there interpolates a ghost strip of road across the triangles next to the band.
- `WildebeestHerd.gd` moves the migration on the wall clock (`Time.get_unix_time_from_system()`),
  so LAN peers agree without syncing. It bumps only carts with `has_physics_authority()`. The animals'
  kinematic bodies sit on layer value 4, which carts don't collide with but AI obstacle rays see.
- Kicker names must contain "jump", not "ramp": Level.gd bakes a second trimesh collider under any node
  named "ramp". Keep "Props", "Vegetation" and "Environment" out of dressing node names for the same reason.
- `StandardMaterial3D` with `vertex_color_use_as_albedo` needs `vertex_color_is_srgb = true` for the
  generator's palettes. Shaders that read `COLOR` as a colour convert it with `pow(c, 2.2)`.
- Wildlife and trees are about twice life size, to suit the RC carts. The herd instances the rigged
  `models/animals/wildebeest/Wildebeest_Animated.glb` (faces +Z, "Run" cycle) at `WILDEBEEST_SCALE`.
  `run_stride` matches the gait to the herd's speed, and the hit box scales with `animal_scale`.
  The model's texture imports are capped at 2048.
- Acacias are branch tubes (`tree_bark.gdshader`) under pads of alpha-tested leaf cards
  (`acacia_leaves.gdshader`). The generator draws the leaf texture with coverage-preserving mipmaps
  (`_acacia_leaf_texture`). Each tree crossfades to its far mesh around `ACACIA_NEAR`
  (`tree_lod.gdshaderinc`). The far meshes cast no shadow, because the shadow pass can't tell which LOD a
  tree is showing.
- Kopje tors are granite meshes (`_build_kopje_rocks`): a half-buried dome with boulders resting on or
  against it, never piled into towers, which read as cairns. `granite.gdshaderinc` is shared with the
  ground shader. Keep the kopje heightfield smooth: a coarse grid heaped with lumps reads as gravel.
  `_verify_rocks_bedded` reports any block that floats.
- `res://scratch/mara_test.tscn -- [seconds=200] [speed=4] [croc=1.0]` sends the AI over the croc jump
  and reports take-off speeds, drownings and herd bumps. `res://scratch/mara_shots.tscn` renders the menu
  tiles (windowed, into a fixed-size SubViewport). `res://scratch/look_shots.tscn -- <level> <dir>
  [car=x,z,yaw] name:x,y,z:tx,ty,tz ...` renders look-dev shots with carts dropped in for scale.

## Nyota Stadium (Matumaini GP, stage 2)

- `regenerate_nyota_stadium.gd` plans the lap as turtle moves (`PLAN`: straights and circular arcs), so
  the lanes are exactly straight and the hairpins exactly round, and places everything by arc length `s`
  (`_plan_at`). The jumps are pieces of one height profile along `s` (`_plan_profile`, `_add_run`,
  `_add_double`). One ribbon (`_build_track`) carries dirt in the bowl and tarmac outside (vertex colour,
  `stadium_track.gdshader`), with the hairpin berms (`_berm_lift`) and shoulders down into the floor.
  Collision: `StadiumTrack` and `StreetTrack` (track), `ArenaInfield` (off-road).
- The floor is `STREET_Y` (7m) below the streets. The four stands stop short of the corners, where
  retaining walls hold up the corner yards. The lap leaves up a ramp in a cutting through the north-east
  yard and drops back in off the south-east one (the Drop-In: a kicker on the yard, a `voids` gap over the
  wall, a landing hill). The corner walls' collision stops at street level and the parapets have their
  own: a full-height box once blocked the Drop-In's corridor for slow carts and clipped fast ones.
- Tune jumps with `res://scratch/nyota_jump_test.tscn` (headless), which drives a real cart over every lip
  (TrackPath meta `jump_lips`) at capped speeds. Real carts fly 30-45% further than `_verify_jumps()`'s
  ballistic estimate: they leave the lip steeper and drive themselves back to top speed in the air. The
  landings are tuned to the real test: at 40 m/s, the speed carts carry in the lanes, every landing is on
  its landing face.
- Berm backs run 1:3.2 (`BERM_BACK_RUN`). PlayerCart won't climb off-road slopes past about 35 degrees,
  and a cart that went over a steeper berm was stuck behind it.
- Sponsor artwork can't be drawn headless, so `StadiumAds.gd` draws it into an atlas at load (fictional
  sponsors only). `stadium_boards.gdshader` reads it: `COLOR.r` picks the advert, `COLOR.g` marks LED
  boards that cycle. `_sign()` builds a panel whose text reads left to right from its front.
- The crowd (`_build_crowd`): every spectator is a card (far) and, near the lap, also a 3D figure (near). See
  "The crowd" below.
- `city_ground.gdshader` paints the street grid that `_build_city` fills with blocks (`STREET_X0`,
  `BLOCK_X`, ... must match). `city_building.gdshader` draws the facades; `COLOR.a` is 0 for a block,
  0.25 for a low block with a painted iron roof, 1 for a glass tower. The jacarandas reuse Mara
  Crossing's acacia build (`_tree_plan`, `acacia_leaves.gdshader` with a blossom atlas).
- `scratch/ai_race_test` at `speed=4` steps physics at 1/15s: a cart at 60 m/s moves 4m a step, tunnels
  into barriers and wedges. Check suspicious respawns at `speed=1`. Respawns tagged "boom" are item
  explosions, not the track.
- `res://scratch/nyota_shots.tscn` renders the menu tile with carts posed anywhere, mid-air included.
  `res://scratch/nyota_live_shot.tscn -- <dir> [wait=25] [level=...] name:x,y,z:tx,ty,tz` takes shots
  during a live spectator race, for what only renders in a real game.

## Matatus (Nyota Stadium's plaza and car park)

- `MatatuKit.gd` builds a Nairobi matatu, a 14-seat high-roof minibus (the Toyota HiAce shape) at life size
  (5.4 x 1.9 x 2.3m, nose toward -z) through a `PropKit`; the generator scales it by `MATATU_SCALE` (2). The
  driver is on +x and the sliding door on -x, because Kenya drives on the left. `LIVERIES` is data: colours, the
  name painted on the van, route number, plate, rear slogan and a `style` (flames, swoosh, zebra, flag, stars,
  bolts, check) that picks the artwork in `_art_side`. A new livery is an entry there plus, for a new look,
  a branch in `_art_side`.
- The shell is a loft of cross-sections along z (`_ring`, `_params`): the arches are cut by lifting the
  underside over each wheel (`_bottom`), with dark liners so they don't look through the van. The side wall
  is exactly planar below the belt line and exactly tilted above it, which is why paint and glass can be flat
  polygons: `_side_poly` clips a (z, y) shape to the paintable panel (`PANEL`) and the arches, splits it at the
  belt line and lays it on the wall `off` metres proud. `L0` to `L5` are the paint layers' offsets (band,
  artwork, two more, lettering shadow, lettering): the mobile renderer can't separate faces closer than
  about a centimetre, so each layer stands 6mm (life size) above the last. Shapes that overlap must be on
  different layers, and the lettering above all the artwork: pink and cyan swooshes both on `L1` z-fought where
  the wave crossed itself (Malaika), and lettering between two artwork layers was covered by the upper one. Keep new artwork off the nose
  above the belt (the belt drops there) and on the lower panel, or on the windows/pillars.
- Offset a side's decals as `side * wall_x + off * normal.x`, not `side * (wall_x + off * normal.x)`: the
  second form pushed the whole left side's glass and paint inside the body.
- Lettering is the pixel font `GLYPHS` (`_text`, five rows; add any letter you need). On the +x side the text
  reads toward the nose, on -x toward the tail, as on a real vehicle. Give a name a colour that contrasts
  with the artwork under it: the first pass had pink lettering on a pink swoosh.
- A matatu is five surfaces (`make_material`): `paint` (clearcoat), `glass`, `chrome`, `matte` (black plastic,
  rubber, underbody) and `lamp` (emissive, tinted by vertex colour; the neon under the sills too), so a
  van is five draw calls. About 10k triangles a van, eight meshes shared by the 16 vans.
- `regenerate_nyota_stadium.gd`'s `_build_matatus` bakes one mesh per livery used and places `MeshInstance3D`s
  (`spots`: position, yaw, livery). They save to `generated/matatu_*.res`, not `nyota_*`, through
  `_save_shared_resource`: `MeshChunker.chunk_scene` splits any `nyota_` mesh of 8000+ triangles on an
  80m grid in local space, and a van is modelled around its origin, so each one became four pieces.
  `_matatu_lap_distance` errors on any van within `STREET_HALF` + 1.5 of the lap (the nearest is 12.5m); a van
  within `MATATU_SOLID` gets a box collider.
- `res://scratch/matatu_preview.gd` (`-s`, windowed) renders the vans in memory in a second:
  `-- <dir> [livery=N | all=1] [scale=2] [fov=40] name:x,y,z:tx,ty,tz ...` (life size, nose toward -z, driver
  on +x).

## Street lights, the arena wall, facades and the big screen (Nyota Stadium)

- `StreetLampKit.gd` builds the street light at life size through a `PropKit`: base plate and bolts, a sleeve
  with a service door, a tapered pole with collars, a swan-neck arm with a brace, and a cobra-head luminaire
  (`_build_luminaire`: a lofted aluminium shell, a dark underside, a glowing lens, a photocell). The arm
  reaches along +x. `_build_street_lamps` bakes one mesh (`generated/streetlamp.res`, shared, not `nyota_`) and
  instances it at `LAMP_SCALE` (1.35, a 12m pole) in 160m cells with a 380m draw range; `_build_precinct_dressing`
  turns each so its arm is over the road. About 1.4k triangles a lamp. The lens uses plain additive emission:
  an emission multiplied by a single vertex colour read dull tan against the sky.
  `res://scratch/streetlamp_preview.gd` (`-s`, windowed) renders one: `-- <dir> [scale=1.35] name:x,y,z:tx,ty,tz`.
  The stands' roof lamps and the floodlight heads are still boxes.
- The stand fronts' wall (`_build_walls`) stands 3cm proud of the stand shell (`WALL_FACE_OFFSET`): both had their
  arena-facing face at the arena edge, and two coplanar faces z-fought across the concrete above the boards.
  It only showed on the south wall, where the sun is behind the face and the two meshes shade differently. The
  board frames (`FRAME_D`) and the boards (`BOARD_D`) keep 4cm gaps in front of it.
- `stadium_boards.gdshader` fades its LED pixel grid by how big a cell is on screen (`fwidth`), not by
  distance alone: along a wall from 25m the 3cm cells were under a pixel wide and shimmered as the camera moved.
- To tell flicker from parallax, render the same view from two camera spots 3cm apart and diff the images:
  `res://scratch/nyota_shots.tscn -- <dir> freeze s0:... s1:...` (`freeze` stops the LED boards cycling their
  adverts, or the diff just shows the ad changing). Z-fighting shows as blocky patches; parallax as thin edges.
- City facades (`_building`, `city_building.gdshader`): each wall's UV.x is stretched (under 15%) so the wall
  ends on a whole 4m bay, and the Builder's second UV set (`tri2`, UV2.x) so it ends on a whole 6m shop
  front. Before, UV.x ran on round the perimeter, so a window could straddle a corner and show on both walls;
  now every window has a margin at the corner, a glass tower's panel grid (two panels a bay) lands a mullion on
  it, and the counts carry on from wall to wall so each wall still gets its own random windows. A Builder
  only writes UV2 if `tri2` was used.
- The windows of the city's buildings (`city_building.gdshader`) look like glass without a real reflection: the
  panes are dark with a tint (blue, green, bronze or grey) and low roughness, which gives the sun's glint from
  the real specular, and the reflected sky is a made-up one in EMISSION: `reflected_sky(reflect(-view, normal))`,
  a gradient to the horizon with a couple of noise reads for cloud puffs and a darker ground below it, scaled by
  a Fresnel term (`refl_base` face-on, up to 1 at a grazing angle), brighter toward the top of each pane, and
  dimmer in a fifth of them (a dark room). Panes behind a curtain stay dull. The glass towers' curtain wall gets
  the same, stronger. It costs a few noise reads on window pixels within the detail range. `refl_top`,
  `refl_horizon`, `refl_ground` and `refl_cloud` are set from the sky's colours in `_build_city`: change the sky
  and change them too. (Giving the panes a metallic albedo to reflect the sky's radiance map gave pale flat
  colour, since from above they only reflect the haze and the ground.)
- The sky (`_build_environment`) is `sky_tropical_cumulus.gdshader` (Msitu Falls' shader) set for a Nairobi
  afternoon: a deep clean-air blue overhead, big heaped cumulus (`cloud_coverage` 0.58, `cloud_scale` 1.15) with
  blue-grey bases, a dusty haze along the horizon matching the fog (`HAZE`) and a warm glow on the sun's side
  (`sun_horizon_glow`, a uniform that is 0 for Msitu). The cirrus sky was Frostpeak Creek's.
- City buildings (`_build_city`, `_building_massed`): no longer one box each. `_massing` makes a building's tiers as
  polygons: a slab, a podium with a tower and a crown (the glass towers, with a lit mast), a stepped one (two
  setbacks, on two sides or four) or an L with a lower wing. `_tier` builds a tier's walls (UV.x stretched to whole
  bays, see above; UV2.y the window style) and roof. The architecture goes on top, by distance from the lap
  (`CITY_DETAIL_NEAR` 180m: everything, `CITY_DETAIL_MID` 460m: massing, cornices and parapets, beyond: a plain
  box): cornices, parapets, corner pilasters, shop awnings along the street fronts, balcony galleries (a slab, a
  railing and a rail per floor on every other storey) and the roof's gear (`_roof_gear`: a lift housing, polytanks
  on stands, solar water heaters, air-conditioner condensers, an antenna mast, a dish). `_edge_box` lays a box
  along a polygon's edge (depth out from the wall, `inner` behind it).
- The small parts go in a second mesh per cell (`BlockDetail_*`: no shadow, drawn to `CITY_DETAIL_RANGE`), the shell
  in `Blocks_*` as before. The details use their own random stream (`drng`, seeded from the plot's position), and
  `_add_rooftop`'s old draws are still burned on the city's `rng`: a new draw there moves every building after it.
- A vertex colour's alpha picks the facade in `city_building.gdshader`: 0 a block with windows, 0.25 a low block
  with an iron roof, `A_PLAIN` 0.7 plain concrete (the trim, plant rooms, tanks), `A_RAIL` 0.8 railing (vertical
  bars, the gaps `discard`ed: alpha scissor would turn the whole building shader into a transparent pipeline), 1
  glass. Windows have a sill, a dark line under it, a lintel and a shaded reveal, and a style per building: punched,
  a ribbon, a narrow pair or tall (UV2.y). Regenerating Nyota takes about two minutes now (the polygon work).
  Benchmark: no change at the start grid (29.9ms; the detail parts are about 20k visible triangles).
- `FoodTruckKit.gd` (extends MatatuKit): the fan zone's three food trucks (`TRUCKS`: Chai na Mandazi, Nyama Choma,
  Pizza Safari), each a HiAce cab (MatatuKit's shell cut at the cab's back, `_station_zs`, its wheels, lamps and
  lettering) with a box body: a serving hatch on +x with a striped awning on stainless arms, a counter, bottles on
  shelves under a lamp, a menu board, a lit roof sign with pennants, an air-conditioner and chimney, rear doors,
  gas bottles on a rack and a generator. `_build_food_trucks` places them (yaw -90 degrees puts the hatch toward
  +z, the plaza) between the plaza's trees (the old boxes stood in front of them), sharing the matatu materials
  (`_vehicle_kit`). `res://scratch/foodtruck_preview.gd`: `-- <dir> [truck=N | all=1] [scale=2] name:x,y,z:tx,ty,tz`.
- `MarketStallKit.gd` (extends MatatuKit, for the pixel lettering and the grid helper): Soko Street's market stalls at life
  size (3 x 2.2m, the front toward +z), six trades in `KINDS`: vegetables (stepped crates of heaped produce with price
  tags, a hanging scale, bananas, sacks), second-hand clothes (two rails of hung shirts, dresses and trousers, folded
  piles, a bale, strung shoes), shoes (tiered shelves and a table of pairs, sandals strung from the beam), fruit (a
  striped umbrella over watermelons and pineapples, a handcart with wheels), grains and spices (open sacks on two
  stages behind the counter, bowls of spice, jars, scales) and an airtime and phone-accessories kiosk (a tin and
  plank hut with a shutter propped as an awning, shelves of covers, a glowing charging board). Every stall has a
  rough timber frame with lashings, a tarpaulin (wrinkled and sagging between the rafters, with a wavy valance) or
  corrugated iron (real ridges), and a painted sign (`SIGNS`). `variant` changes the colours. Five-odd materials
  (`make_stall_material`: wood, tin, cloth (double sided), plastic, produce, paint). About 3k triangles each.
  `_build_market_stalls` builds one mesh per trade and colourway and places them (STALL_SCALE 2); a seller stands
  behind each counter. A tarp's valance hides what is hung at its own height: signs under a tarp hang lower.
  `res://scratch/stall_preview.gd`: `-- <dir> [kind=N | all=1] [variant=N] [scale=2] name:x,y,z:tx,ty,tz`.
- The Jumbotron (`_build_screens`, `Jumbotron.gd`): its frame is tilted with the screen (`rotation.x`, 6
  degrees). The screen leans back, so with an upright frame the quad's upper half sank behind the frame's front
  face and only the bottom 56% of the picture showed, a black bar over it. Glacier Highway tilts its housing
  with its panel, which is why that one was fine. `res://scratch/nyota_live_shot.tscn -- <dir> wait=20 jumbo_dump`
  saves what the screen's own camera sees (`jumbo_view.png`) apart from how the quad shows it, which tells a
  camera problem from a mapping or occlusion one.

## The crowd (Nyota Stadium)

- A spectator is two things drawn from one `INSTANCE_CUSTOM` (`crowd_common.gdshaderinc`: r a seed, g the skin
  draw, b the pose `(id + 0.5) / 16`, a a second seed and the animation phase), so it is the same person at both
  distances: a **card** (`stadium_crowd.gdshader`, a flat figure drawn in the shader, the old look, now with legs)
  and, within reach of the lap, a **3D figure** (`CrowdKit.gd` mesh, `stadium_person.gdshader`). They swap by dither
  between 34 and 44m (`tree_lod.gdshaderinc`: `lod_mode` 1 on the figure, 2 on the card).
- `CrowdKit.gd` is one mesh (about 1.4k triangles, 800 of them drawn) in a standing rest pose at 1.86 times life
  size (3.3m, the stands' scale), carrying every hair style, a dress and the props. Per vertex: COLOR the part
  (limb), region (skin, shirt, trousers, ...) and style (which hair or prop); UV/UV2 the limb's two joints (they all
  lie in the plane z = 0) or a head part's head-unit position. The vertex shader bends the joints per pose, hides
  the styles a spectator doesn't have (`VERTEX = vec3(0)`), and the fragment shader paints the face (eyes, brows,
  nose, mouth, ears, stubble, sunglasses). Its constants (`HEAD_C`, `HEAD_R`, `HIP_Y`) repeat CrowdKit's.
- The 16 poses (0-6 seated: idle, clap, film, talk, arms crossed, cheer, drink; 7-15 standing: idle, clap, cheer,
  film, arms crossed, flag, hands on hips, wave, drink) are tables in `stadium_person.gdshader` (`ARM_L`, `ARM_R`:
  pitch, roll, elbow, yaw; `LEGS`), a forearm's direction from straight down being pitch + elbow. Not everyone
  cheers: `POSE_*` in the generator are the odds (about 10% cheer, 17% in the main stand's middle).
- The figure stands on y = 0; a seated one's pelvis drops to `SEAT_HIP` over it. In the stands the origin is the seat
  cushion's top (`CROWD_SEAT_H`), so a standing fan stands on the seat; the people in the plazas, round the stalls
  and in the yards behind the barriers (`standing_only` spots) stand on the ground and have legs.
- Skin: about 80% African (dark to medium brown), the rest South Asian, European, East Asian, Arab or mixed
  (`crowd_skin`). Hair is black and tight (short or an afro) in the African group; others vary. 6% are children
  (`crowd_height`), and clothes have hoops, stripes, badges, long or short sleeves, dresses, caps and headscarves.
- Cards: a pixel of a card is shaded however empty, and the stands are many cards deep, so there is a card shape
  per pose class (`CROWD_CARDS`: seated, seated arms up, standing, standing arms up, standing with a flag; only
  arms up need the wide ones). The per-person values are worked out once per card in `vertex()`, and `fragment()`
  draws the outline first and discards outside it before choosing a colour. Seated cards stand 0.6m toward the
  arena (`CROWD_CARD_FORWARD`) so their shins aren't hidden by the seat cushion; flat things that stand at the
  seat's own depth lose their lower half to it.
- Only spectators within `CROWD_NEAR_REACH` of the lap (in plan) get a figure, in 24m cells (`CrowdNear_*`) with a
  visibility range. `CrowdDetail.gd` (group `vegetation_detail`, on the `Crowd` node) follows the Detail Level
  setting: Off no figures (the cards at every distance), Low 24m, Medium 34m, High 44m, Ultra 57m. It sets
  `lod_fade_begin`/`end` on every crowd material and the cells' range. The generator indexes the lap
  (`_index_lap`) before the crowd for this.
- Cost (M1, 1600x1000, `scratch/bench.tscn`): the 3D figures about 0.4ms, the cards about 1.5ms, of a 30ms frame at
  the start grid; Ultra 0.5ms more than High. Bench runs on the M1 differ by up to 2x with the GPU's clock (one
  "both hidden" run read 12ms against 30ms for the rest, and sent me looking for a 19ms card cost that wasn't
  there): repeat a run before believing a big difference. In zsh a variable holding several `hide=` arguments
  isn't split, so `hide=a hide=b` in one variable hides nothing.
- `res://scratch/crowd_preview.gd` (`-s`, windowed) renders the figures in memory in a second: `-- <dir> [rows=3]
  [seed=1] [cards=1] [skin=<g>] name:x,y,z:tx,ty,tz`, a column per pose 0..15 (2.6m apart), the cards in a row
  behind with `cards=1`. `nyota_shots` takes `detail=N` to try a Detail Level.

## Camps (CampKit.gd: Lakeside Course and Bloombay Dunes)

- `CampKit.gd` holds the vehicle and tent builders that used to live in `regenerate_lakeside.gd`, built
  through a `PropKit` at life size (nose toward -z, y up) and placed by the caller with `set_frame` at
  `PROP_SCALE` (1.6). `make_material(key)` is the one definition of the camp's vertex-colour materials
  (`matte`, `metal`, `canvas`, `lamp`, ...): each generator saves and shares its own copies.
- The layouts are data (`LAYOUT_MAIN` 34x26m, `LAYOUT_VILLAGE` 26x20m, `LAYOUT_PAIR` 18x16m: items in terrace
  coordinates, +z toward the track) and `build_layout()` lays one out on a pad, so both levels place camps
  the same way. It returns the pitches' footprints and `bad`, any pair closer than `CAMP_GAP` (1.5m) or
  standing off the pad by more than a metre. Footprints (`FOOT`) are measured off the built meshes,
  awnings included: a motorhome with its awning out is about 7 x 12m at game scale, so five vehicles, four
  tents and three gazebos did not fit the Lakeside's 34 x 26m terrace and overlapped. Change a builder's
  size and re-measure `FOOT` (build it into a PropKit, read `commit().get_aabb()`).
- A vehicle's awning side is its +x, which a layout turns to terrace -x: space a row of awning vehicles
  7m apart plus the gap, not the 4m body width.
- Pads are the only level ground. A 12m vehicle on a slope floats at one end, so camps stay on their pad.

## Bloombay Dunes (beach stage)

- The surf is `beach_water.gdshader` on the `BloombayWater` node, which `regenerate_bloombay_dunes.gd` builds
  (`_build_ocean`) after `generate_world()` replaces TerrainGenerator's flat plane. The generator bakes a shore
  field (`_bake_shore_field`, one texel per terrain vertex from `SHORE_X0` to `SHORE_X1`): ground height,
  wave travel time to the waterline (an eikonal solve with the shallow-water speed, so crests bend round the
  bay and close up as they shoal), surf weight, and the shallowest depth seaward. The shader numbers waves by
  phase, breaks them where they get taller than 0.78 of the depth, and runs their swash up the sand. Change
  the terrain and the field follows on the next regeneration.
- The water mesh is a grid on the terrain's grid lines (thirds of a cell across the surf zone `SURF_X0..X1`),
  so the swash sheet lies parallel to the sand, then wider out to `OCEAN_REACH`. It is chunked for culling.
- The waterline is `TerrainGenerator.bloombay_shore_x(z)`, the seabed `bloombay_sea_depth()` (1:25 foreshore,
  sandbar about 40m out). Keep the waterline 10m+ off the beach straight's outer edge.
- The water draws the sand under it from the screen texture as emission. Clamp any screen UV you offset:
  past the frame edge the copy holds stale pixels (it showed up as a strip of text along the bottom).
- Structures are under `Seafront` (`_build_seafront`), named to avoid Level.gd's "Props"/"Environment"
  trimesh baking (and no "ramp" either). `_verify_seafront_clear` errors on any footprint too close to the
  racing line.
- Every seafront part a cart can touch has collision: boxes, cylinders and hulls (`_box_in`, `_box_along`,
  `_rod_collider`, `_hull_collider`). `_collider` adds each shape to one body per structure (`<name>Body`).
  Carts can wade the shallow sea out to the lighthouse, so it has collision too. Flat things on the sand
  (towels, planks, nets) have none.
- People-sized things are about 1.6x life size (`PROP_SCALE`), because at life size a lounger is shorter
  than a cart. Builders lay them out at life size inside `_scale_about(pivot, s)` ... `_end_scale()`.
  `_tri`, `_ground`, `_collider` and `_note` all work through that frame: things placed with `_ground()`
  in the life-size layout land on the real sand. Pick the pivot on the sea side so the structure grows
  inland, away from the racing line. This applies to the huts, the bar, the lifeguard towers, the
  parasol sets and the fence. The pier and the lighthouse grow seaward from their landward ends.
- Parasol sets are rejection-sampled per zone (`PARASOL_ZONES`): `PARASOL_GAP` apart, on dry level sand,
  clear of the track and of every footprint noted before them. The fence is built first for that reason.
- Loungers, cool boxes and parasols are knockable (`KnockableProps.gd`). Each design is one MultiMesh,
  and each prop a frozen rigid body that a cart faster than `push_speed` frees as it nears. At 22 m/s
  a cart keeps ~88% of its speed and flings a lounger clear; a slower cart stops against it.
  - Parasols free at 2.5 m/s, so a bump topples them. Their weighted base holds the centre of mass
    low (`centre_of_mass_y`), so they don't fall over when a cart just passes.
  - Frozen props must be on layer 1: Jolt's static bodies don't look for contacts, so on a layer
    outside the carts' mask a slow cart drove through them. A freed prop moves to its own layer.
  - `_knock_add` records them in the parasol sets, and `_build_knockables` builds the meshes at the
    origin. Towels have no collision.
- Sign lettering is block capitals from `GLYPHS` (`_pixel_text`), since text can't be drawn headless. Add
  any letter you need to the table.
- Flags (`_flag`) wave in `flag_wave.gdshader`. The shader reads the hoist-to-fly position from UV.x
  and the flag's phase and length from UV2, so `_flag` writes its vertices itself instead of going
  through `_tri`.
- Flicker: the project renders with the mobile renderer. At racing distances its depth buffer can't
  separate faces a few millimetres apart, so decals, glass, lettering and paint layers stand 2-3cm
  proud of what's behind them. No two faces may overlap in one plane: hut walls run between their
  corner posts, not through them. On the wreck's double-sided "wreck" material, timbers are sunk a
  centimetre into the planking rather than laid on it. `res://scratch/zfight_scan.gd -- <mesh.res> ...
  [tol=0.002]` lists overlapping coplanar triangles in saved meshes. Ignore same-colour pairs and
  faces hidden on the ground or under roofs.
- Point 19 (the third dune crest) is close to the map's edge falloff: past 0.88 of the terrain radius,
  the ground drops to -40, below the respawn height. Pointed north-east, its handles hooked the lap
  back in an 8m radius on the crest, and AI carts flew off it into the drop again on every lap.
  Keep corners near the edge wide. `scratch/ai_race_test` at `speed=2` finds such loops.
- Don't put a boost pad within ~100m before a real corner. A pad pushes for 2s whatever the brakes do,
  and the AI doesn't brake while boosting until a turn is 14m away (`PlayerCart._get_ai_input`, "let
  the boost rip"). BoostPad_5 moved from the point 19 crest to the run onto the finish straight.
- The shipwreck is a trawler built from a hull function, `_wreck_point(s, a, side)`, in its own frame
  (`WRECK_*`), and is heeled toward the dunes so the dune descent sees its deck. The stove-in side faces
  the sea. Missing planks are keyed per station and strake (`_wreck_plan_damage`), and frames are built
  only where planks or deck are gone. `_verify_wreck_bedded` errors if the hull clears the sand anywhere
  aft of the forefoot.
- FastNoiseLite defaults to 5-octave FBM. For paint or sand patches sampled per mesh cell, set
  `fractal_type = FRACTAL_NONE`, or the patches break up into a checkerboard of single cells.
- Coconut palms (`_build_palms`) are instanced from four shapes (`PALM_SHAPES`, `_palm_mesh`).
  - Each palm has a ringed trunk that leans and curves back up (`palm_trunk.gdshader`), fronds and
    coconuts. A frond is two leaflet cards hung in a V from its midrib (`palm_fronds.gdshader`, atlas
    drawn by `_palm_frond_texture`).
  - Palms crossfade to a stand-in round `PALM_NEAR` (`tree_lod.gdshaderinc`).
  - They grow in groves on the land side of the beach, and a few metres up the banks of the water
    (`PALM_BANK`), leaning toward it.
  - `_palm_ok` keeps them clear of the racing line, the gates and the seafront footprints, so they're
    built after the gates. `_palm_lean_clear` follows each trunk's lean and the crown's droop past
    every footprint taller than they are there (`_note`'s `height`). A palm behind the huts once
    leaned seaward through their roofs.
  - The root is "Palms", not "Vegetation", which Level.gd would bake trimesh colliders under.
  - Each trunk's collider is a cylinder over its first 4m, tilted with its lean.
- The monorail (`_build_monorail`, `MONO_*`) runs on a beam 9m up along the landward edge of the
  beach.
  - To the south it curves over a dune lagoon to a buffer. To the north it crosses the lap, with no
    pylon in the road corridor, and runs on off the map and out to sea (`MONO_FAR_Z`), as if it went
    somewhere. Off the map it has no collision or footprints.
  - The beam's dark conductor band is part of its side faces (`_beam`): laid on as a strip, it
    flickered.
  - South Beach station (`_build_mono_station`) stands at the beach path, so the dune fence's gap
    there is wide. It has a glass vault, a glazed hall and stairs toward the track, kept 5m+ off its
    edge.
  - `Monorail.gd` shuttles a three-car train between the far end, the station and the south end on
    the wall clock, like `WildebeestHerd.gd`, so LAN peers agree without syncing. It plays the baked
    station chime (`_station_chime`) 3s before each stop at the station. The cars are internal
    children, each with an AnimatableBody3D box.
  - The line's footprints keep palms out of its corridor.
- The surf is heard from `SurfSound`, AudioStreamPlayer3Ds 10m seaward of the waterline every
  `SURF_SPACING`. They alternate two clips baked by `_surf_stream`: rumble, curl, crash and swash
  on `SEA_PERIOD`, three waves in one clip and four in the other, so neighbours never fall into step.
- The inland dunes are dressed after the seafront (`_build_inland`, before the palms, whose `_footprints`
  check keeps them off everything noted here). The generator takes about 17s.
  - Five camps (`CAMP_SITES`: s along the lap, side, `CampKit` layout) stand on pads graded into the sand
    with `TerrainGenerator.flat_pads`. `_plan_camps` runs before `generate_world()`: it searches ±110m of
    each site's s for the pad with the least relief at a distance that keeps its blend (`CAMP_BLEND` 9m) clear
    of the curb, off the beach strip, gates and other camps, and reads natural heights through
    `_sample_cached_height` (which computes them from the curve while no world exists). Every inland spot
    is sloped (3-8m of relief over a camp), so each pad is a cut-and-fill terrace.
  - `_build_corner_runs`: the sharpest corners (`_corner_sites`, outside of the turn picked from the
    heading change) get a tyre wall or red/white barriers at `TYRE_LAT` (10.9m, 2m past the curb) with
    feather flags, chequered flags and cones; `_build_camp_frontage` runs barriers and flags along the road
    edge facing each camp. Tyre walls and barriers have box colliders.
  - Flags are `_banner()` meshes in world space in `flag_wave.gdshader` (the seafront's flag shader):
    feather flags are a width profile down a 3.9m pole, chequered flags a 8x5 cell grid. All stream east,
    off the sea.
  - Pebbles and rocks (`_build_rocks`) are eight `_rock` meshes (four 320-face rocks, four 80-face pebbles)
    in 60m MultiMesh cells; the big ones get cylinder colliders and stay 14m+ off the lap. A third of the
    clusters lie in the dune grass.
  - Dune grass (`_build_dune_grass`, `dune_grass.gdshader`) is isolated patches (`GRASS_PATCH_GAP` apart)
    of tufts in 60m MultiMesh cells; vertex colour alpha is the height up the blade, which the shader sways
    with `TIME`. Grass and rocks cast no shadow. Tyre walls, barriers and flags are one mesh per corner or
    camp frontage with a `visibility_range_end` (`DRESS_RANGE`): one level-wide mesh can't be culled by
    distance, and measured 0.3ms of GPU on an M1 for no reason.
  - `DuneDetail.gd` (on the `DuneCamps` node, group `vegetation_detail`) follows the Detail Level
    setting like `JungleDetail.gd`: it thins the grass, the rocks and the bent palms' cells
    (`visible_instance_count`, so the generator shuffles each cell's instances) and pulls their draw
    distance in. The level is built at the richest (Ultra) and guards against baking a level of detail into
    the level when run by a generator. On an M1 (2020), against High (what Auto starts at): Off -0.77ms,
    Low -0.53, Medium -0.29, Ultra +0.19 (`res://scratch/ab_bench.tscn -- <level> quality=0 quality=2 ...`).
  - Bent palms are `PALM_SHAPES` 4 and 5 (`BENT_FIRST`): lean about 55-65 degrees at the foot, curving
    back up under the crown. Some lagoon palms are bent (from their own RNG, so the beach palms keep their
    places), and `PALM_DUNE_ANCHORS` anchors along the lap plus four round each camp grow singles and pairs
    (`_palm_crown_off_road` keeps a crown 5.5m off the road's edge).
- `res://scratch/bloombay_shots.tscn -- <dir> name:x,y,z:tx,ty,tz[:frames[:gap]]` renders into the window
  (not a SubViewport) and can save a time sequence to watch the surf.

## Msitu Falls (Matumaini GP, stage 3)

- The sky is `sky_tropical_cumulus.gdshader`, static like the others (no `TIME`). It keeps
  `sky_winter_cirrus.gdshader`'s uniform names, because `JungleRain.gd` drives `sky_top`, `sky_horizon`,
  `cloud_*`, `sun_glow` and `sky_energy` to cloud the sky over in a storm. `cloud_coverage` past ~0.65 closes
  it into a dark overcast deck on its own.
- `_ground_at()` must split each cell on the same diagonal as `_build_terrain` (the one joining the closer
  heights). With one fixed diagonal it stood up to a metre off the real surface on some cells, and plants,
  posts and signs floated or sank there. `_verify_ground_at` reads the mesh's index buffer back and
  errors on any difference. Everything the generator stands on the ground goes through it.
- Ground plants and canopy trees are placed with `_relief_under()`: the fall from the foot to the lowest
  ground under the leaves (or buttress roots). Ferns and shrubs sink by `PLANT_SINK` of it and skip a lip
  steeper than `MAX_PLANT_RELIEF`; buttressed trees do the same (`TREE_*`). Without it the downhill
  leaves hung in the air over the road's banks. `res://scratch/msitu_forest_audit.gd` (run with `-s`, windowed,
  since the dummy renderer returns zeroed multimesh transforms) measures every instance's root against
  the terrain mesh.
- Fern fronds are folded (`_frond`'s `fold`): a flat ribbon seen along its width is a thin line, and a ring of
  them from the side looked like spider legs. Their tips droop to the ground.
- Chevron boards draw their arrows toward +UV.x (`_build_chevrons`' shader, tip at x = 0.65) and the
  generator mirrors the UVs for a left-hander, so they point into the bend. The shader once drew
  `<`, which put every board backwards. `res://scratch/msitu_chevron_check.gd` (headless) reads the
  saved level and lists any board whose arrows disagree with the road's turn.
- The ranger post is `RangerPostBuilder.gd`, laid out by `build_all()` and baked to
  `generated/msitu_ranger_post.res`: an office with a veranda, a thatched rondavel, a store with a
  woodshed, a tank, a signboard, fence and flag. Buildings are modelled at life size in their own frame
  (X along the front, Y up, Z out of the front) and grown by `SCALE` (1.6); anything laid on a surface
  stands 2.5cm+ proud of it. Its shaders (`hut_wood`, `hut_roof_iron`, `hut_thatch`, `hut_masonry`)
  take UV in world metres and the vertex colour as the tint (they linearise it); the mesh carries
  generated tangents for the corrugation and straw normal maps.
- The post stands on a level pad graded into the lowland west of the straight (`POST_*`,
  `_pad_weight` in `_build_heights`). The yard is written into the vertex-colour masks as a patch of road
  (`_yard_paint`), so the ground shader paints worn laterite there. `_in_ranger_yard` keeps trees
  and understory out of it, and `_verify_ranger_post` checks every footprint is within 12cm of the pad
  and well clear of the road. The old buildings sat where the start clearing happened to fall, and two of them
  hung over the hillside.
- Don't put "road", "track", "ramp", "bridge", "deck", "jump", "curb", "pier", "gate" or "checkpoint" in the
  name of anything with collision: `PlayerCart._is_track_surface` treats it as drivable.
- `res://scratch/ranger_post_preview.gd` (run with `-s`, windowed, `-- <dir> name:x,y,z:tx,ty,tz ...`) renders the post
  on flat ground in a few seconds, without generating the level.

## Car select screen

- `CarSelection.gd` builds the whole screen in code (`CarSelection.tscn` is only the root): a showroom
  SubViewport behind the UI (the car on a turntable, `showroom_sky.gdshader` for studio reflections,
  `showroom_floor.gdshader`'s fading grid, over a gradient drawn by the Control), the car's card and stats
  on the left, the paint shop on the right, Back / the line-up / Confirm along the bottom. Each car has an
  accent colour (`CAR_ACCENTS`) for its stat bars, the turntable's ring and Confirm.
- The camera is a long lens (`CAMERA_FOV` 26) from far back; the old 75-degree lens from 2m stretched the
  car. The turntable turns once every ~24s, and the car can be dragged round (or turned with the right stick).
- The showroom renders only while the screen is up (`UPDATE_WHEN_PARENT_VISIBLE`); the old preview
  rendered through every race.
- Left/right, Q/E or the shoulder buttons change car, except while the paint shop has the focus: its
  rows are single buttons that take left/right. Back, Esc and the pad's B emit `back_requested`; Main.gd
  returns to the menu, the lobby room, or player 1's pick from player 2's.
- `res://scratch/car_select_flow_test.tscn` (headless) walks Main's flow through the screen and prints
  what's visible at each step. `scratch/menu_shot` takes `size=<w>x<h>` (the window can't exceed the
  screen, so on a 16:10 Mac it stays 16:10).

## Explosions tear the cars apart

- `CarDebris.gd`. A procedural car is one `Body` mesh plus four wheels, with every part merged into the
  body, so the pieces are found in the mesh: triangles that share vertices are one piece (union-find).
  The biggest is the shell; pieces of 60+ triangles (shocks, bumpers, wings, mirrors, lamps, exhausts,
  cage tubes: 26-61 on the six cars measured) can tear off alone, and smaller fittings stay on the shell.
- `PlayerCart._ready` calls `CarDebris.prepare()`: a worker thread splits the body and builds the piece
  meshes (centred on their own middle, same vertex layout and material as the body, so they take the paint
  and the fade) and the shell in 11 shards, keyed by model path and shared by every cart of that model.
  The main thread only reads the mesh arrays first. Nothing is analysed at the explosion.
- `roll()` picks the damage: about 12% scorched (0-1 wheel, 2-4 parts), 30% the wheels go (2-4 wheels,
  1-3 parts), 38% stripped (0-2 wheels, 5-10 parts), 20% disintegrates (the shell comes apart in shards
  and the 22 biggest parts fly singly, 2-4 wheels). Parts are picked weighted toward the big and the
  outlying. `tear()` assembles it: one new body mesh at most (the index buffer without what came off).
  Each peer rolls its own, as the wheels always did, so the debris differs between machines.
- `PlayerCart._tear_car` / `_update_debris` / `_clear_debris` fly each piece with its own simulation
  (thrown, spinning about its middle, a bounce or two, at rest), not the `part_*` dictionaries the
  wheels use. The piece keeps the body's vertices because `car_body.gdshader` paints from model-space
  positions: moving the vertices to recentre them would slide the stripes and the number. The pieces are
  `car_shader` meshes under the model, so the fade-out and flashes reach them. Respawn restores the body
  mesh and frees them.
- Tools: `damage_override` on a cart forces the damage. `res://scratch/explosion_shots.tscn -- <dir>
  [cars=...] [dmg=name:wheels:parts:dis] [nofire]` blows carts up on the grid and shoots them (`nofire`
  shows what is left of the car); `res://scratch/car_parts_dump.gd` (`-s`, headless) lists a car's pieces.
  `hitch_probe` takes `explode_wheels`, `explode_parts` and `explode_shatter`.

## Engine sounds

Each car has its own loop: `engine_sound` and `engine_gain_db` in its PlayerCart preset (the loops are in
`sounds/enginesounds/`). The gain brings every loop to the Mudrunner's loudness, the original engine, which
keeps it: the loops were made at very different levels (the electric motor needs +10.8dB, the hum +17.8dB,
the rest -3dB). `_setup_engine_sound` loads the preset's file; speed moves its pitch from 0.8 to 1.35 and
its volume from -32 to -22dB, plus the gain. Measure a new loop's RMS and set the gain to
20*log10(0.328/rms). `res://scratch/engine_sound_test.tscn -- cars=0,1,...` lists each car's loop.

## Procedural cars (all eight)

- Every car is built in code; they replaced Hunyuan imports, which are all gone. `CarBuilder.gd` is the geometry toolkit (lofts,
  lathes, tubes, rounded boxes into one indexed mesh, the material id per vertex in UV2.x). `CarDesign.gd` is
  what the cars share: the lofted shell, fender sweeps, wheel parts, a coil-over, the detail map. Each car
  extends it (`MudrunnerBuilder.gd`, `PhantomBuilder.gd`, `StrikeforceBuilder.gd`, `CenturionBuilder.gd`, `ShadowBuilder.gd`, `InterceptorBuilder.gd`,
  `ViperBuilder.gd`, `ApexBuilder.gd`) with
  its shape and its own parts. `regenerate_cars.gd` saves each as `generated/cars/<Name>.tscn` with its meshes, material and detail
  map; run `res://regenerate_cars.tscn` headless. PlayerCart and CarSelection load it through the preset's
  `model_path`, with `model_y_rotation` PI and `wheel_parts` `Wheel_FL` ... `Wheel_RR`. `PlayerCart.tscn`'s
  `CartModel` placeholder (swapped for the preset's model at spawn) and the look-dev tools' stand-in carts
  (`gate_shots`, `look_shots`, `msitu_shots`, `bloombay_shots`, `nyota_shots`) are procedural cars too, in their
  factory paint.
- Builders work in the cart frame (metres, front at -Z, ground at y = 0); the scene's `Model` node undoes
  PlayerCart's x2 scale and half turn. Each car keeps its Hunyuan model's wheel positions, so it sits
  where the old one did. Proportions are measured off the FBX: slice the body per z for its top, bottom
  and widths, probe the fenders. `res://scratch/car_dump.gd` (`-s`, headless, `-- <car.tscn> <dir>`) writes an
  imported car's triangles in the cart frame, per part, for slicing.
- The shell is one cross-section per station (bottom, corner, vertical side to the beltline, then the
  car's `_upper()`), each parameter a curve of knots along the car; caps close the ends (`*_cap_exp`:
  high exponents for a flat face). Stations are refined where neighbouring sections differ. A section
  with features (a tight roof corner, the Phantom's bonnet dome) must use `segment_counts` /
  `_upper_segments()`, so every feature sits on the same ring points at every station; resampled as
  one curve, the points slid between features and the loft folded into creases.
- A section whose shape changes along the car (the Strikeforce: hardtop over the cab, a bed sunk into the
  tub, a flat bonnet and tailgate; the Centurion: a deck over nose and engine, its cockpit sunk between the
  side armour) keyframes all its upper profiles in one table (`KEYS`, `CarDesign.keyed_knots()`), so they
  change together and each region boundary (windscreen, cab back, dash, firewall) is a clean wall, not a
  fold. Where two segments meet, match their slopes, or the clearcoat shows the crease.
- The Centurion's Hunyuan model stood on narrow front wheels like a dragster; the rebuild has the same paddle
  tyre at all four corners. Its paddles follow the carcass and taper into the shoulders (`_paddle`):
  full height to the edge, they stood out from the sidewalls like fins. Its cage is in the accent colour
  (`M_ANODISED`), so the paint job's accent recolours it.
- The Shadow's section is faceted: straight runs between corners with small fillets (`_upper_segments`),
  every corner keyed in `KEYS`. Its pods grow out from under the bonnet's side, which stays the same wall
  (on the nose the pod is a 1cm ledge), so the ring points never jump between regions.
- Plates, roof panels and wings are profiles swept along a path (`CarDesign.sweep()`), each strip turned
  outward by its profile edge's normal: a centroid test flipped the Shadow's wing top, whose centroid
  lies off the bent plate. `slab()` extrudes a side-view outline across x (endplates, swan necks),
  `round_lamp()` is a bezelled lamp.
- The Interceptor cuts its arches by lifting the shell's bottom in a squared superellipse over each wheel
  (`_bot_knots`) and sweeps its flares along that outline; its bumpers are as wide as the flares, or the
  flares' ends stood out past them like fins. Nose and tail parts (lamps, intakes, grilles) sit on the
  shell via `CarDesign.face_frame()`, which finds the surface and its normal with `shell_z()`.
- A greenhouse needs a real corner in the section. On one smooth dome (`CarDesign._upper`'s cubic) the
  windscreen had nowhere to stop: it wrapped round into the side glass, and a pillar painted onto the
  dome read as a wedge. The Interceptor's section has the corner (`_upper_segments`: the glass leaning
  in, its rounding, the crowned top), and the detail map puts the A-, roof-rail and D-pillars on that
  rounding by arc length along the section (`_upper_s`, `PILLAR_PAD`). A threshold on the detail
  map's normals gave ragged edges instead, since they step from one ring point to the next.
- Stations are doubles. A flat cap (exponent 8) closes only at the exact tip: the tip rounded to a
  float32 (1.025 -> 1.0249999) left a hole a quarter of the face across.
- Wheel arches through a body (the Phantom) are cut by lifting the shell's bottom over each wheel
  (`BOT_KNOTS`), with dark liner walls inside so the arch doesn't look through the car; the flares
  sweep along the same outline (`_arch_lip()`).
- One shader draws the whole car: `car_body.gdshader` (code in `car_body.gdshaderinc`). Paint patterns are
  drawn in the car's frame from the builder's `PAINT_LAYOUT` uniforms. The body's detail map (R glass,
  G panel gaps, B chrome, A black) draws windows, seals and panel lines over the shell's UVs: u by arc
  length along the top of the centre line, so a windscreen gets its share. The caps squeeze a flat front
  or rear face into few texels, so details there (grille, lamps, the Strikeforce's tailgate frame) are
  parts. The map is saved as a lossless `PortableCompressedTexture2D`, which needs `keep_compressed_buffer`
  or it saves empty.
- Headlamp lenses go through `CarDesign.lens()`, whose UVs centre the reflector rings the shader draws.
  Black plastic flares: set `fender_mat`/`fender_col`. A part built round the origin (the Strikeforce's
  spare, its own `build_wheel()`) is put in place with `CarBuilder.transform_from()`.
- Paint jobs (`CarPaint.gd`: pattern, finish, four colours, racing number) are per-instance shader
  parameters (`CarPaint.apply`), so all cars of a model share one material. Only models whose root has the
  `procedural_car` meta are paintable, and the paint shop in CarSelection hides for the others. It saves
  per car in `user://settings.cfg` (`[paint]`, `[paint_p2]` for split-screen's second player).
  NetworkManager carries the paint job in the player info and with car changes (`CarPaint.clean` on
  receipt), Level passes it in the spawn data, and bots get `CarPaint.random`.
- PlayerCart's flashes on meshes tagged `car_shader` go through instance uniforms (`fx_glow`, `fx_tint`).
  Fading swaps in `car_body_fade.gdshader` (`fx_alpha`) as the material override: the Mobile renderer
  ignores `GeometryInstance3D.transparency`, and a shader that writes ALPHA always draws as transparent.
- Turn a built surface around with `CarBuilder.flip()` or `orient_*()`, which rewind the triangles too.
  Negating only the normals leaves the faces pointing inward, and they get culled.
- New shaders compile in the background and draw nothing until they're ready, so look-dev tools wait ~40
  frames before the first shot.
- `res://scratch/car_preview.gd` (`-s`, windowed) builds a car in memory and renders it from named cameras:
  `-- <dir> [car=Mudrunner] [paint=<pattern>,<finish>,<hex primary>,<hex secondary>,<hex accent>,<hex rim>,<number>]
  [orig=<imported car .tscn>] [yaw=<deg>] [scene=<saved car .tscn>] [sun=<pitch>,<yaw>] name:x,y,z:tx,ty,tz[:up]`
  (`orig` with the old preset's turn: `yaw=-90` for a model that had `model_y_rotation` PI/2).
  `res://scratch/car_live_shot.tscn -- <dir> [level=...] [cars=5,5,0,1,2,3] [carts=100,101]
  [fx=shock,respawn,teleport,fade]` shoots carts in a live race. `scratch/ai_race_test` takes `cars=`, and
  `scratch/menu_shot` takes `car:<index>[:<pattern>]` for the paint shop (it saves nothing).
- To rebuild another car: write `<Name>Builder.gd` extending `CarDesign.gd` (set the shell in `_init()`;
  `build_body`, `build_wheel`, `_detail_shapes`/`_detail_at`, `PAINT_LAYOUT`, `WHEEL_POSITIONS`,
  `ANTENNA_POS`), add it to `regenerate_cars.gd`'s `CARS` and its factory paint to `CarPaint.FACTORY`, then
  point the preset in both PlayerCart and CarSelection at `generated/cars/<Name>.tscn`.
- The Apex overrides `section()` to cut its wheel wells as notches (the bottom steps up an inner wall
  `x_well` to the arch's ceiling, then out round the fender's lip), instead of lifting the whole bottom over
  each wheel like the other cars. That lets its open bed's floor sit below the arches, between the rear
  wells. Where there's no wheel the notch has no height and the section is the usual one. The front
  wells reach in to x 0.285 and 0.33 along the car either side of the axle, for the tyres at full lock.
- Where a bonnet turns up into the windscreen (the cowl), keep the section's crown and the top's
  width (C's x) steady, or the windscreen's base bends: the Apex's crown turned from the bonnet's dish
  to the windscreen's dome within 3cm, which stood a steep triangular prow under the glass, and its
  bonnet's wider top narrowing there flared the A-pillars' feet. Its crown is 0 across the cowl and
  grows slowly up the glass, and B is keyed by its own x (`bx`), so the bonnet's shut lines run on
  into the A-pillars. To check a cowl, print `top_y()`'s slope along z at a few x: it should rise
  the same at every x. Parts lying across a crowned roof (visor, light bar, lip) follow `top_y()`.
