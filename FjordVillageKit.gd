extends "res://YardKit.gd"
## Svartvik, the fishing village on Frostpeak Creek's south shore (regenerate_frostpeak_dressing.gd, _build_village),
## built at life size through YardKit's kit (the hut shaders: "battens" upright board cladding, "lapboards", "timber",
## "painted" trim, "stone", "slate"; CampKit's "glass", "steel") and grown by the generator's PROP_SCALE. Norwegian
## coastal buildings in winter: painted timber houses with white trim and corner boards, a gabled porch (bislag) over
## the door, slate roofs under snow, chimneys; a white long church with a west tower and spire; red fishermen's
## cabins (rorbuer) on stilts at the water's edge; tarred boathouses (naust); a timber quay on piles; racks of drying
## stockfish (hjell); kick-sleds and woodpiles.
##
## A building is built in its own frame: x along its front, the front wall in the plane z = 0 facing +z, the back at
## z = -d, the floor at y = 0 (a step's height over the ground at its highest corner). Its stone foundation (or its
## stilts) runs down `plinth` metres under the floor, so it reaches the ground on a slope. Add-ons stand at least 2.5cm
## proud of what they sit on (the mobile renderer can't part closer faces at racing distances). Every function that
## builds a chimney returns its top (local), for the generator's smoke.

const PAINTS := [
	Color(0.92, 0.91, 0.87),  # white
	Color(0.55, 0.14, 0.11),  # Falu red
	Color(0.86, 0.68, 0.33),  # ochre
	Color(0.90, 0.82, 0.54),  # pale yellow
	Color(0.52, 0.60, 0.65),  # blue-grey
	Color(0.47, 0.55, 0.47),  # green-grey
]
const WHITE := Color(0.94, 0.94, 0.91)
const SLATE_ROOF := Color(0.22, 0.23, 0.25)
const SNOW := Color(0.90, 0.93, 0.98)
const FOUNDATION := Color(0.50, 0.50, 0.51)
const TAR := Color(0.20, 0.13, 0.10)
const WOOD_GREY := Color(0.52, 0.47, 0.42)
const PITCH := 0.78  # tan of a 38 degree roof
## How far a window's casing reaches past its opening at the side, and its crown board and that board's snow over it.
const WINDOW_CASING := 0.16
const WINDOW_TOP := 0.24
## The least gap between a gable window's top and the roof's slope over it.
const GABLE_CLEAR := 0.2

static var _snow_mat: Material


## YardKit's kit with "snow" (plain white, rough) added.
static func new_village_kit(scale: float) -> PropKit:
	var pk := new_kit(scale)
	var base: Callable = pk.material_for
	pk.material_for = func(k: String) -> Material:
		if k == "snow":
			if _snow_mat == null:
				var m := StandardMaterial3D.new()
				m.vertex_color_use_as_albedo = true
				m.vertex_color_is_srgb = true
				m.roughness = 0.85
				m.metallic_specular = 0.3
				_snow_mat = m
			return _snow_mat
		return base.call(k)
	return pk


# ======================================================================================
#  Parts
# ======================================================================================

## A window in a timber wall: dark glass, a white casing standing out from the boards with a crown board over it and
## a sill under it (both snowed on), a cross of glazing bars. `c` the middle of the opening on the wall's face.
static func nwindow(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float, bars := 2) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	box_at(pk, kit, "glass", c + out * 0.04, basis, Vector3(w, h, 0.04), GLASS_COL)
	var fw := 0.11
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "painted", c + across * (sx * (w * 0.5 + fw * 0.5)) + out * 0.06, basis, Vector3(fw, h + 0.1, 0.08), WHITE)
	box_at(pk, kit, "painted", c + Vector3(0, h * 0.5 + 0.1, 0) + out * 0.065, basis, Vector3(w + 2.0 * fw + 0.1, 0.18, 0.09), WHITE)
	box_at(pk, kit, "painted", c - Vector3(0, h * 0.5 + 0.05, 0) + out * 0.09, basis, Vector3(w + 2.0 * fw + 0.08, 0.08, 0.16), WHITE)
	# Snow on the crown board and the sill.
	box_at(pk, kit, "snow", c + Vector3(0, h * 0.5 + 0.21, 0) + out * 0.075, basis, Vector3(w + 2.0 * fw + 0.08, 0.05, 0.1), SNOW)
	box_at(pk, kit, "snow", c - Vector3(0, h * 0.5, 0) + out * 0.12, basis, Vector3(w + 2.0 * fw, 0.035, 0.12), SNOW)
	box_at(pk, kit, "painted", c + out * 0.075, basis, Vector3(0.05, h, 0.05), WHITE)
	for k in range(1, bars + 1):
		box_at(pk, kit, "painted", c + Vector3(0, h * (float(k) / float(bars + 1) - 0.5), 0) + out * 0.075, basis, Vector3(w, 0.045, 0.05), WHITE)


