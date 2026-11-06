extends RefCounted
## Kokerei Kronprinz, the colliery's still-working coking plant (Zeche Kronprinz, Kronburg GP stage 3): a coke oven battery
## (Koksofenbatterie) with its machines (the pusher machine, the coke guide car, the quench car and its loco, the larry
## car on top), the coal tower at its end, the quench tower and the coke wharf on the quench car line, the by-product
## plant (Nebengewinnung), the emergency gas flare and plain standard-gauge track. A generic 1950s-70s Ruhr plant: no real
## works, every name fictional.
##
## Everything is built through a PropKit at LIFE size and grown by the caller (PROP_SCALE 1.6): make a kit with
## `new_kit(scale)`, set its frame (scaled by PROP_SCALE), call a builder, `commit(pk, kit)`. UVs are in metres times `uvk`
## (the caller's scale) where a shader reads them (brick, concrete, corrugated iron, timber, sleepers), in life metres on
## glazing. Labels are SteelworksKit's [text, position, outward normal, cap height, colour, board width], life size in the
## builder's frame. SteelworksKit's helpers (and its pipe_run, chimney) are used directly, sharing this kit's frame.
##
## THE BATTERY FRAME. coke_battery's frame is the plant's: x along the battery from 0 to battery_length(ovens) (end walls
## END_W thick at both ends, then the ovens at PITCH 1.45: oven i's middle at oven_x(i), heating wall j at wall_x(j)), z
## across it (the pusher side toward -z, the coke side toward +z), y = 0 the ground. Life metres:
##   brick faces z +-7.00; door frames' faces +-7.30; doors +-7.50; buckstays (the battery's face) +-7.66
##   oven sole y 4.4, chambers to 8.7, battery top y 9.6 (TOP_Y); benches y 4.2 (BENCH_Y)
##   pusher bench   z -7.1..-9.4, x 0..L+2.4      coke bench   z 7.1..11.8, x 0..L+1.2 (columns z 11.16..11.72)
##   pusher rails   z -10.6 and -16.6, rail top y 0.25 (PUSH_RAIL_Y), x -2..L+2, on concrete strips z +-0.45
##   guide rails    z 8.3 and 11.2 on the coke bench, rail top y 4.28 (GUIDE_RAIL_Y), x 0..L+1.2
##   larry rails    z -4.5 and 4.5 on the top, rail top y 9.8 (LARRY_RAIL_Y), x 0..L-0.45 (the coal tower carries them on)
##   quench track   z 14.4 (QUENCH_Z): the caller lays kokerei_rails along x there; its rail top is y 0.2 (RAIL_TOP)
##   gas collecting main z -7.0, y 12.3, r 0.75; ascension pipes at z -5.8; the offtake leaves at x L+3 toward -z
##   (gas_offtake()).
## The machines are built in that same frame, only shifted along x: place each at Vector3(oven_x(i), 0, 0) in the battery's
## frame (its ram, guide, hoppers on oven i). The quench car is built in the track's frame (z 0 the track's middle, y 0 the
## track's ground): place it like kokerei_rails, at (x, 0, QUENCH_Z).
##
## Builders (life metres; footings run below y = 0; extents measured on the built triangles):
##   coke_battery(pk, kit, labels, ovens = 50, number = 3, seed = 3, open_oven = -1)   57.1k triangles at 50 ovens
##       x -2..L+8.2 (rails, far-end stairs), z -17.05..11.82, y to 14.4 (valve spindles); L = battery_length(ovens),
##       78.9 at 50. open_oven: that oven's doors off, its chamber glowing (pusher, guide car and loaded quench car at it)
##   pusher_machine(pk, kit, holding_door = false)   x -4.85..4.85, z -27.84..-9.45, y 0.24..13.0   (3.9k)
##   coke_guide_car(pk, kit, pushing = false, holding_door = false)   x -3.05..3.1, z 7.34..13.3, y 4.2..13.6   (2.7k)
##       pushing: the cage reaches the door frame with a glowing coke cake in it (use only at the battery's open_oven)
##   quench_car(pk, kit, load = 0)   track frame: x -17.0..8.05 (loco at -x), z -1.9..1.9, y to 4.3 (3.7k)
##       load 1 glowing coke, 2 quenched (grey, wet); x 0 the tub's middle; discharge gates on its -z side
##   larry_car(pk, kit)              x -2.6..4.4, z -4.84..4.84, y 9.8..16.4   (1.7k)
##   coal_tower(pk, kit, labels)     origin under its middle: x -16.6 (gallery stub)..12.55 (deck bridge), z -14.1..10.35,
##                                   y to 48; place it at battery x = COAL_TOWER_X (-12.55) so its deck meets the end wall
##                                   (4.3k)
##   quench_tower(pk, kit, labels)   the track along x through its foot: clear |z| < 2.97 from y 0 to 6.35 (spray headers
##                                   above); x -7.6..7.15, z -7.15 (stairs)..+4.95, y to 43.0; quench_steam_point() (5.4k)
##   coke_wharf(pk, kit, length = 60) x -0.5..length+0.5, z -12.6..1.0, y to 12.8 (lamp masts); y = 0 the LOWER yard; its
##                                   lip 5.9 up at z 0; the quench track beside it at z +3.0 on ground y 4.6
##                                   (WHARF_TRACK_Z/Y); see coke_wharf (4.4k at 60m)
##   byproduct_plant(pk, kit, labels) centred: x -42..42, z -28..30, y to 36.6 (washer vents), chimney 32  (37.6k)
##   kokerei_rails(pk, kit, length)  along +x from 0 to length, rails z +-0.7175, rail top y 0.2, ballast z +-2.3 (1.7k/100m)
##   gas_flare(pk, kit)              base centred: x -4.8..7.6, z -2.6..2.6, y to 30.45; flare_point(), flare_inlet() (3.9k)
## Effects: battery_fx_spots(), quench_steam_point(), flare_point(), wharf_steam_spots(), quench_car_fx_spots(),
## byproduct_fx_spots() give places in each builder's frame. Hook-ups: gas_offtake(), byproduct_gas_inlet()/_outlet(),
## flare_inlet(), coal_tower_gallery_end().
##
## Faces never share a plane: trims, doors, plates and glazing stand 2.5cm+ proud of what is behind them, parts that meet
## overlap or step. Godot's front faces wind clockwise: PropKit.tri winds every triangle for the `out` it is given.

const PropKit = preload("res://PropKit.gd")
const SteelworksKit = preload("res://SteelworksKit.gd")
const YardKit = preload("res://YardKit.gd")
const FreightKit = preload("res://FreightKit.gd")

static var uvk := 1.6
static var _mats := {}

const TANGENT_KEYS := ["iron", "concrete", "slate", "tile"]

# ---- The battery's frame (life metres) ----
const PITCH := 1.45
const END_W := 3.2
const FACE_Z := 7.0
const FRAME_Z := 7.30
const DOOR_Z := 7.50
const BUCK_Z := 7.66
const SOLE_Y := 4.4
const CHAMBER_TOP := 8.7
const TOP_Y := 9.6
const BENCH_Y := 4.2
const BENCH_IN := 7.1
const PUSH_BENCH_OUT := 9.4
const COKE_BENCH_OUT := 11.8
const PUSH_RAILS := [-10.6, -16.6]
const PUSH_RAIL_Y := 0.25
const GUIDE_RAILS := [8.3, 11.2]
const GUIDE_RAIL_Y := 4.28
const LARRY_RAIL_Z := 4.5
const LARRY_RAIL_Y := 9.8
const QUENCH_Z := 14.4
const RAIL_TOP := 0.2
const GAUGE_HALF := 0.7175
const ASC_Z := -5.8
const MAIN_Z := -7.0
const MAIN_Y := 12.3
const MAIN_R := 0.75
const CHARGE_Z := [-3.3, -1.1, 1.1, 3.3]
## Where coal_tower's origin goes in the battery's frame (its deck bridge then ends at the battery's x = 0).
const COAL_TOWER_X := -12.55
const WHARF_TRACK_Z := 3.0
const WHARF_TRACK_Y := 4.6

# ---- Colours ----
const WHITE := Color(1, 1, 1)
const BRICK := Color(0.44, 0.21, 0.15)
const BRICK_DARK := Color(0.34, 0.17, 0.13)
const FIREBRICK := Color(0.80, 0.68, 0.50)
const CONCRETE := Color(0.64, 0.63, 0.60)
const CONC_SOOT := Color(0.58, 0.57, 0.54)
const CONC_DARK := Color(0.44, 0.43, 0.40)
const KERB := Color(0.62, 0.50, 0.15)
const STEEL := Color(0.26, 0.31, 0.30)
const STEEL_DARK := Color(0.16, 0.18, 0.18)
const CAST := Color(0.15, 0.14, 0.13)
const ARMOUR := Color(0.12, 0.115, 0.11)
const BUCK := Color(0.21, 0.22, 0.22)
const DOOR_COL := Color(0.22, 0.20, 0.19)
const FRAME_COL := Color(0.40, 0.39, 0.37)
const SPRING := Color(0.30, 0.27, 0.22)
const BENCH_COL := Color(0.30, 0.29, 0.27)
const SOOT_TOP := Color(0.24, 0.22, 0.21)
const ASC_COL := Color(0.42, 0.41, 0.39)
const ASC_DARK := Color(0.22, 0.21, 0.20)
const MAIN_COL := Color(0.30, 0.29, 0.27)
const CLAY := Color(0.36, 0.33, 0.28)
const MACHINE := Color(0.24, 0.34, 0.29)
const CLAD := Color(0.42, 0.47, 0.43)
const GUIDE_COL := Color(0.74, 0.55, 0.16)
const LARRY_COL := Color(0.27, 0.35, 0.31)
const LOCO_RED := Color(0.50, 0.15, 0.10)
const TUB := Color(0.21, 0.19, 0.17)
const WHEEL := Color(0.20, 0.19, 0.18)
const RAIL_COL := Color(0.36, 0.25, 0.19)
const ROOF_COL := Color(0.26, 0.26, 0.26)
const COKE := Color(0.30, 0.30, 0.31)
const CREAM := Color(0.94, 0.91, 0.82)
const BOARD := Color(0.08, 0.16, 0.30)
const CRANE_YELLOW := Color(0.93, 0.68, 0.10)
const RED := Color(0.70, 0.12, 0.09)
const TAR := Color(0.13, 0.12, 0.11)
const SILVER := Color(0.70, 0.70, 0.68)
const PIPE_RUST := Color(0.45, 0.40, 0.34)


# ======================================================================================
#  Materials and kits
# ======================================================================================

## Keys: "soot" (kokerei_soot.gdshader: soot streaks by the vertex alpha), "coke" (kokerei_coke.gdshader: lumps of coke),
## "kballast" (rail_ballast.gdshader for a sooty plant: UV.x the game metres across the track), "sleeper", "rail",
## "railtop" (FreightKit's), and everything SteelworksKit makes: "brick" (ruhr_brick), "concrete", "iron", "timber",
## "painted", "roofing", "rusty", "grime", "shell", "floor", "corten", "hot", "glass", "skylight", "hazard", "lamp",
## "lens", "heap", "steel", "metal", "matte", "paint", "rubber".
static func make_material(key: String) -> Material:
	match key:
		"soot":
			var s := ShaderMaterial.new()
			s.shader = load("res://kokerei_soot.gdshader")
			return s
		"sootcrete":
			# Concrete with the shuttering's lines (the quench tower, the coal tower's underside).
			var c := ShaderMaterial.new()
			c.shader = load("res://kokerei_soot.gdshader")
			c.set_shader_parameter("board", 1.0)
			return c
		"coke":
			var k := ShaderMaterial.new()
			k.shader = load("res://kokerei_coke.gdshader")
			return k
		"kballast":
			var b := ShaderMaterial.new()
			b.shader = load("res://rail_ballast.gdshader")
			b.set_shader_parameter("stones_tex", load("res://materials/dark_canyon_rock.png"))
			b.set_shader_parameter("stones_normal", load("res://materials/dark_canyon_rock_normal.png"))
			b.set_shader_parameter("gauge_half", GAUGE_HALF * uvk)
			b.set_shader_parameter("tile_m", 1.7 * uvk / 1.5)
			b.set_shader_parameter("dust", Color(0.25, 0.23, 0.21))
			b.set_shader_parameter("oil", Color(0.20, 0.18, 0.17))
			b.set_shader_parameter("rust", Color(0.38, 0.25, 0.18))
			return b
		"sleeper", "rail", "railtop":
			return FreightKit.make_material(key)
	return SteelworksKit.make_material(key)


## A kit growing everything by `scale`, its materials shared with every other kit made here.
static func new_kit(scale: float) -> PropKit:
	var pk := PropKit.new()
	pk.material_for = func(k: String) -> Material:
		if not _mats.has(k):
			_mats[k] = make_material(k)
		return _mats[k]
	pk.set_frame(Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO))
	uvk = scale
	SteelworksKit.uvk = scale
	SteelworksKit._lx = Transform3D.IDENTITY
	YardKit.uvk = scale
	return pk


## The materials made so far, by key (the generator saves them so every mesh shares one per key).
static func materials() -> Dictionary:
	return _mats


## Commits a kit with tangents on the surfaces whose shaders read a normal map; each surface named after its key.
static func commit(pk: PropKit, kit: Dictionary) -> ArrayMesh:
	for key in TANGENT_KEYS:
		if kit.has(key):
			var st: SurfaceTool = kit[key]
			st.index()
			st.generate_tangents()
	var mesh := ArrayMesh.new()
	var keys: Array = kit.keys()
	keys.sort()
	for key in keys:
		var s: SurfaceTool = kit[key]
		s.index()
		var before := mesh.get_surface_count()
		s.commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_material(before, pk.material_for.call(key))
			mesh.surface_set_name(before, key)
	return mesh


# ======================================================================================
#  Layout
# ======================================================================================

static func battery_length(ovens: int) -> float:
	return END_W * 2.0 + PITCH * float(ovens)


## Oven i's middle along the battery (x), i from 0.
static func oven_x(i: int) -> float:
	return END_W + PITCH * (float(i) + 0.5)


## Heating wall j (j from 0 to ovens: 0 and ovens are the end flues against the end walls).
static func wall_x(j: int) -> float:
	return END_W + PITCH * float(j)


## The gas offtake's open end in the battery's frame: [point (the pipe's centre), direction it continues in, radius].
static func gas_offtake(ovens := 50) -> Array:
	return [Vector3(battery_length(ovens) + 3.0, MAIN_Y, -12.0), Vector3(0, 0, -1), MAIN_R]


## The doors whose seals leak (glowing seams and a wisp of smoke): [oven, side (+1 coke, -1 pusher), heat 0..1, left
## length, right length], the same for a seed every time.
static func leaking_doors(ovens := 50, seed_v := 3) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 104729 + ovens * 31
	var out: Array = []
	var used := {}
	var n: int = maxi(2, int(round(float(ovens) * 0.14)))
	for k in range(n):
		var i := rng.randi_range(0, ovens - 1)
		var s: float = 1.0 if rng.randf() < 0.62 else -1.0
		var heat := rng.randf_range(0.22, 0.62)
		var ll := rng.randf_range(0.3, 3.2)
		var lr := rng.randf_range(0.3, 3.2)
		var key := "%d_%d" % [i, int(s)]
		if used.has(key):
			continue
		used[key] = true
		out.append([i, s, heat, ll, lr])
	return out


## The ovens whose ascension pipe stands open and burning (being decarbonised), the same for a seed every time.
static func burning_standpipes(ovens := 50, seed_v := 3) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + ovens * 13 + 5
	var out: Array = []
	for k in range(maxi(1, ovens / 18)):
		var i := rng.randi_range(1, ovens - 2)
		if not out.has(i):
			out.append(i)
	return out


## Where the battery smokes and burns, in its frame (life metres): [kind, position, strength 0..1].
##   "door_smoke"      a wisp off a leaking door's top (its seams glow): drifting up the face
##   "standpipe_fire"  a flame over an open ascension pipe (yellow-orange, about 1.5m tall)
##   "top_haze"        a thin haze off the battery top every few ovens
##   "push_smoke"      (with open_oven) dense smoke and glow out of the open oven's coke side
static func battery_fx_spots(ovens := 50, seed_v := 3, open_oven := -1) -> Array:
	var out: Array = []
	for d in leaking_doors(ovens, seed_v):
		var s: float = d[1]
		var top: float = 8.95 if s > 0.0 else 8.92
		out.append(["door_smoke", Vector3(oven_x(d[0]), top + 0.2, s * (DOOR_Z + 0.2)), d[2]])
	for i in burning_standpipes(ovens, seed_v):
		out.append(["standpipe_fire", Vector3(oven_x(i), TOP_Y + 4.35, ASC_Z), 1.0])
	for i in range(2, ovens, 7):
		out.append(["top_haze", Vector3(oven_x(i), TOP_Y + 0.4, 0.0), 0.4])
	if open_oven >= 0 and open_oven < ovens:
		out.append(["push_smoke", Vector3(oven_x(open_oven), CHAMBER_TOP + 0.4, FRAME_Z + 0.4), 1.0])
	return out


## The quench tower's steam: where the generator's big burst comes out (the top of its chimney), in its frame.
static func quench_steam_point() -> Vector3:
	return Vector3(0, 43.4, 0)


## The emergency flare's flame (the tip's top), in gas_flare's frame.
static func flare_point() -> Vector3:
	return Vector3(0, 30.45, 0)


## Where gas_flare's knock-out drum takes its pipe (the nozzle's end, pointing +x; radius 0.3), in its frame.
static func flare_inlet() -> Vector3:
	return Vector3(7.6, 1.6, 0)


## The coal tower's conveyor gallery stub: [the middle of its open (closed off) end, direction it falls away along,
## cross-section (width, height)] in coal_tower's frame, for a gallery from the coal washer to continue.
static func coal_tower_gallery_end() -> Array:
	var d := Vector3(-cos(deg_to_rad(12.0)), -sin(deg_to_rad(12.0)), 0.0)
	return [Vector3(-6.75, 43.45, 0) + d * 9.7, d, Vector2(3.2, 2.9)]


## The by-product plant's gas inlet (the crossover main from the battery ends here, pointing -x; radius 0.75) and its
## clean-gas outlet (pointing +x; radius 0.45), in its frame.
static func byproduct_gas_inlet() -> Vector3:
	return Vector3(-42.0, 10.5, 22.0)


static func byproduct_gas_outlet() -> Vector3:
	return Vector3(42.0, 7.2, 4.0)


## Steam and smoke over the by-product plant: [kind, position, strength], in its frame.
static func byproduct_fx_spots() -> Array:
	return [["steam", Vector3(-34.0, 12.4, -1.0), 0.8], ["steam", Vector3(39.0, 27.6, 17.0), 0.25], ["smoke", Vector3(2.0, 32.5, 27.0), 0.35]]


## Steam off the freshly dumped coke on the wharf (in its frame).
static func wharf_steam_spots(length := 60.0) -> Array:
	var out: Array = []
	for c in _wharf_heaps(length):
		var t: float = c[1]
		out.append(["steam", Vector3(c[0], lerpf(5.9, 1.1, t) + 1.4, lerpf(0.0, -9.0, t)), 0.5])
	return out


## The quench car's steam/smoke over its load (in the track's frame), when it carries one.
static func quench_car_fx_spots(load := 1) -> Array:
	if load <= 0:
		return []
	return [["glow_smoke" if load == 1 else "steam", Vector3(0, 4.6, 0), 1.0]]


# ======================================================================================
#  Helpers
# ======================================================================================

## Axis-aligned block between two corners, UVs in metres.
static func _blk(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color) -> void:
	pk.block(kit, key, Vector3(minf(lo.x, hi.x), minf(lo.y, hi.y), minf(lo.z, hi.z)), Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z)), col, uvk)


## The same without its bottom (it stands on something).
static func _blk_nb(pk: PropKit, kit: Dictionary, key: String, lo: Vector3, hi: Vector3, col: Color) -> void:
	var a := Vector3(minf(lo.x, hi.x), minf(lo.y, hi.y), minf(lo.z, hi.z))
	var b := Vector3(maxf(lo.x, hi.x), maxf(lo.y, hi.y), maxf(lo.z, hi.z))
	pk.box(kit, key, Transform3D(Basis(), (a + b) * 0.5), b - a, col, uvk, true)


static func _box(pk: PropKit, kit: Dictionary, key: String, c: Vector3, basis: Basis, size: Vector3, col: Color) -> void:
	pk.box(kit, key, Transform3D(basis, c), size, col, uvk)


## A vertical quad (wall) from a to b (their y ignored) between y0 and y1 facing `out`, UVs in metres.
static func _wall(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, y0: float, y1: float, col: Color, out: Vector3) -> void:
	var l := Vector2(b.x - a.x, b.z - a.z).length()
	pk.quad(kit, key, [Vector3(a.x, y0, a.z), Vector3(b.x, y0, b.z), Vector3(b.x, y1, b.z), Vector3(a.x, y1, a.z)], out, col,
			[Vector2(0, y0) * uvk, Vector2(l, y0) * uvk, Vector2(l, y1) * uvk, Vector2(0, y1) * uvk])


## A rail head along x from x0 to x1 at z, its running surface at y (bright), its sides and underside `hh` deep.
static func _rail_head(pk: PropKit, kit: Dictionary, x0: float, x1: float, z: float, y: float, hw := 0.036, hh := 0.045) -> void:
	pk.quad(kit, "railtop", [Vector3(x0, y, z - hw), Vector3(x1, y, z - hw), Vector3(x1, y, z + hw), Vector3(x0, y, z + hw)], Vector3.UP, Color(0.66, 0.65, 0.63))
	for sd in [-1.0, 1.0]:
		pk.quad(kit, "rail", [Vector3(x0, y - hh, z + sd * hw), Vector3(x1, y - hh, z + sd * hw), Vector3(x1, y, z + sd * hw), Vector3(x0, y, z + sd * hw)], Vector3(0, 0, sd), RAIL_COL.lightened(0.06))
	pk.quad(kit, "rail", [Vector3(x0, y - hh, z - hw), Vector3(x1, y - hh, z - hw), Vector3(x1, y - hh, z + hw), Vector3(x0, y - hh, z + hw)], Vector3.DOWN, RAIL_COL.darkened(0.2))
	for e in [[x0, -1.0], [x1, 1.0]]:
		var x: float = e[0]
		pk.quad(kit, "rail", [Vector3(x, y - hh, z - hw), Vector3(x, y - hh, z + hw), Vector3(x, y, z + hw), Vector3(x, y, z - hw)], Vector3(e[1], 0, 0), RAIL_COL)


