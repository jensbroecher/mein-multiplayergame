extends "res://YardKit.gd"
## Estación Seca's small town across the road from the station, and the plaza in front of the station
## (regenerate_freight_line.gd: _build_town, _build_plaza). Built at life size through YardKit's kit (its materials: the
## hut shaders for plaster, tile, stone, timber, painted boards; CampKit's canvas, glass, lamps) and grown by the
## generator's PROP_SCALE, so they match the station and the cooperative.
##
## A building is built in its own frame: x along its front, the front wall in the plane z = 0 facing +z, the back at
## z = -d, the ground at y = 0. Every add-on stands at least 2.5cm proud of what it sits on (the mobile renderer can't
## part faces closer at racing distances), eaves and awnings have undersides (seen from a car below), and steps run
## down to the ground. Signs go into `labels` as YardKit's [text, position, outward normal, cap height, colour, board
## width], in the building's frame.

const OCHRE := Color(0.86, 0.70, 0.46)
const ROSE := Color(0.84, 0.58, 0.50)
const SKY := Color(0.62, 0.74, 0.80)
const SAGE_WALL := Color(0.70, 0.76, 0.62)
const WHITE_WALL := Color(0.93, 0.92, 0.88)
const BLUE_TRIM := Color(0.16, 0.32, 0.52)
const WOOD_DARK := Color(0.36, 0.24, 0.15)
const WOOD_MID := Color(0.52, 0.36, 0.22)

## The town's buildings, west to east: [kind, width, depth, wall colour, shutter colour]. Widths are life size.
const STREET := [
	["house_gable", 8.5, 7.0, OCHRE, SHUTTER],
	["cantina", 12.0, 9.0, ROSE, Color(0.45, 0.18, 0.12)],
	["tienda", 10.0, 8.0, SKY, BLUE_TRIM],
	["hostal", 11.0, 9.0, WHITE_WALL, BLUE_TRIM],
	["house_flat", 9.0, 7.5, SAGE_WALL, Color(0.55, 0.32, 0.16)],
	["farmacia", 8.0, 7.0, CREAM, Color(0.10, 0.42, 0.30)],
]
## Life-size metres between neighbours.
const GAP := 4.2


## The street's total length (life size): the buildings and the gaps between them.
static func street_length() -> float:
	var total := 0.0
	for b in STREET:
		total += float(b[1])
	return total + GAP * float(STREET.size() - 1)


static func building(pk: PropKit, kit: Dictionary, kind: String, w: float, d: float, col: Color, shutter: Color, labels: Array, rng: RandomNumberGenerator) -> void:
	match kind:
		"house_gable":
			_house_gable(pk, kit, w, d, col, shutter, rng)
		"cantina":
			_cantina(pk, kit, w, d, col, shutter, labels)
		"tienda":
			_tienda(pk, kit, w, d, col, shutter, labels)
		"hostal":
			_hostal(pk, kit, w, d, col, shutter, labels)
		"house_flat":
			_house_flat(pk, kit, w, d, col, shutter, rng)
		"farmacia":
			_farmacia(pk, kit, w, d, col, shutter, labels)
	# The backs (seen from the lap's far side): a back door with a lamp and windows, bins by the door.
	if kind != "house_gable":
		door(pk, kit, Vector3(-w * 0.25, 0.45, -d), Vector3(0, 0, -1), 1.0, 2.15, true, 0.0)
		_wall_lamp(pk, kit, Vector3(-w * 0.25 + 0.85, 2.55, -d), Vector3(0, 0, -1))
		window(pk, kit, Vector3(w * 0.2, 1.8, -d), Vector3(0, 0, -1), 1.0, 1.1, shutter)
		if kind == "hostal":
			for k in range(3):
				window(pk, kit, Vector3((float(k) - 1.0) * w * 0.3, 4.9, -d), Vector3(0, 0, -1), 0.9, 1.1, shutter)
		drum(pk, kit, Vector3(-w * 0.25 - 1.3, 0.0, -d - 0.6), Color(0.2, 0.32, 0.22), 0.95, 0.3)
		drum(pk, kit, Vector3(-w * 0.25 - 2.0, 0.0, -d - 0.6), Color(0.25, 0.27, 0.3), 0.95, 0.3)


# ======================================================================================
#  Shells and roofs
# ======================================================================================

## Four plastered walls from the ground to `h`, a stone plinth round the foot (4cm proud), a cornice band under the
## top (8cm proud) unless `cornice` is off.
static func _shell(pk: PropKit, kit: Dictionary, w: float, d: float, h: float, col: Color, cornice := true) -> void:
	var x0 := -w * 0.5
	var x1 := w * 0.5
	wall(pk, kit, "plaster", Vector3(x0, 0, 0), Vector3(x1, 0, 0), 0.0, h, col, Vector3(0, 0, 1))
	wall(pk, kit, "plaster", Vector3(x1, 0, -d), Vector3(x0, 0, -d), 0.0, h, col.darkened(0.04), Vector3(0, 0, -1))
	wall(pk, kit, "plaster", Vector3(x1, 0, 0), Vector3(x1, 0, -d), 0.0, h, col.darkened(0.02), Vector3(1, 0, 0))
	wall(pk, kit, "plaster", Vector3(x0, 0, -d), Vector3(x0, 0, 0), 0.0, h, col.darkened(0.02), Vector3(-1, 0, 0))
	blk(pk, kit, "stone", Vector3(x0 - 0.04, 0.0, -d - 0.04), Vector3(x1 + 0.04, 0.45, 0.04), STONE.darkened(0.05))
	if cornice:
		blk(pk, kit, "plaster", Vector3(x0 - 0.08, h - 0.3, -d - 0.08), Vector3(x1 + 0.08, h - 0.12, 0.08), col.lightened(0.15))


## A tiled gable roof, the ridge along x: eaves overhanging `oh` with fascia boards and soffits under them (seen from
## below), the gable ends plastered, a ridge cap.
static func _gable_roof(pk: PropKit, kit: Dictionary, w: float, d: float, h: float, col: Color, rise: float, oh := 0.5) -> void:
	var x0 := -w * 0.5 - oh
	var x1 := w * 0.5 + oh
	var zm := -d * 0.5
	var ridge: float = h + rise
	var pitch: float = rise / (d * 0.5)
	var ey: float = h - pitch * oh
	var tile_col := TERRACOTTA
	# The two slopes, and under each the soffit (a board face looking down, 4cm below).
	roof(pk, kit, "tile", Vector3(x0, ey, oh), Vector3(x1, ey, oh), Vector3(x1, ridge, zm), Vector3(x0, ridge, zm), tile_col, Vector3(0, 1.0, pitch).normalized())
	roof(pk, kit, "tile", Vector3(x1, ey, -d - oh), Vector3(x0, ey, -d - oh), Vector3(x0, ridge, zm), Vector3(x1, ridge, zm), tile_col, Vector3(0, 1.0, -pitch).normalized())
	# The slopes' undersides, boarded, 5cm under the tiles over their whole width: seen from below where the roof
	# runs out past the walls (the eaves, and over the gables, where the sky had shown through).
	roof(pk, kit, "lapboards", Vector3(x0, ey - 0.05, oh), Vector3(x1, ey - 0.05, oh), Vector3(x1, ridge - 0.05, zm), Vector3(x0, ridge - 0.05, zm), WOOD_MID, Vector3(0, -1.0, -pitch).normalized())
	roof(pk, kit, "lapboards", Vector3(x1, ey - 0.05, -d - oh), Vector3(x0, ey - 0.05, -d - oh), Vector3(x0, ridge - 0.05, zm), Vector3(x1, ridge - 0.05, zm), WOOD_MID, Vector3(0, -1.0, pitch).normalized())
	# Rafter tails under the eaves, a gutter along each and a downpipe at its ends.
	var rx := x0 + 0.3
	while rx < x1 - 0.2:
		for e in [[oh, 0.0], [-d - oh, -d]]:
			pk.beam(kit, "timber", Vector3(rx, ey - 0.12, float(e[0]) * 0.92 + float(e[1]) * 0.08), Vector3(rx, h - 0.12, float(e[1])), 0.08, 0.14, WOOD_DARK, Vector3(1, 0, 0))
		rx += 0.6
	for e2 in [[oh + 0.08, 1.0], [-d - oh - 0.08, -1.0]]:
		var gz: float = e2[0]
		pk.tube(kit, "steel", Vector3(x0 + 0.1, ey - 0.12, gz), Vector3(x1 - 0.1, ey - 0.12, gz), 0.07, 0.07, 8, Color(0.55, 0.57, 0.56))
		for sx in [-1.0, 1.0]:
			var px: float = sx * (w * 0.5 - 0.15)
			pk.tube(kit, "steel", Vector3(px, ey - 0.12, gz), Vector3(px, 0.15, gz - float(e2[1]) * (oh + 0.02)), 0.045, 0.045, 8, Color(0.55, 0.57, 0.56))
	# The gables, and the roof's edge over them (verge boards).
	for sx in [-1.0, 1.0]:
		var gx: float = sx * w * 0.5
		gable(pk, kit, "plaster", Vector3(gx, h, 0.0 if sx > 0.0 else -d), Vector3(gx, h, -d if sx > 0.0 else 0.0), Vector3(gx, ridge, zm), col.darkened(0.02), Vector3(sx, 0, 0))
		var vx: float = sx * (w * 0.5 + oh)
		pk.beam(kit, "timber", Vector3(vx, ey - 0.06, oh), Vector3(vx, ridge - 0.06, zm), 0.06, 0.22, WOOD_DARK, Vector3(1, 0, 0))
		pk.beam(kit, "timber", Vector3(vx, ey - 0.06, -d - oh), Vector3(vx, ridge - 0.06, zm), 0.06, 0.22, WOOD_DARK, Vector3(1, 0, 0))
	# Fascia boards along the eaves and the ridge cap.
	pk.beam(kit, "timber", Vector3(x0, ey - 0.1, oh + 0.03), Vector3(x1, ey - 0.1, oh + 0.03), 0.22, 0.05, WOOD_DARK, Vector3.UP)
	pk.beam(kit, "timber", Vector3(x0, ey - 0.1, -d - oh - 0.03), Vector3(x1, ey - 0.1, -d - oh - 0.03), 0.22, 0.05, WOOD_DARK, Vector3.UP)
	pk.beam(kit, "tile", Vector3(x0, ridge + 0.04, zm), Vector3(x1, ridge + 0.04, zm), 0.32, 0.16, tile_col.darkened(0.15), Vector3(0, 0, 1))