## A panelled door with its casing, a step down to the ground and, with `porch`, a gabled porch roof (bislag) on two
## brackets. `c` the middle of the sill on the wall's face.
static func ndoor(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, col: Color, porch := true) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var basis := Basis(across, Vector3.UP, out)
	var w := 0.95
	var h := 2.05
	box_at(pk, kit, "painted", c + Vector3(0, h * 0.5, 0) + out * 0.04, basis, Vector3(w, h, 0.06), col)
	for py in [0.25, 0.7]:
		box_at(pk, kit, "painted", c + Vector3(0, h * py, 0) + out * 0.08, basis, Vector3(w * 0.7, h * 0.3, 0.03), col.lightened(0.1))
	box_at(pk, kit, "steel", c + across * 0.33 + Vector3(0, 1.0, 0) + out * 0.11, basis, Vector3(0.04, 0.2, 0.05), Color(0.2, 0.2, 0.21))
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "painted", c + across * (sx * (w * 0.5 + 0.07)) + Vector3(0, h * 0.5 + 0.06, 0) + out * 0.06, basis, Vector3(0.14, h + 0.12, 0.08), WHITE)
	box_at(pk, kit, "painted", c + Vector3(0, h + 0.15, 0) + out * 0.065, basis, Vector3(w + 0.4, 0.18, 0.09), WHITE)
	# The step: a stone block down to well under the ground.
	box_at(pk, kit, "stone", c + Vector3(0, -0.45, 0) + out * 0.45, basis, Vector3(w + 0.6, 0.9, 0.8), FOUNDATION.lightened(0.1))
	box_at(pk, kit, "snow", c + Vector3(0, 0.02, 0) + out * 0.55, basis, Vector3(w + 0.5, 0.05, 0.55), SNOW)
	if porch:
		# Low enough that its ridge (and the snow on it) stays under the main roof's fascia on a 1.5-storey house.
		var depth := 1.1
		var half := 0.8
		var ey: float = h + 0.25
		var ry: float = ey + half * 0.85
		var o: Vector3 = c + out * 0.02
		var p_l: Vector3 = o - across * half
		var p_r: Vector3 = o + across * half
		var top: Vector3 = o + Vector3(0, ry, 0)
		for side in [-1.0, 1.0]:
			var eave_a: Vector3 = o + across * (side * half) + Vector3(0, ey, 0)
			var n: Vector3 = (Vector3.UP * half + across * (side * 0.85)).normalized()
			roof(pk, kit, "slate", eave_a, eave_a + out * depth, top + out * depth, top, SLATE_ROOF, n)
			# Snow on it, a little inset and proud.
			var sa: Vector3 = eave_a.lerp(top, 0.04) + n * 0.06
			pk.quad(kit, "snow", [sa, sa + out * (depth - 0.06), top + n * 0.06 + out * (depth - 0.06), top + n * 0.06], n, SNOW)
			# A bracket under each eave.
			pk.beam(kit, "painted", o + across * (side * (half - 0.1)) + Vector3(0, ey - 0.75, 0), o + across * (side * (half - 0.1)) + Vector3(0, ey - 0.05, 0) + out * (depth - 0.1),
					0.09, 0.09, WHITE)
		# The porch's front gable, boarded.
		var fa: Vector3 = p_l + Vector3(0, ey, 0) + out * depth
		var fb: Vector3 = p_r + Vector3(0, ey, 0) + out * depth
		pk.tri(kit, "painted", fa, fb, top + out * depth, out, out, out, WHITE, out)
		pk.tri(kit, "painted", fa - out * 0.03, fb - out * 0.03, top + out * (depth - 0.03), -out, -out, -out, WHITE.darkened(0.3), -out)
		pk.beam(kit, "painted", fa, fb, 0.1, 0.12, WHITE, out)


## Corner boards: white boards on a wall's corners from `y0` to `y1`.
static func corner_boards(pk: PropKit, kit: Dictionary, w: float, d: float, y0: float, y1: float) -> void:
	for cx in [-1.0, 1.0]:
		for cz in [0.0, -1.0]:
			var x: float = cx * (w * 0.5 + 0.02)
			var z: float = cz * d + (0.02 if cz == 0.0 else -0.02)
			blk(pk, kit, "painted", Vector3(x - 0.09, y0, z - 0.09), Vector3(x + 0.09, y1, z + 0.09), WHITE)


