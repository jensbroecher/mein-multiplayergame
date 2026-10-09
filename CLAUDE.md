# RC Vibe GP (Godot 4.8, GDScript)

## Godot executable

Portable install, not on PATH:

- `D:\Godot\Godot_v4.8-dev6_win64_console.exe`: use this one from the shell, because it prints to stdout/stderr
- `D:\Godot\Godot_v4.8-dev6_win64.exe`: GUI editor

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
