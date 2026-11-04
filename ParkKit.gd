extends RefCounted
## The Lakeside Meadows' park things (regenerate_lakeside.gd), built at life size through a PropKit (front toward -z,
## y up, on the ground at y = 0) and placed by the caller's frame at PROP_SCALE, like VenueKit:
## - the playground by the marquee: a swing set, a slide tower, a seesaw, a roundabout, a climbing dome, a sandpit,
##   safety mats, a fence with a gate, benches and a bin;
## - the paths' benches and fingerposts;
## - a cyclist in parts for Cyclists.gd: the bicycle's frame with the rider's body and arms (one mesh), a wheel, the
##   cranks, a thigh and a shin with its shoe, each built round the joint it turns about (see the BIKE_* numbers);
## - the airship for Airship.gd: a lathed envelope (nose toward -z, its axis through the origin), X tail fins, the
##   gondola under it with its engine pods, and a propeller (built round its hub, turning about z).
## Wood goes through VenueKit's timber (hut_wood.gdshader, key "timber"); everything else is vertex colour on
## CampKit's keys ("matte", "metal", "steel", "plastic", "rubber", "gloss", "canvas").

const PropKit = preload("res://PropKit.gd")
const VenueKit = preload("res://VenueKit.gd")

var _kit: PropKit
var _venue: VenueKit

const STEEL := Color(0.62, 0.64, 0.66)
const DARK := Color(0.12, 0.12, 0.13)
const RUBBER := Color(0.08, 0.08, 0.08)
const TIMBER := Color(0.62, 0.48, 0.32)


func _init(kit: PropKit, venue: VenueKit) -> void:
	_kit = kit
	_venue = venue


# ======================================================================================
#  Small shapes
# ======================================================================================

## A sphere (a lathe of a half circle) at `c`.
func ball(kit: Dictionary, key: String, c: Vector3, r: float, col: Color, segs := 12, squash := Vector3.ONE) -> void:
	var prof: Array = []
	var rings := maxi(4, segs / 2)
	for i in range(rings + 1):
		var a := -PI * 0.5 + PI * float(i) / float(rings)
		prof.append(Vector2(cos(a) * r, sin(a) * r))
	var base := _kit.xf
	_kit.set_frame(base * Transform3D(Basis.from_scale(squash), c))
	_kit.lathe(kit, key, Vector3.ZERO, prof, segs, col)
	_kit.set_frame(base)


## A chain (or rope) of `links` short bars from a to b.
func chain(kit: Dictionary, a: Vector3, b: Vector3, links: int) -> void:
	for i in range(links):
		var p0 := a.lerp(b, float(i) / links)
		var p1 := a.lerp(b, float(i + 1) / links)
		_kit.tube(kit, "metal", p0, p1, 0.007, 0.007, 4, STEEL, false)


# ======================================================================================
#  The playground
# ======================================================================================

## A swing set 4.8m long: an A-frame of steel tubes each end, the top beam, two swings on chains (seats 0.45m up,
## at x = -1.0 and 1.0). Returns the seats' tops (for children sitting on them).
func swing_set(kit: Dictionary, frame_col: Color, seat_cols: Array) -> Array:
	var k := _kit
	var top := 2.35
	for sx in [-2.4, 2.4]:
		for sz in [-1.0, 1.0]:
			k.tube(kit, "steel", Vector3(sx, 0.0, sz), Vector3(sx, top, 0.0), 0.05, 0.05, 10, frame_col)
		k.tube(kit, "steel", Vector3(sx, 0.8, -0.66), Vector3(sx, 0.8, 0.66), 0.03, 0.03, 8, frame_col)
		ball(kit, "steel", Vector3(sx, top, 0.0), 0.075, frame_col)
	k.tube(kit, "steel", Vector3(-2.5, top, 0.0), Vector3(2.5, top, 0.0), 0.055, 0.055, 12, frame_col)
	var seats: Array = []
	for i in range(2):
		var x: float = -1.0 + 2.0 * i
		var seat_y := 0.45
		for sx in [-0.21, 0.21]:
			k.block(kit, "steel", Vector3(x + sx - 0.03, top - 0.06, -0.03), Vector3(x + sx + 0.03, top + 0.02, 0.03), STEEL)
			chain(kit, Vector3(x + sx, top - 0.04, 0.0), Vector3(x + sx, seat_y + 0.02, 0.0), 14)
		var sc: Color = seat_cols[i % seat_cols.size()]
		k.block(kit, "rubber", Vector3(x - 0.24, seat_y - 0.03, -0.11), Vector3(x + 0.24, seat_y + 0.01, 0.11), sc)
		seats.append(Vector3(x, seat_y + 0.01, 0.0))
	return seats