## A gabled roof over a w x d box (ridge along x), its eave at `eave`, with overhangs, white fascias and bargeboards
## and a coat of snow; returns the ridge's height. `oh` the overhang at the eaves, `og` at the gables.
static func gable_roof(pk: PropKit, kit: Dictionary, w: float, d: float, eave: float, pitch: float, col: Color, oh := 0.45, og := 0.35,
		snow := true) -> float:
	var ridge: float = eave + d * 0.5 * pitch
	var zr: float = -d * 0.5
	for side in [1.0, -1.0]:
		# Front (side 1) plane from its eave at z = oh (or the back's at z = -d - oh) up to the ridge.
		var ze: float = oh if side > 0.0 else -d - oh
		var ye: float = eave - oh * pitch
		var n: Vector3 = Vector3(0, 1.0, side * pitch).normalized()
		var p0 := Vector3(-w * 0.5 - og, ye, ze)
		var p1 := Vector3(w * 0.5 + og, ye, ze)
		var p2 := Vector3(w * 0.5 + og, ridge, zr)
		var p3 := Vector3(-w * 0.5 - og, ridge, zr)
		roof(pk, kit, "slate", p0, p1, p2, p3, col, n)
		# Fascia along the eave.
		pk.beam(kit, "painted", p0 + Vector3(0, -0.1, side * 0.02), p1 + Vector3(0, -0.1, side * 0.02), 0.22, 0.05, WHITE, Vector3(0, 1, 0))
		if snow:
			var s := 0.12
			var a: Vector3 = p0 + n * s + Vector3(0.12, 0, 0)
			var b: Vector3 = p1 + n * s - Vector3(0.12, 0, 0)
			var c: Vector3 = p2 + n * s - Vector3(0.12, 0, 0)
			var e: Vector3 = p3 + n * s + Vector3(0.12, 0, 0)
			pk.quad(kit, "snow", [a, b, c, e], n, SNOW)
			# Its thickness along the eave and up both gable edges.
			var dn: Vector3 = -n * (s + 0.02)
			pk.quad(kit, "snow", [a, b, b + dn, a + dn], Vector3(0, -0.3, side).normalized(), SNOW.darkened(0.06))
			pk.quad(kit, "snow", [b, c, c + dn, b + dn], Vector3.RIGHT, SNOW.darkened(0.04))
			pk.quad(kit, "snow", [a, e, e + dn, a + dn], Vector3.LEFT, SNOW.darkened(0.04))
	# Bargeboards up the gables.
	for gx in [-1.0, 1.0]:
		var x: float = gx * (w * 0.5 + og + 0.02)
		for side in [1.0, -1.0]:
			var ze2: float = oh if side > 0.0 else -d - oh
			pk.beam(kit, "painted", Vector3(x, eave - oh * pitch - 0.1, ze2), Vector3(x, ridge - 0.05, zr), 0.24, 0.05, WHITE, Vector3(1, 0, 0))
	return ridge


## A chimney through the roof at (x, z): a rendered stack with a cap and snow on it, from inside the house up to `top`.
## Returns the middle of its mouth.
static func chimney(pk: PropKit, kit: Dictionary, x: float, z: float, y0: float, top: float) -> Vector3:
	blk(pk, kit, "stone", Vector3(x - 0.32, y0, z - 0.32), Vector3(x + 0.32, top, z + 0.32), Color(0.62, 0.60, 0.58))
	blk(pk, kit, "stone", Vector3(x - 0.4, top, z - 0.4), Vector3(x + 0.4, top + 0.12, z + 0.4), Color(0.45, 0.45, 0.46))
	blk(pk, kit, "snow", Vector3(x - 0.38, top + 0.12, z - 0.38), Vector3(x + 0.38, top + 0.17, z - 0.1), SNOW)
	blk(pk, kit, "snow", Vector3(x - 0.38, top + 0.12, z + 0.1), Vector3(x + 0.38, top + 0.17, z + 0.38), SNOW)
	return Vector3(x, top + 0.2, z)


# ======================================================================================
#  Buildings
# ======================================================================================