## A crane rail along x on a base at y0, its running surface at y1: foot plate, web, head.
static func _crane_rail(pk: PropKit, kit: Dictionary, x0: float, x1: float, z: float, y0: float, y1: float) -> void:
	_blk(pk, kit, "rail", Vector3(x0, y0, z - 0.09), Vector3(x1, y0 + 0.024, z + 0.09), RAIL_COL.darkened(0.15))
	_blk(pk, kit, "rail", Vector3(x0 + 0.01, y0 + 0.02, z - 0.02), Vector3(x1 - 0.01, y1 - 0.045, z + 0.02), RAIL_COL)
	_rail_head(pk, kit, x0 + 0.01, x1 - 0.01, z, y1, 0.04, 0.045)


## A wheel on an axle along `axis` (unit), radius r, tread width w, a flange on the `flange` side (+1 / -1 along axis).
static func _wheel(pk: PropKit, kit: Dictionary, c: Vector3, axis: Vector3, r: float, w: float, flange := 0.0, segs := 10) -> void:
	pk.tube(kit, "steel", c - axis * (w * 0.5), c + axis * (w * 0.5), r, r, segs, WHEEL, true)
	if flange != 0.0:
		var fc: Vector3 = c + axis * (flange * (w * 0.5 + 0.012))
		pk.tube(kit, "steel", fc - axis * 0.012, fc + axis * 0.012, r + 0.035, r + 0.035, segs, WHEEL.darkened(0.15), true)
	# The hub, standing out of the outer face.
	var hc: Vector3 = c - axis * (flange * (w * 0.5 + 0.03)) if flange != 0.0 else c + axis * (w * 0.5 + 0.03)
	pk.tube(kit, "steel", hc - axis * 0.03, hc + axis * 0.03, r * 0.32, r * 0.32, 6, STEEL_DARK, true)


## A light guard rail along a polyline: posts every `spacing`, a top rail and a knee rail.
static func _rail_line(pk: PropKit, kit: Dictionary, pts: Array, h := 1.1, col := STEEL_DARK, key := "steel", spacing := 2.0) -> void:
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n: int = maxi(int(ceil(a.distance_to(b) / spacing)), 1)
		for k in range(n + 1):
			if k == 0 and i > 0:
				continue
			if k == n and i == pts.size() - 2 and (pts[0] as Vector3).distance_to(b) < 0.01:
				continue
			var p: Vector3 = a.lerp(b, float(k) / float(n))
			pk.beam(kit, key, p, p + Vector3.UP * h, 0.05, 0.05, col)
		var a2: Vector3 = a + (b - a).normalized() * 0.031 if i > 0 else a
		var b2: Vector3 = b
		if i == pts.size() - 2 and (pts[0] as Vector3).distance_to(b) < 0.01:
			b2 = b - (b - a).normalized() * 0.031
		pk.beam(kit, key, a2 + Vector3.UP * h, b2 + Vector3.UP * h, 0.06, 0.05, col)
		pk.beam(kit, key, a2 + Vector3.UP * (h * 0.52), b2 + Vector3.UP * (h * 0.52), 0.045, 0.04, col)


## A ring walkway round a vertical cylinder: a grating annulus from r0 to r1 at y (its top), brackets, a light railing.
static func _ring_walk(pk: PropKit, kit: Dictionary, c: Vector3, r0: float, r1: float, segs: int, col := STEEL_DARK, rail := true) -> void:
	pk.lathe(kit, "steel", c, [Vector2(r1, -0.1), Vector2(r1, 0.0), Vector2(r0, 0.0)], segs, col, true)
	pk.lathe(kit, "steel", c, [Vector2(r0, -0.1), Vector2(r1, -0.1)], segs, col.darkened(0.3), true)
	for k in range(0, segs, 3):
		var a: float = TAU * float(k) / float(segs)
		var d := Vector3(cos(a), 0, sin(a))
		pk.beam(kit, "steel", c + d * r0 + Vector3(0, -0.1, 0), c + d * (r0 + (r1 - r0) * 0.2) + Vector3(0, -1.0, 0), 0.08, 0.08, col)
	if rail:
		var pts: Array = []
		for k in range(segs + 1):
			var a2: float = TAU * float(k) / float(segs)
			pts.append(c + Vector3(cos(a2) * (r1 - 0.05), 0.0, sin(a2) * (r1 - 0.05)))
		_rail_line(pk, kit, pts, 1.05, col, "steel", 99.0)


## A plain ladder (two rails, rungs every `step`) from base to top on a face looking `out`, standing 0.14 off it.
static func _ladder(pk: PropKit, kit: Dictionary, base: Vector3, top: Vector3, out: Vector3, step := 0.42, col := STEEL_DARK) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var stand: Vector3 = out * 0.14
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", base + across * (sx * 0.22) + stand, top + across * (sx * 0.22) + stand + Vector3.UP * 0.9, 0.05, 0.05, col)
	var n: int = int((top.y - base.y) / step)
	for k in range(1, n + 1):
		var p: Vector3 = base.lerp(top, float(k) / float(n + 1)) + stand
		pk.beam(kit, "steel", p - across * 0.22, p + across * 0.22, 0.03, 0.03, col)


## A clad box (machine house, head house): walls of `key` (UVs in metres, u along, v up) round x0..x1, z0..z1 from y0 to
## y1, with openings per face: faces {"pz": [[Rect2(u, y, w, h), kind], ...], "nz", "px", "nx"}; u runs along +x on the z
## faces and along +z on the x faces, from the face's low corner. kind "win" (glazing and a steel frame), "door" (a dark
## leaf set in), "open" (nothing). Corner trims cover the joints.
static func _clad_box(pk: PropKit, kit: Dictionary, key: String, x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, col: Color,
		faces: Dictionary, thick := 0.08, trim := STEEL_DARK) -> void:
	var defs: Array = [
		["pz", Vector3(x0, 0, z1), Vector3(1, 0, 0), Vector3(0, 0, 1), x1 - x0],
		["nz", Vector3(x0, 0, z0), Vector3(1, 0, 0), Vector3(0, 0, -1), x1 - x0],
		["px", Vector3(x1, 0, z0), Vector3(0, 0, 1), Vector3(1, 0, 0), z1 - z0],
		["nx", Vector3(x0, 0, z0), Vector3(0, 0, 1), Vector3(-1, 0, 0), z1 - z0],
	]
	for d in defs:
		var holes: Array = []
		var list: Array = faces.get(d[0], [])
		for h in list:
			holes.append([h[0], true])
		var p0: Vector3 = d[1]
		var along: Vector3 = d[2]
		var out: Vector3 = d[3]
		SteelworksKit._wall_holes(pk, kit, key, p0, along, out, 0.0, d[4], y0, y1, holes, col, thick, "steel")
		for h in list:
			var r: Rect2 = h[0]
			var c: Vector3 = p0 + along * (r.position.x + r.size.x * 0.5) + Vector3.UP * (r.position.y + r.size.y * 0.5)
			match String(h[1]):
				"win":
					SteelworksKit._glazing(pk, kit, c - out * 0.05, along, Vector3.UP, out, r.size.x, r.size.y)
					SteelworksKit._window_frame(pk, kit, c, along, out, r.size.x, r.size.y, trim, 1 if r.size.x > 1.2 else 0, 1)
				"door":
					var b := Basis(along, Vector3.UP, out)
					_box(pk, kit, "paint", c - out * 0.04, b, Vector3(r.size.x, r.size.y, 0.05), col.darkened(0.45))
					_box(pk, kit, "steel", c - out * 0.0 + along * (r.size.x * 0.32) + Vector3(0, -0.1, 0), b, Vector3(0.05, 0.25, 0.05), STEEL)
	# Corner trims stand outward from the corner (inward they would share the walls' inner planes).
	for cx in [x0, x1]:
		for cz in [z0, z1]:
			var ox: float = 1.0 if cx > (x0 + x1) * 0.5 else -1.0
			var oz: float = 1.0 if cz > (z0 + z1) * 0.5 else -1.0
			_blk(pk, kit, "steel", Vector3(cx - ox * 0.05, y0, cz - oz * 0.05), Vector3(cx + ox * 0.09, y1, cz + oz * 0.09), trim)


## A flat roof slab with a small overhang over x0..x1, z0..z1 at y.
static func _flat_roof(pk: PropKit, kit: Dictionary, x0: float, x1: float, z0: float, z1: float, y: float, over := 0.15, t := 0.22, col := ROOF_COL) -> void:
	_blk(pk, kit, "roofing", Vector3(x0 - over, y, z0 - over), Vector3(x1 + over, y + t, z1 + over), col)


## A cab: a lower panel block, corner posts, glazing on the faces in `glazed` ("pz", "nz", "px", "nx"), a roof.
static func _cab(pk: PropKit, kit: Dictionary, x0: float, x1: float, z0: float, z1: float, y0: float, ysill: float, yhead: float, y1: float, col: Color,
		glazed: Array, key := "paint") -> void:
	_blk(pk, kit, key, Vector3(x0, y0, z0), Vector3(x1, ysill, z1), col)
	var pw := 0.1
	for cx in [x0, x1]:
		for cz in [z0, z1]:
			var sx: float = 1.0 if cx > (x0 + x1) * 0.5 else -1.0
			var sz: float = 1.0 if cz > (z0 + z1) * 0.5 else -1.0
			_blk(pk, kit, key, Vector3(cx, ysill, cz), Vector3(cx - sx * pw, yhead, cz - sz * pw), col.darkened(0.1))
	_blk(pk, kit, key, Vector3(x0 - 0.08, yhead, z0 - 0.08), Vector3(x1 + 0.08, y1, z1 + 0.08), col.darkened(0.25))
	var h: float = yhead - ysill
	var cy: float = (ysill + yhead) * 0.5
	for g in glazed:
		match String(g):
			"pz":
				SteelworksKit._glazing(pk, kit, Vector3((x0 + x1) * 0.5, cy, z1 - 0.04), Vector3(1, 0, 0), Vector3.UP, Vector3(0, 0, 1), x1 - x0 - pw * 2.0, h)
			"nz":
				SteelworksKit._glazing(pk, kit, Vector3((x0 + x1) * 0.5, cy, z0 + 0.04), Vector3(1, 0, 0), Vector3.UP, Vector3(0, 0, -1), x1 - x0 - pw * 2.0, h)
			"px":
				SteelworksKit._glazing(pk, kit, Vector3(x1 - 0.04, cy, (z0 + z1) * 0.5), Vector3(0, 0, 1), Vector3.UP, Vector3(1, 0, 0), z1 - z0 - pw * 2.0, h)
			"nx":
				SteelworksKit._glazing(pk, kit, Vector3(x0 + 0.04, cy, (z0 + z1) * 0.5), Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0), z1 - z0 - pw * 2.0, h)


## A prism of a polygon in the z-y plane (Vector2(z, y), any winding) from x0 to x1: both caps and the rim, UVs in metres.
static func _prism_x(pk: PropKit, kit: Dictionary, key: String, poly: PackedVector2Array, x0: float, x1: float, col: Color) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	for side in [0, 1]:
		var x: float = x0 if side == 0 else x1
		var n := Vector3(-1, 0, 0) if side == 0 else Vector3(1, 0, 0)
		for i in range(0, tris.size(), 3):
			var a: Vector2 = poly[tris[i]]
			var b: Vector2 = poly[tris[i + 1]]
			var c: Vector2 = poly[tris[i + 2]]
			pk.tri(kit, key, Vector3(x, a.y, a.x), Vector3(x, b.y, b.x), Vector3(x, c.y, c.x), n, n, n, col, n, a * uvk, b * uvk, c * uvk)
	var ccw := PropKit._signed_area(poly) > 0.0
	for i in range(poly.size()):
		var p: Vector2 = poly[i]
		var q: Vector2 = poly[(i + 1) % poly.size()]
		var e: Vector2 = q - p
		if e.length_squared() < 1e-8:
			continue
		var o2: Vector2 = Vector2(e.y, -e.x).normalized() if ccw else Vector2(-e.y, e.x).normalized()
		var o3 := Vector3(0, o2.y, o2.x)
		var l: float = e.length()
		pk.quad(kit, key, [Vector3(x0, p.y, p.x), Vector3(x1, p.y, p.x), Vector3(x1, q.y, q.x), Vector3(x0, q.y, q.x)], o3, col,
				[Vector2(0, 0), Vector2((x1 - x0) * uvk, 0), Vector2((x1 - x0) * uvk, l * uvk), Vector2(0, l * uvk)])


## A slat (louvre board) centred at c, `length` along `along` (unit, horizontal), `depth` deep toward `out` and tipped down
## by `tilt` radians at its outer edge, `thick` thick.
static func _slat(pk: PropKit, kit: Dictionary, key: String, c: Vector3, along: Vector3, out: Vector3, length: float, depth: float, thick: float, tilt: float, col: Color) -> void:
	var zx: Vector3 = (out * cos(tilt) - Vector3.UP * sin(tilt)).normalized()
	var yx: Vector3 = zx.cross(along).normalized()
	_box(pk, kit, key, c, Basis(along, yx, zx), Vector3(length, thick, depth), col)


## A soot-painted quad: the vertex colours' alpha says how sooted each corner is (kokerei_soot.gdshader).
static func _soot_quad(pk: PropKit, kit: Dictionary, key: String, p: Array, n: Vector3, col: Color, alphas: Array) -> void:
	var c0 := Color(col.r, col.g, col.b, alphas[0])
	var c1 := Color(col.r, col.g, col.b, alphas[1])
	var c2 := Color(col.r, col.g, col.b, alphas[2])
	var c3 := Color(col.r, col.g, col.b, alphas[3])
	# PropKit.tri takes one colour per triangle: split each quad into four around its middle so the corners keep theirs.
	var m: Vector3 = (p[0] + p[1] + p[2] + p[3]) * 0.25
	var am: float = (float(alphas[0]) + float(alphas[1]) + float(alphas[2]) + float(alphas[3])) * 0.25
	var cm := Color(col.r, col.g, col.b, am)
	var cs: Array = [c0, c1, c2, c3]
	for i in range(4):
		var a: Vector3 = p[i]
		var b: Vector3 = p[(i + 1) % 4]
		_tri_cols(pk, kit, key, a, b, m, n, cs[i], cs[(i + 1) % 4], cm)


## One triangle with a colour per corner (PropKit.tri sets one), wound to face `n`.
static func _tri_cols(pk: PropKit, kit: Dictionary, key: String, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var s: SurfaceTool = pk.st(kit, key)
	var wa: Vector3 = pk.xf * a
	var wb: Vector3 = pk.xf * b
	var wc: Vector3 = pk.xf * c
	var wn: Vector3 = (pk.xf.basis.inverse().transposed() * n).normalized()
	if (wc - wa).cross(wb - wa).dot(wn) < 0.0:
		var t := wb
		wb = wc
		wc = t
		var tc := cb
		cb = cc
		cc = tc
	for v in [[wa, ca], [wb, cb], [wc, cc]]:
		s.set_color(v[1])
		s.set_normal(wn)
		s.set_uv(Vector2.ZERO)
		s.add_vertex(v[0])


## A heightfield-like surface over a grid of points (grid[i][k]), smooth normals (facing `up_hint`), a colour per point;
## `keep` (optional) says whether cell (i, k) is drawn.
static func _grid_surface(pk: PropKit, kit: Dictionary, key: String, grid: Array, cols: Array, up_hint: Vector3, keep := Callable()) -> void:
	var ni: int = grid.size()
	var nk: int = (grid[0] as Array).size()
	var norms: Array = []
	for i in range(ni):
		var row: Array = []
		for k in range(nk):
			var dx: Vector3 = (grid[mini(i + 1, ni - 1)][k] as Vector3) - (grid[maxi(i - 1, 0)][k] as Vector3)
			var dz: Vector3 = (grid[i][mini(k + 1, nk - 1)] as Vector3) - (grid[i][maxi(k - 1, 0)] as Vector3)
			var n: Vector3 = dx.cross(dz).normalized()
			if n.dot(up_hint) < 0.0:
				n = -n
			row.append(n)
		norms.append(row)
	var s: SurfaceTool = pk.st(kit, key)
	var nb: Basis = pk.xf.basis.inverse().transposed()
	for i in range(ni - 1):
		for k in range(nk - 1):
			if keep.is_valid() and not keep.call(i, k):
				continue
			for t in [[[i, k], [i + 1, k], [i + 1, k + 1]], [[i, k], [i + 1, k + 1], [i, k + 1]]]:
				var ids: Array = t
				var ps: Array = []
				var ns: Array = []
				var cs: Array = []
				for id in ids:
					ps.append(pk.xf * (grid[id[0]][id[1]] as Vector3))
					ns.append((nb * (norms[id[0]][id[1]] as Vector3)).normalized())
					cs.append(cols[id[0]][id[1]])
				var fo: Vector3 = (ns[0] + ns[1] + ns[2])
				if ((ps[2] as Vector3) - ps[0]).cross((ps[1] as Vector3) - ps[0]).dot(fo) < 0.0:
					var tp = ps[1]
					ps[1] = ps[2]
					ps[2] = tp
					var tn = ns[1]
					ns[1] = ns[2]
					ns[2] = tn
					var tc = cs[1]
					cs[1] = cs[2]
					cs[2] = tc
				for v in range(3):
					s.set_color(cs[v])
					s.set_normal(ns[v])
					s.set_uv(Vector2.ZERO)
					s.add_vertex(ps[v])


# ======================================================================================
#  The coke oven battery
# ======================================================================================

## Batterie `number`: `ovens` chambers between two brick end walls along x (see the header for the frame). Both faces carry
## oven doors (heavy cast steel in frames, two latch bars hooked onto the frame; on the pusher side a leveller door at the
## top) between buckstays tied across the top; under them the regenerator wall with its inspection doors and the heating
## gas main; a bench along each side (the coke side's wider, carrying the guide car's rails, on columns). On top: charging
## holes in four rows, inspection caps over the heating walls, the larry car's rails, an ascension pipe per oven with its
## gooseneck into the gas collecting main on the pusher side. Some doors leak (glowing seams), a pipe or two burns open.
## With `open_oven` that oven's doors are off and its chamber glows (the guide car and pusher at it, the push under way).
static func coke_battery(pk: PropKit, kit: Dictionary, labels: Array, ovens := 50, number := 3, seed_v := 3, open_oven := -1) -> void:
	ovens = maxi(ovens, 4)
	var L: float = battery_length(ovens)
	var leaks: Array = leaking_doors(ovens, seed_v)
	var fires: Array = burning_standpipes(ovens, seed_v)
	_battery_body(pk, kit, L)
	_battery_ends(pk, kit, labels, L, number)
	_battery_benches(pk, kit, ovens, L)
	for j in range(ovens + 1):
		_heating_wall(pk, kit, j, ovens)
	for i in range(ovens):
		var ox: float = oven_x(i)
		for s in [-1.0, 1.0]:
			var leak: Array = []
			for d in leaks:
				if int(d[0]) == i and float(d[1]) == s:
					leak = d
			_oven_door(pk, kit, ox, s, leak, i == open_oven)
			_regen_front(pk, kit, ox, s)
		_oven_top(pk, kit, ox, fires.has(i))
		if i % 5 == 4:
			SteelworksKit._label(labels, str(number * 100 + i + 1), Vector3(ox, 9.33, FACE_Z + 0.06), Vector3(0, 0, 1), 0.2, CREAM, 0.8)
	_gas_main(pk, kit, ovens, L)
	_battery_rails(pk, kit, L)
	_battery_stairs(pk, kit, L)


static func _battery_body(pk: PropKit, kit: Dictionary, L: float) -> void:
	# The foundation, its top a 0.3m base course in front of the regenerator walls.
	_blk(pk, kit, "concrete", Vector3(-0.3, -2.0, -7.45), Vector3(L + 0.3, 0.3, 7.45), CONC_DARK)
	for s in [-1.0, 1.0]:
		var z: float = s * FACE_Z
		# The brick faces: the regenerator wall below, the band over the doors; the armour plates cover the oven heads.
		_wall(pk, kit, "brick", Vector3(END_W - 0.3, 0, z), Vector3(L - END_W + 0.3, 0, z), 0.3, TOP_Y, BRICK, Vector3(0, 0, s))
		_blk(pk, kit, "grime", Vector3(END_W, 4.0, s * 6.95), Vector3(L - END_W, 9.0, s * 7.04), ARMOUR)
		# The top's edge: a cast-iron coping angle standing 7cm over the top.
		_blk(pk, kit, "steel", Vector3(0.6, TOP_Y - 0.12, s * 6.9), Vector3(L - 0.6, TOP_Y + 0.07, s * 7.08), CAST)
	# The top: brick paving black with coal dust and tar (soot by the vertex alpha: patchy).
	var tz := 6.9
	var nseg: int = maxi(int(L / 12.0), 1)
	for k in range(nseg):
		var xa: float = lerpf(0.45, L - 0.45, float(k) / float(nseg))
		var xb: float = lerpf(0.45, L - 0.45, float(k + 1) / float(nseg))
		_soot_quad(pk, kit, "soot", [Vector3(xa, TOP_Y, -tz), Vector3(xb, TOP_Y, -tz), Vector3(xb, TOP_Y, tz), Vector3(xa, TOP_Y, tz)], Vector3.UP, SOOT_TOP,
				[0.85, 0.85, 0.55, 0.55])


static func _battery_ends(pk: PropKit, kit: Dictionary, labels: Array, L: float, number: int) -> void:
	for e in [0, 1]:
		var xo: float = 0.0 if e == 0 else L
		var sx: float = -1.0 if e == 0 else 1.0
		var xf: float = xo - sx * 0.45
		var xi: float = xo - sx * (END_W + 0.25)
		# The wall: brick, its top just under the battery's paving in the middle, a parapet over the outer bands.
		_blk(pk, kit, "brick", Vector3(xf, -0.5, -7.8), Vector3(xi, TOP_Y - 0.03, 7.8), BRICK)
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "brick", Vector3(xf, TOP_Y - 0.03, sz * 5.8), Vector3(xi, TOP_Y + 0.9, sz * 7.8), BRICK)
			_blk(pk, kit, "brick", Vector3(xo, -0.5, sz * 6.6), Vector3(xf - sx * 0.1, TOP_Y + 1.0, sz * 7.85), BRICK_DARK)
			_blk(pk, kit, "steel", Vector3(xf, TOP_Y + 0.9, sz * 5.75), Vector3(xi, TOP_Y + 0.98, sz * 7.82), CAST)
		# The refractory field between the piers: pale firebrick standing 7cm out of the wall.
		_blk(pk, kit, "brick", Vector3(xf + sx * 0.07, 3.2, -5.6), Vector3(xf - sx * 0.05, TOP_Y - 0.6, 5.6), FIREBRICK)
		# Steel binders holding the end wall: two uprights, two horizontals across.
		for zb in [-6.15, 6.15]:
			SteelworksKit._ibeam(pk, kit, "steel", Vector3(xf + sx * 0.2, -0.3, zb), Vector3(xf + sx * 0.2, TOP_Y + 0.8, zb), 0.36, 0.3, BUCK, Vector3(sx, 0, 0), 0.04, 0.04)
		for yb in [3.5, TOP_Y - 0.25]:
			SteelworksKit._ibeam(pk, kit, "steel", Vector3(xf + sx * 0.26, yb, -6.45), Vector3(xf + sx * 0.26, yb, 6.45), 0.3, 0.28, BUCK, Vector3(sx, 0, 0), 0.04, 0.04)
		# The battery's number on an enamel board.
		_blk(pk, kit, "paint", Vector3(xf + sx * 0.10, 7.2, -4.9), Vector3(xf + sx * 0.14, 8.85, 4.9), BOARD)
		SteelworksKit._label(labels, "BATTERIE %d" % number, Vector3(xf + sx * 0.16, 8.02, 0.0), Vector3(sx, 0, 0), 0.62, CREAM, 9.4)