## A slide tower: a 1.3m square deck 1.5m up on four timber posts, a pitched roof, rails round three sides, a ladder up
## the back (+z) and a slide down the front (-z) to the ground 3.4m out. Returns the deck's middle.
func slide_tower(kit: Dictionary, roof_col: Color, slide_col: Color) -> Vector3:
	var k := _kit
	var h := 0.65
	var deck := 1.5
	for sx in [-h, h]:
		for sz in [-h, h]:
			_venue.timber(kit, Vector3(sx, -0.1, sz), Vector3(sx, 2.75, sz), 0.1, 0.1, TIMBER)
	# The deck: boards across.
	for i in range(7):
		var z := -h + 0.1 + i * 0.19
		_venue.timber(kit, Vector3(-h - 0.05, deck, z), Vector3(h + 0.05, deck, z), 0.16, 0.04, TIMBER.darkened(0.08), Vector3.BACK)
	_venue.timber(kit, Vector3(-h, deck - 0.08, -h), Vector3(h, deck - 0.08, -h), 0.12, 0.06, TIMBER)
	_venue.timber(kit, Vector3(-h, deck - 0.08, h), Vector3(h, deck - 0.08, h), 0.12, 0.06, TIMBER)
	# Rails on the sides (x) and halfway along the front beside the slide's mouth.
	for sx in [-h, h]:
		for y in [deck + 0.45, deck + 0.85]:
			_venue.timber(kit, Vector3(sx, y, -h), Vector3(sx, y, h), 0.08, 0.05, TIMBER, Vector3.UP)
	# The roof: two slopes over the deck, gables at front and back.
	var eave := 2.55
	var ridge := 3.2
	for s in [-1.0, 1.0]:
		var n := Vector3(s * (ridge - eave), 0.95, 0.0).normalized()
		var p := [Vector3(0.0, ridge, -h - 0.2), Vector3(s * (h + 0.25), eave, -h - 0.2), Vector3(s * (h + 0.25), eave, h + 0.2), Vector3(0.0, ridge, h + 0.2)]
		k.panel(kit, "plastic", p, n, roof_col, roof_col.darkened(0.25))
	for zz in [-h - 0.05, h + 0.05]:
		var nz := Vector3(0.0, 0.0, signf(zz))
		k.panel(kit, "plastic", [Vector3(-h - 0.05, eave, zz), Vector3(h + 0.05, eave, zz), Vector3(0.0, ridge - 0.05, zz), Vector3(0.0, ridge - 0.05, zz)],
				nz, roof_col.lightened(0.1), roof_col)
	# The ladder up the back.
	for sx in [-0.28, 0.28]:
		k.tube(kit, "steel", Vector3(sx, 0.0, h + 0.75), Vector3(sx, deck + 0.9, h), 0.03, 0.03, 8, slide_col.darkened(0.2))
	for i in range(1, 6):
		var t := float(i) / 6.0
		var p := Vector3(0.0, 0.0, h + 0.75).lerp(Vector3(0.0, deck + 0.9, h), t * (deck / (deck + 0.9)))
		k.tube(kit, "steel", Vector3(-0.28, p.y, p.z), Vector3(0.28, p.y, p.z), 0.022, 0.022, 6, STEEL)
	# The slide: a chute from the deck's front edge down to a run-out, its sides raised, on two legs.
	var w := 0.3
	var pts := [Vector3(0.0, deck + 0.02, -h), Vector3(0.0, deck - 0.25, -h - 0.5), Vector3(0.0, 0.55, -h - 2.4), Vector3(0.0, 0.32, -h - 3.0), Vector3(0.0, 0.3, -h - 3.4)]
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var along := (b - a).normalized()
		var up := Vector3.RIGHT.cross(along).normalized() * -1.0
		if up.y < 0.0:
			up = -up
		# The bed, then the side walls.
		k.quad(kit, "plastic", [a + Vector3(-w, 0.0, 0.0), b + Vector3(-w, 0.0, 0.0), b + Vector3(w, 0.0, 0.0), a + Vector3(w, 0.0, 0.0)], up, slide_col)
		k.quad(kit, "plastic", [a + Vector3(w, 0.0, 0.0), b + Vector3(w, 0.0, 0.0), b + Vector3(-w, 0.0, 0.0), a + Vector3(-w, 0.0, 0.0)], -up, slide_col.darkened(0.3))
		for s in [-1.0, 1.0]:
			var x: float = s * w
			var p := [a + Vector3(x, 0.0, 0.0), b + Vector3(x, 0.0, 0.0), b + Vector3(x, 0.0, 0.0) + up * 0.22, a + Vector3(x, 0.0, 0.0) + up * 0.22]
			k.panel(kit, "plastic", p, Vector3(-s, 0.0, 0.0), slide_col, slide_col.darkened(0.15))
			k.tube(kit, "plastic", a + Vector3(x, 0.0, 0.0) + up * 0.22, b + Vector3(x, 0.0, 0.0) + up * 0.22, 0.03, 0.03, 6, slide_col.lightened(0.15), false)
	for t in [0.45, 0.85]:
		var p: Vector3 = (pts[1] as Vector3).lerp(pts[2], t)
		for sx in [-0.22, 0.22]:
			k.tube(kit, "steel", Vector3(sx, 0.0, p.z), Vector3(sx, p.y - 0.02, p.z), 0.035, 0.035, 8, STEEL)
	return Vector3(0.0, deck + 0.02, 0.0)