## A house `w` wide and `d` deep with `floors` floors (1, 1.5: a knee wall under the roof, or 2), painted `paint`, on a
## stone foundation `plinth` deep. Windows along the front and back and in the gables, the door at `door_x` (share of
## the front, -0.5..0.5) under its porch. Returns the chimney's mouth.
static func house(pk: PropKit, kit: Dictionary, w: float, d: float, floors: float, paint: Color, plinth: float, door_x := 0.0,
		seed_v := 0) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var fy := 0.5
	blk(pk, kit, "stone", Vector3(-w * 0.5 - 0.1, -plinth, -d - 0.1), Vector3(w * 0.5 + 0.1, fy, 0.1), FOUNDATION)
	var storey := 2.7
	# A 1.5-storey house has a 1m knee wall under the roof, a 2-storey one 0.3m, so the upper windows' casings stay
	# under the eave's fascia.
	var eave: float = fy + storey * floor(floors) + (1.0 if fmod(floors, 1.0) > 0.0 else (0.3 if floors >= 2.0 else 0.0))
	var key := "battens"
	wall(pk, kit, key, Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), fy, eave, paint, Vector3.BACK)
	wall(pk, kit, key, Vector3(w * 0.5, 0, -d), Vector3(-w * 0.5, 0, -d), fy, eave, paint, Vector3.FORWARD)
	wall(pk, kit, key, Vector3(w * 0.5, 0, 0), Vector3(w * 0.5, 0, -d), fy, eave, paint, Vector3.RIGHT)
	wall(pk, kit, key, Vector3(-w * 0.5, 0, -d), Vector3(-w * 0.5, 0, 0), fy, eave, paint, Vector3.LEFT)
	var ridge: float = eave + d * 0.5 * PITCH
	for gx in [-1.0, 1.0]:
		gable(pk, kit, key, Vector3(gx * w * 0.5, eave, 0.0 if gx > 0.0 else -d), Vector3(gx * w * 0.5, eave, -d if gx > 0.0 else 0.0),
				Vector3(gx * w * 0.5, ridge, -d * 0.5), paint, Vector3(gx, 0, 0))
	corner_boards(pk, kit, w, d, fy - 0.05, eave)
	gable_roof(pk, kit, w, d, eave, PITCH, SLATE_ROOF)
	# Windows: a row per full floor front and back, a pair in each gable.
	var n_win: int = maxi(2, int(round(w / 2.4)))
	var door_u: float = door_x * w
	for fl in range(int(floor(floors))):
		var cy: float = fy + storey * float(fl) + (1.4 if fl == 0 else 1.3)
		for k in range(n_win):
			var x: float = -w * 0.5 + w * (float(k) + 0.5) / float(n_win)
			# Clear of the door's porch (0.8 either side) and its brackets.
			if fl == 0 and absf(x - door_u) < 1.75:
				continue
			nwindow(pk, kit, Vector3(x, cy, 0.0), Vector3.BACK, 0.9, 1.25)
			nwindow(pk, kit, Vector3(x, cy, -d), Vector3.FORWARD, 0.9, 1.25)
	# Two windows in each gable, near its middle. The attic's (1.5 and 2 storeys) go as high as the roof's slope lets
	# their casing, crown board and its snow stand GABLE_CLEAR under the roof at their outer side; out at gz -0.3 and
	# -0.7 of the depth they stuck up through the roof. A one-storey house's light its ground floor.
	var gw := 0.75
	var gh := 1.0
	var off: float = minf(1.0, d * 0.5 - gw)
	var gy: float = fy + 1.4
	if fmod(floors, 1.0) > 0.0 or floors >= 2.0:
		var edge_y: float = eave + (d * 0.5 - off - gw * 0.5 - WINDOW_CASING) * PITCH
		gy = minf(eave + 0.9, edge_y - GABLE_CLEAR - gh * 0.5 - WINDOW_TOP)
	for gx in [-1.0, 1.0]:
		for gs in [-1.0, 1.0]:
			nwindow(pk, kit, Vector3(gx * w * 0.5, gy, -d * 0.5 + gs * off), Vector3(gx, 0, 0), gw, gh)
	# The porch only where the wall stands high enough under the eave for it (not on a one-storey house).
	ndoor(pk, kit, Vector3(door_u, fy, 0.0), Vector3.BACK, PAINTS[rng.randi() % PAINTS.size()].darkened(0.25), floors >= 1.5)
	var cx: float = w * (0.18 if rng.randf() < 0.5 else -0.2)
	return chimney(pk, kit, cx, -d * 0.5 + 0.3, ridge - 1.2, ridge + 0.9)


