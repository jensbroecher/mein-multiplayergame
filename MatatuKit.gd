extends RefCounted
## Nairobi matatus: a 14-seat high-roof minibus (the Toyota HiAce shape that fills the city's roads)
## in a hand-painted livery, built through a PropKit at life size (5.4 x 1.9 x 2.3m) and scaled by the caller.
##
## Axes: x across (the driver sits on +x, since Kenya drives on the left and the cab is on the right; the
## sliding door is on -x, the kerb side), y up, z along, the nose toward -z.
##
## The shell is a loft of cross-sections along z (`_ring`): bottom, corners, a flat side with a little
## tumblehome above the belt, the crowned roof. Arches are cut by lifting the bottom over each wheel.
## The side wall is exactly planar below the belt and exactly tilted above it, so windows and paint can be
## laid on it as flat polygons (`_side_poly`), clipped to the arches. Everything is in five material keys,
## so a matatu is five draw calls: `paint` (clearcoat, vertex colour), `glass`, `chrome`, `matte`
## (black plastic, rubber, underbody) and `lamp` (emissive, tinted by the vertex colour).
##
## Liveries (`LIVERIES`) are data: colours, the name painted on it, and a style that picks the artwork.

const PropKit = preload("res://PropKit.gd")

# ---------------------------------------------------------------------------------------------
#  Dimensions (life size, metres)
# ---------------------------------------------------------------------------------------------
const Z_NOSE := -2.70
const Z_TAIL := 2.70
const HW := 0.94
const AXLE_F := -1.76
const AXLE_R := 1.44
const WHEEL_R := 0.375
const WHEEL_X := 0.79
const ARCH_R := 0.445
const Y_BOT := 0.30
const TILT := 0.10
const BELT := 1.10
const RB := 0.09

## (z, y) of the roof's centre line: bonnet, windscreen (a straight run from (-1.85, 1.27) to (-1.28, 2.08)), roof.
const TOP := [
	[-2.70, 0.98], [-2.62, 1.015], [-2.40, 1.055], [-2.10, 1.095], [-1.95, 1.13], [-1.85, 1.27],
	[-1.28, 2.08], [-1.16, 2.20], [-1.02, 2.27], [-0.85, 2.28], [2.35, 2.28], [2.55, 2.23], [2.70, 2.12],
]

const TYRE := Color(0.06, 0.06, 0.065)
const BLACK := Color(0.045, 0.047, 0.05)
const RUBBER := Color(0.09, 0.09, 0.10)
const UNDER := Color(0.035, 0.035, 0.04)
const CHROME := Color(0.90, 0.91, 0.93)
const GUNMETAL := Color(0.13, 0.14, 0.16)

## Paint, by the livery's fields. `style` picks the artwork (see _art). Colours are sRGB.
##   base   lower body          upper  body above the belt line     roof  roof and pillars
##   a1 a2 a3  the artwork's colours     band  the Sacco stripe (or none)    neon  underglow
const LIVERIES := [
	{"name": "MOTO", "txt": Color(0.97, 0.97, 0.94), "shd": Color(0.85, 0.12, 0.04), "style": "flames", "base": Color(0.05, 0.05, 0.06), "upper": Color(0.05, 0.05, 0.06), "roof": Color(0.93, 0.93, 0.91),
			"a1": Color(0.95, 0.18, 0.05), "a2": Color(1.0, 0.55, 0.05), "a3": Color(1.0, 0.88, 0.20), "band": Color(0.98, 0.80, 0.08),
			"neon": Color(1.0, 0.35, 0.05), "route": "23", "plate": "KDG 417M", "slogan": "NIMEBARIKIWA"},
	{"name": "MALAIKA", "txt": Color(0.95, 0.20, 0.55), "shd": Color(0.35, 0.12, 0.60), "style": "swoosh", "base": Color(0.94, 0.94, 0.95), "upper": Color(0.94, 0.94, 0.95), "roof": Color(0.94, 0.94, 0.95),
			"a1": Color(0.95, 0.20, 0.55), "a2": Color(0.10, 0.75, 0.85), "a3": Color(0.35, 0.12, 0.60), "band": Color(0.98, 0.80, 0.08),
			"neon": Color(0.95, 0.20, 0.75), "route": "46", "plate": "KCB 092T", "slogan": "TUKO PAMOJA"},
	{"name": "SIMBA", "txt": Color(0.05, 0.05, 0.06), "shd": Color(0.85, 0.12, 0.10), "style": "zebra", "base": Color(0.98, 0.78, 0.06), "upper": Color(0.98, 0.78, 0.06), "roof": Color(0.06, 0.06, 0.07),
			"a1": Color(0.05, 0.05, 0.06), "a2": Color(0.95, 0.95, 0.93), "a3": Color(0.85, 0.12, 0.10), "band": Color(0.05, 0.05, 0.06),
			"neon": Color(1.0, 0.85, 0.15), "route": "111", "plate": "KDA 266K", "slogan": "KING OF THE ROAD"},
	{"name": "UHURU", "txt": Color(0.97, 0.97, 0.94), "shd": Color(0.04, 0.04, 0.05), "style": "flag", "base": Color(0.78, 0.07, 0.10), "upper": Color(0.78, 0.07, 0.10), "roof": Color(0.93, 0.93, 0.91),
			"a1": Color(0.04, 0.04, 0.05), "a2": Color(0.05, 0.50, 0.20), "a3": Color(0.95, 0.95, 0.93), "band": Color(0.98, 0.80, 0.08),
			"neon": Color(0.20, 0.95, 0.35), "route": "58", "plate": "KCZ 735D", "slogan": "SHUKRANI KWA MUNGU"},
	{"name": "NYOTA", "txt": Color(1.0, 0.82, 0.15), "shd": Color(0.02, 0.04, 0.16), "style": "stars", "base": Color(0.06, 0.12, 0.38), "upper": Color(0.06, 0.12, 0.38), "roof": Color(0.93, 0.93, 0.91),
			"a1": Color(1.0, 0.82, 0.15), "a2": Color(0.30, 0.65, 1.0), "a3": Color(0.93, 0.93, 0.91), "band": Color(0.98, 0.80, 0.08),
			"neon": Color(0.25, 0.55, 1.0), "route": "33", "plate": "KDC 508B", "slogan": "MUNGU NI MWEMA"},
	{"name": "SHUJAA", "txt": Color(0.15, 0.90, 0.85), "shd": Color(0.12, 0.03, 0.18), "style": "bolts", "base": Color(0.42, 0.10, 0.55), "upper": Color(0.42, 0.10, 0.55), "roof": Color(0.05, 0.05, 0.06),
			"a1": Color(0.15, 0.90, 0.85), "a2": Color(1.0, 0.85, 0.20), "a3": Color(0.95, 0.95, 0.93), "band": Color(0.98, 0.80, 0.08),
			"neon": Color(0.15, 0.95, 0.85), "route": "125", "plate": "KCY 871F", "slogan": "DREAM CHASER"},
	{"name": "BINGWA", "txt": Color(0.08, 0.50, 0.24), "shd": Color(0.04, 0.04, 0.05), "style": "check", "base": Color(0.93, 0.93, 0.91), "upper": Color(0.93, 0.93, 0.91), "roof": Color(0.08, 0.50, 0.24),
			"a1": Color(0.08, 0.50, 0.24), "a2": Color(0.05, 0.05, 0.06), "a3": Color(0.98, 0.80, 0.08), "band": Color(0.98, 0.80, 0.08),
			"neon": Color(0.30, 1.0, 0.45), "route": "102", "plate": "KDB 144S", "slogan": "MAMA'S BOY"},
	{"name": "RAFIKI", "txt": Color(1.0, 0.55, 0.08), "shd": Color(0.03, 0.10, 0.30), "style": "swoosh", "base": Color(0.10, 0.45, 0.80), "upper": Color(0.10, 0.45, 0.80), "roof": Color(0.93, 0.93, 0.91),
			"a1": Color(1.0, 0.55, 0.08), "a2": Color(0.93, 0.93, 0.91), "a3": Color(0.04, 0.12, 0.35), "band": Color(0.98, 0.80, 0.08),
			"neon": Color(1.0, 0.55, 0.10), "route": "44", "plate": "KCW 320H", "slogan": "SAFARI NJEMA"},
]