## A seesaw 3.6m long along x on a red pivot stand, tipped a little, handles and seats at both ends. Returns the
## seats' tops.
func seesaw(kit: Dictionary, col: Color) -> Array:
	var k := _kit
	var tilt := 0.16
	var piv := Vector3(0.0, 0.55, 0.0)
	k.block(kit, "steel", Vector3(-0.12, 0.0, -0.32), Vector3(0.12, 0.08, 0.32), STEEL)
	for sz in [-0.22, 0.22]:
		k.tube(kit, "steel", Vector3(0.0, 0.05, sz * 1.3), piv + Vector3(0.0, 0.0, sz), 0.05, 0.04, 8, Color(0.80, 0.16, 0.12))
	k.tube(kit, "steel", piv + Vector3(0.0, 0.0, -0.3), piv + Vector3(0.0, 0.0, 0.3), 0.045, 0.045, 10, STEEL)
	var dir := Vector3(cos(tilt), sin(tilt), 0.0)
	var a := piv - dir * 1.8 + Vector3(0, 0.06, 0)
	var b := piv + dir * 1.8 + Vector3(0, 0.06, 0)
	k.beam(kit, "plastic", a, b, 0.26, 0.07, col, Vector3.BACK)
	var seats: Array = []
	for e in [-1.0, 1.0]:
		var end: Vector3 = piv + dir * (e * 1.45) + Vector3(0, 0.1, 0)
		k.block(kit, "rubber", end + Vector3(-0.2, 0.0, -0.15), end + Vector3(0.2, 0.05, 0.15), RUBBER)
		var hb: Vector3 = end + dir * (-e * 0.35)
		for sz in [-0.16, 0.16]:
			k.tube(kit, "steel", hb + Vector3(0, 0, sz), hb + Vector3(0, 0.32, sz), 0.02, 0.02, 6, STEEL)
		k.tube(kit, "steel", hb + Vector3(0, 0.32, -0.18), hb + Vector3(0, 0.32, 0.18), 0.024, 0.024, 6, Color(0.9, 0.75, 0.1))
		seats.append(end + Vector3(0, 0.05, 0))
	# Old tyres half sunk under each end, where it bumps down.
	for e in [-1.0, 1.0]:
		k.tyre(kit, "rubber", Vector3(e * 1.75, 0.04, 0.0), 0.14, 0.3, 0.16, 14, RUBBER)
	return seats


## A roundabout 2m across: a ribbed deck on a centre post, four grab rails rising to a ring round the post.
func roundabout(kit: Dictionary, col: Color, rail_col: Color) -> void:
	var k := _kit
	var r := 1.0
	k.lathe(kit, "steel", Vector3.ZERO, [Vector2(0.0, 0.12), Vector2(r * 0.25, 0.1), Vector2(r * 0.25, 0.0)], 12, DARK)
	k.lathe(kit, "plastic", Vector3.ZERO, [Vector2(r, 0.18), Vector2(r, 0.26), Vector2(r - 0.04, 0.3), Vector2(0.0, 0.3)], 28, col)
	k.lathe(kit, "plastic", Vector3.ZERO, [Vector2(0.0, 0.18), Vector2(r, 0.18)], 28, col.darkened(0.4))
	# Ribs in segments across the deck.
	for i in range(8):
		var a := TAU * i / 8.0
		k.beam(kit, "plastic", Vector3(cos(a) * 0.12, 0.31, sin(a) * 0.12), Vector3(cos(a) * (r - 0.05), 0.31, sin(a) * (r - 0.05)), 0.05, 0.02,
				col.lightened(0.3))
	k.tube(kit, "steel", Vector3(0, 0.3, 0), Vector3(0, 1.05, 0), 0.05, 0.05, 10, rail_col)
	ball(kit, "steel", Vector3(0, 1.08, 0), 0.08, rail_col)
	for i in range(4):
		var a := TAU * (i + 0.5) / 4.0
		var foot := Vector3(cos(a) * (r - 0.12), 0.3, sin(a) * (r - 0.12))
		var knee := Vector3(cos(a) * (r - 0.12), 0.85, sin(a) * (r - 0.12))
		k.tube(kit, "steel", foot, knee, 0.025, 0.025, 6, rail_col)
		k.tube(kit, "steel", knee, Vector3(cos(a) * 0.08, 1.0, sin(a) * 0.08), 0.025, 0.025, 6, rail_col)


## A climbing dome 3.2m across: a lattice of steel bars on a hemisphere (rings and meridians, the bottom ring on the
## ground).
func climbing_dome(kit: Dictionary, col: Color) -> void:
	var k := _kit
	var r := 1.6
	var rings := 4
	var segs := 10
	var pts := []
	for j in range(rings + 1):
		var el := (PI * 0.5) * float(j) / float(rings)
		var row := []
		for i in range(segs):
			var a := TAU * i / segs + (0.0 if j % 2 == 0 else PI / segs)
			row.append(Vector3(cos(a) * cos(el) * r, sin(el) * r, sin(a) * cos(el) * r))
		pts.append(row)
	var top := Vector3(0, r, 0)
	for j in range(rings):
		for i in range(segs):
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][(i + 1) % segs]
			k.tube(kit, "steel", a, b, 0.022, 0.022, 6, col, false)
			var up: Vector3 = top if j == rings - 1 else pts[j + 1][i]
			var up2: Vector3 = top if j == rings - 1 else pts[j + 1][(i + segs - 1) % segs if j % 2 == 1 else i]
			k.tube(kit, "steel", a, up, 0.022, 0.022, 6, col, false)
			if j < rings - 1:
				k.tube(kit, "steel", a, up2, 0.022, 0.022, 6, col.darkened(0.15), false)
		# Joints.
		for i in range(segs):
			ball(kit, "steel", pts[j][i], 0.035, STEEL, 6)
	ball(kit, "steel", top, 0.06, STEEL, 8)