## A flat roof behind a parapet: the walls run on up to `h + par`, the parapet's inside faces and a coping on top,
## the roof's deck at `h`, drain spouts (canales) out through the front's parapet.
static func _flat_roof(pk: PropKit, kit: Dictionary, w: float, d: float, h: float, col: Color, par := 0.7) -> void:
	var x0 := -w * 0.5
	var x1 := w * 0.5
	var t := 0.25
	var top: float = h + par
	wall(pk, kit, "plaster", Vector3(x0, 0, 0), Vector3(x1, 0, 0), h, top, col, Vector3(0, 0, 1))
	wall(pk, kit, "plaster", Vector3(x1, 0, -d), Vector3(x0, 0, -d), h, top, col.darkened(0.04), Vector3(0, 0, -1))
	wall(pk, kit, "plaster", Vector3(x1, 0, 0), Vector3(x1, 0, -d), h, top, col.darkened(0.02), Vector3(1, 0, 0))
	wall(pk, kit, "plaster", Vector3(x0, 0, -d), Vector3(x0, 0, 0), h, top, col.darkened(0.02), Vector3(-1, 0, 0))
	# Inside faces of the parapet, the deck.
	wall(pk, kit, "plaster", Vector3(x1 - t, 0, -t), Vector3(x0 + t, 0, -t), h, top, col.darkened(0.1), Vector3(0, 0, -1))
	wall(pk, kit, "plaster", Vector3(x0 + t, 0, -d + t), Vector3(x1 - t, 0, -d + t), h, top, col.darkened(0.1), Vector3(0, 0, 1))
	wall(pk, kit, "plaster", Vector3(x1 - t, 0, -d + t), Vector3(x1 - t, 0, -t), h, top, col.darkened(0.12), Vector3(-1, 0, 0))
	wall(pk, kit, "plaster", Vector3(x0 + t, 0, -t), Vector3(x0 + t, 0, -d + t), h, top, col.darkened(0.12), Vector3(1, 0, 0))
	pk.quad(kit, "concrete", [Vector3(x0 + t, h, -t), Vector3(x1 - t, h, -t), Vector3(x1 - t, h, -d + t), Vector3(x0 + t, h, -d + t)], Vector3.UP, CONCRETE.darkened(0.1))
	# Coping along the top, 5cm proud each side.
	blk(pk, kit, "stone", Vector3(x0 - 0.05, top, -t - 0.02), Vector3(x1 + 0.05, top + 0.08, 0.05), STONE.lightened(0.1))
	blk(pk, kit, "stone", Vector3(x0 - 0.05, top, -d - 0.05), Vector3(x1 + 0.05, top + 0.08, -d + t + 0.02), STONE.lightened(0.1))
	blk(pk, kit, "stone", Vector3(x0 - 0.05, top, -d + t + 0.02), Vector3(x0 + t + 0.02, top + 0.08, -t - 0.02), STONE.lightened(0.1))
	blk(pk, kit, "stone", Vector3(x1 - t - 0.02, top, -d + t + 0.02), Vector3(x1 + 0.05, top + 0.08, -t - 0.02), STONE.lightened(0.1))
	# Canales: square timber spouts out through the parapet at the roof's level.
	for sx in [-0.3, 0.3]:
		pk.beam(kit, "timber", Vector3(sx * w, h + 0.12, -0.3), Vector3(sx * w, h + 0.08, 0.55), 0.18, 0.14, WOOD_DARK, Vector3(1, 0, 0))


## A water tank on a stand on a flat roof at (x, z).
static func _roof_tank(pk: PropKit, kit: Dictionary, x: float, z: float, h: float) -> void:
	for sx in [-0.45, 0.45]:
		for sz in [-0.45, 0.45]:
			pk.beam(kit, "steel", Vector3(x + sx, h, z + sz), Vector3(x + sx, h + 0.9, z + sz), 0.06, 0.06, CAST)
	blk(pk, kit, "steel", Vector3(x - 0.6, h + 0.9, z - 0.6), Vector3(x + 0.6, h + 0.96, z + 0.6), CAST)
	pk.tube(kit, "metal", Vector3(x, h + 0.96, z), Vector3(x, h + 2.0, z), 0.55, 0.55, 14, Color(0.18, 0.2, 0.22))
	pk.tube(kit, "metal", Vector3(x, h + 2.0, z), Vector3(x, h + 2.12, z), 0.55, 0.3, 14, Color(0.18, 0.2, 0.22))


## A potted plant at p: a terracotta pot (rolled rim, a band, a foot) with soil in it, and an agave (a rosette of thick
## tapering leaves, curving out, each with a darker spine and a tip) or a flowering shrub (leafy clumps dotted with
## blooms).
static func _pot(pk: PropKit, kit: Dictionary, p: Vector3, agave: bool, s := 1.0) -> void:
	pk.lathe(kit, "plaster", p, [Vector2(0.15 * s, 0.0), Vector2(0.17 * s, 0.04 * s), Vector2(0.21 * s, 0.08 * s), Vector2(0.26 * s, 0.36 * s),
			Vector2(0.255 * s, 0.38 * s), Vector2(0.3 * s, 0.4 * s), Vector2(0.31 * s, 0.48 * s), Vector2(0.27 * s, 0.49 * s), Vector2(0.26 * s, 0.44 * s)], 16, TERRACOTTA)
	pk.lathe(kit, "plaster", p + Vector3(0, 0.2 * s, 0), [Vector2(0.235 * s, 0.0), Vector2(0.245 * s, 0.03 * s)], 16, TERRACOTTA.darkened(0.15), true)
	pk.tube(kit, "matte", p + Vector3(0, 0.42 * s, 0), p + Vector3(0, 0.43 * s, 0), 0.255 * s, 0.255 * s, 16, Color(0.30, 0.22, 0.15))
	var top: Vector3 = p + Vector3(0, 0.43 * s, 0)
	if agave:
		for ring in range(3):
			var n: int = 7 - ring
			for k in range(n):
				var a: float = TAU * (float(k) + 0.5 * float(ring)) / float(n)
				var out := Vector3(cos(a), 0, sin(a))
				var side := Vector3(-sin(a), 0, cos(a))
				var length: float = (0.62 - 0.12 * float(ring)) * s
				var lift: float = 0.35 + 0.35 * float(ring)
				var base: Vector3 = top + out * 0.04 * s
				var mid: Vector3 = base + (out * 0.55 + Vector3(0, lift, 0)).normalized() * length * 0.55
				var tip: Vector3 = base + out * length * (0.85 - 0.2 * float(ring)) + Vector3(0, length * (lift + 0.1), 0)
				var wb: float = 0.07 * s
				var col := Color(0.40, 0.54, 0.42).lerp(Color(0.52, 0.62, 0.48), float(ring) / 2.0)
				var up := (mid - base).cross(side).normalized()
				pk.quad(kit, "canvas", [base - side * wb, base + side * wb, mid + side * wb * 0.7, mid - side * wb * 0.7], up, col)
				pk.quad(kit, "canvas", [base + side * wb, base - side * wb, mid - side * wb * 0.7, mid + side * wb * 0.7], -up, col.darkened(0.15))
				pk.tri(kit, "canvas", mid - side * wb * 0.7, mid + side * wb * 0.7, tip, up, up, up, col, up)
				pk.tri(kit, "canvas", mid + side * wb * 0.7, mid - side * wb * 0.7, tip, -up, -up, -up, col.darkened(0.15), -up)
				pk.beam(kit, "canvas", tip - (tip - mid).normalized() * 0.05 * s, tip, 0.012 * s, 0.012 * s, Color(0.35, 0.22, 0.12))
	else:
		var blooms := [Color(0.88, 0.16, 0.34), Color(0.96, 0.55, 0.12), Color(0.85, 0.30, 0.65)]
		var bc: Color = blooms[int(absf(p.x * 7.0 + p.z * 3.0)) % 3]
		for k in range(5):
			var a3: float = TAU * float(k) / 5.0
			var cc: Vector3 = top + Vector3(cos(a3) * 0.13, 0.18, sin(a3) * 0.13) * s if k > 0 else top + Vector3(0, 0.32, 0) * s
			pk.lathe(kit, "canvas", cc - Vector3(0, 0.12, 0) * s, [Vector2(0.001, 0.0), Vector2(0.16 * s, 0.07 * s), Vector2(0.18 * s, 0.17 * s), Vector2(0.11 * s, 0.27 * s), Vector2(0.001, 0.3 * s)], 9,
					Color(0.24, 0.42, 0.22).lightened(0.05 * float(k)))
			for f in range(3):
				var fa: float = a3 + float(f) * 2.1
				var fp: Vector3 = cc + Vector3(cos(fa) * 0.13, 0.08 + 0.05 * float(f), sin(fa) * 0.13) * s
				pk.lathe(kit, "canvas", fp, [Vector2(0.001, 0.0), Vector2(0.045 * s, 0.02 * s), Vector2(0.001, 0.045 * s)], 5, bc)