static func _battery_benches(pk: PropKit, kit: Dictionary, ovens: int, L: float) -> void:
	# Pusher side: a cantilevered slab with a toe kerb, on brackets from the buckstays.
	_blk(pk, kit, "floor", Vector3(-0.06, 3.95, -BENCH_IN), Vector3(L + 2.4, BENCH_Y, -PUSH_BENCH_OUT), BENCH_COL)
	_blk(pk, kit, "paint", Vector3(-0.04, BENCH_Y - 0.02, -PUSH_BENCH_OUT + 0.06), Vector3(L + 2.38, BENCH_Y + 0.1, -PUSH_BENCH_OUT - 0.02), KERB)
	# Coke side: wider, the guide car's rails on it, its outer edge on a beam and columns.
	_blk(pk, kit, "floor", Vector3(-0.06, 3.95, BENCH_IN), Vector3(L + 1.2, BENCH_Y, COKE_BENCH_OUT), BENCH_COL)
	_blk(pk, kit, "paint", Vector3(-0.04, BENCH_Y - 0.02, COKE_BENCH_OUT - 0.06), Vector3(L + 1.18, BENCH_Y + 0.1, COKE_BENCH_OUT + 0.02), KERB)
	_blk(pk, kit, "sootcrete", Vector3(0.0, 3.35, 11.1), Vector3(L + 1.2, 3.95, 11.76), Color(CONC_DARK.r, CONC_DARK.g, CONC_DARK.b, 0.55))
	var cols: Array = [0.32, L + 0.88]
	for i in range(1, ovens, 4):
		cols.append(oven_x(i))
	for x in cols:
		_blk(pk, kit, "sootcrete", Vector3(x - 0.28, -0.6, 11.16), Vector3(x + 0.28, 3.36, 11.72), Color(CONC_DARK.r, CONC_DARK.g, CONC_DARK.b, 0.45))
	for j in range(ovens + 1):
		var xw: float = wall_x(j)
		pk.beam(kit, "steel", Vector3(xw, 2.7, -7.6), Vector3(xw, 3.92, -9.1), 0.14, 0.14, BUCK)
		pk.beam(kit, "steel", Vector3(xw, 3.885, -7.6), Vector3(xw, 3.885, -9.3), 0.13, 0.13, BUCK)
		pk.beam(kit, "steel", Vector3(xw, 2.7, 7.6), Vector3(xw, 3.92, 9.6), 0.14, 0.14, BUCK)
		pk.beam(kit, "steel", Vector3(xw, 3.885, 7.6), Vector3(xw, 3.885, 11.08), 0.13, 0.13, BUCK)
	# Railings across the bench ends at the coal tower's end.
	_rail_line(pk, kit, [Vector3(0.06, BENCH_Y, -BENCH_IN - 0.05), Vector3(0.06, BENCH_Y, -PUSH_BENCH_OUT + 0.08)], 1.1, CRANE_YELLOW, "paint")
	_rail_line(pk, kit, [Vector3(0.06, BENCH_Y, BENCH_IN + 0.05), Vector3(0.06, BENCH_Y, COKE_BENCH_OUT - 0.08)], 1.1, CRANE_YELLOW, "paint")
	# The battery top's railing along the coke edge.
	_rail_line(pk, kit, [Vector3(0.6, TOP_Y + 0.07, 6.99), Vector3(L - 0.6, TOP_Y + 0.07, 6.99)], 1.05, STEEL_DARK, "steel", PITCH * 2.0)


## Heating wall j: the buckstays on both faces, the tie rod across the top with its spring packs, inspection caps.
static func _heating_wall(pk: PropKit, kit: Dictionary, j: int, ovens: int) -> void:
	var xw: float = wall_x(j)
	for s in [-1.0, 1.0]:
		SteelworksKit._ibeam(pk, kit, "steel", Vector3(xw, 0.3, s * 7.35), Vector3(xw, TOP_Y + 1.0, s * 7.35), 0.62, 0.32, BUCK, Vector3(0, 0, 1), 0.05, 0.05)
		pk.beam(kit, "rusty", Vector3(xw, TOP_Y + 0.04, s * 6.5), Vector3(xw, TOP_Y + 0.8, s * 7.95), 0.07, 0.07, CAST)
		_blk(pk, kit, "steel", Vector3(xw - 0.17, TOP_Y + 0.6, s * 7.69), Vector3(xw + 0.17, TOP_Y + 0.94, s * 7.98), SPRING)
		_blk(pk, kit, "steel", Vector3(xw - 0.1, TOP_Y + 0.68, s * 7.98), Vector3(xw + 0.1, TOP_Y + 0.86, s * 8.08), CAST)
	pk.beam(kit, "rusty", Vector3(xw, TOP_Y + 0.04, -6.55), Vector3(xw, TOP_Y + 0.04, 6.55), 0.07, 0.07, CAST)
	if j == 0 or j == ovens:
		return
	for z in [-5.0, -2.4, 0.0, 2.4, 5.0]:
		_blk_nb(pk, kit, "steel", Vector3(xw + 0.17, TOP_Y, z - 0.12), Vector3(xw + 0.41, TOP_Y + 0.07, z + 0.12), CAST)


## An oven's door on one face (s = +1 the coke side, -1 the pusher side): the frame in the brickwork, the door (ribs, two
## latch bars in hooks on the frame, lifting lugs; on the pusher side a leveller door over it), its seams glowing if it
## leaks. `open`: no door, the chamber glowing in the frame.
static func _oven_door(pk: PropKit, kit: Dictionary, ox: float, s: float, leak: Array, open: bool) -> void:
	var zb: float = s * 7.03
	var zf: float = s * FRAME_Z
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "steel", Vector3(ox + sx * 0.355, 4.1, zb), Vector3(ox + sx * 0.475, 9.0, zf), FRAME_COL)
	_blk(pk, kit, "steel", Vector3(ox - 0.475, 9.0, zb), Vector3(ox + 0.475, 9.18, zf), FRAME_COL)
	_blk(pk, kit, "steel", Vector3(ox - 0.475, 3.98, zb), Vector3(ox + 0.475, 4.1, zf), FRAME_COL)
	if open:
		# The coke cake's end, glowing yellow-orange, a little inside the chamber; its jambs glowing dull red.
		pk.quad(kit, "hot", [Vector3(ox - 0.355, 4.1, s * 7.1), Vector3(ox + 0.355, 4.1, s * 7.1), Vector3(ox + 0.355, 9.0, s * 7.1), Vector3(ox - 0.355, 9.0, s * 7.1)],
				Vector3(0, 0, s), SteelworksKit.hot_colour(0.72))
		for sx in [-1.0, 1.0]:
			pk.quad(kit, "hot", [Vector3(ox + sx * 0.355, 4.1, s * 7.1), Vector3(ox + sx * 0.355, 4.1, zf), Vector3(ox + sx * 0.355, 9.0, zf), Vector3(ox + sx * 0.355, 9.0, s * 7.1)],
					Vector3(-sx, 0, 0), SteelworksKit.hot_colour(0.35))
		return
	var dt: float = 8.95 if s > 0.0 else 8.05
	_blk(pk, kit, "rusty", Vector3(ox - 0.345, 4.25, zf), Vector3(ox + 0.345, dt, s * DOOR_Z), DOOR_COL)
	for rx in [-0.17, 0.17]:
		_blk(pk, kit, "rusty", Vector3(ox + rx - 0.035, 4.35, s * DOOR_Z), Vector3(ox + rx + 0.035, dt - 0.1, s * 7.56), DOOR_COL.darkened(0.12))
	var latches: Array = [5.0, dt - 0.75]
	for yl in latches:
		_blk(pk, kit, "steel", Vector3(ox - 0.5, yl - 0.08, s * 7.56), Vector3(ox + 0.5, yl + 0.08, s * 7.64), FRAME_COL.darkened(0.1))
		for sx in [-1.0, 1.0]:
			_blk(pk, kit, "steel", Vector3(ox + sx * 0.44, yl - 0.14, zf), Vector3(ox + sx * 0.52, yl + 0.14, s * 7.68), FRAME_COL)
	for lx in [-0.22, 0.22]:
		_blk(pk, kit, "steel", Vector3(ox + lx - 0.04, dt, s * 7.36), Vector3(ox + lx + 0.04, dt + 0.04, s * 7.46), FRAME_COL)
	var top: float = dt
	if s < 0.0:
		# The leveller door (Planiertür), its own latch.
		_blk(pk, kit, "rusty", Vector3(ox - 0.26, 8.13, zf), Vector3(ox + 0.26, 8.92, s * 7.46), DOOR_COL)
		_blk(pk, kit, "rusty", Vector3(ox - 0.33, 8.48, s * 7.46), Vector3(ox + 0.33, 8.58, s * 7.52), DOOR_COL.darkened(0.25))
		top = 8.92
	if leak.is_empty():
		return
	var hc: Color = SteelworksKit.hot_colour(float(leak[2]))
	var hw: float = 0.345 if s > 0.0 else 0.26
	_blk(pk, kit, "hot", Vector3(ox - hw - 0.02, top - 0.02, s * 7.29), Vector3(ox + hw + 0.02, top + 0.035, s * 7.335), hc)
	var lens: Array = [leak[3], leak[4]]
	for k in range(2):
		var sx: float = -1.0 if k == 0 else 1.0
		var l: float = minf(float(lens[k]), top - 4.4)
		_blk(pk, kit, "hot", Vector3(ox + sx * (hw - 0.01), top - l, s * 7.292), Vector3(ox + sx * (hw + 0.03), top - 0.03, s * 7.33), hc.darkened(0.15))


## Under the bench: the regenerator wall's inspection door and the oven's branch off the heating gas main.
static func _regen_front(pk: PropKit, kit: Dictionary, ox: float, s: float) -> void:
	_blk(pk, kit, "steel", Vector3(ox - 0.25, 0.9, s * 6.98), Vector3(ox + 0.25, 1.5, s * 7.07), CAST)
	_blk(pk, kit, "steel", Vector3(ox - 0.06, 1.15, s * 7.07), Vector3(ox + 0.06, 1.27, s * 7.13), STEEL)
	pk.tube(kit, "steel", Vector3(ox, 2.15, s * 7.0), Vector3(ox, 2.15, s * 7.8), 0.06, 0.06, 6, STEEL_DARK, false)
	_blk(pk, kit, "steel", Vector3(ox - 0.1, 2.04, s * 7.32), Vector3(ox + 0.1, 2.28, s * 7.46), RED.darkened(0.35))


## The top of one oven: four charging holes with their lids and clay seals, the ascension pipe with its head, lid,
## gooseneck and the valve on the collecting main. `burning`: the pipe's lid stands open and the pipe burns.
static func _oven_top(pk: PropKit, kit: Dictionary, ox: float, burning: bool) -> void:
	for z in CHARGE_Z:
		var c := Vector3(ox, TOP_Y, float(z))
		pk.lathe(kit, "matte", c, [Vector2(0.42, 0.025), Vector2(0.3, 0.04)], 6, CLAY, true)
		pk.lathe(kit, "steel", c, [Vector2(0.3, 0.02), Vector2(0.3, 0.09), Vector2(0.001, 0.13)], 6, CAST, true)
	var c2 := Vector3(ox, TOP_Y, ASC_Z)
	pk.box(kit, "rusty", Transform3D(Basis(), c2 + Vector3(0, 0.08, 0)), Vector3(0.8, 0.16, 0.8), ASC_DARK, uvk, true)
	pk.tube(kit, "rusty", c2 + Vector3(0, 0.16, 0), c2 + Vector3(0, 3.4, 0), 0.28, 0.28, 10, ASC_COL, false)
	pk.tube(kit, "rusty", c2 + Vector3(0, 1.6, 0), c2 + Vector3(0, 1.72, 0), 0.315, 0.315, 10, ASC_DARK, false)
	_blk(pk, kit, "rusty", c2 + Vector3(-0.36, 3.4, -0.36), c2 + Vector3(0.36, 4.2, 0.36), ASC_DARK)
	if burning:
		# The lid swung up on its hinge (toward +z), the pipe's mouth glowing.
		var hinge: Vector3 = c2 + Vector3(0, 4.2, 0.3)
		var lb := Basis(Vector3.RIGHT, deg_to_rad(75.0))
		_box(pk, kit, "steel", hinge + lb * Vector3(0, 0.05, -0.3), lb, Vector3(0.6, 0.1, 0.6), CAST)
		pk.quad(kit, "hot", [c2 + Vector3(-0.26, 4.23, -0.26), c2 + Vector3(0.26, 4.23, -0.26), c2 + Vector3(0.26, 4.23, 0.26), c2 + Vector3(-0.26, 4.23, 0.26)],
				Vector3.UP, SteelworksKit.hot_colour(0.8))
	else:
		_blk_nb(pk, kit, "steel", c2 + Vector3(-0.3, 4.2, -0.3), c2 + Vector3(0.3, 4.3, 0.3), CAST)
		pk.beam(kit, "steel", c2 + Vector3(0, 4.33, 0.2), c2 + Vector3(0, 4.55, 0.55), 0.06, 0.06, CAST)
	# Gooseneck into the valve box sitting on the main.
	pk.tube(kit, "rusty", c2 + Vector3(0, 3.85, -0.36), Vector3(ox, TOP_Y + 3.85, -6.62), 0.22, 0.22, 10, ASC_COL, false)
	_blk(pk, kit, "rusty", Vector3(ox - 0.34, MAIN_Y + 0.68, -7.38), Vector3(ox + 0.34, MAIN_Y + 1.62, -6.62), ASC_DARK)
	pk.beam(kit, "steel", Vector3(ox, MAIN_Y + 1.62, -7.0), Vector3(ox, MAIN_Y + 2.05, -7.0), 0.05, 0.05, CAST)
	_blk(pk, kit, "steel", Vector3(ox - 0.17, MAIN_Y + 2.02, -7.03), Vector3(ox + 0.17, MAIN_Y + 2.07, -6.97), RED.darkened(0.3))


## The gas collecting main (Vorlage) along the pusher side on frames standing on the top and the buckstays, the
## flushing liquor pipe beside it, the offtake turning toward -z past the far end on a column; the heating gas mains
## under the benches.
static func _gas_main(pk: PropKit, kit: Dictionary, ovens: int, L: float) -> void:
	SteelworksKit._pipe(pk, kit, "rusty", [Vector3(1.2, MAIN_Y, MAIN_Z), Vector3(L + 3.0, MAIN_Y, MAIN_Z), Vector3(L + 3.0, MAIN_Y, -12.0)], MAIN_R, MAIN_COL, 16, PITCH * 4.0, true)
	pk.tube(kit, "steel", Vector3(1.4, MAIN_Y + 0.55, -7.95), Vector3(L + 1.5, MAIN_Y + 0.55, -7.95), 0.08, 0.08, 8, STEEL, true)
	for j in range(2, ovens, 4):
		var xw: float = wall_x(j)
		_blk(pk, kit, "steel", Vector3(xw - 0.1, TOP_Y, -6.45), Vector3(xw + 0.1, MAIN_Y - 0.82, -6.25), BUCK)
		_blk(pk, kit, "steel", Vector3(xw - 0.1, TOP_Y + 1.0, -7.45), Vector3(xw + 0.1, MAIN_Y - 0.82, -7.25), BUCK)
		_blk(pk, kit, "steel", Vector3(xw - 0.12, MAIN_Y - 0.94, -7.6), Vector3(xw + 0.12, MAIN_Y - 0.78, -6.1), BUCK)
		_blk(pk, kit, "steel", Vector3(xw - 0.25, MAIN_Y - 0.8, -7.5), Vector3(xw + 0.25, MAIN_Y - 0.52, -6.5), STEEL_DARK)
		pk.beam(kit, "steel", Vector3(xw, MAIN_Y + 0.3, -7.6), Vector3(xw, MAIN_Y + 0.55, -7.95), 0.06, 0.06, STEEL_DARK)
	# The offtake's column past the pusher rails' end.
	_blk(pk, kit, "concrete", Vector3(L + 3.1, -1.0, -11.8), Vector3(L + 4.1, 0.2, -10.8), CONCRETE)
	_blk(pk, kit, "steel", Vector3(L + 3.35, 0.2, -11.55), Vector3(L + 3.85, MAIN_Y - 0.9, -11.05), BUCK)
	_blk(pk, kit, "steel", Vector3(L + 2.3, MAIN_Y - 0.9, -11.55), Vector3(L + 3.85, MAIN_Y - 0.65, -11.05), BUCK)
	# Heating gas mains under both benches, on short brackets off every fourth buckstay.
	for s in [-1.0, 1.0]:
		SteelworksKit._pipe(pk, kit, "rusty", [Vector3(0.7, 2.15, s * 7.95), Vector3(L - 0.7, 2.15, s * 7.95)], 0.2, PIPE_RUST, 10, PITCH * 8.0, true)
		for j in range(0, ovens + 1, 4):
			var xw2: float = wall_x(j)
			pk.beam(kit, "steel", Vector3(xw2, 1.9, s * 7.62), Vector3(xw2, 1.9, s * 8.2), 0.1, 0.1, BUCK)


static func _battery_rails(pk: PropKit, kit: Dictionary, L: float) -> void:
	# The pusher machine's track at the ground, on concrete strips, buffer stops at both ends.
	for z in PUSH_RAILS:
		var zr: float = z
		_blk(pk, kit, "concrete", Vector3(-2.0, -0.6, zr - 0.45), Vector3(L + 2.0, 0.1, zr + 0.45), CONC_DARK)
		_crane_rail(pk, kit, -2.0, L + 2.0, zr, 0.1, PUSH_RAIL_Y)
		for e in [[-2.0, 1.0], [L + 2.0, -1.0]]:
			var x: float = e[0]
			_blk(pk, kit, "paint", Vector3(x - float(e[1]) * 0.05, 0.1, zr - 0.4), Vector3(x + float(e[1]) * 0.45, 1.25, zr + 0.4), RED)
			_blk(pk, kit, "steel", Vector3(x + float(e[1]) * 0.45, 0.55, zr - 0.3), Vector3(x + float(e[1]) * 0.6, 0.95, zr + 0.3), STEEL_DARK)
	# The guide car's rails on the coke bench.
	for z in GUIDE_RAILS:
		_crane_rail(pk, kit, 0.0, L + 1.2, float(z), BENCH_Y, GUIDE_RAIL_Y)
	# The larry car's rails on the top (the coal tower carries them on past x = 0).
	for sz in [-1.0, 1.0]:
		var zl: float = sz * LARRY_RAIL_Z
		_blk(pk, kit, "concrete", Vector3(0.45, TOP_Y, zl - 0.3), Vector3(L - 0.45, TOP_Y + 0.08, zl + 0.3), CONCRETE.darkened(0.35))
		_crane_rail(pk, kit, 0.0, L - 0.45, zl, TOP_Y + 0.08, LARRY_RAIL_Y)
		_blk(pk, kit, "paint", Vector3(L - 0.95, TOP_Y + 0.08, zl - 0.35), Vector3(L - 0.6, TOP_Y + 1.0, zl + 0.35), RED)