## A sandpit 3.2m square: a frame of sleepers, the sand inside (a little heaped), a bucket and a spade.
func sandpit(kit: Dictionary, rng: RandomNumberGenerator) -> void:
	var k := _kit
	var h := 1.6
	for s in [-1.0, 1.0]:
		_venue.timber(kit, Vector3(-h - 0.1, 0.12, s * h), Vector3(h + 0.1, 0.12, s * h), 0.2, 0.24, TIMBER.darkened(0.1), Vector3.BACK)
		_venue.timber(kit, Vector3(s * h, 0.12, -h + 0.1), Vector3(s * h, 0.12, h - 0.1), 0.2, 0.24, TIMBER.darkened(0.1), Vector3.RIGHT)
	var sand := Color(0.86, 0.76, 0.56)
	var n := 8
	for i in range(n):
		for j in range(n):
			var p := []
			for c in [[0, 0], [1, 0], [1, 1], [0, 1]]:
				var x: float = -h + 0.1 + (2.0 * h - 0.2) * float(i + c[0]) / n
				var z: float = -h + 0.1 + (2.0 * h - 0.2) * float(j + c[1]) / n
				var edge: float = minf(h - 0.1 - absf(x), h - 0.1 - absf(z))
				var y: float = 0.1 + minf(edge, 0.5) * 0.12 + sin(x * 3.1 + z * 1.7) * 0.015
				p.append(Vector3(x, y, z))
			k.quad(kit, "matte", [p[0], p[3], p[2], p[1]], Vector3.UP, sand.darkened(rng.randf_range(0.0, 0.06)))
	# A bucket and a spade.
	var bc: Color = [Color(0.95, 0.20, 0.15), Color(0.15, 0.45, 0.95), Color(0.98, 0.80, 0.10)][rng.randi() % 3]
	k.lathe(kit, "plastic", Vector3(0.6, 0.14, -0.5), [Vector2(0.0, 0.0), Vector2(0.08, 0.0), Vector2(0.11, 0.17), Vector2(0.105, 0.17), Vector2(0.075, 0.01)], 12, bc)
	k.beam(kit, "plastic", Vector3(-0.5, 0.17, 0.4), Vector3(-0.1, 0.2, 0.55), 0.03, 0.02, Color(0.15, 0.7, 0.3))
	k.block(kit, "plastic", Vector3(-0.62, 0.15, 0.32), Vector3(-0.46, 0.18, 0.46), Color(0.15, 0.7, 0.3))


## A rubber safety mat (lo to hi in x and z), its top 4cm up.
func safety_mat(kit: Dictionary, lo: Vector2, hi: Vector2, col: Color) -> void:
	_kit.block(kit, "rubber", Vector3(lo.x, -0.06, lo.y), Vector3(hi.x, 0.04, hi.y), col)


## A park bench 1.8m long (seat top 0.45m up, its front toward -z): cast-iron ends, slats for the seat and back.
func park_bench(kit: Dictionary) -> void:
	var k := _kit
	var iron := Color(0.12, 0.16, 0.13)
	for sx in [-0.8, 0.8]:
		k.beam(kit, "steel", Vector3(sx, 0.0, -0.22), Vector3(sx, 0.43, -0.2), 0.05, 0.06, iron, Vector3.BACK)
		k.beam(kit, "steel", Vector3(sx, 0.0, 0.22), Vector3(sx, 0.86, 0.3), 0.05, 0.06, iron, Vector3.BACK)
		k.beam(kit, "steel", Vector3(sx, 0.42, -0.26), Vector3(sx, 0.42, 0.24), 0.05, 0.05, iron, Vector3.UP)
		k.beam(kit, "steel", Vector3(sx, 0.62, -0.2), Vector3(sx, 0.62, 0.22), 0.04, 0.04, iron, Vector3.UP)
	for i in range(4):
		var z := -0.21 + i * 0.13
		_venue.timber(kit, Vector3(-0.92, 0.45, z), Vector3(0.92, 0.45, z), 0.1, 0.035, TIMBER, Vector3.BACK)
	for i in range(3):
		var y := 0.58 + i * 0.11
		var z := 0.235 + (y - 0.58) * 0.18
		_venue.timber(kit, Vector3(-0.92, y, z), Vector3(0.92, y, z), 0.085, 0.03, TIMBER, Vector3.UP)