## A wall lantern at p on a wall facing `out`: a back plate, a scrolled bracket (an arm and a curved brace), and a
## hexagonal lantern hanging from it: a hood with a finial, six glowing panes between dark corner bars, a base and a drop.
static func _wall_lamp(pk: PropKit, kit: Dictionary, p: Vector3, out: Vector3) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	box_at(pk, kit, "steel", p + out * 0.015, Basis(across, Vector3.UP, out), Vector3(0.16, 0.34, 0.03), CAST)
	var arm_end: Vector3 = p + out * 0.42 + Vector3(0, 0.08, 0)
	pk.beam(kit, "steel", p + out * 0.02 + Vector3(0, 0.08, 0), arm_end, 0.03, 0.03, CAST, across)
	var prev: Vector3 = p + out * 0.02 - Vector3(0, 0.13, 0)
	for k in range(1, 7):
		var t: float = float(k) / 6.0
		var q: Vector3 = p + out * (0.02 + 0.3 * sin(t * PI * 0.5)) + Vector3(0, -0.13 + 0.21 * (1.0 - cos(t * PI * 0.5)), 0)
		pk.beam(kit, "steel", prev, q, 0.02, 0.02, CAST, across)
		prev = q
	pk.tube(kit, "steel", arm_end + Vector3(0, -0.12, 0), arm_end, 0.015, 0.015, 6, CAST, false)
	var c: Vector3 = arm_end + Vector3(0, -0.12, 0)
	pk.lathe(kit, "steel", c - Vector3(0, 0.14, 0), [Vector2(0.15, 0.0), Vector2(0.13, 0.05), Vector2(0.03, 0.14), Vector2(0.001, 0.16)], 6, CAST, true)
	pk.lathe(kit, "lamp", c - Vector3(0, 0.46, 0), [Vector2(0.08, 0.0), Vector2(0.12, 0.3), Vector2(0.001, 0.31)], 6, Color(1.0, 0.82, 0.48), true)
	for k in range(6):
		var a2: float = TAU * (float(k) + 0.5) / 6.0
		var dv := Vector3(cos(a2), 0, sin(a2))
		pk.beam(kit, "steel", c - Vector3(0, 0.46, 0) + dv * 0.085, c - Vector3(0, 0.14, 0) + dv * 0.13, 0.02, 0.02, CAST)
	pk.lathe(kit, "steel", c - Vector3(0, 0.52, 0), [Vector2(0.001, 0.0), Vector2(0.05, 0.02), Vector2(0.1, 0.06), Vector2(0.001, 0.07)], 6, CAST, true)
	pk.lathe(kit, "steel", c - Vector3(0, 0.6, 0), [Vector2(0.001, 0.0), Vector2(0.025, 0.04), Vector2(0.001, 0.08)], 6, CAST, true)


## A clothesline from post a to post b (on the ground): T-shaped posts, two lines sagging between them, and washing
## pegged on: shirts (a body and sleeves), trousers, towels, a sheet, each a different colour, two pegs apiece.
static func _clothesline(pk: PropKit, kit: Dictionary, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var along: Vector3 = (b - a).normalized()
	var across: Vector3 = along.cross(Vector3.UP).normalized()
	var top := 2.1
	for p in [a, b]:
		pk.beam(kit, "steel", p, p + Vector3(0, top + 0.05, 0), 0.06, 0.06, Color(0.5, 0.52, 0.5), across)
		pk.beam(kit, "steel", p + Vector3(0, top, 0) - across * 0.35, p + Vector3(0, top, 0) + across * 0.35, 0.05, 0.05, Color(0.5, 0.52, 0.5))
		pk.beam(kit, "steel", p + Vector3(0, top - 0.35, 0), p + Vector3(0, top - 0.05, 0) + across * 0.3, 0.03, 0.03, Color(0.5, 0.52, 0.5))
		pk.beam(kit, "steel", p + Vector3(0, top - 0.35, 0), p + Vector3(0, top - 0.05, 0) - across * 0.3, 0.03, 0.03, Color(0.5, 0.52, 0.5))
	var span: float = a.distance_to(b)
	var line_y := func(t: float) -> float: return top - 0.25 * 4.0 * t * (1.0 - t)
	for li in [-0.28, 0.28]:
		var n := 12
		for k in range(n):
			var t0: float = float(k) / float(n)
			var t1: float = float(k + 1) / float(n)
			var p0: Vector3 = a.lerp(b, t0) + across * li
			var p1: Vector3 = a.lerp(b, t1) + across * li
			p0.y = line_y.call(t0)
			p1.y = line_y.call(t1)
			pk.beam(kit, "steel", p0, p1, 0.012, 0.012, Color(0.85, 0.85, 0.82))
	var pal := [Color(0.85, 0.25, 0.22), Color(0.22, 0.42, 0.75), Color(0.95, 0.85, 0.35), Color(0.92, 0.92, 0.9), Color(0.35, 0.6, 0.4), Color(0.75, 0.45, 0.7)]
	var x := 0.5
	var li2 := 0
	while x < span - 0.6:
		var t: float = x / span
		var off: float = -0.28 if li2 % 2 == 0 else 0.28
		var c: Vector3 = a + along * x + across * off
		c.y = line_y.call(t)
		var col: Color = pal[rng.randi() % pal.size()]
		var kind: int = rng.randi() % 4
		var bs := Basis(along, Vector3.UP, across)
		var wdt: float
		match kind:
			0:
				wdt = 0.55
				box_at(pk, kit, "canvas", c + Vector3(0, -0.35, 0), bs, Vector3(0.48, 0.66, 0.02), col)
				for sx in [-1.0, 1.0]:
					pk.beam(kit, "canvas", c + along * (sx * 0.22) + Vector3(0, -0.06, 0), c + along * (sx * 0.42) + Vector3(0, -0.36, 0), 0.18, 0.02, col, across)
				box_at(pk, kit, "canvas", c + Vector3(0, -0.03, 0.0), bs, Vector3(0.16, 0.06, 0.025), col.darkened(0.2))
			1:
				wdt = 0.45
				box_at(pk, kit, "canvas", c + Vector3(0, -0.06, 0), bs, Vector3(0.42, 0.12, 0.02), col)
				for sx in [-1.0, 1.0]:
					box_at(pk, kit, "canvas", c + along * (sx * 0.11) + Vector3(0, -0.5, 0), bs, Vector3(0.18, 0.78, 0.02), col)
			2:
				wdt = 0.7
				box_at(pk, kit, "canvas", c + Vector3(0, -0.42, 0), bs, Vector3(0.64, 0.84, 0.02), col)
				box_at(pk, kit, "canvas", c + Vector3(0, -0.72, 0), bs, Vector3(0.64, 0.06, 0.025), col.lightened(0.3))
			_:
				wdt = 1.3
				box_at(pk, kit, "canvas", c + Vector3(0, -0.6, 0), bs, Vector3(1.24, 1.2, 0.02), Color(0.94, 0.94, 0.92))
		for sx2 in [-1.0, 1.0]:
			box_at(pk, kit, "timber", c + along * (sx2 * wdt * 0.4) + Vector3(0, 0.01, 0), bs, Vector3(0.025, 0.08, 0.035), Color(0.62, 0.48, 0.3))
		x += wdt + rng.randf_range(0.15, 0.45)
		li2 += 1


## Wrought-iron bars over a window (a reja), 6cm out: uprights, two rails, a twist of scroll at the top.
static func _grille(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float, h: float) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var f: Vector3 = c + out * 0.16
	var n: int = int(w / 0.16)
	for k in range(n + 1):
		var x: float = -w * 0.5 + w * float(k) / float(n)
		pk.beam(kit, "steel", f + across * x - Vector3(0, h * 0.5 + 0.05, 0), f + across * x + Vector3(0, h * 0.5 + 0.05, 0), 0.02, 0.02, CAST, across)
	for y in [-h * 0.5, 0.0, h * 0.5]:
		pk.beam(kit, "steel", f + Vector3(0, y, 0) - across * (w * 0.5 + 0.05), f + Vector3(0, y, 0) + across * (w * 0.5 + 0.05), 0.03, 0.03, CAST, Vector3.UP)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", f + across * (sx * (w * 0.5 + 0.05)) + Vector3(0, h * 0.5, 0), c + out * 0.02 + across * (sx * (w * 0.5 + 0.05)) + Vector3(0, h * 0.5, 0), 0.03, 0.03, CAST)
		pk.beam(kit, "steel", f + across * (sx * (w * 0.5 + 0.05)) - Vector3(0, h * 0.5, 0), c + out * 0.02 + across * (sx * (w * 0.5 + 0.05)) - Vector3(0, h * 0.5, 0), 0.03, 0.03, CAST)


## A flower box under a window (its sill at c): a planked box on brackets, geraniums in it.
static func _window_box(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3, w: float) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var bs := Basis(across, Vector3.UP, out)
	box_at(pk, kit, "timber", c + out * 0.3 + Vector3(0, -0.28, 0), bs, Vector3(w, 0.24, 0.3), WOOD_MID)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", c + out * 0.04 + across * (sx * w * 0.38) + Vector3(0, -0.55, 0), c + out * 0.3 + across * (sx * w * 0.38) + Vector3(0, -0.4, 0), 0.03, 0.03, CAST)
	var n: int = int(w / 0.2)
	for k in range(n):
		var p: Vector3 = c + out * 0.3 + across * (-w * 0.5 + 0.1 + (w - 0.2) * float(k) / float(maxi(n - 1, 1))) + Vector3(0, -0.16, 0)
		_geranium(pk, kit, p, 1.0, [Color(0.86, 0.10, 0.16), Color(0.94, 0.36, 0.52), Color(0.97, 0.92, 0.9)][k % 3], k * 7 + int(absf(p.x * 13.0)))


## A geranium at `base` (on the soil): a mound of round, scalloped leaves (each a flat fan of 7 triangles, tilted out,
## a darker zone ring), and 2-4 flower heads on stalks rising over them, each a ball of 9-13 florets (five petals round
## a pale eye). `s` scales it (1 is about 30cm tall).
static func _geranium(pk: PropKit, kit: Dictionary, base: Vector3, s: float, bloom: Color, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var leaf := Color(0.24, 0.42, 0.20)
	for k in range(9):
		var a: float = TAU * float(k) / 9.0 + rng.randf_range(-0.2, 0.2)
		var dist: float = rng.randf_range(0.03, 0.11) * s
		var c: Vector3 = base + Vector3(cos(a) * dist, rng.randf_range(0.07, 0.16) * s, sin(a) * dist)
		var lr: float = rng.randf_range(0.045, 0.065) * s
		var tilt: float = rng.randf_range(0.3, 0.8)
		var up: Vector3 = (Vector3(cos(a) * tilt, 1.0, sin(a) * tilt)).normalized()
		var t1: Vector3 = up.cross(Vector3(0, 0, 1) if absf(up.z) < 0.9 else Vector3(1, 0, 0)).normalized()
		var t2: Vector3 = up.cross(t1)
		var col: Color = leaf.lightened(rng.randf_range(-0.05, 0.1))
		pk.beam(kit, "canvas", base, c, 0.008 * s, 0.008 * s, leaf.darkened(0.2))
		for j in range(7):
			var b0: float = TAU * float(j) / 7.0
			var b1: float = TAU * float(j + 1) / 7.0
			var e0: float = lr * (1.0 + 0.12 * sin(b0 * 7.0 * 0.5 + 1.0))
			var e1: float = lr * (1.0 + 0.12 * sin(b1 * 7.0 * 0.5 + 1.0))
			var q0: Vector3 = c + (t1 * cos(b0) + t2 * sin(b0)) * e0
			var q1: Vector3 = c + (t1 * cos(b1) + t2 * sin(b1)) * e1
			var m0: Vector3 = c + (t1 * cos(b0) + t2 * sin(b0)) * e0 * 0.55 + up * 0.002
			var m1: Vector3 = c + (t1 * cos(b1) + t2 * sin(b1)) * e1 * 0.55 + up * 0.002
			pk.tri(kit, "canvas", c, q0, q1, up, up, up, col, up)
			pk.tri(kit, "canvas", c, q1, q0, -up, -up, -up, col.darkened(0.2), -up)
			pk.quad(kit, "canvas", [m0, m0.lerp(q0, 0.25) + up * 0.001, m1.lerp(q1, 0.25) + up * 0.001, m1], up, col.darkened(0.25))
	var heads: int = rng.randi_range(2, 4)
	for h in range(heads):
		var a2: float = TAU * float(h) / float(heads) + rng.randf_range(-0.4, 0.4)
		var top: Vector3 = base + Vector3(cos(a2) * 0.05 * s, rng.randf_range(0.24, 0.34) * s, sin(a2) * 0.05 * s)
		pk.beam(kit, "canvas", base + Vector3(0, 0.05 * s, 0), top, 0.01 * s, 0.01 * s, leaf.darkened(0.1))
		var n: int = rng.randi_range(9, 13)
		for f in range(n):
			# Florets over the upper half of a ball, each facing out.
			var ph: float = acos(rng.randf_range(0.1, 1.0))
			var th: float = rng.randf() * TAU
			var dirf := Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th))
			var fc: Vector3 = top + dirf * 0.045 * s
			var u1: Vector3 = dirf.cross(Vector3.UP if absf(dirf.y) < 0.95 else Vector3.RIGHT).normalized()
			var u2: Vector3 = dirf.cross(u1)
			var pr: float = 0.02 * s
			var pc: Color = bloom.lightened(rng.randf_range(-0.05, 0.1))
			for pi in range(5):
				var pa: float = TAU * float(pi) / 5.0
				var pd: Vector3 = u1 * cos(pa) + u2 * sin(pa)
				var pw: Vector3 = (u1 * cos(pa + PI * 0.5) + u2 * sin(pa + PI * 0.5)) * pr * 0.45
				var tip: Vector3 = fc + pd * pr
				pk.quad(kit, "canvas", [fc, fc + pd * pr * 0.5 + pw, tip, fc + pd * pr * 0.5 - pw], dirf, pc)
				pk.quad(kit, "canvas", [fc, fc + pd * pr * 0.5 - pw, tip, fc + pd * pr * 0.5 + pw], -dirf, pc.darkened(0.2))
			pk.tri(kit, "canvas", fc + dirf * 0.002 + u1 * pr * 0.2, fc + dirf * 0.002 + u2 * pr * 0.2, fc + dirf * 0.002 - u1 * pr * 0.2, dirf, dirf, dirf, Color(0.98, 0.9, 0.85), dirf)