static func _battery_stairs(pk: PropKit, kit: Dictionary, L: float) -> void:
	# From the ground up to each bench at the far end.
	SteelworksKit._stair(pk, kit, Vector3(L + 8.2, 0.0, -8.25), Vector3(L + 2.4, BENCH_Y, -8.25), 1.0, STEEL, CRANE_YELLOW)
	SteelworksKit._stair(pk, kit, Vector3(L + 7.0, 0.0, 9.5), Vector3(L + 1.2, BENCH_Y, 9.5), 1.0, STEEL, CRANE_YELLOW)
	# From the pusher bench up beside the end wall to the top, a landing over the wall's head.
	SteelworksKit._stair(pk, kit, Vector3(L + 1.2, BENCH_Y, -8.9), Vector3(L + 1.2, TOP_Y, -1.6), 1.0, STEEL, CRANE_YELLOW)
	_blk(pk, kit, "steel", Vector3(L - 0.45, TOP_Y - 0.12, -2.5), Vector3(L + 1.8, TOP_Y, -0.7), STEEL_DARK)
	for p in [Vector3(L + 1.75, 0.0, -2.45), Vector3(L + 1.75, 0.0, -0.75)]:
		_blk(pk, kit, "steel", p + Vector3(-0.07, 0.3, -0.07), p + Vector3(0.07, TOP_Y - 0.12, 0.07), STEEL)
	_rail_line(pk, kit, [Vector3(L + 1.76, TOP_Y, -1.5), Vector3(L + 1.76, TOP_Y, -0.72), Vector3(L - 0.4, TOP_Y, -0.72)], 1.1, CRANE_YELLOW, "paint")
	_rail_line(pk, kit, [Vector3(L + 0.68, BENCH_Y, -9.35), Vector3(L + 2.35, BENCH_Y, -9.35)], 1.1, CRANE_YELLOW, "paint")


# ======================================================================================
#  The machines
# ======================================================================================

## The pusher machine (Koksausdrückmaschine), in the battery's frame shifted to its oven (x 0 the ram): on two rails at
## z -10.6 and -16.6 (four two-wheel bogies), the deck, the machine house in corrugated iron, the operator's cab on its
## battery side looking at the door, the ram (the ram head at the front, its tail in a lattice boom behind the house out to
## z -27.8) and the leveller bar over it, the door extractor at x +1.45 (the next oven), a front platform at the bench's
## height, roof gear, a cable drum. Keep z -9.55..-27.8 clear along the pusher track.
static func pusher_machine(pk: PropKit, kit: Dictionary, holding_door := false) -> void:
	var col := MACHINE
	var wy: float = PUSH_RAIL_Y + 0.45
	for z in PUSH_RAILS:
		var zr: float = z
		for bx in [-3.0, 3.0]:
			for wx in [-0.8, 0.8]:
				_wheel(pk, kit, Vector3(bx + wx, wy, zr), Vector3(0, 0, 1), 0.45, 0.13, -1.0 if zr > -13.0 else 1.0)
			for sz in [-1.0, 1.0]:
				_blk(pk, kit, "steel", Vector3(bx - 1.35, 0.5, zr + sz * 0.15), Vector3(bx + 1.35, 1.25, zr + sz * 0.32), col.darkened(0.3))
			_blk(pk, kit, "steel", Vector3(bx - 1.45, 1.25, zr - 0.38), Vector3(bx + 1.45, 1.6, zr + 0.38), col.darkened(0.25))
		_blk(pk, kit, "steel", Vector3(-4.7, 1.6, zr - 0.42), Vector3(4.7, 2.05, zr + 0.42), col.darkened(0.15))
	_blk(pk, kit, "steel", Vector3(-4.85, 2.05, -17.5), Vector3(4.85, 2.4, -9.7), col.darkened(0.1))
	_blk(pk, kit, "hazard", Vector3(-4.85, 2.07, -9.7), Vector3(4.85, 2.38, -9.66), WHITE)
	# The machine house.
	var holes := {
		"pz": [[Rect2(4.1, 4.5, 1.0, 1.4), "open"], [Rect2(4.25, 7.95, 0.7, 0.85), "open"], [Rect2(7.1, 6.2, 1.5, 1.3), "win"]],
		"nz": [[Rect2(3.6, 4.5, 2.0, 4.8), "open"], [Rect2(0.9, 6.2, 1.4, 1.2), "win"], [Rect2(6.9, 6.2, 1.4, 1.2), "win"]],
		"px": [[Rect2(1.2, 6.4, 1.4, 1.2), "win"], [Rect2(3.4, 6.4, 1.4, 1.2), "win"], [Rect2(4.6, 2.4, 0.9, 2.1), "door"]],
		"nx": [[Rect2(1.2, 6.4, 1.4, 1.2), "win"], [Rect2(3.4, 6.4, 1.4, 1.2), "win"]],
	}
	_clad_box(pk, kit, "iron", -4.6, 4.6, -17.2, -11.4, 2.4, 10.0, CLAD, holes, 0.08, col.darkened(0.2))
	_flat_roof(pk, kit, -4.6, 4.6, -17.2, -11.4, 10.0, 0.18, 0.24, ROOF_COL)
	_rail_line(pk, kit, [Vector3(-4.65, 10.24, -17.25), Vector3(4.65, 10.24, -17.25), Vector3(4.65, 10.24, -11.35), Vector3(-1.2, 10.24, -11.35)], 1.0, CRANE_YELLOW, "paint", 2.4)
	for fx in [-2.2, 1.6]:
		pk.lathe(kit, "steel", Vector3(fx, 10.24, -14.6), [Vector2(0.7, 0.0), Vector2(0.7, 0.55), Vector2(0.78, 0.6), Vector2(0.001, 0.62)], 12, col.darkened(0.2), true)
	_blk(pk, kit, "paint", Vector3(-3.9, 10.24, -16.8), Vector3(-2.9, 11.2, -15.6), col.darkened(0.3))
	# Lamp mast with two floods aimed at the battery.
	pk.beam(kit, "steel", Vector3(3.9, 10.24, -11.9), Vector3(3.9, 13.0, -11.9), 0.12, 0.12, STEEL_DARK)
	for lx in [-0.35, 0.35]:
		_blk(pk, kit, "steel", Vector3(3.9 + lx - 0.25, 12.55, -11.9), Vector3(3.9 + lx + 0.25, 12.95, -11.6), STEEL_DARK)
		_blk(pk, kit, "lens", Vector3(3.9 + lx - 0.2, 12.6, -11.6), Vector3(3.9 + lx + 0.2, 12.9, -11.57), Color(0.85, 0.85, 0.8))
	# The operator's cab on the battery side, glazed toward the door and both ways along the battery.
	_cab(pk, kit, -4.4, -1.4, -11.36, -9.75, 4.6, 6.0, 7.9, 8.2, col, ["pz", "nx", "px"])
	for cx in [-4.2, -1.6]:
		pk.beam(kit, "steel", Vector3(cx, 3.4, -10.0), Vector3(cx, 4.6, -10.0), 0.14, 0.14, col.darkened(0.3))
	_blk(pk, kit, "steel", Vector3(-4.4, 2.4, -11.3), Vector3(-1.6, 3.4, -9.8), CAST)
	# The front platform at the bench's height, on brackets; its railing at the +x end.
	_blk(pk, kit, "floor", Vector3(-1.3, 4.25, -11.4), Vector3(4.6, 4.33, -9.62), BENCH_COL)
	for bx2 in [-1.0, 2.6, 4.3]:
		pk.beam(kit, "steel", Vector3(bx2, 2.4, -11.3), Vector3(bx2, 4.25, -9.9), 0.12, 0.12, col.darkened(0.3))
	_rail_line(pk, kit, [Vector3(4.42, 4.33, -11.3), Vector3(4.42, 4.33, -9.7)], 1.0, CRANE_YELLOW, "paint")
	# The ram: its head in front, the beam back through the house into the boom; the rack along its top.
	_blk(pk, kit, "rusty", Vector3(-0.25, 4.8, -27.6), Vector3(0.25, 5.55, -9.83), STEEL_DARK)
	_blk(pk, kit, "metal", Vector3(-0.08, 5.55, -27.4), Vector3(0.08, 5.6, -9.9), Color(0.5, 0.5, 0.48))
	_blk(pk, kit, "steel", Vector3(-0.21, 4.5, -9.8), Vector3(0.21, 7.95, -9.55), CAST)
	_blk(pk, kit, "hazard", Vector3(-0.25, 4.46, -9.84), Vector3(0.25, 7.99, -9.8), WHITE)
	for ys in [4.8, 6.2, 7.6]:
		_blk(pk, kit, "steel", Vector3(-0.16, ys - 0.09, -10.3), Vector3(0.16, ys + 0.09, -9.84), CAST)
	# The leveller bar.
	_blk(pk, kit, "rusty", Vector3(-0.1, 8.2, -25.0), Vector3(0.1, 8.5, -9.75), STEEL_DARK)
	_blk(pk, kit, "steel", Vector3(-0.18, 8.05, -9.75), Vector3(0.18, 8.65, -9.6), CAST)
	# The boom carrying the ram's tail, struts under it.
	SteelworksKit._lattice(pk, kit, "steel", Vector3(0, 6.9, -17.2), Vector3(0, 6.9, -27.8), 1.6, 4.4, 2.12, col.darkened(0.1), Vector3.UP, 0.2, 0.09, 15)
	for sx in [-0.8, 0.8]:
		pk.beam(kit, "steel", Vector3(sx, 2.4, -17.4), Vector3(sx, 4.62, -24.0), 0.16, 0.16, col.darkened(0.2))
	# The door extractor (Türabheber) at the next oven's door, its carriage with hooks at the latch heights.
	var ex := 1.45
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "steel", Vector3(ex + sx * 0.55 - 0.1, 2.4, -10.22), Vector3(ex + sx * 0.55 + 0.1, 10.4, -9.92), col.darkened(0.15))
	_blk(pk, kit, "steel", Vector3(ex - 0.72, 10.1, -10.27), Vector3(ex + 0.72, 10.5, -9.87), col.darkened(0.15))
	_blk(pk, kit, "steel", Vector3(ex - 0.42, 5.2, -9.92), Vector3(ex + 0.42, 7.6, -9.79), CAST)
	for yh in [5.0, 7.3]:
		_blk(pk, kit, "steel", Vector3(ex - 0.32, yh - 0.06, -9.79), Vector3(ex + 0.32, yh + 0.06, -9.69), STEEL)
	if holding_door:
		_held_door(pk, kit, Vector3(ex, 4.3, -9.68), 1.0, 8.92)
	# Ladder up the house's +x side, the cable drum at the back.
	SteelworksKit._ladder(pk, kit, Vector3(4.6, 2.4, -16.5), Vector3(4.6, 11.1, -16.5), Vector3(1, 0, 0), false, STEEL_DARK)
	pk.tube(kit, "steel", Vector3(-2.3, 3.4, -18.2), Vector3(-1.5, 3.4, -18.2), 0.75, 0.75, 14, STEEL_DARK, true)
	for dx in [-2.33, -1.47]:
		pk.tube(kit, "steel", Vector3(dx - 0.02, 3.4, -18.2), Vector3(dx + 0.02, 3.4, -18.2), 0.95, 0.95, 14, col.darkened(0.25), true)
	_blk(pk, kit, "steel", Vector3(-2.5, 2.4, -18.4), Vector3(-1.3, 2.62, -17.5), col.darkened(0.3))
	for mx in [-3.6, 2.8]:
		pk.tube(kit, "paint", Vector3(mx - 0.6, 2.85, -17.0), Vector3(mx + 0.6, 2.85, -17.0), 0.38, 0.38, 10, Color(0.24, 0.30, 0.42), true)


## A door hung on an extractor: `c` the middle of its outer face's foot (against the hooks), `s` the way from its outer face
## to its plug side (toward the oven); the ribs stand off the outer face, the plug side still glowing dull red.
static func _held_door(pk: PropKit, kit: Dictionary, c: Vector3, s: float, top: float) -> void:
	var h: float = top - 4.25
	_blk(pk, kit, "rusty", c + Vector3(-0.345, 0.0, 0.0), c + Vector3(0.345, h, s * 0.2), DOOR_COL)
	for rx in [-0.17, 0.17]:
		_blk(pk, kit, "rusty", c + Vector3(rx - 0.035, 0.1, 0.0), c + Vector3(rx + 0.035, h - 0.1, -s * 0.06), DOOR_COL.darkened(0.12))
	_blk(pk, kit, "hot", c + Vector3(-0.3, 0.1, s * 0.2), c + Vector3(0.3, h - 0.1, s * 0.23), SteelworksKit.hot_colour(0.15))


## The coke guide car (Kokskuchenführungswagen), in the battery's frame shifted to its oven (x 0 the guide): on the two
## rails on the coke bench (z 8.3 and 11.2), two half frames either side of the guide joined by the top frame and the
## machinery house over it, the guide's cage (grate-barred walls) from the door to z 13.2 over the quench car, the cab
## hanging on the +z side over the quench track, the door extractor at x -1.45. `pushing`: the cage reaches to the door
## frame and a glowing coke cake is in it (only at the battery's open_oven). Keep z 7.3..13.3 above the bench clear.
static func coke_guide_car(pk: PropKit, kit: Dictionary, pushing := false, holding_door := false) -> void:
	var col := GUIDE_COL
	var wr := 0.35
	var wy: float = GUIDE_RAIL_Y + wr
	for z in GUIDE_RAILS:
		var zr: float = z
		for bx in [-2.0, 2.0]:
			for wx in [-0.55, 0.55]:
				_wheel(pk, kit, Vector3(bx + wx, wy, zr), Vector3(0, 0, 1), wr, 0.11, 1.0 if zr < 10.0 else -1.0)
			for sz in [-1.0, 1.0]:
				_blk(pk, kit, "rusty", Vector3(bx - 0.95, 4.42, zr + sz * 0.12), Vector3(bx + 0.95, 5.02, zr + sz * 0.26), col.darkened(0.35))
			_blk(pk, kit, "rusty", Vector3(bx - 1.05, 5.0, zr - 0.3), Vector3(bx + 1.05, 5.25, zr + 0.3), col.darkened(0.3))
	for sx in [-1.0, 1.0]:
		for z in GUIDE_RAILS:
			var zr2: float = z
			_blk(pk, kit, "rusty", Vector3(sx * 0.7, 5.25, zr2 - 0.28), Vector3(sx * 2.95, 5.75, zr2 + 0.28), col)
		for xc in [0.9, 2.75]:
			_blk(pk, kit, "rusty", Vector3(sx * xc - 0.15, 5.3, 8.0), Vector3(sx * xc + 0.15, 5.7, 11.5), col.darkened(0.1))
			for z in GUIDE_RAILS:
				var zr3: float = z
				_blk(pk, kit, "rusty", Vector3(sx * xc - 0.15, 5.75, zr3 - 0.15), Vector3(sx * xc + 0.15, 9.4, zr3 + 0.15), col)
		# Diagonal bracing in each half's +-z planes.
		for z in GUIDE_RAILS:
			var zr4: float = z
			pk.beam(kit, "rusty", Vector3(sx * 0.9, 5.75, zr4), Vector3(sx * 2.6, 9.3, zr4), 0.1, 0.1, col.darkened(0.15))
	_blk(pk, kit, "hazard", Vector3(-2.95, 5.27, 11.48), Vector3(-0.7, 5.73, 11.52), WHITE)
	_blk(pk, kit, "hazard", Vector3(0.7, 5.27, 11.48), Vector3(2.95, 5.73, 11.52), WHITE)
	# Top frame and the cantilever carrying the cab.
	_blk(pk, kit, "rusty", Vector3(-2.95, 9.4, 7.95), Vector3(2.95, 9.9, 11.55), col)
	_blk(pk, kit, "rusty", Vector3(0.75, 9.4, 11.55), Vector3(2.95, 9.85, 13.3), col)
	# Machinery house on top.
	var holes := {
		"px": [[Rect2(0.6, 10.7, 1.2, 0.9), "win"]],
		"nx": [[Rect2(0.6, 10.7, 1.2, 0.9), "win"]],
		"pz": [[Rect2(1.6, 9.9, 0.9, 1.9), "door"]],
	}
	_clad_box(pk, kit, "iron", -2.3, 2.3, 8.45, 11.05, 9.9, 12.5, CLAD.darkened(0.1), holes, 0.08, col.darkened(0.3))
	_flat_roof(pk, kit, -2.3, 2.3, 8.45, 11.05, 12.5, 0.15, 0.2, ROOF_COL)
	pk.beam(kit, "steel", Vector3(-1.8, 12.7, 10.6), Vector3(-1.8, 13.6, 10.6), 0.1, 0.1, STEEL_DARK)
	_rail_line(pk, kit, [Vector3(-2.88, 9.9, 8.02), Vector3(2.88, 9.9, 8.02), Vector3(2.88, 9.9, 11.48), Vector3(-2.88, 9.9, 11.48), Vector3(-2.88, 9.9, 8.02)], 1.0, STEEL_DARK, "steel", 2.0)
	# The cab, glazed toward the quench car and along the track.
	_cab(pk, kit, 0.95, 2.85, 11.62, 13.2, 6.4, 7.3, 9.0, 9.4, col, ["pz", "px", "nx"], "rusty")
	# The guide: a cage of grate bars from the door to over the quench car.
	var cz0: float = 7.34 if pushing else 7.7
	var cz1 := 13.2
	var cy0 := 4.42
	var cy1 := 8.95
	_blk(pk, kit, "steel", Vector3(-0.36, 4.36, cz0), Vector3(0.36, cy0, cz1), CAST)
	for sx in [-1.0, 1.0]:
		var x: float = sx * 0.36
		_blk(pk, kit, "rusty", Vector3(x - 0.04, cy0, cz0 + 0.12), Vector3(x + 0.04, cy0 + 0.22, cz1 - 0.02), col.darkened(0.2))
		_blk(pk, kit, "rusty", Vector3(x - 0.04, cy1 - 0.22, cz0 + 0.12), Vector3(x + 0.04, cy1, cz1 - 0.02), col.darkened(0.2))
		for k in range(9):
			var zp: float = lerpf(cz0 + 0.3, cz1 - 0.04, float(k) / 8.0)
			_blk(pk, kit, "rusty", Vector3(x - 0.05, cy0 + 0.22, zp - 0.06), Vector3(x + 0.05, cy1 - 0.22, zp + 0.06), col.darkened(0.25))
		for yb in [5.55, 6.65, 7.75]:
			_blk(pk, kit, "steel", Vector3(x - 0.03, yb - 0.05, cz0 + 0.12), Vector3(x + 0.03, yb + 0.05, cz1 - 0.05), STEEL_DARK)
		_blk(pk, kit, "hazard", Vector3(sx * 0.40, 4.36, cz0), Vector3(sx * 0.48, 8.95, cz0 + 0.12), WHITE)
		for zh in [8.2, 9.8, 11.4, 12.9]:
			pk.beam(kit, "steel", Vector3(x, cy1, zh), Vector3(x, 9.4, zh), 0.08, 0.08, STEEL_DARK)
		pk.beam(kit, "steel", Vector3(sx * 0.4, 6.5, 8.3), Vector3(sx * 0.8, 6.5, 8.3), 0.12, 0.12, col.darkened(0.2))
		pk.beam(kit, "steel", Vector3(sx * 0.4, 6.5, 11.2), Vector3(sx * 0.8, 6.5, 11.2), 0.12, 0.12, col.darkened(0.2))
	_blk(pk, kit, "hazard", Vector3(-0.48, 8.95, cz0), Vector3(0.48, 9.08, cz0 + 0.12), WHITE)
	if pushing:
		# The coke cake on its way through, glowing; its crumbled front end over the quench car.
		_blk(pk, kit, "hot", Vector3(-0.27, cy0, cz0 + 0.1), Vector3(0.27, 8.55, 11.6), SteelworksKit.hot_colour(0.6))
		_blk(pk, kit, "hot", Vector3(-0.25, cy0, 11.6), Vector3(0.25, 7.2, 12.4), SteelworksKit.hot_colour(0.48))
	# The door extractor at the next oven toward -x, hanging from the top frame.
	# Holding a door it stands pulled back from the battery, clear of the neighbouring door.
	var ex := -1.45
	var zc: float = 8.79 if holding_door else 7.70
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "steel", Vector3(ex + sx * 0.48 - 0.09, 4.8, zc + 0.08), Vector3(ex + sx * 0.48 + 0.09, 9.4, zc + 0.28), col.darkened(0.2))
	_blk(pk, kit, "steel", Vector3(ex - 0.42, 4.8, zc), Vector3(ex + 0.42, 8.6, zc + 0.08), CAST)
	for yh in [5.0, 8.2]:
		_blk(pk, kit, "steel", Vector3(ex - 0.3, yh - 0.06, zc - 0.04), Vector3(ex + 0.3, yh + 0.06, zc), STEEL)
	if holding_door:
		_held_door(pk, kit, Vector3(ex, 4.3, zc - 0.05), -1.0, 8.95)
	# Ladder from the bench to the top frame.
	SteelworksKit._ladder(pk, kit, Vector3(2.95, BENCH_Y, 9.75), Vector3(2.95, 9.9, 9.75), Vector3(1, 0, 0), false, STEEL_DARK)