## A litter bin on a post.
func bin(kit: Dictionary) -> void:
	var k := _kit
	var green := Color(0.10, 0.30, 0.20)
	k.tube(kit, "steel", Vector3(0, 0, 0), Vector3(0, 0.55, 0), 0.04, 0.04, 8, DARK)
	k.lathe(kit, "steel", Vector3(0, 0.45, 0), [Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.22, 0.55), Vector2(0.2, 0.56), Vector2(0.18, 0.06)], 14, green)


## A fence from a to b (ground points in the frame): posts every 2m or so and two rails.
func fence_run(kit: Dictionary, a: Vector3, b: Vector3, col: Color) -> void:
	var length := Vector2(b.x - a.x, b.z - a.z).length()
	var n := maxi(1, ceili(length / 2.0))
	for i in range(n + 1):
		var p := a.lerp(b, float(i) / n)
		_venue.timber(kit, p + Vector3(0, -0.2, 0), p + Vector3(0, 1.0, 0), 0.09, 0.09, col)
	for y in [0.45, 0.88]:
		_venue.timber(kit, a + Vector3(0, y, 0), b + Vector3(0, y, 0), 0.1, 0.04, col, Vector3.UP)


## A wooden fingerpost: a post with two arms at different bearings (radians about y, 0 pointing -z).
func fingerpost(kit: Dictionary, arms: Array) -> void:
	_venue.timber(kit, Vector3(0, -0.3, 0), Vector3(0, 2.3, 0), 0.11, 0.11, TIMBER.darkened(0.1))
	var y := 2.05
	for a in arms:
		var d := Vector3(-sin(float(a)), 0.0, -cos(float(a)))
		_venue.timber(kit, Vector3(0, y, 0) + d * 0.06, Vector3(0, y, 0) + d * 0.75, 0.16, 0.03, Color(0.86, 0.80, 0.66), Vector3.UP)
		y -= 0.24
	ball(kit, "matte", Vector3(0, 2.33, 0), 0.07, TIMBER.darkened(0.2), 8)


# ======================================================================================
#  The cyclist
# ======================================================================================

const BIKE_WHEEL_R := 0.345
const BIKE_REAR_Z := 0.5
const BIKE_FRONT_Z := -0.52
const BIKE_BB := Vector3(0.0, 0.28, 0.08)
const BIKE_CRANK := 0.17
const BIKE_PEDAL_X := 0.12
const BIKE_HIP := Vector3(0.0, 0.97, 0.27)
const BIKE_HIP_X := 0.095
const BIKE_THIGH := 0.45
const BIKE_SHIN := 0.47
## How many turns of the wheels to one of the cranks.
const BIKE_GEAR := 1.35