## Block capitals, five rows high (letters 3 to 5 cells wide).
const GLYPHS := {
	" ": ["..", "..", "..", "..", ".."],
	"A": [".XX.", "X..X", "XXXX", "X..X", "X..X"], "B": ["XXX.", "X..X", "XXX.", "X..X", "XXX."],
	"C": [".XXX", "X...", "X...", "X...", ".XXX"], "D": ["XXX.", "X..X", "X..X", "X..X", "XXX."],
	"E": ["XXXX", "X...", "XXX.", "X...", "XXXX"], "F": ["XXXX", "X...", "XXX.", "X...", "X..."],
	"G": [".XXX", "X...", "X.XX", "X..X", ".XXX"], "H": ["X..X", "X..X", "XXXX", "X..X", "X..X"],
	"I": ["XXX", ".X.", ".X.", ".X.", "XXX"], "J": ["..XX", "...X", "...X", "X..X", ".XX."],
	"K": ["X..X", "X.X.", "XX..", "X.X.", "X..X"], "L": ["X...", "X...", "X...", "X...", "XXXX"],
	"M": ["X...X", "XX.XX", "X.X.X", "X...X", "X...X"], "N": ["X..X", "XX.X", "X.XX", "X..X", "X..X"],
	"O": [".XX.", "X..X", "X..X", "X..X", ".XX."], "P": ["XXX.", "X..X", "XXX.", "X...", "X..."],
	"Q": [".XX.", "X..X", "X..X", "X.XX", ".XXX"], "R": ["XXX.", "X..X", "XXX.", "X.X.", "X..X"],
	"S": [".XXX", "X...", ".XX.", "...X", "XXX."], "T": ["XXXXX", "..X..", "..X..", "..X..", "..X.."],
	"U": ["X..X", "X..X", "X..X", "X..X", ".XX."], "V": ["X...X", "X...X", ".X.X.", ".X.X.", "..X.."],
	"W": ["X...X", "X...X", "X.X.X", "XX.XX", "X...X"], "X": ["X...X", ".X.X.", "..X..", ".X.X.", "X...X"],
	"Y": ["X...X", ".X.X.", "..X..", "..X..", "..X.."], "Z": ["XXXX", "...X", "..X.", "X...", "XXXX"],
	"0": [".XX.", "X..X", "X..X", "X..X", ".XX."], "1": [".X.", "XX.", ".X.", ".X.", "XXX"],
	"2": [".XX.", "X..X", "..X.", ".X..", "XXXX"], "3": ["XXX.", "...X", ".XX.", "...X", "XXX."],
	"4": ["X..X", "X..X", "XXXX", "...X", "...X"], "5": ["XXXX", "X...", "XXX.", "...X", "XXX."],
	"6": [".XXX", "X...", "XXX.", "X..X", ".XX."], "7": ["XXXX", "...X", "..X.", ".X..", ".X.."],
	"8": [".XX.", "X..X", ".XX.", "X..X", ".XX."], "9": [".XX.", "X..X", ".XXX", "...X", "XXX."],
	"-": ["...", "...", "XXX", "...", "..."], ".": [".", ".", ".", ".", "X"], "!": ["X", "X", "X", ".", "X"],
	"'": ["X", "X", ".", ".", "."],
}

var _k: PropKit
var _kit := {}
var _liv := {}


func _init(kit: PropKit) -> void:
	_k = kit