## An air-conditioner box on a wall at c facing `out`, on two brackets, with a grille and a drip pipe.
static func _ac_unit(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var bs := Basis(across, Vector3.UP, out)
	box_at(pk, kit, "steel", c + out * 0.28, bs, Vector3(0.85, 0.6, 0.5), Color(0.86, 0.86, 0.84))
	pk.tube(kit, "steel", c + out * 0.54, c + out * 0.56, 0.22, 0.22, 14, Color(0.25, 0.25, 0.26))
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "steel", c + across * (sx * 0.32) - Vector3(0, 0.3, 0), c + across * (sx * 0.32) + out * 0.5 - Vector3(0, 0.3, 0), 0.04, 0.04, CAST)
	pk.tube(kit, "steel", c + out * 0.1 - Vector3(0, 0.3, 0), c + out * 0.1 - Vector3(0, c.y - 0.1, 0), 0.015, 0.015, 5, Color(0.9, 0.9, 0.9))


## A satellite dish on a stand on a flat roof at p.
static func _dish(pk: PropKit, kit: Dictionary, p: Vector3) -> void:
	pk.tube(kit, "steel", p, p + Vector3(0, 0.8, 0), 0.04, 0.04, 8, Color(0.6, 0.6, 0.6))
	var c := p + Vector3(0, 0.95, 0.1)
	var bs := Basis(Vector3.RIGHT, -0.6)
	pk.lathe(kit, "steel", c, [Vector2(0.001, 0.0), Vector2(0.3, 0.06), Vector2(0.42, 0.14)], 16, Color(0.9, 0.9, 0.88), false, bs)
	pk.lathe(kit, "steel", c, [Vector2(0.42, 0.12), Vector2(0.3, 0.04), Vector2(0.001, -0.02)], 16, Color(0.7, 0.7, 0.68), false, bs)
	pk.beam(kit, "steel", c, c + bs * Vector3(0, 0.45, 0), 0.02, 0.02, Color(0.6, 0.6, 0.6))


## The electricity meter box on a wall at c, its cable up to the eaves.
static func _meter_box(pk: PropKit, kit: Dictionary, c: Vector3, out: Vector3) -> void:
	var across: Vector3 = out.cross(Vector3.UP).normalized()
	var bs := Basis(across, Vector3.UP, out)
	box_at(pk, kit, "steel", c + out * 0.08, bs, Vector3(0.35, 0.5, 0.12), Color(0.72, 0.74, 0.72))
	box_at(pk, kit, "glass", c + out * 0.145 + Vector3(0, 0.08, 0), bs, Vector3(0.16, 0.12, 0.02), GLASS_COL)
	pk.tube(kit, "steel", c + out * 0.06 + Vector3(0, 0.25, 0), c + out * 0.06 + Vector3(0, 1.9, 0), 0.02, 0.02, 6, CAST)


## A sign board on the wall at c (its middle on the face), w x h, with its text.
static func _board(pk: PropKit, kit: Dictionary, labels: Array, c: Vector3, w: float, h: float, col: Color, text: String, ink: Color) -> void:
	box_at(pk, kit, "painted", c + Vector3(0, 0, 0.04), Basis(), Vector3(w, h, 0.08), col)
	box_at(pk, kit, "painted", c + Vector3(0, 0, 0.09), Basis(), Vector3(w - 0.16, h - 0.16, 0.02), col.lightened(0.12))
	labels.append([text, c + Vector3(0, 0, 0.13), Vector3(0, 0, 1), h * 0.42, ink, w - 0.4])


# ======================================================================================
#  The buildings
# ======================================================================================