## The quench car (Löschwagen) and its electric loco, in the track's frame (rails at z +-0.7175, rail top y 0.2): a 14m
## steel tub on two bogies (x -7..7), its floor sloping down toward -z to four bottom-hung discharge gates on that side,
## stiffened walls, soot-black; the loco coupled at its -x end (x -16.55..-8.5): cab at the far end, a hood, red with
## striped buffer beams. load 1: glowing coke, 2: quenched coke (grey, wet). x 0 is the tub's middle: put it under the
## guide car's oven. Its discharge side (-z) must face the coke wharf.
static func quench_car(pk: PropKit, kit: Dictionary, load := 0) -> void:
	var g := GAUGE_HALF
	var wr := 0.46
	var wy: float = RAIL_TOP + wr
	for bx in [-4.6, 4.6]:
		for ax in [-0.9, 0.9]:
			for sz in [-1.0, 1.0]:
				_wheel(pk, kit, Vector3(bx + ax, wy, sz * g), Vector3(0, 0, 1), wr, 0.13, -sz)
			pk.tube(kit, "steel", Vector3(bx + ax, wy, -g + 0.08), Vector3(bx + ax, wy, g - 0.08), 0.09, 0.09, 6, STEEL_DARK, false)
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "steel", Vector3(bx - 1.4, wy - 0.25, sz * (g + 0.12)), Vector3(bx + 1.4, wy + 0.3, sz * (g + 0.3)), CAST)
			for ax2 in [-0.9, 0.9]:
				_blk(pk, kit, "steel", Vector3(bx + ax2 - 0.2, wy - 0.18, sz * (g + 0.3)), Vector3(bx + ax2 + 0.2, wy + 0.2, sz * (g + 0.42)), STEEL_DARK)
		_blk(pk, kit, "steel", Vector3(bx - 0.4, wy + 0.3, -(g + 0.36)), Vector3(bx + 0.4, 1.12, g + 0.36), CAST)
	_blk(pk, kit, "steel", Vector3(-7.4, 1.12, -1.25), Vector3(7.4, 1.58, 1.25), CAST)
	for ex in [-1.0, 1.0]:
		_blk(pk, kit, "hazard", Vector3(ex * 7.4, 0.98, -1.5), Vector3(ex * 7.6, 1.62, 1.5), WHITE)
		for sz in [-0.875, 0.875]:
			pk.tube(kit, "steel", Vector3(ex * 7.6, 1.3, sz), Vector3(ex * 7.98, 1.3, sz), 0.12, 0.12, 8, STEEL_DARK, false)
			pk.tube(kit, "steel", Vector3(ex * 7.98, 1.3, sz), Vector3(ex * 8.05, 1.3, sz), 0.24, 0.24, 10, STEEL, true)
	# The tub.
	_blk(pk, kit, "rusty", Vector3(-7.0, 1.58, 1.67), Vector3(7.0, 4.2, 1.75), TUB)
	for ex in [-1.0, 1.0]:
		_blk(pk, kit, "grime", Vector3(ex * 6.92, 1.58, -1.66), Vector3(ex * 7.0, 4.2, 1.66), TUB)
	for k in range(4):
		var x0: float = -6.9 + float(k) * 3.45 + 0.02
		var x1: float = x0 + 3.41
		_blk(pk, kit, "rusty", Vector3(x0, 1.75, -1.75), Vector3(x1, 4.12, -1.67), TUB.lightened(0.05))
		for r in [0.2, 0.5, 0.8]:
			var xr: float = lerpf(x0, x1, r)
			_blk(pk, kit, "rusty", Vector3(xr - 0.06, 1.8, -1.86), Vector3(xr + 0.06, 4.1, -1.75), TUB.darkened(0.3))
		# Locking lever at the gate's foot.
		pk.beam(kit, "steel", Vector3((x0 + x1) * 0.5, 1.7, -1.8), Vector3((x0 + x1) * 0.5 + 0.6, 1.35, -1.55), 0.08, 0.08, STEEL_DARK)
	for k in range(14):
		var xr2: float = -6.5 + float(k)
		_blk(pk, kit, "rusty", Vector3(xr2 - 0.06, 1.58, 1.75), Vector3(xr2 + 0.06, 4.2, 1.86), TUB.darkened(0.3))
	_blk(pk, kit, "steel", Vector3(-7.06, 4.1, 1.62), Vector3(7.06, 4.25, 1.9), CAST)
	_blk(pk, kit, "steel", Vector3(-7.06, 4.12, -1.9), Vector3(7.06, 4.3, -1.62), CAST)
	for ex in [-1.0, 1.0]:
		_blk(pk, kit, "steel", Vector3(ex * 6.9, 4.1, -1.62), Vector3(ex * 7.08, 4.25, 1.62), CAST)
	# The floor, sloping down toward the gates.
	var d := Vector3(0, 1.4, 3.34).normalized()
	var nrm := d.cross(Vector3.RIGHT).normalized()
	_box(pk, kit, "grime", Vector3(0, 2.5, 0) - nrm * 0.05, Basis(Vector3.RIGHT, nrm, d), Vector3(13.84, 0.1, 3.62), TUB.darkened(0.2))
	# A brake platform and ladder at the +x end.
	_blk(pk, kit, "steel", Vector3(7.08, 1.52, -1.3), Vector3(7.5, 1.66, 1.3), STEEL_DARK)
	for k in range(4):
		pk.beam(kit, "steel", Vector3(7.06, 1.9 + float(k) * 0.55, -0.25), Vector3(7.06, 1.9 + float(k) * 0.55, 0.25), 0.04, 0.04, STEEL_DARK)
	if load > 0:
		_coke_load(pk, kit, load)
	_quench_loco(pk, kit)


static func _floor_y(z: float) -> float:
	return 1.8 + (z + 1.67) / 3.34 * 1.4


## The load in the tub: a lumpy heap of coke (smooth, a colour per point): glowing with dark crusts (load 1) or quenched
## grey and wet (2).
static func _coke_load(pk: PropKit, kit: Dictionary, load: int) -> void:
	var nx := 28
	var nz := 7
	var grid: Array = []
	var cols: Array = []
	for i in range(nx + 1):
		var row: Array = []
		var crow: Array = []
		for k in range(nz + 1):
			var x: float = lerpf(-6.85, 6.85, float(i) / float(nx))
			var z: float = lerpf(-1.62, 1.62, float(k) / float(nz))
			var mound: float = 0.38 * (1.0 - pow(x / 6.9, 2.0)) + 0.12 * sin(x * 0.9 + 0.4)
			var lump: float = 0.13 * sin(x * 2.9 + z * 3.4) * cos(x * 1.3 - z * 5.1) + 0.07 * sin(x * 6.1 + z * 2.0 + 1.3)
			var y: float = maxf(_floor_y(z) + 0.4, 3.36 + mound + lump)
			row.append(Vector3(x, minf(y, 4.06), z))
			var n: float = 0.5 + 0.5 * sin(x * 1.7 + z * 2.3) * cos(x * 0.6 - z * 1.9 + 0.7)
			if load == 1:
				var crust: float = smoothstep(0.55, 0.85, 0.5 + 0.5 * sin(x * 3.3 - z * 2.7 + 2.0) * sin(x * 1.1 + 0.3))
				crow.append(SteelworksKit.hot_colour(0.22 + 0.5 * n).lerp(Color(0.07, 0.03, 0.02), crust * 0.85))
			else:
				crow.append(Color(COKE.r * (0.85 + 0.3 * n), COKE.g * (0.85 + 0.3 * n), COKE.b * (0.85 + 0.3 * n), 0.75))
		grid.append(row)
		cols.append(crow)
	_grid_surface(pk, kit, "hot" if load == 1 else "coke", grid, cols, Vector3.UP)


## The electric quench loco (Löschlok) coupled at the car's -x end.
static func _quench_loco(pk: PropKit, kit: Dictionary) -> void:
	var g := GAUGE_HALF
	var wr := 0.5
	var wy: float = RAIL_TOP + wr
	for ax in [-14.3, -10.7]:
		for sz in [-1.0, 1.0]:
			_wheel(pk, kit, Vector3(ax, wy, sz * g), Vector3(0, 0, 1), wr, 0.13, -sz)
		pk.tube(kit, "steel", Vector3(ax, wy, -g + 0.08), Vector3(ax, wy, g - 0.08), 0.1, 0.1, 6, STEEL_DARK, false)
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "steel", Vector3(-15.6, 0.5, sz * (g + 0.12)), Vector3(-9.4, 1.0, sz * (g + 0.28)), CAST)
		for ax2 in [-14.3, -10.7]:
			_blk(pk, kit, "steel", Vector3(ax2 - 0.25, 0.48, sz * (g + 0.28)), Vector3(ax2 + 0.25, 0.92, sz * (g + 0.4)), STEEL_DARK)
	_blk(pk, kit, "steel", Vector3(-16.4, 1.0, -1.32), Vector3(-8.65, 1.48, 1.32), CAST)
	for e in [[-16.55, -16.4, -1.0], [-8.65, -8.5, 1.0]]:
		_blk(pk, kit, "hazard", Vector3(e[0], 0.92, -1.45), Vector3(e[1], 1.6, 1.45), WHITE)
		for sz in [-0.875, 0.875]:
			var xb: float = e[1] if float(e[2]) > 0.0 else e[0]
			var xe: float = xb + float(e[2]) * 0.38
			pk.tube(kit, "steel", Vector3(xb, 1.3, sz), Vector3(xe, 1.3, sz), 0.12, 0.12, 8, STEEL_DARK, false)
			pk.tube(kit, "steel", Vector3(xe, 1.3, sz), Vector3(xe + float(e[2]) * 0.07, 1.3, sz), 0.24, 0.24, 10, STEEL, true)
	# The cab at the -x end, glazed all round over its waist; the hood toward the car.
	_cab(pk, kit, -16.3, -13.4, -1.4, 1.4, 1.48, 2.9, 3.95, 4.25, LOCO_RED, ["nx", "pz", "nz", "px"])
	_blk(pk, kit, "paint", Vector3(-13.4, 1.48, -1.05), Vector3(-8.75, 2.95, 1.05), LOCO_RED)
	_blk(pk, kit, "paint", Vector3(-13.3, 2.95, -0.95), Vector3(-8.85, 3.08, 0.95), LOCO_RED.darkened(0.3))
	for sz in [-1.0, 1.0]:
		for gx in [-12.4, -10.2]:
			_blk(pk, kit, "steel", Vector3(gx, 1.75, sz * 1.05), Vector3(gx + 1.5, 2.65, sz * 1.075), LOCO_RED.darkened(0.25))
			for k in range(6):
				var yl: float = 1.83 + float(k) * 0.14
				_blk(pk, kit, "steel", Vector3(gx + 0.06, yl, sz * 1.075), Vector3(gx + 1.44, yl + 0.05, sz * 1.1), LOCO_RED.darkened(0.55))
		pk.beam(kit, "paint", Vector3(-13.3, 2.45, sz * 1.24), Vector3(-8.8, 2.45, sz * 1.24), 0.04, 0.04, CRANE_YELLOW)
		for px in [-13.0, -11.0, -9.0]:
			pk.beam(kit, "paint", Vector3(px, 1.48, sz * 1.24), Vector3(px, 2.44, sz * 1.24), 0.034, 0.034, CRANE_YELLOW)
		# Steps under the cab doors.
		_blk(pk, kit, "steel", Vector3(-15.2, 0.62, sz * 1.25), Vector3(-14.5, 0.68, sz * 1.5), STEEL_DARK)
	pk.lathe(kit, "steel", Vector3(-11.0, 3.08, 0), [Vector2(0.55, 0.0), Vector2(0.55, 0.12), Vector2(0.001, 0.14)], 10, STEEL_DARK, true)
	for sz in [-0.8, 0.8]:
		pk.tube(kit, "lens", Vector3(-16.32, 2.4, sz), Vector3(-16.4, 2.4, sz), 0.13, 0.13, 8, Color(0.9, 0.88, 0.8), true)


## The larry car (Füllwagen), in the battery's frame shifted to its oven (its hoppers over oven 0's charging holes at
## x 0): on the top's rails at z +-4.5 (four wheels), two box girders, four hoppers in a row across the battery (z -3.3,
## -1.1, 1.1, 3.3) narrowing to telescopic sleeves raised over the lids, lid lifters, a platform with railings and a winch
## house on the hoppers' tops, the cab at its +x end. 7.0 x 9.7 x 6.6m over the rails.
static func larry_car(pk: PropKit, kit: Dictionary) -> void:
	var col := LARRY_COL
	var wr := 0.38
	var wy: float = LARRY_RAIL_Y + wr
	for sz in [-1.0, 1.0]:
		var zr: float = sz * LARRY_RAIL_Z
		for wx in [-1.55, 1.55]:
			_wheel(pk, kit, Vector3(wx, wy, zr), Vector3(0, 0, 1), wr, 0.12, -sz)
			_blk(pk, kit, "rusty", Vector3(wx - 0.32, wy - 0.12, zr - sz * 0.12), Vector3(wx + 0.32, 10.4, zr + sz * 0.3), col.darkened(0.3))
		_blk(pk, kit, "rusty", Vector3(-2.4, 10.35, zr - 0.32), Vector3(2.4, 11.15, zr + 0.32), col)
		_blk(pk, kit, "hazard", Vector3(-2.4, 10.37, zr + sz * 0.32), Vector3(2.4, 10.6, zr + sz * 0.34), WHITE)
	for sx in [-1.0, 1.0]:
		_blk(pk, kit, "rusty", Vector3(sx * 2.25 - 0.18, 10.5, -4.78), Vector3(sx * 2.25 + 0.18, 11.1, 4.78), col.darkened(0.08))
		_blk(pk, kit, "rusty", Vector3(sx * 1.05 - 0.14, 12.7, -4.6), Vector3(sx * 1.05 + 0.14, 13.1, 4.6), col.darkened(0.1))
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "rusty", Vector3(sx * 1.05 - 0.12, 11.15, sz * 4.5 - 0.12), Vector3(sx * 1.05 + 0.12, 12.7, sz * 4.5 + 0.12), col)
			pk.beam(kit, "rusty", Vector3(sx * 2.1, 11.1, sz * 4.5), Vector3(sx * 1.15, 12.65, sz * 4.5), 0.1, 0.1, col.darkened(0.2))
	for z in CHARGE_Z:
		var cz: float = z
		SteelworksKit._frustum(pk, kit, "rusty", 0.0, cz, 11.65, 0.32, 0.32, 13.1, 0.93, 0.98, col)
		_blk(pk, kit, "rusty", Vector3(-0.93, 13.1, cz - 0.98), Vector3(0.93, 15.2, cz + 0.98), col)
		_blk(pk, kit, "rusty", Vector3(-0.96, 14.0, cz - 1.0), Vector3(0.96, 14.12, cz + 1.0), col.darkened(0.2))
		pk.tube(kit, "steel", Vector3(0, 10.3, cz), Vector3(0, 11.7, cz), 0.26, 0.26, 10, CAST, false)
		pk.tube(kit, "steel", Vector3(0, 10.25, cz), Vector3(0, 10.45, cz), 0.33, 0.33, 10, CAST, true)
		_blk(pk, kit, "steel", Vector3(0.52, 10.35, cz - 0.14), Vector3(0.82, 10.7, cz + 0.14), STEEL_DARK)
		pk.beam(kit, "steel", Vector3(0.67, 10.7, cz), Vector3(0.67, 11.9, cz), 0.06, 0.06, STEEL)
	# The platform on top, its railing and the winch house.
	_blk(pk, kit, "floor", Vector3(-1.15, 15.2, -4.5), Vector3(1.15, 15.3, 4.5), col.darkened(0.3))
	_rail_line(pk, kit, [Vector3(-1.1, 15.3, -4.45), Vector3(1.1, 15.3, -4.45), Vector3(1.1, 15.3, 4.45), Vector3(-1.1, 15.3, 4.45), Vector3(-1.1, 15.3, -4.45)], 1.0, CRANE_YELLOW, "paint", 2.3)
	_blk(pk, kit, "paint", Vector3(-0.9, 15.3, -0.8), Vector3(0.4, 16.4, 0.8), col.darkened(0.15))
	# The cab at +x, glazed forward and to both sides.
	_cab(pk, kit, 2.43, 4.3, -2.3, 2.3, 10.9, 11.9, 13.4, 13.7, col, ["px", "pz", "nz"], "rusty")
	# Ladder from the top up to the platform.
	_ladder(pk, kit, Vector3(-2.45, 10.05, 0.0), Vector3(-2.45, 15.3, 0.0), Vector3(-1, 0, 0))
	_blk(pk, kit, "steel", Vector3(-2.45, 15.2, -0.4), Vector3(-1.15, 15.3, 0.4), STEEL_DARK)


# ======================================================================================
#  The coal tower
# ======================================================================================

## The coal tower (Kohlenturm) at the battery's x = 0 end: its origin on the ground under its middle, x along the battery
## (the battery at +x), z across. Six concrete columns (x -6.9, 0, 6.9; z +-9.4) carry the deck at the battery top's height
## with the larry car's rails (z +-4.5, rail top 9.8) and a bridge on to x 12.55 (the battery's end wall: place the tower at
## battery x = COAL_TOWER_X), then the bunker (15 x 20m, y 20..41) with four outlets over the larry car's hoppers (their
## gates at y 17.2..17.8), the head house to 45.9 with the conveyor gallery stub falling away toward -x
## (coal_tower_gallery_end()), a stair tower on the -z side to 46.9. KOKEREI / KRONPRINZ on the +z and -x faces.
static func coal_tower(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var conc := CONCRETE
	for x in [-6.9, 0.0, 6.9]:
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "concrete", Vector3(x - 1.0, -3.0, sz * 9.4 - 1.0), Vector3(x + 1.0, 0.1, sz * 9.4 + 1.0), conc.darkened(0.08))
			_blk(pk, kit, "concrete", Vector3(x - 0.55, 0.1, sz * 9.4 - 0.55), Vector3(x + 0.55, 20.2, sz * 9.4 + 0.55), conc)
		_blk(pk, kit, "concrete", Vector3(x - 0.45, TOP_Y - 1.5, -9.4), Vector3(x + 0.45, TOP_Y - 0.6, 9.4), conc.darkened(0.05))
	for sz in [-1.0, 1.0]:
		_blk(pk, kit, "concrete", Vector3(-6.9, 4.6, sz * 9.4 - 0.35), Vector3(6.9, 5.4, sz * 9.4 + 0.35), conc.darkened(0.05))
		_blk(pk, kit, "concrete", Vector3(-6.9, 15.6, sz * 9.4 - 0.4), Vector3(6.9, 16.6, sz * 9.4 + 0.4), conc.darkened(0.05))
	# The deck and the bridge to the battery.
	_blk(pk, kit, "concrete", Vector3(-7.6, TOP_Y - 0.6, -6.0), Vector3(7.6, TOP_Y, 6.0), conc.darkened(0.1))
	_blk(pk, kit, "concrete", Vector3(7.6, TOP_Y - 0.5, -5.6), Vector3(12.55, TOP_Y, 5.6), conc.darkened(0.1))
	for sz in [-1.0, 1.0]:
		var zl: float = sz * LARRY_RAIL_Z
		_blk(pk, kit, "concrete", Vector3(6.9, TOP_Y - 1.35, zl - 0.3), Vector3(12.55, TOP_Y - 0.5, zl + 0.3), conc.darkened(0.05))
		_blk(pk, kit, "concrete", Vector3(-7.4, TOP_Y, zl - 0.3), Vector3(12.55, TOP_Y + 0.08, zl + 0.3), conc.darkened(0.35))
		_crane_rail(pk, kit, -7.2, 12.55, zl, TOP_Y + 0.08, LARRY_RAIL_Y)
		_blk(pk, kit, "paint", Vector3(-7.6, TOP_Y + 0.08, zl - 0.35), Vector3(-7.25, TOP_Y + 1.1, zl + 0.35), RED)
		_rail_line(pk, kit, [Vector3(-7.5, TOP_Y, sz * 5.9), Vector3(7.55, TOP_Y, sz * 5.9), Vector3(7.55, TOP_Y, sz * 5.5), Vector3(12.4, TOP_Y, sz * 5.5)], 1.1, CRANE_YELLOW, "paint", 2.5)
	# The bunker: board-formed concrete on its base band, corner piers, a band halfway, a cornice.
	_blk(pk, kit, "concrete", Vector3(-7.5, 20.0, -10.0), Vector3(7.5, 41.0, 10.0), conc)
	_blk(pk, kit, "sootcrete", Vector3(-7.7, 19.6, -10.2), Vector3(7.7, 20.8, 10.2), _soot_col(conc.darkened(0.05), 0.5))
	_blk(pk, kit, "concrete", Vector3(-7.65, 30.2, -10.15), Vector3(7.65, 30.6, 10.15), conc.darkened(0.06))
	_blk(pk, kit, "concrete", Vector3(-7.8, 40.6, -10.3), Vector3(7.8, 41.4, 10.3), conc.darkened(0.06))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_blk(pk, kit, "concrete", Vector3(sx * 6.7, 20.8, sz * 9.2), Vector3(sx * 7.75, 40.6, sz * 10.25), conc.darkened(0.03))
	# Hopper outlets over the larry car's hoppers.
	for z in CHARGE_Z:
		var cz: float = z
		SteelworksKit._frustum(pk, kit, "rusty", 0.0, cz, 17.8, 0.32, 0.32, 19.6, 1.0, 0.95, STEEL_DARK)
		_blk(pk, kit, "steel", Vector3(-0.42, 17.2, cz - 0.42), Vector3(0.42, 17.8, cz + 0.42), CAST)
		pk.tube(kit, "steel", Vector3(0.42, 17.5, cz), Vector3(0.95, 17.5, cz), 0.09, 0.09, 6, STEEL, true)
	# Slit windows (dark recesses with frames) on the +x, -x and +z faces.
	for y in [23.0, 33.5]:
		for zw in [-5.0, 5.0]:
			_slit(pk, kit, Vector3(7.5, y, zw), Vector3(1, 0, 0))
	for zw2 in [-5.5, 5.5]:
		_slit(pk, kit, Vector3(-7.5, 24.5, zw2), Vector3(-1, 0, 0))
	for xw in [-4.5, 4.5]:
		_slit(pk, kit, Vector3(xw, 24.0, 10.0), Vector3(0, 0, 1))
	# The head house: steel-clad, a band of windows, roof, railing, aviation lamps.
	var win: Array = []
	for k in range(5):
		win.append([Rect2(1.0 + float(k) * 2.5, 42.6, 1.6, 1.4), "win"])
	var winz: Array = []
	for k in range(6):
		winz.append([Rect2(1.0 + float(k) * 2.85, 42.6, 1.6, 1.4), "win"])
	_clad_box(pk, kit, "iron", -6.8, 6.8, -9.3, 9.3, 41.4, 45.6, CLAD.darkened(0.15), {"pz": win, "nz": win, "px": winz}, 0.08, STEEL_DARK)
	_flat_roof(pk, kit, -6.8, 6.8, -9.3, 9.3, 45.6, 0.2, 0.25, ROOF_COL)
	_rail_line(pk, kit, [Vector3(-6.9, 45.85, -9.4), Vector3(6.9, 45.85, -9.4), Vector3(6.9, 45.85, 9.4), Vector3(-6.9, 45.85, 9.4), Vector3(-6.9, 45.85, -9.4)], 1.0, STEEL_DARK, "steel", 3.0)
	for c in [Vector3(-6.7, 45.85, -9.2), Vector3(6.7, 45.85, 9.2)]:
		_blk(pk, kit, "lamp", c + Vector3(-0.15, 0.0, -0.15), c + Vector3(0.15, 0.3, 0.15), Color(1.0, 0.15, 0.1))
	pk.beam(kit, "steel", Vector3(0, 45.85, 0), Vector3(0, 48.0, 0), 0.05, 0.05, STEEL_DARK)
	# The conveyor gallery stub: corrugated box falling away toward -x, its windows, its knee braces.
	var gd := Vector3(-cos(deg_to_rad(12.0)), -sin(deg_to_rad(12.0)), 0.0)
	var gu := Vector3(gd.y, -gd.x, 0.0)
	var gs := Vector3(-6.75, 43.45, 0)
	var gb := Basis(gd, gu, gd.cross(gu).normalized())
	_box(pk, kit, "iron", gs + gd * 4.85, gb, Vector3(9.7, 2.9, 3.2), CLAD.darkened(0.15))
	_box(pk, kit, "steel", gs + gd * 9.72, gb, Vector3(0.1, 3.06, 3.36), STEEL_DARK)
	for sz in [-1.0, 1.0]:
		SteelworksKit._glazing(pk, kit, gs + gd * 4.6 + gu * 0.35 + Vector3(0, 0, sz * 1.63), gd, gu, Vector3(0, 0, sz), 7.6, 0.8)
		pk.beam(kit, "steel", Vector3(-6.85, 45.75, sz * 1.5), gs + gd * 9.4 + gu * 1.45 + Vector3(0, 0, sz * 1.5), 0.08, 0.08, STEEL_DARK)
		pk.beam(kit, "steel", Vector3(-6.6, 45.75, sz * 1.62), gs + gd * 5.0 + gu * 1.45 + Vector3(0, 0, sz * 1.62), 0.08, 0.08, STEEL_DARK)
	# The stair tower on the -z side.
	_blk(pk, kit, "concrete", Vector3(1.5, -0.5, -13.6), Vector3(5.5, 46.6, -10.0), conc.darkened(0.04))
	_blk(pk, kit, "roofing", Vector3(1.35, 46.6, -13.75), Vector3(5.65, 46.85, -9.95), ROOF_COL)
	var yw := 5.6
	while yw < 45.0:
		_slit(pk, kit, Vector3(3.5, yw, -13.6), Vector3(0, 0, -1), 0.7, 1.4)
		yw += 3.6
	_blk(pk, kit, "paint", Vector3(2.9, 0.0, -13.63), Vector3(4.1, 2.3, -13.58), Color(0.20, 0.24, 0.22))
	_blk(pk, kit, "concrete", Vector3(2.6, 2.3, -14.1), Vector3(4.4, 2.45, -13.6), conc.darkened(0.1))
	# The name on two faces.
	_blk(pk, kit, "paint", Vector3(-6.4, 32.6, 10.0), Vector3(6.4, 39.6, 10.06), Color(0.14, 0.15, 0.15))
	SteelworksKit._label(labels, "KOKEREI", Vector3(0, 37.3, 10.09), Vector3(0, 0, 1), 2.0, CREAM, 12.2)
	SteelworksKit._label(labels, "KRONPRINZ", Vector3(0, 34.4, 10.09), Vector3(0, 0, 1), 2.0, CREAM, 12.2)
	_blk(pk, kit, "paint", Vector3(-7.56, 32.6, -8.9), Vector3(-7.5, 39.6, 8.9), Color(0.14, 0.15, 0.15))
	SteelworksKit._label(labels, "KOKEREI", Vector3(-7.59, 37.3, 0), Vector3(-1, 0, 0), 2.2, CREAM, 17.2)
	SteelworksKit._label(labels, "KRONPRINZ", Vector3(-7.59, 34.3, 0), Vector3(-1, 0, 0), 2.2, CREAM, 17.2)