## The bicycle's frame (no wheels or cranks) and its rider's body, head and arms, in one mesh, at life size: the
## wheels' axles at (0, BIKE_WHEEL_R, BIKE_REAR_Z) and (0, BIKE_WHEEL_R, BIKE_FRONT_Z), the bottom bracket at BIKE_BB,
## the rider's hips at BIKE_HIP (the legs are their own parts).
func cyclist_body(kit: Dictionary, frame_col: Color, jersey: Color, shorts: Color, skin: Color, helmet: Color, hair: Color, female: bool) -> void:
	var k := _kit
	var rear := Vector3(0.0, BIKE_WHEEL_R, BIKE_REAR_Z)
	var front := Vector3(0.0, BIKE_WHEEL_R, BIKE_FRONT_Z)
	var bb := BIKE_BB
	var seat_top := Vector3(0.0, 0.84, 0.22)
	var head_top := Vector3(0.0, 0.88, -0.4)
	var head_low := Vector3(0.0, 0.74, -0.37)
	var r := 0.018
	k.tube(kit, "gloss", bb, seat_top, r * 1.2, r, 8, frame_col)
	k.tube(kit, "gloss", seat_top + Vector3(0, -0.03, 0), head_top + Vector3(0, -0.03, 0), r, r, 8, frame_col)
	k.tube(kit, "gloss", bb, head_low, r * 1.4, r * 1.3, 8, frame_col)
	k.tube(kit, "gloss", head_low + Vector3(0, -0.04, 0), head_top + Vector3(0, 0.03, 0), r * 1.5, r * 1.5, 8, frame_col)
	for sx in [-0.05, 0.05]:
		var axle := rear + Vector3(sx, 0, 0)
		k.tube(kit, "gloss", bb + Vector3(sx * 0.5, 0, 0), axle, r * 0.8, r * 0.7, 6, frame_col)
		k.tube(kit, "gloss", seat_top + Vector3(sx * 0.3, -0.02, 0), axle, r * 0.7, r * 0.7, 6, frame_col)
		k.tube(kit, "gloss", head_low + Vector3(sx * 0.6, -0.02, 0), front + Vector3(sx, 0, 0), r * 0.9, r * 0.7, 6, frame_col.darkened(0.1))
	# Seatpost and saddle, stem and bars, grips.
	k.tube(kit, "steel", seat_top, Vector3(0.0, 0.93, 0.25), 0.014, 0.014, 6, STEEL)
	k.block(kit, "rubber", Vector3(-0.06, 0.93, 0.17), Vector3(0.06, 0.965, 0.36), DARK)
	k.block(kit, "rubber", Vector3(-0.025, 0.935, 0.08), Vector3(0.025, 0.96, 0.18), DARK)
	var bar := Vector3(0.0, 0.95, -0.47)
	k.tube(kit, "steel", head_top, bar, 0.016, 0.016, 6, DARK)
	k.tube(kit, "steel", bar + Vector3(-0.25, 0, 0), bar + Vector3(0.25, 0, 0), 0.012, 0.012, 6, DARK)
	# Mudguard-less, a bottle on the down tube, reflectors.
	k.tube(kit, "plastic", bb.lerp(head_low, 0.35) + Vector3(0, 0.04, 0), bb.lerp(head_low, 0.62) + Vector3(0, 0.04, 0), 0.032, 0.032, 8, Color(0.9, 0.9, 0.92))
	k.block(kit, "plastic", rear + Vector3(-0.03, 0.4, 0.06), rear + Vector3(0.03, 0.44, 0.08), Color(0.85, 0.05, 0.05))
	# The rider: pelvis, torso leaning forward, shoulders, neck, head, helmet.
	var hip := BIKE_HIP
	var shoulders := Vector3(0.0, 1.38, -0.12)
	ball(kit, "canvas", hip + Vector3(0, 0.02, 0), 0.15, shorts, 10, Vector3(1.15, 0.9, 1.0))
	k.tube(kit, "canvas", hip + Vector3(0, 0.06, -0.01), shoulders, 0.15, 0.17, 10, jersey)
	ball(kit, "canvas", shoulders, 0.17, jersey, 10, Vector3(1.25, 0.7, 0.9))
	var neck := shoulders + Vector3(0, 0.1, -0.06)
	k.tube(kit, "canvas", shoulders, neck + Vector3(0, 0.03, -0.02), 0.055, 0.05, 8, skin)
	var head := Vector3(0.0, 1.57, -0.24)
	ball(kit, "canvas", head, 0.1, skin, 12, Vector3(0.9, 1.05, 1.0))
	if female:
		# A ponytail out under the helmet.
		k.tube(kit, "canvas", head + Vector3(0, 0.0, 0.09), head + Vector3(0, -0.13, 0.18), 0.04, 0.02, 6, hair)
	var hp: Array = []
	for i in range(7):
		var a := PI * 0.5 * float(i) / 6.0
		hp.append(Vector2(cos(a) * 0.125, sin(a) * 0.12))
	var base := k.xf
	k.set_frame(base * Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 1.3)), head + Vector3(0, 0.02, 0.01)))
	k.lathe(kit, "gloss", Vector3.ZERO, hp, 14, helmet)
	k.set_frame(base)
	# Sunglasses.
	k.block(kit, "gloss", head + Vector3(-0.07, 0.01, -0.105), head + Vector3(0.07, 0.04, -0.085), DARK)
	# Arms: shoulder, elbow, hand on the bars.
	for s in [-1.0, 1.0]:
		var sh := shoulders + Vector3(s * 0.18, -0.02, 0.0)
		var hand := bar + Vector3(s * 0.21, 0.03, 0.0)
		var elbow := sh.lerp(hand, 0.5) + Vector3(s * 0.04, 0.03, 0.05)
		k.tube(kit, "canvas", sh, elbow, 0.055, 0.045, 8, jersey)
		k.tube(kit, "canvas", elbow, hand, 0.042, 0.035, 8, skin)
		ball(kit, "canvas", hand, 0.04, Color(0.12, 0.12, 0.12), 8)


## A wheel round the origin, turning about x: tyre, rim, 16 spokes, the hub.
func bike_wheel(kit: Dictionary, rim_col: Color) -> void:
	var k := _kit
	var ax := Basis(Vector3.BACK, PI * 0.5)
	k.tyre(kit, "rubber", Vector3.ZERO, BIKE_WHEEL_R - 0.035, BIKE_WHEEL_R, 0.034, 28, RUBBER, ax)
	k.tyre(kit, "metal", Vector3.ZERO, BIKE_WHEEL_R - 0.06, BIKE_WHEEL_R - 0.03, 0.02, 28, rim_col, ax)
	for i in range(16):
		var a := TAU * i / 16.0
		var side := 0.025 if i % 2 == 0 else -0.025
		k.tube(kit, "steel", Vector3(side, 0, 0), Vector3(0.0, cos(a), sin(a)) * (BIKE_WHEEL_R - 0.055), 0.0025, 0.0025, 3, STEEL, false)
	k.tube(kit, "metal", Vector3(-0.045, 0, 0), Vector3(0.045, 0, 0), 0.022, 0.022, 8, STEEL)