## A house under a tile gable: a door with steps between two shuttered windows, a window on each side, a chimney, a
## bench and pots by the door, a low garden wall along the front with a gap for the path.
static func _house_gable(pk: PropKit, kit: Dictionary, w: float, d: float, col: Color, shutter: Color, rng: RandomNumberGenerator) -> void:
	var h := 3.3
	_shell(pk, kit, w, d, h, col, false)
	_gable_roof(pk, kit, w, d, h, col, 1.6)
	door(pk, kit, Vector3(0.0, 0.45, 0.0), Vector3(0, 0, 1), 1.1, 2.2, true, 0.0)
	for sx in [-1.0, 1.0]:
		window(pk, kit, Vector3(sx * w * 0.3, 1.75, 0.0), Vector3(0, 0, 1), 1.0, 1.25, shutter)
		window(pk, kit, Vector3(sx * w * 0.5, 1.75, -d * 0.5), Vector3(sx, 0, 0), 0.9, 1.15, shutter)
	window(pk, kit, Vector3(0.0, 1.75, -d), Vector3(0, 0, -1), 1.0, 1.15, Color(0, 0, 0, 0))
	blk(pk, kit, "brick", Vector3(w * 0.25 - 0.35, h + 0.6, -d * 0.7 - 0.35), Vector3(w * 0.25 + 0.35, h + 2.3, -d * 0.7 + 0.35), BRICK)
	blk(pk, kit, "brick", Vector3(w * 0.25 - 0.42, h + 2.3, -d * 0.7 - 0.42), Vector3(w * 0.25 + 0.42, h + 2.42, -d * 0.7 + 0.42), BRICK.darkened(0.1))
	_wall_lamp(pk, kit, Vector3(-0.95, 2.85, 0.0), Vector3(0, 0, 1))
	bench(pk, kit, Vector3(w * 0.3, 0.0, 1.0), Vector3(0, 0, 1), 1.4)
	for sx2 in [-1.0, 1.0]:
		_window_box(pk, kit, Vector3(sx2 * w * 0.3, 1.75 - 0.625, 0.0), Vector3(0, 0, 1), 1.2)
		_window_box(pk, kit, Vector3(sx2 * w * 0.5, 1.75 - 0.575, -d * 0.5), Vector3(sx2, 0, 0), 1.1)
	# A little tiled canopy over the door on two brackets, the house number on a tile beside it.
	pk.quad(kit, "tile", [Vector3(-0.95, 2.95, 0.05), Vector3(0.95, 2.95, 0.05), Vector3(0.95, 2.75, 0.8), Vector3(-0.95, 2.75, 0.8)], Vector3(0, 1, 0.27).normalized(), TERRACOTTA)
	pk.quad(kit, "lapboards", [Vector3(-0.95, 2.93, 0.05), Vector3(0.95, 2.93, 0.05), Vector3(0.95, 2.73, 0.8), Vector3(-0.95, 2.73, 0.8)], Vector3(0, -1, -0.27).normalized(), WOOD_MID)
	for bx in [-0.85, 0.85]:
		pk.beam(kit, "timber", Vector3(bx, 2.35, 0.03), Vector3(bx, 2.78, 0.7), 0.07, 0.07, WOOD_DARK)
	box_at(pk, kit, "painted", Vector3(0.95, 2.15, 0.03), Basis(), Vector3(0.24, 0.24, 0.04), WHITE_WALL)
	_meter_box(pk, kit, Vector3(w * 0.45, 1.5, 0.0), Vector3(0, 0, 1))
	_pot(pk, kit, Vector3(-1.1, 0.0, 0.6), true)
	_pot(pk, kit, Vector3(1.1, 0.0, 0.6), false, 0.9)
	# The garden wall, a gap for the path.
	for sx in [-1.0, 1.0]:
		var xa: float = sx * 0.9
		var xb: float = sx * (w * 0.5 + 0.2)
		blk(pk, kit, "plaster", Vector3(minf(xa, xb), 0.0, 2.3), Vector3(maxf(xa, xb), 0.85, 2.55), col.lightened(0.08))
		blk(pk, kit, "stone", Vector3(minf(xa, xb) - 0.04, 0.85, 2.26), Vector3(maxf(xa, xb) + 0.04, 0.93, 2.59), STONE.lightened(0.1))
		blk(pk, kit, "plaster", Vector3(minf(xb, xb + sx * 0.25) if sx > 0.0 else xb - 0.25, 0.0, 0.0), Vector3(xb if sx < 0.0 else xb + 0.25, 0.85, 2.3), col.lightened(0.08))


## The cantina: a flat roof behind a stepped false front with its name, a timber portal (porch) along the front on posts
## with a plank floor, batwing doors, lanterns hung from the portal's beam, barrels, a bench and a hitching rail.
static func _cantina(pk: PropKit, kit: Dictionary, w: float, d: float, col: Color, shutter: Color, labels: Array) -> void:
	var h := 3.9
	_shell(pk, kit, w, d, h, col, false)
	_flat_roof(pk, kit, w, d, h, col, 0.6)
	# The false front: a stepped crown over the middle of the facade.
	blk(pk, kit, "plaster", Vector3(-w * 0.3, h + 0.6, -0.25), Vector3(w * 0.3, h + 1.5, 0.0), col)
	blk(pk, kit, "plaster", Vector3(-w * 0.15, h + 1.5, -0.25), Vector3(w * 0.15, h + 2.0, 0.0), col)
	blk(pk, kit, "stone", Vector3(-w * 0.3 - 0.05, h + 1.5, -0.3), Vector3(-w * 0.15, h + 1.58, 0.05), STONE.lightened(0.1))
	blk(pk, kit, "stone", Vector3(w * 0.15, h + 1.5, -0.3), Vector3(w * 0.3 + 0.05, h + 1.58, 0.05), STONE.lightened(0.1))
	blk(pk, kit, "stone", Vector3(-w * 0.15 - 0.05, h + 2.0, -0.3), Vector3(w * 0.15 + 0.05, h + 2.08, 0.05), STONE.lightened(0.1))
	_board(pk, kit, labels, Vector3(0.0, h + 1.0, 0.0), w * 0.55, 0.8, Color(0.30, 0.12, 0.08), "CANTINA LA VIA", Color(0.98, 0.84, 0.45))
	# The portal: a plank floor, posts and a beam, a sloping roof of boards with its underside.
	var pd := 2.8
	var ph := 3.15
	blk(pk, kit, "timber", Vector3(-w * 0.5, 0.0, 0.0), Vector3(w * 0.5, 0.45, pd), WOOD_MID)
	for k in range(2):
		blk(pk, kit, "timber", Vector3(-1.0 - 0.3 * float(k), 0.0, pd + 0.0), Vector3(1.0 + 0.3 * float(k), 0.3 - 0.15 * float(k), pd + 0.35 + 0.35 * float(k)), WOOD_MID.darkened(0.08 * float(k)))
	var posts := 5
	for k in range(posts):
		var px: float = lerpf(-w * 0.5 + 0.2, w * 0.5 - 0.2, float(k) / float(posts - 1))
		blk(pk, kit, "timber", Vector3(px - 0.11, 0.45, pd - 0.31), Vector3(px + 0.11, ph, pd - 0.09), WOOD_DARK)
		pk.beam(kit, "timber", Vector3(px, ph - 0.55, pd - 0.2), Vector3(px + 0.45, ph - 0.1, pd - 0.2), 0.1, 0.08, WOOD_DARK, Vector3(0, 0, 1))
	blk(pk, kit, "timber", Vector3(-w * 0.5 - 0.1, ph, pd - 0.36), Vector3(w * 0.5 + 0.1, ph + 0.25, pd - 0.04), WOOD_DARK)
	var r_back: float = ph + 0.55
	pk.quad(kit, "lapboards", [Vector3(-w * 0.5 - 0.2, ph + 0.25, pd + 0.1), Vector3(w * 0.5 + 0.2, ph + 0.25, pd + 0.1), Vector3(w * 0.5 + 0.2, r_back, 0.06), Vector3(-w * 0.5 - 0.2, r_back, 0.06)],
			Vector3(0, 1.0, 0.11).normalized(), WOOD_MID.darkened(0.1))
	pk.quad(kit, "lapboards", [Vector3(-w * 0.5 - 0.2, r_back - 0.05, 0.06), Vector3(w * 0.5 + 0.2, r_back - 0.05, 0.06), Vector3(w * 0.5 + 0.2, ph + 0.2, pd + 0.1), Vector3(-w * 0.5 - 0.2, ph + 0.2, pd + 0.1)],
			Vector3(0, -1.0, -0.11).normalized(), WOOD_MID.darkened(0.25))
	# The door on the portal's floor, batwing doors in it, windows either side with shutters.
	door(pk, kit, Vector3(0.0, 0.45, 0.0), Vector3(0, 0, 1), 1.5, 2.4, false)
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "painted", Vector3(sx * 0.37, 1.55, 0.2), Basis(), Vector3(0.66, 1.0, 0.05), shutter)
		for k in range(4):
			box_at(pk, kit, "painted", Vector3(sx * 0.37, 1.2 + 0.22 * float(k), 0.24), Basis(), Vector3(0.58, 0.05, 0.03), shutter.lightened(0.2))
		window(pk, kit, Vector3(sx * w * 0.3, 2.05, 0.0), Vector3(0, 0, 1), 1.4, 1.3, shutter)
		window(pk, kit, Vector3(sx * w * 0.5, 2.05, -d * 0.5), Vector3(sx, 0, 0), 1.0, 1.2, shutter)
	# Lanterns on the beam, barrels and a bench on the portal, a hitching rail in front of it.
	for lx in [-w * 0.32, 0.0, w * 0.32]:
		pk.beam(kit, "steel", Vector3(lx, ph, pd - 0.2), Vector3(lx, ph - 0.35, pd - 0.2), 0.02, 0.02, CAST)
		pk.block(kit, "lamp", Vector3(lx - 0.1, ph - 0.7, pd - 0.3), Vector3(lx + 0.1, ph - 0.35, pd - 0.1), Color(1.0, 0.78, 0.45))
	for bx in [-w * 0.42, -w * 0.42 + 0.75]:
		drum(pk, kit, Vector3(bx, 0.45, 1.2), WOOD_MID, 0.95, 0.34)
	bench(pk, kit, Vector3(w * 0.32, 0.45, 1.3), Vector3(0, 0, 1), 1.8)
	for sx in [-1.0, 1.0]:
		pk.beam(kit, "timber", Vector3(sx * w * 0.35, 0.0, pd + 1.6), Vector3(sx * w * 0.35, 1.05, pd + 1.6), 0.12, 0.12, WOOD_DARK)
	pk.beam(kit, "timber", Vector3(-w * 0.35 - 0.1, 1.0, pd + 1.6), Vector3(w * 0.35 + 0.1, 1.0, pd + 1.6), 0.1, 0.1, WOOD_DARK, Vector3(0, 0, 1))
	_roof_tank(pk, kit, w * 0.25, -d * 0.6, h)
	# A lit beer sign in the window, string lights along the portal's beam, a chalkboard by the door.
	# In the window's outer half: from the road a porch post stood in front of its middle.
	var sgx: float = -w * 0.3 - 0.33
	box_at(pk, kit, "steel", Vector3(sgx, 2.05, 0.11), Basis(), Vector3(0.72, 0.32, 0.04), CAST)
	box_at(pk, kit, "lamp", Vector3(sgx, 1.93, 0.14), Basis(), Vector3(0.64, 0.04, 0.02), Color(1.0, 0.35, 0.2))
	labels.append(["CERVEZA", Vector3(sgx, 2.08, 0.16), Vector3(0, 0, 1), 0.13, Color(1.4, 0.75, 0.3), 0.66])
	var bulbs := 18
	for k in range(bulbs + 1):
		var t: float = float(k) / float(bulbs)
		var bx2: float = lerpf(-w * 0.5, w * 0.5, t)
		var sag: float = 0.18 * sin(fmod(t * 4.0, 1.0) * PI)
		pk.lathe(kit, "lamp", Vector3(bx2, ph - 0.12 - sag, pd + 0.02), [Vector2(0.001, 0.0), Vector2(0.05, 0.05), Vector2(0.001, 0.12)], 6,
				[Color(1.0, 0.8, 0.4), Color(1.0, 0.45, 0.3), Color(0.6, 0.9, 0.5)][k % 3], true)
		if k < bulbs:
			var t2: float = float(k + 1) / float(bulbs)
			var sag2: float = 0.18 * sin(fmod(t2 * 4.0, 1.0) * PI) if k + 1 < bulbs else 0.0
			pk.beam(kit, "steel", Vector3(bx2, ph - sag, pd + 0.02), Vector3(lerpf(-w * 0.5, w * 0.5, t2), ph - sag2, pd + 0.02), 0.012, 0.012, CAST)
	box_at(pk, kit, "painted", Vector3(1.4, 0.45 + 0.55, 0.9), Basis(Vector3.RIGHT, -0.15), Vector3(0.6, 0.85, 0.04), Color(0.1, 0.12, 0.1))
	labels.append(["HOY", Vector3(1.4, 1.15, 0.94), Vector3(0, 0, 1), 0.12, Color(0.95, 0.95, 0.9), 0.5])


