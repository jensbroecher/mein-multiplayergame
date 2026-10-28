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
- The road stops round the loop (`_plan_road_gaps`, `LOOP_ROAD_GAP`: 8m before the entry lane's start to 10m
  after the exit lane's end, from the loop's saved place): `TerrainGenerator.road_gaps`, with the asphalt and
  curbs tapering to a point over `road_gap_taper` (12m) either side, so carts cross a short stretch of grass into
  the loop and out of it (the meadow grows mown grass there). Changing the gap re-bakes the world (meta
  `baked_road_gaps`). The pylons reach down to the ground beside the road (`LoopCSG.support_foot_y`, from the
  ground under `support_spots()`, 0.4m in): they started at the loop's origin and stood in the air.
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

## Canyon Course (Sierra del Viento, stage 1)

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
- The eagle (`Eagle.gd` on `models/animals/20260717033727_7db23447.fbx`) skips its setup in the generator:
  its wing pivots and sound players were saved into the level, and at runtime the model's own wings came
  back beside them (two eagles, one inside the other). Its wings (`part_4`, `part_7`) hinge on the body's
  long axis; each one's angle in the model (a steep V) is measured and lowered to `glide_dihedral_deg`.
  Soaring it beats in bursts; in the dive (a stoop) the wings are drawn up; grabbing and carrying it
  beats hard, the downstroke 40% of the beat, the wing twisting through it. It banks into turns. A cart
  at `escape_speed_share` (0.88) of its top speed outruns it: never picked, and a dive breaks off.
  `part_8` (a stray feather over the head) is hidden. `res://scratch/eagle_preview.tscn -- <dir> [yaw=]
  [pitch=]` renders the wing poses through a beat.
- `res://scratch/lap_shots.tscn -- <level> <dir> [every=N] [s=<m>] [high=1]` renders chase views along any
  lap; `scratch/canyon_props_preview.gd` (`-s`, windowed, `-- <dir> set=rocks|forms|cacti [far=1]
  name:x,y,z:tx,ty,tz`) renders the cacti and rocks in memory in seconds; `scratch/dress_list.gd` (`-s`,
  headless, `-- [match=Near_saguaro] [count=8] [max=60]`) lists where a level's MultiMesh dressing stands
  (to aim a camera at it); `scratch/asset_sheet.gd` (windowed) a contact sheet of a model folder;
  `scratch/lod_probe.gd` and `scratch/asset_survey.gd` (headless) a model's LOD chain and triangles/textures.

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

## Road gaps