## The cranks round the bottom bracket at the origin, turning about x: at angle 0 the right one (+x) points
## forward (-z) and the left one back, a pedal on each, the chainring on the right.
func bike_crank(kit: Dictionary) -> void:
	var k := _kit
	for s in [-1.0, 1.0]:
		var end := Vector3(s * 0.085, 0.0, -s * BIKE_CRANK)
		k.beam(kit, "metal", Vector3(s * 0.085, 0, 0), end, 0.025, 0.012, STEEL, Vector3.UP)
		k.block(kit, "rubber", end + Vector3(s * 0.01 - 0.0, -0.012, -0.035) + Vector3(minf(s, 0.0) * 0.09, 0, 0),
				end + Vector3(s * 0.01, 0.012, 0.035) + Vector3(maxf(s, 0.0) * 0.09, 0, 0), DARK)
	k.lathe(kit, "metal", Vector3.ZERO, [Vector2(0.0, 0.0), Vector2(0.1, 0.0)], 20, Color(0.35, 0.36, 0.38), false, Basis(Vector3.BACK, PI * 0.5))
	k.tube(kit, "metal", Vector3(-0.09, 0, 0), Vector3(0.09, 0, 0), 0.02, 0.02, 8, STEEL)


## A thigh hanging from the hip at the origin down -y (BIKE_THIGH long), in the shorts' colour.
func bike_thigh(kit: Dictionary, shorts: Color, skin: Color) -> void:
	_kit.tube(kit, "canvas", Vector3.ZERO, Vector3(0, -BIKE_THIGH * 0.7, 0), 0.085, 0.068, 8, shorts)
	_kit.tube(kit, "canvas", Vector3(0, -BIKE_THIGH * 0.7, 0), Vector3(0, -BIKE_THIGH, 0), 0.066, 0.058, 8, skin)
	ball(kit, "canvas", Vector3.ZERO, 0.085, shorts, 8)


## A shin from the knee at the origin down -y (BIKE_SHIN long), a sock and a shoe pointing forward (-z) at its end.
func bike_shin(kit: Dictionary, skin: Color, sock: Color, shoe: Color) -> void:
	var k := _kit
	ball(kit, "canvas", Vector3.ZERO, 0.06, skin, 8)
	k.tube(kit, "canvas", Vector3.ZERO, Vector3(0, -BIKE_SHIN * 0.78, 0.0), 0.058, 0.042, 8, skin)
	k.tube(kit, "canvas", Vector3(0, -BIKE_SHIN * 0.78, 0.0), Vector3(0, -BIKE_SHIN, 0.0), 0.042, 0.04, 8, sock)
	k.block(kit, "rubber", Vector3(-0.045, -BIKE_SHIN - 0.06, -0.17), Vector3(0.045, -BIKE_SHIN + 0.03, 0.06), shoe)


# ======================================================================================
#  The airship
# ======================================================================================

const SHIP_LENGTH := 64.0
const SHIP_R := 8.4

## The envelope's radius `h` metres toward the nose from its middle (0 at both tips).
static func ship_radius(h: float) -> float:
	var u := clampf((SHIP_LENGTH * 0.5 - h) / SHIP_LENGTH, 0.0, 1.0)
	return SHIP_R * pow(maxf(sin(PI * pow(u, 0.8)), 0.0), 0.7)