## The shop: a flat roof, two big shop windows either side of a glazed door, a striped canvas awning over them on
## brackets (with its underside and a scalloped valance), the name on a board, crates of fruit and a bench outside.
static func _tienda(pk: PropKit, kit: Dictionary, w: float, d: float, col: Color, shutter: Color, labels: Array) -> void:
	var h := 3.7
	_shell(pk, kit, w, d, h, col)
	_flat_roof(pk, kit, w, d, h, col, 0.8)
	_board(pk, kit, labels, Vector3(0.0, h + 0.35, 0.0), w * 0.7, 0.75, Color(0.92, 0.88, 0.70), "ABARROTES", Color(0.12, 0.25, 0.50))
	# The shop windows: a painted frame (3cm proud), the glass, a stall riser under them.
	for sx in [-1.0, 1.0]:
		var cx: float = sx * w * 0.27
		var ww: float = w * 0.32
		box_at(pk, kit, "painted", Vector3(cx, 1.65, 0.03), Basis(), Vector3(ww + 0.24, 2.0, 0.06), shutter)
		box_at(pk, kit, "glass", Vector3(cx, 1.7, 0.065), Basis(), Vector3(ww, 1.7, 0.03), GLASS_COL)
		box_at(pk, kit, "painted", Vector3(cx, 1.7, 0.095), Basis(), Vector3(0.06, 1.7, 0.03), shutter)
		box_at(pk, kit, "painted", Vector3(cx, 0.5, 0.06), Basis(), Vector3(ww + 0.24, 0.5, 0.12), shutter.darkened(0.2))
		# Goods in the window: shelves of coloured tins.
		for k in range(3):
			box_at(pk, kit, "matte", Vector3(cx, 1.1 + 0.45 * float(k), -0.12), Basis(), Vector3(ww - 0.1, 0.3, 0.12), [Color(0.8, 0.2, 0.15), Color(0.95, 0.75, 0.2), Color(0.2, 0.5, 0.3)][k])
	door(pk, kit, Vector3(0.0, 0.45, 0.0), Vector3(0, 0, 1), 1.2, 2.3, true, 0.0)
	# The awning: stripes of canvas sloping out on brackets, its underside, a valance.
	var ay0 := 3.15
	var ay1 := 2.55
	var az := 1.7
	var n := 10
	for k in range(n):
		var xa: float = lerpf(-w * 0.5 + 0.2, w * 0.5 - 0.2, float(k) / float(n))
		var xb: float = lerpf(-w * 0.5 + 0.2, w * 0.5 - 0.2, float(k + 1) / float(n))
		var c: Color = Color(0.85, 0.22, 0.16) if k % 2 == 0 else Color(0.95, 0.93, 0.86)
		pk.quad(kit, "canvas", [Vector3(xa, ay1, az), Vector3(xb, ay1, az), Vector3(xb, ay0, 0.06), Vector3(xa, ay0, 0.06)], Vector3(0, 1.0, 0.35).normalized(), c)
		pk.quad(kit, "canvas", [Vector3(xa, ay0 - 0.02, 0.06), Vector3(xb, ay0 - 0.02, 0.06), Vector3(xb, ay1 - 0.02, az), Vector3(xa, ay1 - 0.02, az)], Vector3(0, -1.0, -0.35).normalized(), c.darkened(0.25))
		pk.quad(kit, "canvas", [Vector3(xa, ay1 - 0.3, az + 0.01), Vector3(xb, ay1 - 0.3, az + 0.01), Vector3(xb, ay1, az + 0.01), Vector3(xa, ay1, az + 0.01)], Vector3(0, 0, 1), c)
	for sx in [-1.0, 0.0, 1.0]:
		pk.beam(kit, "steel", Vector3(sx * (w * 0.5 - 0.3), ay0 - 0.6, 0.03), Vector3(sx * (w * 0.5 - 0.3), ay1 - 0.04, az - 0.05), 0.04, 0.04, CAST)
	# Crates of fruit and vegetables on trestles, a bench, a cooler.
	for k in range(3):
		var fx: float = -w * 0.45 + 1.2 * float(k)
		crate(pk, kit, Vector3(fx + 0.4, 0.0, 1.0), 0.0, Vector3(0.7, 0.5, 0.5), Color(0.6, 0.45, 0.28))
		var fruit: Color = [Color(0.9, 0.45, 0.1), Color(0.35, 0.6, 0.2), Color(0.85, 0.15, 0.12)][k]
		pk.lathe(kit, "matte", Vector3(fx + 0.4, 0.5, 1.0), [Vector2(0.3, 0.0), Vector2(0.24, 0.12), Vector2(0.001, 0.18)], 8, fruit)
	bench(pk, kit, Vector3(w * 0.33, 0.0, 1.1), Vector3(0, 0, 1), 1.6)
	box_at(pk, kit, "paint", Vector3(w * 0.1, 0.55, 0.5), Basis(), Vector3(0.7, 1.1, 0.6), Color(0.75, 0.1, 0.1))
	box_at(pk, kit, "glass", Vector3(w * 0.1, 0.75, 0.815), Basis(), Vector3(0.5, 0.6, 0.03), GLASS_COL)
	_roof_tank(pk, kit, -w * 0.25, -d * 0.55, h)
	_ac_unit(pk, kit, Vector3(w * 0.5, 2.6, -d * 0.5), Vector3(1, 0, 0))
	# A hanging blade sign over the door's corner.
	pk.beam(kit, "steel", Vector3(-w * 0.5 + 0.3, 3.35, 0.0), Vector3(-w * 0.5 + 0.3, 3.35, 0.9), 0.04, 0.04, CAST)
	box_at(pk, kit, "painted", Vector3(-w * 0.5 + 0.3, 2.95, 0.55), Basis(Vector3.UP, PI * 0.5), Vector3(0.75, 0.6, 0.05), Color(0.85, 0.22, 0.16))
	labels.append(["HELADOS", Vector3(-w * 0.5 + 0.33, 2.95, 0.55), Vector3(1, 0, 0), 0.11, Color(0.98, 0.95, 0.85), 0.65])
	_meter_box(pk, kit, Vector3(w * 0.45, 1.5, 0.0), Vector3(0, 0, 1))