## The church: a white long church in timber, its axis along x, the tower at the west end (-x) with the door, the nave,
## a lower, narrower chancel at the east end; tall windows down both sides; a slender eight-sided spire with a cross.
## The nave's south wall is the front (z = 0). Returns the spire's top.
static func church(pk: PropKit, kit: Dictionary, plinth: float) -> Vector3:
	var fy := 0.6
	var nave_l := 16.0
	var nave_d := 10.0
	var eave := fy + 6.2
	var x0: float = -nave_l * 0.5
	var x1: float = nave_l * 0.5
	blk(pk, kit, "stone", Vector3(x0 - 4.6, -plinth, -nave_d - 0.2), Vector3(x1 + 5.2, fy, 0.2), FOUNDATION)
	# Nave.
	wall(pk, kit, "lapboards", Vector3(x0, 0, 0), Vector3(x1, 0, 0), fy, eave, WHITE, Vector3.BACK)
	wall(pk, kit, "lapboards", Vector3(x1, 0, -nave_d), Vector3(x0, 0, -nave_d), fy, eave, WHITE, Vector3.FORWARD)
	var npitch := 1.15
	var ridge: float = eave + nave_d * 0.5 * npitch
	for gx in [-1.0, 1.0]:
		var gxp: float = x1 if gx > 0.0 else x0
		wall(pk, kit, "lapboards", Vector3(gxp, 0, 0.0 if gx > 0.0 else -nave_d), Vector3(gxp, 0, -nave_d if gx > 0.0 else 0.0), fy, eave, WHITE, Vector3(gx, 0, 0))
		gable(pk, kit, "lapboards", Vector3(gxp, eave, 0.0 if gx > 0.0 else -nave_d), Vector3(gxp, eave, -nave_d if gx > 0.0 else 0.0),
				Vector3(gxp, ridge, -nave_d * 0.5), WHITE, Vector3(gx, 0, 0))
	_shifted_roof(pk, kit, Vector3.ZERO, nave_l, nave_d, eave, npitch)
	for k in range(4):
		var x: float = x0 + nave_l * (float(k) + 0.5) / 4.0
		nwindow(pk, kit, Vector3(x, fy + 3.3, 0.0), Vector3.BACK, 1.1, 2.6, 4)
		nwindow(pk, kit, Vector3(x, fy + 3.3, -nave_d), Vector3.FORWARD, 1.1, 2.6, 4)
	# Chancel.
	var c_d := 6.6
	var c_l := 5.0
	var cz0: float = -(nave_d - c_d) * 0.5
	var c_eave: float = fy + 4.8
	var c_ridge: float = c_eave + c_d * 0.5 * npitch
	wall(pk, kit, "lapboards", Vector3(x1, 0, cz0), Vector3(x1 + c_l, 0, cz0), fy, c_eave, WHITE, Vector3.BACK)
	wall(pk, kit, "lapboards", Vector3(x1 + c_l, 0, cz0 - c_d), Vector3(x1, 0, cz0 - c_d), fy, c_eave, WHITE, Vector3.FORWARD)
	wall(pk, kit, "lapboards", Vector3(x1 + c_l, 0, cz0), Vector3(x1 + c_l, 0, cz0 - c_d), fy, c_eave, WHITE, Vector3.RIGHT)
	gable(pk, kit, "lapboards", Vector3(x1 + c_l, c_eave, cz0), Vector3(x1 + c_l, c_eave, cz0 - c_d), Vector3(x1 + c_l, c_ridge, cz0 - c_d * 0.5), WHITE, Vector3.RIGHT)
	_shifted_roof(pk, kit, Vector3(x1 + c_l * 0.5 + 0.2, 0, cz0), c_l + 0.4, c_d, c_eave, npitch, 0.0, 0.35)
	nwindow(pk, kit, Vector3(x1 + c_l * 0.5, fy + 2.6, cz0), Vector3.BACK, 0.9, 2.0, 3)
	nwindow(pk, kit, Vector3(x1 + c_l * 0.5, fy + 2.6, cz0 - c_d), Vector3.FORWARD, 0.9, 2.0, 3)
	corner_boards(pk, kit, nave_l, nave_d, fy - 0.05, eave)
	# Tower: a square shaft to the belfry, louvred openings, a cornice, then the spire.
	var t := 4.4
	var tx0: float = x0 - t
	var tz0: float = -(nave_d - t) * 0.5
	var t_top: float = fy + 15.0
	var tb := Vector3(x0 - t * 0.5, 0, tz0 - t * 0.5)
	for face in [[Vector3(tx0, 0, tz0), Vector3(x0, 0, tz0), Vector3.BACK], [Vector3(x0, 0, tz0 - t), Vector3(tx0, 0, tz0 - t), Vector3.FORWARD],
			[Vector3(tx0, 0, tz0 - t), Vector3(tx0, 0, tz0), Vector3.LEFT]]:
		wall(pk, kit, "lapboards", face[0], face[1], fy, t_top, WHITE, face[2])
	wall(pk, kit, "lapboards", Vector3(x0 + 0.02, 0, tz0), Vector3(x0 + 0.02, 0, tz0 - t), ridge - 0.2, t_top, WHITE, Vector3.RIGHT)
	for o in [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT]:
		var c: Vector3 = tb + o * (t * 0.5) + Vector3(0, t_top - 2.0, 0)
		var basis := Basis(o.cross(Vector3.UP).normalized(), Vector3.UP, o)
		box_at(pk, kit, "painted", c + o * 0.03, basis, Vector3(1.6, 2.0, 0.04), Color(0.18, 0.17, 0.16))
		for k in range(6):
			box_at(pk, kit, "painted", c + o * 0.06 + Vector3(0, -0.85 + float(k) * 0.34, 0), basis, Vector3(1.6, 0.06, 0.08), WHITE)
	blk(pk, kit, "painted", Vector3(tx0 - 0.25, t_top, tz0 - t - 0.25), Vector3(x0 + 0.25, t_top + 0.3, tz0 + 0.25), WHITE)
	blk(pk, kit, "snow", Vector3(tx0 - 0.23, t_top + 0.3, tz0 - t - 0.23), Vector3(x0 + 0.23, t_top + 0.36, tz0 + 0.23), SNOW)
	# The spire: eight faces of slate from the tower's top to a point, snow lying only low on it.
	var sp_base: Vector3 = tb + Vector3(0, t_top + 0.3, 0)
	var sp_top: Vector3 = sp_base + Vector3(0, 11.0, 0)
	var r0: float = t * 0.5 * 0.92
	for k in range(8):
		var a0: float = TAU * (float(k) + 0.5) / 8.0
		var a1: float = TAU * (float(k) + 1.5) / 8.0
		var pa: Vector3 = sp_base + Vector3(cos(a0), 0, sin(a0)) * r0
		var pb: Vector3 = sp_base + Vector3(cos(a1), 0, sin(a1)) * r0
		var mid_d: Vector3 = Vector3(cos((a0 + a1) * 0.5), 0, sin((a0 + a1) * 0.5))
		var n: Vector3 = (mid_d * 11.0 + Vector3.UP * r0).normalized()
		pk.tri(kit, "slate", pa, pb, sp_top, n, n, n, SLATE_ROOF, n)
	# Cross on top.
	pk.beam(kit, "steel", sp_top - Vector3(0, 0.2, 0), sp_top + Vector3(0, 1.6, 0), 0.1, 0.1, Color(0.75, 0.62, 0.3))
	pk.beam(kit, "steel", sp_top + Vector3(-0.5, 1.05, 0), sp_top + Vector3(0.5, 1.05, 0), 0.1, 0.1, Color(0.75, 0.62, 0.3), Vector3(0, 0, 1))
	# The west door, double, with a little porch.
	ndoor(pk, kit, Vector3(tx0, fy, tz0 - t * 0.5), Vector3.LEFT, Color(0.42, 0.16, 0.12), true)
	nwindow(pk, kit, Vector3(tx0, fy + 6.5, tz0 - t * 0.5), Vector3.LEFT, 0.8, 1.6, 3)
	return sp_top + Vector3(0, 1.6, 0)