## The envelope (white with a band and a dark nose and tail), the four tail fins in an X with their rudders and
## elevators, and the gondola (glazed front, a band of windows down each side, engine pods on pylons). Nose -z.
func airship(kit: Dictionary, body: Color, band: Color, trim: Color) -> void:
	var k := _kit
	var ax := Basis(Vector3.RIGHT, -PI * 0.5)
	var n := 48
	var hs: Array = []
	for i in range(n + 1):
		var u := float(i) / n
		# Denser at the tips.
		var h := -SHIP_LENGTH * 0.5 + SHIP_LENGTH * (0.5 - 0.5 * cos(PI * u))
		hs.append(h)
	var ranges := [[-99.0, -24.0, trim], [-24.0, -14.0, body], [-14.0, -11.5, band], [-11.5, 17.0, body], [17.0, 19.0, band], [19.0, 29.5, body], [29.5, 99.0, trim]]
	for rg in ranges:
		var prof: Array = []
		var lo: float = rg[0]
		var hi: float = rg[1]
		var first := true
		for h in hs:
			if float(h) < lo or float(h) > hi:
				continue
			if first and lo > -SHIP_LENGTH * 0.5:
				prof.append(Vector2(ship_radius(lo), lo))
			first = false
			prof.append(Vector2(ship_radius(float(h)), float(h)))
		if hi < SHIP_LENGTH * 0.5:
			prof.append(Vector2(ship_radius(hi), hi))
		k.lathe(kit, "gloss", Vector3.ZERO, prof, 40, rg[2], false, ax)
	# Fins in an X (45 degrees), along the tail from h -27 to -18 at the root.
	var base := k.xf
	for i in range(4):
		var a := PI * 0.25 + PI * 0.5 * i
		var radial := Vector3(cos(a), sin(a), 0.0)
		var side := Vector3(0, 0, 1).cross(radial)
		# Extrude's x along the ship toward the tail (+z), y outward, z across the fin.
		k.set_frame(base * Transform3D(Basis(Vector3(0, 0, 1), radial, side), Vector3.ZERO))
		var r0 := ship_radius(-18.0) - 0.4
		var r1 := ship_radius(-27.5) - 0.3
		var fin := PackedVector2Array([Vector2(18.0, r0), Vector2(28.0, r1), Vector2(29.0, r1 + 6.2), Vector2(24.5, r1 + 6.6)])
		k.extrude(kit, "gloss", fin, -0.22, 0.22, 0.08, body)
		# The rudder / elevator: the fin's trailing strip in the trim colour.
		var flap := PackedVector2Array([Vector2(26.6, r1 + 0.3), Vector2(29.2, r1 + 0.3), Vector2(29.9, r1 + 6.2), Vector2(28.0, r1 + 6.3)])
		k.extrude(kit, "gloss", flap, -0.18, 0.18, 0.05, trim)
	k.set_frame(base)
	# The gondola: a side outline (x toward the nose) extruded across, turned to lie along z.
	var gy := -ship_radius(2.0) + 0.6
	k.set_frame(base * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, gy, 2.0)))
	var g := PackedVector2Array([Vector2(-6.5, 0.4), Vector2(-6.8, -0.6), Vector2(-6.0, -2.2), Vector2(4.4, -2.4), Vector2(6.0, -1.9), Vector2(6.9, -0.9),
			Vector2(6.6, 0.4)])
	k.extrude(kit, "gloss", g, -1.45, 1.45, 0.25, body.darkened(0.04))
	# Windows: a dark band down each side and the glazed front.
	for s in [-1.0, 1.0]:
		var zz: float = s * 1.47
		var nrm := Vector3(0, 0, s)
		var wp := [Vector3(-4.8, -1.75, zz), Vector3(4.6, -1.75, zz), Vector3(5.3, -0.75, zz), Vector3(-4.8, -0.75, zz)]
		if s < 0.0:
			wp = [wp[3], wp[2], wp[1], wp[0]]
		k.quad(kit, "gloss", wp, nrm, Color(0.06, 0.09, 0.14))
	k.quad(kit, "gloss", [Vector3(6.1, -1.7, -1.2), Vector3(6.1, -1.7, 1.2), Vector3(6.75, -0.95, 1.2), Vector3(6.75, -0.95, -1.2)],
			Vector3(0.75, 0.65, 0).normalized(), Color(0.06, 0.09, 0.14))
	k.set_frame(base)
	# Engine pods on pylons either side of the gondola's rear half.
	for s in [-1.0, 1.0]:
		var c := Vector3(s * 3.6, gy - 1.2, 4.6)
		k.beam(kit, "steel", Vector3(s * 1.4, gy - 1.0, 4.6), c, 0.35, 0.18, trim, Vector3.BACK)
		k.tube(kit, "gloss", c + Vector3(0, 0, -1.6), c + Vector3(0, 0, 1.4), 0.45, 0.55, 14, body)
		ball(kit, "gloss", c + Vector3(0, 0, -1.6), 0.45, body, 12)
		# The duct round the propeller.
		k.tyre(kit, "gloss", c + Vector3(0, 0, 2.0), 1.35, 1.5, 0.7, 28, trim, Basis(Vector3.RIGHT, PI * 0.5))
		for i in range(3):
			var a := TAU * i / 3.0 + 0.3
			k.beam(kit, "steel", c + Vector3(0, 0, 1.6), c + Vector3(cos(a), sin(a), 0.0) * 1.38 + Vector3(0, 0, 2.0), 0.08, 0.05, trim)
	# The mooring cone at the nose.
	k.lathe(kit, "metal", Vector3(0, 0, -SHIP_LENGTH * 0.5 + 0.2), [Vector2(0.0, 0.0), Vector2(0.55, 0.0), Vector2(0.12, -0.9), Vector2(0.0, -0.95)],
			12, STEEL, false, ax)


## The engine pods' propeller centres (in the airship's frame).
static func ship_prop_centres() -> Array:
	var gy := -ship_radius(2.0) + 0.6
	return [Vector3(-3.6, gy - 1.2, 6.6), Vector3(3.6, gy - 1.2, 6.6)]


## A propeller round its hub at the origin, turning about z: a spinner and five twisted blades.
func ship_prop(kit: Dictionary, col: Color) -> void:
	var k := _kit
	k.lathe(kit, "metal", Vector3.ZERO, [Vector2(0.0, -0.25), Vector2(0.26, -0.25), Vector2(0.18, 0.3), Vector2(0.0, 0.45)], 12, STEEL, false,
			Basis(Vector3.RIGHT, PI * 0.5))
	for i in range(5):
		var a := TAU * i / 5.0
		var d := Vector3(cos(a), sin(a), 0.0)
		var t := Vector3(-sin(a), cos(a), 0.0)
		var pts := []
		for j in range(4):
			var rr := 0.2 + 1.08 * float(j) / 3.0
			var w := lerpf(0.26, 0.12, float(j) / 3.0)
			var twist := lerpf(0.9, 0.35, float(j) / 3.0)
			var chord := (t * cos(twist) + Vector3(0, 0, 1) * sin(twist)) * w
			pts.append([d * rr - chord, d * rr + chord])
		for j in range(3):
			var p := [pts[j][0], pts[j + 1][0], pts[j + 1][1], pts[j][1]]
			var nrm: Vector3 = ((p[1] as Vector3) - (p[0] as Vector3)).cross((p[3] as Vector3) - (p[0] as Vector3)).normalized()
			k.panel(kit, "metal", p, nrm, col, col)