## The guest house: two storeys under a tile gable, a balcony across the upper floor on brackets with an iron railing
## and French windows onto it, a door with a lantern either side, the name on a board, flower boxes.
static func _hostal(pk: PropKit, kit: Dictionary, w: float, d: float, col: Color, shutter: Color, labels: Array) -> void:
	var h := 6.6
	_shell(pk, kit, w, d, h, col)
	_gable_roof(pk, kit, w, d, h, col, 1.9)
	# A band at the floor between the storeys.
	blk(pk, kit, "plaster", Vector3(-w * 0.5 - 0.06, 3.3, -d - 0.06), Vector3(w * 0.5 + 0.06, 3.48, 0.06), col.lightened(0.1))
	door(pk, kit, Vector3(0.0, 0.45, 0.0), Vector3(0, 0, 1), 1.3, 2.3, true, 0.0)
	for sx in [-1.0, 1.0]:
		_wall_lamp(pk, kit, Vector3(sx * 1.2, 2.6, 0.0), Vector3(0, 0, 1))
		window(pk, kit, Vector3(sx * w * 0.32, 1.75, 0.0), Vector3(0, 0, 1), 1.1, 1.2, shutter)
		for z in [-d * 0.3, -d * 0.7]:
			window(pk, kit, Vector3(sx * w * 0.5, 1.75, z), Vector3(sx, 0, 0), 0.9, 1.1, shutter)
			window(pk, kit, Vector3(sx * w * 0.5, 4.9, z), Vector3(sx, 0, 0), 0.9, 1.1, shutter)
	# The balcony: a slab on brackets (with its underside), an iron railing, French windows behind it.
	var bz := 1.2
	blk(pk, kit, "concrete", Vector3(-w * 0.42, 3.22, 0.06), Vector3(w * 0.42, 3.72, bz), CONCRETE)
	for bx in [-w * 0.38, 0.0, w * 0.38]:
		pk.beam(kit, "stone", Vector3(bx, 2.95, 0.06), Vector3(bx, 3.22, bz * 0.8), 0.18, 0.18, STONE)
	railing(pk, kit, Vector3(-w * 0.42 + 0.05, 3.72, bz - 0.05), Vector3(w * 0.42 - 0.05, 3.72, bz - 0.05), 1.0, CAST)
	railing(pk, kit, Vector3(-w * 0.42 + 0.05, 3.72, 0.1), Vector3(-w * 0.42 + 0.05, 3.72, bz - 0.05), 1.0, CAST)
	railing(pk, kit, Vector3(w * 0.42 - 0.05, 3.72, bz - 0.05), Vector3(w * 0.42 - 0.05, 3.72, 0.1), 1.0, CAST)
	for k in range(3):
		var wx: float = (float(k) - 1.0) * w * 0.3
		window(pk, kit, Vector3(wx, 4.85, 0.0), Vector3(0, 0, 1), 1.0, 2.0, shutter)
		# A flower box on the railing.
		blk(pk, kit, "timber", Vector3(wx - 0.5, 4.5, bz + 0.0), Vector3(wx + 0.5, 4.72, bz + 0.25), WOOD_MID)
		for f in range(5):
			pk.lathe(kit, "canvas", Vector3(wx - 0.4 + 0.2 * float(f), 4.72, bz + 0.12), [Vector2(0.1, 0.0), Vector2(0.12, 0.1), Vector2(0.001, 0.18)], 6,
					[Color(0.85, 0.15, 0.25), Color(0.95, 0.6, 0.1), Color(0.8, 0.2, 0.5)][f % 3])
	# The name on the balcony's front edge (over the door it ran into the door's frame).
	_board(pk, kit, labels, Vector3(0.0, 3.47, bz), 3.4, 0.42, Color(0.10, 0.22, 0.42), "HOSTAL LA ESTACION", Color(0.96, 0.94, 0.86))
	_pot(pk, kit, Vector3(-1.4, 0.0, 0.9), true, 1.1)
	_pot(pk, kit, Vector3(1.4, 0.0, 0.9), true, 1.1)
	for sx3 in [-1.0, 1.0]:
		_grille(pk, kit, Vector3(sx3 * w * 0.32, 1.75, 0.0), Vector3(0, 0, 1), 1.1, 1.2)
	pk.tube(kit, "steel", Vector3(w * 0.3, h + 1.0, -d * 0.6), Vector3(w * 0.3, h + 3.4, -d * 0.6), 0.03, 0.025, 6, CAST)
	for k in range(3):
		pk.beam(kit, "steel", Vector3(w * 0.3 - 0.5 + 0.08 * float(k), h + 2.6 + 0.3 * float(k), -d * 0.6), Vector3(w * 0.3 + 0.5 - 0.08 * float(k), h + 2.6 + 0.3 * float(k), -d * 0.6), 0.02, 0.02, CAST)


## A flat-roofed adobe house: vigas (roof beams) through the front wall, canales, a water tank on the roof, a door and
## deep-set windows, a ramada (a shade of poles and brush) at one side with a table under it, a clothesline.
static func _house_flat(pk: PropKit, kit: Dictionary, w: float, d: float, col: Color, shutter: Color, rng: RandomNumberGenerator) -> void:
	var h := 3.4
	_shell(pk, kit, w, d, h, col, false)
	_flat_roof(pk, kit, w, d, h, col, 0.55)
	var vx := -w * 0.5 + 0.6
	while vx < w * 0.5 - 0.4:
		pk.tube(kit, "timber", Vector3(vx, h - 0.25, -0.3), Vector3(vx, h - 0.25, 0.45), 0.11, 0.11, 8, WOOD_DARK)
		vx += 0.9
	door(pk, kit, Vector3(-w * 0.18, 0.45, 0.0), Vector3(0, 0, 1), 1.0, 2.15, true, 0.0)
	window(pk, kit, Vector3(w * 0.22, 1.7, 0.0), Vector3(0, 0, 1), 1.1, 1.1, shutter)
	window(pk, kit, Vector3(w * 0.5, 1.7, -d * 0.5), Vector3(1, 0, 0), 0.9, 1.0, shutter)
	window(pk, kit, Vector3(-w * 0.5, 1.7, -d * 0.5), Vector3(-1, 0, 0), 0.9, 1.0, shutter)
	_roof_tank(pk, kit, -w * 0.2, -d * 0.5, h)
	# The ramada on the east side: four poles, beams, a roof of brush (a mat of thin poles).
	var rx0: float = w * 0.5 + 0.3
	var rx1: float = w * 0.5 + 3.2
	for p in [Vector2(rx0, 0.3), Vector2(rx1, 0.3), Vector2(rx0, -3.0), Vector2(rx1, -3.0)]:
		pk.tube(kit, "timber", Vector3(p.x, 0.0, p.y), Vector3(p.x, 2.6, p.y), 0.09, 0.08, 8, WOOD_DARK)
	pk.beam(kit, "timber", Vector3(rx0 - 0.2, 2.6, 0.3), Vector3(rx1 + 0.2, 2.6, 0.3), 0.14, 0.14, WOOD_DARK, Vector3(0, 0, 1))
	pk.beam(kit, "timber", Vector3(rx0 - 0.2, 2.6, -3.0), Vector3(rx1 + 0.2, 2.6, -3.0), 0.14, 0.14, WOOD_DARK, Vector3(0, 0, 1))
	var mz := -3.2
	while mz < 0.5:
		pk.tube(kit, "timber", Vector3(rx0 - 0.3, 2.74, mz), Vector3(rx1 + 0.3, 2.74, mz), 0.04, 0.04, 5, Color(0.62, 0.52, 0.36))
		mz += 0.12
	blk(pk, kit, "timber", Vector3(rx0 + 0.6, 0.72, -2.0), Vector3(rx1 - 0.6, 0.78, -1.0), WOOD_MID)
	for tx in [rx0 + 0.7, rx1 - 0.7]:
		for tz in [-1.9, -1.1]:
			pk.beam(kit, "timber", Vector3(tx, 0.0, tz), Vector3(tx, 0.72, tz), 0.06, 0.06, WOOD_DARK)
	# The clothesline behind, with washing.
	# Off to the side of the back door (it had hung across it).
	_clothesline(pk, kit, Vector3(w * 0.02, 0.0, -d - 3.2), Vector3(w * 0.5 + 2.6, 0.0, -d - 3.2), rng)
	for sx in [-1.0, 1.0]:
		_grille(pk, kit, Vector3(sx * w * 0.5, 1.7, -d * 0.5), Vector3(sx, 0, 0), 0.9, 1.0)
	_grille(pk, kit, Vector3(w * 0.22, 1.7, 0.0), Vector3(0, 0, 1), 1.1, 1.1)
	_dish(pk, kit, Vector3(w * 0.3, h, -d + 0.8))
	_meter_box(pk, kit, Vector3(-w * 0.42, 1.6, 0.0), Vector3(0, 0, 1))
	_pot(pk, kit, Vector3(w * 0.05, 0.0, 0.5), false)


## The chemist's: a flat roof, a green cross sign standing out from the wall over the door (lit), a shop window, the
## name on a board.
static func _farmacia(pk: PropKit, kit: Dictionary, w: float, d: float, col: Color, shutter: Color, labels: Array) -> void:
	var h := 3.6
	_shell(pk, kit, w, d, h, col)
	_flat_roof(pk, kit, w, d, h, col, 0.7)
	_board(pk, kit, labels, Vector3(0.0, h + 0.3, 0.0), w * 0.7, 0.65, Color(0.10, 0.42, 0.30), "FARMACIA", Color(0.96, 0.96, 0.92))
	door(pk, kit, Vector3(w * 0.22, 0.45, 0.0), Vector3(0, 0, 1), 1.1, 2.3, true, 0.0)
	box_at(pk, kit, "painted", Vector3(-w * 0.18, 1.7, 0.03), Basis(), Vector3(2.6, 1.9, 0.06), shutter)
	box_at(pk, kit, "glass", Vector3(-w * 0.18, 1.75, 0.065), Basis(), Vector3(2.3, 1.6, 0.03), GLASS_COL)
	box_at(pk, kit, "painted", Vector3(-w * 0.18, 0.55, 0.06), Basis(), Vector3(2.6, 0.45, 0.12), shutter.darkened(0.2))
	# The cross on a bracket: two lit bars each side of a dark box.
	var cp := Vector3(w * 0.22, 3.2, 0.55)
	pk.beam(kit, "steel", Vector3(w * 0.22, 3.2, 0.0), cp, 0.06, 0.06, CAST)
	box_at(pk, kit, "steel", cp, Basis(), Vector3(0.08, 0.86, 0.86), CAST)
	for sx in [-1.0, 1.0]:
		box_at(pk, kit, "lamp", cp + Vector3(sx * 0.055, 0, 0), Basis(), Vector3(0.03, 0.72, 0.24), Color(0.2, 0.95, 0.4))
		box_at(pk, kit, "lamp", cp + Vector3(sx * 0.055, 0, 0), Basis(), Vector3(0.03, 0.24, 0.72), Color(0.2, 0.95, 0.4))
	window(pk, kit, Vector3(w * 0.5, 1.75, -d * 0.5), Vector3(1, 0, 0), 0.9, 1.1, shutter)
	_pot(pk, kit, Vector3(w * 0.42, 0.0, 0.6), true)
	_ac_unit(pk, kit, Vector3(-w * 0.5, 2.5, -d * 0.4), Vector3(-1, 0, 0))
	_wall_lamp(pk, kit, Vector3(w * 0.22 - 0.9, 2.6, 0.0), Vector3(0, 0, 1))
	_dish(pk, kit, Vector3(-w * 0.25, h, -d + 0.8))


# ======================================================================================
#  The street and the plaza
# ======================================================================================

