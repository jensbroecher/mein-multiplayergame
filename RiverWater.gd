extends Node3D
## Water whose surface is not one flat plane: a river that falls along its length, plus pools.
##
## PlayerCart finds this node as the level's "RiverWater" child and asks `surface_at()` for the
## water height under the car instead of using a single stage-wide water level. The level
## generator fills the data; it is plain arrays so the level file stores it directly.
##
## Strips are polylines of (x, surface y, z) with a half width per point. A strip covers the
## band within that half width of each of its segments, with the surface height and half width
## interpolated along the segment. Pools are discs of (x, surface y, z, radius).

## Every strip's points, back to back. `strip_starts[i]` is the index of strip i's first point.
@export var strip_points: PackedVector3Array = PackedVector3Array()
@export var strip_half_widths: PackedFloat32Array = PackedFloat32Array()
@export var strip_starts: PackedInt32Array = PackedInt32Array()
## (x, surface y, z, radius) per pool.
@export var pools: Array[Vector4] = []
## XZ rectangle covering all water, so callers can reject most positions cheaply.
@export var water_bounds: Rect2 = Rect2()


## Water surface height at (x, z), or NAN where there is no water.
##
## Where two pieces overlap (a strip ending inside a pool), the piece the point sits deepest
## inside wins, measured as distance from its edge relative to its width. That keeps the
## surface continuous along a strip and puts the step at a waterfall exactly on the lip.
func surface_at(x: float, z: float) -> float:
	if not water_bounds.has_point(Vector2(x, z)):
		return NAN
	var best_y: float = NAN
	var best_depth: float = 0.0
	for pool in pools:
		var r: float = pool.w
		var d: float = Vector2(x - pool.x, z - pool.z).length()
		if d < r:
			var depth: float = 1.0 - d / r
			if depth > best_depth:
				best_depth = depth
				best_y = pool.y
	var n_strips: int = strip_starts.size()
	for s in range(n_strips):
		var first: int = strip_starts[s]
		var last: int = (strip_starts[s + 1] if s + 1 < n_strips else strip_points.size()) - 1
		for i in range(first, last):
			var a: Vector3 = strip_points[i]
			var b: Vector3 = strip_points[i + 1]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var len2: float = ab.length_squared()
			if len2 < 1e-6:
				continue
			var t: float = clampf(((x - a.x) * ab.x + (z - a.z) * ab.y) / len2, 0.0, 1.0)
			# Past either end of the strip the band stops square instead of rounding off, or the
			# upper river would bulge over the falls lip.
			if (i == first and t <= 0.0) or (i == last - 1 and t >= 1.0):
				var along: float = ((x - a.x) * ab.x + (z - a.z) * ab.y) / len2
				if along < -0.0001 or along > 1.0001:
					continue
			var hw: float = lerpf(strip_half_widths[i], strip_half_widths[i + 1], t)
			var px: float = a.x + ab.x * t
			var pz: float = a.z + ab.y * t
			var d: float = Vector2(x - px, z - pz).length()
			if d < hw:
				var depth: float = 1.0 - d / hw
				if depth > best_depth:
					best_depth = depth
					best_y = lerpf(a.y, b.y, t)
	return best_y