## The material for a kit key. Vertex colour is the albedo (sRGB) on all of them.
static func make_material(key: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.6
	match key:
		"paint":
			m.roughness = 0.34
			m.metallic = 0.12
			m.clearcoat_enabled = true
			m.clearcoat = 0.8
			m.clearcoat_roughness = 0.06
		"glass":
			m.roughness = 0.05
			m.metallic = 0.55
			m.metallic_specular = 0.9
		"chrome":
			m.metallic = 1.0
			m.roughness = 0.1
		"matte":
			m.roughness = 0.62
		"lamp":
			m.emission_enabled = true
			m.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			m.emission = Color(1.0, 1.0, 1.0)
			m.emission_energy_multiplier = 1.0
			m.roughness = 0.2
	return m


# ---------------------------------------------------------------------------------------------
#  The shell
# ---------------------------------------------------------------------------------------------

func _top(z: float) -> float:
	for i in range(TOP.size() - 1):
		var a: Array = TOP[i]
		var b: Array = TOP[i + 1]
		if z <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), clampf((z - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
	return float((TOP[TOP.size() - 1] as Array)[1])


## The underside's height: flat, lifted in a round arch over each wheel.
func _bottom(z: float) -> float:
	var y := Y_BOT
	for az in [AXLE_F, AXLE_R]:
		var dz: float = absf(z - az)
		if dz < ARCH_R:
			y = maxf(y, WHEEL_R + sqrt(ARCH_R * ARCH_R - dz * dz))
	return y


## The cross-section's shape at z.
func _params(z: float) -> Dictionary:
	var yt := _top(z)
	var f := clampf((yt - 1.1) / 1.0, 0.0, 1.0)
	var rt := lerpf(0.15, 0.10, f)
	var crown := lerpf(0.05, 0.03, f)
	var yr := yt - crown
	var ye := yr - rt
	var yk := minf(BELT, ye - 0.02)
	var we := HW - TILT * maxf(ye - yk, 0.0)
	return {"y0": _bottom(z), "yt": yt, "rt": rt, "crown": crown, "yr": yr, "ye": ye, "yk": yk, "we": we, "xr": we - rt}


## Half of the section, from the bottom's centre up the +x side to the roof's centre (22 points).
func _half_ring(p: Dictionary) -> PackedVector2Array:
	var y0: float = p["y0"]
	var yk: float = p["yk"]
	var ye: float = p["ye"]
	var yr: float = p["yr"]
	var yt: float = p["yt"]
	var we: float = p["we"]
	var xr: float = p["xr"]
	var pts := PackedVector2Array()
	pts.append(Vector2(0.0, y0))
	pts.append(Vector2((HW - RB) * 0.5, y0))
	for i in range(5):
		var a := PI * 0.5 * float(i) / 4.0
		pts.append(Vector2(HW - RB + sin(a) * RB, y0 + RB - cos(a) * RB))
	var y_lo := y0 + RB
	pts.append(Vector2(HW, lerpf(y_lo, yk, 1.0 / 3.0)))
	pts.append(Vector2(HW, lerpf(y_lo, yk, 2.0 / 3.0)))
	pts.append(Vector2(HW, yk))
	pts.append(Vector2(lerpf(HW, we, 1.0 / 3.0), lerpf(yk, ye, 1.0 / 3.0)))
	pts.append(Vector2(lerpf(HW, we, 2.0 / 3.0), lerpf(yk, ye, 2.0 / 3.0)))
	pts.append(Vector2(we, ye))
	# Top corner: a quadratic curve from the side's top to the roof's edge, its control at the corner.
	for i in range(1, 5):
		var t := float(i) / 4.0
		var a0 := Vector2(we, ye)
		var c0 := Vector2(we, yr)
		var b0 := Vector2(xr, yr)
		pts.append(a0.lerp(c0, t).lerp(c0.lerp(b0, t), t))
	var crown: float = p["crown"]
	for i in range(1, 6):
		var x := xr * (1.0 - float(i) / 5.0)
		pts.append(Vector2(x, yt - crown * pow(x / maxf(xr, 0.001), 2.0)))
	return pts


const RING_HALF := 22
## The ring segment's paint region: 0 underbody, 1 lower body, 2 upper body, 3 roof.
const SEG_REGION := [0, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3]


func _seg_color(region: int, zmid: float) -> Color:
	if region == 0:
		return UNDER
	# Ahead of the windscreen the whole nose is body colour.
	if zmid < -1.9:
		return _liv["base"]
	match region:
		1:
			return _liv["base"]
		2:
			return _liv["upper"] if zmid > -1.3 or true else _liv["base"]
		_:
			return _liv["roof"] if zmid > -1.2 else _liv["upper"]


func _station_zs() -> Array:
	var zs: Array = [Z_NOSE, Z_NOSE + 0.012, Z_NOSE + 0.04, -2.55, -2.40, -0.70, -0.20, 0.30, 0.75, 1.95, 2.15, 2.35, 2.50, Z_TAIL - 0.04, Z_TAIL - 0.012, Z_TAIL]
	for kn in TOP:
		zs.append(float((kn as Array)[0]))
	for az in [AXLE_F, AXLE_R]:
		for dz in [-0.434, -0.40, -0.34, -0.26, -0.15, 0.0, 0.15, 0.26, 0.34, 0.40, 0.434]:
			zs.append(az + dz)
	zs.sort()
	var out: Array = []
	for z in zs:
		if out.is_empty() or float(z) - float(out[out.size() - 1]) > 0.011:
			out.append(float(z))
	return out


## How much the section shrinks toward its end, which rounds the nose and tail's edges.
func _cap_scale(z: float) -> float:
	var d := minf(z - Z_NOSE, Z_TAIL - z)
	var t := clampf(d / 0.045, 0.0, 1.0)
	return 0.91 + 0.09 * pow(1.0 - pow(1.0 - t, 4.0), 0.25)


func _build_shell() -> void:
	var zs := _station_zs()
	var grid: Array = []
	var centres: Array = []
	for z in zs:
		var p := _params(float(z))
		var half := _half_ring(p)
		var s := _cap_scale(float(z))
		var cy: float = (float(p["y0"]) + float(p["yt"])) * 0.5
		var ring: Array = []
		# +x half from P0 up to P21, then the -x half back down to P1.
		for i in range(half.size()):
			ring.append(Vector3(half[i].x * s, cy + (half[i].y - cy) * s, float(z)))
		for i in range(half.size() - 2, 0, -1):
			ring.append(Vector3(-half[i].x * s, cy + (half[i].y - cy) * s, float(z)))
		grid.append(ring)
		centres.append(cy)
	var nr: int = (grid[0] as Array).size()
	var normals: Array = []
	for i in range(grid.size()):
		var row: Array = []
		for j in range(nr):
			var p: Vector3 = grid[i][j]
			var t_ring: Vector3 = (grid[i][(j + 1) % nr] as Vector3) - (grid[i][(j - 1 + nr) % nr] as Vector3)
			var tz: Vector3 = (grid[mini(i + 1, grid.size() - 1)][j] as Vector3) - (grid[maxi(i - 1, 0)][j] as Vector3)
			var n: Vector3 = tz.cross(t_ring)
			if n.length_squared() < 1e-12:
				n = Vector3(p.x, p.y - float(centres[i]), 0.0)
			n = n.normalized()
			if n.dot(Vector3(p.x, p.y - float(centres[i]), 0.0)) < 0.0:
				n = -n
			row.append(n)
		normals.append(row)
	for i in range(grid.size() - 1):
		var zmid: float = (float(zs[i]) + float(zs[i + 1])) * 0.5
		for j in range(nr):
			var j2 := (j + 1) % nr
			var seg: int = j if j < RING_HALF - 1 else (nr - 1 - j)
			var col := _seg_color(SEG_REGION[seg], zmid)
			var key := "matte" if SEG_REGION[seg] == 0 else "paint"
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][j2]
			var c: Vector3 = grid[i + 1][j2]
			var d: Vector3 = grid[i + 1][j]
			var na: Vector3 = normals[i][j]
			var nb: Vector3 = normals[i][j2]
			var nc: Vector3 = normals[i + 1][j2]
			var nd: Vector3 = normals[i + 1][j]
			var out := (na + nb + nc + nd).normalized()
			_k.tri(_kit, key, a, b, c, na, nb, nc, col, out)
			_k.tri(_kit, key, a, c, d, na, nc, nd, col, out)
	# Flat faces close the nose and the tail.
	for end in [0, grid.size() - 1]:
		var zn: float = -1.0 if end == 0 else 1.0
		var nrm := Vector3(0, 0, zn)
		var c0 := Vector3(0.0, float(centres[end]), float(zs[end]))
		for j in range(nr):
			var a2: Vector3 = grid[end][j]
			var b2: Vector3 = grid[end][(j + 1) % nr]
			_k.tri(_kit, "paint", c0, a2, b2, nrm, nrm, nrm, _liv["base"], nrm)


# ---------------------------------------------------------------------------------------------
#  Wheels
# ---------------------------------------------------------------------------------------------

func _wheel(cz: float, side: float) -> void:
	var c := Vector3(side * WHEEL_X, WHEEL_R, cz)
	var out := Vector3(side, 0.0, 0.0)
	var ab := Basis(Vector3.BACK, -PI * 0.5 * side)
	_k.tyre(_kit, "matte", c, 0.205, WHEEL_R, 0.205, 18, TYRE, ab)
	# The dish, a dark alloy centre with a chrome lip, six chrome spokes, hub and lug nuts.
	_k.lathe(_kit, "matte", c + out * 0.066, [Vector2(0.20, 0.0), Vector2(0.17, -0.012), Vector2(0.06, -0.026), Vector2(0.0, -0.026)], 14, GUNMETAL, false, ab)
	_k.lathe(_kit, "chrome", c + out * 0.071, [Vector2(0.212, 0.0), Vector2(0.205, 0.014), Vector2(0.192, 0.014), Vector2(0.186, 0.0)], 18, CHROME, false, ab)
	for s in range(6):
		var ang := TAU * float(s) / 6.0 + 0.3
		var dir := Vector3(0.0, cos(ang), sin(ang))
		var p_in := c + dir * 0.05 + out * 0.058
		var p_out := c + dir * 0.185 + out * 0.054
		_k.beam(_kit, "chrome", p_in, p_out, 0.046, 0.012, CHROME, out)
	_k.lathe(_kit, "chrome", c + out * 0.052, [Vector2(0.065, 0.0), Vector2(0.055, 0.016), Vector2(0.0, 0.02)], 12, CHROME, false, ab)
	for s in range(5):
		var ang2 := TAU * float(s) / 5.0
		var p0 := c + Vector3(0.0, cos(ang2), sin(ang2)) * 0.095 + out * 0.05
		_k.tube(_kit, "chrome", p0, p0 + out * 0.02, 0.012, 0.012, 5, CHROME, false)


# ---------------------------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------------------------

## A box between two corners, and its mirror image across x = 0 (x0, x1 given for the +x side).
func _blk(key: String, lo: Vector3, hi: Vector3, col: Color) -> void:
	_k.block(_kit, key, lo, hi, col)


func _blk_m(key: String, lo: Vector3, hi: Vector3, col: Color) -> void:
	_k.block(_kit, key, lo, hi, col)
	_k.block(_kit, key, Vector3(-lo.x, lo.y, lo.z), Vector3(-hi.x, hi.y, hi.z), col)


## A vertical prism on a plan outline (x, z): moulded plastic with smooth sides.
func _prism(key: String, outline: PackedVector2Array, y0: float, y1: float, col: Color, smooth := true) -> void:
	var n := outline.size()
	var ccw := PropKit._signed_area(outline) > 0.0
	var nrm := PackedVector3Array()
	for i in range(n):
		var p := outline[(i - 1 + n) % n]
		var q := outline[(i + 1) % n]
		var e := q - p
		var o := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
		o = o.normalized()
		nrm.append(Vector3(o.x, 0.0, o.y))
	for i in range(n):
		var j := (i + 1) % n
		var a := outline[i]
		var b := outline[j]
		var fo := Vector3(b.y - a.y, 0.0, a.x - b.x) if ccw else Vector3(a.y - b.y, 0.0, b.x - a.x)
		fo = fo.normalized()
		var na: Vector3 = nrm[i] if smooth else fo
		var nb: Vector3 = nrm[j] if smooth else fo
		_k.tri(_kit, key, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), na, nb, nb, col, fo)
		_k.tri(_kit, key, Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), na, nb, na, col, fo)
	var tris := Geometry2D.triangulate_polygon(outline)
	for i in range(0, tris.size(), 3):
		var a2 := outline[tris[i]]
		var b2 := outline[tris[i + 1]]
		var c2 := outline[tris[i + 2]]
		_k.tri(_kit, key, Vector3(a2.x, y1, a2.y), Vector3(b2.x, y1, b2.y), Vector3(c2.x, y1, c2.y), Vector3.UP, Vector3.UP, Vector3.UP, col, Vector3.UP)
		_k.tri(_kit, key, Vector3(a2.x, y0, a2.y), Vector3(b2.x, y0, b2.y), Vector3(c2.x, y0, c2.y), Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, col, Vector3.DOWN)


