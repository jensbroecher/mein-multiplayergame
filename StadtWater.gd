extends Node3D
## Quer durch Kronburg's water bodies, each at its own level: the moat, the Botanischer Garten's lily pond and the canal.
## PlayerCart takes one water surface per stage unless the level has a node named "RiverWater" with `surface_at(x, z)`
## (as Northlight Caverns' NorthlightWater.gd): this is that node, so a cart in the pond or the canal is in water too (it
## wades, slows, splashes, sinks where it is deep), not driving over a dry bed under a drawn surface. Only the moat had
## counted (the first node named "...Water").
##
## `rects`: [x0, z0, x1, z1, y] per box of water; `ellipses`: [cx, cz, rx, rz, y] per ellipse. `water_bounds` covers all.

@export var rects: Array = []
@export var ellipses: Array = []
@export var water_bounds: Rect2 = Rect2()


## The water's surface (world y) at (x, z), or NAN where there is none.
func surface_at(x: float, z: float) -> float:
	if not water_bounds.has_point(Vector2(x, z)):
		return NAN
	for r in rects:
		if x >= float(r[0]) and x <= float(r[2]) and z >= float(r[1]) and z <= float(r[3]):
			return float(r[4])
	for e in ellipses:
		var u: float = (x - float(e[0])) / float(e[2])
		var v: float = (z - float(e[1])) / float(e[3])
		if u * u + v * v <= 1.0:
			return float(e[4])
	return NAN