## gable_roof for a box whose front middle stands at `at` (x the middle of its length).
static func _shifted_roof(pk: PropKit, kit: Dictionary, at: Vector3, l: float, d: float, eave: float, pitch: float, og := 0.35,
		oh := 0.45) -> void:
	var keep: Transform3D = pk.xf
	pk.set_frame(keep * Transform3D(Basis(), at))
	gable_roof(pk, kit, l, d, eave, pitch, SLATE_ROOF, oh, og)
	pk.set_frame(keep)


## A fisherman's cabin (rorbu): red boards, white trim, its gable and door toward the sea (+z), a little deck in front
## with a railing, all on timber stilts `stilt` metres down to the shore or the sea bed. Built with the gable as the
## front: the ridge runs along z. Returns the chimney's mouth.
static func rorbu(pk: PropKit, kit: Dictionary, w: float, d: float, paint: Color, stilt: float, seed_v := 0) -> Vector3:
	var fy := 0.0
	var eave := 2.9
	var deck := 2.2
	# Stilts and the floor frame.
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [deck, 0.0, -d * 0.5, -d]:
			var p := Vector3(sx * (w * 0.5 - 0.15), 0, sz - (0.15 if sz > 0.0 else 0.0))
			pk.tube(kit, "timber", p + Vector3(0, -stilt, 0), p + Vector3(0, -0.15, 0), 0.16, 0.14, 8, WOOD_GREY)
	blk(pk, kit, "timber", Vector3(-w * 0.5 - 0.1, -0.35, -d - 0.1), Vector3(w * 0.5 + 0.1, fy, deck), WOOD_GREY.darkened(0.15))
	blk(pk, kit, "snow", Vector3(-w * 0.5, fy, 0.05), Vector3(w * 0.5, fy + 0.05, deck - 0.05), SNOW)
	# Walls: the long sides along z, the gables at z = 0 (sea) and z = -d.
	wall(pk, kit, "battens", Vector3(w * 0.5, 0, 0), Vector3(w * 0.5, 0, -d), fy, eave, paint, Vector3.RIGHT)
	wall(pk, kit, "battens", Vector3(-w * 0.5, 0, -d), Vector3(-w * 0.5, 0, 0), fy, eave, paint, Vector3.LEFT)
	wall(pk, kit, "battens", Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), fy, eave, paint, Vector3.BACK)
	wall(pk, kit, "battens", Vector3(w * 0.5, 0, -d), Vector3(-w * 0.5, 0, -d), fy, eave, paint, Vector3.FORWARD)
	var pitch := 0.95
	var ridge: float = eave + w * 0.5 * pitch
	gable(pk, kit, "battens", Vector3(-w * 0.5, eave, 0), Vector3(w * 0.5, eave, 0), Vector3(0, ridge, 0), paint, Vector3.BACK)
	gable(pk, kit, "battens", Vector3(w * 0.5, eave, -d), Vector3(-w * 0.5, eave, -d), Vector3(0, ridge, -d), paint, Vector3.FORWARD)
	corner_boards(pk, kit, w, d, fy, eave)
	# The roof (ridge along z): build gable_roof turned a quarter round.
	var keep: Transform3D = pk.xf
	# Turned a quarter round (its x along -z, its z along +x) and moved so its box covers this one.
	pk.set_frame(keep * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5, 0, -d * 0.5)))
	gable_roof(pk, kit, d, w, eave, pitch, SLATE_ROOF, 0.4, 0.4)
	pk.set_frame(keep)
	ndoor(pk, kit, Vector3(-w * 0.18, fy, 0.0), Vector3.BACK, Color(0.92, 0.92, 0.88), false)
	nwindow(pk, kit, Vector3(w * 0.24, fy + 1.5, 0.0), Vector3.BACK, 0.8, 1.0)
	nwindow(pk, kit, Vector3(0, eave + 0.9, 0.0), Vector3.BACK, 0.6, 0.8, 1)
	for sz in [-0.3, -0.75]:
		nwindow(pk, kit, Vector3(w * 0.5, fy + 1.4, d * sz), Vector3.RIGHT, 0.8, 0.95)
		nwindow(pk, kit, Vector3(-w * 0.5, fy + 1.4, d * sz), Vector3.LEFT, 0.8, 0.95)
	# The deck's railing.
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "painted", Vector3(sx * (w * 0.5 - 0.05), fy + 1.0, 0.05), Vector3(sx * (w * 0.5 - 0.05), fy + 1.0, deck - 0.05), 0.08, 0.08, WHITE)
		pk.beam(kit, "painted", Vector3(sx * (w * 0.5 - 0.05), fy, deck - 0.05), Vector3(sx * (w * 0.5 - 0.05), fy + 1.0, deck - 0.05), 0.08, 0.08, WHITE)
	pk.beam(kit, "painted", Vector3(-w * 0.5, fy + 1.0, deck - 0.05), Vector3(w * 0.5, fy + 1.0, deck - 0.05), 0.08, 0.08, WHITE, Vector3(0, 0, 1))
	return chimney(pk, kit, w * 0.2, -d * 0.7, ridge - 1.4, ridge + 0.7)