## A rounded rectangle in plan (x0..x1, z0..z1), corner radius r.
static func _rrect(x0: float, x1: float, z0: float, z1: float, r: float, segs := 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [[x1 - r, z1 - r, 0.0], [x0 + r, z1 - r, 0.25], [x0 + r, z0 + r, 0.5], [x1 - r, z0 + r, 0.75]]
	for c in corners:
		for i in range(segs + 1):
			var a: float = (float(c[2]) + 0.25 * float(i) / float(segs)) * TAU
			pts.append(Vector2(float(c[0]) + cos(a) * r, float(c[1]) + sin(a) * r))
	return pts


## A grid on a parametric surface f(u, v) -> Vector3 (u, v in 0..1), faces toward `out`; col_fn(u, v)
## colours it. Normals come from the surface itself.
func _grid(key: String, f: Callable, nu: int, nv: int, col_fn: Callable, out: Vector3) -> void:
	var pts: Array = []
	var nrm: Array = []
	var cols: Array = []
	for iv in range(nv + 1):
		for iu in range(nu + 1):
			var u := float(iu) / float(nu)
			var v := float(iv) / float(nv)
			var du: Vector3 = f.call(minf(u + 0.01, 1.0), v) - f.call(maxf(u - 0.01, 0.0), v)
			var dv: Vector3 = f.call(u, minf(v + 0.01, 1.0)) - f.call(u, maxf(v - 0.01, 0.0))
			var n := du.cross(dv).normalized()
			if n.dot(out) < 0.0:
				n = -n
			pts.append(f.call(u, v))
			nrm.append(n)
			cols.append(col_fn.call(u, v))
	for iv in range(nv):
		for iu in range(nu):
			var i0 := iv * (nu + 1) + iu
			var i1 := i0 + 1
			var i2 := i1 + nu + 1
			var i3 := i0 + nu + 1
			_k.tri(_kit, key, pts[i0], pts[i1], pts[i2], nrm[i0], nrm[i1], nrm[i2], cols[i0], out)
			_k.tri(_kit, key, pts[i0], pts[i2], pts[i3], nrm[i0], nrm[i2], nrm[i3], cols[i0], out)


## The roof line's surface point at (x, z) (the crowned top, used for the windscreen and what sits on it).
func _roof_pt(x: float, z: float) -> Vector3:
	var p := _params(z)
	return Vector3(x, float(p["yt"]) - float(p["crown"]) * pow(x / maxf(float(p["xr"]), 0.001), 2.0), z)


func _windscreen_normal() -> Vector3:
	return Vector3(0.0, 1.0, -1.42).normalized()


# ---------------------------------------------------------------------------------------------
#  The body's side as a canvas
# ---------------------------------------------------------------------------------------------

## The side wall's half-width at (z, y): vertical below the belt line, tilted in above it.
func _side_x(z: float, y: float) -> float:
	var p := _params(z)
	return HW - TILT * maxf(y - float(p["yk"]), 0.0)


func _side_normal(side: float, y: float) -> Vector3:
	return Vector3(side, TILT if y > BELT else 0.0, 0.0).normalized()


## The wheel arches as holes in (z, y) space, a little bigger than the opening.
func _arch_hole(az: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := ARCH_R + 0.04
	pts.append(Vector2(az - r, -0.1))
	for i in range(19):
		var a := PI - PI * float(i) / 18.0
		var y := WHEEL_R + sin(a) * r
		if y > 0.2:
			pts.append(Vector2(az + cos(a) * r, y))
	pts.append(Vector2(az + r, -0.1))
	return pts


## The paintable part of the lower body, in (z, y): clear of the nose's curve and the belt line.
const PANEL := [Vector2(-2.62, 0.32), Vector2(2.64, 0.32), Vector2(2.64, 1.085), Vector2(-1.80, 1.085), Vector2(-1.90, 0.94), Vector2(-2.62, 0.88)]


## Clips `poly` (z, y) to pieces of the lower panel, minus the arches; `panel` false skips that (windows, trim).
func _side_pieces(poly: PackedVector2Array, panel: bool, arches: bool) -> Array:
	var pieces: Array = [poly]
	if panel:
		var next: Array = []
		for pc in pieces:
			for r in Geometry2D.intersect_polygons(pc, PackedVector2Array(PANEL)):
				if not Geometry2D.is_polygon_clockwise(r):
					next.append(r)
		pieces = next
	if arches:
		for az in [AXLE_F, AXLE_R]:
			var next2: Array = []
			for pc in pieces:
				for r in Geometry2D.clip_polygons(pc, _arch_hole(az)):
					if not Geometry2D.is_polygon_clockwise(r):
						next2.append(r)
			pieces = next2
	return pieces


## A flat paint or vinyl shape on one side (`side` -1 or +1), `off` metres proud, in (z, y) points.
## Split at the belt line so every piece lies in one plane of the side.
func _side_poly(side: float, poly: PackedVector2Array, col: Color, off: float, key := "paint", panel := true, arches := true) -> void:
	for pc in _side_pieces(poly, panel, arches):
		var halves: Array = []
		for box in [PackedVector2Array([Vector2(-4, -1), Vector2(4, -1), Vector2(4, BELT), Vector2(-4, BELT)]),
				PackedVector2Array([Vector2(-4, BELT), Vector2(4, BELT), Vector2(4, 4), Vector2(-4, 4)])]:
			for r in Geometry2D.intersect_polygons(pc, box):
				if not Geometry2D.is_polygon_clockwise(r):
					halves.append(r)
		for h in halves:
			var tris := Geometry2D.triangulate_polygon(h)
			for i in range(0, tris.size(), 3):
				var v: Array = []
				var nrm: Array = []
				for k in range(3):
					var q: Vector2 = h[tris[i + k]]
					var n := _side_normal(side, q.y)
					v.append(Vector3(side * _side_x(q.x, q.y) + off * n.x, q.y + off * n.y, q.x))
					nrm.append(n)
				_k.tri(_kit, key, v[0], v[1], v[2], nrm[0], nrm[1], nrm[2], col, nrm[0])


## A ribbon on the side: centre line `y_c(s)` and half width `w(s)` for s in 0..1 over z0..z1.
func _side_ribbon(side: float, z0: float, z1: float, y_c: Callable, w: Callable, col: Color, off: float, key := "paint", steps := 28, panel := true) -> void:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in range(steps + 1):
		var s := float(i) / float(steps)
		var z := lerpf(z0, z1, s)
		var yc: float = y_c.call(s)
		var hw: float = w.call(s)
		top.append(Vector2(z, yc + hw))
		bot.append(Vector2(z, yc - hw))
	bot.reverse()
	top.append_array(bot)
	_side_poly(side, top, col, off, key, panel)


## A rectangle on the side in (z, y).
func _side_rect(side: float, z0: float, y0: float, z1: float, y1: float, col: Color, off: float, key := "paint", panel := false, arches := false) -> void:
	_side_poly(side, PackedVector2Array([Vector2(z0, y0), Vector2(z1, y0), Vector2(z1, y1), Vector2(z0, y1)]), col, off, key, panel, arches)


## A window on the side: the four corners (z, y) in order bottom-front, bottom-back, top-back, top-front.
func _side_window(side: float, c: Array) -> void:
	var cen := Vector2.ZERO
	for p in c:
		cen += p as Vector2
	cen /= 4.0
	for layer in range(2):
		var grow := 0.032 if layer == 0 else 0.0
		var pts: Array = []
		for p in c:
			var d: Vector2 = (p as Vector2) - cen
			pts.append((p as Vector2) + d.normalized() * grow)
		var off := 0.007 if layer == 0 else 0.013
		var n := _side_normal(side, 1.5)
		var v: Array = []
		for p in pts:
			var q: Vector2 = p
			v.append(Vector3(side * _side_x(q.x, q.y) + off * n.x, q.y + off * n.y, q.x))
		_k.quad(_kit, "matte" if layer == 0 else "glass", v, n, RUBBER if layer == 0 else Color(0.03, 0.045, 0.06))


## A thin dark line on the side (a door's shut line), vertical or along z.
func _seam(side: float, z0: float, y0: float, z1: float, y1: float, w := 0.008) -> void:
	var horizontal := absf(z1 - z0) > absf(y1 - y0)
	if horizontal:
		_side_rect(side, z0, y0 - w * 0.5, z1, y0 + w * 0.5, UNDER, 0.004, "matte")
	else:
		_side_rect(side, z0 - w * 0.5, y0, z0 + w * 0.5, y1, UNDER, 0.004, "matte")


# ---------------------------------------------------------------------------------------------
#  Lettering
# ---------------------------------------------------------------------------------------------

## Width in cells of `text`.
static func text_cells(text: String) -> int:
	var w := -1
	for ch in text:
		w += (GLYPHS[ch][0] as String).length() + 1
	return w


## `text` in GLYPHS, `cell` metres a cell, centred on `centre` and reading along `right`, its up along `up`;
## it faces right x up. `slant` leans the letters forward (italic).
func _text(key: String, centre: Vector3, right: Vector3, up: Vector3, cell: float, text: String, col: Color, slant := 0.0) -> void:
	var face := right.cross(up).normalized()
	var origin := centre - right * (float(text_cells(text)) * cell * 0.5) - up * (2.5 * cell)
	var x := 0
	for ch in text:
		var rows: Array = GLYPHS[ch]
		for r in range(5):
			var row: String = rows[r]
			var i := 0
			while i < row.length():
				if row[i] != "X":
					i += 1
					continue
				var j := i
				while j < row.length() and row[j] == "X":
					j += 1
				var lo := origin + right * (float(x + i) * cell) + up * (float(4 - r) * cell)
				var span := right * (float(j - i) * cell)
				var s0 := right * (slant * float(4 - r) * cell)
				var s1 := right * (slant * float(5 - r) * cell)
				_k.quad(_kit, key, [lo + s0, lo + span + s0, lo + span + up * cell + s1, lo + up * cell + s1], face, col)
				i = j
		x += (rows[0] as String).length() + 1


## Lettering on a side, with a drop shadow, reading toward the nose on +x and toward the tail on -x.
func _side_text(side: float, zc: float, yc: float, cell: float, text: String, col: Color, shadow: Color, slant := 0.15) -> void:
	var right := Vector3(0, 0, -side)
	var n := Vector3(side, 0, 0)
	var base := Vector3(side * HW, yc, zc)
	if shadow.a > 0.0:
		_text("paint", base + n * L4 - right * cell * 0.30 - Vector3(0, cell * 0.30, 0), right, Vector3.UP, cell, text, shadow, slant)
	_text("paint", base + n * L5, right, Vector3.UP, cell, text, col, slant)


# ---------------------------------------------------------------------------------------------
#  Details
# ---------------------------------------------------------------------------------------------

func _build_liners() -> void:
	# Dark wheel wells, so the arches don't look through the van.
	for az in [AXLE_F, AXLE_R]:
		_blk("matte", Vector3(-0.62, 0.22, az - ARCH_R - 0.012), Vector3(0.62, 0.88, az + ARCH_R + 0.012), UNDER)
		for side in [-1.0, 1.0]:
			# The tub's back wall, behind the tyre, with the suspension and brake in it.
			_blk("matte", Vector3(side * 0.60, 0.22, az - 0.30), Vector3(side * 0.69, 0.60, az + 0.30), GUNMETAL)
			_k.tube(_kit, "chrome", Vector3(side * 0.66, WHEEL_R, az), Vector3(side * 0.70, WHEEL_R, az), 0.075, 0.075, 8, Color(0.55, 0.57, 0.6))


func _build_glass() -> void:
	var glass := Color(0.03, 0.045, 0.06)
	# Windscreen: rubber, then the glass, on the roof line's slope; a dark sun strip across its top.
	var wn := _windscreen_normal()
	var ws_surface := func(x0: float, x1: float, z0: float, z1: float, lift: float) -> Callable:
		return func(u: float, v: float) -> Vector3:
			return _roof_pt(lerpf(x0, x1, u), lerpf(z0, z1, v)) + wn * lift
	_grid("matte", ws_surface.call(-0.78, 0.78, -1.935, -1.265, 0.007), 6, 1, func(_u: float, _v: float) -> Color: return RUBBER, wn)
	_grid("glass", ws_surface.call(-0.745, 0.745, -1.915, -1.285, 0.013), 6, 1, func(_u: float, v: float) -> Color: return glass.lerp(Color(0.10, 0.15, 0.22), v * 0.5), wn)
	_grid("matte", ws_surface.call(-0.745, 0.745, -1.375, -1.285, 0.018), 6, 1, func(_u: float, _v: float) -> Color: return BLACK, wn)
	# Side glass.
	var zs := [[-1.50, -0.84, -1.22], [-0.74, 0.28, 0.0], [0.40, 1.40, 0.0], [1.52, 2.28, 0.0]]
	for side in [-1.0, 1.0]:
		# Front door: the window's leading edge follows the A-pillar.
		_side_window(side, [Vector2(-1.50, 1.28), Vector2(-0.84, 1.28), Vector2(-0.84, 1.96), Vector2(-1.22, 1.96)])
		if side > 0.0:
			_side_window(side, [Vector2(-0.74, 1.28), Vector2(0.28, 1.28), Vector2(0.28, 1.96), Vector2(-0.74, 1.96)])
		else:
			# The sliding door's window.
			_side_window(side, [Vector2(-0.62, 1.28), Vector2(0.56, 1.28), Vector2(0.56, 1.96), Vector2(-0.62, 1.96)])
		var z_a := 0.40 if side > 0.0 else 0.80
		_side_window(side, [Vector2(z_a, 1.28), Vector2(1.40, 1.28), Vector2(1.40, 1.96), Vector2(z_a, 1.96)])
		_side_window(side, [Vector2(1.52, 1.28), Vector2(2.28, 1.28), Vector2(2.28, 1.96), Vector2(1.52, 1.96)])
	zs.clear()
	# Rear window.
	var rn := Vector3(0, 0, 1)
	_k.quad(_kit, "matte", [Vector3(-0.665, 1.235, Z_TAIL + 0.006), Vector3(0.665, 1.235, Z_TAIL + 0.006), Vector3(0.665, 1.955, Z_TAIL + 0.006), Vector3(-0.665, 1.955, Z_TAIL + 0.006)], rn, RUBBER)
	_k.quad(_kit, "glass", [Vector3(-0.63, 1.27, Z_TAIL + 0.012), Vector3(0.63, 1.27, Z_TAIL + 0.012), Vector3(0.63, 1.92, Z_TAIL + 0.012), Vector3(-0.63, 1.92, Z_TAIL + 0.012)], rn, glass)


func _build_doors() -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * (HW + 0.022)
		# Front door: hinge line at the arch, shut line behind it; handle at the belt.
		_seam(side, -0.80, 0.42, -0.80, 1.26)
		_seam(side, -1.56, 0.95, -1.56, 1.26)
		_seam(side, -1.56, 1.26, -0.80, 1.26)
		_k.beam(_kit, "chrome", Vector3(x, 1.10, -0.96), Vector3(x, 1.10, -0.82), 0.026, 0.02, CHROME, Vector3.UP)
		# Mirror: an arm and a black housing with its glass facing the driver.
		var mx: float = side * 1.045
		_k.beam(_kit, "matte", Vector3(side * 0.92, 1.30, -1.42), Vector3(side * 1.03, 1.36, -1.40), 0.035, 0.03, BLACK, Vector3.UP)
		_prism("matte", _rrect(minf(side * 1.00, side * 1.09), maxf(side * 1.00, side * 1.09), -1.50, -1.34, 0.04, 3), 1.28, 1.48, BLACK)
		_k.quad(_kit, "glass", [Vector3(mx - 0.036, 1.30, -1.338), Vector3(mx + 0.036, 1.30, -1.338), Vector3(mx + 0.036, 1.46, -1.338), Vector3(mx - 0.036, 1.46, -1.338)], Vector3(0, 0, 1), Color(0.18, 0.22, 0.27))
		# Side repeater on the wing.
		_k.block(_kit, "lamp", Vector3(side * (HW - 0.004), 0.70, -2.18), Vector3(side * (HW + 0.02), 0.76, -2.06), Color(1.0, 0.55, 0.05))
	# The sliding door, on the kerb side (-x): its outline, handle and the rails it runs on.
	var sx := -(HW + 0.022)
	_seam(-1.0, -0.68, 0.42, -0.68, 1.26)
	_seam(-1.0, 0.66, 0.42, 0.66, 1.26)
	_seam(-1.0, -0.68, 1.26, 0.66, 1.26)
	_seam(-1.0, -0.68, 0.42, 0.66, 0.42)
	_k.beam(_kit, "chrome", Vector3(sx, 1.10, -0.56), Vector3(sx, 1.10, -0.40), 0.026, 0.02, CHROME, Vector3.UP)
	_k.beam(_kit, "matte", Vector3(sx, 0.90, 0.66), Vector3(sx, 0.90, 2.05), 0.05, 0.02, BLACK, Vector3.UP)
	_k.beam(_kit, "matte", Vector3(sx, 1.19, 0.66), Vector3(sx, 1.19, 2.30), 0.05, 0.02, BLACK, Vector3.UP)
	# The fuel flap on the driver's side.
	_seam(1.0, 1.84, 0.90, 1.84, 1.06)
	_seam(1.0, 2.02, 0.90, 2.02, 1.06)
	_seam(1.0, 1.84, 0.90, 2.02, 0.90)
	_seam(1.0, 1.84, 1.06, 2.02, 1.06)


func _build_front() -> void:
	# Bumper: a moulded wrap-around in black, with a chrome capping strip and an intake.
	_prism("matte", _rrect(-0.962, 0.962, -2.795, -2.50, 0.20, 5), 0.30, 0.60, BLACK)
	_k.beam(_kit, "chrome", Vector3(-0.78, 0.606, -2.79), Vector3(0.78, 0.606, -2.79), 0.04, 0.022, CHROME, Vector3.BACK)
	_blk("matte", Vector3(-0.34, 0.50, -2.806), Vector3(0.34, 0.575, -2.790), UNDER)
	for s in range(-3, 4):
		_blk("chrome", Vector3(float(s) * 0.095 - 0.006, 0.505, -2.812), Vector3(float(s) * 0.095 + 0.006, 0.57, -2.804), CHROME)
	# Plate.
	_k.quad(_kit, "matte", [Vector3(0.28, 0.345, -2.801), Vector3(-0.28, 0.345, -2.801), Vector3(-0.28, 0.465, -2.801), Vector3(0.28, 0.465, -2.801)], Vector3(0, 0, -1), Color(0.90, 0.90, 0.88))
	_text("matte", Vector3(0, 0.405, -2.808), Vector3(-1, 0, 0), Vector3.UP, 0.0135, _liv["plate"], Color(0.05, 0.05, 0.06))
	# Fog lamps.
	var fb := Basis(Vector3.RIGHT, -PI * 0.5)
	for side in [-1.0, 1.0]:
		_k.lathe(_kit, "chrome", Vector3(side * 0.66, 0.44, -2.79), [Vector2(0.062, 0.0), Vector2(0.056, 0.012), Vector2(0.0, 0.014)], 12, CHROME, false, fb)
		_k.lathe(_kit, "lamp", Vector3(side * 0.66, 0.44, -2.805), [Vector2(0.048, 0.0), Vector2(0.0, 0.01)], 12, Color(1.0, 0.95, 0.80), false, fb)
	# The face: grille with chrome bars and a badge, headlamps with a projector, an indicator and a day strip.
	_blk("matte", Vector3(-0.40, 0.63, -2.722), Vector3(0.40, 0.87, -2.700), BLACK)
	for yy in [0.675, 0.735, 0.795]:
		_blk("chrome", Vector3(-0.375, yy - 0.012, -2.732), Vector3(0.375, yy + 0.012, -2.722), CHROME)
	_k.lathe(_kit, "chrome", Vector3(0.0, 0.75, -2.735), [Vector2(0.062, 0.0), Vector2(0.056, 0.012), Vector2(0.0, 0.016)], 16, CHROME, false, fb)
	_k.lathe(_kit, "matte", Vector3(0.0, 0.75, -2.745), [Vector2(0.040, 0.0), Vector2(0.0, 0.004)], 16, Color(0.7, 0.05, 0.05), false, fb)
	for side in [-1.0, 1.0]:
		var xa := minf(side * 0.46, side * 0.83)
		var xb := maxf(side * 0.46, side * 0.83)
		_blk("matte", Vector3(xa - 0.012, 0.655, -2.726), Vector3(xb + 0.012, 0.935, -2.700), BLACK)
		_blk("lamp", Vector3(minf(side * 0.48, side * 0.72), 0.675, -2.738), Vector3(maxf(side * 0.48, side * 0.72), 0.915, -2.724), Color(0.92, 0.95, 1.0))
		_k.lathe(_kit, "chrome", Vector3(side * 0.60, 0.795, -2.742), [Vector2(0.085, 0.0), Vector2(0.078, 0.012), Vector2(0.060, 0.012)], 18, CHROME, false, fb)
		_k.lathe(_kit, "lamp", Vector3(side * 0.60, 0.795, -2.75), [Vector2(0.056, 0.0), Vector2(0.0, 0.012)], 14, Color(1.0, 1.0, 0.95), false, fb)
		_blk("lamp", Vector3(minf(side * 0.725, side * 0.82), 0.675, -2.738), Vector3(maxf(side * 0.725, side * 0.82), 0.915, -2.724), Color(1.0, 0.55, 0.05))
		_blk("lamp", Vector3(minf(side * 0.48, side * 0.82), 0.645, -2.734), Vector3(maxf(side * 0.48, side * 0.82), 0.657, -2.728), Color(1.0, 1.0, 0.95))
	# Wipers on the glass.
	var wn := _windscreen_normal()
	for pair in [[-0.70, -0.05], [-0.05, 0.62]]:
		var a := _roof_pt(float(pair[0]), -1.90) + wn * 0.026
		var b := _roof_pt(float(pair[1]), -1.58) + wn * 0.026
		_k.beam(_kit, "matte", a, b, 0.022, 0.012, BLACK, wn)


func _build_rear() -> void:
	# Bumper, with its step, plate and tail lamp clusters.
	_prism("matte", _rrect(-0.962, 0.962, 2.50, 2.795, 0.20, 5), 0.30, 0.60, BLACK)
	_k.beam(_kit, "chrome", Vector3(-0.80, 0.606, 2.79), Vector3(0.80, 0.606, 2.79), 0.04, 0.022, CHROME, Vector3.BACK)
	_blk("matte", Vector3(-0.30, 0.60, 2.55), Vector3(0.30, 0.625, 2.775), Color(0.12, 0.12, 0.13))
	var rn := Vector3(0, 0, 1)
	_k.quad(_kit, "matte", [Vector3(-0.27, 0.70, 2.716), Vector3(0.27, 0.70, 2.716), Vector3(0.27, 0.83, 2.716), Vector3(-0.27, 0.83, 2.716)], rn, Color(0.98, 0.80, 0.08))
	_text("matte", Vector3(0, 0.765, 2.722), Vector3(1, 0, 0), Vector3.UP, 0.0145, _liv["plate"], Color(0.05, 0.05, 0.06))
	for side in [-1.0, 1.0]:
		var xa := minf(side * 0.60, side * 0.84)
		var xb := maxf(side * 0.60, side * 0.84)
		_blk("matte", Vector3(xa - 0.012, 0.69, 2.700), Vector3(xb + 0.012, 1.40, 2.726), BLACK)
		var xi := minf(side * 0.62, side * 0.82)
		var xo := maxf(side * 0.62, side * 0.82)
		_blk("lamp", Vector3(xi, 1.08, 2.724), Vector3(xo, 1.37, 2.736), Color(0.85, 0.04, 0.03))
		_blk("lamp", Vector3(xi, 0.90, 2.724), Vector3(xo, 1.06, 2.736), Color(1.0, 0.55, 0.05))
		_blk("lamp", Vector3(xi, 0.72, 2.724), Vector3(xo, 0.88, 2.736), Color(0.90, 0.90, 0.85))
	# Handle, wiper, and a spoiler with the third brake light.
	_k.beam(_kit, "chrome", Vector3(-0.12, 0.865, 2.73), Vector3(0.12, 0.865, 2.73), 0.022, 0.02, CHROME, Vector3.UP)
	_k.beam(_kit, "matte", Vector3(0.0, 1.30, 2.73), Vector3(0.40, 1.74, 2.73), 0.02, 0.012, BLACK, Vector3.BACK)
	_blk("matte", Vector3(-0.78, 2.285, 2.40), Vector3(0.78, 2.32, 2.64), BLACK)
	_blk("matte", Vector3(-0.74, 2.24, 2.44), Vector3(-0.70, 2.285, 2.60), BLACK)
	_blk("matte", Vector3(0.70, 2.24, 2.44), Vector3(0.74, 2.285, 2.60), BLACK)
	_blk("lamp", Vector3(-0.42, 2.292, 2.636), Vector3(0.42, 2.318, 2.646), Color(0.9, 0.04, 0.03))


func _build_trim() -> void:
	# Side skirts, with underglow along their lower edge, and the neon under both bumpers.
	var neon: Color = _liv["neon"]
	for side in [-1.0, 1.0]:
		for span in [[AXLE_F + ARCH_R + 0.01, AXLE_R - ARCH_R - 0.01], [AXLE_R + ARCH_R + 0.01, 2.50]]:
			var xa := minf(side * (HW - 0.06), side * (HW + 0.03))
			var xb := maxf(side * (HW - 0.06), side * (HW + 0.03))
			_blk("matte", Vector3(xa, 0.28, float(span[0])), Vector3(xb, 0.45, float(span[1])), BLACK)
			var xc := minf(side * (HW + 0.03), side * (HW + 0.036))
			var xd := maxf(side * (HW + 0.03), side * (HW + 0.036))
			_blk("lamp", Vector3(xc, 0.30, float(span[0])), Vector3(xd, 0.325, float(span[1])), neon)
	_blk("lamp", Vector3(-0.80, 0.30, -2.80), Vector3(0.80, 0.318, -2.795), neon)
	_blk("lamp", Vector3(-0.80, 0.30, 2.795), Vector3(0.80, 0.318, 2.80), neon)
	# A row of amber marker lamps along the roof's front edge.
	for i in range(7):
		var x := -0.60 + 0.20 * float(i)
		var p := _roof_pt(x, -1.19)
		_k.block(_kit, "lamp", p + Vector3(-0.035, -0.008, -0.012), p + Vector3(0.035, 0.03, 0.02), Color(1.0, 0.6, 0.08))
	# A roof vent.
	_blk("matte", Vector3(-0.30, 2.275, 0.20), Vector3(0.30, 2.31, 0.78), Color(0.10, 0.11, 0.12))


# ---------------------------------------------------------------------------------------------
#  Paint: the livery's artwork, name and the Sacco band
# ---------------------------------------------------------------------------------------------

## How far each layer of paint stands off the body (life size): the band, the artwork, two more
## layers, the lettering's shadow and the lettering. Shapes that overlap must be on different layers,
## and different colours must never share one where they touch: equal depths z-fight (the pink and
## cyan swooshes did). The lettering goes above all the artwork.
const L0 := 0.008
const L1 := 0.014
const L2 := 0.020
const L3 := 0.026
const L4 := 0.032
const L5 := 0.038

## A lightning bolt in unit coordinates (u across, v up).
const BOLT := [Vector2(0.55, 1.0), Vector2(0.05, 0.42), Vector2(0.40, 0.42), Vector2(0.18, 0.0), Vector2(0.95, 0.60), Vector2(0.55, 0.60), Vector2(0.85, 1.0)]


static func _luma(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## A shape's outline scaled into (z, y): unit points times (sz, sy) from (z0, y0); `flip` mirrors it along z.
static func _unit_poly(unit: Array, z0: float, y0: float, sz: float, sy: float, flip := 1.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in unit:
		var q: Vector2 = p
		out.append(Vector2(z0 + flip * q.x * sz, y0 + q.y * sy))
	return out


static func _circle_poly(c: Vector2, r: float, n := 22) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


static func _star_poly(c: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(10):
		var a := rot + PI * 0.5 + TAU * float(i) / 10.0
		var rr := r if i % 2 == 0 else r * 0.42
		out.append(c + Vector2(cos(a), sin(a)) * rr)
	return out


## A flame tongue: base at (z0, y0) w wide, h tall, its tip swept back (+z) by `lean`, a curl in its tail.
static func _flame_poly(z0: float, y0: float, w: float, h: float, lean: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(11):
		var t := float(i) / 10.0
		var cz := z0 + w * 0.5 + lean * pow(t, 1.7) + 0.22 * w * sin(t * PI * 1.3)
		var hw := w * 0.5 * pow(1.0 - t, 0.72)
		left.append(Vector2(cz - hw, y0 + h * t))
		right.append(Vector2(cz + hw, y0 + h * t))
	right.reverse()
	left.append_array(right)
	return left


func _side_text_fit(side: float, zc: float, yc: float, max_w: float, max_cell: float, text: String, col: Color, shadow: Color) -> void:
	var cell := minf(max_cell, max_w / float(text_cells(text)))
	_side_text(side, zc, yc, cell, text, col, shadow)


func _art_side(side: float) -> void:
	var a1: Color = _liv["a1"]
	var a2: Color = _liv["a2"]
	var a3: Color = _liv["a3"]
	var band: Color = _liv["band"]
	var nm: String = _liv["name"]
	# The Sacco band under the windows, with the operator's name on it.
	_side_rect(side, -4.0, 0.985, 4.0, 1.083, band, L0, "paint", true, true)
	var band_text := Color(0.05, 0.05, 0.06) if _luma(band) > 0.35 else Color(0.97, 0.97, 0.94)
	_side_text_fit(side, 1.42, 1.034, 0.95, 0.017, nm + " SACCO", band_text, Color(0, 0, 0, 0))
	match _liv["style"]:
		"flames":
			var k := 0
			var z0 := -1.30
			while z0 < 0.95:
				var h := 0.21 + 0.07 * sin(float(k) * 2.1)
				var w := 0.27 + 0.04 * cos(float(k) * 1.7)
				var lean := 0.30 + 0.10 * sin(float(k) * 1.3)
				_side_poly(side, _flame_poly(z0, 0.40, w, h, lean), a1, L1)
				_side_poly(side, _flame_poly(z0 + w * 0.12, 0.40, w * 0.72, h * 0.72, lean * 0.7), a2, L2)
				_side_poly(side, _flame_poly(z0 + w * 0.26, 0.40, w * 0.42, h * 0.42, lean * 0.4), a3, L3)
				z0 += 0.27
				k += 1
			for fz in [[-2.55, 0.34, 0.40, 0.30], [-2.30, 0.30, 0.34, 0.26], [1.92, 0.30, 0.46, 0.30], [2.18, 0.26, 0.40, 0.26], [2.40, 0.24, 0.30, 0.2]]:
				_side_poly(side, _flame_poly(float(fz[0]), 0.40, float(fz[1]), float(fz[2]), float(fz[3])), a1, L1)
				_side_poly(side, _flame_poly(float(fz[0]) + 0.04, 0.40, float(fz[1]) * 0.7, float(fz[2]) * 0.7, float(fz[3]) * 0.7), a2, L2)
		"swoosh":
			# Ribbons that dive under the name and rise at both ends.
			var dip := func(s: float, low: float) -> float: return low + 0.30 * pow(absf(2.0 * s - 1.0), 2.0)
			_side_ribbon(side, -2.55, 2.62, func(s: float) -> float: return dip.call(s, 0.49), func(s: float) -> float: return 0.01 + 0.05 * pow(sin(PI * s), 0.9), a2, L1)
			_side_ribbon(side, -2.55, 2.62, func(s: float) -> float: return dip.call(s, 0.58), func(s: float) -> float: return 0.01 + 0.055 * pow(sin(PI * s), 0.9), a1, L2)
			_side_ribbon(side, -2.55, 2.62, func(s: float) -> float: return dip.call(s, 0.58) + 0.085 * pow(sin(PI * s), 0.9) + 0.02, func(s: float) -> float: return 0.012 * pow(sin(PI * s), 0.6), a3, L3)
			for st in [[-2.05, 0.80, 0.07], [2.25, 0.72, 0.09], [2.45, 0.88, 0.05], [-2.35, 0.66, 0.05]]:
				_side_poly(side, _star_poly(Vector2(float(st[0]), float(st[1])), float(st[2])), a3, L4)
		"zebra":
			# Tapering black stripes rising from the sill, in the manner of a zebra's flank.
			var z0b := -1.30
			var kb := 0
			while z0b < 1.0:
				var pts := PackedVector2Array()
				var rpts := PackedVector2Array()
				var hh := 0.17 + 0.04 * sin(float(kb) * 1.9)
				for i in range(8):
					var t := float(i) / 7.0
					var cz := z0b + 0.14 * t + 0.035 * sin(t * TAU)
					var hw := 0.052 * (1.0 - t) + 0.008
					pts.append(Vector2(cz - hw, 0.42 + hh * t))
					rpts.append(Vector2(cz + hw, 0.42 + hh * t))
				rpts.reverse()
				pts.append_array(rpts)
				_side_poly(side, pts, a1, L1)
				z0b += 0.19
				kb += 1
			for zz in [-2.46, -2.30, 1.98, 2.14, 2.30, 2.46]:
				var pts2 := PackedVector2Array([Vector2(zz - 0.05, 0.40), Vector2(zz + 0.05, 0.40), Vector2(zz + 0.14, 0.78), Vector2(zz + 0.115, 0.78)])
				_side_poly(side, pts2, a1, L1)
			# A crown on the rear quarter, in the colour of a lion's mane.
			var cz2 := 2.26
			_side_poly(side, PackedVector2Array([Vector2(cz2 - 0.20, 0.50), Vector2(cz2 + 0.20, 0.50), Vector2(cz2 + 0.22, 0.88), Vector2(cz2 + 0.10, 0.70), Vector2(cz2, 0.92), Vector2(cz2 - 0.10, 0.70), Vector2(cz2 - 0.22, 0.88)]), a1, L1)
			_side_poly(side, PackedVector2Array([Vector2(cz2 - 0.16, 0.54), Vector2(cz2 + 0.16, 0.54), Vector2(cz2 + 0.17, 0.80), Vector2(cz2 + 0.08, 0.66), Vector2(cz2, 0.84), Vector2(cz2 - 0.08, 0.66), Vector2(cz2 - 0.17, 0.80)]), a3, L2)
		"flag":
			var cols := [a1, a3, a2]
			var widths := [0.075, 0.02, 0.075]
			var offs := [0.092, 0.0, -0.092]
			var lay := [L1, L2, L1]
			for i in range(3):
				var of: float = offs[i]
				_side_ribbon(side, -2.55, 2.62, func(s: float) -> float: return 0.56 + of + 0.05 * sin(s * TAU * 1.5), func(_s: float) -> float: return float(widths[i]), cols[i], lay[i])
		"stars":
			_side_ribbon(side, -2.55, 2.62, func(s: float) -> float: return lerpf(0.50, 0.60, s) + 0.03 * sin(s * TAU * 1.5), func(s: float) -> float: return 0.01 + 0.055 * pow(sin(PI * s), 0.7), a2, L0)
			_side_poly(side, _star_poly(Vector2(-2.12, 0.64), 0.20), a1, L1)
			_side_poly(side, _star_poly(Vector2(-2.12, 0.64), 0.12, PI / 5.0), a3, L2)
			_side_poly(side, _star_poly(Vector2(2.28, 0.68), 0.22), a1, L1)
			_side_poly(side, _star_poly(Vector2(2.28, 0.68), 0.13, PI / 5.0), a3, L2)
			for st in [[-1.2, 0.56, 0.05], [-0.7, 0.50, 0.07], [0.55, 0.52, 0.06], [0.88, 0.60, 0.05], [1.9, 0.52, 0.06], [-2.45, 0.78, 0.05], [2.55, 0.52, 0.05]]:
				_side_poly(side, _star_poly(Vector2(float(st[0]), float(st[1])), float(st[2])), a1 if int(float(st[0]) * 10.0) % 2 == 0 else a3, L2)
		"bolts":
			for b in [[-2.50, 0.42, 0.30, 0.45, 1.0], [1.95, 0.42, 0.34, 0.50, 1.0], [-1.25, 0.42, 0.22, 0.30, 1.0], [0.55, 0.42, 0.22, 0.30, 1.0]]:
				_side_poly(side, _unit_poly(BOLT, float(b[0]), float(b[1]), float(b[2]), float(b[3]), float(b[4])), a1, L1)
				_side_poly(side, _unit_poly(BOLT, float(b[0]) + 0.03 * float(b[2]) / 0.3, float(b[1]) + 0.03, float(b[2]) * 0.72, float(b[3]) * 0.86), a2, L2)
			_side_ribbon(side, -2.55, 2.62, func(s: float) -> float: return 0.47 + 0.02 * sin(s * TAU * 2.0), func(_s: float) -> float: return 0.018, a3, L0)
		"check":
			# A chequered band, two rows of squares, and a football on the rear quarter.
			var sq := 0.065
			var ci := 0
			var cz3 := -2.55
			while cz3 < 2.62:
				for row in range(2):
					var col: Color = a1 if (ci + row) % 2 == 0 else a2
					_side_rect(side, cz3, 0.44 + float(row) * sq, cz3 + sq, 0.44 + float(row + 1) * sq, col, L1, "paint", true, true)
				cz3 += sq
				ci += 1
			var bc := Vector2(2.28, 0.72)
			_side_poly(side, _circle_poly(bc, 0.25), a2, L1)
			_side_poly(side, _circle_poly(bc, 0.23), Color(0.96, 0.96, 0.94), L2)
			_side_poly(side, _circle_poly(bc, 0.075, 5), a2, L3)
			for i in range(5):
				var ang := TAU * float(i) / 5.0 + PI * 0.5
				var q := bc + Vector2(cos(ang), sin(ang)) * 0.20
				_side_poly(side, _circle_poly(q, 0.055, 5), a2, L3)
	# The name, big, sign-painted, on the door.
	var mid := -0.12 if side > 0.0 else -0.02
	_side_text_fit(side, mid, 0.800, 2.05, 0.060, nm, _liv["txt"], _liv["shd"])


## Racing stripes over the bonnet and the roof.
func _stripes(cols: Array, x0: float, w: float, gap: float) -> void:
	var up := Vector3.UP
	for i in range(cols.size()):
		for side in [-1.0, 1.0]:
			var xa: float = x0 + float(i) * (w + gap)
			for zr in [[-2.60, -1.97], [-0.98, 0.08], [0.90, 2.33]]:
				var f := func(u: float, v: float) -> Vector3:
					return _roof_pt(side * lerpf(xa, xa + w, u), lerpf(float(zr[0]), float(zr[1]), v)) + up * 0.009
				_grid("paint", f, 1, 8, func(_u: float, _v: float) -> Color: return cols[i], up)


func _build_art() -> void:
	for side in [-1.0, 1.0]:
		_art_side(side)
	match _liv["style"]:
		"swoosh":
			_stripes([_liv["a1"], _liv["a2"]], 0.10, 0.10, 0.03)
		"flag":
			_stripes([_liv["a1"], _liv["a3"], _liv["a2"]], 0.0, 0.07, 0.015)
		"check":
			_stripes([_liv["a1"], _liv["a2"]], 0.12, 0.09, 0.03)
		"bolts":
			_stripes([_liv["a1"]], 0.12, 0.12, 0.0)
		"flames":
			_stripes([_liv["a1"], _liv["a2"]], 0.12, 0.09, 0.03)
		"stars":
			_stripes([_liv["a1"]], 0.14, 0.10, 0.0)
		"zebra":
			_stripes([_liv["a1"]], 0.14, 0.10, 0.0)
	var nm: String = _liv["name"]
	# Windscreen banner: the name across the sun strip, and the route number on a card in the corner.
	var wn := _windscreen_normal()
	var wup := Vector3(0, 1.42, 1.0).normalized()
	var bcol: Color = _liv["txt"] if _luma(_liv["txt"]) > 0.45 else Color(0.97, 0.97, 0.94)
	var cell := minf(0.024, 1.30 / float(text_cells(nm)))
	_text("matte", _roof_pt(0.0, -1.33) + wn * 0.026, Vector3(-1, 0, 0), wup, cell, nm, bcol, 0.12)
	var card := _roof_pt(-0.52, -1.72) + wn * 0.026
	var cr := Vector3(-1, 0, 0)
	_k.quad(_kit, "matte", [card - cr * 0.10 - wup * 0.06, card + cr * 0.10 - wup * 0.06, card + cr * 0.10 + wup * 0.06, card - cr * 0.10 + wup * 0.06], wn, Color(0.95, 0.95, 0.92))
	_text("matte", card + wn * 0.004, cr, wup, minf(0.02, 0.17 / float(text_cells(_liv["route"]))), _liv["route"], Color(0.05, 0.05, 0.06))
	# Tailgate: the name across it, the slogan on the bumper.
	var rc := minf(0.05, 0.98 / float(text_cells(nm)))
	_text("paint", Vector3(0.0, 1.04, Z_TAIL + 0.028), Vector3(1, 0, 0), Vector3.UP, rc, nm, _liv["shd"], 0.12)
	_text("paint", Vector3(0.0 - rc * 0.4, 1.04 + rc * 0.4, Z_TAIL + 0.036), Vector3(1, 0, 0), Vector3.UP, rc, nm, _liv["txt"], 0.12)
	var slogan: String = _liv["slogan"]
	_text("matte", Vector3(0, 0.455, Z_TAIL + 0.104), Vector3(1, 0, 0), Vector3.UP, minf(0.02, 1.45 / float(text_cells(slogan))), slogan, Color(0.97, 0.97, 0.94))


# ---------------------------------------------------------------------------------------------
#  Build
# ---------------------------------------------------------------------------------------------

## The matatu in `livery` (an entry of LIVERIES), into one mesh with the PropKit's current frame.
func build(livery: Dictionary) -> ArrayMesh:
	_liv = livery
	_kit = {}
	_build_shell()
	_build_liners()
	for az in [AXLE_F, AXLE_R]:
		for side in [-1.0, 1.0]:
			_wheel(az, side)
	_build_glass()
	_build_doors()
	_build_front()
	_build_rear()
	_build_trim()
	_build_art()
	return _k.commit(_kit)
