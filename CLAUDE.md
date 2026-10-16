# RC Vibe GP (Godot 4.8, GDScript)

## Godot executable

Portable install, not on PATH:

- `D:\Godot\Godot_v4.8-dev6_win64_console.exe`: use this one from the shell, because it prints to stdout/stderr
- `D:\Godot\Godot_v4.8-dev6_win64.exe`: GUI editor
- On macOS: `/Applications/Godot.app/Contents/MacOS/Godot` (prints to stdout as well)

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

`Level.tscn` and `MountainLevel.tscn` can each be written by several generators (`regenerate_both`,
`regenerate_custom_path`, `regenerate_desert`, ...). Don't regenerate them unless you know which one made the
current file.

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
  (`start_lights.gdshader`) waves a chequered flag. `Level.start_race()` calls `show_start_lights(step)` at
  each countdown beat: 0 = lamps up and dark, 1..3 = that many red, 4 = green. The screen hangs under
  the beam because the front row's chase camera sees nothing above about 7.7m at the gantry. Keep the
  lamp energy low: brighter, ACES bleaches the red to coral and the green to mint.
- Checkpoints are an aluminium truss with a CHECKPOINT banner. `gate_color` colours the banner's bands and
  the ballast blocks. The truss is 8m tall, because carts cresting a rise pass through at up to 5.7m
  (Pinecrest's checkpoint 5).
- Levels put the gate origin anywhere from on the road to 0.4m under it (the older levels), or 3m under
  it (Canyon's Halfway1). Once the level has built its runtime collision, `_settle_on_ground()` stands
  the gate on the road under its centre and puts the feet and the START/FINISH decal on the ground.
  It also lowers a checkpoint (down to 4.6m) under anything more than 3m above the road, such as
  Glacier Highway's sign gantries. Lower hits come from props' collision hulls reaching over the road.
  The rays are nudged off the gate line because a ray straight down a terrain grid line can miss.
- The feet's colliders are 2.5m walls. A cart that clips the top edge of a low block gets launched,
  because PlayerCart only smooths edges up to `STEP_SMOOTH_MAX_HEIGHT`.
- `res://scratch/gate_shots.tscn -- <level> <dir> [carts=N] [fov=75] [all=x,y,z:tx,ty,tz]
  name:gate:x,y,z:tx,ty,tz[:step]` renders gates from cameras in gate space (X across the road, grid on
  +Z), with any start-light step.

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
- The crowd is one card per spectator (`stadium_crowd.gdshader` draws the figure; pose, shirt and skin
  are in `INSTANCE_CUSTOM`), in a MultiMesh per 60m cell, casting no shadow.
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
  parasol sets and the fence.
- Parasol sets are rejection-sampled per zone (`PARASOL_ZONES`): `PARASOL_GAP` apart, on dry level sand,
  clear of the track and of every footprint noted before them. The fence is built first for that reason.
- Sign lettering is block capitals from `GLYPHS` (`_pixel_text`), since text can't be drawn headless. Add
  any letter you need to the table.
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
    built after the gates.
  - The root is "Palms", not "Vegetation", which Level.gd would bake trimesh colliders under.
  - Each trunk's collider is a cylinder over its first 4m, tilted with its lean.
- `res://scratch/bloombay_shots.tscn -- <dir> name:x,y,z:tx,ty,tz[:frames[:gap]]` renders into the window
  (not a SubViewport) and can save a time sequence to watch the surf.