`TerrainGenerator.road_gaps` ([s0, s1] pairs along the curve, default roads only) leaves stretches of a lap
with no road. `_road_gap_width(offset)` scales the asphalt's half width, the curbs' inner edge, the road sides
and the road collision to 0 over `road_gap_taper` before each gap and back after it, and `_segment_in_gap`
drops the segments where it reaches 0. `_road_gap_ground` grades the ground (visual and collision) along the gap
and both tapers to `ROAD_GAP_GROUND` (18cm, under the curbs' outer edge) below the road's surface, easing
back 6m past them. PlayerCart's corridor rule (terrain within the road's half width counts as road) skips the
gaps and tapers (`_in_road_gap`), so the ground there is grass, off-road, with its sound and dust.

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
- `StageAmbience.gd` (added by Level) plays the recorded backgrounds in `sounds/<kind>/` per stage (`STAGES`),
  under the levels' own baked ambiences, crossfading random clips. Each clip is levelled by its measured
  RMS (`CLIP_DB`): they range from -12 to -49 dBFS. Measure a new clip before adding it. The deserts
  (Mountain Pass's dunes too: it had the forest layer, birdsong over sand) have none: nothing recorded
  suits them.
- Leftover sounds now used: `unused_tire_screech_*` (a one-shot at the start of a skid over 12 m/s),
  `unused_car_crash_clank` (cart against cart), `unused_warning_beep` (a missile closing on the local
  cart), `unused_alert` (wrong way). The double beep (an item in hand) was too distracting and is gone.
  The odd-named loops in `sounds/enginesounds/` (`cccc`, `kkk`, ...) are spares no car uses.
  The screech and the squeal (`SFX_BrakeDrift`) only play on paved road: see Surfaces below.

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
- `res://scratch/surface_fx_test.tscn -- <level> [seconds=60]` races the AI and tallies, per surface, the
  marks, smoke, dust, grit and sound, with the sliding loop's mean level in dBFS against the engine's
  (windowed: headless never primes the trail particles, so only the
  classification counts there). `res://scratch/skid_shots.tscn -- <dir>` (windowed) photographs marks the
  AI laid; `res://scratch/spray_shots.tscn -- <dir> level=...` shoots carts raising dust.

## Props that give: flags, tyre stacks, cones

- `SpringProps.gd` (a MultiMeshInstance3D, one per design, rest transforms in `rest`): each prop is a damped
  spring tip about its foot plus, for stacks, a slide. A cart's touch (its speed from how far it moved, so
  remote carts count) tips it away and the prop wobbles back; only moving props are written back. Local
  scenery, not synced. Flags (Bloombay's feather and chequered flags, `_build_spring_flags`, FLAG_SCALE 1.5)
  have no collider: a cart drives through, the flag bends over and loses it a little speed. Their waving
  phase is the instance custom data (`flag_wave.gdshader`'s INSTANCE_CUSTOM.x). Chequered flags stand only
  at the start/finish (`_build_finish_flags`, FINISH_AT).
- `TyreStacks.gd`: tyre walls of stacks of `PropKit.painted_tyre` (tyre_wall.gdshader), as SpringProps (they
  shift up to 0.6m and rock) over the wall's own box colliders, which still stop the cart. Lakeside,
  Bloombay and Pinecrest all build their tyre walls through it. Bloombay's corner cones are KnockableProps.
- `res://scratch/spring_props_test.tscn -- <dir> [level=] [props=Flags|Stacks] [index=N] [speed=25]` (windowed)
  drives a cart through one prop and logs the tip and slide.
- Marker poles (`KnockablePoles.gd`: Msitu Falls, Frostfall Gorge, Mara Crossing) are rigid bodies frozen until
  a cart comes within `RELEASE_RADIUS`. On the hit (`_launch`) a pole is thrown: away from the cart and
  along its travel at `LAUNCH_SPEED_SHARE` of its speed (from how far it moved, so remote carts count), a
  hop up (`LAUNCH_UP_*`), tumbling. Left to the contact, the cart's sphere only tipped it over and rolled
  on top of it (0.2m up at most); now 5-23m out and up to 5m high at 30 m/s.
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
  - Not solid: ground cover under `MIN_HEIGHT` (0.5m), anything named in `SOFT` (grass, meadow, crowd,
    flags and tyre stacks, which are SpringProps, knockable props, icicles, skid marks, shadow-only
    stand-ins), and MultiMeshes run by a script that moves its own instances (`SELF_MOVING`: KnockablePoles,
    KnockableIce, KnockableProps, SpringProps). The poles' MultiMesh is named `MarkerPosts`/`SnowPoles`,
    which `SOFT` missed: a static collider and a wobble here stopped the carts on it and fought the poles'
    rigid bodies for the transforms (a wiggle and a glitch instead of the pole flying).
  - Brush (`BRUSH`, by the mesh's file name: the ferns, not `tree_fern`): no collider at all. A cart drives
    through, bends it right over (`BRUSH_LEAN`, `BRUSH_KICK`, along its travel) and loses `BRUSH_DRAG`
    (3.5%) of its speed entering each one (carts this peer has physics authority over, as SpringProps'
    flags do); one the Detail Level doesn't draw slows nobody. Solid, the ferns stopped carts dead.
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
`res://scratch/wooden_ramp_preview.gd` (`-s`, windowed, `-- <dir> name:x,y,z:tx,ty,tz`) renders a kicker, a
table-top and a roller on a flat road.

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
- Time trial: no boxes at all (Level frees the levels' own too), and each lap starts with two boosts in the
  slots (`_give_lap_boosts`, `PlayerCart.set_lap_boosts`). `res://scratch/time_trial_items_check.tscn`.
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
  within one run; `gates` samples 10m before each checkpoint instead of along the lap. On macOS, separate
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
- `CrowdKit.gd` is one mesh (about 1.8k triangles, 1k of them drawn) in a standing rest pose at 1.86 times life
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
- The shoulder joint (`SHOULDER_X` 0.34) is just inside the torso's side, with a deltoid on the upper arm: out at
  0.40, beside the chest, a raised arm swung about a point outside the body and stood off the shoulder with a gap.
  (A deltoid turning only part of the way with the arm stuck out as a lump under a raised arm.) The cap is a crown
  cut on a slant (at the brows in front, mid-head at the back) with a curved bill from its front edge
  (`_build_cap`); the short hair is on the head's own 6 x 12 grid, since on a coarser one the head's corners poked
  through it. `res://scratch/crowd_preview.gd` is the way to check a pose.
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
  `generated/crowd_person.res`) from spots of [position, facing, seated], at a scale and with a skin mix of its
  own (Lakeside's start). Nyota's generator still has its own copy of these numbers.
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
- A boost no longer skips braking for a sharp corner ("let the boost rip" only for bends under 1.6 times
  `react_corner`): a boosted bot met Glacier Highway's Ridge Bypass fork, 84 degrees, at 60 m/s.
- `res://scratch/shortcut_probe.tscn -- <level> [seconds=180] [speed=2] [static=1] [chance=1.0] [trace=<name>]`
  checks each shortcut (ends against the lap, water, drops, solid things on the line) and races bots that
  take every one, listing where any falls, drowns or sticks (and where it was 0.5s before); `trace=` logs a
  shortcut's riders every 0.2s (off the line, speed, the turn ahead, boosting). `res://scratch/colliders_near.tscn
  -- <level> x,y,z ... [radius=3] [route=<path>:<s0>:<s1>[:half]]` lists what is solid at a spot, and what a
  ray down a route meets. `res://scratch/path_overlay_shots.tscn -- <level> <dir> name:x,y,z:tx,ty,tz[:fov]`
  renders a level with its lap (white), shortcuts (yellow) and other paths (cyan) drawn over it.
- Still on the main laps (not shortcuts): Glacier Highway catches bots on a sign gantry's leg at the S-bend
  near 470m and at 790-850m; Lakeside loses a few round its lakes, scattered.

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
  rebuild) also needs a preset appended to both lists (they're indexed, so append), a `CAR_ACCENTS` colour and its
  name in `Lobby.CAR_NAMES`.
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

## Canyon Chasm dirt ramps and rocks

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