static func _soot_col(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## A narrow window on a wall at `c` (its middle on the face), facing `out`: a dark recess 3cm proud and a frame.
static func _slit(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w := 0.6, h := 2.4) -> void:
	var across: Vector3 = Vector3.UP.cross(out).normalized()
	var b := Basis(across, Vector3.UP, out)
	_box(pk, kit, "matte", c + out * 0.015, b, Vector3(w, h, 0.03), Color(0.05, 0.06, 0.07))
	for sv in [-1.0, 1.0]:
		_box(pk, kit, "steel", c + Vector3.UP * (sv * (h * 0.5 + 0.05)) + out * 0.04, b, Vector3(w + 0.2, 0.1, 0.08), STEEL_DARK)
		_box(pk, kit, "steel", c + across * (sv * (w * 0.5 + 0.05)) + out * 0.04, b, Vector3(0.1, h, 0.08), STEEL_DARK)


# ======================================================================================
#  The quench tower
# ======================================================================================

## The quench tower (Löschturm), its origin on the ground under its middle, the quench track along x through its foot
## (the passage clear for |z| <= 3.0, y <= 7.0: the car needs |z| <= 2.8, y <= 6): two concrete walls and a slab over the
## passage with the spray headers under it, the shaft tapering to 31m streaked black from the top down, the louvred baffle
## section (timber slats, dark inside) to 38.4, the roof frame round an opening and the steam chimney to 43, a steel stair
## tower up the -z side (keep the track's +z side, the road's, for the plain face). Steam bursts at quench_steam_point().
static func quench_tower(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	var conc := CONC_SOOT
	# The foot: walls either side of the passage and the slab over it.
	for sz in [-1.0, 1.0]:
		_soot_block(pk, kit, Vector3(-7.0, -1.0, sz * 3.0), Vector3(7.0, 7.0, sz * 4.7), conc, 0.35, 0.55)
		# The inner faces of the passage, darker (steam blackened).
		pk.quad(kit, "soot", [Vector3(-7.0, 0.0, sz * 2.97), Vector3(7.0, 0.0, sz * 2.97), Vector3(7.0, 7.0, sz * 2.97), Vector3(-7.0, 7.0, sz * 2.97)], Vector3(0, 0, -sz),
				Color(conc.r, conc.g, conc.b, 0.85))
	_soot_block(pk, kit, Vector3(-7.15, 7.0, -4.85), Vector3(7.15, 7.8, 4.85), conc.darkened(0.06), 0.6, 0.65)
	# Spray headers and nozzles under the slab.
	for sz in [-1.2, 1.2]:
		pk.tube(kit, "steel", Vector3(-6.8, 6.6, sz), Vector3(6.8, 6.6, sz), 0.09, 0.09, 8, STEEL_DARK, true)
		for k in range(7):
			var x: float = -6.0 + float(k) * 2.0
			_blk(pk, kit, "steel", Vector3(x - 0.05, 6.38, sz - 0.05), Vector3(x + 0.05, 6.55, sz + 0.05), STEEL_DARK)
	# The water pipe up the -x end into the slab.
	pk.tube(kit, "rusty", Vector3(-7.3, 0.3, -3.9), Vector3(-7.3, 7.35, -3.9), 0.16, 0.16, 8, PIPE_RUST, true)
	_blk(pk, kit, "concrete", Vector3(-7.6, -0.6, -4.2), Vector3(-7.0, 0.3, -3.6), CONCRETE)
	# The shaft.
	var y0 := 7.8
	var y1 := 31.0
	var b0 := Vector2(6.6, 4.4)
	var b1 := Vector2(5.6, 3.8)
	_frustum_soot(pk, kit, "sootcrete", y0, b0, y1, b1, conc, 0.3, 0.95)
	for c in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var o := Vector3(c.x * 0.12, 0, c.y * 0.12)
		var a := Vector3(c.x * b0.x, y0, c.y * b0.y) + o
		var b := Vector3(c.x * b1.x, y1, c.y * b1.y) + o
		pk.beam(kit, "soot", a, b, 0.62, 0.62, Color(conc.r * 0.95, conc.g * 0.95, conc.b * 0.95, 0.7))
	for yb in [15.5, 23.2]:
		var t: float = (yb - y0) / (y1 - y0)
		var hx: float = lerpf(b0.x, b1.x, t)
		var hz: float = lerpf(b0.y, b1.y, t)
		_soot_block(pk, kit, Vector3(-hx - 0.25, yb - 0.25, -hz - 0.15), Vector3(hx + 0.25, yb + 0.25, hz + 0.15), conc.darkened(0.04), 0.35 + t * 0.4, 0.4 + t * 0.4)
	# The baffle section: concrete corner posts, timber louvres on all four faces, black inside.
	var lb := Vector2(5.6, 3.8)
	for c2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		_soot_block(pk, kit, Vector3(c2.x * lb.x - 0.25, y1, c2.y * lb.y - 0.25), Vector3(c2.x * lb.x + 0.25, 38.4, c2.y * lb.y + 0.25), conc.darkened(0.1), 0.95, 1.0)
	var faces: Array = [[Vector3(0, 0, lb.y), Vector3(1, 0, 0), Vector3(0, 0, 1), lb.x * 2.0 - 0.5], [Vector3(0, 0, -lb.y), Vector3(-1, 0, 0), Vector3(0, 0, -1), lb.x * 2.0 - 0.5],
			[Vector3(lb.x, 0, 0), Vector3(0, 0, -1), Vector3(1, 0, 0), lb.y * 2.0 - 0.5], [Vector3(-lb.x, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0), lb.y * 2.0 - 0.5]]
	for f in faces:
		var fc: Vector3 = f[0]
		var y := 31.45
		while y < 38.1:
			_slat(pk, kit, "timber", fc + Vector3(0, y, 0), f[1], f[2], f[3], 0.62, 0.05, deg_to_rad(35.0), Color(0.40, 0.36, 0.31))
			y += 0.58
		# The black inside, facing in, behind the slats.
		var inset: Vector3 = -(f[2] as Vector3) * 0.55
		var half: Vector3 = (f[1] as Vector3) * ((f[3] as float) * 0.5)
		pk.quad(kit, "matte", [fc + inset - half + Vector3(0, y1, 0), fc + inset + half + Vector3(0, y1, 0), fc + inset + half + Vector3(0, 38.4, 0), fc + inset - half + Vector3(0, 38.4, 0)],
				-(f[2] as Vector3), Color(0.03, 0.03, 0.03))
	# The roof frame round the opening, then the chimney.
	var ro := Vector2(5.85, 4.05)
	var op := Vector2(3.0, 2.2)
	for sz in [-1.0, 1.0]:
		_soot_block(pk, kit, Vector3(-ro.x, 38.4, sz * op.y), Vector3(ro.x, 39.0, sz * ro.y), conc.darkened(0.1), 1.0, 1.0)
	for sx in [-1.0, 1.0]:
		_soot_block(pk, kit, Vector3(sx * op.x, 38.4, -op.y), Vector3(sx * ro.x, 39.0, op.y), conc.darkened(0.1), 1.0, 1.0)
	_frustum_soot(pk, kit, "soot", 39.0, Vector2(3.0, 2.2), 43.0, Vector2(2.6, 1.9), conc.darkened(0.1), 0.9, 1.0)
	_frustum_soot(pk, kit, "soot", 39.0, Vector2(2.75, 1.95), 43.0, Vector2(2.35, 1.65), Color(0.1, 0.1, 0.1), 1.0, 1.0, true)
	_rim(pk, kit, 43.0, Vector2(2.6, 1.9), Vector2(2.35, 1.65), conc.darkened(0.2))
	# The stair tower on the -z side: eight flights zig-zagging up to a walkway at the baffles.
	var xa := -4.6
	var xb := 0.8
	var zs := [-5.45, -6.4]
	for k in range(8):
		var ya: float = float(k) * 3.9
		var yb2: float = ya + 3.9
		var foot: Vector3
		var head: Vector3
		if k % 2 == 0:
			foot = Vector3(xa, ya, zs[0])
			head = Vector3(xb, yb2, zs[0])
		else:
			foot = Vector3(xb, ya, zs[1])
			head = Vector3(xa, yb2, zs[1])
		SteelworksKit._stair(pk, kit, foot, head, 0.9, STEEL, STEEL_DARK)
		var lx0: float = xb if k % 2 == 0 else xa - 1.3
		var lx1: float = xb + 1.3 if k % 2 == 0 else xa
		_blk(pk, kit, "steel", Vector3(lx0, yb2 - 0.1, -4.95), Vector3(lx1, yb2, -6.9), STEEL_DARK)
		var rx: float = lx1 if k % 2 == 0 else lx0
		_rail_line(pk, kit, [Vector3(rx, yb2, -4.98), Vector3(rx, yb2, -6.87)], 1.05, STEEL_DARK, "steel")
	for p in [Vector2(xa - 1.3, -4.95), Vector2(xa - 1.3, -6.85), Vector2(xb + 1.3, -4.95), Vector2(xb + 1.3, -6.85)]:
		_blk(pk, kit, "steel", Vector3(p.x - 0.08, 0.0, p.y - 0.08), Vector3(p.x + 0.08, 31.2, p.y + 0.08), STEEL)
		_blk(pk, kit, "concrete", Vector3(p.x - 0.3, -0.6, p.y - 0.3), Vector3(p.x + 0.3, 0.15, p.y + 0.3), CONCRETE)
	for k in range(1, 8):
		pk.beam(kit, "steel", Vector3(xa - 1.3, float(k) * 3.9 - 0.16, -4.95), Vector3(xa - 1.3, float(k) * 3.9 - 0.16, -4.4), 0.1, 0.1, STEEL)
	_blk(pk, kit, "steel", Vector3(-5.92, 31.12, -4.12), Vector3(2.12, 31.22, -6.86), STEEL_DARK)
	_rail_line(pk, kit, [Vector3(-5.85, 31.22, -6.8), Vector3(2.05, 31.22, -6.8), Vector3(2.05, 31.22, -4.15)], 1.1, STEEL_DARK, "steel")
	SteelworksKit._label(labels, "LÖSCHTURM", Vector3(0, 24.0, 4.04), Vector3(0, 0, 1), 1.25, CREAM, 10.5)


## A block in the soot shader, its lower corners `a0` sooted and its upper `a1`.
static func _soot_block(pk: PropKit, kit: Dictionary, lo: Vector3, hi: Vector3, col: Color, a0: float, a1: float) -> void:
	var p := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z)]
	var q := [Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	var outs := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	for i in range(4):
		var j: int = (i + 1) % 4
		_soot_quad(pk, kit, "soot", [p[i], p[j], q[j], q[i]], outs[i], col, [a0, a0, a1, a1])
	_soot_quad(pk, kit, "soot", [q[0], q[1], q[2], q[3]], Vector3.UP, col, [a1, a1, a1, a1])
	_soot_quad(pk, kit, "soot", [p[0], p[1], p[2], p[3]], Vector3.DOWN, col.darkened(0.2), [a0, a0, a0, a0])


## The four sides of a rectangular frustum from (half sizes) b0 at y0 to b1 at y1, sooted a0 at the foot to a1 at the top;
## `inward` faces them in (an inner lining).
static func _frustum_soot(pk: PropKit, kit: Dictionary, key: String, y0: float, b0: Vector2, y1: float, b1: Vector2, col: Color, a0: float, a1: float, inward := false) -> void:
	var cs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	var bands := 3
	for i in range(4):
		var ca: Vector2 = cs[i]
		var cb: Vector2 = cs[(i + 1) % 4]
		for k in range(bands):
			var ta: float = float(k) / float(bands)
			var tb: float = float(k + 1) / float(bands)
			var ya: float = lerpf(y0, y1, ta)
			var yb: float = lerpf(y0, y1, tb)
			var ba: Vector2 = b0.lerp(b1, ta)
			var bb: Vector2 = b0.lerp(b1, tb)
			var p0 := Vector3(ca.x * ba.x, ya, ca.y * ba.y)
			var p1 := Vector3(cb.x * ba.x, ya, cb.y * ba.y)
			var p2 := Vector3(cb.x * bb.x, yb, cb.y * bb.y)
			var p3 := Vector3(ca.x * bb.x, yb, ca.y * bb.y)
			var mid: Vector3 = (p0 + p1 + p2 + p3) * 0.25
			var n: Vector3 = (p1 - p0).cross(p3 - p0).normalized()
			if n.dot(Vector3(mid.x, 0, mid.z)) < 0.0:
				n = -n
			if inward:
				n = -n
			var aa: float = lerpf(a0, a1, ta)
			var ab: float = lerpf(a0, a1, tb)
			_soot_quad(pk, kit, key, [p0, p1, p2, p3], n, col, [aa, aa, ab, ab])


## The flat top of a rectangular wall ring between the outer half sizes `bo` and the inner `bi` at y.
static func _rim(pk: PropKit, kit: Dictionary, y: float, bo: Vector2, bi: Vector2, col: Color) -> void:
	var cs := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for i in range(4):
		var ca: Vector2 = cs[i]
		var cb: Vector2 = cs[(i + 1) % 4]
		_soot_quad(pk, kit, "soot", [Vector3(ca.x * bo.x, y, ca.y * bo.y), Vector3(cb.x * bo.x, y, cb.y * bo.y), Vector3(cb.x * bi.x, y, cb.y * bi.y), Vector3(ca.x * bi.x, y, ca.y * bi.y)],
				Vector3.UP, col, [1.0, 1.0, 1.0, 1.0])


# ======================================================================================
#  The coke wharf
# ======================================================================================

## The coke wharf (Kokskai), x 0..length along the quench track. Its frame's y = 0 is the LOWER yard where the belt runs;
## the quench track runs on the upper level beside its back at z = WHARF_TRACK_Z (3.0), rail level y = WHARF_TRACK_Y (4.6):
## the quench car's gates (on its -z side) open over the lip. From the lip (z 0, y 5.9: the back wall's top, "6m at its
## back") the cast-iron plated slope falls at 28 degrees toward -z to the gates along its foot (z -9.0, y 1.1), which let the
## coke onto the belt conveyor (z -10.55, belt top 0.9); a walkway and railing on its far side (to z -12.6). Cheek walls
## close both ends. Grey coke lies in heaps on the slope (wharf_steam_spots() for the steam off them). Placed with its
## frame 4.6m under the quench track's ground (the plant on a terrace over the lower yard), the car can dump onto it; set
## at the track's own ground it still reads as a wharf (a 5.9m wall beside the track), but the car could not reach it.
static func coke_wharf(pk: PropKit, kit: Dictionary, length := 60.0) -> void:
	var W: float = maxf(length, 10.0)
	var lip_y := 5.9
	var foot_z := -9.0
	var foot_y := 1.1
	_blk(pk, kit, "concrete", Vector3(0.0, -1.0, 0.0), Vector3(W, lip_y, 1.0), CONCRETE)
	_blk(pk, kit, "steel", Vector3(0.0, lip_y - 0.02, -0.08), Vector3(W, lip_y + 0.1, 0.25), CAST)
	# The slope's plates in bays, the dividing ribs between them.
	var bay := 2.5
	var nb: int = maxi(int(round(W / bay)), 1)
	var sn := Vector3(0, -foot_z, lip_y - foot_y).normalized()
	sn = Vector3(0, absf(sn.y), -absf(sn.z))
	for k in range(nb):
		var xa: float = W * float(k) / float(nb)
		var xb: float = W * float(k + 1) / float(nb)
		pk.quad(kit, "rusty", [Vector3(xa, lip_y, 0.0), Vector3(xb, lip_y, 0.0), Vector3(xb, foot_y, foot_z), Vector3(xa, foot_y, foot_z)], sn,
				Color(0.20, 0.18, 0.17) if k % 2 == 0 else Color(0.23, 0.20, 0.18))
		if k > 0:
			pk.beam(kit, "steel", Vector3(xa, lip_y, -0.05) + sn * 0.075, Vector3(xa, foot_y, foot_z + 0.05) + sn * 0.075, 0.12, 0.15, CAST, Vector3.RIGHT)
	# Cheek walls at both ends.
	var cheek := PackedVector2Array([Vector2(1.0, -1.0), Vector2(1.0, lip_y + 1.3), Vector2(foot_z - 0.6, foot_y + 1.3), Vector2(foot_z - 0.6, -1.0)])
	_prism_x(pk, kit, "concrete", cheek, -0.5, 0.0, CONCRETE.darkened(0.04))
	_prism_x(pk, kit, "concrete", cheek, W, W + 0.5, CONCRETE.darkened(0.04))
	# The gate wall along the foot and the gates (bottom-hung flaps with counterweights) over the belt.
	_blk(pk, kit, "concrete", Vector3(0.0, -1.0, foot_z - 0.5), Vector3(W, foot_y, foot_z), CONCRETE.darkened(0.06))
	for k in range(nb):
		var xc: float = W * (float(k) + 0.5) / float(nb)
		_blk(pk, kit, "steel", Vector3(xc - 0.9, 0.55, foot_z - 0.62), Vector3(xc + 0.9, foot_y + 0.02, foot_z - 0.56), STEEL_DARK)
		pk.tube(kit, "steel", Vector3(xc - 0.95, foot_y, foot_z - 0.6), Vector3(xc + 0.95, foot_y, foot_z - 0.6), 0.045, 0.045, 6, CAST, true)
		pk.beam(kit, "steel", Vector3(xc + 0.6, foot_y, foot_z - 0.62), Vector3(xc + 0.6, foot_y + 0.55, foot_z - 1.05), 0.06, 0.06, CAST)
		_blk(pk, kit, "steel", Vector3(xc + 0.48, foot_y + 0.5, foot_z - 1.18), Vector3(xc + 0.72, foot_y + 0.72, foot_z - 0.94), STEEL)
	# The belt conveyor: stringers, idlers every 3m, the troughed belt with a thin layer of coke, the return belt.
	var bz := -10.55
	for sz in [-0.8, 0.8]:
		_blk(pk, kit, "steel", Vector3(0.0, 0.55, bz + sz - 0.05), Vector3(W, 0.68, bz + sz + 0.05), STEEL)
	var xi := 1.5
	while xi < W:
		_blk(pk, kit, "steel", Vector3(xi - 0.06, 0.68, bz - 0.85), Vector3(xi + 0.06, 0.8, bz + 0.85), STEEL_DARK)
		for sz in [-0.8, 0.8]:
			_blk(pk, kit, "steel", Vector3(xi - 0.05, 0.0, bz + sz - 0.05), Vector3(xi + 0.05, 0.55, bz + sz + 0.05), STEEL)
		xi += 3.0
	_blk(pk, kit, "rubber", Vector3(0.0, 0.84, bz - 0.35), Vector3(W, 0.87, bz + 0.35), Color(0.07, 0.07, 0.07))
	for sz in [-1.0, 1.0]:
		var wing_c := Vector3(W * 0.5, 0.96, bz + sz * 0.52)
		var across := Vector3(0, 0.45, sz * 0.89).normalized()
		pk.beam(kit, "rubber", Vector3(0.0, wing_c.y, wing_c.z), Vector3(W, wing_c.y, wing_c.z), 0.38, 0.03, Color(0.07, 0.07, 0.07), across)
	_blk(pk, kit, "coke", Vector3(0.05, 0.87, bz - 0.28), Vector3(W - 0.05, 0.95, bz + 0.28), Color(COKE.r, COKE.g, COKE.b, 0.8))
	_blk(pk, kit, "rubber", Vector3(0.0, 0.28, bz - 0.38), Vector3(W, 0.31, bz + 0.38), Color(0.07, 0.07, 0.07))
	# The walkway beyond, its railing.
	_blk(pk, kit, "concrete", Vector3(0.0, -0.2, -12.6), Vector3(W, 0.12, -11.55), CONCRETE.darkened(0.1))
	_rail_line(pk, kit, [Vector3(0.0, 0.12, -12.5), Vector3(W, 0.12, -12.5)], 1.1, CRANE_YELLOW, "paint", 2.5)
	# Coke on the slope: heaps thickest toward the gates, some bare plates between.
	_wharf_coke(pk, kit, W, lip_y, foot_y, foot_z, sn)
	# Lamp masts on the back wall lighting the slope.
	for xm in [W * 0.3, W * 0.7]:
		pk.beam(kit, "steel", Vector3(xm, lip_y, 0.6), Vector3(xm, lip_y + 6.9, 0.6), 0.16, 0.16, STEEL_DARK)
		_blk(pk, kit, "steel", Vector3(xm - 0.35, lip_y + 6.6, 0.2), Vector3(xm + 0.35, lip_y + 7.0, 0.55), STEEL_DARK)
		_blk(pk, kit, "lens", Vector3(xm - 0.28, lip_y + 6.62, 0.17), Vector3(xm + 0.28, lip_y + 6.95, 0.2), Color(0.85, 0.85, 0.8))


## The heaps: [x middle, t down the slope 0..1, radius along x, height].
static func _wharf_heaps(W: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(W * 10.0) + 77
	var out: Array = []
	var x := rng.randf_range(4.0, 8.0)
	while x < W - 3.0:
		out.append([x, rng.randf_range(0.55, 0.85), rng.randf_range(4.0, 7.5), rng.randf_range(0.7, 1.4)])
		x += rng.randf_range(9.0, 15.0)
	return out


static func _wharf_coke(pk: PropKit, kit: Dictionary, W: float, lip_y: float, foot_y: float, foot_z: float, sn: Vector3) -> void:
	var heaps: Array = _wharf_heaps(W)
	var nx: int = maxi(int(ceil((W - 1.2) / 0.8)), 2)
	var nt := 10
	var grid: Array = []
	var thick: Array = []
	var cols: Array = []
	for i in range(nx + 1):
		var row: Array = []
		var trow: Array = []
		var crow: Array = []
		var x: float = lerpf(0.6, W - 0.6, float(i) / float(nx))
		for k in range(nt + 1):
			var t: float = lerpf(0.06, 0.985, float(k) / float(nt))
			var h := 0.0
			for hp in heaps:
				var dx: float = (x - float(hp[0])) / float(hp[2])
				var dt: float = (t - float(hp[1])) / 0.45
				h += float(hp[3]) * exp(-(dx * dx + dt * dt))
			# A skin spread along the foot, piled against the gates.
			h += 0.3 * smoothstep(0.62, 1.0, t)
			h += 0.09 * sin(x * 1.9 + t * 7.0) * cos(x * 0.7 - t * 3.0) + 0.07 * sin(x * 3.7 + t * 13.0) * sin(x * 2.3 - t * 17.0 + 1.1)
			h *= 0.9 + 0.2 * sin(x * 0.31 + 0.4)
			var base := Vector3(x, lerpf(lip_y, foot_y, t), lerpf(0.0, foot_z, t))
			row.append(base + sn * maxf(h, 0.02))
			trow.append(h)
			var wet: float = clampf(0.25 + 0.55 * (0.5 + 0.5 * sin(x * 0.45 + t * 3.0)), 0.0, 1.0)
			var g: float = 0.88 + 0.24 * (0.5 + 0.5 * sin(x * 1.3 - t * 5.0))
			crow.append(Color(COKE.r * g, COKE.g * g, COKE.b * g, wet))
		grid.append(row)
		thick.append(trow)
		cols.append(crow)
	var keep := func(i: int, k: int) -> bool:
		return minf(minf(thick[i][k], thick[i + 1][k]), minf(thick[i][k + 1], thick[i + 1][k + 1])) >= 0.12
	_grid_surface(pk, kit, "coke", grid, cols, sn, keep)


# ======================================================================================
#  Track
# ======================================================================================

## Standard-gauge track along +x from 0 to `length` (the cars' and the quench car's line), at y = 0 the ground beside it:
## a ballast bed (top 5cm over the ground, 1.6m either side, its shoulders sinking to 2.3m out), timber sleepers every
## 0.65m, rails at z +-0.7175 with their running surface at y 0.2 (RAIL_TOP). Name the node without "track"/"line".
static func kokerei_rails(pk: PropKit, kit: Dictionary, length: float) -> void:
	var T := 1.6
	var F := 2.3
	var yt := 0.05
	var yf := -0.3
	var nseg: int = maxi(int(ceil(length / 10.0)), 1)
	var sn_l := Vector3(0, 0.9, -1.0).normalized()
	var sn_r := Vector3(0, 0.9, 1.0).normalized()
	for k in range(nseg):
		var x0: float = length * float(k) / float(nseg)
		var x1: float = length * float(k + 1) / float(nseg)
		var col: Color = FreightKit.ballast_colour(Vector3(x0, 0, 0)).darkened(0.25)
		pk.quad(kit, "kballast", [Vector3(x0, yt, -T), Vector3(x1, yt, -T), Vector3(x1, yt, T), Vector3(x0, yt, T)], Vector3.UP, col,
				[Vector2(-T * uvk, 99), Vector2(-T * uvk, 99), Vector2(T * uvk, 99), Vector2(T * uvk, 99)])
		pk.quad(kit, "kballast", [Vector3(x0, yf, -F), Vector3(x1, yf, -F), Vector3(x1, yt, -T), Vector3(x0, yt, -T)], sn_l, col,
				[Vector2(-F * uvk, 99), Vector2(-F * uvk, 99), Vector2(-T * uvk, 99), Vector2(-T * uvk, 99)])
		pk.quad(kit, "kballast", [Vector3(x0, yt, T), Vector3(x1, yt, T), Vector3(x1, yf, F), Vector3(x0, yf, F)], sn_r, col,
				[Vector2(T * uvk, 99), Vector2(T * uvk, 99), Vector2(F * uvk, 99), Vector2(F * uvk, 99)])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(length * 7.0) + 3
	var x := 0.33
	while x < length - 0.1:
		_sleeper(pk, kit, Vector3(x, 0.12, 0.0), 1.3, 0.13, 0.15, FreightKit.SLEEPER * (0.85 + rng.randf() * 0.3), rng.randf() * 40.0)
		x += 0.65
	for sz in [-1.0, 1.0]:
		var z: float = sz * GAUGE_HALF
		_blk(pk, kit, "rail", Vector3(0.0, 0.12, z - 0.065), Vector3(length, 0.135, z + 0.065), RAIL_COL.darkened(0.15))
		_blk(pk, kit, "rail", Vector3(0.01, 0.13, z - 0.009), Vector3(length - 0.01, RAIL_TOP - 0.045, z + 0.009), RAIL_COL)
		_rail_head(pk, kit, 0.01, length - 0.01, z, RAIL_TOP, 0.033, 0.045)


## A sleeper across the track: its top's middle at c, `half_len` along z, `half_w` along x, `h` deep; UVs in metres.
static func _sleeper(pk: PropKit, kit: Dictionary, c: Vector3, half_len: float, half_w: float, h: float, col: Color, u0: float) -> void:
	var l := Vector3(0, 0, half_len)
	var w := Vector3(half_w, 0, 0)
	var dn := Vector3(0, -h, 0)
	var t00: Vector3 = c - l - w
	var t10: Vector3 = c + l - w
	var t11: Vector3 = c + l + w
	var t01: Vector3 = c - l + w
	var L2: float = half_len * 2.0 * uvk
	var W2: float = half_w * 2.0 * uvk
	var H: float = h * uvk
	pk.quad(kit, "sleeper", [t00, t10, t11, t01], Vector3.UP, col, [Vector2(u0, 0), Vector2(u0, L2), Vector2(u0 + W2, L2), Vector2(u0 + W2, 0)])
	pk.quad(kit, "sleeper", [t00 + dn, t10 + dn, t10, t00], Vector3(-1, 0, 0), col.darkened(0.12), [Vector2(u0, 0), Vector2(u0, L2), Vector2(u0 + H, L2), Vector2(u0 + H, 0)])
	pk.quad(kit, "sleeper", [t11 + dn, t01 + dn, t01, t11], Vector3(1, 0, 0), col.darkened(0.12), [Vector2(u0, L2), Vector2(u0, 0), Vector2(u0 + H, 0), Vector2(u0 + H, L2)])
	pk.quad(kit, "sleeper", [t10 + dn, t11 + dn, t11, t10], Vector3(0, 0, 1), col.darkened(0.2), [Vector2(u0, 0), Vector2(u0 + W2, 0), Vector2(u0 + W2, H), Vector2(u0, H)])
	pk.quad(kit, "sleeper", [t01 + dn, t00 + dn, t00, t01], Vector3(0, 0, -1), col.darkened(0.2), [Vector2(u0, 0), Vector2(u0 + W2, 0), Vector2(u0 + W2, H), Vector2(u0, H)])


# ======================================================================================
#  The emergency gas flare
# ======================================================================================

## The emergency flare (Notfackel), its origin on the ground at the stack's foot: a concrete pad, the flare stack inside a
## four-legged lattice derrick (to 27.3m, a platform there with railing and red lamps), the tip with its wind shield and
## three pilot burners to 30.4m (flare_point() for the flame), a ladder up the +z face, the knock-out drum on saddles at
## +x (its inlet at flare_inlet()) and the water seal pot at -x. Name its node without "flare" (DressingColliders skips
## "flare": "Notfackel" works).
static func gas_flare(pk: PropKit, kit: Dictionary) -> void:
	_blk(pk, kit, "concrete", Vector3(-2.6, -1.0, -2.6), Vector3(2.6, 0.3, 2.6), CONCRETE)
	SteelworksKit._tower(pk, kit, "steel", Vector3(0, 0.3, 0), 27.0, 2.1, 0.75, 3.0, STEEL, 0.22, 0.1, false)
	for c in [Vector2(-2.1, -2.1), Vector2(2.1, -2.1), Vector2(2.1, 2.1), Vector2(-2.1, 2.1)]:
		_blk(pk, kit, "steel", Vector3(c.x - 0.35, 0.3, c.y - 0.35), Vector3(c.x + 0.35, 0.42, c.y + 0.35), STEEL_DARK)
	_blk(pk, kit, "steel", Vector3(-0.7, 0.3, -0.7), Vector3(0.7, 0.55, 0.7), STEEL_DARK)
	SteelworksKit._pipe(pk, kit, "rusty", [Vector3(0, 0.55, 0), Vector3(0, 29.0, 0)], 0.42, SILVER, 12, 6.0, false)
	# The tip and its shield, the burner ring glowing faintly.
	pk.tube(kit, "steel", Vector3(0, 28.9, 0), Vector3(0, 30.2, 0), 0.5, 0.5, 12, Color(0.3, 0.27, 0.24), false)
	pk.lathe(kit, "hot", Vector3(0, 30.2, 0), [Vector2(0.5, 0.0), Vector2(0.001, 0.0)], 12, SteelworksKit.hot_colour(0.2), true)
	pk.lathe(kit, "steel", Vector3(0, 29.5, 0), [Vector2(0.8, 0.0), Vector2(0.8, 0.9), Vector2(0.76, 0.9)], 12, Color(0.22, 0.2, 0.19), true)
	pk.lathe(kit, "steel", Vector3(0, 29.5, 0), [Vector2(0.76, 0.9), Vector2(0.76, 0.0)], 12, Color(0.12, 0.11, 0.1), true)
	for k in range(4):
		var a: float = TAU * float(k) / 4.0 + 0.4
		pk.beam(kit, "steel", Vector3(cos(a) * 0.5, 29.6, sin(a) * 0.5), Vector3(cos(a) * 0.78, 29.6, sin(a) * 0.78), 0.06, 0.06, STEEL_DARK)
	for k in range(3):
		var a2: float = TAU * float(k) / 3.0
		var pc := Vector3(cos(a2) * 0.62, 0, sin(a2) * 0.62)
		pk.tube(kit, "steel", pc + Vector3(0, 1.0, 0), pc + Vector3(0, 30.25, 0), 0.045, 0.045, 6, STEEL, true)
		_blk(pk, kit, "steel", pc + Vector3(-0.07, 30.25, -0.07), pc + Vector3(0.07, 30.45, 0.07), CAST)
	# Platform under the tip, its railing and lamps; the ladder up the +z face.
	_blk(pk, kit, "steel", Vector3(-1.4, 27.2, -1.4), Vector3(1.4, 27.32, 1.4), STEEL_DARK)
	_rail_line(pk, kit, [Vector3(-1.35, 27.32, -1.35), Vector3(1.35, 27.32, -1.35), Vector3(1.35, 27.32, 1.35), Vector3(-1.35, 27.32, 1.35), Vector3(-1.35, 27.32, -1.35)], 1.05, STEEL_DARK, "steel", 2.8)
	for c2 in [Vector3(-1.3, 28.4, -1.3), Vector3(1.3, 28.4, 1.3)]:
		_blk(pk, kit, "lamp", c2 + Vector3(-0.12, 0, -0.12), c2 + Vector3(0.12, 0.24, 0.12), Color(1.0, 0.15, 0.1))
	SteelworksKit._slant_ladder(pk, kit, Vector3(0.0, 0.3, 2.3), Vector3(0.0, 27.2, 1.45), STEEL_DARK)
	# The knock-out drum (horizontal, on saddles) and its pipe into the stack's foot.
	var ab := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
	pk.lathe(kit, "shell", Vector3(4.6, 1.6, 0), [Vector2(0.001, -2.9), Vector2(0.6, -2.8), Vector2(1.0, -2.55), Vector2(1.1, -2.3), Vector2(1.1, 2.3), Vector2(1.0, 2.55),
			Vector2(0.6, 2.8), Vector2(0.001, 2.9)], 14, Color(0.40, 0.42, 0.40), false, ab)
	for xs in [3.0, 6.2]:
		_blk(pk, kit, "concrete", Vector3(xs - 0.4, -0.6, -1.0), Vector3(xs + 0.4, 0.9, 1.0), CONCRETE)
	SteelworksKit._pipe(pk, kit, "rusty", [Vector3(3.6, 2.6, 0), Vector3(3.6, 3.4, 0), Vector3(0.45, 3.4, 0)], 0.3, PIPE_RUST, 10, 0.0, true)
	pk.tube(kit, "rusty", Vector3(7.3, 1.6, 0), Vector3(7.5, 1.6, 0), 0.3, 0.3, 10, PIPE_RUST, false)
	pk.tube(kit, "rusty", Vector3(7.5, 1.6, 0), Vector3(7.6, 1.6, 0), 0.38, 0.38, 10, PIPE_RUST.darkened(0.15), true)
	# The water seal pot.
	pk.lathe(kit, "shell", Vector3(-3.8, 0.0, 1.0), [Vector2(0.9, 0.0), Vector2(0.9, 3.2), Vector2(0.6, 3.55), Vector2(0.001, 3.65)], 12, Color(0.36, 0.40, 0.37), false)
	_blk(pk, kit, "concrete", Vector3(-4.8, -0.6, 0.0), Vector3(-2.8, 0.1, 2.0), CONCRETE)
	SteelworksKit._pipe(pk, kit, "rusty", [Vector3(-3.8, 3.3, 1.0), Vector3(-3.8, 4.2, 1.0), Vector3(-0.4, 4.2, 0.3)], 0.2, PIPE_RUST, 8, 0.0, true)


# ======================================================================================
#  The by-product plant
# ======================================================================================

## The by-product plant (Nebengewinnung), its origin on the ground at its middle (x -42..42, z -28..30; the gas flows
## toward +x): the crossover main arriving at byproduct_gas_inlet() up to the header over three primary coolers, two
## electrostatic tar precipitators, the brick exhauster house (Gassaugerhaus), four tall washers (ammonia, benzol,
## naphthalene) with ring platforms and ladders, the main pipe rack along z 4 (the clean gas leaving at
## byproduct_gas_outlet()), a small cooling tower for the coolers' water, the tank farm (tar and benzol tanks in a bund
## wall) to the south, the control room (Messwarte) and a brick chimney. Tallest parts 34.6m (the benzol washer).
static func byproduct_plant(pk: PropKit, kit: Dictionary, labels: Array) -> void:
	# Primary coolers: three tall cylinders on a plinth, the gas header over them, the inlet main rising to it.
	for zc in [8.0, 16.0, 24.0]:
		var c := Vector3(-31.0, 0.0, zc)
		_vessel(pk, kit, c, 2.3, 22.0, Color(0.33, 0.37, 0.35), "dome")
		_ring_walk(pk, kit, c + Vector3(0, 11.0, 0), 2.32, 3.2, 16)
		_ladder(pk, kit, c + Vector3(-2.3, 0.4, 0), c + Vector3(-2.3, 22.6, 0), Vector3(-1, 0, 0), 0.5)
		pk.tube(kit, "rusty", c + Vector3(0, 23.6, 0), c + Vector3(0, 25.0, 0), 0.5, 0.5, 10, PIPE_RUST, false)
		SteelworksKit._pipe(pk, kit, "rusty", [c + Vector3(2.3, 1.6, 0), c + Vector3(3.6, 1.6, 0), c + Vector3(3.6, 1.6, -2.4)], 0.42, PIPE_RUST, 10, 0.0, true)
	SteelworksKit._pipe(pk, kit, "rusty", [Vector3(-31.0, 25.6, 27.2), Vector3(-31.0, 25.6, 5.0)], 0.75, MAIN_COL, 14, 6.0, true)
	SteelworksKit._pipe(pk, kit, "rusty", [byproduct_gas_inlet(), Vector3(-37.0, 10.5, 22.0), Vector3(-37.0, 25.6, 22.0), Vector3(-31.8, 25.6, 22.0)], 0.75, MAIN_COL, 14, 6.0, true)
	for zs in [21.0, 13.0]:
		_blk(pk, kit, "steel", Vector3(-37.3, 0.0, zs - 0.2), Vector3(-36.7, 24.8, zs + 0.2), STEEL)
	_blk(pk, kit, "steel", Vector3(-37.4, 24.8, 12.6), Vector3(-30.4, 25.1, 21.4), STEEL_DARK)
	_blk(pk, kit, "concrete", Vector3(-35.0, -0.5, 4.0), Vector3(-27.0, 0.3, 28.0), CONCRETE)
	# Electrostatic tar precipitators.
	for zc in [11.0, 20.0]:
		var c2 := Vector3(-20.0, 0.0, zc)
		_vessel(pk, kit, c2, 2.0, 14.0, Color(0.30, 0.31, 0.30), "cone")
		_blk(pk, kit, "paint", c2 + Vector3(-1.2, 15.2, -1.2), c2 + Vector3(1.2, 16.8, 1.2), Color(0.40, 0.42, 0.40))
		_ring_walk(pk, kit, c2 + Vector3(0, 14.0, 0), 2.02, 2.9, 14)
		_ladder(pk, kit, c2 + Vector3(0, 0.4, -2.0), c2 + Vector3(0, 14.0, -2.0), Vector3(0, 0, -1), 0.5)
		SteelworksKit._pipe(pk, kit, "rusty", [c2 + Vector3(-2.0, 2.2, 0), Vector3(-27.4, 2.2, zc)], 0.42, PIPE_RUST, 10, 0.0, true)
	# The exhauster house.
	_brick_hall(pk, kit, labels, -12.0, 12.0, 8.0, 22.0, 9.5, 12.6)
	SteelworksKit._pipe(pk, kit, "rusty", [Vector3(-18.0, 3.0, 15.5), Vector3(-12.3, 3.0, 15.5)], 0.6, PIPE_RUST, 12, 0.0, true)
	# The washers in a row, linked over the top and at the foot.
	var washers: Array = [[18.0, 2.1, 30.0], [25.5, 1.8, 34.0], [32.5, 1.8, 32.0], [39.0, 1.5, 26.0]]
	for w in washers:
		var c3 := Vector3(w[0], 0.0, 17.0)
		var r: float = w[1]
		var h: float = w[2]
		_vessel(pk, kit, c3, r, h, Color(0.36, 0.38, 0.36) if r > 1.9 else Color(0.62, 0.62, 0.60), "dome")
		var yp := 10.0
		while yp < h - 1.0:
			_ring_walk(pk, kit, c3 + Vector3(0, yp, 0), r + 0.02, r + 1.0, 14)
			yp += 9.0
		_ring_walk(pk, kit, c3 + Vector3(0, h - 0.6, 0), r + 0.02, r + 0.9, 14)
		_ladder(pk, kit, c3 + Vector3(0, 0.4, -r), c3 + Vector3(0, h - 0.6, -r), Vector3(0, 0, -1), 0.5)
		pk.tube(kit, "steel", c3 + Vector3(0.6, h + r * 0.4, 0), c3 + Vector3(0.6, h + r * 0.4 + 1.6, 0), 0.12, 0.12, 6, STEEL_DARK, true)
	for k in range(washers.size() - 1):
		var a: Array = washers[k]
		var b: Array = washers[k + 1]
		var ytop: float = minf(float(a[2]), float(b[2])) - 1.5
		SteelworksKit._pipe(pk, kit, "rusty", [Vector3(float(a[0]) + float(a[1]), ytop, 17.0), Vector3((float(a[0]) + float(b[0])) * 0.5, ytop, 17.0),
				Vector3((float(a[0]) + float(b[0])) * 0.5, 2.0, 17.0), Vector3(float(b[0]) - float(b[1]), 2.0, 17.0)], 0.32, PIPE_RUST, 10, 0.0, true)
	SteelworksKit._pipe(pk, kit, "rusty", [Vector3(12.3, 6.5, 19.5), Vector3(16.8, 6.5, 19.5), Vector3(17.6, 6.5, 18.9)], 0.5, PIPE_RUST, 12, 0.0, true)
	_blk(pk, kit, "concrete", Vector3(15.0, -0.5, 13.5), Vector3(41.0, 0.3, 20.5), CONCRETE)
	# The main pipe rack along z 4, the gas leaving at its +x end.
	var xr := -36.0
	while xr <= 40.01:
		for zc2 in [2.8, 5.2]:
			_blk(pk, kit, "steel", Vector3(xr - 0.15, 0.0, zc2 - 0.15), Vector3(xr + 0.15, 5.7, zc2 + 0.15), STEEL)
			_blk(pk, kit, "concrete", Vector3(xr - 0.4, -0.5, zc2 - 0.4), Vector3(xr + 0.4, 0.2, zc2 + 0.4), CONCRETE)
		_blk(pk, kit, "steel", Vector3(xr - 0.12, 5.7, 2.4), Vector3(xr + 0.12, 6.0, 5.6), STEEL)
		xr += 6.0
	for zc3 in [2.6, 5.4]:
		_blk(pk, kit, "steel", Vector3(-36.2, 5.75, zc3 - 0.1), Vector3(40.2, 5.95, zc3 + 0.1), STEEL)
	var rack_pipes: Array = [[2.9, 0.3, PIPE_RUST], [3.65, 0.25, Color(0.62, 0.55, 0.15)], [4.35, 0.22, SILVER], [5.1, 0.3, Color(0.28, 0.40, 0.55)]]
	for rp in rack_pipes:
		var pr: float = rp[1]
		pk.tube(kit, "rusty", Vector3(-36.5, 6.0 + pr + 0.03, rp[0]), Vector3(40.5, 6.0 + pr + 0.03, rp[0]), pr, pr, 8, rp[2], true)
	SteelworksKit._pipe(pk, kit, "rusty", [Vector3(39.0, 2.0, 15.6), Vector3(39.0, 2.0, 11.0), Vector3(39.0, 7.2, 11.0), Vector3(39.0, 7.2, 4.0), byproduct_gas_outlet()], 0.45, MAIN_COL, 12, 0.0, true)
	# The cooling tower for the coolers' water: a basin, a louvred timber box, the fan stack.
	_blk(pk, kit, "concrete", Vector3(-38.6, -0.5, -4.6), Vector3(-29.4, 1.0, 1.6), CONCRETE)
	_blk(pk, kit, "matte", Vector3(-38.3, 0.0, -4.3), Vector3(-29.7, 1.03, 1.3), Color(0.10, 0.12, 0.12))
	for c4 in [Vector2(-38.0, -4.0), Vector2(-30.0, -4.0), Vector2(-38.0, 1.0), Vector2(-30.0, 1.0)]:
		_blk(pk, kit, "timber", Vector3(c4.x - 0.2, 1.0, c4.y - 0.2), Vector3(c4.x + 0.2, 9.0, c4.y + 0.2), Color(0.30, 0.27, 0.22))
	var y4 := 1.4
	while y4 < 8.8:
		_slat(pk, kit, "timber", Vector3(-34.0, y4, 1.0), Vector3(1, 0, 0), Vector3(0, 0, 1), 7.6, 0.5, 0.04, deg_to_rad(35.0), Color(0.32, 0.28, 0.22))
		_slat(pk, kit, "timber", Vector3(-34.0, y4, -4.0), Vector3(-1, 0, 0), Vector3(0, 0, -1), 7.6, 0.5, 0.04, deg_to_rad(35.0), Color(0.32, 0.28, 0.22))
		_slat(pk, kit, "timber", Vector3(-30.0, y4, -1.5), Vector3(0, 0, -1), Vector3(1, 0, 0), 4.6, 0.5, 0.04, deg_to_rad(35.0), Color(0.32, 0.28, 0.22))
		_slat(pk, kit, "timber", Vector3(-38.0, y4, -1.5), Vector3(0, 0, 1), Vector3(-1, 0, 0), 4.6, 0.5, 0.04, deg_to_rad(35.0), Color(0.32, 0.28, 0.22))
		y4 += 0.6
	pk.quad(kit, "matte", [Vector3(-37.5, 1.0, 0.5), Vector3(-30.5, 1.0, 0.5), Vector3(-30.5, 9.0, 0.5), Vector3(-37.5, 9.0, 0.5)], Vector3(0, 0, -1), Color(0.03, 0.03, 0.03))
	pk.quad(kit, "matte", [Vector3(-37.5, 1.0, -3.5), Vector3(-30.5, 1.0, -3.5), Vector3(-30.5, 9.0, -3.5), Vector3(-37.5, 9.0, -3.5)], Vector3(0, 0, 1), Color(0.03, 0.03, 0.03))
	_blk(pk, kit, "timber", Vector3(-38.3, 9.0, -4.3), Vector3(-29.7, 9.3, 1.3), Color(0.26, 0.23, 0.19))
	pk.lathe(kit, "timber", Vector3(-34.0, 9.3, -1.5), [Vector2(1.7, 0.0), Vector2(1.7, 2.6), Vector2(1.85, 2.7), Vector2(1.6, 2.7)], 14, Color(0.28, 0.25, 0.20), true)
	pk.lathe(kit, "matte", Vector3(-34.0, 11.9, -1.5), [Vector2(1.6, 0.0), Vector2(1.6, -1.6), Vector2(0.001, -1.6)], 14, Color(0.04, 0.04, 0.04), true)
	# The tank farm: a bund wall, two tar tanks, three benzol tanks, an ammonia water tank.
	for e in [[Vector3(-38.0, -0.5, -28.0), Vector3(40.0, 1.3, -27.7)], [Vector3(-38.0, -0.5, -5.3), Vector3(40.0, 1.3, -5.0)],
			[Vector3(-38.0, -0.5, -27.7), Vector3(-37.7, 1.3, -5.3)], [Vector3(39.7, -0.5, -27.7), Vector3(40.0, 1.3, -5.3)]]:
		_blk(pk, kit, "concrete", e[0], e[1], CONC_DARK)
	var tanks: Array = [[-28.0, -17.0, 6.5, 9.0, TAR, "TEER 1"], [-12.0, -17.0, 6.5, 9.0, TAR, "TEER 2"], [4.0, -17.0, 4.2, 8.0, SILVER, "BENZOL 1"],
			[15.0, -17.0, 4.2, 8.0, SILVER, "BENZOL 2"], [26.0, -17.0, 4.2, 8.0, SILVER, "BENZOL 3"], [35.5, -11.0, 2.6, 6.5, Color(0.36, 0.42, 0.38), "AMMONIAKWASSER"]]
	for t in tanks:
		_tank(pk, kit, labels, Vector3(t[0], 0.0, t[1]), t[2], t[3], t[4], t[5])
	SteelworksKit.pipe_run(pk, kit, PackedVector3Array([Vector3(-28.0, 1.4, -10.4), Vector3(-28.0, 1.4, -3.0), Vector3(30.0, 1.4, -3.0), Vector3(30.0, 1.4, -10.0)]), 0.25)
	# The control room, the chimney.
	_control_room(pk, kit, labels, Vector3(22.0, 0, 23.5), Vector3(38.0, 0, 29.5))
	_chimney_at(pk, kit, Vector3(2.0, 0.0, 27.0), 32.0)


static func _chimney_at(pk: PropKit, kit: Dictionary, p: Vector3, h: float) -> void:
	var saved: Array = SteelworksKit._push(pk, Transform3D(Basis(), p))
	SteelworksKit.chimney(pk, kit, h, 0)
	SteelworksKit._pop(pk, saved)


## A vertical vessel standing at c (its foot): a concrete plinth ring, the shell, a domed / conical / flat top, flanged
## nozzles at the foot and the top.
static func _vessel(pk: PropKit, kit: Dictionary, c: Vector3, r: float, h: float, col: Color, top := "dome") -> void:
	var segs := 18 if r > 1.8 else 14
	pk.lathe(kit, "concrete", c, [Vector2(r + 0.5, -0.6), Vector2(r + 0.5, 0.35), Vector2(r - 0.2, 0.35)], segs, CONCRETE, true)
	pk.lathe(kit, "shell", c, [Vector2(r, 0.35), Vector2(r, h * 0.5), Vector2(r, h)], segs, col)
	for yb in [h * 0.33, h * 0.66]:
		pk.tube(kit, "shell", c + Vector3(0, yb - 0.06, 0), c + Vector3(0, yb + 0.06, 0), r + 0.04, r + 0.04, segs, col.darkened(0.2), false)
	match top:
		"dome":
			pk.lathe(kit, "shell", c + Vector3(0, h, 0), [Vector2(r, 0.0), Vector2(r * 0.86, r * 0.28), Vector2(r * 0.5, r * 0.45), Vector2(0.001, r * 0.52)], segs, col)
		"cone":
			pk.lathe(kit, "shell", c + Vector3(0, h, 0), [Vector2(r, 0.0), Vector2(0.4, r * 0.55), Vector2(0.001, r * 0.55)], segs, col)
		_:
			pk.lathe(kit, "shell", c + Vector3(0, h, 0), [Vector2(r, 0.0), Vector2(0.001, 0.0)], segs, col, true)


## A storage tank at c: a concrete ring footing, the shell, a shallow cone roof with a railing over the stair's head, a
## straight stair up the side, its name on the -z side.
static func _tank(pk: PropKit, kit: Dictionary, labels: Array, c: Vector3, r: float, h: float, col: Color, name: String) -> void:
	var segs := 24 if r > 4.0 else 18
	pk.lathe(kit, "concrete", c, [Vector2(r + 0.4, -0.5), Vector2(r + 0.4, 0.25), Vector2(r - 0.2, 0.25)], segs, CONCRETE, true)
	pk.lathe(kit, "shell", c, [Vector2(r, 0.25), Vector2(r, h)], segs, col)
	pk.lathe(kit, "shell", c + Vector3(0, h, 0), [Vector2(r + 0.08, -0.05), Vector2(r + 0.08, 0.05), Vector2(0.6, r * 0.14), Vector2(0.001, r * 0.15)], segs, col.lightened(0.05))
	pk.tube(kit, "shell", c + Vector3(0, h * 0.5 - 0.08, 0), c + Vector3(0, h * 0.5 + 0.08, 0), r + 0.04, r + 0.04, segs, col.darkened(0.2), false)
	# A straight stair along the tangent at the roof's edge (every step stays outside the shell), toward +z; a small tank
	# has a ladder instead. A railing round the roof's edge by the stair's head.
	var a0 := deg_to_rad(150.0)
	var top := c + Vector3(cos(a0) * (r + 0.55), h, sin(a0) * (r + 0.55))
	if r > 3.0:
		var tang := Vector3(-sin(a0), 0, cos(a0))
		var foot := top - tang * (h / tan(deg_to_rad(50.0)))
		foot.y = c.y
		SteelworksKit._stair(pk, kit, foot, top, 0.8, STEEL, STEEL_DARK)
	else:
		_ladder(pk, kit, c + Vector3(cos(a0) * r, 0.3, sin(a0) * r), c + Vector3(cos(a0) * r, h, sin(a0) * r), Vector3(cos(a0), 0, sin(a0)), 0.45)
	var pts: Array = []
	for k in range(5):
		var a: float = a0 - 0.15 + float(k) * 0.32
		pts.append(c + Vector3(cos(a) * (r - 0.1), h + 0.06, sin(a) * (r - 0.1)))
	_rail_line(pk, kit, pts, 1.05, STEEL_DARK, "steel", 99.0)
	var ln := Vector3(0, 0, -1)
	SteelworksKit._label(labels, name, c + Vector3(0, h * 0.62, -r - 0.06), ln, minf(1.2, (r * 1.2) / maxf(float(name.length()) * 0.72, 1.0)), Color(0.92, 0.9, 0.86) if col.v < 0.4 else Color(0.12, 0.12, 0.12), r * 1.3)


## The exhauster house: a brick hall x0..x1, z0..z1, eaves at `eave`, a slate roof to `ridge` along x, tall windows along
## both long walls, gables with a round window, a door in the +x gable under its name.
static func _brick_hall(pk: PropKit, kit: Dictionary, labels: Array, x0: float, x1: float, z0: float, z1: float, eave: float, ridge: float) -> void:
	var lx: float = x1 - x0
	var lz: float = z1 - z0
	var win: Array = []
	var nw: int = int(lx / 4.0)
	for k in range(nw):
		win.append([Rect2(lx * (float(k) + 0.5) / float(nw) - 1.0, 2.6, 2.0, 4.6), true])
	for zf in [[z1, Vector3(0, 0, 1)], [z0, Vector3(0, 0, -1)]]:
		var p0 := Vector3(x0, 0, zf[0])
		SteelworksKit._wall_holes(pk, kit, "brick", p0, Vector3(1, 0, 0), zf[1], 0.0, lx, -0.3, eave, win, BRICK, 0.4, "brick")
		for h in win:
			var r: Rect2 = h[0]
			var cw: Vector3 = p0 + Vector3(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.5, 0) - (zf[1] as Vector3) * 0.12
			SteelworksKit._glazing(pk, kit, cw, Vector3(1, 0, 0), Vector3.UP, zf[1], r.size.x, r.size.y)
			SteelworksKit._window_frame(pk, kit, cw, Vector3(1, 0, 0), zf[1], r.size.x - 0.2, r.size.y - 0.2, STEEL_DARK, 1, 2)
			_box(pk, kit, "concrete", p0 + Vector3(r.position.x + r.size.x * 0.5, r.position.y - 0.1, 0) + (zf[1] as Vector3) * 0.05, Basis(), Vector3(r.size.x + 0.3, 0.16, 0.3), CONCRETE)
	var door := [[Rect2(lz * 0.5 - 1.6, 0.0, 3.2, 4.2), true]]
	for xf in [[x1, Vector3(1, 0, 0), door], [x0, Vector3(-1, 0, 0), []]]:
		var p1 := Vector3(xf[0], 0, z0)
		SteelworksKit._wall_holes(pk, kit, "brick", p1, Vector3(0, 0, 1), xf[1], 0.0, lz, -0.3, eave, xf[2], BRICK, 0.4, "brick")
		var poly := PackedVector2Array([Vector2(0.0, eave), Vector2(lz, eave), Vector2(lz * 0.5, ridge)])
		SteelworksKit._wall_poly(pk, kit, "brick", p1, Vector3(0, 0, 1), xf[1], poly, BRICK, 0.4)
		pk.tube(kit, "steel", p1 + Vector3(0, eave + 1.2, lz * 0.5), p1 + Vector3(0, eave + 1.2, lz * 0.5) + (xf[1] as Vector3) * 0.06, 0.8, 0.8, 14, STEEL_DARK, true)
	_box(pk, kit, "paint", Vector3(x1 + 0.05, 2.1, (z0 + z1) * 0.5), Basis(), Vector3(0.06, 4.2, 3.2), Color(0.16, 0.24, 0.20))
	_box(pk, kit, "concrete", Vector3(x1 + 0.12, 4.4, (z0 + z1) * 0.5), Basis(), Vector3(0.3, 0.3, 3.8), CONCRETE)
	_blk(pk, kit, "paint", Vector3(x1 + 0.03, 5.1, (z0 + z1) * 0.5 - 3.2), Vector3(x1 + 0.08, 6.1, (z0 + z1) * 0.5 + 3.2), BOARD)
	SteelworksKit._label(labels, "GASSAUGERHAUS", Vector3(x1 + 0.1, 5.6, (z0 + z1) * 0.5), Vector3(1, 0, 0), 0.5, CREAM, 6.2)
	SteelworksKit._label(labels, "NEBENGEWINNUNG", Vector3(0.0, eave - 1.2, z1 + 0.05), Vector3(0, 0, 1), 0.7, CREAM, 14.0)
	# The roof, its overhang and underside; a ridge vent.
	var zm: float = (z0 + z1) * 0.5
	for sz in [-1.0, 1.0]:
		var ze: float = z1 + 0.4 if sz > 0.0 else z0 - 0.4
		var drop: float = (ridge - eave) / (lz * 0.5) * 0.4
		var a := Vector3(x0 - 0.4, eave - drop, ze)
		var b := Vector3(x1 + 0.4, eave - drop, ze)
		var n: Vector3 = Vector3(0, lz * 0.5, sz * (ridge - eave)).normalized()
		SteelworksKit._roof(pk, kit, "roofing", a, b, Vector3(x1 + 0.4, ridge, zm), Vector3(x0 - 0.4, ridge, zm), Color(0.26, 0.27, 0.29), n)
	_blk(pk, kit, "iron", Vector3(x0 + 2.0, ridge - 0.1, zm - 0.6), Vector3(x1 - 2.0, ridge + 0.7, zm + 0.6), Color(0.35, 0.36, 0.36))


## The control room (Messwarte): a flat-roofed brick box between the corners lo and hi (y ignored), a band of windows
## all round, a door and its name.
static func _control_room(pk: PropKit, kit: Dictionary, labels: Array, lo: Vector3, hi: Vector3) -> void:
	var lx: float = hi.x - lo.x
	var lz: float = hi.z - lo.z
	var winx: Array = []
	for k in range(int(lx / 2.5)):
		winx.append([Rect2(0.8 + float(k) * 2.5, 2.0, 1.7, 1.8), true])
	var winz: Array = [[Rect2(0.8, 2.0, 1.7, 1.8), true], [Rect2(3.3, 2.0, 1.7, 1.8), true]]
	var walls: Array = [[Vector3(lo.x, 0, hi.z), Vector3(1, 0, 0), Vector3(0, 0, 1), lx, winx], [Vector3(lo.x, 0, lo.z), Vector3(1, 0, 0), Vector3(0, 0, -1), lx, [[Rect2(lx * 0.5 - 0.6, 0.0, 1.2, 2.3), true]]],
			[Vector3(hi.x, 0, lo.z), Vector3(0, 0, 1), Vector3(1, 0, 0), lz, winz], [Vector3(lo.x, 0, lo.z), Vector3(0, 0, 1), Vector3(-1, 0, 0), lz, winz]]
	for w in walls:
		SteelworksKit._wall_holes(pk, kit, "brick", w[0], w[1], w[2], 0.0, w[3], -0.3, 5.5, w[4], BRICK.lightened(0.04), 0.35, "brick")
		for h in w[4]:
			var r: Rect2 = h[0]
			var cw: Vector3 = (w[0] as Vector3) + (w[1] as Vector3) * (r.position.x + r.size.x * 0.5) + Vector3.UP * (r.position.y + r.size.y * 0.5) - (w[2] as Vector3) * 0.1
			if r.position.y < 0.5:
				_box(pk, kit, "paint", cw, Basis(w[1], Vector3.UP, w[2]), Vector3(r.size.x, r.size.y, 0.05), Color(0.16, 0.24, 0.20))
			else:
				SteelworksKit._glazing(pk, kit, cw, w[1], Vector3.UP, w[2], r.size.x, r.size.y)
				SteelworksKit._window_frame(pk, kit, cw, w[1], w[2], r.size.x - 0.2, r.size.y - 0.2, Color(0.85, 0.85, 0.82), 1, 0)
	_flat_roof(pk, kit, lo.x, hi.x, lo.z, hi.z, 5.5, 0.3, 0.3, ROOF_COL)
	_blk(pk, kit, "concrete", Vector3(lo.x - 0.32, 5.55, lo.z - 0.32), Vector3(hi.x + 0.32, 5.95, hi.z + 0.32), CONCRETE)
	_blk(pk, kit, "paint", Vector3(lo.x + lx * 0.5 - 2.6, 4.3, hi.z + 0.03), Vector3(lo.x + lx * 0.5 + 2.6, 5.15, hi.z + 0.08), BOARD)
	SteelworksKit._label(labels, "MESSWARTE", Vector3(lo.x + lx * 0.5, 4.72, hi.z + 0.1), Vector3(0, 0, 1), 0.45, CREAM, 5.0)