## A boathouse (naust): tarred boards on a stone footing, a steep roof, big double doors in the sea gable (+z). The
## ridge runs along z.
static func naust(pk: PropKit, kit: Dictionary, w: float, d: float, plinth: float) -> void:
	var fy := 0.3
	var eave := 2.4
	blk(pk, kit, "stone", Vector3(-w * 0.5 - 0.15, -plinth, -d - 0.15), Vector3(w * 0.5 + 0.15, fy, 0.15), FOUNDATION.darkened(0.1))
	wall(pk, kit, "battens", Vector3(w * 0.5, 0, 0), Vector3(w * 0.5, 0, -d), fy, eave, TAR, Vector3.RIGHT)
	wall(pk, kit, "battens", Vector3(-w * 0.5, 0, -d), Vector3(-w * 0.5, 0, 0), fy, eave, TAR, Vector3.LEFT)
	wall(pk, kit, "battens", Vector3(-w * 0.5, 0, 0), Vector3(w * 0.5, 0, 0), fy, eave, TAR, Vector3.BACK)
	wall(pk, kit, "battens", Vector3(w * 0.5, 0, -d), Vector3(-w * 0.5, 0, -d), fy, eave, TAR, Vector3.FORWARD)
	var pitch := 1.2
	var ridge: float = eave + w * 0.5 * pitch
	gable(pk, kit, "battens", Vector3(-w * 0.5, eave, 0), Vector3(w * 0.5, eave, 0), Vector3(0, ridge, 0), TAR, Vector3.BACK)
	gable(pk, kit, "battens", Vector3(w * 0.5, eave, -d), Vector3(-w * 0.5, eave, -d), Vector3(0, ridge, -d), TAR, Vector3.FORWARD)
	var keep: Transform3D = pk.xf
	# Turned a quarter round (its x along -z, its z along +x) and moved so its box covers this one.
	pk.set_frame(keep * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(w * 0.5, 0, -d * 0.5)))
	gable_roof(pk, kit, d, w, eave, pitch, SLATE_ROOF.darkened(0.1), 0.3, 0.3)
	pk.set_frame(keep)
	# Doors: two leaves of planks with a white frame.
	var basis := Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "battens", Vector3(sx * w * 0.19, fy + 1.45, 0.04), basis, Vector3(w * 0.37, 2.6, 0.06), TAR.lightened(0.08))
	box_at(pk, kit, "painted", Vector3(0, fy + 2.85, 0.06), basis, Vector3(w * 0.8, 0.14, 0.08), WHITE.darkened(0.15))


## A timber quay `length` (x) by `width` (z, out over the water toward +z) with its deck at `deck_y` over the water at
## y 0, on piles down to `depth` under it: planks on stringers, an edge timber, bollards, a ladder down. Snow on the
## deck except where it's trodden.
static func quay(pk: PropKit, kit: Dictionary, length: float, width: float, deck_y: float, depth: float) -> void:
	var x0: float = -length * 0.5
	for k in range(int(length / 3.0) + 1):
		var x: float = x0 + minf(float(k) * 3.0, length)
		for z in [0.3, width * 0.5, width - 0.3]:
			pk.tube(kit, "timber", Vector3(x, -depth, z), Vector3(x, deck_y - 0.3, z), 0.2, 0.18, 8, WOOD_GREY.darkened(0.25))
		pk.beam(kit, "timber", Vector3(x, deck_y - 0.35, 0.0), Vector3(x, deck_y - 0.35, width), 0.3, 0.3, WOOD_GREY.darkened(0.2), Vector3.RIGHT)
	blk(pk, kit, "timber", Vector3(x0, deck_y - 0.2, 0.0), Vector3(-x0, deck_y, width), WOOD_GREY)
	# Snow lies along the edges; the middle is trodden down to the planks.
	blk(pk, kit, "snow", Vector3(x0 + 0.05, deck_y, width - 1.1), Vector3(-x0 - 0.05, deck_y + 0.06, width - 0.35), SNOW)
	blk(pk, kit, "snow", Vector3(x0 + 0.05, deck_y, 0.05), Vector3(-x0 - 0.05, deck_y + 0.05, 0.9), SNOW)
	blk(pk, kit, "timber", Vector3(x0, deck_y, width - 0.3), Vector3(-x0, deck_y + 0.25, width), WOOD_GREY.darkened(0.3))
	for k in range(int(length / 8.0) + 1):
		var x2: float = x0 + 2.0 + float(k) * 8.0
		if x2 > -x0 - 1.0:
			break
		pk.lathe(kit, "steel", Vector3(x2, deck_y + 0.25, width - 0.6), [Vector2(0.22, 0.0), Vector2(0.18, 0.1), Vector2(0.16, 0.5),
				Vector2(0.26, 0.58), Vector2(0.26, 0.66), Vector2(0.001, 0.66)], 10, Color(0.15, 0.16, 0.17), true)
	for k in range(9):
		pk.beam(kit, "steel", Vector3(x0 + 4.0 - 0.3, deck_y - float(k) * 0.4, width + 0.08), Vector3(x0 + 4.0 + 0.3, deck_y - float(k) * 0.4, width + 0.08),
				0.04, 0.04, Color(0.3, 0.3, 0.3), Vector3(0, 0, 1))