## The pavement along the town's front: concrete slabs in a 1.5m grid (joints 1.2cm up), a stone kerb on the road
## side, lamp posts, benches, a bin, from x0 to x1 (life size, the frame's x along the street), its front edge at
## z = depth (toward the road), its back at z = 0 under the buildings' fronts.
static func pavement(pk: PropKit, kit: Dictionary, x0: float, x1: float, depth: float, keep_clear: Array = []) -> void:
	blk(pk, kit, "concrete", Vector3(x0, -0.3, 0.0), Vector3(x1, 0.12, depth), CONCRETE)
	var jx := x0 + 1.5
	while jx < x1:
		pk.quad(kit, "concrete", [Vector3(jx - 0.02, 0.132, 0.0), Vector3(jx + 0.02, 0.132, 0.0), Vector3(jx + 0.02, 0.132, depth), Vector3(jx - 0.02, 0.132, depth)], Vector3.UP, CONCRETE.darkened(0.25))
		jx += 1.5
	blk(pk, kit, "stone", Vector3(x0, -0.3, depth), Vector3(x1, 0.16, depth + 0.3), STONE)
	var lx := x0 + 4.0
	var k := 0
	while lx < x1 - 2.0:
		lamp_post(pk, kit, Vector3(lx, 0.12, depth - 0.5), 3.8)
		var free := true
		for kc in keep_clear:
			if lx + 2.2 > float(kc.x) - 1.2 and lx + 2.2 < float(kc.y) + 1.2:
				free = false
		if k % 2 == 1 and free:
			bench(pk, kit, Vector3(lx + 2.2, 0.12, depth - 1.6), Vector3(0, 0, 1), 1.6)
		lx += 11.0
		k += 1


## The plaza in front of the station: dressed stone paving in a grid with a border, a round fountain in its middle (a
## basin, a column, a bowl, water), four planters with olive trees, benches facing the fountain, lamp posts, a flagpole,
## a bus shelter by the road, bollards along the road's edge. Life size, in the station's frame (x 0..40 its front,
## z from 0 at the station's front out to `depth` toward the road).
## Where the plaza's trees stand (on their planters' soil) and the fountain's middle, in the plaza's frame.
static func plaza_tree_spots(x0: float, x1: float, depth: float) -> Array:
	var out: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			out.append(Vector3((x0 + x1) * 0.5 + sx * 9.5, 0.73, depth * 0.5 + sz * 4.0))
	return out


static func fountain_centre(x0: float, x1: float, depth: float) -> Vector3:
	return Vector3((x0 + x1) * 0.5, 0.1, depth * 0.5)


static func plaza(pk: PropKit, kit: Dictionary, x0: float, x1: float, depth: float, labels: Array) -> void:
	# The paving: a slab of dressed stone, its joints in a 2m grid 1.2cm up, a darker border.
	blk(pk, kit, "dressed", Vector3(x0, -0.4, 0.0), Vector3(x1, 0.1, depth), Color(0.78, 0.72, 0.62))
	var jx := x0 + 2.0
	while jx < x1 - 0.5:
		pk.quad(kit, "dressed", [Vector3(jx - 0.03, 0.112, 0.0), Vector3(jx + 0.03, 0.112, 0.0), Vector3(jx + 0.03, 0.112, depth), Vector3(jx - 0.03, 0.112, depth)], Vector3.UP, Color(0.6, 0.55, 0.46))
		jx += 2.0
	var jz := 2.0
	while jz < depth - 0.5:
		pk.quad(kit, "dressed", [Vector3(x0, 0.114, jz - 0.03), Vector3(x1, 0.114, jz - 0.03), Vector3(x1, 0.114, jz + 0.03), Vector3(x0, 0.114, jz + 0.03)], Vector3.UP, Color(0.6, 0.55, 0.46))
		jz += 2.0
	blk(pk, kit, "stone", Vector3(x0 - 0.3, -0.4, depth), Vector3(x1 + 0.3, 0.16, depth + 0.35), STONE)
	var cx: float = (x0 + x1) * 0.5
	var cz: float = depth * 0.5
	var c := Vector3(cx, 0.1, cz)
	# The fountain: a stone basin with a rim, the water, a column with a bowl and a finial.
	pk.lathe(kit, "stone", c, [Vector2(3.0, 0.0), Vector2(3.0, 0.55), Vector2(3.25, 0.62), Vector2(3.25, 0.72), Vector2(2.8, 0.72), Vector2(2.8, 0.4), Vector2(0.001, 0.4)], 28, STONE.lightened(0.08))
	pk.tube(kit, "stone", c + Vector3(0, 0.4, 0), c + Vector3(0, 1.9, 0), 0.32, 0.22, 14, STONE.lightened(0.05))
	pk.lathe(kit, "stone", c + Vector3(0, 1.9, 0), [Vector2(0.2, 0.0), Vector2(1.1, 0.35), Vector2(1.15, 0.45), Vector2(0.001, 0.45)], 20, STONE.lightened(0.1))
	pk.lathe(kit, "stone", c + Vector3(0, 2.35, 0), [Vector2(0.14, 0.0), Vector2(0.1, 0.5), Vector2(0.2, 0.62), Vector2(0.001, 0.85)], 12, STONE.lightened(0.1))
	# Benches round it, facing in.
	for k in range(4):
		var a: float = TAU * (float(k) + 0.5) / 4.0
		var bdir := Vector3(cos(a), 0, sin(a))
		var bp: Vector3 = c + bdir * 5.2
		var out := -bdir
		var axis_out := Vector3(signf(out.x), 0, 0) if absf(out.x) > absf(out.z) else Vector3(0, 0, signf(out.z))
		bench(pk, kit, Vector3(bp.x, 0.1, bp.z), axis_out, 1.8)
	# Planters with olive trees at the four corners round the fountain.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pp := Vector3(cx + sx * 9.5, 0.1, cz + sz * 4.0)
			blk(pk, kit, "stone", pp + Vector3(-1.0, 0.0, -1.0), pp + Vector3(1.0, 0.6, 1.0), STONE)
			blk(pk, kit, "matte", pp + Vector3(-0.85, 0.6, -0.85), pp + Vector3(0.85, 0.63, 0.85), Color(0.33, 0.24, 0.16))
			# The trees themselves are WoodlandBuilder's (the generator plants them: plaza_tree_spots).
	# Lamp posts at the corners, a flagpole by the station's door, a bus shelter and bollards by the road.
	for p in [Vector3(x0 + 1.5, 0.1, 1.5), Vector3(x1 - 1.5, 0.1, 1.5), Vector3(x0 + 1.5, 0.1, depth - 1.5), Vector3(x1 - 1.5, 0.1, depth - 1.5)]:
		lamp_post(pk, kit, p, 4.0)
	var fp := Vector3(cx + 4.5, 0.1, 1.6)
	blk(pk, kit, "stone", fp + Vector3(-0.4, 0, -0.4), fp + Vector3(0.4, 0.35, 0.4), STONE)
	pk.tube(kit, "steel", fp + Vector3(0, 0.35, 0), fp + Vector3(0, 9.0, 0), 0.08, 0.05, 10, Color(0.85, 0.85, 0.82))
	pk.lathe(kit, "steel", fp + Vector3(0, 9.0, 0), [Vector2(0.12, 0.0), Vector2(0.001, 0.2)], 8, Color(0.85, 0.7, 0.3))
	for k in range(3):
		box_at(pk, kit, "canvas", fp + Vector3(0.9, 8.2 - 0.4 * float(k), 0), Basis(), Vector3(1.6, 0.4, 0.02), [Color(0.96, 0.47, 0.09), Color(0.06, 0.10, 0.25), Color(0.96, 0.47, 0.09)][k])
	# The bus shelter at the plaza's road edge, its back to the road.
	var sp := Vector3(x0 + 6.0, 0.1, depth - 1.6)
	for sx in [-1.2, 1.2]:
		pk.beam(kit, "steel", sp + Vector3(sx, 0, 0.5), sp + Vector3(sx, 2.5, 0.5), 0.08, 0.08, IRON_GREEN)
	box_at(pk, kit, "glass", sp + Vector3(0, 1.3, 0.55), Basis(), Vector3(2.3, 1.9, 0.03), GLASS_COL)
	blk(pk, kit, "iron", sp + Vector3(-1.45, 2.5, -0.9), sp + Vector3(1.45, 2.6, 0.7), IRON_GREEN)
	pk.quad(kit, "iron", [sp + Vector3(-1.45, 2.49, 0.7), sp + Vector3(1.45, 2.49, 0.7), sp + Vector3(1.45, 2.49, -0.9), sp + Vector3(-1.45, 2.49, -0.9)], Vector3.DOWN, IRON_GREEN.darkened(0.3))
	bench(pk, kit, sp + Vector3(0, 0, 0.0), Vector3(0, 0, -1), 2.0)
	box_at(pk, kit, "painted", sp + Vector3(1.6, 2.3, 0.5), Basis(), Vector3(0.5, 0.5, 0.04), Color(0.1, 0.3, 0.6))
	labels.append(["BUS", sp + Vector3(1.6, 2.3, 0.53), Vector3(0, 0, 1), 0.22, Color(0.95, 0.95, 0.9), 0.45])
	pk.beam(kit, "steel", sp + Vector3(1.6, 0, 0.5), sp + Vector3(1.6, 2.05, 0.5), 0.05, 0.05, CAST)
	var bx := x0 + 10.0
	while bx < x1 - 1.0:
		pk.tube(kit, "steel", Vector3(bx, 0.1, depth - 0.4), Vector3(bx, 0.95, depth - 0.4), 0.11, 0.1, 10, CAST)
		pk.lathe(kit, "steel", Vector3(bx, 0.95, depth - 0.4), [Vector2(0.11, 0.0), Vector2(0.001, 0.1)], 10, CAST)
		bx += 2.5
	# The station's name in metal letters on a low wall at the plaza's west end, facing the road.
	var nw := Vector3(x0 + 0.8, 0.1, depth * 0.5)
	blk(pk, kit, "stone", nw + Vector3(-0.3, 0, -3.5), nw + Vector3(0.3, 1.1, 3.5), STONE.darkened(0.05))
	labels.append(["ESTACION SECA", nw + Vector3(-0.33, 0.6, 0), Vector3(-1, 0, 0), 0.32, Color(0.82, 0.68, 0.35), 6.6])
