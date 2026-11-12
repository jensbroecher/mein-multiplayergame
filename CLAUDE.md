# RC Vibe GP (Godot 4.8, GDScript)

## Godot executable

Portable install, not on PATH:

- `F:\Godot\Godot_v4.8-beta2_win64_console.exe` (or latest in `F:\Godot`): use this one from the shell, because it prints to stdout/stderr
- `F:\Godot\Godot_v4.8-beta2_win64.exe`: GUI editor
- On macOS: `/Applications/Godot.app/Contents/MacOS/Godot` (prints to stdout as well)

## Scratch folder is committed and never deleted

The `scratch/` folder contains permanent test, verification, look-dev, and audit scripts for the project.
- **Do NOT exclude `scratch/` from git** (never add it to `.gitignore`).
- **Do NOT delete or clean up files in `scratch/`**. Any new test scripts or probes created there are preserved so they can be re-run whenever needed.

## Menu tiles

Every stage's menu tile (`images/menu/tile_*.jpg`, 1376x768, drawn cropped to about 5:3) is the same kind of picture:
the stage from a bit far off and at an angle. `scratch/render_menu_tiles.sh [Lakeside ...]` renders them (all, or the
stages named by their level file without "Level.tscn") through `res://scratch/menu_tile_shot.tscn` (windowed, one run a
stage, about a minute each) and imports them; `OUT=<dir>` writes them there instead. The camera stands 30 degrees up,
as near as the whole lap (with room round it) fits the frame, tipped up a little so the country shows above, on the
bearing (every 15 degrees, never looking into the sun) that frames it nearest; the fog is pushed back by most of the
camera's distance, falling snow and Mina's dust wall are hidden, shadows reach across the view. Per-stage overrides
(`focus`/`radius` for the point-to-point routes, `zoom`, `az`, `elev`, ...) are `STAGES` in the script. The user may
change the courses again: re-render a stage's tile after a big change rather than hand-placing a camera. No level
generator writes a tile. `res://scratch/lap_points.gd` (`-s`, headless, `-- <level> [every=250]`) prints where a
lap runs, to aim a focus.

## The main menu's mode tiles are live 3D scenes

The mode tiles (Single Player, Splitscreen, Multiplayer, Spectator, Inspect, Options, and Grand Prix, Time Trial and
VS Race under them) are no longer AI pictures: `MainMenu._add_tile` with a `scene:<kind>` file puts a
`MenuTileStage.gd` (a TextureRect drawing its own SubViewport and World3D, built in code) where the picture was. The
cars are the game's own in factory paint, and the Mudrunner (the game's "main character") is in every scene with cars.
The Garage tile stays a render (`tile_garage.jpg`); GP Test, the cups and the courses keep their pictures, which drift
and zoom slowly (`MenuTileDrift.gd`: zoomed in 8%, the zoom breathing, a drift of about 45 seconds inside the room the
zoom leaves, leaning in under the pointer or focus, each tile on its own phase; in a holder that clips it inside the
border). So no tile stands still.
- The cars stand still on a road that slides under them (`menu_tile_road.gdshader`'s `scroll`, set from the script), with
  marker posts, bushes and trees (Harbor Pier's saved far tree meshes) wrapping along it; hills round the horizon. Every
  motion is a function of the clock (`seek`).
- `_frame` frames each camera on what it shows (a centre, its extent across and up) into the part of the tile above the
  caption's fade, whatever the tile's shape: 4:1 on the main screen, nearly square under Single Player.
- Kinds: single (the Mudrunner from the front), splitscreen (two viewports sharing one world, each chasing its car, P1
  and P2 badges), multiplayer (seen from behind, the Mudrunner as P1 chasing three others under name tags), spectator (a
  broadcast's high side view, LIVE and lap badges), vs (two side by side, head on), time_trial (a hologram ghost,
  `menu_ghost.gdshader`, and a running lap time and gap), grand_prix (the podium at night under a chequered banner,
  confetti), inspect (`Drone.gd`, no cars), options (`MenuPropKit.build_bench`: a workbench with a laptop whose screen
  is a live 2D settings page with telemetry, a pro pistol-grip transmitter whose wheel steers the Mudrunner on its set-up
  stand, a pegboard wall, hex drivers, a LiPo). The bench's car is at the game's prop scale (`BENCH_SHOW_SCALE`, the
  garage's 1/1.6 of race size: about 1.4m beside a 32cm laptop; the user found an RC car's real 46cm too small for this
  game's very large scale cars), its stand as high as its body's underside plus 3cm. The laptop's and transmitter's pages
  are drawn on their screens in 3D (`MenuPropKit._settings_page`, `_tx_page`: flat quads, Label3Ds and ribbons laid
  out in design pixels a fraction of a millimetre over the screen). As a SubViewport's texture the page shimmered
  (no mipmaps), then, rendered with its tile, came out grey or drawn into a corner of the screen while the tile under
  the pointer drew every frame (the user saw it every time; no probe here did, since reading a texture back makes the
  GPU finish its work first). The laptop is a 16-inch one (the user's choice). Options' camera is placed by hand (`_aim`, not `_frame`): low
  and about 0.8m in front of the laptop from its left, a 54-degree lens, looking past it to the transmitter and the car;
  so the room is closed on the right (a side wall) and has a floor under the bench. The tiles' viewports have physics
  interpolation off: the project's is on, and with the camera and cars moved in `_process` the hovered tile (drawn every
  frame) flickered on fine detail while the mouse moved. `res://scratch/laptop_flicker_probe.tscn -- [frames=90]
  [dir=<out>] [first=1] [fullscreen=1]` (windowed) moves the mouse over the Options tile and records the laptop screen
  frame by frame, or (`first=1`) watches the page from the menu's first frame; `res://scratch/laptop_startup_probe.tscn
  -- [frames=120] [key=2.5]` runs the real start-up (Main as the running scene, the title card skipped by a key) and logs
  the page's viewport every frame once the menu shows.
- A tile's contents are under "Content" in a Panel ("Picture") 4px inside the frame whose rounded rectangle
  (`TILE_INNER_RADIUS`) clips them (`clip_children`), so the picture, the caption's shade and the colour bar follow
  the frame's round corners (`TILE_RADIUS`). A page's tiles cascade in (`_cascade_in`: each fades in as its picture rises
  into the frame, `CASCADE_STEP` apart, a course list within `CASCADE_SPAN`; started a frame after the page is built,
  whose frame is long), also when the menu comes back. Changing page fades the last page out whole where it stood
  (`_fade_out`, `FADE_OUT_TIME`, on `TileFadeOut` over the tile area) and builds the new one only then
  (`show_sub_menu` awaits it; `current_screen` changes at once): built at once, its long frame made the fade's tween
  jump to the end. `res://scratch/menu_transition_shots.tscn -- <dir> [from=main] [to=sp_modes] [every=4] [count=12]`
  (windowed) saves a contact sheet of the frames through a page change.
- MainMenu's `_relayout_tiles` measures the ScrollContainer (the VBox inside it is as big as its content, so it had
  sized each page from the last: small tiles at start-up, the two Single Player tiles taller than the screen), runs again
  whenever the scroll area resizes, and caps a tile at about 5:3, the grid centred. `res://scratch/menu_layout_probe.tscn
  -- [size=1728x1080] [start=<w>x<h>] [hidden=60]` (windowed) walks the pages and prints every tile's size.
- Cost: each tile costs about 2ms of an M1's GPU whatever its size, MSAA or shadows (the trees' near meshes 2ms more,
  so the far ones are used). So only the tile under the pointer or focus renders every frame; the others take turns
  (`IDLE_EVERY` by Detail Level: every 2nd frame from Medium, every 3rd at Low and Off, never slower: at every 4th the
  road judders and the user read the tiles as still), and nothing renders while the menu is hidden. The main screen holds
  60 fps on the M1 at 2880x1800. `res://scratch/menu_motion_check.tscn -- [detail=0..4] [screen=stage_select]` (windowed)
  runs Main's real menu and prints how much of each tile changed in half a second (0%: a still tile). `res://scratch/menu_tile_bench.tscn -- [screens=main,sp_modes] [frames=300] [dbg=<switch>:<value> ...]`
  (windowed) prints frame times and each tile's GPU time; the `dbg` switches (`MenuTileStage.dbg`: msaa, glow, shadows,
  trees, far_trees, sky, scale) price the parts. `res://scratch/menu_shot.tscn -- <dir> main sp_modes coop_config`
  photographs the screens.
- `Drone.gd` (a camera drone at game scale, about 1.3m across, nose toward -z: body with a livery band, carbon arms,
  motors, spinning props with faint discs, skids, a gimbal camera, nav lights and a strobe) runs itself with
  `auto_animate`, so it can fly over the races later as a broadcast drone.

## Levels are generated, not hand-edited

Each level in `levels/*Level.tscn` (plus its meshes in `generated/*.res`) is written by a generator script
in the project root: `regenerate_<level>.gd`, run through the matching `regenerate_<level>.tscn`.
Don't edit the generated `.tscn`/`.res` files by hand, because the next regeneration overwrites them.
Change the generator and regenerate instead.

Regenerate headless from the project root (the scene saves the level and quits by itself):

```sh
"/f/Godot/Godot_v4.8-beta2_win64_console.exe" --headless --path . res://regenerate_frostpeak_creek.tscn
```

Close the Godot editor while regenerating: with it open, one regeneration's `generated/mountain_track_collision_shape.res`
came out truncated (corrupt; the level failed to load its track) and a regeneration with the editor closed wrote it whole.
Afterwards, check the output for `ERROR:` lines from the generator. Generators like Frostpeak Creek run
self-checks (`_verify_ramp_junction`, `_verify_bridge_alignment`) that `push_error` on bad geometry but
still save the level. You can ignore these at exit: "Node not found: Players/PlayerSpawner" (`Level.gd` runs
outside a game), "Leaked instance dependency", and RID/ObjectDB leak messages.

`LakesideLevel.tscn` can be written by several generators (`regenerate_both`, `regenerate_custom_path`,
`regenerate_desert`, ...). Don't regenerate it unless you know which one made the current file. `MountainLevel.tscn`
(Jebel Sahar) is now made by `regenerate_mountain_dressing.gd` alone, which re-bakes its ground too: the old
`regenerate_mountain`/`regenerate_both`/`regenerate_custom_path` would bring back neither its pads nor its dressing. `LakesideLevel.tscn` (Lakeside Meadows) is dressed by `regenerate_lakeside.gd`: run that after any of
the others re-bakes it (see Lakeside Meadows below).
`FrostpeakCreekLevel.tscn` is dressed by `regenerate_frostpeak_dressing.gd`: run it after `regenerate_frostpeak_creek.gd`
(see Frostpeak Creek below).
`GlacierHighwayLevel.tscn` is dressed by `regenerate_glacier_dressing.gd`: run it after `regenerate_glacier_highway.gd`
(see Glacier Highway below).

## Lakeside Meadows (Bloombay GP, stage 1)

The menus call it Lakeside Meadows (it was the Lakeside Course / Meadow Circuit); files and code keep "lakeside"
(`LakesideLevel.tscn`, `regenerate_lakeside.gd`).


- `regenerate_lakeside.gd` dresses `levels/LakesideLevel.tscn` as an RC race meeting and replaces everything under
  `LakesideDressing` on every run: the paddock, race control and its observer tower, the lap towers, catch fences, crowd
  barriers, tyre walls, hay, cones, the grandstand across the first corner, the campsite on the hill, the
  orange kicker, the long bridge's wooden ramps and boost pads, the woods, the boulders, the meadow grass, the woodcutter's yard, the marquee, the cars on
  show and the spectators; it also lays the AI's shortcut. The terrain and road stay TerrainGenerator's.
- It grades flat pads (`TerrainGenerator.flat_pads`: paddock, grandstand footing, campsite terraces) and mows
  the venue's verges (`grass_clearings`, no tall grass there). Both are applied after the road blend, so keep
  them off the road. The world is re-baked only when they change (or with `-- rebake`). A run without a
  bake takes about 35s. Pad heights come from the natural ground (pads cleared first), so they are the
  same on every run. TerrainGenerator's own grass cards are gone (`no_grass`): they were most of a
  re-bake's 13 minutes.
- The meadow grass is `_build_meadow` (`MeadowGrass.gd`, `meadow_grass.gdshader`, `MeadowDetail.gd`): tufts of
  real blades (curved, tapering strips with rounded normals, a few flowers) swaying in gusts that roll across
  the meadow from the turbines' side. Nothing is placed one by one: three tiers (dense near, sparser and
  wider out to 116m and 230m) each draw one shared MultiMesh of a cell's tufts at y = 0 in every cell, and
  the shader stands each tuft on the ground from a height texture (the terrain's 2m grid, read on its own
  triangles like `_ground()`) and grows it as a 0.5m grass map says (R how much, G how tall). The map is
  drawn in the generator: thinner and shorter in the woods, mown on the clearings and pads, short along the
  verges, none on the roads (except under the bridge), in the lake or on cliffs, and none under anything
  standing on the ground: every prop's triangles within `GRASS_TOP` of the ground (the dressing, the level's
  own props, the loop, the bridge piers) and the footprints of the trunks, boulders and hazel at each
  instance (`_stamps`). New dressing needs nothing. Cost (M1, ab_bench): 5.6ms, against the old cards' 8.3ms.
  `MeadowDetail.gd` thins the shared MultiMeshes and pulls the fade in with the Detail Level; Level.gd feeds
  the carts' positions to the materials (group `grass_push`) so the grass bends round them.
- Hay bales (`_hay_bale`, `hay_bale.gdshader`): a lumpy rounded bale with flake seams, strands and weathering
  drawn in the shader (UVs in metres), four twines and loose straws. Tyre walls (`_tyre`, `tyre_wall.gdshader`):
  each tyre a lathe with UVs across its section, the shader drawing tread, sidewall ribs and lettering, and
  the paint chipped off the tread and edges.
- The loop (`Ramps/LoopCSG`, `LoopCSG.gd`) builds itself from its exports as internal children, never saved.
  It was placed facing against the lap, and the road falls 1.2m across it, so the lane the carts left by
  ended a metre above the road. `_fit_loop` turns it to face the lap and sets `entry_end_y`/`exit_end_y`
  25cm under the road at each end, with the road's grade (`road_grade`); the lanes are cubic ramps.
  `res://scratch/loop_exit_probe.gd` (`-s`, headless) raycasts the surface across both ends against the road.
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
- The long bridge (s 1180-1690, about 20m over the lake; a bend at 1360-1520) and the climb to it carry
  `WoodenRamp.tscn`s curb to curb under `LakesideDressing/BridgeJumps` (`BRIDGE_RAMPS`, `BRIDGE_PADS`,
  `_build_bridge_jumps`): two rollers at s 955 and 985, a kicker at 1215 where the bridge leaves the shore with a
  boost pad straight into it, a table-top at 1570 after the bend, and boost pads at 1040, a staggered pair after
  Halfway2 (1145, 1165) and 1545. Their lips join the TrackPath's `jump_lips`:
  `nyota_jump_test ... level=res://levels/LakesideLevel.tscn ground=1` lands the kicker 38-74m on at 30-58 m/s
  (before the bend), the table-top 25-50m on, every cart keeping its speed. Hand-tune them in the generator:
  anything under `LakesideDressing` is replaced on every run. AI races (speed=2) lose about one bot a race in the
  bridge's bend (1485-1588), with or without them.
- The scaffold tower beside race control (`_build_observer_tower`, `OBSERVER_TOWER`) carries a race observer
  instead of its old broadcast camera: a spectator with arms crossed on the platform (`_observer_spot`, added
  in `_build_spectators`; a spot's fifth field picks `CrowdPlacer`'s pose).
- The loop's lanes taper their walls (and the entry divider's nose) down into the road over the last
  `LoopCSG.end_taper` (8m) of each end: a CSG box subtracted above a plane from 3cm over the lane's surface at
  its end to the walls' tops. Cut square, 2.6m walls stood up out of the road as blunt black blocks. The cut
  box takes the asphalt material (a subtraction's faces take its own: white by default) and stays low and
  inside the lane, clear of the loop above it.
- The loop stands on a platform of its own (`_build_loop_apron`, `LOOP_APRON_*`, `loop_apron.gdshader`): the road
  stops square at its ends (a road gap from `_plan_road_gaps`, `LOOP_GAP_TAPER` 5cm, the curbs stopping there,
  `TerrainGenerator.road_gap_half_width` grading the ground under its whole width), and a 40cm concrete slab, its top
  level with the road along the lap's line (so flush with it at both ends), flares from the road's edge to
  `LOOP_APRON_HALF` under both lanes; the lanes' ends lie on it `LOOP_END_LIP` up. Drawn in bays with joints, a white
  edge line, hazard stripes along the flared sides and white chevrons leading into the entry lane; its vertices are
  pulled toward the eye (as the paths') so its ends win the depth test against the road's last centimetres. Solid
  (`LoopApronDeck`: track, asphalt). The user disliked both earlier versions: the road tapering to a point into the
  grass either side of the loop, and the road running on under it with the lanes sunk into the asphalt, half on it.
  Without grass to slow them (the second version) bots left the loop at full speed into the 60 degree corner after it
  and ran off the deck over the inlet: see the guardrails below. The pylons reach down to the ground beside the road
  (`LoopCSG.support_foot_y`, from the ground under `support_spots()`, 0.4m in): they started at the loop's origin
  and stood in the air.
- W-beam guardrails (`_build_drop_rails`, `DROP_RAILS`: [s0, s1, sides]) stand on the deck's edge
  (`DROP_RAIL_LAT` 7.75) wherever the ground `DROP_RAIL_OUT` past it is more than `DROP_RAIL_DEPTH` under the road,
  led in `DROP_RAIL_LEAD` posts before each drop: over the inlet after the loop (s 2690-2805, both sides; the ground
  falls 15-18m just past the curbs) and round the outside of the first corner (s 3270-45, over its embankment, where
  `_trim_run` leaves the tyre wall out and boosted bots flew off). Boxes per span (`GuardrailBody`).
- A LOOP AHEAD sign stands `LOOP_SIGN_BEFORE` (75m) before the entry lane, right of the road (`_build_loop_sign`):
  a yellow board on two posts with the loop drawn on it (a road in, a circle shifted on a little, an arrow out)
  and the words in a Label3D.
- Single meshes under `LakesideDressing` get no collider from DressingColliders.gd: "lake" (in the node's path) is
  one of its `MESH_SKIP` water words. Give new dressing its own boxes (`_boxes_body`): the marquee's beer tables
  have a block each, the rowing boat a convex hull (`RowboatBody`).
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
- AI races (`scratch/ai_race_test`, speed=2) show falls at about 668m and between the two lakes at 3115 to
  3132m; the undressed level had them too. None come from the venue's props. The loop used to stall carts
  at its entry (2600m) until its lanes were separated, and its exit pad then boosted them off the corner
  55m on (2745m): see the loop note above. `res://scratch/loop_ai_probe.tscn` traces one AI cart through it.
  The old curl threw carts off the road at 2213m; the kicker doesn't.
- `ConcreteRamp.tscn` (hand-built CSG, Ramps/ConcreteRamp): its rear cornice hangs just under the lip (it
  stood 0.38m above it and carts leaving the jump hit it), and the side plinths slope in at the toe, under
  the walls (flat, they stood up out of the ramp's foot).
- The water (`TerrainGenerator/Water_Surface`) is a 12000m plane. `water.gdshader` tiles its ripples 40 times
  across the mesh's UVs and was tuned on a 1600m plane, so `wave_scale` is the plane's size / 1600; at 1 the
  ripples were 300m across and raced. Both `_generate_water` and `_update_water_surface` set it.
- The three wind turbines on the ridge south of the lake are `WindTurbineBuilder.gd` (tower, nacelle, rotor,
  saved as `generated/lakeside_turbine_*.res`) and `WindTurbine.gd` (turns the rotor, flashes the beacon).
  The rotor faces +Z and turns clockwise seen from there, as real ones do, and the blades are built for it:
  rings of a cambered airfoil with normals from its cross-section, leading edge on the side they move toward,
  flat side to the wind, twist turning the leading edge upwind, coned upwind away from the tower. The beacon
  and the anemometer mast stand on the roof (`nacelle_roof_y`). `res://scratch/turbine_preview.gd` (`-s`,
  windowed) renders one in seconds: `-- <dir> [spin=40] [angle=30] name:x,y,z:tx,ty,tz[:frames[:gap]]`.
- The AI's shortcut is laid by `_lay_shortcuts` (`SHORTCUTS`: [node, s0, s1, leave, join]): a cubic from the
  lap's centreline at s0 across the inside of the bend to s1, its end handles turned from the lap's heading
  toward the chord by `leave`/`join`, so it parts at about 27 degrees and merges at about 22, on the ground
  (on the road near its ends). The woods (`alts`) and boulders (`_on_shortcut`) keep off it. It removes any
  `AlternativePaths` child not listed (and drops it from Level's exported `alternative_paths`): the hand-drawn AlternativePath2 (s 506-622) was a jump off the high road
  onto the island inside that bend, the tilted wooden cart FBX its ramp. The island lies 5-22m under the road
  except for 70m of gentle bend, so there is no cut to drive there. `res://scratch/lakeside_bank_profile.gd`
  (`-s`, `-- <s0> <s1> [lats=-20,...]`) prints the ground beside the road against the road's height.
- Fences, crowd barriers and tyre walls stop where the ground falls away (`_trim_run`: within `RUN_MAX_DROP` of
  the road's height and under `RUN_MAX_SLOPE`, pieces of at least `RUN_MIN`); they had run on down the banks
  round the start. The generator prints what each run left out.
- The woodcutter's yard inside the bend after the hill and the marquee by the far woods are `VenueKit.gd`
  (life size through the PropKit, at PROP_SCALE): a hay cart with spoked wheels and a bale, a stack of felled
  logs between stakes, a saddle-notched log cabin (stone footing and chimney, shake roof, gables on the end
  walls, shuttered windows, a bench, a woodpile), and a 6 x 6m pagoda marquee with beer
  tables. The chopping block and its axe are gone (`woodpile` still burns their random draws, so the yard stays put). They replaced three Hunyuan FBX (a cart, logs, a festival tent) that stood 2-3 times too big and are
  deleted. `_build_venue` removes the old nodes (`OLD_FBX`) and places each prop with `_free_spot`: the nearest
  place to `YARD`'s point clear of the road (`_verify_clear`'s rule), the shortcut and what's noted, level to
  within 0.9m and not down a bank. Timber is `hut_wood.gdshader` (keys "timber", "lapboards", "battens",
  "painted"; not "boards", which is the sponsor boards' key), round logs `tree_bark.gdshader` on their own
  surfaces (oak bark, or `_logwall_material`'s pale debarked logs).
- The paddock's gazebos and team tents are grown (`GAZEBO_GROW`, `TENT_GROW`, on top of PROP_SCALE; their
  furniture isn't) so a race car fits on a display table (`VenueKit.display_table`). `SHOW_CARS`, the lighter
  models, stand on every other gazebo's table and in each team tent at race size (the other tables hold a
  charger and the toolkit; the small RC buggies and transmitters are gone): `_show_car` lays the car's
  scene out again (its Model node and its meshes, the same `.res` files) under a `DisplayCar.gd` node, which
  applies the car's factory paint at load. Their meshes stop drawing at `SHOW_CAR_RANGE` (130m): a car is
  37-51k triangles.
- The bend round the woodyard (s 465-690, a 125 degree left-hander over both arms of the lake) is a banked board
  track (`_build_banked_turn`, `BANK_*`): a timber deck over the road from curb to curb, flush with it at both ends
  (2cm up), tilting about its inner edge to 17 degrees through the corner (the outer edge 4.9m over the road), with
  painted bands (a blue apron, black, red and blue lines: vertex colour, alpha the paint) and the planks, nails and
  rubber line drawn by `board_track.gdshader` (UV in world metres: x along the lap, y across). The deck is its own
  body `BankedDeck` (road, `surface` wood); the boarded wall along its top (sponsor boards inside, posts and battens
  outside, down to the road's edge so nothing gets under the deck) is `BankedWall`. Both hold their meshes, so
  DressingColliders leaves them alone. An AI race (speed=2) ran it with no falls. `res://scratch/lakeside_bend_probe.gd`
  (`-s`, headless, `-- [s0=] [s1=] [step=]`) prints a stretch of the lap's heading, radius, heights and gates.
- The rowing boat on the lake north of that bend is `RowboatCSG.gd`: modelled in CSG at life size (a lens of two
  upright cylinders for the plan, an elliptic cylinder for the bilges, tilted boxes for the bottom's V, long
  cylinders for the keel's rocker and the sheer; `_hull(g)` grows the solid so the same build gives the planking's
  inside, the boot top, the strake and the keel). The generator builds the tree, waits a frame and bakes it
  (`RowboatCSG.bake`: the placeholder materials named "key:colour" become the level's materials, the colour goes into
  the vertex colours, UVs in metres along the boat), so the level holds no CSG. Placed at `BOAT_AT`, `BOAT_SCALE` 2.
  `res://scratch/rowboat_preview.gd` (`-s`, windowed, `-- <dir> [csg=1] name:x,y,z:tx,ty,tz`) renders it. It and the
  removal of the stray boat copy and two hay bales (`OLD_FBX`) left the course with no FBX; the only imported model
  left is `LevelDesign/Bush` (`models/trees/bush.glb`).
- Spectators (`_build_spectators`, `CrowdPlacer.gd`: Nyota Stadium's people at PROP_SCALE / 1.86, a European mix
  of skins, `SPECTATOR_SKIN`): two loose rows behind the crowd barriers by the straight (`_barrier_spots`), the
  grandstand about two thirds full (`_stand_frames`, on the seat boards; `STAND_UP_SHARE` of them stand on the
  foot board in front of their seat) and a pair at each show car's table. Only the grandstand's standers wave
  flags (a spot's fourth field, "in a stand", picks `CrowdPlacer.POSE_STAND_FANS`): under a gazebo the flag stood
  up through the roof. `res://scratch/spectator_ground_probe.gd` (`-s`, headless, `-- [level=...]`) checks the
  grandstands' bases and the standing spectators' feet against the ground under them.

- The country round it (`_build_backdrop`, `BACK_*`, `LAND_BEARING`/`LAND_HALF`): past the terrain's rim (it falls into
  the sea from 880m) a ring of ground (`BACK_R0` 830 to `BACK_R1` 3.8km) carries the land on away from the big lake and
  the long bridge (they lie north-west): across `LAND_HALF` either side of `LAND_BEARING` farmland, woods and ranges on
  the horizon, elsewhere the sea and a low far shore, so the stage no longer reads as an island. Inside `BACK_NEAR` it
  takes the terrain's grass material (UVs world xz, as the terrain's), past it vertex colour; solid out to `BACK_SOLID`
  (`CountryGround`). Its woods (`_build_country_woods`, the woods' far stand-ins in 500m cells named
  `TreeDeepFar_country_*`, shuffled) follow the Detail Level through a `JungleDetail` of their own (`CountryDetail`:
  none at Off and Low, 70% at High, all at Ultra; 1.6ms of an M1's frame at 4320x2700 at High). Bloombay's skyline
  (`_build_bloombay`, `BloombayCity.gd`, the harbour's blue glass towers and blocks under tile roofs) stands on a plain
  `CITY_DIST` (2.35km) out on that side, from the other side than Harbor Pier's. The fog runs to `BACK_FOG` (4.6km).
  `res://scratch/lakeside_rim_probe.gd` (`-s`, headless) prints the ground across the rim.
- The lookout tower (`_build_lookout`, the user's `models/lookout_tower.blend`, imported through Blender): the
  best-scoring free spot within `LOOKOUT_REACH` of the road (how far it stands over the ground round it), off every pad
  (`_on_pad`: it first stood among the upper camp terrace's motorhomes, which note no footprints) and at least
  `LOOKOUT_FINISH_CLEAR` (450m) from the finish gantry (the user didn't want it at the start); now on a hill above the
  banked turn. The .blend's ground pad is left out, the glass drawn front faces only; its frame's triangles are its
  collider.
- The playground (`_build_playground`, `ParkKit.gd`, life size at PROP_SCALE) on a pad of its own (`PLAYGROUND_*`,
  graded with the others) `PLAYGROUND_AWAY` past the marquee's anchor, away from the road: a swing set, a slide tower,
  a seesaw, a roundabout, a climbing dome, a sandpit, safety mats, a rail fence with a gate toward the marquee, benches,
  a bin, a fingerpost; children (CrowdPlacer spots at `PLAYGROUND_CHILD` of the size) on the swings, the slide, the
  seesaw, the roundabout and round the sandpit, parents watching and on the benches; box colliders. Its sound: the
  user's `sounds/playground_ambience*.wav` from two corners, levelled by RMS (`PLAYGROUND_RMS`) to `PLAYGROUND_LEVEL`
  at `PLAYGROUND_SOUND_UNIT` metres.
- The south bike loop comes up to the lap: across the inlet beside the lap's own bridge over it on a 115m wooden
  trestle (`TRAIL_BRIDGES`: [path, leg], a leg straight between its anchors, its deck level from bank to bank;
  `_build_trail_bridge`: planks on three stringers, a bent every `BRIDGE_BENT` down to the pond's bed with crossed
  braces, railings; boxes, `PondBoardwalk_*`), 20m from the road's middle, then along the bottom straight 25-30m off it,
  so the riders pass close by the race (the user couldn't see them from the track: the loops had kept 150m off it).
  A bridge leg's far bank may be land of its own: each routed leg is searched in the region its start lies in.
- The paths (`_plan_trails`, `_build_trails`, `TRAILS`: [name, kind, anchors, closed]): two bike loops (`BikeEast` in the
  east country (not "BikeLoop": Level.gd bakes a trimesh under anything named "loop" and PlayerCart counts it as road), `BikeSouth` across the southern meadows, 5.1km, pale gravel) and footpaths (`MeadowWalk` north of the
  lap, `PlaygroundWalk` from the playground's gate onto it, `CampWalk` from the campsite east). Routed by AStarGrid2D on
  a `TRAIL_CELL` grid: solid in and near the water, on the road and its verges (a path may pass only under a bridge
  high over the ground), on pads, footprints and the shortcut, past `TRAIL_REACH`, on ground steeper than
  `TRAIL_MAX_SLOPE`; dearer on slopes, near the road and near ground earlier legs took (so an out-and-back doesn't run
  down one corridor twice). A path's anchors all go to the open region most of them fall in (the lakes cut the land
  into pieces; `_trail_label`), excursions that come back to where they were are cut (`_trail_cut_excursions`), then
  Chaikin and a running mean smooth them. The generator prints overlaps (`_trail_overlaps`), points in the water or on
  the road, and anchors it had to move. Each is a ribbon (`trail_path.gdshader`, COLOR.r the kind: worn earth with a
  grassy crown or compacted gravel, ragged grassy edges discarded, vertices pulled toward the eye like the skid marks
  so it wins the depth test; front faces up: wound the other way it was invisible from above) on the ground, "Trail_*"
  (no collider: DressingColliders' "trail"); the meadow clears its grass under them, and the woods, shrubs and
  boulders keep off them (`_on_trail`). Walkers in ones and twos along the footpaths and benches with people at
  viewpoints (`WALKER_EVERY`, `BENCH_EVERY`).
- Cyclists (`Cyclists.gd`, `_build_cyclists`, `RIDERS` 14, shared between the bike loops by length): each rides its loop
  on the wall clock (LAN peers agree), both ways round in ones to threes, keeping right (`w` of its Vector4), leaning
  into bends. ParkKit's parts at PROP_SCALE: the frame and the rider's body one mesh in its colours, wheels rolling and
  cranks turning with the distance (wrapped in doubles before they become rotations), each leg a thigh and a shin set
  by two-bone IK from the hip to its pedal. An AnimatableBody3D box each (layer 1). Sounds: the user's
  `sounds/bicycle1/2.wav` (rolling, one each in turn) and `bicycle_pedalling.wav`, levelled by RMS (`BIKE_*_RMS`) to
  `BIKE_ROLL_LEVEL`/`BIKE_PEDAL_LEVEL` at `BIKE_SOUND_UNIT`, pitched with the rider's speed; none on a headless server.
- The airship (`_build_airship`, `ParkKit.airship`, `Airship.gd`): a 70m blimp (a lathed envelope, X tail fins with
  rudders, a gondola, engine pods with ducted propellers that spin) with the RC Vibe GP logo on both sides between its
  orange bands (`_airship_logo_mesh`: a patch following the envelope's curve `AIRSHIP_LOGO_PROUD` out, reading left to
  right from each side; `_airship_logo_texture`: images/logo_transparent.png halved, `fix_alpha_edges`, mipmapped, saved
  lossless; alpha blended), flying an ellipse (`AIRSHIP_CENTRE`, `AIRSHIP_RADII`) at
  `AIRSHIP_ALTITUDE` (165m) on the wall clock, banking a little and bobbing. Its engines: the user's
  `sounds/airship_engine.wav` levelled to `AIRSHIP_ENGINE_LEVEL` at `AIRSHIP_ENGINE_UNIT` (120m), about -20 dBFS as it
  passes 165m overhead, no distance low-pass (`attenuation_filter_db` 0): at -38 dBFS and filtered the user heard
  nothing standing under it.
- `res://scratch/lakeside_ascii_map.gd` (`-s`, headless, `-- [cell=20] [x0= x1= z0= z1=] [h]`) prints the level as an ASCII
  map (road, bridges, water, steep ground, the paths, named landmarks) for planning by eye;
  `res://scratch/lakeside_park_shots.tscn -- <dir> [rider=N] [frames=N] [trails=1] name:x,y,z:tx,ty,tz` (windowed)
  photographs a rider, the airship and each path piece where they are right now, cameras kept out of the ground.
- Stats (M1, 4320x2700, `ab_bench`, with other work running): about 25ms at High; the paths, playground, airship and skyline
  under 0.05ms each.

## Pinecrest Ridge (Bloombay GP, stage 2)

- `regenerate_pinecrest_ridge.gd` builds `levels/PinecrestRidgeLevel.tscn` through TerrainGenerator, headless, in
  about 25s. The lap's handles are made collinear in plan, each keeping its length and its rise (so the jump
  lips keep their kick): pairs that disagreed were corners in the road (up to 39 degrees). The summit hairpin
  (`P_SB3`, an 11m arc) and the last corner onto the start straight (a 15m arc through `P_VALLEY_SW` and its
  own entry point) had been bends crammed into the end of a segment, 3.4m and 6m in radius, and the road folded
  over itself there. `res://scratch/pinecrest_curve_probe.gd` (`-s`, headless, `-- [min=12] [s0= s1=]`) lists the
  generator's curve's kinks and tight stretches without building anything; `res://scratch/pinecrest_road_probe.gd`
  (`-s`, headless, `-- [level=]`) checks a saved level: ground over the asphalt, tight corners, legs close in plan
  and dressing standing on the road.
- The generator measures along the closed lap (`_closed_curve`, as TerrainGenerator lays the road): the
  TrackPath stops at its last point, short of the start line, and flowers and shrubs grew on that asphalt.
- The ground is graded to the road at its nearest point in plan (`TerrainGenerator.road_height_from_plan`): the
  3D query asks from the natural ground's height, and where the road is cut into the hillside it found a point
  further up the road (or the switchback leg above). The whole climb was buried, up to 3.4m deep, the asphalt
  showing in islands.
- The forest trail (`TRAIL_GAPS`): from jump 1's landing to switchback 2, and on from switchback 2's paved
  hairpin to the summit hairpin, the climb has no asphalt (road gaps). The ground lies `TRAIL_GROUND` (6cm) under
  the road's surface, painted as a rutted dirt track by `terrain_grass_varied.gdshader` from the ground map; it is
  off-road to the carts and gravel to their tyres. Toward each stretch the asphalt breaks up over the taper and
  `TRAIL_LEAD` before it (`road_crumble.gdshader`: cracks, dirt washed over, pieces discarded so the dirt shows
  through; the tyres carry dirt out of a stretch along two lines). The curbs and the road's side walls stop
  where the taper begins (`curbs_stop_at_gaps`): with the ground that close under the asphalt, the side walls drew
  two thin lines across the dirt.
- `terrain_grass_varied.gdshader` (only this level uses it) also draws bare rock on the steepest faces (the cut
  banks between the switchbacks: `rock_tex`), the forest floor under the trees (`woods_map`, each tree's crown
  shaded in by `_shade_woods`), Ridgecrest's lanes and lawns (`ground_map` B and A), wet silt at the lake's edge
  (`water_level`), and, past the rim, hands over to the backdrop's vertex colours by their alpha. Chevron boards
  stand on the outside of each turn behind its tyre wall (`_turn_between`); they had been on the inside of every
  hairpin.
- Ridgecrest (`RIDGECREST_SITES`, `RidgecrestKit.gd`), a district of Bloombay on the summit's broad back north of the
  summit road: chalets (stone or white-washed ground floor, timber upper floor, a balcony with geraniums, slate or
  shingle roof), the Hotel Ridgecrest (a farmhouse, its barn glazed behind boards, a terrace), the chapel on the
  peak (a copper spire, clocks), concrete-and-timber villas with walls of glass and a pool, glass-gabled houses
  under zinc, the clubhouse pavilion on the lip over the course (coin telescopes), the estate gate. `_plan_ridgecrest`
  runs before `generate_world`: it builds each building once at the origin to measure it and pads it at the
  natural ground's mean under it (`TerrainGenerator.natural_height`). The lanes (`RIDGECREST_LANES`, a drive to
  each house) are painted on the ground, and `_on_lane` keeps the woods, boulders and the summit road's guardrail
  (`_rail_gaps`) off them. Hedges and dry-stone walls, garden trees from the woods' own meshes (`_garden_trees`,
  added by `_build_woodland`), the plaza's fountain, lamps, SUVs on four drives; the names are Label3Ds.
  - A building's floor at its local y 0 lies in the plane of its pad, which the ground is graded to, and flickers
    with the grass: the pavilion's terrace stands `deck` (6cm) up. `_verify_ridgecrest_apart` errors where two
    footprints overlap in plan (the gate's west wall ran through the pavilion terrace's glass balustrade; the
    pavilion moved west). The gate has no pad: `estate_gate` takes a ground lookup, so each pier and each course of
    its walls (at most 1.6m, stepping with the slope) stands on its own ground; set level at the ground under its
    middle, its walls burrowed into the rising ground. It has no gates between its piers, and its slate ("CITY OF
    BLOOMBAY") sits under the coping of the lowest course behind it (the coping had run across RIDGECREST).
    Chevron boards keep off the lanes (`_on_lane`).
  - Furniture is solid: RidgecrestKit's helpers (`table_set`, `parasol`, `bench`, `lounger`, `telescope`,
    `lamp_post`) record boxes in world space from the kit's frame (`_solid`, `solid`), which `_build_ridgecrest`
    adds to RidgecrestBody; carts drove through the hotel's terrace tables (and its raised terrace, now a box of
    its own). `res://scratch/ridgecrest_solids.gd` (`-s`, headless, `-- x,z ... [r=3]`) lists the boxes near a spot.
  - Window boxes (`flower_box`) hold geraniums: zonal ones (a mound of 16-22 leaves, 3-5 round heads of 14-20 florets)
    and ivy-leaved ones trailing down the front (`trail`: 0 on the hotel's box over its name). Every leaf, floret,
    bud and stalk is one quad whose shape `window_geranium.gdshader` draws (UV2.x what it is, UV2.y its sway): the
    scalloped leaf with its notch, dark horseshoe band and veins, the five-pointed ivy leaf, five petals round a
    pale eye. They go into RidgecrestKit's `flora` (and a few coloured quads standing in for them into
    `flora_far`), which `_rc_flowers` commits per building, so each pair's visibility range is measured from its
    building; the two crossfade over `FLOWER_FADE` (95-125m) by tree_lod.gdshaderinc's dither. They draw on a
    random stream of their own. About 158k triangles in all; on an RTX 2060 0.1ms of GPU looking at the district
    (`ab_bench ... cam=... hide=Flowers_`). Lumps of plain colour (boxes, then balls) had read as cubes.
  - The chapel's tower door has a landing and three steps up to it. The residents' four SUVs park in bays beside
    their drives (`_plan_car`: parallel to the lane, clear of buildings, lanes and other bays; a short lane of its
    own, so paved and kept clear of hedges and trees, on a pad graded level a ground cell wider than the car,
    planned after the houses' pads so it wins). The houses stand 0-12m from their lanes, too close to park nose-in:
    the cars had stood across a house pad's graded edge, one end buried. `_verify_car_level` prints the ground's
    rise and fall under each car.
  - Lamp posts (`lamp_post`: a flared cast-iron foot, a tapering shaft with collars, a ladder bar) and the entrance's
    piers carry `RidgecrestKit.lantern` (a cup, four glowing panes widening upward between dark corner posts, glazing
    bars, a roof with eaves and a finial); they had been glowing boxes. The plaza's benches, each with a lamp
    behind it, stand in the gaps between the lanes leaving it (`_rc_plaza` reads their bearings off
    `RIDGECREST_LANES`): on fixed bearings two lamps had stood in the lanes. Lamps along the lanes keep off other
    lanes and drives too.
  - The walls are solid quads, so a window's glass lies just proud of the face inside a casing that stands out (set
    back, it was hidden behind the wall). Glass is `ridgecrest_glass.gdshader` (a made-up reflection in EMISSION, as
    on Nyota's towers; COLOR.a is the curtain); slate, standing-seam zinc and board-formed concrete are
    `hut_masonry.gdshader` styles 6-8; hedges `hedge.gdshader`. `RidgecrestKit.finish` adds the tangents their
    normal maps need. `res://scratch/ridgecrest_preview.gd` (`-s`, windowed, `-- <dir> [only=chalet,...]
    name:x,y,z:tx,ty,tz`) renders every building in memory in seconds.
- The country round it (`_build_backdrop`): TerrainGenerator's edge falloff is off (`edge_falloff`), so the
  ground runs on to the terrain's rim, and past it a ring of ground (`BACK_R0` to `BACK_R1`, inside the race
  cameras' 4000m far plane) carries the island on into wooded foothills and ranges (broad massifs with ridges cut
  into them, highest to the north behind the summit), with a valley to the south-west opening onto the coast,
  where Bloombay's skyline stands (`_build_bloombay`) by the sea. Out to `BACK_SHADE` it is drawn in the terrain's
  own material (saved as `terrain_mat`), then a plain vertex-colour one; inside `BACK_SOLID` it is solid; the woods
  carry on over it (`_backdrop_trees`). Nothing within 820m dips under TerrainGenerator's 1600m water plane. The fog
  runs out to `BACK_FOG` (4.6km) so the ranges show, hazed. Sharp ridged noise alone made a row of identical spikes.
- The far forest (`_build_far_forest`, `FAR_FOREST_*`): from where the backdrop's 3D trees thin out (690m) to 3.3km,
  about 150k impostor trees over the ranges: wherever the backdrop is painted forest (not the meadows, the fields and
  sand by the sea, Bloombay) and up the steep faces short of the cliffs, to a ragged tree line (`FAR_FOREST_LINE`),
  spacing out and growing with distance. Each is a quad whose corners all sit at its foot (the corner's offset in
  UV2); `tree_impostor.gdshader` opens it out facing the camera about its upright and lights it with the crown's
  baked normals. The sprites are the woods' own fir and larch (WoodlandBuilder, detailed meshes, two shapes, five
  bearings each) baked by `regenerate_pinecrest_impostors.gd` (`-s`, **windowed**: run it after changing those
  trees, then regenerate): their own shaders made unshaded into `generated/pinecrest_impostor_albedo.res`
  (coverage-keeping mipmaps, meta `frames`: each tree's frame height and foot) and the normals into
  `..._normal.res`. The pine is in the atlas but not planted: its open crown on a red trunk read as a stick with
  dark blobs. Slope is read over 30m (`FAR_FOREST_SLOPE_SPAN`): over 6m the ridges' fine noise read as cliffs and
  left the mountains bare. COLOR.b is a rank the Detail Level thins by (JungleDetail's `impostor_material`,
  `IMPOSTORS`); DressingColliders skips "impostor". Cost 0.7ms (M1, 4320x2700). `scratch/impostor_atlas_dump.gd`
  (`-s`, headless, `-- <dir>`) writes the atlas out as PNGs.
- The meadow (`_build_meadow`): the Lakeside Meadows' grass (MeadowGrass.gd, meadow_grass.gdshader, MeadowDetail.gd)
  on Pinecrest's own map: thinner under the trees (the woods map), mown on the pads and verges, none on the road,
  the trail, the lanes, in the water, on rock faces, past the rim, or under the footprints, trunks, boulders and
  Ridgecrest's boxes (`_trunk_spots`, `_boulder_spots`, `_rc_boxes`).
- The lake's and ponds' edges (`_build_pond`, `PondKit.gd`, at `POND_SCALE`): bulrush stands from the shallows up
  the wet bank, soft rushes and yellow flag irises on the bank (`dune_grass.gdshader`), rafts of water lilies
  floating 0.6-2.6m deep near a shore. Named "PondGrass"/"PondLilies", so DressingColliders leaves them soft.
- Cost (M1, 4320x2700, `ab_bench` samples=6): 20.9ms in all; the meadow 3.9ms (MeadowDetail scales it), the backdrop
  0.44, Ridgecrest 0.17, the pond plants 0.06 (before the far forest's 0.7).
- AI races (`scratch/ai_race_test`, 6 carts) finish every lap at speed 1 and 2. Bots that ran wide at switchback 2's
  exit wedged up the bank (its tyre wall now runs on 34m past the apex); one ran up Ridgecrest's lane where the
  summit road bends (the guardrail's gap is now only the lane and 1.5m a side); one wedges now and then inside
  switchback 4 (969m) and at switchback 1's exit (375m).

## Harbor Pier (Bloombay GP, stage 3)

- `regenerate_harbor_pier.gd` (`regenerate_harbor_pier.tscn`, headless, about 5s) builds `levels/HarborPierLevel.tscn`:
  Bloombay's port at 17:24 on a clear afternoon. The lap, the piers, jumps, skyway, gates and pads are the old layout,
  untouched: TerrainGenerator's `harbor_pier` code still builds the piers, junctions, platforms, ramps, bridges, the
  skyway and the barriers as boxes (their collision), now drawn by `harbor_quay.gdshader` from the world position and
  normal (`mode`: 0 the quays' concrete, decks in slabs and walls with the tide line, a worn yellow coping edge only at
  deck height; 1 piles; 2 the ramps' planks; 3 the bridges' chequer plate; 4 the barriers' chevrons; 5 the land). The
  water is `harbor_water.gdshader` on a 4.4km plane (`HARBOR_SEA_SIZE`, past the fog): ripples in world metres, Godot's
  own sky and sun reflections, lapping where the depth texture says something stands in it. The weather controller
  is gone (its overcast washed the stage out): the sky is `sky_tropical_cumulus.gdshader`, the sun low in the WSW.
- Everything round the lap is under `PortScenery` (props at PROP_SCALE 1.6, `PortKit.gd` and `ShipKit.gd`, both on
  YardKit's helpers and materials). Keep "harbor", "pier", "deck", "road", "track", "ramp", "bridge", "jump", "gate"
  out of its node names (PlayerCart counts them as road) and "Water" (the sea). DressingColliders skips every single
  mesh on this level ("pier" is in the level's name, within its three ancestors), so each prop has its own colliders
  (`_solid`, `_box_shape`, `_cyl_shape`); only the hill trees (MultiMesh) get DressingColliders' trunks.
  - The wharves (`WAREHOUSES`, `STACKS`): brick sheds (`PortKit.warehouse`: pilasters, gables with round vents, roller
    doors, a canopy, the sign band in Label3Ds) and corrugated containers (`PortKit.container`, `shipping_container.gdshader`:
    UV.x carries the face as 100 x its id). Quay furniture (`_build_quay_furniture`) goes only on free edges, read off
    TerrainGenerator's bodies (`_read_quays`, `_free_edges`): water beyond, no barrier, 17m clear of every corner block
    (the racing line cuts their insides), 7m of the ramps, clear of gates and pads.
  - The shores (`_land_d`, `_land_h`, `QUAY_*`): mainland north of z -142, the old town's hill west of x -352, the
    container terminal east of x 268, one heightfield whose grid lines run along the quays (vertical quay walls); land
    vertex alpha: 0 grown, 0.5 asphalt, 1 concrete slabs. The town (`_build_city`, `_add_building`): city_building.gdshader
    facades under tile and slate hip roofs, merged per 450m tile; the harbour front row, the city grid with downtown to the
    north-east, the old town's pastel houses up the west hill. Breakwaters (`WEST_BREAKWATER`, `EAST_MOLE`): granite
    mounds, crown walls, tetrapods and armour stone, the red (west) and green (east) entrance lights, each on a head
    (`_roundhead`, `HEAD_R`, `HEAD_TOP`): a cone of rubble wrapping the mound's end with tetrapods round its seaward half,
    a round concrete block on it (tide line, railing, bollards) the light stands on, the crown wall stopping at it (the
    mound had ended cut off square with the light's foot half over the water). The block's top is 5cm over the
    walkway's and the walkway ends inside its rim: both tops at one height, running into each other, flickered. The terminal:
    the feeder ship BLOOMBAY STAR alongside (`ShipKit.container_ship`, bow north), three ship-to-shore cranes
    (`PortKit.sts_crane`, one boom raised), the yard and two RTGs. The marina below the old town (pontoons, moored
    yachts and trawlers), trawlers at the fish market, boats under way (SeaBoat.gd with the boats saved as
    `generated/harbor_boat_*.tscn`; keep every loop clear of the pontoons, which end at x -278: the inner trawler's
    once ran through the last one), gull flocks.
  - Downtown's towers (`_add_tower`, `_prism`, `_plan_shape`): a podium, then a blue glass shaft (square, chamfered,
    octagonal or round) stepping back once or twice, a plain crown, some with a mast; the city material's far glass
    (`sky_reflect`, `glass_dark`) is blue, as Bloombay looks from South Beach.
  - The cathedral (`PortKit.cathedral`, `CATHEDRAL_AT`) on the west hill, its front facing south over the old town to
    the marina and the south pier (facing east it stood dark against the low sun): twin towers with copper spires, a
    rose window over three portals, nave and aisles with flying buttresses, a transept, a dome on a drum, an apse, on a
    podium with steps (its floor halfway between the ground in front and behind). Parts with no UVs use the plain
    vertex-colour keys "stonetrim", "slatetrim", "copper"; the hut shaders' keys need UVs in metres and tangents.
  - The trees (`_build_trees`) are WoodlandBuilder's oak, lime, birch and spruce (one shape each: eight would split
    every 300m cell eight ways), `Tree_`/`TreeShadow_` near cells under JungleDetail and `Trees_far_` stand-in cells,
    all holding the same shuffled instances so HarborDetail thins them alike.
  - The cruise liners (`CRUISE_SHIPS`, the user's `models/boats/*_CruiseShip.blend`, imported by Godot through Blender,
    so the editor settings' `filesystem/import/blender/blender_path` must be set on every machine that imports the project;
    the .glb copies are gone. 360m, bows toward -z, waterline in the boot-topping band at 10.8m): one at anchor off the
    harbour mouth, one cruising past. `_cruise_scene` merges each file's ~1,500 meshes into one surface per material (turned
    bow +z for SeaBoat; the .blend's `Sea` plane skipped) plus a far mesh without the parts under `CRUISE_SMALL`, past
    `CRUISE_NEAR`. The files were fixed in Blender by `scratch/cruise_ship_fix.py` (`Blender -b <file> --python
    scratch/cruise_ship_fix.py -- backup=<dir>`): a duplicated bow railing (and cap) deleted, every railing set onto its
    deck (they stood 6cm over it, the stepped aft ones 8-10cm out past its edge) with its cap closed onto it, the funnel's
    mast stretched down onto the deck (it hung 1.4m over nothing), and parts lying flush on another (stripes, headers,
    balcony bases, glass on frames, curtains) moved 3cm in front, as a whole along the flush faces' normal, open sheets
    along their own normals (inflating a closed part moved its hidden back faces onto the glass behind). `scratch/
    cruise_ship_audit.py` lists what is left under 1cm (about 50 m2 a ship of the original ~4000: the sports court's glass
    walls on its floor, the stripe's ends at the stern, the promenade's teal accent). Blender's `.blend1` (the previous
    save) is git-ignored. Blender exports every material double-sided and every window pane lies with its back face on
    the wall behind it, so through the semi-transparent cabin glass that back face fought the wall (every window
    flickered): `_cruise_material` (`CRUISE_GLASS`) makes the windows and glazed panels opaque, dark and mirror-like,
    front faces only, and culls the back faces of the railings' clear glass. `scratch/depth_flicker_probe.tscn` on a
    liner's side: 0.02% precision difference.
  - The small craft (`ShipKit.fishing_boat`, `sailboat`, `tug`, their sizes in `TRAWLER`, `YACHT`, `TUG`) share `hull`:
    smooth normals along and up each side (the transom flat), a sheer rising to the bow, bulwarks inside where the sheer
    stands over the deck, `strake` for rubbing strakes and toe rails. Fittings: `deckhouse` (raked front windows),
    `lifelines`, `fender`, `tyre_fender`, `liferaft`, `radar`, `nav_light`; `axis_basis` turns a ring to face along an
    axis. Trawlers moor only on a pontoon's south side (two stern to stern across a gap overlapped).
  - Sound: StageAmbience's harbour layer (`sounds/harbor/harbor_pier_ambiance*.wav`, -30 dBFS) with the town under it
    (`sounds/city/`, -38); only clips in `CLIP_DB` play, so the folder's engine and horns stay out of the bed. SeaBoat's
    optional `engine_sound` (a loop on the hull; the diesel's import loops) and `horns` (a blast every `horn_gap`
    seconds): the trawlers and the tug run the diesel, the tug sounds its horn, the cruising liner the same horns
    pitched down (0.48) heard across the bay; the tug alongside the terminal idles (`TugAlongsideEngine`). Levels from
    the clips' measured RMS (`DIESEL_RMS`, `TUG_HORN_RMS`) to `ENGINE_LEVEL`/`HORN_LEVEL` at the unit size (engines 40-55m,
    horns 160-400m: at 14-20m and -26 dBFS nobody heard them from the track).
  - Wakes: SeaBoat's optional `wake_width`/`wake_spread`/`wake_seconds` lay a ribbon of foam along the way the boat came
    (stern samples every 0.25s in an ImmediateMesh, pre-filled from the clock at load) and a bow wave on the hull,
    `boat_wake.gdshader` (thin broken arms, churn behind the stern, drawn after the water: render_priority 2; its normal
    forced up, or the strip's back came out dark grey).
    `res://scratch/harbor_sound_check.tscn` (windowed) lists the layers and every boat's players.
  - The steel channel bridges (`HarborBridge_*`) drum under the wheels: `BridgeRumble.gd` (`decks`, their boxes read in
    `_read_quays`) plays, for every cart it sees, a synthesised hollow steel rumble that rises with speed, a plate clank
    every `JOINT_STEP` (3m) and a clang over the expansion joint on and off (no recording: all made in code, like
    RailRumble's). `res://scratch/bridge_rumble_check.tscn -- [speed=25]` (windowed) drives a stand-in across and logs it.
  - The jump ramps' barriers (TerrainGenerator, `Rail_Jump*_Takeoff/Landing_*`) stand on the ramps' edges (7.8-8.2m out)
    and reach down past their 0.65m-thick undersides: at 8.2m and from the ramp's top they hung beside it over the water.
  - Signs are Label3Ds with `alpha_cut` DISCARD: blended, the ship's name sorted against the water and lost pieces.
    Anything laid on a wall stands 6cm (life) proud: the roller doors at 2cm flickered against the brick.
- `HarborDetail.gd` (on PortScenery) follows the Detail Level: High draws what the generator built, Ultra the extra
  fifth of the trees and every draw distance 25-30% further, the lower levels thin the trees and armour and pull
  distances in (`base_range` meta on each node; each cell's instances are shuffled). Cost (M1, 4320x2700, `ab_bench`):
  9.5ms GPU along the lap (the trees 1.3ms, boats and liners 0.2ms); Off saves 1.45ms, Ultra adds 0.36ms.
- AI races (`scratch/ai_race_test`, speed=2) finish every lap; the falls are the old ones (jump 2's gap at 862-891m,
  jump 1's, a bot flying the catch rail off the skyway's descent). `scratch/collision_audit ... reach=30` lists only
  gulls, the flag, the sheds' canopies (10m up), the wall fenders and the skyway's hull skirt.

## Arco del Viento (the Canyon Course, Sierra del Viento, stage 1)

The menus call it Arco del Viento (it was Canyon Drift / CANYON COURSE); files and code keep "canyon"
(`CanyonLevel.tscn`, `regenerate_canyon.gd`). Lap records are keyed by the file, so a rename keeps them.


- `regenerate_canyon.gd` builds `levels/CanyonLevel.tscn` from scratch (it used to re-run TerrainGenerator
  over the old 4km lap): 2.5km, half tarmac, half gravel and dirt. The start straight runs down the river's
  west bank past the Parador del Viento, over the Puente (a camel-back through truss), up a shelf road on
  the east wall to La Horquilla, onto the mesa where the tarmac ends, along La Cuchilla (a knife-edge gravel
  ridge, the old course's elevated road with the misty hills behind), down La Bajada (two dirt kickers,
  `_build_kickers`, with shoulders down into the ground each side, `KICK_SHOULDER`) into the
  Valle de los Duendes (procedural hoodoos), through La Garganta (a slot canyon), over the ford El Vado and
  back on tarmac through El Arco del Viento. Regenerating takes about 25s.
- The lap is turtle moves (`PLAN`) with two solved straights (one north-south, one east-west), as on Msitu
  Falls. The river is laid through the plan: through the ford and under the bridge's middle
  (`_build_river`), and the canyon's walls stand at offsets from it (`_river_frame`), so the canyon follows
  the plan. The ridge is tabulated by x (`_build_ridge_table`); La Cuchilla's flanks are its own profile,
  not the mesa's.
- No road mesh: the ground is graded flat under the road (`_grade`: against the true distance to the
  road's polyline; a "beyond the segment end" term times the slot's vertical cut stood the floor up 2m
  round bends) and `canyon_ground.gdshader` paints the tarmac (lines from the lateral in COLOR.a) or the
  gravel, `UV2.y` saying which (it crumbles from one to the other over `PAVED_BLEND`). The bridge deck
  carries the same data and material. Collision is split by surface into `BODIES`, each with a `surface`
  meta and dust colour; roads end in "Road" so they count as track.
- Rock: `canyon_strata.gdshaderinc` (beds by world height, cross-bedded laminations in sets of three beds,
  varnish streaks, grain from `dark_rock.png`) is shared by the ground's cliffs and `canyon_rock.gdshader`
  on the slot's walls, the arch and the hoodoos, so a bed runs on from one to the other. `sand.png` is near
  flat colour and `dark_canyon_rock.png` is pebble rubble (the desert pavement), not a cliff.
  - None of the strata is mipmapped, so each pattern fades to its average by the pixel's size in metres
    (`fw = length(fwidth(w_pos))`, taken outside any branch and passed in): drawn sharp, the laminations,
    partings and streaks shimmered on every distant cliff.
  - Buff and cream beds start at `pale_from` (22m); below it is the red formation. A cream bed along the
    slot's floor read as a dusty smear on both walls. The bed hash (`cs_hash`) is chaotic in float32, so
    which beds come out pale can't be worked out off the GPU: render `ALBEDO = strata_color(...)` to see.
- The slot's walls are meshes standing on a floor graded `SLOT_FLAT` (14.5m) wide, with the heightfield's
  vertical cut behind them. Their feet reach out to 10.6m, so the floor runs a 2.5m cell's diagonal past
  them: at 11m the cut's rising triangles stood in front of the feet. The top row reaches out to
  `SLOT_LIP` (20m), over the trench behind each wall, and tucks under the ground there. The arch is a
  lofted lintel over a steep cutting through a fin of rock (`FIN_*`), its legs down on the cutting's walls.
  `res://scratch/slot_wall_probe.gd` (`-s`, headless) checks that every wall triangle faces the road.
- The river (`_build_river`, `_water_cap`): meanders of 180-300m swing it between the big bends (not near
  the ford or under the bridge, where the road crosses it); it widens round its bends, its deepest line
  swings toward the outside bank, which is cut steep, and a gravel bar shelves up out of the water on the
  inside (`_rv_bend`: signed 1/radius, smoothed). Either side of the ford both banks are broad beaches and
  the bed a shallow riffle (`FORD_DEPTH`); under the bridge it keeps its old gorge (steep banks, 20m
  half width): with a beach there the approach stood on a tall embankment, and an AI cart went off it
  into the river. The shore wanders a few metres on noise. The river is carved
  before the road's grading, so at the ford the road's shoulders ease into the bed. Without all this it
  was a canal: one width, steep parallel banks, a square trench where the road crossed.
  - The water is `canyon_river.gdshader` (not `river_water.gdshader`, which Frostfall Gorge shares):
    silt-laden, tan in the shallows and olive with depth, plumes drifting down it, ripple crests and a
    little foam only where the riffle runs over the bar (by the depth straight down to the bed, from the
    depth texture). `ambient_light_disabled`: lit by the sky's radiance it mirrored blue, so its ambient
    is EMISSION and its reflection is drawn in the shader (sky over a skyline of canyon walls, rock
    below). That skyline is low, gently rolling and blurred: a sharp, wavy one read as a dark wavy smear
    along every far shore. The depth texture is read unfiltered (`filter_nearest`): mipmapped, it
    averaged the banks' silhouettes into deep water. The mesh is a ribbon 12m wider than the river each side (UV in metres), so it reaches past
    every beach's shore; the banks hide the rest.
  - `canyon_ground.gdshader` draws the bars (river cobbles: the pebble rubble half washed out of its red,
    sand drifted between), a dark wet band and a drift line along the waterline, the bed under the water
    (silt over cobbles, greener with depth) and fades the road's paint out under the water.
  - The riverside (`_build_riverside`): reed clumps at the shore (`_reed_clump`, `dune_grass.gdshader`),
    tamarisk and willows on the bars and low banks, cottonwoods on the terraces (WoodlandBuilder's
    `cottonwood` and `willow`, added for this; their leaf material's backlight dulled, the lakeside's
    glowed lime here). It walks both shores, finding each one's waterline on the built ground.
- Dressing (`_build_dressing`): the agaves, yuccas, sotol, brush, flowers and joshua trees are Hunyuan
  models, each reduced twice: a near model (Godot's simplifier, and vertex clustering, `_cluster_reduce`,
  where the simplifier gives up on seamed foliage) and a far one (clustered to a few hundred triangles).
  The cacti and the rocks are built in code (`_build_procedural_dressing`, near and far): the models'
  cacti were smooth green blobs and their boulders stacked pancakes, cairns and grey blobs.
  - `CactusKit.gd`: saguaro (seven arm layouts), organ pipe, barrel, prickly pear, cholla, hedgehog and
    ocotillo, every stem a sweep of a ribbed section along a path, closed by a dome. `cactus.gdshader`
    shades the ribs round (a normal map across each rib from the tangents), puts areoles and spines on
    the ridges (fading to their sheen as they get smaller than a pixel), corks old saguaros' feet and
    varies each plant's colour by its position. The vertex data is documented at CactusKit's top.
  - `SandstoneKit.gd`: blocks (rounded boxes sheared by fracture planes, bedding grooves), pebble
    scatters, and the landmarks (`FORMATIONS`, `_build_formations`): buttes with a talus apron and an
    overhanging cap rock, spire clusters, balanced rocks; each pushed further out if its spot falls in
    the river, by the road or on the Parador's pad, stood on the lowest ground under its foot, solid as
    a convex hull near the road. All drawn by `canyon_rock.gdshader`, so they carry the cliffs' beds.
  - Talus under the cliffs is clusters of blocks; a mix names a species or "block"/"stones" and
    `_variant` picks the shape. Each 96m cell is two MultiMeshes with the same shuffled instances,
    swapping at `DRESS_FAR`'s distance (or `_dress_swap`'s); `CanyonDetail.gd` thins both alike and scales
    the far one's range by Detail Level. Small things cast no shadow. The far terrain is one mesh outside
    the chunker (`canyonfar_ground.res`): cut into 80m cells it was thousands of one-triangle draws.
  - Cost (M1, `scratch/bench.tscn`): about 12ms GPU, 1.54M primitives, 640 draws (the M1's clock moves a
    run's GPU time up to 2x, so compare primitives and draws); the dressing with full models and big
    cells had been 26ms and 13M primitives.
- The Parador del Viento (`_build_parador`, on a pad `PARADOR_HALF` graded level, its near edge 19m off
  the centreline so the pad's blend never reaches the road): a canopy over three islands of pumps, the
  shop, a streamlined diner with a patio, a motel wing and office, a workshop with tyres, drums and a
  wreck, restrooms, a picnic ramada, the water tower, a windmill (`_windmill`) over a stock tank, lot
  lights, CampKit vehicles and Label3D signs, at life size in the pad's frame (x along the road, z away
  from it), grown by `PROP_SCALE`. Every building has a box collider. The dressing keeps off the pad.
- The section signs (`_plan_signs`, before the dressing) each search their stretch, both sides and up to `SIGN_SHIFT`
  either way, for ground level under the whole board, near the road's height, off every leg of the lap and out of the
  water; where there is none (the shelf road, the end of the ridge) the board stays level and each post runs down to
  its own ground. At a fixed 11m out they had one post on the road's edge and the other hanging over a bank or buried
  in a cut. The plants and the power line keep off them (`_landmarks`). The kicker pennants
  stand on the kicker's shoulder or the ground, not at the lip's height.
- The start venue (`_plan_venue`, `_build_venue`, `VENUE_*`), on the river side across from the Parador: CampKit's crowd
  barriers along the verge, CrowdPlacer's people behind them, at and round VenueKit's marquee on its own pad, and along
  the Parador's forecourt edge; and the RC Vibe GP flag (`_build_logo_flag`, a `LogoFlag.gd` node: see "The RC Vibe GP
  flag"), streaming west, the way the windmill faces (into an east wind).
- The Parador's furniture and fittings are `RoadsideKit.gd` (life size through the PropKit, placed at PROP_SCALE): the
  café's patio tables under market umbrellas with chrome diner chairs, the fuel pumps (displays, grade buttons,
  nozzles in holsters, hoses), the islands' bins and squeegee buckets, the ice chest, the gas-bottle cage, a bench,
  picnic tables under the ramada, the air and water post, oil drums and tyre stacks (`tyre_wall.gdshader`, key
  "tyre"; sawn wood is "timber", `hut_wood.gdshader`). They replaced boxes and slabs. The Parador's mesh is chunked,
  and DressingColliders skips chunks, so nothing in it is solid but `_build_parador`'s boxes: every new prop needs
  its own (`collision_audit ... reach=95` lists what isn't; it now tests its sphere at the geometry, not the cell's
  middle, which missed chairs and posts near a cell's corner).
- The power line (`_plan_poles`, `_build_poles`, `LINE_*`) comes in over the plateau west of the canyon from past the
  draw distance, down the west wall (a span whose wires would come within `LINE_CLEAR` of a ledge gets a pole in its
  middle; poles keep off steep ground, `_pole_foot`), turns at the road past El Arco and runs along the verge to the
  Parador: a transformer pole drops to the shop's roof, a guyed dead-end pole by the diner drops to its roof
  (`PARADOR_DROPS`). Guy wires are solid along their guards. It used to stop in the air at El Arco, either side of the
  Parador and before the bridge.
- The Parador's windmill wheel is its own mesh (`_windmill_rotor`) under `ParadorWindmill/BladePivot`, which
  `Windmill.gd` turns (`WINDMILL_SPIN` degrees a second). `res://scratch/canyon_dressing_shots.tscn -- <dir>
  [only=signs,kickers,start,windmill]` (windowed) photographs the signs, kickers, start and windmill from the level's
  own nodes.
- The eagle (`Eagle.gd` on `models/animals/20260717033727_7db23447.fbx`, `EAGLE_SCALE` 6.5: at 10 it dwarfed the
  carts) swoops onto a cart matching its velocity, then holds it on a critically damped spring under the talons
  (`_follow_talons`, `carry_follow_rate`) while the climb eases in (`lift_time`, `carry_turn_rate`); the cart's model
  hangs and swings under it (`_process`). It used to snap 3m above the cart and jerk the cart up into its grip in one
  frame, and its clearance ray (from 40m up, carts included) lifted it onto the gantry, checkpoint banners and the cart
  it held; now the ray starts just over it, skips carts, and near a cart steers the climb (`soft`, `look_ahead`).
  `res://scratch/eagle_carry_test.tscn -- [seconds=150] [shots=<dir>]` (headless, `--fixed-fps 60`; windowed for
  shots) races the AI with the eagle hunting at once and prints each hunt's largest step and acceleration per phase
  (a smooth carry stays under about 300 m/s^2; the old snaps were thousands). It skips its setup in the generator:
  its wing pivots and sound players were saved into the level, and at runtime the model's own wings came
  back beside them (two eagles, one inside the other). Its wings (`part_4`, `part_7`) hinge on the body's
  long axis; each one's angle in the model (a steep V) is measured and lowered to `glide_dihedral_deg`.
  Soaring it beats in bursts; in the dive (a stoop) the wings are drawn up; grabbing and carrying it
  beats hard, the downstroke 40% of the beat, the wing twisting through it. It banks into turns. A cart
  at `escape_speed_share` (0.88) of its top speed outruns it: never picked, and a dive breaks off.
  `part_8` (a stray feather over the head) is hidden. `res://scratch/eagle_preview.tscn -- <dir> [yaw=]
  [pitch=]` renders the wing poses through a beat.
- `res://scratch/lap_shots.tscn -- <level> <dir> [every=N] [s=<m>] [high=1] [clock=<s>: every Train held]` renders chase views along any
  lap; `scratch/canyon_props_preview.gd` (`-s`, windowed, `-- <dir> set=rocks|forms|cacti [far=1]
  name:x,y,z:tx,ty,tz`) renders the cacti and rocks in memory in seconds; `scratch/dress_list.gd` (`-s`,
  headless, `-- [match=Near_saguaro] [count=8] [max=60]`) lists where a level's MultiMesh dressing stands
  (to aim a camera at it); `scratch/asset_sheet.gd` (windowed) a contact sheet of a model folder;
  `scratch/lod_probe.gd` and `scratch/asset_survey.gd` (headless) a model's LOD chain and triangles/textures.

## Frostpeak Creek (Svartfjell GP, stage 1)

- `regenerate_frostpeak_creek.gd` builds the lap, terrain, bridges, shortcuts and gates; `regenerate_frostpeak_dressing.gd`
  (`regenerate_frostpeak_dressing.tscn`, headless, about 10s) dresses the saved level and must run after it. Each run replaces
  `FrostpeakDressing`, sets the materials below again and first deletes its own `generated/frostpeak_dress_*` (after loading
  the level, which points at them). The terrain's shape and the lap are untouched. Before it the stage was a flat white
  material, an empty `Vegetation` node and fog closing in at 520m.
- The ground (`frostpeak_ground.gdshader` on Terrain_Visual): wind crust and drifts, the plough's grey spray and a brighter
  windrow along every road's edge, needle litter under the woods (`_bake_ground_map`: R the distance to the nearest road's
  edge, G the woods), shore ice and wet stones at the waterline, and on steep faces grey gneiss in 3D cellular blocks,
  drill-hole grooves within about 10m of a road and curtains of frozen seepage. Steepness is the steeper of the vertex and
  the face normal (the grid stands up in spikes against the road walls). The rock is in a dynamic branch that takes no
  derivatives (the face normal is worked out before it).
- The road walls (`frostpeak_wall.gdshader`, `WALLS`: Visual_Road_Sides and the shortcuts' embankments): granite ashlar in
  world space with frost on each course. They had the asphalt's darkened texture, which read as brown earth once the fog
  stopped hiding it. Their vertex normals lean up toward the road, so the shader takes the face's own facing.
- The overpass (`_build_overpasses`): where the Jump 2 approach crosses the start straight TerrainGenerator draws nothing under
  the road, and from below the curbs' 17m ribbon was a white slab. A concrete soffit with girders and fascias goes wherever the
  road mesh stands `OVERPASS_CLEAR` over the ground on its line and both curbs, outside TerrainGenerator's timber-bridge zones.
- The fjord (`_build_backdrop`): the island stands in a fjord running north and south (`_fjord_axis`, `_fjord_half`: narrowing
  to its head at `FJORD_HEAD_Z`, opening toward the sea in the south), its walls rising from the shore to shoulders and peaks,
  and at its head Svartfjell (`SVART_*`), a black horn with concave faces, four ridges and three shoulders, straight ahead down
  the start straight. One polar ring from under the island's rim (`BACK_R0`) to `BACK_R1`, 720 round, in `BACK_SECTORS`
  meshes `BackdropGround_n` (DressingColliders skips "ground"), drawn by `fjord_mountain.gdshader`: snow by slope, couloirs,
  forest up to a ragged tree line, wet rock and an ice rim at the water's edge, the bed dark; vertex colour g is how black the
  rock is. Every pattern is world-space (3D) noise: coordinates turned with the normal swirled like marble, and snow on
  ledges across the faces read as brush strokes. `_svart` returns -500 off its foot: at 0 the smooth maximum that sets it into
  the fjord lifted the whole bed to the waterline and the fjord read as a snowfield (`kronburg_hide_shot ... hide=` showed
  it). TerrainGenerator's water plane is stretched to 9km, its edge fade off and its finish darker and less metallic (at
  metallic 0.65 the deep water mirrored the pale sky and read as ice). The fog runs out to `FOG` with curve 1.8.
- The woods (`_plan_woods`, `_build_woods`, `SnowTreeKit.gd`): about 4,100 snowy spruce (Frostfall Gorge's, copied into
  the kit) on the flanks and 1,330 bare winter birch (WoodlandBuilder's birch with `twig_atlas()` sprays through
  `winter_twigs.gdshader`) by the creek and on the woods' edges. Crowns keep `TREE_CLEAR` off every road's edge, out of the
  water, off steep ground and mostly out of `RESERVED`: the start's west side (for a race venue), the south shore (the
  village) and the view to it from the south loop. Saved as the Detail Level's Ultra draws them: every tree, the rich spruce (Frostfall's full tree and stand-in),
  the detailed trees casting their own shadows. `SnowWoodsDetail.gd` draws less below it: a share of the trees by rank
  (`TREE_SHARE`: Off 1,520, Low 2,180, Medium 2,900, High 3,570; trees by the roads rank low, `RANK_NEAR_ROAD`, and go
  last), the light meshes (a cell's metas `rich_mesh`/`light_mesh`; a stand-in of 6 flat whorls read as a bare pole, so the
  light one has 8), shadows from the TreeShadow_ stand-ins. Each cell's instances are in rank order with the ranks in its
  meta `ranks`, so the near, far and shadow cells (which group trees differently) draw the same trees; the trunk colliders
  within 40m of a road (meta `rank`, reaching 0.7 of the skirt) switch off with them. `spruce_fronds.gdshader`'s
  `snow_cover_shift` (0 for Frostfall) leaves the dark needles showing between the snow.
- Svartvik, the fishing village on the south shore (`_plan_village` before the woods, `_build_village`,
  `FjordVillageKit.gd`, life size at `PROP_SCALE` 1.6 through YardKit's kit plus a plain "snow" key): painted timber houses
  (`house`: battens, white trim and corner boards, a gabled porch over the door, slate under snow, a chimney) every
  `HOUSE_STEP` along both sides of the street (`LANES[0]`, trodden snow in the ground map's B), each skipped where its
  footprint is near a road (`VILLAGE_ROAD_CLEAR`), in the water, too steep (`HOUSE_MAX_DROP`, else a stone foundation takes
  up the fall) or taken; a white long church on the east terrace (`CHURCH_AT`, its axis along z, the tower and spire at the
  north end toward the lap); rorbuer on stilts and tarred boathouses (`naust`) along the waterline (`_shore_z`, `SHORE_X`); a
  timber quay at `QUAY_X` with two ShipKit fishing boats, one rafted outside the other; stockfish racks (`hjell`);
  woodpiles and kick-sleds (`spark`) by the doors; wood smoke from every chimney (`_build_smoke`, one GPUParticles3D each,
  shared material). Batched by 120m of x into `Svartvik_n` meshes, which DressingColliders makes solid; the trees keep off
  the buildings and lanes (`_in_village`) and thin out in `RESERVED`'s view from the south loop. About 70k triangles, 0.1ms.
  `res://scratch/fjord_village_preview.gd` (`-s`, windowed, `-- <dir> name:x,y,z:tx,ty,tz`) renders every building on a flat
  snowfield in seconds. A generator scene whose script fails to parse sits idle instead of quitting: check new code with
  `res://scratch/parse_check.gd` (`-s`, headless, `-- res://a.gd ...`) first.
- Cost (M1, `ab_bench`, 1280x720 window): the woods about 4ms at High; Off -3.4, Low -2.3, Medium -0.95, Ultra +7.2 (its own
  tree shadows about a third of that); the fjord 0.5ms. Separate `bench.tscn` runs of one level drifted between 16 and
  21ms on the GPU's clock alone: compare with ab_bench.
- AI races (`scratch/ai_race_test`, speed=2): every bot finishes three laps; the falls (off the Alpine bridge at 509-515m,
  and at 1270m) happen on the undressed level too.
- `res://scratch/meshes_at.gd` (`-s`, headless, `-- <level> x,y,z ...`) lists the meshes whose bounds hold a point;
  `scratch/kronburg_hide_shot.tscn` takes `level=`; `res://scratch/terrain_height_grid.gd` (`-s`, headless, `-- <level>
  [cell=50] [half=450]`) prints a level's terrain heights round its lap.

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

## Glacier Highway (Svartfjell GP, stage 2)

- `regenerate_glacier_highway.gd` (`regenerate_glacier_highway.tscn`, headless, about 20s) builds
  `levels/GlacierHighwayLevel.tscn` from scratch: the trunk (a closed figure of eight at 2.8m and 16.5m, through the
  tunnel and back over it on the high overpass), three ramps (the Express Flyover, the Gorge Cut down through the
  crevasse, the Ridge Bypass), the valley heightfield and the tunnel's massif. `regenerate_glacier_dressing.gd`
  (`regenerate_glacier_dressing.tscn`, headless, about 10s) dresses the saved level and must run after it.
- Dusk (`DUSK_*`, `sky_tropical_cumulus.gdshader`): a deep blue overhead, a warm glow low on the sun's side (SSW, 4.5
  degrees up), rose-grey clouds, blue snow in the shade and alpenglow on the peaks; the ambient and exposure are low
  enough that the streetlights' pools read (`_build_highway_streetlights`: every 42m, an emissive head and a
  SpotLight3D, `no_shadow`). A first pass at pinker, brighter values read as lavender. The sign gantries are gone (the
  user didn't like them).
- Barriers: the Jersey barriers are drawn; their collision is an upright wall `PARAPET_H` high, `PARAPET_INSET` in from
  the deck's edge, in a body of its own (`<Road>_Parapets`, not track): as the profile's own trimesh it was a ramp the
  cart's sphere rode up and over, and the AI's line checks skip track. Full height to their ends. Beside a ramp the
  trunk's barrier opens only where the ramp's deck reaches `GAP_OUTER_MIN` past the trunk's edge
  (`_junction_gap_intervals`), and the ramp's outer barrier rises just before that: the ramps leave and join along the
  trunk's edge, and the Ridge Bypass's centreline hugged it for 20m with its deck centimetres wide there, the trunk
  standing open over a 16m drop that bots cut straight across. `scratch/wall_ray_probe.gd` (`-s`, headless, `-- <level>
  dir=x,z len= y= x,z ... [line=x0,z0,x1,z1,step]`) casts horizontal rays across a road and names the walls it meets.
- The ground under an at-grade deck (`_apply_road_corridors`) lies `DECK_FILL_UNDER` (0.32m) under it, out to
  `DECK_FILL_OUT` past its edges, graded to each road's nearest point (a ramp's at its deck's height: it is lifted up to
  0.35m toward the trunk's where they tile). On the old shelf, 0.73m under the deck's thin collision (the cart's sphere
  is 0.75m in radius), a cart beside a deck slid in under it and jammed (the finish straight, the tunnel's mouth); in
  the Gorge Cut it was pushed out through the ground. The crevasse's floor is the same height under its road.
  `scratch/ray_stack_probe.gd` (`-s`, headless, `-- <level> x,z ... [line=x0,z0,x1,z1,step]`) lists everything a vertical
  ray meets, top to bottom (one body's surfaces count once: the trunk's overpass hides its deck under it).
- The bots' paths over the ramps (`_ai_route_curve`, the AlternativePaths) are not the ramps' centrelines: in the
  trunk's outer lane until the trunk's barrier opens beside the ramp, then `AI_ROUTE_EDGE` inside the ramp's widening
  outer edge, then its centreline. Each carries `ai_lane_ends` (`_ai_lane_ends`: the metres at its start and end beside
  the trunk), and PlayerCart holds a bot to the path's line there (`AI_LANE_ENDS_HOLD`). Kept half a ramp inside the
  paving the path moved out at twice the ramp's rate, and bots met a 70 degree turn at the Gorge Cut's split, braked
  and slid back onto the trunk. `scratch/alt_path_lateral.gd` (`-s`, headless, `-- <level> [step=4] [max=80]
  [only=<name>]`) prints a level's shortcuts' lateral from the lap and height over it along their ends.
- The valley opens to the south (`VALLEY_OPEN_Z` in `_alpine_height`) and a carriageway runs on down it, only to be
  seen (`FAR_SOUTH`, `FarHighwaySouth`): from the turnaround the highway reads as going somewhere, not an oval. It is
  being carried on north over the turnaround: its near end is a new viaduct climbing to 16.5m and stopping in the air
  south of the hairpin (no barriers or lamps on its last `FAR_BARE` metres, no pier under its last `FAR_TIP_OVERHANG`,
  lamps from `FAR_LIT_FROM`), and the dressing builds the works (`_build_works`, `Anlegg`): a form traveller, the next
  segment's formwork and starter bars on each deck end, the next pier past the gap in the hairpin's infield with its
  balanced cantilever (`WORKS_T_*`), a pier with only its crosshead, one half poured, a footing with its cages
  (`WORKS_PIERS`), temporary railings, BaustelleKit's tower crane (its top slewing over the gap, SlewHazard.gd,
  harmless; on a 40m mast (life), since BaustelleKit's load hangs 17.6m under the jib and on 30m it swung through the
  bridge's formwork and the spruces: `scratch/crane_clearance_probe.tscn` (headless) prints the load's height against
  the tallest thing under the jib's swing), yard and machines at PROP_SCALE, floodlights and a board (SVARTFJELLVEGEN,
  made up). Every piece keeps
  `WORKS_LAP_CLEAR` from the lap and the ramps (`_check_works_clear`); the trees keep out of `WORKS_KEEP`. It had ended
  on the ground behind a barrier, joined to nothing, and the user disliked it. The bridge pieces are at game scale, so
  BaustelleKit's `uvk` is set by calling `new_kit` again for each scale. `scratch/glacier_height_map.tscn` (headless,
  `-- [cell=40] [x0= x1= z0= z1=]`) prints the natural ground with the lap and ramps marked.
- The dressing (`GlacierDressing`, every run replaces it and deletes `generated/glacier_dress_*` first):
  - The country (`_build_country`): rows of ground step out from the 1.1km heightfield's edge (the first on its edge's
    own vertices) carrying the generator's `_alpine_height` (an instance of its script, not in the tree) on into far
    ranges (`COUNTRY_BLEND`), the valley open down the far highway; drawn in the valley's ground out to `NEAR_D`, then
    in `fjord_mountain.gdshader`; solid out to `SOLID_D`.
  - The ground: `frostpeak_ground.gdshader` on the valley, the massif and the near country (its own ground map),
    `snow_slope` 0.62 (the walls lie near 45 degrees: at Frostpeak's 0.7 whole hillsides came out mottled), and two
    uniforms added for it whose defaults leave Frostpeak Creek as it was: `face_weight` (0 on the country, whose
    triangles are tens of metres across and turned to rock one by one), `block_shade`/`fine_blocks` (smaller,
    quieter rock blocks on the massif's faces over the overpass).
  - The woods: SnowTreeKit's spruce and birch (about 3,400) on the lower slopes, off the roads and steep ground,
    SnowWoodsDetail thinning them below Ultra, as on Frostpeak Creek.
  - The glacier (`_build_glacier`, `GlacierTongue`, `glacier_tongue.gdshader`): a side valley cut into the north wall
    behind the basin (the highway generator's `glacier_trough`, applied by `_alpine_height` and by the country's
    `_country_h` after its blend, so it runs on into the ranges; `_alpine_base` is the ground without it): steep walls on
    a broad floor (`glacier_floor`: a gentle tongue, the icefall up the wall, the firn basin, `GLACIER_SLOPES`,
    `GLACIER_ICEFALL`), winding (`glacier_axis_x`), widest at its mouth (`glacier_half_w`). The ice is a convex sheet on
    the floor, its margins tucked under the walls, thickening from a rounded, dirty snout; seracs heave up in the icefall
    (COLOR.r), firn lies up high (COLOR.g); the shader draws the crevasses (in the icefall and along the margins only:
    across the whole tongue they read as zebra stripes), ogives, a medial moraine and the margins' rubble, each fading by
    the pixel's size. Seen from the lap down the run-out north of the tunnel, filling the notch between the peaks.
  - The avalanche gallery (`_build_gallery`, `GALLERY_*`): 65m of cut-and-cover gallery over the lap where it runs
    south in its cutting on the east flank: a wall on the uphill side (found from the natural ground, `_alpine_height`:
    raycast through the colliders it came out mirrored), a roof slab on columns on the valley side with an edge beam,
    lamps and lights under it, and the snow on the roof running on up the slope (the ground's material with a ground map
    as if far from any road: over the road its map painted the plough's grit on it). The roof's underside is
    `GALLERY_CLEAR` over the road, the tunnel's; roof, wall and columns are solid boxes (`AvalancheGallery`), so the race
    camera comes down under it as in the tunnel. The streetlight that stood up through the roof is taken out.
  - Snow poles (`_build_snow_poles`, `SnowPoles_*`): plough markers every `SNOW_POLE_STEP` just behind the barriers
    wherever a road runs at ground level, in MultiMesh cells ("pole": DressingColliders makes them rigid posts).
  - Svartfjell Fjellstue (`_build_rest_stop`, `LODGE_*`, made up): a mountain lodge in Falu red and its annex
    (FjordVillageKit), the lot with cars and a motorhome (CampKit), ploughed snow round it, picnic tables (RoadsideKit),
    lamp posts (YardKit) and lights, on the pad the highway generator levels (`PADS`, `_apply_pads`) on the valley floor
    east of the tunnel's approach, seen from the overpass, the tunnel's approach and the express flyover. Its name is on a
    lit board standing on the front roof slope (`_lodge_signs`, `LODGE_SIGN_*`), KAFE on a blade by the door between
    the floors (`LODGE_BLADE_*`): on the wall between the window rows the name ran across the windows.
- PlayerCart respawns a bot off the course for `AI_OFF_COURSE_GIVE_UP` (15s) at its last checkpoint: one in the
  Gorge Cut's old crevasse kept moving and so never counted as stuck.
- AI races (`scratch/ai_race_test`, speed=2, `noitems=1`): 1-3 falls a race (round the Ridge Bypass's split and its
  descent, 1340-1460m), flying laps 46-49s; before this work 10-16 a race (the finish straight under the deck, the
  Ridge Bypass's split, the Gorge Cut's split and merge, the tunnel's mouth), 57-63s. `scratch/shortcut_probe ...
  chance=1.0` sends every bot over every ramp.
- Cost (M1, 1280x720 window, `ab_bench`): 19.9ms on average at High; the works 0.42ms, the gallery, the glacier, the lodge and
  the snow poles under 0.1ms each.

## Curbs

`curb_stripes.gdshader` draws the red/white kerb only where the curb mesh's vertex colour red channel is
1 (corners), and a plain white kerb elsewhere. TerrainGenerator writes that weight
(`_apply_curb_corner_weights`) when it builds the curbs. To update the saved curb meshes of every level
without regenerating them, run `res://refresh_curb_corners.tscn` headless (Lakeside, Mountain Pass, Bloombay,
Pinecrest and Frostpeak are the levels with these curbs; Mountain Pass's had no weights at all and was striped
all round).
- A metre is in a corner when the `CURB_CORNER_SPAN` (60m) centred on it turns `CURB_CORNER_TURN` (30 degrees) or
  more in plan; each corner runs on `CURB_CORNER_LEAD` (10m) into its braking zone and exit, corners closer than
  `CURB_CORNER_JOIN` (12m) become one kerb, and the transitions snap to whole stripe pairs. The old rule (a radius
  under about 105m over a +-8m window) striped gentle sweepers and left real corners in fragments, and joining
  over 30m made Pinecrest's hairpins one 420m kerb.
- Each side is weighted apart, as on a circuit: the inside where the corner measures as one, the outside from the
  apex out through the exit (where the turn in the 30m behind outweighs the 30m ahead). A right-hander turns the
  heading's angle `atan2(z, x)` up and its inside is the right of travel (`_path_right`: UV.x past the curb mesh's
  middle). Striped on both sides from braking zone to exit, a corner read as a painted lane.
- `res://scratch/curb_corner_probe.tscn -- [level=...] [turn=35]` (headless) lists each level's striped runs (how
  far the lap turns over each) and its real corners with how much of each is striped.
- Inside a corner sharper than the road is wide (Lakeside's first corner, a single point), the inner offsets of the
  slices before the apex run on past where the two legs' inner edges meet: the curb lay across the other leg's
  asphalt as a red and white spike. `_create_path_visual` and `_create_path_sides` leave out every curb and side-wall
  segment whose inner edge (the wall's top) lies on another stretch's asphalt (`_on_other_asphalt`: nearer its
  centreline than the road's half width, at about its height), tested only where the heading turns more than
  acos(`CURB_FOLD_TURN_COS`) over `CURB_FOLD_LOOK` either side. Applies on each level's next re-bake.

## Road gaps

`TerrainGenerator.road_gaps` ([s0, s1] pairs along the curve, default roads only) leaves stretches of a lap
with no road. `_road_gap_width(offset)` scales the asphalt's half width, the curbs' inner edge, the road sides
and the road collision to 0 over `road_gap_taper` before each gap and back after it, and `_segment_in_gap`
drops the segments where it reaches 0. `_road_gap_ground` grades the ground (visual and collision) along the gap
and both tapers to `ROAD_GAP_GROUND` (18cm, under the curbs' outer edge) below the road's surface, easing
back 6m past them. PlayerCart's corridor rule (terrain within the road's half width counts as road) skips the
gaps and tapers (`_in_road_gap`), so the ground there is grass, off-road, with its sound and dust.
- A level's `Surfaces.LEVELS` entry can name what that ground is (`"gap"`: Pinecrest Ridge's forest trail is
  gravel; PlayerCart's `_on_road_gap_ground`, `Surfaces.of_road_gap`).
- `road_gap_drift` (per gap, in `road_gaps`' order) heaps a mound across a gap, highest in its middle, easing to
  nothing at its ends: Bloombay Dunes' sand drifts over the road.
- `road_gap_half_width` grades a gap's ground out to that far either side of the line (at least the curbs' outer edge),
  easing back over 6m: the Lakeside loop's platform is wider than the road.
- `curbs_stop_at_gaps` ends the curbs and the road's side walls where a taper begins (instead of following the
  asphalt down to its point) and eases the gap's grading in inside the taper, so `road_gap_ground` (default
  `ROAD_GAP_GROUND`) can bring the ground up to a few centimetres under the asphalt: Pinecrest Ridge, 6cm.

## TerrainGenerator's bridge pillars

`generate_bridge_supports` (on by default) stands a concrete pillar with a box collider every 30m wherever the road's
curve is 5m over sea level (`_generate_bridge_supports`; MOUNTAIN and CANYON layouts skip it). That suits a bridge over
water and nothing else: on a dune or a hillside the pillar stands buried under the road. Off on Wadi al-Ghaf,
Frostpeak Creek, Pinecrest Ridge and Ramlat Hamra (one poked out of a dune crossing, which is bare sand). Lakeside's 68
are its long bridge's piers but 12 on the climb to it, Bloombay Dunes' 32 are all under its dune road: under paved road
they don't show. `res://scratch/bridge_support_check.gd` (`-s`, headless, `-- <level>`) lists a level's pillars with
the natural ground under each (`natural_height`, the ground before the road is graded in) and which hold nothing up.

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
  a sign gantry. Lower hits come from props' collision hulls reaching over the road.
  The rays are nudged off the gate line because a ray straight down a terrain grid line can miss.
- The feet's colliders are 2.5m walls. A cart that clips the top edge of a low block gets launched,
  because PlayerCart only smooths edges up to `STEP_SMOOTH_MAX_HEIGHT`.
- Bots are also credited a gate by their progress along the lap's path (`_credit_passed_checkpoints`: they can fly over
  a gate's trigger on a jump), but only once they are past the gate's own plane (`_past_gate`, along the lap's heading
  there, unless more than `PAST_GATE_REACH` from it); a crossing short of it waits (`cp_pending`). Pinecrest's path
  stops 30m short of its start line, so the path's end is the finish's offset: bots were credited the finish 31m before
  the gantry and, finished, braked to a stop short of it. `ai_race_test` prints where each cart finished (`FINISHED`)
  and came to rest (`AT REST`).
- The grid's slot markings (`SpawnIndicator.tscn`, a 2m quad under each spawn point, which hangs off the finish gate's
  node) lie down on the surface under them once the level's collision exists (`SpawnIndicator.gd`: four rays at the
  corners for the plane, looking past the carts on the grid, `LIFT` 3.5cm over it). Placed flat 5cm over the spawn
  point they floated 6-50cm on most stages (Harbor Pier's half a metre) or stood off a sloping grid.
  `res://scratch/grid_ground_probe.tscn -- <level>` (headless) prints the worst gap between the slots and the ground,
  before and after.
- A circuit's TrackPath is closed at load (`Level._close_lap_path`: the first point appended again on a copy of the
  curve, as TerrainGenerator's world curve does for the road) where its end lies more than `LAP_CLOSE_GAP` from its
  start: Tolvanera Gulch's stopped 64m short (bots lost the line there and drove in circles just before the finish, one
  never completing a lap), Pinecrest Ridge's 30m, Mountain Pass's 25m. Every other level's closes (a scan of the saved
  paths found none else).
- `res://scratch/gate_shots.tscn -- <level> <dir> [carts=N] [fov=75] [lap=N] [all=x,y,z:tx,ty,tz]
  name:gate:x,y,z:tx,ty,tz[:step[:scroll]]` renders gates from cameras in gate space (X across the road,
  grid on +Z), with any start-light step (-1 for none) and the ticker `scroll` LEDs along. `lap=` feeds
  the ticker six racers with the leader on that lap.

## Racers who have finished, the commentator's hits, the bots' names

- A racer who has finished is out of the fight: nothing targets it (missiles' locks, the bots' item decisions, the
  eagle), and nothing hits or pushes it (`on_hit`, `apply_blast_impulse`, the lightning's slow, the shockwave, bomb
  blasts; a missile flies on past it, a dropped bomb doesn't go off under it).
- The spectator camera after the player has finished follows the racers still going and, once everyone has finished,
  stays on the last one it watched (`_spectate_fallback`): it went back to the player's own car. The cycle keys skip
  the player's car once all have finished; the number keys still pick any car.
- `RaceCommentator.call_shockwave`: the shockwave's victims (collected on the server, passed with
  `client_play_shockwave`, so every peer calls it) get a line like the missile, bomb and lightning hits; it had none.
- The bots (`BotRoster.gd`): each a different car drawn from every preset (PlayerCart.CAR_PRESETS, the humans' cars
  left out while there are enough) and named after it. In a Grand Prix the line-up is drawn once at the start
  (`NetworkManager.gp_bot_roster`, cleared wherever the GP's standings are) and kept: the standings are kept by name.
  They had always been Viper, Shadow, Apex, Blaze and Nova on the first four cars.

## Announcer

The race calls are `voice/lola/` clips, listed per line with their takes in `MusicManager.VOICE_LINES`.
`play_voice(line)` picks a take at random. Level calls 3/2/1/go in the countdown, and at each gate the
player is counted for (`_play_lap_cue`) the chime `sounds/checkpoint_passed.wav` plus a call: "checkpoint",
"final lap" when they cross the line onto the last lap, "finish" at the line, and then the place if it's
first to third (`_announce_place`). The podium calls each place as it's revealed. In a time trial there is no
RaceCommentator (its "and they're off", the lead, the places) and no place call: one racer against the clock.
- A human who drives on past the gate they need without being counted gets "checkpoint missed"
  (`_watch_missed_checkpoints`, server). It follows the cart along the racing line like the AI's gate
  credit does, and fires as the cart passes `MISS_DISTANCE` (14m; a gate's area is 8m deep) beyond the
  gate. A step along the line over `MISS_MAX_STEP` is a re-sync, not driving (a respawn resets the line).
  Bots don't hear it: they are credited by progress.
  - The racing-line tracker (`_track_cart_curve_offset`) stops following a cart further than `reach` from
    the line and holds its last value (the AI's gate credit wants that: 28m). For humans the watch passes
    `miss_track_reach` (150m): at 28m a wide cut round a gate across the grass lost the line for good (30m
    out was enough; nothing re-found it but a respawn), so there was no call, and the gate after never
    counted because the lap still needed the skipped one. A respawn then put them two gates back.
  - Whatever the tracker says, reaching the gate after the one still needed counts the gate between as the
    one missed (`_count_skipped_gate`, from `_on_checkpoint_entered`, server): `_checkpoint_missed` runs, the
    reached gate counts, and the call waits `SKIPPED_GATE_VOICE_DELAY` (1.4s) for that gate's own. It only
    counts when the cart's nearest point on the lap is within `SKIPPED_GATE_REACH` (40m) of the gate, so a
    gate where the lap crosses itself isn't taken for skipped on the first pass over the crossing. No two
    gates on any level are closer than 53m.
- One gate may be missed (`_checkpoint_missed`): the gate after it becomes the one they need, so catching
  it keeps them in the race. Missing that one too, two in a row, disqualifies them (`_disqualify`: the
  "disqualified" call, the cart drives itself as after the finish, it ranks last as DQ and scores nothing).
  The line on the last lap can't be skipped. Once no human is still racing, the race ends 10s later.
- A bot that drives through a later gate than the one it needs, near that gate on the lap, gets the gates between and
  its racing-line tracker is put on that gate (`_catch_up_bot`): on Mina del Viento's open pit floor one went wide of a
  gate, its tracker lost the line, and it passed every gate after uncounted and drove off the end of the stage.
  Only when it is past the gate it still needs along the lap (nearer having passed it than reaching it): on Mtaa Nights
  the grid stands 20m behind the finish line, every bot drove through it after the green light needing gate 1 and was
  given a lap, and the human ranked last however they drove. `res://scratch/position_probe.tscn -- [level=]
  [seconds=40] [step=0.6]` (headless) carries the human along the lap in a GP against the bots and prints everyone's
  laps, next gate and position every 2s.
- Driving the wrong way (`_watch_wrong_way`, server, humans): velocity against every lap path within 14m
  (`_lap_tangents_near`: where a shortcut crosses the road either way is right) for 2.5s gives "wrong
  way" and an alert chime, again every 7s while it lasts.
- A human's clean lap (no gate missed) faster than the stage's record in `user://lap_records.cfg` gets
  "new lap record" (`_lap_completed`); the first lap ever only sets the record. Laps faster than the track
  at 70 m/s are teleports (tests), not laps.
- `res://scratch/announcer_test.tscn` (headless) walks a player through every gate and lists what was
  said. `res://scratch/missed_checkpoint_test.tscn -- [level] [skip=N]` drives a cart along the line past
  all gates but one (16m wide of its area): the call, the lap still counted, then the wrong way, then two
  gates missed in a row (disqualified). `skip=-1` is a clean lap, which must say nothing. It moves the cart
  a few metres a frame exactly along the line, which is why it never saw the wide-detour failure.
  `res://scratch/human_skip_test.tscn -- [level=] [skip=1] [aside=30] [span=30] [reach=]` (headless) drives
  a real, non-AI cart with the throttle and steering actions, `aside` metres off the line (negative: left)
  round one gate, and prints PASS or FAIL: the call heard once, the lap needing the gate three on. A run in
  which the cart respawns (Lakeside's lakes beside gate 2) is INVALID, so try it on open ground (Mara
  Crossing, `skip=1`: 29m and further failed before the fix, 16m passed). `reach=5` makes the watch lose the
  line at once, to try the reached-the-next-gate fallback alone.

## Water edges against what stands in front

`river_water`, `water` and `beach_water` read the depth texture unfiltered, and where it says something is in
front of the water (a pixel along a silhouette: MSAA, the interpolated camera in motion) they take it as deep
water, not a shore. Clamped to 0 depth, those pixels drew white foam round every bridge rail, hanger and tree
in front of the water while driving (Msitu Falls, Bloombay Dunes). `canyon_river` still clamps.

## Deep water, stage ambience and the sounds

- Deep water (`PlayerCart._set_engine_flooded`): once a cart is under (`is_underwater`, not boosting), the
  engine floods: no drive, the engine sound dies, the cart sinks instead of bobbing, `sinking_underwater.wav`
  plays where it went under and `WaterFx.spawn_bubbles` rises off it (a column cut off at the surface,
  `water_bubble.gdshader`, and fizz on top) until it drowns (2.5s) and respawns. A fall faster than 11 m/s
  (`_entry_fall_speed`, from first touch to going under) sets off `WaterFx.spawn_splash`: a column, spray,
  mist and a foam ring that spreads (`water_foam.gdshader`). FxWarmup holds their stand-ins.
  `res://scratch/deep_water_test.tscn -- <dir> [at=x,z] [height=25]` (windowed) drops a cart and saves frames
  on physics time (the shots stall frames, and physics catches up only 4 steps a frame); `follow=1
  vel=x,y,z pre=0.5,0.8` shoots through the cart's own follower camera, during the fall as well.
- The follower camera's splash shot (`_splash_cam_wanted`, `_splash_camera`): it follows the cart down to the
  water as usual; once the cart is sinking (`_engine_flooded`: under and not boosting) it pulls back fast
  (`SPLASH_CAM_PULL`) to `SPLASH_CAM_BACK` (10m) back along the way the cart was heading (noted while it was
  above the water) and `SPLASH_CAM_UP` (5.5m) over the spot, looking at it, until the respawn or a boost out.
  An earlier version set off as soon as a cart fell fast with water below, and fired for carts that landed
  short. Test harnesses that make an AI cart the local player must set `camera_pivot.top_level` as
  PlayerCart's setup does, or the cart drags the pivot along.
- The stages with a stadium crowd layer (Nyota, Mtaa) roar at the green light and when the first racer finishes
  (`StageAmbience.roar()`, `ROAR`: `sounds/Huge_stadium_crowd.wav`, a 13s swell; Level's `_crowd_roar_rpc`).
  The stages with a grandstand (a node named "Grandstand": Lakeside, Bloombay Dunes, Mina del Viento) cheer at the same
  moments (`sounds/Fans_cheering.wav`), in 3D from the middle of the stand's meshes (`_find_grandstands`): Mina's
  stands at the finish, so only the finish hears it; Lakeside's across the first corner, 150m from the line.
  `res://scratch/crowd_cheer_check.tscn` (headless) lists what each stage plays. Nyota's paper banner cheers too
  when the first cart bursts it.
- `StageAmbience.gd` (added by Level) plays the recorded backgrounds in `sounds/<kind>/` per stage (`STAGES`; Harbor Pier:
  `harbor` and `city`),
  under the levels' own baked ambiences, crossfading random clips. Each clip is levelled by its measured
  RMS (`CLIP_DB`): they range from -12 to -49 dBFS. Measure a new clip before adding it. The deserts
  (Mountain Pass's dunes too: it had the forest layer, birdsong over sand) have none: nothing recorded
  suits them.
- Leftover sounds now used: `unused_tire_screech_*` (a one-shot at the start of a skid over 12 m/s),
  `unused_car_crash_clank` (cart against cart), `unused_warning_beep` (a missile closing on the local
  cart), `unused_alert` (wrong way). The double beep (an item in hand) was too distracting and is gone.
  The odd-named loops in `sounds/enginesounds/` (`cccc`, `kkk`, ...) are spares no car uses.
  The screech and the squeal (`SFX_BrakeDrift`) only play on paved road: see Surfaces below.

## Sound effects from ElevenLabs (tools/elevenlabs)

- `tools/elevenlabs/generate_sfx.mjs` makes sound effects with ElevenLabs' text to sound effects (SFX v3,
  `eleven_text_to_sound_v3`) from the jobs in `tools/elevenlabs/sfx.json` (name, the file under the project, the prompt,
  seconds, whether it loops seamlessly, prompt influence), as 44.1kHz WAV; it skips files already made (`--force`,
  `--list`, names to make only those). From the project root: `node --env-file=.env.local tools/elevenlabs/generate_sfx.mjs`.
  The key is the user's, in `.env.local` (git ignores it; written by `npx @elevenlabs/cli onboard`): never print it or put
  it in code, the SDK reads `ELEVENLABS_API_KEY`. The folder has its own package.json (`npm install` there for
  `@elevenlabs/elevenlabs-js`; node_modules is git-ignored) and a `.gdignore`, so Godot never scans it. Each run spends
  the account's credits.
- After making clips: import them (`Godot --headless --path . --import`), set `edit/loop_mode=2` in a looping clip's
  `.import` and import again, and measure them (`res://scratch/measure_clip_rms.gd`, `-s`, headless: length, RMS, peak
  and loudest second in dBFS, read from the WAV itself) to level them by their RMS like the recorded clips elsewhere.
- Made so far: the airliners' approach and climb-out roars (Airliners.gd); the suspended railway's run, pass-by bursts,
  brakes and station chime (SuspendedTrains.gd; its first soft glide loop is unused now); Qaysariyyat al-Manara's market
  murmur and the start promenade's six cheers (Marina Nights, CrowdCheers.gd); Rheinufer's ship horns and diesel, Autobahn
  hum, Kirmes, sheep, river and windmill (`sounds/rheinufer/`); the Classics' engines (`engine_bootlegger`,
  `engine_meteor`, `engine_bubble`) and the Sandpiper's (`engine_sandpiper`); the garage's lifts and line-up (`garage_*`, `sounds/garage/`). One-shots are
  levelled by their loudest second, loops by their RMS. Very short one-shots (a single clack under a second) come back
  as smeared noise, take after take: synthesise those (`scratch/garage_lock_click.py`).
- Music: `tools/elevenlabs/generate_music.mjs` composes tracks with ElevenLabs Music (`client.music.compose`) from
  `music.json` (name, path, prompt, seconds), always with `forceInstrumental` (the user wants no vocals or lyrics in the
  game's music), as MP3 (mp3_44100_192), skipping files already made. The Kronburg GP's three (`music/kronburg/`:
  Schichtwechsel, Abendrot am Rhein, Kleeblatt) were made so: `MusicManager.STAGE_TRACKS["kronburg"]` and `["rheinufer"]`.

## Surfaces: skid marks, sliding sounds and spray

- `Surfaces.gd` says what the tyres are on: asphalt (any paved road: concrete and brick too), dirt, gravel,
  sand, snow, ice, grass, mud, wood or rock. PlayerCart sets `surface` every physics tick on the ground
  (`Surfaces.of`) and sends it to remote carts as `sync_surface` (-1 while airborne; replicated on change).
  A collider says what it is with a `surface` meta (on itself or an ancestor): new generators set it on
  their bodies. Older levels have none: their entry in `Surfaces.LEVELS` names surfaces by node-name
  fragment, then by track (`_is_track_surface`) or not. A snow drift over a road is snow. A level's entry
  can also recolour a surface's dust (`"dust"`: Mara's murram is red), and a body's `dust_color` meta
  overrides everything.
- Only paved road takes rubber, screeches and squeals. `SkidMarks.gd` is one MultiMeshInstance3D per level
  (added by the first cart that skids): a ring of 8192 quads, each wheel's mark a strip whose quads share
  corners with the one before, so it bends without gaps or dark overlaps. A quad's four corners ride in its
  instance transform's columns and `skid_marks.gdshader` builds the quad from them (skip_vertex_transform,
  the node at the identity). The corners lie on the ground each wheel's ray hits (`_update_skid_marks`,
  every frame, remote carts too), 1.5cm up; the shader also pulls each vertex toward the camera along its
  own ray (same pixels, wins the depth test) instead of standing it off the road. Multiply blending: a mark
  darkens whatever the road's lighting made of it. Width is the tyre's footprint across its path (wider
  sliding sideways); marks fade over 45s and past 90-150m. The old marks were CPU particle quads that
  floated over crests and streaked when the emitter was parked.
- Everywhere else the tyres slide audibly in the surface's own loop: `regenerate_surface_sounds.gd` (run
  headless) synthesises one seamless 2.4s loop per surface from filtered noise (gravel crunch, sand hiss,
  snow crunch, ice scrape with stick-slip chatter, mud squelch, plank knocks...) into
  `generated/surfaces/skid_<surface>.res`, all at -16 dBFS RMS; `Surfaces.FX` sets each one's level
  (`sound_db`, about -13 matches the asphalt squeal) and how much quieter it plays just rolling at speed
  (`roll_db`). Two players per cart crossfade when the surface changes (`_update_surface_audio`).
  `res://scratch/surface_sound_dump.gd -- <dir>` writes the loops out as .wav.
- Gravel, sand, snow and ice also have real recorded takes (`sounds/continuous_gravel_tire_*.wav`,
  `continuous_sand_*.wav`, `driving_on_snow_*.wav`/`snow_impact_and_driving.wav`, `driving_on_ice_*.wav`):
  `Surfaces.RECORDED_CLIPS`, picked at random by `pick_clip()` whenever a cart enters that surface,
  alongside the synthesised loop as a fallback. They were recorded much hotter than the synthesised
  -16 dBFS baseline, so each clip's entry carries its own gain back down to it (measured with
  `res://scratch/measure_surface_rms.gd`), which `_update_surface_audio` adds on top of the surface's
  usual `sound_db`. Their `.wav.import` has `loop_mode` forward (full file): unlike the synthesised
  `.res` loops they aren't crossfaded at the seam, so a 15s take restarts audibly, but that beats the
  dead air and hard restart of `loop_mode` disabled. They are driving sounds, not just slides, so these
  four surfaces roll only 5-6 dB under a full slide (`roll_db`; ice rolled silent before): about -34 dBFS
  at speed, level with the engine. At the old roll levels (-13, ice -80) they sat 10-25 dB under it and
  only slides were heard.
- `_skid_amount` (0..1) drives all of it: a drift or a locked brake at speed, or sliding wide in a corner.
  Paved road smokes when skidding; anything else raises its dust (`_set_dirt_emitting`: colour, size, rise,
  density per surface, some even rolling) and flings grit (`grit_particles`: stones, sand, snow clumps, mud
  clods, grass bits; unshaded, since a lit billboard facing away from the sun read as a black dot).
- Loose track slows a car by its offroad rating (`LOOSE_TRACK_SURFACES`: a dirt, gravel, sand or mud road, packed
  snow): its speed cap falls to `LOOSE_TRACK_PENALTY` (0.78) of its top speed at the worst rating, none at the best;
  off the road (0.55-0.65 at the worst) is harsher. Before, every car ran flat out on Canyon's gravel half, Mara's
  murram and Msitu's dirt whatever its rating (a road car at its full 81 km/h there). Paved road, wood, rock and ice
  aren't loose. `res://scratch/offroad_speed_probe.tscn -- [level=] [car=16] [aside=30] [from=150] [seconds=40]`
  (headless) drives the human's cart flat out with the player's input actions, `aside` metres off the lap line, and
  logs its speed (and as the HUD shows it: x1.8), whether it is off-road, the penalty, the surface and boosts.
- `res://scratch/surface_fx_test.tscn -- <level> [seconds=60]` races the AI and tallies, per surface, the
  marks, smoke, dust, grit and sound, with the sliding loop's mean level in dBFS against the engine's
  (windowed: headless never primes the trail particles, so only the
  classification counts there). `res://scratch/skid_shots.tscn -- <dir>` (windowed) photographs marks the
  AI laid; `res://scratch/spray_shots.tscn -- <dir> level=...` shoots carts raising dust.

## Rain puddles

- `Puddles.gd` works out again on the CPU the puddles the shaders draw (the same `hash12`/`vnoise` on the integer lattice,
  the same formulas): Quer durch Kronburg's haul road (BaustrasseTrack, `stadt_road` kind 11: in the ruts, by the lap's
  lateral and distance), scrapyard slabs (SchrottplatzTrack, kind 13) and site mud (BaustellenMatsch, `stadt_ground`), and
  Zeche Kronprinz's track (KohlenTrack). Msitu Falls' come from a noise texture and aren't covered. PlayerCart
  (`_update_puddle`, the car this peer drives) takes PUDDLE_DRAG (0.7) of its speed a second while in one, throws a little
  muddy spray off the rear wheels (the grit's particle set-up, so nothing new compiles) and splashes on entering at speed
  (`sounds/surfaces/puddle_splash_*.wav`). A top-down render against the computed map matched blob for blob.

## Blasts' tumble

- `apply_blast_impulse` (shockwaves, bombs, missiles) gives the car a push and a tumble (`air_angular_velocity`), which
  only plays out in the air. A car the blast didn't lift (the shockwave's edge, a wall in the way) kept the tumble, and
  its next jump, however much later, threw it about (the user found it). Now the tumble is dropped once the car has been
  on the ground for `BLAST_SPIN_GROUND_LIFE` (0.3s, `_ground_settle`). `res://scratch/blast_spin_test.tscn -- [level=]
  [wait=3] [lift=1]` (headless) blasts a car without lift and checks the tumble is gone; `lift=1` checks a real throw
  still tumbles.

## The shield

- PlayerCart's `_update_shield_visual` runs it from `is_shielded`'s changes on every peer: it forms (grows out of the car
  with an overshoot and a flash, `sounds/items/shield_up.wav`), flickers its last SHIELD_WARN (2s), and fades out when it
  runs out (`shield_down.wav`) or bursts when a hit breaks it (`shield_break.wav`). Respawns clear it with no animation.
- A bot waits AI_ITEM_GAP (2.5s) after using an item before the next: checked every 0.25s, one holding two shockwaves set
  off the second a quarter of a second after the first, which looked like one shockwave firing twice.

## The RC Vibe GP flag (LogoFlag.gd)

- `LogoFlag.gd` (`@tool` Node3D) builds a 14m white pole (`pole_height`) on a concrete foot with a gilt ball, its
  collider, and the flag (6.6 x 4.1m) streaming along the node's +x, as internal children: a level stores only the
  transform. The cloth is `logo_flag.gdshader`: flag_wave's wave (`flag_wave.gdshaderinc`, shared with
  `flag_wave.gdshader`) and the artwork from `generated/logo_flag_texture.res`, which `LogoFlag.bake_texture()` draws (the
  logo, `images/logo_transparent.png`, on navy between orange bands, mipmapped) and the Arco del Viento and Bloombay
  generators run. The back face mirrors u, so the logo reads the right way round from both sides.
- Arco del Viento's and Bloombay's generators place their own. Every other level gets one at race start:
  Level.gd's `_place_logo_flag` (after the runtime collision and DressingColliders' meshes) calls
  `LogoFlag.place_at_finish`, which tries spots beside the start gantry (`TRY_ALONG`, `TRY_ACROSS`, past the line
  first) for level, dry ground off the road and `LAP_CLEAR` from every lap path, with nothing solid round the pole
  or where the flag hangs, a roof high enough (it lowers the pole under one), and a clear view from the grid to the
  flag's corners. It streams away from the road. No level needs regenerating for it.
- `res://scratch/canyon_dressing_shots.tscn -- <dir> only=start level=res://levels/X.tscn` (windowed) photographs any
  level's start and its flag (`start_flag`, `start_flag_near`) and prints where it stood.


- `SpringProps.gd` (a MultiMeshInstance3D, one per design, rest transforms in `rest`): each prop is a damped
  spring tip about its foot plus, for stacks, a slide. A cart's touch (its speed from how far it moved, so
  remote carts count) tips it away and the prop wobbles back; only moving props are written back. Local
  scenery, not synced. Flags (Bloombay's feather and chequered flags, `_build_spring_flags`, FLAG_SCALE 1.5)
  have no collider: a cart drives through, the flag bends over and loses it a little speed. Their waving
  phase is the instance custom data (`flag_wave.gdshader`'s INSTANCE_CUSTOM.x). At the start/finish
  (`_build_finish_flags`, FINISH_AT) a row stands on the left only (the right's was taken away), every other one an RC
  Vibe GP flag (design "logo", `_logo_flag`: logo_flag.gdshader's cloth, key "logo_flag"), and the big LogoFlag stands
  on the beach past them (`LOGO_FLAG_S`, `LOGO_FLAG_LAT`): left to Level.gd it found only the right, behind the stand.
- `TyreStacks.gd`: tyre walls of stacks of `PropKit.painted_tyre` (tyre_wall.gdshader), as SpringProps (they
  shift up to 0.6m and rock) over the wall's own box colliders, which still stop the cart. Lakeside,
  Bloombay and Pinecrest all build their tyre walls through it. Bloombay's corner cones are KnockableProps.
- `res://scratch/spring_props_test.tscn -- <dir> [level=] [props=Flags|Stacks] [index=N] [speed=25]` (windowed)
  drives a cart through one prop and logs the tip and slide.
- Marker poles (`KnockablePoles.gd`: Msitu Falls, Frostfall Gorge, Mara Crossing, the Leitpfosten of Kronburger Hütte and
  Rheinufer, Quer durch Kronburg's Leitbaken) are rigid bodies frozen until
  a cart comes within `RELEASE_RADIUS`. On the hit (`_launch`) a pole is thrown: away from the cart and
  along its travel at `LAUNCH_SPEED_SHARE` of its speed (from how far it moved, so remote carts count), a
  hop up (`LAUNCH_UP_*`), tumbling. Left to the contact, the cart's sphere only tipped it over and rolled
  on top of it (0.2m up at most); now 5-23m out and up to 5m high at 30 m/s.
  Each pole's collider spans its drawn mesh (`_collider_span`: the mesh's height at the pole's scale, less 10cm sunk into
  the ground; where the mesh's bounds are far shorter than `pole_height`, as the Leitpfosten's are, the pole stands on its
  origin, `pole_height` tall), and the bodies are never scaled (the drawing keeps the scale). A fixed span centred 12cm
  over the origin hung most of a pole whose origin is its foot into the ground: released as a cart came near, it was
  pushed up out of it and stood floating.
  `res://scratch/pole_launch_test.tscn -- [level=] [index=40] [speed=22]` (headless) drives a real cart
  into one and logs where the pole went, and anything else solid at its foot.

## Everything solid (DressingColliders.gd)

- Every plant and object is solid on every course, near the road or far off it: Level.gd adds
  `DressingColliders.gd` once its own runtime colliders exist (not in generators). It needs no level to
  be regenerated.
  - MultiMesh instances: each mesh's shape is worked out once from its vertices (the median radius of its
    lower band): tall and slender (trees, saguaros, palms, posts) gets a trunk cylinder up to 6m, anything
    else a box round what's below 2.6m. One StaticBody3D per 64m cell, rock and plant bodies apart (their
    `surface` meta), shapes added through shape owners, not nodes. Instances drawn twice (near and far
    MultiMeshes) are solid once. Transforms come from `multimesh.buffer`: on the dummy renderer (a headless
    server, whose bots still drive into things) `get_instance_transform()` returns zeros.
  - Spectators: every standing one (CrowdPlacer's and Nyota's card cells `Crowd_<x>_<z>_<class>`, classes 2-4, which
    hold everyone at every Detail Level) is a cylinder the figure's size (`_cover_crowd`, `PERSON_HEIGHT`,
    `PERSON_RADIUS` at the figure's scale 1); the seated ones sit in stands that are solid already. Mtaa Nights about
    1,960, Nyota Stadium 1,720, Mina 300, Lakeside 100.
  - Not solid: ground cover under `MIN_HEIGHT` (0.5m), anything named in `SOFT` (grass, meadow, crowd's figures,
    flags and tyre stacks, which are SpringProps, knockable props, icicles, skid marks, shadow-only
    stand-ins), and MultiMeshes run by a script that moves its own instances (`SELF_MOVING`: KnockablePoles,
    KnockableIce, KnockableProps, SpringProps). The poles' MultiMesh is named `MarkerPosts`/`SnowPoles`,
    which `SOFT` missed: a static collider and a wobble here stopped the carts on it and fought the poles'
    rigid bodies for the transforms (a wiggle and a glitch instead of the pole flying).
  - Brush (`BRUSH`, by the mesh's file name: the ferns, not `tree_fern`): no collider at all. A cart drives
    through, bends it right over (`BRUSH_LEAN`, `BRUSH_KICK`, along its travel) and loses `BRUSH_DRAG`
    (3.5%) of its speed entering each one (carts this peer has physics authority over, as SpringProps'
    flags do); one the Detail Level doesn't draw slows nobody. Solid, the ferns stopped carts dead.
    Entering one at `BRUSH_BREAK_SPEED` (6 m/s) or more tears it apart (`_tear`, Msitu Falls and Pinecrest Ridge): its
    instance collapses in every MultiMesh drawing it, for the race, and `FernShreds.gd` throws its fronds off (out from
    its middle, a share of the cart's travel, up), tumbling, and shrinks them away over a second or so; the user wanted
    them to come apart into their leaves, not fly off whole. Each fern mesh is split once into its fronds (connected
    pieces, grouped by bearing, re-centred) and each frond drawn through a MultiMesh of `POOL` instances in the fern's own
    material: the ferns' own pipeline, so the first fern torn compiles nothing. `res://scratch/fern_parts_dump.gd` (`-s`,
    headless) lists a fern mesh's pieces.
  - The Detail Level: an instance a MultiMesh doesn't draw (past `visible_instance_count`, or hidden) has
    its collider switched off, checked every half second, so nobody hits a plant they can't see.
  - Single meshes (`_cover_meshes`, a few physics frames later): every visible MeshInstance3D gets a
    collider, a trimesh of its own triangles (both sides) if it is over 5m across (a camp's gear, a dune:
    driven over), else its convex hull; overlapping colliders it had already does no harm. Skipped
    (`MESH_SKIP`): the ground, roads and anything driven on (decks, ramps, jumps, kickers, piers, gates:
    a second, unnamed collider there would read as off-road), water, sky, effects, see-through materials,
    and meshes under a body or under a script that moves itself (the eagle, item boxes, carts). It prints
    what it made solid.
  - Plants up to 5.5m (not `ROCKY` things) wobble when a cart touches them: a damped spring about the foot
    (`SPRING_K`, `SPRING_DAMP`), the kick from the cart's speed (from how far it moved, so remote carts
    count), written into every MultiMesh that draws the plant. Local scenery, not synced.
  - `res://scratch/plant_hit_test.tscn -- <dir> [level=] [match=PlantsNear_pear] [index=0] [speed=14]
    [brush=1]` checks a plant's collider and logs its wobble (`brush=1`: the index-th fern);
    `res://scratch/brush_drive_test.tscn -- [level=] [index=0] [speed=20]` drives a real cart through ferns
    near the lap and logs its speed at each one; `res://scratch/mmi_survey.gd` (`-s`) lists every
    MultiMesh a level holds.

## Collision audit

`res://scratch/collision_audit.tscn -- <level> [reach=30] [all=1]` (headless, a spectator race so Level.gd's
runtime colliders exist) lists, per node, the 1m cells within `reach` of the lap where something is drawn at
a cart's height (0.4 to 1.4m over the ground) with no collider: what a cart drives through. Since
DressingColliders.gd only flags, tyre stacks and ground cover are soft. Trees' colliders now reach `TREE_SOLID_SHARE` (0.7) of their
branches' spread at that height (`WoodlandBuilder.band_radius`: a spruce's or fir's skirt), Pinecrest's dwarf
pines and junipers have a core collider and its logs and rockfall fences boxes, Bloombay's rocks (not
pebbles) are all solid and its bent palms carry a hull of their low trunk.

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

## The 3D logo and the title card

The logo (`images/logo_simple.jpeg`) is a model, `generated/logo/RcVibeLogo.tscn`, and the game opens with a
title card (`SplashScreen.gd`) of it and five cars. Like the levels it is generated: don't edit the files in
`generated/logo/`. Run, in this order (the trace needs about 20s, the rest seconds):

```sh
Godot --headless --path . -s res://scratch/logo_trace.gd [-- debug=<dir>]   # shapes + colours out of the picture
Godot --headless --path . --import                                           # the two textures it wrote
Godot --headless --path . res://regenerate_logo.tscn                         # LogoBuilder.gd -> the scene
```

- The picture is a JPEG, and none of it is taken as it comes: a bevel and a clearcoat show every wobble of an
  edge and every speck. `logo_trace.gd` works at half size: navy is any pixel under `NAVY_V`; the not-navy
  pixels are flood-filled into regions; one that reaches the image's edge is outside, and so is a small one with
  the background in it (the gaps between the letters are real holes, ringed in amber, but enclosed by navy) or
  a wedge of amber filling a narrow gap (the V-I one); the faces are the big enclosed regions. The loops
  (marching squares) are then fitted, not simplified: resampled, corners found by the turn over a window,
  each stretch between corners a straight line within `LINE_TOL` or Schneider cubic Beziers (flat ones become
  lines), and each corner moved to where its two lines meet, which gives back the sharp point the blur rounded
  (the flicks' tips). A face's and the body's edge is where the *brightness* crosses 0.5, halfway between the
  navy and the face, not at the navy threshold: a glowing stroke fades into the navy slowly, and the threshold
  sat in the noisy tail of the fade (the C's tip came out wavy). It prints how far a fit strays (over 4px) and
  `scratch/logo_shape_check.gd` (`-s`, headless) checks every loop for self-crossings and triangulates each tier.
- Colours are not the picture's either. The rim and the navy are gradients by height (`logo_gradients.png`: the
  median of 24 bands, end bands that are mostly edge fringe replaced by their neighbour). The faces are
  `logo_faces.png`: a bilateral blur (edge-preserving: the blocks and ringing go, the strokes and the horizon
  lines stay) run only on pixels inside a face, then spread 20px past each face's edge. The `.import` files
  (lossless, the faces with mipmaps) are written by the tracer and let through `.gitignore`.
- `LogoBuilder.gd`: three tiers on a flat back (`RIM_TOP` 80, `BODY_TOP` 108, `FACE_TOP` 146 picture pixels,
  `PX` metres a pixel: 9 x 3.4 m), the eight faces built round their own centres (nodes `Face_R` ... `Face_P`
  under `Faces`, `Rim`, `Body`) so a letter can move on its own. Each shape is a wall, then `BEVEL_STEPS` rings
  of a quarter ellipse, each the outline pushed in by the mitered normals (rings correspond vertex for vertex),
  then a flat top. Three things the push needed, each found by a bad render: the push is capped by the point's
  *displacement* (a sharp corner's miter is longer than the push, and an uncapped one crossed a neck); the room
  is the shortest distance to an edge outside the point's own `SKIP_ARC` of outline, not the way straight in
  (that overshoots in a tapering neck); and `_cure` collapses the swallowtails that are left (three to nine
  points of no area at a spike's tip; it warns for anything bigger). The picture is looked up `UV_INSET` (4px)
  inside the edge on walls and bevels too, or they showed a row of dark ticks. `PolyTriangulate.gd` triangulates
  a polygon with holes (ear clipping, holes bridged to the outline): `Geometry2D.triangulate_polygon` takes
  none, and the B, P, G, R and the C-V gap have them (`scratch/poly_triangulate_test.gd`).
- `logo_3d.gdshader` is the one material: UV2.x says rim (gradient row 0), body (row 1) or face (the faces
  texture), UV2.y how far up a wall from the tier below (the foot is darker: no ambient occlusion otherwise), UV
  is the place in the picture so every lookup is the same whatever a letter's pivot. `instance uniform fade`
  is a brightness, not a transparency: a mesh waiting at its start pose has to be `visible = false`. `glow` is
  the share of the colour that is self-lit, so the navy doesn't go black and the pale colours don't burn out
  under a key light; `sheen` (0 to 1) sweeps a slanted highlight across. `res://scratch/logo_preview.gd`
  (`-s`, windowed, `-- <dir> [yaw=] [key=] [amb=] name:x,y,z:tx,ty,tz[:fov]`) renders it in the showroom sky.
- `SplashScreen.gd` builds everything in code in a SubViewport (see the file's header) and every motion is a
  function of the clock: `seek(t)` jumps anywhere. Main plays it once a launch (`should_play`: not when
  headless, not with `nosplash` as a user arg, and only when Main is the *running scene*, so the tests that
  instantiate Main from their own scene never see it), on a CanvasLayer at 105, under the swipe (120) that takes
  it away, with the menu hidden behind it. It holds for `DURATION` (20s) and then ends by itself; any key, click
  or button skips it after half a second. The camera's push in takes `DOLLY_TIME` (6.5s), after that it only
  breathes, and the highlight sweeps the letters every `SHEEN_EVERY`, so the long hold is never still. It
  follows the player's settings: `MusicManager.anti_aliasing`, shadows, and the Detail Level (the floor's mirror
  from Medium, particles thinned below).
  - Looking round: the mouse, or the stick of a pad pushed furthest past `STICK_DEADZONE`, moves the camera
    toward where it points by `LOOK_SHIFT` metres, and the point it looks at `LOOK_TARGET_SHARE` as far, so the
    cars shift against the logo and the logo stays in frame; it eases there at `LOOK_RATE`. Both are read from
    the *events* (`_mouse_pos`, `_axes`), not polled: the pointer's place only counts once it has moved (it may
    be anywhere when the card comes up), a pad coming or going clears the sticks, and a test can drive it. Mouse
    events reach `_input` in the window's canvas coordinates (an injected event is read as window pixels and
    scaled by the stretch transform, like the real one: send `root.get_final_transform() * canvas_pos`).
  - The cars are drawn afresh at every launch (`_pick_cars`): five distinct models from `CarSelection.CAR_PRESETS`
    (the car select list, so a new car turns up here by itself) into the five `SLOTS`, each with a
    `CarPaint.random` paint job whose body colour is bright enough for the dark floor (`MIN_PAINT_LUMINANCE`)
    and not close to one already in the line (`PAINT_APART`). Cars differ in size, so what depends on it is
    read off each: a wheel's radius from its mesh (the cars' frame is the world's in metres: `CAR_SCALE` and the
    model's half scale cancel), the dust from the rear axle as wide as the track, the shadow from the track and
    wheelbase. `random_seed` fixes the draw, `lineup` says what was drawn.
  - The floor is a transparent plane, and the cars and logo stand again below it upside down (`_mirror`, the
    same transforms): `splash_floor.gdshader` reads the depth texture and is see-through where it hides
    something, by how far below the floor that thing is, so a reflection fades away from its contact.
  - Things that went wrong: the two rim lights glinted off the polished floor as enormous coloured sheets
    (the floor is on layer 2 and the rims' `light_cull_mask` is 1); the dust was drawn before the floor, which
    painted over it, because transparent things sort by their node's distance (give each transparent layer a
    `render_priority`: burst -3, floor 0, shadow blobs 1, dust 2, sparks 3); the sky's sun glow at `pow(s, 30)`
    covered half the view and the warm and cool soft boxes the floor reflected must stay above the low parts
    of the sky.
  - The cars are `generated/cars/<Name>.tscn` at `CAR_SCALE` 2 (PlayerCart's x2), facing +z at yaw 0; a
    wheel node turns about its own x (forward is a falling angle, by the distance rolled over the wheel's
    radius) and steers about y. The dust emitter is scaled by 1/`CAR_SCALE`, or the cloud's sizes and speeds
    double.
  - `res://scratch/splash_shots.tscn -- <dir> [times=0.5,1.0,...] [seek=1] [seed=N] [look=x,y]` (windowed, with
    `--fixed-fps 30` so the clock and the dust are the same however slowly the shots save) photographs it, with
    the line-up of that seed and the view held as if the mouse stood at (x, y); `bench=1` (without
    `--fixed-fps`) prints its frame times (60 fps on an M1 at 1920x1080). `res://scratch/splash_flow_test.gd`
    (`-s`, windowed, `-- <dir> [key=3.0 | key=-1] [nosplash]`) plays the real start-up and checks the hand-over
    to the menu (`key=-1` waits out the 20s); `res://scratch/splash_input_test.gd` (`-s`, windowed) drives the
    mouse, a stick and a pad button through the real start-up; `res://scratch/car_lineup.gd` photographs the
    cars in factory paint.
- The engine's own boot image (`application/boot_splash/image`, shown while the project initialises, before
  Main exists) is `images/logo_black_bg.png`, with `boot_splash/bg_color` black to match its background so a
  window of another shape gets no grey bars. It has to be a PNG: Godot 4.8 logs "The only supported format is
  PNG" and shows its own logo for a JPEG, so `logo_black_bg.jpeg` was converted losslessly (RGB, no alpha). It
  is read straight from the file at start-up, not through the import system. The title card fades in from
  near black, so the two meet.

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
Bloombay sets it on. Every other pad turns about its own up axis at runtime to face the nearest lap path
(`_face_lap`: TrackPath, the alternative paths, other `*Path` children such as Mara's CrocJumpPath):
31 pads on 8 levels had been laid backwards or across shortcuts. `settle_on_track` is on by default: every
pad drops onto the surface under it once the level's collision exists, tilts with it and faces along the
nearest lap path (`_lap_tangent`); flat pads at set heights had floated on one side or sunk into slopes.
`_settle` lies the pad on the plane through its four corners' hits, at the middle's hit; only hits on
level-ish ground (normal y >= 0.6) within 1.5m of the middle count, and the tilt stops at 40 degrees.
Setting its height from the lowest corner buried pads on slopes (Lakeside's kicker: a metre under the
deck), and a corner ray clipping a wall or curb tipped some onto their sides.
`res://scratch/boost_pad_settle_probe.tscn -- <level>` lists each pad's saved and settled place and tilt.
The shader's lit border is one rectangular frame (`aspect`, the top's proportions): separate side and end
lines had overshot each other at the corners. `res://scratch/boost_pad_audit.gd` (`-s`) lists the saved
transforms; `res://scratch/boost_pad_runtime_check.tscn -- <level>` checks them in game.

## Wooden ramps

`WoodenRamp.tscn` (`WoodenRamp.gd`, `@tool`, a StaticBody3D) is a jump to place by hand on any level. It builds
its mesh and a trimesh collider from its exports as internal children (cached per shape), so a level stores only
the transform and the shape: `length` (toe to lip), `height`, `width`, `curve` (0 a wedge, 1 a transition flat at
the toe; the lip's slope is height / length * (1 + curve)), `table_length` (a flat top), `tail_length` (a run back
down: a roller; 0 cuts it square, a kicker with a boarded back), `wood_color`, `trim_color` (the toe and lip
planks). The planks never lie lower than `PLANK_MIN_Y` (5cm) over the ground: at the toe and a roller's foot
they lie flat on the road there, since a plank top grazing the road z-fought with it all across the ramp (the
collision keeps the true profile). A kicker's back boards stop under the header along its top, which stands
1.5cm proud of them: flush, they shared a plane in a band under the lip that flickered. Planks across the run on stringers, upright boards on the sides, posts and a sill outside, all
`hut_wood.gdshader`. The origin is the toe's middle on the ground and the ramp rises toward -z (like a boost
pad's front). Like the pads, `settle_on_track` (on) drops it onto the surface under it once the level's collision
exists, on the plane through its corners' hits, 1cm under so the toe shows no edge; `face_lap` (on) turns it
along the nearest lap path; the Snap To Ground button does the drop in the editor (the saved colliders, else
the meshes under it). It is in the `ramps` group with `surface` wood, so it is track whatever it is called and
the AI never steers round it: make it as wide as the road. `lip_info()` gives a `jump_lips` entry.
`trestle` leaves the sides and back open: joists under the planks (`TRESTLE_JOIST_GAP` apart), and every `TRESTLE_BENT` a bent
across the run (a sill, a post under each joist, a cap beam, diagonal braces in one or two tiers with a girt), the sides
braced between the bents; for big ramps, where boarded sides read as one solid block (the collision is the same).
`res://scratch/wooden_ramp_preview.gd` (`-s`, windowed, `-- <dir> name:x,y,z:tx,ty,tz`) renders a kicker, a
table-top and a roller on a flat road, and Mina del Viento's big trestle kicker at x 45.

## Item boxes

- `ItemBox.gd` (`@tool`) builds the box as internal children, so level files (and Level.gd's spawns) only
  store the transform: a holographic glass globe (`item_box_orb.gdshader`: a rim, latitude and longitude
  lines, the circuit traces; `SHELL` switches back to the cube, `item_box_glass.gdshader`), the symbol of the item it holds
  (`item_box_glyph`, white tubes swept along `ItemSymbols.gd`'s strokes), sparkles (`item_box_sparkles`) and a
  glow on the ground (`item_box_glow`). Meshes and materials are static, shared by every box; a box's own state
  is shader instance uniforms (`phase`, `pop`, `build`, the glow's `present` and `charge`) and its `item`.
- What a box shows is what it gives. The server picks the item (`roll_item`, ITEM_POOL) when the box comes back
  (`_activate_rpc(item)`) and every peer shows it. Until START_BOOST_ONLY_SECONDS after the green light every box
  holds a boost (`boost_only_until`, set by Level); then Level has the server pick again for the boxes still
  standing (`server_reroll`). One exception: the racer in last place always gets a boost, a chance to catch up
  without slowing anyone. `res://scratch/item_box_roll_check.tscn` checks both.
- `ItemSymbols.gd` holds the seven symbols (flame, rocket, rocket and reticle, shield, rings, bomb, bolt) as
  strokes in a -1..1 square; `ItemSymbolIcon.gd` draws them in the HUD's item slots and the kill feed (white
  over a soft dark edge). `res://scratch/item_symbols_preview.tscn -- <dir>` (windowed) shows boxes and icons.
- Time trial: no boxes at all (Level frees the levels' own too). The run starts with one boost in the slots
  (`_give_start_boost`) and every gate that counts adds one (`_give_gate_boost`, `PlayerCart.give_boost`, up to the two
  slots; none at the final line). See "Time trial and lap times".
- The glass is premultiplied: ALBEDO is the light it gives off, ALPHA how much it dims what's behind it. Back
  faces draw at 45%, which gives the far edges. Its even `fill` stays low because it lays cyan over the symbol.
- The symbol turns about world up to face the camera in its vertex shader (BILLBOARD_FIXED_Y's matrix), so it
  reads on both split-screen viewports. It is unshaded with its own fixed key light: lit by the scene, its
  specular took in the blue sky.
- The sparkles are one mesh of quads that the vertex shader places (seeds in COLOR, corner in UV, writes
  `POSITION`): no particle system. `custom_aabb` covers the burst.
- Once the level's collision exists (`_settle`) the box raycasts down: the cube's centre hovers `HOVER`
  (1.45m) over the ground, at most `MAX_SEAT_SHIFT` off the node so it stays in the 2.5m pickup area, and the
  glow lies on the hit. Level spawns boxes 1.2m (random) or 1.5m (gates) above the ground or the gate's origin.
- Taken (`_deactivate_rpc`): `pop` runs to 1 over 0.5s (a flash, the glass swells and fades, the
  sparkles fly out, a shock ring on the ground), then the box hides and the ring on the ground fills round
  over `RESPAWN_TIME` (`charge`). Back (`_activate_rpc`, and at the start): `build` cuts the cube off under a
  line sweeping up it. Each peer animates from the RPCs.
- Every part gives off its own light, so `_settle` sets `gain` to 1 / the level's `tonemap_exposure` on the
  shared materials: Northlight's 1.45 bloomed them into white balls. Fog is off on them; they fade themselves
  (`fade_begin`/`fade_end`) and by `visibility_range_end`.
- Cost: about 0.03ms of GPU on an M1 at Pinecrest's gates (`ab_bench ... gates hide=ItemBox`).
- `res://scratch/itembox_preview.tscn -- <dir> [boxes=3] [car=0] name:x,y,z:tx,ty,tz[:frames[:gap]] pop=<i>
  respawn=<i> wait=<s> param=<part>:<name>:<value>` (windowed; a scene, because ItemBox uses NetworkManager)
  renders boxes over a flat road. Steps run in order: `pop=1 burst:0,2.4,9:0,1.6,0:8:0.07` saves the burst
  frame by frame, and `param=` tries a shader value on a part's shared material.

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

## Hashes of interpolated values (flicker on Windows only)

A face's vertex colour (or any attribute equal at its three corners) arrives in the fragment shader bit-exact on
Apple's GPUs, but on NVIDIA under Vulkan perspective-correct interpolation lets it drift in the last bits from pixel
to pixel. A hash (`fract(p * big)`) turns that drift into a different draw per pixel: `city_building.gdshader`'s
per-window and per-shop picks hashed `vcol`, and on Windows every window, shop front and sign band of Nyota Stadium
and Mtaa Nights was speckled noise that crawled as the camera moved; on the Mac it was clean. Feed hashes from a
`varying flat` copy (`vkey`) or from per-instance data, never from a smooth varying. `res://scratch/depth_flicker_probe.tscn
-- <dir> [level=] [chase=<s>,...] [near=1.0] name:x,y,z:tx,ty,tz` (windowed) renders each view in one frame from four
cameras (near 0.05 and `near`, each also 3cm to the side) and prints the share of pixels that differ: unstable
shading changes between two cameras at the same spot, z-fighting shows against the near plane, parallax is thin edges.
Godot's Mobile renderer takes a D24 depth buffer where the GPU has one (the RTX 2060 here) and D32 float on Apple
Silicon, which has none; the probe found no z-fighting from it on these levels.

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
- A windowed run on the M1 that logs `ERROR: timeout waiting for fence` (Metal) can save garbage frames:
  wrong colours (a green car came out red and blue), every shot the same whatever changed. It is the GPU,
  not the scene: rerun before believing the picture.

## Texture streaming (the rock and plant models)

- Godot 4.8's texture streaming is on (`rendering/textures/streaming/enabled`; the editor needs a restart
  after changing it): a streamed texture loads only the mip levels the camera needs. Works with the Mobile
  renderer on Metal here; Compatibility has no streaming.
- The Hunyuan models in `models/plants`, `models/desert`, `desert2`, `desert3` (4096px maps) and
  `models/desertridge`, `models/trees` import their textures with the "Texture2D Streamed" importer
  (`streamed_texture_2d`). `scratch/stream_textures.py` converts a folder: it shrinks each PNG in place
  (Lanczos: the maps the materials use to `--size`, 1024 for plants and 2048 for rocks; the grey
  metallic/roughness maps no material reads to 512) and rewrites its `.import` keeping its uid. Which file
  is a normal map comes from the models' own materials (`scratch/texture_roles.gd` writes them as JSON),
  not from its name. The streamed importer has no size limit, which is why the sources are shrunk.
  `.gitignore` lets those `.import` files through, so the setting travels with the project.
- Reimport headless with `Godot --headless --path . --import` (about 9 minutes for all of them).

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

- The cavern's mountain is one peak (`_mountain_full`, `MOUNT_*`): its summit over the passage's middle, concave flanks
  falling away east and west, spurs radiating from the top, a horn on it; cut down by the portals' faces as before
  (`_cavern_mass`'s `along`). The heightfield rises to it `MOUNT_INNER_RISE` past the gallery's edge, and the cap over the
  passage (`_cap_section`) is laid at the mountain's own height (`_cavern_mass(..., true)`: no corridor cut),
  `CAP_LIFT` over the heightfield where both carry it, diving gently under it at its edges (`CAP_HALF_W` 46). It had been
  two ridges either side of the passage (the height rose away from the axis) with the cap filling the saddle to 90%
  of the lower: from the road, two humps with a dome between; the user disliked it. Diving from 60% of its width, the cap
  left a crease up either side. The audit (`_audit_cavern`) still checks the gallery and its walls.
- The ice sculpture exhibition (`IceSculptureKit.gd`, `ice_sculpture.gdshader`): carved-ice sculptures modelled as signed
  distance fields (smooth-blended ellipsoids, tapering capsules, chains) and meshed by surface nets
  (`IceSculptureKit.mesh(design, voxel)`, normals from the field's gradient; 1-4s a design at `SCULPTURE_VOXEL`; saved as
  `generated/icesculpture_<design>.res`, outside the `northlight_` prefix, or MeshChunker cut each into four); the
  designs: owl, reindeer, whale (its tail rising from a wave), swan, bear, snowflake, spiral, wave, fox (all made up). A
  pair tops each junction pylon (`SCULPTURE_PYLONS`, one design a junction, facing the oncoming cars, turned a little to
  the road, `SCULPTURE_PYLON_SCALE`, on a wider glowing plinth), the garden stands on ice pedestals on the frozen lake
  beside the start straight (`SCULPTURE_GARDEN`, `_build_sculpture_garden`, solid boxes), and the festival's sign
  (NORTHLIGHT ICE SCULPTURE FESTIVAL, made up; `_sign_ice_material`: darker ice so its letters read) stands by the finish.
  Each sculpture glows in its uplight's colour (instance uniform `glow`, strongest at its silhouette and foot) with a
  small light (`no_shadow`); the shader bumps chisel scoops into it (Worley, no tangents needed) and is opaque.
  `res://scratch/ice_sculpture_preview.gd` (`-s`, windowed, `-- <dir> [only=owl,...] [voxel=] name:x,y,z:tx,ty,tz[:fov]`)
  meshes the designs in a row 6m apart and renders them in seconds.
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
- `res://scratch/ab_bench.tscn -- res://levels/X.tscn [samples=6] [gates] variant ...` switches variants
  (`storm`, `nolightshadow`, `nomoonshadow`, `unshadow=`, `sky=`, `hide=`, `cheapmat=`) back and forth
  within one run; `gates` samples 10m before each checkpoint instead of along the lap, `cam=x,y,z:tx,ty,tz`
  (repeatable) from those spots. On macOS, separate
  `bench.tscn` runs differ by up to 2x with the GPU's clock.

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
  headless and lists every respawn with where it happened, and each cart's laps in game seconds (`laps_s`; `FLYING
  LAPS`: the laps after the first, to compare AI changes with `cars=` fixed and `noitems=1`). `res://scratch/water_drop_test.tscn` drops a
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

- The footballs (`Football_1`..`5`, `KickBall.gd`, see "Kick balls") wait on flat runs in all four lanes, between the
  jumps (`FOOTBALLS`: lane, x, lateral), placed by `_place_gameplay`.
- The bowl's checkpoints stand 38-40m down the lane after their hairpin (lane 2 x -80 in the whoops, lane 4 x -82 at the
  Kibo double's foot): 16m out, carts drifting wide out of the bermed turn went round the gate's area. Lane 3 has none
  (the user found the bowl had too many): the lane dividers are 1.3m walls, so lanes 2 and 4's gates keep the lap honest.
- Beside each stand's end a wall closes the yard's edge from the floor to the paving (`_build_walls`): the paving is
  one-sided, and from the arena, past a stand's end over its low front rows, the yard's fans stood on nothing.
- Everything in the city is solid: each building's tiers are convex prisms (`_city_solids`, `_build_city_solids`, an L
  split by `decompose_polygon_in_convex`), one body per city cell (`CitySolid_*`): the cells' meshes are 400m across,
  which DressingColliders skips. The fan zone's tents (legs, and the roof from the valance up), the TV trucks and the
  camera towers are boxes (`_precinct_solids`, `PrecinctSolids`): their mesh is chunked. `_edge_box` draws undersides
  (awnings, balcony slabs and cornices had none, invisible from the street below).
- Return jumps (`RETURN_JUMPS`, `_plan_return_jumps`, `ReturnJumps/ReturnJump_*`): WoodenRamp kickers outside the
  street barriers, `RETURN_ANGLE` off the road's heading, the lip's corner 0.4m off the barrier, for a cart that jumped
  out: in the fan zone and the market plaza onto the Drop-In's run-up (straight into the jump back into the bowl), from
  the infield and the city onto the avenue, from the car park onto lane 4's street. Lamps and people keep off them and
  the fence stops over them (`_near_return_jump`). `res://scratch/return_jump_test.tscn -- [speeds=13,16,22,28]
  [only=Market]` (headless) drives a real cart at each and prints where it lands: on the road from 13 to 28 m/s.
- The paper run-through banner (`PaperBanner.gd`, node `RunThroughBanner`, `BANNER_PAST_LIP` 3.5m past the Drop-In's
  lip, standing on the yard's paving before the wall): a 17 x 6.6m sheet on two posts and a top bar, printed with
  `images/posters/forestrun.jpeg` between orange bands and chequered panels (`PaperBanner.bake_texture()`, run by the
  generator, read straight from the JPEG, saved as `generated/paper_banner_texture.res`; `paper_banner.gdshader`, both
  sides printed, the torn edges bare paper). The sheet is a grid of jittered cells; a cart crossing its plane (its
  position, from frame to frame, every cart this peer sees) tears out an ellipse round where it hit (`HOLE`) with
  rips running out of it (`SLITS`), and the cells no longer joined to the top bar or a post fall too. Each torn cell
  is a scrap moved by the script (thrown with the cart, air drag, flutter, a ray to land on), lying 7-10s before
  shrinking away. One sheet a race: never replaced. Later carts go through the hole or tear more. Local scenery, not
  synced, costs no speed; its script moves things, so DressingColliders leaves its meshes alone (the frame has its
  own boxes). `res://scratch/paper_banner_shots.tscn -- <dir> [speed=34] [lat=0] [carts=1] [times=...] [cam=...]`
  (windowed, `--fixed-fps 60`) drives real carts through it and saves frames; `nyota_jump_test ... only=DropIn` prints
  the cells left after each run.
- The exit cutting's walls (`_build_cutting`) have a back face down to the yard's paving and a cap at the top end,
  and the street barriers capped ends: with only the road's face, the north wall vanished seen from the street.

## Kick balls (KickBall.gd)

- `KickBall.gd` (`@tool` RigidBody3D) is a ball the carts kick about: `Style.FOOTBALL` (Nyota Stadium: a size 5
  ball at the stadium's 1.86 times life size grown again by 1.75, 0.72m across: at 0.41m it was hard to see) and `Style.BEACH`
  (Bloombay: 0.9m, light, floaty). It builds its sphere and shape as internal children from `STYLES` (radius,
  mass, gravity, damping, bounce, kick, lift, slow, float, drag, roll), so a level stores the transform, the
  style, `water_y` and `drift`. `kick_ball.gdshader` draws both: the football's 32 panels of a truncated
  icosahedron (the face its ray from the centre meets first, pentagons black) with dust scuffs, the beach ball's
  six gores and white caps.
- Carts never touch it through the physics: every cart gets a collision exception (their 1.5m sphere rode up
  over a 0.4m ball and pressed it into the ground). The ball tests itself against a box round each car's body
  (`CAR_HALF`, `CAR_Y`, in the cart's frame: its body never rolls; the box reaches down so nothing passes under)
  and kicks itself off along the contact's normal at `kick` times the closing speed, lofted by `lift`. A fast car
  swallows the ball's centre in one frame, so the normal is then the face it came in through (`_entry_face`).
  The cart this peer drives loses `slow` of the closing speed: a football costs a head-on cart about 12% at
  30 m/s, a beach ball about 4%. It is on its own layer (`LAYER`, 6), so AI obstacle rays and ground probes
  don't see it.
- Local scenery like KnockableProps: each peer runs its own ball from every cart it sees (velocity from how far
  a remote cart moved; a respawn's jump is none). Nothing is synced.
- Afloat (`water_y`) it sits `float` under and drifts by `drift`; rolling slowly on the ground it meets a fixed
  rolling resistance (`roll`, m/s^2): a proportional one let a beach ball creep 5m down the beach's 3 degrees
  into the sea. Lost (fallen out, at rest away from home for `RESET_IDLE` with no cart within `RESET_CLEAR`, or
  adrift past `ADRIFT`) it goes back to where it started. Its thump is synthesised (`_thump`).
- `res://scratch/kick_ball_test.tscn -- [level=] [index=0 | spawn=football|beach s=300] [speed=30] [watch=4]
  [trace=1]` (headless) drives a real cart into a ball and logs the cart's speed before and after and the
  ball's flight (`aside` is undone by the cart's own grip); `res://scratch/kick_ball_float_check.tscn --
  [level=] [seconds=20]` lists where every ball went, afloat or not.

## The crowd (Nyota Stadium)

- A spectator is two things drawn from one `INSTANCE_CUSTOM` (`crowd_common.gdshaderinc`: r a seed, g the skin
  draw, b the pose `(id + 0.5) / 16`, a a second seed and the animation phase), so it is the same person at both
  distances: a **card** (`stadium_crowd.gdshader`, a flat figure drawn in the shader, the old look, now with legs)
  and, within reach of the lap, a **3D figure** (`CrowdKit.gd` mesh, `stadium_person.gdshader`). They swap by dither
  between 34 and 44m (`tree_lod.gdshaderinc`: `lod_mode` 1 on the figure, 2 on the card).
- `CrowdKit.gd` is one mesh (about 2.3k triangles, 1.3k of them drawn) in a standing rest pose at 1.86 times life
  size (3.3m, the stands' scale), carrying every hair style, a dress and the props. Per vertex: COLOR the part
  (limb), region (skin, shirt, trousers, ...) and style (which hair or prop); UV/UV2 the limb's two joints (they all
  lie in the plane z = 0) or a head part's head-unit position. The vertex shader bends the joints per pose, hides
  the styles a spectator doesn't have (`VERTEX = vec3(0)`), and the fragment shader paints the face (eyes, brows,
  nose, mouth, ears, stubble, sunglasses). Its constants (`HEAD_C`, `HEAD_R`, `HIP_Y`) repeat CrowdKit's.
- The 16 poses (0-6 seated: idle, clap, film, talk, arms crossed, cheer, drink; 7-15 standing: idle, clap, cheer,
  film, arms crossed, flag, hands on hips, wave, drink) are tables in `stadium_person.gdshader` (`ARM_L`, `ARM_R`:
  pitch, roll, elbow, yaw; `TWIST`, the upper arm turned about its own length; `LEGS`), a forearm's direction from
  straight down being pitch + elbow. The elbow only bends forward, so a hand on the hip needs the twist (90 degrees
  in) to bring the forearm round to the waist. Not everyone cheers: `POSE_*` in the generator are the odds (about
  10% cheer, 17% in the main stand's middle). Flags (pose 12) only in the stands: `POSE_STANDING_PLAZA` has none
  (they stood up through the fan zone's tents and the stalls' tarps), and a fan under less than `FLAG_HEADROOM` of
  the roof (`_roof_underside`: the upper tier's back rows) cheers instead.
- The shoulder joint (`SHOULDER_X` 0.34) is just inside the torso's side: out at 0.40, beside the chest, a raised arm
  swung about a point outside the body and stood off the shoulder with a gap. The shoulder is a ball centred on the
  joint (and the elbow and knee balls on theirs), so it looks the same however the limb turns and always covers the
  join: a deltoid placed off the joint swung out with a raised arm as a lump over a gap (the user saw arms "not even
  attached"). The torso's shoulder line runs up to the balls (from a flat shelf at 2.62 they stood up like pads), the
  thighs' tops are inside the seat (open and wider, their edge showed as a flap over each hip), and the hands are a
  palm, curled fingers and a thumb (`_build_hand`, palm toward the thigh), no longer an egg. Limbs are 9-10 sided,
  the torso 12. Crossed arms (4, 11) turn the upper arms in (`TWIST` 80) so the forearms lie across the chest: the
  old yaw swung the elbows to the middle and the hands out past the other side. The cap is a crown
  cut on a slant (at the brows in front, mid-head at the back) with a curved bill from its front edge
  (`_build_cap`); the short hair is on the head's own 6 x 12 grid, since on a coarser one the head's corners poked
  through it. `res://scratch/crowd_preview.gd` is the way to check a pose.
- Animation (the vertex shader, and the card's arms and hops to match): nobody keeps going. `crowd_common`'s
  `crowd_cycle` gives each person bursts on a cycle of their own (`crowd_burst`: about 11s, 42% of it in a burst, a
  quarter either way; the mouth opens only in one): cheering, clapping and waving come in bursts with the arms down
  between them (to the seated hands-on-thighs or the standing idle arms), two in five cheerers hop two or three times
  at the start of a burst with a crouch before and after (`crowd_hop`), the rest bounce on their toes or in their
  seat; flag wavers wave hard in a burst and sway between; filmers lower the phone now and then (`PHONE_DOWN`),
  drinkers sip now and then and hold the drink low between (`HOLD_SIT`, `HOLD_STAND`); talkers turn to a neighbour
  and gesture. The idle look round in held glances (`crowd_look`), and the standing shift their weight from foot to
  foot (`shift`: the legs lean from the ankles, the free knee eases, the shoulders counter). Pose 9 used to jump
  without a pause. Near player one's car (`xray_car_a`, PlayerCart's camera x-ray global: w > 0 in a race) they
  watch it go by: within 55m, gone at 95m, never round behind them; the head takes most of it, the shoulders the
  rest (filmers more, so the phone follows; talkers and drinkers less).
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
- `CrowdPlacer.gd` builds the same people for other levels (cards, figures, `CrowdDetail.gd`, the shared
  `generated/crowd_person.res`) from spots of [position, facing, seated, in a stand, pose (-1: drawn), size], at a
  scale and with a skin mix of its own (Lakeside's start; its playground's children are size 0.58). Nyota's generator
  still has its own copy of these numbers.
- `res://scratch/crowd_preview.gd` (`-s`, windowed) renders the figures in memory in a second: `-- <dir> [rows=3]
  [seed=1] [cards=1] [skin=<g>] [car=x,y,z] [time=<s>] name:x,y,z:tx,ty,tz`, a column per pose 0..15 (2.6m apart),
  the cards in a row behind with `cards=1`, player one's car at `car=` for the watchers, the clock run to `time=`
  first (bursts are seconds long). `nyota_shots` takes `detail=N` to try a Detail Level.
- `scratch/human_lineup.tscn` (`human_lineup.gd`, a tool script: open it in the editor, or run it with F6 to fly round:
  WASD/QE, right mouse, 1-9 sections, C the car, L the labels) stands the game's people in one line, numbered and
  described: every pose with its prop, every hairstyle, shirt pattern, sleeves, trousers, shorts, dresses, shoes,
  sunglasses and beards, the skin groups, children, yukata, the flags, then the far cards of the 16 poses; a car drives
  up and down in front (the spectators watch it: it sets `xray_car_a`), and the Lakeside's cyclists ride a loop behind
  it when it runs. Its outfits are spelled out, not drawn: a seed of 2 or more is `2 + n`, the n-th of the material's
  `crowd_lineup` codes (`lineup_code`; crowd_common's `crowd_data` swaps the number for the code, `crowd_rand` and
  `crowd_hair_style` answer from its bits, everything else from the phase). The number, not the code, goes through the
  instance data: the Compatibility renderer keeps instance custom data as half floats (exact only up to 2048), and
  every code came out as a yellow shirt and grey shorts. `res://scratch/human_lineup_shots.gd` (`-s`, windowed, `--
  <dir> [time=<s>] [nocar=1] name:x,y,z:tx,ty,tz[:fov]`) photographs it. It showed children with grey hair (no
  more: only adults go grey).
- The figure is the shared `generated/crowd_person.res`, which every level with spectators loads:
  `res://scratch/rebuild_crowd_person.gd` (`-s`, headless) rebuilds it from CrowdKit keeping its material, so a change
  to the figure needs no level regenerated (regenerate_nyota_stadium writes it too).
- The Compatibility renderer (Godot 4.8-beta2, `--rendering-driver opengl3`, as the cloud renders) loses a mesh's
  vertex colours on a MultiMesh with custom data and no instance colours: every figure drew as a rest-pose doll in
  skin, every style shown. The preview gives its MultiMeshes white instance colours (`mmcol=0` leaves them out); the
  levels' crowds look like that in a Compatibility render (Vulkan is fine).

## Camps (CampKit.gd: Lakeside Meadows and Bloombay Dunes)

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
- CampKit's "lamp" gives off no light (see "Lamps on the night and dusk stages").

## Lamps on the night and dusk stages

- CampKit's and MatatuKit's "lamp" is a StandardMaterial3D with emission MULTIPLY and no emission texture: the texture's
  default is black, so it gives off no light and lanterns, lamp lenses and bulbs read as paint (a StandardMaterial3D
  can't glow in its vertex colour either). `res://scratch/lamp_material_probe.gd` (`-s`, windowed) measures it (0.05
  against a glowing 1.0); `res://scratch/lamp_survey.gd` (`-s`, headless, `-- [levels]`) lists each level's sun (its
  elevation, energy and colour) and its dead lamp surfaces and the files that hold them.
- On the night and dusk stages lamps glow: `LampGlow.gd` (`material()`: `lamp_glow.gdshader`, unshaded, the vertex colour
  times `energy`; `is_dead`, `fix_mesh`). Marina Nights (MarinaKit's keys, its sailboats), Mtaa Nights (the vehicles'
  lamp, `generated/mtaa_matatu_lamp.res`), Ramlat Hamra (`ArabianKit.lamps_glow`, set by its generator: the palace's and
  the reflector posts') and Mina del Viento at dawn (MinaKit's "lamp", `generated/minaprop_mat_lamp.res`). Their saved
  files were patched in place by `res://scratch/fix_lamp_glow.gd` (`-s`, headless, `-- <levels> [energy=] [dry=1]`: a
  dead lamp material in a file of its own is replaced at its path, one embedded in a mesh is swapped and the mesh
  saved), and their generators build them so. The day stages keep CampKit's (lamps lit at noon would look wrong).

## Bloombay Dunes (beach stage)

- The surf is `beach_water.gdshader` on the `BloombayWater` node, which `regenerate_bloombay_dunes.gd` builds
  (`_build_ocean`) after `generate_world()` replaces TerrainGenerator's flat plane. The generator bakes a shore
  field (`_bake_shore_field`, one texel per terrain vertex from `SHORE_X0` to `SHORE_X1`): ground height,
  wave travel time to the waterline (an eikonal solve with the shallow-water speed, so crests bend round the
  bay and close up as they shoal), surf weight, and the shallowest depth seaward. The shader numbers waves by
  phase, breaks them where they get taller than 0.78 of the depth, and runs their swash up the sand. Change
  the terrain and the field follows on the next regeneration.
  - The field reaches `FIELD_NORTH` (260m) past the terrain's north rim and `FIELD_SOUTH` (1.3km) past its
    south one, and east to `SHORE_X1` (900m) along the north coast, from `_coast_height` off the terrain: its
    edge rows repeat outward, and the north beach's shallows repeated had surfed across the whole bay; ending
    at x 5, the foam stopped dead at the causeway. Its A channel (shallowest water seaward) runs along the
    rows from the west for the west beach and down the columns from the north for the north coast.
  - East of the field and past its ends the shader takes the edge texel where its surf weight says open sea
    (the bay north of the course: weight 1 off the north coast too) and fades the swell out as the water
    shoals by a coarse ground map (`_bake_coast_map`, `COAST_MAP`, 8m texels of `_coast_height`), with no
    swash: given the edge's sand, the water draped over the north beach in bands. Behind the west beach (the
    dune ponds) it is calm, over a shallow bottom (-1.5m; at -50 the occluded pixels round a pond's edge drew
    it a dark rim). Calm everywhere east, the bay had showed as a pale rectangle.
  - Over land the sheet hides a metre under the field's ground, and each chunk's culling box reaches up over
    the highest ground it spans (`_water_ground`): with boxes 4m high, chunks up the dunes culled in and out
    (tiles popping in motion). Hiding it at a fixed depth instead stepped the water's edge along the grid and
    flashed cells as waves lifted a corner. A chunk wholly over dry land (`DRY_GROUND`) is left out; the fine
    columns go into chunks `OCEAN_CHUNK_COLS` wide.
- The water mesh is a grid on the terrain's grid lines (thirds of a cell across the surf zone `SURF_X0..X1`),
  so the swash sheet lies parallel to the sand, then wider out to `OCEAN_REACH`. It is chunked for culling. Its
  fine rows run on south along the coast to `OCEAN_FINE_SOUTH` (z 900).
- The course is no island (`_build_backdrop`, `_coast_height`): TerrainGenerator's `edge_falloff` and
  `clip_to_disc` are off (the terrain is the whole square: the disc's rim of 2.26m cells showed as a staircase
  over the ring under it) and
  `TerrainGenerator.bloombay_north_coast` gives the map a north waterline (`bloombay_north_shore_z`, z about
  -450) with a 45m beach and the dunes easing in by 110m, only ever lowering the ground (switching on whether
  the ground was under sea level stood ponds and the west beach in cliffs); `bloombay_sea_depth` deepens past
  240m offshore to 40m (where the falloff used to take it). The dune hollows (ponds) ease in from x 40 to 70
  (a hard switch at x 50 cut ponds with a straight wall) and fade out between r 360 and 440.
  `res://scratch/bloombay_shots.tscn` takes a camera velocity (`name:...:frames:gap:vx,vy,vz`) to catch what
  only shows in motion. `res://scratch/terrain_step_scan.gd` (`-s`, headless, `-- [level=] [step=1.5] [shore=1] [column=x,z0,z1]
  [row=z,x0,x1]`) lists steps between neighbouring vertices of a level's saved terrain. Past the
  terrain's square a ring of ground (from its edge, `BACK_R0` 475 on the edges' middles, to `BACK_R1` 3.7km, `BACK_SEGS` 720 round, `BACK_SECTORS` meshes, solid
  inside `BACK_SOLID`) carries on: the beach south along the coast past the wreck, dunes, scrub and hills
  inland, the north coast east along a bay that closes at `BAY_HEAD_X`. Open sea west and north-west. Across
  the bay Bloombay's skyline (`_build_bloombay`, as on Pinecrest Ridge: houses, blocks, downtown towers round
  where the monorail comes in) stands on its shore (`_city_shore`, `CITY_SHORE_Z` -2300), 2-3km from the
  course, inside the cameras' 4000m. `_land_d` says how far inland a point is (negative at sea) for all three
  coasts; `_coast_far` is the far country, `_coast_height` blends the terrain's own (`natural_height`) into it
  from 30m past the square's edge (by the distance past the edge, so the square's corners meet it on the
  terrain's own ground). The ring's rings are distances past the square's edge: one a cell inside, tucked
  0.15m under, then one on the edge at the terrain's own heights, then out (4m apart to 600m, 1.5% a ring to
  1.3km, 3% past it); its angles hit the square's corners. Out to `BACK_SHADE` the ring is drawn in the sand material tinted by vertex colour (`_sand_mean`,
  the texture's mean, is white), past it in plain vertex colour. Keep its sea floor whole (`BACK_DEEP`): water
  over the void past a floor's edge reads darker, and the edge showed from the air.
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
- The grandstand's treads are `STAND_TIER_D` (1.45m) deep with moulded seats (`_stand_seat`: pedestal, pan,
  curved back) at their back (`STAND_SEAT_BACK`), so a seated spectator's feet rest on their own tread; on the
  old 1.05m treads with benches in the middle, legs stood out through the row below. Nosings on the treads,
  half steps with yellow edges up the two aisles, aisle handrails and a front rail.
- The beach huts (`_hut_details`, `_hut_roof_trim`): a panelled door with a louvred vent and knob in a white
  architrave, the hut's number over it (`GLYPHS` has digits now), corner boards and skirting, a shuttered side
  window, a boarded deck with two steps, now and then a towel on a hook or a surfboard by the door; barge
  boards, a ridge cap and a pennant on the roof.
- Parasol sets are rejection-sampled per zone (`PARASOL_ZONES`): `PARASOL_GAP` apart, on dry level sand,
  clear of the track and of every footprint noted before them. The fence is built first for that reason.
- Beach play on the beach section (`_build_beach_play`): beach balls (`KickBall.gd`, see "Kick balls") on the
  racing line (`BEACH_BALLS`, by s), on the dry sand (`BEACH_BALLS_DRY`) and afloat in the shallows
  (`BEACH_BALLS_AFLOAT`, `water_y` 0, `drift` up the beach), and sand toys: buckets, spades and swim rings are
  knockable (`TOY_COLOURS`, push 0: any moving cart frees them; plastic knocks), sandcastles (`_sandcastle`) are scenery in the Umbrellas mesh. Toys lie by some parasol sets
  (`_toy_group`, their own RNG seeded by the set, so the sets' draws stay put) and at `LINE_TOYS` by the line.
- Knocked props sound as what they are (`KnockableProps.Sound`, `bonk_sound`, -1 by the node's name, so no
  level needs regenerating): the crate crash for loungers, a synthesised hollow plastic tok-tok-tok for cones,
  cool boxes and sand toys, a canvas whump and pole ping for parasols (`_synth_sound`), louder the harder
  the hit, carrying like a cart's knock (unit_size 20). At -10dB and unit_size 8 they were lost under the
  engine. `res://scratch/knock_sound_dump.gd` (`-s`, headless, `-- <dir>`) writes them and the balls' kicks
  out as .wav with their levels.
- Traffic cones (anything knockable with "cone" in its name) thud (`KnockableProps.Sound.THUD`, `_synth_thud`: a body
  note gliding 125 to 62Hz, a low-passed thump, two smaller thuds as it lands, at `THUD_DB`). A recording the user
  tried first began with 164ms of silence (heard as a delay). Every KnockableProps node plays through a pool of
  `VOICES` players, and a prop hit again (its speed jumping `REHIT_DV`, `REHIT_GAP` apart) sounds again: with one
  player and one sound per prop, a cart through a row of cones was heard once. `scratch/knock_sound_dump.gd` writes the
  thud out too. CampKit's cone base is a deeper orange (`CONE_BASE`; the user disliked the
  near-black one); the saved cone meshes of Lakeside, Bloombay Dunes and Pinecrest Ridge were recoloured in place by
  `res://scratch/recolor_cone_base.gd` (`-s`, headless, `-- <mesh.res> ...`).
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
    pylon in the road corridor, and runs on off the map 1.9km across the bay into Bloombay (`MONO_FAR_Z`).
    Off the map it has no collision or footprints. Its pylons there stood on nothing, their footings in
    clear water: now they stand on pile caps on a causeway (`_build_causeway`, `DAM_*`), a rubble mound
    whose crest is 1.3m under the surface and whose sides run down at 1:1.6 to the sea bed, in the rocks'
    material, from the north beach to Bloombay's shore; its flanks lower down are the sea bed's sand
    (`_mat("seabed")`), or it read as a dark wedge. The train cruises at 32 m/s for the longer run.
  - The beam's dark conductor band is part of its side faces (`_beam`): laid on as a strip, it
    flickered.
  - South Beach station (`_build_mono_station`) stands at the beach path, so the dune fence's gap
    there is wide. It has a glass vault, a glazed hall and stairs toward the track, kept 5m+ off its
    edge. The landing between the two flights has balustrades on its sides only (one across its far edge
    closed the way down). Its planters (`_planter`: walls, coping, soil) hold small palms (`_planter_palms`,
    planted by `_build_palms` at 0.15-0.18 scale: at 0.25 their crowns reached over the platform's edge),
    flowering shrubs (`_flower_shrub`, leaf cards and five-petal flowers in the canvas material) and dune
    grass tufts (`StationPlanterGrass`); they had been green lumps of `_rock`.
  - Departure boards (`StationBoard.gd`, `_station_board`): over the hall's doors, beside the head of the
    stairs and one hung across the platform (two-sided). A dark panel with amber Label3D text (modulate
    over 1, so the glow takes it): the station and the clock, the next two trains (where to, minutes, DUE,
    BOARDING) and a status line. It reads `Monorail.upcoming()`, the timetable from the same wall clock the
    train runs on, so every peer agrees unsynced; the train's `stop_names` name the stops.
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
- Boats (`_build_boats`, `BOATS`): the yacht at anchor about 110m off the waterline (`super_yacht02.glb`), the low-poly
  cruise ship and two low-poly sailboats (`models/lowpoly/`, bows along +z) are `SeaBoat.gd` nodes: each sails a loop
  (two straights along the node's z, half-circle turns) at its speed, placed from the wall clock like the monorail (LAN
  peers agree), bobbing and rolling, the sailboats heeling away from the wind, an AnimatableBody3D box round each hull.
  `draft` is the waterline over the model's y 0. The generator errors if the sea bed comes within `BOAT_KEEL_CLEAR` of a
  keel anywhere on a loop. The old boxy sailboats are gone.
- The raft (`_build_raft`, `RAFT_*`, Quaternius's inflatable) lies on the sand by the south lifeguard tower, tilted with
  the beach, with a box collider: north of there the lap runs only 15-20m off the waterline
  (`res://scratch/beach_lap_profile.gd`, `-s`, headless, prints the waterline and the lap's x along the beach).
- Seashells (`_build_seashells`, `SHELL_PATCHES`): the model holds a scallop and a conch as two surfaces, split into two
  meshes (`_shell_meshes`; the conch stands on its point in the file and is laid on its side; the file has no normals),
  scattered in eight patches 3-12m up from the waterline, about 60 in all, MultiMeshes per patch drawn to `SHELL_RANGE`.
  Not solid (under DressingColliders' `MIN_HEIGHT`).
- The gull flocks call (`BirdFlock.gd`'s `calls`: `sounds/beach/Seagulls_*.wav` in a shuffled order, a pause of
  `call_gap` between them, from the flock's middle). Each clip's gain brings its measured RMS (`GULL_CALL_RMS`) to
  `GULL_CALL_LEVEL` at `GULL_CALL_UNIT` metres, capped there when nearer (`max_db`). The clips aren't in
  StageAmbience's `CLIP_DB`, so the beach ambience doesn't play them. `res://scratch/sea_life_check.tscn -- [seconds=40]`
  (headless) prints each boat's speed and heading and the calls each flock played.
- Regenerating takes about 30s on the M1. It took 2 minutes while TerrainGenerator's `_sample_cached_height` built
  a new world curve on every call before the terrain existed (each then baked on its first query, and with
  `road_height_from_plan` rebuilt its plan table along the whole lap): the camps' planning samples thousands of
  heights. It keeps the curve now (`_sample_curve`).
- Sand over the road (`_plan_sand_gaps`, `SAND_*`): where the lap runs out onto the beach (west of `BEACH_X`, either
  side of the start) and two stretches in the dunes where sand has drifted across it (`SAND_DRIFTS`: s 530-558 on the
  climb north, 1203-1231 over the third crest) are `TerrainGenerator.road_gaps`. The asphalt breaks up under blown
  sand over the taper and `SAND_LEAD` before each (`road_crumble.gdshader` with the beach's sand texture and tint),
  the curbs stop (`curbs_stop_at_gaps`), the ground runs `SAND_GROUND` under the road's surface with a drift heaped
  across the dune ones (`TerrainGenerator.road_gap_drift`, per gap: 0.45-0.5m in the middle), and the tyres carry sand
  out. PlayerCart counts gaps and tapers as off-road, sand (Surfaces' `"gap"`): about two thirds of a car's speed.
  Before, the dunes buried the road there by accident (up to 1.5m over its edge; the ground graded from the dunes'
  height found a point further up the road) with a ragged edge, and a cart on that sand counted as on asphalt.
  `road_height_from_plan` is on now. The road crumble shader takes 4 gaps: all used. `scratch/pinecrest_road_probe.gd
  -- level=res://levels/BloombayDunesLevel.tscn` lists what is left buried (the drifts, and 0.4m at the inside edge of
  the 7.5m corner at s 1080); `scratch/offroad_speed_probe.tscn ... from=2000 seconds=24` drives from the grid through
  the beach's end and the first drift, printing what the cart stands on.

## Mtaa Nights (Matumaini GP, stage 4)

- `regenerate_mtaa_nights.gd` (`regenerate_mtaa_nights.tscn`, headless, about 30s) builds `levels/MtaaNightsLevel.tscn`: an
  early-evening race through a made-up Nairobi-style district. Kilele Avenue (the start), Biashara Street (the market),
  Mtaa Road (tarmac, then murram through the estate), the park, Mwangaza Road into Club Kilele (an open-air club: its lane
  crosses the LED dancefloor), Kanisa Road (murram, past the church) and back. Music: `Green_Canopy_Dash`,
  `Nairobi_at_Top_Speed`, `Red_Clay_Drift` (`MusicManager.STAGE_TRACKS["mtaa"]`; Mara Crossing shuffles the other
  three unused africa tracks with its own). Mina del Viento has its own: `STAGE_TRACKS["mina"]`,
  `music/canyon/Sun_Scorched_Horizon.mp3`, which the canyon folder's shuffle leaves out
  (`res://scratch/stage_playlist_check.tscn` prints each stage's playlist).
- Every road is a path of straights and arcs (`_fillet`: corner points and radii; `MAIN`, the forks `YARD`, `LAWN`,
  `BACKSTAGE`, the dressing-only `SIDE_STREETS`); everything is placed by (path, s). No road mesh: one heightfield
  (`GRID` 2m, in `TILE` tiles) carries per vertex the distance to the nearest road's edge (a smooth minimum, so junction
  corners are round), the lateral and the distance along that road (`ARRAY_CUSTOM0`, RGBA float), and the surface and zone
  masks; `mtaa_ground.gdshader` paints tarmac and lane lines, murram, gravel, kerbs, pavements, the lawn, bare earth and
  the club's pavers from them. Collision is split per triangle (`BODIES`): AsphaltRoad, MurramRoad, GravelRoad and
  DanceDeck are track; CityPaving, ClubPaving, ParkLawn and BareEarth are off-road. The ground isn't chunked by
  MeshChunker (it would drop CUSTOM0); the generator builds its own tiles.
- The forks are AlternativePaths the AI takes too, each paved against loose: Biashara Street or the jua kali alley (murram,
  a zigzag, whoops, a plank table-top `AlleyJump`), the park's paved path or straight over the lawn (off-road grass: the
  lawn's path is not painted or counted as road, it only shapes its mound and wears a trail), the lane over the
  dancefloor or the backstage road (gravel, the `LoadingJump` kicker). The loose routes are 0.76-0.92 of the paved ones
  (`_verify_forks` prints them and the trunk's paved to murram ratio, about 2:1), so off-road cars take them and road
  cars stay on the tarmac. Checkpoints are only on the trunk (Mtaa Road's murram, Kanisa Road).
  - The alley's corners were 12m and bots coming off the avenue ran straight past its entry; now 16-24m. Bots that miss a
    shortcut anyway drop it and drive on (PlayerCart, before its off-course check: far from the shortcut, inside the lap's
    road), instead of being respawned for straying from it. `scratch/shortcut_probe ... chance=1.0`: no respawns on any fork.
- Buildings fill every ground cell that is neither road, pavement (`_setback`: the market's 13m holds the stalls) nor an
  open place (`PARK`, `CLUB`, `CHURCH`): greedy rectangles (`_plan_buildings`), styled by district (`_style_at`), each a box
  collider, so no block can be driven through. They use `city_building.gdshader` with its evening lights on (`lit_share`,
  `lit_color`, `lit_energy`: lit rooms, open shops, glowing sign bands, office floors). Those uniforms default to 0, so
  Nyota Stadium is unchanged. Past the detailed ground, `_build_far_city` lays a skyline of boxes (a business district to
  the north-east), and `_build_hills` the hills round the horizon: low rolling country, and under the sunset an
  Ngong-like ridge (`HILL_KNUCKLES`: four rounded knuckles on one long back, steep at its south end, sinking slowly
  north), a polar heightfield of 720 columns and 20 rings with a wandering crest and gullies cut by noise
  (`_hill_height`). The knuckles had been |sin| humps three vertices wide on four rings: pyramids. `HILL_PEAK` (270)
  keeps them under the sun's disc from the west of the course.
- Club Kilele (`_build_club`): mural walls, neon gate arches (Label3D, unshaded, HDR modulate so they bloom), a stage with a
  truss, the LED wall (`club_screen.gdshader`), the DJ booth, the VIP deck, bars, festoon bulbs (`neon_emissive.gdshader`),
  the dancefloor (`club_dancefloor.gdshader`: tiles in patterns on the beat, white under the carts) with the ground left out
  under it. `ClubLights.gd` runs the show on the wall clock (LAN peers agree): 16 moving heads with additive beam cones
  (`club_beam.gdshader`, instance uniforms `tint`, `strength`), 8 lasers, 6 coloured washes; it feeds the floor the carts'
  positions. Slow sweeps and a soft swell on the beat, never a strobe (motion comfort).
- Jacarandas are Nyota Stadium's saved tree meshes (`generated/nyota_tree_*.res`): regenerate Nyota first if they're missing.
- Cost (M1, 1600x1000, `scratch/bench.tscn`): 13.5ms GPU, 413 draws (Nyota 12.0ms, 416).
- `scratch/ai_race_test`: 6 bots finish 3 laps at speed 2; the odd bot runs wide onto the pavement at the market corner.
- Generators that loop must advance their loop variable: `_build_far_city` once didn't, ate the machine's memory and
  rebooted the Mac twice. Run new generators under a memory watchdog (kill Godot past a few GB).

## Msitu Falls (Matumaini GP, stage 3)

- Auto's Detail Level steps (MusicManager `_check_auto_grass_quality`, Low to Ultra) must never change the light. At
  Low, JungleDetail turned the canopy's shadows off and flattened the ground (`TREE_SHADOWS`, `FINE_GROUND`): where 4x
  MSAA (or anything slower) pushed Auto down around the green light, the shaded forest floor and road went bright and
  washed out; at 2x and FXAA Auto stayed at Medium. Low now keeps the stand-in's shadows and the ground; only Off (a
  manual setting) drops them. Auto also remembers the level it settled on per stage and display setup
  (`user://auto_detail.cfg`, `_auto_memory_key`: stage, anti-aliasing, resolution, render scale, window mode,
  renderer) and starts there, not at High every race. `res://scratch/msaa_brightness_probe.tscn -- [<dir>] [level=]
  [aa=2] [detail=N] [noread]` (windowed) runs a GP race at an anti-aliasing setting and logs the phase, frame rate and
  the frame's brightness (saving frames with a dir).

- The sky is `sky_tropical_cumulus.gdshader`, static like the others (no `TIME`). The storm transition
  is driven smoothly per frame by `JungleRain.gd` via the `rain_sky_blend` global shader parameter, blending
  `sky_top`, `sky_horizon`, `cloud_*`, `sun_glow` and `sky_energy` toward storm values without triggering
  radiance map rebuild stalls or stepping. `cloud_coverage` past ~0.65 closes it into a dark overcast deck
  on its own.
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
- The bamboo marker posts (`_build_marker_posts`) stand 2m off the road's edge, or 1.2m if that's steep, on
  ground under a 0.55 slope and within 1.5m of the road's height (`_post_spot`), else not at all: behind
  the falls the verge runs into the cliff's foot, and three posts stood 3-9m up its face.
- Don't put "road", "track", "ramp", "bridge", "deck", "jump", "curb", "pier", "gate" or "checkpoint" in the
  name of anything with collision: `PlayerCart._is_track_surface` treats it as drivable.
- `res://scratch/ranger_post_preview.gd` (run with `-s`, windowed, `-- <dir> name:x,y,z:tx,ty,tz ...`) renders the post
  on flat ground in a few seconds, without generating the level.

## AI shortcuts (AlternativePaths)

- A level's shortcuts are the Path3D children of its `AlternativePaths` (Level.gd collects them). A bot rolls
  once, `AI_ROUTE_DECIDE` (45m) before a shortcut's start, whether it takes it (`ai_shortcut_chance`); one
  that does lines up with the start (`_ai_pending_route`: the lane offset eases toward the start's side,
  kept 2.2m inside the road's half width) and switches onto it within 12m of it. Deciding 14m out, bots took
  Glacier Highway's forks from the far lane at full speed.
- On a shortcut the AI samples one route (`_ai_route_local`): the shortcut, then on along the lap from where
  it rejoins (`_ai_rejoin_offset`). The aim point, the turn ahead (`_ai_measure_upcoming_turn`) and the road
  limits all go through it. They used to wrap round the shortcut with fmod: within a look-ahead of its end
  the aim point jumped back to its start and the bots swerved off (Lakeside's two ran into the lakes).
- A route with an `ai_lane_limit` meta (Northlight's Thin Ice) is driven tightly: at most `AI_TIGHT_SPEED`
  (18 m/s, boost or not), aiming 10-16m ahead, steering against sliding across the line (`AI_TIGHT_DAMP`; on
  the ice, aiming the nose alone swung bots 5m either side of the weave into the holes), and ignoring the
  layer-4 markers it's laid to clear. 40 of 55 bots had drowned there; now about 1 in 20.
- A route's `ai_lane_ends` meta (Vector2: metres at its start and at its end) holds a bot to its line there
  (`AI_LANE_ENDS_HOLD`, easing out over `AI_LANE_ENDS_EASE`), at full speed: Glacier Highway's ramps, whose ends share
  the trunk's paving and leave it through a gap in its barrier. Switching onto a ramp, bots had kept their own lane
  offset (up to 3.2m) and missed the gap.
- A bot respawned while on a shortcut doesn't take that shortcut again for `AI_ROUTE_SHUN_MSEC` (60s, `_ai_route_shunned`):
  re-rolling at every respawn, one fell off Glacier Highway's Ridge Bypass five times running.
- A boost no longer skips braking for a sharp corner ("let the boost rip" only for bends under 1.6 times
  `react_corner`): a boosted bot met Glacier Highway's Ridge Bypass fork, 84 degrees, at 60 m/s.
- `res://scratch/shortcut_probe.tscn -- <level> [seconds=180] [speed=2] [static=1] [chance=1.0] [trace=<name>]`
  checks each shortcut (ends against the lap, water, drops, solid things on the line) and races bots that
  take every one, listing where any falls, drowns or sticks (and where it was 0.5s before); `trace=` logs a
  shortcut's riders every 0.2s (off the line, speed, the turn ahead, boosting). `res://scratch/colliders_near.tscn
  -- <level> x,y,z ... [radius=3] [route=<path>:<s0>:<s1>[:half]]` lists what is solid at a spot, and what a
  ray down a route meets. `res://scratch/path_overlay_shots.tscn -- <level> <dir> name:x,y,z:tx,ty,tz[:fov]`
  renders a level with its lap (white), shortcuts (yellow) and other paths (cyan) drawn over it.
- Still on the main laps (not shortcuts): Lakeside loses a few round its lakes, scattered.

## Bots off the course

- A bot finds its way back to the road when it is off the course (beyond `_is_car_on_track_corridor`, on the ground,
  on grass or on a surface named as road more than `AI_OFF_LAP_PLAN` (16m) from its route in plan: Glacier Highway's
  other decks counted as road), or on grass inside the corridor with the way to its usual aim point blocked
  (`_ai_line_drivable` looked at every `AI_BLOCK_CHECK`: just outside Pinecrest's guardrails, 8.5m off the line,
  bots counted as on the course and drove along the rails for the road; not checked within the road's half width of the
  line, the lap's own ground: on Pinecrest's forest trail a tree beside a bend blocked the line, and bots on the trail
  went into recovery, crawled and were respawned as stuck), and for as long as a way back is being followed, until it
  is on the road again. `_ai_rejoin_goal`:
  - a straight line first (`_ai_direct_rejoin`): road points from `AI_REJOIN_BACK` behind to `AI_REJOIN_AHEAD` ahead,
    best first, the first whose line `_ai_line_drivable` passes, kept while its line stays drivable. A line is drivable
    when, every `AI_LINE_STEP`, the ground under it (a ray down) is there, out of deep water (`_deep_water_at`), climbs
    no more than `AI_LINE_MAX_RISE` a metre and drops no more than `AI_LINE_MAX_DROP`, and nothing long stands across
    it at a cart's height (`_ai_step_barred`: rays at 0.35 and 0.8m over the ground; one at 0.7m passed over a
    guardrail from the higher side of a cut). A narrow thing (`_ai_narrow_obstacle`: 2.2m either way along its face,
    and across the ray's own direction, a short ray finds nothing solid but track and ground: a lone trunk, a post, a
    rock) the avoidance steers round, and the ray goes on from behind it; a rail, a fence, a wall or a cluster of
    boulders bars it. What went wrong before: testing lines 1.6m either side let a guardrail met at a shallow angle pass;
    looking for the same collider only let Pinecrest's boulders (one body) pass in clusters; stopping at the first hit,
    a chevron board hid the summit tyre wall behind it; and along the face only, a ray into the notch where two of a
    guardrail's boxes meet on a bend hit an end face and the rail passed for a post.
  - else a way round (`RejoinPlanner.gd`): a Dijkstra search over a 3m grid round the bot, probing as it goes: a cell
    is the ground a ray down finds there (from just over the height it was reached at, so a bridge overhead isn't the
    ground), blocked in deep water, on a prop's top or too steep; a step between cells is blocked where it climbs more
    than `CLIMB` a metre, drops more than `DROP` or meets something long at bumper height; a goal is a drivable cell on
    the lap (within the road's half width of its line in plan: on the road, or on the ground where a stage has none),
    one behind the bot costing `BEHIND_COST` a metre. A ground cell with something standing within `TIGHT_R` of a cart
    there costs `TIGHT_COST` times as much (`_tight`): a way had run between a guardrail and the chevron boards 2m behind
    it (the cart is 2.7m across) and the bot wedged there. The bot follows the way to its end (`_ai_follow_way_back`) at
    most `AI_WAY_BACK_SPEED` (13 m/s, slower into its sharp turns: at full speed bots overshot its turns and circled), and
    is respawned when no road is in reach (`MAX_RADIUS` 80m, `MAX_EXPAND` 6000 cells: at 2600 searches on Pinecrest's
    summit hillside, where cells stack in height bands, gave up with a way there). A bot that gets no metre nearer the point it is heading for
    in `AI_WAY_BACK_STALL` (2s) closes that step for every search on the level for `CLOSE_MSEC` (20s:
    `RejoinPlanner.close_step`) and plans again. Closed for good, steps closed where another cart was in the way sealed
    bots in behind Pinecrest's summit tyre wall over a race. Probes and what each collider is are cached per level, and all searches share `FRAME_USEC` (1.2ms) a physics
    frame. No boosting while finding a way back (it overshot every turn of it).
  - Off the course with the way on behind it and something solid within 2.6m of its nose (`_ai_back_turn`), a bot backs
    away turning toward it for `AI_BACK_TURN_TIME` (arcade reverse: steering right turns the nose right). Turning forward
    on full lock, bots nosed into Pinecrest's rails ground along them for seconds.
  - Before: the goal was the nearest road point whatever lay between, so bots ground along barriers, or took goals
    behind and ahead in turn ("brake, turn round, drive back, hit a wall, turn again"); with the road up a bank they
    wandered across country for the next gate.
- Never count a bot as off the course for being high over its route: on a kicker's lip or in the air off it, a bot is
  metres above the lap's line (the corridor allows 5m), and when height alone took it for lost, every bot braked on the
  jumps and turned for a road point behind or beside it (all those ahead were drops) and drove off into the ponds.
  `ai_race_test` prints each jump lip's crossing speeds (`LIP`, from TrackPath's `jump_lips`) and `REJOIN-ON-ROAD` when
  a bot is in recovery while over the road; the recovery state is cleared whenever the bot is on the course.
- `res://scratch/ai_rejoin_probe.tscn -- <level> x,z[,yaw] ... [auto=N] [rails=N] [rails_steep=1] [forest=N] [seconds=25]
  [trace=1]` (headless) drops one bot off the course at each spot, facing away from the road (`auto=N`: N spots along the
  lap 20-30m out on dry ground; `rails=N`: N spots 3.5m outside the level's guardrails, facing the rail, `rails_steep=1`
  where the ground behind them is steepest; `forest=N`: N spots among the trees) and prints when it was back on the road or
  respawned, how long it crawled (under 3 m/s: grinding or stuck), how far it drove, and the planner's time (in all and
  its busiest frame). Against the first version (nearest road point): Pinecrest's guardrail spots 8/8 back (most in 1-4s,
  the longest drives 100m round a rail to its end; two had been lost after 25s), Lakeside 9/10 within 3s (was 7/10, up
  to 11s and 267m), Glacier Highway, the Canyon and Msitu Falls likewise (the jungle is the hardest: now and then a bot
  crawls among the trunks and the "confined" rule respawns it). Pinecrest with `rails=10 rails_steep=1 forest=8`: 15 of
  18 back within 10s, the rest respawned within 3s (before the fixes above: two timeouts, bots circling outside the
  rails and wedged behind the summit tyre wall).
  `res://scratch/rejoin_plan_probe.tscn -- <level> x,y,z ...` (headless) prints the way the planner finds from each spot
  and, for each step, what the bumper rays meet and whether each counted as narrow (and what its side rays found);
  `scratch/rail_boxes_near.gd` (`-s`, headless, `-- <level> x,z [radius=10] [match=Guardrail]`) lists a body's boxes
  near a spot with their ends, to see where a run of rail stops.

## AI corner speeds

- A cart's heading turns at most `steer_speed` rad/s (above 10 m/s) and its grip only damps its sideways velocity
  (`-lat_vel x grip`, no lateral-g limit), so the path's radius can be as small as v / steer_speed. The AI plans a corner
  by its radius: `_ai_measure_upcoming_turn` also returns the tightest curvature ahead (`kappa`: the heading's change
  over 6m), and the safe speed is at least `AI_YAW_USE` (0.5) x `steer_speed` x R (times the root of the surface's
  grip), up to the top speed. By the heading's change alone (`corner_factor`) a 75m sweeper was taken as slowly as a
  12m corner, about 13-16 m/s.
- `is_hairpin` (shorter aim, the lane offset damped, a 10 m/s cap, a longer braking window, no drifting) is a corner sharp
  within 20m or turning over 72 degrees ahead *and* tighter than 25m: on the angle alone every 90-degree bend counted.
  A right angle (under 110 degrees) may still go at 0.85 of its radius' speed; true hairpins keep the cap.
- Measured (`scratch/ai_race_test ... speed=2 cars=5,16,0,3,8,12 noitems=1`, flying laps' mean): Marina Nights 75.2s ->
  72.7s, Glacier Highway 59.2 -> 53.1 (non-item falls 13 -> 7), Pinecrest Ridge and Lakeside Meadows the same within the
  noise, no new respawns. At 0.6 Glacier Highway's falls tripled.

## AI boosts

- A bot fires a boost item when recovering (slow or off the road) or on an open stretch (`_process_ai_items`), never with a
  sharp turn within 26m, and not while a corner of more than 50 degrees (0.9 rad) lies within 105m of its route
  (`_ai_measure_upcoming_turn` with a 110m look, from `_ai_turn_offset`): a boost carries a cart 80-120m, and the turn
  ahead is measured only `speed` x 1.8 metres out (30m out of a slow corner), so out of one of Marina Nights' souk
  corners bots fired one and met the next at 60 m/s.

## AI drifting

- Bots drift some corners: braking for a corner they could drift (fast enough, sharp enough, steering into it), they
  decide once a corner (`_ai_drift_corner`, 40m buckets of the lap) with their `ai_drift_chance` (0.25-0.85 by
  aggression) and then hold the slide as a player does: on the throttle while the road just ahead still turns more than
  `AI_DRIFT_HOLD_ANGLE` or they steer hard, until it straightens (or the charge reaches 2s), which releases it and its
  boost. The release paths a player has (counter-steer, straightening the wheel, letting go of the controls) don't end an
  AI's drift. Before, the drift ended as soon as braking did: a third of a second each, which nobody saw. Never on Harbor
  Pier, never into a hairpin (`is_hairpin`) on any stage, decided or held, and never within `AI_DRIFT_EDGE` (2m) of the
  road's edge (`_ai_drift_room`): drifting Pinecrest's switchbacks threw six bots a race over their edges and the summit
  tyre wall. `ai_race_test` prints each cart's drifts and their time (Bloombay 7-26 a race, Pinecrest 10-27) and takes
  `nodrift=1`. A bot drifts only a corner whose outside is safe (`_ai_drift_safe`: just past the road's edge on the
  outside, at the apex and over the 36m after it, the ground is there, not more than `AI_DRIFT_DROP` (1.5m) under the
  road and not deep water): drifting wherever it could, bots slid off Glacier Highway (14 falls a race against 1 with
  drifting off) and Frostpeak Creek (8 against 2); with the check Glacier had 5. A drift also ends by the clock
  (`_drift_age`, `AI_DRIFT_MAX_AGE` 3s) and once the bot no longer wants it after 0.6s: the charge only builds on the
  ground over 4 m/s, so a slow or airborne drift never ended (91s of drifting in one Tolvanera race, turning in circles).
  `ai_race_test` prints `LONG DRIFT` for any held over 4s. Pinecrest at speed 2: every bot finishes, one or two respawns a race that aren't items, mostly at
  switchback 2 (about 488m) and the summit hairpin (608-670m), with or without drifting.

## Car weights

- Each preset has a `weight` (0.85 Fulmine to 1.25 Titan; trucks and crawlers heavy, coupés, buggies and the sand rail
  light) and the cart's mass is `PlayerCart.BASE_MASS` (1200) times it. Every driving force in PlayerCart scales with the
  mass, so a car drives the same whatever it weighs; what changes is contact (`CartWeight.gd`): cart against cart
  (physics: a heavy car shoves a light one), props that are rigid bodies (KnockableProps, freed at `push_speed` / weight),
  and the scripted knocks: KickBall (kicked `push_share` harder, `loss_share` of the slow), SpringProps' flags and tyre
  stacks, DressingColliders' brush and plant wobble, Tumbleweeds, KnockableRocks, KnockablePoles' launch, the
  wildebeest herd. The shockwave and missile and bomb blasts give every car the same push (`BASE_MASS` times the old
  speed), so the speed it gets goes as one over the weight. Gusts, the tornado and the haboob scale with the mass and
  treat every car alike. About 15-25% either way: felt, not race-deciding. CarSelection shows it as a WEIGHT bar (read
  from PlayerCart's presets). `kick_ball_test` takes `weight=`.

## Carts on the loop

- On the loop (`is_on_loop`) the ground ray points at the loop's surface along its last normal (`_loop_last_normal`), not
  down the model's up, and the model turns to that surface at `LOOP_ALIGN_RATE` (40 a second, once, not up then basis)
  with its nose along the velocity, turned off it by what the steering turned it up to `LOOP_STEER_ANGLE` (0.45 rad:
  with the nose along the velocity alone, steering did nothing on the loop, since the drive pushes along the nose): smoothed as on a hill the model ran 30-40 degrees behind the loop's turn, standing off
  it, and the ray missed the surface (airborne: tumbling, landing sounds). No crash or landing sound from the loop's own
  surface, and a contact facing the way the ground under the cart does is floor, not a wall (round the loop the floor
  faces sideways and down, and played the crash every 0.6s). `res://scratch/loop_ai_probe.tscn` prints, at the end, the
  angle between the model's up and the loop surface under it (now 3.5 degrees on average, the worst 12; was 31), frames
  the ground ray missed and the bump/landing sounds played.

## Breakable chevron signs (BreakableSigns.gd)

- The chevron boards round the corners (Msitu Falls' `Chevrons/ChevronBoards` and `ChevronPosts`, Pinecrest Ridge's
  `Chevrons/ChevronSigns`) break off when hit. Level.gd adds `BreakableSigns.gd` with its runtime colliders, before
  DressingColliders; no level needs regenerating. The generators merge every board of a level into one mesh, so at load
  its triangles are split per sign (middles within `LINK` in plan; 38 on Msitu, 34 on Pinecrest), each sign a node of
  its own with its meshes re-centred and a convex hull (`SignBody`); the merged meshes and Pinecrest's
  `ChevronSignsBody` boxes are freed.
- A cart over `BREAK_SPEED` (5 m/s) coming at a sign knocks it off a step before it would touch (its speed from how far
  it moved, so every peer breaks the signs it sees hit; nothing synced): the collider goes, the cart loses `DRAG` (5%),
  the sign flies along the cart's travel with a hop, tumbling end over end about its long axis, bounces and eases down
  lying face up or down, and stays for the race. Slower, it is solid. The knock is `crate_crash` for Msitu's timber
  boards, the clank for Pinecrest's steel. Its landing ray skips plant, rock and trunk colliders (a sign came to rest on
  a shrub's box 1.8m up).
- `res://scratch/break_test.tscn -- [<dir>] [kind=sign|fern] [level=] [index=0] [speed=22]` drives a real cart into a
  sign or a fern near the lap and logs the flight (windowed with a dir: frames from beside it).

## The race start: grid, reveal and intro

- The stage opens on the intro's first frame with the grid already landed. Main sets the level's
  `hold_start_for_reveal` before adding it, waits after the collisions for `Level.wait_for_grid()` (the carts' 5m spawn
  drop over, `GRID_SETTLE_MAX`; every local cart has planned its intro, `prepare_intro`, and holds its first pose), hides
  the loading screen, then calls `screen_revealed()`; the race starts `REVEAL_HOLD` later, as the swipe clears. A test
  harness that instantiates a level itself never sets the hold and starts 0.4s after the grid lands. Before, the race
  started 0.4s after `_ready`, so the reveal showed the carts falling onto the grid, then the orbit began.
- The intro (`StartIntroCamera.gd`, PlayerCart's `prepare_intro`, `start_intro_animation`, `_apply_intro_camera`,
  `Level.INTRO_SECONDS` 4s): a path in polar coordinates about the player's car on one smootherstep, from a wide high
  start round to the race camera, ending exactly on it. The race camera keeps running under the move from its own last
  pose (`_intro_race_pos`), put on its rest pose when the move is planned (it had been following the drop and swung
  the sweep with it), and the last quarter blends onto it: no snap at the hand-over. The old orbit was always the same
  180 degrees in world axes, starting at full speed, ending at a fixed world offset the race camera snapped from.
- `choose` scores each start (both sides, sweeps of 150/100/60 degrees at two heights, straight in from far behind and
  low, a crane from 58m up) along its path: the line of sight blocked, the camera inside something or under the ground,
  and trees (crowns have no collider: a trunk body within `CROWN_R` of the ground under a low point of the line counts).
  Lakeside and most stages take the 150-degree sweep; Mtaa Nights' street between houses comes straight in down the
  street from 80m back, 16m up (the crane looked straight down into it). It prints `[Intro] <start> (blocked ...)`.
- `res://scratch/start_intro_test.tscn -- [<dir>] [cup=] [stage=] [mode=chase|top|follow] [trace] [shots=0,0.25,...]`
  (windowed, `--fixed-fps 60`) runs Main's real start-up: FAIL if a cart is seen dropping after the reveal, and the
  camera's top speed, turn rate and worst velocity jump through the move (Lakeside: 46 m/s, 68 deg/s, 66 m/s^2, 0 at the
  hand-over).

## Race cameras

- Three modes (`MusicManager.CameraMode`, the menus' order), cycled with C and saved as `camera_mode` (an old
  `use_isometric_camera` = false loads as Follower, true as High Chase). The menus call them Chase, High and
  Close (`CAMERA_MODE_NAMES`); the code keeps High Chase / Top Down (`is_isometric`) / Follower:
  - High Chase (`is_high_chase`, the default): `CHASE_BACK` 14m behind and `CHASE_UP` 10m over the cart
    (about 35 degrees down to it, the horizon still in the frame's top), lens `CHASE_FOV`, a boost widening it
    only 2-3 degrees. Its heading (`_chase_yaw`, `_update_chase_heading`) follows the cart's velocity (its nose
    when slow or reversing) on a critically damped spring (`CHASE_YAW_RATE` 4.5, turn rate capped at
    `CHASE_YAW_MAX` 2.2 rad/s: it was 3.0 and 1.2 and the user found it too slow in corners), so a pan eases
    in and out; easing the angle itself started and stopped the turn at once.
    The camera's position and aim are both eased at the same rate from the same smoothed point, so the view
    turns only with that heading, never with the cart's wobbles. Its height eases after the cart's
    (`CHASE_Y_RATE`, within `CHASE_Y_ABOVE`/`CHASE_Y_BELOW`). It rides at the checkpoint trusses' and start
    gantry's height (it used to stay under the banners at 5.4m, which the user found too low): the gates'
    materials, the banner text and the gantry's LED screen dissolve within `CheckpointGate.CAMERA_FADE_*` (2-5m)
    of a camera (pixel dither, still opaque).
  - Top Down (`is_isometric`, "High" in the menus) sits at `TOPDOWN_OFFSET` (-30, 42, 30) in world axes, about
    45 degrees down (68 had been too steep to read as a view of the road), with a 44 degree lens
    (`TOPDOWN_FOV`). It never turns: it looks along the offset at a point led ahead of the cart along its
    travel (`_update_topdown_lead`: `TOPDOWN_LEAD_BASE` 12m along the velocity, else the nose, plus
    `TOPDOWN_LEAD_TIME` x speed, at most `TOPDOWN_LEAD_MAX`, eased by a critically damped spring
    `TOPDOWN_LEAD_RATE`), so the car rides toward the far side of the frame from where it is heading and
    the road ahead fills the rest. `_fit_topdown_lead` scales the lead down until the car stays within
    `TOPDOWN_CAR_FRAME` (0.55) of the half width and half height from the middle, worked out from the lens,
    the viewport's shape (a split-screen half is narrower: `scratch/coop_high_cam_check.tscn`) and the
    perspective (a lead toward the view's depth brings the car nearer the camera). The first version led
    along the road with no limit and a cut across the view put the car out of the frame (1.5 half widths
    out); the second, depth-only, kept the car centred sideways, which the user said "still centres the car".
    A corner slides the car across the frame over a second or two (95th percentile 0.3 half-screens a
    second). It used to aim 11-24m along the nose, which swung the view with every steering input.
  - Both made the user dizzy before these changes (motion comfort matters here): terrain pulling a raised
    camera in now eases in at `RAISED_CAM_PULL_RATE` and out at `RAISED_CAM_RELEASE_RATE`, not a 15/s snap.
    `res://scratch/race_cam_motion_probe.tscn -- [level=] [mode=chase|top|follow] [cart=0] [seconds=60]`
    (headless, `--fixed-fps 60`) rides along with an AI cart and prints the camera's turn rate, its
    acceleration, the shake, pitch, FOV and where the cart sits on screen, plus `EDGE` lines when it nears
    the frame's edge. On Lakeside the Top Down's mean turn rate went from 11.4 to 1.1 deg/s.
  - Follower trails 5.2-6.8m behind; see the splash shot under Deep water.
- See-through in the raised cameras (`camera_xray.gdshaderinc`): the tree, palm, spruce, cactus and rock
  shaders (`tree_bark`, `acacia_leaves`, `palm_*`, `spruce*`, `cactus`, `granite_rock`, `canyon_rock`) dither
  away up to 72% of their pixels in a tube from the camera to the cart (`XRAY_RADIUS_*`). PlayerCart feeds the
  globals `xray_cam_a/b`, `xray_car_a/b` (project.godot `[shader_globals]`, slot b for split screen's player 2)
  in `_update_xray_globals`. A slot applies to a view whose camera is within 4m of it: physics interpolation
  draws the camera behind where `_process` put it, and a 0.25m match never fired at speed. Shadow passes
  (orthographic) are skipped. A new plant or rock shader includes it and calls `xray_hidden()` first in
  fragment(). The old `_update_camera_xray` sets `GeometryInstance3D.transparency`, which the Mobile renderer
  ignores, and MultiMesh instances can't be faded one by one anyway; StandardMaterial props (Hunyuan models)
  aren't covered.
- `res://scratch/race_cam_shots.tscn -- <dir> [level=] [mode=top|follow] [cart=0] [every=4] [count=6]`
  (windowed) rides along with an AI cart through its own race camera and saves frames.
  `scratch/look_shots` takes a lens per shot (`name:x,y,z:tx,ty,tz:fov`).

## Slipstream

- `PlayerCart._update_slipstream`: a cart within `SLIPSTREAM_RANGE` (26m) behind another, inside a wake `SLIPSTREAM_WIDTH`
  (1.3m) either side of its line that widens by `SLIPSTREAM_WIDEN` a metre of gap, both above `SLIPSTREAM_MIN_SPEED`
  (18 m/s) and heading the same way, builds a `_draft` (0..1, deeper the closer it follows; up at `SLIPSTREAM_RISE`,
  down at `SLIPSTREAM_FALL`). It raises the speed cap (`speed_cap`, `effective_max`) by up to `SLIPSTREAM_GAIN` (6%)
  and the drive force by up to `SLIPSTREAM_PULL`. No HUD, sound or effect shows it. The wake is looked up every
  `SLIPSTREAM_CHECK` (0.2s, staggered per cart) by carts this peer drives, bots too: a loop over the carts, no rays.
  Boosting carts neither take nor get it.
- `res://scratch/slipstream_probe.tscn -- [level=] [car=5] [seconds=60]` (headless) drives the human flat out on the
  line in a GP with bots and logs speed against the cap, the draft and the gap ahead; then how long each cart drafted.
  On Lakeside the human ran at about 1.07 of its cap in a draft (1.00-1.02 out of one); bots drafted 7-30% of a race.

## The garage (Garage.gd)

- A walk-in car collection, from the main menu's GARAGE tile (`MainMenu.garage_pressed`, `Main._on_menu_garage_pressed`:
  built under the loading screen, since it loads every car; `finished` swipes back to the menu, waiting out a swipe
  still running). Built in code in its own world (a SubViewport), like the podium; first person (a CharacterBody3D).
- Scale: the walker and the building are life size; the cars are large-scale RC cars. On the courses people and props
  stand at 1.6 times life size beside the cars (`PROP_SCALE`, Lakeside's spectators about 2.85m), so a car here is its
  race size over 1.6 (`SHOW_SCALE`): about 1.4m long. At 1.8 times race size (the first version) they read as real cars.
  Each stands on a plinth at table height (`DAIS_H` 0.7) with a two-post lift of its own size and a plaque on its front.
- The hall grows with the collection: the entrance (glazed double doors, locked, `_build_entrance`; outside a canopy,
  a forecourt, a road, lawns, trees and a `LogoFlag`, room for more places later), the foyer (the player's car,
  `NetworkManager.local_car_index`, on a turntable), the concourse under a glass gable roof (`_build_roof`) with a
  gallery per category off either side in pairs (`SLOT` apart), each as long as its cars need (`G_ENTRY`, `BAY`,
  `G_END`), and the trophy hall, whose front wall and the entrance wall (`TALL_H`) close the roof's gables. Categories
  are `CarCollection.CATEGORIES` (by preset name); a car none names goes into "New Arrivals". Cars are in the player's
  saved paint, angled toward the way in. Walls are cut into pieces of 8m at most and floors into 8m tiles, so no mesh
  takes in more lights than the mobile renderer gives one. `garage_floor.gdshader` is polished concrete (and the
  forecourt's paving) in world space.
- `garage_sky.gdshader` is two skies: the radiance cubemap (`AT_CUBEMAP_PASS`: reflections and ambient) is the car
  select screen's studio, so the paint keeps its soft-box highlights in the closed galleries; what the eye sees through
  the roof and the doors is a summer sky with cumulus and the sun. The sun (a DirectionalLight) lights only
  `SUN_LAYER` (`_sunlit`: the concourse floor, the roof's steel, the foyer, the outside) and shines straight down the
  concourse, so it never reaches the galleries through their roofs or the walls' gallery sides with shadows off.
- Signs are boards with their text fitted to their width (`_sign`, `_text`'s `max_w`): the first version's free text
  ran into the next line, past its door ("4X4 & MONSTERS") and into the trophy hall's logo. The trophy hall's back
  wall has only the logo and the tally (its door's sign names it), above the cases as seen from the door.
- The line-up (`CarCollection.gd`): the cars the car select screen offers, saved as the cars left out (settings.cfg
  `[garage] hidden_cars`), so new cars join it by themselves; never empty. Looking at a car (within `REACH`, `AIM_CONE`,
  no wall between) and pressing E (pad A) puts it in or out: the plinth's band lights in the gallery's colour and the
  spotlight comes up, or the band goes grey and the light dims. CarSelection re-reads the line-up whenever it shows
  (`_refresh_lineup`: pills only for those cars, stepping through them; car indices stay the presets' own).
- F (pad Y) lifts the car (`LIFT_TIME`): the carriages rise to its underside (`_underside`: the body's lowest vertex
  between the axles, not the wheels), then car and arms together by `LIFT_HEIGHT`, and the camera orbits it from any
  side and from below (kept over the plinth's top and out of the walls), an inspection lamp under it lit while it is
  up. The camera blends between the eye and the orbit (`CAM_BLEND_TIME`).
- Walking (`_update_steps`): a light head bob and footsteps (`sounds/garage/footstep_1/2.mp3`, alternating feet, pitch
  and level varied), a step every `STEP_LENGTH` (0.95m; `STEP_LENGTH_RUN` 1.55m running: about 3 and 3.7 a second).
  The head dips `BOB_DROP` (1.8cm; `BOB_RUN` times running) as each foot lands and sways `BOB_SWAY` over it, no roll,
  easing in and out with the speed (motion comfort: the user asked for a light one). `res://scratch/garage_steps_test.tscn`
  (headless, `--fixed-fps 60`) walks and runs with real key events and prints the cadence, dip and sway.
- Time trial records (`TimeTrialRecords.gd`): a board per Grand Prix on the trophy hall's side walls
  (`_build_record_boards`, `RECORD_BOARD_*`), each stage's best run and best lap, the car and date, reading round the
  hall from the door (down the left wall, the cups, back up the right). `garage_shots ... trophies=demo` records
  made-up runs too (and prints where the hall is).
- Trophies (`Trophies.gd`, user://trophies.cfg): `Main._show_gp_podium_impl` records one per finished Grand Prix for
  the best local place in the top three (`Podium.local_names()`), only if it started from stage 1
  (`NetworkManager.gp_trophy_eligible`, cleared by GP TEST from a later stage). The hall shows a pedestal per cup
  (`NetworkManager.GP_CUPS`) with the best trophy (Podium's cup mesh) in a glass case or a grey ghost, the counts and
  the car, and the tally under the logo.
  - The case (`CASE_*`, `_build_pedestal`): a round glass case on a steel foot, the cup on a velvet dais, a lid with a
    ring of light under it. The old one was a glass box whose floor lay in the column's top plane and flickered: the
    foot, the dais and the glass have no bottom faces (`_cyl`) and start inside what they stand on. The glass draws in
    two (`case_back` before the ghost cup, `case_front` after, by render priority), or the three swapped places as the
    camera moved. The plaque (`PLAQUE_*`) is a frosted glass plate leaning back in a chrome clamp on a steel ledge out of
    the column, its text drawn after the glass (`_on_glass`, render priority 2); before, the text stood in the air 5-35cm
    in front of the round column. `garage_shots ... cam:` two views 2cm apart and a diff showed the old floor's stripes.
- Sounds (`GARAGE_SOUNDS`, 3D at each bay, `SOUND_UNIT`): a lift rising runs the power unit's hum and one lowering the
  fluid's hiss (loops, louder and higher with the carriage's speed, `HUM_FADE`), a safety lock clacks every `LOCK_STEP`
  of the rise (alternate posts), the locks release as it starts down, a clunk at the top, a thud at the bottom; reversed
  mid-way the hums hand over. A car joining or leaving the line-up switches its plinth's lights on or off (they replaced
  the UI confirm, and the lift replaced the F press's UI blip). Made with tools/elevenlabs (`garage_*` jobs) and readied
  by `scratch/garage_sound_prep.py` (mono, the lead-in cut, raised: they came 25-45 dB quiet); the clack is synthesised
  (`scratch/garage_lock_click.py`). `res://scratch/garage_sound_check.tscn` (headless, `--fixed-fps 60`) runs a lift up,
  down and reversed and the line-up out and in, and prints every sound with its level and place.
- Cost (M1, 2880x1800): 60 fps, 6.8-10.9ms GPU (the most at the entrance, looking through the roof). Touch has no
  controls in it yet.
- `res://scratch/garage_shots.tscn -- <dir> [trophies=demo] walk:<name>:x,z:yaw[:pitch] inspect:<name>:<car>[:yaw:pitch:dist]
  lower toggle:<car> cam:<name>:x,y,z:tx,ty,tz[:fov] bench:x,z:yaw tile:<path.jpg>:...` (windowed, `--resolution 1600x900`)
  photographs it with its HUD, benchmarks it, and rendered `images/menu/tile_garage.jpg`;
  `res://scratch/garage_flow_test.tscn` (headless) walks Main's flow (open, line-up, Esc, car select, trophies) and
  prints PASS/FAIL, putting the player's settings and trophies back.

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
The loop's end is the clip's length times its rate (`get_length() * mix_rate`): the imports are QOA, and the data's
bytes counted as 16-bit frames had ended every car's loop about a fifth of the way through its clip, with a seam.
A clip that comes out quiet (the bubble car's at -37.7 dBFS) is raised in the file (`scratch/normalize_wav.py`) first.
- A preset's `engine_top_loop` (seconds): at top speed (`ENGINE_TOP_ON`, off below `ENGINE_TOP_OFF`, shares of
  max_speed) the stream loops only its last stretch, below it the whole clip (`_update_engine_top_loop` moves only
  `loop_begin`, so the playback runs on to the end before the next pass starts there: no cut). The Meteor's ElevenLabs
  clip revved up through its 8s (its main pitch 262 to 315 Hz) after an unsteady first 1.75s, so every loop dropped back
  with a hiccup: `scratch/make_engine_loop.py` rebuilt it (from the generated clip: make it again with `--force` and
  re-run the script, `--from=1.75 --to=5.81 --tail=0.65 --fade=0.12 --wrap=0.30`) as the steady part, its head
  cross-faded so the file's end runs into its start, then a loop of its own, every join seamless. The top loop must be a
  stretch that holds its pitch: its last second still climbed 4% and sounded like a rev-up every pass, so the clip now
  ends at 5.81s, on 0.65s that hold 285-288 Hz (its end at its start's pitch). Imported as PCM (`compress/mode=0`) for exact
  loop points. `scratch/find_loop_point.py` prints a clip's level along it and how its end joins its start;
  `res://scratch/engine_top_loop_test.tscn -- [cars=19,...] [seconds=60]` (headless; it makes a bot the local player,
  since only that cart plays its engine) logs each wrap of the playback and whether it went where it should.

## Procedural cars

- Every car is built in code; they replaced Hunyuan imports, which are all gone. `CarBuilder.gd` is the geometry toolkit (lofts,
  lathes, tubes, rounded boxes into one indexed mesh, the material id per vertex in UV2.x). `CarDesign.gd` is
  what the cars share: the lofted shell, fender sweeps, wheel parts, a coil-over, the detail map. Each car
  extends it (`MudrunnerBuilder.gd`, `PhantomBuilder.gd`, `StrikeforceBuilder.gd`, `CenturionBuilder.gd`, `ShadowBuilder.gd`, `InterceptorBuilder.gd`,
  `ViperBuilder.gd`, `ApexBuilder.gd`, `MirageBuilder.gd`, `InfernoBuilder.gd`, `NocturneBuilder.gd`, `VortexBuilder.gd`, `ZephyrBuilder.gd`) with
  its shape and its own parts. `regenerate_cars.gd` saves each as `generated/cars/<Name>.tscn` with its meshes, material and detail
  map; run `res://regenerate_cars.tscn` headless (`-- Nocturne ...` builds only those cars: a full run rewrites every
  car's scene, since node ids change on each save). PlayerCart and CarSelection load it through the preset's
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
- The antenna (a paint shop option: `CarPaint.ANTENNAS` off, round, flag; the paint's "antenna" is that index, an older
  bool reads as off/round) is PlayerCart.tscn's `Visuals/Antenna`: a dark mount ball (round, so it looks the same as the
  rod sways about its foot), the 0.8m rod and a 2cm glowing tip, stood on the car's `AntennaPlacement` (the builder's
  `ANTENNA_POS`). `CarAntenna.dress` (free of autoloads, so tools can use it) shows the tip or a pennant trailing back
  from the rod's top (made in code, shared), in the accent colour; PlayerCart dresses its own and the car select
  screen a copy of the same node (it had built its own with the old 4cm tip). `scratch/antenna_style_check.gd`. Each foot sits 4mm into the surface, a little more on a slope.
  `scratch/antenna_check.gd` (`-s`, headless, `-- [cars=...]`) measures every car's foot against its body and anything
  in the rod's way; `scratch/car_preview.gd ... antenna=1` renders the antenna on the car. Ten cars' feet floated up to
  9cm, one was sunk 5.6cm and the Titan's rod grazed its bed rail before they were set by it.
- A builder with `build_rear_wheel()` gets its own rear wheel meshes (`<prefix>_rear_wheel_l/r.res`) on `Wheel_RL`/`RR`;
  the others share one wheel mesh at all four corners.
- The Nocturne (a 917K-style short-tail coupé on slicks) keys its section like the Inferno's, but above the side runs a
  wall from A to B that goes down into the valleys (bonnet, engine deck) and up as the canopy's side glass: B passes A's
  height well inboard of it, so the wall never vanishes. Its fender humps stand over those valleys, so the section isn't
  monotonic in y and `CarDesign.shell_z()` (which assumes it is) found the side wall first: the Nocturne overrides it
  with a point-in-polygon test. Its wheel wells' ceilings slope down inward to stay under the low fender tops.
- In `car_body.gdshaderinc`, don't call `cover()` (it takes `fwidth`) inside a branch whose edge crosses the paint:
  derivatives are undefined where a branch splits a pixel quad. The Racer pattern's bonnet roundel drew a dashed line
  across every bonnet where its `p.z < hood_z + 2r` branch ended; the roundels are now drawn everywhere and masked.
- The Titan (`TitanBuilder.gd`, an RC monster truck) uses the Strikeforce's keyed section on a body raised to a 0.50m
  sill, with 0.69m tyres (hub 0.345m); PlayerCart plants any car by its lowest wheel, so nothing else needed changing.
  Its arches are circles round each hub (`_bot_knots`: the sill and the circle blended by a smooth max), and the arch
  liners stop short of the nose and tail (full length, they stood out of the tail as black bars). It was too boxy
  with flat box flares and sharp edges; now the shoulders round over 5cm (`RIM_R`, so `rim_w` must stay above it),
  the body swells over the wheels and pinches at the doors (`W_KNOTS`), the nose and tail caps are rounded, and the
  flares (`_build_flare`, not `build_fender`) are a superelliptic swell from the bonnet's or bed's shoulder down to a
  rolled lip, shrinking into the body over both ends instead of ending in flat caps. Lamps on the rounded ends go
  through `_on_face` (`face_frame`). The bed is open (`KEYS`: a floor with a fillet, `cy` < 0, like the Strikeforce's)
  with a black liner (detail map), and carries a chase rack with a light bar, a spare tyre (the truck's own wheel at
  70%) under two ratchet straps and jerrycans (`_bed_load`). Its floor must stay over the rear arch's ceiling (0.755),
  so `BED_FLOOR` is 0.775 and the rails stand above the doors' belt to give it depth. A wheelie bar and a tow hitch
  hung off the back and were taken off: only the sphere collides, but 30cm of bar 2cm off the ground would sink into
  every ramp and landing. Its shocks are big-bore bodies in the accent colour (`_big_shock`), stood nearly
  upright beside the tyres so they show in the gap under the flares.
- The Sandstorm (`SandstormBuilder.gd`, a desert rally-raid buggy, an original design with a made-up name) is built on
  the Titan's keyed section and flares, lower and longer: a closed cab with a sloping rear window, an engine cover
  falling to the tail with two sand ladders (`_deck_load`, accent colour) strapped on it, a painted roof scoop
  (`_roof_scoop`, a lofted superellipse eased down into the roof), a tubular bull bar with spot lamps, twin shocks
  at each corner (CarDesign's `coilover` and `_bypass`), all-terrain tyres on ten-spoke rims. A spare lying on a flat
  deck made it read as a pickup, so the deck slopes and carries the ladders instead.
- CarSelection's line-up of names sits centred between Back and Confirm (not on the screen), as a carousel: the names
  ride on a reel (`_reel`) in a window between the arrows (`REEL_SIZE`, room for about eleven) that fades them out over
  `REEL_FADE` at each end (a gradient drawn only as a mask, `clip_children`), and `_place_reel` slides the car on show
  to the middle, stopping where the first or last name would go into the fade. Any number of cars fits.
- To rebuild another car: write `<Name>Builder.gd` extending `CarDesign.gd` (set the shell in `_init()`;
  `build_body`, `build_wheel`, `_detail_shapes`/`_detail_at`, `PAINT_LAYOUT`, `WHEEL_POSITIONS`,
  `ANTENNA_POS`), add it to `regenerate_cars.gd`'s `CARS` and its factory paint to `CarPaint.FACTORY`, then
  point the preset in both PlayerCart and CarSelection at `generated/cars/<Name>.tscn`. A new car (not a
  rebuild) also needs a preset appended to both lists (they're indexed, so append), a `weight` in PlayerCart's (see
  "Car weights"), a `CAR_ACCENTS` colour and its name in `Lobby.CAR_NAMES`.
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
- The Inferno (`InfernoBuilder.gd`, a dune supercar) cuts its wells like the Apex and sinks the bonnet
  panel, cockpit and engine deck between the fenders and haunches with one keyed section (`KEYS`: a
  roll onto the fender top, which falls inward to A, a wall down, a floor). Its visor, quarter windows
  and rear window are separate panels drawn as glass: they are `M_BODY` with every UV on a patch of
  the detail map kept glass on the flat bottom under the cockpit (`GLASS_Z`, `_glass_uv`). Its tail
  cap shrinks toward the top of the black fascia (`tail_cap_y = TAIL_Y`): the cap's rings are scaled
  copies of the section about that height, so the edge lies on the same ring points all over the
  face. A boundary crossing a cap at another height came out wavy. The side is split at the sill line
  for the same reason.
- The Obsidian (`ObsidianBuilder.gd`, a futuristic matte-black desert raider, an original design with a made-up name) features a low sculpted hood with extraction vents and an LED light bar, an open-wheel front with long A-arms, a chrome-framed cockpit canopy with tan bucket seats, a central cylindrical sensor pod on the roll hoop, exposed underfloor bronze power cylinders clamped along the sills, and a sculpted rear cowl that arches over the rear tyres, finished with twin aerodynamic winglet fins. Its balloon mud-terrain tyres ride on deep-dish gold/bronze beadlock rims. Under the rear cowl, between the seats and the rear axle, sits a flat-six (`_engine_side`, `_engine_centre`, `ENGINE_*`): a crankcase on the spine, finned cylinders, heads with valve covers in the accent colour, red plug leads, intake runners off a plenum with a filter, headers into collectors that run back past the gearbox (over the half shafts, under the upper arms' pivots) into a silencer across the tail, and two tailpipes out under the bumper; the exhausts had come out of nothing in an empty cavity.
- The Fulmine (`FulmineBuilder.gd`, a mid-engined hypercar, an original design with a made-up name) is built on the
  Nocturne's section (wells cut as notches, fender humps over a sunken bonnet and tail) with the Inferno's flank intake
  (`_scoop()`) carved ahead of each rear wheel, 10cm deep. Beside the cockpit B drops deep below A, so the shell is an
  open tub (a dash in front, a bulkhead behind) with seats, a steering wheel and a tunnel in it, under a see-through
  canopy (`build_glass()`, `_canopy_ring()`: an arch standing on the door tops and running up the sail panels into the
  engine cover) on dark frames. Its first version, a square keyed section with a chamfer and a flat top, read as a
  boxy wedge; the second, with an opaque painted canopy and a shallow scoop, as the Nocturne again. The nose's leading
  edge is raised (`nose_cap_y` 0.18) so there is a front face under it for the black mouth and its vanes: on a shovel
  nose the mouth fell on the underside and never showed. Lamps and light bars are thin tubes laid along the surface
  through `face_frame()` (`_on_face_line`), their UVs zeroed (`_lamp_tube`) or the headlamp material's reflector rings
  stripe them. The detail map gives each ring segment the same number of texels, so a long segment with few points
  draws jagged edges. `res://scratch/car_mesh_check.gd` (`-s`, headless, `-- [Fulmine ...]`) checks a car's meshes
  (glass included) for NaNs, zero normals and bad material ids. The flank intake's back wall faces forward into the
  opening, so a radiator core stands across it (`_side_intake_parts`: a dark frame, alloy fins), with a lip in the
  accent colour along the opening's lower edge; the nose's intakes carry flat fins (`FIN_PROFILE` swept along the
  face), which read as blades where round tubes read as wires.
- See-through canopies: a builder with `build_glass(b)` gets a `Glass` mesh beside `Body` (regenerate_cars.gd,
  `<prefix>_glass.res`), drawn by `car_glass.gdshader` (car_body.gdshaderinc's `CAR_GLASS` path: the vertex colour is
  the tint, its alpha the opacity face on, rising with Fresnel; premultiplied so reflections keep their strength). It
  is tagged `car_shader` (paint and flashes reach it through the same instance uniforms; a fade swaps in
  car_body_fade.gdshader, which draws it by its material id, so give the glass M_DARK) and `car_glass`: PlayerCart never
  turns its shadow on (it would black out the cockpit) and hides it while the body is disintegrated
  (`_debris_glass`). It can't be part of the body mesh: CarDebris only splits a one-surface `Body`, and a plain
  transparent material would be made opaque by PlayerCart's fade code when the fade ends.
- `CarDesign._shell_shade(p)` (default 1) writes a grey into the shell's vertex colours; car_body.gdshader multiplies the
  body's colour by it and takes the gloss and clearcoat off with it, so a recess reads as a cavity (the Fulmine's
  intakes and cockpit tub). Every other car's shell is white, so nothing changes for them.
- The Basilisk (`BasiliskBuilder.gd`, an electric super-crossover, an SUV coupé; an original design with a made-up name,
  from a concept picture the user liked, kept fictional and deliberately unlike the Nocturne and Fulmine): tall on big
  wheels in black arch cladding (`build_fender` with `fender_mat` M_DARK; arches lifted into the bottom as on the
  Interceptor). Its `section()`: the side steps in round the lower door's air channel (`_groove`: black and shaded
  inside, deepest behind the front wheel, fading along the door) and leans in toward its top (`SIDE_TUCK`, `_side_lean`:
  the shoulder carries the lean on), then a shoulder rolling in to S, a run from S to the corner K and K's rounding and
  a crowned top (KEYS). Over the bonnet K stands above S, so the fender tops fall away from two creases converging on
  the badge: a raised V, the opposite of the Fulmine's humps over a sunken bonnet. The greenhouse is the detail map's,
  by arc length along the upper curve (`_upper_s`, as the Interceptor's): black pillars and rails, a semi-gloss black
  glass roof (`ROOF_GLOSS`: as clear glass it mirrored the sky and read blue), a black vent slashing down each C-pillar.
  - A nearly flat cap face (the nose's exponent 5 up and down) gets almost no detail map round its tip: the u table is
    linear in z, and the face's rings all lie within 2mm of the tip, so a painted grille crept up the fan of triangles
    there as a dark tent. The nose's openings (brow, lamp housings, corner intakes, grille) and the tail's lower bumper
    are patches on the face (`_face_patch`: a grid through `face_frame`, `PATCH_OUT` proud, its border tucked under the
    surface over `PATCH_BEVEL`); `shell_z` bisects to the surface (CarDesign's 2mm steps put a point on a flat face up
    to 2mm behind it, and patches sank into the paint); `stations()` adds rings close to each tip; each tip sits under a
    part (the badge, the bumper patch). At exponent 5 the tail's face rippled: it uses 3.
  - Its motor is `engine_future_04.wav`, one of four unused loops in `sounds/enginesounds/`, +5.4 dB from its -15.1 dBFS
    RMS. The paint shop's "Basilisk Olive" is its factory colour (the shop names the nearest palette entry).
- The Classics (CarCollection's gallery of that name; original designs with made-up names, each with its own engine
  loop made with tools/elevenlabs):
  - The Bootlegger (`BootleggerBuilder.gd`, a hot rod): the shell is only a chopped coupé's cab and turtle deck (the
    firewall is its flat nose cap, satin black in the detail map so the engine stands out); its section above the side
    is the glass leaning in, the roof corner and a crowned top, the glass shrinking to millimetres over the cowl and
    the deck. Painted frame rails (`_frame_rail`, a sweep in M_PAINT, so the patterns run onto them) carry an exposed V8
    (valve covers, roots blower and belt, bug catcher scoop, plug wires, zoomies), an arched grille shell and bucket
    headlamps. Big and little wheels (`build_rear_wheel`): the hubs sit at each tyre's radius, so it rakes forward.
    Its flames start at the firewall (`nose_z` -0.33).
  - The Meteor (`MeteorBuilder.gd`, a 1930s-style Grand Prix single-seater): its section above the side is a shoulder
    (a quarter ellipse), a rim, a wall, a corner and a crowned top, keyed along the car: a dome over the bonnet, a
    trough for the cockpit (as the Centurion's), and behind it the wall leaning in as the headrest fairing's flank. The
    grille's chrome ring follows the nose's face (`shell_z` per point). The aero screen is `build_glass` with both
    faces (car_glass culls back faces). Wire wheels: forty spokes laced from two hub flanges. The exhaust is on the
    left only (built outside the mirrored parts).
  - The Kugelblitz (`KugelblitzBuilder.gd`, a 1950s-style bubble car): the Meteor's section, the cabin a trough under a
    glass bubble (`build_glass`, `_bubble_ring` after the Fulmine's canopy) sitting on the rim; arches lifted into the
    bottom over each wheel (`_bot_knots`, as the Interceptor's) with dark liners, the front ones clear of the tyres at
    full lock. Parts on its round nose lie on it: the grille smile's dark core is a grid at `shell_z` (a flat polygon
    stood 8cm off the nose at its ends), the bumpers' path follows the face (kept within x 0.24, or `shell_z` found the
    face behind the arch). Through the bubble the dark cabin reads grey under a bright sky: that is the glass's
    reflection, not the detail map.
- The Sandpiper (`SandpiperBuilder.gd`, in the Buggies gallery): a 1960s-style beach buggy, an original design with a
  made-up name, picked to stand apart from the other buggies (the Shadow, the Centurion, the Vortex: all caged, all
  winged): rounded and low, no cage or wing, the fenders part of the body, the engine bare at the back. Its section is
  the Nocturne's (wells cut as notches, a roll onto the crest, the fender top falling to A, a wall to B, a top to the
  centre line), keyed through five regions: fender humps over a domed bonnet, the cowl (B over A), the cockpit (the wall
  runs down inside the tub to the floor), the rear deck behind the seats, the engine bay (another trough, between the
  broad rear fenders). A tail cap shrinking toward a point closed over the bay (the U section isn't star-shaped about
  any point), so `_cap()` is overridden for the tail: it only squashes the section toward `TAIL_LINE_Y` (the bay's floor
  line), and the rear fenders curl down to it while the bay stays open. The fender's crest must stay 1.5cm over its
  arch (`_ceiling` caps the arch under the belt): check a new KEYS row's belt against the well's height there, or the
  tyre pokes through. Its air-cooled flat-four (chrome fan shroud, alternator and belt, twin carbs, finned barrels),
  muffler and upswept pipes sit in the bay and hang out over the tail. Narrow ribbed fronts, fat block-tread rears
  (`build_rear_wheel`), eight-spoke rims with chrome lips. Its engine loop (`engine_sandpiper`) had a 0.064 jump at its
  seam: `scratch/seamless_loop.py in.wav out.wav [--fade=0.15]` cross-fades a steady clip's head into its end (for one
  that revs up, `make_engine_loop.py`). Factory paint "Surf Turquoise" (gloss) with white stripes and a white roll bar
  (the accent).
- The Samurai (`SamuraiBuilder.gd`, in the Classics gallery): a 1970s Japanese fastback coupé in "kaido racer" street
  trim, an original design with a made-up name, picked to stand apart from the fleet (no other road coupé of the era; the
  Interceptor's flares are painted on a winged hatchback). The Interceptor's keyed greenhouse section (`_corner`,
  `_upper_segments`, `_upper_s`) on a long flat bonnet, the cabin set back, a fastback to a short deck with a ducktail
  (KEYS' kick at z 1.03); arches lifted into the bottom (`_bot_knots`) under black overfenders (`build_fender` with
  `fender_mat` M_DARK and a box `_fender_section`) with chrome rivets round their faces (`_rivets`, along the same spine);
  the belt rises over the front wheel so the flare's top stays under it. Quad round headlamps and taillamps on the cap
  faces (`face_frame`), a black grille with a crest of crossed blades in the accent colour (`_crest`), chrome blade
  bumpers that follow the faces round their corners (`CarDesign.face_strip`: a profile laid along per-point outward
  directions, since `sweep` takes one), chrome drip rails along the greenhouse's corner, chrome window surrounds in the detail map
  (B), louvres over the rear glass (slats swept across along `top_y`), a chin spoiler in the paint with an oil cooler
  behind it, fender mirrors, and two chrome takeyari exhausts that bend up behind the tail and splay into a V. Deep-dish
  eight-spoke rims, a polished lip and dish in chrome, the spokes in the rim colour. Factory paint: Two-Tone, "Samurai
  Vermilion" over white with a gold pinline, gold rims, number 47; PAINT_LAYOUT's `belt_y` is the two-tone's split
  (0.345), low on the side, not the window line. Its engine (`engine_samurai`, tools/elevenlabs: a straight-six through
  open pipes, steady at 112-117 Hz) had its seam cross-faded with `scratch/seamless_loop.py --fade=0.3` (the clip faded
  in over its first quarter second).
- The Ninja (`NinjaBuilder.gd`, in the Hypercars gallery): the Samurai's opposite, a compact modern Japanese track car,
  an original design with a made-up name: 1.96m on a 1.18m wheelbase, the shortest after the Kugelblitz, rounded and
  hooded where the fleet's other dark cars are angular. CarDesign's own section (a side, then one `_upper` cubic, keyed
  through KEYS: low and wide over the bonnet and the deck, a tall dome over the cabin) with `segment_counts` and
  `_upper_segments` returning the cubic as one segment: resampled as one curve the ring points slid and the shell came out
  crumpled like a cloth cover. `w` swells over each wheel and pinches at the doors (the haunches carry the arches, lifted
  into the bottom as on the Samurai; no separate fenders). The glass is only a visor band of height round the cabin in the
  detail map (`_visor_d`, `VISOR_*`, narrowing to a point behind the doors), the "eye slit" of a hood. A light slit across
  the nose (`face_strip`, M_TAILLAMP in white) over a black lower face (detail map) with an accent line under it, a red
  slit across the tail over a black diffuser, a blade fin down the middle from the roof to the tail (`sweep` of a tapered
  profile reaching `FIN_DEPTH` into the body along a spine rising to `FIN_H` over the deck, a chrome edge swept along its
  ridge), vented engine covers either side of it, a diagonal intake slashed into each haunch (`_slash_d`), camera-pod
  mirrors. Its `shell_z` bisects to the surface (as the Basilisk's): CarDesign's 3mm march sank the light slits into the
  nose. The wheels are throwing stars (`_star_blade`: four curved blades tapering to points at the rim, flat-faced quads
  along a curve, round a boss with a dark hole). Factory paint: Side Stripe in matte "Ninja Indigo" with a black sash edged
  in crimson round the waist (`belt_y` 0.435 puts the stripe there), silver rims. Its engine (`engine_ninja`: a small turbo
  four with its whistle) is the second take: the first wandered 255-273 Hz and came out at -42 dBFS.
- The Crimson (`CrimsonBuilder.gd`, in the Hypercars gallery): a two-seat road-going racing speedster after a mid-1990s
  concept car the user sent pictures of, asked for with "a very similar shape": its shape kept close, no maker's badge or
  name (the user's call over the usual looser "inspired by"). The fleet's only car with open front wheels and a front wing.
  Front wheels on exposed wishbones (`_front_suspension`) under black cycle fenders mounted on the body (`_front_fender`,
  `_band_shell`: a rounded hood over the tread, which only swings sideways under it at full lock); the body is narrow enough
  round the front axle (`W_KNOTS`) for a tyre at 0.5 rad of steer (PlayerCart's `current_steer * 0.5`). Its own
  `section()` (`_segments`): a flat bottom, the lower side leaning out from a tucked-in sill to the crease (`w`, the widest
  line), the upper side leaning in (`lean`), then the Meteor's keyed shoulder, rim, wall, corner and crowned top: the
  hood's dome, the cockpit trough, and behind it the rim is a blade's broad top over a black louvred engine cover
  (`_engine_cover`). No tail cap (`_cap` only does the nose): the tail is one flat black face (`build_shell`, triangulated
  with `Geometry2D.triangulate_polygon`), and the blades run on past it as fins (`_fin`) lofted from the shell's last ring
  (`FIN_FROM`..`FIN_TO`), rising to `FIN_TOP`, sweeping out to `FIN_X_TIP` over the rear tyres and closing to a point, a
  wing between them; risen steeply they read as devil's horns. The black shield-shaped hood is the detail map
  (`_hood_half`). The wraparound screen (`build_glass`, `_screen_base`, `_screen_edge`): its foot across the hood and back
  along the cockpit's rim; its top edge raked back as a whole (a rake per point, front and sides apart, doubled the edge
  back on itself round the corners) at a fixed height in front (`SCREEN_TOP_Y`; from the foot's height it followed every
  dip of the hood), a black hoop along it. LED headlamps in pods on stalks, an LED line along the wing (M_TAILLAMP, pale
  blue), deep black rear fenders, cross-spoke mesh wheels (twelve pairs of spokes crossing, the two sets 3mm apart so they
  don't z-fight), wider tyres behind. Factory paint: Pearl "Crimson" flipping to orange, silver rims, number 96. Its engine
  (`engine_crimson`: a V12 held at speed) had its seam cross-faded (`scratch/seamless_loop.py --fade=0.25`).

## Canyon Chasm dirt ramps, rocks, signs, tornado and houses

The menus call this stage Tolvanera Gulch (a dust devil, for its tornado); files and code keep "CanyonChasm".


- `DirtRampCSG.gd` (`@tool`) builds the two `DirtRamp` humps in `CanyonChasmLevel.tscn` as CSG internal children (a side
  profile extruded across the width, intersected with a cross section extruded along the run; `use_collision`), so the
  level stores only each node's transform and script. They replaced the Hunyuan FBX `models/ramps/a0c68129...`
  (deleted), whose baked mesh sat in the level; the profile in `PROFILE` was measured off it (about 33 x 13 x 8.9m).
  `res://scratch/dirt_ramp_preview.gd` (`-s`, windowed, `-- <dir>`) renders one; `scratch/chasm_ramp_check.gd`
  (`-s`, headless) lists the level's ramp colliders. `scratch/chasm_ramp_probe*.gd` read the deleted FBX.
- The rocks are `ChasmRockCSG.gd` (`@tool`), the same way: every slab a prism (an irregular outline extruded down
  from its top, stepped in along its top edge so the layers read as ledges), boulders squashed spheres. `kind`
  picks the shape the FBX had: CLUSTER (block stacks among boulders, the six `Rock_Curve*`/`Rock3-5`), TOR (stepped
  pancake slabs, `Rock`), ARCH (stacked legs and two courses of slabs round a flat arc, `RockArc`), MOSSY (grey
  limestone pillars on ledges, `Rock2`, `Rock6-8`). `stretch` scales the shape inside the CSG (RockArc's model was
  scaled unevenly), so the node and its collider's body stay unscaled. `rock_seed` varies each one.
  The FBX it replaced (`models/desert/462b0835...`, `8fc36b06...`, `5de45969...`) are deleted; `0c797c60...` (the
  TOR's model) stays because MountainLevel uses it.
- They draw with `canyon_rock.gdshader`, the Canyon Course's sandstone beds, with `vertex_occlusion` off (CSG
  meshes have no vertex colours, and a missing COLOR reads as white: fully shaded), `tint`/`tint_amount` (the
  beds' colour replaced by the tint at their own brightness, divided by their 0.2 mean: the pale salmon of the
  models, or grey limestone) and `moss` (on what faces up, and in pockets down the steep faces). All default to
  the Canyon Course's look. `res://scratch/chasm_rock_preview.gd` (`-s`, windowed, `-- <dir> [fbx=1] [kind=N]`)
  renders each kind (beside its FBX while one exists); `scratch/chasm_rock_check.gd` (`-s`, headless) lists the
  level's rocks with their colliders.
- The chevron arrow sign (`ArrowSign`) is `ArrowSignCSG.gd`, modelled in CSG at life size like the rowing boat
  (`RowboatCSG.gd`): each colour band is the sign's outline intersected with its chevron prism, so faces and edges
  take the band's material. `regenerate_arrow_sign.tscn` (headless) bakes it to `generated/arrow_sign.res`, which
  `ArrowSign.tscn` draws; the level holds no CSG. It keeps the frame of the Hunyuan FBX it replaced
  (`models/signs/300e3a6c...`, deleted), so the level's node kept its rotation and position and lost its x10 scale.
  `res://scratch/chasm_arrow_sign_shot.gd` (`-s`, windowed, `-- <dir> [scene]`) renders it from four sides;
  `scratch/chasm_arrow_sign_check.gd` (`-s`, headless) reports its mesh and collider in the level.
- The wandering twister (`Tornado`) is `TornadoCSG.gd`, modelled in CSG at life size (35.5m tall, 38.3m anvil diameter,
  slender 1.15m touchdown stem, multi-tiered cloud shelves and a rounded storm anvil dome). `regenerate_tornado.tscn`
  (headless) bakes it to `generated/tornado.res` (6.7k triangles, single ArrayMesh surface, 150 KB), which `Tornado.tscn`
  draws at scale 1.0; the level holds no CSG and no heavy asset. It replaced the 50k-triangle Hunyuan FBX
  (`models/desert2/d4250e86adc7a52ecf39a804e207694e.fbx` and its 30MB of textures, deleted), eliminating coordinate hacks
  and 40x level scaling. `tornado_vortex.gdshader` drives dynamic serpentine trunk sway, 3D helical spiral vertex fluting,
  warm terracotta-to-sand height gradients, high-contrast roping dust ribbons, and soft ground fade. `Tornado.gd` adds
  ground touchdown dust blast, orbiting debris particles, a 3D looping wind roar (`winter_wind_loop.mp3`), 38m aerodynamic
  suction with cyclonic crosswind swirl, escalating vertical car capture, boost-to-escape mechanics, and high-velocity
  ejection with one-shot dust burst and swoosh SFX. `res://scratch/test_tornado_look.gd` renders preview shots;
  `scratch/test_tornado_suction.gd` runs headless physics and authority verification.
- The three houses (`LargeHouse`, `House`, and `CasitaHouse`), the ranch windmill (`Windmill`), and the jump barriers
  (`Barrier`, `Barrier2`) are built in CSG at life size (`LargeHouseCSG.gd`, `AdobeHouseCSG.gd`, `CasitaHouseCSG.gd`,
  `WindmillCSG.gd`, `ChasmBarrierCSG.gd`) and baked headless by `regenerate_chasm_houses.tscn` into `generated/*.res`:
  - `LargeHouseCSG.gd` -> `generated/large_house.res` (3,058 tris) -> `LargeHouse.tscn`: 37.3m x 37.9m Mediterranean
    whitewashed stucco villa (`hut_masonry.gdshader` `style = 4`) under Spanish terracotta barrel-tile roofs (`style = 5`).
  - `AdobeHouseCSG.gd` -> `generated/adobe_house.res` (4,112 tris) -> `AdobeHouse.tscn`: 31.5m x 23.1m x 22.8m two-story
    desert adobe pueblo house (`style = 3`) with saddle-curved roof parapets, protruding wooden vigas, and a slatted wooden
    pergola on stilts.
  - `CasitaHouseCSG.gd` -> `generated/casita_house.res` (5,434 tris) -> `CasitaHouse.tscn`: 23.0m x 18.2m x 21.2m Southwest
    cream-adobe casita on the West straight (`(-229.5, 16.0, 65.0)`) with sculpted side parapet wing walls, Spanish
    terracotta barrel-tile roof extending over a timber-post entrance porch with carved corbel (`zapata`), four protruding
    dark vigas, a coffered Spanish oak front door, two recessed round-arched window niches with iron grilles, a flagstone
    courtyard with rounded adobe walls, wooden bench, and three potted agaves.
  - `WindmillCSG.gd` -> `generated/windmill_tower.res` (7,872 tris) + `generated/windmill_rotor.res` (5,864 tris) ->
    `Windmill.tscn`: 25.4m tapered 4-leg timber derrick tower (5 bays of X-bracing, railed upper wooden platform, front
    ladder, wellhead & pump rod, turntable gearbox, tail vane) and 15.0m 18-bladed galvanized steel rotor on `BladePivot`
    spun by `Windmill.gd`. Replaced `models/desert/20260617011251_4d3f8d7e.fbx` (580k tris, deleted).
  - `ChasmBarrierCSG.gd` -> `generated/chasm_barrier.res` (1,132 tris) -> `ChasmBarrier.tscn`: 11.4m double corrugated
    W-beam steel guardrail on 3 H-posts, replacing `models/concrete/3947899e2e8ccf226587409e9b0ce96a.fbx` (deleted).
- `regenerate_canyon_chasm_dressing.tscn` (`regenerate_canyon_chasm_dressing.gd`) builds `ChasmDressing.tscn` (`CanyonDressing`
  with `CanyonDetail.gd`), containing:
  - `ChasmCliffs` (`generated/canyon_chasm_cliffs.res`, `SandstoneKit.gd` + `canyon_rock.gdshader`): 3D tiered sandstone
    cliff formations lining the West, East, North, and South walls of the chasm water pit, eliminating stretched planar UVs.
  - Over 3,200 non-FBX procedural desert plants and rocks in `MultiMeshInstance3D` cells (`CactusKit.gd` 7 cactus species,
    `DesertFloraKit.gd` procedural Joshua trees, agaves, yuccas, desert shrubs, and wildflowers, and `SandstoneKit.gd`
    boulders/pebbles). `CanyonChasmLevel.tscn` now uses zero `.fbx` files, a warm golden-hour desert sky
    (`sky_tropical_cumulus.gdshader`), and calm, wave-free emerald-teal chasm water (`ChasmPitWater`).



## Estación Seca (Freight Line, Sierra del Viento GP, stage 3)

The menus call it Estación Seca (it was Freight Line), after its station; files and code keep "freight" (`FreightLevel.tscn`,
`regenerate_freight_line.gd`). Lap records are keyed by the file, so a rename keeps them.

A high-desert railroad plain at midday; the gimmick is two railways crossing the lap, with trains on the wall clock
that destroy any cart they touch. `regenerate_freight_line.gd` (`regenerate_freight_line.tscn`, headless, about 8s) builds
`levels/FreightLevel.tscn` (the file and the root node are "FreightLevel" on purpose: DressingColliders skips any mesh
whose path says "line", and `PlayerCart` takes any node under the level whose name has "Water" for the sea: the water
tower is "TankTower", and when it was "WaterTower" every road dip under its height flooded the engines).

- The lap is a closed loop of straights and arcs (`LAP`: corner points and radii, `_fillet`, 2.9km). The two railways
  (`RAILS`: the Main Line east-west, the Branch Line from the north) are straight lines between hills (`HILLS`) that
  they run into. Each line has a `trains` list (name, speed, `period`, `phase`, consist), and `_build_railways` errors if
  two trains on a line overlap (a turn on the line takes (line + train) / speed seconds): the Main Line runs a long
  Freight (28 cars: two diesels, boxcars, hoppers, tank cars, log cars, flatcars, a caboose) and the Express (a
  streamlined diesel, five coaches and an observation car) 68s apart, the Branch Line a shorter Freight; the local passenger
  train shares the Main Line's west end (below). Nobody is "gapped" any more: a train is one solid string, and the only way
  over a crossing while a train is on it is the flatcar kicker (below).
- Tunnel portals (`FreightKit.portal`, names unaccented: Label3D's default font has no accents, so "TUNEL", "FIN DE VIA",
  "ESTACION") close the end of a cutting where a railway goes into a hill. They are planned before the ground is graded
  (`_plan_portals`, `_portals`: place, the way in, the tunnel's depth behind, the bay's height and the wing tops). The
  facade is dressed stone (hut_masonry's rubble, key "dressed", UVs from PropKit's `extrude`/`block` `uv_scale`, offset
  clear of the shader's moss): a segmental arch with voussoirs, a bay 13.5-15m high (0.8m over the hill above the arch,
  `PORTAL_TOP_MIN`), and wings whose tops follow the natural hill just behind (`_wing_tops`), so it never stands out of the
  hillside as a slab. The lining (24m) is unshaded (key "tunnel": no sun or sky reaches in), dim at the mouth and black
  within a third of the way, with weak lamps and a black plug; black veils across it (`tunnel_fog`, its own mesh
  `TunnelFog_*`, more opaque deeper in) fade a train into the dark. The track runs on into it (`PortalTrackBed`).
  - The ground: a heightfield can't hold a tunnel, so behind a portal's face `_grade` leaves out the line's own segments
    (`_behind_portal`: the last ones outside cut a bowl round the mouth that ran on up through the lining, and the trains
    drove into a slope of rock), holds the hill `PORTAL_COVER` over the lining's crown, and keeps it under the facade's top
    (or the cutting's walls beside it) plus `PORTAL_RISE` per metre back from the facade's back, so it rises from the
    facade instead of standing over it. The grid has lines exactly on each portal's face and back and is halved across the
    cutting (`PORTAL_REFINE`, `_grid_axis`), so the step from the cutting's floor to the hill over the lining falls inside the
    facade's thickness; those cells under the arch are left out of the drawn ground (`_in_portal_hole`; they keep their
    collision, which also stops a cart driving in). The cutting's walls rise `PORTAL_CUT` (2) per metre. No telegraph
    pole stands in a cutting.
  - The hills are smooth buttes (`_hills`: rims wander 12% on low-frequency noise), and `canyon_ground.gdshader`'s
    `face_slope` is 0 here: taken from each triangle's own face (as on the Canyon Course), the rock's edge followed the 5m
    grid's triangles and the hills showed every facet.
- Terrain as on the Canyon Course: no road mesh, the ground is graded flat under the lap and the rails (`_grade`,
  samples chained by `_rs_next`) and `canyon_ground.gdshader` paints the tarmac from the vertex data. Heights are `_plain`
  (gentle swell), the hills and the far mesas. The road and the rails follow `_plain` smoothed along them; near a crossing
  the rail takes the road's height (`_rail_height`, 14m flat, easing over 46m), and its top stands `RAIL_LIFT_CROSSING`
  (10cm) over the road there and 60cm elsewhere (`_rail_lift`), so the crossing is flush and the ballast has room.
  Depot pad: `_pads` (x -305..45, z 110..222 and a 16m blend), `_pad_at`. Each crossing has a planked deck
  (`FreightKit.crossing_deck`; its joints, flangeways and edge strips stand 1.2, 2.4 and 3.6cm up: closer, they flickered).
- The track is `FreightKit.track_piece` (rails, sleepers and ballast at TrainKit.SCALE, in pieces of 32 samples named
  "TrackBed..."). The ballast is `rail_ballast.gdshader`: crushed stone from the desert pavement's pebbles washed to grey,
  laid in world space from above (beds that meet or overlap match), stained with oil between the rails and rust under them
  by UV.x and UV.y (metres from each track's centre, 99 for none), dusty on the shoulders, its stones' normal map tipped onto
  the face in world space (the meshes have no tangents). Sleepers are hut_wood's squared timber (`_sleeper`: UVs in metres,
  the grain along v); rails have rusty sides and a bright running surface (keys "rail", "railtop"). Every point's "across"
  is mitred between its segments (`before`/`after` carry it over a piece's ends), so curves have no seams.
  - The track itself is solid (`RailSurface_<line>`, gravel): every triangle FreightKit.track_piece and turnout draw
    (the ballast's top and shoulders, the sleepers, the rails), collected through `FreightKit.solid_sink` and left out
    for `RAIL_SURFACE_SKIP` (13m) round each level crossing (the planked deck). A cart runs over the sleepers and rails
    as on Mina del Viento's rail loop, whose track mesh is solid by accident (Level.gd bakes trimeshes under any node
    named "loop": `RailLoop`). With only the hump below, cars glided over the track as if hovering. The hump's top is
    `FreightKit.bed_top`: -0.4 here (under the ballast's top), -0.15 elsewhere; it now only eases the ballast's steep
    lower shoulders. `track_cross_test`: hops of 0.4-0.6m at 21-34 m/s, speed kept.
  - Collision: every bed is a body `RailBed_<line>` (`_bed_body`, surface gravel; the name keeps clear of PlayerCart's track
    words) of `_bed_faces`: a low, wide hump rising 7 degrees from under the ground to 15cm under the rails' tops. A cart
    crossing at full speed comes off it about 4 m/s up (a hop of a few tens of centimetres) and keeps its speed. PlayerCart
    smooths only the pop off small edges, so shorter, steeper ramps (the ballast's own shoulders) threw carts crossing a
    turnout a metre up, and a longer 17-degree one launched them like a kicker. `res://scratch/track_cross_test.tscn --
    [run=x,z,yaw,run_up ...] [trace=1]` (headless) drives a real cart across and prints the hop, the speed in and out and
    what it stood on, the chassis jolts and whether it was blown up (`hold=<train>:<clock>` holds a train, `kills=1`
    leaves them deadly). The yard lead's embankment by T1 still throws a fast cart: that is the ground.
  - The sound: `RailRumble.gd` (node `RailRumble`, fed every stretch of track's centre line by the generator,
    `_rumble_lines`) plays a clunk (`FreightKit.rail_clunk`) as a cart crosses a rail on the ground (at a level crossing or
    off the road) and a knock (`sleeper_knock`) every third sleeper as one runs along a track. Sound only: the handling is
    the beds' collision alone, as on Mina del Viento's rail loop (which has a RailRumble too). Its jolts, impulses and the
    flip and throw over the rails at speed (24.5 m/s) made the carts shake and tumble, and the user preferred Mina's.
    On the bed the tyres roll on gravel (the bodies' surface).
- `TrainKit.gd` builds the rolling stock through a PropKit at SCALE 1.5 (`KINDS`: loco 19m, box 15, tank 14, flat 16,
  flat_load 16, hopper 16, caboose 10, ploco 20, coach 26, obs 26, in life-size metres): a hood-unit diesel (`_road_diesel`: a six-axle road unit in maroon with a gold band, a rounded
  short hood with gold chevrons and twin headlights, a windscreen of two panes, the cab under a black roof, the long
  hood's louvred doors, dynamic-brake housing, twin exhausts, radiator grilles and three fans, walkways with white
  handrails, gold-striped pilots (`_pilot`, shared) and a plough; `loco:1` has a black roof over its radiators; `loco:2` is
  the yard switcher, `_switcher`: an end-cab diesel in safety yellow on a black frame, a rounded long hood with
  louvred doors, the radiator grille and twin headlights on its front, fans and exhaust on top, white handrails,
  corner steps, black-and-yellow chevrons on the pilots; `scratch/train_preview.gd ... consist=loco:2`), boxcars and tank cars in four colourways, an open flatcar, the log car (`_flat_car` with
  `_log_load`: bulkheads, three layers of 17/16/17 crosswise logs, stakes and chains; every log `_log` has eight bark
  ridges and a cut face with rim, sapwood, heartwood rings and pith), a covered grain hopper with three roof hatches
  (`_hopper`), a caboose, the passenger cab unit (`_cab_unit`), coaches and the observation car (`_coach`: windows every
  2.2m, a gold pinstripe, air-conditioning units, a beavertail with a tail lamp).
  - The cab unit has a full-width "bulldog" nose: the body's rounded section carried forward, its top dropping from the cab
    roof down a raked two-pane windscreen onto a rounded hood and over a bulging front to a pilot, the headlight set into
    the hood's slope. A tapering bullet nose had read as Bloombay's monorail. Its livery (teal, a gold line, cream, the line
    sweeping down the nose) is `_banded_shell`: the rings cut at the livery's heights into bands lofted apart, each one
    colour, so the lines run clean however coarse the rings (one loft coloured quad by quad stepped them into teeth).
  `Train.gd` runs a train along a Curve3D on the wall clock (`looped`: round a closed path for ever, Mina del Viento's
  rail loop): `consist` ("loco", "box:1", "flat", "flat_load", "hopper",
  "tank", "caboose", "ploco", "coach", "obs", "gap:20" for an opening, which only the tests use now, and "~" before a car
  to turn it round), `speed`, `period` (>= (line + train) / speed), `phase`. Each car's bogies are meshes of their own
  (`TrainKit.build(kind, variant, false)`, `bogies`, `bogie_mesh`), each set on the rails at its own place along the
  path and turned along them there, the body hung between the outermost two's pivots: as one mesh placed on the chord
  between the car's ends, the bogies stood off the rails on a curve (the local's turn into the station).
  `res://scratch/train_curve_preview.gd` (`-s`, windowed, `-- <dir> [r=60] [head=190] [consist=...] name:x,y,z:tx,ty,tz`)
  holds a train on a tight curve. Hits are a swept test of each cart this peer
  drives against each car's box in the car's own frame (a car is solid from the rail down 1.2m to its height: a flatcar is
  2.2m, a boxcar 6.3m, loaded flatcar 4.4m); no collision body, because a cart moves a metre a step.
  `blocked_intervals`/`pass_window`/`pass_windows` (each pass its own window) give the timetable at a point. With `legs`
  ([start, end, from, to, ramp] per leg, flattened) a train keeps a timetable of its own: it pulls away, runs, stops, stands
  and may back up; its blocked intervals are stepped out once per point and kept, and it idles (diesel, no wheels) when
  standing. `clock_override` holds a train at one clock reading, with `kills` and `sounds` off: that is a train standing
  still (`_park_train`: the yard switcher with three hoppers under the loadout; set the head's distance along the track).
  - A train standing still (`is_moving`: under `STAND_SPEED`, the local at the platform, parked stock) destroys nobody
    and is solid: each car has a box body (`Car.body`, an AnimatableBody3D following its car, `sync_to_physics` off: on, it
    stayed at the origin) on layer 1 only while it stands in view. Moving, it is not solid and destroys what it touches.
  - Physics interpolation is on: a car coming back into view resets it (`reset_physics_interpolation`), or for one frame it
    was drawn between where it left the path and where it came back, a ghost car flashing near the tunnels.
- The local (`_build_local_train`, `LOCAL_*`, node `MainLineLocalTrain`): a diesel at each end (the rear one "~ploco") and two
  coaches. Its path is the Main Line from its west end to T1 and the yard lead on to the buffer stop; every 250s (two of the
  Main Line's turns) it comes out of the west tunnel, takes T1 round into the platform (in at 20-82s), stands at the station,
  and backs out the same way into the tunnel (198-246s), in the gaps the Freight and the Express leave on that stretch.
  `_verify_local` errors if they ever meet there or within `LOCAL_FOUL` (60m) past T1, where the lead still runs
  beside the main line (checked only to T1, the Express's observation car and the local's rear diesel brushed each
  other there as the local backed out at 191s), and then lists the runs out that would be clear.
  `res://scratch/train_clearance_probe.tscn -- [step=0.5] [warn=3]` (headless) steps every train of a level through
  1500s together and prints how close each pair of trains comes (cars as capsules in plan), and any overlap. The west crossing listens to it too: `res://scratch/crossing_windows_probe.gd`
  (`-s`, headless, `-- [at=40,60]`) lists every crossing's trains and passes, and with `at=` holds the trains' clocks to print
  what a bot would hear.
  `res://scratch/train_kill_test.tscn` (headless) puts a real cart through a crossing at the middle of each car, in a gap
  and before and after the train (all must come out right); `scratch/train_preview.gd` (`-s`, windowed) renders the cars;
  `scratch/lap_shots.tscn ... clock=<s>` holds every train at a time of day to shoot it.
- `RailCrossing.gd` (a gate-like node at each crossing, -z the way of travel) draws the masts, crossbucks, lamps and barrier
  arms and runs them off the timetables of every train on its line (`train_paths`): lights and the horn `warn_lead` (6.5s)
  before the first car of the first train, the arms down after `arm_delay`, off `hold` after the last. The barriers are not
  solid. It is in the group `rail_crossings`; PlayerCart's `_ai_rail_crossing_override` makes a bot stop `ai_stop_short`
  (+3) metres short of a crossing a train is on and wait (and turns the stuck checks off, `_ai_crossing_hold`); bots never
  try the kicker. Waiting bots bunch up and get shot. A crossing closes for each pass of each train on its own (`_windows`:
  `pass_windows`, so the local closes it twice a cycle, not for the minutes between). A boosting bot (a pad or an item)
  can't brake for a closed crossing.
- Two big trestle jumps (`BIG_JUMPS`, `_build_big_jumps`: Mina's plateau jump, 26m to a 6m lip, as wide as the road)
  on the straights with no crossing ahead: the start straight past the station (toe at s 300) and the top straight
  past checkpoint 4 (toe 1880; a gate under the flight would be hit, carts fly 7-11m up), each with a boost pad
  `BIG_JUMP_BOOST` before it; their lips are the TrackPath's `jump_lips` (`nyota_jump_test ...
  level=res://levels/FreightLevel.tscn ground=1`: 25-83m out at 30-60 m/s, all keep their speed). Another pad starts
  the west straight (`Boost_West`). No pad may lead into a crossing. `res://scratch/lap_layout_scan.gd` (`-s`,
  headless, `-- [level=] [min=120]`) lists a lap's straights and where its gates, pads, ramps and crossings stand.
- Every crossing has the flatcar kicker (`KICKER_*`, `_build_kicker`, a WoodenRamp whose lip is 11m before the rails): at
  35-40 m/s a cart is 4.4-4.8m over the road (centre) over the rails, clearing a 2.2m flatcar and not a boxcar (6.3m), a
  log car, a hopper or a coach. The lines' freights carry runs of empty flatcars (four in a row) to jump over.
  `res://scratch/kicker_flight_test.tscn -- height=2.2 run_ups=...` (headless) measures a ramp's flight with a real cart.
- The yard (`_build_spurs`, `_build_yard`, `YARD_*`): a network off the Main Line. A lead leaves it at turnout T1 (x -440,
  to the south), curves round to the east (`_turtle`: straights and arcs, R 100 then R 60) and runs on as the platform track
  (z 170) past Estacion del Viento to a buffer stop at x -108; at T2 (x -262) the factory track leaves it to the left,
  an S-curve (R 150) onto z 158, and runs on past the grain cooperative to its own buffer stop at x 25. Each spur has
  its own ground (`_spur_heights`: the plain smoothed along it, held exactly to the track it leaves for `TURNOUT_HOLD`
  (42m, past the turnout) and to the pad's height on the pad). `FreightKit.turnout` builds a turnout: both tracks' rails,
  the switch blades, the frog, check rails, stretcher bars, long switch sleepers and a switch stand, on one ballast bed
  (where the two tracks are `TURNOUT_SEPARATION` apart they get beds of their own, `_in_turnout` cuts the plain bed out of
  the zone). The joins: the shared bed starts 1.5m before the toe and runs `TURNOUT_OVERLAP` past the zone, 3cm under the
  tracks' own beds (so the two never share a plane); the branch's rails run `TURNOUT_RAILS` past it, lifted 1.8cm only
  where the blades lie on the through rails (level by 12m), and the branch's own track starts at the very sample they reach
  (it had started a sample later, leaving bare rails over the ground and gaps in the ballast). The ground grading and
  the flora keep off the spurs (`_spur_distance`).
  The switch stand beside each turnout's toe is solid (`SwitchStand_<name>`, a box over its base, post and lever from
  `FreightKit.turnout`'s `info["stand"]`): it is in the track bed's mesh, which DressingColliders skips.
  `FreightKit.buffer_stop` is a slab and an anchor block under a red-and-white buffer beam on two H-section uprights, two
  buffer heads on hydraulic cylinders, diagonal braces, white rail ends with a tie bar, a red lamp, a plate, and a heap
  of ballast behind (`_ballast_heap`: a lumpy mound of facets with loose stones; it had been a flat-coloured earth bank).
- The depot: `YardKit.gd` (the station) and `FactoryKit.gd` (the grain cooperative, `extends YardKit` for its helpers) are
  built at life size through a PropKit made by `YardKit.new_kit(scale)` (its materials are the hut shaders: `hut_masonry`
  stucco/tile/concrete/brick/stone, `hut_wood` weatherboards and painted boards, `hut_roof_iron` corrugated iron; UV in
  world metres, so `uvk` is the grower's scale, and `YardKit.commit` adds the tangents the tile, iron, concrete, zinc and
  slate normal maps need) and grown by PROP_SCALE. Every roof rests on what carries it: posts, columns and braces are cut to
  the plane above them (`_plane_y`) or stand on the slab under a girder (`canopy`), which is what the old station got
  wrong (its veranda posts stopped short of a sloped roof, the freight shed's posts 0.9m below it).
  - Estacion del Viento (`station`): stucco walls on a stone plinth with quoins (on the walls from the corner inward,
    alternately long and short, 5cm proud: they had been laid past the corners, sticking out beyond both walls), a stone
    cornice, a terracotta tile roof with
    eave and rake boards, two brick chimneys, a pedimented portico on four columns over the entrance with the name on
    its entablature, shuttered windows (`window`: frame, mullions, sill, lintel, louvred shutters), a clock tower with a clock
    face on each side and a hipped tile roof with a weathervane, a platform canopy on cast-iron columns (`canopy`: iron roof,
    girder, columns with brackets, scalloped valance, gutter, downpipes; `dir`/`floor_y` make it a dock canopy too), and
    `platform` (an asphalt slab in 4m panels, a stone-faced edge, a concrete coping, a yellow line, ramps, benches, lamp
    posts, blue enamel name boards facing the track, a luggage trolley, milk churns, crates: their battens stand 2.5cm proud,
    and flush they flickered; the slab joints and the yellow line 1.2cm up) and `goods_shed` (red
    weatherboards, a ridge lantern, sliding doors on rails, its own canopy, drums and crates). The platform's top is
    0.5m over the rail top: the frame's origin is `STATION_BACK` (37.2m) south of the platform track and the edge
    `PLATFORM_EDGE` (2.6m) from its centre, 35cm from a coach's side.
  - Labels are `[text, position, outward normal, cap height, colour, board width]` in the kit's units; `_yard_labels` lays
    them out as Label3Ds (`pixel_size` = cap x PROP_SCALE / 44.8 at font size 64, `double_sided` off) and `_fit_pixel`
    shrinks one that would run past its board (measured with ThemeDB's fallback font, Label3D's default, which works
    headless; it prints what it shrank). The generator's own `_label` (the portals' plaques, FIN DE VIA on the buffer
    stops' `BUFFER_PLATE`, the RR signs) takes a width too. Letters ran past their boards.
  - The cooperative (`factory`): two rows of four slip-formed concrete silos (a footing, eight pilasters, ring beams, a
    parapet and a hatch and vent on the deck, cage ladders), an enclosed sheet-metal gallery along their tops (it stands on
    the decks, with plugs over the star bins between the silos) into the head house (board-formed concrete with
    pilasters, bands, slit windows, a sign, a penthouse in corrugated iron with a beacon, a bucket-elevator duct up the
    back), a short gallery on a trestle from the head house into the loadout (a steel portal gantry over the factory
    track at `FACTORY_X`: a bin on beams, a funnel and a telescoping spout over the hopper), an iron-clad warehouse
    (roller doors on a raised dock under a canopy, ridge ventilators), a control hut, two steel tanks and light masts.
  - The meshes are saved under `freightyard_` (not `freight_`) so MeshChunker leaves them whole: chunked, DressingColliders
    would skip them (it skips chunks) and nothing would be solid. They are single meshes, so DressingColliders gives each a
    trimesh collider (the log shows `Depot/Station`, `Depot/GrainCooperative`, `Depot/TankTower`).
  - `res://scratch/yard_preview.gd` (`-s`, windowed, `-- <dir> [set=station|factory|all] [stock=1] name:x,y,z:tx,ty,tz[:fov]`)
    renders the station (at the origin, the platform track at z -37.2) and the cooperative (at (150, 0, -150)) on flat
    ground in seconds.
- `YardKit.roof` draws a darker underside 4cm under every roof slope (`under`, off where a roof has its own soffit: the
  platform canopy, TownKit's boarded gables): seen from below, the warehouse's roof had vanished and its beams floated.
  Canopy columns are evenly spaced end to end, with no brace past the girder's ends. Sliding doors' rails stand prouder
  than their stiles (they had shared a plane where they crossed and flickered). Lamp posts and lanterns close every
  part and overlap their joints. The passenger cab unit's pilot has a back face.
- Rolling stock and turnouts are kept free of coplanar faces: `scratch/train_mesh_dump.gd` (`-s`, headless, `-- <dir>
  [kinds=ploco:0,coach:0,...]`) saves TrainKit's cars as .res and `scratch/zfight_scan.gd ... tol=0.004 detail=1 unit=1.5`
  lists any two faces in one plane with both triangles' middles (life size) and the facing. Every car scans clean except
  the passenger cab unit's frame faces hidden inside its body. Parts that touch end a centimetre short or stand a
  centimetre proud: the frame slab inside the end beams, coupler tops under the beam's, ladder rails clear of the body
  (`_ladder`'s `side_x`) with rungs inside them, switch blades and wing rails slimmer than the rails they lie on
  (`_rail_beams`'s `slim`), fan blades and plough halves stepped.
- The water tower (`FreightKit.water_tower`, `TankTower`): everything placed from the legs' own line (`leg_r`), so the
  strut rings sit on the legs and the crossed rods (with turnbuckles) on each bay's outer face; a ring beam and joists
  under the tank, a railed deck round its foot, a ladder up a leg's face and on up the tank. The spout is a stowed
  tender-filling spout (for the steam era), hinged on the tank's -z side (the track), swung up, its chain over a pulley
  to a counterweight. Its braces had missed the legs (a scale factor, not the legs' slope) and the spout stuck out of
  the tank in mid air.
- The town and the plaza (`TownKit.gd`, extends YardKit, life size at PROP_SCALE, `_build_town`, `_build_plaza`, pads 1 and 2
  in `_pads`): across the road from the station a row of six buildings facing the road (`TownKit.STREET`: a gabled house,
  Cantina La Via with a false front and a timber portal, a grocer's (Abarrotes) with a striped awning, the two-storey Hostal
  La Estacion with a balcony, an adobe house with vigas, a ramada and a clothesline, a farmacia with a lit green cross),
  a pavement with lamps and benches; between the station and the road a plaza of dressed stone with a fountain
  (`fountain_water.gdshader`: pools rippling out from where the water lands, sheets streaking down, all from TIME,
  `_build_fountain_water`, node `FountainSpray`: named "...Water" it was taken for the level's sea and every engine
  flooded; its sound `sounds/Gentle_flowing_water.wav`, looped in its import), four planters with WoodlandBuilder cottonwoods at `PLAZA_TREE_SCALE` (each under a body with a
  trunk cylinder), benches, a bus shelter, a flagpole, bollards. Detail: lamp posts and the cantina's porch lanterns are `YardKit.lantern` (four panes widening upward between
  corner posts, glazing bars, a flared hood with its underside, a crown and finial; `hanging` adds a ring), the posts
  `YardKit.lamp_post` (a fluted foot, collars, a ladder bar, a capital): the station's platform lamps too. Wall
  lanterns (a scrolled bracket, a hexagonal lantern), clay pots with agaves or flowering shrubs, window
  boxes of geraniums (`_geranium`: scalloped leaves with a dark zone, umbels of five-petal florets), rejas (window grilles), gutters and downpipes, rafter tails, a door canopy, meter boxes, AC units,
  satellite dishes, an aerial, the cantina's beer sign and string lights, the grocer's blade sign, a clothesline with
  pegged washing, and on every back a door, windows and bins. Roof slopes are boarded underneath over their whole width
  (over the gables the sky had shown through from below). Eaves, awnings and balconies have undersides; door steps
  run down to the ground (`YardKit.door`'s `ground_y`). Both are single meshes, so DressingColliders makes them solid.
- Rock clusters on the road (`ROAD_ROCKS`: [s, side]): KnockableRocks on one half of five straights, clear of the crossings,
  jumps, gates and pads, for carts to crash into and shove aside.
- Tunnel portals are solid (`TunnelPortalWall_<n>`, their own triangles via `PropKit.kit_triangles`): DressingColliders
  skipped them ("line" in their mesh's name).
- Plants and rocks keep apart (`_plant_clear`, `_plant_note`: footprints in an 8m grid, the clusters first), here and in
  Mina's flora (`_plant_fits`): a cactus grew out of a sagebrush.
- `hut_roof_iron.gdshader` fades its ribs and laps to their average by the pixel's size in metres (`fwidth` of the UV): sharp,
  the 17cm ribs aliased into rings that crawled across a distant roof (it is also Msitu Falls' ranger post's shader).
- The rocks (`FreightKit.boulder`, `_pick_rock`, `_rock_xf` in `_build_flora`): weathered boulders (an icosphere dented by
  noise, a flat buried base, on half of them a bedding-plane top, smooth normals) in `canyon_rock.gdshader`, the hills'
  sandstone beds tinted toward the plain's tan, each set with its foot on the lowest ground under it. Lumps of flat facets
  had read as mushrooms, and the Canyon Course's fallen blocks (SandstoneKit) as bricks on this plain. Most (64%, and
  anything within 12.5m of the road's centre) are low stones of 22-60cm, some 0.8-1.5m, a few 1.6-2.6m, the big ones kept
  off the road by their size. The sagebrush (`FreightKit.sage`) is smooth ellipsoid lobes (`_blob`, darker underneath)
  sitting down on the ground: on a stem it had read as a ball on a stick, as lathe lobes as green crystals.
  - The sagebrush (`FreightKit.sage`, `Sagebrush_*`): an authentic desert shrub (*Artemisia tridentata*) with gnarled,
    radiating woody stems (`Color(0.38, 0.32, 0.24)`), multi-plane foliage sprays of serrated silvery grey-green leaves with
    sun-bleached straw tips, and dry sticks poking through, using two-sided `sage_leaf` material. In `DressingColliders`, each
    bush gets a base collider and spring-loaded wobble behaviour when struck by carts.
  - Large immovable boulders (`h >= 1.0m`, up to 2.6m, plus cluster anchor stones): have permanent convex hull colliders
    baked directly into `Desert/BouldersBody` (`StaticBody3D`), guaranteeing 100% solid, immovable collision with zero
    risk of being missed or culled by detail LODs.
  - Rock clusters (`KnockableRocks.gd` under `Desert/RockClusters`): 47 clusters across the circuit consisting of 5-8
    pushable stones (35-78cm) and optional immovable anchor boulders. Dynamic stones have realistic sandstone mass
    (320-950kg), high friction (0.95), and heavy cluster drag (`cluster_drag = 7.5`) with direct impact deceleration
    (18-35% cart speed loss on strike). Their material duplicates `canyon_rock.gdshader` with `local_coords = true`
    so strata and textures rotate rigidly with the stone rather than sliding in world space.
  - Track buffer stops (`BufferStop_0`, `BufferStop_1`): have permanent `StaticBody3D` colliders (`BufferStop_Body`) combining
    a front barrier impact box (6.9m wide, 3.6m tall) and full trimesh geometry of the steel beam, hydraulic heads and earth mound.
  - Level crossing gate posts (`RailCrossing.gd` `Mast0`, `Mast1`): have dedicated `StaticBody3D` colliders (0.9m foundation box
    and 5.4m tall cylinder mast), preventing carts from ghosting through crossing barriers.
  - Telegraph poles (`TelegraphPoles`): `DressingColliders` samples lower vertex bounds and generates rigid cylinder colliders
    for all poles along the railway; `ROCKY` classifies poles and masts as solid rigid obstacles.
  - Standalone small/medium rocks: their MultiMeshes carry `hull_collider` and `min_collider_height` (15cm) meta for
    `DressingColliders`, which uses a distinct rock-versus-plant spatial hash key to prevent nearby vegetation from skipping
    rock colliders: a cart's sphere rolls up the low ones, bumping it into the air.
- Dressing: telegraph poles and wires along the rails (`_build_poles`, solid cylinder colliders), advance warning signs (`_build_crossing_signs`),
  saguaros and other cacti (CactusKit, two detail levels swapped at 150m), sagebrush shrubs (`Sagebrush_*`, wobbling vegetation)
  and boulders (`_build_flora`). Wind loop `PlainsWind`; the crossings a bell and a horn (`FreightKit.bell/horn`). The trains play recordings
  (`Train.DIESEL_CLIPS`: `sounds/diesel_locomotive*.wav`, one per train by its name, on the leading diesel;
  `TRACK_CLIP`, `sounds/train_track_sound.wav`, the wheels), each through two players crossfading into itself over
  `LOOP_XFADE` before it ends, levelled to the synthesised `FreightKit.diesel/clatter` they replaced
  (`scratch/train_sound_levels.gd`); Mina del Viento's rail loop too. `res://scratch/train_loop_probe.tscn --
  [level=] [seconds=]` (headless) prints each train's loops. `sounds/cargo_train*.wav` are recorded pass-bys (a swell and a
  fade): each crossing plays one for every pass of a freight (`RailCrossing.PASSBY_CLIPS`: where to start in the
  clip, its loudest moment, where to stop, gain), timed off the timetable so the swell peaks `PASSBY_PEAK_AFTER`
  (2.5s) after the first car reaches it, the clip picked by the pass's number so every peer hears the same one.
  `res://scratch/passby_probe.tscn -- [seconds=150]` (headless, real time) logs each pass-by against the warning.
- AI races (`scratch/ai_race_test`, speed=1 only: the trains run on the real clock, not the engine's) finish three laps in
  about 250s; a few bots a race are blown up queueing at a closed crossing (missiles), rarely run into a train (a boosting
  bot can't brake for one). `noitems=1` doesn't take every item away here: a bot was still blown up with it. With the local
  running, six bots finished three laps with no train hits.
- Cost (M1, 4320x2700, `scratch/ab_bench`): about 19ms of GPU along the lap; the track beds 0.06ms (their ballast shader
  0.3ms over a plain material where the yard fills the view), the tunnel veils 0.06ms, the desert's plants and rocks 0.8ms.
  `res://scratch/freight_ground_profile.tscn` (headless) raycasts the collision along the lap for steps (`across=1` the
  road's width), `scratch/freight_nodes_near.tscn -- x,y,z radius=` lists nodes near a point, `scratch/freight_drive_test.tscn`
  drives a cart straight (it has no steering).

## Mina del Viento (Sierra del Viento GP, stage 4, the finale)

A point-to-point rally sprint (one run, no laps): `regenerate_mina.gd` (`regenerate_mina.tscn`, headless, about 15s) builds
`levels/MinaLevel.tscn`, 4.75km from a plateau at dawn (+54m) down into an open-pit copper mine and out into the valley (-34m).
Rebuilt on 2026-11-02 (Gemini's first version had a pit unrelated to its road, trucks in walls, a storm that never ended).

- The route is an open path of straights and arcs (`_fillet_open`: HEAD corners, the pit's three, FLOOR, TAIL), measured from the
  path's start (`_at(s)`, `_spot(s, lat, lift)`). Sections: the plateau, tarmac (0-1.26km: the start in the balloon fiesta,
  the radio array's arm, the dry wash's crest jump `WASH_SHAPE` at 820m), the mine's gate (`GATE_S`, tarmac ends), the shelf
  road cut into the escarpment's face (to 1.77km), the notch through the pit's rim, the haul ramp three quarters of the way
  round the pit (1.87-3.01km, 5.5%), the floor (off-road, below), the mouth (a benched cut through the south wall), the valley (concrete
  again from `PAVED_AGAIN`), the finish (`FINISH_RUNOUT` before the path's end). The road's height is `_prof` (HEAD_PROFILE and
  stations from the solved route, linear, smoothed, the wash added).
- The pit is one function, `_pit_d` (distance outside a rounded rectangle, the floor): benches are its contours
  (`_benches`: BENCH_H every BENCH_W, face then berm). `_solve_route` puts the ramp's corners on contours whose mean wall
  height matches the road's there, so the ramp is cut into the benches it crosses. The mouth is the same bench function
  across its centreline (`_mine_cut`). Grading (`_grade`, per stretch `_grading_at`) clamps the ground to every road
  segment's cut and fill. Dressing is placed by (s, lat) or on `_ground_at` and every footprint is checked (`_seat`,
  `_report_seats`: errors past twice its tolerance), so nothing stands in a wall.
- Terrain: one heightfield (`FINE_STEP` 5m, half that over `PIT_X`/`PIT_Z`), the far land a mesh of its own (`minafar_`).
  `mina_ground.gdshader` (derived from canyon_ground): desert floor, sandstone on the escarpment, the pit's ore by depth
  below the rim (`copper_rock`: leached cap, oxide zone with malachite streaks, grey porphyry; presplit half barrels on the
  faces), the roads painted from the vertex data, sand drifted over the shelf road (UV.y, `DRIFTS`, the `MinaSandRoad`
  body), blowing sand along the ground (`storm`, `wind_dir`, set by HaboobWeather). UV.x is how deep the mine cut (the ore's
  rock and rubble); the sump's stain is limited to `sump` (xz, radius), or the mouth's floor (below the sump's water) went
  teal. Bodies: `MinaRoad`, `MinaHaulRoad`, `MinaSandRoad` (track), `MinaGround`, `MinaPitGround`, `MinaRockFace`.
- The pit floor (`FLOOR` corners, `T_FLOOR`..`T_MOUTH`; `_offroad_at`) is off-road: a serpentine of 90-degree turns
  (radius 18-24m) between parked trucks standing on the insides of its bends, along the north wall beside the shovel's
  crawlers and its truck, hard left at `T_SUMP_TURN` with the sump straight on, then down the west side into the mouth
  (about 730m). Its road triangles are `MinaPitGround` (no "road" in the name, so PlayerCart counts it off-road), lumpy
  (`FLOOR_LUMPS`), painted as wheel ruts in the rubble (UV2.y -1). A boost pad starts the north leg. `_check_clear` errors
  on any pit machine within `PIT_CLEAR` of the track's edge. Adding corners: keep `T_MOUTH`/`T_VALLEY` (constants) in step
  (`_solve_route` errors if not); the later checkpoints, boosts, signs, the paving and the grandstand follow the route.
- The sump (`SUMP`, `SUMP_R`, `SUMP_DEPTH`) is real water, `SumpWater` at `SUMP_WATER_Y`: dug 5.5m, deep enough to drown
  a cart. PlayerCart takes the first node named "...Water" for the level's water; its `water_bounds_min`/`max` metas
  (PlayerCart's general water branch reads them now) keep it to the pond, or the mouth and the valley, which lie below
  its surface, would flood every engine. `res://scratch/pond_drop_test.tscn -- <level> x,z ...` (headless) drops a held
  cart at each spot and reports the water level, whether it went under and drowned. Bots don't drown there.
- Bumps (`BUMP`, `_plan_bumps`, `_bump_at`): mounds of spilled ore, 1m high, about 9m long, covering half the road on one
  side (sides alternate), so a driver takes one for the air or steers round it: down the ramp every `BUMP_EVERY`, on the
  floor's straights, two staggered in the mouth, none within `BUMP_KEEP` of a gate or boost pad. Raised into the
  heightfield (the pit's 2.5m grid) and painted paler (UV.y, the drift channel; the bodies don't change).
- The rope shovel's crawlers (`MinaKit._crawler`): a chain of shoes (grouser outside, drive lug inside) round the drive
  sprocket (rear, its teeth showing) and the idler, the side frame between the runs with ribs, flanged rollers in pairs
  either side of the drive lugs, running on the shoes' plates (the lower ones under the frame on brackets from its foot,
  the carriers on posts under the top run: they had hung beside the frame in the air), hubs with bolt circles, the propel gearbox; a toothed swing ring, ribbed house walls, a door, roof cabinets, work lamps,
  a boarding stair, the boom's plates, walkway rail and lamps. The trucks flickered where faces lay in one plane (the
  body's front wall and its lining, the canopy and the deck against it, the cab front and its trim):
  `scratch/zfight_scan.gd -- res://generated/minaprop_haul_truck_1.res ...` lists what's left (railing posts, hidden).
- The light towers (`MinaKit.light_tower`) are mining light plants: a single-axle trailer chassis on leaf springs with
  mudguards, an A-frame drawbar with a hitch eye, jockey wheel and safety chains, the generator canopy (chamfered roof,
  louvred door vents, handles, the control panel and e-stop at the back, exhaust, lifting eye, amber beacon, hazard stripes
  along the skirt, `_hazard_band`), four outriggers on screw jacks, and a three-stage telescopic mast (pivot bracket, ram,
  winch, cable spiralling down) with four finned LED floods on yokes along a crossbar. They had been a box on a pole.
- The plateau jump (`PLATEAU_JUMP`, `_build_plateau_jump`): a WoodenRamp across the start straight (toe at s 205, 26m to
  a 6m lip, `trestle` on), the boost pad at 168 feeding it; carts land on the straight before the sweeper. Its lip is in
  the TrackPath's `jump_lips` (`_plateau_jump_lip`): 26m out at 30 m/s to 75m at 60, 1.5-5.5m over the lip, all keep
  their speed. Named "PlateauJump", not "...Ramp" (Level.gd bakes a second collider under any "ramp").
- The drills (`MinaKit.drill_rig`, `_drill_track`): crawler tracks of shoes round a sprocket and idler with rollers, a
  railed deck on levelling jacks, the power pack (louvred doors, radiator grille, exhausts, air cleaners, hydraulic tank,
  beacon), a dust collector piped to the hood, the glazed cab under a ROPS roof with lamps, mirror and ladder, and the
  lattice mast (crown block, pivot and raise rams, rotary head with hoses, drill pipe, centraliser, dust hood, rod
  carousel, work lamps). Solid as the carrier and the mast. They had been two blocks and a box under a mast.
- The gate (`_build_gate`, `_plan_gate_pads`): its legs and the boom's post stand on pads at the road's height (the left
  leg had stood on air where the bank falls away), and the guard house (`MinaKit.guard_house`, `GUARD_HOUSE_AT` in the
  gate's frame) is a prop of its own on a pad beside it, its front to the road: a rendered block house on a plinth with
  steps, framed windows all round, a door, a canopy on columns with CONTROL DE ACCESO on its fascia, an air-conditioner,
  a water tank, a radio mast, a solar panel, a floodlight, a bench and a bin.
- The guard house's detail (`_guard_house_details`): coping, gutters and downpipes, window grilles and awnings, the
  service counter and intercom at the road window, the glazed door, column bases and caps, striped bollards, yellow
  nosings, a fire extinguisher cabinet, an electrical box, wall lamps, a CCTV camera, the PARE and SOLO PERSONAL
  AUTORIZADO signs, potted cacti, a roof hatch and vent, the tank's straps, a flagpole; solid as the house, its plinth,
  columns, bollards, the PARE post and the flagpole.
- The muck pile at the shovel (`MinaKit.muck_height`, `muck_pile`, `MUCK_*`): blasted rock against the north wall, a
  crest that rises and falls, the slope of repose down to the shovel, steep ends and back, the dipper's bite out of its
  front, boulders; its collision is the same surface as a trimesh (it had been a convex hull 15% under the mesh, which
  carts sank into), and its toe runs in under the shovel's crawlers so no gap is left to wedge in.
- The rail loop (`RAIL_LOOP`, `_build_rail_loop`): a 3.55km balloon loop on the plateau north of the start straight (clear
  of the road, the fiesta and the far dishes) where a freight (`RAIL_CONSIST`: two diesels, covered hoppers of
  concentrate, acid tank cars, a diesel at the tail) circles for ever at `RAIL_TRAIN_SPEED` (Train.gd `looped`), so it
  never appears or vanishes at a track's end. Track in 32-sample pieces (`FreightKit.track_piece`), rail tops on the
  ground smoothed round the loop, trestles over dips, its bed solid (`RailBed_Loop`); the train destroys a cart it
  touches, as on Freight Line. It replaced the radio array's double track, which ran under the dishes and nowhere.
  `res://scratch/mina_line_profile.gd` (`-s`, headless, `-- x0,z0 x1,z1 ... [step=]`) prints the ground along a line.
- Flora keeps off the crowd barriers and the spectators (`_flora_blockers`, `_blocked_by_crowd`, 8m cells) and the rail
  loop: plants grew through the finish's fences and people.
- Under the trucks and the conveyors: a haul truck is solid where it is (`TRUCK_SOLIDS`: the wheels, the rear axle's
  housing, the frame rails, the engine house, the bumper, the body over 3.7m life size), so a cart drives under it
  between the wheels, across it or along it; a conveyor's low run is solid as its belt frame and each support's two legs
  (where `conveyor_run` stands them), not a wall down to the ground. `res://scratch/drive_under_check.tscn` (headless)
  sweeps a cart-sized sphere under every truck both ways and across the conveyor's runs, and checks every sign is solid.
  `res://scratch/mina_prop_positions.gd` (`-s`, headless, `-- [match=]`) lists where the signs, gate, trucks, drills and
  light towers stand, for aiming shots.
- Signs (`_plan_signs`, before the heights; `_sign_at`): each is solid (its posts and board) and keeps
  `SIGN_CONVEYOR_CLEAR` (9m) from a conveyor's line and clear of the guard house, moving along the road or across it
  (PLANTA stood in the conveyor by the mouth). Each stands `SIGN_LAT` (10.9m) out on its side on a small pad of
  its own at the road's height (`SIGN_PAD`, `SIGN_PAD_BLEND`; none by the sump), cut into the bank or built up from it:
  the road's grading falls or climbs steeply from about 9.5m out, and at a fixed 11-12m the signs had one post in the air
  and the other buried. A sign stands on the lower of its posts' ground (it prints any whose posts differ by over 0.3m).
  `res://scratch/mina_verge_profile.gd` (`-s`, headless, `-- <s> ... [lats=...]`) prints the ground across the road against
  its height, from the generator's own heights.
- Safety berms (`BERMS`, `_build_berms`, `mina_rubble.gdshader`): rubble windrows on the drop side of the shelf road and down
  the ramp, their collider a steeper, taller wall than the heap (a cart glances off instead of riding over the edge).
- Set pieces are `MinaKit.gd` (life size, grown by `PROP_SCALE` 1.6; balloons 1.5, dishes 1.25), meshes and materials
  saved under `minaprop_` (MeshChunker leaves them whole) by `_save_props`, each big prop under a StaticBody3D with its own
  boxes (`_prop`), so DressingColliders leaves it be: the haul trucks (`haul_truck`, `water_truck`, `mina_tyre.gdshader`
  chevron lugs), the rope shovel at the muck pile on the floor, the crusher by the mouth, drills, light towers, the radio
  telescopes (`radio_dish`, each on its own pad), the balloons
  (`balloon`, `balloon_inflating`, `mina_balloon.gdshader`, `mina_flame.gdshader`), the conveyors (`conveyor_run`: two
  galleries over the road, `CONVEYOR_A`/`B`; the generator errors if one clears the ground by under 9m), the stockpile,
  the truck shop, the concentrator and thickeners, the grandstand. `res://scratch/mina_kit_preview.gd` (`-s`, windowed,
  `-- <dir> set=truck,shovel,... name:x,y,z:tx,ty,tz`) renders them in seconds; `scratch/test_mina_kit.gd` (`-s`, headless)
  builds each and prints its triangles.
- The balloons (`MinaKit.balloon`, `balloon_inflating`): a woven wicker basket (stakes and weavers, a padded leather rim,
  rope handles, skids, fuel cylinders with hoses), padded uprights, twin burners with coils, blast valves and pilot
  lights, a dark skirt under the mouth, the crown ring; the field's standing ones tethered by two ropes to stakes. An
  inflating one lies on the ground (`inflating_frame`), its mouth just off it, the basket on its side with its burner
  into the mouth, a ducted inflator fan (guard, blades, engine, frame on wheels) beside it, the crown line out to the
  crew member holding it; the crew stand at their jobs (the mouth, the fan, the crown line, the basket), not inside it.
  The envelopes are solid as convex hulls (`envelope_hull`, `_hull_shape`); their inside glows with the daylight through
  the nylon (`mina_balloon.gdshader`), not black through the mouth. `scratch/drive_under_check.tscn` checks each is solid
  and no spectator stands inside a lying one.
- `BalloonFiesta.gd`: the balloons aloft loop slowly over the plateau on the wall clock; every burner fires now and then
  (the `burn` instance uniform).
- The haboob (`HaboobWeather.gd`): a place, not a schedule. `intensity_at(p)` is the storm's cover there (a grid the
  generator bakes, `_storm_cover`: the escarpment's band from `STORM_FROM` north of its edge to `STORM_TO` out over the
  valley, and the pit) less the shelter of lying below the land's natural height (the pit, the notch, the mouth). So it
  thickens from about 1.1km, is thickest along the shelf road and the notch, thins down the ramp to a haze on the floor
  and is gone in the valley; every viewer sees it by their own camera (eased, snapping on a cut). At its thickest the dust
  closes in to `storm_fog_end` (230m, depth fog; aerial perspective off), the sun dims to a pale disc, sheets of dust roll
  past (faded within 30m of the lens) and sand snakes low over the ground; nothing streaks across the view (motion
  comfort). Gust fronts sweep downwind (`gust_at`, position and wall clock) and push the carts this peer drives across their
  line at up to `gust_accel` (42 m/s^2: about 8 m/s of slide in a full crosswind on a grip of 5; 19 was too gentle to
  notice), a little along it. From the plateau it is the
  `DustWall`: curtains along the edge (`DUST_CURTAINS`, `mina_dust_wall.gdshader`) that fade as you near them, at grazing
  angles, and once you are inside the storm (`inside`). A blast siren wails at the gate; "HABOOB!" on the HUD once.
- `Tumbleweeds.gd` (a MultiMesh, in DressingColliders' SELF_MOVING): weeds roll across the shelf road on paths of their own
  (berms included in their heights) on the wall clock; a cart bursts one and keeps `HIT_KEEP` of its speed.
- Level.gd: `is_point_to_point` (one lap; checkpoints sorted along the open path; the start gantry is `StartLine`, which
  holds the grid's SpawnPoints and the start lights and ticker); the HUD's stage progress is measured to the finish line
  (`_finish_offset`); after the finish carts brake to a stop in the run-out. RaceUI shows `STAGE: n%`, the minimap an open
  line with start and finish.
- Tests: `scratch/ai_race_test.tscn -- res://levels/MinaLevel.tscn seconds=200 speed=2` (6/6 finish in about 115-135s, no
  respawns but items); `scratch/nyota_jump_test.tscn -- level=res://levels/MinaLevel.tscn speeds=30,40,50,60 ground=1` (the
  wash's crest: 13-46m from 40 m/s; the plateau jump, above); `scratch/route_ai_probe.tscn -- [level=] start=<s> [speed=30]` (headless) traces one bot from any point
  of a route with what it touches; `scratch/route_surface_scan.tscn -- <level> x0,z0 x1,z1` raycasts a line for steps;
  `scratch/inspect_mina_stuck.gd` (`-s`, `-- <s> ...`) prints where the route is at given distances;
  `scratch/race_cam_shots.tscn -- <dir> level=res://levels/MinaLevel.tscn every=5 count=22` rides through the storm.
  The menu tile is `res://scratch/render_mina_shot.tscn` (windowed).
- Cost (M1, scratch/bench.tscn, 1280x720): about 37ms GPU on average, 610 draws (Freight Line measured 64ms in the same run).

## Time trial and lap times

- `TimeTrialRecords.gd` (user://time_trial_records.cfg, per stage keyed by the level's file name): the best run
  (total, its laps, car, date), the best lap with its gates' times (`lap_splits`, the last is the lap), and the
  number of finished runs. Level records them for the human in a time trial (server): a lap when clean
  (`_lap_completed`), a run at the finish when every lap was clean (`_record_run`). `lap_records.cfg` (the
  announcer's "new lap record", any mode) is kept as before.
- Level times every racer: `_grant_checkpoint` notes the split at each gate (`lap_splits`, by gate index, -1 for a
  missed one), `_lap_completed` the lap (`lap_times`; a lap faster than 70 m/s along `_lap_length()` isn't clean),
  `_check_finish` the run (`finish_ms`, the laps' sum). The human's HUD hears of each (`_send_timing`: a gate, a lap,
  the finish; RPC'd to a remote player, straight to the right HUD in split screen), and every HUD starts its clock at
  the green light (`_start_lap_timers`) with the stage's lap record and, in a time trial, the stored best lap's splits.
- `RaceUI`'s lap timer (`timing_*`, under the minimap), shown in a time trial only (a GP or a single race times every lap
  but shows no clock): the running lap (or stage) time in tabular figures, the delta
  at each gate against the reference lap's split there (green faster, red slower; the reference is the stored time
  trial best lap, then the session's best clean lap), the lap's delta or RECORD, LAST / BEST / RECORD, and in a time
  trial RUN and BEST RUN. A time trial hides the position and the standings. A time trial ends at the line (or a
  disqualification) on the next frame (`_end_race_now`): no 30s countdown. The end screen shows TIME (the
  winner's, then gaps) and BEST LAP (the race's fastest in green) per racer; a time trial's is a lap sheet: each lap,
  the fastest marked, the total against the best run, the records.
- `res://scratch/time_trial_items_check.tscn -- [res://levels/X.tscn] [lap=62]` (headless) runs a real time trial,
  granting the gates with faked lap times: boosts, no boxes or commentator, the HUD's laps, the saved records and the
  end screen's sheet (the player's records files are put back).


## Al-Raihana GP (Jebel Sahar and Wadi al-Ghaf)

A fictional Gulf country: orange dune sand, the dark brown rock of the jebel, mud-brick forts and wind towers, date
palms and ghaf trees, a modern city on the horizon. Not the Sierra's red sandstone, cacti and Spanish adobe. The menus
call the stages Jebel Sahar and Wadi al-Ghaf; files and code keep "mountain" and "desert_wadi" (`MountainLevel.tscn`,
`DesertWadiLevel.tscn`). Neither uses any imported model now (the 24 FBX/GLB Mountain Pass alone used are deleted).

- `ArabianTerrain.gd` replaces both levels' FBM noise in `TerrainGenerator._get_terrain_height` (prefixes "mountain"
  and "desert_wadi"): `dunes()` (transverse dunes across the shamal, `WIND`: gentle windward slope, sharp crest, slip
  face `SLIP_SHARE`, crests wandering and breaking into segments, small dunes riding on them), `serir()` (gravel pans
  where the sand runs thin) and `jebel()` (spurs and gullies running down the cone, warped polar ridged noise, faded
  near the summit). Mountain Pass keeps its bridges and its 3D road query where the old noise had them
  (`bridge_ref_h`: the old base height): measured against the new ground the spiral's closest-point query picked the
  wrong leg and new spurs stood up through spans (sand over the road). Desert Wadi has no bridge test at all (an
  off-road lap). `res://scratch/arabian_terrain_preview.gd` (`-s`, headless, `-- <level> <out.png> [step=] [half=]`)
  draws a level's base shapes as a hillshaded map with the lap in red, without a bake.
- `arabian_ground.gdshader` is both levels' ground: sand with wind ripples (faded by `fwidth`, none on slip faces),
  rock on cliffs and over `rock_height` (the jebel), steep sand below it stays sand (a pad's graded bank read as a dark
  cliff), gravel pans in specks, the piste, yards, wet sand by `water_y`. `ground_map` (`generated/<prefix>_ground_map.res`)
  carries what it can't work out: R the piste as a distance (1 - metres / `piste_reach`; ruts at set distances from the
  line), G gravel, B yards (the pads).
- `regenerate_mountain_dressing.gd` / `regenerate_wadi_dressing.gd` (headless, about a minute each: the bake is most
  of it) plan pads on the natural ground (`flat_pads`), re-bake (`generate_world`), then build `MountainDressing` /
  `WadiDressing` from scratch (both under `CanyonDetail.gd`: Plants_/Tall_/Rocks_ cells, `TallNear_` the palms' and
  trees' near models, no `base_range`). They replace the weather controller with the stage's own sky
  (`ArabianDresser.environment`). `_align_start_and_spawns_to_track` moves the grid under FinishLine and owns it only
  in the editor: the dresser owns it, or the level saves without spawns and no cart starts.
- `ArabianDresser.gd`: what both share (exact ground on the generator's triangles, the lap's distance in plan from a
  grid index, notes for keeping apart, the sky, the ground map and material, plant and rock meshes, MultiMesh
  cells, the country past the rim `backdrop` and the `skyline`).
- `ArabianKit.gd` (PropKit, life size, grown by 1.6): `fort` and `watchtower` in two styles, `house` (courtyard house,
  poles, carved doors, a `wind_tower`), `house_najdi`, `mosque`, `villa`, `barasti` (palm-frond hut), `bedouin_tent`
  (black goat hair, carpets, a `dallah`), `road_lamp`, `skyline_tower`, `palace` (Ramlat Hamra).
  Mud is hut_masonry 3; COLOR.a is how much its plaster flakes (keep it low: at 1 the forts were blotched white).
  - Style 0, Omani (Jebel Sahar, and Marina's souk watchtower): `fort_omani`, battered walls dressed outside by
    `wall_dress` (lime bands, buttresses, two rows of loopholes, waterspouts, machicolations), `tiered_tower`s (drums
    stepping back, each with a band, loopholes, poles, merlons on its ledge), a square tower, a three-tier keep with a
    lookout `kiosk`, the gatehouse (the door in a recessed two-centred pointed arch, `arch_opening` filled with darker
    mud, a lattice fanlight, nested frames, a machicolation, two `cannon`s), arcaded rooms, stairs, a whitewashed
    `mosque` with a round minaret, the well. Style 1, Najdi (Wadi al-Ghaf): `fort_najdi` in redder mud (`MUD_RED`),
    walls leaning in hard, a white band under the walkway painted with `triangles`, rows of triangular vents, square
    tapering towers (`_najdi_tower`), the murabba'a (a tall square keep), the gate block with a `najdi_door`, the
    mosque with a square minaret. `watchtower(…, style)` follows them (its door's face leaves out the shutter there).
  - White trim is "stucco" (hut_masonry 4): "lime" (style 1) paints brown patches where its wash has gone whatever
    COLOR.a says, which read as dirt on bands and on a white mosque. `najdi_door`: teak leaves with painted sawtooth
    bands and diamonds, laid 1.2cm proud (a full grid of primaries read as a toy); shutters are `NAJDI_SHUTTER`'s muted
    colours. `door(…, gable=false)` inside an arch: its own pointed gable left a black triangle under the arch's head.
  - `national_flag`: Al-Raihana's (fictional): a maroon field, a gold band at the hoist, a gold eight-pointed star, as
    on the flag carrier's tails (AirlinerKit "raihana"). The user chose it over an emblem they had drawn in Gemini.
    The first flags were banded tricolours that were real countries' flags.
  - `villa` (Wadi al-Ghaf's `VillaWadi`, from a picture the user liked): a sandstone house on a terrace among boulders,
    built mirrored so the dome stands on the right seen from the front: the hall (a great pointed arch over a balconied
    window and a round-arched porch, `arch_bay`; turrets with little domes; a belvedere of arches on the roof), a
    half-round loggia (`curved_arcade`, `column`), the domed drum with a curved arcade, a round tower, `stairs` with
    stepped cheeks, a round pool and majlis (`ring_wall`, `disc_slab`: UVs in metres, or hut_masonry's foot term darkens
    them), `sand_boulder`s. `res://scratch/arabian_buildings_preview.gd` (`-s`, windowed, `-- <dir>
    set=fort|tower|houses|mosque|villa style=0|1 name:x,y,z:tx,ty,tz[:fov]`) renders any of them in seconds.
  - Tower footings flare out under the ground (a rubble talus): where a pad's edge falls away one had shown as a cube.
  Single meshes: DressingColliders gives each a trimesh at race time. Keep "line" out of names that should be solid
  ("Skyline" is skipped on purpose), and "gate", "light", "lake". "cloth" is drawn from both sides (for single faces);
  `PropKit.panel` lays a back face of its own, so panels take "awning" (one-sided), or the two faces z-fight.
- `DatePalmKit.gd`: date palms (stiff blue-green fronds, a clad trunk, offshoots, date bunches) on Bloombay's palm
  shaders with an atlas of their own. WoodlandBuilder has `ghaf` and `samr` (umbrella thorn); their leaves are
  `acacia_leaves.gdshader` with `desaturate` (0 by default, so other levels are unchanged).
- Jebel Sahar: the fort Qal'at as-Sahar on the summit (its own pad), watchtowers on spurs, a village on one broad
  terrace north of the start (houses on their own pads on the dunes stood in cut-and-fill pits) with its date gardens,
  a Bedouin camp to the west, the road's lamps on the outside of the bends (or the inside where the outside falls
  away), the summit's chevron board (`ArrowSign.tscn`), the ranges to the south and the city to the north-east.
  - The lap was reshaped once (`_reshape_lap`, marked by the TrackPath's `town_route` meta; 2.82km to 3.25km): the
    summit road (`SUMMIT`) swings round the fort 57m from its middle (it ran 100m off), the fort's pad at `FORT_Y`
    a few metres over it and its gate (`FORT_YAW`) toward the hairpin; after the plunge the lap turns into the
    village (`TOWN`, on the terrace's height) through tight hairpins between the houses and out to the finish
    straight. The grid and gates are where they were.
  - No tarmac in the town: it is a road gap (`_plan_road_gaps`, like Bloombay's sand), off-road sand, its lanes the
    ground shader's piste (`piste_map`, its own texture: the ground map's R carries the rock here), garden walls
    along the street (`TownWalls`, solid) where no house fronts it. The houses face the street (`house`'s yard left
    off where the next lane runs behind).
  - Sand drifts over the road (`DRIFTS`, three road gaps with `road_gap_drift`, the asphalt crumbling into sand
    toward them through `road_crumble.gdshader`) and sand blowing across them (`SandFx`: `sand_drift.gdshader`
    streamers in two layers on a strip over the road, and GPU grains off the crest). No lamps stand in a gap.
  - The rock is the ground map's R (`_rock_at`: the slope over 6m and the height, `map_rock`): read per triangle,
    the 2m grid drew the rock's edge as a saw-tooth down every slope. Rock formations (`RockFormations`, 34 of
    `ChasmRock.gd`'s cluster, tor and arch shapes in the jebel's brown, `palette` 1, baked to
    `generated/canyon_chasm_rocks/`) stand on the steep faces. The summit has no bridge test (`bridge_factor`
    off within 100m of the middle): the reshaped road stood on concrete walls there. The road's side walls are
    sandy dressed stone (`_stone_road_sides`).
- Airliners over all four stages (`Airliners.gd`, `AirlinerKit.gd`; the user asked for passenger jets coming to and from
  the city): procedural airframes, generic shapes of no real type, "twin" (a wide-body twin-jet, 64.5m) and "quad"
  (four engines, 71m), at life size, nose -z; one mesh with every part (COLOR.r the part, `P_*`) and no livery in it:
  `airliner_body.gdshader` paints the livery from uniforms (`AirlinerKit.LIVERIES`, fictional carriers: Raihana the
  flag carrier, Raihana Cargo, Bloombay Air, Matumaini Airways, Viento, Sahar Air) and draws the cabin windows, doors,
  cockpit glazing, cheatlines, belly, tail art (SDF stars, sun, waves, band, crescent) and the tail's colour sweeping
  over the rear fuselage from the model position; what differs between airframes comes per instance (`door_z`,
  `win_z`, `art_c`, `nose_z`). Gear legs are meshes of their own built about their hinges (meta "fold_axis",
  "fold_angle"), lights a mesh of sprites (`airliner_lights.gdshader`: corners all at the light, opened out facing the
  camera and never under a few pixels across; nav, strobes, beacons, landing lights by `landing`). At night the cabins
  glow and the tail is floodlit (`night`). Both fade by dither toward the cameras' far plane and at their routes' ends
  (`vis`). `regenerate_airliners.tscn` (headless, seconds) bakes `generated/airliners/airliner_<frame>.tscn`;
  `res://scratch/airliner_preview.gd` (`-s`, windowed, `-- <dir> [frame=twin|quad] [livery=] [gear=0] [night=1] [all=1]
  name:x,y,z:tx,ty,tz[:fov]`) renders them in memory.
  - `Airliners.gd` (a node with `routes`, `fleet`, `night`) flies them at SCALE 1.6 on the wall clock (seconds into the
    UTC day, LAN peers agree; `clock_override` for lap_shots' clock=): a flight leaves each route's start every `every`
    seconds, its airframe and livery drawn from `fleet` by its number; pooled planes; nothing on a headless server. A
    route (`arrival`, `departure`, `build_route`) is a plan polyline rounded to `radius`, heights and speeds by distance
    (heights smoothed except on the ground), the main wheels' path. It banks into turns (as a life-size jet would, 25
    degrees at most), flares and lowers its nose on landing, rotates on take-off, lowers its gear `GEAR_DOWN_AT` over the
    runway and folds it after lift-off. The engines are recorded loops (`CLIPS`: `sounds/airliners/jet_approach_loop.wav`,
    `jet_climb_loop.wav`, made with tools/elevenlabs; gains from their measured RMS), louder on take-off and reverse
    thrust; `jet_roar` (synthesised) if a clip is missing.
  - The desert stages (`ArabianDresser.airliners`, called before `backdrop`): an arrival's 3-degree final passes `lat_a`
    (300m) beside the lap on one side and 650m beside the city's towers to a runway 1.6km past the city (out of reach),
    a departure lifts off short of the city on its other side and climbs out `lat_d` (550m) past the lap: over the lap at
    about 250m and 390m. Each turns in and out of its line far off (`entry_turn`, `exit_turn`), away from the stage's
    ranges; where ranges stand behind the lap (Jebel Sahar's south, Wadi's north-east) the final is shorter (`final_len`
    6km) or it flew into a peak. Both runways are graded into the country as airfields (`airfields`, `_backdrop_y`) and
    drawn (`_runway`, "AirportGround": DressingColliders leaves it). `backdrop` then checks both routes against the country
    (`country_height`) and the towers and prints how they pass the lap (it errors under 60m, away from their runways'
    last and first 2.5km). `res://scratch/airliner_map.gd` (`-s`, headless, `-- <level> <out.png> [half=5500] [px=10]`)
    maps a level's skies (the ground, ranges, city, lap, the cameras' 4km reach, the routes darker the higher);
    `res://scratch/airliner_times.gd` (`-s`, headless, `-- <level> [k=100]`) prints when each flight is where (the
    clock= to aim a shot); `res://scratch/airliner_shots.gd` (`-s`, windowed, `-- <level> <dir> clock=<s>
    name:x,y,z:plane0[:fov]`) photographs them there, aiming at a flight by its number. lap_shots shoots too soon on a
    heavy level: the airliners' new shaders compile in the background and draw nothing until ready (the race's loading
    and intro cover that in the game).
- Music: Wadi al-Ghaf plays its own track (`MusicManager.STAGE_TRACKS["wadi"]`, `music/al-raihana/Racing_the_Mirage.mp3`),
  Ramlat Hamra `Red_Sands_Pursuit.mp3` ("ramlat"), Marina Nights `Midnight_Sprint.mp3` and `music/night/Apex_Drift.mp3`;
  Jebel Sahar still shuffles `music/mountain/`. New Al-Raihana tracks go in
  `music/al-raihana/` with an entry in STAGE_TRACKS and `_stage_track_key`. `res://scratch/stage_track_key_check.gd`
  (`-s`, headless) prints which key each stage gets.
- `regenerate_desert_wadi.gd` (the old generator) lays the lap again from LakesideLevel.tscn's template and drops the
  dressing: run `regenerate_wadi_dressing.gd` after it.
- Wadi al-Ghaf: the piste (`PISTE_IN`/`PISTE_OUT`) and rally marker flags (soft: "flag" in their names) along the
  lap, the oasis's palms round the lake and the old river's bed, Husn al-Wadi on the dunes, the village by the oasis,
  watchtowers, the camp in the western bowl. Its buildings are Najdi (style 1, above), unlike Jebel Sahar's Omani
  ones: the village's houses are `house_najdi` and the plot nearest its middle is the mosque. The fort's pad holds its
  corner towers and 6m round them. The villa (`_plan_sites`: `VILLA_HALF`, `VILLA_BLEND`, `VILLA_ROAD` from the lap,
  the flattest ground found, its front toward the nearest road point; `VILLA_PALMS` in its courtyard) stands 115m off
  the lap at (-413, 99), over a dune crest from it.
- Jebel Sahar's summit pad is 30m with a 12m blend: one of its diagonals points at the summit road (bearing -95, 61m
  out), and at 35m its corner raised the ground over the asphalt's edge (`scratch/pinecrest_road_probe.gd
  level=res://levels/MountainLevel.tscn`). Behind the fort, where no road runs, the summit stands higher than the pad.
- Jebel Sahar's town has two checkpoints (`_town_checkpoint`, both in the level's `checkpoints` before the finish), or
  the town could be cut: `HalfwayTownEntry` at its entrance (s 2696, between `TOWN[2]` and `TOWN[3]`) and `HalfwayTown`
  among the houses (s 3000), 305m apart (it errors under 53m). `res://scratch/gate_offsets.gd` (`-s`, headless,
  `-- <level>`) reads a saved level's checkpoint order from the .tscn and prints each gate's distance along the lap: the
  order must rise with it. Ramlat Hamra, made from Jebel Sahar's scene, drops both town gates (they stood on its lap out
  of order) and sets its own order. The summit's chevron board points down the plunge (ArrowSign's arrow is its
  +x). Forts and watchtowers stand on rubble footings 6m (life) deep (`ArabianKit.round_tower`, `fort`, `watchtower`),
  flaring out below the ground: at a pad's edge they had stood on air. The town walls carry a coping and merlons.
- The Al-Raihana heightfields split each cell along the diagonal joining its closer heights
  (`TerrainGenerator.adaptive_diagonal`, `split_00_11`; `ArabianDresser.ground` matches): one fixed diagonal sawed
  steep slopes into teeth.
- AI races (`scratch/ai_race_test`, speed=2): Jebel Sahar (the town route) and Wadi al-Ghaf, every bot finishes
  three laps, the only respawns item blasts.
- Ramlat Hamra (stage 3, `regenerate_ramlat_hamra.gd`, headless, 45s, `levels/RamlatHamraLevel.tscn`, prefix
  "ramlat_hamra"): sunset in a sand sea of seif dunes (`ArabianTerrain.megadunes`: ridges `MEGA_HEIGHT` 50m high along
  x, `MEGA_SPACING` apart, flat salt corridors between, `MEGA_SADDLES` lowering the middle ridge a little where the lap
  crosses it, a star dune `MEGA_PEAK`). Jebel Sahar's scene is its template (gates, grid, spawners; its road gaps,
  road material and `town_route` meta are replaced). The lap (`_lap_curve`, Catmull-Rom): east along corridor A's
  north lane from the start, off-road north over the middle ridge (`CROSS_MID`, crest about 20m up) and down straight
  at Qasr al-Hamra's front (`PALACE_AT`, square to the crossing), east along its court on corridor B, off-road south
  over the east ridge (`CROSS_E`), west along corridor A's south lane over the `SabkhaKicker` (WoodenRamp, a boost
  pad before it, the TrackPath's `jump_lips`), a hairpin at the west end. The crossings are road gaps
  (`_plan_gaps`: wherever the line leaves the corridors' level, Surfaces' "gap" sand), the curve following the dune
  (`_dune_y`), the asphalt crumbling into sand at their feet (`road_crumble`). Gates are kept off the crossings. The
  palace (`ArabianKit.palace`: a domed hall over an arcade, crenellated wings with wind towers, domed corner towers, a
  pool court) is cut into the next ridge's foot on a pad whose blend stops short of the road. Salt flats are
  `arabian_ground`'s `salt_height` (crust in patches, polygon ridges). Camels (`ArabianKit.camel`), two Bedouin camps
  between corridor A's lanes, reflector posts (none on the crossings), ghaf, grass and broom, the ranges to the west,
  the city to the north-east. AI races (speed=2): every bot finishes three laps, the only respawns item blasts. No
  bridge pillars (`generate_bridge_supports` off): TerrainGenerator stood 11 under the dune crossings, buried in the
  sand, and where the dune dips under the line the crossing follows one poked out of the east ridge.
  - The canyon road (`SNAKE`): corridor A's south lane leaves its straight at x 265 and winds south of it between
    red sandstone formations (`_build_canyon_rocks`: ChasmRock.gd shapes, `palette` 2, on the inside and outside of
    each bend) back to the lane at x -200; the kicker (`SabkhaKicker`) is after it, at x -245. The straight off-road
    alternative (`AlternativePaths/DuneBypass`, `BYPASS_X0`..`BYPASS_X1`, 470m against the road's 565m, flat sand)
    runs on along the lane's line: off-road cars lose less there. Plants, grass tufts, reflector posts, camels and
    rocks keep off it (`_on_bypass`; the tufts and posts had stood on it), and no gate stands on the canyon road (a bot
    on the bypass would miss it). `res://scratch/flora_on_road.gd` (`-s`, headless, `-- res://levels/X.tscn
    [half=7.5]`) lists every MultiMesh instance within `half` of any lap path, shortcuts included (none on the four
    Al-Raihana stages).
    `scratch/shortcut_probe ... chance=1.0`: taken 22 times, rejoins cleanly, the only respawns item blasts.
  - Saif al-Hamra (`_plan_sword_gate`, `_build_sword_gate`, `ArabianKit.sword_gate`; `SWORD_X` 215 on corridor B, s 829):
    two giant scimitars crossed over the palace's avenue, as Mombasa's tusks are, each hilt standing in a pedestal
    beside the road (`SWORD_SPAN` + 2.5 out, its foot on the ground). A blade is a circular arc from the guard (9m up,
    leaving at 72 degrees) through the crossing (24m over the road's middle): a chrome edge on the arc's outside, a
    darker fuller, gold lozenges, a glowing line along the spine; a gold crossguard with langets, a banded maroon grip,
    a pommel with a red gem. The pedestals are mud brick on stone with merlons, gold star medallions and the name; the
    blades pass 1.5m apart where they cross. Solid as boxes (the pedestals) and capsules along the blades, in one body
    named without "gate" (`SaifAlHamra`: a "gate" collider counts as road). Uplights at each foot. Gates and plants
    keep off its feet.
- Wadi al-Ghaf's water is wadeable everywhere (`WADI_RIVER_BED_Y` 1.25 under a 1.7 surface; within the water's
  reach the ground never lies under the bed) and the ford's road no lower than `FORD_Y` (1.2,
  `regenerate_wadi_dressing._raise_ford`): the water slows a cart (PlayerCart's shallow drag), the strip of land
  between the lake and the river is the quick line. A metre deep, bots drowned at the ford a dozen times a race,
  and the rejoin planner (`_deep_water_at`: 0.6m under the surface) found no way back from beside it. The water's
  colours are set in `TerrainGenerator.add_wadi_river_water` (it rebuilds the water at runtime): clear green-teal.
- Marina Nights (stage 4, the finale; `regenerate_marina_nights.gd`, headless, about a minute,
  `levels/MarinaNightsLevel.tscn`, prefix "marina_nights"): a night street race through the city the other three stages
  see on their horizon. Ramlat Hamra's scene is its template (gates, grid, spawners; its AlternativePaths are dropped).
  Ground: `ArabianTerrain.marina_height` (flat land at `MARINA_LAND`, the sea south of `coast_z`, the creek along
  `creek_x` to `MARINA_CREEK_HEAD`, quays dropping to the bed), which TerrainGenerator returns as it is: nothing graded
  toward the lap (graded up to the old road's height, the ground had cut through the souk's houses 24cm over their
  floors). Drawn by `marina_ground.gdshader` (sandstone slabs, promenades from the ground map's R, palm beds G, dressed
  stone on the quay faces); the sea is `MarinaWater` (a plane at y 0, PlayerCart's general water branch). The ground is
  chunked (80m), and every other mesh here is built in pieces, for the Mobile renderer's per-mesh light limit.
  - No TerrainGenerator road (`_generate_road_and_sand` returns for the prefix). The lap is straights and arcs (`CORNERS`,
    `_fillet`, `_at(s)`; heights `_lap_y`: the land plus `ROAD_LIFT` 5cm, the bridges' humps, the tube's deck), the
    TrackPath sampled from it every 4m and closed on itself. `_build_roads` lays a ribbon per section (`_road_sections`:
    [s0, s1, kind, half width, body name]) in `marina_road.gdshader`: UV x across, y along, UV2.x the kind (0 the city's
    asphalt with lane lines, studs and kerb stones, 1 the souk's setts, 2 the palm avenue's pavers in a diagonal bond,
    3 the bridge decks with blue LED studs breathing, 4 the tube's resin deck with LED edge lines, 5 the plaza, polar
    about `plaza_c`), a stone threshold (a steel joint on decks) where the kind changes (COLOR.r). Its vertices are pulled
    toward the eye (as the skid marks'), so a ribbon 5cm over the ground wins the depth test. Every triangle the lap
    runs on (the ribbons, the decks, the plaza's paving) is one body, `LapRoad` (`_build_lap_body`: track, surface
    asphalt): split into pieces, a cart's sphere caught the next piece's leading edge on the corniche bridge's slopes and
    was thrown a metre up (`res://scratch/lap_hop_probe.tscn -- [level=] [lat=] [from=] [seconds=]`, headless, drives a
    real cart along the lap and lists every hop with what it left). `road_width` stays 15 (the AI's road half).
  - The lap (2.6km): the corniche east (the start, the Pearl Ring's jump), Jisr al-Qamar over the creek's mouth, right
    into Mamar al-Bahr, the glass tube out over the sea round the marina and back to the avenue's foot (its portals 290m
    apart), Al-Manara Avenue north, the north road west across the fountain plaza and over the creek under the
    `CreekArch`, the souk's nine sharp corners (12m, a hairpin), the palm avenue south to the sea. Gates (placed by spot,
    in lap order): in the tube (or the marina walk would cut it), on the avenue, on the north road, on the souk's long
    lane (Ramlat's HalfwayTown is the fifth), on the palm avenue.
  - Jisr al-Qamar (`_build_arc_bridge`): the deck humps `ARC_H` (7m) over `ARC_HALF` either side of the creek's axis
    (cos², at most 14%), on two arch ribs of white stone springing from the quays, spandrel columns, lines of light along
    the ribs' outer faces and the slab's fascia (`ledchase`: colours drifting slowly), lanterns on the balustrade,
    uplights at the springings. `_deck_edges` (both bridges): walkways flush with the deck (off-road; at 15cm their kerb stood at the road's edge),
    the balustrade (boxes),
    retaining walls where the deck stands over the land, and wing walls flaring out at the way in: two bots had slipped
    past the balustrade's end and wedged beside the creek bridge's ramp.
  - Mamar al-Bahr (`_build_tube`): deck `TUBE_HALF` (9m) a side, `TUBE_Y` over the sea rising to `TUBE_CREST` at the far
    straight; the vault a circle through the deck's edges and the crown `TUBE_CROWN` (13.5m, so the High Chase camera
    rides inside it); steel ribs every 6m (`marina_rib.gdshader`) with LED strips (`ribled`: marina_led with `cam_fade`),
    both dithered away within 2.5-6m of the camera; purlins; the glazing one sheet (`marina_glass.gdshader`: Fresnel, a
    made-up night reflection, mullions; render_priority 2, after the sea); upstands with LED lines, a box girder with a
    lit fascia, piers every 24m lit at the waterline, stone portals with the name, lamps under the crown every 32m. Solid:
    the deck (`TubeDeck_n`, track) and walls 3.4m high inside the glass (`TubeWalls`; the meshes are under it, so
    DressingColliders leaves them). Round the outside of the right turn into it a wall with glowing chevrons
    (`_build_turn_wall`): off the bridge's crest one bot in eighteen ran wide onto the promenade and stuck.
  - The fountain plaza (`_build_plaza`, `PLAZA_C` on the north road): the road stops at its paving (each ribbon's end cut
    to its circle, `_row_on_circle`; the paving a centimetre higher) and starts again past it; the lap rounds the
    fountain's north side, the south way is as short. Paving in four quarters (`FountainPlazaDeck_n`, track).
    `MarinaKit.plaza_fountain`: three marble steps with a band of eight-point stars before them (the shader), a basin of
    blue tiles lit under the water, the column and three bowls (FountainShow, `base_y` the basin's floor). A ring of
    planters with palms and lit bollards closes it but where the roads come in; outside it café tables under parasols,
    benches, lantern posts, people (CrowdPlacer, a Gulf mix of skins).
  - The souk (`_build_souk`): houses along both sides of every lane (fronts 9.2m off the line, 2.3m further where it turns,
    `_corner_room`: a bot wedged against the fronts out of a corner), the blocks behind packed from big houses to small
    (`_foot`: oriented boxes, `_obb_hit`; none overlap, so no roofs or plinths at one height z-fight), mud walls along the
    lanes wherever no house fronts them, the market hall Souk al-Lulu (`MarinaKit.souk_hall`) on the long lane, a
    watchtower, strings of bulbs across the straight runs (named "...Light...", soft). 40m cells, one mesh each
    (DressingColliders makes them solid). The first souk flickered: its awnings were `PropKit.panel` (two faces) in
    ArabianKit's two-sided "cloth", which z-fought with itself; "awning" is the one-sided key for panels (Wadi al-Ghaf's
    rally flags had the same).
  - Dawwar al-Bahr (`_build_wheel`, `FerrisWheel.gd`): a 136m wheel on an island east of the marina with a footbridge,
    facing the start (from the grid it stands inside the Pearl Ring); bands of LEDs on the rims' faces (thin strips round
    their outsides didn't show from the start), lit spokes, 36 glowing cabins kept level (a MultiMesh, set on the physics
    tick: from `_process` physics interpolation warned), on the wall clock.
  - Light: MarinaKit's "led", "ledchase", "glasslit" and "lamp" are `marina_led.gdshader` (unshaded, vertex colour times
    `energy`). CampKit's "lamp" gives off no light at all (see "Lamps on the night and dusk stages"), so this generator
    builds through `MarinaKit.new_kit` only, and ShipKit's sailboats go through `LampGlow.fix_mesh`. About 95 real OmniLights, no shadows, faded past
    150m: the street lamps (none in the tube, the plaza, the souk or on the bridges), the souk's strings, the plaza, the
    bridge's lanterns and uplights, the tube.
  - The city is `GulfCity.gd` (BloombayCity's facade machinery): `gulf_block` (stucco, stepped merlons, a setback top
    floor, a wind tower, a dome or a pergola on the roof) and `gulf_tower` (sail, twisted, stepped spire, lattice
    crown, twins with a sky bridge). `city_building.gdshader`'s `gulf` (off everywhere else) draws pointed-arch
    windows, mashrabiya screens over half of them, an arcade of pointed arches with warm shops along the ground floor
    instead of neon sign bands, vertical bronze fins on the towers. The user found the first version (BloombayCity's
    boxes) too like Mtaa Nights'. Cells 55m within 90m of the lap (each takes in only the lights near it), 220m beyond;
    none on the plaza, the marina walk, the souk or the wheel's shore. A lit city past the terrain's edge
    (`_build_far_city`, `FarSkyline_<x>_<z>` in `FAR_CELL` 1.3km cells, GulfCity's `far`: no merlons or roof pergolas).
    Whole and in full detail it was 1.7 million triangles in one 133MB file, which GitHub refuses (100MB a file) and
    which hung the push; now 3MB in all. Keep every generated file well under 100MB.
  - The marina walk (`_build_promenade`): where the corniche ran before the tube took the lap out to sea, a promenade from
    the quay to the town (the ground map's R), with the corniche's sea front: lantern posts along the quay, benches
    facing the sea, kiosks with café tables, people. The marina between the tube's legs (`_build_marina`): pontoons with
    finger berths, ShipKit's sailing yachts and MarinaKit's yachts, three superyachts on the outer pontoon; a superyacht
    and a motor yacht cruising outside the tube (SeaBoat, `generated/marina_nights_boat_*.tscn`). Dhows moored in the
    creek.
  - `MarinaKit.yacht(pk, kit, rng, length, style)` (metres, the bow toward +z: SeaBoat's convention): ShipKit's hull with
    a boot stripe and a sheer stripe (`YACHT_STYLES`), lit windows along its topsides, anchors in their pockets, a swim
    platform with steps and the tender garage's door; decks of rounded plan (`_rounded_plan`, `_house`: fronts raked
    back, dark windscreens, a third of the side panes lit) each roofed by a wider slab (`_slab`: teak, a white fascia, an
    LED line under it), chrome rails, a hardtop on pillars with the mast (radar domes, a scanner, lights), a hot tub and
    sun pads forward, navigation lights (starboard green on -x), blue lights along the waterline aft (a glowing quad
    under the stern, meant as light in the water, lay on the sea as an opaque blue slab). 44m: three decks (5.2k
    triangles), 24m: two. `res://scratch/yacht_preview.gd` (`-s`, windowed, `-- <dir> [length=] [style=] [night=1]
    name:x,y,z:tx,ty,tz`) renders one in seconds. (The first, `ArabianKit.superyacht`, was boxes; it is no longer used.)
  - The start's promenade (`_build_start_promenade`): a grandstand opposite the finish line on the sea side
    (`MarinaKit.grandstand`, `STAND_LAT`, `STAND_LEN`; a single mesh named "Grandstand", so StageAmbience cheers from it,
    and DressingColliders makes it solid) under a tensile canopy, about 120 seated fans; people two deep behind crowd
    barriers along both sides of the straight (`BARRIER_LAT`; the sea side's start is past the south-west corner's exit:
    a bot run wide out of it stuck at the line's end), banner poles at the line, shade sails over benches, kiosks with
    café tables, flower beds, strings of lights between the palms, a balloon seller, fishermen at the rail with their
    rods, families out walking. `_in_stand` keeps palms and furniture off the stand. About 575 people on the stage.
  - `Fireworks.gd` (node `Fireworks`): shells over the sea south of the tube and the boats on the wall clock (LAN peers
    agree), pooled GPUParticles3D bursts (peony, ring, willow), a flash light per burst, a synthesised boom delayed by the
    distance; none headless.
  - Bab al-Lulu, the Pearl Ring (`_plan_ring`, `_build_ring`, `ArabianKit.pearl_ring`): a gilded ring with LED strips and
    a glowing pearl over the corniche, `RING_PAST_LIP` (10m) past the `PearlKicker` (WoodenRamp, lip 4m over the road, a
    boost pad 28m before it; the TrackPath's `jump_lips`). Its foot is 0.65m under the road, so the opening's bottom is
    3.65m over the road (with the ring on the land, as the road was lowered 0.6m, carts at 22 m/s clipped it). Capsule
    colliders round the torus (`PearlRing`), cylinders for the pylons. `nyota_jump_test ...
    level=res://levels/MarinaNightsLevel.tscn ground=1`: 22-60 m/s all through, speed kept.
  - Qaysariyyat al-Manara (`_build_arcade`, `ARCADE_Z0`..`ARCADE_Z1`, 300m of Al-Manara Avenue after the marina walk; the
    user's "modern souk" the lap runs through): a hall `HALL_HALF` (16m) either side of the avenue's line in 10m bays
    (`BAY`): two storeys of shops either side (`_arcade_front`: lit rooms behind pointed arches with carpets, lamps,
    spices or gold in them and a lit ceiling panel, canopies over some, the gallery's balcony with a lattice balustrade
    and a gold rail, an arched door above, the cornice with a line of light), patterned stone walkways with a kerb
    (`_arcade_walk`), a pointed vault (`_vault_profile`: two arcs `VAULT_R` from their feet, springing at `SPRING`, the
    crown about 34m up) of mashrabiya lattice (`marina_lattice.gdshader`, MarinaKit key "lattice": eight-pointed stars
    cut out by discard, the bars backlit gold) between carved ribs with lines of light, lanterns hanging from the crown,
    a portal at each end (`_arcade_portal`: the opening's stone frame, gold lines, a lattice band with the name, two
    lantern towers). The lattice's light lies on the road and walkways (`arcade_floor_light.gdshader`: soft stars,
    additive, pulled toward the eye further than the road so it wins the depth test). Café tables and planters on the
    walkways, about 90 shoppers below and on the galleries, 10 real lights, the market's murmur from four players
    (`sounds/arcade/souk_arcade_loop.wav`, made with tools/elevenlabs). Its footprint is reserved (`_reserve_landmarks`)
    before the city is built; no street lamps or palms inside. Solid: the shop fronts (a box a side), the portals and
    towers, the furniture. Halfway3's gate stands in it.
  - Al-Mu'allaq (`_build_suspended`, `SuspendedTrains.gd`), a suspended railway after Wuppertal's, 933m: from its city
    terminus north of the souk (Mahattat al-Madina, `STATION_CITY`, in a forecourt of its own) over the souk's roofs
    (frames among the houses, reserved before the souk is packed), down the palm avenue's line (`LINE_X`) without a
    stop (one over the street read as a train halting for nothing: no station shows from the road), over the corniche's
    corner (a 66m span) and 650m of sea to Jazirat al-Fanous. The terminus has a hall under its platforms
    (`_terminus_hall`: two stone wings with lit pointed windows and the line's name, a lower glazed hall under the tracks,
    a grand entrance at each end with the station's name). Two tracks `TRACK_OFF` either side, each a box-truss girder (`_truss`) with the rail hung under
    it on brackets (running surface `RAIL_Y`, 27m up) and a line of light; lattice portals over the street (`LEG_U`) and
    piers on concrete caps in the sea (`SEA_LEG_U`), at `FRAME_Z`, clear of the cruising superyacht's lanes (it crosses
    the line at z 435 and 575: the spans there are 66m). Stations (`_rail_station`): platforms at the cars' floor,
    railings, benches, a canopy with the line's and the station's names, glazed lift towers down to the ground. The cars
    (`MarinaKit.hanging_car`, life size, grown by PS: bogies on the rail, hangers, a rounded body, lit windows, a cab at
    each end of a two-car train) hang 20m over the street, above the race cameras. `SuspendedTrains.gd` shuttles a train
    on each track between the stations on the wall clock (accelerating to `cruise`, braking, `dwell` at each end, the two
    half a turn apart), swings them fore and aft as they speed up and brake (a damped pendulum about the rail, local), and
    sounds them (tools/elevenlabs): the run of wheels on the rail and the girder's hum (`suspended_train_run_loop.wav`,
    with the speed), a pass-by burst once a pass when one comes within `PASSBY_NEAR` of the camera (`suspended_passby_*`),
    the brakes into a station, a chime as one pulls out. Palms and lamps keep off its feet (`_near_rail_foot`).
  - The start promenade's crowd cheers the racers by (`_build_cheers`, `CrowdCheers.gd`): a section behind each side's
    barriers every 30m along the straight and a louder one at the grandstand; a cart within `reach` faster than
    `min_speed` sets a section off, a random clip of six (`sounds/crowd/promenade_cheer_*.wav`, tools/elevenlabs, each
    levelled by its loudest second), louder the faster, then it rests `cooldown` and a little more, so the cheers roll
    along with the pack. Local to every peer. The souk's corner room (`_corner_room`) runs 32m past each corner: car 4
    wedged in the houses 29m past the right-hander at (-230, -75) in two races of three before.
  - Jazirat al-Fanous (`ArabianTerrain.MARINA_ISLAND`, `marina_island_d`: land in `marina_water_d`, so the terrain bakes
    it with quay walls; the ground map paves it) off the palm avenue, past the fireworks, its north shore clear of the
    superyacht's loop. Burj al-Fanous (`_build_island`, `MarinaKit.fanous_tower`, an original landmark, 307m to its
    beacon): an octagonal podium, a drum with tall pointed windows, the lantern itself (an octagonal body bulging like a
    fanous, `fanous_r`) of lattice ("lattice_big": dark burnished bars against a bright core inside, so the pattern
    reads; with the bars glowing as brightly as the core it was a glowing egg), gold ribs and bands with lines of light,
    an octagonal onion dome lit gold, a spire with three orbs and a red beacon. Floodlights round it, eight searchlights
    (`SkyBeams.gd`: cones along their +y in `club_beam.gdshader`, turning in slow circles both ways and leaning, on the
    wall clock), palms round the shore and up the walk from the railway's station, lantern posts, people.
    `res://scratch/marina_landmark_preview.gd` (`-s`, windowed, `-- <dir> [set=fanous|car] name:x,y,z:tx,ty,tz`) renders the
    tower or a train in memory at night.
  - Airliners at night (`_build_airliners`, see "Airliners" under the Al-Raihana GP): arrivals from the west along the coast
    1.25km offshore (beyond the island, 438m clear of the tower) to an airport east of the city, departures climbing out
    west 1.95km offshore: landing lights, strobes, lit cabins and floodlit tails over the sea.
  - The city's name in gold (`_build_raihana`, `RAIHANA_*`, node `RaihanaName`): الريحانة, 48 x 22m, on a stone plinth
    in the sea 55m off the coast between the creek's mouth and the tube, facing the bridge's crest and the corniche past
    the grandstand (which hides it from the grid). The word is Amiri Bold (`fonts/Amiri-Bold.ttf`, SIL Open Font
    License, `fonts/Amiri-OFL.txt` beside it) through Godot's TextMesh, which shapes the joined Arabic itself, baked to a
    mesh: no font at runtime. Reem Kufi, a variable font, broke TextMesh's triangulation (self-intersecting outlines).
    TextMesh centres the line box, so the baseline is (descent - ascent) / 2 times `pixel_size`; the plinth's top is the
    baseline, and under the ر's tail and the ي's two dots (all below the baseline, found from the mesh's vertices) its
    front steps back into a bay so they hang free: on the top they would be buried, and ي without its dots is another
    letter. `raihana_letters.gdshader` is polished gold that also lights itself (as if uplit, by the mesh's own height)
    and reflects a made-up night by the reflected view ray, since the real uplights fade past 220m;
    `raihana_glint.gdshader` lays streaks of glitter on the sea before it (value noise stretched along the way to the
    viewer, drifting; a hash per column and ripple row had drawn a grid of dashes). "AL-RAIHANA" in Latin letters
    (Label3D) on the plinth's face where nothing hangs. `res://scratch/arabic_text_preview.gd` (`-s`, windowed, `-- <dir>
    font=<ttf> [font=...] [text=] [size=64] [depth=0.35] name:x,y,z:tx,ty,tz[:fov]`) extrudes a word in each font given,
    one row per font, to compare them.
  - Music `MusicManager.STAGE_TRACKS["marina"]` (Midnight_Sprint and Apex_Drift), ambience city and harbour.
  - Cost (M1, 1280x720, `scratch/bench.tscn` samples=16): 11.5ms GPU on average along the lap, the worst 16.9ms, about
    600 draws and 5.5M primitives; with the arcade, the railway, the island and the airliners 10.5ms, the worst 12.9ms,
    656 draws, 5.6M (the M1's clock moves runs that much).
  - AI races (speed=2): every bot finishes three laps, the only respawns item blasts (out of the souk's corners bots had
    fired boosts into the next one: see "AI boosts"). With the arcade, the railway and the island, two races: every bot
    finished both; one had a bot wedged once among the souk's houses 10m off a lane (2269m) and once beside the creek
    bridge's ramp (1744m), the other only item blasts. Nothing on the avenue or the palm avenue. `res://scratch/unused_generated.gd -- marina_nights_` (`-s`,
    headless) lists the generator's leftovers in generated/ that no scene loads any more.

## Kronburger Hütte (Kronburg GP, stage 1)

A fictional town in the Ruhrgebiet on a summer afternoon: the canal, the steelworks (the Kronburger Hütte), the colliery
estate, the half-timbered old town on its hill under Burg Kronburg's ruin. Stage 1 of the Kronburg GP
(`NetworkManager.GP_CUPS["Kronburg GP"]`; stage 2 is Rheinufer, stage 3 Zeche Kronprinz). Files and code keep "kronburg" (`KronburgLevel.tscn`, `regenerate_kronburg.gd`).

- `regenerate_kronburg.gd` (`regenerate_kronburg.tscn`, headless, about 15s) builds `levels/KronburgLevel.tscn` from scratch.
  The lap (3.0km) is straights and arcs (`CORNERS`, `_fillet`, `_at(s)`): the Kanalstraße east beside the canal (the start),
  left through the works gate, right into the rolling mill hall (`HALL_X0`, `HALL_Z`, `HALL_LEN`: 240m straight through
  it), left round the blast furnace, left onto the works' north road under the pipe bridges (the `SlagJump` kicker), up
  through the colliery estate (10.5%, `MAX_GRADE`), through the town gate along the Hauptstraße, round the Marktplatz
  (`C7`, r 22), down the Kirchberg and back onto the Kanalstraße.
- Ground: `_natural` (the valley's side rising to the north-west by `_rise(u)`, u the distance up it; hills; the castle hill;
  the far country; the canal's plain), then the pads (`WORKS_RECT`, `MARKT_RECT`, `SPORT_RECT`, the castle's top), the slag
  heap (`HALDE_*`), the canal cut (`CANAL_Z`, `CANAL_HALF`, sloped stone-pitched banks) and the harbour basin
  (`HARBOUR_RECT`). The canal and harbour only cut where they are (`dzc < CANAL_HALF`, `hd < 0`): as `min()` everywhere they
  capped the whole map at the bank's height. The road's height is the natural ground along the lap smoothed, the square
  held level (`MARKT_HOLD`), no grade over `MAX_GRADE` (`_plan_road_heights`); `_grade` lays the ground `GROUND_UNDER` under
  the road across the ribbon and a verge, rounded shoulders beyond. `kronburg_ground.gdshader`: grass and dirt on banks;
  vertex masks R sandstone (steep faces, the canal's riprap), G the works' slag and old concrete, B farmland (a patchwork
  of fields in Voronoi cells: meadow, wheat, rapeseed, maize, ploughed, hedgerows on the borders), A woodland floor.
  Bodies: KronburgMeadow (grass), WorksGround (gravel), KronburgCrag (rock).
- Roads are ribbons (`_build_roads`, `kronburg_road.gdshader`, kinds by s in `_road_kinds`): 0 country asphalt with German
  markings (6m dashes in 18m, edge lines, a gravel Bankett), 1 the old town's setts in segmental arcs (Bogenpflaster) with
  a sett gutter, kerbs and sandstone flag pavements (`PAVEMENT` 3.4m on the ribbon), 2 the estate's asphalt with kerbs and
  grey 30cm flags, 3 the works' concrete slabs, 4 the mill hall's floor, 5 the Marktplatz (world-space arcs, dark bands;
  the square's own paving `_build_markt_paving` is drawn the same and coplanar), 6 the canal's towpath (dressing only).
  Everything the lap runs on is one body, LapRoad. The shader's `stripe()` is box-filtered coverage: Marina's
  fade-to-share version, used for a single centre line, whitened the whole road's width at a distance.
- The old town (`_build_town`, `KronburgTownKit.gd` at PROP_SCALE): St. Lamberti on the square's north side, the Rathaus on
  its west, the fountain, the Maibaum, the weekly market (`MARKET_STALLS`, CampKit gazebos), lime trees, rows round the
  square (`_row`), gable houses along both sides of the Hauptstraße and the Kirchberg (`_frontage`, fronts on the
  pavement's edge `FRONT_LAT`; `house_extent` says how far steps, jetties, awnings and signs reach out, up to 2.1m life),
  back lanes (`LANES`, `_build_lanes`: cobbled ribbons off the lap with houses both sides), the Kronentor on the
  Hauptstraße (its field side, +z, faces out of town), the wall with round towers (`_build_town_wall`, open where the lap
  and the lanes pass), Burg Kronburg's ruin (`CASTLE_C`), garden trees. The colliery estate: brick terraces in their front
  gardens along the climb and its back street (`ESTATE_STREETS`), the Trinkhalle on a corner.
  - `KronburgTownKit.gd` (extends YardKit; life size, footings to -4): `fachwerk_house` (variants 0 white and black, 1
    coloured on a stone ground floor, 2 Bergisch slate with green shutters, 3 a shop with its sign and awning, 4 eaves to
    the street with dormers), `church`, `rathaus`, `market_fountain`, `town_gate`, `brick_terrace`, `trinkhalle`,
    `litfass`, `ortsschild`, `peitschen_lamp`, `old_lantern_post`, `bus_stop`, `street_bench` (not `bench`: YardKit's has
    another signature), `bollard`, `bike_rack`, `glass_containers`, `beer_crates`, `castle_ruin`, `allotment`,
    `beer_garden`, `maibaum`. Its keys: `biber`, `ashlar`, `kslate`, `kbrick` (hut_masonry styles 9 plain tiles, 10
    ashlar, 11 slate scales, 12 Ruhr brick, all fading their fine pattern by `fwidth`: style 2's mortar and style 6's
    lichen read as moiré and blotches on long walls), `pane` (opaque glass), `gold`, `enamel`, `leaf`, `kwater`
    (kronburg_water.gdshader), `hedge`. `res://scratch/kronburg_town_preview.gd` (`-s`, windowed, `-- <dir>
    [set=houses|church|rathaus|gate|fountain|terrace|kiosk|street|castle|misc|all] [sheet=1] name:x,y,z:tx,ty,tz`) renders
    them in seconds; `scratch/kronburg_town_dump.gd` saves them for `scratch/zfight_scan.gd`.
- Props are batched (`_add_prop`): many props built into one kit per 140m cell (a mesh with a surface per material),
  saved under `kronburgprop_` (MeshChunker leaves them whole, so DressingColliders makes them solid), materials saved once.
  The node is the batch key in PascalCase, so keep DressingColliders' and PlayerCart's track words out of keys: the gates
  are "kronentor" and "works_werkstor" (named "...Gate" they were skipped and carts drove through their towers), the
  chimneys "works_chimneys" ("stack" is SOFT), the torpedo cars' rails "works_rails" ("track" is road).
  Kit calls go through `_kit_call`, which skips (and warns once about) a builder a kit lacks. Every run first deletes
  `generated/kronburg*` (renamed or dropped props leave nothing behind).
- The works (`_build_works`, `SteelworksKit.gd` at PROP_SCALE): the rolling mill hall over the lap (`_hall_xf`: the kit's
  -z along the lap), the blast furnace (`FURNACE_AT`: its skip incline runs 138m toward +z and first crossed the lap by
  the hall's exit; after moving anything, check `generated/kronburgprop_works_*.res` AABBs against the lap), the hot blast
  stoves and the hot-blast main to the furnace (`pipe_run` between their flanges), the gas holder, the cooling tower,
  three stacks, two pipe bridges over the north road, the works gate, torpedo ladle cars on their track, the harbour's
  ore crane, barges and stockpiles, the ore yard (`ORE_YARD`: a second ore bridge over long piles; a shorter
  `rolling_hall` there showed its mill line's cooling bed sticking out of its end: the mill train is laid for 150m),
  pipe runs on racks, the car park (`CAR_PARK`, CampKit cars), the steel crown on the slag heap, Zeche Kronprinz's
  headframe above the estate. `_build_works_fx`: OmniLights and sparks at `SteelworksKit.hall_fx_spots` and
  `works_fx_spots` (the tap hole, the pour), steam off the cooling tower, smoke from the stacks and stoves (`_plume`).
  - `SteelworksKit.gd` (life size, footings to -3): `rolling_hall`, `blast_furnace`, `cowpers`, `gasometer`, `chimney`
    (0 brick, 1 red and white), `cooling_tower`, `pipe_bridge` (+ `pipe_bridge_z`), `pipe_run`, `headframe`, `torpedo_car`,
    `works_gate`, `steel_crown`, `ore_crane`, `barge` (bow +z, waterline y 0: SeaBoat's convention, `draft` 0),
    `stockpile`. Shaders: hot_steel (vertex colour the heat), steel_glazing (inside face daylight), industrial_paint
    (weathering by world position: keys rusty, corten, grime, floor, shell, roofing, heap), hazard_stripes, ruhr_brick.
    Road corridors (checked on the triangles by `scratch/steelworks_corridor_check.gd`): the hall keeps |x| < 6 clear
    below 12 (life) and its gateways 16m wide, 13m high; a pipe bridge nothing under its `clearance` over its span; the
    gate nothing in |x| < 8 below 11. `res://scratch/steelworks_preview.gd` (`-s`, windowed, `-- <dir>
    set=hall|furnace|cowpers|gasometer|stacks|pipes|headframe|torpedo|gate|crown|harbour|all name:x,y,z:tx,ty,tz`).
- The Marktplatz: the lap goes anticlockwise round the fountain (C7-C11: up its east side, behind it past a checkpoint,
  down its west side, back along its south side past the market) and right down the Kirchberg. The way in and the way
  out only meet at the square's corner (`MARKT_JUNCTION`, about 19m apart). A first version went clockwise and crossed
  its own way in there: a human driving round it the other way was taken by the missed-gate watch for past the market
  gate, heard "checkpoint missed", and the gate then never counted. The square's paving is all one, so the lap shows
  only by a line of knockable cones (`_build_markt_cones`, `MARKT_CONES_FROM`/`TO`, "MarktCones": KnockableProps, the
  thud) from the market's east end through the corner onto the old corner's verge, the way the user drew it: it keeps
  the way in and the way out apart and marks the corner straight onto the Kirchberg (left open: the user didn't want it
  blocked). The square's height and paving run from `MARKT_IN` to `MARKT_OUT`; the weekly market stands inside the
  loop facing the fountain, the maypole, Litfaßsäule and two limes in the square's north-east corner.
  `scratch/human_skip_test ... level=res://levels/KronburgLevel.tscn skip=-1 gates_after=6` drives a real cart round
  it: the market gate counts, nothing said.
- The works' car park is "ParkplatzWerk" and its MultiMeshes "ParkedCars_*" (DressingColliders' ROCKY "parked": solid,
  no wobble): as "Werksparkplatz" it held "spark", one of DressingColliders' SOFT words, and the cars had no collider.
  The stockpiles are batched per 200m cell (`_pile_key`): as one mesh 524m across DressingColliders skipped it as ground
  (it gives no single mesh over 400m a collider) and carts drove through every heap. `res://scratch/wide_prop_meshes.gd`
  (`-s`, headless, `-- <level> [limit=400]`) lists a level's meshes that wide.
- The Leitpfosten (all three Kronburg GP stages) were built upside down (the frame's z points down; the bands' z ranges
  were the wrong way round): only their top 43cm, white and black overlapping, floating 1.2m up.
- The canal's water sheet is wound clockwise from above (`_build_canal`): wound the other way it was culled and the canal
  read as clear water over its bed. The harbour's ore unloader stands on the north quay (`_crane_xf`, face -x: its girder
  out over the basin, its rails along the quay on land, `ORE_CRANE_LIFT` up so the rail heads no longer lie flush with the
  pad and flicker), the stockpiles along the quay between its legs; its rails had run out across the basin through the
  moored barges and the piles' ends 10m into the water.
- The football pitch's goals (`_goal_frame`: square posts and crossbar, the net's frame of top arms, sloping end
  stanchions and ground bars, nothing in the net's middle) and their nets (`GoalNet.gd`, `goal_net.gdshader`, under
  `Bolzplatz`): the net gives where the ball (any KickBall) or a cart presses it, springs back and wobbles; it catches the
  ball (a spring and drag, `BALL_*`) so it drops into the goal, and stops a cart (`CART_*`: a spring, then a wall at
  `CART_GIVE`; applied by the peer that drives the cart). It has no collider, so it can give. In or out of the goal
  changes only across the mouth. A football waits on the centre spot. `res://scratch/goal_net_test.tscn -- [<dir>]
  [goal=West] [speed=30] [up=7] [from=10] [lat=1.5] [cam=x,y,z] [frames=...]` (windowed for frames) shoots it into a goal
  and logs the ball and the net's bulge; `cart=front|back` (headless) drives a real cart into the net from inside the
  goal or from behind and prints how far it got.
- The Halde detour (`_plan_detour`, `DETOUR`, the user's idea, as if the organisers had sent the lap off the road): after
  checkpoint 2 the lap leaves the straight north to the blast furnace (C3-C4) eastward, climbs the slag heap through its
  birch woods, rounds the steel crown anticlockwise (a gate behind it, `DETOUR_GATES[0]`) and comes down the north-west
  flank (a gate at the woods' edge, `[1]`, so the top can't be skipped) onto the north road after C4. No road: CORNERS and
  the road ribbon are unchanged, only the TrackPath (`_spliced_curve`: the bots' line, the gates' order, the minimap) runs
  over it, 690m off-road against the road's 201m (TrackPath 3733m, the road's lap 3228m). The ground there is off-road (it
  isn't TerrainGenerator's, so PlayerCart's corridor rule doesn't call it road). Red-and-white marker poles with orange
  pennants lead the way (`_build_detour_poles`, knockable, staggered every `DETOUR_POLE_EVERY`); the trees keep off a lane
  `DETOUR_LANE` either side of the bots' line, the poles and the gates (`_keep_clear`, `_off_lap_clear`), dense
  either side. AI races (speed=2, noitems): every bot finishes three laps, no falls or stuck carts; flying laps 94-110s
  (about 72s before), so stage 1's lap records date from the shorter lap.
- Shortcuts (`_build_shortcuts`, AlternativePaths, off-road, with boost pads): `Rasenschnitt` across the lawn inside the
  hairpin before the start (`LAWN_CUT`, `LAWN_PADS`; the start's barriers are short, `START_BEFORE` 45m and
  `START_AFTER` 40m, so it rejoins before them) and the hidden `Kleingartenweg` along the 5m walk between the allotments'
  two rows of plots (`ALLOT_PATH`, `ALLOT_PADS`, `ai_chance_scale` 0.5). `scratch/shortcut_probe ... chance=1.0`: every bot
  rejoins. The car park leaves out cars where the works gate's walls run through its rows (`_clear` against the walls'
  note).
- Ground masks: every vertex of the fine grid takes `_masks`, however far from the road (`_road_d` capped under 1e8:
  past the grading's reach it read as the coarse land's and painted fields inside the works).
- `res://scratch/kronburg_hide_shot.tscn -- <out.png> x,y,z:tx,ty,tz [hide=<node path> ...]` (windowed) renders the level
  from one camera with nodes left out, to find what draws what.
- Germany besides: the Autobahn viaduct across the valley west of town (`_build_autobahn`, `AUTOBAHN_*`, hillside to
  hillside) with traffic (`AutobahnTraffic.gd`: CampKit vehicles on the wall clock, shrinking away at the ends),
  Leitpfosten (knockable delineator posts, `_build_delineators`, KnockablePoles), traffic signs (`_traffic_sign`: Tempo 30
  zone, warning triangles, the priority diamond), place-name signs, whip-arm street lamps, the allotments (`ALLOT_*`), the
  beer garden, the red-ash football pitch (`_pitch`, SV Glückauf Kronburg), barges on the canal (SeaBoat: one cruising a
  3.6km loop whose turns lie out in the haze, two moored in the harbour).
- Sound: `sounds/kronburg/` (tools/elevenlabs): the mill's hum in the hall, the furnace's roar, St. Lamberti's bells every
  150s on the wall clock and the crane horn (`PeriodicSound.gd`), the barge's diesel. StageAmbience: city and birds.
  Music: `MusicManager.STAGE_TRACKS["kronburg"]` (the GP's own instrumental tracks, `music/kronburg/`).
- AI races (`scratch/ai_race_test`, speed=2): every bot finishes three laps, the only respawns item blasts; flying laps
  about 72s.
- Cost (M1, 1280x720, `scratch/bench.tscn`): 9.9ms GPU on average along the lap, the worst 12.9ms (the old town and the
  works); about 1.0M triangles of props, the town's houses most of them.
- Menu tiles: `images/menu/tile_kronburg.jpg` (the mill's gateway) and `tile_kronburg_gp.jpg` (from over the canal),
  rendered with `scratch/lap_shots.tscn` and cropped to 1376x768.

- A four-seat touring plane (`LightPlane.gd`, node `Rundflug`, added by all four Kronburg GP generators through
  `LightPlane.add_to`): an original high-wing design built in code at life size and grown by 1.6 (white, a red
  cheatline laid by each section's own height, the windows the same way, red wing tips, a striped fin, struts, fixed
  gear with fairings, nav lights, the registration D-EKRB, a propeller that spins). It flies an ellipse fitted round the
  level's TrackPath at runtime (`fit_share`, `fit_margin`, `fit_min`/`fit_max`), `altitude` (150m) over the lap's
  highest point, rising and sinking 22m, banked by its speed and the turn's tightness, on the wall clock. Its engine
  (`sounds/kronburg/light_plane_loop.wav`, tools/elevenlabs, levelled by its RMS) takes the full Doppler shift from its
  velocity and the camera's. `res://scratch/light_plane_preview.gd` (`-s`, windowed) renders the model standing;
  `res://scratch/light_plane_shots.gd -- <level> <dir>` (`-s`, windowed) photographs it in a level where the clock has
  it and prints how high it is.

## Rheinufer (Kronburg GP, stage 2)

The Lower Rhine at the edge of Kronburg on a summer evening (sun low in the WSW). Files and code: `RheinuferLevel.tscn`,
`regenerate_rheinufer.gd` (`regenerate_rheinufer.tscn`, headless, about 20s), `rheinufer*` in `generated/`.

- The lap (2.94km, `CORNERS`, `_fillet_path`): south down the east bank's Rheinuferpromenade (the start, Gründerzeit houses,
  plane trees), right between the bridge towers onto the Alte Rheinbrücke (z `OLD_BRIDGE_Z`), right onto the west bank's
  dyke road (`DYKE_X`, the `DeichJump` kicker, the sheep's crossing), left off the dyke west over the A 58 on an
  embankment, round the Anschlussstelle's loop ramp (two 73.5m arcs) onto the A 47 eastbound, over the A 58 at the
  Autobahnkreuz, over the dyke and the Rhine on the Harfenbrücke, and down the curving exit ramp onto the promenade.
  Segment order (the fillet's): promenade, E1, old bridge, W1, dyke, D1, west road, H1, H2, A 47, E0 (`_design_y_fixed`).
- Heights are designed, not graded from the ground: `old_deck(x)` and `harp_deck(x)` (static: the bridge kit is built to
  the same Callables), `_a2_y(x)` the A 47's profile, `_west_y`, Hermite pieces elsewhere (`_hermite`). Where the lap is
  on a structure (`_lap_on_deck`) the ground is not graded under it.
- Ground: `_raw_natural` (the river between ±`RIVER_HALF` at `WATER_Y` 0, the west beach and meadow at `FLOOD_Y`, the dyke,
  the land behind it, the town's quay, lower promenade and terrace on the east bank), pads (`_plan_pads`: farms, the power
  station; the Kirmes' `KIRMES_RECT`). `kronburg_ground.gdshader` with `g_beach` on (G is the Rhine's sand and gravel
  beach, R basalt riprap via `rock_tint`; both uniforms off by default so Kronburger Hütte is unchanged). Bodies:
  RheinMeadow, RheinBeach (sand), RheinRiprap (rock); no collider on the bed under the water.
- Roads: the lap's ribbons by kind (`_road_kinds`: 7 Autobahn for the exit ramp's top, 2 the promenade with pavements, 8
  the old bridge's town asphalt, 0 the dyke and west road, 7 the loop and the A 47; kinds 7 and 8 were added to
  `kronburg_road.gdshader`), one body LapRoad. The dressing roads (`_plan_dressing_roads`, `_dress_road`/`_dress_from`:
  the A 58 both ways, the A 47 westbound and its closed eastbound ends, the Kreuz's four loops `Schleife*` with lead lanes,
  the country road on west, the promenade's continuation) share the grading (`_seg_a/_seg_b`, `_grade`) and are solid as
  `Autobahn<name>Body`. Never name anything "loop" or "ramp" here: Level.gd bakes extra trimeshes under such names.
- The Alte Rheinbrücke's feet stay under the road (`RheinBridgeKit.OB_FOOT_UNDER`): the east end pier stands on the town's
  quay terrace and the west abutment on the dyke, both at the road's height, and their basalt plinths stood 1.1m and 0.7m
  up across the road; a flood arch with under `OB_FLOOD_MIN_RISE` over the ground (the last one, in the dyke) is filled
  with masonry (it had turned upside down and stood up through the road as a band of brick). `_check_old_bridge` builds
  the bridge again on the real ground and errors on anything over the road (`check_clearance`, `OB_BANDS`).
  `res://scratch/lap_overhead_probe.gd` (`-s`, headless, `-- <level> [half=7.5] [low=0.3] [cart=6] [high=14] [skip=...]
  [detail=<name part>] [mm=1]`) lists, for any level, what is drawn over its lap and how low; `res://scratch/mesh_tris_in_box.gd`
  (`-s`, headless, `-- <level> <name part> x0,y0,z0 x1,y1,z1`) which triangles of a merged prop reach into a box.
- Structures: the generator's own girders (`_plan_decks`, `_girder`) for the overpasses over the A 58, the A 47's viaduct
  onto the Harfenbrücke, the exit ramp's viaduct and the A 47 east of the river; RheinBridgeKit's `viaduct_pier`
  (cap BEARING_H under the girder) and `abutment` (its shelf 2.8m under the road; given the road's height its ballast
  wall stood 2.7m over the road and bots crashed into it), none where two decks meet.
- Edge colliders: `_lap_edge_boxes` (old bridge kerbs, the Harfenbrücke's median and railing), `_barrier_runs` (the
  median's Betonschutzwand and the Schutzplanke on the embankments, both from RheinBridgeKit, beams facing the road),
  crowd barriers round the outside of E1 up to the bridge's head (bots ran wide there into the river), the quay's railing
  (`QuayRailBody`, open where the lap crosses the quay onto the bridge: closed, it stopped every bot). Race closures
  (`_build_closures`, `race_closure`) where roads leave the lap, each placed clear of the lap's bends (on the A 47's line
  at the loop ramp and the exit the lap runs on the closed carriageway for tens of metres: `A47_EB_END`, `A47_EB_EAST`).
  The old bridge's gate towers have their own boxes (DressingColliders skips anything named "bridge").
- Kits: `RheinBridgeKit.gd` (the two bridges in game metres, Autobahn furniture and transmission towers at life size),
  `RheinShipKit.gd` (Rhine ships, landing stage, groynes, km boards, buoys, gauge), `NiederrheinKit.gd` (tower windmill and
  its sails, farmsteads, shepherd's cart, bales, tractor, the power station), `RheinStadtKit.gd` (Gründerzeit houses,
  hotel, quay wall, Rheintreppe, promenade furniture, the Kirmes), each with a windowed preview in `scratch/`
  (`rhein_bridge_preview.gd`, `rhein_ship_preview.gd`, `niederrhein_preview.gd`, `rhein_stadt_preview.gd`). The kits keep
  their UV scale in statics (`uvk`), so `_add_prop_scaled` calls `new_kit(scale)` again before building into a batch.
  `_add_prop_game` batches at scale 1 (the bridges); `_kit_mesh_life` builds ride parts at life size under nodes grown by
  PROP_SCALE.
- WoodlandBuilder gained "pollard" (Kopfweide), "poplar" and "plane" (`tree_mesh`, `rhein_leaf_material`, the Rhine
  atlas); `_build_woods` uses them for the ditches, the west road and the promenade.
- Life on it: ships on SeaBoat loops (lanes ±55, turns 4.6km out; horns, diesel, wakes), the excursion ship moored at the
  landing with passengers (`excursion_seats`), `SheepFlock.gd` (36 sheep, shepherd and dog crossing the dyke road every
  110s on the wall clock, bodies on layer 4, knocked aside by carts), the Kirmes (`KirmesWheel.gd`, `KirmesRide.gd`),
  the windmill's sails (`Spinner.gd`), traffic on the A 58 and the A 47 westbound (`AutobahnTraffic.gd`, which now takes a
  height profile, `heights`/`height_step`), steam over the power station's cooling towers.
- The Gegenfahrbahn (`XOVER_W`, `XOVER_E`, `SHOULDER`, `_build_gegenfahrbahn`, `GEGEN_PADS`): after the last gate before
  the Harfenbrücke the median is paved (`MittelXover`, a kind-3 dressing road) and a player may cross onto the A 47
  westbound and take the bridge against its traffic (`AutobahnTraffic.kills`: a vehicle destroys a cart it touches, a
  swept box test, no bodies), with boost pads only on that side; past the bridge's east end a concrete slab
  (`_build_xover_slab`, `XoverSlabDeck`, on one pier) carries it across the median and the closed eastbound onto the exit
  ramp (it filled a hole there; `_xover_edge_open` flattens the girders' upstands and drops their edge boxes along it).
  The westbound's stretch between them is a track body of its own (`Gegenfahrbahn...Track`, a road's `track_x`); the
  rest of the dressing roads stay off-road "Autobahn...Body". Their ribbon meshes are named "...Road_n": DressingColliders
  had given each a second, off-road trimesh. It is `AlternativePaths/Gegenfahrbahn` (wrong-way watch, pads' facing) with
  `ai_chance_scale` 0 (PlayerCart multiplies a route's chance by it): the vehicles fill the lanes to the shoulder and bots
  can't see them, and nearly every bot that took it was blown up. Checkpoint 6 moved off the bridge to the ramp's foot.
  `scratch/shortcut_probe ... chance=1 harmless=1` forces bots onto it with the traffic harmless (18 of 18 rejoined).
- The median's concrete barrier is drawn over the A 58 overpass too (its collider stood there invisible, the median
  reading as open). Under both Rhine bridges the piers, flood-arch piers and vaults (sliced along the intrados, so the
  arches stay open), the Harfenbrücke's girder (a metre or two over the dyke) and its pylon, piers and abutment are
  solid (`RheinBridgeKit.old_bridge_solids`/`harp_bridge_solids`, `RheinPfeilerBody`); the kit's meshes are "..._bridge",
  which DressingColliders skips, and carts drove through them. The westbound's railing and median face on the bridge
  have edge boxes (`_x_edge_boxes`).
- The crossover slab starts 8m before the bridge's end, between the median's kerb and the ramp (the ramp's arc curving
  away from the kerb had left a sliver open over the water). Guardrails are drawn on decks too (on the girders'
  cantilevers, 6cm down), so the exit ramp's outside has one all the way down, and one runs along the slab's open east
  edge: there had been only the girders' 30cm cornice.
- AutobahnTraffic's sound (both Rheinufer carriageways and Kronburger Hütte's viaduct): `voices` (6) players follow the
  vehicles nearest the camera, each kind's engine loop (`engine_sounds`, `kind_engine`; `sounds/rheinufer/traffic_*_loop.wav`,
  tools/elevenlabs, made without a Doppler sweep of their own) levelled by its RMS, pitched by the Doppler shift worked
  out from the vehicle's and the camera's velocities (AudioStreamPlayer3D's own needs the camera's `doppler_tracking`);
  a vehicle honks at a cart in its own lane ahead of it about half the time (`honk_share`, then `honk_gap` 14s), and one
  near the listener now and then (`ambient_honk` 35s). Every vehicle in a lane runs at the lane's speed: each at its own,
  the faster ones drove into the ones ahead. `res://scratch/autobahn_sound_probe.gd` (`-s`, windowed, `--fixed-fps 60`,
  `-- [from=x,z] [speed=40] [seconds=14]`) rides a camera against the traffic and logs the voices' pitch and the honks.
- The town behind the promenade (`_build_stadtviertel`, `STADT_*`): the east bank behind the two rows of houses had been
  one bare meadow out to the fields, the church alone in it and the back row facing a street that wasn't there. Now:
  Friedrichstraße and a grid of streets (`_plan_stadt_streets`, kind-2 dressing roads, the side streets in pieces
  between the cross streets so no two ribbons overlap), perimeter blocks of RheinStadtKit's Gründerzeit houses
  (`_stadt_row`: fronts on the pavement's edge, fewer storeys toward the edge of town), each the detailed house in
  "stadtnah_" batches drawn to `STADT_NEAR` (210m) and its `gruenderzeit_house_far` stand-in in "stadtfern_" batches from
  there (a batch's `visibility_range_begin` via `_batch_flags`) and one box collider per house (`StadtviertelBody`; the
  batches carry `skip_dressing_colliders`, which DressingColliders now honours on single meshes too, or it would have
  built trimeshes of 2M triangles). Trees in the courtyards (`_stadt_trees`, planted by `_build_woods`), the church's
  block a square of limes (its portal's forecourt kept clear), a park between the exit ramp and Friedrichstraße
  (`_stadt_park`), allotments between the first cross street and the A 47 (`_stadt_allotments`), a noise wall on the
  viaduct over them (`_stadt_noise_wall`), whip-arm street lamps. The church's footprint is now noted where it stands
  (it had been noted at its height as z). The view from the exit ramp to the church is kept open (the user missed it once
  the blocks went up): the block south of the church square is a lawn ringed by limes (`STADT_OPEN_BLOCK`,
  `_stadt_lawn`), the square has no row on its south side and its limes stand north of the church, and the park's trees
  keep out of the sightlines (`_in_church_view`). 125 houses; 0.1ms of GPU along the lap (M1, `ab_bench ... hide=Stadtnah`).
- Autobahn traffic uses CampKit's `motorhome_road` (awning rolled in, entry step stowed; Kronburger Hütte's viaduct too):
  the camp's motorhome drove with its awning out and door step down. `res://scratch/camp_vehicle_preview.gd` (`-s`,
  windowed, `-- <dir> [kinds=motorhome:0,motorhome_road:0] name:x,y,z:tx,ty,tz`) renders CampKit's vehicles side by side.
- AI races (`scratch/ai_race_test`, speed=2): every bot finishes three laps, the only respawns item blasts; flying laps
  about 67s. Cost (M1, 1280x720, `scratch/bench.tscn`): 8.1ms GPU on average, the worst 10.3ms.
- Menu tile `images/menu/tile_rheinufer.jpg` (the old bridge from the river, `scratch/look_shots.tscn` at 1376x768).

## Zeche Kronprinz (Kronburg GP, stage 3)

An off-road stage on a misty summer morning through the fictional colliery Zeche Kronprinz (founded 1871, closed 1986,
now industrial heritage), the still-working Kokerei Kronprinz next door and the colliery's spoil heap. Files and code:
`ZecheLevel.tscn`, `regenerate_zeche.gd` (`regenerate_zeche.tscn`, headless, about 17s), `zeche_`/`zecheprop_`/`zechefar_`
in `generated/` (each run deletes them first).

- The lap (3.0km, `CORNERS`, `_fillet_path`): east from the colliery yard (`YARD_RECT`, graded flat at `YARD_Y`; the
  start, Schacht I's Malakoff tower, Schacht II's steel headframe and its winding houses, the Lohnhalle), under the coal
  washer (`WASHER_X`: the lap drives through its passage), along the coke oven battery's coke side past the quench tower
  (`BATTERY_X0`, `KOKS_Z`), left up the Halde's haul ramp (`RAMP_Z0` to `HALDE_Z0`, then the plateau at `HALDE_Y` 36m past
  the Kronprinzenblick landmark, `SUMMIT_AT`), off its north end over the `HaldenSprung` kicker (a WoodenRamp whose lip is
  the TrackPath's `jump_lips`) and down the flank (`DROP_Z1`, 26.6% at the steepest), west through the birch scrub over the
  colliery railway, south through the settling ponds' ford, over the railway again and back onto the yard.
- No road mesh: the lap is the ground graded flat across `ROAD_HALF` (`_grade`), its height designed (`_plan_road_heights`:
  the base ground smoothed, the ramp, plateau and a Hermite descent on segment 0, the ford's dip). Bodies: KohlenTrack
  (dirt) and ZechenplatzTrack (the yard, gravel) are track; HaldenGrund, ZechenGrund (gravel) and ZechenWiese (grass) are
  off-road. `zeche_ground.gdshader` paints from the vertex masks (R spoil, G the works' slag and slabs, B the track, A the
  woods' floor) and UV2.x (the distance to the lap: ruts, gravel at the edges, puddles). Flowers and shale fragments are
  round flecks (`fleck`) that shrink away with the pixel's size: cells of a hash drew coloured squares. The works' ground
  is painted only over `WORKS_PAINT` (the washer, the battery and its by-product plant), its edge wandering on noise;
  `WORKS_RECT` is only graded: painted, it was a 550 x 260m black rectangle from the air.
- The settling ponds (`PONDS`, `_build_ponds`): both at one level (`_pond_level`), one `KlaerteichWater` node with
  `water_bounds_min`/`max` metas; the lap fords the east one `POND_DEPTH` (0.45m) under its surface, slowed but never
  drowning. The water mesh's triangles go [centre, a0, a1] (clockwise from above): the other way round the ponds were
  culled and showed no water at all.
- The colliery railway (`RAIL`, a bent polyline: `_plan_rail`, `_build_railway`): FreightKit's track, Freight Line's
  Train.gd (`ZechenbahnTrain`, a yard switcher and seven hoppers out and back every 209s at `RAIL_SPEED` 19 with short
  `RAIL_STANDS`, `legs`: at 13 m/s with long stands it came once in about six minutes and the user never met it in a
  race), RailCrossing.gd at both
  crossings (lap 1317m and 2047m, 89 and 87 degrees), RailRumble, the loading bunker over it (`BUNKER_S`). Laid straight it
  crossed the lap at 21 degrees, and a bot waiting at the closed crossing stood on the rails and was hit. The ground
  dips about 24cm under the rails at a crossing; each deck has a box collider at its mats' height
  (`BahnuebergangDeck<n>`, track), or carts sank into the mats. A boosting bot
  can't brake for a crossing: bots don't fire a boost with one within `PlayerCart.AI_BOOST_CROSSING_CLEAR` (180m) ahead
  (`_ai_rail_crossing_ahead`), and no pad leads into one.
- Kits (life size, grown by PROP_SCALE 1.6, batched through `_add_prop`): `ZechenKit.gd` (the Malakoff tower, the Doppelbock
  headframe and its sheaves, winding houses, the Lohnhalle, the coal washer with its passage, conveyor galleries, the
  bunker, mine carts, the summit landmark and its wheel, fences, floodlight masts, boards, buddleia and goldenrod; header
  lists its material keys) and `KokereiKit.gd` (the battery in its own frame, see its header; the pusher machine, guide
  car, quench car and loco, larry car, coal tower, quench tower, rails, by-product plant, flare), with stage 1's
  SteelworksKit and KronburgTownKit. Previews and checks: `scratch/zechen_preview.gd`, `scratch/zechen_check.gd` (the
  washer's and the bunker's clearances), `scratch/kokerei_preview.gd`, `scratch/kokerei_clearance_check.gd`,
  `scratch/kokerei_mesh_dump.gd` (for zfight_scan).
- Life on it: the quench tower's steam burst every 95s on the wall clock (`PeriodicBurst.gd`, with its hiss), smoke from
  leaking oven doors, the open oven's glow, standpipe fires, the flare, steam over the by-product plant; the sheaves and the
  summit wheel turn (`Spinner.gd`); walkers on the Halde, spectators at the start. Sounds (`sounds/zeche/`, tools/elevenlabs):
  the Kokerei's hum, the conveyor, crows over the scrub, the quench burst. Music `MusicManager.STAGE_TRACKS["zeche"]`
  (`Kohle_und_Dampf` and two of stage 1's).
- The woods (`_build_woods`: birch, willow, oak, poplar, about 5,000 in 260m cells, the near meshes to 120m past a cell)
  and the scrub plants (buddleia, goldenrod: DressingColliders' `BRUSH`, driven through). With 7,700 trees and a 170m
  near range the stage cost 14.4ms.
- AI races (`scratch/ai_race_test`, speed=2): every bot finishes three laps, no train hits, the respawns item blasts (and
  now and then a fall near the second crossing, 2044m); flying laps about 80s. Cost (M1, 1280x720, `scratch/bench.tscn`):
  12.2ms GPU on average, the worst 15.4ms. `res://scratch/zeche_ground_heights.gd` (`-s`, headless, `-- [level=] x,z ...`)
  prints the ground under points (to aim look_shots' cameras).
- Menu tile `images/menu/tile_zeche.jpg` (the yard with the Malakoff tower, the headframe and the washer, look_shots).

## Quer durch Kronburg (Kronburg GP, stage 4, the finale)

A point-to-point rally sprint (one run, no laps) of about 6km straight across Kronburg on a late-summer morning. Files and
code keep "stadtrallye" (`StadtrallyeLevel.tscn`, `regenerate_stadtrallye.gd`, `stadtrallye*` in `generated/`, which
each run deletes first).

- `regenerate_stadtrallye.gd` (`regenerate_stadtrallye.tscn`, headless, about 65s, a 2GB peak; its header explains the
  route, the profile, the grading, the kits and the hazards): the Kaiserstraße start before the Hauptbahnhof, the moat
  bridge, the pedestrian zone past Kaufhaus Krone, under the railway, across the Ring between its traffic and trams, the
  Botanischer Garten (the parterre, through the Palmenhaus, the rose pergola, the lily pond's bridge, the Alpinum's
  hairpins, the belvedere, the leap off the terrace), down the Hafenstraße into the docks (the demolition site's wrecking
  ball, the scrapyard's magnet crane, the building site's excavator, dirt kicker, car park and road roller) to the finish
  at the old gasworks.
- Kits (life size, grown by PROP_SCALE 1.6, batched by `_add_prop`): the generator calls builders by name through
  `_kit_call`, which warns once and skips one that is missing, also through wrappers (`_garden_prop`, the Ring's vehicle
  list, the site's material list, the scrapyard's bins), so grep for both when checking a kit is complete.
  `StadtKit.gd` (the Hauptbahnhof, the railway's bridges and walled embankment, Kaufhaus Krone, the fountain, café
  terraces, the U-Bahn entrance, trams and the Ring's cars, buses and trucks, the tram stop, catenary masts, traffic
  lights, the temporary grandstand), `GardenKit.gd` (the Palmenhaus, plants, gates and fences, beds, the stone bridges,
  the belvedere, terrace walls, steps, balustrades, hedges, the Alpinum's stones and cushions, the parterre fountain),
  `ScrapKit.gd` (the crawler crane and its wrecking ball, the ruined office block, rubble and scrap heaps, bale walls, the
  magnet handler, the baler, the yard's office, weighbridge, fence, skips and bins), `BaustelleKit.gd` (the tower crane,
  the excavator, the road roller, the site's gear). Windowed previews: `scratch/stadt_preview.gd`, `garden_preview.gd`,
  `scrap_preview.gd`, `baustelle_preview.gd`; `scratch/scrap_contract_check.gd` (headless) builds ScrapKit's props as
  their call sites do. The stone bridges are driven over: their decks lie 5cm (life) under the road's ribbon, on
  `GardenKit.bridge_deck_y`, the generator's own crest profile. Its wing walls (a footing slab under a sloped wall)
  had the same thickness, so their faces shared a plane wherever the wall's foot dipped under the footing's top, with
  the courses running opposite ways on one face: the pond bridge flickered beside its entry. The footing now stands
  1.5cm proud and runs 2.5cm past the wall's end (as does the coping), the end newels stop 1.5cm short of the bridge's
  end wall and the string course 4cm inside them. `scratch/zfight_scan.gd -- res://generated/stadtrallyeprop_pond_bridge.res`
  lists what is left (the balustrade's ends and plinth inside its pedestals, hidden).
- The hazards run on the wall clock (CrossTraffic.gd, WreckingBall.gd, CarDropCrane.gd, SlewHazard.gd, ShuttleProp.gd).
  The bots take their chances and some get blown up: the user found waiting at gates held them up too long, so the
  generator no longer adds the gates (`HAZARD_GATES` false; they are still set up, and the gate, margin and probe notes
  below hold if they come back). With it on, each one the route meets has a HazardGate.gd (group "rail_crossings", so
  bots wait at it as at a level crossing), which opens only for an arrival with the road clear from `lead` + a margin before to `trail` + the margin after (the margin
  PlayerCart's 1.6s, or the gate's `own_margin`). `res://scratch/hazard_gate_probe.gd` (`-s`, headless, `-- [level=]`)
  prints each gate's cycle, when its hazard covers the road and the share of arrivals it lets through: 0% holds the bots
  for good.
  - The wrecking ball swings free and fast (`BALL_GRAVITY` 28: 7.2s a swing, 13 m/s over the road) and destroys a cart it
    meets (`kills`). Its gaps are short, so its gate has tight margins (`lead` 0.3, `trail` 0.6, `own_margin` 0.5) and counts
    only the ball over the bot's lane (`road_half` 3.5). Free at gravity 14 with the whole road counted it never opened; a
    4.5s hold at the far end was the first fix, and the user wanted it faster without the pause.
  - The magnet crane (`CarDropCrane.gd`, `ScrapKit.material_handler` with its stick raised, `HANDLER_TIP`; the magnet
    built without its wreck, `scrap_magnet(..., false)`, and the wreck alone, `magnet_car`) carries the car 5.7m over the
    lane, drops it on the road (destroying a cart under it), leaves it lying there as a solid obstacle (an AnimatableBody3D
    box on layer 1 only then) and pulls it back up. Swinging low across the lane, the car had passed through the
    checkpoint's truss; that checkpoint now stands before the handler.
  - SlewHazard, CarDropCrane and ShuttleProp move themselves in `_ready`, which also runs in the generator: the level was
    saved with them already turned or moved to wherever the clock had them, and the game measured their swing from that
    (the crane dropped its car beside the road, the excavator's gate saw nothing). Each keeps its first heading or place in
    a meta (`base_basis`, `home`) and reads it back.
  - A bot well past a crossing's stop line (`AI_CROSSING_COMMITTED`, 4m) drives on whatever the gate says: one let through
    just before the Ring's traffic came stopped where it was, in the outer lane, and was run down.
  - DressingColliders skips the traffic's MultiMeshes (CrossTraffic's and AutobahnTraffic's, meta
    `skip_dressing_colliders`): it had frozen a collider where each vehicle stood at load, and its wobble then drew the
    car standing there while the stream drove through it (an invisible car in the Ring that appeared when hit).
- PlayerCart's 2.8s stuck check starts its window again while a bot is held at a crossing or gate (`_ai_crossing_hold`):
  checked only at the window's end, a bot let go just before it had barely moved off the line and was respawned 200m back.
- The water for the carts is `StadtWater.gd`, the level's "RiverWater" node (`surface_at`, as Northlight Caverns'): the
  moat and the canal (deep enough to drown in) and the lily pond (about 1m, waded), each at its own level. PlayerCart had
  taken only the first "...Water" node, the moat, so a cart drove over the pond's and the canal's dry beds.
- The scrapyard is open: the bale walls are short runs with gaps, and wrecked cars (`ScrapKit.wreck`, some two high;
  `_build_scrap_wrecks`) stand staggered along the lane's edges (3.9-5.2m out, a little askew: nearer the middle and turned
  across it, the bots crawled into them until respawned) and scattered over the yard, each a box the bots' rays see. The
  crane's dropped car lies 2.2s, under PlayerCart's 2.8s stuck check.
- The building site's haul road (`stadt_road.gdshader` kind 11) has no steel road plates any more: one lay under the
  wrecking ball and read as its hit zone.
- The water: the moat (deep enough to drown in: `water_bounds_min`/`max`), the lily pond and the canal, wound clockwise
  from above (`_water_strips`, the pond's fan): wound the other way all three were culled and showed no water. The
  bridges' spans are `_deck_zones`, left to the natural ground by `_grade`: the last graded sample's flat band and
  shoulders had wrapped round into the spans and dammed the moat and the pond, burying the side arches.
- The route's road collision (`CityRoad`, `GartenwegTrack`, `BaustrasseTrack`, `SchrottplatzTrack`) is built from each
  section's triangles: they had been appended to a copy of the dictionary's PackedVector3Array (a packed array read out of
  a Dictionary is a copy), so the route had no road collision, only the graded ground under it, and at the terrace the
  carts fell through the drawn road.
- The building site's parcours (corners 20-24, the user's idea): from the yard road south, a U to the right past the
  excavator (`EXCAVATOR_AT`, its arm over the first leg's south half), north up a straight over the dirt kicker
  (`KICKER_AT`), a U to the left along the north fence over a dirt table-top (`TABLE_AT`, `TABLE`) and through its
  checkpoint (`PARCOURS_GATE`), then west through the car park. Tyre walls round each corner's outside
  (`_build_parcours`, `PARCOURS_TYRES`: TyreStacks over box colliders, ScrapKit's "tyre"), the Leitbaken along both edges.
  The gate may be missed once like any other (the user's rule): the field isn't fenced off. The jumps are the route's
  profile (the ribbon is their top) with the ground left at the road's level under them (`_jump_spans`) and spoil-heap
  sides of their own (`_build_spoil_jumps`, `SpoilHeapsBody`, off-road dirt): graded up under the run-up, the kicker had
  stood as a sheet of road over a low bank, with no sides. No boost into the kicker: boosted off its lip a cart lands
  in the hairpin after it.
- The terrace's drop is a flight of stairs (`TERRACE_FACE` 9m, `TERRACE_STEPS` 15, `_build_terrace_stairs`, parapets
  either side, solid), after the kicker: the road's collision runs straight down the nosings and its ribbon isn't drawn
  there. Below it the road runs sunk between grass banks to the garden's exit; boost pads stand on the banks
  (`BANK_BOOSTS`, settled onto the slope), and the checkpoint stands at the stairs' foot, out of their line. More stand on
  the Hafenstraße's banks below the second railway underpass (`HAFEN_BANK_BOOSTS`); each pad reserves its spot and the
  bank ahead of it (`_note_rect`) so the dressing keeps off. The garden's furniture stops 30m before the terrace.
- The terrace: the pads "terrace" (10cm under the walls' coping) and "terrace_below" (the steps' foot) meet at
  `_terrace_cut`, inside the retaining walls' thickness, on terrain grid lines of their own (`_with_line`; the grid is
  5m, too coarse to hold the step); beside the drop each side is graded only from the road on its own level
  (`_grade`'s `terrace_side`), or the lawn banked up half the walls' height. The route runs due south there (the cut
  assumes it, and errors if not).
- `_build_city_blocks` once never advanced `bx`: the runaway filled the system disk with swap (everything stopped,
  "disk full") and then rebooted the Mac. Run this generator, as any, under a watchdog on the process's footprint
  (`top -stats mem`), swap and the system disk's free space: RSS stays low once macOS swaps the process out.
- The S-Bahn over the city (`SBAHN_CONSIST`) is TrainKit's German Regional-Express (`re_loco`, `re_dosto`, `~re_cab`: a
  fictional operator's push-pull set in red, a diesel locomotive, double-deck coaches with their low floor between the
  bogies, a cab car on the upper deck, side buffers); it had been the Sierra's American cab units and coaches.
  `scratch/train_preview.gd ... consist=re_loco,re_dosto,re_dosto,~re_cab` renders it.
- The railway's earth embankment keeps its crown (`EMBANK_CROWN` 8.5m a side: the ballast reaches about 6.8m) and the
  top of its flanks wherever no road is near (`_embank_floor`, applied after the grading, right up to a wall's end and
  6m in behind it), and the brick-walled run past the Ring bridge goes on to x 300 (`WALLED`): the garden's parterre lies
  so close below the line that the grading had cut the bank into a 12m rock-painted cliff, and the track hung over it.
  StadtKit's railway bridge: the sandstone shelf band, the side copings and the wing walls' copings run 4cm past the
  brick faces they end on (flush, they flickered), and the wing walls start 5cm inside the abutment.
- Sound levels: AudioStreamPlayer3D caps a voice at `max_db` (+3dB, +6 at most), so a quiet clip levelled by its RMS
  came out up to 16dB too soft. Quiet clips are raised in place instead: `scratch/normalize_wav.py [--rms=-16] [--peak=-1]
  file.wav ...` (16-bit PCM; prints the levels before and after; it drops any loop chunk, so set `loop_mode=2` in the
  .import). Done for the city engines, the tram's rumble, two car horns, Rheinufer's motorhome and the light plane. The
  stage's own loops (excavator, site, scrapyard, roller, reverse beeper, the Ring's traffic bed, the tram) had imported
  with `loop_mode` 0 and played once: now forward.
- The Ring's cars, vans, trucks and bus have engines (CrossTraffic's `engine_sounds`, `kind_engine`: city-driving loops
  `sounds/stadtrallye/city_*_loop.wav`, tools/elevenlabs, levelled by their RMS) on the six nearest the camera, their
  Doppler shift scaled down (`doppler_share` 0.5: a few percent at town speeds, not the motorway's swoop); the trams
  keep their own rumble. `scratch/autobahn_sound_probe.gd -- level=res://levels/StadtrallyeLevel.tscn
  node=Ring/RingTraffic from=82,-200 speed=0 y=36` logs the voices beside the Ring.
- AI races (`scratch/ai_race_test`, speed=1 only: the hazards run on the wall clock; `noitems=1`): every bot finishes,
  in 190-265s. Music `MusicManager.STAGE_TRACKS["stadtrallye"]`; its sounds are in `sounds/stadtrallye/` (tools/elevenlabs).
  Not re-run since the city blocks and the brewery came in (the run was stopped).
- The city behind the route (`_build_city_blocks`, `_block_row`): rows of RheinStadtKit's Gründerzeit houses round
  courtyards on two grids, the old city west of the Ring (`BLOCK_X`/`BLOCK_Z`) and the Hafenviertel east of it
  (`EAST_BLOCK_X`/`EAST_BLOCK_Z`, an empty field before). They were boxes with `city_building.gdshader` facades whose
  windows the eaves cut off (the user found them too plain). A row runs from one house deep in from its corner to the
  next (the row before fills the corner), its widths scaled to fit; a house keeps `BLOCK_ROUTE_CLEAR` off the route's
  line, and those within `BLOCK_DETAIL` (230m, `_route_far_dist`) get the detailed house near the camera, the rest only
  the far one. 690 houses, 256 detailed. Every block corner shows a firewall: RheinStadtKit's `BRICK` was lightened (at
  0.34, 0.20, 0.16 it read black in shade). Cost: the props' triangles visible along the route went from 1.14M mean /
  1.80M worst to 1.53M / 2.23M (`res://scratch/visible_tris_probe.gd`, `-s`, headless, `-- <level> [step=200]
  [under=Stadt]`, prints MEAN and WORST); lower `BLOCK_DETAIL` if that is too much.
- Die Kronburger Brauerei (`BreweryKit.gd`, `_build_brewery`, `BREWERY_AT`), home of Kronburger Pilsner (the user's
  idea, all fictional), on the field west of the Hafenstraße just south of the second railway underpass, facing the
  road, on a pad of its own ("brauerei", 30cm under the road) and built before the blocks, which keep clear of it. Red
  brick and sandstone among the flats, not a works: the Brauhaus (the tavern's round-arched windows, a balcony over the
  portal, a volute gable with the name, a clock, Kronburg's arms and a gilded crown, a hipped slate roof with dormers),
  the taller Sudhaus with the giant bottle (13.5m life, label lettered a Label3D per letter round its front, `_wrap_text`)
  on a corbelled console in a blue niche, its tower with clocks and a copper cupola, a painted advert on its north wall
  (seen coming down from the railway), the gate wing (BRAUEREIHOF) under a stepped gable, the Lagerhaus across the yard;
  in front the beer garden (gravel, two chestnuts, beer tables, parasols, strings of lights, a brick fence with railings,
  the BIERGARTEN gate, barrels and crates) with CrowdPlacer patrons on the benches (`garden_people`). Two batches
  ("brauerei" to 2400m, "brauerei_garten" to 900m), about 31k + 27k triangles; box colliders (`brewery_solids`,
  `garden_solids`). `scratch/stadt_preview.gd ... set=brauerei` renders it in memory in seconds.

## Shop names in the Kronburg GP (ShopNames.gd)

- Every café, shop, restaurant, workshop, kiosk and fair stall on the four Kronburg stages is named through
  `ShopNames.unique(kind, wanted)` (RheinStadtKit, KronburgTownKit, StadtKit): the hand-picked name if it is free, else
  one made from the kind's patterns (surnames, places, café and brewhouse words, Italian words, inn signs). The same
  "Café Rheinblick" had turned up several times down one street (the user noticed). A name's word (Rheinblick, Venezia)
  is used once, surnames are spread, each kind starts its draw somewhere of its own.
- The names are unique across the GP: each generator calls `reset(salt, stage)` first, which takes the other stages'
  names (and their words) from `generated/kronburg_shop_names.json`, and `save()` before saving its level, which writes
  its own. Regenerating a stage can shift its names (it keeps off the others' current ones). Generated in the order
  Rheinufer, Kronburger Hütte, Zeche, Quer durch Kronburg, Café Rheinblick is Rheinufer's.
- `res://scratch/shop_names_check.gd` (`-s`, headless) draws a stage's worth of names and prints any drawn twice.

## Test Track (a proving ground, no cup)

- `regenerate_test_track.gd` (`regenerate_test_track.tscn`, headless, about 12s) builds `levels/TestTrackLevel.tscn` on
  MiyoshinoStage.gd: a 1.6km clockwise lap for trying the cars. A 580m start straight (distance boards 300/200/100 before
  the first corner, two boost pads out of the last corner), a fast right-hander, the south leg, a 16m hairpin (cones on
  its apex), a table-top (`_ramp`: WoodenRamp with a table and a tail), a chicane between cones, the surface strip, and
  the hill on the west leg (`HILL_*`, max grade 14%) with a kicker before its crest and a boost pad before that.
  Guardrails round the outside of the four corners (`_rails`, MiyoshinoPropKit.guardrail and box colliders), the start
  venue's barriers and spectators, a paddock (CampKit gazebos, tables and vehicles) north of the straight, cedars and
  maples from 70m off the road out.
- The surface strip (`STRIP`, `_build_strip`): nine 24m patches with 6m of asphalt between, on the leg west of the
  chicane: sand, snow, ice, mud, grass, gravel, dirt, wood, cobbles (rock to the tyres). Each is a ribbon over the road
  `STRIP_LIFT` up, drawn by `test_surface.gdshader` (`kind`; UV in metres along and across), in its own body
  "TestStrip<Surface>Road" (track to PlayerCart) with its `surface` meta; the word painted on the road at its start
  and a board beside it. A bright ice mirrored the sky and read as white as the snow: it is a darker blue-grey.
- In NetworkManager's ALL_STAGES with `"test": true`: under "Other Courses" in the course lists (Time Trial, Spectator,
  Inspect, VS), never the random pick or the next stage. Its menu tile is `tile_test_track.jpg` (render_menu_tiles.sh
  knows it as TestTrack).
- AI races (`scratch/ai_race_test`, speed=2): every bot finishes, no falls (the respawns are bombs and missiles), flying
  laps 36-44s.

## Miyoshino GP (Senbon Sakura Pass, Yoshino Rapids, Monzenmachi, Yamabushi Trail)

Japan: Yoshino's cherry-blossom mountains in spring (the cup's name is Yoshino's old poetic one). Four stages built in one
night from the user's phone brainstorm; they asked for it without questions, so the design choices below are mine.
Files: `SenbonSakuraLevel.tscn` (`regenerate_senbon_sakura.gd`, stem "senbon"), `YoshinoRapidsLevel.tscn`
(`regenerate_yoshino_rapids.gd`, "yoshinogawa"), `MonzenmachiLevel.tscn` (`regenerate_monzenmachi.gd`, "monzen"),
`YamabushiLevel.tscn` (`regenerate_yamabushi.gd`, "yamabushi": not "...Trail...", "trail" in a level's name is one of
DressingColliders' MESH_SKIP words and nothing on the stage would be solid). Each `regenerate_<x>.tscn` runs headless in
11-21s and first deletes its stem's files in `generated/`.

- `MiyoshinoStage.gd` is the generator all four extend (read its header): a `Route` class (straights and arcs through
  filleted corners, heights per metre), `_plan_heights` (the natural ground along the route, bridges straight from bank
  to bank, smoothed, clamped to `max_grade`), one heightfield of `_natural` graded to every route (`_grade`: the flat band
  may differ left and right, with its own cut and fill slopes: a plank walk has no ground under its valley side), the
  roads as ribbons with one collision body per surface (LapRoadAsphalt, LapRoadDirt, LapRoadWood, LapRoadGravel;
  `K_FOOTPATH` is drawn as paving but its body, FootpathStones, is off-road rock; `K_STEPS` has collision and no ribbon),
  gates, grid, pads, kickers (`_jump_lips`), sky (`_environment()` overrides), woods (`_tree_pick`, `extra_trees`), prop
  batches (`_put`, `_put_world` with `_life()` for builders that take points, `LBL` for the labels array), automatic
  guardrails where the ground falls away, shortcuts as AlternativePaths (`shortcuts`), point-to-point stages.
  `-- maponly=1 map=<png> [profile=1]` saves a plan of the stage (hillshade, roads, a dot every 100m) in seconds.
  Under the lap's road and `LAP_GROUND_OWN` (0.5m) past its edge the lap's height wins the grading (`_grade`): a shortcut
  joining at a grade had pushed the ground up through the lap's road; across the lap's whole flat band, its verge held the
  ground up through a shortcut's near edge meeting it at a slant. The automatic guardrails leave the mouths of shortcuts
  open (`_route_mouths`), and a shortcut that can't reach the lap's height at either end within its grade is warned
  about (a step in the road).
- Where a shortcut meets the lap (the user saw the torii path's end hovering and lying over the road's edge):
  - Its ribbon's ends follow the road's edge: a section's fifth field (1 its start, 2 its end, 3 both) trims each of its
    five columns to `_off_lap_column` (where that column leaves the lap's road for good, `OFF_LAP_MARGIN` 0.2m off its
    edge; a route may start beside the road and cross it at a slant, as the raft crossing does). Cut square it lay over
    the edge, or held back until both edges were clear it left a wedge of grass.
  - Its heights: pinned to the lap's at each sample's nearest point while the centre is within `lap.half + 2.5`
    (`_plan_heights`), and leaning across with the lap's grade there (`Route.tilt`, `surf`; the torii path 8-9%: held
    level, one edge stood 35cm over the road and the other sank under the ground graded to it), easing out over
    `TILT_FADE`; the grading leans with it (`_seg_tilt`). Past the pins a cubic eases into the climb over `END_EASE`
    (16m): pinned, the path turned 25% within a metre and the ground cut across the sag. Shortcuts are graded from 1.5m
    samples and the grid is halved (2m) within `END_REFINE` of their ends (`_refine_axis`).
  - What the 2m grid still cuts across (a few cm), the paving is lifted over: never less than `RIBBON_OVER_GROUND` (4cm)
    over the built ground (`_build_roads` prints how much). `_check_shortcuts_ground` prints where the ground comes within
    3cm of a shortcut's surface and warns past 12cm.
  Under a deck the ground is cut, never filled: at least `DECK_CLEAR` (0.6m) under it across its width and 1.5m more,
  banking up beyond like a cutting (a cut-only segment, `_cut_under`; a bridge entry's fifth field true leaves it alone:
  the rafts). A road segment holds the ground flat only beside it, not past its ends: past the last one before a deck
  it had held the ground at its own height into the span, and on the ravine's slanting crossing on Senbon Sakura Pass
  the hillside stood up to 77cm through the planks (the user saw grass on the bridge). `_check_decks` warns about any
  deck the ground comes within 5cm of; every run prints each deck clear or not.
- Shaders: `miyoshino_ground.gdshader` (masks R rock, G bare ground, B cherry groves' fallen petals, A cedar forest
  floor; UV2.y wet; past `canopy_from` the grove and forest masks become the canopies' colours), `miyoshino_road.gdshader`
  (kinds 0 asphalt with white edge lines, an orange centre line and a gutter, 1 ishidatami paving, 2 the dirt trail, 3
  planks, 4 gravel, 5 raked precinct gravel; COLOR.g fallen petals). `hut_masonry.gdshader` gained `tile_buff` (default
  0.55, unchanged elsewhere): 0 for "kawara", which had come out orange and blue.
- Kits (life size, PROP_SCALE 1.6; all extend `MiyoshinoKit.gd`, the shared palette and keys: "kawara", "hiwada",
  "shikkui", "ishi", "urushi", "washi" (glows when `MiyoshinoKit.night` is set before the first `new_kit`), "neon"...):
  `MiyoshinoTownKit.gd` (machiya in six variants, great_gate, main_hall, pagoda, temple_wall, wall_gate, chaya, yatai,
  bell_tower, shrine_hall, kominka, mountain_hut), `MiyoshinoPropKit.gd` (torii in three styles, lanterns, chochin
  strings, bonbori, utility poles and wires, guardrail, curve mirror, signs, nobori, jizo, komainu, fences, hanami sets,
  vending machine, kei truck, summit shrine...), `MiyoshinoRiverKit.gd` (log rafts, sawmill and wheel, boats; in game
  metres: road_bridge, suspension_bridge, ledge_walk, timber_chute, with `check_corridor`). Previews:
  `scratch/miyoshino_town_preview.gd`, `miyoshino_prop_preview.gd`, `miyoshino_river_preview.gd` (`-s`, windowed).
  The kits and the stages write their signs in romaji; `MiyoshinoStage._jp` (the `JP` table) turns the ones it knows into
  Japanese, drawn in Yuji Syuku (`fonts/YujiSyuku-Regular.ttf`, SIL Open Font License, `fonts/YujiSyuku-OFL.txt`), both
  for texts passed to a builder through `_put` (a way-stone stacks its characters) and for the labels a kit emits. A new
  sign text needs an entry there or it stays romaji. `scratch/label_positions.gd` (`-s`, headless, `-- <level>`) lists a
  level's Label3Ds and where they are. The emblem is a drawn five-petal crest.
- Trees: `MiyoshinoTrees.gd` (extends WoodlandBuilder; its own atlas): sakura, yamazakura, shidare, sugi, momiji, take,
  matsu, tsutsuji; `scratch/miyoshino_trees_preview.gd`. The sugi's far stand-in (the user found it a plain cone) is three
  cards crossing on the stem with the crown painted as the near tree grows (`_sugi_far`: ragged tiers, short lowest
  boughs, sky between the tiers), its stem stopping just inside the crown. It added BARKS entries, and uniforms to `acacia_leaves`
  (`backlight_albedo`, `seed_tint_a/b`, `glow`) and `tree_bark` (`node_spacing`, `node_color`) whose defaults leave the
  other stages as they were (`scratch/miyoshino_trees_regress.gd` hashes the old kinds).
- Koinobori (the carp streamers of Children's Day): `MiyoshinoPropKit.koinobori_pole` (a pole with a gilt ball and an
  arrow wheel, the five-coloured streamer, the black and red carp and two or three children, halyard and guy ropes) and
  `koinobori_line` (carp on a rope between two masts, as hung across rivers), `koinobori_carp` the open cloth tube.
  `koinobori.gdshader` (key "koi", MiyoshinoKit) ripples each carp across the wind and dips it, more toward the tail,
  and paints scales, eyes, head band, belly and tail and cuts the tail's fork; its data is in the vertices (UV along and
  round, COLOR the colour and design, CUSTOM0 the sway axis, phase and length: the "koi" SurfaceTool is made with a
  custom format). On Senbon Sakura Pass on 14m poles at the park's front edge (lower, behind the cherry avenue, they
  didn't show from the road) and in the farmhouses' yards; on Yoshino Rapids three lines across the river (below the
  timber bridge, mid-river, above the ford) and poles on the village's river side; two poles in Monzenmachi's gardens.
  `scratch/miyoshino_prop_preview.gd ... set=koi`.
- Nobody stands inside a prop: `_put` notes the footprint of every solid prop it places (`SOLID_FOOT`, `_note_solid`:
  benches, lanterns, stalls, halls...) and `_clear_people_from_props` drops any spectator whose feet fall in one before
  CrowdPlacer builds them (prints how many; the user found one stuck in a bench).
- The RC Vibe GP flag is each stage's own (`_logo_flag(root, s, lat)`: a `LogoFlag` by the start, streaming away from
  the road): left to Level.gd it stood under Senbon Sakura Pass's power lines. On Senbon on the park side by the koinobori.
- `PetalGusts.gd`: petals falling round the camera and, at `spots`, gusts on the wall clock that blow petals across the
  road and push the carts this peer drives (`mist`: wisps of cloud instead, the Yamabushi Trail's upper mountain).
- Senbon Sakura Pass (3.4km, a spring morning): the hanami park's start straight, then (the user's idea) right over a
  timber bridge with vermilion railings onto the temple island, round the hall on the temple's stone paving (K_STONE;
  the hall faces the park across the water, two halls as its wings, a pagoda at the island's west end, a bell tower at
  its east end) and back over the second bridge; three legs and two hairpins up the cherry slope, the ridge (teahouse, a
  kicker), the shrine's turn-back, the cedar descent over the ravine's arch bridge. The lake is a smooth union of
  ellipses with points of land cut out and a wandering shore (`LAKE_BLOBS`, `LAKE_POINTS`, `_lake_d`, `_island_d`,
  `_water_d`: negative in the water), which carves the ground and builds the water (a grid of 5m cells near it). The
  island has two gates one after the other: driving round the lake instead misses both, which disqualifies.
  - The turn onto the first bridge comes after a 330m straight (the start line is at x -300 and the boost pad 30m past
    it: nearer the turn, bots still at 40-50 m/s on lap 1 ran wide onto the grass before the railing began, drove down
    the verge behind it and dropped into the lake at the bank). Vermilion railings run round the whole outside of the
    turns onto and off the bridges and a little way along the causeways' insides (`_build_approach_rails`); their
    colliders and the island bridges' are 2.6m high. `scratch/ai_race_test ... history=400` prints the last frames
    before a respawn (how a bot got where it fell).
  - The torii path cuts the upper hairpin (55m against 96m, footpath: off-road). Its exit had been closed by a guardrail
    and a 1.2m step (it couldn't climb the 9m between the legs within 20%; now 30%). Bots lap in about 85s; in four
    races after these fixes none fell on the island (only item blasts).
- Yoshino Rapids (2.6km, midday): the river is functions of x (`_river_z`, `_river_half`, `_water_y` falling at RAPIDS,
  `_depth`), which carve the ground and build the water (RiverWater.gd with one strip, `river_water.gdshader`). The south
  bank's village, the timber bridge, the lumber yard and sawmill (its wheel a Spinner), the forest road, the timber slide
  (planks between log walls) and its kicker, the ford (0.36m deep). The raft train (`RaftCrossing`, RiverRafts.gd: the
  rafts bob, their deck is still boxes) is 315m against the lap's 533m. Laps about 63s, no respawns (before the forest
  road below was reshaped).
  - The mill race (the user saw the wheel with no water, its flume coming from nowhere and going nowhere, the mill too far
    from the road): `_plan_race()` (from `_init_noise`, before the ground) lays it out and `_race_cut` cuts its channels
    into `_natural` (`_natural_base` is the ground without them). The sawmill stands `MILL_GAP` (4m) off the yard road's
    edge; a creek down the north hill feeds the mill pond (`_pond`, found up the hill where the ground can hold it at the
    flume's height), a sluice, the flume on trestles (`MiyoshinoRiverKit.flume`, `FLUME_*`) into the sawmill's own trough
    (`sawmill_flume()`; the sawmill is built `with_water` false), the water falling over the wheel (`_build_wheel_fall`,
    waterfall.gdshader), the pit, a culvert under the road (`culvert_head` at both mouths: the road's grading fills the
    channel within about 5m of its flat band), the brook in two small falls into the log pond. The channels' water is
    ribbons on their levels (`_levels`: never rising downstream, never less than `free` under the ground), the river's
    shader with its own settings. Two water sounds (Gentle_flowing_water.wav) at the wheel and the brook.
  - The log pond (`BAY_C`, `BAY_R`): a bay of the north bank in `_natural_base` and `_shore_d`, its water a grid fading
    out over the river's own (COLOR.b) and three RiverWater pools. The rafts that drifted down the river went through the
    timber bridge and the raft train (the user saw them collide): three rafts with loads lie moored in the pond instead
    ("Moored_bay_*", bobbing with the train), tied to posts on its bank.
  - The village (the start straight, after a picture the user sent of a Japanese town: a row of dark-tiled houses, a
    paved sidewalk with lamps and planters, the road, a park with paths, a stream, a red bridge and a tea house):
    `_build_village`. The sidewalk (`_build_sidewalk`, `SIDE_W` 6m, `KERB` 16cm over the road, the road shader's paving,
    kind 1) is solid (`SidewalkStones`: off the course, asphalt under the tyres) and anything standing on it stands on it
    (`_stand_y`, a hook in MiyoshinoStage that `_beside` and `_build_start_crowd` use; its default is the ground). The
    machiya stand nearly wall to wall at its outer edge (`_build_house_rows`), alleys every five to seven houses lead to
    a back lane (`LANE_LAT`) and a second row (machiya, kura, thatched kominka, gardens behind bamboo fences). On the
    sidewalk: `MiyoshinoPropKit.street_lantern`, `planter`, `bike_rack` and `bicycle` at the alleys, the utility poles
    by the kerb. The start's crowd stands behind barriers on the river verge and on the sidewalk (`_build_start_crowd`'s
    `sides`). The river side: an azalea hedge, the cherry avenue, a promenade (`PROM_LAT`, paving drawn on the ground,
    `VillagePavingGround`) with lamps and `park_bench`es. The park (`PARK_X`, `_build_park`): the garden stream (a
    `_race` piece from its spring pool, `GARDEN_POOL`, `GARDEN_STREAM`) under the promenade's drum bridge
    (`arched_bridge`) and a path's smaller one, paths and two plazas (`PARK_PATHS`, `PARK_PLAZAS`), the tea house
    (`chaya`, `TEA_HOUSE`), weeping cherries, maples, pines, azaleas along the paths (MiyoshinoTrees' tsutsuji), purple
    irises (PondKit.iris with a colour) and `garden_rock`s along the stream; `_tree_pick` plants nothing of its own there
    (`_in_park`). The ground's grid is halved round the garden stream and the brook (`_extra_refine`): on 4m cells their
    channels showed as patches of water. A three-storey pagoda stands on the hill behind (`_build_hill_pagoda`). The
    props went from about 275k to 515k triangles (the second row of houses most of it): not yet measured on a GPU.
  - The user's picks from my ideas: a cherry-blossom fair on the promenade past the finish (`FAIR`, `_build_fair`:
    yatai, `festival_pole`s with chochin strings across and along), picnics on the park's lawns (`_build_picnics`),
    people in yukata (`_person`'s `yukata`; CrowdPlacer's spot field 6 adds 2 to the skin draw, `crowd_yukata` in
    crowd_common.gdshaderinc; `crowd_yukata` share of the start's crowd: the robe to the ankles round both legs, CrowdKit's
    `S_ROBE`, standing only, the obi above it, geta; with each leg robed apart they read as pyjamas; no hops), koi in the
    garden pool and stream (`KoiFish.gd`, `koi.gdshader`, `_build_koi`; 12-16cm under the surface: deeper, the creek
    water's colour all but hid them), a grey heron at the ford that flies off when a cart comes near (`Heron.gd`, built
    in code, `HERON_AT`; its first light greys read as an egret's white in the sun), and the park run (`PARK_RUN`, an AI
    path over the lawns and the park's little drum bridge onto the raft crossing, `_build_shortcut_paths`, its
    `ai_chance_scale` 0.35; everything keeps `PARK_RUN_CLEAR` off its line, `_run_d`). The run's first corner is a 45m
    sweep: at 18m a third of the bots, flat out off the start straight, ran straight on past it. `shortcut_probe ...
    chance=1.0` (speed 2, 240s): taken 18 times, all rejoined, no respawns.
  - `res://scratch/node_where.gd` (`-s`, headless, `-- <level> word ... [max=40]`) prints where a level's nodes are (their
    bounds, a path's points), to aim a camera; `look_shots` takes `hide=<word>` (e.g. `hide=millracesurface` to see the
    koi under the creek water).
  - The forest road (the user wanted it more exciting: sharp turns, ups and downs, more props): four sharp bends (radii
    24-30m) climbing from the yard (3m) over a crest (26m), down a dip (24m) and up to the slide's top (29m); curve
    mirrors and warning signs at the bends, jizo, a cedar torii near the top, way-stones, log stacks, a timber sledge, a
    woodcutters' hut with its kei truck, banners.
- Monzenmachi (2.0km, dusk, `MK.night`): the shop street under lantern strings (key "lantern_lights": not solid), the
  great gate (the road narrows to 6.5m through its 6.9m bay), the stone steps (treads whose nosings lie on the road's
  line; the collision is that ramp), the precinct (hall, pagoda, bell tower), the back street, the bamboo chicane and the
  walled Alley past it. 107 OmniLights without shadows; town batches in 60m cells for the Mobile renderer's light limit.
  The first street run must start at s 4, not `closest_s` of a point before s 0 (it returned the lap's end and the shop
  street stood empty). Laps about 50s, no respawns.
- Yamabushi Trail's summit (the user's idea, from two pictures): the cone's top is a gentle dome (`_summit_h`, `DOME_K`)
  meeting the trail where it ends (it had finished in a 17m cutting under a bare top), a walled terrace on it
  (`PRECINCT_R`, `PRECINCT_Y`, the drop inside the wall's line, `TERRACE_SLOPE_W`) with a precinct (`_build_summit`):
  `MiyoshinoTownKit.summit_hall` (vermilion, veranda, karahafu, lanterns), the five-storey pagoda, bell tower, water
  pavilion, a small Shinto hall, lanterns, banners, cherries, red maples (`MiyoshinoTrees` "momiji_red": the maple's
  cards tinted red), raked gravel and paths (the road shader's kinds 5 and 1 on meshes of their own, `precinct_gravel`
  warmer), `MiyoshinoPropKit.ishigaki` round it and a vermilion fence, `grand_stairs` up from a paved approach under two
  torii. The old summit shrine stands past the run-out's end behind a bamboo fence (the stop wall), the stone torii over
  the trail before the finish. The trail is asphalt to the trailhead torii (`_trail_from`), then stone paving (it was
  earth); the valley road (`_plan_routes`, a route pinned to the lap only at its start: `_add_route(..., pin_far_end
  false)`) runs 1km on north past the trailhead car park (`_build_trailhead`, `PARK_*`, kei cars and trucks:
  `MiyoshinoPropKit.kei_car`). A stage can halve its ground grid in places (`_extra_refine`; the shortcut-end halving
  only works since the fix in `_refine_axis`: the other three stages' saved levels predate it). Not raced yet.
- Yamabushi Trail (4.5km, point to point, dawn): a spiral of corners 1.6 times round a cone (`_spiral`, `_natural`), the
  mountain always on the right; a suspension bridge over the gorge (in the cloud: laid along the chord between its
  ends, shifted and widened to hold the curving trail, its side colliders along its netting; along the trail's heading
  at its start the trail's planks ran out past the netting toward the far end), plank walks (LEDGES) with chains,
  chain fences on the drops, the summit shrine. `CloudLayer.gd` sets every viewer's fog and sun by their camera's height
  (the band 96-150m: fog to 85m inside it), `cloud_sea.gdshader` the sheet seen from above. Bots take 114-130s.
- Music `MusicManager.STAGE_TRACKS` "senbon", "yoshino", "monzen", "yamabushi" (`music/miyoshino/`, instrumental,
  tools/elevenlabs). Their ambience is their own (`sounds/miyoshino/<bed>/`, tools/elevenlabs `miyo_*` jobs, three
  takes a bed, prompted without insects or near birds): the user found Lakeside's insects-and-birds bed, which they had
  borrowed, too full of bees and birdsong. Senbon a breeze in the blossoms, Yoshino the river under it, Monzenmachi the
  temple town's quiet dusk, the Yamabushi Trail mountain wind; a temple bell (`temple_bell.wav`, PeriodicSound via
  `MiyoshinoStage._periodic`) from the island's bell tower every 150s and the precinct's every 120s.
  `scratch/miyoshino_sound_check.gd` (`-s`, headless) lists each stage's layers and bells. Checked by numbers, not by
  ear: chirp and steady above-4kHz frames are near zero, against 4-44% and 25-70% in the Lakeside clips.
- Not checked yet: GPU cost on any of the four, the gusts and the cloud in a real race, the raft crossing and the Alley
  with bots forced onto them (`scratch/shortcut_probe ... chance=1.0`), collision_audit, the jump tests.

## Tianqiao (Yunhai GP, stage 1)

- The Yunhai GP (云海, `NetworkManager.GP_CUPS["Yunhai GP"]`, `MainMenu.COL_YUNHAI`) is a made-up river megacity at night
  after Chongqing; only stage 1 exists so far. `regenerate_tianqiao.gd` (`regenerate_tianqiao.tscn`, headless, about 15s)
  builds `levels/TianqiaoLevel.tscn` on the Miyoshino stage base (`MiyoshinoStage.gd`): one point-to-point run of 3.2km
  from the roof of the Yunhai Center (the supertall, start at 150m) along the Yunlang sky gallery's roof, a kicker and a
  30m gap onto tower B (138m), a skyway through tower E's sky lobby, the spiral round tower C (1.25 turns, 122 to 92m),
  a skyway to tower D, the second 30m gap onto the Xinghe Hui mall's roof (70m), three ramps cascading down its atrium
  hall (hairpins at the ends), the aquarium's acrylic tunnel through the tanks (fish MultiMeshes,
  `aquarium_fish.gdshader`; the tanks `aquarium_tank.gdshader`), out of a portal in the mall's south front
  (`MALL_PORTAL`) onto a flyover down into the night-market street and along it to the finish in the Yunhai Park. The
  user's idea and choices: one run top to park, night with neon and haze, drive through the mall and the aquarium.
- Heights: `_shape_heights` lays the lap's heights from knots at anchors found along it (`_find_anchors`, `_s_after`:
  the lap crosses itself round the spiral, so nearest points are searched past an s), rounded except across the jumps'
  gaps; everything down to the street is one ungraded "bridge". The road ribbon must stay above the roofs: the roofs'
  colliders (`RoofDeck_*`, track, asphalt) are 0.2m under the road's height, and the road holds its height until 6m
  past tower B's edge (it had dipped 8cm under the roof there by the rounding, and bots stopped at the edge).
- Buildings are `MegacityKit.gd` (game metres, world space, one `PropKit` per key) drawn by `megacity_tower.gdshader`
  (styles by COLOR.a x 8: office glass, flats, LED media facade, shop fronts, the mall's lit interior, concrete, cladding
  with an LED line; UV.x carries the building's number x 1000), neon by `neon_emissive.gdshader` and Label3D signs in
  Noto Sans CJK SC (see "The Yunhai GP's stage base" below).
- The shared parts (the city, the river, the night, `_deck`, `_roof`, the font) live in `YunhaiStage.gd`; Tianqiao keeps
  its towers, mall, aquarium, street and park, and `_plot_tweak` gives the blocks along the night-market street shop
  podiums.
- Runtime colliders: DressingColliders makes every prop mesh solid unless its name holds a skip word, and Level's
  collision builder gives anything named "ramp" or "loop" a convex hull (a "hall_ramp" prop became one blob filling the
  atrium). So every deck prop's key starts with "deck" or holds it (`deck_skyway_s1`, `hall_decks`, `roof_deck`, ...)
  and has its own rails (`_edge_boxes` on `SkyRailsBody`, parapet boxes in `_roof`); `MCK.tower(..., roof_parapet)` is off
  for the towers the lap crosses (their parapets in `_roof` have gaps where the lap passes: `open` stretches run along
  each side clockwise from above, the south side from its east end). Building walls are solid, so the lap's way out of
  the mall is a real hole in its south front and in the tanks' ends.
- The atrium hall's walls are drawn facing in (MCK.wall draws one side), so from the mall's roof they were invisible
  and the lap seemed to drive into an open hall, and on into a solid south wall at the aquarium (the hall's mesh holds
  glass, so DressingColliders leaves it soft and the bots drove through). Now `_x_wall` cuts real openings: the entry
  where the lap comes off the roof and the aquarium's door (`MALL_PORTAL`, `MALL_PORTAL_Y`: a lit frame, dark reveals to
  the tank, its name over it); the walls' tops over the roof are clad outside with an LED line; the south walkways (and
  their shoppers and signs) stop 14m short of the door below the floor the last ramp passes (they hung 3.5m over the
  road, as the user found).
- The skyways from tower B to the spiral and from the spiral to tower D are glass (the user's wish): their stretches
  are sections of their own, and `_glass_roads` puts `glass_deck.gdshader` (panes on a steel grid, the city showing
  through, LED edges) on those road pieces (found by their UV.y, metres along the lap); `_deck(..., glass)` builds no
  slab under them, only steel girders, stringers and ribs. Collision is the road's as usual.
- The gates after the jumps stand well past the landings: the user flew over the one on tower B's roof. One is on the
  glass skyway 25m past tower B's edge, the other 58m past the mall roof's landing.
- The mall roof's car park is gone (the user wanted a futuristic part of the mall complex there): the Xinghe Library
  (`_build_library`, 星河图书馆: five elliptical glass floors twisting up, white fins, terraces with readers, a lit book
  core, a glass dome in a roof garden; box slices as its collider, `LibraryBody`, since its mesh holds glass), a lattice
  shell over a sky garden east of the lap, and five LED rings over the lap where it runs east across the roof.
- The fish: no whale sharks (the user didn't like them); the fish have eyes (`_fish_mesh`: a white disc and a pupil
  each side of the head).
- MultiMesh buffers are written by hand (`_build_fish`): on the headless renderer `set_instance_transform` stores
  nothing and the saved fish were all at the origin. `scratch/tianqiao_fish_probe.gd` (`-s`) prints them.
- Falling off: PlayerCart respawns a cart (human or bot) once it is more than the level root's `fall_respawn_drop` meta
  (18m here) under the nearest point of the lap in 3D (`_fallen_off_heights`, every 0.2s); the y < -50 rule never fired
  150m over the street.
- AI races (`scratch/ai_race_test`, speed=2): every bot finishes in 76-89s; jump lips at 46-54 m/s. A bot knocked
  sideways in the air off tower D's kicker falls now and then.
- Music: the night folder's two tracks (`MusicManager.STAGE_TRACKS["tianqiao"]`) until the stage has its own.
- The menu tiles: `tile_tianqiao.jpg` (`menu_tile_shot`'s `STAGES` focus on the towers, spiral and mall) and
  `tile_yunhai_gp.jpg` (a copy of it until the cup has more stages).

## The Yunhai GP's stage base (YunhaiStage.gd)

- `YunhaiStage.gd` (on `MiyoshinoStage.gd`) holds what the Yunhai stages share: the flat street grid
  (`megacity_ground.gdshader`, `grid_origin`/`grid_cell`/`grid_street`, a park's lawns `park_rect`), the river
  (`river_pts`) under a dark mirror, hills round the far city, the night (`_environment`, which a stage can take with
  `super()` and change), the city's blocks (`_build_city` round `city_mid` to `city_near`, kept off `_reserved` and
  under the lap; `_plot_tweak` per plot) and skyline (`_build_skyline`), decks (`_deck`: slab, glass or concrete
  parapets with an LED line on top, LED strips, columns kept off lower stretches of the lap by `_col_ok` and off what a
  stage's `_col_blocked` says; `pier_style` 1 for motorway hammerhead piers), roofs (`_roof`), crowd lines.
- The signs' font: `fonts/NotoSansSC-Yunhai.otf`, Noto Sans CJK SC Bold cut down to ASCII and the characters the Yunhai
  generators use. After adding a sign with new characters run `scratch/yunhai_font_subset.sh` (pyftsubset, the
  system's NotoSansCJK-Bold.ttc face 2), then regenerate. `_load_cjk_font` (in `_build_dressing`: the run clears the
  stage's old files after `_configure`) reads it into a FontFile saved as `generated/<stem>_cjk_font.res`, so the
  generator needs no import of it. OFL text in `fonts/NotoSansCJK-OFL.txt`.

## Panlong Interchange (Yunhai GP, stage 2)

- `regenerate_panlong.gd` (`regenerate_panlong.tscn`, headless, about 20s) builds `levels/PanlongLevel.tscn`: laps (3km)
  of a made-up five-level motorway interchange at the blue hour. The user picked it from four ideas for stage 2 (the
  interchange, a cliff town of stilt houses by the river, racing the monorail through a block of flats, the river's
  banks in morning fog); the others are open for later stages.
- The lap turns left eight times (`corners`), twice round, crossing itself three times: the start straight on the
  ground (z 0) under the west leg (x -150, 22m) and the north leg (x 120, 12m), and the low leg (z -160, 12m) under the
  west leg. Heights are `KNOTS` (plan points well clear of the crossings, lap order) interpolated round the closed lap
  and rounded; every stretch over 2.5m is an ungraded bridge, and so is the start straight over the cutting.
- The unfinished ramp on the top leg (z -300): a 28m gap after a kicker (`JUMP_LIP`, `JUMP_GAP`), the deck ends cut
  square with starter bars and chevrons, red lamps, a 前方施工 ("works ahead") board.
- Around it: the Nanbin Expressway sunk in a cutting along x 0 (`CUT_*`: the ground cut in `_natural`, walls, the grid's
  streets crossing on bridges), the Yunhai Ring Expressway at 36m along z -60 over everything (`RING_*`, piers kept off
  the lap's legs and the cutting), both with AutobahnTraffic.gd traffic (CampKit's vans and SUVs at PROP_SCALE with
  head- and tail-lights added, no sound), green sign gantries over the lap (`GANTRIES`), lamp posts, four LED
  billboards, a footbridge over the start straight with people on it, pines, maples, bamboo and a few cherries on the
  lawns inside the knot (`KNOT_RECT`), the city round it.
- AI races (`scratch/ai_race_test`, speed=2): every bot finishes three laps in 64-82s each; the kicker is crossed at
  41-58 m/s and one bot in six fell short of the landing once.
- `fall_respawn_drop` is 9m: a cart off the coil respawns before it reaches the lawn. One that drops off an upper leg
  onto a lower stretch of the lap is on the track there and drives on (the gates then count it as having missed one).
- Music: the night folder's two tracks (`STAGE_TRACKS["panlong"]`) until it has its own. Menu tile: `tile_panlong.jpg`.

## Wangjiang (Yunhai GP, stage 3)

- `regenerate_wangjiang.gd` (`regenerate_wangjiang.tscn`, headless, about 20s) builds `levels/WangjiangLevel.tscn`: one
  4km run at night from the plateau (80m) down to the river and over it to the far bank. The user asked for two of the ideas offered for
  stage 2 together (racing the monorail through a block of flats, the cliff town of stilt houses by the river) as a
  longer point-to-point race.
- The run: Wangjiang Road east from Wangjiang station with the monorail's beam beside it (`MONO_SIDE` north,
  `MONO_UP` over the road), both on viaducts across the Huaxi gully (`_natural`: a ravine at x 750, floor 25m, running
  on down the slope); through the Jiayuan Building (`FLATS`), whose hole (`FLATS_HOLE_Z`, walls cut by `_z_wall`) the road
  and the line share; through Chaoyang station, its two halves either side of a cross street (`STATION_2A`/`2B`), a
  kicker and a 28m gap between them (`JUMP_LIP`); south down Jiefang Road; four legs along the slope (`LEGS`) joined by
  hairpins (r20, 40m apart, the legs falling 12-13m each, the hairpins flat); the quay west to the Yunhai Bridge; over
  the river; the finish in the Yunhai Plaza on the far bank. The user had the legs halved (they were 380m) and the run
  carried over the river to a grand plaza.
- The Yunhai Bridge (`_build_bridge`, 云海大桥, along `BRIDGE_X`): up a 12% ramp off the quay, level over the main span
  between two A-shaped white pylons (`PYLONS`, 118m, LED legs, red lights), down a ramp into the plaza; fans of steel
  stays (lit faintly: bright, they glowed into broad white bars across the view from the deck); no piers under the main
  span (`_col_blocked`); the pylons' feet are boxes (`BridgePylonsBody`). The quay's railing, lanterns and stalls stop
  where the road crosses the promenade.
- The Yunhai Plaza (`_build_plaza`, 云海广场, `PLAZA2`): paving with LED rings, a lit arch where the bridge comes down,
  grandstands both sides of the finish straight (`_grandstand`: ten rows, seats in the cup's colours, a cantilevered
  roof, LED boards along the front, about 1,400 people seated), a concert stage at the end (LED screens, a truss roof,
  speakers, spots and lasers into the sky, a crowd before it), fountains, nine illuminated towers round it with lit
  crowns, barriers along the finish straight and across the road's end.
- Heights: `KNOTS` along the run; every stretch more than 3m over `_natural` (and the hole) is an ungraded bridge.
  The city's towers stand on the lowest ground under their plots (`YunhaiStage._plot_ground`), so they rise out of the
  gully and step down the slope.
- The monorail: Monorail.gd (three cars, Bloombay Dunes' car shape in white with a red band, `_car_mesh`), stops at both
  stations and the ends, on the wall clock, so the train is wherever the clock puts it when the race passes; its beam and
  columns (none in the building or over the cross street) are a "deck_" prop.
- The cliff town (`_build_cliff_town`): along each leg, stilt houses on the downhill side (`_stilt_house`: timber floors
  with lit windows, balconies at the back, a grey roof with flared corners, stilts to the slope, lanterns, a shop sign),
  shopfronts in a retaining wall uphill (`_uphill_front`), every fourth house spanning the road on posts 6.6m up
  (`_arcade`, its windows on the faces the drivers see), houses up the slope above the first leg, pavilions at the
  hairpins. Window colours are kept dim (neon_emissive at energy 4 burns pale colours to white blobs).
- The quay (`_build_quay`): the river wall, a railed promenade with lanterns and food stalls, shophouses at the hill's
  foot, four LED-outlined tour boats, a lantern gate (望江码头) at the bridge's foot. The cableway over the river (`CableCar.gd`:
  two cabins on sagging ropes shuttling on the wall clock, a jig-back) runs from the plateau's edge (`CABLE_A`) to the
  far bank.
- AI races (`scratch/ai_race_test`, speed=2): every bot finishes in 91-117s; the kicker is crossed at 47-56 m/s.
- `fall_respawn_drop` 11m (the legs are 12-13m apart, so a cart off an upper leg lands on the one below and drives on).

## Shuangjiang (Yunhai GP, stage 4)

- `regenerate_shuangjiang.gd` (`regenerate_shuangjiang.tscn`, headless, about 20s) builds `levels/ShuangjiangLevel.tscn`:
  laps (about 3.85km, 85-115s) at dawn after the night race, where the main river (along z 0, banks at |z|
  `RIVER_HALF_W` 205m) meets a tributary (along `TRIB_X`, `TRIB_HALF` 150m wide each side) from the north. The last of
  the four ideas offered for the cup's second stage.
- The lap: the start on the south bank's avenue (`START_AT`) heading west past the riverside park (`RIVERSIDE`); north
  over the Jiangxin Bridge (江心大桥, `_build_arch_bridge`, a red steel through-arch along `ARCH_X`: ribs, chords, webs,
  hangers, wind bracing over the deck, LED); down off the peninsula onto the shore road (gravel, `_sections`) at the
  water's edge under the bluff, a kicker and a 36m jump over a sand barge moored in an inlet (`JUMP_LIP`, `INLET`); a
  loop up over the shore road at the confluence's beach (the bluff turns north from `BLUFF_X0`, `BLUFF_RECEDE`) onto
  the Shuangjiang Bridge (双江大桥, `_build_suspension_bridge`, along `SUSP_X`: white towers at z +-`SUSP_TOWER_Z`,
  main cables `_cable_y` self-anchored on the deck's edges at `SUSP_END_Z`, hangers, no piers under the main span,
  `_col_blocked`); down onto the avenue. Every stretch more than 3m over `_natural` is a bridge on hammerhead piers.
  The loop was first tight (r60) and in a cutting into the bluff: bots flew off its bends and one drove round under it
  for the rest of the race; it now has r80 corners on the open beach and no boost before it.
- Fog: the environment starts in thick morning fog (`_environment`: fog 25-850m, a low warm sun in the east, a pale
  sky). `FogLift.gd` (a child of the level) lifts it once the race starts (Level's `race_state` past the lobby) over
  `lift_time` (210s) to 160-2600m, and thins the river mist (`_build_mist`: `river_mist.gdshader` sheets, children
  named "Mist...", drifting wisps that fade near the camera and where they meet things) to `end_mist` of its density;
  each peer on its own clock. `res://scratch/fog_lift_check.tscn -- [level=] [lift=4]` (headless) prints it lifting.
- The ground: `megacity_ground.gdshader`'s `shore_y` (3.4 here: under it gravel and mud, wetter and glossier toward
  the water, no streets or their lamp pools or gloss) and `slope_grass` (steep ground above the shore is grass and
  rock). Their defaults leave the other stages as they were. The roads have a little dew (`wetness`).
- Dressing: Tianqiao's landmarks on the peninsula's heights looming out of the fog (`_build_landmarks`: the Liangjiang
  towers with their sky gallery 云廊, the Yunhai Center supertall); the shore (`_build_shore`: a retaining wall along the
  bluff, boulders, beached sampans, sand heaps, fishermen); the confluence's beach (`_build_beach`); barges, a container
  barge and river cruisers (`_build_barges`); the riverside park's promenade, lamps and benches, mostly green trees
  (`_tree_pick`); lamps along the lap; the start crowd. Mornings dim the city's windows and LEDs (the shared
  `MCK.material` values set in `_build_dressing`). `MCK.rock_heap` is the aquarium's dark "tank" material: the boulders
  here are `_boulders` ("paint").
- AI races (`scratch/ai_race_test`, speed=2): every bot finishes; the only respawns are from items. The barge jump is
  crossed at 43-50 m/s. `fall_respawn_drop` 9m.
- Music: `STAGE_TRACKS["shuangjiang"]` (Above the Clouds, then Engines at the Gate). Menu tile: `tile_shuangjiang.jpg`.