## A rack of drying stockfish (hjell): A-frames of poles every 2.5m along x with poles laid across them, and pairs of
## cod hanging over the poles, `length` long.
static func hjell(pk: PropKit, kit: Dictionary, length: float, seed_v := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var h := 3.2
	var n: int = int(length / 2.5)
	var x0: float = -length * 0.5
	for k in range(n + 1):
		var x: float = x0 + float(k) * 2.5
		for s in [-1.0, 1.0]:
			pk.tube(kit, "timber", Vector3(x, -0.4, s * 1.2), Vector3(x, h + 0.2, -s * 0.15), 0.07, 0.05, 6, WOOD_GREY)
	for lvl in [h - 0.05, h - 1.0]:
		var z: float = 0.0 if lvl > h - 0.5 else 0.5
		pk.tube(kit, "timber", Vector3(x0 - 0.3, lvl, z), Vector3(-x0 + 0.3, lvl, z), 0.05, 0.05, 6, WOOD_GREY.lightened(0.05))
		var x2: float = x0 + 0.3
		while x2 < -x0 - 0.3:
			var c := Color(0.62, 0.55, 0.44).lerp(Color(0.45, 0.40, 0.33), rng.randf())
			for side in [-1.0, 1.0]:
				var top := Vector3(x2, lvl, z + side * 0.05)
				var fish_l: float = rng.randf_range(0.55, 0.75)
				pk.beam(kit, "timber", top, top + Vector3(0, -fish_l, side * 0.08), 0.12, 0.03, c, Vector3(1, 0, 0))
			x2 += rng.randf_range(0.28, 0.4)


## A kick-sled (spark): two long runners turned up at the front, a slatted seat on two uprights, the handlebar.
static func spark(pk: PropKit, kit: Dictionary) -> void:
	for sx in [-0.22, 0.22]:
		pk.beam(kit, "steel", Vector3(sx, 0.03, 0.9), Vector3(sx, 0.03, -1.5), 0.03, 0.02, Color(0.2, 0.2, 0.22), Vector3.RIGHT)
		pk.beam(kit, "steel", Vector3(sx, 0.03, 0.9), Vector3(sx, 0.15, 1.05), 0.03, 0.02, Color(0.2, 0.2, 0.22), Vector3.RIGHT)
		pk.beam(kit, "painted", Vector3(sx, 0.03, 0.55), Vector3(sx, 0.55, 0.5), 0.04, 0.04, Color(0.55, 0.14, 0.11))
		pk.beam(kit, "painted", Vector3(sx, 0.03, 0.1), Vector3(sx, 1.05, 0.0), 0.04, 0.04, Color(0.55, 0.14, 0.11))
	blk(pk, kit, "timber", Vector3(-0.26, 0.55, 0.15), Vector3(0.26, 0.6, 0.6), Color(0.55, 0.42, 0.30))
	pk.beam(kit, "timber", Vector3(-0.26, 0.6, 0.15), Vector3(-0.26, 0.95, 0.1), 0.04, 0.04, Color(0.55, 0.42, 0.30))
	pk.beam(kit, "timber", Vector3(0.26, 0.6, 0.15), Vector3(0.26, 0.95, 0.1), 0.04, 0.04, Color(0.55, 0.42, 0.30))
	blk(pk, kit, "timber", Vector3(-0.27, 0.85, 0.08), Vector3(0.27, 0.97, 0.12), Color(0.55, 0.42, 0.30))
	pk.beam(kit, "steel", Vector3(-0.3, 1.05, 0.0), Vector3(0.3, 1.05, 0.0), 0.04, 0.04, Color(0.2, 0.2, 0.22), Vector3(0, 0, 1))


## A woodpile against a wall: split logs stacked `l` long, 1.2m high, under a strip of snow.
static func woodpile(pk: PropKit, kit: Dictionary, l: float, seed_v := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var rows := 6
	for r in range(rows):
		var x: float = -l * 0.5 + 0.12
		while x < l * 0.5 - 0.1:
			var rr: float = rng.randf_range(0.08, 0.12)
			var y: float = 0.1 + float(r) * 0.2
			pk.tube(kit, "timber", Vector3(x, y, -0.25), Vector3(x, y, 0.25), rr, rr, 6, Color(0.62, 0.50, 0.36).lerp(Color(0.48, 0.38, 0.28), rng.randf()))
			x += rr * 2.0 + 0.01
	blk(pk, kit, "snow", Vector3(-l * 0.5, 0.1 + float(rows) * 0.2 - 0.05, -0.27), Vector3(l * 0.5, 0.1 + float(rows) * 0.2 + 0.05, 0.27), SNOW)
